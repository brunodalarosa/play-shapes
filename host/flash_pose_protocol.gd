class_name FlashPoseProtocol
extends RefCounted
## Narrow protocol boundary between one registered transport peer and the
## scene-scoped authoritative round controller.

const INPUT_TYPES := [&"pose_down", &"pose_up"]
const DIRECTIONS := [&"left", &"right", &"down", &"up"]
const MAX_INPUT_SEQUENCE := 9007199254740991 # JavaScript's largest exact integer.

var controller: FlashPoseRoundController

func _init(round_controller: FlashPoseRoundController = null) -> void:
	controller = round_controller

func handle_action(player: Dictionary, message: Dictionary, host_receipt_msec: int) -> Dictionary:
	if controller == null or not is_instance_valid(controller):
		return _rejected(&"game_unavailable", "Flash? Pose! is not active")
	if player.is_empty():
		return _rejected(&"not_joined", "Join before sending pose input")
	var message_type := StringName(message.get("type", ""))
	if message_type not in INPUT_TYPES:
		return _rejected(&"unsupported_message", "That action is not supported")
	# Reject rather than ignore authority-shaped fields so accidental client
	# trust cannot silently enter this boundary later.
	for key: Variant in message.keys():
		if key not in ["type", "direction", "input_seq"]:
			return _rejected(&"unauthorized_field", "Pose input contains a host-owned field")
	var raw_direction: Variant = message.get("direction")
	var raw_sequence: Variant = message.get("input_seq")
	if not raw_direction is String or StringName(raw_direction) not in DIRECTIONS:
		return _rejected(&"invalid_direction", "Choose an available pose direction")
	# Godot's JSON decoder may represent a browser-authored JSON integer as a
	# float. Accept only finite, whole, non-negative values within JS's exact
	# integer range, then normalize before reaching the authoritative rules.
	var input_sequence := -1
	if raw_sequence is int and raw_sequence >= 0 and raw_sequence <= MAX_INPUT_SEQUENCE:
		input_sequence = int(raw_sequence)
	elif raw_sequence is float and is_finite(raw_sequence) \
			and raw_sequence >= 0.0 and raw_sequence <= float(MAX_INPUT_SEQUENCE) \
			and raw_sequence == floor(raw_sequence):
		input_sequence = int(raw_sequence)
	if input_sequence < 0:
		return _rejected(&"invalid_sequence", "Pose input needs a non-negative sequence")
	var result := controller.submit_pose_input(
		String(player.player_id), StringName(raw_direction), message_type == &"pose_down",
		input_sequence, host_receipt_msec)
	if result.accepted:
		return {"accepted": true}
	return _rejected(StringName(result.code), _message_for_code(StringName(result.code)))

func snapshot_for(player_id: String) -> Dictionary:
	if controller == null or not is_instance_valid(controller):
		return {"type": "lobby", "state": "waiting", "message": "Waiting for the next game"}
	var own_state := _player_state(player_id)
	if own_state.is_empty():
		return {"type": "lobby", "state": "waiting", "message": "Waiting for the next game"}
	return {
		"type": "flash_pose_snapshot",
		"debug_mode": controller.is_one_player_debug(),
		"phase": str(controller.phase_name()),
		"style": str(controller.style),
		"stop_id": controller.current_stop_id,
		"available_directions": Array(controller.available_directions()).map(func(value: StringName) -> String: return str(value)),
		"player": _public_gameplay_state(own_state),
		"presentation": _presentation_tuning(),
	}

func challenge_message() -> Dictionary:
	return {
		"type": "flash_pose_challenge",
		"debug_mode": controller.is_one_player_debug(),
		"stop_id": controller.current_stop_id,
		"available_directions": Array(controller.available_directions()).map(func(value: StringName) -> String: return str(value)),
		"presentation": _presentation_tuning(),
		"message": "Music stopped! Hold your pose",
	}

func charge_update_for(player_id: String, semantic: Dictionary) -> Dictionary:
	if _player_state(player_id).is_empty():
		return {}
	return {
		"type": "flash_pose_charge",
		"direction": str(semantic.get("pose_direction", &"")),
		"charge": clampf(float(semantic.get("pose_charge", 0.0)), 0.0, 1.0),
		"held": bool(semantic.get("pose_held", false)),
	}

func result_for(player_id: String, stop_id: int, results: Array[Dictionary]) -> Dictionary:
	for result: Dictionary in results:
		if String(result.get("player_id", "")) == player_id:
			var eliminated := bool(result.get("eliminated", false))
			return {
				"type": "flash_pose_result", "stop_id": stop_id,
				"debug_mode": controller.is_one_player_debug(),
				"success": bool(result.get("success", false)),
				"lives": int(result.get("lives", 0)), "eliminated": eliminated,
				"message": "You've been eliminated :(" if eliminated else ("Pose locked!" if result.get("success", false) else ("Missed it — debug mode continues" if controller.is_one_player_debug() else "Missed it — one life lost")),
			}
	return {}

func results_message(player_id: String, results: Dictionary) -> Dictionary:
	var placement := 0
	for entry: Dictionary in results.get("ranking", []):
		if String(entry.get("player_id", "")) == player_id:
			placement = int(entry.get("placement", 0))
			break
	return {"type": "flash_pose_results", "debug_mode": controller.is_one_player_debug(),
		"placement": placement, "message": "Round complete"}

func _player_state(player_id: String) -> Dictionary:
	for state: Dictionary in controller.player_snapshot():
		if String(state.get("player_id", "")) == player_id:
			return state
	return {}

func _public_gameplay_state(state: Dictionary) -> Dictionary:
	return {
		"lives": int(state.get("lives", 0)),
		"eliminated": StringName(state.get("state", &"")) == &"eliminated",
		"direction": str(state.get("pose_direction", &"")),
		"charge": clampf(float(state.get("pose_charge", 0.0)), 0.0, 1.0),
		"held": bool(state.get("pose_held", false)),
	}

func _presentation_tuning() -> Dictionary:
	var tuning: SimonSaysTuning = controller.tuning
	return {
		"colors": {
			"left": "#" + tuning.controller_left_color.to_html(false),
			"right": "#" + tuning.controller_right_color.to_html(false),
			"down": "#" + tuning.controller_down_color.to_html(false),
			"up": "#" + tuning.controller_up_color.to_html(false),
		},
		"minimum_brightness": tuning.controller_minimum_brightness,
		"maximum_brightness": tuning.controller_maximum_brightness,
		"charge_fill_seconds": tuning.charge_fill_seconds,
		"charge_decay_seconds": tuning.charge_decay_seconds,
	}

func _message_for_code(code: StringName) -> String:
	match code:
		&"wrong_phase": return "Pose input is closed"
		&"locked_direction": return "That pose is not available yet"
		&"duplicate_sequence", &"out_of_order_sequence": return "That pose input was already handled"
		&"late_input": return "That pose arrived after the host deadline"
		_: return "The host rejected that pose input"

func _rejected(code: StringName, message: String) -> Dictionary:
	return {"accepted": false, "code": code, "message": message}
