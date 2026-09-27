extends SceneTree
## The registry remains authoritative while the Playground lobby shows no roster.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := root.get_node("SessionHost")
	var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	var start := lobby.get_node("%StartMinigame") as Button
	var help := lobby.get_node("%StartHelp") as Label
	if not _check(host.accepting_new_players and start.disabled and help.text.contains("At least 2"),
			"Empty lobby accepts joins and explains start availability"):
		return
	if not _check(lobby.find_child("PlayerRoster", true, false) == null
			and lobby.find_child("PlayerCount", true, false) == null
			and lobby.find_child("EmptyRoster", true, false) == null,
			"Playground presentation contains no player list"):
		return

	var first: Dictionary = host.player_registry.join_player(90, "First", true, 1000)
	await process_frame
	if not _check(first.accepted and start.disabled, "One registered player cannot start"):
		return
	var second: Dictionary = host.player_registry.join_player(91, "Second", true, 1001)
	await process_frame
	if not _check(second.accepted and not start.disabled and help.text.contains("Ready"),
			"Second join refreshes start availability"):
		return
	host.player_registry.disconnect_connection(90, 2000)
	await process_frame
	if not _check(host.player_registry.player_count() == 2 and not start.disabled,
			"Reconnect grace retains the registered player and availability"):
		return
	var resumed: Dictionary = host.player_registry.resume_player(
		92, host.player_registry.session_id, first.reconnect_token, 2001)
	await process_frame
	if not _check(resumed.accepted and not start.disabled, "Resume preserves availability"):
		return
	host.player_registry.leave_connection(91)
	await process_frame
	if not _check(start.disabled and help.text.contains("At least 2"),
			"Leaving updates availability without a roster"):
		return

	lobby.queue_free()
	await process_frame
	if not _check(not host.accepting_new_players and host.player_registry.player_count() == 1,
			"Leaving lobby disables joins but preserves player data"):
		return
	var replacement: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(replacement)
	await process_frame
	if not _check(host.accepting_new_players and (replacement.get_node("%StartMinigame") as Button).disabled,
			"Replacement lobby reads persistent player data"):
		return
	replacement.queue_free()
	print("Player lobby checks passed")
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
