extends SceneTree
## End-to-end scene-flow checks using real registered players and persistent autoloads.

const LOBBY_PATH := "res://scenes/lobby.tscn"
const GAME_PATH := "res://minigames/dancer_simon_says.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := root.get_node("SessionHost")
	var launcher := root.get_node("DebugLauncher")
	var tuning := load("res://Tuning/Minigames/SimonSays/Default.tres") as SimonSaysTuning
	tuning.countdown_seconds = 0.0
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18082
	host.settings.websocket_port = 18083
	if not _check(host.start(), "Persistent LAN services start"):
		return
	var host_id := host.get_instance_id()

	change_scene_to_file(LOBBY_PATH)
	await scene_changed
	await process_frame
	var start_button := current_scene.get_node("%StartMinigame") as Button
	var start_help := current_scene.get_node("%StartHelp") as Label
	if not _check(start_button.disabled and start_help.text.contains("At least 2"),
			"[AUTO] Normal start explains the zero-player gate"):
		return

	var first: Dictionary = host.player_registry.join_player(501, "First", true, 1000)
	await process_frame
	if not _check(first.accepted and start_button.disabled,
			"[AUTO] One registered player cannot unlock normal start"):
		return
	if not _check(launcher.scenario_for_id(&"one_player_simon").availability(
			{"one_registered_player": true}).available,
			"[AUTO] One registered player unlocks only the debug scenario"):
		return
	var second: Dictionary = host.player_registry.join_player(502, "Second", true, 1001)
	await process_frame
	if not _check(second.accepted and not start_button.disabled,
			"[AUTO] Two registered players unlock normal start"):
		return
	if not _check(not launcher.scenario_for_id(&"one_player_simon").availability(
			{"one_registered_player": false}).available,
			"[AUTO] Two players close the one-player debug gate"):
		return

	start_button.pressed.emit()
	await scene_changed
	await process_frame
	var controller := current_scene.get_node(^"RoundController") as FlashPoseRoundController
	if not _check(current_scene.scene_file_path == GAME_PATH and controller.phase_name() == &"countdown",
			"[GODOT-RUNTIME] Normal host control launches the shared Flash? Pose! scene once"):
		return
	if not _check(controller.player_snapshot().size() == 2 and not host.accepting_new_players,
			"[AUTO] Normal launch snapshots two registry participants and closes joins"):
		return
	if not _check(host.player_registry.join_player(503, "Late", host.accepting_new_players, 1002).code == &"game_in_progress",
			"[AUTO] New players cannot join the active round"):
		return
	if not _check(host.running and host.get_instance_id() == host_id,
			"[GODOT-RUNTIME] Scene launch preserves SessionHost and LAN services"):
		return

	controller.advance(Time.get_ticks_msec())
	host.player_registry.leave_connection(502)
	await process_frame
	if not _check(controller.phase_name() == &"results_wait" \
			and controller.player_snapshot()[1].state == &"withdrawn",
			"[AUTO] Explicit gameplay Leave withdraws without replacing the round snapshot"):
		return
	var return_button := current_scene.find_child("ReturnToLobby", true, false) as Button
	if not _check(return_button != null and return_button.visible,
			"[EDITOR] Results expose a shared-display host return control"):
		return
	return_button.pressed.emit()
	await scene_changed
	await process_frame
	if not _check(current_scene.scene_file_path == LOBBY_PATH and host.accepting_new_players,
			"[GODOT-RUNTIME] Results return reopens the lobby"):
		return
	if not _check(host.player_registry.player_count() == 1 and host.running and host.get_instance_id() == host_id,
			"[GODOT-RUNTIME] Lobby return preserves the remaining identity and services"):
		return

	if not _check(launcher.launch(&"one_player_simon"),
			"[AUTO] F12 registration launches with exactly one real registered player"):
		return
	await scene_changed
	await process_frame
	controller = current_scene.get_node(^"RoundController") as FlashPoseRoundController
	if not _check(controller.player_snapshot().size() == 1 and controller.phase_name() == &"countdown" \
			and controller.is_one_player_debug(),
			"[GODOT-RUNTIME] Debug uses the same scene/controller with one participant"):
		return
	if not _check(launcher.marker_text() == "DEBUG — One-player Flash? Pose!",
			"[GODOT-RUNTIME] Debug marker uses the player-facing scenario name"):
		return
	var first_debug_scene_id := current_scene.get_instance_id()
	if not _check(launcher.restart_scenario(), "[AUTO] Debug restart prepares a clean launch snapshot"):
		return
	await scene_changed
	await process_frame
	controller = current_scene.get_node(^"RoundController") as FlashPoseRoundController
	if not _check(current_scene.get_instance_id() != first_debug_scene_id \
			and controller.phase_name() == &"countdown" and controller.player_snapshot().size() == 1,
			"[GODOT-RUNTIME] Debug restart reconstructs the shared scene cleanly"):
		return
	launcher.return_to_lobby()
	await scene_changed
	await process_frame
	if not _check(current_scene.scene_file_path == LOBBY_PATH and launcher.marker_text().is_empty() \
			and host.accepting_new_players and host.running and host.get_instance_id() == host_id,
			"[GODOT-RUNTIME] Debug return clears its marker and preserves the lobby/session"):
		return

	host.stop()
	print("Flash Pose lobby/debug flow checks passed")
	quit(0)


func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
