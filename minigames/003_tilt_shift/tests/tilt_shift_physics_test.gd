extends TestScript


func _run() -> void:
	var zero := await _surface_result(0.0, 0.0, 0.0, 0.0)
	var paddle_rebound := await _surface_result(0.0, 0.5, 0.0, 0.0)
	var ball_rebound := await _surface_result(0.5, 0.0, 0.0, 0.0)
	check(zero.x > -2.0, "Zero restitution on both materials suppresses material rebound")
	check(paddle_rebound.x < -70.0, "Nonzero paddle material produces rebound")
	check(ball_rebound.x < -70.0, "Zero paddle bounce does not cancel ball restitution")
	var rough_paddle := await _surface_result(0.0, 0.0, 0.0, 1.0)
	var rough_ball := await _surface_result(0.0, 0.0, 1.0, 0.0)
	check(rough_paddle.y < zero.y - 10, "High paddle friction reduces tangential sliding")
	check(rough_ball.y < zero.y - 10, "Ball friction also contributes at the same contact")
	await _test_ball_collisions()
	await _test_acceleration()
	await _test_fast_impacts()
	await _test_full_turn_contacts()


func _surface_result(
	ball_bounce: float,
	paddle_bounce: float,
	ball_friction: float,
	paddle_friction: float,
) -> Vector2:
	var profile := TiltShiftPhysicsTuning.new()
	profile.gravity = 0.0
	profile.ball_bounce = ball_bounce
	profile.paddle_bounce = paddle_bounce
	profile.ball_friction = ball_friction
	profile.paddle_friction = paddle_friction
	var scene := Node2D.new()
	root.add_child(scene)
	var paddle := _paddle(scene, profile)
	var ball := _ball(scene, profile, Vector2(500, 260), Vector2(100, 200))
	var minimum_y := 200.0
	for tick: int in 20:
		await physics_frame
		await process_frame
		minimum_y = minf(minimum_y, ball.linear_velocity.y)
		check(
			ball.position.y < paddle.position.y + 1,
			"A falling ball stays above the solid paddle",
		)
	var result := Vector2(minimum_y, ball.linear_velocity.x)
	print(
		"Contact ball/paddle bounce=",
		ball_bounce,
		"/",
		paddle_bounce,
		" friction=",
		ball_friction,
		"/",
		paddle_friction,
		" result=",
		result,
	)
	scene.queue_free()
	await process_frame
	return result


func _paddle(scene: Node, profile: TiltShiftPhysicsTuning) -> TiltShiftPaddleBody:
	var content := TiltShiftPaddle.new()
	content.paddle_id = "contact_surface"
	content.position = Vector2(0.5, 0.3)
	var paddle := TiltShiftPaddleBody.new()
	paddle.configure(content, profile, TiltShiftArena.WORLD_UNITS)
	scene.add_child(paddle)
	return paddle


func _ball(
	scene: Node,
	profile: TiltShiftPhysicsTuning,
	position: Vector2,
	velocity: Vector2,
) -> TiltShiftBall:
	var ball := TiltShiftBall.new()
	ball.configure(profile, TiltShiftArena.WORLD_UNITS)
	ball.position = position
	ball.linear_velocity = velocity
	scene.add_child(ball)
	return ball


func _test_ball_collisions() -> void:
	var profile := TiltShiftPhysicsTuning.new()
	profile.gravity = 0.0
	profile.ball_bounce = 0.5
	var scene := Node2D.new()
	root.add_child(scene)
	var a := _ball(scene, profile, Vector2(300, 100), Vector2(100, 0))
	var b := _ball(scene, profile, Vector2(340, 100), Vector2(-100, 0))
	for tick: int in 20:
		await physics_frame
		await process_frame
	check(
		a.linear_velocity.x < -50 and b.linear_velocity.x > 50,
		"Two native ball bodies collide and exchange momentum",
	)
	check(
		a.position.distance_to(b.position) >= a.radius + b.radius - 0.5,
		"Ball pair does not remain interpenetrating",
	)
	scene.queue_free()
	await process_frame


func _test_fast_impacts() -> void:
	var profile := TiltShiftPhysicsTuning.new()
	profile.gravity = 0.0
	var scene := Node2D.new()
	root.add_child(scene)
	_paddle(scene, profile)
	var ball := _ball(scene, profile, Vector2(500, 250), Vector2(0, 1000))
	for tick: int in 8:
		await physics_frame
		await process_frame
		check(ball.position.y < 300, "A 1-width/s ball cannot tunnel through the default paddle")
	scene.queue_free()
	await process_frame


func _test_acceleration() -> void:
	var low := TiltShiftPhysicsTuning.new()
	low.gravity = 0.2
	var high := TiltShiftPhysicsTuning.new()
	high.gravity = 0.8
	var scene := Node2D.new()
	root.add_child(scene)
	var slow := _ball(scene, low, Vector2(100, 20), Vector2(0, 100))
	var fast := _ball(scene, high, Vector2(200, 20), Vector2(0, 100))
	var entered := _ball(scene, low, Vector2(300, 20), Vector2(0, 300))
	var global_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	for tick: int in 12:
		await physics_frame
		await process_frame
	check(
		fast.linear_velocity.y > slow.linear_velocity.y + 80,
		"Higher local gravity accelerates free fall more strongly",
	)
	check(
		absf(entered.linear_velocity.y - slow.linear_velocity.y - 200) < 0.1,
		"Initial entry speed remains separate from identical acceleration",
	)
	check(
		ProjectSettings.get_setting("physics/2d/default_gravity") == global_gravity,
		"Ball acceleration leaves unrelated global gravity unchanged",
	)
	scene.queue_free()
	await process_frame


func _test_full_turn_contacts() -> void:
	var profile := TiltShiftPhysicsTuning.new()
	profile.gravity = 0.0
	var scene := Node2D.new()
	root.add_child(scene)
	var paddle := _paddle(scene, profile)
	var ball := _ball(scene, profile, Vector2(539, 285), Vector2.ZERO)
	var touched := false
	var maximum_penetration := 0.0
	for tick: int in 480:
		paddle.target_angle = TAU * 2 if tick < 240 else 0.0
		paddle.advance_pose(1.0 / 60.0)
		await physics_frame
		await process_frame
		touched = touched or ball.linear_velocity.length() > 1.0
		var local := paddle.to_local(ball.position)
		var closest := local.clamp(-paddle.size * 0.5, paddle.size * 0.5)
		var penetration := ball.radius - local.distance_to(closest)
		maximum_penetration = maxf(maximum_penetration, penetration)
		check(
			ball.position.is_finite() and ball.linear_velocity.is_finite(),
			"Full turns and wrap reversals keep contact state finite",
		)
		check(
			absf(wrapf(paddle.rotation - paddle.applied_angle, -PI, PI)) < 0.001,
			"Actual collider/visual pose follows the unwrapped physical angle",
		)
	check(touched, "A rotating paddle physically pushes a stationary ball with zero bounce")
	check(
		maximum_penetration < ball.radius * 0.5,
		"Rotation contacts stay within half a ball radius of transient penetration",
	)
	print("Rotation maximum transient penetration: ", maximum_penetration, " pixels")
	scene.queue_free()
	await process_frame
