class_name ShapeFacePreset
extends RefCounted
## A named face: its box and the parts placed in it, in drawing order.

## Eyes fixed by a pose, including closed eyes and symbolic eyes.
const UNBLINKING_EYES: Array[String] = [
	"facial_part_eye_closed_down",
	"facial_part_eye_closed_up",
	"facial_part_eye_x",
	"facial_part_eye_squeezed",
	"facial_part_eye_spiral",
	"facial_part_eye_heart",
	"facial_part_eye_star",
	"facial_part_eye_money",
]
const EYE_PREFIX := "facial_part_eye_"

var name := ""
## Width over height.
var box_aspect := 1.0
## The reference image's height in source pixels; part sizes in pixels divide by it.
var source_height := 1.0
var layers: Array[ShapeFaceLayer] = []


## True for an eye part that a blink may close.
static func can_close(part: String) -> bool:
	return part.begins_with(EYE_PREFIX) and part not in UNBLINKING_EYES


## True when one of its eyes may close for a blink.
func can_blink() -> bool:
	for layer: ShapeFaceLayer in layers:
		if can_close(layer.part):
			return true
	return false
