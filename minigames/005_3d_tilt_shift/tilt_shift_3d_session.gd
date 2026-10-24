class_name TiltShift3DSession
extends Node
## Persistent coordination of Tilt Shift 3D across the Pre-minigame screen and play: motion
## preparation, the launch gate, the phones' protocol and its traffic. The rules, physics and
## presentation own everything else. SessionHost creates it from the catalog entry.

const ID := &"tilt_shift_3d"
var motion: TiltShift3DMotionController
var profile: TiltShift3DTuning
var protocol: TiltShift3DProtocol
var generation := ""
var last_process_usec := 0
var clock: Callable = Time.get_ticks_msec
var _host: Node
var _presentation: TiltShift3DPresentation
var _stage := &"idle"
var _generations: Dictionary[String, String] = { }
var _dirty: Dictionary[String, bool] = { }
var _sent_at := -1000
var _next_round_at := -1


func _ready() -> void:
	motion = TiltShift3DMotionController.new()
	add_child(motion)
	motion.state_changed.connect(_on_motion_state)


## Starts preparation for the Pre-minigame screen with the host's active preset.
func prepare(host: Node) -> bool:
	return prepare_with(host, host.active_presets.tilt_shift_3d)


func prepare_with(host: Node, selected: TiltShift3DTuning) -> bool:
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
	if _stage != &"preparing":
		return false
	var players: Array[Dictionary] = _host.players()
	if players.size() not in [2, 4, 6, 8, 10]:
		return false
	if not profile.layouts_by_round.is_empty():
		return true
	for player: Dictionary in players:
		if not ready_for(String(player.player_id)):
			return false
	return true


## What the Pre-minigame screen tells [param player_id]'s phone: their calibration and their
## paddle, before teams exist.
func preparation_for(player_id: String) -> Dictionary:
	var state := motion.player_state(player_id)
	state.generation = generation
	var layout := profile.layout_for(0)
	var size := layout.paddle_size(TiltShift3DTypes.Team.ORANGE, profile.physics)
	state.paddle_size = [size.x, size.y]
	state.angle_radians = 0.0
	if motion.inputs.has(player_id):
		state.angle_radians = motion.inputs[player_id].angle_radians
	state.color = "ffffff"
	for player: Dictionary in _host.players():
		if String(player.player_id) == player_id:
			var colour := String(player.get("character_color", ""))
			state.color = TiltShift3DPresentation.player_color(colour).to_html(false)
	state.face = profile.expressions.play_face
	state.look = TiltShift3DProtocol.look_of(profile)
	return state


func sync_players(players: Array[Dictionary]) -> void:
	if _stage == &"preparing":
		motion.sync_roster(_ids(players))
		for player_id: String in motion.inputs:
			var channel: MotionInputChannel = _host.websocket.motion_channels[player_id]
			var current := channel.subscription_id
			if profile.layouts_by_round.is_empty() and _generations.has(player_id) \
					and _generations[player_id] != current:
				motion.reset_preparation(player_id)
			_generations[player_id] = current
	elif _stage == &"playing" and is_instance_valid(_presentation):
		var connected: Dictionary = { }
		for player: Dictionary in players:
			connected[String(player.player_id)] = player.state == "connected"
		for player_id: String in motion.inputs:
			_presentation.arena.controller.set_connected(player_id, connected.get(player_id, false))


func attach(presentation: TiltShift3DPresentation, participants: Array) -> bool:
	if _stage != &"preparing" or not launch_eligible():
		return false
	var players: Array[TiltShift3DState.Player] = []
	for record: Dictionary in participants:
		var player := TiltShift3DState.Player.new()
		player.player_id = String(record.player_id)
		player.player_name = String(record.name)
		player.seat = int(record.seat)
		player.character_color = String(record.character_color)
		player.connected = record.state == "connected"
		players.append(player)
	if not presentation.start_shift(profile, players, true).accepted:
		return false
	if not motion.activate(presentation.arena):
		presentation.stop()
		return false
	_presentation = presentation
	_stage = &"playing"
	protocol = TiltShift3DProtocol.new(generation)
	protocol.ready_action = _accept_ready
	protocol.calibration_context = _calibration_allowed
	protocol.set_look(profile)
	var controller := presentation.arena.controller
	controller.round_prepared.connect(_on_round_started)
	controller.phase_changed.connect(_on_round_started)
	controller.readiness_changed.connect(_on_round_started)
	controller.round_started.connect(_on_round_started)
	controller.round_ended.connect(_on_round_ended)
	controller.shift_finished.connect(_on_finished)
	controller.angle_changed.connect(_on_player)
	controller.presence_changed.connect(_on_player)
	presentation.player_face_changed.connect(_on_face)
	protocol.apply_snapshot(controller.snapshot())
	for player_id: String in motion.inputs:
		protocol.apply_motion(player_id, motion.player_state(player_id))
	_host.register_minigame_protocol(protocol)
	return true


func _on_player(player: TiltShift3DState.Player) -> void:
	if _stage != &"playing" or protocol == null:
		return
	protocol.apply_player(player)
	_dirty[player.player_id] = true


func _on_face(player_id: String, face: String) -> void:
	if (
		_stage in [&"playing", &"results"] and protocol != null
		and protocol.apply_face(player_id, face)
	):
		# The face goes out at once; a dropped send is covered by the next periodic snapshot.
		protocol.publish(player_id)
		_dirty[player_id] = true


func _on_round_started(state: TiltShift3DState.Snapshot) -> void:
	if _stage != &"playing" or protocol == null:
		return
	_next_round_at = -1
	protocol.apply_snapshot(state)
	_publish_all()


func _on_round_ended(state: TiltShift3DState.Snapshot) -> void:
	if _stage != &"playing" or protocol == null:
		return
	protocol.apply_snapshot(state)
	if state.phase == &"between_rounds":
		var pause := 0.0 if state.reworked else profile.flow.intermission_seconds
		_next_round_at = clock.call() + roundi(pause * 1000.0)
	_publish_all()


func _on_finished(state: TiltShift3DState.Snapshot) -> void:
	if _stage != &"playing" or protocol == null:
		return
	_stage = &"results"
	_next_round_at = -1
	protocol.apply_snapshot(state)
	_publish_all()


func _on_motion_state(player_id: String, state: Dictionary) -> void:
	if _stage == &"playing" and protocol != null:
		protocol.apply_motion(player_id, state)
		_dirty[player_id] = true
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
	if _stage == &"playing" and is_instance_valid(_presentation):
		_observe_angles()
	if _next_round_at >= 0 and now >= _next_round_at:
		_next_round_at = -1
		if not _presentation.start_next_round().accepted:
			stop()
	if profile != null and now - _sent_at >= ceili(1000.0 / profile.flow.phone_updates_hz):
		_sent_at = now
		if protocol != null:
			for player_id: String in _dirty:
				protocol.publish(player_id)
		elif _stage == &"preparing" and _host.readiness != null:
			for player_id: String in _dirty:
				_host.websocket.send_current_snapshot(player_id)
		_dirty.clear()
	last_process_usec = Time.get_ticks_usec() - began


## The phone turns its paddle with the physical angle, which trails the accepted one under the
## turning-speed limit.
func _observe_angles() -> void:
	var bodies: Dictionary[String, TiltShift3DPaddleBody] = { }
	for body: TiltShift3DPaddleBody in _presentation.arena.paddle_bodies():
		bodies[body.paddle_id] = body
	for player: TiltShift3DState.Player in _presentation.arena.controller.snapshot().players:
		if player.paddle_ids.is_empty() or not bodies.has(player.paddle_ids[0]):
			continue
		if protocol.apply_angle(player.player_id, bodies[player.paddle_ids[0]].applied_angle):
			_dirty[player.player_id] = true


func _publish_all() -> void:
	for player_id: String in protocol.player_ids():
		protocol.publish(player_id, false)


func stop() -> void:
	_stage = &"idle"
	_next_round_at = -1
	if _host != null and protocol != null:
		_host.unregister_minigame_protocol(protocol)
	if is_instance_valid(_presentation):
		if _presentation.player_face_changed.is_connected(_on_face):
			_presentation.player_face_changed.disconnect(_on_face)
		_presentation.stop()
	_presentation = null
	if is_instance_valid(motion):
		motion.stop()
	if protocol != null:
		protocol.detach()
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


func _accept_ready(player_id: String, value: bool, token: String, now: int) -> bool:
	if _stage != &"playing" or not is_instance_valid(_presentation):
		return false
	var controller := _presentation.arena.controller
	controller.set_motion_usable(player_id, motion.ready_for(player_id))
	return controller.set_ready(player_id, value, token, now).accepted


func _calibration_allowed(token: String) -> bool:
	if _stage != &"playing" or not is_instance_valid(_presentation):
		return false
	var state := _presentation.arena.controller.snapshot()
	return (
		state.round_token == token
		and state.phase in [&"preparing", &"countdown", &"start", &"between_rounds"]
	)


func force_start(token: String, launch_generation: String) -> bool:
	if (
		launch_generation != generation or _stage != &"playing"
		or not is_instance_valid(_presentation)
	):
		return false
	return _presentation.arena.controller.force_start(token, clock.call()).accepted
