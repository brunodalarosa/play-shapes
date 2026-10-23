extends TestScript
## The exported Cubio model: its clips and timing, player tint, held stances and blinking.

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
		CharacterSelection.validate_selection("squircle", "#E53935").character_shape == "cubio",
		"Legacy Squircle selection resolves to Cubio",
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
		if mesh.name == "Face":
			check(
				material != null and material.shader == Cubio3D.FACE_SHADER
				and material.get_shader_parameter("face") == Cubio3D.FACE_NEUTRAL,
				"The face keeps its untinted artwork",
			)
		elif material != null and material.get_shader_parameter("player_color") == Color("#43A047"):
			tinted += 1
	check(tinted == 5, "Body, both hands and both feet take the player tint")

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


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
