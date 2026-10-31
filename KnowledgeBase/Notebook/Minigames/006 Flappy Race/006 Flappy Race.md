---
area: Minigames
tags: [hub]
code: [minigames/006_flappy_race, web/src/006_flappy_race, components/flappy_flight, web/src/flappy_flight, tests/fixtures/flappy_flight_runs.json, FlappyRaceController]
verified: 2026-10-31
branch: feature/knowledge-base
---

# 006 Flappy Race

Hub of minigame 006, Flappy Race. Parent: [[Minigames]]. Each player taps to flap a winged
Cubio through a cave from the start line to the finish.

## Identity

| Number | Players | Phone input | Status |
| --- | --- | --- | --- |
| 006 | 1–10, the only minigame with `min_players = 1` | taps | playable on a placeholder course and podium; cave art, phone audio and booklet preview to come |

## Where in code

- Host: `minigames/006_flappy_race/`; catalog entry `flappy_race_minigame.tres`.
- Shared flight step: `components/flappy_flight/` and its TypeScript twin
  `web/src/flappy_flight/`.
- Phone: `web/src/006_flappy_race/`.
- Workshop: `minigames/006_flappy_race/workshop/`, the first on the shared window.

## This folder

| Note | Holds |
| --- | --- |
| [[006 Files]] | every file of the minigame folder and its tests |
| [[006 Code Map]] | which script owns which part of the race |
| [[006 Messages]] | `flappy_tap`, snapshots, settled flights and events |
| [[006 Phone Screen]] | what the phone shows, predicts and sends |
| [[006 Tuning]] | every field of the preset and its parts |
| [[006 Scene Composition]] | how the shared screen and podium are composed |
| [[006 Asset Sources]] | where each asset comes from |

## Messages and authority

The host runs the race: countdown, flights, finishing, the timer, disconnects and the
ranking. A tap carries the tick the phone applied it at; the host settles every flight one tap
window behind its clock ([[0048-predicted-input-carries-a-tick|0048]]).

## Prediction

Each phone predicts its own flight on the shared step and corrects it from host state. The
GDScript and TypeScript steps are proven bit-identical by
`tests/fixtures/flappy_flight_runs.json` ([[0047-shared-deterministic-simulation|0047]]).
See [[Shared Deterministic Prediction]].

## Workshop and tuning

One file per preset in `tuning/`, holding the race, flight, course and view parts.
`FlappyRaceAutopilot` taps through the protocol as a phone does. See [[006 Tuning]] and
[[Workshop Window]].

## Verification

`node tools/check.mjs flappy`; the course sweep runs under `--full`, and the presentation's
visual check runs without `--headless`. Pending evidence is under Flappy Race in
[[Pending Reviews]].

## Gotchas

- **Change the flight step in both languages and regenerate the fixture**, or the phone and
  the host disagree about where a player is.
- Finishers teleport to the podium rather than fly to it
  ([[0056-podium-arrivals-teleport|0056]]).
- Overlapping Cubios dither instead of hiding each other
  ([[0051-dithered-overlap-on-a-shared-plane|0051]]).

## Architecture docs

[[006 Flappy Race Design]], [[Shared Deterministic Prediction]].
