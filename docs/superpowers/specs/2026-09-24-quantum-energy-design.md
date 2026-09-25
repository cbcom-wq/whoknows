# Quantum energy — the power and the currency of the universe

**Date:** 2026-09-24
**Status:** Proposed design, awaiting the owner's review. It was written from the owner's brief
of 2026-09-24. Every row of §2 is a recommendation until the owner approves or changes it, except
row 5, which the owner decided. No code has changed.
**Revised 2026-09-25** after the owner's first read: the ship keeps its size. The first draft
lengthened the starter by a row for a three-cell engine room. The owner pointed out that the bridge
has room to spare, so one side's rooms shift forward instead, and the engine room is one cell
(§5.3).
**Depends on:** `main` at `c79402f` (the airlock and first spacewalk; the ship-and-space items)
**Governed by:** `docs/design/visual-style.md`
**Plan:** `docs/superpowers/plans/2026-09-24-quantum-energy.md`
**Amends, once approved:**
- the slice spec's §5 and §6.1, and its roadmap;
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

What exists today:
- **Power** is a number. Three `reactor` blocks buried in the unwalkable equipment deck generate
  36 MW from nothing.
- **Nothing aboard is worth anything.** The sixteen items are things to pick up and throw.
- **Boost** (Space) is free, and so are **the suit's thrusters**.
- **Nothing is outside** to gather. Items in space were deferred by both the hands-and-items spec
  (§16) and the airlock spec (§13).

### 1.1 The pitch

You walk aft down the corridor. The last door on the right, beside the airlock's hatch, slides
open on the engine room. The machine faces you. At your left shoulder stands the engine: a pillar
of glass where a violet core turns inside three slow rings. A column of lit bars on its face says
the store is half full. Drop a mug into the machine's bay: it hangs there in the field, turning,
and the screen reads *CONVERT · MUG · +3 QE*. Press the button and the mug is gone. A bead of
light runs along the pipe to the engine, and a bar lights.

Put your palm on the machine's charge plate and your suit fills. Cycle out through the airlock, take the hose
nozzle from its reel beside the hatch, and float out into the junk drifting behind your ship. Hold
the trigger: a lump of ice tumbles toward you and vanishes into the nozzle with a thunk. *+12 QE ·
NEW PATTERN.* Back aboard, sit down and boost: the core spins faster and the store ticks down.

### 1.2 What this adds

- **A value** in QE for every object.
- **A store** of QE on every ship. The engine is lit while the store holds any. Ordinary flight
  spends none; extras spend it.
- **An engine room** at the aft end of the corridor, beside the airlock, with the engine and the
  machine.
- **The machine:** convert objects to QE, make objects from QE, charge your suit.
- **A suit cell** your thrusters draw on.
- **Things in space** and **a hose** to gather them with.

---

## 2. Decisions (proposed)

Each row is a recommendation for the owner to approve or change.

| # | Question | Recommendation | Why | Alternatives |
|---|---|---|---|---|
| 1 | What ordinary flight costs | **Nothing, but the engine must be lit.** The ship flies, turns, holds gravity and runs its lights at full power while the store holds at least 1 QE. | The owner's own suggestion. Flying about never becomes a fuel chore. The existing power model (MW, Rule 5) keeps its meaning. An empty store becomes an event, a crippled or derelict ship, not a routine. | An idle trickle (kept as a tuning knob, default 0). Power that falls with the store, which makes handling depend on wealth. |
| 2 | What spends ship QE now | **Boost** (5 QE/s), **making objects** and **charging the suit**. Jumps, weapons and shields are hooks (§8.4). | Boost already exists and is free; it is the obvious first extra. | — |
| 3 | Running dry | **A reserve line at 100 QE that only the suit may cross.** Boost and making stop at the line. Charging the suit may take the store down to 1 QE. Nothing you do takes the last one. | You can never strand your own ship, and you can always go out and gather. Only outside forces empty a store: Slice 2's hits, capture, or a derelict found empty. | No reserve: boost until dark, then salvage your way back. But the hose needs a charged suit, so this can lock the game. |
| 4 | Where the power comes from | **The quantum engine replaces the reactors.** `reactor` and `battery` retire. A new `quantum_cell` block holds QE and delivers the ship's power, but only while the engine is lit. | One source of power, the one the fiction names: the engine lights the cells. The starter's three reactors become three quantum cells in the same cells, with the same mass and the same 12 MW each, so nothing about the ship's balance or power moves. | Keep reactors as backup generation. Then QE does not really power the ship. |
| 5 | The engine room in the starter | **Decided by the owner, 2026-09-25: the ship keeps its size.** The port rooms (bunk room and bathroom) shift forward a row into the bridge's back corner. The engine room takes the freed cell at the aft end of the corridor, beside the airlock. | Every room the owner chose stays. The room sits on the way out: charge your suit on the way to the airlock, feed the machine on the way back. Deck and room blocks weigh the same, so every flight figure is unchanged (§5.4). Port, not starboard: starboard's weapon rack would land under a porthole (§5.3). | Lengthen the ship by a row (the first draft; the owner declined it). Shift two rows for a two-cell engine room, at the cost of a second bridge cell (§5.5). |
| 6 | What the machine can make | **Only what it has read.** Converting a kind for the first time records its pattern. The machine starts knowing everything the ship was stocked with. | The theme (slice spec §1.1): a new kind of thing is worth more than its QE. Exploring unlocks things to make. | Anything in the item catalogue. |
| 7 | Make versus convert | **Making costs twice what converting gives.** | Nothing can print QE, and keeping a useful object is always cheaper than remaking it. | At par: objects become cash, and nothing is worth keeping. |
| 8 | The hose | **A nozzle on a 30 m line from a reel beside the outer hatch.** On a spacewalk you take it, aim, and hold the trigger. Loose things within 8 m fly in and are converted into the ship's store. | "A hose connected to the airlock … to suck in objects outside." Hands-on and physical, and it gives a spacewalk a job. | A fixed hose aimed from the open outer hatch. A ship-mounted vacuum worked from the cockpit. |
| 9 | Things to gather | **Salvage: loose items drifting in space**, in a cloud behind the starter's stern and six more farther out. | The hose needs something outside. | Make the debris field's rocks swallowable. They are 5–40 m, so they would need a cutter first. |
| 10 | The suit | **A 100 QE suit cell,** empty at the start and charged at the machine's plate. Thrust costs 1 QE per m/s. The airlock won't depressurize for an empty suit. A suit that runs dry outside brings you home on its emergency cell. | "The user must power up the suit at the quantum machine." Nothing can strand you, and there is no death to fall back on yet. | Drift until rescued. That needs death or rescue, neither of which exists. |
| 11 | The colour of QE | **A soft violet, `QUANTUM`:** the one cool colour in a warm ship. Every light stays `LIGHT_WARM`; bloom carries the violet. | It reads as other and precious, with no style-rule change. | A warm gold: safer, but less distinct. |

### 2.1 The three that change the most

- **Retiring the reactors (row 4).** A block the slice spec lists goes away, and every power number
  now depends on the engine being lit.
- **Patterns (row 6).** It decides whether the machine is a vending machine or a discovery.
- **The make markup (row 7).** It sets how much a thing in the hand is worth over its QE.

The starter's layout (row 5) is settled. It moves three rooms and changes none of the ship's
figures.

---

## 3. The model: power and quantum energy

### 3.1 Two quantities

The owner's "present but not deducted" works because a ship needs two numbers, not one:

| | Power | Quantum energy (QE) |
|---|---|---|
| What it is | How much the engine can deliver at once | How much is in the store |
| Unit | MW, as today | QE, whole numbers |
| Comes from | The quantum cells, while the engine is lit | Converting objects, at the machine or with the hose |
| Goes to | Everything that runs: thrust, RCS, gravity, lights, airlocks | The extras: boost, making things, the suit; later jumps, shields and weapons |
| Running short | Brownout (Rule 5, a later mechanic) | The engine goes dark |

**The engine is lit while the store holds at least 1 QE.** A lit engine gives the ship its full
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

### 4.3 Patterns

- Each ship keeps a `PatternLibrary`: the item kinds its machine knows.
- It starts with every kind the ship was stocked with on its first load, which is all sixteen on
  the starter.
- Converting a kind it does not know, at the machine or with the hose, adds it. The machine's screen
  or the HUD says *NEW PATTERN*.
- **The machine makes only kinds it knows.** EVA tools (the hose nozzle) are never made or
  converted.

### 4.4 Who knows

An item's prompt never shows its value. Values show in two places: the machine's screen while the
item is in the bay, and the HUD when the hose swallows it. Knowing what something is worth is
information, and the machine is how you get it. The slice's unidentified salvage (§1.1) plugs in
later: an unidentified block's value stays unknown until the machine reads it.

---

## 5. The ship

### 5.1 Blocks

| Block | Category | Occupancy | Mass | Power | QE capacity |
|---|---|---|---|---|---|
| **`quantum_room`** (new) | Interior | DECK | 0.4 t | draws 0.1 MW | — |
| **`quantum_cell`** (new) | Systems | SOLID | 5 t | generates 12 MW while lit | 400 |
| `reactor` | *retired* | | | | |
| `battery` | *retired* (it has no function today and the starter has none) | | | | |

- The block count stays 21.
- `BlockDefinition` gains `quantum_capacity: int`, in a "Quantum" export group.
- `ShipStats` gains `quantum_capacity`. `power_gen` now means the power the ship has while lit.
- `quantum_room` is a room block with deck's mass and power, as the style guide's §4 asks.
- `quantum_cell` is the reactor with a store added: the same mass, hp and generation.

### 5.2 Validation

- **Rule 7 (error, `QUANTUM_ROOM`):** a ship needs two things:
  - a quantum room that seats both a machine and an engine;
  - at least one quantum cell.

  The validator asks `InteriorLayout` whether the room seats both pieces (§6.1), as Rule 6 asks
  `AirlockSite`. Without an engine or a cell, a ship has no power at all, which is as fatal as
  having no pilot seat.
- Rule 5 (power margin, a warning) is unchanged.

### 5.3 The starter shuttle

```
 z \ x       −1             0              +1
  −4       canopy        canopy          canopy
  −3        deck       pilot_seat         deck         ┐
  −2        deck          deck            deck         │ bridge
  −1      bunk_room       deck            deck         ┘  ← the bunk room moves up a row
   0      bunk_room       deck           galley
  +1      bathroom        deck         weapon_room
  +2    quantum_room      deck           closet        ← new: the engine room
  +3      bulkhead       airlock         bulkhead
```

- **The port rooms shift forward a row:** the bunk room to z = −1…0, the bathroom to z = +1.
- **The engine room takes the freed cell** at (−1, 0, +2): the corridor's aft end, beside the
  airlock.
- **The three reactors become quantum cells** in the same cells.
- **Nothing else moves:** the hull, the equipment deck, the pods and the airlock.

The bridge keeps eight of its nine cells. Its front row, with the helm and the cockpit pod, is
untouched.

**Why port, not starboard.** A room whose feature wall is on the outer skin gets a porthole above
its furniture (style guide §3.1). Forward of the engine pods, at z = −1 and 0, the outer walls are
outer skin.
- **Shifting starboard** would put the weapon room at (1, 0, 0). Its 1.7 m rack would meet a
  porthole, and the rack has no low variant.
- **Shifting port** puts the bunk room there instead. Bunks already build a single low bunk under a
  porthole, so both bunk cells gain a window. The room goes from three berths (a double bunk and a
  single) to two singles.
- **The bathroom and the engine room** sit beside the pods, so neither gets a porthole.

The stock follows its rooms. The plan re-pins the starter's stock counts.

### 5.4 Measured

Deck, room and engine-room blocks all weigh 0.4 t, and a quantum cell weighs what a reactor does.
Moving rooms inside the cabin therefore changes none of the ship's figures. These were computed with
`ShipStats`'s own arithmetic outside the engine, which reproduces today's recorded figures exactly.
The plan confirms them in Godot.

| | Today | With the engine room |
|---|---|---|
| Blocks | 84 | 84 |
| Mass | 92,300 kg | 92,300 kg |
| Centre of mass | (0, 1.268, 0.325) | the same |
| Pitch imbalance under full burn | 101,408 N·m: 3.2% of pitch authority | the same |
| Torque budget (N·m) | 3,162,514 / 2,081,257 / 2,183,099 | the same |
| Power | 36.0 generated / 30.8 drawn MW | 36.0 generated while lit / 30.8 drawn |
| QE capacity | — | 1,200 |

The ship handles exactly as it does today.

### 5.5 Alternatives considered

- **Lengthen the ship by a row.** This was the first draft: a three-cell engine room between the
  corridor and the airlock, with the ship 2 m longer. It measured well (pitch balance 2.6% of pitch
  authority, and 8% less forward acceleration). The owner declined it on 2026-09-25.
- **Shift two rows,** for a two-cell engine room at (−1, 0, +1…+2), where the engine and the machine
  would each get a wall of their own. It costs the bridge a second cell and brings the bunk room up
  beside the helm row. Worth it only if the one-cell room renders too cramped (§19).

---

## 6. The engine room

### 6.1 Layout

- **`quantum_room` joins `InteriorLayout.ROOM_IDS`:** walls where it meets another zone, one
  doorway, a sliding door, as for any room.
- **Airlocks resolve before rooms,** so an airlock whose inner hatch opens into a room claims that
  wall before the room furnishes it. The starter's does not, but a player's ship may.
- **The layout deals the pieces.** It records a `piece` on each furnished wall:
  1. Rank the room's cells by distance from the room's doorway, then by lowest `(z, x)`.
  2. The first feature wall gets the `machine`.
  3. The first secondary wall gets the `engine`. With no secondary wall, the engine takes the next
     feature wall.
  4. Any other feature or secondary wall gets `conduits`.

  A room that cannot seat both a machine and an engine fails Rule 7.
- **In the starter,** the room is one cell at (−1, 0, +2):
  - the doorway is its starboard wall, onto the corridor's last cell, beside the airlock's inner
    hatch;
  - the machine is on the port wall, facing you as you come in;
  - the engine is on the aft wall, against the bulkhead, at the door end: at your left shoulder as
    you enter;
  - the forward wall, onto the bathroom, keeps its trim.
- **Clearance:** the engine is 0.5 m deep, so the aisle from the door stays 1.0 m wide (style guide
  §3.1).
- **Floor:** `ROOM_FLOOR[&"quantum_room"]`, a deep violet-grey pinned by rendering.

### 6.2 The engine

A pillar, so that it fits a secondary wall (under 1 m wide, style guide §3.1).
`InteriorProps.quantum_engine(kit, f, variety)` builds the fixed parts. A `QuantumCore` node, like
`AirlockHatch`, owns the moving parts and knows nothing about ships.

**Fixed:**
- a plinth 0.7 × 0.2 × 0.5 m with a glowing base;
- two slim bevelled uprights from floor to ceiling, following `HEADROOM`;
- a glass tube 0.42 m across, from 0.45 m to 2.05 m up;
- a crown at the ceiling with a conduit rising into it.

Collider: 0.7 m wide, the full height, 0.5 m deep.

**Moving (`QuantumCore`):**
- **The core:** a faceted ball, 0.14 m in radius, at 1.25 m, in `QUANTUM` on the glow batch. It
  turns and breathes (scale ±4% at the pulse rate).
- **Three rings** round it, 0.17–0.2 m in radius, in `TRIM` with a `QUANTUM` inner edge, each turning
  on its own axis.
- **The gauge:** ten chunky bars up the front of the right-hand upright. The lit bars show how full
  the store is. The lowest bar is the reserve, and it turns `AMBER` when it is all that is left.
- **`flash()`:** a short brightening when QE arrives.

**States:**

| State | Rings | Pulse | Core and bars |
|---|---|---|---|
| Lit | 0.25 rev/s | 0.5 Hz | glowing |
| Boosting | ×3 | 2 Hz | glowing |
| Dark | still | — | core in `TRIM`, unlit; bars dark |
| Relighting | spinning up (§8.3) | rising | flaring |

**Light:** one small warm light (energy 0.5, `LIGHT_WARM`). The violet is glow, not light.

### 6.3 The machine

`InteriorProps.quantum_machine(kit, f, variety)`:
- **The cabinet:** 1.5 m wide, 2.0 m tall, 0.6 m deep. `TRIM` body, `WALL_LOW` base, glowing plinth.
- **The bay,** 0.9–1.5 m up, left of centre:
  - a 0.6 m square recess with a lit `QUANTUM` ring round its mouth and a glowing disc for a floor;
  - an item in it floats at the centre, turning slowly (10°/s);
  - the cabinet's colliders are built round the recess, so the Interactor can reach what sits
    there (style guide §3).
- **The screen** above the bay: live data (§7, style guide §2.8).
- **Three buttons** in a column right of the bay: ◀, the big button, ▶.
- **The charge plate** at the cabinet's right-hand end: a round hand plate 0.22 m across at 1.2 m, in
  a bevelled ring, lit `QUANTUM` when ready. A separate dock would need a wall of its own, and a
  one-cell room has none to spare.
- **A conduit** from the cabinet's top along the ceiling to the engine's crown. The bead runs along
  it (§7.5).
- **It publishes frames** in its own frame: `quantum_machine_bay()`, `quantum_machine_screen()`,
  `quantum_machine_buttons()`, `quantum_machine_plate()` and `quantum_machine_conduit()`.

### 6.4 Conduits

`InteriorProps.conduits(kit, f, variety)`: vertical pipes with collars in `TRIM` and `WALL_LOW`,
for walls with nothing else to hold. The starter has none.

### 6.5 How it is built

- The props stay grid-blind (style guide §3).
- `InteriorDressing` builds one `QuantumRoom` node per quantum room, as it builds `AirlockRoom`. It
  holds:
  - the core;
  - a `QuantumBay` at the bay frame;
  - the panel and the two arrow buttons;
  - a `ChargeDock` (the plate's interactable) at the plate frame;
  - the conduit path;
  - the room's key cell (its lowest cell).
- `InteriorBuilder.quantum_rooms()` returns them, as `airlock_rooms()` does.

---

## 7. The machine in use

### 7.1 Converting

1. **Drop an item into the bay:** aim at the bay and press G. Grasp's stow on drop already does this
   (hands-and-items spec §7.4). `QuantumBay` extends `StowPoint` and accepts any item that has a
   value, fits (largest side ≤ 0.55 m) and is under the 40 kg lift limit. A crate or a toolbox fits.
2. **The screen reads** *CONVERT · CRATE*, then *+30 QE* (with *· NEW PATTERN* for an unknown
   kind), then *STORE 600 QE*.
3. **The big button reads** *Convert Crate (+30 QE)*. Pressing it takes 1.2 s:
   - the item glows and shrinks to a point;
   - a bead of light runs along the conduit to the engine;
   - the store is credited when the bead arrives, and the core flashes.
4. **Refused** if the value will not fit in the store: *STORE FULL*, with a coral button.

Until you convert it, the item is simply stowed. Its own prompt (*Take Crate*) takes it back out.

### 7.2 Making

- **With the bay empty,** the screen reads *MAKE · MUG*, *COST 6 QE*, *STORE 600 QE*. ◀ and ▶ step
  through the known patterns, sorted by cost.
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

`QuantumPlant` keeps one cycle per quantum room, keyed by the room's key cell, so a rebuild never
drops an item mid-conversion. The bay's item re-seats through the existing re-seat on rebuild
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

## 8. The engine and flight

### 8.1 Lit

While the engine is lit, `FlightComputer` flies exactly as today and spends no QE.

### 8.2 Boost

- Boost costs **5 QE/s** while it is held with translation input. Boost multiplies thrust, so
  holding it with no thrust costs nothing.
- **At the reserve, boost stops.** The HUD reads *BOOST · RESERVE*.
- The engine's rings turn three times as fast while you boost (§6.2).

### 8.3 Dark and relighting

**Dark** (the store at 0):
- no thrust and no RCS: the ship coasts, and the assist has nothing to act with;
- the interior drops to emergency light:
  - cell lights at 30%;
  - the shared glow material's `energy` at 35% (the uniform `glow.gdshader` already has);
  - the engine still and its hum silent;
- the HUD reads *ENGINE DARK*.

**Still working in the dark,** on their own cells in the fiction:
- the airlocks, so you are never locked out;
- the machine and its charge plate, so you can relight;
- gravity.

**Relighting** (the store rises from 0) takes 3 s:
1. the rings spin up over 1.5 s and the core flares;
2. the ship's lights come back cell by cell outward from the engine room, 0.1 s per cell of walking
   distance;
3. the glow comes back last, with the `engine_up` sound.

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
it without a fight by relighting it.

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
- **A 40 kg item cannot noticeably move a 100 t hull.**
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
  2. the ship's store is credited and the pattern learned;
  3. the HUD shows *+12 QE*, with *NEW PATTERN · ICE CHUNK* if the kind was unknown.
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
- **`QuantumToast`**, a `HudElement` near the reticle, created in code as the reticle is: *+12 QE*
  and *NEW PATTERN · …*, rising and fading over 1.2 s.
- **Aboard on foot the HUD stays dark,** as now. The machine's screens are the instruments there.

---

## 13. Sound

Every sound is a new `Synth` builder (style guide §2.9):

| Sound | What it is | Where |
|---|---|---|
| `engine_hum` | two soft detuned sines, beating slowly; its pitch lifts while boosting | looped, positional at the engine, Ship bus |
| `convert` | a rising shimmer: filtered noise swept up, a sine glide, a soft pop | the bay |
| `materialize` | the same, falling, ending in a soft thump | the bay |
| `charge` | a rising tone, looped while charging; a small chime at full | the charge plate |
| `engine_down`, `engine_up` | spool down, spool up | the engine |
| `hose_draw` | low filtered noise, looped while suction runs | Suit bus |
| `hose_gulp` | a short soft thunk | Suit bus |

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
                               PatternLibrary
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
  pattern_library.gd   PatternLibrary: known kinds (pure)
  machine_cycle.gd     MachineCycle: the machine's state, cues, prompts, screen (pure)
  suit_cell.gd         SuitCell: charge, Δv cost, warnings, dry (pure)
  tether.gd            Tether: the hose's pull at full length (pure)
  quantum_plant.gd     QuantumPlant: one per ship; owns the store and library; binds rooms
  quantum_room.gd      QuantumRoom: what the dressing built for one room (references)
  quantum_core.gd      QuantumCore: the engine's moving parts and gauge
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
data/blocks/quantum_room.tres, quantum_cell.tres   (reactor.tres and battery.tres removed)
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
  - `interior_layout.gd`: `ROOM_IDS`, airlocks first, dealing pieces;
  - `interior_dressing.gd`: the room's pieces and `QuantumRoom`;
  - `interior_props.gd`: three props and their frames;
  - `interior_builder.gd`: `quantum_rooms()`;
  - `interior_palette.gd`, `hull_palette.gd`: the new colours.
- **The airlock:**
  - `airlock_alcove.gd`: the reel;
  - `airlock.gd`: the empty-suit refusal, letting go of the nozzle at the threshold, and wiring
    the reel's sink;
  - `airlock_panel.gd`: extends `ReadoutPanel`.
- **HUD, sound and the scene:**
  - `vehicle_telemetry.gd`;
  - `synth.gd`;
  - `flight_test.gd`/`.tscn`: the starter grid, salvage and the HUD.

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
  - `QUANTUM_DEEP`, the unlit core and the gauge's dark bars;
  - `ICE` and `COPPER`;
  - `ROOM_FLOOR[&"quantum_room"]`.
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
- **`test_pattern_library.gd`:** it starts with the stocked kinds; it learns once; it reports new.
- **`test_machine_cycle.gd`:**
  - convert and make, with their timings and cues in order;
  - the credit lands on `&"credited"`, not before;
  - the refusals: store full, reserve held, nothing known;
  - ◀ and ▶ wrap, sorted by cost;
  - prompts, screen lines and button colours for each state.
- **`test_suit_cell.gd`:** the Δv cost; warnings at 25 and 10; dry at 0; charging to capacity.
- **`test_suit.gd`** (extended): `home_step` heads for the hold point at 1.5 m/s and holds there.
- **`test_tether.gd`:** slack does nothing; taut removes outward velocity and pulls back.
- **Blocks and stats:**
  - `quantum_capacity` sums;
  - `reactor` and `battery` are gone;
  - **the starter's flight numbers are unchanged** (§5.4), and its capacity is 1,200.
- **Validator:** Rule 7 fixtures (no room; a room that seats both pieces; one that cannot; no
  quantum cell). Existing fixtures gain a quantum room
  so their own rules stay isolated.
- **Layout:**
  - the quantum-room zone, and airlocks resolved first;
  - piece dealing: the machine on a feature wall, the engine on a secondary wall (or the next
    feature wall), conduits on the rest;
  - the starter: the moved bunk room and bathroom, the engine room's doorway onto the corridor,
    the machine on its port wall and the engine on its aft wall;
  - the aisle from the door stays 1.0 m clear.
- **Props:** the three props build in bare frames; pinned collider counts; the bay is clear of the
  machine's colliders.
- **`QuantumCore`:** the gauge lights the right number of bars for a fill; the reserve bar turns
  amber; the states.
- **Dressing:** one `QuantumRoom` in the starter with a core, a bay, a panel, two arrows and a
  charge plate.
- **`QuantumPlant`:**
  - it binds across rebuilds without resetting;
  - the store starts at half, once;
  - dropping into the bay and converting credits the store and learns the pattern;
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
  - down the corridor into the engine room, then across it to the airlock's inner hatch;
  - the aisle is clear, and every piece's collider stops the avatar.
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
  - the engine room from the corridor door;
  - the engine lit, at the reserve and dark;
  - the machine loaded and empty;
  - a convert and a make, mid-show;
  - the plate charging;
  - the reel on the hull;
  - a spacewalk with the hose drawing in junk;
  - the HUD seated and on a spacewalk;
  - the bridge with the bunk room in its back corner, and the bunk room's two windows.
- **Frame time** at 1280 × 720, against the 120 fps budget:
  - the engine room at rest;
  - mid-convert;
  - a spacewalk in the near cloud with the hose drawing.

### 15.3 Playtest checklist

- Is the engine room the heart of the ship? Do you want to go in?
- Does converting feel satisfying, and making feel like magic?
- Does the engine's gauge read at a glance?
- Is boost's cost felt without being a nag?
- Is a salvage walk worth its suit charge?
- Did you ever feel stranded?

---

## 16. Amendments to other documents

Applied with the code they describe:

- **Slice spec:**
  - **§5, the catalogue:** `reactor` and `battery` retire; `quantum_room` and `quantum_cell`
    join.
  - **§6.1:** Rule 7.
  - **Roadmap:** Slice 2's shields and weapons spend QE, and crippled means a dark engine. Slice 5's
    jumps and the shipyard cost QE.
- **Interior redesign §7.5:** the starter's cabin layout becomes §5.3's. The bunk room gains its two
  windows.
- **Hands and items:**
  - **§15:** items in space now exist, as salvage.
  - **§16:** hands outside take EVA tools; carrying salvage aboard stays out of scope.
- **Airlock:**
  - **§7.4:** outside, the hands take EVA tools.
  - **§12/§13:** the empty-suit refusal. The suit's fuel is the suit cell.
- **Planetfall §18:** a supply cache's manifest lines carry QE values. A `WRECK` site can be a
  derelict to relight.
- **Visual style guide:**
  - a §3.5 for the engine room: the pieces, the dealing rule, the engine as a gauge;
  - §2.8: the machine's screen joins the live-data screens;
  - §2.9: you hear the tool in your hands through the suit;
  - the new palette entries;
  - items outside, on layer 1 and lit by the sun;
  - the frame-time figures.
- **`SLICE-1-STATUS`:** a "what works" entry once built.

---

## 17. Hooks left open

- **Spenders:** jumps, shields, turret weapons, repairs and shipyard costs (§8.4).
- **Crippling and capture:** a drained store goes dark; a captured ship's store is yours.
- **Derelicts:** a ship found with an empty store; relight it by feeding its machine.
- **Unidentified salvage:** values unknown until read (§4.4).
- **Trade:** stations buy and sell in QE. A quantum shard made and unmade at par could become cash
  you carry.
- **Being remade:** the machine converts QE "into the player". When death exists, the engine room
  is where you come back, for a price.
- **Hands outside:** carrying salvage aboard; a cutter for things too big to swallow.
- **Life support:** a slow suit drain, once there is something to lose.
- **An idle trickle** on the ship's store, if QE never feels scarce (§2, row 1).
- **Returning a suit's charge** to the store at the machine's plate.
- **Persistence:** the store, the library and the suit cell save with the ship when saving exists.

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
| The one-cell engine room feels cramped | Rendered first, in Task 3, before anything is built on it. If it is, shift two rows for a two-cell room (§5.5). |
| The bridge feels smaller with the bunk room in its corner | It keeps eight of its nine cells and its whole front row. Render it from the helm and from the corridor. |
| QE never feels scarce, or always does | All numbers are constants in `QuantumValues`, tuned at playtest: boost cost, make markup, suit cost, values, salvage counts. |
| A hose line passing through the hull looks wrong | It is mostly slack behind you. If renders show clipping, push segments out of the hull with sphere casts. |
| Suction feels floaty or twitchy | The force limit, drift damping and speed cap are all knobs; tune them in the probe. |
| Ninety sleeping rigid bodies outside cost frame time | They sleep. Measure in the near cloud; thin the far clouds if needed. |
| The violet core clashes with the warm cabin | It is the one cool colour, a gauge on the glow batch. Render beside the warm alternative (§2, row 11) and let the owner choose. |
| A dark ship feels like a bug | Emergency light, never black: "dim is not dark" (style guide §2.3). The airlock and machine always work. |

---

## 20. Build order and definition of done

Each phase ends playable:

- **Phase A: the store and the room.**
  - blocks, stats, Rule 7, the moved rooms;
  - the engine room's layout, props and `QuantumCore` gauge;
  - `QuantumStore`, `QuantumPlant`, lit and boost;
  - the HUD's ship gauge.

  *Walk into the engine room; boost and watch the gauge fall.*
- **Phase B: the machine.** Values, patterns, the bay, `MachineCycle`, the panel, convert and make,
  the show and sounds. *Convert a mug; make one back.*
- **Phase C: the suit.** `SuitCell`, the charge plate, thrust costs, the dry return, the airlock's
  refusal, the suit's HUD. *Charge up, go out, run dry, be brought home.*
- **Phase D: salvage and the hose.** Items outside, `SalvageField`, the reel, nozzle, line,
  suction, tether and toasts. *Vacuum the junk behind the stern and watch the store climb.*
- **Phase E: dark and relight.** Emergency light and the relight sequence, proven by the dark
  probe.

Then the final renders, frame times and the amendments (§16).

**Done when:**
1. You launch `flight_test`, walk aft into the engine room and find the core turning and the gauge
   half full.
2. You convert a mug and make one back.
3. You charge your suit at the machine, cycle out, take the hose and vacuum the near cloud.
4. You come back in with more QE than you spent.
5. You sit down, boost, and watch the store fall to the reserve and stop.
6. The GUT suite is green with pristine output, every render in §15.2 has gone to the owner, and
   the engine room and the spacewalk hold 120 fps on the GTX 960.
