# Quantum energy — the power and the currency of the universe

**Date:** 2026-09-24
**Status:** Every row of §2 is decided. The spec awaits the owner's review of the whole before
anything is built. It was written from the owner's brief of 2026-09-24. No code has changed.
**Revised 2026-09-25** by the owner's direction:
- **The ship keeps its size.** The first draft lengthened it by a row for an engine room.
- **There is no new room.** The quantum machine stands on the bridge. The engine is a **quantum
  core** at the centre of the bridge. No room moves.
- **Decided:**
  - the core is the ship's reactor and weighs 5 t;
  - the machine makes anything, and making costs twice what converting gives (rows 4, 6, 7 and 12).

**Revised again 2026-09-25,** when the owner answered the open questions (§2.1):
- **No reserve, but low power.** Below 10% of capacity the ship limps: half thrust and turning,
  no boost, no making, emergency light. A pilot light means an empty store never stays empty
  (§3.2, §8).
- **This build has no dark state.** The ship always flies (§8.3).
- **Salvage sits at the asteroid groups** as well as behind the stern. A HUD marker finds it: a
  vague ping far off, then a region you search (§10).
- **Brought up to date with `main`:** the floating origin and the asteroids, which merged after
  the first draft. Everything outside the ship follows the floating-origin rule (§10.1, §11.3,
  §14.2).

**Depends on:** `main` at `7609d0f` (the airlock and first spacewalk, the floating origin, the
asteroid groups and the flight controls)
**Amended 2026-09-25 by the bridge computer spec** (`2026-09-25-bridge-computer-design.md` §13):
salvage reaches the HUD through the ship's sensors (`ShipSensors`, `Contact`), built here in
Task 10, so the computer can share them (§10.4, §12, §14, §15).
**Governed by:** `docs/design/visual-style.md`, and CLAUDE.md's floating-origin rule
**Plan:** `docs/superpowers/plans/2026-09-24-quantum-energy.md`
**Amends, once approved:**
- the slice spec's §5 and §6.1, and its roadmap;
- the interior redesign's §7.5;
- hands-and-items §15 and §16;
- airlock §7.4 and §13;
- asteroids §13 (items in space);
- Planetfall §18;
- the visual style guide.

§16 lists each amendment.

---

## 1. Why

The owner's brief, 2026-09-24:

> Quantum energy: the power source and currency of our universe.
>
> Spaceships contain a room with a quantum engine and quantum machine. Objects can be placed in the
> machine and converted to quantum energy. The quantum engine powers the ship. The quantum machine
> converts quantum energy from and into objects and the player.
>
> Quantum energy is then used for powering all sorts of things. A few starter examples: the ship
> is powered on quantum energy; the user's suit uses quantum energy (the user must power up the
> suit at the quantum machine); the quantum machine can also create new objects from quantum
> energy.
>
> The ship also has a hose connected to the airlock that can be used to suck in objects outside and
> convert them to the quantum energy stored on the ship.
>
> Different objects have different quantum values.
>
> Ship being powered by quantum energy will be tricky. Maybe normal movement will just require
> quantum energy be present but not deduct it. Extra future features like speed boosts, quantum
> jumps, weapon systems, shields, etc. will spend energy.

And on 2026-09-25:

> The quantum machine is on the bridge itself; we have space and don't need a new room. The engine
> is actually a quantum core and is at the centre of the current bridge area.

What exists today:
- **Power** is a number. Three `reactor` blocks buried in the unwalkable equipment deck generate
  36 MW from nothing.
- **Nothing aboard is worth anything.** The sixteen items are things to pick up and throw.
- **Boost** (Space) is free, and so are **the suit's thrusters**.
- **Nothing outside can be gathered.** Asteroids stream in groups 3–6 km apart, each a big rock
  with small ones round it, but the smallest is 1 m of rock. Items in space were deferred by the
  hands-and-items spec (§16), the airlock spec (§13) and the asteroids spec (§13).
- **The floating origin** re-centres the outside world on you every 2 km. Anything outside must
  join `Universe.EXTERIOR_SPACE` or listen to `Universe.shifted` (CLAUDE.md).

### 1.1 The pitch

You walk forward up the corridor onto the bridge. At its centre, behind the captain's chair, stands
the quantum core: a pillar of glass where a violet heart turns inside three slow rings. A column of
lit bars on its spine says the store is half full.

Against the bridge's back wall, on your right as you step up, is the machine. Drop a mug into its
bay: it hangs there in the field, turning, and the screen reads *CONVERT · MUG · +3 QE*. Press the
button and the mug is gone. A bead of light runs along the pipe overhead to the core, and a bar
lights. Put your palm on the machine's charge plate and your suit fills.

Walk aft to the airlock, cycle out, take the hose nozzle from its reel beside the hatch, and float
out into the junk drifting behind your ship. Hold the trigger: a lump of ice tumbles toward you and
vanishes into the nozzle with a thunk. *+12 QE.* Back aboard, you step round the core
into the captain's chair and boost. Behind you the core spins faster and the store ticks down.
Past the big rock ahead, a ping on the HUD points at the next group: salvage, about 4 km off.
Boost too long on the way and the core's last bar turns amber, the lights drop, and the ship limps
the rest of the way.

### 1.2 What this adds

- **A value** in QE for every object.
- **A store** of QE on every ship. Ordinary flight spends none; extras spend it. Below a tenth of
  capacity the ship drops into low power and limps.
- **The quantum core,** the ship's engine, at the centre of the bridge.
- **The quantum machine** on the bridge: convert objects to QE, make objects from QE, charge your
  suit.
- **A suit cell** your thrusters draw on.
- **Things in space** and **a hose** to gather them with: a cloud behind the stern, and one at
  every asteroid group, found with a HUD marker.

---

## 2. Decisions

Every row is decided by the owner: rows 4–7 and 12 on 2026-09-25, and the rest later that day
(§2.1).

| # | Question | Decision | Why | Alternatives |
|---|---|---|---|---|
| 1 | What ordinary flight costs | **Nothing.** The ship flies, turns, holds gravity and runs its lights for free. Full power needs the store at or above the low-power line (row 3). | The owner's own suggestion. Flying about never becomes a fuel chore. The existing power model (MW, Rule 5) keeps its meaning. | An idle trickle on the lit core. Thrust that costs a little. |
| 2 | What spends ship QE now | **Boost** (5 QE/s), **making objects** and **charging the suit**. Jumps, weapons and shields are hooks (§8.4). | Boost already exists and is free; it is the obvious first extra. | Boost staying free. |
| 3 | Running low | **No reserve, but low power.** Below 10% of capacity the ship drops into low power: half thrust and turning, no boost, no making, emergency light. Converting and charging the suit still work. Any spend may take the store to 0. **A pilot light:** below 25 QE the core gains 1 QE every 5 s, up to 25. | The owner: *"The ship won't be stranded because normal flight is free. But running too low will put the ship in a type of low power mode. This is part of the game aspect. The player needs to be careful with their energy usage."* The pilot light means an empty ship and an empty suit are never locked out of gathering. | A reserve at 100 QE that extras cannot cross (the first recommendation). A dark state at 0 with no thrust. No safety net at 0. |
| 4 | Where the power comes from | **Decided by the owner, 2026-09-25: the core is the reactor.** It generates the ship's power (36 MW on the starter): all of it at full power, half in low power (§3.1). `reactor` and `battery` retire. The three reactors' cells become **quantum cells**: storage for QE, with the reactors' weight. | One engine, the one the fiction names, at the heart of the bridge. The cells keep the equipment deck's weight where it was. Made plain hull instead, they would leave the ship 5.2% nose-down under a full burn, worse than today. | Keep reactors as backup generation. Then QE does not really power the ship. Let the core hold the store, with the old reactor cells made hull: 12 t lighter, but badly balanced. |
| 5 | Where the core and the machine stand | **Decided by the owner, 2026-09-25:** both on the bridge, the core at its centre. There is no new room, and no room moves. The machine stands against the bridge's back wall on the starboard side, facing forward. Both are **fixture blocks,** like the helm. | Fixtures are grid data, so any blueprint can place them. The back wall is the one bridge wall with neither a porthole nor a console: the machine replaces a set of lockers or a display. You pass both on your way to the helm. | The machine on a flank wall, facing the core, which covers a porthole. An engine room: the earlier drafts, superseded (§5.5). |
| 6 | What the machine can make | **Decided by the owner, 2026-09-25: anything.** Every item kind with a value, EVA tools aside. More advanced things simply cost more, because they are worth more (§4.3). | The machine is a maker, not a collection. | Only kinds it has converted (the first draft's patterns). |
| 7 | Make versus convert | **Decided by the owner, 2026-09-25: making costs twice what converting gives.** Converting returns half of what making took. | Nothing can print QE, and keeping a useful object is always cheaper than remaking it. | At par: objects become cash, and nothing is worth keeping. |
| 8 | The hose | **A nozzle on a 30 m line from a reel beside the outer hatch.** On a spacewalk you take it, aim, and hold the trigger. Loose things within 8 m fly in and are converted into the ship's store. | "A hose connected to the airlock … to suck in objects outside." Hands-on and physical, and it gives a spacewalk a job. | A fixed hose aimed from the open outer hatch. A ship-mounted scoop worked from the cockpit. |
| 9 | Things to gather | **Salvage: loose items in space.** A near cloud behind the starter's stern, and a cloud at every asteroid group, remembered once taken. **Found with a HUD marker:** a vague ping far off, then a region you search (§10.4). | The hose needs something outside, and the groups are already where you fly to. The owner chose the ping-then-region marker, so finding salvage takes a little searching. A bridge computer with a map comes in its own spec, next (§17). | Fixed clouds 300–1,200 m out (the first recommendation, which the start's big rock now fills). The near cloud only. A visible wreck at each cloud. Swallowable rocks: the smallest is 1 m, so they would need a cutter first. |
| 10 | The suit | **A 100 QE suit cell,** empty at the start and charged at the machine's plate. Thrust costs 1 QE per m/s. The airlock won't depressurize for an empty suit. A suit that runs dry outside brings you home on its emergency cell. | "The user must power up the suit at the quantum machine." Nothing can strand you, and there is no death to fall back on yet. | Drift until rescued: that needs death or rescue, neither of which exists. A dry return paid from the ship's store. A suit that starts charged. |
| 11 | The colour of QE | **Chosen at Task 3's renders:** a soft violet, `QUANTUM`, rendered on the bridge beside a warm gold. It is built violet until then. Either way every light stays `LIGHT_WARM`, and bloom carries the colour. | Violet reads as other and precious, the one cool colour in a warm ship, with no style-rule change. The owner will choose from the real bridge. | Settle violet or gold now. |
| 12 | What the core weighs | **Decided by the owner, 2026-09-25: 5 t,** a reactor's weight. | The heart of the ship should weigh like one. At cabin level it brings the ship's pitch imbalance under full burn almost to zero (§5.4). It costs 5% of forward acceleration. | The weight of a deck plate (0.4 t), which leaves every flight figure exactly as it is today. |

### 2.1 How each was decided

**2026-09-25, first:**
- row 4: the core is the reactor;
- row 5: the core and the machine stand on the bridge;
- row 6: the machine makes anything;
- row 7: making costs twice what converting gives;
- row 12: the core weighs 5 t.

**2026-09-25, answering the open questions:**

| # | Question | The owner's answer | Where it lands |
|---|---|---|---|
| 1, 2 | Does ordinary flight cost QE, and what spends it? | As recommended: flight is free; boost, making and the suit spend. | Task 4; Tasks 6 and 7 |
| 3 | Is there a reserve? | **No: low power instead**, below 10% of capacity, with half flight power, extras off and emergency light. At 0, **a pilot light** refills the store to 25. | §3.2, §8; Tasks 4 and 11 |
| 8 | What is the hose? | As recommended: the hand-held nozzle on a 30 m line. | §11; Task 9 |
| 9 | What does the hose gather? | **The near cloud and salvage at every asteroid group.** A HUD marker finds it: a ping far off, a region close by. A **bridge computer with a map** is wanted too, as its own spec. | §10; Tasks 8 and 10; §17 |
| 10 | How does the suit work? | As recommended. | §9; Task 7 |
| 11 | What colour is QE? | Decided at the renders, violet beside warm gold. | §14.3; Task 3 |

---

## 3. The model: power and quantum energy

### 3.1 Two quantities

The owner's "present but not deducted" works because a ship needs two numbers, not one:

| | Power | Quantum energy (QE) |
|---|---|---|
| What it is | How much the core can deliver at once | How much is in the store |
| Unit | MW, as today | QE, whole numbers |
| Comes from | The quantum core: all of it at full power, half in low power | Converting objects, at the machine or with the hose; the pilot light |
| Goes to | Everything that runs: thrust, RCS, gravity, lights, airlocks | The extras: boost, making things, the suit; later jumps, shields and weapons |
| Running short | Brownout (Rule 5, a later mechanic) | Low power |

**The core runs at full power while the store is at or above the low-power line,** and gives the
ship its full `power_gen`. **Below the line it runs in low power** and gives half. Between those
two, power does not scale with how full the store is.

### 3.2 The store

- **Capacity** is the sum of every block's `quantum_capacity`: 400 per quantum cell. The starter
  holds 1,200.
- **It starts half full** (600) on the ship's first load, as stocking happens once. Rebuilds keep
  the amount, clamped to any new capacity.
- **Whole numbers.** Continuous costs (boost, the suit) accrue fractions and are debited in whole
  QE as they add up.
- **A credit that would overflow is refused**, never partly wasted: *STORE FULL*.
- **Every spend is all or nothing, and any spend may take the store to 0.** There is no reserve.
- **The low-power line is 10% of capacity,** rounded up: 120 QE on the starter, the top of the
  core's lowest gauge bar. The ship is in low power while the store is below it (§8.3). Full power
  returns as soon as the store is back at the line.
- **The pilot light:** while the store is below 25 QE, the core gains 1 QE every 5 s, up to 25
  and never beyond. An empty store is back to 25 in about two minutes: one short hose trip's worth
  for the suit. It counts as a credit from the source `&"pilot"`.

| Who draws on the store | When it may |
|---|---|
| Boost; making objects | only at full power |
| Charging a suit | always |
| Outside losses (later: shield hits, damage, a boarder draining it) | always |

### 3.3 In and out, in this build

| In | Out |
|---|---|
| Converting at the machine: the item's value | Boost: 5 QE/s |
| Swallowing with the hose: the item's value | Making: twice the item's value |
| The pilot light: 1 QE per 5 s, below 25 | Charging a suit: 1 QE per QE charged |

### 3.4 A currency

QE is what things are worth. In this build you spend it at the machine and on boost. The wider
economy plugs in later (§17): stations and trade, the shipyard's build costs, and paying off a
faction. The game's pillar stands: **QE buys blocks, items, repairs and jumps; ships are still
taken, not bought** (slice spec §1).

---

## 4. What things are worth

### 4.1 The rule of thumb

`value ≈ mass × material + what it does`:
- raw matter (rock, ice): about 3 QE/kg;
- worked material (scrap, a mug, a crate): 3–4 QE/kg;
- equipment and electronics: well above their mass;
- stored energy (a power cell, a quantum shard): the most.

Values are whole numbers set by hand on each item definition (`quantum_value`) following the rule.
A test holds every item to having one.

### 4.2 The table

| Item | Mass | Value (QE) | Make cost (QE) |
|---|---|---|---|
| Mug | 0.3 kg | 3 | 6 |
| Ration tin | 0.4 kg | 5 | 10 |
| Spanner | 0.8 kg | 8 | 16 |
| Rock sample | 3 kg | 9 | 18 |
| Flare | 0.3 kg | 10 | 20 |
| Canister | 4 kg | 14 | 28 |
| O2 tank | 5 kg | 25 | 50 |
| Hand lamp | 0.6 kg | 25 | 50 |
| Crate | 12 kg | 30 | 60 |
| Spare helmet | 2.5 kg | 35 | 70 |
| Toolbox | 8 kg | 40 | 80 |
| Medkit | 1.5 kg | 40 | 80 |
| Datapad | 0.5 kg | 50 | 100 |
| Spare module | 0.5 kg | 60 | 120 |
| Plasma pistol | 1.4 kg | 120 | 240 |
| Power cell | 2 kg | 150 | 300 |
| *Salvage (§10.5):* rock chunk | 4 kg | 10 | 20 |
| ice chunk | 3 kg | 12 | 24 |
| scrap plate | 6 kg | 18 | 36 |
| wire coil | 1.5 kg | 20 | 40 |
| broken module | 2 kg | 45 | 90 |
| quantum shard | 0.8 kg | 250 | 500 |
| Hose nozzle (§11) | — | 0: never converted or made | — |

Everything the starter carries converts to about 935 QE. The biggest single sources are the two
power cells (150 each) and the two pistols (120 each). That is more than the store has room for
(1,200 − 600), so emptying the ship teaches *STORE FULL*.

### 4.3 What the machine makes

- **Anything with a value:** every item kind in the catalogue, salvage included. EVA tools (the hose
  nozzle) are never made or converted.
- **More advanced things cost more,** because they are worth more: a mug costs 6 QE to make, a
  plasma pistol 240, a quantum shard 500.
- **A new kind joins the list by existing.** Add an item `.tres` with a value, and the machine can
  make it.

### 4.4 Where values show

An item's prompt never shows its value. Values show in two places:
- at the machine: as a make cost in its list, or as a value when the item is in its bay;
- on the HUD, when the hose swallows something.

The slice's unidentified salvage (§1.1) plugs in later. An unidentified thing's value stays unknown
until the machine reads it, and it cannot be made until it is identified.

---

## 5. The ship

### 5.1 Blocks

| Block | Category | Occupancy | Mass | Power | QE capacity |
|---|---|---|---|---|---|
| **`quantum_core`** (new) | Interior | MOUNT | 5 t | generates 36 MW at full power, 18 in low power | — |
| **`quantum_machine`** (new) | Interior | MOUNT | 0.5 t | draws 0.5 MW | — |
| **`quantum_cell`** (new) | Systems | SOLID | 5 t | — | 400 |
| `reactor` | *retired* | | | | |
| `battery` | *retired* (it has no function today and the starter has none) | | | | |

- The block count goes from 21 to 22.
- **The core and the machine are fixtures,** like the helm: each occupies a walkable cell and is
  drawn by the dressing (style guide §4, "A new fixture").
- **The quantum cell** is the reactor with its generation moved to the core: the same mass and hp.
- `BlockDefinition` gains `quantum_capacity: int`, in a "Quantum" export group.
- `ShipStats` gains `quantum_capacity`. `power_gen` now means the power the ship has at full power.

### 5.2 Validation

- **Rule 7 (error, `QUANTUM`):** a ship needs at least one quantum core, one quantum machine and one
  quantum cell. Without them it has no power, no way to gain QE, or nowhere to keep it, which is as
  fatal as having no pilot seat.
- **Rule 4** already holds both fixtures reachable on foot from the helm: every MOUNT must be.
- **Rule 5** (power margin, a warning) is unchanged.

### 5.3 The starter shuttle

```
 z \ x       −1             0              +1
  −4       canopy        canopy          canopy
  −3        deck       pilot_seat         deck            ┐
  −2        deck      quantum_core        deck            │ bridge
  −1        deck          deck       quantum_machine      ┘
   0      bunk_room       deck           galley
  +1      bunk_room       deck         weapon_room
  +2      bathroom        deck           closet
  +3      bulkhead       airlock         bulkhead
```

- **The quantum core** at (0, 0, −2), the centre of the bridge, straight behind the helm. It faces
  aft, so its gauge faces the corridor.
- **The quantum machine** at (1, 0, −1), the bridge's starboard back corner. It faces forward, with
  its back to the galley's wall.
- **The three reactors become quantum cells** in the same cells.
- **Nothing else moves.** Every room, the hull, the equipment deck and the airlock stay as they are.
- **The avatar now starts at (0, 0, −1).** It used to start one cell behind the helm, where the core
  now stands.

### 5.4 Measured

These figures were computed with `ShipStats`'s own arithmetic outside the engine, which reproduces
today's recorded figures exactly. The plan confirms them in Godot.

| | Today | With the core and machine |
|---|---|---|
| Blocks | 84 | 84 |
| Mass | 92,300 kg | 97,000 kg |
| Centre of mass | (0, 1.268, 0.325) | (0.002, 1.206, 0.118) |
| Inertia (million kg·m²) | 1.82, 2.65, 1.06 | 1.91, 2.74, 1.07 |
| Pitch imbalance under full burn | 101,408 N·m: **3.2%** of pitch authority | 9,278 N·m: **0.3%** |
| Yaw imbalance under full burn | 0 | 3,093 N·m: 0.15% of yaw authority (the machine stands starboard) |
| Torque budget (N·m) | 3,162,514 / 2,081,257 / 2,183,099 | 3,058,763 / 2,029,381 / 2,198,454 |
| Peak turn acceleration, pitch / yaw / roll | 99.6 / 45.0 / 117.6 °/s² | 91.7 / 42.5 / 117.2 °/s² |
| Forward acceleration | 16.3 m/s² | 15.5 m/s² |
| Power | 36.0 generated / 30.8 drawn MW | 36.0 generated at full power / 31.1 drawn |
| QE capacity | — | 1,200 |

**The core's weight evens out the ship.** Its 5 t at cabin level lower the centre of mass to
1.206 m. That is almost exactly the average height of the ship's thrust: 1.2 m, from two pods at
0 m and three stern thrusters at 2 m. So a full burn barely pitches the ship at all. The ship is 5%
heavier; assist still reaches its turn rates within about a second.

The core also moves toward the open "two bells or five" question (SLICE-1-STATUS). That question
needs heavy equipment brought down to cabin level, which is what the core is. It is not enough on
its own to settle the question.

### 5.5 Alternatives considered

- **A deck-weight core** (0.4 t): nothing moves at all, but the heart of the ship weighs what a
  floor plate does (§2, row 12).
- **The machine on a flank wall,** facing the core across the bridge: it would cover a porthole.
- **An engine room** (the drafts of 2026-09-24 and 2026-09-25): first a ship one row longer with a
  three-cell room, then the port rooms moved forward to free a single cell. The owner superseded
  both: the bridge has the space, and no new room is needed.

---

## 6. The core and the machine on the bridge

### 6.1 Placement

- **Both are fixtures.** `InteriorDressing.draws_fixture` gains both ids, and each is built from its
  fixture frame, as the helm is. A blueprint places them like any block.
- **They do not reshape the bridge.**
  - Today any fixture makes its own cell and its neighbours bridge (the mauve floor) and turns their
    windows into consoles. That rule was written when the helm was the only fixture.
  - The zone and console rules now skip the quantum fixtures (`InteriorLayout.QUIET_FIXTURES`), so
    the starter's floors, consoles and portholes stay exactly as they are.
  - A fixture's own cell keeps plain walls, as the helm's does, so nothing else stands where it
    does.
- **The core stands at its cell's centre.** It takes the place of its cell's round ceiling light:
  its crown carries that cell's warm light (role `&"cell"`), so every cell still has exactly one.
- **The machine stands against a wall.** It builds in the frame of the wall at its back, the one its
  orientation turns away from. In the starter that is the galley's partition wall behind
  (1, 0, −1). The cell's starboard porthole stays.
- **Walking round the core:**
  - its footprint is 1.2 m across, so the straight walk from the corridor to the helm now steps round
    it, through (±1, 0, −2);
  - more than 1.0 m stays clear on either side (style guide §3.1's aisle);
  - the chair is reached as before.

### 6.2 The quantum core

`InteriorProps.quantum_core(kit, f, variety)` builds the fixed parts. A `QuantumCore` node, like
`AirlockHatch`, owns the moving parts and knows nothing about ships.

**Fixed:**
- an octagonal plinth 1.2 m across and 0.25 m tall, with a glowing base;
- a glass column 0.9 m across, from 0.35 m to 2.15 m up, in the `GLASS` batch;
- a crown at the ceiling, 1.1 m across, following `HEADROOM`, with two conduits rising into it and
  the cell's light beneath it;
- a slim spine on the core's facing side, carrying the gauge.

Collider: a box 1.1 m square, the full height.

**Moving (`QuantumCore`):**
- **The heart:** a faceted ball, 0.3 m in radius, at 1.25 m, in `QUANTUM` on the glow batch. It
  turns and breathes (scale ±4% at the pulse rate).
- **Three rings** round it, 0.34–0.42 m in radius, in `TRIM` with a `QUANTUM` inner edge, each
  turning on its own axis.
- **The gauge:** ten chunky bars up the spine. The lit bars show how full the store is. The lowest
  bar is the low-power line (10% of capacity), and it turns `AMBER` when it is all that is left.
  At 0 it stays lit amber at half brightness, so the gauge never reads as dead.
- **`flash()`:** a short brightening when QE arrives.

**States:**

| State | Rings | Pulse | Heart and bars |
|---|---|---|---|
| Full power | 0.25 rev/s | 0.5 Hz | glowing |
| Boosting | ×3 | 2 Hz | glowing |
| Low power | 0.05 rev/s, a crawl | 0.2 Hz | dim, as all glow is in low power (§8.3); the lowest bar amber |
| Restoring | spinning up to full over 1.5 s (§8.3) | rising | flaring |

**Light:** the crown's cell light, `LIGHT_WARM` like every cell's. The violet is glow, not light.

### 6.3 The machine

`InteriorProps.quantum_machine(kit, f, variety)`, built in the frame of the wall at its back:
- **The cabinet:** 1.5 m wide, 2.0 m tall, 0.6 m deep. `TRIM` body, `WALL_LOW` base, glowing plinth.
  It leaves 1.4 m clear in front of it.
- **The bay,** 0.9–1.5 m up, left of centre:
  - a 0.6 m square recess with a lit `QUANTUM` ring round its mouth and a glowing disc for a floor;
  - an item in it floats at the centre, turning slowly (10°/s);
  - the cabinet's colliders are built round the recess, so the Interactor can reach what sits
    there (style guide §3).
- **The screen** above the bay: live data (§7, style guide §2.8).
- **Three buttons** in a column right of the bay: ◀, the big button, ▶.
- **The charge plate** at the cabinet's right-hand end: a round hand plate 0.22 m across at 1.2 m,
  in a bevelled ring, lit `QUANTUM` when ready.
- **A conduit** from the cabinet's top, along the ceiling to the core's crown, about 2.3 m away on
  the starter. The bead runs along it (§7.5).
- **It publishes frames** in its own frame: `quantum_machine_bay()`, `quantum_machine_screen()`,
  `quantum_machine_buttons()`, `quantum_machine_plate()` and `quantum_machine_conduit()`.

### 6.4 How it is built

- The props stay grid-blind (style guide §3).
- **For each core,** `InteriorDressing` builds a `QuantumCore`.
- **For each machine,** it builds a `QuantumMachine` node, as it builds `AirlockRoom`. The node holds:
  - a `QuantumBay` at the bay frame;
  - the panel and the two arrow buttons;
  - a `ChargeDock` (the plate's interactable) at the plate frame;
  - the conduit path to the nearest core;
  - the machine's cell.
- `InteriorBuilder.quantum_cores()` and `quantum_machines()` return them, as `airlock_rooms()` does.

---

## 7. The machine in use

### 7.1 Converting

1. **Drop an item into the bay:** aim at the bay and press G. Grasp's stow on drop already does this
   (hands-and-items spec §7.4). `QuantumBay` extends `StowPoint` and accepts any item that has a
   value, fits (largest side ≤ 0.55 m) and is under the 40 kg lift limit. A crate or a toolbox fits.
2. **The screen reads** *CONVERT · CRATE*, then *+30 QE*, then *STORE 600 QE*.
3. **The big button reads** *Convert Crate (+30 QE)*. Pressing it takes 1.2 s:
   - the item glows and shrinks to a point;
   - a bead of light runs along the conduit to the core;
   - the store is credited when the bead arrives, and the core flashes.
4. **Refused** if the value will not fit in the store: *STORE FULL*, with a coral button.

Until you convert it, the item is simply stowed. Its own prompt (*Take Crate*) takes it back out.

### 7.2 Making

- **With the bay empty,** the screen reads *MAKE · MUG*, *COST 6 QE*, *STORE 600 QE*. ◀ and ▶ step
  through everything it can make, sorted by cost.
- **Pressing the big button** debits the cost at once. Over 1.5 s a violet point in the bay swells
  into the item, which floats there, stowed. Take it.
- **A make that would drop the ship into low power warns first.** The third line reads
  *→ LOW POWER* in place of the store, and the button is `AMBER`. Pressing it still makes the
  item: being careful is the player's job.
- **Refused:**
  - with *NOT ENOUGH QE* if the cost is more than the store holds;
  - with *MAKE · LOW POWER* while the ship is in low power (§8.3).

### 7.3 Charging the suit

- F at the plate: *Charge suit (+86 QE)*.
- The suit charges at 50 QE/s, up to 100, while you stay within 1.2 m of the plate.
- While charging: the plate glows, the machine's screen counts up (*SUIT 64%*) and a tone rises. A
  chime sounds when the suit is full.
- Charging works in low power, and may take the store down to 0 (§3.2). The pilot light then
  brings it back to 25.

### 7.4 How it is built

`MachineCycle` is a pure `RefCounted`, like `AirlockCycle`:
- **Stages:** `IDLE`, `CONVERTING`, `MAKING`.
- **`press(button)`** takes `&"big"`, `&"prev"` or `&"next"`.
- **`step(delta, bay, store)`** returns cues in order:
  - `&"convert_start"`, `&"bead"`, `&"credited"`;
  - `&"make_start"`, `&"materialized"`;
  - `&"refused"`.
- **Pure functions** give the prompts, the three screen lines and the button colour:
  - `SIGNAL_GO` when pressing will do something;
  - `AMBER` while working, and for a make that will drop the ship into low power;
  - `CORAL` when refused: store full, not enough QE, or low power.

`QuantumPlant` keeps one cycle per machine, keyed by the machine's cell, so a rebuild never drops an
item mid-conversion. The bay's item re-seats through the existing re-seat on rebuild
(hands-and-items spec §5.3).

### 7.5 The show

All of it uses the kit, built-in particles and plain materials. There is no new shader.

- **Sparkles:** built-in particles (chunky puffs in `QUANTUM`, unshaded, with a near-camera fade)
  in the bay during a convert or make.
- **The bead:** a glow ball moving along the conduit path over 0.6 s.
- **A flash:** a warm light (`LIGHT_WARM`, energy 0.6) for 0.2 s.
- **The item's shrink and swell** animate by scale, as `ImpactFlash` does, so no shared material
  is modified.

---

## 8. The core and flight

### 8.1 Full power

At full power, `FlightComputer` flies exactly as today and spends no QE.

### 8.2 Boost

- Boost costs **5 QE/s** while it is held with translation input. Boost multiplies thrust, so
  holding it with no thrust costs nothing.
- **Boost cuts out when the store crosses the low-power line,** and stays off in low power. The
  HUD reads *BOOST · LOW POWER*. Nothing warns before a boost crosses the line: the core's amber
  bar and the falling store on the HUD are the warning.
- The core's rings turn three times as fast while you boost (§6.2). You feel it behind the chair
  rather than see it; the HUD shows the store falling.

### 8.3 Low power

**In low power** (the store below 10% of capacity, including at 0):
- **The ship limps.** The core gives half its `power_gen`, and `FlightComputer` scales every
  thruster's force and every torque by `LOW_POWER_AUTHORITY` (0.5). The ship still flies, turns
  and brakes, at half the acceleration. The assist still reaches its target rates, but more
  slowly.
- **The extras are off:** boost (§8.2) and making (§7.2).
- **Still working as always:** converting, charging the suit, the airlocks and gravity.
- **Emergency light:**
  - cell lights at 30% of their energy;
  - the shared glow material's `energy` at 35% (the uniform `glow.gdshader` already has);
  - the core at a crawl, its heart dim (§6.2);
  - its hum lower and quieter.
- **The HUD** reads *LOW POWER* in `WARNING` (§12).

**Dropping into low power** takes 1 s. The `core_down` sound plays, and the lights and glow fall
together to the emergency levels.

**Power restored** (the store back at the line) takes 3 s:
1. the rings spin up over 1.5 s and the heart flares;
2. the ship's lights come back cell by cell outward from the core, 0.1 s per cell of walking
   distance;
3. the glow comes back last, with the `core_up` sound.

A crossing mid-sequence reverses from where it has got to, so the lights never jump.

**This build has no dark state.** At 0 the ship is simply in low power, and the pilot light
(§3.2) starts refilling it. Whether damage can put a core out altogether is Slice 2's question
(§8.4).

### 8.4 Later spenders (hooks, not built)

| Spender | Slice | Shape |
|---|---|---|
| Quantum jump | 5 | Cost grows with distance and ship mass; the jump layer between systems |
| Shields | 2 | Absorb hits by spending QE. A drained ship drops into low power: half its authority, no boost. Slice 2 decides whether damage can also put a core out, which would be the crippled state (slice roadmap). |
| Turret weapons | 2 | Per shot, from the store; off in low power |
| Repairs, the shipyard | 1 (Phase C), 5 | Blocks cost QE to build or mend |

This puts QE at the centre of the core loop (slice spec §1). Draining an enemy's store leaves it
limping and toothless. A captured ship's store is loot. A derelict is a ship found in low power
with an almost empty store, and you can take it without a fight by feeding its machine.

---

## 9. The suit cell

- **`SuitCell`:** a charge from 0 to 100 QE. It starts **empty**.
- **Cost:** 1 QE per m/s of Δv the thrusters deliver, suit assist included. That is 2.5 QE/s at full
  thrust. Holding station beside a drifting ship costs almost nothing.
- **Warnings** on the HUD and the suit's chime: amber at 25, coral at 10.
- **Running dry:**
  - the thrusters stop, and the emergency cell takes over;
  - it steers you at 1.5 m/s to a point 1.5 m outside your airlock's outer hatch and holds you
    there, at no cost;
  - the HUD reads *SUIT DRY · RETURNING*;
  - you can still look around; press the hull panel and float in as usual.
- **The airlock's room panel will not depressurize** while your suit holds under 10 QE. Its status
  reads *CHARGE SUIT* and its prompt *Charge suit first*. This is the airlock's first refusal in
  open space (airlock spec §12 anticipated refusals).
- **The hose costs the suit nothing.** It runs on ship power through the line.

---

## 10. Things in space

### 10.1 Items outside

- **An item can live in the world.** `Item.set_space(true)`:
  - switches its look to render layer 1, lit by the sun;
  - sets its collision mask to `1 | 4 | 32 | 64`: hull, avatar, items and rocks, matching
    `AsteroidBody`'s mask, which already includes items.

  `set_space(false)` undoes both. There is no felt gravity outside, and project gravity is zero.
- **Whoever parents an item outside decides how it follows the floating origin,** because a
  member must never sit under another member, which would shift it twice (asteroids spec §4.2):
  - **free salvage** lives directly under `SalvageField`, a plain node under `Outside` at the
    identity that is never moved and is not a member itself. `SalvageField` puts each item it
    spawns in `Universe.EXTERIOR_SPACE`, and takes it out before freeing it;
  - **the hose nozzle** is never a member. It always lives under the reel on the hull, or in your
    hands, and both are already shifted (§11.1).

  `test_floating_origin_scene.gd` catches an item that is neither.
- **A 40 kg item cannot noticeably move a 97 t hull.**
- **Hands aboard are unchanged,** and hands outside take only EVA tools (§11.2). While your hands
  are suspended, salvage shows no *Take* prompt. Carrying salvage aboard by hand is a later spec.

### 10.2 The salvage field

`SalvageField` owns every salvage cloud. Each cloud has an id, a centre as a `UniversePoint`, and
a list of salvage items, each with an index, a kind, a pose and a tumble. **Everything about a
cloud comes from the world seed and its id**, through `AsteroidRecipe`'s integer hash
(`cell_seed`, `mix`), so a cloud is the same every time it loads, on any machine.

- **The near cloud** (id `&"near"`): 12 items, 12–40 m aft of the starter's stern along the
  airlock's line, so the first spacewalk has something to gather. Its centre is fixed as a
  `UniversePoint` when the scene starts. It sits inside the 80 m the start keeps clear of rocks.
- **A cloud at every asteroid group:** one per big rock, keyed by the big rock's giant cell (the
  5 km region):
  - its centre lies in a seeded direction from the big rock's centre, 40–120 m off its surface;
  - its 10–16 items scatter within 25 m of the centre;
  - **every item is kept clear of every rock**, by the recipe's bounding-sphere test against the
    rubble and mid-size cells it touches, and the big rock itself; a rejected candidate is simply
    not placed, as in the recipe (asteroids spec §5.4);
  - **half the groups hold one quantum shard,** chosen by the seed.

  The start's own big rock has a cloud too, somewhere round it: 600 m to 1.4 km from where you
  begin, so its region shows from the first frame.
- **Loading:** a cloud's items are spawned when the focus comes within 3 km of its centre, and
  freed when it goes beyond 4 km. Only clouds within 3 km have nodes.
- **Motion:** each item tumbles in place at up to 20°/s and **does not drift.** It moves only
  when something pushes it: the hose, you, or the ship. Rocks become bodies only near you and the
  ship (the asteroid bubble), so an item left drifting could pass into a rock that is still only a
  picture, and overlapping bodies fly apart.
- **The mix,** by weight: rock chunk 4, scrap plate 3, ice chunk 3, wire coil 2, broken module 1.
- **Rocks that move.** Clearance is tested against the recipe's positions. A rock you have
  shoved about may drift onto a cloud's seeded place. This is accepted as rare (§19): few rocks are
  ever shoved, and those drift slowly.

### 10.3 The ledger

- **`SalvageLedger`** remembers every salvage item taken, by cloud id and index. A cloud that
  loads again leaves those out, so **nothing taken comes back.**
- **What counts as taken:** swallowed by the hose. Nothing else removes salvage in this build.
- **Something pushed but not taken** returns to its seeded place when its cloud next loads.
- **`remaining(cloud_id) -> int`** tells the marker whether a cloud still holds anything.
- The ledger lives for the session, owned by `SalvageField`. Saving it is a hook (§17).

### 10.4 Finding salvage

Salvage is 0.2–0.5 m across and invisible from a few hundred metres. The owner chose a marker that
is vague far off and becomes a region you search close by.

- **`SalvageSense`** is pure. From your universe position, a cloud's centre, its id and the time,
  it returns one of three readings:

  | Distance to the cloud's centre | Reading | What the HUD shows |
  |---|---|---|
  | 2–10 km | **A ping** | A soft marker in the cloud's rough direction, accurate to ±10°. It refreshes every 4 s, with a new seeded error each time, and fades between refreshes. It reads *SALVAGE ~4 KM*, to the nearest kilometre. |
  | within 2 km, outside the region | **A region** | A ring on screen round a sphere 150 m across (radius 75 m). The sphere's centre is offset from the cloud's by up to 50 m, seeded per cloud, so the whole cloud (every item within 25 m of its centre) always lies inside it, but seldom at its middle. It reads *SALVAGE 640 M*, the distance to the sphere. |
  | inside the region | **Nothing** | The marker fades out, and you look. |

- **The nearest three clouds** that still hold something (`SalvageLedger.remaining`) are shown.
  Within 10 km there may be fifteen groups, and three avoids clutter.
- **Pings need no loaded items.** `SalvageField.known_clouds(focus, range)` lists every cloud
  within range from the recipe and the ledger alone: the near cloud, and each big rock's cloud in
  the giant cells round the focus. The list is refreshed when the focus crosses into a new giant
  cell, not every frame.
- **Through the ship's sensors.** `SalvageField` is a sensor source: `contacts(focus, range,
  time)` gives one `Contact` per cloud with something left, carrying its `SalvageSense` reading
  (a ping, or a region, including when you are inside it), and `contact(id, focus, time)` looks
  one up by id. `ShipSensors` (`Ship/Sensors`) gathers the contacts of every source it is given.
  The flight scene registers the field. The bridge computer's map reads the same contacts
  (bridge computer spec §4).
- **Seated and on a spacewalk.** `SalvageMarker` is a `HudElement` using the airlock marker's
  screen-edge logic (`VelocityMarker.resolve`), so a ping behind you pins to an edge the same way.
  It reads the salvage contacts from the ship's sensors, never from the field directly. On foot
  aboard, the HUD stays dark as now.
- **A glint:** every salvage item flashes a small warm glint for 0.15 s every 2–4 s, seeded, as if
  it caught the sun. It is an unshaded billboard quad in `InteriorPalette.LIGHT_WARM`, visible to
  about 50 m and fading out by 60 m. The quantum shard glows as well, on the glow batch.

### 10.5 Salvage kinds

Six new item kinds. Each is a `.tres`, a look in `ItemLooks` and a value (§4.2). All are WIELD
except the scrap plate (CARRY).

| Id | Size (m) | Look |
|---|---|---|
| `rock_chunk` | 0.20 × 0.16 × 0.18 | a faceted lump in `WALL_LOW` |
| `ice_chunk` | 0.20 × 0.18 × 0.20 | a faceted pale lump, new `ICE` |
| `scrap_plate` | 0.50 × 0.04 × 0.35 | a bent bevelled plate in `TRIM` with a torn `BELT` stripe |
| `wire_coil` | 0.20 × 0.08 × 0.20 | a chunky torus, new `COPPER` |
| `broken_module` | 0.25 × 0.06 × 0.18 | the spare module's look, cracked, its light dead |
| `quantum_shard` | 0.08 × 0.20 × 0.08 | a faceted crystal in `QUANTUM` on the glow batch |

---

## 11. The hose

### 11.1 The reel

- **Where:** on the airlock's outer face, on the jamb opposite the hull panel.
- **What:** a drum 0.5 m across with a cradle holding the nozzle, in `HullPalette` with a new `HOSE`
  colour.
- **Built by `AirlockAlcove`**, on the own-hull layer, with the rest of the hatch face.
- **The nozzle is an item** (`hose_nozzle`, WIELD, an **EVA tool**) stowed on the reel's stow point.
  Its prompt is *Take Hose nozzle*. The spacewalking Interactor's mask gains the items layer
  (16 → 16 | 32).
- **Where the nozzle lives:** under the reel while docked or winding home, and in your hands while
  held. It is `set_space(true)` from its first build, and never a floating-origin member itself
  (§10.1).

### 11.2 Holding it

- **Grasp's `suspended`** (airlock spec §7.4) now lets EVA tools through. Outside, you can take, hold
  and use the nozzle, and nothing else.
- **The hands** use the Grip pose.
- **Letting go in any way** returns the nozzle to the reel, which winds it home along the line over
  1 s. The ways are:
  - G;
  - a throw;
  - crossing back in (it is let go first);
  - the suit running dry.

### 11.3 The line

- **`HoseLine`:** a verlet rope of 40 segments from the reel to the nozzle's tail, drawn as chunky
  ribbed segments on render layer 1. It has zero gravity and is damped. It does not collide.
- **It obeys the floating origin.** The `HoseLine` node lives under `Outside` and is a member of
  `Universe.EXTERIOR_SPACE`. Its rope points are kept in its own frame, so a shift carries them with
  it. Each tick it reads the reel's anchor and the nozzle's tail afresh, and converts them into
  that frame.
- **30 m long.** At full length the tether holds you: outward velocity is removed and a 1 m/s² pull
  draws you back. The tether reads its anchor from the reel every tick, so a shift never leaves it
  pulling toward a stale point.

### 11.4 Suction

- **Hold `use`:** a cone 8 m long with a 15° half-angle, widened by half each item's largest side
  (the forgiving-aim rule, hands-and-items spec §7.2).
- **Items in the cone** are woken and pulled toward the mouth:
  - at up to 6 m/s², but no more than 120 N of force, so a 40 kg item comes at 3 m/s²;
  - with sideways drift damped, so they funnel in;
  - at no more than 5 m/s.
- **Within 0.35 m of the mouth, an item is swallowed:**
  1. it freezes and shrinks into the mouth over 0.25 s;
  2. the ship's store is credited;
  3. the item emits `consumed`, and `SalvageField`, which listens to every salvage item it
     spawns, records it in the ledger (§10.3);
  4. the HUD shows *+12 QE · ICE CHUNK*.
- **Refusals:** a thing too big (over 0.6 m or 40 kg) is not pulled, and the prompt reads *Too big*.
  With the store full, suction stops and the prompt reads *Store full*.
- **The show:** the mouth glows `QUANTUM` while drawing, and each swallow gulps. The nozzle's
  particles are local to it. Any that are emitted in world space join `Universe.HOLDS_SHIFT`.
- **Suction costs no QE,** and works in low power: gathering is how you climb back out.

---

## 12. HUD

- **`VehicleTelemetry`** gains:
  - `has_energy`, `energy`, `energy_capacity`, `energy_line` (the ship's low-power line; 0 for the
    suit) and `energy_label` (*QE* or *SUIT*);
  - `energy_state`: for the ship `&"full"` or `&"low_power"`; for the suit `&"ok"`, `&"low"`,
    `&"critical"` or `&"dry"`;
  - `boost_refused` and `tool_text`.

  Each vehicle fills them through the same duck-typed `build_telemetry()`.
- **`EnergyPanel`**, a `HudElement` in the band:
  - seated, it shows the ship's store: *QE 600*, with a bar, a notch at the low-power line and
    *BOOST −5/S* while boosting;
  - in low power, *LOW POWER*, and *BOOST · LOW POWER* when you try to boost;
  - on a spacewalk, it shows the suit (*SUIT 64%*) and, with the hose in hand, *HOSE 12 M* (the line
    paid out);
  - it uses `HudPalette`: the readout colour normally, `WARNING` in low power and when the suit is
    low, critical or dry.
- **`SalvageMarker`**, a `HudElement` (§10.4), created in code as the reticle is. The flight scene
  binds it to the ship's sensors, and it draws their salvage contacts each frame. It shows
  whenever you are seated or on a spacewalk.
- **`QuantumToast`**, a `HudElement` near the reticle, created in code as the reticle is:
  *+12 QE · ICE CHUNK*, rising and fading over 1.2 s.
- **Aboard on foot the HUD stays dark,** as now. The core's gauge and the machine's screen are the
  instruments there.

---

## 13. Sound

Every sound is a new `Synth` builder (style guide §2.9):

| Sound | What it is | Where |
|---|---|---|
| `core_hum` | two soft detuned sines, beating slowly; its pitch lifts while boosting | looped, positional at the core, Ship bus |
| `convert` | a rising shimmer: filtered noise swept up, a sine glide, a soft pop | the bay |
| `materialize` | the same, falling, ending in a soft thump | the bay |
| `charge` | a rising tone, looped while charging; a small chime at full | the charge plate |
| `core_down`, `core_up` | spool down, spool up | the core |
| `hose_draw` | low filtered noise, looped while suction runs | Suit bus |
| `hose_gulp` | a short soft thunk | Suit bus |

The core's hum sits under the bridge. Keep it quieter than the ship's air-handling hum, so the
bridge stays calm.

**A style amendment:** on a spacewalk you hear your breathing, your thrusters, the warning chime
**and the tool in your hands**, carried through the suit.

---

## 14. Architecture

```
                       ShipStats.quantum_capacity               QuantumBay (StowPoint)
                                  │                                 │  item dropped in
 FlightComputer ◄── power, boost ─┤                                 ▼
                                  ▼                 ┌──────── MachineCycle (pure) ◄── panel buttons
 Avatar/SuitCell ◄── charge ── QuantumPlant ────────┤
   (spends Δv)       (plate)   owns: QuantumStore   └──────── QuantumCore (gauge, states)
                                  ▲      │ full / low power
 HoseNozzle ── swallow ───────────┘      └────► Ship: emergency light, power restored
   │ (EVA tool, on HoseLine from HoseReel on AirlockAlcove)
   │ item.consumed
   ▼
 SalvageField ── owns: SalvageLedger ── SalvageSense (pure) ── contacts ──► ShipSensors ──► SalvageMarker
   (clouds from AsteroidRecipe's big rocks; items spawned within 3 km, members of EXTERIOR_SPACE)
```

- **`QuantumPlant` is the only thing that knows a ship has QE.** It is a `Node` under `Ship`,
  created in code like `Airlocks`, and lives across rebuilds.
- **`ShipSensors` is the only thing the HUD asks about what is out there.** It is a `Node` under
  `Ship`, created in code, holding the sources the flight scene gives it. The ship knows nothing
  about salvage.
- **`SalvageField` is the only thing that knows where salvage is.** It is a `Node3D` under
  `Outside`, created in code by the flight scene. It keeps its own `AsteroidRecipe` made with the
  stream's seed (a recipe's cache is not shared), and reads the `Universe`.
- **Everything visual knows nothing about ships:** `QuantumCore`, `QuantumShow`, `ChargeDock`,
  `HoseLine` and the props. Each takes a frame, a size or a body, as `AirlockHatch` does.
- **Everything with rules is pure and tested headless:** `QuantumStore`, `MachineCycle`,
  `SuitCell`, `Tether`, `QuantumValues`, `SalvageLedger` and `SalvageSense`.
- **Items still know nothing about ships or salvage.** The hose credits the store through a sink
  callable that the airlock wires to the reel. A converted or swallowed item emits `consumed`
  before it is freed, and whoever cares listens.

### 14.1 Files

```
src/quantum/
  quantum_store.gd     QuantumStore: amount, capacity, the low-power line, spend/credit/drain,
                       the pilot light (pure)
  quantum_values.gd    QuantumValues: constants, make cost, fits-the-bay (pure)
  machine_cycle.gd     MachineCycle: the machine's state, cues, prompts, screen (pure)
  suit_cell.gd         SuitCell: charge, Δv cost, warnings, dry (pure)
  tether.gd            Tether: the hose's pull at full length (pure)
  quantum_plant.gd     QuantumPlant: one per ship; owns the store; binds the fixtures
  quantum_core.gd      QuantumCore: the core's moving parts and gauge
  quantum_machine.gd   QuantumMachine: what the dressing built for one machine (references)
  quantum_bay.gd       QuantumBay extends StowPoint: accepts anything that fits
  charge_dock.gd       ChargeDock: the hand plate, an interactable
  quantum_show.gd      QuantumShow: sparkles, bead, flash
  hose_reel.gd         HoseReel: the reel's stow point, winding the nozzle home
  hose_nozzle.gd       HoseNozzle extends ItemUse: suction and swallowing
  hose_line.gd         HoseLine: the rope and its look
src/ship/interior/readout_panel.gd   ReadoutPanel: AirlockPanel's body, button and readout,
                                     extracted so the machine can share them
src/world/
  salvage_field.gd     SalvageField: the clouds, loading and freeing their items, known_clouds
  salvage_ledger.gd    SalvageLedger: what has been taken (pure)
  salvage_sense.gd     SalvageSense: a cloud and your position to a ping, a region or nothing (pure)
src/sensors/
  contact.gd           Contact: one thing the ship knows about (pure)
  ship_sensors.gd      ShipSensors: the sources, a 4 Hz contacts cache
src/ui/energy_panel.gd, src/ui/quantum_toast.gd, src/ui/salvage_marker.gd
data/blocks/quantum_core.tres, quantum_machine.tres, quantum_cell.tres
           (reactor.tres and battery.tres removed)
data/items/rock_chunk, ice_chunk, scrap_plate, wire_coil, broken_module, quantum_shard,
           hose_nozzle (.tres)
```

**Modified:**
- **Blocks and the ship:**
  - `block_definition.gd`: `quantum_capacity`;
  - `ship_stats.gd`: `quantum_capacity`;
  - `ship_validator.gd`: Rule 7;
  - `ship.gd`: `QuantumPlant`, emergency light, power restored;
  - `flight_computer.gd`: low power's authority, and boost's cost.
- **Items:**
  - `item_definition.gd`: `quantum_value` and `eva_tool`;
  - every item `.tres`: a value;
  - `item.gd`: `set_space` (layers and mask) and the `consumed` signal;
  - `item_looks.gd`: seven looks;
  - `item_use.gd`: a `hold(active)` hook with a quiet default.
- **The avatar:**
  - `grasp.gd`: EVA tools pass `suspended`; `use` held and released;
  - `avatar.gd`: the suit cell, Δv cost, the dry return;
  - `suit.gd`: a pure `home_step`;
  - `interactor.gd`: the spacewalk mask.
- **The interior:**
  - `interior_layout.gd`: `QUIET_FIXTURES`;
  - `interior_dressing.gd`: the two fixtures, the wall-standing frame, the core cell's light;
  - `interior_props.gd`: two props and their frames;
  - `interior_builder.gd`: `quantum_cores()` and `quantum_machines()`;
  - `interior_palette.gd`, `hull_palette.gd`: the new colours.
- **The airlock:**
  - `airlock_alcove.gd`: the reel;
  - `airlock.gd`: the empty-suit refusal, letting go of the nozzle at the threshold, and wiring
    the reel's sink;
  - `airlock_panel.gd`: extends `ReadoutPanel`.
- **HUD, sound and the scene:**
  - `vehicle_telemetry.gd`;
  - `synth.gd`;
  - `flight_test.gd`/`.tscn`: the starter grid, the spawn, the salvage field and the HUD.
- **The floating origin's test:** `test_floating_origin_scene.gd` walks the scene with salvage
  loaded and the hose out.

### 14.2 Layers

No new physics or render layers. The last column says how each thing outside follows the floating
origin (§10.1, §11.3).

| Thing | Physics layer | Mask | Render layer | Floating origin |
|---|---|---|---|---|
| An item aboard | 6 (32) | 2 \| 4 \| 32, as now | 2 | never moves |
| Free salvage | 6 (32) | 1 \| 4 \| 32 \| 64 | 1 | a member, joined by `SalvageField` |
| A salvage item's glint | — | — | 1 | under its item |
| The machine's buttons and charge plate | 2 (`interior_geometry`), like the airlock panels | — | 2 | never moves |
| The reel and the docked nozzle | on the hull | — | own hull (4), like the alcove | under the hull |
| The hose nozzle | 6 (32) | 1 \| 4 \| 32 \| 64 | 1 | under the reel or your hands; never a member |
| The hose line | — | — | 1 | a member; points in its own frame |
| The Interactor on a spacewalk | — | 16 \| 32 | — | — |
| Suction | a shape query on 32 | — | — | — |

### 14.3 Palette

- **`InteriorPalette` gains:**
  - `QUANTUM`, a soft luminous violet;
  - `QUANTUM_DEEP`, the unlit heart and the gauge's dark bars;
  - `ICE` and `COPPER`.
- **`HullPalette` gains** `HOSE`.
- **`HudPalette` is unchanged.**

Values are pinned by rendering. Adding palette entries is not a rule change.

**Beside the veined rocks.** The asteroids' crystal veins are already `SpacePalette.CRYSTAL`,
which is `InteriorPalette.LAVENDER`. If QE is violet, the veins will read as quantum ore, which
is a fair hook for mining later (§17). Task 3's renders put `QUANTUM` beside a veined rock, so the
owner chooses knowingly.

---

## 15. Testing

### 15.1 Automated (GUT, headless, output pristine)

- **`test_quantum_store.gd`:**
  - the low-power line is 10% of capacity, rounded up; low power below it, full power at it;
  - spends are all or nothing, and may take the store to 0;
  - boost and making are refused in low power, and a suit charge and a drain are not;
  - the pilot light: below 25 it credits 1 QE every 5 s, stops at 25, and never adds above it;
  - a credit over capacity is refused;
  - a new capacity clamps the amount;
  - continuous costs debit whole QE at the right times.
- **`test_quantum_values.gd`:** make cost is twice the value; what fits the bay; every item `.tres`
  has a value, and only EVA tools have 0.
- **`test_machine_cycle.gd`:**
  - convert and make, with their timings and cues in order;
  - the credit lands on `&"credited"`, not before;
  - the refusals: store full, not enough QE, low power;
  - a make that would cross the low-power line warns (*→ LOW POWER*, `AMBER`) and still makes;
  - ◀ and ▶ step through every item with a value, EVA tools left out, sorted by cost, and wrap;
  - prompts, screen lines and button colours for each state.
- **`test_suit_cell.gd`:** the Δv cost; warnings at 25 and 10; dry at 0; charging to capacity.
- **`test_suit.gd`** (extended): `home_step` heads for the hold point at 1.5 m/s and holds there.
- **`test_tether.gd`:** slack does nothing; taut removes outward velocity and pulls back.
- **Blocks and stats:**
  - `quantum_capacity` sums;
  - `reactor` and `battery` are gone;
  - **the starter's figures pinned as measured in §5.4.**
- **Validator:** Rule 7 fixtures: no core; no machine; no cell; all three. Existing fixtures gain
  all three, so their own rules stay isolated.
- **Layout:**
  - the quantum fixtures are listed as fixtures;
  - **the starter's zones and wall variants are exactly today's,** except the machine cell's back
    wall, which goes plain.
- **Props:** both build in bare frames; pinned collider counts; the bay is clear of the machine's
  colliders.
- **`QuantumCore`:** the gauge lights the right number of bars for a fill; the lowest bar turns
  amber at the line and stays lit at 0; the states.
- **Dressing:**
  - the starter has one `QuantumCore` and one `QuantumMachine`, with every reference set;
  - the core's cell has no round ceiling light and exactly one cell light;
  - the machine stands against the wall at its back;
  - the conduit path runs from the machine to the core's crown.
- **The spawn:** the avatar starts at (0, 0, −1), clear of the core.
- **`QuantumPlant`:**
  - it binds across rebuilds without resetting;
  - the store starts at half, once;
  - dropping into the bay and converting credits the store;
  - making puts an item in the bay;
  - charging moves QE into the suit.
- **`FlightComputer`:**
  - low power halves every force and torque;
  - boost spends 5 QE/s, cuts out when the store crosses the line, and is refused below it;
  - a null store means free boost and full power, as today.
- **Items:**
  - `set_space` switches layers and masks both ways;
  - `consumed` fires once, before the item is freed;
  - the six salvage looks build.
- **`SalvageField`:**
  - the same seed and id give the same cloud;
  - the counts;
  - the near cloud's distances;
  - a group's cloud lies 40–120 m off its big rock's surface;
  - no salvage item's bounding sphere touches a rock's, over many groups;
  - shards in about half the groups;
  - items load within 3 km as `EXTERIOR_SPACE` members, and are freed beyond 4 km, with no
    orphans;
  - `known_clouds` lists clouds within range without spawning anything.
- **`SalvageLedger`:** a taken item stays out of a reloaded cloud; `remaining` counts down.
- **`ShipSensors`:** merges its sources nearest first; the 4 Hz cache; `SalvageField`'s contacts
  carry its readings, and a region contact stays while you are inside it.
- **`SalvageSense`:**
  - a ping beyond 2 km, within ±10° of the true direction, a new error every 4 s, the distance to
    the nearest kilometre;
  - a region within 2 km, 75 m in radius, whose centre is within 50 m of the cloud's and holds
    the whole cloud;
  - nothing inside the region;
  - only the nearest three clouds with something left.
- **The floating origin** (`test_floating_origin_scene.gd`, extended): with salvage loaded and the
  hose out, everything outside is covered; a shift keeps salvage, the hose line and the tether
  where they were relative to you.
- **Hose:**
  - the cone and its widening;
  - the force limit;
  - a swallow within 0.35 m credits through the sink;
  - too big and store full are refused;
  - letting go reels it home;
  - Grasp lets only EVA tools past `suspended`.
- **Airlock:** the empty-suit refusal of the room panel.
- **HUD:** the telemetry energy fields for ship and suit; `EnergyPanel`'s text and states;
  `SalvageMarker` draws a ping, a region and nothing from the sensors' contacts, and pins to the
  screen's edge.
- **`Synth`:** the seven new sounds build, are deterministic and are not silent.
- **`test_visual_style_rules.gd`** (extended):
  - the new painting files are held to palette colours;
  - `quantum_core.gd`, `quantum_show.gd`, `charge_dock.gd`, `hose_line.gd` and `readout_panel.gd`
    are held grid-blind;
  - the salvage glint's colour comes from the palette;
  - the shader set is still exactly three.

### 15.2 Real-scene probes and renders

- **Walk probe:**
  - from the start, round the core either side to the helm, and sit;
  - stand, walk to the machine, then down the corridor to the airlock;
  - the core's and the machine's colliders stop the avatar.
- **Machine probe:**
  - drop a mug in, convert it: the store +3;
  - make a mug: the store −6, and a mug in the bay;
  - take it;
  - try to overfill.
- **Suit probe:**
  - the room panel refuses with an empty suit;
  - charge, cycle out, thrust until dry;
  - be brought to the hatch;
  - come in.
- **Hose probe:**
  - take the nozzle and drift into the near cloud;
  - swallow three kinds, and the store rises by their values;
  - hit the tether at 30 m;
  - let go, and it reels home.
- **Low-power probe:**
  - seated, boost until the store crosses the line: boost cuts out, the lights drop, *LOW POWER*;
  - fly: half the acceleration, and the assist still settles;
  - walk to the machine: making is refused, converting works; convert until the line: power is
    restored cell by cell;
  - charge the suit until the store is at 0, and watch the pilot light bring it to 25.
- **Salvage probe:**
  - from the start, the first group's region shows; fly to it and the marker fades inside;
  - find the cloud by eye and by its glints, go out and swallow two items;
  - fly away past 4 km and back: those two are still gone, the rest are back where they began;
  - fly 6 km on to the next group, following its ping, across a floating-origin shift.
- **Renders at 1.6 m eye height,** sent to the owner:
  - the bridge from the corridor, with the core at its centre;
  - the bridge from the machine, and from beside the helm looking aft at the core;
  - the core at full power, at the line and in low power, beside a veined rock for the colour;
  - the bridge and the corridor in low power, and power restored mid-sequence;
  - the machine loaded and empty;
  - a convert and a make, mid-show;
  - the plate charging;
  - the seated view, unchanged, with the core behind you;
  - the reel on the hull;
  - a spacewalk with the hose drawing in junk;
  - the HUD seated and on a spacewalk, in low power, and with a ping and a region;
  - a group's cloud at 50 m, glinting.
- **Frame time** at 1280 × 720, against the 120 fps budget:
  - the bridge at rest, looking through the core's glass at the canopy;
  - mid-convert;
  - a spacewalk in the near cloud with the hose drawing;
  - seated at a group's cloud, with its items loaded and the big rock's swarm in view.

### 15.3 Playtest checklist

- Is the core the heart of the bridge? Does stepping round it ever get in the way?
- Does converting feel satisfying, and making feel like magic?
- Does the core's gauge read at a glance?
- Is boost's cost felt without being a nag?
- Does low power make you careful, or just annoyed? Is half power the right limp?
- Is a salvage walk worth its suit charge?
- Is finding a cloud a small, satisfying search, or a chore? Is the region the right size?
- Did you ever feel stranded? Did you ever wait for the pilot light?

---

## 16. Amendments to other documents

Applied with the code they describe:

- **Slice spec:**
  - **§5, the catalogue:** `reactor` and `battery` retire; `quantum_core`, `quantum_machine` and
    `quantum_cell` join.
  - **§6.1:** Rule 7.
  - **Roadmap:** Slice 2's shields and weapons spend QE; a drained ship limps in low power, and
    Slice 2 decides whether damage can put a core out. Slice 5's jumps and the shipyard cost QE.
- **Interior redesign §7.5:** the starter's bridge gains the core at (0, 0, −2) and the machine at
  (1, 0, −1).
- **Hands and items:**
  - **§15:** items in space now exist, as salvage.
  - **§16:** hands outside take EVA tools; carrying salvage aboard stays out of scope.
- **Airlock:**
  - **§7.4:** outside, the hands take EVA tools.
  - **§12/§13:** the empty-suit refusal. The suit's fuel is the suit cell.
- **Asteroids:**
  - **§4.4:** items in space follow the floating-origin rule, as members;
  - **§13:** items in space exist, as salvage round each group.
- **Planetfall §18:** a supply cache's manifest lines carry QE values. A `WRECK` site can be a
  derelict to feed.
- **Visual style guide:**
  - a §3.5 for the core and the machine:
    - fixtures that do not reshape the bridge;
    - a wall-standing fixture builds in the frame of the wall at its back;
    - the core's crown carries its cell's light;
    - the core as a gauge;
  - §2.8: the machine's screen joins the live-data screens;
  - §2.9: you hear the tool in your hands through the suit;
  - the new palette entries;
  - items outside, on layer 1 and lit by the sun, with their glint;
  - low power's emergency light, and power restored cell by cell;
  - the frame-time figures.
- **`SLICE-1-STATUS`:** a "what works" entry once built, with the new flight figures.

---

## 17. Hooks left open

- **Spenders:** jumps, shields, turret weapons, repairs and shipyard costs (§8.4).
- **The bridge computer and its map:** designed in
  `docs/superpowers/specs/2026-09-25-bridge-computer-design.md`, built after this. A holo table at
  (−1, 0, −1) shows the ship's sensor contacts and sets a course the HUD follows.
- **Crippling and capture:** a drained store leaves a ship limping; whether damage can put a core
  out is Slice 2's. A captured ship's store is yours.
- **Derelicts:** a ship found in low power with an almost empty store; take it by feeding its
  machine.
- **Mining:** the asteroids' lavender veins read as quantum ore if QE is violet (§14.3). A cutter
  could free swallowable chunks.
- **More salvage:** replenishing clouds over time, wrecks you can see from far off, and salvage
  that saves with the ledger.
- **Unidentified salvage:** values unknown until read (§4.4).
- **Trade:** stations buy and sell in QE. A quantum shard made and unmade at par could become cash
  you carry.
- **Being remade:** the machine converts QE "into the player". When death exists, the bridge's
  machine is where you come back, for a price.
- **Hands outside:** carrying salvage aboard; a cutter for things too big to swallow.
- **Life support:** a slow suit drain, once there is something to lose.
- **Low power's other losses:** gravity failing aboard, once walking in zero-g exists.
- **An idle trickle** on the ship's store, if QE never feels scarce (§2, row 1).
- **Returning a suit's charge** to the store at the machine's plate.
- **Persistence:** the store, the suit cell and the salvage ledger save when saving exists.
- **Two bells:** the core is heavy equipment at cabin level, a step toward the two-bell
  silhouette (§5.4).

---

## 18. Non-goals

- Trade, prices, stations, factions.
- Health, death, respawn.
- Carrying salvage aboard by hand; grabbing anything outside except the nozzle.
- Cutting up large debris.
- Brownout (power margin as a live mechanic).
- A dark core. The ship always flies (§8.3).
- Gravity failing in low power (gravity stays on).
- The bridge computer and its map (its own spec, built after this).
- Reeling yourself in along the hose.
- Saving and loading.

---

## 19. Risks

| Risk | Mitigation |
|---|---|
| The core crowds the bridge or blocks the walk to the helm | Its 1.2 m footprint leaves more than 1.0 m either side. Proven by the walk probe and renders from the corridor. Shrink the plinth if needed. |
| The core's glass costs frame time: transparent, in the middle of the bridge, over the canopy view | Measured in the bridge probe. If needed, frame the glass more heavily so less of it is transparent. |
| The core's weight changes how the ship flies | Measured in §5.4: balance improves and handling moves 2–8%. Flown before anything else is built on it. A deck-weight core leaves every figure as today (§2, row 12). |
| QE never feels scarce, or always does | All numbers are constants in `QuantumValues`, tuned at playtest: boost cost, make markup, suit cost, values, salvage counts. |
| A hose line passing through the hull looks wrong | It is mostly slack behind you. If renders show clipping, push segments out of the hull with sphere casts. |
| Suction feels floaty or twitchy | The force limit, drift damping and speed cap are all knobs; tune them in the probe. |
| Salvage bodies outside cost frame time | Only clouds within 3 km have nodes: the near cloud's 12 and, usually, one group's 10–16, all asleep. Measure at a group's cloud with the swarm in view. |
| A pushed item drifts into a rock that is still only a picture, and the two fly apart | Salvage never drifts on its own (§10.2). The bubble makes rocks solid near you and the ship, which is where things get pushed. If it is seen, make a moving item an anchor while it is awake. |
| A shoved rock has drifted onto a cloud's seeded place, so an item spawns inside it | Rare: few rocks are shoved, and slowly. If it is seen, skip spawning any item whose place a loaded rock body overlaps (one shape query per item, at load). |
| Finding a cloud is a chore, or no search at all | The ping's error, the region's size and offset, and the glint's range are constants in `SalvageSense`, tuned at playtest. |
| The violet core clashes with the warm cabin | It is the one cool colour, a gauge on the glow batch. Render beside the warm alternative (§2, row 11) and let the owner choose. |
| Low power feels like a bug or a punishment | Emergency light, never black: "dim is not dark" (style guide §2.3). The HUD says *LOW POWER*. The ship still flies, the machine still converts, and the pilot light refills an empty store. The authority factor is a constant, tuned at playtest. |
| Low power flickers at the line | Only deliberate actions cross it: boost (which then stops), a make, a suit charge, a convert. A crossing mid-sequence reverses smoothly (§8.3). |

---

## 20. Build order and definition of done

Each phase ends playable:

- **Phase A: the store and the core.**
  - blocks, stats, Rule 7, the core and machine on the starter's bridge, the spawn;
  - the core's prop and `QuantumCore` gauge, and the machine's body;
  - `QuantumStore`, `QuantumPlant`, boost, low power's rules and the pilot light;
  - the HUD's ship gauge.

  *Walk onto the bridge and round the core; boost and watch the gauge fall until the ship limps.*
- **Phase B: the machine.** Values, the bay, `MachineCycle`, the panel, convert and make,
  the show and sounds. *Convert a mug; make one back.*
- **Phase C: the suit.** `SuitCell`, the charge plate, thrust costs, the dry return, the airlock's
  refusal, the suit's HUD. *Charge up, go out, run dry, be brought home.*
- **Phase D: the near cloud and the hose.** Items outside, the near cloud, the reel, nozzle,
  line, suction, tether and toasts. *Vacuum the junk behind the stern and watch the store climb.*
- **Phase E: salvage at the groups.** The group clouds, the ledger, `SalvageSense` and the marker.
  *Follow a ping to the big rock, search its region, and gather there.*
- **Phase F: low power's look.** Emergency light and power restored, proven by the low-power
  probe.

Then the final renders, frame times and the amendments (§16).

**Done when:**
1. You launch `flight_test` and find the core turning at the centre of the bridge, its gauge half
   full.
2. You convert a mug at the machine and make one back.
3. You charge your suit at the machine, cycle out, take the hose and vacuum the near cloud.
4. You come back in with more QE than you spent.
5. You step round the core into the chair and boost until the store crosses the line: the ship
   drops into low power and limps. Converting at the machine brings the power back, cell by cell.
6. You follow a ping to the first group, search its region, and gather its salvage with the hose.
7. The GUT suite is green with pristine output, every render in §15.2 has gone to the owner, and
   the bridge and the spacewalk hold 120 fps on the GTX 960.
