class_name ShapeFaceManifest
extends RefCounted
## The shared face parts and the presets composed from them, read from
## [code]assets/runtime/shape_faces/face_presets.json[/code]. A face is a box measured in face
## heights; each layer places one part in it. Positions are from the box's centre with X right
## and Y down, and rotations are clockwise, as in the manifest.

const DIRECTORY := "res://assets/runtime/shape_faces/"
const MANIFEST := DIRECTORY + "face_presets.json"
## The eye a blink draws.
const BLINK_EYE := "facial_part_eye_closed_down"

var faces: Dictionary[String, ShapeFacePreset] = { }
## Source size in pixels of each part.
var part_sizes: Dictionary[String, Vector2] = { }
var _textures: Dictionary[String, Texture2D] = { }
var _blinked: Dictionary[String, ShapeFacePreset] = { }


## The project's face manifest, freshly read. The part textures it loads are shared through
## the resource cache.
static func load_default() -> ShapeFaceManifest:
	var result := ShapeFaceManifest.new()
	result.read(FileAccess.get_file_as_string(MANIFEST))
	return result


## Reads the manifest's JSON text. Returns false when it is not a face manifest.
func read(text: String) -> bool:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or not data.get("parts") is Dictionary:
		return false
	var parts: Dictionary = data["parts"]
	for part: String in parts:
		var entry: Dictionary = parts[part]
		part_sizes[part] = Vector2(entry["size"][0], entry["size"][1])
	var presets: Dictionary = data.get("faces", { })
	for name: String in presets:
		var entry: Dictionary = presets[name]
		var face := ShapeFacePreset.new()
		face.name = name
		face.box_aspect = float(entry["box_aspect"])
		face.source_height = float(entry["source_size"][1])
		for layer_entry: Dictionary in entry["layers"]:
			var layer := ShapeFaceLayer.new()
			layer.part = String(layer_entry["part"])
			layer.center = Vector2(layer_entry["center"][0], layer_entry["center"][1])
			layer.size = Vector2(layer_entry["size"][0], layer_entry["size"][1])
			layer.rotation_degrees = float(layer_entry["rotation_degrees"])
			layer.mirror = bool(layer_entry["mirror"])
			face.layers.append(layer)
		faces[name] = face
	return not faces.is_empty()


## The preset called [param name], or null.
func face(name: String) -> ShapeFacePreset:
	return faces.get(name)


## The preset with its open eyes closed for a blink, each closed eye centred where the open one
## was at its own source size. Fixed eyes, such as shut or spiral eyes, stay as they are.
func blinked(name: String) -> ShapeFacePreset:
	if _blinked.has(name):
		return _blinked[name]
	var original := face(name)
	if original == null:
		return null
	var result := ShapeFacePreset.new()
	result.name = name
	result.box_aspect = original.box_aspect
	result.source_height = original.source_height
	for layer: ShapeFaceLayer in original.layers:
		var copy := layer.copy()
		if ShapeFacePreset.can_close(copy.part):
			copy.part = BLINK_EYE
			copy.size = part_sizes[BLINK_EYE] / original.source_height
			copy.rotation_degrees = 0.0
		result.layers.append(copy)
	_blinked[name] = result
	return result


## The part's texture, loaded once.
func texture(part: String) -> Texture2D:
	if not _textures.has(part):
		_textures[part] = load(DIRECTORY + part + ".png") as Texture2D
	return _textures[part]
