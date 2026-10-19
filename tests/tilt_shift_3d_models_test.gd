extends TestScript
## The bin of Tilt Shift 3D: the crate copies are byte-identical to the approved KayKit files,
## the runtime bin is the verified export, and its three meshes keep the names, budget, origin
## and cut that let a scene stretch it to any opening.

const DIRECTORY := "res://assets/runtime/minigames/tilt_shift_3d/crate/"
const ART := "res://art/tilt_shift_3d/"
## The SHA-256 of every unchanged crate file, pinned from the 005 asset sources guide.
const SUMS := ART + "SHA256SUMS"
const MESHES: Array[String] = ["BinLeft", "BinMiddle", "BinRight"]
const MATERIALS: Array[String] = ["Body", "Trim"]
const TRIANGLE_CAP := 300
## The side boards' inner faces, where the ends meet the middle.
const CUT := 0.75
const OUTER := 1.0
const HEIGHT := 0.8
const DEPTH := 2.0
const ARENA_WIDTH := 19.2
const OPENINGS: Array[float] = [0.10, 0.20, 0.40]


func _run() -> void:
	var sums := _read_sums()
	check(sums.size() == 4, "The sums list the crate's glTF, buffer, texture and license")
	for file: String in sums:
		check(
			FileAccess.get_sha256(ART + file) == sums[file],
			"The art copy of %s is unchanged" % file,
		)
	check(
		FileAccess.get_sha256(DIRECTORY + "License.txt") == sums["crate/License.txt"],
		"The runtime license is the pack's license",
	)
	check(
		FileAccess.get_sha256(DIRECTORY + "bin.glb")
		== FileAccess.get_sha256(ART + "bin/export/bin.glb"),
		"The runtime bin is the verified export",
	)

	var model := (load(DIRECTORY + "bin.glb") as PackedScene).instantiate() as Node3D
	var parts := _parts(model)
	model.free()
	if parts.is_empty():
		return

	var left: AABB = parts["BinLeft"]["bounds"]
	var middle: AABB = parts["BinMiddle"]["bounds"]
	var right: AABB = parts["BinRight"]["bounds"]
	var whole := left.merge(middle).merge(right)
	check(is_zero_approx(whole.end.y), "The origin is on the top rim line")
	check(is_equal_approx(whole.position.y, -HEIGHT), "The bin hangs %s below its mouth" % HEIGHT)
	check(
		is_equal_approx(whole.position.z, -DEPTH / 2) and is_equal_approx(whole.end.z, DEPTH / 2),
		"The bin's depth is centred on the mouth",
	)
	check(
		is_equal_approx(left.position.x, -OUTER) and is_equal_approx(left.end.x, -CUT),
		"BinLeft holds the left end",
	)
	check(
		is_equal_approx(right.position.x, CUT) and is_equal_approx(right.end.x, OUTER),
		"BinRight holds the right end",
	)

	var off_cut := 0
	for vertex: Vector3 in parts["BinMiddle"]["faces"]:
		off_cut += 0 if is_equal_approx(absf(vertex.x), CUT) else 1
	check(off_cut == 0, "BinMiddle runs straight between the cuts, so it stretches cleanly")

	for opening: float in OPENINGS:
		var width := opening * ARENA_WIDTH
		var shift := (width - 2 * CUT) / 2
		var stretched_middle := middle.size.x * width / (2 * CUT)
		var mouth := (right.position.x + shift) - (left.end.x - shift)
		check(
			is_equal_approx(mouth, width) and is_equal_approx(stretched_middle, width),
			"At %s arena widths the inner mouth is the opening" % opening,
		)


## Bounds and triangle vertices of each mesh, empty when the meshes or materials differ.
func _parts(model: Node3D) -> Dictionary[String, Dictionary]:
	var parts: Dictionary[String, Dictionary] = { }
	var triangles := 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var faces := mesh.mesh.get_faces()
		triangles += faces.size() / 3
		parts[String(mesh.name)] = { "bounds": mesh.transform * mesh.get_aabb(), "faces": faces }
		var materials: Array[String] = []
		for surface: int in mesh.mesh.get_surface_count():
			materials.append(mesh.mesh.surface_get_material(surface).resource_name)
		materials.sort()
		check(materials == MATERIALS, "%s is drawn in Body and Trim" % mesh.name)

	var found: Array[String] = []
	found.assign(parts.keys())
	found.sort()
	if not check(found == MESHES, "The bin has exactly the meshes %s" % [MESHES]):
		return { }
	check(triangles <= TRIANGLE_CAP, "The bin stays within %d triangles" % TRIANGLE_CAP)
	return parts


## Reads the sha256sum-format list into relative path to hash.
func _read_sums() -> Dictionary[String, String]:
	var sums: Dictionary[String, String] = { }
	for line: String in FileAccess.get_file_as_string(SUMS).split("\n", false):
		var parts := line.split("  ")
		sums[parts[1]] = parts[0]

	return sums
