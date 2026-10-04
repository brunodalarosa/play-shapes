# Browser build

How the phone client's TypeScript becomes the one script the host serves. What the phone
screens do is in [phone-client.md](phone-client.md).

## Building

Node 22 or newer is required for development and not for play. `node tools/setup.mjs` checks
it with the other required tools and installs the `web/` dependencies.
[README.md](../README.md#requirements) lists every tool.

After any TypeScript edit, rebuild and commit `web/public/app.js`:

```powershell
cd web
npm.cmd run check
npm.cmd run build
npm.cmd test
cd ..
```

- `web/src/` is the source. `web/public/` is what the host serves, and it is committed, so
  playing needs neither Node nor Internet.
- The check command rebuilds and fails if `web/public/` changed.

## What the build does

`npm run build` runs three steps ([decision 0016](decisions/0016-bundle-the-phone-client.md)):

1. `npm run modules` compiles each TypeScript module to JavaScript in `web/build/`, which git
   ignores, and copies the pinned NippleJS beside them. TypeScript checks the types as it
   compiles.
2. `npm run bundle` has esbuild join `web/build/app.js` and everything it imports into
   `web/public/app.js`. The bundle is not minified, so a change shows in a diff and a line
   number in the phone's error panel can be looked up.
3. It generates `web/public/platform_input_settings.json` from the browser's input defaults.
   The host reads that file; do not edit it by hand.

`web/build/` is also what the unit tests and the platform controller harness import, one
module at a time. `npm test` runs `npm run modules` first, so the tests never run old output.
The bundle is made from those same files.

## Adding a module

Import it from a module that `app.ts` reaches, and rebuild. Nothing else needs to know about
it: the host serves one script, `/app.js`, and the export includes that one file.

The other routes the host serves are in [protocol.md](protocol.md#http-routes).
