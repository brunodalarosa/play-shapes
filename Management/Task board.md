```base
filters:
  and:
    - file.inFolder("play-shapes/Management/Tasks")
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
    order:
      - id
      - type
      - owner
      - release
      - priority
      - depends_on
    groupByProperty: note.status
    cardTitleProperty: note.title
    columnOrders:
      note.status:
        - backlog
        - in progress
        - done
    cardOrders:
      note.status:
        backlog:
          - play-shapes/Management/Tasks/PS-003 - Define Join Identity and Reconnection UX.md
          - play-shapes/Management/Tasks/PS-004 - Define the Game-Feel Tuning Strategy.md
          - play-shapes/Management/Tasks/PS-005 - Define Multi-Phone and Agent Validation Strategy.md
          - play-shapes/Management/Tasks/PS-006 - Implement Player Join and Host-Owned Registry.md
          - play-shapes/Management/Tasks/PS-008 - Design Fake Music Stops.md
          - play-shapes/Management/Tasks/PS-011 - Implement Hybrid Character Animation Lab.md
          - play-shapes/Management/Tasks/PS-012 - Implement Milestone 1 Character Animation System.md
          - play-shapes/Management/Tasks/PS-013 - Implement Pose Charge and Evaluation Rules.md
        done:
          - play-shapes/Management/Tasks/PS-009 - Create and Import Character Feet Assets.md
        in progress:
          - play-shapes/Management/Tasks/PS-014 - Implement Minimal Gameplay Debug Launcher.md
    columnColors:
      note.status:
        done: green
        in progress: blue

```
