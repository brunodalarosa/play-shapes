extends TestScript


func _run() -> void:
	var profile := TiltShiftPhysicsTuning.new()
	profile.ball_count = 100
	var uniform := TiltShiftDelivery.schedule(profile.ball_count, profile.delivery_curve, 10000)
	profile.delivery_curve = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(0.2, 0),
			Vector2(0.4, 4),
			Vector2(0.6, 4),
			Vector2(0.8, 0),
			Vector2(1, 0),
		]
	)
	var middle := TiltShiftDelivery.schedule(profile.ball_count, profile.delivery_curve, 10000)
	check(uniform.size() == 100 and middle.size() == 100, "Curve shape preserves the ball budget")
	check(uniform[0] < 100 and middle[0] > 2000, "Busy middle visibly delays the first delivery")
	for offset: int in middle:
		check(offset > 2000 and offset < 8000, "Zero-intensity spans receive no scheduled balls")
		check(offset < 10000, "Every delivery precedes the exclusive deadline")
	profile.delivery_curve = PackedVector2Array(
		[Vector2(0, 1), Vector2(0.25, 0), Vector2(0.75, 0), Vector2(1, 1)]
	)
	var plateau := TiltShiftDelivery.schedule(profile.ball_count, profile.delivery_curve, 10000)
	for offset: int in plateau:
		check(offset < 2500 or offset > 7500, "An interior zero-weight plateau receives no balls")
	profile.delivery_curve = PackedVector2Array([Vector2(0, 0), Vector2(1, 0)])
	check(not profile.validation_errors().is_empty(), "Positive budget rejects an all-zero curve")
	profile.ball_count = 0
	check(profile.validation_errors().is_empty(), "Zero budget allows an empty delivery round")
	profile.ball_count = 1
	profile.delivery_curve = PackedVector2Array([Vector2(0, 1), Vector2(0.5, -1), Vector2(1, 1)])
	check(not profile.validation_errors().is_empty(), "Negative intensity fails validation")
	profile.delivery_curve = PackedVector2Array([Vector2(0, 1), Vector2(0, 1), Vector2(1, 1)])
	check(not profile.validation_errors().is_empty(), "Duplicate curve progress fails validation")
	profile.delivery_curve = PackedVector2Array([Vector2(0, NAN), Vector2(1, 1)])
	check(not profile.validation_errors().is_empty(), "Non-finite intensity fails validation")
	profile.delivery_curve = PackedVector2Array([Vector2(0, 0), Vector2(0.99999, 0), Vector2(1, 1)])
	var selected := TiltShiftFixtures.tuning()
	selected.physics = profile
	check(
		not selected.validation_errors().is_empty(),
		"Sub-millisecond delivery support fails launch",
	)
	selected = TiltShiftFixtures.tuning()
	selected.physics.ball_bounce = INF
	var controller := TiltShiftShiftController.new()
	controller.tuning = selected
	check(
		not controller.start_shift(TiltShiftFixtures.players(10), 0).accepted,
		"Invalid physics is rejected before authoritative play begins",
	)
	controller.free()
	selected = TiltShiftFixtures.tuning()
	selected.physics.spawn_half_width = 0.49
	selected.physics.ball_radius = 0.02
	check(
		not selected.validation_errors().is_empty(),
		"Entry bounds require ball clearance at walls",
	)
