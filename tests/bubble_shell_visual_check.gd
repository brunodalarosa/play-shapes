extends TestScript
## Renders bubble shells of several sizes around tinted Cubios on an underwater blue, one
## stretched and one bursting, for visual review. Run without --headless.

const OUTPUT_DIR := "res://test-results/bubble-shell"
const CUBIO: PackedScene = preload("res://characters/cubio_3d.tscn")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("2a8fd6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cfe8ff")
	environment.ambient_light_energy = 0.6
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0.0, 0.0, 20.15)
	world.add_child(camera)
	camera.make_current()

	var bubbles: Array[BubbleShell3D] = []
	var setups := [
		[Vector2(-6.0, 1.5), 0.48, "#E53935", Vector2.ZERO],
		[Vector2(-2.0, 1.5), 0.9, "#1E88E5", Vector2.ZERO],
		[Vector2(3.5, 1.0), 1.7, "#FBC02D", Vector2.ZERO],
		[Vector2(-4.0, -2.6), 0.9, "#43A047", Vector2(0.2, 0.05)],
		[Vector2(1.0, -2.6), 0.9, "#8E24AA", Vector2.ZERO],
	]
	for setup: Array in setups:
		var at: Vector2 = setup[0]
		var radius: float = setup[1]
		var cubio := CUBIO.instantiate() as Cubio3D
		cubio.standing_height = minf(radius * 1.0, 0.95)
		cubio.position = Vector3(at.x, at.y - cubio.standing_height * 0.5, 0.0)
		world.add_child(cubio)
		cubio.nameplate.visible = false
		cubio.player_color = Color(String(setup[2]))
		var shell := BubbleShell3D.new()
		shell.radius = radius
		shell.position = Vector3(at.x, at.y, 0.0)
		world.add_child(shell)
		shell.stretch = setup[3]
		bubbles.append(shell)
	await _settle(10)
	_capture("bubbles")
	bubbles[4].pop()
	await _settle(8)
	_capture("burst")


func _settle(frames: int) -> void:
	for _frame: int in frames:
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(label: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s-%dx%d.png" % [OUTPUT_DIR, label, image.get_width(), image.get_height()]
	check(image.save_png(path) == OK, "The %s capture is saved" % label)
	print("[GODOT-RUNTIME] Bubble shell %s capture: %s" % [label, path])
