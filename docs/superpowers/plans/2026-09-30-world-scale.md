# World Scale Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make planets 15–60 km worlds you fly down to and skim over, with the system spaced out to match, drawn by one quadtree surface per body that streams its detail round you, solid where you touch it, and a speed limit that rises with altitude.

**Architecture:** Part A (Tasks 1–4) is the numbers: `WorldRecipe` and `SystemRecipe` at the new sizes, moons as warp targets, the warp retuned, the map and markers, the far plane. Bodies are still faceted shells there, only huge, so the owner can judge the sizes by flying. Part B (Tasks 5–11) is the ground: `WorldTerrain` (pure: height, colour, altitude) feeds the far mesh and `TerrainChunkData` (pure, built on worker threads) over `CubeSphere` (pure face and quadtree maths). `WorldSurface` (a node beside each `BodyProxy`) chooses leaves, streams chunks, keeps them solid round anchors and lifts anything that ends up underground. `FlightComputer` asks `Whereabouts` for the well and altitude and applies the altitude limit. Part C (Tasks 12–13) measures, renders and updates the documents and the skill.

**Tech Stack:** Godot 4.5.1 (.NET build, GDScript only here), GUT (headless) via `who-knows\run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-09-30-world-scale-design.md` (read it first). Background: `2026-09-28-warp-design.md`, `2026-09-27-system-skeleton-design.md` §7, `2026-09-23-planetfall-design.md` §6.

## Global Constraints

- **Run the whole suite before and after every task:** `& .\who-knows\run_tests.ps1` from the repo root (about 10 minutes). It must end `---- All tests passed! ----` with output pristine (no new warnings or errors) and exit code 0. One file alone: `& .\who-knows\run_tests.ps1 -gtest=res://test/unit/<file>.gd`.
- **CLAUDE.md is binding.** Colours only from `SpacePalette` outside (and `InteriorPalette` on the holo, `HudPalette` on the HUD). Every new file that paints joins `PAINTING_FILES` in `test/unit/test_visual_style_rules.gd`. Anything outside the ship joins `Universe.EXTERIOR_SPACE` itself, under a parent that never moves. No `#` comments inside `.tscn`/`.tres` blocks; this plan edits no `.tscn`.
- **No new shader.** Every world material is `BodyLook.material(false)`.
- **Numbers (spec §3, §5, §6):** planets 15,000–60,000 m, moons 4,000–15,000 m, star 200,000–300,000 m; relief 1–2.5% of radius, at most 1,200 m; well 2 radii; warp limit = well + 14,000 m (a planet's also past its ring by `CLEAR`); moons 180–400 km out, wholly outside their planet's limit; slots 1,500–7,500 km; warp 18 s + 1 s per 350,000 m; cost 40 QE + 1 QE per 12,500 m, rounded up; far plane 400,000 m; `PROXY_AT` 350,000 m; surface within min(10 radii, 300 km); split 1.5× edge, merge 1.8×; 16 × 16 quads, finest quad ≤ 2 m; solid within 64 m + 1 s × speed, at most 160 m; speed limit 120 m/s + 1 m/s per 40 m of altitude, capped at 1,500, easing back to 120 over the top tenth of the well.
- **Versions:** `WorldRecipe.GENERATOR_VERSION` 2, `SystemRecipe.VERSION` 3, `AsteroidRecipe.VERSION` 4. An old save starts over at the start.
- **Style of the code:** match the surrounding GDScript: `##` doc comments in plain English that say why, typed vars, `const` for every tunable, short British-English sentences.
- **Commits:** one per task at least, in the repo's style (`feat:`, `test:`, `docs:`), ending with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Review Focus

1. **Arriving at a world:** after a hop or a warp's drop-out the surface must be whole on its first frame (the six roots, built synchronously), and a chunk must never vanish before what replaces it is built. Pinned by `test_a_surface_is_whole_from_its_first_frame` and `test_every_leaf_is_drawn_once_and_nothing_overlaps` (Task 9).
2. **Coming down fast:** an anchor arriving near the ground before its collision is streamed must still have ground under it the same tick. Pinned by `test_an_anchor_arriving_fast_has_ground_under_it` (Task 10).
3. **Leaving a world mid-build:** a surface freed while worker jobs are in flight must wait for them, never crash or leak. Pinned by `test_a_surface_freed_mid_build_waits_for_its_jobs` (Task 9).
4. **A warp passing a world:** no surface may start while a warp carries you (a synchronous root build mid-warp is a hitch, and the hull is ghosted). Pinned by `test_no_surface_starts_while_frozen` (Task 9) and `set_warp` freezing proxies (Task 9).
5. **Degenerate places:** a focus at a body's centre, below the lowest ground, or at negative altitude must not produce NaNs or a zero limit. Pinned by `test_selection_from_the_centre_is_sane` (Task 8), `test_no_keys_from_the_centre_or_far_away` (Task 10) and `test_the_limit_at_or_below_the_ground_is_the_cruise_ceiling` (Task 11).

---

## File map

```
Create:
  who-knows/src/world/world_terrain.gd        WorldTerrain: height, colour, altitude (pure)
  who-knows/src/world/cube_sphere.gd          CubeSphere: faces, quadtree keys, bounds (pure)
  who-knows/src/world/terrain_chunk_data.gd   TerrainChunkData: one chunk's arrays (pure)
  who-knows/src/world/world_surface.gd        WorldSurface: leaves, streaming, solid ground, floor
  who-knows/src/world/terrain_collider.gd     TerrainCollider: which chunks are solid (pure)
  who-knows/test/unit/test_world_terrain.gd
  who-knows/test/unit/test_cube_sphere.gd
  who-knows/test/unit/test_terrain_chunks.gd
  who-knows/test/unit/test_world_surface.gd
  who-knows/test/unit/test_speed_limit.gd
  who-knows/test/probes/world_probe.gd
Modify:
  who-knows/src/world/{world_recipe,system_recipe,system_body,warp_target,whereabouts,
    body_look,body_proxy,star_system,belt_look,ring_look,asteroid_recipe}.gd
  who-knows/src/flight/{warp_plan,warp_profile,flight_computer}.gd
  who-knows/src/sensors/body_contacts.gd
  who-knows/src/ship/computer/map_page.gd
  who-knows/src/ui/{body_marker,contact_marker,vehicle_telemetry}.gd, src/ui/panels/velocity_panel.gd
  who-knows/scenes/flight_test.gd
  who-knows/test/unit/{test_world_recipe,test_system_recipe,test_warp_profile,test_warp_plan,
    test_map_page,test_warp_hud,test_body_proxy,test_system_scene,test_floating_origin_scene,
    test_visual_style_rules}.gd
  .claude/skills/building-a-ship/{SKILL.md,reference.md,ship_probe.gd}
  docs: the specs the world scale spec amends (Task 13)
```

---

# Part A — the numbers

### Task 1: The recipes at the new scale, and moons as warp targets

**Files:**
- Modify: `who-knows/src/world/world_recipe.gd`, `system_recipe.gd`, `system_body.gd`, `warp_target.gd`, `asteroid_recipe.gd`
- Test: `who-knows/test/unit/test_world_recipe.gd`, `test_system_recipe.gd`

**Interfaces:**
- Produces:
  - `WarpTarget.Kind { STAR, PLANET, CLUSTER, MOON }` (MOON appended, so saved values never move).
  - `SystemRecipe.warp_targets()` order: the star, the planets in slot order, the moons in body order, then the clusters.
  - `SystemBody.warp_limit` for every star, planet and moon: its well + `WARP_CLEAR`; a planet's also at least `ring.outer + CLEAR`.
  - `SystemRecipe._planet_limit(p: SystemBody) -> float` (static).
  - `WorldRecipe.RADIUS`, `RELIEF`, `RELIEF_MAX`, `WELL_RADII` at the new values.

- [ ] **Step 1: Run the whole suite for a baseline**

Run: `& .\who-knows\run_tests.ps1`
Expected: `---- All tests passed! ----`. Note the test count.

- [ ] **Step 2: Write the failing tests**

In `who-knows/test/unit/test_world_recipe.gd`, replace the two assertions that pin the old numbers:

```gdscript
			assert_eq(r.well_radius(), r.radius_m * 2.0)
```

(in `test_planets_and_moons_are_in_range`, replacing the `* 3.0` line) and, in `test_each_field_draws_from_its_own_sub_seed`:

```gdscript
	assert_eq(r.radius_m, size.randf_range(15000.0, 60000.0))
```

and append:

```gdscript
func test_worlds_are_tens_of_kilometres_with_real_mountains():
	# The world scale spec §3.1.
	assert_eq(WorldRecipe.RADIUS[K.PLANET], Vector2(15000.0, 60000.0))
	assert_eq(WorldRecipe.RADIUS[K.MOON], Vector2(4000.0, 15000.0))
	assert_eq(WorldRecipe.RELIEF_MAX, 1200.0)
	for s in 200:
		var r := WorldRecipe.from_seed(s * 131 + 7)
		assert_between(r.relief_m, minf(r.radius_m * 0.01, 1200.0) - 0.001, 1200.0)
	assert_eq(WorldRecipe.GENERATOR_VERSION, 2)
```

In `who-knows/test/unit/test_system_recipe.gd`:

Replace in `test_the_star_is_at_the_middle_of_a_layer_of_giant_cells`:

```gdscript
	assert_between(s.star.radius, 200000.0, 300000.0)
```

Replace the whole of `test_warp_limits_reach_past_each_body_s_edge_and_hold_its_moons` with:

```gdscript
func test_warp_limits_reach_past_each_body_s_well_and_moons_lie_outside_their_planet_s():
	for k in 200:
		var s := SystemRecipe.from_seed(k * 7919 + 3)
		var broken := s.problems()
		assert_eq(broken.size(), 0, "seed %d: %s" % [s.seed, ", ".join(broken)])
		for t in s.warp_targets():
			assert_gte(t.limit, t.edge + SystemRecipe.WARP_CLEAR - 0.01, "%s" % t.id)
		for p in s.planets():
			assert_almost_eq(p.warp_limit, SystemRecipe._planet_limit(p), 0.01)
			if p.ring != null:
				assert_gte(p.warp_limit, p.ring.outer + SystemRecipe.CLEAR - 0.01, "%s holds its ring" % p.id)
			for m in s.moons_of(p):
				var d := m.point.minus(p.point).length()
				assert_gte(d - m.warp_limit, p.warp_limit + SystemRecipe.CLEAR - 0.01, "%s is clear of %s's limit" % [m.id, p.id])
				assert_lte(d + m.neighbourhood, p.neighbourhood + 0.01, "%s stays in %s's neighbourhood" % [m.id, p.id])
```

Replace the whole of `test_targets_are_the_star_then_the_planets_then_the_clusters` with:

```gdscript
func test_targets_are_the_star_the_planets_the_moons_then_the_clusters():
	var s := SystemRecipe.from_seed(1337)
	var targets := s.warp_targets()
	assert_eq(targets[0].id, &"star")
	assert_eq(targets[0].kind, WarpTarget.Kind.STAR)
	assert_eq(targets[0].edge, s.star.well_radius)
	var planets := s.planets()
	for i in planets.size():
		assert_eq(targets[i + 1].id, planets[i].id)
		assert_eq(targets[i + 1].kind, WarpTarget.Kind.PLANET)
		assert_eq(targets[i + 1].limit, planets[i].warp_limit)
	var moons := s.bodies.filter(func(b: SystemBody) -> bool: return b.kind == SystemBody.Kind.MOON)
	for i in moons.size():
		var t := targets[planets.size() + 1 + i]
		assert_eq(t.id, moons[i].id)
		assert_eq(t.kind, WarpTarget.Kind.MOON)
		assert_eq(t.limit, moons[i].well_radius + SystemRecipe.WARP_CLEAR)
	var first_cluster := 1 + planets.size() + moons.size()
	for i in s.clusters.size():
		assert_eq(targets[first_cluster + i], s.clusters[i])
	assert_eq(targets.size(), first_cluster + s.clusters.size())
	for t in targets:
		assert_eq(s.warp_target(t.id), t)
		assert_eq(t.contact_id(), StringName("body:" + String(t.id)))
```

Replace `test_the_versions_moved_on`:

```gdscript
func test_the_versions_moved_on():
	assert_eq(SystemRecipe.VERSION, 3)
	assert_eq(AsteroidRecipe.VERSION, 4)
```

Append:

```gdscript
# --- the world scale spec §3 ----------------------------------------------------

func test_the_system_is_thousands_of_kilometres_across():
	var s := SystemRecipe.from_seed(1337)
	assert_between(s.slots[0], SystemRecipe.FIRST_SLOT * 0.9, SystemRecipe.FIRST_SLOT * 1.1)
	assert_eq(SystemRecipe.FIRST_SLOT, 1500000.0)
	assert_eq(SystemRecipe.LAST_SLOT, 7500000.0)
	for p in s.planets():
		assert_between(p.radius, 15000.0, 60000.0)
		assert_eq(p.well_radius, p.radius * 2.0)
	for b in s.belts:
		assert_between(b.half_width, SystemRecipe.BELT_MIN_HALF_WIDTH, SystemRecipe.BELT_HALF_WIDTH.y)
		assert_lte(b.half_thickness, 2000.0, "inside one layer of giant cells")
	gut.p(s.describe())
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `& .\who-knows\run_tests.ps1 -gtest=res://test/unit/test_system_recipe.gd`
Expected: FAIL (the star's radius, `_planet_limit` not found, the versions).

- [ ] **Step 4: Change `WorldRecipe`**

In `who-knows/src/world/world_recipe.gd` replace the constants block from `GENERATOR_VERSION` to `WELL_RADII` with:

```gdscript
## Part of a world's identity: bumped whenever a seed's world changes.
const GENERATOR_VERSION := 2
## Radius, metres, by kind: uniform. Worlds you fly down into, not balls you
## orbit (the world scale spec §3.1).
const RADIUS: Array[Vector2] = [Vector2(15000.0, 60000.0), Vector2(4000.0, 15000.0)]
## Surface gravity, m/s2, by kind: capped below the starter shuttle's lift of
## about 10.8 m/s2 so no world strands the only ship (Planetfall §5.2).
const GRAVITY: Array[Vector2] = [Vector2(2.0, 8.0), Vector2(1.0, 4.0)]
## Peak-to-trough terrain, as a share of radius, and never more than
## RELIEF_MAX metres: real mountains to fly between.
const RELIEF := Vector2(0.01, 0.025)
const RELIEF_MAX := 1200.0
## Atmosphere weights, NONE / THIN / THICK, by kind: moons are mostly bare.
const ATMOSPHERE_WEIGHTS := [[0.40, 0.35, 0.25], [0.80, 0.20, 0.0]]
## A world's well reaches this many radii: its edge is a radius above the
## ground (the world scale spec §3.1).
const WELL_RADII := 2.0
```

- [ ] **Step 5: Add `MOON` to `WarpTarget`**

In `who-knows/src/world/warp_target.gd`:

```gdscript
## One place a warp can take you (docs/superpowers/specs/2026-09-28-warp-design.md
## §3.1; the world scale spec §3.3): the star, a planet, a moon or a belt
## cluster, as data. SystemRecipe makes these; WarpPlan, Whereabouts, the map
## and the HUD read them.

## MOON comes last so no saved value moves.
enum Kind { STAR, PLANET, CLUSTER, MOON }
```

and in `system_body.gd` replace the `warp_limit` doc comment with:

```gdscript
## A warp may start only beyond this, from its centre (the warp spec §3.2; the
## world scale spec §3.3): its well plus WARP_CLEAR, and a planet's past its
## ring. Every star, planet and moon has one.
var warp_limit := 0.0
```

- [ ] **Step 6: Change `SystemRecipe`**

In `who-knows/src/world/system_recipe.gd`:

Top doc comment: replace the paragraph starting `It also lists the warp targets` with:

```gdscript
## It also lists the warp targets (docs/superpowers/specs/2026-09-28-warp-design.md
## §3; docs/superpowers/specs/2026-09-30-world-scale-design.md §3.3): the star,
## the planets, the moons and the belts' clusters, each with a warp limit, and
## a disc of orbital debris round every planet. A moon lies wholly outside its
## planet's limit: at this scale it is a warp, not a flight, away.
```

Replace the constants from `VERSION` down to `DEBRIS_TILT` with:

```gdscript
## Bumped whenever a seed's system changes: a save made by another version
## starts over (saving spec §8.1).
const VERSION := 3

## The height of the system's disc, and of the star's centre.
const PLANE_Y := 2500

const STAR_RADIUS := Vector2(200000.0, 300000.0)
## The star's neighbourhood reaches this far past its well.
const STAR_ROOM := 40000.0
## The first slot, give or take FIRST_SLOT_JITTER; each next one this many
## times further out; none past LAST_SLOT; never more than MOST_SLOTS.
const FIRST_SLOT := 1500000.0
const FIRST_SLOT_JITTER := 0.1
const SLOT_RATIO := Vector2(1.18, 1.30)
const LAST_SLOT := 7500000.0
const MOST_SLOTS := 10
## A planet sits up to this share of its slot's radius off the disc.
const TILT := 0.03
## Tries at an angle round the star before giving up the moons, and again
## before leaving the slot empty.
const PLACE_TRIES := 32
## A planet's neighbourhood reaches at least this far past its well.
const PLANET_ROOM := 20000.0
## Everything keeps this far from whatever it must be clear of.
const CLEAR := 5000.0
## A moon's neighbourhood reaches this far past its well.
const MOON_ROOM := 5000.0
const MOST_MOONS := 3
## A moon is this far from its planet's centre, at most.
const MOON_FAR := 400000.0
## ... and at least this far, and always clear of its planet's limit.
const MOON_NEAR := 180000.0
const MOON_TRIES := 16
## Rings: on planets this big, this often.
const RING_MIN_RADIUS := 30000.0
const RING_CHANCE := 0.25
const RING_INNER := Vector2(1.6, 2.0)
const RING_WIDTH := Vector2(10000.0, 30000.0)
const RING_HALF_THICKNESS := 100.0
const RING_TILT := deg_to_rad(30.0)
## Belts: this many, never slot 0, never side by side.
const BELTS := Vector2i(1, 2)
## A belt's cross-section. It is wide at this scale so it reads as a band,
## but no thicker than before: it must lie inside one 5 km layer of giant
## cells, where its big rocks can sit.
const BELT_HALF_WIDTH := Vector2(20000.0, 40000.0)
const BELT_HALF_THICKNESS := Vector2(1500.0, 2000.0)
## A belt squeezed below this half-width is dropped; planets beside a belt
## leave it at least this.
const BELT_MIN_HALF_WIDTH := 15000.0
## A belt goes only where both gaps to its neighbouring slots are this wide:
## room for its narrowest self and the biggest moonless planet beside it.
const BELT_GAP := 300000.0
## A warp may start this far past a body's well (the warp spec §3.2): about
## two minutes of flying at 120 m/s.
const WARP_CLEAR := 14000.0
## A belt cluster's reach from its centre (§3.1).
const CLUSTER_RADIUS := 4000.0
## Clusters per belt, and tries at a seeded angle for each.
const CLUSTERS := Vector2i(3, 6)
const CLUSTER_TRIES := 24
## Orbital debris (§3.3): a disc from a planet's well to this far inside its
## warp limit, this thick, tilted up to this much off the system's plane when
## there is no ring to follow.
const DEBRIS_INSIDE := 1000.0
const DEBRIS_HALF_THICKNESS := 3000.0
const DEBRIS_TILT := deg_to_rad(20.0)
```

In `problems()`, inside the moons loop, after the `"%s is in %s's ring"` check, add:

```gdscript
			if d - m.warp_limit < p.warp_limit + CLEAR - 0.01:
				out.append("%s is inside %s's limit" % [m.id, p.id])
```

and replace the loop

```gdscript
	for b in tops:
		if b.warp_limit < b.neighbourhood + CLEAR - 0.01:
			out.append("%s's warp limit is inside its neighbourhood" % b.id)
```

with:

```gdscript
	for b in tops:
		if b.warp_limit < b.well_radius + WARP_CLEAR - 0.01:
			out.append("%s's warp limit is inside its well" % b.id)
		if b.ring != null and b.warp_limit < b.ring.outer + CLEAR - 0.01:
			out.append("%s's ring pokes out of its warp limit" % b.id)
```

In `_make_planet(i)`, after the block that may drop the ring (after `if bare > room:` … `return` … the closing of that block) and **before** `var moons := _make_moons(i, p, room)`, add:

```gdscript
	p.warp_limit = _planet_limit(p)
```

and delete the later line

```gdscript
	p.warp_limit = maxf(p.well_radius + WARP_CLEAR, p.neighbourhood + CLEAR)
```

Add after `_find_place`:

```gdscript
## A planet's warp limit (the world scale spec §3.3): its well plus
## WARP_CLEAR, and past its ring. Not its neighbourhood: that holds its moons,
## which lie outside the limit with limits of their own.
static func _planet_limit(p: SystemBody) -> float:
	var limit := p.well_radius + WARP_CLEAR
	if p.ring != null:
		limit = maxf(limit, p.ring.outer + CLEAR)
	return limit
```

In `_make_moons`, after `m.neighbourhood = m.well_radius + MOON_ROOM`, replace

```gdscript
		var near := maxf(MOON_NEAR, p.well_radius + m.well_radius + CLEAR)
```

with:

```gdscript
		m.warp_limit = m.well_radius + WARP_CLEAR
		# Wholly outside its planet's limit (§3.3), which already holds the
		# planet's ring.
		var near := maxf(MOON_NEAR, p.warp_limit + m.warp_limit + CLEAR)
```

In `_make_star`, `star.warp_limit = star.well_radius + WARP_CLEAR` stays as it is.

Replace `_make_targets()` with:

```gdscript
func _make_targets() -> void:
	var kinds := {
		SystemBody.Kind.STAR: WarpTarget.Kind.STAR,
		SystemBody.Kind.PLANET: WarpTarget.Kind.PLANET,
		SystemBody.Kind.MOON: WarpTarget.Kind.MOON,
	}
	# The star, the planets, then the moons (the world scale spec §3.3).
	for kind in [SystemBody.Kind.STAR, SystemBody.Kind.PLANET, SystemBody.Kind.MOON]:
		for b in bodies:
			if b.kind != kind:
				continue
			var t := WarpTarget.new()
			t.id = b.id
			t.kind = kinds[kind]
			t.name = b.name
			t.point = b.point
			t.radius = b.radius
			t.edge = b.well_radius
			t.limit = b.warp_limit
			_targets.append(t)
	_targets.append_array(clusters)
	for t in _targets:
		_target_by_id[t.id] = t
```

Update the `warp_targets()` doc comment to "the star, the planets in slot order, the moons, then the clusters."

- [ ] **Step 7: Bump `AsteroidRecipe.VERSION`**

In `who-knows/src/world/asteroid_recipe.gd`, change `const VERSION := 3` to `const VERSION := 4`, and add to its doc comment above it: `4: the world scale (belts and rings at the new sizes).`

- [ ] **Step 8: Run the recipe tests**

Run: `& .\who-knows\run_tests.ps1 -gtest=res://test/unit/test_system_recipe.gd` then `-gtest=res://test/unit/test_world_recipe.gd`
Expected: PASS. Read the printed `describe()` and the 500-seed line from `test_every_seed_keeps_every_rule`.
If `test_every_seed_keeps_every_rule` fails on empty slots (`assert_lt(empty, SEEDS / 10)`), print the reasons it lists: *no room beside a belt* means `BELT_GAP` is too small for a 60 km planet with moons (raise it in 50 km steps); *no clear angle* means `SLOT_RATIO`'s lower bound is too tight (raise `.x` to 1.22). Do not relax the test.

- [ ] **Step 9: Run the whole suite**

Run: `& .\who-knows\run_tests.ps1`
Expected: failures only in files Tasks 2–4 own (`test_warp_profile`, `test_warp_plan`, `test_map_page`, `test_warp_hud`, `test_body_proxy`, `test_star_system`, `test_system_scene`, `test_warp_scene`, `test_warp_drive`). Anything else failing is this task's to fix now. Note which fail.

- [ ] **Step 10: Commit**

```bash
git add who-knows/src/world who-knows/test/unit/test_world_recipe.gd who-knows/test/unit/test_system_recipe.gd
git commit -m "feat: world scale -- planets 15-60 km, the system spaced out, moons as warp targets"
```

---

### Task 2: The warp, retuned

**Files:**
- Modify: `who-knows/src/flight/warp_profile.gd`, `warp_plan.gd`
- Test: `who-knows/test/unit/test_warp_profile.gd`, `test_warp_plan.gd`, `test_warp_scene.gd`

**Interfaces:**
- Consumes: `WarpTarget.Kind.MOON` (Task 1).
- Produces: `WarpProfile.PACE = 350000.0`; `WarpPlan.WARP_M_PER_QE = 12500.0` (replaces `WARP_PER_KM`, which is deleted); `WarpPlan.cost_of(travel)` = `WARP_BASE + ceili(travel / WARP_M_PER_QE)`.

- [ ] **Step 1: Write the failing tests**

In `who-knows/test/unit/test_warp_profile.gd` replace the first three tests (up to and including `test_the_peak_makes_the_distance`) with:

```gdscript
func test_the_duration_is_eighteen_seconds_and_one_more_per_350_km():
	assert_almost_eq(WarpProfile.new(350000.0).duration, 19.0, 1e-6)
	assert_almost_eq(WarpProfile.new(3500000.0).duration, 28.0, 1e-6)
	assert_almost_eq(WarpProfile.new(12250000.0).duration, 53.0, 1e-6)

func test_the_distance_comes_out_exact_and_the_ends_are_at_cruise():
	for d in [5000.0, 350000.0, 4600000.0, 12500000.0]:
		var p := WarpProfile.new(d)
		assert_almost_eq(p.travelled_at(0.0), 0.0, 1e-6)
		assert_almost_eq(p.travelled_at(p.duration), d, d * 1e-6)
		assert_almost_eq(p.speed_at(0.0), WarpProfile.EDGE_SPEED, 1e-6)
		assert_almost_eq(p.speed_at(p.duration), WarpProfile.EDGE_SPEED, 1e-6)
		var sum := 0.0
		var dt := 0.001
		var t := 0.0
		while t < p.duration:
			sum += p.speed_at(t + dt * 0.5) * dt
			t += dt
		assert_almost_eq(sum, d, d * 0.001, "the distance is the speed's integral")

func test_the_peak_makes_the_distance():
	var p := WarpProfile.new(3500000.0)
	assert_almost_eq(p.peak, 120.0 + (3500000.0 - 120.0 * 28.0) / 24.0, 0.01)
	assert_almost_eq(p.speed_at(14.0), p.peak, 1e-6)
```

Change the file's doc comment to: `## How fast a warp goes (the warp spec §5.3; the world scale spec §3.4): 18 s and 1 s more per 350 km, up to the peak over 4 s and back down over the last 4, 120 m/s at both ends.`

In `test_typical_trips_average_about_thirty_seconds`, replace the filter line with:

```gdscript
		var ts := s.warp_targets().filter(func(t: WarpTarget) -> bool:
			return t.kind == WarpTarget.Kind.STAR or t.kind == WarpTarget.Kind.PLANET)
```

In `who-knows/test/unit/test_warp_plan.gd`:

Add a member and set it in `before_each` (after `_cluster`), and add it to `_targets`:

```gdscript
var _distant: WarpTarget
```

```gdscript
	_distant = _target(&"p9", WarpTarget.Kind.PLANET, Vector3(0, 0, -8000000), 150000.0)
	_targets = [_star, _near, _far, _cluster, _distant]
```

In `test_ready_with_the_cost_the_time_and_the_drop_out_point` replace the cost and duration lines with:

```gdscript
	assert_eq(p.cost, 40 + 7, "84 km is 6.72 lots of 12.5 km, rounded up")
	assert_almost_eq(p.duration, 18.0 + 84000.0 / 350000.0, 1e-6)
```

Replace `test_low_power_and_too_little_qe_are_refused` and `test_a_warp_into_low_power_warns_but_goes` with:

```gdscript
func test_low_power_and_too_little_qe_are_refused():
	_store.amount = 100
	assert_eq(_check(_from(), Vector3.LEFT, _near).status, WarpPlan.Status.LOW_POWER)
	_store.amount = 200
	var nose := UniversePoint.at(0, 0, -8000000).minus(_from()).normalized()
	var p := _check(_from(), nose, _distant)
	assert_eq(p.status, WarpPlan.Status.NO_QE, p.text())
	assert_gt(p.cost, 600, "7,800 km of travel")
	assert_eq(p.cost, WarpPlan.cost_of(p.distance))
	assert_eq(p.text(), "WARP · NEED %d QE" % p.cost)

func test_a_warp_into_low_power_warns_but_goes():
	var nose := UniversePoint.at(0, 0, -8000000).minus(_from()).normalized()
	_store.amount = WarpPlan.cost_of(_check(_from(), nose, _distant).distance) + 20
	var p := _check(_from(), nose, _distant)
	assert_eq(p.status, WarpPlan.Status.READY, p.text())
	assert_true(p.into_low_power)
	assert_eq(p.text(), "WARP READY · J · → LOW POWER")
```

Replace `test_the_cost_rounds_up_per_kilometre` with:

```gdscript
func test_the_cost_is_one_qe_per_12_5_km_rounded_up_and_exact():
	assert_eq(WarpPlan.cost_of(0.0), 40)
	assert_eq(WarpPlan.cost_of(1.0), 41)
	assert_eq(WarpPlan.cost_of(3000000.0), 280, "exactly 240 lots: 0.08 per km would round to 241")
	assert_eq(WarpPlan.cost_of(12500000.0), 1040)

func test_a_moon_s_limit_blocks_like_a_planet_s():
	var moon := _target(&"p1.m1", WarpTarget.Kind.MOON, Vector3(0, 0, 300000), 30000.0)
	_targets.append(moon)
	var p := _check(UniversePoint.at(0, 0, 500000), Vector3.FORWARD, _far)
	assert_eq(p.status, WarpPlan.Status.BLOCKED)
	assert_eq(p.blocker, moon)
```

Append to `who-knows/test/unit/test_warp_scene.gd` (the world scale spec §8.2; `_ready_above`, `_put` and `_run` are the file's own helpers):

```gdscript
func test_a_warp_to_a_moon_arrives_at_its_limit():
	if not _system.bodies.any(func(b: SystemBody) -> bool: return b.kind == SystemBody.Kind.MOON):
		pass_test("no moon in the flight test's system")
		return
	var t := _ready_above(WarpTarget.Kind.MOON)
	_ship.warp.engage()
	_run(WarpDrive.SPOOL + 1.0)
	_run(_ship.warp.time_left() + 0.1)
	await wait_physics_frames(2)
	assert_almost_eq(_focus().minus(t.point).length(), t.limit, 400.0)

## About 250 km/s at the peak, 4 km a tick: the origin must keep up
## (the world scale spec §3.4). WarpDrive re-centres it every step.
func test_a_long_warp_keeps_the_origin_up_at_full_speed():
	_ship.quantum.store.amount = _ship.quantum.store.capacity
	var planets := _system.planets()
	for a in planets:
		for b in planets:
			if a == b or a.point.minus(b.point).length() < 5000000.0:
				continue
			var toward := b.point.minus(a.point).normalized()
			_put(a.point.plus(toward * (a.warp_limit + 25000.0)), b.point)
			_ship.warp.chart(b.id)
			if _ship.warp.check().status != WarpPlan.Status.READY:
				continue
			_ship.warp.engage()
			_run(WarpDrive.SPOOL + 1.0)
			for k in 8:
				_run(3.0)
				assert_lt(_ship.exterior.global_position.length(), Universe.FORCE_AT,
					"the origin keeps up at %.0f km/s" % (_ship.warp.velocity().length() / 1000.0))
			return
	pass_test("no clear line of 5,000 km in this system")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `& .\who-knows\run_tests.ps1 -gtest=res://test/unit/test_warp_plan.gd`
Expected: FAIL (the cost is still 4 QE a km). The two scene tests may already pass; they pin behaviour that must survive the retune.

- [ ] **Step 3: Retune**

In `who-knows/src/flight/warp_profile.gd`:

```gdscript
## How fast a warp goes (docs/superpowers/specs/2026-09-28-warp-design.md
## §5.3; the world scale spec §3.4): it takes BASE_TIME and a second more per
## PACE metres, rising from EDGE_SPEED to its peak over RAMP seconds, holding,
## and easing back down over the last RAMP. The peak is whatever makes the
## distance come out exact. Pure.
##
## PACE keeps the median trip about 30 s at the world scale's distances.

const BASE_TIME := 18.0
const PACE := 350000.0
```

In `who-knows/src/flight/warp_plan.gd` replace `const WARP_PER_KM := 4.0` with:

```gdscript
## One QE for every this many metres of travel (the world scale spec §3.4):
## 0.08 QE a km, written this way round so the cost is exact -- 0.08 is not,
## and ceili(240.00000000000003) is 241.
const WARP_M_PER_QE := 12500.0
```

and `cost_of` with:

```gdscript
static func cost_of(travel: float) -> int:
	return WARP_BASE + ceili(maxf(travel, 0.0) / WARP_M_PER_QE)
```

Update the file's doc comment line about blocking: "the line blocked by the star, a planet or a moon". The blocking loop already skips only clusters, so moons block with no code change.

- [ ] **Step 4: Find and fix every other use of `WARP_PER_KM`**

Run: `git grep -n WARP_PER_KM`
Expected: only `.claude/skills/building-a-ship/ship_probe.gd` and `SKILL.md`/`reference.md`. Change the probe line now (the documents are Task 13):

```gdscript
	var reach_km := (s.quantum_capacity - WarpPlan.WARP_BASE) * WarpPlan.WARP_M_PER_QE / 1000.0
```

- [ ] **Step 5: Run the warp tests**

Run: `-gtest=res://test/unit/test_warp_profile.gd`, then `test_warp_plan.gd`, `test_warp_drive.gd`, `test_warp_scene.gd`.
Expected: PASS. Read the printed mean from `test_typical_trips_average_about_thirty_seconds`. If it is outside 25–35 s, change `PACE` (a larger `PACE` shortens trips) and record the value in the commit message; do not relax the test.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/flight who-knows/test/unit/test_warp_profile.gd who-knows/test/unit/test_warp_plan.gd who-knows/test/unit/test_warp_scene.gd .claude/skills/building-a-ship/ship_probe.gd
git commit -m "feat: world scale -- the warp paced and priced for thousands of kilometres"
```

---

### Task 3: Sensors, the map and the markers

**Files:**
- Modify: `who-knows/src/sensors/body_contacts.gd`, `src/ship/computer/map_page.gd`, `src/ui/body_marker.gd`, `src/ui/contact_marker.gd`
- Test: `who-knows/test/unit/test_map_page.gd`, `test_warp_hud.gd`

**Interfaces:**
- Consumes: moons as warp targets (Task 1); `WarpPlan.cost_of` (Task 2).
- Produces: `MapPage.RANGES = [2000, 10000, 50000, 500000, 20000000]`, `SYSTEM_RANGE = 4`, `SYSTEM_REACH = 9000000`, `SCALE_RING = 2500000`, `LARGE = 45000`, `MEDIUM = 30000`, `TARGET_KINDS` with `&"moon"`, `MapPage.flying_text(metres) -> String`; `BodyContacts.RANGE = 20000000`.

- [ ] **Step 1: Write the failing tests**

In `who-knows/test/unit/test_map_page.gd`:

In `test_between_placements_at_30_km_the_marks_turn_with_the_ship`: rename it `test_between_placements_at_50_km_the_marks_turn_with_the_ship` and change the expected position line to:

```gdscript
	assert_almost_eq(shown, Vector3(20000, 0, 0) * (HoloVolume.RADIUS / 50000.0), Vector3.ONE * 0.001)
```

In `test_the_system_range_shows_worlds_only_and_30_km_rocks_and_worlds`: rename it `test_the_system_range_shows_worlds_only_and_50_km_rocks_and_worlds`, and change `_page.range_index = MapPage.SYSTEM_RANGE - 1` to `_page.range_index = 2`.

In `test_worlds_are_drawn_in_their_own_colour_by_class_on_the_system_range`, replace the radii list, the star's radius and the last radius:

```gdscript
	for r in [[15000.0, &"small"], [35000.0, &"medium"], [50000.0, &"large"]]:
```

```gdscript
	c.radius = 250000.0
```

```gdscript
	c.radius = 60000.0
```

Replace `test_the_system_range_steps_through_warp_targets_only` with:

```gdscript
func test_the_system_range_steps_through_warp_targets_moons_included():
	var s := _with_system()
	var ids := _page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id)
	for t in s.warp_targets():
		assert_true(ids.has(t.contact_id()), "%s" % t.id)
	for b in s.bodies:
		if b.kind == SystemBody.Kind.MOON:
			assert_true(ids.has(BodyContacts.id_of(b)), "moons are targets at this scale")
```

In `test_the_screen_gives_size_distance_time_and_cost` replace the `lines[1]` assertion with:

```gdscript
	assert_true(lines[1].contains(" FLYING"), lines[1])
```

Append:

```gdscript
func test_the_ranges_reach_a_planet_s_moons_and_the_whole_system():
	assert_eq(MapPage.RANGES, [2000.0, 10000.0, 50000.0, 500000.0, 20000000.0] as Array[float])
	assert_eq(MapPage.SYSTEM_RANGE, MapPage.RANGES.size() - 1)
	assert_eq(MapPage.PLACE_EVERY.size(), MapPage.RANGES.size())
	assert_gte(BodyContacts.RANGE, MapPage.RANGES[MapPage.SYSTEM_RANGE])

func test_flying_time_reads_in_minutes_then_hours():
	assert_eq(MapPage.flying_text(72000.0), "10 MIN FLYING")
	assert_eq(MapPage.flying_text(10.0), "1 MIN FLYING")
	assert_eq(MapPage.flying_text(4600000.0), "11 H FLYING")

func test_a_moon_s_screen_says_moon_and_its_size():
	var s := _with_system()
	var moons := s.bodies.filter(func(b: SystemBody) -> bool: return b.kind == SystemBody.Kind.MOON)
	if moons.is_empty():
		pass_test("no moons in this seed")
		return
	var m: SystemBody = moons[0]
	_page.selected = BodyContacts.id_of(m)
	var lines := _page.lines(_ctx)
	assert_eq(lines[0], "%s · MOON · %d KM ACROSS" % [m.name, roundi(m.radius * 2.0 / 1000.0)])
```

In `who-knows/test/unit/test_warp_hud.gd`, in `test_the_contact_marker_leaves_worlds_and_clusters_to_the_body_marker`, change the moon line to:

```gdscript
	assert_false(ContactMarker.marks_kind(BodyContacts.MOON), "moons are warp targets: the body marker's")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `-gtest=res://test/unit/test_map_page.gd`
Expected: FAIL (`flying_text` not found, the ranges).

- [ ] **Step 3: Body contacts**

In `who-knows/src/sensors/body_contacts.gd`: `const RANGE := 20000000.0` ("The whole system, about 15,000 km across, and then some."), and change the `MOON` comment to `## Moons: warp targets at the world scale, kept apart so the map can size them.` Change the class doc's last sentence to: "Moons are kind MOON and clusters CLUSTER, so KIND is exactly the star and the planets."

- [ ] **Step 4: The map**

In `who-knows/src/ship/computer/map_page.gd`:

Class doc: "at 2, 10 or 30 km" becomes "at 2, 10, 50 or 500 km", and "scale rings every 50 km" becomes "scale rings every 2,500 km".

Constants:

```gdscript
const RANGES: Array[float] = [2000.0, 10000.0, 50000.0, 500000.0, 20000000.0]
## The last range is the whole system (the system skeleton spec §10): it asks
## the sensors for all of it, and is drawn round the star out to SYSTEM_REACH
## (the warp spec §7.1). 500 km holds a planet and its moons (the world scale
## spec §3.5).
const SYSTEM_RANGE := 4
const SYSTEM_REACH := 9000000.0
## Rings of faint ticks round the ship, every SCALE_RING out to the rim.
const SCALE_RING := 2500000.0
```

```gdscript
## A planet this big is large; this big, medium (the world scale spec §3.1).
const LARGE := 45000.0
const MEDIUM := 30000.0
```

```gdscript
const TARGET_KINDS: Array[StringName] = [&"body", &"moon", &"cluster"]
```

```gdscript
const PLACE_EVERY: Array[float] = [0.0, 0.0, 0.5, 0.5, 0.5]
```

In `targets()`, replace

```gdscript
		if range_index == SYSTEM_RANGE - 1 and not [&"rock", &"body", &"moon", &"cluster"].has(c.kind):
```

with

```gdscript
		if range_index >= 2 and range_index < SYSTEM_RANGE and not [&"rock", &"body", &"moon", &"cluster"].has(c.kind):
```

and update its doc comment: "The 50 and 500 km ranges show big rocks and worlds only".

In `_place`, delete the line `_place_moons(volume, ctx, frame)` and delete the whole `_place_moons` function: moons are targets now and are drawn in the list, sized by `mark_size`.

In `warp_lines`, replace the `match t.kind:` block and the `how` line with:

```gdscript
	match t.kind:
		WarpTarget.Kind.STAR:
			what = "STAR · %d KM ACROSS" % roundi(t.radius * 2.0 / 1000.0)
		WarpTarget.Kind.CLUSTER:
			what = "BELT · %d KM ACROSS" % roundi(t.radius * 2.0 / 1000.0)
		WarpTarget.Kind.MOON:
			what = "MOON · %d KM ACROSS" % roundi(t.radius * 2.0 / 1000.0)
		_:
			var cls := String(size_class_of_radius(t.radius)).to_upper()
			what = "PLANET · %s · %d KM ACROSS" % [cls, roundi(t.radius * 2.0 / 1000.0)]
	var travel := d - t.limit
	var how := "%d KM · %s" % [roundi(d / 1000.0), flying_text(d)]
```

Add after `warp_lines`:

```gdscript
## How long `metres` takes at the cruise ceiling: minutes, or hours past 90
## minutes -- most trips at the world scale are hours of flying, which is
## why you warp.
static func flying_text(metres: float) -> String:
	var minutes := metres / FlightComputer.CRUISE_LIMIT_MPS / 60.0
	if minutes > 90.0:
		return "%d H FLYING" % roundi(minutes / 60.0)
	return "%d MIN FLYING" % maxi(1, roundi(minutes))
```

- [ ] **Step 5: The markers**

In `who-knows/src/ui/body_marker.gd`, change the skip to

```gdscript
			if c.id == sensors.course:
				continue
```

and the class doc's first line to "Every warp target in view, moons included (the world scale spec §3.3), bracketed and named with its distance".

In `who-knows/src/ui/contact_marker.gd`:

```gdscript
static func marks_kind(kind: StringName) -> bool:
	return kind != RockContacts.KIND and kind != BodyContacts.KIND and kind != BodyContacts.CLUSTER \
		and kind != BodyContacts.MOON
```

and add to its doc comment: "Nor worlds, moons or clusters: they are warp targets, and BodyMarker brackets them."

- [ ] **Step 6: Run the tests**

Run: `-gtest=res://test/unit/test_map_page.gd`, `test_warp_hud.gd`, `test_body_contacts.gd`, `test_system_scene.gd`.
Expected: PASS except `test_system_scene.gd`'s tests that depend on Task 4 (none should; if `test_the_sensors_know_every_world` fails, it is because `RANGES[SYSTEM_RANGE]` grew: it should now pass with more worlds).

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/sensors who-knows/src/ship/computer/map_page.gd who-knows/src/ui who-knows/test/unit/test_map_page.gd who-knows/test/unit/test_warp_hud.gd
git commit -m "feat: world scale -- the map and markers for a system 15,000 km across"
```

---

### Task 4: Seeing that far

**Files:**
- Modify: `who-knows/src/world/body_proxy.gd`, `belt_look.gd`, `ring_look.gd`, `who-knows/scenes/flight_test.gd`
- Test: `who-knows/test/unit/test_floating_origin_scene.gd`, `test_body_proxy.gd`

**Interfaces:**
- Produces: `BodyProxy.VIEW_FAR = 400000.0` (the cameras' far plane) and `BodyProxy.PROXY_AT = 350000.0`.

- [ ] **Step 1: Write the failing test**

In `who-knows/test/unit/test_floating_origin_scene.gd` append to `test_the_cameras_outside_see_as_far_as_rocks_are_drawn`:

```gdscript
	# The world scale spec §5.2: far enough for the horizon of the world
	# you are over, and past every proxy.
	assert_gt(BodyProxy.VIEW_FAR, BodyProxy.PROXY_AT)
	for path in ["Ship/Exterior/ChaseCamera", "Ship/Canopy/CanopyCam"]:
		assert_eq((_root.get_node(path) as Camera3D).far, BodyProxy.VIEW_FAR, path)
	assert_eq(_avatar.camera.far, BodyProxy.VIEW_FAR, "on a spacewalk")
```

In `who-knows/test/unit/test_body_proxy.gd`, rename `test_the_two_rules_meet_at_28_km` to `test_the_two_rules_meet_at_proxy_at` and change the file's doc comment to "within PROXY_AT; beyond, along the same direction at PROXY_AT". In `test_far_off_it_keeps_its_direction_and_angular_size`, replace the focus and origin lines with points beyond 350 km:

```gdscript
	var focus := b.point.plus(Vector3(-900000, 2500, 400000))
	_universe.origin = focus.plus(Vector3(0, -500, 1000))
```

In `test_a_shift_changes_nothing_you_see`, change the focus offset to `Vector3(3000, 4000, 600000)`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `-gtest=res://test/unit/test_floating_origin_scene.gd`
Expected: FAIL (`VIEW_FAR` not found).

- [ ] **Step 3: Proxies and the far plane**

In `who-knows/src/world/body_proxy.gd` replace the `PROXY_AT` block with:

```gdscript
## The cameras' far plane outside (the world scale spec §5.2): the horizon of
## a 60 km world seen from its warp limit is about 120 km away, and every
## proxy sits inside it. Godot 4.5's Forward+ draws with reversed depth, so
## this far costs no precision up close.
const VIEW_FAR := 400000.0
## Beyond the giant rocks' fade and inside VIEW_FAR: a body farther than this
## is drawn here, along its true direction, scaled to its true angular size.
const PROXY_AT := 350000.0
```

and its doc comment's first sentence to "at its true place and size when within PROXY_AT of the focus". `NEAR_WITHIN` (6 km) stays for now: Task 9 replaces the near shell.

In `who-knows/scenes/flight_test.gd` replace the camera loop comment and body:

```gdscript
	# Godot's cameras stop drawing at 4 km; a world's horizon is 100 km off
	# and every proxy sits at 350 km (the world scale spec §5.2).
	for cam: Camera3D in [$Ship/Exterior/ChaseCamera, $Ship/Canopy/CanopyCam, _avatar.camera]:
		cam.far = BodyProxy.VIEW_FAR
```

and in the `hop()` doc comment replace "A system is 300 km across; this stands in for cruise until cruise exists." with "A system is 15,000 km across; this is the debug way round it."

- [ ] **Step 4: Belt and ring looks at the new sizes**

In `who-knows/src/world/belt_look.gd`:

```gdscript
const SLABS := 320
## A slab's size: across, and thick. Each stands for tens of kilometres of a
## belt 40-80 km wide (the world scale spec §3.5); tuned at the renders.
const SLAB_ACROSS := Vector2(8000.0, 16000.0)
const SLAB_THICK := 1500.0
```

In `who-knows/src/world/ring_look.gd`:

```gdscript
## Slabs in a ring, and their size: across, and thick. A ring is 10-30 km
## wide at the world scale (spec §3.5); tuned at the renders.
const SLABS := 128
const SLAB_ACROSS := Vector2(1500.0, 3000.0)
const SLAB_THICK := 60.0
```

- [ ] **Step 5: Run the view tests**

Run: `-gtest=res://test/unit/test_floating_origin_scene.gd`, `test_body_proxy.gd`, `test_star_system.gd`, `test_system_scene.gd`, `test_warp_scene.gd`.
Expected: PASS.

- [ ] **Step 6: Run the whole suite**

Run: `& .\who-knows\run_tests.ps1`
Expected: `---- All tests passed! ----`, output pristine, exit code 0.

- [ ] **Step 7: Fly it, and stop for the owner**

Run the game (the `run` skill, or Godot's editor with `flight_test.tscn`) and warp from the start to a planet and on to its moon. Then send the owner three screenshots taken with `test/probes/system_render.gd` (its usage line is in its header): the start, a planet from its limit, and the belts from above. **Part A is flyable here: ask the owner whether the sizes and spacing feel right before Part B.** Numbers are cheap to change now (spec §10).

- [ ] **Step 8: Commit**

```bash
git add who-knows/src/world who-knows/scenes/flight_test.gd who-knows/test/unit/test_floating_origin_scene.gd who-knows/test/unit/test_body_proxy.gd
git commit -m "feat: world scale -- see 400 km out, proxies at 350 km, belts and rings resized"
```

---

# Part B — the ground

### Task 5: `WorldTerrain`, and the far mesh drawn from it

**Files:**
- Create: `who-knows/src/world/world_terrain.gd`, `who-knows/test/unit/test_world_terrain.gd`
- Modify: `who-knows/src/world/body_look.gd`, `who-knows/test/unit/test_body_proxy.gd`, `test_visual_style_rules.gd`

**Interfaces:**
- Produces:
  - `WorldTerrain.new(recipe: WorldRecipe)`; `radius: float`, `relief: float`, `recipe`; `height_at(dir: Vector3) -> float` (metres above `radius`, within ±`relief / 2`); `colour_at(dir: Vector3, slope: float, patch_m: float) -> Color`; `ground_at(dir: Vector3, slope: float) -> StringName`; `altitude_of(local: Vector3) -> float`; `const PATCH_QUADS := 6.0`, `const CRATER_FLOOR := 0.78`, `craters: Array` of `[Vector3 dir, float angular radius]`.
  - `BodyLook.FAR_DETAIL = 3` (1,280 faces), vertices lifted by the terrain. `BodyLook.NEAR_DETAIL` and `points()` stay until Task 10.

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_world_terrain.gd`:

```gdscript
extends GutTest

## A world's ground (the world scale spec §4): the same for the same recipe,
## within its relief, altitude agreeing with height, and every colour from its
## palette.

func _recipe(seed: int, archetype := -1) -> WorldRecipe:
	var k := seed
	while true:
		var r := WorldRecipe.from_seed(k)
		if archetype < 0 or r.archetype == archetype:
			return r
		k += 1
	return null

static func _dir(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if v.length() > 0.1 and v.length() <= 1.0:
			return v.normalized()
	return Vector3.UP

func test_the_same_recipe_gives_the_same_ground():
	var r := _recipe(1337)
	var a := WorldTerrain.new(r)
	var b := WorldTerrain.new(r)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 50:
		var d := _dir(rng)
		assert_eq(a.height_at(d), b.height_at(d))
		assert_eq(a.colour_at(d, 0.1, 50.0), b.colour_at(d, 0.1, 50.0))

func test_heights_stay_within_the_relief_and_vary():
	for seed in [11, 12, 13, 14]:
		var t := WorldTerrain.new(_recipe(seed))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var lo := INF
		var hi := -INF
		for i in 1500:
			var h := t.height_at(_dir(rng))
			lo = minf(lo, h)
			hi = maxf(hi, h)
		assert_gte(lo, -t.relief * 0.5 - 0.001)
		assert_lte(hi, t.relief * 0.5 + 0.001)
		assert_gt(hi - lo, t.relief * 0.25, "seed %d: a world, not a ball" % seed)

func test_altitude_agrees_with_height():
	var t := WorldTerrain.new(_recipe(21))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 50:
		var d := _dir(rng)
		var p := d * (t.radius + t.height_at(d) + 25.0)
		assert_almost_eq(t.altitude_of(p), 25.0, 0.05)

func test_every_colour_comes_from_the_palette():
	var r := _recipe(31)
	var t := WorldTerrain.new(r)
	var palette: Dictionary = SpacePalette.WORLDS[r.palette]
	var allowed: Array[Color] = []
	for key in [&"ground_low", &"ground_high", &"rock", &"dust"]:
		for k in SpacePalette.SHADES.size():
			allowed.append(SpacePalette.shade(palette[key], k))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 200:
		var c := t.colour_at(_dir(rng), rng.randf_range(0.0, 1.2), rng.randf_range(10.0, 50000.0))
		assert_true(allowed.has(c), "a colour from outside the palette: %s" % c)

func test_steep_ground_is_bare_rock():
	var t := WorldTerrain.new(_recipe(41))
	assert_eq(t.ground_at(Vector3.UP, deg_to_rad(50.0)), &"rock")

func test_a_crater_seen_from_afar_is_a_real_bowl():
	var t := WorldTerrain.new(_recipe(51, WorldRecipe.Archetype.CRATERED))
	assert_gt(t.craters.size(), 0)
	var c: Array = t.craters[0]
	var centre: Vector3 = c[0]
	var size: float = c[1]
	var side := centre.cross(Vector3.UP if absf(centre.y) < 0.9 else Vector3.RIGHT).normalized()
	var rim := centre.rotated(side, size * (WorldTerrain.CRATER_FLOOR + 1.0) * 0.5)
	assert_lt(t.height_at(centre), t.height_at(rim), "the floor is below the rim")
	assert_eq(t.ground_at(centre, 0.0), &"rock", "and painted as the far pattern paints it")
```

In `who-knows/test/unit/test_body_proxy.gd`, in `test_every_face_takes_a_colour_from_its_palette`, change `320 * 3` to `1280 * 3`. In `test_shades_come_in_patches_not_triangle_by_triangle`, change `BodyLook.NEAR_DETAIL` to `BodyLook.FAR_DETAIL`. Append:

```gdscript
func test_the_far_mesh_is_lifted_by_the_real_ground():
	# The world scale spec §5.1: the far mesh is sampled from WorldTerrain.
	var b := _planet()
	var t := WorldTerrain.new(b.recipe)
	var positions: PackedVector3Array = BodyLook.mesh(b, BodyLook.FAR_DETAIL).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0, positions.size(), 97):
		var p := positions[i]
		assert_almost_eq(p.length(), 1.0 + t.height_at(p) / t.radius, 1e-4)
```

In `who-knows/test/unit/test_visual_style_rules.gd`, add to `PAINTING_FILES` after `"res://src/world/body_look.gd",`:

```gdscript
	"res://src/world/world_terrain.gd",
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `-gtest=res://test/unit/test_world_terrain.gd`
Expected: FAIL (`WorldTerrain` not found).

- [ ] **Step 3: Write `WorldTerrain`**

Create `who-knows/src/world/world_terrain.gd`:

```gdscript
class_name WorldTerrain
extends RefCounted

## The ground of one world (docs/superpowers/specs/2026-09-30-world-scale-design.md
## §4): how high it is, what colour it is, and how far above it a point is.
## Pure and deterministic: the same on every machine. Everything that needs
## the ground asks this -- the far mesh, the surface's chunks, collision, the
## analytic floor and the speed limit -- never each other.
##
## Not thread-safe (FastNoiseLite is not): each thread makes its own from the
## same recipe, and they all agree.
##
## A height is metres above radius_m, within half the relief either way: a
## continent layer the size of the world under the archetype's own hills,
## and for a cratered world the same craters its far pattern paints. The
## colours are that pattern -- patches, bands, plateaus, craters (style guide
## §3.5) -- with steep ground bare rock, in shade patches a few triangles
## across at every detail.

## Continents: this many across the unit sphere.
const CONTINENT_SCALE := 1.4
## The archetype's hills: the biggest this many metres across, and octaves
## down to the smallest.
const HILL_WAVE := 4000.0
const HILL_OCTAVES := 7
## How the relief is shared between continents and hills.
const CONTINENT_SHARE := 0.45
const HILL_SHARE := 0.55
## Mesa terraces: how many, and the flat share of each.
const TERRACES := 4
const TERRACE_FLAT := 0.8
## A cratered world's hills are this much gentler.
const CRATERED_HILLS := 0.4
## A crater's bowl and rim, as shares of the relief's half.
const CRATER_DEPTH := 0.8
const CRATER_RIM := 0.25
## Of a crater's width, the dark floor; the rest is its light rim.
const CRATER_FLOOR := 0.78
## Craters: how many, and how wide, in radians round the sphere.
const CRATERS := Vector2i(5, 9)
const CRATER_SIZE := Vector2(0.12, 0.35)
## Ridged bands of colour: how many round the sphere.
const BANDS := 9.0
## How finely the colour pattern varies over the unit sphere.
const PATTERN_SCALE := 1.6
## Steeper than this, the ground is bare rock.
const ROCK_SLOPE := deg_to_rad(35.0)
## A shade patch is this many triangles across, so shades come in broad
## patches at every detail, never triangle by triangle.
const PATCH_QUADS := 6.0

var recipe: WorldRecipe
var radius: float
var relief: float
var archetype: WorldRecipe.Archetype
var palette: Dictionary
## [centre direction, angular radius] per crater; empty unless CRATERED.
var craters: Array = []
var band_axis := Vector3.UP

var _continents := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _pattern := FastNoiseLite.new()
var _shades := FastNoiseLite.new()

func _init(p_recipe: WorldRecipe) -> void:
	recipe = p_recipe
	radius = recipe.radius_m
	relief = recipe.relief_m
	archetype = recipe.archetype
	palette = SpacePalette.WORLDS[recipe.palette]
	_continents.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"continents"))
	_continents.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continents.frequency = 1.0
	_continents.fractal_type = FastNoiseLite.FRACTAL_FBM
	_continents.fractal_octaves = 3
	_hills.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"terrain"))
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 1.0
	_hills.fractal_octaves = HILL_OCTAVES
	_hills.fractal_type = FastNoiseLite.FRACTAL_RIDGED if archetype == WorldRecipe.Archetype.RIDGED \
		else FastNoiseLite.FRACTAL_FBM
	# The far pattern keeps the sub-seeds it always had, so a world looks as
	# it did from afar.
	_pattern.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"look"))
	_pattern.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_pattern.frequency = 1.0
	_pattern.fractal_type = FastNoiseLite.FRACTAL_FBM
	_pattern.fractal_octaves = 2
	_shades.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"shades"))
	_shades.noise_type = FastNoiseLite.TYPE_CELLULAR
	_shades.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_shades.frequency = 1.0
	_shades.fractal_type = FastNoiseLite.FRACTAL_NONE
	var rng := WorldSeed.rng(recipe.seed, &"marks")
	band_axis = _direction(rng)
	if archetype == WorldRecipe.Archetype.CRATERED:
		for i in rng.randi_range(CRATERS.x, CRATERS.y):
			craters.append([_direction(rng), rng.randf_range(CRATER_SIZE.x, CRATER_SIZE.y)])

## Metres above radius at `dir`, within half the relief either way.
func height_at(dir: Vector3) -> float:
	var d := dir.normalized()
	var continent := _continents.get_noise_3dv(d * CONTINENT_SCALE)
	var hills := _hills.get_noise_3dv(d * (radius / HILL_WAVE))
	match archetype:
		WorldRecipe.Archetype.MESA:
			hills = _terrace(hills)
		WorldRecipe.Archetype.CRATERED:
			hills = hills * CRATERED_HILLS + _crater(d)
	return relief * 0.5 * clampf(CONTINENT_SHARE * continent + HILL_SHARE * hills, -1.0, 1.0)

## How far `local` (from the world's centre) is above the ground under it.
func altitude_of(local: Vector3) -> float:
	if local.is_zero_approx():
		return -radius
	return local.length() - (radius + height_at(local))

## Which of the palette's grounds faces `dir` on ground this steep (radians).
func ground_at(dir: Vector3, slope: float) -> StringName:
	if slope > ROCK_SLOPE:
		return &"rock"
	var d := dir.normalized()
	var n := _pattern.get_noise_3dv(d * PATTERN_SCALE)
	match archetype:
		WorldRecipe.Archetype.RIDGED:
			var band := sin(d.dot(band_axis) * BANDS + n * 2.5)
			if band > 0.75:
				return &"rock"
			return &"ground_high" if band > 0.05 else &"ground_low"
		WorldRecipe.Archetype.MESA:
			if absf(n - 0.05) < 0.06:
				return &"rock"
			return &"ground_high" if n > 0.05 else &"ground_low"
		WorldRecipe.Archetype.CRATERED:
			for c: Array in craters:
				var angle := d.angle_to(c[0])
				if angle < float(c[1]) * CRATER_FLOOR:
					return &"rock"
				if angle < float(c[1]):
					return &"ground_high"
			return &"dust" if n > 0.2 else &"ground_low"
	if n < -0.45:
		return &"rock"
	return &"ground_high" if n > 0.1 else &"ground_low"

## The colour of ground facing `dir`, this steep, in shade patches about
## `patch_m` metres across.
func colour_at(dir: Vector3, slope: float, patch_m: float) -> Color:
	var d := dir.normalized()
	var base: Color = palette[ground_at(d, slope)]
	var cell := (_shades.get_noise_3dv(d * (radius / maxf(patch_m, 1.0))) + 1.0) * 0.5
	var k := clampi(floori(cell * SpacePalette.SHADES.size()), 0, SpacePalette.SHADES.size() - 1)
	return SpacePalette.shade(base, k)

## Mesa: flat steps with steep risers.
func _terrace(h: float) -> float:
	var t := (h + 1.0) * 0.5 * TERRACES
	var step := floorf(t)
	var f := t - step
	var rise := 0.0 if f < TERRACE_FLAT else (f - TERRACE_FLAT) / (1.0 - TERRACE_FLAT)
	return (step + rise) / TERRACES * 2.0 - 1.0

## Every crater's bowl and rim at `d`.
func _crater(d: Vector3) -> float:
	var out := 0.0
	for c: Array in craters:
		var t := d.angle_to(c[0]) / float(c[1])
		if t >= 1.0:
			continue
		if t < CRATER_FLOOR:
			var k := t / CRATER_FLOOR
			out -= CRATER_DEPTH * (1.0 - k * k)
		else:
			out += CRATER_RIM * sin(PI * (t - CRATER_FLOOR) / (1.0 - CRATER_FLOOR))
	return out

static func _direction(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if v.length() > 0.2 and v.length() <= 1.0:
			return v.normalized()
	return Vector3.UP
```

- [ ] **Step 4: Draw the far mesh from it**

Replace the whole of `who-knows/src/world/body_look.gd` with:

```gdscript
class_name BodyLook
extends RefCounted

## What a star, planet or moon looks like from afar (the system skeleton spec
## §7.2; the world scale spec §5.1): a faceted icosphere, flat-shaded, each
## face one colour. A world's far mesh is sampled from its WorldTerrain -- the
## same heights, patterns and craters its surface has up close -- so the
## hand-over to the surface changes a pixel or two. The star is one colour of
## its palette in broad shade patches. No texture, no noise on the surface
## itself: shape and flat colour carry it.
##
## Meshes are radius one; a proxy scales them.

## Subdivisions: a world from afar (1,280 faces), up close until the surface
## replaces it (5,120), and the star (1,280).
const FAR_DETAIL := 3
const NEAR_DETAIL := 4
const STAR_DETAIL := 3
## How finely the star's shade patches vary over it.
const SHADE_SCALE := 2.2

static var _materials := {}

## The mesh for `body` at `detail` subdivisions, radius one.
static func mesh(body: SystemBody, detail: int) -> ArrayMesh:
	var sphere := RockMesh.sphere(detail)
	var dirs: PackedVector3Array = sphere[0]
	var faces: PackedInt32Array = sphere[1]
	var terrain: WorldTerrain = WorldTerrain.new(body.recipe) if body.recipe != null else null
	var shades := _star_shades(body) if terrain == null else null
	var lifted := PackedVector3Array()
	lifted.resize(dirs.size())
	for i in dirs.size():
		lifted[i] = dirs[i] if terrain == null else dirs[i] * (1.0 + terrain.height_at(dirs[i]) / terrain.radius)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for t in range(0, faces.size(), 3):
		var a := lifted[faces[t]]
		var b := lifted[faces[t + 1]]
		var c := lifted[faces[t + 2]]
		var cross := (b - a).cross(c - a)
		if cross.dot(a + b + c) > 0.0:
			# Godot draws the side (b - a) x (c - a) points away from.
			var swap := b
			b = c
			c = swap
			cross = -cross
		var n := -cross.normalized()
		var mid := (a + b + c).normalized()
		var colour: Color
		if terrain == null:
			colour = _star_colour(body, shades, mid)
		else:
			var patch := (a - b).length() * terrain.radius * WorldTerrain.PATCH_QUADS
			colour = terrain.colour_at(mid, n.angle_to(mid), patch)
		positions.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([n, n, n]))
		colours.append_array(PackedColorArray([colour, colour, colour]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## The shell's distinct points at `detail`, radius one: the near collision
## hull, until the surface's own collision replaces it.
static func points(detail: int) -> PackedVector3Array:
	return RockMesh.sphere(detail)[0]

## The material every world shares: its vertex colours, lit by the sun. The
## star's is unshaded: it is the light, and is never in shadow.
static func material(star: bool) -> StandardMaterial3D:
	if not _materials.has(star):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		if star:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[star] = m
	return _materials[star]

static func _star_shades(body: SystemBody) -> FastNoiseLite:
	var shades := FastNoiseLite.new()
	shades.seed = WorldSeed.noise_seed(WorldSeed.sub(body.seed, &"shades"))
	shades.noise_type = FastNoiseLite.TYPE_CELLULAR
	shades.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	shades.frequency = 1.0
	shades.fractal_type = FastNoiseLite.FRACTAL_NONE
	return shades

static func _star_colour(body: SystemBody, shades: FastNoiseLite, d: Vector3) -> Color:
	var base: Color = SpacePalette.STARS[body.star_palette][&"body"]
	var cell := (shades.get_noise_3dv(d * SHADE_SCALE) + 1.0) * 0.5
	return SpacePalette.shade(base, clampi(floori(cell * SpacePalette.SHADES.size()), 0, SpacePalette.SHADES.size() - 1))
```

- [ ] **Step 5: Run the tests**

Run: `-gtest=res://test/unit/test_world_terrain.gd`, `test_body_proxy.gd`, `test_star_system.gd`, `test_visual_style_rules.gd`.
Expected: PASS. If `test_shades_come_in_patches_not_triangle_by_triangle` falls below 0.6, raise `PATCH_QUADS` to 8 and rerun (a bigger patch is broader).

- [ ] **Step 6: Run the whole suite, then commit**

Run: `& .\who-knows\run_tests.ps1` — expected all passing.

```bash
git add who-knows/src/world/world_terrain.gd who-knows/src/world/body_look.gd who-knows/test/unit/test_world_terrain.gd who-knows/test/unit/test_body_proxy.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: world scale -- WorldTerrain, and far meshes drawn from the real ground"
```

---

### Task 6: `CubeSphere`

**Files:**
- Create: `who-knows/src/world/cube_sphere.gd`, `who-knows/test/unit/test_cube_sphere.gd`

**Interfaces:**
- Produces (all static; a node key is `Vector4i(face, depth, ix, iy)`):
  - `const FACES := 6`, `const QUADS := 16`, `const FINEST_QUAD := 2.0`, `const AXES` (per face `[normal, u axis, v axis]`).
  - `direction(face: int, u: float, v: float) -> Vector3` (unit; u, v in [-1, 1]).
  - `face_uv(dir: Vector3) -> Vector3` (x = face, y = u, z = v).
  - `key_for(dir: Vector3, depth: int) -> Vector4i`.
  - `node_rect(key: Vector4i) -> Vector3` (x = u0, y = v0, z = size in face units).
  - `children(key) -> Array[Vector4i]`, `parent(key) -> Vector4i`.
  - `depth_for(radius: float) -> int`, `edge_m(radius: float, depth: int) -> float`.
  - `node_bound(key, radius: float, relief: float) -> Array` (`[Vector3 centre, float radius]`, body-local).

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_cube_sphere.gd`:

```gdscript
extends GutTest

## The cube-sphere and its quadtree (Planetfall §6.4; the world scale spec
## §5.2): unit directions, a round trip back to the face, depths per radius,
## and children that tile their parent exactly.

func test_directions_are_unit_and_face_centres_are_the_axes():
	for f in CubeSphere.FACES:
		assert_true(CubeSphere.direction(f, 0.0, 0.0).is_equal_approx(CubeSphere.AXES[f][0]))
		for uv in [Vector2(-1, -1), Vector2(0.3, -0.7), Vector2(1, 1), Vector2(-0.99, 0.5)]:
			assert_almost_eq(CubeSphere.direction(f, uv.x, uv.y).length(), 1.0, 1e-6)

func test_a_direction_goes_back_to_its_face_and_place():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 300:
		var f := rng.randi_range(0, 5)
		var u := rng.randf_range(-0.98, 0.98)
		var v := rng.randf_range(-0.98, 0.98)
		var back := CubeSphere.face_uv(CubeSphere.direction(f, u, v))
		assert_eq(int(back.x), f)
		assert_almost_eq(back.y, u, 1e-4)
		assert_almost_eq(back.z, v, 1e-4)

func test_the_finest_quad_is_about_two_metres():
	assert_eq(CubeSphere.depth_for(60000.0), 12)
	assert_eq(CubeSphere.depth_for(15000.0), 10)
	assert_eq(CubeSphere.depth_for(4000.0), 8)
	for r in [4000.0, 15000.0, 37000.0, 60000.0]:
		var quad := CubeSphere.edge_m(r, CubeSphere.depth_for(r)) / CubeSphere.QUADS
		assert_between(quad, 1.0, CubeSphere.FINEST_QUAD)

func test_children_tile_their_parent_and_know_it():
	var key := Vector4i(3, 2, 1, 2)
	var rect := CubeSphere.node_rect(key)
	var area := 0.0
	for c in CubeSphere.children(key):
		assert_eq(CubeSphere.parent(c), key)
		assert_eq(c.y, 3)
		var r := CubeSphere.node_rect(c)
		assert_between(r.x, rect.x - 1e-9, rect.x + rect.z)
		assert_between(r.y, rect.y - 1e-9, rect.y + rect.z)
		area += r.z * r.z
	assert_almost_eq(area, rect.z * rect.z, 1e-12)

func test_a_node_s_centre_finds_the_node():
	for key in [Vector4i(0, 0, 0, 0), Vector4i(2, 3, 5, 1), Vector4i(5, 6, 63, 0), Vector4i(1, 4, 7, 15)]:
		var rect := CubeSphere.node_rect(key)
		var d := CubeSphere.direction(key.x, rect.x + rect.z * 0.5, rect.y + rect.z * 0.5)
		assert_eq(CubeSphere.key_for(d, key.y), key)

func test_a_node_s_bound_holds_its_corners_and_relief():
	var key := Vector4i(4, 3, 2, 6)
	var b := CubeSphere.node_bound(key, 20000.0, 400.0)
	var centre: Vector3 = b[0]
	var r: float = b[1]
	var rect := CubeSphere.node_rect(key)
	for k in 4:
		var corner := CubeSphere.direction(key.x, rect.x + rect.z * float(k & 1), rect.y + rect.z * float(k >> 1))
		assert_lte((corner * 20200.0).distance_to(centre), r + 0.01)
		assert_lte((corner * 19800.0).distance_to(centre), r + 0.01)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `-gtest=res://test/unit/test_cube_sphere.gd`
Expected: FAIL (`CubeSphere` not found).

- [ ] **Step 3: Write `CubeSphere`**

Create `who-knows/src/world/cube_sphere.gd`:

```gdscript
class_name CubeSphere
extends RefCounted

## The six faces of a cube pushed out onto a sphere, and the quadtree on each
## (Planetfall §6.4; docs/superpowers/specs/2026-09-30-world-scale-design.md
## §5.2). Pure. A node is Vector4i(face, depth, ix, iy): at depth d a face is
## 2^d nodes across, each covering u from -1 + ix * 2 / 2^d over 2 / 2^d, and
## v likewise. The spherified-cube mapping keeps cells nearly even in size.
##
## Neighbouring faces meet exactly: the cube point on one face's edge is
## computed from the same numbers on the other's, so shared edges agree to
## the last bit.

const FACES := 6
## Quads along a chunk's edge.
const QUADS := 16
## The finest quad, metres, at most.
const FINEST_QUAD := 2.0
## Per face: its outward axis, then its u and v axes.
const AXES := [
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
]

## The unit direction at (u, v) on `face`.
static func direction(face: int, u: float, v: float) -> Vector3:
	var axes: Array = AXES[face]
	var p: Vector3 = axes[0] + axes[1] * u + axes[2] * v
	var x2 := p.x * p.x
	var y2 := p.y * p.y
	var z2 := p.z * p.z
	return Vector3(
		p.x * sqrt(maxf(0.0, 1.0 - y2 * 0.5 - z2 * 0.5 + y2 * z2 / 3.0)),
		p.y * sqrt(maxf(0.0, 1.0 - z2 * 0.5 - x2 * 0.5 + z2 * x2 / 3.0)),
		p.z * sqrt(maxf(0.0, 1.0 - x2 * 0.5 - y2 * 0.5 + x2 * y2 / 3.0)))

## The face a direction lies on.
static func face_of(d: Vector3) -> int:
	var a := d.abs()
	if a.x >= a.y and a.x >= a.z:
		return 0 if d.x > 0.0 else 1
	if a.y >= a.z:
		return 2 if d.y > 0.0 else 3
	return 4 if d.z > 0.0 else 5

## Vector3(face, u, v) for `dir`: the plain cube projection, refined by a few
## Newton steps onto the spherified mapping.
static func face_uv(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var face := face_of(d)
	var axes: Array = AXES[face]
	var k: float = d.dot(axes[0])
	var u: float = d.dot(axes[1]) / k
	var v: float = d.dot(axes[2]) / k
	for i in 6:
		var p := direction(face, u, v)
		var e := d - p
		if e.length() < 1e-7:
			break
		var h := 1e-4
		var du := (direction(face, u + h, v) - p) / h
		var dv := (direction(face, u, v + h) - p) / h
		var a11 := du.dot(du)
		var a12 := du.dot(dv)
		var a22 := dv.dot(dv)
		var b1 := du.dot(e)
		var b2 := dv.dot(e)
		var det := a11 * a22 - a12 * a12
		if absf(det) < 1e-12:
			break
		u += (a22 * b1 - a12 * b2) / det
		v += (a11 * b2 - a12 * b1) / det
	return Vector3(face, clampf(u, -1.0, 1.0), clampf(v, -1.0, 1.0))

## The node at `depth` holding `dir`.
static func key_for(dir: Vector3, depth: int) -> Vector4i:
	var fuv := face_uv(dir)
	var n := 1 << depth
	var ix := clampi(floori((fuv.y + 1.0) * 0.5 * n), 0, n - 1)
	var iy := clampi(floori((fuv.z + 1.0) * 0.5 * n), 0, n - 1)
	return Vector4i(int(fuv.x), depth, ix, iy)

## Vector3(u0, v0, size): where a node starts on its face, and its width.
static func node_rect(key: Vector4i) -> Vector3:
	var size := 2.0 / float(1 << key.y)
	return Vector3(-1.0 + key.z * size, -1.0 + key.w * size, size)

static func children(key: Vector4i) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	for k in 4:
		out.append(Vector4i(key.x, key.y + 1, key.z * 2 + (k & 1), key.w * 2 + (k >> 1)))
	return out

static func parent(key: Vector4i) -> Vector4i:
	return Vector4i(key.x, key.y - 1, key.z >> 1, key.w >> 1)

## The depth whose quads are FINEST_QUAD or less on a world of `radius`
## (Planetfall §6.4): 12 at 60 km, 10 at 15 km, 8 for a 4 km moon.
static func depth_for(radius: float) -> int:
	return ceili(log(PI * radius / (2.0 * QUADS * FINEST_QUAD)) / log(2.0))

## A node's edge at `depth` on a world of `radius`, metres: a face spans a
## quarter of a great circle.
static func edge_m(radius: float, depth: int) -> float:
	return PI * radius * 0.5 / float(1 << depth)

## [centre, radius] of a sphere, body-local, holding all of a node's ground
## on a world of `radius` whose ground lies within `relief` / 2 of it.
static func node_bound(key: Vector4i, radius: float, relief: float) -> Array:
	var rect := node_rect(key)
	var mid := direction(key.x, rect.x + rect.z * 0.5, rect.y + rect.z * 0.5) * radius
	var r := 0.0
	for k in 4:
		var corner := direction(key.x, rect.x + rect.z * float(k & 1), rect.y + rect.z * float(k >> 1)) * radius
		r = maxf(r, corner.distance_to(mid))
	return [mid, r + relief * 0.5]
```

- [ ] **Step 4: Run the tests**

Run: `-gtest=res://test/unit/test_cube_sphere.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/world/cube_sphere.gd who-knows/test/unit/test_cube_sphere.gd
git commit -m "feat: world scale -- CubeSphere, the faces and quadtree a world's ground hangs on"
```

---

### Task 7: `TerrainChunkData`

**Files:**
- Create: `who-knows/src/world/terrain_chunk_data.gd`, `who-knows/test/unit/test_terrain_chunks.gd`
- Modify: `who-knows/test/unit/test_visual_style_rules.gd`

**Interfaces:**
- Consumes: `WorldTerrain` (Task 5), `CubeSphere` (Task 6).
- Produces: `TerrainChunkData.build(terrain: WorldTerrain, key: Vector4i) -> TerrainChunkData` with `key`, `centre: Vector3i` (body-local, whole metres), `grid: PackedVector3Array` ((QUADS+1)² ground points, relative to `centre`, row by row in v then u), `positions`, `normals`, `colours` (ground triangles first, 512 × 3 vertices, then skirts), `faces: PackedVector3Array` (the ground triangles only, relative to `centre`); `const SKIRT_QUADS := 2.0`.

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_terrain_chunks.gd`:

```gdscript
extends GutTest

## One chunk of a world's ground (the world scale spec §5.2, §5.4):
## deterministic, small chunk-relative numbers, edges that meet their
## neighbours across cube faces too, skirts, and collision that is exactly
## the ground drawn.

const N := CubeSphere.QUADS

var _terrain: WorldTerrain

func before_each():
	var r := WorldRecipe.from_seed(1337)
	r.radius_m = 60000.0
	r.relief_m = 1200.0
	_terrain = WorldTerrain.new(r)

func _abs(c: TerrainChunkData, i: int, j: int) -> Vector3:
	return c.grid[j * (N + 1) + i] + Vector3(c.centre)

func test_the_same_key_gives_the_same_chunk():
	var a := TerrainChunkData.build(_terrain, Vector4i(2, 5, 7, 11))
	var b := TerrainChunkData.build(WorldTerrain.new(_terrain.recipe), Vector4i(2, 5, 7, 11))
	assert_eq(a.centre, b.centre)
	assert_eq(a.positions, b.positions)
	assert_eq(a.colours, b.colours)

func test_numbers_are_chunk_sized_and_finite():
	for key in [Vector4i(0, 0, 0, 0), Vector4i(4, 12, 2000, 1000)]:
		var c := TerrainChunkData.build(_terrain, key)
		var reach := CubeSphere.edge_m(_terrain.radius, key.y) * 1.5 + _terrain.relief
		for p in c.positions:
			assert_true(p.is_finite())
			assert_lte(p.length(), reach, "%s: chunk-relative, never world-sized" % key)

func test_neighbours_on_a_face_share_their_edge():
	var a := TerrainChunkData.build(_terrain, Vector4i(1, 6, 20, 30))
	var b := TerrainChunkData.build(_terrain, Vector4i(1, 6, 21, 30))
	for j in N + 1:
		assert_almost_eq(_abs(a, N, j), _abs(b, 0, j), Vector3.ONE * 0.01)

func test_neighbours_across_a_cube_edge_share_their_edge():
	# Face 0's u = +1 edge is face 5's u = -1 edge, with the same v.
	var a := TerrainChunkData.build(_terrain, Vector4i(0, 2, 3, 1))
	var b := TerrainChunkData.build(_terrain, Vector4i(5, 2, 0, 1))
	for j in N + 1:
		assert_almost_eq(_abs(a, N, j), _abs(b, 0, j), Vector3.ONE * 0.01)

func test_ground_then_skirts_and_collision_is_the_ground_drawn():
	var c := TerrainChunkData.build(_terrain, Vector4i(3, 7, 40, 90))
	var ground := N * N * 2 * 3
	var skirts := 4 * N * 4 * 3
	assert_eq(c.positions.size(), ground + skirts)
	assert_eq(c.normals.size(), c.positions.size())
	assert_eq(c.colours.size(), c.positions.size())
	assert_eq(c.faces.size(), ground)
	for k in ground:
		assert_eq(c.faces[k], c.positions[k])

func test_ground_faces_look_outward():
	var c := TerrainChunkData.build(_terrain, Vector4i(4, 9, 300, 200))
	for t in range(0, N * N * 2 * 3, 3):
		var mid := (c.positions[t] + c.positions[t + 1] + c.positions[t + 2]) / 3.0 + Vector3(c.centre)
		assert_gt(c.normals[t].dot(mid.normalized()), 0.0)
```

In `who-knows/test/unit/test_visual_style_rules.gd` add after `"res://src/world/world_terrain.gd",`:

```gdscript
	"res://src/world/terrain_chunk_data.gd",
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `-gtest=res://test/unit/test_terrain_chunks.gd`
Expected: FAIL (`TerrainChunkData` not found).

- [ ] **Step 3: Write `TerrainChunkData`**

Create `who-knows/src/world/terrain_chunk_data.gd`:

```gdscript
class_name TerrainChunkData
extends RefCounted

## One chunk of a world's ground (docs/superpowers/specs/2026-09-30-world-scale-design.md
## §5.2, §5.4): a quadtree node's QUADS x QUADS quads, flat-shaded with one
## colour a triangle, with a skirt round its edge to hide cracks against a
## coarser neighbour, as packed arrays for a mesh and for collision. Pure:
## built on a worker thread with that thread's own WorldTerrain.
##
## Every number is relative to `centre`, the chunk's middle rounded to whole
## metres, so no 32-bit float ever holds a world-sized offset: heights and
## the subtraction are done in 64-bit, and the node sits at
## body.point + centre in the universe.

## A skirt drops this many quads' edge below the ground.
const SKIRT_QUADS := 2.0

var key: Vector4i
## The chunk's middle, body-local, whole metres.
var centre: Vector3i
## The (QUADS + 1)^2 ground points, relative to centre, row by row in v.
var grid := PackedVector3Array()
var positions := PackedVector3Array()
var normals := PackedVector3Array()
var colours := PackedColorArray()
## The ground's triangles alone, relative to centre: for collision.
var faces := PackedVector3Array()

static func build(terrain: WorldTerrain, p_key: Vector4i) -> TerrainChunkData:
	var c := TerrainChunkData.new()
	c.key = p_key
	var n := CubeSphere.QUADS
	var rect := CubeSphere.node_rect(p_key)
	var step := rect.z / n
	var mid := CubeSphere.direction(p_key.x, rect.x + rect.z * 0.5, rect.y + rect.z * 0.5)
	var mid_r := terrain.radius + terrain.height_at(mid)
	c.centre = Vector3i(roundi(mid.x * mid_r), roundi(mid.y * mid_r), roundi(mid.z * mid_r))
	var cx := float(c.centre.x)
	var cy := float(c.centre.y)
	var cz := float(c.centre.z)
	var dirs := PackedVector3Array()
	dirs.resize((n + 1) * (n + 1))
	c.grid.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var d := CubeSphere.direction(p_key.x, rect.x + i * step, rect.y + j * step)
			var r := terrain.radius + terrain.height_at(d)
			dirs[j * (n + 1) + i] = d
			c.grid[j * (n + 1) + i] = Vector3(d.x * r - cx, d.y * r - cy, d.z * r - cz)
	var quad := CubeSphere.edge_m(terrain.radius, p_key.y) / n
	var patch := quad * WorldTerrain.PATCH_QUADS
	for j in n:
		for i in n:
			var i00 := j * (n + 1) + i
			var i10 := i00 + 1
			var i01 := i00 + n + 1
			var i11 := i01 + 1
			c._ground(terrain, dirs, i00, i10, i11, patch)
			c._ground(terrain, dirs, i00, i11, i01, patch)
	var drop := quad * SKIRT_QUADS
	for k in n:
		c._skirt(terrain, dirs, k, k + 1, drop, patch)                                   # v = start
		c._skirt(terrain, dirs, n * (n + 1) + k, n * (n + 1) + k + 1, drop, patch)       # v = end
		c._skirt(terrain, dirs, k * (n + 1), (k + 1) * (n + 1), drop, patch)             # u = start
		c._skirt(terrain, dirs, k * (n + 1) + n, (k + 1) * (n + 1) + n, drop, patch)     # u = end
	return c

## One ground triangle, wound so Godot draws its outward side.
func _ground(terrain: WorldTerrain, dirs: PackedVector3Array, ia: int, ib: int, ic: int, patch: float) -> void:
	var a := grid[ia]
	var b := grid[ib]
	var c := grid[ic]
	var out := (dirs[ia] + dirs[ib] + dirs[ic]).normalized()
	var cross := (b - a).cross(c - a)
	if cross.dot(out) > 0.0:
		# Godot draws the side (b - a) x (c - a) points away from.
		var swap := b
		b = c
		c = swap
		cross = -cross
	var normal := -cross.normalized()
	var colour := terrain.colour_at(out, normal.angle_to(out), patch)
	positions.append_array(PackedVector3Array([a, b, c]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	colours.append_array(PackedColorArray([colour, colour, colour]))
	faces.append_array(PackedVector3Array([a, b, c]))

## A skirt below the edge from grid point `ip` to `iq`, both ways round so
## it hides a crack whichever side it is seen from.
func _skirt(terrain: WorldTerrain, dirs: PackedVector3Array, ip: int, iq: int, drop: float, patch: float) -> void:
	var p := grid[ip]
	var q := grid[iq]
	var p2 := p - dirs[ip] * drop
	var q2 := q - dirs[iq] * drop
	var normal := (dirs[ip] + dirs[iq]).normalized()
	var colour := terrain.colour_at(normal, 0.0, patch)
	positions.append_array(PackedVector3Array([p, q, q2, p, q2, p2, p, q2, q, p, p2, q2]))
	for k in 12:
		normals.append(normal)
		colours.append(colour)
```

- [ ] **Step 4: Run the tests**

Run: `-gtest=res://test/unit/test_terrain_chunks.gd`, then `test_visual_style_rules.gd`.
Expected: PASS. Also add a timing line to the test file and read it:

```gdscript
func test_a_chunk_builds_in_time():
	var t0 := Time.get_ticks_usec()
	for k in 5:
		TerrainChunkData.build(_terrain, Vector4i(k, 10, 300 + k, 400))
	var ms := (Time.get_ticks_usec() - t0) / 5000.0
	gut.p("a chunk builds in %.1f ms on one thread (spec §5.6: 10 ms)" % ms)
	assert_lt(ms, 40.0, "far over budget: see the spec's fallbacks")
```

If it prints over 10 ms, record the figure in the commit message; Task 12 measures it in the real scene, and the spec's fallbacks (§5.6) are Task 12's decision, not this task's.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/world/terrain_chunk_data.gd who-knows/test/unit/test_terrain_chunks.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: world scale -- TerrainChunkData, one chunk of ground in chunk-relative numbers"
```

---

### Task 8: Choosing the chunks

**Files:**
- Create: `who-knows/src/world/world_surface.gd` (its pure static part only), `who-knows/test/unit/test_world_surface.gd`

**Interfaces:**
- Consumes: `CubeSphere` (Task 6).
- Produces: `WorldSurface` (`extends Node3D`) with `const SPLIT := 1.5`, `const MERGE := 1.8`, and static `select(radius: float, relief: float, depth_max: int, local: Vector3, was_split: Dictionary, bounds: Dictionary) -> Array` returning `[leaves: Array[Vector4i], split: Dictionary]`; static `horizon_reach(radius: float, relief: float, d: float) -> float`; static `bound_of(key: Vector4i, radius: float, relief: float, bounds: Dictionary) -> Array` (cached `CubeSphere.node_bound`).

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_world_surface.gd`:

```gdscript
extends GutTest

## A world's surface (the world scale spec §5): which chunks are drawn for
## where you are, and (below) the node that streams them.

const R := 60000.0
const RELIEF := 1200.0

var _depth := CubeSphere.depth_for(R)

func _leaves(altitude: float, was := {}) -> Array:
	return WorldSurface.select(R, RELIEF, _depth, Vector3.UP * (R + altitude), was, {})

static func _is_ancestor(a: Vector4i, b: Vector4i) -> bool:
	var p := b
	while p.y > a.y:
		p = CubeSphere.parent(p)
	return p == a and a != b

func test_from_far_off_a_world_is_a_few_coarse_chunks():
	var leaves: Array[Vector4i] = _leaves(R * 9.0)[0]
	assert_between(leaves.size(), 1, 24)
	for k in leaves:
		assert_lte(k.y, 1)

func test_on_the_ground_the_finest_chunk_is_under_you():
	var leaves: Array[Vector4i] = _leaves(2.0)[0]
	assert_true(leaves.has(CubeSphere.key_for(Vector3.UP, _depth)))

func test_the_chunk_count_stays_in_budget_at_every_height():
	for altitude in [2.0, 1000.0, 10000.0, 100000.0]:
		var n: int = (_leaves(altitude)[0] as Array).size()
		gut.p("%.0f m up: %d chunks built" % [altitude, n])
		assert_lte(n, 350, "%.0f m up" % altitude)

func test_nothing_behind_the_horizon_is_chosen():
	for k: Vector4i in _leaves(100.0)[0]:
		var b := CubeSphere.node_bound(k, R, RELIEF)
		assert_gt((b[0] as Vector3).normalized().dot(Vector3.UP), 0.0, "%s is on the far side" % k)

func test_leaves_never_overlap():
	var leaves: Array[Vector4i] = _leaves(300.0)[0]
	var set := {}
	for k in leaves:
		set[k] = true
	for k in leaves:
		var p := k
		while p.y > 0:
			p = CubeSphere.parent(p)
			assert_false(set.has(p), "%s and its ancestor %s are both leaves" % [k, p])

func test_a_split_node_stays_split_until_merge():
	# A node between SPLIT and MERGE edges away splits only if it already was.
	var key := Vector4i(2, 4, 8, 8)
	var b := CubeSphere.node_bound(key, R, RELIEF)
	var edge := CubeSphere.edge_m(R, key.y)
	var centre: Vector3 = b[0]
	var at := centre + centre.normalized() * (float(b[1]) + edge * (WorldSurface.SPLIT + WorldSurface.MERGE) * 0.5)
	var fresh: Dictionary = WorldSurface.select(R, RELIEF, _depth, at, {}, {})[1]
	assert_false(fresh.has(key), "not split from fresh")
	var kept: Dictionary = WorldSurface.select(R, RELIEF, _depth, at, {key: true}, {})[1]
	assert_true(kept.has(key), "kept split")

func test_selection_from_the_centre_is_sane():
	var sel := WorldSurface.select(R, RELIEF, _depth, Vector3.ZERO, {}, {})
	for k: Vector4i in sel[0]:
		assert_lte(k.y, _depth)
	assert_eq(WorldSurface.horizon_reach(R, RELIEF, 0.0), INF)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `-gtest=res://test/unit/test_world_surface.gd`
Expected: FAIL (`WorldSurface` not found).

- [ ] **Step 3: Write the selection**

Create `who-knows/src/world/world_surface.gd`:

```gdscript
class_name WorldSurface
extends Node3D

## A world's ground at its true place and size
## (docs/superpowers/specs/2026-09-30-world-scale-design.md §5): a quadtree on
## each face of a cube-sphere, split finer where the focus is near and never
## drawn behind the horizon, each leaf one chunk of TerrainChunkData.
##
## This part chooses the leaves, and is pure.

## Split a node when the focus is within SPLIT times its edge of it; merge it
## again only beyond MERGE (§5.2). About 21 leaves a level at 1.5.
const SPLIT := 1.5
const MERGE := 1.8

## The leaves to draw for a focus at `local` (from the world's centre), and
## which nodes are split: [leaves, split]. `was_split` is the last call's
## split, for hysteresis; `bounds` caches each node's bound between calls.
static func select(radius: float, relief: float, depth_max: int, local: Vector3,
		was_split: Dictionary, bounds: Dictionary) -> Array:
	var leaves: Array[Vector4i] = []
	var split := {}
	var reach := horizon_reach(radius, relief, local.length())
	for f in CubeSphere.FACES:
		_walk(Vector4i(f, 0, 0, 0), radius, relief, depth_max, local, reach, was_split, bounds, leaves, split)
	return [leaves, split]

## How far from a focus `d` from the centre any ground can still be seen: to
## the horizon of the lowest ground, then on to the highest ground beyond it.
## Everywhere, from inside the lowest ground.
static func horizon_reach(radius: float, relief: float, d: float) -> float:
	var low := radius - relief * 0.5
	var high := radius + relief * 0.5
	if d <= low:
		return INF
	return sqrt(d * d - low * low) + sqrt(high * high - low * low)

## A node's [centre, radius], cached.
static func bound_of(key: Vector4i, radius: float, relief: float, bounds: Dictionary) -> Array:
	if not bounds.has(key):
		bounds[key] = CubeSphere.node_bound(key, radius, relief)
	return bounds[key]

static func _walk(key: Vector4i, radius: float, relief: float, depth_max: int, local: Vector3, reach: float,
		was_split: Dictionary, bounds: Dictionary, leaves: Array[Vector4i], split: Dictionary) -> void:
	var b := bound_of(key, radius, relief, bounds)
	var to := (b[0] as Vector3).distance_to(local)
	var near := maxf(to - float(b[1]), 0.0)
	if near > reach:
		return
	var factor := MERGE if was_split.has(key) else SPLIT
	if key.y < depth_max and near < factor * CubeSphere.edge_m(radius, key.y):
		split[key] = true
		for c in CubeSphere.children(key):
			_walk(c, radius, relief, depth_max, local, reach, was_split, bounds, leaves, split)
	else:
		leaves.append(key)
```

- [ ] **Step 4: Run the tests**

Run: `-gtest=res://test/unit/test_world_surface.gd`
Expected: PASS. Read the printed chunk counts. If any altitude is over 350, the budget in spec §5.6 is at risk: lower `SPLIT` to 1.3 (and `MERGE` to 1.6), rerun, and note both numbers in the commit message.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/world/world_surface.gd who-knows/test/unit/test_world_surface.gd
git commit -m "feat: world scale -- choosing a world's chunks, split near you and culled past the horizon"
```

---

### Task 9: Streaming the surface, and the proxy handing over to it

**Files:**
- Modify: `who-knows/src/world/world_surface.gd`, `body_proxy.gd`, `star_system.gd`
- Test: `who-knows/test/unit/test_world_surface.gd`, `test_body_proxy.gd`, `test_floating_origin_scene.gd`, `test_visual_style_rules.gd`

**Interfaces:**
- Consumes: `select` (Task 8), `TerrainChunkData.build` (Task 7), `WorldTerrain` (Task 5).
- Produces:
  - `WorldSurface`: `body: SystemBody`, `universe: Universe`, `terrain: WorldTerrain`, `depth_max: int`, `leaves: Array[Vector4i]`; `setup(body, universe)`, `build_roots()`, `update(focus: UniversePoint)`, `finish()` (waits for every job and applies everything: for tests and probes), `chunk_count() -> int`, `visible_chunks() -> Array[Vector4i]`, `jobs_in_flight() -> int`; `const MAX_JOBS := 12`, `const RESELECT_AFTER := 10.0`, `const SHADOW_EDGE := 512.0`.
  - `BodyProxy`: `const SURFACE_RADII := 10.0`, `const SURFACE_MOST := 300000.0`, `const SURFACE_HYSTERESIS := 1.1`, `var frozen := false`, `surface() -> WorldSurface`, `surface_at() -> float`. The near shell's *collider* stays until Task 10; its near *mesh* goes.
  - `StarSystem.set_warp(on)` also sets every proxy's `frozen`.

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_world_surface.gd`:

```gdscript
# --- the node (§5.3, §5.4) ----------------------------------------------------

var _universe: Universe
var _system: SystemRecipe
## Off the cube's grid lines: straight up is where four cells meet, and
## "the chunk under you" would be a tie.
var _up := Vector3(0.31, 0.9, 0.22).normalized()

func _planet() -> SystemBody:
	if _system == null:
		_system = SystemRecipe.from_seed(1337)
	return _system.planets()[0]

func _surface(altitude: float) -> WorldSurface:
	_universe = Universe.new()
	add_child_autofree(_universe)
	var p := _planet()
	var s := WorldSurface.new()
	s.setup(p, _universe)
	add_child_autofree(s)
	s.build_roots()
	var focus := _above(p, s, altitude)
	_universe.origin = focus
	s.update(focus)
	return s

func _above(p: SystemBody, s: WorldSurface, altitude: float) -> UniversePoint:
	return p.point.plus(_up * (p.radius + s.terrain.height_at(_up) + altitude))

func test_a_surface_is_whole_from_its_first_frame():
	_universe = Universe.new()
	add_child_autofree(_universe)
	var s := WorldSurface.new()
	s.setup(_planet(), _universe)
	add_child_autofree(s)
	s.build_roots()
	assert_eq(s.chunk_count(), 6)
	assert_eq(s.visible_chunks().size(), 6)

func test_every_leaf_is_drawn_once_and_nothing_overlaps():
	var s := _surface(500.0)
	s.finish()
	var shown := s.visible_chunks()
	assert_eq(shown.size(), s.leaves.size())
	for k in s.leaves:
		assert_true(shown.has(k), "%s is drawn" % k)
	assert_eq(s.jobs_in_flight(), 0)

func test_chunks_are_members_and_the_surface_never_moves():
	var s := _surface(500.0)
	s.finish()
	assert_false(s.is_in_group(Universe.EXTERIOR_SPACE))
	assert_eq(s.global_transform, Transform3D.IDENTITY)
	for c in s.get_children():
		assert_true(c.is_in_group(Universe.EXTERIOR_SPACE), "%s shifts" % c.name)

func test_a_shift_moves_every_chunk_with_the_focus():
	var s := _surface(500.0)
	s.finish()
	var before := {}
	for c: Node3D in s.get_children():
		before[c.name] = c.global_position
	_universe.shift(Vector3(2000, 0, -1000))
	for c: Node3D in s.get_children():
		assert_almost_eq(c.global_position, before[c.name] - Vector3(2000, 0, -1000), Vector3.ONE * 0.001)

func test_climbing_away_merges_chunks():
	var s := _surface(300.0)
	s.finish()
	var low := s.chunk_count()
	var p := _planet()
	var high := _above(p, s, 80000.0)
	s.update(high)
	s.finish()
	assert_lt(s.chunk_count(), low)
	assert_eq(s.visible_chunks().size(), s.leaves.size())

func test_a_surface_freed_mid_build_waits_for_its_jobs():
	var s := _surface(200.0)
	assert_gt(s.jobs_in_flight(), 0, "jobs are out")
	remove_child(s)
	s.free()
	pass_test("freed with jobs in flight, and nothing broke")
```

Replace the doc comment line at the top of the test file with: `## A world's surface (the world scale spec §5): which chunks are drawn for where you are, and the node that streams them.`

In `who-knows/test/unit/test_body_proxy.gd` append:

```gdscript
func test_near_a_world_its_surface_takes_over():
	var b := _planet()
	var p := _proxy(b)
	var near := b.point.plus(Vector3(0, 0, b.radius * 3.0))
	_universe.origin = near
	p.place(_universe, near)
	var s := p.surface()
	assert_not_null(s, "within %.0f km" % (p.surface_at() / 1000.0))
	assert_false((p.get_node("Far") as Node3D).visible, "the far mesh gives way")
	assert_eq(s.get_parent(), p.get_parent(), "beside the proxy, under a parent that never moves")
	var far := b.point.plus(Vector3(0, 0, p.surface_at() * 1.2))
	_universe.origin = far
	p.place(_universe, far)
	assert_null(p.surface())
	assert_true((p.get_node("Far") as Node3D).visible)

func test_no_surface_starts_while_frozen():
	var b := _planet()
	var p := _proxy(b)
	p.frozen = true
	var near := b.point.plus(Vector3(0, 0, b.radius * 3.0))
	_universe.origin = near
	p.place(_universe, near)
	assert_null(p.surface(), "a warp is carrying you past")

func test_the_surface_starts_within_ten_radii_and_300_km():
	var b := _planet()
	var p := _proxy(b)
	assert_eq(p.surface_at(), minf(b.radius * BodyProxy.SURFACE_RADII, BodyProxy.SURFACE_MOST))
```

In `who-knows/test/unit/test_floating_origin_scene.gd` append:

```gdscript
func test_everything_outside_is_covered_beside_a_world():
	var system: SystemRecipe = _root.system
	var planet := system.planets()[0]
	_root.hop_index = system.bodies.find(planet) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(2)
	var surface: WorldSurface = (_root.star_system.proxy(planet.id) as BodyProxy).surface()
	assert_not_null(surface)
	surface.finish()
	assert_eq(_uncovered(), [], "every chunk of ground shifts too")
```

In `who-knows/test/unit/test_visual_style_rules.gd` add after the chunk data line:

```gdscript
	"res://src/world/world_surface.gd",
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `-gtest=res://test/unit/test_world_surface.gd`
Expected: FAIL (`setup` not found).

- [ ] **Step 3: Write the node**

In `who-knows/src/world/world_surface.gd`, replace the class doc comment with:

```gdscript
## A world's ground at its true place and size
## (docs/superpowers/specs/2026-09-30-world-scale-design.md §5): a quadtree on
## each face of a cube-sphere, split finer where the focus is near and never
## drawn behind the horizon, each leaf one chunk of TerrainChunkData built on
## a worker thread and turned into a mesh here within a budget a tick.
##
## Nothing is ever a hole: a node stays drawn until every leaf beneath it that
## replaces it is built, and a chunk shows only while nothing drawn above it
## does. The six coarsest are built at once, so the world is whole on its
## first frame.
##
## The floating origin (CLAUDE.md): this node never moves and is not a member;
## each chunk is a member of Universe.EXTERIOR_SPACE of its own, placed from
## its UniversePoint when made.
```

Add after `const MERGE`:

```gdscript
## Chunk builds in flight at once.
const MAX_JOBS := 12
## Main-thread time a tick may spend turning finished chunks into nodes: the
## asteroids' own budget.
const APPLY_BUDGET_USEC := AsteroidStream.APPLY_BUDGET_USEC
## The leaves are chosen afresh once the focus has moved this far.
const RESELECT_AFTER := 10.0
## Chunks with an edge this short or shorter cast shadows: the sun's shadows
## reach 2 km.
const SHADOW_EDGE := 512.0

var body: SystemBody
var universe: Universe
## The main thread's own; each job makes another.
var terrain: WorldTerrain
var depth_max := 0
var leaves: Array[Vector4i] = []

var _split := {}
var _bounds := {}
## key -> MeshInstance3D
var _chunks := {}
## key -> task id
var _jobs := {}
## key -> TerrainChunkData, written by the jobs under _mutex.
var _done := {}
var _mutex := Mutex.new()
var _selected_at: UniversePoint
var _local := Vector3.ZERO

func setup(p_body: SystemBody, p_universe: Universe) -> void:
	body = p_body
	universe = p_universe
	name = "Surface_%s" % String(body.id).replace(".", "_")
	terrain = WorldTerrain.new(body.recipe)
	depth_max = CubeSphere.depth_for(body.radius)

## The six coarsest chunks, built now: whole on the first frame.
func build_roots() -> void:
	for f in CubeSphere.FACES:
		_make_chunk(TerrainChunkData.build(terrain, Vector4i(f, 0, 0, 0)))

## Chooses the leaves for `focus` if it has moved, collects finished jobs,
## asks for what is missing nearest first, applies what fits in the budget,
## and lets go of what nothing needs.
func update(focus: UniversePoint) -> void:
	_local = focus.minus(body.point)
	if _selected_at == null or focus.minus(_selected_at).length() >= RESELECT_AFTER:
		_selected_at = focus
		var sel := select(body.radius, terrain.relief, depth_max, _local, _split, _bounds)
		leaves.assign(sel[0])
		_split = sel[1]
	_collect()
	_request()
	_apply(Time.get_ticks_usec() + APPLY_BUDGET_USEC)
	_prune()

## Waits for every job and applies everything: tests and probes.
func finish() -> void:
	while not _jobs.is_empty() or _missing().size() > 0:
		for id: int in _jobs.values():
			WorkerThreadPool.wait_for_task_completion(id)
		_jobs.clear()
		_request()
		for id: int in _jobs.values():
			WorkerThreadPool.wait_for_task_completion(id)
		_jobs.clear()
		_apply(INF)
	_prune()

func chunk_count() -> int:
	return _chunks.size()

func visible_chunks() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	for k: Vector4i in _chunks:
		if (_chunks[k] as MeshInstance3D).visible:
			out.append(k)
	return out

func jobs_in_flight() -> int:
	return _jobs.size()

func _exit_tree() -> void:
	# A job holds this node; never let one outlive it.
	for id: int in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(id)
	_jobs.clear()

## Wanted leaves not drawn, not building and not built.
func _missing() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	_mutex.lock()
	for k in leaves:
		if not _chunks.has(k) and not _jobs.has(k) and not _done.has(k):
			out.append(k)
	_mutex.unlock()
	return out

func _collect() -> void:
	for k: Vector4i in _jobs.keys():
		var id: int = _jobs[k]
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_jobs.erase(k)

func _request() -> void:
	var missing := _missing()
	missing.sort_custom(func(a: Vector4i, b: Vector4i) -> bool: return _distance(a) < _distance(b))
	for k in missing:
		if _jobs.size() >= MAX_JOBS:
			return
		_jobs[k] = WorkerThreadPool.add_task(_job.bind(k, body.recipe), false, "world chunk")

## On a worker: its own terrain, one chunk.
func _job(key: Vector4i, recipe: WorldRecipe) -> void:
	var data := TerrainChunkData.build(WorldTerrain.new(recipe), key)
	_mutex.lock()
	_done[key] = data
	_mutex.unlock()

func _apply(deadline: float) -> void:
	_mutex.lock()
	var ready: Array = _done.keys()
	_mutex.unlock()
	ready.sort_custom(func(a: Vector4i, b: Vector4i) -> bool: return _distance(a) < _distance(b))
	var wanted := {}
	for k in leaves:
		wanted[k] = true
	for k: Vector4i in ready:
		if Time.get_ticks_usec() > deadline:
			return
		_mutex.lock()
		var data: TerrainChunkData = _done[k]
		_done.erase(k)
		_mutex.unlock()
		if wanted.has(k) and not _chunks.has(k):
			_make_chunk(data)

func _make_chunk(data: TerrainChunkData) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.positions
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_COLOR] = data.colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := MeshInstance3D.new()
	m.name = "C%d_%d_%d_%d" % [data.key.x, data.key.y, data.key.z, data.key.w]
	m.mesh = mesh
	m.material_override = BodyLook.material(false)
	m.layers = 1
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		if CubeSphere.edge_m(body.radius, data.key.y) <= SHADOW_EDGE \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_to_group(Universe.EXTERIOR_SPACE)
	add_child(m)
	m.global_position = universe.to_engine(body.point.plus(Vector3(data.centre)))
	_chunks[data.key] = m

## Lets go of every drawn chunk nothing needs, and shows each only while
## nothing drawn above it is shown.
func _prune() -> void:
	var wanted := {}
	var waiting := {}
	var covering := {}
	for k in leaves:
		wanted[k] = true
		if not _chunks.has(k):
			waiting[k] = true
			var p := k
			while p.y > 0:
				p = CubeSphere.parent(p)
				covering[p] = true
	for k: Vector4i in _chunks.keys():
		if wanted.has(k) or covering.has(k) or _below_any(k, waiting):
			continue
		(_chunks[k] as Node).queue_free()
		_chunks.erase(k)
	for k: Vector4i in _chunks:
		(_chunks[k] as MeshInstance3D).visible = not _below_any(k, _chunks)

## True if an ancestor of `key` is in `set`.
static func _below_any(key: Vector4i, set: Dictionary) -> bool:
	var p := key
	while p.y > 0:
		p = CubeSphere.parent(p)
		if set.has(p):
			return true
	return false

func _distance(key: Vector4i) -> float:
	var b := bound_of(key, body.radius, terrain.relief, _bounds)
	return maxf((b[0] as Vector3).distance_to(_local) - float(b[1]), 0.0)
```

`finish()` loops until nothing is missing; because `_apply(INF)` applies every finished chunk, the loop ends.

- [ ] **Step 4: The proxy hands over**

In `who-knows/src/world/body_proxy.gd`:

Replace the doc comment paragraph beginning `Up close it swaps` with:

```gdscript
## Within SURFACE_AT of its centre a world is drawn by its WorldSurface, at
## its true place, and the far mesh gives way (the world scale spec §5.1). The
## surface is this proxy's sibling, under the same parent that never moves.
## Up close it still grows a convex collider on the `terrain` layer until the
## surface's own collision replaces it.
```

Add constants after `FADE_MARGIN`:

```gdscript
## Within SURFACE_RADII radii of its centre, and never beyond SURFACE_MOST
## (inside the far plane), a world is drawn by its surface; it goes back to
## its far mesh SURFACE_HYSTERESIS times farther out.
const SURFACE_RADII := 10.0
const SURFACE_MOST := 300000.0
const SURFACE_HYSTERESIS := 1.1
```

Add members after `var distance`:

```gdscript
## While a warp carries you no surface starts (the world scale spec §5.1): a
## synchronous first build mid-warp would be a hitch, for a world gone in a
## second.
var frozen := false

var _universe: Universe
var _surface: WorldSurface
```

In `setup`, delete the three `visibility_range_*` lines on `_far` (the surface takes over now, not the near mesh).

Replace `place` with:

```gdscript
func place(universe: Universe, focus: UniversePoint) -> void:
	_universe = universe
	var at := placement(body.point, focus, universe)
	distance = body.point.minus(focus).length()
	var s: float = at[1]
	global_transform = Transform3D(Basis.from_scale(Vector3.ONE * s), at[0])
	if body.kind == SystemBody.Kind.STAR:
		return
	if distance < surface_at() and _surface == null and not frozen:
		_make_surface()
	elif distance > surface_at() * SURFACE_HYSTERESIS and _surface != null:
		_drop_surface()
	if _surface != null:
		_surface.update(focus)
	_far.visible = _surface == null
	var height := distance - body.radius
	if height < NEAR_WITHIN and _collider == null:
		_make_near()
	elif height > NEAR_WITHIN + NEAR_HYSTERESIS and _collider != null:
		_drop_near()
	_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if height < SHADOW_WITHIN \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
```

Add:

```gdscript
## Where the surface takes over, metres from the centre.
func surface_at() -> float:
	return minf(body.radius * SURFACE_RADII, SURFACE_MOST)

## Its surface while it is near, else null.
func surface() -> WorldSurface:
	return _surface

func _make_surface() -> void:
	_surface = WorldSurface.new()
	_surface.setup(body, _universe)
	get_parent().add_child(_surface)
	_surface.build_roots()

func _drop_surface() -> void:
	_surface.queue_free()
	_surface = null

func _exit_tree() -> void:
	if _surface != null:
		_surface.queue_free()
		_surface = null
```

Replace `_make_near` and `_drop_near` so they keep only the collider (the near mesh is gone; the surface draws the ground):

```gdscript
func _make_near() -> void:
	_collider = StaticBody3D.new()
	_collider.name = "Shell"
	_collider.collision_layer = LAYER
	_collider.collision_mask = 0
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for p in BodyLook.points(BodyLook.NEAR_DETAIL):
		points.append(p * body.radius)
	hull.points = points
	shape.shape = hull
	_collider.add_child(shape)
	add_child(_collider)

func _drop_near() -> void:
	_collider.queue_free()
	_collider = null
```

Delete `var _near`, and change `is_near()` to `return _collider != null`. Its doc comment becomes "True while its shell is solid (until the surface's collision replaces it)."

- [ ] **Step 5: Freeze proxies at warp**

In `who-knows/src/world/star_system.gd` replace `set_warp` with:

```gdscript
## The belts' look while a warp carries you: every slab whole (§5.2); and no
## world starts its surface on the way past (the world scale spec §5.1).
func set_warp(on: bool) -> void:
	for b in belts:
		b.set_whole(on)
	for p in proxies:
		p.frozen = on
```

- [ ] **Step 6: Run the tests**

Run: `-gtest=res://test/unit/test_world_surface.gd`, `test_body_proxy.gd`, `test_floating_origin_scene.gd`, `test_system_scene.gd`, `test_star_system.gd`, `test_warp_scene.gd`, `test_visual_style_rules.gd`.
Expected: PASS. Also check the run's exit code is 0 and there is no *ObjectDB instances leaked* or *WorkerThreadPool* warning at exit: a task never waited on shows as a leak there.

- [ ] **Step 7: Run the whole suite, then commit**

```bash
git add who-knows/src/world who-knows/test/unit/test_world_surface.gd who-knows/test/unit/test_body_proxy.gd who-knows/test/unit/test_floating_origin_scene.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: world scale -- a world's surface streams its chunks round you, whole from the first frame"
```

---

### Task 10: Solid ground, and the analytic floor

**Files:**
- Create: `who-knows/src/world/terrain_collider.gd`
- Modify: `who-knows/src/world/world_surface.gd`, `body_proxy.gd`, `body_look.gd`
- Test: `who-knows/test/unit/test_world_surface.gd`, `test_body_proxy.gd`, `test_system_scene.gd`

**Interfaces:**
- Consumes: `WorldSurface` (Task 9), `CubeSphere.key_for` (Task 6).
- Produces:
  - `TerrainCollider` (static): `REACH := 64.0`, `LOOKAHEAD := 1.0`, `REACH_MAX := 160.0`; `reach_for(speed: float) -> float`; `keys_near(terrain: WorldTerrain, depth: int, local: Vector3, reach: float) -> Array[Vector4i]` (nearest first; empty from the centre or when higher than `reach` above the ground).
  - `WorldSurface`: `floor_fired: int`, `static var warn_on_floor := true`, `solid_keys() -> Array[Vector4i]`, `const FLOOR_SLACK := 0.5`. Solid pieces are `StaticBody3D` on `BodyProxy.LAYER`, members of `Universe.EXTERIOR_SPACE`.
  - `BodyProxy` loses `NEAR_WITHIN`, `NEAR_HYSTERESIS`, `is_near()`, `collider()`, `_make_near()`, `_drop_near()`; `BodyLook` loses `NEAR_DETAIL` and `points()`.

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_world_surface.gd`:

```gdscript
# --- solid ground (§5.5) --------------------------------------------------------

func _anchor(s: WorldSurface, altitude: float, mask := BodyProxy.LAYER) -> RigidBody3D:
	var a := RigidBody3D.new()
	a.freeze = true
	a.collision_mask = mask
	a.add_to_group(AsteroidStream.SPACE_ANCHOR)
	a.add_to_group(Universe.EXTERIOR_SPACE)
	add_child_autofree(a)
	a.global_position = _universe.to_engine(_above(_planet(), s, altitude))
	return a

func test_no_keys_from_the_centre_or_far_away():
	var t := WorldTerrain.new(_planet().recipe)
	var d := CubeSphere.depth_for(t.radius)
	assert_eq(TerrainCollider.keys_near(t, d, Vector3.ZERO, 100.0).size(), 0)
	assert_eq(TerrainCollider.keys_near(t, d, Vector3.UP * (t.radius + t.relief + 5000.0), 160.0).size(), 0)

func test_the_ground_under_you_is_among_the_keys_and_they_are_few():
	var t := WorldTerrain.new(_planet().recipe)
	var d := CubeSphere.depth_for(t.radius)
	var local := _up * (t.radius + t.height_at(_up) + 10.0)
	var keys := TerrainCollider.keys_near(t, d, local, TerrainCollider.REACH_MAX)
	assert_eq(keys[0], CubeSphere.key_for(local, d), "the one under you first")
	assert_lte(keys.size(), 100)

func test_an_anchor_near_the_ground_has_solid_ground_round_it():
	var s := _surface(3000.0)
	var a := _anchor(s, 20.0)
	s.update(_universe.to_universe(a.global_position))
	s.finish()
	var solid := s.solid_keys()
	assert_gt(solid.size(), 0)
	var bodies := s.get_children().filter(func(n: Node) -> bool: return n is StaticBody3D)
	assert_eq(bodies.size(), solid.size())
	for b: StaticBody3D in bodies:
		assert_eq(b.collision_layer, BodyProxy.LAYER)
		assert_eq(b.collision_mask, 0)
		assert_true(b.is_in_group(Universe.EXTERIOR_SPACE))

func test_an_anchor_arriving_fast_has_ground_under_it():
	var s := _surface(3000.0)
	var a := _anchor(s, 5.0)
	s.update(_universe.to_universe(a.global_position))   # no finish(): this tick
	var under := CubeSphere.key_for(_universe.to_universe(a.global_position).minus(_planet().point), s.depth_max)
	assert_true(s.solid_keys().has(under), "built at once, not waited for")

func test_an_anchor_under_the_ground_is_lifted_out():
	WorldSurface.warn_on_floor = false
	var s := _surface(3000.0)
	var a := _anchor(s, -20.0)
	a.freeze = false
	a.linear_velocity = -a.global_position.normalized() * 30.0
	s.update(_universe.to_universe(a.global_position))
	WorldSurface.warn_on_floor = true
	var local := _universe.to_universe(a.global_position).minus(_planet().point)
	assert_gte(s.terrain.altitude_of(local), 0.0)
	assert_eq(s.floor_fired, 1)
	assert_gte(a.linear_velocity.dot(local.normalized()), 0.0, "no longer moving in")

func test_a_ghosted_hull_is_left_alone():
	var s := _surface(3000.0)
	var a := _anchor(s, -20.0, 0)
	s.update(_universe.to_universe(a.global_position))
	assert_eq(s.floor_fired, 0, "at warp the hull passes through everything")
```

Note: `_surface(altitude)` places the focus above `_up` on the planet, and `_anchor` places anchors on the same line, so they are near the chunks selected. `_up` is off the cube's grid lines on purpose.

In `who-knows/test/unit/test_body_proxy.gd` delete `test_up_close_it_is_solid_exactly_as_drawn`.

In `who-knows/test/unit/test_system_scene.gd` replace `test_the_hull_bumps_off_a_world` with:

```gdscript
func test_the_hull_bumps_off_a_world():
	var system: SystemRecipe = _root.system
	var planet := system.planets()[0]
	_root.hop_index = system.bodies.find(planet) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(2)
	var surface: WorldSurface = (_root.star_system.proxy(planet.id) as BodyProxy).surface()
	assert_not_null(surface, "3 km off: its ground is drawn")
	var centre := _universe.to_engine(planet.point)
	var out := (_ship.exterior.global_position - centre).normalized()
	var ground := planet.radius + surface.terrain.height_at(out)
	_ship.exterior.global_position = centre + out * (ground + 40.0)
	_ship.exterior.linear_velocity = -out * 15.0
	await wait_physics_frames(240)
	var local := _universe.to_universe(_ship.exterior.global_position).minus(planet.point)
	assert_gt(surface.terrain.altitude_of(local), 0.0, "the hull never went in")
	assert_eq(surface.floor_fired, 0, "the ground held it, not the safety net")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `-gtest=res://test/unit/test_world_surface.gd`
Expected: FAIL (`TerrainCollider` not found).

- [ ] **Step 3: Write `TerrainCollider`**

Create `who-knows/src/world/terrain_collider.gd`:

```gdscript
class_name TerrainCollider
extends RefCounted

## Which of a world's finest chunks must be solid round an anchor
## (docs/superpowers/specs/2026-09-30-world-scale-design.md §5.5; Planetfall
## §6.5): every one within REACH plus a second of travel, at most REACH_MAX,
## of an anchor that close to the ground. Pure.
##
## The chunks are found in the face's own grid round the one under the
## anchor -- cells are nearly even on a spherified cube -- and by sampling
## directions only where that window crosses a cube edge.

const REACH := 64.0
const LOOKAHEAD := 1.0
const REACH_MAX := 160.0

static func reach_for(speed: float) -> float:
	return minf(REACH + LOOKAHEAD * speed, REACH_MAX)

## The finest chunks within `reach` of `local` (from the world's centre),
## nearest first; none from the centre or from higher than `reach` up.
static func keys_near(terrain: WorldTerrain, depth: int, local: Vector3, reach: float) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	if local.is_zero_approx() or terrain.altitude_of(local) > reach:
		return out
	var under := CubeSphere.key_for(local, depth)
	var edge := CubeSphere.edge_m(terrain.radius, depth)
	var n := ceili(reach / edge) + 1
	var cells := 1 << depth
	var inside := under.z - n >= 0 and under.w - n >= 0 and under.z + n < cells and under.w + n < cells
	if inside:
		for dy in range(-n, n + 1):
			for dx in range(-n, n + 1):
				if dx * dx + dy * dy <= n * n:
					out.append(Vector4i(under.x, depth, under.z + dx, under.w + dy))
	else:
		var up := local.normalized()
		var a := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
		var b := up.cross(a)
		var seen := {}
		var step := edge * 0.5
		var m := ceili((reach + edge) / step)
		for j in range(-m, m + 1):
			for i in range(-m, m + 1):
				var off := a * (i * step) + b * (j * step)
				if off.length() > reach + edge:
					continue
				var k := CubeSphere.key_for(local + off, depth)
				if not seen.has(k):
					seen[k] = true
					out.append(k)
	var centre_of := func(k: Vector4i) -> Vector3:
		var r := CubeSphere.node_rect(k)
		return CubeSphere.direction(k.x, r.x + r.z * 0.5, r.y + r.z * 0.5) * terrain.radius
	var d := {}
	for k in out:
		d[k] = (centre_of.call(k) as Vector3).distance_to(local)
	out.sort_custom(func(p: Vector4i, q: Vector4i) -> bool: return d[p] < d[q])
	return out
```

- [ ] **Step 4: Solid ground and the floor in `WorldSurface`**

In `who-knows/src/world/world_surface.gd`:

Add to the class doc comment, before the floating-origin paragraph:

```gdscript
## Round every space anchor near the ground its finest chunks are solid too
## (§5.5): the one right under it built at once if it is missing, the rest
## streamed. If an anchor ever ends up more than FLOOR_SLACK under the ground
## -- a chunk late, or continuous collision missing -- it is lifted out and a
## warning logged. That should never happen; the probe counts it.
```

Add constants and members:

```gdscript
## Below the ground by more than this, an anchor is lifted out (§5.5).
const FLOOR_SLACK := 0.5

## Tests quieten the floor's warning when they set it off on purpose.
static var warn_on_floor := true

## How many times an anchor was lifted out from under the ground.
var floor_fired := 0
## key -> StaticBody3D
var _solid := {}
var _wanted_solid := {}
```

In `update`, after `_prune()`, add:

```gdscript
	_keep_anchors_above_ground()
```

and before `_collect()`, add:

```gdscript
	_wanted_solid = _solid_wanted()
```

In `finish()`, add `_wanted_solid = _solid_wanted()` as its first line.

Change `_missing()` to include solid keys:

```gdscript
func _missing() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	_mutex.lock()
	for k in leaves:
		if not _chunks.has(k) and not _jobs.has(k) and not _done.has(k):
			out.append(k)
	for k: Vector4i in _wanted_solid:
		if not _solid.has(k) and not _jobs.has(k) and not _done.has(k) and not out.has(k):
			out.append(k)
	_mutex.unlock()
	return out
```

Change the loop in `_apply` to make solid pieces too:

```gdscript
		if wanted.has(k) and not _chunks.has(k):
			_make_chunk(data)
		if _wanted_solid.has(k) and not _solid.has(k):
			_make_solid(data)
```

At the end of `_prune()`, add:

```gdscript
	for k: Vector4i in _solid.keys():
		if not _wanted_solid.has(k):
			(_solid[k] as Node).queue_free()
			_solid.erase(k)
```

Add:

```gdscript
func solid_keys() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	out.assign(_solid.keys())
	return out

## Every finest chunk some anchor needs solid; the one under an anchor that
## is missing is built now.
func _solid_wanted() -> Dictionary:
	var out := {}
	for node in get_tree().get_nodes_in_group(AsteroidStream.SPACE_ANCHOR):
		var a := node as Node3D
		if a == null or not a.is_inside_tree():
			continue
		var local := universe.to_universe(a.global_position).minus(body.point)
		var keys := TerrainCollider.keys_near(terrain, depth_max, local, TerrainCollider.reach_for(_speed_of(a)))
		for k in keys:
			out[k] = true
		if not keys.is_empty() and not _solid.has(keys[0]):
			_make_solid(TerrainChunkData.build(terrain, keys[0]))
	return out

func _make_solid(data: TerrainChunkData) -> void:
	var b := StaticBody3D.new()
	b.name = "S%d_%d_%d_%d" % [data.key.x, data.key.y, data.key.z, data.key.w]
	b.collision_layer = BodyProxy.LAYER
	b.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(data.faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	b.add_to_group(Universe.EXTERIOR_SPACE)
	add_child(b)
	b.global_position = universe.to_engine(body.point.plus(Vector3(data.centre)))
	_solid[data.key] = b

## The analytic floor (§5.5): an anchor more than FLOOR_SLACK under the
## ground is put back above it, clear by its own reach, moving in no more.
## Not a ghosted hull at warp: it passes through everything on purpose.
func _keep_anchors_above_ground() -> void:
	for node in get_tree().get_nodes_in_group(AsteroidStream.SPACE_ANCHOR):
		var a := node as CollisionObject3D
		if a == null or not a.is_inside_tree() or a.collision_mask & BodyProxy.LAYER == 0:
			continue
		var local := universe.to_universe(a.global_position).minus(body.point)
		if local.is_zero_approx() or terrain.altitude_of(local) >= -FLOOR_SLACK:
			continue
		var up := local.normalized()
		var clear := float(a.get_meta(AsteroidStream.ANCHOR_RADIUS, 1.0))
		a.global_position = universe.to_engine(body.point.plus(up * (terrain.radius + terrain.height_at(up) + clear)))
		if a is RigidBody3D:
			var v := (a as RigidBody3D).linear_velocity
			(a as RigidBody3D).linear_velocity = v - up * minf(v.dot(up), 0.0)
		elif a is CharacterBody3D:
			var v := (a as CharacterBody3D).velocity
			(a as CharacterBody3D).velocity = v - up * minf(v.dot(up), 0.0)
		floor_fired += 1
		if warn_on_floor:
			push_warning("WorldSurface: %s was under %s's ground; lifted out" % [a.name, body.name])

static func _speed_of(a: Node3D) -> float:
	if a is RigidBody3D:
		return (a as RigidBody3D).linear_velocity.length()
	if a is CharacterBody3D:
		return (a as CharacterBody3D).velocity.length()
	return 0.0
```

- [ ] **Step 5: Remove the old shell**

In `who-knows/src/world/body_proxy.gd`: delete `NEAR_WITHIN`, `NEAR_HYSTERESIS`, `var _collider`, `is_near()`, `collider()`, `_make_near()`, `_drop_near()`, and the four lines in `place()` that make or drop the near collider. Keep `LAYER` (items and the avatar's masks use it). Its doc comment's shell sentence becomes: "The surface's own collision makes it solid where anything touches it (§5.5)."

In `who-knows/src/world/body_look.gd`: delete `NEAR_DETAIL` and `points()`, and change the subdivisions comment to "a world from afar (1,280 faces), and the star (1,280)."

Run: `git grep -n -e "is_near()" -e "NEAR_WITHIN" -e "NEAR_DETAIL" -e "\.collider()" -- who-knows`
Expected: nothing. Fix any hit.

- [ ] **Step 6: Run the tests**

Run: `-gtest=res://test/unit/test_world_surface.gd`, `test_body_proxy.gd`, `test_system_scene.gd`, `test_floating_origin_scene.gd`, `test_warp_scene.gd`.
Expected: PASS, output pristine (the floor test turns its warning off).

- [ ] **Step 7: Run the whole suite, then commit**

```bash
git add who-knows/src/world who-knows/test/unit
git commit -m "feat: world scale -- solid ground round you, and a floor nothing falls through"
```

---

### Task 11: The altitude speed limit

**Files:**
- Modify: `who-knows/src/world/whereabouts.gd`, `src/flight/flight_computer.gd`, `src/ui/vehicle_telemetry.gd`, `src/ui/panels/velocity_panel.gd`, `scenes/flight_test.gd`
- Create: `who-knows/test/unit/test_speed_limit.gd`

**Interfaces:**
- Consumes: `WorldTerrain` (Task 5).
- Produces:
  - `Whereabouts.well() -> SystemBody` (or null), `Whereabouts.altitude() -> float` (`INF` outside every well), static `Whereabouts.well_at(system, u) -> SystemBody`, `terrain_of(body) -> WorldTerrain`.
  - `FlightComputer`: `const LIMIT_PER_M := 1.0 / 40.0`, `const LIMIT_CAP := 1500.0`, `const LIMIT_EASE := 0.1`, `var whereabouts: Whereabouts`, `var current_limit: float`, static `speed_limit(altitude: float, well_top: float) -> float`, `speed_limit_now() -> float`.
  - `VehicleTelemetry.limit_raised: bool`; the velocity panel shows `LIMIT n` while it is.

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_speed_limit.gd`:

```gdscript
extends GutTest

## The speed limit rises with altitude inside a well (the world scale spec
## §6): 120 m/s on the ground, 1 m/s more for every 40 m up, at most 1,500,
## easing back to 120 over the top tenth of the well.

const FC := FlightComputer

func test_the_limit_climbs_with_altitude():
	assert_almost_eq(FC.speed_limit(0.0, 60000.0), 120.0, 1e-6)
	assert_almost_eq(FC.speed_limit(4000.0, 60000.0), 220.0, 1e-6)
	assert_almost_eq(FC.speed_limit(40000.0, 60000.0), 1120.0, 1e-6)
	assert_almost_eq(FC.speed_limit(54000.0, 60000.0), 1470.0, 1e-6, "the peak, just below the easing")

func test_it_eases_back_over_the_top_tenth_of_the_well():
	assert_almost_eq(FC.speed_limit(57000.0, 60000.0), lerpf(120.0, 1500.0, 0.5), 1e-6, "capped, then half eased")
	assert_almost_eq(FC.speed_limit(60000.0, 60000.0), 120.0, 1e-6)
	assert_almost_eq(FC.speed_limit(14250.0, 15000.0), lerpf(120.0, 120.0 + 14250.0 / 40.0, 0.5), 1e-6)

func test_the_limit_at_or_below_the_ground_is_the_cruise_ceiling():
	assert_almost_eq(FC.speed_limit(-3.0, 60000.0), 120.0, 1e-6)
	assert_almost_eq(FC.speed_limit(INF, 60000.0), 120.0, 1e-6)
	assert_almost_eq(FC.speed_limit(100.0, 0.0), 120.0, 1e-6)

# --- where you are ----------------------------------------------------------------

var _universe: Universe
var _where: Whereabouts
var _focus: Node3D
var _system: SystemRecipe

func _place(u: UniversePoint) -> void:
	_universe.origin = u
	_focus.global_position = Vector3.ZERO

func _setup_where() -> void:
	_system = SystemRecipe.from_seed(1337)
	_universe = Universe.new()
	add_child_autofree(_universe)
	_focus = Node3D.new()
	add_child_autofree(_focus)
	_universe.set_focus(_focus)
	_where = Whereabouts.new()
	add_child_autofree(_where)
	_where.setup(_system, _universe)

func test_the_well_you_are_in_and_your_height_over_its_ground():
	_setup_where()
	var p := _system.planets()[0]
	var t := _where.terrain_of(p)
	_place(p.point.plus(Vector3.UP * (p.radius + t.height_at(Vector3.UP) + 4000.0)))
	assert_eq(_where.well(), p)
	assert_almost_eq(_where.altitude(), 4000.0, 0.1)
	_place(p.point.plus(Vector3.UP * (p.well_radius + 100.0)))
	assert_null(_where.well())
	assert_eq(_where.altitude(), INF)

func test_the_flight_computer_holds_you_to_the_limit_where_you_are():
	_setup_where()
	var p := _system.planets()[0]
	var t := _where.terrain_of(p)
	var hull := RigidBody3D.new()
	hull.mass = 95300.0
	add_child_autofree(hull)
	var fc := FlightComputer.new()
	fc.hull_path = NodePath("../" + hull.name)
	hull.get_parent().add_child(fc)
	autofree(fc)
	fc.whereabouts = _where
	_universe.set_focus(hull)
	_universe.origin = p.point.plus(Vector3.UP * (p.radius + t.height_at(Vector3.UP) + 4000.0))
	hull.global_position = Vector3.ZERO
	hull.linear_velocity = Vector3(0, 0, -500)
	fc._physics_process(1.0 / 60.0)
	assert_almost_eq(fc.current_limit, 220.0, 0.5)
	assert_almost_eq(hull.linear_velocity.length(), 220.0, 0.5)
	var tm := fc.build_telemetry()
	assert_almost_eq(tm.cruise_limit, 220.0, 0.5)
	assert_true(tm.limit_raised)

func test_the_panel_shows_the_limit_only_while_it_is_raised():
	var panel := VelocityPanel.new()
	add_child_autofree(panel)
	var tm := VehicleTelemetry.new()
	tm.assist_enabled = true
	tm.cruise_limit = 1470.0
	tm.limit_raised = true
	panel.render(tm)
	assert_true(panel.mode_label.text.ends_with("LIMIT 1470"), panel.mode_label.text)
	tm.cruise_limit = 120.0
	tm.limit_raised = false
	panel.render(tm)
	assert_false(panel.mode_label.text.contains("LIMIT"), panel.mode_label.text)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `-gtest=res://test/unit/test_speed_limit.gd`
Expected: FAIL (`speed_limit` not found).

- [ ] **Step 3: `Whereabouts` knows the well and the height**

In `who-knows/src/world/whereabouts.gd`, add to the class doc comment:

```gdscript
## And which well you are in and how high you are over its ground (the world
## scale spec §7), for the speed limit: worked out when asked, from the
## world's own WorldTerrain, never cached between ticks.
```

Add a member after `var _since`:

```gdscript
## One WorldTerrain per world, by body id, for this thread.
var _terrains := {}
```

Add after `dust()`:

```gdscript
## The body whose well the focus is in, or null. Wells never overlap.
func well() -> SystemBody:
	var u := _focus_point()
	return well_at(recipe, u) if u != null else null

## How high the focus is over the ground of the well it is in; INF in none.
func altitude() -> float:
	var b := well()
	if b == null:
		return INF
	var local := _focus_point().minus(b.point)
	var t := terrain_of(b)
	return t.altitude_of(local) if t != null else local.length() - b.radius

## `body`'s ground, or null for the star.
func terrain_of(body: SystemBody) -> WorldTerrain:
	if body.recipe == null:
		return null
	if not _terrains.has(body.id):
		_terrains[body.id] = WorldTerrain.new(body.recipe)
	return _terrains[body.id]

static func well_at(system: SystemRecipe, u: UniversePoint) -> SystemBody:
	for b in system.bodies:
		if u.minus(b.point).length() <= b.well_radius:
			return b
	return null

func _focus_point() -> UniversePoint:
	if recipe == null or universe == null or not is_instance_valid(universe.focus) \
			or not universe.focus.is_inside_tree():
		return null
	return universe.to_universe(universe.focus.global_position)
```

- [ ] **Step 4: The flight computer holds you to it**

In `who-knows/src/flight/flight_computer.gd`, after `BOOST_MULTIPLIER`:

```gdscript
## Inside a well the limit climbs with altitude (the world scale spec §6): 1 m/s
## more for every 40 m up, to LIMIT_CAP, easing back to CRUISE_LIMIT_MPS over
## the top LIMIT_EASE of the well so you leave it at the speed the rocks
## outside stream for. At full speed you are always about 40 s from the ground.
const LIMIT_PER_M := 1.0 / 40.0
const LIMIT_CAP := 1500.0
const LIMIT_EASE := 0.1
```

After `var warp`:

```gdscript
## Where you are, for the limit; null means the cruise ceiling everywhere, as
## in every test that never sets it.
var whereabouts: Whereabouts = null
## This tick's limit with the assist on, m/s.
var current_limit := CRUISE_LIMIT_MPS
```

Add after `forward_speed()`:

```gdscript
## The assist's limit `altitude` over the ground of a well whose edge is
## `well_top` over it (§6). Pure. The cruise ceiling outside a well, on or
## under the ground, and above the well's edge.
static func speed_limit(altitude: float, well_top: float) -> float:
	if is_inf(altitude) or well_top <= 0.0 or altitude >= well_top:
		return CRUISE_LIMIT_MPS
	var a := maxf(altitude, 0.0)
	var climb := minf(CRUISE_LIMIT_MPS + a * LIMIT_PER_M, LIMIT_CAP)
	var ease := clampf((well_top - a) / (LIMIT_EASE * well_top), 0.0, 1.0)
	return lerpf(CRUISE_LIMIT_MPS, climb, ease)

## The limit where the focus is now.
func speed_limit_now() -> float:
	if whereabouts == null:
		return CRUISE_LIMIT_MPS
	var b := whereabouts.well()
	if b == null:
		return CRUISE_LIMIT_MPS
	return speed_limit(whereabouts.altitude(), b.well_radius - b.radius)
```

In `_apply_translation`, as its first line:

```gdscript
	current_limit = speed_limit_now()
```

and replace the two uses of `CRUISE_LIMIT_MPS` in it:

```gdscript
		locked_speed = clampf(-local_velocity.z, -current_limit, current_limit)
```

```gdscript
	if assist_enabled and _hull.linear_velocity.length() > current_limit:
		_hull.linear_velocity = _hull.linear_velocity.normalized() * current_limit
```

In `build_telemetry`, replace the `CRUISE_LIMIT_MPS` argument with `current_limit`, and after `t.locked_speed = locked_speed` add:

```gdscript
	t.limit_raised = current_limit > CRUISE_LIMIT_MPS + 0.5
```

- [ ] **Step 5: The panel shows it**

In `who-knows/src/ui/vehicle_telemetry.gd`, after `var cruise_limit`:

```gdscript
## True while the limit is above the cruise ceiling: high in a world's well
## (the world scale spec §6).
var limit_raised: bool = false
```

In `who-knows/src/ui/panels/velocity_panel.gd` replace the `mode_label.text = ...` statement with:

```gdscript
	mode_label.text = "ASSIST %s   BOOST %s" % [
		"ON" if telemetry.assist_enabled else "OFF",
		"ON" if telemetry.boost_active else "OFF",
	]
	# High in a world's well the limit climbs (the world scale spec §6).
	if telemetry.limit_raised:
		mode_label.text += "   LIMIT %d" % roundi(telemetry.cruise_limit)
```

- [ ] **Step 6: Wire it in the flight scene**

In `who-knows/scenes/flight_test.gd`, on the line after `_ship.sensors.whereabouts = star_system.whereabouts`, add:

```gdscript
	# The speed limit climbs with altitude in a world's well (the world scale
	# spec §6); where you are is Whereabouts' to say.
	_ship.flight_computer.whereabouts = star_system.whereabouts
```

- [ ] **Step 7: Run the tests**

Run: `-gtest=res://test/unit/test_speed_limit.gd`, `test_flight_computer.gd`, `test_whereabouts.gd`, `test_system_scene.gd`, and any velocity panel test (`git grep -l VelocityPanel who-knows/test`).
Expected: PASS.

- [ ] **Step 8: Run the whole suite, then commit**

```bash
git add who-knows/src who-knows/scenes/flight_test.gd who-knows/test/unit/test_speed_limit.gd
git commit -m "feat: world scale -- the speed limit climbs with altitude in a world's well"
```

---

# Part C — measure, show, document

### Task 12: The descent probe and the renders

**Files:**
- Create: `who-knows/test/probes/world_probe.gd`

**Interfaces:**
- Consumes: everything above. Reads `WorldSurface.visible_chunks()`, `floor_fired`, `FlightComputer.speed_limit`, `Performance` monitors.

- [ ] **Step 1: Write the probe**

Create `who-knows/test/probes/world_probe.gd`:

```gdscript
extends SceneTree

# A big world in the real flight scene, for the owner and for the budgets
# (docs/superpowers/specs/2026-09-30-world-scale-design.md §5.6, §8.3). Run it
# WITHOUT --headless so it renders and the frame times mean something:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/world_probe.gd -- <abs out dir> [seed]
#
# Writes world_*.png: the largest planet from a neighbour, from its warp limit,
# from its well's edge, from 1 km, skimming at 150 m, standing (1.6 m), a
# moon in its sky, and a belt from a planet. Then flies from the limit to
# 150 m at the speed limit and skims 20 km, printing per phase: the worst
# frame, chunks drawn and built, draw calls, and the floor's count.

var _out := ""
var _root: Node
var _ship: Ship
var _universe: Universe
var _stream: AsteroidStream
var _system: SystemRecipe
var _planet: SystemBody
var _terrain: WorldTerrain

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_root = load("res://scenes/flight_test.tscn").instantiate()
	if args.size() > 1 and args[1].is_valid_int():
		(_root.get_node("AsteroidStream") as AsteroidStream).seed = args[1].to_int()
	# Never the owner's game: saving is on outside --headless.
	_root.save_enabled = false
	root.add_child(_root)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _frames(8)
	var file := "%s/world_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s   %s" % [file, _root.star_system.whereabouts.text()])

func _surface() -> WorldSurface:
	return (_root.star_system.proxy(_planet.id) as BodyProxy).surface()

## Puts the hull, at rest, at `at`, facing `target`, and everything outside
## ready for it, the ground built.
func _put(at: UniversePoint, target: UniversePoint) -> void:
	var hull := _ship.exterior
	hull.linear_velocity = Vector3.ZERO
	hull.angular_velocity = Vector3.ZERO
	var dir := target.minus(at).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	hull.global_transform = Transform3D(Basis.looking_at(dir, up), _universe.to_engine(at))
	_universe.check()
	_root.star_system.place_all()
	_root.star_system.whereabouts.look()
	_stream.update(0.0, true)
	if _surface() != null:
		_surface().finish()

func _ground(dir: Vector3, above: float) -> UniversePoint:
	return _planet.point.plus(dir * (_planet.radius + _terrain.height_at(dir) + above))

func _run() -> void:
	await _frames(5)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	_stream = _root.get_node("AsteroidStream")
	_system = _root.system
	for p in _system.planets():
		if _planet == null or p.radius > _planet.radius:
			_planet = p
	_terrain = WorldTerrain.new(_planet.recipe)
	print("probe   %s  r %.0f m  relief %.0f m  %s" % [_planet.name, _planet.radius, _terrain.relief,
		WorldRecipe.Archetype.keys()[_planet.recipe.archetype]])
	# On the sunward side, a little off the line to the star, so relief shades.
	var sun := _system.star.point.minus(_planet.point).normalized()
	var dir := sun.rotated(Vector3.UP, 0.6).normalized()
	var neighbour := _nearest_other(_planet)
	_put(neighbour.point.plus(_planet.point.minus(neighbour.point).normalized() * neighbour.warp_limit), _planet.point)
	await _shot("from_neighbour")
	_put(_planet.point.plus(dir * _planet.warp_limit), _planet.point)
	await _shot("from_limit")
	_put(_planet.point.plus(dir * _planet.well_radius), _planet.point)
	await _shot("from_well_edge")
	var ahead := dir.cross(Vector3.UP).normalized()
	_put(_ground(dir, 1000.0), _ground(dir.rotated(Vector3.UP.cross(dir).normalized(), 0.05), 0.0))
	await _shot("from_1km")
	_put(_ground(dir, 150.0), _ground(dir.rotated(ahead, 0.01), 150.0))
	await _shot("skimming_150m")
	await _standing(dir)
	await _moon_in_the_sky(dir)
	await _belt_from_a_planet()
	await _descend(dir)
	print("probe   done")
	quit()

func _nearest_other(p: SystemBody) -> SystemBody:
	var best: SystemBody = null
	for q in _system.planets():
		if q != p and (best == null or q.point.minus(p.point).length() < best.point.minus(p.point).length()):
			best = q
	return best

## A camera at 1.6 m on the ground, looking along it: eye height (CLAUDE.md).
func _standing(dir: Vector3) -> void:
	_put(_ground(dir, 30.0), _ground(dir.rotated(Vector3.UP.cross(dir).normalized(), 0.001), 30.0))
	var cam := Camera3D.new()
	cam.far = BodyProxy.VIEW_FAR
	cam.near = 0.05
	cam.add_to_group(Universe.EXTERIOR_SPACE)
	_root.get_node("Outside").add_child(cam)
	var eye := _ground(dir, 1.6)
	var look := _ground(dir.rotated(Vector3.UP.cross(dir).normalized(), 0.002), 1.6)
	cam.global_transform = Transform3D(Basis.looking_at(look.minus(eye).normalized(), dir), _universe.to_engine(eye))
	cam.make_current()
	await _shot("standing")
	cam.queue_free()
	await _frames(2)

func _moon_in_the_sky(dir: Vector3) -> void:
	var moons := _system.moons_of(_planet)
	if moons.is_empty():
		print("probe   no moon round %s" % _planet.name)
		return
	var m := moons[0]
	var up := m.point.minus(_planet.point).normalized()
	_put(_ground(up.slerp(dir, 0.3).normalized(), 200.0), m.point)
	await _shot("moon_in_the_sky")

func _belt_from_a_planet() -> void:
	if _system.belts.is_empty():
		return
	var belt := _system.belts[0]
	var best: SystemBody = null
	for p in _system.planets():
		var r := p.point.minus(belt.centre).length()
		if best == null or absf(r - belt.radius) < absf(best.point.minus(belt.centre).length() - belt.radius):
			best = p
	var out := best.point.minus(belt.centre)
	var at := best.point.plus(-out.normalized() * best.warp_limit)
	var target := belt.centre.plus(out.normalized() * belt.radius)
	_put(at, target)
	await _shot("belt_from_planet")

## From the limit to 150 m at the speed limit, then 20 km at 150 m, the hull
## carried by hand (frozen, so physics never fights the script).
func _descend(dir: Vector3) -> void:
	var hull := _ship.exterior
	_put(_planet.point.plus(dir * _planet.warp_limit), _planet.point)
	hull.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	hull.freeze = true
	var well_top := _planet.well_radius - _planet.radius
	var worst := 0.0
	var calls := 0
	var chunks := 0
	var t0 := Time.get_ticks_usec()
	var fell := 0
	while true:
		await physics_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - t0) / 1000.0)
		t0 = now
		var u := _universe.to_universe(hull.global_position)
		var alt := _terrain.altitude_of(u.minus(_planet.point))
		if alt <= 150.0:
			break
		var limit := FlightComputer.speed_limit(alt, well_top)
		var step := minf(limit / 60.0, alt - 150.0)
		hull.global_position += -dir * step
		calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if _surface() != null:
			chunks = maxi(chunks, _surface().visible_chunks().size())
			fell = _surface().floor_fired
	print("probe   descent  worst frame %.1f ms  draw calls %d  chunks drawn %d  floor %d" % [worst, calls, chunks, fell])
	await _shot("after_descent")
	worst = 0.0
	calls = 0
	chunks = 0
	var ahead := dir.cross(Vector3.UP).normalized()
	var travelled := 0.0
	var here := dir
	t0 = Time.get_ticks_usec()
	while travelled < 20000.0:
		await physics_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - t0) / 1000.0)
		t0 = now
		var limit := FlightComputer.speed_limit(150.0, well_top)
		var angle := limit / 60.0 / (_planet.radius + 150.0)
		here = here.rotated(ahead.cross(here).normalized(), angle).normalized()
		travelled += limit / 60.0
		var at := _ground(here, 150.0)
		hull.global_position = _universe.to_engine(at)
		calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if _surface() != null:
			chunks = maxi(chunks, _surface().visible_chunks().size())
			fell = _surface().floor_fired
	print("probe   skim 20 km  worst frame %.1f ms  draw calls %d  chunks drawn %d  floor %d" % [worst, calls, chunks, fell])
	hull.freeze = false
```

- [ ] **Step 2: Run the probe**

Run (not headless, from the repo root):

```powershell
$godot = "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe"
New-Item -ItemType Directory -Force "$env:TEMP\world_probe" | Out-Null
& $godot --path who-knows --resolution 1280x720 --script res://test/probes/world_probe.gd -- "$env:TEMP\world_probe"
```

Expected: `render` lines for every shot, two `probe` lines with numbers, then `probe   done`. Compare with spec §5.6: worst frame ≤ 33 ms, chunks drawn ≤ 150, floor 0. Record the four numbers of each phase.

If the worst frame or chunks are over budget, apply spec §5.6's levers in order and rerun, recording each result: (a) `CubeSphere.QUADS` 32 with `FINEST_QUAD` 2.0 (a quarter as many chunks; rerun Tasks 6–10's tests), (b) lower `MAX_JOBS` if frames spike while building. The floor firing is a bug, not a tuning question: find why a solid chunk was missing.

- [ ] **Step 3: The map and system renders**

Run the existing probes, which now show the new scale:

```powershell
& $godot --path who-knows --resolution 1280x720 --script res://test/probes/system_render.gd -- "$env:TEMP\world_probe"
& $godot --path who-knows --resolution 1280x720 --script res://test/probes/computer_render.gd -- "$env:TEMP\world_probe"
```

Expected: `system_*.png` and `computer_*.png` written.

- [ ] **Step 4: Show the owner**

Look at every `world_*.png` yourself first against `docs/design/visual-style.md` (stylized, warm, dim; broad flat patches, never noise). Then send them, the system SYSTEM-range and 500 km map renders, and the probe's numbers to the owner with SendUserFile, asking for approval of the look. **Do not tune colours or add a style rule without the owner's approval** (CLAUDE.md). Record the owner's answer for Task 13.

- [ ] **Step 5: Commit**

```bash
git add who-knows/test/probes/world_probe.gd
git commit -m "test: world scale -- the descent probe and a big world's renders"
```

---

### Task 13: The documents and the skill

**Files:**
- Modify: `docs/superpowers/specs/2026-09-27-star-systems-design.md`, `2026-09-27-system-skeleton-design.md`, `2026-09-28-warp-design.md`, `2026-09-23-planetfall-design.md`, `2026-09-30-world-scale-design.md`
- Modify: `.claude/skills/building-a-ship/SKILL.md`, `reference.md`
- Modify (only with the owner's approval from Task 12): `docs/design/visual-style.md`

- [ ] **Step 1: Amendment notes in the specs this one amends**

Add under the header of each, after its last existing amendment note, a blockquote in the house style:

`2026-09-27-star-systems-design.md`:

```markdown
> **Amended 2026-09-30 by the world scale spec** (`2026-09-30-world-scale-design.md`): the
> *Scale* decision (§2) is replaced: planets are 15–60 km, moons 4–15 km, the star 200–300 km,
> and a system is about 15,000 km across (its §3). §4.1's and §4.3's numbers are that spec's.
> §6's proxies sit at 350 km inside a 400 km far plane, and near a world its surface is a
> quadtree drawn at true scale (its §5), not a swap to a real `Planet` at 20 km.
```

`2026-09-27-system-skeleton-design.md`:

```markdown
> **Amended 2026-09-30 by the world scale spec** (`2026-09-30-world-scale-design.md` §5): a
> proxy keeps its far mesh, now sampled from `WorldTerrain`, and hands over to a
> `WorldSurface` within min(10 radii, 300 km). The near shell and its convex collider are gone;
> the surface's own collision replaces them.
```

`2026-09-28-warp-design.md`:

```markdown
> **Amended 2026-09-30 by the world scale spec** (`2026-09-30-world-scale-design.md` §3.3,
> §3.4): moons are warp targets, each wholly outside its planet's limit, and block a line like
> a planet. A planet's limit is its well + 14 km and past its ring, no longer at least its
> neighbourhood. Travel is 18 s + 1 s per 350 km; the cost is 40 QE + 1 QE per 12.5 km
> (`WARP_M_PER_QE`). The map's ranges are 2, 10, 50 and 500 km and the system.
```

`2026-09-23-planetfall-design.md`:

```markdown
> **Amended 2026-09-30 by the world scale spec** (`2026-09-30-world-scale-design.md`): worlds
> are 15–60 km (moons 4–15 km) with relief up to 1.2 km (§3, §5.2), and the well is 2 radii
> (§7.1). The terrain of §6 is built there, at the new depths, as `WorldTerrain`, `CubeSphere`,
> `TerrainChunkData`, `WorldSurface` and `TerrainCollider`, with the analytic floor of §8.5;
> boulders are still this spec's. What stays here: gravity, the assisted descent, landing,
> the airlock step-out, walking, boulders, sites and the atmosphere.
```

In `2026-09-30-world-scale-design.md`, change the **Status** line to say it is built on `world-scale`, and add a `## 13. What was built` section listing: the dates, the probe's numbers from Task 12 (worst frame, chunks, draw calls, floor, for descent and skim), any lever pulled (`QUADS`, `SPLIT`, `PACE`, `BELT_GAP`) with its value and why, the owner's verdict on the look, and the test count before and after.

- [ ] **Step 2: The `building-a-ship` skill (CLAUDE.md)**

In `.claude/skills/building-a-ship/SKILL.md`, replace the warp reach row with:

```markdown
| Warp reach on a full store | `(quantum_capacity − WarpPlan.WARP_BASE) × WarpPlan.WARP_M_PER_QE / 1000` km | 14,500 km on 1,200 QE (7,000 km on its starting 600) |
```

Add a line to its checklist (next to the warp line):

```markdown
- [ ] **Near a world the assist's limit climbs with altitude** (`FlightComputer.speed_limit`,
      the world scale spec §6): anything else that caps the hull's speed must use
      `current_limit`, never `CRUISE_LIMIT_MPS`, and a ship's `Whereabouts` must be wired
      (`flight_computer.whereabouts`) or it is held to 120 m/s everywhere.
```

Add to *Mistakes already made*:

```markdown
| Writing a warp cost as 0.08 QE per km | `ceili(0.08 * 3000)` is 241, not 240: 0.08 is not exact in floating point | Price per whole units the other way round: `WarpPlan.WARP_M_PER_QE` (metres per QE) |
```

In `.claude/skills/building-a-ship/reference.md`, in the warp table replace the Cost and Travel rows:

```markdown
| Cost | 40 QE + 1 QE per 12.5 km, rounded up | `WarpPlan.WARP_BASE`, `WARP_M_PER_QE` |
| Travel | 18 s + 1 s per 350 km; 4 s ramps; 120 m/s at both ends | `WarpProfile.BASE_TIME`, `PACE`, `RAMP`, `EDGE_SPEED` |
```

change the Warp limit row to `a body's well (a cluster's 4 km) + 14 km; a planet's also past its ring; moons are targets too`, and add a section after the warp section:

```markdown
## Flying near a world (`docs/superpowers/specs/2026-09-30-world-scale-design.md` §6)

| What | Value | Where |
|---|---|---|
| Speed limit in a well, assist on | 120 m/s + 1 m/s per 40 m of altitude, at most 1,500 | `FlightComputer.speed_limit`, `LIMIT_PER_M`, `LIMIT_CAP` |
| Easing at the well's edge | back to 120 m/s over the top tenth | `FlightComputer.LIMIT_EASE` |
| Where you are | the well and the altitude over its ground | `Whereabouts.well()`, `altitude()` |
| Solid ground round the hull | 64 m + 1 s × speed, at most 160 m | `TerrainCollider` |
| The floor | an anchor > 0.5 m under the ground is lifted out, `WorldSurface.floor_fired` counts it | `WorldSurface.FLOOR_SLACK` |

The hull is a space anchor (`AsteroidStream.SPACE_ANCHOR`), so a world's surface keeps ground
solid under it with no wiring. A ghosted hull (mask 0, at warp) is never lifted.
```

Run: `git grep -n -e WARP_PER_KM -e "4 QE per km" -e "1 s per 5 km" -- .claude docs/superpowers/specs/2026-09-30-world-scale-design.md who-knows`
Expected: nothing.

- [ ] **Step 3: The style guide, only if approved**

If the owner approved the look in Task 12, add to `docs/design/visual-style.md`'s worlds section a *Worlds up close* rule stating what was approved (flat-shaded chunks, one palette colour a triangle, shade patches about six triangles across, rock on slopes over 35°), with the date and the render names. If not approved, leave the guide alone and note in the world scale spec §13 what the owner asked for instead.

- [ ] **Step 4: Run the whole suite**

Run: `& .\who-knows\run_tests.ps1`
Expected: `---- All tests passed! ----`, output pristine, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add docs .claude/skills/building-a-ship
git commit -m "docs: world scale -- the specs it amends, what was built, and the ship skill"
```
