@tool
class_name PlatformSurface
extends StaticBody2D
## A drop rule independent of the landing shape's existing one-way behavior.

enum DropRule { OPEN, CLOSED }

## Open permits deliberate FALL; Closed rejects FALL. Does not change underside collision.
@export_enum("Open", "Closed")
var drop_rule: int = DropRule.OPEN


func world_bounds() -> Rect2:
	var bounds := Rect2()
	var found := false
	for child: Node in get_children():
		if child is CollisionShape2D and not child.disabled and child.shape != null:
			var rectangle: Rect2 = child.global_transform * child.shape.get_rect()
			bounds = bounds.merge(rectangle) if found else rectangle
			found = true
	return bounds
