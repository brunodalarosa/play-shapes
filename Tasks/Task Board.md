# Task Board

This embedded Obsidian Base uses the installed Kanban Bases View plugin. It reads task frontmatter directly, groups cards by `status`, and remains valid Markdown for GitHub and text editors.

```base
filters:
  and:
    - file.inFolder("play-shapes/Tasks")
    - 'id != null'
    - 'type != null'
properties:
  id:
    displayName: ID
  type:
    displayName: Type
  owner:
    displayName: Owner
  release:
    displayName: Release
  priority:
    displayName: Priority
  depends_on:
    displayName: Depends on
views:
  - type: kanban-view
    name: Task Board
    groupByProperty: note.status
    cardTitleProperty: note.title
    order:
      - note.id
      - note.type
      - note.owner
      - note.release
      - note.priority
      - note.depends_on
```

If the board does not render, confirm that Obsidian's Bases core plugin and the Kanban Bases View community plugin are enabled. [[Task Index]] is the no-plugin fallback.
