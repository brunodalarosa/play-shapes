extends SceneTree
## Short deterministic review reel for the three loops and interruption states.

var _elapsed := 0.0
var _last_section := -1

func _initialize() -> void:
	change_scene_to_file("res://debug/character_animation_system.tscn")

func _process(delta: float) -> bool:
	if current_scene == null or current_scene.scene_file_path != "res://debug/character_animation_system.tscn":
		return false
	_elapsed += delta
	var section := floori(_elapsed / 2.0)
	if section != _last_section:
		_last_section = section
		match section:
			0, 1, 2:
				current_scene._reset_states()
				current_scene.get_node("%StylePicker").select(section)
				current_scene._select_style(section)
			3:
				current_scene._held = true
				current_scene._charge = 1.0
			4:
				current_scene._held = false
				current_scene._charge = 0.0
				current_scene._reaction(&"survived")
			5:
				current_scene._toggle_elimination()
	if _elapsed >= 12.0:
		quit(0)
	return false
