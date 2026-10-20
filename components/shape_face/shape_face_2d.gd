class_name ShapeFace2D
extends Control
## The same composed face as [ShapeFace3D], drawn in a Control for UI such as a player chip.
## The face fits the Control's rectangle, centred, keeping the preset's aspect.

@export var face_name := "face_a":
	set(value):
		face_name = value
		queue_redraw()
@export var blinking := false:
	set(value):
		blinking = value
		queue_redraw()

var manifest := ShapeFaceManifest.shared()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## The face box this Control draws into, in its own coordinates.
func face_rect() -> Rect2:
	var face := _face()
	if face == null or size.x <= 0.0 or size.y <= 0.0:
		return Rect2()
	var height := minf(size.y, size.x / face.box_aspect)
	var box := Vector2(height * face.box_aspect, height)
	return Rect2((size - box) * 0.5, box)


func _draw() -> void:
	var face := _face()
	var box := face_rect()
	if face == null or box.size.y <= 0.0:
		return
	var centre := box.get_center()
	for layer: ShapeFaceManifest.Layer in face.layers:
		var part_size := layer.size * box.size.y
		var flip := Vector2(-1.0, 1.0) if layer.mirror else Vector2.ONE
		# Positive 2D turns are clockwise on screen, as the manifest's are.
		draw_set_transform(
			centre + layer.center * box.size.y,
			deg_to_rad(layer.rotation_degrees),
			flip,
		)
		draw_texture_rect(manifest.texture(layer.part), Rect2(-part_size * 0.5, part_size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _face() -> ShapeFaceManifest.Face:
	return manifest.blinked(face_name) if blinking else manifest.face(face_name)
