# 0028. Tilt Shift edits isolated drafts and previews ordinary gameplay

## Situation

Designer edits must survive explicit saving without mutating cached runtime content.
Editor tool scripts do not supply an ordinary gameplay loop. A second physics model
would diverge from runtime contacts, delivery and scoring.

## Decision

Use a Tilt Shift main-screen editor plugin with deep-copied Resource drafts. Data-only
Resources and pure validation/geometry helpers run in the editor; gameplay bodies and
the rules controller remain ordinary runtime scripts.

Explicit usable saves validate content; invalid drafts stay in ignored scratch storage.
Saved profiles embed selected content with repeated references preserved. This isolates
a reviewed profile from later edits to independently saved component files.

Preview launches a separate Godot process using the same gameplay arena/controller and
a temporary copied profile. Designer angles target synthetic player assignments through
the ordinary host seam. No phone transport or second physics implementation is added.

## What follows

- Round mappings and active selection are explicit edits; a basket selector alone does
  not change the shift. Stale mappings are retained until explicitly removed.
- Reflected pair edits preserve IDs; ambiguity is an error rather than an automatic
  reassignment. Geometry guides never reposition objects or certify strategic fairness.
- Undo/redo snapshots preserve shared references. Saved content changes only on save
  or explicit active selection, independently of preview state.
- Preview owns one process/session directory and cleans only those temporary files.
  Export filters exclude editor code, drafts and documentation captures.
