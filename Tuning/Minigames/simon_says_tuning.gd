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
## Multiplier for body jiggle layered over authored poses. Higher feels looser; lower keeps silhouettes steadier. Default: 1.0. Safe range: 0-2.
@export_range(0.0, 2.0, 0.05)
var secondary_motion_strength: float = 1.0:
	set(value): secondary_motion_strength = clampf(value, 0.0, 2.0)
## Lead-dancer motion emphasis multiplier. Higher makes the lead broader than players. Default: 1.16. Safe range: 1-1.5.
@export_range(1.0, 1.5, 0.01)
var lead_emphasis: float = 1.16:
	set(value): lead_emphasis = clampf(value, 1.0, 1.5)
## Duration of life-loss and survival reactions, in seconds. Higher is more theatrical; lower returns to dance sooner. Default: 0.7. Safe range: 0.25-2.
@export_range(0.25, 2.0, 0.05, "suffix:s")
var reaction_seconds: float = 0.7:
	set(value): reaction_seconds = clampf(value, 0.25, 2.0)
## Duration of one happy or moody results cycle, in seconds. Higher feels calmer; lower feels busier. Default: 1.8. Safe range: 0.5-4.
@export_range(0.5, 4.0, 0.1, "suffix:s")
var result_cycle_seconds: float = 1.8:
	set(value): result_cycle_seconds = clampf(value, 0.5, 4.0)
## Time a lead dancer flows through a command pose while music continues, in seconds. Higher makes poses more explicit; lower keeps dance continuity. Default: 0.45. Safe range: 0.2-1.5.
@export_range(0.2, 1.5, 0.05, "suffix:s")
var pose_flow_hold_seconds: float = 0.45:
	set(value): pose_flow_hold_seconds = clampf(value, 0.2, 1.5)

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
