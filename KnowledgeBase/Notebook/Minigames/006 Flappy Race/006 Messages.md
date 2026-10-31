---
area: Minigames
tags: [system, stub]
code: [FlappyRaceController]
verified:
branch:
---

# 006 Messages

Hub: [[006 Flappy Race]].

The messages of minigame 006. The shared rules are in the message protocol.

Flappy Race launches through the shared Pre-minigame gate with 1 to 10 players. The host runs
the race in `FlappyRaceController`; `flappy_race_protocol.gd` is its phone side. Ticks are the
shared 60 Hz simulation ticks since GO ([[0047-shared-deterministic-simulation|0047]]).

The phone sends `flappy_tap` with `type`, a whole `seq` increasing per player and a whole `tick`,
the tick it applied the tap at. Other fields, a missing or fractional number and a negative one
are rejected. The host steps every flight at a settled tick, one tap window (15 ticks by
default) behind its clock, and applies each tap at its own tick when that lies in the window.

- A tap older than the window applies at the next tick to settle; one ahead of the host's clock
  applies at the clock.
- Several taps in one tick are one flap. A tap during the countdown, with a used `seq`, from a
  frozen or finished player, or while not ready to respawn, is accepted and does nothing.

`flappy_race_snapshot` is sent on launch and on every resume. It carries `phase` (`countdown`,
`racing` or `results`), `player_count`, `tick_rate`, the settled `tick`, the host's
`clock_tick`, `countdown_remaining_msec`, `window_ticks`, `race_ticks`, `last_seconds_tick`,
the flight tuning as `flight`, the presentation values as `view`, the player's
`character_color`, the generated `course` and the player's own state as `own`. In
results it adds `results`, every player's `place`, `name`, colour, finish time or distance and
`dnf`, and the player's own entry as `own_result`.

`own` holds the exact settled `flight` (position, vertical speed, flying, ready, cooldown,
invulnerability and boost ticks, obstacle index, `hearts` and the indices of the pickups
`taken`), `last_seq`, `connected`, `place`, `finish_tick` and `dnf`.

- `flappy_race_state`: `tick`, `clock_tick` and `own`, 20 times a second to each racing player,
  skipped while that connection has output queued.
- `flappy_race_event`: `event`, `tick` and, for the player's own events, `own`. `go` and
  `last_seconds` reach every phone; `hit`, `heart_refilled`, `ready`, `respawn`, `pickup` (with
  its `pickup` index) and `finish` (with its `place`) reach only their player.

Everything the host sends is settled and final. A disconnected player's flight freezes; a resume
within grace waits ready at the same spot with no heart spent. When grace expires the player is
DNF. Exact ties in the ranking are ordered at random
([[0050-random-order-for-exact-ties|0050]]). The phone compares each settled
state with its own prediction for that tick and replays its taps only when they differ.
