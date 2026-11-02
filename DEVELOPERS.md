# Lastborn Colony: developer guide

How the game is built, run, tested and published. For how to play, see `README.md`.

Lastborn Colony is a turn-based colony game for Godot 4.3+. The code is built around one plain state object, rule functions that take that state, and a single `end_turn`. The setting, buildings, economy, numbers, story and art are all original. All art is drawn in code, and there are no image or sound assets.

## Web version

The web version (https://zephino.github.io/Lastborn_Colony/) is rebuilt and published automatically every time something is pushed to `main` (`.github/workflows/web.yml`). The game's tests run first; if any fail, the old version stays online.

The leaderboard, Google sign-in, cloud save and Suggest a feature use the owner's Cloudflare Worker in `leaderboard-api/` (https://lastborn-colony.thebotcoder.workers.dev). Without it, or offline, the game plays normally and these buttons explain what's missing. Setup steps for the owner: `leaderboard-api/README.md`.

## One-time GitHub Pages setting (owner)

1. Open https://github.com/Zephino/Lastborn_Colony/settings/pages
2. Under **Build and deployment**, set **Source** to **GitHub Actions**. (With "Deploy from a branch", GitHub shows this README instead of the game.)
3. Open the **Actions** tab, click **Web build** on the left, then **Run workflow** → **Run workflow**. After 2–4 minutes the game is live at the link above.

If a build fails, open it in the **Actions** tab: the red step shows what went wrong (usually a failing test).

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard build; .NET is not needed).
2. In the Godot Project Manager, choose **Import**, select `project.godot` in this repository's root folder, then press **Run** (F5).

Tests run headless from the repository root:

```bash
godot --headless --script res://tests/run_tests.gd
```

The test script exits with code 0 if every check passes. It checks the random-number generator, the data files, map generation, placement rules, determinism, saving and loading, that a colony which builds nothing dies, and that the scripted bot buys out the charter on every planet and difficulty it is required to win.

## Layout

| Path | What it is |
| --- | --- |
| `data/*.json` | All numbers and text: balance, buildings, research, events, story and story events, planets, difficulty, cargo, online messages, the How to play guide. Tune the game here. |
| `scripts/sim/` | The rules. Has no scene or node dependencies, so it runs headless. |
| `scripts/sim/game_data.gd` | Loads the JSON once. Also has the climate functions `light_at` and `cold_at`. |
| `scripts/sim/rng.gd` | mulberry32 random numbers. The generator state is kept in `state["rng"]`, so saves replay exactly. |
| `scripts/sim/map_gen.gd` | Map generation from a seed. |
| `scripts/sim/new_game.gd` | Builds a fresh state `Dictionary`. |
| `scripts/sim/actions.gd` | Player actions. Each one returns `{ok, reason}`. |
| `scripts/sim/turn.gd` | `end_turn(state)`. |
| `scripts/sim/research.gd` | Research topics and their effects. |
| `scripts/sim/fleet.gd` | Drones, satellites, supply pods, waste and specialists. |
| `scripts/sim/text_rules.gd` | Cleaning rules for everything a player types. |
| `scripts/sim/tips.gd`, `data/tips.json` | First-game tips: when each shows (once per game). |
| `scripts/sim/probe.gd` | Scouting probes before landing: site reports and lucky finds (fixed by seed, planet and site). |
| `scripts/sim/manifest.gd` | The ship's manifest: checking a load and applying it to a new game. |
| `scripts/ui/setup_flow.gd`, `scripts/ui/minimap.gd`, `scripts/ui/probe_view.gd`, `scripts/ui/planet_card.gd` | The screens before landing (with probe scouting), the small map previews (fogged until scouted), the probe report picture, and the planet cards (globe, difficulty pips and stat bars, styled by each planet's "look" in `data/planets.json`). |
| `scripts/ui/colony_text.gd` | Inspector and Colony report text (pure functions, tested headless). |
| `scripts/ui/people.gd`, `scripts/ui/stat_icon.gd` | Colonists in space suits, and the resource icons in the top bar. |
| `scripts/ui/sprite_icon.gd` | A small picture of one building, for the build list, Build menu and Info panel. |
| `scripts/ui/stats_graph.gd`, `scripts/ui/records.gd` | The graphs (from `state["history"]`, one row a turn) and personal records (kept in `user://records.cfg`). |
| `scripts/ui/menus.gd` | Research, Settings, Leaderboard and cloud-save dialogs. |
| `scripts/ui/fleet_menu.gd` | The Drones & orbit dialog. |
| `scripts/sim/save_game.gd` | JSON saves to `user://saves/`. |
| `scripts/ui/main.gd` | All screens, built in code. |
| `scripts/ui/map_view.gd` | The angled (isometric) map: draws terrain and buildings back to front with the sprites, and turns clicks and taps into tiles. |
| `scripts/ui/sprites.gd`, `scripts/ui/sprites_more.gd` | Every building, tunnel, drone, satellite and ground tile, drawn in code (top-down and angled). |
| `scripts/net/` | Online features: leaderboard, Google sign-in, cloud save (`online.gd`), the Worker's address (`online_config.gd`). |
| `scripts/ui/app_actions.gd` | Fullscreen, Install app and Update app. |
| `leaderboard-api/` | The Cloudflare Worker behind the online features (not part of the game build). |
| `web/update.js`, `.github/workflows/web.yml` | The web version's self-updater, and the workflow that builds and publishes it. |
| `tests/` | Headless test runner (`run_tests.gd`, with `test_fleet.gd` and `test_new.gd` for the newer content), the scripted bot, and `trace.gd` (a turn-by-turn trace of a bot game). |
| `tools/` | Developer tools, not part of the game: `sprite_sheet.gd` draws the sprite sheets, `ui_shot.gd` takes screenshots of the game screens, `setup_shot.gd` of the screens before landing (with probes), `planet_shot.gd` of every planet's surface, `anim_shot.gd` saves frames of the map animations, `balance.gd` plays many bot games (optionally for one planet and difficulty) and prints wins and turns. |
| `.cursor/rules/`, `AGENTS.md`, `CLAUDE.md` | Rules for AI assistants working on the project. |
| `CHANGELOG.md`, `VERSION` | What changed in each version, and the current version. |

### Turn order

`end_turn` runs these steps in order:

1. Construction
2. Repairs
3. Connectivity to the Landing Pad
4. Allocation of workers, power and heat
5. Production and export
6. Research (or the plague cure)
7. Storage caps
8. Life support
9. Population: births, growing up, aging, deaths
10. Morale and defection
11. Crime
12. Breakdowns
13. Plague
14. Company payment
15. Timers
16. Story events, then random events
17. Endings

### Rules for changing the code

- The state is a plain `Dictionary` with no objects in it, so `JSON.stringify` saves it directly.
- Every random decision must go through `rng.gd`. Never use Godot's global `randf()` in `scripts/sim/`. The title screen's random seed is the only exception.
- `state["structures"]` is processed in insertion order inside each priority band. Saves keep that order: `to_text` writes keys unsorted.

## Status and next steps

- All headless test checks pass in Godot 4.3, and the Worker's tests pass. A colony that builds nothing dies out. `tools/balance.gd` replays the bot (`-- <planet> <difficulty> <games>`). With the smarter bot (v00.01.83), on Normal over 6 maps each, it wins Brume, Shale, Tessel, Cinder, Glasswater and Hollow 6/6, Ashfall 5/6 and Rimefar 1/6. On Brume it takes about 126 turns on Easy, 131 on Normal and 144 on Hard. The bot is a rough stand-in for a player: it still builds too few Seam Cutters on ore-poor sites (Tessel is slower for it than it should be). Headless tests are not playtesting: play it to judge how it feels.
- Ideas: changing trade prices, difficulty settings, and sound.

## Input safety

- Everything a player types is cleaned before it's stored, shown or sent (`scripts/sim/text_rules.gd`). Colony and player names keep only letters, numbers, spaces, `-` and `_`, with length limits. Free text (suggestions) loses control characters and invisible characters that could hide or reorder text. Text shown in rich-text panels can't open formatting tags.
- Saves loaded from the cloud are cleaned the same way.
- The online service checks everything again on its side, whatever the game sends: types, lengths, allowed characters and ranges, body size limits, and rate limits. **It uses no SQL database, so SQL injection can't happen.** Any future SQL must use bound parameters. Suggestion text is escaped before it goes into a GitHub issue. See `leaderboard-api/README.md`, "Input safety".
- Hostile input is tested on both sides: SQL-looking text, script tags, BBCode, Markdown, control and invisible characters, over-long text and wrong types.

## License

Copyright (c) 2026 Zephino. All rights reserved. See `LICENSE` and `CREDITS.md`.
