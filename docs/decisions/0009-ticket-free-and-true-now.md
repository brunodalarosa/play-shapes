# 0009. No ticket numbers; documents say what is true now

Decided by the project owners on 2026-10-03.

## Situation

The development manual was one 43 KB file mixing reference, how-to, status and accounts of past test runs. Documents, comments and file names carried ticket numbers that nobody could look up from the repository.

## Decision

Things are named for what they are. Ticket and task numbers appear nowhere in the repository.

Each document covers one topic and states what is true now. The reason for a choice goes in a decision record. The account of how a change was verified goes in the pull request that made it.

## What follows

- The check command enforces links, paragraph length and the absence of ticket numbers.
- Reviews that still need a person are listed in one document, not repeated as caveats.
- The Squircle art source still stores names with ticket prefixes and is exempt until they are renamed in the Blender file.
