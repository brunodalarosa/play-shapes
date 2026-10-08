extends TestScript

const MotionFixture := preload("res://minigames/003_tilt_shift/tests/tilt_shift_motion_fixtures.gd")
var _now := 0


func _run() -> void:
	var host := root.get_node("SessionHost")
	var original: ActivePresets = host.active_presets
	host.active_presets = original.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	host.active_presets.tilt_shift.physics.ball_count = 0
	host._ensure_tilt_shift()
	var session := host.tilt_shift as TiltShiftSession
	session.set_process(false)
	session.motion.set_process(false)
	session.clock = func() -> int:
		return _now
	session.motion.clock = session.clock
	for index: int in 10:
		host.player_registry.join_player(
			950 + index,
			"Designer %d" % index,
			true,
			0,
			"squircle",
			"#1E88E5",
		)
	var start: Dictionary = host.begin_pre_minigame(TiltShiftSession.ID)
	check(
		start.accepted and start.direct_launch and host.readiness == null,
		"Mapped Tilt Shift enters selected preparation without the all-player lobby gate",
	)
	var presentation := TiltShiftPresentation.new()
	root.add_child(presentation)
	presentation.arena.clock = session.clock
	presentation.arena.set_physics_process(false)
	var launch: Dictionary = host.consume_minigame_launch(TiltShiftSession.ID)
	check(
		session.attach(presentation, launch.participants),
		"Uncalibrated selected preparation attaches without prematurely starting play",
	)
	var controller := presentation.arena.controller
	var protocol := session.protocol
	var state := controller.snapshot()
	var selected := PackedStringArray()
	var spectator := ""
	for player: TiltShiftState.Player in state.players:
		if player.selected:
			selected.append(player.player_id)
		else:
			spectator = player.player_id
	var ready_message := {
		"type": "tilt_shift_ready",
		"generation": session.generation,
		"round_token": state.round_token,
		"ready": true,
	}
	check(
		not protocol.handle_ready(spectator, ready_message, 0),
		"Spectator wire READY is rejected",
	)
	var first := selected[0]
	var channel: MotionInputChannel = host.websocket.motion_channels[first]
	MotionFixture.live(channel, 0, 1, 0)
	channel.handle(
		{ "player_id": first },
		{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
		0,
	)
	check(
		protocol.handle_ready(first, ready_message, 0),
		"Selected calibrated wire READY is accepted",
	)
	var neutral := session.motion.inputs[first].neutral_phase
	channel.reconnect()
	_now = 250
	MotionFixture.live(channel, 20, 1, _now)
	session.motion.poll()
	check(
		session.motion.inputs[first].neutral_phase == neutral,
		"Preparation reconnect preserves neutral",
	)
	var calibration := {
		"type": "motion_calibrate",
		"subscription_id": channel.subscription_id,
		"generation": session.generation,
		"round_token": state.round_token,
	}
	check(protocol.valid_calibration(calibration), "Current round calibration context is accepted")
	channel.handle(
		{ "player_id": first },
		{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
		_now,
	)
	check(not controller.snapshot(first).players[0].ready, "Accepted recalibration clears READY")
	check(
		session.motion.inputs[first].neutral_phase != neutral,
		"Deliberate calibration changes neutral",
	)
	for id: String in selected:
		channel = host.websocket.motion_channels[id]
		_now += 250
		MotionFixture.live(channel, 0, 2, _now)
		channel.handle(
			{ "player_id": id },
			{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
			_now,
		)
		check(
			protocol.handle_ready(id, ready_message, _now),
			"Selected phones release their current gate",
		)
	check(controller.snapshot().phase == &"countdown", "All-ready enters the shared countdown once")
	check(
		not session.force_start(state.round_token, session.generation),
		"Host cannot force the same countdown a second time",
	)
	var cutoff := controller.snapshot().phase_deadline_msec + 600
	_now = cutoff
	presentation.arena.step(0, _now)
	check(controller.snapshot().phase == &"active", "Runtime arena starts only after START")
	check(
		not protocol.valid_calibration(calibration),
		"Active wire calibration context is rejected",
	)
	var before := session.motion.inputs[first].neutral_phase
	channel = host.websocket.motion_channels[first]
	MotionFixture.live(channel, 35, 3, _now)
	channel.handle(
		{ "player_id": first },
		{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
		_now,
	)
	check(
		session.motion.inputs[first].neutral_phase == before,
		"Active callback cannot change neutral",
	)
	_now = controller.snapshot().deadline_msec
	presentation.arena.step(0, _now)
	session.poll()
	check(
		controller.snapshot().round_number == 2 and controller.snapshot().phase == &"preparing",
		"Next mapped round waits for its changed participants",
	)
	check(
		not protocol.handle_ready(first, ready_message, _now),
		"Old wire round cannot confirm the next gate",
	)
	check(
		not session.force_start(controller.snapshot().round_token, "obsolete"),
		"Stale launch generation cannot force another playthrough",
	)
	controller.phase_changed.connect(
		func(_state: TiltShiftState.Snapshot) -> void:
			host.send_players_to_lobby(),
		CONNECT_ONE_SHOT,
	)
	_now += 100000
	presentation.arena.step(0, _now)
	check(
		host.websocket.motion_channels.is_empty() and host.websocket._active_protocol == null,
		"Cancellation during a phase notification retires protocol and remaining callbacks",
	)
	check(
		not protocol.handle_ready(first, ready_message, _now),
		"Retired adapter cannot resume preparation",
	)
	presentation.queue_free()
	await process_frame
	for index: int in 10:
		host.player_registry.leave_connection(950 + index)
	await _initial_calibration(host, session)
	session.clock = Time.get_ticks_msec
	session.motion.clock = Time.get_ticks_msec
	session.set_process(true)
	session.motion.set_process(true)
	host.active_presets = original


func _initial_calibration(host: Node, session: TiltShiftSession) -> void:
	for count: int in [2, 4]:
		_now = 0
		for index: int in count:
			host.player_registry.join_player(980 + index, "Player %d" % index, true, 0)
		check(host.begin_pre_minigame(TiltShiftSession.ID).accepted, "Small roster prepares")
		var presentation := TiltShiftPresentation.new()
		root.add_child(presentation)
		presentation.arena.clock = session.clock
		presentation.arena.set_physics_process(false)
		var launch: Dictionary = host.consume_minigame_launch(TiltShiftSession.ID)
		check(session.attach(presentation, launch.participants), "Small roster attaches")
		var controller := presentation.arena.controller
		var state := controller.snapshot()
		check(
			state.phase == &"preparing" and not state.panel_visible,
			"Initial calibration skips both the participant panel and READY",
		)
		_now = 65000
		presentation.arena.step(0, _now)
		check(
			controller.snapshot().phase == &"preparing" and presentation.arena.spawned_count == 0,
			"Delayed permission cannot consume the countdown or start ball delivery",
		)
		var first := state.players[0].player_id
		var channel: MotionInputChannel = host.websocket.motion_channels[first]
		MotionFixture.live(channel, 0, 1, _now)
		channel.handle(
			{ "player_id": first },
			{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
			_now,
		)
		session.motion.poll()
		presentation.arena.step(0, _now)
		check(controller.snapshot().phase == &"preparing", "One calibrated phone cannot launch")
		var wire := session.protocol.snapshot_for(first)
		check(
			wire.calibration_available and not wire.ready_available,
			"Phone calibration stays available while READY stays hidden",
		)
		_now += 250
		for player: TiltShiftState.Player in state.players:
			channel = host.websocket.motion_channels[player.player_id]
			MotionFixture.live(channel, 0, 2, _now)
			channel.handle(
				{ "player_id": player.player_id },
				{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
				_now,
			)
		controller.set_connected(first, false)
		session.motion.poll()
		presentation.arena.step(0, _now)
		check(controller.snapshot().phase == &"preparing", "Disconnected calibration cannot launch")
		controller.set_connected(first, true)
		_now += 1250
		var fresh_id: String = launch.participants[0].player_id
		channel = host.websocket.motion_channels[fresh_id]
		MotionFixture.live(channel, 25, 3, _now)
		session.motion.poll()
		presentation.arena.step(0, _now)
		check(controller.snapshot().phase == &"preparing", "Stale calibrated input cannot launch")
		_now += 250
		for player: TiltShiftState.Player in state.players:
			channel = host.websocket.motion_channels[player.player_id]
			MotionFixture.live(channel, 0, 4, _now)
		session.motion.poll()
		presentation.arena.step(0, _now)
		state = controller.snapshot()
		check(
			state.phase == &"countdown" and state.phase_deadline_msec == _now + 3000,
			"All selected calibrated phones receive the complete default countdown",
		)
		_now = state.phase_deadline_msec + 600
		presentation.arena.step(0, _now)
		check(controller.snapshot().phase == &"active", "Calibrated countdown enters active play")
		for index: int in state.players.size():
			var player := state.players[index]
			channel = host.websocket.motion_channels[player.player_id]
			MotionFixture.live(channel, 25 if index % 2 == 0 else -25, 5, _now)
		session.motion.poll()
		for player: TiltShiftState.Player in state.players:
			var angle := controller.snapshot(player.player_id).players[0].angle_radians
			check(absf(angle) > 0.1, "Each phone's tilt reaches its authoritative paddles")
			check(
				session.protocol.snapshot_for(player.player_id).angle_radians == angle,
				"Each phone receives its accepted host angle",
			)
		_now = controller.snapshot().deadline_msec
		presentation.arena.step(0, _now)
		session.poll()
		check(
			controller.snapshot().round_number == 2 and controller.snapshot().phase == &"countdown",
			"Unchanged later participants skip calibration, panel and READY",
		)
		for player: TiltShiftState.Player in state.players:
			check(
				session.motion.inputs[player.player_id].calibrated,
				"Later rounds retain calibration",
			)
		host.send_players_to_lobby()
		check(
			host.websocket.motion_channels.is_empty(),
			"Cancel retires initial calibration capture",
		)
		presentation.queue_free()
		await process_frame
		for index: int in count:
			host.player_registry.leave_connection(980 + index)
