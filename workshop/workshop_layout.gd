class_name WorkshopLayout
extends RefCounted
## Remembers a workshop's layout on this computer: the grips between panels and which panels
## are popped out, on which screen, where and how large.

const FOLDER := "user://workshops"

var file_path := ""


func _init(workshop_id: String) -> void:
	file_path = FOLDER.path_join("%s_layout.cfg" % workshop_id)


func save(splits: Dictionary[String, int], panels: Array[WorkshopDockablePanel]) -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var config := ConfigFile.new()
	for split: String in splits:
		config.set_value("splits", split, splits[split])
	for panel: WorkshopDockablePanel in panels:
		var state := panel.window_state()
		if state.is_empty():
			continue
		var section := "panel_%d" % panel.number
		config.set_value(section, "rect", state.rect)
		config.set_value(section, "screen", state.screen)
		config.set_value(section, "mode", state.mode)
	config.save(file_path)


## The saved grips, by name.
func splits() -> Dictionary[String, int]:
	var result: Dictionary[String, int] = { }
	var config := _load()
	if config.has_section("splits"):
		for key: String in config.get_section_keys("splits"):
			result[key] = int(config.get_value("splits", key, 0))
	return result


## How each popped-out panel was, by panel number: rect, screen and mode.
func popped() -> Dictionary[int, Dictionary]:
	var result: Dictionary[int, Dictionary] = { }
	var config := _load()
	for section: String in config.get_sections():
		if not section.begins_with("panel_"):
			continue
		var rect: Variant = config.get_value(section, "rect", Rect2i())
		if not rect is Rect2i or not (rect as Rect2i).has_area():
			continue
		result[int(section.trim_prefix("panel_"))] = {
			"rect": rect,
			"screen": int(config.get_value(section, "screen", -1)),
			"mode": int(config.get_value(section, "mode", Window.MODE_WINDOWED)),
		}
	return result


func clear() -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)


func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(file_path)
	return config
