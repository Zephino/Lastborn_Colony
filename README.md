# Lastborn Colony

A turn-based colony game for Godot 4.3+. You run a colony on Brume, a moon that always shows the same face to its sun. The west edge of the map is frozen night and the east edge is scorched day. You live on the strip between them.

The colonists owe the Harrow & Vell Charter Company 6,000 marks for their passage. Payments start on turn 30 and come due every 10 turns, each one larger than the last. Pay it all off and the colony is yours. Miss three payments in a row and the Company takes over. Let everyone die and the colony goes silent.

The code is built around one plain state object, rule functions that take that state, and a single `end_turn`. The setting, buildings, economy, numbers, story and art are all original. All art is drawn in code, and there are no image or sound assets.

## Play online

**https://zephino.github.io/Lastborn_Colony/**

The web version is rebuilt and published automatically every time something is pushed to `main` (`.github/workflows/web.yml`). The game's tests run first; if any fail, the old version stays online.

- It runs in any modern browser on a computer, and on phones and tablets. On a phone the interface scales to the screen, with larger text, and menus scroll when long. The map gets the whole width:
  - **Build** opens the list of buildings. Choose one, then tap a tile; it places once.
  - **Info**, **Research** and **Company** open what the side panel shows on a computer.
  - Drag the map with one finger, pinch or use **−** and **+** to zoom. Dragging never builds.
- Saved games are kept in your browser on that device.
- **Install app** (Settings) installs it like an app in Chrome and Edge, or on Android. On iPhone or iPad: tap **Share**, then **Add to Home Screen**.
- **Updates:** for 30 seconds after the game opens, it checks for a newer version and switches to it. **Update app** (Settings) does the same at any time. Your saves are kept.

### Leaderboard, Google sign-in and cloud save

- **Leaderboard** (title screen) shows how far players got on each planet: colonies that bought out their charter come first (fewest turns wins), then everyone else by how much debt they paid off. Type your name on the title screen, then post a score when a colony ends, or choose **Menu → Retire** to post one that's still running.
- **Suggest a feature** (title screen) sends an idea or bug report to the owner. It becomes a public issue on this repository, so don't include private details. No account is needed.
- The title screen says **Signed in with Google** when you are; Settings shows which account.
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
3. **Choose a difficulty.** Easy has a smaller debt, gentler payments, fewer disasters and no plague. Hard has a bigger debt, steeper payments, more disasters and plague, faster wear and more crime. Every planet has a leaderboard for each difficulty.
4. **Pack the ship.** The hold has 10 cargo bays. Choose colonists, alloy, food, oxygen, water, starting funds, or prefab buildings (placed later for free). Everything is bought on credit, so each bay adds to the debt you must pay off. **Recommended load** is a balanced start that costs 6,000 marks.
5. **Choose a landing site.** Four sites on the same map, each with a preview and a count of the ice, vents and ore seams nearby.

### In the colony

- **The map is shown at an angle.** Buildings are sealed domes, rounded halls and towers joined by tunnels, with airlocks at their doors.
- **Build** by choosing a building on the left and clicking a tile. A new building must touch the colony. Lay **Heat Mains** (1 alloy each) to reach further out.
- **Terrain matters.** Ice Drills go on ice, Vent Taps on vents (orange), and Seam Cutters on ore seams (teal streaks). Ridges, deep ice and scorched ground can't be built on.
- **The climate band is the core trade-off.** Mirror Fields make more power the further east they are. Buildings need more heat the further west they are. Ice and vents are mostly in the west, so the best sites pull you in both directions. Selecting a tile shows its light and heat factor.
- **Each turn, every building needs its workers, power and heat.** Generators get resources first, then other buildings take them in priority order (water, then oxygen and food, housing, ore, alloy, export, civic). Anything that can't be fully supplied sits idle, marked with a red dot.
- **Keep people alive.** Each person uses 0.1 food, 0.1 oxygen and 0.05 water per turn. Shortages kill people, and oxygen shortages kill fastest.
- **Morale** sets production efficiency (50–130%). Commons and the Clinic raise it. Shortages, overcrowding and missed payments lower it. Below 20, people leave.
- **Money:** Forges turn ore into alloy, and Launch Rails sell alloy for 20 marks each. Rails never sell below your export reserve, which you set in the right panel. You can also pay the debt early from there.
- **The Deep:** a second level under the surface. Build a **Shaft** (surface, 15 alloy, 3 turns); when it's finished, a landing opens below it. Build outward from the landing. Switch levels with the **Surface/Deep** buttons (or **Q** and **E**; on phones, the Deep/Surface button).
  - Open caverns cost the normal price. Solid rock must be dug out: +4 alloy and +2 turns. Bedrock can't be built on.
  - Ore veins make Seam Cutters 50% more productive, deep vents give Vent Taps 50% more heat, and aquifers let Ice Drills work underground.
  - Buildings underground need a steady, low amount of heat (factor 0.5), which helps on cold worlds. Icequakes never reach them.
  - Mirror Fields and Launch Rails need the sky, so they stay on the surface.
- **Parts:** a **Fab Shop** machines alloy into parts. Drones, satellites and the most advanced buildings need parts as well as alloy.
- **Drones** (Drones & orbit button): a **Drone Bay** builds and runs work drones, 4 per working bay (Drone Swarms research adds 2). Drones beyond that sit idle.
  - **Grader:** adds a turn of progress to one surface building under construction.
  - **Borer:** does the same for a Shaft or a Deep building, and while you own one, digging into rock costs no extra alloy.
  - **Prospector:** brings back 2 loose ore a turn.
  - **Hauler:** two working Seam Cutters make 25% more ore.
- **Orbit** (Drones & orbit button): a working Launch Rail can launch satellites, paid in alloy, parts and marks.
  - **Weather satellite:** grit fronts hurt mirrors half as much, and icequakes reach less far.
  - **Relay satellite:** morale +3.
  - **Power satellites** (after Power Beaming research): each beams 10 power to a **Beam Catcher**.
  - **Supply pods** packed before landing stay aboard the ship; call one down any time for 50 alloy, 40 food and 40 oxygen.
- **Big power:** the **Fusion Core** (after Contained Fusion research, 40 alloy and 12 parts) makes 30 power and some heat, day or night.
- **Waste:** everyone makes waste, and some breaks down by itself. Above 40 it lowers morale, and lots of it helps plague spread. **Reclaimers** recycle it into a little ore and water.
- **Specialists:** an **Academy** trains workers into specialists, up to 30% of adults. They make Forges, Fab Shops, Seam Cutters and labs up to 15% more productive.
- **More civic buildings:**
  - **Signal Mast:** small morale boost, and 1 more mark for each alloy sold (up to 3 masts).
  - **Rescue Station:** seal failures and icequakes damage half as many buildings.
  - **Hazard Lab:** three times a Survey Lab's research, but it lowers morale and breaks down often.
  - **Garden Cavern:** Deep only. A park with a pond: a big morale boost and a little food.
  - **Lounge:** a big morale boost, but it costs 3 marks a turn and raises crime.
- **Survey probes** (cargo): the landing-site screen also shows the ore veins, aquifers and deep vents below each site.
- **Research:** Survey Labs produce research toward the topic you pick. Finished topics boost buildings, housing or exports, or reduce breakdowns, plague and crime.
- **People age:** children grow into adults, and adults grow into elders, who don't work and die sooner. A Clinic helps everyone live longer.
- **Breakdowns:** machines wear out and break down now and then. A Workshop speeds up repairs.
- **Crime** grows with population, crowding and low morale. It steals alloy and marks and lowers morale. Warden Posts hold it down.
- **Plague** can break out in a larger colony. Survey Labs must research a cure before time runs out, or about a tenth of the colony dies.
- **Factions:** the Company (Harrow & Vell) and the Crews' Union each have a relation from 0 to 100, shown in the colony summary and the report. Good Company relations soften missed-payment penalties and bring extra settlers; poor ones bring none. Good Union relations lift morale; very poor ones lead to a strike. Paying on time pleases the Company, missing a payment angers it, and shortages anger the Union.
- **Story:** story events (`data/story_events.json`) arrive as the colony grows, each once, and ask you to choose. Some depend on earlier choices or on how the factions feel. Two can end the game: **Independence** (a strong Union and a weak Company: the colony declares itself free) and **Company Town** (a pleased Company and a weak Union: you sign the colony over and the debt is cancelled). Both count on the leaderboard, ranked by debt paid.
- **Events** happen at random: grit storms, vent surges, broken seals, icequakes, stowaways, auditors and offers. Some ask you to choose.
- **Colony report** (button by End turn) shows where power, heat and workers go, how each resource changed, which buildings are idle and why, and the next payments. Selecting a building also says why it isn't running.
- **How to play** (title screen, or Menu in a game): a short illustrated guide.
- **Settings** (title screen, or Menu in a game): fullscreen, and for the web version Install app and Update app.
- **Placing a building:** a bar shows what you're placing, with **Cancel**. Dragging the map never places anything.
- **Keys:** Enter ends the turn. Arrow keys or WASD move the map. Q shows the surface and E the Deep. Esc cancels building or closes a dialog that can be closed. Drag the map to move it and use the mouse wheel to zoom. The game autosaves every 10 turns to `user://saves/autosave.json`. The Save button writes to `manual.json`.

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
| `scripts/sim/manifest.gd` | The ship's manifest: checking a load and applying it to a new game. |
| `scripts/ui/setup_flow.gd`, `scripts/ui/minimap.gd` | The screens before landing, and the small map previews. |
| `scripts/ui/colony_text.gd` | Inspector and Colony report text (pure functions, tested headless). |
| `scripts/ui/people.gd`, `scripts/ui/stat_icon.gd` | Colonists in space suits, and the resource icons in the top bar. |
| `scripts/ui/sprite_icon.gd` | A small picture of one building, for the build list, Build menu and Info panel. |
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
| `tests/` | Headless test runner, the scripted bot, and `trace.gd` (a turn-by-turn trace of a bot game). |
| `tools/` | Developer tools, not part of the game: `sprite_sheet.gd` draws the sprite sheets, `ui_shot.gd` takes screenshots of the game screens, `balance.gd` compares bot games with and without the newer content. |
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
16. Story events, then random events
17. Endings

### Rules for changing the code

- The state is a plain `Dictionary` with no objects in it, so `JSON.stringify` saves it directly.
- Every random decision must go through `rng.gd`. Never use Godot's global `randf()` in `scripts/sim/`. The title screen's random seed is the only exception.
- `state["structures"]` is processed in insertion order inside each priority band. Saves keep that order: `to_text` writes keys unsorted.

## Status and next steps

- All 447 headless test checks pass in Godot 4.3, and the Worker's 53 tests pass. Over 10 test maps per planet, the scripted player pays off the debt in about 120 turns on Brume, 114 on Cinder and 168 on Hollow. A colony that builds nothing dies out. `tools/balance.gd` replays the bot with and without the newer content (drones, satellites, Fab Shop, Academy, Signal Masts and so on) to compare. Headless tests are not playtesting: play it to judge how it feels.
- Ideas: changing trade prices, difficulty settings, and sound.

## Input safety

- Everything a player types is cleaned before it's stored, shown or sent (`scripts/sim/text_rules.gd`). Colony and player names keep only letters, numbers, spaces, `-` and `_`, with length limits. Free text (suggestions) loses control characters and invisible characters that could hide or reorder text. Text shown in rich-text panels can't open formatting tags.
- Saves loaded from the cloud are cleaned the same way.
- The online service checks everything again on its side, whatever the game sends: types, lengths, allowed characters and ranges, body size limits, and rate limits. **It uses no SQL database, so SQL injection can't happen.** Any future SQL must use bound parameters. Suggestion text is escaped before it goes into a GitHub issue. See `leaderboard-api/README.md`, "Input safety".
- Hostile input is tested on both sides: SQL-looking text, script tags, BBCode, Markdown, control and invisible characters, over-long text and wrong types.

## License

Copyright (c) 2026 Zephino. All rights reserved. See `LICENSE` and `CREDITS.md`.
