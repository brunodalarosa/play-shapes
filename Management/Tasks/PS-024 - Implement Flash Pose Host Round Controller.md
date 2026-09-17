---
id: PS-024
title: "Implement Flash? Pose! host round controller"
type: implementation
status: backlog
release:
owner: ai
priority:
depends_on:
  - "[[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]]"
  - "[[PS-013 - Implement Pose Charge and Evaluation Rules]]"
  - "[[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]]"
  - "[[PS-006 - Implement Player Join and Host-Owned Registry]]"
  - "[[PS-012 - Implement Milestone 1 Character Animation System]]"
---

# Goal

Implement the host-authoritative Flash? Pose! round model that turns the
approved pose rules and editor-visible stage into a deterministic, observable
round lifecycle. Keep networking, browser rendering, audio playback, and
shared-screen presentation outside this controller.

# Scope

- Add a small `FlashPoseRoundController` owned by the minigame scene with
  explicit phases: countdown, dance, genuine-stop grace, resolve, flash wait,
  results wait, and lobby return.
- Snapshot the registered participants at start, keep stable `player_id` and
  seat identity, and maintain plain per-player state for two lives, pose
  charge, elimination, withdrawal, reaction, and life-loss order.
- Choose one of the three music/style pairs for a round, choose genuine stop
  targets from the currently unlocked directions, and apply the tunable round
  timer, stop interval, difficulty reduction, and unlock thresholds.
- Provide a narrow input method for the later protocol adapter to submit
  validated press/release events with host receipt time and sequence number.
  The controller must reject unknown players, unknown directions, wrong
  phases, duplicate/out-of-order sequences, and late input without mutating a
  resolved stop.
- Preserve each uninterrupted stop's direction, charge, and held state, run
  PS-013 at the host grace deadline, apply the three-part success rule, deduct
  one life for every failure, and mark a player eliminated at zero lives.
- Observe registry changes without owning identity: explicit Leave withdraws a
  player without a life loss; a reconnecting player remains represented but
  has no held input until a valid resume and new press.
- Publish narrow signals for phase changes, semantic animation updates,
  genuine-stop start, resolved results, flash request/completion, result
  snapshot, and return-to-lobby request. Emit the flash request only after
  results are fixed and only once per genuine `stop_id`.
- Produce the limited ranking required by [[001 - Dancer simon says]]: last
  remaining player highest, elimination order for eliminated players, then
  remaining lives and life-loss order at timeout, with stable player ID only
  for the all-perfect fallback.
- Add deterministic tests using injected time, target/style sequences, and
  direct input calls. Tests must not require simulated network clients.

# Non-Goals

- Parsing WebSocket packets, sending browser messages, or implementing phone
  controls; that belongs to [[PS-025 - Implement Flash Pose Phone Protocol and Controller]].
- Instantiating or positioning the editor-visible stage, drawing UI, playing
  music/SFX/VFX, or rendering results; those belong to [[PS-026 - Implement Flash Pose Shared Screen Feedback and Results]].
- Adding fake music stops, a score/points system, a cross-minigame session, a
  next-minigame queue, or a general state-machine framework.
- Compensating for network latency or accepting client-authored timestamps.

# Acceptance Criteria

- The controller's transition graph is explicit, invalid transitions are
  harmless, and one round can proceed through countdown, dance, genuine stop,
  grace, resolve, flash wait, another cycle, results, and return request.
- Host time is the only authority for countdown, round timeout, stop deadline,
  and input lateness. A deterministic test proves an input at the deadline is
  handled consistently and an input after it cannot change the result.
- Each genuine stop preserves an uninterrupted hold and resolves correct
  direction + full charge + held input, applies exactly one life loss per
  failure, and eliminates at zero lives without reading animation frames.
- Explicit Leave withdraws a player without a life loss; a temporary
  reconnecting state does not invent a held input or a new player identity.
- The controller emits results before one `flash_requested` event and cannot
  emit a second flash for the same stop, even if completion or transition
  callbacks repeat. It resumes only after a matching `flash_completed`.
- The target/style sequence can be injected for tests, while normal play uses
  the approved two-to-four pose progression and one style/track for the whole
  round.
- Ranking and two-player/one-player-debug termination conditions match the
  canonical design without adding points or unapproved tiebreakers.
- Focused `[AUTO]` rule/state tests pass and `DEVELOPMENT.md` records the
  controller ownership, signals, timing model, provisional defaults, and
  limitations. No runtime or human-feel claim is made by the unit tests.

# Game Feel / Player Experience

The controller protects fairness: the lead pose is revealed before the grace
window begins, the host resolves once, and the flash never creates a hidden
extra reaction window. It keeps the pressure readable through predictable
life loss and elimination while leaving exact interval and grace values open
to the named tuning workflow and human play.

# Open Questions

- If playtesting shows the no-latency-compensation rule is unfair, create a
  focused networking/timing task rather than expanding this controller.

# Notes / Findings

The current `PoseCharge` is a standalone semantic value object, while the
current `SessionHost` and `PlayerRegistry` survive scene changes. This task
should keep the round controller scene-scoped and let the persistent host
provide identity/action boundaries. A small enum plus transition method is
preferred over state subclasses for this fixed first flow.

# Draft Execution Prompt

Read this task, [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[PS-013 - Implement Pose Charge and Evaluation Rules]], [[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]], [[PS-006 - Implement Player Join and Host-Owned Registry]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[001 - Dancer simon says]], [[Decision Log]], and
[[DEVELOPMENT]]. Inspect the current scene, registry, tuning, animator, and
pose-charge code before editing. Implement only the host-owned round lifecycle
and its narrow semantic signals/direct input seam. Use host monotonic time,
explicit transitions, stable player IDs, deterministic injection for tests,
and the approved lives/ranking rules. Do not parse browser packets, edit child
sprites, play audio/VFX, add fake stops, or build a general state framework.
Expose new player-facing timing values through the existing tuning preset,
add focused boundary tests, update development notes, and report `[AUTO]`
evidence separately from runtime/device/human evidence. Follow GitHub Flow and
keep unrelated changes out of the pull request.

# Outcome
