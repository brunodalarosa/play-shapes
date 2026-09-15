---
id: PS-004
title: Define the game-feel tuning strategy
type: design
status: done
release:
owner: shared
priority:
depends_on: []
---

# Goal

Define a consistent, designer-friendly approach for exposing and explaining values that affect how Play Shapes feels, before gameplay systems establish incompatible tuning patterns.

# Scope

- Identify categories of feel values likely to recur across host gameplay, camera, animation, UI, audio, haptics, and phone controls.
- Investigate the most appropriate Godot- and web-facing exposure mechanisms for this project.
- Define naming, grouping, defaults, safe ranges, units, ownership, and documentation expectations.
- Define how agents identify new feel parameters and report how the human can tune them.
- Define a lightweight experimental loop for comparing values and recording findings.

# Non-Goals

- Choosing final values for a minigame that has not been designed.
- Building editor tools, resources, settings screens, or runtime debug menus.
- Centralizing every constant regardless of whether it affects player experience.
- Mandating one storage mechanism before project-specific evidence is reviewed.

# Acceptance Criteria

- The strategy states which kinds of values qualify as game-feel controls.
- Recommended exposure mechanisms and their tradeoffs are explained for an experienced programmer who is new to Godot.
- The human can tell where to find, change, reset, and compare relevant values without reading underlying logic.
- Guidance covers bounds, units, defaults, presets/versioning, and preventing invalid combinations.
- Future implementation tasks have a short checklist for documenting tunables and their validation experiments.
- Unresolved tooling needs become separate bounded tasks.

# Game Feel / Player Experience

This task governs input thresholds, dead zones, sensitivity, acceleration, speed, friction, drag, jump timing, buffering, coyote time, cooldowns, animation/transition timing, camera effects, particles, UI timing, feedback delays, SFX relationships, haptics, color feedback, hit-stop, slow motion, and similar responsiveness constants.

# Open Questions

The strategy is approved; these are intentionally deferred to the implementation follow-up [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]]:

- What exact Godot `Resource` nesting and inspector metadata shape best implements the umbrella assets without making them cumbersome to edit?
- Which existing host and browser values genuinely need a shared source in the first migration, rather than remaining platform-specific?
- Does the editor-first Resource workflow provide enough navigation and validation, or does evidence justify a focused editor helper later?

# Notes / Findings

## Confirmed workflow

- The human accepts stopping and relaunching between tuning runs. The first strategy does not require a runtime tuning overlay or live value editing.
- Tuning must be accessible without understanding implementation code. An agent must expose a value in the approved tuning location and explain it there before treating the value as designer-accessible.
- Technical settings and game-feel settings may share the system when their labels and categories make the distinction clear.

## Recommended organization

Use a `Tuning/` root with a small, predictable navigation layer:

- `Tuning/Minigames/<minigame>/` contains one umbrella asset shape for that minigame. Each named preset is an instance of the same umbrella shape, with sections for gameplay/difficulty, timing/input, animation/motion, visual feedback, audio/haptics, and phone-controller behavior as applicable. Minigame-specific values should not be split into separate subsystem files merely for technical neatness.
- `Tuning/Shared/<category>/` contains reusable values grouped by concern. The initial category map is Input and phone controls, UI and presentation, Audio and haptics, Accessibility, Networking and session behavior, Camera, and Browser/platform behavior. The category map may grow when real systems justify it.
- A project-level `Active Presets` asset selects the named preset for each minigame and shared category. This is the one obvious place to see which variants are active; switching it requires an editor change and a relaunch.
- `Tuning/Experiments/` contains one Markdown note per tuning experiment. A project-level tuning guide/index explains the folder layout, reset workflow, preset naming, and how to find the relevant asset.

The organization is deliberately a family of focused assets, not one monolithic project-wide tuning file. A minigame has one front door even when its values affect several systems; genuinely reusable values have their own shared category.

## Tunable field contract

Every exposed field must be understandable in the Inspector and in the Markdown guide without reading implementation logic. It should provide:

- a plain-language label and explicit unit, such as `Pose grace window (seconds)` or `Controller sensitivity`;
- a stable technical identifier for tests, documentation, and agent communication;
- a purpose statement and a concrete example of the player-facing result;
- the default value and recommended/safe range;
- what increasing and decreasing the value generally feels like;
- invalid-value rules, including whether a value is a duration, percentage, count, or other constrained type;
- relationships with other fields when a combination can be invalid;
- the owning category/system and the experiment or validation note that should evaluate it.

Inspector constraints should prevent or clamp clearly invalid individual values. Cross-field invariants should be checked by automated validation rather than relying on prose alone.

Expose values when a human may reasonably tune them for player feel, accessibility, balance/difficulty, presentation/feedback, or operational behavior. Keep algorithmic implementation details such as random seeds, protocol identifiers, cache sizes, and internal clocks private unless a concrete human tuning need appears.

## Presets, validation, and ownership

- Each minigame and shared category has a known-good `Default` preset. It is the recovery point and is not casually edited.
- Experiments copy a baseline into a clearly named preset such as `Generous`, `Strict`, or `Experimental_YYYY-MM-DD`. Presets are committed assets, not informal copies that exist only in Git history.
- Every committed preset must pass automated validation. A preset may produce a poor subjective result, but it may not contain invalid values or invalid combinations. A failing unit test is sufficient evidence that the preset is not structurally usable.
- Automated tests prove safety and consistency, not whether the game feels good. Human playtesting remains the authority for feel, readability, fairness, and emotional response.
- Agents may create candidate presets, update experiment notes, run checks, and recommend changes. Only the human may promote a preset to `Default`, approve a feel decision, or declare an experiment successful.

## Lightweight experiment loop

1. Start from a known-good preset and create a named candidate.
2. Write one hypothesis and change one logical group of related values; do not mix unrelated changes.
3. Select the candidate in `Active Presets`, relaunch, and play the relevant scene or minigame.
4. Compare against the baseline under recorded conditions rather than trusting isolated numbers.
5. Add a separate note under `Tuning/Experiments/` containing the date, minigame/category, preset, exact changes, player/device conditions, observations, and a keep/reject/investigate decision.
6. Keep the candidate, revise it, or promote it only after human approval.

## Cross-platform rule

Use one shared source only when the host and browser genuinely need the same value or synchronized behavior. Keep browser-only presentation, retry, and interaction details in the Browser/platform category. Keep host-only settings in Networking/session. The shared tuning system does not require every platform to consume one universal configuration payload.

This preserves the host-authoritative architecture and avoids coupling the Godot runtime to browser implementation details merely for organizational symmetry.

## Rejected or deferred approaches

- A single project-wide tuning asset was rejected because it would become crowded and make minigame ownership unclear.
- Runtime editing and side-by-side live presets were deferred; relaunch-based comparison is sufficient for the first milestone.
- Relying on Git history alone for experiments was rejected because a named, selectable preset is easier to reproduce.
- Exposing every constant was rejected because implementation noise would undermine accessibility.
- Exact Resource schemas, active-preset loading, and the first migration of existing host/animation/browser values belong in [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]].

# Draft Execution Prompt

Read [[PS-004 - Define the Game-Feel Tuning Strategy]], [[Project Overview]], [[Decision Log]], [[DEVELOPMENT]], and the current Godot/web project structure. Investigate project-appropriate designer-facing tuning patterns and facilitate decisions with the human. Produce concise conventions and an experimental checklist, clearly separating recommended choices from unresolved questions. Do not implement resources, tools, configuration, or gameplay changes.

# Outcome

2026-09-14: **done and approved**. The human project owner approved an editor-first shared tuning system with one umbrella asset per minigame, shared category assets, a project-level active-preset selector, protected known-good defaults, named experiment presets, Inspector plus Markdown guidance, automated validation for every committed preset, and separate experiment notes. Human playtesting remains the authority for subjective feel, while agents may prepare candidates but may not promote defaults or approve feel decisions.

Implementation was deliberately not included in this design session. The bounded follow-up is [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]].
