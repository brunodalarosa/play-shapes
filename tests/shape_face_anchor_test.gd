extends TestScript
## Face placements on a model: reading, rejecting malformed files and writing them back.

const SCRATCH := "user://shape_face_anchor_test.json"


func _run() -> void:
	var cubio := ShapeFaceAnchor.load_file(Cubio3D.FACE_ANCHOR_PATH)
	check(cubio != null and cubio.valid(), "Cubio's face anchor file reads")

	var placement := ShapeFaceAnchor.new()
	placement.offset = Vector2(0.12345678, -0.25)
	placement.height = 0.8
	check(placement.save_file(SCRATCH), "A placement writes to a file")
	var read := ShapeFaceAnchor.load_file(SCRATCH)
	check(
		read != null and read.offset.is_equal_approx(Vector2(0.1235, -0.25))
		and is_equal_approx(read.height, 0.8),
		"It reads back as written, to a tenth of a millimetre",
	)

	for text: String in ["", "[]", '{"offset": [0, 0]}', '{"offset": [0], "height": 1.0}']:
		var file := FileAccess.open(SCRATCH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		check(
			ShapeFaceAnchor.load_file(SCRATCH) == null,
			"Malformed placement %s is refused" % text,
		)
	placement.height = 0.0
	check(not placement.save_file(SCRATCH), "A face with no height is not written")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
