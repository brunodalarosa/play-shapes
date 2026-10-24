class_name TiltShift3DBall
extends RigidBody3D
## One ball on the gameplay plane: it falls with its own acceleration, rolls about the depth
## axis only, and reports each new paddle it touches with the speed it closed in at.

## A new contact with [param paddle], closing at [param speed] world units per second.
signal paddle_touched(paddle: TiltShift3DPaddleBody, speed: float)

var handle: TiltShift3DState.BallHandle
var score_value: int = 1
## Last observed position in arena coordinates, X right and Y down from the top-left.
var previous_position := Vector2.ZERO
var acceleration: float = 3.5
var radius: float = 0.3
var resolved: bool = false
var _previous_velocity := Vector3.ZERO
var _touching: Array[TiltShift3DPaddleBody] = []


func configure(profile: TiltShift3DPhysicsTuning, units: float) -> void:
	radius = profile.ball_radius * units
	acceleration = profile.gravity * units
	custom_integrator = true
	continuous_cd = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = 1
	collision_mask = 3
	var material := PhysicsMaterial.new()
	material.friction = profile.ball_friction
	material.rough = true
	material.bounce = profile.ball_bounce
	physics_material_override = material
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.shape = shape
	add_child(collider)
	PlaneLock3D.lock(self, true)
	linear_velocity = Vector3(0.0, -profile.entry_speed * units, 0.0)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var touching: Array[TiltShift3DPaddleBody] = []
	for index: int in state.get_contact_count():
		var paddle := state.get_contact_collider_object(index) as TiltShift3DPaddleBody
		if paddle == null or touching.has(paddle):
			continue
		touching.append(paddle)
		if _touching.has(paddle):
			continue
		# The speed along the contact normal before the solver stopped the ball.
		var paddle_velocity := state.get_contact_collider_velocity_at_position(index)
		var normal := state.get_contact_local_normal(index)
		var closing := absf((_previous_velocity - paddle_velocity).dot(normal))
		paddle_touched.emit(paddle, closing)
	_touching = touching
	if not resolved:
		state.linear_velocity.y -= acceleration * state.step
	_previous_velocity = state.linear_velocity
