extends TestScript
## The exported Squircle model: its clips and timing, player tint, held stances and blinking.

const VISUAL := preload("res://characters/squircle_3d.tscn")


func _run() -> void:
	var squircle := VISUAL.instantiate() as Squircle3D
	squircle.blink_interval = Vector2(0.05, 0.05)
	root.add_child(squircle)
	await process_frame

	var player := squircle.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip: String in Squircle3D.CLIP_FRAMES:
		if not check(player.has_animation(clip), "The model carries the %s clip" % clip):
			return
		var animation := player.get_animation(clip)
		var looping := clip in Squircle3D.LOOPING_CLIPS
		check(
			animation.loop_mode == (Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE),
			"%s %s" % [clip, "loops" if looping else "holds its last frame"],
		)
	check(
		is_equal_approx(player.get_animation("idle").length, 2.0)
		and is_equal_approx(player.get_animation("look_up").length, 8.0 / 24.0),
		"Clip lengths follow the source frame counts at 24 fps",
	)
	check(player.current_animation == "idle", "A new Squircle idles")

	squircle.player_color = Color("#43A047")
	var tinted := 0
	for mesh: MeshInstance3D in squircle.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.material_override as ShaderMaterial
		if mesh.name == "Face":
			check(
				material != null and material.shader == Squircle3D.FACE_SHADER
				and material.get_shader_parameter("face") == Squircle3D.FACE_NEUTRAL,
				"The face keeps its untinted artwork",
			)
		elif material != null and material.get_shader_parameter("player_color") == Color("#43A047"):
			tinted += 1
	check(tinted == 5, "Body, both hands and both feet take the player tint")

	squircle.play("look_up")
	await _wait(0.5)
	check(squircle.action == "look_up", "Look up enters and holds")
	squircle.play("idle")
	await _wait(0.1)
	check(squircle.action == "look_up", "Leaving a stance first reverses it")
	await _wait(0.5)
	check(
		squircle.action == "idle" and player.current_animation == "idle",
		"A released stance returns to idle",
	)

	squircle.play("walk")
	squircle.set_travel(2.0)
	await _wait(0.3)
	check(squircle.facing_yaw() > 0.5, "Travelling right turns the Squircle toward +X")
	squircle.set_travel(0.0)
	squircle.play("idle")
	await _wait(0.4)
	check(absf(squircle.facing_yaw()) < 0.01, "Standing still faces the camera")

	var blinked := false
	for _frame: int in 30:
		await process_frame
		blinked = blinked or squircle.is_blinking()
	check(blinked, "The Squircle blinks on its own")
	squircle.queue_free()
	await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
