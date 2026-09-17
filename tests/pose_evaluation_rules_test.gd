extends SceneTree

const Rules = preload("res://host/pose_evaluation_rules.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_full_hold_and_deadline()
	_test_correction_and_direction_reset()
	_test_release_tap_and_repress()
	_test_sequence_validation_and_late_input()
	_test_disconnect_resume_and_withdrawal()
	_test_elimination_record_and_semantic_output()
	if _failures == 0:
		print("Pose evaluation rules checks passed")
	quit(0 if _failures == 0 else 1)


func _test_full_hold_and_deadline() -> void:
	var rules := _rules_with_player("hold")
	var stop: Dictionary = rules.begin_stop(1, &"up", 0)
	_check(stop.accepted and stop.pose_revealed_msec == 0 and stop.evaluation_deadline_msec == 1200,
		"Default stop reveals immediately and evaluates after the 1.2 second grace")
	_check(rules.submit_input("hold", &"up", true, 1, 0).accepted,
		"A validated press is accepted at the opening boundary")
	_check(not rules.evaluate_stop(1, 1199).accepted, "Evaluation is rejected one millisecond early")
	var resolved: Dictionary = rules.evaluate_stop(1, 1200)
	var result: Dictionary = resolved.results[0]
	_check(result.success and result.charge == 1.0 and result.held,
		"Correct full charge held at the exact deadline succeeds")
	_check(result.evaluated_at_msec == 1200, "The result records the authoritative deadline")


func _test_correction_and_direction_reset() -> void:
	var rules := _rules_with_player("correct")
	rules.begin_stop(1, &"right", 0)
	rules.submit_input("correct", &"left", true, 1, 0)
	var corrected: Dictionary = rules.submit_input("correct", &"right", true, 2, 200)
	_check(corrected.accepted and corrected.state.direction == &"right" and corrected.state.charge == 0.0,
		"Changing direction during grace resets charge")
	var result: Dictionary = rules.evaluate_stop(1, 1200).results[0]
	_check(result.success, "A correction with a complete one-second hold before the deadline succeeds")


func _test_release_tap_and_repress() -> void:
	var rules := _rules_with_player("tap")
	rules.begin_stop(1, &"left", 0)
	rules.submit_input("tap", &"left", true, 1, 0)
	rules.submit_input("tap", &"left", false, 2, 400)
	var repressed: Dictionary = rules.submit_input("tap", &"left", true, 3, 500)
	_check(repressed.accepted and repressed.state.charge > 0.0 and repressed.state.charge < 0.4,
		"Same-direction repress continues from rapidly drained progress")
	var result: Dictionary = rules.evaluate_stop(1, 1200).results[0]
	_check(not result.success and result.reason == &"incomplete_charge",
		"A tap loses efficiency versus an uninterrupted hold")


func _test_sequence_validation_and_late_input() -> void:
	var rules := _rules_with_player("ordered")
	rules.begin_stop(7, &"down", 100)
	_check(rules.submit_input("ordered", &"down", true, 4, 100).accepted, "First ordered input is accepted")
	_check(rules.submit_input("ordered", &"down", true, 4, 200).code == &"stale_input",
		"Duplicate input sequence is rejected")
	_check(rules.submit_input("ordered", &"up", true, 3, 200).code == &"stale_input",
		"Out-of-order input sequence is rejected")
	_check(rules.submit_input("ordered", &"sideways", true, 5, 200).code == &"invalid_direction",
		"Unknown directions are rejected")
	_check(rules.submit_input("ordered", &"up", true, 5, 1301).code == &"late_input",
		"Input received after the host deadline is rejected")
	var resolved: Dictionary = rules.evaluate_stop(7, 1400)
	var before: Dictionary = resolved.results[0]
	_check(before.success and before.direction == &"down", "Rejected input cannot replace the valid held direction")
	_check(rules.submit_input("ordered", &"up", true, 6, 1400).code == &"no_active_stop",
		"Resolved stops cannot be mutated")
	var repeated: Dictionary = rules.evaluate_stop(7, 1500).results[0]
	_check(repeated == before, "Repeated evaluation returns the immutable authoritative result")


func _test_disconnect_resume_and_withdrawal() -> void:
	var rules := _rules_with_player("reconnect")
	_check(rules.add_player("leave", 0), "A second participating player can be added")
	rules.begin_stop(1, &"up", 0)
	rules.submit_input("reconnect", &"up", true, 1, 0)
	rules.submit_input("leave", &"up", true, 1, 0)
	_check(rules.set_player_connected("reconnect", false, 500), "Disconnect is recorded at host time")
	_check(not rules.semantic_state("reconnect").held, "Disconnect clears the held input")
	_check(rules.set_player_connected("reconnect", true, 600), "Resume restores connectivity")
	_check(not rules.semantic_state("reconnect").held, "Resume does not restore the stale hold")
	_check(rules.withdraw_player("leave", 700), "Explicit Leave becomes withdrawal")
	var results: Array = rules.evaluate_stop(1, 1200).results
	_check(results.size() == 1 and results[0].player_id == "reconnect",
		"Withdrawn players are excluded rather than failed")
	_check(not results[0].success and results[0].reason == &"no_input",
		"A resumed player with no new press follows the normal failure rule")


func _test_elimination_record_and_semantic_output() -> void:
	var rules := _rules_with_player("eliminated")
	rules.begin_stop(3, &"right", 0)
	var failed: Dictionary = rules.evaluate_stop(3, 1200).results[0]
	_check(not failed.success and failed.reason == &"no_input", "Missing input produces a normal failure record")
	var elimination: Dictionary = rules.mark_eliminated("eliminated", 3, 1200)
	_check(elimination.accepted and elimination.record.player_id == "eliminated",
		"The later lives owner can create an authoritative elimination record")
	var semantic: Dictionary = rules.semantic_state("eliminated")
	_check(semantic.eliminated and semantic.reaction == &"none" and not semantic.held,
		"Eliminated players remain represented by persistent animation semantics")
	_check(not rules.mark_eliminated("eliminated", 3, 1200).accepted,
		"Elimination cannot be recorded twice")


func _rules_with_player(player_id: String) -> RefCounted:
	var tuning := SimonSaysTuning.new()
	var rules := Rules.new(tuning)
	_check(rules.add_player(player_id, 0), "Player %s is registered in pose rules" % player_id)
	return rules


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(description)
