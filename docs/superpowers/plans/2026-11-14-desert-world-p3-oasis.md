# Desert World, Phase 3: Hand-Made Worlds and the Oasis — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A star system can carry hand-made designs on top of its seed. The first one turns 1337's `p3` into the desert world. It gets an abandoned oasis village that you find by its beacon and land beside on a packed-stone pad. You can wade in its pool and walk through its huts, palms, gardens, broken wall and the beast's tracks. You can enter four of its buildings, take what the settlers left, and read their last log. Taken stays taken across saves.

**Architecture:** A `SystemDesign` (JSON in `data/systems/`) is applied inside `SystemRecipe.from_seed`. It changes recipe fields (the *tweak*) and puts `TerrainStamp`s on a `WorldRecipe`. `WorldTerrain.height_at` and `ground_at` blend the stamps in, so the far mesh, chunks, collision, landing and the speed limit all see them, and `GroundCover` keeps clear of them. A pinned place (`PlaceDesign`, its layout in `data/places/`) is drawn by a `PlaceField` under Outside: one member of `Universe.EXTERIOR_SPACE` per loaded place, holding its pieces (palms, water, shells, wall, tracks, outcrop, gardens) and its loose items. The enterable buildings are **bases**: `BaseSite`s with new building module kinds, made from the layout once, then woken, slept and saved by `Bases` as any base is. Their airlock is a plain doorway. A `PlaceContacts` sensor source shows the beacon, and a `WarpTarget` can name the side a warp arrives on.

**Tech Stack:** Godot 4.5.1, GDScript, GUT. Tests run with `who-knows/run_tests.ps1 -gselect=<test file without .gd>`.

**Spec:** `docs/superpowers/specs/2026-11-03-desert-world-design.md`. The scope is §8 (phase 3), with §3 (anti-goals), §9 (style guide), §10 (verification), §11 (upkeep), §12 and §14. Also read the phase 0–2 status blocks at the top, with their *Notes for phase 3* and *Open for phase 3*. Star systems spec `2026-09-27-star-systems-design.md` §9 is what Part A builds. The habitat modules spec §9.1 is what the buildings are. Pictures: `2026-11-03-desert-world/oasis-layout.html` (the oasis, approved) and `beast-concept.webp` (the land). Read `docs/design/visual-style.md` §2, §3.8, §3.9 and §4 before any visual task.

**Work in:** `D:/git/whoknows-desert-oasis`, branch `desert-oasis`, made from `main` at `2226305`. Its `.godot` cache is already imported. Never switch a branch or commit in `D:/git/whoknows`.

**Three parts, three checkpoints.** Part A (Tasks 1–7) covers the authored world, the ground at the oasis, the beacon and the arrival; it ends at Checkpoint A. Part B (Tasks 8–11) is the village outside; it ends at Checkpoint B. Part C (Tasks 12–17) covers the buildings you enter, the things to find and the log; it ends at Checkpoint C. Task 18 updates the documents. Each part can be flown on its own. Don't start a part before the owner has seen the last checkpoint's renders.

## Global Constraints

- **Targeted tests only:** run `run_tests.ps1 -gselect=<file>` for the files a task touches. Never run the full suite; the owner is asked at the end (Task 18).
- **Today's worlds stay the same** (spec §3, §7.4). A world with no stamps keeps its `height_at`, `ground_at` and cover **bit for bit**, and `p3` does too beyond its stamps' outer reach. Every body other than `p3` in 1337, and every seed with no design, is untouched. `SystemRecipe.VERSION` and `WorldRecipe.GENERATOR_VERSION` do not change.
- **One ground.** Stamps live only in `WorldTerrain.height_at` / `ground_at`. Nothing else flattens or digs the ground. Pieces of a place sit on the ground `height_at` gives, never on numbers of their own.
- **The design is data and is never saved** (spec §8.6). A save keeps only what changed: items taken, items dropped, bases' contents. A save made before phase 3 loads, and the oasis appears fresh in it.
- **The floating origin** (CLAUDE.md): each loaded place is one node in `Universe.EXTERIOR_SPACE`, placed from its `UniversePoint`, and its pieces and loose items are its children, never members themselves. Buildings are bases: their exterior is already a member. `test_floating_origin_scene.gd` passes with the oasis loaded and a ship landed on the pad (Tasks 6, 9 and 13).
- **Every ship is usable** (CLAUDE.md): the buildings are bases, never ships, and never in `Fleet`. That is the exception bases already have (spec §8.4).
- **Colours come only from the palettes** (style guide §2.2). A new `OasisPalette` (`src/world/oasis_palette.gd`) holds the oasis's outside colours: water, palms, green grass, gardens, the brick skin, the weathered prefab plate, sails and tracks. New interior colours go in `InteriorPalette`. The desert palette (`SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE]`) gains `&"pad"` and `&"damp"`. Every new painting file joins `PAINTING_FILES`. Spec §9 approved the palette list growing. CLAUDE.md's palette line is updated in Task 18.
- **No new shader**, inside or out (style guide §2.5, §3.9). Engine materials only. Brick and the weathered prefab plate are copies of the hull's livery material (`GridHome.livery`) with other parameter values.
- **No `#` comments inside `.tscn`/`.tres` blocks** (CLAUDE.md). The new room blocks copy `data/blocks/galley.tres` exactly, with no comments, and a test reads their values back at runtime.
- **Frame budget:** at least **80 fps at 1280 × 720 on the GTX 960** (120 until the owner lowered it on 2026-11-16), measured with the windowed probe. The worst views are expected to be seated on the pad looking across the oasis (the canopy view draws everything twice) and inside a building with the doorway's daylight. Phase 2 measured 136 seated landed on open dunes.
- **Interior rules hold in buildings:** render layer 2, no interior shadows, one light per cell and the doorway clearance (style guide §5; their tests run in Task 14).
- **Skills and documents are updated in the same branch** (CLAUDE.md, spec §11) in Task 18. `fleet_play.gd` runs after the airlock change (Task 13).
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Merging and pushing need the owner.

## Calls made in this plan (mine; the owner can change any)

1. **The desert world is `p3`** (DRANAXNAX-50): 54.6 km across, thick air, already a desert, gravity **5.28 m/s²** (the spec's "about 5"), and the nearest planet to the entry (1,312 km). It is phase 2's probe desert. The tweak pins `archetype` DUNES, `palette` desert and `atmosphere` THICK at the values it already rolls, so it stays a desert if a generator changes. Its gravity, size and name stay the seed's. **The owner named it WADIS** at Checkpoint A (2026-11-14, spec §14.9).
2. **Designs are JSON**: `data/systems/<star name, lower case>.json`, keyed inside by `"seed"`, beside the ship library's JSON. Place layouts go in `data/places/<id>.json`, and logs in `data/logs/<id>.json`. JSON has no `.tres` comment trap.
3. **Latitude and longitude** on a world are in the universe's axes, since worlds never turn: north is +y, longitude 0 is +x, east is toward −z at longitude 0. `dir = (cos φ cos λ, sin φ, −cos φ sin λ)`. A place's frame has x east, y up and z south, so layout `[east, north]` metres are `Vector3(e, h, −n)`. Its `heading` turns the layout clockwise about up.
4. **Stamps nest or keep apart:** two stamps on a body either don't touch (with their blend edges) or one lies wholly inside the other's flat part. They apply in file order, outer first. A FLATTEN with no `level` takes the mean of the ground already stamped under its flat part (37 samples). Every stamp clears ground cover within its flat radius plus `TerrainStamp.CLEAR_MARGIN` (2 m).
5. **The oasis's ground:** an *oasis floor* FLATTEN of radius **120 m** with a **150 m** blend (about 8° at worst against 40 m dunes); the **pad**, a FLATTEN of radius **26 m** (the Warden's half-diagonal of 20.1 m plus 6 m), raised **0.15 m**, its edge **4 m**, ground `pad`; the **pool**, a BASIN of radius **17 m** with a flat floor out to **9 m**, **1.3 m** deep, ground `damp`. The water stands **0.3 m** below the oasis floor, so the pool is about 29 m across, about knee-deep (0.5 m) 2 m in from the edge and 1.0 m (waist) at the middle.
   Checkpoint A: the floor keeps 0.35 of the dunes' roll (`keep`); the pool sits on its own level bank (r 24 then; Rework 1, round 2 made it r 54.3, and Rework 2 lets it keep 0.2 of the roll with a level shore, `pool_shore`, r 17.4, round the water); every later piece that needs level ground (gardens, pump, buildings, the crushed hut) gets its own nested FLATTEN in kesdra.json.
6. **Where the oasis is:** found in Task 4 by a probe. It scans the circle of points where the sun stands **30°** up, keeps those whose 400 m disc has no mesa, tower or talus and which lie off the wind axis's poles, and takes the one nearest the side you come from out of the entry. The latitude and longitude are rounded to 0.01° in the data. The test holds the sun between 25° and 35°.
7. **The layout** follows `oasis-layout.html`, read at 0.3 m to a pixel, with the pool at the origin and north up, as reworked at Checkpoint B (below). The pad grew to fit the Warden, so it moved west. All positions are `[east, north]` m; sizes are [across, high, deep] m; a yaw ψ turns a shell's front (its door) to face bearing ψ:
   - pad (−80, −40); a path from the pad's edge (−56.8, −28.4) through the gate (−42.2, −22.5) to (−15.2, −7.6) by the pool, flat stones the last stretch;
   - pool (0, 0) on its bank (FLATTEN r 54.3, edge 4.2, keep 0.2: the town floor keeps a gentle roll, with the level `pool_shore` round the water so no ground in the green ring lies below the water + 0.1 m), with a green ring out to 36 × 26 m;
   - ten palms: (−20.4, 12), (−24, −3), (−15, −16.5), (18, 9.6), (23.4, 0.6), (0, 21.6), (9, −17.4), (−33, 27), (3, −41) and (−30.5, −32.5);
   - twelve buildings in five compounds round the pool, each compound on one FLATTEN (the cluster plus an apron, edge 1.0) nested in the bank's flat part, buildings within a compound 0.3–2 m apart, and 3 m or more between compounds. Yard walls 1.8 m high (`yards`, built with `BrickShell.wall`) close each compound's sides, so a lane's sides are walls rather than sand:

     | compound (stamp, centre, r) | id | kind | centre | size | yaw |
     |---|---|---|---|---|---|
     | north (`court_north`, (0.7, 38.0), 14.0) | `workshop` | box, enterable (Part C) | (0.5, 31.4) | 10.8 × 3.4 × 6.4 | −179 |
     | | `house_b` | box, two storeys | (−8.0, 38.5) | 7.5 × 5.6 × 6.0 | −179 |
     | | `hut_b` | round | (9.8, 35.9) | r 3.6 | −165 |
     | east (`court_east`, (29.0, 26.4), 11.9) | `store` | box, long and low | (28.2, 31.3) | 11.0 × 2.9 × 4.6, 2.4 m double door | −138 |
     | | `house_a` | box | (31.9, 20.7) | 8.0 × 3.0 × 5.5 | −123 |
     | crushed (`court_crushed`, (26.5, −25.7), 8.6) | `hut_8` | crushed | (30.2, −24.4) | 7.0 × 3.2 × 5.5 | 70 |
     | | `hut_9` | crushed | (23.8, −27.8) | 6.5 × 3.0 × 5.0 | 95 |
     | south (`court_south`, (2.2, −35.0), 14.8) | `comms` | box, enterable (Part C) | (2.3, −32.9) | 8.0 × 3.2 × 4.4 | −4 |
     | | `home_5` | round | (10.8, −37.7) | r 4.8 | −16 |
     | | `home_4` | box, enterable (Part C) | (−7.4, −32.2) | 6.9 × 3.2 × 4.9 | 13 |
     | west (`court_west`, (−37.8, 14.0), 9.7) | `home_3` | box, enterable (Part C) | (−37.8, 9.4) | 6.9 × 3.2 × 4.9 | 104 |
     | | `house_d` | box | (−37.7, 18.4) | 7.0 × 3.0 × 5.0 | 116 |

     Each shell names its compound's stamp (`"stamp"`). The four Part C buildings stand as plain brick shells with `"enterable": true` until Task 13 makes them bases on the same ground; their doors open on a lane;
   - a ring wall 2.6 m high hugging the village, 15 corners at 45.5–49 m (mean 46.9), with four buildings backing onto it; its gate (4.5 m clear between two piers 1.6 m thick and 4.0 m high) at (−42.2, −22.5), facing the pad; its breach, 8.5 m wide, at (46.4, −11.2) in the east (bearing 103.5), with rubble inside at (42.6, −10.1) and outside at (50.8, −12.3);
   - the tracks out from (62.0, −2.2), past the bank's lip (no print lies across a stamp's lip), bearing **60°** for **375 m**, and in from (42.7, −10.0) at bearing 215 for 12.5 m to the crushed huts;
   - the ledge, a MESA at (−12.2, 87.1) north outside the wall: a long shelf, its flat top an ellipse 40 × 16 m (radius 20, `stretch` 2.5) with its long axis at `heading` 82°, its edge wandering by `wobble` 0.08, 6 m over the floor, falling over a 5.5 m edge (about 47°, rock by the slope rule), ground `ground_high`;
   - gardens on their own stamps (r 3.5, edge 1.2) at (−42.1, −5.9), (−20.4, 36.1) and (44.5, 1.6), the last dried and nearest the breach;
   - the pump at (17, 1.2);
   - shade sails at (−19.5, −33.8), (−33.6, 23.5) and (42.7, 10.6);
   - things lying outside: a crate by the crushed hut at (34.0, −23.0), a canister by the path inside the gate at (−39.5, −19.2).

   Rework at Checkpoint B, 2026-11-14: the owner rejected the village: huts built into the sand with no floors, too few buildings, a wall that did not surround the settlement, the grass ending abruptly and the rock outcrop out of place. Rework 1 replaced the layout above: twelve buildings (was four shells and four sites) each on its own level ground, a whole ring wall with a gate facing the pad and a breach the beast came through (was two runs and a gap), the outcrop replaced by a sandstone ledge, a new MESA stamp, and (round 2) the pool bank grown to r 54.3 so the five compounds' stamps nest inside it, the narrowest lane between them 3.1 m (round 1 had shrunk the bank to r 20 and kept the lanes 6–10 m; round 2 superseded both). Rework 2 does the looks (foundations, floors, doors, the grass's edge, the ledge's dressing) and rolls the town floor: `pool_bank` keeps 0.2 of the floor's roll, and a nested level `pool_shore` (r 17.4, keep 0, 0.05 m under the mean of the bank beneath it) holds the green at least 0.1 m over the water; every stamp margin stays at least 0.3 m.

   Rework 1, round 2, 2026-11-15: the buildings read as scattered houses in open sand, the wall stood far off, hollows in the green lay under the water and the ledge was a round plug. The twelve buildings were grouped into five compounds, each on one FLATTEN, with yard walls between them (house_c went and house_d came, so twelve still stand); the ring wall came in from 52–57.5 m to a mean of 46.9 m; the bank grew to r 54.3 with keep 0, so nothing in the green lies below the water + 0.1 m (test_place_field holds it); and MESA gained an elliptical, wobbled footprint (`stretch`, `heading`, `wobble`) for a long ledge. Round stamps are unchanged bit for bit.
8. **The beacon reads `OASIS`** and shows inside `p3`'s well (spec §8.2), kind `&"beacon"`. A warp to `p3` arrives over the oasis, turned toward your side of the world by at most **75°** and never past the limb seen from where you start (5° spare), so it never routes through the world.
9. **Buildings are base sites with building module kinds:** `home_a` and `home_b` (3 × 2 cells), `workshop` (4 × 3) and `comms` (3 × 2), each with one storey of rooms and a roof storey of grav plating. Homes look like **mud brick** (a new `brick` look in `BaseExterior`, with a cloth sail). The workshop and comms hut are **prefabs**: today's drum shell in a weathered plate, patched with brick. Their legs are none, and each floor sits **0.3 m** over the ground at the door, on its foundation, with a 0.15 m threshold as the middle step (two steps of 0.15 m), so no ramp is built (the controller's ruling at the Checkpoint B rework; it was 0.15 m).
10. **The door is the airlock in doorway mode:** both hatches open, no cycle, no pressure, no panels, no steam. The threshold code hands you over as the outer hatch does today. It applies to every airlock of a base on a world.
11. **Outside items** carry string ids in the layout. `PlaceField` keeps the taken ids per place and saves them in a new save part, `"places"`. **Inside items** go into each building's `BaseSite.items` when the site is first made, so they save and stay taken as any base's items do.
12. **The tracks are flat, darker prints**, laid on the ground's own triangles: each an oval **2.4 m** long with three toe notches, a 7 m stride, four feet. They fade along the 400 m into the dunes. Their size is tuned at Checkpoint B to read from the seat coming in.
13. **The outcrop is hand-placed `RockMesh` stones** (6–12 m) in the world's `boulder` shades, with smaller stones as steps that rise at most 0.7 m (a jump peaks at 0.89 m) to a lookout about 8 m up. *Rework at Checkpoint B, 2026-11-14: replaced by the ledge, a MESA stamp (call 7); `OasisLooks.outcrop` is gone.*
14. **Water is one flat, faceted, opaque disc** in `OasisPalette.WATER` at the water level, plus an `Area3D` that slows you as you wade: `Avatar.wade_factor(depth)` goes from 1 to **0.55** at 1 m deep. No swimming; it is never deeper than you can stand.
15. **Abandoned, not cold:**
    - about half the room props are knocked over;
    - sand drifts lie along the walls and in from the door;
    - a third of the practicals are dead and a third flicker;
    - the inner door is jammed part open;
    - a warm daylight spot shines in at the doorway;
    - wind is heard faintly through the walls (`WindSound.Ear.WALLS`, the deferred §6.4 line).
16. **The log** is `data/logs/oasis_last.json`, with spec §8.7's draft text verbatim. A datapad whose use state names a log opens `LogPanel` when used, and ESC closes it.
17. **No save `FORMAT` bump:** the new part and the new `BaseSite.world` key are optional, with defaults, and a pre-phase-3 save is pinned by a test.

**Not in phase 3:**
- the beast, people in the village, and the ocean world;
- planting bases on a world;
- the system overview scene (star systems §9.4) and hand-built worlds (§9.2's third depth);
- tweaks to rings and moons;
- grass that sways, and wind direction in the wind sound;
- the low, fast flight follow-up (spec phase 2 *Open for phase 3*: M2, M8, one shared apply budget, the gate's hitch). It is its own branch;
- the dither's stipple on the farthest stones.

## Review Focus

These are the five most likely to bite a player that the spec implies and no task's main tests exercise. Each has its test in the task named.

1. **Landing at the oasis.** The Warden, the heaviest and longest ship, sets down on the pad level (tilt under 2°) with no damage. A ship set down off the pad, across the floor's blend or on a palm or the crushed hut, lands tilted or refuses with *UNEVEN GROUND*. It never sticks, crashes or is hurt by a 2 m/s touchdown. Covered by Task 4 (`test_every_library_ship_fits_the_pad`) and Task 11 (the probe's landings, measured).
2. **Carrying things through a door.** A ration tin carried out of home 3 and dropped outside becomes a stray. One carried into home 4 becomes home 4's, and saving keeps both. Going in and out with something in your hand never drops it or doubles it. Covered by Task 15 (`test_carry_an_item_out_and_back_in`).
3. **A floating-origin shift at the oasis:** while standing in the pool, while inside a building, and with items lying on the ground. Nothing jumps, nothing falls through, and the water's slowing still applies. Covered by Task 6 (`test_place_follows_a_shift`, `test_wading_survives_a_shift`) and Task 10 (`test_items_stay_on_the_ground_across_a_shift`).
4. **A save from before phase 3 with a ship landed where the oasis floor now is.** The ground there moved up to 20 m. A ship that is now buried is lifted, and one now hanging falls and lands; both are undamaged. The oasis appears with nothing taken. Covered by Task 4 (`test_a_ship_saved_where_the_floor_moved_settles`) and Task 15 (`test_a_save_from_before_phase_3_loads`).
5. **Warping to `p3` from its far side or from close in.** The arrival never routes through the world, and the beacon shows only inside the well. Covered by Task 5 (`test_arrival_never_crosses_the_world`, `test_beacon_only_inside_the_well`).

---

## File Structure

| File | What it does |
|---|---|
| `who-knows/src/world/terrain_stamp.gd` (create) | One stamp as data, and its pure maths: weight, depth, whether it clears cover |
| `who-knows/src/world/world_recipe.gd` (modify) | `stamps: Array[TerrainStamp]` |
| `who-knows/src/world/world_terrain.gd` (modify) | Stamps in `height_at` and `ground_at`; `base_height_at`, `stamp_clear` |
| `who-knows/src/world/ground_cover.gd` (modify) | Drops cover in a stamp's clear reach, after every draw |
| `who-knows/src/world/space_palette.gd` (modify) | The desert palette's `pad` and `damp` |
| `who-knows/src/world/system_design.gd`, `place_design.gd` (create) | Designs loaded from JSON, applied, validated; places and their layouts |
| `who-knows/src/world/system_recipe.gd` (modify) | Applies the design in `from_seed`; `places()`; arrival sides on targets |
| `who-knows/src/world/warp_target.gd`, `src/flight/warp_plan.gd` (modify) | `arrive` and the clamped drop point |
| `who-knows/src/sensors/place_contacts.gd` (create) | The beacon as a sensor contact |
| `who-knows/src/ui/hud_palette.gd`, `src/ship/computer/map_page.gd` (modify) | The beacon's colour; you can set a course to it |
| `who-knows/src/world/place_field.gd` (create) | Loads and frees places round the focus; their pieces, loose items and ledger; makes building sites |
| `who-knows/src/world/oasis_palette.gd` (create) | The oasis's outside colours |
| `who-knows/src/world/oasis_looks.gd` (create) | Water, palms, the green ring, gardens, the pump, the path, tracks, rubble, the outcrop, sails: each from a kit and a frame |
| `who-knows/src/world/brick_shell.gd` (create) | The mud-brick box and round shells, whole or crushed, and brick patches; used by `OasisLooks` and `BaseExterior` |
| `who-knows/src/avatar/avatar.gd` (modify) | `wade_depth`, `wade_factor` |
| `who-knows/src/habitat/module_definition.gd`, `module_catalog.gd` (modify) | `look`, `legs`; the four building kinds |
| `who-knows/src/habitat/base_site.gd`, `base.gd`, `base_exterior.gd`, `bases.gd` (modify) | `world`; on a world; the brick and prefab looks; `add_site` |
| `who-knows/src/ship/airlock/airlock_cycle.gd`, `airlock.gd`, `src/ship/grid_home.gd` (modify) | Doorway mode |
| `who-knows/data/blocks/home_room.tres`, `workshop_room.tres`, `comms_room.tres` (create) | The new room blocks |
| `who-knows/src/ship/interior/*` (modify) | The new rooms' props; the abandoned mood |
| `who-knows/src/audio/wind_sound.gd` (modify) | `Ear.WALLS` |
| `who-knows/src/items/datapad.gd`, `datapad_logs.gd` (modify, create) | Datapads that carry a log |
| `who-knows/src/ui/log_panel.gd` (create) | The log read on screen |
| `who-knows/scenes/flight_test.gd` (modify) | Wires the field, contacts, sites, the panel and the save part |
| `who-knows/data/systems/kesdra.json`, `data/places/oasis.json`, `data/logs/oasis_last.json` (create) | The design, the layout, the log |
| `who-knows/test/unit/test_terrain_stamps.gd`, `test_system_design.gd`, `test_desert_world.gd`, `test_place_contacts.gd`, `test_place_field.gd`, `test_oasis_looks.gd`, `test_brick_shell.gd`, `test_placed_items.gd`, `test_buildings.gd`, `test_datapad_log.gd` (create) | |
| `who-knows/test/unit/test_ground_cover.gd`, `test_warp_plan.gd`, `test_avatar_field.gd`, `test_module_catalog.gd`, `test_airlock_cycle.gd`, `test_interior_dressing.gd`, `test_wind_sound.gd`, `test_save_bases.gd`, `test_landing_save.gd`, `test_visual_style_rules.gd` (modify) | |
| `who-knows/test/probes/oasis_render.gd` (create) | Checkpoints A, B and C: renders and frame rates |
| Docs and skills (modify) | Task 18 |

---

## Part A: the authored world

### Task 1: Stamps in the ground

**Files:**
- Create: `who-knows/src/world/terrain_stamp.gd`
- Modify: `who-knows/src/world/world_recipe.gd`, `who-knows/src/world/world_terrain.gd`, `who-knows/src/world/space_palette.gd`
- Test: `who-knows/test/unit/test_terrain_stamps.gd`

**Interfaces:**
- Produces: `class_name TerrainStamp extends RefCounted`:
  - `enum Kind { FLATTEN, BASIN }`, `const CLEAR_MARGIN := 2.0`;
  - `var id: StringName`, `kind: Kind`, `centre: Vector3` (a unit direction from the world's centre), `radius: float` (m, the flat part, or the basin's rim), `edge: float` (m, FLATTEN's blend), `level := NAN` (m above `radius_m`; FLATTEN), `raise := 0.0` (FLATTEN), `floor_radius := 0.0` and `depth := 0.0` (BASIN), `ground: StringName = &""` (a palette key, or none);
  - `func metres_from(dir: Vector3, world_radius: float) -> float` (great-circle);
  - `func reach() -> float` (radius + edge for FLATTEN, radius for BASIN);
  - `func weight(m: float) -> float` (FLATTEN: 1 within `radius`, `1 − smoothstep(radius, radius + edge, m)` beyond);
  - `func dig(m: float) -> float` (BASIN: `depth` within `floor_radius`, `depth × (1 − smoothstep(floor_radius, radius, m))` to the rim, 0 beyond).
- Produces: `WorldRecipe.stamps: Array[TerrainStamp]` (empty by default, filled only by a design). `WorldTerrain`:
  - `func base_height_at(dir) -> float` (today's `height_at`, untouched);
  - `height_at(dir)` = the base with each stamp applied in order (FLATTEN: `lerpf(h, level + raise, weight)`; BASIN: `h − dig`);
  - `func stamp_clear(dir: Vector3) -> bool` (inside some stamp's `radius + CLEAR_MARGIN`);
  - `ground_at(dir, slope)` returns the innermost stamp's `ground` within its `radius` when it is set, before the archetype's rules, and steepness still wins (`rock` over `ROCK_SLOPE`).
- Produces: `SpacePalette.WORLDS[DESERT_PALETTE]` gains `&"pad"` (packed stone, start `b09a7e`) and `&"damp"` (wet sand, start `7a5a3c`). Retuned at Checkpoint A only.

- [ ] **Step 1: Write the failing tests** in `test_terrain_stamps.gd`. Build stamps by hand on a fresh `p3` recipe (`WorldRecipe.from_seed(SystemRecipe.from_seed(1337).body(&"p3").seed)`, so the system's own is untouched; there are no designs yet):
  - `test_no_stamps_no_change`: on one seed of each archetype, 500 random directions give `height_at == base_height_at` exactly and identical `ground_at`.
  - `test_a_flatten_is_flat`: a FLATTEN of radius 120 m and edge 150 m on dunes. Within 120 m, 200 samples lie within 0.01 m of one level. That level is within 1 m of the mean of `base_height_at` over the disc. Beyond `reach()` the heights equal `base_height_at` exactly.
  - `test_a_flatten_blends_smoothly`: along 5 rays out from the centre, no 2 m step in the blend is steeper than 12°.
  - `test_a_raised_flatten_stands_proud`: a pad FLATTEN nested in the floor, `raise` 0.15, stands 0.15 m (±0.001) above the floor at its centre.
  - `test_a_basin_dips`: a BASIN (rim 17, floor 9, depth 1.3) inside the floor. Its centre is 1.3 m under the floor (±0.001). At 12.4 m from the centre it is 0.75–0.85 m under. At 17 m and beyond it is at the floor.
  - `test_stamp_ground`: the pad's flat part answers `&"pad"`, the basin `&"damp"`, and a 40° slope inside the pad still `&"rock"`.
  - `test_stamp_clear`: true within `radius + CLEAR_MARGIN` of any stamp, false outside every stamp.
  - `test_level_is_the_same_on_every_thread`: two `WorldTerrain`s of the same recipe, one built in a `WorkerThreadPool` task, give the same FLATTEN levels and heights.
  - `test_the_desert_palette_has_pad_and_damp`.

- [ ] **Step 2: Run to see them fail.** `run_tests.ps1 -gselect=test_terrain_stamps`. Expected: FAIL (`TerrainStamp` not defined).

- [ ] **Step 3: Implement.** `WorldTerrain._init` takes the recipe's stamps and fills each FLATTEN's `level` when it is `NAN`. It uses the mean of `height_at` with the stamps before it applied, over 37 points: the centre, and 12 points each on rings at a third, two thirds and all of `radius`. The values go into the terrain's own copies, never the recipe's, so the recipe stays read-only for other threads. Rename today's `height_at` body to `base_height_at`. The new `height_at` returns at once when there are no stamps. Each stamp first rejects by the dot product against the cosine of its reach (kept per stamp), so a world with stamps pays one dot product per stamp away from them. Measure 10,000 `height_at` calls on `p3` with no stamps and with three, before and after, and write all four numbers in the commit message.

- [ ] **Step 4: Run to see them pass.** Run `-gselect=test_terrain_stamps`, then `-gselect=test_world_terrain`, `-gselect=test_terrain_chunks` and `-gselect=test_world_recipe`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: terrain stamps: a flattened disc and a basin, blended into height_at`

---

### Task 2: Ground cover keeps clear of stamps

**Files:**
- Modify: `who-knows/src/world/ground_cover.gd`
- Test: `who-knows/test/unit/test_ground_cover.gd`

**Interfaces:**
- Consumes: `WorldTerrain.stamp_clear(dir)` (Task 1).
- Produces: `GroundCover.scatter` draws every boulder and tuft exactly as today, then drops those whose direction is `stamp_clear`. The rng sequence never changes, so a chunk away from every stamp keeps every stone.

- [ ] **Step 1: Write the failing tests** in `test_ground_cover.gd`:
  - `test_no_cover_on_a_stamp`: on `p3` with a 120 m FLATTEN on a talus band (find one with `in_talus`), no boulder or tuft of any finest chunk inside lies within the flat radius plus `CLEAR_MARGIN`.
  - `test_cover_beside_a_stamp_is_unchanged`: a finest chunk whose every corner is beyond the stamp's reach plus 50 m has the same `scatter` with the stamp as without, stone for stone.
  - `test_a_cleared_chunk_is_solid_only_where_stones_are`: a finest `TerrainChunkData` inside the stamp has `faces` of the ground only.

- [ ] **Step 2: Run to see them fail.** `-gselect=test_ground_cover`. Expected: FAIL on the first and third.

- [ ] **Step 3: Implement** the filter at the end of `_boulders` and `_grass`, after every draw.

- [ ] **Step 4: Run to see them pass.** `-gselect=test_ground_cover`, `-gselect=test_cover_field`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: ground cover keeps clear of stamps`

---

### Task 3: System designs

**Files:**
- Create: `who-knows/src/world/system_design.gd`, `who-knows/src/world/place_design.gd`, `who-knows/data/systems/kesdra.json`
- Modify: `who-knows/src/world/system_recipe.gd`
- Test: `who-knows/test/unit/test_system_design.gd`, `who-knows/test/unit/test_system_recipe.gd` (run)

**Interfaces:**
- Consumes: `TerrainStamp`, `WorldRecipe.stamps` (Task 1).
- Produces: `class_name SystemDesign extends RefCounted`:
  - `const DIR := "res://data/systems"`;
  - `static func for_seed(seed: int) -> SystemDesign` (null when none; every file in `DIR` is read once and cached, main thread first: `SystemRecipe.from_seed` is called on the main thread before any worker);
  - `static func load_file(path: String) -> SystemDesign` (null and a `push_error` on bad JSON);
  - `var seed: int`, `var path: String`, `var bodies: Dictionary` (StringName id → the body's Dictionary);
  - `func apply_to(recipe: WorldRecipe, body_id: StringName) -> void` (the tweak's fields, then the stamps, resolved to directions);
  - `func places_on(body_id: StringName) -> Array[PlaceDesign]`;
  - `func problems(system: SystemRecipe) -> PackedStringArray` (empty when valid);
  - `static func dir_of(lat_deg: float, lon_deg: float) -> Vector3` and `static func frame_at(dir: Vector3, heading_deg: float) -> Basis` (call 3).
- Produces: `class_name PlaceDesign extends RefCounted`:
  - `var id: StringName`, `name: String`, `body_id: StringName`, `lat: float`, `lon: float`, `heading: float`, `beacon: bool`;
  - `func dir() -> Vector3`, `func frame() -> Basis`;
  - `func local_dir(east: float, north: float, world_radius: float) -> Vector3` (the direction of a layout point);
  - `func layout() -> Dictionary` (`data/places/<id>.json`, `{}` when missing; cached).
- Produces: `SystemRecipe.from_seed(p_seed: int, use_design := true)`, with `var design: SystemDesign` (null without one). In `_make_planet` and `_make_moons`, `design.apply_to(recipe, id)` runs before the recipe's name, radius or well are read. `func places() -> Array[PlaceDesign]` covers every body's places.
- The JSON shape (stamps give `lat`/`lon`, or `place` with `at: [east, north]` in that place's frame):

```json
{
  "seed": 1337,
  "bodies": {
    "p3": {
      "tweak": {"archetype": "DUNES", "palette": "desert", "atmosphere": "THICK"},
      "stamps": [],
      "places": []
    }
  }
}
```

  Allowed tweak keys: `name`, `radius`, `gravity`, `palette` (a palette's `&"name"`), `archetype` and `atmosphere` (enum names). Stamp keys: `id`, `kind` (`flatten` / `basin`), `lat`+`lon` or `place`+`at`, `radius`, `edge`, `level`, `raise`, `floor`, `depth`, `ground`. Place keys: `id`, `name`, `lat`, `lon`, `heading`, `beacon`.
- `problems()` reports, each naming the body: a body id the system lacks; an unknown tweak or stamp key or enum name; a latitude outside ±90; a stamp `ground` its world's palette lacks; two stamps that neither keep apart nor nest (call 4); a place outside every FLATTEN's flat part on its body ("a pinned place sits on its stamped ground"); a stamp's `place` that is not a place on that body.

- [ ] **Step 1: Write the failing tests** in `test_system_design.gd`:
  - `test_every_design_in_the_data_is_valid`: for every file in `DIR`, with `system := SystemRecipe.from_seed(design.seed)`, `system.design.problems(system)` is empty.
  - `test_a_tweak_changes_only_its_fields`: a test design (written to `user://` and loaded with `load_file`) renames a planet of seed 4242 and sets its palette. That body's `name` and `palette` change. Its `radius_m`, `relief_m`, `surface_gravity`, `archetype` and atmosphere equal the undesigned ones. Every other body's recipe equals the undesigned one, field by field, and its `point` too.
  - `test_a_renamed_planet_names_its_moons`.
  - `test_stamps_land_on_the_recipe`: a design with a FLATTEN at a place's `at` gives `recipe.stamps[0].centre` equal to `place.local_dir(at...)` within 1e-9.
  - `test_problems_name_the_body`: one broken design per rule above, each giving one problem that contains the body's id.
  - `test_lat_lon_frame`: `dir_of(0, 0) == Vector3.RIGHT`; `dir_of(90, 0) == Vector3.UP`; `dir_of(0, 90)` is (0, 0, −1). At `dir_of(30, 40)`, `frame_at(d, 0)` has y = d, −z pointing north (its dot with +y is positive and it is tangent), and x = east = north × up. A heading of 90 turns −z onto east.
  - `test_no_design_no_change`: `SystemRecipe.from_seed(1337, false).describe()` equals `from_seed(1337).describe()`, and every recipe field of every body but `stamps` matches. (The kesdra tweak only pins what p3 already has.)

- [ ] **Step 2: Run to see them fail.** `-gselect=test_system_design`. Expected: FAIL (`SystemDesign` not defined).

- [ ] **Step 3: Implement** both classes and the hook in `SystemRecipe`, and write `kesdra.json` with `p3`'s tweak (call 1) and empty stamps and places.

- [ ] **Step 4: Run to see them pass.** `-gselect=test_system_design`, `-gselect=test_system_recipe`, `-gselect=test_world_recipe`, `-gselect=test_star_system`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: system designs: tweaks and stamps from JSON, validated`

---

### Task 4: The desert world's oasis ground

**Files:**
- Modify: `who-knows/data/systems/kesdra.json`
- Create: `who-knows/data/places/oasis.json` (the pool and the pad only, for now)
- Test: `who-knows/test/unit/test_desert_world.gd`, `who-knows/test/unit/test_landing_save.gd`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: `p3`'s place `oasis` (`name` "OASIS", `beacon` true, `heading` 0) and its three stamps (call 5): `oasis_floor` at the place, `pad` at (−80, −40) and `pool` at (0, 0). `oasis.json` starts as `{"pool": {"at": [0, 0], "level": -0.3}, "pad": {"at": [-80, -40], "radius": 26}}`. Later tasks add keys and never rename these.

- [ ] **Step 1: Find the place.** Write a throwaway script under `test/probes/_tmp/` (deleted before the commit). It scans directions on `p3` where the angle to the star is 60° (sun 30° up), in 0.5° steps round that circle. It keeps those whose 400 m disc, sampled at 37 points, has `continent_at` under `MESA_FROM − TOWER_BAND − 0.02`, no `in_talus`, and `|d · wind_axis| < DUNE_POLE − 0.05`. Of those, it takes the one nearest the direction from `p3` to `entry()`. Round its latitude and longitude to 0.01°. Print them, the sun's elevation there, and the floor's resulting level against the dunes' range over the disc. Put them in `kesdra.json`.

- [ ] **Step 2: Write the failing tests** in `test_desert_world.gd` (all on `SystemRecipe.from_seed(1337)`):
  - `test_the_desert_world_is_p3`: `p3` is a desert with thick air, gravity within 0.01 of 5.28, and its name the seed's.
  - `test_the_sun_stands_low_over_the_oasis`: the sun's elevation at the oasis is 25–35°.
  - `test_the_floor_and_the_pad_are_flat`: 200 samples within the pad's 26 m lie within 0.02 m of one level, which is 0.15 m (±0.005) above the floor's level. 400 samples of the floor between 30 m and 120 m from the centre, off the pad and pool, lie within 0.02 m of the floor's level.
  - `test_every_library_ship_fits_the_pad`: for every ship in `ShipLibrary.load_from_dir()`, the half-diagonal of its grid's horizontal footprint plus 5 m is at most the pad's radius.
  - `test_the_pool_is_wadeable`: with the water at the floor − 0.3 m, the water's edge (where the depth is 0) lies 14–15.5 m from the centre on 8 rays, the depth 2 m in from the edge is 0.4–0.6 m, the centre's is 0.9–1.05 m, and nowhere is it over 1.05 m.
  - `test_no_cover_at_the_oasis`: no finest chunk inside the floor's 120 m has a boulder or tuft there (`GroundCover.scatter`).
  - `test_the_rest_of_p3_is_untouched`: 500 directions beyond every stamp's reach have `height_at == base_height_at`.
  
  And in `test_landing_save.gd` (Review Focus 4): `test_a_ship_saved_where_the_floor_moved_settles`. A hull restored landed at a place on the floor where `base_height_at` is 6 m above the stamped ground is let fall and is LANDED on the floor within 10 s. One where it is 6 m below (now buried) is lifted onto the floor. Neither takes damage. If it passes already (phase 2's restore), keep it as a pin and say so.

- [ ] **Step 3: Run to see them fail, then fill the data.** `-gselect=test_desert_world`. Expected: FAIL until the place and stamps are in `kesdra.json`. Then add them and run again.

- [ ] **Step 4: Run to see them pass.** `-gselect=test_desert_world`, `-gselect=test_system_design`, `-gselect=test_landing_save`, `-gselect=test_landing_monitor`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: the desert world's oasis ground: a floor, a pad and a pool basin on p3`

---

### Task 5: The beacon, and arriving over the oasis

**Files:**
- Create: `who-knows/src/sensors/place_contacts.gd`
- Modify: `who-knows/src/world/warp_target.gd`, `who-knows/src/flight/warp_plan.gd`, `who-knows/src/world/system_recipe.gd` (`_make_targets`), `who-knows/src/ui/hud_palette.gd`, `who-knows/src/ship/computer/map_page.gd`, `who-knows/scenes/flight_test.gd` (`_wire_ship`, beside `BodyContacts`)
- Test: `who-knows/test/unit/test_place_contacts.gd`, `who-knows/test/unit/test_warp_plan.gd`

**Interfaces:**
- Consumes: `SystemRecipe.places()`, `PlaceDesign.dir()` (Task 3); the terrain to put the beacon on the ground.
- Produces: `class_name PlaceContacts extends RefCounted`, a sensor source like `BodyContacts`:
  - `const KIND := &"beacon"`, `const PREFIX := "place:"`;
  - `_init(system: SystemRecipe)` makes one `Contact` per place with `beacon`: label its `name`, `EXACT`, its point on the ground (`WorldTerrain.new(body.recipe).height_at`) plus 2 m;
  - `contacts(focus, range_m, time)` lists one only while `focus` is inside its body's well (`well_radius` from the centre), whatever the range;
  - `contact(id, ...)`.
- Produces: `HudPalette.for_kind(&"beacon")` returns a new `HudPalette.BEACON` (warm amber; HudPalette is a palette). `MapPage.colour_for(&"beacon")` returns `InteriorPalette.AMBER`. `&"beacon"` is in `COURSE_KINDS`, and `shrink` keeps it at full size.
- Produces: `WarpTarget.arrive: Vector3` (a unit direction from the centre, or ZERO). `SystemRecipe._make_targets` sets it from the first beacon place on that body. In `WarpPlan`:
  - `const ARRIVE_MAX := deg_to_rad(75.0)`, `const ARRIVE_SPARE := deg_to_rad(5.0)`;
  - `static func arrival_dir(target: WarpTarget, from: UniversePoint) -> Vector3`: with no `arrive`, the unit from the centre toward `from`. Otherwise `arrive`, turned toward that unit until it is within `minf(ARRIVE_MAX, acos(limit / distance to centre) − ARRIVE_SPARE)` of it.
  - `check` drops at `target.point + arrival_dir × limit`. `direction`, `distance`, `cost`, `duration` and `off_line` all follow the line to that drop. `to_centre` stays the distance to the centre.

- [ ] **Step 1: Write the failing tests.** In `test_place_contacts.gd`:
  - `test_one_beacon_for_the_oasis`: the kind, label `OASIS`, and a point within 3 m of the ground at the place.
  - `test_beacon_only_inside_the_well`: none at the warp limit, one 1 m inside the well, none in another world's well (Review Focus 5).
  - `test_no_beacon_without_one`: a design place with `beacon` false gives none.

  In `test_warp_plan.gd`:
  - `test_targets_without_a_side_are_unchanged`: for 20 targets of 1337 other than `p3`, the drop point, cost and direction equal what the centre line gives (the old maths, written in the test).
  - `test_arrival_over_the_oasis`: from the entry, the drop is within 1° of the oasis's direction from `p3` if that is within the clamp; otherwise exactly at the clamp.
  - `test_arrival_never_crosses_the_world`: from 50 points round `p3` at 1.2 to 20 limits out, the segment from `from` to the drop never passes within `well_radius` of `p3`'s centre (Review Focus 5). Sample it every 1 km.
  - `test_aligning_follows_the_drop`: a nose on the centre line, with the drop clamped away from it, reads ALIGN.

- [ ] **Step 2: Run to see them fail.** `-gselect=test_place_contacts`, `-gselect=test_warp_plan`. Expected: FAIL.

- [ ] **Step 3: Implement**, and wire `PlaceContacts.new(system)` into each ship's sensors beside `BodyContacts`.

- [ ] **Step 4: Run to see them pass.** `-gselect=test_place_contacts`, `-gselect=test_warp_plan`, `-gselect=test_body_contacts`, `-gselect=test_system_recipe`, `-gselect=test_visual_style_rules`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: the oasis's beacon, and a warp to its world arrives over it`

---

### Task 6: The place field, and the pool's water

**Files:**
- Create: `who-knows/src/world/place_field.gd`, `who-knows/src/world/oasis_palette.gd`, `who-knows/src/world/oasis_looks.gd`
- Modify: `who-knows/src/avatar/avatar.gd`, `who-knows/scenes/flight_test.gd` (`_wire_star_system`: make the field under `$Outside` and step it), `who-knows/test/unit/test_visual_style_rules.gd`
- Test: `who-knows/test/unit/test_place_field.gd`, `who-knows/test/unit/test_avatar_field.gd`, `who-knows/test/unit/test_floating_origin_scene.gd` (run)

**Interfaces:**
- Consumes: `SystemRecipe.places()`, `PlaceDesign.layout()`, `Whereabouts.terrain_of(body)`.
- Produces: `class_name PlaceField extends Node3D`, under Outside at the identity and never moved:
  - `const LOAD_WITHIN := 8000.0`, `const FREE_BEYOND := 10000.0`;
  - `func setup(p_universe: Universe, p_system: SystemRecipe, p_whereabouts: Whereabouts, p_catalog: ItemCatalog) -> void`;
  - `func update() -> void`, called each physics tick (loads a place whose point is within `LOAD_WITHIN` of the focus and frees one beyond `FREE_BEYOND`);
  - `func loaded(id: StringName) -> Node3D` (the place's node or null);
  - `static func on_ground(place: PlaceDesign, terrain: WorldTerrain, east: float, north: float) -> Vector3` (a layout point on the ground, in the place's frame: pure);
  - the place's node is `Place_<id>`, a member of `Universe.EXTERIOR_SPACE` with `global_transform = Transform3D(place.frame(), universe.to_engine(point))`, where `point` is the place on the ground. Its pieces are children: never members.
- Produces: `class_name OasisPalette extends RefCounted` with `WATER` to start (more in Tasks 8–9). `class_name OasisLooks extends RefCounted` with `static func water(kit: InteriorKit, f: Transform3D, radius: float) -> void` (a flat faceted disc, 24 sides). `class_name PoolWater extends Area3D` (in `oasis_looks.gd` or its own file, which the builder chooses): `var level_y` in its frame and `var floor_of: Callable` (frame-local ground height). Each physics tick it sets the overlapping avatar's `wade_depth`, and 0 as it leaves.
- Produces: in `Avatar`, `var wade_depth := 0.0`, `const WADE_SPEED := 0.55`, `const WADE_DEEP := 1.0`, `static func wade_factor(depth: float) -> float` (`lerpf(1, WADE_SPEED, clampf(depth / WADE_DEEP, 0, 1))`). FIELD movement multiplies its speed by it.

- [ ] **Step 1: Write the failing tests.** In `test_place_field.gd` (the flight scene with the starter landed on `p3`'s pad, as `test_system_scene` sets one down; use `LevelGround` only if the pad's own flatness is not enough):
  - `test_the_oasis_loads_near_and_frees_far`: one `Place_oasis` within 8 km and none at 11 km.
  - `test_the_place_sits_on_the_ground`: its origin is within 0.02 m of the floor's ground under it.
  - `test_the_water_lies_at_its_level`: the water mesh's centre is 0.3 m (±0.01) under the floor, and it is drawn on layer 1.
  - `test_place_follows_a_shift`: across `Universe.shift`, the place's engine position plus the shift equals its universe point before and after (Review Focus 3).
  - `test_only_the_place_is_a_member`: none of its descendants is in `EXTERIOR_SPACE` or `HOLDS_SHIFT`.

  In `test_avatar_field.gd`:
  - `test_wade_factor`: `wade_factor(0) == 1`; `wade_factor(1) == 0.55`; `wade_factor(2) == 0.55`; `wade_factor(0.5)` lies between.
  - `test_wading_slows_you_in_the_pool`: the avatar in FIELD at the pool's centre, walking for 1 s, covers 0.5–0.6 of what it covers on the floor.
  - `test_wading_survives_a_shift`: a shift while you stand in the pool leaves `wade_depth` within 0.01 (Review Focus 3).

- [ ] **Step 2: Run to see them fail.** `-gselect=test_place_field`, `-gselect=test_avatar_field`. Expected: FAIL.

- [ ] **Step 3: Implement**, add `place_field.gd` and `oasis_looks.gd` to `PAINTING_FILES`, and wire the field in `flight_test.gd`.

- [ ] **Step 4: Run to see them pass.** `-gselect=test_place_field`, `-gselect=test_avatar_field`, `-gselect=test_avatar_modes`, `-gselect=test_floating_origin_scene`, `-gselect=test_visual_style_rules`. Expected: all PASS.

- [ ] **Step 5: Commit.** `feat: PlaceField loads the oasis round you; its pool's water slows you`

---

### Task 7: The oasis probe, and Checkpoint A (the ground, the beacon, the arrival)

**Files:**
- Create: `who-knows/test/probes/oasis_render.gd`

**Interfaces:**
- Consumes: `desert_render.gd`'s and `landing_play.gd`'s helpers for placing, landing, stepping out and timing frames. Call or copy them; don't invent a new harness.
- Produces: `oasis_render.gd -- <out dir> [land|village|inside|all]`. The `land` set:
  - the warp from the entry to `p3`, its arrival rendered seated (the beacon on the HUD within the well, the world below);
  - seated over the oasis at 2 km and 300 m;
  - the starter landing on the pad from 150 m (print its tilt and damage);
  - the Warden landing on the pad the same way (Review Focus 1: tilt under 2°, damage 0);
  - on foot at eye height (1.6 m): at the pad's edge looking at the oasis, at the pool's edge, and standing in the pool (print the wading speed);
  - the fps landed seated on the pad over 10 s, and on foot by the pool.

- [ ] **Step 1: Write the probe** (the `land` set). Each view is printed with its name, altitude and fps where measured.
- [ ] **Step 2: Run it windowed** (never `--headless`) from `D:/git/whoknows-desert-oasis/who-knows`: `& $godot --path . -s res://test/probes/oasis_render.gd -- <scratchpad>/oasis_a land`. Expected: every view written, the landings undamaged, no errors, every fps line at least 120.
- [ ] **Step 3: Look at every render yourself first** against the style guide and the mockups. Check that the floor reads as level, packed ground among dunes, not a scar; that the pad reads as stone; that the pool's dip shows; that the beacon shows. Fix what is plainly wrong, then re-run.
- [ ] **Step 4: Checkpoint A: show the owner.** `SendUserFile` the key renders, each named, with the fps and landing lines. Ask:
  - does the oasis's ground sit right among the dunes, and is the sun's angle right;
  - are `pad` and `damp` the right colours;
  - does the beacon and the arrival over the oasis feel right;
  - **what is the world called**, if they want to name it now.
  
  **Wait for the owner.** Their changes go into `kesdra.json` and the palette, are re-rendered and shown again.
- [ ] **Step 5: Commit** the probe and any tuning. `test: oasis_render probe; the oasis ground tuned at Checkpoint A`

---

## Part B: the village outside

### Task 8: Palms, the green ring, gardens and the pump

**Files:**
- Modify: `who-knows/src/world/oasis_palette.gd`, `who-knows/src/world/oasis_looks.gd`, `who-knows/src/world/place_field.gd`, `who-knows/data/places/oasis.json`
- Test: `who-knows/test/unit/test_oasis_looks.gd`, `who-knows/test/unit/test_place_field.gd`

**Interfaces:**
- Produces: in `OasisLooks`, each from a kit and a frame on the ground, colours from `OasisPalette` only, and never seeing the place or the grid:
  - `static func palm(kit: InteriorKit, f: Transform3D, variety: float) -> void`: a segmented, faceted trunk of 6–8 chunky bevelled drums, leaning and curving by `variety`, 6–9 m tall, and 7 broad flat fronds drooping from the crown; `PALM_TRUNK`, `PALM_FROND` and a dry `PALM_FROND_DRY` on the lowest one or two;
  - `static func palm_collider(f: Transform3D, variety: float) -> CollisionShape3D` (the trunk, a capsule on `BodyProxy.LAYER`);
  - `static func grass_ring(f: Transform3D, axes: Vector2, inner: float, seed: int) -> MultiMeshInstance3D`: green tufts with `GroundCover.grass_mesh()` in `GRASS` shades, between the water's edge plus `inner` and the ellipse `axes`, with no collision. Each tuft sits on the ground through a `floor_of` Callable given with it;
  - `static func garden(kit: InteriorKit, f: Transform3D, size: Vector2, dried: bool, variety: float) -> void`: a low raised bed of `GARDEN_SOIL` with rows of crops, `CROP_GREEN`, or `CROP_DRY` when dried;
  - `static func pump(kit: InteriorKit, f: Transform3D) -> void` and `static func pipe(kit: InteriorKit, from: Vector3, to: Vector3) -> void`;
  - `static func path(kit: InteriorKit, points: PackedVector3Array, width: float) -> void`: flat stones on the ground in `OasisPalette.PATH`.
- Produces: `oasis.json` gains `palms`, `grass_ring` (axes `[36, 26]`, inner 1.5 m), `gardens` (with `dried`), `pump` (with its pipe's end) and `path`, all from call 7. `PlaceField` builds them on load: one kit for the solids, one `MultiMeshInstance3D` for the grass, and palm trunks as colliders under one `StaticBody3D` on `BodyProxy.LAYER`.

- [ ] **Step 1: Write the failing tests** in `test_oasis_looks.gd` (each in a bare frame, as `test_interior_props` does):
  - `test_a_palm_builds_alone`: it builds with no place or grid, its height is 6–9 m, and two varieties differ in height or lean.
  - `test_a_palm_has_seven_fronds`: count the frond pieces by their colour.
  - `test_colours_come_from_the_palette`: every vertex colour of a palm, a garden and the pump is an `OasisPalette` constant or a `SpacePalette.shade` of one.
  - `test_a_dried_garden_is_dry`: only `CROP_DRY` crops.
  - `test_the_grass_ring_keeps_out_of_the_water`: no tuft lies within the water's edge plus `inner`, and none lies beyond the ellipse.

  In `test_place_field.gd`:
  - `test_palms_stand_on_the_ground`: each palm's foot is within 0.05 m of `on_ground` at its layout point.
  - `test_palm_trunks_are_solid`: a ray at chest height toward a palm hits `BodyProxy.LAYER` at its trunk.

- [ ] **Step 2: Run to see them fail.** `-gselect=test_oasis_looks`, `-gselect=test_place_field`. Expected: FAIL.
- [ ] **Step 3: Implement.** Add the colours to `OasisPalette`. Start each from the concept art and the mockup (`#5f7a35` crowns, `#8f9a49` gardens, `#6fb0b4` water). They are retuned at Checkpoint B only.
- [ ] **Step 4: Run to see them pass.** `-gselect=test_oasis_looks`, `-gselect=test_place_field`, `-gselect=test_visual_style_rules`. Expected: all PASS.
- [ ] **Step 5: Commit.** `feat: the oasis's palms, green ring, gardens and pump`

---

### Task 9: Brick shells, the broken wall, the tracks and the outcrop

**Files:**
- Create: `who-knows/src/world/brick_shell.gd`
- Modify: `who-knows/src/world/oasis_palette.gd`, `who-knows/src/world/oasis_looks.gd`, `who-knows/src/world/place_field.gd`, `who-knows/data/places/oasis.json`, `who-knows/test/unit/test_visual_style_rules.gd`
- Test: `who-knows/test/unit/test_brick_shell.gd`, `who-knows/test/unit/test_place_field.gd`, `who-knows/test/unit/test_floating_origin_scene.gd` (run)

**Interfaces:**
- Produces: `class_name BrickShell extends RefCounted`, built from a kit and a frame, colours from `OasisPalette` (`BRICK`, `BRICK_DARK` for courses and the bevelled rims, `SAIL`, `SAIL_POLE`). Part C's `BaseExterior` uses it too, so it never sees a grid:
  - `static func box(kit: InteriorKit, f: Transform3D, size: Vector3, openings: Array, variety: float) -> void`: thick chunky walls with a bevelled parapet and flat roof, a few proud brick courses, and openings (each `[centre in f, width, height]`) left as holes with chunky lintels;
  - `static func round_hut(kit: InteriorKit, f: Transform3D, radius: float, height: float, variety: float) -> void`;
  - `static func crushed(kit: InteriorKit, f: Transform3D, size: Vector3, variety: float) -> void`: the walls broken down on one side, the roof slabs fallen in at angles, rubble inside;
  - `static func wall(kit: InteriorKit, points: PackedVector3Array, height: float, variety: float) -> void` (a brick wall along a polyline, 0.5 m thick);
  - `static func rubble(kit: InteriorKit, f: Transform3D, spread: Vector2, count: int, variety: float) -> void`;
  - `static func patch(kit: InteriorKit, f: Transform3D, size: Vector2, variety: float) -> void` (a brick patch on a flat wall);
  - `static func sail(kit: InteriorKit, f: Transform3D, size: Vector2, variety: float) -> void` (a cloth sail on four poles, sagging);
  - `box`, `round_hut`, `crushed` and `wall` each have a twin with the same arguments minus `kit`, named `box_shapes` and so on. It returns `Array[CollisionShape3D]` (boxes) for one `StaticBody3D` on `BodyProxy.LAYER`. How closely they follow the look is the builder's call, written in the doc comment.
- Produces: `OasisLooks.tracks(f: Transform3D, from: Vector2, bearing_deg: float, length: float, floor_of: Callable, variety: float) -> MeshInstance3D` (call 12). Each print's vertices sit on the ground's own triangles: corner heights from `floor_of`, split as `TerrainChunkData` splits its quads, 0.03 m proud. The colour fades from `TRACK` toward the sand's along the length, the last third with fewer prints. Also `OasisLooks.outcrop(f: Transform3D, size: Vector3, variety: float) -> Node3D` (call 13): stones from `RockMesh` in the world's `boulder` shades (taken from the palette as `GroundCover` takes them), with their colliders.
- Produces: `oasis.json` gains `shells` (home 5 `round`, the crushed hut), `wall` (its two runs, the gap between them), `rubble`, `tracks` (out of the gap at bearing 60° for 400 m; in from the gap to the crushed hut), `outcrop` and `sails`, all from call 7. `PlaceField` builds them, with `brick_shell.gd` and the new looks in `PAINTING_FILES`.

- [ ] **Step 1: Write the failing tests.** In `test_brick_shell.gd`, each in a bare frame:
  - `test_a_box_builds_alone`, with a test that the code names neither `ShipGrid` nor `InteriorLayout` (`GRID_SIDE`, as `REUSABLE_FILES` does).
  - `test_openings_are_holes`: a ray through each opening's centre meets no collider.
  - `test_the_walls_are_solid`: a ray at a wall's middle meets its collider within 0.6 m of the wall's face.
  - `test_colours_come_from_the_palette`.
  - `test_a_crushed_hut_differs_from_a_whole_one`: its roof's highest vertex is under 70% of the whole one's.

  In `test_place_field.gd`:
  - `test_every_piece_sits_on_the_ground`: each shell's, wall run's and garden's lowest point lies within 0.1 m of `on_ground`.
  - `test_the_wall_has_its_gap`: a ray across the gap at 1 m height meets nothing; a ray across each run does.
  - `test_the_tracks_lead_out_of_the_gap`: the first print lies within 6 m of the gap. The prints' bearing from the gap is within 10° of 60°. The last is 350–400 m out. Every print's vertices are within 0.05 m of the ground under them.
  - `test_the_outcrop_can_be_climbed`: from the floor, a chain of stone tops, each at most 0.7 m above the last and at most 2.5 m apart, reaches a top at least 7 m up.
  - `test_the_village_is_whole`: every item of call 7 has its piece (a count per kind).

- [ ] **Step 2: Run to see them fail.** `-gselect=test_brick_shell`, `-gselect=test_place_field`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to see them pass.** `-gselect=test_brick_shell`, `-gselect=test_place_field`, `-gselect=test_floating_origin_scene` (with the oasis loaded and the starter landed on the pad: add that case if the test does not reach a world), `-gselect=test_visual_style_rules`. Expected: all PASS.
- [ ] **Step 5: Commit.** `feat: the village's brick shells, the broken wall, the beast's tracks and the outcrop`

---

### Task 10: Things lying outside, and taken stays taken

**Files:**
- Modify: `who-knows/src/world/place_field.gd`, `who-knows/data/places/oasis.json`, `who-knows/scenes/flight_test.gd` (`_wire_hands`, `capture`, `_wire_universe`)
- Test: `who-knows/test/unit/test_placed_items.gd`

**Interfaces:**
- Consumes: `Item.new()`, `setup`, `set_space(true)`; the avatar's `grasp.taken` signal; `Item.consumed`.
- Produces: `oasis.json` `items`: `[{"id": "crate_hut", "kind": "crate", "at": [40, -22], "yaw": 20}, {"id": "canister_path", "kind": "canister", "at": [-40, -33], "yaw": 70}]` (spec §8.5, outside). In `PlaceField`:
  - on load, each item not taken is made, put on the ground (its box's bottom on `on_ground`), frozen static, and made a child of the place's node;
  - `func take(item: Item) -> void`: if it is one of ours, it is marked taken and ours no more. It is called from `grasp.taken` and from `consumed`. A taken item is then the hand's: dropped outside it becomes a stray, as today;
  - `func is_taken(place_id: StringName, item_id: String) -> bool`;
  - `func to_dict() -> Dictionary` (`{"taken": {place id: [item ids, sorted]}}`) and `func from_dict(d: Dictionary) -> void`;
  - the flight scene saves it as the part `"places"` and reads it back before the field's first `update`.

- [ ] **Step 1: Write the failing tests** in `test_placed_items.gd`:
  - `test_items_lie_on_the_ground`: both items, loaded, have their bottoms within 0.05 m of the ground, frozen.
  - `test_taking_one_marks_it`: grasp the crate; `is_taken(&"oasis", "crate_hut")`; it is no longer a child of the place.
  - `test_taken_stays_taken_after_a_reload`: take the crate, free the place (focus 11 km off), load it again: no crate.
  - `test_taken_stays_taken_after_a_save`: take it, then `to_dict` → a new field `from_dict` → load: no crate; the canister is still there.
  - `test_a_taken_item_dropped_outside_is_a_stray`: drop it on the floor: `strays.count()` goes up by one, and the field still says taken.
  - `test_items_stay_on_the_ground_across_a_shift` (Review Focus 3).

- [ ] **Step 2: Run to see them fail.** `-gselect=test_placed_items`. Expected: FAIL.
- [ ] **Step 3: Implement**, and wire it in the flight scene.
- [ ] **Step 4: Run to see them pass.** `-gselect=test_placed_items`, `-gselect=test_stray_field`, `-gselect=test_save_scene`. Expected: all PASS.
- [ ] **Step 5: Commit.** `feat: things lying round the oasis, and taken stays taken`

---

### Task 11: Play the village, measure it, and Checkpoint B

**Files:**
- Modify: `who-knows/test/probes/oasis_render.gd`

- [ ] **Step 1: Add the `village` set:**
  - on foot at eye height: from the pad toward the village, at the pool among the palms (toward and away from the sun), at the broken wall looking out along the tracks, from the outcrop's lookout over the dunes, in the gardens, and by the crushed hut;
  - seated, coming in to land, at 150 m and 40 m over the oasis: do the tracks read from the seat?
  - **seated on the pad looking across the oasis** (the canopy draws it twice), with the fps over 10 s;
  - on foot in the village, with the fps over 10 s;
  - Review Focus 1: the starter set down across the floor's blend 130 m out, and onto the crushed hut. Print each result (landed and its tilt, or the refusal's text) and the damage (must be 0);
  - a contact sheet `oasis_sheet.png`: `oasis-layout.html` (rendered with the built-in browser) beside a top-down render at 250 m.
- [ ] **Step 2: Run it windowed:** `oasis_render.gd -- <scratchpad>/oasis_b village`, then `landing_play.gd` on its own world. Expected: no errors; every fps line at least **120**; the landings undamaged.
- [ ] **Step 3: If a view is under 120 fps**, cut in this order and measure again: the grass ring's density, the palms' fronds beyond 300 m (`visibility_range_end` on a simpler crown), the tracks beyond 200 m from the focus, the shells' courses. Record each step's numbers.
- [ ] **Step 4: Checkpoint B: show the owner.** `SendUserFile` the sheet and the key renders with the fps lines. Ask:
  - do the palms, the green and the water read as the concept art's oasis, in the house style;
  - does the brick read as mud brick;
  - do the crushed hut, the broken wall and the tracks tell the beast's story;
  - are the tracks big enough from the seat;
  - is the layout right.
  
  **Wait for the owner**, tune, re-render and show again.
- [ ] **Step 5: Commit** the probe and tuning. `test: the village measured; tuned at Checkpoint B`

---

## Part C: buildings you enter, things to find, the log

### Task 12: Building modules, their rooms and their looks

**Files:**
- Modify: `who-knows/src/habitat/module_definition.gd`, `module_catalog.gd`, `base_site.gd`, `base_exterior.gd`
- Create: `who-knows/data/blocks/home_room.tres`, `workshop_room.tres`, `comms_room.tres`
- Modify: `who-knows/src/ship/interior/interior_layout.gd` (`ROOM_IDS`), `interior_palette.gd` (`ROOM_FLOOR`), `interior_props.gd`, `interior_dressing.gd` (`_room_piece`)
- Test: `who-knows/test/unit/test_module_catalog.gd`, `test_base_site.gd`, `test_interior_props.gd`, `test_interior_dressing.gd`, `test_brick_shell.gd`

**Interfaces:**
- Produces: `ModuleDefinition.look: StringName` (`&"drum"` default, or `&"brick"` / `&"prefab"`) and `ModuleDefinition.legs := true`. `ModuleCatalog`:
  - `const HOME_A := &"home_a"`, `HOME_B := &"home_b"`, `WORKSHOP := &"workshop"`, `COMMS := &"comms"`;
  - `static func buildings() -> Array[StringName]`;
  - `kinds()` is unchanged (they can't be planted: no package);
  - each building: storey 0 is one `airlock` in the middle of its front, opening out of +z, and its room type everywhere else; storey 1 is `grav_plating` over every floor cell. `home_a` and `home_b` are 3 × 2 cells of `home_room`, with `home_b` the mirror. `workshop` is 4 × 3 of `workshop_room`, and `comms` 3 × 2 of `comms_room`. Homes are `brick`, and the workshop and comms hut `prefab`. All have `legs` false.
- Produces: `BaseSite.world: StringName = &""` (the body id a site stands on; "" on a rock), saved in `to_dict` and read with a default in `from_dict`.
- Produces: three room blocks, copies of `galley.tres` with only `id` and `display_name` changed. `ROOM_IDS` and `ROOM_FLOOR` gain them (floors: home a warm rug-ochre, workshop a dark oil-slate, comms a dusty blue-grey). Each gets a feature prop and a compact one in `InteriorProps`, tested in a bare frame:
  - home: `low_table` with cushions, and `bedroll`;
  - workshop: `workbench` with a vice, and `tool_rack`;
  - comms: `radio_console` with one screen (set dressing that moves, style guide §2.4), and `antenna_cabinet`.
- Produces: `BaseExterior` draws a `brick` module with `BrickShell.box` round its cells (openings at its airlock face and its windows, a `sail` over the door). A `prefab` module gets today's drum in the weathered plate (a copy of the livery with `hull_colour` `OasisPalette.WEATHERED_PLATE` and `livery_colour` `WEATHERED_BAND`), with two or three `BrickShell.patch`es by `variety`. A module with `legs` false draws no legs.

- [ ] **Step 1: Write the failing tests:**
  - `test_module_catalog.gd`: `test_buildings_have_a_door_rooms_and_gravity`: each building has exactly one airlock on storey 0 at the front, opening +z, at least four cells of its room type, and grav plating over every floor cell. Also `test_buildings_cannot_be_planted`: `kinds()` is unchanged, and no building has a package.
  - `test_base_site.gd`: `test_world_is_saved`, and `test_an_old_site_has_no_world` (a dict with no `world` reads `&""`).
  - `test_interior_dressing.gd`: `test_new_rooms_are_dressed`: a grid of each room type gets its feature prop and its compact prop. And `test_room_blocks_read_back`: `BlockCatalog.load_from_dir` gives each new id with `galley`'s mass, power and category (the `.tres` rule: read back at runtime).
  - `test_interior_props.gd`: each new prop builds in a bare frame, its colliders sit in front of the wall, and its collider count is pinned.
  - `test_brick_shell.gd`: `test_a_brick_module_has_no_legs_and_a_door`: `BaseExterior.build` for a site with one `home_a` makes no legs and leaves its airlock's hatch face bare.

- [ ] **Step 2: Run to see them fail.** Expected: FAIL.
- [ ] **Step 3: Implement.** Add the colours to `InteriorPalette` and `OasisPalette`.
- [ ] **Step 4: Run to see them pass.** `-gselect=test_module_catalog`, `test_base_site`, `test_interior_props`, `test_interior_dressing`, `test_brick_shell`, `test_visual_style_rules`, `test_mesh_winding`. Expected: all PASS.
- [ ] **Step 5: Commit.** `feat: building modules: two homes, a workshop and a comms hut, brick and prefab`

---

### Task 13: Bases on a world, with doorways

**Files:**
- Modify: `who-knows/src/habitat/base.gd`, `bases.gd`, `who-knows/src/ship/grid_home.gd`, `who-knows/src/ship/airlock/airlock_cycle.gd`, `airlock.gd`, `who-knows/src/world/place_field.gd`, `who-knows/data/places/oasis.json`, `who-knows/scenes/flight_test.gd`, `who-knows/src/audio/wind_sound.gd`
- Test: `who-knows/test/unit/test_buildings.gd`, `test_airlock_cycle.gd`, `test_wind_sound.gd`, `test_bases.gd`; `test/probes/fleet_play.gd` (run)

**Interfaces:**
- Consumes: Task 12's modules and `BaseSite.world`.
- Produces: `GridHome.doorways() -> bool` (false). `Base`:
  - `on_world()` is `site.world != &""` (the phase 0 note: else you step out in SUIT mode and are asked for a charge);
  - `outside_refusal()` is `""`;
  - `doorways()` is `on_world()`.
- Produces: `AirlockCycle.doorway := false` and `func hold_open() -> void`, after which:
  - both hatches are open and their bolts drawn;
  - `step` returns no cues and changes nothing;
  - `press` does nothing;
  - `prompt` and `status` are "".

  `Airlock` calls it when its home `doorways()`, hides its panels, and makes no haze, steam or sound. The threshold code is untouched.
- Produces: `Bases.add_site(site: BaseSite) -> void`. `PlaceField.ensure_sites(bases: Bases) -> void` (called at wiring, after `bases.from_dict`) makes each layout `buildings` entry's site if `bases.site_named(id)` is null:
  - id `<place>.<building>` (e.g. `&"oasis.home_3"`), the system seed, `world` the body id;
  - one module of its kind at cell zero with no legs;
  - `turn` the place's frame turned by the building's `yaw`;
  - `at` such that its airlock's outer hatch floor stands `SILL` (0.3 m) over the ground at the door (the foundation, with the 0.15 m threshold as the middle step);
  - `items` from the layout (Task 15).
- Produces: `oasis.json` `buildings`: `home_3` (`home_a`, (−37.8, 9.4), yaw 104), `home_4` (`home_b`, (−7.4, −32.2), yaw 13), `workshop` (`workshop`, (0.5, 31.4), yaw −179) and `comms` (`comms`, (2.3, −32.9), yaw −4), each door facing a lane (Rework at Checkpoint B, 2026-11-14, round 2 on 2026-11-15: call 7's new places). Each replaces the plain `"enterable": true` brick shell of the same id in `shells` and stands on that shell's compound stamp in kesdra.json (`"stamp"`), which is level with the pool's bank; its footprint is the shell's (the workshop's prefab drum about 10.6 × 6.1 m, the comms hut's about 7.8 × 4.1 m); the shell is removed when the site is made. The builder may turn a door to face the village if the renders say so.
- Produces: `WindSound.Ear.WALLS`, appended, on the Ship bus at `WALLS_DB` below HULL (start −14 dB, by ear): you in PLATING inside a base that is `on_world()`.

- [ ] **Step 1: Write the failing tests.** In `test_buildings.gd` (the flight scene, the starter on the pad, the focus at the oasis, `bases.check_sleep()` run):
  - `test_four_buildings_wake_at_the_oasis`: `oasis.home_3`, `home_4`, `workshop` and `comms` are awake bases, none in `Fleet`.
  - `test_buildings_stand_on_the_ground`: each door's outer hatch floor is 0.25–0.35 m over the ground (SILL 0.3 m), and no ramp was built.
  - `test_walk_in_and_out`: the avatar in FIELD walks through home 3's door and is in PLATING in its interior, then walks out and is in FIELD on the ground at the door. It is never in SUIT, and never asked for a charge.
  - `test_gravity_and_light_inside`: inside, the avatar stands (plating gravity) and at least one practical is lit. If plating or lights need a store a base doesn't have, give the building the least that makes them work, and say so in the report.
  - `test_a_building_sleeps_and_wakes`: the focus 21 km off sleeps them; back, they wake with the same contents.
  - `test_ensure_sites_is_idempotent`: called twice, still four sites.

  In `test_airlock_cycle.gd`: `test_a_doorway_stays_open` (100 steps of every occupancy, both hatches 1, no cues, presses ignored). In `test_wind_sound.gd`: `test_walls_ear_inside_a_building` (quieter than HULL, silent with no air).

- [ ] **Step 2: Run to see them fail.** Expected: FAIL.
- [ ] **Step 3: Implement**, and wire `ensure_sites` and the wind ear in the flight scene.
- [ ] **Step 4: Run to see them pass.** `-gselect=test_buildings`, `test_airlock_cycle`, `test_airlock_node`, `test_airlock_world`, `test_bases`, `test_save_bases`, `test_wind_sound`, `test_floating_origin_scene`. Then the probe `test/probes/fleet_play.gd` (CLAUDE.md, after any airlock change). Expected: all PASS, and fleet_play ALL OK.
- [ ] **Step 5: Commit.** `feat: the oasis's buildings are bases on a world, with plain doorways`

---

### Task 14: Abandoned, not cold

**Files:**
- Modify: `who-knows/src/ship/interior_builder.gd`, `who-knows/src/ship/interior/interior_dressing.gd`, `interior_props.gd`, `sliding_door.gd`, `interior_palette.gd`, `who-knows/src/habitat/base.gd`
- Test: `who-knows/test/unit/test_interior_dressing.gd`

**Interfaces:**
- Produces: `InteriorBuilder.Mood { KEPT, ABANDONED }` and `var mood := Mood.KEPT`. A `Base` that is `on_world()` sets ABANDONED before its first `rebuild`. With ABANDONED, `InteriorDressing.build` does five things, by each cell's own variety so it is the same every time:
  1. It tips about half the room pieces (`static func tip(f: Transform3D, variety: float) -> Transform3D`, turned 80–95° about one floor edge), colliders and all.
  2. It lays sand drifts (`InteriorProps.sand_drift(kit, f, variety)`: low faceted wedges, `InteriorPalette.SAND_DRIFT`) along the walls of every cell and in a tongue from the airlock's inner door.
  3. It leaves a third of the practicals dead (not built) and makes a third flicker, through the existing `flicker_of` and a new `dead_of` Callable.
  4. It jams the inner sliding door at 0.4 open and tilted 6° (`SlidingDoor.jam(open: float, tilt_deg: float)`).
  5. It puts one warm `SpotLight3D` (`InteriorPalette.DAYLIGHT`, no shadows, layer 2) shining in from the airlock's inner door.

  KEPT is exactly today's dressing.

- [ ] **Step 1: Write the failing tests** in `test_interior_dressing.gd`:
  - `test_kept_is_today`: the starter's interior dressing with KEPT has the same node and mesh-vertex counts as before (pin today's numbers first).
  - `test_abandoned_tips_and_drifts`: a `home_a` grid: at least one tipped piece and at most two thirds tipped; drifts in every cell.
  - `test_abandoned_lights`: at least one dead and one flickering, and not every one of either.
  - `test_the_door_is_jammed`: the inner door reads `open` 0.4 and stays there.
  - `test_daylight_at_the_door`: one daylight spot, with shadows off and on layer 2.
  - `test_the_same_every_time`: two builds of the same site give the same tipped set and the same dead lights.

  The interior rules' own tests run as well: no shadows, layer 2, one light per cell, the doorway clearance.
- [ ] **Step 2: Run to see them fail.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to see them pass.** `-gselect=test_interior_dressing` (it holds the lighting and clearance rules), `test_interior_props`, `test_interior_builder`, `test_light_flicker`, `test_buildings`, `test_visual_style_rules`. Expected: all PASS.
- [ ] **Step 5: Commit.** `feat: the oasis's buildings are left in a hurry: tipped, sanded, half lit`

---

### Task 15: Things to find inside, kept by saving

**Files:**
- Modify: `who-knows/src/world/place_field.gd` (`ensure_sites`), `who-knows/data/places/oasis.json`
- Test: `who-knows/test/unit/test_buildings.gd`, `who-knows/test/unit/test_save_bases.gd`

**Interfaces:**
- Produces: each layout building carries `items: [{"kind", "cell": [x, y, z], "at": [x, y, z], "yaw", "use"?}]`, where `at` is metres from the cell's floor centre. They become `BaseSite.items` entries in `GridHome.items_to_dict`'s shape (`kind`, `variety`, `state` "loose", `place` in the interior frame), made once in `ensure_sites`. Spec §8.5, the amounts modest:
  - home 3: 2 ration tins, a mug and a spare helmet;
  - home 4: a medkit, an O2 tank and 2 ration tins;
  - workshop 6: a toolbox, a spanner, a wire coil and 2 power cells, and a plasma pistol behind a barricade of 4 crates stacked loose;
  - comms 7: the log datapad (`use: {"on": false, "log": "oasis_last"}`) and a power cell.

  Every kind must be in `data/items/`, and `SystemDesign.problems` gains a check that it is.

- [ ] **Step 1: Write the failing tests:**
  - `test_buildings.gd`: `test_each_building_holds_its_things`: a count per kind per building, all on the floor or a surface (none falling after 2 s of physics).
  - `test_buildings.gd`: `test_carry_an_item_out_and_back_in` (Review Focus 2). Take a ration tin from home 3, walk out with it, and drop it: one more stray, and home 3 has one tin less. Pick it up, walk into home 4, and drop it there: no stray, and home 4 has three tins. `bases.to_dict()` and `strays.to_dict()` agree.
  - `test_save_bases.gd`: `test_taken_stays_taken_inside`: take the pistol, `to_dict` → `from_dict` → wake. No pistol in the workshop, the rest there.
  - `test_save_bases.gd`: `test_a_save_from_before_phase_3_loads` (Review Focus 4): a save dict with no `places` part and no world sites loads. The four sites are made, full, and nothing is taken outside.
- [ ] **Step 2: Run to see them fail.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to see them pass.** `-gselect=test_buildings`, `test_save_bases`, `test_save_scene`, `test_system_design`. Expected: all PASS.
- [ ] **Step 5: Commit.** `feat: what the settlers left in their buildings; taken stays taken`

---

### Task 16: The log

**Files:**
- Create: `who-knows/src/items/datapad_logs.gd`, `who-knows/src/ui/log_panel.gd`, `who-knows/data/logs/oasis_last.json`
- Modify: `who-knows/src/items/datapad.gd`, `who-knows/scenes/flight_test.gd` (make the panel under the HUD), `who-knows/test/unit/test_visual_style_rules.gd`
- Test: `who-knows/test/unit/test_datapad_log.gd`

**Interfaces:**
- Produces: `class_name DatapadLogs extends RefCounted` with `const DIR := "res://data/logs"` and `static func entries(id: StringName) -> Array` (`[{day: int, text: String}]`, cached; `[]` when missing) and `static func title(id) -> String`. `oasis_last.json` holds spec §8.7's five entries word for word, with the title "SETTLEMENT LOG".
- Produces: `Datapad.log: StringName = &""`, saved and restored in its use state. With a log, `use` turns the screen on and calls the group `LogPanel.GROUP` with `open_log(id)`. With none, it behaves as today.
- Produces: `class_name LogPanel extends CanvasLayer` with `const GROUP := &"log_panel"` and `FONT_SIZE := 26`. It is styled as `ComputerOverlay` is: `LIGHT_WARM` on screen black, from `InteriorPalette` alone. It shows the title and each entry as **Day N.** and its text, a few lines in large type. `func open_log(id: StringName)` and `func close()`. While open it takes `ui_cancel` in `_input` and marks it handled, so the avatar's own ESC never fires. It closes on ESC, and when the pad leaves your hand. It is in `PAINTING_FILES`.

- [ ] **Step 1: Write the failing tests** in `test_datapad_log.gd`:
  - `test_the_log_reads_as_written`: five entries, days 212, 230, 233, 236 and 237, the text equal to the spec's.
  - `test_a_plain_datapad_is_unchanged`: use toggles the screen and opens nothing.
  - `test_using_the_comms_pad_opens_the_log`: the panel is visible with five entries.
  - `test_esc_closes_it_and_nothing_else`: a `ui_cancel` press closes it and is handled. The avatar's ESC handler did not run.
  - `test_the_log_survives_saving`: the pad's `to_dict` → `from_dict` keeps `log`.
- [ ] **Step 2: Run to see them fail.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to see them pass.** `-gselect=test_datapad_log`, `test_item_looks`, `test_visual_style_rules`. Expected: all PASS.
- [ ] **Step 5: Commit.** `feat: the comms hut's datapad carries the settlers' last log`

---

### Task 17: Play the buildings, measure them, and Checkpoint C

**Files:**
- Modify: `who-knows/test/probes/oasis_render.gd`

- [ ] **Step 1: Add the `inside` set:**
  - each enterable building at eye height: from the door looking in, and from the far corner looking back at the daylight;
  - the barricade and the pistol in the workshop;
  - the log open on the screen, rendered at 1280 × 720;
  - the fps inside each building over 10 s, and walking out of home 3 into the village;
  - the whole trip played: land on the pad, walk to the comms hut, take the datapad, read it, walk back and board. Print each step.
- [ ] **Step 2: Run it windowed:** `oasis_render.gd -- <scratchpad>/oasis_c all`, then `fleet_play.gd`. Expected: no errors; every fps line at least **80**; the trip ALL OK.
- [ ] **Step 3: If a view is under 80 fps**, cut in this order and measure again: the daylight spot's range, the drifts' facets, the flickering practicals' count. Record the numbers.
- [ ] **Step 4: Checkpoint C: show the owner.** `SendUserFile` the inside renders and the log with the fps lines. Ask:
  - do the interiors read as warm homes left in a hurry, differing from the ship by more than brightness;
  - are the new rooms' props right;
  - **is the log's text right**, or do they want to rewrite it (spec §14.4);
  - are the amounts of items right.
  
  **Wait for the owner**, tune, re-render and show again.
- [ ] **Step 5: Commit** the probe and tuning. `test: the oasis's buildings measured; tuned at Checkpoint C`

---

### Task 18: Style guide, skills and documents

**Files:**
- Modify:
  - `docs/design/visual-style.md` (§2.6, §3.9, §4, §5);
  - `CLAUDE.md` (the palette line);
  - the desert world spec (a phase 3 status block);
  - the star systems spec (step 5 marked built at the tweak and stamp depths);
  - the world scale spec (§8.3 done);
  - the Planetfall spec;
  - `.claude/skills/building-a-ship/` (checklist, `reference.md`);
  - `.claude/skills/designing-a-ship/` (checklist);
  - `.claude/skills/building-an-npc/reference.md`.

- [ ] **Step 1: The style guide.** §3.9 gains *Palms and the oasis* (the green ring, water, gardens, call 14's water) and *Brick* (the brick skin and the weathered prefab plate, both copies of the livery). §4's *a different kind of interior* gains the abandoned mood as built. §2.6 gets Tasks 7, 11 and 17's numbers. §5 names `OasisPalette` and the new `PAINTING_FILES`. Only what the owner approved at the checkpoints is written as a rule.
- [ ] **Step 2: CLAUDE.md.** The palette line becomes `InteriorPalette` inside, `HullPalette` on the hull, `SpacePalette` for rocks and worlds, and `OasisPalette` for the oasis's outside (palms, water, brick). The test's header comment changes with it.
- [ ] **Step 3: The specs.** The desert world spec gets a *Status: phase 3 is built* block with:
  - the differences as built (at least the calls above that changed at a checkpoint, the doorway airlock, the buildings as base sites, `p3` and its unchanged gravity, the world's name if given);
  - the measured numbers;
  - *Open*: the beast's design next, and the low-flight fps follow-up.
  
  The star systems spec marks step 5 built at the tweak and stamp depths, with the JSON format. The world scale spec marks §8.3's *Worlds up close* done. Planetfall marks its sites, signals and discovery log as still open.
- [ ] **Step 4: Skills.**
  - `building-a-ship`: a checklist line that a new ship must fit the oasis pad (`test_every_library_ship_fits_the_pad`); in `reference.md`, the pad's radius, that bases on a world have doorways, and where stamps live.
  - `designing-a-ship`: the pad limit (half-diagonal ≤ 21 m) or the pad grows with it.
  - `building-an-npc` `reference.md`: places, their ground and buildings exist on `p3` for the beast to come, and a world creature walks a stamped floor like any ground.
  - Fix any name in the skills that no longer exists.
- [ ] **Step 5: Ask the owner** whether to run the full suite before merging, and report the targeted runs so far. Then commit: `docs: phase 3 in the style guide, the specs, CLAUDE.md and the skills`.

---

## Spec coverage

| Spec | Task |
|---|---|
| §8.1 system designs keyed by id; authored bodies keep their sub-seeds | 3 |
| §8.1 stamps: pad, basin; in `height_at` so everything sees them | 1, 4 |
| §8.1 a pinned place from `UniversePoint`s in `EXTERIOR_SPACE` | 3, 6 |
| §8.1 the validator, run over every design in the data | 3 (and 15's item check) |
| §8.2 one planet of 1337, clear of the belts; tweak and stamps; ~5 m/s² | 3, 4 (call 1) |
| §8.2 its name is the owner's | Checkpoint A (7), call 1 |
| §8.2 the day side, the sun 25–35° up | 4 |
| §8.2 the beacon in the well, on the HUD and the map; warping arrives on its side | 5 |
| §8.3 the pad, the pool (wadeable), homes, prefabs, the crushed hut, the wall, tracks, the outcrop, gardens, palms | 4, 6, 8, 9, 12 |
| §8.3 shells kit-built with collision; palms from a palette | 8, 9 |
| §8.4 enterable buildings are bases, not ships; doors with no cycle; blocks, new rooms; the brick skin; abandoned interiors | 12, 13, 14 |
| §8.5 things to find, inside and out; taken stays taken | 10, 15 |
| §8.6 saving: taken, dropped, a landed ship, the bases; old saves keep working | 4, 10, 15 |
| §8.7 a datapad you can read; ESC closes it; the draft text | 16 |
| §6.4 wind faintly inside buildings (deferred to phase 3) | 13 |
| Phase 0 notes: `Base.on_world`, `outside_refusal`, ramps on bases, items from another shift field | 13 (no ramp: `SILL`), 10 |
| Phase 2 open: stamps keep cover clear; the oasis's own grass and palms | 2, 8 |
| §9 the style guide, the palette list; §10 renders, budget, tests, the floating origin, fleet_play; §11 skills and documents | 7, 11, 17, 18; 6, 9, 13 |
