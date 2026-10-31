---
tags: [hub]
code: []
verified: 2026-10-31
branch: feature/knowledge-base
---

# Architecture

Explanations, humans first. Parent: [[Home]]. How the game is meant to work and why: mental
models, flows and decisions. Where things are in the code is in the [[Notebook]].

## Levels

| Level | Explains | Example |
| --- | --- | --- |
| macro | a flow across systems | [[Play Shapes Overview]], [[Player Journeys]] |
| system | one system and its extension points | [[Minigame Contract]] |
| implementation | one concrete thing built on the systems | [[006 Flappy Race Design]] |

Each doc names its `parent` one level up and links its children down. Folders
`Architecture/<Area>/` are created with their first doc.

## Writing a doc

- Start from [[Architecture Doc]]; a minigame's design starts from [[Minigame Design Doc]].
- **Agent-written docs stay `status: draft`** until a person who knows the system reviews
  them. Mark claims nobody checked *(unverified)*.
- The why is the most valuable part: constraints, decisions, history, what was tried. Link the
  records in [[Decisions]] rather than retelling them.

## Docs

- Macro: [[Play Shapes Overview]], [[Player Journeys]], [[Art Direction]].
- Host and Session: [[Message Protocol]].
- Player journeys: [[Lobby Journey]], [[Minigame Journey]], [[Pre-minigame Screen]],
  [[Journey Change Rules]].
- Playground Lobby: [[Lobby Platform Motor]], [[Lobby Visual Rules]].
- Minigames: [[Minigame Contract]], [[Shared Deterministic Prediction]],
  [[004 Bubbles and Jellyfishes Design]], [[005 Tilt Shift Design]],
  [[006 Flappy Race Design]].
- Workshops and Tuning: [[Minigame Workshops]].
- [[Decisions]]: every decision record, 0001 onward.

## Candidates

Roughly by how long the system takes to understand:

- [[Session and Reconnection]]: registry, tokens, grace and resume across scenes.
- [[Boot Steps]]: Essential and Optional steps and entry points.
- [[Motion Pipeline]]: phone sensors to Tilt Shift paddle angles, calibration included.
- [[Shape Face System]]: parts, presets, expressions and blinking on host and phone.
- [[Cubio Character]]: rig, clips, held stances and the front push.
- [[Phone Rendering]]: the three.js views and their flat fallbacks.
