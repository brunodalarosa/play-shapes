class_name Bubbles3DProtocol
extends MinigameProtocol
## The phone side of one Bubbles and jellyfishes 3D round. Phones send touches; the host measures
## their timing, validates every field and never trusts a client's identity or clock.
##
## Client messages:
## - bubbles_3d_touch: input_seq, stage start, drag or cancel, and for drag a coarse direction
##   of two integers from -4 to 4 in screen axes (X right, Y down), for the live stretch.
## - bubbles_3d_release: input_seq and the touch's net displacement as two numbers from -1 to 1,
##   a share of the touch area in screen axes.

const MAX_INPUT_SEQUENCE := 9_007_199_254_740_991
const MIN_DRAG_INTERVAL_MSEC := 60
const MAX_DRAG_UPDATES := 48
const DRAG_STEPS := 4.0
const TYPES: Array[String] = ["bubbles_3d_touch", "bubbles_3d_release"]

var controller: Bubbles3DRoundController
## Per player: the open touch's sequence, start time, last update and drag count.
var _touches: Dictionary[String, Dictionary] = { }
var _canceled_seq: Dictionary[String, int] = { }


func _init(round_controller: Bubbles3DRoundController) -> void:
	controller = round_controller
	controller.phase_changed.connect(_on_phase_changed)
	controller.personal_state_changed.connect(_on_personal_state_changed)
	controller.personal_visual_changed.connect(_on_personal_visual_changed)
	controller.feedback_requested.connect(_on_feedback)


func handles(message_type: String) -> bool:
	return message_type in TYPES


func handle_message(player: Dictionary, message: Dictionary, host_msec: int) -> Dictionary:
	if controller == null or not is_instance_valid(controller):
		return _reject(&"game_unavailable")
	if player.is_empty() or not player.has("player_id"):
		return _reject(&"not_joined")
	if host_msec < 0:
		return _reject(&"invalid_time")
	var sequence := _sequence(message.get("input_seq"))
	if sequence < 0:
		return _reject(&"invalid_sequence")
	var player_id := String(player.player_id)
	if message.get("type") == "bubbles_3d_touch":
		return _handle_touch(player_id, sequence, message, host_msec)
	return _handle_release(player_id, sequence, message, host_msec)


func _handle_touch(player_id: String, sequence: int, message: Dictionary, now: int) -> Dictionary:
	for key: Variant in message.keys():
		if key not in ["type", "input_seq", "stage", "drag"]:
			return _reject(&"unauthorized_field")
	var own := controller.personal_snapshot(player_id)
	if (
		own.is_empty() or own.phase != &"active" or not own.connected
		or own.left or sequence <= int(own.last_input_seq)
	):
		return _reject(&"stale_or_unavailable")
	var stage: Variant = message.get("stage")
	if typeof(stage) != TYPE_STRING or stage not in ["start", "drag", "cancel"]:
		return _reject(&"invalid_stage")
	if (stage == "drag") != message.has("drag"):
		return _reject(&"invalid_stage")
	# An open touch stays until its release, its cancel or a newer touch, so a long hold is
	# always timed from its real start. The bubble settles a stretch that stops updating.
	var touch: Dictionary = _touches.get(player_id, { })
	if stage == "start":
		if not touch.is_empty() and sequence <= int(touch.seq):
			return _reject(&"stale_touch")
		_touches[player_id] = { "seq": sequence, "start": now, "last": now, "drags": 0 }
		controller.drag_visual_changed.emit(player_id, Vector2.ZERO, now)
		return { "accepted": true }
	if touch.is_empty() or sequence != int(touch.seq):
		return _reject(&"stale_touch")
	if stage == "cancel":
		_end_touch(player_id)
		_canceled_seq[player_id] = sequence
		return { "accepted": true }
	var drag := _drag(message.drag)
	if not drag.is_finite():
		return _reject(&"invalid_drag")
	var too_soon := now - int(touch.last) < MIN_DRAG_INTERVAL_MSEC and int(touch.drags) > 0
	if int(touch.drags) >= MAX_DRAG_UPDATES or too_soon:
		return { "accepted": true }
	touch.drags = int(touch.drags) + 1
	touch.last = now
	controller.drag_visual_changed.emit(player_id, drag, int(touch.start))
	return { "accepted": true }


func _handle_release(player_id: String, sequence: int, message: Dictionary, now: int) -> Dictionary:
	for key: Variant in message.keys():
		if key not in ["type", "input_seq", "displacement"]:
			return _reject(&"unauthorized_field")
	var raw: Variant = message.get("displacement")
	if not raw is Array or raw.size() != 2:
		return _reject(&"invalid_displacement")
	for coordinate: Variant in raw:
		if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)):
			return _reject(&"invalid_displacement")
	if sequence == _canceled_seq.get(player_id, -1):
		return _reject(&"canceled_touch")
	var touch: Dictionary = _touches.get(player_id, { })
	var started := int(touch.start) if not touch.is_empty() and int(touch.seq) == sequence else -1
	# Screen Y points down; the plane's Y points up.
	var displacement := Vector2(float(raw[0]), -float(raw[1]))
	var result := controller.submit_swipe(player_id, sequence, displacement, now, started)
	if started >= 0:
		_end_touch(player_id)
	if not result.accepted:
		return _reject(StringName(result.code))
	return {
		"accepted": true,
		"snapshot": true,
		"reply": {
			"type": "bubbles_3d_release_result",
			"action": str(result.action),
			"reason": str(result.get("reason", "")),
		},
	}


func snapshot_for(player_id: String) -> Dictionary:
	if controller == null or not is_instance_valid(controller):
		return super(player_id)
	var own := controller.personal_snapshot(player_id)
	if own.is_empty():
		return super(player_id)
	var tuning := controller.tuning
	var now := int(own.host_time_msec)
	var reform_end := int(own.last_pop_msec) + roundi(tuning.bubble_reform_seconds * 1000.0)
	return {
		"type": "bubbles_3d_snapshot",
		"phase": str(own.phase),
		"debug_mode": controller.is_one_player_debug(),
		"character_shape": String(own.character_shape),
		"character_color": String(own.character_color),
		"score": int(own.score),
		"bubble_radius": float(own.bubble_radius),
		"visual_jellyfish": int(own.visual_jellyfish),
		"seat": int(own.seat),
		"connected": bool(own.connected),
		"left": bool(own.left),
		"host_time_msec": now,
		"invulnerable_remaining_msec": maxi(0, int(own.invulnerable_until_msec) - now),
		"reform_remaining_msec": maxi(0, reform_end - now) if int(own.last_pop_msec) >= 0 else 0,
		"rank": _rank_for(player_id) if own.phase == &"results" else 0,
		"visual_tuning": {
			"starting_radius": tuning.starting_radius,
			"max_radius": tuning.max_radius,
			"visual_cap": tuning.captured_visual_cap,
			"caught_width": tuning.jellyfish_collider_radius * 4.0
			* Bubbles3DPlayerBubble.CAUGHT_WIDTH_SHARE,
			"character_height_per_radius": tuning.character_height_per_radius,
			"character_max_height": tuning.character_max_height,
			"character_bob": tuning.character_bob,
			"character_lean_degrees": tuning.character_lean_degrees,
			"live_drag_pull_strength": tuning.live_drag_pull_strength,
			"live_drag_response_seconds": tuning.live_drag_response_seconds,
			"swipe_max_hold_seconds": tuning.swipe_max_hold_seconds,
			"bubble_reform_seconds": tuning.bubble_reform_seconds,
			"burst_seconds": tuning.burst_seconds,
		},
	}


func detach() -> void:
	if controller == null or not is_instance_valid(controller):
		return
	for connection: Array in [
		[controller.phase_changed, _on_phase_changed],
		[controller.personal_state_changed, _on_personal_state_changed],
		[controller.personal_visual_changed, _on_personal_visual_changed],
		[controller.feedback_requested, _on_feedback],
	]:
		var source: Signal = connection[0]
		if source.is_connected(connection[1]):
			source.disconnect(connection[1])


func _on_phase_changed(_phase: StringName, _snapshot: Dictionary) -> void:
	broadcast_requested.emit()


func _on_personal_state_changed(player_id: String, _snapshot: Dictionary) -> void:
	send_requested.emit(player_id, snapshot_for(player_id), false)


func _on_personal_visual_changed(player_id: String, visual: Dictionary) -> void:
	send_requested.emit(player_id, { "type": "bubbles_3d_visual", "visual": visual }, true)


func _on_feedback(player_id: String, kind: StringName, data: Dictionary) -> void:
	var message := snapshot_for(player_id)
	message.type = "bubbles_3d_feedback"
	message.event = str(kind)
	if kind == &"pop":
		message.lost = int(data.get("lost", 0))
	send_requested.emit(player_id, message, false)


func _end_touch(player_id: String) -> void:
	if _touches.erase(player_id):
		controller.drag_visual_changed.emit(player_id, Vector2.ZERO, -1)


func _rank_for(player_id: String) -> int:
	var by_player: Dictionary = controller.result_snapshot().get("by_player_id", { })
	return int(by_player.get(player_id, { }).get("rank", 0))


## A coarse drag in screen axes, as a plane direction; non-finite when malformed.
static func _drag(raw: Variant) -> Vector2:
	if not raw is Array or raw.size() != 2:
		return Vector2(NAN, NAN)
	var steps := Vector2.ZERO
	for index: int in 2:
		var value: Variant = raw[index]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			return Vector2(NAN, NAN)
		var number := float(value)
		if not is_finite(number) or floorf(number) != number or absf(number) > DRAG_STEPS:
			return Vector2(NAN, NAN)
		steps[index] = number
	return Vector2(steps.x, -steps.y) / DRAG_STEPS


## A whole, non-negative sequence number, or -1.
static func _sequence(raw: Variant) -> int:
	if typeof(raw) not in [TYPE_INT, TYPE_FLOAT]:
		return -1
	var number := float(raw)
	if (
		not is_finite(number) or number < 0.0
		or number > float(MAX_INPUT_SEQUENCE) or floorf(number) != number
	):
		return -1
	return int(number)


func _reject(code: StringName) -> Dictionary:
	var text := "Bubbles 3D input rejected: %s" % str(code)
	return { "accepted": false, "code": code, "message": text }
