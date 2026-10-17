# Playground plaza assets

Source models for the plaza. The authored [cafe](cafe/README.md),
[billboard](billboard/README.md) and [table](table/README.md) have their own delivery notes.

## KayKit props

These three models are unchanged glTF 2.0 deliveries by Kay Lousberg, copied from
`KayKit_Free_pack`. Each directory contains the model, its referenced binary buffer,
its texture atlas and the original pack license. Preserve their relative filenames.
Git preserves the supplied bytes in these three directories without line-ending conversion.

| Role | Model | Original pack | License |
| --- | --- | --- | --- |
| Chair | [chair_A.gltf](chair/chair_A.gltf) | KayKit Restaurant Bits 1.0 FREE | [CC0](chair/License.txt) |
| Tree | [Tree_2_E_Color1.gltf](tree/Tree_2_E_Color1.gltf) | KayKit Forest Nature Pack 1.0 FREE | [CC0](tree/License.txt) |
| Potted plant | [bush.gltf](potted_plant/bush.gltf) | KayKit City Builder Bits 1.0 FREE | [CC0](potted_plant/License.txt) |

The supplied licenses identify Creative Commons Zero (CC0) and credit Kay Lousberg
at www.kaylousberg.com. Each model was taken from its pack's `Assets/gltf/` directory;
each `License.txt` was taken from that pack's root.

### Source identity

SHA-256 of each unchanged model:

- `chair/chair_A.gltf`:
  `0d0abdc382abedb3e4bc2e0260af663c16ff2dab0d441f09d675e0709a7a7310`
- `tree/Tree_2_E_Color1.gltf`:
  `5330b533a759a013ad752be03a8c85a49f304e45d777b1da99522eeb5a1d74a9`
- `potted_plant/bush.gltf`:
  `b1de478b23e6bcfd08d6c070440582195839f66dfd3afc123118fb6298483183`

## Integration boundary

`art/.gdignore` excludes these sources from Godot's asset importer. No running scene
references these models. Their scene scale, orientation, collision, landing surfaces,
materials in Godot and final-camera readability still need to be fitted and checked
during scene integration. Keep one shared copy of each prop for reuse.

The files add no host frame work or phone messages while uninstantiated. A completed
file copy and matching hashes establish source delivery, not a playable plaza.
