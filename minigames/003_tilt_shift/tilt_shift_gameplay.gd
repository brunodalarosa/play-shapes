class_name TiltShiftGameplay
extends Control
## Normal catalog entry; the reusable factory stays independent of host services.

var presentation: TiltShiftPresentation
var return_button: Button
var _host: Node
const FACTORY := preload("res://minigames/003_tilt_shift/tilt_shift_presentation.tscn")


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
	var launch: Dictionary = _host.consume_minigame_launch(TiltShiftSession.ID)
	if launch.is_empty() or not _host.tilt_shift.attach(presentation, launch.participants):
		_return_to_lobby.call_deferred()
		return
	presentation.arena.controller.shift_finished.connect(_show_return)


func _show_return(_state: TiltShiftState.Snapshot) -> void:
	return_button.show()


func _return_to_lobby() -> void:
	_host.send_players_to_lobby()
	_host.clear_minigame_launch()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _exit_tree() -> void:
	if _host != null:
		_host.tilt_shift.stop()
