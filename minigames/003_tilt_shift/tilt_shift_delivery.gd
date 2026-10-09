@tool
class_name TiltShiftDelivery
extends RefCounted
## Exact integration and midpoint quantiles for linear or smoothstep intensity profiles.


static func total_weight(points: PackedVector2Array) -> float:
	var total := 0.0
	for index: int in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		total += (b.x - a.x) * (a.y + b.y) * 0.5
	return total


static func intensity(points: PackedVector2Array, progress: float, smooth: bool = false) -> float:
	for index: int in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		if progress >= a.x and progress <= b.x:
			var fraction := (progress - a.x) / (b.x - a.x)
			if smooth:
				fraction = fraction * fraction * (3.0 - 2.0 * fraction)
			return lerpf(a.y, b.y, fraction)
	return 0.0


static func schedule(
	count: int,
	points: PackedVector2Array,
	duration_msec: int,
	smooth: bool = false,
) -> PackedInt32Array:
	var result := PackedInt32Array()
	if count <= 0 or points.size() < 2 or duration_msec <= 0:
		return result
	var total := total_weight(points)
	if not is_finite(total) or total <= 0.0:
		return result
	var span := 1
	var consumed := 0.0
	for index: int in count:
		var target := total * (float(index) + 0.5) / float(count)
		while span < points.size() - 1:
			var weight := (points[span].x - points[span - 1].x)
			weight *= (points[span].y + points[span - 1].y) * 0.5
			if consumed + weight > target:
				break
			consumed += weight
			span += 1
		var a := points[span - 1]
		var b := points[span]
		var low := 0.0
		var high := b.x - a.x
		var slope := (b.y - a.y) / high
		for iteration: int in 48:
			var middle := (low + high) * 0.5
			var area := a.y * middle + slope * middle * middle * 0.5
			if smooth:
				var fraction := middle / (b.x - a.x)
				# Integrate smoothstep exactly; segment weight still equals its trapezoid.
				var integral := fraction * fraction * fraction * (1.0 - fraction * 0.5)
				area = a.y * middle + (b.y - a.y) * (b.x - a.x) * integral
			if area < target - consumed:
				low = middle
			else:
				high = middle
		var progress := a.x + (low + high) * 0.5
		var offset := mini(duration_msec - 1, floori(progress * duration_msec))
		if intensity(points, float(offset) / duration_msec, smooth) <= 0.0:
			offset += 1
		if (
			offset >= duration_msec
			or intensity(points, float(offset) / duration_msec, smooth) <= 0.0
		):
			return PackedInt32Array()
		result.append(offset)
	return result
