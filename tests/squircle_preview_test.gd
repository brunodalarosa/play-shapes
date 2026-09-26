extends SceneTree
## Focused PS-058 sheet/metadata mapping and preview switching check.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var launcher := root.get_node("DebugLauncher")
	var scenario: DebugScenario = launcher.scenario_for_id(&"squircle_render_preview")
	if not _check(scenario != null and scenario.availability({}).available, "F12 preview is registered and available"):
		return
	var scene := load(scenario.scene_path) as PackedScene
	var preview := scene.instantiate() as Control
	root.add_child(preview)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/experiments/squircle-animation/export/manifest.json"))
	var imported: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://debug/squircle_preview/manifest.json"))
	if not _check(imported.clips.size() == 6, "Six clip/view combinations have metadata"):
		return
	for record: Dictionary in imported.clips:
		var original: Dictionary = {}
		for candidate: Dictionary in source.clips:
			if candidate.name == record.name and candidate.view == record.view:
				original = candidate
				break
		if not _check(not original.is_empty() and record.frames == original.frames and record.fps == original.fps
			and record.anchor_px == original.anchor_px and record.first_frame == 1
			and record.last_frame == original.sequence[-1].frame, "Imported metadata matches source"):
			return
		preview.set("_action", String(record.name))
		preview.set("_view", String(record.view))
		preview.call("_update_selection")
		for frame: int in [0, int(record.frames) - 1]:
			preview.set("_elapsed", float(frame) / float(record.fps))
			preview.call("_update_frame")
			var first: Dictionary = preview.get("_samples")[0]
			var base := first.base as Sprite2D
			var face := first.face as Sprite2D
			if not _check(base.region_rect == face.region_rect and base.region_rect.position == Vector2(frame % 8 * 256, floori(float(frame) / 8.0) * 256)
				and base.position == -Vector2(float(record.anchor_px[0]), float(record.anchor_px[1])), "Frame tiles and source anchor stay aligned"):
				return
	for option: Dictionary in CharacterSelection.COLORS:
		preview.set("_color", option)
		preview.call("_update_selection")
		var first: Dictionary = preview.get("_samples")[0]
		if not _check((first.material as ShaderMaterial).get_shader_parameter("player_color") == Color(String(option.hex))
			and (first.face as Sprite2D).material == null, "Canonical colors tint only the rendered body layer"):
			return
	for expression: String in ["neutral", "blink"]:
		preview.set("_expression", expression)
		preview.call("_update_selection")
		var first: Dictionary = preview.get("_samples")[0]
		if not _check((first.face as Sprite2D).texture == preview.get("_textures")["run-three-quarter-%s" % expression], "Both face sheets switch independently"):
			return
	print("Squircle preview checks passed")
	quit(0)


func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
