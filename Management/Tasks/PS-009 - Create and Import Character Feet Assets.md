---
id: PS-009
title: Create and import character feet assets
type: implementation
status: done
release: Milestone 1
owner: ai
priority:
depends_on: []
---

# Goal

Complete the Kenney Shape Characters pack with floating feet that match its visual language, then import and configure the pack in Godot as reusable, tintable character parts for Milestone 1.

# Scope

- Inspect `assets/Kenney_Shape_Characters`, including its Default and Double PNG exports, spritesheet PNG/XML pairs, preview, vector overview, naming, scale, outlines, shading, transparency, and spacing before creating anything.
- Use appropriate computer-based image creation and editing tools, with visual inspection, to create the smallest useful set of detached foot assets for expressive Rayman-inspired characters with floating hands and feet.
- Match the source pack's proportions, line weight, palette treatment, lighting, edge quality, transparency, and pixel-density conventions closely enough that the feet read as part of the same family.
- Add corresponding foot PNGs to both `PNG/Default` and `PNG/Double` using consistent names and exact 2x dimensions between the two resolutions.
- Repack both spritesheet images and update both XML atlases without dropping, renaming, resizing, or corrupting existing entries.
- Preserve `License.txt`, the original Kenney attribution, and a clear record identifying the new feet as project-created additions rather than original Kenney assets.
- Import the character and relevant background-level assets into Godot with project-appropriate texture settings.
- Create a small reusable character asset setup whose body, face, left/right hands, and left/right feet can be positioned and animated independently.
- Configure the character art so runtime tinting can provide an effectively unlimited set of player colors while preserving readable facial features, outlines, highlights, and shadows. Avoid requiring a separately exported full character set for every color.
- Keep any asset-selection API or resource structure narrow, readable, and suitable for later use by the animation strategy selected in [[PS-010 - Explore Character Animation Strategy]].
- Update [[DEVELOPMENT]] with asset provenance, naming, import settings, tint usage, reusable character setup, validation evidence, and any caveats discovered.

# Non-Goals

- Implementing Dancer Simon Says gameplay, controller input, scoring, lives, elimination, or networking behavior.
- Producing the final dance animation library or committing to a rigging strategy before [[PS-010 - Explore Character Animation Strategy]] is approved.
- Adding 2D collision shapes, physics bodies, navigation, or platforming behavior for Milestone 1.
- Redrawing the rest of the Kenney pack or replacing its existing art direction.
- Creating a broad character-customization system, color-selection UI, persistence, or unlock system.
- Treating AI output as accepted solely because it was generated; visual comparison and human review remain required.

# Acceptance Criteria

- The repository contains a coherent, approved set of detached foot assets that visually matches the existing floating hands and geometric bodies.
- Every new foot exists in transparent Default and Double PNG form, with consistent naming and true 2x dimensions.
- The default and double spritesheet PNGs contain all existing assets plus the new feet, and their XML files contain correct, non-overlapping coordinates for every entry.
- Existing standalone PNG and atlas entries are unchanged in appearance and remain usable.
- A visual contact sheet or equivalent comparison shows the new feet beside representative bodies, hands, faces, and backgrounds at both source resolutions.
- Godot imports the relevant assets without errors and uses intentional texture filtering, mipmap, repeat, and compression settings appropriate to the art and expected display scale.
- A reusable Godot character can independently display and transform its body, face, two hands, and two feet, with sensible origins, draw order, and left/right behavior for later animation.
- At least several strongly different tint colors are demonstrated without duplicated per-color character assemblies, color leakage into facial details, or unacceptable loss of outline/highlight readability.
- The relevant background assets are imported and can be composed for a Milestone 1 level without collision configuration.
- Validation reports image/atlas checks, Godot editor-load results, runtime visual inspection, and human art approval as separate evidence.
- [[DEVELOPMENT]] and this task's findings/outcome document the final files, provenance, configuration, tint approach, and known caveats.

# Game Feel / Player Experience

The feet must remain legible while detached from the body and moving quickly on a shared screen. Their silhouette, spacing, scale, pivots, and overlap order should support playful dance poses rather than imply realistic anatomy. Tinting must keep players distinguishable without weakening facial readability or making hands and feet disappear against the included backgrounds.

# Open Questions

- Which foot silhouette and minimum pose variants look most natural beside the existing hand and body assets? Resolve through visual exploration and human art approval rather than expanding into a large speculative set.
- Whether the best tint-ready source is a neutral project-created variant, selective modulation of existing colored sprites, a shader/material approach, or another non-destructive setup.
- Whether one canonical resolution should drive runtime use while the other remains a source/export counterpart.
- Which pivots, mirroring rules, offsets, and draw-order defaults should be established now without prematurely choosing the animation implementation.
- Whether the existing background pieces need any import-setting exceptions relative to the character pieces.

# Notes / Findings

The inspected pack contains 104 standalone PNGs in each of `PNG/Default` and `PNG/Double`, plus `spritesheet_default.png`/`.xml` and `spritesheet_double.png`/`.xml`. It contains geometric bodies, faces, facial parts, six hand poses in several colors, shadows, and environment tiles, but no feet. The pack is Kenney Shape Characters 1.0 under CC0; new feet must be documented as project additions.

# Draft Execution Prompt

Read this task first and treat it as the source of truth. Then read [[Project Overview]], [[Workflow]], [[Decision Log]], [[DEVELOPMENT]], [[PS-001 - Define the First Gameplay Milestone]], and [[PS-010 - Explore Character Animation Strategy]] if it has been completed. Inspect the complete `assets/Kenney_Shape_Characters` pack and the current Godot project before changing anything. Use computer-based image creation/editing tools and visual inspection to create the smallest coherent foot set, preserving the pack's style, resolution conventions, existing files, and attribution. Present a compact visual comparison for human art approval before treating the feet as final. Update the Default and Double standalone PNG collections and both spritesheet PNG/XML pairs, then validate atlas completeness, coordinates, transparency, and 2x consistency. Import and configure the character and relevant background assets in Godot, create a minimal reusable assembly with independently transformable body/face/hands/feet, and demonstrate robust runtime tint variation. Do not implement gameplay, final dance animations, rigging, or collisions. Run relevant asset checks and Godot editor/runtime checks, visually inspect the result, and report automated, editor/runtime, visual, and human-approval evidence separately. Update relevant Markdown with provenance, tuning/configuration details, caveats, and exact usage guidance. Follow the repository's GitHub Flow instructions and open a pull request for human review.

# Outcome

2026-09-13: **done**. The project owner explicitly approved the foot art and
requested task completion. Technical validation and human art approval are
complete; pull-request merging remains a separate owner action.

- Created one rounded detached foot in GIMP, with a layered XCF source, transparent
  40 x 24 Default / 80 x 48 Double exports, and mirrored left/right use.
- Expanded both atlases to 105 entries. Original standalone files remain
  byte-identical; original atlas rectangles retain their appearance and coordinates.
- Added `characters/shape_character.tscn` with six independent sprite parts and
  per-instance runtime tinting; neutral face details are excluded from the shader.
  Double-resolution blue parts are canonical, rendered at half scale. Very dark
  tint requests are lifted toward slate for facial readability.
- Added a collision-free background composition and static six-color review scene
  at `characters/asset_showcase.tscn` (F6). No animation strategy was selected.
- Image/atlas checks and real-renderer tests passed. Editor load passed separately
  from existing MCP early-shutdown cleanup warnings. Visual source comparisons
  and runtime screenshots were inspected; the owner explicitly approved the foot
  art on 2026-09-13, completing the separate human acceptance step.
- Comparison sheets, XCF, preservation manifests, and runtime capture are in
  `art/character-feet/`. See [[DEVELOPMENT]] for exact usage, test commands,
  import settings, pivots, provenance, and the GIMP indexed-PNG working-copy workaround.
