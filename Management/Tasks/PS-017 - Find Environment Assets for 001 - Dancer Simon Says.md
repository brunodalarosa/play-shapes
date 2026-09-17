---
id: PS-017
title: Find scenario and environment assets for 001 - Dancer Simon Says minigame
type: asset-hunt
status: backlog
release:
owner: human
priority:
depends_on: []
---

# Goal

Find and select the scenario and environment visuals that establish the
playful shared-screen setting for Dancer Simon Says and can be used by the
scene implementation without style, license, or readability surprises.

# Scope

- Search the existing project assets and suitable external sources for a
  background, floor/stage, framing elements, and small decorative pieces that
  support the wireframe.
- Record the source, license or permission, provenance, resolution, aspect
  ratio, and any import or attribution requirements for each candidate.
- Compare candidates against the existing Shape Characters style, character
  silhouettes, shared-screen readability, and the intended playful tone.
- Select a minimal coherent set for the first scene and identify explicit
  rejects or deferred gaps rather than silently substituting unrelated art.
- Produce reviewable references or previews that let the project owner approve
  the selected environment before implementation consumes it.

# Non-Goals

- Creating new production artwork, editing assets, or using generative image
  creation.
- Hunting for character, animation, music, sound-effect, or phone-controller
  assets unless a candidate is inseparable from the environment set.
- Importing or wiring the selected assets into Godot; that belongs to the
  implementation task.
- Completing the task through an agent while `owner: human` remains in place.

# Acceptance Criteria

- Candidates and the selected set are listed with source, license/provenance,
  dimensions or resolution, and intended use.
- The selected set contains enough environment material to realize the
  approved wireframe without requiring an untracked placeholder.
- The selected assets preserve character contrast and pose readability at the
  intended shared-screen distance.
- Any attribution, redistribution, conversion, or import caveat is recorded in
  a project-accessible note before implementation begins.
- The project owner explicitly approves the selected environment set, or the
  task records a named blocker and the missing decision.

# Game Feel / Player Experience

Environment art should frame the dancers and make the stop-and-copy moment
feel like a playful stage performance. It must not compete with the lead pose,
make small player characters disappear, or rely on background detail that is
only readable up close.

# Open Questions

- Should the first scene use one static stage or a small set of interchangeable
  background layers?
- Does the environment need a distinct visual stop cue, or should that remain
  owned by the lead dancer and gameplay feedback?
- Which external licenses are acceptable for committed runtime assets and their
  source files?
- Are any current Kenney environment pieces close enough to preserve a single
  visual language, or is a new source necessary?

# Notes / Findings

This is intentionally a human-only sourcing task for now. It is a selection
and provenance task, not an asset rework task. If an existing asset later needs
treatment, create or link a separate `asset-rework` task rather than hiding the
work in this hunt.

# Draft Execution Prompt

Read [[PS-016 - Create Wireframe for 001 - Dancer Simon Says]], [[001 - Dancer simon says]],
[[PS-009 - Create and Import Character Feet Assets]], [[Project Overview]], and the asset/licensing notes in [[DEVELOPMENT]]. Inspect the
existing environment material and candidate sources, then collect a minimal
coherent stage set with provenance, license, dimensions, import caveats, and
review previews. Use human/computer browsing and existing source material; do
not use generative image creation or edit assets in this task. Obtain explicit
human approval before treating the selected set as ready for [[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]].

# Outcome
