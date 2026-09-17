---
id: PS-006
title: Implement player join and host-owned registry
type: implementation
status: done
release:
owner: ai
priority:
depends_on:
  - "[[PS-003 - Define Join Identity and Reconnection UX]]"
---

# Goal

Implement the smallest host-authoritative identity layer that turns a browser connection into a named lobby player while preserving the local-network-first foundation and the approved [[PS-003 - Define Join Identity and Reconnection UX]] behavior.

# Scope

- Add a session-scoped, host-owned player registry under the existing persistent `SessionHost` lifecycle. It must survive scene changes and reset on host restart.
- Keep the existing transport `connection_id` separate from an opaque host-generated `player_id`.
- Add an opaque browser reconnect token and session identity. Store the token and last-used name in browser `localStorage`; never accept a client-selected player ID as authoritative.
- Extend the versioned protocol with the minimum explicit messages needed for optional resume, name join, accepted/rejected results, and explicit leave. Preserve the current handshake and reject malformed or unauthorized messages.
- Validate names using the approved rules: trimmed printable Unicode, 1–16 characters, no control characters, and case-insensitive duplicate detection. Reject duplicate names with `Name already in use`.
- Add a default configurable player capacity of 20, separate from the existing 32-connection transport limit. A full lobby rejects new players but permits valid existing-player resumes.
- Retain disconnected players in a reconnecting state for a configurable 60-second grace period, reserve their slot during that period, restore the same player on valid resume, and remove the record after expiry.
- Add phone UI for name entry, joining, joined/reconnecting/expired/full/error states, session restart handling, and `Leave`/`Change player`.
- Add the minimum shared lobby presentation for public names, join order or seat, and connected/reconnecting states. Replace the current browser-connection diagnostic with player-aware information without redesigning the whole lobby.
- Keep new joins lobby-only. Do not implement the future “connect now to join next minigames” queue. Existing players may reconnect during gameplay; minigame-specific absence rules remain outside this task.
- Add proportionate automated protocol, registry, and browser checks. The project owner will perform the real-phone flow checks; do not add a device farm or elaborate simulation harness.

# Non-Goals

- The future next-minigame join queue or any late-join gameplay flow.
- Gameplay controller input, authoritative minigame state, scoring, lives, or consequences of a disconnected player.
- Character selection, persistent profiles, cross-session identity, Internet accounts, matchmaking, or online hosting.
- Host approval workflows, manual moderation tools, connection-quality measurement, or multi-player-per-browser behavior.
- A general-purpose networking framework or unrelated refactors of the existing HTTP/WebSocket foundation.

# Acceptance Criteria

- The host creates, validates, updates, and removes player records authoritatively; client input cannot directly choose or mutate authoritative identity fields.
- A first-time browser can enter a valid name and is automatically accepted. The phone shows a joined state and the shared lobby shows the player.
- `connection_id`, `player_id`, session identity, and reconnect token have distinct lifecycles and are covered by tests or documented protocol evidence.
- A page reload, screen lock, temporary connection loss, or brief Wi-Fi loss can resume the same player with its token within the 60-second grace period. The player slot remains reserved while reconnecting.
- Expired tokens cannot resume removed records. The phone returns to an actionable join state with the last name available for resubmission.
- Invalid names, duplicate names, full capacity, malformed messages, unsupported messages, and a new-session token receive deterministic actionable responses. Duplicate names use exactly `Name already in use`.
- `Leave` removes the player immediately, invalidates its token, and makes the name/capacity available again.
- A host restart creates a new session. Old tokens cannot resume; a reconnecting phone receives a session-restarted state and may submit its prefilled name again.
- The default player capacity is 20 and is independent of the existing 32 transport connections. Valid reconnects are allowed when the player capacity is full.
- The player registry remains available across Godot scene changes through the existing persistent host lifecycle.
- The shared display and phone use actionable connection states and do not require a color-only or signal-strength indicator. Name input has an accessible label and status feedback.
- `max_players` and `reconnect_grace_seconds` are designer-accessible host settings with documented units, defaults, and locations. Existing provisional network retry/handshake values remain documented rather than being silently changed.
- Automated results, Godot editor/runtime results, desktop-browser results, and owner-performed physical-phone results are reported separately. No physical-phone result is claimed by the implementation agent.
- `DEVELOPMENT.md`, this task, and [[Decision Log]] record material implementation discoveries without broadening scope.

# Game Feel / Player Experience

Keep the current provisional values unless the implementation exposes a concrete defect: the host request/handshake timeout remains 5 seconds, the browser fetch timeout remains 5 seconds, the browser WebSocket deadline remains about 7 seconds, and browser retry remains 2 seconds. Add `max_players = 20` and `reconnect_grace_seconds = 60` to the existing designer-facing host settings resource. Document any browser-side copy or timing constants at their source until [[PS-004 - Define the Game-Feel Tuning Strategy]] establishes a shared convention. No runtime tuning UI, connection-quality meter, animation, or audio feedback is needed here.

# Open Questions

- The future next-minigame queue needs its own design and implementation task.
- Each minigame must later define what a disconnected or reconnecting player can do during its rules; this registry task only reports connection state.
- [[PS-004 - Define the Game-Feel Tuning Strategy]] may later reorganize settings exposure without changing this task's player-facing behavior.

# Notes / Findings

PS-003 is approved on 2026-09-14. The implementation should adapt the existing `SessionHost`, `WebsocketService`, lobby scene, and thin browser client rather than introduce a new networking layer. A plain typed registry/data structure plus existing Godot signals is preferred; a new pattern or abstraction must earn its complexity through a concrete lifecycle or testability problem.

# Draft Execution Prompt

Read this task first and treat it as the source of truth. Then read the completed [[PS-003 - Define Join Identity and Reconnection UX]], [[Decision Log]], [[Project Overview]], [[DEVELOPMENT]], and project [[AGENTS.md]]. Inspect the existing `SessionHost`, `WebsocketService`, lobby scene, browser client, protocol tests, and current worktree before changing anything. Implement only the approved session-scoped registry, join/resume/leave protocol, phone states, and minimal shared roster. Preserve the host-authoritative model, protocol validation, local-network-first behavior, and existing scene lifecycle; avoid unrelated refactors and do not implement the future next-minigame queue. Keep `max_players` and `reconnect_grace_seconds` designer-accessible, document their units/defaults/locations, and preserve the current provisional retry and handshake values unless a tested defect requires a change. Add focused automated checks for identity separation, name validation, capacity, grace expiry, explicit leave, host restart, malformed input, and resume. Run the relevant project checks, distinguish automated results from Godot/editor, desktop-browser, and owner-performed physical-phone evidence, update [[DEVELOPMENT]] with important discoveries, and report any assumption that would change the approved behavior before making it.

# Outcome

Implemented on `feat/ps-006-player-registry` on 2026-09-14. `SessionHost` now owns
a session-scoped authoritative registry with separate connection, player,
session, and reconnect-token identities. The versioned browser protocol supports
join, automatic resume, deterministic rejection, explicit leave, host-restart
recovery, and lobby-only new-player admission. The shared lobby renders seat,
name, and connected/reconnecting text states; the accessible phone page provides
name entry, joined/reconnecting/expired/full/error copy, reload resume, and
Leave/Change player.

`max_players = 20` and `reconnect_grace_seconds = 60.0` are exposed in
`Tuning/Shared/Networking/Default.tres`; the 32-connection transport cap and provisional
5/5/7/2-second host request, browser fetch, WebSocket deadline, and retry values
remain unchanged. Focused registry, lobby, TypeScript, HTTP, and WebSocket checks
pass. A desktop browser pass at a 390×844 viewport passed join, reload resume,
and leave/change-player flows. Physical-phone screen-lock, temporary Wi-Fi loss,
touch/mobile-browser behavior, and full shared-display play flow remain explicitly
owner-performed validation.
