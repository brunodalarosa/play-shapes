---
area: Minigames
tags: [hub]
code: [minigames/004_3d_bubbles, web/src/004_3d_bubbles, assets/runtime/minigames/bubbles_3d, Bubbles3DProtocol, minigames/004_3d_bubbles/bubbles_3d_round_controller.gd]
verified: 2026-10-31
branch: feature/knowledge-base
---

# 004 Bubbles and Jellyfishes

Hub of minigame 004, Bubbles and jellyfishes 3D. Parent: [[Minigames]]. Each player swipes to
push a bubble with their Cubio inside, catching jellyfishes and dodging pufferfishes.

## Identity

| Number | Players | Phone input | Status |
| --- | --- | --- | --- |
| 004 | 2–10 | portrait swipes and holds | playable; awaits physical-phone checks and the owner's play review |

## Where in code

- Host: `minigames/004_3d_bubbles/`; catalog entry `bubbles_3d_minigame.tres`.
- Phone: `web/src/004_3d_bubbles/`, a three.js view of the player's own bubble.
- Runtime art: `assets/runtime/minigames/bubbles_3d/`; sources in `art/bubbles_3d/`.
- Workshop: none yet. It is planned on the shared window
  ([[0052-a-workshop-for-every-minigame|0052]]).

## This folder

| Note | Holds |
| --- | --- |
| [[004 Code Map]] | which script owns which part of the round |
| [[004 Messages]] | the touch, release, snapshot and feedback messages |
| [[004 Phone Screen]] | what the phone shows and sends |
| [[004 Tuning]] | every field of the tuning preset |
| [[004 Scene Composition]] | how the shared screen is composed |
| [[004 Asset Sources]] | where each asset came from and its license |
| [[004 Art Assets]] | the Blender sources and their export to runtime |

## Messages and authority

The host validates touches and releases and times holds itself; the phone only reports
gestures. Scores, pops, scatter and ranking are the host's. See [[004 Messages]].

## Prediction

None. The phone draws what the host's snapshots say.

## Workshop and tuning

One preset, `minigames/004_3d_bubbles/tuning/Default.tres`, selected in
`Tuning/Active Presets.tres`. Fields: [[004 Tuning]].

## Verification

`node tools/check.mjs bubbles_3d plane_3d bubble_shell underwater`. Pending evidence is under
Bubbles and jellyfishes 3D in [[Pending Reviews]].

## Gotchas

- **There is no spin move**; `tests/bubbles_3d_no_spin_test.gd` in the minigame keeps it out.
- Free jellyfishes draw through one `Bubbles3DJellyfishSwarm`, not one node each.

## Architecture docs

[[004 Bubbles and Jellyfishes Design]].
