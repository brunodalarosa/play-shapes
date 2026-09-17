---
id: PS-021
title: Implement curated runtime asset pipeline
type: implementation
status: in-progress
release:
owner: ai
priority:
depends_on:
  - PS-009
  - PS-012
---

# Goal

Create a small, explicit runtime asset set and repeatable intake workflow so Play
Shapes imports, references, tests, and exports only the sprites it actually uses,
while preserving the complete Kenney Shape Characters pack and project-created
source material as provenance-bearing source archives.

# Scope

- Inventory every production, debug, test, documentation, and tooling reference
  to `assets/Kenney_Shape_Characters`, including standalone PNGs, spritesheets,
  XML atlases, generated Godot import metadata, and the PS-009 validation tools.
- Record a before-change baseline for repository asset size, Godot import count,
  runtime-loaded textures, and a representative exported build or pack size so
  the optimization has measurable evidence rather than inferred savings.
- Establish a clearly named runtime asset root, such as
  `assets/runtime/shape_characters/`, containing only assets intentionally used
  by the game. Keep the exact folder name consistent and document it.
- Preserve `assets/Kenney_Shape_Characters` as the complete source/provenance
  archive, including Kenney's license, original color variants, both resolutions,
  atlases, XML, previews, and the documented PS-009 project additions. Do not
  destructively normalize, recolor, compact, or delete the archival pack.
- Define one machine-readable runtime manifest as the source of truth for every
  curated sprite. Each entry must identify its stable runtime name, source file,
  role, tint policy, canonical resolution, derivation/copy behavior, provenance,
  and any mirroring or import-setting requirements.
- Seed the runtime set with the current character dependencies: four canonical
  body silhouettes, six canonical hand poses, the project-created foot, the
  facial expressions used by `CharacterExpression`, and only the environment
  pieces that are genuinely referenced. Use the current Double-resolution
  canonical art at half scale unless inspection finds a documented reason to
  change that approved convention.
- Preserve runtime tint behavior from [[PS-009 - Create and Import Character Feet Assets]]:
  body, hands, and feet use one canonical shaded source per silhouette with the
  existing per-character tint material; faces and other color-sensitive art
  declare a non-tintable policy. Do not flatten shaded art to pure white or tint
  facial features accidentally.
- Implement a deterministic sync/check tool that can populate or verify the
  runtime set from the manifest. It must fail clearly for missing sources,
  duplicate runtime names, unexpected output files, dimension mismatches,
  unsupported tint policies, provenance omissions, or stale generated copies.
- Move production and relevant debug/test references from archival asset paths
  to stable runtime paths. Add a validation rule that prevents new production
  `.gd`, `.tscn`, or `.tres` references from bypassing the runtime set.
- Configure Godot and export behavior so archival source assets are not imported
  or packaged into release builds. Prefer a documented project-level exclusion
  that remains correct for new files; add an explicit export preset/filter if
  needed. Verify the actual exported contents rather than assuming a folder or
  `.gdignore` rule is sufficient.
- Keep standalone runtime textures unless measurement demonstrates a material
  benefit from a generated atlas. If an atlas is justified, generate it from the
  manifest with padding/extrusion appropriate for the existing mipmapped linear
  filtering and retain stable logical sprite names.
- Document the future sprite-intake workflow: where editable/source art belongs,
  how an agent adds a manifest entry, when a sprite may be tintable, how runtime
  output is refreshed, which checks run, and what visual/human review is required.
- Update [[DEVELOPMENT]], relevant asset provenance notes, and this task with the
  final folder contract, commands, measurements, limitations, and migration notes.

# Execution Plan

1. **Audit and baseline.** Enumerate current references and assets; capture file,
   import, load, and export-size baselines; identify source-only versus runtime
   requirements without moving anything.
2. **Define the boundary.** Choose the runtime root and manifest schema; document
   tintable, untinted, copied, derived, and mirrored asset policies. Treat the
   current archival pack as immutable input during routine sprite additions.
3. **Build the curated set.** Add the manifest and deterministic sync/check tool,
   then populate the smallest complete set needed by current scenes and tests.
4. **Migrate consumers.** Update character, expression, animation, environment,
   debug, and test references in small groups. Validate each group before removing
   its dependency on the archival paths.
5. **Exclude source archives.** Add and verify Godot import/export exclusions only
   after all runtime consumers have moved. Inspect the exported artifact contents
   and compare measured size with the baseline.
6. **Guard future additions.** Add automated checks for manifest integrity,
   runtime/source separation, import settings, dimensions, tint policy, and
   forbidden production references to archival folders.
7. **Verify presentation.** Run asset, script, editor-load, and real-renderer
   checks. Compare representative bodies, all hand poses, feet, expressions, and
   animations against the approved appearance across several tint colors.
8. **Document and hand off.** Write the short add-a-sprite procedure, record
   before/after measurements and caveats, and open a focused pull request under
   the repository's GitHub Flow process.

# Non-Goals

- Deleting or rewriting the complete Kenney source pack to reduce repository size.
- Redesigning the approved character art, feet, expressions, detached-sprite
  animation architecture, or per-player tint shader.
- Converting every colored source sprite to a new white or grayscale master when
  the approved canonical shaded source already works.
- Adding speculative sprites, costumes, body shapes, expressions, environment
  pieces, or broad character-customization APIs that are not currently required.
- Building an atlas solely because atlases are conventionally considered an
  optimization; runtime and export measurements must justify that added pipeline.
- Claiming visual parity, export exclusion, or performance improvement from unit
  tests alone.

# Acceptance Criteria

- A documented runtime asset root and machine-readable manifest contain every
  sprite used by production scenes/scripts, with stable names, source provenance,
  tint policy, resolution, and derivation behavior.
- Production `.gd`, `.tscn`, and `.tres` files contain no direct references to
  the archival Kenney folder, and an automated check prevents regressions.
- The complete source pack, license, original variants, atlases/XML, previews,
  and PS-009 additions remain preserved and clearly separate from runtime output.
- Running the sync/check workflow twice produces no second-run changes and fails
  with actionable messages when a manifest/source/output invariant is broken.
- Adding a representative test sprite through the documented intake workflow
  demonstrates that future assets can be introduced without copying unused color
  variants or manually editing multiple unrelated lists. Remove the test fixture
  afterward unless it is a real approved game asset.
- Godot imports the curated runtime assets with intentional lossless compression,
  filtering, mipmap, repeat, and alpha behavior consistent with their use.
- The archival source collection is absent from a representative exported build
  or pack, confirmed by inspecting exported contents. Before/after packaged sizes
  and the exact export configuration are recorded.
- Existing automated character-asset and animation tests pass after migration,
  and new checks cover manifest completeness, stale outputs, forbidden source
  references, tint-policy validity, and export-boundary configuration.
- A Godot 4.7 editor-load check reports no new import, resource, or script errors.
- Real-renderer comparison confirms preserved silhouettes, gradients, alpha edges,
  facial details, mirroring, pivots, animation texture swaps, and per-instance tint
  isolation. Automated and renderer evidence are reported separately.
- Human visual review confirms that representative characters still match the
  approved PS-009/PS-012 appearance before the task is marked done.
- [[DEVELOPMENT]] explains the runtime/source boundary and gives an AI-friendly,
  step-by-step procedure for adding, replacing, validating, and removing sprites.
- The work is delivered in a focused pull request; unrelated task-board or feature
  changes are excluded from its commits.

# Game Feel / Player Experience

This is primarily a maintainability and packaging change, so players should see
no visual or behavioral difference. Gradients, antialiasing, facial readability,
pose silhouettes, hand changes, foot mirroring, and animation timing must remain
unchanged. Future sprites should enter through the same tint and validation rules
so additional content cannot quietly reduce character clarity or consistency.

# Open Questions

- What final runtime-root name best distinguishes shipped art from source archives
  without conflicting with Godot's `res://assets` conventions?
- Should the manifest be a JSON file used by tooling, a Godot Resource used at
  runtime, or a build-time format that generates Godot-native resources?
- Is `.gdignore` sufficient for the archive boundary once runtime references move,
  or should the project use explicit export presets and exclusion filters as the
  authoritative release mechanism?
- Does a generated atlas measurably improve packaging, texture switching, or load
  behavior for the expected sprite count, or do standalone textures remain simpler
  and equally effective?
- Should source archives remain inside the Godot repository under an ignored
  subtree, or eventually move under the already Godot-ignored `art/` hierarchy?

# Notes / Findings

At task creation, the source pack contains 105 standalone PNGs at each of Default
and Double resolution plus matching atlases. The colored character subset contains
60 body/hand files per resolution but only 10 distinct silhouettes: four bodies
and six hand poses. The existing game already references blue Double-resolution
canonical parts, scales them to 0.5, and recolors bodies/hands/feet with
`characters/player_tint.gdshader`; faces remain untinted. Current production code
does not use the large spritesheet directly.

The complete pack is approximately 1.17 MB in the repository. Removing redundant
standalone color variants alone would save only about 152 KB compressed across
both resolutions, so this task optimizes the ongoing intake, import, reference,
and export boundary rather than destructively minimizing the provenance archive.

# Draft Execution Prompt

Read [[PS-021 - Implement Curated Runtime Asset Pipeline]], [[PS-009 - Create and Import Character Feet Assets]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[Project Overview]], [[Workflow]], [[Task System]], [[Decision Log]], and [[DEVELOPMENT]] before editing. Inspect the complete current asset/reference graph and preserve unrelated working-tree changes. Establish measured import/export baselines, then implement one documented runtime asset root and one machine-readable manifest that separates shipped sprites from the preserved Kenney/project source archive. Add a deterministic, idempotent sync/check workflow; migrate all production consumers to stable runtime paths; prevent future production references to the archive; and verify that source assets are absent from an inspected exported build. Preserve the approved Double-at-half-scale convention, shaded canonical sources, tint shader, untinted faces, pivots, mirroring, animations, and visual appearance. Do not add an atlas without measured benefit and filtering-safe padding. Add focused automated checks, run relevant existing tests and a Godot 4.7 editor load, perform real-renderer comparisons, and obtain human visual approval before marking the task done. Report automated, editor, renderer, export/package, and human evidence separately. Document the exact add-a-sprite workflow and before/after measurements in DEVELOPMENT.md. Follow GitHub Flow and open a focused pull request; do not include unrelated task-board or feature edits.

# Outcome

2026-09-16: implementation and technical validation are complete on
`feat/ps-021-curated-runtime-assets`; human visual approval remains the only task
acceptance step still pending, so the task is intentionally still `in-progress`.

- Added a 21-entry JSON manifest and deterministic sync/check tool under the
  documented `assets/runtime/shape_characters/` boundary. A second sync is a
  no-op; focused negative tests cover duplicate names, unsupported tint policy,
  and missing provenance.
- Migrated every production, debug, and test consumer from the Kenney archive to
  stable runtime paths. The check rejects future `.gd`, `.tscn`, or `.tres`
  bypasses and validates exact copies, dimensions, import policy, and outputs.
- Preserved the complete archive, added its Godot import boundary, and added a
  release validation preset. Direct PCK inspection found runtime assets present
  and no archival path. The comparable pack fell from 2,192,572 to 895,316 bytes
  (1,297,256 bytes / 59.17% smaller).
- Archive/atlas validation, pipeline tests, animation/expression/foundation
  checks, Godot 4.7.2 editor import/load, and GL Compatibility renderer checks
  pass. Renderer evidence confirms per-instance tint isolation, mirrored feet,
  preserved faces, and unchanged presentation.
- See [[DEVELOPMENT]] for the exact add/replace/remove workflow, measurements,
  commands, evidence labels, and the corrected LF license-baseline caveat.
