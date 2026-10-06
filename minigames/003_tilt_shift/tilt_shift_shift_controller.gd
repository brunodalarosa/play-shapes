class_name TiltShiftShiftController
extends Node
## Host rules only. Call advance with the same monotonic time used by the future arena.

signal round_started(snapshot: TiltShiftState.Snapshot)
signal assignments_changed(snapshot: TiltShiftState.Snapshot)
signal angle_changed(player: TiltShiftState.Player)
signal presence_changed(player: TiltShiftState.Player)
signal score_changed(snapshot: TiltShiftState.Snapshot)
signal round_ended(snapshot: TiltShiftState.Snapshot)
signal shift_finished(snapshot: TiltShiftState.Snapshot)

enum Phase {
	IDLE,
	ACTIVE,
	BETWEEN_ROUNDS,
	FINISHED,
}
const PHASE_NAMES: Array[StringName] = [&"idle", &"active", &"between_rounds", &"finished"]

static var _next_generation: int = 0

@export var tuning: TiltShiftTuning = preload("res://minigames/003_tilt_shift/tuning/Default.tres")

var _phase: Phase = Phase.IDLE
var _content: TiltShiftTuning
var _players: Array[TiltShiftState.Player] = []
var _teams: Array[PackedStringArray] = []
var _neighbors: Array[TiltShiftState.Neighbor] = []
var _allocations: Array[TiltShiftState.Allocation] = []
var _scores: Array[int] = [0, 0]
var _round_number: int = 0
var _generation: int = 0
var _round_token: String = ""
var _last_time_msec: int = -1
var _started_at_msec: int = -1
var _deadline_msec: int = -1
var _balls := PackedByteArray()
var _notifying: bool = false
var _random := RandomNumberGenerator.new()


func _init() -> void:
	_random.randomize()


func set_random_seed(seed: int) -> void:
	_random.seed = seed


func start_shift(
	participants: Array[TiltShiftState.Player],
	host_time_msec: int,
) -> TiltShiftState.Result:
	if _notifying or _phase not in [Phase.IDLE, Phase.FINISHED]:
		return TiltShiftState.rejected(&"shift_already_running")
	if not _valid_time(host_time_msec):
		return TiltShiftState.rejected(&"invalid_host_time")
	if tuning == null:
		return TiltShiftState.rejected(&"invalid_tuning", ["Tilt Shift: select a tuning preset."])
	var errors := tuning.validation_errors()
	if not errors.is_empty():
		return TiltShiftState.rejected(&"invalid_tuning", errors)
	if participants.size() not in [2, 4, 6, 8, 10]:
		return TiltShiftState.rejected(&"invalid_roster")
	var ids := PackedStringArray()
	for player: TiltShiftState.Player in participants:
		if player == null or player.player_id.is_empty() or ids.has(player.player_id) \
				or player.seat < 1:
			return TiltShiftState.rejected(&"invalid_roster")
		ids.append(player.player_id)

	# Ordinary duplication retains external Resources; live content must survive Inspector edits.
	_content = tuning.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	_players.clear()
	for player: TiltShiftState.Player in participants:
		var copied := TiltShiftState.copy_player(player)
		copied.angle_radians = 0.0
		copied.paddle_ids.clear()
		_players.append(copied)
	for index: int in range(_players.size() - 1, 0, -1):
		var other := _random.randi_range(0, index)
		var swapped := _players[index]
		_players[index] = _players[other]
		_players[other] = swapped
	_teams = [PackedStringArray(), PackedStringArray()]
	for index: int in _players.size():
		var player := _players[index]
		player.team = 0 if index < _players.size() / 2 else 1
		_teams[player.team].append(player.player_id)
	_neighbors = TiltShiftPaddleAllocator.neighbors(
		_content.paddle_layout,
		_content.neighbor_distance,
	)
	_allocations.clear()
	_scores = [0, 0]
	_round_number = 0
	_next_generation += 1
	_generation = _next_generation
	_begin_round(host_time_msec)
	return TiltShiftState.accepted()


func advance(host_time_msec: int) -> TiltShiftState.Result:
	if _notifying or _phase == Phase.IDLE or not _valid_time(host_time_msec):
		return TiltShiftState.rejected(&"invalid_phase_or_time")
	_last_time_msec = host_time_msec
	if _phase == Phase.ACTIVE and host_time_msec >= _deadline_msec:
		_finish_round()
	return TiltShiftState.accepted()


## The arena clears old balls before requesting the next round; no grace or implicit delay.
func start_next_round(host_time_msec: int) -> TiltShiftState.Result:
	if _notifying or _phase != Phase.BETWEEN_ROUNDS or not _valid_time(host_time_msec):
		return TiltShiftState.rejected(&"next_round_unavailable")
	_begin_round(host_time_msec)
	return TiltShiftState.accepted()


func register_ball(round_token: String, host_time_msec: int) -> TiltShiftState.Result:
	if not _settle_active(round_token, host_time_msec):
		return TiltShiftState.rejected(&"inactive_or_stale_round")
	var handle := TiltShiftState.BallHandle.new()
	handle.round_token = _round_token
	handle.index = _balls.size()
	_balls.append(0)
	return TiltShiftState.accepted(handle)


func resolve_ball(
	handle: TiltShiftState.BallHandle,
	basket_id: String,
	host_time_msec: int,
) -> TiltShiftState.Result:
	if handle == null or not _settle_active(handle.round_token, host_time_msec):
		return TiltShiftState.rejected(&"inactive_or_stale_round")
	if not _unresolved(handle):
		return TiltShiftState.rejected(&"unknown_or_resolved_ball")
	var basket := _basket(basket_id)
	if basket == null:
		return TiltShiftState.rejected(&"unknown_basket")
	_balls[handle.index] = 1
	if TiltShiftTypes.is_player_team(basket.team):
		_scores[basket.team] += 1
		_notifying = true
		score_changed.emit(snapshot())
		_notifying = false
	return TiltShiftState.accepted()


func discard_ball(handle: TiltShiftState.BallHandle, host_time_msec: int) -> TiltShiftState.Result:
	if handle == null or not _settle_active(handle.round_token, host_time_msec):
		return TiltShiftState.rejected(&"inactive_or_stale_round")
	if not _unresolved(handle):
		return TiltShiftState.rejected(&"unknown_or_resolved_ball")
	_balls[handle.index] = 1
	return TiltShiftState.accepted()


## Only an authenticated host motion consumer calls this seam, never a client callback.
func accept_angle(
	player_id: String,
	angle_radians: float,
	round_token: String,
	host_time_msec: int,
) -> TiltShiftState.Result:
	if not is_finite(angle_radians) or not _settle_active(round_token, host_time_msec):
		return TiltShiftState.rejected(&"invalid_or_stale_control")
	var player := _player(player_id)
	if player == null:
		return TiltShiftState.rejected(&"unknown_player")
	player.angle_radians = angle_radians
	_notifying = true
	angle_changed.emit(TiltShiftState.copy_player(player))
	_notifying = false
	return TiltShiftState.accepted()


func set_connected(player_id: String, connected: bool) -> TiltShiftState.Result:
	if _notifying or _phase not in [Phase.ACTIVE, Phase.BETWEEN_ROUNDS]:
		return TiltShiftState.rejected(&"presence_unavailable")
	var player := _player(player_id)
	if player == null:
		return TiltShiftState.rejected(&"unknown_player")
	player.connected = connected
	_notifying = true
	presence_changed.emit(TiltShiftState.copy_player(player))
	_notifying = false
	return TiltShiftState.accepted()


func snapshot(player_id: String = "") -> TiltShiftState.Snapshot:
	var result := TiltShiftState.Snapshot.new()
	result.phase = PHASE_NAMES[_phase]
	result.round_token = _round_token
	result.round_number = _round_number
	result.round_count = _content.round_count if _content != null else 0
	result.started_at_msec = _started_at_msec
	result.deadline_msec = _deadline_msec
	result.scores.assign(_scores)
	if _phase == Phase.FINISHED:
		result.is_draw = _scores[0] == _scores[1]
		result.winner = -1 if result.is_draw else (0 if _scores[0] > _scores[1] else 1)
	for player: TiltShiftState.Player in _players:
		if player_id.is_empty() or player.player_id == player_id:
			result.players.append(TiltShiftState.copy_player(player))
	for allocation: TiltShiftState.Allocation in _allocations:
		result.allocations.append(TiltShiftState.copy_allocation(allocation))
	for neighbor: TiltShiftState.Neighbor in _neighbors:
		result.neighbors.append(TiltShiftState.copy_neighbor(neighbor))
	if _content != null:
		result.physics = _content.physics.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		result.neighbor_distance = _content.neighbor_distance
		result.paddle_layout = _content.paddle_layout.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		result.basket_preset = _content.baskets_by_round[_round_number - 1].duplicate_deep(
			Resource.DEEP_DUPLICATE_ALL
		)
	return result


func _begin_round(host_time_msec: int) -> void:
	_round_number += 1
	_round_token = "%d:%d" % [_generation, _round_number]
	_started_at_msec = host_time_msec
	_deadline_msec = host_time_msec + roundi(_content.round_duration_seconds * 1000.0)
	_last_time_msec = host_time_msec
	_balls.clear()
	for team: int in 2:
		var paddles: Array[TiltShiftPaddle] = []
		for paddle: TiltShiftPaddle in _content.paddle_layout.paddles:
			if paddle.team == team:
				paddles.append(paddle)
		var previous := PackedStringArray()
		if _allocations.size() > team:
			previous = _allocations[team].owner_ids
		var allocation := TiltShiftPaddleAllocator.allocate(
			paddles,
			_teams[team],
			_round_number - 1,
			_neighbors,
			_random,
			previous,
		)
		if _allocations.size() > team:
			_allocations[team] = allocation
		else:
			_allocations.append(allocation)
	for player: TiltShiftState.Player in _players:
		player.paddle_ids.clear()
		var allocation := _allocations[player.team]
		for index: int in allocation.paddle_ids.size():
			if allocation.owner_ids[index] == player.player_id:
				player.paddle_ids.append(allocation.paddle_ids[index])
	_phase = Phase.ACTIVE
	_notifying = true
	assignments_changed.emit(snapshot())
	round_started.emit(snapshot())
	_notifying = false


func _finish_round() -> void:
	_balls.clear()
	_phase = Phase.FINISHED if _round_number == _content.round_count else Phase.BETWEEN_ROUNDS
	_notifying = true
	round_ended.emit(snapshot())
	if _phase == Phase.FINISHED:
		shift_finished.emit(snapshot())
	_notifying = false


func _valid_time(host_time_msec: int) -> bool:
	return host_time_msec >= 0 and host_time_msec >= _last_time_msec


func _settle_active(round_token: String, host_time_msec: int) -> bool:
	if _notifying or not _valid_time(host_time_msec):
		return false
	# Settle even stale events: the host clock, not callback order, closes scoring.
	if _phase == Phase.ACTIVE:
		advance(host_time_msec)
	return _phase == Phase.ACTIVE and round_token == _round_token


func _unresolved(handle: TiltShiftState.BallHandle) -> bool:
	return handle.index >= 0 and handle.index < _balls.size() and _balls[handle.index] == 0


func _basket(basket_id: String) -> TiltShiftBasketOpening:
	for basket: TiltShiftBasketOpening in _content.baskets_by_round[_round_number - 1].openings:
		if basket.basket_id == basket_id:
			return basket
	return null


func _player(player_id: String) -> TiltShiftState.Player:
	for player: TiltShiftState.Player in _players:
		if player.player_id == player_id:
			return player
	return null
