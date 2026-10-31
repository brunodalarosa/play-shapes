---
tags: [architecture]
level: system
parent: "[[Player Journeys]]"
status: draft
code: []
verified:
branch:
---

# Player journeys

Where to find the player experience requirements, and how to review changes to the sequence
of screens. These requirements apply to normal play; explicitly labeled debug flows are exceptions.

## Read the journey before changing its flow

Read the relevant design document in
[[Player Journeys|Player journeys]] before planning
a change to onboarding, the lobby, minigame preparation, gameplay or results. Those documents
describe the player's experience; the implementation plan describes how the code delivers it.

For a minigame, read both
[[Minigame Journey]] and
[[Pre-minigame Screen|Pre-minigame screen]].
Read the selected minigame's design when changing its controls or round sequence.

## Mandatory preparation

Every normal minigame launch follows the shared Pre-minigame screen, gameplay, then results.
The initial screen shows the preview, instructions and all-player READY status. Readiness
checks inside gameplay, including Tilt Shift 3D's selected-player round panels, do not replace it.

There is no player setting to skip the initial screen. Debug launch paths may bypass it.
See [[0032-mandatory-pre-minigame-screen|decision 0032]].

## Implementation-plan warning

If a plan proposes skipping the Pre-minigame screen in normal play, place this conspicuous
warning immediately before the proposed change, in bold and uppercase:

**WARNING: THIS IMPLEMENTATION PLAN SKIPS THE PRE-MINIGAME SCREEN IN A NORMAL GAME FLOW.**

Explain which launch skips it and why. The warning flags a conflict with the approved
journey; it does not authorize the bypass. Return that feature-plan change to the owner
before implementation. Existing debug exceptions do not require this warning.
