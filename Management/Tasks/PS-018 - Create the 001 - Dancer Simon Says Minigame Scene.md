---
id: PS-018
title: Create the 001 - Dancer Simon Says minigame scene
type: implementation
status: backlog
release:
owner: ai
priority:
depends_on:
  - "[[PS-016 - Create Wireframe for 001 - Dancer Simon Says]]"
  - "[[PS-017 - Find Environment Assets for 001 - Dancer Simon Says]]"
  - "[[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]]"
---

# Goal

Create the editor-visible Godot scene that composes the Dancer Simon Says
gameplay stage from the approved wireframe, selected environment assets, and
existing character components. The scene must define where the lead and player
characters appear while keeping those placements directly editable by a human.

# Scope

- Add a reusable Dancer Simon Says gameplay scene using the approved
  environment set and current character/animation components.
- Define the lead-dancer placement and a stable set of human-editable player
  placement slots for the supported 2–10 player range.
- Keep placements visible in the Godot editor before the game is run, with
  names, markers, nodes, or another clear authoring representation that a
  human can move and save without editing code.
- Preserve responsive, screen-relative composition and the project's
  no-hard-coded-viewport-dimensions rule.
- Make the scene boundary clear enough for later orchestration, pose
  evaluation, phone feedback, and results work without implementing those
  systems here.
- Add focused scene/editor-load coverage and update [[DEVELOPMENT]] with the
  scene path, placement authoring workflow, asset references, and caveats.

# Non-Goals

- Implementing the round loop, music, stop timing, pose charge/evaluation,
  ranking, elimination rules, networking, or phone UI.
- Creating or reworking character or environment art.
- Implementing the results screen, scoreboard, fake music stops, or complete
  lobby-to-minigame transitions.
- Generating player placements only at runtime in a way that hides them from
  the editor or requires code changes for ordinary layout tuning.

# Acceptance Criteria

- The scene opens in Godot 4.7.2 without script, resource, or import errors and
  presents the approved environment composition.
- The lead placement and all supported player slots are visible and clearly
  named or marked in the editor before running the game.
- A human can move, reorder, or adjust the placement representation in the
  editor, save the scene, and see the change persist without changing code.
- The layout remains readable for the intended small and full player counts and
  matches the approved wireframe's hierarchy and safe areas.
- The scene references the selected environment assets and existing character
  building blocks without duplicating or silently replacing their sources.
- Focused automated/editor evidence verifies the scene structure and load; any
  runtime or visual result is reported separately from human visual approval.
- The project owner performs and approves the visual placement review before
  this task is marked done.

# Game Feel / Player Experience

Placement controls the first read of every stop: the lead must command
attention, while the player row must remain easy to scan for reactions and
elimination. The scene should leave enough breathing room for character motion
and feedback overlays without making the group feel disconnected.

# Open Questions

- Which scene node or resource representation best supports responsive slot
  placement while remaining friendly to a Godot-new human editor?
- Should eliminated players keep their slot, move to a reserved area, or be
  visually handled by the later gameplay system?
- Which parts of the wireframe need a reusable scene component versus a later
  gameplay overlay?
- Does the selected environment require a small import or rework follow-up
  before visual approval?

# Notes / Findings

This task is deliberately a placement/composition slice, not the complete
minigame implementation. [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]] must define the broader orchestration boundary and any
additional implementation tasks before this scene is executed.

# Draft Execution Prompt

Read this task, [[PS-016 - Create Wireframe for 001 - Dancer Simon Says]],
[[PS-017 - Find Environment Assets for 001 - Dancer Simon Says]], [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[001 - Dancer simon says]], [[PS-012 - Implement Milestone 1 Character Animation System]],
[[PS-014 - Implement Minimal Gameplay Debug Launcher]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[Project Overview]], [[Decision Log]], and [[DEVELOPMENT]] first. Inspect the existing scene, character, asset,
and editor conventions before editing. Implement only the reusable
editor-visible stage composition and placement slots described here. Use the
approved assets and preserve host authority, responsive layout, current
character animation boundaries, and human-editable scene data. Add focused
tests or editor checks, distinguish `[AUTO]`, `[EDITOR]`, `[GODOT-RUNTIME]`, and
`[HUMAN-PLAY]` evidence, document how a human tunes placements, and avoid
implementing the broader gameplay loop or unrelated refactors.

# Outcome
