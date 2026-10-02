# Squircle canonical source

`squircle-animated.blend` is the current editable Squircle v1 model and saved
idle/walk/run source. This folder contains current authoring, export and review
resources. Temporary variants and version comparisons belong in ignored
`scratch/` or `comparisons/`; do not commit them.

The shared game assets live in `assets/runtime/animated_characters/squircle/v1/`.
Playground, Bubbles, the F12 Animation Lab and phone setup consume that same set.
Source art is excluded from Godot import by `.gdignore` and from standalone builds
by the existing `art/**` export filter.

## Edit the model and motion

Open the source in Blender 5.2.2. Textures are packed and their current editable
PNG originals are in `textures/`. No add-on or automatic script execution is needed.
The saved scene and action identifiers retain their established names so the
existing rig/export contract stays stable:

- Scene: `PS057 | Squircle Animation Studio`.
- Select `Animation.Controls`; choose `PS057 | Idle`, `PS057 | Walk` or
  `PS057 | Run` in Dope Sheet > Action Editor.
- Timeline ends: 48, 24 or 16, all at 24 fps. Space plays; Numpad 0 shows the camera.
- Pose Mode edits the five independent body/hand/foot controls. The face follows
  the body. Actions have fake users, linear interpolation and cyclic modifiers.
  Key N+1 repeats key 1 and is never exported.

Both hands are smooth UV spheres, 48 segments by 32 rings, centered on their wrist
pivots. Their diameter is **0.60 m**, compared with **2.00 m body width** and
**0.92 m foot length**: **30%** and **65.22%**, respectively. The hands are roughly
34 pixels across in the 256-pixel front render, or 17 pixels at 128.

To resize, select each Hand mesh separately in Edit Mode, select all vertices and
scale uniformly around Median Point by `desired_diameter / current_diameter`.
Apply the same factor to both hands. Keep object scale at one and update the scene
property `Hand diameter m`. Save and regenerate the complete export below.

| Clip | Frames | Duration | Forward travel | Contact |
|---|---:|---:|---:|---|
| Idle | 1–48 | 2 s | 0 | Both soles planted |
| Walk | 1–24 | 1 s | 1.65 m/s | 62.5% stance per foot |
| Run | 1–16 | 2/3 s | 3.60 m/s | 37.5% stance, flight and opposing hand swing |

## Export and synchronize

Run from this folder, using Blender and Python with Pillow/NumPy:

```powershell
& $blender --background squircle-animated.blend --python-exit-code 1 --python export_frames.py
& $python make_previews.py
& $blender --background squircle-animated.blend --python-exit-code 1 --python render_hand_detail.py
& $blender --background squircle-animated.blend --python-exit-code 1 --python validate_animation.py
& $python sync_runtime.py
```

`export/` holds the raw colorable/mask sequences, expressions and frame manifest.
`make_previews.py` packs sheets, independent neutral/blink faces, motion loops,
palette and layer reviews, and `review-data.js`. `sync_runtime.py` checks the saved
source hash and complete six-clip frame sequence, then copies the 18 current
runtime sheets and writes the runtime manifest and `runtime-sync.json`.

For an independent reproducibility check:

```powershell
& $blender --background squircle-animated.blend --python-exit-code 1 --python export_frames.py -- --output recheck
& $python verify_export.py
```

`recheck/` is temporary and ignored; remove it after verification. Partial exports
also require a separate output directory, for example
`--output probe --clips run --views three-quarter --frames 1 5 9 13`.

From the implementation root, refresh icons after artwork changes and reimport:

```powershell
node web/scripts/generate_pwa_icons.mjs
godot --headless --editor --path . --import
godot --headless --path . --script tests/squircle_animation_lab_test.gd
godot --path .
```

Phones receive the same canonical idle-front sheets through the host HTTP routes.
There is no extra phone animation copy. F12 > Animation Lab reviews clips, colors,
expressions and both sizes.

## Review the current design

Serve this folder with `python -m http.server 8057 --bind 127.0.0.1`, then open
`http://127.0.0.1:8057/review.html`. The review supports palette, expression, size,
pause, time, slow motion and ground-contact controls. Useful current outputs are
`previews/motion-review-{256,128}.gif`, `review-sheet.png`, `palette-and-blink.png`,
`hand-detail-sphere.png` and `occlusion-proof.png`.

## Render contract and verification

Cycles, 48 samples, denoising, AgX, seed 57, straight-alpha transparent RGBA PNG,
256×256 untrimmed tiles; face visibility masks use 16 samples without denoising.
OPTIX is selected when available, otherwise CPU. No preferences are saved.
Fixed orthographic scale is 4.5: front 0° yaw/0° elevation; three-quarter 35°/9°.
Framing does not change by action, pose, layer or player color.

The source manifest records order, time, camera, projected face corners, sole
positions/stance and ground anchor. Anchors at 256 are front (128, 204.231186) and
three-quarter (128, 203.292557). Forward is -Y; root travel is
`-speed × elapsed_seconds` along Y. The optional shadow catcher is disabled;
game scenes supply ground shadows. Sheets have eight columns in row-major order;
blank trailing cells are never animation frames.

Colorable layers include body, hands, feet, shading and self-occlusion with the face
hidden. Display-space blue-basis tint preserves highlights across all five parts.
Neutral/blink are independent untinted face layers. Projected face corners give
their affine transform; rendered mask alpha clips body/hand occlusion. Mask RGB is
white. Tint is a stylized RGB transfer, not a physical rerender of each palette color.

`validation.json` checks spherical geometry, loop seams, sole contact/travel,
floating foot/body gaps, camera bounds and hand/body/floor/foot clearance at
quarter-frame intervals. Foot clearance uses conservative world AABBs.
`export-verification.json` checks independent replay metadata, ordering, packed
tiles, alpha margins and consumed-channel tolerance ≤1/255. These reports establish
desktop technical evidence; physical-phone and owner game-feel review are separate.
