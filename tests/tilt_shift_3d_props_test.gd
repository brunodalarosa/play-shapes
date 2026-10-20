extends TestScript
## The factory props, trash emblem and booklet preview of Tilt Shift 3D: the six KayKit props
## are byte-identical to the files the 005 asset sources guide approved, in art and at runtime,
## each imports as a model, and the emblem and preview are unchanged copies.

const ART := "res://art/tilt_shift_3d/props/"
const RUNTIME := "res://assets/runtime/minigames/tilt_shift_3d/"
## The SHA-256 of every copied file, checked against the 005 asset sources guide when copied.
const SUMS := ART + "SHA256SUMS"
const MODELS: Array[String] = [
	"platformer/pipe_90_A_blue.gltf",
	"platformer/pipe_180_B_blue.gltf",
	"platformer/pipe_end_blue.gltf",
	"platformer/structure_C.gltf",
	"resource_bits/Parts_Cog.gltf",
	"city_builder/watertower.gltf",
]


func _run() -> void:
	var sums: Dictionary[String, String] = { }
	for line: String in FileAccess.get_file_as_string(SUMS).split(
		"
",
		false,
	):
		sums[line.substr(66)] = line.substr(0, 64)
	check(sums.size() == 18, "The sums list six models, their buffers, textures and licenses")
	for file: String in sums:
		var hash := sums[file]
		check(FileAccess.get_sha256(ART + file) == hash, "The art copy of %s is unchanged" % file)
		check(
			FileAccess.get_sha256(RUNTIME + "props/" + file) == hash,
			"The runtime copy of %s is unchanged" % file,
		)

	for file: String in MODELS:
		var scene := load(RUNTIME + "props/" + file) as PackedScene
		if not check(scene != null, "%s imports as a scene" % file):
			continue
		var model := scene.instantiate()
		check(not model.find_children("*", "MeshInstance3D").is_empty(), "%s has a mesh" % file)
		model.free()

	check(
		FileAccess.get_sha256(RUNTIME + "trash_badge.png")
		== "52584262a7d1a171981bf93c09f1438eb02e0e002dab3dcf3b2b9dba14051fb6",
		"The trash emblem is the factory's emblem, unchanged",
	)
	check(
		FileAccess.get_sha256(RUNTIME + "tilt_shift_3d_preview.png")
		== "f30118a214159ec53a0ef5f4e13c8b430d82f32fd62d716973f1df5c923d6f04",
		"The booklet preview is the factory's preview, unchanged until a 3D one is supplied",
	)
