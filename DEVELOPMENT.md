# Play Shapes development

## PS-018 — editor-authored Flash? Pose! stage (2026-09-16)

The reusable gameplay-stage shell lives at the reserved path
`res://minigames/dancer_simon_says.tscn`. It intentionally contains presentation
and placement only: the player-facing title, the PS-017 environment art, one
lead preview, and ten player previews. Round state, pose evaluation, audio,
feedback, results, networking, and navigation remain in their later tasks.

`LeadSlot` and `PlayerSlots/Seat01` through `Seat10` are stable `Control`
anchors. Their positions are stored as screen-relative anchors directly in the
scene, not calculated from viewport dimensions in code. Seat numbering expands
center-out (`Seat01`/`Seat02` are the center pair), so assigning the first two
through ten stable seats keeps smaller groups centered without reshuffling an
already assigned player. Later systems may configure or replace a slot's
`PreviewCharacter`, but must preserve the slot identity and authored position
throughout a round.

### Adjusting the composition in Godot

1. Open `res://minigames/dancer_simon_says.tscn` in the 2D editor.
2. Select `LeadSlot` or one of the named nodes under `PlayerSlots`.
3. Move it with the 2D tool or edit its Layout anchor values, then save the
   scene. Do not generate seat positions in a runtime script.
4. On the scene root, set `preview_player_count` from 2 to 10 to compare small
   and full formations. Hidden previews do not remove their seat nodes.
5. Toggle `show_character_previews` only when an unobstructed environment pass
   is useful. The lead and ten editor markers remain available for authoring.

The scene uses only the manifest-owned runtime paths under
`assets/runtime/shape_characters/environment/`: `floor_left.png`,
`floor_center.png`, `floor_right.png`, and `tree_small.png`. Character previews
instance `res://characters/shape_character.tscn`; they do not duplicate its
textures or animation boundary.

Focused checks:

```powershell
godot --headless --path . --script res://tests/dancer_simon_says_scene_test.gd
godot --path . --resolution 1440x810 --script res://tests/dancer_simon_says_scene_visual_check.gd
```

The structural check covers the reserved path, one lead, ten stable named
seats, center-out two-player preview, editor anchors, character instances, and
all selected environment references. The renderer check writes review images
under `test-results/ps-018/`; those generated files are ignored. These checks
do not constitute owner visual approval. PS-018 remains in progress until the
owner approves the composition.

## PS-017 — Milestone 1 environment asset decision (2026-09-16)

PS-017 is complete by explicit owner decision. Flash? Pose! will use the
existing curated environment sprites in
`assets/runtime/shape_characters/environment/` for Milestone 1: the left,
center, and right floor tiles plus the small tree. Their Kenney Shape
Characters 1.0 / CC0-1.0 provenance, source paths, dimensions, and stable
runtime paths are already recorded in
`assets/runtime/shape_characters/manifest.json`.

PS-018 may compose these assets into the editor-visible minigame scene while
preserving character contrast and pose readability. This is a deliberate
temporary visual choice so implementation can proceed; sourcing or creating a
prettier environment is deferred until after Milestone 1 and is not a blocker.
No runtime assets or Godot scenes changed in this decision-only update.

## Task dependency links (2026-09-16)

All non-empty `depends_on` properties now store exact Obsidian wikilinks to
their task notes instead of plain task IDs. This lets Bases filters resolve each
dependency as a file and inspect its `status` property. Tasks with no
dependencies continue to use `depends_on: []`.

## PS-019 — Flash? Pose! implementation plan (2026-09-16)

PS-019 is complete; the owner confirmed the implementation decomposition and
the three gameplay-policy choices below.
The current checkout contains the persistent `SessionHost`/`PlayerRegistry`,
the hello/join/leave WebSocket boundary, the editor-first tuning resources,
the approved semantic character animator, the F12 launcher, and the supplied
runtime music/flash candidates. It does not yet contain a gameplay scene,
gameplay protocol, host start control, round coordinator, shared-screen results
presentation, or phone pose controls.

The execution sequence is: human-confirmed PS-017 environment assets; PS-013
pose rules and PS-018 editor-visible stage; PS-023 audio preparation; PS-024
host round controller; PS-025 phone protocol/controller; PS-026 shared-screen
feedback/audio/flash/results (with PS-025 able to proceed in parallel); PS-027
lobby/debug/return integration; PS-028 technical validation; and PS-029 the
owner's two-phone and human-play gate. PS-022 was a discarded historical draft
and is not reused because task IDs are never reused.

The recommended architecture is a scene-scoped host round coordinator using a
small enum and explicit transitions, plain per-player state keyed by host
`player_id`, the Godot `_process` loop, and narrow signals. It does not add a
state-object hierarchy, universal event bus, simulated-player framework,
device farm, or runtime tuning UI. The host owns deadlines and input receipt
time; the presentation emits one genuine-stop flash request only after results
are resolved and acknowledges completion before music resumes. The player-
facing name is **Flash? Pose!**; the reserved internal scene path and existing
`SimonSaysTuning` identifiers remain stable unless a real compatibility need
justifies a migration.

The owner confirmed that an uninterrupted phone hold persists through a genuine
stop and keeps the character holding its pose; a disconnect clears the hold,
missing input loses a life, and explicit Leave withdraws without a life loss.
The owner also confirmed exact playback-position pause/resume around the flash.
Numeric timing, flash intensity, audio gain, accessibility, fairness, and fun
remain human-play decisions. This planning update changed documentation only;
no gameplay, editor/runtime, browser, device, or human-play validation was run.

## PS-021 — curated runtime asset pipeline (2026-09-16)

Runtime-ready Shape Character art now lives under
`assets/runtime/shape_characters/`. The complete
`assets/Kenney_Shape_Characters/` folder remains the immutable provenance and
authoring archive, but its root `.gdignore` prevents Godot from importing it.
Release exports also exclude that archive and the build-time manifest. Production
`.gd`, `.tscn`, and `.tres` files must reference only the runtime root.

`assets/runtime/shape_characters/manifest.json` is the source of truth. Its 21
entries currently select four blue Double-resolution bodies, six blue
Double-resolution hand poses, the PS-009 Double-resolution foot, six used face
expressions, and four used environment pieces. Body, hand, and foot entries use
`player_tint`; faces and environment art use `untinted`. Runtime files are exact
copies rather than derived images, so the approved shaded source, alpha edges,
pivots, horizontal mirroring, half-scale presentation, and tint shader remain
unchanged. Standalone textures remain simpler than an atlas at this size.

### Add, replace, or remove a sprite

1. Put editable or supplied source art in its provenance-bearing source location.
   Do not hand-edit a file under `assets/runtime/shape_characters/`.
2. Add or update one manifest entry. Give it a unique stable name and runtime
   path; record source path, role, `player_tint` or `untinted`, Double canonical
   resolution, `copy` behavior, creator/license/source provenance, mirror policy,
   and exact pixel dimensions. The manifest-wide `smooth_sprite` import policy
   applies unless a future schema explicitly adds a reviewed exception. Only
   shaded body/hand/foot art compatible with `player_tint.gdshader` may use
   `player_tint`; faces stay untinted.
3. Run `python tools/assets/runtime_asset_pipeline.py sync`. Open/import the
   project once (or run the headless editor-load command below), then run `sync`
   again so the committed `.import` sidecars receive the required lossless,
   mipmapped, alpha-border-fixed, repeat-disabled settings. Import once more.
4. Run `python tools/assets/runtime_asset_pipeline.py check`. It rejects missing
   sources, duplicate names/paths, invalid policies, missing provenance, wrong
   dimensions, stale copies, unexpected output files, incorrect import settings,
   production archive references, or a missing import/export boundary.
5. Migrate callers to the stable runtime path. For removal, delete the manifest
   entry and its exact runtime `.png` and `.png.import`; `check` must pass before
   committing. Never delete the provenance source merely because runtime stopped
   using it.
6. Run relevant scene/animation tests and a Compatibility-renderer comparison.
   Export `PS-021 Validation Pack`, run the export-boundary check, and obtain
   human visual approval whenever visible art, policy, or presentation changes.

Commands from the Godot project root:

```powershell
python tools/assets/runtime_asset_pipeline.py sync
godot --headless --editor --path . --quit-after 30
python tools/assets/runtime_asset_pipeline.py sync
godot --headless --editor --path . --quit-after 30
python tools/assets/runtime_asset_pipeline.py check
python -m unittest tests/runtime_asset_pipeline_test.py
godot --headless --path . --export-pack "PS-021 Validation Pack" test-results/ps-021/curated.pck
python tools/assets/runtime_asset_pipeline.py check-export --pack test-results/ps-021/curated.pck
```

### Measurements and evidence

- Before: the archive held 435 files / 1,168,853 bytes, including 214 PNGs and
  215 `.import` sidecars; the representative all-resource PCK was 2,192,572 bytes.
  Production directly referenced 15 archive textures.
- After: the manifest owns 21 PNGs / 35,025 bytes and 21 import sidecars. Godot
  actively imports those 21 runtime PNGs and ignores the archive. The comparable
  PCK is 895,316 bytes, saving 1,297,256 bytes (59.17%). The repository remains
  intentionally larger because the complete source archive is preserved.
- `[AUTO]` Manifest/schema, stale-copy, import-setting, forbidden-reference,
  archive/atlas preservation, animation, expression, and foundation checks pass.
  A second sync reports zero copies and zero sidecar changes.
- `[EDITOR]` Godot 4.7.2 imports the 21 runtime textures and loads without new
  resource or script failures. Existing MCP early-shutdown leak warnings remain.
- `[GODOT-RUNTIME]` GL Compatibility on the RTX 5070 passed the existing rendered
  tint/isolation/face checks (260 opaque face pixels unchanged) and regenerated
  `art/character-feet/runtime-showcase.png` without a tracked pixel change.
- `[EXPORTED-BUILD]` Direct pack inspection confirms runtime paths are present
  and `assets/Kenney_Shape_Characters` is absent.
- `[HUMAN-PLAY]` Approved on 2026-09-16. The owner reviewed the regenerated
  runtime showcase, confirmed that it looked good, and authorized marking
  PS-021 done. This completes the separate human visual acceptance step.

Once `.gdignore` established the source boundary, Godot removed the archive's
215 generated `.import` sidecars. This is intentional cleanup of obsolete engine
metadata, not deletion of source material: all source PNGs, license text,
atlases/XML, previews, vectors, and PS-009 project additions remain preserved.

The original file-hash baseline now records the repository's enforced LF form of
`License.txt`; its earlier CRLF hash could not pass in a checkout governed by the
existing `eol=lf` attribute. No license text changed.

## PS-016-PS-020 - Dancer Simon Says visual and audio planning task set (2026-09-15)

The planning layer now distinguishes three specialized task types in addition
to exploration, design, implementation, and validation: `asset-hunt`,
`asset-rework`, and `wireframes-and-art-mockups`. Asset hunts and wireframes or
art mockups are human-owned for now because the owner must select visual
direction and approve the result. Asset rework is intended for AI or shared
computer-based treatment of existing media; generative image creation is not
the default and must be explicitly requested in a task.

PS-016 creates the human visual reference for the Dancer Simon Says shared
screen and phone control. PS-017 selects the scenario/environment asset set
with provenance and licensing notes. PS-020 selects music and SFX candidates
with provenance, loop/stop metadata, and human listening approval. PS-019 plans
the complete implementation and creates any remaining bounded follow-up tasks. PS-018 is deliberately
narrow: it will compose an editor-visible Godot gameplay scene with human-
editable lead and 2–10 player placement slots using the approved wireframe and
selected environment assets. None of these tasks implement the minigame yet;
the implementation task remains dependent on the planning and content outputs.

This session changed Markdown planning records only. No runtime, asset, browser,
Godot editor, or device validation was performed or claimed.

## PS-005 — Multi-phone and agent validation strategy (2026-09-15 working draft)

The MVP routine physical matrix is two real phones on normal home Wi-Fi with the
host also on Wi-Fi: an iPhone 16 Pro (Safari by default, Chrome for a browser
spot check) and a Pixel 7 (Chrome). Two simultaneous phones are sufficient for
MVP validation; larger playtests are future coverage. VPN, guest-network
isolation, hotspot, packet shaping, and unusual interfaces are not MVP gates.

Keep these evidence labels distinct in task notes and reports: `[AUTO]`,
`[EDITOR]`, `[GODOT-RUNTIME]`, `[DESKTOP-BROWSER]`, `[PHYSICAL-PHONE]`,
`[EXPORTED-BUILD]`, and `[HUMAN-PLAY]`. Automated, editor/runtime, and desktop
browser results can support technical claims, but they do not prove touch,
real-phone LAN reachability, exported-build behavior, couch-distance
readability, accessibility, or game feel. The complete matrix, two-phone
scenario, report fields, and completion rules are in [[PS-005 - Define Multi-Phone and Agent Validation Strategy]]. This is a working draft pending
owner approval; no device-farm, CI, network-emulation, or profiling tooling was
added.

## PS-012 — Milestone 1 character animation system (2026-09-15)

PS-012 upgrades `characters/hybrid_character_animator.gd` from the approved lab
prototype into the production animation boundary for `ShapeCharacter`. Gameplay
may call `setup(character, is_lead, phase_index, phase_count)`,
`set_dance_style(style)`, `set_pose_state(direction, normalized_charge, held)`,
`set_dance_active(active)`, `play_lead_pose_flow(direction)`,
`play_reaction(reaction)`, `set_eliminated(eliminated)`, and
`set_result_mood(mood)`. Gameplay must not manipulate child sprites, easing, or
animation clocks and must never read transforms or animation time to evaluate a
pose. PS-013 remains responsible for authoritative charge and success.

The three music-paired styles are `bounce`, `swing`, and `disco`. Each owns
distinct authored limb choreography, while `_pose_targets()` is the sole shared
source for Up, Left, Right, and Down across every style and both character
roles. The lead starts at loop phase zero. Player setup uses indices 0–9 over a
phase count of 10, producing deterministic 0.0–0.9 offsets. Seeded expression
and jiggle variation supplements those offsets without changing command meaning.
`set_dance_active(false)` freezes a genuine stopped lead; a full normalized pose
remains exact and still. Eliminated characters override every other state,
remain visible with a sad face, and ignore later transient reactions.

Use F12 and choose **Milestone 1 character animation** to open
`debug/character_animation_system.tscn`. It shows one emphasized lead and ten
smaller players, three style choices, normalized command charge, short lead pose
flows, life-loss recoil, survival celebration, elimination, and happy/moody
results. This debug scene supplies semantics only and does not emulate scoring,
lives, music stops, networking, or authoritative evaluation.

Designer-facing animation values remain in
`Tuning/Minigames/SimonSays/Default.tres`: base tempo, bounce, sway, jiggle,
secondary-motion strength, visual follow speed, lead emphasis, transient
reaction duration, results cycle duration, and lead pose-flow hold duration.
The authored transforms in the animator are choreography data rather than
gameplay rules. Add a new dance style by adding its semantic ID and authored
poses; do not duplicate the canonical command poses. Add a reaction behind a
semantic method/state and document its interruption priority. Current feel
values remain adjustable through named presets even after this milestone approval.

Focused API/state, tuning, charge, expression, launcher, and foundation checks
pass. On this development machine, directly processing all eleven animator
components for 600 synthetic 60 Hz frames measured 289.13–301.40 microseconds
average and 474–534 microseconds worst across three runs; this is a CPU-side component sample, not whole-frame
rendering or evidence for other hardware. The Godot Compatibility renderer
successfully captured all three loops, command/reaction stills, and a review
reel under `test-results/ps-012/`. The project owner then ran the game, tested
the animations directly, and reported being 100% satisfied with the Milestone 1
result on 2026-09-15. That is the required human motion/readability approval and
completes PS-012. It does not claim validation on other hardware.

Validation commands:

```powershell
godot --headless --path . --script res://tests/animation_lab_test.gd
godot --headless --path . --script res://tests/character_animation_performance_test.gd
godot --headless --path . --script res://tests/tuning_presets_test.gd
godot --headless --path . --script res://tests/pose_charge_test.gd
godot --headless --path . --script res://tests/character_expression_test.gd
godot --headless --path . --script res://tests/debug_launcher_test.gd
godot --headless --path . --script res://tests/foundation.gd
godot --path . --resolution 1440x900 --script res://tests/character_animation_visual_check.gd
```

## PS-015 — shared tuning assets and preset workflow (2026-09-14)

### Inspector tooltip correction (2026-09-15)

Godot 4.7.2 showed `No description available` for the first tuning Resources.
Keep every documented tunable in this exact order: the `##` documentation
comment, then the export annotation on its own line, then the `var` declaration
on the next line. Use `@export_group` for Inspector sections, not
`@export_category`: categories change the Inspector's documentation context and
can prevent subsequent custom-property descriptions from resolving. This applies
to range exports and plain Resource-reference exports.
`tests/tuning_presets_test.gd` checks both rules for every current tweakable so
future additions cannot silently lose their Inspector tooltip.
Godot's `--gdscript-docs res://Tuning` output was also inspected: all 17 current
properties and their full descriptions are present in the generated
`SimonSaysTuning.xml`, `NetworkingTuning.xml`, and `ActivePresets.xml`. These
temporary XML files are verification output and are not committed.

PS-015 implements the editor-first workflow approved by PS-004. Open
`Tuning/Active Presets.tres` for the project-level selector. Its Simon Says and
Networking references point to committed, named assets; assigning the matching
`Default.tres`, saving, and relaunching deterministically restores the known-good
configuration. There is no runtime tuning UI.

`Tuning/Minigames/SimonSays/Default.tres` is the minigame front door. It owns the
currently implemented charge fill/decay, lab preview timing, dance tempo, body
bounce/jiggle/sway, and visual-follow values. The animation lab and animator now
consume that Resource without changing their provisional defaults.
`Tuning/Shared/Networking/Default.tres` replaces `host/default_settings.tres`
and owns the existing HTTP/WebSocket ports, transport/player limits, request
timeout, and reconnect grace. `SessionHost` obtains it through Active Presets;
the host remains authoritative.

Each exported field includes Inspector documentation, units, a default, a safe
range, and higher/lower guidance. Setters clamp individual values. Each Resource
reports actionable cross-field errors, and `tests/tuning_presets_test.gd`
recursively loads and validates every committed `.tres` below `Tuning/`. It also
checks invalid individual values, invalid combinations, and missing active
references. Future preset files are therefore included automatically rather than
being allowlisted.

The complete navigation, naming, reset, extension, and experiment workflow is in
`Tuning/README.md`; copy `Tuning/Experiments/EXPERIMENT_TEMPLATE.md` for a feel
comparison. The approved shared category map is documented there, but only
Networking has a Resource today because the other categories have no concrete
implemented values yet. Browser fetch timeout (5 seconds), WebSocket deadline
(about 7 seconds), and retry delay (2 seconds) remain local to `web/src/app.ts`;
no current behavior requires synchronizing them with the host.

Validation commands:

```powershell
godot --headless --path . --script res://tests/tuning_presets_test.gd
godot --headless --path . --script res://tests/pose_charge_test.gd
godot --headless --path . --script res://tests/animation_lab_test.gd
godot --headless --path . --script res://tests/player_registry_test.gd
godot --headless --path . --script res://tests/player_lobby_test.gd
godot --headless --path . --script res://tests/foundation.gd
godot --headless --editor --path . --quit-after 30
cd web
npm.cmd run build
npm.cmd run check
npm.cmd test
```

Automated Resource, regression, TypeScript, and browser/host integration checks
pass. The normal-profile Godot editor-load check passes without script/resource
errors; its existing early-shutdown cleanup warnings remain non-failures. This
session's Computer connection exposed no native Godot window, so a live Inspector
walkthrough was not performed. No browser behavior changed, no physical-phone or
exported-build check was run, and no subjective feel/readability/fun approval is
claimed. The owner still controls candidate promotion into `Default`.

## PS-004 — shared editor-first tuning strategy (2026-09-14)

PS-004 is complete. The approved workflow is editor-first: stopping and
relaunching between tuning runs is acceptable, and Milestone 1 does not need a
runtime tuning overlay.

The future tuning layout is a `Tuning/` root with one umbrella preset shape per
minigame, shared assets grouped by concern, a project-level `Active Presets`
selector, a Markdown tuning guide, and separate notes under
`Tuning/Experiments/`. The initial shared categories are Input and phone
controls, UI and presentation, Audio and haptics, Accessibility, Networking
and session behavior, Camera, and Browser/platform behavior. These categories
can grow when a real system justifies them.

Every exposed value must be understandable without reading implementation code:
use a plain-language label, explicit unit, default, safe range, purpose,
higher/lower outcome guidance, invalid-value rules, and related-field
constraints. Inspector constraints should prevent or clamp invalid individual
values; focused automated tests must reject invalid combinations. Every
committed named preset is validated, including non-active variants. Tests prove
configuration safety, not subjective game feel.

`Default` is the known-good recovery preset. Agents may create named candidate
presets and experiment notes, but only the project owner may promote a preset
to `Default` or approve a feel decision. An experiment changes one logical group
under one hypothesis, uses a named preset, relaunches the relevant scene, and
records the preset, conditions, observations, and decision in a separate note.

Host and browser values share a source only when they genuinely need
synchronized behavior. Browser-only interaction/presentation values remain
platform-local; host-only settings remain in the networking/session category.
The implementation follow-up is [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]]. No tuning resources, selectors, runtime UI, or gameplay
values were implemented by the PS-004 design session.

## PS-006 — player join and host-owned registry (2026-09-14)

`SessionHost` owns one `PlayerRegistry` for the lifetime of the host process. The
registry uses four deliberately separate identities: each WebSocket gets a
monotonic transport `connection_id`; each accepted player gets an opaque
session-scoped `player_id`; the host process gets an opaque `session_id`; and the
browser receives an opaque reconnect token. Only the host generates these values.
The browser stores the session ID, reconnect token, and last-used name in
`localStorage`; a client-supplied `player_id` has no protocol meaning.

Protocol 1 keeps the original `hello`/`welcome` handshake. `hello` may include the
stored `session_id` and `reconnect_token`. `welcome.resume_status` is one of
`join_required`, `resumed`, `expired`, or `session_restarted`. A welcomed client
may send `join` with a name or `leave`; the host replies with `join_accepted`,
`join_rejected`, `left`, or an actionable `error`. Invalid JSON/handshakes close
with policy code 1008. Unsupported post-handshake actions receive a bounded error
and cannot mutate identity. A duplicate active-token resume gives the newest
connection ownership and closes the older tab with code 4000; the bundled client
stops that older tab from retrying, preventing a reconnect loop.

Names are trimmed, 1–16 Unicode code points, and reject C0/C1 controls plus
Unicode line separators. Duplicate comparison uses Unicode lowercase matching.
Disconnected records change to `reconnecting`, reserve their name and capacity,
and expire at the configured grace boundary. Explicit Leave removes the record
and token immediately. New joins are enabled only while `scenes/lobby.tscn` is in
the tree; valid resumes remain available in other scenes. The lobby roster reads
the persistent registry and displays seat, public name, and a text connection
state. It no longer treats raw browser connections as players. Registry changes
also drive DebugLauncher's `registered_player` feature.

Designer-facing host values now live in
`Tuning/Shared/Networking/Default.tres`, backed by `NetworkingTuning`:
`max_players = 20` players and
`reconnect_grace_seconds = 60.0` seconds. They are independent of the existing
`max_connections = 32` transport cap. The provisional host request/handshake
timeout remains 5 seconds. Browser constants remain near their behavior in
`web/src/app.ts`: fetch timeout 5 seconds, WebSocket deadline about 7 seconds,
and retry delay 2 seconds. Run `npm.cmd run build` from `web/` after editing the
TypeScript source so the locally served `web/public/app.js` stays current.

Validation commands:

```powershell
godot --headless --path . --script res://tests/player_registry_test.gd
godot --headless --path . --script res://tests/player_lobby_test.gd
godot --headless --path . --script res://tests/foundation.gd
cd web
npm.cmd run check
npm.cmd test
```

The registry check covers identity separation, Unicode/name validation,
case-insensitive duplicates, lobby-only joins, two-player capacity with a reserved
reconnecting slot, resume while full, deterministic duplicate resume, exact
60-second expiry, leave/token invalidation, name reuse, and new-session rejection.
The lobby check covers roster text and persistence across lobby replacement. The
Node suite exercises the real local HTTP/WebSocket host, bundled accessibility
markup, handshake errors, host-owned identity, duplicate rejection, resume,
leave, and session restart responses. A desktop in-app browser check at 390×844
confirmed the join layout, named joined state, reload resume, and Leave/Change
player with preserved name and returned focus. The headless editor-load check has
no project parse errors; sandbox-only Godot profile/cache write errors are not an
editor runtime result. Physical-phone screen-lock, Wi-Fi-loss, touch, mobile
browser, and shared-display flow checks remain owner validation and are not
claimed here.

## PS-011 — hybrid character animation lab (2026-09-13)

The lab scene is `debug/character_animation_lab.tscn`. Start the normal host,
press F12, and choose **Hybrid character animation lab**; the PS-014 catalog now
enables that entry because the packed scene exists. F6/direct scene launch remains
a fallback, but launcher navigation is the acceptance path. F12 also provides
clean restart and lobby return while preserving `SessionHost`.

The lab begins in an automatic tour: two seconds of dance, then Up, Left, Right,
and Down in sequence with fill, snap/hold, and release unwind. Press **A** or use
the check button to disable the tour. Hold the arrow keys or the on-screen buttons
to compare poses manually. The diagnostic text is intentionally debug-only; the
character has no player-facing charge bar.

`characters/pose_charge.gd` owns deterministic semantic state: normalized charge,
held direction, fill/decay, reset-on-direction-change, and committed state. It has
no animation-frame knowledge. `characters/hybrid_character_animator.gd` consumes
that state, blends authored screen-relative part transforms, and adds restrained
procedural bounce/jiggle while dancing and charging. At charge 1 the pose snaps
to its still authored target until release. The production gameplay layer must
continue to own evaluation and pass semantic state into animation; it must never
infer authoritative outcomes from displayed transforms.

`characters/character_expression.gd` adds presentation-only life without entering
the charge contract. The neutral happy face blinks for short beats at randomized
roughly 2–5.5 second intervals. Longer micro-expressions appear less often from a
weighted happy/cheeky deck with rare subdued or worried faces. Committed poses use
intentional faces for silhouette/emotion clarity. The animator also changes hand
textures during the dance: closed, open, peace, point, rock, and thumbs-up all
participate. Up commits with rock hands, the screen-right dab uses open hands,
Left mixes open/peace, and Down mixes thumbs-up/open. Source textures, tint shader,
and mirrored screen-relative transforms remain unchanged.

Base-dance refinement keeps command poses unchanged. Blinks last 30% longer than
the first visual candidate (0.117–0.195 seconds). Dance hand textures change once
per five beats—an 80% frequency reduction—with open/closed shapes comprising ten
of fourteen sequence slots. The body now sways horizontally and occasionally
enters a randomized 1.8–3.2 second slow-jiggle phrase before returning to its
normal pattern; normal phrases last 6–11 seconds. These choices intentionally add
organic irregularity without changing authored limb choreography or pose rules.

Lab tunables are exported on the scene script (`charge_fill_seconds`,
`charge_decay_seconds`, `auto_hold_seconds`, `auto_release_seconds`) and animator
(`dance_beats_per_second`, `body_bounce`, `body_jiggle_degrees`,
`visual_follow_speed`). Current values are provisional visual-review defaults,
not production tuning. The shared `ShapeCharacter` scene, sprite pivots, tint
material ownership, mirrored art, face texture, and asset provenance are unchanged.

Validation commands:

```powershell
godot --headless --path . --script res://tests/pose_charge_test.gd
godot --headless --path . --script res://tests/animation_lab_test.gd
godot --path . --script res://tests/animation_lab_visual_check.gd
godot --headless --editor --path . --quit-after 30
```

The model test covers deterministic fill, rapid-tap accumulation, fast decay,
direction reset, snap/hold, and full release. The integration test covers launcher
availability/entry, persistent debug naming, six-part character integrity, and
complete pose targets. The real Compatibility renderer produced the ignored
`test-results/ps-011/animation-lab.gif` plus dance/pose stills for human review.
Technical validation did not replace human motion review. The owner explicitly
approved the final command poses and refined base dance on 2026-09-13. PS-011 is
complete; PS-012 may begin only as a separate, newly scoped development session.

## PS-014 — minimal gameplay debug launcher (2026-09-13)

`DebugLauncher` is a `CanvasLayer` autoload alongside `SessionHost`. Press F12 in
any host scene to toggle its overlay. It never pauses the tree and does not own,
start, or stop networking. Launch, restart, and lobby return use ordinary scene
replacement, so the same `SessionHost` node, listeners, connections, and future
host-owned player registry remain alive.

The persistent launcher state owns the active scenario name and displays
`DEBUG — <scenario name>` above every debug-launched scene. Restart reloads the
registered scene path to reconstruct clean scenario-local state. Return to lobby
clears the active registration and marker before loading `scenes/lobby.tscn`.
The overlay and marker stay available in editor and exported builds for now.

Scenario definitions live in `debug/scenario_catalog.gd`; add a single
`DebugScenario` there when a real scene becomes available. Each entry has a
stable ID, display name, scene path, and optional required feature. The launcher
also exposes `register_scenario()` for focused tests or future composition. It
checks the packed scene through `ResourceLoader` and renders missing destinations
as disabled, explicitly unavailable buttons. PS-011 only needs to supply its
scene at the catalogued path (or update that one catalog entry). The reserved
one-player Simon Says entry additionally requires `registered_player`; PS-006 or
its integration should call `set_feature_available(&"registered_player", true)`
only from the authoritative registry. Never derive it from browser connections.

Validation commands:

```powershell
godot --headless --editor --path . --quit-after 30
godot --headless --path . --script res://tests/debug_launcher_test.gd
godot --path . --resolution 1152x800 --script res://tests/debug_launcher_visual_check.gd
```

The focused runtime test covers unavailable entries, F12 toggle behavior,
non-pausing state, launch, clean scene reconstruction, marker lifetime, lobby
return, and identity/continuity of a running `SessionHost`. The visual helper
captures `test-results/ps-014/debug-launcher.png` from the real Compatibility
renderer. These checks do not prove exported-build behavior, physical phones,
multiplayer identity, or game feel.

## PS-007 — approved minimal debug-suite design (2026-09-13)

The first debug suite is intentionally only a host-side scenario launcher. F12
toggles a non-pausing overlay from any Godot scene. It preserves the running LAN
services across scenario launch, clean scenario restart, and return to lobby.
Every debug-launched scene carries a persistent `DEBUG — <scenario name>` marker.
The host shortcut has no phone-browser behavior.

The launcher stays present in editor and exported builds during this early phase.
It does not include pause, time scaling, live tuning, forced state, logs, replay,
simulated players, or a command console. One-player gameplay requires one real
registered player after PS-006; raw browser connection count is not identity.
PS-014 implements the launcher. PS-011 then supplies the animation lab scene.
Do not expand either task merely to anticipate future debug needs.

## PS-010 — approved character animation strategy (2026-09-13)

PS-010 selected a hybrid detached-sprite approach for Milestone 1: authored
transforms on the existing six independent sprite parts, shared semantic command
poses, and limited procedural bounce, jiggle, and phase offsets. Skeletal rigging
is intentionally excluded because these floating parts do not need weighted limb
deformation. Gameplay owns normalized charge and outcomes; animation consumes
semantic state and never infers rules from visual frames.

The approved vocabulary is three track-specific dance loops; four shared
screen-relative poses (hands-up, hands-left wave, screen-right dab, playful low
twerk); charge/unwind/snap/hold; life-loss recoil; survival celebration;
elimination to persistent sad stillness; and happy/moody result reactions.
Players may correct during a tunable grace window. Success requires the correct
direction, full charge, and held input at authoritative evaluation. A 1-second
fill and approximately 1.2-second expert grace are provisional starting points.

Implementation is deliberately staged: PS-011 proves one character in a debug
animation lab and requires human visual approval; PS-012 builds the production
animation library/API and measures eleven-character behavior; PS-013 implements
host-authoritative charge and evaluation. Do not combine these tasks into one
large implementation session or bypass their dependencies.

## PS-009 — character feet and reusable asset setup (2026-09-13)

**PS-009 is done.** The project owner explicitly approved the foot art on
2026-09-13 and requested completion. Pull-request merging remains an owner action.
This branch includes the preceding PS-009/PS-010 task-definition commit because
it is not yet on `main`. Unrelated local draft and task-board edits are excluded.

### Files and provenance

- `assets/Kenney_Shape_Characters/`: supplied Kenney Shape Characters 1.0,
  including both 104-image source sets, preview/sample, SVG/SWF overview,
  original CC0 license, and two updated PNG/XML atlases.
- `PNG/{Default,Double}/blue_foot_round.png`: one new right-facing rounded
  foot, 40 x 24 / 80 x 48, transparent and antialiased. Mirror for the left foot.
  One silhouette is the smallest useful set; additional poses await PS-010.
- `art/character-feet/blue_foot_round.xcf`: editable GIMP source with silhouette
  and highlight paths, blue gradient fill, and separate 20%-opacity white rim.
  Default was exported from a cubic downscale of the Double source.
- `art/character-feet/comparison-{default,double}.png`: native-resolution
  comparisons beside bodies, hands, face, assembled character, and environment.
- `art/character-feet/runtime-showcase.png`: captured from the actual Godot
  Compatibility renderer. `PROJECT_ADDITIONS.md` in the pack identifies the new
  feet as project additions, not Kenney originals.

Source inspection covered all 104 names at both resolutions, both atlases,
preview/sample, and the SVG overview. Bodies are 80 x 80 at Default, with smooth
vertical gradients and subtle top rims, not black outlines. Hands are roughly
28–38 pixels wide. The foot's rounded instep/toe and small bright rim follow
that treatment; neither realistic ankles nor a shoe sole outline were added.

Original standalone PNGs, license, preview/sample, and vector files remain
byte-identical. Atlas canvases grow only at the bottom: 577 x 605 and 1154 x 1210.
The new rectangles are (2,579,40,24) and (4,1158,80,48). Original rectangles
retain all coordinates and visible pixels. The atlases now use RGBA; invisible
RGB beneath alpha zero is not part of the appearance-preservation comparison.
Do not downscale the entire atlas to regenerate Default: original entries must
remain their supplied resolution-specific exports.

### Godot usage and designer controls

Instance `characters/shape_character.tscn`. Its six direct `Sprite2D` children
are `Body`, `Face`, `LeftHand`, `RightHand`, `LeftFoot`, and `RightFoot`.
Each has an independent position, rotation, scale, texture, and draw order.
Enable Editable Children on an instance to tune these in the inspector.
Body/face origins are their centers; hand origins are centers; feet have a
heel-biased pivot through ±12 Double-pixel sprite offsets. The root origin is
the body center. Default hand positions are (±55,20), feet (±20,60).
Body z=0, limbs z=1, face z=2. The left hand and foot use `flip_h`; transform
the whole root to place a character, not to recolor it. These defaults are
starting points for human pose experiments, not a committed rig or dance system.

Double is canonical at runtime, with each sprite scaled to 0.5 (80 world-unit
body). Set `player_color` on the root in the inspector or at runtime. Each
instance owns one shader material shared across its five colored parts.
Face has no tint material and retains the source white eyes and dark features.
The shader maps the canonical BLUE art's lightness into colored shadows and
highlights; keep blue body/hand textures when swapping the four body shapes or
six hand poses. Faces can use any `face_*.png`. No atlas parser, color-specific
assemblies, broad customization API, or per-color exports are required.

Keep root/ancestor `modulate` white, otherwise Godot will also modulate the face.
Use `player_color.a` for colored-part opacity only; use ancestor alpha deliberately
when fading the entire character. Very dark colors are lifted toward slate to
keep the dark face readable. This palette favors readability over exact requested
RGB reproduction. Color alone does not guarantee distinguishability for every
player or background; group readability and accessibility remain human checks.

`characters/background_sample.tscn` composes tree and three floor tiles as
ordinary sprites, with no collision, physics, or navigation. It can be instanced
and repositioned independently. It is a composition example, not a final level.

Open `characters/asset_showcase.tscn` and press **F6** for six color/pose examples
against light and dark backgrounds. F5 still starts the existing LAN lobby.
The review scene uses a responsive grid and static transforms only. It neither
starts services nor implements gameplay, networking, rigging, or animation clips.

### Import and authoring settings

All standalone PNGs use lossless compression, mipmaps, alpha-border fixing,
and disabled automatic 3D compression detection. Character and background roots
explicitly use **Linear with Mipmaps** and **Repeat Disabled**; children inherit.
This suits smooth art scaled down for a shared screen. Atlas imports retain no
mipmaps because the original pack has tightly adjacent entries without extrusion;
runtime uses standalone textures to avoid atlas bleed. Source previews/vectors
retain their original import defaults. `art/`, `tools/`, and `test-results/` are
excluded from Godot scanning via `.gdignore`, keeping review material and caches
out of the resource import/export set.

GIMP 3.2.6 showed false transparent stripes when loading some indexed originals.
Never overwrite those originals to fix the editor display. Run
`uv run --with pillow python tools/assets/prepare_gimp_inputs.py` to create
pixel-identical RGBA working copies in ignored `test-results/ps-009/gimp-rgba`.
GIMP performs the actual image composition using those copies. The preparation
script verifies each round-trip; it does not modify source files.
For review regeneration, set `PLAY_SHAPES_ROOT` to the checkout path in GIMP's
Python console, execute `tools/assets/compose_gimp_review.py`, call
`review('Default')` or `review('Double')`, and export that image as PNG.
Open the XCF to edit feet; save source before downscaling a duplicate for Default.
Update both atlas shelves and XML entries after any dimension/shape changes.

### Validation evidence and caveats

From the Godot project root:

```powershell
uv run --with pillow python tools/assets/validate_character_pack.py
godot --headless --editor --path . --quit-after 30
godot --path . --resolution 1152x800 --script res://tests/character_assets_test.gd
```

- **Automated image checks: passed.** 105 names per atlas, complete source sets,
  no overlaps, all rectangles in bounds, preserved original pixel hashes and
  source-file hashes, exact new-foot atlas pixels, transparent antialiased feet,
  exact 2x dimensions throughout, and intentional standalone import settings.
  Baselines in `art/character-feet/original_{manifest,file_hashes}.json` describe
  the supplied originals. Do not regenerate them to conceal a mismatch.
- **Editor load: passed** on Godot 4.7.2. No script or import failures on the final
  run. Early editor shutdown emits the existing MCP resource-cleanup warnings
  (68 objects / 33 resources), separately from loading errors. The initial
  sandboxed attempt could not access Godot's normal settings/cache directories;
  rerunning with access resolved that environmental failure.
- **Real renderer tests: passed** with GL Compatibility on RTX 5070. Six independent
  parts, per-instance material isolation, mirrored feet, changed body pixels after
  tinting, unchanged other player, and 260 unchanged opaque facial pixels.
  The test uses a five-source-pixel interior mask to exclude mipmapped alpha edges;
  a tighter mask falsely included blended body/face edge pixels. It has a timeout
  so an assertion cannot leave a test process running indefinitely.
- **Visual inspection: performed.** Both source-resolution sheets, the vector
  overview, live Godot window through Computer Use, and final renderer capture
  were inspected. Very dark tints were lifted after the first runtime comparison.
- **Human art approval: approved on 2026-09-13.** The owner explicitly approved
  the foot art and requested PS-009 be marked done. The comparison images retain
  their original review-time "art approval pending" captions as historical evidence;
  this approval record supersedes those captions.
  Physical-phone checks, game-feel playtesting, final dance readability, and
  exported-build verification are outside this asset task's technical evidence.

The image scripts were verified with Pillow 12.3.0 (`get_flattened_data`); the `uv --with`
commands install an isolated tool dependency, not a game runtime dependency.
If the normal uv cache is blocked, set `UV_CACHE_DIR` to an ignored folder under
`test-results/`. Renderer-test output is in `test-results/ps-009/render-test.log`
when launched with `--log-file`; its committed screenshot is refreshed each run.

## Planning and task context

The canonical planning layer is Markdown under `Project/`, `Drafts/`, `Roadmap/`,
`Tasks/`, and `Decisions/`. Future agents should begin with
[Project Overview](Project/Project%20Overview.md), then read
[Task Index](Task%20Index.md), the selected task, and its linked decisions
before proposing or implementing work. The interactive Obsidian view is
[Task board](Task%20board.md); its manual-index fallback requires no plugin.

Implementation work must happen in a separate execution session from planning.
An implementation task is not ready until its scope, acceptance criteria,
dependencies, and draft execution prompt reflect approved design decisions.

## Phase 1 — LAN hello world (2026-09-09)

Implemented: boot starts HTTP and WebSocket services, then opens the lobby
playground with a join QR code. A browser on the same LAN loads the bundled
Hello world page and completes a versioned WebSocket handshake with Godot.
No player names, characters, controller inputs, persistence, or minigames yet.

Physical-phone scanning and cross-device network access are the remaining
acceptance check. Desktop Chrome successfully loaded the Wi-Fi address and
displayed the connected state. Do not equate this with a physical-phone test.

## Project location and running

The Git repository and Godot root are this `play-shapes/` directory, nested
inside the parent notes vault. Keep `project.godot` here. The parent contains
`AGENTS.md`, `Development phase 1.md`, `Main.md`, `Stack.md`, and
`Lobby playground.md`; read those before expanding scope. Their instruction
that the parent is the Godot root does not match the existing filesystem.

Open `project.godot` in Godot 4.7.2 and press F6 for an individual scene only
when appropriate; use **F5** for the complete boot flow. Or from this directory:

```powershell
godot --path .
```

Select the host's Wi-Fi/Ethernet IPv4 address in the lobby. Phones must use
the same reachable LAN. Scan the QR or type its displayed URL. The current
address is detected each launch; it is not stored in source. Refresh rescans
adapters and preserves the current choice when possible. Common `192.168.*`
addresses are preferred, but this is a heuristic, not default-route detection.
VPNs, multiple interfaces, and guest Wi-Fi can require manual selection.
Loopback, link-local, and IPv6 addresses are excluded. No address means no QR.

PS-006 replaced the lobby's old browser-connection diagnostic with the
authoritative player roster. Reloading still creates a new transport connection
ID, but the browser-held token resumes the same session player during its grace
period; see the PS-006 section above.

## Code map

- `scenes/boot.*`: starts services, displays a startup error and Retry on failure.
- `host/session_host.gd`: autoload owning service and player-registry lifecycle
  across scene changes, settings, address discovery, and URL construction.
  WebSocket bind failure rolls back HTTP startup. `stop()` releases listeners
  and connected peers.
- `Tuning/Shared/Networking/Default.tres`: inspector-editable ports, connection limit and
  request/handshake timeout, player capacity, and reconnect grace. Defaults:
  HTTP 8080, WebSocket 8081, 32 connections per service, 20 players, five-second
  timeout, and 60-second reconnect grace. Restart to apply changed settings.
- `host/player_registry.gd`: authoritative session/player/token identities,
  name validation, capacity, disconnect grace, resume, and explicit leave.
- `host/http_service.gd`: fixed route allowlist, bundled assets, bounded request
  buffers, nonblocking partial reads/writes, one GET per connection. No arbitrary
  filesystem access or client-selected resource loading.
- `host/websocket_service.gd`: bounded peers/messages and versioned
  hello/welcome, join, resume, and leave transport. It rejects malformed or
  unauthorized actions and delegates authoritative identity changes to the
  registry.
- `scenes/lobby.*`: editor-visible Control/Container billboard, address picker,
  refresh/copy actions, nearest-filtered QR texture with a four-module margin,
  and the public player roster.
- `web/src/app.ts`: thin browser client, five-second config fetch timeout,
  seven-second WebSocket deadline, and two-second retry. It stores only the
  session/token/last-name identity needed for resume and handles pagehide/pageshow
  for browser back-forward cache restoration.
- `web/public/`: offline HTML/CSS and committed compiled JavaScript. Godot serves
  these directly, so running the game requires neither Node nor internet access.
- `addons/kenyoni/qr_code/`: unmodified MIT QR runtime files pinned to commit
  `3d92d1bab93c0a8cb58951c039ddb17acd70a449`. See UPSTREAM.md and LICENSE.md.
  The existing Godot MCP addon and configuration were left unchanged. Upstream
  trailing whitespace is preserved; exclude this vendor directory from whitespace
  checks. GitHub marks the directory as vendored to keep reviews focused.

## Protocol version 1

GET `/session.json` returns `protocol` and `websocket_port`. The browser uses
the page hostname for `ws://HOST:PORT`.

```json
{"type":"hello","protocol":1}
```

Godot assigns the connection ID and replies:

```json
{"type":"welcome","protocol":1,"connection_id":1,"message":"Hello world"}
```

The HTTP server also serves `/`, `/app.js`, `/style.css`; unknown routes return
404 and non-GET methods return 405. Headers exceeding 8192 bytes are rejected
with 431 or a TCP reset if unread request bytes remain (Windows socket behavior).
There is no TLS, authentication, public hosting, or CORS API in this phase.
The listeners bind all interfaces for LAN access. Do not forward these ports
to the internet. Console packaging/network permissions remain future work.

## Build and verification

Node 22+ is needed only for development/tests (validated with Node 24.20.0).
After TypeScript changes, rebuild and commit `web/public/app.js` with its source.

```powershell
cd web
npm.cmd ci --ignore-scripts
npm.cmd run build
npm.cmd run check
npm.cmd test
```

Close the interactive game before tests. The suite refuses to test over an
existing host and launches its own Godot process. `GODOT_BIN` can override the
Windows executable default in `web/tests/host.test.mjs`. Tests also use ports
18080/18081 for startup rollback/retry/restart checks. QR decoder dependencies
are development-only; they are never shipped to phones.

From the Godot root:

```powershell
godot --headless --editor --path . --quit-after 30
```

Validated: TypeScript build/check; six integration tests covering actual HTTP
assets/config, independent QR decoding, route/method rejection, fragmented and
oversized requests, four simultaneous WebSockets with distinct IDs, malformed
and unauthorized state messages; startup rollback, retry and restart checks.
Godot runtime logs had no script/runtime errors. Headless editor import had no
parse errors; early editor shutdown reports MCP resource-cleanup warnings.
Visually checked the lobby QR and Chrome's Hello world/connected page via the
LAN address, including reconnection after restarting the host. A real phone scan
and mobile-browser layout check remain pending.

## Networking and export caveats

If a phone cannot load the page, check the displayed adapter, same Wi-Fi,
VPN LAN restrictions, guest-network client isolation, and Windows Firewall.
HTTP **and** WebSocket TCP ports must be reachable. If Windows asks to allow
Godot on a private network, the user should handle that permission. This work
does not change firewall or VPN settings. A busy port produces Retry in boot.

No export preset is created in this phase. When adding one, explicitly include
`web/public/*.html,web/public/*.css,web/public/*.js` as non-resource files and
exclude `web/node_modules/*`, `web/src/*`, `web/tests/*`, `tests/*` and
`test-results/*`. Otherwise Godot's export filtering can omit the web assets.
Validate an exported build separately; editor/runtime checks do not prove export.

## Next iteration

Confirm the physical-phone acceptance check, then add validated join/name
messages and a host-owned player registry as separate components. Keep browser
connection IDs separate from stable player identity. Add gameplay only after
that layer has explicit reconnect/disconnect rules.
