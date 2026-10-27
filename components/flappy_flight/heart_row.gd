class_name HeartRow
extends RefCounted
## A row of hearts, each a spare respawn, counted in simulation ticks.
##
## Full hearts are always the leftmost ones, so the leftmost empty heart is the one at index
## [member full]. Only it refills. A hit spends the rightmost full heart, which makes the heart
## that was refilling no longer the leftmost empty one: its progress simply stays in
## [member refill_ticks] and now belongs to the new leftmost empty heart. A hit with no full
## heart leaves a heart [member owed], spent as soon as the next refill completes.

var count := 0
var full := 0
## Ticks of progress on the leftmost empty heart.
var refill_ticks := 0
var owed := false
var recovery_ticks := 0


func _init(heart_count: int, heart_recovery_ticks: int) -> void:
	count = heart_count
	full = heart_count
	recovery_ticks = heart_recovery_ticks


## Advances the refill by one tick. Returns true when a heart finished refilling, whether it
## joined the row or was spent on an owed respawn.
func tick() -> bool:
	if full >= count:
		return false

	refill_ticks += 1
	if refill_ticks < recovery_ticks:
		return false

	refill_ticks = 0
	if owed:
		owed = false
	else:
		full += 1
	return true


func hit() -> void:
	if full > 0:
		full -= 1
	else:
		owed = true


## How far the leftmost empty heart has refilled, 0 to 1.
func refill_share() -> float:
	return float(refill_ticks) / recovery_ticks


## What changes during a run; the phone already has the count and the recovery time.
func to_dictionary() -> Dictionary:
	return { "full": full, "refill_ticks": refill_ticks, "owed": owed }


func copy_from(other: HeartRow) -> void:
	count = other.count
	full = other.full
	refill_ticks = other.refill_ticks
	owed = other.owed
	recovery_ticks = other.recovery_ticks
