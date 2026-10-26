class_name FlappyRaceProtocol
extends MinigameProtocol
## The phones' view of a Flappy Race. It accepts no input yet; every phone waits on the shared
## screen until the race exists.

const SNAPSHOT_TYPE := "flappy_race_snapshot"

var _player_count: int


func _init(player_count: int) -> void:
	_player_count = player_count


func snapshot_for(_player_id: String) -> Dictionary:
	return { "type": SNAPSHOT_TYPE, "state": "waiting", "player_count": _player_count }
