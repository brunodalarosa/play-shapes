extends SceneTree

const Service = preload("res://host/websocket_service.gd")
const BubblesController = preload("res://minigames/bubbles_round_controller.gd")
const FlashController = preload("res://minigames/flash_pose_round_controller.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var service := Service.new()
	root.add_child(service)
	var bubbles := BubblesController.new()
	root.add_child(bubbles)
	bubbles.tuning = BubblesTuning.new()
	bubbles.tuning.instructions_seconds = 0.0
	bubbles.tuning.countdown_seconds = 0.0
	bubbles.start_round([{"player_id": "p0", "name": "First", "seat": 1}, {"player_id": "p1", "name": "Second", "seat": 2}], 0)
	bubbles.complete_entrance(0)
	bubbles.advance(0)
	service.set_bubbles_controller(bubbles)
	_check(service._active_protocol == service._bubbles_protocol and service._active_protocol.snapshot_for("p0").type == "bubbles_snapshot",
		"Bubbles is the only active gameplay protocol")
	_check(bubbles.return_to_lobby_requested.is_connected(service._on_bubbles_return_to_lobby),
		"Bubbles results return resets the connected phones")
	var flash := FlashController.new()
	root.add_child(flash)
	flash.tuning = SimonSaysTuning.new()
	service.set_flash_pose_controller(flash)
	_check(service._bubbles_protocol == null and service._active_protocol == service._flash_pose_protocol,
		"Starting Flash Pose clears Bubbles routing")
	service.clear_flash_pose_controller(flash)
	_check(service._active_protocol == null, "Leaving Flash Pose clears active routing")
	service.set_bubbles_controller(bubbles)
	service.clear_bubbles_controller(bubbles)
	_check(service._active_protocol == null and service._bubbles_protocol == null, "Leaving Bubbles clears active routing")
	print("Active minigame protocol checks: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
