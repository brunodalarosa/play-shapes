class_name PlaneWalls3D
extends Node3D
## Four invisible walls around a rectangle of the vertical gameplay plane, on their own physics
## layer. Only bodies whose collision mask includes that layer bounce off them; every other body
## passes through.

## The walled rectangle on the plane, in world units, Y up.
@export var bounds := Rect2(-9.6, -5.4, 19.2, 10.8):
	set(value):
		bounds = value
		_rebuild()
## How thick each wall is beyond the rectangle's edge.
@export var thickness: float = 2.0:
	set(value):
		thickness = maxf(0.01, value)
		_rebuild()
## How far each wall reaches in front of and behind the plane.
@export var depth: float = 4.0:
	set(value):
		depth = maxf(0.01, value)
		_rebuild()
## The physics layer the walls are on. Bodies that should bounce add it to their mask.
@export_flags_3d_physics var collision_layer: int = 1:
	set(value):
		collision_layer = value
		_rebuild()
## Restitution of the walls; how it combines with a body's own is the physics engine's rule.
@export_range(0.0, 1.0, 0.01) var bounce: float = 0.5:
	set(value):
		bounce = clampf(value, 0.0, 1.0)
		_material.bounce = bounce

var _material := PhysicsMaterial.new()


func _init() -> void:
	_material.friction = 0.0
	_material.bounce = bounce


func _ready() -> void:
	_rebuild()


func wall(side: StringName) -> StaticBody3D:
	return get_node_or_null(NodePath(String(side))) as StaticBody3D


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child: Node in get_children():
		remove_child(child)
		child.free()
	var center := bounds.get_center()
	var half := bounds.size * 0.5
	var reach := half + Vector2(thickness, thickness)
	_add_wall(
		&"Left",
		Vector3(center.x - half.x - thickness * 0.5, center.y, 0.0),
		Vector3(thickness, reach.y * 2.0, depth),
	)
	_add_wall(
		&"Right",
		Vector3(center.x + half.x + thickness * 0.5, center.y, 0.0),
		Vector3(thickness, reach.y * 2.0, depth),
	)
	_add_wall(
		&"Bottom",
		Vector3(center.x, center.y - half.y - thickness * 0.5, 0.0),
		Vector3(reach.x * 2.0, thickness, depth),
	)
	_add_wall(
		&"Top",
		Vector3(center.x, center.y + half.y + thickness * 0.5, 0.0),
		Vector3(reach.x * 2.0, thickness, depth),
	)


func _add_wall(side: StringName, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = side
	body.collision_layer = collision_layer
	body.collision_mask = 0
	body.physics_material_override = _material
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
