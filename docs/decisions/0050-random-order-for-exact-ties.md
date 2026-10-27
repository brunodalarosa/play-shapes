# 0050. Exact ties in gameplay results may be settled at random

Decided by the owner on 2026-10-26, for minigame 006 and every minigame after it.

## Situation

Flappy Race ranks finishers by the 60 Hz tick they cross the finish line in. Two players could
cross in the same tick, or stop the timer at the same distance. Giving them a shared place, or
splitting the tick to find who was first, adds rules and code for a case players will almost
never meet.

## Decision

Play Shapes is a party game. When two or more players reach a result in the same simulation
tick, at the same distance or with an equal score, a minigame may order them at random instead
of handling the tie. Each tied player still gets a place of their own.

The random draw comes from a seeded generator the minigame already owns, such as its round
seed, so tests stay deterministic.

## What follows

- Rare edge cases do not earn extra code paths. A minigame states in its design document where
  it orders ties at random.
- A minigame whose design calls for shared places, as a score race with frequent ties might,
  keeps them; this decision allows random order, it does not require it.
- Flappy Race is the first user: same-tick finishes, equal distances and DNF players are
  ordered at random within their group.
