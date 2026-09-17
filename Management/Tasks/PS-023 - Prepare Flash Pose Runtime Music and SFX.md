---
id: PS-023
title: "Prepare Flash? Pose! runtime music and SFX"
type: asset-rework
status: backlog
release:
owner: ai
priority:
depends_on:
  - "[[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]]"
  - "[[PS-020 - Find Music and SFX for 001 - Dancer Simon Says]]"
---

# Goal

Turn the supplied Flash? Pose! music and camera-flash sound candidates into
technically usable, provenance-bearing runtime inputs without silently
choosing new audio or deciding the final mix by code.

# Scope

- Inspect `assets/runtime/bgm/` and `assets/runtime/sfxs/`, currently including
  the three music candidates and `flash_1.ogg`/`flash_2.ogg`, before editing.
- Record creator/source, license or permission, format, duration, sample rate,
  loop points or loop behavior, intended cue, and any redistribution caveat in
  the project-accessible audio/provenance notes.
- Preserve the supplied source files and provenance. If treatment, trimming,
  conversion, or normalization is needed, create a clearly named derived
  runtime file and keep the original candidate recoverable.
- Configure Godot import and looping metadata so the three music/style pairs
  and flash SFX load deterministically. Do not add a new audio manager here.
- Define the stable mapping used later by the presentation task: `bounce` to
  Bouncing music, `swing` to Swinging music, and `disco` to Wacky music. Flash
  SFX selection may be deterministic or seeded, but must not be triggered by a
  future fake music stop.
- Add a focused resource/load or metadata check where practical and document
  the exact path the gameplay implementation should consume.

# Non-Goals

- Designing or implementing the round loop, music-stop timing, pose rules,
  browser controller, audio buses, or camera-flash VFX.
- Designing or implementing fake music stops.
- Sourcing new external or generative audio, or replacing a candidate without
  human approval.
- Declaring final loudness, mix, fairness, or feel successful without the
  human listening and gameplay review in [[PS-029 - Validate Flash Pose on Two Phones and in Human Play]].

# Acceptance Criteria

- Every consumed file has recorded provenance, permission/license status,
  format, duration, and intended use; unknown metadata is a named blocker,
  not an invented value.
- Music loop/stop behavior is technically documented and verified in Godot or
  through a focused asset check. The three style mappings are unambiguous.
- Flash SFX candidates load from project paths and remain separate from the
  future fake-stop design.
- Any derived asset is reproducible or clearly documented, while the original
  candidate remains recoverable.
- No gameplay, protocol, or fake-stop code is added, and no subjective audio
  approval is claimed. Human listening remains a required later gate.
- `DEVELOPMENT.md` records the paths, import caveats, provenance boundary, and
  validation evidence separately from human listening evidence.

# Game Feel / Player Experience

The chosen music should support the three recognizable animation styles, stop
cleanly enough for the pose to read, and return without an accidental click or
rhythmic stumble. The flash sound should punctuate the resolved snapshot
without overpowering speech or teaching players that a fake stop is real.

# Open Questions

- The first proof uses exact-position pause/resume. If loop metadata is
  incomplete, record the technical caveat and keep any restart-point change as
  a focused follow-up rather than changing the approved first-proof behavior.
- Which of the two flash candidates best survives repeated genuine stops? The
  implementation may keep both as named candidates until the owner listens.

# Notes / Findings

PS-020 is marked done and the current checkout already contains the candidate
files, but its task note has no outcome metadata. This task closes the
technical provenance/import gap without rewriting the human-owned sourcing
decision. Final candidate approval remains human-owned.

# Draft Execution Prompt

Read this task, [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[PS-020 - Find Music and SFX for 001 - Dancer Simon Says]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[Project Overview]], [[Decision Log]], and [[DEVELOPMENT]]. Inspect the supplied runtime audio and
its history before editing. Preserve source files, document provenance and
technical metadata, apply only reproducible treatment that is necessary for
runtime use, and verify Godot import/loop behavior. Do not source new audio,
implement gameplay or fake stops, or claim human listening approval. Update
the development notes with exact paths and separate technical from human
evidence.

# Outcome
