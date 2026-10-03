# Play Shapes development

The development documents, one per area. Read the one for what you are working on;
none of them needs the others first.

| Working on | Read |
| --- | --- |
| What exists today, running the project, joining from a phone | [docs/overview.md](docs/overview.md) |
| Which script or scene owns what | [docs/architecture.md](docs/architecture.md) |
| Messages between phone and host, HTTP routes, limits | [docs/protocol.md](docs/protocol.md) |
| Tests, the check command, evidence labels | [docs/verification.md](docs/verification.md) |
| What still needs a person or a real phone | [docs/pending-reviews.md](docs/pending-reviews.md) |
| What is done, what is next, known bugs | [docs/roadmap.md](docs/roadmap.md) |
| Why things are the way they are | [docs/decisions/](docs/decisions/README.md) |
| Formatting, linting and the document rules | [docs/formatting-and-linting.md](docs/formatting-and-linting.md) |
| The phone client's TypeScript and its build | [docs/browser-build.md](docs/browser-build.md) |
| The phone page: app install, touch, error panel | [docs/phone-client.md](docs/phone-client.md) |
| The phone's joystick and action button, platform movement | [docs/platform-phone-controller.md](docs/platform-phone-controller.md) |
| Motion sensors and the motion lab | [docs/motion-input.md](docs/motion-input.md) |
| LAN, firewall, the host's network settings | [docs/networking.md](docs/networking.md) |
| HTTPS for test phones | [docs/local-https.md](docs/local-https.md) |
| The Windows package | [docs/standalone-build.md](docs/standalone-build.md) |
| Tuning values | [Tuning/README.md](Tuning/README.md) |
| Squircle art source and export | [art/squircle/README.md](art/squircle/README.md) |
| Bubbles art source and runtime assets | [art/bubbles/README.md](art/bubbles/README.md), [the asset guide](assets/runtime/minigames/bubbles_and_jellyfishes/README.md) |

[README.md](README.md) covers what to install and how to play.
[AGENTS.md](AGENTS.md) covers how to work on the project.

## Writing these documents

- One topic per document, named after the topic.
- Say what is true now. The reason for a choice goes in a [decision record](docs/decisions/README.md). How a change was verified goes in its pull request.
- Open with one or two sentences that say what the document covers.
- Keep paragraphs short and use lists for anything enumerated.
- State each fact in one place and link to it from the others.
- Name things for what they are, never for the ticket they came from.

`node tools/docs.mjs` checks the links, the paragraph length and the ticket rule. See
[docs/formatting-and-linting.md](docs/formatting-and-linting.md#document-rules).
