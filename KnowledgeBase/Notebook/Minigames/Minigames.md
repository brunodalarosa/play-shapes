---
area: Minigames
tags: [hub]
code: [minigames/catalog.tres, MinigameDefinition, MinigameProtocol, host/pre_minigame_readiness.gd, scenes/pre_minigame_screen.tscn]
verified: 2026-10-31
branch: feature/knowledge-base
---

# Minigames

Area hub. Parent: [[Notebook]]. Every minigame has a number that is never reused, one folder
in the code, `minigames/NNN_name/`, and one folder here, `NNN Name/`.

## Rules

- **Every normal launch goes through the Pre-minigame screen.** A plan that skips it carries
  the warning in [[Journey Change Rules]].
- **Every minigame has a workshop on the shared design, planned with the minigame**
  ([[0052-a-workshop-for-every-minigame|0052]]).
- Numbers are stable identifiers; 001, 002 and 003 are retired and never reused.
- A minigame's hub follows [[Minigame Hub]] exactly. The rest of its folder is its own: the
  hub's "This folder" table says what each note holds. Keep that table current.

## Minigames

| Hub | Players | Input | Design |
| --- | --- | --- | --- |
| [[004 Bubbles and Jellyfishes]] | 2–10 | portrait swipes | [[004 Bubbles and Jellyfishes Design]] |
| [[005 Tilt Shift]] | 2, 4, 6, 8, 10 | landscape tilt | [[005 Tilt Shift Design]] |
| [[006 Flappy Race]] | 1–10 | taps | [[006 Flappy Race Design]] |

## Shared notes

- [[Minigame Catalog]]: how a minigame is declared, and the steps to add one.
- [[Pre-minigame Readiness]]: who owns the Ready screen in front of every round.

## Adding a minigame here

1. Make `Notebook/Minigames/NNN Name/` and its hub from [[Minigame Hub]].
2. Write its design from [[Minigame Design Doc]] in `Architecture/Minigames/`.
3. Add a row above, and a path-scoped rule in `.claude/rules/` that points at the hub.

Architecture: [[Minigame Contract]], [[Minigame Journey]], [[Minigame Workshops]].
