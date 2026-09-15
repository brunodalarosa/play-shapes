extends SceneTree
## CPU-side sample on the current development machine; not a broader hardware claim.

const SAMPLE_FRAMES := 600

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://debug/character_animation_system.tscn")
	await scene_changed
	await process_frame
	var animators: Array[HybridCharacterAnimator] = current_scene.animators
	var worst_usec := 0
	var total_usec := 0
	for frame: int in SAMPLE_FRAMES:
		var started := Time.get_ticks_usec()
		for animator: HybridCharacterAnimator in animators:
			animator._process(1.0 / 60.0)
		var elapsed := Time.get_ticks_usec() - started
		total_usec += elapsed
		worst_usec = maxi(worst_usec, elapsed)
	var average_usec := float(total_usec) / SAMPLE_FRAMES
	if average_usec >= 16667.0:
		push_error("Eleven-character animation CPU sample exceeded a 60 FPS frame budget")
		quit(1)
		return
	print("11-character CPU sample: %.2f us average, %d us worst across %d synthetic frames" % [average_usec, worst_usec, SAMPLE_FRAMES])
	quit(0)
