class_name TiltShift3DGameplay
extends Control
## The catalog entry's scene: the factory, attached to the session SessionHost prepared on the
## Pre-minigame screen, and Return to lobby once the shift's results show.

const FACTORY := preload("res://minigames/005_3d_tilt_shift/tilt_shift_3d_presentation.tscn")

var presentation: TiltShift3DPresentation
var return_button: Button
var _host: Node
var _session: TiltShift3DSession


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	presentation = FACTORY.instantiate()
	add_child(presentation)
	return_button = Button.new()
	add_child(return_button)
	return_button.text = "Return to lobby"
	return_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	return_button.offset_left = -260
	return_button.offset_top = -72
	return_button.offset_right = -24
	return_button.offset_bottom = -20
	return_button.custom_minimum_size = Vector2(236, 52)
	return_button.pressed.connect(_return_to_lobby)
	return_button.hide()
	_host = get_node_or_null("/root/SessionHost")
	if _host == null:
		return
	_session = _host.minigame_session(TiltShift3DSession.ID) as TiltShift3DSession
	var launch: Dictionary = _host.consume_minigame_launch(TiltShift3DSession.ID)
	if (
		launch.is_empty() or _session == null
		or not _session.attach(presentation, launch.participants)
	):
		_return_to_lobby.call_deferred()
		return
	presentation.arena.controller.shift_finished.connect(_show_return)
	presentation.force_start_requested.connect(_force_start)


func _force_start(token: String) -> void:
	_session.force_start(token, _session.generation)


func _show_return(_state: TiltShift3DState.Snapshot) -> void:
	return_button.show()


func _return_to_lobby() -> void:
	_host.send_players_to_lobby()
	_host.clear_minigame_launch()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _exit_tree() -> void:
	if _session != null:
		_session.stop()
