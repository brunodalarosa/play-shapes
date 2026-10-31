---
area: Minigames
tags: [system, stub]
code: []
verified:
branch:
---

# 004 Messages

Hub: [[004 Bubbles and Jellyfishes]].

The messages of minigame 004. The shared rules are in the message protocol.

Minigame 004 uses messages with a `bubbles_3d` prefix and has no spin or charge. Every client
WebSocket packet is bounded to 8192 bytes. The phone sends:

- `bubbles_3d_touch` with `input_seq` and `stage`: `start` on touch down, `drag` with a coarse
  `drag` of two integers from -4 to 4 in screen axes, and `cancel` when a touch is interrupted.
  The phone throttles drags to 70 ms, re-sends the current one every 600 ms while held and caps
  a touch at 48 drags.
- `bubbles_3d_release` with the same `input_seq` and `displacement`, the net movement as two
  numbers from -1 to 1, a share of the touch area in screen axes.

The host side:

- The host times a touch from its own receipt of `start`. A release later than
  `swipe_max_hold_seconds` applies nothing, and the live stretch settles at that limit.
- A release shorter than `swipe_min_distance` applies nothing. Otherwise one fixed-strength
  push follows its direction; distance and speed add no strength.
- Drags at least 60 ms apart, at most 48 per touch, drive only the shared-screen stretch, which
  settles after 1.2 seconds without one.
- The host answers a release with `bubbles_3d_release_result` (`action` and `reason`) and a
  `bubbles_3d_snapshot`. `bubbles_3d_feedback` adds `event` (`captured` or `pop`) and, for a
  pop, `lost`.
- `bubbles_3d_visual` carries the drawn radius, shell stretch, speed share, invulnerability, time
  since the last pop and the drawn catch, at up to 20 Hz, dropped while a connection is backed up.
- Reconnect embeds the latest snapshot in `welcome.gameplay`.
