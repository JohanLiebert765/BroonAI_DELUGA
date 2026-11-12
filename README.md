# GHOST TRAIN: THE LAST ROUTE

A first-person, PS1-style survival-horror game for Windows PC, made with Godot 4 and GDScript.
Play alone or with up to four players over a local network. The game needs no internet
connection and no accounts.

You find the *Vesper*, train 13 of the Northern Vale Railway, standing under steam on a line
that was closed in 1961. It only goes one way: toward Hollowgate tunnel. Keep the locomotive
running, search five locations for fuel, parts and documents, avoid what walks there, and
decide how the last route ends.

## Contents

- Five chapters: Blackmoor Siding, Ravenwood Station, the Dead Forest, the Empty Village and
  the Last Tunnel, each with required and optional objectives.
- A drivable train with five cars: fuel, engine, electrics and running gear wear out and must be
  serviced; the boiler can overheat; the train will not leave until the chapter's main objective
  is done and everyone is aboard.
- Four playable survivors with different bonuses, inventory with stacks, shared stashes on the
  train, a workbench and a medical station for crafting.
- Four hostile entities with different rules (the Passenger, the Signal, the Hollow, the
  Conductor) and random events while travelling.
- Ten readable documents that tell the story, and three endings.
- Manual saves (three slots) and an autosave at every departure.
- Settings for audio, display, graphics quality, mouse, key bindings and interface language
  (English, Russian).

## Requirements

- Windows 10/11, 64-bit, a GPU with Vulkan support (Godot "Forward+" renderer).
- To open or build the project: [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/)
  standard edition (not .NET). Newer 4.x versions should open it as well; 4.3 is the tested one.

## Opening the project in Godot

1. Install Godot 4.3 and start it.
2. In the Project Manager choose **Import**, select `project.godot` in this folder, then **Import & Edit**.
3. Wait for the first import of textures and sounds to finish.
4. Press **F5** to run. The main scene is `scenes/main_menu/main_menu.tscn`.

## Single-player

Main menu → **New Game** → choose a survivor → **Start**. **Continue** loads the most recent
save; **Load Game** lists the autosave and the three manual slots.

## Multiplayer over a local network (1–4 players)

All players must be on the same network (the same router, switch or Wi-Fi) and run the same
version of the game.

### Creating a server (host)

1. Main menu → **Multiplayer**.
2. Enter your name and a port (default **24680**), then press **Host Game**.
3. The lobby shows the IP addresses of your PC. Tell the other players the address that
   belongs to your local network (usually `192.168.x.x` or `10.x.x.x`) and the port.
4. If Windows Firewall asks, allow the game on **private networks**. The game uses UDP on
   the chosen port.
5. Choose a survivor. When everyone has chosen, press **Start**.

The host is the authority: it runs the enemies, the train, loot and events, validates every
interaction and is the only one who can save. To continue a saved co-op game, the host loads
the save from the main menu and then hosts as usual; players who pick the same survivors get
their inventory back.

### Connecting to a server

1. Main menu → **Multiplayer**.
2. Enter your name, the host's IP address and port, then press **Join Game**.
3. Choose a free survivor (each can be taken once) and wait for the host to start.

To try it on one PC, start the game twice and join `127.0.0.1`.

If a client disconnects, their items are dropped where they stood and the game continues.
If the host closes the game, clients return to the main menu. Joining is only possible in the
lobby, not while a game is running.

### Dedicated host (optional)

A machine can host without playing; then four clients can join:

```
GhostTrain.exe --headless -- --server --port 24680
```

Any client may press **Start** on a dedicated host.

## Controls

| Action | Default |
| --- | --- |
| Move | W A S D |
| Look | Mouse |
| Sprint / crouch / jump | Shift / Ctrl / Space |
| Interact, pick up, read | E |
| Flashlight on/off | F |
| Reload flashlight (uses a battery) | R |
| Inventory | Tab |
| Pause menu, close a panel | Esc |

All keys except Esc can be rebound in **Settings → Controls**.

## How to play

- The objective is shown at the bottom left. The **route map** in the locomotive cab lists the
  chapter's objectives and what the train still needs before it can leave. Required objectives
  are marked.
- To depart: finish the required objectives, have at least 30% fuel and 30% engine condition,
  set the course on the route map, get everyone aboard and pull the **control lever**.
- While travelling, watch the instruments. Full throttle is faster but burns more fuel and
  heats the boiler; vent the **steam valve** before it reaches 100. Feed the **firebox** with
  fuel cans. Repair the **engine**, the **fuse box** and the **running gear** with parts.
- Craft at the **workbench** (workshop car) and the **medical station** (medical car). Recipes
  show what they need; tools are not consumed.
- Put spare items in the shared **cargo stash** and **medicine cabinet**.
- Noise attracts things. Sprinting, forcing doors and running generators are loud. Crouching is quiet.
- A survivor who collapses wakes up in the medical car. The **cot** there restores health
  when you are badly hurt.
- Reading the documents matters: what you know at the end changes the ending.

A complete walkthrough with spoilers is in [documentation/WALKTHROUGH.md](documentation/WALKTHROUGH.md).

## Changing settings

Main menu → **Settings**, or **Esc → Settings** in game: music, effects and ambience volume,
resolution, fullscreen, graphics quality, mouse sensitivity and inversion, key bindings,
interface language. Settings, saves and unlocked endings are stored in
`%APPDATA%\Godot\app_userdata\GHOST TRAIN THE LAST ROUTE\` (`settings.cfg`, `saves\`,
`profile.cfg`). Delete `settings.cfg` to restore the defaults.

## Building the EXE

1. In Godot: **Editor → Manage Export Templates → Download and Install** (once).
2. **Project → Export…** The preset **Windows Desktop** is already defined in
   `export_presets.cfg`; press **Export Project** and choose `build/GhostTrain.exe`.

Or from a command line:

```
godot --headless --path . --export-release "Windows Desktop" build/GhostTrain.exe
```

The preset embeds the game data in the executable, so `GhostTrain.exe` is the only file to
distribute. The `build/` folder is not tracked by git.

## Tests

The `tests/` folder has headless checks that run the real game scenes (replace `godot` with
the path to the Godot 4.3 executable):

| Command | What it covers |
| --- | --- |
| `godot --headless --path . -s tests/check_scripts.gd` | every script and scene compiles |
| `godot --headless --path . -s tests/smoke_single.gd` | lobby, pickups, stash, crafting, departure, autosave |
| `godot --headless --path . -s tests/playthrough.gd -- terminus` | all five chapters to an ending (`terminus`, `bypass` or `passengers`) |
| `godot --headless --path . -s tests/save_load.gd` | save, quit, load: location, flags, inventory, health |
| `tests/run_lan.sh /path/to/godot` | host and two clients on localhost: lobby, unique characters, host validation, disconnect, travel |

Headless runs print `mesh_get_surface_count` errors from Godot's dummy renderer; they are harmless.

## Project layout

```
assets/          generated sounds, music, textures and icons
data/            items, recipes, characters, chapters and objectives, documents, translations
documentation/   walkthrough and design notes
scenes/          menu, lobby, game, player, train, enemies, interface
scripts/         core (state, settings, audio), multiplayer, player, train, world and
                 locations, enemies, inventory, crafting, quests, save_system, ui
shaders/         PS1-style post-process
tests/           headless tests
tools/           Python generators for the assets
```

## Assets and licenses

Every sound, texture and icon in `assets/` was generated for this project by the scripts in
`tools/`; no third-party asset packs or plugins are used. Details are in
[assets/LICENSES.md](assets/LICENSES.md).
