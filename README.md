# Lastborn Colony

A turn-based colony game for Godot 4.3+. You run a colony on Brume, a moon that always shows the same face to its sun. The west edge of the map is frozen night and the east edge is scorched day. You live on the strip between them.

The colonists owe the Harrow & Vell Charter Company 6,000 marks for their passage. Payments start on turn 30 and come due every 10 turns, each one larger than the last. Pay it all off and the colony is yours. Miss three payments in a row and the Company takes over. Let everyone die and the colony goes silent.

The code is built around one plain state object, rule functions that take that state, and a single `end_turn`. The setting, buildings, economy, numbers, story and art are all original. All art is drawn in code, and there are no image or sound assets.

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (the standard build; .NET is not needed).
2. In the Godot Project Manager, choose **Import**, select `project.godot` in this repository's root folder, then press **Run** (F5).

Tests run headless from the repository root:

```bash
godot --headless --script res://tests/run_tests.gd
```

The test script exits with code 0 if every check passes. It checks the random-number generator, the data files, map generation, placement rules, determinism, saving and loading, that a colony which builds nothing dies, and that the scripted bot buys out the charter on seeds 1–3.

## How to play

- **Build** by choosing a building on the left and clicking a tile. A new building must touch the colony. Lay **Heat Mains** (1 alloy each) to reach further out.
- **Terrain matters.** Ice Drills go on ice, Vent Taps on vents (orange), and Seam Cutters on ore seams (teal streaks). Ridges, deep ice and scorched ground can't be built on.
- **The climate band is the core trade-off.** Mirror Fields make more power the further east they are. Buildings need more heat the further west they are. Ice and vents are mostly in the west, so the best sites pull you in both directions. Selecting a tile shows its light and heat factor.
- **Each turn, every building needs its workers, power and heat.** Generators get resources first, then other buildings take them in priority order (water, then oxygen and food, housing, ore, alloy, export, civic). Anything that can't be fully supplied sits idle, marked with a red dot.
- **Keep people alive.** Each person uses 0.1 food, 0.1 oxygen and 0.05 water per turn. Shortages kill people, and oxygen shortages kill fastest.
- **Morale** sets production efficiency (50–130%). Commons and the Clinic raise it. Shortages, overcrowding and missed payments lower it. Below 20, people leave.
- **Money:** Forges turn ore into alloy, and Launch Rails sell alloy for 20 marks each. Rails never sell below your export reserve, which you set in the right panel. You can also pay the debt early from there.
- **Events** happen at random: grit storms, vent surges, broken seals, stowaways, auditors and offers. Some ask you to choose.
- **Keys:** Enter ends the turn and Esc cancels building. Right-drag pans the map and the mouse wheel zooms. The game autosaves every 10 turns to `user://saves/autosave.json`. The Save button writes to `manual.json`.

## Layout

| Path | What it is |
| --- | --- |
| `data/*.json` | All numbers and text: balance, buildings, events, story. Tune the game here. |
| `scripts/sim/` | The rules. Has no scene or node dependencies, so it runs headless. |
| `scripts/sim/game_data.gd` | Loads the JSON once. Also has the climate functions `light_at` and `cold_at`. |
| `scripts/sim/rng.gd` | mulberry32 random numbers. The generator state is kept in `state["rng"]`, so saves replay exactly. |
| `scripts/sim/map_gen.gd` | Map generation from a seed. |
| `scripts/sim/new_game.gd` | Builds a fresh state `Dictionary`. |
| `scripts/sim/actions.gd` | Player actions. Each one returns `{ok, reason}`. |
| `scripts/sim/turn.gd` | `end_turn(state)`. |
| `scripts/sim/save_game.gd` | JSON saves to `user://saves/`. |
| `scripts/ui/main.gd` | All screens, built in code. |
| `scripts/ui/map_view.gd` | Map drawing and mouse input. |
| `tests/` | Headless test runner and the scripted bot. |

### Turn order

`end_turn` runs these steps in order:

1. Construction
2. Repairs
3. Connectivity to the hull
4. Allocation of workers, power and heat
5. Production and export
6. Storage caps
7. Life support
8. Population
9. Morale and defection
10. Company payment
11. Timers
12. Random events
13. Endings

### Rules for changing the code

- The state is a plain `Dictionary` with no objects in it, so `JSON.stringify` saves it directly.
- Every random decision must go through `rng.gd`. Never use Godot's global `randf()` in `scripts/sim/`. The title screen's random seed is the only exception.
- `state["structures"]` is processed in insertion order inside each priority band. Saves keep that order: `to_text` writes keys unsorted.

## Status and next steps

- **This first version has not been run in Godot yet.** The scripts parse cleanly with `gdtoolkit`, and the economy was checked with a Python model: a scripted player clears the debt between turns 126 and 170 on 20 of 20 seeds, and a colony that builds nothing dies by about turn 50. Run the tests and play it once before building on top of it.
- Ideas: underground levels, research, a second rival faction, trade prices that change, difficulty settings, and sound.
