class_name SquircleRenderedSample
extends Node2D
## The two aligned Squircle v1 layers used by the debug comparison and Animation Lab.

const TILE_SIZE := 256
const TINT_SHADER: Shader = preload("res://assets/runtime/animated_characters/squircle/v1/render_tint.gdshader")

var base: Sprite2D
var face: Sprite2D
var tint_material: ShaderMaterial
var _columns: int = 8


func _init() -> void:
	base = _make_layer()
	tint_material = ShaderMaterial.new()
	tint_material.shader = TINT_SHADER
	base.material = tint_material
	add_child(base)
	face = _make_layer()
	add_child(face)


func configure(clip: Dictionary, colorable: Texture2D, expression: Texture2D, color: Color) -> void:
	var anchor := Vector2(float(clip.anchor_px[0]), float(clip.anchor_px[1]))
	_columns = int(clip.sheet_columns)
	base.texture = colorable
	face.texture = expression
	base.position = -anchor
	face.position = -anchor
	tint_material.set_shader_parameter("player_color", color)


func show_frame(frame: int) -> void:
	var tile := Rect2(frame % _columns * TILE_SIZE, floori(float(frame) / float(_columns)) * TILE_SIZE,
		TILE_SIZE, TILE_SIZE)
	base.region_rect = tile
	face.region_rect = tile


func _make_layer() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sprite
