# Branching

Which branches exist, what each one holds, and how a change travels from a feature branch to
a release. The model is Git Flow; [decision 0022](decisions/0022-git-flow.md) says why.

## The branches

| Branch | Starts from | Merges into | Holds |
| --- | --- | --- | --- |
| `main` | | | Released versions only. Every new commit on it is the merge of a release or a hotfix, and carries a version tag. |
| `develop` | | | The work for the next release. Every pull request that is not a release or a hotfix targets it. |
| `feature/<name>` | `develop` | `develop` | One change: a feature, a fix, a document. |
| `release/<version>` | `develop` | `main`, then `develop` | A release being prepared. |
| `hotfix/<version>` | `main` | `main`, then `develop` | A fix to the released version that cannot wait for the next release. |

- `main` and `develop` are permanent. They are never deleted, rebased or force-pushed, and
  nothing is committed to them directly.
- The other branches are deleted once they are merged.
- No version has been released yet. Until the first release, `main` stays at the commit
  `develop` started from.

## Names

- `feature/<name>`: lower-case words joined by hyphens that name the change, such as
  `feature/minigame-catalog`. Every branch that starts from `develop` uses this prefix,
  whatever kind of change it is.
- `release/<version>` and `hotfix/<version>`: the version without the `v`, such as
  `release/0.1.0`.
- No ticket number, and no name of a tool or a person.

## Versions

- Versions follow [semantic versioning](https://semver.org): `MAJOR.MINOR.PATCH`. The first
  release is `0.1.0`.
- A release raises the minor number and a hotfix raises the patch number. The project owners
  decide when a release raises the major number instead.
- The tag is the version with a `v` in front: `v0.1.0`. It is an annotated tag on the merge
  commit on `main`.
- The tag is the only record of the version. Neither `project.godot` nor the Windows package
  carries one yet; see the [roadmap](roadmap.md#backlog).

## Merging

Every merge is a merge commit: **Create a merge commit** on GitHub, `git merge --no-ff`
locally. Squash merging and rebase merging are not used.

A pull request needs no approval from a second person to merge. It does need the output of
the check command, as [verification.md](verification.md) describes.

GitHub holds `main` and `develop` to these rules with a ruleset: a change arrives by pull
request, only a merge commit is offered, and force pushes and deletion are refused. `develop`
is the default branch, so a new pull request targets it unless the target is changed.

## A feature

```powershell
git switch develop
git pull
git switch -c feature/<name>
```

Before the pull request is opened, and again before it is merged if `develop` has moved,
rebase the branch onto `develop`:

```powershell
git fetch origin
git rebase origin/develop
git push --force-with-lease
```

- Fold a fix-up commit into the commit it corrects, with `git rebase -i origin/develop`. Each
  commit that reaches `develop` stands on its own and is not known to be broken.
- A rebase gives every commit a new hash. A commit listed in `.git-blame-ignore-revs` is
  listed with the hash it has after the last rebase; see
  [formatting-and-linting.md](formatting-and-linting.md#blame).
- The pull request targets `develop`. Delete the branch after the merge.
- A feature that builds on another unmerged feature targets that feature's branch. When the
  base has merged, rebase onto `develop` and change the target to `develop`.

## A release

```powershell
git switch develop
git pull
git switch -c release/0.1.0
git push -u origin release/0.1.0
```

From here the branch takes only fixes for this release, the version and documents. New
features keep merging into `develop` and wait for the next release.

1. Run `node tools/check.mjs --full --release` on the branch.
2. Open a pull request from the release branch into `main` and merge it.
3. Tag the merge commit:

   ```powershell
   git switch main
   git pull
   git tag -a v0.1.0 -m "Play Shapes 0.1.0"
   git push origin v0.1.0
   ```

4. Open a pull request from the release branch into `develop` and merge it, so the fixes
   made during the release reach the next one.
5. Delete the release branch.

A release branch is never rebased. A conflict with `develop` is resolved in the merge.

## A hotfix

```powershell
git switch main
git pull
git switch -c hotfix/0.1.1
```

1. Commit the fix and run `node tools/check.mjs --full --release` on the branch.
2. Open a pull request into `main`, merge it, and tag the merge commit as for a release.
3. Open a pull request from the hotfix branch into `develop` and merge it. When a release
   branch is open, target that branch instead; it carries the fix to `develop` when the
   release finishes.
4. Delete the hotfix branch.
