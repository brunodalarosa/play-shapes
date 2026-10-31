---
area: Workshops and Tuning
tags: [system, stub]
code: [WorkshopWindow, WorkshopTuning, WorkshopTheme]
verified:
branch:
---

# Workshop Window

Hub: [[Workshops and Tuning]].

The shared parts of every minigame workshop.


The shared parts of every workshop live in `workshop/`, outside any minigame folder, as
[[Minigame Workshops|Minigame workshops]] designs them. Workshops and
`workshop/` are left out of the exported game.

- `workshop_window.gd` (`WorkshopWindow`) is the window: the top bar and the four panels. A
  minigame's workshop scene calls `setup` with its presets and its Active Presets field, fills
  the first three panels and restarts its game on `restart_requested`.
- `workshop_dockable_panel.gd` pops a panel out into its own window and docks it back;
  `workshop_layout.gd` remembers the layout in `user://workshops/`.
- `workshop_tuning.gd` (`WorkshopTuning`) holds the preset as saved, as edited and as running,
  with undo. A tuning Resource lists its live export groups in `LIVE_GROUPS`; other edits wait
  for a restart. `workshop_tunable.gd` is one value, found from the Resource's exports.
- `workshop_tunables_panel.gd` and `workshop_tunable_row.gd` draw the Tunables panel.
- `workshop_presets.gd` reads and writes a minigame's preset files, and
  `workshop_game_preset.gd` changes its one line of `Tuning/Active Presets.tres`.
- `workshop_phone_view.gd` shows the phone page in godot-wry, signed in as the designer
  ([[0054-workshop-phone-view-in-godot-wry|0054]]).
- `workshop_boot_request.tres` asks the boot for the servers bound to this PC only.
- `workshop_theme.gd` (`WorkshopTheme`) builds the Material Design 3 theme the window wears
  ([[0055-material-design-3-for-workshops|0055]]), with the fonts in `fonts/`.
