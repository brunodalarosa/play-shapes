extends Control
## Explicitly simulated review. It does not create players or grant real launch eligibility.

const FACTORY := preload("res://minigames/003_tilt_shift/tilt_shift_presentation.tscn")
var _factory: TiltShiftPresentation
var _elapsed := 0.0


func _ready() -> void:
	var host := get_node("/root/SessionHost")
	host.send_players_to_lobby()
	host.clear_minigame_launch()
	host.set_accepting_new_players(false)
	_factory = FACTORY.instantiate()
	add_child(_factory)
	var players: Array[TiltShiftState.Player] = []
	for index: int in 10:
		var player := TiltShiftState.Player.new()
		player.player_id = "demo_%d" % index
		player.player_name = "Demo %d" % (index + 1)
		player.seat = index + 1
		player.character_color = "#598DF2"
		players.append(player)
	_factory.start_shift(host.active_presets.tilt_shift, players)
	_factory.arena.controller.round_ended.connect(_on_round_ended)


func _process(delta: float) -> void:
	_elapsed += delta
	var controller := _factory.arena.controller
	var state := controller.snapshot()
	if state.phase != &"active":
		return
	for player: TiltShiftState.Player in state.players:
		var angle := sin(_elapsed * 0.7 + player.seat * 0.4) * 0.8
		controller.accept_angle(player.player_id, angle, state.round_token, Time.get_ticks_msec())


func _on_round_ended(state: TiltShiftState.Snapshot) -> void:
	if state.phase == &"between_rounds":
		_factory.start_next_round.call_deferred()
