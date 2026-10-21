extends TestScript

const Model := preload("res://addons/tilt_shift_3d_workshop/workshop_model.gd")
const DEFAULT := "res://minigames/005_3d_tilt_shift/tuning/Default.tres"


func _run() -> void:
	var draft := Model.new()
	check(draft.load_profile(DEFAULT), "Workshop loads the selected runtime profile")
	var layout := draft.profile.paddle_layout
	layout.arena_size = Vector2(1.0, 0.5625)
	# Three anchors on the left, two on the right and one on the center line.
	var points: Array[Vector2] = [
		Vector2(0.17, 0.15),
		Vector2(0.83, 0.15),
		Vector2(0.43, 0.50),
		Vector2(0.57, 0.50),
		Vector2(0.30, 0.35),
		Vector2(0.50, 0.25),
	]
	var paddles: Array[TiltShift3DPaddle] = []
	for index: int in points.size():
		var paddle := TiltShift3DPaddle.new()
		paddle.paddle_id = "test_%d" % index
		paddle.position = points[index]
		paddles.append(paddle)
	layout.paddles = paddles
	draft.snap_enabled = true
	draft.position_snap = 0.01

	var labels := draft.paddle_labels()
	check(
		labels == PackedStringArray(["A2", "B1", "A0", "B0", "A1", "C0"]),
		"Labels give the side, then the rank counted up from the floor: %s" % labels,
	)
	check(draft.paddle_partner(2) == 3, "A0 pairs with B0")
	check(draft.paddle_partner(3) == 2, "B0 pairs with A0")
	check(draft.paddle_partner(0) == -1, "An anchor without an opposite rank has no partner")
	check(draft.paddle_partner(5) == -1, "A center anchor has no partner")

	draft.move_paddle(2, Vector2(0.40, 0.45))
	check(
		paddles[3].position == points[3],
		"Without forced symmetry a move leaves the paired paddle alone",
	)

	draft.set_force_paddle_symmetry(true)
	check(_mirrored(draft, 2, 3), "Turning symmetry on mirrors B0 from A0")
	check(_mirrored(draft, 4, 1), "Turning symmetry on mirrors B1 from A1")
	check(paddles[0].position == points[0], "A paddle without a partner keeps its place")
	# Undo swaps in a copy of the profile, so the paddles have to be read again.
	draft.undo()
	check(
		draft.profile.paddle_layout.paddles[3].position == points[3],
		"One undo reverts the whole correction",
	)
	draft.redo()
	paddles = draft.profile.paddle_layout.paddles
	check(_mirrored(draft, 2, 3), "Redo restores the correction")

	draft.move_paddle(1, Vector2(0.66, 0.43))
	check(
		paddles[4].position.is_equal_approx(Vector2(0.34, 0.43)),
		"Moving a B paddle moves its A partner to the mirrored point",
	)
	draft.move_paddle(2, Vector2(0.40, 0.30))
	check(_mirrored(draft, 2, 3), "Moving an A paddle moves its B partner")
	var reordered := draft.paddle_labels()
	check(
		reordered[2] == "A1" and reordered[3] == "B1" and _mirrored(draft, 4, 1),
		"Pairs stay matched when a move changes the ranks",
	)

	draft.set_force_paddle_symmetry(false)
	draft.move_paddle(2, Vector2(0.20, 0.50))
	check(not _mirrored(draft, 2, 3), "Unchecking lets a designer break the symmetry")
	draft.set_force_paddle_symmetry(true)
	var restored := draft.paddle_labels()
	for index: int in paddles.size():
		var partner := draft.paddle_partner(index)
		if restored[index].begins_with("A") and partner >= 0:
			check(_mirrored(draft, index, partner), "Checking again corrects %s" % restored[index])


func _mirrored(draft: Model, source: int, partner: int) -> bool:
	var paddles := draft.profile.paddle_layout.paddles
	var width := draft.profile.paddle_layout.arena_size.x
	var expected := Vector2(width - paddles[source].position.x, paddles[source].position.y)
	return paddles[partner].position.is_equal_approx(expected)
