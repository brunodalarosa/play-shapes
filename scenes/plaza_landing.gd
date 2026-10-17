@tool
class_name PlazaLanding
extends Node3D
## Marks the top centre of a landing where it crosses the plaza's action plane. The lobby
## world builds the matching 2D platform from it, so scenery and collision share one placement.

## Landing width along the action plane, in world units.
@export_range(0.1, 40.0, 0.05, "suffix:H") var width: float = 2.0:
	set(value):
		width = value
		update_gizmos()
## Open permits a deliberate FALL through the landing; Closed rejects it.
@export_enum("Open", "Closed") var drop_rule: int = PlatformSurface.DropRule.OPEN
## Landings are one-way platforms, entered from below. Clear this for solid ground.
@export var one_way: bool = true


## The landing's top edge as a segment in action-plane coordinates.
func plane_span() -> Rect2:
	var top := global_position
	return Rect2(top.x - width * 0.5, top.y, width, 0.0)
