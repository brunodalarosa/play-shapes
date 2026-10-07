@tool
class_name TiltShiftFlowTuning
extends Resource

## Pause between the exclusive cutoff and the next round; never permits late scoring.
@export_range(0.0, 10.0, 0.25, "suffix:s") var intermission_seconds := 3.0
## Personalized phone angle updates per second. Structural transitions are immediate.
@export_range(1, 30, 1, "suffix:Hz") var phone_updates_hz := 15


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(intermission_seconds) or intermission_seconds < 0 or intermission_seconds > 10:
		errors.append("Tilt Shift: intermission must be between 0 and 10 seconds.")
	if phone_updates_hz < 1 or phone_updates_hz > 30:
		errors.append("Tilt Shift: phone updates must be between 1 and 30 Hz.")
	return errors
