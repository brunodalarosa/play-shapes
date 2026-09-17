---
id: PS-020
title: Find music and SFX for 001 - Dancer Simon Says minigame
type: asset-hunt
status: done
release:
owner: human
priority:
depends_on: []
---

# Goal

Find a coherent set of music and sound-effect candidates for Dancer Simon Says
that supports dancing, the music-stop tension, pose evaluation, elimination,
and results feedback without creating licensing or integration surprises.

# Scope

- Search for loopable music candidates that fit the current playful dance
  direction and can support the music-paired character styles documented in
  [[PS-012 - Implement Milestone 1 Character Animation System]].
- Search for sound effects for the minigame's likely cues, such as countdown or
  start, music stop, pose reveal/evaluation, success or failure, life loss,
  elimination, and results transition. Keep the cue list provisional where
  [[001 - Dancer simon says]] leaves behavior open.
- Record source, creator, license or permission, attribution, file format,
  duration, loop points, sample rate or other relevant technical metadata, and
  any redistribution restrictions for every serious candidate.
- Compare candidates for mood, repetition fatigue, stop/restart behavior,
  shared-room clarity, character-pose readability, and whether the effects can
  be heard without overwhelming speech or player reactions.
- Select a minimal candidate set for human review and identify missing cues,
  rejected candidates, and any future `asset-rework` work needed for trimming,
  looping, normalization, or format conversion.

# Non-Goals

- Implementing an audio manager, music-stop timing, gameplay rules, or Godot
  audio buses.
- Editing, mixing, normalizing, or otherwise treating the source audio; create
  a separate `asset-rework` task if that work is required.
- Using generative audio unless the project owner explicitly requests it.
- Finalizing audio behavior or volume values without human listening and
  gameplay review.
- Completing the task through an agent while `owner: human` remains in place.

# Acceptance Criteria

- Music and SFX candidates are listed with provenance, license, metadata, and
  intended in-game use.
- The candidate music set is loopable or has a documented loop workaround, and
  its stop/restart behavior is suitable for the minigame's tension pattern.
- The candidate SFX set covers the currently expected feedback moments, or each
  uncovered cue is recorded as a named follow-up rather than hidden.
- The set preserves pose readability and does not rely on audio alone for cues
  that need an accessibility alternative.
- Candidates are available as reviewable files, links, or previews without
  committing unlicensed or provenance-unclear material to the runtime project.
- The project owner explicitly approves the selected candidates, or the task
  records a named blocker and the missing decision.

# Game Feel / Player Experience

Music should make the automatic dance feel energetic and inviting, then make a
stop feel sudden but fair. Effects should clarify what happened without turning
the shared screen into a noisy warning system. Repetition, volume, silence,
and cue redundancy matter because players will be listening in a shared room
while watching the lead dancer and holding a phone.

# Open Questions

- Should the first playable proof use three distinct music tracks, one track
  with variations, or a smaller temporary set?
- How abrupt or stylized should the music stop be, and does it need a separate
  stop sting or silence cue?
- Which feedback moments need an SFX in the first implementation versus a
  visual or animation-only treatment?
- What loudness and dynamic-range target keeps cues audible without making the
  music fatiguing during repeated rounds?
- Which non-audio cues should accompany stop, evaluation, failure, and
  elimination for accessibility?

# Notes / Findings

This is intentionally a human-only sourcing task for now. It selects and
documents candidates; it does not import, edit, mix, or approve final runtime
audio. Any treatment of selected files belongs in a separate `asset-rework`
task, and final use remains subject to human listening and gameplay approval.

# Draft Execution Prompt

Read [[001 - Dancer simon says]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[Project Overview]], [[Decision Log]], and [[DEVELOPMENT]]. Search existing and suitable external sources for loopable music and SFX candidates. Document provenance, license, metadata, loop/stop behavior, intended cue, accessibility caveats, and review previews. Do not implement audio code, edit or normalize files, use generative audio, or silently choose final timing/volume values. Keep this task human-owned and obtain explicit owner approval before treating the selected set as ready for implementation.

# Outcome
