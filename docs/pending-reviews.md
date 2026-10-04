# Pending reviews

What still needs a person, a real phone or an exported package before it can be called
checked. Automated tests and render captures do not settle any of it. Remove an entry when
the review is done, and record the device and browser versions in the pull request that
removes it. The evidence labels are defined in
[verification.md](verification.md#evidence-labels).

## Bubbles and Jellyfishes

- `[HUMAN-PLAY]` The owner's two-phone play and game-feel review.
- `[HUMAN-PLAY]` Couch-distance readability of the shared screen, the final audio mix, and
  the fairness of creature collisions and telegraphs.

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
- Two players on one Open surface: drop one to the next surface, then check that
  `BottomShelf` rejects FALL.
- Set another platform to Closed in the Inspector and check it alone changes.
- Feet stay grounded, and characters still interact as before.

## Squircle look-up and crouch

- `[HUMAN-PLAY]` The owner's approval of the animation timing and feel, and of the poses.
- `[PHYSICAL-PHONE]` How the stances read on a real phone and from the couch.

## Squircle source and sheets

The sheets were rendered again on another machine after the names inside the Blender source
changed. A pixel comparison with the previous sheets found nothing a viewer should notice.

- `[GODOT-RUNTIME]` A look at the Squircle in the lobby and in the F12 Animation Lab, in every
  clip and both views.
- The source opened in Blender by someone who edits it: the scene, the actions and the face
  images are found under their new names. No evidence label covers Blender.

## Phone client

Record the exact OS and browser versions for each row.

| Device and browser | Journey to check |
| --- | --- |
| iPhone Safari | The offer in a tab; Share, Add to Home Screen, Open as Web App; launching the icon to the current host; the standalone layout; switching with separate or shared storage; lobby stick and jump together; READY and CANCEL; Bubbles swipe, spin and cancel; the keyboard; pinch and double tap; bars and rotation; background, lock and unlock; the motion lab permission. |
| Android Chrome | A real native install event when eligible; the accepted, dismissed and unsupported paths; launching the icon; the same play, lifecycle, keyboard and permission journey. |
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

- `[GODOT-RUNTIME]` A look at the text of the animation lab note, the motion lab readings and
  pose hint, and the phone's motion lab panel and error panel. Tests cover their content; no
  one has looked at them on a screen since their strings were last rebuilt.

## Tooling on other platforms

- `[AUTO]` `node tools/setup.mjs` and `node tools/check.mjs` on macOS and Linux. Only Windows
  has been run. The formatter checksums for the other platforms were recorded from the
  release, not run.
