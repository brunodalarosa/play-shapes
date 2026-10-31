---
area: Minigames
tags: [system, stub]
code: [minigames/005_3d_tilt_shift, TiltShift3DMotionController, TiltShift3DTiltInput, MinigameProtocol, debug/tilt_shift_3d_review.tscn]
verified:
branch:
---

# 005 Code Map

Hub: [[005 Tilt Shift]].

Where minigame 005 lives in the code.

Minigame 005 is Tilt Shift in 3D, in `minigames/005_3d_tilt_shift/`.
[Its README](../../../../minigames/005_3d_tilt_shift/README.md) lists what each script owns, and its
selected Resources are in the [field guide](../../../../minigames/005_3d_tilt_shift/tuning/README.md).

- `tilt_shift_3d_shift_controller.gd` owns equal teams, frozen shift content, layout exposure
  history, participant selection, readiness, countdown, round deadlines, cumulative scores,
  ball resolution, assignments and held angles. The allocator returns inspectable neighbor and
  conflict diagnostics.
- The arena simulates on Jolt with plane-locked bodies, as 004 does, and fills the frame with
  the floor raised for the bins ([[0038-tilt-shift-3d-full-width-frame|decision 0038]]).
- Paddles are rounded bars built in code with a matching convex collider
  ([[0036-tilt-shift-3d-generated-paddle|decision 0036]]), each with a composed face
  ([[0037-shape-face-system|decision 0037]]).
- `TiltShift3DMotionController` owns capture preparation, calibration and active-consumer
  lifecycle; each `TiltShift3DTiltInput` holds one player's neutral and continuous input. See
  [[005 Motion Control|motion input]].
- `tilt_shift_3d_session.gd` is the catalog's session script; `tilt_shift_3d_protocol.gd` is a
  `MinigameProtocol`. The messages are in [[005 Messages]].
- `addons/tilt_shift_3d_workshop/` is its editor workshop
  ([workshop guide](../../../../minigames/005_3d_tilt_shift/tuning/WORKSHOP.md)), and
  `debug/tilt_shift_3d_review.tscn` is its simulated F12 review. See
  [[Journey Change Rules|player journeys]].
