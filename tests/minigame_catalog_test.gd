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
		check(minigame.max_players >= 2, "A minigame supports at least two players: %s" % label)
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


func _check_debug_scenarios() -> void:
	var scenarios := DebugScenarioCatalog.scenarios(CATALOG)

	for minigame: MinigameDefinition in CATALOG.minigames:
		var matching := scenarios.filter(
			func(scenario: DebugScenario) -> bool:
				return scenario.minigame_id == minigame.id,
		)

		check(
			matching.size() == (1 if minigame.one_player_debug else 0),
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
