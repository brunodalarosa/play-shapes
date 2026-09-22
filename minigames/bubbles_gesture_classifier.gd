class_name BubblesGestureClassifier
extends RefCounted
## Classifies one completed, normalized touch trace. The transport must authenticate its player.

const MAX_POINTS := 128
const MAX_ABSOLUTE_TURN_STEP := 1.6
const MIN_CIRCLE_RADIUS := 0.025


static func classify(trace: Variant, tuning: BubblesTuning) -> Dictionary:
	if tuning == null or not trace is Array:
		return _reject(&"malformed_trace")
	var raw: Array = trace
	if raw.size() < 2 or raw.size() > MAX_POINTS:
		return _reject(&"trace_size")
	var points: Array[Vector2] = []
	for item: Variant in raw:
		if not item is Array or item.size() != 2:
			return _reject(&"malformed_trace")
		var pair: Array = item
		if (typeof(pair[0]) not in [TYPE_FLOAT, TYPE_INT]
				or typeof(pair[1]) not in [TYPE_FLOAT, TYPE_INT]):
			return _reject(&"malformed_trace")
		var x := float(pair[0])
		var y := float(pair[1])
		if not is_finite(x) or not is_finite(y) or x < 0.0 or x > 1.0 or y < 0.0 or y > 1.0:
			return _reject(&"out_of_bounds")
		points.append(Vector2(x, y))

	var center := Vector2.ZERO
	for point: Vector2 in points:
		center += point
	center /= float(points.size())
	var radius := 0.0
	for point: Vector2 in points:
		radius += point.distance_to(center)
	radius /= float(points.size())
	var signed_turn := 0.0
	var absolute_turn := 0.0
	var heading_turn := 0.0
	var smooth := true
	var radial_error := 0.0
	for index: int in points.size():
		radial_error = maxf(radial_error, absf(points[index].distance_to(center) - radius))
		if index == 0:
			continue
		var before := points[index - 1] - center
		var after := points[index] - center
		if before.length() < MIN_CIRCLE_RADIUS * 0.5 or after.length() < MIN_CIRCLE_RADIUS * 0.5:
			smooth = false
			continue
		var step := before.angle_to(after)
		if absf(step) > MAX_ABSOLUTE_TURN_STEP:
			smooth = false
		signed_turn += step
		absolute_turn += absf(step)
		if index >= 2:
			var previous_segment := points[index - 1] - points[index - 2]
			var current_segment := points[index] - points[index - 1]
			if previous_segment.length_squared() > 0.0 and current_segment.length_squared() > 0.0:
				heading_turn += absf(previous_segment.angle_to(current_segment))

	# Once the path has made a half-turn it is circular intent. A failed or
	# incomplete circle cannot be reinterpreted as a late swipe.
	if points.size() >= 6 and heading_turn >= PI * 0.75:
		var required_turn := TAU * float(tuning.circles_to_charge)
		var closed := points[0].distance_to(points[-1]) <= radius * tuning.circle_tolerance
		var consistent := absolute_turn > 0.0 and absf(signed_turn) / absolute_turn >= 0.85
		var radial_ok := radius >= MIN_CIRCLE_RADIUS and radial_error <= radius * tuning.circle_tolerance
		if smooth and closed and consistent and radial_ok and absf(signed_turn) >= required_turn * 0.9:
			return {"accepted": true, "action": &"spin", "direction": &"clockwise" if signed_turn > 0.0 else &"counterclockwise"}
		return {"accepted": true, "action": &"none", "reason": &"incomplete_circle"}

	var displacement := points[-1] - points[0]
	if displacement.length() >= tuning.swipe_min_distance:
		return {"accepted": true, "action": &"swipe", "direction": displacement.normalized(), "strength": tuning.swipe_impulse}
	return {"accepted": true, "action": &"none", "reason": &"too_short"}


static func _reject(code: StringName) -> Dictionary:
	return {"accepted": false, "code": code}
