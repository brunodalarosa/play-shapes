extends SceneTree
## Launched by the persistence test to prove reload without a ResourceLoader cache.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var profile: TiltShiftTuning = load(args[0])
	var first := profile.baskets_by_round[0]
	var second := profile.baskets_by_round[1]
	var valid := (
		(
			(
				profile.validation_errors().is_empty() and first != second \
						and first == profile.baskets_by_round[2]
				and first == profile.baskets_by_round[3]
			) \
					and first.preset_name == "First layout"
			and second.preset_name == "Second layout"
		) \
				and is_equal_approx(second.openings[0].width, 0.10) \
				and first.openings[0].basket_id == "orange_left" \
				and first.openings[0].team == 0
		and first.openings[4].team == 1
	) \
			and is_equal_approx(first.openings[0].center, 0.10) \
			and profile.paddle_layout.paddles.size() == 10
	print("Workshop fresh-process reload: ", valid)
	quit(0 if valid else 1)
