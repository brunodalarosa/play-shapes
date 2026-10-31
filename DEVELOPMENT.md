# Play Shapes development

The development documents, one per area. Read the one for what you are working on;
none of them needs the others first.

| Working on | Read |
| --- | --- |
| What exists today, running the project, joining from a phone | [docs/overview.md](KnowledgeBase/Architecture/Play%20Shapes%20Overview.md) |
| Player-facing screen sequences, preparation and journey changes | [docs/player-journeys.md](docs/player-journeys.md) |
| Which script or scene owns what | [docs/architecture.md](KnowledgeBase/Notebook/Codebase.md) |
| Messages between phone and host, HTTP routes, limits | [docs/protocol.md](KnowledgeBase/Architecture/Host%20and%20Session/Message%20Protocol.md) |
| Tests, the check command, evidence labels | [docs/verification.md](KnowledgeBase/Notebook/Tooling%20and%20Verification/Verification.md) |
| What still needs a person or a real phone | [docs/pending-reviews.md](KnowledgeBase/Notebook/Pending%20Reviews.md) |
| What is done, what is next, known bugs | [docs/roadmap.md](KnowledgeBase/Notebook/Roadmap.md) |
| Why things are the way they are | [docs/decisions/](KnowledgeBase/Architecture/Decisions/Decisions.md) |
| Branches, merging, releases and version numbers | [docs/branching.md](KnowledgeBase/Notebook/Tooling%20and%20Verification/Branching.md) |
| Formatting, linting and the document rules | [docs/formatting-and-linting.md](KnowledgeBase/Notebook/Tooling%20and%20Verification/Formatting%20and%20Linting.md) |
| The phone client's TypeScript and its build | [docs/browser-build.md](KnowledgeBase/Notebook/Phone%20Client/Browser%20Build.md) |
| The phone page: app install, touch, error panel | [docs/phone-client.md](KnowledgeBase/Notebook/Phone%20Client/Phone%20Web%20App.md) |
| The phone's joystick and action button, platform movement | [docs/platform-phone-controller.md](KnowledgeBase/Notebook/Playground%20Lobby/Platform%20Controller.md) |
| Motion sensors and the motion lab | [docs/motion-input.md](KnowledgeBase/Notebook/Phone%20Client/Motion%20Input.md) |
| LAN, firewall, the host's network settings | [docs/networking.md](KnowledgeBase/Notebook/Host%20and%20Session/Networking.md) |
| HTTPS for test phones | [docs/local-https.md](KnowledgeBase/Notebook/Phone%20Client/Local%20HTTPS.md) |
| The Windows package | [docs/standalone-build.md](KnowledgeBase/Notebook/Tooling%20and%20Verification/Standalone%20Build.md) |
| Tuning values | [Tuning/README.md](Tuning/README.md) |
| Tilt Shift 3D editor workshop | [the workshop guide](minigames/005_3d_tilt_shift/tuning/WORKSHOP.md) |
| Cubio art source and export | [art/cubio/README.md](art/cubio/README.md) |
| Bubbles and jellyfishes 3D art source and runtime assets | [art/bubbles_3d/README.md](art/bubbles_3d/README.md) |
| Tilt Shift 3D art source and runtime assets | [art/tilt_shift_3d/README.md](art/tilt_shift_3d/README.md) |

[README.md](README.md) covers what to install and how to play.
[AGENTS.md](AGENTS.md) covers how to work on the project.

## Writing these documents

- One topic per document, named after the topic.
- Say what is true now. The reason for a choice goes in a [decision record](KnowledgeBase/Architecture/Decisions/Decisions.md). How a change was verified goes in its pull request.
- Open with one or two sentences that say what the document covers.
- Keep paragraphs short and use lists for anything enumerated.
- State each fact in one place and link to it from the others.
- Name things for what they are, never for the ticket they came from.

`node tools/docs.mjs` checks the links, the paragraph length and the ticket rule. See
[docs/formatting-and-linting.md](KnowledgeBase/Notebook/Tooling%20and%20Verification/Formatting%20and%20Linting.md#document-rules).
