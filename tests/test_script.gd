class_name TestScript
extends SceneTree
## The base of every script in tests/ that runs to an end: a test or a render helper.
##
## Override [method _run] and call [method check] in it. The script fails when a check
## fails or when anything logs an error while it runs, and it always quits, also after a
## script error.


## Counts the errors Godot logs, which covers a failed check, a script error and an error
## raised by the code under test.
class ErrorCounter:
	extends Logger

	var count := 0
	var _lock := Mutex.new()


	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		_code: String,
		_rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace],
	) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return

		# Godot logs from any thread.
		_lock.lock()
		count += 1
		_lock.unlock()


var _errors := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	_start.call_deferred()


## The body of the test. It may await.
func _run() -> void:
	pass


## Records a failure under [param description] when [param condition] is false. Returns the
## condition, so a test can stop where going on makes no sense.
func check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)

	return condition


func _start() -> void:
	# A script error ends _run early and returns here, so the script still quits.
	await _run()

	await _release_scene()

	OS.remove_logger(_errors)
	var name := (get_script() as Script).resource_path.get_file().get_basename()
	print("%s: %d failures" % [name, _errors.count])
	quit(0 if _errors.count == 0 else 1)


## Frees what the test put in the tree and lets the servers let go of it, so that Godot
## reports nothing held at exit.
func _release_scene() -> void:
	# Last added, first freed, as Godot does at exit: a scene leaves while the autoloads it
	# says goodbye to are still there.
	var children := root.get_children()
	children.reverse()

	for child: Node in children:
		child.queue_free()

	await process_frame

	# A sound that was still playing is let go by the audio thread, in the mix after the one
	# that fades it out. Frames pass much faster than mixes when nothing is drawn.
	for mix: int in 2:
		await _next_audio_mix()

	await process_frame


func _next_audio_mix() -> void:
	var since_mix := AudioServer.get_time_since_last_mix()

	# Mixes come many times a second. The limit only keeps a script from waiting forever on
	# an audio driver that never mixes.
	var give_up_at := Time.get_ticks_msec() + 1000

	while AudioServer.get_time_since_last_mix() >= since_mix:
		if Time.get_ticks_msec() > give_up_at:
			return

		since_mix = AudioServer.get_time_since_last_mix()
		await process_frame
