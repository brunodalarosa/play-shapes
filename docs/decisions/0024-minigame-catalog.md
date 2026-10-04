# 0024. The minigame catalog is an explicit list of definitions that hold paths

Decided by the project owners on 2026-10-03.

## Situation

The shared code named the one minigame in five places: the lobby's picker, three lookups in the session host for its scene, its name and its player limit, the ready screen's content map, and the debug menu's scenario list. A second minigame would have meant editing each of them.

## Decision

Each minigame has a `MinigameDefinition` resource in its folder, and `minigames/catalog.tres` lists the definitions. The session host owns the catalog, and the four places above read it.

The catalog is a list someone edits, not a scan of the `minigames/` folder. The order of the list is the order of the lobby's picker, and nothing depends on reading folders inside an exported package.

A definition holds the paths of the minigame's scene and of its ready-screen content, not the loaded resources. A loaded reference would bring every minigame's scene, art and sound into memory when the host boots.

## What follows

- Adding a minigame is a folder, a definition and one entry in the catalog.
- A path in a definition is a string. Moving the file it names does not update it; `tests/minigame_catalog_test.gd` fails when a path leads nowhere.
- `Tuning/Active Presets.tres` keeps one typed slot per minigame. It is the one place where every active preset is seen and switched, and a slot shared by all minigames would accept the wrong minigame's preset.
- The phone asset routes and the export policy's required paths still name each minigame by hand. The steps that rewrite them are on the [roadmap](../roadmap.md).
- The session host's four functions named after Bubbles are gone. A minigame calls the general ones with its own id.
