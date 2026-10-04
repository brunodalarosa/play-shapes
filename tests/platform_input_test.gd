extends TestScript
## Shared classifier and hostile/coalesced snapshot boundary cases.


func _run() -> void:
	for y: float in [-1.0, 1.0]:
		var vertical := "crouch" if y < 0.0 else "look_up"
		check(
			PlatformInput.classify(Vector2(0, y), "neutral") == vertical,
			"Straight vertical stance",
		)
		check(
			PlatformInput.classify(Vector2(0.7, y * 0.7), vertical) == "move",
			"Diagonal exits stance",
		)
		var band := Vector2(sin(deg_to_rad(24.0)), y * cos(deg_to_rad(24.0)))
		check(
			PlatformInput.classify(band, "move") == "move"
			and PlatformInput.classify(band, vertical) == vertical,
			"Sector hysteresis matches phone",
		)
		check(
			PlatformInput.validate(_snapshot(band, vertical)).accepted
			and PlatformInput.validate(_snapshot(band, "move")).accepted,
			"Coalesced sector hints retain either valid history",
		)
	check(
		PlatformInput.classify(Vector2(0, 0.18), "neutral") == "neutral"
		and PlatformInput.classify(Vector2(0, 0.18), "look_up") == "look_up",
		"Radial hysteresis",
	)
	var radial_release := PlatformInput.validate(_snapshot(Vector2(0, 0.18), "look_up"))
	check(radial_release.accepted, "Coalesced radial release")
	var near_boundary := { "horizontal": 0.0, "vertical": 0.160000001, "stance": "look_up" }
	check(
		PlatformInput.validate(near_boundary).accepted,
		"JSON precision near radial boundary survives Vector2 narrowing",
	)
	for degrees: float in [20.0, 28.0]:
		var x := sin(deg_to_rad(degrees))
		var y := -cos(deg_to_rad(degrees))
		check(
			PlatformInput.validate({ "horizontal": x, "vertical": y, "stance": "crouch" }).accepted,
			"Exact angular boundary preserves a valid phone hint",
		)
	for axes: Vector2 in [
		Vector2(INF, 0),
		Vector2(NAN, 0),
		Vector2(0, INF),
		Vector2(0, NAN),
		Vector2(1, 1),
		Vector2(0, -1.1),
	]:
		var rejected_axes := PlatformInput.validate(_snapshot(axes, "move"))
		check(not rejected_axes.accepted, "Reject nonfinite/out-of-disk axes")
	for hint: Variant in ["crouch", "look_up", "neutral", "unknown", 1, { }]:
		var rejected_stance := PlatformInput.validate(_snapshot(Vector2(0.7, 0.7), hint))
		check(not rejected_stance.accepted, "Reject forged/nonstring stance")
	check(not PlatformInput.validate({ "horizontal": 0 }).accepted, "Require complete snapshot")
	var fall := _snapshot(Vector2(0, -1), "crouch")
	fall.action = "fall"
	check(
		PlatformInput.validate(fall, "fall").accepted
		and not PlatformInput.validate(fall, "jump").accepted,
		"Explicit action matches release type",
	)
	fall.action = "jump"
	check(not PlatformInput.validate(fall, "jump").accepted, "Jump never replaces crouched FALL")
	var neutral := _snapshot(Vector2.ZERO, "neutral")
	neutral.action = "fall"
	check(not PlatformInput.validate(neutral, "fall").accepted, "Fall requires downward intent")


func _snapshot(axes: Vector2, hint: Variant) -> Dictionary:
	return { "horizontal": axes.x, "vertical": axes.y, "stance": hint }
