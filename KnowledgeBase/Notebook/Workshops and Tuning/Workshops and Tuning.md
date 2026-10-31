---
area: Workshops and Tuning
tags: [hub]
code: [Tuning/Active Presets.tres, WorkshopWindow, WorkshopTuning, WorkshopTheme, addons/godot_wry]
verified: 2026-10-31
branch: feature/knowledge-base
---

# Workshops and Tuning

Area hub. Parent: [[Notebook]]. Named tuning Resources, the selector that picks them, and the
shared workshop window where a designer edits them against the real game.

## Notes

- [[Tuning Presets]]: `Active Presets.tres` and how to try and record a preset.
- [[Tuning Code Rules]]: where Resources live and the rules a tuning script follows.
- [[Workshop Window]]: the shared window's scripts.
- Experiments: one note per tuning experiment in `Experiments/`, from [[Tuning Experiment]].

## Rules

- **Only the owner promotes subjective feel into `Default`.** Tests prove a preset is safe,
  not that it is fun.
- There is no runtime tuning UI. A workshop edits presets; the game reads the selection at
  start.
- Live versus restart follows each Resource's `LIVE_GROUPS`.
- **No pause or speed controls**: the owner removed time controls because phones predict on
  their own clock.
- New workshop controls are designed from Material 3 and added to `WorkshopTheme` as variations
  ([[0055-material-design-3-for-workshops|0055]]).

## Gotchas

- The phone view uses vendored `addons/godot_wry/` v1.0.2, which only draws in the main
  window, so that panel stays docked ([[0054-workshop-phone-view-in-godot-wry|0054]]).
- `workshop/` and every `minigames/*/workshop/` are left out of exports.

Architecture: [[Minigame Workshops]].
