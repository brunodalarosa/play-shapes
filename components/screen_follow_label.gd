class_name ScreenFollowLabel
extends Label
## Screen text that follows a 3D node, such as a nameplate. It sits centred above the node's
## projected point and hides while the node is behind the camera or gone.

## The node to follow.
@export var target: Node3D
## World offset from the target's origin to the point the label sits above.
@export var world_offset := Vector3.ZERO
## Screen offset in pixels from that point to the label's bottom centre.
@export var screen_offset := Vector2(0.0, -8.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(_delta: float) -> void:
	follow()


## Places the label now. Called every frame; call it after moving the target to avoid a frame
## of lag.
func follow() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if target == null or not is_instance_valid(target) or camera == null:
		visible = false
		return
	var point := target.global_position + world_offset
	if camera.is_position_behind(point) or not target.is_visible_in_tree():
		visible = false
		return
	visible = true
	var anchor := camera.unproject_position(point) + screen_offset
	global_position = anchor - Vector2(size.x * 0.5, size.y)
