# Asteroids Implementation Plan (build steps 2–6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fixed debris field with asteroids streamed in around you from a seed:
batched pictures far away, sleeping physics bodies near the path of the hull or a spacewalker,
loaded well before they could be seen.

**Architecture:** `AsteroidRecipe` is a pure function from (seed, tier, cell) to rocks, run on
worker threads. `AsteroidStream` keeps the cells around the `Universe` focus loaded and draws
them as blocks of MultiMeshes. `AsteroidBubble` turns rocks near an anchor's path into
`AsteroidBody`s and back. `RockMesh` and `SpacePalette` give the look. The floating origin (plan 1)
moves every block and body.

**Tech Stack:** Godot 4.5.1 (.NET build, GDScript only), GUT 9, `run_tests.ps1`,
`WorkerThreadPool`.

**Spec:** `docs/superpowers/specs/2026-09-24-asteroids-design.md` (§5–§12). Plan 1
(`2026-09-24-floating-origin.md`) is merged: `Universe`, `UniversePoint`,
`Universe.EXTERIOR_SPACE` exist.

## Global Constraints

- Tiers (spec §5.1): cells 200 / 1000 / 5000 m; diameters 1–5 / 5–40 / 40–300 m; at most
  24 / 12 / 3 rocks per cell; detail 0 / 1 / 2 subdivisions (20 / 80 / 320 triangles).
- Distances (spec §6.1): fade 600→450 / 4000→3000 / 20000→15000 m; load 900 / 5000 / 25000 m;
  unload 1100 / 5500 / 30000 m. Head start: load − fade end ≥ 300 m/s × 1 s.
- Bubble (spec §7): pad 24 m, lookahead 1.5 s, let go after 2 s, adrift at 1 cm or 0.5°,
  at most 96 adrift.
- Physics layer 7 `asteroids` = 64. Rock mask 101; hull mask 65; suit mask 97.
- Colours only from `SpacePalette` (or the palettes it references) in every new file; no colour
  literals. No new shader: `StandardMaterial3D` with distance fade.
- Every block node and every body is a member of `Universe.EXTERIOR_SPACE`, under a holder that
  never moves. Positions that must survive a shift are `UniversePoint`s.
- Recipes touch no nodes and share nothing across threads; each worker job builds its own
  `AsteroidRecipe`.
- GUT, headless, output pristine, **no orphans**: anything pooled out of the tree is freed on
  exit.
- `.tscn`: no `#` comments; read edited nodes back at runtime.
- Run the import pass after new `class_name`s. Commits end with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Worktree `D:\git\whoknows-asteroids`, branch `asteroids`.

---

## File Structure

| File | Responsibility |
|---|---|
| Create `who-knows/src/world/space_palette.gd` | Rock colours and the crystal. |
| Create `who-knows/src/world/rock_mesh.gd` | The three base shapes at three details; hull points. |
| Create `who-knows/src/world/asteroid_rock.gd` | One rock's data. |
| Create `who-knows/src/world/asteroid_recipe.gd` | Density, the cell hash, a cell's rocks, the start. |
| Create `who-knows/src/world/asteroid_stream.gd` | Cells, jobs, blocks, materials; the bubble's queries. |
| Create `who-knows/src/world/asteroid_bubble.gd` | Promote, let go, adrift, drop, the cap, the pool. |
| Create `who-knows/src/world/asteroid_body.gd` | One touchable rock. |
| Create tests `test_rock_mesh.gd`, `test_asteroid_recipe.gd`, `test_asteroid_stream.gd`, `test_asteroid_bubble.gd`, `test_crash_feel.gd` | As named. |
| Modify `who-knows/src/ship/ship.gd` | Hull: mask, CCD, anchor, anchor radius, thump. |
| Modify `who-knows/src/avatar/avatar.gd` | Suit mask, anchor, bumps in space. |
| Modify `who-knows/src/camera/motion_coupling.gd` | The shove cap and the jolt. |
| Modify `who-knows/src/audio/synth.gd`, `test_synth.gd` | `hull_thump`. |
| Modify `who-knows/scenes/flight_test.tscn`, `flight_test.gd` | Stream in, debris out, the start, the readout. |
| Modify `who-knows/project.godot` | Layer 7 name. |
| Delete `who-knows/src/world/debris_field.gd` (+ `.uid`) | Replaced. |
| Modify `test_visual_style_rules.gd`, `docs/design/visual-style.md`, the specs | Rules and records. |

---

### Task 1: The look — SpacePalette and RockMesh

**Files:** create `space_palette.gd`, `rock_mesh.gd`, `test/unit/test_rock_mesh.gd`; modify
`test/unit/test_visual_style_rules.gd` (`PAINTING_FILES`).

**Interfaces — Produces:** `SpacePalette.ASH/UMBER/SLATE/RUST/SAND`, `ROCKS: Array[Color]`,
`CRYSTAL`, `UNTINTED`; `RockMesh.Shape {BOULDER, SHARD, VEINED}`, `RockMesh.REACH := 0.65`,
`static func mesh(shape: int, detail: int) -> ArrayMesh`,
`static func hull_points(shape: int, detail: int) -> PackedVector3Array`.

- [ ] **Step 1: Write the failing tests**

**File:** `who-knows/test/unit/test_rock_mesh.gd`

```gdscript
extends GutTest

## The rock shapes (docs/superpowers/specs/2026-09-24-asteroids-design.md §8):
## chunky, flat-shaded, wound the way Godot draws, within reach, and tinted
## per rock -- except the veined one, which carries its own crystal.

const SHAPES := [RockMesh.Shape.BOULDER, RockMesh.Shape.SHARD, RockMesh.Shape.VEINED]

func _arrays(shape: int, detail: int) -> Array:
	return RockMesh.mesh(shape, detail).surface_get_arrays(0)

func test_detail_sets_the_triangle_count():
	for detail in 3:
		var v: PackedVector3Array = _arrays(RockMesh.Shape.BOULDER, detail)[Mesh.ARRAY_VERTEX]
		assert_eq(v.size() / 3, [20, 80, 320][detail])

func test_every_vertex_is_within_reach():
	var worst := 0.0
	for shape in SHAPES:
		for detail in 3:
			for v in RockMesh.hull_points(shape, detail):
				worst = maxf(worst, v.length())
	assert_lte(worst, RockMesh.REACH + 0.0001)
	assert_gt(worst, 0.45, "and it is a rock of diameter about one")

func test_flat_shaded_and_wound_for_godot():
	var bad := 0
	for shape in SHAPES:
		for detail in 3:
			var a := _arrays(shape, detail)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			for t in range(0, v.size(), 3):
				var face := (v[t + 1] - v[t]).cross(v[t + 2] - v[t])
				if n[t] != n[t + 1] or n[t] != n[t + 2]:
					bad += 1
				elif face.length() > 1e-7 and face.dot(n[t]) >= 0.0:
					bad += 1
				elif n[t].dot(v[t] + v[t + 1] + v[t + 2]) <= 0.0:
					bad += 1
	assert_eq(bad, 0, "every triangle flat, facing out, drawn from outside")

func test_only_the_veined_shape_has_colours_of_its_own():
	for shape in SHAPES:
		var colours: PackedColorArray = _arrays(shape, 1)[Mesh.ARRAY_COLOR]
		var crystal := 0
		var rock := 0
		for c in colours:
			if c == SpacePalette.CRYSTAL:
				crystal += 1
			elif c != SpacePalette.UNTINTED:
				rock += 1
		if shape == RockMesh.Shape.VEINED:
			assert_gt(crystal, 0, "a vein of crystal")
			assert_gt(rock, crystal, "in a rock that is mostly rock")
		else:
			assert_eq(crystal + rock, 0, "white, so each rock's own tint shows")

func test_meshes_are_built_once_and_shared():
	assert_same(RockMesh.mesh(RockMesh.Shape.SHARD, 1), RockMesh.mesh(RockMesh.Shape.SHARD, 1))

func test_hull_points_are_the_distinct_vertices():
	assert_eq(RockMesh.hull_points(RockMesh.Shape.BOULDER, 0).size(), 12)
	assert_eq(RockMesh.hull_points(RockMesh.Shape.BOULDER, 2).size(), 162)

func test_the_cuts_make_facets_not_a_ball():
	var cut := 0
	var pts := RockMesh.hull_points(RockMesh.Shape.BOULDER, 2)
	for p in pts:
		if p.length() < 0.49:
			cut += 1
	assert_gt(cut, pts.size() / 3, "much of the surface lies on flat cuts")
```

- [ ] **Step 2: Run to verify failure** — `& .\who-knows\run_tests.ps1 '-gselect=test_rock_mesh'`:
  parse errors, `RockMesh` not declared.

- [ ] **Step 3: Implement**

**File:** `who-knows/src/world/space_palette.gd`

```gdscript
class_name SpacePalette
extends RefCounted

## The colours of the world outside the ship that is not the hull
## (docs/superpowers/specs/2026-09-24-asteroids-design.md §8): dusty, warm rock,
## and the lavender crystal the rock sample aboard came from. Lit by the sun,
## so they sit mid-dark. Tuned by rendering.

const ASH := Color(0.36, 0.34, 0.32)
const UMBER := Color(0.33, 0.26, 0.21)
const SLATE := Color(0.28, 0.28, 0.29)
const RUST := Color(0.41, 0.28, 0.21)
const SAND := Color(0.47, 0.42, 0.35)
## One per rock, as its instance colour.
const ROCKS: Array[Color] = [ASH, UMBER, SLATE, RUST, SAND]
## Crystal veins: the rock sample's lavender, the same palette entry.
const CRYSTAL := InteriorPalette.LAVENDER
## No tint: white, so a veined rock's own vertex colours show.
const UNTINTED := Color(1, 1, 1)
```

**File:** `who-knows/src/world/rock_mesh.gd`

```gdscript
class_name RockMesh
extends RefCounted

## The base rock shapes (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §8): chunky, faceted, flat-shaded. Each is a sphere cut by a handful of
## seeded planes -- big flat facets, like stone split along its grain --
## sampled at an icosphere's vertices, so the shape is convex and its collision
## hull is the rock you see. Built once per (shape, detail) and shared by every
## rock.
##
## Diameter one: no vertex lies farther than REACH from the centre. A rock
## scales it by its diameter and stretch.

enum Shape { BOULDER, SHARD, VEINED }

## The farthest any shape's vertex lies from its centre, at diameter one.
const REACH := 0.65

## Per shape: seed, cut planes, nearest and farthest cut (a fraction of the
## radius), and a stretch baked into the shape.
const _RECIPES := {
	Shape.BOULDER: [101, 12, 0.78, 0.93, Vector3(1.0, 1.0, 1.0)],
	Shape.SHARD: [202, 9, 0.62, 0.86, Vector3(0.82, 0.74, 1.3)],
	Shape.VEINED: [303, 12, 0.76, 0.92, Vector3(1.05, 0.95, 1.0)],
}
## A veined rock's crystal: faces whose centre lies this close to the vein's
## great circle, on one side of the rock.
const _VEIN_AXIS := Vector3(0.3, 1.0, 0.2)
const _VEIN_WIDTH := 0.16

static var _spheres := {}
static var _meshes := {}
static var _points := {}

## The shared mesh for `shape` at `detail` subdivisions (0: 20 triangles, 1:
## 80, 2: 320). Vertex colours are white, so a rock's instance colour tints it
## -- except the veined shape, which carries rock and crystal itself.
static func mesh(shape: int, detail: int) -> ArrayMesh:
	var key := shape * 10 + detail
	if not _meshes.has(key):
		_meshes[key] = _build(shape, detail)
	return _meshes[key]

## The shape's distinct vertices, for its convex collision shape.
static func hull_points(shape: int, detail: int) -> PackedVector3Array:
	var key := shape * 10 + detail
	if not _points.has(key):
		var seen := {}
		var out := PackedVector3Array()
		for v in _vertices(shape, detail):
			if not seen.has(v):
				seen[v] = true
				out.append(v)
		_points[key] = out
	return _points[key]

static func _build(shape: int, detail: int) -> ArrayMesh:
	var sphere := _icosphere(detail)
	var dirs: PackedVector3Array = sphere[0]
	var faces: PackedInt32Array = sphere[1]
	var verts := _vertices(shape, detail)
	var vein := _VEIN_AXIS.normalized()
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for t in range(0, faces.size(), 3):
		var a := verts[faces[t]]
		var b := verts[faces[t + 1]]
		var c := verts[faces[t + 2]]
		var cross := (b - a).cross(c - a)
		if cross.dot(a + b + c) > 0.0:
			# Godot draws the side (b - a) x (c - a) points away from.
			var swap := b
			b = c
			c = swap
			cross = -cross
		var n := -cross.normalized()
		var colour := SpacePalette.UNTINTED
		if shape == Shape.VEINED:
			var d := (dirs[faces[t]] + dirs[faces[t + 1]] + dirs[faces[t + 2]]).normalized()
			var in_vein := absf(d.dot(vein)) < _VEIN_WIDTH and d.x > -0.3
			colour = SpacePalette.CRYSTAL if in_vein else SpacePalette.ASH
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

## Every icosphere vertex, pulled in to the shape's cut planes.
static func _vertices(shape: int, detail: int) -> PackedVector3Array:
	var recipe: Array = _RECIPES[shape]
	var rng := RandomNumberGenerator.new()
	rng.seed = recipe[0]
	var planes: Array[Vector4] = []
	while planes.size() < recipe[1]:
		var n := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if n.length() < 0.2:
			continue
		n = n.normalized()
		planes.append(Vector4(n.x, n.y, n.z, rng.randf_range(recipe[2], recipe[3])))
	var stretch: Vector3 = recipe[4]
	var out := PackedVector3Array()
	var dirs: PackedVector3Array = _icosphere(detail)[0]
	for d in dirs:
		var r := 1.0
		for p in planes:
			var along := d.x * p.x + d.y * p.y + d.z * p.z
			if along > 0.05:
				r = minf(r, p.w / along)
		out.append(d * r * 0.5 * stretch)
	return out

## Unit directions and triangles of an icosahedron subdivided `detail` times.
static func _icosphere(detail: int) -> Array:
	if _spheres.has(detail):
		return _spheres[detail]
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var dirs: Array[Vector3] = []
	for c in [Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
			Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
			Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1)]:
		dirs.append(c.normalized())
	var faces := PackedInt32Array([
		0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
		1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
		4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for level in detail:
		var mids := {}
		var next := PackedInt32Array()
		for t in range(0, faces.size(), 3):
			var a := faces[t]
			var b := faces[t + 1]
			var c := faces[t + 2]
			var ab := _mid(dirs, mids, a, b)
			var bc := _mid(dirs, mids, b, c)
			var ca := _mid(dirs, mids, c, a)
			next.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
		faces = next
	var sphere := [PackedVector3Array(dirs), faces]
	_spheres[detail] = sphere
	return sphere

static func _mid(dirs: Array[Vector3], mids: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if not mids.has(key):
		mids[key] = dirs.size()
		dirs.append(((dirs[a] + dirs[b]) * 0.5).normalized())
	return mids[key]
```

In `test_visual_style_rules.gd`, add to `PAINTING_FILES` after `"res://src/ship/airlock/airlock_show.gd",`:

```gdscript
	"res://src/world/rock_mesh.gd",
	"res://src/world/asteroid_recipe.gd",
	"res://src/world/asteroid_stream.gd",
	"res://src/world/asteroid_bubble.gd",
	"res://src/world/asteroid_body.gd",
```

(The last four arrive in Tasks 2–4; add each line in the task that creates its file, so the
suite stays green between tasks.)

- [ ] **Step 4: Import, run** — `test_rock_mesh`: 7/7; `test_visual_style_rules`: 3/3.
- [ ] **Step 5: Commit** — `feat: chunky faceted rock shapes and the space palette`.

---

### Task 2: The recipe — AsteroidRock and AsteroidRecipe

**Files:** create `asteroid_rock.gd`, `asteroid_recipe.gd`, `test/unit/test_asteroid_recipe.gd`;
add `asteroid_recipe.gd` to `PAINTING_FILES`.

**Interfaces — Consumes:** `UniversePoint.at/plus/minus` (plan 1), `RockMesh.Shape`,
`SpacePalette.ROCKS/UNTINTED`. **Produces:** `AsteroidRock` fields `tier, cell, index, local,
turn, size, shape, colour, mass, radius`, `basis() -> Basis`, `id() -> Vector4i`;
`AsteroidRecipe.new(seed: int, start: UniversePoint = null)`, `enum Tier`, constants `TIERS,
NEST, CELL, D_MIN, D_MAX, MOST, BOUND, STRETCH_MAX, START_CLEAR, GIANT_DENSITY, MASS_PER_M3`,
`density_at(u) -> float`, `cell_density(tier, cell) -> float`,
`static count_for(tier, density) -> int`, `cell_rocks(tier, cell) -> Array[AsteroidRock]`,
`static cell_corner(tier, cell) -> UniversePoint`, `static cell_of(tier, u) -> Vector3i`,
`static parent_of(from_tier, cell, tier) -> Vector3i`, `static floor_div(a, b) -> int`,
`static cell_seed(seed, tier, cell) -> int`, `static mix(x) -> int`,
`find_start() -> UniversePoint`.

- [ ] **Step 1: Write the failing tests**

**File:** `who-knows/test/unit/test_asteroid_recipe.gd`

```gdscript
extends GutTest

## The recipe (docs/superpowers/specs/2026-09-24-asteroids-design.md §5): the
## same rocks every time, never overlapping, in fields with gaps.

const SEED := 1337
const T := AsteroidRecipe.Tier

var _recipe: AsteroidRecipe

func before_each():
	_recipe = AsteroidRecipe.new(SEED)

## A cell in a field's core, so there are rocks to test.
func _dense(tier: int) -> Vector3i:
	for x in 2000:
		var c := Vector3i(x, 3, -2)
		if _recipe.cell_density(tier, c) > 0.9:
			return c
	fail_test("no dense cell found")
	return Vector3i.ZERO

func test_the_hash_is_splitmix64_and_pinned():
	assert_eq(AsteroidRecipe.mix(1), 6238072747940578789)
	assert_eq(AsteroidRecipe.mix(-5), 5185122842947594062)
	assert_eq(AsteroidRecipe.cell_seed(1337, 0, Vector3i.ZERO), 781683203928849809)
	assert_eq(AsteroidRecipe.cell_seed(1337, 2, Vector3i(-3, 7, 1)), -4929385403267878857)

func test_the_same_cell_gives_the_same_rocks():
	var c := _dense(T.MID)
	var a := AsteroidRecipe.new(SEED).cell_rocks(T.MID, c)
	var b := AsteroidRecipe.new(SEED).cell_rocks(T.MID, c)
	assert_gt(a.size(), 0)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].local, b[i].local)
		assert_eq(a[i].size, b[i].size)
		assert_eq(a[i].turn, b[i].turn)
		assert_eq(a[i].colour, b[i].colour)
		assert_eq(a[i].id(), b[i].id())

func test_another_seed_gives_other_rocks():
	var c := _dense(T.MID)
	var a := _recipe.cell_rocks(T.MID, c)
	var b := AsteroidRecipe.new(SEED + 1).cell_rocks(T.MID, c)
	assert_true(b.is_empty() or a.is_empty() or a[0].local != b[0].local)

func test_every_rock_stays_inside_its_cell():
	for tier in AsteroidRecipe.TIERS:
		var size := float(AsteroidRecipe.CELL[tier])
		for rock in _recipe.cell_rocks(tier, _dense(tier)):
			for axis in 3:
				assert_true(rock.local[axis] - rock.radius >= 0.0 and rock.local[axis] + rock.radius <= size,
					"tier %d rock %d pokes out of its cell" % [tier, rock.index])

func test_no_rocks_overlap_in_a_field_core():
	# Every rubble cell of one dense mid cell, against each other within a
	# cell, and against the mid and giant rocks around them.
	var giant := _dense(T.GIANT)
	var mid := giant * AsteroidRecipe.NEST + Vector3i(2, 2, 2)
	var overlaps := 0
	var checked := 0
	var corner := AsteroidRecipe.cell_corner(T.MID, mid)
	var big := []
	for r in _recipe.cell_rocks(T.MID, mid):
		big.append([r.local, r.radius])
	var gc := AsteroidRecipe.cell_corner(T.GIANT, giant).minus(corner)
	for r in _recipe.cell_rocks(T.GIANT, giant):
		big.append([gc + r.local, r.radius])
	for i in big.size():
		for j in range(i + 1, big.size()):
			checked += 1
			if big[i][0].distance_to(big[j][0]) < big[i][1] + big[j][1]:
				overlaps += 1
	for x in 5:
		for y in 5:
			for z in 5:
				var cell := mid * AsteroidRecipe.NEST + Vector3i(x, y, z)
				var off := AsteroidRecipe.cell_corner(T.RUBBLE, cell).minus(corner)
				var rocks := _recipe.cell_rocks(T.RUBBLE, cell)
				for i in rocks.size():
					for j in range(i + 1, rocks.size()):
						checked += 1
						if rocks[i].local.distance_to(rocks[j].local) < rocks[i].radius + rocks[j].radius:
							overlaps += 1
					for b in big:
						checked += 1
						if (off + rocks[i].local).distance_to(b[0]) < rocks[i].radius + b[1]:
							overlaps += 1
	assert_gt(checked, 1000, "a real field was checked")
	assert_eq(overlaps, 0)

func test_fields_have_gaps_and_cores():
	var empty := 0
	var full := 0
	var n := 0
	for x in 60:
		for z in 60:
			var d := _recipe.cell_density(T.MID, Vector3i(x * 3, 0, z * 3))
			n += 1
			if d <= 0.0:
				empty += 1
			elif d >= 0.99:
				full += 1
	gut.p("density over %d mid cells: %.0f%% empty, %.0f%% core" % [n, 100.0 * empty / n, 100.0 * full / n])
	assert_gt(empty, n / 10, "gaps")
	assert_gt(full, n / 50, "cores")

func test_giants_live_only_in_cores():
	for x in 200:
		var c := Vector3i(x, 0, 0)
		if not _recipe.cell_rocks(T.GIANT, c).is_empty():
			assert_gt(_recipe.cell_density(T.GIANT, c), AsteroidRecipe.GIANT_DENSITY)

func test_the_start_is_at_a_fields_edge_and_clear():
	var start := _recipe.find_start()
	var d := _recipe.density_at(start)
	assert_between(d, 0.3, 0.6)
	var r := AsteroidRecipe.new(SEED, start)
	for tier in AsteroidRecipe.TIERS:
		var home := AsteroidRecipe.cell_of(tier, start)
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					var cell := home + Vector3i(x, y, z)
					var corner := AsteroidRecipe.cell_corner(tier, cell)
					for rock in r.cell_rocks(tier, cell):
						var at := corner.plus(rock.local)
						assert_gt(at.minus(start).length(), AsteroidRecipe.START_CLEAR + rock.radius - 0.001)

func test_mass_follows_size():
	for rock in _recipe.cell_rocks(T.MID, _dense(T.MID)):
		assert_almost_eq(rock.mass, AsteroidRecipe.MASS_PER_M3 * rock.size.x * rock.size.y * rock.size.z, rock.mass * 1e-5)

func test_veined_rocks_are_never_rubble_and_carry_their_own_colour():
	var veined := 0
	for x in 40:
		for rock in _recipe.cell_rocks(T.MID, _dense(T.MID) + Vector3i(0, x, 0)):
			if rock.shape == RockMesh.Shape.VEINED:
				veined += 1
				assert_eq(rock.colour, SpacePalette.UNTINTED)
	for rock in _recipe.cell_rocks(T.RUBBLE, _dense(T.RUBBLE)):
		assert_ne(rock.shape, RockMesh.Shape.VEINED)
	assert_gt(veined, 0, "some mid-size rocks are veined")

func test_cells_nest_and_floor_toward_minus_infinity():
	assert_eq(AsteroidRecipe.floor_div(-1, 5), -1)
	assert_eq(AsteroidRecipe.floor_div(-5, 5), -1)
	assert_eq(AsteroidRecipe.floor_div(-6, 5), -2)
	assert_eq(AsteroidRecipe.parent_of(T.RUBBLE, Vector3i(-1, 24, 25), T.GIANT), Vector3i(-1, 0, 1))
	assert_eq(AsteroidRecipe.cell_of(T.MID, UniversePoint.at(-1, 999, 1000)), Vector3i(-1, 0, 1))
```

- [ ] **Step 2: Run to verify failure** — parse errors: `AsteroidRecipe` not declared.

- [ ] **Step 3: Implement**

**File:** `who-knows/src/world/asteroid_rock.gd`

```gdscript
class_name AsteroidRock
extends RefCounted

## One rock, as data (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §5.3): where it sits in its cell, how it is turned and sized, what it looks
## like and weighs. No node: recipes make these on worker threads.

var tier: int
var cell: Vector3i
## Which candidate it was in its cell: with tier and cell, who it is.
var index: int
## From its cell's lowest corner, metres.
var local: Vector3
var turn: Basis
## Its extent on each axis: diameter times stretch.
var size: Vector3
var shape: int
var colour: Color
var mass: float
## The sphere about its centre it never pokes out of.
var radius: float

## Rotation and size together.
func basis() -> Basis:
	return turn * Basis.from_scale(size)

## Who it is, across loads: its cell, with tier and index packed together.
func id() -> Vector4i:
	return Vector4i(cell.x, cell.y, cell.z, tier * 1000 + index)
```

**File:** `who-knows/src/world/asteroid_recipe.gd`

```gdscript
class_name AsteroidRecipe
extends RefCounted

## What rocks are where (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §5): a pure function from (seed, tier, cell) to that cell's rocks, the same
## every time, on any thread. Touches no nodes. Each instance has its own
## noise and cache, so give each worker its own.
##
## Cells nest: each tier's cell is NEST times the one below, so a cell lies in
## exactly one cell of every larger tier. A rock stays inside its own cell and
## clear of the rocks of the larger cells around it, so no two rocks ever
## overlap -- which matters, because overlapping bodies fly apart.

enum Tier { RUBBLE, MID, GIANT }

const TIERS := 3
const NEST := 5
## Cell edge per tier, metres.
const CELL: Array[int] = [200, 1000, 5000]
const D_MIN: Array[float] = [1.0, 5.0, 40.0]
const D_MAX: Array[float] = [5.0, 40.0, 300.0]
const MOST: Array[int] = [24, 12, 3]
## Giants live only where density is over this: the cores of fields.
const GIANT_DENSITY := 0.7
const STRETCH_MIN := 0.75
const STRETCH_MAX := 1.25
## Bounding radius per metre of diameter per unit of stretch: over
## RockMesh.REACH, so it covers every shape.
const BOUND := 0.7
const VEINED_CHANCE := 0.1
## Kilograms per cubic metre of diameter: rock at about 2,000 kg/m3 in a rough
## sphere, less voids.
const MASS_PER_M3 := 840.0
## Nothing within this of the start, in any tier.
const START_CLEAR := 150.0
## Density noise, in universe kilometres: fields about 15 km across.
const NOISE_FREQUENCY := 0.05
## Density is the noise shaped: nothing below LOW, a full core above HIGH.
const DENSITY_LOW := 0.35
const DENSITY_HIGH := 0.75
## splitmix64's constants, as signed 64-bit ints.
const _GOLDEN := -7046029254386353131
const _MIX_1 := -4658895280553007687
const _MIX_2 := -7723592293110705685

var world_seed: int
## The centre of the clear bubble at the start, or null for none.
var start: UniversePoint

var _noise: FastNoiseLite
var _cache := {}

func _init(p_seed: int, p_start: UniversePoint = null) -> void:
	world_seed = p_seed
	start = p_start
	_noise = FastNoiseLite.new()
	_noise.seed = p_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = NOISE_FREQUENCY
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3

## How full of rock space is at `u`: 0, empty, to 1, a field's core. The one
## place density is decided -- the hook for keeping fields off worlds later.
func density_at(u: UniversePoint) -> float:
	var n := _noise.get_noise_3d((u.x + u.fx) / 1000.0, (u.y + u.fy) / 1000.0, (u.z + u.fz) / 1000.0)
	return smoothstep(DENSITY_LOW, DENSITY_HIGH, (n + 1.0) * 0.5)

## The density at a cell's centre.
func cell_density(tier: int, cell: Vector3i) -> float:
	var size := CELL[tier]
	var half := size / 2
	return density_at(UniversePoint.at(cell.x * size + half, cell.y * size + half, cell.z * size + half))

## How many rocks a cell tries to place at `density`.
static func count_for(tier: int, density: float) -> int:
	if tier == Tier.GIANT:
		if density <= GIANT_DENSITY:
			return 0
		return roundi((density - GIANT_DENSITY) / (1.0 - GIANT_DENSITY) * MOST[tier])
	return roundi(density * MOST[tier])

## The cell's rocks, in candidate order. Cached.
func cell_rocks(tier: int, cell: Vector3i) -> Array[AsteroidRock]:
	var key := Vector4i(cell.x, cell.y, cell.z, tier)
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 4096:
		_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = cell_seed(world_seed, tier, cell)
	var size := float(CELL[tier])
	var margin := BOUND * D_MAX[tier] * STRETCH_MAX
	var blockers := _blockers(tier, cell)
	var rocks: Array[AsteroidRock] = []
	for i in count_for(tier, cell_density(tier, cell)):
		# Every candidate takes the same draws, placed or not, so one rejection
		# never reshuffles the rest.
		var local := Vector3(rng.randf_range(margin, size - margin), rng.randf_range(margin, size - margin),
			rng.randf_range(margin, size - margin))
		var u := rng.randf()
		var diameter := D_MIN[tier] * pow(D_MAX[tier] / D_MIN[tier], u * u)
		var stretch := Vector3(rng.randf_range(STRETCH_MIN, STRETCH_MAX), rng.randf_range(STRETCH_MIN, STRETCH_MAX),
			rng.randf_range(STRETCH_MIN, STRETCH_MAX))
		var turn := Basis.from_euler(Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI),
			rng.randf_range(-PI, PI)))
		var shape_roll := rng.randf()
		var colour_roll := rng.randi_range(0, SpacePalette.ROCKS.size() - 1)
		var radius := BOUND * diameter * maxf(stretch.x, maxf(stretch.y, stretch.z))
		if _touches(local, radius, rocks, blockers):
			continue
		var rock := AsteroidRock.new()
		rock.tier = tier
		rock.cell = cell
		rock.index = i
		rock.local = local
		rock.turn = turn
		rock.size = stretch * diameter
		rock.radius = radius
		rock.mass = MASS_PER_M3 * rock.size.x * rock.size.y * rock.size.z
		if tier != Tier.RUBBLE and shape_roll < VEINED_CHANCE:
			rock.shape = RockMesh.Shape.VEINED
			rock.colour = SpacePalette.UNTINTED
		else:
			rock.shape = RockMesh.Shape.BOULDER if shape_roll < 0.55 else RockMesh.Shape.SHARD
			rock.colour = SpacePalette.ROCKS[colour_roll]
		rocks.append(rock)
	_cache[key] = rocks
	return rocks

## The universe point at a cell's lowest corner.
static func cell_corner(tier: int, cell: Vector3i) -> UniversePoint:
	var size := CELL[tier]
	return UniversePoint.at(cell.x * size, cell.y * size, cell.z * size)

## The cell of `tier` that holds `u`.
static func cell_of(tier: int, u: UniversePoint) -> Vector3i:
	var size := CELL[tier]
	return Vector3i(floor_div(u.x, size), floor_div(u.y, size), floor_div(u.z, size))

## The cell of the larger `tier` that holds `cell` of `from_tier`.
static func parent_of(from_tier: int, cell: Vector3i, tier: int) -> Vector3i:
	var k := 1
	for i in tier - from_tier:
		k *= NEST
	return Vector3i(floor_div(cell.x, k), floor_div(cell.y, k), floor_div(cell.z, k))

## Integer division rounding toward minus infinity.
static func floor_div(a: int, b: int) -> int:
	var q := a / b
	if a % b != 0 and (a < 0) != (b < 0):
		q -= 1
	return q

## What a new rock here must stay clear of: the rocks of the larger cells
## around it, and the start. Each is [centre from this cell's corner, radius].
func _blockers(tier: int, cell: Vector3i) -> Array:
	var out := []
	var corner := cell_corner(tier, cell)
	for t in range(tier + 1, TIERS):
		var parent := parent_of(tier, cell, t)
		var offset := cell_corner(t, parent).minus(corner)
		for rock in cell_rocks(t, parent):
			out.append([offset + rock.local, rock.radius])
	if start != null:
		out.append([start.minus(corner), START_CLEAR])
	return out

static func _touches(local: Vector3, radius: float, rocks: Array[AsteroidRock], blockers: Array) -> bool:
	for rock in rocks:
		if local.distance_to(rock.local) < radius + rock.radius:
			return true
	for b in blockers:
		if local.distance_to(b[0]) < radius + b[1]:
			return true
	return false

## A cell's generator seed: splitmix64 over (seed, tier, x, y, z). Written out
## rather than the engine's hash(), which is not promised to stay the same
## between engine versions.
static func cell_seed(p_seed: int, tier: int, cell: Vector3i) -> int:
	var h := mix(p_seed)
	for v in [tier, cell.x, cell.y, cell.z]:
		h = mix(h ^ mix(v + _GOLDEN))
	return h

## splitmix64's finalizer on 64-bit ints: wrapping multiplies, and logical
## shifts made from arithmetic ones by masking.
static func mix(x: int) -> int:
	x ^= (x >> 30) & 0x3FFFFFFFF
	x *= _MIX_1
	x ^= (x >> 27) & 0x1FFFFFFFFF
	x *= _MIX_2
	x ^= (x >> 31) & 0x1FFFFFFFF
	return x

## Where a flight starts (§5.6): the first whole kilometre along +z from the
## universe's origin that sits at a field's edge.
func find_start() -> UniversePoint:
	for k in 4000:
		var u := UniversePoint.at(0, 0, k * 1000)
		var d := density_at(u)
		if d >= 0.3 and d <= 0.6:
			return u
	push_warning("AsteroidRecipe: no field edge found; starting at the universe's origin")
	return UniversePoint.at(0, 0, 0)
```

- [ ] **Step 4: Import, run** — `test_asteroid_recipe` all pass; note the printed density
  proportions for Task 6.
- [ ] **Step 5: Commit** — `feat: the asteroid recipe -- seeded cells, fields with gaps, no overlaps`.

---

### Task 3: Streaming and pictures

**Files:** create `asteroid_stream.gd`, `asteroid_bubble.gd` (the bubble's full code arrives in
Task 4; this task creates it with `step`, `cell_unloaded` and `clear` doing nothing but their
final signatures), `test/unit/test_asteroid_stream.gd`; add `asteroid_stream.gd` to
`PAINTING_FILES`.

**Interfaces — Consumes:** Tasks 1–2; `Universe` (plan 1). **Produces:**
`AsteroidStream.SPACE_ANCHOR`, `ANCHOR_RADIUS`, `FADE_START`, `FADE_END`, `LOAD`, `UNLOAD`,
`TOP_SPEED`, `DETAIL`; `@export var seed`; `var universe`, `var recipe`, `var bubble`,
`var late_cells`; `start(u: Universe, start_point: UniversePoint = null)`,
`update(delta: float, all_now := false)`, `finish_jobs()`, `is_loaded(tier, cell) -> bool`,
`loaded_rocks(tier, cell) -> Array[AsteroidRock]`, `loaded_count(tier) -> int`,
`rocks_in(tier, box: AABB) -> Array[AsteroidRock]`, `rock_pose(rock) -> Transform3D`,
`picture_transform(rock) -> Transform3D`, `hide_rock(rock)`, `show_rock(rock)`,
`is_hidden(rock) -> bool`, `rock_material(tier, colour) -> StandardMaterial3D`,
`static pack(buf, t, c) -> PackedFloat32Array`, `static block_of(cell) -> Vector3i`,
`static offset_in_block(tier, cell) -> Vector3`, `static velocity_of(node) -> Vector3`,
`static box_distance(p: Vector3, size: float) -> float`.

- [ ] **Step 1: Write the failing tests**

**File:** `who-knows/test/unit/test_asteroid_stream.gd`

```gdscript
extends GutTest

## Streaming and pictures (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §6), headless: a Universe, a focus, and the stream around it.

const T := AsteroidRecipe.Tier

var _world: Node3D
var _universe: Universe
var _focus: Node3D
var _stream: AsteroidStream
var _start: UniversePoint

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_universe = Universe.new()
	_world.add_child(_universe)
	_focus = Node3D.new()
	_world.add_child(_focus)
	_focus.add_to_group(Universe.EXTERIOR_SPACE)
	_universe.set_focus(_focus)
	_stream = AsteroidStream.new()
	_world.add_child(_stream)
	_start = AsteroidRecipe.new(_stream.seed).find_start()
	_universe.origin = _start
	_stream.start(_universe, _start)

func _focus_cell(tier: int) -> Vector3i:
	return AsteroidRecipe.cell_of(tier, _universe.to_universe(_focus.global_position))

func _any_rock(tier: int) -> AsteroidRock:
	for x in range(-2, 3):
		for y in range(-2, 3):
			for z in range(-2, 3):
				var rocks := _stream.loaded_rocks(tier, _focus_cell(tier) + Vector3i(x, y, z))
				if not rocks.is_empty():
					return rocks[0]
	return null

func test_every_tier_loads_at_least_a_second_ahead_of_boost():
	for tier in AsteroidRecipe.TIERS:
		assert_gte(AsteroidStream.LOAD[tier] - AsteroidStream.FADE_END[tier], AsteroidStream.TOP_SPEED * 1.0)
		assert_gt(AsteroidStream.UNLOAD[tier], AsteroidStream.LOAD[tier])
		assert_gt(AsteroidStream.FADE_END[tier], AsteroidStream.FADE_START[tier])

func test_the_first_load_is_done_before_it_returns():
	for tier in AsteroidRecipe.TIERS:
		assert_true(_stream.is_loaded(tier, _focus_cell(tier)), "tier %d around you" % tier)
		assert_gt(_stream.loaded_count(tier), 0)
	assert_eq(_stream.late_cells, 0)

func test_a_picture_is_drawn_exactly_where_its_rock_is():
	var rock := _any_rock(T.RUBBLE)
	assert_not_null(rock)
	var want := Transform3D(rock.basis(), _stream.rock_pose(rock).origin)
	var got := _stream.picture_transform(rock)
	assert_almost_eq(got.origin, want.origin, Vector3.ONE * 0.001)
	assert_true(got.basis.is_equal_approx(want.basis))

func test_packing_matches_the_multimeshs_own_layout():
	var t := Transform3D(Basis.from_euler(Vector3(0.3, -1.2, 2.0)).scaled(Vector3(2, 3, 4)), Vector3(10, -20, 30))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 1
	mm.buffer = AsteroidStream.pack(PackedFloat32Array(), t, SpacePalette.RUST)
	assert_true(mm.get_instance_transform(0).is_equal_approx(t))
	assert_eq(mm.get_instance_color(0), SpacePalette.RUST)

func test_hiding_and_showing_a_rock():
	var rock := _any_rock(T.RUBBLE)
	_stream.hide_rock(rock)
	assert_true(_stream.is_hidden(rock))
	assert_eq(_stream.picture_transform(rock).basis, Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO))
	_stream.show_rock(rock)
	assert_false(_stream.is_hidden(rock))
	assert_almost_eq(_stream.picture_transform(rock).origin, _stream.rock_pose(rock).origin, Vector3.ONE * 0.001)

func test_cells_unload_past_unload_and_stay_between():
	var tier := T.RUBBLE
	var home := _focus_cell(tier)
	# Move so home (the 200 m cell whose corner is the start) is between LOAD
	# and UNLOAD away: it stays loaded.
	_focus.global_position += Vector3(AsteroidStream.LOAD[tier] + 300.0, 0, 0)
	_stream.update(0.0, true)
	assert_true(_stream.is_loaded(tier, home), "hysteresis: no flicker at the edge")
	_focus.global_position += Vector3(AsteroidStream.UNLOAD[tier] + 400.0, 0, 0)
	_stream.update(0.0, true)
	assert_false(_stream.is_loaded(tier, home))

func test_a_result_no_longer_wanted_is_dropped():
	var far := Vector3(0, 0, 50000)
	_focus.global_position = far
	_stream.update(0.0)
	_focus.global_position = Vector3.ZERO
	_stream.update(0.0, true)
	var cell := AsteroidRecipe.cell_of(T.RUBBLE, _universe.to_universe(far))
	assert_false(_stream.is_loaded(T.RUBBLE, cell), "out of date by the time it finished")

func test_everything_drawn_moves_with_the_origin():
	for block in _stream.find_children("Block_*", "Node3D", true, false):
		assert_true(block.is_in_group(Universe.EXTERIOR_SPACE))
	assert_false(_stream.is_in_group(Universe.EXTERIOR_SPACE), "the stream itself never moves")

func test_a_shift_keeps_pictures_on_their_rocks():
	var rock := _any_rock(T.MID)
	_focus.global_position = Vector3(2600, 0, 0)
	_universe.check()
	_stream.update(0.0, true)
	assert_almost_eq(_stream.picture_transform(rock).origin, _stream.rock_pose(rock).origin, Vector3.ONE * 0.002)

func test_pictures_fade_by_tier_and_only_giants_cast_shadows():
	var m := _stream.rock_material(T.MID, SpacePalette.UNTINTED)
	assert_eq(m.distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER)
	assert_eq(m.distance_fade_min_distance, AsteroidStream.FADE_END[T.MID])
	assert_eq(m.distance_fade_max_distance, AsteroidStream.FADE_START[T.MID])
	for inst in _stream.find_children("*", "MultiMeshInstance3D", true, false):
		var giant := String(inst.get_parent().name).begins_with("Block_2_")
		assert_eq(inst.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, giant)
		assert_eq(inst.layers, 1)
```

- [ ] **Step 2: Run to verify failure** — parse errors: `AsteroidStream` not declared.

- [ ] **Step 3: Implement**

**File:** `who-knows/src/world/asteroid_stream.gd`

```gdscript
class_name AsteroidStream
extends Node3D

## Keeps the rocks around you loaded, drawn and touchable
## (docs/superpowers/specs/2026-09-24-asteroids-design.md §6, §7). Cells load
## well beyond where their rocks fade in, on worker threads; loaded rocks are
## drawn as batched pictures, a block of cells at a time; the few near the path
## of the hull or a spacewalker become sleeping bodies (AsteroidBubble).
##
## This node and its two holders never move. Every block and body under them
## is a member of Universe.EXTERIOR_SPACE, moved by the shift itself.

## Bodies that touch rocks: the hull, and you on a spacewalk.
const SPACE_ANCHOR := &"space_anchor"
## Meta on an anchor: how far it reaches from its origin, metres.
const ANCHOR_RADIUS := &"anchor_radius"

## Per tier: whole within FADE_START, gone beyond FADE_END; loaded within
## LOAD, unloaded beyond UNLOAD.
const FADE_START: Array[float] = [450.0, 3000.0, 15000.0]
const FADE_END: Array[float] = [600.0, 4000.0, 20000.0]
const LOAD: Array[float] = [900.0, 5000.0, 25000.0]
const UNLOAD: Array[float] = [1100.0, 5500.0, 30000.0]
## Boost: every tier loads at least a second ahead of it.
const TOP_SPEED := 300.0
## Icosphere subdivisions per tier.
const DETAIL: Array[int] = [0, 1, 2]
const APPLY_BUDGET_USEC := 2000
const MAX_JOBS := 48
const _NO_SLOT := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

@export var seed: int = 1337

var universe: Universe
var recipe: AsteroidRecipe
var bubble: AsteroidBubble
## Cells finished after their rocks could already have been seen. Stays 0.
var late_cells := 0

var _pictures: Node3D
var _started := false
var _start_point: UniversePoint
var _cells: Array[Dictionary] = [{}, {}, {}]
var _wanted: Array[Dictionary] = [{}, {}, {}]
var _blocks: Array[Dictionary] = [{}, {}, {}]
var _block_cells: Array[Dictionary] = [{}, {}, {}]
var _dirty: Array[Dictionary] = [{}, {}, {}]
var _queue: Array = []
var _queued := {}
var _jobs := {}
var _focus_cell: Array = [null, null, null]
var _materials := {}

class _Cell:
	var rocks: Array[AsteroidRock]
	## Per shape: instance data relative to the block's corner, and the ids in
	## the same order.
	var packed: Array[PackedFloat32Array]
	var ids: Array
	## Rocks whose picture is hidden: a body stands in for it, or took it away.
	var hidden := {}

class _Block:
	var node: Node3D
	var instances: Array[MultiMeshInstance3D] = [null, null, null]
	## id -> Vector2i(shape, slot)
	var slots := {}

class _Job:
	var tier: int
	var cell: Vector3i
	var world_seed: int
	var start: UniversePoint
	var task := -1
	var done := false
	var rocks: Array[AsteroidRock]
	var packed: Array[PackedFloat32Array]
	var ids: Array

	## On a worker thread: the cell's rocks, packed for its block.
	func run() -> void:
		rocks = AsteroidRecipe.new(world_seed, start).cell_rocks(tier, cell)
		var offset := AsteroidStream.offset_in_block(tier, cell)
		var p0 := PackedFloat32Array()
		var p1 := PackedFloat32Array()
		var p2 := PackedFloat32Array()
		var i0: Array[Vector4i] = []
		var i1: Array[Vector4i] = []
		var i2: Array[Vector4i] = []
		for rock in rocks:
			var t := Transform3D(rock.basis(), offset + rock.local)
			match rock.shape:
				RockMesh.Shape.BOULDER:
					p0 = AsteroidStream.pack(p0, t, rock.colour)
					i0.append(rock.id())
				RockMesh.Shape.SHARD:
					p1 = AsteroidStream.pack(p1, t, rock.colour)
					i1.append(rock.id())
				_:
					p2 = AsteroidStream.pack(p2, t, rock.colour)
					i2.append(rock.id())
		packed = [p0, p1, p2]
		ids = [i0, i1, i2]

func _ready() -> void:
	_pictures = Node3D.new()
	_pictures.name = "Pictures"
	add_child(_pictures)
	var bodies := Node3D.new()
	bodies.name = "Bodies"
	add_child(bodies)
	bubble = AsteroidBubble.new(self, bodies)

## Starts streaming around `u`'s focus, keeping `start_point`'s bubble clear
## (or none). Everything wanted now is loaded and drawn before this returns.
func start(u: Universe, start_point: UniversePoint = null) -> void:
	universe = u
	_start_point = start_point
	recipe = AsteroidRecipe.new(seed, start_point)
	_started = true
	update(0.0, true)

func _exit_tree() -> void:
	finish_jobs()
	if bubble != null:
		bubble.clear()

func _process(delta: float) -> void:
	if _started:
		update(delta)

func _physics_process(delta: float) -> void:
	if _started:
		bubble.step(delta)

## One streaming step: what is wanted, what finished, what to redraw.
## `all_now` does all of it at once and waits (the first load, and tests).
func update(_delta: float, all_now := false) -> void:
	var focus := _focus_point()
	if focus == null:
		return
	for tier in AsteroidRecipe.TIERS:
		var fc := AsteroidRecipe.cell_of(tier, focus)
		if all_now or _focus_cell[tier] == null or _focus_cell[tier] != fc:
			_focus_cell[tier] = fc
			_rewant(tier, focus)
	_submit(all_now)
	if all_now:
		finish_jobs()
	_collect(focus, all_now)
	_rebuild_dirty(focus, all_now)

## Waits for every job in flight.
func finish_jobs() -> void:
	for job: _Job in _jobs.values():
		if not job.done:
			WorkerThreadPool.wait_for_task_completion(job.task)
			job.done = true

func is_loaded(tier: int, cell: Vector3i) -> bool:
	return _cells[tier].has(cell)

func loaded_rocks(tier: int, cell: Vector3i) -> Array[AsteroidRock]:
	var c: _Cell = _cells[tier].get(cell)
	return c.rocks if c != null else [] as Array[AsteroidRock]

func loaded_count(tier: int) -> int:
	return _cells[tier].size()

## The loaded rocks of `tier` in cells overlapping an engine-space box.
func rocks_in(tier: int, box: AABB) -> Array[AsteroidRock]:
	var lo := AsteroidRecipe.cell_of(tier, universe.to_universe(box.position))
	var hi := AsteroidRecipe.cell_of(tier, universe.to_universe(box.end))
	var out: Array[AsteroidRock] = []
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var c: _Cell = _cells[tier].get(Vector3i(x, y, z))
				if c != null:
					out.append_array(c.rocks)
	return out

## Where a rock sits, in engine space: rotation and position, no scale.
func rock_pose(rock: AsteroidRock) -> Transform3D:
	return Transform3D(rock.turn, universe.to_engine(AsteroidRecipe.cell_corner(rock.tier, rock.cell)) + rock.local)

## Where its picture is drawn, in engine space, scale included.
func picture_transform(rock: AsteroidRock) -> Transform3D:
	var block: _Block = _blocks[rock.tier].get(block_of(rock.cell))
	if block == null or not block.slots.has(rock.id()):
		return _NO_SLOT
	var slot: Vector2i = block.slots[rock.id()]
	var inst := block.instances[slot.x]
	return inst.global_transform * inst.multimesh.get_instance_transform(slot.y)

## Hides a rock's picture: a body stands in for it.
func hide_rock(rock: AsteroidRock) -> void:
	var c: _Cell = _cells[rock.tier].get(rock.cell)
	if c != null:
		c.hidden[rock.id()] = true
	_set_slot(rock.tier, rock.id(), _NO_SLOT)

## Shows a rock's picture again, just where it was.
func show_rock(rock: AsteroidRock) -> void:
	var c: _Cell = _cells[rock.tier].get(rock.cell)
	if c == null:
		return
	c.hidden.erase(rock.id())
	_set_slot(rock.tier, rock.id(), Transform3D(rock.basis(), offset_in_block(rock.tier, rock.cell) + rock.local))

func is_hidden(rock: AsteroidRock) -> bool:
	var c: _Cell = _cells[rock.tier].get(rock.cell)
	return c != null and c.hidden.has(rock.id())

## A rock material: vertex colour times `colour` (white for the pictures,
## whose instance colour tints them), fading out by the tier's distances.
func rock_material(tier: int, colour: Color) -> StandardMaterial3D:
	var key := "%d:%s" % [tier, colour.to_html()]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = colour
		m.roughness = 1.0
		# Reversed (min beyond max): whole within FADE_START, gone past FADE_END.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = FADE_END[tier]
		m.distance_fade_max_distance = FADE_START[tier]
		_materials[key] = m
	return _materials[key]

## Appends one instance to a MultiMesh buffer: the transform's rows, then the
## colour.
static func pack(buf: PackedFloat32Array, t: Transform3D, c: Color) -> PackedFloat32Array:
	buf.append_array(PackedFloat32Array([
		t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x,
		t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y,
		t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z,
		c.r, c.g, c.b, c.a]))
	return buf

## The block (the next tier's cell) a cell is drawn in.
static func block_of(cell: Vector3i) -> Vector3i:
	return Vector3i(AsteroidRecipe.floor_div(cell.x, AsteroidRecipe.NEST),
		AsteroidRecipe.floor_div(cell.y, AsteroidRecipe.NEST), AsteroidRecipe.floor_div(cell.z, AsteroidRecipe.NEST))

## A cell's corner from its block's corner, metres.
static func offset_in_block(tier: int, cell: Vector3i) -> Vector3:
	return Vector3(cell - block_of(cell) * AsteroidRecipe.NEST) * AsteroidRecipe.CELL[tier]

static func velocity_of(node: Node) -> Vector3:
	if node is RigidBody3D:
		return (node as RigidBody3D).linear_velocity
	if node is CharacterBody3D:
		return (node as CharacterBody3D).velocity
	return Vector3.ZERO

## How far `p` (from a box's lowest corner) is from the box [0, size]^3.
static func box_distance(p: Vector3, size: float) -> float:
	return Vector3(maxf(0.0, maxf(-p.x, p.x - size)), maxf(0.0, maxf(-p.y, p.y - size)),
		maxf(0.0, maxf(-p.z, p.z - size))).length()

func _focus_point() -> UniversePoint:
	if universe == null or not is_instance_valid(universe.focus):
		return null
	return universe.to_universe(universe.focus.global_position)

func _key(tier: int, cell: Vector3i) -> Vector4i:
	return Vector4i(cell.x, cell.y, cell.z, tier)

func _rewant(tier: int, focus: UniversePoint) -> void:
	var size := float(AsteroidRecipe.CELL[tier])
	var fc: Vector3i = _focus_cell[tier]
	var inside := focus.minus(AsteroidRecipe.cell_corner(tier, fc))
	var n := ceili(LOAD[tier] / size)
	var wanted := {}
	for x in range(-n, n + 1):
		for y in range(-n, n + 1):
			for z in range(-n, n + 1):
				var d := Vector3i(x, y, z)
				if box_distance(inside - Vector3(d) * size, size) <= LOAD[tier]:
					wanted[fc + d] = true
	_wanted[tier] = wanted
	for c: Vector3i in _cells[tier].keys():
		if not wanted.has(c) and box_distance(inside - Vector3(c - fc) * size, size) > UNLOAD[tier]:
			_unload(tier, c)
	var velocity := velocity_of(universe.focus)
	var ahead := velocity.normalized() if velocity.length() > 1.0 else Vector3.ZERO
	_queue = _queue.filter(func(q: Array) -> bool:
		var keep: bool = q[1] != tier or wanted.has(q[2])
		if not keep:
			_queued.erase(_key(q[1], q[2]))
		return keep)
	for c: Vector3i in wanted:
		var key := _key(tier, c)
		if _cells[tier].has(c) or _jobs.has(key) or _queued.has(key):
			continue
		var centre := Vector3(c - fc) * size + Vector3.ONE * size * 0.5 - inside
		_queue.append([centre.length() - 0.5 * maxf(0.0, centre.dot(ahead)), tier, c])
		_queued[key] = true
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

func _submit(all_now: bool) -> void:
	while not _queue.is_empty() and (all_now or _jobs.size() < MAX_JOBS):
		var q: Array = _queue.pop_front()
		var key := _key(q[1], q[2])
		_queued.erase(key)
		var job := _Job.new()
		job.tier = q[1]
		job.cell = q[2]
		job.world_seed = seed
		job.start = _start_point
		job.task = WorkerThreadPool.add_task(job.run)
		_jobs[key] = job

func _collect(focus: UniversePoint, all_now: bool) -> void:
	for key: Vector4i in _jobs.keys():
		var job: _Job = _jobs[key]
		if not job.done:
			if not WorkerThreadPool.is_task_completed(job.task):
				continue
			WorkerThreadPool.wait_for_task_completion(job.task)
			job.done = true
		_jobs.erase(key)
		if not _wanted[job.tier].has(job.cell):
			continue
		var cell := _Cell.new()
		cell.rocks = job.rocks
		cell.packed = job.packed
		cell.ids = job.ids
		_cells[job.tier][job.cell] = cell
		var b := block_of(job.cell)
		if not _block_cells[job.tier].has(b):
			_block_cells[job.tier][b] = {}
		_block_cells[job.tier][b][job.cell] = true
		_dirty[job.tier][b] = true
		if not all_now and not cell.rocks.is_empty():
			var size := float(AsteroidRecipe.CELL[job.tier])
			if box_distance(focus.minus(AsteroidRecipe.cell_corner(job.tier, job.cell)), size) < FADE_END[job.tier]:
				late_cells += 1

func _unload(tier: int, c: Vector3i) -> void:
	_cells[tier].erase(c)
	var b := block_of(c)
	if _block_cells[tier].has(b):
		_block_cells[tier][b].erase(c)
	_dirty[tier][b] = true
	bubble.cell_unloaded(tier, c)

func _rebuild_dirty(focus: UniversePoint, all_now: bool) -> void:
	var order := []
	for tier in AsteroidRecipe.TIERS:
		var size := float(AsteroidRecipe.CELL[tier] * AsteroidRecipe.NEST)
		for b: Vector3i in _dirty[tier]:
			var corner := UniversePoint.at(b.x * int(size), b.y * int(size), b.z * int(size))
			order.append([box_distance(focus.minus(corner), size), tier, b])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var began := Time.get_ticks_usec()
	for o in order:
		if not all_now and Time.get_ticks_usec() - began > APPLY_BUDGET_USEC:
			return
		_dirty[o[1]].erase(o[2])
		_rebuild(o[1], o[2])

func _rebuild(tier: int, b: Vector3i) -> void:
	var cells: Dictionary = _block_cells[tier].get(b, {})
	var block: _Block = _blocks[tier].get(b)
	var buffers: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	var counts := [0, 0, 0]
	var slots := {}
	for c: Vector3i in cells:
		var cell: _Cell = _cells[tier][c]
		for s in 3:
			var ids: Array = cell.ids[s]
			for k in ids.size():
				slots[ids[k]] = Vector2i(s, counts[s] + k)
			var buf := buffers[s]
			buf.append_array(cell.packed[s])
			buffers[s] = buf
			counts[s] += ids.size()
	if counts[0] + counts[1] + counts[2] == 0:
		if block != null:
			block.node.free()
			_blocks[tier].erase(b)
		if cells.is_empty():
			_block_cells[tier].erase(b)
		return
	if block == null:
		block = _Block.new()
		block.node = Node3D.new()
		block.node.name = "Block_%d_%d_%d_%d" % [tier, b.x, b.y, b.z]
		_pictures.add_child(block.node)
		var edge := AsteroidRecipe.CELL[tier] * AsteroidRecipe.NEST
		block.node.global_position = universe.to_engine(UniversePoint.at(b.x * edge, b.y * edge, b.z * edge))
		block.node.add_to_group(Universe.EXTERIOR_SPACE)
		_blocks[tier][b] = block
	for s in 3:
		var inst := block.instances[s]
		if counts[s] == 0:
			if inst != null:
				inst.free()
				block.instances[s] = null
			continue
		if inst == null:
			inst = MultiMeshInstance3D.new()
			inst.layers = 1
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tier == AsteroidRecipe.Tier.GIANT \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			inst.material_override = rock_material(tier, SpacePalette.UNTINTED)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = RockMesh.mesh(s, DETAIL[tier])
			inst.multimesh = mm
			block.node.add_child(inst)
			block.instances[s] = inst
		inst.multimesh.instance_count = counts[s]
		inst.multimesh.buffer = buffers[s]
	block.slots = slots
	for c: Vector3i in cells:
		for id: Vector4i in (_cells[tier][c] as _Cell).hidden:
			_set_slot(tier, id, _NO_SLOT)

func _set_slot(tier: int, id: Vector4i, t: Transform3D) -> void:
	var block: _Block = _blocks[tier].get(block_of(Vector3i(id.x, id.y, id.z)))
	if block == null or not block.slots.has(id):
		return
	var slot: Vector2i = block.slots[id]
	block.instances[slot.x].multimesh.set_instance_transform(slot.y, t)
```

**`asteroid_bubble.gd`:** the stream needs `AsteroidBubble` to parse, so create it now from
Task 4's **File:** block (and `asteroid_body.gd` with it, which the bubble names). This task's
tests never promote a rock: no node in them is in `SPACE_ANCHOR`.

- [ ] **Step 4: Import, run** — `test_asteroid_stream` all pass. Time the file: if the start
  takes more than 1 s headless, note it for Task 6.
- [ ] **Step 5: Commit** — `feat: stream asteroid cells on worker threads and draw them in blocks`.

---

### Task 4: The physics bubble — AsteroidBody and AsteroidBubble

**Files:** create `asteroid_body.gd`, finish `asteroid_bubble.gd`,
`test/unit/test_asteroid_bubble.gd`; add both to `PAINTING_FILES`; modify `project.godot`
(layer 7 name), `ship.gd` (hull mask, CCD, anchor, anchor radius), `avatar.gd` (suit mask,
anchor).

**Interfaces — Produces:** `AsteroidBody.LAYER := 64`, `MASK := 101`, `MASS_CAP`, `rock`,
`adrift`, `outside_for`, `setup(rock, mesh, material, points)`, `moved_from(home) -> bool`;
`AsteroidBubble` `PAD, LOOKAHEAD, LET_GO_AFTER, MAX_ADRIFT`, `max_adrift`, `live`,
`step(delta)`, `cell_unloaded(tier, cell)`, `clear()`, `static segment_distance(p, a, b)`.

- [ ] **Step 1: Write the failing tests**

**File:** `who-knows/test/unit/test_asteroid_bubble.gd`

```gdscript
extends GutTest

## The physics bubble (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §7), headless: rocks near an anchor's path become sleeping bodies and go
## back to being pictures when it has passed.

const T := AsteroidRecipe.Tier
const DT := 1.0 / 60.0

var _world: Node3D
var _universe: Universe
var _anchor: RigidBody3D
var _stream: AsteroidStream

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_universe = Universe.new()
	_world.add_child(_universe)
	_anchor = RigidBody3D.new()
	_anchor.gravity_scale = 0.0
	_anchor.collision_layer = 0
	_anchor.collision_mask = 0
	_world.add_child(_anchor)
	_anchor.add_to_group(Universe.EXTERIOR_SPACE)
	_anchor.set_meta(AsteroidStream.ANCHOR_RADIUS, 5.0)
	_universe.set_focus(_anchor)
	_stream = AsteroidStream.new()
	_world.add_child(_stream)
	var start := AsteroidRecipe.new(_stream.seed).find_start()
	_universe.origin = start
	_stream.start(_universe, start)

## A loaded rubble rock, and the anchor put `gap` metres from its surface.
func _beside_a_rock(gap: float) -> AsteroidRock:
	var fc := AsteroidRecipe.cell_of(T.RUBBLE, _universe.to_universe(Vector3.ZERO))
	for x in range(-3, 4):
		for z in range(-3, 4):
			var rocks := _stream.loaded_rocks(T.RUBBLE, fc + Vector3i(x, 0, z))
			if not rocks.is_empty():
				var rock := rocks[0]
				_anchor.global_position = _stream.rock_pose(rock).origin + Vector3(rock.radius + 5.0 + gap, 0, 0)
				_anchor.linear_velocity = Vector3.ZERO
				return rock
	fail_test("no rubble near the start")
	return null

func _arm() -> void:
	_anchor.add_to_group(AsteroidStream.SPACE_ANCHOR)

func test_a_rock_within_reach_becomes_a_sleeping_body_just_where_it_was():
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	var body: AsteroidBody = _stream.bubble.live.get(rock.id())
	assert_not_null(body)
	assert_true(body.sleeping, "asleep until something touches it")
	assert_true(body.global_transform.is_equal_approx(_stream.rock_pose(rock)))
	assert_eq(body.mass, minf(rock.mass, AsteroidBody.MASS_CAP))
	assert_eq(body.collision_layer, 64)
	assert_eq(body.collision_mask, 1 | 4 | 32 | 64)
	assert_true(body.is_in_group(Universe.EXTERIOR_SPACE))
	assert_true(_stream.is_hidden(rock), "its picture gives way")

func test_nothing_becomes_a_body_without_an_anchor():
	_beside_a_rock(10.0)
	_stream.bubble.step(DT)
	assert_eq(_stream.bubble.live.size(), 0)

func test_a_rock_out_of_reach_stays_a_picture():
	var rock := _beside_a_rock(AsteroidBubble.PAD + 20.0)
	_arm()
	_stream.bubble.step(DT)
	assert_false(_stream.bubble.live.has(rock.id()))

func test_the_reach_runs_ahead_along_your_velocity():
	var rock := _beside_a_rock(AsteroidBubble.PAD + 60.0)
	_arm()
	_anchor.linear_velocity = Vector3(-60, 0, 0)
	_stream.bubble.step(DT)
	assert_true(_stream.bubble.live.has(rock.id()), "1.5 s ahead at 60 m/s")

func test_an_untouched_body_goes_back_to_a_picture_after_you_pass():
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	_anchor.global_position += Vector3(500, 0, 0)
	for i in 5:
		_stream.bubble.step(0.5)
	assert_false(_stream.bubble.live.has(rock.id()))
	assert_false(_stream.is_hidden(rock))
	assert_almost_eq(_stream.picture_transform(rock).origin, _stream.rock_pose(rock).origin, Vector3.ONE * 0.001)

func test_a_touched_rock_is_adrift_and_stays_while_in_sight():
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	var body: AsteroidBody = _stream.bubble.live[rock.id()]
	body.global_position += Vector3(0, 0.02, 0)
	_stream.bubble.step(DT)
	assert_true(body.adrift)
	_anchor.global_position += Vector3(300, 0, 0)
	for i in 5:
		_stream.bubble.step(0.5)
	assert_true(_stream.bubble.live.has(rock.id()), "still within sight")
	assert_true(_stream.is_hidden(rock), "and its home stays empty")

func test_an_adrift_rock_is_dropped_out_of_sight_and_its_home_stays_empty():
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	_stream.bubble.live[rock.id()].global_position += Vector3(0, 0.02, 0)
	_stream.bubble.step(DT)
	_anchor.global_position += Vector3(AsteroidStream.FADE_END[T.RUBBLE] + 100.0, 0, 0)
	_stream.bubble.step(DT)
	assert_false(_stream.bubble.live.has(rock.id()))
	assert_true(_stream.is_hidden(rock), "no second copy appears at home while its cell is loaded")

func test_the_home_is_forgotten_when_its_cell_unloads():
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	_stream.bubble.live[rock.id()].global_position += Vector3(0, 0.02, 0)
	_stream.bubble.step(DT)
	var home := _anchor.global_position
	_anchor.global_position += Vector3(5000, 0, 0)
	_stream.bubble.step(DT)
	_stream.update(0.0, true)
	_anchor.global_position = home
	_stream.update(0.0, true)
	assert_false(_stream.is_hidden(rock), "back in its seeded place")

func test_too_many_adrift_drops_the_farthest():
	_stream.bubble.max_adrift = 1
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	var near: AsteroidBody = _stream.bubble.live[rock.id()]
	var far := AsteroidBody.new()
	var other := AsteroidRock.new()
	other.cell = Vector3i(99, 99, 99)
	other.index = 1
	other.size = Vector3.ONE
	other.mass = 800.0
	far.setup(other, RockMesh.mesh(0, 0), _stream.rock_material(0, SpacePalette.ASH), RockMesh.hull_points(0, 0))
	_stream.get_node("Bodies").add_child(far)
	far.global_position = _anchor.global_position + Vector3(0, 0, 400)
	far.adrift = true
	_stream.bubble.live[other.id()] = far
	near.global_position += Vector3(0, 0.02, 0)
	_stream.bubble.step(DT)
	assert_true(_stream.bubble.live.has(rock.id()))
	assert_false(_stream.bubble.live.has(other.id()))
	assert_engine_error("adrift", "the cap says so")

func test_segment_distance():
	assert_almost_eq(AsteroidBubble.segment_distance(Vector3(5, 3, 0), Vector3.ZERO, Vector3(10, 0, 0)), 3.0, 0.0001)
	assert_almost_eq(AsteroidBubble.segment_distance(Vector3(-4, 3, 0), Vector3.ZERO, Vector3(10, 0, 0)), 5.0, 0.0001)
	assert_almost_eq(AsteroidBubble.segment_distance(Vector3(1, 1, 0), Vector3.ZERO, Vector3.ZERO), sqrt(2.0), 0.0001)
```

And in the real scene, append to `test_floating_origin_scene.gd`:

```gdscript
func test_the_hull_and_a_spacewalker_touch_rocks():
	assert_true(_ship.exterior.is_in_group(AsteroidStream.SPACE_ANCHOR))
	assert_eq(_ship.exterior.collision_mask, 1 | 64)
	assert_true(_ship.exterior.continuous_cd)
	assert_gt(float(_ship.exterior.get_meta(AsteroidStream.ANCHOR_RADIUS)), 7.0)
	_out(Vector3(0, 0, 12))
	assert_true(_avatar.is_in_group(AsteroidStream.SPACE_ANCHOR))
	assert_eq(_avatar.collision_mask, 1 | 32 | 64)
	_back_in()
	assert_false(_avatar.is_in_group(AsteroidStream.SPACE_ANCHOR))
```

- [ ] **Step 2: Run to verify failure** — `AsteroidBody` not declared; the scene test fails on the
  group.

- [ ] **Step 3: Implement**

**File:** `who-knows/src/world/asteroid_body.gd`

```gdscript
class_name AsteroidBody
extends RigidBody3D

## One rock you can touch (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §7.3): put exactly where its picture was, asleep until something hits it,
## then as heavy as it looks. Pooled: the bubble hands one node rock after rock.

const LAYER := 64
## The hull, the avatar, items and other rocks.
const MASK := 1 | 4 | 32 | 64
## Past this the solver gains nothing but trouble: a rock this heavy is a wall
## to anything that can hit it.
const MASS_CAP := 1.0e8
## Moved this far, or turned this much, from where it was put: adrift.
const MOVE := 0.01
const TURN := deg_to_rad(0.5)

static var _surface: PhysicsMaterial

var rock: AsteroidRock
var adrift := false
## Seconds out of every anchor's reach, while untouched.
var outside_for := 0.0

var _shape: CollisionShape3D
var _look: MeshInstance3D

func _init() -> void:
	collision_layer = LAYER
	collision_mask = MASK
	can_sleep = true
	gravity_scale = 0.0
	if _surface == null:
		_surface = PhysicsMaterial.new()
		_surface.friction = 0.6
		_surface.bounce = 0.2
	physics_material_override = _surface
	_shape = CollisionShape3D.new()
	_shape.shape = ConvexPolygonShape3D.new()
	add_child(_shape)
	_look = MeshInstance3D.new()
	_look.layers = 1
	add_child(_look)
	add_to_group(Universe.EXTERIOR_SPACE)

## Becomes `p_rock`: its shape and mesh at its size, its mass, at rest.
func setup(p_rock: AsteroidRock, mesh: Mesh, material: Material, points: PackedVector3Array) -> void:
	rock = p_rock
	var id := rock.id()
	name = "Rock_%d_%d_%d_%d" % [id.x, id.y, id.z, id.w]
	adrift = false
	outside_for = 0.0
	mass = minf(rock.mass, MASS_CAP)
	continuous_cd = rock.tier == AsteroidRecipe.Tier.RUBBLE
	var scaled := PackedVector3Array()
	for p in points:
		scaled.append(p * rock.size)
	(_shape.shape as ConvexPolygonShape3D).points = scaled
	_look.mesh = mesh
	_look.material_override = material
	_look.transform = Transform3D(Basis.from_scale(rock.size), Vector3.ZERO)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

## True once it has moved or turned off the spot it was put on.
func moved_from(home: Transform3D) -> bool:
	if global_position.distance_to(home.origin) > MOVE:
		return true
	var turned := home.basis.get_rotation_quaternion().inverse() * global_basis.get_rotation_quaternion()
	return turned.get_angle() > TURN
```

**File:** `who-knows/src/world/asteroid_bubble.gd`

```gdscript
class_name AsteroidBubble
extends RefCounted

## The rocks you could touch (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §7): every physics tick, rocks near the path of an anchor over the next
## LOOKAHEAD seconds become AsteroidBodies, asleep until something hits them.
## Untouched bodies turn back into pictures once you have passed; touched ones
## are adrift, and last until they are out of sight.

const PAD := 24.0
const LOOKAHEAD := 1.5
const LET_GO_AFTER := 2.0
const MAX_ADRIFT := 96

var stream: AsteroidStream
var holder: Node3D
## Adrift bodies allowed at once; over it, the farthest goes.
var max_adrift := MAX_ADRIFT
## id -> AsteroidBody
var live := {}

var _pool: Array[AsteroidBody] = []

func _init(p_stream: AsteroidStream, p_holder: Node3D) -> void:
	stream = p_stream
	holder = p_holder

func step(delta: float) -> void:
	var near := _near_paths()
	for id: Vector4i in near:
		if not live.has(id):
			_promote(near[id])
	var focus: Node3D = stream.universe.focus if stream.universe != null else null
	var adrift: Array[AsteroidBody] = []
	for id: Vector4i in live.keys():
		var body: AsteroidBody = live[id]
		if not body.adrift and body.moved_from(stream.rock_pose(body.rock)):
			body.adrift = true
		if body.adrift:
			var seen_to := AsteroidStream.FADE_END[body.rock.tier]
			if focus != null and body.global_position.distance_to(focus.global_position) > seen_to:
				_drop(id)
			else:
				adrift.append(body)
		elif near.has(id):
			body.outside_for = 0.0
		else:
			body.outside_for += delta
			if body.outside_for >= LET_GO_AFTER:
				_let_go(id)
	if adrift.size() > max_adrift and focus != null:
		var at := focus.global_position
		adrift.sort_custom(func(a: AsteroidBody, b: AsteroidBody) -> bool:
			return a.global_position.distance_squared_to(at) > b.global_position.distance_squared_to(at))
		push_warning("AsteroidBubble: %d rocks adrift, over %d: dropping the farthest" % [adrift.size(), max_adrift])
		for i in adrift.size() - max_adrift:
			_drop(adrift[i].rock.id())

## Its cell has gone: untouched bodies there go with it.
func cell_unloaded(tier: int, cell: Vector3i) -> void:
	for id: Vector4i in live.keys():
		var body: AsteroidBody = live[id]
		if body.rock.tier == tier and body.rock.cell == cell and not body.adrift:
			_release(id)

## Frees every pooled body (they are out of the tree).
func clear() -> void:
	for body in _pool:
		body.free()
	_pool.clear()

static func segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 1e-9:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Rocks within reach of an anchor's path: id -> rock.
func _near_paths() -> Dictionary:
	var out := {}
	for node in stream.get_tree().get_nodes_in_group(AsteroidStream.SPACE_ANCHOR):
		var anchor := node as Node3D
		if anchor == null or not anchor.is_inside_tree():
			continue
		var a := anchor.global_position
		var b := a + AsteroidStream.velocity_of(anchor) * LOOKAHEAD
		var reach := PAD + float(anchor.get_meta(AsteroidStream.ANCHOR_RADIUS, 1.0))
		for tier in AsteroidRecipe.TIERS:
			var grow := reach + AsteroidRecipe.BOUND * AsteroidRecipe.D_MAX[tier] * AsteroidRecipe.STRETCH_MAX
			var box := AABB(a, Vector3.ZERO).expand(b).grow(grow)
			for rock in stream.rocks_in(tier, box):
				var id := rock.id()
				if out.has(id) or (not live.has(id) and stream.is_hidden(rock)):
					continue
				if segment_distance(stream.rock_pose(rock).origin, a, b) <= reach + rock.radius:
					out[id] = rock
	return out

func _promote(rock: AsteroidRock) -> void:
	var body: AsteroidBody = _pool.pop_back() if not _pool.is_empty() else AsteroidBody.new()
	var detail: int = AsteroidStream.DETAIL[rock.tier]
	body.setup(rock, RockMesh.mesh(rock.shape, detail), stream.rock_material(rock.tier, rock.colour),
		RockMesh.hull_points(rock.shape, detail))
	holder.add_child(body)
	body.global_transform = stream.rock_pose(rock)
	body.sleeping = true
	stream.hide_rock(rock)
	live[rock.id()] = body

## Untouched and passed: back to a picture.
func _let_go(id: Vector4i) -> void:
	var rock: AsteroidRock = live[id].rock
	_release(id)
	stream.show_rock(rock)

## Adrift and out of sight: gone. Its home stays empty while its cell is
## loaded, so no second copy appears.
func _drop(id: Vector4i) -> void:
	_release(id)

func _release(id: Vector4i) -> void:
	var body: AsteroidBody = live[id]
	live.erase(id)
	holder.remove_child(body)
	_pool.append(body)
```

Add the scene wiring:

- `project.godot` `[layer_names]`: after `3d_physics/layer_6="items"` add
  `3d_physics/layer_7="asteroids"`.
- `ship.gd` `_ready()`: replace

  ```gdscript
  	exterior.collision_mask = 1    # detects only other hulls
  ```

  with

  ```gdscript
  	exterior.collision_mask = 1 | AsteroidBody.LAYER   # other hulls, and rocks
  	# At boost the hull moves 5 m a tick: without this it passes through rubble.
  	exterior.continuous_cd = true
  ```

  and after `exterior.add_to_group(Universe.EXTERIOR_SPACE)` add

  ```gdscript
  	# It touches rocks (asteroids spec §7.1).
  	exterior.add_to_group(AsteroidStream.SPACE_ANCHOR)
  ```

  and at the end of `_rebuild_everything()` add

  ```gdscript
  	_set_anchor_radius()
  ```

  with the new function

  ```gdscript
  ## How far the hull reaches from its origin, for the asteroid bubble.
  func _set_anchor_radius() -> void:
  	var reach := 0.0
  	for c: Vector3i in grid.coords():
  		reach = maxf(reach, ShipGrid.cell_center(c).length())
  	exterior.set_meta(AsteroidStream.ANCHOR_RADIUS, reach + ShipGrid.CELL_SIZE * 0.87)
  ```

- `avatar.gd`: `const SUIT_MASK := 1 | 32` becomes `const SUIT_MASK := 1 | 32 | AsteroidBody.LAYER`;
  in `enter_suit` after `add_to_group(Universe.EXTERIOR_SPACE)`:

  ```gdscript
  	add_to_group(AsteroidStream.SPACE_ANCHOR)
  	set_meta(AsteroidStream.ANCHOR_RADIUS, 1.0)
  ```

  and in `enter_plating` after `remove_from_group(Universe.EXTERIOR_SPACE)`:

  ```gdscript
  	remove_from_group(AsteroidStream.SPACE_ANCHOR)
  ```

- [ ] **Step 4: Import, run** `test_asteroid_bubble`, `test_floating_origin_scene`,
  `test_avatar_modes`, then the full suite.
- [ ] **Step 5: Commit** — `feat: rocks near your path become sleeping bodies you can hit`.

---

### Task 5: Into the scene, and how a crash feels

**Files:** modify `flight_test.tscn`, `flight_test.gd`, `avatar.gd` (bumps), `motion_coupling.gd`,
`synth.gd`, `ship.gd` (thump); delete `debris_field.gd`; create `test/unit/test_crash_feel.gd`;
modify `test_synth.gd`.

**Interfaces — Consumes:** everything above. **Produces:** `MotionCoupling.SHOVE_CAP := 12.0`,
`static func felt(shove: Vector3) -> Vector3` (capped), `var jolt: Vector3`;
`Avatar.SUIT_MASS := 120.0`, `BUMP_BOUNCE := 0.2`; `Ship.hull_struck(knock: float)`,
`static func thump_db(knock: float) -> float`; `Synth` sound `&"hull_thump"` (0.6 s).

- [ ] **Step 1: Write the failing tests**

**File:** `who-knows/test/unit/test_crash_feel.gd`

```gdscript
extends GutTest

## How a crash feels (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §7.5, §7.6), in the real scene: capped aboard, with a jolt and a thump; two
## bodies in space on a spacewalk.

const DT := 1.0 / 60.0

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _mc: MotionCoupling

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_mc = _root.get_node("Ship/MotionCoupling")

func test_a_crash_shoves_you_no_harder_than_the_cap():
	_ship.exterior.linear_velocity = Vector3.ZERO
	_mc._physics_process(DT)
	_ship.exterior.linear_velocity = Vector3(0, 0, -20)
	_mc._physics_process(DT)
	assert_lte(_avatar.external_accel.length(), MotionCoupling.SHOVE_CAP + 0.001)
	assert_gt(_mc.jolt.length(), 0.0, "the rest is a jolt")

func test_ordinary_flying_is_not_capped():
	var shove := Vector3(0, 0, 5.7)
	assert_eq(MotionCoupling.felt(shove), shove)

func test_the_jolt_dies_away():
	_ship.exterior.linear_velocity = Vector3.ZERO
	_mc._physics_process(DT)
	_ship.exterior.linear_velocity = Vector3(0, 0, -20)
	_mc._physics_process(DT)
	for i in 60:
		_mc._physics_process(DT)
	assert_lt(_mc.jolt.length(), 0.001)

func test_a_harder_knock_thumps_louder():
	assert_lt(Ship.thump_db(0.5), Ship.thump_db(3.0))
	assert_lt(Ship.thump_db(3.0), Ship.thump_db(10.0))
	assert_eq(Ship.thump_db(100.0), Ship.thump_db(8.0), "capped")

func test_bumping_a_rock_on_a_spacewalk_shares_momentum():
	var outside: Node3D = _root.get_node("Outside")
	_ship.exterior.global_position = Vector3(0, 0, 500)
	_avatar.enter_suit(outside, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), Vector3.ZERO, _ship.exterior)
	var rock := AsteroidRock.new()
	rock.cell = Vector3i(7, 7, 7)
	rock.size = Vector3.ONE * 1.2
	rock.mass = AsteroidRecipe.MASS_PER_M3 * 1.2 * 1.2 * 1.2
	var body := AsteroidBody.new()
	body.setup(rock, RockMesh.mesh(0, 0), StandardMaterial3D.new(), RockMesh.hull_points(0, 0))
	outside.add_child(body)
	body.global_position = Vector3(0, 0, -3)
	_avatar.suit_assist = false
	_avatar.velocity = Vector3(0, 0, -3)
	for i in 90:
		await wait_physics_frames(1)
	var p_avatar := Avatar.SUIT_MASS * _avatar.velocity.z
	var p_rock := body.mass * body.linear_velocity.z
	assert_lt(body.linear_velocity.z, -0.05, "the rock drifts away")
	assert_almost_eq(p_avatar + p_rock, Avatar.SUIT_MASS * -3.0, 40.0, "momentum is shared, not made")
```

In `test_synth.gd`, add `&"hull_thump": 0.6,` to `LENGTHS`.

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**

`motion_coupling.gd`: add after `@export var shake_frequency`:

```gdscript
## The hardest shove you feel, m/s^2: well over a full burn (about 5.7 felt),
## so flying is untouched, but a crash cannot fling you across the room
## (asteroids spec §7.5). The rest becomes a jolt of the head.
const SHOVE_CAP := 12.0
## Head lurch per m/s^2 of shove over the cap, metres; at most JOLT_MAX.
const JOLT_PER_ACCEL := 0.0015
const JOLT_MAX := 0.06
const JOLT_DECAY := 8.0
```

after `var _shake_phase`:

```gdscript
## Where a crash has thrown the head, dying away.
var jolt := Vector3.ZERO
```

replace in `_physics_process`

```gdscript
	var shove := -accel_local * shove_scale
	drive_felt_gravity(shove)
```

with

```gdscript
	var shove := -accel_local * shove_scale
	var over := shove.length() - SHOVE_CAP
	if over > 0.0:
		var lurch := shove.normalized() * minf(JOLT_MAX, over * JOLT_PER_ACCEL)
		if lurch.length() > jolt.length():
			jolt = lurch
	shove = felt(shove)
	jolt *= exp(-JOLT_DECAY * delta)
	drive_felt_gravity(shove)
```

add the static function

```gdscript
## The shove you actually feel: capped.
static func felt(shove: Vector3) -> Vector3:
	return shove.limit_length(SHOVE_CAP)
```

and replace `_apply_shake` with

```gdscript
func _apply_shake(accel_local: Vector3, delta: float) -> void:
	_shake_phase += delta * shake_frequency
	# The rumble is capped with the shove; a crash is the jolt's job.
	var magnitude := minf(accel_local.length(), SHOVE_CAP / shove_scale) * shake_scale
	var sway := sin(_shake_phase) * magnitude * 0.01 if magnitude >= 0.001 else 0.0
	_avatar.head.position.x = sway + jolt.x
	_avatar.head.position.z = jolt.z
```

`avatar.gd`: add after `const SUIT_MASK`:

```gdscript
## You and your suit, kilograms, for bumping into things in space.
const SUIT_MASS := 120.0
const BUMP_BOUNCE := 0.2
```

in `_suit_physics`, replace the final `move_and_slide()` with

```gdscript
	var before := velocity
	move_and_slide()
	_bump_in_space(before)
```

and add

```gdscript
## Two bodies in space (asteroids spec §7.6): bumping a rock shares momentum
## along the contact, with a little bounce. A 1 m rock drifts off slowly; a
## giant stops you dead.
func _bump_in_space(before: Vector3) -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as AsteroidBody
		if body == null:
			continue
		var n := hit.get_normal()
		var at := hit.get_position() - body.global_position
		var closing := -(before - (body.linear_velocity + body.angular_velocity.cross(at))).dot(n)
		if closing <= 0.0:
			continue
		var m := SUIT_MASS * body.mass / (SUIT_MASS + body.mass)
		var j := (1.0 + BUMP_BOUNCE) * m * closing
		body.apply_impulse(-n * j, at)
		velocity += n * (before.dot(n) + j / SUIT_MASS - velocity.dot(n))
```

`synth.gd`: add `&"hull_thump"` to the end of `NAMES`; in `build()`'s match add

```gdscript
		&"hull_thump":
			x = _hull_thump()
```

and the sound, after `_seal_thump`:

```gdscript
## The hull struck: a deep, heavy thump through the structure, with a short
## metallic ring (asteroids spec §7.5).
static func _hull_thump() -> PackedFloat32Array:
	var n := _len(0.6)
	var rumble := _lowpass(_noise(n, 27), 250.0)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(48.0, 30.0, minf(t / 0.35, 1.0)) / MIX_RATE
		x[i] = sin(phase) * exp(-t / 0.18) + rumble[i] * exp(-t / 0.07) * 2.2 \
			+ sin(TAU * 173.0 * t) * exp(-t / 0.12) * 0.12
	return _gain(x, 0.8)
```

`ship.gd`: add `var _thump: AudioStreamPlayer` and `var _last_hull_velocity := Vector3.ZERO`;
in `_ready()` after the hum is added:

```gdscript
	_thump = AudioStreamPlayer.new()
	_thump.name = "Thump"
	_thump.bus = AudioBuses.SHIP
	add_child(_thump)
	exterior.contact_monitor = true
	exterior.max_contacts_reported = 8
	exterior.body_entered.connect(_on_hull_struck)
```

add

```gdscript
func _physics_process(_delta: float) -> void:
	_last_hull_velocity = exterior.linear_velocity

func _on_hull_struck(body: Node) -> void:
	if body is AsteroidBody:
		hull_struck((exterior.linear_velocity - _last_hull_velocity).length())

## A strike you feel aboard (asteroids spec §7.5): a thump, louder the harder
## the hull was knocked (`knock`: its change of speed, m/s). Outside is silent.
func hull_struck(knock: float) -> void:
	if not _aboard():
		return
	var s := Synth.sound(&"hull_thump")
	if s == null:
		return
	_thump.stream = s
	_thump.volume_db = thump_db(knock)
	_thump.play()

static func thump_db(knock: float) -> float:
	return lerpf(-30.0, -2.0, clampf(knock / 8.0, 0.0, 1.0))

func _aboard() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and interior.is_ancestor_of(cam)
```

and make `_update_hum` use `_aboard()`.

`flight_test.tscn`: delete the line
`[ext_resource type="Script" path="res://src/world/debris_field.gd" id="8_debris_field"]` and the
block

```
[node name="DebrisField" type="MultiMeshInstance3D" parent="."]
script = ExtResource("8_debris_field")
```

(with one of its surrounding blank lines); add
`[ext_resource type="Script" path="res://src/world/asteroid_stream.gd" id="21_asteroid_stream"]`
after the universe ext_resource, and after the `Universe` node block:

```
[node name="AsteroidStream" type="Node3D" parent="."]
script = ExtResource("21_asteroid_stream")
```

`load_steps` stays 27. Delete `who-knows/src/world/debris_field.gd` and its `.uid`.

`flight_test.gd`: add `@onready var _stream: AsteroidStream = $AsteroidStream`; in
`_wire_universe()` after `_universe.set_focus(_ship.exterior)`:

```gdscript
	# The flight starts at a field's edge (asteroids spec §5.6): the universe's
	# origin goes there, and the rocks around it load before the first frame.
	var start := AsteroidRecipe.new(_stream.seed).find_start()
	_universe.origin = start
	_stream.start(_universe, start)
```

and extend the readout text with the stream:

```gdscript
	_universe_readout.text = "universe %.3f, %.3f, %.3f km   origin shifts %d\nrock cells %d / %d / %d   bodies %d   late cells %d" % [
		(u.x + u.fx) / 1000.0, (u.y + u.fy) / 1000.0, (u.z + u.fz) / 1000.0, _universe.shifts,
		_stream.loaded_count(0), _stream.loaded_count(1), _stream.loaded_count(2), _stream.bubble.live.size(),
		_stream.late_cells]
```

- [ ] **Step 4: Run** `test_crash_feel`, `test_synth`, `test_floating_origin_scene`,
  `test_motion_coupling`, then the full suite. Time the suite: it was ~30 s; each scene load now
  streams too.
- [ ] **Step 5: Commit** — `feat: asteroids in the flight scene; a capped crash, a jolt and a thump`.

---

### Task 6: Live check, renders, tuning (spec §11.2)

A throwaway script in the scratchpad, windowed, against the real scene:

1. **Renders:** chase camera at the start; a wide shot of a field core; through the canopy from
   the pilot's seat; on a spacewalk at 1.6 m eye height beside a rubble rock and facing a giant.
2. **Flight:** 20 km at boost along a line through fields, logging late cells (must be 0), frames
   over 33 ms (must be 0 with no captures running), worst and mean frame time, cells and bodies
   loaded.
3. **Crashes:** ram rubble, a mid-size rock and a giant at 60 m/s; log hull and rock velocities
   before and after, and the felt shove.
4. **Spacewalk:** bump rubble at 2 m/s; log both velocities.
5. **Density:** the proportions printed in Task 2 against the target (a third fields, half empty);
   retune `DENSITY_LOW/HIGH` if far off, then re-run.

Fix anything found with a test first. Tune colours in `SpacePalette` by rendering. Commit each
fix: `fix: ...`.

---

### Task 7: Records and merge

- [ ] `docs/design/visual-style.md`: add §3.5 *Rocks in space* and the new files to §5 (text in
  the spec §12).
- [ ] Spec amendments (spec §12): Planetfall §4.2, §6.4, §14, §16; airlock §7.4.
- [ ] Asteroid spec: §16 *As built (plan 2)* with the live-check numbers and every deviation.
- [ ] Full suite; merge `--no-ff` into `main` (clean, on `main`), import pass, suite, push,
  remove the worktree, delete the branch.
- [ ] Send the owner the renders.
