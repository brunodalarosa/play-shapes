class_name PlatformMotor
extends Node
## Reusable host physics on a CharacterBody2D. No registry, UI or player identity.

signal fall_reset_requested

## Horizontal top speed, pixels/second.
@export var move_speed: float = 330.0
## Horizontal acceleration, pixels/second squared, on ground and in air.
@export var acceleration: float = 1900.0
## Downward acceleration, pixels/second squared.
@export var gravity: float = 1350.0
## Grounded jump impulse, pixels/second.
@export var jump_impulse: float = 940.0
## Fraction of landing speed used to rebound from another character.
@export_range(0.0, 1.0) var player_bounce_factor: float = 0.45
## Maximum player rebound, pixels/second.
@export var player_bounce_max_impulse: float = 420.0
## Minimum landing speed for player rebound, pixels/second.
@export var player_bounce_min_fall_speed: float = 160.0
## Analog horizontal threshold selecting run rather than walk.
@export_range(0.0, 1.0) var run_threshold: float = 0.72
## World Y below which the owning adapter must respawn the body.
@export var fall_reset_y: float = 1160.0
## Input lease, milliseconds. Must exceed the phone's held-input refresh.
@export_range(150, 1000, 1) var input_timeout_msec: int = 350
## Maximum per-support exclusion, seconds. Timeout always restores collision.
@export_range(0.1, 2.0, 0.01) var drop_timeout_seconds: float = 0.65
## Full-body clearance past the support bounds, pixels; higher delays restoration.
@export_range(0.0, 16.0, 0.5) var drop_clearance: float = 4.0
## Initial downward speed for a deliberate drop, pixels/second.
@export_range(1.0, 300.0, 1.0) var drop_speed: float = 80.0

var axes := Vector2.ZERO
var stance := "neutral"
var enabled := true
var _last_input_msec := 0
var _jump_queued := false
var _fall_armed := true
var _drop_surface: PlatformSurface
var _dropping := false
var _drop_elapsed := 0.0
var _saved_snap := 0.0
var _contacts_valid := false
@onready var body := get_parent() as CharacterBody2D


func _ready() -> void:
	assert(body != null, "PlatformMotor requires a CharacterBody2D parent")
	set_physics_process(enabled)


func set_enabled(value: bool) -> void:
	if value != enabled:
		clear_input()
	enabled = value
	set_physics_process(enabled)
	if not enabled and is_instance_valid(body):
		body.velocity = Vector2.ZERO


func set_input(value: Vector2, hint: String, now_msec: int) -> void:
	axes = value
	stance = hint
	_last_input_msec = now_msec
	if hint != "crouch":
		_fall_armed = true


func expire_input(now_msec: int) -> void:
	if now_msec - _last_input_msec > input_timeout_msec:
		clear_input()


func clear_input() -> void:
	axes = Vector2.ZERO
	stance = "neutral"
	_jump_queued = false
	_fall_armed = true
	_contacts_valid = false
	_restore_contact()


func request_jump() -> bool:
	if not enabled or not _contacts_valid or _jump_queued or _dropping or not body.is_on_floor() or body.velocity.y < 0.0:
		return false
	_jump_queued = true
	return true


func supporting_surface() -> PlatformSurface:
	if not _contacts_valid or not body.is_on_floor() or body.velocity.y < 0.0:
		return null
	var support: PlatformSurface
	for index: int in body.get_slide_collision_count():
		var contact := body.get_slide_collision(index)
		if contact.get_normal().dot(body.up_direction) < cos(body.floor_max_angle):
			continue
		var collider := contact.get_collider()
		# Character/unknown/ambiguous support cannot authorize a platform drop.
		if not collider is PlatformSurface or (support != null and support != collider):
			return null
		support = collider as PlatformSurface
	return support


func request_fall() -> bool:
	if not enabled or stance != "crouch" or _dropping or not _fall_armed or _jump_queued:
		return false
	var support := supporting_surface()
	if support == null or support.drop_rule != PlatformSurface.DropRule.OPEN:
		return false
	_fall_armed = false
	_dropping = true
	_drop_surface = support
	# Remove the exception before Godot frees the support's physics RID. Otherwise
	# querying exceptions can retain a dead RID even after the node reference expires.
	support.tree_exiting.connect(_restore_contact, CONNECT_ONE_SHOT)
	_drop_elapsed = 0.0
	_saved_snap = body.floor_snap_length
	body.floor_snap_length = 0.0
	body.add_collision_exception_with(support)
	body.velocity.y = maxf(body.velocity.y, drop_speed)
	return true


func presentation_action() -> String:
	if body.is_on_floor() and body.velocity.y >= 0.0 and not _dropping and stance in ["look_up", "crouch"]:
		return stance
	return "idle" if absf(body.velocity.x) < 20.0 else "run" if absf(axes.x) >= run_threshold else "walk"


func _physics_process(delta: float) -> void:
	expire_input(Time.get_ticks_msec())
	body.velocity.x = move_toward(body.velocity.x, axes.x * move_speed, acceleration * delta)
	if _jump_queued:
		# Eligibility is checked again at consumption, so an edge/transition cannot queue a later jump.
		if body.is_on_floor() and body.velocity.y >= 0.0:
			body.velocity.y = -jump_impulse
		_jump_queued = false
	else:
		body.velocity.y += gravity * delta
	var falling_speed := body.velocity.y
	body.move_and_slide()
	_contacts_valid = true
	if _dropping:
		_update_drop(delta)
	if falling_speed >= player_bounce_min_fall_speed:
		for index: int in body.get_slide_collision_count():
			var contact := body.get_slide_collision(index)
			if contact.get_collider() is CharacterBody2D and contact.get_normal().y < -0.7:
				body.velocity.y = -minf(falling_speed * player_bounce_factor, player_bounce_max_impulse)
				break
	if body.position.y > fall_reset_y:
		clear_input()
		body.velocity = Vector2.ZERO
		fall_reset_requested.emit()


func _update_drop(delta: float) -> void:
	_drop_elapsed += delta
	if not is_instance_valid(_drop_surface) or _drop_elapsed >= drop_timeout_seconds:
		_restore_contact()
		return
	var support_bounds := _drop_surface.world_bounds()
	var body_bounds := _body_bounds()
	# Full clearance, walking off an edge, or landing on a different support all end
	# the exclusion. Lower platforms/characters remain collidable throughout.
	if body_bounds.position.y > support_bounds.end.y + drop_clearance \
			or body_bounds.end.x < support_bounds.position.x or body_bounds.position.x > support_bounds.end.x \
			or body.is_on_floor():
		_restore_contact()


func _body_bounds() -> Rect2:
	var bounds := Rect2()
	var found := false
	for child: Node in body.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape != null:
			var rectangle: Rect2 = child.global_transform * child.shape.get_rect()
			bounds = bounds.merge(rectangle) if found else rectangle
			found = true
	return bounds


func _restore_contact() -> void:
	if not _dropping:
		return
	if is_instance_valid(body):
		if is_instance_valid(_drop_surface):
			if _drop_surface.tree_exiting.is_connected(_restore_contact):
				_drop_surface.tree_exiting.disconnect(_restore_contact)
			body.remove_collision_exception_with(_drop_surface)
		body.floor_snap_length = _saved_snap
	_drop_surface = null
	_dropping = false
	_drop_elapsed = 0.0


func _exit_tree() -> void:
	clear_input()
