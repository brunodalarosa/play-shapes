extends TestScript
## The composed face: the manifest's presets become placed parts, a blink closes only open
## eyes, expressions follow their priorities and durations, natural blinks keep their timing,
## and the 3D and 2D faces draw the preset they are given without any physics.


func _run() -> void:
	var manifest := ShapeFaceManifest.load_default()
	check(manifest.faces.size() >= 12, "The manifest keeps the twelve original presets")
	var face_a := manifest.face("face_a")
	check(face_a.layers.size() == 3, "face_a has two eyes and a mouth")
	check(is_equal_approx(face_a.box_aspect, 1.72414), "face_a keeps its box aspect")
	check(face_a.layers[0].center.is_equal_approx(Vector2(-0.51724, -0.15517)), "Eyes keep place")
	check(face_a.can_blink(), "Open eyes can blink")
	check(not manifest.face("face_j").can_blink(), "Crossed-out eyes do not blink")
	check(not manifest.face("face_k").can_blink(), "Shut eyes do not blink")
	for part: String in manifest.part_sizes:
		check(manifest.texture(part) != null, "%s has a texture" % part)

	var blink := manifest.blinked("face_a")
	check(blink.layers[0].part == ShapeFaceManifest.BLINK_EYE, "A blink closes the left eye")
	check(blink.layers[1].part == ShapeFaceManifest.BLINK_EYE, "A blink closes the right eye")
	check(blink.layers[0].center == face_a.layers[0].center, "A closed eye sits where it was")
	check(
		blink.layers[0].size.is_equal_approx(Vector2(48.0, 24.0) / 58.0),
		"A closed eye keeps its own source size",
	)
	check(blink.layers[2].part == face_a.layers[2].part, "A blink leaves the mouth")
	check(face_a.layers[0].part == "facial_part_eye_open", "A blink leaves the preset unchanged")
	check(manifest.blinked("face_j").layers[0].part == "facial_part_eye_x", "X eyes stay X")

	_check_expressions()
	_check_blinks()
	await _check_nodes()


func _check_expressions() -> void:
	var stack := ShapeFaceExpressions.new(1)
	check(stack.face_at(0.0) == "face_a", "With nothing active the base face shows")
	stack.show("face_i", 0.35, 1, 0.0)
	check(stack.face_at(0.2) == "face_i", "A timed expression shows")
	stack.show("face_j", 0.8, 2, 0.1)
	check(stack.face_at(0.2) == "face_j", "A higher priority covers a lower one")
	check(stack.active_priority(0.2) == 2, "The active priority is the highest")
	stack.show("face_i", 0.6, 1, 0.5)
	check(stack.face_at(0.95) == "face_i", "A covered expression shows once the cover ends")
	check(stack.face_at(1.11) == "face_a", "Every expression ends after its duration")
	stack.show("face_j", 0.8, 2, 1.0)
	stack.show("face_j", 0.8, 2, 1.5)
	check(stack.face_at(2.2) == "face_j", "Showing again extends an expression")
	stack.base_face = "face_e"
	stack.clear_all()
	check(stack.face_at(2.2) == "face_e", "The base face can change")


func _check_blinks() -> void:
	var stack := ShapeFaceExpressions.new(7)
	var closed_runs: Array[float] = []
	var open_runs: Array[float] = []
	var was_closed := false
	var started := 0.0
	var step := 0.005
	for index: int in 24000:
		var now := index * step
		var closed := stack.blinking_at(now)
		if closed != was_closed:
			(closed_runs if was_closed else open_runs).append(now - started)
			started = now
			was_closed = closed
	check(closed_runs.size() > 15, "Blinks recur over two minutes")
	for run: float in closed_runs:
		check(absf(run - 0.12) <= step + 0.0001, "A blink lasts 0.12 s")
	open_runs.remove_at(0)
	for run: float in open_runs:
		check(run >= 2.4 - 0.12 - step and run <= 5.6 + step, "Blinks are 2.4 to 5.6 s apart")


func _check_nodes() -> void:
	var face := ShapeFace3D.new()
	face.height = 0.5
	root.add_child(face)
	check(face.quads().size() == 3, "The 3D face draws one quad per layer")
	var mouth := face.quads()[2]
	check(
		mouth.position.is_equal_approx(Vector3(0.0, -0.37776 * 0.5, mouth.position.z)),
		"Parts sit at their centre, Y up, scaled by the face height",
	)
	check(mouth.position.z > face.quads()[0].position.z, "Later layers sit in front")
	face.face_name = "face_j"
	check(face.quads().size() == 5, "Changing the face redraws it")
	face.face_name = "face_a"
	face.blinking = true
	var eye := face.quads()[0].material_override as StandardMaterial3D
	check(
		eye.albedo_texture
		== ShapeFaceManifest.load_default().texture("facial_part_eye_closed_down"),
		"Blinking closes the drawn eyes",
	)

	var time := [0.0]
	face.blinking = false
	face.expressions = ShapeFaceExpressions.new(3)
	face.clock = func() -> float:
		return time[0]
	face.expressions.show("face_i", 0.35, 1, 0.0)
	await process_frame
	await process_frame
	check(face.face_name == "face_i", "A face driven by an expression stack follows it")
	time[0] = 1.0
	await process_frame
	await process_frame
	check(face.face_name == "face_a", "It returns to the base face")
	check(face.find_children("*", "CollisionObject3D").is_empty(), "A face has no physics")

	var chip := ShapeFace2D.new()
	chip.size = Vector2(100.0, 40.0)
	root.add_child(chip)
	var box := chip.face_rect()
	check(is_equal_approx(box.size.y, 40.0), "A 2D face fits the Control's height")
	check(is_equal_approx(box.size.x, 40.0 * 1.72414), "It keeps the preset's aspect")
	check(box.get_center().is_equal_approx(Vector2(50.0, 20.0)), "It is centred")
