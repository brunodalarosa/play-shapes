---
area: Tooling and Verification
tags: [system, stub]
code: [debug/tilt_shift_3d_review.tscn, debug/shape_characters_lab/shape_characters_lab.tscn]
verified:
branch:
---

# Debug Menu

Hub: [[Tooling and Verification]].

The F12 launcher and its scenes.

- `debug/` contains the non-pausing F12 scenario catalog and the debug scenes. The launcher
  remains present in development exports.
- **Flappy Race workshop** opens its workshop; see [[Workshop Window]].
- **Tilt Shift 3D factory · simulated controls** opens `debug/tilt_shift_3d_review.tscn`: ten
  synthetic players tilt through a whole shift, with no phones and no launch eligibility.
- **Shape Characters lab** opens `debug/shape_characters_lab/shape_characters_lab.tscn`. Three
  quarters of the width show a Cubio turned by mouse drag; a tabbed panel picks the model and
  join colour, plays each clip once with pause, restart, stop and speed, and picks any face.
- The lab's Face tab toggles blinking and moves and scales the face. Save writes the placement
  to Cubio's `face_anchor.json`, the game's default, which an export cannot write.
- The motion lab is described in [[Motion Input]].
