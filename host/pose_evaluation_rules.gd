class_name PoseEvaluationRules
extends RefCounted
## Host-owned pose input and evaluation state. Browser packets and animation frames
## never enter this object; callers provide validated player IDs and host receipt time.

signal semantic_state_changed(player_id: String, state: Dictionary)
signal evaluation_resolved(stop_id: int, results: Array[Dictionary])
signal elimination_recorded(record: Dictionary)

const DIRECTIONS: Array[StringName] = [&"up", &"left", &"right", &"down"]

class PlayerPoseState extends RefCounted:
	var player_id: String
	var charge := PoseCharge.new()
	var latest_input_seq: int = -1
	var latest_input_received_msec: int = -1
	var connected := true
	var withdrawn := false
	var eliminated := false
	var reaction: StringName = &"none"

	func _init(id: String, fill_seconds: float, decay_seconds: float) -> void:
		player_id = id
		charge.fill_seconds = fill_seconds
		charge.decay_seconds = decay_seconds


var _tuning: SimonSaysTuning
var _players: Dictionary = {}
var _last_advanced_msec: int = -1
var _active_stop_id: int = -1
var _target_direction: StringName = &""
var _stop_started_msec: int = -1
var _pose_revealed_msec: int = -1
var _evaluation_deadline_msec: int = -1
var _stop_resolved := true
var _resolved_results: Array[Dictionary] = []


func _init(tuning: SimonSaysTuning = null) -> void:
	_tuning = tuning if tuning != null else SimonSaysTuning.new()


func add_player(player_id: String, host_time_msec: int = 0) -> bool:
	if player_id.is_empty() or _players.has(player_id) or not _stop_resolved \
			or not _accept_host_time(host_time_msec):
		return false
	_advance_to(host_time_msec)
	_players[player_id] = PlayerPoseState.new(
		player_id, _tuning.charge_fill_seconds, _tuning.charge_decay_seconds)
	_emit_semantic_state(player_id)
	return true


## Opens one genuine-stop window. Existing held charge is intentionally preserved.
func begin_stop(stop_id: int, target_direction: StringName, host_time_msec: int) -> Dictionary:
	if target_direction not in DIRECTIONS:
		return _rejected(&"invalid_direction")
	if stop_id <= _active_stop_id:
		return _rejected(&"stale_stop")
	if not _stop_resolved:
		return _rejected(&"stop_in_progress")
	if not _accept_host_time(host_time_msec):
		return _rejected(&"non_monotonic_host_time")
	_advance_to(host_time_msec)
	_active_stop_id = stop_id
	_target_direction = target_direction
	_stop_started_msec = host_time_msec
	_pose_revealed_msec = host_time_msec + roundi(_tuning.pose_reveal_delay_seconds * 1000.0)
	_evaluation_deadline_msec = _pose_revealed_msec + roundi(_tuning.pose_grace_seconds * 1000.0)
	_stop_resolved = false
	_resolved_results.clear()
	for player: PlayerPoseState in _players.values():
		player.reaction = &"none"
		_emit_semantic_state(player.player_id)
	return {
		"accepted": true,
		"stop_id": stop_id,
		"target_direction": target_direction,
		"stop_started_msec": _stop_started_msec,
		"pose_revealed_msec": _pose_revealed_msec,
		"evaluation_deadline_msec": _evaluation_deadline_msec,
	}


## Applies a press or release after the protocol layer has authenticated the player.
## input_seq is client-provided only for ordering; timing always uses host_receipt_msec.
func submit_input(player_id: String, requested_direction: StringName, held: bool,
		input_seq: int, host_receipt_msec: int) -> Dictionary:
	# Free posing is part of play throughout the round. Only an unresolved stop
	# adds a deadline; outside that window input still drives semantic animation
	# and prepares whatever uninterrupted pose reaches the next genuine stop.
	if not _stop_resolved and host_receipt_msec > _evaluation_deadline_msec:
		return _rejected(&"late_input")
	if not _accept_host_time(host_receipt_msec):
		return _rejected(&"non_monotonic_host_time")
	var player := _players.get(player_id) as PlayerPoseState
	if player == null or player.withdrawn or player.eliminated:
		return _rejected(&"inactive_player")
	if not player.connected:
		return _rejected(&"disconnected_player")
	if input_seq < 0 or input_seq <= player.latest_input_seq:
		return _rejected(&"stale_input")
	if requested_direction not in DIRECTIONS:
		return _rejected(&"invalid_direction")
	if not held and (not player.charge.held or requested_direction != player.charge.direction):
		return _rejected(&"mismatched_release")

	_advance_to(host_receipt_msec)
	player.charge.advance(0.0, requested_direction if held else &"")
	player.latest_input_seq = input_seq
	player.latest_input_received_msec = host_receipt_msec
	_emit_semantic_state(player_id)
	return {"accepted": true, "state": semantic_state(player_id)}


## Clears a held input immediately. Reconnect does not restore it; a new press is required.
func set_player_connected(player_id: String, connected: bool, host_time_msec: int) -> bool:
	if (not _stop_resolved and host_time_msec > _evaluation_deadline_msec) \
			or not _accept_host_time(host_time_msec):
		return false
	var player := _players.get(player_id) as PlayerPoseState
	if player == null or player.withdrawn:
		return false
	_advance_to(host_time_msec)
	player.connected = connected
	if not connected:
		player.charge.advance(0.0, &"")
	_emit_semantic_state(player_id)
	return true


## Explicit Leave is a withdrawal, not a pose failure or elimination.
func withdraw_player(player_id: String, host_time_msec: int) -> bool:
	if (not _stop_resolved and host_time_msec > _evaluation_deadline_msec) \
			or not _accept_host_time(host_time_msec):
		return false
	var player := _players.get(player_id) as PlayerPoseState
	if player == null:
		return false
	_advance_to(host_time_msec)
	player.withdrawn = true
	player.connected = false
	player.charge.reset()
	player.reaction = &"none"
	_emit_semantic_state(player_id)
	return true


## Resolves against the exact deadline even if the caller runs a later process frame.
func evaluate_stop(stop_id: int, host_time_msec: int) -> Dictionary:
	if stop_id != _active_stop_id:
		return _rejected(&"unknown_stop")
	if _stop_resolved:
		return {"accepted": true, "already_resolved": true, "results": _resolved_results.duplicate(true)}
	if host_time_msec < _evaluation_deadline_msec:
		return _rejected(&"evaluation_not_due")
	if not _accept_host_time(host_time_msec):
		return _rejected(&"non_monotonic_host_time")

	_advance_to(_evaluation_deadline_msec)
	for player: PlayerPoseState in _players.values():
		if player.withdrawn or player.eliminated:
			continue
		var success := player.connected \
			and player.charge.direction == _target_direction \
			and player.charge.is_committed()
		var result := {
			"stop_id": _active_stop_id,
			"player_id": player.player_id,
			"success": success,
			"reason": _result_reason(player, success),
			"target_direction": _target_direction,
			"direction": player.charge.direction,
			"charge": player.charge.charge,
			"held": player.charge.held,
			"evaluated_at_msec": _evaluation_deadline_msec,
			"latest_input_seq": player.latest_input_seq,
			"latest_input_received_msec": player.latest_input_received_msec,
		}
		_resolved_results.append(result)
		player.reaction = &"survived" if success else &"life_loss"
		_emit_semantic_state(player.player_id)
	_stop_resolved = true
	evaluation_resolved.emit(_active_stop_id, _resolved_results.duplicate(true))
	# The snapshot above is fixed at the deadline. Semantic charge may continue to
	# evolve until the caller's current frame without changing that result.
	_advance_to(host_time_msec)
	return {"accepted": true, "already_resolved": false, "results": _resolved_results.duplicate(true)}


## The later round controller decides when lives reach zero, then records that
## authoritative decision here for animation and the future phone adapter.
func mark_eliminated(player_id: String, stop_id: int, host_time_msec: int) -> Dictionary:
	var player := _players.get(player_id) as PlayerPoseState
	if player == null or player.withdrawn or player.eliminated:
		return _rejected(&"inactive_player")
	if not _stop_resolved or stop_id != _active_stop_id or not _accept_host_time(host_time_msec):
		return _rejected(&"invalid_elimination")
	var result := _result_for_player(player_id)
	if result.is_empty() or result.success:
		return _rejected(&"player_did_not_fail")
	player.eliminated = true
	player.reaction = &"none"
	player.charge.reset()
	var record := {
		"player_id": player_id,
		"stop_id": stop_id,
		"eliminated": true,
		"recorded_at_msec": host_time_msec,
		"result": result.duplicate(true),
	}
	_emit_semantic_state(player_id)
	elimination_recorded.emit(record.duplicate(true))
	return {"accepted": true, "record": record}


func semantic_state(player_id: String) -> Dictionary:
	var player := _players.get(player_id) as PlayerPoseState
	if player == null:
		return {}
	return {
		"player_id": player.player_id,
		"direction": player.charge.direction,
		"charge": player.charge.charge,
		"held": player.charge.held,
		# These aliases can be passed directly to HybridCharacterAnimator without
		# making the animation component authoritative.
		"pose_direction": player.charge.direction,
		"pose_charge": player.charge.charge,
		"pose_held": player.charge.held,
		"reaction": player.reaction,
		"eliminated": player.eliminated,
		"connected": player.connected,
		"withdrawn": player.withdrawn,
		"latest_input_seq": player.latest_input_seq,
		"latest_input_received_msec": player.latest_input_received_msec,
	}


func current_deadline_msec() -> int:
	return _evaluation_deadline_msec


func _advance_to(host_time_msec: int) -> void:
	if _last_advanced_msec < 0:
		_last_advanced_msec = host_time_msec
		return
	var delta := float(host_time_msec - _last_advanced_msec) / 1000.0
	if delta <= 0.0:
		return
	for player: PlayerPoseState in _players.values():
		if not player.withdrawn and not player.eliminated:
			player.charge.advance(delta, player.charge.direction if player.charge.held else &"")
			_emit_semantic_state(player.player_id)
	_last_advanced_msec = host_time_msec


func _accept_host_time(host_time_msec: int) -> bool:
	return host_time_msec >= 0 and (_last_advanced_msec < 0 or host_time_msec >= _last_advanced_msec)


func _result_reason(player: PlayerPoseState, success: bool) -> StringName:
	if success:
		return &"success"
	if not player.connected:
		return &"disconnected"
	if player.charge.direction.is_empty():
		return &"no_input"
	if player.charge.direction != _target_direction:
		return &"wrong_direction"
	if not player.charge.held:
		return &"released"
	return &"incomplete_charge"


func _result_for_player(player_id: String) -> Dictionary:
	for result: Dictionary in _resolved_results:
		if result.player_id == player_id:
			return result
	return {}


func _emit_semantic_state(player_id: String) -> void:
	semantic_state_changed.emit(player_id, semantic_state(player_id))


func _rejected(code: StringName) -> Dictionary:
	return {"accepted": false, "code": code}
