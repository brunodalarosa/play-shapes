# 0047. Phone-predicted characters run a shared deterministic simulation, not Jolt

Decided by the owner on 2026-10-25, for minigame 006.

## Situation

Every gameplay scene simulated its characters on Jolt with bodies locked to one plane
([0042](0042-plaza-lobby-jolt-plane.md)). Flappy Race is the first minigame where the phone
predicts its own character, so a flap shows in the same frame as the tap. Prediction needs the
phone and the host to compute the same flight from the same taps, and Jolt cannot run in the
browser.

Flappy flight is simple: one box, a velocity, gravity, and axis-aligned obstacle boxes.

## Decision

A phone-predicted character runs a fixed 60 Hz step written twice, once in GDScript and once in
TypeScript, with the same arithmetic in the same order. Both use 64-bit floats: the GDScript
side keeps its state in plain `float` fields, never in `Vector2` or `Rect2`, which hold 32-bit
values. The step uses only addition, subtraction, multiplication, division, `min` and `max`,
and counts durations in whole ticks.

A committed fixture holds courses, tuning and tap scripts, the events each run produces and a
digest of every tick's exact state. The GDScript and TypeScript tests must both reproduce it.

## What follows

- This is the project default for any character the phone predicts. Jolt stays the default
  for everything else.
- The host stays the authority: the phone's prediction is presentation and yields to host state.
- A change to the rules changes both files and regenerates the fixture in the same commit.
- Geometry sent to the phone is snapped to steps of 1/64 m, so JSON carries it exactly.
- The first user is `components/flappy_flight/` with its mirror in `web/src/flappy_flight/`.
