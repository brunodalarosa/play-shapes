extends SceneTree
## Exercises lobby selection, normal/debug launch, teardown, and both directions of game switching.

const LOBBY_PATH := "res://scenes/lobby.tscn"
const BUBBLES_PATH := "res://minigames/bubbles_and_jellyfishes.tscn"
const FLASH_POSE_PATH := "res://minigames/dancer_simon_says.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := root.get_node("SessionHost")
	var launcher := root.get_node("DebugLauncher")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18088
	host.settings.websocket_port = 18089
	if not _check(host.start(), "Persistent host services start"):
		return
	var host_id := host.get_instance_id()
	host.active_presets.simon_says.countdown_seconds = 0.0
	host.active_presets.bubbles.instructions_seconds = 0.0
	host.active_presets.bubbles.countdown_seconds = 0.0
	host.active_presets.bubbles.round_duration_seconds = 10.0

	change_scene_to_file(LOBBY_PATH)
	await scene_changed
	await process_frame
	var selector := current_scene.get_node("%MinigameSelector") as OptionButton
	var start_button := current_scene.get_node("%StartMinigame") as Button
	var start_help := current_scene.get_node("%StartHelp") as Label
	if not _check(selector.item_count == 2 and selector.get_item_text(1) == "Bubbles and Jellyfishes",
			"Lobby offers Flash? Pose! and Bubbles and Jellyfishes"):
		return
	selector.select(1)
	selector.item_selected.emit(1)
	if not _check(start_button.disabled and start_help.text.contains("At least 2"),
			"Selected Bubbles blocks launch at zero players with actionable copy"):
		return
	var rejected: Dictionary = host.prepare_minigame_launch(&"bubbles")
	if not _check(not rejected.accepted and host.accepting_new_players,
			"The host rechecks and rejects a direct one-player normal launch"):
		return

	var first := _join(host, 501, "First")
	await process_frame
	if not _check(first.accepted and start_button.disabled,
			"One real player still cannot use the normal Bubbles launch"):
		return
	var bubbles_debug: DebugScenario = launcher.scenario_for_id(&"one_player_bubbles")
	if not _check(bubbles_debug != null and bubbles_debug.availability(
			{"one_registered_player": true}).available,
			"F12 offers Bubbles only through its explicit one-player scenario"):
		return
	if not _check(launcher.launch(&"one_player_bubbles"), "F12 starts the one-player Bubbles scenario"):
		return
	await scene_changed
	await process_frame
	var presentation := current_scene as BubblesPresentation
	var bubble_controller := current_scene.get_node("RoundController") as BubblesRoundController
	if not _check(current_scene.scene_file_path == BUBBLES_PATH and bubble_controller.is_one_player_debug()
			and bubble_controller.player_snapshot().size() == 1,
			"Bubbles debug uses the same round scene with one registered player"):
		return
	if not _check(launcher.marker_text() == "DEBUG — One-player Bubbles and Jellyfishes"
			and presentation.get_node("Hud/DebugLabel").visible,
			"F12 and the shared screen clearly label the debug round"):
		return
	if not _check(host.websocket._active_protocol == host.websocket._bubbles_protocol
			and host.websocket._bubbles_protocol.controller == bubble_controller,
			"Bubbles is the only active phone protocol"):
		return
	var first_debug_scene_id := current_scene.get_instance_id()
	if not _check(launcher.restart_scenario(), "Bubbles debug can restart from F12"):
		return
	await scene_changed
	await process_frame
	bubble_controller = current_scene.get_node("RoundController") as BubblesRoundController
	if not _check(current_scene.get_instance_id() != first_debug_scene_id
			and bubble_controller.is_one_player_debug()
			and host.websocket._bubbles_protocol.controller == bubble_controller,
			"Debug restart replaces the controller and protocol snapshot cleanly"):
		return
	launcher.return_to_lobby()
	await scene_changed
	await process_frame
	if not _check(current_scene.scene_file_path == LOBBY_PATH and launcher.marker_text().is_empty()
			and host.accepting_new_players and host.running and host.get_instance_id() == host_id
			and host.player_registry.player_count() == 1
			and host.websocket._active_protocol == null and host.websocket._bubbles_protocol == null,
			"Debug return clears Bubbles routing and preserves the lobby, player, and services"):
		return

	selector = current_scene.get_node("%MinigameSelector") as OptionButton
	start_button = current_scene.get_node("%StartMinigame") as Button
	start_help = current_scene.get_node("%StartHelp") as Label
	selector.select(1)
	selector.item_selected.emit(1)
	var overflow_connections: Array[int] = []
	for index: int in 10:
		var connection_id := 600 + index
		var overflow := _join(host, connection_id, "Extra %d" % index)
		if not _check(overflow.accepted, "Lobby retains its 20-player capacity"):
			return
		overflow_connections.append(connection_id)
	await process_frame
	if not _check(start_button.disabled and start_help.text.contains("supports up to 10 players"),
			"Selected minigame blocks an 11-player launch with an actionable maximum"):
		return
	for connection_id: int in overflow_connections:
		host.player_registry.leave_connection(connection_id)
	await process_frame
	var second := _join(host, 502, "Second")
	await process_frame
	if not _check(second.accepted and not start_button.disabled,
			"Two registered players unlock normal Bubbles"):
		return
	var first_id := String(first.player.player_id)
	var first_token := String(first.reconnect_token)
	start_button.pressed.emit()
	await scene_changed
	await process_frame
	bubble_controller = current_scene.get_node("RoundController") as BubblesRoundController
	if not _check(current_scene.scene_file_path == BUBBLES_PATH
			and bubble_controller.phase_name() == &"instructions"
			and bubble_controller.player_snapshot().size() == 2,
			"The selected Bubbles round starts with the registered roster snapshot"):
		return
	if not _check(host.websocket._active_protocol == host.websocket._bubbles_protocol
			and host.websocket._flash_pose_protocol == null and not host.accepting_new_players,
			"Bubbles launch disables joins and excludes Flash? Pose! routing"):
		return
	host.player_registry.disconnect_connection(501)
	await process_frame
	if not _check(not bool(bubble_controller.personal_snapshot(first_id).connected),
			"Bubbles observes the registered player's disconnect"):
		return
	var resumed: Dictionary = host.player_registry.resume_player(503, host.player_registry.session_id, first_token)
	await process_frame
	if not _check(resumed.accepted and bool(bubble_controller.personal_snapshot(first_id).connected),
			"Reconnect restores the same Bubbles participant and identity"):
		return
	var left: Dictionary = host.player_registry.leave_connection(502)
	await process_frame
	if not _check(left.accepted and bool(bubble_controller.personal_snapshot(
			String(second.player.player_id)).left),
			"Explicit phone leave is observed by the active Bubbles controller"):
		return
	for frame: int in 180:
		if bubble_controller.phase_name() == &"active":
			break
		await process_frame
	if not _check(bubble_controller.phase_name() == &"active", "Bubbles presentation reaches active play"):
		return
	bubble_controller.advance(maxi(Time.get_ticks_msec(), bubble_controller.last_host_time_msec()) + 300000)
	await process_frame
	var bubbles_return := current_scene.find_child("ReturnToLobby", true, false) as Button
	if not _check(bubble_controller.phase_name() == &"results" and bubbles_return != null
			and bubbles_return.visible,
			"Bubbles results expose the host-only lobby return"):
		return
	bubbles_return.pressed.emit()
	await scene_changed
	await process_frame
	if not _check(current_scene.scene_file_path == LOBBY_PATH and host.accepting_new_players
			and host.player_registry.player_count() == 1 and host.running
			and host.get_instance_id() == host_id and host.websocket._active_protocol == null
			and host.websocket._bubbles_protocol == null,
			"Bubbles results return resets phones and tears down routing without losing the host"):
		return

	selector = current_scene.get_node("%MinigameSelector") as OptionButton
	start_button = current_scene.get_node("%StartMinigame") as Button
	var third := _join(host, 504, "Third")
	await process_frame
	selector.select(0)
	selector.item_selected.emit(0)
	if not _check(third.accepted and not start_button.disabled, "Flash? Pose! remains selectable after Bubbles"):
		return
	start_button.pressed.emit()
	await scene_changed
	await process_frame
	var flash_controller := current_scene.get_node("RoundController") as FlashPoseRoundController
	if not _check(current_scene.scene_file_path == FLASH_POSE_PATH
			and flash_controller.player_snapshot().size() == 2
			and host.websocket._active_protocol == host.websocket._flash_pose_protocol
			and host.websocket._bubbles_protocol == null,
			"The selected Flash? Pose! round replaces Bubbles routing"):
		return
	flash_controller.advance(Time.get_ticks_msec())
	host.player_registry.leave_connection(504)
	await process_frame
	var flash_return := current_scene.find_child("ReturnToLobby", true, false) as Button
	if not _check(flash_controller.phase_name() == &"results_wait" and flash_return != null
			and flash_return.visible,
			"Flash? Pose! keeps its explicit-leave results and host return"):
		return
	flash_return.pressed.emit()
	await scene_changed
	await process_frame
	if not _check(current_scene.scene_file_path == LOBBY_PATH and host.websocket._active_protocol == null
			and host.websocket._flash_pose_protocol == null and host.running,
			"Flash? Pose! return clears its protocol and preserves LAN services"):
		return

	selector = current_scene.get_node("%MinigameSelector") as OptionButton
	start_button = current_scene.get_node("%StartMinigame") as Button
	var fourth := _join(host, 505, "Fourth")
	await process_frame
	selector.select(1)
	selector.item_selected.emit(1)
	if not _check(fourth.accepted and not start_button.disabled, "Bubbles can be selected again after Flash? Pose!"):
		return
	start_button.pressed.emit()
	await scene_changed
	await process_frame
	bubble_controller = current_scene.get_node("RoundController") as BubblesRoundController
	if not _check(current_scene.scene_file_path == BUBBLES_PATH
			and host.websocket._active_protocol == host.websocket._bubbles_protocol
			and host.websocket._flash_pose_protocol == null,
			"Switching back to Bubbles leaves exactly one protocol active"):
		return
	for frame: int in 180:
		if bubble_controller.phase_name() == &"active":
			break
		await process_frame
	if not _check(bubble_controller.phase_name() == &"active", "Second Bubbles round reaches active play"):
		return
	bubble_controller.advance(maxi(Time.get_ticks_msec(), bubble_controller.last_host_time_msec()) + 300000)
	await process_frame
	bubbles_return = current_scene.find_child("ReturnToLobby", true, false) as Button
	if not _check(bubbles_return != null and bubbles_return.visible, "Second Bubbles round reaches results"):
		return
	bubbles_return.pressed.emit()
	await scene_changed
	await process_frame
	if not _check(current_scene.scene_file_path == LOBBY_PATH
			and host.websocket._active_protocol == null and host.websocket._bubbles_protocol == null
			and host.running and host.get_instance_id() == host_id,
			"Repeated switching leaves no stale controller and keeps the same host alive"):
		return

	host.stop()
	print("[GODOT-RUNTIME] Complete minigame selection and switching flow checks passed")
	quit(0)


func _join(host: Node, connection_id: int, player_name: String) -> Dictionary:
	return host.player_registry.join_player(connection_id, player_name,
		host.accepting_new_players, Time.get_ticks_msec())


func _check(condition: bool, description: String) -> bool:
	if condition:
		return true
	push_error(description)
	quit(1)
	return false
