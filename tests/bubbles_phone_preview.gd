extends SceneTree
## Local desktop-browser preview only; not a playable arena or phone validation.

var _controller: BubblesRoundController
var _timer: Timer


func _initialize() -> void:
	_boot.call_deferred()


func _boot() -> void:
	var session := root.get_node("/root/SessionHost")
	var configured_port := OS.get_environment("BUBBLES_PREVIEW_PORT")
	if configured_port.is_valid_int():
		var port := int(configured_port)
		if port >= 1024 and port < 65535:
			session.settings.http_port = port
			session.settings.websocket_port = port + 1
	if not session.start():
		push_error(session.startup_error)
		quit(1)
		return
	session.set_accepting_new_players(true)
	session.players_changed.connect(_on_players_changed)
	print("Bubbles phone preview ready: join at http://127.0.0.1:%d" % session.settings.http_port)


func _on_players_changed(players: Array[Dictionary]) -> void:
	if _controller != null or players.is_empty():
		return
	_start_round.call_deferred(players[0])


func _start_round(player: Dictionary) -> void:
	if _controller != null:
		return
	var session := root.get_node("/root/SessionHost")
	session.set_accepting_new_players(false)
	_controller = BubblesRoundController.new()
	root.add_child(_controller)
	_controller.tuning = BubblesTuning.new()
	_controller.tuning.instructions_seconds = 0.0
	_controller.tuning.countdown_seconds = 0.0
	_controller.tuning.round_duration_seconds = 120.0
	var now := Time.get_ticks_msec()
	_controller.start_round([player], now, true)
	session.register_bubbles_controller(_controller)
	_controller.complete_entrance(now)
	_controller.advance(now)
	for index: int in 8:
		_controller.record_jellyfish_capture(String(player.player_id), now)
	_timer = Timer.new()
	_timer.wait_time = 1.0 / 30.0
	_timer.timeout.connect(func() -> void:
		if _controller.phase_name() == &"active":
			_controller.advance(Time.get_ticks_msec()))
	root.add_child(_timer)
	_timer.start()
