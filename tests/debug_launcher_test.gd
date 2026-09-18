extends SceneTree
## Focused checks for registration and state transitions without starting LAN services.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var launcher := root.get_node("DebugLauncher")
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18080
	host.settings.websocket_port = 18081
	if not _check(host.start(), "Test LAN services start"):
		return
	var original_host_id := host.get_instance_id()
	var animation_lab: DebugScenario = launcher.scenario_for_id(&"animation_lab")
	var simon: DebugScenario = launcher.scenario_for_id(&"one_player_simon")
	if not _check(animation_lab != null, "Animation lab is registered"):
		return
	if not _check(animation_lab.availability({}).available, "Implemented animation lab is available"):
		return
	if not _check(simon != null, "One-player Simon Says is reserved"):
		return
	if not _check(not simon.availability({"one_registered_player": false}).available, "Flash? Pose! still requires the one-player debug feature"):
		return
	if not _check(simon.availability({"one_registered_player": true}).available, "Implemented Flash? Pose! stage is available to its one-player debug path"):
		return
	if not _check(not launcher.restart_scenario(), "Restart is disabled outside a debug scenario"):
		return
	if not _check(launcher.active_scenario == null, "Normal startup has no debug scenario"):
		return
	if not _check(launcher.get_tree().paused == false, "Launcher does not pause the scene tree"):
		return
	var f12 := InputEventKey.new()
	f12.keycode = KEY_F12
	f12.pressed = true
	launcher._input(f12)
	if not _check(launcher.is_open(), "F12 opens the overlay"):
		return
	if not _check(launcher.get_tree().paused == false, "Opening the overlay does not pause the scene tree"):
		return
	launcher._input(f12)
	if not _check(not launcher.is_open(), "F12 closes the overlay"):
		return

	var fixture := DebugScenario.new(
		&"test_fixture",
		"Clean-state fixture",
		"res://tests/fixtures/debug_scenario.tscn"
	)
	launcher.register_scenario(fixture)
	if not _check(launcher.launch(&"test_fixture"), "Available scenario launches immediately"):
		return
	await scene_changed
	var first_scene_id := current_scene.get_instance_id()
	if not _check(launcher.marker_text() == "DEBUG — Clean-state fixture", "Debug scenario marker persists"):
		return
	if not _check(host.running and host.get_instance_id() == original_host_id, "LAN service owner survives launch"):
		return
	if not _check(launcher.restart_scenario(), "Current scenario restarts"):
		return
	await scene_changed
	if not _check(current_scene.get_instance_id() != first_scene_id, "Restart reconstructs the scenario scene"):
		return
	if not _check(host.running and host.get_instance_id() == original_host_id, "LAN service owner survives restart"):
		return
	launcher.return_to_lobby()
	await scene_changed
	if not _check(current_scene.scene_file_path == launcher.LOBBY_PATH, "Return loads the lobby"):
		return
	if not _check(launcher.marker_text().is_empty(), "Lobby return removes the debug marker"):
		return
	if not _check(host.running and host.get_instance_id() == original_host_id, "LAN service owner survives lobby return"):
		return
	host.stop()
	print("Debug launcher checks passed")
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
