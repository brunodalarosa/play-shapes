extends VBoxContainer
## Designer input feeds the host controller; physics is the actual gameplay arena.

var profile: TiltShiftTuning
var roster: int = 10
var arena: TiltShiftArena
var viewport: SubViewport
var _status: Label
var _inputs: VBoxContainer
var _angles: Dictionary = { }
var _elapsed: float = 0.0
var _sample_elapsed: float = 0.0
var _timings := PackedInt32Array()
var _camera: Camera2D
var _players: Array[TiltShiftState.Player] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "Tilt Shift • actual gameplay physics preview"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	_button(toolbar, "Start / restart shift", restart)
	_button(toolbar, "Stop / clear", stop)
	_button(
		toolbar,
		"Next round",
		func() -> void:
			var result := arena.start_next_round()
			if result.accepted:
				_build_inputs()
			else:
				_status.text = "Next round unavailable: " + String(result.reason),
	)
	var row := HSplitContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var frame := SubViewportContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.stretch = true
	row.add_child(frame)
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(viewport)
	arena = TiltShiftArena.new()
	viewport.add_child(arena)
	_camera = Camera2D.new()
	viewport.add_child(_camera)
	frame.resized.connect(_fit_camera)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 300
	row.add_child(scroll)
	_inputs = VBoxContainer.new()
	_inputs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inputs)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	restart.call_deferred()


func restart() -> bool:
	stop()
	_players.clear()
	for index: int in roster:
		var player := TiltShiftState.Player.new()
		player.player_id = "designer_%d" % index
		player.player_name = "Designer %d" % (index + 1)
		player.seat = index + 1
		_players.append(player)
	var result := arena.start_shift(profile, _players)
	if not result.accepted:
		_status.text = "Preview rejected: " + "\n".join(result.errors)
		return false
	_timings.clear()
	_build_inputs()
	_fit_camera()
	return true


func stop() -> void:
	_angles.clear()
	if is_instance_valid(arena):
		arena.stop()
	if is_instance_valid(_status):
		_status.text = "Stopped • temporary balls, assignments and scores cleared."
	if is_instance_valid(_inputs):
		for child: Node in _inputs.get_children():
			_inputs.remove_child(child)
			child.queue_free()


func set_angle(player_id: String, degrees: float) -> bool:
	if arena.controller == null:
		return false
	var snapshot := arena.controller.snapshot()
	var result := arena.controller.accept_angle(
		player_id,
		deg_to_rad(degrees),
		snapshot.round_token,
		Time.get_ticks_msec(),
	)
	if result.accepted:
		_angles[player_id] = degrees
	return result.accepted


func _build_inputs() -> void:
	for child: Node in _inputs.get_children():
		_inputs.remove_child(child)
		child.queue_free()
	var state := arena.controller.snapshot()
	for player: TiltShiftState.Player in state.players:
		var label := Label.new()
		label.text = "%s • %s\n%s" % [
			player.player_name,
			"Orange" if player.team == 0 else "Blue",
			", ".join(player.paddle_ids),
		]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_inputs.add_child(label)
		var angle := SpinBox.new()
		angle.min_value = -360
		angle.max_value = 360
		angle.allow_greater = true
		angle.allow_lesser = true
		angle.step = 5
		angle.suffix = "degrees (unwrapped)"
		angle.value = rad_to_deg(player.angle_radians)
		_inputs.add_child(angle)
		angle.value_changed.connect(
			func(value: float) -> void:
				set_angle(player.player_id, value),
		)
		var buttons := HBoxContainer.new()
		_inputs.add_child(buttons)
		_button(
			buttons,
			"−360°",
			func() -> void:
				angle.value -= 360,
		)
		_button(
			buttons,
			"+360°",
			func() -> void:
				angle.value += 360,
		)


func _fit_camera() -> void:
	if profile == null or not is_instance_valid(viewport):
		return
	var extent := profile.paddle_layout.arena_size * TiltShiftArena.WORLD_UNITS
	_camera.position = extent * 0.5 + Vector2(0, 15)
	var zoom := minf(viewport.size.x / (extent.x + 40), viewport.size.y / (extent.y + 60))
	_camera.zoom = Vector2.ONE * zoom


func _process(delta: float) -> void:
	_elapsed += delta
	_sample_elapsed += delta
	if arena.controller == null:
		return
	if _sample_elapsed >= 0.05:
		_sample_elapsed = 0
		_timings.append(arena.last_step_usec)
		if _timings.size() > 2000:
			_timings.remove_at(0)
	if _elapsed < 0.2:
		return
	_elapsed = 0
	var state := arena.controller.snapshot()
	_status.text = (
		"Round %d/%d • %s • Orange %d / Blue %d • delivered %d • live %d / peak %d\n"
		+ "Position seed %d • arena script p95 %d μs • native physics/rendering excluded"
	) % [
		state.round_number,
		state.round_count,
		state.phase,
		state.scores[0],
		state.scores[1],
		arena.spawned_count,
		arena.live_balls().size(),
		arena.peak_live_balls,
		arena.position_seed_used,
		timing_p95(),
	]


func timing_p95() -> int:
	if _timings.is_empty():
		return 0
	var sorted := _timings.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, floori(sorted.size() * 0.95))]


func _exit_tree() -> void:
	stop()


func _button(parent: Node, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	parent.add_child(button)
	button.pressed.connect(action)
