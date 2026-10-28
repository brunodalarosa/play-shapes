class_name DebugScenarioCatalog
extends RefCounted
## Central extension point for debug destinations. Lifecycle and UI stay in DebugLauncher.


## The labs, then a one-player round of each minigame that offers one and needs more players
## to launch normally.
static func scenarios(minigames: MinigameCatalog) -> Array[DebugScenario]:
	var result: Array[DebugScenario] = [
		DebugScenario.new(
			&"flappy_race_workshop",
			"Flappy Race workshop",
			"res://minigames/006_flappy_race/workshop/flappy_race_workshop.tscn",
		),
		DebugScenario.new(
			&"tilt_shift_3d_review",
			"Tilt Shift 3D factory · simulated controls",
			"res://debug/tilt_shift_3d_review.tscn",
		),
		DebugScenario.new(
			&"shape_characters_lab",
			"Shape Characters lab",
			"res://debug/shape_characters_lab/shape_characters_lab.tscn",
		),
		DebugScenario.new(
			&"motion_lab",
			"Gyroscope and Accelerometer Lab",
			"res://debug/motion_lab/motion_lab.tscn",
		),
	]

	for minigame: MinigameDefinition in minigames.minigames:
		# A minigame that starts with one player normally needs no debug round for it.
		if not minigame.one_player_debug or minigame.min_players <= 1:
			continue

		result.append(
			DebugScenario.new(
				StringName("one_player_%s" % minigame.id),
				"One-player %s" % minigame.display_name,
				minigame.scene_path,
				"one_registered_player",
				minigame.id,
			),
		)

	return result
