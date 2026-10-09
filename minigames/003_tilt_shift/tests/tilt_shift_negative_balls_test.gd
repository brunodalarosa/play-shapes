extends TestScript

const Model := preload("res://addons/tilt_shift_workshop/workshop_model.gd")
const Graph := preload("res://addons/tilt_shift_workshop/workshop_delivery_graph.gd")
const WorkshopPanel := preload("res://addons/tilt_shift_workshop/workshop_panel.gd")
const DEFAULT := "res://minigames/003_tilt_shift/tuning/Default.tres"


func _run() -> void:
	_test_delivery()
	_test_scoring()
	await _test_arena()
	await _test_presentation()
	_test_workshop()
	await _test_tunable_controls()


func _test_delivery() -> void:
	var profile := TiltShiftPhysicsTuning.new()
	var points := profile.negative_delivery_curve
	var schedule := TiltShiftDelivery.schedule(20, points, 10000, true)
	check(schedule.size() == 20, "Smooth negative delivery preserves its independent budget")
	for offset: int in schedule:
		check(offset > 2000 and offset < 9000, "Negative deliveries stay between 20% and 90%")
	check(
		is_equal_approx(TiltShiftDelivery.intensity(points, 0.7, true), 1.0),
		"Negative intensity peaks at 70%",
	)
	for progress: float in [0.0, 0.1, 0.2, 0.9, 1.0]:
		check(
			TiltShiftDelivery.intensity(points, progress, true) == 0.0,
			"Empty spans include the start and stop boundaries",
		)
	for knot: Vector2 in points:
		var before := TiltShiftDelivery.intensity(points, knot.x - 0.0001, true)
		var after := TiltShiftDelivery.intensity(points, knot.x + 0.0001, true)
		check(absf(after - before) < 0.00001, "Smooth joins have no intensity jump or sharp slope")
	# Numerical integration checks the scheduler's quantiles independently of its inverse formula.
	var integrated := 0.0
	var cursor := 0
	var weight := TiltShiftDelivery.total_weight(points)
	for index: int in 10000:
		integrated += TiltShiftDelivery.intensity(points, (index + 0.5) / 10000.0, true) / 10000.0
		if cursor < schedule.size() and index == schedule[cursor]:
			var expected := weight * (cursor + 0.5) / schedule.size()
			check(
				absf(integrated - expected) < 0.0002,
				"Smooth schedule follows integrated density",
			)
			cursor += 1
	check(cursor == 20, "Independent integration checked every negative delivery")
	profile.negative_delivery_curve = PackedVector2Array([Vector2(0, 0), Vector2(1, 0)])
	check(not profile.validation_errors().is_empty(), "Negative budget rejects a zero-weight curve")
	profile.negative_ball_count = 0
	check(
		profile.validation_errors().is_empty(),
		"Zero negative budget permits disabling penalties",
	)
	profile.negative_delivery_curve = PackedVector2Array([Vector2(0, 0), Vector2(0, 1)])
	check(not profile.validation_errors().is_empty(), "Malformed negative curves fail validation")
	var selected := TiltShiftFixtures.tuning(1)
	selected.physics.negative_ball_count = 20
	selected.physics.negative_delivery_curve = PackedVector2Array(
		[Vector2(0, 0), Vector2(0.99999, 0), Vector2(1, 1)]
	)
	check(
		not selected.validation_errors().is_empty(),
		"Unrepresentable negative schedules reject launch",
	)


func _test_scoring() -> void:
	var controller := TiltShiftShiftController.new()
	controller.tuning = TiltShiftFixtures.tuning(2)
	root.add_child(controller)
	controller.start_shift(TiltShiftFixtures.players(2), 0)
	var token := controller.snapshot().round_token
	for basket: String in ["orange_left", "blue_left"]:
		var negative := controller.register_ball(token, 0, -1).ball
		check(
			controller.resolve_ball(negative, basket, 0).accepted,
			"Zero-score negative catch resolves",
		)
		check(controller.snapshot().scores == [0, 0], "Neither team can have a negative score")
		check(
			not controller.resolve_ball(negative, basket, 0).accepted,
			"A negative catch cannot be counted twice",
		)
	var positive := controller.register_ball(token, 0).ball
	controller.resolve_ball(positive, "orange_left", 0)
	var penalty := controller.register_ball(token, 0, -1).ball
	controller.resolve_ball(penalty, "orange_left", 0)
	check(controller.snapshot().scores == [0, 0], "One negative catch removes exactly one point")
	controller._scores[0] = TiltShiftShiftController.MAX_SCORE
	positive = controller.register_ball(token, 0).ball
	controller.resolve_ball(positive, "orange_left", 0)
	check(
		controller.snapshot().scores[0] == TiltShiftShiftController.MAX_SCORE,
		"Positive catches saturate at the integer maximum without overflowing",
	)
	penalty = controller.register_ball(token, 0, -1).ball
	controller.resolve_ball(penalty, "orange_left", 0)
	check(
		controller.snapshot().scores[0] == TiltShiftShiftController.MAX_SCORE - 1,
		"A penalty still subtracts at the integer maximum",
	)
	var before := controller.snapshot().scores
	for discarded: bool in [false, true]:
		var ball := controller.register_ball(token, 0, -1).ball
		if discarded:
			controller.discard_ball(ball, 0)
		else:
			controller.resolve_ball(ball, "trash_center", 0)
		check(
			controller.snapshot().scores == before,
			"Trash and discarded negative balls never score",
		)
	check(not controller.register_ball(token, 0, 2).accepted, "Unknown score values are rejected")
	var stale := controller.register_ball(token, 0, -1).ball
	controller.advance(1000)
	check(
		not controller.resolve_ball(stale, "orange_left", 1000).accepted,
		"Deadline rejects penalties",
	)
	controller.start_next_round(1001)
	check(
		not controller.resolve_ball(stale, "orange_left", 1001).accepted,
		"Old penalties cannot cross rounds",
	)
	check(controller._ball_values.is_empty(), "Round transition clears registered score values")
	controller.free()


func _test_arena() -> void:
	var selected := TiltShiftFixtures.tuning(1)
	selected.round_duration_seconds = 10.0
	selected.physics.ball_count = 60
	selected.physics.negative_ball_count = 20
	selected.physics.delivery_cutoff_seconds = 6.0
	var arena := TiltShiftArena.new()
	arena.clock = func() -> int:
		return 0
	root.add_child(arena)
	arena.set_physics_process(false)
	check(
		arena.start_shift(selected, TiltShiftFixtures.players(10)).accepted,
		"Mixed-ball arena launches",
	)
	for offset: int in range(0, 10000, 10):
		arena.step(0, offset)
		if offset <= 2000:
			check(
				arena.negative_spawned_count == 0,
				"Negative arena delivery waits until after 20%",
			)
		if offset >= 9000:
			check(
				arena.negative_spawned_count == 20,
				"Negative delivery ends by 90% of the full round",
			)
	check(
		arena.positive_spawned_count == 60 and arena.spawned_count == 80,
		"Independent schedules add twenty penalties without replacing positive balls",
	)
	for ball: TiltShiftBall in arena.live_balls():
		check(
			ball.position.x >= 100 and ball.position.x <= 900,
			"Both ball types share the centered spawn area",
		)
	var negative: TiltShiftBall
	for ball: TiltShiftBall in arena.live_balls():
		if ball.score_value < 0:
			negative = ball
			break
	check(negative != null, "The arena marks spawned penalties for presentation")
	var state := arena.controller.snapshot()
	var height := state.paddle_layout.arena_size.y * TiltShiftArena.WORLD_UNITS
	negative.score_value = 1
	negative.previous_position = Vector2(100, height - 10)
	negative.position = Vector2(100, height + 1)
	arena.step(0, 9999)
	check(
		arena.controller.snapshot().scores == [0, 0],
		"Body edits cannot change the host-registered penalty",
	)
	arena.step(0, 10000)
	check(arena.live_balls().is_empty(), "Mixed balls clear at the scoring deadline")
	arena.stop()
	arena.start_shift(selected, TiltShiftFixtures.players(10))
	arena.step(0, 9000)
	check(
		arena.negative_spawned_count == 0,
		"A hitch cannot deliver penalties in the final zero span",
	)
	arena.stop()
	arena.queue_free()
	await process_frame


func _test_presentation() -> void:
	var source: TiltShiftTuning = load(DEFAULT)
	check(
		source.physics.ball_count == 60 and source.physics.negative_ball_count == 20,
		"Saved production content selects sixty white and twenty dark blue balls",
	)
	check(
		is_equal_approx(source.physics.ball_radius, 0.0138 * 1.15),
		"Default ball radius grows another 15%",
	)
	var profile := TiltShiftFixtures.tuning(1)
	profile.physics.ball_radius = source.physics.ball_radius
	profile.physics.negative_ball_color = Color("3498db")
	profile.physics.negative_ball_count = 20
	var presentation := TiltShiftPresentation.new()
	root.add_child(presentation)
	presentation.arena.clock = func() -> int:
		return 0
	presentation.arena.set_physics_process(false)
	check(
		presentation.start_shift(profile, TiltShiftFixtures.players(2)).accepted,
		"Tint fixture launches",
	)
	profile.physics.negative_ball_color = Color.RED
	for value: int in [1, -1]:
		var ball := presentation.arena._spawn(0, value)
		var collider := ball.get_node("CollisionShape2D") as CollisionShape2D
		var visual := ball.get_child(1) as Sprite2D
		check(
			is_equal_approx((collider.shape as CircleShape2D).radius, 15.87),
			"Both colliders use the enlarged radius",
		)
		check(visual != null, "Both ball types reuse the existing sprite")
		if value < 0:
			var material := visual.material as ShaderMaterial
			check(material != null, "Negative balls use the white-rim sprite material")
			check(
				material.get_shader_parameter("ball_color") == Color("3498db"),
				"Negative ball shading uses the selected tint tunable",
			)
		else:
			check(visual.material == null, "Positive sprites retain their original appearance")
		check(visual.modulate == Color.WHITE, "Sprite modulation leaves the negative rim white")
		var region := TiltShiftArt.bounds("gameplay/ball")
		check(
			is_equal_approx(visual.scale.x * maxf(region.size.x, region.size.y), ball.radius * 2),
			"Shared sprite dimensions follow the enlarged collider",
		)
	presentation.stop()
	await process_frame
	check(
		presentation.start_shift(profile, TiltShiftFixtures.players(2)).accepted,
		"A fresh shift accepts edited color tunables",
	)
	var recolored := presentation.arena._spawn(0, -1)
	var recolored_visual := recolored.get_child(1) as Sprite2D
	var recolored_material := recolored_visual.material as ShaderMaterial
	check(
		recolored_material.get_shader_parameter("ball_color") == Color.RED,
		"Restart applies the new tint even when the sprite material is reused",
	)
	presentation.stop()
	presentation.queue_free()
	await process_frame


func _test_workshop() -> void:
	var model := Model.new()
	check(model.load_profile(DEFAULT), "Workshop loads the negative delivery tunables")
	var original := model.profile.physics.negative_delivery_curve.duplicate()
	model.begin_edit()
	model.profile.physics.negative_ball_count = 31
	model.profile.physics.negative_ball_color = Color("3498db")
	model.profile.physics.negative_delivery_curve[3] = Vector2(0.6, 1)
	model.end_edit()
	model.undo()
	check(
		model.profile.physics.negative_ball_count == 20
		and model.profile.physics.negative_ball_color.is_equal_approx(Color("176dd1"))
		and model.profile.physics.negative_delivery_curve == original,
		"Undo restores negative count and curve together",
	)
	model.redo()
	var graph := Graph.new()
	graph.negative = true
	graph.setup(model)
	var expected := TiltShiftDelivery.schedule(
		31,
		model.profile.physics.negative_delivery_curve,
		roundi(model.profile.round_duration_seconds * 1000),
		true,
	)
	check(graph.schedule == expected, "Negative graph uses runtime smoothing and full-round timing")
	var path := "res://test-results/tilt-shift/negative-reload.tres"
	DirAccess.make_dir_recursive_absolute("res://test-results/tilt-shift")
	check(ResourceSaver.save(model.profile, path) == OK, "Edited negative tunables save")
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var reloaded := saved as TiltShiftTuning
	check(
		reloaded.physics.negative_ball_count == 31
		and reloaded.physics.negative_ball_color.is_equal_approx(Color("3498db"))
		and reloaded.physics.negative_delivery_curve
		== model.profile.physics.negative_delivery_curve,
		"Negative count and curve survive a fresh Resource reload",
	)
	check(
		(load(DEFAULT) as TiltShiftTuning).physics.negative_delivery_curve == original,
		"Workshop negative edits remain isolated from runtime content",
	)
	graph.free()


func _test_tunable_controls() -> void:
	var panel := WorkshopPanel.new()
	root.add_child(panel)
	await process_frame
	var controls := panel.tunables.get_children()
	var heading := -1
	for index: int in controls.size():
		if controls[index] is Label and controls[index].text.begins_with("Negative smooth"):
			heading = index
			break
	if check(heading >= 0, "Tunables exposes the separate negative curve controls"):
		var low_row: HBoxContainer = controls[heading + 3]
		var intensity := low_row.get_child(1) as SpinBox
		check(
			is_equal_approx(intensity.value, 0.15),
			"Curve controls retain the initial low intensity",
		)
		var row: HBoxContainer = controls[heading + 4]
		var input := row.get_child(0) as SpinBox
		input.value = 0.65
		check(
			is_equal_approx(panel.model.profile.physics.negative_delivery_curve[3].x, 0.65),
			"Editing a Tunables control updates the runtime negative curve",
		)
		check(
			panel.model.profile.physics.delivery_curve
			== TiltShiftPhysicsTuning.new().delivery_curve,
			"Negative curve controls preserve the positive curve",
		)
	var radius := panel.tunables.find_child("ball_radius", true, false) as SpinBox
	check(is_equal_approx(radius.value, 0.01587), "Tunables retains the exact 15% radius increase")
	var picker := panel.tunables.find_child("negative_ball_color", true, false) as ColorPickerButton
	if check(picker != null, "Tunables exposes the negative ball color picker"):
		picker.color = Color("3498db")
		picker.color_changed.emit(picker.color)
		check(
			panel.model.profile.physics.negative_ball_color == picker.color
			and not picker.edit_alpha,
			"Color picker edits the saved opaque negative tint",
		)
	panel.queue_free()
	await process_frame
