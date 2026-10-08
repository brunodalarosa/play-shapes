extends TestScript

var _now := 0


func _run() -> void:
	var source: TiltShiftTuning = load("res://minigames/003_tilt_shift/tuning/Default.tres")
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1024, 768)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var profile: TiltShiftTuning = source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		profile.physics.ball_count = 10
		profile.physics.use_position_seed = true
		profile.physics.position_seed = 749
		profile.layouts_by_round[1].arena_size.y = 0.75
		var presentation := TiltShiftPresentation.new()
		root.add_child(presentation)
		presentation.arena.set_physics_process(false)
		presentation.arena.clock = func() -> int:
			return _now
		_now = 0
		check(
			presentation.start_shift(profile, TiltShiftFixtures.players(10)).accepted,
			"Viewport-aware journey starts from saved content",
		)
		await process_frame
		await process_frame
		presentation._fit_camera()
		var arena := presentation.arena
		check(arena.position_seed_used == 749, "Mapped preparation initializes the position seed")
		check(
			arena.paddle_bodies().size() == 5 and arena.live_balls().is_empty(),
			"Layout A exists during preparation without balls",
		)
		var auto_body: TiltShiftPaddleBody
		for body: TiltShiftPaddleBody in arena.paddle_bodies():
			if body.auto_rate != 0:
				auto_body = body
		check(auto_body != null and auto_body.target_angle == 0, "Neutral begins at zero")
		arena.step(0.016, 0)
		check(auto_body.target_angle == 0, "Readiness does not rotate neutral")
		var token := arena.controller.snapshot().round_token
		arena.controller.force_start(token, 0)
		_now = 3000
		arena.step(0.016, _now)
		check(
			auto_body.target_angle == 0 and arena.spawned_count == 0,
			"START remains stationary and delivery-free",
		)
		_now = 3600
		arena.step(0.016, _now)
		var ball := arena._spawn(_now)
		check(ball != null, "Active round permits viewport-aware ball entry")
		var top := arena.visible_top
		check(
			ball.position.y + ball.radius < top,
			"Whole visible ball starts above the fitted viewport top",
		)
		check(auto_body.target_angle > 0, "Neutral rotates only in active play")
		var first := arena.controller.snapshot().players[0]
		check(
			not presentation
			.operator_for(first.player_id)
			.character
			.player_color
			.is_equal_approx(Color.WHITE),
			"Factory operators retain selected colors",
		)
		var window := roundi(
			(profile.round_duration_seconds - profile.physics.delivery_cutoff_seconds) * 1000
		)
		for offset: int in arena._schedule:
			check(offset < window, "Full schedule remains before the delivery cutoff")
		check(
			arena._schedule.size() == profile.physics.ball_count,
			"Cutoff retains the ball budget",
		)
		_now = arena.controller.snapshot().deadline_msec
		arena.step(0, _now)
		check(arena.live_balls().is_empty(), "Immediate deadline clears unresolved offscreen balls")
		arena.start_next_round()
		check(arena.paddle_bodies().size() == 6, "Next layout replaces physical geometry")
		await process_frame
		var bounds := presentation.world_bounds()
		var transform := presentation.viewport.get_canvas_transform()
		var visible := Rect2(Vector2.ZERO, Vector2(presentation.viewport.size)).grow(2)
		for corner: Vector2 in [bounds.position, bounds.end]:
			check(
				visible.has_point(transform * corner),
				"Changed round arena dimensions refit the complete factory",
			)
		check(bounds.size.y > 800, "Round layout dimensions update factory bounds")
		for body: TiltShiftPaddleBody in arena.paddle_bodies():
			check(
				is_equal_approx(body.size.x, 180.0),
				"Layout B has independent collider dimensions",
			)
		presentation.stop()
		presentation.queue_free()
		await process_frame
