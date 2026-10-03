# 0022. Git Flow: `main` holds releases, `develop` holds the work

Decided by the project owners on 2026-10-03.

## Situation

Every change branched from `main` and merged back into it, and branch names followed three different patterns. Nothing had been released, so `main` meant the latest work. The project is about to start making releases. A release needs time to be stabilised while other work goes on, and players need one place that always holds the version they have.

The alternative was to keep the single branch and tag releases on it. It has no place to stabilise a release, and no agreed way to fix a released version once `main` has moved on.

## Decision

The project follows Git Flow as it is commonly described: `main`, `develop`, and `feature/`, `release/` and `hotfix/` branches. It is adopted before the first release, so that it is practiced by the time a release depends on it. [branching.md](../branching.md) states the rules.

## What follows

- `main` does not move until the first release. Work merges once, into `develop`; only a release or a hotfix merges twice.
- Every merge is a merge commit. It keeps a feature's commits together under one merge, and it keeps the hashes in `.git-blame-ignore-revs` valid, which a squash or a rebase merge would change.
- A feature branch is rebased onto `develop` before it merges, so each feature reads as one straight run of commits.
- One prefix, `feature/`, covers every branch from `develop`. Nobody has to sort a change into a kind before naming its branch.
- Versions are semantic and start at `0.1.0`.
- A merge needs no second person's approval for now.
- The steps are plain git commands. The `git flow` extension is not required.
