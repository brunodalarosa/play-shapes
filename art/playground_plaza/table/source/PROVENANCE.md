# Cafe table provenance

The adapted cafe table derives from Quaternius' Ultimate House Interior Pack,
June 2020 edition, using the supplied `Table_RoundSmall.obj` and its material file.
The copies in this directory are unchanged. Their approved SHA-256 hashes are:

| File | SHA-256 |
| --- | --- |
| [Table_RoundSmall.obj](Table_RoundSmall.obj) | `7e95bb32fe64438ff90e4f25407acf86ebd6173405da99fe0c150b9121bdbece` |
| [Table_RoundSmall.mtl](Table_RoundSmall.mtl) | `f9cf420bec3be1dcebf8294fb1fa28fecd75a5c61069c77b898136ebe4efe060` |

The source path within the supplied collection is
`quaternius_ultimate-house-interior-pack/Ultimate House Interior Pack - June 2020/OBJ/`.
Only these two source files are required. The MTL contains one plain Wood material
and no texture map references. The original library files were not modified.

## Adaptation

The original two connected components become `Tabletop` and `Pedestal and Base`.
Uniform scaling normalizes tabletop width to 4.25. After shifting the base to ground,
the straight pedestal collar between original Y heights 0.247605 and 0.320399 is
extended by approximately 0.487797. The upper pedestal and complete tabletop move up
by that amount.

The stem from original Y height 0.247605 upward is narrowed to 50% of
its normalized width and depth. The foot below that collar retains its source shape,
and every vertex keeps its height from the initial adaptation. Support normals are refreshed.
The tabletop top is at height 3 and its thickness remains approximately 0.252256.

The source Wood material is replaced with golden-yellow tabletop and charcoal
pedestal/base materials. No braces, new shape details, textures or collision are added.
The exporter checks the source hashes and adapted geometry against the original vertices,
including the stem reduction and preserved tabletop, foot and heights.

## License evidence

Pack-specific author/license evidence remains unresolved. The selection evidence
included only a local collection note claiming CC0; that note is not a pack-specific
license. The inspected pack root contains Blends, FBX, OBJ and a preview image, with
no supplied license file. This document does not establish a license grant.

Publication remains pending until applicable author/pack license evidence is resolved
and the project owner approves publication. Do not replace this status with a verified
license claim based solely on the collection note.
