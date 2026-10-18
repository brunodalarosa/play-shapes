extends TestScript
## The models of Bubbles and jellyfishes 3D: the library copies are byte-identical to the
## approved sources, every runtime model loads as a scene with meshes, and the adapted
## creatures keep their named meshes, triangle budgets, origins and facing.

const DIRECTORY := "res://assets/runtime/minigames/bubbles_3d/"
## The SHA-256 of every unchanged library copy, pinned from the 004 asset sources guide.
const SUMS := "res://art/bubbles_3d/SHA256SUMS"
const ART := "res://art/bubbles_3d/"
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

	_check_jellyfish()


func _check_jellyfish() -> void:
	var parts := _creature("jellyfish", ["Bell", "Tentacles", "Eyes"], 600)
	if parts.is_empty():
		return

	var bell := parts["Bell"]
	check(bell.get_center().is_zero_approx(), "The jellyfish origin is the bell centre")
	check(parts["Eyes"].end.z < bell.get_center().z, "The jellyfish eyes face -Z")
	check(
		parts["Tentacles"].position.y < bell.position.y - 0.15,
		"The jellyfish tentacles hang below the bell",
	)
	check(
		is_equal_approx(snappedf(bell.size.y / bell.size.x, 0.01), 0.7),
		"The jellyfish bell is 0.7 as tall as it is wide",
	)


## Loads an adapted creature and returns the bounds of each named mesh, empty on failure.
func _creature(name: String, names: Array[String], triangle_cap: int) -> Dictionary[String, AABB]:
	var file := "%s/%s.glb" % [name, name]
	check(
		FileAccess.get_sha256(DIRECTORY + file)
		== FileAccess.get_sha256(ART + name + "/export/%s.glb" % name),
		"The runtime %s is the verified export" % name,
	)

	var model := _instantiate(file)
	var parts: Dictionary[String, AABB] = { }
	var triangles := 0
	for node: Node in _meshes(model):
		var mesh := node as MeshInstance3D
		parts[String(mesh.name)] = mesh.transform * mesh.get_aabb()
		triangles += mesh.mesh.get_faces().size() / 3
	model.free()

	var found: Array[String] = []
	found.assign(parts.keys())
	found.sort()
	var expected := names.duplicate()
	expected.sort()
	if not check(found == expected, "The %s has exactly the meshes %s" % [name, names]):
		return { }
	check(triangles <= triangle_cap, "The %s stays within %d triangles" % [name, triangle_cap])
	return parts


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
