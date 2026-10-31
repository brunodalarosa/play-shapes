---
area: Minigames
tags: [system, stub]
code: [TiltShift3DSession]
verified:
branch:
---

# 005 Preparation Lifecycle

Hub: [[005 Tilt Shift]].

The normal catalog flow uses `TiltShift3DSession` to keep the same motion consumer across
the shared all-player Pre-minigame screen to factory transition. Final joins from existing onboarding sockets
receive new isolated channels without resetting earlier players. Expired preparation
participants lose their channels. READY is revoked when capture becomes stale, unusable or portrait.

Mapped-round resume clears readiness and keeps neutral and ownership. Calibration is
allowed before/between active rounds and clears READY. Active play locks calibration.

After the shared screen, when the first round skips its participant panel and READY, the phone session waits
in preparation until every selected player is connected with fresh calibrated input. This
initial calibration wait has no timeout; permission and CALIBRATE remain available until
the complete countdown starts. Later rounds reuse calibration and retain their panel rules.

Older shared-gate preparation retains its original neutral-reset policy.
Host cancel, scene startup failure, results, debug replacement and return to the lobby retire
the prepared consumer. The F12 factory review is explicitly simulated and creates no motion
subscriptions. See [flow tuning](../../../../minigames/005_3d_tilt_shift/tuning/FLOW.md).
