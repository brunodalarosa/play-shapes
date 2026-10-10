extends TestScript


func _run() -> void:
	_selection()
	_preparation()
	_content()


func _profile() -> TiltShiftTuning:
	var source: TiltShiftTuning = load("res://minigames/003_tilt_shift/tuning/Default.tres")
	var result: TiltShiftTuning = source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	result.round_duration_seconds = 1.0
	result.physics.delivery_cutoff_seconds = 0.0
	return result


func _start_active(controller: TiltShiftShiftController, now: int) -> int:
	var state := controller.snapshot()
	if state.phase == &"preparing":
		check(
			controller.force_start(state.round_token, now).accepted,
			"Host force enters countdown",
		)
	state = controller.snapshot()
	check(state.phase == &"countdown", "Every round receives a countdown")
	var active_at := state.phase_deadline_msec + 600
	controller.advance(active_at)
	check(controller.snapshot().phase == &"active", "START completes before active play")
	return active_at


func _selection() -> void:
	for count: int in [2, 4, 6, 8, 10]:
		for seed_value: int in 40:
			var controller := TiltShiftShiftController.new()
			controller.tuning = _profile()
			controller.set_random_seed(seed_value)
			check(
				controller.start_shift(TiltShiftFixtures.players(count), 0).accepted,
				"Every allowed roster starts the mapped journey",
			)
			var played: Dictionary[String, int] = { }
			var exposures: Dictionary[String, PackedStringArray] = { }
			var first_spectators := PackedStringArray()
			var larger: Dictionary[String, int] = { }
			var now := 0
			for round_index: int in 4:
				var state := controller.snapshot()
				var expected_capacity := 4 if round_index % 2 == 0 else 6
				var selected: Array[int] = [0, 0]
				for player: TiltShiftState.Player in state.players:
					if not player.selected:
						check(player.paddle_ids.is_empty(), "Spectators own no paddle")
						if round_index == 0:
							first_spectators.append(player.player_id)
						continue
					selected[player.team] += 1
					played[player.player_id] = played.get(player.player_id, 0) + 1
					if not exposures.has(player.player_id):
						exposures[player.player_id] = PackedStringArray()
					exposures[player.player_id].append(state.paddle_layout.layout_id)
					if count == 10 and round_index == 1:
						check(
							first_spectators.has(player.player_id),
							"Ten-player second round uses only first-round spectators",
						)
					if count == 4 and round_index % 2 == 1 and player.paddle_ids.size() == 2:
						larger[player.player_id] = larger.get(player.player_id, 0) + 1
				var capacity := mini(count, expected_capacity)
				check(
					selected[0] == selected[1] and selected[0] * 2 == capacity,
					"Round capacity is filled with equal teams",
				)
				for allocation: TiltShiftState.Allocation in state.allocations:
					for id: String in allocation.owner_ids:
						check(not id.is_empty(), "Every team paddle has an owner")
				if round_index % 2 == 0:
					check(
						state.auto_direction == (1.0 if round_index == 0 else -1.0),
						"Repeated auto appearance reverses without saved history",
					)
				now = _start_active(controller, now)
				now += 1000
				controller.advance(now)
				if round_index < 3:
					check(controller.start_next_round(now).accepted, "Mapped next round prepares")
			if count == 10:
				var b_only: Array[int] = [0, 0]
				for player: TiltShiftState.Player in controller.snapshot().players:
					check(
						played.get(player.player_id, 0) == 2,
						"Ten-player journey gives two turns each",
					)
					if not exposures[player.player_id].has("a"):
						b_only[player.team] += 1
				check(b_only == [1, 1], "One B-only participant per team")
			if count == 4:
				check(larger.size() == 4, "Four-player larger B shares rotate to every player")
			controller.free()


func _preparation() -> void:
	var controller := TiltShiftShiftController.new()
	controller.tuning = _profile()
	controller.start_shift(TiltShiftFixtures.players(10), 0)
	var state := controller.snapshot()
	check(
		state.panel_visible and state.phase_deadline_msec == 60000,
		"Panel opens with one fixed sixty-second deadline",
	)
	check(
		state.started_at_msec == -1 and state.deadline_msec == -1,
		"Active scoring clock is absent in preparation",
	)
	check(
		not controller.register_ball(state.round_token, 0).accepted,
		"Preparation cannot spawn a scoring ball",
	)
	var selected := PackedStringArray()
	var spectator := ""
	for player: TiltShiftState.Player in state.players:
		if player.selected:
			selected.append(player.player_id)
		else:
			spectator = player.player_id
	check(
		not controller.set_ready(spectator, true, state.round_token, 0).accepted,
		"Spectators cannot release preparation",
	)
	check(
		not controller.set_ready(selected[0], true, state.round_token, 0).accepted,
		"Ordinary READY requires accepted usable motion",
	)
	check(
		controller.accept_angle(selected[0], 0.7, state.round_token, 0).accepted,
		"Selected paddles accept preparation positioning",
	)
	check(
		not controller.accept_angle(spectator, 1.0, state.round_token, 0).accepted,
		"Spectator motion cannot drive a paddle",
	)
	controller.set_motion_usable(selected[0], true)
	controller.set_ready(selected[0], true, state.round_token, 1)
	controller.invalidate_ready(selected[0])
	check(
		not controller.snapshot(selected[0]).players[0].ready,
		"Recalibration invalidates the old confirmation",
	)
	controller.set_connected(selected[0], false)
	check(
		controller.snapshot().phase_deadline_msec == 60000,
		"Disconnect does not extend the readiness deadline",
	)
	controller.advance(60000)
	check(controller.snapshot().phase == &"countdown", "Timeout enters countdown")
	check(
		not controller.force_start(state.round_token, 60000).accepted,
		"Duplicate force cannot restart countdown",
	)
	controller.advance(63000)
	check(controller.snapshot().phase == &"start", "Countdown ends in START, before scoring")
	controller.advance(63600)
	check(controller.snapshot().started_at_msec == 63600, "Clock starts at START completion")
	check(
		not controller.set_ready(selected[0], true, state.round_token, 63600).accepted,
		"Late READY cannot alter active play",
	)
	controller.advance(64600)
	controller.start_next_round(64600)
	check(
		not controller.force_start(state.round_token, 64600).accepted,
		"Prior-round force is rejected",
	)
	controller.free()
	for count: int in [2, 4]:
		controller = TiltShiftShiftController.new()
		controller.tuning = _profile()
		controller.start_shift(TiltShiftFixtures.players(count), 0)
		check(
			controller.snapshot().phase == &"countdown" and not controller.snapshot().panel_visible,
			"Unchanged full participants skip both panel and READY",
		)
		controller.free()


func _content() -> void:
	var profile := _profile()
	check(profile.validation_errors().is_empty(), "Saved A/B content validates")
	profile.paddle_layout = null
	var controller := TiltShiftShiftController.new()
	controller.tuning = profile
	check(
		controller.start_shift(TiltShiftFixtures.players(10), 0).accepted,
		"Explicit layout maps need no compatibility layout reference",
	)
	controller.free()
	check(
		profile.layouts_by_round[0] == profile.layouts_by_round[2],
		"Repeated layout references retain identity",
	)
	profile.layouts_by_round[1].player_length = 0.25
	check(profile.layouts_by_round[0].player_length == 0.20, "Layout sizes are independent")
	profile.physics.delivery_cutoff_seconds = 1.0
	check(
		not profile.validation_errors().is_empty(),
		"Empty positive-budget delivery window is invalid",
	)
