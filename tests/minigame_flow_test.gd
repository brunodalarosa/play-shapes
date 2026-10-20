extends TestScript
## Exercises the Bubbles and jellyfishes 3D normal/debug launch, reconnect, and teardown.

const LOBBY_PATH := "res://scenes/lobby.tscn"
const BUBBLES_3D_PATH := "res://minigames/004_3d_bubbles/3d_bubbles.tscn"


func _run() -> void:
	var host := root.get_node("SessionHost")
	var launcher := root.get_node("DebugLauncher")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18088
	host.settings.websocket_port = 18089
	if not check(host.start(false), "Persistent host services start"):
		return
	var host_id := host.get_instance_id()
	host.active_presets.bubbles_3d.instructions_seconds = 0.0
	host.active_presets.bubbles_3d.countdown_seconds = 0.0
	host.active_presets.bubbles_3d.round_duration_seconds = 10.0

	change_scene_to_file(LOBBY_PATH)
	await scene_changed
	await process_frame
	var selector := current_scene.get_node("%MinigameSelector") as OptionButton
	var start_button := current_scene.get_node("%StartMinigame") as Button
	var start_help := current_scene.get_node("%StartHelp") as Label
	if not check(
		selector.item_count == 3 and selector.get_item_text(0) == "Bubbles and jellyfishes 3D"
		and selector.get_item_text(1) == "Tilt Shift 3D"
		and selector.get_item_text(2) == "Tilt Shift",
		"Lobby offers Bubbles and jellyfishes 3D, then Tilt Shift 3D beside Tilt Shift",
	):
		return
	if not check(
		host.minigame_scene_path(&"flash_pose").is_empty()
		and not host.prepare_minigame_launch(&"flash_pose").accepted
		and host.minigame_scene_path(&"bubbles").is_empty()
		and not host.prepare_minigame_launch(&"bubbles").accepted,
		"Retired games cannot launch through the host",
	):
		return
	selector.select(0)
	selector.item_selected.emit(0)
	if not check(
		start_button.disabled and start_help.text.contains("At least 2"),
		"Selected Bubbles 3D blocks launch at zero players with actionable copy",
	):
		return
	var rejected: Dictionary = host.prepare_minigame_launch(&"bubbles_3d")
	if not check(
		not rejected.accepted and host.accepting_new_players,
		"The host rechecks and rejects a direct one-player normal launch",
	):
		return

	var first := _join(host, 501, "First")
	await process_frame
	if not check(
		first.accepted and start_button.disabled,
		"One real player still cannot use the normal Bubbles 3D launch",
	):
		return
	var bubbles_debug: DebugScenario = launcher.scenario_for_id(&"one_player_bubbles_3d")
	var debug_features := { "one_registered_player": true }
	if not check(
		bubbles_debug != null and bubbles_debug.availability(debug_features).available,
		"F12 offers Bubbles 3D only through its explicit one-player scenario",
	):
		return
	if not check(
		launcher.launch(&"one_player_bubbles_3d"),
		"F12 starts the one-player Bubbles 3D scenario",
	):
		return
	await scene_changed
	await process_frame
	var presentation := current_scene as Bubbles3DPresentation
	var bubble_controller := current_scene.get_node("RoundController") as Bubbles3DRoundController
	if not check(
		current_scene.scene_file_path == BUBBLES_3D_PATH and bubble_controller.is_one_player_debug()
		and bubble_controller.player_snapshot().size() == 1,
		"Bubbles 3D debug uses the same round scene with one registered player",
	):
		return
	if not check(
		launcher.marker_text() == "DEBUG — One-player Bubbles and jellyfishes 3D"
		and presentation.get_node("Hud/DebugLabel").visible,
		"F12 and the shared screen clearly label the debug round",
	):
		return
	if not check(
		host.websocket._active_protocol == host.websocket._minigame_protocol
		and host.websocket._minigame_protocol.controller == bubble_controller,
		"Bubbles 3D is the only active phone protocol",
	):
		return
	var first_debug_scene_id := current_scene.get_instance_id()
	if not check(launcher.restart_scenario(), "Bubbles 3D debug can restart from F12"):
		return
	await scene_changed
	await process_frame
	bubble_controller = current_scene.get_node("RoundController") as Bubbles3DRoundController
	if not check(
		current_scene.get_instance_id() != first_debug_scene_id
		and bubble_controller.is_one_player_debug()
		and host.websocket._minigame_protocol.controller == bubble_controller,
		"Debug restart replaces the controller and protocol snapshot cleanly",
	):
		return
	launcher.return_to_lobby()
	await scene_changed
	await process_frame
	if not check(
		current_scene.scene_file_path == LOBBY_PATH and launcher.marker_text().is_empty()
		and host.accepting_new_players and host.running and host.get_instance_id() == host_id
		and host.player_registry.player_count() == 1 and host.websocket._active_protocol == null
		and host.websocket._minigame_protocol == null,
		"Debug return clears Bubbles 3D routing and preserves the lobby, player, and services",
	):
		return

	selector = current_scene.get_node("%MinigameSelector") as OptionButton
	start_button = current_scene.get_node("%StartMinigame") as Button
	start_help = current_scene.get_node("%StartHelp") as Label
	selector.select(0)
	selector.item_selected.emit(0)
	var overflow_connections: Array[int] = []
	for index: int in 9:
		var connection_id := 600 + index
		var overflow := _join(host, connection_id, "Extra %d" % index)
		if not check(overflow.accepted, "Lobby fills to ten registered players"):
			return
		overflow_connections.append(connection_id)
	await process_frame
	if not check(
		host.player_registry.player_count() == 10 and not start_button.disabled
		and host.minigame_availability(&"bubbles_3d").available,
		"Full ten-player lobby can launch Bubbles 3D",
	):
		return
	if not check(
		host.player_registry.join_player(700, "Eleventh", true).code == &"full",
		"Host rejects an eleventh new player",
	):
		return
	for connection_id: int in overflow_connections:
		host.player_registry.leave_connection(connection_id)
	await process_frame
	var second := _join(host, 502, "Second")
	await process_frame
	if not check(
		second.accepted and not start_button.disabled,
		"Two registered players unlock normal Bubbles 3D",
	):
		return
	var first_id := String(first.player.player_id)
	var first_token := String(first.reconnect_token)
	start_button.pressed.emit()
	await scene_changed
	await process_frame
	if not check(
		current_scene.scene_file_path == "res://scenes/pre_minigame_screen.tscn"
		and host.readiness != null and host.websocket._active_protocol == host.readiness,
		"Normal Bubbles 3D opens host-owned ready-up before gameplay",
	):
		return
	host.cancel_pre_minigame()
	await scene_changed
	await process_frame
	if not check(
		current_scene.scene_file_path == LOBBY_PATH and host.readiness == null
		and host.accepting_new_players and host.player_registry.player_count() == 2,
		"Host cancel returns to joining lobby with both players intact",
	):
		return
	selector = current_scene.get_node("%MinigameSelector") as OptionButton
	selector.select(0)
	selector.item_selected.emit(0)
	(current_scene.get_node("%StartMinigame") as Button).pressed.emit()
	await scene_changed
	await process_frame
	host.readiness.set_ready(first.player, true)
	if not check(
		current_scene.scene_file_path == "res://scenes/pre_minigame_screen.tscn",
		"One ready player cannot start gameplay",
	):
		return
	host.readiness.set_ready(second.player, true)
	await scene_changed
	await process_frame
	bubble_controller = current_scene.get_node("RoundController") as Bubbles3DRoundController
	if not check(
		current_scene.scene_file_path == BUBBLES_3D_PATH
		and bubble_controller.phase_name() == &"instructions"
		and bubble_controller.player_snapshot().size() == 2,
		"The selected Bubbles 3D round starts with the registered roster snapshot",
	):
		return
	if not check(
		host.websocket._active_protocol == host.websocket._minigame_protocol
		and not host.accepting_new_players,
		"Bubbles 3D launch disables joins and owns gameplay routing",
	):
		return
	host.player_registry.disconnect_connection(501)
	await process_frame
	if not check(
		not bool(bubble_controller.personal_snapshot(first_id).connected),
		"Bubbles 3D observes the registered player's disconnect",
	):
		return
	var resumed: Dictionary = host.player_registry.resume_player(
		503,
		host.player_registry.session_id,
		first_token,
	)
	await process_frame
	if not check(
		resumed.accepted and bool(bubble_controller.personal_snapshot(first_id).connected),
		"Reconnect restores the same Bubbles 3D participant and identity",
	):
		return
	var left: Dictionary = host.player_registry.leave_connection(502)
	await process_frame
	var second_id := String(second.player.player_id)
	if not check(
		left.accepted and bool(bubble_controller.personal_snapshot(second_id).left),
		"Explicit phone leave is observed by the active Bubbles 3D controller",
	):
		return
	(current_scene as Bubbles3DPresentation)._entrance_tween.kill()
	for frame: int in 180:
		if bubble_controller.phase_name() == &"active":
			break
		await process_frame
	if not check(
		bubble_controller.phase_name() == &"active",
		"Bubbles 3D presentation reaches active play",
	):
		return
	bubble_controller.advance(
		maxi(Time.get_ticks_msec(), bubble_controller.last_host_time_msec()) + 300000
	)
	await process_frame
	var bubbles_return := current_scene.find_child("ReturnToLobby", true, false) as Button
	if not check(
		bubble_controller.phase_name() == &"results"
		and bubbles_return != null and bubbles_return.visible,
		"Bubbles 3D results expose the host-only lobby return",
	):
		return
	bubbles_return.pressed.emit()
	await scene_changed
	await process_frame
	if not check(
		current_scene.scene_file_path == LOBBY_PATH and host.accepting_new_players
		and host.player_registry.player_count() == 1 and host.running
		and host.get_instance_id() == host_id and host.websocket._active_protocol == null
		and host.websocket._minigame_protocol == null,
		"Bubbles 3D results return resets phones and tears down routing without losing the host",
	):
		return

	selector = current_scene.get_node("%MinigameSelector") as OptionButton
	start_button = current_scene.get_node("%StartMinigame") as Button
	var fourth := _join(host, 505, "Fourth")
	await process_frame
	selector.select(0)
	selector.item_selected.emit(0)
	if not check(
		fourth.accepted and not start_button.disabled,
		"Bubbles 3D can start again after returning to the lobby",
	):
		return
	start_button.pressed.emit()
	await scene_changed
	await process_frame
	if not check(
		current_scene.scene_file_path == "res://scenes/pre_minigame_screen.tscn",
		"Second normal launch also visits ready-up",
	):
		return
	host.readiness.set_ready(first.player, true)
	host.readiness.set_ready(fourth.player, true)
	await scene_changed
	await process_frame
	bubble_controller = current_scene.get_node("RoundController") as Bubbles3DRoundController
	if not check(
		current_scene.scene_file_path == BUBBLES_3D_PATH
		and host.websocket._active_protocol == host.websocket._minigame_protocol,
		"Repeated Bubbles 3D launch leaves exactly one protocol active",
	):
		return
	(current_scene as Bubbles3DPresentation)._entrance_tween.kill()
	for frame: int in 180:
		if bubble_controller.phase_name() == &"active":
			break
		await process_frame
	if not check(
		bubble_controller.phase_name() == &"active",
		"Second Bubbles 3D round reaches active play",
	):
		return
	bubble_controller.advance(
		maxi(Time.get_ticks_msec(), bubble_controller.last_host_time_msec()) + 300000
	)
	await process_frame
	bubbles_return = current_scene.find_child("ReturnToLobby", true, false) as Button
	if not check(
		bubbles_return != null and bubbles_return.visible,
		"Second Bubbles 3D round reaches results",
	):
		return
	bubbles_return.pressed.emit()
	await scene_changed
	await process_frame
	if not check(
		current_scene.scene_file_path == LOBBY_PATH
		and host.websocket._active_protocol == null and host.websocket._minigame_protocol == null
		and host.running and host.get_instance_id() == host_id,
		"Repeated switching leaves no stale controller and keeps the same host alive",
	):
		return

	host.stop()


func _join(host: Node, connection_id: int, player_name: String) -> Dictionary:
	return host.player_registry.join_player(
		connection_id,
		player_name,
		host.accepting_new_players,
		Time.get_ticks_msec(),
	)
