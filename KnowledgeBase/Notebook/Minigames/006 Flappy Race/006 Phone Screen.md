---
area: Minigames
tags: [system, stub]
code: []
verified:
branch:
---

# 006 Phone Screen

Hub: [[006 Flappy Race]].

After READY the phone shows the race in portrait: its own Cubio over the course, in 3D or
drawn flat without WebGL, with the hearts and refill ring at the top left, the progress bar,
and the timer at the top right. Every touch-down anywhere on it is one flap.

- The phone predicts its own flight from its own taps, so a flap shows in the next frame, and
  corrects itself from the host's settled state
  ([[0048-predicted-input-carries-a-tick|0048]]).
- A hit flies the spent heart to the respawn spot, where it waits, or shows an outline that
  fills while a heart is owed, and pulses once a tap respawns.
- The phone shows the countdown, "Finished!" and then the place, and the player's own result.
  A reconnect returns to the race; returning to the lobby hides it.
