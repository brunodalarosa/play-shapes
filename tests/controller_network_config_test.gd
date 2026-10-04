extends TestScript


func _run() -> void:
	var settings := NetworkingTuning.new()
	var config := ControllerNetworkConfig.new(settings)
	check(config.validation_error().is_empty(), "The default network settings are valid")
	check(
		config.join_url("192.168.1.50") == "http://192.168.1.50:8080",
		"The join URL uses the LAN address and the HTTP port",
	)
	config.tls_enabled = true
	config.advertised_host = "playshapes.local"
	check(
		config.join_url("192.168.1.50") == "https://playshapes.local:8080",
		"With TLS the join URL uses HTTPS and the advertised host",
	)
	check(
		config.public_session("test").websocket_scheme == "wss",
		"With TLS the session tells phones to use a secure WebSocket",
	)
	check(
		not config.public_session("test").has("private_key_path"),
		"The session sent to phones leaves out the private key path",
	)
	config.websocket_port = config.http_port
	check(
		not config.validation_error().is_empty(),
		"One port for both HTTP and WebSocket is rejected",
	)
	config.websocket_port = 8081
	config.advertised_host = "https://wrong/path"
	check(
		not config.validation_error().is_empty(),
		"An advertised host with a scheme or a path is rejected",
	)
