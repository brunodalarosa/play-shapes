extends SceneTree

const Controller = preload("res://minigames/flash_pose_round_controller.gd")
const Protocol = preload("res://host/flash_pose_protocol.gd")

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_valid_ordered_actions_and_malformed_packets()
	_test_snapshots_elimination_and_ten_players()
	if _failures == 0:
		print("[AUTO] Flash Pose protocol checks passed")
	quit(0 if _failures == 0 else 1)

func _test_valid_ordered_actions_and_malformed_packets() -> void:
	var controller := _controller()
	controller.inject_sequences([&"bounce"], [&"left"], [100])
	controller.start_round(_participants(2), 0)
	var protocol := Protocol.new(controller)
	var player: Dictionary = _participants(2)[0]
	_check(protocol.handle_action(player, {"type": "pose_down", "direction": "left", "input_seq": 1}, 0).accepted,
		"Phone posing is active from the minigame countdown")
	controller.advance(0)
	_check(not protocol.handle_action(player, {"type": "pose_down", "direction": "left", "input_seq": 1}, 1).accepted,
		"A duplicate sequence is rejected")
	_check(protocol.handle_action(player, {"type": "pose_up", "direction": "left", "input_seq": 2}, 2).accepted,
		"A matching release works while music is playing")
	controller.advance(100)
	for malformed: Dictionary in [
		{"type": "pose_down", "direction": "spin", "input_seq": 3},
		{"type": "pose_down", "direction": "left", "input_seq": -1},
		{"type": "pose_down", "direction": "left", "input_seq": 3.5},
		{"type": "pose_down", "direction": "left", "input_seq": "3"},
		{"type": "pose_down", "direction": "left", "input_seq": 3, "player_id": "p2"},
		{"type": "pose_down", "direction": "left", "input_seq": 3, "timestamp": 999999},
	]:
		_check(not protocol.handle_action(player, malformed, 3).accepted,
			"Malformed or authority-shaped pose input is rejected")
	var semantic: Dictionary = controller._pose_rules.semantic_state("p1")
	_check(not semantic.held and semantic.latest_input_seq == 2,
		"Rejected input does not mutate held state or accepted sequence")
	var browser_packet: Dictionary = JSON.parse_string(
		'{"type":"pose_down","direction":"left","input_seq":3}')
	_check(protocol.handle_action(player, browser_packet, 101).accepted,
		"A JSON-decoded browser sequence is normalized and accepted")
	semantic = controller._pose_rules.semantic_state("p1")
	_check(semantic.held and semantic.latest_input_seq == 3,
		"Normalized browser input reaches the authoritative pose rules")
	var deadline: int = controller._pose_rules.current_deadline_msec()
	controller.advance(deadline)
	var lives_before: int = controller._players.p1.lives
	_check(protocol.handle_action(player, {"type": "pose_down", "direction": "left", "input_seq": 4}, deadline + 1).accepted,
		"Post-resolution input resumes free posing")
	_check(controller._players.p1.lives == lives_before,
		"Post-resolution posing cannot mutate the resolved challenge")

func _test_snapshots_elimination_and_ten_players() -> void:
	var controller := _controller()
	controller.tuning.pose_grace_seconds = 0.01
	controller.inject_sequences([&"disco"], [&"right", &"right"], [0, 0])
	var participants := _participants(10)
	_check(controller.start_round(participants, 0).accepted, "Ten registered players can enter one round snapshot")
	var protocol := Protocol.new(controller)
	controller.advance(0)
	controller.advance(0)
	var snapshot: Dictionary = protocol.snapshot_for("p10")
	_check(snapshot.type == "flash_pose_snapshot" and snapshot.phase == "genuine_stop_grace" \
		and snapshot.available_directions == ["left", "right"] and snapshot.player.lives == 2,
		"Reconnect snapshot is personalized and exposes only current phone state")
	_check(snapshot.player.character_shape == "circle" and snapshot.player.character_color == "#8D6E63",
		"Phone reconnect snapshots retain the host-owned selected appearance")
	_check(snapshot.presentation.colors.left == "#48d16f" \
		and snapshot.presentation.minimum_brightness == 0.42 \
		and snapshot.presentation.charge_fill_seconds == controller.tuning.charge_fill_seconds,
		"Host snapshot owns phone colors, brightness, and charge timing")
	var charge_update: Dictionary = protocol.charge_update_for("p10", {
		"pose_direction": &"left", "pose_charge": 0.75, "pose_held": true,
	})
	_check(charge_update.type == "flash_pose_charge" and charge_update.direction == "left" \
		and charge_update.charge == 0.75 and charge_update.held,
		"Personalized semantic charge update contains no gameplay outcome authority")
	controller.advance(10)
	controller.acknowledge_flash(1, 10)
	controller.advance(10)
	controller.advance(20)
	var eliminated_message := protocol.result_for("p10", 2, [{
		"player_id": "p10", "success": false, "lives": 0, "eliminated": true,
	}])
	_check(eliminated_message.message == "You've been eliminated :(" and eliminated_message.lives == 0,
		"Elimination uses the exact player-facing copy")
	_check(protocol.snapshot_for("unknown").type == "lobby",
		"A player outside the round remains lobby-only")

	var debug_controller := _controller()
	debug_controller.start_round([_participants(1)[0]], 0, true)
	var debug_protocol := Protocol.new(debug_controller)
	var debug_snapshot: Dictionary = debug_protocol.snapshot_for("p1")
	var debug_result: Dictionary = debug_protocol.result_for("p1", 1, [{
		"player_id": "p1", "success": false, "lives": 2, "eliminated": false,
	}])
	_check(debug_snapshot.debug_mode and debug_protocol.challenge_message().debug_mode,
		"One-player debug state is explicit in snapshots and challenges")
	_check(debug_result.debug_mode and debug_result.lives == 2 \
		and debug_result.message == "Missed it — debug mode continues",
		"Debug results expose infinite-life behavior without false life-loss copy")

func _controller() -> Node:
	var controller := Controller.new()
	var tuning := SimonSaysTuning.new()
	tuning.countdown_seconds = 0.0
	tuning.round_duration_seconds = 10.0
	controller.tuning = tuning
	root.add_child(controller)
	return controller

func _participants(count: int) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	var shapes: Array[String] = ["square", "circle", "squircle", "rhombus"]
	var colors: Array[String] = ["#E53935", "#F57C00", "#FBC02D", "#43A047", "#00ACC1", "#1E88E5", "#3949AB", "#8E24AA", "#EC407A", "#8D6E63"]
	for index: int in count:
		players.append({"player_id": "p%d" % (index + 1), "name": "Player %d" % (index + 1), "seat": index + 1,
			"state": "connected", "character_shape": shapes[index % shapes.size()], "character_color": colors[index % colors.size()]})
	return players

func _check(condition: bool, description: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(description)
