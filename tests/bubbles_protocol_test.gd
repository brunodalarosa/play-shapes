extends SceneTree

const Controller = preload("res://minigames/bubbles_round_controller.gd")
const Protocol = preload("res://host/bubbles_protocol.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var controller := Controller.new()
	root.add_child(controller)
	controller.tuning = BubblesTuning.new()
	controller.tuning.instructions_seconds = 0.0
	controller.tuning.countdown_seconds = 0.0
	controller.tuning.round_duration_seconds = 10.0
	var players := [
		{"player_id": "p0", "name": "First", "seat": 1, "state": "connected"},
		{"player_id": "p1", "name": "Second", "seat": 2, "state": "connected"},
	]
	_check(controller.start_round(players, 0).accepted, "Round starts")
	controller.complete_entrance(0)
	controller.advance(0)
	var protocol := Protocol.new(controller)
	var visual_updates: Array[float] = []
	controller.charge_visual_changed.connect(func(id: String, progress: float) -> void:
		if id == "p0": visual_updates.append(progress))
	var charge_start := {"type": "bubbles_charge", "input_seq": 1, "stage": "start", "step": 0}
	_check(protocol.handle_action(players[0], charge_start, 1).accepted, "Authenticated charge starts a visual gesture")
	_check(protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 1, "stage": "progress", "step": 2}, 2).accepted,
		"Coarse charge step reaches presentation")
	_check(visual_updates.back() == 0.5 and controller.personal_snapshot("p0").last_input_seq == -1,
		"Charge changes only presentation, never accepted gameplay sequence")
	_check(not protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 1, "stage": "progress", "step": 1}, 3).accepted,
		"Out-of-order progress is rejected")
	_check(not protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 1, "stage": "progress", "step": 5}, 3).accepted,
		"Over-range progress is rejected")
	_check(not protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 1, "stage": "progress", "step": 3, "player_id": "p1"}, 3).accepted,
		"Client-authored player identity is rejected")
	_check(not protocol.handle_action(players[1], {"type": "bubbles_charge", "input_seq": 1, "stage": "progress", "step": 3}, 3).accepted,
		"Another authenticated player cannot advance the gesture")
	var json_charge: Dictionary = JSON.parse_string('{"type":"bubbles_charge","input_seq":1,"stage":"progress","step":3}')
	_check(protocol.handle_action(players[0], json_charge, 4).accepted, "JSON numeric charge step reaches the host")
	var swipe := {"type": "bubbles_trace", "input_seq": 1, "trace": [[0.1, 0.5], [0.9, 0.5]]}
	_check(protocol.handle_action(players[0], swipe, 1).accepted, "Authenticated swipe reaches controller")
	_check(visual_updates.back() == 0.0, "Completed trace clears charge cue")
	_check(protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 2, "stage": "start", "step": 0}, 6).accepted,
		"Next gesture may start")
	_check(protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 2, "stage": "cancel", "step": 0}, 7).accepted,
		"Canceled gesture clears visual cue")
	_check(not protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 2, "stage": "progress", "step": 3}, 8).accepted,
		"Canceled gesture cannot resume")
	_check(not protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 2, "stage": "start", "step": 0}, 9).accepted,
		"Canceled gesture sequence cannot restart")
	_check(protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 3, "stage": "start", "step": 0}, 9).accepted,
		"A fresh gesture can start after cancel")
	_check(not protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 3, "stage": "progress", "step": 3}, 2000).accepted,
		"Timed-out charge cannot resume")
	_check(not protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 3, "stage": "start", "step": 0}, 2001).accepted,
		"Timed-out gesture sequence cannot restart")
	_check(controller.personal_snapshot("p0").spin_until_msec == -1, "Charge and cancellation never activate spin")
	_check(controller.personal_snapshot("p0").last_input_seq == 1 and controller.personal_snapshot("p1").last_input_seq == -1,
		"Action only mutates authenticated player")
	_check(not protocol.handle_action(players[0], swipe, 2).accepted, "Duplicate sequence rejected")
	var malformed: Array[Dictionary] = [
		{"type": "bubbles_trace", "input_seq": -1, "trace": swipe.trace},
		{"type": "bubbles_trace", "input_seq": 1.5, "trace": swipe.trace},
		{"type": "bubbles_trace", "input_seq": INF, "trace": swipe.trace},
		{"type": "bubbles_trace", "input_seq": "2", "trace": swipe.trace},
		{"type": "bubbles_trace", "input_seq": 2, "trace": [[0.5, 0.5]]},
		{"type": "bubbles_trace", "input_seq": 2, "trace": [[0.5, NAN], [0.6, 0.5]]},
		{"type": "bubbles_trace", "input_seq": 2, "trace": [[0.5, 0.5], [1.1, 0.5]]},
		{"type": "bubbles_trace", "input_seq": 2, "trace": [[0.5, 0.5], [0.6, 0.5]], "player_id": "p1"},
		{"type": "bubbles_trace", "input_seq": 2, "trace": [[0.5, 0.5], [0.6, 0.5]], "host_time_msec": 999},
		{"type": "bubbles_trace", "input_seq": 2, "trace": _oversized_trace()},
	]
	for packet: Dictionary in malformed:
		_check(not protocol.handle_action(players[0], packet, 3).accepted, "Malformed, oversized, or authority-shaped input rejected")
	_check(not protocol.handle_action({}, {"type": "bubbles_trace", "input_seq": 2, "trace": swipe.trace}, 3).accepted,
		"Unjoined connection cannot act")
	_check(controller.personal_snapshot("p0").last_input_seq == 1, "Rejected packets do not advance accepted sequence")
	var json_packet: Dictionary = JSON.parse_string('{"type":"bubbles_trace","input_seq":2,"trace":[[0.1,0.5],[0.9,0.5]]}')
	_check(protocol.handle_action(players[1], json_packet, 4).accepted, "JSON browser packet is accepted for authenticated player")
	_check(controller.personal_snapshot("p1").last_input_seq == 2, "Second player's sequence remains independent")
	var spin := protocol.handle_action(players[0], {"type": "bubbles_trace", "input_seq": 4, "trace": _circle()}, 5)
	var while_spinning := protocol.handle_action(players[0], {"type": "bubbles_trace", "input_seq": 5, "trace": swipe.trace}, 5)
	_check(spin.accepted and spin.action == "spin" and while_spinning.accepted and while_spinning.action == "swipe",
		"Swipe remains available during host-approved spin")
	var snapshot := protocol.snapshot_for("p0")
	_check(snapshot.type == "bubbles_snapshot" and snapshot.score == 0 and snapshot.visual_jellyfish == 0 and snapshot.seat == 1,
		"Personal snapshot contains exact score and visual state")
	_check(not snapshot.debug_mode, "Normal Bubbles snapshots do not claim debug mode")
	_check(protocol.snapshot_for("unknown").type == "lobby", "Unknown player receives no gameplay state")
	controller.record_jellyfish_capture("p0", 5)
	var collected := protocol.feedback_for("p0", &"captured", {})
	_check(collected.event == "captured" and collected.score == 1 and collected.visual_jellyfish == 1,
		"Collection feedback reflects host score")
	controller.pop_player("p0", 6)
	var pop := protocol.feedback_for("p0", &"pop", {"lost": 1})
	_check(pop.score == 0 and pop.lost == 1 and pop.invulnerable_remaining_msec > 0 and pop.reform_remaining_msec > 0,
		"Pop feedback carries authoritative re-form and invulnerability state")
	controller.advance(10000)
	var results := protocol.snapshot_for("p0")
	_check(results.phase == "results" and results.rank > 0, "Result snapshot includes placement")
	var debug_controller := _controller()
	debug_controller.start_round([{"player_id": "debug", "name": "Debug", "seat": 1}], 0, true)
	var debug_snapshot: Dictionary = Protocol.new(debug_controller).snapshot_for("debug")
	_check(debug_controller.is_one_player_debug() and debug_snapshot.debug_mode,
		"One-player debug state reaches the phone snapshot")
	_test_timed_swipes()
	print("Bubbles protocol checks: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _oversized_trace() -> Array:
	var result := []
	for index: int in 129:
		result.append([0.1, 0.5])
	return result


func _circle() -> Array:
	var result := []
	for index: int in 65:
		var angle := float(index) / 32.0 * TAU
		result.append([0.5 + 0.2 * cos(angle), 0.5 + 0.2 * sin(angle)])
	return result


func _test_timed_swipes() -> void:
	var controller := _controller()
	controller.tuning.instructions_seconds = 0.0
	controller.tuning.countdown_seconds = 0.0
	controller.tuning.round_duration_seconds = 10.0
	var players := [{"player_id": "a", "seat": 1}, {"player_id": "b", "seat": 2}]
	controller.start_round(players, 0)
	controller.set_process(false)
	controller.complete_entrance(0)
	controller.advance(0)
	var protocol := Protocol.new(controller)
	var impulses: Array[StringName] = []
	var drags: Array[Vector2] = []
	controller.arena_event_requested.connect(func(kind: StringName, id: String, _data: Dictionary) -> void:
		if id == "a" and kind in [&"swipe", &"spin"]: impulses.append(kind))
	controller.drag_visual_changed.connect(func(id: String, drag: Vector2) -> void:
		if id == "a": drags.append(drag))
	var swipe := [[0.1, 0.5], [0.9, 0.5]]
	var limit := roundi(controller.tuning.swipe_max_hold_seconds * 1000.0)
	protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 1, "stage": "start", "step": 0}, 100)
	var quick := protocol.handle_action(players[0], {"type": "bubbles_trace", "input_seq": 1, "trace": swipe}, 100 + limit)
	_check(quick.action == "swipe" and impulses.size() == 1, "Swipe at the configured host-time limit applies impulse")
	protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 2, "stage": "start", "step": 0}, 1000)
	_check(protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 2, "stage": "motion", "drag": [-4, 1]}, 1070).accepted,
		"Authenticated coarse drag updates visual cue while held")
	_check(drags.back() == Vector2(-1.0, 0.25) and impulses.size() == 1,
		"Live drag changes no gameplay state before release")
	_check(not protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 2, "stage": "motion", "drag": [-5, 0]}, 1080).accepted,
		"Out-of-range drag is rejected")
	_check(not protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 2, "stage": "motion", "drag": [0.5, 0]}, 1080).accepted,
		"Fractional drag cell is rejected")
	_check(not protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 2, "stage": "motion", "drag": [1, 0], "player_id": "b"}, 1080).accepted,
		"Forged drag identity is rejected")
	var slow := protocol.handle_action(players[0], {"type": "bubbles_trace", "input_seq": 2, "trace": swipe}, 1000 + limit + 1)
	_check(slow.accepted and slow.action == "none" and slow.reason == "swipe_too_slow" and impulses.size() == 1,
		"Slow touch consumes its sequence without applying swipe impulse")
	_check(drags.back() == Vector2.ZERO, "Release clears live drag cue")
	protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 3, "stage": "start", "step": 0}, 2000)
	var long_spin := protocol.handle_action(players[0], {"type": "bubbles_trace", "input_seq": 3, "trace": _circle()}, 2000 + limit + 500)
	_check(long_spin.accepted and long_spin.action == "spin" and impulses.size() == 2,
		"Completed spin remains available after the swipe-only time limit")
	protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 4, "stage": "start", "step": 0}, 5000)
	var before_motion := drags.size()
	for index: int in Protocol.MAX_MOTION_UPDATES + 2:
		protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 4, "stage": "motion", "drag": [index % 5 - 2, 0]}, 5100 + index * 60)
	_check(drags.size() - before_motion == Protocol.MAX_MOTION_UPDATES and impulses.size() == 2,
		"Motion packet cap bounds visual work without changing gameplay")
	protocol.handle_action(players[0], {"type": "bubbles_charge", "input_seq": 4, "stage": "cancel", "step": 0}, 8100)
	_check(not protocol.handle_action(players[0], {"type": "bubbles_trace", "input_seq": 4, "trace": _circle()}, 8200).accepted and impulses.size() == 2,
		"Canceled gesture cannot later activate spin")


func _controller() -> BubblesRoundController:
	var result := Controller.new() as BubblesRoundController
	root.add_child(result)
	result.tuning = BubblesTuning.new()
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
