class_name FlappyRaceCourseView
extends Node3D
## The course on the shared screen as placeholder stone, the same boxes and coins the phone
## draws, until the cave models replace it. Collision never comes from here: the flight uses the
## course's own boxes.

## How far the hanging stone reaches above its gap, so no zoom shows its end.
const HANGING_REACH := 400.0
const DEPTH := 6.0
const STONE := Color("#d6a86c")
const FLOOR := Color("#b98a55")
const GOLD := Color("#f2c230")
const FINISH := Color("#fff3cb")
## Turns per second of a coin.
const COIN_SPIN := 0.5

var _coins: Array[MeshInstance3D] = []


## Builds the course once; call again only for a new race.
func build(course: FlappyRaceCourse) -> void:
	for child: Node in get_children():
		child.queue_free()
	_coins.clear()

	var flight := course.flight
	_block(_material(FLOOR), flight.start_x - 80.0, flight.finish_x + 80.0, -40.0, 0.0)
	_block(_material(FINISH), flight.finish_x - 0.25, flight.finish_x + 0.25, 0.0, 80.0)
	var stone := _material(STONE)
	for obstacle: FlappyFlightObstacle in flight.obstacles:
		_block(stone, obstacle.x_start, obstacle.x_end, -1.0, obstacle.gap_bottom)
		var top := obstacle.gap_top + HANGING_REACH
		_block(stone, obstacle.x_start, obstacle.x_end, obstacle.gap_top, top)

	var coin := CylinderMesh.new()
	coin.top_radius = 0.5
	coin.bottom_radius = 0.5
	coin.height = 0.18
	coin.radial_segments = 20
	coin.material = _material(GOLD, 0.35)
	for pickup: FlappyFlightPickup in flight.pickups:
		var mesh := MeshInstance3D.new()
		mesh.mesh = coin
		mesh.rotation.x = PI * 0.5
		mesh.scale = Vector3.ONE * pickup.half_size * 2.0
		mesh.position = Vector3(pickup.x, pickup.y, 0.5)
		add_child(mesh)
		_coins.append(mesh)


func coins() -> Array[MeshInstance3D]:
	return _coins


func _process(delta: float) -> void:
	for coin: MeshInstance3D in _coins:
		coin.rotate_object_local(Vector3.UP, TAU * COIN_SPIN * delta)


func _block(material: Material, x0: float, x1: float, y0: float, y1: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(x1 - x0, y1 - y0, DEPTH)
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, -DEPTH * 0.5)
	add_child(mesh)


static func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.9 if metallic == 0.0 else 0.3
	return material
