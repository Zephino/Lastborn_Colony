# Lastborn Colony

A turn-based colony game for Godot 4.3+. You run a colony on Brume, a moon that always shows the same face to its sun. The west edge of the map is frozen night and the east edge is scorched day. You live on the strip between them.

The colonists owe the Harrow & Vell Charter Company 6,000 marks for their passage. Payments start on turn 30 and come due every 10 turns, each one larger than the last. Pay it all off and the colony is yours. Miss three payments in a row and the Company takes over. Let everyone die and the colony goes silent.

The code is built around one plain state object, rule functions that take that state, and a single `end_turn`. The setting, buildings, economy, numbers, story and art are all original. All art is drawn in code, and there are no image or sound assets.

## Play online

**https://zephino.github.io/Lastborn_Colony/**

The web version is rebuilt and published automatically every time something is pushed to `main` (`.github/workflows/web.yml`). The game's tests run first; if any fail, the old version stays online.

- It runs in any modern browser on a computer, and on phones and tablets (a mouse or touch screen is needed for the map).
- Saved games are kept in your browser on that device.
- **Install app** (Settings) installs it like an app in Chrome and Edge, or on Android. On iPhone or iPad: tap **Share**, then **Add to Home Screen**.
- **Updates:** for 30 seconds after the game opens, it checks for a newer version and switches to it. **Update app** (Settings) does the same at any time. Your saves are kept.

### Leaderboard, Google sign-in and cloud save

- **Leaderboard** (title screen) shows how far players got on each planet: colonies that bought out their charter come first (fewest turns wins), then everyone else by how much debt they paid off. Type your name on the title screen, then post a score when a colony ends, or choose **Menu → Retire** to post one that's still running.
- **Sign in with Google** (Settings) is optional. It lets you keep one cloud save and carry on from another device: **Save this game to the cloud** on one device, then **Load my game from the cloud** on the other.
- These features use the owner's Cloudflare Worker in `leaderboard-api/` (https://lastborn-colony.thebotcoder.workers.dev). Without it, or offline, the game plays normally and these buttons explain what's missing. Setup steps for the owner: `leaderboard-api/README.md`.

### One-time GitHub Pages setting (owner)

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

The test script exits with code 0 if every check passes. It checks the random-number generator, the data files, map generation, placement rules, determinism, saving and loading, that a colony which builds nothing dies, and that the scripted bot buys out the charter on seeds 1–3.

## How to play

### Before landing

1. **Briefing:** the story so far.
2. **Choose a planet.** Brume (Standard) has ice, vents and sunlight all within reach. Cinder (Harder) is bright and hot, but ice is rare. Hollow (Hardest) is icy and full of vents, but the sun is weak. Each planet has its own leaderboard.
3. **Pack the ship.** The hold has 10 cargo bays. Choose colonists, alloy, food, oxygen, water, starting funds, or prefab buildings (placed later for free). Everything is bought on credit, so each bay adds to the debt you must pay off. **Recommended load** is a balanced start that costs 6,000 marks.
4. **Choose a landing site.** Four sites on the same map, each with a preview and a count of the ice, vents and ore seams nearby.

### In the colony

- **Build** by choosing a building on the left and clicking a tile. A new building must touch the colony. Lay **Heat Mains** (1 alloy each) to reach further out.
- **Terrain matters.** Ice Drills go on ice, Vent Taps on vents (orange), and Seam Cutters on ore seams (teal streaks). Ridges, deep ice and scorched ground can't be built on.
- **The climate band is the core trade-off.** Mirror Fields make more power the further east they are. Buildings need more heat the further west they are. Ice and vents are mostly in the west, so the best sites pull you in both directions. Selecting a tile shows its light and heat factor.
- **Each turn, every building needs its workers, power and heat.** Generators get resources first, then other buildings take them in priority order (water, then oxygen and food, housing, ore, alloy, export, civic). Anything that can't be fully supplied sits idle, marked with a red dot.
- **Keep people alive.** Each person uses 0.1 food, 0.1 oxygen and 0.05 water per turn. Shortages kill people, and oxygen shortages kill fastest.
- **Morale** sets production efficiency (50–130%). Commons and the Clinic raise it. Shortages, overcrowding and missed payments lower it. Below 20, people leave.
- **Money:** Forges turn ore into alloy, and Launch Rails sell alloy for 20 marks each. Rails never sell below your export reserve, which you set in the right panel. You can also pay the debt early from there.
- **Research:** Survey Labs produce research toward the topic you pick. Finished topics boost buildings, housing or exports, or reduce breakdowns, plague and crime.
- **People age:** children grow into adults, and adults grow into elders, who don't work and die sooner. A Clinic helps everyone live longer.
- **Breakdowns:** machines wear out and break down now and then. A Workshop speeds up repairs.
- **Crime** grows with population, crowding and low morale. It steals alloy and marks and lowers morale. Warden Posts hold it down.
- **Plague** can break out in a larger colony. Survey Labs must research a cure before time runs out, or about a tenth of the colony dies.
- **Events** happen at random: grit storms, vent surges, broken seals, icequakes, stowaways, auditors and offers. Some ask you to choose.
- **Colony report** (button by End turn) shows where power, heat and workers go, how each resource changed, which buildings are idle and why, and the next payments. Selecting a building also says why it isn't running.
- **Settings** (title screen, or Menu in a game): fullscreen, and for the web version Install app and Update app.
- **Keys:** Enter ends the turn. Esc cancels building or closes a dialog that can be closed. Right-drag pans the map and the mouse wheel zooms. The game autosaves every 10 turns to `user://saves/autosave.json`. The Save button writes to `manual.json`.

## Layout

| Path | What it is |
| --- | --- |
| `data/*.json` | All numbers and text: balance, buildings, research, events, story, planets, cargo, online messages. Tune the game here. |
| `scripts/sim/` | The rules. Has no scene or node dependencies, so it runs headless. |
| `scripts/sim/game_data.gd` | Loads the JSON once. Also has the climate functions `light_at` and `cold_at`. |
| `scripts/sim/rng.gd` | mulberry32 random numbers. The generator state is kept in `state["rng"]`, so saves replay exactly. |
| `scripts/sim/map_gen.gd` | Map generation from a seed. |
| `scripts/sim/new_game.gd` | Builds a fresh state `Dictionary`. |
| `scripts/sim/actions.gd` | Player actions. Each one returns `{ok, reason}`. |
| `scripts/sim/turn.gd` | `end_turn(state)`. |
| `scripts/sim/research.gd` | Research topics and their effects. |
| `scripts/sim/manifest.gd` | The ship's manifest: checking a load and applying it to a new game. |
| `scripts/ui/setup_flow.gd`, `scripts/ui/minimap.gd` | The screens before landing, and the small map previews. |
| `scripts/ui/colony_text.gd` | Inspector and Colony report text (pure functions, tested headless). |
| `scripts/ui/menus.gd` | Research, Settings, Leaderboard and cloud-save dialogs. |
| `scripts/sim/save_game.gd` | JSON saves to `user://saves/`. |
| `scripts/ui/main.gd` | All screens, built in code. |
| `scripts/ui/map_view.gd` | Map drawing and mouse input. |
| `scripts/net/` | Online features: leaderboard, Google sign-in, cloud save (`online.gd`), the Worker's address (`online_config.gd`). |
| `scripts/ui/app_actions.gd` | Fullscreen, Install app and Update app. |
| `leaderboard-api/` | The Cloudflare Worker behind the online features (not part of the game build). |
| `web/update.js`, `.github/workflows/web.yml` | The web version's self-updater, and the workflow that builds and publishes it. |
| `tests/` | Headless test runner, the scripted bot, and `trace.gd` (a turn-by-turn trace of a bot game). |
| `.cursor/rules/`, `AGENTS.md`, `CLAUDE.md` | Rules for AI assistants working on the project. |
| `CHANGELOG.md`, `VERSION` | What changed in each version, and the current version. |

### Turn order

`end_turn` runs these steps in order:

1. Construction
2. Repairs
3. Connectivity to the hull
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
16. Random events
17. Endings

### Rules for changing the code

- The state is a plain `Dictionary` with no objects in it, so `JSON.stringify` saves it directly.
- Every random decision must go through `rng.gd`. Never use Godot's global `randf()` in `scripts/sim/`. The title screen's random seed is the only exception.
- `state["structures"]` is processed in insertion order inside each priority band. Saves keep that order: `to_text` writes keys unsorted.

## Status and next steps

- All 200 headless test checks pass in Godot 4.3, and the Worker's 29 tests pass. Over 10 test maps per planet, the scripted player pays off the debt in about 101 turns on Brume, 116 on Cinder and 137 on Hollow (one loss on Hollow). The scripted player pays off the debt on 16 of 16 test maps, between turns 83 and 120, and a colony that builds nothing dies out. Headless tests are not playtesting: play it to judge how it feels.
- Ideas: underground levels, a rival faction, changing trade prices, difficulty settings, and sound.

## License

Copyright (c) 2026 Zephino. All rights reserved. See `LICENSE` and `CREDITS.md`.
