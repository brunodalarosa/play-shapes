class_name TiltShift3DPresentation
extends Control
## The shared screen of Tilt Shift 3D: the factory, the bins, the paddles with their faces and
## names, the balls, and the HUD over them. Rules and physics stay with the arena it owns; this
## only draws what they report.

signal force_start_requested(round_token: String)
signal round_feedback(snapshot: TiltShift3DState.Snapshot)
## The strongest face across [param player_id]'s paddles changed to [param face].
signal player_face_changed(player_id: String, face: String)

const TEXT_COLOR := Color("3d465d")
const ORANGE_TEXT := Color("e86f00")
const BLUE_TEXT := Color("0144f2")
const CREAM := Color("fff5d9")
## Gap in world units between a paddle's outline and its name.
const NAME_GAP := 0.2

@export var tuning: TiltShift3DPresentationTuning = preload(
	"res://minigames/005_3d_tilt_shift/tuning/Presentation.tres"
)
@export var expression_tuning: TiltShift3DExpressionTuning = preload(
	"res://minigames/005_3d_tilt_shift/tuning/Expressions.tres"
)

var arena: TiltShift3DArena
var viewport: SubViewport
var camera: Camera3D
var factory: TiltShift3DFactory
var driver: TiltShift3DExpressionDriver
var round_end_count := 0
var last_process_usec := 0
var participant_panel: PanelContainer
var force_button: Button
var _world: Node3D
var _bins_root: Node3D
var _names_root: Control
var _orange: Label
var _blue: Label
var _clock: Label
var _cue: Label
var _announcement: Label
var _participant_rows: VBoxContainer
var _participant_title: Label
var _state: TiltShift3DState.Snapshot
var _controller: TiltShift3DShiftController
var _selected: TiltShift3DPresentationTuning
var _paddles: Dictionary[String, TiltShift3DPaddleVisual] = { }
var _names: Dictionary[String, ScreenFollowLabel] = { }
var _bins: Dictionary[String, TiltShift3DBinVisual] = { }
var _floor_visuals: Array[MeshInstance3D] = []
var _player_faces: Dictionary[String, String] = { }
var _ball_meshes: Dictionary[int, SphereMesh] = { }
var _ball_materials: Dictionary[int, StandardMaterial3D] = { }
var _last_ended_token := ""
var _last_timer_second := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := SubViewportContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	frame.add_child(viewport)
	_world = Node3D.new()
	_world.name = "World"
	viewport.add_child(_world)
	_build_lighting()
	factory = TiltShift3DFactory.new()
	factory.name = "Factory"
	_world.add_child(factory)
	_bins_root = Node3D.new()
	_bins_root.name = "Bins"
	_world.add_child(_bins_root)
	arena = TiltShift3DArena.new()
	arena.name = "Arena"
	_world.add_child(arena)
	arena.ball_spawned.connect(_on_ball_spawned)
	arena.ball_removed.connect(_on_ball_removed)
	arena.paddle_hit.connect(_on_paddle_hit)
	arena.stopped.connect(_on_stopped)
	camera = Camera3D.new()
	camera.name = "Camera"
	_world.add_child(camera)
	camera.make_current()
	# Names follow the paddles through this viewport's camera, so they live in its canvas.
	_names_root = Control.new()
	_names_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(_names_root)
	# The container resizes before its stretched viewport; fit the final render size.
	viewport.size_changed.connect(_fit_camera)
	_build_hud()
	_build_preparation_ui()


func start_shift(
	profile: TiltShift3DTuning,
	players: Array[TiltShift3DState.Player],
	wait_for_initial_motion: bool = false,
) -> TiltShift3DState.Result:
	if tuning == null or expression_tuning == null:
		return TiltShift3DState.rejected(&"invalid_tuning")
	var errors := tuning.validation_errors()
	errors.append_array(expression_tuning.validation_errors())
	if not errors.is_empty():
		return TiltShift3DState.rejected(&"invalid_tuning", errors)
	var mapped := not profile.layouts_by_round.is_empty()
	_selected = (
		profile.presentation if mapped else tuning
	).duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	var expressions := (
		profile.expressions if mapped else expression_tuning
	).duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	driver = TiltShift3DExpressionDriver.new(expressions)
	factory.configure(_selected)
	_apply_hud_style()
	var result := arena.start_shift(profile, players, wait_for_initial_motion)
	if not result.accepted:
		return result
	_controller = arena.controller
	_controller.round_prepared.connect(_on_round_prepared)
	_controller.phase_changed.connect(_on_phase)
	_controller.readiness_changed.connect(_on_readiness)
	_controller.round_started.connect(_on_round_started)
	_controller.assignments_changed.connect(_on_assignments)
	_controller.score_changed.connect(_on_scores)
	_controller.round_ended.connect(_on_round_ended)
	_controller.shift_finished.connect(_on_finished)
	round_end_count = 0
	_last_ended_token = ""
	_on_round_started(_controller.snapshot())
	return result


func start_next_round() -> TiltShift3DState.Result:
	return arena.start_next_round()


func stop() -> void:
	if is_instance_valid(arena):
		arena.stop()


## The drawn paddle of [param paddle_id], or null.
func paddle_visual(paddle_id: String) -> TiltShift3DPaddleVisual:
	return _paddles.get(paddle_id)


## The name above [param paddle_id], or null for the automatic paddle.
func name_label(paddle_id: String) -> ScreenFollowLabel:
	return _names.get(paddle_id)


func bin_visual(basket_id: String) -> TiltShift3DBinVisual:
	return _bins.get(basket_id)


func floor_visuals() -> Array[MeshInstance3D]:
	return _floor_visuals.duplicate()


## The strongest face across [param player_id]'s paddles now, or an empty string.
func player_face(player_id: String) -> String:
	return _player_faces.get(player_id, "")


func cue_text() -> String:
	return _cue.text if _cue.visible else ""


func clock_text() -> String:
	return _clock.text


func score_texts() -> PackedStringArray:
	return PackedStringArray([_orange.text, _blue.text])


## The paddle colour of a player's chosen Squircle colour, given as its ID or hex.
static func player_color(character_color: String) -> Color:
	for color: Dictionary in CharacterSelection.COLORS:
		if color.id == character_color or color.hex == character_color:
			return Color(String(color.hex))
	return Color(character_color) if Color.html_is_valid(character_color) else Color.WHITE


func _seconds() -> float:
	return float(arena.clock.call()) / 1000.0


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("f6ecd8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff8ee")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-38.0, 24.0, 0.0)
	light.light_energy = 0.75
	light.shadow_enabled = false
	_world.add_child(light)


func _build_hud() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 36
	bar.offset_right = -36
	bar.offset_top = 14
	bar.offset_bottom = 84
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_orange = _hud_label(bar, HORIZONTAL_ALIGNMENT_LEFT, ORANGE_TEXT)
	_clock = _hud_label(bar, HORIZONTAL_ALIGNMENT_CENTER, TEXT_COLOR)
	_blue = _hud_label(bar, HORIZONTAL_ALIGNMENT_RIGHT, BLUE_TEXT)
	_cue = Label.new()
	_cue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cue.add_theme_color_override("font_color", TEXT_COLOR)
	_cue.add_theme_color_override("font_outline_color", CREAM)
	_cue.add_theme_constant_override("outline_size", 18)
	_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cue)
	_cue.hide()


func _hud_label(parent: Container, alignment: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", CREAM)
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _apply_hud_style() -> void:
	for label: Label in [_orange, _clock, _blue]:
		label.add_theme_font_size_override("font_size", _selected.hud_font_size)
	_cue.add_theme_font_size_override("font_size", _selected.hud_font_size * 3)


func _on_round_prepared(state: TiltShift3DState.Snapshot) -> void:
	if state.reworked:
		_on_round_started(state)


func _on_round_started(state: TiltShift3DState.Snapshot) -> void:
	if state.reworked and _state != null and _state.round_token == state.round_token:
		_on_phase(state)
		return
	_state = state
	_last_timer_second = -1
	_cue.hide()
	_rebuild_paddles()
	_rebuild_bins()
	_on_assignments(state)
	_on_scores(state)
	_fit_camera()
	_on_phase(state)


func _rebuild_paddles() -> void:
	for visual: TiltShift3DPaddleVisual in _paddles.values():
		_remove_visual(visual)
	_paddles.clear()
	for label: ScreenFollowLabel in _names.values():
		_remove_visual(label)
	_names.clear()
	for body: TiltShift3DPaddleBody in arena.paddle_bodies():
		var visual := TiltShift3DPaddleVisual.new()
		visual.name = "Look"
		body.add_child(visual)
		visual.configure(body, _selected, Color.WHITE)
		_paddles[body.paddle_id] = visual
		if body.team == TiltShift3DTypes.Team.TRASH:
			continue
		var label := ScreenFollowLabel.new()
		label.target = body
		var reach := body.size.y * (0.5 + _selected.gap_ratio + _selected.outline_ratio)
		label.world_offset = Vector3(0.0, reach + NAME_GAP, 0.0)
		label.add_theme_font_size_override("font_size", _selected.name_font_size)
		label.add_theme_color_override("font_color", TEXT_COLOR)
		label.add_theme_color_override("font_outline_color", CREAM)
		label.add_theme_constant_override("outline_size", 8)
		label.modulate.a = 0.0
		_names_root.add_child(label)
		_names[body.paddle_id] = label


func _rebuild_bins() -> void:
	for bin: TiltShift3DBinVisual in _bins.values():
		_remove_visual(bin)
	_bins.clear()
	for visual: MeshInstance3D in _floor_visuals:
		_remove_visual(visual)
	_floor_visuals.clear()
	var units := TiltShift3DArena.WORLD_UNITS
	var floor_y := arena.floor_depth()
	var band := _state.physics.bin_band * units
	var openings := _state.basket_preset.openings
	var tolerance := TiltShift3DBasketPreset.REFLECTION_TOLERANCE
	for opening: TiltShift3DBasketOpening in openings:
		var left := opening.center - opening.width * 0.5
		var right := opening.center + opening.width * 0.5
		var insets := Vector2.ZERO
		for other: TiltShift3DBasketOpening in openings:
			if other == opening:
				continue
			if absf(other.center + other.width * 0.5 - left) <= tolerance:
				insets.x = TiltShift3DBinVisual.END_WIDTH
			if absf(other.center - other.width * 0.5 - right) <= tolerance:
				insets.y = TiltShift3DBinVisual.END_WIDTH
		var bin := TiltShift3DBinVisual.new()
		bin.name = opening.basket_id
		_bins_root.add_child(bin)
		bin.configure(
			opening,
			opening.width * units,
			insets,
			band,
			_selected.bin_color(opening.team),
		)
		bin.position = arena.to_world(Vector2(opening.center * units, floor_y))
		_bins[opening.basket_id] = bin
	var material := StandardMaterial3D.new()
	material.albedo_color = _selected.trash_bin_color.lerp(Color.WHITE, 0.3)
	for body: StaticBody3D in arena.floor_bodies():
		var shape := (body.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		var mesh := BoxMesh.new()
		mesh.size = Vector3(shape.size.x, shape.size.y, 1.6)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = material
		visual.position = body.position
		_bins_root.add_child(visual)
		_floor_visuals.append(visual)


func _on_assignments(state: TiltShift3DState.Snapshot) -> void:
	var owners: Dictionary[String, String] = { }
	for player: TiltShift3DState.Player in state.players:
		for paddle_id: String in player.paddle_ids:
			var visual: TiltShift3DPaddleVisual = _paddles.get(paddle_id)
			if visual == null or visual.team == TiltShift3DTypes.Team.TRASH:
				continue
			owners[paddle_id] = player.player_id
			visual.set_color(player_color(player.character_color))
			if _names.has(paddle_id):
				_names[paddle_id].text = player.player_name
	driver.set_paddles(owners)
	for paddle_id: String in _paddles:
		var visual := _paddles[paddle_id]
		if visual.face != null:
			visual.face.expressions = driver.stacks.get(paddle_id)
			visual.face.clock = _seconds
	driver.set_moment(state, _paddle_teams(state))


func _paddle_teams(state: TiltShift3DState.Snapshot) -> Dictionary[String, int]:
	var teams: Dictionary[String, int] = { }
	for player: TiltShift3DState.Player in state.players:
		for paddle_id: String in player.paddle_ids:
			teams[paddle_id] = player.team
	return teams


func _on_scores(state: TiltShift3DState.Snapshot) -> void:
	_state = state
	_orange.text = str(state.scores[0])
	_blue.text = str(state.scores[1])


func _on_round_ended(state: TiltShift3DState.Snapshot) -> void:
	if state.round_token == _last_ended_token:
		return
	_last_ended_token = state.round_token
	round_end_count += 1
	_state = state
	_clock.text = "0 s"
	for bin: TiltShift3DBinVisual in _bins.values():
		bin.clear_feedback()
	_cue.text = "ROUND COMPLETE"
	_cue.modulate.a = 1.0
	_cue.show()
	driver.set_moment(state, _paddle_teams(state))
	round_feedback.emit(state)


func _on_finished(state: TiltShift3DState.Snapshot) -> void:
	_state = state
	_cue.text = ("DRAW"
		if state.is_draw
		else "%s WINS" % ("ORANGE" if state.winner == 0 else "BLUE"))
	_cue.modulate.a = 1.0
	_cue.show()
	driver.set_moment(state, _paddle_teams(state))


func _on_ball_spawned(ball: TiltShift3DBall) -> void:
	var key := roundi(ball.radius * 10000.0)
	if not _ball_meshes.has(key):
		var sphere := SphereMesh.new()
		sphere.radius = ball.radius
		sphere.height = ball.radius * 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		_ball_meshes[key] = sphere
	var colour := _state.physics.negative_ball_color if ball.score_value < 0 \
			else _selected.ball_color
	if not _ball_materials.has(ball.score_value):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.45
		_ball_materials[ball.score_value] = material
	var visual := MeshInstance3D.new()
	visual.mesh = _ball_meshes[key]
	visual.material_override = _ball_materials[ball.score_value]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.add_child(visual)


func _on_ball_removed(_handle: TiltShift3DState.BallHandle, basket_id: String) -> void:
	if _bins.has(basket_id) and _state != null and _state.phase == &"active":
		_bins[basket_id].pulse(_selected.catch_feedback_seconds, _seconds())


func _on_paddle_hit(paddle: TiltShift3DPaddleBody, speed: float) -> void:
	if driver != null:
		driver.hit(paddle.paddle_id, speed, _seconds())


func _process(_delta: float) -> void:
	var began := Time.get_ticks_usec()
	if _state == null:
		return
	var now := _seconds()
	if _state.phase == &"active":
		var seconds := maxi(
			0,
			ceili(float(_state.deadline_msec - int(arena.clock.call())) / 1000.0),
		)
		if seconds != _last_timer_second:
			_last_timer_second = seconds
			_clock.text = "%d s" % seconds
	if _state.reworked:
		_update_start_visuals()
	for bin: TiltShift3DBinVisual in _bins.values():
		bin.update(now)
	_update_names()
	_update_faces(now)
	last_process_usec = Time.get_ticks_usec() - began


func _update_names() -> void:
	var alpha := 0.0
	if _state.phase == &"active":
		var shown := float(int(arena.clock.call()) - _state.started_at_msec) / 1000.0
		alpha = 1.0
		if shown > _selected.name_seconds:
			var fade := maxf(_selected.name_fade_seconds, 0.001)
			alpha = clampf(1.0 - (shown - _selected.name_seconds) / fade, 0.0, 1.0)
	for label: ScreenFollowLabel in _names.values():
		label.modulate.a = alpha


func _update_faces(now: float) -> void:
	var speeds: Dictionary[String, float] = { }
	for body: TiltShift3DPaddleBody in arena.paddle_bodies():
		speeds[body.paddle_id] = body.angular_speed
	driver.update(speeds, now)
	for paddle_id: String in _paddles:
		_paddles[paddle_id].set_squash(driver.squash(paddle_id, now))
	for player: TiltShift3DState.Player in _state.players:
		var face := driver.face_for_player(player.player_id, now)
		if face != _player_faces.get(player.player_id, ""):
			_player_faces[player.player_id] = face
			player_face_changed.emit(player.player_id, face)


## Frames the whole arena: edge to edge at 16:9, with any extra height of a narrower screen
## above the arena, so the bin band always meets the bottom edge.
func _fit_camera() -> void:
	if viewport.size.x <= 0 or viewport.size.y <= 0:
		return
	var size := arena.world_size()
	var fov := _selected.camera_fov if _selected != null else 30.0
	var distance := size.y * 0.5 / tan(deg_to_rad(fov) * 0.5)
	var aspect := float(viewport.size.x) / float(viewport.size.y)
	var half_height := size.y * 0.5
	if aspect >= size.x / size.y - 0.0001:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = fov
	else:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = rad_to_deg(2.0 * atan(size.x * 0.5 / distance))
		half_height = size.x * 0.5 / aspect
	camera.position = Vector3(0.0, half_height - size.y * 0.5, distance)
	arena.set_visible_top(size.y - half_height * 2.0)


func _on_stopped() -> void:
	if is_instance_valid(_controller):
		_controller.round_prepared.disconnect(_on_round_prepared)
		_controller.phase_changed.disconnect(_on_phase)
		_controller.readiness_changed.disconnect(_on_readiness)
		_controller.round_started.disconnect(_on_round_started)
		_controller.assignments_changed.disconnect(_on_assignments)
		_controller.score_changed.disconnect(_on_scores)
		_controller.round_ended.disconnect(_on_round_ended)
		_controller.shift_finished.disconnect(_on_finished)
	_controller = null
	_state = null
	participant_panel.hide()
	_announcement.hide()
	for label: ScreenFollowLabel in _names.values():
		_remove_visual(label)
	_names.clear()
	_paddles.clear()
	for bin: TiltShift3DBinVisual in _bins.values():
		_remove_visual(bin)
	_bins.clear()
	for visual: MeshInstance3D in _floor_visuals:
		_remove_visual(visual)
	_floor_visuals.clear()
	_player_faces.clear()
	_cue.hide()
	_orange.text = ""
	_blue.text = ""
	_clock.text = ""


func _remove_visual(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _exit_tree() -> void:
	stop()


func _build_preparation_ui() -> void:
	_announcement = Label.new()
	_announcement.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_announcement.offset_top = 84
	_announcement.offset_bottom = 150
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.add_theme_font_size_override("font_size", 44)
	_announcement.add_theme_color_override("font_color", TEXT_COLOR)
	_announcement.add_theme_color_override("font_outline_color", CREAM)
	_announcement.add_theme_constant_override("outline_size", 10)
	_announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_announcement)
	_announcement.hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	participant_panel = PanelContainer.new()
	participant_panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4ecd9")
	style.border_color = Color("e0d2b6")
	style.set_border_width_all(2)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.set_corner_radius_all(16)
	participant_panel.add_theme_stylebox_override("panel", style)
	center.add_child(participant_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	participant_panel.add_child(column)
	_participant_title = Label.new()
	_participant_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_participant_title.add_theme_color_override("font_color", Color("253c56"))
	_participant_title.add_theme_font_size_override("font_size", 36)
	column.add_child(_participant_title)
	_participant_rows = VBoxContainer.new()
	_participant_rows.add_theme_constant_override("separation", 10)
	column.add_child(_participant_rows)
	force_button = Button.new()
	force_button.text = "FORCE START"
	force_button.custom_minimum_size.y = 48
	column.add_child(force_button)
	force_button.pressed.connect(
		func() -> void:
			if _state != null:
				force_start_requested.emit(_state.round_token),
	)
	participant_panel.hide()


func _round_label(state: TiltShift3DState.Snapshot) -> String:
	if state.round_number == state.round_count:
		return "FINAL ROUND"
	return "ROUND %d" % state.round_number


func _on_phase(state: TiltShift3DState.Snapshot) -> void:
	_state = state
	if driver != null:
		driver.set_moment(state, _paddle_teams(state))
	if not state.reworked:
		return
	_cue.modulate.a = 1.0
	_announcement.text = _round_label(state)
	_participant_title.text = _announcement.text
	_on_readiness(state)
	_update_start_visuals()


func _on_readiness(state: TiltShift3DState.Snapshot) -> void:
	_state = state
	participant_panel.visible = state.panel_visible
	if not state.panel_visible:
		return
	for child: Node in _participant_rows.get_children():
		_participant_rows.remove_child(child)
		child.queue_free()
	for team: int in 2:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		_participant_rows.add_child(row)
		for player: TiltShift3DState.Player in state.players:
			if player.team != team or not player.selected:
				continue
			row.add_child(_participant_card(state, player))


func _participant_card(
	state: TiltShift3DState.Snapshot,
	player: TiltShift3DState.Player,
) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = 150
	var chip := TiltShift3DPaddleChip.new()
	chip.name = "Chip"
	chip.custom_minimum_size = Vector2(150, 56)
	card.add_child(chip)
	chip.configure(
		player_color(player.character_color),
		player.team,
		state.paddle_layout.paddle_size(player.team, state.physics),
		state.physics,
		_selected,
	)
	var name_label := Label.new()
	name_label.text = player.player_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override(
		"font_color",
		Color("96500d") if player.team == 0 else Color("225fa9"),
	)
	name_label.add_theme_font_size_override("font_size", 22)
	card.add_child(name_label)
	var ready_label := Label.new()
	ready_label.text = "READY" if player.ready else "…"
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.add_theme_color_override(
		"font_color",
		Color("227347") if player.ready else Color("526075"),
	)
	card.add_child(ready_label)
	return card


func _update_start_visuals() -> void:
	var now := int(arena.clock.call())
	_announcement.visible = (
		not _state.panel_visible and _state.phase in [&"countdown", &"start", &"active"]
	)
	if _state.phase == &"active":
		_announcement.visible = now - _state.started_at_msec < 2000
	if _state.phase == &"countdown":
		_cue.text = str(maxi(1, ceili(float(_state.phase_deadline_msec - now) / 1000.0)))
		_cue.show()
	elif _state.phase == &"start":
		_cue.text = "START"
		var duration := maxi(1, _state.phase_deadline_msec - _state.phase_started_msec)
		var progress := clampf(float(now - _state.phase_started_msec) / duration, 0.0, 1.0)
		_cue.modulate.a = sin(progress * PI)
		_cue.show()
	elif _state.phase in [&"active", &"preparing"]:
		_cue.hide()
