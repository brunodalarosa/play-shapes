class_name BubblesPresentation
extends Control
## Shared screen composition. All scores, phases and outcomes come from the controller.

const WORLD_SIZE := Vector2(1920.0, 1080.0)
const NPC_ARENA_BOUNDS := Rect2(120.0, 160.0, 1680.0, 780.0)
const CHARACTER_SCENE: PackedScene = preload("res://characters/shape_character.tscn")
const MUSIC: AudioStream = preload("res://assets/runtime/bgm/Beach_music.ogg")
const SFX: Dictionary = {
	&"collect": preload("res://assets/runtime/sfxs/drawKnife2.ogg"),
	&"pop": preload("res://assets/runtime/sfxs/chop.ogg"),
	&"reform": preload("res://assets/runtime/sfxs/maximize_006.ogg"),
	&"shove": preload("res://assets/runtime/sfxs/select_006.ogg"),
	&"spin_charge": preload("res://assets/runtime/sfxs/upgrade1.ogg"),
	&"spin_activate": preload("res://assets/runtime/sfxs/woosh4.ogg"),
	&"final_beat": preload("res://assets/runtime/sfxs/stonesHit1.ogg"),
}

@onready var controller: BubblesRoundController = $RoundController
@onready var player_arena: BubblesPlayerArena = $World/PlayerArena
@onready var creature_arena: BubblesCreatureArena = $World/CreatureArena
@onready var _world: Node2D = $World
@onready var _far: TextureRect = $FarBackground
@onready var _mid: TextureRect = $Midground
@onready var _foreground: TextureRect = $Foreground
@onready var _timer: Label = $Hud/Timer
@onready var _cue: Label = $Hud/CenterCue
@onready var _instructions: PanelContainer = $Hud/InstructionCard
@onready var _results: ColorRect = $Hud/Results
@onready var _results_list: VBoxContainer = $Hud/Results/ResultsList
@onready var _return_button: Button = $Hud/Results/ReturnToLobby
@onready var _debug_label: Label = $Hud/DebugLabel

var _music: AudioStreamPlayer
var _audio_players: Dictionary = {}
var _audio_counts: Dictionary = {}
var _started := false
var _entrance_done := false
var _entrance_tween: Tween
var _last_countdown_second := -1
var _last_timer_second := -1
var _go_until_msec := -1
var _pending_reforms: Dictionary = {}
var _last_shove_by_pair: Dictionary = {}
var _ambient_seconds := 0.0
var _protocol_registered := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_far.pivot_offset = _far.size * 0.5
	_mid.pivot_offset = _mid.size * 0.5
	_foreground.pivot_offset = _foreground.size * 0.5
	_style_instruction_card()
	_setup_audio()
	controller.phase_changed.connect(_on_phase_changed)
	controller.feedback_requested.connect(_on_feedback)
	controller.round_results_ready.connect(_on_results)
	player_arena.player_collision.connect(_on_player_collision)
	_return_button.pressed.connect(_on_return_pressed)
	resized.connect(_layout_world)
	_layout_world()
	set_process(false)
	set_physics_process(false)
	var session_host := get_node_or_null("/root/SessionHost")
	if session_host == null:
		return
	var launch: Dictionary = session_host.consume_bubbles_launch()
	if launch.is_empty():
		return
	controller.return_to_lobby_requested.connect(_on_return_to_lobby_requested)
	session_host.players_changed.connect(_on_registry_players_changed)
	var started := start_round(
		launch.get("participants", []),
		Time.get_ticks_msec(),
		bool(launch.get("allow_one_player_debug", false))
	)
	if not bool(started.accepted):
		push_error("Bubbles and Jellyfishes could not start: %s" % started.get("code", &"unknown"))
		_return_to_lobby.call_deferred()
		return
	_protocol_registered = true
	session_host.register_bubbles_controller(controller)


## PS-046 will call this after choosing Bubbles and registering the active protocol.
func start_round(participants: Array, host_time_msec: int, allow_one_player_debug := false) -> Dictionary:
	if _started:
		return {"accepted": false, "code": &"round_already_started"}
	var outcome := controller.start_round(participants, host_time_msec, allow_one_player_debug)
	if not outcome.accepted:
		return outcome
	_started = true
	_debug_label.visible = controller.is_one_player_debug()
	player_arena.setup(controller, NPC_ARENA_BOUNDS, _viewport_bounds())
	var ordered: Array[Dictionary] = []
	for state: Dictionary in controller.player_snapshot().values():
		ordered.append(state)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.seat < b.seat)
	# Equal angular spacing and a random rotation keep every starting pair separated.
	var rotation := controller.next_random_unit() * TAU
	for index: int in ordered.size():
		var state := ordered[index]
		var angle := rotation + TAU * float(index) / float(ordered.size())
		var destination := NPC_ARENA_BOUNDS.get_center() + Vector2(cos(angle) * 570.0, sin(angle) * 270.0)
		var bubble := player_arena.add_bubble(String(state.player_id), destination)
		if bubble == null:
			continue
		var from_left := index % 2 == 0
		bubble.position = Vector2(-160.0 if from_left else WORLD_SIZE.x + 160.0, destination.y)
		if _entrance_tween == null:
			_entrance_tween = create_tween().set_parallel(true)
		_entrance_tween.tween_property(bubble, "position", destination, maxf(0.5, controller.tuning.instructions_seconds * 0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	creature_arena.setup(controller, player_arena)
	_instructions.visible = true
	_apply_audio_gains()
	_play_music()
	set_process(true)
	set_physics_process(true)
	return outcome


func _exit_tree() -> void:
	if _protocol_registered:
		var session_host := get_node_or_null("/root/SessionHost")
		if session_host != null:
			session_host.unregister_bubbles_controller(controller)
		_protocol_registered = false
	if _music != null:
		_music.stop()
	for players: Array in _audio_players.values():
		for player: AudioStreamPlayer in players:
			player.stop()


func _process(delta: float) -> void:
	_ambient_seconds += delta
	# Motion stays under one percent of an overscanned plate; the center stays quiet.
	_far.scale = Vector2.ONE * 1.025
	_mid.scale = Vector2.ONE * 1.032
	_foreground.scale = Vector2.ONE * 1.018
	var drift := controller.tuning.parallax_strength
	_far.position = Vector2(sin(_ambient_seconds * 0.18) * 4.0, cos(_ambient_seconds * 0.13) * 3.0) * drift
	_mid.position = Vector2(sin(_ambient_seconds * 0.32) * 9.0, cos(_ambient_seconds * 0.24) * 5.0) * drift
	_foreground.position = Vector2(sin(_ambient_seconds * 0.43) * 5.0, 0.0) * drift
	if not _started:
		return
	var now := maxi(Time.get_ticks_msec(), controller.last_host_time_msec())
	if controller.phase_name() == &"instructions":
		if not _entrance_done and (_entrance_tween == null or not _entrance_tween.is_running()):
			_entrance_done = true
		if _entrance_done:
			controller.complete_entrance(now)
	elif controller.phase_name() == &"countdown":
		# Use the transition's fixed deadline, never the animation's frame count.
		var left := maxf(0.0, float(_countdown_end_msec - now) / 1000.0)
		var second := maxi(1, ceili(left))
		if second != _last_countdown_second:
			_last_countdown_second = second
			_cue.text = str(second)
			_pulse(_cue, 1.22 if second == 1 else 1.08)
	elif controller.phase_name() == &"active":
		if _go_until_msec >= 0 and now >= _go_until_msec:
			_cue.visible = false
			_go_until_msec = -1
		_update_timer(now)
	for player_id: String in _pending_reforms.keys():
		if now >= int(_pending_reforms[player_id]):
			_pending_reforms.erase(player_id)
			_play_sfx(&"reform")


var _countdown_end_msec := -1


func _physics_process(delta: float) -> void:
	if not _started:
		return
	var now := maxi(Time.get_ticks_msec(), controller.last_host_time_msec())
	if controller.phase_name() in [&"countdown", &"active"]:
		player_arena.simulate_step(minf(delta, 0.05), now)
		creature_arena.simulate_step(minf(delta, 0.05), now)


func _layout_world() -> void:
	var factor := minf(size.x / WORLD_SIZE.x, size.y / WORLD_SIZE.y)
	_world.scale = Vector2.ONE * factor
	_world.position = (size - WORLD_SIZE * factor) * 0.5
	for plate: TextureRect in [_far, _mid, _foreground]:
		plate.pivot_offset = plate.size * 0.5
	if _started and is_instance_valid(player_arena):
		player_arena.set_wall_bounds(_viewport_bounds())


func _viewport_bounds() -> Rect2:
	return get_viewport().get_visible_rect()


func _on_phase_changed(phase: StringName, _snapshot: Dictionary) -> void:
	match phase:
		&"countdown":
			_instructions.visible = false
			_cue.visible = true
			_last_countdown_second = -1
			_countdown_end_msec = controller.last_host_time_msec() + roundi(controller.tuning.countdown_seconds * 1000.0)
		&"active":
			_instructions.visible = false
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


func _update_timer(now: int) -> void:
	var end_msec := controller.active_start_msec() + roundi(controller.tuning.round_duration_seconds * 1000.0)
	var second := maxi(0, ceili(float(end_msec - now) / 1000.0))
	_timer.text = str(second)
	if second == _last_timer_second:
		return
	_last_timer_second = second
	if second > 0 and second <= controller.tuning.final_timer_emphasis_seconds:
		var progress := 1.0 - float(second - 1) / float(controller.tuning.final_timer_emphasis_seconds)
		var strength := 1.0 + (0.08 + progress * 0.18 + (0.16 if second <= 3 else 0.0)) * controller.tuning.timer_pulse_strength
		_pulse(_timer, strength)
		_play_sfx(&"final_beat")
	else:
		_timer.scale = Vector2.ONE


func _pulse(label: Label, strength: float) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * strength
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_feedback(_player_id: String, kind: StringName, data: Dictionary) -> void:
	match kind:
		&"captured":
			_play_sfx(&"collect")
		&"pop":
			_play_sfx(&"pop")
			_pending_reforms[_player_id] = int(data.get("at_msec", Time.get_ticks_msec())) + roundi(controller.tuning.bubble_reform_seconds * 1000.0)
		&"spin":
			# The completed release is the authoritative full-charge decision.
			_play_sfx(&"spin_charge")
			_play_sfx(&"spin_activate")


func _on_player_collision(first_id: String, second_id: String, _spun_id: String) -> void:
	var pair := "%s:%s" % [first_id, second_id]
	var now := controller.last_host_time_msec()
	if now - int(_last_shove_by_pair.get(pair, -1000)) < 240:
		return
	_last_shove_by_pair[pair] = now
	_play_sfx(&"shove")


func _on_results(snapshot: Dictionary) -> void:
	_world.visible = false
	for row: Node in _results_list.get_children():
		row.queue_free()
	var ranking: Array = snapshot.get("ranking", [])
	for entry: Dictionary in ranking:
		_add_result_row(entry, ranking.size())
	_results.visible = true
	_return_button.disabled = false


func _add_result_row(entry: Dictionary, count: int) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = clampf((size.y * 0.73) / float(maxi(count, 1)), 45.0, 92.0)
	row.add_theme_constant_override("separation", 18)
	_results_list.add_child(row)
	var color := BubblesPlayerArena.SEAT_COLORS[posmod(int(entry.get("seat", 1)) - 1, BubblesPlayerArena.SEAT_COLORS.size())]
	var rank := _result_label("#%d" % int(entry.get("rank", 0)), 0.09, 27)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(58, 48)
	var character := CHARACTER_SCENE.instantiate() as ShapeCharacter
	portrait.add_child(character)
	character.position = Vector2(29, 25)
	character.scale = Vector2.ONE * 0.27
	character.player_color = color
	var name_label := _result_label(String(entry.get("name", "Player")), 0.7, 27)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var count_label := _result_label("%d jellyfish" % int(entry.get("score", 0)), 0.21, 26)
	row.add_child(rank)
	row.add_child(portrait)
	row.add_child(name_label)
	row.add_child(count_label)


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
		launcher.return_to_lobby(false)
	else:
		var session_host := get_node_or_null("/root/SessionHost")
		if session_host != null:
			session_host.send_players_to_lobby()
			session_host.clear_minigame_launch()
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _on_registry_players_changed(players: Array[Dictionary]) -> void:
	if _started:
		controller.observe_registry(players, Time.get_ticks_msec())


func _style_instruction_card() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.14, 0.22, 0.93)
	panel.border_color = Color(0.7, 0.94, 0.96, 0.95)
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(20)
	panel.set_content_margin_all(24)
	_instructions.add_theme_stylebox_override("panel", panel)


func _setup_audio() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "BubblesMusic"
	_music.volume_db = controller.tuning.music_gain_db
	_music.stream = MUSIC.duplicate()
	if _music.stream is AudioStreamOggVorbis:
		(_music.stream as AudioStreamOggVorbis).loop = true
	add_child(_music)
	for kind: StringName in SFX.keys():
		var pool: Array[AudioStreamPlayer] = []
		for index: int in (16 if kind == &"collect" else 4):
			var player := AudioStreamPlayer.new()
			player.name = "%s%d" % [kind, index]
			player.stream = SFX[kind]
			player.volume_db = controller.tuning.sfx_gain_db - (3.0 if kind == &"collect" else 0.0)
			add_child(player)
			pool.append(player)
		_audio_players[kind] = pool
		_audio_counts[kind] = 0


func _apply_audio_gains() -> void:
	_music.volume_db = controller.tuning.music_gain_db
	for kind: StringName in _audio_players.keys():
		for player: AudioStreamPlayer in _audio_players[kind]:
			player.volume_db = controller.tuning.sfx_gain_db - (3.0 if kind == &"collect" else 0.0)


func _play_music() -> void:
	if not _music.playing:
		_music.play()


func _play_sfx(kind: StringName) -> void:
	var pool: Array = _audio_players.get(kind, [])
	if pool.is_empty():
		return
	var count := int(_audio_counts.get(kind, 0))
	(pool[count % pool.size()] as AudioStreamPlayer).play()
	_audio_counts[kind] = count + 1


func audio_event_count(kind: StringName) -> int:
	return int(_audio_counts.get(kind, 0))
