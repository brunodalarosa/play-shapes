# Overview and running

What the project does today and how to run it. Read this first if you are new to the
repository.

## What exists today

- Godot 4.7.2 is the authoritative host. Phone controllers are bundled HTML, CSS and
  JavaScript clients over local HTTP and WebSockets.
- The lobby opens a shared ready screen for **Bubbles and Jellyfishes** with 2–10 registered
  players. Bubbles starts after every current participant is ready.
- **Tilt Shift** supports 2/4/6/8/10 players. Each phone enables motion, sets a comfortable
  landscape neutral and confirms READY on the shared Pre-minigame screen before launch.
  One team paddle on each phone mirrors
  the host's accepted angle throughout the factory rounds.
- Registered players appear as Squircle v1 characters in the Playground lobby. Each steers
  their character from a portrait phone stick and a release-action button. Near-vertical input
  reaches or crouches, and FALL descends Open supports.
- Squircle v1 is also the character in Minigame 002 and in phone setup.
- F12 opens the debug menu: a one-real-player Bubbles scenario, the Squircle Animation Lab,
  the Gyroscope and Accelerometer Lab, and a Tilt Shift factory with explicitly simulated
  controls. The factory review creates ten synthetic operators without registering phones.
  Bubbles labels its debug round on the host and the phone.
- The host defaults to a responsive 1920×1080 GL Compatibility presentation.
- **Project > Tools > Build Standalone Host** creates a portable Windows x86_64 release ZIP.
  There is no Linux build.

What still needs a person's review is listed in [pending-reviews.md](pending-reviews.md).

## Where things are

The repository contains the Godot project, the browser client, the bundled runtime assets,
the tests and the tooling.

- [README.md](../README.md): what to install and how to play.
- [AGENTS.md](../AGENTS.md): how to work on the project.
- [DEVELOPMENT.md](../DEVELOPMENT.md): the table of development documents.
- [Tuning/README.md](../Tuning/README.md): tuning values.

## Running

Run Git, Godot, the browser build and the tests from the repository root. `project.godot`
must remain at the root.

```powershell
godot --version
godot --path .
```

- **F5** runs the complete boot and lobby flow.
- **F6** runs one scene; use it only when a scene is designed to run on its own.
- Set `GODOT_BIN` when Godot is not on PATH.

## Joining from a phone

In the lobby, choose a reachable Wi-Fi or Ethernet IPv4 address. Then scan the QR code, or
type the displayed URL, on a phone on the same LAN.

- Address discovery runs at launch and on Refresh.
- It prefers common `192.168.*` addresses. It is not default-route detection.
- Loopback, link-local and IPv6 addresses are excluded.
- VPNs, multiple adapters, guest Wi-Fi and client isolation can require a manual choice or
  prevent access. See [networking.md](networking.md).

## Starting a round

- Normal play starts with 2–10 registered players. Choose a minigame from the lobby dropdown
  before starting. Tilt Shift requires an even roster and calibrated motion from everyone.
- For debug, register exactly one phone, press F12, and choose the matching one-player
  Bubbles scenario. The separately labeled Tilt Shift factory review needs no phones.
- Restart and lobby return preserve the running `SessionHost`, the player registry and the
  LAN services.
