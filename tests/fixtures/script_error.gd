extends TestScript
## Runs into a script error on purpose, after an await, for test_script_test.gd.


func _run() -> void:
	await process_frame

	var missing: Node = null
	print(missing.name)

	check(false, "This line is never reached")
