extends TestScript
## Actual collider fitting, accepted-control holds and authoritative round feedback.

const SCENE := "res://minigames/003_tilt_shift/tilt_shift_presentation.tscn"


func _run() -> void:
	await _check_invalid_tuning()
	await _check_rosters_and_geometry()
	await _check_control_and_rounds()
	await _check_winner()


func _check_invalid_tuning() -> void:
	var time: Array[int] = [1000]
	var presentation := _create(time)
	presentation.tuning = TiltShiftPresentationTuning.new()
	presentation.tuning.turns_per_loop = 0
	presentation.tuning.basket_scale = NAN
	var launch := presentation.start_shift(TiltShiftFixtures.tuning(1), _players(2))
	check(
		not launch.accepted and launch.errors.size() == 2,
		"Unsafe cosmetic scales and animation divisors reject before launch",
	)
	check(presentation.arena.controller == null, "Invalid presentation cannot start rules")
	presentation.tuning.turns_per_loop = 0.25
	presentation.tuning.basket_scale = 0.12
	presentation.tuning.catch_feedback_seconds = 0.1
	check(
		presentation.tuning.validation_errors().is_empty(),
		"Documented minimum presentation values remain usable",
	)
	presentation.queue_free()
	await process_frame


func _create(time: Array[int]) -> TiltShiftPresentation:
	var presentation := load(SCENE).instantiate() as TiltShiftPresentation
	root.add_child(presentation)
	presentation.arena.clock = func() -> int:
		return time[0]
	presentation.arena.set_physics_process(false)
	return presentation


func _players(count: int) -> Array[TiltShiftState.Player]:
	var result := TiltShiftFixtures.players(count)
	for index: int in count:
		result[index].character_color = String(CharacterSelection.COLORS[index].hex)
		result[index].player_name = "Operator %d" % (index + 1)
	return result


func _check_rosters_and_geometry() -> void:
	for count: int in [2, 4, 6, 8, 10]:
		var time: Array[int] = [1000]
		var presentation := _create(time)
		var profile := TiltShiftFixtures.tuning(1)
		profile.physics.ball_count = 0
		profile.physics.paddle_length = 0.16 if count == 4 else 0.10
		profile.physics.paddle_thickness = 0.025 if count == 4 else 0.01
		var launch := presentation.start_shift(profile, _players(count))
		check(launch.accepted, "Supported roster launches")
		for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1024, 768)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			await process_frame
			await process_frame
			var view := Rect2(Vector2.ZERO, Vector2(presentation.viewport.size)).grow(2)
			var transform := presentation.viewport.get_canvas_transform()
			var bounds := presentation.world_bounds()
			check(
				presentation.viewport.size == dimensions,
				"Stretched viewport follows the host size",
			)
			check(
				view.has_point(transform * bounds.position)
				and view.has_point(transform * bounds.end),
				"Resized viewport contains the complete factory without moving physical bodies",
			)
		var state := presentation.arena.controller.snapshot()
		check(
			presentation._operators.size() == count,
			"Exactly one station per player, not per paddle",
		)
		for player: TiltShiftState.Player in state.players:
			var operator := presentation.operator_for(player.player_id)
			check(operator != null, "Every participant has an operator")
			check(
				(operator.scale.x < 0.0) == (player.team == 1),
				"Team sides mirror the same character and lever without another asset library",
			)
			var selection := CharacterSelection.resolve_selection(
				"squircle",
				player.character_color,
			)
			check(
				operator.character.player_color == Color(String(selection.character_color)),
				"Selected body, hand and foot tint is retained independently of team",
			)
			check(
				player.player_name in operator._label.text,
				"Station labels retain selected names",
			)
		for body: TiltShiftPaddleBody in presentation.arena.paddle_bodies():
			var beam := presentation.beam_for(body.paddle_id)
			var collider := body.get_node("CollisionShape2D") as CollisionShape2D
			var shape := collider.shape as RectangleShape2D
			check(
				beam.contact_rect() == Rect2(-shape.size * 0.5, shape.size),
				"Beam visible extents exactly fit real collider dimensions, "
				+ "including resized presets",
			)
			check(beam.get_parent() == body, "The collider owns the artwork's physical transform")
			for angle: float in [0.0, PI * 0.5, TAU + 0.3, -TAU * 2.0 - 0.4]:
				body.target_angle = angle
				presentation.arena.step(1.0 / 60.0, time[0])
				await physics_frame
				check(
					beam.global_transform.is_equal_approx(collider.global_transform),
					"Confirmed physics and visible surfaces share one transform "
					+ "through turns/reversal",
				)
		for opening: TiltShiftBasketOpening in state.basket_preset.openings:
			var basket := presentation.basket_for(opening.basket_id)
			check(
				is_equal_approx(basket.position.x, opening.center * TiltShiftArena.WORLD_UNITS)
				and is_equal_approx(
					basket.opening_rect.size.x,
					opening.width * TiltShiftArena.WORLD_UNITS,
				),
				"Basket mouths are positioned and sized by scoring openings",
			)
			check(
				basket.back.z_index < 2 and basket.front.z_index > 2,
				"Balls draw between basket layers",
			)
			_check_rendered_mouth(basket, opening)
		presentation.stop()
		check(
			presentation._operators.is_empty() and presentation._beams.is_empty(),
			"Stop clears visuals",
		)
		presentation.queue_free()
		await process_frame


func _check_control_and_rounds() -> void:
	var time: Array[int] = [1000]
	var presentation := _create(time)
	var profile := TiltShiftFixtures.tuning(2)
	profile.physics.ball_count = 4
	for opening: TiltShiftBasketOpening in profile.baskets_by_round[1].openings:
		opening.width *= 0.75
	check(
		presentation.start_shift(profile, _players(4)).accepted,
		"Multi-round presentation launches",
	)
	var controller := presentation.arena.controller
	var state := controller.snapshot()
	var player := state.players[0]
	var operator := presentation.operator_for(player.player_id)
	var station_id := operator.get_instance_id()
	var first_paddle := presentation.arena.paddle_bodies()[0]
	var first_paddle_id := first_paddle.get_instance_id()
	for angle: float in [PI * 0.5, TAU * 2.0 + PI, -TAU * 0.5]:
		check(
			controller.accept_angle(player.player_id, angle, state.round_token, time[0]).accepted,
			"Host accepts repeated complete turns and reversal",
		)
		check(is_equal_approx(operator.accepted_angle, angle), "Operator follows accepted control")
	var held := operator.pose_frame()
	controller.set_connected(player.player_id, false)
	for unused: int in 5:
		await process_frame
	check(operator.pose_frame() == held, "Missing/disconnected input holds the same operating pose")
	controller.accept_angle("forged", 0, state.round_token, time[0])
	check(operator.pose_frame() == held, "Rejected input cannot animate an operator")
	var orange := _opening(state, 0)
	var scored := controller.register_ball(state.round_token, time[0]).ball
	var catch_result := controller.resolve_ball(scored, orange.basket_id, time[0])
	check(catch_result.accepted, "A valid catch scores")
	check(presentation._orange.text.ends_with("1"), "HUD uses cumulative authoritative team scores")
	presentation.arena.ball_removed.emit(scored, orange.basket_id)
	var old_basket := presentation.basket_for(orange.basket_id)
	check(old_basket._flash_remaining > 0.0, "A host catch triggers restrained basket feedback")
	var late := controller.register_ball(state.round_token, time[0]).ball
	presentation.arena._spawn(time[0])
	time[0] = state.deadline_msec
	check(
		not controller.resolve_ball(late, orange.basket_id, time[0]).accepted,
		"Deadline rejects late catches",
	)
	check(presentation.round_end_count == 1, "One round-end event produces one feedback cue")
	check(
		presentation.arena.live_balls().is_empty(),
		"The scoring cutoff clears in-flight visual bodies",
	)
	check(old_basket._flash_remaining == 0.0, "Round end clears catch effects immediately")
	check(
		presentation._cue.visible and presentation._clock.text.ends_with("0 s"),
		"Cutoff is visible immediately",
	)
	controller.round_ended.emit(controller.snapshot())
	check(
		presentation.round_end_count == 1,
		"Repeated round-end notification does not replay feedback",
	)
	check(presentation.start_next_round().accepted, "Caller advances to the next configured round")
	state = controller.snapshot()
	check(
		not presentation._cue.visible and state.scores == [1, 0],
		"Next round clears cue and retains totals",
	)
	check(
		presentation.operator_for(player.player_id).get_instance_id() == station_id,
		"Round changes retain one station and its held control per player",
	)
	check(
		presentation.arena.paddle_bodies()[0].get_instance_id() == first_paddle_id,
		"Round changes retain the fixed physical paddle layout",
	)
	check(
		presentation.basket_for(orange.basket_id) != old_basket,
		"Old round basket feedback cannot linger",
	)
	var blue := _opening(state, 1)
	var equalizer := controller.register_ball(state.round_token, time[0]).ball
	controller.resolve_ball(equalizer, blue.basket_id, time[0])
	time[0] = state.deadline_msec
	controller.advance(time[0])
	check(
		presentation._cue.text == "DRAW" and presentation.round_end_count == 2,
		"Final authoritative equal totals produce a draw and exactly one cue for each round",
	)
	presentation.stop()
	check(
		not controller.round_ended.is_connected(presentation._on_round_ended),
		"Stop disconnects old controller notifications",
	)
	presentation.queue_free()
	await process_frame


func _check_winner() -> void:
	var time: Array[int] = [1000]
	var presentation := _create(time)
	var profile := TiltShiftFixtures.tuning(1)
	profile.physics.ball_count = 0
	presentation.start_shift(profile, _players(2))
	var controller := presentation.arena.controller
	var state := controller.snapshot()
	var basket := _opening(state, 0)
	var ball := controller.register_ball(state.round_token, time[0]).ball
	controller.resolve_ball(ball, basket.basket_id, time[0])
	time[0] = state.deadline_msec
	controller.advance(time[0])
	check(presentation._cue.text == "ORANGE TEAM WINS", "Winner comes from shift totals")
	presentation.stop()
	presentation.queue_free()
	await process_frame


func _opening(state: TiltShiftState.Snapshot, team: int) -> TiltShiftBasketOpening:
	for opening: TiltShiftBasketOpening in state.basket_preset.openings:
		if opening.team == team:
			return opening
	return null


func _check_rendered_mouth(basket: TiltShiftBasketVisual, opening: TiltShiftBasketOpening) -> void:
	var rear := basket.back
	var region := (rear.texture as AtlasTexture).region
	var cap := rear.patch_margin_left
	var center_scale := (rear.size.x - cap * 2) / (region.size.x - cap * 2)
	var mouth: Array = TiltShiftArt.metadata().basket_mouth_px
	for index: int in 2:
		var local_x := float(cap) + (float(mouth[index]) - region.position.x - cap) * center_scale
		var world_x := basket.position.x + rear.position.x + local_x * rear.scale.x
		var expected_x := opening.center + opening.width * (-0.5 if index == 0 else 0.5)
		check(
			is_equal_approx(world_x, expected_x * TiltShiftArena.WORLD_UNITS),
			"Rendered inner rim endpoints match the scoring opening, not the outer bin width",
		)
	check(
		is_zero_approx(basket.front.position.y),
		"Front overlay begins at the physical scoring plane",
	)
