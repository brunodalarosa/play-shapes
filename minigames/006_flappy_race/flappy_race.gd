class_name FlappyRace
extends Control
## The catalog entry's scene: takes the launch from SessionHost, gives the phones their
## protocol and offers Return to lobby. The race itself is not built yet.

const ID := &"flappy_race"
const LOBBY_PATH := "res://scenes/lobby.tscn"

var participants: Array = []
var _host: Node
var _protocol: FlappyRaceProtocol

@onready var return_button: Button = %ReturnToLobby
@onready var _player_count: Label = %PlayerCount


func _ready() -> void:
	return_button.pressed.connect(_return_to_lobby)
	_host = get_node_or_null("/root/SessionHost")
	if _host == null:
		return

	var launch: Dictionary = _host.consume_minigame_launch(ID)
	if launch.is_empty():
		_return_to_lobby.call_deferred()
		return

	participants = launch.participants
	_player_count.text = (
		"1 player" if participants.size() == 1 else "%d players" % participants.size()
	)
	_protocol = FlappyRaceProtocol.new(participants.size())
	_host.register_minigame_protocol(_protocol)


func _return_to_lobby() -> void:
	if _host != null:
		_host.send_players_to_lobby()
		_host.clear_minigame_launch()
	get_tree().change_scene_to_file(LOBBY_PATH)


func _exit_tree() -> void:
	if _protocol != null and _host != null:
		_host.unregister_minigame_protocol(_protocol)
	_protocol = null
