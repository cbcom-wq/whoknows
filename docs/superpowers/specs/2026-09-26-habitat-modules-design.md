# Habitat modules: a base you print, plant and plug together

**Date:** 2026-09-26, revised 2026-10-08
**Status:** Designed with the owner. **Every decision in §2 was taken on 2026-10-08**, after a
review that brought the 2026-09-26 draft up to date with saving, NPCs, the bridge computer, star
systems, the warp, world scale, health and damage, and many ships (§18). Awaiting the owner's
review of this written spec. No plan exists and no code has changed.
**Depends on:** `main` at `2476498`, which has quantum energy's Tasks 1–8 (the store, the machine,
the suit cell, the near cloud), the asteroids' fixed big rocks (asteroids spec §18) in belts
(system skeleton §6), the airlock, the floating origin, saving (format 2), NPCs, health and
damage, and many ships (`Fleet`). **Phase D also needs quantum energy's hose and its line
(Task 9)**, not yet built: corridors reuse the line. A base's sensor contact needs its Task 10.
**Governed by:** `docs/design/visual-style.md`, and CLAUDE.md's rules on the floating origin and
on every ship being usable.
**Builds on:**
- the slice spec §3, the interior/exterior split and its slot grid;
- quantum energy §3 (the store), §4 (values), §7 (the machine), §9 (the suit cell), §11 (the hose)
  and §17 (mining, persistence, the shipyard's costs);
- the airlock spec §7 (the threshold);
- the bridge computer spec §4 (the ship's sensors);
- the saving spec §5 (calm), §7 (strays) and §8 (the file);
- the NPC foundation §6 (stimuli) and its skitters;
- health and damage §7.2 (downed);
- many ships §5 (`Fleet`: slots, sleeping, spawning);
- Planetfall §18, whose "outpost is a `ShipGrid` that never flies" this spec builds.

---

## 1. Why

The owner's idea, 2026-09-26:

> We have the quantum machine on the ship now which can make things. An idea I had is what if it
> could make like habitat modules that come out as a package but can expand on an outside surface.
> Different modules could have different abilities. They would also have doors with a type of
> expandable corridor that the user could pull and connect to other modules to connect them.
> Inside a module the network the user would not need a powered suit and would have artificial
> gravity. An example module is a ship builder module. So we start to see a game progression
> system. The player collects objects to turn into quantum energy, they convert that energy into
> things like these modules, that then allow them to harvest more energy or build better ships, or
> a multitude of other things.

What exists today:
- **QE has few ways in and several ways out.** You gather salvage, convert it at the machine, and
  spend it on boost, the warp (40 QE plus distance), the suit, being patched up after a blackout
  (50 QE) and making small items. Nothing you make earns you more QE, so the loop cannot grow.
- **The ship's store is capped at 1,200 QE** (three quantum cells) and starts at 600. Making only
  works at full power.
- **Big rocks live in belts** round the star (system skeleton §6). Within 4 km they are fixed in
  place and solid as drawn (asteroids §18): the only surfaces outside that stay put. The start is
  700 m off the first belt's first big rock.
- **Interior space is a grid of slots** 2 km apart (`Ship.SLOT_SPACING`), handed out by `Fleet`,
  at most 16.
- **Ships far off sleep** (`Fleet.SLEEP_AT` 20 km, `WAKE_AT` 18 km): a record, not nodes.
- **Saving keeps one game** (format 2): the ships, what's aboard, the suit, strays, salvage taken.
- **Skitters** live in herds on the big rocks' crater walls, and scatter at a `VIBRATION` or
  `SHAKE`.
- **The shipyard editor is not built** (Slice 1 Phase C, Tasks 16–20). It has no place in the
  world yet.

### 1.1 The pitch

You've been vacuuming salvage for an hour and the store is almost full. At the machine, ▶ steps
past the plasma pistol and the power cell to something new: *MAKE · HUB PACKAGE · COST 800 QE*.
You press it. The core's gauge drops almost to the amber bar, and a violet point in the bay swells
into a chunky cream case the size of a suitcase, strapped in terracotta.

You carry it aft, cycle out and fly down to the big rock off the bow. As you drift over the
surface, a ghost of the hub appears under you on its legs: coral over the crater rim, green on the
flat shelf beyond. You press *Plant*. The case lands and its seams split violet. Four legs stamp
into the rock, and a herd of skitters on the crater wall bolts. The hub levels, walls fold up round
it and its porthole lights come on, warm.

You cycle in through the hub's own little airlock. Your feet find the floor. It's quiet, the air
handler hums, and your suit's gauge stops mattering. Out of the porthole your ship hangs above
the rock, its running lights blinking.

Two trips later there's a drill module on the next shelf over. Outside, you unhook the corridor
collar from the hub's side door and fly it across to the drill's door. The accordion tube follows
you, snaps into place, stiffens and hisses. Inside, the hub's side door turns green. You walk
through a ribbed tube to the drill room, where a gauge reads *VEIN 1.8×*. It's chewing lavender
crystal out of the rock, a little QE at a time, whether you're there or not.

Far off, a fabricator and then a ship builder: a gantry on the rock where the shipyard runs, and
where the next ship is printed block by block from the base's store.

### 1.2 What this adds

- **Module packages:** items the machine makes. You carry one outside and plant it.
- **Planting:** on a fixed surface (a big rock, in this build), with a ghost that shows where the
  module fits. The module levels itself on legs and unfolds.
- **A base:** modules on one rock sharing one frame, one grid, one interior slot and one store.
  Inside a base you walk in gravity and your suit is idle, as aboard the ship.
- **Corridors:** accordion tubes you pull from a door port on a spacewalk and plug into another.
- **Modules that do things.** The first set is a hub, a drill, a store, a fabricator, a suit bay
  and a ship builder. §6 lists them and §7 how they unlock one another.
- **The universe clock:** play time, saved, which the drill earns against.

---

## 2. Decisions

All taken by the owner on 2026-10-08. Rows 1, 2 and 4–12 are the draft's recommendations,
accepted as written; rows 3, 13 and 14–17 were reopened or added by the review.

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | What the machine makes | **A module package: an item** like any other, with a value, made at twice its value (quantum energy §2, row 7). It fits the bay: 0.5 m, 30 kg. | The machine already makes anything with a value. A new kind joins the list by existing (QE §4.3). A package converted back returns half, like everything else. |
| 2 | Getting it outside | **You carry it out.** Packages are a new kind of **EVA cargo**, which Grasp lets past `suspended` as it does EVA tools. Carrying one makes the suit slower: 150 kg, not 120, so 2.0 m/s². | Hands-on and physical, like the hose. It gives a spacewalk a job and makes the trip to the rock part of building. |
| 3 | Where a module can stand | **On a big rock in this build, through a surface interface that planets join later** (§5.1). Big rocks are the only fixed surfaces outside today. | Phases A–D build on what is on `main`. At world scale a planet is 15–60 km in radius, nearly flat at a base's size, so a `PlanetSurface` slots in when Planetfall lands. |
| 4 | Uneven ground | **Levelling legs.** Each module stands on four legs that reach 0.3–2.5 m. A spot is good when every leg reaches the ground and nothing else touches it. | Big rocks are lumpy on purpose (craters, ledges, boulders). Legs turn "is it flat?" into "can the legs reach?", which is readable and forgiving. A strong Astroneer-style shape. |
| 5 | One base, one frame | **The first module, a hub, fixes the base's frame:** its up, its yaw and its 2 m grid. Every later module snaps to that grid, in quarter turns, within 24 m of the base. Its legs level it to the base's up. | One rigid frame makes the whole base one grid, like a ship: one interior slot, one gravity, and the ship's builders unchanged (§9). Corridors stay straight grid runs. |
| 6 | Starting a base | **Only a hub starts a base.** It holds the base's airlock. Any other module is planted within reach of an existing base. | Every base needs a way in. One rule: *plant a hub first*. |
| 7 | Corridors | **Pulled on a spacewalk.** A door port has a **collar**, an EVA tool on a line like the hose nozzle. Take it, fly to another port within 24 m and press *Connect*. The tube routes itself along the grid (§5.4), unfolds, stiffens and pressurizes. | The owner's "pull and connect", made physical. It reuses the hose's line and reel. |
| 8 | Inside a base | **Exactly as aboard the ship:** interior space, `PLATING` mode, gravity, hands free, the suit idle. No shoves, because a base never moves. | The owner's "no powered suit, artificial gravity". It is the ship's interior, which already works. |
| 9 | Where a base's QE lives | **The base has its own store.** The hub holds 400; store modules add capacity. **A quantum link** moves QE between the ship's store and the base's, both ways and without loss, from a panel in the hub, while the ship is within 1 km. | The base becomes a place you come back to ("the drill filled it while I was away"). Lossless transfer never punishes moving energy home. |
| 10 | What earns QE | **The drill.** It mines the rock under it, slowly and without you, more on a rich or veined rock. Its yield stays unknown until it has run for a minute (*who knows*). | "Harvest more energy." It uses the lavender veins, which already read as quantum ore (QE §14.3, §17), and makes a base's site a real choice. |
| 11 | How modules unlock | **By who can make them.** The ship's machine makes the small packages, a **fabricator** module the big ones, and the **store's capacity** gates the biggest. | A progression you can see and touch, with no tech tree or menus. |
| 12 | Moving a module | **Pack it up** from a panel inside it, when it has no corridors and nothing in its bays. You get the package back at full value. | Mistakes in placement shouldn't cost QE. |
| 13 | Saving | **A base saves as its `BaseSite`,** per system, in save format 3 (§11). | Saving exists. A progression you lose on quitting isn't one. |
| 14 | What time the drill earns in | **Play time only:** the universe clock (§9.4). The drill earns while the game runs, wherever you are, warps included; nothing while it is closed. | Matches the strays rule (saving §7.1): nothing moves while the game is closed. No bonus for not playing, no cheating by the system clock. |
| 15 | A package left outside | **It is a stray like anything else** (saving §7): forgotten after 10 minutes spent more than 5 km away. Downed while carrying one, you drop it where you fell. | The owner: "the player needs to be careful not to lose these." Carrying an 800 QE case through space is meant to carry risk. |
| 16 | The fabricator's cost | **1,200 QE, the starter's whole store.** Made at the ship's machine, it leaves the ship in low power; the base's store, over the link, is the way back (§4.2). | Saving up for it is the first real goal. Rushing it before the base holds QE costs you, and the machine's *→ LOW POWER* warning says so. |
| 17 | Skitters and bases | **A base is part of the rock to them.** Planting stamps a `VIBRATION` that scatters nearby herds; a working drill gives off a faint, constant one that drifts their rounds away from it (§8.4). | Needs no new behaviour, only two stimulus sources. A base slowly quietens its rock: a cost you notice. |

### 2.1 Open beyond §2

- **The ship builder's shape** (§6.5). This spec gives it a place, a cost, a size and a launch. Its
  editor is the slice's Phase C (Tasks 16–20), in a spec of its own after the base.
- **Docking.** A dock module the ship berths against, so you walk from ship to base with no
  spacewalk: the slice spec's §3.1 stitching, and docking's own spec (many ships §11).
- **The pillar.** "Ships are taken, not bought" (slice spec §1). The ship builder is where you
  *build* and refit ships from blocks, with QE. Nothing here sells a ship.

---

## 3. The loop

```
      gather (hose, salvage)            convert (machine)
  ┌──────────────────────────► items ─────────────────► ship store ──┬──► warp, boost, suit,
  │                                                        │  link   │    patching you up
  │                                                        ▼         │ make
  │   drill ──── QE in play time ──────────────────────► base store  ▼
  │     ▲                                                  │       packages
  │     └──────────────────────────────────────── modules ◄┴─────────┘ plant
  │                                                  │
  └──────────── better ships (ship builder), bigger stores, faster suit ◄┘
```

- **Early:** the starter's cargo, converted, plus a few salvage groups buys a hub. Saving 800 for it
  competes with warps, and that is intended: a hub is a choice to stay. The exact path is measured
  in Phase B's probe (§12.2) against the cargo then aboard, not guessed here.
- **Middle:** a drill and a store make the base earn and hold QE. The fabricator unlocks the big
  modules.
- **Late:** the ship builder spends the base's store on blocks. Stronger ships reach further, and
  later other systems.

**Every number here is a first guess**, a constant in one place (`HabitatValues`), tuned at
playtest, as quantum energy's are (QE §19).

---

## 4. Packages

### 4.1 The item

- **One item kind per module:** `hub_package`, `drill_package`, and so on. Each is a `.tres` with a
  value, and with a new `module` field naming the module it unfolds into.
- **They all look the same, bar a stripe.** A bevelled case 0.5 × 0.35 × 0.5 m in `TRIM`, with two
  terracotta `BELT` straps, a carrying handle and a violet seam. The module's colour goes on a
  band across the lid, from a new `ModuleColours` table in `InteriorPalette` (a palette entry,
  not a rule change).
- **30 kg, CARRY.** It fits the bay (largest side 0.5 ≤ 0.55 m; under the 40 kg lift limit).
- **EVA cargo** (`ItemDefinition.eva_cargo`): Grasp lets it past `suspended` on a spacewalk, as it
  lets EVA tools. Unlike an EVA tool, it is made and converted like any other item.
- **Carrying it outside** adds its mass to the suit's: acceleration becomes
  `2.5 × 120 / (120 + 30)` = 2.0 m/s². The suit cell still pays for its Δv.
- **Letting go outside** leaves it floating where it is, as salvage does. It joins
  `Universe.EXTERIOR_SPACE` and glints.
- **A package left adrift is at risk.** It is a stray (`StrayLedger.adopt`): forgotten for good
  after 10 minutes spent more than 5 km from it (saving §7.1). If you are downed while carrying one,
  it drops where you fell (health and damage §7.2) and the suit takes you home without it. Nothing
  warns you beyond the glint and the stray rule itself: losing one is the player's lesson.

### 4.2 Costs

| Module | Made at | Package value | Make cost | Footprint (cells) |
|---|---|---|---|---|
| Hub | the ship's machine | 400 | 800 | 2 × 2 |
| Drill | the ship's machine | 300 | 600 | 1 × 2 |
| Store | the ship's machine | 250 | 500 | 1 × 1 |
| Fabricator | the ship's machine | 600 | 1,200 | 2 × 2 |
| Suit bay | the fabricator | 400 | 800 | 1 × 2 |
| Ship builder | the fabricator | 2,000 | 4,000 | 2 × 3 control room, and a gantry (§6.5) |

- **The hub costs 800,** two thirds of a full starter store.
- **The fabricator costs the whole of the starter's store** (1,200). It needs the store brim full,
  and making it takes the ship to 0 and into low power: half authority, no boost, no warp, no
  making, until the pilot light brings it to 25. **The way back is the base's store**, over the
  link (§6.1). Make it once a drill and a store have filled the base; rush it and you wait on the
  pilot light. The machine's amber *→ LOW POWER* warning (QE §7.2) covers the moment, and nothing
  else stops you.
- **The ship builder costs 4,000,** more than any ship holds. It is made only at the fabricator,
  from the base's store, once store modules have raised its capacity (§6.3). That is the gate.

---

## 5. Planting and corridors

### 5.1 The surface

Planting never sees a rock. It asks a **`PlantSurface`**:

| Method | Answers |
|---|---|
| `up_at(point) -> Vector3` | the surface's up at a point: a big rock's averaged normal there; later, a planet's radial up |
| `cast(from, dir, reach) -> Dictionary` | the ground along a ray: hit point and normal, or nothing |
| `fixed() -> bool` | whether it never moves. Only fixed surfaces take a base |
| `site_id() -> StringName` | the rock (or later the world) the base belongs to, as `RockHerds.site_of()` names it |

- **`RockSurface`** implements it for a big rock in detail. A rock not in detail offers no surface,
  so no ghost shows past 4 km, which is far beyond the ghost's 8 m reach anyway.
- **`PlanetSurface`** is Planetfall's to add (§15). Nothing in `Planting` or `CorridorRoute`
  changes when it does.

### 5.2 The ghost

On a spacewalk, holding a package, you see a ghost of the module wherever you look at a surface
within 8 m:
- **The body at its levelled height, with its legs reaching down to the ground**, in a flat,
  translucent colour: `SIGNAL_GO` where it fits and `CORAL` where it doesn't. It is drawn in an
  unshaded `StandardMaterial3D`, which adds no shader.
- **Near a base, the ghost snaps** to the base's grid, in quarter turns (Q/E turn it). Far from
  any base, only a hub shows a ghost, turned to face you.
- **The prompt says what's wrong:**

  | Prompt | When |
  |---|---|
  | *Plant Hub* | it fits |
  | *Too steep* | the base's up (or, for a new hub, the surface's) is more than 25° off the surface's average normal |
  | *Legs can't reach* | a leg needs more than 2.5 m, or less than 0.3 m |
  | *Blocked* | the body touches the ground, a boulder, another module or a corridor |
  | *Too far from the base* | not a hub, and more than 24 m from every module of the base |
  | *Plant a hub first* | not a hub, and no base on this surface |
  | *Too close to a ship* | within 20 m of any ship's hull |

- **The test is a few shape queries**, run at 10 Hz while you aim: a box for the body, and a ray
  down for each leg.

### 5.3 Unfolding

Press `use` with a green ghost:
1. **The case flies to the spot** over 0.6 s and settles (0.4 s).
2. **The seams split violet**, and the legs punch down to the ground and level the body (1.0 s).
   The stamp gives off a `VIBRATION` through the rock (§8.4).
3. **The walls and roof fold up** from the case in three chunky stages: each a panel turned
   about its hinge, animated by transform so no shared material changes (2.0 s).
4. **The lights come on** cell by cell, as when power returns on the ship (QE §8.3), with a
   soft `unfold` sound (1.5 s).

About 5.5 s in all. The package is consumed at step 1, and the base is changed at step 4. Nothing
can interrupt it, and the save gate waits for it (§11.2).

### 5.4 Corridors

**Every module has door ports:** a round hatch on a face of the grid, with a **collar** on its
outside face. The hub has three, and the other modules one or two (§6).

**Pulling one:**
1. On a spacewalk, take the collar from a port (*Take Corridor collar*). It is an EVA tool on a
   line from its port, drawn and simulated as the hose line is (`HoseLine`, 24 m).
2. Fly toward another port. Within 3 m of a free port, a ghost shows the tube's route: at most
   two bends, along the base's grid, and level. The ghost is `CORAL` when the route is blocked by
   the ground or by a module.
3. Press `use`: *Connect*. The collar flies to the far port, the tube unfolds along the route like
   an accordion (1.5 s), stiffens, and struts drop from it to the ground where it runs more than
   1 m above the surface. It hisses as it pressurizes (1.2 s).
4. Inside, both ports' doors turn from `CORAL` to `SIGNAL_GO`. Opening them is a button press, as
   with a room's door.

**The route** is found on the grid by a small breadth-first search from port to port. It prefers
the fewest bends, and never goes through a module or the ground. Two ports on different storeys
are joined by a **ramp section**, one storey over three cells, as the route's middle leg.

**Letting go** of the collar anywhere else winds it home along its line, like the hose nozzle.

**Retracting** a corridor: from the panel beside either door, inside, while nobody is in it and
nothing loose lies in it. It folds back into its first port.

### 5.5 Leaving and coming back

- **Every base has one way in:** the hub's airlock. It is the ship's airlock block (`Airlock`,
  `AirlockSite`), dressed and cycled exactly as the ship's is (the airlock spec). The threshold
  maths use the base's transform in place of the hull's. A base's velocity is always zero.
- **The suit's home is the nearest awake ship or base.** Many ships made the suit belong to the
  nearest ship (many ships §2, row 3); this widens it to anything with an airlock and a frame.
  Relative speed, the assist and the airlock all follow that home.
- **Entering a base is boarding it.** `board(ship)` is the one place the space you are in changes
  (many ships §4); it widens to take a base. Inside a base, the base is what you are aboard: the
  universe's focus, the one that never sleeps, and the store the HUD and a blackout use. Whether
  that is a common `Home` that `Ship` and `Base` both are, or `board` taking either, is the plan's
  to settle.
- **A marker home.** On a spacewalk, `AirlockMarker` marks the nearest ship's airlock and the
  nearest base's, each with its distance.

---

## 6. The modules

Each module is a small **grid of blocks**, a prefab (`ModuleDefinition`), which is copied into
the base's grid when it is planted (§9.1). Room blocks already dress themselves (interior
redesign §7), so a module's inside is furnished the same way a ship's rooms are.

### 6.1 Hub

- **2 × 2 cells:** the airlock in one corner, a small deck in the others, and three door ports.
- **A quantum terminal** against a wall: the machine's bay and charge plate without making, so you
  can convert and charge your suit (QE §7.1, §7.3). It shares `MachineCycle`, with making turned
  off.
- **The link panel** (§2, row 9): *SHIP 640 · BASE 120*, with ◀ and ▶ to move QE in 50s, and a
  hold to move it continuously. It reads *NO LINK* when no ship is within 1 km; with several, it
  links the nearest.
- **A small store** of 400 QE, and a small core behind a grille for light and gravity. The core
  gives no thrust, so it has no power figure to balance.
- **Where you wake** if you are downed inside the base: beside the hub's core (§11.3).

### 6.2 Drill

- **1 × 2 cells:** a control room with a porthole down onto the drill head, and one port.
- **What it does:** it mines the rock under it into the base's store.
  - base rate: **1 QE per 10 s** of play time (6 per minute, 360 per hour);
  - times the rock's **richness**, seeded per big rock, from 0.5 to 3.0, and doubled on a veined
    rock.
- **Who knows:** for its first minute of running the drill's gauge reads *SURVEYING*. Then it shows
  the richness: *VEIN 1.8×*. You don't know how good a site is until you've paid for a drill on it.
- **Earning by the clock** (§9.4): the base credits `rate × (clock − last_credit)`, capped by the
  store's free capacity, every few seconds while awake and once on waking. A base far away and
  asleep therefore earns as if you were there; a closed game earns nothing. You come back to a full
  store, not an endless one.
- **It hums through the rock** (§8.4).
- **The look:** a drill head through the floor, turning, in `TRIM` and `COPPER`, a lavender glow
  where it bites, and a chunky derrick on the roof.

### 6.3 Store

- **1 × 1 cell:** a quantum cell (the ship's block) in a room of its own, glowing through a
  grille, and one port.
- **+1,000 QE of capacity** for the base's store.
- **The low-power line** is the ship's rule: 10% of capacity. Below it the base drops into
  emergency light, and making is off. Drills, the link and the airlock still work.

### 6.4 Fabricator

- **2 × 2 cells:** a machine too big for the ship. Its bay is a floor pad 1.6 m across, with a
  field ring above it.
- **It makes the big packages** (§4.2), and later the big things: ship blocks, droids, large
  equipment.
- **It works exactly like the ship's machine** (`MachineCycle`, making at twice the value, only at
  full power), but draws on the **base's** store.
- **Converting at the pad** takes things too big for the ship's bay: up to 1.5 m across and
  400 kg. (Getting a big thing into the base is §15's problem: a cargo door.)

### 6.5 Ship builder

**Its own spec** (§2.1). What this one fixes:
- **A control room** (2 × 3 cells) with the shipyard's console. That console is where the slice's
  Phase C editor runs: block placement, the deck slicer, live stats and validation, save and load
  (slice spec §8).
- **A gantry** beside it on the rock: an open frame of chunky trusses, 12 × 10 × 24 m, holding a
  cradle. **The ship being built stands in the cradle,** and you see it through the control
  room's windows.
- **Blocks cost QE** from the base's store as they are printed into the cradle. The block
  catalogue gains a `quantum_value` (QE §17: "blocks cost QE to build or mend"). Removing a block
  refunds its full value, because it is the same block, not a conversion.
- **Launch is `fleet.spawn(grid, cradle_place)`.** The printed ship is a ship like any other from
  its first second: boardable, flyable and saved (CLAUDE.md, *Every ship is usable*). It takes a
  slot from the shared pool (§9.3), so a full pool refuses the launch with *NO BERTH FREE*.
- **Refitting** a ship you already have (and later, one you've captured) means flying it into the
  cradle.

### 6.6 Suit bay

- **1 × 2 cells:** a rack you back into.
- **Suit upgrades,** bought with the base's QE: a larger suit cell, stronger thrusters
  (2.5 → 3.5 m/s²), and later a longer hose.
- **The suit charges here for free** from the base's store.

### 6.7 Later modules (hooks, not designed)

| Module | What it would do |
|---|---|
| Sensor mast | The base becomes a sensor source (bridge computer §4.2): salvage pings from 20 km, not 10. |
| Refinery | Rubble rocks fed through a cargo door, converted at a better rate. |
| Quarters | Bunks: where you wake when downed in the base, and later where you're remade. |
| Greenhouse | Life support, once the suit drains (QE §17). |
| Dock | Your ship berths against it: walk in, no spacewalk (slice spec §3.1). |
| Beacon | A warp target, and later a jump target. |
| Turret | Defence, when there is something to defend against. |

---

## 7. How the modules unlock

```
 ship's machine ──► Hub ──► (a base exists)
        │                ├─► Drill ────► earns QE
        │                ├─► Store ────► holds QE (raises the base's capacity)
        │                └─► Fabricator ─► Suit bay
        │                                └─► Ship builder (needs store ≥ 4,000)
        └─ everything already in QE §4.2
```

- **The machine's list grows by existing,** as it does today (QE §4.3). The hub package simply
  appears among the other things it can make.
- **A package you can't place yet** can still be made. Its prompt tells you why not
  (*Plant a hub first*).
- **Nothing is hidden.** The fabricator's list shows everything it can make, with costs you
  can't yet afford reading *NOT ENOUGH QE*, so you can see what you're saving for.

---

## 8. The look, the sound, the wildlife

**Stylized, warm and dim**, like the ship (style guide §1). A base is chunky, bevelled and
friendly: Astroneer's charm, a little more serious.

### 8.1 Outside

- **Modules** are rounded drums and capsules round their cells, not box hulls: bevelled cylinders
  with flat ends, plated in the hull's livery material as the airlock's hatch face is, with
  chunky `PANEL_LINE` ribs. The module's colour band from its package runs round it.
- **Legs:** four chunky telescoping struts in `TRIM`, with round pads on the ground.
- **Portholes** show warm light from inside. From a few kilometres off, a base is a cluster of
  warm points on a grey rock, which is how you find home.
- **Corridors:** a ribbed accordion tube, with rings every 0.5 m, in `TRIM`, with a `BELT` band at
  each end.
- **Colours** come from `HullPalette` for the body and legs, and `InteriorPalette` for the light
  seen through the portholes. The props that build modules are grid-blind and built from frames,
  as the ship's are (style guide §3).

### 8.2 Inside

- **The ship's interior, unchanged:** the same kit, palette, lights, doors, walls and floors. A
  module's floor colour says what it is, as a room's does (style guide §2.2): a new
  `ROOM_FLOOR` entry per module.
- **Corridors inside:** a round-ish tube 2 m across, ribbed, with a flat floor, lit by a warm
  strip every 2 m. Walking through one should feel like crossing between buildings.
- **Portholes** show the real outside (style guide §2.7): the rock's surface close by, your ship
  above.

### 8.3 Style rules this touches

- **No new shader.** The ghost uses an unshaded `StandardMaterial3D`, and the unfolding animates
  transforms. The shader budget stays three.
- **New palette entries** (`ModuleColours`, `ROOM_FLOOR` entries, any `HullPalette` additions)
  are not rule changes.
- **Rule changes that need the owner's approval:** none foreseen. If renders suggest modules want
  their own palette (a `BasePalette`), that is a rule change, and `test_visual_style_rules.gd`
  changes with the guide.

### 8.4 Skitters

A base is part of the rock to the herds (§2, row 17). No new behaviour, need or sense:
- **`SurfaceCrawler` walks round a base** as it walks round a boulder: the base's static body is on
  the rock's collision layer.
- **Planting stamps:** at step 2 of unfolding (§5.3), a `Stimulus.VIBRATION` at the hub's centre,
  strength 1.0, radius 60 m, on the rock's site (`RockHerds.site_of()`). Herds within reach scatter
  as they do at any other vibration.
- **A working drill hums:** a `VIBRATION` of strength 0.2, radius 80 m, renewed every few seconds
  while it runs and the base is awake. It is below the startle threshold, so herds don't bolt, but
  their rounds drift away from it over time. A rock with a busy base slowly empties of skitters.
- **The `building-an-npc` skill** gains *bases give off vibration* in its reference and checklist,
  in the same branch (CLAUDE.md).

### 8.5 Sound

New `Synth` builders: `unfold` (clunks and a rising shimmer), `leg_stamp`, `tube_extend` (a
ratcheting accordion), `tube_seal` (a hiss), `drill_hum` (a low grinding loop, quieter than the
air handler).

---

## 9. Architecture

### 9.1 A base is a grid that doesn't fly

A ship is one `ShipGrid`, and everything else is built from it (the building-a-ship skill). **A
base is the same:** a `ShipGrid` in the base's frame, a union of its modules' prefabs and its
corridors' cells. Planetfall §18 sketched the same outpost.

```
                   BaseGrid (a ShipGrid)  ◄── planting copies a module's prefab in
                   the single source of truth   corridors add tube and ramp cells
                          │
            ┌─────────────┴─────────────┐
            │                           │
   EXTERIOR: StaticBody3D           INTERIOR: in a shared slot, never moves
   under Outside, a member of       InteriorBuilder + InteriorDressing,
   Universe.EXTERIOR_SPACE          unchanged; gravity, no shoves
   BaseExterior: pods, legs,        airlock, doors, rooms, portholes
   tubes, struts
```

- **`Base`** (a `Node3D`, beside the ships): owns the grid, the exterior, the interior and a
  `QuantumPlant` of its own. It has no `FlightComputer`, no RCS and no `MotionCoupling`.
- **What `Base` shares with `Ship`** is extracted, not copied: building the interior from the grid,
  the portals, and the airlock wiring. A small `GridInterior` holds it, and `Ship` uses it too.
  This extraction comes first, as a refactor with no behaviour change (Phase A).
- **`BaseValidator`:** the ship validator's structural rules (connectivity, reachability on foot,
  the airlock's one face to space), and none of its flight rules (a helm, thrust, balance).
- **`BaseSite`** (pure): the base's frame as a `UniversePoint` and a basis, its surface's site id,
  its modules and corridors, its store, the drill's last credit and survey state. It is what is
  saved, and all a sleeping base is.
- **`Planting`** (pure): from a `PlantSurface` and a module's footprint, it gives the prompt of §5.2
  and the leg lengths. Tested headless with built surfaces.
- **`CorridorRoute`** (pure): the grid search of §5.4.
- **`HabitatValues`:** every number in this spec.
- **`Bases`** (a `Node` under `Outside`): every base in the session, keyed by id, sleeping and
  waking them (§9.3).

### 9.2 The floating origin

- **A base's exterior is one node, a member of `Universe.EXTERIOR_SPACE`,** whose parent never
  moves. Its pods, legs and tubes are its children, never members themselves (CLAUDE.md).
- **Its position is a `UniversePoint`** in `BaseSite`, never an engine `Vector3`.
- **A sleeping base has no nodes**, so it is in no group: the same exception CLAUDE.md makes for a
  ship asleep, and `test_floating_origin_scene.gd` treats it the same way.
- **A package floating outside** is a stray in the `StrayField`, which already covers it. The
  collar's line is a member with its points in its own frame, as the hose line is.
- **The base's interior** is in interior space and never moves.
- `test_floating_origin_scene.gd` walks the scene with a base awake, a corridor half pulled, and a
  package floating.

### 9.3 Interior slots and sleeping

- **One pool of slots for ships and bases.** `Fleet._free_slot()` moves into a small
  `InteriorSlots` allocator that `Fleet` and `Bases` both ask: `claim() -> int`, `release(slot)`,
  and the cap of 16 (slot 15 is 30 km out, where a float still holds about 2 mm). Slot 0 stays the
  starter's. A full pool refuses a new ship (*NO BERTH FREE*, §6.5) and a new base (*NO ROOM*, the
  ghost's prompt).
- **Bases sleep as ships do:** asleep past `Fleet.SLEEP_AT` (20 km) from the universe's focus,
  awake again inside `WAKE_AT` (18 km), checked at 1 Hz. The base you are inside never sleeps.
- **Asleep, a base is its `BaseSite` only.** Its exterior and interior are freed and **its slot is
  released.** Everything inside it (items, the drill's state) is held in the site, positioned
  relative to the interior's origin, so it wakes correctly into whatever slot is free.
- **Waking** claims a slot, builds the interior and exterior from the grid, puts the items back,
  and credits the drill for the time asleep (§9.4).
- **A base and its rock:** the exterior stands on the rock's exact surface, which exists only in
  detail, within 4 km of an anchor (asteroids §18). **An awake base joins
  `AsteroidStream.SPACE_ANCHOR`**, as an awake ship does, so its rock is always in detail under it,
  wherever your ship has drifted. Asleep, it leaves the group, as a sleeping ship does.

### 9.4 The universe clock

- **`Universe.clock`**: seconds of play time since the game began, advanced every physics tick,
  through warps and blackouts alike. Saved; the star systems spec §11 already reserves it.
- **Only the drill reads it** in this spec. Other things may later (comets, being remade).
- Time with the game closed never counts, matching the strays rule (saving §7.1).

### 9.5 Files (a sketch, for the plan to settle)

```
src/habitat/
  habitat_values.gd     HabitatValues: costs, rates, reaches, limits (pure)
  module_definition.gd  ModuleDefinition: a module's prefab grid, footprint, ports (Resource)
  base_site.gd          BaseSite: frame, site, modules, store, drill state (pure)
  plant_surface.gd      PlantSurface: up, cast, fixed, site id (interface)
  rock_surface.gd       RockSurface: a big rock in detail as a PlantSurface
  planting.gd           Planting: fit test and prompts (pure)
  corridor_route.gd     CorridorRoute: port-to-port grid search (pure)
  drill_yield.gd        DrillYield: richness, surveying, earnings by the clock (pure)
  base.gd               Base: grid, exterior, interior, plant
  bases.gd              Bases: every base in the session, sleeping and waking
  base_exterior.gd      BaseExterior: pods, legs, tubes, struts, unfolding
  package_ghost.gd      PackageGhost: the ghost and its prompt
  corridor_collar.gd    CorridorCollar extends ItemUse: the collar on its line
  link_panel.gd         LinkPanel: the quantum link
src/ship/grid_interior.gd    GridInterior: what Ship and Base share (extracted)
src/ship/interior_slots.gd   InteriorSlots: the slot pool (extracted from Fleet)
data/modules/*.tres          hub, drill, store, fabricator, suit_bay, ship_builder
data/items/*_package.tres, corridor_collar.tres
```

---

## 10. HUD

- **On a spacewalk with a package:** *PACKAGE · HUB* in the band, and the ghost's prompt at the
  reticle.
- **`EnergyPanel`** gains the base's store while you're inside a base, from the base's own
  `QuantumPlant`. Aboard on foot the HUD stays dark, as now. The hub's terminal and the drill's
  gauge are the instruments inside.
- **Sensors:** each base is a contact (`Contact`), so the bridge computer's map shows your bases,
  asleep or awake, and can set a course home. A base's contact comes from its `BaseSite`, so it
  needs no nodes.

---

## 11. Saving

### 11.1 What is saved

- **Save format 3.** A format-2 save migrates with no bases and the clock at 0.
- **The universe clock.**
- **Bases, keyed by system id**, beside that system's salvage and stray ledgers (star systems §11).
  While only one system exists, one entry. Each base is its `BaseSite`: frame (`UniversePoint` and
  basis), surface site id, modules (kind, cell, quarter turns), corridors (ports and route), store,
  the drill's last credit and survey state, and the items inside, relative to the interior's
  origin, in the saving spec's item form (§6.4 there).
- **A base's slot is never saved.** It is claimed afresh on waking.
- **Packages adrift** are strays, saved by the stray ledger as they are today.

### 11.2 Calm

The save gate (saving §5) also waits while:
- a module is unfolding (§5.3);
- a corridor is unfolding, pressurizing or retracting (§5.4);
- the link is moving QE.

A collar held on a spacewalk is an item in use, which the gate already handles (saving §6.5).

### 11.3 Being downed

- **Inside a base,** you wake beside the hub's core after 3 s of black, as aboard a ship with no
  bunks (health and damage §7.2). **The 50 QE patch-up comes from the base's store.**
- **Outside,** you wake inside the airlock you left by, whether a ship's or a base's.
- **A package you were carrying** drops where you fell and is a stray (§4.1).

---

## 12. Testing

### 12.1 Automated (GUT, headless, output pristine)

Targeted test files only during the build; the full suite only with the owner's say-so at the end.

- **`Planting`:** every prompt in §5.2 from built surfaces; leg lengths; snapping to a base's grid
  in quarter turns; *NO ROOM* when the slot pool is full.
- **`PlantSurface`:** `RockSurface` gives a rock's up and casts; a non-fixed surface refuses a base.
- **`CorridorRoute`:** straight, one bend, two bends, a ramp; blocked by a module and by the
  ground; the fewest bends win; longer than 24 m is refused.
- **`DrillYield`:** the surveying minute; richness seeded per rock and in range; veined doubles;
  earnings by the clock, capped at free capacity; credited once on waking for the time asleep.
- **`BaseSite`:** the same site gives the same grid; a planted module's prefab lands at the right
  cells, turned correctly; packing up removes exactly its cells.
- **`BaseValidator`:** the structural rules on and the flight rules off.
- **`GridInterior`:** the ship's interior is exactly as before (the parity test).
- **`InteriorSlots`:** ships and bases share the pool; a sleeping base releases its slot and wakes
  into another with everything inside where it was; the cap holds.
- **Sleeping:** a base sleeps past 20 km and wakes inside 18 km; asleep it has no nodes. With you
  inside it and the ship 25 km off, the base stays awake, is the focus, and its rock stays in
  detail; the ship sleeps.
- **Items:** every package has a value, fits the bay and is EVA cargo; the machine lists the small
  packages and not the big ones; a package let go outside is adopted by the stray ledger and
  forgotten on its rule.
- **Link:** moves QE both ways without loss, refuses beyond 1 km, and respects both capacities.
- **Saving:** a base round-trips (`test_save_scene.gd`); format 2 migrates to 3
  (`test_save_game.gd`); the gate waits on unfolding, a corridor and the link.
- **Downed:** inside a base you wake by the hub's core and the base's store pays.
- **Skitters:** planting emits a vibration on the rock's site; a running drill emits its hum; a
  herd scatters at the first and not at the second.
- **The floating origin:** a base, a pulled collar and a floating package, all covered; a sleeping
  base in no group.
- **Style rules:** the new painting files are held to the palettes; the props are grid-blind; three
  shaders.

### 12.2 Real-scene probes and renders

- **Plant probe:** make a hub, carry it out, find each coral prompt, plant it on a shelf of the
  start's big rock, and cycle in. It also records the early path: how much of the starter's cargo
  and how many salvage groups a hub actually takes.
- **Corridor probe:** plant a drill 10 m off, pull a collar across, connect, walk through.
- **Drill probe:** survey, earn, fly 25 km away (the base sleeps), come back (it wakes) to the
  earnings.
- **`fleet_play.gd`** after Phase A and after any change to the airlock or the suit's home
  (CLAUDE.md).
- **Renders at 1.6 m eye height,** sent to the owner: a package in the bay; the ghost green and
  coral; mid-unfold; a hub from 20 m and from 2 km; inside the hub; a corridor from inside and from
  outside; the drill's porthole down onto its head.
- **Frame time** at 1280 × 720 against the 120 fps budget: inside the hub, looking out; outside,
  with five modules and the rock in detail.

### 12.3 Playtest checklist

- Is making the hub a goal worth saving for, against the warps it costs? Is 800 QE right?
- Does carrying a package out feel like a job, or a chore? Does the risk of losing one feel fair?
- Is the ghost clear about why a spot is bad?
- Does pulling a corridor feel physical and satisfying?
- Does walking into a base feel like coming home?
- Does the drill make you want to come back? Is its rate right?
- Does the fabricator's low-power moment teach, or just annoy?
- Does the progression pull you forward: hub, drill, store, fabricator, ship builder?

---

## 13. Amendments to other documents (once approved)

- **Slice spec:** §3.1, the slot grid's first use beyond ships; the roadmap gains bases, between
  Slice 1 and Slice 2. §8, the shipyard gains a home in the ship builder.
- **Quantum energy:** §4.2, the packages; §17, mining and the shipyard's costs now have a design.
- **The airlock spec:** a base's airlock uses the same cycle with a still frame.
- **The asteroids spec:** §18, big rocks carry bases; their richness is seeded.
- **Bridge computer:** §4.2, bases are contacts, and later sensor sources.
- **Saving:** format 3, the clock, bases, and the gate's new waits.
- **Star systems:** §11, bases join a system's saved state; the clock is built.
- **Many ships:** §4, `board` takes a base; §5.1, the slot pool is shared with bases; the suit's
  home is a ship or a base.
- **Health and damage:** §7.2, waking in a base.
- **Planetfall:** §18, the outpost is this spec's base; a `PlanetSurface` is its job.
- **Visual style guide:** a section for bases outside (pods, legs, tubes) and the new palette
  entries.
- **The `building-a-ship` skill:** bases are grids too. Its checklist and `reference.md` gain
  `Base`, `GridInterior`, `InteriorSlots` and `BaseValidator`, as CLAUDE.md asks.
- **The `building-an-npc` skill:** bases give off vibration (§8.4).

---

## 14. Build order

Each phase ends playable. Phases A–C need only what is on `main` now; Phase D needs quantum
energy's hose line (Task 9), and a base's sensor contact needs its Task 10.

- **Phase A: `GridInterior` and `InteriorSlots`.** Extract what `Ship` and a base share, and the
  slot pool from `Fleet`, with no behaviour change, proven by the parity test, the ship probe and
  `fleet_play.gd`.
- **Phase B: a hub you can plant.** The universe clock, the hub package, EVA cargo, `PlantSurface`
  and `RockSurface`, the ghost, planting, unfolding, the hub's grid and interior in a pooled slot,
  its airlock, boarding a base and the suit's home, sleeping and waking, saving (format 3), and the
  planting stamp.
  *Make a hub, carry it out, plant it, walk inside, quit, and load back into it.*
- **Phase C: a base that earns.** The base's store, the link, the drill (its clock, survey and hum)
  and the store module. *Plant a drill beside the hub, fly off, and come back to QE.*
- **Phase D: corridors.** Ports, collars, routes, tubes, ramps.
  *Pull a corridor from the hub to the drill and walk through it.*
- **Phase E: the fabricator and the suit bay.**
- **Phase F: the ship builder.** Its own spec, with the slice's Phase C editor.

**Done (Phases A–D) when:**
1. You make a hub package at the ship's machine, carry it out and plant it on the start's big rock.
2. You cycle in and walk the hub in gravity, with the suit idle.
3. You plant a drill, pull a corridor to it and walk through.
4. You fly away until the base sleeps, come back, and the drill has earned QE, which you link to
   the ship.
5. You quit and load, and the base, its store and its corridor are as you left them.
6. The targeted GUT files are green with pristine output, the renders of §12.2 have gone to the
   owner, and a base holds 120 fps on the GTX 960.

---

## 15. Hooks left open

- **Planets and moons:** a `PlanetSurface`, where the world's up is the base's up (Planetfall).
- **Docking:** a dock module; the ship's interior stitched to the base's (slice spec §3.1).
- **Cargo doors:** getting big things (rubble, crates of salvage) into a base.
- **Mid-size rocks,** once a rock can be pinned in place.
- **Damage and raids:** a base can be hit; its store is loot.
- **Captured bases:** a base found in low power is taken by feeding its hub's terminal, as a
  derelict ship is (QE §17).
- **Droids** made at the fabricator: the maintenance droid's `DeckWalker` already walks a grid, so
  a base can have one tending it, and later running its drills.
- **Several bases,** and the link between them.
- **Bases in other systems,** once jumps exist: kept per system already (§11.1).

---

## 16. Non-goals

- The ship builder's editor (its own spec, and the slice's Phase C).
- Docking, cargo doors, planets.
- Damage, raids, defence.
- Life support, air as a resource.
- Moving a base as a whole.
- Multiplayer.

---

## 17. Risks

| Risk | Mitigation |
|---|---|
| A base's rock unloads while you're inside | An awake base is a space anchor, so its rock stays in detail under it; a base you're inside is what you're aboard, so it is the focus and never sleeps. A test parks the ship 25 km off with you inside the base. |
| Widening `board` breaks boarding ships | Phase B changes it with `fleet_play.gd` run before and after, and the plan settles its shape before any code. |
| The slot pool runs out | 16 slots, ships and bases together, and a sleeping base holds none. A full pool says so (*NO ROOM*, *NO BERTH FREE*) rather than failing. |
| Waking into another slot misplaces what's inside | Everything inside a base is held relative to its interior's origin; the `InteriorSlots` test wakes a base into a different slot and checks every item. |
| Snapping to one grid makes good spots feel unreachable | Legs cover 2.2 m of rise; 25° of slope is allowed; the ghost says why. If it's still too strict, loosen the leg reach before giving up the one frame. |
| Corridor routes fail on lumpy rock | Struts carry a tube over dips; the route may rise a storey by a ramp. The ghost shows a blocked route before you connect. |
| `GridInterior` or `InteriorSlots` extraction breaks the ships | Phase A changes no behaviour, proven by the parity test, the ship probe and `fleet_play.gd` before anything is built on it. |
| Passive QE makes gathering pointless | The drill's rate is low, play time only, capped by the store, and tuned at playtest. Salvage stays the quick way to QE. |
| Losing a package feels unfair | It is the owner's choice (§2, row 15). The playtest asks; if it stings too much, packages can be kept by the stray ledger later without changing anything else. |
| The fabricator's low power strands a player | The link back from the base's store; the machine's warning; the pilot light. The playtest asks. |
| Bases cost frame time outside | A base's exterior is a handful of chunky meshes and a static body, and a sleeping base costs nothing. Measured in §12.2. |

---

## 18. What the 2026-10-08 review changed

The draft of 2026-09-26 was written against `main` at `ae32d48`. Since then `main` gained saving,
NPCs, the bridge computer, star systems, the warp, world scale, health and damage, and many ships.
The review with the owner:
- **decided all of §2**: rows 1, 2 and 4–12 as recommended; row 3 reshaped round a surface
  interface; row 13 replaced now that saving exists; rows 14–17 added;
- **shared the interior slots with `Fleet`** and **made bases sleep as ships do**, in place of
  "loading with the rock within 30 km" (§9.3);
- **added the universe clock** (§9.4) and **a saving section** (§11);
- **made packages strays** (§4.1), and said what being downed does in and near a base (§11.3);
- **put the warp into the loop** (§3) and **said the fabricator empties a full ship** (§4.2);
- **gave skitters a part** (§8.4);
- **made the ship builder launch through `Fleet`** (§6.5);
- **made entering a base boarding it** (§5.5), and an awake base a space anchor, so its rock stays
  in detail whatever the ship does (§9.3);
- renamed the draft's "moons (mid-size rocks)" to **mid-size rocks**, since moons are now bodies
  4–15 km across, and used the airlock's real class names (`Airlock`, `AirlockSite`).
