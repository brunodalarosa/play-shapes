extends SceneTree
## Run against an exported PCK with --main-pack, so no workspace files supply resources.


func _initialize() -> void:
	var excluded := [
		"res://addons/tilt_shift_workshop",
		"res://scratch",
		"res://docs/images/tilt-shift-workshop",
	]
	var failures := 0
	for path: String in excluded:
		if DirAccess.dir_exists_absolute(path):
			push_error("Editor-only folder exists in runtime PCK: " + path)
			failures += 1
	var profile: Resource = load("res://minigames/003_tilt_shift/tuning/Default.tres")
	if profile == null:
		push_error("Selected usable Tilt Shift content is missing from the runtime PCK.")
		failures += 1
	else:
		var errors: PackedStringArray = profile.call("validation_errors")
		if not errors.is_empty():
			push_error("Exported selected content is invalid: " + "\n".join(errors))
			failures += 1
		var selected: Resource = profile.get("paddle_layout")
		if selected.get("paddles").size() != 10:
			failures += 1
	print("Workshop isolated runtime PCK check: %d failures" % failures)
	quit(0 if failures == 0 else 1)
