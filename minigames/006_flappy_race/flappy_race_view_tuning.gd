@tool
class_name FlappyRaceViewTuning
extends Resource
## How a Flappy Race looks and feels on the phone and the shared screen. Presentation only: no
## value here changes a flight. The phone receives [method to_dictionary] in its snapshot.

@export_group("Cubio")
## Nose-up tilt at the flap velocity, degrees. Default: 25.
@export_range(0.0, 90.0, 1.0, "suffix:°") var tilt_up_degrees: float = 25.0
## Nose-down tilt at the fastest fall, degrees. Default: 70.
@export_range(0.0, 90.0, 1.0, "suffix:°") var tilt_down_degrees: float = 70.0
## How quickly the tilt follows the vertical speed, s. Default: 0.08.
@export_range(0.0, 1.0, 0.01, "suffix:s") var tilt_response_seconds: float = 0.08
## The dizzy tumble at the hit spot before the Cubio leaves play, s. Default: 0.6.
@export_range(0.0, 3.0, 0.05, "suffix:s") var hit_tumble_seconds: float = 0.6
## How long the beaming face lasts after a pickup, s. Default: 0.6.
@export_range(0.0, 3.0, 0.05, "suffix:s") var pickup_face_seconds: float = 0.6

@export_group("Phone")
## Where the phone keeps its Cubio, as a share of the screen width from the left. Default: 0.3.
@export_range(0.05, 0.95, 0.01) var phone_cubio_screen_share: float = 0.3
## Time a host correction takes to blend out of the drawn position, s. Default: 0.12.
@export_range(0.0, 1.0, 0.01, "suffix:s") var correction_seconds: float = 0.12
## Time the spent heart takes to fly from the row to the respawn spot, s. Default: 0.6.
@export_range(0.05, 3.0, 0.05, "suffix:s") var heart_flight_seconds: float = 0.6


func to_dictionary() -> Dictionary:
	return {
		"tilt_up_degrees": tilt_up_degrees,
		"tilt_down_degrees": tilt_down_degrees,
		"tilt_response_seconds": tilt_response_seconds,
		"hit_tumble_seconds": hit_tumble_seconds,
		"pickup_face_seconds": pickup_face_seconds,
		"phone_cubio_screen_share": phone_cubio_screen_share,
		"correction_seconds": correction_seconds,
		"heart_flight_seconds": heart_flight_seconds,
	}


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var tilts := [tilt_up_degrees, tilt_down_degrees]
	if tilts.any(
		func(value: float) -> bool:
			return value < 0.0 or value > 90.0,
	):
		errors.append("Flappy Race view: tilts must lie between 0 and 90 degrees.")
	var durations := [
		tilt_response_seconds,
		hit_tumble_seconds,
		pickup_face_seconds,
		correction_seconds,
	]
	if durations.any(
		func(value: float) -> bool:
			return value < 0.0,
	):
		errors.append("Flappy Race view: durations cannot be negative.")
	if heart_flight_seconds <= 0.0:
		errors.append("Flappy Race view: the heart flight must take some time.")
	if phone_cubio_screen_share <= 0.0 or phone_cubio_screen_share >= 1.0:
		errors.append("Flappy Race view: the phone's Cubio must sit inside the screen.")
	return errors
