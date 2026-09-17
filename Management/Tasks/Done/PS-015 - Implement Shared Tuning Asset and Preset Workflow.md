---
id: PS-015
title: Implement shared tuning asset and preset workflow
type: implementation
status: done
release:
owner: ai
priority:
depends_on:
  - "[[PS-004 - Define the Game-Feel Tuning Strategy]]"
---

# Goal

Implement the smallest reusable foundation for PS-004's editor-first tuning workflow so a human can find, edit, validate, compare, and reset designer-facing values without reading gameplay implementation code.

# Scope

- Create the agreed `Tuning/` organization with shared categories, minigame umbrella presets, a project-level `Active Presets` selector, a tuning guide/index, and an experiment-note template.
- Define typed Godot `Resource` data with human-facing Inspector labels, explicit units, useful descriptions, defaults, safe ranges, and individual-value clamping or prevention where the engine supports it.
- Create a Simon Says umbrella tuning profile that can own the Milestone 1 gameplay/timing, animation/motion, visual feedback, audio/haptics, and phone-controller values that are actually present in the implementation at the time of this task.
- Migrate the current relevant host, animation, pose-charge, and browser values without silently changing their provisional behavior. Keep platform-specific browser values local unless a specific shared behavior requires synchronization.
- Add automated validation for every committed preset, including cross-field invariants and invalid-value cases. A subjective feel judgment must remain separate from these checks.
- Make selecting a named preset through `Active Presets` and returning to `Default` deterministic after relaunch; do not add a runtime tuning UI.
- Document how future agents add a tunable value, add or update its validation, expose it to the human, and record the experiment.

# Non-Goals

- Choosing final game-feel values or declaring a preset subjectively successful.
- Building live runtime editing, side-by-side in-game preset comparison, or a general-purpose debug console.
- Centralizing every implementation constant or forcing all host and browser values into one synchronized payload.
- Rewriting gameplay, networking, animation, audio, or browser architecture beyond the narrow wiring needed to consume the new configuration.
- Adding future categories or migration work without a concrete current value that belongs there.

# Acceptance Criteria

- A new Godot user can locate the tuning guide, the active-preset selector, the Simon Says umbrella profile, and the shared category profiles without searching through gameplay scripts.
- The human can open a preset in the Inspector and understand each exposed value from its label, unit, description, default, safe range, and higher/lower outcome guidance.
- Individual invalid values are prevented or clamped, and invalid combinations fail focused automated validation with an actionable message.
- Every committed preset is included in automated validation; no preset is silently exempt because it is not currently active.
- The known-good `Default` preset is easy to restore, while named variants remain reproducible and version-controlled.
- Current migrated behavior remains unchanged unless a deliberate, documented defect fix is required.
- The experiment template records the preset, hypothesis, logical value group, conditions, observations, and human decision separately from the assets.
- The implementation documents which browser values remain platform-local and which, if any, are sourced from a shared configuration.
- Automated results, Godot/editor results, browser results, and human feel approval are reported as separate evidence.

# Game Feel / Player Experience

The workflow must make it practical for a Unity-experienced but Godot-new designer to compare feel changes through named presets and relaunches. The system should explain what values do and protect against malformed configurations without pretending that passing tests proves responsiveness, fairness, readability, or fun.

# Open Questions

- Which exact current values belong in the first Simon Says profile once PS-012 and PS-013 add their production systems?
- Does the first Resource/Inspector workflow need a focused editor helper after real use exposes navigation or validation friction?
- Which cross-platform values demonstrate a real need for host-to-browser synchronization rather than separate platform-local configuration?

# Notes / Findings

This task implements the approved strategy in [[PS-004 - Define the Game-Feel Tuning Strategy]]. The human owns feel decisions and promotion of presets to `Default`; agents own the mechanical migration, validation, documentation, and candidate-preset preparation.

# Draft Execution Prompt

Read [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[PS-004 - Define the Game-Feel Tuning Strategy]], [[Project Overview]], [[Decision Log]], [[DEVELOPMENT]], and the current Godot/web implementation before changing anything. Inspect the existing host settings resource, character animation/pose-charge values, browser timing constants, scene wiring, test conventions, and current worktree. Implement only the shared tuning foundation and the narrow migration of existing relevant values. Use Godot Resources and Inspector metadata where they satisfy the approved workflow; do not invent a runtime tuning UI or centralize unrelated constants. Preserve current provisional defaults and host-authoritative boundaries. Validate every committed preset and invalid combination with focused automated tests, run the proportional Godot/editor/browser checks, and report automated, editor/runtime, browser, and human-feel evidence separately. Update [[DEVELOPMENT]] and the tuning guide with exact locations, reset instructions, preset naming, and caveats. Do not mark a preset as human-approved or promote it to `Default` without explicit owner approval. Follow GitHub Flow and open a pull request for review.

# Outcome

2026-09-14: **done, with subjective feel intentionally unapproved**. Added the
project-level `Tuning/Active Presets.tres` selector, Simon Says and Networking
`Default` Resources, Inspector ranges/tooltips and individual clamping, recursive
validation for every committed preset, invalid-combination tests, the tuning
guide, and the experiment template. The host and animation lab consume the
selected assets after relaunch with their prior provisional defaults unchanged.
Browser-only fetch, connection-deadline, and retry values remain local because
no synchronized host behavior currently requires them.

Automated tuning/regression and browser-host integration suites pass, as does a
normal-profile headless editor load. The current Computer connection exposed no
native Godot window, so no live Inspector walkthrough is claimed. Physical-phone,
exported-build, and human feel/readability/fun approval remain separate evidence;
only the owner may promote a candidate into `Default`.

2026-09-15 correction: all current Simon Says, Networking, and Active Presets
fields keep their `##` documentation immediately above a standalone export
annotation and use `@export_group` sections. `@export_category` changed the
Inspector documentation context and left the properties showing
`No description available`. Regression coverage enforces both tooltip rules.
