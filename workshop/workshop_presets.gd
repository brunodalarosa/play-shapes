class_name WorkshopPresets
extends RefCounted
## A minigame's presets: one .tres file each in its tuning folder, every part embedded.

const DEFAULT_NAME := "Default"
const EXTENSION := ".tres"

var folder := ""


func _init(tuning_folder: String) -> void:
	folder = tuning_folder


## Preset names, Default first, then by name.
func names() -> PackedStringArray:
	var result: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(EXTENSION):
			result.append(file.trim_suffix(EXTENSION))
	result.sort_custom(
		func(a: String, b: String) -> bool:
			if a == DEFAULT_NAME or b == DEFAULT_NAME:
				return a == DEFAULT_NAME
			return a.naturalnocasecmp_to(b) < 0,
	)
	return PackedStringArray(result)


func path(name: String) -> String:
	return folder.path_join(name + EXTENSION)


func has(name: String) -> bool:
	return FileAccess.file_exists(path(name))


## A fresh copy of the preset as its file holds it, shared with nothing else loaded.
func load_preset(name: String) -> Resource:
	var loaded := ResourceLoader.load(path(name), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	return WorkshopTuning.copy(loaded)


## Writes [param preset] as [param name], every part inside the one file. A preset with
## validation errors is refused.
func save(preset: Resource, name: String) -> String:
	var problem := name_problem(name)
	if not problem.is_empty():
		return problem
	if preset.has_method(&"validation_errors") and not preset.validation_errors().is_empty():
		return "Fix the errors before saving."
	var error := ResourceSaver.save(WorkshopTuning.copy(preset), path(name))
	return "" if error == OK else "Could not save %s: %s" % [name, error_string(error)]


func duplicate_preset(name: String, new_name: String) -> String:
	if has(new_name):
		return "A preset named %s already exists." % new_name
	return save(load_preset(name), new_name)


## Renames a preset. Default and the preset the game uses keep their names.
func rename(name: String, new_name: String, game_uses: String) -> String:
	var problem := _protected(name, game_uses, "renamed")
	if problem.is_empty():
		problem = name_problem(new_name)
	if problem.is_empty() and has(new_name):
		problem = "A preset named %s already exists." % new_name
	if not problem.is_empty():
		return problem
	var error := DirAccess.rename_absolute(path(name), path(new_name))
	return "" if error == OK else "Could not rename %s: %s" % [name, error_string(error)]


## Deletes a preset's file. Default and the preset the game uses cannot be deleted.
func delete(name: String, game_uses: String) -> String:
	var problem := _protected(name, game_uses, "deleted")
	if not problem.is_empty():
		return problem
	var error := DirAccess.remove_absolute(path(name))
	return "" if error == OK else "Could not delete %s: %s" % [name, error_string(error)]


## Why [param name] cannot name a preset, or an empty string.
static func name_problem(name: String) -> String:
	if name.strip_edges().is_empty():
		return "A preset needs a name."
	if name != name.strip_edges() or not name.is_valid_filename() or name.length() > 40:
		return "Use letters, numbers, spaces, hyphens or underscores, up to 40."
	if RegEx.create_from_string("^[A-Za-z0-9 _-]+$").search(name) == null:
		return "Use letters, numbers, spaces, hyphens or underscores, up to 40."
	return ""


func _protected(name: String, game_uses: String, action: String) -> String:
	if name == DEFAULT_NAME:
		return "Default cannot be %s." % action
	if path(name) == game_uses:
		return "The preset the game uses cannot be %s." % action
	return ""
