# Tilt Shift rules and content tuning

Select a rules Resource in `Tuning/Active Presets.tres`, under Tilt Shift. The host consumer
injects it into the controller. Editing it during a shift does not rewrite frozen live
content; relaunch the shift to apply changes.

The Godot **Tilt Shift** tab provides snapped editing, named saves, geometry guides and
actual gameplay preview. See [the editor workshop workflow](WORKSHOP.md).

## Provisional profile

| Field | Default | Units / safe range | Effect |
| --- | --- | --- | --- |
| Round duration | 45 | Seconds, 1–300 | Higher allows more play before the immediate scoring cutoff. |
| Round count | 4 | Integer, 1–24 | Higher lengthens a shift; edit the round mapping alongside it. |
| Neighbor distance | 0.24 | Arena-width units, 0.01–2 | Higher asks the allocator to separate more nearby paddles. |
| Paddle layout | `layouts/Mirrored.tres` | One selected Resource | Ten stable anchors in four rows, five per team. |
| Baskets by round | `baskets/FiveOpenings.tres` repeated four times | One valid entry per numbered round | Five touching openings cover the stage: Orange/Blue/trash/Orange/Blue. |

Values are provisional. Owner play chooses duration, shift length and useful separation.
The profile selects `Physics.tres` for arena geometry, contact materials and delivery.
See [the physics field guide](PHYSICS.md). The selected `Motion.tres` profile supplies
[calibrated motion tuning](MOTION.md). `Presentation.tres` controls the cosmetic factory
view described in [the presentation contract](../README.md#factory-presentation).
It is copied by the presentation at launch and does not alter frozen gameplay content.

The selected `Flow.tres` controls intermission and phone update rate; see
[flow tuning](FLOW.md). `ThreeOpenings.tres` supplies a distinct mirrored basket comparison
alongside the unchanged five-opening default.

## Arena coordinates and neighbors

Positions are measured from the arena's top-left. Both axes use the same unit: one default
arena width. The example arena is `Vector2(1, 0.5625)`, independent of viewport dimensions.
The arena uses 1,000 world units per coordinate unit. Fit the view with a camera;
do not scale or move the active physical subtree to resize the screen.

Centers are neighbors when their Euclidean distance is less than or equal to
`neighbor_distance`, including vertical and diagonal pairs. Snapshots return each pair's
IDs and distance alongside the threshold. The workshop can draw this same graph.

Balanced counts are mandatory; separation is optimized within them. Closeness stays
diagnostic and never moves a paddle. This graph does not certify swept collider clearance,
physical routing or strategic fairness.

## Numbered rounds and fairness cycles

Entry zero selects round one. Exactly `round_count` non-null valid basket presets are
required. A missing/surplus mapping fails before launch with expected and actual counts.

Extra shares rotate over two rounds for two teammates, three for three teammates and
four for four teammates. Complete cycles give equal cumulative shares. Partial cycles
can leave players one extra-share round apart; the default four rounds do not complete
the three-teammate cycle. Teams and paddle positions stay fixed throughout the shift.

## Basket validity

Centers/widths share the layout's arena units, and floor width must match the arena.
Every Orange opening needs a reflected Blue opening of equal width. Off-center trash
needs reflected trash; center trash reflects to itself. Basket count is configurable.

Reflection and touching-opening tolerance is `0.00001` coordinate units for float precision,
not a fairness control. Missing references, duplicate IDs, non-finite geometry,
nonpositive widths, overlaps, out-of-bounds openings and missing reflections fail
validation. Drafts can be edited but cannot launch until valid.

Duplicate `Default.tres` to compare profiles, or duplicate named layout/basket assets
and point a profile at them. Preserve stable IDs when rearranging a layout. Save/reload
and run [focused checks](../../../docs/verification.md#focused-checks-by-area).
Tests certify configuration/rule safety; owner play certifies feel.
