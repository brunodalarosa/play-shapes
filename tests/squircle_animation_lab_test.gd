extends SceneTree
## Focused Squircle Animation Lab manifest, scene, and playback checks.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var launcher := root.get_node("DebugLauncher")
	var scenario: DebugScenario = launcher.scenario_for_id(&"squircle_animation_lab")
	if not _check(scenario != null and scenario.display_name == "Animation Lab"
		and scenario.availability({}).available, "Animation Lab has its own F12 entry"):
		return
	if not _check(launcher.scenario_for_id(&"squircle_render_preview") == null,
		"Retired comparison is absent"):
		return
	var lab := (load(scenario.scene_path) as PackedScene).instantiate() as Control
	root.add_child(lab)
	var samples: Array = lab.get("_samples")
	if not _check(samples.size() == 3 and samples[0].scale == Vector2.ONE
		and samples[1].scale == Vector2.ONE * 0.5
		and samples[2].scale.is_equal_approx(Vector2.ONE * 0.58), "Reference and actual lobby sizes are shown"):
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/runtime/animated_characters/squircle/v1/manifest.json"))
	if not _check(manifest.clips.size() == 10 and lab.get("_clips").size() == manifest.clips.size()
		and lab.get("_actions").has("look_up") and lab.get("_actions").has("crouch"),
		"All motion and held clip/view pairs are available from the manifest"):
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
			var effective := mini(frame, int(clip.frames) - 1) if clip.playback == "held" else frame % int(clip.frames)
			var tile := Rect2(effective % int(clip.sheet_columns) * 256,
				floori(float(effective) / float(clip.sheet_columns)) * 256, 256, 256)
			for sample: SquircleV1Playback in samples:
				var base: Sprite2D = sample.get("_colorable")
				var face: Sprite2D = sample.get("_face")
				if not _check(base.texture.get_width() == int(clip.sheet_columns) * 256
					and base.texture.get_height() == ceili(float(clip.frames) / float(clip.sheet_columns)) * 256
					and face.texture.get_size() == base.texture.get_size(), "Sheets match manifest dimensions at all sample sizes"):
					return
				if not _check(base.region_rect == tile and face.region_rect == tile
					and base.position == -Vector2(float(clip.anchor_px[0]), float(clip.anchor_px[1]))
					and face.position == base.position,
					"Both layers loop on the same manifest tile and anchor"):
					return
		if not _check(samples[0].get("_colorable").texture == samples[1].get("_colorable").texture,
			"Both sizes show the same approved sheet"):
			return
	for color: Dictionary in CharacterSelection.COLORS:
		lab.set("_color", color)
		lab.call("_update_selection")
		if not _check(samples[0].get("_colorable").material.get_shader_parameter("player_color")
			== Color(String(color.hex)) and samples[0].get("_face").material == null,
			"Player color tints only the body layer"):
			return
	for expression: String in ["neutral", "blink"]:
		lab.set("_expression", expression)
		lab.call("_update_selection")
		if not _check(samples[0].face_blink == (expression == "blink")
			and samples[0].get("_face").texture.resource_path.ends_with("-neutral.png")
			and samples[0].get("_blink").texture.resource_path.ends_with("-blink.png"),
			"Both sizes switch face independently of tint"):
			return
	if not _test_held_playback(samples[0]):
		return
	# Host stance selection must consume the same manifest-owned held clips as the lab.
	for sign_y: float in [-1.0, 1.0]:
		var selected := PlatformInput.classify(Vector2(0, sign_y), "neutral")
		samples[0].seek_clip("idle", "front", 0)
		samples[0].play(selected, "front")
		samples[0].advance_playback(1.0)
		var anchor: Vector2 = samples[0].get("_colorable").position
		samples[0].play("idle", "front")
		samples[0].advance_playback(1.0)
		if not _check(samples[0].get("_clip_key") == "idle-front"
			and samples[0].get("_colorable").position == anchor,
			"Host-classified stance releases to neutral at the same floor anchor"):
			return
	lab.set("_expression", "auto")
	lab.set("_blink_elapsed", 2.90)
	lab.call("_update_expression")
	if not _check(samples[0].face_blink, "Natural blink continues independently in held poses"):
		return
	lab.set("_elapsed", 0.25)
	lab.call("_update_frame")
	var paused_tile: Rect2 = samples[0].get("_colorable").region_rect
	var paused_blink: bool = samples[0].face_blink
	lab.call("_toggle_play")
	lab.call("_process", 0.5)
	if not _check(lab.get("_elapsed") == 0.25 and not lab.get("_playing")
		and samples[0].get("_colorable").region_rect == paused_tile and samples[0].face_blink == paused_blink,
		"Pause holds the selected frame"):
		return
	lab.call("_toggle_play")
	lab.call("_process", 0.5)
	if not _check(lab.get("_elapsed") == 0.75 and lab.get("_playing"),
		"Play resumes from the held frame"):
		return
	if not _check(lab.find_children("*", "ShapeCharacter", true, false).is_empty(),
		"Lab contains only Squircle v1 samples"):
		return
	print("Animation Lab checks passed")
	quit(0)


func _test_held_playback(sample: SquircleV1Playback) -> bool:
	for view: String in ["front", "three-quarter"]:
		for action: String in ["look_up", "crouch"]:
			sample.seek_clip("idle", view, 0)
			sample.play(action, view)
			sample.advance_playback(4.0 / 24.0)
			var base: Sprite2D = sample.get("_colorable")
			var entry_tile := base.region_rect
			for repeat: int in range(5):
				sample.play(action, view)
			if not _check(base.region_rect == entry_tile and sample.get("_elapsed_msec") > 0.0, "Repeated held requests preserve entry progress"):
				return false
			sample.play("idle", view)
			sample.advance_playback(1.0 / 24.0)
			if not _check(base.region_rect.position.x == 3 * 256 and sample.get("_clip_key") == action + "-" + view, "Early release reverses the current frame"):
				return false
			sample.play(action, view)
			sample.advance_playback(10.0)
			var held_tile := base.region_rect
			sample.advance_playback(10.0)
			if not _check(base.region_rect == held_tile and held_tile.position == Vector2(0, 256), "Re-press completes entry then holds frame 9 indefinitely"):
				return false
			var anchor := base.position
			var other := "crouch" if action == "look_up" else "look_up"
			sample.play(other, view)
			sample.advance_playback(4.0 / 24.0)
			if not _check(sample.get("_clip_key") == action + "-" + view and base.region_rect.position.x == 4 * 256, "Stance switching releases the current pose first"):
				return false
			sample.advance_playback(4.0 / 24.0)
			if not _check(sample.get("_clip_key") == other + "-" + view and base.region_rect.position == Vector2.ZERO and base.position == anchor, "Switch enters the next stance at shared neutral and anchor"):
				return false
			sample.advance_playback(1.0)
			sample.play("idle", view)
			sample.advance_playback(1.0)
			if not _check(sample.get("_clip_key") == "idle-" + view and base.region_rect.position == Vector2.ZERO and base.position == anchor, "Release returns to idle without moving the ground anchor"):
				return false
	return true


func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
