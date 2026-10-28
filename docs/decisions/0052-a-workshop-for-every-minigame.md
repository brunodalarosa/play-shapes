# 0052. Every minigame has a workshop built on one shared design

Decided by the owner on 2026-10-28, for minigame 006 and every minigame after it.

## Situation

The game runs from scripts with no scene a person can look at, so the owner needs a place to
see, play and tune each minigame. The Tilt Shift 3D workshop, an editor tab with a small
preview, a long column of fields and a file menu of thirteen items, was hard to use. Each new
minigame could get its own tool, or all could share one design.

## Decision

Every minigame has a workshop following
[Minigame workshops](../game-design-documents/Minigame%20workshops.md): a scene started on its
own through the boot, running the real game and phone page, with four named panels that can be
resized and popped out into windows, presets saved as one file each, and a button that makes a
preset the one the game uses. Only the parts that document lists as the minigame's own differ.

## What follows

- The shared parts are built once, outside any minigame folder, starting with Flappy Race.
- Planning a new minigame includes planning its workshop.
- A workshop never runs different rules from a real game, so values the phone predicts with
  wait for a restart.
- The phone view shows the real phone page inside the game window, which needs a web view
  add-on; godot-wry is tried first.
- Tilt Shift 3D keeps its current workshop until it is moved onto the shared design, and
  Bubbles and jellyfishes 3D gets one later.
