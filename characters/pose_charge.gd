class_name PoseCharge
extends RefCounted
## Deterministic semantic input state. It has no knowledge of animation frames.

var fill_seconds: float = 1.0
var decay_seconds: float = 0.28
var direction: StringName = &""
var charge: float = 0.0
var held: bool = false

func advance(delta: float, requested_direction: StringName) -> void:
	var request_changed := not requested_direction.is_empty() and requested_direction != direction
	held = not requested_direction.is_empty()
	if request_changed:
		direction = requested_direction
		charge = 0.0
		return
	if held:
		charge = minf(charge + delta / maxf(fill_seconds, 0.001), 1.0)
	else:
		charge = maxf(charge - delta / maxf(decay_seconds, 0.001), 0.0)
		if is_zero_approx(charge):
			direction = &""

func is_committed() -> bool:
	return held and is_equal_approx(charge, 1.0)

func reset() -> void:
	direction = &""
	charge = 0.0
	held = false
