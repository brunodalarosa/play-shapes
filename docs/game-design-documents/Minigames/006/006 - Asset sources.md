# 006 asset sources

The models of [[006 - Flappy Race]], where each comes from and what changes. Placement is in [[006 - Scene composition]]. This guide authorizes no gameplay change and no change to other scenes' assets.

## Summary

| Scene role | Source | Change | Project destination |
| --- | --- | --- | --- |
| Stalactite, stalagmite | KayKit Forest Nature `Rock_1_O` (tip), `Rock_1_K` (shaft), `Rock_1_J` and `Rock_1_M` (shaft variants) | Sandy recolour; stacked by a column builder; flipped for stalactites | `art/flappy_race/rocks/`, runtime `assets/runtime/minigames/flappy_race/rocks/` |
| Rock stack | KayKit Medieval Hexagon `mountain_B`, with `Rock_1_M` as a variant | Sandy recolour; stacked to height | Same folders |
| Crystal shards and clusters | None: generated in code | New reusable crystal builder, Godot and three.js | Shared component folder |
| Speed pickup | KayKit Prototype Bits `Coin_A` | None; spin and glow at runtime | `art/flappy_race/coin/`, runtime `assets/runtime/minigames/flappy_race/coin/` |
| Respawn heart | KayKit Platformer `heart_red` | Tinted to the player's colour at runtime; glow and refill ring at runtime | `art/flappy_race/heart/`, runtime `assets/runtime/minigames/flappy_race/heart/` |
| Cave mushroom | Kenney Food Kit `mushroom` | Cap recoloured pink or teal with a soft glow | `art/flappy_race/mushroom/`, runtime `assets/runtime/minigames/flappy_race/mushroom/` |
| Cave walls | Kenney Mini Forest `rocks-ramp` and KayKit `mountain_B` | Recoloured lavender and teal, scaled and arranged into wall layers | `art/flappy_race/rocks/` and runtime folder |
| Cave floor | Simple geometry, with KayKit Resource Bits `Stone_Chunks_Small` pebbles | Pebbles recoloured sandy | `art/flappy_race/pebbles/`, runtime folder |
| Start gate, finish arch | Assembled from the column pieces and crystals, plus a checkered band | None to the sources | Scene only |
| Podium | None: simple geometry in the cave's stone with crystal trim | New | Scene only |
| Cubio | Existing `assets/runtime/animated_characters/cubio/model/cubio.glb` | New Flap, Hit and Respawn clips | Existing folders |

![The selected library sources](references/library-sources.jpg)

All library sources are CC0-1.0 packs held in the owner's local asset library: KayKit (Kay Lousberg) and Kenney. Attribution is not required; keep each pack's license file beside its copy, as `art/playground_plaza/` does.

## Required changes

### Stalactites and stalagmites

References: [stalactite](references/stalactite.jpg), [stalagmite](references/stalagmite.jpg) and the [approved assembly](references/column-assembly.jpg).

- One recoloured copy of each piece in warm sandy stone, a flat material in place of the pack's texture atlas.
- A column builder stacks shaft pieces from the root, each overlapping the previous by about 45% of its height and narrowing toward the tip, then ends with the tip piece. A random turn about the vertical axis on each piece keeps columns from repeating.
- Stalactites are the same build flipped, rooted beyond the top of the view at maximum zoom-out.
- Crystal clusters grow from the column's surface along its normal, a few large ones per column, more toward the tip.

Acceptance: at any length up to 60 m, a column shows no gaps or narrow necks between pieces at the closest and farthest zoom; its silhouette covers its collision boxes and does not reach into the gap beyond the hit box tolerance.

### Rock stack

Reference: [rock stack](references/rock-stack.jpg). Sandy recolour like the columns. Tall stacks repeat `mountain_B` with a turn about the vertical axis. Acceptance as for the columns.

### Crystals

Reference: [crystal](references/crystal.jpg). Hexagonal prisms with pointed tips, built from height, radius, facet count and tip length; clusters of three to six fanning from one root. Flat turquoise and pink materials, no texture. The same builder runs on the host and the phone, so the phone needs no crystal files. Acceptance: shards read as crystals at a 2 m size on the shared screen.

### Cave mushroom, heart, coin, walls, pebbles

References: [mushroom](references/cave-mushroom.jpg), [heart](references/respawn-heart.jpg), [coin](references/pickup-coin.jpg), [cave wall](references/cave-wall.jpg).

- Mushroom: a recoloured copy with a pink or teal emissive cap.
- Heart and coin: unchanged copies; tint, glow, spin and the refill ring are runtime.
- Walls: recoloured lavender and teal copies; arches are assembled from the column pieces.
- Pebbles: a sandy recoloured copy.

### Podium

Reference: [podium](references/podium.jpg). Three raised blocks side by side, the middle tallest for first, the left for second, the right lowest for third, and one long low step in front for everyone else. Each raised top holds one Cubio; the low step holds nine.

## Copy and import instructions

1. Follow root AGENTS.md and the implementation plan's checkpoints before importing.
2. Before copying, check every file's SHA-256 against the values below. If anything differs, stop and report; do not substitute another file.
3. Copy each source with its buffer and texture into `art/flappy_race/<group>/`, leaving the library originals unchanged, and keep each pack's `License.txt` beside its copy. Write `SHA256SUMS` there.
4. Make recoloured runtime GLBs in `assets/runtime/minigames/flappy_race/<group>/`, Y up, facing −Z like the other project GLBs. Serve the column pieces, the floor pebbles, the coin and the heart to the phone over HTTP.
5. Record provenance in `art/flappy_race/README.md`: source, path, hash, license and any change.
6. Add the new runtime paths to the standalone build policy.

## Selected sources and hashes

Paths are relative to the owner's asset library roots (`C:\BrunoOS\Game assets\` for KayKit, `Documents\General game assets\playful-lowpoly-asset-packs\` for Kenney).

- `Rock_1_O_Color1.gltf`, KayKit Forest Nature 1.0, `KayKit_Free_pack/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/`
  - sha256 `60e50199f545865b7ef7cec4a3cb99ef71a813b6e2079cd4d1f0f0a626e61964`
  - `Rock_1_O_Color1.bin` `41eefd97add129ba44fc5769a64f5e1098fdb23a8efacc2d80a3e88b301e210e`
- `Rock_1_K_Color1.gltf`, same folder
  - sha256 `1e7a18bd9e03a00a25ec15953391f0c65f7822951e752c360e676d09604c6cf6`
  - `Rock_1_K_Color1.bin` `e1a2d4e85398e34cfbc18ef085c916c60d89eb877622133f4874cc58dd59a881`
- `Rock_1_J_Color1.gltf`, same folder
  - sha256 `8821410d8b261346bd18547f41ac7d465f2254007d8fa6fee6ecf43c072979c9`
  - `Rock_1_J_Color1.bin` `49cf706f4885deb2a4079f22fe1f3000922229435e7f8af4928ab1d7443c9595`
- `Rock_1_M_Color1.gltf`, same folder
  - sha256 `e3cc71684110ffbe6a68d173979aeac3e56ae6215e821db1840c2c62ef0c92ad`
  - `Rock_1_M_Color1.bin` `8fd44261459863bb6ff074a58e608c2c651fdd2c5e53c14d2416246d26c0b904`
- The four rocks share `forest_texture.png` `406c01e0ac1d3368fc7b26ff5fb0d3335ba5e48bd19a703540ed92ee3971ea39`.
- `mountain_B.gltf`, KayKit Medieval Hexagon 1.0, `KayKit_Free_pack/KayKit_Medieval_Hexagon_Pack_1.0_FREE/Assets/gltf/decoration/nature/`
  - sha256 `367b785733d37cb2714f65ba5ceb182e1c2209fafb81b7ad41ba773564cb6915`
  - `mountain_B.bin` `b6af8ac3e6e2df676f9535ee55f49cf792658534e112fe173e52b2bbcfc7d4ac`
  - `hexagons_medieval.png` `5301a06866ba3be68dcc14cc429bd6d0f69004b72884283715d7e233f2e9782e`
- `Coin_A.gltf`, KayKit Prototype Bits 1.1, `KayKit_Free_pack/KayKit_Prototype_Bits_1.1_FREE/Assets/gltf/`
  - sha256 `9fc0a6e1bc8cd9af17184c5e229698878d222710bcf828fb79419d6b2e35fc03`
  - `Coin_A.bin` `ec0daba899fb776fd99d11b6bda072e09b578cf895017baabde900cacc965068`
  - `prototypebits_texture.png` `dec912e8cc8f8d09c29be48dda0daad90e653939c4e6fc799309ec1ae7a4cbcd`
- `heart_red.gltf`, KayKit Platformer 1.0, `KayKit_Free_pack/KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/red/`
  - sha256 `e7144dca45a625dde21da32a73e317f1b41270878f1bf904aa09bdbdb3cf171b`
  - `heart_red.bin` `2c67de83c74b023e0ffaf5b487d41ff22894f61a811e7d72cda770176fc293f9`
  - `platformer_texture.png` `2771a7c3f7fd59bcba08dc967858942d9f83820ecc9146e98d25707a07210273`
- `Stone_Chunks_Small.gltf`, KayKit Resource Bits 1.0, `KayKit_Free_pack/KayKit_ResourceBits_1.0_FREE/Assets/gltf/`
  - sha256 `c92409d663f1af77164d74bf8b3522207249591f1f5d4e22b0f3fb5372781094`
  - `Stone_Chunks_Small.bin` `58c68f4e870cac393ce76448d597707708c836f52461feccc04182ac6dcc9ef1`
  - `resource_bits_texture.png` `62a252aba7bc9382effe48d93b976605d8fa70a3a40af7fc52362f5ca89c135b`
- `mushroom.glb`, Kenney Food Kit, `kenney_food-kit/Models/GLB format/`
  - sha256 `9ba28f47de26738f31083e590180aba99568f4399de0ec271924f0b278bac997`
  - `Textures/colormap.png` `75baf74d9483a0fc56ac21ceba346fbe16fc24a2a1bf0524c53e6bbe802e1153`
- `rocks-ramp.glb`, Kenney Mini Forest, `kenney_mini-forest/Models/GLB format/`
  - sha256 `e09b699180e66a615be406d0ca8b1e1f42d573589a41c0067988418bc548d807`
  - `Textures/colormap.png` `319f1087d8ed50a8794f9a8179f64671d5595f2365fdf3e47ec2d4eb74dba20f`

## Unresolved conditions

- No essential asset is missing. The crystals and the podium are built in code.
- Scale, triangle counts, origins and material slots are unknown until import; the library did not report them.
- Dependency lists cover the known buffer and texture references; other binary dependencies are unverified.
- Recolouring replaces the texture atlas with flat materials; whether a palette texture or a flat material suits the phone better is an import decision.

## Verification expectations

These have not passed yet; the import must show them.

- Hashes match; each copy keeps its license file.
- Recoloured GLBs import in Godot on GL Compatibility and load in three.js on the phone.
- Pieces are Y up, facing −Z, with origins at the base centre.
- Column builds meet the acceptance above across many seeds.
- Phone frame time with the visible column pieces stays within the plan's budget.
