# Windows standalone build

## Windows standalone build

Install the exact Godot 4.7.2 Windows export templates with **Editor > Manage Export Templates**, then use **Project > Tools > Build Standalone Host**. Godot requires both release and debug x86_64 template files even though this action exports release only.

```text
builds/standalone/
├── Play-Shapes-windows-x86_64.zip
└── windows-x86_64/
    ├── Play Shapes.exe
    ├── Play Shapes.pck
    └── build-info.json
```

The ZIP contains one `Play-Shapes-windows-x86_64/` folder. The manifest records preset, architecture, Godot version, renderer, UTC time, and source revision when available. Before archiving, the builder verifies the external PCK, every browser module, boot/lobby scenes, QR dependency, Bubbles scenes/scripts, and Bubbles runtime art/audio. It never starts Node.

The `Play Shapes Windows Release` preset includes the committed browser runtime while excluding browser source/dependencies, tests/results, tools, source art, runtime asset manifests, build output, editor addons, and package configuration. Do not broaden filters just to silence a policy failure. `addons/kenyoni/qr_code/` must remain included.

The editor polls a separate headless export process. Cancel terminates that owned process or removes only its partial ZIP. Success opens the extracted folder but never launches the game. For builder UI maintenance, set `Window.size` before parameterless `popup_centered()`; Godot treats a size passed to `popup_centered(size)` as a minimum and may retain an oversized native window. Keep the target path single-line/ellipsized because early wrapping can create an extreme minimum height.
