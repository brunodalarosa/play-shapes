# Squircle toy study — PS-056

**Awaiting owner visual approval.** This is an editable art experiment, not the
approved animation source for PS-057. No production Godot assets are replaced.

Open `squircle-toy.blend` in Blender 5.2. The active scene is
`PS056 | Squircle Toy Studio`. All textures are packed and also provided under
`textures/`; no add-on, MCP connection, or script execution is needed to use it.
The untouched startup scene is retained separately as `Scene`.

## Inspect and experiment safely

1. Use **File > Save As** to make a personal copy before changing the model.
2. The file opens in the three-quarter camera with the body selected. Drag the
   middle mouse button to orbit; use the mouse wheel to zoom. Numpad 0 returns
   to the active camera. **Render > Render Image** (F12) shows the studio render;
   **Render > View Render** (F11) returns to/from the render window.
3. To switch views, select `Camera.Front` or `Camera.ThreeQuarter` in the Outliner,
   put the pointer over the viewport, and use **View > Cameras > Set Active Object
   as Camera** (Ctrl+Numpad 0). Render again with F12.
4. Undo experiments with Ctrl+Z, or reopen your saved copy. The supplied PNGs
   remain the recorded baseline and do not change when you adjust the scene.

## Change softness, gloss, color, and lighting

| What | Exact Blender control | Baseline / useful experiment |
| --- | --- | --- |
| Body roundness | Select `Body.Squircle` > Object Data Properties (green triangle) > Shape Keys > `Softness - rounder silhouette` > **Value** | `0.30`; try 0.0 for firmer corners, 0.65 for softer, 1.0 for nearly round. Depth stays fixed so the face remains in front. |
| Rubber vs plastic | Select body > Material Properties > Surface > Principled BSDF > **Roughness** | `0.32`; try 0.50 for rubber or 0.18 for shiny plastic. Shared by body, both hands, and both feet. |
| Surface gloss | Same material > **Coat > Weight / Roughness** | `0.18 / 0.24`; Weight 0 removes the clear coat. Metallic stays 0. |
| Player color | Same material > **Base Color** > Hex | Baseline `#1E88E5`. Change this shared material to recolor all five parts together. See palette below. |
| Main illumination | Select `Light.Key - large softbox` > Light Data Properties (bulb) > **Power / Size** | `450 W / 4 m`; larger size gives broader highlights. |
| Fill / rim | Select the named Fill or Rim light > same controls | Fill `180 W / 3.5 m`; rim `550 W / 3 m`. |
| Render transparency | Render Properties > Film > **Transparent** | Enabled. PNG output is RGBA. |

The viewport uses Material Preview's studio environment for quick interaction.
Use F12 for the exact saved lights and Cycles shading. AgX color management means
rendered pixels include lighting and tone mapping; they are not flat palette hexes.

All ten palette materials are stored in the blend. To use a preset on all parts:
select body, both hand meshes and both foot meshes, with the body selected last;
choose a `Toy | …` material on the body, then **Object > Link/Transfer Data > Link
Materials** (Ctrl+L > Link Materials). Do not include the face in that selection.
For quick experimentation, changing Base Color on the existing shared blue
material is simpler; its name will still say Blue until you rename it.

| Red | Orange | Golden Yellow | Green | Cyan |
| --- | --- | --- | --- | --- |
| `#E53935` | `#F57C00` | `#FBC02D` | `#43A047` | `#00ACC1` |
| Blue | Indigo | Purple | Pink | Brown |
| `#1E88E5` | `#3949AB` | `#8E24AA` | `#EC407A` | `#8D6E63` |

## Poseable hierarchy and ground contract

```text
Character.Root - ground anchor        at (0, 0, 0)
├─ Body.Pivot                         body center, Z=1.62
│  ├─ Body.Squircle                   adjustable silhouette
│  └─ Face.Plane - neutral artwork    in separate untinted collection
├─ Hand.L.Wrist → Hand.L              independently movable/rotatable
├─ Hand.R.Wrist → Hand.R
├─ Foot.L.Contact → Foot.L            pivot centered on sole at Z=0
└─ Foot.R.Contact → Foot.R
```

Front is **-Y**, up is **+Z**. L/R mean the left/right of the front preview.
Select a named pivot in the Outliner, then G to move or R to rotate. Body motion
carries the face; hands and feet remain independently poseable. The root moves
the entire character. Enable viewport overlays (Shift+Alt+Z) if you want to see
the pivot guides. There is no armature and no walk/run animation in this task.

Both soles sit at **Z=0**. The ground guide and the root share this anchor.
An optional Cycles shadow catcher lies at Z=-0.003 to avoid intersecting soles.
The default beauty previews exclude it. The `blue-contact-shadow-768.png` preview
shows the optional result; the choice of baked shadow versus game-scene shadow
is still for owner review. To enable it, find `Ground.ShadowCatcher - optional`
in `04 | Ground guides`, enable its viewport eye and render-camera icon (expose
restriction toggles using the Outliner filter if necessary).

## Face and expressions

The exact 100×58 neutral texture is on a flat 1.25×0.725 plane, 0.015 units ahead
of the body's front. It is parented to `Body.Pivot`, with no camera-facing
constraint. The 35° three-quarter view visibly compresses its width. The plane
is intentionally not wrapped around the body; extreme side views are outside
this proof of concept.

To try a blink: select `Face.Plane - neutral artwork`, open the **Shading**
workspace, and locate the image texture node labeled **EXPRESSION - neutral /
blink**. Choose the packed image `PS056 Face - blink` in its image dropdown.
Return to `PS056 Face - neutral` for the baseline. Keep Extension **Clip** to
prevent the top and bottom image edges from repeating. The face material uses
original colors and alpha; it never shares the toy material. In Cycles, the face
is camera-visible but does not emit onto, reflect in, or cast shadows on the toy.
Nearby geometry can still occlude it naturally.

`blue-colorable-only-768.png` is a face-free render of the five colorable parts.
Hide the `02 | Face - untinted` collection for a new face-free render. This proves
separation; a production layered sprite exporter is PS-057 work.

## Files, provenance, and repeatability

- `previews/review-sheet.png`: front, three-quarter, and native small-size samples.
- `previews/palette-sheet.png`: all ten existing colors in the fixed angled view.
- `previews/*-768.png`: transparent studio renders, plus optional shadow and
  colorable-only evidence. Blue, red, and golden yellow include both views.
- `previews/*-128.png`, `*-256.png`: downsampled blue samples in both views.
- `previews/manifest.json`: render settings and output inventory.
- `validation.json`: structural checks from the saved Blender scene.
- `build_model.py`: optional reproducible Blender-native construction recipe.
  Run in a fresh file; it creates a new scene and saves `squircle-toy.blend` beside
  the script. This overwrites that output path, so keep owner edits in a copy.
- `render_previews.py`: uses the saved model, restores temporary scene changes,
  and does not save the blend. Run with Blender's background command below.
- `make_review_sheets.py`: composes review boards from existing rendered PNGs;
  requires Python with Pillow.

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background 'squircle-toy.blend' --python 'render_previews.py'
```

Source references at experimental base `8c1f850`: runtime Shape Character
`bodies/squircle.png`, `hands/open.png`, `hands/closed.png`, `feet/round.png`,
and `faces/neutral.png` / `faces/blink.png`, all under
`assets/runtime/shape_characters/`. The copied face pixels are unchanged.
Assembly reference: `characters/shape_character.tscn`; palette:
`characters/character_selection.gd`; color/face separation reference:
`characters/player_tint.gdshader`. The dimensional geometry was constructed for
this experiment. No Rayman art was copied or traced.

Owner chose relaxed open hands. Rounded fingers and simple rounded feet are the
first interpretation; 128/256-pixel canvas sizes and the shadow treatment remain
review assumptions. Technical checks and renders do not constitute owner art,
readability, game-feel, or animation-source approval.
