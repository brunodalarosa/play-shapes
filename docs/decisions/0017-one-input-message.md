# 0017. One message for gameplay input

Decided by the project owners on 2026-10-03.

## Situation

The host routes about a dozen message types by name: three for the lobby, two for the one minigame, and more for ready-up and motion. Every new minigame would add its own.

The host serves the phone client itself, so both always change together. There is no older client to stay compatible with.

## Decision

Gameplay input travels in one message that carries a sequence number, which control it came from, and that control's data. The host routes it to whichever minigame is active.

Session messages for joining, resuming, leaving and readying keep their own names. The old input message names are not kept behind adapters.

## What follows

- A new minigame adds no message type; it uses a control and handles that control's data.
- The change is a new protocol version, made when the input pipeline is reworked.
