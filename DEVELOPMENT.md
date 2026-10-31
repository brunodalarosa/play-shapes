# Play Shapes development

Where the project's documentation lives. Development knowledge is in the knowledge base, an
Obsidian vault in [KnowledgeBase/](KnowledgeBase/Home.md); open it in Obsidian or read it as
Markdown.

| Working on | Start at |
| --- | --- |
| Anything: the conventions and the map of the vault | [Home](KnowledgeBase/Home.md) |
| Where each part of the code lives | [Codebase](KnowledgeBase/Notebook/Codebase.md) |
| Boot, the host services, players and networking | [Host and Session](KnowledgeBase/Notebook/Host%20and%20Session/Host%20and%20Session.md) |
| The phone client, its build, motion input and HTTPS | [Phone Client](KnowledgeBase/Notebook/Phone%20Client/Phone%20Client.md) |
| The lobby plaza, platform movement and Cubio | [Playground Lobby](KnowledgeBase/Notebook/Playground%20Lobby/Playground%20Lobby.md) |
| A minigame, the catalog or the Ready screen | [Minigames](KnowledgeBase/Notebook/Minigames/Minigames.md) |
| Tuning presets and the workshop window | [Workshops and Tuning](KnowledgeBase/Notebook/Workshops%20and%20Tuning/Workshops%20and%20Tuning.md) |
| Art sources and runtime assets | [Art Pipeline](KnowledgeBase/Notebook/Art%20Pipeline/Art%20Pipeline.md) |
| Running, checking, formatting, branching and building | [Tooling and Verification](KnowledgeBase/Notebook/Tooling%20and%20Verification/Tooling%20and%20Verification.md) |
| What is done, what is next, known bugs | [Roadmap](KnowledgeBase/Notebook/Roadmap.md) |
| What still needs a person or a real phone | [Pending Reviews](KnowledgeBase/Notebook/Pending%20Reviews.md) |
| How systems are meant to work, and why | [Architecture](KnowledgeBase/Architecture/Architecture.md) |
| Why things are the way they are | [Decisions](KnowledgeBase/Architecture/Decisions/Decisions.md) |

[README.md](README.md) covers what to install and how to play.
[AGENTS.md](AGENTS.md) covers how to work on the project.

## Writing pages

- One topic per page, named after the topic. Page names are unique across the vault.
- Say what is true now. The reason for a choice goes in a [decision
  record](KnowledgeBase/Architecture/Decisions/Decisions.md). How a change was verified goes in
  its pull request.
- Keep paragraphs short and use lists for anything enumerated.
- State each fact in one place and link to it from the others.
- Name things for what they are, never for the ticket they came from.

`node tools/docs.mjs` checks the links, wikilinks, frontmatter, paragraph length and the ticket
rule. See [the document rules](KnowledgeBase/Notebook/Tooling%20and%20Verification/Formatting%20and%20Linting.md#document-rules).
