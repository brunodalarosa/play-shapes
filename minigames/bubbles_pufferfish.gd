class_name BubblesPufferfish
extends Area2D
## One warned, one-pass host trajectory. Decorative motion never drives collision checks.

const LEFT_TEXTURE: Texture2D = preload("res://assets/runtime/minigames/bubbles_and_jellyfishes/pufferfish/pufferfish_left.png")
const RIGHT_TEXTURE: Texture2D = preload("res://assets/runtime/minigames/bubbles_and_jellyfishes/pufferfish/pufferfish_right.png")
const TELEGRAPH_PATH_FRACTION := 0.15
const MAX_WARNING_BUBBLES := 48

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
var _warning_enabled := false
var _warning_bubble_spacing := 24.0
var _warning_bubble_radius := 4.5
var _warning_fade_seconds := 0.7
var _warning_rise_speed := 12.0
var _next_warning_bubble_distance := 4.0
var _warning_bubble_index := 0
var _warning_bubbles: Array[Dictionary] = []
var _base_sprite_scale := Vector2.ONE
var _base_sprite_rotation := 0.0
var _jiggle_degrees := 3.5
var _jiggle_period_seconds := 0.32
var _jiggle_squash := 0.035
var _animation_elapsed := 0.0


func _ready() -> void:
	set_physics_process(false)
	_collider.shape = _collider.shape.duplicate()


func configure(id: int, selected_tuning: BubblesTuning, at_msec: int,
		start: Vector2, destination: Vector2, edge_warning_position: Vector2) -> void:
	creature_id = id
	radius = selected_tuning.pufferfish_collider_radius * selected_tuning.pufferfish_size_multiplier
	start_position = start
	end_position = destination
	_path_length = start.distance_to(destination)
	direction = (destination - start).normalized()
	_speed = selected_tuning.pufferfish_speed
	_warning_enabled = selected_tuning.pufferfish_warning_enabled
	_warning_bubble_spacing = selected_tuning.pufferfish_warning_bubble_spacing
	_warning_bubble_radius = selected_tuning.pufferfish_warning_bubble_radius
	_warning_fade_seconds = selected_tuning.pufferfish_warning_fade_seconds
	_warning_rise_speed = selected_tuning.pufferfish_warning_rise_speed
	_next_warning_bubble_distance = minf(4.0, _warning_bubble_spacing * 0.25)
	_jiggle_degrees = selected_tuning.pufferfish_jiggle_degrees
	_jiggle_period_seconds = selected_tuning.pufferfish_jiggle_period_seconds
	_jiggle_squash = selected_tuning.pufferfish_jiggle_squash
	warning_until_msec = at_msec + (roundi(selected_tuning.pufferfish_warning_seconds * 1000.0) if _warning_enabled else 0)
	global_position = edge_warning_position if _warning_enabled and warning_until_msec > at_msec else start
	_sprite.texture = LEFT_TEXTURE if direction.x < 0.0 else RIGHT_TEXTURE
	_base_sprite_rotation = direction.angle() - (PI if direction.x < 0.0 else 0.0)
	_sprite.rotation = _base_sprite_rotation
	_base_sprite_scale = Vector2.ONE * radius * 3.5 / float(_sprite.texture.get_width())
	_sprite.scale = _base_sprite_scale
	_sprite.visible = false
	(_collider.shape as CircleShape2D).radius = radius
	_collider.disabled = true
	queue_redraw()
	if warning_until_msec == at_msec:
		simulate_step(0.0, at_msec)


func simulate_step(delta: float, host_time_msec: int) -> void:
	if finished:
		return
	_advance_warning_bubbles(delta)
	if not active:
		if host_time_msec < warning_until_msec:
			return
		active = true
		global_position = start_position
		_sprite.visible = true
		_collider.disabled = false
		queue_redraw()
	var previous_distance := _distance_traveled
	_distance_traveled += _speed * delta
	var current_distance := minf(_distance_traveled, _path_length)
	global_position = start_position + direction * current_distance
	_animation_elapsed += delta
	_update_body_motion()
	_emit_warning_bubbles_through(minf(current_distance, _path_length * TELEGRAPH_PATH_FRACTION), previous_distance)
	if _distance_traveled >= _path_length:
		finished = true
		visible = false
		_collider.disabled = true
	queue_redraw()


func can_hit_player() -> bool:
	return active and not finished


func _update_body_motion() -> void:
	var wave := sin(TAU * _animation_elapsed / _jiggle_period_seconds)
	_sprite.rotation = _base_sprite_rotation + deg_to_rad(_jiggle_degrees) * wave
	_sprite.scale = _base_sprite_scale * Vector2(1.0 + wave * _jiggle_squash * 0.35, 1.0 - wave * _jiggle_squash)


func _emit_warning_bubbles_through(distance_limit: float, previous_distance: float) -> void:
	if not _warning_enabled:
		return
	var telegraph_end := _path_length * TELEGRAPH_PATH_FRACTION
	while _next_warning_bubble_distance <= distance_limit and _next_warning_bubble_distance <= telegraph_end:
		if _warning_bubbles.size() >= MAX_WARNING_BUBBLES:
			_warning_bubbles.pop_front()
		var side := -2.5 if _warning_bubble_index % 2 == 0 else 2.5
		var emit_position := start_position + direction * _next_warning_bubble_distance
		emit_position -= direction * radius * 0.55
		emit_position += direction.orthogonal() * side
		var size_factor := 0.8 + float(_warning_bubble_index % 3) * 0.2
		var drift := Vector2.UP * _warning_rise_speed - direction * minf(10.0, _speed * 0.06)
		_warning_bubbles.append({
			"position": emit_position,
			"velocity": drift,
			"age": 0.0,
			"lifetime": _warning_fade_seconds,
			"radius": _warning_bubble_radius * size_factor,
		})
		_warning_bubble_index += 1
		_next_warning_bubble_distance += _warning_bubble_spacing
	if distance_limit > previous_distance:
		queue_redraw()


func _advance_warning_bubbles(delta: float) -> void:
	if delta <= 0.0 or _warning_bubbles.is_empty():
		return
	for index: int in range(_warning_bubbles.size() - 1, -1, -1):
		var bubble: Dictionary = _warning_bubbles[index]
		var age := float(bubble["age"]) + delta
		if age >= float(bubble["lifetime"]):
			_warning_bubbles.remove_at(index)
			continue
		var position: Vector2 = bubble["position"]
		var velocity: Vector2 = bubble["velocity"]
		bubble["position"] = position + velocity * delta
		bubble["age"] = age
		_warning_bubbles[index] = bubble
	queue_redraw()


func _draw() -> void:
	if not _warning_enabled or finished:
		return
	if not active:
		_draw_warning_preview()
		return
	for bubble: Dictionary in _warning_bubbles:
		var age := float(bubble["age"])
		var lifetime := float(bubble["lifetime"])
		var opacity := clampf(1.0 - age / lifetime, 0.0, 1.0)
		var bubble_position: Vector2 = bubble["position"]
		_draw_bubble(bubble_position - global_position, float(bubble["radius"]), opacity)


func _draw_warning_preview() -> void:
	var preview_length := _path_length * TELEGRAPH_PATH_FRACTION
	var steps := mini(32, maxi(2, roundi(preview_length / _warning_bubble_spacing)))
	var path_start := start_position - global_position
	for index: int in steps + 1:
		var progress := float(index) / float(steps)
		var offset := direction.orthogonal() * (sin(float(index) * 1.7) * 1.5)
		var center := path_start + direction * preview_length * progress + offset
		var opacity := lerpf(0.22, 0.78, progress)
		_draw_bubble(center, _warning_bubble_radius * lerpf(0.75, 1.15, progress), opacity)


func _draw_bubble(center: Vector2, bubble_radius: float, opacity: float) -> void:
	var edge := Color(0.62, 0.96, 1.0, 0.9 * opacity)
	var inner := Color(0.34, 0.82, 0.9, 0.12 * opacity)
	draw_circle(center, bubble_radius, inner)
	draw_arc(center, bubble_radius, 0.0, TAU, 14, edge, 1.5, true)
	draw_circle(center + Vector2(-bubble_radius * 0.3, -bubble_radius * 0.32), bubble_radius * 0.17,
		Color(0.96, 1.0, 1.0, 0.8 * opacity))
