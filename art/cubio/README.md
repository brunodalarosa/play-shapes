# Cubio source and export

`cubio-animated.blend` is the editable Cubio model and its nine animations. Godot and the
phone use the same rigged GLB. Authoring art is excluded from Godot import and release exports.

## Character

- The body is **2 × 2 × 2 m**, with a **0.08 m** bevel and flat main faces.
- Hands are the original **0.60 m** spheres. Feet retain their **0.78 × 0.92 × 0.39 m**
  dimensions. Their meshes and local transforms are unchanged; the six original clips keep
  their animated positions.
- The five independent controls remain on `Animation.Controls`. The body and face anchor
  follow `Body.Pivot`; each hand and foot has its own control. Standing height is **2.62 m**.
- The model has no face of its own. `Face.Anchor`, an unrotated empty 0.015 m in front of the
  cube's centre, marks where Godot and the phone draw the shared shape face. Its −Y points out
  of the front, which is +Z once exported Y up. The face's offset from it and its height are in
  `assets/runtime/animated_characters/cubio/face_anchor.json`.

## Edit the motion

Open the blend in Blender 5.2.2 or newer. The scene is `Cubio Animation Studio`.
Select `Animation.Controls` and choose an action in the Action Editor; Pose Mode edits
the independent body, hand and foot controls. No startup script or add-on is needed.

| Action | Frames at 24 fps | Playback |
| --- | ---: | --- |
| Cubio \| Idle | 48 | Loop |
| Cubio \| Walk | 24 | Loop, 1.65 m/s forward travel |
| Cubio \| Run | 16 | Loop, 3.60 m/s forward travel |
| Cubio \| Look Up | 9 | Enter, hold, reverse to release |
| Cubio \| Crouch | 9 | Enter, hold, reverse to release |
| Cubio \| Lever Pull | 24 | Right-hand loop; other parts stay at neutral |
| Cubio \| Flap | 7 | One wing beat, then hold; downstroke reaches frame 3 |
| Cubio \| Hit | 17 | One tumble about the body centre, then hold |
| Cubio \| Respawn | 13 | Squash, pop and settle, then hold |

Actions have fake users. Looping curves repeat; held poses have constant extrapolation.
The six original actions retain their motion. `animation_common.py` defines clip timing
and the names used by the export and verification scripts.

The flight clips use the existing floating hands as wings. They animate in place around
the body centre; the race owns travel and tilt. Host `Cubio3D.play_once` and phone
`playOnce` restart a gesture immediately and hold its last pose. Flaps during Respawn leave
the pop intact; Hit can interrupt it. Hit playback fits the race's tumble duration.

Geometry QA checks the floating parts separately. Ground-height notices for the body and
hands are expected; the feet remain on the ground plane.

## Verify and export

Run from this directory with a Blender executable in `$blender`:

```powershell
& $blender --background cubio-animated.blend --python-exit-code 1 --python verify_source.py
& $blender --background cubio-animated.blend --python-exit-code 1 --python export_glb.py
& $blender --background cubio-animated.blend --python-exit-code 1 --python render_review.py
```

`verify_source.py` writes `validation.json`: cube and limb dimensions, the face anchor,
loop seams, held poses, grounded-clip sole contact and quarter-frame surface intersections.
It also checks the fast downstroke, the tumble centre and the respawn squash and stretch.
`export_glb.py` temporarily parents rigid meshes and the face anchor to the existing control
bones and exports all nine clips. Neither script saves the blend.

The export writes `cubio.glb` and source/hash metadata to
`assets/runtime/animated_characters/cubio/model/`. It embeds no materials: `Cubio3D` and
the phone renderer apply the player tint and draw the shape face. The character has
**8,492 triangles**: 108 body, 2,976 per hand and 1,216 per foot.

`render_review.py` refreshes the front, three-quarter and motion-pose images in `previews/`.
Blender has no shape face, so a fresh render shows a blank front; the committed previews were
rendered with the former painted face.
The motion sheet reads left to right: idle, walk, run; look up, crouch, lever pull; flap,
hit, respawn.
These are authoring review images; runtime animation uses the GLB directly.

The Shape Characters lab lists every exported clip. Capture four poses per clip, with the
runtime face, using `tests/cubio_clips_visual_check.gd` as described in
[verification](../../docs/verification.md#render-helpers). Its output is under
`test-results/cubio/clips/`; `-- --output=res://test-results/cubio/before` chooses another folder.

After exporting, rebuild the phone client. Refresh app icons only when the character's
appearance changes, from the current three-quarter render:

```powershell
cd ../../web
npm run build
cd ../art/cubio
```

The icon refresh command, from `web/`, is `node scripts/generate_pwa_icons.mjs`.

The live Ready-screen and phone setup previews share the gameplay character. Temporary
variants and comparisons belong in ignored `scratch/` or `comparisons/` folders.
