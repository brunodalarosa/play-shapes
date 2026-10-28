class_name OffscreenBubbles
extends Control
## Racers behind the left edge of a race view, as speech bubbles on that edge: each points left
## in the racer's colour with their face and name, and slides up and down with their height.
## Fill this Control over the view; it never takes input.


## One racer to show.
class Entry:
	extends RefCounted

	var id := ""
	var display_name := ""
	var color := Color.WHITE
	var face := "face_slightly_smiling"
	## Height on screen, pixels from the top of this Control.
	var screen_y := 0.0


	func _init(
		racer_id: String,
		racer_name: String,
		racer_color: Color,
		racer_face: String,
		height: float,
	) -> void:
		id = racer_id
		display_name = racer_name
		color = racer_color
		face = racer_face
		screen_y = height


## One bubble: a rounded body and an arrow tip on its left.
class Bubble:
	extends Control

	const ARROW := 18.0
	var face := ShapeFace2D.new()
	var label := Label.new()
	var color := Color.WHITE:
		set(value):
			color = value
			queue_redraw()


	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(250, 76)
		size = custom_minimum_size
		face.position = Vector2(ARROW + 10, 8)
		face.size = Vector2(60, 60)
		add_child(face)
		label.position = Vector2(ARROW + 78, 0)
		label.size = Vector2(250 - ARROW - 86, 76)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.16))
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)


	func _draw() -> void:
		var body := Rect2(Vector2(ARROW, 0), size - Vector2(ARROW, 0))
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(22)
		style.border_color = Color(1, 1, 1, 0.9)
		style.set_border_width_all(4)
		draw_style_box(style, body)
		var middle := size.y * 0.5
		var tip := PackedVector2Array(
			[Vector2(0, middle), Vector2(ARROW + 4, middle - 14), Vector2(ARROW + 4, middle + 14)]
		)
		draw_colored_polygon(tip, color)


## Space kept from the top, bottom and left edges, pixels.
@export var edge := 16.0
var _bubbles: Dictionary[String, Bubble] = { }


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows exactly [param entries]; anyone else's bubble goes.
func show_racers(entries: Array[Entry]) -> void:
	var shown: Dictionary[String, bool] = { }
	for entry: Entry in entries:
		shown[entry.id] = true
		var bubble: Bubble = _bubbles.get(entry.id)
		if bubble == null:
			bubble = Bubble.new()
			bubble.name = "Bubble_%s" % entry.id.validate_node_name()
			_bubbles[entry.id] = bubble
			add_child(bubble)
		bubble.color = entry.color
		bubble.face.face_name = entry.face
		bubble.label.text = entry.display_name
		bubble.position = Vector2(edge, entry.screen_y - bubble.size.y * 0.5)

	for id: String in _bubbles.keys():
		if not shown.has(id):
			_bubbles[id].queue_free()
			_bubbles.erase(id)
	_spread()


## Keeps every bubble on screen and stacks bubbles at similar heights instead of overlapping.
func _spread() -> void:
	var ordered: Array[Bubble] = []
	ordered.assign(_bubbles.values())
	ordered.sort_custom(
		func(a: Bubble, b: Bubble) -> bool:
			return a.position.y < b.position.y,
	)
	var next_top := edge
	for bubble: Bubble in ordered:
		bubble.position.y = maxf(bubble.position.y, next_top)
		next_top = bubble.position.y + bubble.size.y + 4.0
	var bottom := size.y - edge
	for index: int in range(ordered.size() - 1, -1, -1):
		var bubble := ordered[index]
		bubble.position.y = minf(bubble.position.y, bottom - bubble.size.y)
		bottom = bubble.position.y - 4.0


func bubble_for(id: String) -> Control:
	return _bubbles.get(id)


func shown_ids() -> PackedStringArray:
	return PackedStringArray(_bubbles.keys())
