---
id: PS-010
title: Explore character animation strategy
type: design
status: backlog
release: Milestone 1
owner: shared
priority:
depends_on:
  - PS-009
---

# Goal

Define an implementation-ready animation strategy for Milestone 1's Dancer Simon Says characters, determining through focused investigation and a future interview with the human project owner whether detached-sprite animation, skeletal rigging, or another Godot approach best supports expressive floating hands, feet, and jiggling geometric bodies.

# Scope

- Begin with a focused question session that helps the human describe the desired motion, art flexibility, authoring comfort, iteration needs, and acceptable production cost; do not assume prior rigging knowledge.
- Inspect the imported Shape Characters setup and the canonical minigame design in [[001 - Dancer simon says]].
- Identify the minimum animation vocabulary Milestone 1 needs, including automatic dancing, the approved directional Simon Says poses, transitions, idle/countdown/result reactions, failures, and elimination feedback where relevant.
- Compare viable Godot 2D approaches such as independently transformed sprite parts with `AnimationPlayer`, bone-based cutout animation, procedural/tweened motion, or a deliberate hybrid.
- Explain each approach in plain language, including what "rigging" would mean for these detached body parts and whether it provides meaningful value for this game's needs.
- Evaluate authoring workflow, pose reuse, transitions, mirroring, pivot placement, draw order, body squash/stretch or jiggle, tint/material compatibility, runtime cost for up to 10 player characters plus a lead dancer, and maintainability by human and AI contributors.
- Determine how gameplay state should request semantic actions such as dance or pose without coupling authoritative rules to animation implementation details.
- Define how lead-dancer and player-character animation can share clips or pose data while still allowing clear role-specific emphasis.
- Consider how the included background-level art supports readable silhouettes and motion staging. Milestone 1 does not require 2D collisions.
- Recommend one strategy, record rejected alternatives and tradeoffs, and split any proof-of-concept or production work into separate bounded follow-up tasks.

# Non-Goals

- Implementing a rig, animation controller, production animation clips, gameplay logic, or background scenes.
- Creating or editing the missing foot art covered by [[PS-009 - Create and Import Character Feet Assets]].
- Requiring the human to choose technical terminology or a tool before seeing plain-language options.
- Designing animation systems for every future minigame.
- Adding 2D collisions, physics simulation, procedural ragdolls, inverse kinematics, or platforming movement unless investigation finds a concrete Milestone 1 need and the human explicitly approves it.
- Selecting final timings, amplitudes, easing curves, or other feel values without later visual experimentation and playtesting.

# Acceptance Criteria

- The future agent conducts and records a focused interview with the human before finalizing the recommendation.
- The human receives a plain-language explanation of whether rigging is useful, optional, or unnecessary for this specific detached-part art style.
- The required Milestone 1 animation and pose vocabulary is bounded and documented, including what may be reused between the lead dancer and player characters.
- At least two credible Godot animation approaches are compared using project-specific advantages, disadvantages, authoring workflow, and maintenance cost.
- The recommendation states the intended scene/node responsibilities, asset pivots and hierarchy, animation data ownership, transition model, mirroring and draw-order rules, tint interaction, and boundary with authoritative gameplay.
- The strategy accounts for up to 10 simultaneous player characters plus the lead dancer and identifies any performance claim that still needs measurement.
- The strategy explains how body jiggle/squash/stretch and the larger hand/foot motion combine without making poses hard to read on the shared screen.
- Background use and contrast requirements are documented without adding collision scope.
- Uncertainties that need visual proof become explicit, small prototype tasks with success criteria rather than being silently resolved in the design document.
- The human project owner approves or revises the recommendation before a production animation implementation task is made ready.

# Game Feel / Player Experience

The animation must feel playful, loose, and musical while keeping every Simon Says pose immediately recognizable. Detached hands and feet should provide the largest motion; the body should contribute bounce, rotation, squash/stretch, or jiggle without obscuring the directional cue. Transitions need to feel responsive at a music stop, and simultaneous player characters must stay readable against the level art. Exact timing and motion values should remain designer-accessible and be discovered through visual experiments under the conventions from [[PS-004 - Define the Game-Feel Tuning Strategy]].

# Open Questions

- Which exact dance poses and non-gameplay reactions are essential for the first playable milestone?
- Should the lead dancer exaggerate the same pose data used by players or use separately authored clips?
- Does the human want to author and adjust poses primarily in the Godot editor, through reusable data, or by asking agents to edit them?
- How much procedural variation is desirable before repeated dances stop feeling predictable, and how much randomness would hurt cue readability?
- Are sprite-part transforms sufficient, or do bones materially improve pivot control, reuse, secondary motion, and editing speed for this asset structure?
- Should left/right limbs share mirrored art and motion, or do asymmetrical poses justify separate assets or animation data?
- What minimum visual prototype would let the human compare the leading approaches fairly?

# Notes / Findings

Milestone 1 uses the Shape Characters for the lead dancer and player characters and uses the included environment art for its background levels. Character motion centers on detached floating hands and newly added feet, with secondary body motion. No 2D collisions are required for this milestone. This task deliberately preserves the rigging decision until the human has been interviewed and the actual imported asset setup has been inspected.

# Draft Execution Prompt

Read [[PS-010 - Explore Character Animation Strategy]] first and treat it as the source of truth. Then read [[001 - Dancer simon says]], [[PS-001 - Define the First Gameplay Milestone]], the completed [[PS-009 - Create and Import Character Feet Assets]], [[PS-004 - Define the Game-Feel Tuning Strategy]] if completed, [[Project Overview]], [[Decision Log]], and [[DEVELOPMENT]]. Inspect the imported character assembly and relevant background assets without modifying them. Start by interviewing the human project owner in plain language about desired dance motion, pose readability, reuse, variation, authoring workflow, and production constraints. Ask focused follow-ups and explain unfamiliar animation or rigging concepts with concrete project-specific examples; this is the intended "grill me" stage, so do not finalize the strategy before the human has answered. Then compare the smallest credible Godot approaches, recommend one with explicit tradeoffs and architecture boundaries, and define any narrowly scoped visual prototypes needed to resolve remaining uncertainty. Do not implement the rig, animations, gameplay, backgrounds, or collisions. Record approved decisions, unresolved questions, rejected alternatives, and proposed follow-up tasks. Keep numeric feel values open for later experimentation unless the human explicitly approves them.

# Outcome
