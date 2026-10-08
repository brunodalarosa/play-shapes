extends TestScript

const MotionFixture := preload("res://minigames/003_tilt_shift/tests/tilt_shift_motion_fixtures.gd")
const FACTORY := preload("res://minigames/003_tilt_shift/tilt_shift_presentation.tscn")
const THREE := preload("res://minigames/003_tilt_shift/tuning/baskets/ThreeOpenings.tres")


func _run() -> void:
	var host := root.get_node("SessionHost")
	host._ensure_tilt_shift()
	for count: int in [2, 4, 6, 8, 10]:
		await _exercise(host, count)
	await _roster_changes(host)


func _join(host: Node, connection: int) -> Dictionary:
	var result: Dictionary = host.player_registry.join_player(
		connection,
		"Player %d" % connection,
		true,
		Time.get_ticks_msec(),
		"squircle",
		"#1E88E5",
	)
	return result.player


func _calibrate(host: Node, player: Dictionary, now: int) -> void:
	var channel: MotionInputChannel = host.websocket.motion_channels[player.player_id]
	check(
		MotionFixture.live(channel, 0, 1, now),
		"Unknown permission with current samples is usable",
	)
	check(
		channel.handle(
			player,
			{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
			now,
		),
		"Authenticated preparation calibration request is accepted",
	)
	check(
		host.tilt_shift.ready_for(player.player_id),
		"Fresh calibrated connected player may READY",
	)


func _exercise(host: Node, count: int) -> void:
	host.tilt_shift.motion.clock = Time.get_ticks_msec
	var connections: Array[int] = []
	for index: int in count:
		connections.append(700 + index)
		_join(host, 700 + index)
	var selected: TiltShiftTuning = host.active_presets.tilt_shift.duplicate_deep(
		Resource.DEEP_DUPLICATE_ALL,
	)
	selected.layouts_by_round.clear()
	var legacy: TiltShiftPaddleLayout = load(
		"res://minigames/003_tilt_shift/tuning/layouts/Mirrored.tres"
	)
	selected.paddle_layout = legacy.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	selected.round_count = 2
	selected.baskets_by_round = [selected.baskets_by_round[0], THREE]
	selected.physics.ball_count = 0
	selected.flow.intermission_seconds = 0.0
	host.active_presets.tilt_shift = selected
	check(host.begin_pre_minigame(TiltShiftSession.ID).accepted, "Eligible even roster prepares")
	var readiness: PreMinigameReadiness = host.readiness
	var participants: Array[Dictionary] = host.players()
	for player: Dictionary in participants:
		check(
			not readiness.set_ready(player, true).accepted,
			"Crafted READY cannot skip sensor proof",
		)
		_calibrate(host, player, Time.get_ticks_msec())
	var old_generation: String = host.tilt_shift.generation
	for player: Dictionary in participants:
		check(readiness.set_ready(player, true).accepted, "Prepared player can READY")
	check(host.readiness == null and readiness.transitioning, "All-ready launches exactly once")
	var factory := FACTORY.instantiate() as TiltShiftPresentation
	root.add_child(factory)
	check(host.tilt_shift.attach(factory, participants), "Same prepared motion consumer attaches")
	var controller := factory.arena.controller
	var motion: TiltShiftMotionController = host.tilt_shift.motion
	var protocol: TiltShiftProtocol = host.tilt_shift.protocol
	for player: Dictionary in participants:
		var personal: Dictionary = protocol.snapshot_for(player.player_id)
		var expected := controller.snapshot(player.player_id).players[0]
		check(
			personal.paddle_ids == Array(expected.paddle_ids),
			"Wire assignments match host ownership",
		)
		check(personal.generation == old_generation, "Preparation generation transfers into play")
		if count == 2:
			check(
				personal.paddle_ids.size() == 5,
				"Two players retain five paddles each on the host",
			)
	var first: Dictionary = participants[0]
	var input: TiltShiftTiltInput = motion.inputs[first.player_id]
	var neutral := input.neutral_phase
	var channel: MotionInputChannel = host.websocket.motion_channels[first.player_id]
	var now := Time.get_ticks_msec() + 50
	MotionFixture.live(channel, 25, 2, now)
	motion.clock = func() -> int:
		return now
	motion.poll()
	var accepted := controller.snapshot(first.player_id).players[0].angle_radians
	check(absf(accepted) > 0.1, "Accepted tilt changes the authoritative player angle")
	check(
		protocol.snapshot_for(first.player_id).angle_radians == accepted,
		"Phone mirrors accepted angle",
	)
	channel.reconnect()
	check(
		not channel.handle(
			first,
			{ "type": "motion_calibrate", "subscription_id": "obsolete" },
			now + 250,
		),
		"Reconnect cannot use an obsolete calibration subscription",
	)
	MotionFixture.live(channel, 30, 1, now + 50)
	motion.clock = func() -> int:
		return now + 50
	motion.poll()
	check(input.neutral_phase == neutral, "Gameplay reconnect preserves neutral")
	channel.handle(
		first,
		{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
		now + 250,
	)
	check(input.neutral_phase == neutral, "Gameplay calibration is locked")
	var snapshot := controller.snapshot()
	var handle := controller.register_ball(snapshot.round_token, now + 50).ball
	controller.resolve_ball(handle, snapshot.basket_preset.openings[0].basket_id, now + 50)
	check(controller.snapshot().scores == [1, 0], "Accepted catch changes cumulative host score")
	var deadline := snapshot.deadline_msec
	factory.arena.clock = func() -> int:
		return deadline
	controller.advance(snapshot.deadline_msec)
	check(protocol.phase == "between_rounds", "Cutoff snapshot freezes the round")
	host.tilt_shift.poll()
	check(controller.snapshot().round_number == 2, "Session advances next round once")
	check(
		controller.snapshot().basket_preset.openings.size() == 3,
		"Second mapped preset is selected",
	)
	snapshot = controller.snapshot()
	if count != 10:
		handle = controller.register_ball(snapshot.round_token, deadline).ball
		controller.resolve_ball(handle, "blue", deadline)
		check(controller.snapshot().scores == [1, 1], "Scores carry across mapped rounds")
	controller.advance(snapshot.deadline_msec)
	check(protocol.phase == "finished" and motion.inputs.is_empty(), "Results stop sensor capture")
	if count == 10:
		check(controller.snapshot().winner == 0, "Cumulative score reports the winning team")
	else:
		check(controller.snapshot().is_draw, "Equal cumulative score reports a draw")
	host.send_players_to_lobby()
	check(host.websocket._active_protocol == null, "Return clears Tilt Shift protocol")
	check(host.websocket.motion_channels.is_empty(), "Return retires capture channels")
	host.clear_minigame_launch()
	factory.queue_free()
	await process_frame
	for connection: int in connections:
		host.player_registry.leave_connection(connection)


func _roster_changes(host: Node) -> void:
	host.tilt_shift.motion.clock = Time.get_ticks_msec
	var first := _join(host, 801)
	check(
		not host.begin_pre_minigame(TiltShiftSession.ID).accepted,
		"One-player roster cannot prepare",
	)
	var second := _join(host, 802)
	check(host.begin_pre_minigame(TiltShiftSession.ID).accepted, "Two-player roster prepares")
	var now := Time.get_ticks_msec()
	_check_blockers(host, first, now)
	host.tilt_shift.motion.clock = Time.get_ticks_msec
	_calibrate(host, first, now)
	var channel: MotionInputChannel = host.websocket.motion_channels[first.player_id]
	check(host.readiness.set_ready(first, true).accepted, "First player waits READY for second")
	channel.reconnect()
	host.tilt_shift.poll()
	check(
		not host.tilt_shift.motion.inputs[first.player_id].calibrated,
		"Preparation resume clears neutral",
	)
	check(not host.readiness.snapshot_for(first.player_id).ready, "Preparation resume clears READY")
	_calibrate(host, second, now)
	var second_channel: MotionInputChannel = host.websocket.motion_channels[second.player_id]
	var second_generation := second_channel.subscription_id
	var third := _join(host, 803)
	host.readiness.add_joined(third)
	check(
		host.websocket.motion_channels.size() == 3,
		"Final onboarding join gets an isolated channel",
	)
	check(
		second_channel.subscription_id == second_generation
		and host.tilt_shift.motion.inputs[second.player_id].calibrated,
		"Final onboarding join preserves the earlier player's calibrated channel",
	)
	check(
		not host.minigame_availability(TiltShiftSession.ID).available,
		"Odd final roster blocks launch",
	)
	_calibrate(host, first, now + 50)
	host.tilt_shift.motion.clock = func() -> int:
		return now + 50
	host.readiness.set_ready(first, true)
	host.tilt_shift.motion.clock = func() -> int:
		return now + 2000
	host.tilt_shift.poll()
	check(not host.readiness.snapshot_for(first.player_id).ready, "Stale capture revokes READY")
	host.cancel_pre_minigame()
	check(host.websocket.motion_channels.is_empty(), "Host cancel retires every final-join channel")
	check(
		not channel.handle(
			first,
			{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
			now + 3000,
		),
		"Retired callbacks cannot revive capture",
	)
	check(
		not host.prepare_minigame_launch(TiltShiftSession.ID, true).accepted,
		"Real Tilt Shift never accepts the one-player debug bypass",
	)
	for player: Dictionary in [first, second, third]:
		host.player_registry.leave_connection(int(player.seat) + 800)


func _check_blockers(host: Node, player: Dictionary, start: int) -> void:
	var channel: MotionInputChannel = host.websocket.motion_channels[player.player_id]
	var cases := ["denied", "error", "unsupported", "insecure", "absent", "partial", "stale"]
	for index: int in cases.size():
		channel.reconnect()
		host.tilt_shift.sync_players(host.players())
		var now := start + (index + 1) * 1000
		host.tilt_shift.motion.clock = func() -> int:
			return now
		var diagnostics := MotionFixture.diagnostics()
		var reason: String = cases[index]
		if reason in ["denied", "error"]:
			diagnostics.orientation_permission = reason
		elif reason == "unsupported":
			diagnostics.orientation_support = false
		elif reason == "insecure":
			diagnostics.secure_context = false
		channel.handle(
			player,
			{
				"type": "motion_status",
				"subscription_id": channel.subscription_id,
				"diagnostics": diagnostics,
			},
			now,
		)
		if reason != "absent":
			var sample := MotionFixture.sample(0)
			if reason == "partial":
				sample.orientation[0] = null
			if reason == "stale":
				sample.orientation_age_msec = 2000
			channel.handle(
				player,
				{
					"type": "motion_sample",
					"subscription_id": channel.subscription_id,
					"sequence": 1,
					"sample": sample,
				},
				now,
			)
		channel.handle(
			player,
			{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
			now,
		)
		check(
			not host.readiness.set_ready(player, true).accepted,
			"Unusable capture cannot appear ready: " + reason,
		)
	channel.reconnect()
	host.tilt_shift.sync_players(host.players())
