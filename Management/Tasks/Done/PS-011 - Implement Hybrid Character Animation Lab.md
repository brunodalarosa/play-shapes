---
id: PS-011
title: Implement hybrid character animation lab
type: implementation
status: done
release: Milestone 1
owner: ai
priority:
depends_on:
  - "[[PS-014 - Implement Minimal Gameplay Debug Launcher]]"
  - "[[PS-010 - Explore Character Animation Strategy]]"
---

# Goal

Build the smallest in-game visual laboratory that proves the approved hybrid
detached-sprite animation strategy on one Shape Character and lets the human
judge it through the gameplay debug menu before production animation begins.

# Scope

- Use the existing `ShapeCharacter` body, face, hands, feet, pivots, tint shader,
  and standalone Double-resolution textures without changing asset provenance.
- Add one representative automatic dance loop with independently authored part
  transforms plus limited procedural body bounce/jiggle.
- Demonstrate all four canonical screen-relative poses: hands-up, both-hands-left
  wave, screen-right dab, and a playful/readable down-twerk.
- Add an interactive normalized pose-charge demonstration: default 1-second fill,
  much faster designer-tunable decay, direction changes resetting to zero,
  release visibly unwinding toward dance, snap at 1, and still hold while input
  remains held.
- Keep charge calculation deterministic and separate from visual interpolation so
  this prototype can expose the contract later gameplay will use.
- Register the lab with the in-game debug launcher implemented by [[PS-014 - Implement Minimal Gameplay Debug Launcher]]. A direct scene launch may remain as a developer fallback, but does not satisfy debug-menu acceptance.
- Expose provisional motion and timing controls in the Godot inspector or the
  project-approved mechanism from [[PS-004 - Define the Game-Feel Tuning Strategy]]
  when that strategy is available.
- Update [[DEVELOPMENT]] with controls, scene entry, tunables, architecture notes,
  validation evidence, and known visual questions.

# Non-Goals

- Producing all three dance loops or final reaction animations.
- Implementing phone input, networking, lives, elimination, round timing, music
  synchronization, fake stops, or authoritative Simon Says evaluation.
- Building a bone rig or a second competing animation architecture.
- Treating the prototype's timings, easing, or choreography as production-final.
- Redesigning the general debug suite beyond the smallest approved entry needed
  to reach this lab.

# Acceptance Criteria

- The human can open the lab from the in-game debug menu and return without
  entering a normal multiplayer session.
- One tintable six-part character performs a looping dance with readable detached
  limb motion and secondary body bounce/jiggle.
- Each of the four commands can be selected interactively and remains
  screen-directionally correct regardless of mirrored limb art.
- A visible debug readout may show direction and numeric charge for diagnosis,
  while the character itself uses no player-facing charge bar or separate cue.
- Holding fills charge, switching direction resets it, release drains it much
  faster than fill, rapid taps can accumulate charge, and charge 1 snaps to a
  still pose that remains held until release.
- Draw order, pivots, tinting, face readability, and transitions remain correct
  throughout every demonstrated state.
- The prototype runs without script/runtime errors and includes focused automated
  checks for deterministic charge-state transitions where practical.
- Human visual review explicitly approves, revises, or rejects the motion before
  [[PS-012 - Implement Milestone 1 Character Animation System]] begins.

# Game Feel / Player Experience

The experiment should answer whether the character feels playful, loose, and
musical while its command silhouette remains immediate. Detached hands and feet
provide the largest movement; the body supports them without hiding the cue.
Commitment should feel earned over the charge, then unmistakable at the snap.

# Open Questions

- Exact fill, decay, snap, bounce, jiggle, pose-hold, and unwind values.
- The best choreography for the representative dance loop and Down pose.
- Whether the existing pivots need small non-destructive adjustments.
- Which debug input layout makes repeated comparison fastest for the human.

# Draft Execution Prompt

Read [[PS-011 - Implement Hybrid Character Animation Lab]], [[PS-010 - Explore Character Animation Strategy]], [[PS-014 - Implement Minimal Gameplay Debug Launcher]], [[PS-004 - Define the Game-Feel Tuning Strategy]], [[PS-009 - Create and Import Character Feet Assets]], and [[DEVELOPMENT]]. Inspect the existing character scene and debug entry points before changing code. Implement one narrowly scoped hybrid-animation lab reachable from the approved in-game debug menu, using authored detached-sprite transforms plus limited procedural secondary motion. Demonstrate one dance loop, deterministic fill/decay behavior, release unwind, snap/hold, and all four canonical poses. Keep authoritative charge state separate from animation frames and do not implement networking or minigame rules. Add focused checks, run Godot parse/editor/runtime validation, capture visual evidence, and request human visual approval. Update DEVELOPMENT.md. Follow GitHub Flow and open a pull request; do not begin PS-012 in the same session.

# Outcome

2026-09-13: **done and approved**. The project owner approved the revised hybrid
animation lab after three visual iterations. The final base dance uses authored
detached-limb choreography, restrained normal/slow body jiggle with horizontal
sway, 30%-longer natural blinks, weighted facial micro-expressions, and slower
hand-shape variation dominated by open/closed hands. All four canonical command
poses were explicitly approved: Up uses rock hands, the screen-right dab uses
open hands, Left mixes open/peace, and Down mixes thumbs-up/open. Deterministic
charge, expression, hand-frequency, jiggle-cycle, launcher, editor, renderer,
foundation, and web checks passed. This approval completes PS-011 and permits a
separate future session to begin PS-012; no PS-012 work was included here.
