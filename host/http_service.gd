class_name HttpService
extends Node
## A bounded, nonblocking HTTP service for a fixed set of bundled assets.
## Each connection serves one request, then closes; no filesystem paths come from clients.

const ASSETS: Dictionary = {
"/pwa.js": {
	"path": "res://web/public/pwa.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/manifest.webmanifest": {
	"path": "res://web/public/manifest.webmanifest",
	"content_type": "application/manifest+json",
},
"/app-icon-180.png": {
	"path": "res://web/public/app-icon-180.png",
	"content_type": "image/png",
	"resource_type": "Texture2D",
},
"/app-icon-192.png": {
	"path": "res://web/public/app-icon-192.png",
	"content_type": "image/png",
	"resource_type": "Texture2D",
},
"/app-icon-512.png": {
	"path": "res://web/public/app-icon-512.png",
	"content_type": "image/png",
	"resource_type": "Texture2D",
},

"/motion_lab.js": {
	"path": "res://web/public/motion_lab.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/motion_input.js": {
	"path": "res://web/public/motion_input.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/network_config.js": {
	"path": "res://web/public/network_config.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/": {
	"path": "res://web/public/index.html",
	"content_type": "text/html; charset=utf-8",
},
"/app.js": {
	"path": "res://web/public/app.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/lobby_controls.js": {
	"path": "res://web/public/lobby_controls.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/lobby_input.js": {
	"path": "res://web/public/lobby_input.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/vendor/nipplejs.mjs": {
	"path": "res://web/public/vendor/nipplejs.mjs",
	"content_type": "text/javascript; charset=utf-8",
},
"/immersive.js": {
	"path": "res://web/public/immersive.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/bubbles_gesture.js": {
	"path": "res://web/public/bubbles_gesture.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/character_selection.js": {
	"path": "res://web/public/character_selection.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/squircle_v1.js": {
	"path": "res://web/public/squircle_v1.js",
	"content_type": "text/javascript; charset=utf-8",
},
"/squircle-v1/manifest.json": {
	"path": "res://assets/runtime/animated_characters/squircle/v1/manifest.json",
	"content_type": "application/json",
},
"/squircle-v1/idle-front-colorable.png": {
	"path": "res://assets/runtime/animated_characters/squircle/v1/idle-front-colorable.png",
	"content_type": "image/png",
	"resource_type": "Texture2D",
},
"/squircle-v1/idle-front-neutral.png": {
	"path": "res://assets/runtime/animated_characters/squircle/v1/idle-front-neutral.png",
	"content_type": "image/png",
	"resource_type": "Texture2D",
},
"/squircle-v1/idle-front-blink.png": {
	"path": "res://assets/runtime/animated_characters/squircle/v1/idle-front-blink.png",
	"content_type": "image/png",
	"resource_type": "Texture2D",
},
"/bubbles-jellyfish.png": {
	"path": "res://assets/runtime/minigames/bubbles_and_jellyfishes/jellyfish/jellyfish_small.png",
	"content_type": "image/png",
	"resource_type": "Texture2D",
},
"/bubbles-phone-background.png": {
	"path": "res://assets/runtime/minigames/bubbles_and_jellyfishes/environment/phone_background_portrait.png",
	"content_type": "image/png",
	"resource_type": "Texture2D",
},
"/style.css": {
	"path": "res://web/public/style.css",
	"content_type": "text/css; charset=utf-8",
},
}
var _server: TCPServer = TCPServer.new()
var _clients: Array[Dictionary] = []
var _settings: NetworkingTuning
var _tls_options: TLSOptions
var _network: ControllerNetworkConfig
var _bodies: Dictionary = {}
var _session_id: String
var startup_error: String = ""

func start(settings: NetworkingTuning, session_id: String, network: ControllerNetworkConfig = null, tls_options: TLSOptions = null) -> Error:
	_tls_options = tls_options
	_settings = settings
	_network = network if network != null else ControllerNetworkConfig.new(settings)
	_session_id = session_id
	startup_error = ""
	_bodies.clear()
	for route: String in ASSETS:
		var asset: Dictionary = ASSETS[route]
		var error := _load_asset(route, asset)
		if error != OK:
			return error
	var listen_error := _server.listen(_network.http_port, _network.bind_address)
	if listen_error != OK:
		startup_error = "Could not listen for HTTP on port %d: %s" % [
			_network.http_port, error_string(listen_error),
		]
	return listen_error

func _load_asset(route: String, asset: Dictionary) -> Error:
	var path: String = asset.path
	if asset.get("resource_type", "") == "Texture2D":
		var texture := ResourceLoader.load(path) as Texture2D
		if texture == null:
			startup_error = "Could not load HTTP image resource '%s'." % path
			return ERR_FILE_NOT_FOUND
		var image := texture.get_image()
		if image.is_empty():
			startup_error = "Could not read HTTP image resource '%s'." % path
			return ERR_FILE_CORRUPT
		var png_bytes := image.save_png_to_buffer()
		if png_bytes.is_empty():
			startup_error = "Could not encode HTTP image resource '%s' as PNG." % path
			return ERR_CANT_CREATE
		_bodies[route] = png_bytes
		return OK
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		startup_error = "Could not read HTTP asset '%s': %s" % [path, error_string(error)]
		return error
	_bodies[route] = file.get_buffer(file.get_length())
	return OK

func stop() -> void:
	_server.stop()
	for client: Dictionary in _clients:
		client.connection.close()
	_clients.clear()

func _process(_delta: float) -> void:
	if not _server.is_listening():
		return
	# Bound work per frame as well as total connections.
	for unused: int in range(8):
		if not _server.is_connection_available():
			break
		var peer := _server.take_connection()
		if _clients.size() >= _settings.max_connections:
			peer.disconnect_from_host()
		else:
			_clients.append({"connection": ControllerStream.new(peer, _tls_options), "input": PackedByteArray(),
				"output": PackedByteArray(), "sent": 0, "created": Time.get_ticks_msec(), "finished": -1})
	for index: int in range(_clients.size() - 1, -1, -1):
		var client: Dictionary = _clients[index]
		var connection: ControllerStream = client.connection
		var ready := connection.poll_ready()
		if connection.failed or Time.get_ticks_msec() - client.created > _settings.request_timeout_seconds * 1000:
			_drop(index)
			continue
		if not ready:
			continue
		var peer: StreamPeer = connection.stream
		if client.finished >= 0:
			if Time.get_ticks_msec() - client.finished >= 100:
				_drop(index)
			continue
		if client.output.is_empty():
			var available := peer.get_available_bytes()
			if available > 0:
				var read := peer.get_partial_data(mini(available, 8193))
				if read[0] != OK:
					_drop(index)
					continue
				client.input.append_array(read[1])
				if client.input.size() > 8192:
					client.output = _response("431 Request Header Fields Too Large", "text/plain", "Request too large".to_utf8_buffer())
				elif client.input.get_string_from_utf8().contains("\r\n\r\n"):
					client.output = _route(client.input.get_string_from_utf8())
		else:
			# Partial writes retain their offset; a slow phone never blocks the game loop.
			var write := peer.put_partial_data(client.output.slice(client.sent))
			if write[0] != OK:
				_drop(index)
				continue
			client.sent += write[1]
			if write[1] > 0:
				client.created = Time.get_ticks_msec() # Timeout measures stalls, not total transfer time.
			if client.sent == client.output.size():
				client.finished = Time.get_ticks_msec() # Let TCP flush before closing a larger asset response.

func _drop(index: int) -> void:
	_clients[index].connection.close()
	_clients.remove_at(index)

func _route(request: String) -> PackedByteArray:
	var parts := request.get_slice("\r\n", 0).split(" ")
	if parts.size() != 3:
		return _response("400 Bad Request", "text/plain", "Bad request".to_utf8_buffer())
	if parts[0] != "GET":
		return _response("405 Method Not Allowed", "text/plain", "GET only".to_utf8_buffer())
	var route := parts[1].get_slice("?", 0)
	if route == "/session.json":
		return _response("200 OK", "application/json", JSON.stringify(_network.public_session(_session_id)).to_utf8_buffer())
	if not ASSETS.has(route):
		return _response("404 Not Found", "text/plain", "Not found".to_utf8_buffer())
	return _response("200 OK", ASSETS[route].content_type, _bodies[route])

func _response(status: String, mime: String, body: PackedByteArray) -> PackedByteArray:
	var headers := "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n" % [status, mime, body.size()]
	var result := headers.to_utf8_buffer()
	result.append_array(body)
	return result

func _exit_tree() -> void:
	stop()
