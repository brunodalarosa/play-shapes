# 0055. Workshops follow Material Design 3

Decided by the owner on 2026-10-28, for every minigame workshop.

## Situation

The first workshop used Godot's default controls, which the owner found unpleasant and unlike
the mockups of [Minigame workshops](../game-design-documents/Minigame%20workshops.md). Godot
styles every control through a theme, so any design system can be applied without engine
changes. The owner chose Google's Material Design 3.

## Decision

Workshops wear Material Design 3's dark scheme, built once as a Godot theme in
`workshop/workshop_theme.gd`: its colour roles, type scale with Roboto, shapes and state
layers, and named variations for the workshop's own parts.

A workshop that needs a kind of control the theme does not have yet designs it from Material
Design 3's component of the same purpose, adds it to that theme as a variation, and uses it
from there, so every workshop keeps one look.

## What follows

- Colours, fonts and sizes come from the theme's roles, never from values set on a control.
- Material has no warning role; an amber extended colour marks unsaved edits and values waiting
  for a restart.
- Material's ripple and floating field labels are left out; hover and press show as state
  layers.
- Roboto and Roboto Mono are vendored in `workshop/fonts/` under the SIL Open Font License, and
  stay out of the exported game with the rest of `workshop/`.
- The game's own screens are not covered; they follow the art direction.
