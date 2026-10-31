# 0056. Flappy Race finishers teleport to the podium instead of flying there

Decided by the owner on 2026-10-30, for minigame 006.

## Situation

The design had each finisher fly from the finish line to their spot on the podium. A flight
needs a path around the other Cubios, timing against later finishers and a landing clip, for a
moment that lasts about a second.

## Decision

A finisher teleports to their spot as they cross the line, with a puff of sparks in their colour
where they leave and where they land. At the results the unfinished players teleport to the low
step the same way.

## What follows

- The podium needs no flight animation and no path planning; a spot per place is enough.
- The puff is a `CPUParticles3D`, which the GL Compatibility renderer draws.
- A richer arrival can replace the puff later without changing where anyone stands.
