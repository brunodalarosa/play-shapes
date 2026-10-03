# 0013. Phone and host share one input tuning

Recorded on 2026-10-03 from the project's documents, where it was already in force. The reasons are as those documents gave them; whoever made the decision should correct them if they differ.

## Situation

The phone classifies the joystick into stances with a dead zone and angle thresholds, and the host checks the same input. Two copies of those numbers would drift apart, and the host would start rejecting what the phone sends.

## Decision

The numbers live once, in the phone client's defaults. The build generates a settings file from them, and the host reads that file.

## What follows

- Tuning the input means editing the defaults, rebuilding and restarting the host.
- The generated file is never edited, and the host's thresholds are never tuned separately.
- The phone's stance is only a hint. The host decides grounding and presentation.
