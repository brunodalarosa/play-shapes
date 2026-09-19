extends SceneTree
## Focused shared-screen contract checks. Human couch-distance readability and
## final mix/feel remain PS-029 gates, not claims made by this test.

const STAGE_SCENE := preload("res://minigames/dancer_simon_says.tscn")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := STAGE_SCENE.instantiate() as DancerSimonSaysStage
	var controller := stage.get_node(^"RoundController") as FlashPoseRoundController
	var presentation := stage.get_node(^"Presentation") as FlashPosePresentation
	var tuning := SimonSaysTuning.new()
	tuning.countdown_seconds = 0.0
	tuning.round_duration_seconds = 10.0
	tuning.pose_grace_seconds = 0.2
	tuning.charge_fill_seconds = 0.1
	tuning.flash_duration_seconds = 0.08
	tuning.music_resume_fade_seconds = 0.0
	controller.tuning = tuning
	presentation.tuning = tuning
	root.add_child(stage)
	await process_frame
	var start_msec := Time.get_ticks_msec()

	controller.inject_sequences([&"swing"], [&"left"], [0])
	var started := controller.start_round([
		{"player_id": "p1", "name": "One", "seat": 1, "state": "connected"},
		{"player_id": "p2", "name": "Two", "seat": 2, "state": "connected"},
	], start_msec)
	_check(started.accepted, "Presentation fixture starts")
	_check(presentation._player_animators.size() == 2, "Participating players populate stable seats")
	_check((presentation._player_labels[1] as Label).text.contains("One") and (presentation._player_labels[1] as Label).text.contains("♥♥"),
		"Player status uses a name and non-color life symbols")
	_check(presentation._music.stream == FlashPoseAudioCatalog.MUSIC_BY_STYLE[&"swing"],
		"Round style selects exactly one mapped music stream")

	controller.advance(start_msec)
	controller.advance(start_msec)
	_check(controller.phase_name() == &"genuine_stop_grace", "Injected genuine stop reaches presentation")
	_check(presentation._music.stream_paused and presentation._cue_panel.visible \
		and presentation._cue_label.text.contains("LEFT") and presentation._cue_label.text.contains("←"),
		"Genuine stop pauses music and shows text plus icon direction feedback")
	controller.submit_pose_input("p1", &"left", true, 1, start_msec)
	controller.submit_pose_input("p2", &"left", true, 1, start_msec)
	var player_animator := presentation._player_animators["p1"] as HybridCharacterAnimator
	_check(player_animator.semantic_state().pose_held \
		and player_animator.semantic_state().pose_direction == &"left",
		"Accepted phone press reaches the character as a held pose")
	controller.advance(start_msec + 50)
	_check(player_animator.semantic_state().pose_charge > 0.0,
		"Held phone input visibly advances character pose charge")
	controller.advance(start_msec + 200)
	_check(presentation._flashed_stop_ids.size() == 1, "Resolved genuine stop starts exactly one guarded flash")
	await create_timer(0.4).timeout
	_check(controller.phase_name() == &"dance" \
		and presentation._music.stream == FlashPoseAudioCatalog.MUSIC_BY_STYLE[&"swing"],
		"Matching flash completion resumes the dance with the same music stream")
	presentation._on_flash_requested(1, [])
	_check(presentation._flashed_stop_ids.size() == 1, "Duplicate flash callback cannot retrigger the effect")

	presentation._on_round_results_ready({
		"top_group_size": 1,
		"ranking": [
			{"player_id": "p1", "name": "One"},
			{"player_id": "p2", "name": "Two"},
		],
	})
	_check(presentation._results.visible and presentation._happy_names.text.contains("One") \
		and presentation._moody_names.text.contains("Two"),
		"Persistent results separate named winner and loser groups without points")
	var winner_heading := presentation._winner_panel.find_child("WinnersHeading", true, false) as Label
	var loser_heading := presentation._loser_panel.find_child("LosersHeading", true, false) as Label
	_check(winner_heading.text == "WINNERS" and loser_heading.text == "LOSERS",
		"Results use exact neutral winner and loser headings")
	_check(presentation._happy_names.text == "One" and presentation._moody_names.text == "Two",
		"Result player names have no decorative emoji prefixes")
	_check(is_equal_approx(presentation._winner_panel.anchor_bottom - presentation._winner_panel.anchor_top, 0.288) \
		and is_equal_approx(presentation._loser_panel.anchor_bottom - presentation._loser_panel.anchor_top, 0.288),
		"Each result panel uses 80 percent of the former 36-percent vertical footprint")
	_check(presentation._return_button.size.x >= 320.0 and presentation._return_button.size.y >= 64.0,
		"Return action is materially larger than the former 220 by 44 presentation")
	_check(presentation._loser_panel.anchor_bottom < presentation._return_button.anchor_top,
		"Result groups end above the centered return action")
	_check(not presentation._happy_names.text.to_lower().contains("score") \
		and not presentation._moody_names.text.to_lower().contains("score"),
		"Results do not introduce a scoreboard")
	_check(player_animator.semantic_state().result_mood == &"happy",
		"Winner retains the internal happy result mood")
	var loser_animator := presentation._player_animators["p2"] as HybridCharacterAnimator
	_check(loser_animator.semantic_state().result_mood == &"moody",
		"Loser retains the internal moody result mood")

	stage.queue_free()
	await process_frame
	if _failures == 0:
		print("Flash Pose presentation checks passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(description)
