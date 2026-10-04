class_name DebugScenarioCatalog
extends RefCounted
## Central extension point for debug destinations. Lifecycle and UI stay in DebugLauncher.


## The labs, then a one-player round of each minigame that offers one.
static func scenarios(minigames: MinigameCatalog) -> Array[DebugScenario]:
	var result: Array[DebugScenario] = [
		DebugScenario.new(
			&"motion_lab",
			"Gyroscope and Accelerometer Lab",
			"res://debug/motion_lab/motion_lab.tscn",
		),
		DebugScenario.new(
			&"squircle_animation_lab",
			"Animation Lab",
			"res://debug/animation_lab/animation_lab.tscn",
		),
	]

	for minigame: MinigameDefinition in minigames.minigames:
		if not minigame.one_player_debug:
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
