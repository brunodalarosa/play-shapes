extends TestScript

const Preview := preload("res://addons/tilt_shift_workshop/workshop_preview.gd")
const DEFAULT := "res://minigames/003_tilt_shift/tuning/Default.tres"

var _positions := PackedFloat32Array()
var _catches: int = 0


func _run() -> void:
	var disk_hash := FileAccess.get_sha256(DEFAULT)
	var profile := TiltShiftFixtures.tuning(2)
	profile.round_duration_seconds = 3
	profile.physics.ball_count = 12
	profile.physics.gravity = 2
	profile.physics.entry_speed = 1
	profile.physics.use_position_seed = true
	profile.physics.position_seed = 71
	var preview := Preview.new()
	preview.profile = profile
	preview.roster = 10
	root.add_child(preview)
	await process_frame
	await process_frame
	preview.arena.ball_spawned.connect(_record_spawn)
	preview.arena.ball_removed.connect(_record_catch)
	check(
		preview.arena is TiltShiftArena and preview.arena.controller != null,
		"Workshop preview starts the actual runtime arena and host rules",
	)
	var state := preview.arena.controller.snapshot()
	check(state.players.size() == 10, "Preview supports the ten-player roster")
	var player := state.players[0]
	check(preview.set_angle(player.player_id, 720), "Designer accepts continuous multiple turns")
	for body: TiltShiftPaddleBody in preview.arena.paddle_bodies():
		if player.paddle_ids.has(body.paddle_id):
			check(
				is_equal_approx(body.target_angle, TAU * 2),
				"Designer controls reach the same physical paddle targets as gameplay",
			)
	check(preview.set_angle(player.player_id, -360), "Designer reversal retains unwrapped angle")
	await create_timer(3.1).timeout
	check(preview.arena.spawned_count == 12, "Runtime preview delivers the selected curve budget")
	check(_catches > 0, "Native falling balls reach runtime basket catches")
	check(
		preview.arena.live_balls().is_empty(),
		"Immediate deadline clears remaining preview balls",
	)
	var positions := _positions.duplicate()
	check(preview.arena.start_next_round().accepted, "Preview runs mapped numbered rounds")
	preview.stop()
	check(
		preview.arena.controller == null and preview.arena.live_balls().is_empty(),
		"Stop clears temporary scores, controller and balls",
	)
	check(preview.arena.paddle_bodies().is_empty(), "Stop clears preview paddle bodies")
	_positions.clear()
	check(preview.restart(), "Restart starts a fresh shift")
	await create_timer(0.7).timeout
	var repeated := true
	for index: int in _positions.size():
		if index >= positions.size() or not is_equal_approx(_positions[index], positions[index]):
			repeated = false
	check(
		not _positions.is_empty() and repeated,
		"Restart repeats the selected seed's spawn positions",
	)
	check(
		preview.arena.controller.snapshot().scores == [0, 0],
		"Restart resets cumulative preview scores",
	)
	preview.stop()
	profile.physics.ball_bounce = 0.5
	profile.physics.paddle_bounce = 0.4
	check(preview.restart(), "Same preview can start with nonzero selected contact restitution")
	await create_timer(0.3).timeout
	var balls := preview.arena.live_balls()
	check(
		not balls.is_empty() and is_equal_approx(balls[0].physics_material_override.bounce, 0.5),
		"Preview rigid balls receive selected runtime materials",
	)
	check(
		is_equal_approx(preview.arena.paddle_bodies()[0].physics_material_override.bounce, 0.4),
		"Preview paddles receive selected nonzero materials",
	)
	preview.arena.ball_spawned.disconnect(_record_spawn)
	preview.arena.ball_removed.disconnect(_record_catch)
	preview.queue_free()
	await process_frame
	await physics_frame
	check(
		FileAccess.get_sha256(DEFAULT) == disk_hash,
		"Preview lifecycle leaves saved content unchanged",
	)
	var host := root.get_node_or_null("SessionHost")
	check(host == null or not host.get("running"), "Preview never starts phone network services")


func _record_spawn(ball: TiltShiftBall) -> void:
	_positions.append(ball.position.x)


func _record_catch(_handle: TiltShiftState.BallHandle, basket: String) -> void:
	if not basket.is_empty():
		_catches += 1
