class_name TiltShift3DPaddleChip
extends Control
## A small flat picture of a player's paddle for UI: their colour, the cream gap ring, their team
## outline and their face, in the paddle's proportions.

var face: ShapeFace2D
var body_color := Color.WHITE
var gap_color := Color("fff3dc")
var outline_color := Color("fd8702")
## Thickness over length, and the ring widths and corner radius as shares of the thickness.
var aspect := 0.2
var gap_ratio := 0.06
var outline_ratio := 0.09
var corner_ratio := 0.35
var face_ratio := 0.72


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	face = ShapeFace2D.new()
	add_child(face)
	resized.connect(_layout)
	_layout()


## Takes the paddle's look from the round's tuning.
func configure(
	color: Color,
	team: int,
	size_in_widths: Vector2,
	physics: TiltShift3DPhysicsTuning,
	look: TiltShift3DPresentationTuning,
) -> void:
	body_color = color
	gap_color = look.gap_color
	outline_color = look.outline_color(team)
	aspect = size_in_widths.y / maxf(size_in_widths.x, 0.001)
	gap_ratio = look.gap_ratio
	outline_ratio = look.outline_ratio
	corner_ratio = physics.corner_radius_ratio
	face_ratio = look.face_height_ratio
	_layout()


## The body's rectangle inside the chip, rings excluded.
func body_rect() -> Rect2:
	var rings := gap_ratio + outline_ratio
	# Fit the outline's outer box, length + 2 rings by thickness + 2 rings, in the chip.
	var thickness := minf(size.x / (1.0 / aspect + rings * 2.0), size.y / (1.0 + rings * 2.0))
	var body := Vector2(thickness / aspect, thickness)
	return Rect2((size - body) * 0.5, body)


func _layout() -> void:
	if face == null:
		return
	var body := body_rect()
	var height := body.size.y * face_ratio
	face.size = Vector2(body.size.x, height)
	face.position = Vector2(body.position.x, body.get_center().y - height * 0.5)
	queue_redraw()


func _draw() -> void:
	var body := body_rect()
	var thickness := body.size.y
	var gap := thickness * gap_ratio
	var outline := thickness * outline_ratio
	_rounded(body.grow(gap + outline), thickness * corner_ratio + gap + outline, outline_color)
	_rounded(body.grow(gap), thickness * corner_ratio + gap, gap_color)
	_rounded(body, thickness * corner_ratio, body_color)


func _rounded(rect: Rect2, radius: float, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(roundi(radius))
	style.anti_aliasing = true
	draw_style_box(style, rect)
