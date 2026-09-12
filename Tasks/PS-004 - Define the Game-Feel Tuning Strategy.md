---
id: PS-004
title: Define the game-feel tuning strategy
type: design
status: backlog
release:
owner: shared
priority:
depends_on: []
---

# Goal

Define a consistent, designer-friendly approach for exposing and explaining values that affect how Play Shapes feels, before gameplay systems establish incompatible tuning patterns.

# Scope

- Identify categories of feel values likely to recur across host gameplay, camera, animation, UI, audio, haptics, and phone controls.
- Investigate the most appropriate Godot- and web-facing exposure mechanisms for this project.
- Define naming, grouping, defaults, safe ranges, units, ownership, and documentation expectations.
- Define how agents identify new feel parameters and report how the human can tune them.
- Define a lightweight experimental loop for comparing values and recording findings.

# Non-Goals

- Choosing final values for a minigame that has not been designed.
- Building editor tools, resources, settings screens, or runtime debug menus.
- Centralizing every constant regardless of whether it affects player experience.
- Mandating one storage mechanism before project-specific evidence is reviewed.

# Acceptance Criteria

- The strategy states which kinds of values qualify as game-feel controls.
- Recommended exposure mechanisms and their tradeoffs are explained for an experienced programmer who is new to Godot.
- The human can tell where to find, change, reset, and compare relevant values without reading underlying logic.
- Guidance covers bounds, units, defaults, presets/versioning, and preventing invalid combinations.
- Future implementation tasks have a short checklist for documenting tunables and their validation experiments.
- Unresolved tooling needs become separate bounded tasks.

# Game Feel / Player Experience

This task governs input thresholds, dead zones, sensitivity, acceleration, speed, friction, drag, jump timing, buffering, coyote time, cooldowns, animation/transition timing, camera effects, particles, UI timing, feedback delays, SFX relationships, haptics, color feedback, hit-stop, slow motion, and similar responsiveness constants.

# Open Questions

- Which values belong in reusable Godot resources versus scene-local inspector properties?
- Which web-controller values need a shared configuration source or runtime synchronization?
- Does the human need runtime adjustment and side-by-side presets in the first gameplay milestone?
- How should tuning changes be recorded so agents can reason about experiments without creating process overhead?

# Notes / Findings


# Draft Execution Prompt

Read [[PS-004 - Define the Game-Feel Tuning Strategy]], [[Project Overview]], [[Decision Log]], [[DEVELOPMENT]], and the current Godot/web project structure. Investigate project-appropriate designer-facing tuning patterns and facilitate decisions with the human. Produce concise conventions and an experimental checklist, clearly separating recommended choices from unresolved questions. Do not implement resources, tools, configuration, or gameplay changes.

# Outcome
