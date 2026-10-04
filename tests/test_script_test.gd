extends TestScript
## Runs small scripts that pass, fail and break on purpose, each in a Godot of its own, and
## checks what the base makes of them.


class FixtureRun:
	var exit_code := 0
	var output := ""


func _run() -> void:
	var passing := _run_fixture("passing")
	check(passing.exit_code == 0, "A script whose checks pass exits with 0")
	check(passing.output.contains("passing: 0 failures"), "A passing script reports no failures")
	check(not passing.output.contains("ERROR"), "A passing check prints nothing")

	var failing := _run_fixture("failing_check")
	check(failing.exit_code == 1, "A failed check makes the script exit with 1")
	check(
		failing.output.contains("ERROR: This check fails on purpose"),
		"A failed check prints its description as an error",
	)
	check(
		failing.output.contains("failing_check: 2 failures"),
		"A failed check does not stop the checks after it",
	)

	var broken := _run_fixture("script_error")
	check(broken.exit_code == 1, "A script error makes the script exit with 1")
	check(broken.output.contains("SCRIPT ERROR"), "A script error is printed")
	check(
		broken.output.contains("script_error: 1 failures"),
		"A script error ends the test where it happened and counts as one failure",
	)


func _run_fixture(fixture: String) -> FixtureRun:
	var arguments := ["--headless", "--path", ProjectSettings.globalize_path("res://")]
	arguments.append_array(["--script", "res://tests/fixtures/%s.gd" % fixture])

	var lines: Array = []
	var result := FixtureRun.new()
	result.exit_code = OS.execute(OS.get_executable_path(), arguments, lines, true)
	result.output = "\n".join(lines)

	return result
