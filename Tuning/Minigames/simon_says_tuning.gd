class_name SimonSaysTuning
extends Resource
## One front door for the Simon Says values that exist today. Changes apply after relaunch.

@export_group("Gameplay and timing")
## Shared-screen countdown before dancing begins, in seconds. Higher gives players more preparation; lower starts faster. Default: 3.0. Safe range: 0-10.
@export_range(0.0, 10.0, 0.25, "suffix:s")
var countdown_seconds: float = 3.0:
	set(value): countdown_seconds = clampf(value, 0.0, 10.0)
## Maximum dancing-round duration after the countdown, in seconds. Higher permits more stops; lower ends sooner. Default: 60. Safe range: 10-300.
@export_range(10.0, 300.0, 1.0, "suffix:s")
var round_duration_seconds: float = 60.0:
	set(value): round_duration_seconds = clampf(value, 10.0, 300.0)
## Earliest initial music stop, in seconds. Higher gives longer dance stretches; lower increases pressure. Default: 4.0. Safe range: 0.5-15.
@export_range(0.5, 15.0, 0.1, "suffix:s")
var stop_interval_min_seconds: float = 4.0:
	set(value): stop_interval_min_seconds = clampf(value, 0.5, 15.0)
## Latest initial music stop, in seconds. Higher makes stops less predictable; lower tightens pacing. Default: 7.0. Safe range: 0.5-20.
@export_range(0.5, 20.0, 0.1, "suffix:s")
var stop_interval_max_seconds: float = 7.0:
	set(value): stop_interval_max_seconds = clampf(value, 0.5, 20.0)
## Interval reduction after each resolved stop, in seconds. Higher ramps pressure faster; lower changes pacing gradually. Default: 0.25. Safe range: 0-2.
@export_range(0.0, 2.0, 0.05, "suffix:s")
var stop_interval_reduction_seconds: float = 0.25:
	set(value): stop_interval_reduction_seconds = clampf(value, 0.0, 2.0)
## Elapsed round time that unlocks the Down pose, in seconds. Lower introduces three choices sooner. Default: 15. Safe range: 0-300.
@export_range(0.0, 300.0, 1.0, "suffix:s")
var down_unlock_seconds: float = 15.0:
	set(value): down_unlock_seconds = clampf(value, 0.0, 300.0)
## Elapsed round time that unlocks the Up pose, in seconds. Lower introduces all four choices sooner. Default: 30. Safe range: 0-300.
@export_range(0.0, 300.0, 1.0, "suffix:s")
var up_unlock_seconds: float = 30.0:
	set(value): up_unlock_seconds = clampf(value, 0.0, 300.0)
## Time to reach a committed command pose, in seconds. Higher feels more deliberate; lower feels more responsive. Default: 1.0. Safe range: 0.1-3.0.
@export_range(0.1, 3.0, 0.05, "suffix:s")
var charge_fill_seconds: float = 1.0:
	set(value): charge_fill_seconds = clampf(value, 0.1, 3.0)
## Time for a released pose charge to return to zero, in seconds. Higher preserves progress longer; lower unwinds faster. Default: 0.28. Safe range: 0.05-1.0.
@export_range(0.05, 1.0, 0.01, "suffix:s")
var charge_decay_seconds: float = 0.28:
	set(value): charge_decay_seconds = clampf(value, 0.05, 1.0)
## Delay from the audible full stop until the command pose is revealed. Higher adds suspense but shortens no other timer; lower reveals sooner. Default: 0.0. Safe range: 0-0.5.
@export_range(0.0, 0.5, 0.01, "suffix:s")
var pose_reveal_delay_seconds: float = 0.0:
	set(value): pose_reveal_delay_seconds = clampf(value, 0.0, 0.5)
## Time from pose reveal until authoritative evaluation. Higher is more forgiving; lower is harder. Default: 1.2. Safe range: 0.2-3.0.
@export_range(0.2, 3.0, 0.05, "suffix:s")
var pose_grace_seconds: float = 1.2:
	set(value): pose_grace_seconds = clampf(value, 0.2, 3.0)

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

@export_group("Shared-screen feedback")
## Camera-flash fade duration after authoritative resolution. Higher lingers longer; lower is snappier. Provisional default: 0.22. Safe range: 0.08-0.6.
@export_range(0.08, 0.6, 0.01, "suffix:s")
var flash_duration_seconds: float = 0.22:
	set(value): flash_duration_seconds = clampf(value, 0.08, 0.6)
## Peak opacity of the code-native camera flash. Higher is brighter; lower preserves more scene detail. Provisional default: 0.78. Safe range: 0.2-1.0.
@export_range(0.2, 1.0, 0.01)
var flash_intensity: float = 0.78:
	set(value): flash_intensity = clampf(value, 0.2, 1.0)
## Music playback level. Provisional until PS-029 listening review. Default: -8 dB. Safe range: -30 to 0.
@export_range(-30.0, 0.0, 0.5, "suffix:dB")
var music_gain_db: float = -8.0:
	set(value): music_gain_db = clampf(value, -30.0, 0.0)
## Flash SFX level. Provisional until PS-029 listening review. Default: -5 dB. Safe range: -30 to 0.
@export_range(-30.0, 0.0, 0.5, "suffix:dB")
var flash_sfx_gain_db: float = -5.0:
	set(value): flash_sfx_gain_db = clampf(value, -30.0, 0.0)
## Music fade after the flash completes. Zero resumes immediately. Provisional default: 0.12. Safe range: 0-1.
@export_range(0.0, 1.0, 0.01, "suffix:s")
var music_resume_fade_seconds: float = 0.12:
	set(value): music_resume_fade_seconds = clampf(value, 0.0, 1.0)

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
	if stop_interval_min_seconds > stop_interval_max_seconds:
		errors.append("Simon Says: Minimum stop interval must not exceed the maximum stop interval.")
	if down_unlock_seconds > up_unlock_seconds:
		errors.append("Simon Says: Down must unlock no later than Up so difficulty progresses from two to four poses.")
	if up_unlock_seconds > round_duration_seconds:
		errors.append("Simon Says: Up unlock must occur within the round duration.")
	if auto_release_seconds < charge_decay_seconds:
		errors.append("Simon Says: Auto release (%.2fs) must be at least charge decay (%.2fs) so the preview can fully unwind." % [auto_release_seconds, charge_decay_seconds])
	return errors
