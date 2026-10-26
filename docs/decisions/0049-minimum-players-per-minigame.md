# 0049. Each minigame sets its own minimum number of players

Decided by the owner on 2026-10-25, for minigame 006.

## Situation

`SessionHost` refused every normal launch below two registered players. Flappy Race is the
first minigame meant to be played alone as normal game flow, while 004 and 005 still need at
least two. A one-player round existed only as a debug scenario that skips the Pre-minigame
screen.

## Decision

`MinigameDefinition.min_players`, default 2, is the fewest registered players a normal launch
needs. `SessionHost.minigame_availability` reads it, and the lobby shows its reason. A debug
one-player launch still needs `one_player_debug` and exactly one player. The debug menu offers
no one-player round for a minigame whose minimum is already 1, and the catalog test rejects
that combination.

## What follows

- A minigame that starts with one player goes through the Pre-minigame screen like any other.
- 004 and 005 keep the default and the same refusal text.
- A later minigame sets its minimum in its definition, with no change to the host.
