class_name TiltShiftMotionTuning
extends Resource
## Frozen per control session. Gain is output degrees per physical in-plane degree.

## Provisional 1:1 gain. Wider trials trade responsiveness against the physical rate limit.
@export_range(0.05, 8.0, 0.05) var gain: float = 1.0
## Continuous mode retains every sampled complete turn, without a rotation stop.
@export var continuous: bool = true
## Bounded comparison only: maximum degrees on either side of the chosen neutral.
@export_range(1.0, 180.0, 1.0, "suffix:degrees") var maximum_degrees: float = 60.0
## Minimum gravity projection in the physical screen plane. Flat poses become unusable.
@export_range(0.01, 0.95, 0.01) var minimum_projection: float = 0.2
## A larger usable-sample gap resumes on the nearest old-neutral branch, without unseen turns.
@export_range(34, 1000, 1, "suffix:ms") var continuity_gap_msec: int = 250


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(gain) or gain < 0.05 or gain > 8.0:
		errors.append("Tilt control: gain must be finite and between 0.05 and 8.")
	if not is_finite(maximum_degrees) or maximum_degrees < 1.0 or maximum_degrees > 180.0:
		errors.append("Tilt control: bounded maximum must be between 1 and 180 degrees.")
	if not is_finite(minimum_projection) or minimum_projection < 0.01 or minimum_projection > 0.95:
		errors.append("Tilt control: minimum projection must be between 0.01 and 0.95.")
	if continuity_gap_msec < 34 or continuity_gap_msec > 1000:
		errors.append("Tilt control: continuity gap must be between 34 and 1000 ms.")
	return errors
