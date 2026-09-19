---
id: PS-027
title: Integrate Flash? Pose! lobby and debug flow
type: implementation
status: done
release:
owner: ai
priority:
depends_on:
  - "[[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]]"
  - "[[PS-006 - Implement Player Join and Host-Owned Registry]]"
  - "[[PS-014 - Implement Minimal Gameplay Debug Launcher]]"
  - "[[PS-024 - Implement Flash Pose Host Round Controller]]"
  - "[[PS-025 - Implement Flash Pose Phone Protocol and Controller]]"
  - "[[PS-026 - Implement Flash Pose Shared Screen Feedback and Results]]"
---

# Goal

Wire the completed Flash? Pose! slices into the real host flow so normal play
can start from the lobby with two or more registered players, debug play can
start with one real player, and the host can return cleanly to the lobby.

# Scope

- Add the shared-display host control `Start minigame` to the lobby, enabling
  it for at least two registered players and explaining why it is unavailable
  otherwise. Do not let a browser phone start a round.
- On normal start, snapshot the current registry participants, stop accepting
  new players for the round, load the existing reserved internal scene path
  `res://minigames/dancer_simon_says.tscn`, and preserve `SessionHost`, LAN
  services, identities, seats, and valid reconnects.
- Update the existing F12 debug registration to launch the same scene as
  `One-player Flash? Pose!` when one real registered player exists. Preserve
  the `DEBUG — <scenario name>` marker, non-pausing behavior, restart, and
  return-to-lobby semantics. Do not create simulated players or a second game
  implementation.
- Connect the host-only results action to return to the lobby. Ensure scene
  teardown disconnects signals, stops presentation/audio, clears round state,
  and lets the lobby reopen new joins without restarting the host process.
- Handle an explicit player Leave/withdrawal during gameplay according to the
  PS-019 contract and make valid reconnect snapshots reflect the current game
  or lobby phase.
- Add focused integration/editor/runtime checks for the normal player gate,
  one-player debug gate, marker lifecycle, scene transitions, host/service
  continuity, and return-to-lobby behavior. Update `DEVELOPMENT.md` with the
  exact start/debug workflow.

# Non-Goals

- Reimplementing round rules, phone protocol, presentation, results, or audio
  already owned by PS-024 through PS-026.
- Adding a late-join queue, cross-minigame session, host authentication,
  simulated players, or a general scene router.
- Changing the approved normal two-player minimum, 20-player registry
  capacity, 60-second reconnect grace, or F12 launcher behavior.

# Acceptance Criteria

- With zero or one registered player, normal lobby start is disabled; with two
  or more it launches the Flash? Pose! scene once and prevents new joins while
  preserving existing identities.
- The same registered player can reach one-player Flash? Pose! only through
  the F12 debug entry, and raw browser connection count cannot unlock it.
- The normal and debug paths use one scene/round implementation, display the
  correct player-facing name, and do not restart or drop `SessionHost` LAN
  services.
- F12 still opens a non-pausing launcher, restarts the active scenario from a
  clean state, and returns to the lobby with the marker removed. Existing
  launcher behavior remains intact outside this integration.
- The host-only results action returns to the lobby, reopens new joins, leaves
  the persistent player registry usable, and does not leave stale signals,
  audio, timers, or browser state.
- Focused `[AUTO]`, `[EDITOR]`, and `[GODOT-RUNTIME]` checks cover the gates and
  transitions. Physical-phone and human-play evidence remain in PS-029.
- `DEVELOPMENT.md` documents the normal start, debug start, result return,
  reconnect, and service-continuity caveats.

# Game Feel / Player Experience

The host should be able to begin a round without exposing development
controls to phones or asking players to understand the scene system. The
two-player gate prevents an accidental empty proof, while the one-player
debug path keeps iteration fast and visibly marked as development behavior.

# Open Questions

- The owner may adjust the wording or placement of the shared-display start
  and result-return controls during human review; the actions themselves stay
  host-only.

# Notes / Findings

The current lobby only opens/closes new-player admission and has no start
button. `DebugLauncher` already preserves the persistent host and reserves a
one-player scene entry, but the reserved scene path does not yet exist. This
task is the final lifecycle wiring boundary, not a new networking or routing
framework.

# Draft Execution Prompt

Read this task, [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[PS-024 - Implement Flash Pose Host Round Controller]], [[PS-025 - Implement Flash Pose Phone Protocol and Controller]], [[PS-026 - Implement Flash Pose Shared Screen Feedback and Results]], [[PS-014 - Implement Minimal Gameplay Debug Launcher]], [[PS-006 - Implement Player Join and Host-Owned Registry]], [[PS-007 - Define the Gameplay Debug Suite]], [[Project Overview]], [[Decision Log]], and [[DEVELOPMENT]]. Inspect the
current lobby, boot, SessionHost, DebugLauncher, scene-change lifecycle, and
tests before editing. Add only the host start gate, shared scene navigation,
debug registration, results return, and teardown/service-continuity wiring.
Preserve the two-player normal minimum, one real-player debug rule, persistent
identity, no-pause launcher, and host authority. Add focused integration checks,
document the workflow, and distinguish editor/runtime evidence from physical
phone and human-play evidence. Follow GitHub Flow and keep unrelated changes
out of the pull request.

# Outcome

Completed on 2026-09-18. The lobby now exposes a host-only `Start minigame`
control gated to 2–10 registered players with visible unavailable reasons.
Normal and exactly-one-player F12 debug starts both snapshot the persistent
registry through `SessionHost` and load the same reserved Flash? Pose! scene.
The debug entry uses the player-facing name, retains its non-pausing marker,
clean restart, and lobby-return behavior, and cannot be unlocked by raw browser
connections.

The shared results view now exposes `Return to lobby`. Controller notification
precedes deferred scene teardown so phones receive lobby state; the persistent
host, services, surviving identities, seats, and reconnect capability remain
alive while joins reopen in the replacement lobby. Explicit gameplay Leave is
observed as withdrawal without life loss. Focused automated/editor/runtime
checks passed, including 12/12 browser integration tests and a reviewed
1280×720 technical results render. Physical-phone and human-play evidence
remain explicitly assigned to PS-029.

Owner testing before merge then exposed two phone-control defects in this same
acceptance boundary: JSON-decoded whole-number `input_seq` values were rejected
when Godot represented them as floats, and held charge did not advance between
input/deadline events. Both were corrected in this PR with bounded numeric
normalization, host-time pose-rule ticking, and regression coverage from parsed
browser packets through semantic character charge. The phone pose button and
all child icon/label content also disable standard/WebKit selection and iOS
touch callouts, backed by compiled-bundle checks. A fresh physical-phone retest
is still required; no post-fix device approval is claimed here.

The owner subsequently confirmed that the normal minigame is playable with an
iPhone and an Android phone. One-player debug still ended after the first pose
because it inherited the normal last-player rule. The controller now records
the explicit one-player debug launch, preserves infinite lives across failed
evaluations, bypasses `last_player` while its real participant remains, and
finishes at the configured maximum duration. Debug protocol messages drive the
phone label `Lives: DEBUG`; normal life and end rules are unchanged. Automated
coverage passes, but the task is reopened until the owner verifies this debug
flow on a phone.
