---
area: Minigames
tags: [hub]
code: []
verified:
branch:
---

# {{title}}

Hub of one minigame, named `NNN Name` after its stable number. Parent: [[Minigames]]. Every
minigame hub keeps these sections in this order, so an agent finds the same things in the same
place; the minigame's other notes may take any shape, and the folder map below says what they
are.

## Identity

| Number | Players | Phone input | Status |
| --- | --- | --- | --- |
| NNN | min–max | gesture, tilt, buttons… | in design / playable / approved |

## Where in code

- Host: `minigames/NNN_name/` (scenes, controller, `*_protocol.gd`, tuning, `tests/`).
- Phone: `web/src/NNN_name/`.
- Runtime art: `assets/runtime/minigames/<name>/`.
- Workshop: `minigames/NNN_name/workshop/`.

## This folder

The notes in this minigame's folder and what each holds. Keep it current when a note is added.

| Note | Holds |
| --- | --- |
| [[NNN Design]] | the design document (Architecture) |

## Messages and authority

What the phone sends, what the host answers, what the host alone decides.

## Prediction

What the phone predicts, on which shared step, and the fixture that proves it. "None" is a
valid answer.

## Workshop and tuning

The tuning Resources, live versus restart groups, and the workshop presets.

## Verification

The focused `node tools/check.mjs` filters and the evidence still pending in
[[Pending Reviews]].

## Gotchas

**Bold** the ones that cause bugs when ignored.

## Architecture docs

[[NNN Design]] and any other doc about this minigame.
