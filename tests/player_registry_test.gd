extends SceneTree
## Deterministic identity lifecycle checks; explicit timestamps avoid real-time waits.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var registry := PlayerRegistry.new(2, 60.0)
	if not _check(registry.session_id.length() == 32, "Session identity is opaque and host-generated"):
		return
	for invalid_name: Variant in [null, "", "   ", "12345678901234567", "Line\nBreak"]:
		if not _check(not registry.validate_name(invalid_name).accepted, "Invalid names are rejected"):
			return

	var first := registry.join_player(11, "  Zoë 🎮  ", true, 1000, "square", "#EC407A")
	if not _check(first.accepted and first.player.name == "Zoë 🎮", "Printable Unicode name is trimmed and accepted"):
		return
	if not _check(first.player.character_shape == "squircle" and first.player.character_color == "#EC407A",
			"Legacy body input resolves to Squircle while preserving the selected color"):
		return
	if not _check(first.player.player_id != str(11) and first.reconnect_token != first.player.player_id,
			"Connection, player, and reconnect identities stay separate"):
		return
	var invalid_selection := registry.join_player(18, "Bad Shape", true, 1000, "triangle", "#E53935")
	if not _check(not invalid_selection.accepted and invalid_selection.code == &"invalid_character_selection"
			and registry.player_count() == 1, "Unknown client shapes cannot create a player record"):
		return
	var partial_registry := PlayerRegistry.new()
	var color_only := partial_registry.join_player(19, "Color Only", true, 1000, null, "#43A047")
	if not _check(color_only.accepted and color_only.player.character_shape == "squircle"
			and color_only.player.character_color == "#43A047",
			"Missing shape resolves to Squircle without replacing a valid selected color"):
		return
	var duplicate := registry.join_player(12, "ZOË 🎮", true, 1000)
	if not _check(not duplicate.accepted and duplicate.message == "Name already in use", "Duplicate matching is case-insensitive"):
		return
	var blocked := registry.join_player(12, "Other", false, 1000)
	if not _check(blocked.code == &"game_in_progress", "New players cannot join during gameplay"):
		return

	var second := registry.join_player(12, "Other", true, 1000, "rhombus", "#00ACC1")
	if not _check(second.accepted and registry.player_count() == 2, "Capacity counts player records"):
		return
	registry.disconnect_connection(11, 1000)
	if not _check(registry.public_players()[0].state == "reconnecting", "Disconnect reserves a reconnecting slot"):
		return
	var full := registry.join_player(13, "Third", true, 2000)
	if not _check(full.code == &"full", "Reconnect reservations count toward capacity"):
		return
	var resumed := registry.resume_player(14, registry.session_id, first.reconnect_token, 60999)
	if not _check(resumed.accepted and resumed.player.player_id == first.player.player_id and resumed.player.seat == first.player.seat
			and resumed.player.character_shape == "squircle" and resumed.player.character_color == "#EC407A",
			"A valid grace-window resume restores the same player, seat, shape, and color"):
		return
	var duplicate_resume := registry.resume_player(15, registry.session_id, first.reconnect_token, 61000)
	if not _check(duplicate_resume.accepted and duplicate_resume.replaced_connection_id == 14,
			"A duplicate resume deterministically replaces the previous connection"):
		return
	var left := registry.leave_connection(15)
	if not _check(left.accepted and registry.player_count() == 1, "Explicit leave removes the player immediately"):
		return
	var invalidated := registry.resume_player(16, registry.session_id, first.reconnect_token, 61000)
	if not _check(invalidated.code == &"expired", "Leave invalidates the reconnect token"):
		return
	var reused := registry.join_player(16, "zoë 🎮", true, 61000)
	if not _check(reused.accepted and reused.player.character_shape == "squircle"
			and reused.player.character_color == CharacterSelection.FALLBACK_COLOR,
			"Legacy and test joins without a style receive the Squircle-and-blue fallback"):
		return

	var expiring := PlayerRegistry.new(1, 60.0)
	var expiring_join := expiring.join_player(21, "Grace", true, 5000)
	expiring.disconnect_connection(21, 5000)
	expiring.expire_players(64999)
	if not _check(expiring.player_count() == 1, "Player remains before the exact grace boundary"):
		return
	expiring.expire_players(65000)
	if not _check(expiring.player_count() == 0, "Player expires at the exact grace boundary"):
		return
	if not _check(expiring.resume_player(22, expiring.session_id, expiring_join.reconnect_token, 65000).code == &"expired",
			"Expired tokens cannot restore removed records"):
		return

	var restarted := PlayerRegistry.new()
	if not _check(restarted.max_players == 10 and PlayerRegistry.new(20).max_players == 10,
			"Registry fallback and oversized constructor remain capped at ten"):
		return
	var full_party := PlayerRegistry.new()
	var first_full: Dictionary = {}
	for index: int in 10:
		var joined := full_party.join_player(100 + index, "Player %d" % index, true, 1000)
		if not _check(joined.accepted, "Ten distinct players can join"):
			return
		if index == 0:
			first_full = joined
	if not _check(full_party.player_count() == 10 and full_party.join_player(110, "Eleventh", true, 1000).code == &"full",
			"Eleventh new player receives the full-lobby response"):
		return
	full_party.disconnect_connection(100, 1000)
	if not _check(full_party.join_player(110, "Eleventh", true, 2000).code == &"full",
			"Disconnected reservation still occupies the tenth slot"):
		return
	var full_resume := full_party.resume_player(111, full_party.session_id, first_full.reconnect_token, 2000)
	if not _check(full_resume.accepted and full_resume.player.player_id == first_full.player.player_id,
			"Reserved player resumes into a full lobby"):
		return
	full_party.leave_connection(111)
	if not _check(full_party.join_player(110, "Eleventh", true, 2000).accepted,
			"Explicit leave immediately frees a slot"):
		return
	full_party.disconnect_connection(101, 3000)
	if not _check(full_party.join_player(112, "Twelfth", true, 62999).code == &"full"
			and full_party.join_player(112, "Twelfth", true, 63000).accepted,
			"Reservation expiry frees a slot at the grace boundary"):
		return
	if not _check(restarted.session_id != registry.session_id, "A new host registry creates a new session"):
		return
	var old_session := restarted.resume_player(30, registry.session_id, second.reconnect_token)
	if not _check(old_session.code == &"session_restarted", "Old-session tokens receive the restart state"):
		return

	print("Player registry checks passed")
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
