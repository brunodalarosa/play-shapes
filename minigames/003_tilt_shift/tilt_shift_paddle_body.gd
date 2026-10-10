class_name TiltShiftPaddleBody
extends AnimatableBody2D
## Visual and collider share the same physical transform; targets remain unwrapped.

var paddle_id: String
var target_angle: float = 0.0
var auto_rate: float = 0.0
var applied_angle: float:
	get:
		# Sync-to-physics retains the last confirmed transform until the next server step.
		return _commanded_angle + wrapf(rotation - _commanded_angle, -PI, PI)
var _commanded_angle: float = 0.0
var _maximum_tip_step: float = 3.0
var speed: float = PI
var size := Vector2(100, 10)
var color := Color("ec9644")
var placeholder_visible := true:
	set(value):
		placeholder_visible = value
		queue_redraw()


func configure(
	paddle: TiltShiftPaddle,
	profile: TiltShiftPhysicsTuning,
	units: float,
	layout: TiltShiftPaddleLayout = null,
	direction: float = 1.0,
) -> void:
	paddle_id = paddle.paddle_id
	position = paddle.position * units
	size = Vector2(profile.paddle_length, profile.paddle_thickness) * units
	speed = deg_to_rad(profile.rotation_speed_degrees)
	if layout != null:
		size = layout.paddle_size(paddle.team, profile) * units
		if paddle.team == 2:
			auto_rate = deg_to_rad(layout.auto_speed_degrees) * direction
			speed = absf(auto_rate)
	_maximum_tip_step = profile.ball_radius * units * 0.5
	color = [Color("ec9644"), Color("598df2"), Color("929292")][paddle.team]
	collision_layer = 2
	collision_mask = 1
	var material := PhysicsMaterial.new()
	material.friction = profile.paddle_friction
	material.rough = true
	material.bounce = profile.paddle_bounce
	physics_material_override = material
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	collider.shape = shape
	add_child(collider)
	queue_redraw()


func advance_pose(delta: float, auto_active: bool = true) -> void:
	if auto_active:
		target_angle += auto_rate * delta
	var maximum_angle := _maximum_tip_step / (size.length() * 0.5)
	var step_size := minf(speed * delta, maximum_angle)
	_commanded_angle = move_toward(_commanded_angle, target_angle, step_size)
	rotation = _commanded_angle


func _draw() -> void:
	if not placeholder_visible:
		return
	draw_rect(Rect2(-size * 0.5, size), color)
	draw_rect(Rect2(-size * 0.5, size), color.darkened(0.4), false, 1.0)
	draw_circle(Vector2.ZERO, size.y * 0.25, Color("f4e6ad"))
