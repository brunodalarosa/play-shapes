extends SceneTree
## A normal runtime process, launched only by the editor workshop.

const Preview := preload("res://addons/tilt_shift_workshop/workshop_preview.gd")
var _preview: Preview
var _session: String
var _elapsed: float = 0.0
var _ready_sent: bool = false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Workshop preview needs a temporary profile and roster size.")
		quit(1)
		return
	_session = args[0].get_base_dir()
	var profile: Resource = load(args[0])
	if not profile is TiltShiftTuning:
		push_error("Workshop preview profile cannot be loaded.")
		quit(1)
		return
	root.title = "Tilt Shift physics preview"
	root.size = Vector2i(1100, 760)
	root.content_scale_size = root.size
	# No game boot is run; remove the development launcher from this isolated preview.
	var launcher := root.get_node_or_null("DebugLauncher")
	if launcher != null:
		launcher.queue_free()
	_preview = Preview.new()
	_preview.profile = profile
	_preview.roster = args[1].to_int()
	root.add_child.call_deferred(_preview)


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed < 0.2 or not is_instance_valid(_preview):
		return false
	_elapsed = 0
	if not _ready_sent and is_instance_valid(_preview.arena) and _preview.arena.controller != null:
		var state := _preview.arena.controller.snapshot()
		var file := FileAccess.open(_session.path_join("ready.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(
				JSON.stringify(
					{
						"ready": true,
						"gameplay_arena": _preview.arena is TiltShiftArena,
						"round_count": state.round_count,
						"players": state.players.size(),
					}
				)
			)
			file.close()
			_ready_sent = true
	if FileAccess.file_exists(_session.path_join("stop")):
		_preview.stop()
		quit()
		return true
	return false
