@tool
class_name TiltShiftPresentationTuning
extends Resource
## Cosmetic world units; camera fitting does not rescale physics bodies.

## Width reserved on each side for rails and up to five operator stations.
@export_range(80.0, 180.0, 1.0) var side_width: float = 105.0
## Station base width in world units, independent of the collider layout.
@export_range(55.0, 100.0, 1.0) var station_width: float = 80.0
## Width of the untrimmed Squircle tile in world units.
@export_range(64.0, 120.0, 1.0) var character_size: float = 90.0
## Uniform basket end-cap/height scale; center widths follow the scoring openings.
@export_range(0.12, 0.4, 0.01) var basket_scale: float = 0.24
## Paddle ownership badge width in world units.
@export_range(16.0, 32.0, 1.0) var player_badge_size: float = 24.0
## Accepted full paddle turns per authored loop. This never controls physics.
@export_range(0.25, 2.0, 0.25) var turns_per_loop: float = 1.0
## Seconds of gentle basket brightening after an accepted catch.
@export_range(0.1, 0.6, 0.05) var catch_feedback_seconds: float = 0.25
## Score and clock font size before camera fitting.
@export_range(18, 36, 1) var hud_font_size: int = 26


func validation_errors() -> PackedStringArray:
	var limits := {
		"side_width": [80, 180],
		"station_width": [55, 100],
		"character_size": [64, 120],
		"basket_scale": [0.12, 0.4],
		"player_badge_size": [16, 32],
		"turns_per_loop": [0.25, 2],
		"catch_feedback_seconds": [0.1, 0.6],
		"hud_font_size": [18, 36],
	}
	var errors := PackedStringArray()
	for field: String in limits:
		var value := float(get(field))
		var bounds: Array = limits[field]
		if not is_finite(value) or value < float(bounds[0]) or value > float(bounds[1]):
			errors.append(
				"Factory presentation: %s must be finite and between %s and %s."
				% [field.capitalize(), bounds[0], bounds[1]],
			)
	return errors
