extends TestScript
## Renders the underwater environment behind a few bubble shells through a narrow, near-frontal
## camera, for visual review. Run without --headless.

const OUTPUT_DIR := "res://test-results/underwater-environment"
const SCENE: PackedScene = preload(
	"res://components/underwater_environment/underwater_environment.tscn"
)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(SCENE.instantiate())
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0.0, 0.0, 20.15)
	world.add_child(camera)
	camera.make_current()
	for index: int in 5:
		var shell := BubbleShell3D.new()
		shell.radius = 0.5 + index * 0.25
		shell.position = Vector3(-7.0 + index * 3.5, sin(index * 1.7) * 2.5, 0.0)
		world.add_child(shell)
	await _settle(180)
	var image := root.get_texture().get_image()
	var path := "%s/environment-%dx%d.png" % [OUTPUT_DIR, image.get_width(), image.get_height()]
	check(image.save_png(path) == OK, "The capture is saved")
	print("[GODOT-RUNTIME] Underwater environment capture: %s" % path)


func _settle(frames: int) -> void:
	for _frame: int in frames:
		await process_frame
	await RenderingServer.frame_post_draw
