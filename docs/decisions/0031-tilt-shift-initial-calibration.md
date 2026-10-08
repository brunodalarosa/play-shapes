# 0031. Tilt Shift waits for initial calibration before a skipped-panel countdown

Decided by the project owner on 2026-10-07.

The normal shared-screen bypass is superseded by
[0032](0032-mandatory-pre-minigame-screen.md). The round calibration safeguard remains.

## Situation

With two or four phones, decision 0030 skips the participant panel and READY. Starting
the countdown immediately gave players only three seconds to grant sensor permission and
calibrate. Active scoring then locked calibration, leaving uncalibrated phones at zero tilt.
The browser fixture masked this by extending the countdown and granting permission quickly.

## Decision

Normal mapped phone sessions keep the first panel and READY hidden, but wait in preparation
until every selected player is connected with fresh calibrated input. The full countdown
starts afterward. This initial calibration wait has no timeout; later rounds reuse neutral.
This replaces immediate skipped-panel countdown in decision 0030 for initial phone setup.

## What follows

- The existing round controller owns the wait and the motion consumer supplies readiness.
  No client decides when scoring starts and no new wire format is needed.
- Permission and CALIBRATE remain available during the wait. A missing or unavailable phone
  holds preparation until recovery or host cancellation. Active recalibration remains locked.
- Panel timeout and local force behavior remain unchanged. Synthetic factory and workshop
  callers keep their original launch behavior without requiring phone capture.
- Browser coverage uses the default countdown and deliberately delays each phone's setup.
  iPhone and Android permission and physical tilt still need owner retesting.
