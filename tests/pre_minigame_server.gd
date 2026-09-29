extends SceneTree
## Local WebSocket flow fixture. Browser tests own all phone connections.

var _launched := false


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18100
	host.settings.websocket_port = 18101
	if not host.start():
		push_error("Ready fixture could not start")
		quit(1)
		return
	change_scene_to_file("res://scenes/lobby.tscn")
	print("Ready fixture listening")


func _process(_delta: float) -> bool:
	if _launched or current_scene == null or current_scene.scene_file_path != "res://scenes/lobby.tscn":
		return false
	var host := root.get_node("SessionHost")
	if host.player_registry.player_count() != 2:
		return false
	var start := current_scene.get_node("%StartMinigame") as Button
	if start.disabled:
		return false
	_launched = true
	start.pressed.emit()
	return false
