extends SceneTree
## Run with the Compatibility renderer (not --headless) for real shader checks.

const CHARACTER: PackedScene = preload("res://characters/shape_character.tscn")
const SHOWCASE: PackedScene = preload("res://characters/asset_showcase.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void: quit(1))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 180)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var first := CHARACTER.instantiate() as ShapeCharacter
	var second := CHARACTER.instantiate() as ShapeCharacter
	first.position = Vector2(80, 70)
	second.position = Vector2(240, 70)
	viewport.add_child(first)
	viewport.add_child(second)
	assert(first.get_child_count() == 6)
	for part: Node in first.get_children():
		assert(part is Sprite2D)
	assert(first.get_node("Body").material != second.get_node("Body").material)
	assert(first.get_node("Body").material == first.get_node("LeftFoot").material)
	assert(first.get_node("Face").material == null)
	assert(first.get_node("LeftFoot").flip_h and not first.get_node("RightFoot").flip_h)
	var face_transform: Transform2D = first.get_node("Face").transform
	first.get_node("LeftHand").rotation = 0.4
	assert(first.get_node("RightHand").rotation == 0.0)
	assert(first.get_node("Face").transform == face_transform)
	await process_frame
	await RenderingServer.frame_post_draw
	var before := viewport.get_texture().get_image()
	first.player_color = Color("00ffaa")
	await process_frame
	await RenderingServer.frame_post_draw
	var after := viewport.get_texture().get_image()
	assert(before.get_pixel(80, 45) != after.get_pixel(80, 45), "Tint must change rendered body pixels")
	assert(before.get_pixel(240, 45) == after.get_pixel(240, 45), "Other instance must keep its color")
	var face := first.get_node("Face") as Sprite2D
	var mask := face.texture.get_image()
	mask.convert(Image.FORMAT_RGBA8)
	var checked := 0
	# Only compare fully opaque interiors: transparent face areas reveal tinted body.
	for y: int in mask.get_height() / 2:
		for x: int in mask.get_width() / 2:
			var opaque := true
			for dy: int in range(-5, 6):
				for dx: int in range(-5, 6):
					var sx: int = clampi(x * 2 + dx, 0, mask.get_width() - 1)
					var sy: int = clampi(y * 2 + dy, 0, mask.get_height() - 1)
					opaque = opaque and mask.get_pixel(sx, sy).a == 1.0
			if opaque:
				var px: int = 80 - mask.get_width() / 4 + x
				var py: int = 70 - mask.get_height() / 4 + y
				assert(before.get_pixel(px, py).is_equal_approx(after.get_pixel(px, py)), "Tint leaked into face at %d,%d" % [px, py])
				checked += 1
	assert(checked > 50)
	viewport.queue_free()
	var showcase := SHOWCASE.instantiate()
	root.add_child(showcase)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://art/character-feet/runtime-showcase.png")
	assert(capture.save_png(path) == OK)
	print("PASS: six independent parts, per-instance materials, mirrored feet, rendered tint changes, unchanged second player and %d opaque face pixels." % checked)
	showcase.queue_free()
	await process_frame
	quit(0)
