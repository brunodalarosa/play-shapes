# Playground plaza cafe table

Editable variant of the supplied Quaternius round table with a taller pedestal,
slimmer stem, golden-yellow tabletop and charcoal support/base. The self-contained GLB is for
later Godot integration; the running game does not load this asset.

## Files

- [cafe-table.blend](cafe-table.blend): current editable Blender 5.2.2 source.
- [export/cafe-table.glb](export/cafe-table.glb): two meshes and materials, without the studio.
- [export/verification.json](export/verification.json): measured results and source/export hashes.
- [source/PROVENANCE.md](source/PROVENANCE.md): unchanged OBJ/MTL sources, adaptation and
  unresolved pack-specific license evidence.
- [Near-frontal](review/near-frontal.png), [three-quarter](review/three-quarter.png),
  [rear](review/rear.png), [side](review/side.png) and
  [export view](review/export-near-frontal.png): technical inspection renders.

The existing `art/.gdignore` and `art/**` build exclusion keep this package out of
Godot import and standalone builds. There are no colliders, runtime bindings or textures.

## Coordinates and scale

The tabletop is 4.25 wide and deep, with a broad flat top at height 3 and thickness
approximately 0.252256 in normalized authoring units. Its original 20-sided outline,
edge profile and foot geometry remain intact after uniform scaling. The original
straight pedestal collar is lengthened by approximately 0.487797 units. The full stem
profile from that lower collar upward is 50% narrower in both horizontal axes than
the first adapted version. All vertex heights remain unchanged; the foot retains its width.

One planning character height is 1. These dimensions do not prescribe the existing
character's world scale, collision height, jump reach or final-camera composition.
Fit the complete asset during separately approved scene integration.

The root `CafeTable` is at ground center. Blender uses Z up; the GLB uses Y up.
The table is rotationally symmetric in concept, with no distinct facade.
Mesh scales and rotations are applied. `Tabletop` and `Pedestal and Base` have separate
materials: golden yellow `#F4B940` and charcoal `#30333B`, respectively.

## Editing and export

Open the source and edit the named parts under `Cafe Table Asset`. The root, collection
and part names are used by the export checks. Tabletop and foot geometry are retained;
the narrowed support has refreshed normals. The separate `Review Studio - Not Exported`
collection holds the inspection camera, ground and lights.

Run these from this directory with Blender's executable assigned to `$blender`:

```powershell
& $blender --background --factory-startup --python-exit-code 1 --python export_and_verify.py
& $blender --background --factory-startup --python-exit-code 1 --python render_review.py
& $blender --background --factory-startup --python-exit-code 1 --python render_review.py -- --exported
```

Save edits before export. The exporter opens the saved source, exports only the asset
collection and imports the GLB into a disposable scene. It never saves that scene
over the source and does not change a live Blender session.

The verifier requires the approved dimensions, palette, stem reduction and preserved top/foot.
A later change to these delivery constraints must update the checks and documentation
together. Keep the pinned original OBJ/MTL unchanged.

## Verification and limits

The verifier checks approved source hashes, dependencies, closed positive-volume meshes,
nondegenerate faces, applied transforms, source-derived vertex positions, tabletop thickness,
flat top area, ground contact and palette. It decodes GLB world bounds and checks geometry,
names, triangles and material values after a Blender round trip.

The delivery contains 592 triangles, two materials and two exported mesh surfaces.
An unbatched renderer may submit those surfaces per pass; integrated shadows and rendering
costs are unmeasured. While uninstantiated, this asset adds no host frame work or phone traffic.

Near-frontal renders use an orthographic camera with a gentle downward tilt.
The studio uses the Standard view transform at exposure -1.5 to retain the palette's
saturation in inspection previews; final Godot lighting remains a later scene decision.

The owner approved the revised table's visual result on 2026-10-13, including its
50% narrower stem and retained height, tabletop and foot. Final-camera readability,
middle-tier reachability, ten-player play and game feel remain pending in
[pending reviews](../../../docs/pending-reviews.md#playground-plaza-cafe-table).
Godot import, collisions, scene conversion and gameplay changes are outside this delivery.
Pack-specific license evidence must be resolved before publication.
