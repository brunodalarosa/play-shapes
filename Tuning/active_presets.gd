class_name ActivePresets
extends Resource
## Project-level selector. Assign committed named presets here, save, then relaunch.

@export_group("Minigames")
## Active Simon Says umbrella preset. Restore Default.tres to return to known-good values.
@export
var simon_says: SimonSaysTuning

@export_group("Shared categories")
## Active host networking/session preset. Browser-only values intentionally remain in web/src/app.ts.
@export
var networking: NetworkingTuning

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if simon_says == null:
		errors.append("Active Presets: Simon Says preset is missing.")
	else:
		errors.append_array(simon_says.validation_errors())
	if networking == null:
		errors.append("Active Presets: Networking preset is missing.")
	else:
		errors.append_array(networking.validation_errors())
	return errors
