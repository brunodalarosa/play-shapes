extends Node
## Persistent services survive scene changes. Boot owns starting them.

signal connection_count_changed(count: int)

@export var settings: HostSettings = preload("res://host/default_settings.tres")
var running: bool = false
var startup_error: String = ""
var http: HttpService
var websocket: WebsocketService

func _ready() -> void:
	http = HttpService.new()
	websocket = WebsocketService.new()
	add_child(http)
	add_child(websocket)
	websocket.connection_count_changed.connect(connection_count_changed.emit)

func start() -> bool:
	if running:
		return true
	var error := http.start(settings)
	if error != OK:
		startup_error = "Could not start HTTP on port %d: %s" % [settings.http_port, error_string(error)]
		http.stop()
		return false
	error = websocket.start(settings)
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
