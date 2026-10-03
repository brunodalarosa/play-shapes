# 0015. One folder per minigame

Decided by the project owners on 2026-10-03.

## Situation

The files of the one minigame are spread over 14 folders: its scripts, protocol, scenes, tuning, tests and phone code each sit with others of their kind. Adding or changing a minigame means working across all of them.

## Decision

Each minigame's Godot scripts, scenes, protocol script, tuning and tests live in one folder named with its number and name. Its phone code lives in a matching folder under `web/src/`.

Art sources and runtime assets stay where they are, since they are already per minigame and tied to the export rules.

## What follows

- The move is one mechanical change that updates paths, and it conflicts with any branch in progress.
- Minigame numbers stay stable identifiers.
