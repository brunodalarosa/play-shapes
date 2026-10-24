# Playground plaza logo sign

The Play Shapes logo as 3D letters standing on the café roof. Nothing here is modeled by
hand: [export_logo_sign.py](export_logo_sign.py) builds the whole sign from the
[approved logo](../../logo/README.md) every time it runs.

## Files

- [export_logo_sign.py](export_logo_sign.py): builds the sign and writes the export.
- [export/logo_sign.glb](export/logo_sign.glb): the sign, Y up, facing +Z.
- [export/verification.json](export/verification.json): triangle counts, materials, bounds
  and the hashes of the source PNG and the export.

## How the sign is built

1. The PNG is sampled at half resolution. Saturation separates the letters from the cream
   background, and hue separates blue from orange.
2. Each color is outlined with marching squares and simplified to within 0.9 pixels. The
   outlines become a filled 2D curve, so the holes in P and the triangles stay open.
3. The letters are extruded 0.6 deep with a 0.03 bevel. A cream backing, traced from the
   lettering grown by nine pixels, sits behind them like a cut-paper layer.
4. Four 8-sided metal posts with round feet hold the sign 0.9 above its origin.

The letters are 7.2 wide in plaza units, where the café roof is 7. The origin is the
bottom of the posts, at the centre of the sign, so the lobby places it straight onto the
roof. Colors are the median letter colors of the PNG, converted to linear.

## Exporting

Run from this directory with Blender 5.2 assigned to `$blender`, then copy the GLB to
`assets/runtime/playground_plaza/logo_sign/`:

```powershell
& $blender --background --factory-startup --python-exit-code 1 --python export_logo_sign.py
```

The script stops if the sign exceeds 9,000 triangles, if the posts do not reach the origin,
or if the letters lose their planned width. Sizes, depths and the post positions are named
constants at the top of the script.
