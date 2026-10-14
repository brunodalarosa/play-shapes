# Playground plaza billboard

Editable low-poly square billboard and a self-contained glTF 2.0 export for later
Godot integration. A blank display sits in a blue-gray frame above two grounded
truss supports. The two lamp housings contain no runtime lights.

## Files

- [billboard.blend](billboard.blend): current editable Blender 5.2.2 source.
- [export/billboard.glb](export/billboard.glb): mesh/material delivery without the studio.
- [export/verification.json](export/verification.json): geometry, UV checks and file hashes.
- [Near-frontal](review/near-frontal.png), [three-quarter](review/three-quarter.png),
  [rear](review/rear.png), [side](review/side.png) and
  [export view](review/export-near-frontal.png): technical inspection previews.

`art/.gdignore` excludes this package from Godot import; the existing `art/**` export
filter excludes it from standalone builds. Nothing in the running game loads this model.

## Coordinates and scale

The display is 6 by 6 in normalized authoring units, from height 5 to 11. The frame
is 6.4 square and 0.4 deep. The assembly is 6.4 wide, 0.8 deep at the feet and 11.57
high including the lamp housings. One planning character height is 1; these dimensions
do not establish world scale, jump reach or final-camera composition.

The root `Billboard` is at ground center. Blender uses Z up and the display faces +Y.
The GLB uses Y up and the display faces -Z. All mesh scales and rotations are applied.
The two supports connect the feet to the frame, with six crossed bays per support.

## Independent display

`Display` is a separate front-facing quad with its own `Display Blank Cream` material.
It is intentionally open geometry backed by a separate solid `Backing` mesh. Its
6-by-6 surface has no bevel, texture, logo, QR code or text.

In Blender, U increases toward -X and V toward +Z: the face appears upright from +Y.
The export converts V to glTF's top-left image convention. All four corners use the
full 0-to-1 UV square. The display sits at Blender Y = 0.201, just ahead of the frame.
Later integration can replace its material without changing the frame or supports.
Real QR scan size, contrast, camera placement and dynamic graphics remain unvalidated.

## Editing and export

Edit the named parts under `Billboard Asset` in the source. The root, collection and
mesh names are used by the export checks. The frame and feet retain editable
one-segment bevel modifiers, applied during export. Support beams and lamp components
are grouped into named mesh parts; their disconnected solid pieces remain editable.

Five plain Principled materials serve nine mesh parts. No image files, linked libraries
or external material dependencies are required. The separate
`Review Studio - Not Exported` collection contains only inspection camera, ground and lights.

Run these from this directory with Blender's executable assigned to `$blender`:

```powershell
& $blender --background --factory-startup --python-exit-code 1 --python export_and_verify.py
& $blender --background --factory-startup --python-exit-code 1 --python render_review.py
& $blender --background --factory-startup --python-exit-code 1 --python render_review.py -- --exported
```

Save source edits before exporting. The exporter opens the source, exports only the
asset collection and imports the GLB into a disposable scene. It never saves that
scene over the source. These scripts run independently of a live Blender session.

## Verification and limits

The verifier checks closed positive-volume structural meshes, nondegenerate faces,
square display bounds, orientation, upright corner UVs, independent display material,
support contact, applied transforms and external dependencies. It decodes GLB positions,
normals and UVs, then checks names, bounds, triangle totals, UVs and material values
after a Blender round trip. Reports apply only to the source/export hashes they record.

The delivery contains 990 triangles, five materials and 11 exported mesh surfaces.
An unbatched renderer may submit those surfaces per pass; shadows and integrated
rendering costs are unmeasured. While uninstantiated, this asset adds no host frame
work or phone traffic, regardless of roster size.

Review renders use a near-frontal orthographic camera with a gentle downward tilt,
plus inspection angles. They establish technical composition. Owner visual acceptance,
final-camera placement and readability remain pending in
[pending reviews](../../../docs/pending-reviews.md#playground-plaza-billboard).
Godot import, collision, scene conversion, QR scanning and ten-player performance
are outside this standalone asset delivery.
