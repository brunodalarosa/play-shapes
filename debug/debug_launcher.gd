extends CanvasLayer
## Persistent host-only launcher. This autoload never owns or restarts LAN services.

const LOBBY_PATH := "res://scenes/lobby.tscn"

var active_scenario: DebugScenario
var _features: Dictionary = { }
var _panel: PanelContainer
var _scenario_list: VBoxContainer
var _marker: Label
var _restart_button: Button
var _scenarios: Array[DebugScenario] = []


func _ready() -> void:
	layer = 100
	_scenarios = DebugScenarioCatalog.scenarios()
	_build_ui()
	_refresh_actions()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh_actions()


func launch(scenario_id: StringName) -> bool:
	var scenario := scenario_for_id(scenario_id)
	if scenario == null or not bool(scenario.availability(_features).available):
		return false
	if not _prepare_scenario_launch(scenario):
		return false
	active_scenario = scenario
	_panel.hide()
	_update_marker()
	get_tree().change_scene_to_file(scenario.scene_path)
	return true


func restart_scenario() -> bool:
	if active_scenario == null:
		return false
	if not _prepare_scenario_launch(active_scenario):
		return false
	_panel.hide()
	get_tree().change_scene_to_file(active_scenario.scene_path)
	return true


func return_to_lobby(notify_players := true) -> void:
	if notify_players:
		SessionHost.send_players_to_lobby()
	SessionHost.clear_minigame_launch()
	active_scenario = null
	_panel.hide()
	_update_marker()
	get_tree().change_scene_to_file(LOBBY_PATH)


func scenario_for_id(scenario_id: StringName) -> DebugScenario:
	for scenario: DebugScenario in _scenarios:
		if scenario.id == scenario_id:
			return scenario
	return null


func register_scenario(scenario: DebugScenario) -> void:
	var existing := scenario_for_id(scenario.id)
	if existing != null:
		_scenarios[_scenarios.find(existing)] = scenario
	else:
		_scenarios.append(scenario)
	_refresh_actions()


func is_open() -> bool:
	return _panel.visible


func marker_text() -> String:
	return _marker.text


func set_feature_available(feature: StringName, available: bool) -> void:
	_features[feature] = available
	_refresh_actions()


func _build_ui() -> void:
	_marker = Label.new()
	_marker.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_marker.offset_left = 16.0
	_marker.offset_top = 12.0
	_marker.offset_right = -16.0
	_marker.add_theme_color_override("font_color", Color("ffd166"))
	_marker.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_marker.add_theme_constant_override("shadow_offset_x", 2)
	_marker.add_theme_constant_override("shadow_offset_y", 2)
	_marker.add_theme_font_size_override("font_size", 20)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-270, -265)
	_panel.custom_minimum_size = Vector2(540, 530)
	_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("fff8e8")
	panel_style.border_color = Color("c48b50")
	panel_style.set_border_width_all(5)
	panel_style.set_corner_radius_all(24)
	panel_style.shadow_color = Color(0.08, 0.12, 0.2, 0.5)
	panel_style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Play Shapes · Debug"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("133253"))
	column.add_child(title)

	var hint := Label.new()
	hint.text = "F12 closes this overlay. The game and LAN session keep running."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("34516b"))
	hint.add_theme_font_size_override("font_size", 17)
	column.add_child(hint)

	_scenario_list = VBoxContainer.new()
	_scenario_list.add_theme_constant_override("separation", 8)
	column.add_child(_scenario_list)

	var separator := HSeparator.new()
	column.add_child(separator)

	_restart_button = Button.new()
	_restart_button.text = "Restart current debug scenario"
	_style_action(_restart_button, Color("087b70"))
	_restart_button.pressed.connect(restart_scenario)
	column.add_child(_restart_button)

	var lobby_button := Button.new()
	lobby_button.text = "Return to lobby"
	_style_action(lobby_button, Color("1d4367"))
	lobby_button.pressed.connect(return_to_lobby)
	column.add_child(lobby_button)


func _refresh_actions() -> void:
	if _scenario_list == null:
		return
	for child: Node in _scenario_list.get_children():
		child.queue_free()
	for scenario: DebugScenario in _scenarios:
		var state := scenario.availability(_features)
		var button := Button.new()
		button.text = (
			scenario.display_name
			if bool(state.available)
			else "%s — Unavailable" % scenario.display_name
		)
		button.disabled = not bool(state.available)
		button.tooltip_text = str(state.reason)
		_style_action(button, Color("1d4367"))
		button.pressed.connect(launch.bind(scenario.id))
		_scenario_list.add_child(button)
	_restart_button.disabled = active_scenario == null


func _style_action(button: Button, fill: Color) -> void:
	button.custom_minimum_size.y = 46.0
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("eef1ec"))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (
			Color("9aa9a8")
			if state == "disabled"
			else fill.lightened(0.13 if state == "hover" else 0.0)
		)
		style.border_color = Color("c8d9cf") if state == "disabled" else Color("88d7c5")
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.content_margin_left = 12
		style.content_margin_right = 12
		button.add_theme_stylebox_override(state, style)


func _update_marker() -> void:
	_marker.visible = active_scenario != null
	_marker.text = "DEBUG — %s" % active_scenario.display_name if active_scenario != null else ""


func _prepare_scenario_launch(scenario: DebugScenario) -> bool:
	if scenario.minigame_id.is_empty():
		return true
	return bool(
		SessionHost.prepare_minigame_launch(scenario.minigame_id, true).get("accepted", false)
	)
