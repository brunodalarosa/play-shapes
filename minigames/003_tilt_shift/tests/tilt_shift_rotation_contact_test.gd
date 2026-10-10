extends "res://minigames/003_tilt_shift/tests/tilt_shift_physics_test.gd"


func _run() -> void:
	await _test_full_turn_contacts()


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
