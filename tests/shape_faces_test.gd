extends TestScript
## The shared face parts: every part the preset manifest names is an 8x PNG beside it with a
## vector master, the manifest holds the owner's twelve faces, and the parts and manifest are
## the ones the export script last verified against the reference faces.

const DIRECTORY := "res://assets/runtime/shape_faces/"
const MANIFEST := DIRECTORY + "face_presets.json"
const ART := "res://art/shape_characters_face_system_assets/"
const VERIFICATION := ART + "vector/verification.json"
const EXPORT_SCALE := 8
const FACES: Array[String] = [
	"face_a",
	"face_b",
	"face_c",
	"face_d",
	"face_e",
	"face_f",
	"face_g",
	"face_h",
	"face_i",
	"face_j",
	"face_k",
	"face_l",
]


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not check(manifest != null, "The face manifest is JSON"):
		return

	check(int(manifest["export_scale"]) == EXPORT_SCALE, "The parts are exported at 8x")
	var parts: Dictionary = manifest["parts"]
	check(parts.size() == 15, "The manifest lists the fourteen supplied parts and the X-eye")
	check(parts.has("facial_part_eye_x"), "The X-eye is a part")
	for part: String in parts:
		var entry: Dictionary = parts[part]
		var texture := load(DIRECTORY + String(entry["file"])) as Texture2D
		if not check(texture != null, "%s loads as a texture" % part):
			continue
		var size := Vector2i(int(entry["size"][0]), int(entry["size"][1]))
		check(texture.get_size() == Vector2(size * EXPORT_SCALE), "%s is drawn at 8x" % part)
		check(int(entry["padding"]) in [0, 1], "%s has at most a one-pixel margin" % part)
		check(FileAccess.file_exists(ART + "vector/%s.svg" % part), "%s has a master" % part)

	var faces: Dictionary = manifest["faces"]
	var names: Array[String] = []
	names.assign(faces.keys())
	names.sort()
	check(names == FACES, "The manifest holds face_a to face_l")
	for face: String in faces:
		var entry: Dictionary = faces[face]
		var size := Vector2i(int(entry["source_size"][0]), int(entry["source_size"][1]))
		check(
			is_equal_approx(float(entry["box_aspect"]), float(size.x) / size.y),
			"%s keeps its reference's aspect" % face,
		)
		check(_png_size(ART + face + ".png") == size, "%s has its reference's size" % face)
		for layer: Dictionary in entry["layers"]:
			check(parts.has(layer["part"]), "%s uses only listed parts" % face)
			check(
				float(layer["size"][0]) > 0.0 and float(layer["size"][1]) > 0.0,
				"%s draws every part at a size" % face,
			)

	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VERIFICATION))
	if not check(report != null, "The export verification report exists"):
		return
	check(report["result"] == "PASS", "The last export matched every reference face")
	check(
		report["manifest_sha256"] == FileAccess.get_sha256(MANIFEST),
		"The manifest is the one the export verified",
	)
	for part: String in parts:
		var verified: Dictionary = report["parts"][part]
		check(
			verified["sha256"] == FileAccess.get_sha256(DIRECTORY + part + ".png"),
			"%s is the verified export" % part,
		)


## Width and height from a PNG's header; the art folder is not imported, so it cannot load.
func _png_size(path: String) -> Vector2i:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 24:
		return Vector2i.ZERO
	var header := bytes.slice(16, 24)
	header.reverse()
	return Vector2i(header.decode_u32(4), header.decode_u32(0))
