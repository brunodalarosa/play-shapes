class_name ActivePresets
extends Resource
## Project-level selector. Assign committed named presets here, save, then relaunch.

@export_group("Minigames")
## Active Bubbles and jellyfishes 3D preset. Restore the Default.tres in the minigame's tuning
## folder for provisional baseline values.
@export var bubbles_3d: Bubbles3DTuning

## Active Tilt Shift rules/content preset. Default values are provisional, pending owner play.
@export var tilt_shift: TiltShiftTuning

## Active Tilt Shift 3D rules/content preset. Default values are provisional, pending owner play.
@export var tilt_shift_3d: TiltShift3DTuning

@export_group("Shared categories")
## Active host networking/session preset. Browser-only values intentionally remain in
## web/src/app.ts.
@export
var networking: NetworkingTuning

## Active Playground lobby movement preset. Default values are provisional, pending owner play.
@export var lobby_movement: LobbyMovementTuning


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if bubbles_3d == null:
		errors.append("Active Presets: Bubbles 3D preset is missing.")
	else:
		errors.append_array(bubbles_3d.validation_errors())
	if tilt_shift == null:
		errors.append("Active Presets: Tilt Shift preset is missing.")
	else:
		errors.append_array(tilt_shift.validation_errors())
	if tilt_shift_3d == null:
		errors.append("Active Presets: Tilt Shift 3D preset is missing.")
	else:
		errors.append_array(tilt_shift_3d.validation_errors())
	if networking == null:
		errors.append("Active Presets: Networking preset is missing.")
	else:
		errors.append_array(networking.validation_errors())
	if lobby_movement == null:
		errors.append("Active Presets: Lobby movement preset is missing.")
	else:
		errors.append_array(lobby_movement.validation_errors())
	return errors
