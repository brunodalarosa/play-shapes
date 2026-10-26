# Flappy Race

Minigame 006 is a phone-first race through a crystal cave: each player taps to flap their
winged Cubio from the start line to the finish. It is the only minigame that starts with one
player. The design is in `docs/game-design-documents/Minigames/006/`.

Only the launch exists. The race, its course and the phone's view are not built.

## Files

- `flappy_race_minigame.tres` is the catalog entry: 1 to 10 players
  ([decision 0049](../../docs/decisions/0049-minimum-players-per-minigame.md)).
- `flappy_race_pre_minigame_content.tres` is the Pre-minigame booklet text. It has no preview
  image yet.
- `flappy_race.tscn` and `flappy_race.gd` take the launch from `SessionHost`, register the
  protocol, show the title and player count, and offer Return to lobby.
- `flappy_race_protocol.gd` sends each phone a waiting snapshot and accepts no input.
- `tests/flappy_race_launch_test.gd` starts the race with one and with ten players.
- The phone side is `web/src/006_flappy_race/`, tested in `web/tests/006_flappy_race/`.
