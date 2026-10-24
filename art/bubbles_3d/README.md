# Bubbles and jellyfishes 3D assets

Source models for minigame 004. The
[asset sources guide](../../docs/game-design-documents/Minigames/004/004%20-%20Asset%20sources.md)
decides each source and change; [scene composition](../../docs/game-design-documents/Minigames/004/004%20-%20Scene%20composition.md)
decides placement. Nothing here is used by a scene yet; [pending reviews](../../docs/pending-reviews.md)
lists what still needs the owner.

## Unchanged library copies

These files are unchanged CC0-1.0 deliveries by Kay Lousberg (KayKit) and Kenney, copied from
the owner's local asset library. Each folder holds one pack's files with that pack's
`License.txt`, so a role whose models come from two packs has one subfolder per pack.
Preserve the relative filenames: the glTF files name their buffers and textures, and the
Kenney GLBs name `Textures/colormap.png`.

| Role | Folder | Models | Original pack |
| --- | --- | --- | --- |
| Branch coral | [coral](coral/License.txt) | `Tree_Bare_2_A_Color1`, `Tree_Bare_1_C_Color1` | KayKit Forest Nature Pack 1.0 FREE |
| Kelp | [kelp](kelp/License.txt) | `Grass_2_D_Singlesided_Color1`, `Grass_1_C_Color1` | KayKit Forest Nature Pack 1.0 FREE |
| Boulder, reef ledge | [rocks/forest_nature](rocks/forest_nature/License.txt) | `Rock_3_M_Color1`, `Rock_1_L_Color1` | KayKit Forest Nature Pack 1.0 FREE |
| Rock cluster | [rocks/space_base_bits](rocks/space_base_bits/License.txt) | `rocks_A` | KayKit Space Base Bits 1.0 FREE |
| Sunken mug | [mug](mug/License.txt) | `cup` | Kenney Food Kit |
| Sunken bottle | [bottle](bottle/License.txt) | `bottle_A_green` | KayKit Dungeon Pack 1.1 FREE |
| Jellyfish bell part | [jellyfish/source](jellyfish/source/License.txt) | `mushroom` | Kenney Food Kit |
| Pufferfish body part | [pufferfish/source/kaykit_medieval_hexagon](pufferfish/source/kaykit_medieval_hexagon/License.txt) | `projectile_catapult` | KayKit Medieval Hexagon Pack 1.0 FREE |
| Pufferfish fin part | [pufferfish/source/kenney_food_kit](pufferfish/source/kenney_food_kit/License.txt) | `fish` | Kenney Food Kit |

KayKit models come from their pack's `Assets/gltf/` folder (the projectile from
`Assets/gltf/buildings/neutral/`) with the `.bin` buffer and texture atlas beside them.
Kenney models come from `Models/GLB format/` with `Textures/colormap.png`. Each
`License.txt` comes from its pack's root.

### Source identity

[SHA256SUMS](SHA256SUMS) lists the SHA-256 of every copied file, models, buffers, textures
and licenses, relative to this folder. The model, buffer and texture hashes are the ones
the asset sources guide approved; the license hashes were taken when copying. Check them
from this folder with `sha256sum -c SHA256SUMS`. `tests/bubbles_3d_models_test.gd` checks
both these copies and the runtime ones.

Git keeps the supplied bytes without line-ending conversion, set in `.gitattributes`.
Recolouring, scaling and kelp sway happen in the scene through material overrides and
shaders; these sources stay unchanged.

## Jellyfish

[jellyfish.blend](jellyfish/jellyfish.blend) is the editable Blender 5.2 source, built from the
Kenney `mushroom` cap. [export/jellyfish.glb](jellyfish/export/jellyfish.glb) holds three meshes,
590 triangles in all, with flat-colour materials and no textures:

- `Bell` (92 triangles): the cap with its stem deleted and the stem hole closed. The lip below
  its widest ring is compressed into a short skirt, the dome above is stretched, a ring cut
  halfway up the side is pushed out and the top ring drawn in, so the bell is a rounded dome
  0.55 wide and 0.7 as tall as it is wide. Pink `#F48FB1`, with the skirt `Bell Rim` `#F8BBD0`.
- `Tentacles` (450 triangles): five new tapered six-sided tubes, each a straight drop of
  slightly different length and a seven-segment curl of about 1.25 turns ending in a point.
  The outer pairs curl outward. Deeper pink `#F07BA6`.
- `Eyes` (48 triangles): two new black `#151515` oval domes set into the front of the bell.

The origin is the bell's bounding-box centre. The GLB is Y up and faces −Z; in Blender the
front is +Y. Bell and rim are two surfaces of one mesh, so a scene that gives the bell a
single material override draws the jellyfish in three surfaces instead of four.

The guide asks for the cap "flattened to about 0.7 of its width in height". The cap without
its stem is already only 0.48 as tall as it is wide, so reaching 0.7 and the dome of the
reference sheet means stretching it; the 0.7 ratio and the sheet were followed.

## Pufferfish

[pufferfish.blend](pufferfish/pufferfish.blend) is the editable Blender 5.2 source.
[export/pufferfish.glb](pufferfish/export/pufferfish.glb) holds three meshes, 612 triangles in
all, with flat-colour materials and no textures:

- `Body` (140 triangles): the KayKit `projectile_catapult` turned so +X looks between two
  neighbouring spikes, one over the forehead and one under the mouth, scaled to a radius of
  0.415, with its twelve spikes a quarter shorter. Orange `#FF9800`; the spike faces are
  `Spike Tips` `#FFB74D`.
- `Fins` (24 triangles): the Kenney `fish` tail fan, turned to point −X and stretched into a
  fan tail, and its two pectoral triangles, enlarged and set into the body's sides sweeping
  back. Orange-red `#FF5722`, double-sided because the fish's fins are single sheets.
- `Face` (448 triangles): new white `#FAFAFA` eyes with black `#151515` pupils looking
  forward, pink `#F48FB1` cheek discs and a pink-red `#EF5A5A` torus mouth.

The origin is the body centre. The GLB is Y up and faces +X; tail to mouth it is 1.19 long,
about 120 pixels in the game frame. The face parts and fins are one rigid mesh each, so they
stay attached at any heading.

## Building, export and review

The construction scripts are one-time and stay in ignored `scratch/`; edit the saved
`.blend` files directly. Run these from this folder with Blender's executable in `$blender`,
naming `jellyfish` or `pufferfish`:

```powershell
& $blender --background --factory-startup --python-exit-code 1 --python export_and_verify.py -- jellyfish
& $blender --background --factory-startup --python-exit-code 1 --python render_review.py -- jellyfish
& $blender --background --factory-startup --python-exit-code 1 --python render_review.py -- jellyfish --exported
```

[export_and_verify.py](export_and_verify.py) never saves over the source. It:

- checks the library parts against `SHA256SUMS`;
- opens the saved source and checks that no mesh carries normals inherited from a library
  part and that closed meshes face outward;
- exports only the asset collection and imports the GLB into an empty scene, where it checks
  mesh and material names and colours, which materials are double-sided, the triangle cap,
  non-degenerate triangles, the origin, the facing and that every part touches the body or
  bell;
- writes `export/verification.json` and copies the GLB to the runtime folder.

[render_review.py](render_review.py) writes front, side and three-quarter views on grey, a
1920 × 1080 frame on blue through the scene's 30° camera framing the 19.2-unit play plane,
and crops of that frame at true size and enlarged four times, into ignored
`scratch/review/`. The pufferfish frame shows four headings.

## Runtime copies

`art/.gdignore` keeps this folder out of Godot's importer. The game loads byte-identical
copies of the background props from `assets/runtime/minigames/bubbles_3d/`, in the same
folder layout, with their textures imported as VRAM-compressed with mipmaps. The jellyfish
and pufferfish library parts feed only the Blender sources and have no runtime copy; the
exported creature GLBs are copied to `jellyfish/` and `pufferfish/` there. The standalone
export policy lists every runtime model and license.
