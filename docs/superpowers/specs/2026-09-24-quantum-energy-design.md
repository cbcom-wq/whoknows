# Quantum energy — the power and the currency of the universe

**Date:** 2026-09-24
**Status:** Proposed design, awaiting the owner's review. It was written from the owner's brief
of 2026-09-24. Every row of §2 is a recommendation until the owner approves or changes it, except
where the owner has already decided. No code has changed.
**Revised 2026-09-25** by the owner's direction:
- **The ship keeps its size.** The first draft lengthened it by a row for an engine room.
- **There is no new room.** The quantum machine stands on the bridge. The engine is a **quantum
  core** at the centre of the bridge. No room moves.
- **Decided:**
  - the core is the ship's reactor and weighs 5 t;
  - the machine makes anything, and making costs twice what converting gives (rows 4, 6, 7 and 12).

**Depends on:** `main` at `c79402f` (the airlock and first spacewalk; the ship-and-space items)
**Governed by:** `docs/design/visual-style.md`
**Plan:** `docs/superpowers/plans/2026-09-24-quantum-energy.md`
**Amends, once approved:**
- the slice spec's §5 and §6.1, and its roadmap;
- the interior redesign's §7.5;
- hands-and-items §15 and §16;
- airlock §7.4 and §13;
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
- **Nothing is outside** to gather. Items in space were deferred by both the hands-and-items spec
  (§16) and the airlock spec (§13).

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

### 1.2 What this adds

- **A value** in QE for every object.
- **A store** of QE on every ship. The core is lit while the store holds any. Ordinary flight spends
  none; extras spend it.
- **The quantum core,** the ship's engine, at the centre of the bridge.
- **The quantum machine** on the bridge: convert objects to QE, make objects from QE, charge your
  suit.
- **A suit cell** your thrusters draw on.
- **Things in space** and **a hose** to gather them with.

---

## 2. Decisions

Each row is a recommendation for the owner to approve or change, unless it says the owner has
decided.

| # | Question | Recommendation | Why | Alternatives |
|---|---|---|---|---|
| 1 | What ordinary flight costs | **Nothing, but the core must be lit.** The ship flies, turns, holds gravity and runs its lights at full power while the store holds at least 1 QE. | The owner's own suggestion. Flying about never becomes a fuel chore. The existing power model (MW, Rule 5) keeps its meaning. An empty store becomes an event, a crippled or derelict ship, not a routine. | An idle trickle (kept as a tuning knob, default 0). Power that falls with the store, which makes handling depend on wealth. |
| 2 | What spends ship QE now | **Boost** (5 QE/s), **making objects** and **charging the suit**. Jumps, weapons and shields are hooks (§8.4). | Boost already exists and is free; it is the obvious first extra. | — |
| 3 | Running dry | **A reserve line at 100 QE that only the suit may cross.** Boost and making stop at the line. Charging the suit may take the store down to 1 QE. Nothing you do takes the last one. | You can never strand your own ship, and you can always go out and gather. Only outside forces empty a store: Slice 2's hits, capture, or a derelict found empty. | No reserve: boost until dark, then salvage your way back. But the hose needs a charged suit, so this can lock the game. |
| 4 | Where the power comes from | **Decided by the owner, 2026-09-25: the core is the reactor.** It generates the ship's power (36 MW on the starter), but only while it is lit. `reactor` and `battery` retire. The three reactors' cells become **quantum cells**: storage for QE, with the reactors' weight. | One engine, the one the fiction names, at the heart of the bridge. The cells keep the equipment deck's weight where it was. Made plain hull instead, they would leave the ship 5.2% nose-down under a full burn, worse than today. | Keep reactors as backup generation. Then QE does not really power the ship. Let the core hold the store, with the old reactor cells made hull: 12 t lighter, but badly balanced. |
| 5 | Where the core and the machine stand | **Decided by the owner, 2026-09-25:** both on the bridge, the core at its centre. There is no new room, and no room moves. **Recommended for the rest:** the machine against the bridge's back wall on the starboard side, facing forward. Both are **fixture blocks,** like the helm. | Fixtures are grid data, so any blueprint can place them. The back wall is the one bridge wall with neither a porthole nor a console: the machine replaces a set of lockers or a display. You pass both on your way to the helm. | The machine on a flank wall, facing the core, which covers a porthole. An engine room: the earlier drafts, superseded (§5.5). |
| 6 | What the machine can make | **Decided by the owner, 2026-09-25: anything.** Every item kind with a value, EVA tools aside. More advanced things simply cost more, because they are worth more (§4.3). | The machine is a maker, not a collection. | Only kinds it has converted (the first draft's patterns). |
| 7 | Make versus convert | **Decided by the owner, 2026-09-25: making costs twice what converting gives.** Converting returns half of what making took. | Nothing can print QE, and keeping a useful object is always cheaper than remaking it. | At par: objects become cash, and nothing is worth keeping. |
| 8 | The hose | **A nozzle on a 30 m line from a reel beside the outer hatch.** On a spacewalk you take it, aim, and hold the trigger. Loose things within 8 m fly in and are converted into the ship's store. | "A hose connected to the airlock … to suck in objects outside." Hands-on and physical, and it gives a spacewalk a job. | A fixed hose aimed from the open outer hatch. A ship-mounted vacuum worked from the cockpit. |
| 9 | Things to gather | **Salvage: loose items drifting in space**, in a cloud behind the starter's stern and six more farther out. | The hose needs something outside. | Make the debris field's rocks swallowable. They are 5–40 m, so they would need a cutter first. |
| 10 | The suit | **A 100 QE suit cell,** empty at the start and charged at the machine's plate. Thrust costs 1 QE per m/s. The airlock won't depressurize for an empty suit. A suit that runs dry outside brings you home on its emergency cell. | "The user must power up the suit at the quantum machine." Nothing can strand you, and there is no death to fall back on yet. | Drift until rescued. That needs death or rescue, neither of which exists. |
| 11 | The colour of QE | **A soft violet, `QUANTUM`:** the one cool colour in a warm ship. Every light stays `LIGHT_WARM`; bloom carries the violet. | It reads as other and precious, with no style-rule change. | A warm gold: safer, but less distinct. |
| 12 | What the core weighs | **Decided by the owner, 2026-09-25: 5 t,** a reactor's weight. | The heart of the ship should weigh like one. At cabin level it brings the ship's pitch imbalance under full burn almost to zero (§5.4). It costs 5% of forward acceleration. | The weight of a deck plate (0.4 t), which leaves every flight figure exactly as it is today. |

### 2.1 Decided and open

**Decided by the owner, 2026-09-25:**
- row 4: the core is the reactor;
- row 5: the core and the machine stand on the bridge;
- row 6: the machine makes anything;
- row 7: making costs twice what converting gives;
- row 12: the core weighs 5 t.

**Open questions.** These rows stand as recommended until the owner answers them, and the plan
builds them as recommended. Rows 3 and 10 shape play the most.

| # | Open question | Recommended | What changes if the answer differs |
|---|---|---|---|
| 1 | Does ordinary flight cost QE? | No. The core only has to be lit. | `FlightComputer` and `QuantumStore` (Task 4). An idle trickle is one constant. |
| 2 | What spends ship QE now? | Boost (5 QE/s), making objects and charging the suit | Boost's cost (Task 4); the machine and the plate (Tasks 6 and 7) |
| 3 | Is there a reserve? | Yes, 100 QE. Boost and making stop there; only a suit charge may go below it. | `QuantumStore`'s floors (Task 4) |
| 8 | What is the hose? | A hand-held nozzle on a 30 m line from a reel beside the outer hatch, used on a spacewalk | Task 9 |
| 9 | What does the hose gather? | Salvage drifting in space: a near cloud behind the stern and six far clouds | Task 8 |
| 10 | How does the suit work? | A 100 QE cell, empty at the start. 1 QE per m/s of thrust. The airlock refuses an empty suit. A suit that runs dry brings you home. | Task 7 |
| 11 | What colour is QE? | A soft violet, chosen from renders beside a warm gold | The palette (Task 3) |

---

## 3. The model: power and quantum energy

### 3.1 Two quantities

The owner's "present but not deducted" works because a ship needs two numbers, not one:

| | Power | Quantum energy (QE) |
|---|---|---|
| What it is | How much the core can deliver at once | How much is in the store |
| Unit | MW, as today | QE, whole numbers |
| Comes from | The quantum core, while it is lit | Converting objects, at the machine or with the hose |
| Goes to | Everything that runs: thrust, RCS, gravity, lights, airlocks | The extras: boost, making things, the suit; later jumps, shields and weapons |
| Running short | Brownout (Rule 5, a later mechanic) | The core goes dark |

**The core is lit while the store holds at least 1 QE.** A lit core gives the ship its full
`power_gen`, and a dark one gives nothing. Power does not scale with how full the store is.

### 3.2 The store

- **Capacity** is the sum of every block's `quantum_capacity`: 400 per quantum cell. The starter
  holds 1,200.
- **It starts half full** (600) on the ship's first load, as stocking happens once. Rebuilds keep
  the amount, clamped to any new capacity.
- **Whole numbers.** Continuous costs (boost, the suit) accrue fractions and are debited in whole
  QE as they add up.
- **A credit that would overflow is refused**, never partly wasted: *STORE FULL*.
- **The reserve is 100 QE.**

| Who draws on the store | How far down it may go |
|---|---|
| Boost; making objects | the reserve line (100) |
| Charging a suit | 1 |
| Outside losses (later: shield hits, damage, a boarder draining it) | 0 |

### 3.3 In and out, in this build

| In | Out |
|---|---|
| Converting at the machine: the item's value | Boost: 5 QE/s |
| Swallowing with the hose: the item's value | Making: twice the item's value |
| | Charging a suit: 1 QE per QE charged |

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
| *Salvage (§10.3):* rock chunk | 4 kg | 10 | 20 |
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
| **`quantum_core`** (new) | Interior | MOUNT | 5 t | generates 36 MW while lit | — |
| **`quantum_machine`** (new) | Interior | MOUNT | 0.5 t | draws 0.5 MW | — |
| **`quantum_cell`** (new) | Systems | SOLID | 5 t | — | 400 |
| `reactor` | *retired* | | | | |
| `battery` | *retired* (it has no function today and the starter has none) | | | | |

- The block count goes from 21 to 22.
- **The core and the machine are fixtures,** like the helm: each occupies a walkable cell and is
  drawn by the dressing (style guide §4, "A new fixture").
- **The quantum cell** is the reactor with its generation moved to the core: the same mass and hp.
- `BlockDefinition` gains `quantum_capacity: int`, in a "Quantum" export group.
- `ShipStats` gains `quantum_capacity`. `power_gen` now means the power the ship has while lit.

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
| Power | 36.0 generated / 30.8 drawn MW | 36.0 generated while lit / 31.1 drawn |
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
  bar is the reserve, and it turns `AMBER` when it is all that is left.
- **`flash()`:** a short brightening when QE arrives.

**States:**

| State | Rings | Pulse | Heart and bars |
|---|---|---|---|
| Lit | 0.25 rev/s | 0.5 Hz | glowing |
| Boosting | ×3 | 2 Hz | glowing |
| Dark | still | — | heart in `TRIM`, unlit; bars dark |
| Relighting | spinning up (§8.3) | rising | flaring |

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
- **Refused** with *RESERVE HELD* if the cost would take the store below the reserve.

### 7.3 Charging the suit

- F at the plate: *Charge suit (+86 QE)*.
- The suit charges at 50 QE/s, up to 100, while you stay within 1.2 m of the plate.
- While charging: the plate glows, the machine's screen counts up (*SUIT 64%*) and a tone rises. A
  chime sounds when the suit is full.
- Charging may take the store down to 1 QE (§3.2).

### 7.4 How it is built

`MachineCycle` is a pure `RefCounted`, like `AirlockCycle`:
- **Stages:** `IDLE`, `CONVERTING`, `MAKING`.
- **`press(button)`** takes `&"big"`, `&"prev"` or `&"next"`.
- **`step(delta, bay, store)`** returns cues in order:
  - `&"convert_start"`, `&"bead"`, `&"credited"`;
  - `&"make_start"`, `&"materialized"`;
  - `&"refused"`.
- **Pure functions** give the prompts, the three screen lines and the button colour: `SIGNAL_GO`
  when pressing will do something, `AMBER` while working, `CORAL` when refused.

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

### 8.1 Lit

While the core is lit, `FlightComputer` flies exactly as today and spends no QE.

### 8.2 Boost

- Boost costs **5 QE/s** while it is held with translation input. Boost multiplies thrust, so
  holding it with no thrust costs nothing.
- **At the reserve, boost stops.** The HUD reads *BOOST · RESERVE*.
- The core's rings turn three times as fast while you boost (§6.2). You feel it behind the chair
  rather than see it; the HUD shows the store falling.

### 8.3 Dark and relighting

**Dark** (the store at 0):
- no thrust and no RCS: the ship coasts, and the assist has nothing to act with;
- the interior drops to emergency light:
  - cell lights at 30%;
  - the shared glow material's `energy` at 35% (the uniform `glow.gdshader` already has);
  - the core still and its hum silent;
- the HUD reads *CORE DARK*.

**Still working in the dark,** on their own cells in the fiction:
- the airlocks, so you are never locked out;
- the machine and its charge plate, so you can relight;
- gravity.

**Relighting** (the store rises from 0) takes 3 s:
1. the rings spin up over 1.5 s and the heart flares;
2. the ship's lights come back cell by cell outward from the core, 0.1 s per cell of walking
   distance;
3. the glow comes back last, with the `core_up` sound.

**In this build, nothing you do can make the ship go dark** (§3.2). The dark state is reached in
tests and a probe. It is what Slice 2's crippling and a derelict's first visit will use.

### 8.4 Later spenders (hooks, not built)

| Spender | Slice | Shape |
|---|---|---|
| Quantum jump | 5 | Cost grows with distance and ship mass; the jump layer between systems |
| Shields | 2 | Absorb hits by spending QE, **and may go below the reserve to 0**. A drained ship goes dark: that is the crippled state (slice roadmap). |
| Turret weapons | 2 | Per shot, from the store |
| Repairs, the shipyard | 1 (Phase C), 5 | Blocks cost QE to build or mend |

This puts QE at the centre of the core loop (slice spec §1). Crippling an enemy means draining its
store. A captured ship's store is loot. A derelict is a ship whose store is empty, and you can take
it without a fight by relighting its core.

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

- **An item can live in the world:** `Item.set_space(true)` switches its look to render layer 1, lit
  by the sun, and its collision mask to `1 | 4 | 32` (hull, avatar, items). There is no felt
  gravity outside, and project gravity is zero, so outside items drift.
- **A 40 kg item cannot noticeably move a 97 t hull.**
- **Hands aboard are unchanged,** and hands outside take only EVA tools (§11.2). Carrying salvage
  aboard by hand is a later spec.

### 10.2 The salvage field

`SalvageField` is a world node under `Outside`, seeded and deterministic like `DebrisField`.

- **The near cloud:** 12 items, 12–40 m aft of the starter's stern, along the airlock's line, so
  the first spacewalk has something to gather.
- **Six far clouds,** 300–1,200 m out, with 10–16 items each. Half of them hold one quantum shard,
  so there is a reason to fly somewhere.
- **Motion:** drift up to 0.2 m/s and tumble up to 20°/s.
- **The mix,** by weight: rock chunk 4, scrap plate 3, ice chunk 3, wire coil 2, broken module 1.
- **It is not replenished** in this build.

### 10.3 Salvage kinds

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
- **30 m long.** At full length the tether holds you: outward velocity is removed and a 1 m/s² pull
  draws you back.

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
  3. the HUD shows *+12 QE · ICE CHUNK*.
- **Refusals:** a thing too big (over 0.6 m or 40 kg) is not pulled, and the prompt reads *Too big*.
  With the store full, suction stops and the prompt reads *Store full*.
- **The show:** the mouth glows `QUANTUM` while drawing, and each swallow gulps.
- **Suction costs no QE.**

---

## 12. HUD

- **`VehicleTelemetry`** gains `has_energy`, `energy`, `energy_capacity`, `energy_reserve`,
  `energy_label` (*QE* or *SUIT*), `energy_state` (`&"ok"`, `&"reserve"`, `&"low"`, `&"dry"` or
  `&"dark"`) and `tool_text`. Each vehicle fills them through the same duck-typed
  `build_telemetry()`.
- **`EnergyPanel`**, a `HudElement` in the band:
  - seated, it shows the ship's store: *QE 600*, with a bar, the reserve notch and *BOOST −5/S*
    while boosting;
  - on a spacewalk, it shows the suit (*SUIT 64%*) and, with the hose in hand, *HOSE 12 M* (the line
    paid out);
  - it uses `HudPalette`: the readout colour normally, `WARNING` at the reserve, when low and when
    dark.
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
                     ShipStats.quantum_capacity                 QuantumBay (StowPoint)
                                │                                   │  item dropped in
 FlightComputer ◄── lit, boost ─┤                                   ▼
                                ▼                   ┌────────── MachineCycle (pure) ◄── panel buttons
 Avatar/SuitCell ◄── charge ── QuantumPlant ────────┤
   (spends Δv)       (plate)   owns: QuantumStore   └────────── QuantumCore (gauge, states)
                                ▲       │ lit / dark
 HoseNozzle ── swallow ─────────┘       └────► Ship: emergency light, relight sequence
   (EVA tool, on HoseLine from HoseReel on AirlockAlcove)
```

- **`QuantumPlant` is the only thing that knows a ship has QE.** It is a `Node` under `Ship`,
  created in code like `Airlocks`, and lives across rebuilds.
- **Everything visual knows nothing about ships:** `QuantumCore`, `QuantumShow`, `ChargeDock`,
  `HoseLine` and the props. Each takes a frame, a size or a body, as `AirlockHatch` does.
- **Everything with rules is pure and tested headless:** `QuantumStore`, `MachineCycle`,
  `SuitCell`, `Tether` and `QuantumValues`.
- **Items still know nothing about ships.** The hose credits the store through a sink callable
  that the airlock wires to the reel.

### 14.1 Files

```
src/quantum/
  quantum_store.gd     QuantumStore: amount, capacity, reserve, spend/credit/drain, lit (pure)
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
src/world/salvage_field.gd
src/ui/energy_panel.gd, src/ui/quantum_toast.gd
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
  - `ship.gd`: `QuantumPlant`, emergency light, relighting;
  - `flight_computer.gd`: lit, and boost's cost.
- **Items:**
  - `item_definition.gd`: `quantum_value` and `eva_tool`;
  - every item `.tres`: a value;
  - `item.gd`: `set_space`;
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
  - `flight_test.gd`/`.tscn`: the starter grid, the spawn, salvage and the HUD.

### 14.2 Layers

No new physics or render layers.

| Thing | Physics layer | Mask | Render layer |
|---|---|---|---|
| An item aboard | 6 (32) | 2 \| 4 \| 32, as now | 2 |
| An item outside | 6 (32) | 1 \| 4 \| 32 | 1 |
| The machine's buttons and charge plate | 2 (`interior_geometry`), like the airlock panels | — | 2 |
| The reel and the docked nozzle | on the hull | — | own hull (4), like the alcove |
| The hose line, a nozzle in hand | — | — | 1 |
| The Interactor on a spacewalk | — | 16 \| 32 | — |
| Suction | a shape query on 32 | — | — |

### 14.3 Palette

- **`InteriorPalette` gains:**
  - `QUANTUM`, a soft luminous violet;
  - `QUANTUM_DEEP`, the unlit heart and the gauge's dark bars;
  - `ICE` and `COPPER`.
- **`HullPalette` gains** `HOSE`.
- **`HudPalette` is unchanged.**

Values are pinned by rendering. Adding palette entries is not a rule change.

---

## 15. Testing

### 15.1 Automated (GUT, headless, output pristine)

- **`test_quantum_store.gd`:**
  - lit at 1 and dark at 0;
  - spends are all or nothing;
  - the reserve holds for boost and making, the suit goes down to 1, and drains reach 0;
  - a credit over capacity is refused;
  - a new capacity clamps the amount;
  - continuous costs debit whole QE at the right times.
- **`test_quantum_values.gd`:** make cost is twice the value; what fits the bay; every item `.tres`
  has a value, and only EVA tools have 0.
- **`test_machine_cycle.gd`:**
  - convert and make, with their timings and cues in order;
  - the credit lands on `&"credited"`, not before;
  - the refusals: store full, reserve held;
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
- **`QuantumCore`:** the gauge lights the right number of bars for a fill; the reserve bar turns
  amber; the states.
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
- **`FlightComputer`:** dark means no force or torque; boost spends and stops at the reserve; a null
  store means free boost, as today.
- **Items:** `set_space` switches layers and masks; the six salvage looks build.
- **`SalvageField`:** the same seed gives the same field; the counts; the near cloud's distances.
- **Hose:**
  - the cone and its widening;
  - the force limit;
  - a swallow within 0.35 m credits through the sink;
  - too big and store full are refused;
  - letting go reels it home;
  - Grasp lets only EVA tools past `suspended`.
- **Airlock:** the empty-suit refusal of the room panel.
- **HUD:** the telemetry energy fields for ship and suit; `EnergyPanel`'s text and states.
- **`Synth`:** the seven new sounds build, are deterministic and are not silent.
- **`test_visual_style_rules.gd`** (extended):
  - the new painting files are held to palette colours;
  - `quantum_core.gd`, `quantum_show.gd`, `charge_dock.gd`, `hose_line.gd` and `readout_panel.gd`
    are held grid-blind;
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
- **Dark probe:**
  - set the store to 0: no thrust, emergency light;
  - convert an item: the relight sequence runs.
- **Renders at 1.6 m eye height,** sent to the owner:
  - the bridge from the corridor, with the core at its centre;
  - the bridge from the machine, and from beside the helm looking aft at the core;
  - the core lit, at the reserve and dark;
  - the machine loaded and empty;
  - a convert and a make, mid-show;
  - the plate charging;
  - the seated view, unchanged, with the core behind you;
  - the reel on the hull;
  - a spacewalk with the hose drawing in junk;
  - the HUD seated and on a spacewalk.
- **Frame time** at 1280 × 720, against the 120 fps budget:
  - the bridge at rest, looking through the core's glass at the canopy;
  - mid-convert;
  - a spacewalk in the near cloud with the hose drawing.

### 15.3 Playtest checklist

- Is the core the heart of the bridge? Does stepping round it ever get in the way?
- Does converting feel satisfying, and making feel like magic?
- Does the core's gauge read at a glance?
- Is boost's cost felt without being a nag?
- Is a salvage walk worth its suit charge?
- Did you ever feel stranded?

---

## 16. Amendments to other documents

Applied with the code they describe:

- **Slice spec:**
  - **§5, the catalogue:** `reactor` and `battery` retire; `quantum_core`, `quantum_machine` and
    `quantum_cell` join.
  - **§6.1:** Rule 7.
  - **Roadmap:** Slice 2's shields and weapons spend QE, and crippled means a dark core. Slice 5's
    jumps and the shipyard cost QE.
- **Interior redesign §7.5:** the starter's bridge gains the core at (0, 0, −2) and the machine at
  (1, 0, −1).
- **Hands and items:**
  - **§15:** items in space now exist, as salvage.
  - **§16:** hands outside take EVA tools; carrying salvage aboard stays out of scope.
- **Airlock:**
  - **§7.4:** outside, the hands take EVA tools.
  - **§12/§13:** the empty-suit refusal. The suit's fuel is the suit cell.
- **Planetfall §18:** a supply cache's manifest lines carry QE values. A `WRECK` site can be a
  derelict to relight.
- **Visual style guide:**
  - a §3.5 for the core and the machine:
    - fixtures that do not reshape the bridge;
    - a wall-standing fixture builds in the frame of the wall at its back;
    - the core's crown carries its cell's light;
    - the core as a gauge;
  - §2.8: the machine's screen joins the live-data screens;
  - §2.9: you hear the tool in your hands through the suit;
  - the new palette entries;
  - items outside, on layer 1 and lit by the sun;
  - the frame-time figures.
- **`SLICE-1-STATUS`:** a "what works" entry once built, with the new flight figures.

---

## 17. Hooks left open

- **Spenders:** jumps, shields, turret weapons, repairs and shipyard costs (§8.4).
- **Crippling and capture:** a drained store goes dark; a captured ship's store is yours.
- **Derelicts:** a ship found with an empty store; relight its core by feeding its machine.
- **Unidentified salvage:** values unknown until read (§4.4).
- **Trade:** stations buy and sell in QE. A quantum shard made and unmade at par could become cash
  you carry.
- **Being remade:** the machine converts QE "into the player". When death exists, the bridge's
  machine is where you come back, for a price.
- **Hands outside:** carrying salvage aboard; a cutter for things too big to swallow.
- **Life support:** a slow suit drain, once there is something to lose.
- **An idle trickle** on the ship's store, if QE never feels scarce (§2, row 1).
- **Returning a suit's charge** to the store at the machine's plate.
- **Persistence:** the store and the suit cell save with the ship when saving exists.
- **Two bells:** the core is heavy equipment at cabin level, a step toward the two-bell
  silhouette (§5.4).

---

## 18. Non-goals

- Trade, prices, stations, factions.
- Health, death, respawn.
- Carrying salvage aboard by hand; grabbing anything outside except the nozzle.
- Cutting up large debris.
- Brownout (power margin as a live mechanic).
- Zero-g in the dark (gravity stays on).
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
| Ninety sleeping rigid bodies outside cost frame time | They sleep. Measure in the near cloud; thin the far clouds if needed. |
| The violet core clashes with the warm cabin | It is the one cool colour, a gauge on the glow batch. Render beside the warm alternative (§2, row 11) and let the owner choose. |
| A dark ship feels like a bug | Emergency light, never black: "dim is not dark" (style guide §2.3). The airlock and machine always work. |

---

## 20. Build order and definition of done

Each phase ends playable:

- **Phase A: the store and the core.**
  - blocks, stats, Rule 7, the core and machine on the starter's bridge, the spawn;
  - the core's prop and `QuantumCore` gauge, and the machine's body;
  - `QuantumStore`, `QuantumPlant`, lit and boost;
  - the HUD's ship gauge.

  *Walk onto the bridge and round the core; boost and watch the gauge fall.*
- **Phase B: the machine.** Values, the bay, `MachineCycle`, the panel, convert and make,
  the show and sounds. *Convert a mug; make one back.*
- **Phase C: the suit.** `SuitCell`, the charge plate, thrust costs, the dry return, the airlock's
  refusal, the suit's HUD. *Charge up, go out, run dry, be brought home.*
- **Phase D: salvage and the hose.** Items outside, `SalvageField`, the reel, nozzle, line,
  suction, tether and toasts. *Vacuum the junk behind the stern and watch the store climb.*
- **Phase E: dark and relight.** Emergency light and the relight sequence, proven by the dark
  probe.

Then the final renders, frame times and the amendments (§16).

**Done when:**
1. You launch `flight_test` and find the core turning at the centre of the bridge, its gauge half
   full.
2. You convert a mug at the machine and make one back.
3. You charge your suit at the machine, cycle out, take the hose and vacuum the near cloud.
4. You come back in with more QE than you spent.
5. You step round the core into the chair, boost, and watch the store fall to the reserve and stop.
6. The GUT suite is green with pristine output, every render in §15.2 has gone to the owner, and
   the bridge and the spacewalk hold 120 fps on the GTX 960.
