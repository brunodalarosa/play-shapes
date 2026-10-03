# 0014. A rejected jump or fall is dropped, and a fall passes one surface

Recorded on 2026-10-03 from the project's documents, where it was already in force. The reasons are as those documents gave them; whoever made the decision should correct them if they differ.

## Situation

A player can ask to jump or to fall through a platform at a moment when the host cannot allow it. The host could queue the action for later, turn it into another action, or drop it.

## Decision

A rejected attempt is dropped. It never queues a later action, and a fall never becomes a jump.

A fall excludes exactly one supporting surface, for that character only. Falling again requires leaving the down position first, so holding it cannot descend several floors.

## What follows

- Each surface says whether it can be fallen through. The bottom shelf cannot.
- A valid request the physics cannot honor still uses up its sequence number.
