---
area: Playground Lobby
tags: [system, stub]
code: [characters/character_selection.gd, web/src/character_selection.ts, characters/cubio_3d.tscn, ShapeFace3D, assets/runtime/animated_characters/cubio/face_anchor.json, ShapeFaceExpressions, characters/cubio_preview.gd, art/cubio/cubio-animated.blend]
verified:
branch:
---

# Cubio Runtime

Hub: [[Playground Lobby]].

Cubio, the one player character, as the host and the phone run it.


- `characters/character_selection.gd` normalizes missing and legacy shapes to Cubio while
  preserving selected colors. `web/src/character_selection.ts` offers colors and sends
  `cubio`.
- `characters/cubio_3d.tscn` is the real-time Cubio used by the Playground lobby: the
  exported rig and clips, the player tint, a shape face, held stances, turning toward
  travel and a nameplate.
  - The face is a `ShapeFace3D` on the model's `FaceAnchor`, placed by
    `assets/runtime/animated_characters/cubio/face_anchor.json` and driven by a
    `ShapeFaceExpressions` that shows `face_slightly_smiling` and blinks.
  - Its tint shader and the face's parts draw the character in front of any
    scenery within `front_push` (2 units) of it. Each vertex moves toward the camera along
    its view ray, so its place on screen and the character's own layering are unchanged.
    Shadow passes are left alone. Nothing in the plaza may stand in front of a character
    within that distance.
- `characters/cubio_preview.gd` renders a Ready-screen row of live Cubio instances in one
  isolated 3D viewport. Readiness and color updates reuse existing instances.
- The canonical model and six actions are in `art/cubio/cubio-animated.blend`. The body is
  a two-metre cube with a small bevel; the floating limbs and rig retain their transforms.
- `art/cubio/export_glb.py` exports the model and two face textures to
  `assets/runtime/animated_characters/cubio/model/`. Both host and phone consume that model.
  See the [[Cubio Source and Export|source workflow]].

## Loops and held stances

- Runtime clip metadata distinguishes `playback: loop` (idle, walk, run, lever pull) from
  `playback: held` (look_up, crouch).
- `Cubio3D.play(action)` enters a held stance once and sustains its final
  frame.
- Another request reverses current progress to the shared idle neutral before entering the
  latest requested action.
- Re-pressing the current stance cancels the release without restarting.
- Stances keep the feet and ground anchor fixed, with independent color and face or blink
  layers.
- The shared host motor chooses these stances only while grounded. Crouch retains the full
  upright collider and the same floor anchor.
