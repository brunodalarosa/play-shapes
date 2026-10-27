class_name FlappyRace
extends Control
## The catalog entry's scene: takes the launch from SessionHost, runs the race on a
## [FlappyRaceController], gives the phones its protocol and offers Return to lobby. The race
## has no picture yet; a line of text follows its phase and timer.

const ID := &"flappy_race"
const LOBBY_PATH := "res://scenes/lobby.tscn"

var participants: Array = []
var controller: FlappyRaceController
var _host: Node
var _protocol: FlappyRaceProtocol

@onready var return_button: Button = %ReturnToLobby
@onready var _player_count: Label = %PlayerCount
@onready var _race_status: Label = %RaceStatus


func _ready() -> void:
	set_process(false)
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
	controller = FlappyRaceController.new()
	add_child(controller)
	controller.start_race(participants, randi(), Time.get_ticks_msec())
	_host.players_changed.connect(_on_players_changed)
	_protocol = FlappyRaceProtocol.new(controller)
	_host.register_minigame_protocol(_protocol)
	set_process(true)


func _process(_delta: float) -> void:
	_race_status.text = status_text()


## The phase, with the seconds to GO or left on the race timer.
func status_text() -> String:
	if controller == null:
		return ""
	match controller.phase_name():
		&"countdown":
			return "Get ready: %d" % ceili(controller.countdown_remaining_msec() / 1000.0)
		&"racing":
			var left_ticks := controller.race_ticks() - controller.settled_tick
			var left := ceili(float(left_ticks) / FlappyFlightTuning.TICK_RATE)
			return "Racing: %d:%02d left" % [left / 60, left % 60]
	return "Results"


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
