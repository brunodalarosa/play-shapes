# 0054. The workshop phone view is the real phone page in a godot-wry web view

Chosen on 2026-10-28 while building the Flappy Race workshop, under the owner's approval to
take the recommended option; the owner reviews it with the workshop.

## Situation

Workshops show the real phone page beside the game
([0052](0052-a-workshop-for-every-minigame.md)). Godot has no web view of its own, so the page
needs an add-on or a separate browser window. godot-wry was to be tried first, and it had to
work in a popped-out panel too.

## Decision

The phone view runs the page in godot-wry v1.0.2, which wraps the system's WebView2. The
workshop adds the designer to the player registry and stores that player's resume token in
the page before loading it, so the page joins as the designer without the join screen.

That release always draws its page in the main window, so the Phone view panel stays docked
and its Pop out button says why. The other three panels pop out.

## What follows

- Only the Windows library is vendored, in `addons/godot_wry/`, and it stays out of the
  exported game with every workshop.
- Dialogs and menus open as their own windows in a workshop, so they show above the page,
  which draws over the game window.
- The add-on places the page by screen position but sizes it in physical pixels; the phone
  view scales the size by the window's stretch itself, and zooms the page to the device width.
- Upstream merged the fix for popped-out windows after v1.0.2. A release with it lets the
  Phone view pop out; until then, popping it out would need a separate browser window.
