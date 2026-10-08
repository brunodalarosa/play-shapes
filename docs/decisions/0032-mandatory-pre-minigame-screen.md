# 0032. Every normal minigame starts at the shared Pre-minigame screen

Decided by the project owner on 2026-10-08.

## Situation

Tilt Shift's mapped rounds introduced selected-player readiness inside gameplay. Its
normal launch bypassed the shared preparation screen, conflating round preparation with
the initial screen required by the minigame player journey.

## Decision

Every normal minigame launch shows the shared Pre-minigame screen before gameplay.
Debug flows remain exceptions. Round readiness supplements the initial all-player READY
gate. No skip setting exists; adding one would require a separate owner decision.

This replaces the normal shared-screen bypass described in decisions
[0030](0030-tilt-shift-round-preparation.md) and
[0031](0031-tilt-shift-initial-calibration.md). Their round-controller ownership,
calibration protection and participant-panel rules remain.

## What follows

- Tilt Shift carries calibration from shared preparation into its mapped rounds. Every
  phone needs fresh usable calibrated input and landscape orientation before READY.
- Losing landscape eligibility while waiting clears READY. This does not change physical
  tilt interpretation, scoring or an already-started countdown.
- Plans that bypass the screen in normal play must flag the conflict conspicuously.
  [Player journeys](../player-journeys.md) defines the warning and design-reading guidance.
