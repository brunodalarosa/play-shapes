---
area: Minigames
tags: [system, stub]
code: []
verified:
branch:
---

# 005 Phone Screen

Hub: [[005 Tilt Shift]].

Preparation exposes Enable tilt, Set neutral and the host-confirmed READY/CANCEL action.
Landscape orientation, current usable input and completed calibration are required by the
host. A browser without a permission enum may still provide valid samples; denial or absent
samples block READY.

Every normal launch first shows the shared Pre-minigame screen with READY for every player.
The selected-player panel inside gameplay has its own READY when open. Skipping that
round panel does not skip initial preparation. Calibration remains available
before active play and between rounds, and clears an existing READY.

Preparation explains landscape holding and unlocking rotation if needed. Portrait blocks READY
on both phone and host, and rotating back while waiting clears READY. CANCEL remains available.
Active play retains responsive portrait rendering and optional orientation lock.

The view shows the player's own paddle in real-time 3D over the cream
wall gradient: their colour, the gap ring, their team outline once teams exist, and the face
the host chooses. It turns with the host's physical angle and blinks on the phone. There are no
touch gameplay controls or score HUD.

Spectators see their paddle resting level, smaller, over the team-coloured waiting background.
Mapped-round reconnect clears READY and retains neutral. Gameplay reconnect retains neutral and
shows only a temporary permission action if capture needs reacquisition.
Results, cancel and lobby return retire capture and hide the screen. Returning from a cached
page reconnects through the authenticated subscription before capture can resume. The 3D view
draws only when the paddle turns, its face changes or it blinks.

A phone without WebGL, or one whose 3D view fails to load twice, draws the same paddle and face
flat on a 2D canvas. Phones wait a random moment of up to 1.5 seconds before their first
download, and load face parts one at a time, so a room of phones does not overwhelm the host.
