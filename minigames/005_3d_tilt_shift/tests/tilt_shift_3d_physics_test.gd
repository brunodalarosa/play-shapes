extends TestScript
## Ball and paddle contacts on Jolt, on the plane: the materials' restitution and friction act as
## 2D Tilt Shift's did, balls collide with each other, keep their own acceleration, cannot tunnel
## through a paddle, stay at depth zero and roll only about the depth axis. Each new paddle
## contact is reported once, with the speed it closed in at. Speeds and distances
## are 2D Tilt Shift's, scaled from its 1,000 units per width to 19.2.

const UNITS := TiltShift3DArena.WORLD_UNITS
## World units per 2D Tilt Shift arena unit.
const SCALE := UNITS / 1000.0


func _run() -> void:
	var zero := await _surface_result(0.0, 0.0, 0.0, 0.0)
	var paddle_rebound := await _surface_result(0.0, 0.5, 0.0, 0.0)
	var ball_rebound := await _surface_result(0.5, 0.0, 0.0, 0.0)
	check(zero.x < 2.0 * SCALE, "Zero restitution on both materials suppresses material rebound")
	check(paddle_rebound.x > 70.0 * SCALE, "Nonzero paddle material produces rebound")
	check(ball_rebound.x > 70.0 * SCALE, "Zero paddle bounce does not cancel ball restitution")
	var rough_paddle := await _surface_result(0.0, 0.0, 0.0, 1.0)
	var rough_ball := await _surface_result(0.0, 0.0, 1.0, 0.0)
	check(rough_paddle.y < zero.y - 10 * SCALE, "High paddle friction reduces tangential sliding")
	check(rough_ball.y < zero.y - 10 * SCALE, "Ball friction also contributes at the same contact")
	await _test_ball_collisions()
	await _test_acceleration()
	await _test_fast_impacts()
	await _test_plane()
	await _test_touches()


## Drops a ball onto a level paddle and returns its largest upward speed and its final sideways
## speed.
func _surface_result(
	ball_bounce: float,
	paddle_bounce: float,
	ball_friction: float,
	paddle_friction: float,
) -> Vector2:
	var profile := TiltShift3DPhysicsTuning.new()
	profile.gravity = 0.0
	profile.ball_bounce = ball_bounce
	profile.paddle_bounce = paddle_bounce
	profile.ball_friction = ball_friction
	profile.paddle_friction = paddle_friction
	var scene := Node3D.new()
	root.add_child(scene)
	var paddle := _paddle(scene, profile)
	var top := paddle.position.y + paddle.size.y * 0.5
	var ball := _ball(scene, profile, Vector3(0.0, top + 1.0, 0.0), Vector3(1.92, -3.84, 0.0))
	var maximum_y := -INF
	for tick: int in 30:
		await physics_frame
		await process_frame
		maximum_y = maxf(maximum_y, ball.linear_velocity.y)
		check(ball.position.y > top, "A falling ball stays above the solid paddle")
	var result := Vector2(maximum_y, ball.linear_velocity.x)
	print(
		"Contact ball/paddle bounce=%s/%s friction=%s/%s result=%s"
		% [ball_bounce, paddle_bounce, ball_friction, paddle_friction, result]
	)
	scene.queue_free()
	await process_frame
	return result


func _paddle(scene: Node, profile: TiltShift3DPhysicsTuning) -> TiltShift3DPaddleBody:
	var content := TiltShift3DPaddle.new()
	content.paddle_id = "contact_surface"
	var paddle := TiltShift3DPaddleBody.new()
	paddle.configure(content, profile, UNITS)
	scene.add_child(paddle)
	return paddle


func _ball(
	scene: Node,
	profile: TiltShift3DPhysicsTuning,
	position: Vector3,
	velocity: Vector3,
) -> TiltShift3DBall:
	var ball := TiltShift3DBall.new()
	ball.configure(profile, UNITS)
	ball.position = position
	ball.linear_velocity = velocity
	scene.add_child(ball)
	return ball


func _test_ball_collisions() -> void:
	var profile := TiltShift3DPhysicsTuning.new()
	profile.gravity = 0.0
	profile.ball_bounce = 0.5
	var scene := Node3D.new()
	root.add_child(scene)
	var a := _ball(scene, profile, Vector3(-0.4, 0.0, 0.0), Vector3(1.92, 0.0, 0.0))
	var b := _ball(scene, profile, Vector3(0.4, 0.0, 0.0), Vector3(-1.92, 0.0, 0.0))
	for tick: int in 20:
		await physics_frame
		await process_frame
	check(
		a.linear_velocity.x < -50 * SCALE and b.linear_velocity.x > 50 * SCALE,
		"Two native ball bodies collide and exchange momentum",
	)
	check(
		a.position.distance_to(b.position) >= a.radius + b.radius - 0.5 * SCALE,
		"Ball pair does not remain interpenetrating",
	)
	scene.queue_free()
	await process_frame


func _test_fast_impacts() -> void:
	var profile := TiltShift3DPhysicsTuning.new()
	profile.gravity = 0.0
	var scene := Node3D.new()
	root.add_child(scene)
	_paddle(scene, profile)
	var ball := _ball(scene, profile, Vector3(0.0, 1.0, 0.0), Vector3(0.0, -UNITS, 0.0))
	for tick: int in 8:
		await physics_frame
		await process_frame
		check(ball.position.y > 0.0, "A 1-width/s ball cannot tunnel through the default paddle")
	scene.queue_free()
	await process_frame


func _test_acceleration() -> void:
	var low := TiltShift3DPhysicsTuning.new()
	low.gravity = 0.2
	var high := TiltShift3DPhysicsTuning.new()
	high.gravity = 0.8
	var scene := Node3D.new()
	root.add_child(scene)
	var slow := _ball(scene, low, Vector3(-4.0, 0.0, 0.0), Vector3(0.0, -1.92, 0.0))
	var fast := _ball(scene, high, Vector3(0.0, 0.0, 0.0), Vector3(0.0, -1.92, 0.0))
	var entered := _ball(scene, low, Vector3(4.0, 0.0, 0.0), Vector3(0.0, -5.76, 0.0))
	var global_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	for tick: int in 12:
		await physics_frame
		await process_frame
	check(
		fast.linear_velocity.y < slow.linear_velocity.y - 80 * SCALE,
		"Higher local gravity accelerates free fall more strongly",
	)
	check(
		absf(slow.linear_velocity.y - entered.linear_velocity.y - 200 * SCALE) < 0.1 * SCALE,
		"Initial entry speed remains separate from identical acceleration",
	)
	check(
		ProjectSettings.get_setting("physics/3d/default_gravity") == global_gravity,
		"Ball acceleration leaves unrelated global gravity unchanged",
	)
	scene.queue_free()
	await process_frame


func _test_plane() -> void:
	var profile := TiltShift3DPhysicsTuning.new()
	var scene := Node3D.new()
	root.add_child(scene)
	var paddle := _paddle(scene, profile)
	paddle.target_angle = 0.3
	var ball := _ball(scene, profile, Vector3(0.5, 1.5, 0.0), Vector3(0.0, 0.0, 2.0))
	ball.angular_velocity = Vector3(3.0, 3.0, 0.0)
	var rolled := false
	for tick: int in 90:
		paddle.advance_pose(1.0 / 60.0)
		await physics_frame
		await process_frame
		check(PlaneLock3D.is_on_plane(ball, 0.001, true), "A ball stays on the plane")
		check(PlaneLock3D.is_on_plane(paddle, 0.001, true), "A paddle turns only about depth")
		rolled = rolled or absf(ball.angular_velocity.z) > 0.5
	check(rolled, "A ball rolling down a tilted paddle turns about the depth axis")
	check(ball.position.x > 0.5, "A ball rolls down a paddle tilted clockwise, to the right")
	check(is_equal_approx(paddle.applied_angle, 0.3), "The paddle reaches its target")
	check(
		is_equal_approx(paddle.rotation.z, -0.3),
		"A positive angle turns clockwise on screen, a negative turn about +Z",
	)
	scene.queue_free()
	await process_frame


func _test_touches() -> void:
	var profile := TiltShift3DPhysicsTuning.new()
	profile.gravity = 0.0
	var scene := Node3D.new()
	root.add_child(scene)
	var paddle := _paddle(scene, profile)
	var top := paddle.size.y * 0.5
	var ball := _ball(scene, profile, Vector3(0.0, top + 0.6, 0.0), Vector3(0.0, -3.0, 0.0))
	var touches: Array[float] = []
	ball.paddle_touched.connect(
		func(touched: TiltShift3DPaddleBody, speed: float) -> void:
			check(touched == paddle, "The touched paddle is reported")
			touches.append(speed),
	)
	for tick: int in 60:
		await physics_frame
		await process_frame
	check(touches.size() == 1, "A ball resting on a paddle reports its contact once")
	check(
		not touches.is_empty() and absf(touches[0] - 3.0) < 0.2,
		"The contact reports the speed the ball closed in at",
	)
	scene.queue_free()
	await process_frame
