class_name TiltShiftPresentation
extends Control
## Shared-screen visuals. Rules and physics remain owned by the existing arena.

signal force_start_requested(round_token: String)

signal round_feedback(snapshot: TiltShiftState.Snapshot)

@export var tuning: TiltShiftPresentationTuning = preload(
	"res://minigames/003_tilt_shift/tuning/Presentation.tres"
)

var arena: TiltShiftArena
var viewport: SubViewport
var round_end_count := 0
var last_process_usec := 0
var _camera: Camera2D
var _decor: Node2D
var _orange: Label
var _blue: Label
var _clock: Label
var _cue: Label
var _state: TiltShiftState.Snapshot
var _controller: TiltShiftShiftController
var _selected: TiltShiftPresentationTuning
var _operators: Dictionary = { }
var _beams: Dictionary = { }
var _baskets: Dictionary = { }
var _floor_visuals: Array[TiltShiftBeamVisual] = []
var _last_ended_token := ""
var _last_timer_second := -1
var _world_bounds := Rect2()
var _factory_extent := Vector2.ZERO
var participant_panel: PanelContainer
var force_button: Button
var _participant_rows: VBoxContainer
var _participant_title: Label
var _announcement: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var paper := TextureRect.new()
	paper.texture = TiltShiftArt.texture("environment/blue_paper_backdrop")
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	var frame := SubViewportContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(viewport)
	arena = TiltShiftArena.new()
	arena.placeholder_visible = false
	viewport.add_child(arena)
	arena.ball_spawned.connect(_on_ball_spawned)
	arena.ball_removed.connect(_on_ball_removed)
	arena.stopped.connect(_on_stopped)
	_decor = Node2D.new()
	_decor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	viewport.add_child(_decor)
	_camera = Camera2D.new()
	viewport.add_child(_camera)
	# The container resizes before its stretched viewport; fit the final render size.
	viewport.size_changed.connect(_fit_camera)
	var hud := HBoxContainer.new()
	hud.position = Vector2(0, -46)
	hud.size = Vector2(1000, 36)
	viewport.add_child(hud)
	_orange = _hud_label(hud, HORIZONTAL_ALIGNMENT_LEFT, Color("ffbb60"))
	_clock = _hud_label(hud, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE)
	_blue = _hud_label(hud, HORIZONTAL_ALIGNMENT_RIGHT, Color("afd9ff"))
	_cue = Label.new()
	_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cue.add_theme_color_override("font_color", Color("fff5d9"))
	_cue.add_theme_color_override("font_shadow_color", Color("1a304d"))
	_cue.add_theme_constant_override("shadow_offset_x", 2)
	_cue.add_theme_constant_override("shadow_offset_y", 2)
	_cue.z_index = 20
	viewport.add_child(_cue)
	_cue.hide()
	_build_preparation_ui()


func start_shift(
	profile: TiltShiftTuning,
	players: Array[TiltShiftState.Player],
) -> TiltShiftState.Result:
	if tuning == null:
		return TiltShiftState.rejected(&"invalid_tuning")
	var errors := tuning.validation_errors()
	if not errors.is_empty():
		return TiltShiftState.rejected(&"invalid_tuning", errors)
	var result := arena.start_shift(profile, players)
	if not result.accepted:
		return result
	_selected = (
		profile.presentation if not profile.layouts_by_round.is_empty() else tuning
	).duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	_controller = arena.controller
	_controller.round_prepared.connect(_on_round_prepared)
	_controller.phase_changed.connect(_on_phase)
	_controller.readiness_changed.connect(_on_readiness)
	_controller.round_started.connect(_on_round_started)
	_controller.assignments_changed.connect(_on_assignments)
	_controller.angle_changed.connect(_on_angle)
	_controller.score_changed.connect(_on_scores)
	_controller.round_ended.connect(_on_round_ended)
	_controller.shift_finished.connect(_on_finished)
	round_end_count = 0
	_last_ended_token = ""
	_on_round_started(_controller.snapshot())
	return result


func start_next_round() -> TiltShiftState.Result:
	return arena.start_next_round()


func stop() -> void:
	if is_instance_valid(arena):
		arena.stop()


func world_bounds() -> Rect2:
	return _world_bounds


func operator_for(player_id: String) -> TiltShiftOperator:
	return _operators.get(player_id) as TiltShiftOperator


func beam_for(paddle_id: String) -> TiltShiftBeamVisual:
	return _beams.get(paddle_id) as TiltShiftBeamVisual


func basket_for(basket_id: String) -> TiltShiftBasketVisual:
	return _baskets.get(basket_id) as TiltShiftBasketVisual


func _hud_label(parent: Container, alignment: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("253c56"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label


func _on_round_prepared(state: TiltShiftState.Snapshot) -> void:
	if state.reworked:
		_on_round_started(state)


func _on_round_started(state: TiltShiftState.Snapshot) -> void:
	if state.reworked and _state != null and _state.round_token == state.round_token:
		_on_phase(state)
		return
	var extent := state.paddle_layout.arena_size * TiltShiftArena.WORLD_UNITS
	if not _operators.is_empty() and not extent.is_equal_approx(_factory_extent):
		_operators.clear()
		_baskets.clear()
		_floor_visuals.clear()
		for child: Node in _decor.get_children():
			_remove_visual(child)
	_state = state
	_last_timer_second = -1
	_cue.hide()
	if _operators.is_empty():
		_build_factory()
	if state.reworked:
		_rebuild_beams()
	_rebuild_baskets()
	_on_assignments(state)
	_on_scores(state)
	_fit_camera()
	_on_phase(state)


func _build_factory() -> void:
	var extent := _state.paddle_layout.arena_size * TiltShiftArena.WORLD_UNITS
	_factory_extent = extent
	_world_bounds = Rect2(
		Vector2(-_selected.side_width, -54),
		extent + Vector2(_selected.side_width * 2.0, 106),
	)
	for label: Label in [_orange, _clock, _blue]:
		label.add_theme_font_size_override("font_size", _selected.hud_font_size)
	var hud := _orange.get_parent() as HBoxContainer
	hud.size.x = extent.x
	_cue.size = Vector2(extent.x, 100)
	_cue.position = Vector2(0, extent.y * 0.5 - 50)
	_cue.add_theme_font_size_override("font_size", _selected.hud_font_size * 2)
	for team: int in 2:
		var rail_path := "environment/rail_left" if team == 0 else "environment/rail_right"
		var rail := TiltShiftArt.sprite(rail_path, _selected.side_width)
		var height := rail.texture.get_height() * rail.scale.y
		rail.scale *= (extent.y + 52) / height
		var rail_width := rail.texture.get_width() * rail.scale.x
		rail.position = Vector2(
			-rail_width * 0.5 if team == 0 else extent.x + rail_width * 0.5,
			extent.y * 0.5,
		)
		_decor.add_child(rail)
		var players: Array[TiltShiftState.Player] = []
		for player: TiltShiftState.Player in _state.players:
			if player.team == team:
				players.append(player)
		players.sort_custom(
			func(a: TiltShiftState.Player, b: TiltShiftState.Player) -> bool:
				return a.seat < b.seat,
		)
		for index: int in players.size():
			var station := TiltShiftOperator.new()
			station.configure(players[index], _selected)
			var y := extent.y * 0.5
			if players.size() > 1:
				y = lerpf(85.0, extent.y - 70.0, float(index) / float(players.size() - 1))
			station.position = Vector2(
				-_selected.side_width * 0.5 if team == 0 else extent.x + _selected.side_width * 0.5,
				y,
			)
			_decor.add_child(station)
			_operators[players[index].player_id] = station
	if not _state.reworked:
		_rebuild_beams()


func _rebuild_beams() -> void:
	_beams.clear()
	for body: TiltShiftPaddleBody in arena.paddle_bodies():
		var visual := TiltShiftBeamVisual.new()
		var team := 0
		for paddle: TiltShiftPaddle in _state.paddle_layout.paddles:
			if paddle.paddle_id == body.paddle_id:
				team = paddle.team
		visual.configure(body, team, _selected.player_badge_size)
		body.add_child(visual)
		_beams[body.paddle_id] = visual


func _rebuild_baskets() -> void:
	for visual: TiltShiftBeamVisual in _floor_visuals:
		_remove_visual(visual)
	_floor_visuals.clear()
	for body: StaticBody2D in arena.floor_bodies():
		var collider := body.get_node("CollisionShape2D") as CollisionShape2D
		var visual := TiltShiftBeamVisual.new()
		visual.configure_surface(
			body,
			(collider.shape as RectangleShape2D).size,
			"paddles/paddle_neutral",
		)
		body.add_child(visual)
		_floor_visuals.append(visual)
	for basket: TiltShiftBasketVisual in _baskets.values():
		_remove_visual(basket)
	_baskets.clear()
	var floor_y := _state.paddle_layout.arena_size.y * TiltShiftArena.WORLD_UNITS
	for opening: TiltShiftBasketOpening in _state.basket_preset.openings:
		var basket := TiltShiftBasketVisual.new()
		basket.configure(opening, floor_y, _selected.basket_scale)
		_decor.add_child(basket)
		_baskets[opening.basket_id] = basket


func _on_assignments(state: TiltShiftState.Snapshot) -> void:
	for player: TiltShiftState.Player in state.players:
		_on_angle(player)
		for paddle_id: String in player.paddle_ids:
			if _beams.has(paddle_id):
				(_beams[paddle_id] as TiltShiftBeamVisual).assign_player(player)


func _on_angle(player: TiltShiftState.Player) -> void:
	if _operators.has(player.player_id):
		(_operators[player.player_id] as TiltShiftOperator).apply_player(player)


func _on_scores(state: TiltShiftState.Snapshot) -> void:
	_state = state
	_orange.text = str(state.scores[0])
	_blue.text = str(state.scores[1])


func _on_round_ended(state: TiltShiftState.Snapshot) -> void:
	if state.round_token == _last_ended_token:
		return
	_last_ended_token = state.round_token
	round_end_count += 1
	_state = state
	_clock.text = "0 s"
	for basket: TiltShiftBasketVisual in _baskets.values():
		basket.clear_feedback()
	_cue.text = "ROUND COMPLETE"
	_cue.show()
	round_feedback.emit(state)


func _on_finished(state: TiltShiftState.Snapshot) -> void:
	_state = state
	_cue.text = ("DRAW"
		if state.is_draw
		else "%s WINS" % ("ORANGE" if state.winner == 0 else "BLUE"))
	_cue.show()


func _on_ball_spawned(ball: TiltShiftBall) -> void:
	var region := TiltShiftArt.bounds("gameplay/ball")
	var width := ball.radius * 2.0 * region.size.x / maxf(region.size.x, region.size.y)
	var visual := TiltShiftArt.sprite("gameplay/ball", width)
	ball.z_index = 2
	ball.add_child(visual)


func _on_ball_removed(_handle: TiltShiftState.BallHandle, basket_id: String) -> void:
	if _baskets.has(basket_id) and _state != null and _state.phase == &"active":
		(_baskets[basket_id] as TiltShiftBasketVisual).pulse(_selected.catch_feedback_seconds)


func _process(_delta: float) -> void:
	var began := Time.get_ticks_usec()
	if _state != null and _state.phase == &"active":
		var seconds := maxi(
			0,
			ceili(float(_state.deadline_msec - int(arena.clock.call())) / 1000.0),
		)
		if seconds != _last_timer_second:
			_last_timer_second = seconds
			_clock.text = "%d s" % seconds
	if _state != null and _state.reworked:
		_update_start_visuals()
	last_process_usec = Time.get_ticks_usec() - began


func _fit_camera() -> void:
	if _state == null or viewport.size.x <= 0 or viewport.size.y <= 0:
		return
	_camera.position = _world_bounds.get_center()
	_camera.zoom = Vector2.ONE * minf(
		float(viewport.size.x) / _world_bounds.size.x,
		float(viewport.size.y) / _world_bounds.size.y,
	)
	var top := _camera.position.y - float(viewport.size.y) * 0.5 / _camera.zoom.y
	arena.set_visible_top(top)
	var bottom := _camera.position.y + (float(viewport.size.y) * 0.5 + 2.0) / _camera.zoom.y
	for basket: TiltShiftBasketVisual in _baskets.values():
		basket.fill_to(bottom)


func _on_stopped() -> void:
	if is_instance_valid(_controller):
		_controller.round_prepared.disconnect(_on_round_prepared)
		_controller.phase_changed.disconnect(_on_phase)
		_controller.readiness_changed.disconnect(_on_readiness)
		_controller.round_started.disconnect(_on_round_started)
		_controller.assignments_changed.disconnect(_on_assignments)
		_controller.angle_changed.disconnect(_on_angle)
		_controller.score_changed.disconnect(_on_scores)
		_controller.round_ended.disconnect(_on_round_ended)
		_controller.shift_finished.disconnect(_on_finished)
	_controller = null
	_state = null
	participant_panel.hide()
	_announcement.hide()
	for visual: TiltShiftBeamVisual in _beams.values():
		_remove_visual(visual)
	_beams.clear()
	for visual: TiltShiftBeamVisual in _floor_visuals:
		_remove_visual(visual)
	_floor_visuals.clear()
	_operators.clear()
	_baskets.clear()
	for child: Node in _decor.get_children():
		_remove_visual(child)
	_cue.hide()
	_orange.text = ""
	_blue.text = ""
	_clock.text = ""


func _remove_visual(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.queue_free()


func _exit_tree() -> void:
	stop()


func _build_preparation_ui() -> void:
	_announcement = Label.new()
	_announcement.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_announcement.offset_top = 12
	_announcement.offset_bottom = 80
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.add_theme_font_size_override("font_size", 44)
	_announcement.add_theme_color_override("font_color", Color("fff5d9"))
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
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
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


func _round_label(state: TiltShiftState.Snapshot) -> String:
	if state.round_number == state.round_count:
		return "FINAL ROUND"
	return "ROUND %d" % state.round_number


func _on_phase(state: TiltShiftState.Snapshot) -> void:
	_state = state
	if not state.reworked:
		return
	_cue.modulate.a = 1.0
	_announcement.text = _round_label(state)
	_participant_title.text = _announcement.text
	_on_readiness(state)
	_update_start_visuals()


func _on_readiness(state: TiltShiftState.Snapshot) -> void:
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
		_participant_rows.add_child(row)
		for player: TiltShiftState.Player in state.players:
			if player.team != team or not player.selected:
				continue
			var card := VBoxContainer.new()
			card.custom_minimum_size.x = 140
			row.add_child(card)
			var figure := Control.new()
			figure.custom_minimum_size = Vector2(140, 92)
			card.add_child(figure)
			var character := SquircleV1Playback.new()
			for color: Dictionary in CharacterSelection.COLORS:
				if color.id == player.character_color or color.hex == player.character_color:
					character.player_color = Color(String(color.hex))
			character.scale = Vector2.ONE * 0.4
			character.position = Vector2(70, 85)
			figure.add_child(character)
			var name_label := Label.new()
			name_label.text = player.player_name
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_color_override(
				"font_color",
				Color("96500d") if team == 0 else Color("225fa9"),
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
