class_name TiltShiftBall
extends RigidBody2D
## Engine contacts with local acceleration; no global gravity or competing score.

const NEGATIVE_TINT := Color("001a33")

var handle: TiltShiftState.BallHandle
var score_value: int = 1
var previous_position := Vector2.ZERO
var acceleration: float = 400.0
var radius: float = 6.0
var resolved: bool = false
var placeholder_visible := true:
	set(value):
		placeholder_visible = value
		queue_redraw()


func configure(profile: TiltShiftPhysicsTuning, units: float) -> void:
	radius = profile.ball_radius * units
	acceleration = profile.gravity * units
	custom_integrator = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	can_sleep = false
	collision_layer = 1
	collision_mask = 3
	var material := PhysicsMaterial.new()
	material.friction = profile.ball_friction
	material.rough = true
	material.bounce = profile.ball_bounce
	physics_material_override = material
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	collider.shape = shape
	add_child(collider)
	linear_velocity = Vector2(0, profile.entry_speed * units)
	queue_redraw()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not resolved:
		state.linear_velocity.y += acceleration * state.step


func _draw() -> void:
	if not placeholder_visible:
		return
	var color := NEGATIVE_TINT if score_value < 0 else Color("f4e6ad")
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color("78684d"), 1.0, true)
