extends TestScript

const Controller = preload("res://minigames/bubbles_round_controller.gd")
const Protocol = preload("res://host/bubbles_protocol.gd")


func _run() -> void:
	var controller := Controller.new()
	root.add_child(controller)
	controller.tuning = BubblesTuning.new()
	controller.tuning.instructions_seconds = 0.0
	controller.tuning.countdown_seconds = 0.0
	controller.tuning.round_duration_seconds = 10.0
	var players := [
		{
			"player_id": "p0",
			"name": "First",
			"seat": 1,
			"state": "connected",
			"character_shape": "squircle",
			"character_color": "#EC407A",
		},
		{
			"player_id": "p1",
			"name": "Second",
			"seat": 2,
			"state": "connected",
			"character_shape": "square",
			"character_color": "#00ACC1",
		},
	]
	check(controller.start_round(players, 0).accepted, "Round starts")
	controller.complete_entrance(0)
	controller.advance(0)
	var protocol := Protocol.new(controller)
	var visual_updates: Array[float] = []
	controller.charge_visual_changed.connect(
		func(id: String, progress: float) -> void:
			if id == "p0":
				visual_updates.append(progress),
	)
	var charge_start := { "type": "bubbles_charge", "input_seq": 1, "stage": "start", "step": 0 }
	check(
		protocol.handle_action(players[0], charge_start, 1).accepted,
		"Authenticated charge starts a visual gesture",
	)
	check(
		protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 1,
			"stage": "progress",
			"step": 2,
		}, 2).accepted,
		"Coarse charge step reaches presentation",
	)
	check(
		visual_updates.back() == 0.5 and controller.personal_snapshot("p0").last_input_seq == -1,
		"Charge changes only presentation, never accepted gameplay sequence",
	)
	check(not protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 1,
			"stage": "progress",
			"step": 1,
		}, 3).accepted, "Out-of-order progress is rejected")
	check(not protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 1,
			"stage": "progress",
			"step": 5,
		}, 3).accepted, "Over-range progress is rejected")
	check(
		not protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 1,
			"stage": "progress",
			"step": 3,
			"player_id": "p1",
		}, 3).accepted,
		"Client-authored player identity is rejected",
	)
	check(
		not protocol.handle_action(players[1], {
			"type": "bubbles_charge",
			"input_seq": 1,
			"stage": "progress",
			"step": 3,
		}, 3).accepted,
		"Another authenticated player cannot advance the gesture",
	)
	var json_charge: Dictionary = JSON.parse_string(
		'{"type":"bubbles_charge","input_seq":1,"stage":"progress","step":3}'
	)
	check(
		protocol.handle_action(players[0], json_charge, 4).accepted,
		"JSON numeric charge step reaches the host",
	)
	var swipe := { "type": "bubbles_trace", "input_seq": 1, "trace": [[0.1, 0.5], [0.9, 0.5]] }
	check(
		protocol.handle_action(players[0], swipe, 1).accepted,
		"Authenticated swipe reaches controller",
	)
	check(visual_updates.back() == 0.0, "Completed trace clears charge cue")
	check(protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 2,
			"stage": "start",
			"step": 0,
		}, 6).accepted, "Next gesture may start")
	check(protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 2,
			"stage": "cancel",
			"step": 0,
		}, 7).accepted, "Canceled gesture clears visual cue")
	check(not protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 2,
			"stage": "progress",
			"step": 3,
		}, 8).accepted, "Canceled gesture cannot resume")
	check(
		not protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 2,
			"stage": "start",
			"step": 0,
		}, 9).accepted,
		"Canceled gesture sequence cannot restart",
	)
	check(
		protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 3,
			"stage": "start",
			"step": 0,
		}, 9).accepted,
		"A fresh gesture can start after cancel",
	)
	check(not protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 3,
			"stage": "progress",
			"step": 3,
		}, 2000).accepted, "Timed-out charge cannot resume")
	check(
		not protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 3,
			"stage": "start",
			"step": 0,
		}, 2001).accepted,
		"Timed-out gesture sequence cannot restart",
	)
	check(
		controller.personal_snapshot("p0").spin_until_msec == -1,
		"Charge and cancellation never activate spin",
	)
	check(
		controller.personal_snapshot("p0").last_input_seq == 1
		and controller.personal_snapshot("p1").last_input_seq == -1,
		"Action only mutates authenticated player",
	)
	check(not protocol.handle_action(players[0], swipe, 2).accepted, "Duplicate sequence rejected")
	var malformed: Array[Dictionary] = [
		{ "type": "bubbles_trace", "input_seq": -1, "trace": swipe.trace },
		{ "type": "bubbles_trace", "input_seq": 1.5, "trace": swipe.trace },
		{ "type": "bubbles_trace", "input_seq": INF, "trace": swipe.trace },
		{ "type": "bubbles_trace", "input_seq": "2", "trace": swipe.trace },
		{ "type": "bubbles_trace", "input_seq": 2, "trace": [[0.5, 0.5]] },
		{ "type": "bubbles_trace", "input_seq": 2, "trace": [[0.5, NAN], [0.6, 0.5]] },
		{ "type": "bubbles_trace", "input_seq": 2, "trace": [[0.5, 0.5], [1.1, 0.5]] },
		{
			"type": "bubbles_trace",
			"input_seq": 2,
			"trace": [[0.5, 0.5], [0.6, 0.5]],
			"player_id": "p1",
		},
		{
			"type": "bubbles_trace",
			"input_seq": 2,
			"trace": [[0.5, 0.5], [0.6, 0.5]],
			"host_time_msec": 999,
		},
		{ "type": "bubbles_trace", "input_seq": 2, "trace": _oversized_trace() },
	]
	for packet: Dictionary in malformed:
		check(
			not protocol.handle_action(players[0], packet, 3).accepted,
			"Malformed, oversized, or authority-shaped input rejected",
		)
	check(not protocol.handle_action({ }, {
			"type": "bubbles_trace",
			"input_seq": 2,
			"trace": swipe.trace,
		}, 3).accepted, "Unjoined connection cannot act")
	check(
		controller.personal_snapshot("p0").last_input_seq == 1,
		"Rejected packets do not advance accepted sequence",
	)
	var json_packet: Dictionary = JSON.parse_string(
		'{"type":"bubbles_trace","input_seq":2,"trace":[[0.1,0.5],[0.9,0.5]]}'
	)
	check(
		protocol.handle_action(players[1], json_packet, 4).accepted,
		"JSON browser packet is accepted for authenticated player",
	)
	check(
		controller.personal_snapshot("p1").last_input_seq == 2,
		"Second player's sequence remains independent",
	)
	var spin := protocol.handle_action(
		players[0],
		{ "type": "bubbles_trace", "input_seq": 4, "trace": _circle() },
		5,
	)
	var while_spinning := protocol.handle_action(
		players[0],
		{ "type": "bubbles_trace", "input_seq": 5, "trace": swipe.trace },
		5,
	)
	check(
		spin.accepted and spin.action == "spin"
		and while_spinning.accepted and while_spinning.action == "swipe",
		"Swipe remains available during host-approved spin",
	)
	var snapshot := protocol.snapshot_for("p0")
	check(
		snapshot.type == "bubbles_snapshot" and snapshot.score == 0
		and snapshot.visual_jellyfish == 0 and snapshot.seat == 1,
		"Personal snapshot contains exact score and visual state",
	)
	check(
		snapshot.character_shape == "squircle" and snapshot.character_color == "#EC407A",
		"Phone Bubbles snapshots keep the authenticated player's host-owned selection",
	)
	check(
		snapshot.host_time_msec >= 0
		and snapshot.visual_tuning.live_drag_pull_strength
		== controller.tuning.live_drag_pull_strength,
		"Phone receives the shared host clock and configured visual response",
	)
	check(not snapshot.debug_mode, "Normal Bubbles snapshots do not claim debug mode")
	check(
		protocol.snapshot_for("unknown").type == "lobby",
		"Unknown player receives no gameplay state",
	)
	controller.record_jellyfish_capture("p0", 5)
	var collected := protocol.feedback_for("p0", &"captured", { })
	check(
		collected.event == "captured" and collected.score == 1 and collected.visual_jellyfish == 1,
		"Collection feedback reflects host score",
	)
	controller.pop_player("p0", 6)
	var pop := protocol.feedback_for("p0", &"pop", { "lost": 1 })
	check(
		pop.score == 0 and pop.lost == 1 and pop.burst_radius == 50.0
		and pop.invulnerable_remaining_msec > 0 and pop.reform_remaining_msec > 0,
		"Pop feedback carries authoritative re-form and invulnerability state",
	)
	controller.advance(10000)
	var results := protocol.snapshot_for("p0")
	check(results.phase == "results" and results.rank > 0, "Result snapshot includes placement")
	var debug_controller := _controller()
	debug_controller.start_round([{ "player_id": "debug", "name": "Debug", "seat": 1 }], 0, true)
	var debug_snapshot: Dictionary = Protocol.new(debug_controller).snapshot_for("debug")
	check(
		debug_controller.is_one_player_debug() and debug_snapshot.debug_mode
		and debug_snapshot.character_shape == "squircle"
		and debug_snapshot.character_color == CharacterSelection.FALLBACK_COLOR,
		"One-player debug state reaches the phone with the Squircle fallback",
	)
	_test_timed_swipes()


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
	var players := [{ "player_id": "a", "seat": 1 }, { "player_id": "b", "seat": 2 }]
	controller.start_round(players, 0)
	controller.set_process(false)
	controller.complete_entrance(0)
	controller.advance(0)
	var protocol := Protocol.new(controller)
	var impulses: Array[StringName] = []
	var drags: Array[Vector2] = []
	controller.arena_event_requested.connect(
		func(kind: StringName, id: String, _data: Dictionary) -> void:
			if id == "a" and kind in [&"swipe", &"spin"]:
				impulses.append(kind),
	)
	controller.drag_visual_changed.connect(
		func(id: String, drag: Vector2, _gesture_started_msec: int) -> void:
			if id == "a":
				drags.append(drag),
	)
	var swipe := [[0.1, 0.5], [0.9, 0.5]]
	var limit := roundi(controller.tuning.swipe_max_hold_seconds * 1000.0)
	protocol.handle_action(
		players[0],
		{ "type": "bubbles_charge", "input_seq": 1, "stage": "start", "step": 0 },
		100,
	)
	var quick := protocol.handle_action(
		players[0],
		{ "type": "bubbles_trace", "input_seq": 1, "trace": swipe },
		100 + limit,
	)
	check(
		quick.action == "swipe" and impulses.size() == 1,
		"Swipe at the configured host-time limit applies impulse",
	)
	protocol.handle_action(
		players[0],
		{ "type": "bubbles_charge", "input_seq": 2, "stage": "start", "step": 0 },
		1000,
	)
	check(
		protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 2,
			"stage": "motion",
			"drag": [-4, 1],
		}, 1070).accepted,
		"Authenticated coarse drag updates visual cue while held",
	)
	check(
		drags.back() == Vector2(-1.0, 0.25) and impulses.size() == 1,
		"Live drag changes no gameplay state before release",
	)
	check(not protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 2,
			"stage": "motion",
			"drag": [-5, 0],
		}, 1080).accepted, "Out-of-range drag is rejected")
	check(
		not protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 2,
			"stage": "motion",
			"drag": [0.5, 0],
		}, 1080).accepted,
		"Fractional drag cell is rejected",
	)
	check(
		not protocol.handle_action(players[0], {
			"type": "bubbles_charge",
			"input_seq": 2,
			"stage": "motion",
			"drag": [1, 0],
			"player_id": "b",
		}, 1080).accepted,
		"Forged drag identity is rejected",
	)
	protocol.handle_action(
		players[0],
		{ "type": "bubbles_charge", "input_seq": 2, "stage": "motion", "drag": [-4, 1] },
		1000 + limit + 1,
	)
	check(drags.back() == Vector2.ZERO, "Held drag cue clears after the swipe activation limit")
	var slow := protocol.handle_action(
		players[0],
		{ "type": "bubbles_trace", "input_seq": 2, "trace": swipe },
		1000 + limit + 1,
	)
	check(
		slow.accepted and slow.action == "none"
		and slow.reason == "swipe_too_slow" and impulses.size() == 1,
		"Slow touch consumes its sequence without applying swipe impulse",
	)
	check(drags.back() == Vector2.ZERO, "Release clears live drag cue")
	protocol.handle_action(
		players[0],
		{ "type": "bubbles_charge", "input_seq": 3, "stage": "start", "step": 0 },
		2000,
	)
	var long_spin := protocol.handle_action(
		players[0],
		{ "type": "bubbles_trace", "input_seq": 3, "trace": _circle() },
		2000 + limit + 500,
	)
	check(
		long_spin.accepted and long_spin.action == "spin" and impulses.size() == 2,
		"Completed spin remains available after the swipe-only time limit",
	)
	protocol.handle_action(
		players[0],
		{ "type": "bubbles_charge", "input_seq": 4, "stage": "start", "step": 0 },
		5000,
	)
	var before_motion := drags.size()
	for index: int in Protocol.MAX_MOTION_UPDATES + 2:
		protocol.handle_action(
			players[0],
			{
				"type": "bubbles_charge",
				"input_seq": 4,
				"stage": "motion",
				"drag": [index % 5 - 2, 0],
			},
			5100 + index * 60,
		)
	check(
		drags.size() - before_motion == Protocol.MAX_MOTION_UPDATES and impulses.size() == 2,
		"Motion packet cap bounds visual work without changing gameplay",
	)
	protocol.handle_action(
		players[0],
		{ "type": "bubbles_charge", "input_seq": 4, "stage": "cancel", "step": 0 },
		8100,
	)
	check(
		not protocol.handle_action(players[0], {
			"type": "bubbles_trace",
			"input_seq": 4,
			"trace": _circle(),
		}, 8200).accepted and impulses.size() == 2,
		"Canceled gesture cannot later activate spin",
	)


func _controller() -> BubblesRoundController:
	var result := Controller.new() as BubblesRoundController
	root.add_child(result)
	result.tuning = BubblesTuning.new()
	return result
