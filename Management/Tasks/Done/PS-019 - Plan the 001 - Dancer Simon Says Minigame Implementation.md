---
id: PS-019
title: "Plan the 001 - Flash? Pose! minigame implementation"
type: design
status: done
release:
owner: shared
priority:
depends_on: []
---

# Goal

Turn the approved Flash? Pose! concept, wireframe, selected assets, and
existing project foundations into an implementation-ready plan for the first
complete minigame loop. The plan must divide the work into reviewable tasks,
preserve the host-authoritative boundary, and leave final feel decisions to
the project owner.

# Scope

- Define the minigame lifecycle from lobby entry through countdown, dancing,
  genuine stop, grace/evaluation, camera-flash feedback, music resume, life
  loss, elimination, results, and host-controlled return to the lobby.
- Define the smallest ownership boundary between the persistent host,
  authoritative round rules, pose charge, phone protocol, browser controller,
  shared-screen scene, character animation, audio/flash feedback, and debug
  launcher.
- Define the post-handshake messages and host timing needed for press-and-hold
  phone input without allowing a client to choose a player, target pose, time,
  life count, or outcome.
- Map player-facing and game-feel values to the existing editor-first tuning
  workflow, including provisional starting values and the human playtests that
  must decide whether they are good.
- Define the genuine-stop camera-flash contract and keep it distinct from the
  future fake-stop task.
- Cover accessibility baselines, shared-screen readability, phone attention,
  content and provenance gates, debug entry, validation evidence, and human
  approval checkpoints.
- Create only bounded follow-up task records. Keep [[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]] as editor-visible stage composition and do
  not hide the complete feature in one umbrella implementation task.

# Non-Goals

- Implementing gameplay, networking, scenes, assets, audio, or browser UI in
  this planning task.
- Reopening approved animation, identity, tuning, or Milestone 1 decisions
  without new evidence.
- Adding a cross-minigame scoreboard, session sequencing, a larger ranking
  system, or fake music stops.
- Choosing final numeric feel values without human playtesting.
- Reusing the discarded PS-022 draft from repository history; task IDs remain
  sequential and are never reused.

# Acceptance Criteria

- A single plan describes the lifecycle, ownership boundaries, data contracts,
  timing ownership, scene responsibilities, failure behavior, and execution
  sequence for the first Flash? Pose! implementation.
- The plan links the canonical minigame design, approved foundation tasks,
  current scenes/scripts/resources, tuning assets, and validation strategy.
- The observable genuine-stop order is explicitly:
  `music playing -> stop and pose reveal -> grace/evaluation -> authoritative
  resolve -> one camera-flash SFX/VFX -> music resume`. A future fake stop emits
  none of the camera-flash cues.
- Every known unresolved behavior is either answered as a confirmed MVP rule,
  retained as a named owner decision, or converted into a bounded follow-up
  task with an explicit dependency.
- Each new implementation or validation task has its own scope, non-goals,
  acceptance criteria, owner, dependencies, and draft execution prompt.
- The breakdown includes PS-018 and PS-013 without absorbing either task into
  a broader feature task, and it reaches a complete two-player playable loop
  while retaining the normal 2–10 player range and one-player debug path.
- Automated, editor/runtime, desktop-browser, physical-phone, exported-build,
  and human-play evidence remain separate. Passing tests is not presented as
  proof of fun, fairness, readability, accessibility, or phone usability.
- The project owner reviews and approves this plan and decomposition before
  the implementation sequence is treated as ready.

# Game Feel / Player Experience

The implementation must make the shared display the primary attention target:
the lead pose reads first, player reactions remain scannable, and the phone
requires a simple one-thumb press-and-hold action. The genuine stop should feel
like a fair dramatic snapshot: players get the documented grace window, the
host resolves the pose before the flash, and the track returns only after the
flash has finished. Technical completion does not settle timing, readability,
accessibility, or fun.

# Current Baseline and Constraints

- [[PS-001 - Define the First Gameplay Milestone]] and [[001 - Dancer simon says]] define one minigame, normal play for 2–10 players, two lives, limited
  ranking, a two-tier result, and return to the lobby. One-player start is
  debug-only through [[PS-007 - Define the Gameplay Debug Suite]].
- [[PS-006 - Implement Player Join and Host-Owned Registry]] owns stable
  session-scoped player identities, 20-player capacity, 60-second reconnect
  grace, lobby-only new joins, and the persistent `SessionHost` lifecycle.
  Existing players may reconnect during gameplay; minigame absence rules are
  defined below.
- [[PS-012 - Implement Milestone 1 Character Animation System]] already owns
  detached-sprite motion, three styles (`bounce`, `swing`, `disco`), four
  screen-relative command poses, phase offsets, reactions, elimination, and
  results moods. Gameplay supplies semantic state and never reads transforms.
- [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]] makes
  `Tuning/Active Presets.tres` and
  `Tuning/Minigames/SimonSays/Default.tres` the editor-first tuning front door.
  Existing internal `SimonSaysTuning` names are retained for compatibility;
  the exact `Flash? Pose!` wording is used wherever players see the name.
- [[PS-016 - Create Wireframe for 001 - Dancer Simon Says]] is the approved
  reference for the shared screen and the two-, three-, and four-input phone
  layouts. [[PS-017 - Find Better Environment Assets for 001 - Dancer Simon Says]] remains a human-owned prerequisite for the stage.
- [[PS-020 - Find Music and SFX for 001 - Dancer Simon Says]] is marked done
  and the repository currently contains three BGM candidates and two flash
  SFX candidates. Its task note has no recorded outcome metadata, so the
  runtime audio task must confirm provenance, loop behavior, and listening
  approval rather than treating file presence as final approval.
- The current branch has no gameplay scene or gameplay protocol yet. The debug
  catalog reserves `res://minigames/dancer_simon_says.tscn`; preserving that
  internal path avoids an unnecessary rename while the player-facing label is
  Flash? Pose!. The current browser protocol only handles hello, join, leave,
  and reconnect, and the lobby has no start control.

# Proposed Architecture

Use the engine's normal `_process` loop and a small host-owned coordinator. A
plain enum plus one transition method is clearer than a hierarchy of state
objects for this fixed Milestone 1 flow. Godot signals are sufficient for the
known synchronous subscribers; do not introduce a universal event bus or an
event queue.

`FlashPoseRoundController` should own one round's lifecycle and a typed/plain
per-player state record keyed by host-assigned `player_id`. It owns phase
transitions, the round clock, stop IDs, target selection, lives, elimination,
ranking, and result snapshots. It delegates pose mathematics to PS-013,
presentation to the scene, and transport adaptation to the protocol layer.
The controller is a coordinator, not a god object: it must not edit child
sprites, parse browser packets, or decide audio/VFX details.

Use narrow signals or explicit methods at the boundaries, for example:

- `genuine_stop_started(stop_id, direction, available_directions)`;
- `pose_evaluation_resolved(stop_id, results)`;
- `flash_requested(stop_id, results)` and `flash_completed(stop_id)`;
- `round_results_ready(results)` and `return_to_lobby_requested()`.

The exact typed GDScript signatures may be refined during implementation, but
the event ownership and order must remain observable and testable. The
presentation layer must not be able to resolve a result, and an audio callback
must not be able to create a flash by merely pausing music.

# Lifecycle and Ownership

| Phase | Host-owned behavior | Shared-screen/browser consequence |
| --- | --- | --- |
| Lobby | `SessionHost` accepts new players. A host control starts normal play only with at least two registered players. | Lobby shows the player roster and an actionable `Start minigame` control. Phones remain in their joined state. |
| Countdown | Snapshot the participating registered players, assign stable seats, choose one style/track for the round, and run the tunable countdown. Stop accepting new players. | The stage loads with the Flash? Pose! label and a visible countdown. No pose actions are accepted yet. |
| Dance | Start the selected looping track and automatic animation. Choose the next stop from the host-owned random source and difficulty curve. | All characters dance; phones show a waiting/watch state. |
| Genuine stop / grace | Pause the track, freeze and reveal the lead pose, preserve any active player hold/pose while the touch remains held, and accept validated press/release actions until the host deadline. | The lead pose and redundant direction cue are visible. Phones enable the currently unlocked color-and-icon controls. |
| Resolve | At the host grace deadline, evaluate every non-withdrawn player using PS-013. Correct direction + full charge + held input succeeds. Apply one life loss for wrong, missing, incomplete, or released input; eliminate at zero. Ignore late or duplicate actions. | Shared characters receive semantic charge/reaction/elimination state. Each phone receives its own result/lives state. |
| Flash | Emit exactly one `flash_requested` event after results are fixed. Wait for `flash_completed` before resuming music. | A brief bright shared-screen camera-flash effect and one matching SFX play; results remain readable and the flash cannot retrigger for the same stop. |
| Next cycle or end | If more than one eligible player remains and the round timer has not expired, resume dance and schedule the next stop. Otherwise create the limited ranking snapshot. | The next dance begins only after the flash; or the result presentation appears. |
| Results | Keep the upper-ranked half above the lower-ranked half. Hold the view until a host-only return action is used. | Happy/moody groups and names remain visible without points or a cross-minigame scoreboard. |
| Lobby return | Tear down the minigame scene, preserve the persistent registry and LAN services, and let the lobby reopen new joins. | Phones receive a lobby state/snapshot and may remain joined. |

The player substate is separate from the round phase: `active`, `eliminated`,
or `withdrawn`. Preserve a player's seat and shared-screen slot throughout the
round. An explicit `Leave` withdraws the player without a life loss and removes
the record under PS-006. An uninterrupted touch hold may continue through a
genuine stop: the character keeps the corresponding pose and the player does
not need to release and re-press between stops. A transient disconnect clears
that hold; the reconnecting player contributes no input until a new press, and
missing input at a stop follows the normal no-input failure rule.

# Genuine-Stop Contract

Every real stop has a monotonically increasing `stop_id` and a source known to
the round controller as `genuine`. The controller is the only producer of the
flash request. The implementation must make this sequence deterministic:

1. Music is playing and the characters are dancing.
2. The controller pauses/silences the music and tells the lead/player
   animators to show the command semantics without forcibly releasing an
   active player hold.
3. The grace window accepts continuing, new, or corrected direction holds.
4. The controller resolves all results at the host deadline.
5. The controller emits one flash request; the presentation plays one flash
   SFX and one shared-screen VFX.
6. The presentation acknowledges flash completion.
7. The controller resumes the same music stream only after that acknowledgement.

For the first implementation, pause/resume the selected looping stream at its
current playback position rather than adding beat-quantized scheduling. This
keeps the stop/resume boundary simple and reversible; an audio review may later
replace it with a loop-safe transition if human listening exposes a click or
rhythmic stumble. A future fake-stop source must have no route to
`flash_requested` and must not be designed or implemented by these tasks.

# Rules, Data, and Timing Decisions

- Use host monotonic time/engine progression for all deadlines. Client packets
  may carry an `input_seq` for duplicate and ordering checks, but never a
  client-authored timestamp. The first version performs no latency compensation;
  revisit only after the two-phone check produces evidence.
- Keep one PS-013 pose-charge instance per participating player. A genuine stop
  does not clear an active direction, normalized charge, or held status, and it
  does not require a new press event. While the player keeps touching the same
  control, the character keeps holding that pose across the flash. Release and
  direction-change behavior remains governed by PS-013; a disconnect clears the
  hold and requires a new press after reconnect.
- Start with two directions (`left`, `right`), add `down` at the first
  provisional unlock threshold, then add `up` at the second. The four canonical
  directions remain screen-relative and are shared by every dance style.
- Select one of the three music/style pairs once per round and keep it for that
  round. Tests must be able to inject the style/target sequence; the normal
  run may use the host random source.
- Track two lives per participant. Rank elimination order first. If the timer
  expires with multiple active players, use remaining lives, then the order of
  life loss, then stable `player_id` only for the all-perfect fallback, exactly
  as specified by [[001 - Dancer simon says]].
- Keep the results screen host-controlled. The shared screen exposes a
  host-only `Return to lobby` action; there is no automatic timeout in the first
  proof.

# Protocol and Phone Plan

Keep transport handshake `protocol: 1`; these are new post-handshake message
types for the bundled host and browser, not a new networking layer. The host
must derive `player_id` from the authenticated connection/registry mapping.

| Direction | Message | Required behavior |
| --- | --- | --- |
| Browser -> host | `pose_down` with `direction` and `input_seq` | Accept only during the current genuine-stop grace window and for the sender's registered player. Host timestamps receipt. |
| Browser -> host | `pose_up` with `direction` and `input_seq` | Release only the sender's current hold; stale, duplicate, unknown-direction, late, and malformed packets are harmlessly rejected or ignored with an actionable protocol error. |
| Host -> browser | `minigame_state` / `challenge_started` | Communicate player-facing phase, available directions, stop ID, and the sender's own lives/elimination state. Do not rely on the phone to know the authoritative target. |
| Host -> browser | `pose_result` | Communicate that the sender succeeded or lost a life and the resulting lives count after the host resolves the stop. |
| Host -> browser | `eliminated` | Send the exact message `You've been eliminated :(` and disable further pose input while retaining a readable result state. |
| Host -> browser | `results` / `lobby_state` | Show the sender's result/return state and reset the phone to its lobby controls after return. |

The host adapter should expose a narrow `player_action_received` signal and
`send_to_player`/broadcast capability to the current controller. It must not
let the round scene inspect `_clients` or construct WebSocket packets. On
reconnect, send a current snapshot and clear any stale browser pointer state;
do not restore a held input merely because the reconnect token is valid.

The browser controller should use pointer events with capture/cancel cleanup,
prevent accidental page scrolling while holding a region, and render two to
four large square regions with both an icon and a text/accessible label. It
must show explicit waiting, resolving, success/failure, eliminated, and lobby
states. The phone never displays a client-derived life count as authoritative.

# Tuning Plan

Add only values that have a real player-facing experiment to
`SimonSaysTuning`, following the established documentation order and
`@export_group` convention. Use clearly provisional defaults in `Default.tres`;
the owner promotes or replaces them only after playtesting.

| Group | Values to expose | Owner of the behavior |
| --- | --- | --- |
| Gameplay/timing | pre-game countdown, total round duration, pose grace, initial stop interval min/max, difficulty reduction, and the two pose-unlock thresholds | Round controller and PS-013 |
| Input/feedback | held-pose persistence across genuine stops, plus player-facing feedback hold/release duration | Phone/controller and round presentation |
| Audio/flash | music gain, flash SFX gain, flash peak intensity/duration, and any resume fade that proves necessary | Audio/presentation task; final loudness and feel remain human-owned |
| Results | No automatic result timeout for the first proof; expose a duration only if a later approved behavior needs one | Results presentation |

Keep random seeds, sequence counters, protocol identifiers, internal clocks,
and implementation-only constants private. Every new exported value needs a
plain-language description, unit, default, safe range, higher/lower guidance,
invalid-value rules, and focused validation. Browser-only CSS/accessibility
values remain in the browser source unless synchronized behavior is proven
necessary.

# Accessibility and Validation Gates

- The shared display repeats direction meaning with pose, icon, and text; no
  color-only or sound-only requirement decides success. Lives and elimination
  are represented with readable text/shape changes, not only color.
- The phone provides labeled, high-contrast, large touch regions, explicit
  state text/live-region feedback, and a reduced-motion-friendly presentation.
  The camera flash is a brief feedback cue, not the only indication of the
  result; intensity and motion must remain reviewable.
- [[PS-005 - Define Multi-Phone and Agent Validation Strategy]] remains the
  evidence source: automated tests cover deterministic rules/protocols;
  `[EDITOR]` covers scene/Inspector/load; `[GODOT-RUNTIME]` covers the host;
  `[DESKTOP-BROWSER]` covers desktop controller behavior;
  `[PHYSICAL-PHONE]` covers the iPhone 16 Pro Safari and Pixel 7 Chrome pair
  on normal home Wi-Fi; `[HUMAN-PLAY]` covers fairness, readability, attention,
  accessibility, pacing, audio, and fun. Use `[EXPORTED-BUILD]` only when an
  actual export exists.
- The technical validation task must exercise at least two players plus a
  deterministic one-player debug run and a simulated browser matrix up to ten
  connected players. The human validation task owns the real two-phone full
  loop and explicit approval.

# Recommended Execution Order

The first two branches after owner approval can proceed in parallel when their
inputs are ready. The arrows below are the real integration gates, not priority
assignments.

1. Human prerequisite: finish/confirm [[PS-017 - Find Better Environment Assets for 001 - Dancer Simon Says]]; retain the approved PS-016 wireframe.
   PS-020 is the current audio candidate source, but PS-023 must record its
   technical provenance/listening gate before final audio approval.
2. Implement [[PS-013 - Implement Pose Charge and Evaluation Rules]] and
   [[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]] after this
   plan is approved. They are independent slices: PS-013 proves rules, while
   PS-018 proves the editor-visible stage and stable seat slots.
3. In parallel with the two slices above, execute [[PS-023 - Prepare Flash Pose Runtime Music and SFX]] after PS-020 and this plan. It only prepares existing
   candidate media and does not choose new sounds.
4. Execute [[PS-024 - Implement Flash Pose Host Round Controller]] after
   PS-013 and PS-018. This establishes the authoritative lifecycle and testable
   signals, using direct injected inputs until the protocol is connected.
5. After PS-024, execute [[PS-025 - Implement Flash Pose Phone Protocol and Controller]]. It adapts validated browser actions to the round controller
   and implements the two-to-four-region phone journey.
6. After PS-023 and PS-024, execute [[PS-026 - Implement Flash Pose Shared Screen Feedback and Results]]. It populates the PS-018 slots, wires
   animation semantics, maps music/style assets, implements the genuine flash,
   and renders results. PS-025 may proceed in parallel.
7. Execute [[PS-027 - Integrate Flash Pose Lobby and Debug Flow]] after PS-025
   and PS-026. This adds the normal host start gate, one-player debug entry,
   scene navigation, host-controlled result return, and teardown/service
   continuity.
8. Execute [[PS-028 - Validate Flash Pose Technical Loop]] after PS-027 for
   focused automated, editor/runtime, desktop-browser, and available export
   evidence.
9. Execute [[PS-029 - Validate Flash Pose on Two Phones and in Human Play]]
   after PS-028. This is the final physical-device and human approval gate for
   the first functional minigame claim.

PS-008 remains intentionally outside this sequence. It may use the genuine
stop event contract later, but it does not add a fake stop to Milestone 1.

# New Follow-up Tasks

- [[PS-023 - Prepare Flash Pose Runtime Music and SFX]] — technical treatment
  and provenance gate for the supplied music/flash candidates.
- [[PS-024 - Implement Flash Pose Host Round Controller]] — authoritative
  lifecycle, per-player round state, lives, elimination, ranking, and signals.
- [[PS-025 - Implement Flash Pose Phone Protocol and Controller]] — post-
  handshake host adapter and browser press-and-hold journey.
- [[PS-026 - Implement Flash Pose Shared Screen Feedback and Results]] — stage
  runtime population, countdown/pose/status UI, music, flash, reactions, and
  two-tier results presentation.
- [[PS-027 - Integrate Flash Pose Lobby and Debug Flow]] — normal start gate,
  debug entry, scene teardown, and host-controlled return.
- [[PS-028 - Validate Flash Pose Technical Loop]] — agent-run technical and
  desktop evidence.
- [[PS-029 - Validate Flash Pose on Two Phones and in Human Play]] — owner-run
  physical-phone, accessibility, feel, and final approval evidence.

# Owner-Confirmed Decisions

These choices were confirmed by the project owner on 2026-09-16.

- **Held pose:** an uninterrupted touch hold persists through a genuine stop;
  the character keeps holding the pose and the player does not need to
  release/re-press between stops.
- **Temporary disconnect:** a reconnecting player remains in the round, but a
  disconnected hold is not restored; missing input at evaluation loses a life.
  An explicit Leave withdraws without a life loss.
- **Audio resume:** pause and resume the same looping stream at its exact
  playback position for the first proof. Loop-safe musical-boundary work is
  deferred unless listening finds a problem.

Final countdown, stop intervals, grace duration, flash intensity, audio gain,
and other numeric values remain provisional tuning rather than plan blockers.

# Notes / Findings

The current implementation has a persistent `SessionHost`, a host-owned
`PlayerRegistry`, a versioned WebSocket hello/join/leave transport, an
editor-first tuning Resource, an approved semantic animator, and a debug
launcher. It does not yet have a minigame scene, gameplay transport messages,
host start control, round orchestration, or results runtime.

The recommended design uses Godot's existing scene lifecycle, `_process`,
signals, Resources, and the current debug launcher. It does not add a custom
state-object framework, general event bus, simulated-player system, device
farm, networking abstraction, or runtime tuning UI. Revisit those only if a
measured implementation problem creates a concrete need.

The owner-confirmed decisions above close the planning questions without
claiming implementation or player validation. No gameplay, audio, browser,
editor, runtime, device, or human-play validation is claimed until the
follow-up tasks produce it.

# Draft Execution Prompt

Read this task, [[001 - Dancer simon says]], [[PS-001 - Define the First Gameplay Milestone]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[PS-006 - Implement Player Join and Host-Owned Registry]], [[PS-007 - Define the Gameplay Debug Suite]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-013 - Implement Pose Charge and Evaluation Rules]], [[PS-014 - Implement Minimal Gameplay Debug Launcher]], [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[PS-016 - Create Wireframe for 001 - Dancer Simon Says]], [[PS-017 - Find Better Environment Assets for 001 - Dancer Simon Says]], [[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]], [[PS-020 - Find Music and SFX for 001 - Dancer Simon Says]], [[Project Overview]], [[Workflow]], [[Task System]], [[Decision Log]], [[Releases]], and [[DEVELOPMENT]]. Inspect both the parent vault and
the nested Godot repository, current task statuses, scenes, protocol, tuning,
and supplied asset paths. Refine this plan and its bounded follow-up tasks
with the human project owner. Do not implement code, assets, fake stops, or
browser behavior. Preserve blank priority/release fields, stable task IDs and
links, host authority, the approved animation boundary, and separate evidence
categories. This planning task is complete after the owner confirmed the
decisions above; implementation tasks remain separately scoped and must still
be prioritized and executed in the stated order.

# Outcome

Owner confirmed the three implementation-policy choices on 2026-09-16. The
decomposition and execution order are complete; implementation and all runtime,
device, and human-play validation remain in PS-013 and PS-023 through PS-029.
