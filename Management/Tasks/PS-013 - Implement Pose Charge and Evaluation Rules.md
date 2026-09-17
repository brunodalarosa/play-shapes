---
id: PS-013
title: Implement pose charge and evaluation rules
type: implementation
status: backlog
release: Milestone 1
owner: ai
priority:
depends_on:
  - "[[PS-004 - Define the Game-Feel Tuning Strategy]]"
  - "[[PS-015 - Implement Shared Tuning Asset and Preset Workflow]]"
  - "[[PS-006 - Implement Player Join and Host-Owned Registry]]"
  - "[[PS-012 - Implement Milestone 1 Character Animation System]]"
  - "[[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]]"
---

# Goal

Implement the host-authoritative direction charge, grace-window evaluation, and
semantic animation-state output required by Flash? Pose!, without coupling game
rules to character animation frames.

# Scope

- Maintain one host-owned charge state per participating `player_id`, including
  selected direction, normalized charge from 0 to 1, and the host receipt
  time/sequence of the latest validated input.
- Fill charge while the same direction is held, reset to zero when changing to a
  different direction, and drain much faster than fill after release without an
  instant reset. Re-pressing the same direction continues from the drained value,
  allowing rapid taps to accumulate less efficiently than holding.
- Let players begin or correct their direction during the grace window following
  a genuine music stop. Each stop receives a fresh neutral baseline; a stale
  hold from an earlier stop is not evaluated for the new stop.
- At the authoritative evaluation instant, succeed only when direction matches,
  charge is 1, and that direction remains held. Treat changes after the grace
  window/evaluation as failure for that stop rather than retroactive correction.
  Use host monotonic time; do not accept client-authored timestamps or apply
  latency compensation in this first version.
- Expose fill duration, decay duration/rate, grace duration, and the relationship
  between the audible full stop, pose reveal, and evaluation as validated
  designer-facing game-feel controls.
- Emit normalized semantic state to [[PS-012 - Implement Milestone 1 Character Animation System]]; never read animation frames or sprite transforms to decide rules.
- Emit an authoritative result/elimination record for the later protocol layer.
  The phone task, not this rules object, delivers the exact player-facing
  message `You've been eliminated :(` through the validated controller
  boundary.
- Treat an explicit player Leave as withdrawal outside pose evaluation. A
  temporary reconnecting player has no held input until a valid resume and new
  press; the proposed MVP consequence for missing input is the normal failure
  rule.
- Add deterministic tests for holds, releases, taps, direction changes, boundary
  timestamps, full charge, grace timing, and late/invalid input.
- Update [[DEVELOPMENT]] with the state model, timing ownership, tunables, protocol
  boundary, tests, and integration caveats.

# Non-Goals

- Authoring animation clips, reactions, music, fake stops, scoring, ranking, or
  complete round orchestration.
- Letting browser clients or animation components decide charge or success.
- Parsing WebSocket packets, sending phone messages, or owning the round
  lifecycle; those belong to the later protocol and round-controller tasks.
- Finalizing timing values without human playtesting.
- Implementing a player-facing charge meter or separate commitment indicator.

# Acceptance Criteria

- The host produces deterministic normalized charge for every participating
  player from validated input received at host time; client timestamps cannot
  alter the result.
- Direction changes reset charge; releasing drains rather than resets; same-
  direction repress continues from the remaining value; fast tapping can build
  charge but is less effective than holding.
- Each genuine stop starts neutral. Evaluation requires correct direction,
  charge 1, and held input at the grace deadline. Corrections before that
  deadline are accepted; late changes are not.
- Default configuration supports a 1-second fill and an illustrative 1.2-second
  maximum-difficulty grace period, while all feel values remain human-tweakable
  and clearly documented as provisional.
- Animation receives semantic direction, charge, held, reaction, and elimination
  state without becoming authoritative.
- Invalid, duplicated, out-of-order, disconnected, and late client input cannot
  directly mutate resolved results. Explicit Leave is withdrawal; a
  reconnecting player is not treated as holding a direction.
- Focused automated tests cover normal behavior and timing boundaries; runtime
  integration and human game-feel playtesting are reported separately.
- An eliminated player remains represented to the shared-screen animation
  system, and the later protocol adapter can deliver `You've been eliminated :(`
  to that player's phone from the authoritative elimination record.

# Notes / Findings

PS-013 owns semantic charge and evaluation only. It returns data/signals to the
round controller; it does not know browser packet shapes, player-facing copy,
audio, or scene presentation. The controller resets the charge baseline at a
genuine stop and supplies the current host deadline.

# Game Feel / Player Experience

Early difficulty should provide enough grace to learn the visual commitment
model. At high difficulty, an illustrative 1.2-second grace with a 1-second fill
leaves about 0.2 seconds of reaction margin. These are starting hypotheses, not
final balance values.

# Open Questions

- The owner must confirm the fresh-stop baseline and temporary disconnect rule
  proposed by [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]] before this task is treated as ready.
- Final difficulty, decay, and grace values remain provisional until human
  two-phone playtesting. Revisit latency compensation only if that test gives
  concrete evidence that host-receipt timing is unfair.

# Draft Execution Prompt

Read this task, [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[PS-010 - Explore Character Animation Strategy]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-004 - Define the Game-Feel Tuning Strategy]], [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[PS-006 - Implement Player Join and Host-Owned Registry]], [[001 - Dancer simon says]], [[Decision Log]], and [[DEVELOPMENT]]. Inspect the current pose-charge class, host protocol boundary, and gameplay plan before editing. Implement deterministic host-authoritative normalized charge and grace-window evaluation with explicit host-time and sequence behavior. Preserve correction during grace, fast nonzero decay after release, same-direction repress continuity, reset on direction change and at each new stop, and the three-part success condition. Feed semantic state to animation without reading visual frames. Return authoritative result/elimination data without parsing packets or sending browser copy. Add boundary-heavy automated tests, document tunables and caveats in `DEVELOPMENT.md`, and keep networking, round orchestration, human feel, and physical-phone validation distinct. Follow GitHub Flow and open a pull request; keep broader minigame presentation outside this task.

# Outcome
