---
tags: [hub]
code: []
verified: 2026-10-31
branch: feature/knowledge-base
---

# Improvements

Cross-cutting friction. Parent: [[Notebook]]. Format:
`- **<what gets in the way>**: why it hurts, what would improve it. Seen: YYYY-MM-DD`.
Remove an item once it's fixed.

## Tooling and build

- **Three places name each minigame by hand**: `Tuning/Active Presets.tres`, the phone asset
  routes in `host/http_service.gd` and the export policy's required paths. A new minigame
  misses one easily; deriving them from the catalog would remove the step. Seen: 2026-10-31

## Agent setup

- **Most Notebook pages are still `stub`**: they were moved from `docs/` and not yet
  re-checked against the code. Re-verify a page when a task touches it, then drop the tag and
  set `verified`. Seen: 2026-10-31

## Process

- **Two workshop designs coexist**: Tilt Shift's editor addon and the shared window. Notes for
  each minigame must say which one it uses until Tilt Shift and Bubbles move over. Seen:
  2026-10-31

## Codebase-wide
