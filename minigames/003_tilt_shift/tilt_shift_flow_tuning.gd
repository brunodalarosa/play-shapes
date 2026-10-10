@tool
class_name TiltShiftFlowTuning
extends Resource

## Pause between the exclusive cutoff and the next round; never permits late scoring.
@export_range(0.0, 10.0, 0.25, "suffix:s") var intermission_seconds := 3.0
## Personalized phone angle updates per second. Structural transitions are immediate.
@export_range(1, 30, 1, "suffix:Hz") var phone_updates_hz := 15

## Ready-panel deadline in seconds, measured once from panel opening.
@export_range(1.0, 120.0, 1.0) var readiness_seconds := 60.0
## Countdown before START; no active scoring time is consumed.
@export_range(0.1, 10.0, 0.1) var countdown_seconds := 3.0
## Total centered START fade duration before the active clock begins.
@export_range(0.1, 2.0, 0.1) var start_seconds := 0.6


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var ranges := {
		"readiness_seconds": [1.0, 120.0],
		"countdown_seconds": [0.1, 10.0],
		"start_seconds": [0.1, 2.0],
	}
	for field: String in ranges:
		var value := float(get(field))
		if not is_finite(value) or value < ranges[field][0] or value > ranges[field][1]:
			errors.append("Tilt Shift: invalid %s duration." % field)
	if not is_finite(intermission_seconds) or intermission_seconds < 0 or intermission_seconds > 10:
		errors.append("Tilt Shift: intermission must be between 0 and 10 seconds.")
	if phone_updates_hz < 1 or phone_updates_hz > 30:
		errors.append("Tilt Shift: phone updates must be between 1 and 30 Hz.")
	return errors
