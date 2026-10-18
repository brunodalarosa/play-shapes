# Bubbles and jellyfishes 3D assets

Source models for minigame 004. The
[asset sources guide](../../docs/game-design-documents/Minigames/004/004%20-%20Asset%20sources.md)
decides each source and change; [scene composition](../../docs/game-design-documents/Minigames/004/004%20-%20Scene%20composition.md)
decides placement. Nothing here is used by a scene yet.

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

## Runtime copies

`art/.gdignore` keeps this folder out of Godot's importer. The game loads byte-identical
copies of the background props from `assets/runtime/minigames/bubbles_3d/`, in the same
folder layout, with their textures imported as VRAM-compressed with mipmaps. The jellyfish
and pufferfish library parts feed only the Blender sources and have no runtime copy.
The standalone export policy lists every runtime model and license.
