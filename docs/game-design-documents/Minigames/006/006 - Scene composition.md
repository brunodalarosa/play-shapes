# 006 scene composition

How the crystal-cave course of [[006 - Flappy Race]] is put together, on the shared screen and on the phone. Model sources and their changes are in [[006 - Asset sources]].

## Intended player experience

A bright, cheerful crystal cave that winged Cubios race through, threading the gap between a stalactite and a stalagmite again and again. Obstacles read instantly as solid stone; the gap is always the clearest shape on screen. The cave feels magical, never dark.

## Approved composition reference

![Shared screen](references/mockup-cave-shared.jpg)

![Phone](references/mockup-cave-phone.jpg)

The mockups are approved for layout, readability and mood. Gap sizes, crystal placement, colours and background detail are illustrative; the course generator and tuning set the real geometry, and the background is quieter in the game than in the mockup. The speed pickup is a golden coin, not the gold crystal the mockup shows.

## Gameplay space and camera

- Play happens on one vertical plane at depth zero: Cubios move right and up and down; obstacles sit on the plane.
- The ground line is the bottom of the play space. There is no ceiling: the view height is 34 m above the ground, and the cave roof is never shown.
- Obstacles come in pairs at the same position along the course: a stalactite from beyond the top of the view down to the gap, and a ground obstacle from the floor up to it.
- Shared screen: a near-frontal, narrow perspective that follows the leader at about 65% of the width and zooms out to a visible height of up to 54 m. Hanging obstacles still pass the top edge at that zoom.
- Phone: portrait, following its own Cubio, always showing the full 34 m from the ground to the top of the view.
- Timer, place badges, names, bubbles, hearts and the progress bar are screen UI.

## Layers, back to front

| Layer | Content | Notes |
| --- | --- | --- |
| Cave air | Soft vertical gradient, light lavender-blue to warm cream, faint light shafts | Fills the top of the view between obstacles |
| Far walls | Layered cave walls and arches, crystal clusters, a calm pool | Faded, low contrast, slow parallax |
| Near walls | A closer layer of wall pieces, mushrooms, crystal clusters | Still behind the plane, softer than play |
| Gameplay plane | Columns, rock stacks, crystal clusters, coins, Cubios, hearts, start gate, finish arch, podium | The only fully saturated, high-contrast layer |
| Floor | Sandy floor strip with pebbles and small crystals over darker rock | On the plane's ground line; its front edge reaches the bottom of the frame |

The phone shows the cave air, one light far layer, the gameplay plane and the floor, to stay light.

## Asset placement and repetition

| Scene role | Asset | Placement / scale | Repetition | Gameplay relevance |
| --- | --- | --- | --- | --- |
| Stalactite | Column build, flipped | Top of each pair; 5–7 m wide; from the gap to beyond the view | One per pair | Generator boxes |
| Ground obstacle | Stalagmite build, rock stack or crystal cluster | Bottom of each pair; same width | One per pair, mostly stalagmites | Generator boxes |
| Crystals | Crystal builder | Rooted in column surfaces, floor and walls | A few large clusters per column | None, except a cluster obstacle |
| Speed pickup | Coin | Inside a gap, close to an obstacle edge; about 1.6 m | Per the pickup curve | Per-player trigger |
| Respawn heart | Heart, player colour | At a respawn spot; about 2 m | One per waiting player | Phone tap target |
| Cubio | Existing model, hands as wings | On the plane, each in its own thin depth slot | 1–10 | Body cube hit box |
| Start gate | Arch of column pieces | Point A | 1 | None |
| Finish arch | Arch with a checkered band | Point B | 1 | Finish line is a course position |
| Podium | Three raised steps and one low step | Past the finish arch, on the floor | 1 | Finishers' resting spots |
| Mushrooms | Recoloured mushroom | Near walls and floor edges | A few per screen | None |

## Readability and priorities for the first iteration

- The gap between each pair is the clearest shape on screen: no dressing reaches into it.
- Stone stays warm and sandy, so every Cubio colour, purple included, stands out against it and against the lavender walls.
- Background walls stay faded and low contrast; they never read as obstacles.
- First iteration: columns, rock stacks, crystals on columns, the floor, coins, hearts, the arches and the podium. The pool, light shafts and mushrooms can follow.

## Reuse and variants

- One set of column pieces builds every stalactite, stalagmite and both arches.
- One crystal builder dresses columns, the floor, the walls and the podium on host and phone.
- `mountain_B` serves as a rock stack in sandy stone and as a wall piece in lavender, as separate recoloured copies.
- The heart is tinted per player at runtime from one copy.

## Human review

The owner judges in the running game:

- Obstacles read as natural stone, not pipes or towers, and the columns show no seams.
- Gaps are always readable at both zoom limits and on the phone.
- The cave feels bright and cheerful, and every Cubio colour reads against it.
- The coin reads as a power-up.

Technical import and runtime checks are listed in [[006 - Asset sources]].
