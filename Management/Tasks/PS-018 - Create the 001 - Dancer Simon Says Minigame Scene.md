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
  - "[[PS-017 - Find Better Environment Assets for 001 - Dancer Simon Says]]"
  - "[[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]]"
---

# Goal

Create the editor-visible Godot scene that composes the Flash? Pose! gameplay
stage from the approved wireframe, selected environment assets, and existing
character components. The scene must define where the lead and player
characters appear while keeping those placements directly editable by a human.

# Scope

- Add a reusable Dancer Simon Says gameplay scene using the approved
  environment set and current character/animation components.
- Define the lead-dancer placement and a stable set of human-editable player
  placement slots for the supported 2–10 player range.
- Preserve the already reserved internal scene path
  `res://minigames/dancer_simon_says.tscn` so the existing debug registration
  does not require a compatibility rename. Use the exact `Flash? Pose!` name
  only in player-facing labels.
- Use a named lead anchor and ten stable seat anchors (for example,
  `LeadSlot` and `PlayerSlots/Seat01` through `Seat10`) so the later round and
  presentation tasks can populate the scene without searching or relocating
  nodes at runtime.
- Keep eliminated or reconnecting players in their assigned seat; later
  gameplay/presentation systems may change their visual state but must not
  silently reshuffle the shared-screen formation.
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
- Implementing the round state machine, phone protocol, shared-screen
  feedback, music, camera flash, results logic, or lobby navigation.

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
- The scene uses the reserved internal path and exposes one lead anchor plus
  ten stable, named player-seat anchors. A later system can populate two to ten
  seats without changing scene structure, and a human can move/save those
  anchors in the editor without code changes.
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

- The owner may adjust anchor names or visual safe-area placement during the
  PS-016-based review, but the lead/ten-seat boundary and stable-slot behavior
  should remain intact.
- Does the selected environment require a small import or rework follow-up
  before visual approval?

# Notes / Findings

This task is deliberately a placement/composition slice, not the complete
minigame implementation. [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]] defines the broader orchestration boundary and the later tasks that populate these anchors. The scene path remains filesystem-safe and stable even though the player-facing name is Flash? Pose!.

# Draft Execution Prompt

Read this task, [[PS-016 - Create Wireframe for 001 - Dancer Simon Says]], [[PS-017 - Find Better Environment Assets for 001 - Dancer Simon Says]], [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[001 - Dancer simon says]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-014 - Implement Minimal Gameplay Debug Launcher]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[Project Overview]], [[Decision Log]], and [[DEVELOPMENT]] first. Inspect the existing scene, character, asset, and editor conventions before editing. Implement only the reusable editor-visible stage composition, the stable `res://minigames/dancer_simon_says.tscn` path, and named lead/seat anchors described here. Use the approved assets and preserve host authority, responsive layout, current character animation boundaries, stable seat identity, and human-editable scene data. Add focused scene/editor checks, distinguish `[AUTO]`, `[EDITOR]`, `[GODOT-RUNTIME]`, and `[HUMAN-PLAY]` evidence, document how a human tunes placements, and avoid implementing the broader gameplay loop or unrelated refactors.

# Outcome
