---
id: PS-013
title: Implement pose charge and evaluation rules
type: implementation
status: backlog
release: Milestone 1
owner: ai
priority:
depends_on:
  - PS-004
  - PS-006
  - PS-012
---

# Goal

Implement the host-authoritative direction charge, grace-window evaluation, and
semantic animation-state output required by Dancer Simon Says, without coupling
game rules to character animation frames.

# Scope

- Track each active player's selected direction, normalized charge from 0 to 1,
  held state, and relevant input timestamps on the authoritative host.
- Fill charge while the same direction is held, reset to zero when changing to a
  different direction, and drain much faster than fill after release without an
  instant reset. Re-pressing the same direction continues from the drained value,
  allowing rapid taps to accumulate less efficiently than holding.
- Let players begin or correct their direction during the grace window following
  a genuine music stop.
- At the authoritative evaluation instant, succeed only when direction matches,
  charge is 1, and that direction remains held. Treat changes after the grace
  window/evaluation as failure for that stop rather than retroactive correction.
- Expose fill duration, decay duration/rate, grace duration, and the relationship
  between the audible full stop, pose reveal, and evaluation as validated
  designer-facing game-feel controls.
- Emit normalized semantic state to [[PS-012 - Implement Milestone 1 Character Animation System]]; never read animation frames or sprite transforms to decide rules.
- Send the eliminated player's phone the message `You've been eliminated :(`
  through the existing validated controller protocol boundary when elimination
  integration is available.
- Add deterministic tests for holds, releases, taps, direction changes, boundary
  timestamps, full charge, grace timing, and late/invalid input.
- Update [[DEVELOPMENT]] with the state model, timing ownership, tunables, protocol
  boundary, tests, and integration caveats.

# Non-Goals

- Authoring animation clips, reactions, music, fake stops, scoring, ranking, or
  complete round orchestration.
- Letting browser clients or animation components decide charge or success.
- Finalizing timing values without human playtesting.
- Implementing a player-facing charge meter or separate commitment indicator.

# Acceptance Criteria

- The host produces deterministic normalized charge for every active player from
  timestamped validated input.
- Direction changes reset charge; releasing drains rather than resets; same-
  direction repress continues from the remaining value; fast tapping can build
  charge but is less effective than holding.
- Evaluation requires correct direction, charge 1, and held input at the grace
  deadline. Corrections before that deadline are accepted; late changes are not.
- Default configuration supports a 1-second fill and an illustrative 1.2-second
  maximum-difficulty grace period, while all feel values remain human-tweakable
  and clearly documented as provisional.
- Animation receives semantic direction, charge, held, reaction, and elimination
  state without becoming authoritative.
- Invalid, duplicated, out-of-order, disconnected, and late client input cannot
  directly mutate resolved results.
- Focused automated tests cover normal behavior and timing boundaries; runtime
  integration and human game-feel playtesting are reported separately.
- An eliminated player remains represented to the shared-screen animation system
  and receives `You've been eliminated :(` on their phone.

# Game Feel / Player Experience

Early difficulty should provide enough grace to learn the visual commitment
model. At high difficulty, an illustrative 1.2-second grace with a 1-second fill
leaves about 0.2 seconds of reaction margin. These are starting hypotheses, not
final balance values.

# Open Questions

- Final difficulty curve and exact alignment of audio stop, pose reveal, grace
  start, and evaluation.
- Final decay curve and whether network latency compensation is needed after
  real multi-phone testing.
- The precise protocol event that carries elimination UI state once the player
  registry and minigame protocol exist.

# Draft Execution Prompt

Read [[PS-013 - Implement Pose Charge and Evaluation Rules]], [[PS-010 - Explore Character Animation Strategy]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-004 - Define the Game-Feel Tuning Strategy]], [[PS-006 - Implement Player Join and Host-Owned Registry]], [[001 - Dancer simon says]], [[Decision Log]], and [[DEVELOPMENT]]. Inspect the current host protocol and gameplay boundaries before editing. Implement deterministic host-authoritative normalized charge and grace-window evaluation with explicit timestamp behavior. Preserve correction during grace, fast nonzero decay after release, same-direction repress continuity, reset on direction change, and the three-part success condition. Feed semantic state to animation without reading visual frames. Add boundary-heavy automated tests and proportional runtime checks; keep networking validation and human feel evaluation distinct. Document tunables and caveats in DEVELOPMENT.md. Follow GitHub Flow and open a pull request; keep broader minigame orchestration outside this task.

# Outcome
