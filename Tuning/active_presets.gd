class_name ActivePresets
extends Resource
## Project-level selector. Assign committed named presets here, save, then relaunch.

@export_group("Minigames")
## Active Bubbles umbrella preset. Restore the Default.tres in the minigame's tuning folder for
## provisional baseline values.
@export
var bubbles: BubblesTuning

## Active Tilt Shift rules/content preset. Default values are provisional, pending owner play.
@export var tilt_shift: TiltShiftTuning

@export_group("Shared categories")
## Active host networking/session preset. Browser-only values intentionally remain in
## web/src/app.ts.
@export
var networking: NetworkingTuning


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if bubbles == null:
		errors.append("Active Presets: Bubbles preset is missing.")
	else:
		errors.append_array(bubbles.validation_errors())
	if tilt_shift == null:
		errors.append("Active Presets: Tilt Shift preset is missing.")
	else:
		errors.append_array(tilt_shift.validation_errors())
	if networking == null:
		errors.append("Active Presets: Networking preset is missing.")
	else:
		errors.append_array(networking.validation_errors())
	return errors
