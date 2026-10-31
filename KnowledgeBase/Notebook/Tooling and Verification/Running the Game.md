---
area: Tooling and Verification
tags: [system, stub]
code: [project.godot]
verified:
branch:
---

# Running the Game

Hub: [[Tooling and Verification]].

How to run the host and join from a phone.

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
  prevent access. See [[Networking|networking.md]].
## Starting a round

- Normal play starts with 2–10 registered players, or 1–10 for Flappy Race. Choose a minigame
  from the lobby dropdown before starting. Tilt Shift 3D requires an even roster and calibrated motion from
  everyone.
- For debug, register exactly one phone, press F12, and choose a one-player Bubbles
  scenario. The separately labeled Tilt Shift 3D factory review needs no phones.
- Restart and lobby return preserve the running `SessionHost`, the player registry and the
  LAN services.
