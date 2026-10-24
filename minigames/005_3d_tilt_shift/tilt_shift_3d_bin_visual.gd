class_name TiltShift3DBinVisual
extends Node3D
## One bin under a scoring opening, assembled from the stretchable crate: its two ends keep
## their size and its middle stretches to the mouth. The node sits on the mouth's centre at the
## floor line, so the bin's front panel hides balls that have crossed it. Where two openings
## touch, the two bins' end walls stand side by side on the shared edge, so each mouth gives up
## an end wall's width there.

const MODEL := preload("res://assets/runtime/minigames/tilt_shift_3d/crate/bin.glb")
const EMBLEM := preload("res://assets/runtime/minigames/tilt_shift_3d/trash_badge.png")
## Measurements of the crate model, in its own units.
const END_WIDTH := 0.25
const MIDDLE_WIDTH := 1.5
const HEIGHT := 0.8
const DEPTH := 2.0
## How far the rim's lighter colour mixes toward white.
const TRIM_LIGHTEN := 0.35
## How much a catch brightens the bin at its peak.
const FLASH_LIGHTEN := 0.45

var basket_id := ""
var team := 0
## The drawn mouth, left and right edges in world units along X, relative to this node.
var mouth := Vector2.ZERO
var _color := Color.WHITE
var _body := StandardMaterial3D.new()
var _trim := StandardMaterial3D.new()
var _flash_until := 0.0
var _flash_seconds := 0.25


## Builds the bin for [param opening] of [param width] world units, with [param insets] world
## units given up at its left and right edges and [param band] world units of front panel below
## the mouth.
func configure(
	opening: TiltShift3DBasketOpening,
	width: float,
	insets: Vector2,
	band: float,
	color: Color,
) -> void:
	basket_id = opening.basket_id
	team = opening.team
	_color = color
	_paint(0.0)
	var model := MODEL.instantiate()
	var drawn := maxf(width - insets.x - insets.y, 0.05)
	var centre := (insets.x - insets.y) * 0.5
	mouth = Vector2(centre - drawn * 0.5, centre + drawn * 0.5)
	var height_scale := band / HEIGHT if band > 0.0 else 1.0
	for part_name: String in ["BinLeft", "BinMiddle", "BinRight"]:
		var part := model.get_node(part_name) as MeshInstance3D
		model.remove_child(part)
		part.owner = null
		add_child(part)
		part.set_surface_override_material(0, _body)
		part.set_surface_override_material(1, _trim)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var offset := 0.0
		var stretch := 1.0
		match part_name:
			"BinLeft":
				offset = mouth.x + MIDDLE_WIDTH * 0.5
			"BinRight":
				offset = mouth.y - MIDDLE_WIDTH * 0.5
			_:
				offset = centre
				stretch = drawn / MIDDLE_WIDTH
		part.position = Vector3(offset, 0.0, 0.0)
		part.scale = Vector3(stretch, height_scale, 1.0)
	model.free()
	if team == TiltShift3DTypes.Team.TRASH:
		var emblem := Sprite3D.new()
		emblem.name = "Emblem"
		emblem.texture = EMBLEM
		emblem.shaded = false
		emblem.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		emblem.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var size := minf(band * 0.62, drawn * 0.5)
		emblem.pixel_size = size / float(EMBLEM.get_height())
		emblem.position = Vector3(centre, -band * 0.5, DEPTH * 0.5 + 0.01)
		add_child(emblem)


## Brightens the bin for [param seconds] from [param now], after a catch.
func pulse(seconds: float, now: float) -> void:
	_flash_seconds = maxf(seconds, 0.01)
	_flash_until = now + _flash_seconds


func clear_feedback() -> void:
	_flash_until = 0.0
	_paint(0.0)


## Updates the catch flash at [param now].
func update(now: float) -> void:
	var left := _flash_until - now
	_paint(clampf(left / _flash_seconds, 0.0, 1.0) if left > 0.0 else 0.0)


func body_color() -> Color:
	return _body.albedo_color


func _paint(flash: float) -> void:
	var body := _color.lerp(Color.WHITE, flash * FLASH_LIGHTEN)
	_body.albedo_color = body
	_trim.albedo_color = body.lerp(Color.WHITE, TRIM_LIGHTEN)
