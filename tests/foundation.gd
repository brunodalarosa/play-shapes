extends SceneTree
## Runs independently from the interactive host, using alternate test ports.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := root.get_node("SessionHost")
	host.settings = HostSettings.new()
	host.settings.http_port = 18080
	host.settings.websocket_port = 18081
	var blocker := TCPServer.new()
	if not _check(blocker.listen(18081) == OK, "Test port 18081 is already occupied"):
		return
	if not _check(not host.start(), "Busy WebSocket port must fail startup"):
		return
	var probe := TCPServer.new()
	if not _check(probe.listen(18080) == OK, "Failed startup must release HTTP port"):
		return
	probe.stop()
	blocker.stop()
	if not _check(host.start(), "Retry must start both services"):
		return
	host.stop()
	if not _check(host.start(), "Stopped host must restart"):
		return
	var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	var qr: QRCodeRect = lobby.get_node("%JoinQR")
	qr.data = "http://192.168.1.50:8080".to_utf8_buffer()
	qr.update()
	DirAccess.make_dir_recursive_absolute("res://test-results")
	if not _check(qr.texture.get_image().save_png("res://test-results/join-qr.png") == OK, "Save QR image"):
		return
	lobby.queue_free()
	host.stop()
	await process_frame
	print("Foundation checks passed")
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
