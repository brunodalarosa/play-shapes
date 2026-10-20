class_name TiltShift3DPaddleBody
extends AnimatableBody3D
## One paddle on the gameplay plane, turned by code about the depth axis. Its collider is the
## rounded bar the player sees, built from the same measurements. Angles are the rules' angles:
## positive turns clockwise on screen, and targets stay unwrapped across full turns.

var paddle_id: String
var team: int = 0
var target_angle: float = 0.0
var auto_rate: float = 0.0
## The confirmed physical angle. Sync-to-physics keeps the last confirmed transform until the
## next physics step, so this can trail the commanded angle by one tick.
var applied_angle: float:
	get:
		return _commanded_angle + wrapf(-rotation.z - _commanded_angle, -PI, PI)
## Length, thickness and depth in world units.
var size := Vector3(1.92, 0.768, 0.768)
var corner_radius: float = 0.27
## Applied turning speed over the last step, in radians per second, either direction.
var angular_speed: float = 0.0
var speed: float = PI
var _commanded_angle: float = 0.0
var _maximum_tip_step: float = 0.15


func configure(
	paddle: TiltShift3DPaddle,
	profile: TiltShift3DPhysicsTuning,
	units: float,
	layout: TiltShift3DPaddleLayout = null,
	direction: float = 1.0,
) -> void:
	paddle_id = paddle.paddle_id
	team = paddle.team
	var dimensions := Vector2(profile.paddle_length, profile.paddle_thickness)
	speed = deg_to_rad(profile.rotation_speed_degrees)
	if layout != null:
		dimensions = layout.paddle_size(paddle.team, profile)
		if paddle.team == TiltShift3DTypes.Team.TRASH:
			auto_rate = deg_to_rad(layout.auto_speed_degrees) * direction
			speed = absf(auto_rate)
	size = Vector3(dimensions.x, dimensions.y, dimensions.y * profile.depth_ratio) * units
	corner_radius = size.y * profile.corner_radius_ratio
	_maximum_tip_step = profile.ball_radius * units * 0.5
	collision_layer = 2
	collision_mask = 1
	var material := PhysicsMaterial.new()
	material.friction = profile.paddle_friction
	material.rough = true
	material.bounce = profile.paddle_bounce
	physics_material_override = material
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.shape = RoundedBar.shape(size.x, size.y, size.z, corner_radius)
	add_child(collider)


func advance_pose(delta: float, auto_active: bool = true) -> void:
	if auto_active:
		target_angle += auto_rate * delta
	# Bounded so the tip moves at most half a ball radius per step and cannot skip a ball.
	var maximum_angle := _maximum_tip_step / (Vector2(size.x, size.y).length() * 0.5)
	var step_size := minf(speed * delta, maximum_angle)
	var previous := _commanded_angle
	_commanded_angle = move_toward(_commanded_angle, target_angle, step_size)
	angular_speed = absf(_commanded_angle - previous) / delta if delta > 0.0 else 0.0
	# The rules turn clockwise on screen for positive angles; +Z turns counter-clockwise.
	rotation = Vector3(0.0, 0.0, -_commanded_angle)
