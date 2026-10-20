@tool
class_name TiltShift3DPresentationTuning
extends Resource
## How the factory looks. Nothing here changes a collider, a score or a phone message's rate;
## the paddle's size and the floor come from the physics and layout Resources.

@export_group("Paddles")
## Cream gap ring around a player paddle's front outline, as a share of its thickness.
@export_range(0.0, 0.3, 0.005) var gap_ratio: float = 0.06
## Team outline outside the gap ring, as a share of the paddle's thickness.
@export_range(0.0, 0.3, 0.005) var outline_ratio: float = 0.09
@export_color_no_alpha var gap_color: Color = Color("fff3dc")
@export_color_no_alpha var orange_outline_color: Color = Color("fd8702")
@export_color_no_alpha var blue_outline_color: Color = Color("0144f2")
## The automatic paddle's body and its outline; it has no gap ring and no face.
@export_color_no_alpha var neutral_body_color: Color = Color("a0a0a0")
@export_color_no_alpha var neutral_outline_color: Color = Color("707070")
## Face height as a share of the paddle's thickness. The length never stretches it.
@export_range(0.2, 1.0, 0.01) var face_height_ratio: float = 0.72

@export_group("Names")
## Seconds a player's name shows above their paddles after each round's START.
@export_range(0.0, 30.0, 0.1, "suffix:s") var name_seconds: float = 5.0
## Seconds the name takes to fade out afterwards.
@export_range(0.0, 5.0, 0.05, "suffix:s") var name_fade_seconds: float = 0.6
@export_range(14, 48, 1) var name_font_size: int = 24

@export_group("Balls and bins")
@export_color_no_alpha var ball_color: Color = Color("f4e6ad")
@export_color_no_alpha var orange_bin_color: Color = Color("fd5d14")
@export_color_no_alpha var blue_bin_color: Color = Color("0055fa")
@export_color_no_alpha var trash_bin_color: Color = Color("ac9992")
## Seconds of gentle bin brightening after an accepted catch.
@export_range(0.1, 0.6, 0.05) var catch_feedback_seconds: float = 0.25

@export_group("Factory")
@export_color_no_alpha var wall_top_color: Color = Color("fbf3e2")
@export_color_no_alpha var wall_bottom_color: Color = Color("efdfc2")
@export_color_no_alpha var prop_teal_color: Color = Color("9ed3d0")
@export_color_no_alpha var prop_sky_color: Color = Color("a9cbea")
@export_color_no_alpha var prop_grey_color: Color = Color("c9c2ba")
## Vertical field of view of the fixed camera, which frames the whole arena.
@export_range(15.0, 60.0, 0.5, "suffix:degrees") var camera_fov: float = 30.0
## Score and clock font size on a 1080-pixel-tall screen.
@export_range(18, 64, 1) var hud_font_size: int = 40


func validation_errors() -> PackedStringArray:
	var limits := {
		"gap_ratio": [0.0, 0.3],
		"outline_ratio": [0.0, 0.3],
		"face_height_ratio": [0.2, 1.0],
		"name_seconds": [0.0, 30.0],
		"name_fade_seconds": [0.0, 5.0],
		"name_font_size": [14, 48],
		"catch_feedback_seconds": [0.1, 0.6],
		"camera_fov": [15.0, 60.0],
		"hud_font_size": [18, 64],
	}
	var errors := PackedStringArray()
	for field: String in limits:
		var value := float(get(field))
		var bounds: Array = limits[field]
		if not is_finite(value) or value < float(bounds[0]) or value > float(bounds[1]):
			errors.append(
				"Tilt Shift 3D presentation: %s must be finite and between %s and %s."
				% [field.capitalize(), bounds[0], bounds[1]],
			)
	return errors


## The outline colour of a team's paddles.
func outline_color(team: int) -> Color:
	return [orange_outline_color, blue_outline_color, neutral_outline_color][clampi(team, 0, 2)]


## The colour of a team's bins, or the trash bins'.
func bin_color(team: int) -> Color:
	return [orange_bin_color, blue_bin_color, trash_bin_color][clampi(team, 0, 2)]
