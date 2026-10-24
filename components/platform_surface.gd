@tool
class_name PlatformSurface
extends StaticBody3D
## A landing on the plane-locked platform layer. One-way landings are entered from below and
## solid from above; the drop rule is independent of that.

enum DropRule {
	OPEN,
	CLOSED,
}

## Members of this group are the landings a PlatformMotor may pass through or drop through.
const GROUP := &"platform_surfaces"

## Open permits deliberate FALL; Closed rejects FALL. Does not change underside collision.
@export_enum("Open", "Closed") var drop_rule: int = DropRule.OPEN
## A one-way landing lets bodies rise through it from below. Clear this for solid ground.
@export var one_way: bool = true

# Every motor asks for the bounds of every landing each step, so they are kept until the
# landing moves. Its collision shapes are not resized or moved inside it at runtime.
var _bounds := AABB()
var _bounds_placement := Transform3D()
var _bounds_known := false


func _enter_tree() -> void:
	add_to_group(GROUP)


## The world-space box of every enabled collision shape.
func world_bounds() -> AABB:
	var placement := global_transform
	if _bounds_known and placement == _bounds_placement:
		return _bounds
	var bounds := AABB()
	var found := false
	for child: Node in get_children():
		if child is CollisionShape3D and not child.disabled and child.shape != null:
			var box: AABB = child.global_transform * child.shape.get_debug_mesh().get_aabb()
			bounds = bounds.merge(box) if found else box
			found = true
	_bounds = bounds
	_bounds_placement = placement
	_bounds_known = true
	return bounds


## The height a body stands at on this landing.
func top() -> float:
	return world_bounds().end.y
