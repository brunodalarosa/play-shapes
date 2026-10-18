class_name Bubbles3DTuning
extends Resource
## Provisional values for Bubbles and jellyfishes 3D, in world units (one unit is 100 pixels of
## the 2D arena). Save a named preset and relaunch to compare feel.

@export_group("Round lifecycle")
## Character entrance after the shared booklet. Higher lengthens the entrance; lower reaches the
## countdown sooner. Default: 3.0. Safe range: 0.0 to 15.0.
@export_range(0.0, 15.0, 0.25, "suffix:s") var instructions_seconds: float = 3.0:
	set(value):
		instructions_seconds = clampf(value, 0.0, 15.0)
## Countdown after the entrance. Higher gives more preparation; lower starts sooner. Default: 3.0.
## Safe range: 0.0 to 10.0.
@export_range(0.0, 10.0, 0.25, "suffix:s") var countdown_seconds: float = 3.0:
	set(value):
		countdown_seconds = clampf(value, 0.0, 10.0)
## Active round length. Higher allows more collecting; lower makes each catch matter more. Default:
## 90.0. Safe range: 10.0 to 300.0.
@export_range(10.0, 300.0, 1.0, "suffix:s") var round_duration_seconds: float = 90.0:
	set(value):
		round_duration_seconds = clampf(value, 10.0, 300.0)

@export_group("Player bubble")
## Initial bubble radius. Higher begins with more reach and more exposure to pufferfish. Default:
## 0.48. Safe range: 0.16 to 1.6.
@export_range(0.16, 1.6, 0.01, "suffix:u") var starting_radius: float = 0.48:
	set(value):
		starting_radius = clampf(value, 0.16, 1.6)
## Largest visual and collision radius; catching continues past it. Must exceed the starting radius.
## Default: 1.7. Safe range: 0.32 to 2.4.
@export_range(0.32, 2.4, 0.01, "suffix:u") var max_radius: float = 1.7:
	set(value):
		max_radius = clampf(value, 0.32, 2.4)
## Radius gained per caught jellyfish. Higher grows faster. Default: 0.02. Safe range: 0.001 to 0.1.
@export_range(0.001, 0.1, 0.001, "suffix:u") var radius_per_jellyfish: float = 0.02:
	set(value):
		radius_per_jellyfish = clampf(value, 0.001, 0.1)
## Most caught jellyfishes drawn inside a bubble, here and on the phone. Scores are never capped.
## Default: 16. Safe range: 0 to 40.
@export_range(0, 40, 1) var captured_visual_cap: int = 16:
	set(value):
		captured_visual_cap = clampi(value, 0, 40)
## Extra mass per jellyfish as a share of the base mass. Higher makes big bubbles harder to shove.
## Default: 0.02. Safe range: 0.0 to 0.2.
@export_range(0.0, 0.2, 0.005) var mass_growth_per_jellyfish: float = 0.02:
	set(value):
		mass_growth_per_jellyfish = clampf(value, 0.0, 0.2)
## Speed lost per jellyfish, before the speed cap. Higher slows big bubbles more. Default: 0.004.
## Safe range: 0.0 to 0.1.
@export_range(0.0, 0.1, 0.002) var speed_reduction_per_jellyfish: float = 0.004:
	set(value):
		speed_reduction_per_jellyfish = clampf(value, 0.0, 0.1)

@export_group("Movement and swipes")
## Speed one accepted swipe adds to a base-mass bubble. Higher makes each swipe stronger. Default:
## 3.2. Safe range: 0.2 to 10.0.
@export_range(0.2, 10.0, 0.05, "suffix:u/s") var swipe_impulse: float = 3.2:
	set(value):
		swipe_impulse = clampf(value, 0.2, 10.0)
## Longest touch that still moves the bubble. Longer touches only stretch it until this limit.
## Default: 0.8. Safe range: 0.2 to 2.0.
@export_range(0.2, 2.0, 0.05, "suffix:s") var swipe_max_hold_seconds: float = 0.8:
	set(value):
		swipe_max_hold_seconds = clampf(value, 0.2, 2.0)
## Shortest recognised swipe, as a share of the phone touch area. Higher needs a longer swipe.
## Default: 0.06. Safe range: 0.02 to 0.3.
@export_range(0.02, 0.3, 0.005) var swipe_min_distance: float = 0.06:
	set(value):
		swipe_min_distance = clampf(value, 0.02, 0.3)
## Bubble speed cap. Higher allows faster travel. Default: 5.0. Safe range: 0.5 to 12.0.
@export_range(0.5, 12.0, 0.1, "suffix:u/s") var max_player_speed: float = 5.0:
	set(value):
		max_player_speed = clampf(value, 0.5, 12.0)
## Water drag. Higher slows a drifting bubble sooner. Default: 1.8. Safe range: 0.0 to 8.0.
@export_range(0.0, 8.0, 0.1, "suffix:/s") var water_drag: float = 1.8:
	set(value):
		water_drag = clampf(value, 0.0, 8.0)
## Rebound off the screen-edge walls. Zero stops a bubble at the wall. Default: 0.65. Safe range:
## 0.0 to 1.0.
@export_range(0.0, 1.0, 0.01) var wall_bounciness: float = 0.65:
	set(value):
		wall_bounciness = clampf(value, 0.0, 1.0)
## Rebound when two bubbles bump. Higher pushes them apart harder. Default: 0.5. Safe range: 0.0 to
## 1.0.
@export_range(0.0, 1.0, 0.01) var bump_bounciness: float = 0.5:
	set(value):
		bump_bounciness = clampf(value, 0.0, 1.0)

@export_group("Jellyfish")
## Jellyfish collision radius. Higher makes catching easier. Default: 0.14. Safe range: 0.04 to 0.6.
@export_range(0.04, 0.6, 0.01, "suffix:u") var jellyfish_collider_radius: float = 0.14:
	set(value):
		jellyfish_collider_radius = clampf(value, 0.04, 0.6)
## Breathing pulse as a share of the jellyfish size. Zero disables it. Default: 0.045. Safe range:
## 0.0 to 0.12.
@export_range(0.0, 0.12, 0.005) var jellyfish_breath_amplitude: float = 0.045:
	set(value):
		jellyfish_breath_amplitude = clampf(value, 0.0, 0.12)
## Length of one breathing cycle. Default: 2.4. Safe range: 1.2 to 5.0.
@export_range(1.2, 5.0, 0.1, "suffix:s") var jellyfish_breath_period_seconds: float = 2.4:
	set(value):
		jellyfish_breath_period_seconds = clampf(value, 1.2, 5.0)
## Free jellyfishes placed before GO. Cannot exceed the free cap. Default: 20. Safe range: 0 to 100.
@export_range(0, 100, 1) var starting_jellyfish: int = 20:
	set(value):
		starting_jellyfish = clampi(value, 0, 100)
## Most free jellyfishes at once. Higher makes catching busier. Default: 70. Safe range: 1 to 200.
@export_range(1, 200, 1) var max_free_jellyfish: int = 70:
	set(value):
		max_free_jellyfish = clampi(value, 1, 200)
## Spawn rate ceiling of a low wave. At most the high rate. Default: 1.0. Safe range: 0.0 to 10.0.
@export_range(0.0, 10.0, 0.1, "suffix:/s") var jellyfish_low_spawn_rate: float = 1.0:
	set(value):
		jellyfish_low_spawn_rate = clampf(value, 0.0, 10.0)
## Spawn rate ceiling of a high wave. Default: 2.5. Safe range: 0.0 to 15.0.
@export_range(0.0, 15.0, 0.1, "suffix:/s") var jellyfish_high_spawn_rate: float = 2.5:
	set(value):
		jellyfish_high_spawn_rate = clampf(value, 0.0, 15.0)
## Shortest spawn wave. At most the longest wave. Default: 3.0. Safe range: 1.0 to 30.0.
@export_range(1.0, 30.0, 0.5, "suffix:s") var jellyfish_wave_min_seconds: float = 3.0:
	set(value):
		jellyfish_wave_min_seconds = clampf(value, 1.0, 30.0)
## Longest spawn wave. Default: 9.0. Safe range: 1.0 to 45.0.
@export_range(1.0, 45.0, 0.5, "suffix:s") var jellyfish_wave_max_seconds: float = 9.0:
	set(value):
		jellyfish_wave_max_seconds = clampf(value, 1.0, 45.0)
## Jellyfish wandering speed. Higher makes catches harder. Default: 0.5. Safe range: 0.0 to 2.0.
@export_range(0.0, 2.0, 0.05, "suffix:u/s") var jellyfish_speed: float = 0.5:
	set(value):
		jellyfish_speed = clampf(value, 0.0, 2.0)
## Least space between a new jellyfish and any bubble or pufferfish. Default: 0.9. Safe range: 0.0
## to 3.0.
@export_range(0.0, 3.0, 0.05, "suffix:u") var jellyfish_spawn_clearance: float = 0.9:
	set(value):
		jellyfish_spawn_clearance = clampf(value, 0.0, 3.0)
## Time a new jellyfish grows into view before it can be caught. Default: 0.5. Safe range: 0.0 to
## 3.0.
@export_range(0.0, 3.0, 0.05, "suffix:s") var jellyfish_entrance_seconds: float = 0.5:
	set(value):
		jellyfish_entrance_seconds = clampf(value, 0.0, 3.0)
## Time scattered jellyfishes blink white and cannot be caught after a pop. Default: 0.5. Safe
## range: 0.0 to 3.0.
@export_range(0.0, 3.0, 0.05, "suffix:s") var released_collection_lockout_seconds: float = 0.5:
	set(value):
		released_collection_lockout_seconds = clampf(value, 0.0, 3.0)

@export_group("Pufferfish and pop")
## Pufferfish collision radius before the size multiplier. Default: 0.3. Safe range: 0.08 to 1.0.
@export_range(0.08, 1.0, 0.01, "suffix:u") var pufferfish_collider_radius: float = 0.3:
	set(value):
		pufferfish_collider_radius = clampf(value, 0.08, 1.0)
## Scales both the pufferfish model and its collision radius. Default: 1.7. Safe range: 1.0 to 2.0.
@export_range(1.0, 2.0, 0.05, "suffix:x") var pufferfish_size_multiplier: float = 1.7:
	set(value):
		pufferfish_size_multiplier = clampf(value, 1.0, 2.0)
## Body wobble while swimming. Zero disables it. Default: 3.5. Safe range: 0.0 to 12.0.
@export_range(0.0, 12.0, 0.5, "suffix:deg") var pufferfish_jiggle_degrees: float = 3.5:
	set(value):
		pufferfish_jiggle_degrees = clampf(value, 0.0, 12.0)
## Length of one body wobble. Default: 0.32. Safe range: 0.15 to 1.2.
@export_range(0.15, 1.2, 0.05, "suffix:s") var pufferfish_jiggle_period_seconds: float = 0.32:
	set(value):
		pufferfish_jiggle_period_seconds = clampf(value, 0.15, 1.2)
## Body squash during a wobble, as a share of its size. Default: 0.035. Safe range: 0.0 to 0.1.
@export_range(0.0, 0.1, 0.005) var pufferfish_jiggle_squash: float = 0.035:
	set(value):
		pufferfish_jiggle_squash = clampf(value, 0.0, 0.1)
## Pufferfish spawns per second at the start. At most the end rate. Default: 0.3. Safe range: 0.0 to
## 2.0.
@export_range(0.0, 2.0, 0.01, "suffix:/s") var pufferfish_start_spawn_rate: float = 0.3:
	set(value):
		pufferfish_start_spawn_rate = clampf(value, 0.0, 2.0)
## Pufferfish spawns per second at the end of the round. Default: 0.6. Safe range: 0.0 to 3.0.
@export_range(0.0, 3.0, 0.01, "suffix:/s") var pufferfish_max_spawn_rate: float = 0.6:
	set(value):
		pufferfish_max_spawn_rate = clampf(value, 0.0, 3.0)
## Pufferfish travel speed. Higher leaves less time to react. Default: 1.5. Safe range: 0.2 to 4.0.
@export_range(0.2, 4.0, 0.05, "suffix:u/s") var pufferfish_speed: float = 1.5:
	set(value):
		pufferfish_speed = clampf(value, 0.2, 4.0)
## Share of a popped bubble catch that vanishes; the rest scatter. Default: 0.5. Safe range: 0.0 to
## 1.0.
@export_range(0.0, 1.0, 0.01) var pop_disappear_ratio: float = 0.5:
	set(value):
		pop_disappear_ratio = clampf(value, 0.0, 1.0)
## Time after a pop when the character blinks white, cannot catch and cannot be popped. Default:
## 2.0. Safe range: 0.0 to 8.0.
@export_range(0.0, 8.0, 0.1, "suffix:s") var pop_invulnerability_seconds: float = 2.0:
	set(value):
		pop_invulnerability_seconds = clampf(value, 0.0, 8.0)
## Time the new bubble takes to grow around the character. Default: 0.35. Safe range: 0.1 to 1.5.
@export_range(0.1, 1.5, 0.05, "suffix:s") var bubble_reform_seconds: float = 0.35:
	set(value):
		bubble_reform_seconds = clampf(value, 0.1, 1.5)
## Shows a burst of small bubbles at the edge before a pufferfish enters. Default: true.
@export var pufferfish_warning_enabled: bool = true
## How long the edge warning precedes the pufferfish. Default: 1.1. Safe range: 0.0 to 3.0.
@export_range(0.0, 3.0, 0.05, "suffix:s") var pufferfish_warning_seconds: float = 1.1:
	set(value):
		pufferfish_warning_seconds = clampf(value, 0.0, 3.0)
## Small bubbles in one edge warning. Default: 32. Safe range: 4 to 64.
@export_range(4, 64, 1) var pufferfish_telegraph_bubble_count: int = 32:
	set(value):
		pufferfish_telegraph_bubble_count = clampi(value, 4, 64)
## Size of each warning bubble. Default: 0.06. Safe range: 0.02 to 0.1.
@export_range(0.02, 0.1, 0.005, "suffix:u") var pufferfish_telegraph_bubble_radius: float = 0.06:
	set(value):
		pufferfish_telegraph_bubble_radius = clampf(value, 0.02, 0.1)

@export_group("Presentation")
## Squircle height per unit of bubble radius; 1 is half the bubble diameter. Default: 1.0. Safe
## range: 0.4 to 1.6.
@export_range(0.4, 1.6, 0.05) var character_height_per_radius: float = 1.0:
	set(value):
		character_height_per_radius = clampf(value, 0.4, 1.6)
## Tallest the Squircle grows as its bubble grows. Default: 0.95. Safe range: 0.3 to 2.0.
@export_range(0.3, 2.0, 0.05, "suffix:u") var character_max_height: float = 0.95:
	set(value):
		character_max_height = clampf(value, 0.3, 2.0)
## Gentle up-and-down float of the Squircle. Zero holds it still. Default: 0.04. Safe range: 0.0 to
## 0.15.
@export_range(0.0, 0.15, 0.005, "suffix:u") var character_bob: float = 0.04:
	set(value):
		character_bob = clampf(value, 0.0, 0.15)
## Lean of the Squircle toward its bubble travel at top speed. Default: 12.0. Safe range: 0.0 to
## 30.0.
@export_range(0.0, 30.0, 0.5, "suffix:deg") var character_lean_degrees: float = 12.0:
	set(value):
		character_lean_degrees = clampf(value, 0.0, 30.0)
## Drift of the floating hands of the Squircle while it floats. Default: 0.05. Safe range: 0.0 to
## 0.2.
@export_range(0.0, 0.2, 0.005, "suffix:u") var character_hand_wobble: float = 0.05:
	set(value):
		character_hand_wobble = clampf(value, 0.0, 0.2)
## Average time between natural blinks. Default: 3.4. Safe range: 1.5 to 7.0.
@export_range(1.5, 7.0, 0.1, "suffix:s") var character_blink_interval_seconds: float = 3.4:
	set(value):
		character_blink_interval_seconds = clampf(value, 1.5, 7.0)
## Duration of the accepted-swipe push and bubble pull. Default: 0.34. Safe range: 0.12 to 0.9.
@export_range(0.12, 0.9, 0.01, "suffix:s") var swipe_reaction_seconds: float = 0.34:
	set(value):
		swipe_reaction_seconds = clampf(value, 0.12, 0.9)
## Bubble stretch on an accepted swipe. Default: 0.17. Safe range: 0.0 to 0.22.
@export_range(0.0, 0.22, 0.01) var swipe_pull_strength: float = 0.17:
	set(value):
		swipe_pull_strength = clampf(value, 0.0, 0.22)
## Squircle travel inside its bubble on an accepted swipe. Default: 0.13. Safe range: 0.0 to 0.3.
@export_range(0.0, 0.3, 0.01, "suffix:u") var swipe_character_push: float = 0.13:
	set(value):
		swipe_character_push = clampf(value, 0.0, 0.3)
## Bubble stretch toward a finger that is still dragging. Zero disables it. Default: 0.2. Safe
## range: 0.0 to 0.22.
@export_range(0.0, 0.22, 0.01) var live_drag_pull_strength: float = 0.2:
	set(value):
		live_drag_pull_strength = clampf(value, 0.0, 0.22)
## Time the drag stretch takes to follow and settle. Default: 0.08. Safe range: 0.02 to 0.4.
@export_range(0.02, 0.4, 0.01, "suffix:s") var live_drag_response_seconds: float = 0.08:
	set(value):
		live_drag_response_seconds = clampf(value, 0.02, 0.4)
## Droplets one pop throws. Default: 22. Safe range: 0 to 64.
@export_range(0, 64, 1) var pop_droplet_count: int = 22:
	set(value):
		pop_droplet_count = clampi(value, 0, 64)
## How long pop droplets fly. Default: 0.26. Safe range: 0.1 to 0.8.
@export_range(0.1, 0.8, 0.01, "suffix:s") var burst_seconds: float = 0.26:
	set(value):
		burst_seconds = clampf(value, 0.1, 0.8)
## Remaining seconds when the timer starts pulsing. Default: 10. Safe range: 1 to 30.
@export_range(1, 30, 1, "suffix:s") var final_timer_emphasis_seconds: int = 10:
	set(value):
		final_timer_emphasis_seconds = clampi(value, 1, 30)
## Size of the final-seconds timer pulses. Zero keeps the numbers steady. Default: 1.0. Safe range:
## 0.0 to 2.0.
@export_range(0.0, 2.0, 0.05) var timer_pulse_strength: float = 1.0:
	set(value):
		timer_pulse_strength = clampf(value, 0.0, 2.0)

@export_group("Water look")
## Water colour at the top of the screen. Default: #54d1fa.
@export var water_top_colour: Color = Color("54d1fa")
## Water colour at the bottom of the screen. Default: #08459a.
@export var water_bottom_colour: Color = Color("08459a")
## Brightness of the light shafts. Zero hides them. Default: 0.22. Safe range: 0.0 to 1.0.
@export_range(0.0, 1.0, 0.01) var god_ray_strength: float = 0.22:
	set(value):
		god_ray_strength = clampf(value, 0.0, 1.0)
## Drift speed of the light shafts. Default: 0.25. Safe range: 0.0 to 2.0.
@export_range(0.0, 2.0, 0.01) var god_ray_speed: float = 0.25:
	set(value):
		god_ray_speed = clampf(value, 0.0, 2.0)
## Shimmer on the seabed and scenery. Default: 0.25. Safe range: 0.0 to 1.0.
@export_range(0.0, 1.0, 0.01) var caustic_strength: float = 0.25:
	set(value):
		caustic_strength = clampf(value, 0.0, 1.0)
## Camera distance where scenery starts fading. Stays beyond the gameplay plane. Default: 24.0. Safe
## range: 20.5 to 80.0.
@export_range(20.5, 80.0, 0.5, "suffix:u") var haze_begin: float = 24.0:
	set(value):
		haze_begin = clampf(value, 20.5, 80.0)
## Camera distance where scenery has faded fully. Must exceed the haze start. Default: 72.0. Safe
## range: 25.0 to 200.0.
@export_range(25.0, 200.0, 1.0, "suffix:u") var haze_end: float = 72.0:
	set(value):
		haze_end = clampf(value, 25.0, 200.0)
## Rising air bubbles per second in each background column. Default: 1.4. Safe range: 0.0 to 10.0.
@export_range(0.0, 10.0, 0.1, "suffix:/s") var air_bubble_rate: float = 1.4:
	set(value):
		air_bubble_rate = clampf(value, 0.0, 10.0)

@export_group("Audio")
## Background music level. Default: -12.0. Safe range: -30.0 to 0.0.
@export_range(-30.0, 0.0, 0.5, "suffix:dB") var music_gain_db: float = -12.0:
	set(value):
		music_gain_db = clampf(value, -30.0, 0.0)
## Base sound-effect level. Default: -6.0. Safe range: -30.0 to 0.0.
@export_range(-30.0, 0.0, 0.5, "suffix:dB") var sfx_gain_db: float = -6.0:
	set(value):
		sfx_gain_db = clampf(value, -30.0, 0.0)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for property: Dictionary in get_property_list():
		var value: Variant = get(property.name)
		if typeof(value) == TYPE_FLOAT and not is_finite(value):
			errors.append("Bubbles 3D: %s must be finite." % property.name)
	if max_radius <= starting_radius:
		errors.append("Bubbles 3D: Maximum bubble radius must exceed starting radius.")
	if starting_jellyfish > max_free_jellyfish:
		errors.append("Bubbles 3D: Starting jellyfish cannot exceed the free-jellyfish cap.")
	if jellyfish_low_spawn_rate > jellyfish_high_spawn_rate:
		errors.append("Bubbles 3D: Low jellyfish spawn rate cannot exceed high rate.")
	if jellyfish_wave_min_seconds > jellyfish_wave_max_seconds:
		errors.append("Bubbles 3D: Minimum jellyfish wave duration cannot exceed maximum.")
	if pufferfish_start_spawn_rate > pufferfish_max_spawn_rate:
		errors.append("Bubbles 3D: Start pufferfish rate cannot exceed maximum.")
	# Godot adds two bodies' bounce, so the walls keep what the bubbles' half leaves over.
	if wall_bounciness < bump_bounciness * 0.5:
		errors.append("Bubbles 3D: Wall bounciness must be at least half the bump bounciness.")
	if haze_end <= haze_begin:
		errors.append("Bubbles 3D: Haze end must exceed haze begin.")
	return errors


## Bubble radius for a held catch of [param score] jellyfishes.
func radius_for(score: int) -> float:
	return minf(max_radius, starting_radius + float(maxi(0, score)) * radius_per_jellyfish)


## Base-mass multiples a bubble of [param radius] weighs.
func mass_for(radius: float) -> float:
	return 1.0 + _growth(radius) * mass_growth_per_jellyfish


## Speed cap of a bubble of [param radius].
func max_speed_for(radius: float) -> float:
	return max_player_speed / (1.0 + _growth(radius) * speed_reduction_per_jellyfish)


## Squircle standing height inside a bubble of [param radius].
func character_height_for(radius: float) -> float:
	return minf(character_max_height, radius * character_height_per_radius)


## Pufferfish collision radius, which the model is scaled to.
func pufferfish_radius() -> float:
	return pufferfish_collider_radius * pufferfish_size_multiplier


func _growth(radius: float) -> float:
	return maxf(0.0, (radius - starting_radius) / radius_per_jellyfish)
