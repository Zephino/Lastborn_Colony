# Changelog

One entry per change request, newest first (see `.cursor/rules/changelog.mdc`). The version here always matches `VERSION`. The game started inside the `Zephino/ColdLedger` repository (as "Thaw Line", then "Last Colony", then "Lastborn Colony", ColdLedger versions 00.01.05–00.01.07) and moved here at version 00.01.00.

## Version 00.01.09
Date: 11/01/2026
Time: 8:08 AM

### Changes
- **The game screen on phones** (screens narrower than 760 points):
  - The map takes the whole width and starts centered on the hull, with bigger tiles.
  - A new **Build** button opens the buildings as a dialog with large buttons, prices and descriptions. Choosing one starts placing it, and the next tap places it **once**, then placing ends, so a stray tap can't build again.
  - New **−** and **+** zoom buttons, and two-finger pinch to zoom and move the map. A second finger cancels the first finger's tap, so pinching never selects or builds.
  - Less urgent numbers (power, heat, workers, ore, next payment) move to the Report, so the top bar is shorter.
  - Text is larger on phones (17 instead of 15), and all buttons are at least 44 points tall.
- **Moving the map never builds**, on any screen. A press that moves more than a few points is a drag, not a tap. A new **placing bar** shows what you're placing, with a **Cancel** button. On a computer, the arrow keys or WASD also move the map.
- **Readable dialog buttons:** buttons with long text are now sized to fit it. Before, on a phone, the lines overlapped the next button, for example in the Build list and the research topics. This applies to every dialog and the setup pages (new `scripts/ui/ui_util.gd`).
- Fixed: on phones the short message bubble measured itself one word wide and covered most of the screen.
- Tests: 279 game checks pass. Played in a phone-sized browser here (390×844, touch): the Build dialog, choosing a Mirror Field, dragging the map with nothing built, tapping to place it once, and the message bubble. The desktop layout was also rechecked.

### Reason
The owner asked to make all the menus easier to use on a phone, said the game was hard to see and scroll, and asked for a way to scroll without placing anything.

## Version 00.01.08
Date: 11/01/2026
Time: 7:59 AM

### Changes
- **Difficulty levels.** A new page after the planet choice lets you pick Easy, Normal or Hard (`data/difficulty.json`). Normal is the game as before.
  - **Easy:** 25% smaller debt, payments grow half as fast, 40% fewer random events, no plague, half the wear, 30% less crime, morale +5.
  - **Hard:** 25% bigger debt, payments grow 50% faster, 50% more random events, twice the plague chance, 50% more wear, 30% more crime, morale −5.
  - The manifest page shows prices and the starting debt at the chosen difficulty. The colony summary shows the planet and difficulty, and the report's payment schedule follows the difficulty.
- **Leaderboards per planet and difficulty.** Scores carry their difficulty, and the Leaderboard screen switches between planets and difficulties. On the server, Normal boards keep their old place (so existing scores stay where they are), Easy and Hard get their own, and scores from older game versions count as Normal. A planet id can no longer contain `_`, so it can't pose as another board.
- Older saves load as Normal.
- **Tests:** 278 game checks (9 new) and 54 server tests pass. The scripted player wins all 3 test games on Easy (81–115 turns) and on Hard (121–136 turns). The difficulty page and Hard's 7,500-mark debt were checked in a browser here.

### Reason
The owner chose difficulty levels as the first of three next features (then story and factions, then underground levels).

## Version 00.01.07
Date: 11/01/2026
Time: 2:24 AM

### Changes
- **Readable on phones.** The interface now scales by the device's pixel density; before, a phone drew everything at a third of the size. On a phone:
  - **Title, setup and dialogs:** the title screen and setup pages fit the screen, and long dialogs scroll.
  - **Manifest and landing sites:** each price moves under its item, and the sites stack in one column.
  - **Buttons:** touch-sized (44 points).
- **Phone layout for the game screen** (narrow screens only):
  - **Build list:** narrower.
  - **Side panel:** hidden, with its contents opening from new **Info**, **Research** and **Company** buttons. Tapping a tile opens its details.
  - **Buttons:** they wrap so all of them are reachable.
  - **Map:** drag it with one finger, or with the mouse on a computer (a click without moving still selects).
- **Title screen:**
  - **Suggest a feature:** a form with category, title and details, sent to the owner as a GitHub issue through the online service.
  - **Quit**, now in the browser too: it closes the tab where the browser allows it, otherwise it says the tab can be closed.
  - **Signed in with Google**, shown when signed in. No name is shown; Settings has that.
- **Input safety (game):** new `scripts/sim/text_rules.gd` cleans everything a player types.
  - **Names:** colony and player names keep letters, numbers, spaces, `-` and `_`, up to 24 and 16 characters.
  - **Free text:** control characters and invisible text-reordering characters are removed.
  - **Rich-text panels:** the log and the colony summary can't be made to open formatting tags.
  - **Saves:** a save loaded from a file or the cloud has its colony name and planet checked.
- **Input safety (online service):**
  - **Suggestions:** a new endpoint (`/suggestions`) with a category allowlist, length and size limits, a spam trap, and limits of 3 a day per address and 40 a day overall. Suggestion text is escaped so it can't add formatting, links, HTML, @mentions or issue references to the GitHub issue.
  - **No SQL:** the service uses no SQL database, so SQL injection isn't possible. This is now stated in its README, with a rule that any future SQL must use bound parameters.
  - **Audit fixes:** the leaderboard accepted numbers sent as text and lists as names; sending `null` to sign-in crashed the service; body size limits counted characters instead of bytes; and two inputs had no length cap. All four are fixed.
  - **Hostile-input tests:** every route was tested with SQL-looking text, script tags, BBCode, Markdown, control and invisible characters, over-long text, wrong types, huge bodies and broken JSON. All are refused or made harmless.
- **Tests:** 269 game checks pass (50 new, including hostile names and tampered saves) and 53 online-service tests (24 new).
- **Played in a phone-sized browser here** (390×844 points, touch): the title, Suggest a feature, Settings, the whole setup, the game screen, dragging the map, and tapping a tile.
- **Owner setup for suggestions** (in `leaderboard-api/README.md`): a fine-grained GitHub token for this repository with **Issues: read and write**, stored in Cloudflare as the `GITHUB_TOKEN` secret.
- **Exception to `lastborn.mdc`:** `scripts/net/online.gd` is now about 600 lines, over the ~400 aim.

### Reason
The owner asked for menus readable on a phone, Suggest a feature and Quit buttons on the main screen, a signed-in indicator on the main screen, and for all user input to be sanitized and protected against SQL injection.

## Version 00.01.06
Date: 11/01/2026
Time: 2:06 AM

### Changes
- **Idle buildings explain themselves.** Each turn records why a building didn't run (not enough free workers, power or heat) and which input a running building was out of. Selecting the building says what's wrong and how to fix it. The colony summary points out idle buildings.
- **Colony report** (new button by End turn): power, heat and workers in use; each resource's stock and change last turn; people, housing, births, deaths, morale and crime; any shortages; which buildings are idle or starved and why; research progress; and the next three Company payments.
- Inspector numbers now include research bonuses (heat needed, output, housing, exports).
- **Code tidy-up:** inspector and report text moved to `scripts/ui/colony_text.gd`, and the Research, Settings, Leaderboard and cloud-save dialogs moved to `scripts/ui/menus.gd`. `main.gd` went from about 880 to 640 lines (still above the ~400 aim; noted as an exception).
- **Tests:** 200 checks pass (30 new). A new check loads every game script, because two interface scripts had errors that no test touched; Godot's own check caught them before this push. New checks also cover idle reasons and the report text.
- Played in a browser here: the whole setup with the keyboard only (Enter through every page), the game, the Colony report, the Menu, Settings and Research.

### Reason
The owner asked to continue with the interface improvements (step 3). This continues the same request as 00.01.05; it gets its own version so the web version's updater picks it up.

## Version 00.01.05
Date: 11/01/2026
Time: 2:00 AM

### Changes
- **New start: choose what goes on the ship.** "New colony" now leads through four screens before landing (`scripts/ui/setup_flow.gd`):
  1. **Briefing.**
  2. **Planet choice:** three original worlds in `data/planets.json`. **Brume** (Standard) is the original map. **Cinder** (Harder) is hot and bright, with rare ice and frequent grit storms. **Hollow** (Hardest) is icy, has many vents and a weak sun, and gets more icequakes. Each planet sets the sunlight, the heat buildings need, how much ice, rock, ore and vents its maps have, and how often its events happen.
  3. **Pack the ship:** a 10-bay hold (`data/cargo.json`). Cargo is colonists, alloy, food, oxygen, water, starting funds, or prefab buildings (Mirror Field, Vent Tap, Splitter, Kelp Vat, Forge, Survey Lab) that are placed later without spending alloy. Every bay is bought on credit and adds to the starting debt. The **Recommended load** gives exactly the old start (22 adults, 8 children, 150 food and oxygen, 100 water, 80 alloy, 6,000 marks of debt).
  4. **Landing site:** four sites on the chosen planet's map, each with a small map preview (`scripts/ui/minimap.gd`) and a count of the ice, vents and ore seams nearby.
- Game rules: `scripts/sim/manifest.gd` checks and applies a manifest. The map generator and the climate now depend on the planet. New games remember their planet, site, manifest, prefab kits and starting debt. Brume with the recommended load plays exactly as before.
- The leaderboard has a board per planet, with buttons to switch between them. Scores already carried the planet.
- Older saves still load: missing fields get their old meaning (Brume, no kits, and so on).
- Planet difficulty labels were set from test runs of the scripted player on 10 maps each: about 101 turns to pay off the debt on Brume, 116 on Cinder and 137 on Hollow (one loss in 13 games on Hollow).
- **Tests:** 170 checks pass (33 new), covering the manifest limits, prefab kits, planets and landing sites, older saves, and the bot on Cinder and Hollow. A script error inside a test used to stop that test quietly; the web build now fails if Godot reports a script error during the tests. `tests/trace.gd` takes a planet. The whole flow was also played in a browser here: planet, manifest with prefab Vent Taps, landing site, and the game.

### Reason
The owner pointed out that Cold Ledger let the player choose what goes on the spaceship, and asked to continue. This is Lastborn Colony's own version of that idea, tied to its debt to the Company.

## Version 00.01.04
Date: 11/01/2026
Time: 1:48 AM

### Changes
- **Play online:** the web version is built and published to GitHub Pages (https://zephino.github.io/Lastborn_Colony/) on every push to `main` (`.github/workflows/web.yml`). The game's tests and the Worker's tests run first, and a failing test stops the publish. The deploy waits for GitHub's own Pages publish so the README can't replace the game, then checks the site shows the right version.
- **Settings** (title screen and in-game Menu): Fullscreen; for the web version **Install app** (installs it like an app) and **Update app** (reloads the newest version; saves are kept). The page also switches to a newer version by itself in the first 30 seconds after opening (`web/update.js`, adapted from Mythriven).
- **Leaderboard** (title screen): how far players got on each planet. Free charters come first (fewest turns), then the most debt paid. Players type their name on the title screen, then post a score when a colony ends, or retire a running colony from the Menu.
- **Sign in with Google** (Settings, optional), with one **cloud save** per account to carry a game between devices.
- **The online service:** `leaderboard-api/` is a Cloudflare Worker adapted from Mythriven's (leaderboard, Google sign-in, cloud save, privacy page), set up for `lastborn-colony.thebotcoder.workers.dev` and the owner's KV storage. Co-op lobbies, public games and suggestions were left out. Click-by-click setup is in `leaderboard-api/README.md`. Secrets (Google client id and secret) go only into Cloudflare.
- New game files: `scripts/net/online.gd`, `online_config.gd`, `score_entry.gd`, `scripts/ui/app_actions.gd`, and `data/online.json` (all online messages).
- **Research chooser:** the right panel now has a Research button to pick a topic and see progress (or the plague cure). The colony summary shows elders, crime and plague.
- Esc now closes dialogs that are safe to close (Settings, Menu, Briefing, Research, Leaderboard). Dialogs put keyboard focus on their first button, and dialog buttons are at least 44 px tall.
- README: how to play online, the one-time GitHub Pages setting, the online features, and the new files. CREDITS: Wrangler (the Worker's deploy tool).
- Tests: 137 game checks (64 new for the online client) and 29 Worker tests pass. The web build was also played in a browser here (title, Settings, new game, turns, research). The real Worker could not be reached from this test machine, so the leaderboard, Google sign-in and cloud save have not been tried against the live server.

### Decisions for the owner
- Leaderboard names: up to 16 characters, and colony names up to 24, using letters, numbers, spaces, `-` and `_` only.
- The online service accepts web requests only from `zephino.github.io` (and localhost for testing). Desktop builds aren't affected.
- Exception to `lastborn.mdc`: `scripts/ui/main.gd` is now about 850 lines, over the ~400 aim. Splitting it is planned with the interface improvements.

### Reason
The owner asked for the web version to be playable from the internet, a changelog, settings with fullscreen and install/update, Google sign-in using their Worker, a leaderboard of how far players got on which planet, and an updated README.

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
