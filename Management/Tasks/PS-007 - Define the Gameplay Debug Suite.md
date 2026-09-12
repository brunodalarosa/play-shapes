---
id: PS-007
title: Define the gameplay debug suite
type: design
status: backlog
release:
owner: shared
priority:
depends_on: []
---

# Goal

Define a lightweight, reusable debug suite that lets the human and implementation agents exercise gameplay systems quickly, including one-player testing of normally multiplayer experiences, without confusing debug convenience with the shipped player experience.

# Scope

- Define which gameplay states and actions should be reachable through debug controls.
- Define how a developer can run a multiplayer minigame with one real player and supply, simulate, or bypass any otherwise-required participants.
- Identify useful controls for starting, restarting, pausing, advancing, and ending gameplay scenarios.
- Identify ways to inspect or force player state, lives, difficulty, inputs, timing events, disconnections, and other relevant conditions.
- Define which controls belong in Godot, the browser controller, launch configuration, or test-only tooling.
- Establish safeguards and clear visual indicators so debug behavior is not mistaken for normal play.
- Coordinate with [[PS-005 - Define Multi-Phone and Agent Validation Strategy]] while keeping interactive debug tooling distinct from validation evidence.

# Non-Goals

- Implementing the debug suite.
- Building a general-purpose cheat console or production player settings screen.
- Replacing automated tests, physical-device checks, multi-player checks, or human playtests.
- Selecting debug controls for every possible future minigame before concrete needs exist.

# Acceptance Criteria

- The minimum debug workflows for gameplay development are documented.
- One-player testing behavior for normally multiplayer minigames is explicitly defined.
- Proposed controls identify where they appear, who can access them, and whether they may exist in exported builds.
- Debug-only state is visibly distinguishable and cannot silently alter normal sessions.
- The relationship between interactive debugging, automated tests, and validation evidence is clear.
- Implementation work is divided into bounded follow-up tasks only after the human approves the design.

# Game Feel / Player Experience

The suite should shorten the loop for experimenting with timing, feedback, difficulty, and failure states. Debug shortcuts must not be treated as evidence that the normal joining flow, group dynamics, shared-screen readability, phone experience, or multiplayer timing feels correct.

# Open Questions

- Should simulated players make choices automatically, replay recorded inputs, or be controlled from the host?
- Which debug controls are needed for the first gameplay milestone?
- Should debug tools be editor-only, enabled by a dedicated development setting, or compiled into non-release builds?
- Does the human need runtime adjustment of game-feel values here, or should that remain a separate concern of [[PS-004 - Define the Game-Feel Tuning Strategy]]?
- What debug state and event history should be visible or exportable when reproducing a problem?

# Notes / Findings

[[PS-001 - Define the First Gameplay Milestone]] established that every minigame should remain testable with one player even when its normal supported range begins at two players. The first milestone's normal target is 2–10 simultaneous players.

# Draft Execution Prompt

Read [[PS-007 - Define the Gameplay Debug Suite]], [[PS-001 - Define the First Gameplay Milestone]], [[PS-004 - Define the Game-Feel Tuning Strategy]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[Project Overview]], and the current Godot and browser-client structure. Facilitate a focused design session with the human, inventory existing test and runtime capabilities, and propose the smallest reusable debug workflows needed for the first gameplay milestone. Keep debug tooling separate from normal player UX and validation evidence. Do not implement tools or assign priority or release scope without human approval.

# Outcome
