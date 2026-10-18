# Pending reviews

What still needs a person, a real phone or an exported package before it can be called
checked. Automated tests and render captures do not settle any of it. Remove an entry when
the review is done, and record the device and browser versions in the pull request that
removes it. The evidence labels are defined in
[verification.md](verification.md#evidence-labels).

## Playground plaza lobby

- `[GODOT-RUNTIME]` and owner visual review of the running plaza against the approved mockup:
  composition, colors, lighting, the Squircle's scale beside the props, and the nameplates.
  Captures are in `test-results/lobby-playground-world/`.
- `[HUMAN-PLAY]` Movement feel with the new jump height, roof reachability from the tables,
  jump corridors, ten-player readability and game feel.
- The soft sunset lighting, the extra trees and plants, the angled chairs and the larger
  billboard set further back, at the real camera.
- `[HUMAN-PLAY]` Characters drawn in front of chairs, tables and the café instead of
  clipping into them, including while jumping up through or falling through a landing.
  Owner decision whether this replaces true depth layering.
- `[PHYSICAL-PHONE]` Scanning the billboard QR from the couch at real viewing distance.
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

## Tilt Shift rules

- `[EDITOR]` Owner inspection of the rules profile, round mapping, geometry and neighbor
  diagnostics. Automated Resource reload does not establish Inspector usability.
- `[HUMAN-PLAY]` Owner tuning of duration/count and proximity, and strategic fairness
  of ownership variety after gameplay integration.
- `[HUMAN-PLAY]` Owner approval of A/B selection, spectator cadence, shared-paddle variety
  and neutral rotation across 2/4/6/8/10 players. Synthetic fairness is not strategic fairness.
- `[EDITOR]` Owner usability review of Tunables, per-layout dimensions, round mappings,
  field explanations and saving/applying the same profile to runtime and preview.

## Tilt Shift physics

- `[HUMAN-PLAY]` Owner review of the 20-ball negative delivery curve, smooth 70% peak,
  one-point penalty, brighter blue/white-rim visibility and enlarged ball contacts and routing.
- `[EDITOR]` Owner usability review of negative color picker, separate count/curve controls and graph
  in workshop Tunables, including save/apply and undo/redo.
- `[EDITOR]` Owner inspection of the physics profile's units, delivery curve points,
  materials and launch errors. Script save/reload and editor import do not prove usability.
- `[HUMAN-PLAY]` Owner tuning of density, curve shape, dimensions, gravity, entry speed,
  friction and restitution; routing coverage, fairness and full-turn control feel.
- `[PHYSICAL-PHONE]` Responsiveness and physical-angle presentation once motion/phone
  integration uses the arena's confirmed pose rather than its requested target.
- `[EXPORTED-BUILD]` Physics and cleanup in the integrated Windows minigame.
- `[EDITOR]` Owner usability review of the workshop, guide measurements, snap/tolerance
  preferences and save/preview workflow. Scripted editor checks and captures do not
  establish usability. The workshop now consumes the actual runtime arena.

## Tilt Shift calibrated motion

- `[PHYSICAL-PHONE]` Owner Chrome trials on Android and iPhone: verify normal lobby Start
  shows shared preparation, portrait blocks READY, both landscape holds permit READY,
  rotation lock guidance is sufficient, portrait revokes READY, and all-player readiness
  transfers neutral into gameplay. Delay permission and test preparation reconnect/cancel.
- `[PHYSICAL-PHONE]` Owner trials on supported iPhone and Android browsers: record versions,
  comfortable sideways neutral, both holds, mirrored tilts, repeated full turns/reversal,
  screen autorotation, off-axis tolerance, denial, background/lock and permission recovery.
- `[PHYSICAL-PHONE]` Ten-phone load, end-to-end sensor delay and reconnect correction with
  neutral preserved. Synthetic traffic and CPU measurements do not establish these results.
- `[HUMAN-PLAY]` Owner approval of gain, filtering needs and target-versus-collider lag.
  The initial gain is 1, with continuous mode and no extra smoothing.
- `[EDITOR]` Owner inspection of the motion profile's units, valid ranges and launch errors.
- `[EXPORTED-BUILD]` Calibrated control and lifecycle after readiness/phone integration.

## Phone screen wake protection

- `[PHYSICAL-PHONE]` Owner Chrome trials on Android and iPhone over trusted HTTPS: leave
  onboarding, lobby, preparation, gameplay and results untouched beyond the phone's normal
  screen timeout. Confirm the screen stays awake and Tilt Shift keeps sending input.
  Check app switching and return, reload, low-power refusal and installed-app behavior.
  Record device, OS and browser versions; synthetic locks do not establish OS behavior.

## Bubbles and Jellyfishes

- `[HUMAN-PLAY]` The owner's two-phone play and game-feel review.
- `[HUMAN-PLAY]` Couch-distance readability of the shared screen, the final audio mix, and
  the fairness of creature collisions and telegraphs.

## Bubbles and jellyfishes 3D

- `[HUMAN-PLAY]` The owner's play review side by side with 002: swipe responsiveness, movement
  feel, bump and wall rebounds, catching and pops, difficulty, readability at couch distance
  with 5 and 10 players, the underwater look and fun. Every tuning value is provisional.
- `[PHYSICAL-PHONE]` On the iPhone Safari and Android Chrome pair: the three.js view's
  rendering and frame rate, the time to first frame while the models download, swipe
  reliability, latency, haptics where supported, reconnect and the no-WebGL fallback.
- `[HUMAN-PLAY]` The final audio mix, including the countdown beats on the shared cue.
- `[HUMAN-PLAY]` Whether the Squircle should keep drawing over its bubble's highlight, as it
  does in the lobby to stay in front of scenery.
- A 3D Pre-minigame preview image from the owner; the booklet still shows 002's.
- `[GODOT-RUNTIME]` Host frame time on the target PC. `bubbles_3d_performance_check.gd` measured
  ten players, 70 free and 160 caught jellyfishes at 0.76 ms a frame on average (1.17 ms at the
  95th percentile, 182 draw calls) on an RTX 5070 development machine only.

## Bubbles and jellyfishes 3D models

- Owner approval of the jellyfish and pufferfish look from the review renders that
  `render_review.py` in [art/bubbles_3d](../art/bubbles_3d/README.md) writes: the reshaped
  bell, the curled tentacles, the pufferfish face, spikes and fins.
- Owner review of both creatures and the recoloured props in the running scene. Captures from
  `bubbles_3d_scene_visual_check.gd` are in `test-results/bubbles-3d/`.

## Tilt Shift art

- `[PHYSICAL-PHONE]` One-paddle guide readability on a real landscape phone across
  every supported roster, including shared-paddle participants and spectator transitions.
- `[HUMAN-PLAY]` Couch-distance readability of balls, paddles and basket openings,
  including different basket widths/counts and ten operator stations.
- `[HUMAN-PLAY]` Both-side Squircle hand contact and lever travel when operating
  animation consumes the documented art anchors.
- `[EXPORTED-BUILD]` Run the integrated Tilt Shift presentation in a Windows package.

## Tilt Shift factory presentation

- `[HUMAN-PLAY]` Owner review of ball/paddle/basket readability at couch distance,
  ownership badges, selected character colors, inward-facing operators and ten-player density.
- `[HUMAN-PLAY]` Full-width basket routing, colored score numbers and deeper fronts at
  FHD/HD/4:3. The default row has no gaps and catches by center at shared rims.
- `[HUMAN-PLAY]` Lever loop, reversal and held poses on both sides; catch/cutoff and
  cumulative score/round/win/draw feedback. Runtime captures do not establish feel.
- `[PHYSICAL-PHONE]` Accepted-motion timing and shared-screen readability during real play.
- `[EDITOR]` Owner inspection of `Presentation.tres` and the art-equipped workshop preview.

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

## Squircle look-up and crouch

- `[HUMAN-PLAY]` The owner's approval of the animation timing and feel, and of the poses.
- `[PHYSICAL-PHONE]` How the stances read on a real phone and from the couch.

## Squircle lever pull

- `[HUMAN-PLAY]` Owner approval of the reach, downward pull, upward return and loop
  timing in F12 > Animation Lab > Lever Pull, including the small reference size.

## Squircle source and sheets

The sheets were rendered again on another machine after the names inside the Blender source
changed. A pixel comparison with the previous sheets found nothing a viewer should notice.

- `[GODOT-RUNTIME]` A look at the Squircle sheets in the ready screen and in the F12 Animation
  Lab, in every clip and both views.
- The source opened in Blender by someone who edits it: the scene, the actions and the face
  images are found under their new names. No evidence label covers Blender.

## Tilt Shift phone and complete flow

- `[PHYSICAL-PHONE]` Chrome on iPhone and Android: real gesture permission, denied/no-event
  paths, comfortable sideways neutral, portrait/landscape changes, repeated full turns,
  gameplay reconnect without neutral reset, lock/background/foreground and lobby cleanup.
  Record exact device, OS and browser versions. Synthetic Chromium events do not cover this.
- `[HUMAN-PLAY]` One-paddle phone guide readability and responsiveness, the provisional
  countdown/START, participant panel, team waiting visuals and fairness with both layouts.
- `[PHYSICAL-PHONE]` Selected-player READY/CANCEL, between-round recalibration, neutral
  preservation on reconnect, timeout/force start and disconnected-angle holds.
- `[EXPORTED-BUILD]` Physical-phone play against the Windows executable; desktop
  export/pack checks do not establish this real-device journey.
- Audio selection, whistle playback and listening remain deferred.

## Phone client

Record the exact OS and browser versions for each row.

| Device and browser | Journey to check |
| --- | --- |
| iPhone Safari | The page loads the bundled client and reaches the name screen; the offer in a tab; Share, Add to Home Screen, Open as Web App; launching the icon to the current host; the standalone layout; switching with separate or shared storage; lobby stick and jump together; READY and CANCEL; Bubbles swipe, spin and cancel; the keyboard; pinch and double tap; bars and rotation; background, lock and unlock; the motion lab permission. |
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

- `[GODOT-RUNTIME]` Owner visual review of Tilt Shift simulated controls: automatic countdown,
  paddle motion, later rounds, restart and lobby return. Automated progression uses shortened
  in-memory timing and does not establish presentation or game feel.
- `[GODOT-RUNTIME]` A look at the text of the animation lab note, the motion lab readings and
  pose hint, and the phone's motion lab panel and error panel. Tests cover their content; no
  one has looked at them on a screen since their strings were last rebuilt.

## Tooling on other platforms

- `[AUTO]` `node tools/setup.mjs` and `node tools/check.mjs` on macOS and Linux. Only Windows
  has been run. The formatter checksums for the other platforms were recorded from the
  release, not run.
