extends Control

## Every step of the full game. This entry runs the boot itself, to show a failure with Retry.
@export var boot_request: BootRequest = preload("res://host/full_game_boot_request.tres")


func _ready() -> void:
	$Center/Column/Retry.pressed.connect(_start)
	_start.call_deferred()


func _start() -> void:
	$Center/Column/Retry.hide()
	if not SessionHost.boot(boot_request):
		$Center/Column/Status.text = SessionHost.startup_error
		$Center/Column/Retry.show()
