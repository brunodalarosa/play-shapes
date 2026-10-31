---
area: Art Pipeline
tags: [hub]
code: [art, assets/runtime, art/cubio/cubio-animated.blend, assets/runtime/playground_plaza, assets/runtime/shape_faces]
verified: 2026-10-31
branch: feature/knowledge-base
---

# Art Pipeline

Area hub. Parent: [[Notebook]]. Sources live in `art/`, which Godot and the export ignore;
everything the game loads is a verified copy in `assets/runtime/`.

## Notes

- [[Cubio Source and Export]]: the Cubio rig, clips and GLB export.
- [[Shape Face Parts]]: the face system's parts and presets.
- [[Plaza Assets]], with [[Plaza Cafe]], [[Plaza Billboard]], [[Plaza Cafe Table]] and
  [[Plaza Logo Sign]].
- [[Logo]].
- Per-minigame art: [[004 Art Assets]], [[005 Art Assets]], [[006 Asset Sources]].

## Rules

- **Ready-made assets first; author new ones only when strictly necessary.**
- `art/` carries `.gdignore`, and the export filter excludes `art/**`.
- One world unit is one character height. GLBs are Y up with facades facing −Z.
- Temporary variants go in ignored `scratch/` or `comparisons/`, never in commits.
- Every authored mesh passes the Blender asset QA before it is called done.

## Gotchas

- The café table's pack-specific license is unresolved
  ([provenance](../../../art/playground_plaza/table/source/PROVENANCE.md)). It blocks
  publication, not local work.

Architecture: [[Art Direction]], [[Lobby Visual Rules]].
