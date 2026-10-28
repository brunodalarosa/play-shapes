extends TestScript
## The race camera keeps its leader at the chosen share of the width, zooms only as far as the
## pack needs and its limits allow, eases to a new leader, and the bubbles on its left edge
## follow the racers behind it.


func _run() -> void:
	var camera := RaceCamera3D.new()
	root.add_child(camera)
	camera.current = true
	await process_frame
	var aspect := camera.view_aspect()

	camera.frame_race(Vector2(100, 17), PackedVector2Array(), 0.0)
	var shown := camera.visible_rect()
	check(
		is_equal_approx(camera.visible_height, 34.0) and is_equal_approx(shown.position.y, 0.0),
		"Alone, the leader gets the closest zoom from the ground to the top of the view",
	)
	check(
		is_equal_approx((100.0 - shown.position.x) / shown.size.x, 0.65),
		"The leader sits at 65% of the width",
	)
	var on_screen := camera.unproject_position(Vector3(100, 17, 0))
	var width := camera.get_viewport().get_visible_rect().size.x
	check(absf(on_screen.x / width - 0.65) < 0.01, "The camera draws the leader there too")

	var behind := 100.0 - (40.0 * aspect * 0.65 - 2.0)
	var pack := PackedVector2Array([Vector2(behind, 10)])
	camera.frame_race(Vector2(100, 17), pack, 0.0)
	check(
		absf(camera.visible_height - 40.0) < 0.001 and camera.shows(Vector2(behind, 10)),
		"A player behind zooms out just enough to fit",
	)

	var far := PackedVector2Array([Vector2(-500, 17), Vector2(100, 200)])
	camera.frame_race(Vector2(100, 17), far, 0.0)
	check(
		is_equal_approx(camera.visible_height, 54.0)
		and not camera.shows(Vector2(-500, 17)) and camera.shows(Vector2(100, 17)),
		"The zoom stops at 54 m; the leader stays in view and the straggler does not",
	)
	check(
		is_equal_approx(camera.visible_rect().position.y, 17.0 - 27.0),
		"Zoomed out, the view stays centred at half the view height",
	)

	camera.frame_race(Vector2(100, 17), PackedVector2Array(), 0.0)
	camera.frame_race(Vector2(100.2, 17), PackedVector2Array(), 1.0 / 60.0)
	check(is_equal_approx(camera.leader_x, 100.2), "A leader moving on is followed without lag")
	camera.frame_race(Vector2(80, 17), PackedVector2Array(), 1.0 / 60.0)
	check(
		camera.leader_x > 95.0 and camera.leader_x < 100.2,
		"A new leader far behind is eased to, not jumped to",
	)
	for frame: int in 180:
		camera.frame_race(Vector2(80, 17), PackedVector2Array(), 1.0 / 60.0)
	check(absf(camera.leader_x - 80.0) < 0.05, "The camera settles on the new leader")
	camera.queue_free()

	_check_bubbles()


func _check_bubbles() -> void:
	var bubbles := OffscreenBubbles.new()
	bubbles.size = Vector2(1920, 1080)
	root.add_child(bubbles)
	var red := Color("#E53935")
	var entries: Array[OffscreenBubbles.Entry] = [
		OffscreenBubbles.Entry.new("a", "Ana", red, "face_worried", 500.0),
		OffscreenBubbles.Entry.new("b", "Bo", red, "face_slightly_smiling", 510.0),
		OffscreenBubbles.Entry.new("c", "Cy", red, "face_dizzy", 5000.0),
	]
	bubbles.show_racers(entries)
	var a := bubbles.bubble_for("a")
	var b := bubbles.bubble_for("b")
	var c := bubbles.bubble_for("c")
	check(
		bubbles.shown_ids().size() == 3 and a.position.x == bubbles.edge,
		"Every racer behind gets a bubble on the left edge",
	)
	check(
		absf(a.position.y + a.size.y * 0.5 - 500.0) < 1.0
		and b.position.y >= a.position.y + a.size.y,
		"A bubble follows its racer's height, and neighbours stack instead of overlapping",
	)
	check(c.position.y + c.size.y <= 1080.0 - bubbles.edge, "A bubble stays on screen")

	bubbles.show_racers([entries[0]])
	check(bubbles.shown_ids() == PackedStringArray(["a"]), "A racer caught up loses the bubble")
	bubbles.queue_free()
