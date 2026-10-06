class_name TiltShiftMotionController
extends Node
## Preparation/readiness seam and host-only motion consumer; owns no roster or physics.

signal state_changed(player_id: String, state: Dictionary)

var clock: Callable = Time.get_ticks_msec
var inputs: Dictionary[String, TiltShiftTiltInput] = { }
var _service: WebsocketService
var _channels: Dictionary[String, MotionInputChannel] = { }
var _callbacks: Dictionary[String, Callable] = { }
var _states: Dictionary[String, Dictionary] = { }
var _feedback_at: Dictionary[String, int] = { }
var _generations: Dictionary[String, String] = { }
var _arena: TiltShiftArena
var _locked: bool = false
var _token: String = ""
var _playing: bool = false
var _new_round: bool = false


func prepare(
	service: WebsocketService,
	player_ids: PackedStringArray,
	selected: TiltShiftMotionTuning,
) -> bool:
	if service == null or selected == null or not selected.validation_errors().is_empty():
		return false
	stop()
	if not service.begin_multiplayer_motion(player_ids):
		return false
	_service = service
	_service.motion_session_ended.connect(_on_session_ended)
	for player_id: String in player_ids:
		var channel := service.motion_channels[player_id]
		_channels[player_id] = channel
		inputs[player_id] = TiltShiftTiltInput.new(selected)
		var callback := _calibrate.bind(player_id)
		_callbacks[player_id] = callback
		channel.calibration_requested.connect(callback)
	return true


func activate(arena: TiltShiftArena) -> bool:
	if _locked or inputs.is_empty() or arena == null or arena.controller == null:
		return false
	var snapshot := arena.controller.snapshot()
	if snapshot.phase != &"active" or snapshot.players.size() != inputs.size():
		return false
	for player: TiltShiftState.Player in snapshot.players:
		if not inputs.has(player.player_id) or not ready_for(player.player_id):
			return false
	_arena = arena
	_locked = true
	_arena.stopped.connect(stop)
	_arena.tree_exiting.connect(stop)
	_arena.controller.shift_finished.connect(_on_finished)
	_arena.controller.round_started.connect(_on_started)
	_arena.controller.round_ended.connect(_on_ended)
	_on_started(snapshot)
	return true


func ready_for(player_id: String) -> bool:
	var state := player_state(player_id)
	return bool(state.get("calibrated", false)) and bool(state.get("usable", false))


func player_state(player_id: String) -> Dictionary:
	if not inputs.has(player_id):
		return { }
	return inputs[player_id].state(_channels[player_id], clock.call())


func _calibrate(now: int, player_id: String) -> void:
	if not inputs.has(player_id):
		return
	var accepted := not _locked and inputs[player_id].calibrate(_channels[player_id], now)
	var result := player_state(player_id)
	result.accepted = accepted
	result.reason = (
		"active_calibration_locked"
		if _locked
		else ("calibrated" if accepted else result.capture_state)
	)
	_publish(player_id, result, true)


func _process(_delta: float) -> void:
	poll()


func poll() -> void:
	if _service == null:
		return
	var now: int = clock.call()
	if _locked:
		if not is_instance_valid(_arena) or not is_instance_valid(_arena.controller):
			stop()
			return
	var new_round := _new_round
	_new_round = false
	for player_id: String in inputs.keys():
		var updated := inputs[player_id].update(_channels[player_id], now)
		var state := player_state(player_id)
		if (
			state != _states.get(player_id, { })
			or _channels[player_id].subscription_id != _generations.get(player_id, "")
		):
			_publish(player_id, state)
			if _service == null:
				return
		if _playing and (updated or new_round):
			_arena.controller.accept_angle(player_id, inputs[player_id].angle_radians, _token, now)
			if _service == null:
				return


func _on_started(snapshot: TiltShiftState.Snapshot) -> void:
	_token = snapshot.round_token
	_playing = true
	_new_round = true


func _on_ended(_snapshot: TiltShiftState.Snapshot) -> void:
	_playing = false


func _publish(player_id: String, state: Dictionary, calibration_result: bool = false) -> void:
	var now: int = clock.call()
	var generation := _channels[player_id].subscription_id
	if (
		not calibration_result and generation == _generations.get(player_id, "")
		and now - _feedback_at.get(player_id, -1000) < 200
	):
		return
	_feedback_at[player_id] = now
	_generations[player_id] = generation
	_states[player_id] = player_state(player_id)
	_service.send_motion_feedback(player_id, generation, state)
	state_changed.emit(player_id, state.duplicate(true))


func _on_finished(_snapshot: TiltShiftState.Snapshot) -> void:
	stop()


func _on_session_ended() -> void:
	stop()


func stop() -> void:
	var service := _service
	_service = null
	if is_instance_valid(_arena):
		if _arena.stopped.is_connected(stop):
			_arena.stopped.disconnect(stop)
		if _arena.tree_exiting.is_connected(stop):
			_arena.tree_exiting.disconnect(stop)
		if is_instance_valid(_arena.controller):
			var finish := _arena.controller.shift_finished
			if finish.is_connected(_on_finished):
				finish.disconnect(_on_finished)
			if _arena.controller.round_started.is_connected(_on_started):
				_arena.controller.round_started.disconnect(_on_started)
			if _arena.controller.round_ended.is_connected(_on_ended):
				_arena.controller.round_ended.disconnect(_on_ended)
	_arena = null
	if is_instance_valid(service):
		if service.motion_session_ended.is_connected(_on_session_ended):
			service.motion_session_ended.disconnect(_on_session_ended)
		var owns_session := false
		for player_id: String in _channels:
			var channel := _channels[player_id]
			channel.calibration_requested.disconnect(_callbacks[player_id])
			owns_session = owns_session or service.motion_channels.get(player_id) == channel
		if owns_session:
			service.end_motion()
	inputs.clear()
	_channels.clear()
	_callbacks.clear()
	_states.clear()
	_feedback_at.clear()
	_generations.clear()
	_locked = false
	_token = ""
	_playing = false
	_new_round = false


func _exit_tree() -> void:
	stop()
