class_name Bubbles3DJellyfishSwarm
extends Node3D
## Many jellyfishes drawn as one instanced batch per model mesh, so a full arena costs a few draw
## calls. Each jellyfish has a position, a size and a white flash; all face the camera.

const MODEL: PackedScene = preload(
	"res://assets/runtime/minigames/bubbles_3d/jellyfish/jellyfish.glb"
)
const BODY_SHADER: Shader = preload("res://minigames/004_3d_bubbles/jellyfish_body.gdshader")
const MESH_NAMES: Array[String] = ["Bell", "Tentacles", "Eyes"]
## Width of the model at scale one, in world units.
const MODEL_WIDTH := 0.55
## The model faces -Z; turning it around faces the camera.
const FACING := Basis(Vector3.UP, PI)

static var _meshes: Array[Mesh] = []
static var _mesh_transforms: Array[Transform3D] = []

var _batches: Array[MultiMesh] = []


## Prepares room for [param capacity] jellyfishes, none of them shown yet.
func setup(capacity: int) -> void:
	_prepare_meshes()
	for child: Node in get_children():
		child.free()
	_batches.clear()
	for index: int in _meshes.size():
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_custom_data = true
		batch.mesh = _meshes[index]
		batch.instance_count = maxi(0, capacity)
		batch.visible_instance_count = 0
		var drawer := MultiMeshInstance3D.new()
		drawer.name = MESH_NAMES[index]
		drawer.multimesh = batch
		drawer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(drawer)
		_batches.append(batch)


func capacity() -> int:
	return 0 if _batches.is_empty() else _batches[0].instance_count


func visible_count() -> int:
	return 0 if _batches.is_empty() else _batches[0].visible_instance_count


func set_visible_count(count: int) -> void:
	for batch: MultiMesh in _batches:
		batch.visible_instance_count = clampi(count, 0, batch.instance_count)


## Places jellyfish [param index] at [param at] in this node's space, [param width] wide, flashed
## white by [param flash] from 0 to 1 and tilted by [param tilt] radians.
func set_jellyfish(index: int, at: Vector3, width: float, flash: float, tilt := 0.0) -> void:
	var size := maxf(0.0001, width / MODEL_WIDTH)
	var basis := Basis(Vector3.BACK, tilt) * FACING.scaled(Vector3.ONE * size)
	var placed := Transform3D(basis, at)
	for batch_index: int in _batches.size():
		var batch := _batches[batch_index]
		if index < 0 or index >= batch.instance_count:
			return
		batch.set_instance_transform(index, placed * _mesh_transforms[batch_index])
		batch.set_instance_custom_data(index, Color(clampf(flash, 0.0, 1.0), 0.0, 0.0, 0.0))


static func _prepare_meshes() -> void:
	if not _meshes.is_empty():
		return
	var model := MODEL.instantiate() as Node3D
	for mesh_name: String in MESH_NAMES:
		var source := model.find_child(mesh_name, true, false) as MeshInstance3D
		var mesh := source.mesh.duplicate() as Mesh
		if mesh_name != "Eyes":
			for surface: int in mesh.get_surface_count():
				var original := mesh.surface_get_material(surface) as BaseMaterial3D
				var material := ShaderMaterial.new()
				material.shader = BODY_SHADER
				material.set_shader_parameter(&"albedo", original.albedo_color)
				mesh.surface_set_material(surface, material)
		_meshes.append(mesh)
		_mesh_transforms.append(source.transform)
	model.free()
