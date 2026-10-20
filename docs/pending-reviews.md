# Pending reviews

What still needs a person, a real phone or an exported package before it can be called
checked. Automated tests and render captures do not settle any of it. Remove an entry when
the review is done, and record the device and browser versions in the pull request that
removes it. The evidence labels are defined in
[verification.md](verification.md#evidence-labels).

## Playground plaza lobby

- `[GODOT-RUNTIME]` and owner visual review of the running plaza against the approved mockup:
  composition, colors, lighting, the Cubio's scale beside the props, and the nameplates.
  Captures are in `test-results/lobby-playground-world/`.
- `[HUMAN-PLAY]` Movement feel with the new jump height, roof reachability from the tables,
  jump corridors, ten-player readability and game feel.
- The soft sunset lighting, the extra trees and plants, the angled chairs and the larger
  billboard set further back, at the real camera.
- `[HUMAN-PLAY]` Characters drawn in front of chairs, tables and the café instead of
  clipping into them, including while jumping up through or falling through a landing.
  Owner decision whether this replaces true depth layering.
- `[PHYSICAL-PHONE]` Scanning the billboard QR from the couch at real viewing distance, now
  that it fills the display.
- Owner visual review of the café [logo sign](../art/playground_plaza/logo_sign/README.md) at
  the real camera: letter depth, cream backing, posts, and characters on the roof in front.
- `[PHYSICAL-PHONE]` The installed app icon with the stacked logo at Home Screen size.
- `[GODOT-RUNTIME]` Host frame time with ten players on the target PC. Not yet measured.
- `[EXPORTED-BUILD]` The Windows package opens the plaza with every model and license.

## Playground plaza cafe table

- After separate scene integration, `[GODOT-RUNTIME]` materials and final-camera inspection,
  and `[HUMAN-PLAY]` middle-tier reachability, ten-player readability and game feel.
  Integrated rendering performance remains unmeasured; no import/gameplay evidence is supplied.
- Before publication, resolve the pack-specific license evidence recorded in
  [table provenance](../art/playground_plaza/table/source/PROVENANCE.md).

## Playground plaza billboard

- Owner visual approval of the
  [billboard source and previews](../art/playground_plaza/billboard/README.md):
  square display, frame proportions, grounded support silhouette and low-poly finish.
  Automated source/export checks and Blender renders do not establish creative approval.
- After separate scene integration, `[GODOT-RUNTIME]` materials, display mapping and high,
  horizontally centered placement at the final camera; `[PHYSICAL-PHONE]` QR scanning at
  actual viewing distance; and `[HUMAN-PLAY]` ten-player readability. Integrated rendering
  performance remains unmeasured. No Godot import or gameplay evidence is supplied here.

## Playground plaza cafe

- Owner visual approval of the [cafe source and preview renders](../art/playground_plaza/cafe/README.md):
  facade and cup readability, flat roof silhouette, shallow decorative trim and low-poly finish.
  Automated source/export checks and Blender renders do not establish creative approval.
- After separate scene integration, `[GODOT-RUNTIME]` material and final-camera inspection,
  and `[HUMAN-PLAY]` roof reachability, ten-player readability and game feel. No Godot import
  or gameplay evidence is supplied by the standalone model delivery.

## Phone screen wake protection

- `[PHYSICAL-PHONE]` Owner Chrome trials on Android and iPhone over trusted HTTPS: leave
  onboarding, lobby, preparation, gameplay and results untouched beyond the phone's normal
  screen timeout. Confirm the screen stays awake and Tilt Shift 3D keeps sending input.
  Check app switching and return, reload, low-power refusal and installed-app behavior.
  Record device, OS and browser versions; synthetic locks do not establish OS behavior.

## Bubbles and jellyfishes 3D

- `[HUMAN-PLAY]` The owner's play review: swipe responsiveness, movement feel, bump and wall
  rebounds, catching and pops, difficulty, readability at couch distance with 5 and 10 players,
  the underwater look and fun. Every tuning value is provisional.
- `[PHYSICAL-PHONE]` On the iPhone Safari and Android Chrome pair: the three.js view's
  rendering and frame rate, the time to first frame while the models download, swipe
  reliability, latency, haptics where supported, reconnect and the no-WebGL fallback.
- `[HUMAN-PLAY]` The final audio mix, including the countdown beats on the shared cue.
- `[HUMAN-PLAY]` Whether the Cubio should keep drawing over its bubble's highlight, as it
  does in the lobby to stay in front of scenery.
- `[GODOT-RUNTIME]` Host frame time on the target PC. `bubbles_3d_performance_check.gd` measured
  ten players, 70 free and 160 caught jellyfishes at 0.76 ms a frame on average (1.17 ms at the
  95th percentile, 182 draw calls) on an RTX 5070 development machine only.

## Bubbles and jellyfishes 3D models

- Owner approval of the jellyfish and pufferfish look from the review renders that
  `render_review.py` in [art/bubbles_3d](../art/bubbles_3d/README.md) writes: the reshaped
  bell, the curled tentacles, the pufferfish face, spikes and fins.
- Owner review of both creatures and the recoloured props in the running scene. Captures from
  `bubbles_3d_scene_visual_check.gd` are in `test-results/bubbles-3d/`.

## Tilt Shift 3D face parts and bin

- Owner review of the thirty-seven emoji expressions in the Godot 3D front, three-quarter and
  blink captures from `tests/shape_face_3d_visual_check.gd`, under
  `test-results/shape-face-emoji/`: whether each reads as its emoji, especially the similar
  unhappy faces, kissing-eye variations, subtle smiles, exhaustion, toothy mouths and dazed
  eyes, and stays readable at default paddle proportions. The captures are paginated;
  `-- --start=27` starts at the ten added dazed and intense presets. New gameplay assignments
  and adoption by the lobby's Squircle are separate decisions.
- Physical-phone readability of the emoji presets when selected in a test profile remains
  unverified; desktop browser checks only establish composition and loading.
- Owner approval of the face presets from the review sheets that `export_faces.mjs --review` in
  [art/shape_characters_face_system_assets](../art/shape_characters_face_system_assets/README.md)
  writes: all twelve at 1× beside their reference faces, and at 8×, drawn from the exported
  parts and the manifest.
- Owner approval of the bin from the renders that `render_review.py` in
  [art/tilt_shift_3d](../art/tilt_shift_3d/README.md) writes: openings of 0.10, 0.20 and 0.40
  arena widths in orange, blue and grey, and heights of 0.75 and 2 times.
- The faces and bins in the running scene are reviewed with minigame 005.

## Tilt Shift 3D

- `[HUMAN-PLAY]` Feel: tilting responsiveness on Jolt, including balls rolling off the rounded
  ends and resting on the thicker paddles, and catches at the raised floor; density, curve
  shape, negative delivery curve and one-point penalty, dimensions, gravity, entry speed,
  friction and restitution; routing coverage, fairness and full-turn control feel; gain,
  filtering needs and target-versus-collider lag.
- `[HUMAN-PLAY]` Rules and fairness: duration, round count and proximity; strategic fairness of
  ownership variety; A/B selection, spectator cadence, shared-paddle variety and neutral
  rotation across 2/4/6/8/10 players; participant panel, countdown/START, catch/cutoff and
  cumulative score/round/win/draw feedback.
- `[HUMAN-PLAY]` Readability at couch distance with layout A and four players and layout B
  and six: paddle look, gap ring and team outline with every player colour on both teams,
  the grey automatic paddle, ball and bin contrast, the cream wall and props.
- `[HUMAN-PLAY]` Faces: whether they read at the default thickness, whether dizzy and
  startled read as different at a glance, the timing of blinks, dizziness, startle and the
  squash, the countdown and result faces, and whether 150°/s triggers dizziness too often.
- `[HUMAN-PLAY]` Names: five seconds and the fade; overlap when two paddles sit close.
- `[HUMAN-PLAY]` Layout spacing after the thicker paddles and raised floor, and every
  starting value in [the tuning guide](../minigames/005_3d_tilt_shift/tuning/README.md).
- `[PHYSICAL-PHONE]` On the iPhone Safari and Android Chrome pair: normal lobby Start showing
  shared preparation, portrait blocking and revoking READY, both landscape holds permitting
  READY, rotation lock guidance, comfortable sideways neutral, mirrored tilts, repeated full
  turns/reversal, screen autorotation, off-axis tolerance, denial/no-event paths,
  background/lock and permission recovery.
- `[PHYSICAL-PHONE]` On the same phone pair: selected-player READY/CANCEL, between-round
  recalibration, neutral preservation on reconnect, timeout/force start, disconnected-angle
  holds, ten-phone load, the 3D paddle's rendering and frame rate, the face parts loading over
  the LAN and HTTPS, spectators' resting paddle, and the flat drawing where WebGL is off.
- `[EXPORTED-BUILD]` A Tilt Shift 3D shift played from the Windows package, with real phones
  loading `/three_view.js` and the face parts from it.
- `[GODOT-RUNTIME]` Frame time on the target PC with `tilt_shift_3d_performance_check.gd`.
  On the development PC (RTX 5070, Core Ultra 7 265KF) ten players and 80 balls in 20 seconds
  averaged 0.62 ms per frame, 95th percentile 0.95 ms, with up to 118 draw calls.
- `[EDITOR]` Usability of the Tilt Shift 3D workshop tab, Tunables, negative color picker and
  delivery curve controls, guide measurements, snap/tolerance preferences, save/apply,
  undo/redo and its 3D preview, plus Inspector usability of the rules, physics and motion
  profiles.
- Audio selection, whistle playback and listening remain deferred.

## Platform movement in the lobby

`[PHYSICAL-PHONE]`, on real phones:

- Stick and action button touched together.
- Jitter around the vertical sectors, and diagonals.
- Changing direction while the action button is being released.
- Repeated FALL, and cancellation.
- Backgrounding and rotation.
- Disconnect and resume.
- Responsiveness.

`[HUMAN-PLAY]`, the owner's review of stances, animation and feel:

- The sector widths and the gesture that re-arms FALL.
- Drop speed and clearance, and behavior on stacked surfaces and at edges.
- Two players on one Open surface: drop one to the next surface, then check that the
  ground rejects FALL.
- Set another platform to Closed in the Inspector and check it alone changes.
- Feet stay grounded, and characters still interact as before.
- The lobby on Jolt ([0042](decisions/0042-plaza-lobby-jolt-plane.md)): running, jumping
  up through landings, landing on edges, bouncing off other players and FALL still feel as
  they did on the 2D plane.

## Cubio look-up and crouch

- `[HUMAN-PLAY]` The owner's approval of the animation timing and feel, and of the poses.
- `[PHYSICAL-PHONE]` How the stances read on a real phone and from the couch.

## Cubio lever pull

- `[HUMAN-PLAY]` Owner approval of the reach, downward pull, upward return and loop
  timing in the Blender source and current motion-pose review images.

## Phone client

Record the exact OS and browser versions for each row.

| Device and browser | Journey to check |
| --- | --- |
| iPhone Safari | The page loads the bundled client and reaches the name screen; the offer in a tab; Share, Add to Home Screen, Open as Web App; launching the icon to the current host; the standalone layout; switching with separate or shared storage; lobby stick and jump together; READY and CANCEL; Bubbles and jellyfishes 3D swipe and cancel; the keyboard; pinch and double tap; bars and rotation; background, lock and unlock; the motion lab permission. |
| Android Chrome | The page loads the bundled client and reaches the name screen; a real native install event when eligible; the accepted, dismissed and unsupported paths; launching the icon; the same play, lifecycle, keyboard and permission journey. |
| Both | Host restart, grace expiry, a change of LAN origin, certificate trust, reconnecting to the current host, and no duplicate active players after switching from browser to app. |
| Both | Measured timing from touch to host receipt, and subjective responsiveness. Name the measurement method, the sample count and the versions. |

Also unverified: how a Safari tab and the installed app share or separate storage on a real
device.

## Local HTTPS

- `[PHYSICAL-PHONE]` Safari, and the installed app, with the development certificate. Testing
  so far uses Chrome.
- `[PHYSICAL-PHONE]` Reaching and trusting a `.local` hostname from every test phone.

## Motion lab

- `[PHYSICAL-PHONE]` The checklist in
  [motion-input.md](motion-input.md#checking-it-on-a-real-phone), on Chrome for iPhone and
  Android.

## Exported package

- `[EXPORTED-BUILD]` Real phones playing against the exported executable, including the
  installed app.

## Debug screens

- `[GODOT-RUNTIME]` Owner visual review of Tilt Shift 3D simulated controls: automatic countdown,
  paddle motion, later rounds, restart and lobby return. Automated progression uses shortened
  in-memory timing and does not establish presentation or game feel.
- `[GODOT-RUNTIME]` A look at the motion lab readings and pose hint, and the phone's motion
  lab panel and error panel. Tests cover their content; no
  one has looked at them on a screen since their strings were last rebuilt.

## Tooling on other platforms

- `[AUTO]` `node tools/setup.mjs` and `node tools/check.mjs` on macOS and Linux. Only Windows
  has been run. The formatter checksums for the other platforms were recorded from the
  release, not run.

## Cubio character and live previews

- Owner visual approval of the two-metre cube, small bevel, existing floating limbs and
  retained face, at lobby and Bubbles gameplay distances and in the live Ready-screen tray.
  Source renders are in [the Cubio folder](../art/cubio/README.md).
- `[HUMAN-PLAY]` Existing idle, walk, run, look-up, crouch and lever-pull motion on the deeper
  body, plus lobby movement, jumps and readability with ten players.
- `[PHYSICAL-PHONE]` Android Chrome and iPhone Safari: live setup preview, selected color,
  back/next navigation, first model download, app icons and rendering performance. Confirm
  joining remains possible when WebGL is unavailable.
