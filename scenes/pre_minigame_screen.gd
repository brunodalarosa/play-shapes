class_name PreMinigameScreen
extends Control
## One tabletop composition for every minigame content resource.

const CHARACTER: PackedScene = preload("res://characters/squircle_v1_playback.tscn")

var _content: PreMinigameContent
var _preview: TextureRect
var _title: Label
var _controls: Label
var _win: Label
var _hints: Label
var _tray: HBoxContainer
var _snapshot: Dictionary = { }


func _ready() -> void:
	_build_tabletop()
	var host := get_node_or_null("/root/SessionHost")
	if host != null and host.readiness != null:
		configure(host.readiness.minigame_id, host.readiness.snapshot_for(""))
		host.readiness_changed.connect(set_snapshot)
		host.readiness_launch_requested.connect(_on_launch_requested)
		host.readiness_canceled.connect(_on_canceled)


func _exit_tree() -> void:
	var host := get_node_or_null("/root/SessionHost")
	if host != null and host.readiness_changed.is_connected(set_snapshot):
		host.readiness_changed.disconnect(set_snapshot)
	if host != null and host.readiness_launch_requested.is_connected(_on_launch_requested):
		host.readiness_launch_requested.disconnect(_on_launch_requested)
	if host != null and host.readiness_canceled.is_connected(_on_canceled):
		host.readiness_canceled.disconnect(_on_canceled)


func _on_launch_requested(minigame_id: StringName) -> void:
	var host := get_node_or_null("/root/SessionHost")
	if host == null:
		return
	var error := get_tree().change_scene_to_file(host.minigame_scene_path(minigame_id))
	if error != OK:
		push_error("Could not open the selected minigame: %d" % error)
		host.clear_minigame_launch(minigame_id)
		_on_canceled()


func _on_canceled() -> void:
	var host := get_node_or_null("/root/SessionHost")
	if get_tree().change_scene_to_file("res://scenes/lobby.tscn") == OK and host != null:
		host.send_players_to_lobby()


func configure(minigame_id: StringName, snapshot: Dictionary) -> void:
	_content = _content_for(minigame_id)
	if _content == null:
		return
	_title.text = _content.title
	_preview.texture = _content.preview
	_controls.text = _content.controls
	_win.text = _content.win_condition
	_hints.text = _content.hints
	set_snapshot(snapshot)


func _content_for(minigame_id: StringName) -> PreMinigameContent:
	# Looked up in the tree, not by its global name: a script that preloads this scene is
	# compiled before Godot knows the autoloads by name.
	var host := get_node_or_null("/root/SessionHost")
	if host == null:
		return null

	var catalog: MinigameCatalog = host.minigame_catalog
	var minigame := catalog.find(minigame_id)

	return minigame.load_pre_minigame_content() if minigame != null else null


func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	if _tray == null:
		return
	for child: Node in _tray.get_children():
		child.queue_free()
	var players: Array = snapshot.get("players", [])
	for player: Dictionary in players:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(171, 178)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tray.add_child(slot)
		var ready := _label(
			"Ready!" if bool(player.get("ready", false)) else "",
			26,
			Color("#137541"),
		)
		ready.position = Vector2(0, 6)
		ready.size = Vector2(171, 35)
		ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(ready)
		var character := CHARACTER.instantiate() as SquircleV1Playback
		character.position = Vector2(84, 105)
		character.visual_scale = 0.38
		character.player_color = Color(String(player.get("character_color", "#598DF2")))
		character.play("idle", "front")
		slot.add_child(character)
		var name_label := _label(String(player.get("name", "")), 23, Color("#233e46"))
		name_label.position = Vector2(0, 152)
		name_label.size = Vector2(171, 30)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(name_label)


func _build_tabletop() -> void:
	var table := _panel(Rect2(0, 0, 1920, 1080), Color("#e7bf88"), Color("#ac754f"), 0)
	add_child(table)
	var tablet_shadow := _panel(Rect2(72, 102, 1160, 674), Color("#9d724c"), Color("#9d724c"), 28)
	add_child(tablet_shadow)
	var tablet := _panel(Rect2(60, 86, 1160, 674), Color("#314c60"), Color("#183041"), 28)
	add_child(tablet)
	var screen := _panel(Rect2(89, 139, 1102, 620), Color("#13516c"), Color("#d7e3d7"), 12)
	add_child(screen)
	_preview = TextureRect.new()
	_preview.position = Vector2(97, 147)
	_preview.size = Vector2(1086, 611)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)
	var title_plate := _panel(Rect2(220, 20, 840, 90), Color("#fff3cb"), Color("#b98c5b"), 20)
	add_child(title_plate)
	_title = _label("", 44, Color("#284050"))
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_plate_add(title_plate, _title)
	var booklet_shadow := _panel(Rect2(1286, 105, 580, 656), Color("#aa8059"), Color("#aa8059"), 9)
	add_child(booklet_shadow)
	var booklet := _panel(Rect2(1270, 87, 580, 656), Color("#fff8df"), Color("#c59361"), 8)
	add_child(booklet)
	var binding := _panel(Rect2(1292, 102, 24, 625), Color("#cfdbd4"), Color("#8aa99c"), 8)
	add_child(binding)
	var heading := _label("HOW TO PLAY", 36, Color("#235663"))
	_place(heading, 1340, 117, 470, 48)
	add_child(heading)
	_controls = _booklet_field("CONTROLS", 184)
	_win = _booklet_field("WIN CONDITION", 364)
	_hints = _booklet_field("HINTS", 543)
	var tray_shadow := _panel(Rect2(70, 803, 1790, 237), Color("#a47850"), Color("#a47850"), 26)
	add_child(tray_shadow)
	var tray_panel := _panel(Rect2(55, 788, 1790, 237), Color("#f6dfb0"), Color("#b98557"), 26)
	add_child(tray_panel)
	_tray = HBoxContainer.new()
	_tray.position = Vector2(79, 821)
	_tray.size = Vector2(1740, 182)
	_tray.add_theme_constant_override("separation", 2)
	add_child(_tray)
	var cancel := Button.new()
	cancel.text = "Back to lobby"
	cancel.tooltip_text = "Host only: cancel ready-up"
	cancel.position = Vector2(1605, 23)
	cancel.size = Vector2(244, 52)
	cancel.add_theme_font_size_override("font_size", 22)
	cancel.pressed.connect(
		func() -> void:
			var host := get_node_or_null("/root/SessionHost")
			if host != null:
				host.cancel_pre_minigame(),
	)
	add_child(cancel)


func _title_plate_add(plate: Panel, label: Label) -> void:
	plate.add_child(label)


func _booklet_field(heading: String, y: float) -> Label:
	var heading_label := _label(heading, 27, Color("#b35b46"))
	_place(heading_label, 1343, y, 465, 38)
	add_child(heading_label)
	var body := _label("", 28, Color("#31474e"))
	_place(body, 1343, y + 39, 455, 133)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(body)
	return body


func _panel(rect: Rect2, fill: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(4)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(width, height)
