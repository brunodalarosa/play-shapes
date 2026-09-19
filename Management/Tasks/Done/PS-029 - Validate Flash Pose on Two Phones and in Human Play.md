---
id: PS-029
title: Validate Flash? Pose! on two phones and in human play
type: validation
status: done
release:
owner: human
priority:
depends_on:
  - "[[PS-005 - Define Multi-Phone and Agent Validation Strategy]]"
  - "[[PS-028 - Validate Flash Pose Technical Loop]]"
---

# Goal

Have the project owner validate the first complete Flash? Pose! experience on
the intended local network and judge whether the phone controls, shared-screen
communication, timing, feedback, accessibility, and results are usable enough
to call the first minigame proof functional.

# Scope

- Run the normal host on the owner's computer over private home Wi-Fi with two
  real phones: iPhone 16 Pro using Safari and Pixel 7 using Chrome. Record the
  device/OS/browser versions and the Godot renderer/build mode.
- Join two distinct players from the lobby, start the normal game, complete
  several genuine stops with both correct and incorrect holds, observe life
  loss/elimination, reach results, use the host-controlled return, and verify
  both phones return to a usable lobby state.
- Check one-thumb press-and-hold behavior, release/change handling, icon-plus-
  color direction recognition, attention switching between phone and shared
  screen, pose readability, life/elimination communication, flash clarity,
  music stop/resume, audio fatigue, pacing, and result grouping.
- Check the one-player F12 debug path separately if useful, while keeping it
  visibly distinct from normal two-player play. Use iPhone Chrome only as the
  PS-005 browser spot check when the change warrants it.
- Record explicit approval, named fixes, or blockers. If a technical issue is
  found, link a focused follow-up rather than silently changing implementation
  or promoting provisional tuning.

# Non-Goals

- Expanding to a device farm, unusual networks, more than two routine phones,
  fake music stops, online play, or a cross-minigame session.
- Treating automated, desktop-browser, or current-computer runtime evidence as
  a substitute for the named devices and human judgment.
- Promoting final timing, flash intensity, audio gain, or accessibility
  decisions without recording the observed conditions and owner decision.

# Acceptance Criteria

- A structured `[PHYSICAL-PHONE]` record covers the two-phone local-network
  loop, or records the exact environmental/product blocker and required rerun.
- A `[HUMAN-PLAY]` record covers responsiveness, fairness, readability,
  attention, accessibility, audio/flash comfort, pacing, and results. Passing
  the technical task is not reused as this evidence.
- The owner explicitly approves the first functional experience, approves a
  named candidate tuning preset, or identifies bounded changes that must be
  completed before approval. No agent marks the subjective gate done on the
  owner's behalf.
- Any phone/browser-specific issue includes device, browser, steps, result,
  and a focused follow-up or clear acceptance decision.

# Game Feel / Player Experience

This is the authority for whether the stop is fair, the shared display wins
attention, the phone can be operated without constant visual focus, the flash
feels like a satisfying snapshot, and the two-tier result communicates enough
without a scoreboard. The owner may reject technically correct behavior if the
experience is confusing, tiring, inaccessible, or not fun.

# Open Questions

- Which provisional timing, flash, audio, and accessibility adjustments should
  become the next named experiment after the first playthrough?

# Notes / Findings

PS-005 defines the routine device matrix and evidence record. This task remains
human-owned because physical touch, LAN reachability, shared-screen distance,
accessibility, and game feel cannot be established by the agent's automated or
desktop checks.

# Draft Execution Prompt

Read this task, [[PS-005 - Define Multi-Phone and Agent Validation Strategy]],
[[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]],
[[PS-028 - Validate Flash Pose Technical Loop]], [[001 - Dancer simon says]],
[[Project Overview]], [[Releases]], and [[DEVELOPMENT]]. Use the named iPhone
16 Pro Safari and Pixel 7 Chrome pair on normal home Wi-Fi. Follow the exact
full-loop scenarios and evidence fields from PS-005, record physical-device
and human-play observations separately, and document approval or blockers.
Do not infer approval from automated results, change implementation in the
middle of the test without recording it, or expand coverage beyond the stated
MVP matrix unless a concrete issue justifies a focused follow-up.

# Outcome
I've tested and it works! Tested with an android and an iphone