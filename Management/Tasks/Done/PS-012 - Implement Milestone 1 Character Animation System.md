---
id: PS-012
title: Implement Milestone 1 character animation system
type: implementation
status: done
release: Milestone 1
owner: ai
priority:
depends_on:
  - PS-004
  - PS-015
  - PS-011
---

# Goal

Turn the human-approved hybrid prototype into a reusable production animation
component and complete Milestone 1 animation vocabulary for the lead dancer and
up to ten player characters.

# Scope

- Create a narrow semantic character-animation API that accepts dance style,
  normalized pose charge and direction, reaction, elimination, and result mood
  without exposing sprite-track details to gameplay code.
- Author three music-track-specific automatic dance loops.
- Reuse one canonical set of four screen-relative command poses across all three
  styles and both character roles.
- Distribute player loop phases evenly; start the lead dancer at loop time zero.
- Allow lead-dancer role settings for readable emphasis and short tunable command-
  pose flows during music while keeping pose meaning shared with players.
- Implement visual charge interpolation, rapid release/unwind, snap/hold at full
  charge, and stillness at a genuine lead-dancer stop. Consume authoritative
  normalized charge rather than deciding gameplay success from animation time.
- Implement life-loss recoil/upset, successful-survival celebration, elimination
  to persistent sad stillness, happy results, and moody results animations.
- Keep timings, amplitudes, easing, pose-flow hold duration, role emphasis, and
  secondary motion accessible under the approved game-feel tuning convention.
- Preserve current tint/material behavior, responsive placement, screen-relative
  direction, documented pivots, and intentional draw order.
- Update [[DEVELOPMENT]] with the API, ownership boundaries, authoring workflow,
  tunables, performance evidence, and extension guidance.

# Non-Goals

- Implementing authoritative pose evaluation, phone controls, networking, lives,
  ranking, results orchestration, audio assets, or fake music stops.
- Adding skeletal rigging, physics, IK, collisions, ragdolls, or platforming.
- Creating animation systems for unrelated future minigames.
- Selecting final feel values without human playtesting.

# Acceptance Criteria

- Three visibly distinct dance loops are available through semantic dance-style
  selection and can be paired one-to-one with future music tracks.
- All four command poses share canonical data across styles and roles and remain
  unmistakable on the lead dancer and small bottom-row player characters.
- Eleven simultaneous characters animate correctly, with player phases evenly
  distributed and the lead dancer at phase zero; performance is measured on the
  project's target development machine and reported without overclaiming broader
  hardware coverage.
- Gameplay-facing callers never manipulate child sprites, animation tracks, or
  easing directly, and animations never determine authoritative success.
- Charge, unwind, snap/hold, lead freeze, and every required reaction are
  triggerable in debug tooling and behave consistently under interruption.
- Eliminated characters remain visible, sad-faced, and non-dancing.
- Runtime tinting, facial details, draw order, mirroring, and background contrast
  remain readable across representative colors and compositions.
- Automated state/API checks, Godot editor/runtime checks, an eleven-character
  performance sample, and human visual review are reported separately.

# Game Feel / Player Experience

Each track should have a recognizable dance identity without changing the visual
language of commands. Celebrations should matter, failures should read instantly,
and group motion should feel lively rather than synchronized like machinery.

# Open Questions

- Final choreography, reaction staging, and human-approved tuning values.
- Exact lead-dancer exaggeration and command-pose flow duration per difficulty.
- Whether modest deterministic variation beyond phase offsets improves repeated
  viewing without weakening cues.

# Draft Execution Prompt

Read [[PS-012 - Implement Milestone 1 Character Animation System]], the approved outcome and prototype from [[PS-011 - Implement Hybrid Character Animation Lab]], [[PS-010 - Explore Character Animation Strategy]], [[PS-004 - Define the Game-Feel Tuning Strategy]], [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[001 - Dancer simon says]], and [[DEVELOPMENT]]. Preserve the validated detached-sprite and tint setup. Implement a reusable semantic animation component, three track-specific dance loops, shared command poses, role-specific lead presentation, normalized-charge visuals, and all required reactions. Keep authoritative rules outside animation. Exercise every state through debug tooling, validate eleven simultaneous characters, run focused automated and Godot checks, and obtain human visual review. Document exact authoring and tuning guidance in DEVELOPMENT.md. Follow GitHub Flow and open a pull request; do not implement PS-013 or full minigame integration in the same session.

# Outcome

2026-09-15: **done and approved**. Implementation and automated/runtime evidence
are complete on `feat/ps-012-character-animation-system`. The
production semantic component, three dance styles, shared poses, lead/player
roles, ten evenly phased players, normalized charge display, lead freeze/flow,
all required reactions, persistent elimination, debug stage, tuning fields, and
focused checks are present. The project owner ran the game, tested the animations,
and reported being 100% satisfied with the Milestone 1 result. This explicitly
approves the motion and completes PS-012; later tuning may still evolve through
the normal named-preset workflow.
