extends TestScript


func _run() -> void:
	_test_deadline_order()
	_test_resolution_and_totals()
	_test_identity_and_angles()
	_test_snapshot_and_content_isolation()
	_test_reentrant_signals()
	_test_invalid_time_and_preparation()


func _controller(rounds: int = 2) -> TiltShiftShiftController:
	var controller := TiltShiftShiftController.new()
	controller.tuning = TiltShiftFixtures.tuning(rounds)
	controller.set_random_seed(72)
	root.add_child(controller)
	return controller


func _test_deadline_order() -> void:
	for timer_first: bool in [false, true]:
		for offset: int in [-1, 0, 1]:
			var controller := _controller(1)
			var endings: Array[TiltShiftState.Snapshot] = []
			var shifts: Array[TiltShiftState.Snapshot] = []
			controller.round_ended.connect(
				func(value: TiltShiftState.Snapshot) -> void:
					endings.append(value),
			)
			controller.shift_finished.connect(
				func(value: TiltShiftState.Snapshot) -> void:
					shifts.append(value),
			)
			controller.start_shift(TiltShiftFixtures.players(2), 0)
			var token := controller.snapshot().round_token
			var ball := controller.register_ball(token, 0).ball
			if timer_first:
				controller.advance(1000 + offset)
			var catch := controller.resolve_ball(ball, "orange_left", 1000 + offset)
			check(
				catch.accepted == (offset < 0),
				"Host deadline is exclusive in either callback order",
			)
			controller.advance(2000)
			controller.advance(3000)
			check(endings.size() == 1 and shifts.size() == 1, "Round and final shift end emit once")
			check(endings[0].deadline_msec == 1000, "Late clock steps preserve the actual deadline")
			check(
				endings[0].scores[0] == (1 if offset < 0 else 0),
				"Only a pre-deadline catch survives in frozen totals",
			)
			check(
				not controller.resolve_ball(ball, "orange_left", 3000).accepted,
				"Repeated and late callbacks cannot score again",
			)
			check(
				not controller.register_ball(token, 3000).accepted,
				"No ball can be registered after the scoring window",
			)
			controller.free()


func _test_resolution_and_totals() -> void:
	var controller := _controller()
	controller.start_shift(TiltShiftFixtures.players(4), 0)
	var token := controller.snapshot().round_token
	var orange := controller.register_ball(token, 0).ball
	var blue := controller.register_ball(token, 0).ball
	var trash := controller.register_ball(token, 0).ball
	var discarded := controller.register_ball(token, 0).ball
	var pending := controller.register_ball(token, 0).ball
	check(
		not controller.resolve_ball(orange, "missing_basket", 10).accepted,
		"Unknown basket cannot score or consume the ball",
	)
	check(
		controller.resolve_ball(orange, "orange_left", 10).accepted,
		"Catch awards one point to the basket team",
	)
	check(
		not controller.resolve_ball(orange, "blue_left", 10).accepted,
		"One ball cannot score for both teams",
	)
	check(
		controller.resolve_ball(blue, "blue_left", 10).accepted,
		"The opponent basket awards a point to its own team",
	)
	check(
		controller.resolve_ball(trash, "trash_center", 10).accepted,
		"Trash resolves a ball without a point",
	)
	check(controller.discard_ball(discarded, 10).accepted, "Out-of-bounds discard earns no points")
	check(
		not controller.resolve_ball(discarded, "orange_left", 10).accepted,
		"A discarded ball cannot later score",
	)
	var unknown := TiltShiftState.BallHandle.new()
	unknown.round_token = token
	unknown.index = 999
	check(
		not controller.resolve_ball(unknown, "orange_left", 10).accepted,
		"Unknown handles cannot create points",
	)
	unknown.index = -1
	check(not controller.discard_ball(unknown, 10).accepted, "Negative handle indices are rejected")
	check(controller.snapshot().scores == [1, 1], "Only team baskets change cumulative totals")
	controller.advance(1000)
	check(controller.snapshot().phase == &"between_rounds", "First round waits for host cleanup")
	check(
		controller.start_next_round(1200).accepted,
		"Next round is explicitly started after cleanup",
	)
	var second := controller.snapshot()
	check(
		second.round_token != token and second.scores == [1, 1],
		"New round identity retains cumulative team scores",
	)
	check(
		not controller.resolve_ball(pending, "orange_left", 1200).accepted,
		"An old unresolved ball cannot score in a new round",
	)
	var new_ball := controller.register_ball(second.round_token, 1200).ball
	check(
		not controller.resolve_ball(orange, "orange_left", 1200).accepted,
		"An old resolved handle cannot impersonate a reused index",
	)
	check(
		controller.resolve_ball(new_ball, "blue_right", 1200).accepted,
		"Current-round ball can increase the persisted total",
	)
	controller.advance(2200)
	var final := controller.snapshot()
	check(
		final.scores == [1, 2] and final.winner == 1 and not final.is_draw,
		"Highest cumulative score wins, independent of round wins",
	)
	check(not controller.start_next_round(2200).accepted, "No rounds remain after shift end")
	check(
		controller.start_shift(TiltShiftFixtures.players(4), 2200).accepted,
		"A new shift starts after frozen results",
	)
	check(controller.snapshot().scores == [0, 0], "Totals reset only for a new shift")
	check(
		not controller.resolve_ball(new_ball, "blue_left", 2200).accepted,
		"Old shift handles cannot score in a new shift",
	)
	controller.advance(3200)
	controller.start_next_round(3200)
	controller.advance(4200)
	final = controller.snapshot()
	check(
		final.is_draw and final.winner == -1,
		"Equal shift totals produce a draw without tiebreak",
	)
	controller.free()


func _test_identity_and_angles() -> void:
	var controller := _controller()
	controller.start_shift(TiltShiftFixtures.players(4), 0)
	var player := controller.snapshot().players[0]
	var token := controller.snapshot().round_token
	check(
		controller.accept_angle(player.player_id, TAU * 3.0 + 0.5, token, 10).accepted,
		"Accepted controls retain continuous complete turns",
	)
	check(
		controller.set_connected(player.player_id, false).accepted,
		"Disconnect annotates live state",
	)
	var held := controller.snapshot(player.player_id).players[0]
	check(
		not held.connected and held.team == player.team
		and held.paddle_ids == player.paddle_ids and held.angle_radians == TAU * 3.0 + 0.5,
		"Disconnect holds team, assignments and angle",
	)
	check(
		controller.snapshot().phase == &"active",
		"Disconnected participant does not pause the round",
	)
	check(
		not controller.accept_angle(player.player_id, NAN, token, 20).accepted,
		"Non-finite angles are rejected without overwriting control",
	)
	check(
		not controller.accept_angle("unknown", 1.0, token, 20).accepted,
		"Unknown players cannot control paddles",
	)
	controller.advance(1000)
	controller.start_next_round(1000)
	var next := controller.snapshot(player.player_id).players[0]
	check(
		not next.connected and next.angle_radians == held.angle_radians,
		"Round redistribution retains the absent player's last angle",
	)
	check(controller.set_connected(player.player_id, true).accepted, "Original identity can resume")
	var resumed := controller.snapshot(player.player_id).players[0]
	check(
		resumed.team == next.team and resumed.paddle_ids == next.paddle_ids
		and resumed.angle_radians == next.angle_radians,
		"Resume does not change ownership or neutral",
	)
	check(
		not controller.accept_angle(player.player_id, -1.0, token, 1000).accepted,
		"Queued old-round control cannot overwrite the held angle",
	)
	var current_token := controller.snapshot().round_token
	check(
		controller.accept_angle(player.player_id, -TAU * 2.0, current_token, 1010).accepted,
		"Current control supports reversal/full turns",
	)
	controller.free()


func _test_snapshot_and_content_isolation() -> void:
	var controller := _controller()
	var roster := TiltShiftFixtures.players(2)
	controller.start_shift(roster, 0)
	var expected := controller.snapshot()
	roster[0].player_name = "Changed outside"
	roster[0].player_id = "different_identity"
	controller.tuning.paddle_layout.paddles[0].position = Vector2(0.99, 0.99)
	controller.tuning.baskets_by_round[0].openings[0].team = TiltShiftTypes.Team.BLUE
	controller.tuning.round_count = 1
	controller.tuning.round_duration_seconds = 20.0
	var snapshot := controller.snapshot()
	check(
		snapshot.players[0].player_name == expected.players[0].player_name,
		"External roster edits cannot change running identities",
	)
	check(
		snapshot.paddle_layout.paddles[0].position == expected.paddle_layout.paddles[0].position,
		"External layout edits cannot move running paddles",
	)
	check(
		snapshot.basket_preset.openings[0].team == expected.basket_preset.openings[0].team
		and snapshot.round_count == 2 and snapshot.deadline_msec == 1000,
		"External content edits cannot change current scoring rules or duration",
	)
	snapshot.players[0].paddle_ids.clear()
	snapshot.players[0].team = 999
	snapshot.scores[0] = 999
	snapshot.allocations[0].owner_ids.clear()
	snapshot.neighbors.clear()
	snapshot.paddle_layout.paddles[0].paddle_id = "tampered"
	snapshot.basket_preset.openings[0].width = 100.0
	var untouched := controller.snapshot()
	check(
		untouched.scores == [0, 0] and untouched.players[0].team == expected.players[0].team
		and untouched.players[0].paddle_ids == expected.players[0].paddle_ids,
		"Returned snapshot edits cannot change players, ownership or scores",
	)
	check(
		untouched.paddle_layout.paddles[0].paddle_id == expected.paddle_layout.paddles[0].paddle_id
		and untouched.basket_preset.openings[0].width == expected.basket_preset.openings[0].width,
		"Returned content copies cannot mutate frozen resources",
	)
	controller.advance(1000)
	check(
		controller.start_next_round(1000).accepted and controller.snapshot().deadline_msec == 2000,
		"The whole shift uses the content captured at launch",
	)
	controller.free()


func _test_reentrant_signals() -> void:
	var controller := _controller()
	var endings: Array[TiltShiftState.Snapshot] = []
	var transition_attempts: Array[bool] = []
	var round_listener := func(value: TiltShiftState.Snapshot) -> void:
		endings.append(value)
		transition_attempts.append(controller.start_next_round(value.deadline_msec).accepted)
		value.scores[0] = 400
	controller.round_ended.connect(round_listener)
	controller.start_shift(TiltShiftFixtures.players(2), 0)
	var token := controller.snapshot().round_token
	var ball := controller.register_ball(token, 0).ball
	var repeated: Array[bool] = []
	var score_listener := func(_value: TiltShiftState.Snapshot) -> void:
		repeated.append(controller.resolve_ball(ball, "orange_left", 10).accepted)
	controller.score_changed.connect(score_listener)
	check(controller.resolve_ball(ball, "orange_left", 10).accepted, "Initial catch is accepted")
	check(
		repeated == [false] and controller.snapshot().scores == [1, 0],
		"Score notification cannot reenter or double-resolve the same ball",
	)
	controller.advance(1000)
	check(
		endings.size() == 1 and transition_attempts == [false]
		and controller.snapshot().phase == &"between_rounds",
		"Round-end notification cannot reenter a round transition",
	)
	check(
		controller.snapshot().scores == [1, 0],
		"Signal consumers cannot change authoritative totals",
	)
	controller.round_ended.disconnect(round_listener)
	controller.score_changed.disconnect(score_listener)
	controller.free()


func _test_invalid_time_and_preparation() -> void:
	var controller := _controller()
	check(
		not controller.start_shift(TiltShiftFixtures.players(2), -1).accepted,
		"Negative start time cannot create a scoring window",
	)
	controller.tuning.baskets_by_round.pop_back()
	var invalid := controller.start_shift(TiltShiftFixtures.players(2), 0)
	check(
		not invalid.accepted and invalid.reason == &"invalid_tuning"
		and not invalid.errors.is_empty(),
		"Invalid round mappings fail before play with designer errors",
	)
	check(controller.snapshot().phase == &"idle", "Invalid content never starts a round")
	controller.tuning = TiltShiftFixtures.tuning()
	controller.start_shift(TiltShiftFixtures.players(2), 100)
	var token := controller.snapshot().round_token
	check(not controller.register_ball(token, 99).accepted, "Backdated registration is rejected")
	check(
		not controller.start_shift(TiltShiftFixtures.players(4), 100).accepted,
		"A running roster cannot be replaced",
	)
	check(not controller.start_next_round(100).accepted, "Active round cannot be skipped")
	check(not controller.advance(99).accepted, "Clock cannot move backwards")
	check(
		not controller.accept_angle("player_0", 1.0, "obsolete", 1100).accepted
		and controller.snapshot().phase == &"between_rounds",
		"Even obsolete input settles the real scoring deadline",
	)
	controller.free()
