extends Node
## Persistent services survive scene changes. Boot owns starting them.

signal connection_count_changed(count: int)
signal players_changed(players: Array[Dictionary])

const FLASH_POSE_SCENE_PATH := "res://minigames/dancer_simon_says.tscn"
const FLASH_POSE_MAX_PLAYERS := 10

@export var active_presets: ActivePresets = preload("res://Tuning/Active Presets.tres")
var settings: NetworkingTuning
var running: bool = false
var startup_error: String = ""
var http: HttpService
var websocket: WebsocketService
var player_registry: PlayerRegistry
var accepting_new_players: bool = false
var _pending_flash_pose_launch: Dictionary = {}

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
		startup_error = "Could not start HTTP on port %d: %s" % [settings.http_port, error_string(error)]
		http.stop()
		return false
	error = websocket.start(settings, player_registry, func() -> bool: return accepting_new_players)
	if error != OK:
		http.stop()
		startup_error = "Could not start WebSocket on port %d: %s" % [settings.websocket_port, error_string(error)]
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

func flash_pose_availability(allow_one_player_debug := false) -> Dictionary:
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
	if player_count > FLASH_POSE_MAX_PLAYERS:
		return {
			"available": false,
			"reason": "Flash? Pose! supports up to %d players" % FLASH_POSE_MAX_PLAYERS,
		}
	return {"available": true, "reason": ""}

func prepare_flash_pose_launch(allow_one_player_debug := false) -> Dictionary:
	var availability := flash_pose_availability(allow_one_player_debug)
	if not bool(availability.available):
		return {"accepted": false, "reason": availability.reason}
	# Snapshot before leaving the lobby so later registry changes cannot alter the
	# participant list. Connectivity changes still reach the scene controller.
	_pending_flash_pose_launch = {
		"participants": players().duplicate(true),
		"allow_one_player_debug": allow_one_player_debug,
	}
	set_accepting_new_players(false)
	return {"accepted": true}

func consume_flash_pose_launch() -> Dictionary:
	var launch := _pending_flash_pose_launch
	_pending_flash_pose_launch = {}
	return launch

func clear_flash_pose_launch() -> void:
	_pending_flash_pose_launch = {}

func send_players_to_lobby() -> void:
	if websocket != null:
		websocket.send_lobby_state()

func register_flash_pose_controller(controller: FlashPoseRoundController) -> void:
	if websocket != null:
		websocket.set_flash_pose_controller(controller)

func unregister_flash_pose_controller(controller: FlashPoseRoundController) -> void:
	if websocket != null:
		websocket.clear_flash_pose_controller(controller)

func _on_players_changed() -> void:
	var public_players := player_registry.public_players()
	players_changed.emit(public_players)
	var launcher := get_node_or_null("/root/DebugLauncher")
	if launcher != null:
		launcher.set_feature_available(&"one_registered_player", public_players.size() == 1)
