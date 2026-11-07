# Desert World, Phase 0: Standing on a World — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every world pulls. A ship hovers, levels, lands and takes off on any world. You step out of its airlock and walk, jump and carry things there. A spacewalk in a ring stays the weightless spacewalk of today.

**Architecture:** There is one pure gravity source, `WorldGravity`. It is built once by the flight scene from the system, the universe and `Whereabouts`. Everything outside asks it: the flight computer of every ship, the avatar, loose items and the hostile pilot. The flight computer applies gravity as a force and spends its thrust on a gravity hold first. A `LandingMonitor` on each ship freezes it when it has settled on the ground. The airlock refuses to open onto a world until the ship is landed. The avatar gets a third mode, `FIELD`, for walking on a world with "up" pointing away from its centre.

**Tech Stack:** Godot 4.5.1, GDScript, GUT. Tests run with `who-knows/run_tests.ps1 -gselect=<test file without .gd>`.

**Spec:** `docs/superpowers/specs/2026-11-03-desert-world-design.md`, §5 (phase 0), §4 and §14 for decisions. Its §5 adopts Planetfall §7–§11 (`docs/superpowers/specs/2026-09-23-planetfall-design.md`) with changes. Where this plan and Planetfall differ, this plan wins.

**Work in:** `D:/git/whoknows-desert-world`, branch `desert-world`. Run Godot's `--import` once in this worktree before the first test, because its `.godot` cache starts empty.

## Global Constraints

- **Targeted tests only:** `run_tests.ps1 -gselect=<file>` for the files a task touches. Never run the full suite. The owner is asked at the end.
- **The floating origin** (CLAUDE.md) applies to anything put outside. It either joins `Universe.EXTERIOR_SPACE` or listens to `Universe.shifted`. World-space particles join `Universe.HOLDS_SHIFT`. Positions that must survive a shift are `UniversePoint`s.
- **`.tscn`/`.tres`:** no `#` comments inside blocks. Read every edited property back at runtime. Prefer adding nodes in code, as `Ship._ready` already does for its sensors.
- **Every ship is usable** (CLAUDE.md): nothing here reads the starter's numbers. Use the grid's keel and the ship's own budgets.
- **Colours come only from the palettes.** Phase 0 adds no colours.
- **Planets' gravity is 2–7 m/s²; moons' is 1–4.** Every library ship needs a lift margin of at least **1.3** at 7 m/s².
- **The star does not pull** (no recipe; star systems spec §13 leaves it open).
- **Gravity on the avatar, loose items and NPCs applies only *on a world*:** below the air top. The air top is 0.12 R (thin air), 0.20 R (thick) and 0.15 R (no air) above the radius. Ships feel the whole well, out to 2 R.
- **Low power never weakens the gravity hold.** It halves only the pilot's command and drift correction.
- **Hard landing (over 4.0 m/s closing speed) is a toast and a thud. No damage.**
- **Time on foot is unlimited. In `FIELD` the suit's thrusters are off.**
- **Hostiles never come below the air top plus 2 km.**
- **Do not bump `WorldRecipe.GENERATOR_VERSION`.** Gravity has never been felt in play, and a bump would send every save back to the start.
- **Skills are updated in the same branch** (CLAUDE.md): `building-a-ship`, `designing-a-ship` and `building-an-npc` (Task 12).

## Review Focus

These are the five things most likely to bite a player, though the spec implies them without testing them. Each one has its test in the task named.

1. **Spacewalking in a planet's ring** (inside the well, above the air): you must stay weightless and in `SUIT`, and a dropped item must not fall. Tasks 2 and 9.
2. **Warping into or out of a well:** gravity must not act on a ghosted or arriving hull. Otherwise the ship drops out of warp already falling, or is dragged during travel. Task 3.
3. **Loading a save made while landed on a slope:** the ship must come back frozen where it was, not slide or bounce while the ground under it streams in. Task 6.
4. **Landing and taking off on low power** after a long warp: the hold must still hover the starter on a 7 m/s² world. Task 3.
5. **Walking from one landed ship's airlock to another's** on a world. Any ship's threshold must take a `FIELD` avatar in, and the suit must switch ships on the way, as it does on a spacewalk. Task 13 (`landing_play.gd`) and Task 8.

---

## File Structure

| File | What it does |
|---|---|
| `who-knows/src/world/world_recipe.gd` (modify) | Gravity cap 7. `AIR_TOP` and `air_top()` |
| `who-knows/src/world/world_gravity.gd` (create) | The one gravity source: pure statics plus an instance that answers in engine space |
| `who-knows/src/ship/ship_rules.gd` (modify) | `CANNOT_LIFT` rule |
| `who-knows/src/flight/flight_computer.gd` (modify) | Applies gravity, the gravity hold, horizon levelling, lift telemetry |
| `who-knows/src/flight/landing_monitor.gd` (create) | The landing state machine (pure `step`) and the node that freezes the hull |
| `who-knows/src/ship/ship.gd` (modify) | Keel depth, the landing monitor, `on_world()`, `outside_refusal()`, save of `landed` |
| `who-knows/src/ship/grid_home.gd` (modify) | `on_world()` and `outside_refusal()` defaults, for bases |
| `who-knows/src/ship/fleet.gd` (modify) | Restores a landed hull frozen |
| `who-knows/src/ship/airlock/airlock.gd` (modify) | World refusals; hands a `FIELD` avatar across the threshold |
| `who-knows/src/avatar/avatar.gd` (modify) | `Mode.FIELD`, `enter_field`, field physics, jump, suit lamp, `is_outside()` |
| `who-knows/src/world/stray_field.gd` (modify) | Strays on a world fall |
| `who-knows/src/pilot/ship_pilot.gd` (modify) | Hostiles stay above the air |
| `who-knows/src/ui/vehicle_telemetry.gd`, `who-knows/src/ui/hull_panel.gd` (modify) | `ground_status` line |
| `who-knows/scenes/flight_test.gd` (modify) | Builds `WorldGravity` and hands it out. Toasts. `is_outside()` focus |
| `who-knows/project.godot` (modify) | `jump` action on Space |
| `who-knows/test/probes/landing_play.gd` (create) | Plays hover, land, walk, jump, drop, board and take off in real time |

---

### Task 1: The gravity cap, the air top and the lift rule

**Files:**
- Modify: `who-knows/src/world/world_recipe.gd`
- Modify: `who-knows/src/ship/ship_rules.gd` (`_check_flight`)
- Test: `who-knows/test/unit/test_world_recipe.gd`, `who-knows/test/unit/test_ship_rules.gd` (create if it doesn't exist; otherwise add to it), `who-knows/test/unit/test_ship_catalog.gd` (run only)

**Interfaces:**
- Produces: `WorldRecipe.GRAVITY` = `[Vector2(2.0, 7.0), Vector2(1.0, 4.0)]`; `WorldRecipe.AIR_TOP: Array[float]` indexed by `Atmosphere` = `[0.15, 0.12, 0.20]`; `WorldRecipe.air_top() -> float` (metres above `radius_m`); `ShipRules.LIFT_MARGIN := 1.3`; rule code `&"CANNOT_LIFT"`.

- [ ] **Step 1: Write the failing tests**

```gdscript
# test_world_recipe.gd
func test_planets_pull_at_most_seven():
	assert_eq(WorldRecipe.GRAVITY[WorldRecipe.Kind.PLANET], Vector2(2.0, 7.0))
	for s in 200:
		var r := WorldRecipe.from_seed(s)
		assert_between(r.surface_gravity, 2.0, 7.0)

func test_air_top_by_atmosphere():
	var r := WorldRecipe.from_seed(1)
	r.radius_m = 20000.0
	r.atmosphere = WorldRecipe.Atmosphere.NONE
	assert_almost_eq(r.air_top(), 3000.0, 0.01)
	r.atmosphere = WorldRecipe.Atmosphere.THIN
	assert_almost_eq(r.air_top(), 2400.0, 0.01)
	r.atmosphere = WorldRecipe.Atmosphere.THICK
	assert_almost_eq(r.air_top(), 4000.0, 0.01)

func test_gravity_change_moves_nothing_else():
	# Pinned from main at b280fa5 before the change: name, radius, archetype,
	# relief, palette and atmosphere of seeds 1, 7, 1337 and 90210.
	# Fill PINNED from a run on the unmodified code (Step 2), then keep it.
	for row in PINNED:
		var r := WorldRecipe.from_seed(row[0])
		assert_eq([r.name, snappedf(r.radius_m, 0.01), r.archetype, snappedf(r.relief_m, 0.01), r.palette, r.atmosphere], row.slice(1))

# test_ship_rules.gd
func test_cannot_lift_when_vertical_under_margin():
	var s := ShipStats.new()
	s.total_mass_kg = 100_000.0
	s.thrust_budget = {&"forward": 1e6, &"reverse": 1e6, &"lateral": 1e6, &"vertical": 900_000.0}
	var rules: Array = []
	ShipRules._check_flight(s, rules)
	assert_true(rules.any(func(r): return r.code == &"CANNOT_LIFT"))
	s.thrust_budget[&"vertical"] = 100_000.0 * 7.0 * 1.3 + 1.0
	rules.clear()
	ShipRules._check_flight(s, rules)
	assert_false(rules.any(func(r): return r.code == &"CANNOT_LIFT"))
```

- [ ] **Step 2: Fill `PINNED` from the unmodified code, then run the tests and see the new ones fail.** Before touching `world_recipe.gd`, print the six fields for the four seeds and paste them into `PINNED`. Then:
Run: `./run_tests.ps1 -gselect=test_world_recipe` and `-gselect=test_ship_rules`
Expected: `test_planets_pull_at_most_seven`, `test_air_top_by_atmosphere` and `test_cannot_lift_when_vertical_under_margin` fail; `test_gravity_change_moves_nothing_else` passes.

- [ ] **Step 3: Implement.** In `world_recipe.gd`, set `GRAVITY` to the new value. Rewrite its comment: capped so every library ship lifts off with `ShipRules.LIFT_MARGIN` (the desert world spec §5.4); the starter's two-way vertical is 9.5 m/s². Add `AIR_TOP` and `air_top()` with a doc comment citing the spec §5.1 and §6.1. In `ShipRules._check_flight`, add: if `vertical < LIFT_MARGIN × total_mass_kg × WorldRecipe.GRAVITY[PLANET].y`, add `item(&"CANNOT_LIFT", "%.1f m/s² of lift: it needs %.1f to leave a 7 m/s² world")`.

- [ ] **Step 4: Run the tests and the ship catalogue.**
Run: `-gselect=test_world_recipe`, `-gselect=test_ship_rules`, `-gselect=test_ship_catalog`
Expected: all PASS. The starter is 9.46 against 9.1, the warden 13.2 and the lamplighter 15.8. If a library ship fails `CANNOT_LIFT`, stop and report to the owner (spec §5.4).

- [ ] **Step 5: Commit** — `feat: planets pull at most 7 m/s², and every ship must lift off the heaviest`

---

### Task 2: `WorldGravity`, the one source

**Files:**
- Create: `who-knows/src/world/world_gravity.gd`
- Test: `who-knows/test/unit/test_world_gravity.gd`

**Interfaces:**
- Consumes: `SystemRecipe.bodies`, `SystemBody` (`point`, `radius`, `well_radius`, `recipe`), `Whereabouts.well_at(system, u)` and `Whereabouts.terrain_of(body)`, `Universe.to_universe(Vector3) -> UniversePoint`, `UniversePoint.minus(UniversePoint) -> Vector3`, `WorldRecipe.air_top()`.
- Produces (`class_name WorldGravity extends RefCounted`):
  - `static func vector(system: SystemRecipe, u: UniversePoint) -> Vector3`: m/s², pointing to the well's centre; `surface_gravity × (R / max(r, R))²` inside a world's well, else `Vector3.ZERO` (outside every well, or the star's).
  - `static func on_world(system: SystemRecipe, u: UniversePoint) -> bool`: in a world's well with `r − R < recipe.air_top()`.
  - `var system: SystemRecipe`, `var universe: Universe`, `var whereabouts: Whereabouts`; `func setup(p_system, p_universe, p_whereabouts) -> void`.
  - `func at(p: Vector3) -> Vector3`, `func on_world_at(p: Vector3) -> bool`, `func up_at(p: Vector3) -> Vector3` (away from the centre; `Vector3.ZERO` outside a world's well), `func altitude_at(p: Vector3) -> float` (over the terrain via `Whereabouts.terrain_of`, `INF` outside a world's well), `func surface_gravity_at(p: Vector3) -> float` (the well's `surface_gravity`, 0 outside). All take engine positions.

- [ ] **Step 1: Write the failing tests.** Build a system with `SystemRecipe.from_seed(1337)` and take its first planet `b` and its star. Make `UniversePoint`s at known offsets from `b.point` with `b.point.plus(offset: Vector3)`.

```gdscript
func test_surface_pull_is_the_recipes():
	var g := WorldGravity.vector(sys, b.point.plus(Vector3.UP * b.radius))
	assert_almost_eq(g.length(), b.recipe.surface_gravity, 0.001)
	assert_almost_eq(g.normalized(), Vector3.DOWN, Vector3.ONE * 1e-5)

func test_inverse_square():
	var g := WorldGravity.vector(sys, b.point.plus(Vector3.RIGHT * b.radius * 1.5))
	assert_almost_eq(g.length(), b.recipe.surface_gravity / 2.25, 0.001)

func test_nothing_beyond_the_well_or_from_the_star():
	assert_eq(WorldGravity.vector(sys, b.point.plus(Vector3.UP * (b.well_radius + 1.0))), Vector3.ZERO)
	assert_eq(WorldGravity.vector(sys, star.point.plus(Vector3.UP * star.radius * 1.1)), Vector3.ZERO)

func test_under_ground_pulls_as_at_the_ground():
	var g := WorldGravity.vector(sys, b.point.plus(Vector3.UP * b.radius * 0.5))
	assert_almost_eq(g.length(), b.recipe.surface_gravity, 0.001)

func test_on_world_line_is_the_air_top():
	var top := b.recipe.air_top()
	assert_true(WorldGravity.on_world(sys, b.point.plus(Vector3.UP * (b.radius + top - 1.0))))
	assert_false(WorldGravity.on_world(sys, b.point.plus(Vector3.UP * (b.radius + top + 1.0))))

func test_a_ring_is_not_on_a_world():   # Review Focus 1
	var ringed := _first_planet_with_ring(sys)   # pick any seed with a ring if 1337 has none
	var mid := (ringed.ring.inner + ringed.ring.outer) * 0.5
	var u := ringed.point.plus((ringed.ring.normal.cross(Vector3.UP).normalized()) * mid)
	assert_false(WorldGravity.on_world(sys, u))
	assert_gt(WorldGravity.vector(sys, u).length(), 0.0)   # a ship there still feels it
```

- [ ] **Step 2: Run** `-gselect=test_world_gravity` — Expected: FAIL (class missing).
- [ ] **Step 3: Implement `world_gravity.gd`.** The statics use `Whereabouts.well_at`. The instance converts engine positions with `universe.to_universe`. `altitude_at` uses `whereabouts.terrain_of(b).altitude_of(local)`, exactly as `Whereabouts.altitude()` does for the focus. The doc comment names the spec's §5.1 and says it is the one source: interiors never ask.
- [ ] **Step 4: Run** `-gselect=test_world_gravity` — Expected: PASS.
- [ ] **Step 5: Commit** — `feat: WorldGravity, the one answer to what pulls here`

---

### Task 3: The flight computer feels gravity and holds against it

**Files:**
- Modify: `who-knows/src/flight/flight_computer.gd`
- Modify: `who-knows/scenes/flight_test.gd` (the per-ship wiring beside `ship.flight_computer.whereabouts = ...`, about line 302; and build one `world_gravity: WorldGravity` after `star_system.setup(...)` in `_wire_universe`)
- Test: `who-knows/test/unit/test_flight_gravity.gd`

**Interfaces:**
- Consumes: `WorldGravity.at`, `WorldGravity.surface_gravity_at` (Task 2).
- Produces on `FlightComputer`:
  - `var gravity: WorldGravity = null` (null means deep space, as every existing test assumes).
  - `static func gravity_hold(g_local: Vector3, mass: float, budget: Dictionary) -> Vector3`: `−g_local × mass`, clamped to ±`lateral` on x, ±`vertical` on y, and on z to `−forward` / `+reverse`.
  - `static func within_budget(force: Vector3, budget: Dictionary, scale := 1.0) -> Vector3`: the same clamp with every budget × `scale`.
  - `func lift_margin() -> float`: `thrust_budget.vertical / (mass × surface_gravity_at(hull))`, or `INF` when not in a world's well.
  - `func translation_input() -> Vector3`: the pilot's latched translation (for Task 5).
- Produces on the flight scene: `var world_gravity: WorldGravity`, set up once in `_wire_universe`. It sets `ship.flight_computer.gravity = world_gravity` for every ship it wires, the starter included.

- [ ] **Step 1: Write the failing tests** (same `RigidBody3D` fixture as `test_flight_computer.gd`; budget `{forward 1.5e6, reverse 5e5, lateral 5e5, vertical 1e6}`, mass 105_700).

```gdscript
func test_hold_cancels_gravity_within_budget():
	var h := FlightComputer.gravity_hold(Vector3(0, -7.0, 0), 105_700.0, BUDGET)
	assert_almost_eq(h, Vector3(0, 7.0 * 105_700.0, 0), Vector3.ONE * 0.01)

func test_hold_is_clamped_to_the_budget():
	var h := FlightComputer.gravity_hold(Vector3(0, -20.0, 0), 105_700.0, BUDGET)
	assert_eq(h.y, 1e6)

func test_hold_on_a_pitched_hull_uses_the_engines_it_has():
	# Nose down 90°: gravity is along hull -z (forward); the hold pushes +z with the reverse budget.
	var h := FlightComputer.gravity_hold(Vector3(0, 0, -7.0), 105_700.0, BUDGET)
	assert_eq(h.z, minf(7.0 * 105_700.0, 5e5))

func test_sum_never_exceeds_budget():
	var f := FlightComputer.within_budget(Vector3(2e6, -3e6, -9e6), BUDGET)
	assert_eq(f, Vector3(5e5, -1e6, -1.5e6))

func test_low_power_never_weakens_the_hold():   # Review Focus 4
	_fc.thrust_budget = BUDGET
	_fc.quantum = _low_power_store()   # a QuantumStore in low power, as test_flight_computer builds one
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))   # a WorldGravity subclass stub answering at()
	_hull.mass = 105_700.0
	_fc._apply_translation(1.0 / 60.0)
	assert_almost_eq(_fc.commanded_force_local.y, 7.0 * 105_700.0, 1.0)

func test_assist_off_means_no_hold():
	_fc.assist_enabled = false
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_fc._apply_translation(1.0 / 60.0)
	assert_eq(_fc.commanded_force_local, Vector3.ZERO)

func test_no_gravity_during_warp():   # Review Focus 2
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_fc.warp = _travelling_warp_stub()   # a WarpDrive subclass whose travelling() returns true
	await wait_physics_frames(2)
	assert_eq(_hull.linear_velocity, Vector3.ZERO)

func test_frozen_hull_feels_nothing():
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_hull.freeze = true
	await wait_physics_frames(2)
	assert_eq(_hull.linear_velocity, Vector3.ZERO)
	assert_eq(_fc.commanded_force_local, Vector3.ZERO)
```

- [ ] **Step 2: Run** `-gselect=test_flight_gravity` — Expected: FAIL.
- [ ] **Step 3: Implement.**
  - In `_physics_process`, after the warp early-return: if the hull is frozen, zero the commands and return. Otherwise, if `gravity != null`, call `_hull.apply_central_force(gravity.at(_hull.global_position) × _hull.mass)`.
  - In `_apply_translation`, compute `hold` from the **unscaled** `thrust_budget` when `assist_enabled` and gravity isn't zero. Then `commanded_force_local = within_budget(hold + translation_force(...authority budget...), thrust_budget, BOOST_MULTIPLIER if boosting else 1.0)`.
  - In `build_telemetry`, add `t.lift_margin = lift_margin()`.
  - Doc comments cite the spec's §5.2 and Planetfall §8.2.
  - In `flight_test.gd`, build `world_gravity` and set it on every wired ship.
- [ ] **Step 4: Run** `-gselect=test_flight_gravity` and `-gselect=test_flight_computer` — Expected: PASS, the old file unchanged.
- [ ] **Step 5: Commit** — `feat: ships feel a world's pull and hover against it`

---

### Task 4: Horizon levelling and the keel

**Files:**
- Modify: `who-knows/src/flight/flight_computer.gd` (`_apply_rotation`), `who-knows/src/ship/ship.gd`
- Test: `who-knows/test/unit/test_flight_gravity.gd`, `who-knows/test/unit/test_ship_keel.gd`

**Interfaces:**
- Produces:
  - `FlightComputer.LEVEL_FROM := 150.0`, `LEVEL_FULL := 100.0`, `LEVEL_GAIN := 1.5`.
  - `static func level_rates(hull_basis: Basis, up: Vector3, keel_altitude: float, input: Vector3) -> Vector3`: pitch and roll rates in rad/s on axes where `input` is zero. It is `LEVEL_GAIN ×` the hull-up-to-`up` angle, split onto pitch (x) and roll (z), clamped to `ASSIST_TURN_RATE`, faded linearly from 0 at `LEVEL_FROM` to full at `LEVEL_FULL`. Yaw (y) is always 0.
  - `var keel_depth := 0.0` on `FlightComputer`, set by the ship.
  - `Ship.keel_depth() -> float`: metres from the hull's origin down (hull −Y) to the bottom face of the lowest occupied cell. Use `ShipGrid.cell_center(c).y − ShipGrid.CELL_SIZE / 2` over the grid's occupied cells, in the frame the exterior's colliders use (check against `ExteriorBuilder`).
  - `func keel_altitude() -> float` on `FlightComputer`: `gravity.altitude_at(hull) − keel_depth`, or `INF`.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_level_rates_fade_in_below_150():
	var tilted := Basis(Vector3.RIGHT, deg_to_rad(20))
	assert_eq(FlightComputer.level_rates(tilted, Vector3.UP, 200.0, Vector3.ZERO), Vector3.ZERO)
	var half := FlightComputer.level_rates(tilted, Vector3.UP, 125.0, Vector3.ZERO)
	var full := FlightComputer.level_rates(tilted, Vector3.UP, 50.0, Vector3.ZERO)
	assert_almost_eq(half.x, full.x * 0.5, 1e-4)
	assert_almost_eq(absf(full.x), minf(FlightComputer.LEVEL_GAIN * deg_to_rad(20), FlightComputer.ASSIST_TURN_RATE), 1e-4)
	assert_eq(full.y, 0.0)

func test_the_stick_wins():
	var tilted := Basis(Vector3.RIGHT, deg_to_rad(20))
	assert_eq(FlightComputer.level_rates(tilted, Vector3.UP, 50.0, Vector3(1, 0, 0)).x, 0.0)

# test_ship_keel.gd: a starter built from data/ships/starter.json
func test_starter_keel_is_its_lowest_cell_bottom():
	# starter.json's lowest row is y = -1: centre -2 m, bottom face -3 m in the grid's frame.
	# 3.0 holds if the hull's origin is the grid's origin; confirm in ExteriorBuilder, and if it
	# is offset (e.g. by the centre of mass), subtract that offset's y here and say so.
	assert_almost_eq(_starter.keel_depth(), 3.0, 0.01)
```

- [ ] **Step 2: Run** both — Expected: FAIL.
- [ ] **Step 3: Implement.** `_apply_rotation` adds `level_rates(...) / ASSIST_TURN_RATE` to `rotate` when assist is on, `gravity != null` and `keel_altitude() < LEVEL_FROM`. `Ship._ready` sets `flight_computer.keel_depth = keel_depth()`, and again after every grid rebuild (find where `ShipStats` budgets are re-applied).
- [ ] **Step 4: Run** `-gselect=test_flight_gravity`, `-gselect=test_ship_keel`, `-gselect=test_flight_computer` — PASS.
- [ ] **Step 5: Commit** — `feat: the assist levels the ship near the ground`

---

### Task 5: Landing

**Files:**
- Create: `who-knows/src/flight/landing_monitor.gd`
- Modify: `who-knows/src/ship/ship.gd` (create the monitor in `_ready` like `sensors`; `contact_monitor = true`, `max_contacts_reported = 8`)
- Modify: `who-knows/src/ui/vehicle_telemetry.gd`, `who-knows/src/ui/hull_panel.gd`, `who-knows/scenes/flight_test.gd` (toast and thud)
- Test: `who-knows/test/unit/test_landing_monitor.gd`

**Interfaces:**
- Consumes: `FlightComputer.translation_input()`, `keel_altitude()`, `gravity.up_at`, `lift_margin()` (Tasks 3–4); `BodyProxy.LAYER` for terrain contacts; `Synth` sound `&"hull_thump"` (check the builder's name in `Synth.build`).
- Produces (`class_name LandingMonitor extends Node`):
  - `enum State { FLYING, TOUCHING, LANDED }`. Constants: `HARD_LANDING := 4.0`, `SETTLE_TIME := 1.0`, `SETTLE_SPEED := 0.5`, `SETTLE_SPIN := 0.1`, `MAX_TILT := deg_to_rad(25.0)`, `LIFT_GRACE := 0.25`.
  - `static func step(s: Dictionary, i: Dictionary, delta: float) -> Dictionary`. `s` has `state`, `held` (seconds settled) and `apart` (seconds without contact). `i` has `touching: bool`, `closing: float`, `speed: float`, `spin: float`, `tilt: float` (radians) and `translating: bool`. The return is the new `s` plus `hard: float` (the closing speed if this step was a hard touchdown, else 0). It follows Planetfall §9's table exactly.
  - `signal state_changed(state: State)`, `signal hard_landing(speed: float)`.
  - `var state: State`, `func is_landed() -> bool`, `func tilt() -> float`, `func refusal() -> String`: "" when landed, "Uneven ground · tilt %d°" in TOUCHING over `MAX_TILT`, else "Not landed".
  - `func restore_landed() -> void`: sets LANDED and freezes at once (Task 6).
  - `func ground_status() -> String`: "LANDED", "UNEVEN GROUND · TILT %d°", "TOO HEAVY FOR THIS WORLD" (when `lift_margin() < 1.0`), or "".
  - On LANDED: `hull.freeze_mode = FREEZE_MODE_STATIC; hull.freeze = true`. On leaving LANDED: `freeze = false`.
  - `VehicleTelemetry.ground_status: String`. `HullPanel` shows it on `status_label` when not crippled.

- [ ] **Step 1: Write the failing tests** for the pure `step`, one per row of Planetfall §9's table and per refusal.

```gdscript
func _i(o := {}) -> Dictionary:
	var d := {touching = true, closing = 1.0, speed = 0.1, spin = 0.0, tilt = 0.0, translating = false}
	d.merge(o, true)
	return d

func test_first_contact_touches():
	var s := LandingMonitor.step({state = LandingMonitor.State.FLYING, held = 0.0, apart = 0.0}, _i(), 0.016)
	assert_eq(s.state, LandingMonitor.State.TOUCHING)
	assert_eq(s.hard, 0.0)

func test_hard_touchdown_reports_speed():
	var s := LandingMonitor.step({state = LandingMonitor.State.FLYING, held = 0.0, apart = 0.0}, _i({closing = 5.5}), 0.016)
	assert_eq(s.hard, 5.5)

func test_settled_for_a_second_lands():
	var s := {state = LandingMonitor.State.TOUCHING, held = 0.0, apart = 0.0}
	for k in 61:
		s = LandingMonitor.step(s, _i(), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.LANDED)

func test_tilt_over_25_never_lands():
	var s := {state = LandingMonitor.State.TOUCHING, held = 0.0, apart = 0.0}
	for k in 120:
		s = LandingMonitor.step(s, _i({tilt = deg_to_rad(31)}), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.TOUCHING)

func test_lost_contact_flies_again_after_grace():
	var s := {state = LandingMonitor.State.TOUCHING, held = 0.5, apart = 0.0}
	for k in 16:
		s = LandingMonitor.step(s, _i({touching = false}), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.FLYING)

func test_translation_lifts_off():
	var s := LandingMonitor.step({state = LandingMonitor.State.LANDED, held = 1.0, apart = 0.0}, _i({translating = true}), 0.016)
	assert_eq(s.state, LandingMonitor.State.FLYING)
```

- [ ] **Step 2: Run** `-gselect=test_landing_monitor` — FAIL.
- [ ] **Step 3: Implement.**
  - The node's `_physics_process` gathers the inputs from the hull: `get_colliding_bodies()` filtered to `BodyProxy.LAYER`; closing speed `−(v · up)`; spin `|ω|`; tilt the angle between hull up and `gravity.up_at`; translating `translation_input() != ZERO`.
  - It runs `step`, freezes or thaws, and emits.
  - Outside a world's well it stays FLYING and does nothing.
  - `flight_test.gd` connects `hard_landing` to `warp_panel.toast("HARD LANDING · %.1f M/S")` plus a `hull_thump` at the hull, heard on the Ship bus.
- [ ] **Step 4: Run** `-gselect=test_landing_monitor`, plus any `test_hull_panel`/`test_vehicle_telemetry` that exist — PASS.
- [ ] **Step 5: Commit** — `feat: ships land, settle and stay put`

---

### Task 6: A landed ship saves and loads landed

**Files:**
- Modify: `who-knows/src/ship/ship.gd` (`to_dict`: `"landed": landing.is_landed()`), `who-knows/src/ship/fleet.gd` (`restore_hull`), and wherever the starter's hull is restored in `flight_test.gd`
- Test: `who-knows/test/unit/test_landing_save.gd`

**Interfaces:**
- Consumes: `LandingMonitor.restore_landed()` (Task 5).
- Produces: save key `hull.landed: bool` (absent means false, so old saves load flying).

- [ ] **Step 1: Write the failing test** (Review Focus 3). Build a ship in a test scene as `test_fleet*.gd` does. Set its landing state to LANDED on a hull tilted 10°, save it with `to_dict`, restore a second ship with `Fleet.restore_hull`, then step 120 physics frames with no ground under it. Assert `landing.is_landed()`, `exterior.freeze`, and that the transform hasn't changed (`is_equal_approx`).
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.** Write the key; read it in `restore_hull` and call `restore_landed()` after the transform is set. `restore_landed` freezes at once, so the ground streaming in later never moves it.
- [ ] **Step 4: Run** `-gselect=test_landing_save` and the existing saving tests for ships (`-gselect=test_save_game` or whichever covers `Ship.to_dict`) — PASS.
- [ ] **Step 5: Commit** — `feat: a landed ship loads landed`

---

### Task 7: The airlock on a world

**Files:**
- Modify: `who-knows/src/ship/grid_home.gd` (defaults), `who-knows/src/ship/ship.gd` (overrides), `who-knows/src/ship/airlock/airlock.gd`
- Test: `who-knows/test/unit/test_airlock_world.gd`

**Interfaces:**
- Produces:
  - `GridHome.on_world() -> bool` (default false) and `GridHome.outside_refusal() -> String` (default "").
  - `Ship.on_world()`: `gravity != null and gravity.on_world_at(exterior.global_position)`, where `gravity` is `flight_computer.gravity`.
  - `Ship.outside_refusal()`: "" unless `on_world()`, then `landing.refusal()`.
  - `Airlock.HATCH_CLEAR := 2.5`.
  - `func world_refusal() -> String` on `Airlock`, checked in this order: "" unless the room is idle, pressurized and holds the avatar (as `must_charge` checks); then `_ship.outside_refusal()`; then "Hatch blocked" if a capsule cast (radius 0.35, height 1.8) from the outer hatch, `HATCH_CLEAR` m outward, hits `BodyProxy.LAYER | AsteroidBody.LAYER`.
  - `must_charge()` returns false when `_ship.on_world()`: the suit's thrusters are off there.
  - `static func refusal_order(warping: bool, world: String, charge: bool) -> String`: the prompt the room panel shows. "Not during a warp" wins, then `world`, then "Charge suit first".

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_warp_beats_everything():
	assert_eq(Airlock.refusal_order(true, "Not landed", true), "Not during a warp")

func test_world_refusal_beats_charge():
	assert_eq(Airlock.refusal_order(false, "Uneven ground · tilt 31°", true), "Uneven ground · tilt 31°")

func test_open_space_still_asks_for_charge():
	assert_eq(Airlock.refusal_order(false, "", true), "Charge suit first")

func test_base_never_refuses_for_ground():
	assert_eq(GridHome.new().outside_refusal(), "")
```

  Also a scene test: a starter held on a world (stub `WorldGravity` whose `on_world_at` is true), landing FLYING, avatar in the airlock room. Assert `prompt(&"room") == "Not landed"`, and that pressing leaves the cycle idle.
- [ ] **Step 2: Run** `-gselect=test_airlock_world` — FAIL.
- [ ] **Step 3: Implement.** `prompt`, `_on_pressed` and `_apply` go through `refusal_order`. The readout line shows `world.to_upper()` for a world refusal. "CHARGE SUIT" stays as it is.
- [ ] **Step 4: Run** `-gselect=test_airlock_world` and `-gselect=test_airlock` (the existing file) — PASS.
- [ ] **Step 5: Commit** — `feat: the airlock won't open onto a world until you're down`

---

### Task 8: Walking on a world (`FIELD`)

**Files:**
- Modify: `who-knows/src/avatar/avatar.gd`, `who-knows/src/ship/airlock/airlock.gd` (`_watch_threshold`), `who-knows/project.godot` (`jump` on physical key 32), `who-knows/scenes/flight_test.gd`
- Modify (review each `Mode.SUIT` use and switch it to `is_outside()` wherever it means "outside" rather than "floating on thrusters"): `src/avatar/suit_sounds.gd`, `src/camera/camera_director.gd`, `src/combat/core_blast.gd`, `src/combat/weapons.gd`, `src/habitat/package_use.gd`, `src/items/repair_torch.gd`, `src/ship/suit_tie.gd`, `scenes/flight_test.gd`
- Test: `who-knows/test/unit/test_avatar_field.gd`

**Interfaces:**
- Consumes: `WorldGravity.at` (Task 2); `GridHome.on_world()` (Task 7).
- Produces on `Avatar`:
  - `enum Mode { PLATING, SUIT, FIELD }` (append FIELD; saves store the mode by value, so append, never insert).
  - `const JUMP_SPEED := 3.1`, `const LAMP_RANGE := 25.0`, `const LAMP_ANGLE := 35.0`.
  - `var gravity: WorldGravity` (set by the flight scene) and `var up := Vector3.UP`.
  - `func is_outside() -> bool` (SUIT or FIELD).
  - `func enter_field(outside: Node3D, pose: Transform3D, start_velocity: Vector3, ship_hull: RigidBody3D) -> void`: as `enter_suit`, but `mode = FIELD`, `motion_mode = GROUNDED`, `grasp.suspended = false` with `grasp.world_root = outside`, and the old root kept for `enter_plating` to put back.
  - `static func field_basis(b: Basis, new_up: Vector3) -> Basis`: rotates `b` by the shortest arc from `b.y` to `new_up`, so heading is kept.
  - `static func field_velocity(v: Vector3, up: Vector3, wish: Vector3, speed: float, accel: float, g: Vector3, delta: float) -> Vector3`: adds `g × delta`; `move_toward`s the tangent part of `v` toward `wish × speed` (wish projected onto the tangent plane) at `accel`; leaves the part along `up` alone.
- In FIELD:
  - Mouse yaw turns about `up`.
  - `up_direction = up` every tick.
  - Space (`jump`) adds `up × JUMP_SPEED` when `is_on_floor()`.
  - Footfalls play as aboard.
  - The suit thrusters never run.
  - `lights_flood` (L) toggles a head `SpotLight3D` (range 25, angle 35, `light_cull_mask = 1`, no shadows), outside only.
- `_watch_threshold`: going out calls `enter_field` when `_ship.on_world()`, else `enter_suit`. Coming back in accepts `is_outside()`.
- `flight_test.gd`:
  - sets `_avatar.gravity = world_gravity`;
  - sets the universe's focus to the avatar when `is_outside()`;
  - connects `grasp.let_go` so an item let go in FIELD is `item.set_space(true)` and adopted by `strays`;
  - connects `grasp.taken` so a stray taken outside is let go from `strays`.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_field_basis_keeps_heading():
	var b := Basis(Vector3.UP, 0.7)
	var tilted_up := Vector3(0.1, 1.0, 0.0).normalized()
	var nb := Avatar.field_basis(b, tilted_up)
	assert_almost_eq(nb.y, tilted_up, Vector3.ONE * 1e-5)
	var fwd_before := Plane(Vector3.UP, 0).project(-b.z).normalized()
	var fwd_after := Plane(tilted_up, 0).project(-nb.z).normalized()
	assert_almost_eq(fwd_after, Plane(tilted_up, 0).project(fwd_before).normalized(), Vector3.ONE * 1e-4)

func test_field_velocity_walks_tangent_and_falls_along_up():
	var v := Avatar.field_velocity(Vector3(0, 0, 0), Vector3.UP, Vector3(0, 0, -1), 4.0, 30.0, Vector3(0, -5.0, 0), 0.1)
	assert_almost_eq(v, Vector3(0, -0.5, -3.0), Vector3.ONE * 1e-5)

func test_plating_is_unchanged():
	# PLATING regression (Planetfall §11.1): an avatar aboard with grav 9.8 and
	# no input falls 9.8 × delta per tick, straight down -Y, and never asks gravity.
	_avatar.gravity = _fake_gravity(Vector3(5, 0, 0))   # would pull sideways if asked
	# one physics tick with control enabled → velocity == Vector3(0, -9.8 / 60.0, 0)

func test_out_of_a_landed_ship_on_a_world_is_field():
	# Scene test: the threshold crossed outward with _ship.on_world() true puts the avatar in FIELD;
	# with it false (a ring), in SUIT (Review Focus 1).
```

- [ ] **Step 2: Run** `-gselect=test_avatar_field` — FAIL.
- [ ] **Step 3: Implement.** Add `_field_physics(delta)` beside `_suit_physics`, plus the input handling, the lamp and the threshold change. Go through the eight files' `Mode.SUIT` uses one by one. Note in the commit which became `is_outside()` and which stayed SUIT.
- [ ] **Step 4: Run** `-gselect=test_avatar_field`, `-gselect=test_avatar`, `-gselect=test_airlock`, plus the tests of every file changed in the `Mode.SUIT` sweep that has one — PASS.
- [ ] **Step 5: Commit** — `feat: step out onto a world and walk, with up away from its centre`

---

### Task 9: Loose things fall on a world

**Files:**
- Modify: `who-knows/src/world/stray_field.gd`
- Test: `who-knows/test/unit/test_stray_field.gd` (add to it)

**Interfaces:**
- Consumes: `WorldGravity.at`, `on_world_at` (Task 2).
- Produces: `StrayField.gravity: WorldGravity` (set by `flight_test.gd`). Each physics tick, every live stray that is not frozen, with `on_world_at(its position)` true, gets `apply_central_force(at(pos) × mass)`.

- [ ] **Step 1: Write the failing tests.** (a) A stray adopted at a point `on_world` gains downward velocity after 30 physics frames. (b) A stray adopted in a ring position (on_world false, vector non-zero) keeps its velocity (Review Focus 1).
- [ ] **Step 2: Run** `-gselect=test_stray_field` — FAIL.
- [ ] **Step 3: Implement** `_physics_process` in `StrayField`.
- [ ] **Step 4: Run** `-gselect=test_stray_field` — PASS.
- [ ] **Step 5: Commit** — `feat: what you drop on a world falls`

---

### Task 10: Hostiles stay above the air

**Files:**
- Modify: `who-knows/src/pilot/ship_pilot.gd`
- Test: `who-knows/test/unit/test_ship_pilot.gd` (add to it, or create `test_pilot_air_floor.gd`)

**Interfaces:**
- Consumes: `flight.gravity` (`WorldGravity`), `up_at`, `altitude_at`; `SystemBody.recipe.air_top()` via the well at the hull.
- Produces: `ShipPilot.AIR_FLOOR_MARGIN := 2000.0`; `static func above_air(target_v: Vector3, up: Vector3, altitude: float, floor_m: float) -> Vector3`. When `altitude < floor_m`, it replaces the downward part of `target_v` (along −`up`) with an upward one: `up × min(120, (floor_m − altitude) × 0.1)`. Otherwise it returns `target_v` unchanged. The pilot applies it to whatever velocity it hands `flight.hold_velocity` (find that call; hostile ships spec §5.1). `floor_m = air_top + AIR_FLOOR_MARGIN`.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_above_the_floor_nothing_changes():
	assert_eq(ShipPilot.above_air(Vector3(0, -50, 10), Vector3.UP, 9000.0, 6000.0), Vector3(0, -50, 10))

func test_under_the_floor_it_climbs():
	var v := ShipPilot.above_air(Vector3(0, -50, 10), Vector3.UP, 5000.0, 6000.0)
	assert_eq(v, Vector3(0, 100, 10))
```

- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** the file plus `-gselect=test_ship_pilot` — PASS.
- [ ] **Step 5: Commit** — `feat: hostiles keep above a world's air`

---

### Task 11: Ships spawned or woken in a well

**Files:**
- Modify: `who-knows/scenes/flight_test.gd` (any ship wiring path that skips the shared wiring), `who-knows/src/ship/fleet.gd` (`wake`)
- Test: `who-knows/test/unit/test_fleet_gravity.gd`

**Interfaces:**
- Consumes: everything above. Produces nothing new. This task proves no ship slips through without gravity.

- [ ] **Step 1: Write the failing test.** In the flight scene (as the fleet scene tests build it), spawn a second starter with `fleet.spawn` 300 m above the first planet's ground, assist on, stick centred. After 3 s of physics its altitude has changed by less than 2 m: it hovers. Then put it to sleep and wake it, and after 3 s more it still hovers.
- [ ] **Step 2: Run** — FAIL if any path misses `gravity` or `keel_depth`, or the landing monitor isn't wired. **Step 3: Fix** the paths that missed it. **Step 4: Run** `-gselect=test_fleet_gravity` and `-gselect=test_floating_origin_scene` — PASS.
- [ ] **Step 5: Commit** — `test: every ship in a well feels it, spawned or woken`

---

### Task 12: Skills and documents

**Files:**
- Modify: `.claude/skills/building-a-ship/SKILL.md` (checklist: "it lifts off a 7 m/s² world: `CANNOT_LIFT` clear"; *Mistakes already made*: the two-way vertical count means the starter's lift is 9.5, not 4.7, and that's what the hold spends), `.claude/skills/building-a-ship/reference.md` (gravity hold, `LIFT_MARGIN`, `LandingMonitor` constants, keel depth, `WorldGravity`, low power and the hold), `.claude/skills/building-a-ship/ship_probe.gd` (print a `lift` line: `vertical / mass` and its margin at 7 m/s²)
- Modify: `.claude/skills/designing-a-ship/SKILL.md` (a ship must lift off a 7 m/s² world with margin 1.3)
- Modify: `.claude/skills/building-an-npc/reference.md` (`WorldGravity` exists; anything outside on a world must ask it; nothing lives there yet)
- Modify: `docs/superpowers/specs/2026-09-23-planetfall-design.md` (a header note marks §7.1, §8, §9, §10's refusals and §11 built by the desert world's phase 0, with its changes; §7.3 replaced; §12–§13 open), `docs/superpowers/specs/2026-11-03-desert-world-design.md` (status: phase 0 built, with any differences as built)

- [ ] **Step 1: Make the edits.** Check every name the skills mention still exists (`grep`).
- [ ] **Step 2: Run** `-gselect=test_ship_catalog` and `ship_check.gd` on the starter (the skill says how) — the `lift` line prints and passes.
- [ ] **Step 3: Commit** — `docs: phase 0 as built; the ship skills learn gravity, lift and landing`

---

### Task 13: Play it in real time

**Files:**
- Create: `who-knows/test/probes/landing_play.gd` (modelled on `test/probes/fleet_play.gd`: saving off before the scene enters the tree; `_fails` counted; key moments rendered)

**Interfaces:**
- Consumes: the whole phase.

- [ ] **Step 1: Write the probe.** It uses the flight scene and the system's largest planet with air. It prints one line per step with what it measured and renders the moments marked ★:
  1. Put the starter 300 m over flat ground, assist on. Hover 5 s: altitude drift under 2 m. ★
  2. Tilt it 15° and hold the stick centred. Under 150 m it levels within 5 s.
  3. Descend at 2 m/s until it's LANDED within 10 s of touchdown. No hard landing. ★
  4. Try the airlock before landing (re-run from step 1 state): the panel reads NOT LANDED.
  5. Cycle out. The avatar is in FIELD. Walk 20 m away from the hull. Jump: peak height within 10% of `3.1² / (2g)`. ★
  6. Drop a carried item: it falls and rests within 3 s.
  7. Spawn a second starter landed 30 m away, walk into its airlock and cycle in: you're aboard it (Review Focus 5). ★
  8. From its helm, translate up: it leaves LANDED, climbs, and hovers at 300 m.
  9. Put it on low power (store under 10%) and repeat 8: it still climbs (Review Focus 4).
  10. Fly up through the air top into the planet's ring, if it has one, and spacewalk there: SUIT, no fall over 10 s (Review Focus 1). ★
- [ ] **Step 2: Run it** without `--headless`:
  `godot --path who-knows --resolution 1280x720 --script res://test/probes/landing_play.gd -- <abs out dir>`
  Expected: every line passes, `_fails = 0`, renders written.
- [ ] **Step 3: Run** `test/probes/fleet_play.gd` (CLAUDE.md, after any airlock or suit change) — Expected: passes as before.
- [ ] **Step 4: Measure** seated on the ground and standing beside the landed ship (the spec's §10): at least 120 fps at 1280 × 720. Record the numbers in the design's status note.
- [ ] **Step 5: Commit** — `test: landing_play, a world played through in real time`
- [ ] **Step 6: Show the owner** the renders and the probe's lines. Ask whether to run the full suite before the branch is finished.
