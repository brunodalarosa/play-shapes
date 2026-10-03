# Overview and running

This is the compact implementation manual for the current checkout. It records how the project works now, how to run and verify it, and operational caveats that are easy to rediscover.

## Current status

- Godot 4.7.2 is the authoritative host; phone controllers are bundled HTML/CSS/JavaScript clients over local HTTP and WebSockets.
- The lobby opens a shared ready screen for **Bubbles and Jellyfishes** with 2–10 registered players. Bubbles starts after every current participant is ready.
- Registered players appear as Squircle v1 characters in the Playground lobby and steer them from a portrait phone stick and release-action button; near-vertical input reaches/crouches, and FALL descends Open supports. Squircle v1 is also the current character in Minigame 002 and phone setup.
- F12 provides a one-real-player Bubbles debug scenario, the Squircle Animation Lab, and the Gyroscope and Accelerometer Lab. It creates no simulated player; Bubbles labels its debug round on the host and phone.
- The host defaults to a responsive 1920×1080 GL Compatibility presentation.
- **Project > Tools > Build Standalone Host** creates a portable Windows x86_64 release ZIP. Linux is deliberately deferred.
- Bubbles still needs the owner's two-phone and game-feel review; automated evidence does not establish device, browser, network, accessibility, or feel approval.

## Documentation

This repository contains the Godot project, browser client, bundled runtime assets, tests, and tooling. See [README.md](../README.md) for setup, [AGENTS.md](../AGENTS.md) for contributor guidance, and [Tuning/README.md](../Tuning/README.md) for tuning.

## Project location and running

Run Git, Godot, browser build, and tests from this repository root. `project.godot` must remain at its root.

```powershell
godot --version
godot --path .
```

Use **F5** for the complete boot/lobby flow. Use **F6** only when an individual scene is designed for direct execution. Use `GODOT_BIN` when Godot is not on PATH.

In the lobby, choose a reachable Wi-Fi/Ethernet IPv4 address, then scan the QR or type the displayed URL on a phone on the same LAN. Discovery runs at launch and on Refresh; it prefers common `192.168.*` addresses but is not default-route detection. Loopback, link-local, and IPv6 addresses are excluded. VPNs, multiple adapters, guest Wi-Fi, and client isolation can require a manual choice or prevent access.

Normal play starts with 2–10 registered players. Choose a minigame from the lobby dropdown before starting. For debug, register exactly one phone, press F12, and choose the matching one-player scenario. Restart and lobby return preserve the running `SessionHost`, player registry, and LAN services.
