class_name BubblesJellyfish
extends Area2D
## One free collectible. Host timestamps, not animation frames, decide collection.

const WHITE_SHADER: Shader = preload("res://minigames/bubbles_white_blink.gdshader")
const TURN_INTERVAL_MSEC := 1600
const BLINK_INTERVAL_MSEC := 120

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collider: CollisionShape2D = $CollisionShape2D

var creature_id := 0
var released := false
var radius := 14.0
var velocity := Vector2.ZERO
var spawned_at_msec := 0
var collectible_at_msec := 0
var _next_turn_msec := 0
var _base_sprite_scale := 1.0
var _white_material: ShaderMaterial


func _ready() -> void:
	set_physics_process(false)
	_collider.shape = _collider.shape.duplicate()
	_white_material = ShaderMaterial.new()
	_white_material.shader = WHITE_SHADER
	_sprite.material = _white_material


func configure(id: int, selected_tuning: BubblesTuning, at_msec: int, position_world: Vector2,
		movement: Vector2, from_pop := false, release_lockout_msec := 0) -> void:
	creature_id = id
	released = from_pop
	radius = selected_tuning.jellyfish_collider_radius
	spawned_at_msec = at_msec
	collectible_at_msec = at_msec + (maxi(1, release_lockout_msec) if from_pop else roundi(selected_tuning.jellyfish_entrance_seconds * 1000.0))
	_next_turn_msec = at_msec + TURN_INTERVAL_MSEC
	global_position = position_world
	velocity = movement.normalized() * selected_tuning.jellyfish_speed if movement.length_squared() > 0.0 else Vector2.ZERO
	(_collider.shape as CircleShape2D).radius = radius
	_base_sprite_scale = (radius * 4.0) / float(_sprite.texture.get_width())
	_refresh(at_msec)


func simulate_step(delta: float, host_time_msec: int, random_unit: float = 0.5) -> void:
	if host_time_msec >= _next_turn_msec:
		velocity = velocity.rotated((clampf(random_unit, 0.0, 1.0) - 0.5) * PI / 3.0)
		_next_turn_msec = host_time_msec + TURN_INTERVAL_MSEC
	global_position += velocity * delta
	_refresh(host_time_msec)


func needs_turn(host_time_msec: int) -> bool:
	return host_time_msec >= _next_turn_msec


func is_collectible(host_time_msec: int) -> bool:
	return host_time_msec >= collectible_at_msec and host_time_msec >= spawned_at_msec


func is_offscreen(bounds: Rect2) -> bool:
	return not bounds.grow(radius + 30.0).has_point(global_position)


func _refresh(host_time_msec: int) -> void:
	var scale_factor := 1.0
	if not released and collectible_at_msec > spawned_at_msec:
		var progress := clampf(float(host_time_msec - spawned_at_msec) / float(collectible_at_msec - spawned_at_msec), 0.0, 1.0)
		scale_factor = 0.15 + 0.85 * progress
	_sprite.scale = Vector2.ONE * _base_sprite_scale * scale_factor
	var white_on := released and not is_collectible(host_time_msec) and (host_time_msec / BLINK_INTERVAL_MSEC) % 2 == 0
	_white_material.set_shader_parameter("whiten", 1.0 if white_on else 0.0)
	_collider.disabled = not is_collectible(host_time_msec)
