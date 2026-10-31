---
area: Minigames
tags: [system, stub]
code: []
verified:
branch:
---

# 004 Phone Screen

Hub: [[004 Bubbles and Jellyfishes]].

The portrait screen shows the exact host jellyfish count above a live 3D view of the
player's bubble. The whole surface accepts touches, including the count. The tinted
Cubio, natural blinking, idle animation, shell stretch, caught jellyfishes and recovery
follow the host state. A water gradient and light rays sit behind the view. Catch and pop
feedback requests optional vibration.

A touch sends a synchronous start and a synchronous release with normalized net
screen displacement. Coarse drag directions send only when changed after 70 ms, with a
600 ms held refresh and a limit of 48 updates per touch. Only an active, connected player
who has not left can send input. Interrupted gestures cancel on pointer loss, page hiding,
blur, rotation, fullscreen or viewport changes.

The renderer loads on the first game snapshot, including resumed gameplay. Lobby return
or another screen disposes it. Rendering pauses while hidden and caps device pixel ratio
at two. If WebGL or model loading fails, the count remains readable above a flat circle in
the player's color, sized by the host radius. See [[Browser Build|browser-build.md]] for the
separate bundle.
