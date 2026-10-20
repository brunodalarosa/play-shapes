# Tilt Shift 3D tuning

Select a rules Resource in `Tuning/Active Presets.tres`, under Tilt Shift 3D. The host copies it
when the Pre-minigame screen opens; edits apply to the next shift. The **Tilt Shift 3D** tab in
Godot edits every value here with snapping, saves and a gameplay preview; see
[the workshop](WORKSHOP.md).

Values are provisional first guesses. The owner chooses them in play.

## Rules profile

| Field | Default | Units / range | Effect |
| --- | --- | --- | --- |
| Round duration | 45 | Seconds, 1–300 | Scoring window of each round. |
| Round count | 4 | 1–24 | Rounds per shift; map one layout and basket preset per round. |
| Neighbor distance | 0.24 | Widths, 0.01–2 | How far apart same-owner paddles should be. |
| Layouts by round | A, B, A, B | One per round | A has two paddles per team and the automatic paddle; B has three per team. |
| Baskets by round | Five openings × 4 | One per round | Orange, Blue, trash, Orange, Blue across the floor. |

The profile selects [flow](FLOW.md), [motion](MOTION.md), [physics](PHYSICS.md),
`Presentation.tres` and `Expressions.tres`.

## Presentation

`Presentation.tres` decides how the factory looks. It never changes a collider, a score or the
phones' message rate.

| Field | Default | Effect |
| --- | --- | --- |
| Gap ratio / outline ratio | 0.06 / 0.09 | Cream gap ring and team outline widths, as shares of the paddle's thickness. |
| Gap color, outline colors | `#fff3dc`, `#fd8702`, `#0144f2` | The ring and the team outlines. |
| Neutral body / outline color | `#a0a0a0` / `#707070` | The automatic paddle, which has no gap ring and no face. |
| Face height ratio | 0.72 | Face height as a share of the thickness; the length never stretches it. |
| Name seconds / fade | 5 / 0.6 s | How long names show after each round's START, then fade. |
| Ball and bin colors | `#f4e6ad`; `#fd5d14`, `#0055fa`, `#ac9992` | White balls; Orange, Blue and trash bins. |
| Catch feedback | 0.25 s | Bin brightening after a catch. |
| Wall top / bottom color | `#fbf3e2` / `#efdfc2` | The cream wall's gradient. |
| Prop colors | `#9ed3d0`, `#a9cbea`, `#c9c2ba` | Teal, sky and grey of the factory props. |
| Camera FOV | 30° | The fixed camera's narrow view; it always frames the whole arena. |
| HUD font size | 40 | Scores and clock; the centred cue is three times larger. |

## Expressions

`Expressions.tres` decides when paddle faces change. Faces are presets `face_a` to `face_l` of
the shared face manifest; the workshop offers them by name.

| Field | Default | Effect |
| --- | --- | --- |
| Blink gaps / blink | 2.4–5.6 s / 0.12 s | Natural blinks; shut or crossed-out eyes never blink. |
| Dizzy threshold | 150°/s | Applied turning speed that starts dizziness. |
| Dizzy onset / hold | 0.15 / 0.8 s | How long the speed must last, and how long dizziness stays after. |
| Startled minimum speed | 0.05 widths/s | Closing speed of a new ball contact that startles the hit paddle. |
| Startled seconds | 0.35 | How long the startled face shows. |
| Squash / recovery | 12% / 0.25 s | Drawing-only squash along the thickness, springing back. |
| Play face | `face_a` | Default face during play. |
| Dizzy / startled face | `face_j` / `face_i` | During play, dizzy wins over startled, startled over the play face. |
| Countdown face | `face_e` | During 3, 2, 1 and START. |
| Leading / trailing / tied | `face_f` / `face_k` / `face_a` | At each round's end, by the teams' totals. |
| Winning / losing / draw | `face_f` / `face_k` / `face_a` | At the shift's results, until Return to lobby. |

## Arena coordinates and neighbors

Positions are measured from the arena's top-left; both axes use one arena width. The arena is
`1 × 0.5625` and fills the frame edge to edge; the floor sits the bin band above the bottom.
Neighbors and fairness work as in the 2D Tilt Shift: balanced counts are mandatory, and
same-owner neighbors are minimised within them.
