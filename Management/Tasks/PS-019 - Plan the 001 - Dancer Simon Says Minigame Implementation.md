---
id: PS-019
title: Plan the 001 - Dancer Simon Says minigame implementation
type: design
status: backlog
release:
owner: shared
priority:
depends_on: []
---

# Goal

Turn the approved Dancer Simon Says concept, wireframe, selected assets, and
existing project foundations into an implementation-ready plan that exposes
remaining decisions and creates the bounded implementation task set needed to
build the minigame.

# Scope

- Define the minigame state flow from lobby entry through countdown, dancing,
  stop/pose evaluation, life loss and elimination, round end, results, and
  return to lobby, while preserving the Milestone 1 exclusions.
- Assign responsibility across host-authoritative rules, player registry,
  browser controller, shared-screen scene, character animation, audio, and
  debug launcher boundaries.
- Define the messages, data, timing ownership, and failure handling needed for
  phone input and authoritative outcomes without letting clients decide state.
- Map player-facing and game-feel tunables to the approved editor-first tuning
  workflow, including what remains provisional until human playtesting.
- Cover accessibility, shared-screen readability, phone attention, content and
  audio requirements, debug entry, validation evidence, and human approval
  checkpoints.
- Break the remaining work into small implementation and validation tasks,
  keeping [[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]] as the
  scene-composition task rather than absorbing it into a broad feature task.

# Non-Goals

- Implementing gameplay, networking, scenes, assets, audio, or browser UI.
- Reopening approved animation, identity, tuning, or Milestone 1 decisions
  without new evidence.
- Adding the cross-minigame scoreboard, session sequencing, fake music stops,
  or a larger ranking system.
- Choosing final numeric feel values without human playtesting.

# Acceptance Criteria

- A single implementation plan describes the state machine or equivalent
  lifecycle, ownership boundaries, scene responsibilities, and integration
  sequence for the minigame.
- The plan links the approved canonical design and relevant existing tasks,
  decisions, scenes, tuning assets, and validation strategy.
- Every currently known unresolved behavior is either answered with an
  explicitly justified decision, preserved as a named human decision, or
  converted into a bounded follow-up task with a clear dependency.
- The implementation breakdown has independently reviewable tasks with scopes,
  acceptance criteria, ownership, dependencies, and draft execution prompts.
- The breakdown includes the already requested scene task and identifies any
  additional implementation or validation tasks needed for a complete
  Milestone 1 minigame without hiding work in a vague umbrella task.
- The human project owner approves the plan and task decomposition before the
  implementation sequence is treated as ready.

# Game Feel / Player Experience

The plan must connect architecture to the experience: shared-screen attention,
one-thumb press-and-hold input, readable directional poses, fair grace timing,
playful pressure, meaningful reactions, and an understandable end-of-round
result. Technical completion must not be presented as proof of fun, fairness,
readability, accessibility, or physical-phone usability.

# Open Questions

- Which of the remaining Milestone 1 questions should be resolved before code
  begins, and which are safe to expose as provisional tuning or follow-up work?
- What is the smallest authoritative round controller that integrates PS-006,
  PS-012, and PS-013 without turning the scene into a god object?
- Which browser messages and phone states are needed for the first complete
  player journey, including elimination and return to lobby?
- Which audio and environment assets are required for a playable proof versus a
  later polish pass?
- What exact human/editor/device/runtime checks are required at each milestone
  of the implementation sequence?

# Notes / Findings

The canonical design intentionally leaves production assets, accessibility
details, final tuning, and some results behavior open. This planning task must
surface those boundaries rather than fill them with guesses. It may create
follow-up task notes after the plan is coherent; it must not implement them.

# Draft Execution Prompt

Read [[001 - Dancer simon says]], [[PS-001 - Define the First Gameplay Milestone]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]],
[[PS-006 - Implement Player Join and Host-Owned Registry]], [[PS-007 - Define the Gameplay Debug Suite]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-013 - Implement Pose Charge and Evaluation Rules]],
[[PS-014 - Implement Minimal Gameplay Debug Launcher]], [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[PS-016 - Create Wireframe for 001 - Dancer Simon Says]], [[PS-017 - Find Environment Assets for 001 - Dancer Simon Says]], [[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]], [[Project Overview]], [[Workflow]], [[Decision Log]], [[Releases]], and
[[DEVELOPMENT]]. Inspect the current implementation and scene boundaries. Write
an implementation-ready plan, preserve approved decisions, identify every
remaining assumption, and create only bounded follow-up task records with
explicit ownership and dependencies. Do not implement code or assets, do not
assign priority or release, and keep automated, editor/runtime, device, and
human-play evidence distinct.

# Outcome
