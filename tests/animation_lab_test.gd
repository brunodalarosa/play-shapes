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
	var animator := current_scene.get_node("%HybridAnimator") as HybridCharacterAnimator
	var state: PoseCharge = current_scene.charge_state
	state.advance(0.0, &"up")
	state.advance(1.0, &"up")
	animator._update_living_details(0.0)
	if not _check(character.get_node("LeftHand").texture.resource_path.ends_with("blue_hand_rock.png"), "Up uses rock hands"):
		return
	state.advance(0.0, &"right")
	state.advance(1.0, &"right")
	animator._update_living_details(0.0)
	if not _check(character.get_node("RightHand").texture.resource_path.ends_with("blue_hand_open.png"), "Dab uses open hands"):
		return
	var start_hands := animator.dance_hand_shapes_at(0.0)
	if not _check(animator.dance_hand_shapes_at(4.9 / animator.dance_beats_per_second) == start_hands, "Dance hands stay stable for five beats"):
		return
	if not _check(animator.dance_hand_shapes_at(5.1 / animator.dance_beats_per_second) != start_hands, "Dance hands change after five beats"):
		return
	var common_hand_count := animator.DANCE_HANDS.count(&"open") + animator.DANCE_HANDS.count(&"closed")
	if not _check(common_hand_count >= 10, "Open and closed hands dominate the dance sequence"):
		return
	animator.set_jiggle_seed(11011)
	var saw_slow := false
	var returned_to_normal := false
	for unused: int in 400:
		animator._update_jiggle_pattern(0.05)
		if animator.jiggle_is_slow():
			saw_slow = true
		elif saw_slow:
			returned_to_normal = true
	if not _check(saw_slow and returned_to_normal, "Jiggle occasionally slows, then returns to normal"):
		return
	print("Animation lab integration checks passed")
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
