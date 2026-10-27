class_name FlappyRaceRacer
extends RefCounted
## One player in a Flappy Race, owned by [FlappyRaceController]. The flight changes only
## through the shared step; the rest is the race around it.

var player_id := ""
var display_name := ""
var character_color := ""
var seat := 0
var state: FlappyFlightState
## The ticks this player's taps apply at, waiting for the settled simulation to reach them.
## Every key lies inside the tap window, so it never holds more than the window's ticks.
var taps: Dictionary[int, bool] = { }
var last_seq := -1
## A disconnected player's flight is frozen until they resume.
var connected := true
## Gone for good, by an expired grace or a leave, before finishing.
var dnf := false
## The settled tick the body centre crossed the finish line in; -1 before that.
var finish_tick := -1
## Finish order, 1 for the first to cross; 0 before finishing.
var place := 0
## Orders exact ties at random, drawn from the race seed (decision 0050).
var tie_break := 0.0
## The pickups already reported, to tell which one a pickup event took.
var reported_taken := PackedByteArray()


func finished() -> bool:
	return finish_tick >= 0


## Still stepped by the race: connected, not finished and not gone.
func racing() -> bool:
	return connected and not dnf and not finished()


## How far along the course the player is; a waiting player counts at the respawn spot.
func distance() -> float:
	return state.x


## Marks and returns the index of the pickup taken since the last call, or -1.
func newly_taken() -> int:
	for index: int in state.taken.size():
		if state.taken[index] != reported_taken[index]:
			reported_taken[index] = state.taken[index]
			return index
	return -1
