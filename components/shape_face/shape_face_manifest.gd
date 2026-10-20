class_name ShapeFaceManifest
extends RefCounted
## The shared face parts and the presets composed from them, read from
## [code]assets/runtime/shape_faces/face_presets.json[/code]. A face is a box measured in face
## heights; each layer places one part in it. Positions are from the box's centre with X right
## and Y down, and rotations are clockwise, as in the manifest.

const DIRECTORY := "res://assets/runtime/shape_faces/"
const MANIFEST := DIRECTORY + "face_presets.json"
## The eye a blink draws, and the eyes that never blink because they are shut or crossed out.
const BLINK_EYE := "facial_part_eye_closed_down"
const UNBLINKING_EYES: Array[String] = [
	"facial_part_eye_closed_down",
	"facial_part_eye_closed_up",
	"facial_part_eye_x",
]
const EYE_PREFIX := "facial_part_eye_"


## One part placed in a face.
class Layer:
	extends RefCounted

	var part := ""
	## Centre from the box's centre, in face heights, Y down.
	var center := Vector2.ZERO
	## Drawn size in face heights, margin included.
	var size := Vector2.ONE
	## Clockwise turn about the centre.
	var rotation_degrees := 0.0
	## Flipped horizontally about its centre before it turns.
	var mirror := false


	func copy() -> Layer:
		var result := Layer.new()
		result.part = part
		result.center = center
		result.size = size
		result.rotation_degrees = rotation_degrees
		result.mirror = mirror
		return result


## A face preset: its box and its layers in drawing order.
class Face:
	extends RefCounted

	var name := ""
	## Width over height.
	var box_aspect := 1.0
	## The reference image's height in source pixels; part sizes in pixels divide by it.
	var source_height := 1.0
	var layers: Array[Layer] = []


	## True when one of its eyes may close for a blink.
	func can_blink() -> bool:
		for layer: Layer in layers:
			if layer.part.begins_with(EYE_PREFIX) and layer.part not in UNBLINKING_EYES:
				return true
		return false


static var _shared: ShapeFaceManifest

var faces: Dictionary[String, Face] = { }
## Source size in pixels of each part.
var part_sizes: Dictionary[String, Vector2] = { }
var _textures: Dictionary[String, Texture2D] = { }
var _blinked: Dictionary[String, Face] = { }


## The manifest every face shares, read once.
static func shared() -> ShapeFaceManifest:
	if _shared == null:
		_shared = ShapeFaceManifest.new()
		_shared.read(FileAccess.get_file_as_string(MANIFEST))
	return _shared


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
		var face := Face.new()
		face.name = name
		face.box_aspect = float(entry["box_aspect"])
		face.source_height = float(entry["source_size"][1])
		for layer_entry: Dictionary in entry["layers"]:
			var layer := Layer.new()
			layer.part = String(layer_entry["part"])
			layer.center = Vector2(layer_entry["center"][0], layer_entry["center"][1])
			layer.size = Vector2(layer_entry["size"][0], layer_entry["size"][1])
			layer.rotation_degrees = float(layer_entry["rotation_degrees"])
			layer.mirror = bool(layer_entry["mirror"])
			face.layers.append(layer)
		faces[name] = face
	return not faces.is_empty()


## The preset called [param name], or null.
func face(name: String) -> Face:
	return faces.get(name)


## The preset with its open eyes closed for a blink, each closed eye centred where the open one
## was at its own source size. Shut and crossed-out eyes stay as they are.
func blinked(name: String) -> Face:
	if _blinked.has(name):
		return _blinked[name]
	var original := face(name)
	if original == null:
		return null
	var result := Face.new()
	result.name = name
	result.box_aspect = original.box_aspect
	result.source_height = original.source_height
	for layer: Layer in original.layers:
		var copy := layer.copy()
		if copy.part.begins_with(EYE_PREFIX) and copy.part not in UNBLINKING_EYES:
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
