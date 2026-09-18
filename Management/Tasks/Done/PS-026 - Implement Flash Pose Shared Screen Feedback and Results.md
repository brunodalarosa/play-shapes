---
id: PS-026
title: "Implement Flash? Pose! shared-screen feedback and results"
type: implementation
status: done
release:
owner: ai
priority:
depends_on:
  - "[[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]]"
  - "[[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]]"
  - "[[PS-012 - Implement Milestone 1 Character Animation System]]"
  - "[[PS-015 - Implement Shared Tuning Asset and Preset Workflow]]"
  - "[[PS-023 - Prepare Flash Pose Runtime Music and SFX]]"
  - "[[PS-024 - Implement Flash Pose Host Round Controller]]"
---

# Goal

Turn the editor-visible PS-018 stage and PS-024 signals into a readable
shared-screen Flash? Pose! experience with animated characters, music, genuine
stop feedback, lives/reactions, and the two-tier results presentation.

# Scope

- Populate PS-018's lead anchor and stable `Seat01`–`Seat10` slots with the
  existing `ShapeCharacter` and `HybridCharacterAnimator` components. Assign
  stable seat colors/phases, keep the lead emphasized, and pass semantic pose,
  reaction, elimination, and result-mood state through the approved animator
  API.
- Add responsive shared-screen UI for the Flash? Pose! title, countdown,
  current direction/icon/text, active player names/status/lives, stop/result
  feedback, and safe areas from the approved wireframe. Keep the lead pose
  visually dominant without hiding the player row.
- Add a small presentation/audio boundary with three track/style mappings,
  looping BGM, and the supplied flash SFX candidates. Keep music playing
  during dance, pause it at a genuine stop, and resume the same stream only
  after the flash-completion signal.
- Implement a reversible code-native camera-flash overlay and one matching
  SFX/VFX trigger per genuine `stop_id`. Guard duplicate signals and make sure
  the flash does not obscure the pose before resolution, stick on screen, or
  hide lives/results. No generic music-paused callback may trigger it.
- Render results as the canonical upper happy group and lower moody group with
  names and readable context, without points or a cross-minigame scoreboard.
  Leave the view waiting for the host-controlled return action supplied by
  [[PS-027 - Integrate Flash Pose Lobby and Debug Flow]].
- Expose flash duration/intensity, audio gain, and any required resume fade in
  the existing Simon Says tuning preset with Inspector descriptions, clamps,
  and validation. Keep final values provisional until human review.
- Add focused scene/presentation tests or deterministic capture hooks and
  update `DEVELOPMENT.md` with node ownership, asset paths, flash ordering,
  and tuning instructions.

# Non-Goals

- Owning pose success, charge, lives, ranking, timing deadlines, or player
  identity; consume PS-024 snapshots and PS-013 semantics only.
- Parsing phone packets, creating phone controls, or changing the WebSocket
  protocol; that belongs to [[PS-025 - Implement Flash Pose Phone Protocol and Controller]].
- Composing editor placement data or replacing selected environment assets;
  use PS-018 and the approved PS-017 result.
- Designing or implementing fake music stops, a scoreboard, multiple
  minigames, or final feel/audio approval.

# Acceptance Criteria

- The minigame scene loads and presents the approved environment, lead,
  supported player slots, responsive UI, and Flash? Pose! player-facing name
  without hard-coded viewport dimensions.
- The lead and every participating player receive the correct semantic
  direction/charge/held/reaction/elimination state through the PS-012 API;
  presentation code never reads sprite transforms to decide an outcome.
- A technical runtime sequence demonstrates dance -> genuine stop -> pose
  grace -> resolved result -> exactly one camera flash -> music resume. The
  flash cannot retrigger for duplicate completion/result callbacks and a future
  fake-stop source has no flash route.
- BGM maps unambiguously to the three animation styles, starts/stops/resumes
  without leaking players or leaving stale audio after scene teardown, and
  loads the prepared runtime assets from PS-023.
- Results show the canonical happy/moody groups and remain until the host
  returns to the lobby; no score or unapproved tiebreaking is displayed.
- Shared-screen direction, status, lives, and elimination feedback use more
  than color or audio alone and remain inspectable at the intended layout
  sizes. A technical capture is evidence of rendering, not human readability
  approval.
- Focused `[AUTO]`, `[EDITOR]`, and `[GODOT-RUNTIME]` checks pass, and
  `DEVELOPMENT.md` records exact scene/resource paths and provisional tuning.

# Game Feel / Player Experience

This is the visible heartbeat of the minigame. The stage should feel alive
while the lead remains the obvious teacher; a stop should hold attention long
enough to copy the pose, resolve fairly, then punctuate the snapshot without
making the display unreadable. Results should communicate emotional grouping
without turning the first proof into a dashboard.

# Open Questions

- The owner must review flash brightness, duration, SFX choice, music resume,
  and couch-distance readability in PS-029. Keep candidate presets reversible.
- If the selected environment or audio lacks enough contrast/loop metadata,
  record the exact asset gap and create a focused follow-up rather than
  substituting unrelated content.

# Notes / Findings

PS-018 is intentionally only the editor-visible composition. This task is the
runtime population and presentation layer that consumes its anchors. The
current animator already provides lead/player roles, phase offsets, reactions,
elimination, and results moods; do not duplicate those rules in the scene.

# Draft Execution Prompt

Read this task, [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]], [[PS-024 - Implement Flash Pose Host Round Controller]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-023 - Prepare Flash Pose Runtime Music and SFX]], [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[PS-016 - Create Wireframe for 001 - Dancer Simon Says]], [[PS-017 - Find Better Environment Assets for 001 - Dancer Simon Says]], [[001 - Dancer simon says]], and [[DEVELOPMENT]]. Inspect the scene anchors, animator semantic API,
tuning Resource, prepared audio, and current renderer conventions before
editing. Implement only the responsive shared-screen presentation, semantic
character population, music/flash feedback, and results view. Make the genuine
stop ordering and one-flash guard explicit, keep fake stops out, use
designer-accessible values, add focused editor/runtime checks, and distinguish
technical captures from human readability/audio/feel approval. Follow GitHub
Flow and keep unrelated changes out of the pull request.

# Outcome

Completed on 2026-09-17. `dancer_simon_says.tscn` now owns a focused
`FlashPosePresentation` that populates the approved lead/seat anchors, drives
the existing semantic animator API, shows responsive countdown/direction/status
feedback, maps all three styles through the prepared audio catalog, and performs
one code-native flash/SFX per genuine resolved `stop_id` before resuming the
same music stream.

The persistent results overlay uses the controller's canonical
`top_group_size` to show named happy and moody groups without points or a
scoreboard. Flash duration/intensity, BGM/SFX gain, and resume fade are clamped,
Inspector-visible provisional values in the default Simon Says preset.

Focused presentation, scene, controller, audio, tuning, editor-load, and real
GL renderer checks passed. The 1280x720 dance/results captures are technical
rendering evidence only. PS-029 still owns human approval of flash comfort,
audio choice/mix/resume, couch-distance readability, physical-phone behavior,
and overall game feel.
