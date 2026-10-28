Vendored Windows runtime files from https://github.com/doceazedo/godot_wry

Release: v1.0.2 (2026-01-14), `godot_wry.zip`
Path: addons/godot_wry
License: MIT (LICENSE); WRY is Apache-2.0/MIT
SHA-256 of `bin/x86_64-pc-windows-msvc/godot_wry.dll`:
a8fb72d3570708874f92e5e55384c35127c056c1554eb7a06b5997d050831e5b

Kept: the Windows library, the WebView icon and the license. `WRY.gdextension` lists only the
Windows library. Left out: the macOS and Linux libraries, `index.html` and the examples.

Used only by minigame workshops, never by the exported game. This release places every WebView in
the main window, so a WebView inside a popped-out window does not show there; the upstream fix
(pull request 81) is merged but not released.
