@tool
extends Control

signal selection_changed(kind: String, index: int)

const Geometry := preload("res://addons/tilt_shift_workshop/workshop_geometry.gd")
const Model := preload("res://addons/tilt_shift_workshop/workshop_model.gd")
const COLORS: Array[Color] = [Color("ec9644"), Color("598df2"), Color("78684d")]

var model: Model
var mode: String = "paddle"
var selected: int = -1
var paired: bool = true
var show_guides: bool = true
var diagnostics: Dictionary = { }
var _dragging: bool = false
var _offset := Vector2.ZERO


func setup(draft: Model) -> void:
	model = draft
	model.changed.connect(refresh)
	custom_minimum_size = Vector2(340, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	resized.connect(queue_redraw)
	refresh()


func refresh() -> void:
	if (
		model.profile != null and model.profile.paddle_layout != null
		and model.profile.physics != null
	):
		diagnostics = Geometry.inspect(model.profile, model.guide_tolerance)
	queue_redraw()


func arena_rect() -> Rect2:
	var arena: Vector2 = model.profile.paddle_layout.arena_size
	var room := size - Vector2(56, 88)
	var scale := minf(room.x / arena.x, room.y / arena.y)
	var extent := arena * maxf(scale, 1.0)
	return Rect2(Vector2((size.x - extent.x) * 0.5, 24), extent)


func to_screen(point: Vector2) -> Vector2:
	var rect := arena_rect()
	return rect.position + point * rect.size.x / model.profile.paddle_layout.arena_size.x


func to_arena(point: Vector2) -> Vector2:
	var rect := arena_rect()
	return (point - rect.position) * model.profile.paddle_layout.arena_size.x / rect.size.x


func _draw() -> void:
	if model == null or model.profile == null or model.profile.paddle_layout == null:
		return
	var rect := arena_rect()
	var arena: Vector2 = model.profile.paddle_layout.arena_size
	var scale: float = rect.size.x / arena.x
	draw_rect(rect, Color("ede5d5"))
	if model.snap_enabled:
		var step: float = maxf(model.position_snap, 0.001)
		for axis: int in 2:
			var count := mini(1000, floori(arena[axis] / step) + 1)
			for index: int in count:
				var start := Vector2(index * step, 0) if axis == 0 else Vector2(0, index * step)
				var end := (
					Vector2(index * step, arena.y)
					if axis == 0
					else Vector2(arena.x, index * step)
				)
				draw_line(to_screen(start), to_screen(end), Color(0.5, 0.4, 0.3, 0.10))
	draw_line(
		to_screen(Vector2(arena.x * 0.5, 0)),
		to_screen(Vector2(arena.x * 0.5, arena.y)),
		Color("ba8d5a"),
		2,
	)
	if show_guides and not diagnostics.is_empty():
		for corridor: Vector2 in diagnostics.corridors:
			draw_rect(
				Rect2(
					to_screen(Vector2(corridor.x, 0)),
					Vector2((corridor.y - corridor.x) * scale, rect.size.y),
				),
				Color(0.3, 0.7, 0.4, 0.12),
			)
		for edge: TiltShiftState.Neighbor in diagnostics.neighbors:
			var first := _paddle_position(edge.first_id)
			var second := _paddle_position(edge.second_id)
			draw_line(to_screen(first), to_screen(second), Color(0.5, 0.2, 0.6, 0.6), 1.5)
			var selected_id := ""
			if mode == "paddle" and selected >= 0:
				selected_id = model.profile.paddle_layout.paddles[selected].paddle_id
			if selected_id in [edge.first_id, edge.second_id]:
				_label(
					to_screen((first + second) * 0.5),
					"%.3f" % edge.distance,
					Color("633c75"),
					11,
				)
	for index: int in model.profile.paddle_layout.paddles.size():
		var paddle: TiltShiftPaddle = model.profile.paddle_layout.paddles[index]
		if paddle == null:
			continue
		var point := to_screen(paddle.position)
		if show_guides and not diagnostics.is_empty():
			draw_arc(point, diagnostics.radius * scale, 0, TAU, 48, Color(0.45, 0.35, 0.25, 0.4))
			var reflected := to_screen(Vector2(arena.x - paddle.position.x, paddle.position.y))
			draw_circle(reflected, 3, Color("b09070"), false, 1)
		var extent := Vector2(
			model.profile.physics.paddle_length,
			model.profile.physics.paddle_thickness,
		) * scale
		draw_rect(Rect2(point - extent * 0.5, extent), COLORS[clampi(paddle.team, 0, 2)])
		if mode == "paddle" and index == selected:
			draw_rect(
				Rect2(point - extent * 0.5 - Vector2(3, 3), extent + Vector2(6, 6)),
				Color("332719"),
				false,
				2,
			)
		_label(point + Vector2(-3, -12), str(index + 1), Color("332719"), 13)
	var preset: TiltShiftBasketPreset = model.basket()
	for index: int in preset.openings.size():
		var opening: TiltShiftBasketOpening = preset.openings[index]
		if opening == null:
			continue
		var box := Rect2(
			to_screen(Vector2(opening.center - opening.width * 0.5, arena.y)),
			Vector2(opening.width * scale, 26),
		)
		draw_rect(box, COLORS[clampi(opening.team, 0, 2)])
		if mode == "basket" and index == selected:
			draw_rect(box.grow(3), Color("332719"), false, 2)
		_label(box.position + Vector2(2, 17), "%.3f" % opening.width, Color.WHITE, 12)
	draw_rect(rect, Color("78684d"), false, 2)
	_label(
		Vector2(16, size.y - 14),
		"Arena widths • grid %.3f • neighbor %.3f • green: clear vertical corridors"
		% [model.position_snap, model.profile.neighbor_distance],
		Color("d8d1c8"),
		12,
	)


func _gui_input(event: InputEvent) -> void:
	if model == null or model.profile.paddle_layout == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			selected = _pick(event.position)
			selection_changed.emit(mode, selected)
			if selected >= 0:
				model.begin_edit()
				_dragging = true
				var point := to_arena(event.position)
				_offset = _selected_position() - point
				accept_event()
		elif _dragging:
			_dragging = false
			model.end_edit()
			accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		var point := to_arena(event.position) + _offset
		if mode == "paddle":
			model.move_paddle(selected, point)
		else:
			model.move_basket(selected, point.x, paired)
		accept_event()


func _pick(point: Vector2) -> int:
	var position := to_arena(point)
	if mode == "paddle":
		var nearest := -1
		var distance := maxf(14.0 / arena_rect().size.x, model.profile.physics.paddle_length * 0.5)
		for index: int in model.profile.paddle_layout.paddles.size():
			var paddle: TiltShiftPaddle = model.profile.paddle_layout.paddles[index]
			if paddle != null and paddle.position.distance_to(position) <= distance:
				distance = paddle.position.distance_to(position)
				nearest = index
		return nearest
	if absf(point.y - arena_rect().end.y) > 38:
		return -1
	for index: int in model.basket().openings.size():
		var opening: TiltShiftBasketOpening = model.basket().openings[index]
		if opening != null and absf(position.x - opening.center) <= opening.width * 0.5:
			return index
	return -1


func _selected_position() -> Vector2:
	if mode == "paddle":
		return model.profile.paddle_layout.paddles[selected].position
	return Vector2(
		model.basket().openings[selected].center,
		model.profile.paddle_layout.arena_size.y,
	)


func _paddle_position(id: String) -> Vector2:
	for paddle: TiltShiftPaddle in model.profile.paddle_layout.paddles:
		if paddle != null and paddle.paddle_id == id:
			return paddle.position
	return Vector2.ZERO


func _label(point: Vector2, value: String, color: Color, font_size: int) -> void:
	draw_string(
		get_theme_default_font(),
		point,
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color,
	)
