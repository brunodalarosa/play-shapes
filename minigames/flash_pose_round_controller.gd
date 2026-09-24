class_name FlashPoseRoundController
extends Node
## Scene-scoped authoritative coordinator for one Flash? Pose! round.
## Presentation and transport consume this node's signals but never decide outcomes.

signal phase_changed(phase: StringName, snapshot: Dictionary)
signal semantic_animation_updated(player_id: String, state: Dictionary)
signal genuine_stop_started(stop_id: int, direction: StringName, available_directions: Array[StringName])
signal pose_evaluation_resolved(stop_id: int, results: Array[Dictionary])
signal flash_requested(stop_id: int, results: Array[Dictionary])
signal flash_completed(stop_id: int)
signal round_results_ready(results: Dictionary)
signal return_to_lobby_requested

enum Phase { IDLE, COUNTDOWN, DANCE, GENUINE_STOP_GRACE, RESOLVE, FLASH_WAIT, RESULTS_WAIT, LOBBY_RETURN }

const PHASE_NAMES: Dictionary = {
	Phase.IDLE: &"idle", Phase.COUNTDOWN: &"countdown", Phase.DANCE: &"dance",
	Phase.GENUINE_STOP_GRACE: &"genuine_stop_grace", Phase.RESOLVE: &"resolve",
	Phase.FLASH_WAIT: &"flash_wait", Phase.RESULTS_WAIT: &"results_wait",
	Phase.LOBBY_RETURN: &"lobby_return",
}
const STYLES: Array[StringName] = [&"bounce", &"swing", &"disco"]
const INITIAL_LIVES := 2

@export var tuning: SimonSaysTuning = preload("res://Tuning/Minigames/SimonSays/Default.tres")

var phase: Phase = Phase.IDLE
var style: StringName = &""
var current_stop_id := 0
var current_target: StringName = &""
var _one_player_debug := false
var _players: Dictionary = {}
var _pose_rules: PoseEvaluationRules
var _round_started_msec := -1
var _round_deadline_msec := -1
var _phase_deadline_msec := -1
var _next_stop_msec := -1
var _last_host_time_msec := -1
var _life_loss_counter := 0
var _elimination_counter := 0
var _flash_emitted_for_stop := -1
var _injected_styles: Array[StringName] = []
var _injected_targets: Array[StringName] = []
var _injected_intervals_msec: Array[int] = []
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	set_process(false)
	var session_host := get_node_or_null("/root/SessionHost")
	if session_host != null and session_host.has_signal("players_changed"):
		session_host.players_changed.connect(
			func(players: Array[Dictionary]) -> void: observe_registry(players, Time.get_ticks_msec()))
		if session_host.has_method("register_flash_pose_controller"):
			session_host.register_flash_pose_controller(self)

func _exit_tree() -> void:
	var session_host := get_node_or_null("/root/SessionHost")
	if session_host != null and session_host.has_method("unregister_flash_pose_controller"):
		session_host.unregister_flash_pose_controller(self)


func _process(_delta: float) -> void:
	advance(Time.get_ticks_msec())


## Test seams are queues: each consumed value is removed and normal play falls back to host RNG.
func inject_sequences(styles: Array, targets: Array, intervals_msec: Array = []) -> void:
	_injected_styles.clear()
	_injected_targets.clear()
	_injected_intervals_msec.clear()
	for value: Variant in styles:
		_injected_styles.append(StringName(value))
	for value: Variant in targets:
		_injected_targets.append(StringName(value))
	for value: Variant in intervals_msec:
		_injected_intervals_msec.append(int(value))


func start_round(participants: Array, host_time_msec: int, allow_one_player_debug := false) -> Dictionary:
	if phase != Phase.IDLE:
		return _rejected(&"round_already_started")
	if host_time_msec < 0 or participants.size() < (1 if allow_one_player_debug else 2) or participants.size() > 10:
		return _rejected(&"invalid_participants")
	var participant_ids: Dictionary = {}
	for value: Variant in participants:
		if not value is Dictionary:
			return _rejected(&"invalid_participants")
		var candidate_id := String((value as Dictionary).get("player_id", ""))
		if candidate_id.is_empty() or participant_ids.has(candidate_id):
			return _rejected(&"invalid_participants")
		participant_ids[candidate_id] = true
	_one_player_debug = allow_one_player_debug and participants.size() == 1
	_players.clear()
	_pose_rules = PoseEvaluationRules.new(tuning)
	_pose_rules.semantic_state_changed.connect(_on_semantic_state_changed)
	for index: int in participants.size():
		var source: Dictionary = participants[index]
		var player_id := String(source.get("player_id", ""))
		if player_id.is_empty() or _players.has(player_id) or not _pose_rules.add_player(player_id, host_time_msec):
			_players.clear()
			_pose_rules = null
			return _rejected(&"invalid_participants")
		var selection := CharacterSelection.for_player(source)
		_players[player_id] = {
			"player_id": player_id,
			"name": String(source.get("name", "")),
			"seat": int(source.get("seat", index + 1)),
			"character_shape": selection.character_shape,
			"character_color": selection.character_color,
			"snapshot_index": index,
			"state": &"active",
			"connected": String(source.get("state", "connected")) == "connected",
			"lives": INITIAL_LIVES,
			"life_loss_order": -1,
			"elimination_order": -1,
			"pose_direction": &"",
			"pose_charge": 0.0,
			"pose_held": false,
			"reaction": &"none",
		}
		if not _players[player_id].connected:
			_pose_rules.set_player_connected(player_id, false, host_time_msec)
	style = _choose_style()
	_last_host_time_msec = host_time_msec
	_phase_deadline_msec = host_time_msec + roundi(tuning.countdown_seconds * 1000.0)
	_transition_to(Phase.COUNTDOWN)
	set_process(true)
	return {"accepted": true, "style": style, "players": player_snapshot()}


func advance(host_time_msec: int) -> Dictionary:
	if phase == Phase.IDLE or host_time_msec < _last_host_time_msec:
		return _rejected(&"non_monotonic_host_time")
	_last_host_time_msec = host_time_msec
	match phase:
		Phase.COUNTDOWN:
			if host_time_msec >= _phase_deadline_msec:
				_round_started_msec = _phase_deadline_msec
				_round_deadline_msec = _round_started_msec + roundi(tuning.round_duration_seconds * 1000.0)
				_transition_to(Phase.DANCE)
				_schedule_next_stop(_round_started_msec)
		Phase.DANCE:
			if host_time_msec >= _round_deadline_msec:
				_finish_round(&"timeout")
			elif host_time_msec >= _next_stop_msec:
				_begin_genuine_stop(_next_stop_msec)
		Phase.GENUINE_STOP_GRACE:
			if host_time_msec >= _pose_rules.current_deadline_msec():
				_resolve_stop(host_time_msec)
	# Input events establish held/released state; this host-clock tick makes the
	# authoritative charge and its semantic animation update continuously.
	if _pose_rules != null and phase in [Phase.COUNTDOWN, Phase.DANCE, Phase.GENUINE_STOP_GRACE, Phase.FLASH_WAIT]:
		_pose_rules.advance(host_time_msec)
	return {"accepted": true, "phase": phase_name()}


func submit_pose_input(player_id: String, direction: StringName, held: bool,
		input_seq: int, host_receipt_msec: int) -> Dictionary:
	# Settle any phase/deadline reached before this packet. A packet received
	# after evaluation may begin a new free pose, but can never alter that result.
	if phase not in [Phase.IDLE, Phase.RESULTS_WAIT, Phase.LOBBY_RETURN] \
			and host_receipt_msec >= _last_host_time_msec:
		advance(host_receipt_msec)
	if phase not in [Phase.COUNTDOWN, Phase.DANCE, Phase.GENUINE_STOP_GRACE, Phase.FLASH_WAIT]:
		return _rejected(&"wrong_phase")
	if not _players.has(player_id):
		return _rejected(&"unknown_player")
	if direction not in available_directions(host_receipt_msec):
		return _rejected(&"locked_direction")
	return _pose_rules.submit_input(player_id, direction, held, input_seq, host_receipt_msec)


## Registry snapshots contain only public identity/connectivity state. Missing IDs are explicit leaves.
func observe_registry(players: Array, host_time_msec: int) -> void:
	if _pose_rules == null or host_time_msec < _last_host_time_msec:
		return
	# Settle any deadline before applying a registry event received after it. This
	# prevents a late disconnect/leave from rewriting the deadline snapshot.
	advance(host_time_msec)
	_last_host_time_msec = host_time_msec
	var present: Dictionary = {}
	for value: Variant in players:
		if not value is Dictionary:
			continue
		var registry_player: Dictionary = value
		var player_id := String(registry_player.get("player_id", ""))
		if not _players.has(player_id):
			continue
		present[player_id] = true
		var connected := String(registry_player.get("state", "reconnecting")) == "connected"
		var state: Dictionary = _players[player_id]
		if state.connected != connected:
			state.connected = connected
			_pose_rules.set_player_connected(player_id, connected, host_time_msec)
	for player_id: String in _players:
		var state: Dictionary = _players[player_id]
		if state.state == &"active" and not present.has(player_id):
			state.state = &"withdrawn"
			state.connected = false
			_pose_rules.withdraw_player(player_id, host_time_msec)
	if phase in [Phase.DANCE, Phase.GENUINE_STOP_GRACE] and _has_too_few_players():
		_finish_round(&"last_player")


func acknowledge_flash(stop_id: int, host_time_msec: int) -> Dictionary:
	if phase != Phase.FLASH_WAIT or stop_id != current_stop_id or host_time_msec < _last_host_time_msec:
		return _rejected(&"unexpected_flash_completion")
	_last_host_time_msec = host_time_msec
	flash_completed.emit(stop_id)
	if _has_too_few_players() or host_time_msec >= _round_deadline_msec:
		_finish_round(&"last_player" if _has_too_few_players() else &"timeout")
	else:
		_transition_to(Phase.DANCE)
		_schedule_next_stop(host_time_msec)
	return {"accepted": true, "phase": phase_name()}


func request_return_to_lobby() -> bool:
	if phase != Phase.RESULTS_WAIT:
		return false
	_transition_to(Phase.LOBBY_RETURN)
	set_process(false)
	return_to_lobby_requested.emit()
	return true


func phase_name() -> StringName:
	return PHASE_NAMES[phase]


func last_host_time_msec() -> int:
	return _last_host_time_msec


func is_one_player_debug() -> bool:
	return _one_player_debug


func available_directions(at_msec: int = _last_host_time_msec) -> Array[StringName]:
	var result: Array[StringName] = [&"left", &"right"]
	if _round_started_msec < 0:
		return result
	var elapsed := float(maxi(0, at_msec - _round_started_msec)) / 1000.0
	if elapsed >= tuning.down_unlock_seconds:
		result.append(&"down")
	if elapsed >= tuning.up_unlock_seconds:
		result.append(&"up")
	return result


func player_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state: Dictionary in _players.values():
		var copy := state.duplicate(true)
		copy.erase("snapshot_index")
		result.append(copy)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.seat < b.seat)
	return result


func _begin_genuine_stop(start_msec: int) -> void:
	current_stop_id += 1
	var directions := available_directions(start_msec)
	current_target = _choose_target(directions)
	var opened := _pose_rules.begin_stop(current_stop_id, current_target, start_msec)
	if not opened.accepted:
		return
	for state: Dictionary in _players.values():
		if state.state == &"active":
			state.reaction = &"none"
	_transition_to(Phase.GENUINE_STOP_GRACE)
	genuine_stop_started.emit(current_stop_id, current_target, directions)


func _resolve_stop(host_time_msec: int) -> void:
	_transition_to(Phase.RESOLVE)
	var resolution := _pose_rules.evaluate_stop(current_stop_id, host_time_msec)
	if not resolution.accepted:
		return
	var enriched: Array[Dictionary] = []
	for raw_result: Dictionary in resolution.results:
		var result := raw_result.duplicate(true)
		var state: Dictionary = _players[result.player_id]
		if not result.success:
			state.reaction = &"life_loss"
			if not _one_player_debug:
				state.lives -= 1
				_life_loss_counter += 1
				state.life_loss_order = _life_loss_counter
				if state.lives <= 0:
					state.state = &"eliminated"
					state.reaction = &"none"
					_elimination_counter += 1
					state.elimination_order = _elimination_counter
					_pose_rules.mark_eliminated(result.player_id, current_stop_id, host_time_msec)
		result.lives = state.lives
		result.eliminated = state.state == &"eliminated"
		result.debug_mode = _one_player_debug
		enriched.append(result)
	pose_evaluation_resolved.emit(current_stop_id, enriched.duplicate(true))
	_transition_to(Phase.FLASH_WAIT)
	if _flash_emitted_for_stop != current_stop_id:
		_flash_emitted_for_stop = current_stop_id
		flash_requested.emit(current_stop_id, enriched.duplicate(true))


func _finish_round(reason: StringName) -> void:
	if phase in [Phase.RESULTS_WAIT, Phase.LOBBY_RETURN, Phase.IDLE]:
		return
	var ranking := _build_ranking()
	_transition_to(Phase.RESULTS_WAIT)
	set_process(false)
	round_results_ready.emit({
		"reason": reason,
		"style": style,
		"ranking": ranking,
		"top_group_size": ranking.size() / 2,
	})


func _build_ranking() -> Array[Dictionary]:
	var ranking: Array[Dictionary] = []
	for state: Dictionary in player_snapshot():
		if state.state != &"withdrawn":
			ranking.append(state)
	var all_perfect := true
	for state: Dictionary in ranking:
		if state.lives != INITIAL_LIVES:
			all_perfect = false
			break
	ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.state == &"active" and b.state != &"active": return true
		if b.state == &"active" and a.state != &"active": return false
		if a.state == &"eliminated" and b.state == &"eliminated" and a.elimination_order != b.elimination_order:
			return a.elimination_order > b.elimination_order
		if a.lives != b.lives: return a.lives > b.lives
		if a.life_loss_order != b.life_loss_order: return a.life_loss_order > b.life_loss_order
		if all_perfect: return a.player_id < b.player_id
		return a.seat < b.seat # Presentation-only stable order for an unresolved competitive tie.
	)
	for index: int in ranking.size():
		ranking[index].placement = index + 1
	return ranking


func _schedule_next_stop(from_msec: int) -> void:
	var interval_msec: int
	if not _injected_intervals_msec.is_empty():
		interval_msec = maxi(0, _injected_intervals_msec.pop_front())
	else:
		var reduction := float(current_stop_id) * tuning.stop_interval_reduction_seconds
		var minimum := maxf(0.5, tuning.stop_interval_min_seconds - reduction)
		var maximum := maxf(minimum, tuning.stop_interval_max_seconds - reduction)
		interval_msec = roundi(_random.randf_range(minimum, maximum) * 1000.0)
	_next_stop_msec = mini(from_msec + interval_msec, _round_deadline_msec)


func _choose_style() -> StringName:
	if not _injected_styles.is_empty():
		var candidate: StringName = _injected_styles.pop_front()
		if candidate in STYLES:
			return candidate
	return STYLES[_random.randi_range(0, STYLES.size() - 1)]


func _choose_target(directions: Array[StringName]) -> StringName:
	if not _injected_targets.is_empty():
		var candidate: StringName = _injected_targets.pop_front()
		if candidate in directions:
			return candidate
	return directions[_random.randi_range(0, directions.size() - 1)]


func _eligible_player_count() -> int:
	var count := 0
	for state: Dictionary in _players.values():
		if state.state == &"active":
			count += 1
	return count


func _has_too_few_players() -> bool:
	var eligible := _eligible_player_count()
	return eligible == 0 or (eligible == 1 and not _one_player_debug)


func _on_semantic_state_changed(player_id: String, semantic: Dictionary) -> void:
	if _players.has(player_id):
		var state: Dictionary = _players[player_id]
		state.pose_direction = semantic.pose_direction
		state.pose_charge = semantic.pose_charge
		state.pose_held = semantic.pose_held
		state.reaction = semantic.reaction
		state.connected = semantic.connected
	semantic_animation_updated.emit(player_id, semantic)


func _transition_to(next: Phase) -> void:
	if not _valid_transition(phase, next):
		return
	phase = next
	phase_changed.emit(phase_name(), {"stop_id": current_stop_id, "style": style})


func _valid_transition(from: Phase, to: Phase) -> bool:
	return (from == Phase.IDLE and to == Phase.COUNTDOWN) \
		or (from == Phase.COUNTDOWN and to == Phase.DANCE) \
		or (from == Phase.DANCE and to in [Phase.GENUINE_STOP_GRACE, Phase.RESULTS_WAIT]) \
		or (from == Phase.GENUINE_STOP_GRACE and to in [Phase.RESOLVE, Phase.RESULTS_WAIT]) \
		or (from == Phase.RESOLVE and to == Phase.FLASH_WAIT) \
		or (from == Phase.FLASH_WAIT and to in [Phase.DANCE, Phase.RESULTS_WAIT]) \
		or (from == Phase.RESULTS_WAIT and to == Phase.LOBBY_RETURN)


func _rejected(code: StringName) -> Dictionary:
	return {"accepted": false, "code": code}
