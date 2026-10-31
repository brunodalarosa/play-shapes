class_name FlappyRacePodium
extends Node3D
## The podium past the finish line, in placeholder stone until the cave art dresses it: three
## raised blocks, second on the left, first tallest in the middle and third on the right, and one
## long low step in front for everyone else. Its origin is the middle of its foot on the floor.

## Width of each raised block, m.
const BLOCK_WIDTH := 4.0
## Heights of the raised blocks for first, second and third, m: even third stands clear above
## the heads of the Cubios on the low step in front.
const BLOCK_HEIGHTS: Array[float] = [6.6, 5.4, 4.4]
## Where each raised block stands for first, second and third, m from the origin.
const BLOCK_OFFSETS: Array[float] = [0.0, -BLOCK_WIDTH, BLOCK_WIDTH]
const BLOCK_DEPTH := 3.0
const STEP_HEIGHT := 0.8
const STEP_DEPTH := 3.0
## Room for one Cubio on the low step, m: wider than its body with its hands.
const STEP_SPACING := 3.4
## The low step holds everyone after third: up to seven of ten players.
const STEP_PLACES := 7
const STONE := Color("#c99a62")
const STEP_STONE := Color("#b98a55")


func _ready() -> void:
	var stone := FlappyRaceCourseView.stone_material(STONE)
	for index: int in BLOCK_HEIGHTS.size():
		var size := Vector3(BLOCK_WIDTH, BLOCK_HEIGHTS[index], BLOCK_DEPTH)
		_box(stone, size, Vector3(BLOCK_OFFSETS[index], size.y * 0.5, -BLOCK_DEPTH * 0.5))
	var width := STEP_SPACING * STEP_PLACES
	var step := Vector3(width, STEP_HEIGHT, STEP_DEPTH)
	var step_stone := FlappyRaceCourseView.stone_material(STEP_STONE)
	_box(step_stone, step, Vector3(0.0, STEP_HEIGHT * 0.5, STEP_DEPTH * 0.5))


## Where the soles of [param place]'s Cubio stand, in the podium's space: on a raised block for
## the top three, on the low step for the rest, fourth leftmost.
static func spot_for(place: int) -> Vector3:
	if place >= 1 and place <= BLOCK_HEIGHTS.size():
		var index := place - 1
		return Vector3(BLOCK_OFFSETS[index], BLOCK_HEIGHTS[index], -BLOCK_DEPTH * 0.5)
	var slot := clampi(place - BLOCK_HEIGHTS.size() - 1, 0, STEP_PLACES - 1)
	var x := (slot - (STEP_PLACES - 1) * 0.5) * STEP_SPACING
	return Vector3(x, STEP_HEIGHT, STEP_DEPTH * 0.5)


## The podium's outline on the plane, m from its origin: for the camera to frame it.
static func outline() -> Rect2:
	var width := STEP_SPACING * STEP_PLACES
	var top := BLOCK_HEIGHTS[0] + FlappyRacePresentation.CUBIO_HEIGHT
	return Rect2(-width * 0.5, 0.0, width, top)


func _box(material: Material, size: Vector3, centre: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = centre
	add_child(mesh)
