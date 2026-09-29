class_name ControllerNetworkConfig
extends RefCounted
## Canonical endpoints. Local overrides never become browser-visible secrets.

var tls_enabled := false
var bind_address := "*"
var advertised_host := ""
var http_port := 8080
var websocket_port := 8081
var certificate_path := ""
var private_key_path := ""
var error := ""

func _init(settings: NetworkingTuning = null) -> void:
	if settings != null:
		http_port = settings.http_port
		websocket_port = settings.websocket_port

func load_local(path: String) -> void:
	if not FileAccess.file_exists(path):
		error = "Network configuration does not exist: %s" % path
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "Could not read network configuration: %s" % path
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		error = "Network configuration must be a JSON object"
		return
	var values: Dictionary = parser.data
	for field: String in values:
		if field not in ["tls_enabled", "bind_address", "advertised_host", "http_port", "websocket_port", "certificate_path", "private_key_path"]:
			error = "Unknown network setting: %s" % field
			return
		var value: Variant = values[field]
		if field == "tls_enabled":
			if not value is bool:
				error = "tls_enabled must be a boolean"
				return
		elif field in ["http_port", "websocket_port"]:
			if not (value is float or value is int) or not is_finite(float(value)) or float(value) != floor(float(value)) or value < 1024 or value > 65535:
				error = "%s must be an integer from 1024 to 65535" % field
				return
			value = int(value)
		elif not value is String:
			error = "%s must be a string" % field
			return
		if field in ["certificate_path", "private_key_path"] and not String(value).is_empty() and not String(value).is_absolute_path():
			value = path.get_base_dir().path_join(value)
		set(field, value)
	error = validation_error()

static func local_path() -> String:
	if OS.has_environment("PLAY_SHAPES_NETWORK_CONFIG"):
		return OS.get_environment("PLAY_SHAPES_NETWORK_CONFIG")
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	return base.path_join("local/network.json")

func validation_error() -> String:
	if http_port < 1024 or http_port > 65535 or websocket_port < 1024 or websocket_port > 65535 or http_port == websocket_port:
		return "Controller and WebSocket ports must be distinct integers from 1024 to 65535"
	if bind_address != "*" and not bind_address.is_valid_ip_address():
		return "bind_address must be '*' or a local IP address"
	if not advertised_host.is_empty() and not valid_host(advertised_host):
		return "advertised_host must be a hostname or IPv4 address without scheme, path, or port"
	return ""

static func valid_host(value: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$")
	return pattern.search(value) != null and not value.ends_with(".") and not value.contains("..")

func http_scheme() -> String:
	return "https" if tls_enabled else "http"

func websocket_scheme() -> String:
	return "wss" if tls_enabled else "ws"

func join_url(selected_address: String) -> String:
	var hostname := advertised_host if not advertised_host.is_empty() else selected_address
	return "%s://%s:%d" % [http_scheme(), hostname, http_port]

func public_session(session_id: String) -> Dictionary:
	return {"protocol": 1, "session_id": session_id, "http_scheme": http_scheme(),
		"websocket_scheme": websocket_scheme(), "websocket_port": websocket_port}
