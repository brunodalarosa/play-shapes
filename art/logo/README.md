# Play Shapes logo

[play-shapes-logo.png](play-shapes-logo.png) is the approved rounded Cut Paper logo: cobalt
blue PLAY above orange SHAPES on an opaque cream background. It is the unchanged 1536 × 1024
master. Treat it as the source of every logo use; do not repaint or recolor it here.

## Consumers

- The café [logo sign](../playground_plaza/logo_sign/README.md) traces it into 3D letters.
- `web/scripts/generate_pwa_icons.mjs` cuts it out from its background and composes the
  180, 192 and 512 pixel phone app icons beside the Cubio render.

Both separate the letters from the cream by color saturation, so a replacement must keep a
low-saturation background behind saturated lettering. After replacing the file, export the
sign again and regenerate the icons.

`art/.gdignore` keeps this folder out of Godot's importer and the export filter keeps it out
of builds. The game never loads the PNG directly.
