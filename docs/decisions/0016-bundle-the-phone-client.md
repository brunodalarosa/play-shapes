# 0016. Bundle the phone client into one file

Decided by the project owners on 2026-10-03.

## Situation

The phone client is 13 modules served one by one. Each new module has to be added by hand to the host's list of routes and to the export filter, and a missed one leaves phones waiting to connect. One module holds more than half the client's code, and splitting it would add more files to register.

## Decision

The phone client is bundled into one file with esbuild, as a pinned development dependency. TypeScript's compiler stays for type checking.

## What follows

- The host serves one script, so adding a module no longer touches the route list or the export filter.
- The committed output is no longer readable file for file. It is not minified: a change still shows in a diff, and a line number in the phone's error panel can be looked up. The whole client is about 100 KB and travels over the local network, so size is no reason to minify.
- TypeScript compiles each module into an ignored folder, and esbuild bundles from there. The unit tests and the platform controller harness import those per-module files, so the tests run the files the bundle is made from, though not the bundle itself. The host tests and the end-to-end test run the bundle.
- NippleJS is no longer served as a file of its own; it is part of the bundle.
