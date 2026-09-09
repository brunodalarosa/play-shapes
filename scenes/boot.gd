extends Control

func _ready() -> void:
	$Center/Column/Retry.pressed.connect(_start)
	_start.call_deferred()

func _start() -> void:
	$Center/Column/Retry.hide()
	if SessionHost.start():
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	else:
		$Center/Column/Status.text = SessionHost.startup_error + "\nClose the other host or change host/default_settings.tres, then retry."
		$Center/Column/Retry.show()
