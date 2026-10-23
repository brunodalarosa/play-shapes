# 004 asset sources

The models of [[004 - Bubbles and jellyfishes 3D]], where each comes from and what changes. Placement is in [[004 - Scene composition]]. This guide authorizes no gameplay change and no change to other scenes' assets.

## Summary

| Scene role | Source | Change | Project destination |
| --- | --- | --- | --- |
| Player character | Existing `assets/runtime/animated_characters/cubio/model/cubio.glb` | None; used through the existing 3D Cubio scene | Already in the project |
| Player bubble | None: a shader on an engine sphere | New reusable component | Shared component folder |
| Jellyfish | Kenney Food Kit `mushroom` (bell) + new geometry | Adapted in Blender into a new model | `art/bubbles_3d/jellyfish/`, runtime `assets/runtime/minigames/bubbles_3d/jellyfish/` |
| Pufferfish | KayKit `projectile_catapult` (body) + Kenney Food Kit `fish` (fins) + new geometry | Adapted in Blender into a new model | `art/bubbles_3d/pufferfish/`, runtime `assets/runtime/minigames/bubbles_3d/pufferfish/` |
| Branch coral | KayKit `Tree_Bare_2_A_Color1`, `Tree_Bare_1_C_Color1` | Copied unchanged; recoloured in the scene | `art/bubbles_3d/coral/`, runtime `.../bubbles_3d/coral/` |
| Kelp | KayKit `Grass_2_D_Singlesided_Color1`, `Grass_1_C_Color1` | Copied unchanged; recoloured, scaled and swayed in the scene | `art/bubbles_3d/kelp/`, runtime `.../bubbles_3d/kelp/` |
| Rocks | KayKit `rocks_A`, `Rock_3_M_Color1`, `Rock_1_L_Color1` | Copied unchanged; recoloured in the scene | `art/bubbles_3d/rocks/`, runtime `.../bubbles_3d/rocks/` |
| Sunken mug | Kenney Food Kit `cup` | Copied unchanged; scaled in the scene | `art/bubbles_3d/mug/`, runtime `.../bubbles_3d/mug/` |
| Sunken bottle | KayKit `bottle_A_green` | Copied unchanged; scaled in the scene | `art/bubbles_3d/bottle/`, runtime `.../bubbles_3d/bottle/` |

All library sources are CC0-1.0, from KayKit (Kay Lousberg) and Kenney packs held in the owner's local asset library. Attribution is not required; keep each pack's license file beside its copy, as `art/playground_plaza/` does.

## Required model changes

### Jellyfish

Reference: [jellyfish sheet](references/jellyfish.jpg).

- Bell: the `mushroom` cap with its stem removed, flattened to about 0.7 of its width in height, candy pink (about `#F48FB1`) with a lighter rim.
- Tentacles: five new simple tubes (bevelled curves, 6–8 sides) hanging straight down from under the bell, each ending in a tight curl, with slightly varied lengths, in a slightly deeper pink. The KayKit spring was considered and rejected.
- Eyes: two small black spheres on the front of the bell.
- Output: one GLB with separate meshes `Bell`, `Tentacles` and `Eyes`, so bell and tentacles can take a translucent rim-glow material while the eyes stay opaque. Origin at the bell centre, Y up, facing −Z like the other project GLBs.

Acceptance: recognisable as a jellyfish at about 55 pixels wide on a 1920-pixel screen, tentacles read as curly-tipped, at most 600 triangles, imports in Godot with the three named meshes, and the owner approves its look in the scene.

### Pufferfish

Reference: [pufferfish sheet](references/pufferfish.jpg).

- Body: `projectile_catapult` recoloured warm orange (about `#FF9800`) with slightly lighter spike tips; spikes may be shortened a little so the round body dominates.
- Fins: the tail fin and two pectoral fins cut from Kenney `fish`, recoloured orange-red (about `#FF5722`), attached as a fan tail and two small side fins.
- Face: new simple geometry: two large white eyes with black pupils, two pink cheek discs and a small pink-red pouting mouth.
- Output: one GLB with meshes `Body`, `Fins` and `Face`. Rest pose faces +X, origin at the body centre, Y up.

Acceptance: recognisable as a pufferfish at about 120 pixels wide on a 1920-pixel screen from the side and on diagonal headings, at most 700 triangles, fins stay attached when it turns, and the owner approves its look in the scene.

### Background props

No source edits. In the scene, materials are overridden with flat colours: coral pink `#F06292`, orange `#FF8A65` and purple `#BA68C8`; kelp teal `#26A69A` and green `#66BB6A`; rocks blue-grey around `#5C7FA3`. Kelp is stretched 3–5 times vertically and sways with a vertex shader. The mug and bottle keep their supplied materials. Exact colours may be tuned for readability.

## Copy rules

1. Before copying, check every file's SHA-256 against the values below. If anything differs, stop and report; do not substitute another file.
2. Copy only the selected source and the dependencies listed for it, plus the pack license file. Library originals stay unchanged.
3. Keep unchanged copies and the adapted Blender sources under `art/bubbles_3d/`, which Godot does not import. Put the runtime GLB or glTF files under `assets/runtime/minigames/bubbles_3d/` and add them to the standalone export policy.
4. Record provenance in `art/bubbles_3d/README.md`: source pack, path, hash, license and any change, as `art/playground_plaza/README.md` does.
5. Nothing here may change the plaza assets.

## Selected sources and hashes

Paths are relative to the root of the owner's local asset library.

### Jellyfish bell: mushroom

- Pack `kenney_food-kit`, library catalog ID `asset_ae0ecb0785c8a290c0ad88db419ade2e`, CC0-1.0.
- Source (glb): `kenney_food-kit/Models/GLB format/mushroom.glb`
  - sha256 `9ba28f47de26738f31083e590180aba99568f4399de0ec271924f0b278bac997`
- Needs texture: `kenney_food-kit/Models/GLB format/Textures/colormap.png`
  - sha256 `75baf74d9483a0fc56ac21ceba346fbe16fc24a2a1bf0524c53e6bbe802e1153`
- License file: `kenney_food-kit/License.txt`

### Pufferfish body: projectile_catapult

- Pack `KayKit_Free_pack`, library catalog ID `asset_78faf27561ac66dd70fbb38e195760ed`, CC0-1.0.
- Source (gltf): `KayKit_Free_pack/KayKit_Medieval_Hexagon_Pack_1.0_FREE/Assets/gltf/buildings/neutral/projectile_catapult.gltf`
  - sha256 `237483a212c16b392216e9318010a6eaa6ba8849d5b71470967eaa1c313f618b`
- Needs buffer: `KayKit_Free_pack/KayKit_Medieval_Hexagon_Pack_1.0_FREE/Assets/gltf/buildings/neutral/projectile_catapult.bin`
  - sha256 `6baeee13f5ce52976212f8acef4de7cfd55ce604ee3d239f94f6660ffdff9f51`
- Needs texture: `KayKit_Free_pack/KayKit_Medieval_Hexagon_Pack_1.0_FREE/Assets/gltf/buildings/neutral/hexagons_medieval.png`
  - sha256 `5301a06866ba3be68dcc14cc429bd6d0f69004b72884283715d7e233f2e9782e`
- License file: `KayKit_Free_pack/KayKit_Medieval_Hexagon_Pack_1.0_FREE/License.txt`

### Pufferfish fins: fish

- Pack `kenney_food-kit`, library catalog ID `asset_3dd2c68419cb31bca211961bfc7235a9`, CC0-1.0.
- Source (glb): `kenney_food-kit/Models/GLB format/fish.glb`
  - sha256 `5bb8109f83f7ec4609427c6d6de76572c4fc4d055dfc16d47f2c397290c0e29d`
- Needs texture: `kenney_food-kit/Models/GLB format/Textures/colormap.png`
  - sha256 `75baf74d9483a0fc56ac21ceba346fbe16fc24a2a1bf0524c53e6bbe802e1153`
- License file: `kenney_food-kit/License.txt`

### Branch coral A: Tree_Bare_2_A_Color1

- Pack `KayKit_Free_pack`, library catalog ID `asset_8460344bb0ccac2a2a3c611a73b023d5`, CC0-1.0.
- Source (gltf): `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Tree_Bare_2_A_Color1.gltf`
  - sha256 `426327b23a1e52e6f2e4d5e977794cf92fc4121ea92d9c82ed475ead5b71cb50`
- Needs buffer: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Tree_Bare_2_A_Color1.bin`
  - sha256 `399090bcbf7e791f588256001fa4a9c3bb7c96332d09eb56281f58e81def9e06`
- Needs texture: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/forest_texture.png`
  - sha256 `406c01e0ac1d3368fc7b26ff5fb0d3335ba5e48bd19a703540ed92ee3971ea39`
- License file: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/License.txt`

### Branch coral B: Tree_Bare_1_C_Color1

- Pack `KayKit_Free_pack`, library catalog ID `asset_3f9055855a5a0ffd4bdb4f5b1c142ab1`, CC0-1.0.
- Source (gltf): `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Tree_Bare_1_C_Color1.gltf`
  - sha256 `eab8a08bf1f5cbd916467bc5a6ae1ec6625f6ee34865a8ee580a656a59f8e5f2`
- Needs buffer: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Tree_Bare_1_C_Color1.bin`
  - sha256 `34eba3948880b8521e8d0d3d9d6913a96dcb4c87d8b6ad302b1aa7051424fae1`
- Needs texture: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/forest_texture.png`
  - sha256 `406c01e0ac1d3368fc7b26ff5fb0d3335ba5e48bd19a703540ed92ee3971ea39`
- License file: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/License.txt`

### Kelp A: Grass_2_D_Singlesided_Color1

- Pack `KayKit_Free_pack`, library catalog ID `asset_b4c9344d4fe0f9463c429d0e6433869a`, CC0-1.0.
- Source (gltf): `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Grass_2_D_Singlesided_Color1.gltf`
  - sha256 `b839423efe105cb532887213b62354144e4a17f08cfa9d13fcb13413472e49e1`
- Needs buffer: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Grass_2_D_Singlesided_Color1.bin`
  - sha256 `e635ce01334bdcaaebcad6d240cf7f0e5dd7acee5fd38857dbd7f76b4fd70e00`
- Needs texture: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/forest_texture.png`
  - sha256 `406c01e0ac1d3368fc7b26ff5fb0d3335ba5e48bd19a703540ed92ee3971ea39`
- License file: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/License.txt`

### Kelp B: Grass_1_C_Color1

- Pack `KayKit_Free_pack`, library catalog ID `asset_45501fd207b6a15e7d61e78b398d5330`, CC0-1.0.
- Source (gltf): `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Grass_1_C_Color1.gltf`
  - sha256 `449d1a5cc0e808eccdad297bd45d4c86439ceb97703c66db940f36879d242dd1`
- Needs buffer: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Grass_1_C_Color1.bin`
  - sha256 `ad2163a749bf75785f441eac9af6aa444eff591960ad5277c0433551628dbac3`
- Needs texture: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/forest_texture.png`
  - sha256 `406c01e0ac1d3368fc7b26ff5fb0d3335ba5e48bd19a703540ed92ee3971ea39`
- License file: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/License.txt`

### Rock cluster: rocks_A

- Pack `KayKit_Free_pack`, library catalog ID `asset_76e8ddbdc2045939fbe6ef57008ac938`, CC0-1.0.
- Source (gltf): `KayKit_Free_pack/KayKit_Space_Base_Bits_1.0_FREE/Assets/gltf/rocks_A.gltf`
  - sha256 `08ad445724788d6f746dabb663c04e58811a78882d1b2989051f194ce429d06f`
- Needs buffer: `KayKit_Free_pack/KayKit_Space_Base_Bits_1.0_FREE/Assets/gltf/rocks_A.bin`
  - sha256 `fb76b5ba35e2ee7875f47b57696d6cf52f3f6719aa7796bd8cc19f5a15ec44e7`
- Needs texture: `KayKit_Free_pack/KayKit_Space_Base_Bits_1.0_FREE/Assets/gltf/spacebits_texture.png`
  - sha256 `f19fe5ced42f72104a3c2e9f15d591622723695dd461a380691a8a21ebb01ae9`
- License file: `KayKit_Free_pack/KayKit_Space_Base_Bits_1.0_FREE/License.txt`

### Boulder: Rock_3_M_Color1

- Pack `KayKit_Free_pack`, library catalog ID `asset_e5df128f576b8aaa5854880cd2cbef85`, CC0-1.0.
- Source (gltf): `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Rock_3_M_Color1.gltf`
  - sha256 `e9d200a5da70cca763ab8e7c608de5175aef34f02c1fcb1c7b7b8f0ba173a153`
- Needs buffer: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Rock_3_M_Color1.bin`
  - sha256 `8a7f420d8ba7394a928f8f5652a298eee9d44dd72fc5cbff3522bb98ba04b95c`
- Needs texture: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/forest_texture.png`
  - sha256 `406c01e0ac1d3368fc7b26ff5fb0d3335ba5e48bd19a703540ed92ee3971ea39`
- License file: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/License.txt`

### Reef ledge: Rock_1_L_Color1

- Pack `KayKit_Free_pack`, library catalog ID `asset_ecf770481804c544e02e4c2fb1ff7b8c`, CC0-1.0.
- Source (gltf): `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Rock_1_L_Color1.gltf`
  - sha256 `407620a460c45a22275d4bbb5c219f5085ff44f811f1b5d6646232e93b2625a4`
- Needs buffer: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Rock_1_L_Color1.bin`
  - sha256 `c7ba0a00b57b538a5ab095a705ca3d13eef2e7eb22c845c3db257e21c937eef1`
- Needs texture: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/forest_texture.png`
  - sha256 `406c01e0ac1d3368fc7b26ff5fb0d3335ba5e48bd19a703540ed92ee3971ea39`
- License file: `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/License.txt`

### Sunken mug: cup

- Pack `kenney_food-kit`, library catalog ID `asset_74e01bd6a7ae21aedca650d666582ca7`, CC0-1.0.
- Source (glb): `kenney_food-kit/Models/GLB format/cup.glb`
  - sha256 `f9d6786fe9836f16ebb10cc1cb5a8ea8d512c7ae6cfa22394af653e5a5b05f09`
- Needs texture: `kenney_food-kit/Models/GLB format/Textures/colormap.png`
  - sha256 `75baf74d9483a0fc56ac21ceba346fbe16fc24a2a1bf0524c53e6bbe802e1153`
- License file: `kenney_food-kit/License.txt`

### Sunken bottle: bottle_A_green

- Pack `KayKit_Free_pack`, library catalog ID `asset_7bdba9685368fea1284df4a924258a1b`, CC0-1.0.
- Source (gltf): `KayKit_Free_pack/KayKit_Dungeon_Pack_1.1_FREE/Assets/gltf/bottle_A_green.gltf`
  - sha256 `0cd643e227fdb4369dd1cf85d34c58e6b6b605336c73384eb192d21cd6b98bd3`
- Needs buffer: `KayKit_Free_pack/KayKit_Dungeon_Pack_1.1_FREE/Assets/gltf/bottle_A_green.bin`
  - sha256 `e82b591d9efb83c7bfc438c031ff865cb125dd54ddd1599d497c2d7fb6e25c99`
- Needs texture: `KayKit_Free_pack/KayKit_Dungeon_Pack_1.1_FREE/Assets/gltf/dungeon_texture.png`
  - sha256 `ceb331d6ed53273da5e26808560bca8496f8f6ebc12d83b570c0e317560f1d03`
- License file: `KayKit_Free_pack/KayKit_Dungeon_Pack_1.1_FREE/License.txt`

## Verification expectations

- Hashes of every copied file match this guide.
- Each runtime model imports in Godot without errors, at the expected orientation and origin.
- Triangle budgets above hold; ten players with the maximum free and visible jellyfishes keep the
  host and a phone at a smooth frame rate.
- The phone loads the jellyfish model and the Cubio files from the host over HTTP, including in
  the exported Windows build.
- The owner reviews the jellyfish, pufferfish and background in the running scene.
