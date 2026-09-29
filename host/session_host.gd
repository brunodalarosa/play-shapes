extends Node
## Persistent services survive scene changes. Boot owns starting them.

signal connection_count_changed(count: int)
signal players_changed(players: Array[Dictionary])
signal readiness_changed(snapshot: Dictionary)
signal readiness_launch_requested(minigame_id: StringName)
signal readiness_canceled

const BUBBLES_SCENE_PATH := "res://minigames/bubbles_and_jellyfishes.tscn"
const BUBBLES_MAX_PLAYERS := 10
const MINIGAME_BUBBLES := &"bubbles"

@export var active_presets: ActivePresets = preload("res://Tuning/Active Presets.tres")
var settings: NetworkingTuning
var running: bool = false
var startup_error: String = ""
var http: HttpService
var websocket: WebsocketService
var player_registry: PlayerRegistry
var accepting_new_players: bool = false
var _pending_minigame_launch: Dictionary = {}
var readiness: PreMinigameReadiness

func _ready() -> void:
	settings = active_presets.networking
	player_registry = PlayerRegistry.new(settings.max_players, settings.reconnect_grace_seconds)
	http = HttpService.new()
	websocket = WebsocketService.new()
	add_child(http)
	add_child(websocket)
	websocket.connection_count_changed.connect(connection_count_changed.emit)
	player_registry.players_changed.connect(_on_players_changed)
	_on_players_changed()

func _process(_delta: float) -> void:
	player_registry.expire_players()

func start() -> bool:
	if running:
		return true
	var error := http.start(settings, player_registry.session_id)
	if error != OK:
		startup_error = http.startup_error
		if startup_error.is_empty():
			startup_error = "Could not start HTTP service: %s" % error_string(error)
		http.stop()
		return false
	error = websocket.start(settings, player_registry, func() -> bool: return accepting_new_players)
	if error != OK:
		http.stop()
		startup_error = "Could not listen for WebSocket on port %d: %s" % [settings.websocket_port, error_string(error)]
		return false
	running = true
	startup_error = ""
	print("Play Shapes ready: HTTP %d / WebSocket %d" % [settings.http_port, settings.websocket_port])
	return true

func addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address: String in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
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
	http.stop()
	websocket.stop()
	running = false

func join_url(address: String) -> String:
	return "http://%s:%d" % [address, settings.http_port]

func set_accepting_new_players(accepting: bool) -> void:
	accepting_new_players = accepting

func players() -> Array[Dictionary]:
	return player_registry.public_players()

func minigame_scene_path(minigame_id: StringName) -> String:
	match minigame_id:
		MINIGAME_BUBBLES:
			return BUBBLES_SCENE_PATH
	return ""


func minigame_availability(minigame_id: StringName, allow_one_player_debug := false) -> Dictionary:
	var maximum_players := 0
	match minigame_id:
		MINIGAME_BUBBLES:
			maximum_players = BUBBLES_MAX_PLAYERS
		_:
			return {"available": false, "reason": "Choose a supported minigame"}
	var player_count := players().size()
	if allow_one_player_debug:
		if player_count != 1:
			return {
				"available": false,
				"reason": "Requires exactly one registered player",
			}
	elif player_count < 2:
		return {
			"available": false,
			"reason": "At least 2 registered players are needed",
		}
	if player_count > maximum_players:
		return {
			"available": false,
			"reason": "%s supports up to %d players" % [minigame_display_name(minigame_id), maximum_players],
		}
	return {"available": true, "reason": ""}


func minigame_display_name(minigame_id: StringName) -> String:
	match minigame_id:
		MINIGAME_BUBBLES:
			return "Bubbles and Jellyfishes"
	return "Minigame"


func prepare_minigame_launch(minigame_id: StringName, allow_one_player_debug := false) -> Dictionary:
	if minigame_scene_path(minigame_id).is_empty():
		return {"accepted": false, "reason": "Choose a supported minigame"}
	var availability := minigame_availability(minigame_id, allow_one_player_debug)
	if not bool(availability.available):
		return {"accepted": false, "reason": availability.reason}
	# Snapshot before leaving the lobby so later registry changes cannot alter the
	# participant list. Connectivity changes still reach the scene controller.
	_pending_minigame_launch = {
		"minigame_id": minigame_id,
		"participants": players().duplicate(true),
		"allow_one_player_debug": allow_one_player_debug,
	}
	set_accepting_new_players(false)
	return {"accepted": true}


func begin_pre_minigame(minigame_id: StringName) -> Dictionary:
	if readiness != null and readiness.active:
		return {"accepted": false, "reason": "Ready-up is already active"}
	var availability := minigame_availability(minigame_id)
	if not bool(availability.available):
		return {"accepted": false, "reason": availability.reason}
	readiness = PreMinigameReadiness.new(minigame_id, players())
	readiness.changed.connect(_on_readiness_changed)
	readiness.launch_requested.connect(_on_readiness_launch)
	readiness.canceled.connect(_on_readiness_canceled)
	set_accepting_new_players(false)
	websocket.begin_pre_minigame(readiness)
	readiness_changed.emit(readiness.snapshot_for(""))
	return {"accepted": true}


func cancel_pre_minigame() -> void:
	if readiness != null:
		readiness.cancel()


func _on_readiness_changed(snapshot: Dictionary) -> void:
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
	websocket.end_pre_minigame()
	readiness = null
	readiness_canceled.emit()

func consume_minigame_launch(minigame_id: StringName) -> Dictionary:
	if StringName(_pending_minigame_launch.get("minigame_id", &"")) != minigame_id:
		return {}
	var launch := _pending_minigame_launch
	_pending_minigame_launch = {}
	return launch


func clear_minigame_launch(minigame_id: StringName = &"") -> void:
	if minigame_id.is_empty() or StringName(_pending_minigame_launch.get("minigame_id", &"")) == minigame_id:
		_pending_minigame_launch = {}


func bubbles_availability(allow_one_player_debug := false) -> Dictionary:
	return minigame_availability(MINIGAME_BUBBLES, allow_one_player_debug)


func prepare_bubbles_launch(allow_one_player_debug := false) -> Dictionary:
	return prepare_minigame_launch(MINIGAME_BUBBLES, allow_one_player_debug)


func consume_bubbles_launch() -> Dictionary:
	return consume_minigame_launch(MINIGAME_BUBBLES)


func clear_bubbles_launch() -> void:
	clear_minigame_launch(MINIGAME_BUBBLES)

func send_players_to_lobby() -> void:
	if websocket != null:
		websocket.send_lobby_state()

func register_lobby_controller(controller: LobbyPlaygroundWorld) -> void:
	if websocket != null:
		websocket.set_lobby_controller(controller)

func unregister_lobby_controller(controller: LobbyPlaygroundWorld) -> void:
	if websocket != null:
		websocket.clear_lobby_controller(controller)

func register_bubbles_controller(controller: BubblesRoundController) -> void:
	if websocket != null:
		websocket.set_bubbles_controller(controller)

func unregister_bubbles_controller(controller: BubblesRoundController) -> void:
	if websocket != null:
		websocket.clear_bubbles_controller(controller)

func _on_players_changed() -> void:
	var public_players := player_registry.public_players()
	if readiness != null:
		readiness.sync_players(public_players)
	players_changed.emit(public_players)
	var launcher := get_node_or_null("/root/DebugLauncher")
	if launcher != null:
		launcher.set_feature_available(&"one_registered_player", public_players.size() == 1)
