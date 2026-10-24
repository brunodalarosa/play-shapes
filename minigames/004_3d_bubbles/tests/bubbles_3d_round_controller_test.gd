extends TestScript
## The round rules of Bubbles and jellyfishes 3D without any physics: lifecycle, the zero-time
## freeze, ranking and ties, pops and scatter counts, disconnect and leave, swipe validation and
## the random seam.


func _run() -> void:
	_test_lifecycle_and_zero()
	_test_pop_leave_reconnect()
	_test_swipes_and_sequences()
	_test_participants_and_random()


func _controller() -> Bubbles3DRoundController:
	var controller := Bubbles3DRoundController.new()
	root.add_child(controller)
	controller.tuning = Bubbles3DTuning.new()
	controller.tuning.instructions_seconds = 0.0
	controller.tuning.countdown_seconds = 0.0
	controller.tuning.round_duration_seconds = 10.0
	return controller


func _players() -> Array:
	return [
		{ "player_id": "p1", "name": "One", "seat": 1, "state": "connected" },
		{ "player_id": "p2", "name": "Two", "seat": 2, "state": "connected" },
	]


func _active(controller: Bubbles3DRoundController) -> void:
	check(controller.start_round(_players(), 0).accepted, "A two-player round starts")
	check(controller.phase_name() == &"instructions", "The entrance phase comes first")
	check(
		controller.complete_entrance(0).accepted,
		"The entrance acknowledgment starts the countdown",
	)
	controller.advance(0)
	check(controller.phase_name() == &"active", "GO unlocks active play")


func _test_lifecycle_and_zero() -> void:
	var controller := _controller()
	var results: Array[Dictionary] = []
	var placements: Array[int] = []
	controller.round_results_ready.connect(
		func(value: Dictionary) -> void:
			results.append(value),
	)
	controller.arena_event_requested.connect(
		func(kind: StringName, _id: String, data: Dictionary) -> void:
			if kind == &"place_starting_jellyfish":
				placements.append(int(data.count)),
	)
	check(not controller.request_return_to_lobby(), "Return cannot happen before results")
	_active(controller)
	check(
		placements == [controller.tuning.starting_jellyfish],
		"The countdown asks for the starting jellyfish population once",
	)
	check(controller.record_jellyfish_capture("p1", 9999).accepted, "A catch before zero counts")
	check(
		not controller.record_jellyfish_capture("p1", 10000).accepted,
		"A catch at exactly zero does not count",
	)
	check(
		results.size() == 1 and results[0].finished_at_msec == 10000,
		"The deadline freezes the round once, at the exact instant",
	)
	check(
		results[0].by_player_id.p1.score == 1 and results[0].by_player_id.p1.rank == 1,
		"The frozen result records score and rank by host ID",
	)
	check(results[0].by_player_id.p2.rank == 2, "A lower score ranks lower")
	var tampered: Dictionary = controller.result_snapshot()
	tampered.by_player_id.p1.score = 999
	check(
		controller.result_snapshot().by_player_id.p1.score == 1,
		"Consumers cannot change the frozen result",
	)
	controller.advance(11000)
	check(
		results.size() == 1 and not controller.pop_player("p1", 11000).accepted,
		"Arena events after zero do not rewrite results",
	)
	check(
		controller.request_return_to_lobby() and controller.phase_name() == &"lobby_return",
		"Returning to the lobby follows results",
	)

	var tied := _controller()
	_active(tied)
	tied.advance(10000)
	check(
		tied.result_snapshot().by_player_id.p1.rank == 1
		and tied.result_snapshot().by_player_id.p2.rank == 1,
		"Equal scores share a rank",
	)


func _test_pop_leave_reconnect() -> void:
	var controller := _controller()
	_active(controller)
	for index: int in 5:
		controller.record_jellyfish_capture("p1", index)
	check(
		is_equal_approx(controller.personal_snapshot("p1").bubble_radius, 0.48 + 5 * 0.02),
		"Each catch grows the bubble",
	)
	var popped := controller.pop_player("p1", 5)
	check(
		popped.accepted and popped.lost == 5 and popped.released == 3,
		"A pop clears the whole catch and scatters the rounded remainder",
	)
	check(
		is_equal_approx(controller.personal_snapshot("p1").bubble_radius, 0.48),
		"A popped bubble re-forms at the starting size",
	)
	check(
		not controller.record_jellyfish_capture("p1", 6).accepted,
		"An invulnerable bubble cannot catch",
	)
	check(not controller.pop_player("p1", 6).accepted, "An invulnerable bubble cannot pop again")
	check(
		controller.record_jellyfish_capture("p1", 5 + 2000).accepted,
		"Catching resumes when the invulnerability ends",
	)
	controller.observe_registry(
		[{ "player_id": "p1", "state": "reconnecting" }, _players()[1]],
		2100,
	)
	check(
		not controller.player_snapshot().p1.connected and not controller.player_snapshot().p1.left,
		"A disconnected player stays in play",
	)
	controller.observe_registry(_players(), 2200)
	check(
		controller.personal_snapshot("p1").connected
		and controller.personal_snapshot("p1").score == 1,
		"A reconnecting player keeps the host state",
	)
	controller.record_jellyfish_capture("p2", 2300)
	controller.observe_registry([_players()[0]], 2400)
	check(
		controller.player_snapshot().p2.left and controller.player_snapshot().p2.score == 0,
		"An explicit leave pops the bubble and removes control",
	)
	check(
		not controller.record_jellyfish_capture("p2", 2500).accepted,
		"A player who left cannot catch",
	)
	controller.advance(10000)
	check(
		controller.result_snapshot().by_player_id.p2.left,
		"The frozen result keeps every original participant",
	)


func _test_swipes_and_sequences() -> void:
	var controller := _controller()
	_active(controller)
	var swipes: Array[Dictionary] = []
	controller.arena_event_requested.connect(
		func(kind: StringName, _id: String, data: Dictionary) -> void:
			if kind == &"swipe":
				swipes.append(data),
	)
	var right := Vector2(0.2, 0.0)
	check(controller.submit_swipe("p1", 1, right, 1).action == &"swipe", "A valid swipe moves")
	check(
		swipes.size() == 1 and swipes[0].direction == Vector2.RIGHT
		and is_equal_approx(swipes[0].strength, controller.tuning.swipe_impulse),
		"One swipe asks the arena for one fixed-strength push in its direction",
	)
	controller.submit_swipe("p1", 2, Vector2(0.9, 0.0), 2)
	check(
		is_equal_approx(swipes[1].strength, swipes[0].strength),
		"A longer swipe adds no strength",
	)
	check(
		not controller.submit_swipe("p1", 2, right, 3).accepted,
		"A repeated sequence is rejected",
	)
	check(
		not controller.submit_swipe("p1", INF, right, 3).accepted,
		"A non-finite sequence is rejected",
	)
	check(
		not controller.submit_swipe("p1", 9_007_199_254_740_992, right, 3).accepted,
		"A sequence beyond exact integers is rejected",
	)
	check(
		not controller.submit_swipe("unknown", 3, right, 3).accepted,
		"An unknown player is rejected",
	)
	check(
		not controller.submit_swipe("p1", 3, Vector2(NAN, 0.0), 3).accepted,
		"A non-finite displacement is rejected",
	)
	check(
		not controller.submit_swipe("p1", 3, Vector2(1.5, 0.0), 3).accepted,
		"A displacement beyond the touch area is rejected",
	)
	check(
		controller.submit_swipe("p1", 3, right, 4).accepted,
		"A rejected swipe keeps its sequence",
	)
	var short := controller.submit_swipe("p1", 4, Vector2(0.01, 0.0), 5)
	check(
		short.action == &"none" and short.reason == &"swipe_too_short",
		"A swipe under the recognition distance does nothing",
	)
	var slow := controller.submit_swipe("p1", 5, right, 2000, 100)
	check(
		slow.action == &"none" and slow.reason == &"swipe_too_slow",
		"A touch held past the swipe limit does nothing on release",
	)
	check(
		controller.submit_swipe("p1", 6, right, 2700, 2000).action == &"swipe",
		"A touch released within the limit moves",
	)
	check(
		not controller.submit_swipe("p1", 7, right, 2800, 2900).accepted,
		"A touch that starts after its release is rejected",
	)
	check(swipes.size() == 4, "Only accepted swipes push the bubble")
	controller.observe_registry(
		[{ "player_id": "p1", "state": "reconnecting" }, _players()[1]],
		2900,
	)
	check(
		not controller.submit_swipe("p1", 8, right, 3000).accepted,
		"A disconnected player cannot swipe",
	)
	controller.advance(10000)
	check(
		not controller.submit_swipe("p2", 1, right, 10000).accepted,
		"A swipe at exactly zero does nothing",
	)


func _test_participants_and_random() -> void:
	var controller := _controller()
	var alone := [_players()[0]]
	check(not controller.start_round(alone, 0).accepted, "A normal round needs two players")
	var twins := [_players()[0], _players()[0]]
	check(not controller.start_round(twins, 0).accepted, "Duplicate host IDs are rejected")
	var eleven: Array = []
	for index: int in 11:
		eleven.append({ "player_id": "p%d" % index, "seat": index + 1 })
	check(not controller.start_round(eleven, 0).accepted, "More than ten players are rejected")
	controller.tuning.starting_radius = 1.0
	controller.tuning.max_radius = 0.5
	check(not controller.start_round(_players(), 0).accepted, "Invalid tuning prevents a start")
	controller.tuning.max_radius = 1.7
	controller.tuning.starting_radius = 0.48
	check(
		controller.start_round(alone, 0, true).accepted and controller.is_one_player_debug(),
		"An explicit debug round accepts one player",
	)
	check(controller.inject_random_values([0.25, 0.75]), "Finite random values are accepted")
	check(
		controller.next_random_unit() == 0.25 and controller.next_random_unit() == 0.75,
		"Injected random values come back in order",
	)
	check(not controller.inject_random_values([INF]), "Invalid random values are rejected")
	var snapshot := controller.personal_snapshot("p1")
	check(
		not snapshot.has("spin_until_msec") and not snapshot.has("spin_ready_msec"),
		"A player snapshot carries no spin state",
	)
