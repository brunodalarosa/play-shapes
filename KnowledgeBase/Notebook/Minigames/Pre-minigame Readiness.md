---
area: Minigames
tags: [system, stub]
code: [host/pre_minigame_readiness.gd, WebsocketService, scenes/pre_minigame_screen.tscn, assets/runtime/minigames/bubbles_3d/bubbles_3d_preview.png]
verified:
branch:
---

# Pre-minigame Readiness

Hub: [[Minigames]].

Who owns the shared Ready screen before every minigame.


- `host/pre_minigame_readiness.gd` owns one selected round's ordered roster and its ready
  state, keyed by player ID.
- `SessionHost` starts or cancels it, and closes registration before the single launch
  transition.
- `WebsocketService` admits final joins only from onboarding sockets already open at Start,
  resolves ready actions through each registered connection, and sends personalized ready
  snapshots on resume.
- `scenes/pre_minigame_screen.tscn` uses editable Bubbles and jellyfishes 3D content in
  `bubbles_3d_pre_minigame_content.tres`, in the minigame's folder, and a four-player gameplay
  capture in `assets/runtime/minigames/bubbles_3d/bubbles_3d_preview.png`.
- Every normal catalog launch uses this screen. Journey requirements and plan warnings are
  in [[Journey Change Rules|player journeys]].
