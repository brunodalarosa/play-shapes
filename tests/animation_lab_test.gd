extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var launcher := root.get_node("DebugLauncher")
	var scenario: DebugScenario = launcher.scenario_for_id(&"animation_lab")
	if not _check(scenario != null and scenario.availability({}).available, "Animation lab is available through the launcher"):
		return
	if not _check(launcher.launch(&"animation_lab"), "Launcher enters the animation lab"):
		return
	await scene_changed
	await process_frame
	if not _check(current_scene.scene_file_path == "res://debug/character_animation_lab.tscn", "Animation lab scene loaded"):
		return
	if not _check(launcher.marker_text() == "DEBUG — Hybrid character animation lab", "Debug marker identifies the lab"):
		return
	var character := current_scene.get_node("%Character") as ShapeCharacter
	if not _check(character != null and character.get_child_count() == 6, "Tintable six-part character remains intact"):
		return
	for direction: StringName in [&"up", &"left", &"right", &"down"]:
		var targets: Dictionary = current_scene.get_node("%HybridAnimator")._pose_targets(direction)
		if not _check(targets.size() == 6, "%s pose defines all character parts" % direction):
			return
	print("Animation lab integration checks passed")
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
