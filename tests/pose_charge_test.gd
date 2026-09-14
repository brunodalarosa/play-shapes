extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := PoseCharge.new()
	state.fill_seconds = 1.0
	state.decay_seconds = 0.25

	state.advance(0.0, &"up")
	if not _check(state.direction == &"up" and state.charge == 0.0, "New direction begins at zero"):
		return
	state.advance(0.4, &"up")
	if not _check(is_equal_approx(state.charge, 0.4), "Held input fills deterministically"):
		return
	state.advance(0.05, &"")
	if not _check(is_equal_approx(state.charge, 0.2) and state.direction == &"up", "Release decays without immediately losing direction"):
		return
	state.advance(0.05, &"up")
	if not _check(state.charge > 0.2, "Rapid taps can retain and accumulate charge"):
		return
	state.advance(0.1, &"left")
	if not _check(state.direction == &"left" and state.charge == 0.0, "Direction change resets charge"):
		return
	state.advance(1.0, &"left")
	if not _check(state.is_committed(), "Full held charge commits"):
		return
	state.advance(0.5, &"left")
	if not _check(state.is_committed(), "Committed pose remains held"):
		return
	state.advance(0.25, &"")
	if not _check(state.direction.is_empty() and state.charge == 0.0 and not state.is_committed(), "Release fully unwinds"):
		return
	print("Pose charge checks passed")
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
