extends TestScript
## The exported Cubio model: its clips and timing, player tint, shape face, held stances and
## blinking.

const VISUAL := preload("res://characters/cubio_3d.tscn")


func _run() -> void:
	var cubio := VISUAL.instantiate() as Cubio3D
	cubio.blink_interval = Vector2(0.05, 0.05)
	root.add_child(cubio)
	await process_frame
	var body := cubio.find_child("Body", true, false) as MeshInstance3D
	var dimensions := body.mesh.get_aabb().size
	check(
		dimensions.is_equal_approx(Vector3.ONE * 2.0),
		"Cubio's undeformed body has equal two metre sides",
	)
	check(
		CharacterSelection.validate_selection("cubio", "#E53935").accepted
		and not CharacterSelection.validate_selection("triangle", "#E53935").accepted,
		"Cubio is the only accepted body",
	)

	var player := cubio.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip: String in Cubio3D.CLIP_FRAMES:
		if not check(player.has_animation(clip), "The model carries the %s clip" % clip):
			return
		var animation := player.get_animation(clip)
		var looping := clip in Cubio3D.LOOPING_CLIPS
		check(
			animation.loop_mode == (Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE),
			"%s %s" % [clip, "loops" if looping else "holds its last frame"],
		)
	check(
		is_equal_approx(player.get_animation("idle").length, 2.0)
		and is_equal_approx(player.get_animation("look_up").length, 8.0 / 24.0),
		"Clip lengths follow the source frame counts at 24 fps",
	)
	check(player.current_animation == "idle", "A new Cubio idles")

	cubio.player_color = Color("#43A047")
	var tinted := 0
	for mesh: MeshInstance3D in cubio.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.material_override as ShaderMaterial
		if material != null and material.get_shader_parameter("player_color") == Color("#43A047"):
			tinted += 1
	check(tinted == 5, "Body, both hands and both feet take the player tint")
	_check_face(cubio)

	cubio.play("look_up")
	await _wait(0.5)
	check(cubio.action == "look_up", "Look up enters and holds")
	cubio.play("idle")
	await _wait(0.1)
	check(cubio.action == "look_up", "Leaving a stance first reverses it")
	await _wait(0.5)
	check(
		cubio.action == "idle" and player.current_animation == "idle",
		"A released stance returns to idle",
	)

	cubio.play("walk")
	cubio.set_travel(2.0)
	await _wait(0.3)
	check(cubio.facing_yaw() > 0.5, "Travelling right turns the Cubio toward +X")
	cubio.set_travel(0.0)
	cubio.play("idle")
	await _wait(0.4)
	check(absf(cubio.facing_yaw()) < 0.01, "Standing still faces the camera")

	var blinked := false
	for _frame: int in 30:
		await process_frame
		blinked = blinked or cubio.is_blinking()
	check(blinked, "The Cubio blinks on its own")
	cubio.queue_free()
	await process_frame


func _check_face(cubio: Cubio3D) -> void:
	var anchor := cubio.find_child("FaceAnchor", true, false) as Node3D
	check(
		anchor != null and cubio.face.get_parent() == anchor,
		"The shape face is drawn on the model's face anchor",
	)
	var front := cubio.find_child("Body", true, false) as Node3D
	var out := anchor.global_basis.z.normalized()
	check(
		out.is_equal_approx(front.global_basis.z.normalized())
		and anchor.global_position.z > front.global_position.z,
		"The face anchor faces out of the body's front",
	)
	var placement := Cubio3D.face_anchor()
	check(
		is_equal_approx(cubio.face.height, placement.height)
		and cubio.face.position.is_equal_approx(Vector3(placement.offset.x, placement.offset.y, 0)),
		"The face takes the placement from Cubio's anchor file",
	)
	check(
		cubio.face.face_name == Cubio3D.DEFAULT_FACE and not cubio.face.quads().is_empty(),
		"A new Cubio shows the neutral face",
	)
	for quad: MeshInstance3D in cubio.face.quads():
		var material := quad.material_override as ShaderMaterial
		check(
			material != null and float(material.get_shader_parameter("front_push")) == 2.0,
			"Face parts are pushed in front of scenery like the body",
		)
		check(
			material.get_shader_parameter("player_color") == null,
			"Face parts keep their untinted artwork",
		)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
