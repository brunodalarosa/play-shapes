extends TestScript


func _run() -> void:
	var registry := PlayerRegistry.new(10, 60.0)
	var first: Dictionary = registry.join_player(1, "First", true)
	var second: Dictionary = registry.join_player(2, "Second", true)
	var phase := PreMinigameReadiness.new(&"bubbles", registry.public_players())
	var launches := [0]
	var cancels := [0]
	phase.launch_requested.connect(
		func(_id: StringName, _players: Array[Dictionary]) -> void:
			launches[0] += 1,
	)
	phase.canceled.connect(
		func() -> void:
			cancels[0] += 1,
	)
	var first_snapshot: Dictionary = phase.snapshot_for(String(first.player.player_id))
	check(
		phase.status_players().size() == 2 and not first_snapshot.ready,
		"Initial roster is unready",
	)
	var forged_player := { "player_id": "forged" }
	check(
		not phase.set_ready({ }, true).accepted
		and not phase.set_ready(forged_player, true).accepted,
		"Unknown players cannot change readiness",
	)
	phase.set_ready(first.player, true)
	check(
		phase.snapshot_for(String(first.player.player_id)).ready and launches[0] == 0,
		"One ready player does not launch",
	)
	phase.set_ready(first.player, false)
	check(not phase.snapshot_for(String(first.player.player_id)).ready, "Ready can be canceled")
	phase.set_ready(first.player, true)
	registry.disconnect_connection(1, 100)
	phase.sync_players(registry.public_players())
	check(
		not phase.snapshot_for(String(first.player.player_id)).ready and phase
		.status_players()
		.size()
		== 2,
		"Disconnect keeps the participant but clears ready",
	)
	var resumed: Dictionary = registry.resume_player(
		3,
		registry.session_id,
		first.reconnect_token,
		101,
	)
	phase.sync_players(registry.public_players())
	check(
		resumed.accepted and not phase.snapshot_for(String(first.player.player_id)).ready,
		"Resume retains identity and still needs a new ready action",
	)
	var third: Dictionary = registry.join_player(4, "Third", true)
	check(
		phase.add_joined(third.player) and phase.status_players().size() == 3
		and not phase.snapshot_for(String(third.player.player_id)).ready,
		"Already-open onboarding can enter the roster unready",
	)
	phase.set_ready(first.player, true)
	phase.set_ready(second.player, true)
	check(launches[0] == 0, "A late join blocks all-ready")
	phase.set_ready(third.player, true)
	phase.set_ready(third.player, true)
	check(
		launches[0] == 1 and phase.transitioning and not phase.active,
		"All-ready launches exactly once",
	)
	phase.cancel()
	check(cancels[0] == 0, "Cancellation cannot undo launch")
	var another := PreMinigameReadiness.new(&"bubbles", registry.public_players())
	another.canceled.connect(
		func() -> void:
			cancels[0] += 1,
	)
	another.cancel()
	another.cancel()
	check(cancels[0] == 1, "Host cancellation emits once")
	var empty := PreMinigameReadiness.new(&"bubbles", [])
	check(
		empty.status_players().is_empty() and not empty.set_ready({ }, true).accepted,
		"Empty roster cannot launch",
	)
	var expiring := PreMinigameReadiness.new(
		&"bubbles",
		registry.public_players(),
		func() -> bool:
			return registry.player_count() >= 2,
	)
	registry.disconnect_connection(4, 1000)
	expiring.sync_players(registry.public_players())
	check(
		expiring.status_players().size() == 3,
		"Disconnect retains a round participant during grace",
	)
	registry.expire_players(61000)
	expiring.sync_players(registry.public_players())
	check(expiring.status_players().size() == 2, "Expired identity leaves the selected round")
