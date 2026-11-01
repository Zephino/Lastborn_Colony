# Changelog

One entry per change request, newest first (see `.cursor/rules/changelog.mdc`). The version here always matches `VERSION`. The game started inside the `Zephino/ColdLedger` repository (as "Thaw Line", then "Last Colony", then "Lastborn Colony", ColdLedger versions 00.01.05–00.01.07) and moved here at version 00.01.00.

## Version 00.01.53
Date: 11/01/2026
Time: 11:50 PM

### Changes
**The four drones (rovers) were redrawn with much more detail** (`draw_unit` in `scripts/ui/sprites_more.gd`). These drawings are used on the map and in the sprite sheet.
- **Grader:** a bulldozer.
  - treads with road wheels and cleats;
  - a yellow body with an engine grille and a cab cage round tinted glass, with a roof beacon;
  - a curved blade on hydraulic arms, and a headlight.
- **Borer:** an orange tracked digger.
  - a glass cab with a beacon, and hazard stripes;
  - a drill motor on an arm, driving a big cone drill with spiral flutes;
  - rock chips flying off the tip.
- **Prospector:** a six-wheeled explorer.
  - rocker arms, a white body and a blue solar deck;
  - a camera mast with a two-eyed head;
  - a sampling arm shining a teal scanner beam on the ground.
- **Hauler:** a dump truck.
  - a yellow cab with a windscreen, headlight and beacon;
  - a ribbed tipping bin heaped with ore and teal ore chunks, on a lifting piston;
  - six big wheels.
- New shared drawings: `_wheel` (a tyre in its own plane with tread, rim and hub), `_tread` (a caterpillar tread with road wheels), and `_iso_chunk` (a lump of ore).

### Reason
The owner said the rovers needed work.

## Version 00.01.52
Date: 11/01/2026
Time: 11:30 PM

### Changes
**Doors count in play, and buildings can be turned.**
- Each building has a set number of doors (new `doors` field in `data/buildings.json`):
  - **4, hubs:** Landing Pad, Shaft, Shaft Landing, Bunkhouse, Commons, Clinic, Academy, Lounge, Garden Cavern.
  - **2, workplaces:** Splitter, Kelp Vat, Forge, Fab Shop, Reclaimer, Cache, Survey Lab, Workshop, Warden Post, Rescue Station. The two doors are on opposite sides.
  - **1, outlying machines:** Mirror Field, Vent Tap, Ice Drill, Seam Cutter, Spin Launcher, Signal Mast, Beam Catcher, Drone Bay, Fusion Core, Hazard Lab.
  - Heat Mains join on every side.
- **Joining:** neighbouring buildings join, and share power, heat and workers, only where a door meets a door or a Heat Main (`Actions.joined` in the connectivity step).
- **Turning:** a building can be turned in quarter-turns (`rot`, saved with it), and its doors turn with it.
  - When placing, the game turns it automatically to the first way that joins the colony. Press **R** or the new **Rotate** button to turn it yourself.
  - A building with no door facing the colony can't be placed, and says why.
- **Placing preview:** a see-through copy of the building, turned the way it will be built, with orange markers on its door sides. The tile shows green or red for that turn.
- **On the map:** tunnels and airlocks show only where doors meet, and spare doors show capped. Rounded halls (Workshop, Fab Shop, Drone Bay, Cache, Rescue Station, Reclaimer) lie along their doors. Their other artwork keeps facing the camera the same way.
- **Old saves** (no `door_rules`) keep joining on any side.
- **Test bot:** it now hangs one- and two-door buildings off Heat Mains, keeping the hubs' doors free; otherwise it boxed itself in. It still wins every test it must, but games take longer:

| Brume seed | Before | Now |
|---|---|---|
| 1 | 167 turns | 131 turns |
| 2 | 129 turns | 221 turns |
| 3 | 90 turns | 168 turns |

  Door rules make the game harder. This needs watching in real play.
- New tests for door turning, joining only through doors, refusing a wrongly turned building, and old saves (460 checks pass).
- The How to play guide, the README and the placing hint explain doors and turning.

### Reason
The owner decided doors should stay on the sides planned for each building, with the building turned to face them.

## Version 00.01.51
Date: 11/01/2026
Time: 10:55 PM

### Changes
- **Renamed the Landing Hull to Landing Pad.** Its description now says it's where the ship came down: a landing pad with its control dome and airlocks.
  - Player-facing text that meant the building says "landing pad" now: the first log line, the "Landed" message, the landing-site screen, the "not connected" hint, the demolish message, the supply-pod message, one event, one story event and two endings.
- **Renamed the Launch Rail to Spin Launcher.** Its description now says it spins alloy up to speed inside a sealed vacuum drum and flings it to orbit. The "SpinLaunch" trademark is not used.
  - Its research topic is now Magnetic Bearings (was Magnetic Rails).
  - Every other mention was updated: the guide, the README, the Signal Mast's description, the Company account and Drones & orbit text, log messages and tests.
- Internal ids (`hull`, `rail`, `mag_rail`) are unchanged, so saved games load as before.

### Reason
The owner approved "Landing Pad" and chose "Spin Launcher".

## Version 00.01.50
Date: 11/01/2026
Time: 10:45 PM

### Changes
- **The worker's pickaxe hangs from a loop on the side of the tool belt** (`_hanging_pick` in `scripts/ui/people.gd`). The curved steel head rests in a small metal loop at the hip, and the wooden handle hangs down beside the leg. It is no longer slung across the back.

### Reason
The owner asked for the pickaxe to hang from a loop on the side.

## Version 00.01.49
Date: 11/01/2026
Time: 10:35 PM

### Changes
- **The worker's pickaxe was redrawn** (`scripts/ui/people.gd`):
  - a wooden handle with a lighter grain line;
  - a curved steel head across its top that tapers to a point at each end, with a highlight along its upper edge;
  - a dark socket where the head meets the handle.

### Reason
The owner said the pickaxe looked weird.

## Version 00.01.48
Date: 11/01/2026
Time: 10:25 PM

### Changes
- **Workers look like a site crew** (`scripts/ui/people.gd`):
  - a yellow hard-hat shell over the helmet, with a brim, a ridge and a headlamp;
  - a hi-vis orange vest with silver reflective stripes;
  - a brown tool belt with pouches;
  - a yellow power drill in the forward hand.
  - The pickaxe and coiled hose stay on the back.

### Reason
The owner said the worker needed to look better.

## Version 00.01.47
Date: 11/01/2026
Time: 10:15 PM

### Changes
- **Wardens look like security officers** (`scripts/ui/people.gd`):
  - a dark navy suit instead of white, so they stand out from the crews;
  - a gold shield badge on the chest;
  - a torch in the forward hand, shining a beam ahead.
  - On the back, the big violet beacon is gone. They have a short radio aerial and a small red-and-blue light bar, with reflective stripes on the pack.

### Reason
The owner said the Warden needed to be changed.

## Version 00.01.46
Date: 11/01/2026
Time: 10:05 PM

### Changes
- **Colonists carry different gear on their backs by job** (`scripts/ui/people.gd`):
  - **Workers:** a pickaxe slung across the back, and a coiled orange hose on the pack.
  - **Scientists:** a tall antenna with a glowing teal tip, a small sensor dish, and three coloured sample tubes on the pack.
  - **Wardens:** a radio aerial, a violet warning beacon on top of the pack, and violet reflective stripes.

### Reason
The owner suggested each kind of colonist carry something different on their back depending on their job.

## Version 00.01.45
Date: 11/01/2026
Time: 9:55 PM

### Changes
- **Colonists in space suits** (new `scripts/ui/people.gd`): white suits with a gold visor, a backpack, boots and a coloured stripe by job (orange workers, teal scientists, violet wardens). They stand or walk mid-stride.
  - **On the map** (`scripts/ui/map_view.gd`), colonists stand and walk on open ground next to the colony. There's about one for every eight people, up to 16 (half as many in the Deep), and they move to new spots every turn.
  - Some are scientists if you have a lab, and some are wardens if you have a Warden Post.
- **Resource icons** beside every number in the top bar (new `scripts/ui/stat_icon.gd`, drawn in `people.gd`):
  - a helmet for people and a smiley for morale;
  - a lightning bolt for power and a flame for heat;
  - a helmet with a work stripe for idle workers;
  - kelp for food, an O2 bottle for oxygen and a drop for water;
  - a rock with a teal vein for ore, stacked ingots for alloy and a hex nut for parts;
  - a coin for marks, a bill for the debt, and calendars for the turn and the next payment.
- The units page of the sprite sheet now also shows the three colonists and all the icons.

### Reason
The owner asked for resource icons and for colonists, in space suits.

## Version 00.01.44
Date: 11/01/2026
Time: 9:30 PM

### Changes
**Balance check of the newer content.**
- The test bot has an optional advanced mode (`Bot.advanced` in `tests/bot.gd`). It also builds a Fab Shop, a Drone Bay with Prospector, Hauler and Grader drones, Signal Masts, an Academy, a Rescue Station, a Fusion Core (once researched) and a Lounge, and launches a relay satellite.
- The new `tools/balance.gd` plays 10 games per planet both ways. Results, as turns to buy out the charter:

| Planet | Basic bot | Advanced bot |
|---|---|---|
| Brume | 120 turns, 10/10 wins | 151 turns, 10/10 wins |
| Cinder | 114 turns, 9/10 wins | 134 turns, 9/10 wins |
| Hollow | 168 turns, 10/10 wins | 183 turns, 10/10 wins |

- Advanced colonies end up 12–19% bigger. Testing one item at a time over 30 games, the Signal Masts account for most of the slowdown. About half of that comes from the bot letting a happier colony grow and spending its alloy on homes and food instead of exports. Worked out by hand, the Mast is still worth its 8 alloy: three masts add roughly 1,000 marks of sales over a game. The bot doesn't play it well, so its numbers were left alone.
- The new content makes the game neither broken nor easier for the bot. No item is an easy win.
- **Fix found by the check:** the Fab Shop kept turning 2 alloy into parts every turn even with a full store of parts, quietly wasting alloy. It now pauses while the colony holds 40 parts (new building field `max_stock`), and says so when selected: "Paused: the colony already holds 40 parts".
- The Fusion Core is never reached by the bot: its research needs four earlier topics, so it's a late-game building.
- New tests: the Fab Shop pauses at 40 parts and uses no alloy while paused, and the advanced bot buys out the charter on seeds 1–3. 447 checks pass.

### Reason
The owner asked for a balance check of the new buildings.

## Version 00.01.43
Date: 11/01/2026
Time: 8:45 PM

### Changes
A second look at the sprites the owner hadn't commented on (`scripts/ui/sprites_more.gd`). Beam Catcher and Garden Cavern were kept as they are. Four were reworked:
- **Rescue Station:** the floating life ring is gone. It now has a red roll-up bay door in the hall's curved side, a red stripe along it, and red and blue beacons on the roof. The rescue rover is parked in front of the door.
- **Lounge:** a glowing pink neon rim round its foot, two rows of coloured string lights across the dome, and a neon sign on a post.
- **Hazard Lab:** glowing waste barrels beside it and a yellow warning sign on a post.
- **Signal Mast:** a proper lattice tower, wide at the foot and narrowing to the top, with cross-braces, and two real dishes on arms with feed horns.

### Reason
The owner asked for a second look at the Rescue Station, Lounge, Hazard Lab, Signal Mast, Beam Catcher and Garden Cavern.

## Version 00.01.42
Date: 11/01/2026
Time: 8:25 PM

### Changes
- **How to play guide:** 10 short pages in simple words, each with a building picture:
  1. the goal (pay off the debt);
  2. building and moving the map;
  3. power and heat;
  4. keeping people alive;
  5. homes and morale;
  6. making money;
  7. going underground;
  8. research and trouble;
  9. drones and orbit;
  10. tips.
- Open it with **How to play** on the title screen or in the in-game Menu. Each page has Next, Back and Close.
- The text lives in the new `data/help.json` (loaded by `GameData.help_pages()`); the viewer is `show_help` in `scripts/ui/menus.gd`.
- A new test checks every page has a title, some text and a real building picture.

### Reason
The owner asked for a how-to-play guide for first-time players.

## Version 00.01.41
Date: 11/01/2026
Time: 8:10 PM

### Changes
- **Building pictures in the menus**, using the new `scripts/ui/sprite_icon.gd`, which draws one building's angled sprite on the ground it is usually built on:
  - The build list on the left shows a small picture beside every building.
  - The Build menu (phones) shows a picture beside every choice. Ones you can't build yet are faded.
  - The side panel shows a large picture of the selected building above its details, and the Info dialog (phones) shows it under the title.
- `show_modal` options can now carry a building id to show its picture, and the dialog can show one large picture under its title.
- `tools/ui_shot.gd` also takes a screenshot with a building selected.

### Reason
The owner asked for building pictures in the Build menu and Info panel.

## Version 00.01.40
Date: 11/01/2026
Time: 7:55 PM

### Changes
- **Working drones are shown on the map** (`scripts/ui/map_view.gd`), at the front corner of the tile they're working on:
  - **Graders** stand by the surface buildings they're helping to build.
  - **Borers** stand by Shafts and buildings in the Deep.
  - **Haulers** stand by the Seam Cutters they serve.
  - **Prospectors** roam the open ground at the colony's edge, at a new spot each turn.
  - Idle drones (beyond what the Drone Bays can run) aren't shown.
- **Satellites in orbit** show in an "In orbit" strip of night sky at the top of the surface map, one picture per satellite.
- **The Deep looks like a cave** (`terrain_iso` in `scripts/ui/sprites.gd`):
  - Solid rock stands up as rough raised blocks of slightly varied shades, with open cavern floor (with pebbles) between them.
  - Ore veins glow teal in the rock, aquifers are blue pools, and deep vents are glowing cracks.
  - Rock that has a building on it is drawn dug out, flat.
- `tools/ui_shot.gd` now also places drones, satellites and a small Deep colony, and takes a screenshot of the Deep.

### Reason
The owner asked to see drones and satellites on the map, and for the Deep to be checked.

## Version 00.01.39
Date: 11/01/2026
Time: 7:30 PM

### Changes
- **Tunnel junctions look cleaner** (`scripts/ui/sprites.gd`):
  - At a T-junction or crossroads, each tube now stops at the hub's wall and plugs in through a flange ring, instead of running into the middle and overlapping the hub's base.
  - The hub drum is a little wider, so the tubes meet its sides.
  - Flanges (`_flange`) are now one shared drawing, used both where tubes join between tiles and where they plug into a hub.

### Reason
The owner didn't like how the tubes met at the junction hub.

## Version 00.01.38
Date: 11/01/2026
Time: 7:15 PM

### Changes
**Better-looking tubes on the angled map** (`scripts/ui/sprites.gd`):
- **Tubes** are shaded like round metal pipes lit from above, with a highlight along the top, a thin orange stripe, a rib every fifth of a tile, and a raised flange where one tile's tube meets the next. They're slimmer than before.
- **Airlock collars** are smaller and neater: a short wider ring with an amber band and a small light, drawn in the right order so the tube runs cleanly into and out of it.
- **Junctions** (T-junctions and crossroads) are now domed drums with an orange band and a light, standing above the tubes.
- **Corners and dead ends** have rounded, shaded ball joints.

### Reason
The owner said the tubes needed to look better.

## Version 00.01.37
Date: 11/01/2026
Time: 6:55 PM

### Changes
- **The game map is now angled (isometric) and uses the new sprites.** `scripts/ui/map_view.gd` was rewritten:
  - Tiles are diamonds. Ground and buildings are drawn back to front, so nearer buildings cover farther ones.
  - Every building, tunnel and ground tile uses the drawings from `scripts/ui/sprites.gd` and `sprites_more.gd`. Tunnels join neighbouring buildings automatically, and doors and airlocks show where they meet.
  - Buildings under construction are faded and have a progress bar. Broken ones show a yellow cross above them, and idle ones a red dot.
  - The night-side and day-side tint, the green or red placement preview, hover and the selected tile all work on the diamonds.
  - Clicking, tapping, dragging, wheel and pinch zoom, the zoom buttons, the arrow keys and the Surface/Deep switch all work as before.
  - The map starts zoomed in further (tiles 120 pixels wide on computers, 110 on phones), and zooms between 36 and 220.
- The old flat map icons are gone.
- New tests: every tap near the middle or corners of every tile, at three zoom and pan settings, finds the right tile, and centring on a tile puts it in the middle. 441 checks pass.
- `tools/ui_shot.gd` now places a small colony before taking its screenshots.

### Reason
The owner chose the angled view for the game.

## Version 00.01.36
Date: 11/01/2026
Time: 6:30 PM

### Changes
- **Landing Hull:** each airlock building now also has a door on its pad side, so people can walk from the pad into it (sprite concept).
  - **Top-down:** every one shows a dark doorway with a lit amber step.
  - **Angled:** the two back buildings show their door, with a small amber lamp over it. The front two face away, so their doors are hidden.

### Reason
The owner said the airlock buildings should look like they have a door on the other side.

## Version 00.01.35
Date: 11/01/2026
Time: 6:20 PM

### Changes
- **Landing Hull:** each of the pad's four doors is now a small airlock building on the pad's edge, so tunnels run into a building instead of the bare pad (sprite concept, top-down and angled). Each one is a metal block with a small glass roof bubble and an orange band round its foot, and carries the door ring.

### Reason
The owner said that around the Landing Hull's doors there should be a building for the tubes to go into.

## Version 00.01.34
Date: 11/01/2026
Time: 6:05 PM

### Changes
**Not every building is a dome now**, only dome-like: sealed and rounded, but shaped for its job (sprite concepts in `scripts/ui/sprites.gd`, still not used in the game). New hull shapes (`SHAPE`):
- **Rounded halls** (arched glass halls with metal ribs, like a hangar):
  - **Workshop:** the lift and rover inside, the arm and crane outside.
  - **Fab Shop:** beside its sawtooth factory hall.
  - **Drone Bay:** beside its garage and parking lot.
  - **Cache:** a warehouse full of crates and barrels.
  - **Rescue Station** and **Reclaimer.**
- **Tall banded tank** with a glass cap: **Splitter**, which holds water and oxygen.
- **Watchtower:** **Warden Post** has a base drum with lit windows, a column, and a glass lookout cab with a searchlight. The drum is as tall as the airlocks, so its tunnels join a real wall instead of appearing out of nowhere.
- Domes stay where they fit: homes, the Clinic, the Commons, parks, the Lounge and the Academy. Buildings with their own shapes are unchanged.
- Tunnels and doors meet each hull at its real edge: the ends and sides of a hall, or the edge of a tank. The outline shown while a building is under construction follows its shape.

### Reason
The owner said buildings don't all have to be domes, just dome-like, and should look more like what they are. They also asked for the Warden Post's door to look cleaner.

## Version 00.01.33
Date: 11/01/2026
Time: 5:35 PM

### Changes
- **Reclaimer:** the green recycling symbol is gone (sprite concept, top-down and angled). The shredder's rollers now show inside the dome instead.

### Reason
The owner didn't like the recycling symbol.

## Version 00.01.32
Date: 11/01/2026
Time: 5:25 PM

### Changes
Sprite concepts (still not used in the game):
- **Reclaimer redrawn as a recycling plant:**
  - a heap of mixed junk with a conveyor feeding the dome;
  - a shredder with two toothed rollers and a green glow inside;
  - a clear green recycling sign (three chasing arrows) on the dome;
  - stacks of strapped crushed-scrap bales;
  - a squat tank of recovered water.
- **Door counts chosen for each building** (`DOORS` in `scripts/ui/sprites.gd`):
  - **4 doors, hubs where people live, gather or move between levels:** Landing Hull, Shaft, Shaft Landing, Bunkhouse, Commons, Clinic, Academy, Lounge, Garden Cavern.
  - **2 doors, workplaces you pass through (in one side, out the opposite side):** Splitter, Kelp Vat, Forge, Fab Shop, Reclaimer, Cache, Survey Lab, Workshop, Warden Post, Rescue Station.
  - **1 door:**
    - out-of-the-way sites and machines tied to the ground: Mirror Field, Vent Tap, Ice Drill, Seam Cutter, Launch Rail, Signal Mast, Beam Catcher, Drone Bay (its drones use the garage);
    - places kept apart for safety: Fusion Core, Hazard Lab.
  - A two-door building's spare door sits opposite its tunnel.
  - The sprite sheet shows each building with a tunnel at every door and labels its door count.
- Gameplay is unchanged: a building still joins the colony through any side that touches it.

### Reason
The owner said the Reclaimer needed fixing, and asked for each building to have 1, 2 or 4 entrances, whichever makes the most sense, with all buildings redrawn.

## Version 00.01.31
Date: 11/01/2026
Time: 5:00 PM

### Changes
- **Drones are wheeled rovers, not flying drones.**
  - The small drone drawn at the Workshop and Drone Bay (`_top_drone` and `_iso_drone` in `scripts/ui/sprites.gd`) is now a yellow six-wheeled rover with a cab window and a headlight, matching the units sheet.
  - The one on the Workshop's lift is missing a wheel (it lies beside it) and shows a red light.
  - The rovers at the Drone Bay (inside, in the garage and in the parking lot) are bigger.
- The Drone Bay's map icon in the game is now a little rover too.

### Reason
The owner pointed out that the drones are wheeled vehicles, not quadcopters.

## Version 00.01.30
Date: 11/01/2026
Time: 4:45 PM

### Changes
Sprite concepts (still not used in the game):
- **Each building has its own number of doors** (`DOORS` in `scripts/ui/sprites.gd`). Sides with a tunnel always get an open door; spare doors show as capped ones, front sides first. Other sides are plain wall.
  - Four doors (hubs): Landing Hull, Commons, Bunkhouse, Clinic, Cache, Lounge, Garden Cavern, Academy.
  - One door: Mirror Field, Signal Mast, Beam Catcher.
  - Two doors: everything else.
  - The sheet shows the one-door buildings with a single tunnel.
- **Drone Bay:** a one-bay parking lot with painted lines and a parked drone, beside the garage.
- **Academy redrawn as a proper schoolhouse:**
  - a brick dome with two rows of lit classroom windows and white trim;
  - a cream bell tower with an open belfry, a gold bell, a clock and a red roof;
  - a porch with steps, columns and a gable over the front door;
  - a flagpole, a fenced playground (swings, slide, sandpit) and the yellow school bus.

Gameplay is unchanged: a building still joins the colony through any side that touches it.

### Reason
The owner meant that only some buildings should have fewer than four entrances, not all of them. They asked for a parking lot for one drone at the Drone Bay, and for the Academy to look better.

## Version 00.01.29
Date: 11/01/2026
Time: 4:20 PM

### Changes
- **Doors only where a tunnel joins** (sprite concepts in `scripts/ui/sprites.gd`, still not used in the game). Buildings no longer show four orange doors. A side with a tunnel has its airlock and orange door ring; a side without one is plain wall, with no capped door. This applies to every building, top-down and angled.
- Gameplay is unchanged: a building still joins the colony through any side that touches it.

### Reason
The owner said not every building needs four entrances.

## Version 00.01.28
Date: 11/01/2026
Time: 4:05 PM

### Changes
Sprite concepts in `scripts/ui/sprites_more.gd` (still not used in the game), following the owner's feedback:
- **Fusion Core looks like a power station:** a concrete containment dome with a blue-lit hatch, and two big hourglass cooling towers at its sides with clouds of steam.
- **Fab Shop looks like a factory:** a factory hall with a sawtooth roof of skylights and a tall smoking chimney. Inside, a conveyor carries parts between two yellow robot arms, and crates of parts wait outside. The old gantry, which looked like a cross, is gone.
- **Academy looks like a school:** a clock tower with a red roof, a front entrance with columns and a gable, and rows of desks facing a chalkboard. Outside are a playground with swings and a slide, a yellow school bus and a tree.
- **Drone Bay looks like a garage:** a garage beside the dome with a half-open roll-up door, a drone parked inside, a light over the door and a hazard-striped sill. A charging rack stands at the back.

### Reason
The owner said the Fab Shop looked like a church, the Academy like a movie theater, the Fusion Core should look like a nuclear power plant, and the Drone Bay like a garage.

## Version 00.01.27
Date: 11/01/2026
Time: 3:40 PM

### Changes
Sprite concepts for everything added in 00.01.26 (still not used in the game; the map keeps its simple icons for now). They're drawn top-down and angled, in the dome-and-tunnel style, in the new `scripts/ui/sprites_more.gd`:
- **Fusion Core:** a glowing plasma ring held by magnet coils, with two steaming cooling towers.
- **Beam Catcher:** four fields of receiving mesh round a small receiver, with a shaft of light coming down from orbit.
- **Reclaimer:** chasing green recycling arrows, a hopper of junk, a water tank and an ore bin.
- **Fab Shop:** a print bed under a yellow gantry with a glowing nozzle, alloy coming in on a belt, and crates of parts.
- **Drone Bay:** docked drones inside, a landing pad with a drone, and a charging rack.
- **Signal Mast:** a lattice mast with dishes, a red light, signal waves and guy wires.
- **Rescue Station:** a life ring, red warning beacons, a rescue rover and brace beams.
- **Academy:** rows of desks facing a glowing board, a flag and a tree.
- **Hazard Lab:** a glowing green orb inside a hazard-striped blast wall.
- **Garden Cavern:** trees, a pond, a path and flowers under the glass.
- **Lounge:** a glowing dance floor, a bar and a neon sign.
- **Drones** (angled): the Grader (tracks and a wide blade), the Borer (tracks and a drill cone), the Prospector (six wheels, sensor mast and sample arm) and the Hauler (a truck full of ore).
- **Satellites** (angled, in space): weather (solar wings and a sensor eye), relay (a big dish) and power (a gold mirror sail beaming power down).
- The sprite sheet tool (`tools/`) now draws two building pages, a units page, tunnels and the world.

### Reason
The owner asked to see sprites for all units and buildings.

## Version 00.01.26
Date: 11/01/2026
Time: 3:05 PM

### Changes
New buildings, drones, satellites and systems. Every name and number is Lastborn's own (see `lastborn.mdc`).
- **New resource: parts.** A **Fab Shop** turns 2 alloy into 2 parts. Drones, satellites and the advanced buildings need parts as well as alloy. The build menu shows both prices.
- **Drones** (new **Drones & orbit** button; **Drones** on phones). A **Drone Bay** runs 4 drones; the new Drone Swarms research adds 2 more per bay. Drones beyond that sit idle.
  - **Grader:** helps one surface building under construction each turn.
  - **Borer:** helps a Shaft or Deep building, and makes digging into rock cost no extra alloy.
  - **Prospector:** brings in 2 ore a turn.
  - **Hauler:** two Seam Cutters make 25% more ore.
- **Satellites,** launched from a working Launch Rail for alloy, parts and marks:
  - **Weather:** grit fronts hurt mirrors half as much, and icequakes reach less far.
  - **Relay:** morale +3.
  - **Power:** each beams 10 power to the new **Beam Catcher** (needs the new Power Beaming research).
- **Fusion Core:** 30 power and 6 heat, day or night. Needs the new Contained Fusion research, 40 alloy and 12 parts.
- **Waste:** people make waste, some of which breaks down by itself. Above 40 it lowers morale; above 80 plague is more likely. The **Reclaimer** recycles it into a little ore and water.
- **Academy:** trains specialists (up to 30% of adults), who make Forges, Fab Shops, Seam Cutters and labs up to 15% better.
- **Civic buildings:**
  - **Signal Mast:** morale +2, and 1 more mark per alloy sold (up to 3 masts).
  - **Rescue Station:** disasters damage half as many buildings.
  - **Hazard Lab:** 3 research, but morale -3 and frequent breakdowns.
  - **Garden Cavern:** Deep only. Morale +7 and a little food.
  - **Lounge:** morale +9, but 3 marks a turn to run and crime +4. A building that can't pay its running cost sits idle and says why.
- **New cargo:**
  - **Supply pod:** stays aboard the ship; call it down any time for 50 alloy, 40 food and 40 oxygen.
  - **Survey probes:** the landing-site screen also lists the ore veins, aquifers and deep vents under each site.
- Simple map icons for the new buildings. The Colony report has a new "colony systems" line (drones, satellites, waste, specialists, pods).
- Saves from before this version load with no drones, satellites, parts or waste.
- Tests: new `tests/test_fleet.gd` (52 checks) covers every new building, drone, satellite and system, and old saves. The test bot now builds Reclaimers; it still wins as before (seed 1 takes a few more turns because of waste). 438 checks pass.
- New developer tool `tools/ui_shot.gd` takes screenshots of the game screens (not part of the game).

### Reason
The owner asked for a building or unit for every kind of job a colony game like this needs. They agreed to original buildings and units instead of copying another game's list, and said "do them all".

## Version 00.01.25
Date: 11/01/2026
Time: 2:14 PM

### Changes
Sprite concepts in `scripts/ui/sprites.gd` (still not used in the game), following the owner's feedback:
- **Kelp Vat is now a kelp ring farm:** a sealed pool farmed like an ocean kelp farm. Ropes run out from a centre buoy like spokes, with kelp growing along them. Two big floating rings with orange buoys hold them up. A low glass pressure dome covers it, with pink grow lamps round its seal, and a crate of harvested kelp sits at one corner.
- **Seam Cutter is now a laser quarry:** a stepped pit cut down into the ground with teal ore showing in its walls. A yellow gantry on four legs spans the pit, and its laser head shines a beam onto the glowing seam at the bottom, throwing sparks. Cut ore blocks wait at one corner, with a small control dome at the back.
- **Workshop:** the gear-and-wrench sign and spare gear are gone. Inside the dome a drone with a broken rotor sits on a yellow scissor lift, with a tool wall behind it. The yellow robot arm, repair pad, rover and crane outside stay.
- **Bunkhouse, angled view:** now matches the top-down view the owner liked. Pairs of beds stand against the walls round a central table, instead of the stacked bunk bed.
- Survey Lab unchanged (the owner liked it). Unused drawing helpers were removed.

### Reason
The owner liked the Workshop's yellow structures but not the gear and wrench. They liked the Bunkhouse's top-down look but not its angled one, and said the Seam Cutter still looked weird. They wanted the Kelp Vat to look like ocean kelp farms with big rings.

## Version 00.01.24
Date: 11/01/2026
Time: 1:54 PM

### Changes
- **Four buildings redrawn to show what they do** (sprite concepts in `scripts/ui/sprites.gd`, still not used in the game):
  - **Kelp Vat:** the dome is full of water with kelp growing in it, bubbles and pink grow lamps. A tall glass grow tank full of kelp stands beside it, and a crate of harvested kelp sits in front.
  - **Bunkhouse:** beds and bunk beds can be seen through the glass around a table with a warm lamp. It has a lit front door, a lamp post and a planter of shrubs.
  - **Seam Cutter:** a boom with a spiked cutting drum chews into cracks of teal ore in the ground, raising dust. A conveyor carries ore to a heap, and fresh ore sits inside the dome.
  - **Workshop:** a gear-and-wrench sign glows on the dome. A robot arm welds a broken rover on a hazard-striped repair pad, and a small crane lifts an engine block. Parts crates and a spare gear stand at the back.
- **The Survey Lab is now a giant radio telescope:** a huge mesh dish set into the ground, with three lattice towers holding a receiver platform on cables high over the middle. It has a small glass control dome at one corner. The old lab drawing code was removed.
- All are drawn both top-down and angled. Tunnels, airlocks and ports join them as before.

### Reason
The owner said the Seam Cutter, Workshop, Bunkhouse and Kelp Vat didn't look like what they do. They also asked for the Survey Lab to be like a big radio telescope set into the ground.

## Version 00.01.23
Date: 11/01/2026
Time: 1:42 PM

### Changes
- **The Forge looks industrial** (sprite concept in `scripts/ui/sprites.gd`, still not used in the game). It is no longer a glass dome but a heavy plant:
  - a riveted steel dome with panel seams, glowing orange heat vents and an amber warning beacon on top;
  - hazard stripes around its base;
  - an ore hopper on legs, fed by a conveyor carrying ore;
  - two smokestacks with hazard bands and dark smoke, joined to the dome by a thick pipe;
  - a glowing furnace door throwing sparks, and a stack of finished alloy bars.
- Drawn both top-down and angled. Tunnels and ports join it like any other building. The old Forge drawing code was removed.

### Reason
The owner asked for the Forge to look more industrial.

## Version 00.01.22
Date: 11/01/2026
Time: 1:39 PM

### Changes
- **The Launch Rail is now a spin launcher** (sprite concept in `scripts/ui/sprites.gd`, still not used in the game). A big sealed vacuum drum spins a cargo pod on an arm, then throws it up a launch tube toward orbit, with no fuel needed.
  - Drawn as the drum with a bolted rim, and a dark window showing the spinning arm, the white pod and glowing cyan motion trails.
  - A launch tube with an orange stripe leaves the rim and climbs toward the sky on supports, with a light at its mouth.
  - A small control dome stands at the front corner. Tunnels, airlocks and ports join the drum like any other building.
- The building still works the same (it sells alloy for marks) and keeps its name for now. "SpinLaunch" is a real company's name, so the building won't use it; a name like "Spin Launcher" or "Sling Launcher" is for the owner to choose.

### Reason
The owner suggested a spin-launch idea for the Launch Rail.

## Version 00.01.21
Date: 11/01/2026
Time: 1:34 PM

### Changes
Sprite concepts in `scripts/ui/sprites.gd` (still not used in the game):
- **Survey Lab, more scientific:** a glowing hologram of an atom (three orbits, a core and electrons) inside the dome, a telescope looking out of the observatory slit, a satellite dish on a stand, a short sensor mast with a red light, and three glowing specimen tubes (green, cyan, violet).
- **Vent Tap and Forge now look different:**
  - **Vent Tap:** no chimney. A glowing magma pool shows through the glass, radiator fin banks stand on both sides, a big red valve wheel is on the front, and white steam escapes from a relief valve.
  - **Forge:** twin smokestacks with dark smoke, a conveyor belt bringing ore in, a crucible glowing through the glass, a furnace door throwing sparks, and a stack of finished alloy bars.
- **Launch Rail, new design:** a launch track climbs toward the sky on pylons, with twin gold rails and four glowing accelerator coils. A white cargo pod waits at the bottom, and a small control dome sits in front with a feed tube up to the track.

### Reason
The owner asked for a more scientific Survey Lab, a better Launch Rail, and for the Vent Tap and Forge to look different, because they were nearly the same.

## Version 00.01.20
Date: 11/01/2026
Time: 8:56 AM

### Changes
- **The Shaft is airtight** (sprite concepts in `scripts/ui/sprites.gd`, still not used in the game). The hole into the ground is now sealed under a clear pressure dome, held down by a ring of bolts at the rim. The pit, ladder and hoist show through the glass. In the angled style the dome is tall enough to cover the hoist frame. Tunnels and airlocks join the rim as before.

### Reason
The owner said the shaft should look airtight.

## Version 00.01.19
Date: 11/01/2026
Time: 8:55 AM

### Changes
- **The Shaft is a hole into the ground** (sprite concepts in `scripts/ui/sprites.gd`, still not used in the game). Instead of a dome it is an open, round pit:
  - a metal rim with orange-and-black hazard stripes and four lights;
  - rock walls getting darker with depth until they go black;
  - a ladder down the far wall;
  - a hoist frame over the opening, with its cable dropping into the pit.
- Tunnels, airlocks and orange ports join the rim like any other building. Drawn both top-down and angled; in the angled style you see the far inside wall going down into the dark.

### Reason
The owner said the shaft is a hole into the earth.

## Version 00.01.18
Date: 11/01/2026
Time: 8:53 AM

### Changes
- **The Landing Hull looks like a landing pad**, similar to a helipad (sprite concepts in `scripts/ui/sprites.gd`, still not used in the game).
  - It is a round, low platform with an orange edge ring and a painted yellow ring.
  - A big painted **H** lies flat in the middle, with 12 landing lights around the edge and a small control dome at the back corner.
  - Its orange tube ports and tunnels work like every other building's.
  - Drawn both top-down and angled; in the angled style the H and ring lie flat on the platform.

### Reason
The owner asked for the landing pad to look similar to a helicopter landing pad.

## Version 00.01.17
Date: 11/01/2026
Time: 8:51 AM

### Changes
- **Tunnels in every shape** (sprite concepts in `scripts/ui/sprites.gd`, still not used in the game). A tunnel tile now takes its shape from its neighbours (`Sprites.tunnel_shape`):
  - **Lone stub:** a short tube capped at both ends.
  - **Dead end:** a tube capped with an orange light.
  - **Straight:** one continuous tube, with no hub.
  - **Corner:** an elbow joint.
  - **T-junction and crossroads:** a round hub.
- Both styles, top-down and angled. In the angled style, caps and elbows are drawn on top so tubes never hide them.
- New concept sheet: `tools/sprite_sheet.gd` now also renders `lastborn_sprites_tunnels.png`, with all 16 ways a tunnel tile can connect.

### Reason
The owner asked for tunnels in all shapes.

## Version 00.01.16
Date: 11/01/2026
Time: 8:48 AM

### Changes
- **Round tunnels and airlocks** (sprite concepts in `scripts/ui/sprites.gd`, still not used in the game):
  - Tunnels between buildings and on Heat Main tiles are now **round tubes**: shaded to look rounded, with the glowing orange stripe along the top and rib rings. In the angled style they are real cylinders with a round end face.
  - Airlocks are now **round collars** around the tube where it meets the dome, with two amber rings, instead of square boxes.
  - The Heat Main junction is round, with an orange ring.

### Reason
The owner asked for the tunnels and airlocks to be round.

## Version 00.01.15
Date: 11/01/2026
Time: 8:46 AM

### Changes
- **Orange tube ports on every dome** (sprite concepts in `scripts/ui/sprites.gd`, still not used in the game):
  - **Tunnels:** every tunnel between buildings now looks like a Heat Main: a dark casing, a metal core, a glowing orange stripe and ribs. Where it meets a dome there is an airlock and an **open orange ring** in the dome wall.
  - **Unconnected sides:** every side of a dome without a tunnel has a **capped orange port**, a metal cap in an orange ring with a small orange light, ready for a tunnel.
  - **Angled style:** the tunnels carry the same orange stripe, and the two sides facing the viewer show their ports.

### Reason
The owner asked for every building to have an orange tube opening like the Heat Main.

## Version 00.01.14
Date: 11/01/2026
Time: 8:44 AM

### Changes
- **Sprite concepts redrawn as a space colony** (`scripts/ui/sprites.gd`, still not used in the game):
  - **Domes:** every building is a pressurised dome with a metal base ring, glass shell and ribs, and a band in its group colour. Each dome shows its job through the glass and with fittings outside: kelp in the Kelp Vat, a garden in the Commons, a furnace chimney and glowing door on the Forge, an observatory slit and antenna on the Survey Lab, a beacon tower on the Warden Post, gas tanks beside the Splitter, a launch ramp from the Launch Rail, and mirror wings beside the Mirror Field dome.
  - **Tunnels:** a short tunnel joins each dome to every neighbouring building, and Heat Main tiles are longer tunnels with ribs and a junction.
  - **Airlocks:** every tunnel meets a dome through an airlock, a chamber with amber-striped doors.
  - Both styles, top-down and angled, are updated. In the angled style, tunnels going away from the viewer are drawn behind the dome and tunnels coming toward the viewer in front of it.
- The concept sheets (`tools/sprite_sheet.gd`) now show each building with two tunnels, and a sample colony with every building joined to its neighbours.

### Reason
The owner wants every building to look like a dome, joined to the next building by a tunnel, with an airlock between buildings, because the colony is in space.

## Version 00.01.13
Date: 11/01/2026
Time: 8:40 AM

### Changes
- **New sprite concepts, not yet used in the game.** `scripts/ui/sprites.gd` draws every building with its own silhouette, in two styles: top-down for today's square map, and angled ("isometric") for a diamond-tile map. It also draws all 13 terrain types both ways.
  - The look is dark metal, glass roofs and a glowing accent colour per building group: energy cyan and gold, life support green and teal, industry orange, civic violet.
  - Under-construction (faint) and idle (dimmed) versions are included.
  - Heat Mains join only toward the neighbours they connect to.
  - Everything is original and drawn in code; nothing comes from Cold Ledger.
- `tools/sprite_sheet.gd` renders concept sheets to PNG files: every building both ways, and a sample colony drawn both ways. It needs a display, for example `xvfb-run`. The `tools/` folder is left out of the web build.
- Reviewed Cold Ledger's new code-drawn sprites: legally reusable, but drawn for its own Outpost-derived buildings, angled only, and about 20 of them are the same box in different colours. So the owner decided to remake Lastborn's sprites instead.

### Reason
The owner said the sprites might all need remaking, and asked to see both styles side by side before choosing.

## Version 00.01.12
Date: 11/01/2026
Time: 8:35 AM

### Changes
- New owner rule in `CLAUDE.md`, `AGENTS.md` and `.cursor/rules/git-workflow.mdc`: all Lastborn Colony work goes to `Zephino/Lastborn_Colony` only. Nothing is ever committed, pushed or branched in `Zephino/ColdLedger` or other repositories; they are read-only references. The owner approved adding this rule.
- Checked that everything from the old `claude/awesome-faraday-ap5jrw` branch in ColdLedger (the game's first versions, before it moved here) is in this repository: all 20 files are here, and GitHub's `main` matches the latest work.

### Reason
The owner asked to delete that ColdLedger branch, to make sure everything is in the Lastborn repository, and to stop pushing to ColdLedger. The branch itself must be deleted on GitHub by the owner: this environment can't delete branches.

## Version 00.01.11
Date: 11/01/2026
Time: 8:25 AM

### Changes
- **The Deep: an underground level.** Every map now has a second level below the surface. It is made from the same seed but with its own random stream, so surface maps and every earlier result are unchanged. The Deep has solid rock, open caverns, rich ore veins, aquifers, deep vents and bedrock.
  - **Shaft** (new building: surface, 15 alloy, 3 turns): when it's finished, it digs out a **Shaft Landing** directly below and joins the two levels. A shaft can't be dug above bedrock. Removing the Shaft also closes its landing.
  - **Digging:** building on solid rock costs +4 alloy and takes +2 turns. Caverns cost the normal price. The hint and inspector show the digging cost.
  - **Why go down:**
    - Buildings underground need a steady, low heat factor (0.5), which helps on cold worlds like Hollow.
    - Seam Cutters on ore veins cut 50% more ore.
    - Vent Taps on deep vents give 50% more heat.
    - Ice Drills work on aquifers.
    - Icequakes never reach the Deep.
  - Mirror Fields and Launch Rails need the sky and stay on the surface. Housing, life support, industry and civic buildings can go underground.
  - **Switching levels:** Surface/Deep buttons above the build list, the Q and E keys, or the Deep/Surface button on phones. Switching to the Deep centers on the landing, or explains how to open one.
  - Saves keep each building's level, and older saves get a Deep made from their map seed.
- The placing bar now sits over the top of the map, so the map no longer jumps when you pick a building.
- Connectors (heat mains, shafts, landings) no longer show the red "idle" dot.
- **Tests:** 368 game checks pass (19 new for the Deep): shaft rules, the landing opening, digging costs, connection through the shaft, steady heat, icequake shelter, saves, demolition, and older saves. Played in a browser here: building a Shaft, ending turns until it broke through, switching to the Deep with E, and inspecting a rock tile.

### Reason
The owner chose underground levels as the third of the three next features.

## Version 00.01.10
Date: 11/01/2026
Time: 8:13 AM

### Changes
- **Factions.** The Company (Harrow & Vell) and the Crews' Union each have a relation from 0 to 100, starting at 50.
  - **Company:** at 60 or more, each supply drop brings 2 extra settlers; at 25 or less, it brings none. Missed-payment penalties are 50% harsher at 0 and half as harsh at 100. Paying on time raises relations by 3, and missing a payment lowers them by 10.
  - **Union:** each point above or below 50 moves the morale the colony is heading for by 0.1. Shortages lower it by 2 a turn; morale above 60 raises it slowly.
  - Both show in the colony summary, and the Colony report says what they are doing to you.
- **Story.** 11 original story events (`data/story_events.json`) with characters and choices:
  - Each arrives once, when its conditions hold: turn, population, faction standing, or a flag set by an earlier choice (for example, a promise made to the inspector is called in later). There are at least 6 turns between story events.
  - Every event has at least one choice that doesn't end the game. Choices can change relations, morale, marks and alloy, start a strike, or set a story flag.
- **Two new endings:**
  - **Independence:** the Assembly, when the Union is at 75+ and the Company at 30 or less after turn 60.
  - **Company Town:** A Generous Offer, when the Company is at 80+ and the Union at 40 or less after turn 60.

  Both have their own ending text and can be posted to the leaderboard, which accepts them and ranks them by debt paid.
- Older saves load with neutral factions and no story yet.
- The test bot never takes a game-ending story choice, because it plays for a Free Charter.
- **Tests:** 348 game checks (69 new) and 55 server tests pass. The new checks cover:
  - every story event's effects, and that each event has a choice that doesn't end the game;
  - faction changes, and flags unlocking a follow-up event;
  - the Assembly leading to Independence, and posting that score;
  - the Company withholding settlers;
  - older saves.

  The scripted player still wins at least 2 of 3 games on every planet and difficulty. The first story event was checked on a phone-sized screen here.

### Reason
The owner chose story and factions as the second of the next three features.

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
