class_name FlappyRaceAutopilot
extends RefCounted
## A simulated Flappy Race player. It decides each tick from its settled flight with
## [FlappyFlightAutopilot] and sends its taps as a phone would, through
## [method FlappyRaceProtocol.handle_message] (decision 0008).
##
## It has one skill, Good, until the game's own bots are designed; they are meant to share this
## player with the workshop.

enum Skill {
	GOOD,
}

## A registry-like player: player_id, name, character_color and seat.
var player: Dictionary
var skill := Skill.GOOD
## Ticks after GO before it starts deciding, so autopilots flying the same course part ways.
var delay_ticks := 0
var _pilot: FlappyFlightAutopilot
var _seq := 0


func _init(autopilot_player: Dictionary, start_delay_ticks := 0) -> void:
	player = autopilot_player
	delay_ticks = start_delay_ticks


## A player for seat [param seat], named and coloured from the character palette.
static func make_player(index: int, seat: int) -> Dictionary:
	var colors := CharacterSelection.COLORS
	return {
		"player_id": "autopilot-%d" % (index + 1),
		"name": "Autopilot %d" % (index + 1),
		"character_shape": "cubio",
		"character_color": colors[(index + 3) % colors.size()].hex,
		"seat": seat,
		"state": "connected",
	}


## Flies in [param race] from now on, sending taps through [param protocol].
func join(race: FlappyRaceController, protocol: FlappyRaceProtocol) -> void:
	_pilot = FlappyFlightAutopilot.new(race.tuning.flight, race.course.flight)
	_seq = 0
	race.tick_settled.connect(_on_tick_settled.bind(race, protocol))


func _on_tick_settled(tick: int, race: FlappyRaceController, protocol: FlappyRaceProtocol) -> void:
	var racer := race.racer_for(player.player_id)
	if racer == null or not racer.racing() or tick < delay_ticks:
		return
	if not _pilot.decide(racer.state):
		return

	_seq += 1
	var tap := { "type": FlappyRaceProtocol.TAP_TYPE, "seq": _seq, "tick": tick + 1 }
	# Decided while the race settles, so it arrives at the settled clock and never moves it.
	protocol.handle_message(player, tap, 0)
