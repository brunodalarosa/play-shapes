---
id: PS-008
title: Design fake music stops
type: design
status: backlog
release:
owner: shared
priority:
depends_on: []
---

# Goal

Define a fair, readable fake music-stop mechanic for a later iteration of the Simon Says-style dance minigame, increasing tension without making failures feel arbitrary.

# Scope

- Define what players see and hear during a fake stop and how it differs from a real stop.
- Define which player actions during a fake stop count as mistakes.
- Define when the mechanic becomes active and how its frequency changes with difficulty.
- Identify the timing and probability values that must remain designer-tunable.
- Define feedback that helps players understand why they succeeded or lost a life.
- Identify accessibility needs for players who cannot rely on music or a single visual cue.

# Non-Goals

- Adding fake stops to the first gameplay milestone.
- Implementing the mechanic.
- Selecting final timing or probability values without playtesting.
- Redesigning the base pose, lives, elimination, or scoring rules.

# Acceptance Criteria

- Real and fake stop sequences are described from the player's perspective.
- Valid and invalid player responses are unambiguous.
- Required audiovisual cues and accessibility alternatives are documented.
- Designer-tunable timing, frequency, and difficulty controls are identified without prematurely fixing their values.
- Playtest questions define how fairness, readability, anticipation, and frustration will be evaluated.
- Implementation work is split into bounded follow-up tasks only after the human approves the design.

# Game Feel / Player Experience

The fake stop should create playful hesitation and group reactions. It must reward attention rather than guessing, and players should be able to understand the difference between being tricked fairly and receiving an unclear or delayed cue.

# Open Questions

- Does a fake stop briefly silence the music, alter it, or only imitate another stop cue?
- Does the lead dancer continue moving, hesitate, or perform a decoy pose?
- Which early input loses a life, and is any grace or input-cancellation window allowed?
- How often can fake stops occur consecutively?
- Which redundant visual, motion, or haptic cues preserve the mechanic without relying only on audio?

# Notes / Findings

The mechanic was intentionally excluded from [[PS-001 - Define the First Gameplay Milestone]] and reserved for a later iteration.

# Draft Execution Prompt

Read [[PS-008 - Design Fake Music Stops]], [[PS-001 - Define the First Gameplay Milestone]], [[PS-004 - Define the Game-Feel Tuning Strategy]], and the implemented Simon Says minigame when it exists. Facilitate a focused design session with the human project owner, describing the mechanic from the player's perspective and identifying fairness, accessibility, tuning, and playtest needs. Do not implement the mechanic or assign it to a release without human approval.

# Outcome
