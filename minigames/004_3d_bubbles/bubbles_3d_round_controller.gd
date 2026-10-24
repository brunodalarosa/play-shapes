class_name Bubbles3DRoundController
extends Node
## Host-owned rules for one round of Bubbles and jellyfishes 3D: phases, scores, pops, the
## zero-time freeze and ranking. Physics and transport are separate callers; no client packet
## changes a score directly.

signal phase_changed(phase: StringName, snapshot: Dictionary)
signal arena_event_requested(kind: StringName, player_id: String, data: Dictionary)
signal personal_state_changed(player_id: String, snapshot: Dictionary)
signal personal_visual_changed(player_id: String, visual_state: Dictionary)
signal feedback_requested(player_id: String, kind: StringName, data: Dictionary)
signal drag_visual_changed(player_id: String, direction: Vector2, gesture_started_msec: int)
signal round_results_ready(results: Dictionary)
signal return_to_lobby_requested

enum Phase {
	IDLE,
	INSTRUCTIONS,
	COUNTDOWN,
	ACTIVE,
	RESULTS,
	LOBBY_RETURN,
}


## One player's round state. Snapshots copy it into dictionaries at the edges.
class PlayerState:
	extends RefCounted

	var player_id := ""
	var display_name := ""
	var character_shape := ""
	var character_color := ""
	var seat := 0
	var score := 0
	var connected := true
	var left := false
	var invulnerable_until_msec := -1
	var last_pop_msec := -1
	var last_input_seq := -1


	func to_dictionary() -> Dictionary:
		return {
			"player_id": player_id,
			"name": display_name,
			"character_shape": character_shape,
			"character_color": character_color,
			"seat": seat,
			"score": score,
			"connected": connected,
			"left": left,
			"invulnerable_until_msec": invulnerable_until_msec,
			"last_pop_msec": last_pop_msec,
			"last_input_seq": last_input_seq,
		}


const PHASE_NAMES: Array[StringName] = [
	&"idle",
	&"instructions",
	&"countdown",
	&"active",
	&"results",
	&"lobby_return",
]
const MAX_INPUT_SEQ := 9_007_199_254_740_991
const MAX_PLAYERS := 10

@export var tuning: Bubbles3DTuning = preload("res://minigames/004_3d_bubbles/tuning/Default.tres")

var phase: Phase = Phase.IDLE
var _players: Dictionary[String, PlayerState] = { }
var _player_order: Array[String] = []
var _debug_one_player := false
var _last_host_msec := -1
var _countdown_deadline_msec := -1
var _active_start_msec := -1
var _finish_msec := -1
var _frozen_results: Dictionary = { }
var _random := RandomNumberGenerator.new()
var _injected_random: Array[float] = []


func _ready() -> void:
	set_process(false)
	var session_host := get_node_or_null("/root/SessionHost")
	if session_host != null:
		var active: ActivePresets = session_host.get("active_presets")
		if active != null and active.bubbles_3d != null:
			tuning = active.bubbles_3d


func _process(_delta: float) -> void:
	advance(Time.get_ticks_msec())


## Makes spawn choices reproducible for tests.
func set_random_seed(seed: int) -> void:
	_random.seed = seed
	_injected_random.clear()


## Queues exact random units in [0, 1) for the next draws, for deterministic tests.
func inject_random_values(values: Array) -> bool:
	var checked: Array[float] = []
	for raw: Variant in values:
		if typeof(raw) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var value := float(raw)
		if not is_finite(value) or value < 0.0 or value >= 1.0:
			return false
		checked.append(value)
	_injected_random = checked
	return true


func next_random_unit() -> float:
	if not _injected_random.is_empty():
		return _injected_random.pop_front()
	return _random.randf()


func start_round(
	participants: Array,
	host_time_msec: int,
	allow_one_player_debug := false,
) -> Dictionary:
	if phase != Phase.IDLE:
		return _reject(&"round_already_started")
	if tuning == null or not tuning.validation_errors().is_empty():
		return _reject(&"invalid_tuning")
	var fewest := 1 if allow_one_player_debug else 2
	if host_time_msec < 0 or participants.size() > MAX_PLAYERS or participants.size() < fewest:
		return _reject(&"invalid_participants")
	var fresh: Dictionary[String, PlayerState] = { }
	var order: Array[String] = []
	for index: int in participants.size():
		var source: Variant = participants[index]
		if not source is Dictionary or typeof(source.get("player_id")) != TYPE_STRING:
			return _reject(&"invalid_participants")
		var player_id: String = source.player_id
		if player_id.is_empty() or fresh.has(player_id):
			return _reject(&"invalid_participants")
		var seat: Variant = source.get("seat", index + 1)
		if typeof(seat) != TYPE_INT or seat < 1:
			return _reject(&"invalid_participants")
		var selection := CharacterSelection.for_player(source)
		var state := PlayerState.new()
		state.player_id = player_id
		state.display_name = String(source.get("name", ""))
		state.character_shape = selection.character_shape
		state.character_color = selection.character_color
		state.seat = seat
		state.connected = source.get("state", "connected") == "connected"
		fresh[player_id] = state
		order.append(player_id)
	_players = fresh
	_player_order = order
	_debug_one_player = allow_one_player_debug and participants.size() == 1
	_last_host_msec = host_time_msec
	# The shared booklet owns instructions; this phase only waits for the entrance.
	_transition(Phase.INSTRUCTIONS)
	set_process(true)
	return { "accepted": true, "players": player_snapshot() }


## Presentation acknowledges that the bubbles finished entering.
func complete_entrance(host_time_msec: int) -> Dictionary:
	if not _valid_time(host_time_msec) or phase != Phase.INSTRUCTIONS:
		return _reject(&"entrance_not_ready")
	_last_host_msec = host_time_msec
	_countdown_deadline_msec = host_time_msec + roundi(tuning.countdown_seconds * 1000.0)
	_transition(Phase.COUNTDOWN)
	arena_event_requested.emit(
		&"place_starting_jellyfish",
		"",
		{ "count": tuning.starting_jellyfish },
	)
	return { "accepted": true, "phase": phase_name() }


func advance(host_time_msec: int) -> Dictionary:
	if not _valid_time(host_time_msec) or phase == Phase.IDLE:
		return _reject(&"non_monotonic_host_time")
	_last_host_msec = host_time_msec
	if phase == Phase.COUNTDOWN and host_time_msec >= _countdown_deadline_msec:
		_active_start_msec = _countdown_deadline_msec
		_finish_msec = _active_start_msec + roundi(tuning.round_duration_seconds * 1000.0)
		_transition(Phase.ACTIVE)
	if phase == Phase.ACTIVE and host_time_msec >= _finish_msec:
		_freeze_results()
	return { "accepted": true, "phase": phase_name() }


## The arena reports one real jellyfish contact. Client packets never call this.
func record_jellyfish_capture(player_id: String, host_time_msec: int) -> Dictionary:
	if not _settle_active_event(host_time_msec):
		return _reject(&"wrong_phase_or_time")
	var state: PlayerState = _players.get(player_id)
	if state == null:
		return _reject(&"unknown_player")
	if state.left or host_time_msec < state.invulnerable_until_msec:
		return _reject(&"not_collectible")
	state.score += 1
	personal_state_changed.emit(player_id, personal_snapshot(player_id))
	feedback_requested.emit(player_id, &"captured", { "score": state.score })
	return { "accepted": true, "score": state.score }


## A pufferfish contact pops the bubble: the whole catch is lost and part of it scatters.
func pop_player(player_id: String, host_time_msec: int) -> Dictionary:
	if not _settle_active_event(host_time_msec):
		return _reject(&"wrong_phase_or_time")
	return _pop(player_id, host_time_msec, false)


## One completed touch. [param displacement] is the net movement as a share of the phone's
## touch area, in plane axes (X right, Y up). Only its direction matters once it is long enough.
func submit_swipe(
	player_id: String,
	input_seq: Variant,
	displacement: Vector2,
	host_receipt_msec: int,
	gesture_started_msec: int = -1,
) -> Dictionary:
	if not _settle_active_event(host_receipt_msec):
		return _reject(&"wrong_phase_or_time")
	var state: PlayerState = _players.get(player_id)
	if state == null:
		return _reject(&"unknown_player")
	if state.left or not state.connected:
		return _reject(&"player_unavailable")
	if not _valid_sequence(input_seq) or int(input_seq) <= state.last_input_seq:
		return _reject(&"stale_or_invalid_sequence")
	if gesture_started_msec > host_receipt_msec:
		return _reject(&"invalid_gesture_time")
	if not displacement.is_finite() or absf(displacement.x) > 1.0 or absf(displacement.y) > 1.0:
		return _reject(&"invalid_displacement")
	state.last_input_seq = int(input_seq)
	var outcome := { "accepted": true, "action": &"swipe" }
	var longest_hold_msec := roundi(tuning.swipe_max_hold_seconds * 1000.0)
	if displacement.length() < tuning.swipe_min_distance:
		outcome = { "accepted": true, "action": &"none", "reason": &"swipe_too_short" }
	elif gesture_started_msec >= 0 and host_receipt_msec - gesture_started_msec > longest_hold_msec:
		outcome = { "accepted": true, "action": &"none", "reason": &"swipe_too_slow" }
	else:
		arena_event_requested.emit(
			&"swipe",
			player_id,
			{ "direction": displacement.normalized(), "strength": tuning.swipe_impulse },
		)
	personal_state_changed.emit(player_id, personal_snapshot(player_id))
	return outcome


## Pass the full registry roster. A missing ID is an explicit leave; reconnecting IDs stay.
func observe_registry(players: Array, host_time_msec: int) -> void:
	if phase == Phase.IDLE or not _valid_time(host_time_msec):
		return
	advance(host_time_msec)
	if phase not in [Phase.INSTRUCTIONS, Phase.COUNTDOWN, Phase.ACTIVE]:
		return
	var present: Dictionary[String, bool] = { }
	for raw: Variant in players:
		if not raw is Dictionary:
			continue
		var player_id := String(raw.get("player_id", ""))
		var state: PlayerState = _players.get(player_id)
		if state == null or present.has(player_id):
			continue
		present[player_id] = true
		if state.left:
			continue
		var connected: bool = raw.get("state", "reconnecting") == "connected"
		if state.connected != connected:
			state.connected = connected
			personal_state_changed.emit(player_id, personal_snapshot(player_id))
	for player_id: String in _player_order:
		var state := _players[player_id]
		if not present.has(player_id) and not state.left:
			_pop(player_id, host_time_msec, true)
			state.left = true
			state.connected = false
			personal_state_changed.emit(player_id, personal_snapshot(player_id))
			arena_event_requested.emit(&"player_left", player_id, { })


func request_return_to_lobby() -> bool:
	if phase != Phase.RESULTS:
		return false
	_transition(Phase.LOBBY_RETURN)
	set_process(false)
	return_to_lobby_requested.emit()
	return true


func phase_name() -> StringName:
	return PHASE_NAMES[phase]


func is_one_player_debug() -> bool:
	return _debug_one_player


func active_start_msec() -> int:
	return _active_start_msec


func finish_msec() -> int:
	return _finish_msec


func countdown_deadline_msec() -> int:
	return _countdown_deadline_msec


func last_host_time_msec() -> int:
	return _last_host_msec


func player_ids() -> Array[String]:
	return _player_order.duplicate()


func player_snapshot() -> Dictionary:
	var result: Dictionary = { }
	for player_id: String in _player_order:
		result[player_id] = _players[player_id].to_dictionary()
	return result


func personal_snapshot(player_id: String) -> Dictionary:
	var state: PlayerState = _players.get(player_id)
	if state == null:
		return { }
	var snapshot := state.to_dictionary()
	snapshot.phase = phase_name()
	snapshot.host_time_msec = _last_host_msec
	snapshot.finish_msec = _finish_msec
	snapshot.visual_jellyfish = mini(state.score, tuning.captured_visual_cap)
	snapshot.bubble_radius = tuning.radius_for(state.score)
	return snapshot


func result_snapshot() -> Dictionary:
	return _frozen_results.duplicate(true)


func _pop(player_id: String, host_time_msec: int, forced_leave: bool) -> Dictionary:
	var state: PlayerState = _players.get(player_id)
	if state == null:
		return _reject(&"unknown_player")
	if state.left or (not forced_leave and host_time_msec < state.invulnerable_until_msec):
		return _reject(&"invulnerable_or_left")
	var lost := state.score
	var released := clampi(roundi(float(lost) * (1.0 - tuning.pop_disappear_ratio)), 0, lost)
	state.score = 0
	state.last_pop_msec = host_time_msec
	state.invulnerable_until_msec = host_time_msec + roundi(
		tuning.pop_invulnerability_seconds * 1000.0
	)
	var data := {
		"lost": lost,
		"released": released,
		"at_msec": host_time_msec,
		"lockout_msec": roundi(tuning.released_collection_lockout_seconds * 1000.0),
		"invulnerable_until_msec": state.invulnerable_until_msec,
	}
	arena_event_requested.emit(&"pop", player_id, data.duplicate())
	feedback_requested.emit(player_id, &"pop", data.duplicate())
	personal_state_changed.emit(player_id, personal_snapshot(player_id))
	return { "accepted": true, "lost": lost, "released": released }


func _freeze_results() -> void:
	if phase != Phase.ACTIVE:
		return
	var ranking: Array[Dictionary] = []
	for player_id: String in _player_order:
		var state := _players[player_id]
		ranking.append(
			{
				"player_id": player_id,
				"name": state.display_name,
				"seat": state.seat,
				"character_shape": state.character_shape,
				"character_color": state.character_color,
				"score": state.score,
				"left": state.left,
			}
		)
	ranking.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.score != b.score:
				return a.score > b.score
			return a.seat < b.seat,
	)
	var by_player_id: Dictionary = { }
	for index: int in ranking.size():
		var rank := index + 1
		if index > 0 and ranking[index].score == ranking[index - 1].score:
			rank = ranking[index - 1].rank
		ranking[index].rank = rank
		by_player_id[ranking[index].player_id] = ranking[index].duplicate()
	_frozen_results = {
		"finished_at_msec": _finish_msec,
		"ranking": ranking,
		"by_player_id": by_player_id,
	}
	_transition(Phase.RESULTS)
	set_process(false)
	round_results_ready.emit(result_snapshot())


func _transition(next: Phase) -> void:
	phase = next
	phase_changed.emit(phase_name(), { "players": player_snapshot(), "finish_msec": _finish_msec })


func _settle_active_event(host_time_msec: int) -> bool:
	if not _valid_time(host_time_msec):
		return false
	advance(host_time_msec)
	return phase == Phase.ACTIVE


func _valid_time(host_time_msec: int) -> bool:
	return host_time_msec >= 0 and host_time_msec >= _last_host_msec


func _valid_sequence(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return (
		is_finite(number) and number >= 0.0
		and number <= float(MAX_INPUT_SEQ) and floorf(number) == number
	)


func _reject(code: StringName) -> Dictionary:
	return { "accepted": false, "code": code }
