## Player facing name

Bubbles and jellyfishes 3D

## Overview

Minigame 004 rebuilds [[docs/game-design-documents/Minigames/002/002 - Bubbles and jellyfishes]] from scratch in the 3D low-poly world. Each Shape Character floats inside a bubble that the player pushes with swipes on their phone. Players catch jellyfishes by touching them, and each catch grows the bubble. Pufferfishes cross the arena and pop the bubbles they touch.

004 plays exactly like 002 except that the spin move does not exist: no circle gesture, no charge, no spin shove, no spin meter and no spin feedback. Everything else in 002's rules carries over, as written below.

004 sits beside 002 in the lobby so the two versions can be compared. Once the owner approves 004, 002 is retired the way 001 was, and its number is never reused.

## Identity and independence

- Number 004, catalog ID `bubbles_3d`, display name "Bubbles and jellyfishes 3D".
- Code in `minigames/004_3d_bubbles/`, main scene `3d_bubbles.tscn`, phone code in `web/src/004_3d_bubbles/`.
- 004 may copy and adapt 002's code, but never imports, preloads or references 002's scripts, scenes, resources, tuning or protocol. Deleting 002's folder and phone module must not break 004.
- Where a piece is useful beyond this minigame, it is built as a reusable component outside the minigame folder. See [Reusable components](#reusable-components).
- 002 stays untouched, spin included.

## Stop condition

Fixed time duration.

## Minigame journey

1. On the normal host-selected path, the shared [[docs/game-design-documents/Player journeys/Pre-minigame screen]] presents the preview and instruction booklet. After all players are ready, the bubbles enter from the left and right sides of the screen and move to evenly spaced, randomly assigned starting positions. Collision and input stay disabled during the entrance.
2. A 3-second countdown plays. A tunable starting population of jellyfishes is placed before controls unlock. Collision and input stay disabled until `GO`.
3. Player input is enabled.
4. Jellyfishes spawn at safe randomized positions and grow into view as if approaching from the background. They cannot be caught until that entrance animation finishes.
5. Pufferfishes spawn outside the view and cross it once in any direction (horizontal, vertical or diagonal), then leave and despawn. An optional edge warning telegraphs their entry.
6. The round ends when the timer reaches 0. Gameplay freezes immediately and the host keeps that exact score snapshot before any further collision resolves.

## Rules

- Catching: a bubble catches a jellyfish on contact and grows by a tunable amount, up to a maximum visual size. Catching and scoring continue past the maximum size.
- Popping: a pufferfish pops a vulnerable bubble on contact. The player loses every caught jellyfish. A tunable ratio disappears and the rest scatter around the pop point, where anyone, including the popped player, may catch them again after a short tunable lockout. Scattered jellyfishes blink white during the lockout.
- Re-forming: a new bubble forms around the character at once. During a tunable invulnerability period the character blinks white, cannot catch jellyfishes and cannot be popped.
- Bumping: bubbles bounce off each other in opposite directions. There is no other player-versus-player action.
- Walls: invisible walls at the screen edges bounce bubbles back with tunable bounciness. They affect bubbles only; jellyfishes and pufferfishes pass through, and may leave and despawn.
- NPCs ignore each other. Pufferfishes interact only with vulnerable bubbles.
- Larger bubbles gain mass and move more slowly, by tunable amounts. The collision radius always equals the visual radius.
- A temporarily disconnected player's bubble stays fully in play and keeps drifting. An explicit leave pops the bubble under the normal pop rules.

## Simulation and world scale

The host simulates 004 with Godot's 3D physics (Jolt), not with 2D physics mirrored into 3D. Bubbles, NPCs and walls live on one vertical gameplay plane at depth zero; every body's depth axis and rotation are locked so nothing leaves the plane. This differs from the 3D lobby, which mirrors a 2D simulation ([decision 0033](../../../decisions/0033-plaza-lobby-plane-simulation.md)), and is recorded as its own decision record when built.

One world unit equals 100 pixels of 002's 1920 × 1080 arena. The playable plane is 19.2 × 10.8 units, centred on the origin, and 002's tuned distances and speeds carry over divided by 100 as starting values.

## Shared-screen presentation

See [[004 - Scene composition]] for the full scene layout and [[004 - Asset sources]] for every model's source. The approved composition references are [the 5-player mockup](references/mockup-5-players.jpg) and [the 10-player mockup](references/mockup-10-players.jpg); they guide layout and readability, not exact sizes, which come from tuning.

- Camera: fixed, near-frontal perspective with a narrow field of view (about 30°), framing the 19.2 × 10.8 playable plane edge to edge at 16:9. Wider screens show more background; the walls stay at the plane's edges.
- Water: a shader-driven backdrop with a cyan-to-deep-blue depth gradient, a bright rippling surface band at the top, animated god rays fanning down from the top centre, caustic shimmer on the seabed, distance haze and rising air-bubble particles. No paper or craft texture.
- Background: a quiet, faded seabed with recoloured coral, swaying kelp, rocks, an oversized mug and a large bottle, far behind the plane and low in the frame. No foreground props.
- Bubble: a translucent sphere shader with a bright rim, a soft iridescent sheen and a highlight. The character and up to a tunable cap of caught jellyfishes are visible inside it.
- While a finger drags, the bubble stretches toward the coarse drag direction without moving its collider. The stretch settles once the swipe hold limit passes, even if the finger stays down, and on release.
- Pop: the bubble bursts into droplet particles; re-forming grows a new bubble around the character. These effects are code-driven.
- A readable player name follows each bubble as screen UI. The shared screen shows no live scores.
- A timer at the top centre shows the remaining whole seconds. During the final 10 seconds, progressively larger pulses mark each second, strongest on `3`, `2` and `1`, without relying on colour alone.
- The Squircle and the jellyfishes always face the camera. Pufferfishes turn to face their direction of travel, showing their side profile and tilting up or down by at most 35° on diagonal paths.

## Character appearance

The shared screen and the phone both use the real-time 3D Squircle: the same exported model, player tint, face and natural blink used by the 3D lobby. Inside the bubble the Squircle plays its Idle clip with a code-driven bob, a lean toward its velocity and a gentle hand wobble, always facing the camera. No new animation is authored for this minigame.

## Phone controls

Portrait orientation. The whole screen is the input area, including the label at the top.

Swiping in any direction applies a fixed-strength impulse on release, but only if the host-measured touch lasted no longer than the tunable swipe limit. A longer drag stretches the shared-screen bubble until that limit, then the stretch settles and the release applies nothing. Swiping farther or faster than the minimum recognition distance adds no strength, so short, quick swipes work best.

Repeated swipes cannot push a bubble beyond a tunable maximum speed. Without new swipes, tunable water drag slows the bubble. Circles and other shapes have no special meaning: every touch follows the swipe rules above.

## Phone presentation

The phone renders its player's own bubble in real-time 3D in the browser, with three.js, using the same 3D models as the host: the tinted Squircle with its face and blink, the bubble shader ported to the browser, and caught jellyfishes up to the same visual cap. Behind them is a simple animated water gradient with light rays.

- The exact number of caught jellyfishes is shown at the top. The round timer stays on the shared screen only.
- The camera zooms out progressively as the bubble grows.
- The phone shows pops and re-forming as well.
- Where the browser supports it, optional haptics mark a catch and the player's own pop. Gameplay never depends on vibration.
- No spin meter or circle animation exists.

## Pre-minigame booklet

- Title: "Bubbles and jellyfishes 3D".
- Controls: "Swipe and release to nudge your bubble."
- Win condition: "Catch the most jellyfishes. Pufferfish pop bubbles and spill your catch!"
- Hints: "Big bubbles catch more but are easier to pop. Bump other bubbles to push them away."
- Preview image: temporarily the existing `assets/runtime/pre_minigame/bubbles_preview.png`, until the owner supplies a 3D screenshot. The 3D build does not replace it.

## Difficulty progression

The pufferfish spawn rate rises over the round. Jellyfish spawning follows waves that alternate randomized high- and low-rate periods within tunable ranges. A tunable maximum caps how many free jellyfishes exist at once.

## Round ending and ranking

The round ends when time runs out. The host freezes gameplay at zero and ranks players by the jellyfishes they hold in that final snapshot. Ties share a rank.

## Results

Every player in ranking order with rank, name, Shape Character and final jellyfish count. No elaborate winner celebration.

## Lobby and debug flow

004 appears in the lobby's minigame dropdown beside 002 and 003 and starts through the Pre-minigame screen like every normal launch. `Return to lobby` keeps registered players. The F12 debug launcher gains a one-player 004 scenario that skips the Pre-minigame screen, like 002's.

## Audio and feedback

004 reuses 002's shared audio files: `Beach_music.ogg` as background music, and the existing cues for catching, popping, re-forming, bumping, the countdown and the final seconds. The spin-charge and spin-activation cues are not used. The pufferfish warning is visual only. No screen shake.

## Reusable components

These are built outside `minigames/004_3d_bubbles/` so later 3D scenes and minigames can use them:

- A bubble shell: the translucent sphere with stretch, pop and re-form, configurable radius and tint, for Godot.
- An underwater environment: the water backdrop, god rays, caustics, haze and rising bubbles, as one scene with tunable parameters.
- A plane-locked 3D body setup: depth and rotation locks plus edge walls that collide with chosen layers only.
- A screen-space label that follows a 3D node, for nameplates.
- On the phone: a small three.js viewport module with GLB loading, a 3D Squircle renderer (tint, face, blink, Idle) and the bubble shader port, reusable by later phone screens.

## Designer-tunable values

Distances and speeds are in world units; 002's defaults divided by 100 are the starting values.

* Minigame time duration
* Starting, maximum and per-jellyfish growth of the bubble radius
* Maximum number of caught jellyfishes rendered inside a bubble
* Jellyfish and pufferfish collider sizes
* Start and maximum pufferfish spawn rates, and pufferfish speed
* Start and maximum jellyfish spawn rates, wave period ranges and the free-jellyfish cap
* Starting jellyfish population, jellyfish speed and safe spawn radius
* Jellyfish entrance duration and released-jellyfish lockout
* Swipe impulse, minimum swipe distance and maximum swipe hold
* Live drag stretch strength and response time
* Maximum bubble speed, water drag and wall bounciness
* Mass increase and speed reduction as the bubble grows
* Ratio of jellyfishes that disappear on a pop
* Post-pop invulnerability and re-form durations
* Pufferfish edge warning on or off, and its duration
* Final timer emphasis threshold (10 seconds by default)
* Squircle bob, lean and hand-wobble amounts inside the bubble
* Water look: gradient colours, god-ray strength and speed, caustic strength, haze distance, air-bubble rate
* Music and effect volumes

## Answered decisions

Confirmed by the project owner on 2026-10-17:

* 004 is a new minigame beside 002, built from scratch and independent of 002's code; reusable pieces become shared components.
* The spin move is removed entirely, as mechanic, gesture, phone meter, feedback, sounds and booklet text.
* Gameplay otherwise matches 002, including its answered decisions on pops, i-frames, bumping, walls, waves, ties, the zero-time freeze, disconnects and the hidden live score.
* The host uses 3D physics with locked depth and rotation, not a mirrored 2D simulation.
* Camera: fixed, near-frontal, narrow perspective.
* The bubble is a translucent shader sphere, not a modelled asset.
* The Squircle uses its existing Idle clip with code-driven motion inside the bubble.
* The jellyfish is pink with two dot eyes, curly-tipped tentacles and a soft translucent rim glow.
* The background combines natural reef with a few oversized sunken everyday objects, faded and behind play, with no foreground props.
* The phone renders the 3D assets in real time with three.js.
* The booklet text above replaces any spin explanation. The preview image is not replaced as part of the build.
* 004 gets an F12 one-player scenario.
* After the owner approves 004, 002 is retired and removed.

## Deferred decisions

* Final numeric tuning, after human play.
* A 3D preview screenshot for the Pre-minigame screen.
* A dedicated floating animation for the Squircle, which can replace Idle later.

## Validation needs

* Deterministic automated coverage carried over from 002 minus spin: lifecycle, scoring, ties, zero-time freeze, spawn limits, pop and release, disconnect and leave, tuning bounds, and that no spin message or state exists.
* Automated checks that 004 never references 002's files.
* Browser tests for swipe-only input, portrait layout, reconnect snapshots and three.js rendering with a fallback when WebGL is unavailable.
* Godot runtime checks for scene load, plane locks, collisions, visual caps, the water shaders in the Compatibility renderer, timer emphasis, audio, results, lobby return and the F12 entry.
* Performance with ten players and the maximum free and visible jellyfishes, on the host and on a phone.
* Physical-phone validation on the iPhone Safari and Android Chrome pair: rendering, frame rate, gesture reliability, latency and haptics.
* Human play approval of movement feel, readability at couch distance, the underwater look, and fun, compared side by side with 002.
* Exported-build verification of 004, including the phone's model downloads.
