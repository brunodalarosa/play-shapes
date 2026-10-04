extends TestScript
## Passes, for test_script_test.gd.


func _run() -> void:
	check(true, "A passing check stays silent")
