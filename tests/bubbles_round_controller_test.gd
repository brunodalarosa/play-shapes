extends TestScript

const Controller = preload("res://minigames/bubbles_round_controller.gd")


func _run() -> void:
	_test_lifecycle_and_zero()
	_test_pop_leave_reconnect()
	_test_gestures_and_sequences()
	_test_participants_and_random()


func _controller() -> Node:
	var controller := Controller.new()
	root.add_child(controller)
	controller.tuning = BubblesTuning.new()
	controller.tuning.instructions_seconds = 0.0
	controller.tuning.countdown_seconds = 0.0
	controller.tuning.round_duration_seconds = 10.0
	return controller


func _players() -> Array:
	return [
		{ "player_id": "p1", "name": "One", "seat": 1, "state": "connected" },
		{ "player_id": "p2", "name": "Two", "seat": 2, "state": "connected" },
	]


func _active(controller: Node) -> void:
	check(controller.start_round(_players(), 0).accepted, "Normal two-player round starts")
	check(controller.phase_name() == &"instructions", "Instruction phase starts first")
	check(controller.complete_entrance(0).accepted, "Entrance acknowledgment starts countdown")
	controller.advance(0)
	check(controller.phase_name() == &"active", "GO unlocks active play")


func _test_lifecycle_and_zero() -> void:
	var controller := _controller()
	var results: Array[Dictionary] = []
	controller.round_results_ready.connect(
		func(value: Dictionary) -> void:
			results.append(value),
	)
	check(not controller.request_return_to_lobby(), "Return cannot occur before results")
	_active(controller)
	check(controller.record_jellyfish_capture("p1", 9999).accepted, "Catch before deadline counts")
	check(
		not controller.record_jellyfish_capture("p1", 10000).accepted,
		"Catch at exact zero cannot count",
	)
	check(
		results.size() == 1 and results[0].finished_at_msec == 10000,
		"Deadline freezes once at exact instant",
	)
	check(
		results[0].by_player_id.p1.score == 1 and results[0].by_player_id.p1.rank == 1,
		"Frozen result records score and rank by host ID",
	)
	check(results[0].by_player_id.p2.rank == 2, "Second score ranks second")
	var tampered: Dictionary = controller.result_snapshot()
	tampered.by_player_id.p1.score = 999
	check(
		controller.result_snapshot().by_player_id.p1.score == 1,
		"Result snapshots cannot be mutated by consumers",
	)
	controller.advance(11000)
	check(
		results.size() == 1 and not controller.pop_player("p1", 11000).accepted,
		"Post-finish arena events do not rewrite results",
	)
	check(
		controller.request_return_to_lobby() and controller.phase_name() == &"lobby_return",
		"Host return follows results",
	)

	var tied := _controller()
	_active(tied)
	tied.advance(10000)
	check(
		tied.result_snapshot().by_player_id.p1.rank == 1
		and tied.result_snapshot().by_player_id.p2.rank == 1,
		"Equal scores share rank",
	)


func _test_pop_leave_reconnect() -> void:
	var controller := _controller()
	_active(controller)
	for index: int in 5:
		controller.record_jellyfish_capture("p1", index)
	var popped: Dictionary = controller.pop_player("p1", 5)
	check(
		popped.accepted and popped.lost == 5 and popped.released == 3,
		"Pop clears all score and rounds retained half",
	)
	check(
		not controller.record_jellyfish_capture("p1", 6).accepted,
		"Invulnerable bubble cannot collect",
	)
	check(not controller.pop_player("p1", 6).accepted, "Invulnerable bubble cannot pop again")
	controller.observe_registry([{ "player_id": "p1", "state": "reconnecting" }, _players()[1]], 7)
	check(
		not controller.player_snapshot().p1.connected and not controller.player_snapshot().p1.left,
		"Disconnect keeps bubble active",
	)
	controller.observe_registry(_players(), 8)
	check(
		controller.personal_snapshot("p1").connected
		and controller.personal_snapshot("p1").score == 0,
		"Reconnect snapshot retains host state",
	)
	controller.record_jellyfish_capture("p2", 10)
	controller.observe_registry([_players()[0]], 11)
	check(
		controller.player_snapshot().p2.left and controller.player_snapshot().p2.score == 0,
		"Explicit leave pops and removes control",
	)
	check(not controller.record_jellyfish_capture("p2", 12).accepted, "Left player cannot collect")
	controller.advance(10000)
	check(
		controller.result_snapshot().by_player_id.p2.left,
		"Frozen result retains original participant identity",
	)


func _test_gestures_and_sequences() -> void:
	var controller := _controller()
	_active(controller)
	var events: Array[StringName] = []
	controller.arena_event_requested.connect(
		func(kind: StringName, _id: String, _data: Dictionary) -> void:
			events.append(kind),
	)
	var swipe: Array = [[0.1, 0.2], [0.2, 0.2]]
	check(controller.submit_trace("p1", 1, swipe, 1).action == &"swipe", "Valid swipe is accepted")
	check(events.count(&"swipe") == 1, "One trace creates one arena action")
	check(not controller.submit_trace("p1", 1, swipe, 2).accepted, "Duplicate sequence is rejected")
	check(
		not controller.submit_trace("p1", INF, swipe, 2).accepted,
		"Non-finite sequence is rejected",
	)
	check(
		not controller.submit_trace("p1", 9_007_199_254_740_992, swipe, 2).accepted,
		"Sequence above exact integer range is rejected",
	)
	check(
		not controller.submit_trace("unknown", 2, swipe, 2).accepted,
		"Unknown host player ID is rejected",
	)
	var malformed: Dictionary = controller.submit_trace("p1", 2, [[0.0, 0.0], [NAN, 0.0]], 3)
	check(not malformed.accepted, "Malformed trace is rejected")
	check(
		controller.submit_trace("p1", 2, swipe, 4).accepted,
		"Malformed trace does not consume sequence",
	)
	check(
		controller.submit_trace("p1", 3, _circle(), 5).action == &"spin",
		"Completed circle activates on release",
	)
	check(
		controller.submit_trace("p1", 4, _circle(), 6).action == &"none",
		"Spin cooldown blocks immediate replay",
	)
	check(events.count(&"spin") == 1, "Cooldown does not emit another spin")
	check(
		controller.submit_trace("p1", 5, swipe, 7).action == &"swipe",
		"Swipe works during active spin",
	)
	check(events.count(&"swipe") == 3, "Each valid swipe emits exactly once")
	controller.advance(10000)
	check(
		not controller.submit_trace("p1", 6, swipe, 10000).accepted,
		"Gesture at exact zero cannot create an action",
	)


func _test_participants_and_random() -> void:
	var controller := _controller()
	var one_player: Dictionary = controller.start_round([_players()[0]], 0)
	check(not one_player.accepted, "Normal round rejects one player")
	var duplicates: Dictionary = controller.start_round([_players()[0], _players()[0]], 0)
	check(not duplicates.accepted, "Duplicate host IDs are rejected")
	controller.tuning.max_radius = 32.0
	controller.tuning.starting_radius = 100.0
	check(
		not controller.start_round(_players(), 0).accepted,
		"Invalid tuning prevents a round start",
	)
	controller.tuning.max_radius = 110.0
	controller.tuning.starting_radius = 48.0
	var debug_round: Dictionary = controller.start_round([_players()[0]], 0, true)
	check(debug_round.accepted, "Explicit debug round accepts one player")
	check(
		controller.inject_random_values([0.25, 0.75]),
		"Finite injected random values are accepted",
	)
	check(
		controller.next_random_unit() == 0.25 and controller.next_random_unit() == 0.75,
		"Injected random stream is deterministic",
	)
	check(not controller.inject_random_values([INF]), "Invalid injected random values are rejected")


func _circle() -> Array:
	var points: Array = []
	for index: int in 65:
		var angle := float(index) / 32.0 * TAU
		points.append([0.5 + 0.2 * cos(angle), 0.5 + 0.2 * sin(angle)])
	return points
