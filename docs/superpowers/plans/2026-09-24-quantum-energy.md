# Quantum Energy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Gate:** do not start until the owner has approved the spec's §2. If the owner changed a row,
> amend the spec first, then this plan. Two rows change the most (spec §2.1):
> - **retiring the reactors** changes Task 1;
> - **patterns** changes Tasks 5 and 6.

**Goal:** Make quantum energy (QE) the ship's power source and the universe's currency:
- an engine room with an engine and a machine;
- converting objects to QE and making them back;
- a suit cell charged at the machine;
- salvage drifting in space, and a hose on the airlock to gather it.

**Architecture:**
- **The store** is a pure `QuantumStore` owned by one `QuantumPlant` node per ship. It lives across
  rebuilds, as the airlocks do.
- **The engine is lit while the store holds any QE.** Ordinary flight spends nothing; boost, making
  and the suit do.
- **The engine room** is a room block. The layout deals it a machine, an engine and conduits.
  The dressing builds them as grid-blind props and hands a `QuantumRoom` to the plant.
- **The machine** is a pure `MachineCycle`. Its bay is a `StowPoint`, so Grasp's stow-on-drop feeds
  it.
- **The hose** is an EVA-tool item on a reel on the airlock's hull face. It swallows salvage items
  that now drift in the world.

**Tech Stack:** Godot 4.5.1 (Forward+), GDScript, GUT 9.5.

**Spec:** `docs/superpowers/specs/2026-09-24-quantum-energy-design.md`. Read it, and
`docs/design/visual-style.md`, first.

## Global Constraints

- **Everything in `docs/design/visual-style.md` binds:**
  - colours only from `InteriorPalette`, or `HullPalette` on the hull's outside;
  - props never reference `ShipGrid`, `InteriorLayout`, `InteriorBuilder` or `InteriorDressing`;
  - exactly three interior shaders;
  - interior render layer 2 with light cull mask 2;
  - no shadows;
  - every light `LIGHT_WARM`.
- **CLAUDE.md:** no `#` comments in `.tscn`/`.tres`. Prove every scene and resource edit by reading
  the property back at runtime.
- **Workflow:**
  - branch `quantum-energy`;
  - run the import pass after adding a `class_name` (`--headless --path who-knows --import`), and
    commit Godot's `.uid` files;
  - tests: `who-knows\run_tests.ps1 [-gselect=<file>]`. The baseline is 550 passing.
- **The store:**
  - capacity 400 per `quantum_cell`: 1,200 on the starter;
  - each quantum cell generates 12 MW, only while the engine is lit;
  - it starts at half capacity on the first load only;
  - reserve 100 (boost and making stop there; a suit charge goes down to 1; drains go to 0);
  - lit at ≥ 1;
  - whole QE; continuous costs accrue fractions;
  - a credit that would overflow is refused.
- **Costs:**
  - boost 5 QE/s, with translation input only;
  - make costs 2 × value; convert gives 1 × value;
  - a suit charge moves QE one for one.
- **The machine:**
  - convert 1.2 s, of which the bead is the last 0.6 s;
  - make 1.5 s;
  - the bay takes an item with a value, largest side ≤ 0.55 m and mass ≤ 40 kg; items in it turn at
    10°/s.
- **The charge plate:** 50 QE/s, reach 1.2 m.
- **The suit:**
  - capacity 100, empty at the start;
  - 1 QE per m/s of Δv;
  - warnings at 25 and 10;
  - dry: home at 1.5 m/s to a point 1.5 m outside the outer hatch;
  - the room panel refuses to depressurize below 10.
- **The hose:**
  - a 30 m line of 40 segments;
  - a cone 8 m long with a 15° half-angle, widened by half the item's largest side;
  - pull ≤ 6 m/s² and ≤ 120 N, speed cap 5 m/s;
  - swallow within 0.35 m, over 0.25 s;
  - too big above 0.6 m or 40 kg;
  - it reels home in 1 s;
  - the tether pulls 1 m/s².
- **The engine:**
  - rings at 0.25 rev/s, ×3 while boosting;
  - pulse 0.5 Hz, or 2 Hz while boosting;
  - ten gauge bars, the lowest being the reserve.
- **Dark:** cell lights at 30% and glow `energy` at 35%. Relighting takes 3 s, then lights return
  at 0.1 s per cell of walking distance.
- **Salvage:**
  - a near cloud of 12 items, 12–40 m aft of the stern;
  - six far clouds of 10–16 items, 300–1,200 m out, half of them with a shard;
  - drift ≤ 0.2 m/s and tumble ≤ 20°/s;
  - weights: rock 4, scrap 3, ice 3, wire 2, module 1.
- **Layers** (spec §14.2):
  - items outside: layer 32, mask `1 | 4 | 32`, render layer 1;
  - the spacewalking Interactor: mask `16 | 32`;
  - the reel and the docked nozzle: the own-hull render layer (`ExteriorBuilder.OWN_HULL_LAYER`).
- **Values** are in spec §4.2. They are the only source; tests read them from the `.tres` files.
- Commit messages end with the session's attribution trailer.

---

### Task 1: The new blocks and the moved rooms

**Files:**
- Create: `data/blocks/quantum_room.tres`, `data/blocks/quantum_cell.tres`
- Delete: `data/blocks/reactor.tres`, `data/blocks/battery.tres`
- Modify: `block_definition.gd`, `ship_stats.gd`, `scenes/flight_test.gd` (`_starter_grid()` and
  its power note)
- Tests: `test_block_data.gd`, `test_block_catalog.gd`, `test_ship_stats.gd`,
  `test_starter_shuttle.gd`, the parity test

**Interfaces produced:**
- `BlockDefinition.quantum_capacity: int` (export group "Quantum").
- `ShipStats.quantum_capacity: int`, summed like power.

**What to do:**
- **The blocks** (spec §5.1):
  - `quantum_room`: Interior, DECK, 0.4 t, hp 60, `power_draw` 0.1, with the deck's slab mesh;
  - `quantum_cell`: Systems, SOLID, 5 t, hp 250, `power_gen` 12, capacity 400, with a box mesh like
    the reactor's.
- **The starter** (spec §5.3):
  - the bunk room moves to (−1, 0, −1) and (−1, 0, 0);
  - the bathroom moves to (−1, 0, +1);
  - `quantum_room` goes at (−1, 0, +2);
  - the reactors become quantum cells.
- **The power note** in `_starter_grid()` now says quantum cells, not reactors. The recorded flight
  figures stay as they are.

**Tests:**
- the new blocks' fields;
- `reactor` and `battery` are no longer in the catalogue;
- the capacity sum;
- **the starter is unchanged in flight:** 84 blocks, 92,300 kg, centre of mass (0, 1.268, 0.325),
  imbalance.x 101,408 N·m, torque budget (3,162,514, 2,081,257, 2,183,099), 36.0 generated / 30.8
  drawn MW, zero issues;
- the starter's capacity is 1,200;
- re-pin the starter's stock counts, which follow their rooms.

If Godot's numbers differ from these by more than rounding, stop and report.

**Verify:** walk the cabin and render it:
- the bridge from the helm and from the corridor, with the bunk room in its back corner;
- inside the bunk room, with its two windows;
- the bathroom.

Until Task 2 the engine-room cell is open common deck.

**Commit:** `feat: quantum cells replace the reactors, and the port rooms move forward a row`

---

### Task 2: The engine room's layout, and Rule 7

**Files:**
- Modify: `interior_layout.gd`, `interior_palette.gd` (the `ROOM_FLOOR` entry),
  `ship_validator.gd`
- Tests: `test_interior_layout.gd`, `test_interior_builder.gd`, `test_ship_validator.gd`,
  `test_starter_shuttle.gd`

**Interfaces produced:**
- `InteriorLayout.ROOM_IDS` gains `&"quantum_room"`, and `QUANTUM_ROOM_ID := &"quantum_room"`.
- Wall records in a quantum room carry `"piece": StringName`: `&"machine"`, `&"engine"` or
  `&"conduits"`.
- `InteriorLayout.quantum_rooms() -> Array[Dictionary]`: `{zone, coords, doorway, key: Vector3i,
  seated: bool}`. `key` is the room's lowest cell. `seated` is true when both a machine and an engine
  were dealt.
- **`ShipValidator` Rule 7:** an error with code `&"QUANTUM_ROOM"` in two cases:
  - no quantum room has `seated` true (it asks `InteriorLayout.plan`, as Rule 6 asks `AirlockSite`);
  - the ship has no `quantum_cell`.

**What to do:**
- **In `_resolve_rooms`, resolve every airlock-zone room first,** then the rest. An airlock's inner
  hatch then claims its wall before a neighbouring room furnishes it.
- **After furnishing a quantum room's cells, deal pieces** (spec §6.1):
  1. rank the cells by distance from the doorway's face centre, then by lowest `(z, x)`;
  2. the first feature wall gets `machine`;
  3. the first secondary wall gets `engine`, or the next feature wall if there is no secondary;
  4. any other feature or secondary wall gets `conduits`.
- **Floor colour:** a deep violet-grey. Pin it at render in Task 3.
- **Existing validator fixtures** gain a quantum room and a quantum cell, so each test still isolates
  its own rule.

**Tests:**
- the zone;
- the airlock first: a room beside an airlock whose inner hatch opens into it has that wall as a
  doorway, with no piece there;
- dealing in a one-cell, a two-cell and a three-cell room, including a room with no secondary wall;
- **the starter:**
  - the engine room's doorway is (−1, 0, +2)'s +X wall, onto the corridor;
  - `machine` is on its −X wall and `engine` on its +Z wall;
  - its −Z wall keeps its trim;
  - the bunk room's and bathroom's doorways are on their +X walls;
  - five sliding doors become six;
  - the airlock's inner hatch still opens onto the corridor at (0, 0, +2);
- Rule 7: no room; a seated room; a room that cannot seat both; no quantum cell;
- the starter still has zero issues.

**Commit:** `feat: the engine room is a room, with its pieces dealt by the layout`

---

### Task 3: The engine, the machine and the conduits

**Files:**
- Create:
  - `src/quantum/quantum_core.gd`, `src/quantum/quantum_room.gd`;
  - `src/quantum/quantum_bay.gd`, a stub whose `fits` accepts anything with a value (its rules come
    in Task 6);
  - `src/quantum/charge_dock.gd`, the charge plate's interactable (its body only; charging comes in
    Task 7);
  - `src/ship/interior/readout_panel.gd`.
- Modify: `interior_props.gd`, `interior_dressing.gd`, `interior_builder.gd`, `interior_palette.gd`,
  `airlock_panel.gd` (now extends `ReadoutPanel`), `test_visual_style_rules.gd`
- Tests: `test_interior_props.gd`, `test_interior_dressing.gd`, new `test_quantum_core.gd`,
  `test_airlock_panel.gd` (unchanged behaviour after the extraction)

**Interfaces produced:**
- **`InteriorProps`:**
  - `quantum_engine(kit, f, variety)`: the pillar, 0.7 m wide and 0.5 m deep;
  - `quantum_machine(kit, f, variety)`, with `quantum_machine_bay() -> Transform3D`,
    `quantum_machine_screen()`, `quantum_machine_buttons() -> Array[Transform3D]` (◀, big, ▶),
    `quantum_machine_plate()` and `quantum_machine_conduit() -> PackedVector3Array` (the bead's path
    in the prop's frame);
  - `conduits(kit, f, variety)`;
  - `QUANTUM_ENGINE_WIDTH := 0.7`, `QUANTUM_ENGINE_DEPTH := 0.5`, `QUANTUM_MACHINE_WIDTH := 1.5`.
- **`QuantumCore` (`Node3D`, grid-blind):**
  - `setup(frame: Transform3D, layer: int)`;
  - `set_fill(fraction: float, reserve_fraction: float)`;
  - `set_state(&"lit" | &"boost" | &"dark" | &"relight")`;
  - `flash()`;
  - `lit_bars() -> int` (for tests).
- **`ReadoutPanel`:** `AirlockPanel`'s body, button and `Label3D` readout, lifted into a base
  class: `setup(role, layer_bits)`, `prompt_text()`, `interact(actor)`, `can_interact(actor)`, the
  `pressed` signal and `set_readout(lines, button_colour)`. Its size is a parameter, so the arrows
  can be small buttons with no screen.
- **`QuantumRoom` (`Node3D`):** `key`, `cells`, `core`, `bay: QuantumBay`, `panel: ReadoutPanel`,
  `prev_button`, `next_button`, `plate: ChargeDock`, `conduit_path: PackedVector3Array` (in interior
  space), `machine_frame`, `engine_frame`.
- `InteriorBuilder.quantum_rooms() -> Array[QuantumRoom]`.
- **`InteriorPalette`:** `QUANTUM`, `QUANTUM_DEEP`, the `ROOM_FLOOR` value.

**What to do:**
- **Build the props** from kit primitives to spec §6.2–6.4:
  - colliders on anything more than 0.15 m proud;
  - the machine's colliders built round the bay recess;
  - the engine's uprights following `InteriorProps.HEADROOM`;
  - one small `LIGHT_WARM` light at the engine;
  - the core on the glow batch in its own small kit, so it can turn and scale.
- **`InteriorDressing._room_piece`** gains a `&"quantum_room"` branch keyed on `face["piece"]`. It
  builds one `QuantumRoom` per `layout.quantum_rooms()` entry and places:
  - the `QuantumBay` at `f * quantum_machine_bay()`, accepting `&"any"`;
  - the three `ReadoutPanel`s at the buttons' frames;
  - the `ChargeDock` at the plate;
  - the conduit path, from the machine's conduit up and along the ceiling to the engine's crown.
- **Extract `ReadoutPanel`** with no behaviour change. The airlock's tests are the guard.
- **`test_visual_style_rules.gd`:** add the painting files, and add `quantum_core.gd`,
  `charge_dock.gd` and `readout_panel.gd` to the grid-blind list.

**Tests:**
- each prop in a bare frame, with pinned collider counts;
- the bay spot is clear of the machine's colliders;
- the engine stays within 0.5 m of its wall, so the doorway aisle stays 1.0 m;
- `QuantumCore`:
  - `set_fill(0.5, 0.1)` lights 5 bars;
  - `set_fill(0.08, 0.1)` lights only the reserve bar, amber;
  - `dark` lights none, and the core is unlit;
- the dressing on the starter: one `QuantumRoom` with every reference set.

**Verify:**
- **Render at 1.6 m**, and send the renders to the owner:
  - the engine room from its doorway;
  - the engine at 50%, at the reserve and dark (driven by hand);
  - the machine.
- **This is where the one-cell room is judged.** If it renders too cramped, stop and put the two-row
  shift (spec §5.5) to the owner before going on.
- **Pin** `QUANTUM`, `QUANTUM_DEEP` and the floor from these renders.
- **Render the warm-gold alternative** for `QUANTUM` beside the violet (spec §2, row 11).

**Commit:** `feat: the quantum engine and machine, drawn in the house style`

---

### Task 4: The store, the plant, lit and boost

**Files:**
- Create: `src/quantum/quantum_store.gd`, `src/quantum/quantum_values.gd`,
  `src/quantum/quantum_plant.gd`, `src/ui/energy_panel.gd`
- Modify: `ship.gd`, `flight_computer.gd`, `vehicle_telemetry.gd`, `flight_test.gd`,
  `flight_test.tscn` (the `EnergyPanel` in `HudRoot/Screen/Band/Row`)
- Tests: new `test_quantum_store.gd`, `test_quantum_plant.gd`, `test_energy_panel.gd`;
  `test_flight_computer.gd`, `test_vehicle_telemetry.gd`, `test_hud_scene_wiring.gd`

**Interfaces produced:**
- **`QuantumStore` (`RefCounted`):**
  - `amount: int`, `capacity: int`, `const RESERVE := 100`;
  - signals `changed(amount, capacity)` and `lit_changed(lit)`;
  - `is_lit()`, `room()`;
  - `can_spend(n, floor := RESERVE)` and `spend(n, purpose, floor := RESERVE) -> bool`, all or
    nothing, where `floor` is how far down the spend may go;
  - `spend_continuous(cost: float, purpose, floor := RESERVE) -> bool`, which accrues fractions per
    purpose;
  - `credit(n, source) -> bool`, refusing an overflow;
  - `drain(n, source) -> int`, down to 0;
  - `set_capacity(c)`, which clamps.
- **`QuantumValues`:** `BOOST_COST := 5.0`, `MAKE_MARKUP := 2`, `SUIT_FLOOR := 1`,
  `static func make_cost(def: ItemDefinition) -> int` (reads `quantum_value`, 0 until Task 5).
- **`QuantumPlant` (`Node`, `Ship/Quantum`):**
  - `store: QuantumStore`;
  - `bind(rooms: Array[QuantumRoom], stats: ShipStats)`: sets the capacity, starts the store at
    half on the first bind only, and drives each core from the store;
  - `rooms`;
  - signals `lit_changed(lit)` and `credited(amount, source)`.
- **`FlightComputer`:**
  - `var quantum: QuantumStore`, where null means free boost and always lit, as in every existing
    test;
  - dark means zero force and zero torque;
  - boost is spent per tick while boosting with translation input, and denied at the reserve;
  - `boost_refused: bool` goes to telemetry.
- **`VehicleTelemetry`:** `has_energy`, `energy`, `energy_capacity`, `energy_reserve`,
  `energy_label`, `energy_state`, `tool_text`, `boost_refused`.
- **`EnergyPanel` (`HudElement`):**
  - *QE 600*, with a bar and a reserve notch;
  - *BOOST −5/S* while boosting;
  - *BOOST · RESERVE* when refused;
  - *ENGINE DARK* in `WARNING`.

**What to do:**
- `Ship._ready` creates `Quantum`. `_rebuild_everything` calls `quantum.bind(...)` after the
  airlocks, and hands the store to the flight computer.
- The core's state follows the store and boost: `lit`, `boost` or `dark`.
- **The `.tscn` edit:** add the panel node with no comments. Read it back at runtime in
  `test_hud_scene_wiring.gd`.

**Tests:**
- every store rule in spec §15.1;
- the plant: the half start happens once, and survives a rebuild and a capacity change;
- flight: dark means no force or torque; boost spends 5/s and stops at the reserve; a null store
  changes nothing;
- the telemetry fields and the panel's text for each state.

**Verify:** a probe sits, boosts for 20 s, and sees the store fall by 100 (±1) and the gauge follow.
Render the band.

**Commit:** `feat: a quantum store lights the engine, and boost spends it`

*Phase A is playable here.*

---

### Task 5: Values and patterns

**Files:**
- Create: `src/quantum/pattern_library.gd`
- Modify: `item_definition.gd`, all 16 `data/items/*.tres`, `quantum_plant.gd`, `ship.gd`
  (learning the stocked kinds)
- Tests: `test_item_catalog.gd`, new `test_quantum_values.gd`, `test_pattern_library.gd`

**Interfaces produced:**
- `ItemDefinition.quantum_value: int` and `ItemDefinition.eva_tool: bool`.
- **`PatternLibrary`:** `knows(id)`, `learn(id) -> bool` (true when new), `known() -> Array`
  sorted by make cost (given a catalogue).
- `QuantumPlant.patterns`.
- `QuantumPlant.learn_stocked(ids)`, called by `Ship._stock()` with each id it stocks.

**What to do:** set every value from spec §4.2. Edit the `.tres` files as plain property lines,
with no comments, and read them back in the test.

**Tests:**
- every item has a value > 0 unless it is an EVA tool;
- the values match the spec's table;
- make cost is 2 × value;
- the starter knows exactly the sixteen stocked kinds after its first load;
- `learn` reports new once.

**Commit:** `feat: everything has a quantum value, and the machine knows what the ship carried`

---

### Task 6: The machine

**Files:**
- Create: `src/quantum/machine_cycle.gd`, `src/quantum/quantum_show.gd`
- Modify: `quantum_bay.gd` (the real rules), `quantum_plant.gd`, `synth.gd` (`engine_hum`,
  `convert`, `materialize`)
- Tests: new `test_machine_cycle.gd`, `test_quantum_bay.gd`; `test_quantum_plant.gd`,
  `test_synth.gd`

**Interfaces produced:**
- **`MachineCycle` (`RefCounted`):**
  - `enum Stage { IDLE, CONVERTING, MAKING }`, with `CONVERT_TIME := 1.2`, `BEAD_TIME := 0.6` and
    `MAKE_TIME := 1.5`;
  - `selected: int`;
  - `press(button: StringName)`;
  - `step(delta, bay_item_id, bay_value, store: QuantumStore, patterns) -> Array[StringName]`,
    returning the spec §7.4 cues;
  - `prompt(button) -> String`, `screen() -> PackedStringArray` (three lines) and
    `button_colour() -> StringName`.
- **`QuantumBay`:** `fits(item)` applies the value, size and mass rules. `hold_turn(delta)` turns
  its item at 10°/s, and the plant calls it.
- **`QuantumShow` (grid-blind):**
  - `setup(bay_frame, conduit_path, layer)`;
  - `sparkle(on)`;
  - `run_bead(duration)`;
  - `flash()`;
  - `shrink(item, t)` and `swell(item, t)`, by scale.
- **`QuantumPlant`:**
  - `cycles: Dictionary` (key cell → `MachineCycle`);
  - it wires each room's panel and arrows to `press`;
  - it applies the cues: credit and learn on `&"credited"`; debit on `&"make_start"`; on
    `&"materialized"` it spawns the made item into `Ship.items` and secures it in the bay;
  - a converted item is removed with `remove_child()` then `free()` (SLICE-1-STATUS lessons);
  - it plays the sounds.

**What to do:**
- The screen lines, prompts and colours follow spec §7.1–7.2.
- The engine's hum plays positionally at the core on the Ship bus.
- Keep cycles across rebuilds by key cell. The bay's item re-seats by the existing `_reseat`.

**Tests:**
- the cycle, both ways, with timings and cues in order;
- the credit lands at `&"credited"`;
- the refusals;
- ◀ and ▶ wrap and are sorted;
- the bay: fits and refuses by value, size and mass;
- the plant, with real items:
  - dropping a mug into the bay and converting it makes the store +3, and the mug is freed with no
    orphans;
  - a make makes the store −6, with a stowed mug in the bay;
  - a rebuild mid-convert keeps the stage.

**Verify:**
- a real-scene probe: walk in, take a mug from the galley, drop it into the bay, press, and read
  the store; make one back; take it;
- render mid-convert and mid-make;
- measure frame time mid-convert.

**Commit:** `feat: the quantum machine converts things to energy and makes them back`

*Phase B is playable here.*

---

### Task 7: The suit cell and the charge plate

**Files:**
- Create: `src/quantum/suit_cell.gd`
- Modify: `charge_dock.gd` (charging), `avatar.gd`, `suit.gd`, `airlock.gd`, `quantum_plant.gd`,
  `energy_panel.gd`, `synth.gd` (`charge`)
- Tests: new `test_suit_cell.gd`, `test_charge_dock.gd`; `test_suit.gd`, `test_avatar_modes.gd`,
  `test_airlock_node.gd`, `test_energy_panel.gd`

**Interfaces produced:**
- **`SuitCell` (`RefCounted`):**
  - `charge: float` and `const CAPACITY := 100.0`;
  - `spend_dv(dv: float) -> bool` (false when dry);
  - `add(n) -> float`;
  - `level() -> StringName`: `&"ok"`, `&"low"` (25), `&"critical"` (10) or `&"dry"`;
  - `const GO_OUT_MIN := 10.0`.
- **`Avatar.suit_cell`.** In `suit_step`:
  - the Δv between the old and new velocity, excluding the tether, is charged to the cell;
  - when it is dry, the input is zero and `Suit.home_step` steers instead.
- **`Suit.home_step(v, v_ref, to_target: Vector3, delta) -> Vector3`:** pure. It chases
  `v_ref + dir × 1.5` at 1 m/s² and holds within 0.2 m.
- **`ChargeDock`:**
  - an interactable with the prompt *Charge suit (+n QE)* or *Suit charged*;
  - `interact` starts a charge;
  - the plant moves up to 50 QE/s from the store (floor 1) into the actor's `suit_cell` while the
    actor is within 1.2 m;
  - `set_readout(percent)`.
- **`Airlock`:** the room panel's depressurize is refused while the occupant's cell is under
  `GO_OUT_MIN`, with the status *CHARGE SUIT* and the prompt *Charge suit first*.
- **The telemetry on a spacewalk:** *SUIT*, the charge, its level, and the suit's warning chime at
  25 and 10.

**Tests:**
- the cell's costs and levels;
- full thrust for 1 s costs 2.5;
- holding station beside a drifting ship costs under 0.1/s;
- dry turns thrust off and heads home;
- the plate charges at 50/s, stops at 100 and at the store's floor of 1, and stops when you walk
  away;
- the airlock refuses depressurizing below 10 and allows it at 10 or more.

**Verify:**
- the suit probe (spec §15.2): refused empty, charge, cycle out, thrust until dry, be brought to the
  hatch, come in;
- render the plate charging and the suit HUD low.

**Commit:** `feat: the suit runs on quantum energy, charged at the machine`

*Phase C is playable here.*

---

### Task 8: Items in space and the salvage field

**Files:**
- Create: `src/world/salvage_field.gd`; `data/items/rock_chunk.tres`, `ice_chunk.tres`,
  `scrap_plate.tres`, `wire_coil.tres`, `broken_module.tres`, `quantum_shard.tres`
- Modify: `item.gd` (`set_space`), `item_looks.gd` (six looks), `interior_palette.gd` (`ICE`,
  `COPPER`), `flight_test.gd` (the salvage field under `Outside`, created in code)
- Tests: `test_item.gd`, `test_item_looks.gd`, `test_item_catalog.gd`, new
  `test_salvage_field.gd`

**Interfaces produced:**
- `Item.set_space(outside: bool)`: rebuilds the look's kit on render layer 1 (light mask 1) or 2,
  and sets the mask to `1 | 4 | 32` or `2 | 4 | 32`.
- **`SalvageField` (`Node3D`):**
  - `@export var seed`;
  - `build(catalog: ItemCatalog, stern: Transform3D)`: the near cloud is placed aft of the given
    stern transform;
  - `clouds() -> Array[Dictionary]`: `{centre, items}`.

**What to do:**
- Six looks from kit primitives (spec §10.3). The shard's crystal goes on the glow batch.
- The field spawns `Item`s with `set_space(true)`, a random slow drift and tumble, and sleeping
  allowed.

**Tests:**
- `set_space` both ways (layers, masks, the kit's layer);
- the looks build in bare boxes;
- the field is deterministic: counts, near-cloud distances, far-cloud distances, shards in half of
  the far clouds;
- the item catalogue has 22 entries.

**Verify:** render the near cloud from the open outer hatch and from a spacewalk. Measure frame time
on a spacewalk in the near cloud.

**Commit:** `feat: salvage drifting in space`

---

### Task 9: The hose

**Files:**
- Create: `src/quantum/hose_reel.gd`, `src/quantum/hose_nozzle.gd`, `src/quantum/hose_line.gd`,
  `src/quantum/tether.gd`, `src/ui/quantum_toast.gd`; `data/items/hose_nozzle.tres`
- Modify:
  - the airlock: `airlock_alcove.gd` (the reel), `airlock.gd` (the sink, the nozzle let go at the
    threshold);
  - the avatar: `grasp.gd` (EVA tools; `use` held and released), `interactor.gd` (the spacewalk
    mask `16 | 32`), `avatar.gd` (the tether in `suit_step`);
  - items and palettes: `item_use.gd` (`hold`), `item_looks.gd` (the nozzle's look),
    `hull_palette.gd` (`HOSE`);
  - `synth.gd` (`hose_draw`, `hose_gulp`), `flight_test.gd` (the toast);
  - `test_visual_style_rules.gd`.
- Tests: new `test_tether.gd`, `test_hose_nozzle.gd`, `test_hose_reel.gd`; `test_grasp.gd`,
  `test_interactor.gd`, `test_airlock_node.gd`

**Interfaces produced:**
- **`ItemUse.hold(active: bool)`:** a quiet default. Grasp calls it on the `use` press and release,
  after `use()`.
- **`Grasp`:** while `suspended`, an item whose definition has `eva_tool` may be taken, used, held
  and let go. Everything else stays blocked.
- **`HoseReel` extends `StowPoint`:** `accepts = &"hose"`, `anchor() -> Vector3` and `sink:
  Callable` (`func(item: Item) -> bool`, which credits the store). It winds a released nozzle home
  over 1 s, then secures it.
- **`HoseNozzle` extends `ItemUse`:**
  - `hold(true)` starts suction each physics frame: a sphere query on layer 32, the cone filter,
    the force-limited pull, the damped drift, the speed cap, and swallowing at 0.35 m through
    `reel.sink`;
  - `status()`: *drawing*, *too big* or *store full*;
  - `swallowed(id, value, new_pattern)` signal, for the toast.
- **`HoseLine`:** `setup(reel_anchor, nozzle, segments := 40, length := 30.0)`; verlet in
  `_physics_process`; drawn as a `MultiMesh` of bevelled segments on layer 1.
- **`Tether.constrain(pos, vel, anchor, length, delta) -> Vector3`:** pure.
- **`QuantumToast` (`HudElement`):** *+n QE* and *NEW PATTERN · NAME*, rising and fading over 1.2 s.
- **`AirlockAlcove`:** the reel prop on the jamb opposite the hull panel, and a `HoseReel` stocked
  with `hose_nozzle` on the first build.

**What to do:**
- `Airlock.bind` sets `reel.sink` to `QuantumPlant.credit_item`.
- **Crossing in:** at the threshold, the avatar's held EVA tool is let go before `enter_plating`.
- **Suit dry:** the nozzle is let go.
- The HUD's `tool_text` is *HOSE 12 M* while held.

**Tests:**
- the tether: slack, and taut;
- the nozzle, in a headless world with real items:
  - an item in the cone is pulled and one outside it is not;
  - the pull is force-limited for 40 kg;
  - a swallow calls the sink once and frees the item;
  - a refused sink stops suction;
  - too big is not pulled;
- the reel: a release reels home in 1 s;
- Grasp: an EVA tool passes `suspended` and a mug does not;
- the airlock: crossing in lets go of the nozzle;
- the reel is present on the alcove, on the own-hull layer.

**Verify:**
- the hose probe (spec §15.2): take the nozzle, drift into the near cloud, swallow three kinds, see
  the store rise by their values, hit the tether at 30 m, let go, and see it reel home;
- render a spacewalk with the hose drawing, and the reel on the hull;
- measure frame time with the hose drawing.

**Commit:** `feat: a hose on the airlock vacuums salvage into the ship's store`

*Phase D is playable here.*

---

### Task 10: Dark and relight

**Files:**
- Modify: `ship.gd`, `quantum_plant.gd`, `quantum_core.gd`, `synth.gd` (`engine_down`,
  `engine_up`)
- Tests: `test_quantum_plant.gd`, a new `test_ship_dark.gd`

**Interfaces produced:**
- `Ship` listens to `QuantumPlant.lit_changed`:
  - **dark:** every interior light with role `&"cell"` goes to 30% of its energy, and
    `InteriorMaterials.glow()`'s `energy` to 35% of 2.4;
  - **relight:** the sequence in spec §8.3, with lights ordered by `DeckGraph` walking distance
    from the engine room.
- The airlocks, the machine and its charge plate ignore dark.

**Tests:**
- draining to 0 turns flight off and dims the lights and glow;
- a credit starts the relight, which restores every light's energy exactly after 3 s plus the
  cell delay;
- a rebuild while dark stays dark.

**Verify:**
- the dark probe: set the store to 0, render the corridor and the engine room, convert an item,
  and render the relight at 0.5, 1.5 and 3 s;
- the ship flies again afterwards.

**Commit:** `feat: an empty store darkens the ship, and a relit engine brings it back`

*Phase E is playable here.*

---

### Task 11: Docs and the final check

- **Style guide** (spec §16):
  - §3.5, the engine room;
  - §2.8, the machine's screen;
  - §2.9, hearing the tool in your hands;
  - the palette entries;
  - items outside;
  - the frame-time figures.
- **The other amendments:**
  - slice spec §5, §6.1 and the roadmap;
  - hands-and-items §15 and §16;
  - airlock §7.4, §12 and §13;
  - Planetfall §18;
  - interior redesign §7.5, the starter's cabin layout;
  - **`SLICE-1-STATUS`:** a "what works" entry, with the moved rooms.
- **Final checks:**
  - the full suite;
  - every probe;
  - every render in spec §15.2, sent to the owner;
  - frame time in the engine room at rest and mid-convert, and on a spacewalk with the hose drawing;
  - the definition of done (spec §20), walked end to end.

**Commit:** `docs: record quantum energy, the engine room and the hose`
