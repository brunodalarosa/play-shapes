class_name BubblesPufferfish
extends Area2D
## One warned, one-pass host trajectory. Only player bodies are checked by the arena.

const LEFT_TEXTURE: Texture2D = preload("res://assets/runtime/minigames/bubbles_and_jellyfishes/pufferfish/pufferfish_left.png")
const RIGHT_TEXTURE: Texture2D = preload("res://assets/runtime/minigames/bubbles_and_jellyfishes/pufferfish/pufferfish_right.png")

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collider: CollisionShape2D = $CollisionShape2D

var creature_id := 0
var radius := 30.0
var start_position := Vector2.ZERO
var end_position := Vector2.ZERO
var direction := Vector2.RIGHT
var warning_until_msec := 0
var active := false
var finished := false
var _speed := 0.0
var _distance_traveled := 0.0
var _path_length := 0.0


func _ready() -> void:
	set_physics_process(false)
	_collider.shape = _collider.shape.duplicate()


func configure(id: int, selected_tuning: BubblesTuning, at_msec: int,
		start: Vector2, destination: Vector2, edge_warning_position: Vector2) -> void:
	creature_id = id
	radius = selected_tuning.pufferfish_collider_radius
	start_position = start
	end_position = destination
	_path_length = start.distance_to(destination)
	direction = (destination - start).normalized()
	_speed = selected_tuning.pufferfish_speed
	warning_until_msec = at_msec + (roundi(selected_tuning.pufferfish_warning_seconds * 1000.0) if selected_tuning.pufferfish_warning_enabled else 0)
	global_position = edge_warning_position if selected_tuning.pufferfish_warning_enabled and warning_until_msec > at_msec else start
	_sprite.texture = LEFT_TEXTURE if direction.x < 0.0 else RIGHT_TEXTURE
	_sprite.rotation = direction.angle() - (PI if direction.x < 0.0 else 0.0)
	_sprite.scale = Vector2.ONE * radius * 3.5 / float(_sprite.texture.get_width())
	_sprite.visible = false
	(_collider.shape as CircleShape2D).radius = radius
	_collider.disabled = true
	queue_redraw()
	if warning_until_msec == at_msec:
		simulate_step(0.0, at_msec)


func simulate_step(delta: float, host_time_msec: int) -> void:
	if finished:
		return
	if not active:
		if host_time_msec < warning_until_msec:
			return
		active = true
		global_position = start_position
		_sprite.visible = true
		_collider.disabled = false
		queue_redraw()
	_distance_traveled += _speed * delta
	global_position = start_position + direction * minf(_distance_traveled, _path_length)
	if _distance_traveled >= _path_length:
		finished = true
		visible = false
		_collider.disabled = true


func can_hit_player() -> bool:
	return active and not finished


func _draw() -> void:
	if active or finished:
		return
	# A short edge arrow remains readable without using color alone.
	var tip := direction * 22.0
	draw_line(-tip * 0.6, tip, Color(1.0, 0.89, 0.48, 0.95), 5.0, true)
	draw_line(tip, tip - direction.rotated(0.65) * 13.0, Color.WHITE, 4.0, true)
	draw_line(tip, tip - direction.rotated(-0.65) * 13.0, Color.WHITE, 4.0, true)
