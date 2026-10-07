# Windows standalone build

How to build the portable Windows package, what goes into it, and what to keep in mind when
changing the builder. There is no Linux build.

## Building

1. Install the exact Godot 4.7.2 Windows export templates with **Editor > Manage Export
   Templates**. Godot requires both the release and the debug x86_64 template files, even
   though this action exports release only.
2. Use **Project > Tools > Build Standalone Host**.

```text
builds/standalone/
├── Play-Shapes-windows-x86_64.zip
└── windows-x86_64/
    ├── Play Shapes.exe
    ├── Play Shapes.pck
    └── build-info.json
```

- The ZIP contains one `Play-Shapes-windows-x86_64/` folder.
- The manifest records the preset, architecture, Godot version, renderer, UTC time, and the
  source revision when available.
- The build never starts Node.

## What the builder verifies

Before archiving, the builder verifies the external PCK, every browser module, the boot and
lobby scenes, the QR dependency, the Bubbles scenes and scripts, and the Bubbles runtime art
and audio. The required runtime paths also include the reusable Tilt Shift factory
scene and its art geometry manifest. The Squircle manifest carries lever hand positions.

## What the package includes

The `Play Shapes Windows Release` preset includes the committed browser runtime. It excludes:

- the browser source and its dependencies;
- tests and test results;
- tools;
- source art and extraction manifests; runtime Squircle and factory geometry remain included;
- build output;
- editor addons;
- package configuration.

Rules when changing it:

- Do not broaden filters just to silence a policy failure.
- `addons/kenyoni/qr_code/` must remain included.
- Preserve `web/public/`, the external-PCK output, and the boundary between curated runtime
  assets and source or archive art.
- Secret file patterns and local network configuration are ignored by git and excluded from
  both export presets.

## Checking a package

Editor and runtime checks do not prove a package. Smoke the exported executable without Godot
or Node: the lobby, the HTTP routes, the WebSocket, and a browser connection. The automated
export tests are in [verification.md](verification.md#export-tests).

## How the builder runs

- The editor polls a separate headless export process.
- Cancel terminates that owned process, or removes only its partial ZIP.
- Success opens the extracted folder but never launches the game.

## Maintaining the builder's window

- Set `Window.size` before a parameterless `popup_centered()`. Godot treats a size passed to
  `popup_centered(size)` as a minimum and may keep an oversized native window.
- Keep the target path on a single line with an ellipsis. Early wrapping can create an extreme
  minimum height.
