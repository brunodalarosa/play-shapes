# Play Shapes tuning guide

Start with `Active Presets.tres`. It is the project-level selector and shows the active Simon Says, Bubbles, and shared Networking assets in one Inspector. Save a selection and relaunch the relevant scene; there is intentionally no runtime tuning UI.

## Find, compare, and reset values

- Simon Says: `Minigames/SimonSays/Default.tres` is the umbrella profile for the gameplay/timing, animation/motion, and debug-preview values currently implemented. Visual feedback, audio/haptics, and phone-controller fields will be added only when those systems exist.
- Bubbles and jellyfishes: `Minigames/Bubbles/Default.tres` is the provisional umbrella profile for round rules, gesture recognition, and values later arena tasks will consume. See [its field guide](Minigames/Bubbles/README.md). Select a named copy in `Active Presets.tres` and relaunch before comparing feel.
- Networking/session: `Shared/Networking/Default.tres` owns host-only listener, capacity, timeout, and reconnect behavior.
- Default recovery: assign the appropriate `Default.tres` back into `Active Presets.tres`, save, and relaunch.
- Named comparison: duplicate `Default.tres` beside it, use a descriptive name such as `Generous.tres` or `Experimental_2026-09-14.tres`, change one logical group, assign it through `Active Presets.tres`, and commit it. Every committed `.tres` below `Tuning/` is validated.
- Experiment record: copy `Experiments/EXPERIMENT_TEMPLATE.md`; record the preset, hypothesis, conditions, observations, and human decision separately from the asset.

Hover an Inspector property for its purpose, units, default, safe range, and higher/lower guidance. Range metadata and clamping protect individual fields. Automated validation handles related-field rules, including distinct listener ports, player capacity versus connection capacity, and enough automatic-release time for a full pose unwind.

## Shared category map

The approved shared categories are Input and phone controls, UI and presentation, Audio and haptics, Accessibility, Networking and session behavior, Camera, and Browser/platform behavior. Only Networking currently has shared Godot values, so empty placeholder Resources are not created. Add a category asset when a concrete implemented value needs it.

Browser fetch timeout (5 seconds), WebSocket deadline (about 7 seconds), and retry delay (2 seconds) remain platform-local in `web/src/app.ts`. They are browser transport/presentation behavior and no current host rule needs them synchronized. `Active Presets.tres` therefore does not send a tuning payload to phones.

## Adding a tunable value

1. Decide whether the value belongs to a minigame umbrella or a genuinely reusable shared category. Do not expose algorithmic constants without a concrete human tuning need.
2. Add a typed exported property to the owning Resource. Include a plain label, units, default, safe range, purpose, higher/lower outcome, and individual clamp where Godot supports it.
   Write it as three consecutive parts: the `##` description, the export annotation on its own line, then the `var` declaration. Use `@export_group` for section headings; `@export_category` can make Godot resolve later tooltips against the wrong documentation category.
3. Replace the implementation constant with the selected Resource value without changing the default behavior.
4. Add related-field rules to `validation_errors()` and extend `tests/tuning_presets_test.gd` with valid, clamped-invalid, and invalid-combination coverage.
5. Add the value explicitly to every committed named preset, run the preset validator, and update this guide if navigation or ownership changed.
6. Copy the experiment template, change one logical group under one hypothesis, relaunch, and keep automated/editor/browser/human evidence separate. Only the project owner may promote a candidate into `Default` or approve its feel.

Run `godot --headless --path . --script res://tests/tuning_presets_test.gd` from the project root to validate every committed preset. Passing is configuration-safety evidence only.
