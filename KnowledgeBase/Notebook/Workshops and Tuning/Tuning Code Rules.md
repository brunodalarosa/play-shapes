---
area: Workshops and Tuning
tags: [system, stub]
code: [minigames/004_3d_bubbles/tuning/Default.tres, minigames/005_3d_tilt_shift/tuning/Default.tres, minigames/006_flappy_race/tuning/Default.tres, Tuning/Shared/Networking/Default.tres, README.md, tests/tuning_presets_test.gd]
verified:
branch:
---

# Tuning Code Rules

Hub: [[Workshops and Tuning]].

Where tuning Resources live and the rules a tuning script follows.


`Tuning/` contains the active selector, the shared named resources, a guide and an experiment
template. A minigame's named resources are in its own `tuning/` folder. The game has no
runtime tuning UI; a minigame's workshop edits its presets.

- Open `Tuning/Active Presets.tres` to select named resources. The current front doors are
  `minigames/004_3d_bubbles/tuning/Default.tres`,
  `minigames/005_3d_tilt_shift/tuning/Default.tres`,
  `minigames/006_flappy_race/tuning/Default.tres` and `Tuning/Shared/Networking/Default.tres`.
- Restart to apply a changed selection.
- Field descriptions for Bubbles and jellyfishes 3D, Tilt Shift 3D and Flappy Race are in the
  `README.md` beside each `Default.tres`.
- Only the human owner promotes subjective feel into `Default`. Tests establish configuration
  safety, not fun or comfort.

For Inspector help in a tuning script:

- Put a `##` documentation comment directly before the property and its export annotation.
- Use `@export_group`, not `@export_category`, because categories can break the property help
  that follows them.
- `tests/tuning_presets_test.gd` enforces this and recursively checks committed presets.
