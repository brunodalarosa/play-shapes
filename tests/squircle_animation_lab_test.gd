extends SceneTree
## Focused PS-065 manifest, scene, and playback checks.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var launcher := root.get_node("DebugLauncher")
	var scenario: DebugScenario = launcher.scenario_for_id(&"squircle_animation_lab")
	if not _check(scenario != null and scenario.display_name == "Animation Lab"
		and scenario.availability({}).available, "Animation Lab has its own F12 entry"):
		return
	if not _check(launcher.scenario_for_id(&"squircle_render_preview") != null,
		"Rendered comparison remains available"):
		return
	var lab := (load(scenario.scene_path) as PackedScene).instantiate() as Control
	root.add_child(lab)
	var samples: Array = lab.get("_samples")
	if not _check(samples.size() == 2 and samples[0].scale == Vector2.ONE
		and samples[1].scale == Vector2.ONE * 0.5, "Both reference sizes are shown"):
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/runtime/animated_characters/squircle/v1/manifest.json"))
	if not _check(manifest.clips.size() == 6 and lab.get("_clips").size() == 6,
		"All six approved clip/view pairs are available"):
		return
	for clip: Dictionary in manifest.clips:
		lab.set("_action", String(clip.name))
		lab.set("_view", String(clip.view))
		lab.call("_update_selection")
		if not _check(lab.get("_elapsed") == 0.0
			and "%d frames" % int(clip.frames) in String(lab.get("_info").text)
			and "%d fps" % int(clip.fps) in String(lab.get("_info").text),
			"Selection resets and metadata uses the manifest"):
			return
		for frame: int in [0, int(clip.frames) - 1, int(clip.frames)]:
			lab.set("_elapsed", float(frame) / float(clip.fps))
			lab.call("_update_frame")
			var effective := frame % int(clip.frames)
			var tile := Rect2(effective % int(clip.sheet_columns) * 256,
				floori(float(effective) / float(clip.sheet_columns)) * 256, 256, 256)
			for sample: SquircleRenderedSample in samples:
				if not _check(sample.base.region_rect == tile and sample.face.region_rect == tile
					and sample.base.position == -Vector2(float(clip.anchor_px[0]), float(clip.anchor_px[1]))
					and sample.face.position == sample.base.position,
					"Both layers loop on the same manifest tile and anchor"):
					return
		if not _check(samples[0].base.texture == samples[1].base.texture,
			"Both sizes show the same approved sheet"):
			return
	for color: Dictionary in CharacterSelection.COLORS:
		lab.set("_color", color)
		lab.call("_update_selection")
		if not _check(samples[0].tint_material.get_shader_parameter("player_color")
			== Color(String(color.hex)) and samples[0].face.material == null,
			"Player color tints only the body layer"):
			return
	for expression: String in ["neutral", "blink"]:
		lab.set("_expression", expression)
		lab.call("_update_selection")
		if not _check(samples[0].face.texture.resource_path.ends_with("-%s.png" % expression)
			and samples[1].face.texture == samples[0].face.texture,
			"Both sizes switch face independently of tint"):
			return
	lab.set("_elapsed", 0.25)
	lab.call("_toggle_play")
	lab.call("_process", 0.5)
	if not _check(lab.get("_elapsed") == 0.25 and not lab.get("_playing"),
		"Pause holds the selected frame"):
		return
	lab.call("_toggle_play")
	lab.call("_process", 0.5)
	if not _check(lab.get("_elapsed") == 0.75 and lab.get("_playing"),
		"Play resumes from the held frame"):
		return
	if not _check(not _contains_legacy_character(lab), "Lab contains no legacy ShapeCharacter"):
		return
	print("Animation Lab checks passed")
	quit(0)


func _contains_legacy_character(node: Node) -> bool:
	if node is ShapeCharacter:
		return true
	for child: Node in node.get_children():
		if _contains_legacy_character(child):
			return true
	return false


func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
