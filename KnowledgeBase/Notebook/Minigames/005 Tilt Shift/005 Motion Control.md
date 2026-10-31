---
area: Minigames
tags: [system, stub]
code: []
verified:
branch:
---

# 005 Motion Control

Hub: [[005 Tilt Shift]].

`TiltShift3DMotionController.prepare(service, ids, profile)` starts capture and fresh
per-player calibration state. `player_state(id)` exposes `capture_state`, `usable` and
`calibrated` and `landscape`; `ready_for(id)` requires usable capture, completed calibration
and a landscape display orientation. Portrait does not change the physical tilt calculation.

After the actual arena starts, `activate(arena)` verifies its roster. Older single-layout
profiles require every player to be ready before attachment. Mapped profiles allow capture
and calibration inside round preparation. The consumer preserves neutral through the shift,
including intermissions, unless the player deliberately recalibrates before active scoring.
It sends host-owned unwrapped angles through the rules controller; all assigned paddles
receive the same target. The existing physical limiter determines their confirmed poses.

Control uses the direction of world up projected into the physical screen plane. Clockwise
rotation as seen by the holder maps to clockwise rotation on screen. Yaw and display autorotation
alone do not change the phase. Repeated sampled turns accumulate without a rotation stop.
See [[005 Motion Tuning|the tuning guide]].

Complete, fresh orientation is required. Unknown permission may be proven usable by samples;
denied, unavailable, unsupported, insecure, missing and partial orientation remain distinct.
Live acceleration cannot make stale orientation usable. A nearly face-horizontal phone has
an unusable gravity projection: hold the last angle rather than inventing an axis.

Reconnect preserves the original neutral and accumulated branch. The next usable phase
chooses the nearest equivalent angle; it cannot recover unseen full turns. More than 250 ms
between usable samples marks a resumed path. Exactly ambiguous half-turn changes are held.
Reliable unwrapping requires less than 180 degrees between usable samples; real-device
accuracy and comfortable off-axis motion remain pending human trials.

`stop()`, arena stop/exit, shift completion or a replacement capture consumer releases
channels, listeners and calibration. A later preparation starts fresh. The consumer emits
state-change feedback at most five times/s, plus calibration replies limited to five/s;
a new subscription receives fresh feedback. No per-frame angle snapshots are added.
