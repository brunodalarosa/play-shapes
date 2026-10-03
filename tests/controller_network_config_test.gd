extends SceneTree


func _initialize() -> void:
	var settings := NetworkingTuning.new()
	var config := ControllerNetworkConfig.new(settings)
	assert(config.validation_error().is_empty())
	assert(config.join_url("192.168.1.50") == "http://192.168.1.50:8080")
	config.tls_enabled = true
	config.advertised_host = "playshapes.local"
	assert(config.join_url("192.168.1.50") == "https://playshapes.local:8080")
	assert(config.public_session("test").websocket_scheme == "wss")
	assert(not config.public_session("test").has("private_key_path"))
	config.websocket_port = config.http_port
	assert(not config.validation_error().is_empty())
	config.websocket_port = 8081
	config.advertised_host = "https://wrong/path"
	assert(not config.validation_error().is_empty())
	print("Controller network configuration checks passed")
	quit(0)
