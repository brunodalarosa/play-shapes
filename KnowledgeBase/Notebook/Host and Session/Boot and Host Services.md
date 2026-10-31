---
area: Host and Session
tags: [system, stub]
code: [host/boot_steps.gd, BootRequest, host/boot_request.gd, host/full_game_boot_request.tres, host/session_host.gd, host/lobby_controller.gd, host/http_service.gd, host/websocket_service.gd]
verified:
branch:
---

# Boot and Host Services

Hub: [[Host and Session]].

Which host script owns what, from boot to the services that outlive scene changes.


- Every launch runs one boot ([[0053-boot-steps-and-entry-points|0053]]).
  `host/boot_steps.gd` names the steps, their order and what each needs. Presets is the one
  Essential step; the others run only when an entry lists them.
- An entry lists its steps in a `BootRequest` (`host/boot_request.gd`), exported as
  `boot_request` on its scene root. `SessionHost` boots the launched scene once it is in the
  tree and logs a failed step. A scene that lists nothing runs the Essential steps only.
- `scenes/boot.*` is the full game. It asks for every step through
  `host/full_game_boot_request.tres`, boots itself and presents Retry after a failure.
- `servers_this_pc` starts HTTP and WebSocket on 127.0.0.1 without TLS or the network file.
- `host/session_host.gd` persists the services and the registry across scene changes. It
  discovers addresses, constructs URLs, and rolls HTTP back if WebSocket binding fails. The
  registry and catalog load on first use, and `steps_run` lists the steps that have run.
- `host/lobby_controller.gd` is what the services call on the lobby world, so naming the
  lobby loads none of its scenes or models.
- A catalog definition may name a `session_script`. SessionHost creates that session on first
  use and lets it prepare players, gate READY and the launch, and follow the roster, from the
  Pre-minigame screen into play ([[0039-minigame-session-scripts|decision 0039]]).
  Tilt Shift 3D uses one.
- `host/http_service.gd` serves a fixed asset allowlist with bounded requests. It never serves
  a client-selected filesystem path.
- `host/websocket_service.gd` owns bounded protocol-1 peers and messages. It resolves each
  connection to a host-owned player before forwarding gameplay input, and keeps one active
  protocol at a time. A minigame can register a `MinigameProtocol` subclass
  (`host/minigame_protocol.gd`): the service then routes the message types it handles to it and
  sends what it asks for, with no minigame-specific code in the service.
- `host/player_registry.gd` owns session, player and token identities, names, validated
  character shape and color, capacity, reconnect grace, resume and explicit leave.
