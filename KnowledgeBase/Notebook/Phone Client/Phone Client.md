---
area: Phone Client
tags: [hub]
code: [web/public/app.js, web/src/screen_wake_lock.ts, web/src/lobby_input.ts]
verified: 2026-10-31
branch: feature/knowledge-base
---

# Phone Client

Area hub. Parent: [[Notebook]]. The phone is a TypeScript web page that the host serves over
HTTP and WebSockets on the LAN. Each minigame's screen is in its own folder, described in that
minigame's hub.

## Notes

- [[Phone Code Map]]: where each behavior lives in `web/src/`.
- [[Phone Web App]]: setup, wake lock, app install, fullscreen, touch guards, send rates.
- [[Browser Build]]: how `web/src/` becomes the committed bundle.
- [[Motion Input]]: gyroscope and accelerometer readings to the host.
- [[Local HTTPS]]: the certificate test phones trust, needed for motion sensors.
- [[Platform Controller]] (in [[Playground Lobby]]): the joystick and JUMP/FALL button.

## Rules

- **Rebuild after any TypeScript change.** `web/public/app.js` is committed, and the check
  fails when `web/public/` is stale.
- Normal play needs neither Node nor Internet: everything is served by the host.
- The lobby's messages come from the shared `PlatformControls` intent through
  `web/src/lobby_input.ts`. Its axes are X right, Y up, as in Godot 3D.

## Gotchas

- The bundle rewrite can hit a user-mapped-section lock on Windows. Report it as a failure.

Architecture: [[Message Protocol]], [[Shared Deterministic Prediction]].
