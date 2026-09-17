---
id: PS-016
title: Create wireframe for 001 - Dancer Simon Says minigame
type: wireframes-and-art-mockups
status: done
release:
owner: human
priority:
depends_on: []
---

# Goal

Create the human-approved visual layout reference for the Dancer Simon Says
gameplay screen and its companion phone control, so scene composition and later
implementation work have a concrete placement target.

# Scope

- Show the shared-screen gameplay composition: lead dancer, player-character
  row or formation, status/lives treatment, pose cue, and the main safe areas.
- Show the important gameplay states needed to reason about placement: active
  dancing, music stop and pose evaluation, and a player who has been eliminated.
- Include the phone control layout for the directional press-and-hold regions,
  pairing each choice with both a color and an icon.
- Provide at least a small-player and full-player-count view so the layout can
  be checked for 2 and 10 players without inventing a fixed viewport size.
- Annotate hierarchy, readability from the normal shared-screen distance, and
  any areas intentionally reserved for future feedback or audio cues.

# Non-Goals

- Producing final production art, animation, audio, or implementation scenes.
- Choosing final numeric timing, difficulty, ranking, or accessibility behavior
  that remains open in [[001 - Dancer simon says]].
- Designing the results screen, cross-minigame scoreboard, or fake music stops.
- Completing the task through an agent while `owner: human` remains in place.

# Acceptance Criteria

- A source wireframe and a reviewable export are stored in the agreed project
  design location and linked from this task's outcome when complete.
- The shared-screen layout makes the lead pose and every active player's
  character/status legible at the intended viewing distance.
- The composition remains understandable for both 2 and 10 active players,
  including the treatment of empty or eliminated player positions.
- The phone layout communicates directional choices through distinct icons and
  colors and remains plausible for one-thumb press-and-hold use.
- The wireframe identifies unresolved visual decisions instead of silently
  turning them into implementation requirements.
- The project owner explicitly approves the wireframe as the reference for
  implementation tasks.

# Game Feel / Player Experience

The layout should make the shared display the primary attention target while
keeping the phone action simple and peripheral. The lead pose must read first,
player reactions second, and lives/elimination feedback without making the
screen feel like a dashboard. Empty space, scale, and contrast should support
playful tension rather than crowding the dancers.

# Open Questions

- Should player status sit beside each character, in a shared strip, or use a
  small combination of both?
- How much of the shared screen is reserved for a pose cue or stop indicator
  before it competes with the lead dancer?
- Which visual accessibility alternatives need to be called out in the first
  wireframe beyond the icon-plus-color pairing?
- What aspect ratio or couch-distance reference should the owner use for the
  review export?

# Notes / Findings

This is intentionally a human-only visual planning task for now. The output is
the reference used by [[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]],
not a commitment to final art or a runtime UI implementation.

# Draft Execution Prompt

Read [[001 - Dancer simon says]], [[PS-001 - Define the First Gameplay Milestone]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[Project Overview]], and [[Decision Log]]. Create a rough, human-readable wireframe and
review export for the shared gameplay screen and the phone pose control. Cover
active play, music stop/evaluation, 2-player and 10-player layouts, status and
elimination readability, safe areas, and unresolved accessibility questions.
Use the existing minigame rules as context, do not invent final values, and do
not create production assets or implementation code. This task remains
human-owned unless the project owner explicitly changes that ownership.

# Outcome
