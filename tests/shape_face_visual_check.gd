extends TestScript
## Draws each of the twelve presets with [ShapeFace2D] at the reference faces' own size and
## compares it with the reference image: every pixel that is at least half navy, or half white,
## in one image must have a pixel at least a quarter of that colour within one pixel in the
## other. Also writes a review sheet of the references, the 2D faces at 1x and 4x and the 3D
## faces on a paddle. Run without --headless.

const OUTPUT_DIR := "res://test-results/shape-face"
const REFERENCES := "res://art/shape_characters_face_system_assets/"
const NAVY := Color("3d465d")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var manifest := ShapeFaceManifest.load_default()
	var names: Array = manifest.faces.keys()
	# Only the original faces have supplied reference pixels to compare against.
	names = names.filter(
		func(name: String) -> bool:
			return FileAccess.file_exists(REFERENCES + name + ".png"),
	)
	names.sort()
	for name: String in names:
		var reference := Image.load_from_file(
			ProjectSettings.globalize_path(REFERENCES + name + ".png")
		)
		var drawn := await _draw_2d(name, reference.get_size())
		var mismatch := _mismatch(reference, drawn) + _mismatch(drawn, reference)
		check(
			mismatch == 0,
			"%s drawn in 2D matches its reference within a pixel (%d)" % [name, mismatch],
		)

	var sheet := await _sheet(names)
	var path := OUTPUT_DIR + "/faces.png"
	check(sheet.save_png(path) == OK, "The review sheet is saved")
	print("[GODOT-RUNTIME] Shape face review sheet: %s" % path)


func _draw_2d(name: String, size: Vector2i) -> Image:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var face := ShapeFace2D.new()
	face.face_name = name
	face.size = Vector2(size)
	viewport.add_child(face)
	root.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image


## Pixels of [param from] that are at least half navy or half white with no pixel at least a
## quarter of that colour within one pixel in [param to].
func _mismatch(from: Image, to: Image) -> int:
	var count := 0
	for y: int in from.get_height():
		for x: int in from.get_width():
			for colour: int in 2:
				if _share(from.get_pixel(x, y), colour) < 0.5:
					continue
				var found := false
				var inside := Rect2i(Vector2i.ZERO, to.get_size())
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						var at := Vector2i(x + dx, y + dy)
						if not inside.has_point(at):
							continue
						if _share(to.get_pixelv(at), colour) >= 0.25:
							found = true
				if not found:
					count += 1
	return count


## How much of a pixel is navy (0) or white (1): its cover times how close it is to that colour.
func _share(pixel: Color, colour: int) -> float:
	var lightness := clampf(
		(pixel.get_luminance() - NAVY.get_luminance()) / (1.0 - NAVY.get_luminance()),
		0.0,
		1.0,
	)
	return pixel.a * (lightness if colour == 1 else 1.0 - lightness)


func _sheet(names: Array) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1800, 1300)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.own_world_3d = true
	var world := Node3D.new()
	viewport.add_child(world)
	# The 3D scene draws first, so its background is the sheet's background.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("f3ead6")
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0.0, 0.0, 26.0)
	camera.current = true
	world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 20.0, 0.0)
	world.add_child(light)

	for index: int in names.size():
		var name: String = names[index]
		var column := index % 4
		var row := index / 4
		var origin := Vector2(30 + column * 440, 30 + row * 420)
		var reference := TextureRect.new()
		reference.texture = ImageTexture.create_from_image(
			Image.load_from_file(ProjectSettings.globalize_path(REFERENCES + name + ".png"))
		)
		reference.position = origin
		viewport.add_child(reference)
		var small := ShapeFace2D.new()
		small.face_name = name
		small.position = origin + Vector2(130, 0)
		small.size = Vector2(130, 90)
		viewport.add_child(small)
		var large := ShapeFace2D.new()
		large.face_name = name
		large.position = origin + Vector2(0, 100)
		large.size = Vector2(400, 150)
		viewport.add_child(large)

		var paddle := MeshInstance3D.new()
		paddle.mesh = RoundedBar.mesh(3.6, 0.9, 0.9, 0.315)
		var body := StandardMaterial3D.new()
		body.albedo_color = Color("ffd166")
		paddle.material_override = body
		var screen := origin + Vector2(200, 330)
		paddle.position = _world_at(camera, viewport.size, screen)
		world.add_child(paddle)
		var face := ShapeFace3D.new()
		face.face_name = name
		face.height = 0.9 * 0.72
		face.position = Vector3(0.0, 0.0, 0.452)
		paddle.add_child(face)

	for _frame: int in 4:
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image


func _world_at(camera: Camera3D, size: Vector2i, screen: Vector2) -> Vector3:
	var half_height := tan(deg_to_rad(camera.fov * 0.5)) * camera.position.z
	var scale := half_height * 2.0 / float(size.y)
	var offset := screen - Vector2(size) * 0.5
	return Vector3(offset.x * scale, -offset.y * scale, 0.0)
