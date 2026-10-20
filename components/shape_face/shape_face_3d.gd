class_name ShapeFace3D
extends Node3D
## A face drawn on a 3D character: one flat, unlit quad per part, facing +Z, centred on this
## node and [member height] world units tall. Set [member expressions] to let the node pick the
## face and its blinks every frame, or set [member face_name] and [member blinking] directly.

## Gap in depth between stacked parts, so later layers draw over earlier ones.
const LAYER_GAP := 0.0015

static var _materials: Dictionary[String, StandardMaterial3D] = { }

## The face box's height in world units; the width follows the preset's aspect.
@export var height := 0.5:
	set(value):
		height = maxf(value, 0.001)
		_rebuild()
@export var face_name := "face_a":
	set(value):
		if value != face_name:
			face_name = value
			_rebuild()
@export var blinking := false:
	set(value):
		if value != blinking:
			blinking = value
			_rebuild()

## When set, the node shows this stack's face and blinks each frame.
var expressions: ShapeFaceExpressions
## Seconds for [member expressions]; replace it to drive the face from another clock.
var clock := func() -> float:
	return Time.get_ticks_msec() / 1000.0
var manifest := ShapeFaceManifest.shared()
var _quads: Array[MeshInstance3D] = []


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	if expressions == null:
		return
	var now: float = clock.call()
	face_name = expressions.face_at(now)
	blinking = expressions.blinking_at(now)


## The preset drawn now, blink included.
func drawn_face() -> ShapeFaceManifest.Face:
	return manifest.blinked(face_name) if blinking else manifest.face(face_name)


## The quads drawn now, one per layer, in drawing order.
func quads() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for quad: MeshInstance3D in _quads:
		if quad.visible:
			result.append(quad)
	return result


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var face := drawn_face()
	var layers: Array[ShapeFaceManifest.Layer] = [] if face == null else face.layers
	while _quads.size() < layers.size():
		var quad := MeshInstance3D.new()
		quad.mesh = QuadMesh.new()
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(quad)
		_quads.append(quad)
	for index: int in _quads.size():
		var quad := _quads[index]
		quad.visible = index < layers.size()
		if not quad.visible:
			continue
		var layer := layers[index]
		(quad.mesh as QuadMesh).size = layer.size * height
		quad.position = Vector3(
			layer.center.x * height,
			-layer.center.y * height,
			LAYER_GAP * index,
		)
		# Manifest turns are clockwise on screen, which is a negative turn about +Z.
		quad.rotation = Vector3(0.0, 0.0, -deg_to_rad(layer.rotation_degrees))
		quad.material_override = _material(layer.part, layer.mirror, index)


func _material(part: String, mirror: bool, order: int) -> StandardMaterial3D:
	var key := "%s:%s:%d" % [part, mirror, order]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = manifest.texture(part)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.render_priority = order
		# Half eyes are cut flat at their canvas edge; repeating would bleed the far edge in.
		material.texture_repeat = false
		if mirror:
			material.uv1_scale = Vector3(-1.0, 1.0, 1.0)
			material.uv1_offset = Vector3(1.0, 0.0, 0.0)
		_materials[key] = material
	return _materials[key]
