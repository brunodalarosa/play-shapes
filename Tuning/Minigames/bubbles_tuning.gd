class_name BubblesTuning
extends Resource
## Provisional Bubbles and jellyfishes values. Save a named preset and relaunch to compare feel.

@export_group("Round lifecycle")
## Minimum instruction and entrance time, in seconds. Higher allows more reading; lower starts sooner. Default: 3. Safe range: 0-15.
@export_range(0.0, 15.0, 0.25, "suffix:s")
var instructions_seconds: float = 3.0:
	set(value): instructions_seconds = clampf(value, 0.0, 15.0)
## Countdown after the entrance is acknowledged, in seconds. Higher gives more preparation; lower starts sooner. Default: 3. Safe range: 0-10.
@export_range(0.0, 10.0, 0.25, "suffix:s")
var countdown_seconds: float = 3.0:
	set(value): countdown_seconds = clampf(value, 0.0, 10.0)
## Active round duration, in seconds. Higher allows more collecting; lower makes each catch matter more. Default: 90. Safe range: 10-300.
@export_range(10.0, 300.0, 1.0, "suffix:s")
var round_duration_seconds: float = 90.0:
	set(value): round_duration_seconds = clampf(value, 10.0, 300.0)

@export_group("Player bubble")
## Initial bubble radius, in world pixels. Higher begins with more reach and hazard exposure. Default: 48. Safe range: 16-160.
@export_range(16.0, 160.0, 1.0, "suffix:px")
var starting_radius: float = 48.0:
	set(value): starting_radius = clampf(value, 16.0, 160.0)
## Largest visual/collision radius, in world pixels. Higher permits more reach and exposure. Default: 110. Safe range: 32-240; must exceed starting radius.
@export_range(32.0, 240.0, 1.0, "suffix:px")
var max_radius: float = 110.0:
	set(value): max_radius = clampf(value, 32.0, 240.0)
## Radius gained for each captured jellyfish, in world pixels. Higher grows faster; lower delays growth. Default: 2. Safe range: 0.1-10.
@export_range(0.1, 10.0, 0.1, "suffix:px")
var radius_per_jellyfish: float = 2.0:
	set(value): radius_per_jellyfish = clampf(value, 0.1, 10.0)
## Maximum captured jellyfish sprites shown inside a bubble. Higher shows more detail; lower reduces clutter. Scores remain uncapped. Default: 12. Safe range: 0-40.
@export_range(0, 40, 1)
var captured_visual_cap: int = 12:
	set(value): captured_visual_cap = clampi(value, 0, 40)
## Extra mass per jellyfish as a fraction of base mass. Higher makes large bubbles harder to shove. Default: 0.025. Safe range: 0-0.2.
@export_range(0.0, 0.2, 0.005)
var mass_growth_per_jellyfish: float = 0.025:
	set(value): mass_growth_per_jellyfish = clampf(value, 0.0, 0.2)
## Fractional speed reduction per jellyfish, before the physics cap. Higher slows large bubbles more. Default: 0.01. Safe range: 0-0.1.
@export_range(0.0, 0.1, 0.002)
var speed_reduction_per_jellyfish: float = 0.01:
	set(value): speed_reduction_per_jellyfish = clampf(value, 0.0, 0.1)

@export_group("Movement and gestures")
## Fixed swipe impulse, in world pixels per second. Higher makes each swipe stronger. Default: 280. Safe range: 20-1000.
@export_range(20.0, 1000.0, 5.0, "suffix:px/s")
var swipe_impulse: float = 280.0:
	set(value): swipe_impulse = clampf(value, 20.0, 1000.0)
## Minimum normalized net swipe distance. Higher requires a longer swipe; lower accepts smaller gestures. Default: 0.07. Safe range: 0.02-0.3.
@export_range(0.02, 0.3, 0.005)
var swipe_min_distance: float = 0.07:
	set(value): swipe_min_distance = clampf(value, 0.02, 0.3)
## Bubble speed cap, in world pixels per second. Higher permits faster travel. Default: 460. Safe range: 50-1200.
@export_range(50.0, 1200.0, 10.0, "suffix:px/s")
var max_player_speed: float = 460.0:
	set(value): max_player_speed = clampf(value, 50.0, 1200.0)
## Water drag per second. Higher slows unattended bubbles sooner. Default: 1.8. Safe range: 0-8.
@export_range(0.0, 8.0, 0.1, "suffix:/s")
var water_drag: float = 1.8:
	set(value): water_drag = clampf(value, 0.0, 8.0)
## Wall bounce multiplier. Higher rebounds more strongly; zero stops at the wall. Default: 0.65. Safe range: 0-1.
@export_range(0.0, 1.0, 0.01)
var wall_bounciness: float = 0.65:
	set(value): wall_bounciness = clampf(value, 0.0, 1.0)
## Complete circles needed in one touch to charge spin. Higher asks for more deliberate drawing. Default: 2. Safe range: 1-4.
@export_range(1, 4, 1)
var circles_to_charge: int = 2:
	set(value): circles_to_charge = clampi(value, 1, 4)
## Allowed radial variation and end gap as a fraction of circle radius. Higher accepts rougher circles. Default: 0.4. Safe range: 0.2-0.7.
@export_range(0.2, 0.7, 0.01)
var circle_tolerance: float = 0.4:
	set(value): circle_tolerance = clampf(value, 0.2, 0.7)
## Active spin duration, in seconds. Higher extends the shove advantage. Default: 1.5. Safe range: 0.2-5.
@export_range(0.2, 5.0, 0.1, "suffix:s")
var spin_duration_seconds: float = 1.5:
	set(value): spin_duration_seconds = clampf(value, 0.2, 5.0)
## Spin cooldown after activation, in seconds. Higher spaces out spins. Default: 5. Safe range: 0-20.
@export_range(0.0, 20.0, 0.25, "suffix:s")
var spin_cooldown_seconds: float = 5.0:
	set(value): spin_cooldown_seconds = clampf(value, 0.0, 20.0)
## Additional shove impulse against another player while spinning, in world pixels per second. Higher pushes opponents farther. Default: 250. Safe range: 0-1000.
@export_range(0.0, 1000.0, 5.0, "suffix:px/s")
var spin_shove_impulse: float = 250.0:
	set(value): spin_shove_impulse = clampf(value, 0.0, 1000.0)

@export_group("Jellyfish")
## Jellyfish collision radius, in world pixels. Higher makes collection easier. Default: 14. Safe range: 4-60.
@export_range(4.0, 60.0, 1.0, "suffix:px")
var jellyfish_collider_radius: float = 14.0:
	set(value): jellyfish_collider_radius = clampf(value, 4.0, 60.0)
## Initial free jellyfish population at GO. Higher gives earlier opportunities. Default: 20. Safe range: 0-100; cannot exceed free cap.
@export_range(0, 100, 1)
var starting_jellyfish: int = 20:
	set(value): starting_jellyfish = clampi(value, 0, 100)
## Maximum free jellyfish in the arena. Higher makes collection busier. Default: 70. Safe range: 1-200.
@export_range(1, 200, 1)
var max_free_jellyfish: int = 70:
	set(value): max_free_jellyfish = clampi(value, 1, 200)
## Low-wave spawn rate, in jellyfish per second. Higher keeps quiet periods busy. Default: 0.5. Safe range: 0-10.
@export_range(0.0, 10.0, 0.1, "suffix:/s")
var jellyfish_low_spawn_rate: float = 0.5:
	set(value): jellyfish_low_spawn_rate = clampf(value, 0.0, 10.0)
## High-wave spawn rate, in jellyfish per second. Higher creates denser scoring bursts. Default: 2. Safe range: 0-15; at least low rate.
@export_range(0.0, 15.0, 0.1, "suffix:/s")
var jellyfish_high_spawn_rate: float = 2.0:
	set(value): jellyfish_high_spawn_rate = clampf(value, 0.0, 15.0)
## Shortest jellyfish wave, in seconds. Higher stretches every wave. Default: 4. Safe range: 1-30.
@export_range(1.0, 30.0, 0.5, "suffix:s")
var jellyfish_wave_min_seconds: float = 4.0:
	set(value): jellyfish_wave_min_seconds = clampf(value, 1.0, 30.0)
## Longest jellyfish wave, in seconds. Higher allows longer unpredictable bursts. Default: 9. Safe range: 1-45; at least shortest wave.
@export_range(1.0, 45.0, 0.5, "suffix:s")
var jellyfish_wave_max_seconds: float = 9.0:
	set(value): jellyfish_wave_max_seconds = clampf(value, 1.0, 45.0)
## Jellyfish wandering speed, in world pixels per second. Higher makes catches harder. Default: 45. Safe range: 0-200.
@export_range(0.0, 200.0, 5.0, "suffix:px/s")
var jellyfish_speed: float = 45.0:
	set(value): jellyfish_speed = clampf(value, 0.0, 200.0)
## Minimum spawn clearance around players and hazards, in world pixels. Higher reduces immediate collisions. Default: 90. Safe range: 0-300.
@export_range(0.0, 300.0, 5.0, "suffix:px")
var jellyfish_spawn_clearance: float = 90.0:
	set(value): jellyfish_spawn_clearance = clampf(value, 0.0, 300.0)
## Non-collectible entrance duration, in seconds. Higher delays a new catch. Default: 0.6. Safe range: 0-3.
@export_range(0.0, 3.0, 0.05, "suffix:s")
var jellyfish_entrance_seconds: float = 0.6:
	set(value): jellyfish_entrance_seconds = clampf(value, 0.0, 3.0)
## Collection lockout after a pop scatters jellyfish, in seconds. Higher gives opponents more time to reach them. Default: 0.5. Safe range: 0-3.
@export_range(0.0, 3.0, 0.05, "suffix:s")
var released_collection_lockout_seconds: float = 0.5:
	set(value): released_collection_lockout_seconds = clampf(value, 0.0, 3.0)

@export_group("Pufferfish and pop")
## Pufferfish collision radius, in world pixels. Higher increases hazard reach. Default: 30. Safe range: 8-100.
@export_range(8.0, 100.0, 1.0, "suffix:px")
var pufferfish_collider_radius: float = 30.0:
	set(value): pufferfish_collider_radius = clampf(value, 8.0, 100.0)
## Early pufferfish spawns per second. Higher increases early risk. Default: 0.08. Safe range: 0-2.
@export_range(0.0, 2.0, 0.01, "suffix:/s")
var pufferfish_start_spawn_rate: float = 0.08:
	set(value): pufferfish_start_spawn_rate = clampf(value, 0.0, 2.0)
## Late pufferfish spawns per second. Higher increases endgame risk. Default: 0.3. Safe range: 0-3; at least start rate.
@export_range(0.0, 3.0, 0.01, "suffix:/s")
var pufferfish_max_spawn_rate: float = 0.3:
	set(value): pufferfish_max_spawn_rate = clampf(value, 0.0, 3.0)
## Pufferfish drift speed, in world pixels per second. Higher shortens reaction time. Default: 120. Safe range: 20-400.
@export_range(20.0, 400.0, 5.0, "suffix:px/s")
var pufferfish_speed: float = 120.0:
	set(value): pufferfish_speed = clampf(value, 20.0, 400.0)
## Fraction of held jellyfish destroyed on pop. Higher leaves fewer to recollect. Default: 0.5. Safe range: 0-1.
@export_range(0.0, 1.0, 0.01)
var pop_disappear_ratio: float = 0.5:
	set(value): pop_disappear_ratio = clampf(value, 0.0, 1.0)
## Post-pop invulnerability and collection lockout, in seconds. Higher grants safer recovery. Default: 2. Safe range: 0-8.
@export_range(0.0, 8.0, 0.1, "suffix:s")
var pop_invulnerability_seconds: float = 2.0:
	set(value): pop_invulnerability_seconds = clampf(value, 0.0, 8.0)
## Bubble re-form animation after a pop, in seconds. Higher makes recovery more visible; lower feels snappier. Default: 0.35. Safe range: 0.1-1.5.
@export_range(0.1, 1.5, 0.05, "suffix:s")
var bubble_reform_seconds: float = 0.35:
	set(value): bubble_reform_seconds = clampf(value, 0.1, 1.5)
## Show an edge warning before pufferfish enter. Disabling removes visual notice. Default: enabled.
@export
var pufferfish_warning_enabled: bool = true
## Pufferfish edge warning time, in seconds. Higher gives more notice. Default: 0.8. Safe range: 0-3.
@export_range(0.0, 3.0, 0.05, "suffix:s")
var pufferfish_warning_seconds: float = 0.8:
	set(value): pufferfish_warning_seconds = clampf(value, 0.0, 3.0)

@export_group("Presentation")
## Gentle character bob in pixels. Zero holds the idle pose still. Default: 4. Safe range: 0-12.
@export_range(0.0, 12.0, 0.5, "suffix:px")
var character_float_pixels: float = 4.0:
	set(value): character_float_pixels = clampf(value, 0.0, 12.0)
## Seconds between the average natural eye blinks. Default: 3.4. Safe range: 1.5-7.
@export_range(1.5, 7.0, 0.1, "suffix:s")
var character_blink_interval_seconds: float = 3.4:
	set(value): character_blink_interval_seconds = clampf(value, 1.5, 7.0)
## Duration of the accepted-swipe push and bubble pull. Default: 0.34. Safe range: 0.12-0.9.
@export_range(0.12, 0.9, 0.01, "suffix:s")
var swipe_reaction_seconds: float = 0.34:
	set(value): swipe_reaction_seconds = clampf(value, 0.12, 0.9)
## Maximum bubble surface stretch on a swipe. Default: 0.17. Safe range: 0-0.22.
@export_range(0.0, 0.22, 0.01)
var swipe_pull_strength: float = 0.17:
	set(value): swipe_pull_strength = clampf(value, 0.0, 0.22)
## Character travel on an accepted swipe, in local pixels. Default: 13. Safe range: 0-24.
@export_range(0.0, 24.0, 1.0, "suffix:px")
var swipe_character_push_pixels: float = 13.0:
	set(value): swipe_character_push_pixels = clampf(value, 0.0, 24.0)
## Character turning speed while charge is active, in revolutions per second. Default: 2.4. Safe range: 0.5-5.
@export_range(0.5, 5.0, 0.1, "suffix:rev/s")
var charge_turns_per_second: float = 2.4:
	set(value): charge_turns_per_second = clampf(value, 0.5, 5.0)
## Character unwinding time after host-accepted spin activation. Default: 0.22. Safe range: 0.08-0.6.
@export_range(0.08, 0.6, 0.01, "suffix:s")
var spin_release_seconds: float = 0.22:
	set(value): spin_release_seconds = clampf(value, 0.08, 0.6)
## Surface rotation speed during authoritative spin, in revolutions per second. Default: 1.8. Safe range: 0.2-5.
@export_range(0.2, 5.0, 0.1, "suffix:rev/s")
var spin_surface_turns_per_second: float = 1.8:
	set(value): spin_surface_turns_per_second = clampf(value, 0.2, 5.0)
## Visible curved-fragment burst time after a pop. Default: 0.26. Safe range: 0.1-0.6.
@export_range(0.1, 0.6, 0.01, "suffix:s")
var burst_seconds: float = 0.26:
	set(value): burst_seconds = clampf(value, 0.1, 0.6)
## Count of decorative spin bubbles and burst motes per player. Default: 10. Safe range: 0-32.
@export_range(0, 32, 1)
var decorative_particle_count: int = 10:
	set(value): decorative_particle_count = clampi(value, 0, 32)
## Remaining whole seconds when the final timer pulses begin. Higher starts urgency earlier. Default: 10. Safe range: 1-30.
@export_range(1, 30, 1, "suffix:s")
var final_timer_emphasis_seconds: int = 10:
	set(value): final_timer_emphasis_seconds = clampi(value, 1, 30)
## Strength of gentle environment layer motion. Zero holds the plates still; higher increases drift. Default: 1. Safe range: 0-2.
@export_range(0.0, 2.0, 0.05)
var parallax_strength: float = 1.0:
	set(value): parallax_strength = clampf(value, 0.0, 2.0)
## Multiplier for final timer size pulses. Zero keeps numbers steady; higher emphasizes each beat. Default: 1. Safe range: 0-2.
@export_range(0.0, 2.0, 0.05)
var timer_pulse_strength: float = 1.0:
	set(value): timer_pulse_strength = clampf(value, 0.0, 2.0)
## Bubbles background music level in decibels. Higher is louder; lower leaves more room for effects. Default: -12. Safe range: -30-0.
@export_range(-30.0, 0.0, 0.5, "suffix:dB")
var music_gain_db: float = -12.0:
	set(value): music_gain_db = clampf(value, -30.0, 0.0)
## Base effect level in decibels. Higher makes feedback louder; lower keeps it softer. Default: -6. Safe range: -30-0.
@export_range(-30.0, 0.0, 0.5, "suffix:dB")
var sfx_gain_db: float = -6.0:
	set(value): sfx_gain_db = clampf(value, -30.0, 0.0)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for property: Dictionary in get_property_list():
		var value: Variant = get(property.name)
		if typeof(value) == TYPE_FLOAT and not is_finite(value):
			errors.append("Bubbles: %s must be finite." % property.name)
	if max_radius <= starting_radius:
		errors.append("Bubbles: Maximum bubble radius must exceed starting radius.")
	if starting_jellyfish > max_free_jellyfish:
		errors.append("Bubbles: Starting jellyfish cannot exceed the free-jellyfish cap.")
	if jellyfish_low_spawn_rate > jellyfish_high_spawn_rate:
		errors.append("Bubbles: Low jellyfish spawn rate cannot exceed high rate.")
	if jellyfish_wave_min_seconds > jellyfish_wave_max_seconds:
		errors.append("Bubbles: Minimum jellyfish wave duration cannot exceed maximum.")
	if pufferfish_start_spawn_rate > pufferfish_max_spawn_rate:
		errors.append("Bubbles: Start pufferfish rate cannot exceed maximum.")
	return errors
