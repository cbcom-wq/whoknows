# Desert World, Phase 2: The Desert Style — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The generator can roll a desert for any planet with air: warm sand in long dunes with a soft windward side and a steeper lee, all running one way and turning slowly across the world; flat mesas with steep rock risers, and rock towers where the terraces break up; boulders and tufts of dry grass on the ground near you; thin streaks of blowing sand at your feet. It is faceted and flat-coloured, it reads as a desert from orbit, and every world that is not a desert stays exactly the world it was.

**Architecture:** `WorldRecipe` draws "is this a desert" from its own sub-seed (`&"desert"`) and, for a desert, overrides the archetype to a new `DUNES` (appended to the enum) and the palette to a new `desert` palette (appended to `SpacePalette.WORLDS`, outside the old draw). `WorldTerrain.height_at` gains the dune field, mesas and towers, so the far mesh, chunks, collision, landing and the speed limit all see them with no other change. `GroundCover.scatter(terrain, key)` is a pure function that places boulders and grass on one finest chunk from that chunk's own sub-seed. `TerrainChunkData` appends the boulders' faces to its collision, and a `CoverField` under each `WorldSurface` streams the drawn cover in blocks round the focus on worker threads. `BlowingSand` is one GPU particle emitter in local coordinates, a member of `Universe.EXTERIOR_SPACE`, that spawns streaks round the focus along `WorldTerrain.wind_at`. No shader.

**Tech Stack:** Godot 4.5.1, GDScript, GUT. Tests run with `who-knows/run_tests.ps1 -gselect=<test file without .gd>`.

**Spec:** `docs/superpowers/specs/2026-11-03-desert-world-design.md`: §7 (phase 2) is the scope, with §3 (anti-goals), §5.6 (boulders folded in), §9 (style guide), §10 (verification), §11 (upkeep), §12 and §14. Pictures: `docs/superpowers/specs/2026-11-03-desert-world/descent.html` stage 4 and `beast-concept.webp` (the land). Read `docs/design/visual-style.md` §2, §3.5 and §3.9 before any visual task.

**Work in:** `D:/git/whoknows-desert-style`, branch `desert-style`, made from `main` at `3af7971` (`git worktree add ../whoknows-desert-style -b desert-style main`). Run Godot's `--import` once there before the first test (its `.godot` cache starts empty). Never switch a branch or commit in `D:/git/whoknows`.

## Global Constraints

- **Targeted tests only:** `run_tests.ps1 -gselect=<file>` for the files a task touches. Never the full suite; the owner is asked at the end (Task 8).
- **Today's worlds stay the same** (spec §3, §7.4). A planet that is not a desert keeps its archetype, palette, relief, radius, gravity and atmosphere bit for bit. Never write `Archetype.size()` or `SpacePalette.WORLDS.size()` in a draw: the old draws use `DRAWN_ARCHETYPES` (4) and `DRAWN_PALETTES` (8), fixed numbers.
- **Deserts are planets with air only:** `kind == PLANET` and `atmosphere != NONE`, with probability `DESERT_SHARE` = **0.25**. Moons and bare worlds are never deserts. Measured before planning: none of `test_world_recipe`'s four pinned seeds rolls a desert at 0.25 (their rolls are 0.64, 0.43, 0.70, 0.43); in the starting system 1337, planets `p3` (thick, 55 km, roll 0.04) and `p4` (thick, 15 km, roll 0.12) become deserts. `p3` is the probes' desert.
- **`GENERATOR_VERSION` goes to 3,** because the desert seeds' worlds really change. Nothing in `src` reads it today; say so in the spec's status block.
- **One ground.** Dunes, mesas and towers live only in `WorldTerrain.height_at` and `ground_at`. Nothing else shapes the ground. Boulders and grass sit on the ground the finest chunk's triangles describe (the collision), never on a raw `height_at` sample between corners.
- **Same every time:** cover comes from `WorldSeed.sub(recipe.seed, &"cover")` mixed with the finest key, and nothing about it depends on which detail is drawn, what was built before, or the thread it is built on.
- **The floating origin** (CLAUDE.md): every `CoverField` block is a member of `Universe.EXTERIOR_SPACE` placed from its `UniversePoint`. `BlowingSand` is a member of `EXTERIOR_SPACE` too, with `local_coords = true`; it is **not** in `HOLDS_SHIFT`, because an emitter that never stops would hold the origin back until the forced shift at 4 km (phase 0's hover-puff lesson). This is a ruling against spec §7.3's "join `HOLDS_SHIFT`", which assumed short bursts. `test_floating_origin_scene.gd` passes after Tasks 5 and 6.
- **Colours come only from the palettes** (style guide §2.2). New keys on **every** `WORLDS` entry: `&"boulder"` and `&"grass"`. The new `desert` entry also carries `&"streak"` (blowing sand). `ground_cover.gd`, `cover_field.gd` and `blowing_sand.gd` join `PAINTING_FILES`.
- **No shader**, inside or out (style guide §3.9). Engine materials and particles only. Grass does not sway.
- **Frame budget:** at least **120 fps at 1280 × 720 on the GTX 960**, windowed probe. Phase 1 measured **134 seated on the ground** and **120 seated at full entry heat**. Cover and sand must not be drawn at entry heat (they are only near the ground), and seated on the ground is the view to watch.
- **No `.tscn`/`.tres` edits.** Everything is built in code.
- **Skills and documents are updated in the same branch** (CLAUDE.md, spec §11): Task 8.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Merging and pushing need the owner.

## Calls made in this plan (mine; the owner can change any)

1. **The share:** a quarter of planets with air are deserts (`DESERT_SHARE` 0.25), thin air or thick.
2. **A desert gets its own palette,** `desert`, appended to `WORLDS` at index 8, starting from `sand`'s values. `sand` itself is untouched, so worlds that already roll `sand` keep their look. The starting values are retuned at Checkpoint A only.
3. **The dunes:** crests `DUNE_WAVE` **320 m** apart, up to `DUNE_HEIGHT` **18 m** high, the lee taking `DUNE_LEE` **0.18** of each wave (so the lee is about 17° at full height and the windward side about 4°). Their height varies along the crest from 0.35 to 1 by a slow noise, so they read as a field, not corduroy.
4. **The direction:** one wind axis per world (`&"wind"`). Ridges are level lines of `d · axis`, warped by a slow noise so they turn across the world. Near the axis's two poles, where those lines would close into rings, the dunes fade into flat sand sheets (`DUNE_POLE` 0.9).
5. **Mesas** rise where the continent layer is above `MESA_FROM` **0.12**, in `TERRACES` steps, and the dunes fade out over `MESA_EDGE` **0.05** below them. **Towers** stand in the band `TOWER_BAND` **0.06** below the mesa line: cellular columns `TOWER_WAVE` **140 m** apart, `TOWER_RADIUS` 8–22 m, one cell in `TOWER_SHARE` **0.3** standing, each rising to the next terrace up.
6. **Colours on a desert:** dunes `ground_low`, the flats between dunes (the lowest fifth of a wave) `dust`, mesa tops `ground_high`, risers, towers and anything over 35° `rock`.
7. **Boulders on every world,** not only deserts: Planetfall gave every world boulders, and §5.6 folds them in here. On a desert they cluster at the feet of mesas and towers (`BOULDER_TALUS` 3 per 100 m² within the band) and are rare on the dunes (0.15 per 100 m²); elsewhere 0.8 per 100 m². Sizes 0.5–4 m, skewed small (`u³`), a third sunk. None steeper than 30°.
8. **Grass on deserts only,** in clumps (a noise share), on sand under 15°, `GRASS_PER_100M2` **5** in a clump and none outside; tufts 0.3–0.7 m. No collision. Drawn out to 70 m.
9. **Cover is drawn in blocks** two levels coarser than the finest chunks (about 100 m across), so 300 m of boulders is about 30 blocks and 90 draw calls, not 400. Boulders out to `BOULDER_REACH` **300 m**, with a fade.
10. **Blowing sand** on deserts where air ≥ 0.3, full below 15 m over the ground and gone by 60 m (the focus's altitude). 160 streaks 1.5–3 m long, 0.05 m wide, 1.2–2 s life, 8–14 m/s along `wind_at`, in a box 60 × 6 × 60 m round the focus.

**Not in phase 2:** the pad and stamps keeping cover clear (phase 3's stamps). Grass that sways. Wind direction in the wind sound. Cover on habitat rocks or asteroids.

## Review Focus

The five most likely to bite a player, that the spec implies and no task's main tests exercise. Each has its test in the task named.

1. **Landing in a boulder field.** A 4 m boulder under a landing leg must read as uneven ground (the *UNEVEN GROUND · TILT n°* refusal or a tilted, legal landing), never a crash, a ship stuck between rocks, or damage. Task 7 (the probe's boulder landing, measured), with the cover density being the knob.
2. **Cover coming in as you fly low and fast.** At the low-flight speed limit (about 150 m/s) cover must not pop in a block at a time in front of you, and the ground's solid boulders must exist before a hull or the avatar reaches them. Task 5 (`test_blocks_ahead_are_asked_for_first`, `test_boulders_are_solid_where_the_ground_is`).
3. **Far dunes aliasing.** Coarse chunks sample the dune field at quads of 30 m and more; far dunes must not shimmer into noise or pop as detail changes. Task 2 (`test_dunes_change_little_between_details`) and Checkpoint A's renders at 2 km.
4. **A save made before phase 2 on a world that is now a desert:** a ship saved landed there must not hang frozen in the air or sit buried in a dune. Task 4 (`test_restored_landed_off_the_ground_falls_and_settles`).
5. **A floating-origin shift with sand blowing and cover drawn:** streaks and stones stay put on the ground, nothing jumps, and the origin is never held back by the sand. Task 5 (`test_blocks_follow_a_shift`) and Task 6 (`test_sand_never_holds_the_origin`, `test_streaks_keep_their_place_across_a_shift`).

---

## File Structure

| File | What it does |
|---|---|
| `who-knows/src/world/world_recipe.gd` (modify) | `DUNES`, `DESERT_SHARE`, `DRAWN_ARCHETYPES`, the `&"desert"` draw, `is_desert()`, `GENERATOR_VERSION` 3 |
| `who-knows/src/world/space_palette.gd` (modify) | `DRAWN_PALETTES`, `DESERT_PALETTE`, the `desert` entry, `boulder` and `grass` on every entry, `streak` on desert |
| `who-knows/src/world/world_terrain.gd` (modify) | The dune field, mesas, towers, their colours, `wind_at(dir)`, `in_talus(dir)` |
| `who-knows/src/world/ground_cover.gd` (create) | Pure: `scatter(terrain, key) -> GroundCover`, the boulders' collision faces, the grass mesh |
| `who-knows/src/world/terrain_chunk_data.gd` (modify) | Finest chunks append their boulders' faces to `faces` |
| `who-knows/src/world/cover_field.gd` (create) | Node under `WorldSurface`: streams cover blocks round the focus on workers |
| `who-knows/src/world/world_surface.gd` (modify) | Makes and updates its `CoverField` |
| `who-knows/src/world/blowing_sand.gd` (create) | The streaks, by air, altitude and the world's wind |
| `who-knows/src/world/whereabouts.gd` (modify, only if needed) | Exposes the focus for `BlowingSand` |
| `who-knows/test/unit/test_world_recipe.gd`, `test_world_terrain.gd` (modify) | The desert draw and today's seeds; the dune field |
| `who-knows/test/unit/test_ground_cover.gd`, `test_cover_field.gd`, `test_blowing_sand.gd` (create) | |
| `who-knows/test/unit/test_visual_style_rules.gd` (modify) | `PAINTING_FILES` grows by three |
| `who-knows/test/probes/desert_render.gd` (create) | Checkpoints A and B: renders and frame rates on 1337's `p3` |
| `docs/design/visual-style.md`, the spec, Planetfall, skills (modify) | Task 8 |

---

### Task 1: The desert draw, and today's worlds kept

**Files:**
- Modify: `who-knows/src/world/world_recipe.gd`, `who-knows/src/world/space_palette.gd`
- Test: `who-knows/test/unit/test_world_recipe.gd`

**Interfaces:**
- Produces: `WorldRecipe.Archetype.DUNES` (value 4); `WorldRecipe.DESERT_SHARE := 0.25`; `WorldRecipe.DRAWN_ARCHETYPES := 4`; `func is_desert() -> bool` (true iff `archetype == DUNES`); `SpacePalette.DRAWN_PALETTES := 8`; `SpacePalette.DESERT_PALETTE := 8` (the index of `&"name": &"desert"`); every `WORLDS` entry has `&"boulder"` and `&"grass"`; the desert entry has `&"streak"`.

- [ ] **Step 1: Write the failing tests** in `test_world_recipe.gd`:

```gdscript
func test_today_s_worlds_keep_their_archetype_and_palette():
	for s in range(1, 601):
		var r := WorldRecipe.from_seed(s)
		if r.is_desert():
			continue
		assert_eq(r.archetype, WorldSeed.rng(s, &"terrain").randi_range(0, 3), "seed %d" % s)
		assert_eq(r.palette, WorldSeed.rng(s, &"palette").randi_range(0, 7), "seed %d" % s)

func test_a_quarter_of_planets_with_air_are_deserts():
	var air := 0
	var deserts := 0
	for s in range(1, 2001):
		var r := WorldRecipe.from_seed(s)
		if r.atmosphere == WorldRecipe.Atmosphere.NONE:
			assert_false(r.is_desert())
			continue
		air += 1
		if r.is_desert():
			deserts += 1
			assert_eq(r.palette, SpacePalette.DESERT_PALETTE)
	assert_almost_eq(float(deserts) / air, 0.25, 0.03)

func test_moons_are_never_deserts():
	for s in range(1, 501):
		assert_false(WorldRecipe.from_seed(s, WorldRecipe.Kind.MOON).is_desert())

func test_a_desert_keeps_its_size_relief_gravity_and_air():
	# Find seeds that are deserts, and compare with the draws they would have had.
	var found := 0
	for s in range(1, 400):
		var r := WorldRecipe.from_seed(s)
		if not r.is_desert():
			continue
		found += 1
		var terrain := WorldSeed.rng(s, &"terrain")
		terrain.randi_range(0, 3)
		assert_almost_eq(r.relief_m, minf(r.radius_m * terrain.randf_range(0.01, 0.025), 1200.0), 0.001)
	assert_gt(found, 10)

func test_the_starting_system_has_its_deserts():
	var sr := SystemRecipe.from_seed(1337)
	assert_true(sr.body(&"p3").recipe.is_desert())
	assert_true(sr.body(&"p4").recipe.is_desert())
	assert_false(sr.body(&"p2").recipe.is_desert())

func test_every_palette_has_cover_colours():
	for p in SpacePalette.WORLDS:
		assert_true(p.has(&"boulder") and p.has(&"grass"), String(p[&"name"]))
	assert_true(SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE].has(&"streak"))
```

Change the existing `assert_eq(WorldRecipe.GENERATOR_VERSION, 2)` to 3. `PINNED` and `test_gravity_change_moves_nothing_else` stay as they are: they must still pass.

- [ ] **Step 2: Run to see them fail.** `run_tests.ps1 -gselect=test_world_recipe`. Expected: FAIL (`is_desert` and `DUNES` not defined).

- [ ] **Step 3: Implement.** In `from_seed`, keep every existing draw exactly as it is, with `Archetype.size() - 1` replaced by `DRAWN_ARCHETYPES - 1` and the palette's `WORLDS.size() - 1` by `SpacePalette.DRAWN_PALETTES - 1`. After the atmosphere draw: if `kind == PLANET`, `atmosphere != NONE` and `WorldSeed.rng(seed, &"desert").randf() < DESERT_SHARE`, set `archetype = DUNES` and `palette = SpacePalette.DESERT_PALETTE`. Append `{&"name": &"desert", ...}` to `WORLDS` starting from `sand`'s values, with `streak` a pale warm sand (start `e8d6b0`). Give every entry `boulder` (start: that palette's `rock` lifted toward `ground_high`, about halfway) and `grass` (start: a dry straw, `a89060` on the desert, a muted version of `ground_high` elsewhere: grass is drawn only on deserts in this phase, so the others are placeholders kept for completeness). Correct `WorldRecipe`'s doc comment: the archetype enum now has a member the old draw never reaches. Bump `GENERATOR_VERSION` to 3 with a comment: "3: a quarter of planets with air became deserts (desert world spec §7.4)".

- [ ] **Step 4: Run to see them pass.** `run_tests.ps1 -gselect=test_world_recipe`, then `-gselect=test_system_recipe` and `-gselect=test_visual_style_rules`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: a quarter of planets with air are deserts, drawn apart so today's worlds stay`

---

### Task 2: Dunes, mesas and towers

**Files:**
- Modify: `who-knows/src/world/world_terrain.gd`
- Test: `who-knows/test/unit/test_world_terrain.gd`

**Interfaces:**
- Consumes: `WorldRecipe.Archetype.DUNES`, `is_desert()` (Task 1).
- Produces: `func wind_at(dir: Vector3) -> Vector3` (unit, tangent to the sphere at `dir`, pointing from a dune's windward side to its lee: the direction the dune phase increases; `Vector3.ZERO` unless `DUNES`). `func in_talus(dir: Vector3) -> bool` (true in the tower band and on the low ground within `MESA_EDGE` of a mesa: where boulders gather; false unless `DUNES`). Constants `DUNE_WAVE`, `DUNE_HEIGHT`, `DUNE_LEE`, `DUNE_POLE`, `MESA_FROM`, `MESA_EDGE`, `TOWER_BAND`, `TOWER_WAVE`, `TOWER_RADIUS: Vector2`, `TOWER_SHARE` with call 3–5's values. New noises take sub-seeds `&"wind"`, `&"dunes"` and `&"towers"`; every existing noise keeps its sub-seed.

- [ ] **Step 1: Write the failing tests** in `test_world_terrain.gd` (use `_recipe(seed, WorldRecipe.Archetype.DUNES)`, which already searches seeds for an archetype; pick an open point on dunes by searching directions for `ground_at(d, 0) == &"ground_low"` with `not in_talus(d)` and the continent under `MESA_FROM - MESA_EDGE`):
  - `test_dunes_stay_within_the_relief`: 2,000 random directions, every height within `±relief / 2`.
  - `test_the_windward_side_is_gentler_than_the_lee`: along `wind_at(d)` from an open dune point, sample heights every 2 m over 3 waves (great-circle steps). The mean rising slope is less than half the mean falling slope, and the steepest fall is under `ROCK_SLOPE`.
  - `test_ridges_run_across_the_wind`: from the same point, the height's spread over 200 m along `wind_at` is at least four times its spread over 200 m across it.
  - `test_the_wind_turns_across_the_world`: `wind_at` at 50 open points 2 km or more apart differ, compared after parallel transport (or simply by their angle to the local tangent of the world's wind axis), by a spread of at least 20°.
  - `test_mesas_are_flat_steps_with_rock_risers`: in a region where the continent is above `MESA_FROM + 0.05`, 400 samples fall on at most `TERRACES + 1` distinct heights to within 2 m for at least 80% of them; tops are `ground_high`, and a sampled riser (slope from a 2 m step over 35°) is `rock`.
  - `test_towers_stand_in_the_band_and_nowhere_else`: over a line of samples crossing the band, at least one tower (a 2 m step with rise over 10 m) lies inside the band, and none outside both the band and the mesas.
  - `test_dunes_change_little_between_details`: for a dune chunk key at `depth_max - 3`, the height of `TerrainChunkData`'s grid at a point and the finest grid's at the same direction differ by under `DUNE_HEIGHT * 0.5` for 90% of points (the coarse mesh never invents dunes that aren't there).
  - `test_a_desert_looks_sandy_from_afar`: build `BodyLook.mesh` for a desert body at `FAR_DETAIL` and count face colours: at least 60% are shades of `ground_low` or `dust`.
  - `test_other_worlds_are_untouched`: for one seed of each old archetype, 200 heights and colours equal what `main`'s code gives. Write the expected values from `main` first (a short script, values pasted into the test), then implement.

- [ ] **Step 2: Run to see them fail.** `run_tests.ps1 -gselect=test_world_terrain`. Expected: the new tests FAIL; `test_other_worlds_are_untouched` PASSES already (it pins the old path).

- [ ] **Step 3: Implement** in `world_terrain.gd`. In `height_at`, a `DUNES` branch: the continent layer as today; where it is above `MESA_FROM`, mesa terraces from `_terrace` of the continent and hills as `MESA` does; below, dunes in metres added on top of a gentle base, faded out over `MESA_EDGE` toward the mesa line and over `DUNE_POLE` toward the wind axis's poles; towers inside the band. Clamp the sum to `±relief / 2`. The dune profile, per unit phase `t` in [0, 1): rising as `t / (1 - DUNE_LEE)` to the crest, falling over the last `DUNE_LEE`; eased at the trough and crest so no triangle is a knife edge. Phase = `radius × (d · axis) / DUNE_WAVE + warp(d)`, the warp a 2-octave noise worth up to 1.5 waves. `wind_at` is the normalised tangent gradient of that phase, by central differences 1 m apart. `ground_at` for `DUNES`: rock over `ROCK_SLOPE` and on towers, `ground_high` on mesa tops, `dust` in the lowest fifth of a wave, else `ground_low`. Keep the cost of `height_at` within 2× today's `MESA`: measure 10,000 calls before and after and write both in the commit message.

- [ ] **Step 4: Run to see them pass.** `run_tests.ps1 -gselect=test_world_terrain`, then `-gselect=test_terrain_chunks` and `-gselect=test_whereabouts`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: dunes, mesas and towers: the DUNES archetype`

---

### Task 3: The desert probe, and Checkpoint A (the land)

**Files:**
- Create: `who-knows/test/probes/desert_render.gd`

**Interfaces:**
- Consumes: Task 2's ground; `descent_render.gd`'s and `landing_play.gd`'s ways of placing the starter, landing it, stepping out and timing frames (copy their helpers or call them; don't invent a new harness).
- Produces: `desert_render.gd -- <out dir> [land|cover|all]`, on system 1337's `p3`, on its day side with the sun about 30° up (as `descent_render` finds it). The `land` set, for this task:
  - from orbit at 3 radii (the far mesh), and at the air top;
  - seated at 2 km and 300 m, to the horizon toward and away from the sun;
  - seated low flight at 60 m over the dunes, across the wind and along it, and the frame rate over 10 s at 120 m/s there;
  - landed on open dunes: on foot, eye 1.6 m over the ground, toward the sun, away, across the ridges, at the nearest mesa and at the nearest tower;
  - a contact sheet `desert_sheet.png` with stage 4 of `descent.html` (render the mockup with the built-in browser, or reuse phase 1's `descent_sheet.png` crop) beside the eye-height views.

- [ ] **Step 1: Write the probe** with the views above, each printed with its name, altitude, air, and fps where measured.
- [ ] **Step 2: Run it windowed** (never `--headless`), from `D:/git/whoknows-desert-style/who-knows`: `& $godot --path . -s res://test/probes/desert_render.gd -- <scratchpad>/desert_a land`. Expected: every view written, no errors, the low-flight fps printed.
- [ ] **Step 3: Look at every render yourself first** against style guide §2 and the concept art: faceted, flat colour, no noise; dunes reading as long parallel ridges; mesas with steep risers; far dunes not shimmering at 2 km. Fix what is plainly wrong before showing (dune scale, lee steepness, colours), re-run.
- [ ] **Step 4: Checkpoint A — show the owner.** `SendUserFile` the sheet and the key renders, each named, with the fps line. Ask: do the dunes, mesas and towers read as the desert of the concept art; are the dunes the right size and spacing; is the `desert` palette right (sand, mesa tops, rock, sky); is a quarter of planets with air the right share? **Wait for the owner.** Their changes are made in Task 2's constants and the `desert` palette, re-rendered, and shown again.
- [ ] **Step 5: Commit** the probe and any tuning. `test: desert_render probe; the desert's land tuned at Checkpoint A`

---

### Task 4: Ground cover: boulders and grass, placed

**Files:**
- Create: `who-knows/src/world/ground_cover.gd`
- Modify: `who-knows/src/world/terrain_chunk_data.gd`, `who-knows/test/unit/test_visual_style_rules.gd`
- Test: `who-knows/test/unit/test_ground_cover.gd`, `who-knows/test/unit/test_landing_save.gd`

**Interfaces:**
- Consumes: `WorldTerrain.in_talus`, `ground_at`, the palette's `boulder` and `grass` (Tasks 1–2); `RockMesh.Shape.BOULDER` / `SHARD`, `RockMesh.cut_vertices`, `RockMesh.sphere`, `RockDetail._packed`'s buffer layout (`AsteroidStream.pack`).
- Produces: `class_name GroundCover extends RefCounted` with:
  - `static func scatter(terrain: WorldTerrain, key: Vector4i) -> GroundCover` (key at the world's finest depth; pure, any thread);
  - `var boulders: Array` of `[Transform3D relative to the chunk's centre, shape: int, colour: Color, diameter: float]`, and `var grass: Array` of `[Transform3D relative to the centre, colour: Color]`, where the centre is `TerrainChunkData`'s `centre` for the same key;
  - `func boulder_faces() -> PackedVector3Array` (each boulder's detail-0 hull, wound like `RockDetail`'s, relative to the centre);
  - `static func grass_mesh() -> ArrayMesh` (built once, main thread first: a tuft of 6 blades, thin triangles leaning out from a point, about 1 m tall at scale 1, white vertex colours);
  - constants `BOULDER_SIZE := Vector2(0.5, 4.0)`, `BOULDER_SUNK := 0.33`, `BOULDER_SLOPE := deg_to_rad(30.0)`, `BOULDERS_PER_100M2 := 0.8`, `DESERT_BOULDERS := 0.15`, `BOULDER_TALUS := 3.0`, `GRASS_PER_100M2 := 5.0`, `GRASS_SLOPE := deg_to_rad(15.0)`, `GRASS_CLUMP := 0.35` (the share of ground in a clump), `GRASS_HEIGHT := Vector2(0.3, 0.7)`.
  - `TerrainChunkData.build` appends `GroundCover.scatter(terrain, key).boulder_faces()` to `faces` when `key.y == CubeSphere.depth_for(terrain.radius)`. `positions` (the drawn ground) is unchanged.

- [ ] **Step 1: Write the failing tests** in `test_ground_cover.gd`:
  - `test_the_same_chunk_gives_the_same_cover`: two `scatter` calls on separate `WorldTerrain`s of one recipe, one of them from a `WorkerThreadPool` task, are equal stone for stone and tuft for tuft.
  - `test_neighbours_differ`: two adjacent keys' boulders differ.
  - `test_boulders_sit_on_the_collision_ground`: for every boulder of 30 chunks, cast down its local up through the chunk's own `faces` triangles (the ground part only): the ground point lies between the boulder's lowest and highest vertex, and at least `BOULDER_SUNK × diameter × 0.8` of it is below.
  - `test_sizes_and_slopes`: every diameter within `BOULDER_SIZE`; no boulder or tuft where the ground's triangle is steeper than its limit.
  - `test_grass_only_on_desert_sand`: no tufts on a non-desert world; on a desert, none on `rock` or `ground_high`, some on `ground_low` / `dust` over 50 open chunks.
  - `test_boulders_gather_at_the_talus`: on a desert, boulders per 100 m² over 40 talus chunks is at least five times that over 40 open-dune chunks.
  - `test_density_on_other_worlds`: on a `ROLLING` world, the mean over 100 chunks is within 25% of `BOULDERS_PER_100M2`.
  - `test_colours_come_from_the_palette`: every boulder colour is a `SpacePalette.shade` of the palette's `boulder`; every tuft colour a shade of `grass`.
  - `test_finest_chunks_are_solid_round_their_boulders`: a finest `TerrainChunkData`'s `faces` has `QUADS² × 2 × 3 + boulder_faces().size()` vertices; a coarser one's has only the ground's.

  And in `test_landing_save.gd` (Review Focus 4): `test_restored_landed_off_the_ground_falls_and_settles`: a hull restored landed 3 m above a world's ground leaves `LANDED` and is `LANDED` again on the ground within 10 s of physics; one restored with its keel 1 m below the ground ends above it (the analytic floor) and is not damaged. If it already passes, keep it as a pin and say so in the report.

- [ ] **Step 2: Run to see them fail.** `run_tests.ps1 -gselect=test_ground_cover`. Expected: FAIL (`GroundCover` not defined).

- [ ] **Step 3: Implement `ground_cover.gd`.** The rng: `WorldSeed.sub(recipe.seed, &"cover")` mixed with the key's four numbers through `AsteroidRecipe.mix`. Counts per kind: area of the chunk (`edge_m²` at its depth) × density / 100, its fraction rolled. Each point: a random `(u, v)` inside the key's rect; its ground point is found in the same quad and triangle split `TerrainChunkData` uses (corners from `height_at` at the quad's four corner directions, the triangle `i00-i10-i11` or `i00-i11-i01`), never `height_at` at the point. Slope from that triangle's normal. Boulders take `RockMesh` BOULDER or SHARD, a random turn and the asteroid stretch, colour a random shade of `boulder`. Tufts turn about the local up, scale by `GRASS_HEIGHT`, colour a shade of `grass`; in a clump where a slow noise (sub-seed `&"grass"`) is above `1 - 2 × GRASS_CLUMP`. In `terrain_chunk_data.gd`, append the boulder faces at the finest depth. Add `res://src/world/ground_cover.gd` to `PAINTING_FILES`. Fix the landing monitor or `Fleet`'s landed restore only if the Review Focus test fails, the smallest change that makes it pass.

- [ ] **Step 4: Run to see them pass.** `-gselect=test_ground_cover`, `-gselect=test_terrain_chunks`, `-gselect=test_landing_save`, `-gselect=test_landing_monitor`, `-gselect=test_visual_style_rules`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: ground cover: boulders on every world, dry grass on deserts, boulders solid`

---

### Task 5: Cover drawn round you

**Files:**
- Create: `who-knows/src/world/cover_field.gd`
- Modify: `who-knows/src/world/world_surface.gd`, `who-knows/test/unit/test_visual_style_rules.gd`
- Test: `who-knows/test/unit/test_cover_field.gd`, `who-knows/test/unit/test_floating_origin_scene.gd` (run)

**Interfaces:**
- Consumes: `GroundCover.scatter`, `grass_mesh`, `RockMesh.mesh(shape, 1)` and `RockMesh.warm()`; the asteroid boulders' material (as `AsteroidDetail` gets it) or one built the same way: vertex and instance colours as albedo, roughness 1.
- Produces: `class_name CoverField extends Node3D`, made by `WorldSurface.setup` as its child and stepped from `WorldSurface.update(focus)` after the chunks:
  - `const BLOCK_UP := 2` (a block is a key `BLOCK_UP` levels above the finest), `BOULDER_REACH := 300.0`, `GRASS_REACH := 70.0`, `MAX_JOBS := 4`, `APPLY_BUDGET_USEC` the surface's own;
  - `static func blocks_near(terrain: WorldTerrain, local: Vector3, reach: float) -> Array[Vector4i]` (pure: block keys whose ground lies within `reach` of `local`, nearest first, a focus moving at `v` biased `v × 1 s` ahead like `TerrainCollider.reach_for`);
  - `func update(focus: UniversePoint) -> void` (the focus's velocity is worked out here from the last focus and the time since, because `BodyProxy.place` passes only the point), `func finish() -> void` (tests: wait for every job and apply);
  - `func block_count() -> int`, `func block_keys() -> Array[Vector4i]`;
  - each block: a `Node3D` named `Cover_<f>_<d>_<x>_<y>`, a member of `Universe.EXTERIOR_SPACE`, placed at `universe.to_engine(body.point.plus(centre))`, holding one `MultiMeshInstance3D` per boulder shape (shadows on, `visibility_range_end` `BOULDER_REACH` with a `VISIBILITY_RANGE_FADE_SELF` margin of 40 m) and one for grass (shadows off, cull disabled, `visibility_range_end` `GRASS_REACH`, fade 15 m). The block's buffers are packed on the worker, one assignment each on the main thread.
  - Nothing above `BOULDER_REACH` over the ground: `blocks_near` is empty above it, so at entry heat nothing is built.

- [ ] **Step 1: Write the failing tests** in `test_cover_field.gd` (a `WorldSurface` for 1337's `p3`, set up as `test_terrain_chunks` does):
  - `test_blocks_near_cover_the_reach`: every finest key within `BOULDER_REACH` of a ground point has its block in `blocks_near`, and no block is farther than `BOULDER_REACH + block edge`.
  - `test_blocks_ahead_are_asked_for_first`: with a velocity of 150 m/s, the first quarter of `blocks_near` lies ahead of the focus.
  - `test_nothing_high_up`: at 500 m over the ground, `update` + `finish` gives `block_count() == 0`.
  - `test_cover_is_what_scatter_says`: after `finish`, a block's boulder instance count equals the sum of its 16 finest keys' `scatter(...).boulders.size()`, and one instance's transform equals the scatter's, moved by the block centre.
  - `test_far_blocks_go`: move the focus 1 km along the ground; after `finish`, no block from the first place is left.
  - `test_blocks_follow_a_shift`: a block's engine position plus the universe's shift equals its `UniversePoint` before and after `Universe.shift` (as `test_floating_origin_scene` checks chunks).
  - `test_boulders_are_solid_where_the_ground_is`: an anchor hull 2 m over a finest chunk that has a boulder: once `WorldSurface.update` has run, a ray down onto that boulder's top from 10 m hits `BodyProxy.LAYER` at its top, not the ground under it.

- [ ] **Step 2: Run to see them fail.** `-gselect=test_cover_field`. Expected: FAIL.

- [ ] **Step 3: Implement** `cover_field.gd` after `WorldSurface`'s pattern (jobs keyed by block, a `Mutex` for finished data, applied nearest first within the budget, at least one a tick, far ones freed). Wire it in `world_surface.gd`: made in `setup`, `update(focus)` called at the end of the surface's `update`, `finish` called from `finish`, `_exit_tree` waits for its jobs. Add `cover_field.gd` to `PAINTING_FILES`.

- [ ] **Step 4: Run to see them pass.** `-gselect=test_cover_field`, `-gselect=test_terrain_chunks`, `-gselect=test_floating_origin_scene`, `-gselect=test_visual_style_rules`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: CoverField draws boulders and grass round the focus in blocks`

---

### Task 6: Blowing sand

**Files:**
- Create: `who-knows/src/world/blowing_sand.gd`
- Modify: `who-knows/src/world/star_system.gd` (made beside `SpaceDust`, line 54), and `whereabouts.gd` only if the focus's engine position is not already public; `test_visual_style_rules.gd`
- Test: `who-knows/test/unit/test_blowing_sand.gd`, `who-knows/test/unit/test_floating_origin_scene.gd` (run)

**Interfaces:**
- Consumes: `Whereabouts.well()`, `terrain_of(body)`, `altitude()`, `air()`, `up()`; `WorldTerrain.wind_at` (Task 2); the desert palette's `streak`.
- Produces: `class_name BlowingSand extends GPUParticles3D`:
  - `static func strength(desert: bool, air: float, altitude: float) -> float` (pure): 0 unless `desert` and `air >= SAND_AIR` (0.3); 1 at or below `SAND_LOW` (15 m), 0 at or above `SAND_TOP` (60 m), smooth between; times `inverse_lerp(SAND_AIR, 1.0, air)` eased to at least 0.4 at `SAND_AIR`;
  - `func setup(whereabouts: Whereabouts, universe: Universe) -> void`;
  - each physics tick: `amount_ratio = strength(...)`, `emitting = amount_ratio > 0`; the process material's `emission_shape_offset` set to the focus in this node's local frame, the box (`SAND_BOX` 60 × 6 × 60 m) turned to the local up, and its direction and speed (`SAND_SPEED` 8–14 m/s) along `wind_at`;
  - `local_coords = true`; a member of `Universe.EXTERIOR_SPACE`, **not** `HOLDS_SHIFT`; re-placed onto the focus (and `restart()`ed) only when it is off and starting, or the focus is more than `SAND_RECENTRE` (8 km) from it;
  - the streak: a `QuadMesh` 0.05 × 1.5–3 m, `particle_flag_align_y` along the velocity, an unshaded, transparent, depth-tested `StandardMaterial3D` in `streak` at alpha 0.3, fading in and out over its life by a colour ramp built from that one palette colour, `SAND_AMOUNT` 160, lifetime 1.2–2 s.

- [ ] **Step 1: Write the failing tests** in `test_blowing_sand.gd`:
  - `test_strength`: `strength(false, 1, 0) == 0`; `strength(true, 0.2, 0) == 0`; `strength(true, 1, 0) == 1`; `strength(true, 1, 15) == 1`; `strength(true, 1, 60) == 0`; `0 < strength(true, 1, 35) < 1`; `strength(true, 0.35, 0) >= 0.4`.
  - `test_off_in_space_and_on_other_worlds`: set up in the flight scene with the starter in deep space, then landed on a non-desert world with air: `emitting` is false in both.
  - `test_on_at_the_desert_s_ground`: landed on `p3`, after a tick: emitting, `amount_ratio == 1`, and the process material's direction is `wind_at` there in this node's frame (within 1°).
  - `test_sand_never_holds_the_origin`: emitting on the desert, move the focus 2.1 km along the ground: `Universe` shifts within the next tick (not held to the forced 4 km).
  - `test_streaks_keep_their_place_across_a_shift`: the node's engine position plus the shift equals its universe place before and after a shift, and `emission_shape_offset` is unchanged by the shift.
  - `test_colours_come_from_the_palette`: the material's albedo is the desert palette's `streak` (alpha aside).

- [ ] **Step 2: Run to see them fail.** `-gselect=test_blowing_sand`. Expected: FAIL.

- [ ] **Step 3: Implement** `blowing_sand.gd`, make one in `StarSystem` beside its `SpaceDust`, and add it to `PAINTING_FILES`.

- [ ] **Step 4: Run to see them pass.** `-gselect=test_blowing_sand`, `-gselect=test_space_dust`, `-gselect=test_floating_origin_scene`, `-gselect=test_visual_style_rules`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: blowing sand at a desert's ground`

---

### Task 7: Play the desert, measure it, and Checkpoint B (cover and sand)

**Files:**
- Modify: `who-knows/test/probes/desert_render.gd`, `who-knows/test/probes/landing_play.gd` (run only)

- [ ] **Step 1: Add the `cover` set** to `desert_render.gd`:
  - on foot at eye height among grass on open dunes, toward and away from the sun, with blowing sand (`cover_sand_sun`, `cover_sand_away`), and the same with the sand off by hand (`cover_still`) to judge the streaks;
  - on foot at a mesa's foot among its boulders (`cover_talus`), and at a tower;
  - seated, landed among grass, looking out of the canopy (`cover_seated`), and the frame rate there over 10 s;
  - seated low flight at 30 m and 120 m/s over a talus band (`cover_low`), and the frame rate over 10 s; then the same at the low speed limit (about 150 m/s), checking `CoverField` keeps ahead (print the blocks missing in front each second, and the frames where a block appeared within 100 m in front);
  - **landing in a boulder field** (Review Focus 1): the starter brought down at 2 m/s onto the densest talus spot within 300 m: print the monitor's result (landed, its tilt, or the refusal's text), the damage taken (must be 0), and render it from 25 m at eye height; then the Warden (the heaviest library ship) the same way;
  - the frame rate on foot 6 m off the landed starter among cover.
- [ ] **Step 2: Run it windowed:** `desert_render.gd -- <scratchpad>/desert_b all`, then `landing_play.gd -- <scratchpad>/landing_p2` (on its world, now with boulders on every world) and `test/probes/fleet_play.gd` (CLAUDE.md, after anything that touches the ground the suit walks on). Expected: no errors; every fps line at least **120**; the boulder landing undamaged.
- [ ] **Step 3: If a view is under 120 fps**, cut in this order and re-measure: grass reach (70 → 50 m), boulder reach (300 → 200 m), boulder shadows beyond 100 m (a second instance per shape without shadows), `SAND_AMOUNT`. Record each step's numbers.
- [ ] **Step 4: Checkpoint B — show the owner.** `SendUserFile` the cover renders and the boulder landing, with the fps lines and `landing_play`'s summary. Ask: do the boulders and grass read as the concept art's; is the density right (and the boulder landing acceptable); do the streaks read as blowing sand and not as rain or noise; does each look fit the house style? **Wait for the owner**, tune, re-render, show again.
- [ ] **Step 5: Commit** the probe and tuning. `test: desert cover and sand measured; tuned at Checkpoint B`

---

### Task 8: Style guide, skills and documents

**Files:**
- Modify: `docs/design/visual-style.md` (§2.6, §3.9, §5), `docs/superpowers/specs/2026-11-03-desert-world-design.md` (a phase 2 status block like phase 1's), `docs/superpowers/specs/2026-09-23-planetfall-design.md` (boulders marked built), `.claude/skills/building-a-ship/` (checklist, *Mistakes already made*, `reference.md`), `.claude/skills/designing-a-ship/` (checklist), `.claude/skills/building-an-npc/reference.md`

- [ ] **Step 1: Style guide.** §3.9 gains *The desert* (the `DUNES` archetype, the desert palette and its keys, dunes, mesas and towers, colours by `ground_at`) and *Ground cover* (boulders on every world, grass on deserts, blocks and reaches, blowing sand by air and altitude, sand in `EXTERIOR_SPACE` and never `HOLDS_SHIFT`, no sway, no shader). §2.6 gets Task 7's numbers. §5 names the three new `PAINTING_FILES`. Only what the owner approved at Checkpoints A and B is written as a rule.
- [ ] **Step 2: The spec.** A *Status: phase 2 is built* block: the differences as built (at least: deserts are 0.25 of planets with air; a desert palette, not `sand`; boulders on every world; the sand is not in `HOLDS_SHIFT`, and why; `GENERATOR_VERSION` 3 and which seeds changed; anything tuned at the checkpoints), the measured numbers, and *Open for phase 3* (the pad and stamps must keep cover clear: `GroundCover.scatter` needs to ask the stamps; the oasis's grass and palms; anything left over).
- [ ] **Step 3: Skills.** `building-a-ship`: a landing checklist line, "a ship must land, or refuse with *UNEVEN GROUND*, on a boulder field: run `desert_render.gd -- <out> cover`"; *Mistakes already made*: an always-on emitter in `HOLDS_SHIFT` holds the origin back (the hover puff, again for the sand); `reference.md`: boulders are on `BodyProxy.LAYER` inside the finest chunks' collision, `BOULDER_SIZE`, `BOULDER_REACH`. `designing-a-ship`: legs must stand on boulders up to 4 m. `building-an-npc` `reference.md`: worlds have solid boulders and non-solid grass; a world creature (the beast) walks among them. Fix any name in the skills that no longer exists.
- [ ] **Step 4: Ask the owner** whether to run the full suite before merging, and report the targeted runs so far.
- [ ] **Step 5: Commit.** `docs: phase 2 in the style guide, the spec and the skills`

---

## Spec coverage

| Spec | Task |
|---|---|
| §7.1 the look | 2, 4, 6; Checkpoints A (3) and B (7) |
| §7.2 `DUNES`: ridges one way, turning; mesas; towers | 2 |
| §7.2 colour by `ground_at`; the sand palette retuned | 1 (desert palette), 2, 3 |
| §7.2 the far mesh shows it | 2 (`test_a_desert_looks_sandy_from_afar`), 3 (orbit view) |
| §7.3 boulders and grass, from the chunk's sub-seed, on workers; boulders solid, grass not | 4, 5 |
| §7.3 boulders count for landing | 4 (collision), 7 (the boulder landing) |
| §7.3 blowing sand; floating origin | 6 (ruling: `EXTERIOR_SPACE`, not `HOLDS_SHIFT`) |
| §7.3 colours in the palette; the style test grows | 1, 4, 5, 6 |
| §7.3 the pad kept clear | phase 3 (needs its stamps); noted in Task 8 |
| §7.4 the `&"desert"` sub-seed; today's seeds pinned; `GENERATOR_VERSION` | 1 |
| §5.6 boulders folded in | 4 |
| §9 style guide; §10 renders, budget, tests; §11 skills and documents | 3, 7, 8 |
