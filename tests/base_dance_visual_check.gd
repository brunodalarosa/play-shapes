extends SceneTree
## Movie-writer entry point for reviewing only the living base-dance behavior.

func _initialize() -> void:
	_prepare.call_deferred()

func _prepare() -> void:
	change_scene_to_file("res://debug/character_animation_lab.tscn")
	await scene_changed
	current_scene.get_node("%AutoPreview").button_pressed = false
	current_scene.get_node("%HybridAnimator").set_jiggle_seed(11011)
