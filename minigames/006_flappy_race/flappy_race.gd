class_name FlappyRace
extends Control
## The catalog entry's scene: takes the launch from SessionHost, runs the race on a
## [FlappyRaceController], draws it with [FlappyRacePresentation], gives the phones its protocol
## and offers Return to lobby.

const ID := &"flappy_race"
const LOBBY_PATH := "res://scenes/lobby.tscn"

var participants: Array = []
var controller: FlappyRaceController
var _host: Node
var _protocol: FlappyRaceProtocol

@onready var return_button: Button = %ReturnToLobby
@onready var presentation: FlappyRacePresentation = %Presentation


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
	controller = FlappyRaceController.new()
	add_child(controller)
	controller.start_race(participants, randi(), Time.get_ticks_msec())
	_host.players_changed.connect(_on_players_changed)
	_protocol = FlappyRaceProtocol.new(controller)
	_host.register_minigame_protocol(_protocol)
	presentation.bind(controller)


func _on_players_changed(players: Array[Dictionary]) -> void:
	controller.observe_registry(players, Time.get_ticks_msec())


func _return_to_lobby() -> void:
	if _host != null:
		_host.send_players_to_lobby()
		_host.clear_minigame_launch()
	get_tree().change_scene_to_file(LOBBY_PATH)


func _exit_tree() -> void:
	if _host != null and _host.players_changed.is_connected(_on_players_changed):
		_host.players_changed.disconnect(_on_players_changed)
	if _protocol != null and _host != null:
		_host.unregister_minigame_protocol(_protocol)
	_protocol = null
