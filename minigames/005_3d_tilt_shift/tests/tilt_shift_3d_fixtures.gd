class_name TiltShift3DFixtures
extends RefCounted


static func players(count: int) -> Array[TiltShift3DState.Player]:
	var result: Array[TiltShift3DState.Player] = []
	for index: int in count:
		var player := TiltShift3DState.Player.new()
		player.player_id = "player_%d" % index
		player.player_name = "Player %d" % index
		player.character_color = "orange"
		player.seat = index + 1
		result.append(player)
	return result


static func tuning(rounds: int = 4) -> TiltShift3DTuning:
	var default_preset: TiltShift3DTuning = load(
		"res://minigames/005_3d_tilt_shift/tuning/Default.tres"
	)
	var result: TiltShift3DTuning = default_preset.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	result.layouts_by_round.clear()
	var layout: TiltShift3DPaddleLayout = load(
		"res://minigames/005_3d_tilt_shift/tuning/layouts/Mirrored.tres"
	)
	result.paddle_layout = layout.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	result.physics.negative_ball_count = 0
	result.physics.ball_radius = 0.006
	result.physics.gravity = 0.4
	result.physics.entry_speed = 0.1
	result.physics.delivery_cutoff_seconds = 0.0
	result.round_duration_seconds = 1.0
	result.round_count = rounds
	var basket := result.baskets_by_round[0]
	result.baskets_by_round.clear()
	for index: int in rounds:
		result.baskets_by_round.append(basket.duplicate_deep(Resource.DEEP_DUPLICATE_ALL))
	return result


static func team_paddles(layout: TiltShift3DPaddleLayout, team: int) -> Array[TiltShift3DPaddle]:
	var result: Array[TiltShift3DPaddle] = []
	for paddle: TiltShift3DPaddle in layout.paddles:
		if paddle.team == team:
			result.append(paddle)
	return result


static func graph(paddles: Array[TiltShift3DPaddle], bits: int) -> Array[TiltShift3DState.Neighbor]:
	var result: Array[TiltShift3DState.Neighbor] = []
	var bit := 0
	for first: int in 5:
		for second: int in range(first + 1, 5):
			if bits & (1 << bit):
				var edge := TiltShift3DState.Neighbor.new()
				edge.first_id = paddles[first].paddle_id
				edge.second_id = paddles[second].paddle_id
				edge.distance = 0.1
				result.append(edge)
			bit += 1
	return result
