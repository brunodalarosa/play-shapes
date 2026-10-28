class_name WorkshopGamePreset
extends RefCounted
## Which preset the game uses for one minigame: its entry in Tuning/Active Presets.tres.
##
## Using a preset changes only the path of that one entry in the file's text, so every other
## minigame's entry stays as it was and the designer commits a one-line change.

const ACTIVE_PRESETS_PATH := "res://Tuning/Active Presets.tres"

var file_path := ACTIVE_PRESETS_PATH
## The ActivePresets property, such as [code]flappy_race[/code].
var field := ""


func _init(active_presets_field: String, active_presets_path := ACTIVE_PRESETS_PATH) -> void:
	field = active_presets_field
	file_path = active_presets_path


## The res:// path of the preset the game uses, or an empty string.
func current_path() -> String:
	var text := FileAccess.get_file_as_string(file_path)
	var id := _resource_id(text)
	if id.is_empty():
		return ""
	var line := _resource_line(text, id)
	if line == null:
		return ""
	return line.get_string(&"path")


## Makes the game use the preset at [param preset_path]. Returns an error message or "".
func use(preset_path: String) -> String:
	var text := FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		return "Could not read %s." % file_path
	var id := _resource_id(text)
	if id.is_empty():
		return "%s has no %s entry." % [file_path.get_file(), field]
	var shared := RegEx.create_from_string('ExtResource\\("%s"\\)' % id).search_all(text).size()
	if shared != 1:
		return "Another entry shares the %s preset; edit %s by hand." % [field, file_path]

	var line := _resource_line(text, id)
	if line == null:
		return "%s does not list the %s preset." % [file_path.get_file(), field]
	# The uid would point at the old file, so the path alone names the new one.
	var replacement := '[ext_resource type="Resource" path="%s" id="%s"]' % [preset_path, id]
	text = text.substr(0, line.get_start()) + replacement + text.substr(line.get_end())
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return "Could not write %s: %s" % [file_path, error_string(FileAccess.get_open_error())]
	file.store_string(text)
	file.close()
	return ""


func _resource_id(text: String) -> String:
	var entry := RegEx.create_from_string('(?m)^%s = ExtResource\\("([^"]+)"\\)' % field)
	var found := entry.search(text)
	return "" if found == null else found.get_string(1)


func _resource_line(text: String, id: String) -> RegExMatch:
	var pattern := '(?m)^\\[ext_resource [^\\]]*path="(?<path>[^"]+)"[^\\]]* id="%s"\\]' % id
	return RegEx.create_from_string(pattern).search(text)
