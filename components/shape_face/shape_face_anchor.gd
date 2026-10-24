class_name ShapeFaceAnchor
extends RefCounted
## Where a shape face sits on a model, read from the model's [code]face_anchor.json[/code]. The
## model carries a [code]FaceAnchor[/code] node on the surface the face is drawn on, facing out;
## these values place the face on it in the model's source units, X right and Y up.

## Centre of the face box from the anchor node.
var offset := Vector2.ZERO
## Height of the face box.
var height := 1.0


## The anchor in [param path], or null when it is missing or malformed.
static func load_file(path: String) -> ShapeFaceAnchor:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	var data: Variant = json.data
	if not data is Dictionary:
		return null
	var raw_offset: Variant = data.get("offset")
	var raw_height: Variant = data.get("height")
	if not raw_offset is Array or raw_offset.size() != 2 or not raw_height is float:
		return null
	var result := ShapeFaceAnchor.new()
	result.offset = Vector2(float(raw_offset[0]), float(raw_offset[1]))
	result.height = float(raw_height)
	return result if result.valid() else null


func valid() -> bool:
	return offset.is_finite() and is_finite(height) and height > 0.0


## Writes the anchor to [param path]. Returns false when the file cannot be written, as in an
## exported build, where [code]res://[/code] is read-only.
func save_file(path: String) -> bool:
	if not valid():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var data := { "offset": [snappedf(offset.x, 0.0001), snappedf(offset.y, 0.0001)] }
	data["height"] = snappedf(height, 0.0001)
	file.store_string(JSON.stringify(data, "  ") + "\n")
	return true
