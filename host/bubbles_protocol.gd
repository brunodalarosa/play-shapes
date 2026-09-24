class_name BubblesProtocol
extends RefCounted
## Authenticated transport adapter for one Bubbles round. Never trusts client identity or time.

const MAX_INPUT_SEQUENCE := 9007199254740991
const MAX_TRACE_POINTS := 128
const CHARGE_TIMEOUT_MSEC := 1200
const CHARGE_STEPS := 4

var controller: BubblesRoundController
var _charges: Dictionary = {}
var _last_charge_seq: Dictionary = {}


func _init(round_controller: BubblesRoundController = null) -> void:
	controller = round_controller


func handle_action(player: Dictionary, message: Dictionary, host_receipt_msec: int) -> Dictionary:
	if controller == null or not is_instance_valid(controller):
		return _reject(&"game_unavailable")
	if player.is_empty() or not player.has("player_id"):
		return _reject(&"not_joined")
	if message.get("type") == "bubbles_charge":
		return _handle_charge(String(player.player_id), message, host_receipt_msec)
	if message.get("type") != "bubbles_trace":
		return _reject(&"unsupported_message")
	for key: Variant in message.keys():
		if key not in ["type", "input_seq", "trace"]:
			return _reject(&"unauthorized_field")
	var raw_seq: Variant = message.get("input_seq")
	if typeof(raw_seq) not in [TYPE_INT, TYPE_FLOAT]:
		return _reject(&"invalid_sequence")
	var sequence := float(raw_seq)
	if not is_finite(sequence) or sequence < 0.0 or sequence > float(MAX_INPUT_SEQUENCE) or floorf(sequence) != sequence:
		return _reject(&"invalid_sequence")
	var trace: Variant = message.get("trace")
	if not trace is Array or trace.size() < 2 or trace.size() > MAX_TRACE_POINTS:
		return _reject(&"invalid_trace")
	for raw: Variant in trace:
		if not raw is Array or raw.size() != 2:
			return _reject(&"invalid_trace")
		for coordinate: Variant in raw:
			if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)) or float(coordinate) < 0.0 or float(coordinate) > 1.0:
				return _reject(&"invalid_trace")
	var result := controller.submit_trace(String(player.player_id), int(sequence), trace, host_receipt_msec)
	# Let the accepted spin event sample the held visual tension before clearing it.
	_clear_charge(String(player.player_id), int(sequence))
	if not result.accepted:
		return _reject(StringName(result.code))
	return {"accepted": true, "action": str(result.action), "reason": str(result.get("reason", ""))}


## A coarse, authenticated visual cue. Only completed traces reach gameplay rules.
func _handle_charge(player_id: String, message: Dictionary, now: int) -> Dictionary:
	if now < 0:
		return _reject(&"invalid_time")
	for key: Variant in message.keys():
		if key not in ["type", "input_seq", "stage", "step"]:
			return _reject(&"unauthorized_field")
	var raw_seq: Variant = message.get("input_seq")
	if typeof(raw_seq) not in [TYPE_INT, TYPE_FLOAT]:
		return _reject(&"invalid_sequence")
	var number := float(raw_seq)
	if not is_finite(number) or number < 0.0 or number > float(MAX_INPUT_SEQUENCE) or floorf(number) != number:
		return _reject(&"invalid_sequence")
	var seq := int(number)
	var own := controller.personal_snapshot(player_id)
	if own.is_empty() or own.phase != &"active" or not own.connected or own.left or seq <= int(own.last_input_seq):
		return _reject(&"stale_or_unavailable")
	var stage: Variant = message.get("stage")
	var raw_step: Variant = message.get("step")
	if typeof(raw_step) not in [TYPE_INT, TYPE_FLOAT]:
		return _reject(&"invalid_charge")
	var step_number := float(raw_step)
	if typeof(stage) != TYPE_STRING or stage not in ["start", "progress", "cancel"] or not is_finite(step_number) or step_number < 0.0 or step_number > float(CHARGE_STEPS) or floorf(step_number) != step_number:
		return _reject(&"invalid_charge")
	var step := int(step_number)
	var prior: Dictionary = _charges.get(player_id, {})
	if not prior.is_empty() and now < int(prior.time):
		return _reject(&"stale_charge")
	if not prior.is_empty() and now - int(prior.time) > CHARGE_TIMEOUT_MSEC:
		_clear_charge(player_id, int(prior.seq))
		prior = {}
	if stage == "start":
		if step != 0 or seq <= int(_last_charge_seq.get(player_id, -1)):
			return _reject(&"stale_charge")
		_last_charge_seq[player_id] = seq
		_charges[player_id] = {"seq": seq, "step": 0, "time": now}
		controller.charge_visual_changed.emit(player_id, 0.12)
	elif prior.is_empty() or seq != int(prior.seq):
		return _reject(&"stale_charge")
	elif stage == "cancel":
		if step != 0:
			return _reject(&"invalid_charge")
		_clear_charge(player_id, seq)
	elif step <= int(prior.step):
		return _reject(&"stale_charge")
	else:
		_charges[player_id] = {"seq": seq, "step": step, "time": now}
		controller.charge_visual_changed.emit(player_id, float(step) / float(CHARGE_STEPS))
	return {"accepted": true}


func _clear_charge(player_id: String, through_seq: int) -> void:
	var prior: Dictionary = _charges.get(player_id, {})
	if not prior.is_empty() and int(prior.seq) <= through_seq:
		_charges.erase(player_id)
		controller.charge_visual_changed.emit(player_id, 0.0)


func snapshot_for(player_id: String) -> Dictionary:
	if controller == null or not is_instance_valid(controller):
		return {"type": "lobby", "state": "waiting", "message": "Waiting for the next game"}
	var own := controller.personal_snapshot(player_id)
	if own.is_empty():
		return {"type": "lobby", "state": "waiting", "message": "Waiting for the next game"}
	var now := int(own.host_time_msec)
	return {
		"type": "bubbles_snapshot", "phase": str(own.phase),
		"debug_mode": controller.is_one_player_debug(),
		"score": int(own.score), "bubble_radius": float(own.bubble_radius),
		"visual_jellyfish": int(own.visual_jellyfish), "visual_cap": controller.tuning.captured_visual_cap,
		"seat": int(own.seat), "connected": bool(own.connected), "left": bool(own.left),
		"spin_remaining_msec": maxi(0, int(own.spin_until_msec) - now),
		"cooldown_remaining_msec": maxi(0, int(own.spin_ready_msec) - now),
		"invulnerable_remaining_msec": maxi(0, int(own.invulnerable_until_msec) - now),
		"reform_remaining_msec": maxi(0, int(own.last_pop_msec) + roundi(controller.tuning.bubble_reform_seconds * 1000.0) - now) if int(own.last_pop_msec) >= 0 else 0,
		"spin_duration_msec": roundi(controller.tuning.spin_duration_seconds * 1000.0),
		"cooldown_duration_msec": roundi(controller.tuning.spin_cooldown_seconds * 1000.0),
		"circles_to_charge": controller.tuning.circles_to_charge,
		"rank": _rank_for(player_id) if own.phase == &"results" else 0,
	}


func feedback_for(player_id: String, kind: StringName, data: Dictionary) -> Dictionary:
	if controller.personal_snapshot(player_id).is_empty():
		return {}
	var result := snapshot_for(player_id)
	result.type = "bubbles_feedback"
	result.event = str(kind)
	if kind == &"pop":
		result.lost = int(data.get("lost", 0))
	return result


func _rank_for(player_id: String) -> int:
	var entry: Dictionary = controller.result_snapshot().get("by_player_id", {}).get(player_id, {})
	return int(entry.get("rank", 0))


func _reject(code: StringName) -> Dictionary:
	return {"accepted": false, "code": code, "message": "Bubbles input rejected: %s" % str(code)}
