class_name DebugScenarioCatalog
extends RefCounted
## Central extension point for debug destinations. Lifecycle and UI stay in DebugLauncher.


static func scenarios() -> Array[DebugScenario]:
	return [
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
		DebugScenario.new(
			&"one_player_bubbles",
			"One-player Bubbles and Jellyfishes",
			"res://minigames/002_bubbles_and_jellyfishes/bubbles_and_jellyfishes.tscn",
			"one_registered_player",
			&"bubbles",
		),
	]
