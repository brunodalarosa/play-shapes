extends TestScript
## Fails two checks on purpose, for test_script_test.gd.


func _run() -> void:
	check(true, "A passing check stays silent")
	check(false, "This check fails on purpose")
	check(false, "So does this one")
