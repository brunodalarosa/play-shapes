# Tilt Shift 3D assets

Source models for minigame 005. The
[asset sources guide](../../docs/game-design-documents/Minigames/005/005%20-%20Asset%20sources.md)
decides each source and change; [scene composition](../../docs/game-design-documents/Minigames/005/005%20-%20Scene%20composition.md)
decides placement. [Pending reviews](../../docs/pending-reviews.md) lists what still needs the
owner.

## Crate, unchanged

[crate](crate/License.txt) holds the KayKit Restaurant Bits 1.0 FREE `crate` by Kay Lousberg,
CC0-1.0, copied unchanged from the owner's local asset library: `crate.gltf` and its buffer
`crate.bin` and texture atlas `restaurantbits_texture.png` from the pack's `Assets/gltf/`
folder, and `License.txt` from the pack's root. Preserve the relative filenames: the glTF names
its buffer and texture. The library catalog ID is `asset_101425cbeee8861548b16ee5ba7b106a`.

[SHA256SUMS](SHA256SUMS) lists the SHA-256 of the four files, relative to this folder; the
asset sources guide approved all four. Check them from this folder with `sha256sum -c SHA256SUMS`.
Git keeps their bytes without line-ending conversion, set in `.gitattributes`.

## Factory props, unchanged

[props](props/SHA256SUMS) holds six KayKit pieces by Kay Lousberg, CC0-1.0, copied unchanged
from the owner's local asset library with their buffers, texture atlases and the license of
each pack:

| Folder | Pack | Models |
| --- | --- | --- |
| `platformer` | Platformer Pack 1.0 FREE | `pipe_90_A_blue`, `pipe_180_B_blue`, `pipe_end_blue` from `Assets/gltf/blue/`, `structure_C` from `Assets/gltf/neutral/` |
| `resource_bits` | ResourceBits 1.0 FREE | `Parts_Cog` |
| `city_builder` | City Builder Bits 1.0 FREE | `watertower` |

The blue and neutral folders each hold a `platformer_texture.png`; the two are byte-identical,
so one copy serves all four Platformer pieces. [props/SHA256SUMS](props/SHA256SUMS) lists the
eighteen files, relative to that folder; every hash equals the asset sources guide's. The
scene recolours the props with material overrides and never edits them.

## Bin

[bin.blend](bin/bin.blend) is the editable Blender 5.2 source, built from the crate.
[bin.glb](bin/export/bin.glb) holds three meshes, 276 triangles in all, with the texture atlas
replaced by two flat materials and no texture coordinates:

- `Body` `#FD5D14`: the walls, the slats' faces and the floor.
- `Trim` `#FE9666`, a lighter orange: the rim along every top edge and the corner posts, which
  are the ends of the front and back boards where they overlap the side boards.

The scene tints both per team; the review renders mix Trim as the team colour 35% toward
white. Flat shading replaces the crate's custom normals.

The crate was cut at the inner faces of its side boards, X = ±0.75, into `BinLeft` (100
triangles), `BinMiddle` (76) and `BinRight` (100). Every vertex of `BinMiddle` lies on one of
the two cuts, so stretching it along X changes no slope, normal or proportion. The ends hold
the corner posts and the side boards and are never stretched.

### Measurements

In glTF axes, Y up, front −Z, at the native size, where one unit is the scene's world unit:

| Measurement | Value |
| --- | --- |
| Origin | Centre of the mouth on the top inner rim line |
| End width, each | 0.25, from X ±0.75 to ±1.0 |
| Middle native width | 1.5, from X −0.75 to 0.75 |
| Inner mouth edges | X = ±0.75, the side boards' inner faces |
| Height | 0.8, from Y 0 down to −0.8; the floor's top is at −0.7 |
| Depth | 2.0 outside, Z −1 to 1; 1.5 inside |
| Wall thickness | front and back boards 0.25; side boards 0.2, with the board ends 0.05 beyond |

To fit an opening of width `w`, scale `BinMiddle` along X by `w / 1.5` and move `BinLeft` by
`-(w - 1.5) / 2` and `BinRight` by `(w - 1.5) / 2`. The inner mouth is then exactly `w` and
the outer width `w + 0.5`. All three may scale together along Y between 0.75 and 2 times;
the origin stays on the rim. Because the origin is on the mouth's centre line in depth, balls
on the gameplay plane fall between the front and back boards.

The asset QA gate finds no z-fighting, detached parts, flipped normals, non-manifold or
degenerate faces. It reports, and these are accepted: no UV map, since both materials are
flat colours; open edges at the cuts, where the pieces meet; vertices shared by touching
boards, as in the crate; and 12 hidden back-to-back triangle pairs in each end, where the
crate's side boards meet its front and back boards.

## Building, export and review

The construction script is one-time and stays in ignored `scratch/`; edit the saved `.blend`
directly. Run these from this folder with Blender's executable in `$blender`:

```powershell
& $blender --background --factory-startup --python-exit-code 1 --python export_and_verify.py
& $blender --background --factory-startup --python-exit-code 1 --python render_review.py
```

[export_and_verify.py](export_and_verify.py) never saves over the source. It checks the crate
copies against `SHA256SUMS`, exports only the `Bin Asset` collection, imports the GLB into an
empty scene and checks the mesh and material names and colours, the triangle cap, the origin,
the cut and the assembled mouth at openings of 0.10 to 0.40 arena widths and heights of 0.75
to 2 times. It writes `bin/export/verification.json` and copies the GLB and the crate's
license to the runtime folder.

[render_review.py](render_review.py) assembles the exported GLB at openings of 0.10, 0.20 and
0.40 arena widths in orange `#FD5D14`, blue `#0055FA` and grey `#AC9992`, and writes into
ignored `scratch/review/` a 1920 × 1080 frame through the scene's 30° camera with the fronts
filling the band below the mouth line, three-quarter views of each width, and the 0.20 width at
0.75 and 2 times its height.

## Runtime copies

`assets/runtime/minigames/tilt_shift_3d/props/` holds byte-identical copies of the props for
Godot to import. Beside them are `trash_badge.png`, the trash emblem copied unchanged from the
2D Tilt Shift's baskets, and `tilt_shift_3d_preview.png`, the 2D factory's booklet preview,
copied unchanged until a 3D screenshot replaces it. `tests/tilt_shift_3d_props_test.gd`
checks every copy.

`art/.gdignore` keeps this folder out of Godot's importer. The game loads
`assets/runtime/minigames/tilt_shift_3d/crate/bin.glb`, byte-identical to the verified export,
with the crate's `License.txt` beside it. The crate's unchanged glTF and texture feed only the
Blender source and have no runtime copy. The standalone export policy lists both runtime files,
and `tests/tilt_shift_3d_models_test.gd` checks the copies, the meshes and the cut.
