---
area: Minigames
tags: [system, stub]
code: [minigames/006_flappy_race, FlappyRace, FlappyRacePresentation, Cubio3D, RaceCamera3D, OffscreenBubbles, FlappyRacePodium, FlappyRaceController]
verified:
branch:
---

# 006 Code Map

Hub: [[006 Flappy Race]].

Where minigame 006 lives in the code.

Minigame 006 is in `minigames/006_flappy_race/`, the first minigame whose `min_players` is 1.
The host runs and draws the whole race on a placeholder course; each phone flies its own Cubio.
[Its README](../../../../minigames/006_flappy_race/README.md) lists the files.

- `flappy_race.tscn` and `flappy_race.gd` (`FlappyRace`) take the launch, start the race on
  a random seed, register the protocol, bind the presentation and offer Return to lobby.
- `flappy_race_presentation.tscn` and `.gd` (`FlappyRacePresentation`) draw the shared
  screen from the controller's settled flights, smoothed between ticks: a `Cubio3D` per racer
  in its own depth slot, dithered while it covers another
  ([[0051-dithered-overlap-on-a-shared-plane|0051]]), the floating respawn
  hearts, pickup bursts, a `RaceCamera3D` on the leader, `OffscreenBubbles`, place badges,
  fading names, the timer and the countdowns. `flappy_race_course_view.gd` is the placeholder
  course.
- Finishers teleport with a puff of sparks to their spot on `FlappyRacePodium`
  (`flappy_race_podium.gd`), and at the results the presentation frames the podium beside a
  panel of places ([[0056-podium-arrivals-teleport|0056]]).
- `flappy_race_controller.gd` (`FlappyRaceController`) owns the race: the countdown, every
  player's `FlappyRaceRacer`, stepped together one tap window behind the clock
  ([[0048-predicted-input-carries-a-tick|0048]]), finishing, the timer, freezing on
  disconnect, DNF and the ranking ([[0050-random-order-for-exact-ties|0050]]).
- `flappy_race_protocol.gd` turns taps into controller calls and sends each phone its course,
  its settled flight and its events. See [[006 Messages|protocol.md]].
- `flappy_race_course.gd` (`FlappyRaceCourse`) generates the seeded course on the host: obstacle
  pairs, respawn spots, pickups and each ground half's look, following difficulty `Curve`s over
  course progress. Its `to_dictionary` is what phones receive.
- `FlappyRaceTuning` is a preset, selected in `Tuning/Active Presets.tres`: one file holding
  the race's countdown, timer, last seconds, tap window and state rate, and its flight, course
  and view parts.
  `FlappyRaceViewTuning` holds what both screens show: tilt, faces, the phone's framing and
  the shared screen's camera, names, depth slots and dither.
- `flappy_race_autopilot.gd` (`FlappyRaceAutopilot`) is a simulated player that taps through
  the protocol as a phone does, with one skill, Good.
- `workshop/` is its workshop on the shared window: `flappy_race_workshop.tscn` runs the real
  race with the designer and autopilots, and `flappy_race_course_strip.gd` draws the course
  strip. The controller's `place_racer` and the presentation's `followed_id` and
  `frames_camera` serve it; a real race uses neither.
- Its design is in `docs/game-design-documents/Minigames/006/`.
