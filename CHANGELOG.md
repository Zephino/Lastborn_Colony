# Changelog

One entry per change request, newest first (see `.cursor/rules/changelog.mdc`). The version here always matches `VERSION`. The game started inside the `Zephino/ColdLedger` repository (as "Thaw Line", then "Last Colony", then "Lastborn Colony", ColdLedger versions 00.01.05–00.01.07) and moved here at version 00.01.00.

## Version 00.01.03
Date: 11/01/2026
Time: 1:35 AM

### Changes
- **AI rules brought over from Mythriven** and adapted to this project, in `.cursor/rules/`:
  - Kept and adapted: `changelog.mdc`, `version.mdc`, `bug-investigation.mdc`, `dependencies.mdc`, `documentation.mdc`, `git-workflow.mdc` (push straight to `main`), `testing.mdc`, `think-before-acting.mdc`, `accessibility-for-interfaces.mdc`.
  - `mythriven.mdc` became `lastborn.mdc`: this game's standing rules (original content only, numbers in data, deterministic simulation, exact saves, secrets only in Cloudflare).
  - References to files this project doesn't have (`GAME_DESIGN.md`, `docs/BUILD_PLAN.md`, `docs/PROGRESS.md`, the debug menu, `tr()`, object pooling) were replaced with this project's equivalents (`README.md`, this changelog, `tests/trace.gd`).
- Added `AGENTS.md` (shared rules for Cursor and Claude, including the rule that Claude must read every `.cursor/rules/` file) and `CLAUDE.md` (Claude works in developer mode here; ColdLedger and Mythriven are reference projects).
- Added `LICENSE` (copyright Zephino, all rights reserved; same terms as Mythriven) and `CREDITS.md` (Godot Engine, MIT).
- Added the `VERSION` file and this changelog, backfilled below. `project.godot` now carries the same version, and the title screen shows it in the bottom-right corner.

### Reason
The owner asked to pull the AI rules and the copyright from Mythriven, and for a full changelog of everything done so far.

## Version 00.01.02
Date: 11/01/2026
Time: 1:33 AM

### Changes
- **New game systems**, designed for this game (ideas from Cold Ledger, with this game's own buildings, names and numbers):
  - **Life stages:** adults age into elders, who don't work and die faster. The Clinic and Field Medicine help.
  - **Research:** new **Survey Lab** building and `data/research.json` with 13 topics (for example Insulated Mains, Mirror Coatings, Hot Smelting, Magnetic Rails). Finished topics boost buildings, housing, exports, morale, or reduce breakdowns, plague and crime.
  - **Breakdowns:** machines wear out and break down at random. New **Workshop** building speeds up repairs.
  - **Crime:** grows with population, overcrowding and low morale; steals alloy and marks and lowers morale. New **Warden Post** building holds it down.
  - **Icequake** event: damages buildings in an area.
  - **Plague:** an outbreak that Survey Labs must research a cure for in time (longer with a Clinic); otherwise about a tenth of the colony dies.
- The turn now has 17 steps (see `README.md`).
- 28 new test checks (73 in total). The test bot now also builds labs, workshops and warden posts and chooses research; it wins on 16 of 16 test maps, between turns 83 and 120.

### Reason
The owner asked to bring over the game rules from Cold Ledger that fit this game.

## Version 00.01.01
Date: 11/01/2026
Time: 1:29 AM

### Changes
- **The game now runs in Godot 4.3** (it had never been run before). Fixed an undefined variable in `scripts/sim/actions.gd` that stopped every script from loading.
- **Saves reload exactly.** Godot writes decimals to JSON with 15 digits, so a loaded game slowly drifted from the original. Stored values are now rounded to 6 decimal places at the end of each turn.
- **No more soft-lock.** A colony that spent all its alloy before building a Forge could never recover. The Landing Hull now salvages 1 alloy a turn.
- Balance: Seam Cutters make 6 ore (was 5); Forges turn 4 ore into 4 alloy (was 3); each Company payment grows by 20 marks (was 40).
- Test bot fixes: it tries its wanted buildings in order, builds ore and a Forge before a Launch Rail, saves alloy for payments, and adds power when buildings sit idle.
- Added `tests/trace.gd` (prints a turn-by-turn trace of a bot game) and a Web export preset (`export_presets.cfg`).
- All 45 test checks pass.

### Reason
The owner asked to get the game running first.

## Version 00.01.00
Date: 11/01/2026
Time: 1:18 AM

### Changes
- First version of Lastborn Colony in this repository: an original turn-based colony game for Godot 4.3, set on the thaw line of a tidally locked moon, with a debt to pay off to the charter company.
- Game data in `data/*.json`; rules in `scripts/sim/` (seeded random numbers, map generation, actions, turn processing, JSON saves); interface built in code in `scripts/ui/`, with the map drawn procedurally; headless tests and a scripted test player in `tests/`.

### Reason
The owner asked to move the game into its own repository, `Zephino/Lastborn_Colony`.
