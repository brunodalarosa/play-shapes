extends TestScript
## Flappy Race starts from the lobby with one player and with ten, through the Pre-minigame
## screen, while the other minigames keep their minimum, and returns everyone to the lobby.

const LOBBY_PATH := "res://scenes/lobby.tscn"
const PRE_MINIGAME_PATH := "res://scenes/pre_minigame_screen.tscn"
const FLAPPY_RACE_PATH := "res://minigames/006_flappy_race/flappy_race.tscn"


func _run() -> void:
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18110
	host.settings.websocket_port = 18111
	if not check(host.start(false), "Host services start"):
		return

	change_scene_to_file(LOBBY_PATH)
	await scene_changed
	await process_frame

	var players: Array[Dictionary] = [_join(host, 801, "Solo")]
	await process_frame
	if not _check_one_player_rules(host):
		return
	if not await _race_and_return(host, players):
		return

	for index: int in 9:
		players.append(_join(host, 802 + index, "Racer %d" % index))
	await process_frame
	if not check(host.player_registry.player_count() == 10, "The lobby fills to ten players"):
		return
	await _race_and_return(host, players)

	host.stop()


func _check_one_player_rules(host: Node) -> bool:
	var start_button := current_scene.get_node("%StartMinigame") as Button
	var start_help := current_scene.get_node("%StartHelp") as Label
	for minigame_id: StringName in [&"bubbles_3d", &"tilt_shift_3d"]:
		_select(minigame_id)
		if not check(
			start_button.disabled and start_help.text == "At least 2 registered players are needed"
			and not host.minigame_availability(minigame_id).available,
			"One player cannot start %s, with its existing reason" % minigame_id,
		):
			return false

	_select(FlappyRace.ID)
	return check(
		not start_button.disabled and start_help.text == "Ready to start Flappy Race.",
		"One player can start Flappy Race",
	)


## Starts Flappy Race from the lobby, readies every player, checks the race scene, its
## countdown and the phones' protocol, then returns to the lobby.
func _race_and_return(host: Node, players: Array[Dictionary]) -> bool:
	var count := players.size()
	_select(FlappyRace.ID)
	(current_scene.get_node("%StartMinigame") as Button).pressed.emit()
	await scene_changed
	await process_frame
	if not check(
		current_scene.scene_file_path == PRE_MINIGAME_PATH and host.readiness != null,
		"Flappy Race with %d opens the Pre-minigame screen" % count,
	):
		return false

	for joined: Dictionary in players:
		host.readiness.set_ready(joined.player, true)
	await scene_changed
	await process_frame
	var race := current_scene as FlappyRace
	if not check(
		race != null and current_scene.scene_file_path == FLAPPY_RACE_PATH
		and race.participants.size() == count,
		"Flappy Race with %d starts with the whole roster" % count,
	):
		return false

	var protocol: MinigameProtocol = host.websocket._active_protocol
	var snapshot := protocol.snapshot_for(String(players[0].player.player_id))
	if not check(
		protocol is FlappyRaceProtocol and protocol == host.websocket._minigame_protocol
		and snapshot.type == "flappy_race_snapshot" and snapshot.phase == "countdown"
		and snapshot.player_count == count and not host.accepting_new_players,
		"Flappy Race with %d owns the phones' protocol and closes joins" % count,
	):
		return false
	if not check(
		race.controller.racers().size() == count and not snapshot.course.flight.obstacles.is_empty()
		and race.presentation.cue_text() == "3"
		and race.presentation.visual_for(String(players[0].player.player_id)) != null,
		"Flappy Race with %d counts down to a race on a generated course" % count,
	):
		return false

	race.return_button.pressed.emit()
	await scene_changed
	await process_frame
	return check(
		current_scene.scene_file_path == LOBBY_PATH and host.accepting_new_players
		and host.player_registry.player_count() == count
		and host.websocket._active_protocol == null and host.websocket._minigame_protocol == null,
		"Return to lobby after %d keeps every player and clears routing" % count,
	)


func _select(minigame_id: StringName) -> void:
	var selector := current_scene.get_node("%MinigameSelector") as OptionButton
	for index: int in selector.item_count:
		if StringName(selector.get_item_metadata(index)) == minigame_id:
			selector.select(index)
			selector.item_selected.emit(index)
			return


func _join(host: Node, connection_id: int, player_name: String) -> Dictionary:
	return host.player_registry.join_player(
		connection_id,
		player_name,
		host.accepting_new_players,
		Time.get_ticks_msec(),
	)
