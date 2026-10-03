# Browser build

How the phone client's TypeScript becomes the files the host serves, and what to keep in step
when adding a module. What the phone screens do is in [phone-client.md](phone-client.md).

## Building

Node 22 or newer is required for development and not for play. `node tools/setup.mjs` checks
it with the other required tools and installs the `web/` dependencies.
[README.md](../README.md#requirements) lists every tool.

After any TypeScript edit, rebuild and commit all affected modules under `web/public/`:

```powershell
cd web
npm.cmd run check
npm.cmd run build
npm.cmd test
cd ..
```

- `web/src/` is the source. `web/public/` is the committed bundle the host serves, so playing
  needs neither Node nor Internet.
- The build compiles TypeScript and copies the pinned NippleJS into `web/public/vendor/`.
- The build also generates `web/public/platform_input_settings.json` from the browser's input
  defaults. The host reads it; do not edit it by hand.
- The check command rebuilds the bundle and fails if `web/public/` changed.

## Adding a module

Every top-level module imported by `app.js` must also appear in the explicit `HttpService`
allowlist and in the release filter.

- A 200 response for `/app.js` does not prove its module graph works. A missing imported
  module can leave phones at `Connecting to the host…`.
- The export presets include `web/public/*.js` and the Squircle v1 manifest.
- `/platform_controls.js`, `/platform_input.js` and `/platform_input_settings.json` are fixed
  HTTP routes and required export assets.
- The served tests request the imported modules and the front idle Squircle sheets.

The full list of routes is in [protocol.md](protocol.md#http-routes).
