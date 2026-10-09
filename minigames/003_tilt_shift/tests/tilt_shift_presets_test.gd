extends TestScript


func _run() -> void:
	_test_mapping_and_ranges()
	_test_paddle_validation()
	_test_basket_validation()
	_test_saved_content()


func _test_mapping_and_ranges() -> void:
	var tuning := TiltShiftFixtures.tuning()
	check(tuning.validation_errors().is_empty(), "Default selected content is valid")
	tuning.round_count = 999
	tuning.round_duration_seconds = -5.0
	tuning.neighbor_distance = -1.0
	check(
		tuning.round_count == 24 and tuning.round_duration_seconds == 1.0
		and tuning.neighbor_distance == 0.01,
		"Individual rules tunables clamp to safe ranges",
	)
	check(
		_contains(tuning.validation_errors(), "map exactly 24 rounds"),
		"Round-count edits report the required basket mapping",
	)
	tuning = TiltShiftFixtures.tuning()
	tuning.baskets_by_round.append(tuning.baskets_by_round[0])
	check(_contains(tuning.validation_errors(), "found 5"), "Surplus round mappings are rejected")
	tuning.baskets_by_round.resize(4)
	tuning.baskets_by_round[1] = null
	check(
		_contains(tuning.validation_errors(), "round 2: select"),
		"Missing round reference identifies the numbered round",
	)
	tuning = TiltShiftFixtures.tuning()
	tuning.baskets_by_round[1].arena_width = 2.0
	check(
		_contains(tuning.validation_errors(), "round 2: basket floor width must match"),
		"Floor and paddle layout must share arena units and width",
	)
	tuning = TiltShiftFixtures.tuning()
	tuning.neighbor_distance = NAN
	check(not tuning.validation_errors().is_empty(), "Non-finite rules tuning fails validation")


func _test_paddle_validation() -> void:
	var layout := TiltShiftFixtures.tuning().paddle_layout
	layout.paddles.pop_back()
	check(_contains(layout.validation_errors(), "exactly ten"), "Missing paddles fail before play")
	layout = TiltShiftFixtures.tuning().paddle_layout
	layout.paddles[0].paddle_id = layout.paddles[1].paddle_id
	check(_contains(layout.validation_errors(), "duplicate paddle ID"), "Duplicate stable IDs fail")
	layout = TiltShiftFixtures.tuning().paddle_layout
	layout.paddles[0].team = TiltShiftTypes.Team.BLUE
	check(
		_contains(layout.validation_errors(), "five paddles to each team"),
		"Unequal team paddles fail",
	)
	layout.paddles[0].team = TiltShiftTypes.Team.TRASH
	check(_contains(layout.validation_errors(), "not trash"), "Paddles cannot belong to trash")
	layout = TiltShiftFixtures.tuning().paddle_layout
	layout.paddles[0].position = Vector2(2, -1)
	check(_contains(layout.validation_errors(), "outside the arena"), "Out-of-bounds anchors fail")
	layout.paddles[0].position = Vector2(INF, 0.0)
	check(_contains(layout.validation_errors(), "must be finite"), "Non-finite anchors fail")
	layout = TiltShiftFixtures.tuning().paddle_layout
	layout.arena_size = Vector2.ZERO
	check(_contains(layout.validation_errors(), "dimensions"), "Invalid arena dimensions fail")
	layout = TiltShiftFixtures.tuning().paddle_layout
	layout.paddles[0] = null
	check(_contains(layout.validation_errors(), "missing paddle"), "Missing paddle references fail")
	layout = TiltShiftFixtures.tuning().paddle_layout
	for paddle: TiltShiftPaddle in layout.paddles:
		paddle.position = Vector2(0.5, 0.2)
	check(
		layout.validation_errors().is_empty(),
		"Closeness stays inspectable without silently moving anchors or enforcing guide spacing",
	)


func _test_basket_validation() -> void:
	var basket := TiltShiftFixtures.tuning().baskets_by_round[0]
	check(basket.validation_errors().is_empty(), "Five-opening mirrored example is valid")
	basket.openings[0].width = 0.13
	check(
		_contains(basket.validation_errors(), "equal-width reflected"),
		"Unequal team widths fail",
	)
	basket = TiltShiftFixtures.tuning().baskets_by_round[0]
	basket.openings[2].center = 0.51
	check(_contains(basket.validation_errors(), "trash_center"), "Off-center unpaired trash fails")
	basket = TiltShiftFixtures.tuning().baskets_by_round[0]
	basket.openings[1].center = basket.openings[0].center
	check(_contains(basket.validation_errors(), "overlap"), "Overlapping openings fail")
	basket = TiltShiftFixtures.tuning().baskets_by_round[0]
	basket.openings[0].center = 0.01
	check(_contains(basket.validation_errors(), "outside the floor"), "Out-of-bounds opening fails")
	basket = TiltShiftFixtures.tuning().baskets_by_round[0]
	basket.openings[0].basket_id = basket.openings[1].basket_id
	check(_contains(basket.validation_errors(), "duplicate basket ID"), "Duplicate basket IDs fail")
	basket = TiltShiftFixtures.tuning().baskets_by_round[0]
	basket.openings[0].width = 0.0
	check(_contains(basket.validation_errors(), "positive width"), "Zero-width opening fails")
	basket.openings[0].center = NAN
	check(_contains(basket.validation_errors(), "finite"), "Non-finite opening fails")
	basket = TiltShiftFixtures.tuning().baskets_by_round[0]
	basket.openings.remove_at(4)
	check(
		_contains(basket.validation_errors(), "orange_left"),
		"Missing reflected team opening fails",
	)
	basket = TiltShiftFixtures.tuning().baskets_by_round[0]
	basket.openings[0] = null
	check(
		_contains(basket.validation_errors(), "missing opening 1"),
		"Missing opening reference fails",
	)
	basket = TiltShiftFixtures.tuning().baskets_by_round[0]
	var trash := basket.openings[2]
	trash.center = 0.45
	trash.width = 0.04
	var mirrored := trash.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as TiltShiftBasketOpening
	mirrored.basket_id = "trash_other"
	mirrored.center = 0.55
	basket.openings.append(mirrored)
	check(
		basket.validation_errors().is_empty(),
		"Paired off-center trash and six openings are valid",
	)


func _test_saved_content() -> void:
	var directory := "res://test-results/tilt-shift"
	DirAccess.make_dir_recursive_absolute(directory)
	var tuning := TiltShiftFixtures.tuning()
	tuning.paddle_layout.preset_name = "Saved arrangement"
	tuning.paddle_layout.paddles[0].position = Vector2(0.31, 0.105)
	tuning.neighbor_distance = 0.18
	tuning.physics.use_position_seed = true
	tuning.physics.position_seed = 491
	tuning.physics.paddle_bounce = 0.3
	tuning.physics.delivery_curve = PackedVector2Array(
		[Vector2(0, 0), Vector2(0.5, 2), Vector2(1, 0)]
	)
	var path := directory.path_join("reload.tres")
	if not check(ResourceSaver.save(tuning, path) == OK, "Selected content saves as a Resource"):
		return
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var reloaded := saved as TiltShiftTuning
	if not check(
		reloaded != null,
		"Selected content reloads without relying on the in-memory profile",
	):
		return
	check(reloaded.validation_errors().is_empty(), "Saved preset is still valid after reload")
	check(
		reloaded.physics.use_position_seed and reloaded.physics.position_seed == 491
		and is_equal_approx(reloaded.physics.paddle_bounce, 0.3)
		and reloaded.physics.delivery_curve == tuning.physics.delivery_curve,
		"Physics materials, delivery curve and seed survive Resource save/reload",
	)
	check(
		reloaded.paddle_layout.preset_name == "Saved arrangement"
		and reloaded.paddle_layout.paddles[0].position == Vector2(0.31, 0.105)
		and is_equal_approx(reloaded.neighbor_distance, 0.18),
		"Positions, names and designer proximity survive Resource save/reload",
	)
	check(
		reloaded.baskets_by_round.size() == 4
		and reloaded.baskets_by_round[3].openings[0].basket_id == "orange_left",
		"Numbered round mappings and stable basket IDs survive reload",
	)


func _contains(errors: PackedStringArray, part: String) -> bool:
	for error: String in errors:
		if error.contains(part):
			return true
	return false
