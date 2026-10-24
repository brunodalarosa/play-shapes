class_name CubioPreview
extends SubViewportContainer
## One isolated 3D world for a row of live character previews, with no gameplay state.

const CHARACTER: PackedScene = preload("res://characters/cubio_3d.tscn")
const CAMERA_HEIGHT := 1.38

var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _characters: Dictionary[String, Cubio3D] = { }
var _order: Array[String] = []


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_HEIGHT
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.position = Vector3(0, 1.15, 6)
	_world.add_child(_camera)
	_camera.look_at(Vector3(0, 0.5, 0))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	_world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 0.9
	_world.add_child(light)
	resized.connect(_layout_characters)
	_layout_characters()


func set_players(players: Array) -> void:
	_order.clear()
	for player: Dictionary in players:
		var id := String(player.player_id)
		_order.append(id)
		if not _characters.has(id):
			var character := CHARACTER.instantiate() as Cubio3D
			character.rotation.y = -0.22
			_world.add_child(character)
			_characters[id] = character
		_characters[id].player_color = Color(String(player.get("character_color", "#598DF2")))
	for id: String in _characters.keys():
		if not _order.has(id):
			_characters[id].queue_free()
			_characters.erase(id)
	_layout_characters()


func _layout_characters() -> void:
	if _camera == null or _order.is_empty():
		return
	var width := CAMERA_HEIGHT * size.x / maxf(size.y, 1.0)
	var slot_width := width / _order.size()
	for index: int in _order.size():
		_characters[_order[index]].position.x = -width / 2.0 + slot_width * (index + 0.5)
