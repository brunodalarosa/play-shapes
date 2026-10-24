extends TestScript
## Captures the emoji presets only in Godot 3D: front, three-quarter and blinking, with
## enlarged examples and paddles at the default 1:5 proportions. Run without --headless.

const OUTPUT := "res://test-results/shape-face-emoji/"
const EMOJIS := preload("res://tests/shape_face_emoji_test.gd").EMOJIS
const COLORS := ["ffd166", "ee927a", "85bdb5", "aab8e8"]

var _examples: Array[Node3D] = []
var _faces: Array[ShapeFace3D] = []


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var names: Array[String] = []
	names.assign(EMOJIS.keys())
	var first := 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--start="):
			first = maxi(argument.trim_prefix("--start=").to_int(), 0)
	for page_start: int in range(first, names.size(), 16):
		await _page(names.slice(page_start, mini(page_start + 16, names.size())), page_start + 1)


func _page(names: Array[String], first: int) -> void:
	var rows := maxi(ceili(names.size() / 4.0), 1)
	var page_height := 18.0 - (4 - rows) * 4.1
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2400, roundi(1980 * page_height / 18.0))
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("f3ead6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.7
	var setting := WorldEnvironment.new()
	setting.environment = environment
	world.add_child(setting)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = page_height
	camera.position.y = (4 - rows) * 2.05
	camera.position.z = 24.0
	camera.current = true
	world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, -25.0, 0.0)
	light.light_energy = 0.8
	world.add_child(light)
	_label(world, "EMOJI EXPRESSIONS", Vector3(0.0, 8.25, 0.5), 54)
	var range_label := "%d–%d · Large study + default paddle proportions" % [
		first,
		first + names.size() - 1,
	]
	_label(world, range_label, Vector3(0.0, 7.7, 0.5), 30)
	var emoji_font := SystemFont.new()
	emoji_font.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji"])
	var index := 0
	for name: String in names:
		var x := (index % 4 - 1.5) * 5.2
		var y := 5.65 - floorf(index / 4.0) * 4.1
		var origin := Node3D.new()
		origin.position = Vector3(x, y, 0.0)
		world.add_child(origin)
		var reference := _label(origin, EMOJIS[name], Vector3(-1.65, 1.45, 0.5), 76)
		reference.font = emoji_font
		reference.modulate = Color.WHITE
		var title := name.trim_prefix("face_").replace("_", " ").capitalize()
		var caption := _label(origin, title, Vector3(0.45, 1.45, 0.5), 29)
		caption.width = 330.0
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_paddle(origin, name, 1.65, 0.05, Color(COLORS[index % COLORS.size()]))
		_paddle(origin, name, 0.76, -1.43, Color(COLORS[index % COLORS.size()]))
		index += 1
	await _capture(viewport, "front", first, first + names.size() - 1)
	for example: Node3D in _examples:
		example.rotation_degrees.y = 24.0
	await _capture(viewport, "three-quarter", first, first + names.size() - 1)
	for example: Node3D in _examples:
		example.rotation_degrees.y = 0.0
	for face: ShapeFace3D in _faces:
		face.blinking = true
	await _capture(viewport, "blink", first, first + names.size() - 1)
	_faces.clear()
	_examples.clear()
	viewport.queue_free()
	await process_frame


func _paddle(parent: Node3D, name: String, thickness: float, y: float, color: Color) -> void:
	var example := Node3D.new()
	example.position.y = y
	parent.add_child(example)
	_examples.append(example)
	var body := MeshInstance3D.new()
	body.mesh = RoundedBar.mesh(3.8, thickness, 0.45, thickness * 0.35)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	body.material_override = material
	example.add_child(body)
	var face := ShapeFace3D.new()
	face.face_name = name
	face.height = thickness * 0.72
	face.position.z = 0.23
	example.add_child(face)
	_faces.append(face)


func _label(parent: Node3D, text: String, position: Vector3, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.008
	label.outline_size = 0
	label.modulate = Color("3d465d")
	label.position = position
	parent.add_child(label)
	return label


func _capture(viewport: SubViewport, view: String, first: int, last: int) -> void:
	for frame: int in 5:
		await RenderingServer.frame_post_draw
	var path := OUTPUT + "emoji-faces-%s-%02d-%02d.png" % [view, first, last]
	check(viewport.get_texture().get_image().save_png(path) == OK, "Saved %s" % view)
	print("[GODOT-RUNTIME] %s" % path)
