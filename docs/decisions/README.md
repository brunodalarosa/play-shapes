# Decisions

Why the project is the way it is. Each record is one decision: the situation that called
for it, what was decided, and what follows from it. The other documents say what is true
now; these say why.

## When to write one

Write a record when a change makes a choice between real alternatives and the reason will
not be visible in the code or the documents. A fact that the documents already state, such
as a port number or a frame count, needs no record.

- One decision per file, named `NNNN-short-title.md` with the next free number.
- Say who decided and when, then give the three sections below.
- A record is not edited to change its decision. A new record replaces it and says which
  one it replaces; the old one gets a line pointing to the new one.

```markdown
# NNNN. The decision in a few words

Decided by ... on YYYY-MM-DD.

## Situation

What called for a decision, and the alternatives.

## Decision

What was decided.

## What follows

- What this commits the project to, and what it rules out.
```

## Records

| Number | Decision |
| --- | --- |
| [0001](0001-evolve-the-code.md) | Evolve the code; rewrite a part when that makes it better |
| [0002](0002-one-check-command.md) | One command defines verified |
| [0003](0003-setup-checks-tools.md) | The setup script checks tools; it does not install them |
| [0004](0004-end-to-end-test.md) | The end-to-end test drives the real game |
| [0005](0005-test-layers-and-boot.md) | End-to-end tests go through boot; quick tests do not |
| [0006](0006-formatters.md) | Formatters: the GDQuest formatter and Prettier, at 100 characters |
| [0007](0007-lint-rules-and-exceptions.md) | Lint rules and their exceptions |
| [0008](0008-bots.md) | Bots that fill a game are wanted |
| [0009](0009-ticket-free-and-true-now.md) | No ticket numbers; documents say what is true now |
| [0010](0010-no-mdns.md) | Phones find the host by IP address, not by name |
| [0011](0011-local-https-trust.md) | Local HTTPS never changes trust by itself |
| [0012](0012-no-service-worker.md) | No service worker and no cache on the phone |
| [0013](0013-shared-input-tuning.md) | Phone and host share one input tuning |
| [0014](0014-rejected-actions-are-dropped.md) | A rejected jump or fall is dropped, and a fall passes one surface |
| [0015](0015-one-folder-per-minigame.md) | One folder per minigame |
| [0016](0016-bundle-the-phone-client.md) | Bundle the phone client into one file |
| [0017](0017-one-input-message.md) | One message for gameplay input |
| [0018](0018-ui-with-containers.md) | Screens are rebuilt with containers, keeping their design |
| [0019](0019-typed-classes.md) | Typed classes inside the host; dictionaries only at the edges |
| [0020](0020-roadmap-in-the-repository.md) | The plan lives in the repository |
| [0021](0021-no-cloud-ci.md) | No cloud CI for now; verification is local |
| [0022](0022-git-flow.md) | Git Flow: `main` holds releases, `develop` holds the work |
