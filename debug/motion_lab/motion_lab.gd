extends Control
## F12-only lab. Existing SessionHost owns all network/identity/sensor services.

## Optional pose smoothing seconds. Zero shows unsmoothed sensor orientation.
@export_range(0.0, 0.5, 0.01, "suffix:s") var smoothing_seconds := 0.0
## Signed acceleration graph range in m/s²; raw readings are never clamped.
@export_range(1.0, 100.0, 1.0) var acceleration_range := 20.0
## Signed angular velocity graph range in degrees per second.
@export_range(10.0, 1000.0, 10.0) var rotation_rate_range := 180.0

var target_player_id := ""
var _channel: MotionInputChannel
var _target_name := ""
var _summary: Label
var _raw: Label
var _pose_status: Label
var _phone: Node3D
var _viewport: SubViewport
var _plots: Array[MotionLabPlot] = []
var _neutral := Quaternion.IDENTITY
var _pose := Quaternion.IDENTITY
var _last_plot_time := -1
var _refresh_elapsed := 0.0
var _recenter_button: Button

func _ready() -> void:
	_channel = SessionHost.websocket.motion_channel
	_build_ui()
	SessionHost.set_accepting_new_players(true)
	SessionHost.players_changed.connect(_on_players_changed)
	_channel.changed.connect(_on_sample_changed)
	_on_players_changed(SessionHost.players())
	_update_readings()

func _exit_tree() -> void:
	SessionHost.set_accepting_new_players(false)
	SessionHost.websocket.end_motion()
	if SessionHost.players_changed.is_connected(_on_players_changed):
		SessionHost.players_changed.disconnect(_on_players_changed)
	if _channel != null and _channel.changed.is_connected(_on_sample_changed):
		_channel.changed.disconnect(_on_sample_changed)

func bind_player_one() -> void:
	SessionHost.websocket.end_motion()
	target_player_id = ""
	_neutral = Quaternion.IDENTITY
	_pose = Quaternion.IDENTITY
	_last_plot_time = -1
	for plot: MotionLabPlot in _plots:
		plot.clear()
	_on_players_changed(SessionHost.players())

func _on_players_changed(players: Array[Dictionary]) -> void:
	if not target_player_id.is_empty():
		return # An expired identity never silently changes to a newly occupied seat.
	for player: Dictionary in players:
		if player.seat == 1 and player.state == "connected":
			target_player_id = player.player_id
			_target_name = player.name
			SessionHost.websocket.begin_motion(target_player_id)
			return

func _on_sample_changed() -> void:
	if _channel.latest.is_empty():
		_last_plot_time = -1
		for plot: MotionLabPlot in _plots:
			plot.clear()
		return
	if _channel.received_at == _last_plot_time:
		return
	_last_plot_time = _channel.received_at
	for index: int in range(3):
		_plots[index].append_sample(_channel.latest[["acceleration", "acceleration_gravity", "rotation_rate"][index]])

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.1:
		_refresh_elapsed = 0.0
		_update_readings()
	if _has_orientation():
		var target := _neutral.inverse() * _current_pose()
		_pose = target if smoothing_seconds <= 0 else _pose.slerp(target, 1.0 - exp(-delta / smoothing_seconds))
		_phone.quaternion = _pose

func _has_orientation() -> bool:
	if _channel == null or not _channel.is_fresh(Time.get_ticks_msec()) or _channel.latest.is_empty():
		return false
	var sample := _channel.latest
	return sample.orientation_age_msec != null and sample.orientation_age_msec + Time.get_ticks_msec() - _channel.received_at <= MotionInputChannel.STALE_MSEC and not sample.orientation.has(null)

func _current_pose() -> Quaternion:
	return MotionOrientation.physical_basis(_channel.latest.orientation, _channel.latest.screen_angle).get_rotation_quaternion()

func recenter() -> void:
	if _has_orientation():
		_neutral = _current_pose()
		_pose = Quaternion.IDENTITY

func reset_calibration() -> void:
	_neutral = Quaternion.IDENTITY

func _update_readings() -> void:
	var connection := "unavailable"
	for player: Dictionary in SessionHost.players():
		if player.player_id == target_player_id:
			connection = player.state
	var age := Time.get_ticks_msec() - _channel.received_at if _channel.received_at >= 0 else -1
	var fresh := _channel.is_fresh(Time.get_ticks_msec())
	var state := String(_channel.diagnostics.get("state", "waiting for phone"))
	if not fresh and age >= 0:
		state = "STALE"
	_summary.text = "Player 1: %s · %s · %s\nSample age: %s · Sent: %.1f Hz · Received: %.1f Hz · cap %d Hz" % [
		_target_name if not target_player_id.is_empty() else "No connected seat 1", connection, state,
		"unavailable" if age < 0 else "%d ms" % age, _channel.transmitted_hz,
		float(_channel.sample_count - 1) * 1000.0 / maxf(Time.get_ticks_msec() - _channel.first_received_at, 1) if _channel.sample_count > 1 else 0.0, MotionInputChannel.MAX_SEND_HZ]
	var diagnostic_lines := "Phone diagnostics\n"
	for field: String in ["secure_context", "page_protocol", "hostname", "websocket_protocol", "websocket_status", "motion_support", "orientation_support", "motion_permission", "orientation_permission", "state"]:
		diagnostic_lines += "%s: %s\n" % [field.replace("_", " "), str(_channel.diagnostics.get(field, "unavailable"))]
	_raw.text = diagnostic_lines + "\nRaw values · unavailable ≠ zero\n"
	if not _channel.latest.is_empty():
		var sample := _channel.latest
		_raw.text += "\nOrientation α, β, γ (degrees)\n%s · %s\n\nAngular velocity α, β, γ (degrees/s)\n%s\n\nAcceleration x, y, z (m/s²)\n%s\n\nIncluding gravity x, y, z (m/s²)\n%s\n\nMotion events: %.1f Hz · age %s ms\nOrientation events: %.1f Hz · age %s ms\nEvent interval: %s ms\nScreen angle: %s°" % [
			_vector_text(sample.orientation), "absolute" if sample.absolute else "relative", _vector_text(sample.rotation_rate), _vector_text(sample.acceleration), _vector_text(sample.acceleration_gravity),
			sample.motion_hz, _value_text(sample.motion_age_msec), sample.orientation_hz, _value_text(sample.orientation_age_msec), _value_text(sample.interval_msec), _value_text(sample.screen_angle)]
	_pose_status.text = "LIVE phone pose" if _has_orientation() else "Pose unavailable / stale — preview held"
	_recenter_button.disabled = not _has_orientation()

func _value_text(value: Variant) -> String:
	return "unavailable" if value == null else "%.3f" % float(value)

func _vector_text(values: Array) -> String:
	return "[%s, %s, %s]" % [_value_text(values[0]), _value_text(values[1]), _value_text(values[2])]

func _button(text: String, action: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	theme = Theme.new()
	theme.set_color("font_color", "Label", Color("173c52"))
	theme.set_font_size("font_size", "Label", 19)
	var background := ColorRect.new()
	background.color = Color("e7efdf")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	stack.add_theme_color_override("font_color", Color("173c52"))
	stack.add_theme_font_size_override("font_size", 19)
	margin.add_child(stack)
	var title := Label.new()
	title.text = "Gyroscope and Accelerometer Lab"
	title.add_theme_font_size_override("font_size", 30)
	stack.add_child(title)
	_summary = Label.new()
	stack.add_child(_summary)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	_recenter_button = _button("Recenter pose", recenter, actions)
	_button("Reset calibration", reset_calibration, actions)
	_button("Bind current Player 1", bind_player_one, actions)
	_button("Return to lobby", func() -> void: DebugLauncher.return_to_lobby(), actions)
	var smooth_label := Label.new()
	smooth_label.text = "Smoothing (seconds)"
	actions.add_child(smooth_label)
	var smoothing := SpinBox.new()
	smoothing.min_value = 0
	smoothing.max_value = 0.5
	smoothing.step = 0.01
	smoothing.value = smoothing_seconds
	smoothing.value_changed.connect(func(value: float) -> void: smoothing_seconds = value)
	actions.add_child(smoothing)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	stack.add_child(row)
	var preview_column := VBoxContainer.new()
	preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_column.size_flags_stretch_ratio = 1.15
	row.add_child(preview_column)
	_pose_status = Label.new()
	preview_column.add_child(_pose_status)
	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_column.add_child(viewport_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(400, 400)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(_viewport)
	_build_phone()
	var pose_hint := Label.new()
	pose_hint.text = "Orange = phone top · cream = screen\nRelative orientation is not compass heading.\nAcceleration is not position. Raw values remain unsmoothed."
	preview_column.add_child(pose_hint)
	var raw_scroll := ScrollContainer.new()
	raw_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(raw_scroll)
	_raw = Label.new()
	_raw.add_theme_font_size_override("font_size", 17)
	raw_scroll.add_child(_raw)
	var plot_column := VBoxContainer.new()
	plot_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plot_column.add_theme_constant_override("separation", 12)
	row.add_child(plot_column)
	for index: int in range(3):
		var plot := MotionLabPlot.new()
		plot.title = ["Acceleration", "Including gravity", "Angular velocity"][index]
		plot.units = "degrees/s" if index == 2 else "m/s²"
		plot.axis_names = ["alpha (z)", "beta (x)", "gamma (y)"] if index == 2 else ["x", "y", "z"]
		plot.display_range = rotation_rate_range if index == 2 else acceleration_range
		plot.custom_minimum_size = Vector2(320, 190)
		plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		plot_column.add_child(plot)
		_plots.append(plot)

func _block(parent: Node3D, dimensions: Vector3, position_value: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.position = position_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh.material_override = material
	parent.add_child(mesh)

func _build_phone() -> void:
	var world := Node3D.new()
	_viewport.add_child(world)
	_phone = Node3D.new()
	world.add_child(_phone)
	_block(_phone, Vector3(1.2, 2.4, 0.18), Vector3.ZERO, Color("497abc"))
	_block(_phone, Vector3(1.05, 2.1, 0.025), Vector3(0, 0, 0.105), Color("fff6d5"))
	_block(_phone, Vector3(0.55, 0.12, 0.03), Vector3(0, 0.85, 0.13), Color("ed9556"))
	_block(_phone, Vector3(0.35, 0.35, 0.03), Vector3(0, -0.1, 0.13), Color("70c1a6"))
	var camera := Camera3D.new()
	camera.fov = 38
	camera.position = Vector3(3, 3, 6)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("d7e6db")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
