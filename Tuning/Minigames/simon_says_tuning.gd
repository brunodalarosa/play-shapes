class_name SimonSaysTuning
extends Resource
## One front door for the Simon Says values that exist today. Changes apply after relaunch.

@export_group("Gameplay and timing")
## Time to reach a committed command pose, in seconds. Higher feels more deliberate; lower feels more responsive. Default: 1.0. Safe range: 0.1-3.0.
@export_range(0.1, 3.0, 0.05, "suffix:s")
var charge_fill_seconds: float = 1.0:
	set(value): charge_fill_seconds = clampf(value, 0.1, 3.0)
## Time for a released pose charge to return to zero, in seconds. Higher preserves progress longer; lower unwinds faster. Default: 0.28. Safe range: 0.05-1.0.
@export_range(0.05, 1.0, 0.01, "suffix:s")
var charge_decay_seconds: float = 0.28:
	set(value): charge_decay_seconds = clampf(value, 0.05, 1.0)

@export_group("Animation and motion")
## Dance tempo, in beats per second. Higher is more energetic; lower is calmer. Default: 1.7. Safe range: 0.1-3.0.
@export_range(0.1, 3.0, 0.05, "suffix: beats/s")
var dance_beats_per_second: float = 1.7:
	set(value): dance_beats_per_second = clampf(value, 0.1, 3.0)
## Maximum vertical body travel, in screen world units. Higher is springier; lower is steadier. Default: 6. Safe range: 0-16.
@export_range(0.0, 16.0, 0.5, "suffix: px")
var body_bounce: float = 6.0:
	set(value): body_bounce = clampf(value, 0.0, 16.0)
## Maximum body rotation during dance, in degrees. Higher is looser; lower is more upright. Default: 4. Safe range: 0-12.
@export_range(0.0, 12.0, 0.5, "suffix:°")
var body_jiggle_degrees: float = 4.0:
	set(value): body_jiggle_degrees = clampf(value, 0.0, 12.0)
## Maximum horizontal body travel, in screen world units. Higher is broader; lower is more centered. Default: 7. Safe range: 0-16.
@export_range(0.0, 16.0, 0.5, "suffix: px")
var body_sway: float = 7.0:
	set(value): body_sway = clampf(value, 0.0, 16.0)
## Visual charge-follow rate, in normalized charge per second. Higher snaps toward input; lower eases more visibly. Default: 12. Safe range: 1-30.
@export_range(1.0, 30.0, 0.5, "suffix: charge/s")
var visual_follow_speed: float = 12.0:
	set(value): visual_follow_speed = clampf(value, 1.0, 30.0)

@export_group("Debug preview only")
## Time the automatic lab keeps a fully charged pose, in seconds. Higher makes inspection easier; lower cycles faster. Default: 1.5. Safe range: 0.5-5.0.
@export_range(0.5, 5.0, 0.1, "suffix:s")
var auto_hold_seconds: float = 1.5:
	set(value): auto_hold_seconds = clampf(value, 0.5, 5.0)
## Time the automatic lab allows for release, in seconds. Higher shows more unwind; lower advances sooner. Default: 0.7. Safe range: 0.1-2.0.
@export_range(0.1, 2.0, 0.1, "suffix:s")
var auto_release_seconds: float = 0.7:
	set(value): auto_release_seconds = clampf(value, 0.1, 2.0)

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if auto_release_seconds < charge_decay_seconds:
		errors.append("Simon Says: Auto release (%.2fs) must be at least charge decay (%.2fs) so the preview can fully unwind." % [auto_release_seconds, charge_decay_seconds])
	return errors
