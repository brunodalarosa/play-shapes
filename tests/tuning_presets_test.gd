extends SceneTree

const TUNING_ROOT := "res://Tuning"
const SimonTuningScript := preload("res://Tuning/Minigames/simon_says_tuning.gd")
const BubblesTuningScript := preload("res://Tuning/Minigames/bubbles_tuning.gd")
const NetworkingTuningScript := preload("res://Tuning/Shared/networking_tuning.gd")
const ActivePresetsScript := preload("res://Tuning/active_presets.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not _check_tooltip_contract("res://Tuning/Minigames/simon_says_tuning.gd", [
		"countdown_seconds", "round_duration_seconds", "stop_interval_min_seconds",
		"stop_interval_max_seconds", "stop_interval_reduction_seconds",
		"down_unlock_seconds", "up_unlock_seconds",
		"charge_fill_seconds", "charge_decay_seconds", "pose_reveal_delay_seconds",
		"pose_grace_seconds", "dance_beats_per_second",
		"body_bounce", "body_jiggle_degrees", "body_sway", "visual_follow_speed",
		"secondary_motion_strength", "lead_emphasis", "reaction_seconds", "result_cycle_seconds",
		"pose_flow_hold_seconds",
		"controller_left_color", "controller_right_color", "controller_down_color", "controller_up_color",
		"controller_minimum_brightness", "controller_maximum_brightness",
		"auto_hold_seconds", "auto_release_seconds",
	]):
		return
	if not _check_tooltip_contract("res://Tuning/Shared/networking_tuning.gd", [
		"http_port", "websocket_port", "max_connections", "request_timeout_seconds",
		"max_players", "reconnect_grace_seconds",
	]):
		return
	if not _check_tooltip_contract("res://Tuning/Minigames/bubbles_tuning.gd", [
		"instructions_seconds", "countdown_seconds", "round_duration_seconds",
		"starting_radius", "max_radius", "radius_per_jellyfish", "captured_visual_cap",
		"mass_growth_per_jellyfish", "speed_reduction_per_jellyfish",
		"swipe_impulse", "swipe_min_distance", "max_player_speed", "water_drag", "wall_bounciness",
		"circles_to_charge", "circle_tolerance", "spin_duration_seconds", "spin_cooldown_seconds", "spin_shove_impulse",
		"jellyfish_collider_radius", "starting_jellyfish", "max_free_jellyfish",
		"jellyfish_low_spawn_rate", "jellyfish_high_spawn_rate", "jellyfish_wave_min_seconds", "jellyfish_wave_max_seconds",
		"jellyfish_speed", "jellyfish_spawn_clearance", "jellyfish_entrance_seconds", "released_collection_lockout_seconds",
		"pufferfish_collider_radius", "pufferfish_start_spawn_rate", "pufferfish_max_spawn_rate", "pufferfish_speed",
		"pop_disappear_ratio", "pop_invulnerability_seconds", "bubble_reform_seconds", "pufferfish_warning_enabled", "pufferfish_warning_seconds",
		"pufferfish_telegraph_bubble_count", "pufferfish_telegraph_bubble_radius", "pufferfish_telegraph_noise_strength",
		"final_timer_emphasis_seconds",
	]):
		return
	if not _check_tooltip_contract("res://Tuning/active_presets.gd", ["simon_says", "bubbles", "networking"]):
		return

	var preset_paths := _find_presets(TUNING_ROOT)
	if not _check(preset_paths.has("res://Tuning/Active Presets.tres") and preset_paths.has("res://Tuning/Minigames/SimonSays/Default.tres") and preset_paths.has("res://Tuning/Minigames/Bubbles/Default.tres") and preset_paths.has("res://Tuning/Shared/Networking/Default.tres"), "Default presets and Active Presets are discovered"):
		return
	for path: String in preset_paths:
		var preset: Resource = load(path)
		if not _check(preset != null, "Preset loads: %s" % path):
			return
		if not _check(preset.has_method("validation_errors"), "Preset exposes validation: %s" % path):
			return
		var errors: PackedStringArray = preset.validation_errors()
		if not _check(errors.is_empty(), "Preset is valid: %s — %s" % [path, "; ".join(errors)]):
			return

	var simon: Resource = SimonTuningScript.new()
	simon.charge_fill_seconds = -5.0
	simon.body_bounce = 99.0
	if not _check(simon.charge_fill_seconds == 0.1 and simon.body_bounce == 16.0, "Simon Says individual values clamp to safe ranges"):
		return
	simon.charge_decay_seconds = 1.0
	simon.pose_reveal_delay_seconds = 99.0
	simon.pose_grace_seconds = -1.0
	if not _check(simon.pose_reveal_delay_seconds == 0.5 and simon.pose_grace_seconds == 0.2,
		"Pose reveal and grace values clamp to documented safe ranges"):
		return
	simon.stop_interval_min_seconds = 9.0
	simon.stop_interval_max_seconds = 3.0
	if not _check(simon.validation_errors()[0].contains("Minimum stop interval"),
		"Simon Says invalid round timing reports an actionable message"):
		return
	simon.stop_interval_min_seconds = 3.0
	simon.auto_release_seconds = 0.1
	if not _check(simon.validation_errors()[0].contains("Auto release"), "Simon Says invalid combinations report an actionable message"):
		return
	simon.auto_release_seconds = 2.0
	simon.controller_minimum_brightness = 0.8
	simon.controller_maximum_brightness = 0.6
	if not _check(simon.validation_errors()[0].contains("idle brightness"), "Phone brightness ordering validates cleanly"):
		return

	var networking: Resource = NetworkingTuningScript.new()
	networking.http_port = 1
	networking.max_connections = 999
	if not _check(networking.http_port == 1024 and networking.max_connections == 128, "Networking individual values clamp to safe ranges"):
		return
	networking.http_port = 9000
	networking.websocket_port = 9000
	networking.max_connections = 2
	networking.max_players = 3
	var network_errors: PackedStringArray = networking.validation_errors()
	if not _check(network_errors.size() == 2 and network_errors[0].contains("must be different") and network_errors[1].contains("cannot exceed"), "Networking invalid combinations report actionable messages"):
		return
	var bubbles: Resource = BubblesTuningScript.new()
	bubbles.starting_radius = -1.0
	if not _check(bubbles.starting_radius == 16.0, "Bubbles individual values clamp to safe ranges"):
		return
	bubbles.starting_radius = 100.0
	bubbles.max_radius = 32.0
	bubbles.starting_jellyfish = 100
	bubbles.max_free_jellyfish = 1
	if not _check(bubbles.validation_errors().size() == 2, "Bubbles invalid radius and population combinations are rejected"):
		return
	bubbles.max_radius = 110.0
	bubbles.starting_jellyfish = 20
	bubbles.max_free_jellyfish = 70
	bubbles.jellyfish_low_spawn_rate = 3.0
	bubbles.jellyfish_high_spawn_rate = 1.0
	bubbles.pufferfish_start_spawn_rate = 0.8
	bubbles.pufferfish_max_spawn_rate = 0.2
	if not _check(bubbles.validation_errors().size() == 2, "Bubbles invalid spawn-rate ordering is rejected"):
		return
	bubbles = BubblesTuningScript.new()
	bubbles.water_drag = INF
	if not _check(bubbles.water_drag == 8.0 and bubbles.validation_errors().is_empty(), "Bubbles clamps non-finite positive input to a safe bound"):
		return

	var active: Resource = ActivePresetsScript.new()
	if not _check(active.validation_errors().size() == 3, "Active selector rejects missing preset references"):
		return
	print("Tuning preset checks passed (%d committed assets)" % preset_paths.size())
	quit(0)

func _check_tooltip_contract(path: String, property_names: Array[String]) -> bool:
	var source := FileAccess.get_file_as_string(path)
	if not _check(not source.contains("@export_category"), "Tuning groups must not replace the script class used for Inspector documentation: %s" % path):
		return false
	var lines := source.split("\n")
	for property_name: String in property_names:
		var declaration_index := -1
		for index: int in lines.size():
			if (lines[index] as String).begins_with("var %s:" % property_name):
				declaration_index = index
				break
		if not _check(declaration_index >= 2, "Tunable declaration exists: %s" % property_name):
			return false
		# Godot associates the tooltip only when the documentation comment precedes
		# the annotation and the annotation is on its own line before the variable.
		if not _check((lines[declaration_index - 1] as String).begins_with("@export"), "Export annotation immediately precedes %s" % property_name):
			return false
		if not _check((lines[declaration_index - 2] as String).begins_with("## "), "Tooltip documentation immediately precedes the annotation for %s" % property_name):
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

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
