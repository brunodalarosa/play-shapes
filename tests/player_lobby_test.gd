extends SceneTree
## Confirms that lobby presentation observes, but does not own, persistent identity.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := root.get_node("SessionHost")
	var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	if not _check(host.accepting_new_players, "Lobby enables new joins"):
		return
	if not _check(lobby.get_node("%PlayerCount").text == "0 / 20 players", "Empty lobby shows player capacity"):
		return

	var joined: Dictionary = host.player_registry.join_player(90, "Lobby Tester", true, 1000)
	await process_frame
	var roster: GridContainer = lobby.get_node("%PlayerRoster")
	if not _check(joined.accepted and roster.get_child_count() == 1, "Joined player appears in the shared roster"):
		return
	if not _check(roster.get_child(0).text == "1. Lobby Tester — Connected", "Roster includes seat, public name, and text state"):
		return
	host.player_registry.disconnect_connection(90, 2000)
	await process_frame
	if not _check(roster.get_child(0).text.ends_with("Reconnecting"), "Disconnect state is visible without color alone"):
		return

	lobby.queue_free()
	await process_frame
	if not _check(not host.accepting_new_players and host.player_registry.player_count() == 1,
			"Leaving the lobby disables new joins but preserves the registry"):
		return
	var replacement: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(replacement)
	await process_frame
	if not _check(replacement.get_node("%PlayerRoster").get_child_count() == 1,
			"A replacement lobby reads the persistent player record"):
		return
	replacement.queue_free()
	host.player_registry.expire_players(62000)
	print("Player lobby checks passed")
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
