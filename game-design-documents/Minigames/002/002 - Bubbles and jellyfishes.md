## Player facing name
Bubbles and jellyfishes
## Overview
In this underwater minigame the shape characters stays are always inside bubbles, they move around the level with the help of the player that inputs directional force to push the bubble to a direction using swipe controls on their phone. The main objective is to capture as many jellyfishes as possible within the time limit. Captured jellyfishes are trapped inside the player bubble, which gradually increase the bubble size. Players capture jellyfishes simply by colliding with them, so having a bigger bubble means it's easier to capture even more jellyfishes. The bubble stops growing at its maximum visual size, but the player can keep collecting and scoring jellyfishes without a maximum amount. However, jellyfishes aren't the only sea creature in this ocean: Pufferfishes will float around the level, spawning outside the viewport and drifting from one side to the other. If a player bubble collides with a puffer fish they will pop their bubble, including while the player is spinning. The player loses all captured jellyfishes when their bubble pops. A tunable ratio of those jellyfishes is scattered around the pop location so any nearby player, including the player who popped, may recollect them; the rest disappear immediately. A new bubble rapidly forms around the player's shape character. During a tunable invulnerability period the character blinks white, cannot collect jellyfishes, and cannot be popped again. After spawning jellyfishes will wander the level. Players can also bump into each other, which pushes each other to opposite directions. If a player is spinning their bubble however they won't move when bumping into another player and instead shove the other bubble with a tunable amount of additional force. Spinning never pops another player's bubble, and a spinning player otherwise collects jellyfishes and collides with hazards normally. The spinning bubble move has a cooldown.
## Stop condition
Fixed time duration.
## Minigame journey
1. On the normal host-selected path, the shared [[Pre-minigame screen]] presents the preview and instruction booklet. After all players in the selected round are ready, the characters automatically enter the viewport from the left and right sides of the screen and get to their starting positions. The positions are randomly assigned while keeping the same distance from each other. Player collision and player input remain disabled during this entrance. There is no separate in-game instruction card on normal or F12 debug launches.
2. A 3-second countdown plays before the start of the minigame. A tunable starting population of jellyfishes is placed before controls unlock. Player collision and input remain disabled until `GO`.
3. Players inputs are enabled.
4. Jellyfishes start to spawn at safe randomized positions in the screen. Each one grows into view as if approaching from the background and cannot be captured until that entrance animation finishes.
5. Pufferfishes start to spawn outside the viewport and drift across it once before leaving and despawning (any direction: from up to down, from down to up, side to side and diagonally as well). An optional edge warning telegraphs their entry path.
6. The minigame ends when the time duration reaches 0. Gameplay freezes immediately and the host preserves that exact score snapshot before another collision can resolve.
## Shared-screen presentation
Underwater 2D level built from several layered environment assets with gentle parallax and ambient motion. There are no visible boundaries in any corner of the screen, however bumping into any corner will push the player's bubble in the opposite direction, the level is contained in invisible walls that only collide with players, not with NPCs (Jellyfishes, pufferfishes). Jellyfishes may wander out of the arena and despawn. Pufferfishes cross the arena once, leave, and despawn. NPCs pass through one another; pufferfishes collide only with vulnerable player bubbles. Each bubble is a code/shader-built translucent circle that scales cleanly. Its collision radius grows with its visual size, increasing both its collection reach and exposure to pufferfish. Only a capped number of the captured jellyfishes are rendered inside each bubble even when the authoritative count continues higher. Jellyfish and pufferfish use imported static source art with code-driven motion. Bubble popping, re-forming, NPC motion, and other effects use code-driven animation rather than imported VFX sprite sheets. A readable player name follows each bubble; the shared screen does not show live numeric scores. A timer at the top center shows the remaining whole seconds. During the final 10 seconds, progressively larger pulses emphasize each remaining second, with especially strong `3`, `2`, and `1` beats. The emphasis does not depend on color alone.
Every character in the level keeps facing the player.
While a finger drags on the phone, the shared-screen bubble stretches toward the coarse drag direction without moving its collider. The stretch settles when the tunable swipe hold limit passes, even if the finger remains down, to show that the movement opportunity has expired. Circular spin charge adds a faint inner glow that brightens with progress and a continuous bubble wobble; it does not turn the character. Releasing the finger also settles any live deformation. An accepted quick swipe then applies its directional impulse and character push. A touch held longer than the tunable swipe limit produces no impulse. This limit applies only to swipes; a completed spin may take longer.
[[Wireframe_shared_screen.png]] is a wireframe for the shared screen presentation and [[Wireframe_shared_screen captions]] explains the captions in the wireframe.
## Phone controls
Phone in portrait mode. Each minigame owns its phone-orientation requirement; entering this minigame requests portrait orientation, and leaving it restores the orientation required by the next lobby or minigame state.
Swipe controls. 
Swiping in the input area in any direction applies a fixed-strength impulse on release only when the host-measured touch duration is within the tunable swipe limit. Longer drags stretch the shared-screen bubble until that limit, then the stretch settles and release applies no movement impulse. Swiping farther or faster than the minimum recognition threshold does not add more impulse, so short, quick swipes are most effective. Repeated swipes cannot accelerate the bubble beyond a tunable maximum speed. Without new impulses, tunable water drag gradually slows the bubble. Colliding with an invisible wall makes the bubble bounce away according to tunable wall bounciness.
Spinning move: drawing the required circles in one uninterrupted touch gesture charges the spinning move. Clockwise and counterclockwise circles both count. Movement while drawing the circles does not produce directional impulses, and incomplete charge is discarded rather than retained between gestures. Once fully charged, lifting the finger activates the spin. Any momentum from previous impulses is kept, and the player may use directional swipes during the active spin.
## Phone presentation
On the phone the player will see a replica of their character's bubble, rendering captured jellyfishes only up to the same visual cap used on the shared screen. On the top of the screen the exact number of currently captured jellyfishes is displayed. The round timer remains exclusive to the shared screen. To accommodate the increasing size of the bubble the camera will zoom out progressively. A circular meter around the bubble communicates spin charge while the player draws circles, then communicates the move's cooldown after the active spin. Where browser support permits, optional haptic feedback reinforces jellyfish collection, the player's bubble popping, and spin activation; gameplay never depends on vibration.
The whole screen is the input area, even the label on top.
## Character appearance
The shared screen and phone use the approved Squircle v1 rendered character sprites. Every player has the same Squircle body silhouette; the selected color tint distinguishes players. Keep the character readable inside the bubble and mirror its host-owned visual state on the phone.
[[Wireframe_phone_screen.png]] is a wireframe for the phone screen presentation.
## Difficulty progression
The spawn rate of pufferfishes increases as time goes on. The spawn rate of jellyfishes follows a wave pattern, alternating randomized high- and low-spawn periods whose rates and durations remain within tunable ranges. A tunable maximum limits how many free jellyfishes may be active simultaneously.
## Round ending and ranking
Round ends when the time duration ends. The host freezes gameplay immediately at zero and ranks players using their current number of captured jellyfishes in that final snapshot. Players with the same count share the same rank.
## Results
Show every player in ranking order with their rank, name, shape character, and final jellyfish count. No elaborate winner celebration is required for the first implementation.
## Lobby and debug flow
Normal play starts Bubbles and Jellyfishes from the lobby through [[Pre-minigame screen]]. `Return to lobby` preserves registered players. The F12 debug launcher provides a separate one-real-player Bubbles and Jellyfishes scenario that bypasses the pre-minigame screen. A polished minigame menu, automatic playlist, and random selection are deferred.
## Audio and feedback
A single background music track plays throughout the minigame for the first implementation. The minimum sound set covers jellyfish collection, bubble pop, bubble re-forming, spin fully charged, spin activation, player collision/shove, countdown beats, and the final seconds. The pufferfish entry warning is visual only. Neither the shared screen nor phone uses screen shake.
## Asset requirements
All imagery in the wireframes is placeholder reference only and is not approved runtime art. The minigame requires separately supplied and imported layered underwater environment art, jellyfish art, and pufferfish art. Jellyfish and pufferfish may use static source images because their motion is procedural. The scalable bubble, pop/re-form effects, circular meters, pufferfish warning, timer treatment, and results UI are code-built and require no imported visual assets. The shared instruction booklet belongs to [[Pre-minigame screen]]. Audio requires one separately supplied and imported background music track plus a supplied and imported SFX set covering the cues listed above.
## Designer-tunable values
* Minigame time duration
* Starting size of the bubble
* Max size of the bubble
* Bubble size increment for each jellyfish
* Maximum number of captured jellyfish sprites rendered inside a bubble
* Jellyfish collider size
* Pufferfish collider size
* Start spawn rate for pufferfish
* Max spawn rate for pufferfish
* Pufferfish speed
* Start spawn rate for jellyfish
* Max spawn rate for jellyfish
* High- and low-spawn period duration ranges for jellyfish waves
* Maximum number of free jellyfishes in the arena
* Starting jellyfish population
* Jellyfish speed
* Jellyfish safe spawn radius around players and hazards
* Jellyfish entrance animation duration
* Released-jellyfish collection lockout duration
* Swipe impulse force value
* Minimum swipe recognition distance
* Maximum swipe touch duration before the impulse is canceled
* Live shared-screen drag stretch and response time
* Shared-screen spin-charge glow and wobble strength
* Maximum player bubble speed
* Water drag
* Wall bounciness
* Bubble mass increase as it grows
* Bubble speed reduction as it grows
* Active spinning move duration
* Spinning move cooldown
* Number of circles to fully charge spinning move
* Circle recognition tolerance
* Additional player shove force while spinning
* Ratio of jellyfish that disappear when a bubble bursts
* Post-pop invulnerability duration
* Pufferfish edge warning enabled
* Pufferfish edge warning duration
* Final timer emphasis threshold (10 seconds by default)

## Answered decisions

Confirmed by the project owner on 2026-09-22:

* A pop removes every jellyfish from the player's current score. A tunable ratio of those jellyfishes disappears; the remainder scatters around the pop location and can be collected again.
* The re-forming bubble is briefly invulnerable and cannot collect jellyfishes. The shape character blinks white throughout this tunable i-frame period.
* Spinning prevents player-to-player knockback and adds a tunable amount of shove force against the other player. It cannot pop another player's bubble.
* Spinning does not protect against pufferfish and does not otherwise disable jellyfish collection or hazard collisions.
* Bubble growth has a maximum visual size, but there is no maximum jellyfish count. Collecting continues to increase the player's score after the bubble reaches maximum size.
* Final ranking uses the number of jellyfishes currently held when time expires. A last-second pop may therefore dramatically change the ranking.
* Every valid directional swipe released within the tunable touch duration applies the same impulse regardless of swipe length or speed beyond the minimum recognition threshold. Slow drags deform the shared-screen bubble until that limit, then the stretch settles and release has no impulse. Player bubbles have a tunable maximum speed and tunable water drag.
* Invisible walls bounce player bubbles back into the arena with tunable bounciness.
* A spin must be fully charged during one uninterrupted touch gesture. Either circular direction counts, circle drawing produces no directional impulses, and partial charge never persists between gestures.
* A fully charged spin activates when the player lifts their finger. Directional swipes remain available during the active spin.
* The phone uses a circular meter around the player's bubble to show spin charge and then cooldown.
* Normal play supports 2–10 players. One-player play remains available only through debug mode.
* Jellyfishes and pufferfishes may leave the arena and despawn. Each pufferfish crosses the arena once. NPCs ignore one another, and pufferfishes collide only with vulnerable player bubbles.
* Jellyfishes spawn immediately at positions outside a small tunable safe radius around players and hazards. A grow animation makes each new jellyfish appear to approach from the background; it cannot be captured until the animation ends.
* Pufferfish entry may be telegraphed at the arena edge. A tunable boolean enables or disables this warning for testing. Spawn paths do not guarantee a minimum player reaction time.
* Jellyfish waves alternate high- and low-spawn periods with randomized rates and durations inside tunable ranges. A tunable maximum caps the number of free jellyfishes present at once.
* Larger bubbles gain mass and move more slowly according to tunable scaling values.
* Recollectable jellyfishes scattered by a pop have a short tunable collection lockout and blink white until they become collectible.
* A bubble's collision radius grows with its visual size. Only a capped number of captured jellyfish sprites are rendered; collection and scoring continue beyond that visual cap.
* The shared screen identifies each bubble by player name but does not show live numeric scores. Each phone shows its own exact authoritative score.
* Player collision and input are disabled during the entrance and countdown. A tunable starting population of jellyfishes is present when controls unlock at `GO`.
* A temporarily disconnected player's bubble remains in the arena and continues drifting under normal physics. An explicit leave pops the bubble and releases jellyfishes under the normal pop rules.
* Players tied on final jellyfish count share the same rank.
* At zero seconds gameplay freezes immediately before any additional collision resolves. The shared screen timer sits at the top center, displays remaining seconds, and becomes more expressive during the final 10 seconds.
* Results show every player's rank, name, shape character, and final jellyfish count without an elaborate winner celebration in the first implementation.
* A temporarily disconnected player behaves like a controller left unattended: no new inputs occur, but the bubble remains fully in play. It continues drifting, collecting jellyfishes, colliding with pufferfishes, and interacting with other players.
* The shared [[Pre-minigame screen]] booklet replaces the in-game instruction card. Normal play continues into the entrance and countdown after readiness; F12 debug bypasses the ready screen. No in-game instruction card is shown on either launch path. The round timer appears only on the shared screen, with progressively larger pulses during the final 10 seconds and stronger `3`, `2`, and `1` beats.
* The first implementation uses one continuous background music track and sound effects for collection, bubble pop and re-forming, spin charge and activation, player collision/shove, countdown, and final seconds.
* The pufferfish warning is visual only. White blinking remains the sole added visual treatment for post-pop invulnerability and released-jellyfish collection lockout; no lock icon or transparency change is added.
* Optional haptic feedback may reinforce collection, the local player's bubble pop, and spin activation where supported, but vibration is never required feedback. No screen shake is used.
* Wireframe imagery is placeholder-only. Runtime art uses separately prepared layered underwater environment, jellyfish, and pufferfish assets.
* The environment uses several layers with gentle parallax. The bubble is a scalable code/shader-built translucent circle. Static creature art receives procedural motion, and pop/re-form effects and UI graphics are code-built.
* The owner supplies BGM and the complete SFX set for import into the runtime.
* Phone orientation is minigame-specific. This minigame requests portrait and restores the appropriate orientation when transitioning away.
* The lobby uses a temporary minigame-selection dropdown. Return preserves the registered lobby, and F12 provides a separate one-player debug scenario. Better minigame menus and automatic sequencing are deferred.

## Deferred decisions

* Final numeric tuning values remain provisional until human playtesting.
* The owner chooses the final environment, jellyfish, pufferfish, BGM, and SFX assets.
* A polished minigame selection menu, automatic playlist, and random minigame selection are later design work.
* Optional haptics remain best-effort because browser/device support differs.

## Validation needs

* Deterministic automated coverage for lifecycle, scoring, ties, zero-time freeze, spawn limits, pop/release rules, disconnect/leave behavior, and tuning bounds.
* Boundary-heavy browser tests for swipe-versus-circle recognition, one-gesture spin charge, release activation, pointer cancellation, portrait layout, reconnect snapshots, and unsupported orientation/haptics fallbacks.
* Godot editor/runtime checks for scene load, collisions, visual caps, layered environment composition, warning toggles, timer emphasis, audio events, results, lobby return, and one-player debug entry.
* Performance/readability checks with simulated states through the supported 10-player minigame range and maximum configured free/visible jellyfish counts.
* Physical-phone validation on the existing iPhone Safari and Android Chrome pair for portrait orientation, gesture reliability, latency, haptics where supported, and reconnect behavior.
* Human play approval for movement feel, spin recognition, collision fairness, pufferfish warning readability, difficulty curve, scoring drama, couch-distance readability, audio balance, and fun. Automated results do not satisfy these judgments.
* Exported-build verification remains separate from editor/runtime proof and is required before claiming the minigame works in the standalone package.
