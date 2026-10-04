extends TestScript

const Service = preload("res://host/websocket_service.gd")
const BubblesController = preload(
	"res://minigames/002_bubbles_and_jellyfishes/bubbles_round_controller.gd"
)


func _run() -> void:
	var service := Service.new()
	root.add_child(service)
	var bubbles := BubblesController.new()
	root.add_child(bubbles)
	bubbles.tuning = BubblesTuning.new()
	bubbles.tuning.instructions_seconds = 0.0
	bubbles.tuning.countdown_seconds = 0.0
	bubbles.start_round(
		[
			{ "player_id": "p0", "name": "First", "seat": 1 },
			{ "player_id": "p1", "name": "Second", "seat": 2 },
		],
		0,
	)
	bubbles.complete_entrance(0)
	bubbles.advance(0)
	service.set_bubbles_controller(bubbles)
	check(
		service._active_protocol == service._bubbles_protocol
		and service._active_protocol.snapshot_for("p0").type == "bubbles_snapshot",
		"Bubbles is the only active gameplay protocol",
	)
	check(
		bubbles.return_to_lobby_requested.is_connected(service._on_bubbles_return_to_lobby),
		"Bubbles results return resets the connected phones",
	)
	service.clear_bubbles_controller(bubbles)
	check(
		service._active_protocol == null and service._bubbles_protocol == null,
		"Leaving Bubbles clears active routing",
	)
