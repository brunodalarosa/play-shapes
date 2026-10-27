@tool
class_name FlappyFlightTuning
extends Resource
## The flappy shape gameplay values, in metres and seconds. Cubio's 2 m body stands for Flappy
## Bird's height in the reference values. The phone runs the same rules from these values, so
## [method to_dictionary] is what it receives.

## The fixed simulation rate shared by the host and the phone (decision 0047).
const TICK_RATE := 60
const TICK := 1.0 / TICK_RATE
## Cubio's body cube, metres. Hands, feet and the face never collide.
const BODY_SIZE := 2.0

## Constant forward speed, m/s. Default: 10, five body heights per second.
@export_range(1.0, 40.0, 0.1, "suffix:m/s") var forward_speed: float = 10.0
## Upward speed a tap sets, replacing the current vertical speed, m/s. Default: 22.5.
@export_range(1.0, 60.0, 0.1, "suffix:m/s") var flap_velocity: float = 22.5
## Downward acceleration, m/s². Default: 75.
@export_range(1.0, 200.0, 0.5, "suffix:m/s²") var gravity: float = 75.0
## Fastest fall, m/s. Default: 25.
@export_range(1.0, 80.0, 0.5, "suffix:m/s") var max_fall_speed: float = 25.0
## How far the hit box sits inside the visible body cube on every side, m. Default: 0.2.
@export_range(0.0, 0.8, 0.01, "suffix:m") var hit_box_inset: float = 0.2

@export_group("Hearts")
## Hearts in the row, each a spare respawn. Default: 3.
@export_range(1, 10, 1) var heart_count: int = 3
## Time to refill one heart; one refills at a time, s. Default: 10.
@export_range(0.5, 60.0, 0.5, "suffix:s") var heart_recovery_seconds: float = 10.0
## Time from a hit before the floating heart can be tapped, s. Default: 2.
@export_range(0.0, 10.0, 0.1, "suffix:s") var respawn_cooldown_seconds: float = 2.0
## Time after a respawn when obstacles and the ground cost no heart, s. Default: 1.
@export_range(0.0, 5.0, 0.1, "suffix:s") var invulnerable_seconds: float = 1.0

@export_group("Speed pickups")
## Extra forward speed while boosted, as a share of the forward speed. Default: 0.25.
@export_range(0.0, 2.0, 0.05) var boost_share: float = 0.25
## Boost time; another pickup restarts it, s. Default: 3.
@export_range(0.1, 10.0, 0.1, "suffix:s") var boost_seconds: float = 3.0


## Converts [param seconds] to whole simulation ticks, as the phone does.
static func ticks(seconds: float) -> int:
	return roundi(seconds * TICK_RATE)


## Half the hit box's side, metres.
func hit_half() -> float:
	return BODY_SIZE * 0.5 - hit_box_inset


func boosted_speed() -> float:
	return forward_speed * (1.0 + boost_share)


func to_dictionary() -> Dictionary:
	return {
		"forward_speed": forward_speed,
		"flap_velocity": flap_velocity,
		"gravity": gravity,
		"max_fall_speed": max_fall_speed,
		"hit_box_inset": hit_box_inset,
		"heart_count": heart_count,
		"heart_recovery_ticks": ticks(heart_recovery_seconds),
		"respawn_cooldown_ticks": ticks(respawn_cooldown_seconds),
		"invulnerable_ticks": ticks(invulnerable_seconds),
		"boost_share": boost_share,
		"boost_ticks": ticks(boost_seconds),
	}


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var positive := [forward_speed, flap_velocity, gravity, max_fall_speed, boost_seconds]
	for value: float in positive:
		if not is_finite(value) or value <= 0.0:
			errors.append("Flappy flight: speeds, gravity and the boost time must be positive.")
			break

	if hit_box_inset < 0.0 or hit_box_inset >= BODY_SIZE * 0.5:
		errors.append("Flappy flight: the hit box inset must leave a hit box.")
	if heart_count < 1:
		errors.append("Flappy flight: a player needs at least one heart.")
	if ticks(heart_recovery_seconds) < 1:
		errors.append("Flappy flight: a heart must take at least one tick to refill.")
	if respawn_cooldown_seconds < 0.0 or invulnerable_seconds < 0.0 or boost_share < 0.0:
		errors.append("Flappy flight: cooldown, invulnerability and boost cannot be negative.")
	return errors
