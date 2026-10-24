# Playground plaza cafe

Editable low-poly cafe source and a self-contained glTF 2.0 export for later Godot
integration. The asset has a flat roof, shallow decorative trim, a door, opaque window
panels and a cup emblem. There is no text, interior, collision or gameplay binding.

## Files

- [cafe.blend](cafe.blend): current editable Blender 5.2.2 source.
- [export/cafe.glb](export/cafe.glb): mesh and material delivery, without the review studio.
- [export/verification.json](export/verification.json): measured geometry and source/export hashes.
- [Near-frontal view](review/near-frontal.png), [three-quarter view](review/three-quarter.png),
  [rear](review/rear.png), [side](review/side.png) and
  [export view](review/export-near-frontal.png): technical composition previews.

`art/.gdignore` excludes this package from Godot import; the existing `art/**` export
filter excludes it from standalone builds. Nothing in the running game loads this model.

## Coordinates and scale

The complete asset measures 7 wide, 4 deep and 6.5 high in normalized authoring units.
One planning character height is 1; this is not a claim about the current character's
world scale or jump reach. Fit the whole assembly during later scene integration.

The root `Cafe` is at ground center. Blender uses Z up and the facade faces +Y.
The GLB uses Y up and the facade faces -Z. Mesh object scales are applied. The roof's
flat area is approximately 6.93 by 3.93, at height 6.5; its small edge chamfer stays
inside the outer bounds. All trim is decorative and must not become extra landing tiers.

## Editing and export

Open the source and edit the named parts under `Cafe Asset`. The root, collection and
`Roof` names are used by the export checks. Other mesh names must survive the GLB round trip.
One-segment bevel modifiers remain editable in the source and are applied on export.

Seven plain Principled materials are shared across 21 mesh parts. Amber panels are opaque;
no texture files, linked libraries or external material dependencies are required.
The separate `Review Studio - Not Exported` collection contains the camera, ground and lights.

Run these from this directory with Blender's executable assigned to `$blender`:

```powershell
& $blender --background --factory-startup --python-exit-code 1 --python export_and_verify.py
& $blender --background --factory-startup --python-exit-code 1 --python render_review.py
& $blender --background --factory-startup --python-exit-code 1 --python render_review.py -- --exported
```

The exporter opens the saved source, exports only the asset collection, then imports
the GLB into an empty disposable scene. It never saves the imported scene over the source.
Save edits before running it. Scripts run without opening or changing a live Blender session.

## Verification and limits

`export_and_verify.py` checks closed positive-volume parts, degenerate faces, applied
scales, a clear flat roof, external dependencies, mesh names and material values. It decodes
GLB positions to check world bounds and facade orientation, then checks the Blender round trip.
Run it again after source edits; a report only describes the source/export hashes it records.

The delivery contains 1,132 triangles and seven materials. A later unbatched renderer may
submit up to 21 mesh surfaces per pass; shadows and actual scene rendering costs are unmeasured.
While uninstantiated, the asset adds no host frame work or phone messages, with ten players
or any other roster size.

Previews use a near-frontal orthographic camera with a gentle downward tilt, plus inspection
angles. They establish technical composition, not final-camera readability or visual approval.
Godot import, collision, integration performance, roof reachability and multiplayer play
remain outside this delivery. Owner review is listed in
[pending reviews](../../../docs/pending-reviews.md#playground-plaza-cafe).
