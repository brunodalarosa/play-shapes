extends Node
## Persistent services survive scene changes. The boot steps in [BootSteps] start them: the
## Essential ones when the game launches, the Optional ones when an entry asks.

signal connection_count_changed(count: int)
signal players_changed(players: Array[Dictionary])
signal readiness_changed(snapshot: Dictionary)
signal readiness_launch_requested(minigame_id: StringName)
signal readiness_canceled

const MINIGAME_CATALOG_PATH := "res://minigames/catalog.tres"
const LOBBY_PATH := "res://scenes/lobby.tscn"

@export var active_presets: ActivePresets = preload("res://Tuning/Active Presets.tres")

## Loaded by the catalog step on first use.
var minigame_catalog: MinigameCatalog:
	get:
		_run_step(BootSteps.CATALOG)
		return _minigame_catalog
var settings: NetworkingTuning
var network: ControllerNetworkConfig
## False to start the servers without reading the local network file.
var use_local_network_config := true
var running: bool = false
var startup_error: String = ""
var http: HttpService
var websocket: WebsocketService
## Created by the registry step on first use.
var player_registry: PlayerRegistry:
	get:
		_run_step(BootSteps.REGISTRY)
		return _player_registry
var accepting_new_players: bool = false
## The boot steps that have run, in order.
var steps_run: Array[StringName] = []
var _pending_minigame_launch: Dictionary = { }
var readiness: PreMinigameReadiness
## Sessions of catalog minigames that prepare during the Pre-minigame screen, by minigame ID.
## Each is created on first use from its definition's session script.
var minigame_sessions: Dictionary[StringName, Node] = { }
var _minigame_catalog: MinigameCatalog
var _player_registry: PlayerRegistry
var _tls_options: TLSOptions


func _ready() -> void:
	for step: StringName in BootSteps.ESSENTIAL:
		_run_step(step)
	http = HttpService.new()
	websocket = WebsocketService.new()
	add_child(http)
	add_child(websocket)
	websocket.connection_count_changed.connect(connection_count_changed.emit)
	_boot_launched_scene.call_deferred()


func _process(_delta: float) -> void:
	if _player_registry != null:
		_player_registry.expire_players()


## Runs the Essential steps, the steps [param request] lists and the steps those need. On a
## failure it stops, keeps the reason in [member startup_error] and returns false.
func boot(request: BootRequest) -> bool:
	startup_error = BootSteps.request_error(request.steps)
	if not startup_error.is_empty():
		return false
	for step: StringName in BootSteps.with_needs(request.steps):
		startup_error = _run_step(step)
		if not startup_error.is_empty():
			# A retry reads the network file again, as a first start does.
			_forget_steps(BootSteps.NETWORK)
			return false
	return true


## Boots what [param scene] asks for in its [code]boot_request[/code] property. A scene that asks
## for nothing gets the Essential steps only. A failure is logged and the scene carries on.
func boot_scene(scene: Node) -> bool:
	var request := scene.get(&"boot_request") as BootRequest
	if request == null or request.started_by_entry:
		return true
	if boot(request):
		return true
	push_warning("%s runs without a boot step: %s" % [scene.scene_file_path, startup_error])
	return false


func start(use_local_config := true) -> bool:
	if running:
		return true
	use_local_network_config = use_local_config
	var steps: Array[StringName] = [BootSteps.SERVERS]
	return boot(BootRequest.new(steps))


func addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address: String in IP.get_local_addresses():
		if (
			address.contains(":") or address.begins_with("127.")
			or address.begins_with("169.254.") or address == "0.0.0.0"
		):
			continue
		if not result.has(address):
			result.append(address)
	# Common home networks first, but selection remains explicit for VPN/multi-NIC hosts.
	result.sort()
	for address: String in result:
		if address.begins_with("192.168."):
			result.remove_at(result.find(address))
			result.insert(0, address)
			break
	return result


func stop() -> void:
	_stop_minigame_sessions()
	http.stop()
	websocket.stop()
	running = false
	_forget_steps(BootSteps.NETWORK)


func join_url(address: String) -> String:
	return (network if network != null else ControllerNetworkConfig.new(settings)).join_url(address)


func set_accepting_new_players(accepting: bool) -> void:
	accepting_new_players = accepting


func players() -> Array[Dictionary]:
	return player_registry.public_players()


func minigame_scene_path(minigame_id: StringName) -> String:
	var minigame := minigame_catalog.find(minigame_id)

	return minigame.scene_path if minigame != null else ""


func minigame_availability(minigame_id: StringName, allow_one_player_debug := false) -> Dictionary:
	var minigame := minigame_catalog.find(minigame_id)
	if minigame == null:
		return { "available": false, "reason": "Choose a supported minigame" }

	var player_count := players().size()
	if allow_one_player_debug:
		if not minigame.one_player_debug:
			return { "available": false, "reason": "This minigame has no one-player mode" }
		if player_count != 1:
			return { "available": false, "reason": "Requires exactly one registered player" }
	elif player_count < minigame.min_players:
		return { "available": false, "reason": _fewest_players_reason(minigame.min_players) }
	if player_count > minigame.max_players:
		var limit := [minigame.display_name, minigame.max_players]
		return { "available": false, "reason": "%s supports up to %d players" % limit }
	if (
		not minigame.allowed_player_counts.is_empty()
		and player_count not in minigame.allowed_player_counts
	):
		var counts: Array[String] = []
		for count: int in minigame.allowed_player_counts:
			counts.append(str(count))
		var reason := "%s requires %s players" % [minigame.display_name, ", ".join(counts)]
		return { "available": false, "reason": reason }
	return { "available": true, "reason": "" }


func _fewest_players_reason(fewest: int) -> String:
	if fewest == 1:
		return "At least 1 registered player is needed"

	return "At least %d registered players are needed" % fewest


func minigame_display_name(minigame_id: StringName) -> String:
	var minigame := minigame_catalog.find(minigame_id)

	return minigame.display_name if minigame != null else "Minigame"


func prepare_minigame_launch(
	minigame_id: StringName,
	allow_one_player_debug := false,
) -> Dictionary:
	if minigame_scene_path(minigame_id).is_empty():
		return { "accepted": false, "reason": "Choose a supported minigame" }
	var availability := minigame_availability(minigame_id, allow_one_player_debug)
	if not bool(availability.available):
		return { "accepted": false, "reason": availability.reason }
	# Snapshot before leaving the lobby so later registry changes cannot alter the
	# participant list. Connectivity changes still reach the scene controller.
	_pending_minigame_launch = {
		"minigame_id": minigame_id,
		"participants": players().duplicate(true),
		"allow_one_player_debug": allow_one_player_debug,
	}
	set_accepting_new_players(false)
	return { "accepted": true }


func begin_pre_minigame(minigame_id: StringName) -> Dictionary:
	if readiness != null and readiness.active:
		return { "accepted": false, "reason": "Ready-up is already active" }
	var availability := minigame_availability(minigame_id)
	if not bool(availability.available):
		return { "accepted": false, "reason": availability.reason }
	_stop_minigame_sessions()
	var can_ready := Callable()
	var preparation := Callable()
	var session := minigame_session(minigame_id)
	if session != null:
		if not session.prepare(self):
			var reason := "%s preparation could not start" % minigame_display_name(minigame_id)
			return { "accepted": false, "reason": reason }
		can_ready = session.ready_for
		preparation = session.preparation_for
	readiness = PreMinigameReadiness.new(
		minigame_id,
		players(),
		func() -> bool:
			return (
				bool(minigame_availability(minigame_id).available)
				and (session == null or session.launch_eligible())
			),
		can_ready,
		preparation,
	)
	readiness.changed.connect(_on_readiness_changed)
	readiness.launch_requested.connect(_on_readiness_launch)
	readiness.canceled.connect(_on_readiness_canceled)
	set_accepting_new_players(false)
	websocket.begin_pre_minigame(readiness)
	readiness_changed.emit(readiness.snapshot_for(""))
	return { "accepted": true }


func cancel_pre_minigame() -> void:
	if readiness != null:
		readiness.cancel()


func _on_readiness_changed(snapshot: Dictionary) -> void:
	if readiness != null and minigame_sessions.has(readiness.minigame_id):
		minigame_sessions[readiness.minigame_id].sync_players(players())
	readiness_changed.emit(snapshot)


func _on_readiness_launch(minigame_id: StringName, participants: Array[Dictionary]) -> void:
	# Close the onboarding window before another socket packet can be handled.
	websocket.end_pre_minigame()
	readiness = null
	_pending_minigame_launch = {
		"minigame_id": minigame_id,
		"participants": participants,
		"allow_one_player_debug": false,
	}
	readiness_launch_requested.emit(minigame_id)


func _on_readiness_canceled() -> void:
	_stop_minigame_sessions()
	websocket.end_pre_minigame()
	readiness = null
	readiness_canceled.emit()


func consume_minigame_launch(minigame_id: StringName) -> Dictionary:
	if StringName(_pending_minigame_launch.get("minigame_id", &"")) != minigame_id:
		return { }
	var launch := _pending_minigame_launch
	_pending_minigame_launch = { }
	return launch


func clear_minigame_launch(minigame_id: StringName = &"") -> void:
	if (
		minigame_id.is_empty()
		or StringName(_pending_minigame_launch.get("minigame_id", &"")) == minigame_id
	):
		_pending_minigame_launch = { }
		for id: StringName in minigame_sessions:
			if minigame_id.is_empty() or minigame_id == id:
				minigame_sessions[id].stop()


func send_players_to_lobby() -> void:
	if readiness != null and readiness.active:
		readiness.cancel()
	_stop_minigame_sessions()
	if websocket != null:
		websocket.send_lobby_state()


func register_lobby_controller(controller: LobbyController) -> void:
	if websocket != null:
		websocket.set_lobby_controller(controller)


## The session of [param minigame_id], created on first use, or null for a minigame without one.
## A session is a Node with prepare(host), ready_for(player_id), preparation_for(player_id),
## launch_eligible(), sync_players(players) and stop().
func minigame_session(minigame_id: StringName) -> Node:
	if minigame_sessions.has(minigame_id):
		return minigame_sessions[minigame_id]
	var minigame := minigame_catalog.find(minigame_id)
	if minigame == null or minigame.session_script.is_empty():
		return null
	# Loaded on first use, so listing the catalog and lobby play load no minigame scripts.
	var script := load(minigame.session_script) as Script
	var session: Node = script.new()
	add_child(session)
	minigame_sessions[minigame_id] = session
	return session


func _stop_minigame_sessions() -> void:
	for session: Node in minigame_sessions.values():
		session.stop()


func unregister_lobby_controller(controller: LobbyController) -> void:
	if websocket != null:
		websocket.clear_lobby_controller(controller)


## Routes a running minigame's phone messages to [param protocol].
func register_minigame_protocol(protocol: MinigameProtocol) -> void:
	if websocket != null:
		websocket.set_minigame_protocol(protocol)


func unregister_minigame_protocol(protocol: MinigameProtocol) -> void:
	if websocket != null:
		websocket.clear_minigame_protocol(protocol)


func _on_players_changed() -> void:
	var public_players := _player_registry.public_players()
	for session: Node in minigame_sessions.values():
		session.sync_players(public_players)
	if readiness != null:
		readiness.sync_players(public_players)
	players_changed.emit(public_players)
	var launcher := get_node_or_null("/root/DebugLauncher")
	if launcher != null:
		launcher.set_feature_available(&"one_registered_player", public_players.size() == 1)


func _boot_launched_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		boot_scene(scene)


func _run_step(step: StringName) -> String:
	if step in steps_run:
		return ""
	var error := ""
	match step:
		BootSteps.PRESETS:
			settings = active_presets.networking
		BootSteps.REGISTRY:
			_player_registry = PlayerRegistry.new(
				settings.max_players,
				settings.reconnect_grace_seconds,
			)
			_player_registry.players_changed.connect(_on_players_changed)
		BootSteps.CATALOG:
			_minigame_catalog = load(MINIGAME_CATALOG_PATH)
		BootSteps.NETWORK_CONFIG:
			error = _load_network_config()
		BootSteps.CERTIFICATE:
			var tls := ControllerTLS.new()
			if tls.prepare(network) != OK:
				error = tls.error
			_tls_options = tls.options
		BootSteps.SERVERS:
			error = _start_servers()
		BootSteps.SERVERS_THIS_PC:
			network = ControllerNetworkConfig.new(settings)
			network.bind_address = "127.0.0.1"
			_tls_options = null
			error = _start_servers()
		BootSteps.LOBBY:
			get_tree().change_scene_to_file(LOBBY_PATH)
	if error.is_empty():
		steps_run.append(step)
	if step == BootSteps.REGISTRY:
		_on_players_changed()
	return error


func _forget_steps(steps: Array[StringName]) -> void:
	steps_run = steps_run.filter(
		func(step: StringName) -> bool:
			return step not in steps,
	)


func _load_network_config() -> String:
	network = ControllerNetworkConfig.new(settings)
	var path := ControllerNetworkConfig.local_path()
	if (
		use_local_network_config and not path.is_empty()
		and (OS.has_environment("PLAY_SHAPES_NETWORK_CONFIG") or FileAccess.file_exists(path))
	):
		network.load_local(path)
	return network.error if not network.error.is_empty() else network.validation_error()


func _start_servers() -> String:
	var error := http.start(settings, player_registry.session_id, network, _tls_options)
	if error != OK:
		http.stop()
		if not http.startup_error.is_empty():
			return http.startup_error
		return "Could not start HTTP service: %s" % error_string(error)
	error = websocket.start(
		settings,
		player_registry,
		func() -> bool:
			return accepting_new_players,
		network,
		_tls_options,
	)
	if error != OK:
		http.stop()
		return "Could not listen for WebSocket on port %d: %s" % [
			network.websocket_port,
			error_string(error),
		]
	running = true
	print(
		"Play Shapes ready: %s %d / %s %d"
		% [
			network.http_scheme(),
			network.http_port,
			network.websocket_scheme(),
			network.websocket_port,
		]
	)
	return ""
