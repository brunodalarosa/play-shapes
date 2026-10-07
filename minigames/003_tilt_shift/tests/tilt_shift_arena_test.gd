extends TestScript


func _run() -> void:
	await _test_seed_and_cleanup()
	await _test_catches_and_deadline()
	await _test_continuous_basket_row()
	await _test_rotation_and_content()
	await _test_delivery_pauses()
	await _test_observer_stop()


func _arena(selected: TiltShiftTuning, time: Array[int]) -> TiltShiftArena:
	var arena := TiltShiftArena.new()
	arena.clock = func() -> int:
		return time[0]
	root.add_child(arena)
	arena.set_physics_process(false)
	check(arena.start_shift(selected, TiltShiftFixtures.players(10)).accepted, "Arena launches")
	return arena


func _positions(seed_enabled: bool) -> PackedFloat32Array:
	var selected := TiltShiftFixtures.tuning(1)
	selected.physics.use_position_seed = seed_enabled
	selected.physics.position_seed = 749
	selected.physics.ball_count = 20
	var time: Array[int] = [0]
	var arena := _arena(selected, time)
	var result := PackedFloat32Array()
	var schedule := TiltShiftDelivery.schedule(
		selected.physics.ball_count,
		selected.physics.delivery_curve,
		1000,
	)
	for offset: int in schedule:
		time[0] = offset
		arena.step(0.0, offset)
		result.append(arena.live_balls()[-1].position.x)
	check(arena.spawned_count == 20, "The arena emits the complete configured budget")
	check(arena.live_balls().size() <= 20, "Live population is bounded by the round budget")
	arena.stop()
	check(arena.live_balls().is_empty(), "Stop immediately clears the live registry")
	arena.queue_free()
	return result


func _test_seed_and_cleanup() -> void:
	var first := _positions(true)
	await process_frame
	var repeated := _positions(true)
	check(first == repeated, "The same supplied seed reproduces the spawn-position sequence")
	await process_frame
	var fresh := _positions(false)
	await process_frame
	var next_fresh := _positions(false)
	check(fresh != next_fresh, "Absent seed chooses a new position sequence")
	await process_frame
	var selected := TiltShiftFixtures.tuning(1)
	var time: Array[int] = [0]
	var arena := _arena(selected, time)
	for restart: int in 8:
		time[0] += 2000
		arena.step(0.0, time[0])
		var launched := arena.start_shift(selected, TiltShiftFixtures.players(10))
		check(launched.accepted, "Restart launches")
		arena._spawn(time[0])
		arena.stop()
		await process_frame
		check(arena.get_child_count() == 0, "Restart/stop leaves no orphan nodes or colliders")
	arena.queue_free()
	await process_frame


func _test_catches_and_deadline() -> void:
	var selected := TiltShiftFixtures.tuning(2)
	selected.physics.ball_count = 5
	selected.baskets_by_round[1].openings[0].width = 0.10
	selected.baskets_by_round[1].openings[4].width = 0.10
	var time: Array[int] = [0]
	var arena := _arena(selected, time)
	var snapshot := arena.controller.snapshot()
	var first_paddles := arena.paddle_bodies()
	check(not arena.start_next_round().accepted, "Active play rejects premature round transitions")
	var height := snapshot.paddle_layout.arena_size.y * TiltShiftArena.WORLD_UNITS
	for team: int in [0, 1, 2]:
		var basket: TiltShiftBasketOpening
		for candidate: TiltShiftBasketOpening in snapshot.basket_preset.openings:
			if candidate.team == team:
				basket = candidate
				break
		var ball := arena._spawn(team)
		var x := basket.center * TiltShiftArena.WORLD_UNITS
		ball.previous_position = Vector2(x, height - 30)
		ball.position = Vector2(x, height + 1)
		arena.step(0.0, team + 1)
		var score := arena.controller.snapshot().scores
		check(
			score[0] == 1 and score[1] == (0 if team == 0 else 1),
			"Each basket scores only for its team; trash never scores",
		)
		check(
			not arena.controller.resolve_ball(ball.handle, basket.basket_id, team + 1).accepted,
			"A duplicate catch cannot score again",
		)
	var discarded := arena._spawn(3)
	discarded.position = Vector2(-100, 100)
	arena.step(0.0, 4)
	check(arena.controller.snapshot().scores == [1, 1], "Out-of-bounds cleanup never scores")
	var late := arena._spawn(4)
	late.previous_position = Vector2(100, height - 10)
	late.position = Vector2(100, height + 1)
	arena.step(0.0, 1000)
	check(arena.controller.snapshot().scores == [1, 1], "A catch at the deadline cannot score")
	check(arena.live_balls().is_empty(), "Deadline removes all in-flight balls without grace")
	check(arena._spawn(1000) == null, "Deadline cannot spawn a new ball")
	time[0] = 1001
	check(arena.start_next_round().accepted, "Next round consumes the configured basket mapping")
	check(arena.controller.snapshot().scores == [1, 1], "Round transition preserves team totals")
	check(
		arena.controller.snapshot().basket_preset.openings[0].width == 0.10,
		"Next round consumes its distinct selected basket arrangement",
	)
	check(arena.paddle_bodies()[0] == first_paddles[0], "Basket replacement retains paddle bodies")
	check(
		not arena.controller.resolve_ball(late.handle, "orange_left", 1001).accepted,
		"An old ball cannot resolve into a later round",
	)
	arena.stop()
	arena.queue_free()
	await process_frame


func _test_continuous_basket_row() -> void:
	var selected := TiltShiftFixtures.tuning(1)
	selected.physics.ball_count = 201
	var time: Array[int] = [0]
	var arena := _arena(selected, time)
	check(arena.floor_bodies().is_empty(), "Default basket row has no solid floor gaps")
	var state := arena.controller.snapshot()
	var height := state.paddle_layout.arena_size.y * TiltShiftArena.WORLD_UNITS
	var catches := PackedStringArray()
	var record := func(_handle: TiltShiftState.BallHandle, basket_id: String) -> void:
		catches.append(basket_id)
	arena.ball_removed.connect(record)
	for index: int in 201:
		var ball := arena._spawn(0)
		var crossing := float(index) * 5.0
		ball.previous_position = Vector2(crossing, height - 10)
		ball.position = Vector2(crossing, height + 1)
		arena.step(0, 0)
		check(ball.resolved, "Every stage crossing resolves, including shared rims and edges")
	check(
		catches.size() == 201 and not catches.has(""),
		"Continuous openings catch all falling balls exactly once without unscored gaps",
	)
	check(catches.has("trash_center"), "Trash remains a basket destination without points")
	check(arena.live_balls().is_empty(), "Every caught ball retires its live body")
	arena.ball_removed.disconnect(record)
	arena.stop()
	arena.queue_free()
	await process_frame


func _test_rotation_and_content() -> void:
	var selected := TiltShiftFixtures.tuning(2)
	selected.physics.ball_count = 0
	var time: Array[int] = [0]
	var arena := _arena(selected, time)
	var bodies := arena.paddle_bodies()
	var original := bodies[0].position
	selected.paddle_layout.paddles[0].position = Vector2.ZERO
	selected.physics.paddle_length = 0.20
	check(
		bodies[0].position == original and bodies[0].size.x == 100,
		"Inspector edits do not change frozen live geometry",
	)
	for clearance: float in arena.swept_clearances():
		check(clearance > 0.0, "Default full-turn swept extents clear other paddles and walls")
	var player := arena.controller.snapshot().players[0]
	var paddle: TiltShiftPaddleBody
	for body: TiltShiftPaddleBody in bodies:
		if player.paddle_ids.has(body.paddle_id):
			paddle = body
	check(
		arena.controller.accept_angle(player.player_id, TAU * 3, player_token(arena), 0).accepted,
		"Host control accepts repeated full turns",
	)
	for tick: int in 360:
		paddle.advance_pose(1.0 / 60.0)
	check(is_equal_approx(paddle.applied_angle, TAU * 3), "Physical pose completes three turns")
	paddle.target_angle = -TAU
	var before := paddle.applied_angle
	paddle.advance_pose(1.0 / 60.0)
	check(
		absf(paddle.applied_angle - before) <= PI / 60.0 + 0.0001,
		"Reversal across wraps respects the physical angular-speed bound",
	)
	check(
		paddle.get_node("CollisionShape2D").get_parent() == paddle,
		"Collider and drawn visual share the physical body transform",
	)
	arena.controller.set_connected(player.player_id, false)
	check(paddle.target_angle == -TAU, "Disconnect does not replace the accepted target pose")
	time[0] = 1000
	arena.step(0.0, 1000)
	time[0] = 1001
	arena.start_next_round()
	check(
		arena.paddle_bodies()[0] == bodies[0] and bodies[0].position == original,
		"Round transitions retain the same paddle identities and anchors",
	)
	arena.stop()
	arena.queue_free()
	await process_frame


func player_token(arena: TiltShiftArena) -> String:
	return arena.controller.snapshot().round_token


func _test_delivery_pauses() -> void:
	var selected := TiltShiftFixtures.tuning(1)
	selected.physics.ball_count = 20
	selected.physics.delivery_curve = PackedVector2Array(
		[Vector2(0, 1), Vector2(0.25, 0), Vector2(0.75, 0), Vector2(1, 1)]
	)
	var time: Array[int] = [0]
	var arena := _arena(selected, time)
	time[0] = 500
	arena.step(0.0, 500)
	check(arena.spawned_count == 0, "Overdue deliveries wait through zero-intensity spans")
	time[0] = 999
	arena.step(0.0, 999)
	check(arena.spawned_count == 20, "A shaped curve emits the same budget before cutoff")
	var ball := arena.live_balls()[0]
	root.remove_child(arena)
	check(
		arena.live_balls().is_empty() and ball.resolved,
		"Scene exit clears balls even when the arena was detached before deletion",
	)
	arena.queue_free()
	await process_frame


func _test_observer_stop() -> void:
	var selected := TiltShiftFixtures.tuning(1)
	var time: Array[int] = [0]
	var arena := _arena(selected, time)
	var snapshot := arena.controller.snapshot()
	var ball := arena._spawn(0)
	var height := snapshot.paddle_layout.arena_size.y * TiltShiftArena.WORLD_UNITS
	var x := snapshot.basket_preset.openings[0].center * TiltShiftArena.WORLD_UNITS
	ball.previous_position = Vector2(x, height - 30)
	ball.position = Vector2(x, height + 1)
	arena.ball_removed.connect(arena.stop.unbind(2))
	arena.step(0.0, 1)
	check(
		arena.controller == null and arena.live_balls().is_empty(),
		"A preview observer can stop during a catch without resuming the retired round",
	)
	arena.queue_free()
	await process_frame
	arena = _arena(selected, time)
	arena.ball_spawned.connect(arena.stop.unbind(1))
	arena.step(0.0, 500)
	check(
		arena.controller == null and arena.live_balls().is_empty(),
		"A preview observer can stop delivery without leaving orphan balls",
	)
	arena.queue_free()
	await process_frame

	var restarting := _arena(selected, time)
	var restart := func(_ball: TiltShiftBall) -> void:
		restarting.stop()
		restarting.start_shift(selected, TiltShiftFixtures.players(10))
	restarting.ball_spawned.connect(restart)
	time[0] = 500
	restarting.step(0.0, 500)
	check(
		restarting.spawned_count == 0 and restarting.live_balls().is_empty(),
		"A delivery callback restart cannot emit old-frame deliveries into the new shift",
	)
	restarting.ball_spawned.disconnect(restart)
	restarting.stop()
	restarting.queue_free()
	await process_frame
