extends TestScript
## The rounded bar builder: the outline keeps its corner radius whatever the length, the mesh
## and the collider follow the same outline, every triangle faces outwards, and a ball resting
## on the bar meets its true top rather than a scaled box.

const LENGTH := 3.84
const THICKNESS := 0.768
const RADIUS := THICKNESS * 0.35


func _run() -> void:
	var outline := RoundedBar.outline(LENGTH, THICKNESS, RADIUS)
	var bounds := _bounds(outline)
	check(bounds.size.is_equal_approx(Vector2(LENGTH, THICKNESS)), "The outline spans the bar")
	check(bounds.get_center().is_zero_approx(), "The outline is centred on the origin")
	check(_signed_area(outline) > 0.0, "The outline runs counter-clockwise")
	var expected_area := LENGTH * THICKNESS - (4.0 - PI) * RADIUS * RADIUS
	check(absf(_signed_area(outline) - expected_area) < 0.01, "The corners are quarter circles")

	var longer := RoundedBar.outline(LENGTH * 2.0, THICKNESS, RADIUS)
	check(
		(longer[1] - longer[0]).is_equal_approx(outline[1] - outline[0]),
		"A longer bar keeps the same corner, so its ends never stretch",
	)
	var clamped := _bounds(RoundedBar.outline(1.0, 0.2, 5.0))
	check(clamped.size.is_equal_approx(Vector2(1.0, 0.2)), "A large radius is clamped")

	var mesh := RoundedBar.mesh(LENGTH, THICKNESS, THICKNESS, RADIUS)
	var aabb := mesh.get_aabb()
	check(
		aabb.size.is_equal_approx(Vector3(LENGTH, THICKNESS, THICKNESS)),
		"The mesh spans the length, thickness and depth",
	)
	check(_faces_outwards(mesh), "Every triangle of the mesh faces outwards")

	var shape := RoundedBar.shape(LENGTH, THICKNESS, THICKNESS, RADIUS)
	check(shape.points.size() == outline.size() * 2, "The collider has the outline front and back")
	var top := -INF
	for point: Vector3 in shape.points:
		top = maxf(top, point.y)
		check(absf(absf(point.z) - THICKNESS * 0.5) < 0.0001, "The collider has the bar's depth")
	check(is_equal_approx(top, THICKNESS * 0.5), "The collider's top is the bar's top")

	await _rest_on_bar()


func _rest_on_bar() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var bar := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = RoundedBar.shape(LENGTH, THICKNESS, THICKNESS, RADIUS)
	bar.add_child(collider)
	world.add_child(bar)
	var ball := RigidBody3D.new()
	var sphere := CollisionShape3D.new()
	sphere.shape = SphereShape3D.new()
	(sphere.shape as SphereShape3D).radius = 0.3
	ball.add_child(sphere)
	ball.position = Vector3(0.0, 1.5, 0.0)
	world.add_child(ball)
	PlaneLock3D.lock(ball, true)
	ball.gravity_scale = 1.0
	for _frame: int in 120:
		await physics_frame
	var rest := THICKNESS * 0.5 + 0.3
	check(absf(ball.position.y - rest) < 0.03, "A ball comes to rest on the bar's top")
	world.queue_free()


func _faces_outwards(mesh: ArrayMesh) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index: int in range(0, indices.size(), 3):
		var a := vertices[indices[index]]
		var b := vertices[indices[index + 1]]
		var c := vertices[indices[index + 2]]
		var area := (b - a).cross(c - a)
		if area.length() < 0.000001:
			continue
		# Clockwise front faces: the winding normal points into the bar.
		var stored := normals[indices[index]] + normals[indices[index + 1]]
		stored += normals[indices[index + 2]]
		if (-area).dot(stored) <= 0.0:
			return false
	return true


func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		result = result.expand(point)
	return result


func _signed_area(points: PackedVector2Array) -> float:
	var total := 0.0
	for index: int in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		total += a.x * b.y - b.x * a.y
	return total * 0.5
