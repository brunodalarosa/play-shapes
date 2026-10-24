# Bubbles and jellyfishes 3D tuning

Every game-feel value of minigame 004 is in one `Bubbles3DTuning` resource. `Default.tres`
holds provisional values, not approved feel: the retired 002's tuned values divided by 100,
since one world unit is 100 pixels of its arena.

## Changing a value

1. In the Godot editor, duplicate `Default.tres` beside it under a descriptive name, such as
   `Faster swipes.tres`.
2. Open the copy and change one group of values. Hover a field for its unit, default, safe
   range and what a higher value does.
3. Open `Tuning/Active Presets.tres`, set **Bubbles 3D** to the copy, save and relaunch.
4. To go back, set **Bubbles 3D** to `Default.tres` again.

Each field clamps to its safe range. `tests/tuning_presets_test.gd` checks every committed
preset, so a preset that breaks a rule below fails the check.

## The groups

- **Round lifecycle**: entrance, countdown and round length.
- **Player bubble**: starting and largest radius, growth per catch, how many caught
  jellyfishes are drawn, and how much heavier and slower a big bubble gets.
- **Movement and swipes**: swipe strength, the longest hold that still moves, the shortest
  recognised swipe, the speed cap, water drag, and wall and bump bounciness.
- **Jellyfish**: size, breathing, starting and largest population, wave rates and lengths,
  wandering speed, spawn clearance, entrance and the lockout after a pop.
- **Pufferfish and pop**: size, wobble, spawn rates at the start and end, speed, how much of a
  catch vanishes on a pop, invulnerability, re-form time and the edge warning.
- **Presentation**: the Cubio's size, bob, lean and hand drift inside the bubble, swipe and
  drag stretch, pop droplets and the final-seconds timer pulses.
- **Water look**: water colours, god rays, caustics, haze distances and air bubbles.
- **Audio**: music and effect levels.

## Rules between values

- The largest radius must exceed the starting radius.
- The starting population cannot exceed the free-jellyfish cap.
- Low wave rates and the shortest wave cannot exceed the high rates and the longest wave.
- The start pufferfish rate cannot exceed the end rate.
- The haze must end beyond where it begins; it should begin beyond the gameplay plane, about
  20 units from the camera, so the play objects never fade.
- Wall bounciness must be at least half the bump bounciness. Godot adds the bounce of the two
  bodies in a contact, so each bubble carries half the bump bounciness and the walls the rest
  ([decision 0034](../../../docs/decisions/0034-bubbles-3d-jolt-plane.md)).

Only the owner promotes a tried value into `Default.tres`.
