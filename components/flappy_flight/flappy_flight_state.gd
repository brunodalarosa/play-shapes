class_name FlappyFlightState
extends RefCounted
## One player's flight, changed only by [method FlappyFlight.step]. Every field is a plain
## 64-bit float or an integer, never a Vector2, which holds 32-bit floats (decision 0047).

## Body centre, metres along the course and above the ground. While waiting, the respawn spot.
var x := 0.0
var y := 0.0
var vertical_speed := 0.0
## False from a hit until the respawn tap.
var flying := true
## Waiting and allowed to respawn: the cooldown is over and no heart is owed.
var ready := false
var cooldown_ticks := 0
var invulnerable_ticks := 0
var boost_ticks := 0
## The first obstacle the hit box has not yet passed.
var obstacle_index := 0
var hearts: HeartRow
## One byte per course pickup, 1 once this player has taken it.
var taken := PackedByteArray()


func copy_from(other: FlappyFlightState) -> void:
	x = other.x
	y = other.y
	vertical_speed = other.vertical_speed
	flying = other.flying
	ready = other.ready
	cooldown_ticks = other.cooldown_ticks
	invulnerable_ticks = other.invulnerable_ticks
	boost_ticks = other.boost_ticks
	obstacle_index = other.obstacle_index
	if hearts == null:
		hearts = HeartRow.new(other.hearts.count, other.hearts.recovery_ticks)
	hearts.copy_from(other.hearts)
	taken = other.taken.duplicate()


func copy() -> FlappyFlightState:
	var state := FlappyFlightState.new()
	state.copy_from(self)
	return state
