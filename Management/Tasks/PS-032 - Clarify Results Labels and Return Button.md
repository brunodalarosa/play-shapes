---
id: PS-032
title: "Clarify Results labels and strengthen return button"
type: implementation
status: backlog
release:
owner: ai
priority:
depends_on:
  - "[[PS-026 - Implement Flash Pose Shared Screen Feedback and Results]]"
  - "[[PS-027 - Integrate Flash Pose Lobby and Debug Flow]]"
---

# Goal

Improve the shared-screen Results view for minigame 001 so the outcome groups
are immediately understandable and the host-controlled return action is easy
to see and use.

# Scope

- Replace the visible group heading `HAPPY CREW` with exactly `WINNERS`.
- Replace the visible group heading `MOODY CREW` with exactly `LOSERS`.
- Remove the star and cloud emojis from the group headings and from each player
  name in the two result lists. Player names should render as names only.
- Reduce the vertical layout space occupied by the Winners and Losers result
  panels by 20% relative to the current results composition, while preserving
  clear separation, readable names, and the existing upper/lower grouping.
  Measure the current panel/content footprint before editing and document how
  the 20% reduction was applied.
- Make the existing `Return to lobby` button substantially more evident by
  increasing its usable size, visual contrast, and separation from surrounding
  content. Keep it centered in the results view and ensure it remains easy to
  identify at the intended shared-screen viewing distance.
- Preserve the existing host-only return behavior, disabled-state handling,
  results lifetime, ranking split, character result moods, audio teardown, and
  transition back to the lobby.
- Update `DEVELOPMENT.md` with the final label/emoji decision, the panel-space
  measurement, button sizing/styling choices, and verification evidence.

# Non-Goals

- Do not change ranking, `top_group_size`, winner/loser assignment, scoring,
  lives, pose evaluation, round timing, or host authority.
- Do not rename or remove the internal semantic `happy`/`moody` animation
  states; only the player-facing Results labels and name formatting change.
- Do not change the results protocol, browser phone UI, lobby layout, music/SFX
  selection, or character animation content.
- Do not add a scoreboard, points, extra celebratory symbols, or automatic
  return behavior.
- Do not solve the button problem by making it cover player names or overlap
  either result panel.

# Acceptance Criteria

- The shared Results view visibly uses the exact uppercase headings `WINNERS`
  and `LOSERS`.
- No star or cloud emoji appears in either heading or before any player name on
  the Results view. Player names remain readable and retain their existing
  ordering and grouping.
- The Winners and Losers panels/content occupy approximately 80% of their
  current vertical footprint, representing the requested 20% reduction. The
  two groups remain balanced, separated, and readable; the implementation
  records the baseline and final measurement or layout rationale in
  `DEVELOPMENT.md`.
- The `Return to lobby` button is visibly prominent at the intended shared
  display size: it is larger than the current 220×44 presentation, has clear
  contrast against the results backdrop, has comfortable text padding, and is
  not visually confused with either result group.
- At the existing technical results-check size of 1280×720, the complete
  Results view shows both group headings, all test names, and the return button
  without clipping, overlap, unintended scrolling, or loss of readable
  contrast. Also inspect the layout at the project's current/default shared
  display size when available.
- A technical runtime sequence still presents the results until the host uses
  `Return to lobby`; the button remains host-only, invokes the existing
  controller request exactly as before, and preserves its existing disabled
  behavior while the request is processed.
- Winners still receive the existing happy result mood and losers still receive
  the existing moody result mood. This semantic behavior is verified
  separately from the visual label change.
- Focused automated/editor/runtime checks pass, and evidence distinguishes
  automated behavior checks from Godot visual inspection and human readability
  approval. A technical capture is not presented as proof of final couch-
  distance readability or game-feel approval.
- `DEVELOPMENT.md` records the changed labels, emoji removal, 20% layout-space
  reduction, button treatment, exact checks, captures, and any caveats.

# Game Feel / Player Experience

The result should be understood instantly from across the room: `WINNERS` and
`LOSERS` are direct, neutral outcome labels, the player names are clean and
uncluttered, and the next host action is visually obvious without competing
with the results themselves. The larger button should feel intentional and
easy to hit without becoming the most dominant element on the screen.

# Open Questions

None. The implementation agent should preserve the existing visual language
and use the current results capture conventions to make the requested 20%
reduction and button prominence observable.

# Notes / Findings

- Results are built at runtime by
  `minigames/flash_pose_presentation.gd` in `_build_results_view()`.
- The current visible headings are `HAPPY CREW  ★` and `MOODY CREW  ☁`.
- `_on_round_results_ready()` currently prefixes each winner with `★` and each
  loser with `☁`; remove only that presentation formatting.
- The current results panels use anchors of roughly 12%–48% and 53%–89% of
  the viewport height. The current return button is centered near the bottom
  with a 220×44 rectangle. Treat these as the baseline to measure before
  changing the layout.
- Existing internal animator calls use `happy` and `moody` result states and
  must remain unchanged because they drive character presentation rather than
  the visible group wording.

# Draft Execution Prompt

Read this task, [[PS-026 - Implement Flash Pose Shared Screen Feedback and Results]],
[[PS-027 - Integrate Flash Pose Lobby and Debug Flow]], [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[Project Overview]], [[Decision Log]],
[[DEVELOPMENT]], and the project-root `AGENTS.md` before changing anything.
Inspect the current `minigames/flash_pose_presentation.gd`, results controller
signals/snapshots, focused tests, and existing 1280×720 results-capture
conventions before editing.

Implement only the Results presentation changes in this task. Replace the
player-facing headings with exact uppercase `WINNERS` and `LOSERS`, remove star
and cloud prefixes from headings and names, and leave internal `happy`/`moody`
semantic animation state untouched. Measure the current Winners/Losers panel
footprint, reduce that vertical footprint by 20%, and use the recovered space
to make `Return to lobby` materially larger, higher-contrast, and easier to
find without overlapping result content. Preserve the existing host-only
controller request, disabled handling, result lifetime, ranking, audio, and
lobby transition.

Add or update focused checks where useful, run the relevant automated and
Godot/editor/runtime checks, and inspect a technical Results capture at
1280×720 plus the current/default shared-display size if different. Report
`[AUTO]`, `[EDITOR]`, and `[GODOT-RUNTIME]` evidence separately from any human
readability or game-feel judgment. Update `DEVELOPMENT.md` with the baseline
and final layout measurements, implementation choices, captures, and caveats.
Report assumptions and deviations, summarize changed files, and identify any
human-tunable visual constants. Follow the repository's normal GitHub Flow
instructions during implementation and keep unrelated changes out of the
work.

# Outcome
