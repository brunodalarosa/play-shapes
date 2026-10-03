# 0021. No cloud CI for now; verification is local

Decided by the project owners on 2026-10-03.

## Situation

The check command runs only when someone runs it. Cloud CI would run it on every pull request, but the project cannot take on its cost now. A git hook that runs the check before every push was considered; it would block pushing unfinished work, which is sometimes pushed to save it or to move it to another machine.

## Decision

There is no cloud CI and no hook that blocks a push. Whoever makes a change runs the check command and quotes its result in the pull request.

## What follows

- A pull request without the check's output is not verified.
- The repository is public, and hosted runners are commonly free for public repositories. If that holds for this one, cloud CI becomes a small task.
