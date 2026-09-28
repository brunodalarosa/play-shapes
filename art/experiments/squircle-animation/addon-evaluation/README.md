# PS-057 Add-on Evaluation: Sprite Sheet Generator

**Decision: skip as the PS-057 exporter.** The add-on can detect and render an action after an armature is present, but its cardinal view controls cannot express the required 35° yaw / 9° elevation directly, its dynamic-bounds calculation misses the model's nested mesh parts, and its JSON omits the camera, timing, anchor, and layer contract. The approved PS-056 static source used in this trial had no armature; the current PS-057 asset now has a five-control armature and independent actions, but the add-on was not rerun against that animated file. Its one-frame sheet run did work at the existing three-quarter camera when dynamic sizing was disabled. A Blender-native exporter can preserve the current editable pivots and write the exact camera and layer metadata without importing the add-on's armature constraint.

This was a bounded compatibility trial, not animation-quality validation: the generated action only rotated a temporary armature wrapper. The approved PS-056 model and source file remain untouched; `squircle-addon-test.blend` is an evaluation copy with test-only edits.

## Pinned source

- Upstream: [GameSomeStudio/sprite-sheet-generator](https://github.com/GameSomeStudio/sprite-sheet-generator)
- Commit checked: [`1271e915abc28a2e5c3851a63d5913080b0f6825`](https://github.com/GameSomeStudio/sprite-sheet-generator/commit/1271e915abc28a2e5c3851a63d5913080b0f6825), latest `main` commit observed during this evaluation (2026-09-25).
- Source file: [`sprite_sheet_generator_V2.py`](https://github.com/GameSomeStudio/sprite-sheet-generator/blob/1271e915abc28a2e5c3851a63d5913080b0f6825/sprite_sheet_generator_V2.py), copied to this folder for the background test; SHA-256 `ACF25C39C555A289F348916D806852B157DDEF7143D8DCCFCC01A1DA9EF1A416`.
- Upstream declares GPL-3.0-or-later; the matching text is retained as `LICENSE-upstream-GPL-3.0`. The copy is not installed in Blender's user add-ons. If this test source remains in a distributed project, keep its license and attribution with it.
- README: [features and requirements](https://github.com/GameSomeStudio/sprite-sheet-generator/blob/1271e915abc28a2e5c3851a63d5913080b0f6825/README.md).

The latest `main` commit updates the README; the source file's latest preceding change is commit `1b2a954485a50ee2d4071d28c3eda40d2b53805d`, which says it fixes Blender 5.x action detection. The evaluated file came from the pinned `1271e91` tree, so its exact bytes are identified by the hash above.

## Test and findings

The copied model opened as `PS056 | Squircle Toy Studio`, with `Camera.ThreeQuarter` active. At the time of this add-on test, the approved PS-056 static baseline had no armature. The current PS-057 animation file now has `Animation.Controls` with five rigid control bones and independent actions; this test used a temporary wrapper/action on the static copy and did not test the new authored rig. In both arrangements, the body, face plane, two hands, and two feet remain separate mesh objects nested beneath `Character.Root - ground anchor` through pivot empties.

Selecting the original root (`EMPTY`) and running action detection returned `CANCELLED` with the add-on's armature-required message. In the copy only, I added an armature wrapper around the existing root and a short armature-object action named `addon_compat_idle`. Detection returned `FINISHED` and found that action. The generator then returned `FINISHED` and produced a 128×128 RGBA one-cell sheet plus JSON at 8 Cycles samples. This proves a rigid wrapper/action compatibility path; it does not show independent hand/body/foot animation through bones.

The output used the existing fixed `Camera.ThreeQuarter` (35° yaw, 9° elevation) and the add-on's 0° selection. Thus that saved camera can supply the required view, but the add-on's own selector has only 0°, 90°, 180°, and 270°. It rotates the armature, not the camera, and has no custom 35°/9° view field. The output is one row labelled `compat_idle_threequarter_front`; that label is misleading unless a custom camera/view naming layer is added.

The source's dynamic-size bounds routine checks only direct mesh children of the selected armature. In the compatibility copy, the armature's direct child is an `EMPTY`, and the six meshes remain nested below it; the routine returned its fallback `[-1, -1, 1, 1]` box. In the current PS-057 rig, the controls armature is a child of the character root and does not directly own those meshes, so this limitation still applies. Turning it off retains the fixed 128×128 frame and made the tiny sheet run complete.

The generated JSON is useful for basic packing: sprite sheet name, columns, rows, maximum cell width/height, animation row/name, frame count, and per-animation cell width/height. It has no FPS or frame timing, camera pose/angle/elevation, pixel anchor/ground contact, alpha policy, layer names, tint palette, or expression identifier. The code has no body/face/hand/foot render-layer controls. The PS-056 model keeps the face on a distinct plane/material and the colorable body/hand/foot meshes share one material, but the add-on renders the whole scene together. Separate face expression swaps and player tint reconstruction would still need an external layer render/export step.

The direct reference and one-cell add-on outputs both retained the same alpha coverage (4,252 pixels above 0.05). Internal loaded-pixel center colors matched within about 0.00002 per channel; the mean absolute RGB difference across mutually opaque pixels was 0.0278. The add-on does not record color-management state in metadata, so matching color should be rechecked in any future exporter comparison. See `color-comparison.json`.

## Reproduce

From PowerShell, rerun the bounded comparison with Blender 5.2.2:

```powershell
$folder = 'C:\Users\backup pc\Documents\Codex\Play Shapes\play-shapes\art\experiments\squircle-animation\addon-evaluation'
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background (Join-Path $folder 'squircle-addon-test.blend') --python (Join-Path $folder 'run_addon_test.py') *> (Join-Path $folder 'addon-test.log')
```

The run used 128×128, 8 Cycles samples, a single sampled frame, and only the add-on's 0° view. It completed successfully. Blender logged a restricted-profile warning that it could not read the user preferences file; the script does not depend on those preferences. It also logged the expected raw-model armature rejection before the wrapped copy test.

## Evidence files

- `squircle-addon-test.blend` — actual approved model copied before test-only armature/action creation.
- `sprite_sheet_generator_V2.py`, `LICENSE-upstream-GPL-3.0` — pinned upstream source copy and its license.
- `run_addon_test.py`, `addon-test.log`, `diagnostics.json` — procedure and result.
- `reference-threequarter-35x9-128.png` — direct Blender render of the copied scene.
- `addon-sheet-threequarter-35x9-128.png`, `addon-sheet-threequarter-35x9-128_metadata.json` — actual add-on operator output.
- `color-comparison.json` — alpha coverage and sampled pixel difference from Blender's image buffers.

This trial gives no approval of idle/walk/run feel, tint layer compositing, or the eventual in-game sprite size.
