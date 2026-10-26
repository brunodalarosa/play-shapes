extends TestScript
## Every minigame in the catalog names things that exist, so that a wrong path fails here
## and not when the minigame is started.

const CATALOG: MinigameCatalog = preload("res://minigames/catalog.tres")


func _run() -> void:
	check(not CATALOG.minigames.is_empty(), "The catalog lists at least one minigame")

	var ids: Array[StringName] = []

	for minigame: MinigameDefinition in CATALOG.minigames:
		var label := "%s (%s)" % [minigame.display_name, minigame.id]

		check(not minigame.id.is_empty(), "A minigame has an id: %s" % label)
		check(minigame.id not in ids, "No two minigames share an id: %s" % label)
		ids.append(minigame.id)

		check(not minigame.display_name.is_empty(), "A minigame has a name: %s" % label)
		check(
			ResourceLoader.exists(minigame.scene_path, "PackedScene"),
			"A minigame's scene exists: %s" % label,
		)
		check(
			minigame.load_pre_minigame_content() != null,
			"A minigame's ready-screen content loads: %s" % label,
		)
		check(
			1 <= minigame.min_players and minigame.min_players <= minigame.max_players,
			"A minigame's fewest players fit under its most: %s" % label,
		)
		check(
			not (minigame.one_player_debug and minigame.min_players == 1),
			"A minigame that starts with one player offers no one-player debug: %s" % label,
		)
		check(CATALOG.find(minigame.id) == minigame, "The catalog finds it by id: %s" % label)

	check(CATALOG.find(&"no_such_minigame") == null, "An unknown id finds nothing")

	_check_session_host()
	_check_debug_scenarios()


func _check_session_host() -> void:
	var host := root.get_node("SessionHost")
	var first := CATALOG.minigames[0]

	check(host.minigame_scene_path(first.id) == first.scene_path, "The host knows a scene by id")
	check(host.minigame_display_name(first.id) == first.display_name, "The host knows a name by id")
	check(host.minigame_scene_path(&"no_such_minigame").is_empty(), "An unknown id has no scene")
	check(
		not host.minigame_availability(&"no_such_minigame").available,
		"An unknown id is not available",
	)

	_check_fewest_players(host)


## A minigame's own minimum gates a normal launch; the others keep theirs.
func _check_fewest_players(host: Node) -> void:
	var solo := MinigameDefinition.new()
	solo.id = &"solo_fixture"
	solo.display_name = "Solo fixture"
	solo.min_players = 1
	host.minigame_catalog.minigames.append(solo)

	var empty: Dictionary = host.minigame_availability(solo.id)
	check(
		not empty.available and empty.reason == "At least 1 registered player is needed",
		"A one-player minigame still needs a registered player",
	)

	var joined: Dictionary = host.player_registry.join_player(950, "Solo", true, 1000)
	check(
		joined.accepted and host.minigame_availability(solo.id).available,
		"One registered player can launch a minigame whose minimum is one",
	)
	for minigame: MinigameDefinition in CATALOG.minigames:
		if minigame.min_players < 2:
			continue

		var availability: Dictionary = host.minigame_availability(minigame.id)
		check(
			not availability.available
			and availability.reason == "At least 2 registered players are needed",
			"One registered player still cannot launch %s" % minigame.display_name,
		)

	host.player_registry.leave_connection(950)
	host.minigame_catalog.minigames.erase(solo)


func _check_debug_scenarios() -> void:
	var scenarios := DebugScenarioCatalog.scenarios(CATALOG)

	for minigame: MinigameDefinition in CATALOG.minigames:
		var matching := scenarios.filter(
			func(scenario: DebugScenario) -> bool:
				return scenario.minigame_id == minigame.id,
		)

		check(
			matching.size() == (1 if minigame.one_player_debug and minigame.min_players > 1 else 0),
			"A minigame has a one-player debug scenario only when it offers one: %s" % minigame.id,
		)

		if matching.is_empty():
			continue

		var scenario: DebugScenario = matching[0]
		check(scenario.scene_path == minigame.scene_path, "The scenario opens the minigame's scene")
		check(
			scenario.display_name == "One-player %s" % minigame.display_name,
			"The scenario is named after the minigame",
		)
