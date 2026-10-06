extends TestScript
## Captures and measures the real workshop preview with synthetic ten-player input.

const Preview := preload("res://addons/tilt_shift_workshop/workshop_preview.gd")
const Controls := preload("res://minigames/003_tilt_shift/tests/tilt_shift_physics_cost_check.gd")


func _run() -> void:
	root.size = Vector2i(1100, 760)
	root.content_scale_size = Vector2i(1100, 760)
	var profile := TiltShiftFixtures.tuning(1)
	profile.round_duration_seconds = 45
	profile.physics.ball_count = 300
	profile.physics.use_position_seed = true
	profile.physics.position_seed = 749
	var preview := Preview.new()
	preview.profile = profile
	root.add_child(preview)
	await process_frame
	await process_frame
	var input := Controls.Controls.new()
	input.arena = preview.arena
	var state := preview.arena.controller.snapshot()
	input.players = state.players
	input.token = state.round_token
	input.started = state.started_at_msec
	root.add_child(input)
	var output := "res://test-results/tilt-shift/workshop/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await create_timer(6).timeout
	RenderingServer.force_draw()
	check(
		root.get_texture().get_image().save_png(output.path_join("physics-preview.png")) == OK,
		"Actual gameplay workshop preview capture saves",
	)
	await create_timer(39.1).timeout
	var timings := preview.timing_p95()
	var peak := preview.arena.peak_live_balls
	var report := "Ten synthetic players / 300 balls / 45 seconds\n"
	report += "Preview arena script p95: %d microseconds\nPeak live balls: %d\n" % [timings, peak]
	report += "Native physics, rendering and editor guide work excluded from script timing.\n"
	var file := FileAccess.open(output.path_join("preview-cost.txt"), FileAccess.WRITE)
	file.store_string(report)
	file.close()
	print(report)
	check(
		preview.arena.spawned_count == 300,
		"Measured preview delivers the entire selected budget",
	)
	preview.stop()
	check(preview.arena.live_balls().is_empty(), "Measured preview stop clears temporary bodies")
	input.queue_free()
	preview.queue_free()
	await process_frame
