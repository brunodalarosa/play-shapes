extends SceneTree
## Synthetic real-socket roster fixture. Observer output is never a production route.

var _host: Node
var _motion: TiltShiftMotionController
var _observed_at: int = -1000


func _initialize() -> void:
	_boot.call_deferred()


func _boot() -> void:
	_host = root.get_node("SessionHost")
	_host.settings = NetworkingTuning.new()
	_host.settings.http_port = 18340
	_host.settings.websocket_port = 18341
	if not _host.start(false):
		push_error("Multiplayer motion fixture could not start")
		quit(1)
		return
	_motion = TiltShiftMotionController.new()
	_host.set_accepting_new_players(true)
	root.add_child(_motion)
	print("Multiplayer motion fixture ready")


func _process(_delta: float) -> bool:
	if _host == null or _motion == null:
		return false
	var players: Array[Dictionary] = _host.players()
	if _motion.inputs.is_empty() and players.size() == 10:
		var ids := PackedStringArray()
		for player: Dictionary in players:
			ids.append(player.player_id)
		_motion.prepare(_host.websocket, ids, TiltShiftMotionTuning.new())
	var now := Time.get_ticks_msec()
	if now - _observed_at < 50:
		return false
	_observed_at = now
	for player: Dictionary in players:
		var channel: MotionInputChannel = _host.websocket.motion_channels.get(player.player_id)
		if channel != null:
			_host.websocket._send_to_player(
				player.player_id,
				{
					"type": "motion_observed",
					"subscription_id": channel.subscription_id,
					"samples": channel.sample_count,
					"latest": channel.latest,
					"state": _motion.player_state(player.player_id),
				},
			)
	return false
