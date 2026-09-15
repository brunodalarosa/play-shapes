---
id: PS-001
title: Define the first gameplay milestone
type: design
status: done
release: Milestone 1
owner: shared
priority:
depends_on: []
---

# Goal

Define the smallest meaningful gameplay milestone after the local connection proof so the project can prioritize one coherent player experience instead of accumulating disconnected systems.

# Scope

- State what the milestone is intended to prove about Play Shapes.
- Describe the smallest complete player journey from host launch through the end of a round or session.
- Identify the intended player-count range, host controls, phone controls, shared-screen behavior, and a candidate minigame or gameplay slice.
- Identify which uncertainties require separate exploration or design tasks.
- Propose completion evidence without assigning tasks to the release until the human approves the scope.

# Non-Goals

- Designing every future minigame.
- Selecting a long-term release roadmap.
- Implementing the cross-minigame scoreboard or a multi-minigame session sequence.
- Implementing fake music stops; that later mechanic is defined separately in [[PS-008 - Design Fake Music Stops]].
- Committing to networking, art, audio, or gameplay architecture before relevant investigation.
- Implementing the milestone.

# Acceptance Criteria

- A concise milestone statement says what should be playable and what the release is meant to prove.
- The end-to-end player journey and minimum viable scope are documented.
- Explicit non-goals prevent the milestone from becoming a vertical slice of the entire product.
- Important design, technical, content, and validation unknowns are listed.
- The human project owner approves or revises the proposed milestone before tasks are assigned to it.

# Game Feel / Player Experience

Document the intended emotional tone, round pace, control simplicity, readability from the shared display, phone attention demands, feedback priorities, and the feel questions that require experiments. Do not select numeric tuning values yet.

# Open Questions

- Whether shared-screen player characters visibly mirror held poses before the music stops.
- How a remaining-lives tie that crosses the top/bottom cutoff is displayed when the all-perfect ID fallback does not apply. The human deliberately deferred this edge case to prevent scope creep; do not expand Milestone 1 to resolve it without renewed direction.
- How long results remain visible and whether returning to the lobby is automatic or host-controlled.
- Which accessibility alternatives accompany directional pose recognition, press-and-hold input, and music-stop cues.
- Which round length, countdown, grace period, music-stop range, and progression values feel best in playtesting.
- Which specific art, animation, music, and sound assets communicate the approved experience within the milestone's production scope.

# Notes / Findings

## Proposed milestone statement

The first gameplay milestone proves that a group of 2–10 players can join a local Play Shapes lobby, be taken by the host into one complete Simon Says-style dance minigame using their phones, and return to the lobby when the round ends. A one-player debug path supports development, but normal play requires at least two players. The milestone proves one coherent local multiplayer loop; it does not yet prove cross-minigame sequencing or scoring.

## Confirmed player journey

1. The host launches Play Shapes and players join the lobby on their phones.
2. Once at least two players have joined, the host can manually press **Start minigame**. In debug mode only, one joined player is sufficient.
3. A designer-tunable countdown of X seconds begins on the shared screen.
4. At zero, the shared display transitions from the lobby to the Simon Says minigame scene.
5. Players complete the minigame using phone press-and-hold pose controls.
6. When only one player remains or the round timer expires, the minigame ends.
7. A simple results scene places the top half of the minigame ranking in the upper portion of the shared screen against a happy celebration background. The bottom half appears below against a sad, moody background.
8. After the results, the game returns to the lobby. No scoreboard or cross-minigame progression is shown in this milestone.

## Confirmed candidate minigame

The canonical minigame design is [[001 - Dancer simon says]]. The first gameplay milestone will be scoped around this Simon Says-style dance minigame:

- A playful lead dancer appears in the center of the shared screen, with each player's character arranged along the bottom.
- While music plays, all characters dance automatically.
- When the music stops, the lead dancer assumes a directional pose. Each player must copy it by pressing and holding the corresponding area of their phone screen.
- Early difficulty uses two poses and progresses to a maximum of four poses during the minigame.
- The phone's active touch area is presented as a square divided into distinct pose regions. Every region has its own color and icon so choices are not communicated by color alone.
- Music stops after a randomly selected interval. Difficulty shortens the interval through a designer-tunable range whose values will be discovered through playtesting rather than fixed in this design task.
- A wrong pose, no pose, or changing pose after the stop costs one life. A short designer-tunable grace period softens the pose-lock timing.
- Each player starts with two lives and is eliminated from the minigame round after losing both.
- Normal milestone play supports a minimum of 2 and a maximum of 10 simultaneous players.
- A one-player mode is required for development and belongs to the project's debug suite rather than the normal multiplayer experience; its behavior will be defined in [[PS-007 - Define the Gameplay Debug Suite]].
- The minigame round ends when only one player remains or when the round timer expires.

## Confirmed session and scoring model

- A Play Shapes gameplay session consists of multiple minigames played in sequence.
- A session scoreboard tracks player ranking across those minigames.
- Each minigame produces a ranking based on elimination order: earlier elimination means a lower placement, while the last remaining player earns the highest placement.
- If the timer expires with multiple players still active, players with more remaining lives rank higher. Among players who lost lives, the player who lost a life earlier ranks lower than one who lost it later.
- No additional competitive tie-breaking system belongs in Milestone 1.
- If every player reaches the timer with both lives intact, the game sorts players by their stable IDs to divide them deterministically between the top and bottom result groups. This fallback is intentionally simple and is not presented as a skill-based ranking.
- The top half of the minigame ranking earns scoreboard points and the bottom half earns zero points.
- When the player count is odd, the top group contains the smaller half and the bottom group contains the extra player. The top group size is therefore the player count divided by two and rounded down.
- Exact point values and distribution within the scoring half have not yet been selected.
- This broader session model is future context only. The first gameplay milestone contains only the Simon Says-style minigame and does not implement the scoreboard.

## Intended experience

- The phone action should remain simple enough to perform with a press-and-hold gesture while players keep most of their attention on the shared display.
- The central dancer's pose and each player's response must be readable at a glance.
- Random music stops, faster pacing, and additional poses should build playful tension without making failures feel arbitrary.
- The grace period is a player-feel control and must remain easy for the human designer to tune during playtesting; no numeric value has been selected.
- The random music-stop range is also a player-feel control. Its bounds and difficulty progression must be easy for the human designer to change and compare without editing gameplay logic.
- Phone pose targets pair color with a distinct icon to improve recognition and avoid color-only communication.
- Results feedback should be immediately readable and emotionally playful: celebratory for the upper group and disappointed or moody for the lower group, without showing scoreboard points.

## Proposed milestone completion evidence

- Automated checks cover authoritative pose evaluation, lives and elimination, round-ending conditions, the intentionally limited ranking rules, and rejection of invalid or late controller input.
- Godot editor/runtime checks show the lobby, countdown, minigame, results, and return-to-lobby sequence without script or scene errors.
- Browser and protocol checks exercise the controller layout and state changes, including simulated coverage up to 10 connected players.
- The one-player debug path can start and complete the minigame without changing the normal 2-player minimum.
- At least two physical phones complete the full LAN journey together; broader device evidence remains distinct and follows [[PS-005 - Define Multi-Phone and Agent Validation Strategy]].
- Human playtesting evaluates shared-screen readability, one-thumb phone interaction, clarity of correct and failed poses, perceived fairness, pacing, and the emotional readability of the two-tier results scene.
- Evidence explicitly records which checks were automated, editor/runtime, desktop-browser, physical-device/LAN, and human judgments.


# Draft Execution Prompt

Read [[PS-001 - Define the First Gameplay Milestone]], [[Project Overview]], [[Workflow]], [[Releases]], [[Decision Log]], and the relevant human draft notes. Facilitate a focused planning session with the human project owner. Seek clarity about the smallest complete player experience, ask feature-specific questions, preserve open uncertainty, and propose a concise milestone with non-goals and validation needs. Do not implement anything, assign priority, or add tasks to a release without human approval.

# Outcome

Approved by the human project owner on 2026-09-12. Milestone 1 is the single-minigame Simon Says Gameplay Proof described above. The scoreboard, multi-minigame sequencing, and fake music stops are outside its scope. Remaining questions are deliberately preserved as implementation or playtest details; no implementation tasks have been assigned to the release yet.
