class_name BubblesPufferfish
extends Area2D
## One warned, one-pass host trajectory. Particle motion never drives collision checks.

const LEFT_TEXTURE: Texture2D = preload("res://assets/runtime/minigames/bubbles_and_jellyfishes/pufferfish/pufferfish_left.png")
const RIGHT_TEXTURE: Texture2D = preload("res://assets/runtime/minigames/bubbles_and_jellyfishes/pufferfish/pufferfish_right.png")
const WARNING_PARTICLE_TEXTURE_SIZE := 32
const WARNING_PARTICLE_LIFETIME_TAIL := 0.35

@onready var _warning_particles: GPUParticles2D = $WarningParticles
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
var _warning_particle_count := 24
var _warning_bubble_radius := 4.5
var _warning_noise_strength := 3.0
var _base_sprite_scale := Vector2.ONE
var _base_sprite_rotation := 0.0
var _jiggle_degrees := 3.5
var _jiggle_period_seconds := 0.32
var _jiggle_squash := 0.035
var _animation_elapsed := 0.0


func _ready() -> void:
	set_physics_process(false)
	_collider.shape = _collider.shape.duplicate()
	_warning_particles.texture = _create_warning_bubble_texture()
	_warning_particles.one_shot = true
	_warning_particles.explosiveness = 0.9
	_warning_particles.randomness = 1.0
	_warning_particles.local_coords = true
	_warning_particles.emitting = false


func configure(id: int, selected_tuning: BubblesTuning, at_msec: int,
		start: Vector2, destination: Vector2) -> void:
	creature_id = id
	radius = selected_tuning.pufferfish_collider_radius * selected_tuning.pufferfish_size_multiplier
	start_position = start
	end_position = destination
	_path_length = start.distance_to(destination)
	direction = (destination - start).normalized()
	_speed = selected_tuning.pufferfish_speed
	_warning_enabled = selected_tuning.pufferfish_warning_enabled
	_warning_particle_count = selected_tuning.pufferfish_telegraph_bubble_count
	_warning_bubble_radius = selected_tuning.pufferfish_telegraph_bubble_radius
	_warning_noise_strength = selected_tuning.pufferfish_telegraph_noise_strength
	_jiggle_degrees = selected_tuning.pufferfish_jiggle_degrees
	_jiggle_period_seconds = selected_tuning.pufferfish_jiggle_period_seconds
	_jiggle_squash = selected_tuning.pufferfish_jiggle_squash
	var warning_seconds := selected_tuning.pufferfish_warning_seconds if _warning_enabled else 0.0
	warning_until_msec = at_msec + roundi(warning_seconds * 1000.0)
	global_position = start
	_sprite.texture = LEFT_TEXTURE if direction.x < 0.0 else RIGHT_TEXTURE
	_base_sprite_rotation = direction.angle() - (PI if direction.x < 0.0 else 0.0)
	_sprite.rotation = _base_sprite_rotation
	_base_sprite_scale = Vector2.ONE * radius * 3.5 / float(_sprite.texture.get_width())
	_sprite.scale = _base_sprite_scale
	_sprite.visible = false
	(_collider.shape as CircleShape2D).radius = radius
	_collider.disabled = true
	_warning_particles.amount = _warning_particle_count
	_warning_particles.lifetime = maxf(warning_seconds + WARNING_PARTICLE_LIFETIME_TAIL, 0.4)
	_warning_particles.process_material = _create_warning_particle_material()
	_warning_particles.emitting = false
	if warning_seconds > 0.0:
		_warning_particles.restart()
		_warning_particles.emitting = true
	if warning_until_msec == at_msec:
		simulate_step(0.0, at_msec)


func simulate_step(delta: float, host_time_msec: int) -> void:
	if finished:
		return
	var movement_delta := delta
	if not active:
		if host_time_msec < warning_until_msec:
			return
		active = true
		global_position = start_position
		_sprite.visible = true
		_collider.disabled = false
		movement_delta = minf(delta, maxf(0.0, float(host_time_msec - warning_until_msec) / 1000.0))
	_distance_traveled += _speed * movement_delta
	var current_distance := minf(_distance_traveled, _path_length)
	global_position = start_position + direction * current_distance
	_animation_elapsed += movement_delta
	_update_body_motion()
	if _distance_traveled >= _path_length:
		finished = true
		visible = false
		_collider.disabled = true


func can_hit_player() -> bool:
	return active and not finished


func _update_body_motion() -> void:
	var wave := sin(TAU * _animation_elapsed / _jiggle_period_seconds)
	_sprite.rotation = _base_sprite_rotation + deg_to_rad(_jiggle_degrees) * wave
	_sprite.scale = _base_sprite_scale * Vector2(1.0 + wave * _jiggle_squash * 0.35, 1.0 - wave * _jiggle_squash)


func _create_warning_particle_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = 24.0
	material.initial_velocity_min = 95.0
	material.initial_velocity_max = 180.0
	material.gravity = Vector3.ZERO
	material.linear_accel_min = -_warning_noise_strength * 1.5
	material.linear_accel_max = _warning_noise_strength * 1.5
	material.tangential_accel_min = -_warning_noise_strength * 5.0
	material.tangential_accel_max = _warning_noise_strength * 5.0
	material.scale_min = _warning_bubble_radius / 12.0 * 0.75
	material.scale_max = _warning_bubble_radius / 12.0 * 1.35
	material.lifetime_randomness = 0.2
	material.color_ramp = _create_warning_fade_ramp()
	return material


func _create_warning_fade_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _create_warning_bubble_texture() -> ImageTexture:
	var image := Image.create(WARNING_PARTICLE_TEXTURE_SIZE, WARNING_PARTICLE_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var texture_center := Vector2.ONE * (float(WARNING_PARTICLE_TEXTURE_SIZE) - 1.0) * 0.5
	for y: int in WARNING_PARTICLE_TEXTURE_SIZE:
		for x: int in WARNING_PARTICLE_TEXTURE_SIZE:
			var offset := Vector2(x, y) - texture_center
			var radius_ratio := offset.length() / texture_center.x
			var inner_rim := _smoothstep(0.69, 0.78, radius_ratio)
			var outer_rim := 1.0 - _smoothstep(0.9, 1.0, radius_ratio)
			var highlight := exp(-((offset.x + 4.0) * (offset.x + 4.0) + (offset.y + 4.0) * (offset.y + 4.0)) * 0.09) if radius_ratio < 0.82 else 0.0
			var interior := clampf(1.0 - radius_ratio, 0.0, 1.0) * 0.08
			var alpha := clampf(inner_rim * outer_rim * 0.9 + highlight * 0.55 + interior, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.55, 0.94, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _smoothstep(edge_start: float, edge_end: float, value: float) -> float:
	var progress := clampf((value - edge_start) / (edge_end - edge_start), 0.0, 1.0)
	return progress * progress * (3.0 - 2.0 * progress)
