# 0018. Screens are rebuilt with containers, keeping their design

Decided by the project owners on 2026-10-03.

## Situation

The lobby places its controls at 24 fixed positions and the ready screen uses no layout containers. The project's own guidance asks for containers and no fixed viewport sizes. Moving to a shared theme could aim for the exact same pixels, or for the same design.

## Decision

Screens are rebuilt with containers and a shared theme, keeping the design. The result is checked by the owner looking at screenshots, not by matching pixels.

Controls that sit on painted props, such as the lobby's board, stay positioned relative to that art.

## What follows

- Proving pixel-identical output is not required and not attempted.
