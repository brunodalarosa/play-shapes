class_name PlatformMotor
extends Node
## Reusable host physics on a CharacterBody3D locked to the plane at depth zero, in world units
## with Y up. No registry, UI or player identity.
##
## Godot's 3D physics has no one-way shapes, so the motor makes them: before each move it
## excludes, for its own body only, every one-way PlatformSurface in its path whose top is above
## its feet. A body therefore rises through a landing and lands on it from above. A deliberate
## FALL excludes the one Open support underneath until the body clears it.

signal fall_reset_requested

## Feet this far below a one-way top count as beneath it, world units.
const PASS_TOLERANCE := 0.02
## Below this horizontal speed, world units per second, the body presents as idle.
const IDLE_SPEED := 0.2

## Horizontal top speed, units/second.
@export var move_speed: float = 3.44
## Horizontal acceleration, units/second squared, on ground and in air.
@export var acceleration: float = 19.8
## Downward acceleration, units/second squared.
@export var gravity: float = 14.06
## Grounded jump impulse, units/second.
@export var jump_impulse: float = 10.6
## Fraction of landing speed used to rebound from another character.
@export_range(0.0, 1.0) var player_bounce_factor: float = 0.45
## Maximum player rebound, units/second.
@export var player_bounce_max_impulse: float = 4.4
## Minimum landing speed for player rebound, units/second.
@export var player_bounce_min_fall_speed: float = 1.67
## Analog horizontal threshold selecting run rather than walk.
@export_range(0.0, 1.0) var run_threshold: float = 0.72
## World Y below which the owning adapter must respawn the body.
@export var fall_reset_y: float = -3.0
## Input lease, milliseconds. Must exceed the phone's held-input refresh.
@export_range(150, 1000, 1) var input_timeout_msec: int = 350
## Maximum per-support exclusion, seconds. Timeout always restores collision.
@export_range(0.1, 2.0, 0.01) var drop_timeout_seconds: float = 0.65
## Full-body clearance below the support, units; higher delays restoration.
@export_range(0.0, 0.2, 0.005) var drop_clearance: float = 0.04
## Initial downward speed for a deliberate drop, units/second.
@export_range(0.01, 3.0, 0.01) var drop_speed: float = 0.83

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
## Each excluded surface and the callable that releases it when the surface leaves the tree.
var _excluded: Dictionary = { }
@onready var body := get_parent() as CharacterBody3D


func _ready() -> void:
	assert(body != null, "PlatformMotor requires a CharacterBody3D parent")
	PlaneLock3D.lock(body)
	set_physics_process(enabled)


func set_enabled(value: bool) -> void:
	if value != enabled:
		clear_input()
	enabled = value
	set_physics_process(enabled)
	if not enabled and is_instance_valid(body):
		body.velocity = Vector3.ZERO


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
	_end_drop()


func request_jump() -> bool:
	if (
		not enabled or not _contacts_valid or _jump_queued or _dropping
		or not body.is_on_floor() or body.velocity.y > 0.0
	):
		return false
	_jump_queued = true
	return true


func supporting_surface() -> PlatformSurface:
	if not _contacts_valid or not body.is_on_floor() or body.velocity.y > 0.0:
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
	_drop_elapsed = 0.0
	_saved_snap = body.floor_snap_length
	body.floor_snap_length = 0.0
	_exclude(support)
	body.velocity.y = minf(body.velocity.y, -drop_speed)
	return true


## The surfaces this body currently passes through, rising or dropping.
func excluded_surfaces() -> Array[PlatformSurface]:
	var surfaces: Array[PlatformSurface] = []
	surfaces.assign(_excluded.keys())
	return surfaces


func is_dropping() -> bool:
	return _dropping


func presentation_action() -> String:
	if (
		body.is_on_floor() and body.velocity.y <= 0.0
		and not _dropping and stance in ["look_up", "crouch"]
	):
		return stance
	if absf(body.velocity.x) < IDLE_SPEED:
		return "idle"

	return "run" if absf(axes.x) >= run_threshold else "walk"


func _physics_process(delta: float) -> void:
	expire_input(Time.get_ticks_msec())
	body.velocity.x = move_toward(body.velocity.x, axes.x * move_speed, acceleration * delta)
	body.velocity.z = 0.0
	if _jump_queued:
		# Eligibility is checked again at consumption, so an edge/transition cannot queue a later
		# jump.
		if body.is_on_floor() and body.velocity.y <= 0.0:
			body.velocity.y = jump_impulse
		_jump_queued = false
	else:
		body.velocity.y -= gravity * delta
	var falling_speed := -body.velocity.y
	_update_passing(delta)
	body.move_and_slide()
	_contacts_valid = true
	if _dropping:
		_update_drop(delta)
	if falling_speed >= player_bounce_min_fall_speed:
		for index: int in body.get_slide_collision_count():
			var contact := body.get_slide_collision(index)
			if contact.get_collider() is CharacterBody3D and contact.get_normal().y > 0.7:
				body.velocity.y = minf(
					falling_speed * player_bounce_factor,
					player_bounce_max_impulse,
				)
				break
	if body.position.y < fall_reset_y:
		clear_input()
		body.velocity = Vector3.ZERO
		fall_reset_requested.emit()


## Excludes the one-way surfaces this step's motion could meet from below or the side, and
## restores every other one, so landings stay solid to a body whose feet are above them.
func _update_passing(delta: float) -> void:
	var bounds := _body_bounds()
	var moved := AABB(bounds.position + body.velocity * delta, bounds.size)
	var path := bounds.merge(moved)
	var feet := bounds.position.y
	var wanted: Array[PlatformSurface] = []
	for node: Node in body.get_tree().get_nodes_in_group(PlatformSurface.GROUP):
		var surface := node as PlatformSurface
		if not surface.one_way or not surface.is_inside_tree():
			continue
		var box := surface.world_bounds()
		if box.end.y > feet + PASS_TOLERANCE and path.intersects(box):
			wanted.append(surface)
	if _dropping and is_instance_valid(_drop_surface) and not wanted.has(_drop_surface):
		wanted.append(_drop_surface)
	for surface: PlatformSurface in excluded_surfaces():
		if not wanted.has(surface):
			_release(surface)
	for surface: PlatformSurface in wanted:
		_exclude(surface)


func _update_drop(delta: float) -> void:
	_drop_elapsed += delta
	if not is_instance_valid(_drop_surface) or _drop_elapsed >= drop_timeout_seconds:
		_end_drop()
		return
	var support_bounds := _drop_surface.world_bounds()
	var body_bounds := _body_bounds()
	# Full clearance, walking off an edge, or landing on a different support all end
	# the drop. Lower platforms/characters remain collidable throughout.
	if (
		body_bounds.end.y < support_bounds.position.y - drop_clearance
		or body_bounds.end.x < support_bounds.position.x
		or body_bounds.position.x > support_bounds.end.x or body.is_on_floor()
	):
		_end_drop()


func _body_bounds() -> AABB:
	var bounds := AABB()
	var found := false
	for child: Node in body.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape != null:
			var box: AABB = child.global_transform * child.shape.get_debug_mesh().get_aabb()
			bounds = bounds.merge(box) if found else box
			found = true
	return bounds


func _exclude(surface: PlatformSurface) -> void:
	if _excluded.has(surface):
		return
	# Remove the exception before Godot frees the surface's physics RID. Otherwise
	# querying exceptions can retain a dead RID even after the node reference expires.
	var release := _release.bind(surface)
	surface.tree_exiting.connect(release, CONNECT_ONE_SHOT)
	_excluded[surface] = release
	body.add_collision_exception_with(surface)


func _release(surface: PlatformSurface) -> void:
	if not _excluded.has(surface):
		return
	var release: Callable = _excluded[surface]
	_excluded.erase(surface)
	if is_instance_valid(surface):
		if surface.tree_exiting.is_connected(release):
			surface.tree_exiting.disconnect(release)
		if is_instance_valid(body):
			body.remove_collision_exception_with(surface)
	if _dropping and surface == _drop_surface:
		_end_drop()


## Ends a deliberate drop. A body still inside the landing keeps passing through it as an
## ordinary one-way body from the next step.
func _end_drop() -> void:
	if not _dropping:
		return
	var surface := _drop_surface
	_dropping = false
	_drop_surface = null
	_drop_elapsed = 0.0
	if is_instance_valid(body):
		body.floor_snap_length = _saved_snap
	if is_instance_valid(surface):
		_release(surface)


func _exit_tree() -> void:
	clear_input()
	for surface: PlatformSurface in excluded_surfaces():
		_release(surface)
