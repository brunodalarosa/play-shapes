@tool
class_name FlappyRaceViewTuning
extends Resource
## How a Flappy Race looks and feels on the phone and the shared screen. Presentation only: no
## value here changes a flight. The phone receives [method to_dictionary] in its snapshot; the
## shared-screen values stay on the host.

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

@export_group("Shared screen")
## Where the camera keeps the leader, as a share of the width from the left. Default: 0.65.
@export_range(0.05, 0.95, 0.01) var leader_screen_share: float = 0.65
## Visible height at the furthest zoom, m. Default: 54, about 40 px of body at 1080p.
@export_range(10.0, 200.0, 1.0, "suffix:m") var farthest_visible_height: float = 54.0
## Time the camera takes to settle most of the way to a new framing, s. Default: 0.4.
@export_range(0.0, 3.0, 0.05, "suffix:s") var camera_smoothing_seconds: float = 0.4
## Names show over every Cubio this long after GO, s. Default: 5.
@export_range(0.0, 30.0, 0.5, "suffix:s") var name_seconds: float = 5.0
## Then fade out over this long, s. Default: 0.6.
@export_range(0.0, 5.0, 0.1, "suffix:s") var name_fade_seconds: float = 0.6
## Depth between neighbouring players' slots on the plane, m. Default: 0.05.
@export_range(0.0, 1.0, 0.01, "suffix:m") var depth_slot: float = 0.05
## Share of a Cubio left out while it covers another (decision 0051). Default: 0.5.
@export_range(0.0, 1.0, 0.05) var overlap_dither: float = 0.5
## How long a pickup burst lasts, s. Default: 0.5.
@export_range(0.05, 3.0, 0.05, "suffix:s") var burst_seconds: float = 0.5


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
	if leader_screen_share <= 0.0 or leader_screen_share >= 1.0:
		errors.append("Flappy Race view: the leader must sit inside the shared screen.")
	var shared := [camera_smoothing_seconds, name_seconds, name_fade_seconds, depth_slot]
	if shared.any(
		func(value: float) -> bool:
			return value < 0.0,
	):
		errors.append(
			"Flappy Race view: shared-screen times and the depth slot cannot be negative."
		)
	if overlap_dither < 0.0 or overlap_dither > 1.0 or burst_seconds <= 0.0:
		errors.append("Flappy Race view: the dither is a share, and a burst must take some time.")
	return errors
