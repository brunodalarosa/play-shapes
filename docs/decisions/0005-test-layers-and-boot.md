# 0005. End-to-end tests go through boot; quick tests do not

Decided by the project owners on 2026-10-03.

## Situation

The game's boot scene will grow as the framework arrives. If every test had to boot the whole game, everyday testing and work on one minigame would slow down.

## Decision

End-to-end tests run the whole flow, boot included. Unit, integration and single-minigame tests start only what they need.

## What follows

- Boot must not become the only place where required setup happens. Whatever it sets up is callable in pieces, and boot calls the pieces in order.
- A minigame can be started directly by a test, the debug menu or a control route.
