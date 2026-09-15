extends SceneTree

const TUNING_ROOT := "res://Tuning"
const SimonTuningScript := preload("res://Tuning/Minigames/simon_says_tuning.gd")
const NetworkingTuningScript := preload("res://Tuning/Shared/networking_tuning.gd")
const ActivePresetsScript := preload("res://Tuning/active_presets.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not _check_tooltip_contract("res://Tuning/Minigames/simon_says_tuning.gd", [
		"charge_fill_seconds", "charge_decay_seconds", "dance_beats_per_second",
		"body_bounce", "body_jiggle_degrees", "body_sway", "visual_follow_speed",
		"auto_hold_seconds", "auto_release_seconds",
	]):
		return
	if not _check_tooltip_contract("res://Tuning/Shared/networking_tuning.gd", [
		"http_port", "websocket_port", "max_connections", "request_timeout_seconds",
		"max_players", "reconnect_grace_seconds",
	]):
		return
	if not _check_tooltip_contract("res://Tuning/active_presets.gd", ["simon_says", "networking"]):
		return

	var preset_paths := _find_presets(TUNING_ROOT)
	if not _check(preset_paths.has("res://Tuning/Active Presets.tres") and preset_paths.has("res://Tuning/Minigames/SimonSays/Default.tres") and preset_paths.has("res://Tuning/Shared/Networking/Default.tres"), "Default presets and Active Presets are discovered"):
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
	simon.auto_release_seconds = 0.1
	if not _check(simon.validation_errors()[0].contains("Auto release"), "Simon Says invalid combinations report an actionable message"):
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

	var active: Resource = ActivePresetsScript.new()
	if not _check(active.validation_errors().size() == 2, "Active selector rejects missing preset references"):
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
