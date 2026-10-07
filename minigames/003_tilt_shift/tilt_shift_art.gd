class_name TiltShiftArt
extends RefCounted
## Runtime-only geometry for the imported factory parts.

const ROOT := "res://assets/runtime/minigames/003/"
const MANIFEST := ROOT + "manifest.json"
static var _data: Dictionary = { }


static func metadata() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _data


static func entry(path: String) -> Dictionary:
	return metadata().assets[path + ".png"]


static func texture(path: String) -> Texture2D:
	return load(ROOT + path + ".png") as Texture2D


static func bounds(path: String) -> Rect2:
	var values: Array = entry(path).visible_bounds_px
	return Rect2(values[0], values[1], values[2] - values[0], values[3] - values[1])


static func point(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))


static func anchor(path: String, key: String) -> Vector2:
	return point(entry(path).anchors_px[key])


static func sprite(path: String, width: float) -> Sprite2D:
	var result := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture(path)
	atlas.region = bounds(path)
	result.texture = atlas
	result.scale = Vector2.ONE * width / atlas.region.size.x
	return result


## Stretch the center only; the two caps keep their native proportions.
static func strip(path: String, width: float, art_scale: float) -> NinePatchRect:
	var result := NinePatchRect.new()
	var atlas := AtlasTexture.new()
	var region := bounds(path)
	var horizontal: Array = metadata().basket_canvas_region_x
	region.position.x = float(horizontal[0])
	region.size.x = float(horizontal[1] - horizontal[0])
	atlas.atlas = texture(path)
	atlas.region = region
	result.texture = atlas
	result.patch_margin_left = 64
	result.patch_margin_right = 64
	result.size = Vector2(width / art_scale, region.size.y)
	result.scale = Vector2.ONE * art_scale
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
