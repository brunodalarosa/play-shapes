extends SceneTree
## Production semantic API, vocabulary, phase, and debug-stage checks for PS-012.

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var launcher := root.get_node("DebugLauncher")
	if not _check(launcher.launch(&"animation_lab"), "Launcher enters the production animation stage"): return
	await scene_changed
	await process_frame
	if not _check(current_scene.scene_file_path == "res://debug/character_animation_system.tscn", "Production animation stage loaded"): return
	if not _check(launcher.marker_text() == "DEBUG — Milestone 1 character animation", "Debug marker identifies the production stage"): return
	if not _check(current_scene.characters.size() == 11 and current_scene.animators.size() == 11, "One lead and ten player characters are instantiated"): return
	var lead: HybridCharacterAnimator = current_scene.animators[0]
	if not _check(lead.semantic_state().is_lead and lead.semantic_state().phase_offset == 0.0, "Lead begins at phase zero"): return
	for index: int in 10:
		var state: Dictionary = current_scene.animators[index + 1].semantic_state()
		if not _check(not state.is_lead and is_equal_approx(state.phase_offset, float(index) / 10.0), "Player %d has an even phase offset" % (index + 1)): return
	var style_targets: Array[Dictionary] = []
	for style: StringName in HybridCharacterAnimator.DANCE_STYLES:
		lead.set_dance_style(style)
		style_targets.append(lead._dance_pose(style, 0))
	if not _check(style_targets[0][&"LeftHand"] != style_targets[1][&"LeftHand"] and style_targets[1][&"LeftHand"] != style_targets[2][&"LeftHand"], "All three loops have distinct authored choreography"): return
	for direction: StringName in HybridCharacterAnimator.DIRECTIONS:
		var canonical := lead._pose_targets(direction)
		if not _check(canonical.size() == 6 and canonical == current_scene.animators[10]._pose_targets(direction), "%s pose is complete and shared across roles" % direction): return
	lead.set_pose_state(&"right", 1.4, true)
	if not _check(lead.semantic_state().pose_charge == 1.0 and lead.semantic_state().pose_held, "Semantic charge is clamped and consumed without evaluating success"): return
	lead.set_pose_state(&"", 0.0, false)
	lead.play_lead_pose_flow(&"left")
	if not _check(not lead._lead_flow_direction.is_empty(), "Lead-only command-pose flow is triggerable while music continues"): return
	current_scene.animators[1].play_lead_pose_flow(&"left")
	if not _check(current_scene.animators[1]._lead_flow_direction.is_empty(), "Player roles cannot invoke lead-only pose flow"): return
	lead.play_reaction(&"life_loss")
	if not _check(lead.semantic_state().reaction == &"life_loss", "Life-loss reaction is triggerable"): return
	lead.play_reaction(&"survived")
	if not _check(lead.semantic_state().reaction == &"survived", "Survival reaction interrupts life loss consistently"): return
	lead.set_result_mood(&"happy")
	if not _check(lead.semantic_state().result_mood == &"happy" and lead.semantic_state().reaction == &"none", "Happy results interrupt transient reactions"): return
	lead.set_result_mood(&"moody")
	if not _check(lead.semantic_state().result_mood == &"moody", "Moody results are triggerable"): return
	lead.set_eliminated(true)
	lead._process(1.0)
	var face := current_scene.characters[0].get_node("Face") as Sprite2D
	if not _check(lead.semantic_state().eliminated and lead.semantic_state().result_mood == &"none" and face.texture == CharacterExpression.FACES[&"sad"], "Elimination overrides motion and persists with a sad face"): return
	lead.play_reaction(&"survived")
	if not _check(lead.semantic_state().reaction == &"none", "Eliminated characters cannot resume reactions"): return
	print("Character animation system checks passed")
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
