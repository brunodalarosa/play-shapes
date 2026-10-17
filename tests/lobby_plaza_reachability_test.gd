extends TestScript
## With the active movement preset, a player climbs from the ground through each tier to the
## café roof using only the phone's stick and JUMP.

const WORLD := preload("res://scenes/lobby_playground_world.tscn")
const MAX_JUMP_FRAMES := 150
## How far inside a support's edge the climber takes off, in plane pixels.
const EDGE_MARGIN := 12.0


func _run() -> void:
	var world := WORLD.instantiate() as LobbyPlaygroundWorld
	root.add_child(world)
	world.reconcile(
		[
			{
				"player_id": "climber",
				"seat": 1,
				"name": "Climber",
				"state": "connected",
				"character_color": "#43A047",
			},
		]
	)
	var climber := world.character_for("climber")
	var climb: Array[Array] = [
		["GroundLanding", "ChairLeft", 1.0, false],
		["ChairLeft", "TableLeft", 1.0, true],
		["TableLeft", "Cafe", -1.0, true],
	]
	climber.position = Vector2(-3.9 * LobbyPlaygroundWorld.PIXELS_PER_UNIT, 0.0)
	for step: Array in climb:
		var from := world.surface_named(String(step[0]))
		var to := world.surface_named(String(step[1]))
		await _settle(climber)
		if not check(
			climber.motor.supporting_surface() == from,
			"The climber stands on %s" % from.name,
		):
			break
		if not await _jump_onto(climber, to, float(step[2]), bool(step[3])):
			check(false, "One jump carries the climber from %s to %s" % [from.name, to.name])
			break
		check(true, "One jump carries the climber from %s to %s" % [from.name, to.name])
	world.queue_free()
	await process_frame


func _settle(climber: LobbySquircle) -> void:
	climber.clear_input()
	for _frame: int in 20:
		await physics_frame


## Optionally runs to the near edge of the current support, releases JUMP once while holding
## toward the target, then centres over the target.
func _jump_onto(
	climber: LobbySquircle,
	target: PlatformSurface,
	direction: float,
	from_edge: bool,
) -> bool:
	var bounds := target.world_bounds()
	var support := climber.motor.supporting_surface().world_bounds()
	var edge := support.position.x + EDGE_MARGIN if direction < 0.0 else support.end.x - EDGE_MARGIN
	var hold := Vector2(direction, 0.0)
	for _frame: int in MAX_JUMP_FRAMES:
		if not from_edge or (climber.position.x - edge) * direction >= 0.0:
			break
		climber.motor.set_input(hold, "move", Time.get_ticks_msec())
		await physics_frame
	climber.motor.set_input(hold, "move", Time.get_ticks_msec())
	if not climber.motor.request_jump():
		return false
	for _frame: int in MAX_JUMP_FRAMES:
		var centre := bounds.get_center().x
		var steer := clampf((centre - climber.position.x) / 40.0, -1.0, 1.0)
		# Keep driving away until above the target, then steer to its middle.
		var above := climber.position.y < bounds.position.y
		var axis := steer if above else direction
		climber.motor.set_input(Vector2(axis, 0.0), "move", Time.get_ticks_msec())
		await physics_frame
		if climber.motor.supporting_surface() == target:
			return true
	return false
