extends TestScript

const TUNING_ROOT := "res://Tuning"
const MINIGAMES_ROOT := "res://minigames"
const BubblesTuningScript := preload(
	"res://minigames/002_bubbles_and_jellyfishes/bubbles_tuning.gd"
)
const NetworkingTuningScript := preload("res://Tuning/Shared/networking_tuning.gd")
const ActivePresetsScript := preload("res://Tuning/active_presets.gd")


func _run() -> void:
	if not _check_tooltip_contract(
		"res://Tuning/Shared/networking_tuning.gd",
		[
			"http_port",
			"websocket_port",
			"max_connections",
			"request_timeout_seconds",
			"max_players",
			"reconnect_grace_seconds",
		],
	):
		return
	if not _check_tooltip_contract(
		"res://minigames/002_bubbles_and_jellyfishes/bubbles_tuning.gd",
		[
			"instructions_seconds",
			"countdown_seconds",
			"round_duration_seconds",
			"starting_radius",
			"max_radius",
			"radius_per_jellyfish",
			"captured_visual_cap",
			"mass_growth_per_jellyfish",
			"speed_reduction_per_jellyfish",
			"swipe_impulse",
			"swipe_min_distance",
			"max_player_speed",
			"water_drag",
			"wall_bounciness",
			"circles_to_charge",
			"circle_tolerance",
			"spin_duration_seconds",
			"spin_cooldown_seconds",
			"spin_shove_impulse",
			"jellyfish_collider_radius",
			"starting_jellyfish",
			"max_free_jellyfish",
			"jellyfish_low_spawn_rate",
			"jellyfish_high_spawn_rate",
			"jellyfish_wave_min_seconds",
			"jellyfish_wave_max_seconds",
			"jellyfish_speed",
			"jellyfish_spawn_clearance",
			"jellyfish_entrance_seconds",
			"released_collection_lockout_seconds",
			"pufferfish_collider_radius",
			"pufferfish_start_spawn_rate",
			"pufferfish_max_spawn_rate",
			"pufferfish_speed",
			"pop_disappear_ratio",
			"pop_invulnerability_seconds",
			"bubble_reform_seconds",
			"pufferfish_warning_enabled",
			"pufferfish_warning_seconds",
			"pufferfish_telegraph_bubble_count",
			"pufferfish_telegraph_bubble_radius",
			"pufferfish_telegraph_noise_strength",
			"final_timer_emphasis_seconds",
		],
	):
		return
	if not _check_tooltip_contract(
		"res://minigames/003_tilt_shift/tilt_shift_tuning.gd",
		[
			"round_duration_seconds",
			"round_count",
			"neighbor_distance",
			"paddle_layout",
			"baskets_by_round",
			"physics",
		],
	):
		return
	if not _check_tooltip_contract(
		"res://minigames/003_tilt_shift/tilt_shift_physics_tuning.gd",
		[
			"ball_count",
			"delivery_curve",
			"negative_ball_count",
			"negative_delivery_curve",
			"use_position_seed",
			"position_seed",
			"spawn_half_width",
			"ball_radius",
			"paddle_length",
			"paddle_thickness",
			"gravity",
			"entry_speed",
			"rotation_speed_degrees",
			"ball_friction",
			"paddle_friction",
			"ball_bounce",
			"paddle_bounce",
		],
	):
		return
	if not _check_tooltip_contract(
		"res://Tuning/active_presets.gd",
		["bubbles", "tilt_shift", "networking"],
	):
		return

	var preset_paths := _find_presets(TUNING_ROOT)
	for minigame: String in DirAccess.get_directories_at(MINIGAMES_ROOT):
		var tuning_folder := MINIGAMES_ROOT.path_join(minigame).path_join("tuning")
		preset_paths.append_array(_find_presets(tuning_folder))
	if not check(
		preset_paths.has("res://Tuning/Active Presets.tres")
		and preset_paths.has("res://minigames/002_bubbles_and_jellyfishes/tuning/Default.tres")
		and preset_paths.has("res://Tuning/Shared/Networking/Default.tres"),
		"Default presets and Active Presets are discovered",
	):
		return
	for path: String in preset_paths:
		var preset: Resource = load(path)
		if not check(preset != null, "Preset loads: %s" % path):
			return
		var validates := preset.has_method("validation_errors")
		if not check(validates, "Preset exposes validation: %s" % path):
			return
		var errors: PackedStringArray = preset.validation_errors()
		if not check(errors.is_empty(), "Preset is valid: %s — %s" % [path, "; ".join(errors)]):
			return

	var networking: Resource = NetworkingTuningScript.new()
	var default_networking: Resource = load("res://Tuning/Shared/Networking/Default.tres")
	if not check(
		networking.max_players == 10 and default_networking.max_players == 10
		and default_networking.max_connections == 32
		and default_networking.reconnect_grace_seconds == 60.0,
		"Networking defaults preserve ten registered players, 32 connections, and 60-second grace",
	):
		return
	networking.max_players = 20
	if not check(networking.max_players == 10, "Designer tuning clamps capacity at ten"):
		return
	networking.http_port = 1
	networking.max_connections = 999
	if not check(
		networking.http_port == 1024 and networking.max_connections == 128,
		"Networking individual values clamp to safe ranges",
	):
		return
	networking.http_port = 9000
	networking.websocket_port = 9000
	networking.max_connections = 2
	networking.max_players = 3
	var network_errors: PackedStringArray = networking.validation_errors()
	if not check(
		network_errors.size() == 2 and network_errors[0].contains("must be different")
		and network_errors[1].contains("cannot exceed"),
		"Networking invalid combinations report actionable messages",
	):
		return
	var bubbles: Resource = BubblesTuningScript.new()
	bubbles.starting_radius = -1.0
	var clamped: bool = bubbles.starting_radius == 16.0
	if not check(clamped, "Bubbles individual values clamp to safe ranges"):
		return
	bubbles.starting_radius = 100.0
	bubbles.max_radius = 32.0
	bubbles.starting_jellyfish = 100
	bubbles.max_free_jellyfish = 1
	if not check(
		bubbles.validation_errors().size() == 2,
		"Bubbles invalid radius and population combinations are rejected",
	):
		return
	bubbles.max_radius = 110.0
	bubbles.starting_jellyfish = 20
	bubbles.max_free_jellyfish = 70
	bubbles.jellyfish_low_spawn_rate = 3.0
	bubbles.jellyfish_high_spawn_rate = 1.0
	bubbles.pufferfish_start_spawn_rate = 0.8
	bubbles.pufferfish_max_spawn_rate = 0.2
	if not check(
		bubbles.validation_errors().size() == 2,
		"Bubbles invalid spawn-rate ordering is rejected",
	):
		return
	bubbles = BubblesTuningScript.new()
	bubbles.water_drag = INF
	if not check(
		bubbles.water_drag == 8.0 and bubbles.validation_errors().is_empty(),
		"Bubbles clamps non-finite positive input to a safe bound",
	):
		return

	var active: Resource = ActivePresetsScript.new()
	if not check(
		active.validation_errors().size() == 3,
		"Active selector rejects missing preset references",
	):
		return


func _check_tooltip_contract(path: String, property_names: Array[String]) -> bool:
	var source := FileAccess.get_file_as_string(path)
	if not check(
		not source.contains("@export_category"),
		"Tuning groups must not replace the script class used for Inspector documentation: %s"
		% path,
	):
		return false
	var lines := source.split("\n")
	for property_name: String in property_names:
		# The annotation may share the variable's line or sit on the lines above it.
		var declaration := "var %s:" % property_name
		var index := -1
		for candidate: int in lines.size():
			var line := lines[candidate] as String
			if (
				line.begins_with(declaration)
				or (line.begins_with("@export") and line.contains(" " + declaration))
			):
				index = candidate
				break
		if not check(index >= 1, "Tunable declaration exists: %s" % property_name):
			return false

		var exported := (lines[index] as String).begins_with("@export")
		while index > 0 and _is_property_annotation(lines[index - 1]):
			exported = true
			index -= 1
		if not check(exported, "Export annotation precedes %s" % property_name):
			return false

		# Godot attaches the tooltip only when the documentation comment comes directly
		# before the property and its annotations; a group annotation in between detaches it.
		if not check(
			index > 0 and (lines[index - 1] as String).begins_with("## "),
			"Tooltip documentation immediately precedes the annotation for %s" % property_name,
		):
			return false
	return true


func _is_property_annotation(line: String) -> bool:
	if not line.begins_with("@export"):
		return false

	for grouping: String in ["@export_group", "@export_subgroup", "@export_category"]:
		if line.begins_with(grouping):
			return false
	return true


func _find_presets(path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(path)
	if directory == null:
		return result
	for file_name: String in directory.get_files():
		if file_name.ends_with(".tres"):
			result.append(path.path_join(file_name))
	for directory_name: String in directory.get_directories():
		result.append_array(_find_presets(path.path_join(directory_name)))
	result.sort()
	return result
