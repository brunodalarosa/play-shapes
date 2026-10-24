extends TestScript
## The plane-locked 3D body setup on real Jolt physics: locked bodies stay at depth zero
## without turning, or turning only about the depth axis when asked, the edge walls stop bodies
## that mask their layer and let every other body through, and a screen label sits above the
## node it follows.

const BUBBLE_LAYER := 1 << 0
const OTHER_LAYER := 1 << 1
const WALL_LAYER := 1 << 4


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var walls := PlaneWalls3D.new()
	walls.bounds = Rect2(-4.0, -2.0, 8.0, 4.0)
	walls.collision_layer = WALL_LAYER
	walls.bounce = 0.0
	world.add_child(walls)
	check(walls.get_child_count() == 4, "The walls build one body per edge")
	var right := walls.wall(&"Right")
	check(
		is_equal_approx(right.position.x, 4.0 + walls.thickness * 0.5),
		"The right wall's inner face sits on the rectangle's edge",
	)

	var locked := _ball(world, BUBBLE_LAYER, BUBBLE_LAYER | WALL_LAYER, Vector3.ZERO)
	PlaneLock3D.lock(locked)
	locked.linear_velocity = Vector3(6.0, 0.0, 3.0)
	locked.angular_velocity = Vector3(2.0, 3.0, 4.0)
	var passing := _ball(world, OTHER_LAYER, OTHER_LAYER, Vector3(0.0, 1.0, 0.0))
	PlaneLock3D.lock(passing)
	passing.linear_velocity = Vector3(6.0, 0.0, 0.0)
	var turning := _ball(world, OTHER_LAYER, 0, Vector3(0.0, -1.0, 0.0))
	PlaneLock3D.lock(turning, true)
	turning.angular_velocity = Vector3(2.0, 3.0, 4.0)

	for _frame: int in 120:
		await physics_frame
	check(PlaneLock3D.is_on_plane(locked), "A locked body keeps depth zero and no rotation")
	check(
		locked.global_position.x < 4.0 - 0.4 + 0.05,
		"A body that masks the wall layer stays inside the walls",
	)
	check(passing.global_position.x > 5.0, "A body that does not mask it passes through")
	check(
		not PlaneLock3D.is_on_plane(turning) and PlaneLock3D.is_on_plane(turning, 0.001, true),
		"A body locked with turns kept turns only about the depth axis",
	)

	walls.bounds = Rect2(-2.0, -2.0, 4.0, 4.0)
	check(
		is_equal_approx(walls.wall(&"Right").position.x, 2.0 + walls.thickness * 0.5),
		"Changing the bounds moves the walls",
	)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 10.0)
	world.add_child(camera)
	camera.make_current()
	var target := Node3D.new()
	target.position = Vector3(1.0, 0.5, 0.0)
	world.add_child(target)
	var label := ScreenFollowLabel.new()
	label.text = "Player"
	label.target = target
	label.world_offset = Vector3(0.0, 0.6, 0.0)
	root.add_child(label)
	await process_frame
	label.follow()
	var expected := camera.unproject_position(Vector3(1.0, 1.1, 0.0)) + label.screen_offset
	var bottom_centre := label.global_position + Vector2(label.size.x * 0.5, label.size.y)
	check(label.visible, "The label shows while its target is in front of the camera")
	check(bottom_centre.distance_to(expected) < 0.5, "The label sits above its target")
	target.position.z = 20.0
	label.follow()
	check(not label.visible, "The label hides while its target is behind the camera")
	target.queue_free()
	await process_frame
	label.follow()
	check(not label.visible, "The label hides once its target is gone")


func _ball(parent: Node3D, layer: int, mask: int, at: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.collision_layer = layer
	body.collision_mask = mask
	body.position = at
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	shape.shape = sphere
	body.add_child(shape)
	parent.add_child(body)
	return body
