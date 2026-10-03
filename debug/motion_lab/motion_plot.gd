class_name MotionLabPlot
extends Control
## Bounded history + signed bars, shared by all three diagnostic vectors.

var title := ""
var axis_names := ["x", "y", "z"]
var units := ""
var display_range := 20.0
var history: Array[Array] = []
var values: Array = [null, null, null]
const COLORS := [Color("dc7756"), Color("218b73"), Color("487ac0")]
const MAX_POINTS := 120


func append_sample(next: Array) -> void:
	values = next.duplicate()
	history.append(values)
	if history.size() > MAX_POINTS:
		history.pop_front()
	queue_redraw()


func clear() -> void:
	history.clear()
	values = [null, null, null]
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_style_box(_paper(), Rect2(Vector2.ZERO, size))
	draw_string(
		font,
		Vector2(14, 26),
		"%s (%s)" % [title, units],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		19,
		Color("173c52"),
	)
	var graph := Rect2(14, 98, maxf(size.x - 28, 1), maxf(size.y - 112, 1))
	for index: int in range(5):
		var y := graph.position.y + graph.size.y * index / 4.0
		draw_line(Vector2(graph.position.x, y), Vector2(graph.end.x, y), Color("d2dedb"), 1)
	for axis: int in range(3):
		var value: Variant = values[axis]
		var label := "%s: %s" % [
			axis_names[axis],
			"unavailable" if value == null else "%.2f" % float(value),
		]
		draw_string(
			font,
			Vector2(14, 47 + axis * 16),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			190,
			14,
			COLORS[axis],
		)
		var center := size.x * 0.72
		draw_line(
			Vector2(center, 36 + axis * 16),
			Vector2(center, 48 + axis * 16),
			Color("a4b9b1"),
			1,
		)
		if value != null:
			draw_line(
				Vector2(center, 43 + axis * 16),
				Vector2(
					center + clampf(float(value) / display_range, -1, 1) * size.x * 0.2,
					43 + axis * 16,
				),
				COLORS[axis],
				5,
			)
		var previous: Variant = null
		for index: int in range(history.size()):
			var item: Variant = history[index][axis]
			if item == null:
				previous = null
				continue
			var point := Vector2(
				graph.position.x + graph.size.x * index / float(MAX_POINTS - 1),
				graph.get_center().y
				- clampf(float(item) / display_range, -1, 1) * graph.size.y * 0.5,
			)
			if previous != null:
				draw_line(previous, point, COLORS[axis], 2, true)
			previous = point


func _paper() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff9e9")
	style.border_color = Color("c9d9ce")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	return style
