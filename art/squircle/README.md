# Squircle canonical source

`squircle-animated.blend` is the current editable Squircle v1 model and saved
idle/walk/run, look-up/crouch and lever-pull source. This folder contains current authoring,
export and review resources. Temporary variants and version comparisons belong in ignored
`scratch/` or `comparisons/`; do not commit them.

The shared game assets live in `assets/runtime/animated_characters/squircle/v1/`.
Playground, Bubbles, the F12 Animation Lab and phone setup consume that same set.
Source art is excluded from Godot import by `.gdignore` and from standalone builds
by the existing `art/**` export filter.

## Edit the model and motion

Open the source in Blender 5.2.2. Textures are packed and their current editable
PNG originals are in `textures/`. No add-on or automatic script execution is needed.
The export scripts find the scene, the actions and the face images by name, so a
rename there needs the same change in the scripts:

- Scene: `Squircle Animation Studio`.
- Select `Animation.Controls`; choose `Squircle | Idle`, `Squircle | Walk`,
  `Squircle | Run`, `Squircle | Look Up`, `Squircle | Crouch` or `Squircle | Lever Pull`
  in Dope Sheet > Action Editor.
- Timeline ends: 48, 24, 16 or 9, all at 24 fps. Space plays; Numpad 0 shows the camera.
- Pose Mode edits the five independent body/hand/foot controls. The face follows
  the body. All actions have fake users and linear interpolation. Looping motion has
  cyclic modifiers; key N+1 repeats key 1 and is never exported. Held stances have
  constant extrapolation and no cycles: frames 1–9 enter, frame 9 sustains, and
  reverse playback releases. Feet stay identical to idle frame 1 throughout.

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
| Look up | 1–9 | 1/3 s entry/release, indefinite hold | 0 | Both soles planted |
| Crouch | 1–9 | 1/3 s entry/release, indefinite hold | 0 | Both soles planted |
| Lever pull | 1–24 | 1 s loop | 0 | Both soles planted |

### Lever pull

`Squircle | Lever Pull` moves only `Hand.R`: frame 1 is idle, frame 5 reaches forward
and up, frame 13 pulls down, frame 21 returns up, and frame 25 repeats frame 1.
Only frames 1–24 are exported. Smoothstep-spaced linear keys ease each movement;
cyclic modifiers make the source loop. Body, left hand and feet stay at idle frame 1.

The reached wrist center is (1.68, −0.65, 1.95) m and the pulled center is
(1.68, −0.65, 1.10) m. Edit `Hand.R` in Pose Mode to tune travel and keep frame 25
identical to frame 1. Scene properties prefixed `Lever` record timing and travel.
The manifest exposes `lever_pull` as ordinary looping playback in both existing
views. F12 > Animation Lab > Action > Lever Pull plays it with tint and natural blinking.
Station contact and game-state binding are separate from this standalone gesture.

### Held-pose tuning and playback

Frame 1 of each stance matches idle frame 1. Nine samples cover eight intervals
at 24 fps; smoothstep spacing eases entry and reverse release. Edit the `Body`,
`Hand.L` and `Hand.R` pose bones in the new actions. Scene custom properties
prefixed `Stance` describe the current values and timing; they are notes, not drivers.
`animation_common.py` defines the exported frame counts, FPS and `playback: held`.
Keep action range, frame count and timing in agreement after edits.

- Look up: body X rotation −10°; wrist centers (±1.43, −0.12, 2.83) m.
- Crouch: body Z offset −0.16 m; wrist centers (±1.38, −0.06, 1.30) m.
  The depth retains a floating gap above the original feet without resizing the body.
- Both keep the original mesh, spherical hands, materials and fixed 4.5 camera scale.

In the game, `SquircleV1Playback` plays these stances:

- `play("look_up", view)` and `play("crouch", view)` enter and hold the final frame.
  Repeated requests do not restart entry.
- Request `idle` to reverse from current progress. Selecting another action first
  releases to neutral, then enters it.
- Re-requesting the current stance during release reverses direction without jumping.
- `advance_playback(delta)` supports paused and slow review.
  `seek_clip(action, view, milliseconds)` supports deterministic frame inspection.
- The external absolute clock remains available for looping locomotion.
- Tint and face/blink controls remain independent.

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
source hash and complete action/view frame sequences, then copies the 36 current
runtime sheets and writes the runtime manifest and `runtime-sync.json`.
Packing and synchronization replace generated images atomically, so a failed
write leaves the previous asset intact and Windows preview readers can stay open.

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
expressions and 256/128 pixel references plus the actual 0.58 lobby scale. Its
action list comes from the manifest and it uses shared game playback. Select a
stance, pause or slow it, release to idle, re-enter, or switch to the other stance
during entry/hold/release. Natural blinking remains active while a pose is held.

## Review the current design

Serve this folder with `python -m http.server 8057 --bind 127.0.0.1`, then open
`http://127.0.0.1:8057/review.html`. The review supports palette, expression, size,
pause, time, slow motion and ground-contact controls. Held poses show entry,
hold through review tick 36, reverse release, then neutral in each 48-tick review.
Useful current outputs are
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

Lever Pull additionally exports each right wrist's projected `hand_center_px` in the
same tile coordinates. Runtime clips publish the ordered `hand_centers_px` array.
Factory operators use these points for cosmetic grip contact while seeking existing
frames; this metadata adds no new render or alternate character library.

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
