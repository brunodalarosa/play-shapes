extends TestScript
## The workshop's tuning model on the Flappy Race preset: rows generated from the tuning
## Resources, live and restart values, undo, edit counts and differences.

const DEFAULT_PATH := "res://minigames/006_flappy_race/tuning/Default.tres"


func _run() -> void:
	var preset: Resource = load(DEFAULT_PATH)
	var tuning := WorkshopTuning.new(WorkshopTuning.copy(preset), preset)
	_check_discovery(tuning)
	_check_live_and_restart(tuning)
	_check_undo(tuning)
	_check_copy_part(tuning, preset)


func _check_discovery(tuning: WorkshopTuning) -> void:
	var tabs := PackedStringArray()
	for tunable: WorkshopTunable in tuning.tunables:
		if not tabs.has(tunable.tab):
			tabs.append(tunable.tab)
	check(tabs == PackedStringArray(["Race", "Flight", "Course", "View"]), "One tab per part")

	var gravity := tuning.tunable("flight/gravity")
	check(gravity != null and gravity.unit == "m/s²", "A value keeps its unit")
	check(gravity != null and gravity.help.begins_with("Downward acceleration"), "Help is read")
	check(gravity != null and gravity.maximum == 200.0, "A value keeps its range")
	var hearts := tuning.tunable("flight/heart_count")
	check(hearts != null and hearts.kind == WorkshopTunable.Kind.WHOLE, "Whole numbers stay whole")
	check(hearts != null and hearts.group == "Hearts", "Rows sit in their export group")
	var gap_start := tuning.tunable("course/gap_height:0")
	var gap_end := tuning.tunable("course/gap_height:1")
	check(gap_start != null and gap_end != null, "A curve gives a row for each end")
	check(gap_end != null and is_equal_approx(tuning.value(gap_end), 7.0), "Curve end is read")
	check(tuning.tunable("countdown_seconds").tab == "Race", "The preset's own values are Race")

	var live := tuning.tunables.filter(
		func(each: WorkshopTunable) -> bool:
			return each.live,
	)
	check(not live.is_empty(), "Some values are live")
	for each: WorkshopTunable in live:
		check(
			each.key().begins_with("view/") and each.group == "Shared screen",
			"Only Shared screen",
		)


func _check_live_and_restart(tuning: WorkshopTuning) -> void:
	var smoothing := tuning.tunable("view/camera_smoothing_seconds")
	var gravity := tuning.tunable("flight/gravity")
	var running := tuning.running
	var live_seen: Array[WorkshopTunable] = []
	tuning.live_changed.connect(
		func(each: WorkshopTunable) -> void:
			live_seen.append(each),
	)

	tuning.set_value(smoothing, 1.0)
	check(running.view.camera_smoothing_seconds == 1.0, "A live value reaches the game at once")
	check(live_seen == [smoothing], "The game hears about a live value")
	tuning.set_value(gravity, 80.0)
	check(running.flight.gravity == 75.0, "A restart value waits")
	check(tuning.pending() == [gravity], "It is listed as waiting")
	check(tuning.edit_count() == 2, "Both count as unsaved edits")

	var restarted := tuning.restart()
	check(restarted.flight.gravity == 80.0, "A restart applies it")
	check(tuning.pending().is_empty(), "Nothing waits after a restart")
	check(tuning.saved.flight.gravity == 75.0, "The saved copy is untouched")
	var lines := tuning.describe_differences(tuning.saved, tuning.edited)
	check(lines.has("Flight · Gravity: 75.0 m/s² → 80.0 m/s²"), "Differences read clearly")
	tuning.set_value(tuning.tunable("course/gap_height:1"), 7.5)
	check(is_equal_approx(tuning.edited.course.gap_height.sample(1.0), 7.5), "A curve end is set")
	check(is_equal_approx(tuning.edited.course.gap_height.sample(0.0), 8.4), "The other end stays")


func _check_undo(tuning: WorkshopTuning) -> void:
	var gravity := tuning.tunable("flight/gravity")
	tuning.set_value(gravity, 81.0)
	tuning.set_value(gravity, 82.0)
	check(tuning.undo_edit(), "An edit undoes")
	check(tuning.value(gravity) == 80.0, "Consecutive edits of one value undo together")
	check(tuning.redo_edit() and tuning.value(gravity) == 82.0, "And redo")
	tuning.revert()
	check(tuning.edit_count() == 0 and tuning.value(gravity) == 75.0, "Revert drops every edit")
	check(tuning.running.flight.gravity == 80.0, "The running game keeps its values")


func _check_copy_part(tuning: WorkshopTuning, preset: Resource) -> void:
	var other := WorkshopTuning.copy(preset)
	other.flight.gravity = 90.0
	other.course.perfect_run_seconds = 100.0
	tuning.copy_part(other, "flight")
	check(tuning.edited.flight.gravity == 90.0, "Copying a tab takes its values")
	check(tuning.edited.course.perfect_run_seconds == 120.0, "And no other tab's")
	check(tuning.undo_edit() and tuning.edited.flight.gravity == 75.0, "Copying a tab undoes")
