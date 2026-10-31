---
area: Minigames
tags: [hub]
code: [minigames/005_3d_tilt_shift, web/src/005_3d_tilt_shift, assets/runtime/minigames/tilt_shift_3d, addons/tilt_shift_3d_workshop, TiltShift3DMotionController, minigames/005_3d_tilt_shift/tilt_shift_3d_session.gd]
verified: 2026-10-31
branch: feature/knowledge-base
---

# 005 Tilt Shift

Hub of minigame 005, Tilt Shift 3D. Parent: [[Minigames]]. Two equal teams tilt their phones
to steer paddles that guide falling balls into their bins.

## Identity

| Number | Players | Phone input | Status |
| --- | --- | --- | --- |
| 005 | 2, 4, 6, 8 or 10 | landscape tilt over HTTPS motion sensors | playable; replaced the retired 2D Tilt Shift, 003 |

## Where in code

- Host: `minigames/005_3d_tilt_shift/`, with a session script, `tilt_shift_3d_session.gd`.
- Phone: `web/src/005_3d_tilt_shift/`, drawing the player's own paddle in three.js.
- Runtime art: `assets/runtime/minigames/tilt_shift_3d/`; sources in `art/tilt_shift_3d/`.
- Workshop: the editor addon `addons/tilt_shift_3d_workshop/`, not yet on the shared window.

## This folder

| Note | Holds |
| --- | --- |
| [[005 Ownership]] | what each script owns; paddles and faces |
| [[005 Code Map]] | the controller, arena, motion and session in the code |
| [[005 Messages]] | the motion, calibration and round messages |
| [[005 Phone Screen]] | what the phone shows in preparation and play |
| [[005 Motion Control]] | how tilt becomes a paddle angle |
| [[005 Preparation Lifecycle]] | permission, calibration and landscape from Ready to play |
| [[005 Tuning]] | the tuning guide and its Resources |
| [[005 Flow Tuning]], [[005 Motion Tuning]], [[005 Physics and Delivery]] | the three tuning groups |
| [[005 Workshop]] | the editor workshop addon |
| [[005 Scene Composition]] | the factory scene |
| [[005 Asset Sources]], [[005 Art Assets]] | provenance and the art pipeline |

## Messages and authority

The host owns teams, rounds, allocation, scoring and every body; the phone streams its
orientation and the host turns it into held angles. See [[005 Messages]] and [[Motion Input]].

## Prediction

None. The phone shows its paddle from host state.

## Workshop and tuning

Selected Resources and their fields are in [[005 Tuning]]; the workshop is [[005 Workshop]].
F12 offers a simulated factory with ten synthetic players ([[Debug Menu]]).

## Verification

The `tests/` folder of the minigame; see Tilt Shift 3D in
[[Verification#Focused checks by area]]. Motion needs `[PHYSICAL-PHONE]` evidence over HTTPS
([[Local HTTPS]]).

## Gotchas

- **Motion sensors need a secure context**: a phone on plain HTTP gets no orientation.
- **READY is blocked in portrait** and cleared when landscape is lost while waiting
  ([[Pre-minigame Screen]]).
- Some Tilt Shift tests can exit `3221225477` at native shutdown on Windows with zero
  failures. Report it as a failure, separately ([[Roadmap#Known bugs]]).

## Architecture docs

[[005 Tilt Shift Design]].
