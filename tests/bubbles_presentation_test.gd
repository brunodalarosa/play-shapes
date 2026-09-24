extends SceneTree
## Scene, event mapping, timer, warning and dense results contracts.

const SCENE: PackedScene = preload("res://minigames/bubbles_and_jellyfishes.tscn")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var view := SCENE.instantiate() as BubblesPresentation
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var tuning := BubblesTuning.new()
	tuning.instructions_seconds = 0.0
	tuning.countdown_seconds = 3.0
	tuning.round_duration_seconds = 20.0
	tuning.starting_jellyfish = 0
	tuning.pufferfish_warning_enabled = false
	tuning.music_gain_db = -14.0
	tuning.sfx_gain_db = -7.0
	view.controller.tuning = tuning
	var roster: Array = []
	for index: int in 10:
		roster.append({"player_id": "p%d" % index, "name": "Player %d" % index, "seat": index + 1})
	var now := Time.get_ticks_msec()
	_check(view.start_round(roster, now).accepted, "Ten-player scene starts")
	_check(view.player_arena.bubble_ids().size() == 10, "All ten named bubble scenes exist")
	_check(view._world.scale.x > 0.0 and view._world.scale.x < 1.0, "World fits a 1280x720 viewport")
	_check(_rect_matches(view.player_arena.wall_bounds, root.get_viewport().get_visible_rect()), "Player walls match the active 1280x720 viewport")
	_check(_rect_matches(view.player_arena.bounds, BubblesPresentation.NPC_ARENA_BOUNDS), "Existing NPC arena bounds remain unchanged")
	_check(view._far.texture != null and view._mid.texture != null and view._foreground.texture != null, "Three approved environment layers load")
	_check(view._music.stream is AudioStreamOggVorbis and (view._music.stream as AudioStreamOggVorbis).loop, "Selected BGM loops")
	_check(is_equal_approx(view._music.volume_db, -14.0) and is_equal_approx((view._audio_players[&"pop"][0] as AudioStreamPlayer).volume_db, -7.0), "Scene applies selected audio gains")
	_check(view._instructions.visible, "Instruction card appears")
	_check(not view.controller.complete_entrance(now - 1).accepted, "Entrance cannot move time backward")
	_check(view.controller.complete_entrance(now).accepted, "Entrance can enter countdown")
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	await process_frame
	_check(_rect_matches(view.player_arena.wall_bounds, root.get_viewport().get_visible_rect()), "Player walls update with a resized FHD viewport")
	_check(_rect_matches(view.player_arena.bounds, BubblesPresentation.NPC_ARENA_BOUNDS), "NPC arena bounds stay unchanged after resizing")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await process_frame
	_check(_rect_matches(view.player_arena.wall_bounds, root.get_viewport().get_visible_rect()), "Player walls update when returning to 1280x720")
	view._process(0.0)
	_check(view._cue.visible and view._cue.text == "3", "Countdown displays first whole second")
	view.controller.advance(now + 3000)
	_check(view._timer.visible and view._timer.text == "20", "Top-center timer begins at active start")
	_check(view._cue.text == "GO", "Active phase shows GO")
	_check_viewport_wall_cases(view, "1280x720")
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	await process_frame
	_check(_rect_matches(view.player_arena.wall_bounds, root.get_viewport().get_visible_rect()), "Active player walls follow the FHD viewport")
	_check_viewport_wall_cases(view, "1920x1080")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await process_frame
	_check(view.controller.record_jellyfish_capture("p0", now + 3000).accepted, "Collection accepted")
	_check(view.audio_event_count(&"collect") == 1, "Collection cue plays once per accepted event")
	_check(view.controller.pop_player("p0", now + 3000).accepted, "Pop accepted")
	_check(view.audio_event_count(&"pop") == 1, "Pop cue plays once")
	view._process(0.0)
	_check(view.audio_event_count(&"reform") == 0, "Re-form cue waits for the animation")
	view.controller.advance(now + 3000 + roundi(tuning.bubble_reform_seconds * 1000.0))
	view._process(0.0)
	_check(view.audio_event_count(&"reform") == 1, "Re-form cue plays after one pop")
	view.controller.feedback_requested.emit("p0", &"spin", {})
	_check(view.audio_event_count(&"spin_charge") == 1 and view.audio_event_count(&"spin_activate") == 1, "Authoritative spin release triggers charge and activation once")
	view.player_arena.player_collision.emit("p0", "p1", "")
	view.player_arena.player_collision.emit("p0", "p1", "")
	_check(view.audio_event_count(&"shove") == 1, "One contact does not spam shove audio")
	var before_warning := view._audio_counts.duplicate()
	tuning.pufferfish_warning_enabled = true
	var warned_id := view.creature_arena.schedule_puffer_path(Vector2(-100, 400), Vector2(2000, 400), Vector2(140, 400), now + 3000)
	_check(warned_id > 0 and not view.creature_arena.get_pufferfish(warned_id).active, "Enabled puffer warning precedes entry")
	_check(view._audio_counts == before_warning, "Puffer warning has no audio")
	tuning.pufferfish_warning_enabled = false
	var silent_id := view.creature_arena.schedule_puffer_path(Vector2(-100, 600), Vector2(2000, 600), Vector2(140, 600), now + 3000)
	_check(silent_id > 0 and view.creature_arena.get_pufferfish(silent_id).active, "Disabled warning enters without delay")
	view._update_timer(now + 3000 + 11000)
	_check(view._timer.text == "9" and view.audio_event_count(&"final_beat") == 1, "Final timer is numerical and audible")
	view._update_timer(now + 3000 + 11000)
	_check(view.audio_event_count(&"final_beat") == 1, "Repeated frame does not repeat final beat")
	view._update_timer(now + 3000 + 19000)
	_check(view._timer.text == "1" and view._timer.scale.x > 1.0, "Last beat uses stronger size pulse")
	view.controller.advance(now + 3000 + 20000)
	_check(view._results.visible and view._results_list.get_child_count() == 10, "Results include every player")
	var ranking: Array = view.controller.result_snapshot().ranking
	_check(int(ranking[0].rank) == 1 and int(ranking[1].rank) == 1 and int(ranking[9].rank) == 1, "Equal final counts retain shared rank")
	_check((view._results_list.get_child(0) as HBoxContainer).get_child_count() == 4, "Result row has rank, character, name and count")
	_check(view._results_list.size.y > 0.0 and view._results_list.size.y < view.size.y, "Results fit without scrolling")
	_check(view.controller.request_return_to_lobby(), "Host can request return")
	_check(not view.controller.request_return_to_lobby(), "Return fires once")
	view.queue_free()
	await process_frame
	print("Bubbles presentation: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _rect_matches(first: Rect2, second: Rect2) -> bool:
	return is_equal_approx(first.position.x, second.position.x) \
		and is_equal_approx(first.position.y, second.position.y) \
		and is_equal_approx(first.size.x, second.size.x) \
		and is_equal_approx(first.size.y, second.size.y)


func _check_viewport_wall_cases(view: BubblesPresentation, viewport_label: String) -> void:
	var bubble := view.player_arena.get_bubble("p0")
	var bounds := view.player_arena.wall_bounds
	var radius_x := bubble.collision_radius() * bubble.global_transform.x.length()
	var radius_y := bubble.collision_radius() * bubble.global_transform.y.length()
	var center := bounds.get_center()
	var cases: Array[Dictionary] = [
		{"position": Vector2(bounds.position.x + radius_x, center.y), "incoming": Vector2(-100.0, 0.0), "outgoing": Vector2(1.0, 0.0), "label": "left edge"},
		{"position": Vector2(bounds.end.x - radius_x, center.y), "incoming": Vector2(100.0, 0.0), "outgoing": Vector2(-1.0, 0.0), "label": "right edge"},
		{"position": Vector2(center.x, bounds.position.y + radius_y), "incoming": Vector2(0.0, -100.0), "outgoing": Vector2(0.0, 1.0), "label": "top edge"},
		{"position": Vector2(center.x, bounds.end.y - radius_y), "incoming": Vector2(0.0, 100.0), "outgoing": Vector2(0.0, -1.0), "label": "bottom edge"},
		{"position": bounds.position + Vector2(radius_x, radius_y), "incoming": Vector2(-100.0, -100.0), "outgoing": Vector2(1.0, 1.0), "label": "top-left corner"},
		{"position": Vector2(bounds.end.x - radius_x, bounds.position.y + radius_y), "incoming": Vector2(100.0, -100.0), "outgoing": Vector2(-1.0, 1.0), "label": "top-right corner"},
		{"position": Vector2(bounds.position.x + radius_x, bounds.end.y - radius_y), "incoming": Vector2(-100.0, 100.0), "outgoing": Vector2(1.0, -1.0), "label": "bottom-left corner"},
		{"position": bounds.end - Vector2(radius_x, radius_y), "incoming": Vector2(100.0, 100.0), "outgoing": Vector2(-1.0, -1.0), "label": "bottom-right corner"},
	]
	for collision: Dictionary in cases:
		bubble.global_position = collision.position
		bubble.velocity = collision.incoming
		bubble.simulate_step(0.05, bounds, view.controller.last_host_time_msec())
		var within_bounds := bubble.global_position.x >= bounds.position.x + radius_x - 0.001
		within_bounds = within_bounds and bubble.global_position.x <= bounds.end.x - radius_x + 0.001
		within_bounds = within_bounds and bubble.global_position.y >= bounds.position.y + radius_y - 0.001
		within_bounds = within_bounds and bubble.global_position.y <= bounds.end.y - radius_y + 0.001
		var outgoing: Vector2 = collision.outgoing
		var rebounds_inward: bool = outgoing.x == 0.0 or signf(bubble.velocity.x) == outgoing.x
		rebounds_inward = rebounds_inward and (outgoing.y == 0.0 or signf(bubble.velocity.y) == outgoing.y)
		_check(within_bounds and rebounds_inward, "%s %s bounces at the visible edge" % [viewport_label, collision.label])
	bubble.velocity = Vector2.ZERO
