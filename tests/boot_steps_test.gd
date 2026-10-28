extends TestScript
## A launch runs only the Essential steps, and an entry gets exactly the steps it asks for.

const LOBBY_CHARACTER := "res://characters/lobby_cubio.tscn"


func _run() -> void:
	var host := root.get_node("SessionHost")
	var essential_only: Array[StringName] = [BootSteps.PRESETS]
	check(host.steps_run == essential_only, "A bare launch runs the Essential steps only")
	check(
		not ResourceLoader.has_cached(SessionHost.MINIGAME_CATALOG_PATH),
		"A bare launch leaves the minigame catalog unloaded",
	)
	check(
		not ResourceLoader.has_cached(LOBBY_CHARACTER),
		"A bare launch leaves the lobby character unloaded",
	)
	_check_needs()

	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18080
	host.settings.websocket_port = 18081
	var entry: Node = load("res://tests/boot_entry.gd").new()
	var this_pc: Array[StringName] = [BootSteps.SERVERS_THIS_PC]
	entry.boot_request = BootRequest.new(this_pc)
	root.add_child(entry)
	check(host.boot_scene(entry), "This PC's servers start for an entry that asks")
	var expected: Array[StringName] = [
		BootSteps.PRESETS,
		BootSteps.REGISTRY,
		BootSteps.SERVERS_THIS_PC,
	]
	check(host.steps_run == expected, "The entry runs its step and what it needs, no more")
	check(host.network.bind_address == "127.0.0.1", "This PC's servers bind to this PC only")
	check(host.network.http_scheme() == "http", "This PC's servers run without a certificate")
	check(
		not ResourceLoader.has_cached(SessionHost.MINIGAME_CATALOG_PATH),
		"Servers alone leave the minigame catalog unloaded",
	)
	check(await _reaches("127.0.0.1", 18080), "This PC reaches the HTTP server")
	var addresses: PackedStringArray = host.addresses()
	if not addresses.is_empty():
		check(not await _reaches(addresses[0], 18080), "The local network cannot reach it")
	host.stop()
	check(BootSteps.SERVERS_THIS_PC not in host.steps_run, "Stopping forgets the server step")

	var unknown: Array[StringName] = [&"teleporter"]
	check(not host.boot(BootRequest.new(unknown)), "An unknown step fails the boot")
	var both: Array[StringName] = [BootSteps.SERVERS, BootSteps.SERVERS_THIS_PC]
	check(not host.boot(BootRequest.new(both)), "Both kinds of servers at once fail the boot")


func _check_needs() -> void:
	var lobby: Array[StringName] = [BootSteps.LOBBY]
	var lobby_needs: Array[StringName] = [
		BootSteps.PRESETS,
		BootSteps.REGISTRY,
		BootSteps.NETWORK_CONFIG,
		BootSteps.CERTIFICATE,
		BootSteps.SERVERS,
		BootSteps.LOBBY,
	]
	check(BootSteps.with_needs(lobby) == lobby_needs, "The lobby brings the servers it needs")
	var full_game: BootRequest = load("res://host/full_game_boot_request.tres")
	var every_step := BootSteps.ORDER.duplicate()
	every_step.erase(BootSteps.SERVERS_THIS_PC)
	check(BootSteps.with_needs(full_game.steps) == every_step, "The full game runs every step")


func _reaches(address: String, port: int) -> bool:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host(address, port) != OK:
		return false
	for frame: int in 60:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
			return true
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR:
			return false
		await process_frame
	return false
