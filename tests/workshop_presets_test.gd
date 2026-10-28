extends TestScript
## Workshop presets on disk: one file per preset with every part inside, the guards on Default
## and the preset the game uses, and using a preset in the game, which changes only its entry
## of Active Presets.

const FOLDER := "res://test-results/workshop/presets"
const ACTIVE_COPY := "res://test-results/workshop/Active Presets.tres"
const SOURCE := "res://minigames/006_flappy_race/tuning/Default.tres"


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	for file: String in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER.path_join(file))
	var presets := WorkshopPresets.new(FOLDER)
	var preset := WorkshopTuning.copy(load(SOURCE))
	_check_saving(presets, preset)
	_check_guards(presets)
	_check_game_preset()


func _check_saving(presets: WorkshopPresets, preset: Resource) -> void:
	check(presets.save(preset, "Default").is_empty(), "Default saves")
	preset.flight.gravity = 80.0
	check(presets.save(preset, "Floaty").is_empty(), "A new preset saves")
	check(presets.names() == PackedStringArray(["Default", "Floaty"]), "Default is listed first")

	var text := FileAccess.get_file_as_string(presets.path("Floaty"))
	check(not text.contains("ext_resource type=\"Resource\""), "Every part is inside the file")
	var loaded := presets.load_preset("Floaty")
	check(loaded.flight.gravity == 80.0, "A saved value loads back")
	check(is_equal_approx(loaded.course.gap_height.sample(1.0), 7.0), "Curves load back")
	loaded.flight.gravity = 70.0
	check(presets.load_preset("Floaty").flight.gravity == 80.0, "A loaded copy is not shared")

	var broken := WorkshopTuning.copy(preset)
	broken.flight.hit_box_inset = 0.0
	broken.course.respawn_distance = 0.0
	check(not presets.save(broken, "Broken").is_empty(), "A preset with errors does not save")
	check(not presets.has("Broken"), "Nothing is written for it")
	check(not presets.save(preset, "bad/name").is_empty(), "A name must suit a file")


func _check_guards(presets: WorkshopPresets) -> void:
	var used := presets.path("Floaty")
	check(not presets.delete("Default", "").is_empty(), "Default cannot be deleted")
	check(not presets.rename("Floaty", "Other", used).is_empty(), "The used preset keeps its name")
	check(presets.duplicate_preset("Floaty", "Copy").is_empty(), "A preset duplicates")
	check(presets.rename("Copy", "Renamed", used).is_empty(), "Another preset renames")
	check(presets.has("Renamed") and not presets.has("Copy"), "The file moves")
	check(presets.delete("Renamed", used).is_empty() and not presets.has("Renamed"), "And deletes")


func _check_game_preset() -> void:
	var original := FileAccess.get_file_as_string(WorkshopGamePreset.ACTIVE_PRESETS_PATH)
	var file := FileAccess.open(ACTIVE_COPY, FileAccess.WRITE)
	file.store_string(original)
	file.close()

	var game := WorkshopGamePreset.new("flappy_race", ACTIVE_COPY)
	check(game.current_path() == SOURCE, "The preset the game uses is read")
	var floaty := FOLDER.path_join("Floaty.tres")
	check(game.use(floaty).is_empty(), "A preset is used in the game")
	check(game.current_path() == floaty, "The entry now names it")

	var before := original.split("\n")
	var after := FileAccess.get_file_as_string(ACTIVE_COPY).split("\n")
	var changed := 0
	for index: int in before.size():
		if before[index] != after[index]:
			changed += 1
	check(before.size() == after.size() and changed == 1, "Only that entry's line changes")
	var active: ActivePresets = ResourceLoader.load(
		ACTIVE_COPY,
		"",
		ResourceLoader.CACHE_MODE_IGNORE,
	)
	check(active.flappy_race.flight.gravity == 80.0, "A normal launch loads the used preset")
	check(active.validation_errors().is_empty(), "And Active Presets stays valid")
	var tilt := WorkshopGamePreset.new("tilt_shift_3d", ACTIVE_COPY)
	check(tilt.current_path().ends_with("005_3d_tilt_shift/tuning/Default.tres"), "Others stay")
	check(not WorkshopGamePreset.new("missing", ACTIVE_COPY).use(floaty).is_empty(), "No entry")
