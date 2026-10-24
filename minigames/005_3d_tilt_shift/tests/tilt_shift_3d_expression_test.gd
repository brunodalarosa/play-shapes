extends TestScript
## The paddle expressions: dizzy after a sustained fast turn and for its hold afterwards, startled
## on a hard enough hit with a squash that springs back, dizzy above startled above the play face,
## the countdown, round-end and result faces by team, and the player's strongest face across
## their paddles. Every threshold comes from the tuning.

const FAST := deg_to_rad(170.0)
const SLOW := deg_to_rad(100.0)


func _run() -> void:
	var tuning := TiltShift3DExpressionTuning.new()
	check(tuning.validation_errors().is_empty(), "The default expressions are valid")
	var driver := TiltShift3DExpressionDriver.new(tuning)
	var owners: Dictionary[String, String] = { "a_0": "p1", "a_1": "p1", "a_3": "p2" }
	var teams: Dictionary[String, int] = { "a_0": 0, "a_1": 0, "a_3": 1 }
	driver.set_paddles(owners)
	check(not driver.stacks.has("a_2"), "The automatic paddle has no face")

	var state := TiltShift3DState.Snapshot.new()
	state.phase = &"countdown"
	driver.set_moment(state, teams)
	check(driver.face_for("a_0", 0.0) == "face_scheming", "The countdown shows the determined face")
	driver.hit("a_0", 1.0, 0.0)
	check(driver.face_for("a_0", 0.1) == "face_scheming", "Hits outside play change nothing")

	state.phase = &"active"
	driver.set_moment(state, teams)
	check(driver.face_for("a_0", 0.0) == "face_slightly_smiling", "Play shows the default face")
	_check_dizzy(driver)
	_check_startled(driver)

	driver.update({ "a_0": FAST, "a_1": FAST }, 20.0)
	driver.update({ "a_0": FAST, "a_1": FAST }, 20.2)
	driver.hit("a_0", 0.2, 20.25)
	check(driver.face_for("a_0", 20.3) == "face_dizzy", "Dizzy wins over startled")
	driver.hit("a_3", 0.2, 20.25)
	check(driver.face_for_player("p1", 20.3) == "face_dizzy", "A player shows their strongest face")
	check(driver.face_for_player("p2", 20.3) == "face_worried", "Another player keeps their own")

	state.phase = &"between_rounds"
	state.scores = [3, 1]
	driver.set_moment(state, teams)
	check(driver.face_for("a_0", 20.3) == "face_mischievous", "The leading team looks confident")
	check(driver.face_for("a_3", 20.3) == "face_disappointed", "The trailing team looks sad")
	check(driver.squash("a_3", 20.3) == 1.0, "Round end settles any squash")
	state.scores = [2, 2]
	driver.set_moment(state, teams)
	check(
		driver.face_for("a_3", 20.3) == "face_slightly_smiling",
		"A tie shows the default face for both",
	)
	state.phase = &"finished"
	state.scores = [1, 4]
	driver.set_moment(state, teams)
	check(
		driver.face_for("a_0", 30.0) == "face_disappointed",
		"The losing team looks sad at the results",
	)
	check(driver.face_for_player("p2", 30.0) == "face_mischievous", "The winners look confident")
	state.scores = [4, 4]
	driver.set_moment(state, teams)
	check(driver.face_for("a_0", 30.0) == "face_slightly_smiling", "A draw shows the default face")

	tuning.dizzy_face = "face_smiling_eyes"
	tuning.dizzy_degrees_per_second = 300.0
	state.phase = &"active"
	driver.set_moment(state, teams)
	driver.update({ "a_0": FAST }, 40.0)
	driver.update({ "a_0": FAST }, 41.0)
	check(driver.face_for("a_0", 41.0) == "face_slightly_smiling", "The dizzy threshold is tunable")
	driver.update({ "a_0": deg_to_rad(320.0) }, 42.0)
	driver.update({ "a_0": deg_to_rad(320.0) }, 42.2)
	check(driver.face_for("a_0", 42.2) == "face_smiling_eyes", "The dizzy face is tunable")
	tuning.dizzy_face = "face_x"
	check(not tuning.validation_errors().is_empty(), "An unknown face is refused")


func _check_dizzy(driver: TiltShift3DExpressionDriver) -> void:
	driver.update({ "a_0": FAST, "a_1": SLOW }, 1.0)
	driver.update({ "a_0": FAST, "a_1": SLOW }, 1.1)
	check(
		driver.face_for("a_0", 1.1) == "face_slightly_smiling",
		"A turn shorter than the onset is not dizzy",
	)
	driver.update({ "a_0": FAST, "a_1": SLOW }, 1.16)
	check(
		driver.face_for("a_0", 1.16) == "face_dizzy",
		"A sustained fast turn makes a paddle dizzy",
	)
	check(driver.face_for("a_1", 1.16) == "face_slightly_smiling", "A slow paddle stays calm")
	driver.update({ "a_0": SLOW }, 1.5)
	check(driver.face_for("a_0", 1.9) == "face_dizzy", "Dizziness holds after the turn slows")
	check(
		driver.face_for("a_0", 2.0) == "face_slightly_smiling",
		"It ends 0.8 s after the last fast turn",
	)
	driver.update({ "a_0": FAST }, 3.0)
	driver.update({ "a_0": SLOW }, 3.1)
	driver.update({ "a_0": FAST }, 3.2)
	driver.update({ "a_0": FAST }, 3.3)
	check(
		driver.face_for("a_0", 3.3) == "face_slightly_smiling",
		"The onset restarts when the speed drops",
	)


func _check_startled(driver: TiltShift3DExpressionDriver) -> void:
	driver.hit("a_1", 0.04, 10.0)
	check(
		driver.face_for("a_1", 10.1) == "face_slightly_smiling",
		"A soft contact does not startle",
	)
	check(driver.squash("a_1", 10.0) == 1.0, "A soft contact does not squash")
	driver.hit("a_1", 0.06, 10.0)
	check(driver.face_for("a_1", 10.1) == "face_worried", "A hit startles the paddle that was hit")
	check(driver.face_for("a_0", 10.1) == "face_slightly_smiling", "Only the hit paddle reacts")
	check(driver.face_for("a_1", 10.36) == "face_slightly_smiling", "Startled lasts 0.35 s")
	check(is_equal_approx(driver.squash("a_1", 10.0), 0.88), "A hit squashes the paddle 12%")
	var early := driver.squash("a_1", 10.05)
	check(early > 0.88 and early < 1.0, "The squash springs back")
	check(absf(driver.squash("a_1", 10.125) - 1.0) < 0.03, "It overshoots only slightly")
	check(driver.squash("a_1", 10.25) == 1.0, "It recovers within 0.25 s")
