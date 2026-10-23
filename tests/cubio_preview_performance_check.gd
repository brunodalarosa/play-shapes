extends TestScript
## Desktop measurement of the complete Ready screen with ten live Cubio previews.

const SCENE: PackedScene = preload("res://scenes/pre_minigame_screen.tscn")
const OUTPUT := "res://test-results/cubio/ready-performance.json"


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1920, 1080)
	var screen := SCENE.instantiate() as PreMinigameScreen
	root.add_child(screen)
	var players: Array[Dictionary] = []
	for index: int in 10:
		players.append(
			{
				"player_id": "p%d" % index,
				"name": "Player %d" % (index + 1),
				"seat": index + 1,
				"character_color": CharacterSelection.COLORS[index].hex,
				"ready": index % 2 == 0,
			}
		)
	screen.configure(&"bubbles_3d", { "players": players })
	await create_timer(0.5).timeout
	var frames: Array[float] = []
	var calls := 0
	var last := Time.get_ticks_usec()
	var end := last + 3_000_000
	while Time.get_ticks_usec() < end:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		calls = maxi(
			calls,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		)
	frames.sort()
	var total := 0.0
	for frame: float in frames:
		total += frame
	var report := {
		"players": players.size(),
		"frames": frames.size(),
		"average_ms": total / frames.size(),
		"p95_ms": frames[floori(frames.size() * 0.95)],
		"maximum_draw_calls": calls,
		"adapter": RenderingServer.get_video_adapter_name(),
	}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("[GODOT-RUNTIME] Cubio Ready screen: %s" % JSON.stringify(report))
	check(calls > 0, "The measurement used an active renderer")
