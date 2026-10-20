extends "res://minigames/005_3d_tilt_shift/tests/tilt_shift_3d_physics_test.gd"
## A paddle turning through full turns and back pushes a resting ball without letting it sink
## more than half its radius into the rounded collider, and its pose follows the applied angle.


func _run() -> void:
	await _test_full_turn_contacts()


func _test_full_turn_contacts() -> void:
	var profile := TiltShift3DPhysicsTuning.new()
	profile.gravity = 0.0
	var scene := Node3D.new()
	root.add_child(scene)
	var paddle := _paddle(scene, profile)
	var reach := paddle.size.x * 0.35
	var start := Vector3(reach, -(paddle.size.y * 0.5 + 0.3), 0.0)
	var ball := _ball(scene, profile, start, Vector3.ZERO)
	var touched := false
	var maximum_penetration := 0.0
	var half := Vector2(paddle.size.x, paddle.size.y) * 0.5
	for tick: int in 480:
		paddle.target_angle = TAU * 2 if tick < 240 else 0.0
		paddle.advance_pose(1.0 / 60.0)
		await physics_frame
		await process_frame
		touched = touched or ball.linear_velocity.length() > 1.0 * SCALE
		var local := paddle.to_local(ball.position)
		var flat := Vector2(local.x, local.y)
		# The rounded collider lies inside this rectangle, so this overstates any penetration.
		var penetration := ball.radius - flat.distance_to(flat.clamp(-half, half))
		maximum_penetration = maxf(maximum_penetration, penetration)
		check(
			ball.position.is_finite() and ball.linear_velocity.is_finite(),
			"Full turns and wrap reversals keep contact state finite",
		)
		check(
			absf(wrapf(-paddle.rotation.z - paddle.applied_angle, -PI, PI)) < 0.001,
			"Actual collider/visual pose follows the unwrapped physical angle",
		)
	check(touched, "A rotating paddle physically pushes a stationary ball with zero bounce")
	check(
		maximum_penetration < ball.radius * 0.5,
		"Rotation contacts stay within half a ball radius of transient penetration",
	)
	print("Rotation maximum transient penetration: ", maximum_penetration, " world units")
	scene.queue_free()
	await process_frame
