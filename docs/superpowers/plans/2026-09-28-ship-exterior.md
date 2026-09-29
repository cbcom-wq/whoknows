# Ship Exterior Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The hull becomes a generated skin that matches the interior: chamfered, panelled, with fairings for taper, windows where the cabin has windows, a pod shell where the cockpit juts out, and floods and forward lights switched from the helm or the bridge.

**Architecture:** The outside gets the interior's pipeline. A pure `HullLayout` reads the grid, and the interior's own `InteriorLayout`, and decides what every exposed face is. `HullDressing` maps each record to a grid-blind `HullProps` builder, which builds into `InteriorKit` batches on the own-hull layer. `ExteriorBuilder` keeps the colliders and the airlock alcoves and swaps its per-block MultiMeshes for the dressing's merged meshes. A `ShipLights` node under the hull body owns the spot lights and beams, and outlives rebuilds.

**Tech Stack:** Godot 4.5.1, GDScript, GUT tests.

**Spec:** `docs/superpowers/specs/2026-09-28-ship-exterior-design.md`. Read it before starting. Also read `CLAUDE.md`, `docs/design/visual-style.md` and `.claude/skills/building-a-ship/SKILL.md`.

**Builds on `main` at `dfd7b91`**, which includes the star-system skeleton (`docs/superpowers/specs/2026-09-27-system-skeleton-design.md`). What that means here:
- `StarSystem` re-aims the scene's `DirectionalLight3D` from the star every physics tick, and sets its colour and energy from `SpacePalette.STARS`.
- `SpaceDust` flecks drift round the focus, lit, never glowing: the lights will catch them.
- The star is the one emissive thing outside, and **its glow was approved by the owner from renders**. Task 12's bloom must be shown to the owner against it.
- **Saves store the ship's layout** (`Ship.to_dict()["layout"]`), so a resumed game keeps the ship it had, not the reshaped starter (Task 6, Step 5b).

## Global Constraints

- Paths are relative to `who-knows/` unless they start with `docs/` or `.claude/`.
- `$GODOT` is `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe`.
- **Running tests:**
  - one file: `who-knows/run_tests.ps1 -gselect=<file name without .gd>`, from the repo root in PowerShell;
  - the whole suite: `who-knows/run_tests.ps1`.
- After adding any `class_name`, run `& $GODOT --headless --path who-knows --import` before running tests.
- GDScript style: tabs, static types, `##` doc comments that say *why*. Match the surrounding code.
- **Colours:**
  - on the hull they come only from `HullPalette`; inside from `InteriorPalette`; in space from `SpacePalette`;
  - no `Color(...)` or `Color.NAME` literal in any file listed in `test_visual_style_rules.gd`'s `PAINTING_FILES`.
- **Props never see the grid.** `HullProps` and `HullMaterials` build from a kit, a frame and plain values. They never name `ShipGrid`, `BlockCatalog`, `DeckGraph`, `InteriorLayout`, `InteriorBuilder` or `InteriorDressing`.
- **No new shader.** The interior shader budget stays three. Engine materials (`StandardMaterial3D`, `GradientTexture2D`) and new instances of `glow.gdshader` are fine.
- **Render layers and masks:**
  - the hull and everything on it: `ExteriorBuilder.OWN_HULL_LAYER` (4);
  - beams: layer 1;
  - exterior lights: light cull mask `1 | 4`, never layer 2 (the interior).
- **Floating origin:** anything outside the ship is a descendant of the hull body (`Ship/Exterior`, already in `Universe.EXTERIOR_SPACE`).
- **`.tscn`/`.tres` files:**
  - no `#` comments anywhere inside them;
  - after editing one, load it and read the property back at runtime.
- **The spec's numbers:**
  - skin: `CHAMFER` 0.4 m, `PLATE_PROUD` 0.05 m, `PLATE_BEVEL` 0.04 m, `PLATE_GAP` 0.04 m;
  - every fairing weighs 0.3 t;
  - floods: 55° cone, 40 m reach, 25° outward tilt, keel spacing 6 m, belly band 1.5 m;
  - forward lights: 22° cone, 220 m reach, 5° down, 3° toe-out, normal · forward ≥ 0.7, within 2.5 m of the bow, 0.3 m below any window;
  - `lights_flood` on L, `lights_forward` on K;
  - low power sets both light levels to 0.5.
- **Frame budget:** ≥ 120 fps at 1280×720 on the reference GPU, with the canopy view rendering.
- **The building-a-ship skill** is updated in this branch before the work is called done (Task 14).
- **Commits:** every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Branch:** work on `ship-exterior`, created from `ship-exterior-design`.

## Review Focus

These failure modes are not covered by the spec's own examples. Each has a test in the task that owns it.

1. **A ship with no cockpit pod** (a windshield with no helm behind it): it must still get nose windows outside, and forward lights on its bow. *Task 7, `test_a_nose_without_a_pod_gets_its_windows`; Task 8, `test_a_ship_with_no_pod_still_gets_forward_lights`.*
2. **Shaped blocks next to cubes and other shapes**: no hole may open in the skin where a cube face is only partly hidden. *Task 2, `test_a_face_half_hidden_by_a_shaped_block_still_shows`.*
3. **A rebuild while the lights are on** (a block changes in flight): the lights must come back on, in the new places. *Task 9, `test_a_rebuild_keeps_the_lights_on`.*
4. **Loading a save from before this feature**, with no `lights` part: it must load with the lights off and no error. *Task 9, `test_a_save_without_lights_loads_them_off`.*
5. **A ship with no quantum plant** (the test ships and future hulls): the lights must work at full power with `quantum` null. *Task 9, `test_with_no_plant_the_lights_run_at_full_power`.*

---

## File map

Create:

| File | Responsibility |
|---|---|
| `src/ship/hull/hull_shapes.gd` | the seven block shapes: points, faces, `covers`, `contains`, collider parts |
| `src/ship/hull/hull_layout.gd` | pure: the skin, windows, pods, nozzles, light mounts and running strips |
| `src/ship/hull/hull_materials.gd` | the hull's materials: livery, trim, window glass, glow instances, beams |
| `src/ship/hull/hull_props.gd` | grid-blind builders for every piece on the hull |
| `src/ship/hull/hull_dressing.gd` | maps the layout's records to props; builds the kits |
| `src/ship/ship_lights.gd` | the lights' state, spot lights, beams, levels and save |
| `src/ship/lights_panel.gd` | the bridge's two-button lights panel |
| `data/blocks/fairing_*.tres` | six fairing blocks |
| `test/unit/test_hull_shapes.gd`, `test_hull_layout.gd`, `test_hull_props.gd`, `test_hull_windows.gd`, `test_hull_lights.gd`, `test_ship_lights.gd`, `test_lights_panel.gd` | tests |

Modify:

| File | Change |
|---|---|
| `src/ship/interior/interior_kit.gd` | a `HULL` batch, per-batch material overrides |
| `src/ship/hull_palette.gd` | hull colours: plate, trim, glass, window light, work lights, nozzle |
| `src/world/space_palette.gd` | `AMBIENT` for the darker outside |
| `src/ship/exterior_builder.gd` | the skin in place of MultiMeshes; shaped colliders; accessors |
| `src/ship/computer/holo_volume.gd`, `src/ship/computer/status_page.gd` | the miniature from `Mesh`es |
| `src/ship/ship.gd` | `ShipLights`; bind it and the panels after a rebuild; save it |
| `src/ship/interior/interior_props.gd`, `src/ship/interior/interior_dressing.gd`, `src/ship/interior_builder.gd` | the lights panel on a shoulder wall |
| `src/flight/pilot_controls.gd`, `src/ui/vehicle_telemetry.gd`, `src/ui/panels/velocity_panel.gd`, `src/ui/controls_card.gd`, `project.godot` | L and K, the HUD line, the card rows |
| `src/audio/synth.gd` | the `light_switch` sound |
| `scenes/flight_test.gd` | the reshaped starter; the pilot's lights; the outside mood |
| `.claude/skills/building-a-ship/*`, `docs/design/visual-style.md`, specs | the records |

---

### Task 1: HullShapes, the seven block shapes

**Files:**
- Create: `src/ship/hull/hull_shapes.gd`
- Test: `test/unit/test_hull_shapes.gd`

**Interfaces:**
- Consumes: `BlockOrientation.basis_for(o: int) -> Basis`.
- Produces:
  - constants `HullShapes.CUBE`, `SLOPE`, `SLOPE_LONG_LOW`, `SLOPE_LONG_HIGH`, `CORNER_OUT`, `CORNER_IN`, `HALF`, and `BY_ID`;
  - `shape_of(block_id: StringName) -> StringName`;
  - `points(shape) -> PackedVector3Array`;
  - `faces(shape) -> Array[Dictionary]`, each `{points: PackedVector3Array, normal: Vector3, side: Vector3i, full: bool}`, block-local;
  - `covers(shape, orientation: int, hull_normal: Vector3i) -> bool`;
  - `contains(shape, local_point: Vector3) -> bool`;
  - `collider_parts(shape) -> Array[PackedVector3Array]`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## Ship exterior spec §4: the shapes a hull block can have, block-local with
## the block facing FORWARD, a cell spanning -1..1 m.

const ALL := [HullShapes.CUBE, HullShapes.SLOPE, HullShapes.SLOPE_LONG_LOW, HullShapes.SLOPE_LONG_HIGH,
	HullShapes.CORNER_OUT, HullShapes.CORNER_IN, HullShapes.HALF]

func test_blocks_that_are_not_listed_are_cubes():
	assert_eq(HullShapes.shape_of(&"hull"), HullShapes.CUBE)
	assert_eq(HullShapes.shape_of(&"deck"), HullShapes.CUBE)
	assert_eq(HullShapes.shape_of(&"thruster"), HullShapes.CUBE)
	assert_eq(HullShapes.shape_of(&"hull_wedge"), HullShapes.SLOPE)
	assert_eq(HullShapes.shape_of(&"canopy"), HullShapes.SLOPE)
	assert_eq(HullShapes.shape_of(&"fairing_half"), HullShapes.HALF)

## hull_wedge's own mesh is the wedge every slope must match: a full bottom
## rising to a full back face (+z), so its slope faces up and toward the bow.
func test_the_slope_is_the_old_wedge():
	var mesh: ArrayMesh = load("res://data/blocks/meshes/hull_wedge.tres")
	var want := {}
	for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		want[v.snapped(Vector3.ONE * 0.01)] = true
	var got := {}
	for p in HullShapes.points(HullShapes.SLOPE):
		got[p] = true
	assert_eq(got.size(), want.size())
	for p in want:
		assert_true(got.has(p), "the slope has the wedge's point %s" % p)

func test_every_face_normal_points_out_of_its_solid():
	for shape in ALL:
		for face in HullShapes.faces(shape):
			var mid := Vector3.ZERO
			for p: Vector3 in face["points"]:
				mid += p
			mid /= face["points"].size()
			var n: Vector3 = face["normal"]
			assert_almost_eq(n.length(), 1.0, 0.0001)
			assert_false(HullShapes.contains(shape, mid + n * 0.05), "%s: a normal points inward" % shape)
			assert_true(HullShapes.contains(shape, mid - n * 0.05), "%s: just inside a face is solid" % shape)

func _full_sides(shape: StringName) -> Array:
	var out := []
	for face in HullShapes.faces(shape):
		if face["full"]:
			out.append(face["side"])
	out.sort()
	return out

func test_which_faces_fill_their_cell_face():
	assert_eq(_full_sides(HullShapes.CUBE).size(), 6)
	assert_eq(_full_sides(HullShapes.SLOPE), [Vector3i(0, -1, 0), Vector3i(0, 0, 1)])
	assert_eq(_full_sides(HullShapes.SLOPE_LONG_LOW), [Vector3i(0, -1, 0)])
	assert_eq(_full_sides(HullShapes.SLOPE_LONG_HIGH), [Vector3i(0, -1, 0), Vector3i(0, 0, 1)])
	assert_eq(_full_sides(HullShapes.CORNER_OUT), [Vector3i(0, -1, 0)])
	assert_eq(_full_sides(HullShapes.CORNER_IN), [Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)])
	assert_eq(_full_sides(HullShapes.HALF), [Vector3i(0, -1, 0)])

func test_covers_turns_with_the_block():
	assert_true(HullShapes.covers(HullShapes.CUBE, 0, Vector3i.UP))
	assert_true(HullShapes.covers(HullShapes.SLOPE, 0, Vector3i(0, 0, 1)), "its back is full")
	assert_false(HullShapes.covers(HullShapes.SLOPE, 0, Vector3i(0, 0, -1)), "its front is an edge")
	assert_true(HullShapes.covers(HullShapes.SLOPE, 4, Vector3i(0, 0, -1)), "facing aft, its back is to the bow")
	assert_true(HullShapes.covers(HullShapes.HALF, 2, Vector3i.UP), "turned over, it fills the cell's top")
	assert_false(HullShapes.covers(HullShapes.HALF, 2, Vector3i.DOWN))

func test_the_inner_corner_is_two_slopes():
	assert_eq(HullShapes.collider_parts(HullShapes.CORNER_IN).size(), 2)
	assert_eq(HullShapes.collider_parts(HullShapes.SLOPE).size(), 1)
	assert_true(HullShapes.contains(HullShapes.CORNER_IN, Vector3(0.9, 0.8, -0.9)), "under the slope rising to +x")
	assert_true(HullShapes.contains(HullShapes.CORNER_IN, Vector3(-0.9, 0.8, 0.9)), "under the slope rising to +z")
	assert_false(HullShapes.contains(HullShapes.CORNER_IN, Vector3(-0.9, 0.8, -0.9)), "the valley between them")
	for part in HullShapes.collider_parts(HullShapes.CORNER_IN):
		for p in part:
			assert_true(HullShapes.contains(HullShapes.CORNER_IN, p), "every collider point is in the solid")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `who-knows/run_tests.ps1 -gselect=test_hull_shapes`
Expected: FAIL, with a parse error saying `HullShapes` is not declared.

- [ ] **Step 3: Write `src/ship/hull/hull_shapes.gd`**

```gdscript
class_name HullShapes
extends RefCounted

## The shapes a hull block can have (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §4), block-local with the block facing
## FORWARD: a cell spans -1..1 m on each axis. Pure data and geometry.
## HullLayout asks which faces show, HullDressing draws them, and
## ExteriorBuilder takes colliders from them.

const CUBE := &"cube"
const SLOPE := &"slope"
const SLOPE_LONG_LOW := &"slope_long_low"
const SLOPE_LONG_HIGH := &"slope_long_high"
const CORNER_OUT := &"corner_out"
const CORNER_IN := &"corner_in"
const HALF := &"half"

## Every block that is not a cube. `hull_wedge` and `canopy` have always been
## this wedge; the fairings are the new shapes.
const BY_ID := {
	&"hull_wedge": SLOPE,
	&"canopy": SLOPE,
	&"fairing_slope": SLOPE,
	&"fairing_slope_long_low": SLOPE_LONG_LOW,
	&"fairing_slope_long_high": SLOPE_LONG_HIGH,
	&"fairing_corner_out": CORNER_OUT,
	&"fairing_corner_in": CORNER_IN,
	&"fairing_half": HALF,
}

## Each shape's corners, and its faces as indices into them. The four bottom
## corners come first in every shape: B0 front-left, B1 front-right, B2
## back-right, B3 back-left.
const _SOLIDS := {
	&"cube": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		"faces": [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]],
	},
	# A full bottom rising to a full back: the old hull_wedge.
	&"slope": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		"faces": [[0, 1, 2, 3], [3, 2, 4, 5], [1, 2, 4], [0, 3, 5], [0, 1, 4, 5]],
	},
	# The lower half of a two-cell ramp: 0 to 1 m of rise across the cell.
	&"slope_long_low": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(1, 0, 1), Vector3(-1, 0, 1)],
		"faces": [[0, 1, 2, 3], [3, 2, 4, 5], [1, 2, 4], [0, 3, 5], [0, 1, 4, 5]],
	},
	# The upper half: a metre of block with the ramp's second metre on top.
	&"slope_long_high": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		"faces": [[0, 1, 2, 3], [0, 1, 5, 4], [3, 2, 6, 7], [1, 2, 6, 5], [0, 3, 7, 4], [4, 5, 6, 7]],
	},
	# Where two slopes meet round a convex corner: a quarter pyramid.
	&"corner_out": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(1, 1, 1)],
		"faces": [[0, 1, 2, 3], [1, 2, 4], [3, 2, 4], [0, 1, 4], [0, 3, 4]],
	},
	# Where two slopes meet round a concave corner: a slope rising to +z and
	# one rising to +x, together. Not convex: the valley runs corner to corner.
	&"corner_in": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)],
		"faces": [[0, 1, 2, 3], [1, 2, 5, 6], [3, 2, 5, 4], [0, 3, 4], [0, 1, 6], [0, 4, 5], [0, 5, 6]],
	},
	# The bottom half of a cell. Turned over (orientation 2), the top half.
	&"half": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)],
		"faces": [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]],
	},
}

static var _faces_cache: Dictionary = {}

static func shape_of(block_id: StringName) -> StringName:
	return BY_ID.get(block_id, CUBE)

static func points(shape: StringName) -> PackedVector3Array:
	return PackedVector3Array(_SOLIDS[shape]["points"])

## Every face: its points round the face, its unit normal out of the solid,
## the cell face it lies on (`side`, ZERO for a slope or a half's top), and
## whether it fills that whole cell face (`full`).
static func faces(shape: StringName) -> Array[Dictionary]:
	if not _faces_cache.has(shape):
		_faces_cache[shape] = _build_faces(shape)
	return _faces_cache[shape]

static func _build_faces(shape: StringName) -> Array[Dictionary]:
	var pts := points(shape)
	var centre := Vector3.ZERO
	for p in pts:
		centre += p
	centre /= pts.size()
	var out: Array[Dictionary] = []
	for indices: Array in _SOLIDS[shape]["faces"]:
		var fp := PackedVector3Array()
		for i: int in indices:
			fp.append(pts[i])
		var n := (fp[1] - fp[0]).cross(fp[2] - fp[0]).normalized()
		var mid := Vector3.ZERO
		for p in fp:
			mid += p
		mid /= fp.size()
		if n.dot(mid - centre) < 0.0:
			n = -n
		var side := _side_of(fp)
		out.append({"points": fp, "normal": n, "side": side,
			"full": side != Vector3i.ZERO and is_equal_approx(_area(fp), 4.0)})
	return out

static func _side_of(fp: PackedVector3Array) -> Vector3i:
	for axis in 3:
		for s: float in [-1.0, 1.0]:
			var on := true
			for p in fp:
				if not is_equal_approx(p[axis], s):
					on = false
					break
			if on:
				var v := Vector3i.ZERO
				v[axis] = int(s)
				return v
	return Vector3i.ZERO

static func _area(fp: PackedVector3Array) -> float:
	var sum := Vector3.ZERO
	for i in range(1, fp.size() - 1):
		sum += (fp[i] - fp[0]).cross(fp[i + 1] - fp[0])
	return sum.length() * 0.5

## Whether a block of `shape`, turned by `orientation`, fills its whole cell
## face toward `hull_normal`: if so, whatever is on the other side is hidden.
static func covers(shape: StringName, orientation: int, hull_normal: Vector3i) -> bool:
	if shape == CUBE:
		return true
	var local := BlockOrientation.basis_for(orientation).inverse() * Vector3(hull_normal)
	var side := Vector3i(roundi(local.x), roundi(local.y), roundi(local.z))
	for face in faces(shape):
		if face["side"] == side and face["full"]:
			return true
	return false

## Whether a block-local point is inside the solid.
static func contains(shape: StringName, p: Vector3) -> bool:
	const E := 0.0001
	if absf(p.x) > 1.0 + E or absf(p.y) > 1.0 + E or absf(p.z) > 1.0 + E:
		return false
	match shape:
		SLOPE:
			return p.y <= p.z + E
		SLOPE_LONG_LOW:
			return p.y <= (p.z - 1.0) * 0.5 + E
		SLOPE_LONG_HIGH:
			return p.y <= (p.z + 1.0) * 0.5 + E
		CORNER_OUT:
			return p.y <= minf(p.x, p.z) + E
		CORNER_IN:
			return p.y <= maxf(p.x, p.z) + E
		HALF:
			return p.y <= E
	return true

## The convex pieces a collider is made of, block-local. The inner corner is
## not convex, so it is its two slopes.
static func collider_parts(shape: StringName) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	if shape == CORNER_IN:
		var slope := points(SLOPE)
		out.append(slope)
		var turned := PackedVector3Array()
		var quarter := Basis(Vector3.UP, PI * 0.5)   # its rise, +z, turned to +x
		for p in slope:
			turned.append(quarter * p)
		out.append(turned)
	else:
		out.append(points(shape))
	return out
```

- [ ] **Step 4: Import and run the test**

Run: `& $GODOT --headless --path who-knows --import`, then `who-knows/run_tests.ps1 -gselect=test_hull_shapes`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/hull/hull_shapes.gd who-knows/src/ship/hull/hull_shapes.gd.uid who-knows/test/unit/test_hull_shapes.gd
git commit -m "feat: HullShapes -- the seven shapes a hull block can have

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: HullLayout, the skin

**Files:**
- Create: `src/ship/hull/hull_layout.gd`
- Test: `test/unit/test_hull_layout.gd`

**Interfaces:**
- Consumes: `HullShapes` (Task 1); `AirlockSite.hatch_normal(grid, coord) -> Vector3i`; `BlockOrientation`; `ShipGrid.FACE_OFFSETS`, `ShipGrid.cell_center`; `RcsShow.BLOCK_ID`.
- Produces:
  - `HullLayout.plan(grid: ShipGrid, catalog: BlockCatalog, interior: InteriorLayout) -> HullLayout`, where `interior` may be null;
  - arrays:
    - `plates`: `{coord, normal: Vector3i, lo: Vector2, hi: Vector2}`, in the face frame's (x, y);
    - `edges`: `{coord, a: Vector3i, b: Vector3i, axis: Vector3i, ends: [StringName, StringName], running: bool}`, with ends `&"corner" | &"through" | &"cap"` for the −axis end and the +axis end;
    - `corners`: `{coord, sign: Vector3i}`;
    - `facets`: `{coord, shape, orientation, face: int}`;
    - `nozzles`: `{coord, normal: Vector3i, kind: StringName}`;
    - `windows`, `pods`, `mounts`, `unmatched`, which are empty until Tasks 7 and 8;
  - `skin: Dictionary`: `Vector3i -> {Vector3i: true}`, the open faces of cube cells;
  - static frames: `face_basis(n) -> Basis`, `face_frame(coord, n) -> Transform3D`, `edge_frame(e) -> Transform3D`, `edge_span(e) -> Vector2`, `corner_frame(c) -> Transform3D`, `cell_frame(coord, orientation) -> Transform3D`;
  - facet helpers: `facet_points(f) -> PackedVector3Array`, `facet_normal(f) -> Vector3`, `facet_centre(f) -> Vector3`, all in hull space;
  - `shape_at(coord) -> StringName`, which returns `&""` for an empty cell and `HullLayout.ALCOVE` for an airlock alcove;
  - `inside(p: Vector3) -> bool`: whether a hull-space point is inside a block's solid.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## Ship exterior spec §3.1: the skin over every occupied cell -- plates,
## chamfered convex edges, corner facets, and the faces of shaped blocks.

var _cat: BlockCatalog
var _grid: ShipGrid

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func before_each():
	_grid = ShipGrid.new()

func _put(coord: Vector3i, id: StringName, o := 0) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = o
	_grid.set_block(coord, i)

func _plan() -> HullLayout:
	return HullLayout.plan(_grid, _cat, null)

func _edges_along(l: HullLayout, axis_index: int) -> int:
	var n := 0
	for e in l.edges:
		var axis: Vector3i = e["axis"]
		if axis[axis_index] != 0:
			n += 1
	return n

func test_one_cube_has_six_plates_twelve_edges_eight_corners():
	_put(Vector3i.ZERO, &"hull")
	var l := _plan()
	assert_eq(l.plates.size(), 6)
	assert_eq(l.edges.size(), 12)
	assert_eq(l.corners.size(), 8)
	for p in l.plates:
		assert_almost_eq(p["lo"], Vector2(-0.6, -0.6), Vector2.ONE * 0.0001, "chamfered on every side")
		assert_almost_eq(p["hi"], Vector2(0.6, 0.6), Vector2.ONE * 0.0001)
	for e in l.edges:
		assert_eq(e["ends"], [&"corner", &"corner"])

func test_two_cubes_share_no_face_and_their_edges_run_through():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"hull")
	var l := _plan()
	assert_eq(l.plates.size(), 10)
	assert_eq(l.edges.size(), 16)
	assert_eq(l.corners.size(), 8)
	var through := 0
	for e in l.edges:
		if e["ends"].has(&"through"):
			through += 1
	assert_eq(through, 8, "the four long edges, from both cubes")

func test_an_l_has_no_chamfer_in_its_concave_corner():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(0, 0, 1), &"hull")
	assert_eq(_edges_along(_plan(), 1), 5, "five convex vertical edges; the sixth corner is concave")

func test_a_walkable_cell_open_to_space_is_skinned():
	_put(Vector3i.ZERO, &"deck")
	assert_eq(_plan().plates.size(), 6)

func test_a_slope_hides_the_face_its_back_is_against():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(0, 0, -1), &"fairing_slope")
	var l := _plan()
	assert_false(l.skin[Vector3i.ZERO].has(Vector3i(0, 0, -1)))
	for e in l.edges:
		assert_false(e["a"] == Vector3i(0, 0, -1) or e["b"] == Vector3i(0, 0, -1), "no chamfer into the slope")
	assert_eq(l.facets.size(), 4, "the slope's back face is hidden against the cube")

func test_a_face_half_hidden_by_a_shaped_block_still_shows():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"fairing_half")
	var l := _plan()
	assert_true(l.skin[Vector3i.ZERO].has(Vector3i(1, 0, 0)),
		"a half block covers only half the cube's face: the rest must be drawn")

func test_an_edge_that_meets_an_unchamfered_neighbour_is_capped():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(0, 0, 1), &"hull")
	_put(Vector3i(1, 0, 1), &"hull")
	var l := _plan()
	var found := false
	for e in l.edges:
		if e["coord"] == Vector3i.ZERO and e["a"] == Vector3i(1, 0, 0) and e["b"] == Vector3i(0, 1, 0):
			found = true
			assert_eq(e["axis"], Vector3i(0, 0, 1))
			assert_eq(e["ends"], [&"corner", &"cap"])
	assert_true(found)

func test_an_airlock_alcove_is_left_to_the_alcove():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(0, 0, -1), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(-1, 0, 0), &"hull")
	var l := _plan()
	assert_eq(l.shape_at(Vector3i.ZERO), HullLayout.ALCOVE)
	assert_false(l.skin.has(Vector3i.ZERO))
	for e in l.edges:
		assert_ne(e["coord"], Vector3i.ZERO)
	assert_false(l.skin[Vector3i(0, 0, -1)].has(Vector3i(0, 0, 1)), "the deck's face on the alcove is inside")

func test_an_engine_gets_a_nozzle_on_its_exhaust_face():
	_put(Vector3i.ZERO, &"thruster")
	var l := _plan()
	assert_eq(l.nozzles.size(), 1)
	assert_eq(l.nozzles[0]["normal"], Vector3i(0, 0, 1), "a FORWARD thruster exhausts aft")
	assert_eq(l.nozzles[0]["kind"], &"thruster")

func test_inside_follows_the_shapes():
	_put(Vector3i.ZERO, &"fairing_slope")
	var l := _plan()
	assert_true(l.inside(Vector3(0, -0.5, 0.5)))
	assert_false(l.inside(Vector3(0, 0.5, -0.5)), "above the slope is open")
	assert_false(l.inside(Vector3(0, 0, 5)))

func test_the_same_grid_gives_the_same_skin():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"fairing_slope", 12)
	_put(Vector3i(0, 1, 0), &"deck")
	assert_eq(str(_plan().plates), str(_plan().plates))
	assert_eq(str(_plan().edges), str(_plan().edges))
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `who-knows/run_tests.ps1 -gselect=test_hull_layout`
Expected: FAIL, with `HullLayout` not declared.

- [ ] **Step 3: Write `src/ship/hull/hull_layout.gd`**

```gdscript
class_name HullLayout
extends RefCounted

## Decides what the hull's outside is, once (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §3.1, §5, §6.1), for HullDressing to
## draw:
## - the skin over every occupied cell -- a plate per exposed face of a cube,
##   a chamfer on each convex edge, a facet where three chamfers meet, and
##   the exposed faces of shaped blocks;
## - the nozzles on engines and RCS;
## - the windows and pods, which match the interior's (Task 7);
## - the light mounts (Task 8).
##
## Pure: reads the grid and the interior's own layout, touches no nodes. The
## same grid always yields the same layout.

## A cell whose airlock can cycle: AirlockAlcove draws it, not the skin.
const ALCOVE := &"alcove"
const CHAMFER := HullProps.CHAMFER
const HALF_CELL := ShipGrid.CELL_SIZE * 0.5

var plates: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var corners: Array[Dictionary] = []
var facets: Array[Dictionary] = []
var nozzles: Array[Dictionary] = []
var windows: Array[Dictionary] = []
var pods: Array[Dictionary] = []
var mounts: Array[Dictionary] = []
## Interior window faces with no place for a window outside. Empty on any
## ship we give the player; the probe prints it.
var unmatched: Array[Dictionary] = []
## How many interior windows there are, matched or not.
var wanted := 0
## The open faces of every cube cell: Vector3i -> {Vector3i normal: true}.
var skin: Dictionary = {}

var _grid: ShipGrid
var _alcoves: Dictionary = {}
var _pod_cells: Dictionary = {}

static func plan(grid: ShipGrid, _catalog: BlockCatalog, interior: InteriorLayout) -> HullLayout:
	var l := HullLayout.new()
	l._grid = grid
	for coord: Vector3i in grid.coords():
		if AirlockSite.hatch_normal(grid, coord) != Vector3i.ZERO:
			l._alcoves[coord] = true
	l._plan_skin()
	l._plan_nozzles()
	return l

## The skin frame of a face (spec §3.3): +z out of the hull, +y up the face,
## or toward the bow on a roof or belly, +x across.
static func face_basis(n: Vector3i) -> Basis:
	var z := Vector3(n)
	var y := Vector3.UP if n.y == 0 else Vector3.FORWARD
	return Basis(y.cross(z), y, z)

static func face_frame(coord: Vector3i, n: Vector3i) -> Transform3D:
	return Transform3D(face_basis(n), ShipGrid.cell_center(coord) + Vector3(n) * HALF_CELL)

## A chamfer's frame: origin on the cube's edge at its middle, +x along the
## edge, +y and +z the two faces' normals, so the cube is where y and z are
## negative.
static func edge_frame(e: Dictionary) -> Transform3D:
	var a: Vector3i = e["a"]
	var b: Vector3i = e["b"]
	var axis: Vector3i = e["axis"]
	return Transform3D(Basis(Vector3(axis), Vector3(a), Vector3(b)),
		ShipGrid.cell_center(e["coord"]) + Vector3(a + b) * HALF_CELL)

## Where a chamfer starts and ends along its frame's x: short of a corner by
## the chamfer, else the cell's own end.
static func edge_span(e: Dictionary) -> Vector2:
	var ends: Array = e["ends"]
	return Vector2(-HALF_CELL + (CHAMFER if ends[0] == &"corner" else 0.0),
		HALF_CELL - (CHAMFER if ends[1] == &"corner" else 0.0))

## A corner facet's frame: origin on the cube's corner, each axis along one of
## the three open faces' normals, so the cube is where all three are negative.
static func corner_frame(c: Dictionary) -> Transform3D:
	var s: Vector3i = c["sign"]
	return Transform3D(Basis(Vector3(s.x, 0, 0), Vector3(0, s.y, 0), Vector3(0, 0, s.z)),
		ShipGrid.cell_center(c["coord"]) + Vector3(s) * HALF_CELL)

static func cell_frame(coord: Vector3i, orientation: int) -> Transform3D:
	return Transform3D(BlockOrientation.basis_for(orientation), ShipGrid.cell_center(coord))

static func facet_face(f: Dictionary) -> Dictionary:
	return HullShapes.faces(f["shape"])[f["face"]]

static func facet_points(f: Dictionary) -> PackedVector3Array:
	var frame := cell_frame(f["coord"], f["orientation"])
	var out := PackedVector3Array()
	for p: Vector3 in facet_face(f)["points"]:
		out.append(frame * p)
	return out

static func facet_normal(f: Dictionary) -> Vector3:
	return (BlockOrientation.basis_for(f["orientation"]) * facet_face(f)["normal"]).normalized()

static func facet_centre(f: Dictionary) -> Vector3:
	var pts := facet_points(f)
	var c := Vector3.ZERO
	for p in pts:
		c += p
	return c / pts.size()

## What occupies a cell: its HullShapes shape, ALCOVE, or &"" when empty.
func shape_at(coord: Vector3i) -> StringName:
	var inst := _grid.get_block(coord)
	if inst == null:
		return &""
	if _alcoves.has(coord):
		return ALCOVE
	return HullShapes.shape_of(inst.block_id)

## Whether a point in hull space is inside any block's solid.
func inside(p: Vector3) -> bool:
	var coord := Vector3i((p / ShipGrid.CELL_SIZE).round())
	var shape := shape_at(coord)
	if shape == &"":
		return false
	if shape == ALCOVE:
		return true
	var inst := _grid.get_block(coord)
	var local := BlockOrientation.basis_for(inst.orientation).inverse() * (p - ShipGrid.cell_center(coord))
	return HullShapes.contains(shape, local)

## Whether the neighbour across `coord`'s face toward `normal` fills that whole
## face, hiding it.
func _covered(coord: Vector3i, normal: Vector3i) -> bool:
	var other := coord + normal
	var shape := shape_at(other)
	if shape == &"":
		return false
	if shape == HullShapes.CUBE or shape == ALCOVE:
		return true
	return HullShapes.covers(shape, _grid.get_block(other).orientation, -normal)

func _sorted_cells() -> Array:
	var cells := _grid.coords()
	cells.sort()
	return cells

func _plan_skin() -> void:
	for coord: Vector3i in _sorted_cells():
		var shape := shape_at(coord)
		if shape == ALCOVE or _pod_cells.has(coord):
			continue
		if shape == HullShapes.CUBE:
			var open := {}
			for n: Vector3i in ShipGrid.FACE_OFFSETS:
				if not _covered(coord, n):
					open[n] = true
			if not open.is_empty():
				skin[coord] = open
			continue
		var inst := _grid.get_block(coord)
		var basis := BlockOrientation.basis_for(inst.orientation)
		var faces := HullShapes.faces(shape)
		for i in faces.size():
			var side: Vector3i = faces[i]["side"]
			if side != Vector3i.ZERO:
				var hull_side := _round(basis * Vector3(side))
				if _covered(coord, hull_side):
					continue
			facets.append({"coord": coord, "shape": shape, "orientation": inst.orientation, "face": i})
	var cubes := skin.keys()
	cubes.sort()
	for coord: Vector3i in cubes:
		_plan_cube(coord, skin[coord])

## One cube's plates, chamfers and corner facets. A side of a plate is cut
## back by the chamfer where the face beside it, on the same cube, is open
## too: that edge is convex.
func _plan_cube(coord: Vector3i, open: Dictionary) -> void:
	for n: Vector3i in ShipGrid.FACE_OFFSETS:
		if not open.has(n):
			continue
		var b := face_basis(n)
		var x := _round(b.x)
		var y := _round(b.y)
		var lo := Vector2(-HALF_CELL, -HALF_CELL)
		var hi := Vector2(HALF_CELL, HALF_CELL)
		if open.has(-x):
			lo.x += CHAMFER
		if open.has(x):
			hi.x -= CHAMFER
		if open.has(-y):
			lo.y += CHAMFER
		if open.has(y):
			hi.y -= CHAMFER
		plates.append({"coord": coord, "normal": n, "lo": lo, "hi": hi})
	var faces := ShipGrid.FACE_OFFSETS
	for i in faces.size():
		for j in range(i + 1, faces.size()):
			var a: Vector3i = faces[i]
			var b: Vector3i = faces[j]
			if a + b == Vector3i.ZERO or not open.has(a) or not open.has(b):
				continue
			var axis := _cross(a, b)
			var ends: Array[StringName] = []
			for s in [-1, 1]:
				var along: Vector3i = axis * s
				if open.has(along):
					ends.append(&"corner")
				elif _edge_continues(coord + along, a, b):
					ends.append(&"through")
				else:
					ends.append(&"cap")
			edges.append({"coord": coord, "a": a, "b": b, "axis": axis, "ends": ends, "running": false})
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				if open.has(Vector3i(sx, 0, 0)) and open.has(Vector3i(0, sy, 0)) and open.has(Vector3i(0, 0, sz)):
					corners.append({"coord": coord, "sign": Vector3i(sx, sy, sz)})

## A chamfer runs on into the next cell if that cell is a cube with both the
## same faces open.
func _edge_continues(other: Vector3i, a: Vector3i, b: Vector3i) -> bool:
	return skin.has(other) and skin[other].has(a) and skin[other].has(b)

## Engines and RCS get their bell or pod on the face their exhaust leaves by:
## the face opposite their push (RcsShow's convention), if it is open.
func _plan_nozzles() -> void:
	for coord: Vector3i in _sorted_cells():
		var inst := _grid.get_block(coord)
		if inst.block_id != &"thruster" and inst.block_id != RcsShow.BLOCK_ID:
			continue
		var exhaust := _round(BlockOrientation.basis_for(inst.orientation) * Vector3.BACK)
		if skin.has(coord) and skin[coord].has(exhaust):
			nozzles.append({"coord": coord, "normal": exhaust, "kind": inst.block_id})

static func _round(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x), roundi(v.y), roundi(v.z))

static func _cross(a: Vector3i, b: Vector3i) -> Vector3i:
	return Vector3i(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
```

`HullLayout` needs `HullProps.CHAMFER`. Create a stub `src/ship/hull/hull_props.gd` now; Task 3 fills it in:

```gdscript
class_name HullProps
extends RefCounted

## The hull's outside, piece by piece (ship exterior spec §3.3). Filled in by
## Task 3.

const CHAMFER := 0.4
```

- [ ] **Step 4: Import and run the test**

Run: `& $GODOT --headless --path who-knows --import`, then `who-knows/run_tests.ps1 -gselect=test_hull_layout`
Expected: PASS, 11 tests.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/hull/ who-knows/test/unit/test_hull_layout.gd
git commit -m "feat: HullLayout -- the skin: plates, chamfers, corners, facets, nozzles

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The kit, palette, materials and the skin's props

**Files:**
- Modify: `src/ship/interior/interior_kit.gd` (enum `Batch`, `BATCH_NAMES`, `commit()`)
- Modify: `src/ship/hull_palette.gd`
- Create: `src/ship/hull/hull_materials.gd`
- Replace the stub: `src/ship/hull/hull_props.gd`
- Modify: `test/unit/test_visual_style_rules.gd`, adding the new files to both lists
- Test: `test/unit/test_interior_kit.gd` (append), `test/unit/test_hull_props.gd`

**Interfaces:**
- Produces:
  - **The kit:**
    - `InteriorKit.Batch.HULL`, the livery batch, whose default material is `InteriorMaterials.props()`;
    - `InteriorKit.materials: Dictionary`, mapping a `Batch` to a `Material`, which overrides that batch's material at `commit()`.
  - **`HullPalette`:** `PLATE`, `TRIM`, `WINDOW_GLASS`, `WINDOW_LIGHT`, `WORK_LIGHT_WARM`, `WORK_LIGHT_COOL`, `WORK_LIGHT`, `NOZZLE_DARK`.
  - **`HullMaterials`:** `livery()`, `trim()`, `window_glass()`, `glow_instance(energy)`, `beam(colour)`, and the constants `WINDOW_ENERGY` and `BEAM_ALPHA`.
  - **`HullProps` constants:** `CHAMFER`, `PLATE_PROUD`, `PLATE_BEVEL`, `PLATE_GAP`, `RUNNING_WIDTH`.
  - **`HullProps` builders:**
    - `plate(kit, f, size: Vector2)`;
    - `chamfer_strip(kit, f, from: float, to: float, cap_from: bool, cap_to: bool)`;
    - `corner_facet(kit, f)`;
    - `facet(kit, f, points: PackedVector3Array, normal: Vector3)`;
    - `thruster_bell(kit, f)`, `rcs_pod(kit, f)`;
    - `running_strip(kit, f, from: float, to: float)`.

- [ ] **Step 1: Write the failing tests**

Append to `test/unit/test_interior_kit.gd`:

```gdscript
## Ship exterior spec §3.3: the hull builds with the kit, with the livery for
## its plates and its own trim material.
func test_a_batch_s_material_can_be_overridden_and_there_is_a_hull_batch():
	var trim := StandardMaterial3D.new()
	_kit.materials = {InteriorKit.Batch.SOLID: trim}
	_kit.box(InteriorKit.Batch.SOLID, Transform3D.IDENTITY, Vector3.ONE, Color.WHITE)
	_kit.box(InteriorKit.Batch.HULL, Transform3D.IDENTITY, Vector3.ONE, Color.WHITE)
	var by_name := {}
	for mi in _kit.commit():
		by_name[String(mi.name)] = mi
	assert_eq(by_name["DressingSolid"].material_override, trim)
	assert_eq(by_name["DressingHull"].material_override, InteriorMaterials.props(), "the hull batch's default")
```

Create `test/unit/test_hull_props.gd`:

```gdscript
extends GutTest

## Ship exterior spec §3.3: the skin's pieces build from a kit and a frame
## alone, wound so they face out.

var _root: Node3D
var _kit: InteriorKit

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)
	_kit = InteriorKit.new(_root)

## Godot's front face is clockwise seen from the front, so each triangle's
## winding normal must point away from the normal it carries (InteriorKit.tri).
func _faces_out(mesh: Mesh) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0, v.size(), 3):
		if (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(n[i]) > 0.0001:
			return false
	return true

func _triangles(mesh: Mesh) -> int:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3

func _commit() -> Dictionary:
	var out := {}
	for mi in _kit.commit():
		out[String(mi.name)] = mi.mesh
		assert_true(_faces_out(mi.mesh), "%s faces out" % mi.name)
	return out

func test_a_plate_is_a_seam_and_a_proud_panel():
	HullProps.plate(_kit, Transform3D.IDENTITY, Vector2(1.2, 1.2))
	var made := _commit()
	assert_true(made.has("DressingSolid"), "the seam colour behind")
	assert_true(made.has("DressingHull"), "the livery panel in front")
	var aabb: AABB = made["DressingHull"].get_aabb()
	assert_almost_eq(aabb.end.z, HullProps.PLATE_PROUD, 0.0001, "it stands proud by PLATE_PROUD")
	assert_almost_eq(aabb.size.x, 1.2 - HullProps.PLATE_GAP, 0.0001, "the gap between plates is the panel line")

func test_a_chamfer_is_one_quad_and_a_triangle_per_cap():
	HullProps.chamfer_strip(_kit, Transform3D.IDENTITY, -1.0, 0.6, true, false)
	assert_eq(_triangles(_commit()["DressingHull"]), 3)

func test_a_corner_is_one_triangle_facing_out_of_the_corner():
	HullProps.corner_facet(_kit, Transform3D.IDENTITY)
	var mesh: Mesh = _commit()["DressingHull"]
	assert_eq(_triangles(mesh), 1)
	var n: Vector3 = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
	assert_almost_eq(n, Vector3.ONE.normalized(), Vector3.ONE * 0.0001)

func test_a_facet_on_a_quad_gets_a_proud_panel_and_on_a_triangle_lies_flat():
	var quad := PackedVector3Array([Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)])
	HullProps.facet(_kit, Transform3D.IDENTITY, quad, Vector3(0, 1, -1).normalized())
	var made := _commit()
	assert_eq(_triangles(made["DressingSolid"]), 2, "the seam under it")
	assert_eq(_triangles(made["DressingHull"]), 10, "the panel and its four sides")
	var tri := PackedVector3Array([Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1)])
	HullProps.facet(_kit, Transform3D.IDENTITY, tri, Vector3.RIGHT)
	assert_eq(_triangles(_commit()["DressingHull"]), 1)

func test_bells_pods_and_strips_build_in_a_bare_frame():
	HullProps.thruster_bell(_kit, Transform3D.IDENTITY)
	HullProps.rcs_pod(_kit, InteriorKit.at(Vector3(3, 0, 0)))
	HullProps.running_strip(_kit, InteriorKit.at(Vector3(6, 0, 0)), -1.0, 1.0)
	var made := _commit()
	assert_true(made.has("DressingSolid"))
	assert_true(made.has("DressingGlow"), "the bell's ring and the strip glow")

func test_the_materials_are_engine_materials():
	assert_true(HullMaterials.trim() is StandardMaterial3D)
	assert_true(HullMaterials.window_glass() is StandardMaterial3D)
	assert_eq(HullMaterials.livery(), Ship.HULL_LIVERY_MATERIAL, "the livery the hull always had")
	var a := HullMaterials.glow_instance(1.0)
	var b := HullMaterials.glow_instance(1.0)
	assert_ne(a, b, "each glow instance dims on its own")
	assert_eq(a.shader, InteriorMaterials.GLOW_SHADER, "the glow shader, not a new one")
	var beam := HullMaterials.beam(HullPalette.WORK_LIGHT)
	assert_eq(beam.blend_mode, BaseMaterial3D.BLEND_MODE_ADD)
	assert_true(beam.proximity_fade_enabled)
```

In `test/unit/test_visual_style_rules.gd`:
- add `"res://src/ship/hull/hull_props.gd"`, `"res://src/ship/hull/hull_materials.gd"` and `"res://src/ship/hull/hull_layout.gd"` to `PAINTING_FILES`;
- add `"res://src/ship/hull/hull_props.gd"` and `"res://src/ship/hull/hull_materials.gd"` to `REUSABLE_FILES`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `who-knows/run_tests.ps1 -gselect=test_hull_props`, then `-gselect=test_interior_kit`
Expected: FAIL: `HullProps.plate` is not found, and `Batch.HULL` is not declared.

- [ ] **Step 3: Extend `InteriorKit`**

In `src/ship/interior/interior_kit.gd`, change the batch enum, the names and the doc:

```gdscript
## One merged mesh per batch, each with its own material. PORTAL is window
## glass that shows the real view outside; its material is supplied by
## whoever owns that view (InteriorDressing.portal_material). HULL is the
## hull's outside plating (ship exterior spec §3.3), whose builder gives it
## the livery through `materials`.
enum Batch { SOLID, GLOW, SCREEN, GLASS, PORTAL, HULL }
const BATCH_NAMES := ["DressingSolid", "DressingGlow", "DressingScreens", "DressingGlass",
	"DressingPortals", "DressingHull"]
```

Add under `var portal_material: Material`:

```gdscript
## Per-batch materials that replace the defaults at commit(): the hull builds
## its plating in the livery and its trim a little glossier than a cabin's.
var materials: Dictionary = {}   # Batch -> Material
```

Replace the body of `commit()`:

```gdscript
func commit() -> Array[MeshInstance3D]:
	var defaults: Array[Material] = [InteriorMaterials.props(), InteriorMaterials.glow(),
		InteriorMaterials.screen(), InteriorMaterials.glass(),
		portal_material if portal_material != null else InteriorMaterials.portal_fallback(),
		InteriorMaterials.props()]
	var out: Array[MeshInstance3D] = []
	for batch: int in _tools:
		var st: SurfaceTool = _tools[batch]
		out.append(add_mesh(st.commit(), materials.get(batch, defaults[batch]), BATCH_NAMES[batch]))
	_tools.clear()
	return out
```

- [ ] **Step 4: Add the hull's colours to `src/ship/hull_palette.gd`**

Append:

```gdscript
## The plate colour where no livery draws it: the livery's own hull colour
## (data/materials/hull_livery.tres), for flat-shaded pieces and the miniature.
const PLATE := Color("d6d2c4")
## Frames, bezels, bells and housings: a cream a little lighter than the plate.
const TRIM := Color("ede3d0")
## Window glass seen from outside (ship exterior spec §5.1): dark amber.
const WINDOW_GLASS := Color("3b2a1c")
## The lit bands behind the glass: the cabin's own warm light.
const WINDOW_LIGHT := InteriorPalette.LIGHT_WARM
## The work lights (spec §6.2). Both are built for the renders; the owner
## chooses one, and the other is deleted.
const WORK_LIGHT_WARM := Color("ffe9cc")
const WORK_LIGHT_COOL := Color("e4eeff")
const WORK_LIGHT := WORK_LIGHT_WARM
## The dark throat of a bell or a nozzle, and a lens that is off.
const NOZZLE_DARK := Color("2a2a2e")
```

- [ ] **Step 5: Write `src/ship/hull/hull_materials.gd`**

```gdscript
class_name HullMaterials
extends RefCounted

## The hull's outside materials (ship exterior spec §3.3, §5.1, §6.4). Engine
## materials and new instances of the interior's glow shader; no new shader
## (style guide §2.5).

const LIVERY: ShaderMaterial = preload("res://data/materials/hull_livery.tres")
## The windows' glow at full power, as glow.gdshader's energy.
const WINDOW_ENERGY := 2.4
## A beam's strength at the lens, before it fades along its length.
const BEAM_ALPHA := 0.06

static var _cache: Dictionary = {}

## The plating: the livery the hull has always had, stripe and all.
static func livery() -> ShaderMaterial:
	return LIVERY

## Trim, frames, bells and housings: flat vertex colour, a little glossier
## than a cabin's, no rim.
static func trim() -> StandardMaterial3D:
	if not _cache.has(&"trim"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.6
		_cache[&"trim"] = m
	return _cache[&"trim"]

## Window glass from outside: opaque, glossy, coloured by the vertices.
static func window_glass() -> StandardMaterial3D:
	if not _cache.has(&"window_glass"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.15
		m.metallic = 0.3
		_cache[&"window_glass"] = m
	return _cache[&"window_glass"]

## A glow material of its own, so its energy can change alone: a ship's
## windows, or one light group's lenses.
static func glow_instance(energy: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = InteriorMaterials.GLOW_SHADER
	m.set_shader_parameter(&"energy", energy)
	return m

## A light's beam (spec §6.4): added light, unshaded, fading from the lens
## (v = 1) to nothing (v = 0), and softly wherever it meets rock or hull.
static func beam(colour: Color) -> StandardMaterial3D:
	var key := "beam:%s" % colour.to_html()
	if not _cache.has(key):
		var clear := colour
		clear.a = 0.0
		var full := colour
		full.a = 1.0
		var gradient := Gradient.new()
		gradient.set_color(0, clear)
		gradient.set_color(1, full)
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
		tex.width = 4
		tex.height = 64
		var tint := colour
		tint.a = BEAM_ALPHA
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = tint
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 4.0
		# Near opaque, far gone: min above max fades out with distance.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = 400.0
		m.distance_fade_max_distance = 150.0
		_cache[key] = m
	return _cache[key]
```

- [ ] **Step 6: Write the skin's pieces into `src/ship/hull/hull_props.gd`**

Replace the stub with:

```gdscript
class_name HullProps
extends RefCounted

## The hull's outside, piece by piece (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §3.3): plates, chamfers, corner facets,
## the faces of shaped blocks, bells, RCS pods, running strips, and (later
## tasks) windows, the pod shell, light fixtures and beams. Each builds from a
## kit, a frame and plain values, and never sees the grid: HullDressing
## decides where.
##
## The skin frame: origin on the surface, +z out of the hull, +y up the face
## (toward the bow on a roof or belly), +x across. Plating goes in the HULL
## batch (the livery), trim and seams in SOLID, anything lit in GLOW.

const HULL := InteriorKit.Batch.HULL
const SOLID := InteriorKit.Batch.SOLID
const GLOW := InteriorKit.Batch.GLOW
const GLASS := InteriorKit.Batch.GLASS

## The skin's numbers (spec §3.2).
const CHAMFER := 0.4
const PLATE_PROUD := 0.05
const PLATE_BEVEL := 0.04
const PLATE_GAP := 0.04
## A running strip's width across its chamfer (spec §5.4).
const RUNNING_WIDTH := 0.06

static func _at(offset: Vector3) -> Transform3D:
	return InteriorKit.at(offset)

static func _plate_colour() -> Color:
	return InteriorKit.solid(HullPalette.PLATE)

static func _seam() -> Color:
	return InteriorKit.solid(HullPalette.PANEL_LINE)

static func _trim() -> Color:
	return InteriorKit.solid(HullPalette.TRIM)

static func _dark() -> Color:
	return InteriorKit.solid(HullPalette.NOZZLE_DARK)

## One face's plate, `size` across, centred on the frame: the seam colour
## flush on the face, and a bevelled panel standing PLATE_PROUD in front of it,
## PLATE_GAP smaller, so the seam shows round it as a panel line.
static func plate(kit: InteriorKit, f: Transform3D, size: Vector2) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var n := (f.basis * Vector3.BACK).normalized()
	kit.quad(SOLID, f * Vector3(-hx, -hy, 0), f * Vector3(hx, -hy, 0), f * Vector3(hx, hy, 0),
		f * Vector3(-hx, hy, 0), n, _seam())
	var panel := Vector3(maxf(size.x - PLATE_GAP, 0.01), maxf(size.y - PLATE_GAP, 0.01), PLATE_PROUD * 2.0)
	kit.bevel_box(HULL, f, panel, PLATE_BEVEL, _plate_colour())

## A chamfer along a convex edge, in an edge frame: +x along the edge, +y and
## +z the two faces' normals, the solid where y and z are negative. It runs
## from `from` to `to`; a capped end closes the notch against a neighbour that
## is not chamfered.
static func chamfer_strip(kit: InteriorKit, f: Transform3D, from: float, to: float, cap_from: bool,
		cap_to: bool) -> void:
	var a0 := f * Vector3(from, 0, -CHAMFER)
	var a1 := f * Vector3(to, 0, -CHAMFER)
	var b1 := f * Vector3(to, -CHAMFER, 0)
	var b0 := f * Vector3(from, -CHAMFER, 0)
	kit.quad(HULL, a0, a1, b1, b0, (f.basis * Vector3(0, 1, 1)).normalized(), _plate_colour())
	if cap_from:
		kit.tri(HULL, a0, b0, f * Vector3(from, 0, 0), (f.basis * Vector3.RIGHT).normalized(), _plate_colour())
	if cap_to:
		kit.tri(HULL, a1, b1, f * Vector3(to, 0, 0), (f.basis * Vector3.LEFT).normalized(), _plate_colour())

## Where three chamfers meet, in a corner frame: each axis along one open
## face's normal, the solid where all three are negative.
static func corner_facet(kit: InteriorKit, f: Transform3D) -> void:
	kit.tri(HULL, f * Vector3(0, -CHAMFER, -CHAMFER), f * Vector3(-CHAMFER, 0, -CHAMFER),
		f * Vector3(-CHAMFER, -CHAMFER, 0), (f.basis * Vector3.ONE).normalized(), _plate_colour())

## One face of a shaped block, in the block's cell frame, `points` round it.
## A four-sided face (a slope) gets a seam and a proud panel like a cube's
## plate; a triangle lies flat in the livery.
static func facet(kit: InteriorKit, f: Transform3D, points: PackedVector3Array, normal: Vector3) -> void:
	var n := (f.basis * normal).normalized()
	var p := PackedVector3Array()
	for q in points:
		p.append(f * q)
	if p.size() != 4:
		for i in range(1, p.size() - 1):
			kit.tri(HULL, p[0], p[i], p[i + 1], n, _plate_colour())
		return
	kit.quad(SOLID, p[0], p[1], p[2], p[3], n, _seam())
	var centre := (p[0] + p[1] + p[2] + p[3]) * 0.25
	var top := PackedVector3Array()
	var foot := PackedVector3Array()
	for q in p:
		var inset := q + (centre - q).normalized() * PLATE_GAP
		foot.append(inset)
		top.append(inset + n * PLATE_PROUD)
	kit.quad(HULL, top[0], top[1], top[2], top[3], n, _plate_colour())
	for i in 4:
		var j := (i + 1) % 4
		var side := ((top[i] + top[j]) * 0.5 - (centre + n * PLATE_PROUD)).normalized()
		kit.quad(HULL, foot[i], foot[j], top[j], top[i], side, _plate_colour())

## A main engine's bell on its exhaust face: a chunky ring with a dark throat
## and a cyan glow ring inside, like the old thruster mesh.
static func thruster_bell(kit: InteriorKit, f: Transform3D) -> void:
	kit.ring(SOLID, f, 0.62, 0.8, -0.05, 0.5, _trim())
	kit.disc(SOLID, f * _at(Vector3(0, 0, 0.06)), 0.62, _dark())
	kit.annulus(GLOW, f * _at(Vector3(0, 0, 0.08)), 0.3, 0.42, InteriorKit.lit(HullPalette.RUNNING_LIGHT, 1.4))

## An RCS block's pod on its exhaust face: a bevelled block with one round
## nozzle, where RcsShow's puffs come from.
static func rcs_pod(kit: InteriorKit, f: Transform3D) -> void:
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0, 0.1)), Vector3(0.9, 0.9, 0.2), 0.06, _trim())
	kit.ring(SOLID, f * _at(Vector3(0, 0, 0.2)), 0.16, 0.26, 0.0, 0.14, _trim())
	kit.disc(SOLID, f * _at(Vector3(0, 0, 0.21)), 0.16, _dark())

## A cyan running strip along the middle of a chamfer (spec §5.4), in the
## chamfer's edge frame, from `from` to `to`. Glow only: it lights nothing.
static func running_strip(kit: InteriorKit, f: Transform3D, from: float, to: float) -> void:
	var out := Vector3(0, 1, 1).normalized()
	var basis := Basis(Vector3.RIGHT, out.cross(Vector3.RIGHT), out)
	var at := Vector3((from + to) * 0.5, -CHAMFER * 0.5, -CHAMFER * 0.5) + out * 0.012
	kit.box(GLOW, f * Transform3D(basis, at), Vector3(maxf(to - from - 0.1, 0.05), RUNNING_WIDTH, 0.02),
		InteriorKit.lit(HullPalette.RUNNING_LIGHT, 2.2))
```

- [ ] **Step 7: Import and run the tests**

Run: `& $GODOT --headless --path who-knows --import`, then the three files: `-gselect=test_hull_props`, `-gselect=test_interior_kit`, `-gselect=test_visual_style_rules`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add who-knows/src/ship/interior/interior_kit.gd who-knows/src/ship/hull_palette.gd who-knows/src/ship/hull/ who-knows/test/unit/test_interior_kit.gd who-knows/test/unit/test_hull_props.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: the hull's props -- plates, chamfers, facets, bells, pods and strips

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: HullDressing, and the skin replaces the block meshes

**Files:**
- Create: `src/ship/hull/hull_dressing.gd`
- Modify: `src/ship/exterior_builder.gd`, whose mesh code is replaced; the colliders and alcoves stay
- Modify: `src/ship/computer/holo_volume.gd` (`show_miniature`, `miniature_meshes`)
- Modify: `src/ship/computer/status_page.gd`, line 45
- Modify: `test/unit/test_exterior_builder.gd`, `test/unit/test_bridge_computer_scene.gd`, `test/unit/test_holo_volume.gd`
- Modify: `test/unit/test_visual_style_rules.gd`, adding `hull_dressing.gd` to `PAINTING_FILES`
- Modify: `.claude/skills/building-a-ship/ship_probe.gd`, adding hull renders

**Interfaces:**
- Consumes: `HullLayout` (Task 2), and `HullProps` and `HullMaterials` (Task 3).
- Produces:
  - `HullDressing.build(layout: HullLayout, root: Node3D) -> Dictionary`, with keys `meshes: Array[Mesh]`, `lenses: Dictionary`, `window_glow: ShaderMaterial` (null until Task 7);
  - on `ExteriorBuilder`: `layout() -> HullLayout`, `hull_meshes() -> Array[Mesh]`, `lenses() -> Dictionary`, `window_glow() -> ShaderMaterial` and `light_mounts() -> Array[Dictionary]`;
  - `HoloVolume.show_miniature(meshes: Array[Mesh], bounds: AABB)` and `miniature_meshes() -> Array[Mesh]`.

- [ ] **Step 1: Update the tests to the new skin (they fail first)**

In `test/unit/test_exterior_builder.gd`:

1. In `test_rebuild_does_not_leave_stale_nodes_in_the_tree`, replace the MultiMesh count at the end:

```gdscript
	var skins := _builder.get_children().filter(func(c): return c.name == "Skin")
	assert_eq(skins.size(), 1, "stale skins must be fully detached, not merely queued")
```

2. Replace `test_hull_meshes_are_drawn_on_the_own_hull_layer`:

```gdscript
func test_hull_meshes_are_drawn_on_the_own_hull_layer():
	_put(Vector3i.ZERO, &"hull")
	_builder.rebuild()
	var drawn := _builder.find_children("*", "GeometryInstance3D", true, false)
	assert_gt(drawn.size(), 0)
	for g in drawn:
		assert_eq(g.layers, ExteriorBuilder.OWN_HULL_LAYER, "%s" % g.name)
	assert_gt(_builder.hull_meshes().size(), 0, "the plating and trim, for the miniature")

## Ship exterior spec §3.3: the skin casts the sun's shadows, as the block
## meshes did.
func test_the_skin_casts_shadows():
	_put(Vector3i.ZERO, &"hull")
	_builder.rebuild()
	for mi in _builder.get_node("Skin").find_children("*", "MeshInstance3D", true, false):
		if mi.name == "DressingHull" or mi.name == "DressingSolid":
			assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "%s" % mi.name)
```

3. In `test_an_airlock_is_an_open_alcove`, replace the `airlock_drawn` loop and assert:

```gdscript
	assert_false(_builder.layout().skin.has(Vector3i.ZERO), "the skin leaves the alcove's cell to the alcove")
```

In `test/unit/test_bridge_computer_scene.gd`, replace every `exterior_builder.multimeshes()` with `exterior_builder.hull_meshes()`. Rename the loop variable `mm` to `mesh`.

In `test/unit/test_holo_volume.gd`, replace `test_the_miniature_shares_the_meshes_it_is_given`:

```gdscript
## Spec §7.1: the miniature shares the hull's meshes rather than copying them,
## and is sized so its longest side is 0.8 m.
func test_the_miniature_shares_the_meshes_it_is_given():
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 1, 9)
	var meshes: Array[Mesh] = [mesh]
	var bounds := AABB(Vector3(-0.5, -0.5, -4.5), Vector3(1, 1, 9))
	_holo.show_miniature(meshes, bounds)
	assert_true(_holo.miniature_shown())
	assert_eq(_holo.miniature_meshes()[0], mesh, "the same resource, not a copy")
	var drawn := _holo.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.mesh == mesh)
	assert_eq(drawn.size(), 1)
	var inst: MeshInstance3D = drawn[0]
	assert_eq(inst.material_override, InteriorMaterials.holo())
	assert_eq(inst.layers, InteriorKit.LAYER)
	var longest: float = bounds.size.z * (inst.get_parent() as Node3D).scale.z
	assert_almost_eq(longest, HoloVolume.MINIATURE_SIZE, 0.001)
	_holo._process(1.0)
	assert_almost_eq((inst.get_parent().get_parent() as Node3D).rotation.y, HoloVolume.SPIN, 0.0001, "it turns")
	_holo.clear_miniature()
	assert_false(_holo.miniature_shown())
	assert_eq(_holo.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.mesh == mesh).size(), 0)
```

Add `"res://src/ship/hull/hull_dressing.gd"` to `PAINTING_FILES` in `test_visual_style_rules.gd`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `who-knows/run_tests.ps1 -gselect=test_exterior_builder`
Expected: FAIL: `hull_meshes()` and `layout()` are not found.

- [ ] **Step 3: Write `src/ship/hull/hull_dressing.gd`**

```gdscript
class_name HullDressing
extends RefCounted

## Turns a HullLayout into geometry (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §3.3): works out each record's frame and
## asks HullProps for the piece. The only place that decides which hull prop
## goes where.
##
## Each kit gets a child node of `root`, so their merged meshes keep their
## batch names: Skin/Hull/DressingHull is the plating, and so on.

## Builds everything under `root`. Returns the plating and trim meshes (for
## the miniature), each light group's lens glow, and the windows' glow material.
static func build(layout: HullLayout, root: Node3D) -> Dictionary:
	var skin := _kit(root, "Hull")
	skin.materials = {InteriorKit.Batch.HULL: HullMaterials.livery(), InteriorKit.Batch.SOLID: HullMaterials.trim()}
	for p in layout.plates:
		var lo: Vector2 = p["lo"]
		var hi: Vector2 = p["hi"]
		var mid := (lo + hi) * 0.5
		HullProps.plate(skin, HullLayout.face_frame(p["coord"], p["normal"]) * InteriorKit.at(Vector3(mid.x, mid.y, 0)),
			hi - lo)
	for e in layout.edges:
		var f := HullLayout.edge_frame(e)
		var span := HullLayout.edge_span(e)
		var ends: Array = e["ends"]
		HullProps.chamfer_strip(skin, f, span.x, span.y, ends[0] == &"cap", ends[1] == &"cap")
		if e["running"]:
			HullProps.running_strip(skin, f, span.x, span.y)
	for c in layout.corners:
		HullProps.corner_facet(skin, HullLayout.corner_frame(c))
	for fc in layout.facets:
		var face := HullLayout.facet_face(fc)
		HullProps.facet(skin, HullLayout.cell_frame(fc["coord"], fc["orientation"]), face["points"], face["normal"])
	for n in layout.nozzles:
		var f := HullLayout.face_frame(n["coord"], n["normal"])
		if n["kind"] == &"thruster":
			HullProps.thruster_bell(skin, f)
		else:
			HullProps.rcs_pod(skin, f)
	var meshes: Array[Mesh] = []
	for mi in skin.commit():
		if mi.name == InteriorKit.BATCH_NAMES[InteriorKit.Batch.HULL] \
				or mi.name == InteriorKit.BATCH_NAMES[InteriorKit.Batch.SOLID]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			meshes.append(mi.mesh)
	return {"meshes": meshes, "lenses": {}, "window_glow": null}

## A kit on the hull's own layer, under a child of `root` named `kit_name`.
static func _kit(root: Node3D, kit_name: String) -> InteriorKit:
	var node := Node3D.new()
	node.name = kit_name
	root.add_child(node)
	var kit := InteriorKit.new(node)
	kit.layer = ExteriorBuilder.OWN_HULL_LAYER
	kit.light_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	return kit
```

- [ ] **Step 4: Switch `ExteriorBuilder` to the skin**

In `src/ship/exterior_builder.gd`:
- replace the class doc;
- replace `var _multimeshes` with the new fields;
- replace `rebuild`, the MultiMesh part of `_clear`, `multimeshes()`, `bounds()` and `_build_meshes()`.

The final file's changed parts:

```gdscript
class_name ExteriorBuilder
extends Node3D

## Reads a ShipGrid and produces the flying hull: a skin generated over the
## grid (docs/superpowers/specs/2026-09-28-ship-exterior-design.md §3) --
## HullLayout decides it, HullDressing draws it as a few merged meshes -- and
## one collider per occupied cell.
##
## This never references InteriorBuilder. Both are independent readers of the
## same source of truth, which is what makes the parity test honest. The skin
## reads the interior's *layout*, which is pure data from the grid, so every
## window outside matches one inside.
```

The fields, in place of `var _multimeshes`:

```gdscript
var _layout: HullLayout
var _skin: Node3D
var _meshes: Array[Mesh] = []
var _lenses: Dictionary = {}   # StringName group -> MeshInstance3D
var _window_glow: ShaderMaterial
```

`rebuild`:

```gdscript
func rebuild() -> void:
	_clear()
	if _grid == null or _catalog == null:
		return
	var walkable := DeckGraph.build(_grid, _catalog).walkable_coords()
	_layout = HullLayout.plan(_grid, _catalog, InteriorLayout.plan(_grid, _catalog, walkable))
	_build_colliders()
	_build_skin()

## What the skin was made from, for the lights, the probe and tests.
func layout() -> HullLayout:
	return _layout

## The hull's plating and trim, for the bridge computer's miniature (bridge
## computer spec §7.1), which shares them rather than copying.
func hull_meshes() -> Array[Mesh]:
	return _meshes.duplicate()

## Each light group's lens glow (spec §6.1), by group.
func lenses() -> Dictionary:
	return _lenses.duplicate()

## The windows' glow material (spec §5.1): ShipLights sets its energy.
func window_glow() -> ShaderMaterial:
	return _window_glow

## Where the lights go (spec §6.1).
func light_mounts() -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	return _layout.mounts.duplicate() if _layout != null else none

func _build_skin() -> void:
	_skin = Node3D.new()
	_skin.name = "Skin"
	add_child(_skin)
	var made := HullDressing.build(_layout, _skin)
	_meshes.assign(made["meshes"])
	_lenses = made["lenses"]
	_window_glow = made["window_glow"]
```

In `_clear()`, replace the MultiMesh loop with:

```gdscript
	if is_instance_valid(_skin):
		remove_child(_skin)
		_skin.free()
	_skin = null
	_meshes.clear()
	_lenses = {}
	_window_glow = null
	_layout = null
```

`bounds()`: every cell except alcoves now draws:

```gdscript
## Everything the hull draws, in its own frame: the cells its skin covers.
## From the grid rather than the meshes' AABBs, which only a renderer can work
## out.
func bounds() -> AABB:
	var box := AABB()
	var first := true
	if _grid == null:
		return box
	var half := Vector3.ONE * ShipGrid.CELL_SIZE * 0.5
	for coord in _grid.coords():
		if _is_alcove(coord):
			continue
		var cell := AABB(ShipGrid.cell_center(coord) - half, half * 2.0)
		box = cell if first else box.merge(cell)
		first = false
	return box
```

Delete `multimeshes()` and `_build_meshes()`.

- [ ] **Step 5: The miniature takes `Mesh`es**

In `src/ship/computer/holo_volume.gd`:
- change the type of `_mini_meshes` to `Array[Mesh]`;
- change `show_miniature`, where the rest of the function is unchanged:

```gdscript
## The ship in miniature (spec §7.1), from `meshes` shared as they are, and
## `bounds`, everything they draw in their own frame.
func show_miniature(meshes: Array[Mesh], bounds: AABB) -> void:
	...
	for mesh in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = InteriorMaterials.holo()
		mi.layers = layer
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(mi)
	_mini_meshes = meshes.duplicate()

func miniature_meshes() -> Array[Mesh]:
	return _mini_meshes
```

In `src/ship/computer/status_page.gd` line 45, change the call to:

`volume.show_miniature(ctx.exterior_builder.hull_meshes(), ctx.exterior_builder.bounds())`

- [ ] **Step 6: Run the tests, then the full suite**

Run: `who-knows/run_tests.ps1 -gselect=test_exterior_builder`, `-gselect=test_holo_volume` and `-gselect=test_bridge_computer_scene`, then `who-knows/run_tests.ps1`
Expected: all PASS. If another test counted `MultiMeshInstance3D`s under the hull, point it at `Skin` the same way and note it in the task report.

- [ ] **Step 7: Add hull renders to the probe**

In `.claude/skills/building-a-ship/ship_probe.gd`, add this function:

```gdscript
## The hull from outside (ship exterior spec §10): two quarters, the profile,
## above and below, from a camera riding on the hull.
func _hull_shots(ship: Ship, tag: String) -> void:
	var cam := Camera3D.new()
	cam.cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	cam.far = 5000.0
	ship.exterior.add_child(cam)
	var views := {
		"bow_port": Vector3(-14, 6, -18), "stern_starboard": Vector3(14, 6, 18),
		"profile": Vector3(-26, 1, 0), "above": Vector3(0, 28, 4), "below": Vector3(4, -22, 0),
	}
	for view: String in views:
		var at: Vector3 = views[view]
		var up := Vector3.UP if absf(at.normalized().y) < 0.9 else Vector3.FORWARD
		cam.transform = Transform3D(Basis.looking_at(-at, up), at)
		cam.current = true
		await _shot("%s_%s" % [tag, view])
	cam.current = false
	cam.queue_free()
```

Call it in `_run` right after the `pods`/`locks` prints: `await _hull_shots(ship, "hull")`.

- [ ] **Step 8: Render and show the owner (checkpoint 1)**

Run, without `--headless`: `& $GODOT --path who-knows --resolution 1280x720 --script D:/git/whoknows/.claude/skills/building-a-ship/ship_probe.gd -- <absolute scratch dir>`

Check the output for `SHADER ERROR`, and check that fps holds at 120 or more. Send `probe_hull_*.png` to the owner with SendUserFile. The caption should say this is the skin on the unchanged starter, before fairings, windows and lights.

**Stop and wait for the owner's reaction before Task 6.** Task 5 may proceed. If the owner asks for a different chamfer or plate size, change `HullProps` constants only, re-render, and record the value in the spec's §3.2.

- [ ] **Step 9: Commit**

```bash
git add -A who-knows/src who-knows/test .claude/skills/building-a-ship/ship_probe.gd
git commit -m "feat: the hull is a generated skin -- chamfered, panelled, one mesh per material

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Fairing blocks and shaped colliders

**Files:**
- Create: `data/blocks/fairing_slope.tres`, `fairing_slope_long_low.tres`, `fairing_slope_long_high.tres`, `fairing_corner_out.tres`, `fairing_corner_in.tres`, `fairing_half.tres`
- Modify: `src/ship/exterior_builder.gd` (`_build_colliders`)
- Modify: `test/unit/test_block_data.gd` (the count 23 becomes 29, plus a fairing test)
- Test: `test/unit/test_exterior_builder.gd` (append)

**Interfaces:**
- Consumes: `HullShapes.collider_parts`, `HullShapes.shape_of`.
- Produces: six block ids, all `SOLID`, `STRUCTURE`, 0.3 t, 40 hp, no mesh.

- [ ] **Step 1: Write the failing tests**

In `test/unit/test_block_data.gd`, change the count at line 9 from 23 to 29. Add the six ids to the list at line 13, then append:

```gdscript
## Ship exterior spec §4: fairings are light shells, structure not armour.
func test_fairings_are_light_structure():
	for id in [&"fairing_slope", &"fairing_slope_long_low", &"fairing_slope_long_high",
			&"fairing_corner_out", &"fairing_corner_in", &"fairing_half"]:
		var def := _cat.get_def(id)
		assert_not_null(def, "%s is in the catalog" % id)
		assert_eq(def.occupancy, BlockDefinition.Occupancy.SOLID)
		assert_eq(def.category, BlockDefinition.Category.STRUCTURE)
		assert_almost_eq(def.mass_t, 0.3, 0.0001, "%s weighs 0.3 t" % id)
		assert_eq(def.hp, 40)
		assert_eq(def.power_draw, 0.0)
		assert_eq(HullShapes.shape_of(id), HullShapes.BY_ID[id])
```

Append to `test/unit/test_exterior_builder.gd`:

```gdscript
## Ship exterior spec §3.4: a shaped block's collider is its shape, in convex
## pieces; a cube's is still a box.
func test_a_shaped_block_gets_convex_colliders():
	var slope := BlockDefinition.new()
	slope.id = &"fairing_corner_in"
	slope.mass_t = 0.3
	_cat.register(slope)
	_put(Vector3i(2, 0, 0), &"fairing_corner_in")
	_put(Vector3i(0, 0, 0), &"hull")
	_builder.rebuild()
	var convex := _body.get_children().filter(func(c): return c is CollisionShape3D and c.shape is ConvexPolygonShape3D)
	assert_eq(convex.size(), 2, "the inner corner is two slopes")
	for c in convex:
		assert_almost_eq(c.position, ShipGrid.cell_center(Vector3i(2, 0, 0)), Vector3.ONE * 0.0001)
	assert_eq(_box_at(Vector3i.ZERO).size(), 1)
	assert_eq(_builder.collider_coords().size(), 2, "one entry per cell, however many shapes")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `who-knows/run_tests.ps1 -gselect=test_block_data`
Expected: FAIL: 23 ids, not 29.

- [ ] **Step 3: Write the six `.tres` files**

Write each like this one, `data/blocks/fairing_slope.tres`, changing only `id` and `display_name`. **No `#` comments.**

```
[gd_resource type="Resource" script_class="BlockDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ship/block_definition.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"fairing_slope"
display_name = "Fairing Slope"
category = 0
occupancy = 0
mass_t = 0.3
hp = 40
power_gen = 0.0
power_draw = 0.0
thrust_kn = 0.0
grav_radius = 0.0
```

| file | id | display_name |
|---|---|---|
| `fairing_slope.tres` | `&"fairing_slope"` | Fairing Slope |
| `fairing_slope_long_low.tres` | `&"fairing_slope_long_low"` | Fairing Long Slope (Low) |
| `fairing_slope_long_high.tres` | `&"fairing_slope_long_high"` | Fairing Long Slope (High) |
| `fairing_corner_out.tres` | `&"fairing_corner_out"` | Fairing Outer Corner |
| `fairing_corner_in.tres` | `&"fairing_corner_in"` | Fairing Inner Corner |
| `fairing_half.tres` | `&"fairing_half"` | Fairing Half |

- [ ] **Step 4: Give shaped blocks their colliders**

In `ExteriorBuilder._build_colliders()`, replace the box block, the part after the alcove branch:

```gdscript
		var inst := _grid.get_block(coord)
		var shape_name := HullShapes.shape_of(inst.block_id)
		if shape_name == HullShapes.CUBE:
			_add_collider(body, _box_shape(), Transform3D(Basis.IDENTITY, ShipGrid.cell_center(coord)))
		else:
			# Shaped blocks (spec §3.4): their colliders are their shapes, in
			# convex pieces, so rocks and a spacewalker meet what is drawn.
			var frame := HullLayout.cell_frame(coord, inst.orientation)
			for part in HullShapes.collider_parts(shape_name):
				var convex := ConvexPolygonShape3D.new()
				convex.points = part
				_add_collider(body, convex, frame)
		_collider_coords.append(coord)
```

Add the helpers:

```gdscript
func _box_shape() -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * ShipGrid.CELL_SIZE
	return shape

func _add_collider(body: Node, shape: Shape3D, xform: Transform3D) -> void:
	var node := CollisionShape3D.new()
	node.shape = shape
	node.transform = xform
	body.add_child(node)
	_colliders.append(node)
```

- [ ] **Step 5: Read the `.tres` files back at runtime, and run the tests**

Run: `who-knows/run_tests.ps1 -gselect=test_block_data` and `-gselect=test_exterior_builder`
Expected: PASS. `test_fairings_are_light_structure` reads every property back at runtime, which is how CLAUDE.md asks a hand-authored `.tres` to be checked.

- [ ] **Step 6: Run the full suite**

Run: `who-knows/run_tests.ps1`
Expected: PASS. The starter's `hull_wedge` and `canopy` cells now have convex slope colliders, and the pod exception comes in Task 7. If a test measured a hull collision against a nose box, note the change in the task report and fix the test's expectation only if its intent survives. If it doesn't, stop and ask.

- [ ] **Step 7: Commit**

```bash
git add who-knows/data/blocks/fairing_*.tres who-knows/src/ship/exterior_builder.gd who-knows/test/unit/test_block_data.gd who-knows/test/unit/test_exterior_builder.gd
git commit -m "feat: six fairing blocks; shaped blocks collide as they are drawn

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The reshaped starter

**Files:**
- Modify: `scenes/flight_test.gd` (`_starter_grid()`, its constants and its balance comments)
- Test: `test/unit/test_starter_shuttle.gd` (append)

**Interfaces:**
- Consumes: the fairing blocks (Task 5).
- Produces: the starter with 26 fairing cells. Tasks 8 and 12 rely on the keel at y = −1 under x = 0, z = −3..2.

- [ ] **Step 1: Write the failing tests**

Append to `test/unit/test_starter_shuttle.gd`:

```gdscript
const FAIRINGS := [&"fairing_slope", &"fairing_slope_long_low", &"fairing_slope_long_high",
	&"fairing_corner_out", &"fairing_corner_in", &"fairing_half"]

## Ship exterior spec §8: the shape is fairings, all outside the cabin row.
func test_the_shape_is_fairings_outside_the_cabin():
	var n := 0
	var mass := 0.0
	for coord: Vector3i in _grid.coords():
		var id := _grid.get_block(coord).block_id
		if FAIRINGS.has(id):
			n += 1
			mass += _cat.get_def(id).mass_t
			assert_ne(coord.y, 0, "no fairing in the cabin row: %s" % coord)
	assert_eq(n, 26)
	assert_almost_eq(mass, 7.8, 0.0001)

## The building-a-ship reference's test for a new ship (reference.md).
func test_the_reshaped_starter_flies():
	var s := ShipStats.compute(_grid, _cat)
	assert_eq(ShipValidator.validate(_grid, _cat).size(), 0, "zero issues, warnings included")
	assert_gt(s.power_gen, s.power_draw * 1.1, "power with margin")
	assert_gt(s.thrust_budget[&"reverse"], 0.0, "it can brake")
	for axis in 3:
		assert_gt(s.torque_budget[axis], 0.0, "authority both ways on axis %d" % axis)
		assert_lt(absf(s.torque_imbalance[axis]), s.torque_budget[axis] * 0.05, "no fight under burn on axis %d" % axis)

## The reshape must not block any RCS exhaust: today only the down-firing
## pair's faces are open (building-a-ship skill), and they must stay open.
func test_the_reshape_keeps_the_open_rcs_open():
	var open := 0
	for coord: Vector3i in _grid.coords():
		var inst := _grid.get_block(coord)
		if inst.block_id != &"rcs":
			continue
		var out := BlockOrientation.basis_for(inst.orientation) * Vector3.BACK
		if not _grid.has_block(coord + Vector3i(out.round())):
			open += 1
	assert_eq(open, 2)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `who-knows/run_tests.ps1 -gselect=test_starter_shuttle`
Expected: FAIL in `test_the_shape_is_fairings_outside_the_cabin`: 0 fairings, not 26.

- [ ] **Step 3: Add the fairings to `_starter_grid()`**

In `scenes/flight_test.gd`, add a constant beside `O_RCS_DOWN`:

```gdscript
const O_KEEL := 2        ## FORWARD rolled 180 deg: a half block's upper half, hung under a cell
```

At the end of `_starter_grid()`, before `return g`:

```gdscript
	# --- The shape (ship exterior spec §8): fairings, 0.3 t each, all outside
	# the cabin row, so nothing inside moves. A dorsal spine a metre high,
	# ramped up out of the roof toward the bow and down again over the stern
	# bank; a fin rising aft on each engine pod; and a keel under the
	# centreline for the floods to hang from.
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1, 2]:
			_put(g, Vector3i(x, 2, z), &"fairing_half")
		_put(g, Vector3i(x, 2, -2), &"fairing_slope_long_low", O_FORWARD)
		_put(g, Vector3i(x, 2, 3), &"fairing_slope_long_low", O_STERN)
	for x in [-3, 3]:
		_put(g, Vector3i(x, 1, 1), &"fairing_slope", O_FORWARD)
	for z in [-3, -2, -1, 0, 1, 2]:
		_put(g, Vector3i(0, -1, z), &"fairing_half", O_KEEL)
```

- [ ] **Step 4: Run the tests; balance if the flight test fails**

Run: `who-knows/run_tests.ps1 -gselect=test_starter_shuttle`

If `test_the_reshaped_starter_flies` fails on the pitch imbalance (axis 0), the spine has raised the centre of mass. Fix it **by moving fairings, never by weakening the RCS** (building-a-ship skill). Try these in order, re-running after each:
1. Drop the spine's z = 2 row, three `fairing_half` cells. Change `for z in [-1, 0, 1, 2]` to `[-1, 0, 1]`, and move the aft ramp to z = 2.
2. Widen the keel to x = −1..1, adding 12 more `fairing_half` cells at `O_KEEL`.

After any change, update the counts in `test_the_shape_is_fairings_outside_the_cabin` to what you built. Update the spec's §8 in the same commit, with the cells and the reason.

- [ ] **Step 5: Re-measure and write the numbers down**

Run the full suite: `who-knows/run_tests.ps1`. Other tests pin the starter's mass, centre of mass, inertia or feel. When one fails only because the reshape legitimately moved a figure:
- read the new value from `ShipStats.compute`;
- update that pinned number;
- list each change in the task report.

Power must be unchanged, because fairings draw nothing.

Replace the "Real numbers for this exact grid" paragraph in `_starter_grid()`'s comments with the new figures: blocks, mass, centre of mass, inertia, `torque_budget`, `torque_imbalance`, thrust budgets and power. To get them, run the probe or a one-off `print` of `ShipStats.compute`.

- [ ] **Step 5b: Saved games keep their own ship**

A resumed game builds from its saved layout (`Ship.layout_of`), not `_starter_grid()`, so an existing save keeps the flat starter. Do what the spec's §7.1 says the owner decided:

> **Decided (controller ruling, 2026-09-28, pending the owner's word):** saves are left alone; start a new game to fly the reshaped starter. Migrating a saved starter is a small follow-up if the owner wants it.

If migrating, use `SaveGame.migrate`, and bump the format the way that file already does. When a saved layout has no fairing cells and has exactly the old starter's cells, add the 26 fairing cells. Test two things: an old-starter save comes back with 26 fairings, and a save of any other ship is untouched.

- [ ] **Step 6: Render and show the owner (checkpoint 2)**

Run the probe as in Task 4, Step 8. Send the `probe_hull_*` renders and the probe's `feel` lines to the owner, with this caption:

> The reshaped starter: a 1 m dorsal spine ramped at both ends, fins on the pods, and a keel. Compare it with your red sketch.

**Wait for the owner.** If they want the spine or tapers moved, change the cells and repeat Steps 4 and 5. The rules still apply: fairings only, outside the cabin row, RCS exhausts open, balance within 5%.

- [ ] **Step 7: Commit**

```bash
git add who-knows/scenes/flight_test.gd who-knows/test/unit/test_starter_shuttle.gd docs/superpowers/specs/2026-09-28-ship-exterior-design.md
git commit -m "feat: the starter gets a spine, pod fins and a keel -- 26 fairings, balance re-pinned

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Windows, the pod shell and the running strips

**Files:**
- Modify: `src/ship/hull/hull_layout.gd`, adding pods, windows and running marks
- Modify: `src/ship/hull/hull_props.gd`, adding `window_porthole`, `window_rect` and `pod_shell`
- Modify: `src/ship/hull/hull_dressing.gd`, adding the windows kit
- Modify: `src/ship/exterior_builder.gd`, where a pod's cell keeps a box collider
- Test: `test/unit/test_hull_windows.gd`, and `test/unit/test_hull_props.gd` (append)

**Interfaces:**
- Consumes:
  - from `InteriorLayout`: `faces()` records `{coord, normal, kind, porthole}`, `canopy_groups()` records `{normal, coords, pods}` and `pods()` records `{coord, normal}`;
  - `InteriorDressing.pod_frame(coord, normal)`;
  - `InteriorBuilder.floor_y`, `storey_offset`;
  - `InteriorProps.PORTHOLE_HEIGHT`, `PORTHOLE_RADIUS`, `SHOULDER_WINDOW_LOW`, `SHOULDER_WINDOW_HIGH`, `SHOULDER_WINDOW_HALF`, `NOSE_WINDOWS`, `POD_OUTLINE`, `POD_SILL`, `POD_GLASS_TOP`, `POD_ROOF`.
- Produces:
  - `HullLayout.windows`: `{frame: Transform3D, size: Vector2, round: bool, coord: Vector3i}`, where the frame is in hull space, +z out and +y up the face;
  - `HullLayout.pods`: `{frame: Transform3D, cell: Vector3i}`;
  - `HullLayout.is_pod_cell(coord) -> bool`;
  - `HullLayout.unmatched` and `wanted`;
  - `edges[i]["running"]`.

- [ ] **Step 1: Write the failing tests**

Create `test/unit/test_hull_windows.gd`:

```gdscript
extends GutTest

## Ship exterior spec §5: the outside shows what the inside made of it.

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func _starter() -> ShipGrid:
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var g: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	return g

func _layouts(g: ShipGrid) -> Array:
	var interior := InteriorLayout.plan(g, _cat, DeckGraph.build(g, _cat).walkable_coords())
	return [interior, HullLayout.plan(g, _cat, interior)]

func test_every_interior_window_has_one_outside():
	var both := _layouts(_starter())
	var hull: HullLayout = both[1]
	assert_eq(hull.unmatched, [] as Array[Dictionary], "no window inside without one outside")
	assert_gt(hull.wanted, 0)
	assert_eq(hull.windows.size(), hull.wanted)

func test_portholes_sit_where_the_interior_s_do():
	var both := _layouts(_starter())
	var interior: InteriorLayout = both[0]
	var hull: HullLayout = both[1]
	var inside := 0
	for face in interior.faces():
		if face["kind"] == InteriorLayout.Kind.WALL and face["porthole"]:
			inside += 1
	var outside := hull.windows.filter(func(w): return w["round"])
	assert_eq(outside.size(), inside)
	for w in outside:
		var coord: Vector3i = w["coord"]
		var f: Transform3D = w["frame"]
		assert_almost_eq(f.origin.y, InteriorBuilder.floor_y(coord) + InteriorProps.PORTHOLE_HEIGHT, 0.001,
			"a porthole at the interior's height (storey 0)")
		assert_almost_eq(w["size"].x, InteriorProps.PORTHOLE_RADIUS * 2.0, 0.0001)

func test_the_shoulders_are_plate_with_a_window_at_the_interior_s_heights():
	var hull: HullLayout = _layouts(_starter())[1]
	var rects := hull.windows.filter(func(w): return not w["round"])
	assert_eq(rects.size(), 2, "port and starboard shoulders")
	var fl := InteriorBuilder.floor_y(Vector3i(0, 0, -3))
	for w in rects:
		var f: Transform3D = w["frame"]
		var half_rise: float = w["size"].y * 0.5 * f.basis.y.y
		assert_almost_eq(f.origin.y - half_rise, fl + InteriorProps.SHOULDER_WINDOW_LOW, 0.001)
		assert_almost_eq(f.origin.y + half_rise, fl + InteriorProps.SHOULDER_WINDOW_HIGH, 0.001)
		assert_almost_eq(w["size"].x, InteriorProps.SHOULDER_WINDOW_HALF * 2.0, 0.0001)

func test_the_pod_shell_is_the_interior_pod():
	var both := _layouts(_starter())
	var interior: InteriorLayout = both[0]
	var hull: HullLayout = both[1]
	assert_eq(hull.pods.size(), 1)
	var pod: Dictionary = interior.pods()[0]
	var f: Transform3D = hull.pods[0]["frame"]
	assert_eq(f, InteriorDressing.pod_frame(pod["coord"], pod["normal"]), "the same frame, storey 0")
	assert_eq(hull.pods[0]["cell"], pod["coord"] + pod["normal"])
	assert_true(hull.is_pod_cell(pod["coord"] + pod["normal"]))
	assert_false(hull.skin.has(pod["coord"] + pod["normal"]))
	for fc in hull.facets:
		assert_ne(fc["coord"], pod["coord"] + pod["normal"], "the shell draws the pod's cell")

func test_a_nose_without_a_pod_gets_its_windows():
	var g := ShipGrid.new()
	for x in [-1, 0, 1]:
		for spec in [[Vector3i(x, 0, -1), &"canopy"], [Vector3i(x, 0, 0), &"deck"], [Vector3i(x, 1, 0), &"hull"]]:
			var i := BlockInstance.new()
			i.block_id = spec[1]
			g.set_block(spec[0], i)
	var hull: HullLayout = _layouts(g)[1]
	assert_eq(hull.pods.size(), 0)
	assert_eq(hull.unmatched, [] as Array[Dictionary])
	assert_eq(hull.windows.size(), InteriorProps.NOSE_WINDOWS.size() + hull.windows.filter(func(w): return w["round"]).size())

func test_running_strips_mark_the_top_edges():
	var hull: HullLayout = _layouts(_starter())[1]
	var running := hull.edges.filter(func(e): return e["running"])
	assert_gt(running.size(), 0)
	var top := -1000
	for e in hull.edges:
		if (e["a"] == Vector3i.UP or e["b"] == Vector3i.UP) and absi(e["axis"].z) == 1:
			top = maxi(top, e["coord"].y)
	for e in running:
		var along_top: bool = (e["a"] == Vector3i.UP or e["b"] == Vector3i.UP) and absi(e["axis"].z) == 1 \
			and e["coord"].y == top
		var bow: bool = absi(e["axis"].y) == 1 and (e["a"] == Vector3i.FORWARD or e["b"] == Vector3i.FORWARD)
		assert_true(along_top or bow, "a running strip on the top edges or the bow")
```

Append to `test/unit/test_hull_props.gd`:

```gdscript
func test_windows_and_the_pod_shell_build_and_face_out():
	HullProps.window_porthole(_kit, Transform3D.IDENTITY, 0.26)
	HullProps.window_rect(_kit, InteriorKit.at(Vector3(3, 0, 0)), Vector2(1.1, 1.13))
	HullProps.pod_shell(_kit, InteriorKit.at(Vector3(8, 0, 0)))
	var made := _commit()
	assert_true(made.has("DressingGlass"), "the glass")
	assert_true(made.has("DressingGlow"), "the warm bands behind it")
	assert_true(made.has("DressingHull"), "the pod's plating")
	var shell: AABB = made["DressingHull"].get_aabb()
	assert_gt(shell.end.y, InteriorProps.POD_ROOF, "the roof stands over the interior's")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `who-knows/run_tests.ps1 -gselect=test_hull_windows`
Expected: FAIL: `is_pod_cell` is not found, and `windows` is empty.

- [ ] **Step 3: Pods, windows and running strips in `HullLayout`**

In `plan()`, register the pods before the skin, and plan windows and running strips after it:

```gdscript
static func plan(grid: ShipGrid, _catalog: BlockCatalog, interior: InteriorLayout) -> HullLayout:
	var l := HullLayout.new()
	l._grid = grid
	for coord: Vector3i in grid.coords():
		if AirlockSite.hatch_normal(grid, coord) != Vector3i.ZERO:
			l._alcoves[coord] = true
	if interior != null:
		l._plan_pods(interior)
	l._plan_skin()
	l._plan_nozzles()
	if interior != null:
		l._plan_windows(interior)
	l._mark_running()
	return l
```

Add:

```gdscript
func is_pod_cell(coord: Vector3i) -> bool:
	return _pod_cells.has(coord)

## Each cockpit pod (spec §5.2): the pod shell in the interior's own pod frame,
## brought down from its storey into hull space. The skin leaves its canopy
## cell to the shell.
func _plan_pods(interior: InteriorLayout) -> void:
	for pod in interior.pods():
		var coord: Vector3i = pod["coord"]
		var f := InteriorDressing.pod_frame(coord, pod["normal"])
		f.origin.y -= InteriorBuilder.storey_offset(coord.y)
		pods.append({"frame": f, "cell": coord + pod["normal"]})
		_pod_cells[coord + pod["normal"]] = true

## Every window inside gets one outside (spec §5.1): portholes, the
## shoulders beside a pod, and a nose's windows.
func _plan_windows(interior: InteriorLayout) -> void:
	var r := InteriorProps.PORTHOLE_RADIUS
	for face in interior.faces():
		if face["kind"] != InteriorLayout.Kind.WALL or not face["porthole"]:
			continue
		wanted += 1
		var coord: Vector3i = face["coord"]
		var normal: Vector3i = face["normal"]
		var skin_cell := coord
		if _grid.has_block(coord + normal):
			skin_cell = coord + normal
			if _grid.has_block(coord + normal * 2):
				unmatched.append({"coord": coord, "normal": normal})
				continue
		_window_on(skin_cell, coord, normal, InteriorProps.PORTHOLE_HEIGHT - r, InteriorProps.PORTHOLE_HEIGHT + r,
			r * 2.0, true, 0.0)
	for group in interior.canopy_groups():
		var normal: Vector3i = group["normal"]
		var group_pods: Array = group["pods"]
		if group_pods.is_empty():
			_nose_windows(group)
			continue
		for coord: Vector3i in group["coords"]:
			if group_pods.has(coord):
				continue
			wanted += 1
			_window_on(coord + normal, coord, normal, InteriorProps.SHOULDER_WINDOW_LOW,
				InteriorProps.SHOULDER_WINDOW_HIGH, InteriorProps.SHOULDER_WINDOW_HALF * 2.0, false, 0.0)

## A nose's windows (InteriorProps.NOSE_WINDOWS: across, height, half width,
## half height), each on the canopy cell it falls across.
func _nose_windows(group: Dictionary) -> void:
	var normal: Vector3i = group["normal"]
	var across := Vector3.UP.cross(-Vector3(normal))
	var coords: Array = group["coords"]
	var lo := INF
	var hi := -INF
	for c: Vector3i in coords:
		var a := ShipGrid.cell_center(c).dot(across)
		lo = minf(lo, a - HALF_CELL)
		hi = maxf(hi, a + HALF_CELL)
	for w: Vector4 in InteriorProps.NOSE_WINDOWS:
		wanted += 1
		var at := (lo + hi) * 0.5 + w.x
		var placed := false
		for c: Vector3i in coords:
			var a := ShipGrid.cell_center(c).dot(across)
			if absf(at - a) <= HALF_CELL:
				_window_on(c + normal, c, normal, w.y - w.w, w.y + w.w, w.z * 2.0, false, at - a)
				placed = true
				break
		if not placed:
			unmatched.append({"coord": coords[0], "normal": normal})

## One window on `skin_cell`'s face toward `normal`, between `lo` and `hi`
## above `interior_cell`'s floor, `width` across, `shift` along the interior's
## across from the face's centre line. The face may slope: the window's frame
## lies in it, and its size runs up the slope.
func _window_on(skin_cell: Vector3i, interior_cell: Vector3i, normal: Vector3i, lo: float, hi: float,
		width: float, is_round: bool, shift: float) -> void:
	var face := _outer_face(skin_cell, normal)
	if face.is_empty():
		unmatched.append({"coord": interior_cell, "normal": normal})
		return
	var n: Vector3 = face["normal"]
	var up := (Vector3.UP - n * Vector3.UP.dot(n)).normalized()
	var fl := InteriorBuilder.floor_y(interior_cell) - InteriorBuilder.storey_offset(interior_cell.y)
	var mid := fl + (lo + hi) * 0.5
	var p0: Vector3 = face["centre"]
	var centre := p0 + up * ((mid - p0.y) / up.y) + Vector3.UP.cross(-Vector3(normal)) * shift
	windows.append({"frame": Transform3D(Basis(up.cross(n), up, n), centre),
		"size": Vector2(width, (hi - lo) / up.y), "round": is_round, "coord": skin_cell})

## The skin face of `cell` that looks most along `normal`: a cube's own face,
## or the shaped block's face nearest that way. Empty if none shows.
func _outer_face(cell: Vector3i, normal: Vector3i) -> Dictionary:
	if skin.has(cell):
		if skin[cell].has(normal):
			return {"centre": ShipGrid.cell_center(cell) + Vector3(normal) * HALF_CELL, "normal": Vector3(normal)}
		return {}
	var best := {}
	var best_dot := 0.5
	for fc in facets:
		if fc["coord"] != cell:
			continue
		var n := facet_normal(fc)
		var d := n.dot(Vector3(normal))
		if d > best_dot:
			best_dot = d
			best = {"centre": facet_centre(fc), "normal": n}
	return best

## Cyan strips (spec §5.4): along the top chamfers, fore and aft, at the
## highest roof, and up the bow's vertical chamfers.
func _mark_running() -> void:
	var top := -1 << 30
	var bow := 1 << 30
	for e in edges:
		var ups: bool = e["a"] == Vector3i.UP or e["b"] == Vector3i.UP
		if ups and absi(e["axis"].z) == 1:
			top = maxi(top, e["coord"].y)
		var fwd: bool = e["a"] == Vector3i.FORWARD or e["b"] == Vector3i.FORWARD
		if fwd and absi(e["axis"].y) == 1:
			bow = mini(bow, e["coord"].z)
	for e in edges:
		var ups: bool = e["a"] == Vector3i.UP or e["b"] == Vector3i.UP
		var fwd: bool = e["a"] == Vector3i.FORWARD or e["b"] == Vector3i.FORWARD
		e["running"] = (ups and absi(e["axis"].z) == 1 and e["coord"].y == top) \
			or (fwd and absi(e["axis"].y) == 1 and e["coord"].z == bow)
```

- [ ] **Step 4: Windows and the pod shell in `HullProps`**

Append:

```gdscript
## A window frame's bar width.
const FRAME := 0.1
## How far the pod shell stands outside the interior pod's outline.
const POD_SKIN := 0.08
## How far below the pod's floor its shell's belly goes.
const POD_BELOW := 0.12
## The pod roof's thickness and its lip beyond the walls.
const POD_ROOF_THICK := 0.1
const POD_LIP := 0.1

static func _glass() -> Color:
	return InteriorKit.solid(HullPalette.WINDOW_GLASS)

static func _band() -> Color:
	return InteriorKit.lit(HullPalette.WINDOW_LIGHT, InteriorMaterials.GLOW_ENERGY)

## A porthole from outside (spec §5.1), in a skin frame at its centre: a
## chunky trim ring, dark amber glass, and two warm bands behind it.
static func window_porthole(kit: InteriorKit, f: Transform3D, radius: float) -> void:
	kit.ring(SOLID, f, radius, radius + FRAME * 1.6, -0.02, 0.08, _trim())
	kit.disc(GLASS, f * _at(Vector3(0, 0, 0.02)), radius, _glass())
	for y in [0.35 * radius, -0.2 * radius]:
		var w := 2.0 * sqrt(radius * radius - y * y) * 0.8
		kit.box(GLOW, f * _at(Vector3(0, y, 0.025)), Vector3(w, 0.04, 0.004), _band())

## A rectangular window from outside, `size` across and up its face: a
## bevelled trim frame, glass, and three warm bands.
static func window_rect(kit: InteriorKit, f: Transform3D, size: Vector2) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var n := (f.basis * Vector3.BACK).normalized()
	kit.quad(GLASS, f * Vector3(-hx, -hy, 0.02), f * Vector3(hx, -hy, 0.02), f * Vector3(hx, hy, 0.02),
		f * Vector3(-hx, hy, 0.02), n, _glass())
	for k in [-0.5, 0.05, 0.55]:
		kit.box(GLOW, f * _at(Vector3(0, k * hy, 0.025)), Vector3(size.x * 0.86, 0.045, 0.004), _band())
	for s in [-1.0, 1.0]:
		kit.bevel_box(SOLID, f * _at(Vector3(s * (hx + FRAME * 0.5), 0, 0.04)),
			Vector3(FRAME, size.y + FRAME * 2.0, 0.08), 0.02, _trim())
		kit.bevel_box(SOLID, f * _at(Vector3(0, s * (hy + FRAME * 0.5), 0.04)),
			Vector3(size.x, FRAME, 0.08), 0.02, _trim())

## The interior pod's outline grown by POD_SKIN, as (x, z) in the pod frame.
## The mouth's two ends stay on the canopy plane.
static func _pod_outline(grow: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var centre := Vector2(0, -0.9)
	for p: Vector2 in InteriorProps.POD_OUTLINE:
		if is_zero_approx(p.y):
			out.append(p + Vector2(signf(p.x) * grow, 0))
		else:
			out.append(p + (p - centre).normalized() * grow)
	return out

static func _wall(kit: InteriorKit, batch: InteriorKit.Batch, f: Transform3D, a: Vector3, b: Vector3,
		y0: float, y1: float, n: Vector3, colour: Color) -> void:
	kit.quad(batch, f * (a + Vector3.UP * y0), f * (b + Vector3.UP * y0), f * (b + Vector3.UP * y1),
		f * (a + Vector3.UP * y1), n, colour)

## The cockpit pod from outside (spec §5.2), in the interior's pod frame:
## origin at the mouth's floor centre on the canopy plane, -z out into the pod,
## +x across, +y up. The interior pod grown by POD_SKIN: livery below the
## sill, glass with warm bands to the glass top, a band to the roof, the jambs
## solid, a roof with a lip, and a belly. The mouth is left open: the hull
## closes it.
static func pod_shell(kit: InteriorKit, f: Transform3D) -> void:
	var outline := _pod_outline(POD_SKIN)
	var low := -POD_BELOW
	var sill := InteriorProps.POD_SILL
	var glass_top := InteriorProps.POD_GLASS_TOP
	var roof := InteriorProps.POD_ROOF + POD_ROOF_THICK
	var last := outline.size() - 1
	for i in last:
		var p0 := outline[i]
		var p1 := outline[i + 1]
		var d := p1 - p0
		var n := (f.basis * Vector3(d.y, 0, -d.x)).normalized()
		var a := Vector3(p0.x, 0, p0.y)
		var b := Vector3(p1.x, 0, p1.y)
		if i == 0 or i == last - 1:
			_wall(kit, HULL, f, a, b, low, roof, n, _plate_colour())
			continue
		_wall(kit, HULL, f, a, b, low, sill, n, _plate_colour())
		_wall(kit, GLASS, f, a, b, sill, glass_top, n, _glass())
		_wall(kit, HULL, f, a, b, glass_top, roof, n, _plate_colour())
		var inset := (b - a).normalized() * 0.06
		var out := f.basis.inverse() * n * 0.01
		for k in [0.35, 0.7]:
			var y := lerpf(sill, glass_top, k)
			_wall(kit, GLOW, f, a + inset + out, b - inset + out, y - 0.025, y + 0.025, n, _band())
	for i in range(1, last):
		var p := outline[i]
		kit.bevel_box(SOLID, f * _at(Vector3(p.x, (sill + glass_top) * 0.5, p.y)),
			Vector3(0.08, glass_top - sill, 0.08), 0.02, _trim())
	# The roof, with a lip beyond the walls, and the belly.
	var lip := _pod_outline(POD_SKIN + POD_LIP)
	var roof_centre := Vector3(0, roof, -0.9)
	var floor_centre := Vector3(0, low, -0.9)
	for i in last:
		var r0 := Vector3(lip[i].x, roof, lip[i].y)
		var r1 := Vector3(lip[i + 1].x, roof, lip[i + 1].y)
		kit.tri(HULL, f * roof_centre, f * r0, f * r1, (f.basis * Vector3.UP).normalized(), _plate_colour())
		var d := lip[i + 1] - lip[i]
		var n := (f.basis * Vector3(d.y, 0, -d.x)).normalized()
		_wall(kit, HULL, f, Vector3(lip[i].x, 0, lip[i].y), Vector3(lip[i + 1].x, 0, lip[i + 1].y),
			roof - POD_ROOF_THICK, roof, n, _plate_colour())
		var g0 := Vector3(outline[i].x, low, outline[i].y)
		var g1 := Vector3(outline[i + 1].x, low, outline[i + 1].y)
		kit.tri(HULL, f * floor_centre, f * g0, f * g1, (f.basis * Vector3.DOWN).normalized(), _plate_colour())
```

- [ ] **Step 5: Draw windows and pods in `HullDressing`; keep a box on a pod's cell**

In `HullDressing.build`, before `return`, add the windows kit and put its glow material in the result:

```gdscript
	# Windows and pods (spec §5): their own kit, so their glow has its own
	# material, which ShipLights dims with the ship.
	var window_glow := HullMaterials.glow_instance(HullMaterials.WINDOW_ENERGY)
	var glazing := _kit(root, "Windows")
	glazing.materials = {InteriorKit.Batch.HULL: HullMaterials.livery(), InteriorKit.Batch.SOLID: HullMaterials.trim(),
		InteriorKit.Batch.GLASS: HullMaterials.window_glass(), InteriorKit.Batch.GLOW: window_glow}
	for w in layout.windows:
		if w["round"]:
			HullProps.window_porthole(glazing, w["frame"], w["size"].x * 0.5)
		else:
			HullProps.window_rect(glazing, w["frame"], w["size"])
	for p in layout.pods:
		HullProps.pod_shell(glazing, p["frame"])
	for mi in glazing.commit():
		if mi.name != InteriorKit.BATCH_NAMES[InteriorKit.Batch.GLOW]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
```

Return `"window_glow": window_glow` instead of `null`.

In `ExteriorBuilder._build_colliders()`, change the cube test so a pod's canopy cell keeps its box. The pod shell reaches past the wedge:

```gdscript
		if shape_name == HullShapes.CUBE or _layout.is_pod_cell(coord):
```

- [ ] **Step 6: Run the tests, then the full suite**

Run: `who-knows/run_tests.ps1 -gselect=test_hull_windows`, `-gselect=test_hull_props`, then `who-knows/run_tests.ps1`
Expected: PASS.

- [ ] **Step 7: Render and show the owner (checkpoint 3)**

Run the probe. Send the hull renders to the owner, and include the probe's own `seated` and `spawn` renders to show the interior is unchanged. Caption:

> Windows now match the cabin: portholes at the rooms, the shoulder windows, the pod shell, and cyan running strips.

- [ ] **Step 8: Commit**

```bash
git add -A who-knows/src/ship who-knows/test/unit/test_hull_windows.gd who-knows/test/unit/test_hull_props.gd
git commit -m "feat: windows outside where the cabin has them, the pod shell, running strips

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Light mounts and fixtures

**Files:**
- Modify: `src/ship/hull/hull_layout.gd`, adding `_plan_mounts`
- Modify: `src/ship/hull/hull_props.gd`, adding `flood_fixture` and `forward_fixture`
- Modify: `src/ship/hull/hull_dressing.gd`, adding the lens kits
- Test: `test/unit/test_hull_lights.gd`

**Interfaces:**
- Consumes: `HullLayout.skin`, `facets`, `windows`, `pods` and `inside()`.
- Produces:
  - `HullLayout.FLOOD`, `HullLayout.FORWARD`;
  - `HullLayout.mounts`: `{group: StringName, position: Vector3, normal: Vector3, aim: Vector3}`, in hull space with a unit aim;
  - `HullProps.flood_fixture(kit, lens: InteriorKit, f)` and `forward_fixture(kit, lens, f)`, where `f` has +z along the aim;
  - `HullDressing.build(...)["lenses"]`: `{group: MeshInstance3D}`, each with its own glow material as `material_override`, starting at energy 0.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_hull_lights.gd`:

```gdscript
extends GutTest

## Ship exterior spec §6.1: the generator picks where the lights go.

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func _plan(g: ShipGrid) -> HullLayout:
	return HullLayout.plan(g, _cat, InteriorLayout.plan(g, _cat, DeckGraph.build(g, _cat).walkable_coords()))

func _starter() -> ShipGrid:
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var g: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	return g

func _group(l: HullLayout, group: StringName) -> Array:
	return l.mounts.filter(func(m): return m["group"] == group)

func test_the_starter_has_six_floods_and_two_forward_lights():
	var l := _plan(_starter())
	assert_eq(_group(l, HullLayout.FLOOD).size(), 6, "four belly corners and two on the keel")
	assert_eq(_group(l, HullLayout.FORWARD).size(), 2)

func test_every_light_shines_clear_of_the_hull():
	var l := _plan(_starter())
	for m in l.mounts:
		var aim: Vector3 = m["aim"]
		assert_almost_eq(aim.length(), 1.0, 0.0001)
		for i in range(1, 21):
			var p: Vector3 = m["position"] + aim * (0.1 * i)
			assert_false(l.inside(p), "%s at %s shines into the hull %.1f m out" % [m["group"], m["position"], 0.1 * i])

func test_floods_look_down_and_out():
	var l := _plan(_starter())
	for m in _group(l, HullLayout.FLOOD):
		var aim: Vector3 = m["aim"]
		assert_almost_eq(rad_to_deg(aim.angle_to(Vector3.DOWN)), 25.0, 0.5, "tilted 25 deg out")
	var keel := _group(l, HullLayout.FLOOD).filter(func(m): return is_zero_approx(m["position"].x))
	assert_eq(keel.size(), 2)
	for m in keel:
		assert_almost_eq(m["aim"].x, 0.0, 0.0001, "a keel flood tilts fore or aft, not sideways")

func test_forward_lights_look_ahead_from_the_nose_corners():
	var l := _plan(_starter())
	var xs := []
	for m in _group(l, HullLayout.FORWARD):
		assert_lt(rad_to_deg(m["aim"].angle_to(Vector3.FORWARD)), 10.0)
		assert_lt(m["aim"].y, 0.0, "a little down")
		assert_gt(m["aim"].x * m["position"].x, 0.0, "toed out, away from the centreline")
		xs.append(m["position"].x)
	xs.sort()
	assert_lt(xs[0], -2.0)
	assert_gt(xs[1], 2.0)

func test_a_ship_with_no_pod_still_gets_forward_lights():
	var g := ShipGrid.new()
	for x in [-1, 0, 1]:
		for spec in [[Vector3i(x, 0, -1), &"canopy"], [Vector3i(x, 0, 0), &"deck"], [Vector3i(x, 1, 0), &"hull"]]:
			var i := BlockInstance.new()
			i.block_id = spec[1]
			g.set_block(spec[0], i)
	var l := _plan(g)
	assert_eq(_group(l, HullLayout.FORWARD).size(), 2)
	assert_gt(_group(l, HullLayout.FLOOD).size(), 0)

func test_the_dressing_makes_a_lens_per_group_starting_dark():
	var root := Node3D.new()
	add_child_autofree(root)
	var made := HullDressing.build(_plan(_starter()), root)
	for group in [HullLayout.FLOOD, HullLayout.FORWARD]:
		var lens: MeshInstance3D = made["lenses"][group]
		assert_not_null(lens)
		assert_eq((lens.material_override as ShaderMaterial).get_shader_parameter(&"energy"), 0.0)
	assert_ne(made["lenses"][HullLayout.FLOOD].material_override, made["lenses"][HullLayout.FORWARD].material_override)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `who-knows/run_tests.ps1 -gselect=test_hull_lights`
Expected: FAIL: `HullLayout.FLOOD` is not declared.

- [ ] **Step 3: Plan the mounts in `HullLayout`**

Add the constants:

```gdscript
## Light groups (spec §6).
const FLOOD := &"flood"
const FORWARD := &"forward"
## Floods: tilt out from the belly's centre, keel spacing, how far above the
## lowest a downward face still counts as belly (so a keel does not pull every
## flood onto the centreline).
const FLOOD_TILT_DEG := 25.0
const FLOOD_SPACING := 6.0
const BELLY_BAND := 1.5
## Forward lights: how nearly forward a face must look (normal . forward), how
## close to the bow, how far below a window, and the aim's drop and toe-out.
const FORWARD_MIN_DOT := 0.7
const FORWARD_BOW_BAND := 2.5
const FORWARD_BELOW_WINDOW := 0.3
const FORWARD_DROP_DEG := 5.0
const FORWARD_TOE_DEG := 3.0
```

In `plan()`, call `l._plan_mounts()` after `_plan_windows` and before `_mark_running`. Then add:

```gdscript
## Every face of the skin that shows: {centre, normal, coord}, in hull space.
func _open_faces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cubes := skin.keys()
	cubes.sort()
	for coord: Vector3i in cubes:
		for n: Vector3i in ShipGrid.FACE_OFFSETS:
			if skin[coord].has(n):
				out.append({"centre": ShipGrid.cell_center(coord) + Vector3(n) * HALF_CELL, "normal": Vector3(n),
					"coord": coord})
	for fc in facets:
		out.append({"centre": facet_centre(fc), "normal": facet_normal(fc), "coord": fc["coord"]})
	return out

func _plan_mounts() -> void:
	var faces := _open_faces()
	_plan_floods(faces.filter(func(f): return f["normal"].dot(Vector3.DOWN) > 0.99))
	_plan_forward(faces)

## Floods (spec §6.1): one at each corner of the belly, then along the keel
## every FLOOD_SPACING between the bow and stern corners.
func _plan_floods(down: Array) -> void:
	if down.is_empty():
		return
	var lowest := INF
	for f in down:
		lowest = minf(lowest, f["centre"].y)
	var belly := down.filter(func(f): return f["centre"].y <= lowest + BELLY_BAND)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for f in belly:
		var c: Vector3 = f["centre"]
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.z))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.z))
	var middle := (lo + hi) * 0.5
	var chosen: Array[Vector3] = []
	for corner in [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(lo.x, hi.y), Vector2(hi.x, hi.y)]:
		var best: Vector3 = belly[0]["centre"]
		var best_d := INF
		for f in belly:
			var c: Vector3 = f["centre"]
			var d := Vector2(c.x, c.z).distance_to(corner)
			if d < best_d - 0.001 or (absf(d - best_d) <= 0.001 and _before(c, best)):
				best = c
				best_d = d
		if not chosen.has(best):
			chosen.append(best)
	for c in chosen:
		_add_flood(c, Vector3(c.x - middle.x, 0, c.z - middle.y))
	var fore := INF
	var aft := -INF
	for c in chosen:
		fore = minf(fore, c.z)
		aft = maxf(aft, c.z)
	var keel_x := INF
	for f in belly:
		keel_x = minf(keel_x, absf(f["centre"].x))
	var keel := belly.filter(func(f): return is_equal_approx(absf(f["centre"].x), keel_x))
	var count := floori((aft - fore) / FLOOD_SPACING)
	for i in count:
		var z := fore + (aft - fore) * float(i + 1) / float(count + 1)
		var best: Vector3 = keel[0]["centre"]
		for f in keel:
			var c: Vector3 = f["centre"]
			if absf(c.z - z) < absf(best.z - z) - 0.001:
				best = c
		if not chosen.has(best):
			chosen.append(best)
			_add_flood(best, Vector3(0, 0, signf(best.z - middle.y)))

func _add_flood(at: Vector3, out: Vector3) -> void:
	var t := deg_to_rad(FLOOD_TILT_DEG)
	var aim := Vector3.DOWN
	if out.length() > 0.01:
		aim = (Vector3.DOWN * cos(t) + out.normalized() * sin(t)).normalized()
	mounts.append({"group": FLOOD, "position": at, "normal": Vector3.DOWN, "aim": aim})

## Ties go toward the centreline, then the bow.
static func _before(a: Vector3, b: Vector3) -> bool:
	if not is_equal_approx(absf(a.x), absf(b.x)):
		return absf(a.x) < absf(b.x)
	return a.z < b.z

## Forward lights (spec §6.1): of the faces looking within 45 deg of forward,
## on the pod's row (or the lowest row with any), near the bow, and not the
## pod's cell, the outermost to port and starboard.
func _plan_forward(faces: Array[Dictionary]) -> void:
	var fwd := faces.filter(func(f): return f["normal"].dot(Vector3.FORWARD) >= FORWARD_MIN_DOT
		and not _pod_cells.has(f["coord"]))
	if fwd.is_empty():
		return
	var row: int = pods[0]["cell"].y if not pods.is_empty() else 1 << 30
	if pods.is_empty():
		for f in fwd:
			row = mini(row, f["coord"].y)
	fwd = fwd.filter(func(f): return f["coord"].y == row)
	if fwd.is_empty():
		return
	var front := INF
	for f in fwd:
		front = minf(front, f["centre"].z)
	fwd = fwd.filter(func(f): return f["centre"].z <= front + FORWARD_BOW_BAND)
	var port: Dictionary = fwd[0]
	var starboard: Dictionary = fwd[0]
	for f in fwd:
		if f["centre"].x < port["centre"].x - 0.001:
			port = f
		if f["centre"].x > starboard["centre"].x + 0.001:
			starboard = f
	_add_forward(port)
	if starboard != port:
		_add_forward(starboard)

func _add_forward(face: Dictionary) -> void:
	var n: Vector3 = face["normal"]
	var centre: Vector3 = face["centre"]
	var up := (Vector3.UP - n * Vector3.UP.dot(n)).normalized()
	var y := centre.y
	for w in windows:
		if w["coord"] == face["coord"]:
			var wf: Transform3D = w["frame"]
			y = minf(y, wf.origin.y - w["size"].y * 0.5 * wf.basis.y.y - FORWARD_BELOW_WINDOW)
	var at := centre + up * ((y - centre.y) / up.y)
	var drop := deg_to_rad(FORWARD_DROP_DEG)
	var side := signf(centre.x) if not is_zero_approx(centre.x) else 1.0
	var aim := Vector3(0, -sin(drop), -cos(drop)).rotated(Vector3.UP, -side * deg_to_rad(FORWARD_TOE_DEG))
	mounts.append({"group": FORWARD, "position": at, "normal": n, "aim": aim.normalized()})
```

- [ ] **Step 4: The fixtures in `HullProps`**

Append:

```gdscript
## A flood's housing and lens (spec §6.1), in a frame at its mount with +z
## along its aim: a chunky bevelled box and a round lens. The lens goes in
## `lens`'s glow, whose material ShipLights turns up and down.
static func flood_fixture(kit: InteriorKit, lens: InteriorKit, f: Transform3D) -> void:
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0, 0.1)), Vector3(0.56, 0.56, 0.32), 0.06, _trim())
	kit.ring(SOLID, f * _at(Vector3(0, 0, 0.26)), 0.2, 0.26, 0.0, 0.06, _trim())
	kit.disc(SOLID, f * _at(Vector3(0, 0, 0.265)), 0.2, _dark())
	lens.disc(GLOW, f * _at(Vector3(0, 0, 0.27)), 0.2, InteriorKit.lit(HullPalette.WORK_LIGHT, InteriorMaterials.GLOW_ENERGY))

## A forward light (spec §6.1): a recessed lamp in a round bezel, in a frame
## at its mount with +z along its aim.
static func forward_fixture(kit: InteriorKit, lens: InteriorKit, f: Transform3D) -> void:
	kit.ring(SOLID, f, 0.2, 0.32, -0.08, 0.08, _trim())
	kit.disc(SOLID, f * _at(Vector3(0, 0, 0.0)), 0.2, _dark())
	lens.disc(GLOW, f * _at(Vector3(0, 0, 0.01)), 0.19, InteriorKit.lit(HullPalette.WORK_LIGHT, InteriorMaterials.GLOW_ENERGY))
```

- [ ] **Step 5: Lens kits in `HullDressing`**

In `build`, **before** `skin.commit()`, because the housings go in the skin kit, add:

```gdscript
	# Light fixtures (spec §6.1): housings on the skin, each group's lenses in
	# a kit of their own, so each group's glow material dims alone.
	var lens_kits := {}
	for m in layout.mounts:
		var group: StringName = m["group"]
		if not lens_kits.has(group):
			var lk := _kit(root, "Lens_%s" % group)
			lk.materials = {InteriorKit.Batch.GLOW: HullMaterials.glow_instance(0.0)}
			lens_kits[group] = lk
		var aim: Vector3 = m["aim"]
		var up := Vector3.FORWARD if absf(aim.dot(Vector3.UP)) > 0.9 else Vector3.UP
		var f := Transform3D(Basis.looking_at(-aim, up), m["position"])
		if group == HullLayout.FLOOD:
			HullProps.flood_fixture(skin, lens_kits[group], f)
		else:
			HullProps.forward_fixture(skin, lens_kits[group], f)
```

After the skin commit, build the lenses dictionary and return it:

```gdscript
	var lenses := {}
	for group: StringName in lens_kits:
		var lens: MeshInstance3D = lens_kits[group].commit()[0]
		lens.name = "Lens"
		lenses[group] = lens
```

- [ ] **Step 6: Run the tests, then the full suite**

Run: `who-knows/run_tests.ps1 -gselect=test_hull_lights`, then `who-knows/run_tests.ps1`
Expected: PASS. If the starter's flood count is not 6, check which belly faces were chosen: print `l.mounts`. The spec's rule, not the number, is the authority. If the rule is right and the count differs, correct the spec's §6.1 number and this test together, and tell the owner.

- [ ] **Step 7: Commit**

```bash
git add -A who-knows/src/ship/hull who-knows/test/unit/test_hull_lights.gd
git commit -m "feat: light mounts -- floods round the belly, a forward pair at the bow

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: ShipLights, spot lights, beams, levels and save

**Files:**
- Create: `src/ship/ship_lights.gd`
- Modify: `src/ship/hull/hull_props.gd`, adding `beam_cone`
- Modify: `src/ship/ship.gd` (`var lights`, `_ready`, `_rebuild_everything`, `to_dict`, `restore_aboard`)
- Modify: `test/unit/test_visual_style_rules.gd`, adding `ship_lights.gd` to `PAINTING_FILES`
- Test: `test/unit/test_ship_lights.gd`

**Interfaces:**
- Consumes: `ExteriorBuilder.light_mounts()`, `lenses()` and `window_glow()`; `QuantumPlant.store.is_low_power()`.
- Produces:
  - `ShipLights` (`Node3D`):
    - constants `FLOOD`, `FORWARD`, `GROUPS`, `SETTINGS`, `LIGHT_MASK`, `BEAM_LAYER`, `LOW_POWER_LEVEL`;
    - vars `floods`, `forward`, `interior_level`, `exterior_level` and `quantum`;
    - signal `changed`;
  - `bind(mounts: Array, lenses: Dictionary, window_glow: ShaderMaterial)`;
  - `is_on(group) -> bool`, `set_group(group, on)`, `toggle(group)`;
  - `spots(group) -> Array[SpotLight3D]`, `beam(group) -> MeshInstance3D`;
  - `apply_power(low_power: bool)`, `to_dict() -> Dictionary`, `from_dict(d)`;
  - `Ship.lights: ShipLights`, under `Ship/Exterior/Lights`;
  - the save part `"lights"` in `Ship.to_dict`;
  - `HullProps.beam_cone(kit, f, length, radius)`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_ship_lights.gd`:

```gdscript
extends GutTest

## Ship exterior spec §6.2, §7.1: the lights' state, their spot lights and
## beams, low power, and the save.

var _lights: ShipLights
var _flood_lens: MeshInstance3D
var _forward_lens: MeshInstance3D
var _glow: ShaderMaterial

const MOUNTS := [
	{"group": &"flood", "position": Vector3(-4, -1, -6), "normal": Vector3.DOWN, "aim": Vector3(-0.3, -0.9, -0.3)},
	{"group": &"flood", "position": Vector3(4, -1, -6), "normal": Vector3.DOWN, "aim": Vector3(0.3, -0.9, -0.3)},
	{"group": &"forward", "position": Vector3(-4, 0, -6), "normal": Vector3.FORWARD, "aim": Vector3(0, -0.087, -0.996)},
]

func _lens() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = HullMaterials.glow_instance(0.0)
	add_child_autofree(mi)
	return mi

func before_each():
	_lights = ShipLights.new()
	add_child_autofree(_lights)
	_flood_lens = _lens()
	_forward_lens = _lens()
	_glow = HullMaterials.glow_instance(0.0)
	_bind()

func _bind() -> void:
	var mounts: Array = []
	for m in MOUNTS:
		var d: Dictionary = m.duplicate()
		d["aim"] = (d["aim"] as Vector3).normalized()
		mounts.append(d)
	_lights.bind(mounts, {&"flood": _flood_lens, &"forward": _forward_lens}, _glow)

func _energy(mi: MeshInstance3D) -> float:
	return (mi.material_override as ShaderMaterial).get_shader_parameter(&"energy")

func test_one_spot_light_per_mount_aimed_along_it():
	assert_eq(_lights.spots(&"flood").size(), 2)
	assert_eq(_lights.spots(&"forward").size(), 1)
	var spot: SpotLight3D = _lights.spots(&"forward")[0]
	assert_almost_eq(-spot.global_basis.z, MOUNTS[2]["aim"].normalized(), Vector3.ONE * 0.001, "a spot shines along -z")
	assert_eq(spot.light_cull_mask, 1 | ExteriorBuilder.OWN_HULL_LAYER, "never the interior")
	assert_true(spot.shadow_enabled, "the forward lights cast shadows")
	assert_false(_lights.spots(&"flood")[0].shadow_enabled)
	assert_almost_eq(spot.spot_angle, 11.0, 0.0001, "half the 22 deg cone")
	assert_almost_eq(spot.spot_range, 220.0, 0.0001)
	assert_eq(_lights.beam(&"forward").layers, ShipLights.BEAM_LAYER, "beams on the world's layer")

func test_everything_starts_off():
	assert_false(_lights.floods)
	assert_false(_lights.forward)
	for spot in _lights.spots(&"flood"):
		assert_false(spot.visible)
	assert_false(_lights.beam(&"flood").visible)
	assert_eq(_energy(_flood_lens), 0.0)
	assert_almost_eq(_glow.get_shader_parameter(&"energy"), HullMaterials.WINDOW_ENERGY, 0.0001, "the windows glow")

func test_toggling_a_group_lights_it_and_says_so():
	watch_signals(_lights)
	_lights.toggle(&"flood")
	assert_signal_emit_count(_lights, "changed", 1)
	assert_true(_lights.floods)
	assert_false(_lights.forward, "the groups are separate")
	for spot in _lights.spots(&"flood"):
		assert_true(spot.visible)
	assert_true(_lights.beam(&"flood").visible)
	assert_false(_lights.beam(&"forward").visible)
	assert_gt(_energy(_flood_lens), 0.0)
	assert_eq(_energy(_forward_lens), 0.0)
	_lights.set_group(&"flood", true)
	assert_signal_emit_count(_lights, "changed", 1, "no change, no signal")

func test_low_power_halves_the_lights_and_the_windows():
	_lights.set_group(&"forward", true)
	var full: float = _lights.spots(&"forward")[0].light_energy
	_lights.apply_power(true)
	assert_almost_eq(_lights.spots(&"forward")[0].light_energy, full * ShipLights.LOW_POWER_LEVEL, 0.0001)
	assert_almost_eq(_glow.get_shader_parameter(&"energy"), HullMaterials.WINDOW_ENERGY * ShipLights.LOW_POWER_LEVEL, 0.0001)
	assert_true(_lights.spots(&"forward")[0].visible, "the lights still work in low power")
	_lights.apply_power(false)
	assert_almost_eq(_lights.spots(&"forward")[0].light_energy, full, 0.0001)

func test_with_no_plant_the_lights_run_at_full_power():
	_lights.quantum = null
	_lights._process(0.016)
	assert_eq(_lights.exterior_level, 1.0)
	assert_eq(_lights.interior_level, 1.0)

func test_a_rebuild_keeps_the_lights_on():
	_lights.set_group(&"flood", true)
	var old: SpotLight3D = _lights.spots(&"flood")[0]
	_bind()
	assert_false(is_instance_valid(old), "the old lights are freed at once")
	assert_true(_lights.floods)
	for spot in _lights.spots(&"flood"):
		assert_true(spot.visible, "the new lights come on as the old were")

func test_the_save_round_trips():
	_lights.set_group(&"forward", true)
	var d := _lights.to_dict()
	assert_eq(d, {"floods": false, "forward": true})
	var other := ShipLights.new()
	add_child_autofree(other)
	other.from_dict(d)
	assert_true(other.forward)
	assert_false(other.floods)

func test_a_save_without_lights_loads_them_off():
	_lights.set_group(&"flood", true)
	_lights.from_dict({})
	assert_false(_lights.floods)
	assert_false(_lights.forward)

## The real ship: its lights live on the hull, bound after every rebuild.
func test_the_flight_scene_s_ship_has_its_lights_on_the_hull():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.save_enabled = false
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	assert_true(ship.lights is ShipLights)
	assert_eq(ship.lights.get_parent(), ship.exterior, "carried by the floating origin with the hull")
	assert_eq(ship.lights.spots(&"flood").size(), 6)
	assert_eq(ship.lights.spots(&"forward").size(), 2)
	assert_true(ship.to_dict(root.get_node("Universe")).has("lights"))
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `who-knows/run_tests.ps1 -gselect=test_ship_lights`
Expected: FAIL: `ShipLights` is not declared.

- [ ] **Step 3: The beam in `HullProps`**

Append:

```gdscript
## How wide a beam is where it leaves the lens.
const BEAM_NEAR := 0.15

## A light's faint beam (spec §6.4), in a frame at the lens with +z along its
## aim: an open cone `length` long, `radius` wide at its far end. Its UVs run
## v = 1 at the lens to v = 0 at the far end, which HullMaterials.beam fades
## along.
static func beam_cone(kit: InteriorKit, f: Transform3D, length: float, radius: float) -> void:
	var far := Vector3(0, 0, length)
	for i in InteriorKit.SEGMENTS:
		var a0 := TAU * float(i) / InteriorKit.SEGMENTS
		var a1 := TAU * float(i + 1) / InteriorKit.SEGMENTS
		var d0 := Vector3(cos(a0), sin(a0), 0)
		var d1 := Vector3(cos(a1), sin(a1), 0)
		kit.quad(GLOW, f * (d0 * BEAM_NEAR), f * (d1 * BEAM_NEAR), f * (d1 * radius + far), f * (d0 * radius + far),
			(f.basis * (d0 + d1)).normalized(), InteriorKit.solid(HullPalette.WORK_LIGHT))
```

- [ ] **Step 4: Write `src/ship/ship_lights.gd`**

```gdscript
class_name ShipLights
extends Node3D

## The ship's work lights (docs/superpowers/specs/2026-09-28-ship-exterior-design.md
## §6, §7): floods under and around the hull, and a forward pair, at the
## mounts HullLayout picks. The helm (L, K) and the bridge's lights panel both
## switch this one state. It lives under the hull body, so the floating origin
## carries it (CLAUDE.md), and it outlives rebuilds: bind() remakes the lights
## from the new mounts and keeps what was on.

signal changed

const FLOOD := &"flood"
const FORWARD := &"forward"
const GROUPS: Array[StringName] = [FLOOD, FORWARD]
## The world and the ship's own hull; never the interior (layer 2).
const LIGHT_MASK := 1 | ExteriorBuilder.OWN_HULL_LAYER
## Beams are on the world's layer, so the canopy shows your forward beams.
const BEAM_LAYER := 1
## Each group: its cone (full angle, degrees), reach (m), energy at full
## power, and whether it casts shadows. Energies are tuned at the renders.
const SETTINGS := {
	FLOOD: {"cone": 55.0, "reach": 40.0, "energy": 4.0, "shadows": false},
	FORWARD: {"cone": 22.0, "reach": 220.0, "energy": 16.0, "shadows": true},
}
## How much of its reach a beam is drawn along before it has faded out.
const BEAM_FRACTION := 0.6
## Both levels in low power (quantum energy spec §8): the lights still work.
const LOW_POWER_LEVEL := 0.5

var floods := false
var forward := false
## The windows' brightness and the lights', 1 at full power.
var interior_level := 1.0
var exterior_level := 1.0
## The ship's quantum plant, for low power. Null means full power.
var quantum: QuantumPlant

var _rig: Node3D
var _spots: Dictionary = {}    # StringName -> Array[SpotLight3D]
var _beams: Dictionary = {}    # StringName -> MeshInstance3D
var _lenses: Dictionary = {}   # StringName -> MeshInstance3D
var _window_glow: ShaderMaterial

## Remakes the spot lights and beams at `mounts` (HullLayout.mounts), with
## each group's lens glow and the windows' glow from the new skin, and shows
## them as the state says.
func bind(mounts: Array, lenses: Dictionary, window_glow: ShaderMaterial) -> void:
	if is_instance_valid(_rig):
		remove_child(_rig)
		_rig.free()
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_spots.clear()
	_beams.clear()
	_lenses = lenses
	_window_glow = window_glow
	for group in GROUPS:
		var s: Dictionary = SETTINGS[group]
		var kit := InteriorKit.new(_rig)
		kit.layer = BEAM_LAYER
		kit.materials = {InteriorKit.Batch.GLOW: HullMaterials.beam(HullPalette.WORK_LIGHT)}
		var spots: Array[SpotLight3D] = []
		for mount: Dictionary in mounts:
			if mount["group"] != group:
				continue
			var at: Vector3 = mount["position"]
			var aim: Vector3 = mount["aim"]
			var spot := SpotLight3D.new()
			spot.name = "%s_%d" % [group, spots.size()]
			spot.transform = Transform3D(Basis.looking_at(aim, _up(aim)), at)
			spot.light_color = HullPalette.WORK_LIGHT
			spot.spot_angle = s["cone"] * 0.5
			spot.spot_range = s["reach"]
			spot.shadow_enabled = s["shadows"]
			spot.light_cull_mask = LIGHT_MASK
			spot.set_meta(&"group", group)
			_rig.add_child(spot)
			spots.append(spot)
			var length: float = s["reach"] * BEAM_FRACTION
			HullProps.beam_cone(kit, Transform3D(Basis.looking_at(-aim, _up(aim)), at), length,
				tan(deg_to_rad(s["cone"] * 0.5)) * length)
		_spots[group] = spots
		if not spots.is_empty():
			var beam_mesh: MeshInstance3D = kit.commit()[0]
			beam_mesh.name = "Beam_%s" % group
			_beams[group] = beam_mesh
	_apply()

static func _up(aim: Vector3) -> Vector3:
	return Vector3.FORWARD if absf(aim.normalized().dot(Vector3.UP)) > 0.9 else Vector3.UP

func is_on(group: StringName) -> bool:
	return floods if group == FLOOD else forward

func set_group(group: StringName, on: bool) -> void:
	if is_on(group) == on:
		return
	if group == FLOOD:
		floods = on
	else:
		forward = on
	_apply()
	changed.emit()

func toggle(group: StringName) -> void:
	set_group(group, not is_on(group))

func spots(group: StringName) -> Array[SpotLight3D]:
	var none: Array[SpotLight3D] = []
	return _spots.get(group, none)

func beam(group: StringName) -> MeshInstance3D:
	return _beams.get(group)

## Low power halves the windows and the lights (spec §7.1).
func apply_power(low_power: bool) -> void:
	var level := LOW_POWER_LEVEL if low_power else 1.0
	if is_equal_approx(level, exterior_level) and is_equal_approx(level, interior_level):
		return
	interior_level = level
	exterior_level = level
	_apply()

func _process(_delta: float) -> void:
	apply_power(quantum != null and quantum.store != null and quantum.store.is_low_power())

func _apply() -> void:
	for group in GROUPS:
		var on := is_on(group)
		var s: Dictionary = SETTINGS[group]
		for spot in spots(group):
			spot.visible = on
			spot.light_energy = s["energy"] * exterior_level
		if _beams.has(group):
			_beams[group].visible = on
		var lens: MeshInstance3D = _lenses.get(group)
		if is_instance_valid(lens) and lens.material_override is ShaderMaterial:
			(lens.material_override as ShaderMaterial).set_shader_parameter(&"energy",
				InteriorMaterials.GLOW_ENERGY * exterior_level if on else 0.0)
	if _window_glow != null:
		_window_glow.set_shader_parameter(&"energy", HullMaterials.WINDOW_ENERGY * interior_level)

## The ship's save part (spec §7.1). A save without one loads with both off.
func to_dict() -> Dictionary:
	return {"floods": floods, "forward": forward}

func from_dict(d: Dictionary) -> void:
	floods = bool(d.get("floods", false))
	forward = bool(d.get("forward", false))
	_apply()
	changed.emit()
```

- [ ] **Step 5: Wire it into `Ship`**

In `src/ship/ship.gd`, add this field beside `var quantum`:

```gdscript
## The work lights (ship exterior spec §6, §7). On the hull, so the floating
## origin carries them; kept across rebuilds, like Airlocks.
var lights: ShipLights
```

In `_ready()`, right after `add_child(quantum)`:

```gdscript
	lights = ShipLights.new()
	lights.name = "Lights"
	lights.quantum = quantum
	exterior.add_child(lights)
```

In `_rebuild_everything()`, right after `flight_computer.quantum = quantum.store`:

```gdscript
	if lights != null:
		lights.bind(exterior_builder.light_mounts(), exterior_builder.lenses(), exterior_builder.window_glow())
```

In `to_dict()`, add `"lights": lights.to_dict() if lights != null else {},` after `"store"`. In `restore_aboard()`, after the store:

```gdscript
	if lights != null:
		lights.from_dict(d.get("lights", {}))
```

Update `to_dict()`'s doc comment to include "its lights".

Add `"res://src/ship/ship_lights.gd"` to `PAINTING_FILES`.

- [ ] **Step 6: Import, run the tests, then the full suite**

Run: `& $GODOT --headless --path who-knows --import`, then `who-knows/run_tests.ps1 -gselect=test_ship_lights`, then `who-knows/run_tests.ps1`
Expected: PASS, including `test_floating_origin_scene`, since the lights and beams sit under the hull body.

- [ ] **Step 7: Commit**

```bash
git add -A who-knows/src/ship who-knows/test/unit/test_ship_lights.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: ShipLights -- spot lights and faint beams, dimmed in low power, saved

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: The helm's keys, the HUD line and the controls card

**Files:**
- Modify: `project.godot` (the `[input]` section)
- Modify: `src/flight/pilot_controls.gd` (`var lights`, `handle`, `build_telemetry`)
- Modify: `src/ui/vehicle_telemetry.gd`, adding three fields
- Modify: `src/ui/panels/velocity_panel.gd`, adding a lights line
- Modify: `src/ui/controls_card.gd` (`ROWS`)
- Modify: `scenes/flight_test.gd` (`_wire_hud`)
- Test: `test/unit/test_input_map.gd`, `test/unit/test_hud_panels.gd` (append), `test/unit/test_ship_lights.gd` (append)

**Interfaces:**
- Consumes: `ShipLights.toggle`, `floods`, `forward`.
- Produces:
  - input actions `lights_flood` (L, physical keycode 76) and `lights_forward` (K, 75);
  - `PilotControls.lights: ShipLights`;
  - `VehicleTelemetry.has_lights`, `floods_on`, `forward_on`;
  - `VelocityPanel.lights_label`.

- [ ] **Step 1: Write the failing tests**

In `test/unit/test_input_map.gd`, add `&"lights_flood", &"lights_forward"` to `REQUIRED_ACTIONS`, and append:

```gdscript
## Ship exterior spec §7.2: the lights are on L and K.
func test_the_lights_are_on_l_and_k():
	var flood: InputEventKey = InputMap.action_get_events(&"lights_flood")[0]
	var fwd: InputEventKey = InputMap.action_get_events(&"lights_forward")[0]
	assert_eq(flood.physical_keycode, KEY_L)
	assert_eq(fwd.physical_keycode, KEY_K)
```

Append to `test/unit/test_ship_lights.gd`:

```gdscript
func _action(name: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e

## Spec §7.2: L and K toggle the groups while you sit, and do nothing standing.
func test_l_and_k_toggle_the_lights_only_while_seated():
	var pilot := PilotControls.new()
	pilot.lights = _lights
	pilot.handle(_action(&"lights_flood"))
	assert_false(_lights.floods, "standing: nothing")
	pilot.seated = true
	pilot.handle(_action(&"lights_flood"))
	assert_true(_lights.floods)
	pilot.handle(_action(&"lights_forward"))
	assert_true(_lights.forward)
	pilot.handle(_action(&"lights_flood"))
	assert_false(_lights.floods, "L again turns them off")
	pilot.free()
```

Append to `test/unit/test_hud_panels.gd`. First look at how its existing velocity-panel tests make the panel and call `render`, and use the same setup. The panel variable is `panel` below:

```gdscript
## Ship exterior spec §7.2: the HUD shows the lights while you fly.
func test_the_velocity_panel_shows_the_lights():
	var panel := VelocityPanel.new()
	add_child_autofree(panel)
	var t := VehicleTelemetry.new()
	panel.render(t)
	assert_eq(panel.lights_label.text, "", "a vehicle with no lights shows none")
	t.has_lights = true
	t.floods_on = true
	panel.render(t)
	assert_eq(panel.lights_label.text, "FLOOD ON   FWD OFF")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `who-knows/run_tests.ps1 -gselect=test_input_map`
Expected: FAIL: `lights_flood` is not registered.

- [ ] **Step 3: Add the actions to `project.godot`**

In the `[input]` section, after the `toggle_controls={...}` block, add these two blocks. **No comments**:

```
lights_flood={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":76,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
lights_forward={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":75,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
```

- [ ] **Step 4: The pilot's lights, the telemetry and the panel**

In `src/flight/pilot_controls.gd`, beside `var pointer`:

```gdscript
## The ship's work lights (ship exterior spec §7.2), set by the flight scene:
## L and K switch them while you sit.
var lights: ShipLights
```

In `handle()`, before the final `toggle_assist` branch:

```gdscript
	elif event.is_action_pressed(&"lights_flood"):
		if lights != null:
			lights.toggle(ShipLights.FLOOD)
	elif event.is_action_pressed(&"lights_forward"):
		if lights != null:
			lights.toggle(ShipLights.FORWARD)
```

In `build_telemetry()`, before `return t`:

```gdscript
	if lights != null:
		t.has_lights = true
		t.floods_on = lights.floods
		t.forward_on = lights.forward
```

In `src/ui/vehicle_telemetry.gd`, after `boost_refused`:

```gdscript
## The work lights (ship exterior spec §7.2), set by PilotControls: whether
## this vehicle has any, and whether each group is on.
var has_lights: bool = false
var floods_on: bool = false
var forward_on: bool = false
```

In `src/ui/panels/velocity_panel.gd`:
- declare `var lights_label: Label` beside `hold_label`;
- raise `custom_minimum_size` from `Vector2(320.0, 56.0)` to `Vector2(320.0, 74.0)`;
- after `hold_label` is created in `_ready`, add:

```gdscript
	lights_label = Label.new()
	lights_label.text = ""
	lights_label.add_theme_font_size_override("font_size", 11)
	lights_label.add_theme_color_override("font_color", HudPalette.READOUT)
	lights_label.position = Vector2(170.0, 56.0)
	add_child(lights_label)
```

At the end of `render`:

```gdscript
	# The work lights (ship exterior spec §7.2).
	lights_label.text = "FLOOD %s   FWD %s" % ["ON" if telemetry.floods_on else "OFF",
		"ON" if telemetry.forward_on else "OFF"] if telemetry.has_lights else ""
```

In `src/ui/controls_card.gd` `ROWS`, before the `cycle_camera` row:

```gdscript
	[[&"lights_flood"], "Floods", " "],
	[[&"lights_forward"], "Forward lights", " "],
```

In `scenes/flight_test.gd` `_wire_hud()`, add `_pilot.lights = _ship.lights`.

- [ ] **Step 5: Run the tests, then the full suite**

Run: `-gselect=test_input_map`, `-gselect=test_ship_lights`, `-gselect=test_hud_panels`, `-gselect=test_controls_card`, then `who-knows/run_tests.ps1`
Expected: PASS.

- [ ] **Step 6: Read `project.godot` back at runtime**

`test_the_lights_are_on_l_and_k` reads the bindings back at runtime, which is the check CLAUDE.md asks for.

- [ ] **Step 7: Commit**

```bash
git add who-knows/project.godot who-knows/src/flight/pilot_controls.gd who-knows/src/ui who-knows/scenes/flight_test.gd who-knows/test/unit
git commit -m "feat: L and K switch the floods and forward lights; the HUD and card show them

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: The bridge's lights panel

**Files:**
- Create: `src/ship/lights_panel.gd`
- Modify: `src/ship/interior/interior_props.gd`, adding `lights_panel`, its frames and constants
- Modify: `src/ship/interior/interior_dressing.gd`, adding `_lights_panel_cell` and `_lights_panel` and calling them in `_cockpit`
- Modify: `src/ship/interior_builder.gd`, adding `lights_panels()`
- Modify: `src/ship/ship.gd`, binding the panels after a rebuild
- Modify: `src/audio/synth.gd`, adding `light_switch`
- Modify: `test/unit/test_visual_style_rules.gd`, adding `lights_panel.gd` to `PAINTING_FILES`
- Test: `test/unit/test_lights_panel.gd`

**Interfaces:**
- Consumes: `ShipLights`; `ReadoutPanel.setup(role, layer_bits, render_layer, size, has_screen)`, `set_readout(lines, state)`, `make_readout(layer, width)`, `pressed`, `prompt_source`; `InteriorDressing.wall_frame`.
- Produces:
  - `LightsPanel` (`Node3D`) with `cell: Vector3i`, `buttons: Dictionary`, `setup(render_layer)` and `bind(lights: ShipLights)`;
  - `InteriorBuilder.lights_panels() -> Array[LightsPanel]`;
  - the `Synth` sound `&"light_switch"`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_lights_panel.gd`:

```gdscript
extends GutTest

## Ship exterior spec §7.3: a two-button lights panel on the starboard
## shoulder wall, beside its window, reachable standing.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.save_enabled = false
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func _panel() -> LightsPanel:
	var panels := _ship.interior_builder.lights_panels()
	assert_eq(panels.size(), 1)
	return panels[0]

func test_it_is_on_the_starboard_shoulder():
	assert_eq(_panel().cell, Vector3i(1, 0, -3))

func test_its_buttons_switch_the_ship_s_lights():
	var p := _panel()
	var flood: ReadoutPanel = p.buttons[&"flood"]
	assert_eq(flood.prompt_text(), "Floods on")
	assert_eq(flood.button_state(), &"", "unlit while off")
	flood.interact(null)
	assert_true(_ship.lights.floods)
	assert_eq(flood.button_state(), &"go", "lit SIGNAL_GO while on")
	assert_eq(flood.prompt_text(), "Floods off")
	_ship.lights.toggle(&"forward")
	assert_eq(p.buttons[&"forward"].button_state(), &"go", "the helm's keys show on the panel too")

func test_it_is_within_reach_standing_beside_the_desk():
	var eye := _ship.interior.global_transform * (Vector3(2.0, InteriorBuilder.floor_y(Vector3i(1, 0, -2)) + 1.6, -4.0))
	for group in [&"flood", &"forward"]:
		assert_lt(eye.distance_to(_panel().buttons[group].global_position), 2.5, "within the Interactor's reach")

func test_a_rebuild_binds_the_new_panel():
	_ship._rebuild_everything()
	var p := _panel()
	p.buttons[&"forward"].interact(null)
	assert_true(_ship.lights.forward)

func test_the_switch_has_a_sound():
	assert_true(Synth.NAMES.has(&"light_switch"))
	assert_gt(Synth.build(&"light_switch").get_length(), 0.0)
```

Before relying on it, check that `Synth.build` exists and returns an `AudioStreamWAV`; the file's doc says "build() makes one sound from scratch". If its name differs, use the real one here.

- [ ] **Step 2: Run the test to verify it fails**

Run: `who-knows/run_tests.ps1 -gselect=test_lights_panel`
Expected: FAIL: `LightsPanel` is not declared.

- [ ] **Step 3: The panel prop in `InteriorProps`**

Append:

```gdscript
## The lights panel (ship exterior spec §7.3): where it goes on a shoulder
## wall (across toward the pod, and height, in the wall's frame), its plate,
## and its two buttons.
const LIGHTS_PANEL_ACROSS := 0.82
const LIGHTS_PANEL_HEIGHT := 1.45
const LIGHTS_PANEL_SIZE := Vector2(0.34, 0.66)
const LIGHTS_PANEL_DEPTH := 0.04
const LIGHTS_BUTTON := Vector3(0.24, 0.16, 0.05)

## The panel's plate, in a frame on the wall's surface, +z out into the room:
## trim, with a screen-black strip over each button for its label.
static func lights_panel(kit: InteriorKit, f: Transform3D) -> void:
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0, LIGHTS_PANEL_DEPTH * 0.5)),
		Vector3(LIGHTS_PANEL_SIZE.x, LIGHTS_PANEL_SIZE.y, LIGHTS_PANEL_DEPTH), 0.02, _c(InteriorPalette.TRIM))
	for label in lights_panel_labels():
		kit.box(SOLID, f * label * _at(Vector3(0, 0, -0.003)), Vector3(0.26, 0.07, 0.004),
			_c(InteriorPalette.SCREEN_BACK))

## The FLOOD button, then the FWD one, in the panel's frame.
static func lights_panel_buttons() -> Array[Transform3D]:
	return [_at(Vector3(0, 0.12, LIGHTS_PANEL_DEPTH)), _at(Vector3(0, -0.2, LIGHTS_PANEL_DEPTH))]

## Where each button's label reads, just above it.
static func lights_panel_labels() -> Array[Transform3D]:
	return [_at(Vector3(0, 0.26, LIGHTS_PANEL_DEPTH + 0.006)), _at(Vector3(0, -0.06, LIGHTS_PANEL_DEPTH + 0.006))]
```

- [ ] **Step 4: Write `src/ship/lights_panel.gd`**

```gdscript
class_name LightsPanel
extends Node3D

## The lights panel on the bridge (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §7.3): FLOOD and FWD, two big buttons,
## each lit SIGNAL_GO while its group is on. It drives the same ShipLights as
## the helm's keys, so either shows what the other did. The dressing places it
## and the ship binds it after each rebuild.

const GROUPS: Array[StringName] = [&"flood", &"forward"]
const LABELS := {&"flood": "FLOOD", &"forward": "FWD"}
const PROMPTS := {&"flood": "Floods", &"forward": "Forward lights"}

## The shoulder cell it is on.
var cell := Vector3i.ZERO
var buttons: Dictionary = {}   # StringName -> ReadoutPanel

var _lights: ShipLights
var _click: AudioStreamPlayer3D

## Builds the buttons and labels in this node's frame (on the wall, +z into
## the room). Call once, before it enters the tree.
func setup(render_layer: int) -> void:
	var frames := InteriorProps.lights_panel_buttons()
	var labels := InteriorProps.lights_panel_labels()
	for i in GROUPS.size():
		var group := GROUPS[i]
		var button := ReadoutPanel.new()
		button.setup(group, InteriorKit.LAYER, render_layer, InteriorProps.LIGHTS_BUTTON, false)
		button.transform = frames[i]
		button.prompt_source = func() -> String: return _prompt(group)
		button.pressed.connect(func(_role: StringName) -> void: _press(group))
		add_child(button)
		buttons[group] = button
		var label := ReadoutPanel.make_readout(render_layer, 120.0)
		label.text = LABELS[group]
		label.transform = labels[i]
		add_child(label)
	_click = AudioStreamPlayer3D.new()
	_click.name = "Click"
	_click.bus = AudioBuses.SHIP
	add_child(_click)
	_show()

func bind(lights: ShipLights) -> void:
	if _lights != null and _lights.changed.is_connected(_show):
		_lights.changed.disconnect(_show)
	_lights = lights
	if _lights != null:
		_lights.changed.connect(_show)
	_show()

func _prompt(group: StringName) -> String:
	if _lights == null:
		return ""
	return "%s %s" % [PROMPTS[group], "off" if _lights.is_on(group) else "on"]

func _press(group: StringName) -> void:
	if _lights == null:
		return
	_lights.toggle(group)
	var s := Synth.sound(&"light_switch")
	if s != null and _click.is_inside_tree():
		_click.stream = s
		_click.play()

func _show() -> void:
	for group: StringName in buttons:
		var on := _lights != null and _lights.is_on(group)
		(buttons[group] as ReadoutPanel).set_readout(PackedStringArray(), &"go" if on else &"")
```

- [ ] **Step 5: Place it in `InteriorDressing._cockpit`**

At the top of `_cockpit`, after `fixture_cells` is filled:

```gdscript
	var panel_at := _lights_panel_cell(group, fixture_cells)
```

In the `else` branch, after `InteriorProps.shoulder(...)`:

```gdscript
			if panel_at.has(coord):
				_lights_panel(kit, coord, normal, pods[0])
```

Add:

```gdscript
## The shoulder the lights panel goes on (ship exterior spec §7.3): the
## starboard one first, then the nearer the helm. Never one where a fixture
## stands. Empty with no shoulder to put it on.
static func _lights_panel_cell(group: Dictionary, fixture_cells: Dictionary) -> Array[Vector3i]:
	var pods: Array = group["pods"]
	var across := Vector3.UP.cross(-Vector3(group["normal"] as Vector3i))
	var helm: Vector3i = pods[0]
	var best: Array[Vector3i] = []
	var best_rank := Vector2(INF, INF)
	for coord: Vector3i in group["coords"]:
		if pods.has(coord) or fixture_cells.has(coord):
			continue
		var side := Vector3(coord - helm).dot(across)
		var rank := Vector2(0.0 if side > 0.0 else 1.0, absf(side))
		if rank < best_rank:
			best_rank = rank
			best = [coord]
	return best

## The lights panel on a shoulder's wall, beside its window on the side
## toward the helm, above the desk.
static func _lights_panel(kit: InteriorKit, coord: Vector3i, normal: Vector3i, helm: Vector3i) -> void:
	var wall := wall_frame(coord, normal)
	var toward := signf(Vector3(helm - coord).dot(wall.basis.x))
	if toward == 0.0:
		toward = 1.0
	var f := wall * InteriorKit.at(Vector3(toward * InteriorProps.LIGHTS_PANEL_ACROSS,
		InteriorProps.LIGHTS_PANEL_HEIGHT, -InteriorProps.WALL_THICKNESS * 0.5))
	InteriorProps.lights_panel(kit, f)
	var panel := LightsPanel.new()
	panel.name = "LightsPanel_%d_%d_%d" % [coord.x, coord.y, coord.z]
	panel.cell = coord
	panel.transform = f
	panel.setup(kit.layer)
	kit.root.add_child(panel)
```

In `src/ship/interior_builder.gd`, beside `computers()`:

```gdscript
## The bridge's lights panels (ship exterior spec §7.3), for the ship to bind.
func lights_panels() -> Array[LightsPanel]:
	var out: Array[LightsPanel] = []
	if is_instance_valid(_physics_body):
		for node in _physics_body.find_children("*", "LightsPanel", true, false):
			out.append(node as LightsPanel)
	return out
```

In `Ship._rebuild_everything()`, right after `lights.bind(...)`:

```gdscript
		for panel in interior_builder.lights_panels():
			panel.bind(lights)
```

- [ ] **Step 6: The switch sound in `src/audio/synth.gd`**

Add `&"light_switch"` to the end of `NAMES`. Add a branch to the `match` in `build`:

```gdscript
		&"light_switch":
			x = _light_switch()
```

Add the builder beside `_bolt_clunk`:

```gdscript
## A light switch (ship exterior spec §7.3): a short soft click with a low
## knock under it.
static func _light_switch() -> PackedFloat32Array:
	var n := _len(0.12)
	var click := _highpass(_noise(n, 41), 1500.0)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		x[i] = click[i] * exp(-t / 0.003) * 0.6 + sin(TAU * 140.0 * t) * exp(-t / 0.025) * 0.5
	return _gain(x, 0.5)
```

Check that noise seed 41 is not used by another builder. If it is, pick an unused one.

Add `"res://src/ship/lights_panel.gd"` to `PAINTING_FILES`.

- [ ] **Step 7: Import, run the tests, then the full suite**

Run: `& $GODOT --headless --path who-knows --import`, `-gselect=test_lights_panel`, then `who-knows/run_tests.ps1`
Expected: PASS. Interior tests may pin counts of interactables, colliders or lights on the bridge. If one fails because of the panel's two buttons, look at what it guards. Update the count only if the rule still holds (for example "one light per cell": the panel adds no light). Record each such change in the task report.

- [ ] **Step 8: Render the panel for the owner**

Use the probe's standing render near the starboard shoulder. If no view shows the panel, add one to `ship_probe.gd`: stand at cell (1, 0, −2) facing −z, eye height 1.6 m. Send it to the owner with the seated render.

- [ ] **Step 9: Commit**

```bash
git add -A who-knows/src who-knows/test/unit/test_lights_panel.gd who-knows/test/unit/test_visual_style_rules.gd .claude/skills/building-a-ship/ship_probe.gd
git commit -m "feat: a lights panel on the starboard shoulder -- FLOOD and FWD

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: A darker outside, bloom, and the colour chosen at the renders

**Files:**
- Modify: `src/world/space_palette.gd`, adding `AMBIENT`
- Modify: `scenes/flight_test.gd`, adding `_set_outside_mood()` and its constants
- Modify: `.claude/skills/building-a-ship/ship_probe.gd`, adding lit renders and a rock view
- Modify: `src/ship/hull_palette.gd`, where the losing work-light colour is deleted after the owner chooses
- Test: `test/unit/test_hud_scene_wiring.gd` (append)

**Interfaces:**
- Produces:
  - `SpacePalette.AMBIENT`;
  - `FlightTest.OUTSIDE_AMBIENT_ENERGY`, `OUTSIDE_GLOW_INTENSITY` and `OUTSIDE_GLOW_BLOOM`;
  - the world environment's ambient comes from a colour, and glow is on.

- [ ] **Step 1: Write the failing test**

Append to `test/unit/test_hud_scene_wiring.gd`, or wherever that file already loads `flight_test.tscn`; use its setup:

```gdscript
## Ship exterior spec §6.3: outside is dark until a light reaches it, and
## lights bloom. The interior keeps its own environment on its camera.
func test_the_outside_is_dark_and_blooms():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.save_enabled = false
	add_child_autofree(root)
	var env: Environment = root.get_node("WorldEnvironment").environment
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	assert_eq(env.ambient_light_color, SpacePalette.AMBIENT)
	assert_true(env.glow_enabled)
	var cam: Camera3D = root.get_node("Ship/Interior/Avatar/Head/Camera3D")
	assert_ne(cam.environment, env, "the interior's mood stays its own")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `who-knows/run_tests.ps1 -gselect=test_hud_scene_wiring`
Expected: FAIL: the ambient source is the sky.

- [ ] **Step 3: The outside mood**

In `src/world/space_palette.gd`, append:

```gdscript
## What reaches a rock's night side (ship exterior spec §6.3): almost nothing,
## so a ship's lights uncover it.
const AMBIENT := Color("0b0d12")
```

In `scenes/flight_test.gd`, add the constants beside `INTERIOR_ENVIRONMENT`:

```gdscript
## The outside's mood (ship exterior spec §6.3): a near-black ambient, so the
## sun's side of a rock reads as it did and its night side waits for your
## lights, and a gentle bloom on lenses, windows and strips. Tuned at the
## renders with the owner.
const OUTSIDE_AMBIENT_ENERGY := 0.4
const OUTSIDE_GLOW_INTENSITY := 0.6
const OUTSIDE_GLOW_BLOOM := 0.05
```

Call `_set_outside_mood()` in `_ready()` right after `_set_interior_mood()`, and add:

```gdscript
func _set_outside_mood() -> void:
	var env: Environment = $WorldEnvironment.environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = SpacePalette.AMBIENT
	env.ambient_light_energy = OUTSIDE_AMBIENT_ENERGY
	env.glow_enabled = true
	env.glow_intensity = OUTSIDE_GLOW_INTENSITY
	env.glow_bloom = OUTSIDE_GLOW_BLOOM
```

- [ ] **Step 4: Run the tests**

Run: `-gselect=test_hud_scene_wiring`, then `who-knows/run_tests.ps1`
Expected: PASS.

- [ ] **Step 5: Lit renders in the probe, including over a rock's night side**

In `ship_probe.gd`, add:

```gdscript
## Parks the hull 60 m off the nearest big rock's night side, nose on to it,
## still (ship exterior spec §10).
func _park_by_a_rock(scene: Node, ship: Ship) -> bool:
	var universe: Universe = scene.get_node("Universe")
	var best: Contact = null
	for c in ship.sensors.contacts(RockContacts.RANGE):
		if c.kind == RockContacts.KIND and (best == null or c.km < best.km):
			best = c
	if best == null:
		return false
	var sun: DirectionalLight3D = scene.get_node("DirectionalLight3D")
	var light_goes := -sun.global_basis.z
	var rock := universe.to_engine(best.point)
	var at := rock + light_goes * (best.radius + 60.0)
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	ship.exterior.global_transform = Transform3D(Basis.looking_at(rock - at, Vector3.UP), at)
	await _process_frames(30)
	return true
```

In `_run`, after the first `_hull_shots`, add:

```gdscript
	for lit in [["floods", true, false], ["forward", false, true], ["both", true, true]]:
		ship.lights.set_group(&"flood", lit[1])
		ship.lights.set_group(&"forward", lit[2])
		await _hull_shots(ship, "lit_%s" % lit[0])
	if await _park_by_a_rock(scene, ship):
		for lit in [["dark", false, false], ["both", true, true]]:
			ship.lights.set_group(&"flood", lit[1])
			ship.lights.set_group(&"forward", lit[2])
			await _hull_shots(ship, "rock_%s" % lit[0])
		print("fps     %.0f by a rock, both groups on" % await _fps(2.0))
	ship.lights.set_group(&"flood", false)
	ship.lights.set_group(&"forward", false)
```

Also measure fps seated with both groups on: after the existing `seated` shot, turn both on, `await _shot("seated_lit")` and print `fps`, then turn them off. Check the names `Contact.km`, `radius`, `point` and `RockContacts.KIND` against `src/sensors/` before running.

- [ ] **Step 5b: Show the star with the bloom**

The world environment's glow now blooms the star as well, and the star's glow was approved by the owner from renders (system skeleton spec §12). Add a probe shot that looks toward the star, with the bloom off and with it on. Find where `flight_test.gd` keeps its `StarSystem` and the star's `UniversePoint`. The owner judges it in Step 6.

`StarSystem` re-aims the sun every physics tick from the star to the focus. After `_park_by_a_rock` moves the hull, wait a physics frame, then read `-sun.global_basis.z` again. The rock's night side is the side facing away from the star.

The space dust (`SpaceDust`) is lit on layer 1, so the floods and forward lights should pick out flecks. Look for that in the renders: it is part of the "uncovering" the owner asked for.

- [ ] **Step 6: Render both colours for the owner**

Run the probe once with `HullPalette.WORK_LIGHT := WORK_LIGHT_WARM`. Then set it to `WORK_LIGHT_COOL`, run it again into a second directory, and set it back afterwards.

Send the owner the `rock_*`, `lit_both_*`, `seated_lit` and star renders from both runs, side by side, with the fps lines. Ask:
1. warm white or cool white?
2. is the outside dark enough, or too dark?
3. how bright are the beams?
4. is the star's glow still right with the bloom on?

**Wait for the answers.**

- [ ] **Step 7: Apply the owner's choices**

- Set `WORK_LIGHT` to the chosen constant and delete the other.
- Tune `OUTSIDE_AMBIENT_ENERGY`, `ShipLights.SETTINGS` energies and `HullMaterials.BEAM_ALPHA` as the owner asks.
- Record the chosen values and the fps in the spec's §6.2 and §6.3, and the fps in the style guide's §2.6 (Task 14 finishes that text).
- Every view must hold 120 fps. If one doesn't, the first lever is the flood count's shadows (already off). The next is the forward pair's shadow atlas size. Report before changing any other rule.

- [ ] **Step 8: Commit**

```bash
git add -A who-knows/src who-knows/scenes/flight_test.gd who-knows/test .claude/skills/building-a-ship/ship_probe.gd docs/superpowers/specs/2026-09-28-ship-exterior-design.md
git commit -m "feat: a darker outside with bloom; the work lights' colour chosen at the renders

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: The volumetric spike (a measurement, not a feature)

**Files:**
- Create (scratch, **never committed**): a copy of `ship_probe.gd` in the session's scratchpad directory, named `volumetric_spike.gd`

**Interfaces:** none; the output is a report.

This spike answers one question: **do real light shafts fit the frame budget?** Its code is thrown away whatever the answer.

- [ ] **Step 1: Write the spike probe**

Copy `ship_probe.gd` to the scratchpad as `volumetric_spike.gd`. In its `_run`, after parking by a rock (Task 12), add:

```gdscript
	var env: Environment = scene.get_node("WorldEnvironment").environment
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0
	for spot in ship.lights.spots(&"forward") + ship.lights.spots(&"flood"):
		var fog := FogVolume.new()
		fog.shape = RenderingServer.FOG_VOLUME_SHAPE_CONE
		var reach := spot.spot_range * 0.6
		var width := tan(deg_to_rad(spot.spot_angle)) * reach * 2.0
		fog.size = Vector3(width, reach, width)
		var material := FogMaterial.new()
		material.density = 0.02
		fog.material = material
		# A cone FogVolume points along its +y: turn it onto the spot's -z.
		fog.transform = spot.global_transform * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -reach * 0.5))
		ship.exterior.add_child(fog)
	ship.lights.set_group(&"flood", true)
	ship.lights.set_group(&"forward", true)
	await _hull_shots(ship, "volumetric")
	print("fps     %.0f volumetric, chase view by a rock" % await _fps(3.0))
```

Also measure seated, where the canopy's second render is included: sit as the probe does, then `print("fps     %.0f volumetric, seated" % await _fps(3.0))`.

- [ ] **Step 2: Run it without `--headless`, at 1280×720**

Run: `& $GODOT --path who-knows --resolution 1280x720 --script <scratchpad>/volumetric_spike.gd -- <scratch out dir>`

- [ ] **Step 3: Report to the owner**

Send the `volumetric_*` renders next to Task 12's `rock_both_*` renders, with both fps numbers. Say plainly whether the worst view held 120 fps.
- **If it did not:** say that the cones stand, as the spec decides.
- **If it did:** say so, and ask whether they want it.
  - If yes, add a follow-up task to this plan, "Adopt volumetric shafts". Build it with TDD like the others: the environment settings in `_set_outside_mood`, a `FogVolume` per beam made in `ShipLights.bind`, and a test that they exist and sit under the hull. Amend the spec's §6.4 and the style guide's §2.6 with the numbers.

Also measure flood shadows the same way: set `shadow_enabled` on the flood spots in the spike and print fps. Report whether they fit.

- [ ] **Step 4: Nothing to commit**

The spike's files stay in the scratchpad. Only the measured numbers are recorded, in Task 14.

---

### Task 14: The records: the style guide, the skill, the specs

**Files:**
- Modify: `docs/design/visual-style.md` (new §3.6; §4, §5 and §2.6)
- Modify: `.claude/skills/building-a-ship/SKILL.md`, `reference.md`, `ship_probe.gd`
- Modify: `docs/superpowers/specs/2026-09-28-ship-exterior-design.md` (status "Built", and what differs)
- Modify: `docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md` (§2 and §3 amendment notes)
- Modify: `docs/superpowers/specs/2026-09-25-bridge-computer-design.md` (§7.1: `hull_meshes()`)

- [ ] **Step 1: The style guide**

Add **§3.6, "The hull's outside"**, after §3.5, covering:
- **The skin:** generated over the grid like the interior (`HullLayout` → `HullDressing` → `HullProps`, built with `InteriorKit` on the own-hull layer). Give the numbers: a plate per exposed face, standing `PLATE_PROUD` off a seam, `PLATE_GAP` apart; a 0.4 m chamfer on every convex edge; a facet where three meet; no chamfer into a concave corner or a shaped block.
- **Fairings are how a ship tapers:** six light shapes at 0.3 t, one block per taper. `hull_wedge` and `canopy` are the same wedge.
- **Windows match the interior:** every interior window has one outside at the same height, and nothing outside is a window that isn't one inside. Glass from outside is dark amber with warm bands, dimming with the ship. A pod's canopy face is the pod shell, and the shoulders are plate with a window.
- **Running strips:** cyan, glow only.
- **Lights:** floods and a forward pair at generated mounts; `WORK_LIGHT` (the chosen colour); they light the world and the hull, never the interior. Beams are faint additive cones, fading along and at rock.
- **Outside is dark:** `SpacePalette.AMBIENT` and a gentle bloom on the world environment. The interior keeps its own environment.

Then:
- **§4:** in "Anything on the hull's outside", point to §3.6. Add a line on a new hull prop: "in `HullProps`, from a kit and a frame; colours from `HullPalette`; tested in a bare frame in `test_hull_props.gd`".
- **§5:** list the new files, as `test_visual_style_rules.gd` now does.
- **§2.6:** add the measured fps: the hull views, seated with the lights on, by a rock with both groups on (Task 12), and the volumetric spike's numbers (Task 13).
- Update the header's status line: "extended 2026-09-28 for the ship's exterior (owner-approved design, `docs/superpowers/specs/2026-09-28-ship-exterior-design.md`)".

- [ ] **Step 2: The building-a-ship skill**

In `SKILL.md`:
- **Checklist:**
  - step 1 gains: "Shape the outside with fairings, outside the cabin row; the skin chamfers the rest";
  - step 6 gains: "`Ship` makes its `ShipLights`; the scene sets `PilotControls.lights`";
  - step 8 lists the new probe lines;
  - step 9 adds the hull views, lit and dark, and by a rock.
- ***Mistakes already made*** gains these rows (and any others the build hit):
  - a fairing placed in the cabin row;
  - a window inside with none outside (`unmatched` non-empty), usually two solid cells between the room and space;
  - an RCS exhaust closed by a fairing;
  - "balance by weakening RCS" again, now for the spine's raised mass.
- ***Not built yet*** gains: light blocks placed by hand; volumetric shafts, unless Task 13 adopted them; asteroid tunnels.

In `reference.md`:
- add the six fairings to the block table (0.3 t, 40 hp, solid, structure);
- add `O_KEEL = 2` to the orientation table;
- add a section "**The hull's outside**" with:
  - `HullShapes`, `HullLayout`'s records and their keys, `HullDressing.build`'s result, the `ExteriorBuilder` accessors, `ShipLights`' API and `SETTINGS`, the save part, L and K;
  - the starter's new figures: blocks, mass, centre of mass, inertia, budgets, imbalance, feel;
  - its mounts: 6 floods and 2 forward.

In `ship_probe.gd`, make sure it prints:

```gdscript
	var hull := ship.exterior_builder.layout()
	print("skin    %d plates, %d chamfers, %d corners, %d facets, %d nozzles" % [hull.plates.size(),
		hull.edges.size(), hull.corners.size(), hull.facets.size(), hull.nozzles.size()])
	print("windows %d outside for %d inside%s" % [hull.windows.size(), hull.wanted,
		"" if hull.unmatched.is_empty() else "  <-- UNMATCHED %s" % [hull.unmatched]])
	print("lights  %d floods, %d forward" % [ship.lights.spots(&"flood").size(), ship.lights.spots(&"forward").size()])
```

- [ ] **Step 3: The specs**

- **This spec's header:** "Built 2026-MM-DD on branch `ship-exterior`". Add a final section listing every place the build differed from the text, with the owner's choices from the renders.
- **The art direction spec:** add an amendment note at §2 (the envelope is now 3 cells tall at the spine, with a keel) and at §3 (the fairing cells).
- **The bridge computer spec §7.1:** the miniature shares `hull_meshes()` since the ship exterior spec.

- [ ] **Step 4: Run the full suite and the probe one last time**

Run: `who-knows/run_tests.ps1`, then the probe without `--headless`.
Expected:
- all tests pass;
- the probe prints `windows N outside for N inside` with no `UNMATCHED`, `lights  6 floods, 2 forward`, no `BLOCKED` beyond the known ones, no `STUCK`, and no `SHADER ERROR`;
- every fps line is at least 120.

Send the final renders to the owner.

- [ ] **Step 5: Commit**

```bash
git add -A docs .claude/skills/building-a-ship
git commit -m "docs: record the ship exterior -- style guide §3.6, the skill, the specs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then use superpowers:finishing-a-development-branch.
