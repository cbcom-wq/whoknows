# Desert World, Phase 1: Air — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A world with air feels like a planet, not space. Far out, its edge glows. Falling in, the black turns to a deep blue with a warm band on the horizon, the dust goes, and wind starts. Low down there is a full sky, and far land fades into haze. On the ground there's a big warm sky and the sound of wind. Air drags on what moves through it, and a fast entry glows and shakes. A world with no air looks and sounds exactly as it does today.

**Architecture:** There is one number, **air**: 0 at a world's air top, rising to the ground. `WorldRecipe.air_at(altitude)` defines it. `Whereabouts.air()` reads it for the focus, and `WorldGravity.air_at(p)` reads it for any body. The outside's `WorldEnvironment` carries the sky, haze and light. `AirMood` sets them from the focus's air each tick: a `ProceduralSkyMaterial` turned so its up is the world's up, the engine's own distance fog for haze, and the ambient and sun. A `LimbGlow` ring on each world's proxy draws the rim from outside. Drag is an acceleration from `WorldGravity`, felt by ships, strays and you on foot. `EntryGlow` on each hull draws a bow glow near the speed limit and knocks the view through the existing hit-feel path. `WindSound` plays two new `Synth` loops, one through the hull and one through the helmet. No new shader, inside or out.

**Tech Stack:** Godot 4.5.1, GDScript, GUT. Tests run with `who-knows/run_tests.ps1 -gselect=<test file without .gd>`.

**Spec:** `docs/superpowers/specs/2026-11-03-desert-world-design.md`: §6 (phase 1) is the scope, with §1–§4 (why and decisions), §9 (style guide), §10 (verification), §11 (upkeep), §12 (left to the builder) and §14. The target pictures are `docs/superpowers/specs/2026-11-03-desert-world/descent.html`. Phase 1 **replaces** Planetfall §7.3. Planetfall's `atmosphere.gdshader` and `terrain.gdshader` are never built.

**Work in:** `D:/git/whoknows-desert-air`, branch `desert-air`. It was made from `desert-world`, because phase 0 is not merged yet. Run Godot's `--import` once in this worktree before the first test, because its `.godot` cache starts empty. Never switch a branch or commit in `D:/git/whoknows` (main) or `D:/git/whoknows-desert-world`.

## Global Constraints

- **Targeted tests only:** `run_tests.ps1 -gselect=<file>` for the files a task touches. Never run the full suite. The owner is asked at the end (Task 12).
- **One air number.** Only `WorldRecipe.air_at` works it out. The focus's look, dust and wind read `Whereabouts.air()`. Drag and glow on a body read `WorldGravity.air_at(its position)`. Nothing else derives air from altitude.
- **No air, no change.** At air 0 every value `AirMood` writes equals today's: the scene's sky colours, no fog, `SpacePalette.AMBIENT` at 0.4, bloom 0.05, and the star's light. A bare world still feels like a big rock (spec §6.1).
- **The floating origin** (CLAUDE.md): `LimbGlow` is a child of a `BodyProxy`, and `EntryGlow` is a child of a hull. Both move with members of `Universe.EXTERIOR_SPACE`. World-space particles join `Universe.HOLDS_SHIFT`. `test_floating_origin_scene.gd` must pass after Tasks 4, 6 and 11.
- **No `.tscn`/`.tres` edits.** Everything is set in code. `flight_test.tscn`'s sky values become `SpacePalette` constants that `AirMood` writes back. If an edit becomes unavoidable, put no `#` comments in a block, and read every edited property back at runtime.
- **Colours come only from the palettes.** New: `WORLDS[*].sky_high` and `sky_low`, plus `SPACE_SKY_TOP`, `SPACE_SKY_HORIZON`, `SPACE_GROUND_BOTTOM`, `NIGHT_SKY`, `DUSK`, `SUN_LOW`, `ENTRY_LOW` and `ENTRY_HIGH` in `SpacePalette`. `air_mood.gd`, `limb_glow.gd` and `entry_glow.gd` join `PAINTING_FILES` in `test_visual_style_rules.gd`.
- **Shaders:** the interior budget stays three, and **no exterior shader** is added. Only engine materials are used: `Environment`, `ProceduralSkyMaterial`, `StandardMaterial3D` and particles. A fourth shader of either kind needs the owner first.
- **Every ship is usable:** drag, heat and glow come from each ship's own place, speed limit and grid, never the starter's numbers.
- **Space is silent.** Wind plays only where air > 0. No heat damage. The entry shake is never stronger than a light bolt's hit (`HitFeel.strength(LIGHT damage)`, 0.125).
- **Frame budget:** at least **120 fps at 1280 × 720 on the GTX 960**, measured by a windowed probe. Phase 0 measured 140 seated on the ground, so watch this view most.
- **Do not bump `WorldRecipe.GENERATOR_VERSION`.** No seed's world changes.
- **Skills and documents are updated in the same branch** (CLAUDE.md, spec §11): Task 12.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Merging and pushing need the owner.

## Phase 0's open items

| Open item | Covered by |
|---|---|
| The sky is black on the ground | **Yes**: Task 2 (the mood), checked at Checkpoint A |
| The hover puff reads as a white blob | **Yes**: Task 7 (the steady hold is not puffed), checked at Checkpoint C |
| The help card shows the pilot's keys on foot | **Yes**: Task 9 |
| Step 10 of `landing_play.gd` (a ringed planet) was never exercised | **Yes**: Task 10 (a `ring` run on a seed that has one) |

## Calls made in this plan (mine; the owner can change any)

1. **Air's curve:** `AIR_GROUND[atmosphere] × s²`, where `s = 1 − altitude / air_top`. Ground air is 1.0 on a thick world and **0.35** on a thin one (the spec says "about 0.4"). 0.35 is what makes thin air coast about three times as long. Altitude is over the terrain, as `Whereabouts` already reads it.
2. **Drag is an acceleration**, `−DRAG_K × air × |v| × v`, with `DRAG_K = 1/720` per metre. It's the same for every mass, so the spec's coast-down target holds for every ship. **The spec's two drag targets pull apart:** 120 → 20 m/s in 30 s means 20 m/s² of drag at 120 m/s. That caps the starter near the ground of a thick world at about **101 m/s** unboosted (√(14.2 × 720)), under the 120–150 m/s limit there. That is the spec's "a top speed lower near the ground". Higher up it fades: at half the air top it's about 200 m/s. Tune at playtest. The number to change is `DRAG_K`.
3. **The sky** is the scene's own `ProceduralSkyMaterial`, recoloured by air and turned (`Environment.sky_rotation`) so its up is the world's up. **The haze** is the engine's exponential fog with aerial perspective. The game draws no starfield, so nothing fades but the dust and the far bodies. Far planets and moons fade into the haze from below. **Only the star is exempt from the fog** (`disable_fog`).
4. **The rim** is geometry: a camera-facing ring in each world's limb plane, an unshaded additive `StandardMaterial3D`, warm on the sun side and dim on the night side. Inside the air it narrows to a band over the curved horizon, and it is gone by the time the sky's own horizon takes over.
5. **The sun's halo** is the procedural sky's own sun glow, widened by air. If the engine leaves it misplaced under `sky_rotation`, the fallback is fixed in Task 3.
6. **The entry glow** is a bow cap ahead of the hull along its velocity, built like `WarpArrival`'s flash. **The shake** is `Ship.felt_hit`, the path a bolt's hit already takes, without the cabin light dip.
7. **The steady gravity hold is not puffed** (`RcsShow.HOLD_SHOW = 0.0`): puffs show what the pilot and the assist change. The owner sees 0 and 0.25 side by side. This also stops a hovering ship holding up the floating origin's shift (phase 0's note for phase 3).
8. **Thrusters are heard outside in air** (the spec's builder's call, by ear): on foot, positional, on the Suit bus, louder with air. It sits behind `RcsShow.HEARD_OUTSIDE`, and the owner decides from recordings.
9. **Wind** has two loops: `wind` through the helmet and `wind_hull` through the hull. Loudness is `air × (0.3 × gust + speed / 150)`.
10. **You feel drag on foot too**, for one source's sake. At walking and jumping speeds it changes nothing you can measure.
11. **The help card has three faces:** seated, on foot, and spacewalk. H works in all three.
12. **Step 10's ring** is reached by putting the starter in the ring by hand, on the first seed that has a ringed planet. Flying 20 km up to it tests nothing new.

**Not in phase 1:** blowing sand (phase 2, spec §7.3). Wind heard faintly inside enterable buildings (phase 3). The airlock still pumps to vacuum on a world, so the Ship bus muffles while you stand in it with the hatch open. Drag on bolts and on breakup chunks.

## Review Focus

These five are the ones most likely to bite a player that the spec implies without testing. Each has its test in the task named.

1. **Loading a save on the ground, or hopping there with F7:** the sky must be right on the first frame, never a black sky fading in. Task 2 (`test_setup_snaps_at_once`; `hop()` and the end of `_ready` snap).
2. **Another of your ships in air while you are somewhere else:** its drag and glow follow its own place, not the focus's. Task 5 (`test_drag_is_the_hulls_own_air`) and Task 6 (`test_heat_is_the_hulls_own_place`).
3. **Seated on the ground with the canopy view:** the sky is drawn twice, and recolouring a sky re-bakes its radiance. The mood must touch the sky only when it has changed. Task 2 (`test_differs`), measured in Task 3.
4. **Stepping out and back in:** the wind hands over between the hull and the helmet with no gap and no doubling. In a ring or in space it stops. Task 8 (`test_stepping_out_hands_the_wind_over`).
5. **A hull that is ghosted at warp, arriving, frozen or landed** never glows or shakes, however fast its placing moves it. Task 6 (`test_a_frozen_or_arriving_hull_never_glows`).

---

## File Structure

| File | What it does |
|---|---|
| `who-knows/src/world/world_recipe.gd` (modify) | `AIR_GROUND`, `air_at(altitude)`: the one air curve |
| `who-knows/src/world/whereabouts.gd` (modify) | `air()`, `sun_up()`, `up()` for the focus; `dust()` thins with air |
| `who-knows/src/world/world_gravity.gd` (modify) | `air_at(p)`, `DRAG_K`, `drag(air, v)`, `drag_at(p, v)` |
| `who-knows/src/world/space_palette.gd` (modify) | Two sky colours per world palette; space, night, dusk, low sun and entry colours |
| `who-knows/src/world/air_mood.gd` (create) | Pure `mood(air, sun_up, palette, star)`, and the node that writes it to the environment, sky and sun |
| `who-knows/src/world/body_look.gd` (modify) | The star's material ignores fog |
| `who-knows/src/world/limb_glow.gd` (create) | The rim: a ring in a world's limb plane |
| `who-knows/src/world/body_proxy.gd`, `who-knows/src/world/star_system.gd` (modify) | A `LimbGlow` per world with air, placed each tick |
| `who-knows/src/flight/flight_computer.gd` (modify) | Drag on the hull, `hold_force_local`, `heat()` and `entry_heat()` |
| `who-knows/src/flight/entry_glow.gd` (create) | The bow glow and the buffet |
| `who-knows/src/ship/ship.gd` (modify) | Builds the `EntryGlow`; `grid_box()`; buffet → `felt_hit` |
| `who-knows/src/flight/rcs_show.gd` (modify) | The steady hold not puffed; thrusters heard outside in air |
| `who-knows/src/world/stray_field.gd`, `who-knows/src/avatar/avatar.gd` (modify) | Drag on strays and on you in `FIELD` |
| `who-knows/src/audio/synth.gd` (modify) | `wind` and `wind_hull` loops |
| `who-knows/src/audio/wind_sound.gd` (create) | Which ear hears the wind, how loud, and the gusts |
| `who-knows/src/ui/controls_card.gd` (modify) | Seated, on-foot and spacewalk cards |
| `who-knows/scenes/flight_test.gd` (modify) | `_wire_air()`: `AirMood` and `WindSound`; snaps on `hop`; picks the card |
| `who-knows/test/probes/landing_play.gd` (modify) | `ring` mode for step 10; air checks; `_pick_planet` hook |
| `who-knows/test/probes/descent_render.gd` (create) | Renders the four stages, the night side, the glow and the puffs; records the wind; measures fps |

---

### Task 1: How thick the air is, and the dust goes

**Files:**
- Modify: `who-knows/src/world/world_recipe.gd`, `who-knows/src/world/whereabouts.gd`, `who-knows/src/world/world_gravity.gd`
- Test: `who-knows/test/unit/test_world_recipe.gd`, `who-knows/test/unit/test_whereabouts.gd`, `who-knows/test/unit/test_world_gravity.gd` (add to each)

**Interfaces:**
- Consumes: `WorldRecipe.air_top()`, `Whereabouts.well()`, `altitude()`, `_focus_point()`, `SystemRecipe.star.point`; `WorldGravity.body_at(p)`, `altitude_at(p)` (phase 0).
- Produces:
  - `WorldRecipe.AIR_GROUND: Array[float] = [0.0, 0.35, 1.0]` (by `Atmosphere`), and `func air_at(altitude: float) -> float`: `AIR_GROUND[atmosphere] × s × s`, where `s = clampf(1.0 − altitude / air_top(), 0.0, 1.0)`.
  - `Whereabouts.air() -> float`: `well().recipe.air_at(altitude())`, or 0 outside a world's well (none, or the star's).
  - `Whereabouts.up() -> Vector3`: away from the well's centre at the focus; `Vector3.ZERO` outside a world's well.
  - `Whereabouts.sun_up() -> float`: `up() · (star.point − focus).normalized()`, the sine of the sun's height over your horizon; 1.0 outside a world's well.
  - `Whereabouts.DUST_GONE_AT := 0.2`. `dust()` returns today's value × `clampf(1.0 − air() / DUST_GONE_AT, 0.0, 1.0)`. `StarSystem.place_all` already reads it.
  - `WorldGravity.air_at(p: Vector3) -> float`: `body_at(p).recipe.air_at(altitude_at(p))`, or 0 outside a world's well.

- [ ] **Step 1: Write the failing tests**

```gdscript
# test_world_recipe.gd
func test_air_is_nothing_at_the_top_and_whole_on_thick_ground():
	var r := WorldRecipe.from_seed(1)
	r.radius_m = 20000.0
	r.atmosphere = WorldRecipe.Atmosphere.THICK   # air top 4000 m
	assert_eq(r.air_at(4000.0), 0.0)
	assert_eq(r.air_at(9000.0), 0.0)
	assert_almost_eq(r.air_at(0.0), 1.0, 1e-6)
	assert_almost_eq(r.air_at(-50.0), 1.0, 1e-6)
	assert_almost_eq(r.air_at(2000.0), 0.25, 1e-6)   # rises faster near the ground

func test_thin_air_and_none():
	var r := WorldRecipe.from_seed(1)
	r.radius_m = 20000.0
	r.atmosphere = WorldRecipe.Atmosphere.THIN
	assert_almost_eq(r.air_at(0.0), 0.35, 1e-6)
	r.atmosphere = WorldRecipe.Atmosphere.NONE
	assert_eq(r.air_at(0.0), 0.0)
	assert_eq(r.air_at(100.0), 0.0)

# test_world_gravity.gd (the file's own sys and b, set up as test_instance_reads_engine_positions does)
func test_air_at_is_the_recipes_at_the_altitude():
	var was := b.recipe.atmosphere
	b.recipe.atmosphere = WorldRecipe.Atmosphere.THICK
	var universe := Universe.new()
	add_child_autofree(universe)
	universe.origin = b.point
	var w := WorldGravity.new()
	w.setup(sys, universe, null)
	var p := Vector3.UP * (b.radius + 1500.0)
	assert_almost_eq(w.air_at(p), b.recipe.air_at(w.altitude_at(p)), 1e-6)
	assert_gt(w.air_at(p), 0.0)
	assert_eq(w.air_at(Vector3.UP * (b.well_radius + 10.0)), 0.0)
	b.recipe.atmosphere = was   # the system is shared by the file's other tests
```

  In `test_whereabouts.gd`, build it as `test_the_node_says_once_when_you_come_and_go` does: a `Universe` with `origin = b.point`, a focus `Node3D`, `set_focus`, and `Whereabouts.setup`. Here `b` is the file system's first planet, set to THICK and restored at the end. Move the focus with `focus.global_position = dir × r`, then `w.look()`. Then:
  - At 1000 m over its ground (`r = b.radius + terrain_of(b).height_at(dir) + 1000`): `air()` equals `b.recipe.air_at(altitude())` to 1e-6, and `up()` equals `dir` to 1e-5.
  - Outside every well: `air() == 0.0`, `up() == Vector3.ZERO`, `sun_up() == 1.0`.
  - With `dir` toward the star, on the ground: `sun_up() > 0.99`. With `dir` away from it: `sun_up() < -0.99`.
  - Dust: find the height where `b.recipe.air_at` is 0.1 (`top × (1 − sqrt(0.1))`). There, `dust()` is half what it is at the same spot with the planet set to NONE. At 300 m, `dust() == 0.0`. In open space it is `DUST_OPEN`, as today.

- [ ] **Step 2: Run them and see them fail**
Run: `./run_tests.ps1 -gselect=test_world_recipe`, `-gselect=test_whereabouts`, `-gselect=test_world_gravity`
Expected: the new tests FAIL (`air_at`, `air`, `up`, `sun_up` missing); the old ones pass.

- [ ] **Step 3: Implement.** Doc comments cite spec §6.1 and say this is the one place air is worked out. `air_at`'s comment names call 1 (the curve, and 0.35 for thin air).

- [ ] **Step 4: Run the three files.** Expected: PASS. Also run `-gselect=test_space_dust` and `-gselect=test_star_system`: PASS, unchanged.

- [ ] **Step 5: Commit** — `feat: how thick the air is where you are, and the dust goes as it thickens`

---

### Task 2: The outside's mood: sky, haze and light by air

**Files:**
- Create: `who-knows/src/world/air_mood.gd`
- Modify: `who-knows/src/world/space_palette.gd`, `who-knows/src/world/body_look.gd` (`material(true)`: `disable_fog = true`), `who-knows/scenes/flight_test.gd`, `who-knows/test/unit/test_visual_style_rules.gd` (`PAINTING_FILES` += `res://src/world/air_mood.gd`)
- Test: `who-knows/test/unit/test_air_mood.gd` (create); `who-knows/test/unit/test_hud_scene_wiring.gd` and `who-knows/test/unit/test_visual_style_rules.gd` (run)

**Interfaces:**
- Consumes: `Whereabouts.air()`, `sun_up()`, `up()`, `well()` (Task 1); `SpacePalette.WORLDS`, `STARS`; `SystemRecipe.star.star_palette`.
- Produces in `SpacePalette`:
  - `SPACE_SKY_TOP := Color(0.02, 0.02, 0.05)`, `SPACE_SKY_HORIZON := Color(0.05, 0.05, 0.09)`, `SPACE_GROUND_BOTTOM := Color(0.01, 0.01, 0.02)`: today's `flight_test.tscn` values. Its `ground_horizon_color` is the same as `SPACE_SKY_HORIZON`.
  - `NIGHT_SKY := Color("0b1020")`, `DUSK := Color("e89a5c")`, `SUN_LOW := Color("ffd08a")`.
  - Every `WORLDS` entry gains `&"sky_low"` (the horizon: start equal to its `sky`) and `&"sky_high"` (overhead). Starting values: ochre `7d8fb8`, slate `4f6f9a`, rust `8a7fa8`, sage `7f9cbc`, ash `8c96a8`, heather `7a74b0`, sand `7d93bd` (descent.html's stage 4), ice `8fb4d8`. They are approved from renders at Checkpoint A.
- Produces (`class_name AirMood extends Node`):
  - Constants: `SPACE_AMBIENT_ENERGY := 0.4`, `SPACE_BLOOM := 0.05`, `SPACE_HALO_DEG := 1.0`; `HORIZON_FULL_AT := 0.25`, `TOP_FULL_AT := 0.6`; `FOG_GROUND := 0.00004` (1/m), `FOG_AERIAL := 0.5`, `SUN_SCATTER := 0.25`; `AMBIENT_IN_AIR := 0.9`, `BLOOM_IN_AIR := 0.02`, `HALO_DEG := 12.0`; `SUN_WARMTH := 0.6`, `SUN_IN_AIR := 0.9`; `DAY_FROM := -0.10`, `DAY_TO := 0.20`, `DUSK_BAND := 0.25`, `DUSK_WARMTH := 0.5`; `APPLY_EVERY := 0.1`, `APPLY_STEP := 0.004`, `TURN_STEP := deg_to_rad(0.2)`.
  - `static func mood(air: float, sun_up: float, palette: Dictionary, star: Dictionary) -> Dictionary`. Its keys are `sky_top`, `sky_horizon`, `ground_horizon`, `ground_bottom` (Color), `halo_deg`, `fog` (bool), `fog_density`, `fog_colour`, `fog_aerial`, `fog_sun_scatter`, `ambient_colour`, `ambient_energy`, `bloom`, `sun_colour` and `sun_energy`. It works them out like this:

    ```text
    day   = smoothstep(DAY_FROM, DAY_TO, sun_up)
    dusk  = 1 − clampf(|sun_up| / DUSK_BAND, 0, 1)
    high  = NIGHT_SKY.lerp(palette.sky_high, day)
    low   = NIGHT_SKY.lerp(palette.sky_low, day).lerp(DUSK, dusk × DUSK_WARMTH × day)
    h     = smoothstep(0, HORIZON_FULL_AT, air)       # the horizon fills first (stage 2)
    t     = smoothstep(0, TOP_FULL_AT, air)
    sky_top = SPACE_SKY_TOP.lerp(high, t); sky_horizon = ground_horizon = SPACE_SKY_HORIZON.lerp(low, h)
    ground_bottom = SPACE_GROUND_BOTTOM.lerp(low, h)
    fog = air > 0.001; fog_density = FOG_GROUND × sqrt(air); fog_colour = low
    fog_aerial = FOG_AERIAL × h; fog_sun_scatter = SUN_SCATTER × air × day
    ambient_colour = AMBIENT.lerp(high, t); ambient_energy = lerp(SPACE_AMBIENT_ENERGY, AMBIENT_IN_AIR, t × day)
    bloom = lerp(SPACE_BLOOM, BLOOM_IN_AIR, t)
    halo_deg = lerp(SPACE_HALO_DEG, HALO_DEG, air × day)
    sun_colour = star.light.lerp(SUN_LOW, air × SUN_WARMTH × (1 − clampf(sun_up, 0, 1)))
    sun_energy = star.energy × lerp(1, SUN_IN_AIR, air)
    ```

  - `static func sky_basis(up: Vector3) -> Basis`: the shortest-arc turn taking `Vector3.UP` onto `up`. It's the identity for `up` ≈ UP or ZERO, and a half turn about X for DOWN.
  - `static func differs(a: Dictionary, b: Dictionary, step: float) -> bool`: true when `b` is empty, `fog` differs, any colour channel differs by more than `step`, or any float differs by more than `step` × its own size (relative, so a fog density of 4e-5 counts).
  - `static func apply(m: Dictionary, env: Environment, sky: ProceduralSkyMaterial, sun: DirectionalLight3D) -> void`: writes every key. `sky_top` → `sky_top_color`, and so on; `halo_deg` → `sun_angle_max`; `fog_colour` → `fog_light_color`; `bloom` → `env.glow_bloom`.
  - `func setup(env: Environment, sun: DirectionalLight3D, whereabouts: Whereabouts, system: SystemRecipe) -> void`. It takes `env.sky.sky_material` as the `ProceduralSkyMaterial`. It sets `env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL`, `env.fog_mode = Environment.FOG_MODE_EXPONENTIAL` and `env.fog_sky_affect = 0.0`, then calls `snap()`.
  - `func snap() -> void`: applies the mood for where the focus is now, and sets `env.sky_rotation = sky_basis(whereabouts.up()).get_euler()`.
  - `_physics_process`: at most every `APPLY_EVERY` s, it applies the mood only if `differs(new, last, APPLY_STEP)`. It turns the sky only once `up()` has turned more than `TURN_STEP` since the last turn. The palette is `WORLDS[well().recipe.palette]`, or `WORLDS[0]` outside a world's well, where air is 0 anyway.
- Produces in `flight_test.gd`: `var air_mood: AirMood`, and `func _wire_air() -> void`, called at the end of `_wire_star_system()`. `OUTSIDE_AMBIENT_ENERGY := AirMood.SPACE_AMBIENT_ENERGY` and `OUTSIDE_GLOW_BLOOM := AirMood.SPACE_BLOOM`, so the two can't drift apart. `air_mood.snap()` is called by `hop()` after it moves you, and by the last line of `_ready`, after `board()`. A save puts you back before `_wire_star_system()`, but `board()` may still move the focus to another ship or to you on foot.

- [ ] **Step 1: Write the failing tests** (`test_air_mood.gd`; `P := SpacePalette.WORLDS[6]` is `sand`, `S := SpacePalette.STARS[0]`)

```gdscript
func test_no_air_is_todays_space():
	var m := AirMood.mood(0.0, 0.7, P, S)
	assert_eq(m.sky_top, SpacePalette.SPACE_SKY_TOP)
	assert_eq(m.sky_horizon, SpacePalette.SPACE_SKY_HORIZON)
	assert_eq(m.ground_horizon, SpacePalette.SPACE_SKY_HORIZON)
	assert_eq(m.ground_bottom, SpacePalette.SPACE_GROUND_BOTTOM)
	assert_false(m.fog)
	assert_eq(m.ambient_colour, SpacePalette.AMBIENT)
	assert_almost_eq(m.ambient_energy, AirMood.SPACE_AMBIENT_ENERGY, 1e-6)
	assert_almost_eq(m.bloom, AirMood.SPACE_BLOOM, 1e-6)
	assert_almost_eq(m.halo_deg, AirMood.SPACE_HALO_DEG, 1e-6)
	assert_eq(m.sun_colour, S[&"light"])
	assert_almost_eq(m.sun_energy, S[&"energy"], 1e-6)

func test_thick_air_at_noon_is_the_worlds_sky():
	var m := AirMood.mood(1.0, 1.0, P, S)
	assert_eq(m.sky_top, P[&"sky_high"])
	assert_eq(m.sky_horizon, P[&"sky_low"])
	assert_true(m.fog)
	assert_almost_eq(m.fog_density, AirMood.FOG_GROUND, 1e-9)
	assert_eq(m.fog_colour, P[&"sky_low"])
	assert_almost_eq(m.halo_deg, AirMood.HALO_DEG, 1e-6)

func test_the_horizon_fills_before_the_top():   # stage 2: a warm band, a deep overhead
	var m := AirMood.mood(0.2, 1.0, P, S)
	assert_gt(_share(m.sky_horizon, SpacePalette.SPACE_SKY_HORIZON, P[&"sky_low"]),
		_share(m.sky_top, SpacePalette.SPACE_SKY_TOP, P[&"sky_high"]) + 0.2)

func test_the_haze_thickens_all_the_way_down():
	var last := 0.0
	for a in [0.05, 0.2, 0.5, 1.0]:
		var d: float = AirMood.mood(a, 1.0, P, S).fog_density
		assert_gt(d, last)
		last = d

func test_night_is_dark_and_dusk_is_warm():
	var night := AirMood.mood(1.0, -0.6, P, S)
	assert_eq(night.sky_top, SpacePalette.NIGHT_SKY)
	assert_almost_eq(night.ambient_energy, AirMood.SPACE_AMBIENT_ENERGY, 1e-6)   # the lamp still matters
	var dusk := AirMood.mood(1.0, 0.02, P, S)
	var noon := AirMood.mood(1.0, 1.0, P, S)
	assert_lt(_distance(dusk.sky_horizon, SpacePalette.DUSK), _distance(noon.sky_horizon, SpacePalette.DUSK))

func test_every_world_palette_has_two_sky_colours():
	for p in SpacePalette.WORLDS:
		assert_true(p.has(&"sky_high") and p.has(&"sky_low"), String(p[&"name"]))

func test_sky_basis_turns_up_onto_the_local_up():
	for up in [Vector3.UP, Vector3.RIGHT, Vector3(0.3, -0.9, 0.2).normalized(), Vector3.DOWN]:
		assert_almost_eq(AirMood.sky_basis(up) * Vector3.UP, up, Vector3.ONE * 1e-5)

func test_differs():   # Review Focus 3
	var m := AirMood.mood(0.5, 1.0, P, S)
	assert_true(AirMood.differs(m, {}, AirMood.APPLY_STEP))
	assert_false(AirMood.differs(m, m, AirMood.APPLY_STEP))
	assert_false(AirMood.differs(AirMood.mood(0.5005, 1.0, P, S), m, AirMood.APPLY_STEP))
	assert_true(AirMood.differs(AirMood.mood(0.6, 1.0, P, S), m, AirMood.APPLY_STEP))

func test_apply_writes_what_reads_back():
	var env := Environment.new()
	var mat := ProceduralSkyMaterial.new()
	env.sky = Sky.new()
	env.sky.sky_material = mat
	var sun := DirectionalLight3D.new()
	autofree(sun)
	var m := AirMood.mood(1.0, 1.0, P, S)
	AirMood.apply(m, env, mat, sun)
	assert_eq(mat.sky_top_color, m.sky_top)
	assert_eq(mat.ground_bottom_color, m.ground_bottom)
	assert_almost_eq(mat.sun_angle_max, m.halo_deg, 1e-6)
	assert_true(env.fog_enabled)
	assert_almost_eq(env.fog_density, m.fog_density, 1e-9)
	assert_eq(env.fog_light_color, m.fog_colour)
	assert_eq(env.ambient_light_color, m.ambient_colour)
	assert_eq(sun.light_color, m.sun_colour)

func test_setup_snaps_at_once():   # Review Focus 1: a load or a hop onto the ground
	# env, mat and sun built as in test_apply_writes_what_reads_back; system = SystemRecipe.from_seed(1).
	# _fake_where(): a Whereabouts subclass whose air() is 1, sun_up() 1, up() Vector3.RIGHT,
	# and well() a SystemBody whose recipe has palette 6.
	var mood := AirMood.new()
	add_child_autofree(mood)
	mood.setup(env, sun, _fake_where(), system)
	assert_true(env.fog_enabled, "no physics frame has run yet")
	assert_almost_eq(Basis.from_euler(env.sky_rotation) * Vector3.UP, Vector3.RIGHT, Vector3.ONE * 1e-4)
```

  `_share(c, from, to)` is how far `c` lies from `from` toward `to`, averaged over r, g and b. `_distance` is the Euclidean RGB distance. In `test_hud_scene_wiring.gd`, add one line: the scene's `air_mood` is set, and its last mood's `fog` is false at the start (the starter starts in open space).

- [ ] **Step 2: Run** `-gselect=test_air_mood`. Expected: FAIL (class missing).

- [ ] **Step 3: Implement** `air_mood.gd`, the palette entries, the star's `disable_fog`, and `_wire_air()`. In `_set_outside_mood()`, keep what it sets today; `AirMood` writes over it with the same values at air 0. The doc comment cites spec §6.2–§6.3, and says the outside's `WorldEnvironment` may change now because the interior camera carries its own (`ship_interior.tres`).

- [ ] **Step 4: Run** `-gselect=test_air_mood`, `-gselect=test_hud_scene_wiring` and `-gselect=test_visual_style_rules`. Expected: PASS. `test_hud_scene_wiring` must still see the outside's ambient at 0.4 and `SpacePalette.AMBIENT`, and the canopy camera's environment still null.

- [ ] **Step 5: Commit** — `feat: the outside's sky, haze and light follow the air`

---

### Task 3: The descent probe, and Checkpoint A (stages 2–4 and the night side)

**Files:**
- Modify: `who-knows/test/probes/landing_play.gd`. Split the planet choice out of `_to_the_planet()` into `func _pick_planet(system: SystemRecipe) -> SystemBody`, which keeps today's choice. Nothing else changes in this task.
- Create: `who-knows/test/probes/descent_render.gd`, `extends "res://test/probes/landing_play.gd"`. It overrides `_run()` and `_pick_planet()` and reuses the base's helpers (`_place`, `_moved`, `_ground_built`, `_sit`, `_shot`, `_camera_shot`, `_fps`, `_until`, `_seconds`, `_check`, `_into_the_room`, `_cycle_out`).

**Interfaces:**
- Consumes: Tasks 1–2; the flight scene's `air_mood`, `star_system.whereabouts`.
- `_pick_planet` here: the largest planet with THICK air and the `sand` palette, else the largest THICK one, else the largest with air. It also notes the largest THIN one for a second pass.

- [ ] **Step 1: Write the probe.** It prints one line per shot: the shot's name, altitude, `air()`, `sun_up()`, the dust's `density`, `env.fog_density`, and `sky_top_color` and `sky_horizon_color` as hex. It renders on the day side (`sun_up` about 0.5, the sun 30° up, as the oasis will have it). Seated means at the starter's helm, which shows the canopy view.
  1. **Stage 2:** the starter hovering at 0.95, 0.6 and 0.3 × the air top. Seated, looking at the horizon (`stage2_<k>_horizon`), and pitched 30° down (`stage2_<k>_down`).
  2. **Stage 3:** at 1000 m and 300 m. Seated toward the sun (`stage3_<h>_sun`) and away from it (`stage3_<h>_away`).
  3. **Stage 4:** landed on the flattest ground near the spot (base `_flattest`). Seated (`stage4_seated`), and standing in the cabin at a porthole (`stage4_porthole`: the window must show the sky). In the airlock with the outer hatch open (`stage4_hatch`). Then on foot, eye at 1.6 m, 6 m off the hull: horizon away from the sun (`stage4_away`), toward it (`stage4_sun`, for the halo), looking 60° up (`stage4_up`), and back at the ship (`stage4_ship`).
  4. **Night:** landed on the night side, on foot, horizon (`night_ground`), and seated 1000 m over the terminator (`night_terminator`).
  5. **Thin air:** if a THIN planet exists, stage 3 at 300 m and stage 4 on foot, prefixed `thin_`.
  6. **Contact sheet:** `descent_sheet.png`, built with `Image.blit_rect` from 320 × 180 copies. The top row is day (stage2_0.6_horizon, stage3_1000_sun, stage4_away, stage4_up); the bottom row is night_ground, stage4_seated, stage4_porthole and thin_stage4_away.
  7. **Frame rate,** each over 5 s: seated landed (`fps seated on the ground`), seated at 300 m, standing on foot 6 m off, and seated through a dive from the air top to 300 m (the sky being recoloured all the while).
  8. **Checks** (`_check`): on foot in stage 4, the dust's density is 0, fog is on, and `sky_top_color` is not `SPACE_SKY_TOP`. In stage 2 at 0.95 × top, fog density is under 25% of the ground's.
- [ ] **Step 2: Run it** without `--headless`:
  `godot --path who-knows --resolution 1280x720 --script res://test/probes/descent_render.gd -- <abs out dir>`
  Expected: every line passes, `_fails = 0`, and all four fps readings are ≥ 120.
  - If any reading is under 120, measure again with `env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED` (the hull's roughness of 0.85 barely shows the sky's reflection). Keep it only if it lifts the reading over the floor. Say so in the report.
- [ ] **Step 3: Check the sun's halo** in `stage4_sun` and `stage3_<h>_sun`. The glow must be centred on the star's disc.
  - **If it is off** (the engine leaves the light's direction unturned by `sky_rotation`), do this in this task:
    - set `sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY` in `AirMood.setup`;
    - add `src/world/star_halo.gd` (`class_name StarHalo extends MeshInstance3D`): a disc on the star's proxy, facing the focus, `HALO_DEG` across at the star's distance. Its vertex alpha runs from 1 at the centre to 0 at the rim, in the star palette's `light`. Unshaded, additive, `disable_fog`, layer 1. Its strength is `mood.halo_deg / HALO_DEG`;
    - add it to `PAINTING_FILES`, with one test that its alpha is 0 at the rim.
- [ ] **Step 4: Commit** — `test: descent_render, the air in four stages and at night`
- [ ] **Step 5: Checkpoint A — show the owner.** Send `descent_sheet.png` and the stage renders with `SendUserFile`, each named against its `descent.html` stage, with the fps lines. Ask:
  - whether the sky, haze and light read as a planet, and as the mockup;
  - for the eight `sky_high`/`sky_low` pairs: the owner approves them or asks for changes. Unseen palettes are rendered by setting the probe planet's `recipe.palette`.
  
  Tune `AirMood`'s constants and the palette in this task until the owner approves. Record the approved values in the commit message of the tuning commit: `style: the sky colours and haze approved from renders`.

---

### Task 4: The rim from outside

**Files:**
- Create: `who-knows/src/world/limb_glow.gd`
- Modify: `who-knows/src/world/body_proxy.gd` (in `setup`, a `LimbGlow` child when `body.recipe != null` and `atmosphere != NONE`; `func place_air(eye_local: Vector3, sun_dir: Vector3, air_here: float) -> void` passes to it), `who-knows/src/world/star_system.gd` (`place_all` calls `p.place_air(focus.minus(b.point), (recipe.star.point.minus(b.point)).normalized(), whereabouts.air() if whereabouts.well() == b else 0.0)` for every world proxy), `who-knows/test/unit/test_visual_style_rules.gd` (`PAINTING_FILES` += `res://src/world/limb_glow.gd`), `who-knows/test/probes/descent_render.gd` (stage 1)
- Test: `who-knows/test/unit/test_limb_glow.gd` (create), `who-knows/test/unit/test_body_proxy.gd` (add), `who-knows/test/unit/test_floating_origin_scene.gd` (run)

**Interfaces:**
- Consumes: `SystemBody.radius`, `recipe.air_top()`, `recipe.palette`, `SpacePalette.WORLDS[*].sky`; `BodyProxy.distance`.
- Produces (`class_name LimbGlow extends MeshInstance3D`):
  - Constants:
    - `SEGMENTS := 96`;
    - `ROWS := [0.0, 0.25, 1.0]` with `ROW_ALPHA := [1.0, 0.6, 0.0]`, `RIM_ALPHA := 0.8`, `RIM_NIGHT := 0.2`;
    - `INNER_INSET_DEG := 0.5`, `BAND_INSIDE_DEG := 6.0`, `MAX_ANGLE_DEG := 89.5`;
    - `DIP_GONE_DEG := 2.0`, `DIP_FULL_DEG := 8.0`, `AIR_FADE_FROM := 0.3`, `AIR_FADE_TO := 0.8`;
    - `REDRAW_TURN_DEG := 0.25`, `REDRAW_NEAR := 0.005`.
  - `static func angles(radius: float, top: float, d: float) -> Vector2`: the ring's inner and outer edges, as angles from the line from the eye to the centre. Inner is `asin(R/d) − INNER_INSET`. Outer is `min(asin(min((R + top)/d, 1)), asin(R/d) + BAND_INSIDE, MAX_ANGLE)`. Far off, outer is the air shell's silhouette. Inside the air it is a band over the limb. It is continuous across the air top.
  - `static func strength(radius: float, d: float, air_here: float) -> float`: `smoothstep(DIP_GONE, DIP_FULL, acos(R/d)) × (1 − smoothstep(AIR_FADE_FROM, AIR_FADE_TO, air_here))`. The limb's dip under the horizontal fades it near the ground, and the sky's own horizon takes over.
  - `static func lit(dir: Vector3, sun_dir: Vector3) -> float`: `lerpf(RIM_NIGHT, 1.0, smoothstep(-0.3, 0.3, dir.dot(sun_dir)))`.
  - `func setup(body: SystemBody) -> void` and `func place(eye_local: Vector3, sun_dir: Vector3, air_here: float) -> void`. It places the ring in the proxy's local frame, in true metres; the proxy's own scale does the rest.
    - The ring lies in the tangent plane: `R²/d` from the centre toward the eye.
    - Each row's radius is `(d − R²/d) × tan(angle)`, for angles from inner to outer at `ROWS`.
    - Its vertex colour is the palette's `sky`, with alpha `RIM_ALPHA × ROW_ALPHA[row] × strength × lit(segment's direction from the centre)`.
    - It redraws only once the eye has turned more than `REDRAW_TURN_DEG` or `d` has changed by more than `REDRAW_NEAR` of itself, and it is hidden when strength is 0.
  - Material: `StandardMaterial3D`, unshaded, `TRANSPARENCY_ALPHA`, `BLEND_MODE_ADD`, `CULL_DISABLED`, `vertex_color_use_as_albedo`, `disable_fog = true`; layer 1, no shadow.

- [ ] **Step 1: Write the failing tests** (R = 30000, top = 6000)

```gdscript
func test_far_off_the_rim_is_the_air_shell():
	var a := LimbGlow.angles(30000.0, 6000.0, 300000.0)
	assert_almost_eq(a.x, asin(0.1) - deg_to_rad(LimbGlow.INNER_INSET_DEG), 1e-6)
	assert_almost_eq(a.y, asin(36000.0 / 300000.0), 1e-6)

func test_inside_the_air_it_is_a_band_over_the_limb():
	var d := 33000.0
	assert_almost_eq(LimbGlow.angles(30000.0, 6000.0, d).y, asin(30000.0 / d) + deg_to_rad(LimbGlow.BAND_INSIDE_DEG), 1e-6)

func test_continuous_across_the_air_top_and_never_past_the_horizontal():
	assert_almost_eq(LimbGlow.angles(30000.0, 6000.0, 36001.0).y, LimbGlow.angles(30000.0, 6000.0, 35999.0).y, 0.01)
	assert_lte(LimbGlow.angles(30000.0, 6000.0, 30010.0).y, deg_to_rad(LimbGlow.MAX_ANGLE_DEG))

func test_strength_from_outside_and_near_the_ground():
	assert_almost_eq(LimbGlow.strength(30000.0, 300000.0, 0.0), 1.0, 1e-6)
	assert_eq(LimbGlow.strength(30000.0, 30010.0, 0.0), 0.0)    # the limb dips 1.5 deg
	assert_eq(LimbGlow.strength(30000.0, 31000.0, 0.9), 0.0)    # thick air low down

func test_lit_by_the_sun_dim_at_night():
	assert_almost_eq(LimbGlow.lit(Vector3.UP, Vector3.UP), 1.0, 1e-6)
	assert_almost_eq(LimbGlow.lit(Vector3.DOWN, Vector3.UP), LimbGlow.RIM_NIGHT, 1e-6)

func test_the_ring_lies_in_the_limb_plane():
	# setup on a 30 km THICK world; place(Vector3(0, 0, 300000), Vector3.UP, 0.0); read the mesh's vertices.
	# Every vertex v: absf(v.z - 30000.0 * 30000.0 / 300000.0) < 0.01. The inner row's radius
	# sqrt(v.x² + v.y²) equals (300000 - 3000) * tan(angles(...).x) to 0.1 m.

func test_ignores_fog_and_adds_light():
	var m := _glow.material_override as StandardMaterial3D
	assert_true(m.disable_fog)
	assert_eq(m.blend_mode, BaseMaterial3D.BLEND_MODE_ADD)
```

  In `test_body_proxy.gd`: a proxy for a world with air has exactly one `LimbGlow` child, and one for a world with none has no child.

- [ ] **Step 2: Run** `-gselect=test_limb_glow` and `-gselect=test_body_proxy`. Expected: FAIL.
- [ ] **Step 3: Implement** `limb_glow.gd` and the wiring. The doc comment cites spec §6.2 stage 1 and §6.3, and says why it is geometry and not a shader.
- [ ] **Step 4: Run** `-gselect=test_limb_glow`, `-gselect=test_body_proxy`, `-gselect=test_star_system`, `-gselect=test_floating_origin_scene` and `-gselect=test_visual_style_rules`. Expected: PASS.
- [ ] **Step 5: Add stage 1 to the probe.** On the day side, from 3 R and 1.5 R off the centre, looking at the world: seated (`stage1_<k>_seated`) and from the chase camera (`stage1_<k>_chase`). From the night side at 2 R, backlit (`stage1_night`). Across the air top, from 200 m above it and 200 m below it, looking at the horizon (`stage1_top_above`, `stage1_top_below`): the two must not jump. Add `stage1_1.5` as the sheet's first column. Run the probe. Expected: passes, fps unchanged.
- [ ] **Step 6: Commit** — `feat: a world with air glows round its edge`
- [ ] **Step 7: Checkpoint B — show the owner** the stage 1 renders and the crossing pair beside `descent.html`'s stage 1. Tune `RIM_ALPHA`, the band and the fades here until approved.

---

### Task 5: Drag

**Files:**
- Modify: `who-knows/src/world/world_gravity.gd`, `who-knows/src/flight/flight_computer.gd` (`_physics_process`, after the pull: `_hull.apply_central_force(gravity.drag_at(_hull.global_position, _hull.linear_velocity) × _hull.mass)`), `who-knows/src/world/stray_field.gd` (the same for each on-world stray beside its pull), `who-knows/src/avatar/avatar.gd` (`_field_move`: `velocity += gravity.drag_at(global_position, velocity) × delta` after `field_velocity`, when `gravity != null`)
- Test: `who-knows/test/unit/test_world_gravity.gd`, `who-knows/test/unit/test_flight_gravity.gd`, `who-knows/test/unit/test_stray_field.gd` (add to each); `who-knows/test/unit/test_avatar_field.gd` (run)

**Interfaces:**
- Consumes: `WorldGravity.air_at` (Task 1).
- Produces: `WorldGravity.DRAG_K := 1.0 / 720.0`; `static func drag(air: float, v: Vector3) -> Vector3` = `−DRAG_K × air × v.length() × v` (m/s²); `func drag_at(p: Vector3, v: Vector3) -> Vector3` = `drag(air_at(p), v)`. Every `FakeGravity` in the tests gains `var air := 0.0` and `func air_at(_p) -> float: return air`.

- [ ] **Step 1: Write the failing tests**

```gdscript
# test_world_gravity.gd
func _coast(air: float, from: float, to: float) -> float:
	var v := Vector3(from, 0, 0)
	var t := 0.0
	while v.length() >= to and t < 600.0:
		v += WorldGravity.drag(air, v) / 60.0
		t += 1.0 / 60.0
	return t

func test_thick_air_coasts_120_to_20_in_about_30_s():
	assert_between(_coast(1.0, 120.0, 20.0), 27.0, 33.0)

func test_thin_air_takes_about_three_times_as_long():
	var thin := WorldRecipe.AIR_GROUND[WorldRecipe.Atmosphere.THIN]
	assert_between(_coast(thin, 120.0, 20.0) / _coast(1.0, 120.0, 20.0), 2.5, 3.5)

func test_no_air_no_drag():
	assert_eq(WorldGravity.drag(0.0, Vector3(300, 0, 0)), Vector3.ZERO)

# test_flight_gravity.gd
func test_drag_slows_a_coasting_hull():
	_fc.assist_enabled = false
	var f := _fake_gravity(Vector3.ZERO)
	f.air = 1.0
	_fc.gravity = f
	_hull.linear_velocity = Vector3(100, 0, 0)
	await wait_physics_frames(60)
	assert_almost_eq(_hull.linear_velocity.length(), 87.8, 1.0)   # 1/v = 1/100 + t/720

func test_drag_is_the_hulls_own_air():   # Review Focus 2
	# A FakeGravity whose air_at(p) is 1 for p.x > 1000 and 0 otherwise; _fc.whereabouts stays null.
	# A hull at x = 5000 coasting at 100 m/s slows; the same at x = 0 keeps 100 to 1e-3.

func test_no_drag_at_warp():
	# air 1, TravellingWarp, velocity (100, 0, 0): unchanged after 2 physics frames.

# test_stray_field.gd
func test_a_stray_in_air_slows():
	# The file's FakeGravity with zero pull, on_world true, air 1; a stray adopted moving 50 m/s:
	# after 30 physics frames its speed is below 50 - 0.5.
```

- [ ] **Step 2: Run** `-gselect=test_world_gravity`, `-gselect=test_flight_gravity`, `-gselect=test_stray_field`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.** The doc comment on `DRAG_K` cites spec §6.5 and call 2, including the starter's ≈101 m/s near thick ground.
- [ ] **Step 4: Run** the three files plus `-gselect=test_flight_computer` and `-gselect=test_avatar_field`. Expected: PASS. The old tests are unchanged: their gravity is null or airless. Hostile ships fly through their own `FlightComputer` (`ShipPilot.flight`), so they feel the same drag with no code of their own (spec §6.5).
- [ ] **Step 5: Commit** — `feat: air drags on what moves through it`

---

### Task 6: Entry glow and shake

**Files:**
- Create: `who-knows/src/flight/entry_glow.gd`
- Modify: `who-knows/src/flight/flight_computer.gd`, `who-knows/src/world/space_palette.gd` (`ENTRY_LOW := Color("ff9a4a")`, `ENTRY_HIGH := Color("fff3e0")`), `who-knows/src/ship/ship.gd` (in `_ready` after `rcs_show`: `entry_glow = EntryGlow.new()` under `exterior`, `setup(flight_computer, exterior)`, `buffet.connect(func(s, from): felt_hit.emit(s, from))`; refit it wherever `rcs_show.rebuild` runs; `func grid_box() -> AABB`), `who-knows/test/unit/test_visual_style_rules.gd` (`PAINTING_FILES` += `res://src/flight/entry_glow.gd`)
- Test: `who-knows/test/unit/test_flight_gravity.gd` (add), `who-knows/test/unit/test_entry_glow.gd` (create), `who-knows/test/unit/test_floating_origin_scene.gd` (run)

**Interfaces:**
- Consumes: `WorldGravity.body_at`, `altitude_at`, `air_at` (Task 1); `FlightComputer.speed_limit(altitude, well_top)`; `WarpArrival.of(hull)`; `HitFeel.strength`, `WeaponValues.spec(WeaponValues.LIGHT)`; `Ship.felt_hit` (it knocks your view in its cabin, via `flight_test._on_felt_hit`, without the cabin's light dip).
- Produces:
  - `FlightComputer.HEAT_FROM := 0.8`, `HEAT_AIR := 0.05`, `HEAT_AIR_FULL := 0.15`.
  - `static func heat(speed: float, limit: float, air: float) -> float`: `clampf((speed / limit − HEAT_FROM) / (1 − HEAT_FROM), 0, 1) × clampf((air − HEAT_AIR) / (HEAT_AIR_FULL − HEAT_AIR), 0, 1)`.
  - `func entry_heat() -> float` returns 0 when `gravity` is null, the hull is frozen, the warp is travelling, or `WarpArrival.of(_hull) != null`. Otherwise it is `heat(|v|, speed_limit(gravity.altitude_at(hull), b.well_radius − b.radius), gravity.air_at(hull))`, where `b = gravity.body_at(hull)`. That is the hull's **own** limit, not `current_limit`, which is the focus's.
  - `Ship.grid_box() -> AABB`: the occupied cells' box in the hull's frame. It reads cells the same way `keel_depth` does, so light beams and turrets' reach never count.
  - `class_name EntryGlow extends Node3D`:
    - constants `GLOW_ALPHA := 0.55`, `CAP_SEGMENTS := 24`, `CAP_RINGS := 6`, `CAP_MARGIN := 0.6`, `BUFFET_EVERY := 0.12`, `SEED := 0xE7`;
    - `signal buffet(strength: float, from: Vector3)`;
    - `static func cap_mesh() -> ArrayMesh`: a unit dome bulging to −Z, with vertex alpha `cos²` of the angle from its pole at (0, 0, −1). It is 1 at the pole and 0 at the rim;
    - `static func buffet_most() -> float` = `HitFeel.strength(WeaponValues.spec(WeaponValues.LIGHT)["damage"])`;
    - `func setup(flight: FlightComputer, hull: RigidBody3D)`, `func fit(box: AABB)`;
    - each physics tick, with `h = flight.entry_heat()`, the cap shows while h > 0.01. Its pole points along the hull-local velocity. It is scaled to `box`'s extent across that direction, and placed `box`'s extent along it plus `CAP_MARGIN` ahead of the box's centre. Its colour is `ENTRY_LOW.lerp(ENTRY_HIGH, h)` with alpha `GLOW_ALPHA × h`. Every `BUFFET_EVERY` s it emits `buffet(buffet_most() × h, a random unit direction)` from its own seeded RNG;
    - material as `WarpArrival._glow`: unshaded, alpha, additive, cull disabled, layer 1 (so the canopy view shows it), no shadow. Also `vertex_color_use_as_albedo = true`, so the cap's vertex alpha fades its rim, and `albedo_color` carries the heat's colour and alpha.

- [ ] **Step 1: Write the failing tests**

```gdscript
# test_flight_gravity.gd
func test_no_heat_below_eighty_percent_or_without_air():
	assert_eq(FlightComputer.heat(0.79 * 200.0, 200.0, 1.0), 0.0)
	assert_eq(FlightComputer.heat(250.0, 200.0, 0.04), 0.0)

func test_heat_rises_to_the_limit():
	assert_almost_eq(FlightComputer.heat(180.0, 200.0, 1.0), 0.5, 1e-6)
	assert_almost_eq(FlightComputer.heat(200.0, 200.0, 0.5), 1.0, 1e-6)
	assert_almost_eq(FlightComputer.heat(400.0, 200.0, 1.0), 1.0, 1e-6)   # assist off, past it

func test_heat_is_the_hulls_own_place():   # Review Focus 2
	# FakeGravity gains `var body: SystemBody` and `func body_at(_p) -> SystemBody: return body`.
	# Here: air 1, alt 500, body a SystemBody with radius 30000 and well_radius 60000;
	# _fc.whereabouts null (so current_limit is the cruise ceiling). Hull velocity at
	# speed_limit(500, 30000) is 1.0 heat; at 0.5 of it, 0.

func test_a_frozen_or_arriving_hull_never_glows():   # Review Focus 5
	# As above at full heat; then _hull.freeze = true: entry_heat() == 0; unfrozen with a
	# TravellingWarp: 0.

# test_entry_glow.gd (a FlightComputer subclass whose entry_heat() returns `h`; a hull with a 6 x 4 x 12 m box)
func test_the_cap_is_brightest_at_its_pole():
	var a := EntryGlow.cap_mesh().surface_get_arrays(0)
	# the vertex nearest (0, 0, -1) has alpha 1 to 1e-3; every vertex with z > -0.01 has alpha < 0.01

func test_the_glow_follows_the_heat():
	# h = 0: the cap is hidden. h = 1: shown, albedo ENTRY_HIGH with alpha GLOW_ALPHA.

func test_it_points_along_the_velocity():
	# hull velocity (+50, 0, 0) in its own frame, h = 1: (cap.global_basis * Vector3.FORWARD).normalized() ≈ +X to 1e-3

func test_the_buffet_is_never_harder_than_a_light_hit():
	# h = 1 for 60 physics frames: at least 5 buffets, every strength <= EntryGlow.buffet_most() + 1e-6
```

- [ ] **Step 2: Run** `-gselect=test_flight_gravity` and `-gselect=test_entry_glow`. Expected: FAIL.
- [ ] **Step 3: Implement.** The doc comments cite spec §6.5 and call 6: no heat damage, and never stronger than a light hit.
- [ ] **Step 4: Run** `-gselect=test_flight_gravity`, `-gselect=test_entry_glow`, `-gselect=test_hit_feel`, `-gselect=test_warp_arrival`, `-gselect=test_floating_origin_scene` and `-gselect=test_visual_style_rules`. Expected: PASS.
- [ ] **Step 5: Add to the probe:** an assisted dive at the limit from the air top through 0.5 × top. Render it from the chase camera (`entry_chase`) and seated (`entry_seated`). Print the heat each second, and the fps seated at full heat. Then a gentle 30 m/s descent: the heat stays 0. Expected: passes, fps ≥ 120.
- [ ] **Step 6: Commit** — `feat: a fast entry glows and shakes`

---

### Task 7: RCS in a well: the steady hold is not puffed, and in air you hear thrusters outside

**Files:**
- Modify: `who-knows/src/flight/flight_computer.gd` (`var hold_force_local := Vector3.ZERO`: this tick's hold, `within_budget(hold, thrust_budget)`, zero without one), `who-knows/src/flight/rcs_show.gd`, `who-knows/test/probes/descent_render.gd`
- Test: `who-knows/test/unit/test_rcs_show.gd` (add)

**Interfaces:**
- Consumes: `FlightComputer.commanded_force_local`, `hold_force_local`, `gravity.air_at` (Tasks 1, 5).
- Produces on `RcsShow`:
  - `HOLD_SHOW := 0.0`, and `var hold_show := HOLD_SHOW` (the probe sets it).
  - `static func shown_force(commanded: Vector3, hold: Vector3, share: float) -> Vector3` = `commanded − hold × (1 − share)`. `_physics_process` passes it to `firing_for` in place of `commanded_force_local`, so the puffs and their sound both follow it.
  - `HEARD_OUTSIDE := true`, `OUTSIDE_DB := -6.0`.
  - `static func outside_db(amount: float, air: float) -> float` = `lerpf(SOFT_DB, LOUD_DB, amount) + linear_to_db(air) + OUTSIDE_DB`, or `-INF` for air ≤ 0.01.
  - When `HEARD_OUTSIDE` is set, there is one `AudioStreamPlayer3D` per block at its nozzle under this node (the hull's outside), on `AudioBuses.SUIT`. A puff plays there instead of aboard while the current camera is not under the interior and `air_at(hull) > 0.01`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_a_steady_hold_shows_nothing():
	assert_eq(RcsShow.shown_force(Vector3(0, 7e5, 0), Vector3(0, 7e5, 0), 0.0), Vector3.ZERO)

func test_the_pilot_on_top_of_the_hold_shows():
	assert_eq(RcsShow.shown_force(Vector3(0, 9e5, 1e5), Vector3(0, 7e5, 0), 0.0), Vector3(0, 2e5, 1e5))

func test_hold_show_keeps_a_share():
	assert_almost_eq(RcsShow.shown_force(Vector3(0, 8e5, 0), Vector3(0, 8e5, 0), 0.25), Vector3(0, 2e5, 0), Vector3.ONE)

func test_outside_only_in_air():
	assert_eq(RcsShow.outside_db(1.0, 0.0), -INF)
	assert_almost_eq(RcsShow.outside_db(1.0, 1.0), RcsShow.LOUD_DB + RcsShow.OUTSIDE_DB, 1e-4)
```

```gdscript
func test_the_starter_hovering_puffs_nothing():   # phase 0's white blob, on the starter's own blocks
	var hold := Vector3(0, 105_700.0 * 3.7, 0)   # a hover's hold on a 3.7 m/s² world
	for a in _fire(Vector3.ZERO, RcsShow.shown_force(hold, hold, RcsShow.HOLD_SHOW)):
		assert_lt(a, RcsShow.SHOW_AT)
```

- [ ] **Step 2: Run** `-gselect=test_rcs_show`. Expected: FAIL.
- [ ] **Step 3: Implement.** The doc comment says why (call 7, phase 0's open item): the steady hold puffed a white blob, and it held the origin's shift.
- [ ] **Step 4: Run** `-gselect=test_rcs_show`, `-gselect=test_flight_gravity` and `-gselect=test_flight_computer`. Expected: PASS.
- [ ] **Step 5: Add to the probe:** the starter hovering 30 m over the ground in stage 4 light, from the chase camera, with `hold_show` at 0.0 and at 0.25 (`hover_puffs_0`, `hover_puffs_25`), and with a sideways nudge (`hover_nudge`).
- [ ] **Step 6: Commit** — `fix: in a well the steady hold no longer puffs a white blob; in air you hear thrusters outside`

---

### Task 8: Wind

**Files:**
- Modify: `who-knows/src/audio/synth.gd` (`&"wind"` and `&"wind_hull"` in `NAMES` and `LOOPED`, and their builders)
- Create: `who-knows/src/audio/wind_sound.gd`
- Modify: `who-knows/scenes/flight_test.gd` (`_wire_air` adds a `WindSound`; `_physics_process` ticks it), `who-knows/test/probes/descent_render.gd` (recordings)
- Test: `who-knows/test/unit/test_wind_sound.gd` (create), `who-knows/test/unit/test_synth.gd` (run; its build, determinism and loop tests cover the new names)

**Interfaces:**
- Consumes: `Whereabouts.air()` (Task 1); `AudioBuses.SHIP`, `SUIT`; `Synth.sound`.
- Produces:
  - `Synth._wind()`: an 8 s loop.
    - White noise (seed 31) goes through a one-pole low-pass whose cutoff swings `350 × 4^(0.5 + 0.5 sin(TAU t / 8))` Hz, so 350–1400 Hz on one 8 s sine.
    - Then a high-pass at 120 Hz, `_loopable` with a 10% overrun, and `_gain` 0.5.
  - `Synth._wind_hull()`: the same swing with noise seed 32 and the cutoff at 80–260 Hz, plus a 38 Hz sine at 0.08 (304 whole cycles in 8 s), `_gain` 0.5.
  - `class_name WindSound extends Node`:
    - `enum Ear { NONE, HULL, HELMET }`;
    - `AMBIENT := 0.3`, `FULL_SPEED := 150.0`, `HULL_DB := -14.0`, `HELMET_DB := -8.0`, `SILENT_BELOW := 0.003`;
    - `static func level(air: float, speed: float, gust: float) -> float` = `clampf(air × (AMBIENT × gust + speed / FULL_SPEED), 0, 1)`;
    - `static func gust(t: float) -> float` = `0.75 + 0.15 sin(TAU t / 11) + 0.10 sin(TAU t / 4.3 + 1.3)`;
    - `static func ear(mode: Avatar.Mode, in_ship: bool) -> Ear`: FIELD → HELMET; PLATING and `in_ship` → HULL; else NONE;
    - `func tick(air: float, speed: float, which: Ear, delta: float) -> void`. It plays `wind_hull` on its Ship-bus player for HULL, and `wind` on its Suit-bus player for HELMET. The other player is stopped. `volume_db` is `linear_to_db(level) + HULL_DB / HELMET_DB`, and the helmet player's `pitch_scale` is `0.9 + 0.2 × gust`. Below `SILENT_BELOW` both are stopped.
  - In `flight_test`, each physics frame:
    - `in_ship` is `_avatar.get_parent() == aboard.interior`;
    - speed is `aboard.exterior.linear_velocity.length()` for HULL, and `_avatar.velocity.length()` for HELMET;
    - air is `star_system.whereabouts.air()`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_space_is_silent():
	assert_eq(WindSound.level(0.0, 300.0, 1.0), 0.0)

func test_on_the_ground_it_is_the_air_alone():
	assert_almost_eq(WindSound.level(1.0, 0.0, 1.0), WindSound.AMBIENT, 1e-6)
	assert_almost_eq(WindSound.level(0.35, 0.0, 1.0), 0.35 * WindSound.AMBIENT, 1e-6)

func test_in_flight_it_rises_with_speed():
	assert_eq(WindSound.level(1.0, 150.0, 1.0), 1.0)
	assert_almost_eq(WindSound.level(0.5, 75.0, 1.0), 0.5 * (WindSound.AMBIENT + 0.5), 1e-6)

func test_gusts_are_slow_and_bounded():
	var t := 0.0
	while t < 60.0:
		var g := WindSound.gust(t)
		assert_between(g, 0.5, 1.0)
		assert_lt(absf(WindSound.gust(t + 0.05) - g), 0.02)
		t += 0.05

func test_where_you_hear_it():
	assert_eq(WindSound.ear(Avatar.Mode.FIELD, false), WindSound.Ear.HELMET)
	assert_eq(WindSound.ear(Avatar.Mode.PLATING, true), WindSound.Ear.HULL)
	assert_eq(WindSound.ear(Avatar.Mode.SUIT, false), WindSound.Ear.NONE)
	assert_eq(WindSound.ear(Avatar.Mode.PLATING, false), WindSound.Ear.NONE)

func test_stepping_out_hands_the_wind_over():   # Review Focus 4
	# Synth warmed first, as the other sound tests do. tick(1, 0, HULL): hull playing, helmet not;
	# tick(1, 0, HELMET): helmet playing, hull stopped; tick(0, 0, HELMET) (a ring): neither.
```

- [ ] **Step 2: Run** `-gselect=test_wind_sound`. Expected: FAIL.
- [ ] **Step 3: Implement** the builders, `WindSound` and the wiring. The doc comments cite spec §6.4 and style guide §2.9 (changed in Task 12).
- [ ] **Step 4: Run** `-gselect=test_wind_sound`, `-gselect=test_synth` and `-gselect=test_audio_buses`. Expected: PASS.
- [ ] **Step 5: Record for the ear.** In `descent_render`, add an `AudioEffectRecord` on Master and save 6 s WAVs:
  - `wind_stage2_seated` (diving at 300 m/s through 0.6 × top);
  - `wind_low_flight` (seated, 120 m/s at 300 m);
  - `wind_landed_seated`;
  - `wind_on_foot`;
  - `rcs_outside` (on foot, 15 m from a second starter hovering and nudged sideways);
  - `wind_ring_silent` (on a spacewalk above the air: silence).
  
  Print each clip's peak level.
- [ ] **Step 6: Commit** — `feat: wind on the way down and on the ground`
- [ ] **Step 7: Checkpoint C — show the owner** the entry glow pair, the three puff renders and the six recordings. The owner decides `HOLD_SHOW` (0 or 0.25) and `HEARD_OUTSIDE`. Set whatever they choose and commit it: `style: the owner's word on puffs and thrusters outside`.

---

### Task 9: The help card on foot

**Files:**
- Modify: `who-knows/src/ui/controls_card.gd`, `who-knows/scenes/flight_test.gd` (on `_director.view_changed` and `_avatar.mode_changed`: `$HudRoot/Screen/ControlsCard.show_card(ControlsCard.card_for(_director.is_seated, _avatar.mode))`)
- Test: `who-knows/test/unit/test_controls_card.gd`

**Interfaces:**
- Produces:
  - `enum Card { SEATED, ON_FOOT, SPACEWALK }`.
  - `ROWS` stays the seated rows, so the existing tests still name it.
  - `FOOT_ROWS`:
    - `[[move_forward, move_left, move_back, move_right], "Walk", " "]`
    - `[[sprint], "Sprint", " "]`
    - `[[crouch], "Crouch", " "]`
    - `[[jump], "Jump, on a world", " "]`
    - `[[interact], "Use, open, sit", " "]`
    - `[[use], "Use what you hold", " "]`
    - `[[drop, throw], "Drop; throw", "  "]`
    - `[[lights_flood], "Suit lamp, outside", " "]`
    - `[[toggle_controls], "Hide this card", " "]`
  - `SPACEWALK_ROWS`:
    - `[[move_forward, move_left, move_back, move_right], "Thrust", " "]`
    - `[[sprint, crouch], "Up and down", " "]`
    - `[[roll_left, roll_right], "Roll", " "]`
    - `[[interact], "Use, open", " "]`
    - `[[use], "Use what you hold", " "]`
    - `[[drop, throw], "Let go; throw", "  "]`
    - `[[lights_flood], "Suit lamp", " "]`
    - `[[toggle_controls], "Hide this card", " "]`
  - Check what each action does (`project.godot`, `Interactor`, `Grasp`) and fix a label that is wrong.
  - `static func rows_for(c: Card) -> Array`, `static func card_for(seated: bool, mode: Avatar.Mode) -> Card`, `var card := Card.ON_FOOT`, and `func show_card(c: Card) -> void`, which rebuilds the labels and the backdrop. **H works anywhere:** `_armed` goes.

- [ ] **Step 1: Write the failing tests.**
  - `test_seated_is_the_pilots_card`: `card_for(true, PLATING) == SEATED` and `rows_for(SEATED) == ROWS`.
  - `test_on_foot_shows_no_pilot_keys`: `card_for(false, PLATING)` and `card_for(false, FIELD)` are `ON_FOOT`, and no row of `FOOT_ROWS` names `boost`, `warp`, `toggle_assist`, `speed_lock`, `pitch_up` or `weapons_orders`.
  - `test_a_spacewalk_has_its_own_card`: `card_for(false, SUIT) == SPACEWALK`.
  - `test_show_card_relabels`: after `show_card(ON_FOOT)`, `keys.size() == FOOT_ROWS.size()` and `keys[0].text == ControlsCard.keys_text(FOOT_ROWS[0][0], " ")`.
  - `test_every_row_on_every_card_names_a_bound_action`: the existing check, over all three lists.
  - **Replace** `test_h_does_nothing_on_foot` with `test_h_works_on_foot`: with no telemetry, H toggles `shown`. This behaviour change is the open item's fix.
- [ ] **Step 2: Run** `-gselect=test_controls_card`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `-gselect=test_controls_card` and `-gselect=test_hud_scene_wiring`. Expected: PASS.
- [ ] **Step 5: Commit** — `fix: on foot the help card shows your feet's keys, not the pilot's`

---

### Task 10: `landing_play`: the ring at last, and the air on the ground

**Files:**
- Modify: `who-knows/test/probes/landing_play.gd`

**Interfaces:**
- Consumes: everything above; `AsteroidStream.seed` (default 1337; the scene reads a seed only from a save, and saving is off in the probe).
- Produces: `landing_play.gd -- <out> ring`. In `_initialize`, it finds the first seed in 1..2000 whose `SystemRecipe.from_seed(s)` has a planet with a ring, and sets `AsteroidStream.seed` before the scene enters the tree. `_pick_planet` returns that planet, and `_run` does step 0 and step 10 only. If no seed has one, it prints `FAILED 10 no ringed planet in seeds 1-2000` and exits 1.

- [ ] **Step 1: Write step 10 for real** (Review Focus 1 of phase 0):
  1. Put the starter by hand mid-annulus in the ring's plane, hovering with assist on (call 12). It must be on no world (`on_world() == false`), with `whereabouts.air() == 0`, fog off and `dust.density > 0`.
  2. Cycle out: the avatar is in `SUIT`, not `FIELD`.
  3. Assist off for 10 s: you fall under 0.5 m.
  4. Let go of a carried item: in 5 s its distance from the planet's centre changes by under 0.5 m.
  5. Render `ring_spacewalk`, and go back in.
- [ ] **Step 2: Add air checks to the normal run.**
  - Step 1 (the hover at 300 m) prints `air()` and checks that fog is on, on a world with air.
  - Step 5 (on foot) checks that the dust's density is 0 and `sky_top_color` is not `SpacePalette.SPACE_SKY_TOP`.
  - Re-measure phase 0's three views (seated on the ground, standing 6 m off, the ramp's foot), each ≥ 120.
- [ ] **Step 3: Run both:**
  `godot --path who-knows --resolution 1280x720 --script res://test/probes/landing_play.gd -- <abs out dir>`
  `godot --path who-knows --resolution 1280x720 --script res://test/probes/landing_play.gd -- <abs out dir> ring`
  Expected: `ALL OK` both times. Step 10 is no longer `SKIPPED`.
- [ ] **Step 4: Run** `test/probes/fleet_play.gd` (CLAUDE.md, since you on foot changed). Expected: passes as before.
- [ ] **Step 5: Commit** — `test: landing_play spacewalks in a ring at last, and checks the air on the ground`

---

### Task 11: Play the whole descent, measure it, and show the owner

**Files:**
- Modify: `who-knows/test/probes/descent_render.gd` (only if a run shows a gap)

- [ ] **Step 1: Run `descent_render.gd` in full**: every stage, the night side, the glow, the puffs, the recordings, the sheet and the fps. Expected: `_fails = 0`, and every fps reading is ≥ 120.
- [ ] **Step 2: Run** `-gselect=test_floating_origin_scene`, `-gselect=test_visual_style_rules`, and every test file this plan touched (Tasks 1–10). Expected: PASS. Not the full suite.
- [ ] **Step 3: Compile the shaders on a real renderer** (style guide §6): the probe's windowed run. Expected: no `SHADER ERROR` in its output.
- [ ] **Step 4: Show the owner** with `SendUserFile`:
  - the final `descent_sheet.png` beside `descent.html`;
  - the stage renders, the night side, `stage4_porthole` and `stage4_hatch` (the windows and the hatch show the sky);
  - the entry glow and the hover;
  - the recordings;
  - a table of every fps reading (phase 0's three views, and phase 1's new ones).
  
  Ask: does it feel like a planet as you come down, and different once you're there?

---

### Task 12: Style guide, skills and documents

**Files:**
- Modify: `docs/design/visual-style.md`:
  - §2.9: *space is silent; a world with air carries sound*. Name wind, the two loops and the ears, and thrusters outside if kept.
  - A new **§3.9 Worlds up close**, phase 1's part: the sky and haze by air on the outside's environment, `AirMood` and the sky turned to the world's up. The rim (`LimbGlow`), the dust going, the entry glow, the hold not puffed. "No exterior shader: engine materials only". Ground cover, the desert, palms and brick come with phases 2–3.
  - §3.8 *Outside is dark*: amended for a world with air by day, where the ambient is the sky's.
  - §2.6: the measured numbers.
  - §5: the three new `PAINTING_FILES`.
- Modify: `.claude/skills/building-a-ship/SKILL.md`:
  - checklist: "near the ground of a thick world its top speed is √(forward accel / `DRAG_K`), the `drag` line of `ship_probe`";
  - *Mistakes already made*: anything this branch learned, at least the steady hold's white blob.
- Modify: `.claude/skills/building-a-ship/reference.md`: drag (`DRAG_K`, the starter's ≈101 m/s), `entry_heat` and `EntryGlow` (`grid_box`), `hold_force_local` and `HOLD_SHOW`, `HEARD_OUTSIDE`, and wind aboard on the Ship bus.
- Modify: `.claude/skills/building-a-ship/ship_probe.gd`: a `drag` line with the top speed in thick ground air, unboosted and boosted, capped at the cruise limit.
- Modify: `.claude/skills/designing-a-ship/SKILL.md`: one line where it talks about flight feel, saying a ship's top speed near thick ground is √(forward accel × 720).
- Modify: `.claude/skills/building-an-npc/reference.md`: `WorldGravity.air_at` and `drag_at` exist for anything outside in air. Nothing lives there yet.
- Modify: `docs/superpowers/specs/2026-09-23-planetfall-design.md`: the header note says §7.3 is replaced by the desert world's phase 1, as built (no `atmosphere.gdshader`; the `WorldEnvironment` does change now).
- Modify: `docs/superpowers/specs/2026-09-30-world-scale-design.md`: §8.3 *Worlds up close*, done for the air, with ground cover in phase 2.
- Modify: `docs/superpowers/specs/2026-11-03-desert-world-design.md`: the status note says phase 1 is built, lists its differences as built (including any changed call), the measured fps, and the open items left for phase 2.

- [ ] **Step 1: Make the edits.** Check that every name the skills and the guide mention still exists (`grep`).
- [ ] **Step 2: Run** `-gselect=test_visual_style_rules` and `-gselect=test_ship_catalog`, and `ship_check.gd` on the starter (the skill says how). Expected: PASS, and the `drag` line prints.
- [ ] **Step 3: Commit** — `docs: phase 1 as built; the guide learns air and sound on a world, the skills learn drag and entry`
- [ ] **Step 4: Ask the owner** whether to run the full suite before the branch is finished. Do not merge or push.
