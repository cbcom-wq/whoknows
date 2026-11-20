# WADIS's Land Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every desert world a seeded world plan (a region map with seas, ranges, plateaus, canyons, sites and kept discs), reshape WADIS with it, stream the ground smoother and cheaper on every world under a stricter speed limit near the ground, then add the sea and wild oases.

**Architecture:** A new `WorldPlan`, built once per desert recipe (lazily, under a lock, before any worker asks) and read-only after, gives `WorldTerrain.height_at` the big shape; `WorldTerrain` adds each landform's detail with its own per-thread noise, and keeps today's desert to the bit inside kept discs. Streaming gains detail by level, a ground shader that only eases detail in, plan bounds and asking ahead; `FlightComputer.speed_limit` falls near the surface and thick air holds you there with the assist off. The sea is a sheet the chunks draw and hulls collide with on their own layer; wild oases are generated places on the plan's sites.

**Tech Stack:** Godot 4.5.1 mono, GDScript, GUT tests, headless and render probes.

**Spec:** `docs/superpowers/specs/2026-11-19-wadis-land-design.md` (approved by the owner 2026-11-20). Read it first; this plan argues from it and cites its sections as §n.

## Global Constraints

- Work in `D:/git/whoknows-world-plan` on branch `world-plan`; never in `D:/git/whoknows` (it stays on `main`). Merge to `main` or push only on the owner's word.
- Run tests from `D:/git/whoknows-world-plan/who-knows` with `.\run_tests.ps1 -gselect=<file>`, one file per call, only the files a task names. Never the full suite unless the owner asks.
- Godot: `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe`. Render probes run without `--headless`, at `--resolution 1280x720`.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Desert worlds only change** (§3). Every other world keeps `height_at` and `colour_at` at full detail to the bit (Task 1's golden test).
- **Wadoo stays:** inside its kept disc (2,000 m, blend 1,500 m) the base ground is today's `_desert_height` to the bit (§5.6).
- **Frame floor:** at least 80 fps at 1280 × 720 on the GTX 960 in every view (§3, §11).
- **Style** (`docs/design/visual-style.md`, binding): faceted, flat colour per triangle, colours only from `SpacePalette` (terrain, sea) and `OasisPalette` (oasis pieces). The ground's easing shader (Task 15) is the only exterior shader; it draws exactly what `BodyLook.material(false)` draws once eased. Guide, code and `test_visual_style_rules.gd` change together.
- **Water and green together stay well under a quarter of WADIS** (§3).
- **Floating origin:** every chunk, solid body and place node outside is a member of `Universe.EXTERIOR_SPACE`; positions that outlive a shift are `UniversePoint`s or directions.
- **Threads:** the plan's arrays are never written after it is built; `FastNoiseLite` is never shared across threads (the plan uses noise only while building; `WorldTerrain` keeps its own per thread).
- **No `#` comments inside `[node]`, `[sub_resource]` or `[resource]` blocks** of a `.tscn`/`.tres`.
- New terms the spec fixes: `WorldPlan`, `WorldTerrain.surface_at`, the design file's `plan` key, `test/probes/stream_probe.gd`.
- Checkpoints 1–4 end Parts 1–4: stop, show the owner the renders and numbers, and wait. Part 5 follows Checkpoint 4.

## Review Focus

1. **A ship put down over what is now sea** (a v3 save restored landed there, a woken ship, an F6 spawn): it ends on or over the water, never under the sheet. Tests in Task 22.
2. **A hull with its feet on the beach and its stern over the water** lands, and the airlock opens onto water you can wade. Test in Task 22.
3. **Assist off, diving fast into the low band:** the air hold never takes more than the excess in a tick, never reverses you. Test in Task 18.
4. **Someone restored on foot where v4 put rock or deep water:** lifted out of the rock, treading in the water. Tests in Task 23.
5. **An item dropped in the shallows** lies on the seabed under the water, not on the surface, now that `altitude_at` measures to the sea. Test in Task 23.

---

## File map

| File | Responsibility |
|---|---|
| `src/world/plan/world_plan.gd` (new) | `WorldPlan`: builds the plan from a recipe, holds it, answers `sample`, `bounds_of`, `land_at` |
| `src/world/plan/plan_dials.gd` (new) | `PlanDials`: rolls, pins and normalises the dials |
| `src/world/plan/plan_map.gd` (new) | `PlanMap`: per-face corner grids at `PLAN_DEPTH`, bilinear sampling continuous across faces, per-depth bounds |
| `src/world/plan/plan_shapes.gd` (new) | `PlanShapes`: seas, range spines, canyon paths and plateau regions as data, with a per-cell index and distance queries |
| `src/world/plan/plan_site.gd` (new) | `PlanSite`: one site (kind, direction, radius, heading, level) |
| `src/world/plan/wild_oasis.gd` (new) | `WildOasis`: one site's stamps, layout and place |
| `src/world/world_recipe.gd` | plan fields, lazy `plan()`, `GENERATOR_VERSION` 4 |
| `src/world/world_terrain.gd` | planned heights and colours, kept discs, landform detail, `surface_at`, detail by level |
| `src/world/system_design.gd` | the `plan` key: parse, validate, write into the recipe |
| `src/world/system_recipe.gd` | wild oases among `places()` |
| `src/world/terrain_chunk_data.gd` | detail by level, coarse positions for easing, the water sheet and its faces |
| `src/world/world_surface.gd` | plan bounds, easing, ask ahead, water solids, the sea floor for hulls |
| `src/world/body_look.gd` | the far mesh to the surface, the sea's colour |
| `src/world/world_gravity.gd`, `whereabouts.gd`, `terrain_collider.gd`, `stray_field.gd`, `src/ship/spawn_spot.gd` | altitude to the surface where flying, to the ground where standing |
| `src/flight/flight_computer.gd` | the stricter limit |
| `src/flight/landing_monitor.gd`, `src/ship/ship.gd` | no landing on water, crash on water |
| `src/world/sea_water.gd` (new) | wading and treading in the sea |
| `src/avatar/avatar.gd`, `src/avatar/grasp.gd` | treading; no drop while treading |
| `src/world/place_design.gd`, `place_field.gd` | generated layouts, wild oases loaded |
| `data/materials/exterior/ground_ease.gdshader` (new) | the ground's easing shader |
| `data/systems/kesdra.json` | WADIS's `plan` |
| `src/world/space_palette.gd` | `sea_shallow`, `sea_deep` (and `salt` if renders want it) in the desert palette |
| `test/probes/stream_probe.gd`, `test/probes/plan_map.gd` (new) | streaming numbers; the plan as a map |

---

# Part 1: The land

## Task 1: Golden samples of today's ground

Pins what must never change before anything changes (§10).

**Files:**
- Create: `who-knows/test/unit/golden/make_terrain_golden.gd` (a `SceneTree` script that writes the golden file)
- Create: `who-knows/test/unit/golden/terrain_golden.json`
- Test: `who-knows/test/unit/test_terrain_golden.gd`

**Interfaces:**
- Produces: `terrain_golden.json` with `{"worlds": [{"seed": int, "archetype": String, "samples": [[x, y, z, height, r, g, b]]}], "wadoo": [[x, y, z, height]]}`. Later tasks run `test_terrain_golden.gd` after every change to `WorldTerrain`.

- [ ] **Step 1: Write the generator.** For 3 seeds of each drawn archetype (CRATERED, ROLLING, RIDGED, MESA) found by scanning `WorldRecipe.from_seed(s)` for `s` from 1 upward, 200 seeded directions each: `height_at(d)` and `colour_at(d, 0.2, 8.0)` (floats written with `"%.17g"`). For Wadoo: the WADIS recipe from `SystemRecipe.from_seed(1337).body(&"p3").recipe`, 400 directions within 2,000 m of the oasis place (`SystemDesign.dir_of(-2.16, -171.97)`), `height_at(d)` with its stamps. Run it on today's code:

Run: `& $godot --headless --path . -s res://test/unit/golden/make_terrain_golden.gd`
Expected: `terrain_golden.json` written, 12 worlds and 400 Wadoo samples.

- [ ] **Step 2: Write the test.**

```gdscript
func test_every_other_world_keeps_its_ground_to_the_bit():
	for w: Dictionary in _golden().worlds:
		var t := WorldTerrain.new(WorldRecipe.from_seed(int(w.seed)))
		for s: Array in w.samples:
			var d := Vector3(s[0], s[1], s[2])
			assert_eq(t.height_at(d), float(s[3]))
			assert_eq(t.colour_at(d, 0.2, 8.0), Color(s[4], s[5], s[6]))

func test_wadoo_keeps_its_ground_to_the_bit():
	var t := WorldTerrain.new(SystemRecipe.from_seed(1337).body(&"p3").recipe)
	for s: Array in _golden().wadoo:
		assert_eq(t.height_at(Vector3(s[0], s[1], s[2])), float(s[3]))
```

- [ ] **Step 3: Run it.** `.\run_tests.ps1 -gselect=test_terrain_golden.gd` → PASS on today's code.
- [ ] **Step 4: Commit.** `test(world): golden samples of every other world and of Wadoo's ground`

## Task 2: The dials and the design file's `plan` key

**Files:**
- Create: `who-knows/src/world/plan/plan_dials.gd`, `who-knows/src/world/plan/world_plan.gd` (skeleton)
- Modify: `who-knows/src/world/world_recipe.gd`, `who-knows/src/world/system_design.gd`, `who-knows/data/systems/kesdra.json`, `who-knows/src/save/save_game.gd`
- Test: `who-knows/test/unit/test_plan_dials.gd`, `who-knows/test/unit/test_system_design.gd`, `who-knows/test/unit/test_world_recipe.gd`

**Interfaces:**
- Produces:
  - `class_name PlanDials extends RefCounted` with `var sea: float, seas: int, mountains: float, ranges: int, plateaus: float, canyons: int, peak: float, oases: int`; `const NAMES: Array[String] = ["sea", "seas", "mountains", "ranges", "plateaus", "canyons", "peak", "oases"]`; `const OPEN_LEAST := 0.5`; `static func roll(world_seed: int, radius_m: float) -> PlanDials` (each dial is drawn from its own `WorldSeed.rng(WorldSeed.sub(world_seed, &"plan"), &"<dial name>")`, so a dial added later never reshuffles the rest; `sea`'s rng draws `randf() < 1.0 / 3.0` for "no sea" first, then its share); `func pin(values: Dictionary) -> void`; `func open_share() -> float` (1 − sea − mountains − plateaus).
  - `SaveGame.generators()` gains `"world": WorldRecipe.GENERATOR_VERSION`: the save note (§10), so a save says which ground it was made on.
  - `WorldRecipe`: `const GENERATOR_VERSION := 4`; `var plan_pins: Dictionary = {}` (the design's `plan` section, raw); `var keeps: Array[Dictionary] = []` (each `{"place": StringName, "dir": Vector3, "radius": float, "blend": float}`); `var pin_places: Dictionary = {}` (place id → unit `Vector3`); `var planned := true` (false: a desert draws today's ground everywhere, as kept discs do inside); `func plan() -> WorldPlan` (null unless `is_desert()` and `planned`; built on first call under a `Mutex`, every later call returns the same object).
  - `WorldPlan`: `var dials: PlanDials`; `static func build(recipe: WorldRecipe) -> WorldPlan` (this task: dials only).
  - `SystemDesign`: `BODY_KEYS` gains `"plan"`; `const PLAN_KEYS: Array[String] = PlanDials.NAMES + ["keep", "pins"]`.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_plan_dials.gd
func test_the_same_seed_rolls_the_same_dials():
	var a := PlanDials.roll(42, 50000.0)
	var b := PlanDials.roll(42, 50000.0)
	for n in PlanDials.NAMES:
		assert_eq(a.get(n), b.get(n))

func test_rolls_stay_in_their_ranges():
	var no_sea := 0
	for s in 300:
		var d := PlanDials.roll(s, 50000.0)
		if d.sea == 0.0:
			no_sea += 1
		else:
			assert_between(d.sea, 0.0, 0.25)   # under 0.05 only when scaled to keep half open
		assert_between(d.seas, 1, 2)
		assert_between(d.ranges, 1, 5)
		assert_between(d.canyons, 0, 6)
		assert_between(d.oases, 2, 8)
		assert_between(d.peak, 600.0, 2000.0)   # 4% of a 50 km radius caps 2,500
		assert_true(d.open_share() >= PlanDials.OPEN_LEAST - 1e-9)
	assert_between(no_sea, 70, 130)   # about a third of 300

func test_a_pinned_dial_replaces_its_roll_and_no_other():
	var rolled := PlanDials.roll(7, 50000.0)
	var d := PlanDials.roll(7, 50000.0)
	d.pin({"sea": 0.15, "ranges": 3})
	assert_eq(d.sea, 0.15)
	assert_eq(d.ranges, 3)
	assert_eq(d.canyons, rolled.canyons)

func test_each_dial_draws_from_its_own_sub_seed():
	for s in 50:
		var d := PlanDials.roll(s, 50000.0)
		var plan_seed := WorldSeed.sub(s, &"plan")
		assert_eq(d.canyons, WorldSeed.rng(plan_seed, &"canyons").randi_range(0, 6))
		assert_eq(d.oases, WorldSeed.rng(plan_seed, &"oases").randi_range(2, 8))

func test_saves_note_the_world_generator():
	assert_eq(SaveGame.generators().get("world"), 4)
```

```gdscript
# test_system_design.gd (add)
func test_wadis_pins_its_plan():
	var r := SystemRecipe.from_seed(1337).body(&"p3").recipe
	var d := r.plan().dials
	assert_eq([d.sea, d.seas, d.mountains, d.ranges, d.peak, d.plateaus, d.canyons, d.oases],
		[0.15, 1, 0.10, 3, 2000.0, 0.20, 4, 6])
	assert_eq(r.keeps.size(), 1)
	assert_eq(r.keeps[0].radius, 2000.0)
	assert_eq(r.keeps[0].blend, 1500.0)

func test_the_validator_knows_the_plan_key():
	var bad := SystemDesign.from_data({"seed": 1337, "bodies": {"p3": {"plan": {"sea": 0.6, "lakes": 2,
		"keep": [{"place": "nowhere", "radius": 2000, "blend": 1500}]}}}})
	var problems := bad.problems(SystemRecipe.from_seed(1337))
	assert_true(Array(problems).any(func(p): return "sea" in p))
	assert_true(Array(problems).any(func(p): return "lakes" in p))
	assert_true(Array(problems).any(func(p): return "nowhere" in p))
	assert_eq(SystemDesign.for_seed(1337).problems(SystemRecipe.from_seed(1337)).size(), 0)

# test_world_recipe.gd (change line 55's 3 to 4, and add)
func test_only_planned_deserts_have_a_plan():
	var r := SystemRecipe.from_seed(1337).body(&"p3").recipe
	assert_not_null(r.plan())
	assert_same(r.plan(), r.plan())
	r.planned = false
	assert_null(r.plan())
```

- [ ] **Step 2: Run them.** `test_plan_dials.gd`, `test_system_design.gd`, `test_world_recipe.gd` → FAIL (no `PlanDials`, no `plan` key).
- [ ] **Step 3: Implement.**
  - `PlanDials.roll`: sea is 0 with chance 1/3, else 0.05–0.25; seas 1–2; mountains 0.03–0.15; ranges 1–5; plateaus 0.10–0.30; canyons 0–6; peak 600–2,500 capped at 0.04 × radius; oases 2–8 (§5.2). If `open_share() < OPEN_LEAST`, scale sea, mountains and plateaus by one factor so it is exactly `OPEN_LEAST`. `pin` sets only the keys present, then normalises the same way.
  - `SystemDesign.apply_to`: copies the body's `plan` section into `recipe.plan_pins`, resolves each `keep` entry's place to a direction into `recipe.keeps`, and every place's direction into `recipe.pin_places`. `problems()`: unknown plan keys; dials outside their rolled range (0 allowed for shares and counts); a `keep` whose place does not exist; a `plan` on a body that is not a desert.
  - `kesdra.json`, body `p3`: `"plan": {"sea": 0.15, "seas": 1, "mountains": 0.10, "ranges": 3, "peak": 2000, "plateaus": 0.20, "canyons": 4, "oases": 6, "keep": [{"place": "oasis", "radius": 2000, "blend": 1500}], "pins": {"sea_shore": {"place": "oasis", "within": [20000, 40000]}, "range": {"place": "oasis", "within": 15000}}}`.
  - `WorldRecipe.plan()` builds through `WorldPlan.build(self)` under `_plan_lock`.
- [ ] **Step 4: Run the three files** → PASS. Also `test_terrain_golden.gd` → PASS.
- [ ] **Step 5: Commit.** `feat(world): a desert's plan dials, rolled or pinned in its design file`

## Task 3: The plan map

**Files:**
- Create: `who-knows/src/world/plan/plan_map.gd`
- Modify: `who-knows/src/world/plan/world_plan.gd`
- Test: `who-knows/test/unit/test_world_plan.gd`

**Interfaces:**
- Consumes: `WorldRecipe.plan()`, `PlanDials` (Task 2).
- Produces:
  - `PlanMap`: `const PLAN_DEPTH := 6` (cells are the quadtree's nodes at depth 6: 64 per face edge, 1.34 km on WADIS); `func _init(fields: int)`; `func set_corner(field: int, face: int, i: int, j: int, value: float)`; `func corner(field, face, i, j) -> float`; `func at(field: int, d: Vector3) -> float` (bilinear in the cell `d` falls in); `func cell_of(d: Vector3) -> Vector4i`; `func neighbours(cell: Vector4i) -> Array[Vector4i]` (across face edges too); `func set_bounds(low: PackedFloat32Array, high: PackedFloat32Array) -> void` (one value per cell at `PLAN_DEPTH`, face by face, row by row; the coarser depths' min and max worked out inside) and `func bounds_of(key: Vector4i) -> Vector2` (least and most height under a quadtree node: from its cell at depth ≥ 6, the min/max over its cells above).
  - **The corner rule:** every field is stored at cell corners and computed from the corner's direction alone, so a corner shared by two or three faces holds one value and `at` is continuous across face edges.
  - `WorldPlan`: `enum Land { SEA, DUNES, PLAINS, PLATEAU, MOUNTAINS }`; `const SEA_LEVEL := -40.0` (m above radius; under Wadoo's lowest ground, −31 m); `var sea_level: float` (`SEA_LEVEL`, or `-INF` with no sea); `var map: PlanMap`; `func sample(d: Vector3, out: PackedFloat64Array) -> void`; `func land_at(d: Vector3) -> Land`; `func bounds_of(key: Vector4i) -> Vector2`.
  - **The sample layout** (`WorldPlan.S_*`; add indices at the end, never reorder): `S_BASE` 0 base height m; `S_SHORE` 1 signed m to the coast (negative at sea, `INF` with none); `S_DUNES` 2 share of open ground that is dune sea, 0–1; `S_PLATEAU` 3 weight 0–1; `S_PLATEAU_TOP` 4 that region's top m; `S_MOUNTAIN` 5 weight 0–1; `S_RIDGE` 6 m from the nearest spine; `S_CANYON` 7 m from the nearest canyon centreline over its floor's half-width (≤ 1 on the floor, `INF` with none); `S_CANYON_FLOOR` 8 floor height m; `S_CANYON_RIM` 9 wall top over the floor m; `S_KEEP` 10 kept-disc weight 0–1; `S_SIZE` 11. The caller owns `out` (one per `WorldTerrain`), so a sample allocates nothing.

This task fills the grid with the open ground alone (dunes and plains by a noise field, base a gentle roll); Tasks 4–8 add the rest.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func _wadis() -> WorldRecipe:
	return SystemRecipe.from_seed(1337).body(&"p3").recipe

func test_the_same_seed_builds_the_same_plan_on_any_thread():
	var a := WorldPlan.build(_wadis())
	var b: WorldPlan
	var id := WorkerThreadPool.add_task(func(): b = WorldPlan.build(_wadis()))
	WorkerThreadPool.wait_for_task_completion(id)
	var oa := PackedFloat64Array(); oa.resize(WorldPlan.S_SIZE)
	var ob := oa.duplicate()
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for k in 2000:
		var d := _dir(rng)
		a.sample(d, oa); b.sample(d, ob)
		assert_eq(oa, ob)

func test_samples_are_continuous_across_every_face_edge():
	var p := _wadis().plan()
	var out := PackedFloat64Array(); out.resize(WorldPlan.S_SIZE)
	var across := PackedFloat64Array(); across.resize(WorldPlan.S_SIZE)
	for edge_dir in _face_edge_points(400):   # points on edges and the 8 corners
		var e: Vector3 = edge_dir[0]; var step: Vector3 = edge_dir[1]   # tangent across the edge
		p.sample((e + step * 1e-6).normalized(), out)
		p.sample((e - step * 1e-6).normalized(), across)
		assert_almost_eq(out[WorldPlan.S_BASE], across[WorldPlan.S_BASE], 0.1)

func test_building_wadis_takes_under_half_a_second():
	var t := Time.get_ticks_usec()
	WorldPlan.build(_wadis())
	assert_lt(Time.get_ticks_usec() - t, 500000)
```

- [ ] **Step 2: Run** `test_world_plan.gd` → FAIL.
- [ ] **Step 3: Implement** `PlanMap` and the open-ground fill. `WorldPlan.build` uses its own `FastNoiseLite`s seeded from `WorldSeed.sub(recipe.seed, &"plan_<concern>")`, only while building. If WADIS takes over 0.5 s, cache the built arrays under `user://plans/<seed>_<GENERATOR_VERSION>_<hash of plan_pins>.res` rather than lowering the grid.
- [ ] **Step 4: Run** `test_world_plan.gd` → PASS.
- [ ] **Step 5: Commit.** `feat(world): the world plan's map, continuous across cube faces`

## Task 4: Seas

**Files:**
- Create: `who-knows/src/world/plan/plan_shapes.gd`
- Modify: `who-knows/src/world/plan/world_plan.gd`
- Test: `who-knows/test/unit/test_world_plan.gd`

**Interfaces:**
- Produces: `WorldPlan.shapes: PlanShapes`, holding `seas: Array[Dictionary]` (`{"cells": PackedInt32Array, "centre": Vector3}`) plus the index added by Tasks 5–7; `WorldPlan` constants `LAND_ABOVE := 6.0` (open ground's base is never under `sea_level + LAND_ABOVE` outside a basin), `SHELF_DEPTH := 20.0`, `SHELF_WIDTH := 1500.0`, `SEA_DEEP := 300.0` (deep floor under sea level), `const PUDDLE_FROM := 2000.0`; `func nearest_shore_m(d: Vector3) -> float`.

Method (§5.4 step 2): grow each sea over the cells from a seeded centre, by a priority that is distance plus noise, to its share of the surface (the `sea` dial split between `seas` seas): one connected body by construction. `S_SHORE` is the signed great-circle distance from each corner to the grown cells' outline (negative inside), so shores are smooth; the base inside falls from `sea_level` through the shelf to the deep floor by `S_SHORE`. **The shore pin** (`plan_pins.pins.sea_shore`): pick the centre from a seeded sequence of candidates until the nearest shore to the pinned place lies within `within` (20–40 km on WADIS), outside every keep's radius + blend; a world whose candidates all fail is an error the test catches.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_wadis_has_one_sea_of_its_share():
	var p := _wadis().plan()
	assert_eq(p.shapes.seas.size(), 1)
	assert_eq(_components(p, WorldPlan.Land.SEA), 1)
	var under := _share(func(d): return _ground(d) < p.sea_level, 20000)
	assert_between(under, 0.12, 0.18)

func test_the_sea_is_in_view_from_wadoo():
	var p := _wadis().plan()
	var shore := p.nearest_shore_m(SystemDesign.dir_of(-2.16, -171.97))
	assert_between(shore, 20000.0, 40000.0)

func test_a_desert_with_no_sea_has_no_sea_level():
	var r := _desert_with(func(d: PlanDials): return d.sea == 0.0)
	assert_eq(r.plan().sea_level, -INF)
```

(`_ground(d)` is the plan's base until Task 9, then `WorldTerrain.height_at`; `_share` samples seeded directions; `_components` floods `land_at` over cell centres through `map.neighbours`; `_desert_with` scans seeds for a desert recipe meeting the condition.)

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit.** `feat(world): the plan's seas, grown to their share, in view from Wadoo`

## Task 5: Mountain ranges

**Files:** Modify `plan_shapes.gd`, `world_plan.gd`; Test `test_world_plan.gd`.

**Interfaces:**
- Produces: `PlanShapes.ranges: Array[Dictionary]` (`{"spine": PackedVector3Array, "height": PackedFloat32Array, "half_width": float}`); `PlanShapes.near(cell: Vector4i) -> PackedInt32Array` (the shapes whose reach touches the cell: one index for ranges, canyons and plateaus, encoded `kind * 4096 + i`); `PlanShapes.ridge_m(d: Vector3, cell: Vector4i) -> Vector2` (metres to the nearest spine, and the spine's height there). `WorldPlan`: `RANGE_LENGTH := Vector2(20000, 60000)`, `RANGE_HALF_WIDTH := Vector2(4000, 8000)`.

Method (§5.4 step 3): each spine a smooth curve bent by noise, its height rising to the `peak` dial at its highest point and lower along it; kept off the sea and off every keep's radius + blend. On a world with a sea, one range runs to the coast (its end within a cell of the shore), so some shore is cliff. **The range pin** (`pins.range`): one spine passes within `within` (15 km) of the pinned place and outside its radius + blend. `S_MOUNTAIN` and `S_RIDGE` filled; the base rises over the range's half-width.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_wadis_has_three_ranges_to_two_km():
	var p := _wadis().plan()
	assert_eq(p.shapes.ranges.size(), 3)
	var top := 0.0
	for r in p.shapes.ranges:
		top = maxf(top, Array(r.height).max())
	assert_between(top, 1800.0, 2000.0)

func test_a_range_stands_on_wadoos_skyline_but_not_in_its_disc():
	var p := _wadis().plan()
	var wadoo := SystemDesign.dir_of(-2.16, -171.97)
	var nearest := INF
	for r in p.shapes.ranges:
		var spine_m := INF
		for d: Vector3 in r.spine:
			spine_m = minf(spine_m, d.angle_to(wadoo) * _wadis().radius_m)
		assert_gte(spine_m, 3500.0 + r.half_width)   # its flanks stay out of keep + blend
		nearest = minf(nearest, spine_m)
	assert_lte(nearest, 15000.0)

func test_some_range_reaches_the_coast():
	var p := _wadis().plan()
	assert_true(p.shapes.ranges.any(func(r):
		return absf(p.nearest_shore_m(r.spine[0])) < 2000.0 or absf(p.nearest_shore_m(r.spine[-1])) < 2000.0))
```

- [ ] **Steps 2–4:** run → FAIL, implement, run → PASS (also the earlier tests in the file).
- [ ] **Step 5: Commit.** `feat(world): the plan's mountain ranges, one on Wadoo's skyline`

## Task 6: Plateau country, dunes and plains

**Files:** Modify `plan_shapes.gd`, `world_plan.gd`; Test `test_world_plan.gd`.

**Interfaces:**
- Produces: `PlanShapes.plateaus: Array[Dictionary]` (`{"cells": PackedInt32Array, "top": float}`); `WorldPlan.PLATEAU_TOP := Vector2(100.0, 400.0)`; `S_PLATEAU`, `S_PLATEAU_TOP`, `S_DUNES` filled.

Method (§5.4 steps 4–5): regions grown from seeded centres away from the sea and the keeps, to the `plateaus` share, each with its own top drawn from `PLATEAU_TOP`; `S_PLATEAU` rises from 0 to 1 across the region's edge band (where Task 10 lays terraces and towers). The rest is open ground: dune seas where the base is lower, gravel plains between (`S_DUNES`).

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_plateaus_no_longer_all_stand_at_one_height():
	var tops := {}
	for r in _wadis().plan().shapes.plateaus:
		assert_between(r.top, 100.0, 400.0)
		tops[snappedf(r.top, 10.0)] = true
	assert_gt(tops.size(), 1)

func test_dunes_and_plains_keep_at_least_half_the_world():
	var p := _wadis().plan()
	var open := _share(func(d): var l := p.land_at(d); return l == WorldPlan.Land.DUNES or l == WorldPlan.Land.PLAINS, 20000)
	assert_gt(open, 0.5)
	assert_between(_share(func(d): return p.land_at(d) == WorldPlan.Land.PLATEAU, 20000), 0.15, 0.25)
```

- [ ] **Steps 2–4:** FAIL, implement, PASS.
- [ ] **Step 5: Commit.** `feat(world): the plan's plateau country, each region its own height`

## Task 7: Canyons

**Files:** Modify `plan_shapes.gd`, `world_plan.gd`; Test `test_world_plan.gd`.

**Interfaces:**
- Produces: `PlanShapes.canyons: Array[Dictionary]` (`{"path": PackedVector3Array, "floor": PackedFloat32Array, "half_floor": PackedFloat32Array, "rim": PackedFloat32Array, "mouth": StringName}`, `mouth` &"beach" or &"basin"; a branch is its own entry with `"joins": <its parent's index>` and no mouth); `WorldPlan.CANYON_FLOOR_WIDTH := Vector2(150.0, 600.0)`, `CANYON_DEPTH := Vector2(100.0, 400.0)`, `const CANYON_LAND_FLOOR := 1.0` (a floor stays this far over sea level until its mouth). `S_CANYON`, `S_CANYON_FLOOR`, `S_CANYON_RIM` filled.

Method (§5.4 step 6): each canyon starts in plateau country or on a range's flank and steps downhill over the cells (steepest descent on the base, with a seeded wander) to the sea or, with none, to a dry basin it digs. The floor along the path is the running minimum of the base less the canyon's depth, so it never climbs toward the mouth; its width wanders within `CANYON_FLOOR_WIDTH`. On a world with a sea, at least one mouth opens on a beach (a shore not under a range or plateau); if the first draw has none, reroute the canyon nearest a beach to it. One or two branches per world, joining a canyon's path.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_every_canyon_reaches_the_sea_or_a_basin_and_never_climbs():
	var p := _wadis().plan()
	assert_eq(p.shapes.canyons.filter(func(c): return not c.has("joins")).size(), 4)
	for c in p.shapes.canyons:
		var f: PackedFloat32Array = c.floor
		for i in range(1, f.size()):
			assert_true(f[i] <= f[i - 1] + 1e-3, "a canyon's floor climbs toward its mouth")
		assert_true(c.mouth == &"beach" or c.mouth == &"basin" or c.has("joins"))

func test_a_canyon_ends_on_a_beach():
	assert_true(_wadis().plan().shapes.canyons.any(func(c): return c.mouth == &"beach"))

func test_every_canyon_floor_takes_the_starter():
	for c in _wadis().plan().shapes.canyons:
		assert_gte(Array(c.half_floor).min() * 2.0, 150.0)
```

- [ ] **Steps 2–4:** FAIL, implement, PASS.
- [ ] **Step 5: Commit.** `feat(world): the plan's canyons, downhill to the sea, one onto a beach`

## Task 8: Sites, kept discs and bounds

**Files:**
- Create: `who-knows/src/world/plan/plan_site.gd`
- Modify: `world_plan.gd`, `plan_map.gd`
- Test: `test_world_plan.gd`

**Interfaces:**
- Produces:
  - `class_name PlanSite extends RefCounted`: `enum Kind { OASIS, SHORE, KEPT }`; `var kind: Kind`, `dir: Vector3`, `radius: float`, `heading: float` (degrees, as `PlaceDesign.heading`), `level: float` (0 level … 1 rough), `rank: float` (lower is better).
  - `WorldPlan.sites: Array[PlanSite]` (best first within each kind); `WorldPlan.OASIS_SPACING := 4000.0`; `S_KEEP` filled: 1 within a keep's radius, easing (smoothstep) to 0 over its blend; `WorldPlan.keep_weight(d: Vector3) -> float`.
  - Bounds: `WorldPlan.bounds_of(key)` returns each node's least and most height including the detail Task 10 adds, by Land: `const DETAIL_REACH := {Land.DUNES: 45.0, Land.PLAINS: 12.0, Land.PLATEAU: 60.0, Land.MOUNTAINS: 300.0, Land.SEA: 10.0}` (starting values: Task 10 sets the real ones and its test proves them), plus canyons cut to their floor, and the kept disc's today's range (−60 to +300 m).

Method (§5.4 steps 7–8, §5.5): `OASIS` sites on low, fairly level, dry open ground where a canyon widens, at a range's foot, just inland of the sea, or in a dune hollow, at least `OASIS_SPACING` apart and outside every keep's radius + blend; `SHORE` sites on flat ledges by the sea, a few hundred metres along it; one `KEPT` site per keep. Nothing the plan places (sea, range, plateau, canyon, site) comes within a keep's radius + blend.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_oasis_sites_are_low_level_dry_and_spaced():
	var p := _wadis().plan()
	var oases := p.sites.filter(func(s): return s.kind == PlanSite.Kind.OASIS)
	assert_gte(oases.size(), 6)
	for s in oases:
		assert_gt(p.nearest_shore_m(s.dir), 0.0)
		assert_eq(p.keep_weight(s.dir), 0.0)
		assert_lt(s.level, 0.3)
		for o in oases:
			if o != s:
				assert_gte(s.dir.angle_to(o.dir) * _wadis().radius_m, WorldPlan.OASIS_SPACING)

func test_shore_sites_lie_by_the_water():
	var p := _wadis().plan()
	for s in p.sites.filter(func(s): return s.kind == PlanSite.Kind.SHORE):
		assert_between(p.nearest_shore_m(s.dir), 0.0, 400.0)

func test_nothing_planned_comes_near_wadoo():
	var p := _wadis().plan()
	var wadoo := SystemDesign.dir_of(-2.16, -171.97)
	var out := PackedFloat64Array(); out.resize(WorldPlan.S_SIZE)
	for d in _disc_points(wadoo, 3500.0, 1000):
		p.sample(d, out)
		assert_eq(out[WorldPlan.S_MOUNTAIN], 0.0)
		assert_eq(out[WorldPlan.S_PLATEAU], 0.0)
		assert_true(is_inf(out[WorldPlan.S_CANYON]))   # no canyon reaches it, walls and all
		assert_gt(out[WorldPlan.S_SHORE], 0.0)
```

The bounds test comes in Task 10, once the detail exists.

- [ ] **Steps 2–4:** FAIL, implement, PASS.
- [ ] **Step 5: Commit.** `feat(world): the plan's sites and kept discs`

## Task 9: The terrain on the plan

**Files:**
- Modify: `who-knows/src/world/world_terrain.gd`
- Test: `test_world_terrain.gd`, `test_desert_world.gd`, `test_terrain_stamps.gd`, `test_terrain_chunks.gd`, `test_terrain_golden.gd`, `test_world_plan.gd`

**Interfaces:**
- Consumes: `WorldRecipe.plan()`, `WorldPlan.sample`, `S_*`, `keep_weight` (Tasks 2–8).
- Produces: `WorldTerrain.plan: WorldPlan` (null unless planned desert); `relief` on a planned desert is `2 × max(|lowest|, |highest|)` of the plan's bounds (so today's relief pad still covers everything until Task 11); today's `_desert_height` reads `_legacy_half := recipe.relief_m * 0.5`, never `relief`; `func _planned_height(d: Vector3) -> float` (this task: the plan's `S_BASE` plus today's dunes on dune ground; Task 10 adds the rest).

`base_height_at` on a planned desert: `w := plan.keep_weight(d)`; `w == 1` → today's `_desert_height(d, continent)` to the bit; `w == 0` → `_planned_height(d)`; between → `lerpf(_planned, _desert, w)`. `ground_at` likewise picks today's `_desert_ground` where `w > 0.5`. `in_talus` keeps today's answer inside kept discs.

- [ ] **Step 1: Write the failing tests** (in `test_world_plan.gd`).

```gdscript
func test_wadoos_disc_is_todays_ground_to_the_bit():
	var planned := WorldTerrain.new(_wadis())
	var r := _wadis(); r.planned = false
	var today := WorldTerrain.new(r)
	for d in _disc_points(SystemDesign.dir_of(-2.16, -171.97), 2000.0, 2000):
		assert_eq(planned.height_at(d), today.height_at(d))
		assert_eq(planned.colour_at(d, 0.2, 8.0), today.colour_at(d, 0.2, 8.0))

func test_the_kept_disc_eases_out_without_a_step():
	# today's ground has its own cliffs (towers), so the weight is what is checked
	var p := _wadis().plan()
	var wadoo := SystemDesign.dir_of(-2.16, -171.97)
	for bearing in 36:
		var last := NAN
		for m in range(1900, 3700):
			var w := p.keep_weight(_at(wadoo, float(m), deg_to_rad(bearing * 10.0), _wadis().radius_m))
			if m <= 2000: assert_eq(w, 1.0)
			if m >= 3500: assert_eq(w, 0.0)
			if not is_nan(last):
				assert_lte(absf(w - last), 1.5 / 1500.0 + 1e-6)   # smoothstep's steepest, a metre
			last = w

func test_a_planned_desert_reaches_its_peaks_and_its_seabed():
	var t := WorldTerrain.new(_wadis())
	var hs := _heights(t, 20000)
	assert_lt(hs.min(), t.plan.sea_level - 100.0)
	assert_gt(hs.max(), 1000.0)
```

- [ ] **Step 2: Run** `test_world_plan.gd` → FAIL.
- [ ] **Step 3: Implement.** Measure first: time 20,000 `height_at` calls on WADIS before the change and after; write both in the commit message. Over 1.5× today's needs a fix (fewer shapes per cell, cheaper sampling) before Task 10.
- [ ] **Step 4: Sort today's desert tests.** Run `test_world_terrain.gd`, `test_desert_world.gd`, `test_terrain_stamps.gd`, `test_terrain_chunks.gd`. A test of today's desert landforms (dune shape, mesa terraces, towers, talus) sets `recipe.planned = false` on its recipe: that ground lives on inside kept discs. A test about the whole world's shares or relief moves to the plan's numbers. Never weaken an assertion to pass. Then `test_terrain_golden.gd` → PASS.
- [ ] **Step 5: Commit.** `feat(world): a desert's ground from its plan, Wadoo's disc kept to the bit`

## Task 10: The land close up

**Files:** Modify `world_terrain.gd`, `space_palette.gd` (only if `salt` is added), `world_plan.gd` (`DETAIL_REACH`); Test `test_world_plan.gd`, `test_world_terrain.gd`, `test_visual_style_rules.gd`.

**Interfaces:**
- Consumes: the sample layout; today's `DUNE_*`, `MESA_*`, `TOWER_*`, `ROCK_SLOPE`.
- Produces: `_planned_height` complete; `_planned_ground(d, out) -> StringName`; constants for each landform's detail (names the implementer's).

Each kind's detail on the plan's base (§6), the house look throughout (one colour a triangle, `rock` past `ROCK_SLOPE`):
- **Dunes:** today's dune cross-section, phase, swell and pole fade, unchanged, weighted by `S_DUNES`.
- **Plains:** a gentle roll, `ground_low`; near the sea, pale salt pans only if renders want them (a new `salt` key in the desert palette: guide, code and style test together).
- **Plateau country:** today's terraces and towers on each region's edge band, rising to that region's own top (`S_PLATEAU_TOP`).
- **Mountains:** sharp ridged peaks along the spine falling to the flanks (a ridged noise of the terrain's own, per thread), talus and alluvial fans at the foot; `in_talus` true there so boulders gather.
- **Canyons:** `min(ground, floor + walls)`, walls stepped (terraces, `rock` risers, `ground_high` ledges), a flat sandy floor (`ground_low`) of its width.
- **The sea basin:** sand beaches where open ground meets it, cliffs where a range or plateau does, the shelf, the deep floor; `damp` in a band along the waterline.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_canyon_floors_are_level_enough_to_land_on():
	var t := WorldTerrain.new(_wadis())
	for d in _canyon_floor_points(t.plan, 400):
		assert_lt(_slope(t, d, 5.0), deg_to_rad(10.0))

func test_ground_stays_within_the_plans_bounds():
	var t := WorldTerrain.new(_wadis())
	for k in _keys_at_depths(t, [4, 6, 8, 10], 200):
		var b := t.plan.bounds_of(k)
		for d in _points_in(k, 25):
			var h := t.height_at(d)
			assert_true(h >= b.x - 0.01 and h <= b.y + 0.01, "%s outside %s" % [h, b])

func test_no_puddles_away_from_the_sea():
	var t := WorldTerrain.new(_wadis())
	for d in _dirs(20000):
		if t.height_at(d) < t.plan.sea_level:
			assert_lt(t.plan.nearest_shore_m(d), WorldPlan.PUDDLE_FROM)

func test_from_300_m_something_stands_on_the_horizon():
	# §3's anti-goal: from 300 m over open ground, a range, a plateau's edge, a canyon or the sea
	var t := WorldTerrain.new(_wadis())
	var hits := 0
	var spots := _open_ground(t, 200)
	for d in spots:
		if _horizon_feature(t, d, 300.0):
			hits += 1
	assert_gt(float(hits) / spots.size(), 0.8)
```

(`_horizon_feature` looks round 36 bearings out to the horizon from 300 m for any sample whose `land_at` is not open ground or whose ground stands 60 m over the spot's.)

- [ ] **Steps 2–4:** FAIL, implement, PASS. Also `test_world_terrain.gd`, `test_terrain_golden.gd`, `test_visual_style_rules.gd` → PASS.
- [ ] **Step 5: Commit.** `feat(world): dunes, plains, plateaus, ranges, canyons and shores close up`

## Task 11: The far mesh and the plan's bounds

**Files:** Modify `body_look.gd`, `world_surface.gd`, `world_terrain.gd`; Test `test_world_surface.gd`, a new `test_body_look.gd` if none covers the far mesh.

**Interfaces:**
- Produces: `WorldTerrain.surface_at(dir: Vector3) -> float` (`maxf(height_at(dir), sea_level)`; `height_at` with no sea); `WorldTerrain.sea_level: float` (`-INF` with no sea; Task 20 uses it everywhere); `BodyLook.mesh` lifts each point by `surface_at` and colours a point under the sea `sea_shallow`/`sea_deep` by depth (Task 21 adds the keys; until then use `ground_low`). `WorldSurface.bound_of` on a planned desert pads a node by `plan.bounds_of(key)` instead of `relief / 2`; `horizon_reach` takes the plan's least and most height. Rock worlds keep today's relief pad (§8).

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_plan_bounds_never_cull_ground_in_sight():
	var t := WorldTerrain.new(_wadis())
	for focus in _focuses(t, [30.0, 300.0, 2000.0, 10000.0], 20):
		var sel := WorldSurface.select_for(t, focus)   # the planned select
		for d in _ground_in_sight(t, focus, 500):
			assert_true(_covered(sel[0], d), "ground in sight left out")

func test_plan_bounds_cull_more_than_the_relief_pad():
	var t := WorldTerrain.new(_wadis())
	var focus := _over(t, 300.0)
	assert_lt(WorldSurface.select_for(t, focus)[0].size(),
		WorldSurface.select(t.radius, t.relief, CubeSphere.depth_for(t.radius), focus, {}, {})[0].size())
```

`WorldSurface.select_for(terrain: WorldTerrain, local: Vector3, was_split := {}, bounds := {}) -> Array` is new: `select` with the terrain's bounds and heights; `update` calls it.

- [ ] **Steps 2–4:** FAIL, implement, PASS. Also `test_world_surface.gd`, `test_terrain_golden.gd` → PASS.
- [ ] **Step 5: Commit.** `feat(world): the far mesh shows the sea and ranges; nodes culled by the plan's bounds`

## Task 12: The plan's map and Checkpoint 1's renders

**Files:**
- Create: `who-knows/test/probes/plan_map.gd`
- Modify: `who-knows/test/probes/desert_render.gd` (new views), or a new `who-knows/test/probes/land_render.gd` extending it

- [ ] **Step 1: The map probe.** `plan_map.gd` writes `user://plan_map.png`: an equirectangular map of WADIS 2048 × 1024, each `Land` its own flat colour (sea, dunes, plains, plateau, mountains), canyons drawn over, sites marked by kind, Wadoo and its kept disc ringed, the arrival point marked. Run it headless; the PNG is the owner's.
- [ ] **Step 2: The renders** (§11): WADIS from orbit; at 10 km; 2 km over a range and over the (dry) sea basin; 300 m along a canyon; at eye height (1.6 m) on a canyon floor, at a range's foot, on a beach looking out, and from Wadoo's pad; the frame rate seated at each, and flown at the limit along a canyon and over a range. Points come from the plan (`shapes`, `sites`), not hand-picked coordinates.
- [ ] **Step 3: Run both, check every view holds 80 fps,** and send the owner the map and the renders (`SendUserFile`).
- [ ] **Step 3b: The old probes still pass:** `world_probe.gd`, `descent_render.gd`, `desert_render.gd`, `oasis_render.gd`, `landing_play.gd`, `fleet_play.gd`.
- [ ] **Step 4: Commit.** `test(world): the plan's map and the land's renders`

### Checkpoint 1

Stop. Show the owner the map, the renders and the numbers. Tune the dials, the landforms and the colours from what they say (§5.3's numbers are a starting point). Do not begin Part 2 until they are happy with the land.

---

# Part 2: Streaming and speed

## Task 13: The stream probe, first on today's main

**Files:** Create `who-knows/test/probes/stream_probe.gd`.

**Interfaces:**
- Produces: `stream_probe.gd`, run as `-- <route> [assist_off]` or `-- all`, printing one line per route: `route fps_min fps_mean lag_share lag_longest_s pops_within_300`. Routes on WADIS (fixed great-circle paths from Task 12's plan, written as lat/lon pairs so they run on any build): `dunes`, `canyon`, `range`, `coast`, `sea`. Each flown at the limit at 30 m over the surface, then with the assist off at full boost. It never names `WorldPlan` or anything else new on this branch, so the same file runs on `main`.
- Constants (§8.1): `AHEAD := 500.0`, `LAG_SHARE := 0.02`, `LAG_MOST := 0.5`, `POP_WITHIN := 300.0`. **Detail lag:** each frame, 64 points spread over the ground within `AHEAD` m ahead; a point lags when the chunk drawn under it is more than one level coarser than `CubeSphere.key_for` at the depth the quadtree wants there. **Pops:** a chunk shown or hidden within `POP_WITHIN` m, in the camera's view, without an ease running on it (before Task 15, every swap is a pop).

- [ ] **Step 1: Write the probe.**
- [ ] **Step 2: Run it on today's main** in a scratch worktree: `git worktree add ../whoknows-stream-base main`, copy the probe in, run `-- all`, remove the worktree. Record the numbers in the commit message.
- [ ] **Step 3: Run it on this branch** and record those too.
- [ ] **Step 4: Commit.** `test(world): the stream probe, with today's main's numbers`

## Task 14: Detail by level

**Files:** Modify `world_terrain.gd`, `terrain_chunk_data.gd`; Test `test_terrain_chunks.gd`, `test_world_terrain.gd`, `test_terrain_golden.gd`.

**Interfaces:**
- Produces: `WorldTerrain.height_at(dir: Vector3, quad_m := 0.0) -> float` and `colour_at(dir, slope, patch_m, quad_m := 0.0)`: with `quad_m` 0 (the default), full detail to the bit; otherwise detail whose wavelength is under about two `quad_m` is left out (dune ripples, small roughness, the finer octaves), and the result is close to the average of the full detail over the quad. `TerrainChunkData.build` passes its quad size, and 0 at the finest depth. Collision, the analytic floor, altitude, `centre_of` and every other caller keep full detail (§8.2).

An octave left out of a `FastNoiseLite` fBm changes the sum's normalisation: per-level noises with fewer octaves are scaled by their fractal bounding so their low octaves match the full noise's exactly.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_the_finest_chunks_are_full_detail_to_the_bit():
	for r in [_wadis(), WorldRecipe.from_seed(_seed_of(WorldRecipe.Archetype.RIDGED))]:
		var t := WorldTerrain.new(r)
		var k := CubeSphere.key_for(_dir(), CubeSphere.depth_for(t.radius))
		var c := TerrainChunkData.build(t, k)
		for j in CubeSphere.QUADS + 1:
			for i in CubeSphere.QUADS + 1:
				assert_eq(c.grid[j * (CubeSphere.QUADS + 1) + i],
					TerrainChunkData.ground_point(t, TerrainChunkData.corner_dir(k, i, j), c.centre))

func test_coarse_chunks_sit_nearer_the_ground_they_stand_for():
	# each grid point's error against the mean full-detail height over its quad is no worse than today's
	for r in [_wadis(), WorldRecipe.from_seed(_seed_of(WorldRecipe.Archetype.ROLLING))]:
		var t := WorldTerrain.new(r)
		for depth in [6, 8, 10]:
			var e_new := _mean_error(t, depth, true)
			var e_old := _mean_error(t, depth, false)
			assert_lte(e_new, e_old + 0.01)

func test_a_coarse_chunk_builds_faster():
	assert_lt(_build_usec(_wadis(), 8, true), _build_usec(_wadis(), 8, false))
```

- [ ] **Steps 2–4:** FAIL, implement, PASS. `test_terrain_golden.gd` → PASS (default `quad_m` is today's).
- [ ] **Step 5: Run the stream probe** `-- all`; record the change.
- [ ] **Step 6: Commit.** `perf(world): coarse chunks draw only the detail their quads can show`

## Task 15: Easing detail in: the ground shader

The owner allowed one exterior shader for this, 2026-11-20 (§8.2).

**Files:**
- Create: `who-knows/data/materials/exterior/ground_ease.gdshader`, `who-knows/test/probes/ground_shader_match.gd`
- Modify: `terrain_chunk_data.gd`, `world_surface.gd`, `docs/design/visual-style.md` (§2.5, §3.9), `who-knows/test/unit/test_visual_style_rules.gd`
- Test: `test_terrain_chunks.gd`, `test_world_surface.gd`, `test_visual_style_rules.gd`

**Interfaces:**
- Produces: `TerrainChunkData.coarse: PackedVector3Array` (parallel to `positions`: each vertex where the parent's drawn surface has it, relative to this chunk's centre; equal to `positions` at depth 0); `WorldSurface.EASE_TIME := 0.5`; `WorldSurface.ground_material() -> ShaderMaterial` (the chunks'; `BodyLook.material(false)` stays the far mesh's); instance uniform `ease` 0–1 per chunk.

The shader: `VERTEX += CUSTOM0.xyz * (1.0 - ease)` where `CUSTOM0` is `coarse - positions` (`Mesh.ARRAY_CUSTOM0`, `ARRAY_CUSTOM_RGB_FLOAT`); the rest is `BodyLook.material(false)`'s look written out: vertex colour as albedo, roughness 1, the given flat normals, default specular and metallic, fog and shadows as the engine does them. If renders show the light jumping as a chunk eases, ease the normals too through `CUSTOM1`.

How chunks ease (in `_prune_chunks` and a per-frame `_ease(delta)`): a chunk shown where its parent was drawn starts at `ease` 0 and rises to 1 over `EASE_TIME`; a merge eases the other way: the children keep drawing until the parent is built (as today), ease down to 0, then the parent shows and they go. A chunk whose parent was never drawn shows at 1.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_a_childs_coarse_shape_is_its_parents_drawn_surface():
	var t := WorldTerrain.new(_wadis())
	var parent_key := CubeSphere.key_for(_dir(), 9)
	var parent := TerrainChunkData.build(t, parent_key)
	for child_key in CubeSphere.children(parent_key):
		var c := TerrainChunkData.build(t, child_key)
		for v in c.coarse.size():
			var world := c.coarse[v] + Vector3(c.centre)
			assert_lt(_distance_to_surface(parent, world), 0.001)

# test_visual_style_rules.gd
const EXTERIOR_SHADER_DIR := "res://data/materials/exterior/"
func test_the_grounds_easing_shader_is_the_only_exterior_shader():
	var shaders: Array = []
	for file in DirAccess.get_files_at(EXTERIOR_SHADER_DIR):
		if file.ends_with(".gdshader"):
			shaders.append(file)
	assert_eq(shaders, ["ground_ease.gdshader"],
		"an exterior shader needs the owner's approval -- docs/design/visual-style.md §3.9")
```

- [ ] **Steps 2–4:** FAIL, implement, PASS (`test_terrain_chunks.gd`, `test_world_surface.gd`, `test_visual_style_rules.gd`).
- [ ] **Step 5: Prove it draws today's look.** `ground_shader_match.gd` renders the same five views (from Task 12's set) twice, chunks with `ground_material()` at `ease` 1 and with `BodyLook.material(false)`, and compares: mean absolute difference per channel under 1/255 and no pixel over 4/255. Run it; it must pass.
- [ ] **Step 6: The guide.** §3.9's "No exterior shader" names `ground_ease.gdshader` as the one exception the owner allowed on 2026-11-20 and what it may do (ease only); §2.5's budget line says the same.
- [ ] **Step 7: Run the stream probe** `-- all`: pops within 300 m should now be 0.
- [ ] **Step 8: Commit.** `feat(world): the ground eases its detail in (the owner's one exterior shader)`

## Task 16: Ask ahead

**Files:** Modify `world_surface.gd`; Test `test_world_surface.gd`.

**Interfaces:**
- Produces: `WorldSurface.AHEAD_S := 2.0`, `AHEAD_MAX := 1000.0`; `_distance(key)` is the nearer of the distance from where the focus is and from where it will be (`_local + velocity * AHEAD_S`, capped at `AHEAD_MAX`), the velocity read from `universe.focus` by `_velocity_of`.

- [ ] **Step 1: Write the failing test.**

```gdscript
func test_ground_ahead_is_asked_for_before_ground_behind():
	var s := _surface_on(_wadis(), 30.0, Vector3(0, 0, -200.0))   # moving 200 m/s along -z
	var ahead := _leaf_toward(s, Vector3(0, 0, -1), 300.0)
	var behind := _leaf_toward(s, Vector3(0, 0, 1), 300.0)
	assert_lt(s._rank(ahead), s._rank(behind))
```

- [ ] **Steps 2–4:** FAIL, implement, PASS.
- [ ] **Step 5: Commit.** `perf(world): the ground ahead is built first`

## Task 17: The stricter limit near the surface

**Files:** Modify `flight_computer.gd`; Test `test_speed_limit.gd`, `test_flight_computer.gd`; Modify `.claude/skills/building-a-ship/reference.md`.

**Interfaces:**
- Produces: `FlightComputer.LOW_LIMIT_MPS := 70.0`, `LOW_UNDER := 50.0`, `LOW_BLEND_TO := 1000.0`. `speed_limit(altitude, well_top)`: today's curve, except under `LOW_BLEND_TO` it is `lerpf(LOW_LIMIT_MPS, today, smoothstep(LOW_UNDER, LOW_BLEND_TO, a))`, so 70 m/s up to 50 m and today's 145 at 1,000 m. On or under the surface it is `LOW_LIMIT_MPS`; outside a well and at its edge, `CRUISE_LIMIT_MPS` as today. Every world (§8.5). `entry_heat`'s early out compares with `HEAT_FROM * LOW_LIMIT_MPS`, not cruise.

The AI's ships use the same `current_limit` (`ship_pilot.gd`), so their low fights slow too; nothing to change there. The velocity panel shows `LIMIT %d` from the limit already (`velocity_panel.gd:111`); check it reads 70 near the ground.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_the_limit_is_70_near_the_surface():
	assert_eq(FlightComputer.speed_limit(0.0, 50000.0), 70.0)
	assert_eq(FlightComputer.speed_limit(50.0, 50000.0), 70.0)
	assert_almost_eq(FlightComputer.speed_limit(1000.0, 50000.0), 145.0, 0.01)
	assert_almost_eq(FlightComputer.speed_limit(4000.0, 50000.0), 220.0, 0.01)   # today's above

func test_the_limit_never_falls_as_you_climb():
	var last := 0.0
	for a in range(0, 5000, 5):
		var l := FlightComputer.speed_limit(float(a), 50000.0)
		assert_gte(l, last - 1e-9)
		last = l
```

(`entry_heat`'s early out has no test of its own: it is a one-line change; Task 24's low renders show the glow.)

- [ ] **Steps 2–4:** FAIL, implement, PASS (`test_speed_limit.gd`, `test_flight_computer.gd`).
- [ ] **Step 5: The skill.** `building-a-ship/reference.md`: the new curve and its constants.
- [ ] **Step 6: Commit.** `feat(flight): a stricter limit near the surface, on every world`

## Task 18: Thick air holds you near the limit with the assist off

**Files:** Modify `world_gravity.gd`; Test `test_world_gravity.gd`; Modify `building-a-ship/reference.md`.

**Interfaces:**
- Produces: `WorldGravity.HOLD_K := 1.0` (1/m); `static func hold(air: float, v: Vector3, limit: float, dt: float) -> Vector3` (an acceleration: `-v̂ × HOLD_K × air × (|v| − limit)²` past the limit, 0 under it, never more than `(|v| − limit) / dt` in size); `drag_at(p, v)` adds `hold(air_at(p), v, FlightComputer.speed_limit(altitude_at(p), well_top), 1.0 / Engine.physics_ticks_per_second)` where there is air. Airless worlds: nothing, as today (§8.5).

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_full_thrust_settles_near_the_limit_in_thick_air():
	var v := 70.0
	for tick in 600:
		v += (100.0 - WorldGravity.hold(1.0, Vector3(0, 0, v), 70.0, 1.0 / 60.0).length()) / 60.0
	assert_between(v, 70.0, 70.0 * 1.15)

func test_no_hold_without_air_or_under_the_limit():
	assert_eq(WorldGravity.hold(0.0, Vector3(0, 0, 300), 70.0, 1.0 / 60.0), Vector3.ZERO)
	assert_eq(WorldGravity.hold(1.0, Vector3(0, 0, 60), 70.0, 1.0 / 60.0), Vector3.ZERO)

func test_the_hold_never_takes_more_than_the_excess_in_a_tick():   # Review Focus 3
	var dt := 1.0 / 60.0
	for speed in [80.0, 200.0, 600.0, 2000.0]:
		var a := WorldGravity.hold(1.0, Vector3(0, 0, -speed), 70.0, dt)
		assert_lte(a.length() * dt, speed - 70.0 + 1e-6)
		assert_gt(a.z, 0.0)   # against the motion, never with it
```

- [ ] **Steps 2–4:** FAIL, implement, PASS.
- [ ] **Step 5: The skill.** `reference.md`: the air hold.
- [ ] **Step 6: Commit.** `feat(flight): thick air holds you near the limit, the assist off too`

## Task 19: Tune to the pass line

- [ ] **Step 1: Run the stream probe** `-- all`, assist on and off, on the GTX 960.
- [ ] **Step 2: Settle the limit.** Raise `LOW_LIMIT_MPS` (and move `LOW_UNDER`, `LOW_BLEND_TO`) to the fastest that still meets the pass line on every route: lag in at most 2% of samples, never over 0.5 s, no pop within 300 m. If 70 m/s fails, the fix is in streaming (MAX_JOBS, the apply budget, build cost), not a lower limit below 50 m/s without asking the owner.
- [ ] **Step 3: Low flight's fps.** Seated, flown at the limit at 30 m along the canyon and over the range: at least 80 fps.
- [ ] **Step 4: Update** `test_speed_limit.gd`'s numbers to the settled ones, run it → PASS.
- [ ] **Step 5: Commit** with the before and after table: `perf(world): the limit near the ground, tuned to the pass line`

### Checkpoint 2

Stop. Show the owner the before and after numbers (main against this branch) and a low flight down a canyon (a render sequence or a short capture), and the limit you settled. Wait for them.

---

# Part 3: The sea

## Task 20: The surface every flying thing knows

**Files:** Modify `world_terrain.gd`, `world_gravity.gd`, `whereabouts.gd`, `terrain_collider.gd`, `world_surface.gd`, `stray_field.gd`, `spawn_spot.gd`; Test `test_world_gravity.gd`, `test_world_surface.gd`, `test_terrain_chunks.gd`.

**Interfaces:**
- Consumes: `WorldTerrain.surface_at`, `sea_level` (Task 11).
- Produces: `WorldTerrain.surface_altitude_of(local: Vector3) -> float` (to `surface_at`). `WorldGravity.altitude_at(p)` measures to the surface (the limit, the air, the landing aid through `keel_altitude`, the AI's `above_air`, the HUD through `Whereabouts.altitude()`); new `WorldGravity.ground_altitude_at(p)` to the ground, used by what stands on it (`stray_field.gd`'s items). `TerrainCollider.keys_near`/`keys_along`/`ground_gap` and `WorldSurface._near_soon` use the surface, so hulls over water get solid chunks. `WorldSurface`'s split keeps the ground (deep water stays coarse, §8.4). `SpawnSpot.clear_of_ground` uses `surface_at`. `_keep_anchors_above_ground` keeps the ground for the avatar and items; Task 22 gives hulls the sea.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_altitude_over_the_sea_is_to_the_water():
	var g := _gravity_on_wadis()
	var p := _over_sea(g, 30.0)        # 30 m over the water, over deep sea
	assert_almost_eq(g.altitude_at(p), 30.0, 0.5)
	assert_gt(g.ground_altitude_at(p), 100.0)

func test_hulls_over_the_sea_want_solid_chunks():
	var s := _surface_with_hull_over_sea(10.0)
	assert_gt(s._solid_wanted().size(), 0)
```

- [ ] **Steps 2–4:** FAIL, implement, PASS. Also `test_stray_field.gd` if it exists, `test_landing_monitor.gd`.
- [ ] **Step 5: Commit.** `feat(world): altitude over the sea is to the water`

## Task 21: The water drawn

**Files:** Modify `terrain_chunk_data.gd`, `world_terrain.gd`, `body_look.gd`, `space_palette.gd`, `world_surface.gd`, `docs/design/visual-style.md`; Test `test_terrain_chunks.gd`, `test_visual_style_rules.gd`, `test_floating_origin_scene.gd`.

**Interfaces:**
- Produces: desert palette keys `sea_shallow` (starting `2f5f55`) and `sea_deep` (starting `1d3f4a`): darker and deeper than they read in the sun (style guide §2.2's note), green-blue, not icy. `TerrainChunkData`: each quad with any corner under `sea_level` also gets two water triangles at `sea_level` (radius + sea level along each corner's direction), coloured by `WorldTerrain.sea_colour(dir: Vector3) -> Color` (the depth under them, `sea_shallow` to `sea_deep` over `WorldTerrain.SEA_COLOUR_DEEP := 40.0` m, in `SpacePalette.SHADES` steps; the far mesh uses it too, in place of Task 11's stand-in), in the same surface as the ground (one draw), with skirts; `water_faces: PackedVector3Array` for collision (Task 22). A chunk wholly under deep water draws its sheet and no seabed (`water_only`).

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_a_chunk_by_the_shore_draws_its_water_at_sea_level():
	var t := WorldTerrain.new(_wadis())
	var c := TerrainChunkData.build(t, _shore_key(t, CubeSphere.depth_for(t.radius)))
	assert_gt(c.water_faces.size(), 0)
	for p in c.water_faces:
		assert_almost_eq((p + Vector3(c.centre)).length(), t.radius + t.sea_level, 0.01)

func test_water_colours_come_from_the_palette():
	var desert: Dictionary = SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE]
	assert_true(desert.has(&"sea_shallow") and desert.has(&"sea_deep"))
```

- [ ] **Steps 2–4:** FAIL, implement, PASS. `test_visual_style_rules.gd`, `test_floating_origin_scene.gd` (with a sea chunk loaded) → PASS.
- [ ] **Step 5: The guide.** The sea in the world section and its keys in the palette table, in this commit.
- [ ] **Step 6: Commit.** `feat(world): the sea, drawn by the chunks in flat colour by depth`

## Task 22: Hulls and the water

**Files:** Modify `world_surface.gd`, `src/ship/ship.gd`, `landing_monitor.gd`, `spawn_spot.gd`; Test `test_landing_monitor.gd`, `test_landing_save.gd`, `test_world_surface.gd`; Modify `building-a-ship/SKILL.md` (checklist), `reference.md`, `ship_probe.gd`.

**Interfaces:**
- Produces: `WorldSurface.WATER_LAYER := 256` (a physics layer only hulls mask: `ship.gd`'s exterior mask adds it); each solid chunk with `water_faces` gets a second body on `WATER_LAYER`; `LandingMonitor.is_water(body) -> bool`; a hull touching only water is never `LANDED` (`touching` counts ground alone) and `refusal()` says `"On water"`; `Ship` uses `TERRAIN_CRASH_FROM` for water as for ground; `_keep_anchors_above_ground` lifts an anchor whose mask has `WATER_LAYER` (a hull) out from under the sea's surface as from under the ground.

With the assist on, the gravity hold keeps you hovering; with it off, the hull rests on the water and drifts to a stop (the water body's friction).

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_a_hull_on_the_water_never_lands():
	var m := _monitor_on_water()
	_settle(m, 3.0)
	assert_false(m.is_landed())
	assert_eq(m.refusal(), "On water")

func test_a_hull_with_its_feet_on_the_beach_lands():   # Review Focus 2
	var m := _monitor_feet_on_sand_stern_on_water()
	_settle(m, 3.0)
	assert_true(m.is_landed())

func test_a_ship_spawned_over_the_sea_starts_above_the_water():   # Review Focus 1
	var spot := SpawnSpot.clear_of_ground(_sea_point(), _centre(), _terrain(), 12.0)
	assert_gt(_surface_altitude(spot), 0.0)

func test_a_ship_restored_landed_over_the_sea_floats_not_landed():   # Review Focus 1
	var ship := _restore_landed_at(_sea_point())
	_run_ticks(300)
	assert_false(ship.landing.is_landed())
	assert_gt(_surface_altitude(ship.hull.global_position), -0.5)
```

- [ ] **Steps 2–4:** FAIL, implement, PASS.
- [ ] **Step 5: The skill.** Checklist: no landing on water, no stepping out over it; *Mistakes already made* if any; `reference.md`: `WATER_LAYER`; `ship_probe.gd`: a line that the exterior masks `WATER_LAYER`.
- [ ] **Step 6: Run** `test/probes/fleet_play.gd` and `landing_play.gd` → pass.
- [ ] **Step 7: Commit.** `feat(ship): hulls ride the water and never land on it`

## Task 23: On foot in the sea

**Files:**
- Create: `who-knows/src/world/sea_water.gd`
- Modify: `avatar.gd`, `grasp.gd`, `src/npc/populations/wadoo_site.gd` (`open`), `who-knows/scenes/flight_test.gd` (makes the `SeaWater` beside the `PlaceField`)
- Test: new `test_sea_water.gd`, `test_avatar.gd`, `test_ground_walker.gd` if it exists

**Interfaces:**
- Produces: `class_name SeaWater extends Node`: each physics tick, for the avatar on foot on a world with a sea, sets `Avatar.wade_depth` to the water over the ground under it and `Avatar.treading` when that is over `Avatar.TREAD_DEPTH := 1.3` (chest); `0` and `false` out of it, never fighting a `PoolWater` (the deeper of the two wins). `Avatar.treading: bool`; while treading the avatar is held with its feet `TREAD_DEPTH` under the surface, moving at `wade_factor(WADE_DEEP)`, no jump, no diving; it can always walk back out. `Grasp.drop()` does nothing while treading. `WorldTerrain.KNEE := 0.5` and `WorldTerrain.dry_enough(dir: Vector3) -> bool` (no water over `KNEE`): a world site's `open(p)` (today `WadooSite`) is false where it is not.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_wading_in_the_shallows_slows_you():
	var a := _avatar_at_depth(0.8)
	_tick(a)
	assert_almost_eq(a.wade_depth, 0.8, 0.05)
	assert_false(a.treading)

func test_deep_water_holds_you_at_chest_depth():
	var a := _avatar_at_depth(6.0)
	_tick(a, 120)
	assert_true(a.treading)
	assert_almost_eq(_feet_under_surface(a), Avatar.TREAD_DEPTH, 0.1)

func test_you_cannot_drop_things_while_treading():
	var a := _avatar_at_depth(6.0, &"crate")
	a.grasp.drop()
	assert_not_null(a.grasp.held())

func test_a_suit_restored_in_deep_water_treads():   # Review Focus 4
	var a := _restore_avatar_at(_deep_sea_point())
	_tick(a, 60)
	assert_true(a.treading)

func test_a_suit_restored_under_new_ground_is_lifted_out():   # Review Focus 4
	var a := _restore_avatar_at(_under_a_range_point(-20.0))
	_tick(a, 10)
	assert_gte(_ground_altitude(a), -WorldSurface.FLOOR_SLACK)

func test_an_item_dropped_in_the_shallows_lies_on_the_seabed():   # Review Focus 5
	var item := _drop_item_at_depth(0.6)
	_tick_items(120)
	assert_almost_eq(_ground_altitude(item), 0.0, 0.3)
```

- [ ] **Steps 2–4:** FAIL, implement, PASS.
- [ ] **Step 5: The NPC skill.** `building-an-npc`: NPCs on worlds keep out of water over their knees (checklist), the sea in `reference.md`.
- [ ] **Step 6: Commit.** `feat(avatar): wade in the shallows, tread water in the deep`

## Task 24: The sea's renders and Checkpoint 3

- [ ] **Step 1: Renders:** the sea from orbit, 2 km over it, skimming at 30 m, a canyon opening onto the beach, on the beach looking out, wading to the chest, a hull resting on the water. The frame rate seated at each and flown low over the sea at the limit: at least 80 fps.
- [ ] **Step 2: The restore probe:** a save made on main with a ship landed where WADIS now has sea, loaded on this branch: the ship floats, not under the sheet; a ship landed on what is now a mountain's flank is set down safely (the existing safe restore).
- [ ] **Step 3: Run** `oasis_render.gd`, `wadoo_play.gd`, `fleet_play.gd`, `landing_play.gd` → pass.
- [ ] **Step 4: Commit** the probe changes. `test(world): the sea's renders and restores`

### Checkpoint 3

Stop. Show the owner the shore and sea renders. Tune the water's colours and the shores from what they say.

---

# Part 4: Wild oases

## Task 25: An oasis from a site

**Files:**
- Create: `who-knows/src/world/plan/wild_oasis.gd`
- Modify: `world_plan.gd`, `world_terrain.gd` (`_take_stamps`), `place_design.gd`
- Test: new `test_wild_oasis.gd`

**Interfaces:**
- Consumes: `PlanSite` (Task 8).
- Produces:
  - `class_name WildOasis extends RefCounted`; `static func make(site: PlanSite, world_seed: int, k: int, world_radius: float) -> Dictionary` returning `{"place": PlaceDesign, "stamps": Array[TerrainStamp], "layout": Dictionary}`, everything drawn from `WorldSeed.rng(WorldSeed.sub(world_seed, &"wild_oasis"), StringName("o%d" % k))`.
  - Stamps (like Wadoo's, minus the town): a floor that keeps some of the land's roll (FLATTEN, keep about 0.35); a green ring (FLATTEN, radius 35–60 m, `raise` 0, ground `grass`, so it shows green from the air on coarse chunks); the pool's shore and basin (radius 4–12.5 m: 8–25 m across; basin ground `damp`).
  - Layout, in `PlaceField`'s keys: `pool`, `palms` (in clusters), `grass_ring`; in about one oasis in three, a few old walls half buried, as `rubble` and broken low wall runs the brick builder already makes.
  - `PlaceDesign`: `var generated_layout: Dictionary = {}`; `layout()` returns it when it is not empty. Places are `wild_<k>`, `beacon` false, lat/lon from the site's direction.
  - `WorldPlan.wild: Array[Dictionary]` (the `oases` dial's best `OASIS` sites through `make`); `WorldPlan.stamps: Array[TerrainStamp]` (theirs, levels resolved once at the end of `build` by a `WorldTerrain` over the plan without them, so `_take_stamps` never samples for them); `_take_stamps` takes the recipe's then the plan's.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_wadis_has_six_wild_oases_the_same_every_time():
	var a := _wadis().plan().wild
	var b := WorldPlan.build(_wadis()).wild
	assert_eq(a.size(), 6)
	for i in a.size():
		assert_eq(a[i].place.lat, b[i].place.lat)
		assert_eq(a[i].layout, b[i].layout)

func test_about_one_in_three_has_ruins():
	var site := _wadis().plan().sites.filter(func(s): return s.kind == PlanSite.Kind.OASIS)[0]
	var with_ruins := 0
	for k in 300:
		if WildOasis.make(site, 1337, k, _wadis().radius_m).layout.has("rubble"):
			with_ruins += 1
	assert_between(with_ruins / 300.0, 0.25, 0.42)

func test_an_oasis_shows_green_from_afar():
	var t := WorldTerrain.new(_wadis())
	for o in t.plan.wild:
		var d: Vector3 = o.place.local_dir(0.0, 30.0, t.radius)   # inside the green, off the pool
		assert_eq(t.ground_at(d, 0.0), &"grass")

func test_no_wild_oasis_needs_a_level_worked_out_per_thread():
	for s in _wadis().plan().stamps:
		assert_false(s.has_level() and is_nan(s.level))
```

- [ ] **Steps 2–4:** FAIL, implement, PASS. `test_terrain_golden.gd` → PASS (no wild oasis in Wadoo's disc).
- [ ] **Step 5: Commit.** `feat(world): wild oases generated from the plan's sites`

## Task 26: Loading them

**Files:** Modify `system_recipe.gd` (`places()`), `place_field.gd`; Test `test_place_field.gd`, `test_floating_origin_scene.gd`, `test_system_design.gd`.

**Interfaces:**
- Produces: `SystemRecipe.places()` lists each desert body's `plan().wild` places after the designed ones (the validator reads only designed places, `places_on`, so it is unchanged); `PlaceField` loads and frees them like Wadoo (members of `Universe.EXTERIOR_SPACE`, pieces as children). No beacon. `OasisPalette` colours only.

- [ ] **Step 1: Write the failing tests.**

```gdscript
func test_a_wild_oasis_loads_near_you_and_goes_far_away():
	var field := _field_on_wadis()
	var o: PlaceDesign = _wadis().plan().wild[0].place
	_focus_at(field, o, 500.0)
	field.update()
	assert_not_null(field.loaded(o.id))
	assert_true(field.loaded(o.id).is_in_group(Universe.EXTERIOR_SPACE))
	_focus_at(field, o, 12000.0)
	field.update()
	assert_null(field.loaded(o.id))

func test_wild_oases_have_no_beacon():
	for p in SystemRecipe.from_seed(1337).places():
		if String(p.id).begins_with("wild_"):
			assert_false(p.beacon)
```

- [ ] **Steps 2–4:** FAIL, implement, PASS. `test_floating_origin_scene.gd` with a wild oasis loaded → PASS.
- [ ] **Step 5: Commit.** `feat(world): wild oases load like Wadoo, with no beacon`

## Task 27: The oases' renders and Checkpoint 4

- [ ] **Step 1: Renders:** a wild oasis from 2 km (green in sight), from 300 m, landed beside it, at eye height at the pool, among the palms, one with ruins; the frame rate seated at a wild oasis and on foot there: at least 80 fps.
- [ ] **Step 2: Run** `oasis_render.gd`, `wadoo_play.gd` → pass (Wadoo unchanged).
- [ ] **Step 3: Commit.** `test(world): the wild oases' renders`

### Checkpoint 4

Stop. Show the owner the oasis renders. Tune from what they say.

---

# Part 5: Docs and skills

## Task 28: Docs and skills in the same branch

**Files:** `docs/design/visual-style.md`, `docs/superpowers/specs/2026-11-03-desert-world-design.md`, `.claude/skills/building-a-ship/` (`SKILL.md`, `reference.md`, `ship_probe.gd`), `.claude/skills/building-an-npc/` (`SKILL.md`, `reference.md`), `CLAUDE.md` (only if a palette was added).

- [ ] **Step 1: The style guide:** the new landforms and the sea in the world sections (§3.9 and the desert's), every new palette key, §2.6's new frame-rate numbers from Checkpoints 1–4; check §2.5 and §3.9 still say what Task 15 wrote.
- [ ] **Step 2: The desert world spec:** a pointer to this design from §7.2 and §13 (the sea exists now, smaller than the ocean world).
- [ ] **Step 3: The skills:** check every name each mentions still exists; `building-a-ship` has the limit curve, the air hold, `WATER_LAYER`, no landing on water and no stepping out over it; `building-an-npc` has the knee rule and the sea. Lessons learned while building go in each *Mistakes already made*.
- [ ] **Step 4: Run** `test_visual_style_rules.gd`, `test_ship_catalog.gd`, `test_npc_catalog.gd`, and `.claude/skills/building-a-ship/ship_check.gd` on the starter → pass.
- [ ] **Step 5: Commit.** `docs: WADIS's land in the style guide, the desert spec and the skills`

Then report to the owner: what was built, the numbers, what was not verified, and that the branch waits for their word to merge.
