# 005 asset sources

The models and images of [[005 - Tilt Shift 3D]], where each comes from and what changes. Placement is in [[005 - Scene composition]]. This guide authorizes no gameplay change and no change to other scenes' assets.

## Summary

| Scene role | Source | Change | Project destination |
| --- | --- | --- | --- |
| Shape paddle | None: generated in code | New reusable mesh and collider builder | Shared component folder |
| Face parts | Owner-supplied PNGs in `art/shape_characters_face_system_assets/` | Vectorized, X-eye added, exported at 8×, preset manifest | Masters in `art/shape_characters_face_system_assets/vector/`, runtime `assets/runtime/shape_faces/` |
| Bin | KayKit Restaurant Bits `crate` | Adapted in Blender into a three-part, flat-material bin | `art/tilt_shift_3d/crate/`, runtime `assets/runtime/minigames/tilt_shift_3d/crate/` |
| Trash emblem | Owner-supplied trash badge | Unchanged | `assets/runtime/minigames/tilt_shift_3d/trash_badge.png` |
| Ball | None: an engine low-poly sphere | None | — |
| Factory wall | None: a plane with a gradient material | None | — |
| Factory props | KayKit `pipe_90_A_blue`, `pipe_180_B_blue`, `pipe_end_blue`, `Parts_Cog`, `structure_C`, `watertower` | Copied unchanged; recoloured and scaled in the scene | `art/tilt_shift_3d/props/`, runtime `assets/runtime/minigames/tilt_shift_3d/props/` |
| Booklet preview | Owner-supplied 2D factory preview | Temporary placeholder until a 3D screenshot replaces it | `assets/runtime/minigames/tilt_shift_3d/tilt_shift_3d_preview.png` |

All library sources are CC0-1.0 KayKit packs (Kay Lousberg) held in the owner's local asset library. Attribution is not required; keep each pack's license file beside its copy, as `art/playground_plaza/` does. The face assets, trash emblem and booklet preview are the owner's own.

## Required changes

### Face parts

Reference: [the supplied assets](references/face-system-assets.jpg). The 26 source PNGs are small (an open eye is 40 px), flat navy and white, built from circles, arcs and rounded bars.

- Trace every part into a clean SVG master with the same shapes and the same two colours. Keep the source PNGs unchanged.
- Add an X-eye part, `facial_part_eye_x`, cut from `face_j` and traced the same way.
- Export every part as a PNG at 8× the source pixel size with transparent edges.
- Write `face_presets.json`: for each of `face_a` to `face_l`, the parts used and each part's centre, rotation, scale and mirroring inside a face box measured in face heights, plus the box aspect.
- Output: masters in `art/shape_characters_face_system_assets/vector/`; runtime PNGs and the manifest in `assets/runtime/shape_faces/`, a folder shared by all minigames.

Acceptance: each preset, rendered at 1× from the exported parts and the manifest, matches its reference face within one source pixel; the X-eye matches `face_j`; every part stays crisp at 8×; the owner approves a review sheet of all twelve presets at 1× and 8×.

### Bin

Reference: [bin sheet](references/basket-bin.jpg) and the [crate previews](references/crate-source.jpg).

- Replace the texture atlas with two flat materials: `Body` for the walls, slats and floor, and `Trim` for the corner posts and rim. The scene tints them per team.
- Cut the crate along its width into `BinLeft`, `BinMiddle` and `BinRight`. The ends hold the corner posts and wall ends; the middle has a uniform cross-section so it can stretch along X without distorting anything.
- Origin of the assembly at the centre of the mouth, on the top inner rim line; Y up, front facing −Z like the other project GLBs.
- Record in the README the end widths, the middle's native width, the wall thickness, the inner mouth edges and the depth.
- Output: one GLB with the three named meshes.

Acceptance: assembled at every opening width from 0.10 to 0.40 arena widths, the corners and posts keep their proportions; the inner mouth width equals the requested opening; height may scale between 0.75× and 2× without visible faults; at most 300 triangles in total; it imports in Godot 4.7.2 without errors; the owner approves review renders in orange, blue and grey.

### Factory props

No source edits. In the scene, materials are overridden with flat pale colours: teal around `#9ED3D0`, sky blue around `#A9CBEA` and warm grey around `#C9C2BA`. Exact colours may be tuned so the props stay quieter than every gameplay object.

## Copy rules

1. Before copying, check every file's SHA-256 against the values below. If anything differs, stop and report; do not substitute another file.
2. Copy only the selected source and the dependencies listed for it, plus the pack license file. Library originals stay unchanged.
3. Keep unchanged copies and the adapted Blender source under `art/tilt_shift_3d/`, which Godot does not import. Put runtime files under `assets/runtime/minigames/tilt_shift_3d/` and `assets/runtime/shape_faces/` and add them to the standalone export policy.
4. Record provenance in `art/tilt_shift_3d/README.md` and `art/shape_characters_face_system_assets/README.md`: source, path, hash, license and any change.
5. Nothing here may change the plaza assets, 004's assets or the Squircle.

## Selected sources and hashes

Paths are relative to the root of the owner's local asset library. The three Platformer Pack pieces share one texture file, held in each colour folder.

### Bin: crate

- Pack `KayKit_Free_pack`, library catalog ID `asset_101425cbeee8861548b16ee5ba7b106a`, CC0-1.0.
- Source (gltf): `KayKit_Free_pack/KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf/crate.gltf`
  - sha256 `f745014f6239147f2528ac24ef988a5833d048bd3aede81085f4c4fc879a8e16`
- Needs buffer: `KayKit_Free_pack/KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf/crate.bin`
  - sha256 `252687039209b62a3283319d2836d0e0d6745dd638ea53e2315df981c75a6c07`
- Needs texture: `KayKit_Free_pack/KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf/restaurantbits_texture.png`
  - sha256 `1bfff8f880c5e5e1b793bc46fa1f91149b7f70766174a817b3d5962495c5e40f`
- License file: `KayKit_Free_pack/KayKit_Restaurant_Bits_1.0_FREE/License.txt`
  - sha256 `47a1812de438d7452117753d0efbe734c5293db00859b605679128725acf86ef`

### Pipe bend: pipe_90_A_blue

- Catalog ID `asset_0dbe920a7267b1c0f06cf9207a43781a`, CC0-1.0, 576 triangles.
- Source (gltf): `KayKit_Free_pack/KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/blue/pipe_90_A_blue.gltf`
  - sha256 `a1a76bb7d7a8c7eb51b931275449ea90ef8f58dc22396ce2d8acbbfd0bdf11f8`
- Needs buffer: `.../gltf/blue/pipe_90_A_blue.bin`
  - sha256 `06d1337aa2dd49ab5361fb7691388ffbb61eb1e8d09f5b852eba6a825bc5b521`
- Needs texture: `.../gltf/blue/platformer_texture.png`
  - sha256 `2771a7c3f7fd59bcba08dc967858942d9f83820ecc9146e98d25707a07210273`
- License file: `KayKit_Free_pack/KayKit_Platformer_Pack_1.0_FREE/License.txt`
  - sha256 `3fcf0b55c93cfb61138490e2e660a3889427d97c0cfffec2f0d50a9864e9ec69`

### Pipe U-bend: pipe_180_B_blue

- Catalog ID `asset_076b18e2849a003a746fce6318fabf00`, CC0-1.0, 1,280 triangles.
- Source (gltf): `KayKit_Free_pack/KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/blue/pipe_180_B_blue.gltf`
  - sha256 `98a0674bc8cacc262e3dc861d501ce0ceb2711277160d1211b9344631f0dbeec`
- Needs buffer: `.../gltf/blue/pipe_180_B_blue.bin`
  - sha256 `51f5b4e2949cd77608811b9e7f17aa0dcd587912de465a5d30e9576f10576402`
- Needs texture and license: as pipe_90_A_blue.

### Pipe end: pipe_end_blue

- Catalog ID `asset_bfeed1d88586819efecd824597aaa80f`, CC0-1.0, 288 triangles.
- Source (gltf): `KayKit_Free_pack/KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/blue/pipe_end_blue.gltf`
  - sha256 `f1070ad99072dcc187ba11077633a7a05c02f4749eb1074a85fa57f57932fd18`
- Needs buffer: `.../gltf/blue/pipe_end_blue.bin`
  - sha256 `0bfa7b936a12b4228fd356b33cf19be43d18d0449072ad77485abde6d0dcb88a`
- Needs texture and license: as pipe_90_A_blue.

### Scaffold: structure_C

- Catalog ID `asset_6016be047dc88818541eb68a2723093a`, CC0-1.0, 176 triangles.
- Source (gltf): `KayKit_Free_pack/KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/neutral/structure_C.gltf`
  - sha256 `86656de630f2124ffb273582a0eb77fe6ed3ab08ed7c1a8122fce5a0f3d7018c`
- Needs buffer: `.../gltf/neutral/structure_C.bin`
  - sha256 `a4bc1f34e97daaace259d6600110cc66f76fb1be8aab9167411b4c5c423ccceb`
- Needs texture: `.../gltf/neutral/platformer_texture.png`
  - sha256 `2771a7c3f7fd59bcba08dc967858942d9f83820ecc9146e98d25707a07210273`
- License: as pipe_90_A_blue.

### Cog: Parts_Cog

- Catalog ID `asset_d7aaec45e9eca9a305ee1766879e02a8`, CC0-1.0, 192 triangles.
- Source (gltf): `KayKit_Free_pack/KayKit_ResourceBits_1.0_FREE/Assets/gltf/Parts_Cog.gltf`
  - sha256 `85103a0fd958df1223dbb3f05dd821f0b7d2dc890da170fe127d9130ef77ac4c`
- Needs buffer: `.../gltf/Parts_Cog.bin`
  - sha256 `fd2df471dfd61dadd626cbe97fd91046e1c0cdf84d302eb4f75633f5e26f2a2e`
- Needs texture: `.../gltf/resource_bits_texture.png`
  - sha256 `62a252aba7bc9382effe48d93b976605d8fa70a3a40af7fc52362f5ca89c135b`
- License file: `KayKit_Free_pack/KayKit_ResourceBits_1.0_FREE/License.txt`
  - sha256 `cfeda9f60f4c03bb8b342ab4448c944ea5dccc84cd697b4b8eaedcdaa46fcc34`

### Tank: watertower

- Catalog ID `asset_6ec466508d2ae0a1ca8da542cb1b68f5`, CC0-1.0, 146 triangles.
- Source (gltf): `KayKit_Free_pack/KayKit_City_Builder_Bits_1.0_FREE/Assets/gltf/watertower.gltf`
  - sha256 `55ae59f2a21ad38c64312a4c00d6808dc486bf4a8e8a8c969bc9e26cdc84d8f3`
- Needs buffer: `.../gltf/watertower.bin`
  - sha256 `384bc04add6c6fb56202e16688e375e4ad22739d46f37cd427e81087ffc192f6`
- Needs texture: `.../gltf/citybits_texture.png`
  - sha256 `6d2d9a5a13bce32209cd8c04572ab170504d68f34b1519165c9b0c41871e235b`
- License file: `KayKit_Free_pack/KayKit_City_Builder_Bits_1.0_FREE/License.txt`
  - sha256 `9d9a85d52902b2df8025805162cf83f165226d4277d627d1b96472cefe33adb9`

The [prop previews](references/factory-props-sources.jpg) show the six pieces as supplied.

## Verification expectations

- Hashes of every copied file match this guide.
- Each runtime model imports in Godot without errors, at the expected orientation and origin.
- The face presets match their reference images; the phone loads the face parts, the manifest and the paddle parameters from the host over HTTP, including in the exported Windows build.
- Ten players with the round's full ball budget keep the host and a phone at a smooth frame rate.
- The owner reviews the bins, faces and props in the running scene.
