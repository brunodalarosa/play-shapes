class_name TiltShiftSession
extends Node
## Persistent coordination across preparation and gameplay; existing consumers own all rules.

const ID := &"tilt_shift"
var motion: TiltShiftMotionController
var profile: TiltShiftTuning
var protocol: TiltShiftProtocol
var generation := ""
var last_process_usec := 0
var clock: Callable = Time.get_ticks_msec
var _host: Node
var _presentation: TiltShiftPresentation
var _stage := &"idle"
var _generations: Dictionary[String, String] = { }
var _dirty: Dictionary[String, bool] = { }
var _sent_at := -1000
var _next_round_at := -1


func _ready() -> void:
	motion = TiltShiftMotionController.new()
	add_child(motion)
	motion.state_changed.connect(_on_motion_state)


func prepare(host: Node, selected: TiltShiftTuning) -> bool:
	stop()
	_host = host
	if selected == null or not selected.validation_errors().is_empty():
		return false
	profile = selected.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	generation = Crypto.new().generate_random_bytes(12).hex_encode()
	_stage = &"preparing"
	if not motion.prepare(host.websocket, _ids(host.players()), profile.motion):
		stop()
		return false
	sync_players(host.players())
	return true


func ready_for(player_id: String) -> bool:
	if _stage != &"preparing" or not motion.ready_for(player_id):
		return false
	for player: Dictionary in _host.players():
		if String(player.player_id) == player_id:
			var channel: MotionInputChannel = _host.websocket.motion_channels.get(player_id)
			return (
				player.state == "connected" and channel != null
				and _generations.get(player_id, "") == channel.subscription_id
			)
	return false


func launch_eligible() -> bool:
	var players: Array[Dictionary] = _host.players()
	if players.size() not in [2, 4, 6, 8, 10]:
		return false
	for player: Dictionary in players:
		if not ready_for(String(player.player_id)):
			return false
	return true


func preparation_for(player_id: String) -> Dictionary:
	var state := motion.player_state(player_id)
	state.generation = generation
	state.paddle_size = [profile.physics.paddle_length, profile.physics.paddle_thickness]
	state.angle_radians = 0.0
	if motion.inputs.has(player_id):
		state.angle_radians = motion.inputs[player_id].angle_radians
	return state


func sync_players(players: Array[Dictionary]) -> void:
	if _stage == &"preparing":
		motion.sync_roster(_ids(players))
		for player_id: String in motion.inputs:
			var channel: MotionInputChannel = _host.websocket.motion_channels[player_id]
			var current := channel.subscription_id
			if _generations.has(player_id) and _generations[player_id] != current:
				motion.reset_preparation(player_id)
			_generations[player_id] = current
	elif _stage == &"playing" and is_instance_valid(_presentation):
		var connected: Dictionary = { }
		for player: Dictionary in players:
			connected[String(player.player_id)] = player.state == "connected"
		for player_id: String in motion.inputs:
			_presentation.arena.controller.set_connected(player_id, connected.get(player_id, false))


func attach(presentation: TiltShiftPresentation, participants: Array) -> bool:
	if _stage != &"preparing" or not launch_eligible():
		return false
	var players: Array[TiltShiftState.Player] = []
	for record: Dictionary in participants:
		var player := TiltShiftState.Player.new()
		player.player_id = String(record.player_id)
		player.player_name = String(record.name)
		player.seat = int(record.seat)
		player.character_color = String(record.character_color)
		player.connected = record.state == "connected"
		players.append(player)
	if not presentation.start_shift(profile, players).accepted:
		return false
	if not motion.activate(presentation.arena):
		presentation.stop()
		return false
	_presentation = presentation
	_stage = &"playing"
	protocol = TiltShiftProtocol.new(generation)
	var controller := presentation.arena.controller
	controller.round_started.connect(_on_round_started)
	controller.round_ended.connect(_on_round_ended)
	controller.shift_finished.connect(_on_finished)
	controller.angle_changed.connect(_on_player)
	controller.presence_changed.connect(_on_player)
	protocol.apply_snapshot(controller.snapshot())
	_host.websocket.set_tilt_shift_protocol(protocol)
	return true


func _on_player(player: TiltShiftState.Player) -> void:
	protocol.apply_player(player)
	_dirty[player.player_id] = true


func _on_round_started(state: TiltShiftState.Snapshot) -> void:
	_next_round_at = -1
	protocol.apply_snapshot(state)
	_publish_all()


func _on_round_ended(state: TiltShiftState.Snapshot) -> void:
	protocol.apply_snapshot(state)
	if state.phase == &"between_rounds":
		_next_round_at = clock.call() + roundi(profile.flow.intermission_seconds * 1000.0)
	_publish_all()


func _on_finished(state: TiltShiftState.Snapshot) -> void:
	_stage = &"results"
	_next_round_at = -1
	protocol.apply_snapshot(state)
	_publish_all()


func _on_motion_state(player_id: String, _state: Dictionary) -> void:
	if _stage == &"preparing":
		_dirty[player_id] = true
		if _host.readiness != null:
			_host.readiness.refresh()


func _process(_delta: float) -> void:
	poll()


func poll() -> void:
	var began := Time.get_ticks_usec()
	if _stage == &"idle":
		return
	var now: int = clock.call()
	if _stage == &"preparing":
		sync_players(_host.players())
		if _host.readiness != null:
			_host.readiness.refresh()
		for player_id: String in motion.inputs:
			_dirty[player_id] = true
	if _next_round_at >= 0 and now >= _next_round_at:
		_next_round_at = -1
		if not _presentation.start_next_round().accepted:
			stop()
	if profile != null and now - _sent_at >= ceili(1000.0 / profile.flow.phone_updates_hz):
		_sent_at = now
		for player_id: String in _dirty:
			_host.websocket.send_current_snapshot(player_id)
		_dirty.clear()
	last_process_usec = Time.get_ticks_usec() - began


func _publish_all() -> void:
	for player_id: String in protocol.player_ids():
		_host.websocket.send_current_snapshot(player_id, false)


func stop() -> void:
	_stage = &"idle"
	_next_round_at = -1
	if _host != null and protocol != null:
		_host.websocket.clear_tilt_shift_protocol(protocol)
	if is_instance_valid(_presentation):
		_presentation.stop()
	_presentation = null
	if is_instance_valid(motion):
		motion.stop()
	protocol = null
	profile = null
	_generations.clear()
	_dirty.clear()
	generation = ""
	_host = null


func _exit_tree() -> void:
	stop()


static func _ids(players: Array[Dictionary]) -> PackedStringArray:
	var result := PackedStringArray()
	for player: Dictionary in players:
		result.append(String(player.player_id))
	return result
