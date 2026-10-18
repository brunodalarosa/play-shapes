extends TestScript
## The models of Bubbles and jellyfishes 3D: the library copies are byte-identical to the
## approved sources and every runtime model loads as a scene with meshes.

const DIRECTORY := "res://assets/runtime/minigames/bubbles_3d/"
## The SHA-256 of every unchanged library copy, pinned from the 004 asset sources guide.
const SUMS := "res://art/bubbles_3d/SHA256SUMS"
## Library files that only feed the Blender sources and have no runtime copy.
const ART_ONLY_FOLDERS: Array[String] = ["jellyfish", "pufferfish"]
const PROPS: Array[String] = [
	"coral/Tree_Bare_2_A_Color1.gltf",
	"coral/Tree_Bare_1_C_Color1.gltf",
	"kelp/Grass_2_D_Singlesided_Color1.gltf",
	"kelp/Grass_1_C_Color1.gltf",
	"rocks/forest_nature/Rock_3_M_Color1.gltf",
	"rocks/forest_nature/Rock_1_L_Color1.gltf",
	"rocks/space_base_bits/rocks_A.gltf",
	"mug/cup.glb",
	"bottle/bottle_A_green.gltf",
]


func _run() -> void:
	var sums := _read_sums()
	check(sums.size() == 39, "The sums list every copied library file")
	for file: String in sums:
		var expected: String = sums[file]
		check(
			FileAccess.get_sha256(SUMS.get_base_dir().path_join(file)) == expected,
			"The art copy of %s is unchanged" % file,
		)
		if file.get_slice("/", 0) in ART_ONLY_FOLDERS:
			continue
		check(
			FileAccess.get_sha256(DIRECTORY + file) == expected,
			"The runtime copy of %s is unchanged" % file,
		)

	for prop: String in PROPS:
		var model := _instantiate(prop)
		check(not _meshes(model).is_empty(), "%s loads with meshes" % prop)
		model.free()


## Reads the sha256sum-format list into relative path to hash.
func _read_sums() -> Dictionary[String, String]:
	var sums: Dictionary[String, String] = { }
	for line: String in FileAccess.get_file_as_string(SUMS).split("\n", false):
		var parts := line.split("  ")
		sums[parts[1]] = parts[0]

	return sums


func _instantiate(file: String) -> Node3D:
	var scene := load(DIRECTORY + file) as PackedScene
	return scene.instantiate() as Node3D


func _meshes(model: Node) -> Array[Node]:
	return model.find_children("*", "MeshInstance3D", true, false)
