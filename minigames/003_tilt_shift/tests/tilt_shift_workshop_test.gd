extends TestScript

const Model := preload("res://addons/tilt_shift_workshop/workshop_model.gd")
const Geometry := preload("res://addons/tilt_shift_workshop/workshop_geometry.gd")
const Graph := preload("res://addons/tilt_shift_workshop/workshop_delivery_graph.gd")
const DEFAULT := "res://minigames/003_tilt_shift/tuning/Default.tres"
const RELOAD := "res://minigames/003_tilt_shift/tests/tilt_shift_workshop_reload_check.gd"


func _run() -> void:
	var hash_before := FileAccess.get_sha256(DEFAULT)
	var draft := Model.new()
	check(draft.load_profile(DEFAULT), "Workshop loads the selected runtime profile")
	var cached: TiltShiftTuning = load(DEFAULT)
	var original := cached.paddle_layout.paddles[0].position
	draft.begin_edit()
	draft.move_paddle(0, Vector2(0.213, 0.147))
	draft.end_edit()
	check(
		draft.profile.paddle_layout.paddles[0].position.is_equal_approx(Vector2(0.21, 0.15)),
		"Drag coordinates snap in the same width units on both axes",
	)
	check(
		cached.paddle_layout.paddles[0].position == original,
		"Editing does not mutate ResourceLoader cached content",
	)
	draft.undo()
	check(
		draft.profile.paddle_layout.paddles[0].position == original,
		"Undo restores the entire edit",
	)
	draft.redo()
	check(
		draft.profile.paddle_layout.paddles[0].position.is_equal_approx(Vector2(0.21, 0.15)),
		"Redo restores snapped coordinates",
	)
	draft.load_profile(DEFAULT)
	var original_center := draft.basket().openings[0].center
	var other := draft.reflected_index(0)
	check(other == 4, "Example pairs outer Orange with reflected Blue")
	draft.begin_edit()
	check(draft.resize_basket(0, 0.146), "Width edit finds a reflected partner")
	draft.end_edit()
	check(
		is_equal_approx(draft.basket().openings[0].width, 0.15)
		and is_equal_approx(draft.basket().openings[other].width, 0.15),
		"One width edit snaps and changes both team openings",
	)
	draft.begin_edit()
	check(draft.move_basket(0, 1.0 - original_center), "Paired reorder is supported")
	draft.end_edit()
	check(
		is_equal_approx(draft.basket().openings[other].center, original_center),
		"Paired reorder moves the existing stable partner instead of silently re-pairing",
	)
	check(
		draft.basket().validation_errors().is_empty(),
		"Reordered nonoverlapping pairs stay valid",
	)
	draft.undo()
	check(
		is_equal_approx(draft.basket().openings[0].center, original_center),
		"Paired move is one undo operation",
	)
	draft.basket().openings[other].center = 0.79
	check(
		not draft.resize_basket(0, 0.10),
		"Missing reflected partner cannot change team width silently",
	)
	check(not draft.move_basket(0, 0.20), "Missing reflected partner blocks paired dragging")
	check(
		draft.move_basket(other, 1.0 - original_center, false),
		"Single-opening draft repair stays available",
	)
	draft.load_profile(DEFAULT)
	draft.profile.paddle_layout.paddles[0].position = Vector2(0.10, 0.10)
	draft.profile.paddle_layout.paddles[1].position = Vector2(0.10, 0.18)
	var before := draft.profile.paddle_layout.paddles[0].position
	var guides := Geometry.inspect(draft.profile, 0.005)
	check(not guides.warnings.is_empty(), "Asymmetry and swept overlaps are guide warnings")
	check(
		draft.profile.paddle_layout.paddles[0].position == before,
		"Guides never relocate content",
	)
	check(
		draft.profile.validation_errors().is_empty(),
		"Paddle guide warnings do not invalidate presets",
	)
	var vertical := false
	for edge: TiltShiftState.Neighbor in guides.neighbors:
		if edge.first_id == draft.profile.paddle_layout.paddles[0].paddle_id \
				and edge.second_id == draft.profile.paddle_layout.paddles[1].paddle_id:
			vertical = true
	check(vertical, "Neighbor guides include paddles above and below")
	check(guides.clearances.size() == 15, "Five wall and ten pair clearances are inspectable")
	draft.profile.round_count = 5
	check(
		not draft.profile.validation_errors().is_empty(),
		"Round-count increase exposes missing mapping",
	)
	draft.profile.round_count = 3
	check(
		draft.profile.baskets_by_round.size() == 4,
		"Round-count decrease retains stale mappings visibly",
	)
	check(not draft.profile.validation_errors().is_empty(), "Stale mapping blocks launch")
	draft.remove_round_mapping(3)
	check(
		draft.profile.validation_errors().is_empty(),
		"Explicit stale-map removal repairs content",
	)
	_persistence(draft)
	_delivery(draft)
	_mapped_authoring(draft)
	check(
		FileAccess.get_sha256(DEFAULT) == hash_before,
		"All draft operations leave saved defaults unchanged",
	)


func _mapped_authoring(draft: Model) -> void:
	draft.load_profile(DEFAULT)
	check(draft.layouts.size() == 2, "Workshop retains the A/B layout library")
	draft.select_layout(1)
	draft.begin_edit()
	draft.profile.paddle_layout.player_length = 0.22
	draft.end_edit()
	check(
		draft.profile.layouts_by_round[1].player_length == 0.22
		and draft.profile.layouts_by_round[0].player_length == 0.20,
		"Editing B changes its repeated map references without changing A",
	)
	draft.undo()
	check(draft.profile.paddle_layout.player_length == 0.18, "Undo restores selected B dimensions")
	var unmapped := TiltShiftPaddleLayout.new()
	draft.layouts.append(unmapped)
	draft.select_layout(2)
	check(
		draft.profile.validation_errors().is_empty(),
		"An unassigned editing layout does not alter mapped launch validity",
	)
	var path := Model.DRAFTS.path_join("mapped-profile.tres")
	check(draft.save_content(path, "profile", true) == OK, "Mapped draft saves")
	check(draft.load_profile(path), "Mapped draft reloads")
	check(draft.layouts.size() == 2, "Unassigned layout drafts are saved separately")
	check(
		draft.profile.layouts_by_round[0] == draft.profile.layouts_by_round[2]
		and draft.profile.layouts_by_round[1] == draft.profile.layouts_by_round[3],
		"A/B/A/B preserves shared identities after save and reload",
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _persistence(draft: Model) -> void:
	draft.load_profile(DEFAULT)
	draft.basket().preset_name = "First layout"
	var second: TiltShiftBasketPreset = draft.basket().duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	second.preset_name = "Second layout"
	second.openings[0].width = 0.10
	second.openings[4].width = 0.10
	draft.baskets.append(second)
	draft.assign_round(1, 1)
	var path := Model.DRAFTS.path_join("persistence-profile.tres")
	check(draft.save_content(path, "profile", true) == OK, "Explicit draft profile save succeeds")
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray(
			[
				"--headless",
				"--path",
				ProjectSettings.globalize_path("res://"),
				"--script",
				RELOAD,
				"--",
				ProjectSettings.globalize_path(path),
			]
		),
		output,
		true,
	)
	check(
		exit_code == 0,
		"Fresh process preserves multiple baskets, IDs, widths and round references: %s"
		% "".join(output),
	)
	check(draft.load_profile(path), "Saved profile reopens in the workshop")
	check(draft.baskets.size() == 2, "Both numbered-round preset identities survive reload")
	var first_layout := Model.CONTENT.path_join("layouts/WorkshopFixtureOne.tres")
	var second_layout := Model.CONTENT.path_join("layouts/WorkshopFixtureTwo.tres")
	draft.profile.paddle_layout.preset_name = "First paddle layout"
	var first_position := draft.profile.paddle_layout.paddles[0].position
	check(draft.save_content(first_layout, "layout") == OK, "First named paddle layout saves")
	draft.profile.paddle_layout.preset_name = "Second paddle layout"
	draft.profile.paddle_layout.paddles[0].position = Vector2(0.22, 0.12)
	check(draft.save_content(second_layout, "layout") == OK, "Second named paddle layout saves")
	check(draft.load_content(first_layout, "layout"), "First named paddle layout reopens")
	check(
		draft.profile.paddle_layout.paddles[0].position == first_position,
		"Loading another layout preserves independently saved coordinates",
	)
	check(draft.load_content(second_layout, "layout"), "Second named paddle layout reopens")
	check(
		draft.profile.paddle_layout.paddles[0].position.is_equal_approx(Vector2(0.22, 0.12)),
		"Multiple named paddle presets retain their own geometry and selection",
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(first_layout))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(second_layout))
	var usable := Model.CONTENT.path_join("baskets/WorkshopFixture.tres")
	check(
		draft.save_content(usable, "basket") == OK,
		"Valid basket saves as a usable named Resource",
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(usable))
	var malformed: TiltShiftBasketPreset = draft.basket()
	malformed.openings[2].center = 0.6
	check(
		draft.save_content(usable, "basket") == ERR_INVALID_DATA,
		"Off-center unmatched trash cannot save as usable content",
	)
	check(not FileAccess.file_exists(usable), "Rejected usable save leaves no content file")
	var invalid := Model.DRAFTS.path_join("invalid-baskets.tres")
	check(
		draft.save_content(invalid, "basket", true) == OK,
		"Invalid arrangement can be saved as a draft",
	)
	check(draft.load_content(invalid, "basket"), "Invalid draft can be reloaded for repair")
	check(
		not draft.basket().validation_errors().is_empty(),
		"Reloaded invalid draft still reports validity errors",
	)
	check(
		draft.save_content("res://scratch/../unsafe.tres", "basket", true) == ERR_INVALID_PARAMETER,
		"Draft save cannot escape the owned scratch boundary",
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid))


func _delivery(draft: Model) -> void:
	draft.load_profile(DEFAULT)
	draft.profile.physics.ball_count = 37
	draft.profile.physics.delivery_curve = PackedVector2Array(
		[Vector2(0, 1), Vector2(0.2, 0), Vector2(0.8, 0), Vector2(1, 1)]
	)
	var graph := Graph.new()
	graph.setup(draft)
	check(graph.schedule.size() == 37, "Workshop schedule retains the selected total budget")
	var empty_gap := true
	var cutoff := draft.profile.physics.delivery_cutoff_seconds
	var duration := draft.profile.round_duration_seconds - cutoff
	for offset: int in graph.schedule:
		var progress := float(offset) / (duration * 1000.0)
		if progress > 0.2 and progress < 0.8:
			empty_gap = false
	check(empty_gap, "Workshop density uses the actual scheduler and preserves zero-intensity gaps")
	draft.profile.physics.delivery_curve = PackedVector2Array([Vector2(0, 0), Vector2(1, 0)])
	graph.refresh()
	check(
		graph.schedule.is_empty(),
		"Invalid positive-budget zero curve has no misleading preview schedule",
	)
	graph.free()
