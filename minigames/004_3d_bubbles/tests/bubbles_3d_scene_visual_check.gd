extends TestScript
## Renders the shared screen of Bubbles and jellyfishes 3D mid-round with five and with ten
## players, catches of several sizes, free jellyfishes and pufferfishes, for comparison with the
## approved mockups. Run without --headless.

const OUTPUT_DIR := "res://test-results/bubbles-3d"
const SCENE: PackedScene = preload("res://minigames/004_3d_bubbles/3d_bubbles.tscn")
const COLORS: Array[String] = [
	"#E53935",
	"#1E88E5",
	"#43A047",
	"#FBC02D",
	"#8E24AA",
	"#F57C00",
	"#00ACC1",
	"#EC407A",
	"#3949AB",
	"#8D6E63",
]
const CATCHES: Array[int] = [4, 40, 0, 9, 2, 16, 1, 25, 6, 3]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for count: int in [5, 10]:
		await _render(count)


func _render(count: int) -> void:
	var scene := SCENE.instantiate() as Bubbles3DPresentation
	root.add_child(scene)
	await process_frame
	scene.controller.tuning.instructions_seconds = 0.0
	scene.controller.tuning.countdown_seconds = 0.0
	scene.controller.tuning.pufferfish_start_spawn_rate = 0.0
	scene.controller.tuning.pufferfish_max_spawn_rate = 0.0
	var players: Array = []
	for index: int in count:
		players.append(
			{
				"player_id": "p%d" % index,
				"name": "Player %d" % (index + 1),
				"seat": index + 1,
				"state": "connected",
				"character_color": COLORS[index],
			}
		)
	scene.start_round(players, Time.get_ticks_msec())
	for _frame: int in 90:
		await process_frame
	for index: int in count:
		for _catch: int in CATCHES[index]:
			scene.controller.record_jellyfish_capture("p%d" % index, Time.get_ticks_msec())
	var now := Time.get_ticks_msec()
	scene.creature_arena.schedule_puffer_path(Vector2(-10.6, -1.5), Vector2(10.6, 2.0), now)
	scene.creature_arena.schedule_puffer_path(Vector2(10.6, 3.0), Vector2(-10.6, -3.5), now)
	# After their warning, the pufferfishes swim about a third of the way in.
	await create_timer(5.5).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/players-%d-%dx%d.png" % [
		OUTPUT_DIR,
		count,
		image.get_width(),
		image.get_height(),
	]
	check(image.save_png(path) == OK, "The capture is saved")
	print("[GODOT-RUNTIME] Bubbles 3D %d-player capture: %s" % [count, path])
	scene.queue_free()
	await process_frame
