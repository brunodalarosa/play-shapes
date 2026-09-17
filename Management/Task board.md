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
        - in-progress
        - done
    cardOrders:
      note.status:
        backlog:
          - play-shapes/Management/Tasks/PS-008 - Design Fake Music Stops.md
          - play-shapes/Management/Tasks/PS-017 - Find Better Environment Assets for 001 - Dancer Simon Says.md
          - play-shapes/Management/Tasks/PS-018 - Create the 001 - Dancer Simon Says Minigame Scene.md
          - play-shapes/Management/Tasks/PS-024 - Implement Flash Pose Host Round Controller.md
          - play-shapes/Management/Tasks/PS-025 - Implement Flash Pose Phone Protocol and Controller.md
          - play-shapes/Management/Tasks/PS-026 - Implement Flash Pose Shared Screen Feedback and Results.md
          - play-shapes/Management/Tasks/PS-027 - Integrate Flash Pose Lobby and Debug Flow.md
          - play-shapes/Management/Tasks/PS-028 - Validate Flash Pose Technical Loop.md
          - play-shapes/Management/Tasks/PS-029 - Validate Flash Pose on Two Phones and in Human Play.md
        in-progress:
        done:
          - play-shapes/Management/Tasks/Done/PS-001 - Define the First Gameplay Milestone.md
          - play-shapes/Management/Tasks/Done/PS-002 - Validate Phase 1 on a Physical Phone.md
          - play-shapes/Management/Tasks/Done/PS-003 - Define Join Identity and Reconnection UX.md
          - play-shapes/Management/Tasks/Done/PS-004 - Define the Game-Feel Tuning Strategy.md
          - play-shapes/Management/Tasks/Done/PS-005 - Define Multi-Phone and Agent Validation Strategy.md
          - play-shapes/Management/Tasks/Done/PS-006 - Implement Player Join and Host-Owned Registry.md
          - play-shapes/Management/Tasks/Done/PS-007 - Define the Gameplay Debug Suite.md
          - play-shapes/Management/Tasks/Done/PS-009 - Create and Import Character Feet Assets.md
          - play-shapes/Management/Tasks/Done/PS-010 - Explore Character Animation Strategy.md
          - play-shapes/Management/Tasks/Done/PS-011 - Implement Hybrid Character Animation Lab.md
          - play-shapes/Management/Tasks/Done/PS-012 - Implement Milestone 1 Character Animation System.md
          - play-shapes/Management/Tasks/Done/PS-013 - Implement Pose Charge and Evaluation Rules.md
          - play-shapes/Management/Tasks/Done/PS-014 - Implement Minimal Gameplay Debug Launcher.md
          - play-shapes/Management/Tasks/Done/PS-015 - Implement Shared Tuning Asset and Preset Workflow.md
          - play-shapes/Management/Tasks/Done/PS-016 - Create Wireframe for 001 - Dancer Simon Says.md
          - play-shapes/Management/Tasks/Done/PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation.md
          - play-shapes/Management/Tasks/Done/PS-020 - Find Music and SFX for 001 - Dancer Simon Says.md
          - play-shapes/Management/Tasks/Done/PS-021 - Implement Curated Runtime Asset Pipeline.md
          - play-shapes/Management/Tasks/Done/PS-023 - Prepare Flash Pose Runtime Music and SFX.md
    columnColors:
      note.status:
        done: green
        in-progress: blue
  - type: kanban-view
    name: Available tasks
    filters:
      and:
        - depends_on.isEmpty() || list(depends_on).filter(value.asFile().properties.status != "done").isEmpty()
    columnOrders:
      file.file:
        - play-shapes/Management/Tasks/Done/PS-001 - Define the First Gameplay Milestone.md
        - play-shapes/Management/Tasks/Done/PS-002 - Validate Phase 1 on a Physical Phone.md
        - play-shapes/Management/Tasks/Done/PS-003 - Define Join Identity and Reconnection UX.md
        - play-shapes/Management/Tasks/Done/PS-004 - Define the Game-Feel Tuning Strategy.md
        - play-shapes/Management/Tasks/Done/PS-005 - Define Multi-Phone and Agent Validation Strategy.md
        - play-shapes/Management/Tasks/Done/PS-006 - Implement Player Join and Host-Owned Registry.md
        - play-shapes/Management/Tasks/Done/PS-007 - Define the Gameplay Debug Suite.md
        - play-shapes/Management/Tasks/Done/PS-009 - Create and Import Character Feet Assets.md
        - play-shapes/Management/Tasks/Done/PS-010 - Explore Character Animation Strategy.md
        - play-shapes/Management/Tasks/Done/PS-011 - Implement Hybrid Character Animation Lab.md
        - play-shapes/Management/Tasks/Done/PS-012 - Implement Milestone 1 Character Animation System.md
        - play-shapes/Management/Tasks/Done/PS-014 - Implement Minimal Gameplay Debug Launcher.md
        - play-shapes/Management/Tasks/Done/PS-015 - Implement Shared Tuning Asset and Preset Workflow.md
        - play-shapes/Management/Tasks/Done/PS-016 - Create Wireframe for 001 - Dancer Simon Says.md
        - play-shapes/Management/Tasks/Done/PS-020 - Find Music and SFX for 001 - Dancer Simon Says.md
        - play-shapes/Management/Tasks/Done/PS-021 - Implement Curated Runtime Asset Pipeline.md
        - play-shapes/Management/Tasks/PS-008 - Design Fake Music Stops.md
        - play-shapes/Management/Tasks/Done/PS-013 - Implement Pose Charge and Evaluation Rules.md
        - play-shapes/Management/Tasks/PS-017 - Find Better Environment Assets for 001 - Dancer Simon Says.md
        - play-shapes/Management/Tasks/PS-018 - Create the 001 - Dancer Simon Says Minigame Scene.md
        - play-shapes/Management/Tasks/Done/PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation.md
        - play-shapes/Management/Tasks/Done/PS-023 - Prepare Flash Pose Runtime Music and SFX.md
        - play-shapes/Management/Tasks/PS-024 - Implement Flash Pose Host Round Controller.md
        - play-shapes/Management/Tasks/PS-025 - Implement Flash Pose Phone Protocol and Controller.md
        - play-shapes/Management/Tasks/PS-026 - Implement Flash Pose Shared Screen Feedback and Results.md
        - play-shapes/Management/Tasks/PS-027 - Integrate Flash Pose Lobby and Debug Flow.md
        - play-shapes/Management/Tasks/PS-028 - Validate Flash Pose Technical Loop.md
        - play-shapes/Management/Tasks/PS-029 - Validate Flash Pose on Two Phones and in Human Play.md
      note.status:
        - backlog
        - in-progress
        - done
    cardOrders:
      file.file: {}
      note.status: {}
    columnColors:
      file.file: {}
      note.status: {}
    groupByProperty: note.status
    swimlaneByProperty: note.status
```
