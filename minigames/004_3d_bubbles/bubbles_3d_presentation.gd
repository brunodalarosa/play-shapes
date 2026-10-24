class_name Bubbles3DPresentation
extends Control
## The shared screen of Bubbles and jellyfishes 3D: the underwater world, the arenas, the timer,
## countdown, nameplates, sound and results. Every score, phase and outcome comes from the
## controller; this node only shows them and drives the arenas once per physics frame.

## The id this minigame has in the catalog.
const MINIGAME_ID := &"bubbles_3d"
## Where creatures spawn and travel: the 2D arena's inset, in plane units.
const CREATURE_BOUNDS := Rect2(-8.4, -4.0, 16.8, 7.8)
## Starting places lie on this ellipse around the plane's centre.
const START_ELLIPSE := Vector2(5.7, 2.7)
## Vertical field of view that frames the plane edge to edge at 16:9.
const CAMERA_FOV := 30.0
const PLANE_ASPECT := 16.0 / 9.0
const CUBIO_SCENE: PackedScene = preload("res://characters/cubio_3d.tscn")
const MUSIC: AudioStream = preload("res://assets/runtime/bgm/Beach_music.ogg")
const SFX: Dictionary[StringName, AudioStream] = {
	&"collect": preload("res://assets/runtime/sfxs/drawKnife2.ogg"),
	&"pop": preload("res://assets/runtime/sfxs/chop.ogg"),
	&"reform": preload("res://assets/runtime/sfxs/maximize_006.ogg"),
	&"shove": preload("res://assets/runtime/sfxs/select_006.ogg"),
	&"beat": preload("res://assets/runtime/sfxs/stonesHit1.ogg"),
}
const PROPS := "res://assets/runtime/minigames/bubbles_3d/"
const CORAL_COLOURS: Array[Color] = [Color("f06292"), Color("ff8a65"), Color("ba68c8")]
const KELP_COLOURS: Array[Color] = [Color("26a69a"), Color("66bb6a")]
const ROCK_COLOUR := Color("5c7fa3")

@onready var controller: Bubbles3DRoundController = $RoundController
@onready var player_arena: Bubbles3DPlayerArena = $World/PlayerArena
@onready var creature_arena: Bubbles3DCreatureArena = $World/CreatureArena
@onready var water: UnderwaterEnvironment = $World/Water
@onready var camera: Camera3D = $World/Camera
@onready var _scenery: Node3D = $World/Scenery
@onready var _nameplates: Control = $Hud/Nameplates
@onready var _timer: Label = $Hud/Timer
@onready var _cue: Label = $Hud/CenterCue
@onready var _results: Control = $Hud/Results
@onready var _results_list: VBoxContainer = $Hud/Results/Margin/Column/ResultsList
@onready var _return_button: Button = $Hud/Results/Margin/Column/ReturnToLobby
@onready var _debug_label: Label = $Hud/DebugLabel

var _music: AudioStreamPlayer
var _audio_players: Dictionary[StringName, Array] = { }
var _audio_counts: Dictionary[StringName, int] = { }
var _started := false
var _entrance_done := false
var _entrance_tween: Tween
var _last_countdown_second := -1
var _last_timer_second := -1
var _go_until_msec := -1
var _pending_reforms: Dictionary[String, int] = { }
var _last_shove_by_pair: Dictionary[String, int] = { }
var _labels: Dictionary[String, ScreenFollowLabel] = { }
var _protocol: Bubbles3DProtocol


func _ready() -> void:
	_setup_audio()
	_apply_water_look()
	_dress_seabed()
	controller.phase_changed.connect(_on_phase_changed)
	controller.feedback_requested.connect(_on_feedback)
	controller.round_results_ready.connect(_on_results)
	_return_button.pressed.connect(_on_return_pressed)
	resized.connect(_fit_camera)
	_fit_camera()
	set_process(false)
	set_physics_process(false)
	var session_host := get_node_or_null("/root/SessionHost")
	if session_host == null:
		return
	var launch: Dictionary = session_host.consume_minigame_launch(MINIGAME_ID)
	if launch.is_empty():
		return
	controller.return_to_lobby_requested.connect(_on_return_to_lobby_requested)
	session_host.players_changed.connect(_on_registry_players_changed)
	var started := start_round(
		launch.get("participants", []),
		Time.get_ticks_msec(),
		bool(launch.get("allow_one_player_debug", false)),
	)
	if not bool(started.accepted):
		var code: StringName = started.get("code", &"unknown")
		push_error("Bubbles and jellyfishes 3D could not start: %s" % code)
		_return_to_lobby.call_deferred()
		return
	_protocol = Bubbles3DProtocol.new(controller)
	session_host.register_minigame_protocol(_protocol)


## Starts a round with the registry's participants. The host calls this through the launch.
func start_round(
	participants: Array,
	host_time_msec: int,
	allow_one_player_debug := false,
) -> Dictionary:
	if _started:
		return { "accepted": false, "code": &"round_already_started" }
	var outcome := controller.start_round(participants, host_time_msec, allow_one_player_debug)
	if not outcome.accepted:
		return outcome
	_started = true
	_debug_label.visible = controller.is_one_player_debug()
	player_arena.setup(controller, CREATURE_BOUNDS)
	player_arena.player_collision.connect(_on_player_collision)
	var ordered: Array[Dictionary] = []
	for state: Dictionary in controller.player_snapshot().values():
		ordered.append(state)
	ordered.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.seat < b.seat,
	)
	# Even angles from a random start keep every starting pair apart.
	var turn := controller.next_random_unit() * TAU
	var duration := maxf(0.5, controller.tuning.instructions_seconds)
	for index: int in ordered.size():
		var state := ordered[index]
		var angle := turn + TAU * float(index) / float(ordered.size())
		var destination := Vector2(cos(angle), sin(angle)) * START_ELLIPSE
		var bubble := player_arena.add_bubble(String(state.player_id), destination)
		if bubble == null:
			continue
		var side := -1.0 if index % 2 == 0 else 1.0
		bubble.position = Vector3(
			side * (Bubbles3DPlayerArena.PLANE.end.x + 2.5),
			destination.y,
			0.0,
		)
		if _entrance_tween == null:
			_entrance_tween = create_tween().set_parallel(true)
		var target := PlaneLock3D.on_plane(destination)
		var slide := _entrance_tween.tween_property(bubble, "position", target, duration)
		slide.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_add_nameplate(String(state.player_id), String(state.get("name", "")), bubble)
	creature_arena.setup(controller, player_arena)
	_apply_audio_gains()
	_music.play()
	set_process(true)
	set_physics_process(true)
	return outcome


func _exit_tree() -> void:
	if _protocol != null:
		var session_host := get_node_or_null("/root/SessionHost")
		if session_host != null:
			session_host.unregister_minigame_protocol(_protocol)
		_protocol = null
	if _music != null:
		_music.stop()
	for pool: Array in _audio_players.values():
		for player: AudioStreamPlayer in pool:
			player.stop()


func _process(_delta: float) -> void:
	if not _started:
		return
	var now := maxi(Time.get_ticks_msec(), controller.last_host_time_msec())
	match controller.phase_name():
		&"instructions":
			var sliding := _entrance_tween != null and _entrance_tween.is_running()
			if not _entrance_done and not sliding:
				_entrance_done = true
			if _entrance_done:
				controller.complete_entrance(now)
		&"countdown":
			# The deadline decides the numbers, never the frame count.
			var left := float(controller.countdown_deadline_msec() - now) / 1000.0
			var second := maxi(1, ceili(maxf(0.0, left)))
			if second != _last_countdown_second:
				_last_countdown_second = second
				_cue.text = str(second)
				_pulse(_cue, 1.22 if second == 1 else 1.08)
				_play_sfx(&"beat")
		&"active":
			if _go_until_msec >= 0 and now >= _go_until_msec:
				_cue.visible = false
				_go_until_msec = -1
			_update_timer(now)
	for player_id: String in _pending_reforms.keys():
		if now >= _pending_reforms[player_id]:
			_pending_reforms.erase(player_id)
			_play_sfx(&"reform")
	for player_id: String in _labels:
		var bubble := player_arena.get_bubble(player_id)
		if bubble != null:
			_labels[player_id].world_offset = Vector3(0.0, bubble.shell.shown_radius() + 0.08, 0.0)


func _physics_process(delta: float) -> void:
	if not _started:
		return
	var now := maxi(Time.get_ticks_msec(), controller.last_host_time_msec())
	if controller.phase_name() in [&"countdown", &"active"]:
		player_arena.simulate_step(minf(delta, 0.05), now)
		creature_arena.simulate_step(minf(delta, 0.05), now)


## Frames the 19.2 x 10.8 plane edge to edge at 16:9. Wider screens show more water at the
## sides; narrower ones keep the full width and show more above and below.
func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var aspect := view.x / maxf(1.0, view.y)
	var half_height := Bubbles3DPlayerArena.PLANE.size.y * 0.5
	var distance := half_height / tan(deg_to_rad(CAMERA_FOV * 0.5))
	camera.position = Vector3(0.0, 0.0, distance)
	if aspect >= PLANE_ASPECT:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = CAMERA_FOV
	else:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		var half_width := Bubbles3DPlayerArena.PLANE.size.x * 0.5
		camera.fov = rad_to_deg(2.0 * atan(half_width / distance))


func _apply_water_look() -> void:
	var tuning := controller.tuning
	water.top_colour = tuning.water_top_colour
	water.bottom_colour = tuning.water_bottom_colour
	water.ray_strength = tuning.god_ray_strength
	water.ray_speed = tuning.god_ray_speed
	water.caustic_strength = tuning.caustic_strength
	water.haze_begin = tuning.haze_begin
	water.haze_end = tuning.haze_end
	water.air_bubble_rate = tuning.air_bubble_rate


## Places the faded seabed scenery: stacked ledges at the sides, coral and kelp low in the
## corners, rocks along the floor, a sunken mug far left and a bottle far right.
func _dress_seabed() -> void:
	var floor_y := water.seabed_height
	var rocks := [
		["rocks/forest_nature/Rock_1_L_Color1.gltf", Vector3(-21.0, floor_y, -32.0), 3.0, 0.4],
		["rocks/forest_nature/Rock_1_L_Color1.gltf", Vector3(22.0, floor_y, -33.0), 3.2, 2.6],
		["rocks/forest_nature/Rock_3_M_Color1.gltf", Vector3(-8.0, floor_y - 0.6, -36.0), 1.4, 1.1],
		["rocks/forest_nature/Rock_3_M_Color1.gltf", Vector3(9.5, floor_y - 0.6, -34.0), 1.2, 2.0],
		["rocks/space_base_bits/rocks_A.gltf", Vector3(-2.0, floor_y, -26.0), 2.0, 0.3],
		["rocks/space_base_bits/rocks_A.gltf", Vector3(5.0, floor_y, -29.0), 1.8, 2.4],
	]
	for entry: Array in rocks:
		_prop(entry[0], entry[1], entry[2], entry[3], ROCK_COLOUR)
	var coral := [
		["coral/Tree_Bare_2_A_Color1.gltf", Vector3(-15.0, floor_y, -27.0), 0.9, 0.2],
		["coral/Tree_Bare_1_C_Color1.gltf", Vector3(-11.5, floor_y, -33.0), 0.6, 1.4],
		["coral/Tree_Bare_2_A_Color1.gltf", Vector3(14.0, floor_y, -26.0), 0.85, 2.8],
		["coral/Tree_Bare_1_C_Color1.gltf", Vector3(17.5, floor_y, -34.0), 0.6, 0.9],
		["coral/Tree_Bare_2_A_Color1.gltf", Vector3(-6.0, floor_y, -38.0), 0.8, 1.7],
		["coral/Tree_Bare_2_A_Color1.gltf", Vector3(7.0, floor_y, -39.0), 0.75, 0.6],
	]
	for index: int in coral.size():
		var entry: Array = coral[index]
		var colour := CORAL_COLOURS[index % CORAL_COLOURS.size()]
		_prop(entry[0], entry[1], entry[2], entry[3], colour)
	var kelp := [
		["kelp/Grass_2_D_Singlesided_Color1.gltf", Vector3(-17.0, floor_y, -24.0), 1.3, 3.6],
		["kelp/Grass_1_C_Color1.gltf", Vector3(-13.0, floor_y, -25.0), 1.5, 4.2],
		["kelp/Grass_2_D_Singlesided_Color1.gltf", Vector3(-9.0, floor_y, -30.0), 1.2, 3.2],
		["kelp/Grass_1_C_Color1.gltf", Vector3(11.0, floor_y, -25.0), 1.5, 4.0],
		["kelp/Grass_2_D_Singlesided_Color1.gltf", Vector3(15.5, floor_y, -23.5), 1.3, 3.6],
		["kelp/Grass_1_C_Color1.gltf", Vector3(19.0, floor_y, -28.0), 1.4, 4.6],
		["kelp/Grass_2_D_Singlesided_Color1.gltf", Vector3(1.5, floor_y, -34.0), 1.2, 3.0],
	]
	for index: int in kelp.size():
		var entry: Array = kelp[index]
		var stretch: float = entry[3]
		var colour := KELP_COLOURS[index % KELP_COLOURS.size()]
		var model := _prop(entry[0], entry[1], entry[2], float(index) * 1.3, colour, 0.18, 0.9)
		model.scale.y *= stretch
	var mug := _prop("mug/cup.glb", Vector3(-18.5, floor_y + 0.1, -25.0), 8.0, 0.6)
	mug.rotation.z = deg_to_rad(-24.0)
	var bottle := _prop("bottle/bottle_A_green.gltf", Vector3(19.5, floor_y + 0.9, -27.0), 3.6, 0.4)
	bottle.rotation = Vector3(0.0, deg_to_rad(-20.0), deg_to_rad(90.0))


## Adds one library model as faded scenery. A [param colour] replaces its material with the
## shared underwater prop material; without one, its own materials stay.
func _prop(
	file: String,
	at: Vector3,
	size: float,
	turn: float,
	colour := Color(0.0, 0.0, 0.0, 0.0),
	sway := 0.0,
	sway_height := 1.0,
) -> Node3D:
	var model := (load(PROPS + file) as PackedScene).instantiate() as Node3D
	model.position = at
	model.scale = Vector3.ONE * size
	model.rotation.y = turn
	_scenery.add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if colour.a > 0.0:
			mesh.material_override = water.prop_material(colour, sway, sway_height)
	return model


func _add_nameplate(player_id: String, display_name: String, bubble: Bubbles3DPlayerBubble) -> void:
	var label := ScreenFollowLabel.new()
	label.name = "Nameplate_%s" % player_id.validate_node_name()
	label.text = display_name
	label.target = bubble
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.16, 0.3))
	label.add_theme_constant_override("outline_size", 10)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 280.0
	_nameplates.add_child(label)
	_labels[player_id] = label


func _on_phase_changed(phase: StringName, _snapshot: Dictionary) -> void:
	match phase:
		&"countdown":
			_cue.visible = true
			_last_countdown_second = -1
		&"active":
			_cue.text = "GO"
			_cue.visible = true
			_pulse(_cue, 1.25)
			_go_until_msec = controller.last_host_time_msec() + 650
			_timer.visible = true
			_last_timer_second = -1
			_update_timer(controller.last_host_time_msec())
		&"results":
			_timer.text = "0"
			_cue.visible = false
			_pending_reforms.clear()
			_music.stop()
		&"lobby_return":
			_music.stop()


## Shows whole seconds left; the final seconds pulse larger each beat, strongest on 3, 2 and 1,
## so urgency never depends on colour alone.
func _update_timer(now: int) -> void:
	var second := maxi(0, ceili(float(controller.finish_msec() - now) / 1000.0))
	_timer.text = str(second)
	if second == _last_timer_second:
		return
	_last_timer_second = second
	var emphasis_from := controller.tuning.final_timer_emphasis_seconds
	if second > 0 and second <= emphasis_from:
		var progress := 1.0 - float(second - 1) / float(emphasis_from)
		var emphasis := 0.08 + progress * 0.18 + (0.16 if second <= 3 else 0.0)
		_pulse(_timer, 1.0 + emphasis * controller.tuning.timer_pulse_strength)
		_play_sfx(&"beat")
	else:
		_timer.scale = Vector2.ONE


func _pulse(label: Label, strength: float) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * strength
	var settle := create_tween().tween_property(label, "scale", Vector2.ONE, 0.36)
	settle.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_feedback(player_id: String, kind: StringName, data: Dictionary) -> void:
	match kind:
		&"captured":
			_play_sfx(&"collect")
		&"pop":
			_play_sfx(&"pop")
			var at := int(data.get("at_msec", Time.get_ticks_msec()))
			_pending_reforms[player_id] = at + roundi(
				controller.tuning.bubble_reform_seconds * 1000.0
			)


func _on_player_collision(first_id: String, second_id: String) -> void:
	var pair := "%s:%s" % [first_id, second_id]
	var now := controller.last_host_time_msec()
	if now - _last_shove_by_pair.get(pair, -1000) < 240:
		return
	_last_shove_by_pair[pair] = now
	_play_sfx(&"shove")


func _on_results(snapshot: Dictionary) -> void:
	_nameplates.visible = false
	for row: Node in _results_list.get_children():
		row.queue_free()
	var ranking: Array = snapshot.get("ranking", [])
	for entry: Dictionary in ranking:
		_add_result_row(entry, ranking.size())
	_results.visible = true
	_return_button.disabled = false
	_return_button.grab_focus.call_deferred()


func _add_result_row(entry: Dictionary, count: int) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = clampf((size.y * 0.7) / float(maxi(count, 1)), 48.0, 92.0)
	row.add_theme_constant_override("separation", 18)
	_results_list.add_child(row)
	var portrait_size := row.custom_minimum_size.y
	row.add_child(_result_label("#%d" % int(entry.get("rank", 0)), 0.09, 30))
	row.add_child(
		_portrait(
			Color(String(CharacterSelection.for_player(entry).character_color)),
			portrait_size,
		)
	)
	var name_label := _result_label(String(entry.get("name", "Player")), 0.7, 30)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	var score := int(entry.get("score", 0))
	row.add_child(_result_label("%d %s" % [score, "jellyfish"], 0.21, 28))


## A small live render of the player's Cubio for a results row.
func _portrait(colour: Color, edge: float) -> SubViewportContainer:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(edge, edge)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	frame.add_child(view)
	var cubio := CUBIO_SCENE.instantiate() as Cubio3D
	cubio.player_color = colour
	view.add_child(cubio)
	# The nameplate is ready only once the portrait is in the tree.
	cubio.ready.connect(
		func() -> void:
			cubio.nameplate.visible = false,
	)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	view.add_child(light)
	var lens := Camera3D.new()
	lens.fov = 30.0
	lens.position = Vector3(0.0, 0.5, 2.6)
	view.add_child(lens)
	lens.current = true
	return frame


func _result_label(value: String, ratio: float, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = ratio
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _on_return_pressed() -> void:
	_return_button.disabled = controller.request_return_to_lobby()


func _on_return_to_lobby_requested() -> void:
	_return_to_lobby.call_deferred()


func _return_to_lobby() -> void:
	var launcher := get_node_or_null("/root/DebugLauncher")
	if launcher != null:
		# The shared transport has no return hook for this minigame, so the launcher tells phones.
		launcher.return_to_lobby(true)
	else:
		var session_host := get_node_or_null("/root/SessionHost")
		if session_host != null:
			session_host.send_players_to_lobby()
			session_host.clear_minigame_launch()
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _on_registry_players_changed(players: Array[Dictionary]) -> void:
	if _started:
		controller.observe_registry(players, Time.get_ticks_msec())


func _setup_audio() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.stream = MUSIC.duplicate()
	if _music.stream is AudioStreamOggVorbis:
		(_music.stream as AudioStreamOggVorbis).loop = true
	add_child(_music)
	for kind: StringName in SFX:
		var pool: Array[AudioStreamPlayer] = []
		for index: int in (16 if kind == &"collect" else 4):
			var player := AudioStreamPlayer.new()
			player.name = "%s%d" % [kind, index]
			player.stream = SFX[kind]
			add_child(player)
			pool.append(player)
		_audio_players[kind] = pool
		_audio_counts[kind] = 0
	_apply_audio_gains()


func _apply_audio_gains() -> void:
	_music.volume_db = controller.tuning.music_gain_db
	for kind: StringName in _audio_players:
		for player: AudioStreamPlayer in _audio_players[kind]:
			player.volume_db = controller.tuning.sfx_gain_db - (3.0 if kind == &"collect" else 0.0)


func _play_sfx(kind: StringName) -> void:
	var pool: Array = _audio_players.get(kind, [])
	if pool.is_empty():
		return
	var count: int = _audio_counts.get(kind, 0)
	(pool[count % pool.size()] as AudioStreamPlayer).play()
	_audio_counts[kind] = count + 1


func audio_event_count(kind: StringName) -> int:
	return _audio_counts.get(kind, 0)
