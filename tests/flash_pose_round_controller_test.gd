extends SceneTree

const Controller = preload("res://minigames/flash_pose_round_controller.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_lifecycle_deadline_and_flash_order()
	_test_input_rejection_and_immutable_resolution()
	_test_two_failures_eliminate_once()
	_test_registry_disconnect_and_withdrawal()
	_test_timeout_ranking_and_one_player_debug()
	if _failures == 0:
		print("Flash Pose round controller checks passed")
	quit(0 if _failures == 0 else 1)


func _test_lifecycle_deadline_and_flash_order() -> void:
	var controller := _controller(0.0, 10.0)
	controller.inject_sequences([&"swing"], [&"left", &"right"], [100, 100])
	var events: Array[StringName] = []
	controller.pose_evaluation_resolved.connect(func(_id: int, _results: Array[Dictionary]) -> void: events.append(&"resolved"))
	controller.flash_requested.connect(func(_id: int, _results: Array[Dictionary]) -> void: events.append(&"flash"))
	var started: Dictionary = controller.start_round(_participants(), 0)
	_check(started.accepted and started.style == &"swing", "Injected style is selected once for the round")
	controller.advance(0)
	_check(controller.phase_name() == &"dance", "Zero countdown enters dance")
	controller.advance(100)
	_check(controller.phase_name() == &"genuine_stop_grace" and controller.current_target == &"left",
		"Injected interval and target open a genuine stop")
	_check(controller.submit_pose_input("p1", &"left", true, 1, 100).accepted,
		"Input is accepted during grace")
	_check(controller.submit_pose_input("p2", &"left", true, 1, 100).accepted,
		"Second player input is accepted during grace")
	var deadline: int = roundi(controller.tuning.pose_grace_seconds * 1000.0 + 100.0)
	_check(controller.submit_pose_input("p1", &"left", true, 2, deadline).accepted,
		"Input at the exact authoritative deadline is accepted")
	controller.advance(deadline)
	_check(events == [&"resolved", &"flash"], "Authoritative results emit before exactly one flash request")
	_check(controller.phase_name() == &"flash_wait", "Controller waits for matching flash completion")
	_check(not controller.acknowledge_flash(99, deadline).accepted,
		"Mismatched flash completion is harmless")
	_check(controller.acknowledge_flash(1, deadline).accepted and controller.phase_name() == &"dance",
		"Matching flash completion resumes the dance cycle")
	_check(not controller.acknowledge_flash(1, deadline).accepted and events.count(&"flash") == 1,
		"Repeated completion cannot emit a second flash")


func _test_input_rejection_and_immutable_resolution() -> void:
	var controller := _controller(0.0, 10.0)
	controller.inject_sequences([&"bounce"], [&"right"], [0])
	controller.start_round(_participants(), 0)
	_check(controller.submit_pose_input("p1", &"right", true, 1, 0).accepted,
		"Free posing starts with the minigame countdown")
	controller.advance(0)
	controller.advance(0)
	_check(controller.submit_pose_input("unknown", &"right", true, 1, 0).code == &"unknown_player",
		"Unknown players are rejected")
	_check(controller.submit_pose_input("p1", &"up", true, 1, 0).code == &"locked_direction",
		"Directions remain locked until their host-time threshold")
	_check(controller.submit_pose_input("p1", &"right", true, 4, 0).accepted,
		"Valid ordered input reaches pose rules")
	_check(controller.submit_pose_input("p1", &"right", true, 4, 100).code == &"stale_input",
		"Duplicate input sequence is rejected")
	var deadline: int = controller._pose_rules.current_deadline_msec()
	controller.advance(deadline)
	var lives_after: int = controller._players.p2.lives
	_check(controller.submit_pose_input("p2", &"right", true, 1, deadline + 1).accepted,
		"Input after resolution drives free posing for the next dance segment")
	controller.advance(deadline + 1)
	_check(controller._players.p2.lives == lives_after, "Post-result free posing cannot rewrite a resolved life loss")


func _test_registry_disconnect_and_withdrawal() -> void:
	var controller := _controller(0.0, 10.0)
	controller.inject_sequences([&"disco"], [&"left"], [0])
	controller.start_round(_participants(), 0)
	controller.advance(0)
	controller.advance(0)
	controller.submit_pose_input("p1", &"left", true, 1, 0)
	controller.observe_registry([
		{"player_id": "p1", "state": "reconnecting"},
		{"player_id": "p2", "state": "connected"},
	], 100)
	_check(not controller._pose_rules.semantic_state("p1").held,
		"Temporary disconnect clears held input without replacing identity")
	controller.observe_registry([
		{"player_id": "p1", "state": "connected"},
	], 200)
	_check(controller._players.p2.state == &"withdrawn" and controller._players.p2.lives == 2,
		"Explicit registry removal withdraws a player without life loss")
	_check(not controller._pose_rules.semantic_state("p1").held,
		"Reconnect does not invent a held input")


func _test_two_failures_eliminate_once() -> void:
	var controller := _controller(0.0, 10.0)
	controller.tuning.charge_fill_seconds = 0.1
	controller.tuning.pose_grace_seconds = 0.2
	controller.inject_sequences([&"bounce"], [&"left", &"right"], [0, 0])
	var resolved_count := [0]
	controller.pose_evaluation_resolved.connect(
		func(_id: int, _results: Array[Dictionary]) -> void: resolved_count[0] += 1)
	controller.start_round(_participants(), 0)
	controller.advance(0)
	controller.advance(0)
	controller.submit_pose_input("p1", &"left", true, 1, 0)
	controller.advance(200)
	_check(controller._players.p2.lives == 1 and controller._players.p2.state == &"active",
		"A failed stop deducts exactly one life")
	controller.acknowledge_flash(1, 200)
	controller.advance(200)
	controller.submit_pose_input("p1", &"right", true, 2, 200)
	controller.advance(400)
	_check(controller._players.p2.lives == 0 and controller._players.p2.state == &"eliminated",
		"A second failure eliminates at zero lives")
	controller.advance(500)
	_check(resolved_count[0] == 2 and controller._players.p2.elimination_order == 1,
		"A resolved stop cannot deduct or eliminate twice")


func _test_timeout_ranking_and_one_player_debug() -> void:
	var controller := _controller(0.0, 10.0)
	controller.inject_sequences([&"bounce"], [], [20_000])
	var results: Array[Dictionary] = []
	controller.round_results_ready.connect(func(snapshot: Dictionary) -> void: results.append(snapshot))
	controller.start_round([
		{"player_id": "z-player", "name": "Z", "seat": 1, "state": "connected"},
		{"player_id": "a-player", "name": "A", "seat": 2, "state": "connected"},
	], 0)
	controller.advance(0)
	controller.advance(10_000)
	_check(results.size() == 1 and results[0].reason == &"timeout", "Host round deadline produces results")
	_check(results[0].ranking[0].player_id == "a-player" and results[0].top_group_size == 1,
		"All-perfect timeout uses stable player IDs and the smaller top half")
	_check(controller.request_return_to_lobby() and controller.phase_name() == &"lobby_return",
		"Results wait for an explicit host return request")

	var debug_controller := _controller(0.0, 10.0)
	_check(not debug_controller.start_round([_participants()[0]], 0).accepted,
		"Normal start rejects one participant")
	_check(debug_controller.start_round([_participants()[0]], 0, true).accepted,
		"Explicit debug start accepts one participant")


func _controller(countdown: float, duration: float) -> Node:
	var controller := Controller.new()
	var tuning := SimonSaysTuning.new()
	tuning.countdown_seconds = countdown
	tuning.round_duration_seconds = duration
	controller.tuning = tuning
	root.add_child(controller)
	return controller


func _participants() -> Array[Dictionary]:
	return [
		{"player_id": "p1", "name": "One", "seat": 1, "state": "connected"},
		{"player_id": "p2", "name": "Two", "seat": 2, "state": "connected"},
	]


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(description)
