# 0003. The setup script checks tools; it does not install them

Decided by the project owners on 2026-10-03.

## Situation

A contributor needs Git, Godot and Node, and some tasks need more. An installer that sets up a machine is specific to one platform and changes things outside the project.

## Decision

`node tools/setup.mjs` checks the required tools and says how to install a missing one. It reports the tools only some tasks need without failing.

It installs only what belongs to the project: the `web/` dependencies, the pinned GDScript formatter in ignored `local/tools/`, and the Chromium the end-to-end test drives, in Playwright's standard per-user folder.

## What follows

- Required tools are Git, Node 22 or newer, npm and Godot 4.7.2 or newer. Export templates, mkcert, the GitHub CLI and the art tools are as-needed.
- The script is written in Node so it runs wherever the check command runs. Only Windows is in use today.
