---
id: PS-028
title: "Validate Flash? Pose! technical loop"
type: validation
status: backlog
release:
owner: ai
priority:
depends_on:
  - "[[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]]"
  - "[[PS-005 - Define Multi-Phone and Agent Validation Strategy]]"
  - "[[PS-027 - Integrate Flash Pose Lobby and Debug Flow]]"
---

# Goal

Collect reproducible technical evidence that the implemented Flash? Pose!
loop works across host rules, protocol, Godot scenes, the desktop browser, and
the available debug path before asking the owner to perform physical-phone and
human-play review.

# Scope

- Run the focused pose-charge, round-controller, protocol, tuning, scene,
  launcher, and foundation checks created by PS-013 and PS-023 through PS-027.
- Exercise a deterministic two-player host loop, including countdown, at
  least one genuine stop, a correct and failed result, life loss/elimination,
  exactly one flash after resolution, music resume after flash completion,
  results, host return, and lobby re-entry.
- Exercise the one-player debug path through F12 without creating simulated
  players, and confirm normal lobby start still requires two registered
  players.
- Run the bundled browser build/check/test suite and a desktop-browser pass
  for the phone states. Include a scripted or integration matrix up to ten
  connected players where the implementation exposes that capability.
- Run a normal-profile Godot editor-load check and relevant Compatibility
  renderer/runtime captures. If an export preset exists, run the appropriate
  exported-build check; otherwise record `[EXPORTED-BUILD]` as not run rather
  than implying editor evidence proves export behavior.
- Record environment, revision, exact steps, results, artifacts, and caveats
  with the labels from PS-005. Do not perform or claim the physical-phone or
  subjective human-play gate.

# Non-Goals

- Fixing unrelated failures, changing final feel values, or replacing
  implementation tasks with a broad test harness.
- Treating a desktop viewport as an iPhone/Android test or automated results as
  proof of touch, accessibility, fairness, readability, audio quality, or fun.
- Creating a device farm, network emulator, CI system, or performance platform
  not justified by this first proof.

# Acceptance Criteria

- Focused automated rules and protocol checks pass, including late/duplicate
  input protection, lives/elimination, ranking, flash ordering, and the
  no-flash fake-stop contract.
- Godot editor/load and host runtime evidence shows the real scene loop and
  debug/lobby transitions without new script/resource errors.
- Desktop browser build/check/integration evidence shows the bundled phone
  states and the two-to-four input control path; simulated coverage up to ten
  clients is recorded where supported.
- Evidence clearly separates `[AUTO]`, `[EDITOR]`, `[GODOT-RUNTIME]`,
  `[DESKTOP-BROWSER]`, and optional `[EXPORTED-BUILD]`, with failed or not-run
  required checks recorded as blockers or follow-ups.
- A concise validation record points to logs/captures under ignored
  `test-results/` paths and explicitly hands the physical/human gate to PS-029.
- No human-play, physical-phone, or final feel approval is claimed by this
  task.

# Game Feel / Player Experience

Technical evidence should prove that the intended beats are in the right order
and that no hidden timing or stale state makes the experience impossible to
review. It cannot prove that the grace period is fair, the flash is pleasant,
or the phone remains usable while attention is on the shared screen.

# Open Questions

- Any reproducible technical failure should become a focused bug or validation
  follow-up, while a missing physical device remains PS-029's owner gate.

# Notes / Findings

PS-005 defines the routine evidence labels and the minimum two-phone matrix.
This task is intentionally agent-run and technical; it should be completed
before the owner is asked to judge real-device interaction or game feel.

# Draft Execution Prompt

Read this task, [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[PS-013 - Implement Pose Charge and Evaluation Rules]], [[PS-023 - Prepare Flash Pose Runtime Music and SFX]], [[PS-024 - Implement Flash Pose Host Round Controller]], [[PS-025 - Implement Flash Pose Phone Protocol and Controller]], [[PS-026 - Implement Flash Pose Shared Screen Feedback and Results]], [[PS-027 - Integrate Flash Pose Lobby and Debug Flow]], [[Project Overview]], and
[[DEVELOPMENT]]. Inspect the current tests and artifacts before running them.
Collect proportional automated, Godot/editor, host-runtime, desktop-browser,
and available export evidence for the complete first loop. Keep failures
honest, preserve the current project, use ignored test-result paths, and do not
claim physical-phone or human-play approval. Update the validation record and
development notes with exact environments and caveats.

# Outcome
