# 0048. Predicted input carries a simulation tick, settled one window behind the host

Decided by the owner on 2026-10-25 and 2026-10-26, for minigame 006.

## Situation

The browser sent no client time: the host timed every input by its own receipt. Flappy Race
predicts each player's flight on the phone ([0047](0047-shared-deterministic-simulation.md)),
so a flap shows the moment it is tapped. Timed by receipt, the same tap reaches the host 30 to
100 ms late on Wi-Fi, and the host's flight would disagree with the phone's.

Replaying a late tap over a kept history would fix the flight, but it could take back a hit the
host had already counted and shown.

## Decision

A phone-predicted input carries the simulation tick the phone applied it at, never wall-clock
time. The host steps every predicted character at a settled tick, one tap window behind its own
clock (250 ms by default).

- A tap whose tick lies inside the window waits until the simulation reaches that tick.
- A tap older than the window is applied at the next tick to be simulated.
- A tap ahead of the host's clock is applied at the clock.

Everything the host reports about a predicted character, its state and its events, is settled
and final when sent.

## What follows

- A phone can gain at most the window, and only for its own character.
- The host's view of the race, and the shared screen, runs one window behind real time. Each
  player watches their own phone, where the prediction answers at once.
- A late tap gives exactly the run an on-time tap gives, with no history and no re-simulation.
- The window is a tuning value; physical-phone play decides it.
- The first user is Flappy Race's `flappy_tap`, described in
  [protocol.md](../protocol.md#flappy-race).
