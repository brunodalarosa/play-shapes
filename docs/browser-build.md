# Browser build

## Browser build

Node 22+ is required for development and not for play. `node tools/setup.mjs` checks it with the other required tools and installs `web/` dependencies; [README.md](../README.md#requirements) lists every tool. After any TypeScript edit, rebuild and commit all affected modules under `web/public/`:

```powershell
cd web
npm.cmd run check
npm.cmd run build
npm.cmd test
cd ..
```

Every top-level module imported by `app.js` must also appear in the explicit `HttpService` allowlist and release filter. A 200 response for `/app.js` does not prove its module graph works: a missing imported module can leave phones at `Connecting to the host…`. The export presets include `web/public/*.js` and the Squircle v1 manifest; served tests request the imported modules and front idle Squircle sheets.

The Bubbles surface is a full-screen portrait touch area with exact host score, capped decorative jellyfish, and its personalized character preview; the Squircle v1 body, hands, and feet share the player's chosen color. Onboarding offers **Run Play Shapes as an app** before new-player registration, with platform guidance, a real native install prompt only when available, and **Continue in browser**. Standalone/resumed players skip the prompt; tab-session dismissal prevents recurring play interruptions. Browser continuation optionally attempts fullscreen/portrait lock; denial is playable. Gameplay input never requests fullscreen or consumes the motion-permission gesture. Controller surfaces scope zoom/scroll/selection prevention and cancel gestures on viewport/orientation/background changes; onboarding remains scrollable and zoomable. The manifest and local icons are bundled in exports. No service worker or static cache is added; the reachable LAN host still serves all content, and installation does not establish certificate trust. See [optional controller app and touch review](controller-app-and-touch.md) for actual Safari limits, installation steps, origin/session/storage handling, update procedure, synthetic timing and pending physical Safari/Android evidence.
