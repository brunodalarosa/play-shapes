extends TestScript
## The Shape Characters lab: its layout, turning, colours, one-pass clips and face controls.

const SAVED := "user://shape_characters_lab_test_anchor.json"


func _run() -> void:
	var scenario: DebugScenario = root.get_node("DebugLauncher").scenario_for_id(
		&"shape_characters_lab",
	)
	if not check(
		scenario != null and scenario.availability({ }).available,
		"The lab is listed in the debug launcher",
	):
		return
	var lab := load(scenario.scene_path).instantiate() as ShapeCharactersLab
	lab.anchor_path = SAVED
	root.add_child(lab)
	await process_frame
	await process_frame

	var zone_a := lab.get_node("%ZoneA") as Control
	var zone_b := lab.get_node("%ZoneB") as Control
	check(
		absf(zone_a.size.x - 3.0 * zone_b.size.x) <= 2.0 and zone_a.position.x < zone_b.position.x,
		"Zone A takes three quarters of the width, left of zone B",
	)
	var tabs := lab.get_node("%Tabs") as TabContainer
	check(
		tabs.get_tab_count() == 3 and tabs.get_tab_title(0) == "Character"
		and tabs.get_tab_title(1) == "Animations" and tabs.get_tab_title(2) == "Face",
		"Zone B has the Character, Animations and Face tabs",
	)
	_check_turning(lab)
	_check_character(lab)
	await _check_clips(lab)
	_check_face(lab)
	lab.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED))


func _check_turning(lab: ShapeCharactersLab) -> void:
	var turntable := lab.get_node("%Turntable") as Node3D
	var drag := InputEventMouseButton.new()
	drag.button_index = MOUSE_BUTTON_LEFT
	drag.pressed = true
	lab.get_node("%ZoneA").gui_input.emit(drag)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100.0, 40.0)
	lab.get_node("%ZoneA").gui_input.emit(motion)
	check(
		is_equal_approx(turntable.rotation.y, deg_to_rad(40.0))
		and is_zero_approx(turntable.rotation.x) and is_zero_approx(turntable.rotation.z),
		"Dragging turns the character about its upright axis only",
	)
	drag.pressed = false
	lab.get_node("%ZoneA").gui_input.emit(drag)
	lab.get_node("%ZoneA").gui_input.emit(motion)
	check(is_equal_approx(turntable.rotation.y, deg_to_rad(40.0)), "Releasing stops the turn")


func _check_character(lab: ShapeCharactersLab) -> void:
	check(lab.get_node("%Models").get_child_count() == 1, "Cubio is the only model")
	var model := lab.get_node("%Models").get_child(0) as Button
	check(model.text == "Cubio" and model.button_pressed, "Cubio is selected")
	var colors := lab.get_node("%Colors")
	check(
		colors.get_child_count() == CharacterSelection.COLORS.size(),
		"Every join colour is offered",
	)
	var green := colors.get_child(3) as Button
	green.pressed.emit()
	check(
		lab.cubio.player_color == Color(String(CharacterSelection.COLORS[3].hex)),
		"Clicking a colour tints the character",
	)


func _check_clips(lab: ShapeCharactersLab) -> void:
	var player := lab.cubio.animation_player()
	var clips := lab.get_node("%Clips")
	var names: Array[String] = []
	for button: Button in clips.get_children():
		names.append(button.text)
	check(
		names == ["Idle", "Walk", "Run", "Lever Pull", "Look Up", "Crouch"],
		"Every clip has a button",
	)

	(clips.get_child(2) as Button).pressed.emit()
	check(player.current_animation == "run" and player.is_playing(), "A clip button plays it")
	# Run is 16 frames at 24 fps.
	await create_timer(0.9).timeout
	check(not player.is_playing(), "A looping clip plays once and stops at its end")
	var length := player.current_animation_length
	check(absf(player.current_animation_position - length) < 0.01, "It rests on its last frame")

	lab.set_speed(0.5)
	(clips.get_child(1) as Button).pressed.emit()
	await create_timer(0.2).timeout
	(clips.get_child(1) as Button).pressed.emit()
	check(
		player.current_animation == "walk" and player.current_animation_position < 0.05,
		"Clicking a playing clip restarts it",
	)
	check(is_equal_approx(player.speed_scale, 0.5), "The speed multiplier applies")
	lab.toggle_pause()
	var paused_at := player.current_animation_position
	await create_timer(0.1).timeout
	check(
		not player.is_playing() and player.current_animation_position == paused_at,
		"Pause holds the frame",
	)
	lab.toggle_pause()
	check(player.is_playing(), "Play resumes")
	lab.restart_clip()
	check(player.current_animation_position < 0.05, "Restart goes back to the first frame")
	lab.stop_clip()
	check(
		player.current_animation == "idle" and is_equal_approx(player.speed_scale, 1.0),
		"Stop returns to idling as in the game",
	)


func _check_face(lab: ShapeCharactersLab) -> void:
	var face := lab.cubio.face
	var buttons := lab.get_node("%Expressions")
	check(
		buttons.get_child_count() == face.manifest.faces.size(),
		"Every facial expression has a button",
	)
	check(
		face.expressions.base_face == Cubio3D.DEFAULT_FACE
		and face.expressions == lab.cubio.expressions,
		"The neutral face is selected and blinking is on",
	)
	lab.choose_face("face_grinning")
	check(lab.cubio.expressions.base_face == "face_grinning", "Clicking an expression shows it")
	lab.set_blinking(false)
	check(
		face.expressions == null and not face.blinking and face.face_name == "face_grinning",
		"Blinking turns off and keeps the expression",
	)
	lab.reset_face()
	check(
		face.expressions != null and lab.cubio.expressions.base_face == Cubio3D.DEFAULT_FACE,
		"Reset brings back the neutral face with blinking",
	)

	var saved := Cubio3D.face_anchor()
	lab.set_placement(Vector2(0.1, -0.2), 1.1)
	var moved := face.position.is_equal_approx(Vector3(0.1, -0.2, 0.0))
	check(
		moved and is_equal_approx(face.height, 1.1),
		"Position and scale move the face on the character",
	)
	lab.revert_placement()
	check(
		face.position.is_equal_approx(Vector3(saved.offset.x, saved.offset.y, 0.0)),
		"Revert returns to the saved placement",
	)
	lab.set_placement(Vector2(0.05, 0.1), 0.95)
	check(lab.save_placement(), "Save writes the placement")
	var written := ShapeFaceAnchor.load_file(SAVED)
	check(
		written != null and written.offset.is_equal_approx(Vector2(0.05, 0.1))
		and is_equal_approx(Cubio3D.face_anchor().height, 0.95),
		"Saving makes it the default for new characters",
	)
	# Leave the shared default as the project file has it for later scripts.
	Cubio3D.store_face_anchor(saved, SAVED)
