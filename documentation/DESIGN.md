# Design notes

## Architecture

- **Autoloads** (`project.godot`): `Settings`, `Loc`, `ItemDB`, `Audio`, `Net`, `GameState`,
  `Actions`, `Quests`, `SaveSystem`, `SceneFlow`.
- **Host authority.** `GameState` holds one replicated dictionary (location, train, flags,
  documents, stats) plus per-player data (health, inventory). Only the host mutates it; changes
  go out as reliable RPCs. Single-player is the same code with an offline peer.
- **Interactions.** A client asks `World.request_interact(id)`; the host checks that the
  interactable exists, is usable and is within reach of that player, then runs
  `server_interact`. Inventory, crafting, stash and keypad requests go through `Actions` the same way.
- **Flags drive everything.** Doors, containers, pickups, mechanisms and objectives are keyed by
  string flags, so a save file or a state sync restores the world from the flags.
- **Locations** are built in code (`scripts/world/locations/*.gd`, base class `Location`) from
  primitive meshes; the host bakes a navigation mesh after each load and spawns the chapter's enemies.
- **Enemies** (`scripts/enemies/`) run on the host; position, facing, state and opacity replicate.
- **Train** (`scripts/train/`): `train.gd` builds the cars and devices, `train_system.gd`
  simulates travel, wear, departure rules and the ending choice.
- **Saves** are JSON in `user://saves/`: game state, dropped items and players keyed by character.

## Adding content

- Item: add to `data/items.json` (and an icon to `tools/gen_icons.py`). Recipe: `data/recipes.json`.
- Objective: add to the chapter in `data/quests.json` with the flag that completes it.
- Document: add to `data/documents.json`; place it with `document(id, doc_id, pos)` in a location.
- Translation: add `data/lang_<code>.json` (English string -> translated string) and the code to `Loc.LANGS`.
