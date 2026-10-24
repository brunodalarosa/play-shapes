class_name TiltShift3DFactory
extends Node3D
## The quiet toy factory behind the gameplay plane: a warm cream wall with a soft vertical
## gradient, a few pale, recoloured KayKit props in the upper corners and side margins, and
## soft light. Nothing here collides or sits on or in front of the plane.

const PROPS := "res://assets/runtime/minigames/tilt_shift_3d/props/"
## Depth of the wall, well behind the bins' back boards.
const WALL_DEPTH := -3.5
const WALL_SIZE := Vector2(48.0, 28.0)


## One placed prop: the model, where its base sits, its height and turn, and which pale
## colour it takes.
class Placement:
	extends RefCounted

	var model := ""
	var position := Vector3.ZERO
	var height := 1.0
	var rotation_degrees := Vector3.ZERO
	var tint := &"grey"


	func _init(path: String, at: Vector3, tall: float, turn: Vector3, colour: StringName) -> void:
		model = path
		position = at
		height = tall
		rotation_degrees = turn
		tint = colour


var wall: MeshInstance3D
var props: Array[Node3D] = []


## Builds the wall and props in [param look]'s colours.
func configure(look: TiltShift3DPresentationTuning) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	props.clear()

	var gradient := Gradient.new()
	gradient.set_color(0, look.wall_top_color)
	gradient.set_color(1, look.wall_bottom_color)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 4
	texture.height = 128
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	var quad := QuadMesh.new()
	quad.size = WALL_SIZE
	wall = MeshInstance3D.new()
	wall.name = "Wall"
	wall.mesh = quad
	wall.material_override = material
	wall.position = Vector3(0.0, 0.0, WALL_DEPTH)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)

	var colours := {
		&"teal": look.prop_teal_color,
		&"sky": look.prop_sky_color,
		&"grey": look.prop_grey_color,
	}
	for placement: Placement in placements():
		var prop := _prop(placement, colours[placement.tint])
		if prop != null:
			props.append(prop)


## Where the props stand, framing the arena without reaching into its open upper middle.
static func placements() -> Array[Placement]:
	return [
		Placement.new(
			"city_builder/watertower.gltf",
			Vector3(-9.0, 2.3, -2.8),
			2.8,
			Vector3(0.0, 30.0, 0.0),
			&"grey",
		),
		Placement.new(
			"resource_bits/Parts_Cog.gltf",
			Vector3(9.0, 3.4, -3.0),
			1.8,
			Vector3.ZERO,
			&"sky",
		),
		Placement.new(
			"platformer/pipe_90_A_blue.gltf",
			Vector3(-9.6, -3.3, -2.8),
			1.8,
			Vector3(0.0, 90.0, 0.0),
			&"teal",
		),
		Placement.new(
			"platformer/pipe_180_B_blue.gltf",
			Vector3(9.6, -3.4, -3.0),
			1.6,
			Vector3(0.0, -90.0, 0.0),
			&"teal",
		),
	]


func _prop(placement: Placement, colour: Color) -> Node3D:
	var scene := load(PROPS + placement.model) as PackedScene
	if scene == null:
		return null
	var prop := scene.instantiate() as Node3D
	var bounds := AABB()
	var first := true
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D"):
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bounds = mesh.get_aabb() if first else bounds.merge(mesh.get_aabb())
		first = false
	prop.scale = Vector3.ONE * placement.height / maxf(bounds.size.y, 0.001)
	prop.rotation_degrees = placement.rotation_degrees
	prop.position = placement.position
	add_child(prop)
	return prop
