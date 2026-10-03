# 0016. Bundle the phone client into one file

Decided by the project owners on 2026-10-03.

## Situation

The phone client is 13 modules served one by one. Each new module has to be added by hand to the host's list of routes and to the export filter, and a missed one leaves phones waiting to connect. One module holds more than half the client's code, and splitting it would add more files to register.

## Decision

The phone client is bundled into one file with esbuild, as a pinned development dependency. TypeScript's compiler stays for type checking.

## What follows

- The host serves one script, so adding a module no longer touches the route list or the export filter.
- The committed output is no longer readable file for file.
