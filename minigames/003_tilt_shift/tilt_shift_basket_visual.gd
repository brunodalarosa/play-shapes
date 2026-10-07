class_name TiltShiftBasketVisual
extends Node2D
## Both layers share the scoring-mouth mapping; only their centers stretch.

var opening_rect: Rect2
var back: NinePatchRect
var front: NinePatchRect
var _flash_remaining := 0.0
var _flash_seconds := 0.25


func configure(opening: TiltShiftBasketOpening, floor_y: float, art_scale: float) -> void:
	var treatments := ["orange", "blue", "trash"]
	var prefix: String = "baskets/" + treatments[opening.team]
	var mouth: Array = TiltShiftArt.metadata().basket_mouth_px
	var region: Array = TiltShiftArt.metadata().basket_canvas_region_x
	var center_source := float(region[1] - region[0] - 128)
	var center_width := opening.width * TiltShiftArena.WORLD_UNITS
	center_width *= center_source / float(mouth[1] - mouth[0])
	var width := center_width + 128.0 * art_scale
	position = Vector2(opening.center * TiltShiftArena.WORLD_UNITS, floor_y)
	opening_rect = Rect2(
		-opening.width * TiltShiftArena.WORLD_UNITS * 0.5,
		0,
		opening.width * TiltShiftArena.WORLD_UNITS,
		0,
	)
	back = TiltShiftArt.strip(prefix + "_back", width, art_scale)
	front = TiltShiftArt.strip(prefix + "_front", width, art_scale)
	var rear_region := TiltShiftArt.bounds(prefix + "_back")
	var rear_origin_y := -float(mouth[2]) * art_scale
	back.position = Vector2(-width * 0.5, rear_origin_y + rear_region.position.y * art_scale)
	var overlay: Array = TiltShiftArt.entry(prefix + "_back").front_overlay_offset_px
	var front_region := TiltShiftArt.bounds(prefix + "_front")
	front.position = Vector2(
		-width * 0.5,
		rear_origin_y + (float(overlay[1]) + front_region.position.y) * art_scale,
	)
	back.z_index = -2
	front.z_index = 5
	add_child(back)
	add_child(front)
	if opening.team == 2:
		var badge := TiltShiftArt.sprite("baskets/trash_badge", width * 0.30)
		badge.position.y = front.position.y + front.size.y * art_scale * 0.5
		badge.z_index = 6
		add_child(badge)


func pulse(seconds: float) -> void:
	_flash_seconds = maxf(seconds, 0.01)
	_flash_remaining = _flash_seconds


func clear_feedback() -> void:
	_flash_remaining = 0.0
	modulate = Color.WHITE


func _process(delta: float) -> void:
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	var strength := _flash_remaining / _flash_seconds * 0.25
	modulate = Color(1.0 + strength, 1.0 + strength, 1.0 + strength)
