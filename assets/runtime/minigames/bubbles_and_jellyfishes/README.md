# Bubbles and Jellyfishes art

Static paper-craft assets extracted in GIMP for PS-036, PS-037 and PS-038.
The minigame scene, motion, collisions and phone renderer are separate work.

## Inventory and use

| Boundary | Files | Intended use |
| --- | --- | --- |
| `environment/` | `far_background.png`, `midground.png`, `foreground.png` | Three aligned 1920×1080 plates; compose in that order. Far plate is opaque; the two overlays have an empty center. |
| `environment/` | Ten named scenery props | Optional independent parallax/ambient-motion elements; use these instead of a flattened overlay when animating a plant. |
| `jellyfish/` | `jellyfish.png`, `jellyfish_small.png`, `jellyfish_drifting.png` | Default front-facing collectible plus two optional static variants. |
| `pufferfish/` | `pufferfish_left.png`, `pufferfish_right.png` | Complete directional hazard variants; use left as the canonical source. |

All sprites have eight transparent pixels around their visible bounds and a
center pivot `(0.5, 0.5)`. Dimensions, source rectangles, trimming and hashes are
recorded in [the extraction manifest](../../../../art/bubbles/extraction_manifest.json).
Use native aspect ratio. Suggested review widths, including padding: free
jellyfish 50–72 px; in-bubble jellyfish 22–32 px; pufferfish 100–145 px. These are
art-review samples, not final gameplay tuning or a chosen visual cap.

Godot imports use lossless compression, mipmaps, alpha-border correction, straight
alpha and disabled automatic 3D compression. Consumers should explicitly use
`CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` and
`CanvasItem.TEXTURE_REPEAT_DISABLED`. PNGs do not encode a Godot pivot or filtering
mode. Browser consumers should retain aspect ratio and normal smooth filtering.
Phone delivery/HTTP allowlisting is not implemented by this asset import.

For white-blink feedback, replace RGB with white while preserving sampled alpha;
multiplying a pink sprite by white does not whiten it. Pufferfish can rotate about
their center or use the directional variants; the rounded spiky silhouette stays
distinct from the jellyfish bell and long tentacles even without color.

The FHD overlays have no continuous floor. Keep flat prop bases outside the
viewport, and do not tile the background: it is not seamless. Parallax motion
needs overscan/cropping (for example, scale a plate to 1.04 for approximately
38 horizontal and 22 vertical pixels of travel). Do not reveal transparent edges
or treat the decorative reefs as collision boundaries.

## Source and provenance

- Supplied and selected for extraction by project owner Bruno Cesar Dalla Rosa
  on 2026-09-22; described by the owner as generative-AI artwork.
- Acquisition location: parent design vault, `Minigames/002/Generated Mockups/`.
- Sources: `bubbles-paper-ghibli-master-sprite-sheet.png` and
  `bubbles-paper-craft-far-background-fhd.png`; acquisition date 2026-09-22.
- Art direction and generation prompts are recorded alongside those source files
  in `Sprite Sheet Prompt.md`, `Far Background Prompt.md`, `Generation Prompts.md`
  and `Scenario Prompts.md`. Source hashes are preserved in the manifest.
- Creator record: owner-directed generative AI; generator/model and generation
  account are unspecified in the supplied files. GIMP extraction, cleanup and
  composition were performed by Codex on 2026-09-22 using GIMP 3.2.6 through MCP.
- License: no separate license grant or generator terms were supplied. The owner
  authorized importing and publishing these files in the project. No CC0,
  public-domain or third-party commercial-use license is asserted here.
- Attribution requirement: unspecified; none was supplied with the images.
  This record is provenance, not a legal clearance determination.

The extracted jellyfish are pink, matching the actual selected sheet (the earlier
generation prompt requested blue). The clipped rightmost smirking pufferfish is
excluded. Bubble/VFX/UI sprites are excluded because those elements are code-built
under the game design. The sand strip is excluded to avoid a visible arena floor.

## Review and reproducibility

[Art review, regeneration and verification](../../../../art/bubbles/README.md)
contains the previews and evidence. Source originals stay in the design vault;
review images, XCF and manifest stay under `art/`, outside runtime exports.
