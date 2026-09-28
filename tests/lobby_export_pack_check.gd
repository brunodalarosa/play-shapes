extends SceneTree
## Run after a local export to confirm the new offline controller and sheets reached the PCK.

const Policy := preload("res://addons/standalone_build/standalone_build_policy.gd")
const PACK := "res://builds/standalone/windows-x86_64/Play Shapes.pck"

func _initialize() -> void:
	var path := ProjectSettings.globalize_path(PACK)
	var missing := Policy.pack_contains_required_browser_paths(path)
	missing.append_array(Policy.pack_contains_required_runtime_paths(path))
	if not missing.is_empty():
		push_error("Export is missing: %s" % ", ".join(missing))
		quit(1)
		return
	print("Standalone PCK includes required browser and runtime paths")
	quit(0)
