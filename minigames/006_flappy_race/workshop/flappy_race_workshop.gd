class_name FlappyRaceWorkshop
extends Control
## The Flappy Race workshop: the real race, presentation, protocol and phone page in the shared
## workshop window, with autopilot racers, the designer flying through the phone view, seeds,
## quick setups, a course strip, camera choices and readouts.
##
## Run it on its own (F6) or from F12. Each restart builds a fresh race from the running preset,
## as a new game would, and every phone gets a new snapshot.

enum Camera {
	LEADER,
	YOU,
	FREE,
}

const ID := "flappy_race"
const TUNING_FOLDER := "res://minigames/006_flappy_race/tuning"
const PRESENTATION_SCENE := preload("res://minigames/006_flappy_race/flappy_race_presentation.tscn")
const DESIGNER_CONNECTION := -1000
const DESIGNER_NAME := "You"
const MAX_AUTOPILOTS := 9
## Ticks between autopilots starting to fly, so they spread out instead of flying as one.
const AUTOPILOT_DELAY_TICKS := 9
const SETUPS: Array[String] = [
	"Start crowd",
	"Spread pack",
	"One far behind",
	"Leader near finish",
	"Out of hearts",
]
## Obstacles between racers in Spread pack.
const SPREAD_OBSTACLES := 4
## Obstacles the pack leads by in One far behind.
const FAR_BEHIND_OBSTACLES := 20
## Obstacles before the last one where Leader near finish puts the leader.
const NEAR_FINISH_OBSTACLES := 3

@export var boot_request: BootRequest = preload("res://workshop/workshop_boot_request.tres")

var window := WorkshopWindow.new()
var phone := WorkshopPhoneView.new()
var controller: FlappyRaceController
var protocol: FlappyRaceProtocol
var presentation: FlappyRacePresentation
var autopilots: Array[FlappyRaceAutopilot] = []
var seed_value := 1
var designer: Dictionary = { }
var camera_mode := Camera.LEADER
var _host: Node
var _viewport := SubViewport.new()
var _readouts := Label.new()
var _readouts_card := PanelContainer.new()
var _outline := Control.new()
var _strip := FlappyRaceCourseStrip.new()
var _status := Label.new()
var _seed_field := SpinBox.new()
var _seed_lock := Button.new()
var _you_racing := Button.new()
var _autopilot_count := SpinBox.new()
var _skill := OptionButton.new()
var _camera_chips := ButtonGroup.new()
var _outline_toggle := Button.new()
var _free_point := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	# Dialogs and menus open as their own windows, above the phone view's native page.
	get_tree().root.gui_embed_subwindows = false
	add_child(window)
	window.title = "Flappy Race workshop"
	window.setup(ID, WorkshopPresets.new(TUNING_FOLDER), ID)
	window.restart_requested.connect(restart)
	window.key_pressed.connect(_on_key)
	window.tuning.live_changed.connect(_on_live_changed)
	_build_shared_screen()
	_build_phone_view()
	_build_flow()
	seed_value = randi()
	_seed_field.set_value_no_signal(seed_value)
	_autopilot_count.set_value_no_signal(3)
	_start.call_deferred()


## Restarts the race with the running preset. [param setup] names a quick setup;
## [param pack_at] puts the whole pack at that obstacle instead.
func restart(setup := "", pack_at := -1) -> void:
	var course_edited := window.tuning.pending().any(
		func(tunable: WorkshopTunable) -> bool:
			return tunable.part == "course",
	)
	if course_edited and not _seed_lock.button_pressed:
		new_seed()
	var running := window.tuning.restart() as FlappyRaceTuning
	_stop_race()

	controller = FlappyRaceController.new()
	controller.name = "Race"
	add_child(controller)
	# The controller picks the game's preset when it enters the tree; the workshop's wins.
	controller.tuning = running
	var participants := _participants()
	var result := controller.start_race(participants, seed_value, Time.get_ticks_msec())
	if not result.accepted:
		_status.text = "The race did not start: %s" % result.get("code", "")
		return
	_place(participants, setup, pack_at)

	protocol = FlappyRaceProtocol.new(controller)
	for autopilot: FlappyRaceAutopilot in autopilots:
		autopilot.join(controller, protocol)
	if _host != null:
		_host.register_minigame_protocol(protocol)
	presentation = PRESENTATION_SCENE.instantiate()
	_viewport.add_child(presentation)
	presentation.bind(controller)
	_apply_camera()
	_strip.race = controller
	_status.text = "Seed %d%s" % [seed_value, "" if setup.is_empty() else " · " + setup]


func new_seed() -> void:
	seed_value = randi()
	_seed_field.set_value_no_signal(seed_value)


func _start() -> void:
	_host = get_node_or_null("/root/SessionHost")
	if _host != null:
		# F6 boots this scene once SessionHost is ready; from F12 the servers already run.
		await get_tree().process_frame
		if not _host.running:
			_host.boot_scene(self)
		_join_designer()
		_host.players_changed.connect(_on_players_changed)
	restart()


func _join_designer() -> void:
	var registry: PlayerRegistry = _host.player_registry
	var joined := registry.join_player(DESIGNER_CONNECTION, DESIGNER_NAME, true)
	if not joined.accepted:
		phone.readout.text = "Could not add the designer: %s" % joined.get("message", "")
		return
	designer = joined.player
	# The page takes this player over when it connects.
	registry.disconnect_connection(DESIGNER_CONNECTION)
	if not _host.running:
		phone.readout.text = "No servers for the phone view: %s" % _host.startup_error
		return
	var network: ControllerNetworkConfig = _host.network
	var url := "%s://127.0.0.1:%d/" % [network.http_scheme(), network.http_port]
	phone.open(url, registry.session_id, joined.reconnect_token)


func _participants() -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	if _you_racing.button_pressed and not designer.is_empty():
		players.append(designer)
	autopilots.clear()
	for index: int in int(_autopilot_count.value):
		var player := FlappyRaceAutopilot.make_player(index, players.size() + 1)
		players.append(player)
		autopilots.append(FlappyRaceAutopilot.new(player, index * AUTOPILOT_DELAY_TICKS))
	return players


## Where each racer starts in [param setup], or the whole pack at obstacle [param pack_at].
func _place(participants: Array[Dictionary], setup: String, pack_at: int) -> void:
	var count := controller.course.flight.obstacles.size()
	var hearts := controller.tuning.flight.heart_count
	var last := participants.size() - 1
	for index: int in participants.size():
		var player_id: String = participants[index].player_id
		var obstacle := -1
		var full := hearts
		if pack_at >= 0:
			obstacle = pack_at
		match setup:
			"Spread pack":
				obstacle = (last - index) * SPREAD_OBSTACLES
			"One far behind":
				var behind := index == (0 if _you_racing.button_pressed else last)
				obstacle = -1 if behind else FAR_BEHIND_OBSTACLES
			"Leader near finish":
				obstacle = count - NEAR_FINISH_OBSTACLES - index * SPREAD_OBSTACLES
			"Out of hearts":
				full = 0
		if obstacle >= 0 or full != hearts:
			controller.place_racer(player_id, clampi(obstacle, -1, count - 1), full)


func _stop_race() -> void:
	if protocol != null and _host != null:
		_host.unregister_minigame_protocol(protocol)
	protocol = null
	if presentation != null:
		presentation.queue_free()
		presentation = null
	if controller != null:
		controller.queue_free()
		controller = null
	_strip.race = null


func _build_shared_screen() -> void:
	var stage := Control.new()
	stage.clip_contents = true
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.gui_input.connect(_on_shared_screen_input)
	stage.add_child(container)
	_viewport.name = "SharedScreen"
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	container.add_child(_viewport)
	_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.draw.connect(_draw_phone_outline)
	stage.add_child(_outline)
	_readouts_card.theme_type_variation = &"Readouts"
	_readouts_card.position = Vector2(12, 12)
	_readouts_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_readouts_card)
	_readouts.theme_type_variation = &"ReadoutLabel"
	_readouts_card.add_child(_readouts)
	window.shared_screen.set_body(stage, false)

	var camera_label := Label.new()
	camera_label.text = "Camera"
	camera_label.theme_type_variation = &"HelpLabel"
	window.shared_screen.title_bar.add_child(camera_label)
	var tips := ["As in a real race", "Your Cubio", "Drag the shared screen"]
	for index: int in 3:
		var chip := _chip(window.shared_screen.title_bar, ["Leader", "You", "Free"][index])
		chip.button_group = _camera_chips
		chip.button_pressed = index == Camera.LEADER
		chip.tooltip_text = tips[index]
		chip.pressed.connect(
			func() -> void:
				camera_mode = index as Camera
				_apply_camera(),
		)
	_outline_toggle.theme_type_variation = &"ChipButton"
	_outline_toggle.toggle_mode = true
	_outline_toggle.text = "Phone outline"
	_outline_toggle.toggled.connect(
		func(_on: bool) -> void:
			_outline.queue_redraw(),
	)
	window.shared_screen.title_bar.add_child(_outline_toggle)


func _build_phone_view() -> void:
	window.phone_view.set_body(phone)
	window.phone_view.pop_out_blocked = (
		"The phone view stays docked: this godot-wry release draws pages in the main window only."
	)


func _build_flow() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	column.add_child(_label("Course"))

	var course_row := HBoxContainer.new()
	column.add_child(course_row)
	var restart_button := _add_button(
		course_row,
		"Restart · R",
		restart.bind("", -1),
		"Same seed, running preset",
	)
	restart_button.theme_type_variation = &"FilledButton"
	_add_button(course_row, "New course", _on_new_course, "A new seed")
	course_row.add_child(_body_label("Seed"))
	_seed_field.max_value = 4294967295
	_seed_field.custom_minimum_size = Vector2(150, 0)
	_seed_field.get_line_edit().theme_type_variation = &"NumberEdit"
	_seed_field.value_changed.connect(
		func(value: float) -> void:
			seed_value = int(value),
	)
	course_row.add_child(_seed_field)
	_seed_lock.text = "Lock seed"
	_seed_lock.theme_type_variation = &"ChipButton"
	_seed_lock.toggle_mode = true
	_seed_lock.tooltip_text = "Keep the seed when Course values change"
	course_row.add_child(_seed_lock)

	column.add_child(_label("Racers"))
	var racers_row := HBoxContainer.new()
	column.add_child(racers_row)
	_you_racing.text = "You race"
	_you_racing.theme_type_variation = &"ChipButton"
	_you_racing.toggle_mode = true
	_you_racing.button_pressed = true
	_you_racing.tooltip_text = "Fly in the phone view: click or Space"
	racers_row.add_child(_you_racing)
	racers_row.add_child(_body_label("Autopilots"))
	_autopilot_count.max_value = MAX_AUTOPILOTS
	_autopilot_count.get_line_edit().theme_type_variation = &"NumberEdit"
	racers_row.add_child(_autopilot_count)
	racers_row.add_child(_body_label("Skill"))
	_skill.add_item("Good")
	racers_row.add_child(_skill)
	_add_button(racers_row, "Apply", restart.bind("", -1), "Restart with these racers")

	column.add_child(_label("Quick setups"))
	var setups := HFlowContainer.new()
	column.add_child(setups)
	for setup: String in SETUPS:
		_add_button(setups, setup, restart.bind(setup, -1), "Restart into %s" % setup.to_lower())

	column.add_child(_label("Course strip · click to put the pack there"))
	_strip.custom_minimum_size = Vector2(0, 46)
	_strip.picked.connect(
		func(obstacle: int) -> void:
			restart("", obstacle),
	)
	column.add_child(_strip)
	_status.theme_type_variation = &"HelpLabel"
	column.add_child(_status)
	window.flow.set_body(column)


func _process(_delta: float) -> void:
	if controller == null or presentation == null:
		return
	if camera_mode == Camera.FREE:
		presentation.camera.frame_race(_free_point, PackedVector2Array(), 0.0)
	_readouts.text = _readout_text()
	_strip.queue_redraw()
	if _outline_toggle.button_pressed:
		_outline.queue_redraw()
	_update_coverage()


func _readout_text() -> String:
	if not _readouts_card.visible:
		return ""
	var ranking := FlappyRaceController.rank(controller.racers())
	var length := controller.course.length
	var leader := ranking[0].distance() if not ranking.is_empty() else 0.0
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var lines := PackedStringArray(
		[
			"Seed %d · tick %d · leader %d%% · difficulty %.2f · host %.1f ms"
			% [
				seed_value,
				controller.settled_tick,
				roundi(leader / length * 100.0),
				clampf(leader / length, 0.0, 1.0),
				frame_ms,
			],
		]
	)
	for index: int in ranking.size():
		var racer := ranking[index]
		var hearts := racer.state.hearts
		lines.append(
			"%d  %s  %d%%  %s%s  %s"
			% [
				index + 1,
				racer.display_name,
				roundi(racer.distance() / length * 100.0),
				"♥".repeat(hearts.full),
				"♡".repeat(hearts.count - hearts.full),
				_state_name(racer),
			]
		)
	return "\n".join(lines)


func _state_name(racer: FlappyRaceRacer) -> String:
	if racer.finished():
		return "finished"
	if racer.dnf:
		return "gone"
	if not racer.connected:
		return "frozen"
	if not racer.state.flying:
		return "ready" if racer.state.ready else "waiting"
	return "flying"


func _apply_camera() -> void:
	if presentation == null:
		return
	presentation.frames_camera = camera_mode != Camera.FREE
	presentation.followed_id = (designer.get("player_id", "") if camera_mode == Camera.YOU else "")
	if camera_mode == Camera.FREE:
		_free_point = Vector2(presentation.camera.leader_x, controller.course.view_height * 0.5)


## How much course the phone and the shared screen each show, in metres.
func _update_coverage() -> void:
	var device := phone.device_size()
	var phone_width := controller.course.view_height * device.x / device.y
	var shared := presentation.camera.visible_rect().size.x
	var lines := PackedStringArray(
		[
			"HOW MUCH COURSE IS VISIBLE",
			"Phone   %3d m wide" % phone_width,
			"Shared  %3d m wide" % shared,
		]
	)
	phone.readout.text = "\n".join(lines)


## The part of the course the designer's phone shows, outlined on the shared screen.
func _draw_phone_outline() -> void:
	if not _outline_toggle.button_pressed or presentation == null or designer.is_empty():
		return
	var visual := presentation.visual_for(designer.player_id)
	if visual == null:
		return
	var device := phone.device_size()
	var height := controller.course.view_height
	var width := height * device.x / device.y
	var left := visual.drawn.x - controller.tuning.view.phone_cubio_screen_share * width
	var camera := presentation.camera
	var scale := _outline.size / Vector2(_viewport.size)
	var top_left := camera.unproject_position(Vector3(left, height, 0.0)) * scale
	var bottom_right := camera.unproject_position(Vector3(left + width, 0.0, 0.0)) * scale
	_outline.draw_rect(Rect2(top_left, bottom_right - top_left), Color(1, 1, 1, 0.8), false, 2.0)


func _on_shared_screen_input(event: InputEvent) -> void:
	if camera_mode != Camera.FREE or presentation == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var metres := presentation.camera.visible_height / maxf(_viewport.size.y, 1.0)
		_free_point.x -= event.relative.x * metres


func _on_new_course() -> void:
	new_seed()
	restart()


func _on_live_changed(_tunable: WorkshopTunable) -> void:
	if presentation != null:
		presentation.apply_view_tuning()


func _on_players_changed(players: Array[Dictionary]) -> void:
	if controller == null:
		return
	var roster: Array = players.duplicate()
	for autopilot: FlappyRaceAutopilot in autopilots:
		roster.append(autopilot.player)
	controller.observe_registry(roster, Time.get_ticks_msec())


func _on_key(event: InputEventKey) -> void:
	if event.keycode == KEY_TAB:
		_readouts_card.visible = not _readouts_card.visible
		get_viewport().set_input_as_handled()


func _add_button(parent: Control, text: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## A section's name in the flow panel.
func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.uppercase = true
	label.theme_type_variation = &"SectionLabel"
	return label


func _body_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"BodyLabel"
	return label


## A filter chip that stays selected.
func _chip(parent: Control, text: String) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.theme_type_variation = &"ChipButton"
	chip.toggle_mode = true
	parent.add_child(chip)
	return chip


func _exit_tree() -> void:
	_stop_race()
	if _host != null and _host.players_changed.is_connected(_on_players_changed):
		_host.players_changed.disconnect(_on_players_changed)
