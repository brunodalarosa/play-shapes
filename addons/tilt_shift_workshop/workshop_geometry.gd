@tool
extends RefCounted
## Measurements are diagnostics. They never move content or certify strategy.


static func inspect(profile: TiltShiftTuning, tolerance: float) -> Dictionary:
	var warnings := PackedStringArray()
	var edges: Array[TiltShiftState.Neighbor] = []
	var corridors: Array[Vector2] = []
	var clearances: Array[Dictionary] = []
	var size := profile.paddle_layout.arena_size
	var paddles := profile.paddle_layout.paddles
	var physics := profile.physics
	var radius := 0.0
	var blocked: Array[Vector2] = []
	for index: int in paddles.size():
		var paddle := paddles[index]
		if paddle == null or not paddle.position.is_finite():
			warnings.append("Missing or non-finite paddle; repair before viewing guides.")
			continue
		radius = profile.paddle_layout.paddle_size(paddle.team, physics).length() * 0.5
		var point := paddle.position
		var wall := minf(minf(point.x, size.x - point.x), minf(point.y, size.y - point.y))
		wall -= radius
		clearances.append({ "id": paddle.paddle_id, "wall": wall })
		if wall < 0.0:
			warnings.append("%s: swept wall clearance %.4f widths." % [paddle.paddle_id, wall])
		var best := INF
		for other: TiltShiftPaddle in paddles:
			if other == null or other == paddle:
				continue
			var reflected := Vector2(size.x - point.x, point.y)
			best = minf(best, reflected.distance_to(other.position))
		if best > tolerance:
			warnings.append("%s: reflection discrepancy %.4f widths." % [paddle.paddle_id, best])
		for second: int in range(index + 1, paddles.size()):
			var other := paddles[second]
			if other == null:
				continue
			var other_size := profile.paddle_layout.paddle_size(other.team, physics)
			var other_radius := other_size.length() * 0.5
			var distance := point.distance_to(other.position)
			clearances.append(
				{
					"id": paddle.paddle_id,
					"other": other.paddle_id,
					"gap": distance - radius - other_radius,
					"distance": distance,
				}
			)
			if distance < radius + other_radius:
				warnings.append(
					"%s / %s: swept overlap %.4f widths."
					% [paddle.paddle_id, other.paddle_id, radius + other_radius - distance]
				)
		blocked.append(
			Vector2(
				maxf(0.0, point.x - radius - physics.ball_radius),
				minf(size.x, point.x + radius + physics.ball_radius),
			)
		)
	if not paddles.has(null):
		edges = TiltShiftPaddleAllocator.neighbors(profile.paddle_layout, profile.neighbor_distance)
	blocked.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			return a.x < b.x,
	)
	var right := physics.ball_radius
	for interval: Vector2 in blocked:
		if interval.x > right:
			corridors.append(Vector2(right, interval.x))
		right = maxf(right, interval.y)
	if right < size.x - physics.ball_radius:
		corridors.append(Vector2(right, size.x - physics.ball_radius))
	_spacing(paddles, tolerance, warnings)
	return {
		"warnings": warnings,
		"neighbors": edges,
		"corridors": corridors,
		"clearances": clearances,
		"radius": radius,
	}


static func _spacing(
	paddles: Array[TiltShiftPaddle],
	tolerance: float,
	warnings: PackedStringArray,
) -> void:
	var rows: Array[Array] = []
	for paddle: TiltShiftPaddle in paddles:
		if paddle == null:
			continue
		var found := false
		for row: Array in rows:
			if absf(row[0].position.y - paddle.position.y) <= tolerance:
				row.append(paddle)
				found = true
				break
		if not found:
			rows.append([paddle])
	var heights := PackedFloat32Array()
	for row: Array in rows:
		heights.append(row[0].position.y)
		row.sort_custom(
			func(a: TiltShiftPaddle, b: TiltShiftPaddle) -> bool:
				return a.position.x < b.position.x,
		)
		var gaps := PackedFloat32Array()
		for index: int in range(1, row.size()):
			gaps.append(row[index].position.x - row[index - 1].position.x)
		if gaps.size() >= 2 and float(Array(gaps).max()) - float(Array(gaps).min()) > tolerance:
			warnings.append(
				"Row y=%.4f: spacing %.4f–%.4f widths."
				% [row[0].position.y, float(Array(gaps).min()), float(Array(gaps).max())]
			)
	heights.sort()
	var gaps := PackedFloat32Array()
	for index: int in range(1, heights.size()):
		gaps.append(heights[index] - heights[index - 1])
	if gaps.size() >= 2 and float(Array(gaps).max()) - float(Array(gaps).min()) > tolerance:
		warnings.append(
			"Row heights: spacing %.4f–%.4f widths."
			% [float(Array(gaps).min()), float(Array(gaps).max())]
		)
