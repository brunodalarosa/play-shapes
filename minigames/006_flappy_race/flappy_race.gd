class_name FlappyRace
extends Control
## The catalog entry's scene: takes the launch from SessionHost, runs the race on a
## [FlappyRaceController], draws it with [FlappyRacePresentation], gives the phones its protocol
## and offers Return to lobby. It keeps the best finish time of this host run.

const ID := &"flappy_race"
const LOBBY_PATH := "res://scenes/lobby.tscn"

## The best finish time of any race since the host started, ms; -1 before anyone finished.
static var best_msec := -1

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
	controller.race_event.connect(_on_race_event)
	_host.players_changed.connect(_on_players_changed)
	_protocol = FlappyRaceProtocol.new(controller)
	_host.register_minigame_protocol(_protocol)
	presentation.bind(controller)


func _on_players_changed(players: Array[Dictionary]) -> void:
	controller.observe_registry(players, Time.get_ticks_msec())


func _on_race_event(kind: StringName, _player_id: String, _data: Dictionary) -> void:
	if kind != &"results":
		return
	for racer: FlappyRaceRacer in controller.ranking():
		best_msec = record(best_msec, racer.finish_msec())
	presentation.session_best_msec = best_msec


## The better of [param best] and [param time], either -1 for none.
static func record(best: int, time: int) -> int:
	if time < 0:
		return best
	return time if best < 0 else mini(best, time)


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
