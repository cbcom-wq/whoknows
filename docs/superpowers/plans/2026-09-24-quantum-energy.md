# Quantum Energy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Gate:** do not start until the owner has approved the spec as a whole. Every row of its §2 is
> decided (spec §2.1): rows 4–7 and 12 first, then the open questions, answered on 2026-09-25. If
> the owner changes anything at review, amend the spec first, then this plan.

**Goal:** Make quantum energy (QE) the ship's power source and the universe's currency:
- a quantum core at the centre of the bridge, and the quantum machine beside it;
- converting objects to QE and making them back;
- low power when the store runs low, and a pilot light when it is empty;
- a suit cell charged at the machine;
- salvage behind the stern and at every asteroid group, found with a HUD marker and gathered with
  a hose on the airlock.

**Architecture:**
- **The store** is a pure `QuantumStore` owned by one `QuantumPlant` node per ship. It lives across
  rebuilds, as the airlocks do.
- **Ordinary flight spends nothing.** Boost, making and the suit do. Below 10% of capacity the ship
  is in low power: half authority, no boost, no making, emergency light. Below 25 QE a pilot light
  refills the store.
- **The core and the machine are fixture blocks,** drawn by the dressing like the helm. They do not
  change the bridge's zones or wall variants. The dressing hands a `QuantumCore` and a
  `QuantumMachine` to the plant.
- **The machine** is a pure `MachineCycle`. Its bay is a `StowPoint`, so Grasp's stow-on-drop feeds
  it.
- **Salvage** belongs to one `SalvageField` under `Outside`. Its clouds come from the seed: a near
  cloud behind the stern, and one round every asteroid group's big rock. A pure `SalvageLedger`
  remembers what was taken, and a pure `SalvageSense` turns a cloud into a ping, a region or
  nothing for the HUD's `SalvageMarker`.
- **The hose** is an EVA-tool item on a reel on the airlock's hull face. It swallows salvage.
- **Everything outside follows the floating origin** (CLAUDE.md): free salvage and the hose line
  are `Universe.EXTERIOR_SPACE` members; the nozzle always lives under something that is.

**Tech Stack:** Godot 4.5.1 (Forward+), GDScript, GUT 9.5.

**Spec:** `docs/superpowers/specs/2026-09-24-quantum-energy-design.md`. Read it,
`docs/design/visual-style.md`, and the floating-origin section of
`docs/superpowers/specs/2026-09-24-asteroids-design.md` (§4) first.

## Global Constraints

- **Everything in `docs/design/visual-style.md` binds:**
  - colours only from `InteriorPalette`, or `HullPalette` on the hull's outside;
  - props never reference `ShipGrid`, `InteriorLayout`, `InteriorBuilder` or `InteriorDressing`;
  - exactly three interior shaders;
  - interior render layer 2 with light cull mask 2;
  - no shadows;
  - every light `LIGHT_WARM`.
- **The floating origin binds** (CLAUDE.md, asteroids spec §4):
  - everything outside the ship joins `Universe.EXTERIOR_SPACE` itself, under a parent that never
    moves, or lives under a member; never both;
  - world-space particles outside join `Universe.HOLDS_SHIFT`;
  - positions that must survive a shift (cloud centres) are `UniversePoint`s;
  - `test_floating_origin_scene.gd` must stay green with salvage loaded and the hose out.
- **CLAUDE.md:** no `#` comments in `.tscn`/`.tres`. Prove every scene and resource edit by reading
  the property back at runtime.
- **Workflow:**
  - branch `quantum-energy`;
  - run the import pass after adding a `class_name` (`--headless --path who-knows --import`), and
    commit Godot's `.uid` files;
  - tests: `who-knows\run_tests.ps1 [-gselect=<file>]`. Record the baseline on the branch before
    Task 1: 646 or more since the asteroids.
- **Power and the store:**
  - the quantum core generates 36 MW at full power and 18 MW in low power;
  - capacity 400 per `quantum_cell`: 1,200 on the starter;
  - it starts at half capacity on the first load only;
  - **no reserve:** every spend is all or nothing and may take the store to 0;
  - **the low-power line** is 10% of capacity, rounded up (120 on the starter); low power below it,
    full power at it;
  - **in low power:** thrust and torque × `LOW_POWER_AUTHORITY` (0.5); boost and making refused;
    converting, the suit charge, the airlocks and gravity unaffected;
  - **the pilot light:** below 25 QE, +1 QE every 5 s, up to 25 and never above;
  - whole QE; continuous costs accrue fractions;
  - a credit that would overflow is refused.
- **Costs:**
  - boost 5 QE/s, with translation input only; it cuts out when the store crosses the line;
  - make costs 2 × value; convert gives 1 × value;
  - a make that would cross the line warns (*→ LOW POWER*, `AMBER`) and still makes;
  - a suit charge moves QE one for one, down to 0.
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
- **The core:**
  - a 1.2 m footprint, and a 1.1 m square collider the full height;
  - rings at 0.25 rev/s, ×3 while boosting, 0.05 rev/s in low power;
  - pulse 0.5 Hz, 2 Hz while boosting, 0.2 Hz in low power;
  - ten gauge bars, the lowest being the low-power line: amber when it is all that is left, and
    lit amber at half brightness at 0.
- **Low power's look:** dropping takes 1 s, to cell lights at 30% and glow `energy` at 35%. Power
  restored takes 3 s, then lights return at 0.1 s per cell of walking distance from the core. A
  crossing mid-sequence reverses from where it has got to.
- **Salvage:**
  - the near cloud: 12 items, 12–40 m aft of the stern;
  - a cloud per asteroid group, keyed by the big rock's giant cell: centre 40–120 m off the big
    rock's surface, 10–16 items within 25 m of it, every item clear of every rock, one shard in
    about half the groups;
  - items spawn within 3 km of their cloud's centre and are freed beyond 4 km;
  - items tumble ≤ 20°/s and do not drift;
  - weights: rock 4, scrap 3, ice 3, wire 2, module 1;
  - a glint: 0.15 s every 2–4 s, seeded, visible to 50 m and gone by 60 m, in `LIGHT_WARM`.
- **Finding salvage** (`SalvageSense`):
  - a ping at 2–10 km: ±10°, a new seeded error every 4 s, the distance to the nearest kilometre;
  - a region within 2 km: a 75 m radius sphere, its centre within 50 m of the cloud's;
  - nothing inside the region;
  - the nearest three clouds with something left.
- **Layers** (spec §14.2):
  - items outside: layer 32, mask `1 | 4 | 32 | 64`, render layer 1;
  - the spacewalking Interactor: mask `16 | 32`;
  - the reel and the docked nozzle: the own-hull render layer (`ExteriorBuilder.OWN_HULL_LAYER`).
- **Values** are in spec §4.2. They are the only source; tests read them from the `.tres` files.
- Commit messages end with the session's attribution trailer.

---

### Task 1: The new blocks, the starter's bridge and Rule 7

**Files:**
- Create: `data/blocks/quantum_core.tres`, `data/blocks/quantum_machine.tres`,
  `data/blocks/quantum_cell.tres`
- Delete: `data/blocks/reactor.tres`, `data/blocks/battery.tres`
- Modify: `block_definition.gd`, `ship_stats.gd`, `ship_validator.gd`, `scenes/flight_test.gd`
  (`_starter_grid()` and its recorded-numbers comment)
- Tests: `test_block_data.gd`, `test_block_catalog.gd`, `test_ship_stats.gd`,
  `test_ship_validator.gd`, `test_starter_shuttle.gd`, the parity test

**Interfaces produced:**
- `BlockDefinition.quantum_capacity: int` (export group "Quantum").
- `ShipStats.quantum_capacity: int`, summed like power.
- **`ShipValidator` Rule 7:** an error with code `&"QUANTUM"` when a ship has no `quantum_core`, no
  `quantum_machine` or no `quantum_cell`.

**What to do:**
- **The blocks** (spec §5.1):
  - `quantum_core`: Interior, MOUNT, 5 t, hp 250, `power_gen` 36;
  - `quantum_machine`: Interior, MOUNT, 0.5 t, hp 100, `power_draw` 0.5;
  - `quantum_cell`: Systems, SOLID, 5 t, hp 250, capacity 400, with a box mesh like the reactor's.

  The two fixtures get placeholder box meshes. The exterior never shows them, since they sit inside
  the hull.
- **The starter** (spec §5.3):
  - `quantum_core` at (0, 0, −2), facing aft (`O_STERN`);
  - `quantum_machine` at (1, 0, −1), facing forward (`O_FORWARD`);
  - the reactors become quantum cells.
- **Replace the recorded-numbers comment** in `_starter_grid()` with the measured figures. Keep its
  pitch-balance reasoning, and add that the core's 5 t at cabin level bring the imbalance close to
  zero.
- **Existing validator fixtures** gain a core, a machine and a cell, so each test still isolates its
  own rule.

**Tests:**
- the new blocks' fields;
- `reactor` and `battery` are no longer in the catalogue;
- the capacity sum;
- Rule 7: no core; no machine; no cell; all three;
- **the starter pinned** (spec §5.4):
  - 84 blocks and 97,000 kg;
  - centre of mass (0.002, 1.206, 0.118);
  - imbalance (9,278, −3,093, 0) N·m;
  - torque budget (3,058,763, 2,029,381, 2,198,454);
  - 36.0 MW generated and 31.1 MW drawn;
  - capacity 1,200;
  - zero issues.

If Godot's numbers differ from these by more than rounding, stop and report: the spec's were
computed outside the engine.

**Verify:** fly the starter from the seat and the chase camera:
- assist reaches its pitch and roll rates within about a second;
- a full burn barely pitches the ship.

Until Task 3, the two fixture cells show only their placeholder boxes.

**Commit:** `feat: a quantum core and machine join the bridge, and quantum cells replace the reactors`

---

### Task 2: The bridge stays the bridge

**Files:**
- Modify: `interior_layout.gd`, `scenes/flight_test.gd` (`_place_avatar_on_deck()`)
- Tests: `test_interior_layout.gd`, `test_starter_shuttle.gd`, `test_hud_scene_wiring.gd` (the
  spawn, read back at runtime)

**Interfaces produced:**
- `InteriorLayout.QUIET_FIXTURES: Array[StringName] = [&"quantum_core", &"quantum_machine"]`.
- `_zone()` and the console rule (`by_the_helm`) skip quiet fixtures. A quiet fixture's own cell
  still counts as a MOUNT for its own walls, which go plain (`PANEL`), or `PORTHOLE` on a skin
  flank.

**What to do:**
- **Before the change,** record the starter's zone per cell and variant per face in the test as the
  expected values. The change must leave them equal, except (1, 0, −1)'s +Z wall, which becomes
  `PANEL`.
- **The spawn:** `_place_avatar_on_deck()` stands the avatar in the first cell aft of the helm that
  is walkable and holds no fixture: (0, 0, −1) on the starter.

**Tests:**
- the starter's zones and wall variants equal the recorded ones, with the one exception;
- the quantum fixtures are in `layout.fixtures()`;
- the spawn is at (0, 0, −1), clear of the core's footprint;
- standing up from the pilot seat still finds its first stand spot. The chair stands out in the
  canopy pod, 3.7 m ahead of the core.

**Commit:** `feat: the quantum fixtures leave the bridge's floor, consoles and portholes as they were`

---

### Task 3: The quantum core and the machine, drawn

**Files:**
- Create:
  - `src/quantum/quantum_core.gd`, `src/quantum/quantum_machine.gd`;
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
  - `quantum_core(kit, f, variety)`, in a fixture frame: the plinth, the glass column, the crown and
    the spine;
  - `quantum_core_crown_light() -> Vector3`, where the cell's light goes;
  - `quantum_machine(kit, f, variety)`, in a wall frame, with `quantum_machine_bay() ->
    Transform3D`, `quantum_machine_screen()`, `quantum_machine_buttons() -> Array[Transform3D]`
    (◀, big, ▶), `quantum_machine_plate()` and `quantum_machine_conduit() -> PackedVector3Array`
    (where the bead's path leaves the cabinet, in the prop's frame);
  - `QUANTUM_CORE_FOOTPRINT := 1.2`, `QUANTUM_MACHINE_WIDTH := 1.5`.
- **`QuantumCore` (`Node3D`, grid-blind):**
  - `setup(frame: Transform3D, layer: int)`;
  - `set_fill(fraction: float, line_fraction: float)`;
  - `set_state(&"full" | &"boost" | &"low_power" | &"restoring")`;
  - `flash()`;
  - `crown() -> Vector3`;
  - `lit_bars() -> int` (for tests).
- **`ReadoutPanel`:** `AirlockPanel`'s body, button and `Label3D` readout, lifted into a base
  class: `setup(role, layer_bits)`, `prompt_text()`, `interact(actor)`, `can_interact(actor)`, the
  `pressed` signal and `set_readout(lines, button_colour)`. Its size is a parameter, so the arrows
  can be small buttons with no screen.
- **`QuantumMachine` (`Node3D`):** `cell`, `bay: QuantumBay`, `panel: ReadoutPanel`,
  `prev_button`, `next_button`, `plate: ChargeDock`, `conduit_path: PackedVector3Array` (in interior
  space, from the cabinet to the nearest core's crown).
- `InteriorBuilder.quantum_cores() -> Array[QuantumCore]` and
  `quantum_machines() -> Array[QuantumMachine]`.
- `InteriorDressing.draws_fixture` is true for `quantum_core` and `quantum_machine`.
- **`InteriorPalette`:** `QUANTUM`, `QUANTUM_DEEP`.

**What to do:**
- **Build the props** from kit primitives to spec §6.2–6.3:
  - colliders on anything more than 0.15 m proud;
  - the machine's colliders built round the bay recess;
  - the core's crown following `InteriorProps.HEADROOM`;
  - the heart on the glow batch in its own small kit, so it can turn and scale;
  - the column in the `GLASS` batch.
- **`InteriorDressing._fixture`** gains two branches:
  - **The core** builds at `fixture_frame`. Its cell skips the round ceiling light, and the core's
    crown carries that cell's light, with the same role (`&"cell"`), energy and range.
  - **The machine** builds in `wall_frame(coord, -facing)`, the wall at its back. It places:
    - the `QuantumBay` at `f * quantum_machine_bay()`, accepting `&"any"`;
    - the three `ReadoutPanel`s at the buttons' frames;
    - the `ChargeDock` at the plate;
    - the conduit path: up from the cabinet, along the ceiling to the nearest core's crown.
- **Extract `ReadoutPanel`** with no behaviour change. The airlock's tests are the guard.
- **`test_visual_style_rules.gd`:** add the painting files, and add `quantum_core.gd`,
  `charge_dock.gd` and `readout_panel.gd` to the grid-blind list.

**Tests:**
- both props in bare frames, with pinned collider counts;
- the bay spot is clear of the machine's colliders;
- the core's collider is 1.1 m square, centred in its frame;
- `QuantumCore`:
  - `set_fill(0.5, 0.1)` lights 5 bars;
  - `set_fill(0.08, 0.1)` lights only the lowest bar, amber;
  - `set_fill(0.0, 0.1)` still lights the lowest bar, amber at half brightness;
  - `low_power` slows the rings and pulse to their low-power rates;
- the dressing on the starter:
  - one `QuantumCore` and one `QuantumMachine`, with every reference set;
  - the core's cell has no round ceiling light and exactly one cell light;
  - the machine's back is on (1, 0, −1)'s +Z wall;
  - one light per walkable cell still holds.

**Verify:**
- **The walk probe:** from the spawn, round the core either side to the helm, and sit; then to the
  machine. The core's and the machine's colliders stop the avatar.
- **Render at 1.6 m**, and send the renders to the owner:
  - the bridge from the corridor, with the core at its centre;
  - the bridge from the machine, and from beside the helm looking aft at the core;
  - the core at 50%, at the line and in low power (driven by hand);
  - the machine;
  - the seated view, which should be unchanged.
- **This is where the core's size on the bridge is judged.** If it crowds the bridge, shrink the
  plinth before going on.
- **The owner chooses QE's colour here** (spec §2, row 11):
  - render `QUANTUM` as violet and as a warm gold, side by side, on the real bridge;
  - render each beside a veined asteroid, whose crystal is `SpacePalette.CRYSTAL`
    (`InteriorPalette.LAVENDER`), so the owner sees whether the veins read as quantum ore;
  - pin `QUANTUM` and `QUANTUM_DEEP` to the owner's choice.
- **Measure frame time** on the bridge, looking through the core's glass at the canopy.

**Commit:** `feat: the quantum core and machine, drawn in the house style`

---

### Task 4: The store, the plant, boost and low power's rules

**Files:**
- Create: `src/quantum/quantum_store.gd`, `src/quantum/quantum_values.gd`,
  `src/quantum/quantum_plant.gd`, `src/ui/energy_panel.gd`
- Modify: `ship.gd`, `flight_computer.gd`, `vehicle_telemetry.gd`, `flight_test.gd`,
  `flight_test.tscn` (the `EnergyPanel` in `HudRoot/Screen/Band/Row`)
- Tests: new `test_quantum_store.gd`, `test_quantum_plant.gd`, `test_energy_panel.gd`;
  `test_flight_computer.gd`, `test_vehicle_telemetry.gd`, `test_hud_scene_wiring.gd`

**Interfaces produced:**
- **`QuantumStore` (`RefCounted`):**
  - `amount: int`, `capacity: int`;
  - `const LOW_POWER_FRACTION := 0.1`, `const PILOT_CAP := 25`, `const PILOT_PERIOD := 5.0`;
  - signals `changed(amount, capacity)` and `low_power_changed(low: bool)`;
  - `line() -> int` (`ceil(capacity × 0.1)`), `is_low_power() -> bool`, `room() -> int`;
  - `can_spend(n) -> bool` and `spend(n, purpose) -> bool`, all or nothing, down to 0;
  - `spend_continuous(cost: float, purpose) -> bool`, which accrues fractions per purpose;
  - `credit(n, source) -> bool`, refusing an overflow;
  - `drain(n, source) -> int`, down to 0;
  - `tick(delta)`: the pilot light, crediting from `&"pilot"` while below `PILOT_CAP`;
  - `set_capacity(c)`, which clamps.
- **`QuantumValues`:** `BOOST_COST := 5.0`, `MAKE_MARKUP := 2`, `LOW_POWER_AUTHORITY := 0.5`,
  `static func make_cost(def: ItemDefinition) -> int` (reads `quantum_value`, 0 until Task 5).
- **`QuantumPlant` (`Node`, `Ship/Quantum`):**
  - `store: QuantumStore`;
  - `bind(cores: Array[QuantumCore], machines: Array[QuantumMachine], stats: ShipStats)`: sets the
    capacity, starts the store at half on the first bind only, and drives each core from the store;
  - `_physics_process` ticks the store's pilot light;
  - `cores` and `machines`;
  - signals `low_power_changed(low)` and `credited(amount, source)`.
- **`FlightComputer`:**
  - `var quantum: QuantumStore`, where null means free boost and full power, as in every existing
    test;
  - in low power, every force and torque is scaled by `LOW_POWER_AUTHORITY`;
  - boost is spent per tick while boosting with translation input; it is refused in low power and
    cuts out on the tick the store crosses the line;
  - `boost_refused: bool` goes to telemetry.
- **`VehicleTelemetry`:** `has_energy`, `energy`, `energy_capacity`, `energy_line`,
  `energy_label`, `energy_state`, `tool_text`, `boost_refused`.
- **`EnergyPanel` (`HudElement`):**
  - *QE 600*, with a bar and a notch at the line;
  - *BOOST −5/S* while boosting;
  - *LOW POWER* in `WARNING`, and *BOOST · LOW POWER* when boost is refused.

**What to do:**
- `Ship._ready` creates `Quantum`. `_rebuild_everything` calls `quantum.bind(...)` after the
  airlocks, and hands the store to the flight computer.
- The core's state follows the store and boost: `full`, `boost` or `low_power`. Until Task 11 the
  change is instant: no light dimming and no power-restored show.
- **The `.tscn` edit:** add the panel node with no comments. Read it back at runtime in
  `test_hud_scene_wiring.gd`.

**Tests:**
- every store rule in spec §15.1: the line, rounding up; all or nothing; spends to 0; the pilot
  light's rate, cap and silence above 25; overflow refused; clamping; whole-QE debits;
- the plant: the half start happens once, and survives a rebuild and a capacity change;
- flight:
  - low power halves force and torque, and full power leaves them as today;
  - boost spends 5/s, cuts out as the store crosses the line, and is refused below it;
  - a null store changes nothing;
- the telemetry fields and the panel's text for each state.

**Verify:** a probe sits and boosts from 600:
- the store falls by 5/s (±1 per second) and the gauge follows;
- boost cuts out as the store crosses 120, and the HUD reads *LOW POWER*;
- the ship's forward acceleration halves (7.75 m/s², against 15.5).

Render the band at full power and in low power.

**Commit:** `feat: a quantum store powers the core; boost spends it, and a low store limps`

*Phase A is playable here.*

---

### Task 5: Values

**Files:**
- Modify: `item_definition.gd`, all 16 `data/items/*.tres`, `quantum_values.gd`
- Tests: `test_item_catalog.gd`, new `test_quantum_values.gd`

**Interfaces produced:**
- `ItemDefinition.quantum_value: int` and `ItemDefinition.eva_tool: bool`.
- `QuantumValues.makeable(catalog: ItemCatalog) -> Array[ItemDefinition]`: every item with a value,
  EVA tools left out, sorted by make cost.

**What to do:** set every value from spec §4.2. Edit the `.tres` files as plain property lines,
with no comments, and read them back in the test.

**Tests:**
- every item has a value > 0 unless it is an EVA tool;
- the values match the spec's table;
- make cost is 2 × value;
- `makeable` lists every item with a value, no EVA tools, cheapest first.

**Commit:** `feat: everything has a quantum value`

---

### Task 6: The machine

**Files:**
- Create: `src/quantum/machine_cycle.gd`, `src/quantum/quantum_show.gd`
- Modify: `quantum_bay.gd` (the real rules), `quantum_plant.gd`, `item.gd` (the `consumed`
  signal), `synth.gd` (`core_hum`, `convert`, `materialize`)
- Tests: new `test_machine_cycle.gd`, `test_quantum_bay.gd`; `test_quantum_plant.gd`,
  `test_item.gd`, `test_synth.gd`

**Interfaces produced:**
- **`MachineCycle` (`RefCounted`):**
  - `enum Stage { IDLE, CONVERTING, MAKING }`, with `CONVERT_TIME := 1.2`, `BEAD_TIME := 0.6` and
    `MAKE_TIME := 1.5`;
  - `selected: int`;
  - `press(button: StringName)`;
  - `step(delta, bay_item_id, bay_value, store: QuantumStore, makeable: Array) -> Array[StringName]`,
    returning the spec §7.4 cues;
  - `prompt(button) -> String`, `screen() -> PackedStringArray` (three lines) and
    `button_colour() -> StringName`.
- **`QuantumBay`:** `fits(item)` applies the value, size and mass rules. `hold_turn(delta)` turns
  its item at 10°/s, and the plant calls it.
- **`Item.consumed` signal:** emitted once by whatever converts or swallows the item, just before
  it is freed. Nothing aboard listens yet; `SalvageField` will (Task 8).
- **`QuantumShow` (grid-blind):**
  - `setup(bay_frame, conduit_path, layer)`;
  - `sparkle(on)`;
  - `run_bead(duration)`;
  - `flash()`;
  - `shrink(item, t)` and `swell(item, t)`, by scale.
- **`QuantumPlant`:**
  - `cycles: Dictionary` (the machine's cell → `MachineCycle`);
  - it wires each machine's panel and arrows to `press`;
  - it applies the cues: credit on `&"credited"`; debit on `&"make_start"`; on
    `&"materialized"` it spawns the made item into `Ship.items` and secures it in the bay;
  - a converted item emits `consumed`, then is removed with `remove_child()` then `free()`
    (SLICE-1-STATUS lessons);
  - it plays the sounds.

**What to do:**
- The screen lines, prompts and colours follow spec §7.1–7.2:
  - making is refused with *NOT ENOUGH QE* and with *MAKE · LOW POWER*;
  - a make that would cross the line shows *→ LOW POWER* with an `AMBER` button, and still makes.
- The core's hum plays positionally at the core on the Ship bus, quieter than the ship's hum.
- Keep cycles across rebuilds by the machine's cell. The bay's item re-seats by the existing `_reseat`.

**Tests:**
- the cycle, both ways, with timings and cues in order;
- the credit lands at `&"credited"`;
- the refusals: store full, not enough QE, low power;
- the low-power warning, and that pressing through it still makes;
- converting works in low power;
- ◀ and ▶ wrap and are sorted;
- the bay: fits and refuses by value, size and mass;
- the plant, with real items:
  - dropping a mug into the bay and converting it makes the store +3; the mug emits `consumed`
    once and is freed with no orphans;
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
  - the plant moves up to 50 QE/s from the store (down to 0, in low power too) into the actor's
    `suit_cell` while the actor is within 1.2 m;
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
- the plate charges at 50/s, stops at 100 and when the store reaches 0, and stops when you walk
  away;
- the plate charges in low power;
- after a charge empties the store, the pilot light brings it back to 25;
- the airlock refuses depressurizing below 10 and allows it at 10 or more.

**Verify:**
- the suit probe (spec §15.2): refused empty, charge, cycle out, thrust until dry, be brought to the
  hatch, come in;
- render the plate charging and the suit HUD low.

**Commit:** `feat: the suit runs on quantum energy, charged at the machine`

*Phase C is playable here.*

---

### Task 8: Items in space, the near cloud and the ledger

**Files:**
- Create: `src/world/salvage_field.gd`, `src/world/salvage_ledger.gd`;
  `data/items/rock_chunk.tres`, `ice_chunk.tres`, `scrap_plate.tres`, `wire_coil.tres`,
  `broken_module.tres`, `quantum_shard.tres`
- Modify: `item.gd` (`set_space`), `item_looks.gd` (six looks, and the glint),
  `interior_palette.gd` (`ICE`, `COPPER`), `flight_test.gd` (the salvage field under `Outside`,
  created in code), `test_floating_origin_scene.gd`
- Tests: `test_item.gd`, `test_item_looks.gd`, `test_item_catalog.gd`, new
  `test_salvage_field.gd`, `test_salvage_ledger.gd`

**Interfaces produced:**
- `Item.set_space(outside: bool)`: rebuilds the look's kit on render layer 1 (light mask 1) or 2,
  and sets the mask to `1 | 4 | 32 | 64` or `2 | 4 | 32`. It does **not** touch floating-origin
  groups: whoever parents the item decides (spec §10.1).
- **`SalvageLedger` (`RefCounted`):** `take(cloud_id, index)`, `is_taken(cloud_id, index) -> bool`,
  `remaining(cloud_id, count) -> int`.
- **`SalvageField` (`Node3D`, under `Outside`, at the identity, never moved, not a member):**
  - `setup(universe: Universe, catalog: ItemCatalog, world_seed: int)`;
  - `add_near_cloud(stern: Transform3D)`: fixes the near cloud's centre as a `UniversePoint`, aft
    of the given stern transform;
  - `ledger: SalvageLedger`;
  - `cloud_items(cloud_id) -> Array[Dictionary]`: `{index, kind, pose, tumble}`, from the seed and
    the id alone;
  - `_physics_process` loads a cloud's items within 3 km of its centre and frees them beyond 4 km;
  - each spawned item is `set_space(true)`, joins `Universe.EXTERIOR_SPACE`, and is watched for
    `consumed`, which records it in the ledger. It leaves the group before it is freed.

**What to do:**
- Six looks from kit primitives (spec §10.5). The shard's crystal goes on the glow batch.
- **The glint** is a child of each salvage look: an unshaded billboard quad in
  `InteriorPalette.LIGHT_WARM` on render layer 1, flashing for 0.15 s every 2–4 s from a seeded
  phase, with its visibility range fading it out between 50 and 60 m.
- Items tumble in place from their seeded spin and do not drift (spec §10.2).
- The flight scene creates the field after the stream starts and adds the near cloud behind the
  starter's stern.

**Tests:**
- `set_space` both ways: layers, masks, the kit's layer, and no group change;
- the looks and the glint build in bare boxes;
- the near cloud is deterministic: 12 items, 12–40 m aft of the stern;
- the ledger: a taken item is left out when the cloud reloads; `remaining` counts down;
- swallowing is simulated by emitting `consumed`: the ledger records it once;
- loading and freeing: beyond 4 km the items are freed with no orphans; within 3 km they are back,
  minus what was taken;
- **the floating origin:** with the near cloud loaded, `test_everything_outside_is_covered` passes,
  and a shift moves the salvage with the hull;
- the item catalogue has 22 entries.

**Verify:** render the near cloud from the open outer hatch and from a spacewalk, with glints.
Measure frame time on a spacewalk in the near cloud.

**Commit:** `feat: salvage drifting behind the stern, remembered once taken`

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
  - `test_visual_style_rules.gd`, `test_floating_origin_scene.gd`.
- Tests: new `test_tether.gd`, `test_hose_nozzle.gd`, `test_hose_reel.gd`, `test_hose_line.gd`;
  `test_grasp.gd`, `test_interactor.gd`, `test_airlock_node.gd`

**Interfaces produced:**
- **`ItemUse.hold(active: bool)`:** a quiet default. Grasp calls it on the `use` press and release,
  after `use()`.
- **`Grasp`:** while `suspended`, an item whose definition has `eva_tool` may be taken, used, held
  and let go. Everything else stays blocked, and shows no *Take* prompt.
- **`HoseReel` extends `StowPoint`:** `accepts = &"hose"`, `anchor() -> Vector3` and `sink:
  Callable` (`func(item: Item) -> bool`, which credits the store). It winds a released nozzle home
  over 1 s, under itself, then secures it.
- **`HoseNozzle` extends `ItemUse`:**
  - `hold(true)` starts suction each physics frame: a sphere query on layer 32, the cone filter,
    the force-limited pull, the damped drift, the speed cap, and swallowing at 0.35 m through
    `reel.sink`, after which the swallowed item emits `consumed` and is freed;
  - `status()`: *drawing*, *too big* or *store full*;
  - `swallowed(id, value)` signal, for the toast.
- **`HoseLine` (`Node3D`, under `Outside`, a member of `Universe.EXTERIOR_SPACE`):**
  `setup(reel, nozzle, segments := 40, length := 30.0)`; verlet in `_physics_process`, with the
  rope points kept in its own frame, and the reel's anchor and the nozzle's tail read afresh each
  tick; drawn as a `MultiMesh` of bevelled segments on layer 1.
- **`Tether.constrain(pos, vel, anchor, length, delta) -> Vector3`:** pure. The avatar passes the
  reel's anchor read that tick.
- **`QuantumToast` (`HudElement`):** *+n QE · NAME*, rising and fading over 1.2 s.
- **`AirlockAlcove`:** the reel prop on the jamb opposite the hull panel, and a `HoseReel` stocked
  with `hose_nozzle` on the first build. The nozzle is `set_space(true)` and never a member: it
  lives under the reel, or in your hands (spec §10.1, §11.1).

**What to do:**
- `Airlock.bind` sets `reel.sink` to `QuantumPlant.credit_item`.
- **Crossing in:** at the threshold, the avatar's held EVA tool is let go before `enter_plating`.
- **Suit dry:** the nozzle is let go.
- The HUD's `tool_text` is *HOSE 12 M* while held.
- Suction works in low power.
- Any world-space particles at the mouth join `Universe.HOLDS_SHIFT`.

**Tests:**
- the tether: slack, and taut;
- the nozzle, in a headless world with real items:
  - an item in the cone is pulled and one outside it is not;
  - the pull is force-limited for 40 kg;
  - a swallow calls the sink once, emits `consumed` once, and frees the item;
  - a refused sink stops suction;
  - too big is not pulled;
- the reel: a release reels home in 1 s;
- the line: a shift moves its node, and its points stay where they were relative to the reel;
- Grasp: an EVA tool passes `suspended` and a mug does not;
- the airlock: crossing in lets go of the nozzle;
- the reel is present on the alcove, on the own-hull layer;
- **the floating origin:** with the hose out on a spacewalk, `test_everything_outside_is_covered`
  passes, the nozzle is not a member, and a spacewalk across a shift keeps the hose, the tether
  and the salvage where they were relative to you.

**Verify:**
- the hose probe (spec §15.2): take the nozzle, drift into the near cloud, swallow three kinds, see
  the store rise by their values, hit the tether at 30 m, let go, and see it reel home;
- render a spacewalk with the hose drawing, and the reel on the hull;
- measure frame time with the hose drawing.

**Commit:** `feat: a hose on the airlock vacuums salvage into the ship's store`

*Phase D is playable here.*

---

### Task 10: Salvage at the groups, and finding it

**Files:**
- Create: `src/world/salvage_sense.gd`, `src/ui/salvage_marker.gd`
- Modify: `salvage_field.gd` (group clouds, `known_clouds`, readings), `flight_test.gd` (the
  marker, created in code and bound to the field)
- Tests: `test_salvage_field.gd`, new `test_salvage_sense.gd`, `test_salvage_marker.gd`;
  `test_floating_origin_scene.gd`

**Interfaces produced:**
- **`SalvageField`:**
  - `group_cloud(giant_cell: Vector3i) -> Dictionary`: `{id, centre: UniversePoint, big_rock}`, or
    `{}` for a region with no big rock. It reads its own `AsteroidRecipe` made with the stream's
    seed (`cell_rocks(Tier.GIANT, cell)`);
  - `cloud_items` for a group cloud: 10–16 items within 25 m of the centre, each kept clear of
    every rock by the recipe's bounding-sphere test, against the rubble and mid-size cells it
    overlaps and the big rock. That test is today's private `AsteroidRecipe._touches`: make it a
    public static (`touches`) rather than calling a private method from outside. One shard in
    about half the groups;
  - `known_clouds(focus: UniversePoint, range_m := 10000.0) -> Array[Dictionary]`: the near cloud
    and every group cloud in the giant cells within range, with `remaining`, spawning nothing.
    It is cached and refreshed when the focus crosses into a new giant cell;
  - `readings(focus: UniversePoint, time: float) -> Array[Dictionary]`: `SalvageSense`'s reading
    for the nearest three clouds with something left.
- **`SalvageSense` (pure, static):**
  - `const PING_FAR := 10000.0`, `REGION_NEAR := 2000.0`, `PING_ERROR_DEG := 10.0`,
    `PING_PERIOD := 4.0`, `REGION_RADIUS := 75.0`, `REGION_OFFSET := 50.0`;
  - `read(focus: UniversePoint, cloud_centre: UniversePoint, cloud_id, world_seed, time) ->
    Dictionary`: `{mode: &"ping" | &"region" | &"none", direction, km, centre, radius, metres}`;
  - `region_centre(cloud_centre, cloud_id, world_seed) -> UniversePoint`.
- **`SalvageMarker` (`HudElement`):** `bind(field: SalvageField)`. Each frame it asks the field for
  readings at the focus and draws each: a ping as a soft chevron with *SALVAGE ~4 KM*, fading
  between refreshes; a region as a ring round the projected sphere with *SALVAGE 640 M*; nothing
  inside the region. Off-screen and behind-you readings pin to the edge through
  `VelocityMarker.resolve`, as `AirlockMarker` does. It shows while seated or on a spacewalk.

**What to do:**
- A group cloud's centre lies in a seeded direction from the big rock's centre, 40–120 m off its
  surface (its bounding radius from `AsteroidRock.radius`).
- Loading and freeing work for group clouds exactly as for the near cloud (Task 8).
- Cloud ids are stable and hashable: `&"near"`, or the giant cell as a string key.

**Tests:**
- the same seed gives the same group cloud; counts; distance from the surface;
- **no item overlaps a rock**, over 200 groups;
- shards in 40–60% of 200 groups;
- `known_clouds` spawns no nodes and lists the start's own group;
- `SalvageSense`:
  - a ping beyond 2 km: its direction within 10° of the truth, the error changing every 4 s and
    staying the same within a period, `km` rounded;
  - a region within 2 km: radius 75 m, its centre within 50 m of the cloud's, and every item of
    the cloud inside it;
  - nothing inside the region;
- `readings` gives at most three, the nearest, and skips emptied clouds;
- the marker draws a ping, a region and nothing, and pins to the edge;
- **the floating origin:** with a group's cloud loaded, everything outside is covered, and a
  shift leaves the readings unchanged.

**Verify:**
- the salvage probe (spec §15.2): from the start, the first group's region shows; fly to it and the
  marker fades inside; find the cloud by eye and its glints; swallow two items; fly away past 4 km
  and back and see those two still gone; fly on to the next group, following its ping, across a
  floating-origin shift;
- render the HUD with a ping and a region, and a group's cloud at 50 m, glinting;
- measure frame time seated at a group's cloud, with the swarm in view.

**Commit:** `feat: salvage round every asteroid group, found by a ping and then a region`

*Phase E is playable here.*

---

### Task 11: Low power's look, and power restored

**Files:**
- Modify: `ship.gd`, `quantum_plant.gd`, `quantum_core.gd`, `synth.gd` (`core_down`,
  `core_up`)
- Tests: `test_quantum_plant.gd`, a new `test_ship_low_power.gd`

**Interfaces produced:**
- `Ship` listens to `QuantumPlant.low_power_changed`:
  - **dropping into low power, over 1 s:** every interior light with role `&"cell"` goes to 30% of
    its energy, and `InteriorMaterials.glow()`'s `energy` to 35% of 2.4; `core_down` plays;
  - **power restored:** the sequence in spec §8.3, with lights ordered by `DeckGraph` walking
    distance from the core's cell, and `core_up` at the end;
  - a crossing mid-sequence reverses from where it has got to.
- The core's states `low_power` and `restoring` (spec §6.2), and its hum lower and quieter in low
  power.
- The airlocks, the machine and its charge plate ignore low power, apart from the shared glow
  dimming.

**Tests:**
- crossing the line down dims every cell light to 30% and the glow to 35% after 1 s;
- crossing back up restores every light's energy exactly after 3 s plus the cell delay;
- a crossing back mid-sequence reverses without a jump;
- a rebuild in low power stays in low power, with the lights dimmed.

**Verify:**
- the low-power probe (spec §15.2): boost until the line, see the lights drop, fly at half
  authority, convert until the line and render the power-restored sequence at 0.5, 1.5 and 3 s;
- render the bridge and the corridor in low power;
- empty the store with a suit charge, and see the pilot light bring it to 25.

**Commit:** `feat: a low store dims the ship, and restored power comes back cell by cell`

*Phase F is playable here.*

---

### Task 12: Docs and the final check

- **Style guide** (spec §16):
  - §3.5, the core and the machine on the bridge;
  - §2.8, the machine's screen;
  - §2.9, hearing the tool in your hands;
  - the palette entries, including the choice made at Task 3;
  - items outside, and their glint;
  - low power's emergency light, and power restored;
  - the frame-time figures.
- **The other amendments:**
  - slice spec §5, §6.1 and the roadmap;
  - hands-and-items §15 and §16;
  - airlock §7.4, §12 and §13;
  - asteroids §4.4 and §13;
  - Planetfall §18;
  - interior redesign §7.5, the starter's bridge;
  - **`SLICE-1-STATUS`:** a "what works" entry, and the new flight figures replacing the old ones.
- **Final checks:**
  - the full suite;
  - every probe;
  - every render in spec §15.2, sent to the owner;
  - frame time on the bridge at rest and mid-convert, on a spacewalk with the hose drawing, and at
    a group's cloud;
  - the definition of done (spec §20), walked end to end.

**Commit:** `docs: record quantum energy, the core, the machine, salvage and the hose`
