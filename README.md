# Lastborn Colony: how to play

A turn-based colony game. You lead the first settlers on a moon that always shows the same face to its sun. One edge of the map is frozen night and the other is scorched day; you live on the strip between them, on the surface and in the caves below.

Your settlers owe the **Harrow & Vell Charter Company** 6,000 marks for their trip. Pay it all off and the colony is yours.

**Play it here: https://zephino.github.io/Lastborn_Colony/**

It runs in any modern browser, on a computer, phone or tablet. (Developers: see `DEVELOPERS.md`.)

---

## How you win and lose

| Ending | How it happens |
| --- | --- |
| **Free colony** (win) | You pay off the whole debt. Fewer turns is a better score. |
| **Taken by the Company** (lose) | You miss three Company payments in a row and the Company takes over. |
| **Went silent** (lose) | Everyone dies. |
| **Independence** or **Company Town** | Story endings: the colony breaks away, or is signed over to the Company. Both are ranked by how much debt you paid. |

Payments start on **turn 30** and come every **10 turns**, each a little bigger than the last. The top bar always shows the next one.

---

## Before you land

1. **Briefing.** Read the story so far.
2. **Pick a planet.**
   - **Brume** (Standard): ice, vents and sunlight all within reach. Start here.
   - **Cinder** (Harder): bright and hot, but ice is rare.
   - **Hollow** (Hardest): icy and full of vents, but the sun is weak.
3. **Send probes (optional).** Your ship carries **3 scouting probes**. Under each planet, **Send a probe** lets you pick a landing site and land a probe there. Its report shows:
   - a picture of the ground around the site;
   - how much sunlight and cold there is;
   - the ice, vents and ore nearby, and what's in the Deep below;
   - how often grit storms and icequakes hit;
   - any **lucky find**: a crashed wreck (25 alloy and 5 parts), a supply cache (40 food and 40 oxygen) or a rich ore seam beside the pad.
   Then choose **Settle here** or **Look elsewhere**. About half the sites have a lucky find, and you get it whether you scouted the site or not; probing just lets you know.
4. **Pick a difficulty.** Easy has a smaller debt, gentler payments, fewer disasters and no plague. Hard has a bigger debt, steeper payments, more disasters, faster wear and more crime.
5. **Pack the ship.** You have 10 cargo bays: colonists, alloy, food, oxygen, water, starting money, prefab buildings, supply pods or survey probes (2 extra scouting probes). Everything is bought on credit, so each bay adds to your debt. **Recommended load** is a good balanced start.
6. **Pick a landing site.** Sites you've scouted show everything. The others show only a rough outline until you send a probe (you can still send one from here if you have any left).

---

## Your first 30 turns, step by step

You start with a **Landing Pad**, 30 settlers and some alloy. Alloy is what you build with.

1. **Build a Shaft** next to the Landing Pad. It takes 3 turns and opens the **Deep**, the cave level underneath. Your homes, food and air all go down there.
2. **Make power and heat on the surface.** Put **Solar Arrays** toward the sunny side for power. Put a **Vent Tap** on an orange vent for heat.
3. **Get water.** Put an **Ice Drill** on ice.
4. **Go down.** Press **Deep** (or **E**). Build out from the bottom of the Shaft:
   - a **Splitter** turns water into oxygen;
   - a **Kelp Vat** grows food;
   - **Bunkhouses** house 12 people each.
5. **Start making money before turn 30.** Put a **Seam Cutter** on an ore seam (teal streaks) to dig ore. A **Forge** turns ore into alloy. A **Spin Launcher** sells alloy for marks. Then pay the Company on time.
6. **Press End turn** (or **Enter**) and watch the top bar. If something turns red, open the **Colony report** to see why.

Use **Tunnels** (1 alloy each) to reach further out on either level.

---

## The screen

| Part | What it shows |
| --- | --- |
| **Top bar** | People, morale, power, heat, idle workers, food, oxygen, water, ore, alloy, parts, marks, debt and the next payment. |
| **Left list** | Every building you can build, with its price. Grey ones can't be afforded yet or need research. **Surface** and **Deep** switch levels. |
| **Map** | Your colony, seen at an angle. Click a tile to inspect it. Drag to move, scroll or pinch to zoom. |
| **Right panel** | Details on what you selected, plus **Research**, **Drones & orbit**, and the **Company account** (pay early, set your export reserve). |
| **Bottom** | News from the last turn, **End turn**, **Run 5 turns**, **Colony report**, **Save** and **Menu**. |

On a phone the map gets the whole screen. **Build**, **Info**, **Research** and **Company** buttons open what the side panels show on a computer.

---

## How the colony works

### Every turn

- Each building needs its **workers**, **power** and **heat**. Generators go first; then buildings are supplied in order: water, oxygen and food, housing, ore, alloy, selling, then civic buildings.
- A building that can't get everything sits **idle** with a red dot. Select it to see why.
- Each person eats and breathes every turn. Running out of **oxygen** kills fastest, then food and water.

### Light and cold

The map runs from frozen night on one side to blazing day on the other. **Solar Arrays** make more power on the sunny side. Buildings need **more heat** on the cold side. Ice and vents are mostly on the cold side, so you're always balancing the two. Select a tile to see its light and heat factor.

### Ground

- **Ice Drills** go on ice, **Vent Taps** on vents (orange) and **Seam Cutters** on ore seams (teal streaks).
- Ridges, deep ice and scorched ground can't be built on.

### Doors and tunnels

Buildings join with tunnels only where their **doors** meet.

- **Hubs** (Landing Pad, Shaft, Bunkhouse, Commons, Clinic, Academy, Lounge, Garden Cavern) have **4 doors**.
- **Workplaces** have **2 doors**, on opposite sides.
- **Outlying machines** (Solar Array, Vent Tap, Ice Drill, Seam Cutter, Spin Launcher, Radio Station, Beam Catcher, Drone Bay, Fusion Core, Hazard Lab) have **1 door**.
- **Tunnels** join on every side.

A new building needs a door facing a door or a Tunnel. It turns itself to fit; press **R** or **Rotate** to turn it yourself. Don't wall in your Tunnels: leave them a free side so you can keep growing.

### The surface and the Deep

The **Shaft** is a lift tube down to the Deep. When it's finished, a landing opens below it and the area around the landing is already cleared.

| Level | Buildings |
| --- | --- |
| **Surface only** | Solar Array, Battery Bank, Beam Catcher, Spin Launcher, Radio Station, Forge, Fab Shop, Drone Bay, Fusion Core, Reclaimer, Cache, Workshop, Rescue Station, Trading Post |
| **Deep only** | Bunkhouse, Commons, Clinic, Warden Post, Lounge, Garden Cavern, Academy, Schoolhouse, Survey Lab, Hazard Lab, Kelp Vat, Mushroom Farm, Splitter, Water Recycler |
| **Either** | Tunnel, Ice Drill, Vent Tap, Seam Cutter, Heat Store |

The build menu says "Surface only" or "Deep only" on each building.

In the Deep:
- Open cave floor costs the normal price. Solid rock must be dug out first: +4 alloy and +2 turns (only +1 alloy for a Tunnel). Bedrock can't be dug.
- **Ore veins** make Seam Cutters 50% better. **Deep vents** give Vent Taps 50% more heat. **Underground water** lets Ice Drills work below.
- Buildings need only a little heat, and icequakes never reach them.
- The caves are dark except where your colony's lamps reach.

### Morale

Morale sets how hard everyone works (50% to 130%). Commons, Clinics, Lounges, Garden Caverns, Schoolhouses, Radio Stations and relay satellites raise it. Shortages, crowding, waste and missed payments lower it. Below 20, people start leaving.

### Money

- **Seam Cutter** digs ore, then the **Forge** turns ore into alloy, then the **Spin Launcher** sells up to 4 alloy a turn for marks.
- The **export reserve** (right panel) is how much alloy the Spin Launcher always keeps back for building.
- You can **pay early** from the Company account panel.
- A **Trading Post** sells spare food, water and parts too (up to 5 of each a turn), keeping a safe reserve. Its prices rise and fall over time; the building's info shows today's prices.

### Saving power and heat

Power and heat you don't use are normally lost at the end of a turn. A **Battery Bank** saves up to 15 spare power, and a **Heat Store** up to 10 spare heat, for the next turn. They're a good way through grit storms and cold spells. The Colony report shows what was saved and used.

---

## Buildings

| Building | Level | Cost (alloy) | What it does |
| --- | --- | --- | --- |
| Tunnel | Either | 1 | Joins buildings and extends your network. |
| Shaft | Surface | 15 | Lift down to the Deep. |
| Solar Array | Surface | 6 | Power from sunlight. |
| Vent Tap | Either | 10 | Lots of steady heat. Must sit on a vent. |
| Ice Drill | Either | 6 | Water. Must sit on ice or underground water. |
| Splitter | Deep | 10 | Turns water into oxygen. |
| Kelp Vat | Deep | 8 | Food. Needs plenty of heat. |
| Bunkhouse | Deep | 8 | Homes for 12. |
| Seam Cutter | Either | 8 | Ore. Must sit on an ore seam or vein. |
| Forge | Surface | 12 | Ore into alloy. |
| Spin Launcher | Surface | 24 | Sells alloy; launches satellites. |
| Cache | Surface | 5 | +300 storage of each resource. |
| Commons | Deep | 10 | Raises morale. |
| Clinic | Deep | 14 | Halves deaths, raises morale a little. |
| Survey Lab | Deep | 14 | Research. |
| Workshop | Surface | 10 | Faster repairs. |
| Warden Post | Deep | 8 | Holds crime down. |
| Reclaimer | Surface | 10 | Recycles waste into a little ore and water. |
| Fab Shop | Surface | 14 | Alloy into parts. |
| Drone Bay | Surface | 12 | Builds and runs up to 4 drones. |
| Radio Station | Surface | 8 | News and music from home: a little morale, and sells alloy for 1 more mark. |
| Rescue Station | Surface | 12 | Disasters damage half as many buildings. |
| Academy | Deep | 16 | Trains specialists who work better. |
| Hazard Lab | Deep | 18 | Triple research, but lowers morale and breaks often. |
| Garden Cavern | Deep | 14 | Big morale boost, a little food. |
| Lounge | Deep | 10 | Big morale boost; costs 3 marks a turn and raises crime. |
| Beam Catcher | Surface | 16 + parts | Receives power from power satellites. Needs research. |
| Fusion Core | Surface | 40 + parts | Huge power day and night, plus some heat. Needs research. |
| Battery Bank | Surface | 10 | Saves up to 15 spare power for the next turn. |
| Heat Store | Either | 10 | Saves up to 10 spare heat for the next turn. |
| Mushroom Farm | Deep | 8 | Food that needs very little heat: 1 water makes 5 food. |
| Water Recycler | Deep | 12 | Everyone needs 25% less water (two count at most). |
| Trading Post | Surface | 14 | Sells spare food, water and parts for marks. |
| Schoolhouse | Deep | 12 | Children who grow up there become trained specialists; a little morale. |

---

## Drones, satellites and parts

- **Parts** come from a **Fab Shop**. Drones, satellites and the most advanced buildings need parts as well as alloy.
- **Drones** (Drones & orbit button) need a working **Drone Bay**: each runs up to 4.
  - **Grader:** speeds up one surface building under construction.
  - **Borer:** speeds up the Shaft or a Deep building, and makes digging rock free.
  - **Prospector:** brings back 2 ore a turn.
  - **Hauler:** makes your Seam Cutters dig more, and carries ore up the lift.
  - **Sweeper:** in a grit storm, keeps 4 Solar Arrays clean so they lose much less power.
  - **Mechanic:** takes one more turn off a repair each turn.
  - **Medic:** an ambulance rover; 10% fewer deaths each (30% at most).
  - **Scout:** explores far away; sometimes brings back salvage (8 alloy and 2 parts).
- **Satellites** are launched from a working **Spin Launcher**.
  - **Weather:** grit storms hurt solar panels less, and icequakes reach less far.
  - **Relay:** +3 morale.
  - **Power** (after research): beams 10 power to a Beam Catcher.
  - **Survey:** maps the ground from orbit; Seam Cutters and Ice Drills make 10% more.
- **Supply pods** packed before landing wait on the ship. Call one down any time for alloy, food and oxygen.

---

## Dangers

- **Events:** grit storms, vent surges, broken seals, icequakes, stowaways, auditors and offers. Some ask you to choose.
- **Breakdowns:** machines wear out. Workshops and Mechanic rovers speed up repairs.
- **Crime** grows with crowding and low morale. It steals and lowers morale. Warden Posts hold it down.
- **Plague** can break out in a big colony (not on Easy). Survey Labs must research a cure in time.
- **Waste** builds up. Too much lowers morale and spreads plague. Reclaimers clear it.
- **Old age:** children grow up, adults grow old. Elders don't work. Clinics help everyone live longer.

---

## People, factions and story

- The **Company** and the **Crews' Union** each like you from 0 to 100.
  - Paying on time pleases the Company: it softens penalties and sends extra settlers.
  - Shortages anger the Union. A happy Union lifts morale; a very unhappy one goes on strike.
- **Story events** arrive as the colony grows and ask you to choose. Some choices matter later.
- **Research:** pick a topic and your labs work on it. Finished topics improve buildings, housing and sales, or cut breakdowns, plague and crime. Some unlock new buildings.

---

## Controls

| Action | Computer | Phone or tablet |
| --- | --- | --- |
| Build | Pick a building on the left, click a tile | **Build**, pick one, tap a tile |
| Turn a building | **R** or **Rotate** | **Rotate** |
| Cancel | **Esc** or **Cancel** | **Cancel** |
| Move the map | Drag, arrow keys or WASD | Drag with one finger |
| Zoom | Mouse wheel | Pinch, or **−** and **+** |
| Surface / Deep | **Q** / **E**, or the buttons | **Deep** / **Surface** button |
| End turn | **Enter** or **End turn** | **End turn** |

Dragging the map never builds anything by accident.

---

## Saving, settings and online

- **Saving:** the game autosaves every 10 turns. **Save** keeps a manual save. On the web, saves stay in that browser on that device.
- **How to play** (title screen or Menu): a short illustrated guide.
- **Settings:** fullscreen, **Install app** (Chrome, Edge, Android) and **Update app**. On iPhone or iPad: **Share**, then **Add to Home Screen**.
- **Updates:** for 30 seconds after opening, the game checks for a newer version and switches to it. Your saves are kept.
- **Leaderboard** (title screen): one for each planet and difficulty. Type your name on the title screen, then post a score when a colony ends, or **Menu → Retire** to post one that's still running.
- **Sign in with Google** (Settings, optional): keep one cloud save and carry on from another device.
- **Suggest a feature** (title screen): send an idea or a bug report. It becomes a public issue, so don't include private details.

---

## Tips

- **Build the Shaft first.** Homes, food and air all live in the Deep.
- **Don't run out of oxygen.** It kills fastest. Build a second Splitter early.
- **Get money coming in before turn 30.** Seam Cutter, then Forge, then Spin Launcher.
- **Keep Tunnels open.** Leave a free side on your tunnels so the network can grow.
- **Watch for red dots.** An idle building usually needs power, heat or workers.
- **Use Run 5 turns** when things are calm, and the **Colony report** when they're not.
- **On Hollow,** the sun is weak: lean on Vent Taps and deep vents for heat, and the Fusion Core for power.

---

Copyright (c) 2026 Zephino. All rights reserved. See `LICENSE` and `CREDITS.md`.
