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
	var swipe := {"type": "bubbles_trace", "input_seq": 1, "trace": [[0.1, 0.5], [0.9, 0.5]]}
	_check(protocol.handle_action(players[0], swipe, 1).accepted, "Authenticated swipe reaches controller")
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
	var spin := protocol.handle_action(players[0], {"type": "bubbles_trace", "input_seq": 2, "trace": _circle()}, 5)
	var while_spinning := protocol.handle_action(players[0], {"type": "bubbles_trace", "input_seq": 3, "trace": swipe.trace}, 5)
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


func _controller() -> BubblesRoundController:
	var result := Controller.new() as BubblesRoundController
	root.add_child(result)
	result.tuning = BubblesTuning.new()
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
