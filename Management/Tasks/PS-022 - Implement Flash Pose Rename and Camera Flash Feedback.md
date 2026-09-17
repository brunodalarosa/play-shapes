---
id: PS-022
title: "Implement Flash? Pose! rename and camera-flash feedback"
type: implementation
status: backlog
release:
owner: ai
priority:
depends_on:
  - PS-013
  - PS-018
  - PS-019
  - PS-020
---

# Goal

Rebrand minigame `001` from Dancer Simon Says to the exact player-facing name
**Flash? Pose!**, then carry the new theme through its definitions, existing
code-facing front doors, and runtime feedback. At the end of a genuine pose
evaluation grace period, resolve the authoritative result, play a short camera-
flash SFX and shared-screen VFX, and resume the music only after the flash. A
future fake music stop must never emit this flash.

# Scope

- Inventory the parent Play Shapes vault and the nested Godot repository for
  current `Dancer Simon Says`, `Simon Says`, `simon_says`, and related minigame
  labels before editing. Classify player-facing copy, stable IDs, code symbols,
  resource paths, task filenames, historical records, and compatibility data
  instead of applying an unreviewed global replacement.
- Update the canonical `001` definition in the parent vault, the minigame
  index, the Milestone 1 release definition, the relevant decision record,
  `DEVELOPMENT.md`, tuning guidance, and active task notes so the current
  player-facing name is consistently **Flash? Pose!**. Keep the numeric `001`
  identity and stable PS task IDs. A remaining old-name reference is allowed
  only when it is an intentional historical note or documented compatibility
  alias.
- Keep the canonical Markdown filename and existing Obsidian link identity
  stable unless the current tooling proves a safe migration. In particular, do
  not put `?` in a Windows filename; use the exact punctuation in headings,
  labels, and player-facing strings while using a filesystem-safe code form such
  as `flash_pose` for internal identifiers.
- Update existing code assets and references where the old name is a public
  minigame front door: tuning script/class and preset path, active-preset field,
  serialized resource references, debug scenario labels/IDs, runtime scene or
  controller paths when they exist, and focused tests. Rename or migrate rather
  than duplicate assets, repair all references, and preserve a compatibility
  alias only when an actual serialized or network boundary requires it.
- Do not invent a complete minigame scene if the current branch still only has a
  reserved path. Integrate with the scene/controller/orchestration boundary
  that exists after the dependent tasks, or create the smallest clearly named
  flash-feedback component and leave broader round orchestration to its owning
  task.
- Represent the stop source or cue type explicitly enough to distinguish a
  genuine music stop from a future fake stop. The flash trigger must be owned by
  the genuine-stop evaluation lifecycle, not by a generic music pause callback.
- For a genuine stop, implement this observable order:
  1. music is playing and the characters dance;
  2. the genuine stop silences the music and reveals the command pose;
  3. players may correct input during the existing grace period;
  4. the host resolves pose results at the grace deadline;
  5. exactly one camera-flash SFX and shared-screen VFX play after resolution;
  6. the music resumes only after the flash presentation has completed or
     emitted its defined completion signal.
- Make the flash readable as a quick camera capture: a brief bright shared-screen
  treatment with a clean fade/release and a matching SFX. It must not leave the
  screen white, hide lives/results, retrigger from duplicate callbacks, or make
  the lead pose unreadable before evaluation. Use approved/provenance-bearing
  audio or a code-native visual effect; do not silently commit an unlicensed
  downloaded sound.
- Add designer-facing tuning for the flash duration/intensity and any timing or
  audio gain values that materially affect feel. Follow the project's Godot
  Inspector documentation order (`##` description, standalone export annotation,
  then declaration), named preset workflow, safe clamps, and actionable
  cross-field validation. Do not present provisional defaults as final feel.
- Keep fake music stops outside this implementation. Add a focused guard/test or
  event contract proving that a fake-stop source produces no flash when that
  future source is represented, without designing its timing, fairness, or
  player consequences.
- Update the relevant provenance/licensing notes for any new SFX/VFX asset and
  document the authoring path, resource references, timing ownership, and
  remaining human decisions.

# Non-Goals

- Designing or implementing fake music stops, including their stop cue, pose,
  fairness rules, or recovery behavior.
- Replacing the authoritative charge/evaluation rules, scoring, ranking, lives,
  elimination, networking protocol, or complete lobby-to-minigame loop.
- Redesigning the approved detached-sprite character animation architecture,
  canonical poses, dance styles, or player-control layout.
- Choosing final flash brightness, duration, SFX loudness, music mix, or
  accessibility treatment without human runtime/listening review.
- Renaming stable PS task filenames, numeric minigame identity, or historical
  records merely to make a global search result look uniform.
- Adding unrelated assets, broad audio infrastructure, a runtime tuning UI, or
  a cross-minigame scoreboard.

# Acceptance Criteria

- An exhaustive search of the parent vault and nested repository shows that
  current player-facing definitions use **Flash? Pose!**, while any remaining
  Simon Says wording is intentionally historical or documented as a compatibility
  alias. The `001` identity and existing Obsidian/task links remain usable.
- The canonical minigame definition describes the new loop as genuine stop ->
  grace/evaluation -> camera flash SFX/VFX -> music resume, and explicitly says
  fake music stops do not flash. The release, decision, development, tuning, and
  relevant task documents agree with that source of truth.
- Existing code-facing minigame front doors use one filesystem-safe internal
  naming convention, load without broken resource paths, and expose the exact
  player-facing label where a user sees it. No duplicate old/new tuning or scene
  assets remain without a documented compatibility reason.
- A deterministic focused test proves that a genuine stop cannot flash before
  the grace deadline, resolves the pose before the flash, emits one flash per
  stop, and resumes music only after flash completion. Repeated or late callbacks
  do not emit a second flash.
- A deterministic focused test or event-contract check proves that a fake-stop
  source emits no camera-flash SFX or VFX. The test does not require fake-stop
  gameplay to be implemented.
- The SFX and VFX are connected to the actual shared-screen feedback boundary,
  use valid project resources, and remain visible/audible long enough to be
  reviewed without obscuring the pose, player status, or results. Resource
  provenance and licensing are recorded.
- Flash timing, intensity, and other player-facing values are designer-accessible
  through the established tuning preset workflow, with Inspector descriptions,
  safe ranges, defaults, and validation coverage. No material feel value is
  hidden as an unexplained literal in the round controller.
- Relevant automated tests, Godot editor/resource-load checks, and a real
  runtime demonstration pass. Evidence is reported separately as `[AUTO]`,
  `[EDITOR]`, `[GODOT-RUNTIME]`, `[DESKTOP-BROWSER]`, `[PHYSICAL-PHONE]`,
  `[EXPORTED-BUILD]`, or `[HUMAN-PLAY]`; automated checks are not presented as
  proof of visual/audio quality or physical-device behavior.
- `DEVELOPMENT.md` and this task record the final file/scene/resource names,
  event ordering, tuning workflow, provenance, validation commands, unresolved
  caveats, and any compatibility decision. The human owner reviews the flash
  feel and audio before the task is marked done.
- The work is delivered in a focused pull request/commit set with unrelated
  working-tree edits excluded. Parent-vault edits outside the nested Git repo
  are identified separately rather than falsely described as part of the repo
  commit.

# Game Feel / Player Experience

The stop should feel like a playful snapshot: the pose is judged first, then a
quick flash punctuates the captured moment, and the dance track returns cleanly
afterward. The effect should reward the dramatic pause without punishing a
player through an extra hidden timing window. The shared display carries the
main flash; the existing pose, result, and status cues must remain readable.
The flash is a signature of a real stop-and-capture moment, so a fake stop must
not teach players to expect or react to it.

# Open Questions

- Which approved camera/shutter SFX candidate best matches the final music and
  survives repeated rounds without becoming tiring?
- Should the bright treatment be a simple full-screen overlay, a camera-shaped
  aperture/bloom, or another code-native effect that fits the approved stage
  art? The implementation may choose a reversible first pass, but the owner
  must review the result.
- Should music resume immediately when the flash's visible release begins or
  only after the full fade completes, and does the current music system need a
  loop-safe resume point to avoid a click or rhythmic stumble?
- What accessibility-equivalent cue should accompany the flash for players who
  cannot rely on the SFX, and does it belong in this task or a separate UX task?
- Does the existing runtime have a stable event boundary for genuine versus
  fake stops, or should the implementer add a small typed cue-source boundary
  for this effect without implementing fake-stop gameplay?

# Notes / Findings

The canonical minigame document currently lives outside the nested Git
repository at `Play Shapes/Minigames/001/001 - Dancer simon says.md`; the
repository contains the task system, tuning assets, debug catalog, tests, and
development notes that reference it. The implementation agent must inspect and
report this boundary explicitly.

The current Godot tuning front door is
`Tuning/Minigames/simon_says_tuning.gd` with
`Tuning/Minigames/SimonSays/Default.tres`; `Tuning/Active Presets.tres`,
`Tuning/active_presets.gd`, the debug scenario catalog, and tuning tests also
use Simon Says terminology. A reserved debug path may refer to
`res://minigames/dancer_simon_says.tscn` even when that scene is not yet present,
so the agent must verify the current branch instead of assuming it exists.

PS-020 is a human-owned music/SFX sourcing task. The implementation must use
only an approved/provenance-bearing candidate or record a named blocker or
follow-up; it must not silently select final audio. PS-008 remains the owner of
future fake-stop design. The existing PS-013 grace/evaluation boundary and the
PS-015 editor-first tuning workflow are the authoritative integration points.

# Draft Execution Prompt

Read this task first, then read [[001 - Dancer simon says]], [[PS-001 - Define the First Gameplay Milestone]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[PS-008 - Design Fake Music Stops]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-013 - Implement Pose Charge and Evaluation Rules]], [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[PS-018 - Create the 001 - Dancer Simon Says Minigame Scene]], [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[PS-020 - Find Music and SFX for 001 - Dancer Simon Says]], [[Project Overview]], [[Workflow]], [[Decision Log]], [[Releases]], [[Task System]], [[Task Index]], [[Task board]], [[DEVELOPMENT]], and [[Tuning README]]. Inspect both the parent vault and the nested Godot repository, the current working tree, all existing minigame/tuning/audio/scene boundaries, and the approved asset provenance before editing.

Implement the bounded `Flash? Pose!` rebrand and genuine-stop feedback described here. Preserve numeric `001`, stable task/file identities, host authority, approved pose/evaluation semantics, and unrelated user edits. Use exact `Flash? Pose!` for player-facing copy and a consistent filesystem-safe `flash_pose` form for code-facing identifiers. Update current Markdown definitions and links deliberately, classify intentional historical/compatibility references, and repair any existing resource or test references rather than duplicating assets.

At the authoritative end of the existing pose-evaluation grace period, resolve
the result first, then emit one camera-flash SFX/VFX event only for a genuine
music stop, and resume music only after the flash completion boundary. Keep the
effect on the shared-screen feedback path, make it reversible and readable,
and do not implement fake music stops. Add designer-facing tuning fields using
the established Inspector tooltip/preset conventions, provenance notes for
audio/visual resources, deterministic ordering/duplicate-trigger tests, and
proportional editor/runtime checks. If a required dependent system or approved
audio is absent, record the exact blocker and leave a minimal integration seam
rather than inventing unrelated infrastructure. Update `DEVELOPMENT.md`, fill
this task's Outcome only when the acceptance criteria and human review are
complete, and report assumptions, deviations, and `[AUTO]`/`[EDITOR]`/
`[GODOT-RUNTIME]`/`[DESKTOP-BROWSER]`/`[PHYSICAL-PHONE]`/`[EXPORTED-BUILD]`/
`[HUMAN-PLAY]` evidence separately. Follow GitHub Flow and keep unrelated
working-tree changes out of the commit.

# Outcome
