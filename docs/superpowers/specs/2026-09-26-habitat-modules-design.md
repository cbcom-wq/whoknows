# Habitat modules: a base you print, plant and plug together

**Date:** 2026-09-26
**Status:** First draft, written from the owner's idea of 2026-09-26. **Nothing in §2 is decided
yet.** Each row gives a recommendation for the owner to accept or change. No code has changed,
and no plan exists until the owner has answered §2.
**Depends on:** `main` at `ae32d48`, which has quantum energy's Tasks 1–8 (the store, the machine,
the suit cell and the near cloud), the asteroids' fixed big rocks (asteroids spec §18), the
airlock and the floating origin. **It also needs the rest of quantum energy:** the hose and its
line (Task 9), salvage at the groups and the ship's sensors (Task 10), and low power's look
(Task 11). Corridors reuse the hose's line, and bases join the sensors.
**Governed by:** `docs/design/visual-style.md`, and CLAUDE.md's floating-origin rule.
**Builds on:**
- the slice spec §3, the interior/exterior split and its slot grid;
- quantum energy §3 (the store), §4 (values), §7 (the machine), §9 (the suit cell), §11 (the hose)
  and §17 (mining, persistence, the shipyard's costs);
- the airlock spec §7 (the threshold);
- the bridge computer spec §4 (the ship's sensors).

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
- **QE has only a few uses.** You gather salvage (soon with the hose), convert it at the machine,
  and spend it on boost, the suit and making small items. Nothing you make earns you more QE, so the
  loop has no way to grow.
- **The store is capped at 1,200 QE** (three quantum cells), and making only works at full power.
- **Big rocks are fixed in place and solid as drawn** within 4 km (asteroids §18). They are the only
  surfaces outside that stay put.
- **Interior space is a grid of slots**, 2 km apart (`Ship.SLOT_SPACING`). The slice spec reserved
  it so several interiors could be loaded at once. Only slot 0 is used.
- **The shipyard editor is not built** (Slice 1 Phase C, Tasks 16–20). It has no place in the
  world yet.
- **Nothing is saved.** The store, the suit and the salvage ledger last only for the session.

### 1.1 The pitch

You've been vacuuming salvage for an hour and the store is almost full. At the machine, ▶ steps
past the plasma pistol and the power cell to something new: *MAKE · HUB PACKAGE · COST 800 QE*.
You press it. The core's gauge drops almost to the amber bar, and a violet point in the bay swells
into a chunky cream case the size of a suitcase, strapped in terracotta.

You carry it aft, cycle out and fly down to the big rock off the bow. As you drift over the
surface, a ghost of the hub appears under you on its legs: coral over the crater rim, green on the
flat shelf beyond. You press *Plant*. The case lands and its seams split violet. Four legs stamp
into the rock and level the hub, then walls fold up round it and its porthole lights come on,
warm.

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
- **Planting:** on a big rock's surface, with a ghost that shows where the module fits. The module
  levels itself on legs and unfolds.
- **A base:** modules on one rock sharing one frame, one grid, one interior slot and one store.
  Inside a base you walk in gravity and your suit is idle, as aboard the ship.
- **Corridors:** accordion tubes you pull from a door port on a spacewalk and plug into another.
- **Modules that do things.** The first set is a hub, a drill, a store, a fabricator and a ship
  builder. §6 lists them and §7 how they unlock one another.

---

## 2. Decisions for the owner

Every row is a recommendation. None is decided.

| # | Question | Recommendation | Why | Alternatives |
|---|---|---|---|---|
| 1 | What the machine makes | **A module package: an item** like any other, with a value, which the machine makes at twice its value (quantum energy §2, row 7). It fits the bay: 0.5 m, 30 kg. | The machine already makes anything with a value. A new kind joins the list by existing (QE §4.3). A package that converts back returns half, like everything else. | The machine plants the module itself, from a map of the rock. A package too big for the bay, made at a pad outside. |
| 2 | Getting it outside | **You carry it out.** Packages are a new kind of **EVA cargo**, which Grasp lets past `suspended` as it does EVA tools. Carrying one makes the suit slower: 150 kg, not 120, so 2.0 m/s². | Hands-on and physical, like the hose. It gives a spacewalk a job and makes the trip to the rock part of building. | Throwing it from the airlock. A cargo drone. Launching it from the ship at a marked spot. |
| 3 | Where a module can stand | **On a big rock, in this build.** Big rocks are the only surfaces outside that never move (asteroids §18). Planets later (§14). | A pushable rock under a base would fly apart from it. The ship's hull would change the ship's mass and balance, and that belongs to the shipyard. | Moons (mid-size rocks) pinned in place once a base stands on them. The ship's hull, as ship blocks. |
| 4 | Uneven ground | **Levelling legs.** Each module stands on four legs that reach 0.3–2.5 m. A spot is good when every leg reaches the rock and nothing else touches it. | Big rocks are lumpy on purpose (craters, ledges, boulders). Legs turn "is it flat?" into "can the legs reach?", which is readable and forgiving. It is also a strong Astroneer-style shape. | A flat pad the module blasts into the rock. Modules that lie on the surface at an angle, which breaks §2 row 5. |
| 5 | One base, one frame | **The first module you plant, which must be a hub, fixes the base's frame:** its up, its yaw and its 2 m grid. Every later module snaps to that grid, turned in quarter turns, within 24 m of the base. Its legs level it to the base's up. | One rigid frame means the whole base is one grid, like a ship. It lives in one interior slot with one gravity, and it reuses the ship's builders unchanged (§9). It also keeps corridors to straight grid runs. | Every module in its own frame, with corridors that bend in 3D and a gravity per module. That is far harder inside and gains little. |
| 6 | Starting a base | **Only a hub starts a base.** It holds the base's airlock. Any other module must be planted within reach of an existing base. | Every base needs a way in. One rule, easy to explain: *plant a hub first*. | Every module has its own small airlock, which costs space and QE in every module. |
| 7 | Corridors | **Pulled on a spacewalk.** A door port has a **collar** on its outside, an EVA tool on a line, like the hose nozzle. Take it, fly to another port within 24 m and press *Connect*. The tube routes itself along the grid (§5.3), unfolds, stiffens and pressurizes. | This is the owner's "pull and connect", made physical, and it reuses the hose's line and reel. | Dragging a route on a panel inside the hub. Corridors built automatically between neighbouring modules. |
| 8 | Inside a base | **Exactly as aboard the ship:** interior space, `PLATING` mode, gravity, hands free, and the suit idle. No shoves, because a base never moves. | This is the owner's "no powered suit, artificial gravity". It is the ship's interior, which already works. | Low gravity inside a base, since it sits on a rock. |
| 9 | Where a base's QE lives | **The base has its own store.** The hub holds a small one (400). Store modules add capacity. **A quantum link** moves QE between the ship's store and the base's, both ways and without loss, from a panel in the hub, while the ship is within 1 km. | Two stores make the base a place you come back to ("the drill filled it while I was away"). Lossless transfer means you're never punished for moving energy home. | One shared store while the ship is near. Carrying QE as items (a shard loses half at the machine). |
| 10 | What earns QE | **The drill.** It mines the rock under it, slowly and without you. It earns more on a veined rock. Its yield stays unknown until it has run for a minute (*who knows*). | This is "harvest more energy". It uses the lavender veins, which already read as quantum ore (QE §14.3, §17). A base's site becomes a real choice. | A salvage sweeper pulling in drifting salvage (salvage never comes back, so it runs dry). A solar collector anywhere. |
| 11 | How modules unlock | **By who can make them.** The ship's machine makes the small packages. A **fabricator** module makes the big ones. The **store's capacity** gates the biggest, since you can't spend what you can't hold. | "What makes what" is a progression you can see and touch, and it needs no separate tech tree or menus. | A research tree. Blueprints found as salvage. Everything available at once, gated only by cost. |
| 12 | Moving a module | **Pack it up** from a panel inside it, when it has no corridors and nothing in its bays. You get the package back at full value. | Mistakes in placement shouldn't cost QE. | No packing up. Packing up at half value (converting). |
| 13 | Saving | **The base is the first thing that really needs saving.** Recommend a small saving spec before, or with, Phase C (§13). Until then a base lasts for the session, like the salvage ledger. | A progression you lose on quitting isn't a progression. | Build the base first and play it within a session until saving exists. |

### 2.1 Open questions beyond §2

- **The ship builder's shape** (§6.5). This spec only gives it a place, a cost and a size. Its
  editor is the slice's Phase C (Tasks 16–20). Recommend a spec of its own, after the base.
- **Docking.** A dock module the ship can berth against, so you walk from the ship into the base
  with no spacewalk. This is the slice spec's §3.1 stitching, and belongs with Slice 3's docking
  (§14).
- **The pillar.** "Ships are taken, not bought" (slice spec §1). The ship builder is where you
  *build* and refit ships from blocks, with QE. Building by hand was always in the game; buying a
  ship never is. Nothing here sells a ship.

---

## 3. The loop

```
      gather (hose, salvage)            convert (machine)
  ┌──────────────────────────► items ─────────────────► ship store ───┐
  │                                                        │  link    │ make
  │                                                        ▼          ▼
  │   drill ──── QE while you're away ─────────────────► base store   packages
  │     ▲                                                  │          │ plant
  │     └──────────────────────────────────────── modules ◄┴──────────┘
  │                                                  │
  └──────────── better ships (ship builder), bigger stores, faster suit ◄┘
```

- **Early:** the starter's ~935 QE of cargo plus two or three salvage groups buys a hub.
- **Middle:** a drill and a store make the base earn and hold QE. The fabricator unlocks the big
  modules.
- **Late:** the ship builder spends the base's store on blocks. Stronger ships reach further
  groups, and later other systems (Slice 5).

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
  lets the hose nozzle. Unlike an EVA tool, it is made and converted like any other item.
- **Carrying it outside** adds its mass to the suit's: acceleration becomes
  `2.5 × 120 / (120 + 30)` = 2.0 m/s². The suit cell still pays 1 QE per m/s of Δv.
- **Letting go outside** leaves it floating where it is, as salvage does: it doesn't drift, it
  joins `Universe.EXTERIOR_SPACE`, and it glints. It is never lost.

### 4.2 Costs

| Module | Made at | Package value | Make cost | Footprint (cells) |
|---|---|---|---|---|
| Hub | the ship's machine | 400 | 800 | 2 × 2 |
| Drill | the ship's machine | 300 | 600 | 1 × 2 |
| Store | the ship's machine | 250 | 500 | 1 × 1 |
| Suit bay | the fabricator | 400 | 800 | 1 × 2 |
| Fabricator | the ship's machine | 600 | 1,200 | 2 × 2 |
| Ship builder | the fabricator | 2,000 | 4,000 | 2 × 3 control room, and a gantry (§6.5) |

- **The hub costs 800,** two thirds of the starter's store. Emptying the ship's cargo into the
  machine and two or three salvage groups gets you there.
- **The fabricator costs the whole of the starter's store** (1,200), so it needs the store brim
  full. It is the first real saving-up.
- **The ship builder costs 4,000,** more than any ship holds. It can only be made at the fabricator,
  from the base's store, once store modules have raised its capacity (§6.3). That is the gate.

---

## 5. Planting and corridors

### 5.1 The ghost

On a spacewalk, holding a package, you see a ghost of the module wherever you look at a big rock
within 8 m:
- **The body at its levelled height, with its legs reaching down to the rock**, in a flat,
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
  | *Blocked* | the body touches the rock, a boulder, another module or a corridor |
  | *Too far from the base* | not a hub, and more than 24 m from every module of the base |
  | *Plant a hub first* | not a hub, and no base on this rock |
  | *Too close to your ship* | within 20 m of the hull |

- **The test is a few shape queries**, run at 10 Hz while you aim: a box for the body, and a ray
  down for each leg.

### 5.2 Unfolding

Press `use` with a green ghost:
1. **The case flies to the spot** over 0.6 s and settles (0.4 s).
2. **The seams split violet**, and the legs punch down to the rock and level the body (1.0 s).
3. **The walls and roof fold up** from the case in three chunky stages: each a panel turned
   about its hinge, animated by transform so no shared material changes (2.0 s).
4. **The lights come on** cell by cell, as when power returns on the ship (QE §8.3), with a
   soft `unfold` sound (1.5 s).

About 5.5 s in all. The package is consumed at step 1, and the base is changed at step 4. Nothing
can interrupt it.

### 5.3 Corridors

**Every module has door ports:** a round hatch on a face of the grid, with a **collar** on its
outside face. The hub has three, and the other modules one or two (§6).

**Pulling one:**
1. On a spacewalk, take the collar from a port (*Take Corridor collar*). It is an EVA tool on a
   line from its port, drawn and simulated as the hose line is (`HoseLine`, 24 m).
2. Fly toward another port. Within 3 m of a free port, a ghost shows the tube's route: at most
   two bends, along the base's grid, and level. The ghost is `CORAL` when the route is blocked by
   the rock or by a module.
3. Press `use`: *Connect*. The collar flies to the far port, the tube unfolds along the route like
   an accordion (1.5 s), stiffens, and struts drop from it to the rock where it runs more than
   1 m above the surface. It hisses as it pressurizes (1.2 s).
4. Inside, both ports' doors turn from `CORAL` to `SIGNAL_GO`. Opening them is a button press, as
   with a room's door.

**The route** is found on the grid by a small breadth-first search from port to port. It prefers
the fewest bends, and never goes through a module or the rock. Two ports on different storeys are
joined by a **ramp section**, one storey over three cells, as the route's middle leg.

**Letting go** of the collar anywhere else winds it home along its line, like the hose nozzle.

**Retracting** a corridor: from the panel beside either door, inside, while nobody is in it and
nothing loose lies in it. It folds back into its first port.

### 5.4 Leaving and coming back

- **Every base has one way in:** the hub's airlock. It is the ship's airlock block, dressed and
  cycled exactly as the ship's is (the airlock spec). The threshold maths use the base's transform
  in place of the hull's. A base's velocity is always zero.
- **The suit's assist** holds you still relative to whichever you are nearer: your ship or a
  base.
- **A marker home.** On a spacewalk, `AirlockMarker` marks both airlocks, your ship's and the
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
  hold to move it continuously. The panel reads *NO LINK* when the ship is more than 1 km away.
- **A small store** of 400 QE, and a small core behind a grille for light and gravity. The core
  gives no thrust, so it has no power figure to balance.

### 6.2 Drill

- **1 × 2 cells:** a control room with a porthole down onto the drill head, and one port.
- **What it does:** it mines the rock under it into the base's store.
  - base rate: **1 QE per 10 s** (6 per minute, 360 per hour);
  - times the rock's **richness**, seeded per big rock, from 0.5 to 3.0, and doubled on a veined
    rock.
- **Who knows:** for its first minute the drill's gauge reads *SURVEYING*. Then it shows the
  richness: *VEIN 1.8×*. You don't know how good a site is until you've paid for a drill on it.
- **While you're away:** the base credits the drill's earnings for the time since it was last
  loaded, up to its store's capacity. You come back to a full store, not an endless one.
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
- **It makes the big packages** (§4.2), and later the big things: ship blocks, droids (Slice 3),
  large equipment.
- **It works exactly like the ship's machine** (`MachineCycle`, making at twice the value, only at
  full power), but draws on the **base's** store.
- **Converting at the pad** takes things too big for the ship's bay: up to 1.5 m across and
  400 kg. Push a scrap plate or a 1 m rubble rock onto it. (Getting that rock into the base is
  §14's problem: a cargo door.)

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
- **Launch** releases the ship from the cradle.
- **Refitting** a ship you already have (and later, one you've captured, Slice 4) means flying it
  into the cradle.

### 6.6 Suit bay

- **1 × 2 cells:** a rack you back into.
- **Suit upgrades,** bought with the base's QE: a larger suit cell (100 → 200 → 400), stronger
  thrusters (2.5 → 3.5 m/s²), and later a longer hose.
- **The suit charges here for free** from the base's store.

### 6.7 Later modules (hooks, not designed)

| Module | What it would do |
|---|---|
| Sensor mast | The base becomes a sensor source (bridge computer §4.2): salvage pings from 20 km, not 10. |
| Refinery | Rubble rocks fed through a cargo door, converted at a better rate. |
| Quarters | Where you come back when death exists (QE §17, "being remade"). |
| Greenhouse | Life support, once the suit drains (QE §17). |
| Dock | Your ship berths against it: walk in, no spacewalk (slice spec §3.1). |
| Beacon | A quantum-jump target (Slice 5). |
| Turret | Defence, when there is something to defend against (Slice 2). |

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
- **A package you can't place yet** can still be made. Its *Plant* prompt tells you why not
  (*Plant a hub first*).
- **Nothing is hidden.** The fabricator's list shows everything it can make, with costs you
  can't yet afford reading *NOT ENOUGH QE*, so you can see what you're saving for.

---

## 8. The look

**Stylized, warm and dim**, like the ship (style guide §1). A base is chunky, bevelled and
friendly: Astroneer's charm, a little more serious.

### 8.1 Outside

- **Modules** are rounded drums and capsules round their cells, not box hulls: bevelled cylinders
  with flat ends, plated in the hull's livery material as the airlock's hatch face is, with
  chunky `PANEL_LINE` ribs. The module's colour band from its package runs round it.
- **Legs:** four chunky telescoping struts in `TRIM`, with round pads on the rock.
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

---

## 9. Architecture

### 9.1 A base is a grid that doesn't fly

A ship is one `ShipGrid`, and everything else is built from it (the building-a-ship skill). **A
base is the same:** a `ShipGrid` in the base's frame, a union of its modules' prefabs and its
corridors' cells.

```
                   BaseGrid (a ShipGrid)  ◄── planting copies a module's prefab in
                   the single source of truth   corridors add tube and ramp cells
                          │
            ┌─────────────┴─────────────┐
            │                           │
   EXTERIOR: StaticBody3D           INTERIOR: in its own slot, never moves
   under Outside, a member of       InteriorBuilder + InteriorDressing,
   Universe.EXTERIOR_SPACE          unchanged; gravity, no shoves
   BaseExterior: pods, legs,        airlock, doors, rooms, portholes
   tubes, struts
```

- **`Base`** (a `Node3D`, beside `Ship`): owns the grid, the exterior, the interior and a
  `QuantumPlant` of its own. It has no `FlightComputer`, no RCS and no `MotionCoupling`.
- **What `Base` shares with `Ship`** is extracted, not copied: the interior slot, building the
  interior from the grid, the portals, and the airlock wiring (`Airlocks`). A small `GridInterior`
  holds it, and `Ship` uses it too. Recommend doing this extraction first, as a refactor with no
  behaviour change (Phase A).
- **`BaseValidator`:** the ship validator's structural rules (connectivity, reachability on foot,
  the airlock's one face to space), and none of its flight rules (a helm, thrust, balance).
- **`BaseSite`** (pure): the base's frame as a `UniversePoint` and a basis, the big rock's id, and
  its modules. It is what saving will save.
- **`Planting`** (pure): from a rock's surface samples and a module's footprint, it gives the
  prompt of §5.1 and the leg lengths. Tested headless.
- **`CorridorRoute`** (pure): the grid search of §5.3.
- **`HabitatValues`:** every number in this spec.
- **`Bases`** (a `Node` under `Outside`): every base in the session, keyed by big rock. It loads a
  base's exterior when its rock loads, within 30 km, and frees it with the rock.

### 9.2 The floating origin

- **A base's exterior is one node, a member of `Universe.EXTERIOR_SPACE`,** whose parent never
  moves. Its pods, legs and tubes are its children, never members themselves (CLAUDE.md).
- **Its position is a `UniversePoint`** in `BaseSite`, never an engine `Vector3`.
- **A package floating outside** is a member, as salvage is. The collar's line is a member with
  its points in its own frame, as the hose line is.
- **The base's interior** is in interior space and never moves.
- `test_floating_origin_scene.gd` walks the scene with a base loaded, a corridor half pulled, and a
  package floating.

### 9.3 Interior slots

- **Slot 0 is the ship. Each base takes the next free slot.** Slots are 2 km apart, so a base
  may be as large as a ship.
- **Only loaded bases hold a slot.** A base's interior is built when its exterior loads and
  freed when it unloads, unless you're standing in it. You can't be in a base that isn't loaded.

### 9.4 Files (a sketch, for the plan to settle)

```
src/habitat/
  habitat_values.gd     HabitatValues: costs, rates, reaches, limits (pure)
  module_definition.gd  ModuleDefinition: a module's prefab grid, footprint, ports (Resource)
  base_site.gd          BaseSite: frame, rock, modules (pure)
  planting.gd           Planting: fit test and prompts (pure)
  corridor_route.gd     CorridorRoute: port-to-port grid search (pure)
  drill_yield.gd        DrillYield: richness, surveying, earnings over time (pure)
  base.gd               Base: grid, exterior, interior, plant
  bases.gd              Bases: every base in the session, loading with its rock
  base_exterior.gd      BaseExterior: pods, legs, tubes, struts, unfolding
  package_ghost.gd      PackageGhost: the ghost and its prompt
  corridor_collar.gd    CorridorCollar extends ItemUse: the collar on its line
  link_panel.gd         LinkPanel: the quantum link
src/ship/grid_interior.gd   GridInterior: what Ship and Base share (extracted)
data/modules/*.tres        hub, drill, store, fabricator, suit_bay, ship_builder
data/items/*_package.tres, corridor_collar.tres
```

---

## 10. HUD and sound

- **On a spacewalk with a package:** *PACKAGE · HUB* in the band, and the ghost's prompt at the
  reticle.
- **`EnergyPanel`** gains the base's store while you're inside a base, from the base's own
  `QuantumPlant`. Aboard on foot the HUD stays dark, as now. The hub's terminal and the drill's
  gauge are the instruments inside.
- **Sensors:** each base is a contact (`Contact`), so the bridge computer's map shows your bases
  and can set a course home.
- **Sounds** (new `Synth` builders): `unfold` (clunks and a rising shimmer), `leg_stamp`,
  `tube_extend` (a ratcheting accordion), `tube_seal` (a hiss), `drill_hum` (a low grinding loop,
  quieter than the air handler).

---

## 11. Testing

### 11.1 Automated (GUT, headless, output pristine)

- **`Planting`:** every prompt in §5.1 from built surfaces; leg lengths; snapping to a base's grid
  in quarter turns.
- **`CorridorRoute`:** straight, one bend, two bends, a ramp; blocked by a module and by the rock;
  the fewest bends win; longer than 24 m is refused.
- **`DrillYield`:** the surveying minute; richness seeded per rock and in range; veined doubles;
  earnings over time, capped at capacity.
- **`BaseSite`:** the same site gives the same grid; a planted module's prefab lands at the right
  cells, turned correctly; packing up removes exactly its cells.
- **`BaseValidator`:** the structural rules on and the flight rules off.
- **`GridInterior`:** the ship's interior is exactly as before (the parity test).
- **Items:** every package has a value, fits the bay and is EVA cargo; the machine lists the small
  packages and not the big ones.
- **Link:** moves QE both ways without loss, refuses beyond 1 km, and respects both capacities.
- **The floating origin:** a base, a pulled collar and a floating package, all covered.
- **Style rules:** the new painting files are held to the palettes; the props are grid-blind; three
  shaders.

### 11.2 Real-scene probes and renders

- **Plant probe:** make a hub, carry it out, find each coral prompt, plant it on a shelf of the
  start's big rock, and cycle in.
- **Corridor probe:** plant a drill 10 m off, pull a collar across, connect, walk through.
- **Drill probe:** survey, earn, fly 5 km away and come back to the earnings.
- **Renders at 1.6 m eye height,** sent to the owner: a package in the bay; the ghost green and
  coral; mid-unfold; a hub from 20 m and from 2 km; inside the hub; a corridor from inside and from
  outside; the drill's porthole down onto its head.
- **Frame time** at 1280 × 720 against the 120 fps budget: inside the hub, looking out; outside,
  with five modules and the rock in detail.

### 11.3 Playtest checklist

- Is making the hub a goal worth saving for? Is 800 QE right?
- Does carrying a package out feel like a job, or a chore?
- Is the ghost clear about why a spot is bad?
- Does pulling a corridor feel physical and satisfying?
- Does walking into a base feel like coming home?
- Does the drill make you want to come back? Is its rate right?
- Does the progression pull you forward: hub, drill, store, fabricator, ship builder?

---

## 12. Amendments to other documents (once approved)

- **Slice spec:** §3.1, the slot grid's first use beyond ships; the roadmap gains bases, between
  Slice 1 and Slice 2. §8, the shipyard gains a home in the ship builder.
- **Quantum energy:** §4.2, the packages; §17, mining and the shipyard's costs now have a design.
- **The airlock spec:** §13, a base's airlock uses the same cycle with a still frame.
- **The asteroids spec:** §18, big rocks carry bases; their richness is seeded.
- **Bridge computer:** §4.2, bases are sensor sources.
- **Visual style guide:** a section for bases outside (pods, legs, tubes) and the new palette
  entries.
- **The `building-a-ship` skill:** bases are grids too. Its checklist and `reference.md` gain
  `Base`, `GridInterior` and `BaseValidator`, as CLAUDE.md asks.

---

## 13. Build order

Each phase ends playable. The plan is written once §2 is answered. Phases A–C need only what is
on `main` now; Phase D needs quantum energy's hose line (Task 9), and a base's sensor contact
needs its Task 10.

- **Phase A: `GridInterior`.** Extract what `Ship` and a base share, with no behaviour change,
  proven by the parity test and the ship probe.
- **Phase B: a hub you can plant.** The hub package, EVA cargo, the ghost, planting, unfolding, the
  hub's grid and interior in its own slot, and its airlock.
  *Make a hub, carry it out, plant it and walk inside.*
- **Phase C: a base that earns.** The base's store, the link, the drill and the store module.
  *Plant a drill beside the hub, and come back to QE.* **Saving** (§2, row 13) lands here or
  before.
- **Phase D: corridors.** Ports, collars, routes, tubes, ramps.
  *Pull a corridor from the hub to the drill and walk through it.*
- **Phase E: the fabricator and the suit bay.**
- **Phase F: the ship builder.** Its own spec, with the slice's Phase C editor.

**Done (Phases A–D) when:**
1. You make a hub package at the ship's machine, carry it out and plant it on the start's big rock.
2. You cycle in and walk the hub in gravity, with the suit idle.
3. You plant a drill, pull a corridor to it and walk through.
4. You fly away, come back, and the drill has earned QE, which you link to the ship.
5. The GUT suite is green with pristine output, the renders of §11.2 have gone to the owner, and a
   base holds 120 fps on the GTX 960.

---

## 14. Hooks left open

- **Planets:** a base on a world's surface, where the world's up is the base's up.
- **Docking:** a dock module; the ship's interior stitched to the base's (slice spec §3.1).
- **Cargo doors:** getting big things (rubble, crates of salvage) into a base.
- **Bases on moons,** once a rock can be pinned.
- **Damage and raids** (Slice 2): a base can be attacked; its store is loot.
- **Captured bases** (Slice 6's footholds): a base found in low power is taken by feeding its
  hub's terminal, as a derelict ship is (QE §17).
- **Droids** (Slice 3) made at the fabricator, which run a base's drills while you're away.
- **Several bases,** and the link between them.

---

## 15. Non-goals

- The ship builder's editor (its own spec, and the slice's Phase C).
- Docking, cargo doors, planets.
- Damage, raids, defence.
- Life support, air as a resource.
- Moving a base as a whole.
- Multiplayer.

---

## 16. Risks

| Risk | Mitigation |
|---|---|
| A base's rock unloads while you're inside | Bases load with their big rock, within 30 km. You can't get 30 km away while standing in one. A base you're inside is never freed (§9.3). |
| Snapping to one grid makes good spots feel unreachable | Levelling legs cover 2.2 m of rise; 25° of slope is allowed; the ghost says why. If it's still too strict, loosen the leg reach before giving up the one frame. |
| Corridor routes fail on lumpy rock | Struts carry a tube over dips; the route may rise a storey by a ramp. The ghost shows a blocked route before you connect. |
| `GridInterior`'s extraction breaks the ship | Phase A changes no behaviour and is proven by the ship's parity test and probe before anything is built on it. |
| Passive QE makes gathering pointless | The drill's rate is low, capped by the store, and tuned at playtest. Salvage stays the quick way to QE. |
| Nothing is saved, so the progression evaporates | §2, row 13: saving before or with Phase C. |
| Bases cost frame time outside | A base's exterior is a handful of chunky meshes and a static body; its interior exists only in its slot. Measured in §11.2. |
