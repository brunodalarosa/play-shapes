# PS-080 — Squircle look-up and crouch

Implemented locally on 2026-10-02. Owner creative approval remains pending.

The canonical Blender source adds `PS080 | Look Up` and `PS080 | Crouch` to the
existing five-control rig. The original idle/walk/run action curves and modifiers
were fingerprinted before editing and matched after reopening the saved source.
Geometry, materials, packed expressions, feet, root and camera framing are preserved.

Each new action has nine frames at 24 fps: frame 1 is idle neutral, frame 9 is held,
and the eight intervals provide a 1/3-second eased entry or reverse release.
Look-up tilts the body −10° around X and raises both hands. Crouch lowers the body
0.16 m and brings both hands inward and alongside it. Its shallow depth preserves
the existing proportions and floating clearance above the feet. Exact pose and
timing remain tunable in Blender; see [source controls](../art/squircle/README.md).

The shared library contains five actions × two views × three runtime layers.
The manifest carries `playback: held` for the added strips. Existing looping
consumers continue using idle/walk/run. Runtime playback holds indefinitely,
reverses partial entry on release, resumes a re-pressed stance from current
progress, and switches through neutral without restarting on repeated requests.
The F12 lab uses this same playback at 256, 128 and the lobby's 0.58 scale, with
natural/forced blink, palette, pause, slow motion, release and re-enter controls.
PS-082 will connect input; this change adds no movement or platform rules.

## Technical/export evidence

- Blender 5.2.2 source reopened with both new actions and packed neutral/blink textures.
- `validate_animation.py` passed for all five actions at quarter-frame intervals:
  sustained hold, common neutral endpoints, stationary feet/soles, hand/body/foot
  clearance, floor clearance, upward tilt, crouch displacement and camera containment.
- Full export: ten action/view pairs and 212 animation frames; 30 runtime sheets.
- Independent full export from the saved file: identical manifests, 426 replay PNGs,
  maximum consumed-channel difference 1/255, canonical white mask RGB, minimum
  rendered alpha border 13 px, and packed colorable tiles matching raw frames.
  Maximum held face-plane occlusion is 0.0697% across all entry/hold frames.
  Cycles replay may vary by one channel value; PNG byte equality is not required.
- Godot 4.7.2 GL Compatibility import passed. Expanded Animation Lab checks passed
  for all clip/view pairs, synchronized layers/anchors, tint, blink, pause,
  interrupted entry, repeated holds, re-press, switching and release to idle.
- Focused lobby controls, Bubbles presentation and standalone asset-policy checks
  passed. The lobby/Bubbles checks also emit exit-time resource cleanup diagnostics;
  their gameplay/presentation assertions report zero failures.
- Browser dependency installation, type checking and build passed; all 50 browser
  tests passed with the expanded manifest and shared assets. No browser source or
  bundled JavaScript changed.

Current detailed reports are `art/squircle/validation.json`,
`export-verification.json`, `export/manifest.json` and `runtime-sync.json`.
The source README documents commands to reproduce them.
Repeated packing exposed Windows denial of direct file truncation. The current
packing/synchronization tools write a complete
sibling temporary image before replacing the destination; old assets survive
write failure, and temporary outputs are ignored and cleaned up.

## Separate visual review

Agent inspected the live Blender held-pose render, the generated motion sheet,
and Godot GL Compatibility captures of both actions in both views, displaying
256/128 references and the actual lobby scale. Raised hands remain within the
tile; the face reads clearly and limbs remain visually separate. The local HTML
review and generated motion GIFs show entry, sustained hold and reverse release.
Godot's lab also allows interrupted transitions and direct stance switching.

Temporary renders, captures, construction code and logs are in ignored
`BRUNO_GIT_IGNORE/Temp/ps080/`; the independent replay is ignored `art/squircle/recheck/`.
These are not source history or committed comparison artifacts.

Owner animation timing/feel, creative approval and physical-device review remain
separate from these technical and agent visual checks. No publication is authorized.
