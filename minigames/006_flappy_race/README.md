# Flappy Race

Minigame 006 is a phone-first race through a crystal cave: each player taps to flap their
winged Cubio from the start line to the finish. It is the only minigame that starts with one
player. The design is in `docs/game-design-documents/Minigames/006/`.

The host runs the whole race: countdown, flights, finishing, ranking, the timer and
disconnects. Each phone flies its own Cubio, and the shared screen follows the leader with
everyone, both on a placeholder course until the cave art lands. The flight and heart rules are shared code in `components/flappy_flight/`,
mirrored for the phone in `web/src/flappy_flight/`.

## Files

- `flappy_race_minigame.tres` is the catalog entry: 1 to 10 players
  ([decision 0049](../../docs/decisions/0049-minimum-players-per-minigame.md)).
- `flappy_race_pre_minigame_content.tres` is the Pre-minigame booklet text. It has no preview
  image yet.
- `flappy_race.tscn` and `flappy_race.gd` take the launch from `SessionHost`, start the race,
  register the protocol, show the player count and the race's status, and offer Return to
  lobby.
- `flappy_race_presentation.tscn` and `.gd` draw the shared screen: Cubios, hearts, bursts,
  the race camera, bubbles, the dithered overlap, badges, names, timer and countdowns.
  `flappy_race_course_view.gd` is the placeholder course.
- `flappy_race_controller.gd` runs the race, settling every flight one tap window behind its
  clock ([decision 0048](../../docs/decisions/0048-predicted-input-carries-a-tick.md)).
  `flappy_race_racer.gd` is one player's race state.
- `flappy_race_protocol.gd` takes `flappy_tap` and sends each phone its snapshot, its settled
  flight and its events, as [protocol.md](../../docs/protocol.md#flappy-race) describes.
- `flappy_race_course.gd` generates a course from a seed and the tuning.
- `flappy_race_tuning.gd` and `flappy_race_course_tuning.gd` are the tuning scripts; the values
  are in `tuning/`, described in [its README](tuning/README.md).
- `tests/flappy_race_launch_test.gd` starts the race with one and with ten players.
- `tests/flappy_race_controller_test.gd` checks the tap window, freezing, resuming, leaving
  and the ranking; `flappy_race_ten_player_race_test.gd` flies ten autopilots to both ends of
  a race; `flappy_race_protocol_test.gd` checks the messages.
- `tests/flappy_race_presentation_test.gd` checks the shared screen; the visual check of the
  same name captures it with 1, 4 and 10 players, run without `--headless`.
- `tests/flappy_race_course_test.gd` checks the generator, and `flappy_race_flyable_test.gd`
  flies its courses with the autopilot; the sweep version runs under `--full`.
- The phone side is `web/src/006_flappy_race/`, tested in `web/tests/006_flappy_race/`.
