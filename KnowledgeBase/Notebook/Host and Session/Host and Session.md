---
area: Host and Session
tags: [hub]
code: [host/session_host.gd, host/boot_steps.gd, host/websocket_service.gd, host/http_service.gd, host/player_registry.gd, MinigameProtocol, LobbyController]
verified: 2026-10-31
branch: feature/knowledge-base
---

# Host and Session

Area hub. Parent: [[Notebook]]. The Godot PC host is the single authority: it boots, serves
the phone page, owns every player and routes each message to whoever handles it now.

## Notes

- [[Boot and Host Services]]: boot steps, `SessionHost`, the services and the registry.
- [[Networking]]: how phones reach the host on the LAN, and what to check when they can't.

## Rules

- **Phones send input and choices only.** Anything that decides the game is host state.
- **Every message is resolved to a host-owned player through its connection** before it is
  routed. Never trust an ID the phone sends.
- `SessionHost` is an autoload that outlives scene changes: services, at most ten players,
  reconnect tokens with 60 s grace, the catalog and pre-minigame readiness.
- A scene asks for boot steps with an exported `boot_request`
  ([[0053-boot-steps-and-entry-points|0053]]).
- A minigame's messages go to its `MinigameProtocol` subclass; the WebSocket service has no
  minigame-specific code.

## Gotchas

- **`WebsocketService._lobby_controller` and `SessionHost.register_lobby_controller` are typed
  `LobbyController`**, the small base of `LobbyPlaygroundWorld`, so naming the lobby loads no
  model. Keep it that way.
- Close any running host before the browser suite: it uses ports 18080/18081, and the
  end-to-end test uses 18200/18201.

Architecture: [[Message Protocol]], [[Play Shapes Overview]].
