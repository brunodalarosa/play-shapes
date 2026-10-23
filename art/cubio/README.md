# Cubio source and export

`cubio-animated.blend` is the editable Cubio model and its six animations. Godot and the
phone use the same rigged GLB. Authoring art is excluded from Godot import and release exports.

## Character

- The body is **2 × 2 × 2 m**, with a **0.08 m** bevel and flat main faces.
- Hands are the original **0.60 m** spheres. Feet retain their **0.78 × 0.92 × 0.39 m**
  dimensions. Their meshes, local transforms and animated positions are unchanged.
- The five independent controls remain on `Animation.Controls`. The body and face follow
  `Body.Pivot`; each hand and foot has its own control. Standing height is **2.62 m**.
- The face plane sits 0.015 m in front of the cube. Its neutral and blink artwork is unchanged,
  packed in the blend and editable in `textures/`.

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

Actions have fake users. Looping curves repeat; held poses have constant extrapolation.
The source keeps the original rig and motion. `animation_common.py` defines clip timing
and the names used by the export and verification scripts.

Geometry QA checks the floating parts separately. Ground-height notices for the body,
hands and face are expected; the feet remain on the ground plane.

## Verify and export

Run from this directory with a Blender executable in `$blender`:

```powershell
& $blender --background cubio-animated.blend --python-exit-code 1 --python verify_source.py
& $blender --background cubio-animated.blend --python-exit-code 1 --python export_glb.py
& $blender --background cubio-animated.blend --python-exit-code 1 --python render_review.py
```

`verify_source.py` writes `validation.json`: cube and limb dimensions, packed artwork,
loop seams, held poses, sole contact and surface intersections sampled at quarter frames.
`export_glb.py` temporarily parents rigid meshes to the existing control bones and exports
the six clips. Neither script saves the blend.

The export writes `cubio.glb`, the two face images and source/hash metadata to
`assets/runtime/animated_characters/cubio/model/`. It embeds no materials: `Cubio3D` and
the phone renderer apply the player tint and independent face. The character has
**8,494 triangles**: 108 body, 2 face, 2,976 per hand and 1,216 per foot.

`render_review.py` refreshes the front, three-quarter and motion-pose images in `previews/`.
The motion sheet reads left to right: idle, walk, run, then look up, crouch and lever pull.
These are authoring review images; runtime animation uses the GLB directly.

After exporting, rebuild the phone client and refresh its app icons from the current
three-quarter render:

```powershell
cd ../../web
node scripts/generate_pwa_icons.mjs
npm run build
cd ../art/cubio
```

The live Ready-screen and phone setup previews share the gameplay character. There is no
Animation Lab or sprite-sheet pipeline. Temporary variants and comparisons belong in
ignored `scratch/` or `comparisons/` folders.
