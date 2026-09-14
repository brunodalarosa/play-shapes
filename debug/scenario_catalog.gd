class_name DebugScenarioCatalog
extends RefCounted
## Central extension point for debug destinations. Lifecycle and UI stay in DebugLauncher.

static func scenarios() -> Array[DebugScenario]:
	return [
		DebugScenario.new(
			&"animation_lab",
			"Hybrid character animation lab",
			"res://debug/character_animation_lab.tscn"
		),
		DebugScenario.new(
			&"one_player_simon",
			"One-player Dancer Simon Says",
			"res://minigames/dancer_simon_says.tscn",
			"registered_player"
		),
	]
