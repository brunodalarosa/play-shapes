extends TestScript
## The shared screen draws what the rules and arena report: each player paddle in its owner's
## colour with the gap ring, team outline and face, the automatic paddle grey and faceless, names
## for the first seconds of play, bins on the scoring openings, the HUD, chips in the participant
## panel and the camera framing the arena. Faces react to hits without touching physics.

const SCENE := preload("res://minigames/005_3d_tilt_shift/tilt_shift_3d_presentation.tscn")
const UNITS := TiltShift3DArena.WORLD_UNITS

var _now := 0


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var presentation := SCENE.instantiate() as TiltShift3DPresentation
	root.add_child(presentation)
	var arena := presentation.arena
	arena.set_physics_process(false)
	arena.clock = func() -> int:
		return _now
	var source: TiltShift3DTuning = load("res://minigames/005_3d_tilt_shift/tuning/Default.tres")
	var profile: TiltShift3DTuning = source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	profile.physics.ball_count = 0
	profile.physics.negative_ball_count = 0
	var players := TiltShift3DFixtures.players(6)
	for index: int in players.size():
		players[index].character_color = String(CharacterSelection.COLORS[index].id)
	check(presentation.start_shift(profile, players, true).accepted, "The factory launches")
	await process_frame
	await process_frame
	var state := arena.controller.snapshot()

	_check_paddles(presentation, state, profile)
	_check_bins(presentation, state)
	_check_panel(presentation, state)
	_check_camera(presentation)
	await _check_play(presentation, state)
	presentation.stop()
	presentation.queue_free()
	await process_frame


func _check_paddles(
	presentation: TiltShift3DPresentation,
	state: TiltShift3DState.Snapshot,
	profile: TiltShift3DTuning,
) -> void:
	var look := profile.presentation
	var owners: Dictionary[String, TiltShift3DState.Player] = { }
	for player: TiltShift3DState.Player in state.players:
		for paddle_id: String in player.paddle_ids:
			owners[paddle_id] = player
	for body: TiltShift3DPaddleBody in presentation.arena.paddle_bodies():
		var visual := presentation.paddle_visual(body.paddle_id)
		if not check(visual != null and visual.get_parent() == body, "Every paddle is drawn"):
			continue
		var thickness := body.size.y
		check(is_equal_approx(body.size.y, 0.04 * UNITS), "Paddles are 0.04 arena widths thick")
		check(
			is_equal_approx(visual.body_mesh.get_aabb().size.x, body.size.x),
			"The drawn body has the collider's length",
		)
		if body.team == TiltShift3DTypes.Team.TRASH:
			check(visual.face == null and visual.gap_mesh == null, "The automatic paddle is plain")
			check(visual.player_color.is_equal_approx(Color("a0a0a0")), "It is grey")
			check(visual.outline_color().is_equal_approx(Color("707070")), "Its outline is darker")
			check(presentation.name_label(body.paddle_id) == null, "It has no name")
			continue
		var owner := owners[body.paddle_id]
		check(
			visual
			.player_color
			.is_equal_approx(TiltShift3DPresentation.player_color(owner.character_color)),
			"A player paddle takes its owner's colour",
		)
		check(
			visual.outline_color().is_equal_approx(look.outline_color(owner.team)),
			"A player paddle's outline is its team's",
		)
		var gap := visual.gap_mesh.get_aabb().size.y - thickness
		check(is_equal_approx(gap, thickness * 0.06 * 2.0), "The gap ring is 6% of the thickness")
		var outline := visual.outline_mesh.get_aabb().size.y - thickness
		check(
			is_equal_approx(outline, thickness * (0.06 + 0.09) * 2.0),
			"The team outline is 9% of the thickness beyond the gap",
		)
		check(
			is_equal_approx(visual.face.height, thickness * 0.72),
			"The face is 0.72 of the thickness tall, whatever the length",
		)
		check(visual.face.position.z > body.size.z * 0.5, "The face sits on the front")
		check(
			presentation.name_label(body.paddle_id).text == owner.player_name,
			"A player paddle carries its owner's name",
		)


func _check_bins(presentation: TiltShift3DPresentation, state: TiltShift3DState.Snapshot) -> void:
	var floor_y := presentation.arena.to_world(Vector2(0.0, presentation.arena.floor_depth())).y
	for opening: TiltShift3DBasketOpening in state.basket_preset.openings:
		var bin := presentation.bin_visual(opening.basket_id)
		if not check(bin != null, "Each opening has a bin"):
			continue
		check(is_equal_approx(bin.position.y, floor_y), "A bin's mouth is on the raised floor")
		var centre := presentation.arena.to_world(Vector2(opening.center * UNITS, 0.0)).x
		var left := bin.position.x + bin.mouth.x
		var right := bin.position.x + bin.mouth.y
		var half := opening.width * UNITS * 0.5
		check(
			left >= centre - half - 0.001 and right <= centre + half + 0.001,
			"A bin's drawn mouth stays within its scoring opening",
		)
		check(
			(right - left) >= opening.width * UNITS - 0.5 - 0.001,
			"It gives up at most an end wall on each touching side",
		)
		check(
			bin.body_color().is_equal_approx(presentation.tuning.bin_color(opening.team)),
			"A bin takes its team's colour",
		)
		check(
			(bin.get_node_or_null("Emblem") != null) == (opening.team == 2),
			"Only the trash bin carries the emblem",
		)


func _check_panel(presentation: TiltShift3DPresentation, state: TiltShift3DState.Snapshot) -> void:
	check(state.panel_visible, "Six players for four paddles show the participant panel")
	check(presentation.participant_panel.visible, "The panel shows when the rules ask")
	var chips := presentation.participant_panel.find_children(
		"Chip",
		"TiltShift3DPaddleChip",
		true,
		false,
	)
	var selected := 0
	for player: TiltShift3DState.Player in state.players:
		selected += 1 if player.selected else 0
	check(chips.size() == selected, "Each selected player appears as a paddle chip")
	for chip: TiltShift3DPaddleChip in chips:
		check(chip.face != null and chip.face.face_name == "face_a", "A chip shows the face")


func _check_camera(presentation: TiltShift3DPresentation) -> void:
	var camera := presentation.camera
	check(is_equal_approx(camera.fov, 30.0), "The camera has a narrow 30° view")
	check(is_zero_approx(presentation.arena.visible_top), "At 16:9 the frame is the arena")
	var size := Vector2(presentation.viewport.size)
	var top_left := camera.unproject_position(Vector3(-UNITS * 0.5, 5.4, 0.0))
	var bottom_right := camera.unproject_position(Vector3(UNITS * 0.5, -5.4, 0.0))
	check(top_left.distance_to(Vector2.ZERO) < 2.0, "The arena's top-left is the frame's")
	check(bottom_right.distance_to(size) < 2.0, "The arena's bottom-right is the frame's")


func _check_play(presentation: TiltShift3DPresentation, state: TiltShift3DState.Snapshot) -> void:
	var arena := presentation.arena
	var faces: Array[String] = []
	presentation.player_face_changed.connect(
		func(_player_id: String, face: String) -> void:
			faces.append(face),
	)
	var labels: Array[ScreenFollowLabel] = []
	var player_paddle: TiltShift3DPaddleBody
	for body: TiltShift3DPaddleBody in arena.paddle_bodies():
		if presentation.name_label(body.paddle_id) != null:
			labels.append(presentation.name_label(body.paddle_id))
			player_paddle = body
	await process_frame
	check(labels[0].modulate.a == 0.0, "Names are hidden before play")

	check(arena.controller.force_start(state.round_token, _now).accepted, "Force start begins")
	_now += 100
	arena.step(0.016, _now)
	await process_frame
	check(presentation.cue_text() == "3", "The countdown shows on screen")
	var face := presentation.paddle_visual(player_paddle.paddle_id).face
	check(face.face_name == "face_e", "Paddles look determined during the countdown")

	var started := arena.controller.snapshot()
	for tick: int in 100:
		if started.phase == &"active":
			break
		_now += 100
		arena.step(0.016, _now)
		started = arena.controller.snapshot()
	await process_frame
	await process_frame
	check(labels[0].modulate.a == 1.0, "Names show when play starts")
	check(face.face_name == "face_a", "Paddles show the default face in play")
	check(presentation.clock_text().ends_with(" s"), "The clock shows the remaining seconds")

	var collider := player_paddle.get_node("CollisionShape3D") as CollisionShape3D
	var before := (collider.shape as ConvexPolygonShape3D).points.duplicate()
	arena.paddle_hit.emit(player_paddle, 0.5)
	await process_frame
	check(face.face_name == "face_i", "A hit paddle looks startled")
	var visual := presentation.paddle_visual(player_paddle.paddle_id)
	check(visual.scale.y < 1.0 and visual.scale.x == 1.0, "It squashes along its thickness")
	check(
		(collider.shape as ConvexPolygonShape3D).points == before
		and player_paddle.scale == Vector3.ONE,
		"The squash never changes the collider",
	)
	check(faces.has("face_i"), "The owner's strongest face changes with it")

	_now = started.started_at_msec + 5300
	await process_frame
	check(labels[0].modulate.a > 0.0 and labels[0].modulate.a < 1.0, "Names fade after 5 s")
	_now = started.started_at_msec + 5700
	await process_frame
	check(labels[0].modulate.a == 0.0, "Names are gone after the fade")

	_now = started.deadline_msec
	arena.step(0.016, _now)
	await process_frame
	check(presentation.cue_text() == "ROUND COMPLETE", "The round's end shows the cutoff cue")
