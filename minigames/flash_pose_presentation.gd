class_name FlashPosePresentation
extends Node
## Shared-screen-only adapter for Flash? Pose!. The round controller owns every
## outcome; this node maps its snapshots and signals to visuals and audio.

const Animator := preload("res://characters/hybrid_character_animator.gd")
const AudioCatalog := preload("res://assets/runtime/audio/flash_pose_audio_catalog.gd")

const DIRECTION_GLYPHS: Dictionary = {
	&"up": "UP  ↑", &"left": "LEFT  ←", &"right": "RIGHT  →", &"down": "DOWN  ↓",
}
const SEAT_COLORS: Array[Color] = [
	Color("5b8df2"), Color("4ecb8d"), Color("f6c453"), Color("9c72e8"), Color("ef7f45"),
	Color("55c7d9"), Color("e867b5"), Color("89b34c"), Color("7f91a8"), Color("d76464"),
]

@export var controller_path: NodePath = ^"../RoundController"
@export var tuning: SimonSaysTuning = preload("res://Tuning/Minigames/SimonSays/Default.tres")

var _controller: FlashPoseRoundController
var _stage: DancerSimonSaysStage
var _lead_animator: HybridCharacterAnimator
var _player_animators: Dictionary = {}
var _seat_animators: Dictionary = {}
var _player_labels: Dictionary = {}
var _countdown_label: Label
var _cue_panel: PanelContainer
var _cue_label: Label
var _feedback_label: Label
var _results: Control
var _winner_panel: PanelContainer
var _loser_panel: PanelContainer
var _happy_names: Label
var _moody_names: Label
var _return_button: Button
var _flash_overlay: ColorRect
var _music: AudioStreamPlayer
var _flash_sfx: AudioStreamPlayer
var _countdown_left := 0.0
var _flashed_stop_ids: Dictionary = {}


func _ready() -> void:
	_stage = get_parent() as DancerSimonSaysStage
	_controller = get_node(controller_path) as FlashPoseRoundController
	_build_ui()
	_setup_characters()
	_setup_audio()
	_controller.phase_changed.connect(_on_phase_changed)
	_controller.semantic_animation_updated.connect(_on_semantic_animation_updated)
	_controller.genuine_stop_started.connect(_on_genuine_stop_started)
	_controller.pose_evaluation_resolved.connect(_on_pose_evaluation_resolved)
	_controller.flash_requested.connect(_on_flash_requested)
	_controller.flash_completed.connect(_on_flash_completed)
	_controller.round_results_ready.connect(_on_round_results_ready)
	set_process(false)


func _exit_tree() -> void:
	if _music != null:
		_music.stop()
	if _flash_sfx != null:
		_flash_sfx.stop()


func _process(delta: float) -> void:
	_countdown_left = maxf(_countdown_left - delta, 0.0)
	_countdown_label.text = str(maxi(1, ceili(_countdown_left)))
	if is_zero_approx(_countdown_left):
		set_process(false)


func _build_ui() -> void:
	var safe_area := MarginContainer.new()
	safe_area.name = "SafeArea"
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 28)
	safe_area.add_theme_constant_override("margin_top", 76)
	safe_area.add_theme_constant_override("margin_right", 28)
	safe_area.add_theme_constant_override("margin_bottom", 24)
	_stage.add_child.call_deferred(safe_area)

	_countdown_label = Label.new()
	_countdown_label.name = "Countdown"
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.position = Vector2(-90, -110)
	_countdown_label.size = Vector2(180, 140)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 96)
	_countdown_label.add_theme_color_override("font_color", Color("fff3a6"))
	_countdown_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.1, 0.2, 0.9))
	_countdown_label.add_theme_constant_override("shadow_offset_x", 4)
	_countdown_label.add_theme_constant_override("shadow_offset_y", 4)
	_countdown_label.visible = false
	_stage.add_child.call_deferred(_countdown_label)

	_cue_panel = PanelContainer.new()
	_cue_panel.name = "DirectionCue"
	_cue_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cue_panel.position = Vector2(-135, 76)
	_cue_panel.size = Vector2(270, 64)
	var cue_style := StyleBoxFlat.new()
	cue_style.bg_color = Color(0.06, 0.09, 0.17, 0.88)
	cue_style.corner_radius_top_left = 18
	cue_style.corner_radius_top_right = 18
	cue_style.corner_radius_bottom_left = 18
	cue_style.corner_radius_bottom_right = 18
	_cue_panel.add_theme_stylebox_override("panel", cue_style)
	_cue_label = Label.new()
	_cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cue_label.add_theme_font_size_override("font_size", 30)
	_cue_label.add_theme_color_override("font_color", Color.WHITE)
	_cue_panel.add_child(_cue_label)
	_cue_panel.visible = false
	_stage.add_child.call_deferred(_cue_panel)

	_feedback_label = Label.new()
	_feedback_label.name = "StopFeedback"
	_feedback_label.set_anchors_preset(Control.PRESET_CENTER)
	_feedback_label.position = Vector2(-240, 42)
	_feedback_label.size = Vector2(480, 58)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 28)
	_feedback_label.add_theme_color_override("font_color", Color("fff3a6"))
	_feedback_label.visible = false
	_stage.add_child.call_deferred(_feedback_label)

	_build_results_view()
	_flash_overlay = ColorRect.new()
	_flash_overlay.name = "CameraFlash"
	_flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.color = Color(1, 1, 0.92, 0)
	_flash_overlay.z_index = 90
	_stage.add_child.call_deferred(_flash_overlay)


func _build_results_view() -> void:
	_results = Control.new()
	_results.name = "ResultsView"
	_results.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_results.z_index = 50
	_results.visible = false
	_stage.add_child.call_deferred(_results)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.035, 0.05, 0.1, 0.94)
	_results.add_child(backdrop)
	var title := _result_label("FLASH? POSE! RESULTS", 38)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-320, 22)
	title.size = Vector2(640, 54)
	_results.add_child(title)
	# Each panel previously occupied 36% of the viewport height. The 28.8%
	# spans below are exactly 80% of that footprint and leave a distinct action
	# area for the larger return button.
	_winner_panel = _result_panel("WinnerPanel", Color("276749"), 0.12, 0.408)
	_loser_panel = _result_panel("LoserPanel", Color("3f3c67"), 0.462, 0.75)
	_results.add_child(_winner_panel)
	_results.add_child(_loser_panel)
	_happy_names = _result_label("", 28)
	_moody_names = _result_label("", 28)
	_winner_panel.add_child(_section("WINNERS", _happy_names))
	_loser_panel.add_child(_section("LOSERS", _moody_names))
	_return_button = Button.new()
	_return_button.name = "ReturnToLobby"
	_return_button.text = "Return to lobby"
	_return_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_return_button.position = Vector2(-160, -92)
	_return_button.size = Vector2(320, 64)
	_return_button.add_theme_font_size_override("font_size", 24)
	_return_button.add_theme_color_override("font_color", Color("172033"))
	_return_button.add_theme_color_override("font_hover_color", Color("101827"))
	_return_button.add_theme_color_override("font_pressed_color", Color("101827"))
	_return_button.add_theme_color_override("font_disabled_color", Color("536078"))
	_return_button.add_theme_stylebox_override("normal", _return_button_style(Color("f6c453"), Color("fff0b8")))
	_return_button.add_theme_stylebox_override("hover", _return_button_style(Color("ffd86b"), Color.WHITE))
	_return_button.add_theme_stylebox_override("pressed", _return_button_style(Color("dfa832"), Color("fff0b8")))
	_return_button.add_theme_stylebox_override("disabled", _return_button_style(Color("9b8b62"), Color("c6b98f")))
	_return_button.add_theme_stylebox_override("focus", _return_button_style(Color.TRANSPARENT, Color.WHITE, 4))
	_return_button.pressed.connect(func() -> void:
		_return_button.disabled = _controller.request_return_to_lobby())
	_results.add_child(_return_button)


func _result_panel(panel_name: String, color: Color, top: float, bottom: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = top
	panel.anchor_bottom = bottom
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = color.lightened(0.28)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _return_button_style(background: Color, border: Color, border_width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(14)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _section(title_text: String, names: Label) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	var heading := _result_label(title_text, 30)
	heading.name = "%sHeading" % title_text.to_pascal_case()
	column.add_child(heading)
	column.add_child(names)
	return column


func _result_label(text_value: String, size_value: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _setup_characters() -> void:
	var lead_character := _stage.lead_slot().get_node(^"PreviewCharacter") as ShapeCharacter
	_lead_animator = Animator.new()
	lead_character.add_child(_lead_animator)
	_lead_animator.setup(lead_character, true)
	_lead_animator.apply_tuning(tuning)
	var slots := _stage.player_slots()
	for index: int in slots.size():
		var character := slots[index].get_node(^"PreviewCharacter") as ShapeCharacter
		character.player_color = SEAT_COLORS[index]
		var animator := Animator.new()
		character.add_child(animator)
		animator.setup(character, false, index, slots.size())
		animator.apply_tuning(tuning)
		_seat_animators[index + 1] = animator
		var status := Label.new()
		status.name = "PlayerStatus"
		status.position = Vector2(-70, 72)
		status.size = Vector2(140, 50)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.add_theme_font_size_override("font_size", 17)
		status.add_theme_color_override("font_color", Color("101827"))
		status.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.9))
		status.add_theme_constant_override("shadow_offset_x", 1)
		status.add_theme_constant_override("shadow_offset_y", 1)
		slots[index].add_child(status)
		_player_labels[index + 1] = status
		slots[index].visible = false


func _setup_audio() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.volume_db = tuning.music_gain_db
	add_child(_music)
	_flash_sfx = AudioStreamPlayer.new()
	_flash_sfx.name = "FlashSfx"
	_flash_sfx.volume_db = tuning.flash_sfx_gain_db
	add_child(_flash_sfx)


func _on_phase_changed(phase: StringName, snapshot: Dictionary) -> void:
	match phase:
		&"countdown":
			_populate_players(_controller.player_snapshot())
			_set_style(StringName(snapshot.get("style", &"bounce")))
			_countdown_left = tuning.countdown_seconds
			_countdown_label.visible = true
			_countdown_label.text = str(maxi(1, ceili(_countdown_left)))
			set_process(_countdown_left > 0.0)
		&"dance":
			_countdown_label.visible = false
			_cue_panel.visible = false
			_feedback_label.visible = false
			_set_dance_active(true)
			if _music.stream != null and not _music.playing:
				_music.play()
		&"genuine_stop_grace":
			_set_dance_active(false)


func _populate_players(players: Array[Dictionary]) -> void:
	var slots := _stage.player_slots()
	_player_animators.clear()
	for slot: Control in slots:
		slot.visible = false
	for player: Dictionary in players:
		var seat := clampi(int(player.get("seat", 1)), 1, slots.size())
		var slot := slots[seat - 1] as Control
		slot.visible = true
		var character := slot.get_node(^"PreviewCharacter") as ShapeCharacter
		character.apply_selection(CharacterSelection.for_player(player))
		var animator := _seat_animators[seat] as HybridCharacterAnimator
		_player_animators[String(player.player_id)] = animator
		_update_player_status(player)


func _set_style(style: StringName) -> void:
	_lead_animator.set_dance_style(style)
	for animator: HybridCharacterAnimator in _player_animators.values():
		animator.set_dance_style(style)
	_music.stop()
	_music.stream_paused = false
	_music.stream = AudioCatalog.MUSIC_BY_STYLE.get(style)


func _on_semantic_animation_updated(player_id: String, state: Dictionary) -> void:
	var animator := _player_animators.get(player_id) as HybridCharacterAnimator
	if animator == null:
		return
	animator.set_pose_state(StringName(state.get("pose_direction", &"")), float(state.get("pose_charge", 0.0)), bool(state.get("pose_held", false)))


func _on_genuine_stop_started(_stop_id: int, direction: StringName, _available: Array[StringName]) -> void:
	_music.stream_paused = true
	_set_dance_active(false)
	_lead_animator.set_pose_state(direction, 1.0, true)
	_cue_label.text = DIRECTION_GLYPHS.get(direction, String(direction).to_upper())
	_cue_panel.visible = true
	_feedback_label.text = "HOLD THE MATCHING POSE"
	_feedback_label.visible = true


func _on_pose_evaluation_resolved(_stop_id: int, results: Array[Dictionary]) -> void:
	_feedback_label.text = "POSE CAPTURED!"
	for result: Dictionary in results:
		var player_id := String(result.player_id)
		var animator := _player_animators.get(player_id) as HybridCharacterAnimator
		if animator == null:
			continue
		animator.set_eliminated(bool(result.get("eliminated", false)))
		if not bool(result.get("eliminated", false)):
			animator.play_reaction(&"survived" if bool(result.get("success", false)) else &"life_loss")
	for player: Dictionary in _controller.player_snapshot():
		_update_player_status(player)


func _on_flash_requested(stop_id: int, _results: Array[Dictionary]) -> void:
	if _flashed_stop_ids.has(stop_id):
		return
	_flashed_stop_ids[stop_id] = true
	_flash_sfx.stream = AudioCatalog.FLASH_CANDIDATES[posmod(stop_id - 1, AudioCatalog.FLASH_CANDIDATES.size())]
	_flash_sfx.play()
	_flash_overlay.color = Color(1, 1, 0.92, tuning.flash_intensity)
	var tween := create_tween()
	tween.tween_property(_flash_overlay, "color:a", 0.0, tuning.flash_duration_seconds)
	await tween.finished
	_controller.acknowledge_flash(stop_id, maxi(Time.get_ticks_msec(), _controller.last_host_time_msec()))


func _on_flash_completed(_stop_id: int) -> void:
	_lead_animator.set_pose_state(&"", 0.0, false)
	if tuning.music_resume_fade_seconds > 0.0:
		var target_db := tuning.music_gain_db
		_music.volume_db = -40.0
		_music.stream_paused = false
		create_tween().tween_property(_music, "volume_db", target_db, tuning.music_resume_fade_seconds)
	else:
		_music.volume_db = tuning.music_gain_db
		_music.stream_paused = false


func _on_round_results_ready(snapshot: Dictionary) -> void:
	_music.stop()
	_cue_panel.visible = false
	_feedback_label.visible = false
	_countdown_label.visible = false
	var ranking: Array = snapshot.get("ranking", [])
	var top_count := int(snapshot.get("top_group_size", 0))
	var happy: PackedStringArray = []
	var moody: PackedStringArray = []
	for index: int in ranking.size():
		var player: Dictionary = ranking[index]
		var player_name := String(player.get("name", player.get("player_id", "Player")))
		if index < top_count:
			happy.append(player_name)
		else:
			moody.append(player_name)
		var animator := _player_animators.get(String(player.player_id)) as HybridCharacterAnimator
		if animator != null:
			animator.set_eliminated(false)
			animator.set_result_mood(&"happy" if index < top_count else &"moody")
	_happy_names.text = "   ".join(happy)
	_moody_names.text = "   ".join(moody)
	_results.visible = true


func _set_dance_active(active: bool) -> void:
	_lead_animator.set_dance_active(active)
	for animator: HybridCharacterAnimator in _player_animators.values():
		animator.set_dance_active(active)


func _update_player_status(player: Dictionary) -> void:
	var seat := int(player.get("seat", 0))
	var label := _player_labels.get(seat) as Label
	if label == null:
		return
	var lives := maxi(0, int(player.get("lives", 0)))
	var hearts := "♥".repeat(lives) + "♡".repeat(maxi(0, 2 - lives))
	var suffix := "  OUT" if StringName(player.get("state", &"active")) == &"eliminated" else ""
	label.text = "%s\n%s%s" % [String(player.get("name", "Player")), hearts, suffix]
