# 0053. Every launch runs one boot made of Essential and Optional steps

Decided by the owner on 2026-10-28, for the full game and every scene started on its own.

## Situation

Workshops ([0052](0052-a-workshop-for-every-minigame.md)) start as a scene of their own, not
through the full game. Every launch, even of a single scene, loaded the minigame catalog and
the lobby's Cubio model, because the host service named them up front. The owner wanted
workshops to load fast and skip what they do not use.

## Decision

One boot runs on every launch, made of the steps in `host/boot_steps.gd`. Essential steps
always run; today that is only the Active Presets. Every other step is Optional: the player
registry, the minigame catalog, the network file, the certificate, the servers and the lobby.

An entry asks for Optional steps with a `BootRequest` in a `boot_request` property on its
scene's root, and each step brings the steps it needs. A scene that asks for nothing gets the
Essential steps only. The full game, `scenes/boot.tscn`, asks for every step.

## What follows

- A workshop can ask for the servers bound to this PC only, with no certificate, so its phone
  view runs without the local network file.
- A scene started on its own logs a failed step and carries on. The full game keeps its error
  screen with Retry.
- The registry and catalog also load on first use, so code that reads them still works in a
  scene that did not list them; the boot records each step once.
- Host services name the lobby through the small `LobbyController` base, never through the
  lobby world, so naming it loads no scene or model.
- A new step is a name in `BootSteps`, its needs and its case in `SessionHost._run_step`.
