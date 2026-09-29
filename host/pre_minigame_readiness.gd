class_name PreMinigameReadiness
extends RefCounted
## One host-owned round roster. Transport resolves identity before calling set_ready().

signal changed(snapshot: Dictionary)
signal launch_requested(minigame_id: StringName, participants: Array[Dictionary])
signal canceled

var minigame_id: StringName
var active := true
var transitioning := false
var _participants: Array[Dictionary] = []
var _ready_by_id: Dictionary = {}


func _init(selected_minigame: StringName, players: Array[Dictionary]) -> void:
	minigame_id = selected_minigame
	for player: Dictionary in players:
		_add(player)


func snapshot_for(player_id: String) -> Dictionary:
	return {
		"type": "pre_minigame_snapshot",
		"minigame_id": str(minigame_id),
		"ready": bool(_ready_by_id.get(player_id, false)),
		"players": status_players(),
	}


func status_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player: Dictionary in _participants:
		var status := player.duplicate(true)
		status.ready = bool(_ready_by_id.get(String(player.player_id), false))
		result.append(status)
	return result


func add_joined(player: Dictionary) -> bool:
	if not active or transitioning or _ready_by_id.has(String(player.get("player_id", ""))):
		return false
	_add(player)
	changed.emit(snapshot_for(""))
	return true


func set_ready(player: Dictionary, ready: bool) -> Dictionary:
	if not active or transitioning or player.is_empty() or not _ready_by_id.has(String(player.get("player_id", ""))):
		return {"accepted": false, "code": &"ready_unavailable", "message": "Ready-up is not active for this player"}
	var player_id := String(player.player_id)
	if _ready_by_id[player_id] == ready:
		return {"accepted": true}
	_ready_by_id[player_id] = ready
	changed.emit(snapshot_for(""))
	if ready and not _participants.is_empty() and _all_ready():
		transitioning = true
		active = false
		launch_requested.emit(minigame_id, _participants.duplicate(true))
	return {"accepted": true}


func sync_players(current: Array[Dictionary]) -> void:
	if not active:
		return
	var by_id: Dictionary = {}
	for player: Dictionary in current:
		by_id[String(player.player_id)] = player
	var changed_state := false
	for index: int in _participants.size():
		var old: Dictionary = _participants[index]
		var player_id := String(old.player_id)
		if not by_id.has(player_id):
			# An expired/explicitly left player remains in the selected round until
			# cancellation; it cannot silently make the round all-ready.
			if bool(_ready_by_id[player_id]):
				_ready_by_id[player_id] = false
				changed_state = true
			continue
		var updated: Dictionary = by_id[player_id]
		if old.get("state") != updated.get("state"):
			_ready_by_id[player_id] = false
			changed_state = true
		_participants[index] = updated.duplicate(true)
	if changed_state:
		changed.emit(snapshot_for(""))


func cancel() -> void:
	if not active or transitioning:
		return
	active = false
	canceled.emit()


func _add(player: Dictionary) -> void:
	var player_id := String(player.player_id)
	_participants.append(player.duplicate(true))
	_ready_by_id[player_id] = false


func _all_ready() -> bool:
	for player_id: String in _ready_by_id:
		if not bool(_ready_by_id[player_id]):
			return false
	return true
