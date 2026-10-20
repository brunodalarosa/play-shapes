extends Control
## Explicitly simulated Tilt Shift 3D review: ten synthetic players in every colour tilt their
## paddles through a whole shift. It creates no players and grants no real launch eligibility.

const FACTORY := preload("res://minigames/005_3d_tilt_shift/tilt_shift_3d_presentation.tscn")
var _factory: TiltShift3DPresentation
var _elapsed := 0.0


func _ready() -> void:
	var host := get_node("/root/SessionHost")
	host.send_players_to_lobby()
	host.clear_minigame_launch()
	host.set_accepting_new_players(false)
	_factory = FACTORY.instantiate()
	add_child(_factory)
	var players: Array[TiltShift3DState.Player] = []
	for index: int in 10:
		var player := TiltShift3DState.Player.new()
		player.player_id = "demo_%d" % index
		player.player_name = "Demo %d" % (index + 1)
		player.seat = index + 1
		player.character_color = String(CharacterSelection.COLORS[index].hex)
		players.append(player)
	_factory.start_shift(host.active_presets.tilt_shift_3d, players)
	_factory.arena.controller.round_ended.connect(_on_round_ended)


func _process(delta: float) -> void:
	_elapsed += delta
	var controller := _factory.arena.controller
	var state := controller.snapshot()
	if state.phase == &"preparing":
		# Synthetic players have no phones to supply motion readiness or READY.
		for player: TiltShift3DState.Player in state.players:
			if not player.selected:
				continue
			controller.set_motion_usable(player.player_id, true)
			if state.panel_visible:
				controller.set_ready(
					player.player_id,
					true,
					state.round_token,
					Time.get_ticks_msec(),
				)
		return
	if state.phase != &"active":
		return
	for player: TiltShift3DState.Player in state.players:
		# Each player sways at their own pace; some sway fast enough to get dizzy now and then.
		var pace := 0.7 + 0.25 * (player.seat % 4)
		var angle := sin(_elapsed * pace + player.seat * 0.4) * 0.8
		controller.accept_angle(player.player_id, angle, state.round_token, Time.get_ticks_msec())


func _on_round_ended(state: TiltShift3DState.Snapshot) -> void:
	if state.phase == &"between_rounds":
		_factory.start_next_round.call_deferred()
