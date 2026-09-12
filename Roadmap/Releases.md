# Releases

A release is a meaningful playable proof, not a sprint. The human project owner decides release scope and whether its completion bar has been met.

## Local Connection Proof

**State:** Active; implementation is merged and physical-phone acceptance is pending.

**What this release proves:** A host can start a local Play Shapes session and an ordinary phone on the same LAN can reach the bundled controller page and establish the initial versioned connection without an Internet-hosted service.

**What should be playable:** This is a connection foundation, not a game. The host displays a join URL/QR code and connection feedback; the phone loads the local Hello world controller and connects to the host.

**Completion conditions:**

- The existing automated, Godot-load, and desktop-browser checks remain recorded in [[DEVELOPMENT]].
- At least one physical phone can scan the QR code or enter the local URL, load the bundled page, and connect on a normal private LAN.
- The controller remains legible and usable in portrait orientation.
- Reload/reconnection behavior is observed and any failure is recorded as follow-up work.
- The validation record distinguishes device/network evidence from automated evidence.

**Included managed tasks:**

- [[PS-002 - Validate Phase 1 on a Physical Phone]]

## Milestone 1 — Simon Says Gameplay Proof

**State:** Scoped and approved; implementation tasks have not been assigned.

**What this release proves:** A group can move from the local lobby through one complete, readable, phone-controlled minigame and return to the lobby, demonstrating the first coherent Play Shapes gameplay loop.

**What should be playable:** A host starts the minigame after 2–10 players join, a tunable countdown transitions to a Simon Says-style dance game, phones provide press-and-hold pose choices across two to four color-and-icon regions, lives and elimination produce a final ranking, and a simple celebratory/moody results scene appears before returning to the lobby. A one-player start is available only through the debug suite.

**Explicit exclusions:**

- Cross-minigame scoreboard and session sequencing.
- Fake music stops, which are deferred to [[PS-008 - Design Fake Music Stops]].
- Final numeric tuning values before playtesting.
- Additional tie-breaking behavior beyond the deliberately limited rules in [[PS-001 - Define the First Gameplay Milestone]].

**Completion evidence:**

- Automated rules and protocol checks.
- Godot editor/runtime validation of the complete scene loop.
- Browser/controller validation, including simulated connections up to 10 players.
- A working one-player debug path that does not alter the normal 2-player minimum.
- At least one full-session LAN check with two physical phones.
- Human playtesting of phone attention, shared-screen readability, cue clarity, fairness, pacing, and results presentation.
- Evidence reported separately by automated, editor/runtime, browser, physical-device/LAN, and human categories.

**Source design:** [[PS-001 - Define the First Gameplay Milestone]]

**Included managed tasks:** None yet. The human project owner will assign implementation and validation tasks separately.
