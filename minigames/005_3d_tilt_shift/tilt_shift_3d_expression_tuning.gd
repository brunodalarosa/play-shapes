@tool
class_name TiltShift3DExpressionTuning
extends Resource
## When paddle faces change expression and which face each moment shows. Faces never change
## physics. Face names are presets of the shared face manifest, face_a to face_l.

const FACE_MANIFEST := "res://assets/runtime/shape_faces/face_presets.json"

@export_group("Blinking")
## Shortest and longest gap between natural blinks.
@export_range(0.5, 20.0, 0.1, "suffix:s") var blink_interval_min: float = 2.4
@export_range(0.5, 20.0, 0.1, "suffix:s") var blink_interval_max: float = 5.6
## How long a blink keeps the eyes closed.
@export_range(0.02, 1.0, 0.01, "suffix:s") var blink_seconds: float = 0.12

@export_group("Dizzy")
## Applied turning speed at or above which a paddle starts to get dizzy.
@export_range(1.0, 360.0, 1.0, "suffix:degrees/s") var dizzy_degrees_per_second: float = 150.0
## How long the speed must stay that high before the dizzy face shows.
@export_range(0.0, 2.0, 0.01, "suffix:s") var dizzy_onset_seconds: float = 0.15
## How long the dizzy face stays after the speed drops below the threshold.
@export_range(0.0, 5.0, 0.05, "suffix:s") var dizzy_hold_seconds: float = 0.8

@export_group("Startled")
## Smallest closing speed of a new ball contact that startles a paddle, in arena widths/s.
@export_range(0.0, 2.0, 0.005) var startled_minimum_speed: float = 0.05
## How long the startled face shows after a hit.
@export_range(0.05, 3.0, 0.05, "suffix:s") var startled_seconds: float = 0.35
## How much the paddle squashes along its thickness on a hit. Drawing only; the collider
## keeps its size.
@export_range(0.0, 0.5, 0.01) var squash_amount: float = 0.12
## Seconds the squash takes to spring back.
@export_range(0.05, 2.0, 0.05, "suffix:s") var squash_recovery_seconds: float = 0.25

@export_group("Faces")
@export var play_face: String = "face_a"
@export var dizzy_face: String = "face_j"
@export var startled_face: String = "face_i"
@export var countdown_face: String = "face_e"
## Round end: the leading team, the other team, and both teams when tied.
@export var leading_face: String = "face_f"
@export var trailing_face: String = "face_k"
@export var tied_face: String = "face_a"
## Shift results: the winning team, the losing team, and both teams on a draw.
@export var winning_face: String = "face_f"
@export var losing_face: String = "face_k"
@export var draw_face: String = "face_a"


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if (
		not is_finite(blink_interval_min) or not is_finite(blink_interval_max)
		or blink_interval_min < 0.5 or blink_interval_max < blink_interval_min
	):
		errors.append("Tilt Shift 3D expressions: blink gaps need 0.5 s <= shortest <= longest.")
	# Read the manifest's names directly: this Resource loads in the editor and at startup,
	# where it should not hold the face scripts.
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(FACE_MANIFEST))
	var presets: Dictionary = manifest.get("faces", { }) if manifest is Dictionary else { }
	for field: String in faces():
		if not presets.has(String(get(field))):
			errors.append(
				"Tilt Shift 3D expressions: %s is not a face preset." % field.capitalize()
			)
	return errors


## The fields that name a face.
static func faces() -> PackedStringArray:
	return PackedStringArray(
		[
			"play_face",
			"dizzy_face",
			"startled_face",
			"countdown_face",
			"leading_face",
			"trailing_face",
			"tied_face",
			"winning_face",
			"losing_face",
			"draw_face",
		]
	)
