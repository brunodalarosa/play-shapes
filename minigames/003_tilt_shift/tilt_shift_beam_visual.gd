class_name TiltShiftBeamVisual
extends Node2D
## The beam's visible bounds fit its collider; its parent owns the physical rotation.

var body: Node2D
var _size := Vector2.ZERO
var _texture: Texture2D
var _region: Rect2
var _badge: Sprite2D
var _label: Label


func configure(paddle: TiltShiftPaddleBody, team: int, badge_size: float) -> void:
	var path := "paddles/paddle_orange" if team == 0 else "paddles/paddle_blue"
	configure_surface(paddle, paddle.size, path)
	_badge = TiltShiftArt.sprite("gameplay/player_badge", badge_size)
	add_child(_badge)
	_label = Label.new()
	_label.size = Vector2(badge_size, badge_size)
	_label.position = -_label.size * 0.5
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.pivot_offset = _label.size * 0.5
	_label.add_theme_font_size_override("font_size", roundi(badge_size * 0.42))
	_label.add_theme_color_override("font_color", Color("312419"))
	add_child(_label)
	queue_redraw()


func configure_surface(surface: Node2D, physical_size: Vector2, path: String) -> void:
	body = surface
	_size = physical_size
	_texture = TiltShiftArt.texture(path)
	_region = TiltShiftArt.bounds(path)
	queue_redraw()


func assign_player(player: TiltShiftState.Player) -> void:
	_label.text = "P%d" % player.seat


func contact_rect() -> Rect2:
	return Rect2(-_size * 0.5, _size)


func _process(_delta: float) -> void:
	if _badge == null:
		return
	_badge.rotation = -body.rotation
	_label.rotation = -body.rotation


func _draw() -> void:
	if body == null:
		return
	# Height is the physical thickness. Keeping caps uniform avoids oval rivets while
	# the middle stretches to the physical length, including narrow designer presets.
	var cap_px := minf(96.0, _region.size.x * 0.25)
	var cap := minf(cap_px * _size.y / _region.size.y, _size.x * 0.25)
	var destination := contact_rect()
	var source_x := [_region.position.x, _region.position.x + cap_px, _region.end.x - cap_px]
	var source_width := [cap_px, _region.size.x - 2.0 * cap_px, cap_px]
	var target_x := [destination.position.x, destination.position.x + cap, destination.end.x - cap]
	var target_width := [cap, destination.size.x - 2.0 * cap, cap]
	for index: int in 3:
		draw_texture_rect_region(
			_texture,
			Rect2(target_x[index], destination.position.y, target_width[index], destination.size.y),
			Rect2(source_x[index], _region.position.y, source_width[index], _region.size.y),
		)
