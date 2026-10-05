class_name TiltShiftPaddleBody
extends AnimatableBody2D
## Visual and collider share the same physical transform; targets remain unwrapped.

var paddle_id: String
var target_angle: float = 0.0
var applied_angle: float:
	get:
		# Sync-to-physics retains the last confirmed transform until the next server step.
		return _commanded_angle + wrapf(rotation - _commanded_angle, -PI, PI)
var _commanded_angle: float = 0.0
var _maximum_tip_step: float = 3.0
var speed: float = PI
var size := Vector2(100, 10)
var color := Color("ec9644")


func configure(paddle: TiltShiftPaddle, profile: TiltShiftPhysicsTuning, units: float) -> void:
	paddle_id = paddle.paddle_id
	position = paddle.position * units
	size = Vector2(profile.paddle_length, profile.paddle_thickness) * units
	speed = deg_to_rad(profile.rotation_speed_degrees)
	_maximum_tip_step = profile.ball_radius * units * 0.5
	color = Color("ec9644") if paddle.team == 0 else Color("598df2")
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


func advance_pose(delta: float) -> void:
	var maximum_angle := _maximum_tip_step / (size.length() * 0.5)
	var step_size := minf(speed * delta, maximum_angle)
	_commanded_angle = move_toward(_commanded_angle, target_angle, step_size)
	rotation = _commanded_angle


func _draw() -> void:
	draw_rect(Rect2(-size * 0.5, size), color)
	draw_rect(Rect2(-size * 0.5, size), color.darkened(0.4), false, 1.0)
	draw_circle(Vector2.ZERO, size.y * 0.25, Color("f4e6ad"))
