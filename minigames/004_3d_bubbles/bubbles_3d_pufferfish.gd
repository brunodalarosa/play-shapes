class_name Bubbles3DPufferfish
extends Area3D
## One pufferfish crossing: an optional burst of small bubbles at its entry edge, then one
## straight pass across the plane. It turns to face its travel, showing its side, and tilts at
## most 35 degrees on diagonals. It only watches for bubbles.

const MODEL: PackedScene = preload(
	"res://assets/runtime/minigames/bubbles_3d/pufferfish/pufferfish.glb"
)
## Diameter of the model's round body at scale one.
const BODY_DIAMETER := 0.895
## The drawn body is this much wider than the collider, so spikes overlap it a little.
const BODY_TO_COLLIDER := 1.1
const MAX_TILT := deg_to_rad(35.0)

var creature_id := 0
var radius := 0.51
var start_position := Vector2.ZERO
var end_position := Vector2.ZERO
var direction := Vector2.RIGHT
var warning_until_msec := 0
var active := false
var finished := false
var _speed := 0.0
var _travelled := 0.0
var _path_length := 0.0
var _jiggle_degrees := 3.5
var _jiggle_period := 0.32
var _jiggle_squash := 0.035
var _swim_seconds := 0.0
var _heading := Basis.IDENTITY
var _size := 1.0
var _model: Node3D
var _sphere := SphereShape3D.new()
var _warning: CPUParticles3D


func _init() -> void:
	monitorable = false
	var shape := CollisionShape3D.new()
	shape.shape = _sphere
	add_child(shape)
	_model = MODEL.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	_warning = _make_warning()
	add_child(_warning)


func configure(
	id: int,
	tuning: Bubbles3DTuning,
	at_msec: int,
	start: Vector2,
	destination: Vector2,
	watched_layers: int,
	own_layer: int,
) -> void:
	creature_id = id
	radius = tuning.pufferfish_radius()
	_sphere.radius = radius
	collision_layer = own_layer
	collision_mask = watched_layers
	start_position = start
	end_position = destination
	_path_length = start.distance_to(destination)
	direction = (destination - start).normalized()
	_speed = tuning.pufferfish_speed
	_jiggle_degrees = tuning.pufferfish_jiggle_degrees
	_jiggle_period = tuning.pufferfish_jiggle_period_seconds
	_jiggle_squash = tuning.pufferfish_jiggle_squash
	_size = radius * 2.0 * BODY_TO_COLLIDER / BODY_DIAMETER
	var yaw := 0.0 if direction.x >= 0.0 else PI
	var tilt := clampf(atan2(direction.y, absf(direction.x)), -MAX_TILT, MAX_TILT)
	_heading = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, tilt)
	var warning_seconds := (
		tuning.pufferfish_warning_seconds if tuning.pufferfish_warning_enabled else 0.0
	)
	warning_until_msec = at_msec + roundi(warning_seconds * 1000.0)
	position = PlaneLock3D.on_plane(start)
	_model.visible = false
	monitoring = false
	_update_body()
	if warning_seconds > 0.0:
		_warning.amount = tuning.pufferfish_telegraph_bubble_count
		_warning.lifetime = warning_seconds + 0.35
		_warning.direction = Vector3(direction.x, direction.y, 0.0)
		var bubble_size := tuning.pufferfish_telegraph_bubble_radius / 0.06
		_warning.scale_amount_min = 0.7 * bubble_size
		_warning.scale_amount_max = 1.4 * bubble_size
		# The burst starts on the visible side of the edge the pufferfish will cross.
		_warning.position = Vector3(direction.x, direction.y, 0.0) * (radius + 0.6)
		_warning.restart()
		_warning.emitting = true
	else:
		simulate_step(0.0, at_msec)


func simulate_step(delta: float, host_time_msec: int) -> void:
	if finished:
		return
	var moving := delta
	if not active:
		if host_time_msec < warning_until_msec:
			return
		active = true
		monitoring = true
		_model.visible = true
		position = PlaneLock3D.on_plane(start_position)
		moving = minf(delta, maxf(0.0, float(host_time_msec - warning_until_msec) / 1000.0))
	_travelled += _speed * moving
	var along := minf(_travelled, _path_length)
	position = PlaneLock3D.on_plane(start_position + direction * along)
	_swim_seconds += moving
	_update_body()
	if _travelled >= _path_length:
		finished = true
		visible = false
		monitoring = false


func can_hit_player() -> bool:
	return active and not finished


func plane_position() -> Vector2:
	return PlaneLock3D.plane_point(position)


func _update_body() -> void:
	var wave := sin(TAU * _swim_seconds / _jiggle_period)
	var jiggle := Basis(Vector3.BACK, deg_to_rad(_jiggle_degrees) * wave)
	var squash := Vector3(1.0 + wave * _jiggle_squash * 0.35, 1.0 - wave * _jiggle_squash, 1.0)
	_model.basis = _heading * jiggle * Basis.from_scale(squash * _size)


func _make_warning() -> CPUParticles3D:
	var burst := CPUParticles3D.new()
	burst.name = "Warning"
	burst.emitting = false
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.randomness = 1.0
	burst.local_coords = false
	burst.spread = 24.0
	burst.initial_velocity_min = 0.95
	burst.initial_velocity_max = 1.8
	burst.gravity = Vector3(0.0, 0.2, 0.0)
	burst.tangential_accel_min = -0.15
	burst.tangential_accel_max = 0.15
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	burst.color_ramp = fade
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.7, 0.95, 1.0)
	mesh.material = material
	burst.mesh = mesh
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return burst
