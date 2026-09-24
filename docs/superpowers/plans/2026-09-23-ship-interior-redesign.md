# Ship Interior Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the starter shuttle's bare box cabin into a stylized, warm, dim spaceship interior (chunky bevelled props, a rounded cockpit nose with projected windows, portholes), and then divide it into a bridge, a corridor and five rooms with sliding doors, all generated from the ship grid.

**Architecture:** `InteriorLayout` decides what every interior face is. `InteriorBuilder` turns that into structure: colliders and wall, floor and ceiling boxes. `InteriorDressing` turns it into props from `InteriorProps`, a reusable asset library that never sees a grid. The props build through `InteriorKit`, which batches geometry into one merged mesh per material. Rooms are grid data (room blocks), so a future blueprint generator can emit them.

**Tech Stack:** Godot 4.5.1 (Forward+), GDScript only, GUT 9.5 for tests.

**Spec:** `docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md`. Read it before starting any task. Its §4 frame convention and §5.1/§7.2 layout rules are load-bearing.

## Global Constraints

- **Engine:** Godot 4.5.1 stable, Forward+, GDScript only. Never add a C# script. Executable: `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe` (overridable with `GODOT_BIN`).
- **Project root** is `who-knows/` (`res://`). Paths in this plan are relative to the repo root `D:\git\whoknows` unless they start with `res://`.
- **Branch:** `interior-redesign`. Never create or switch branches.
- **Cell size** is `ShipGrid.CELL_SIZE` (2.0). Never hardcode it outside `InteriorProps`' own design constants, and those are guarded by a test.
- **Interior render layer 2:** every interior `MeshInstance3D` has `layers = 2`. Every interior light has `light_cull_mask = 2` and `shadow_enabled = false`.
- **Interior collision:** one `StaticBody3D` per rebuild, `collision_layer = 2`, `collision_mask = 0`. Every dressing collider is a direct child of that body and is in group `InteriorKit.GROUP` (`&"interior_dressing"`).
- **Colours** come only from `InteriorPalette`. No colour literals anywhere else in the interior code.
- **Props never see the grid:** nothing in `interior_props.gd` or `interior_kit.gd` may reference `ShipGrid`, `InteriorLayout`, `InteriorBuilder` or `InteriorDressing`.
- **`InteriorLayout` never references `InteriorBuilder`, `InteriorDressing` or `ExteriorBuilder`.** The builder never references `ExteriorBuilder`.
- **`.tscn`/`.tres`: no `#` comments anywhere** (CLAUDE.md). Prove every scene or resource edit by reading the value back at runtime in a test, not by a clean load.
- **Tests:** GUT, `who-knows/test/unit/test_<subject>.gd`, `extends GutTest`, methods `test_<behaviour>()`. Output must be pristine: no `SCRIPT ERROR`, `ERROR` or stray warnings. Free every node you create (`add_child_autofree`, `autofree`).
- **New `class_name`s:** run the import pass before the first test run after adding one, or GDScript reports `Identifier "X" not declared`:
  ```powershell
  & "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path "D:\git\whoknows\who-knows" --import
  ```
- **Godot writes `.uid` files** next to new `.gd` and `.gdshader` files. Commit them with the file.
- **Run one test file:** `powershell -File D:\git\whoknows\who-knows\run_tests.ps1 -gselect=test_interior_layout`. **Run the full suite:** `powershell -File D:\git\whoknows\who-knows\run_tests.ps1`. The baseline before this plan is 164 passing.
- **Commit messages** end with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File map

| File | Status | Responsibility |
|---|---|---|
| `who-knows/src/ship/interior/interior_layout.gd` | new | what every face is (records) |
| `who-knows/src/ship/interior/interior_palette.gd` | new | colours |
| `who-knows/src/ship/interior/interior_materials.gd` | new | cached materials |
| `who-knows/src/ship/interior/interior_kit.gd` | new | mesh toolkit, batching, lights, colliders |
| `who-knows/src/ship/interior/interior_props.gd` | new | the reusable prop library |
| `who-knows/src/ship/interior/interior_dressing.gd` | new | layout records → props |
| `who-knows/src/ship/interior/sliding_door.gd` | new (Phase B) | self-contained sliding door |
| `who-knows/data/materials/interior/glow.gdshader` | new | lit strips and indicators |
| `who-knows/data/materials/interior/screen.gdshader` | new | animated readouts |
| `who-knows/data/materials/interior/canopy_window.gdshader` | new | nose shell and projected windows |
| `who-knows/data/environments/ship_interior.tres` | new | interior camera environment |
| `who-knows/data/blocks/{bunk_room,galley,bathroom,closet,weapon_room}.tres` | new (Phase B) | room blocks |
| `who-knows/src/ship/interior_builder.gd` | modified | structure from the layout |
| `who-knows/scenes/flight_test.tscn` | modified | canopy material, old lights removed |
| `who-knows/scenes/flight_test.gd` | modified | canopy uniforms, interior environment, Phase B blueprint |
| `who-knows/data/blocks/meshes/pilot_seat.tres` | modified | seat colour |
| `who-knows/test/unit/test_interior_*.gd`, `test_sliding_door.gd`, `test_starter_shuttle.gd` | new | tests |
| `who-knows/test/unit/test_interior_builder.gd`, `test_hud_scene_wiring.gd`, `test_block_data.gd` | modified | tests |

---

# Phase A — the style kit

### Task 1: InteriorLayout (common-area rules)

**Files:**
- Create: `who-knows/src/ship/interior/interior_layout.gd`
- Test: `who-knows/test/unit/test_interior_layout.gd`

**Interfaces:**
- Consumes: `ShipGrid` (`get_block`, `has_block`), `BlockCatalog.get_def`, `BlockDefinition.occupancy`, `DeckGraph.build(grid, catalog).walkable_coords()` (tests only).
- Produces:
  - `InteriorLayout.plan(grid: ShipGrid, catalog: BlockCatalog, walkable: Array) -> InteriorLayout`
  - `faces() -> Array[Dictionary]`: records `{coord: Vector3i, normal: Vector3i, kind: Kind, variant: WallVariant, zone: StringName, porthole: bool, owner: bool}`
  - `canopy_groups() -> Array[Dictionary]`: `{normal: Vector3i, coords: Array}`
  - `walkable_coords() -> Array[Vector3i]`
  - `static face_hash(coord: Vector3i, normal: Vector3i) -> int`
  - `enum Kind { FLOOR, CEILING, WALL, CANOPY }`
  - `enum WallVariant { NONE, HATCH, CONSOLE, PORTHOLE, LOCKERS, DISPLAY, PANEL }`
  - `const ZONE_BRIDGE := &"bridge"`, `const ZONE_COMMON := &"common"`

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_interior_layout.gd`:

```gdscript
extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid

func before_each():
	_cat = BlockCatalog.new()
	for id in [&"hull", &"canopy"]:
		_cat.register(_def(id, BlockDefinition.Occupancy.SOLID))
	for id in [&"deck", &"airlock"]:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))
	_cat.register(_def(&"seat", BlockDefinition.Occupancy.MOUNT))
	_grid = ShipGrid.new()

func _def(id: StringName, occ: BlockDefinition.Occupancy) -> BlockDefinition:
	var d := BlockDefinition.new()
	d.id = id
	d.display_name = String(id)
	d.occupancy = occ
	return d

func _put(coord: Vector3i, id: StringName) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	_grid.set_block(coord, i)

func _plan() -> InteriorLayout:
	return InteriorLayout.plan(_grid, _cat, DeckGraph.build(_grid, _cat).walkable_coords())

func _face(layout: InteriorLayout, coord: Vector3i, normal: Vector3i) -> Dictionary:
	for f in layout.faces():
		if f["coord"] == coord and f["normal"] == normal:
			return f
	return {}

func _count(layout: InteriorLayout, variant: InteriorLayout.WallVariant) -> int:
	var n := 0
	for f in layout.faces():
		if f["kind"] == InteriorLayout.Kind.WALL and f["variant"] == variant:
			n += 1
	return n

func test_every_walkable_cell_gets_a_floor_and_a_ceiling():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	var layout := _plan()
	for coord in [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]:
		assert_eq(_face(layout, coord, Vector3i.DOWN)["kind"], InteriorLayout.Kind.FLOOR)
		assert_eq(_face(layout, coord, Vector3i.UP)["kind"], InteriorLayout.Kind.CEILING)

func test_open_passage_between_walkable_cells_has_no_wall():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	assert_true(_face(_plan(), Vector3i(0, 0, 0), Vector3i(1, 0, 0)).is_empty())

func test_flank_on_the_outer_skin_gets_a_porthole():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")   # vacuum beyond: outer skin
	var f := _face(_plan(), Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	assert_eq(f["variant"], InteriorLayout.WallVariant.PORTHOLE)
	assert_true(f["porthole"], "the builder is told to cut it")

func test_flank_with_solid_beyond_gets_no_porthole():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(2, 0, 0), &"hull")   # a porthole here would look into machinery
	var f := _face(_plan(), Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	assert_ne(f["variant"], InteriorLayout.WallVariant.PORTHOLE)
	assert_false(f["porthole"])

func test_end_walls_never_get_portholes():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"hull")   # skin, but fore/aft
	assert_ne(_face(_plan(), Vector3i(0, 0, 0), Vector3i(0, 0, 1))["variant"],
		InteriorLayout.WallVariant.PORTHOLE)

func test_wall_beside_a_mount_is_a_console_even_on_the_skin():
	_put(Vector3i(0, 0, 0), &"seat")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(2, 0, 0), &"hull")   # skin flank, but by the helm
	assert_eq(_face(_plan(), Vector3i(1, 0, 0), Vector3i(1, 0, 0))["variant"],
		InteriorLayout.WallVariant.CONSOLE)

func test_mount_cells_own_walls_hold_nothing_that_protrudes():
	_put(Vector3i(0, 0, 0), &"seat")
	_put(Vector3i(1, 0, 0), &"hull")
	var layout := _plan()
	assert_eq(_face(layout, Vector3i(0, 0, 0), Vector3i(1, 0, 0))["variant"],
		InteriorLayout.WallVariant.PORTHOLE, "skin flank: a porthole is flat enough")
	assert_eq(_face(layout, Vector3i(0, 0, 0), Vector3i(0, 0, 1))["variant"],
		InteriorLayout.WallVariant.PANEL, "anything else stays flat")

func test_cockpit_row_walls_are_consoles():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, -1), &"canopy")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(2, 0, 0), &"hull")
	assert_eq(_face(_plan(), Vector3i(0, 0, 0), Vector3i(1, 0, 0))["variant"],
		InteriorLayout.WallVariant.CONSOLE)

func test_hatch_only_where_the_airlock_meets_vacuum():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(0, 0, -1), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(-1, 0, 0), &"hull")   # only the aft face opens onto vacuum
	var layout := _plan()
	assert_eq(_face(layout, Vector3i(0, 0, 0), Vector3i(0, 0, 1))["variant"],
		InteriorLayout.WallVariant.HATCH)
	assert_ne(_face(layout, Vector3i(0, 0, 0), Vector3i(1, 0, 0))["variant"],
		InteriorLayout.WallVariant.HATCH)
	assert_eq(_count(layout, InteriorLayout.WallVariant.HATCH), 1)

func test_every_wall_has_one_variant_and_canopies_have_none():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, -1), &"canopy")
	_put(Vector3i(0, 0, 1), &"airlock")
	for f in _plan().faces():
		match f["kind"]:
			InteriorLayout.Kind.WALL:
				assert_ne(f["variant"], InteriorLayout.WallVariant.NONE)
			_:
				assert_eq(f["variant"], InteriorLayout.WallVariant.NONE)

func test_porthole_flag_matches_the_porthole_variant():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(0, 0, 1), &"deck")
	for f in _plan().faces():
		if f["kind"] == InteriorLayout.Kind.WALL:
			assert_eq(f["porthole"], f["variant"] == InteriorLayout.WallVariant.PORTHOLE)

func test_bridge_zone_is_the_command_area():
	_put(Vector3i(0, 0, 0), &"seat")
	_put(Vector3i(0, 0, 1), &"deck")
	_put(Vector3i(0, 0, 2), &"deck")
	var layout := _plan()
	assert_eq(_face(layout, Vector3i(0, 0, 0), Vector3i.DOWN)["zone"], InteriorLayout.ZONE_BRIDGE)
	assert_eq(_face(layout, Vector3i(0, 0, 1), Vector3i.DOWN)["zone"], InteriorLayout.ZONE_BRIDGE,
		"beside the seat")
	assert_eq(_face(layout, Vector3i(0, 0, 2), Vector3i.DOWN)["zone"], InteriorLayout.ZONE_COMMON)

func test_canopy_faces_in_one_plane_form_one_group():
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 0, 0), &"deck")
		_put(Vector3i(x, 0, -1), &"canopy")
	var groups := _plan().canopy_groups()
	assert_eq(groups.size(), 1)
	assert_eq(groups[0]["normal"], Vector3i(0, 0, -1))
	assert_eq(groups[0]["coords"].size(), 3)

func test_canopies_on_different_planes_group_separately():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, -1), &"canopy")
	_put(Vector3i(5, 0, 3), &"deck")
	_put(Vector3i(5, 0, 2), &"canopy")
	assert_eq(_plan().canopy_groups().size(), 2)

func test_the_same_grid_always_plans_the_same():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"seat")
	_put(Vector3i(2, 0, 0), &"hull")
	assert_eq(_plan().faces(), _plan().faces())

## The real starter shuttle, as flight_test.gd builds it (art direction §3.1).
func test_starter_shuttle_layout():
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var grid: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	var catalog := BlockCatalog.load_from_dir("res://data/blocks")
	var layout := InteriorLayout.plan(grid, catalog, DeckGraph.build(grid, catalog).walkable_coords())
	assert_eq(_count(layout, InteriorLayout.WallVariant.CONSOLE), 4, "both walls of the two helm rows")
	assert_eq(_count(layout, InteriorLayout.WallVariant.PORTHOLE), 4, "flanks at z = -1 and 0")
	assert_eq(_count(layout, InteriorLayout.WallVariant.HATCH), 1)
	assert_eq(_count(layout, InteriorLayout.WallVariant.LOCKERS)
		+ _count(layout, InteriorLayout.WallVariant.DISPLAY), 8)
	assert_eq(layout.canopy_groups().size(), 1)
	assert_eq(layout.canopy_groups()[0]["coords"].size(), 3)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `powershell -File D:\git\whoknows\who-knows\run_tests.ps1 -gselect=test_interior_layout`
Expected: FAIL, with a parse error that `InteriorLayout` is not declared.

- [ ] **Step 3: Write the implementation**

Create `who-knows/src/ship/interior/interior_layout.gd`:

```gdscript
class_name InteriorLayout
extends RefCounted

## Decides what every interior face is, once, for both InteriorBuilder
## (structure) and InteriorDressing (props): a floor and a ceiling per
## walkable cell, and for each horizontal face that does not open onto
## another walkable cell, either a canopy face or a wall with exactly one
## variant (docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md
## §5.1).
##
## A record is {coord, normal, kind, variant, zone, porthole, owner}. `zone`
## is the cell's: bridge for the command area, common otherwise. `porthole`
## tells the builder to cut one. `owner` says which record builds a face's
## structure; every face has exactly one.
##
## Pure: reads the grid, returns records, touches no nodes. The same grid
## always yields the same layout.

enum Kind { FLOOR, CEILING, WALL, CANOPY }
enum WallVariant { NONE, HATCH, CONSOLE, PORTHOLE, LOCKERS, DISPLAY, PANEL }

const ZONE_BRIDGE := &"bridge"
const ZONE_COMMON := &"common"
const CANOPY_ID := &"canopy"
const AIRLOCK_ID := &"airlock"
const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _faces: Array[Dictionary] = []
var _groups: Array[Dictionary] = []
var _walkable: Array[Vector3i] = []

static func plan(grid: ShipGrid, catalog: BlockCatalog, walkable: Array) -> InteriorLayout:
	var layout := InteriorLayout.new()
	layout._walkable.assign(walkable)
	var walkable_set := {}
	for coord in walkable:
		walkable_set[coord] = true
	var groups := {}   # plane key -> {normal, coords}
	for coord: Vector3i in layout._walkable:
		var is_mount := _is_mount(grid, catalog, coord)
		var by_the_helm := _has_mount_neighbour(grid, catalog, coord) or _has_canopy_neighbour(grid, coord)
		var zone := ZONE_BRIDGE if is_mount or by_the_helm else ZONE_COMMON
		layout._faces.append(_record(coord, Vector3i.DOWN, Kind.FLOOR, zone))
		layout._faces.append(_record(coord, Vector3i.UP, Kind.CEILING, zone))
		for normal in _HORIZONTAL:
			var neighbour := coord + normal
			if walkable_set.has(neighbour):
				continue   # open passage between two walkable cells
			if _id_at(grid, neighbour) == CANOPY_ID:
				layout._faces.append(_record(coord, normal, Kind.CANOPY, zone))
				var key := "%s:%d:%d" % [normal, _along(neighbour, normal), coord.y]
				groups.get_or_add(key, {"normal": normal, "coords": []})["coords"].append(coord)
				continue
			var face := _record(coord, normal, Kind.WALL, zone)
			var variant := _common_variant(grid, coord, normal, is_mount, by_the_helm)
			face["variant"] = variant
			face["porthole"] = variant == WallVariant.PORTHOLE
			layout._faces.append(face)
	for key in groups:
		layout._groups.append(groups[key])
	return layout

func faces() -> Array[Dictionary]:
	return _faces.duplicate()

## One entry per windshield plane: {normal, coords} -- the walkable cells
## whose face on that plane is canopy. InteriorDressing builds one rounded
## nose over each.
func canopy_groups() -> Array[Dictionary]:
	return _groups.duplicate()

func walkable_coords() -> Array[Vector3i]:
	return _walkable.duplicate()

## A stable integer per face, for choosing between equally good variants and
## for seeding what a prop's screens show. Not random: the same face on the
## same ship always gets the same answer.
static func face_hash(coord: Vector3i, normal: Vector3i) -> int:
	return absi((coord.x * 73856093) ^ (coord.y * 19349663) ^ (coord.z * 83492791)
		^ (normal.x * 2654435761) ^ (normal.z * 40503))

static func _record(coord: Vector3i, normal: Vector3i, kind: Kind, zone: StringName) -> Dictionary:
	return {
		"coord": coord, "normal": normal, "kind": kind, "variant": WallVariant.NONE,
		"zone": zone, "porthole": false, "owner": true,
	}

## Wall variants for bridge and common cells, in strict priority order.
static func _common_variant(grid: ShipGrid, coord: Vector3i, normal: Vector3i,
		is_mount: bool, by_the_helm: bool) -> WallVariant:
	if _id_at(grid, coord) == AIRLOCK_ID and not grid.has_block(coord + normal):
		return WallVariant.HATCH
	var skin_flank := normal.x != 0 and _is_outer_skin(grid, coord, normal)
	if is_mount:
		# The cell's own fixture stands here; nothing that sticks out may too.
		return WallVariant.PORTHOLE if skin_flank else WallVariant.PANEL
	if by_the_helm:
		return WallVariant.CONSOLE
	if skin_flank:
		return WallVariant.PORTHOLE
	return WallVariant.LOCKERS if face_hash(coord, normal) % 2 == 0 else WallVariant.DISPLAY

## Outer skin: at most one solid cell stands between this face and vacuum,
## so a porthole here looks out rather than into machinery.
static func _is_outer_skin(grid: ShipGrid, coord: Vector3i, normal: Vector3i) -> bool:
	var neighbour := coord + normal
	return not grid.has_block(neighbour) or not grid.has_block(neighbour + normal)

static func _has_canopy_neighbour(grid: ShipGrid, coord: Vector3i) -> bool:
	for normal in _HORIZONTAL:
		if _id_at(grid, coord + normal) == CANOPY_ID:
			return true
	return false

static func _has_mount_neighbour(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> bool:
	for normal in _HORIZONTAL:
		if _is_mount(grid, catalog, coord + normal):
			return true
	return false

static func _is_mount(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> bool:
	var inst := grid.get_block(coord)
	if inst == null:
		return false
	var def := catalog.get_def(inst.block_id)
	return def != null and def.occupancy == BlockDefinition.Occupancy.MOUNT

static func _id_at(grid: ShipGrid, coord: Vector3i) -> StringName:
	var inst := grid.get_block(coord)
	return inst.block_id if inst != null else &""

## The coordinate that identifies a face's plane along its normal's axis.
static func _along(coord: Vector3i, normal: Vector3i) -> int:
	return coord.x if normal.x != 0 else coord.z
```

- [ ] **Step 4: Refresh the class cache and run the tests to verify they pass**

Run the import command from Global Constraints, then:
`powershell -File D:\git\whoknows\who-knows\run_tests.ps1 -gselect=test_interior_layout`
Expected: all passing, output pristine.

- [ ] **Step 5: Run the full suite, then commit**

Run: `powershell -File D:\git\whoknows\who-knows\run_tests.ps1`. Expected: no failures.

```bash
git add who-knows/src/ship/interior/interior_layout.gd who-knows/src/ship/interior/interior_layout.gd.uid who-knows/test/unit/test_interior_layout.gd who-knows/test/unit/test_interior_layout.gd.uid
git commit -m "feat: add InteriorLayout, deciding what every interior face is

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Palette, shaders and materials

**Files:**
- Create: `who-knows/src/ship/interior/interior_palette.gd`
- Create: `who-knows/data/materials/interior/glow.gdshader`
- Create: `who-knows/data/materials/interior/screen.gdshader`
- Create: `who-knows/data/materials/interior/canopy_window.gdshader`
- Create: `who-knows/src/ship/interior/interior_materials.gd`
- Test: `who-knows/test/unit/test_interior_materials.gd`

**Interfaces:**
- Produces:
  - `InteriorPalette` constants: `WALL`, `WALL_LOW`, `TRIM`, `BELT`, `CEILING`, `FLOOR`, `FLOOR_BRIDGE`, `SCREEN_BACK`, `WOOD`, `LIGHT_WARM`, `AMBER`, `SKY`, `CORAL`, `LAVENDER`, `GLASS`, `SEAT`
  - `InteriorMaterials.flat(color: Color) -> StandardMaterial3D`
  - `InteriorMaterials.props() -> StandardMaterial3D`
  - `InteriorMaterials.glow() -> ShaderMaterial`
  - `InteriorMaterials.screen() -> ShaderMaterial`
  - `InteriorMaterials.glass() -> StandardMaterial3D`
  - `InteriorMaterials.canopy_fallback() -> ShaderMaterial`
  - `InteriorMaterials.GLOW_ENERGY` (2.4), `GLOW_SHADER`, `SCREEN_SHADER`, `CANOPY_SHADER`
  - `canopy_window.gdshader` uniforms: `shell_color`, `frame_color`, `canopy_view`, `eye_world`, `tan_half_fov_y`, `aspect`, `view_energy`, `window_0..2`, `window_corner`, `frame_width`

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_interior_materials.gd`:

```gdscript
extends GutTest

func test_structure_is_flat_colour_with_no_rim():
	var m := InteriorMaterials.flat(InteriorPalette.WALL)
	assert_eq(m.albedo_color, InteriorPalette.WALL)
	assert_false(m.rim_enabled,
		"rim light on a surface seen edge-on (the whole ceiling) blows it out")

func test_materials_are_built_once_and_shared():
	assert_same(InteriorMaterials.flat(InteriorPalette.WALL), InteriorMaterials.flat(InteriorPalette.WALL))
	assert_same(InteriorMaterials.props(), InteriorMaterials.props())
	assert_same(InteriorMaterials.glow(), InteriorMaterials.glow())

func test_props_take_their_colour_from_vertices():
	var m := InteriorMaterials.props()
	assert_true(m.vertex_color_use_as_albedo)
	assert_true(m.rim_enabled, "a faint rim keeps chunky shapes apart in dim light")

func test_the_three_custom_shaders():
	assert_eq(InteriorMaterials.glow().shader, InteriorMaterials.GLOW_SHADER)
	assert_eq(InteriorMaterials.screen().shader, InteriorMaterials.SCREEN_SHADER)
	assert_eq(InteriorMaterials.canopy_fallback().shader, InteriorMaterials.CANOPY_SHADER)

func test_glow_energy_matches_what_the_kit_scales_by():
	assert_almost_eq(InteriorMaterials.glow().get_shader_parameter(&"energy"),
		InteriorMaterials.GLOW_ENERGY, 0.0001)

func test_screen_colours_come_from_the_palette():
	var m := InteriorMaterials.screen()
	assert_eq(m.get_shader_parameter(&"back_color"), InteriorPalette.SCREEN_BACK)
	assert_eq(m.get_shader_parameter(&"color_a"), InteriorPalette.AMBER)
	assert_eq(m.get_shader_parameter(&"color_b"), InteriorPalette.LAVENDER)
	assert_eq(m.get_shader_parameter(&"color_c"), InteriorPalette.SKY)
	assert_eq(m.get_shader_parameter(&"color_d"), InteriorPalette.CORAL)

func test_glass_is_transparent_and_vertex_tinted():
	var m := InteriorMaterials.glass()
	assert_eq(m.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_true(m.vertex_color_use_as_albedo)

func test_canopy_fallback_has_no_view_and_the_palette_colours():
	var m := InteriorMaterials.canopy_fallback()
	assert_null(m.get_shader_parameter(&"canopy_view"), "windows render black, never a hole")
	assert_eq(m.get_shader_parameter(&"shell_color"), InteriorPalette.WALL)
	assert_eq(m.get_shader_parameter(&"frame_color"), InteriorPalette.TRIM)
```

- [ ] **Step 2: Run to verify failure**

Run: `powershell -File D:\git\whoknows\who-knows\run_tests.ps1 -gselect=test_interior_materials`
Expected: FAIL, with `InteriorMaterials` not declared.

- [ ] **Step 3: Write the palette**

Create `who-knows/src/ship/interior/interior_palette.gd`:

```gdscript
class_name InteriorPalette
extends RefCounted

## Every ship-interior colour, from
## docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md §3.1:
## a stylized, warm, dim cabin -- chunky shapes in flat colour.
##
## Nothing else in the interior names a colour literal, so retuning the look
## (or one day giving a faction its own) is an edit here and nowhere else.

const WALL := Color("d8c7a8")
const WALL_LOW := Color("9c7b63")
const TRIM := Color("ede3d0")
## The terracotta stripe along every wall.
const BELT := Color("b0714e")
const CEILING := Color("cbbba0")
const FLOOR := Color("56607a")
## The command area: cells at the windshield, or at or beside a MOUNT.
const FLOOR_BRIDGE := Color("8a5a66")
const SCREEN_BACK := Color("1a1c23")
const WOOD := Color("9a5e3a")
const LIGHT_WARM := Color("ffd9a8")
const AMBER := Color("ffb45a")
const SKY := Color("8cc8f0")
const CORAL := Color("f07c5a")
const LAVENDER := Color("b9a6e0")
## Porthole glass, used raw (not linearised) with its alpha.
const GLASS := Color(0.55, 0.75, 0.9, 0.22)
## Pilot seat upholstery (data/blocks/meshes/pilot_seat.tres, surface 0).
const SEAT := Color("c4a27a")
```

- [ ] **Step 4: Write the three shaders**

Create `who-knows/data/materials/interior/glow.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, shadows_disabled;

// Every lit strip, lamp face and indicator in one material. The vertex colour
// is the piece's colour pre-scaled by its share of `energy` (InteriorKit.lit),
// so one merged mesh holds lights of different strengths; alpha below 1 marks
// a blinking light and doubles as its phase. Unshaded albedo above 1 lands in
// the HDR buffer, which is what the interior environment's glow blooms.
uniform float energy = 2.4;

void fragment() {
	float on = 1.0;
	if (COLOR.a < 0.99) {
		on = mix(0.12, 1.0, step(0.5, fract(TIME * (0.35 + COLOR.a) + COLOR.a * 7.0)));
	}
	ALBEDO = COLOR.rgb * energy * on;
}
```

Create `who-knows/data/materials/interior/screen.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, shadows_disabled;

// Chunky animated readouts: big shapes, few of them, slow changes. Nothing
// here reads ship state -- it is set dressing that moves. Vertex colour red
// picks the mode (0, 0.25, 0.5 = bars, wave, dots, InteriorKit.Screen);
// green is a per-screen seed so no two screens match.
uniform vec3 back_color : source_color = vec3(0.102, 0.11, 0.137);
uniform vec3 color_a : source_color = vec3(1.0, 0.706, 0.353);
uniform vec3 color_b : source_color = vec3(0.725, 0.651, 0.878);
uniform vec3 color_c : source_color = vec3(0.549, 0.784, 0.941);
uniform vec3 color_d : source_color = vec3(0.941, 0.486, 0.353);
uniform float energy = 1.2;

float screen_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 pick(float h) {
	if (h < 0.4) {
		return color_a;
	}
	if (h < 0.65) {
		return color_b;
	}
	if (h < 0.88) {
		return color_c;
	}
	return color_d;
}

void fragment() {
	int mode = int(floor(COLOR.r * 4.0 + 0.5));
	float seed = COLOR.g * 97.0;
	vec2 uv = UV;
	vec3 lit = vec3(0.0);
	if (mode == 0) {
		// Three rows of bars whose lengths step every few seconds.
		float r = floor(uv.y * 3.0);
		float fy = fract(uv.y * 3.0);
		float epoch = floor(TIME * 0.3 + screen_hash(vec2(r, seed)) * 3.0);
		float len = 0.25 + 0.65 * screen_hash(vec2(r + epoch, seed));
		float bar = step(0.08, uv.x) * step(uv.x, 0.08 + len * 0.84) * step(abs((fy - 0.5) * 0.333), 0.07);
		lit = pick(screen_hash(vec2(r, seed))) * bar;
	} else if (mode == 1) {
		float y = 0.5 + 0.28 * sin(uv.x * 9.0 + TIME * 1.6 + seed);
		lit = color_c * (1.0 - smoothstep(0.03, 0.06, abs(uv.y - y)));
	} else {
		vec2 grid = vec2(5.0, 2.0);
		vec2 cell = floor(uv * grid);
		float h = screen_hash(cell + seed);
		float dot_ = 1.0 - smoothstep(0.22, 0.28, length(fract(uv * grid) - 0.5));
		float on = step(0.5, fract(TIME * (0.15 + h * 0.6) + h));
		lit = pick(h) * dot_ * mix(0.25, 1.0, on);
	}
	ALBEDO = back_color + lit * energy;
}
```

Create `who-knows/data/materials/interior/canopy_window.gdshader`:

```glsl
shader_type spatial;
render_mode cull_disabled;

// The rounded cockpit nose: a flat-coloured shell with window openings cut
// by a rounded-rectangle mask in the shell's UV space (UV.x = arc length
// across the nose from its centre line, UV.y = height above the floor, both
// in metres; see InteriorProps.nose). Inside a window each fragment looks the
// canopy camera's view up by *direction from the pilot's eye*, so every
// window on the curve lines up into one continuous view and the velocity
// marker drawn into that view stays registered against it.

uniform vec3 shell_color : source_color = vec3(0.847, 0.78, 0.659);
uniform vec3 frame_color : source_color = vec3(0.929, 0.89, 0.816);
uniform sampler2D canopy_view : source_color, filter_linear, repeat_disable, hint_default_black;
uniform vec3 eye_world = vec3(0.0);
uniform float tan_half_fov_y = 0.36397;
uniform float aspect = 3.0;
uniform float view_energy = 1.0;

// (centre across, centre height, half width, half height), metres.
uniform vec4 window_0 = vec4(0.0, 1.325, 0.9, 0.375);
uniform vec4 window_1 = vec4(-1.95, 1.3, 0.5, 0.3);
uniform vec4 window_2 = vec4(1.95, 1.3, 0.5, 0.3);
uniform float window_corner = 0.14;
uniform float frame_width = 0.09;

varying vec3 world_pos;

float window_sd(vec2 p, vec4 w) {
	vec2 q = abs(p - w.xy) - w.zw + window_corner;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - window_corner;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float sd = min(window_sd(UV, window_0), min(window_sd(UV, window_1), window_sd(UV, window_2)));
	ROUGHNESS = 0.85;
	if (sd < 0.0) {
		// The canopy camera looks down -Z with the interior's own axes, so the
		// eye-to-fragment offset is already a view-space direction.
		vec3 d = world_pos - eye_world;
		vec3 view = vec3(0.0);
		if (d.z < -0.01) {
			vec2 ndc = vec2(d.x / (-d.z * tan_half_fov_y * aspect), d.y / (-d.z * tan_half_fov_y));
			vec2 uv = vec2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
			if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
				view = texture(canopy_view, uv).rgb;
			}
		}
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = view * view_energy;
	} else if (sd < frame_width) {
		ALBEDO = frame_color;
	} else {
		ALBEDO = shell_color;
	}
}
```

- [ ] **Step 5: Write the materials**

Create `who-knows/src/ship/interior/interior_materials.gd`:

```gdscript
class_name InteriorMaterials
extends RefCounted

## Builds the interior's materials, once each (spec §3.2). Structure and props
## are plain StandardMaterial3D in flat colour: the stylized look needs no
## texture work, and it keeps the GPU cost down. Only three things need
## custom shaders -- lit strips and indicators (glow), animated screens
## (screen), and the cockpit nose's projected windows (canopy_window).

const GLOW_SHADER: Shader = preload("res://data/materials/interior/glow.gdshader")
const SCREEN_SHADER: Shader = preload("res://data/materials/interior/screen.gdshader")
const CANOPY_SHADER: Shader = preload("res://data/materials/interior/canopy_window.gdshader")

## glow.gdshader's energy. InteriorKit.lit() pre-scales each lit piece's
## vertex colour by (its energy / GLOW_ENERGY), so one merged mesh holds lights
## of any strength up to this.
const GLOW_ENERGY := 2.4

static var _cache: Dictionary = {}

## A flat structure colour: floors, ceilings, walls. No rim -- rim light on a
## surface seen at a glancing angle, like the whole ceiling, blows it out.
static func flat(color: Color) -> StandardMaterial3D:
	var key := "flat:%s" % color.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_cache[key] = m
	return _cache[key]

## Every prop's solid geometry. Colour rides on the vertices, so one material
## serves the whole merged mesh; a faint rim keeps chunky shapes apart in dim
## light.
static func props() -> StandardMaterial3D:
	if not _cache.has(&"props"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		m.rim_enabled = true
		m.rim = 0.15
		m.rim_tint = 0.5
		_cache[&"props"] = m
	return _cache[&"props"]

static func glow() -> ShaderMaterial:
	if not _cache.has(&"glow"):
		var m := ShaderMaterial.new()
		m.shader = GLOW_SHADER
		m.set_shader_parameter(&"energy", GLOW_ENERGY)
		_cache[&"glow"] = m
	return _cache[&"glow"]

static func screen() -> ShaderMaterial:
	if not _cache.has(&"screen"):
		var m := ShaderMaterial.new()
		m.shader = SCREEN_SHADER
		m.set_shader_parameter(&"back_color", InteriorPalette.SCREEN_BACK)
		m.set_shader_parameter(&"color_a", InteriorPalette.AMBER)
		m.set_shader_parameter(&"color_b", InteriorPalette.LAVENDER)
		m.set_shader_parameter(&"color_c", InteriorPalette.SKY)
		m.set_shader_parameter(&"color_d", InteriorPalette.CORAL)
		_cache[&"screen"] = m
	return _cache[&"screen"]

## Porthole glass: tint and glint both come from vertex colour and alpha.
static func glass() -> StandardMaterial3D:
	if not _cache.has(&"glass"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.1
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[&"glass"] = m
	return _cache[&"glass"]

## The nose shell with no canopy view wired: the same shader with black
## windows. Used whenever InteriorBuilder.canopy_material is null -- every
## builder test -- so a headless rebuild never leaves a hole in the front.
static func canopy_fallback() -> ShaderMaterial:
	if not _cache.has(&"canopy_fallback"):
		var m := ShaderMaterial.new()
		m.shader = CANOPY_SHADER
		m.set_shader_parameter(&"shell_color", InteriorPalette.WALL)
		m.set_shader_parameter(&"frame_color", InteriorPalette.TRIM)
		_cache[&"canopy_fallback"] = m
	return _cache[&"canopy_fallback"]
```

- [ ] **Step 6: Import and run the tests to verify they pass**

Run the import command, then `powershell -File D:\git\whoknows\who-knows\run_tests.ps1 -gselect=test_interior_materials`.
Expected: all passing.

- [ ] **Step 7: Smoke-test that the shaders compile on a real renderer**

Headless runs never compile shaders, so this is the only check that they do. Create the throwaway file `who-knows/_smoke_interior.gd` (do **not** commit it):

```gdscript
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var mats: Array[Material] = [InteriorMaterials.flat(InteriorPalette.WALL), InteriorMaterials.props(),
		InteriorMaterials.glow(), InteriorMaterials.screen(), InteriorMaterials.glass(),
		InteriorMaterials.canopy_fallback()]
	for i in mats.size():
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.material_override = mats[i]
		mi.position = Vector3(i - 2.5, 0, -5)
		root.add_child(mi)
	for i in 5:
		await process_frame
	print("SMOKE_DONE")
	quit()
```

Run (without `--headless`: a window flashes up briefly):
```powershell
& "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" --path "D:\git\whoknows\who-knows" --script res://_smoke_interior.gd
```
Expected: the output contains `SMOKE_DONE` and no `SHADER ERROR` or `ERROR` lines. Then delete `who-knows/_smoke_interior.gd` (and its `.uid` if one appeared).

- [ ] **Step 8: Full suite, then commit**

Run the full suite. Expected: no failures.

```bash
git add who-knows/src/ship/interior/interior_palette.gd* who-knows/src/ship/interior/interior_materials.gd* who-knows/data/materials/interior who-knows/test/unit/test_interior_materials.gd*
git commit -m "feat: add the interior palette, materials and three shaders

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: InteriorKit

**Files:**
- Create: `who-knows/src/ship/interior/interior_kit.gd`
- Test: `who-knows/test/unit/test_interior_kit.gd`

**Interfaces:**
- Consumes: `InteriorMaterials.props()/glow()/screen()/glass()`, `InteriorMaterials.GLOW_ENERGY`.
- Produces:
  - `InteriorKit.new(root: Node3D, body: CollisionObject3D = null)`
  - `enum Batch { SOLID, GLOW, SCREEN, GLASS }`, `enum Screen { BARS, WAVE, DOTS }`, `const GROUP := &"interior_dressing"`, `const LAYER := 2`
  - Statics: `at(offset: Vector3) -> Transform3D`, `solid(color) -> Color`, `lit(color, energy, blink_phase := 1.0) -> Color`
  - Geometry: `tri`, `quad`, `box(batch, xf, size, color)`, `bevel_box(batch, xf, size, bevel, color)`, `tube_x(batch, xf, radius, length, color)`, `tube_between(batch, a, b, radius, color)`, `ring(batch, xf, r_in, r_out, z_back, z_front, color)`, `annulus(batch, xf, r_in, r_out, color)`, `disc(batch, xf, radius, color)`, `screen(xf, size: Vector2, mode: Screen, variety: float)`
  - `light(pos, color, energy, range_m, role: StringName) -> OmniLight3D`: role in meta `&"role"`
  - `collider(xf, size) -> CollisionShape3D`
  - `add_mesh(mesh, material, node_name) -> MeshInstance3D`
  - `commit() -> Array[MeshInstance3D]`

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_interior_kit.gd`:

```gdscript
extends GutTest

var _root: Node3D
var _body: StaticBody3D
var _kit: InteriorKit

func before_each():
	_body = StaticBody3D.new()
	add_child_autofree(_body)
	_root = Node3D.new()
	_body.add_child(_root)
	_kit = InteriorKit.new(_root, _body)

func _triangles(mi: MeshInstance3D) -> Array:
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var out := []
	for i in range(0, verts.size(), 3):
		out.append({"a": verts[i], "b": verts[i + 1], "c": verts[i + 2], "n": normals[i]})
	return out

func test_bevel_box_is_26_flat_faces():
	_kit.bevel_box(InteriorKit.Batch.SOLID, Transform3D.IDENTITY, Vector3(1, 1, 1), 0.1, Color.WHITE)
	var meshes := _kit.commit()
	# 6 faces and 12 edge strips of two triangles each, and 8 corner triangles.
	assert_eq(_triangles(meshes[0]).size(), 6 * 2 + 12 * 2 + 8)

func test_every_triangle_faces_its_normal():
	# Godot's front face is clockwise seen from the front: (b-a)x(c-a) points
	# away from the viewer, i.e. against the normal.
	_kit.bevel_box(InteriorKit.Batch.SOLID, Transform3D(Basis(Vector3.UP, 0.7), Vector3(1, 2, 3)),
		Vector3(1.4, 0.6, 0.3), 0.05, Color.WHITE)
	_kit.ring(InteriorKit.Batch.SOLID, Transform3D.IDENTITY, 0.2, 0.4, -0.1, 0.1, Color.WHITE)
	_kit.tube_x(InteriorKit.Batch.SOLID, Transform3D.IDENTITY, 0.05, 1.0, Color.WHITE)
	for t in _triangles(_kit.commit()[0]):
		var facing: Vector3 = (t["b"] - t["a"]).cross(t["c"] - t["a"])
		if facing.length() > 0.000001:
			assert_lt(facing.dot(t["n"]), 0.0, "triangle wound against its normal")

func test_one_merged_mesh_per_material():
	for i in 3:
		_kit.box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(i, 0, 0)), Vector3.ONE * 0.2, Color.WHITE)
	for i in 2:
		_kit.box(InteriorKit.Batch.GLOW, InteriorKit.at(Vector3(i, 1, 0)), Vector3.ONE * 0.2, Color.WHITE)
	var meshes := _kit.commit()
	assert_eq(meshes.size(), 2, "five pieces, two materials, two meshes")
	for mi in meshes:
		assert_eq(mi.get_parent(), _root)
		assert_eq(mi.layers, InteriorKit.LAYER)
	assert_eq(meshes[0].material_override, InteriorMaterials.props())
	assert_eq(meshes[1].material_override, InteriorMaterials.glow())

func test_lights_follow_the_interior_convention():
	var l := _kit.light(Vector3(1, 2, 3), InteriorPalette.LIGHT_WARM, 0.4, 3.0, &"ceiling")
	assert_eq(l.get_parent(), _root)
	assert_eq(l.light_cull_mask, 2)
	assert_false(l.shadow_enabled)
	assert_eq(l.get_meta(&"role"), &"ceiling")
	assert_eq(l.position, Vector3(1, 2, 3))

func test_colliders_join_the_body_and_the_dressing_group():
	var c := _kit.collider(InteriorKit.at(Vector3(0, 0.5, 0.2)), Vector3(1, 1, 0.4))
	assert_eq(c.get_parent(), _body, "shapes must be direct children of the body to register")
	assert_true(c.is_in_group(InteriorKit.GROUP))
	assert_eq((c.shape as BoxShape3D).size, Vector3(1, 1, 0.4))

func test_lit_colour_carries_energy_and_blink():
	var full := InteriorKit.lit(Color.WHITE, InteriorMaterials.GLOW_ENERGY)
	assert_almost_eq(full.r, 1.0, 0.001)
	var half := InteriorKit.lit(Color.WHITE, InteriorMaterials.GLOW_ENERGY * 0.5, 0.3)
	assert_almost_eq(half.g, 0.5, 0.001)
	assert_almost_eq(half.a, 0.3, 0.001, "alpha below 1 is the blink phase")

func test_screen_quad_carries_its_mode_and_variety():
	_kit.screen(Transform3D.IDENTITY, Vector2(1, 0.5), InteriorKit.Screen.WAVE, 0.3)
	var colors: PackedColorArray = _kit.commit()[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_almost_eq(colors[0].r, 0.25, 0.01, "mode 1 of 4")
	assert_almost_eq(colors[0].g, 0.3, 0.01)
```

- [ ] **Step 2: Run to verify failure**

Run: `powershell -File D:\git\whoknows\who-knows\run_tests.ps1 -gselect=test_interior_kit`. Expected: FAIL, `InteriorKit` not declared.

- [ ] **Step 3: Write the implementation**

Create `who-knows/src/ship/interior/interior_kit.gd`:

```gdscript
class_name InteriorKit
extends RefCounted

## A mesh toolkit for stylized interiors (docs/superpowers/specs/
## 2026-09-23-ship-interior-redesign-design.md §3.2, §4): bevelled boxes,
## tubes, rings, discs and animated screens, accumulated into one SurfaceTool
## per material and committed as one merged mesh each -- so a cabin full of
## props costs a handful of draw calls. It also makes the lights and colliders
## props ask for, to the interior's conventions: render layer 2, light cull
## mask 2, no shadows, colliders tagged GROUP.
##
## Knows nothing about ships. Give it a node to build under and, if anything
## should be solid, a physics body; any generator can build with it.

## Carried by every collider a kit adds, so a builder can tell dressing
## colliders from its own structure.
const GROUP := &"interior_dressing"

## One merged mesh per batch, each with its own material.
enum Batch { SOLID, GLOW, SCREEN, GLASS }
const BATCH_NAMES := ["DressingSolid", "DressingGlow", "DressingScreens", "DressingGlass"]

## screen.gdshader's modes, carried in vertex colour red as mode / 4.
enum Screen { BARS, WAVE, DOTS }

## Interior render layer and light cull mask (project.godot 3d_render/layer_2).
const LAYER := 2

const SEGMENTS := 24
const TUBE_SEGMENTS := 8

const _BOX_FACES := [
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
]
const _UNIT_UVS: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]

var root: Node3D
var body: CollisionObject3D
var _tools: Dictionary = {}   # Batch -> SurfaceTool

func _init(root_node: Node3D, collision_body: CollisionObject3D = null) -> void:
	root = root_node
	body = collision_body

## A translation-only frame, for placing a piece inside a prop's frame.
static func at(offset: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, offset)

## A palette colour as a vertex colour. Vertex colours reach the materials
## untouched, so they are stored linear.
static func solid(color: Color) -> Color:
	return color.srgb_to_linear()

## A lit piece's vertex colour: the colour pre-scaled by its share of
## InteriorMaterials.GLOW_ENERGY, so one merged glow mesh can hold lights of
## different strengths. `blink_phase` below 1 makes it blink, at that phase.
static func lit(color: Color, energy: float, blink_phase := 1.0) -> Color:
	var l := color.srgb_to_linear()
	var k := energy / InteriorMaterials.GLOW_ENERGY
	return Color(minf(l.r * k, 1.0), minf(l.g * k, 1.0), minf(l.b * k, 1.0), blink_phase)

## One triangle facing `normal`. Godot treats clockwise-seen-from-the-front as
## front-facing -- the front of (a, b, c) is the side (b - a) x (c - a) points
## away from -- so winding is fixed here, once, and no caller has to care.
func tri(batch: Batch, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	var st := _tool(batch)
	for v in [[a, ua], [b, ub], [c, uc]]:
		st.set_normal(normal)
		st.set_color(color)
		st.set_uv(v[1])
		st.add_vertex(v[0])

## A quad a-b-c-d, in order round its edge. UVs run (0,1) at a round to (0,0)
## at d, so a screen quad given bottom-left first reads upright.
func quad(batch: Batch, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
		color: Color) -> void:
	tri(batch, a, b, c, normal, color, _UNIT_UVS[0], _UNIT_UVS[1], _UNIT_UVS[2])
	tri(batch, a, c, d, normal, color, _UNIT_UVS[0], _UNIT_UVS[2], _UNIT_UVS[3])

## A plain box, for strips and slabs too thin to bevel.
func box(batch: Batch, xf: Transform3D, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	for f in _BOX_FACES:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := n * h
		var du := u * h
		var dv := v * h
		quad(batch, xf * (c - du - dv), xf * (c + du - dv), xf * (c + du + dv), xf * (c - du + dv),
			(xf.basis * n).normalized(), color)

## A box with every edge chamfered by `bevel`, flat-shaded: the low-poly,
## slightly toy-like block every chunky prop is made of. 6 faces, 12 edge
## strips, 8 corner triangles.
func bevel_box(batch: Batch, xf: Transform3D, size: Vector3, bevel: float, color: Color) -> void:
	var e := size * 0.5 - Vector3.ONE * bevel
	e = Vector3(maxf(e.x, 0.0), maxf(e.y, 0.0), maxf(e.z, 0.0))
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for a in 3:
		var b := (a + 1) % 3
		var c := (a + 2) % 3
		var ax: Vector3 = axes[a]
		var bx: Vector3 = axes[b]
		var cx: Vector3 = axes[c]
		for sa in [-1.0, 1.0]:
			var o: Vector3 = ax * sa * (e[a] + bevel)
			quad(batch, xf * (o - bx * e[b] - cx * e[c]), xf * (o + bx * e[b] - cx * e[c]),
				xf * (o + bx * e[b] + cx * e[c]), xf * (o - bx * e[b] + cx * e[c]),
				(xf.basis * (ax * sa)).normalized(), color)
			for sb in [-1.0, 1.0]:
				var p1: Vector3 = ax * sa * (e[a] + bevel) + bx * sb * e[b]
				var p2: Vector3 = ax * sa * e[a] + bx * sb * (e[b] + bevel)
				quad(batch, xf * (p1 - cx * e[c]), xf * (p1 + cx * e[c]), xf * (p2 + cx * e[c]),
					xf * (p2 - cx * e[c]), (xf.basis * (ax * sa + bx * sb)).normalized(), color)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var k := Vector3(sx, sy, sz)
				tri(batch, xf * (k * e + Vector3(sx * bevel, 0, 0)), xf * (k * e + Vector3(0, sy * bevel, 0)),
					xf * (k * e + Vector3(0, 0, sz * bevel)), (xf.basis * k).normalized(), color)

## An open-ended faceted tube along the frame's local x axis.
func tube_x(batch: Batch, xf: Transform3D, radius: float, length: float, color: Color) -> void:
	var half := Vector3(length * 0.5, 0.0, 0.0)
	for i in TUBE_SEGMENTS:
		var a0 := TAU * float(i) / TUBE_SEGMENTS
		var a1 := TAU * float(i + 1) / TUBE_SEGMENTS
		var d0 := Vector3(0.0, cos(a0), sin(a0)) * radius
		var d1 := Vector3(0.0, cos(a1), sin(a1)) * radius
		quad(batch, xf * (d0 - half), xf * (d0 + half), xf * (d1 + half), xf * (d1 - half),
			(xf.basis * (d0 + d1)).normalized(), color)

## A tube from a to b (both in the kit's space), for rails that follow a curve.
func tube_between(batch: Batch, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	tube_x(batch, Transform3D(Basis(dir, up, dir.cross(up)), (a + b) * 0.5), radius,
		a.distance_to(b) + radius, color)

static func _ring_dir(i: int) -> Vector3:
	var a := TAU * float(i) / SEGMENTS
	return Vector3(cos(a), sin(a), 0.0)

## A thick ring in the frame's xy plane, facing +z: front annulus at z_front,
## the bore from z_back to z_front, and the outer rim from 0 to z_front.
func ring(batch: Batch, xf: Transform3D, r_in: float, r_out: float, z_back: float, z_front: float,
		color: Color) -> void:
	var front := (xf.basis * Vector3.BACK).normalized()
	var zb := Vector3(0, 0, z_back)
	var zf := Vector3(0, 0, z_front)
	for i in SEGMENTS:
		var d0 := _ring_dir(i)
		var d1 := _ring_dir(i + 1)
		var out := (xf.basis * (d0 + d1)).normalized()
		quad(batch, xf * (d0 * r_in + zf), xf * (d1 * r_in + zf), xf * (d1 * r_out + zf),
			xf * (d0 * r_out + zf), front, color)
		quad(batch, xf * (d0 * r_in + zb), xf * (d1 * r_in + zb), xf * (d1 * r_in + zf),
			xf * (d0 * r_in + zf), -out, color)
		quad(batch, xf * (d0 * r_out), xf * (d1 * r_out), xf * (d1 * r_out + zf),
			xf * (d0 * r_out + zf), out, color)

## A flat ring in the frame's xy plane, facing +z.
func annulus(batch: Batch, xf: Transform3D, r_in: float, r_out: float, color: Color) -> void:
	var n := (xf.basis * Vector3.BACK).normalized()
	for i in SEGMENTS:
		var d0 := _ring_dir(i)
		var d1 := _ring_dir(i + 1)
		quad(batch, xf * (d0 * r_in), xf * (d1 * r_in), xf * (d1 * r_out), xf * (d0 * r_out), n, color)

## A flat disc in the frame's xy plane, facing +z.
func disc(batch: Batch, xf: Transform3D, radius: float, color: Color) -> void:
	var n := (xf.basis * Vector3.BACK).normalized()
	var centre := xf * Vector3.ZERO
	for i in SEGMENTS:
		tri(batch, centre, xf * (_ring_dir(i) * radius), xf * (_ring_dir(i + 1) * radius), n, color)

## An animated screen in the frame's xy plane, facing +z. `variety` (0..1)
## seeds what it shows, so neighbouring screens differ.
func screen(xf: Transform3D, size: Vector2, mode: Screen, variety: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	quad(Batch.SCREEN, xf * Vector3(-hx, -hy, 0), xf * Vector3(hx, -hy, 0), xf * Vector3(hx, hy, 0),
		xf * Vector3(-hx, hy, 0), (xf.basis * Vector3.BACK).normalized(),
		Color(float(mode) * 0.25, variety, 0.0, 1.0))

## A warm interior light. `role` is kept in meta so callers and tests can
## tell ceiling lights from console spill and door lights.
func light(pos: Vector3, color: Color, energy: float, range_m: float, role: StringName) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.light_cull_mask = LAYER
	l.shadow_enabled = false
	l.set_meta(&"role", role)
	root.add_child(l)
	return l

## A box collider for a piece a player could walk into. It goes straight on
## the body, because a CollisionShape3D only registers as the body's direct
## child.
func collider(xf: Transform3D, size: Vector3) -> CollisionShape3D:
	if body == null:
		push_error("InteriorKit.collider: this kit was given no physics body")
		return null
	var shape := BoxShape3D.new()
	shape.size = size
	var c := CollisionShape3D.new()
	c.shape = shape
	c.transform = xf
	c.add_to_group(GROUP)
	body.add_child(c)
	return c

## A standalone mesh (not batched) under the kit's root, on the interior layer.
func add_mesh(mesh: Mesh, material: Material, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.layers = LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

## Commits every batch as one merged mesh with its material.
func commit() -> Array[MeshInstance3D]:
	var materials: Array[Material] = [InteriorMaterials.props(), InteriorMaterials.glow(),
		InteriorMaterials.screen(), InteriorMaterials.glass()]
	var out: Array[MeshInstance3D] = []
	for batch: int in _tools:
		var st: SurfaceTool = _tools[batch]
		out.append(add_mesh(st.commit(), materials[batch], BATCH_NAMES[batch]))
	_tools.clear()
	return out

func _tool(batch: Batch) -> SurfaceTool:
	if not _tools.has(batch):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[batch] = st
	return _tools[batch]
```

- [ ] **Step 4: Import, run the tests, full suite**

Run the import command, then `-gselect=test_interior_kit`. Expected: all passing. Full suite: no failures.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/interior/interior_kit.gd* who-knows/test/unit/test_interior_kit.gd*
git commit -m "feat: add InteriorKit, a batched mesh toolkit for stylized interiors

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: InteriorProps: the wall and ceiling pieces

**Files:**
- Create: `who-knows/src/ship/interior/interior_props.gd`
- Test: `who-knows/test/unit/test_interior_props.gd`

**Interfaces:**
- Consumes: `InteriorKit` (all of Task 3), `InteriorPalette`.
- Produces:
  - Design constants: `BAY` (2.0), `HEADROOM` (1.9), `WALL_THICKNESS` (0.1), `PORTHOLE_HEIGHT` (1.28), `PORTHOLE_RADIUS` (0.26), `PORTHOLE_FRAME_RADIUS` (0.42), `PORTHOLE_OPENING` (0.27)
  - `static wall_trim(kit, f: Transform3D)`
  - `static ceiling_light(kit, ceiling_centre: Vector3)`: light role `&"ceiling"`
  - `static console(kit, f, variety: float)`: 1 collider, light role `&"console"`
  - `static lockers(kit, f, variety)`, `static display(kit, f, variety)`, `static porthole(kit, f)`
  - `static hatch(kit, f)`: light role `&"hatch"`
  - Every `f` is a prop frame per spec §4: origin on the wall's inner surface at floor level, centred along the wall; +x along, +y up, +z into the room.

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_interior_props.gd`:

```gdscript
extends GutTest

## The reuse contract: every prop builds in a bare frame with no grid, no
## layout and no builder -- exactly what a future blueprint generator gives it.

var _root: Node3D
var _body: StaticBody3D
var _kit: InteriorKit

func before_each():
	_body = StaticBody3D.new()
	add_child_autofree(_body)
	_root = Node3D.new()
	_body.add_child(_root)
	_kit = InteriorKit.new(_root, _body)

func _colliders() -> Array:
	return _body.get_children().filter(func(n): return n is CollisionShape3D)

func _lights(role: StringName) -> Array:
	return _root.get_children().filter(
		func(n): return n is OmniLight3D and n.get_meta(&"role", &"") == role)

func _assert_built() -> void:
	assert_gt(_kit.commit().size(), 0, "the prop added geometry")
	for c in _colliders():
		assert_gt(c.position.z, 0.0, "colliders stand in the room, in front of the wall")

func test_prop_dimensions_match_the_ship_grid():
	assert_eq(InteriorProps.BAY, ShipGrid.CELL_SIZE)
	assert_almost_eq(InteriorProps.HEADROOM, ShipGrid.CELL_SIZE - InteriorBuilder.FLOOR_THICKNESS, 0.0001)
	assert_almost_eq(InteriorProps.WALL_THICKNESS, InteriorBuilder.FLOOR_THICKNESS, 0.0001)

func test_porthole_frame_hides_the_square_opening():
	assert_gte(InteriorProps.PORTHOLE_OPENING, InteriorProps.PORTHOLE_RADIUS,
		"the square is at least as wide as the glass")
	assert_lt(InteriorProps.PORTHOLE_OPENING * sqrt(2.0), InteriorProps.PORTHOLE_FRAME_RADIUS,
		"the ring covers the square's corners")

func test_wall_trim_builds_without_a_grid():
	InteriorProps.wall_trim(_kit, Transform3D.IDENTITY)
	_assert_built()
	assert_eq(_colliders().size(), 0, "trim is flush enough to brush past")

func test_ceiling_light_brings_its_light():
	InteriorProps.ceiling_light(_kit, Vector3(0, 1.9, 0))
	_assert_built()
	assert_eq(_lights(&"ceiling").size(), 1)

func test_console_is_solid_and_lit():
	InteriorProps.console(_kit, Transform3D.IDENTITY, 0.4)
	_assert_built()
	assert_eq(_colliders().size(), 1)
	assert_eq(_lights(&"console").size(), 1)

func test_lockers_and_display_are_flat_enough_to_need_no_collider():
	InteriorProps.lockers(_kit, Transform3D.IDENTITY, 0.2)
	InteriorProps.display(_kit, InteriorKit.at(Vector3(3, 0, 0)), 0.7)
	_assert_built()
	assert_eq(_colliders().size(), 0)

func test_porthole_builds_frame_and_glass():
	InteriorProps.porthole(_kit, Transform3D.IDENTITY)
	var names := _kit.commit().map(func(mi): return String(mi.name))
	assert_has(names, "DressingSolid", "the frame")
	assert_has(names, "DressingGlass", "the glass")

func test_hatch_brings_its_light():
	InteriorProps.hatch(_kit, Transform3D.IDENTITY)
	_assert_built()
	assert_eq(_lights(&"hatch").size(), 1)

func test_props_honour_a_rotated_frame():
	var f := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(5, 0, 5))
	InteriorProps.console(_kit, f, 0.1)
	var c: CollisionShape3D = _colliders()[0]
	var local := f.affine_inverse() * c.position
	assert_gt(local.z, 0.0, "still in front of its wall, in the wall's own frame")
```

- [ ] **Step 2: Run to verify failure**

`-gselect=test_interior_props`. Expected: FAIL, `InteriorProps` not declared.

- [ ] **Step 3: Write the implementation**

Create `who-knows/src/ship/interior/interior_props.gd`:

```gdscript
class_name InteriorProps
extends RefCounted

## The interior asset library (docs/superpowers/specs/
## 2026-09-23-ship-interior-redesign-design.md §4, §5.3): every chunky piece of
## a stylized cabin, each built by one static function from an InteriorKit, a
## frame and, where it varies, a `variety` in 0..1.
##
## THE REUSE CONTRACT. A prop never looks at a grid, a layout or a builder. It
## builds in its own frame -- origin on the wall's inner surface at floor
## level, centred along the wall; +x along the wall, +y up, +z out into the
## room -- and nothing else. Anything that can produce a frame (the ship
## interior today; shipyard blueprints, derelicts and stations later) can place
## any prop.
##
## Sizes are metres in that frame. Props are designed for a wall BAY long and
## HEADROOM high; test_interior_props.gd holds the ship's cell and slab
## dimensions to these numbers.

const SOLID := InteriorKit.Batch.SOLID
const GLOW := InteriorKit.Batch.GLOW
const GLASS := InteriorKit.Batch.GLASS

## The wall length a prop is designed to fill.
const BAY := 2.0
## Clear height, floor to ceiling.
const HEADROOM := 1.9
## Thickness of the wall a frame sits on: the frame's origin is on its inner
## face, so the wall's mid-plane is at z = -WALL_THICKNESS / 2.
const WALL_THICKNESS := 0.1

## A porthole: floor-relative centre height, glass radius, frame radius, and
## the half-size of the square hole a wall leaves for it. The frame ring
## covers the square's corners and its bore hides the gap round the glass.
const PORTHOLE_HEIGHT := 1.28
const PORTHOLE_RADIUS := 0.26
const PORTHOLE_FRAME_RADIUS := 0.42
const PORTHOLE_OPENING := 0.27

## Pilasters, a kick band, a terracotta belt, a light shelf with a warm strip
## above it, and a cove up to the ceiling: what makes a bare wall read as a
## ship's wall. Neighbouring walls both build a pilaster on their shared
## edge, so the one on the -x edge is a hair smaller and never z-fights.
static func wall_trim(kit: InteriorKit, f: Transform3D) -> void:
	for side in [-1.0, 1.0]:
		var shrink := 0.0 if side > 0.0 else 0.002
		kit.bevel_box(SOLID, f * _at(Vector3(side * BAY * 0.5, HEADROOM * 0.5, 0.05)),
			Vector3(0.18 - shrink, HEADROOM, 0.1 - shrink), 0.035, _c(InteriorPalette.TRIM))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.08, 0.025)), Vector3(BAY, 0.16, 0.05), 0.02,
		_c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.95, 0.0175)), Vector3(BAY, 0.08, 0.035), 0.015,
		_c(InteriorPalette.BELT))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.66, 0.09)), Vector3(BAY, 0.07, 0.18), 0.03,
		_c(InteriorPalette.TRIM))
	kit.box(GLOW, f * _at(Vector3(0, 1.735, 0.01)), Vector3(BAY, 0.06, 0.02),
		_lit(InteriorPalette.LIGHT_WARM, 2.2))
	kit.box(SOLID, f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(45.0)), Vector3(0, 1.84, 0.06)),
		Vector3(BAY, 0.17, 0.02), _c(InteriorPalette.TRIM))

## A round light on the ceiling: a chunky frame round a glowing disc, and the
## lamp that actually lights the room below it.
static func ceiling_light(kit: InteriorKit, ceiling_centre: Vector3) -> void:
	var down := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), ceiling_centre)
	kit.ring(SOLID, down, 0.3, 0.42, -0.02, 0.05, _c(InteriorPalette.TRIM))
	kit.disc(GLOW, down * _at(Vector3(0, 0, 0.02)), 0.3, _lit(InteriorPalette.LIGHT_WARM, 0.9))
	kit.light(ceiling_centre + Vector3(0, -0.7, 0), InteriorPalette.LIGHT_WARM, 0.35, 3.5, &"ceiling")

## A station console: glowing plinth, bevelled body, a sloped screen, four big
## buttons (one blinks) and a framed screen on the wall above.
static func console(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var body := _c(InteriorPalette.TRIM)
	kit.box(GLOW, f * _at(Vector3(0, 0.05, 0.12)), Vector3(1.1, 0.1, 0.24), _lit(InteriorPalette.LIGHT_WARM, 2.5))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.41, 0.19)), Vector3(1.4, 0.62, 0.38), 0.05, body)
	var slope := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-45.0)), Vector3(0, 0.895, 0.205))
	kit.bevel_box(SOLID, f * slope, Vector3(1.4, 0.5, 0.06), 0.025, body)
	for side in [-0.68, 0.68]:
		kit.tri(SOLID, f * Vector3(side, 0.72, 0.0), f * Vector3(side, 0.72, 0.36), f * Vector3(side, 1.07, 0.0),
			(f.basis * Vector3(signf(side), 0, 0)).normalized(), body)
	kit.bevel_box(SOLID, f * slope * _at(Vector3(0, 0, 0.035)), Vector3(1.24, 0.38, 0.02), 0.01,
		_c(InteriorPalette.SCREEN_BACK))
	var first := int(variety * 3.0)
	kit.screen(f * slope * _at(Vector3(0, 0, 0.047)), Vector2(1.12, 0.3), _mode(first), variety)
	var buttons: Array[Color] = [InteriorPalette.AMBER, InteriorPalette.SKY, InteriorPalette.CORAL,
		InteriorPalette.LIGHT_WARM]
	for i in buttons.size():
		kit.bevel_box(GLOW, f * _at(Vector3(-0.45 + i * 0.3, 0.58, 0.405)), Vector3(0.14, 0.08, 0.05), 0.015,
			_lit(buttons[i], 1.6, 0.4 if i == 2 else 1.0))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.3, 0.03)), Vector3(1.0, 0.5, 0.06), 0.03, body)
	kit.screen(f * _at(Vector3(0, 1.3, 0.061)), Vector2(0.86, 0.36), _mode(first + 1), fposmod(variety + 0.37, 1.0))
	kit.collider(f * _at(Vector3(0, 0.55, 0.2)), Vector3(1.4, 1.1, 0.4))
	kit.light(f * Vector3(0, 1.0, 0.45), InteriorPalette.LIGHT_WARM, 0.35, 1.8, &"console")

## Six raised locker doors on a dark backing, each with a small indicator.
static func lockers(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	kit.box(SOLID, f * _at(Vector3(0, 0.92, 0.01)), Vector3(1.34, 1.46, 0.02), _c(InteriorPalette.WALL_LOW))
	var lamps: Array[Color] = [InteriorPalette.LIGHT_WARM, InteriorPalette.AMBER, InteriorPalette.SKY]
	for col in 2:
		for row in 3:
			var p := Vector3(-0.32 + col * 0.64, 0.45 + row * 0.47, 0.04)
			kit.bevel_box(SOLID, f * _at(p), Vector3(0.6, 0.42, 0.08), 0.03, _c(InteriorPalette.TRIM))
			var h := fposmod(variety * 13.0 + col * 3.7 + row * 1.3, 1.0)
			kit.disc(GLOW, f * _at(p + Vector3(0.2, -0.13, 0.041)), 0.03,
				_lit(lamps[int(h * 3.0) % 3], 1.6, h if h > 0.6 else 1.0))

## A framed wall screen above a small ledge.
static func display(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.0, 0.07)), Vector3(1.5, 0.05, 0.14), 0.02, _c(InteriorPalette.TRIM))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.3, 0.035)), Vector3(1.5, 0.55, 0.07), 0.03, _c(InteriorPalette.TRIM))
	kit.screen(f * _at(Vector3(0, 1.3, 0.071)), Vector2(1.36, 0.41),
		_mode(0 if variety < 0.5 else 2), variety)

## A porthole's frame and glass. The wall behind it must leave a square hole
## PORTHOLE_OPENING across at PORTHOLE_HEIGHT (InteriorBuilder does).
static func porthole(kit: InteriorKit, f: Transform3D) -> void:
	var at := f * _at(Vector3(0, PORTHOLE_HEIGHT, 0))
	kit.ring(SOLID, at, PORTHOLE_RADIUS, PORTHOLE_FRAME_RADIUS, -WALL_THICKNESS, 0.09, _c(InteriorPalette.TRIM))
	kit.annulus(GLOW, at * _at(Vector3(0, 0, 0.092)), PORTHOLE_RADIUS, PORTHOLE_RADIUS + 0.015,
		_lit(InteriorPalette.LIGHT_WARM, 1.0))
	var facing := (at.basis * Vector3.BACK).normalized()
	kit.disc(GLASS, at * _at(Vector3(0, 0, -WALL_THICKNESS * 0.5)), PORTHOLE_RADIUS, InteriorPalette.GLASS)
	# A cartoon glint: two parallel streaks across the glass.
	var glint := at * Transform3D(Basis(Vector3.BACK, deg_to_rad(45.0)), Vector3(-0.04, 0.04, -0.045))
	var white := Color(1, 1, 1, 0.35)
	kit.quad(GLASS, glint * Vector3(-0.15, -0.018, 0), glint * Vector3(0.15, -0.018, 0),
		glint * Vector3(0.15, 0.018, 0), glint * Vector3(-0.15, 0.018, 0), facing, white)
	kit.quad(GLASS, glint * Vector3(-0.08, -0.07, 0), glint * Vector3(0.08, -0.07, 0),
		glint * Vector3(0.08, -0.055, 0), glint * Vector3(-0.08, -0.055, 0), facing, white)

## The airlock's inner hatch: two bevelled leaves with a stripe, thick posts
## and header, a lit strip under the header and a blinking amber indicator --
## legible from across the cabin as the way out.
static func hatch(kit: InteriorKit, f: Transform3D) -> void:
	for side in [-1.0, 1.0]:
		kit.bevel_box(SOLID, f * _at(Vector3(side * 0.28, 0.8, 0.03)), Vector3(0.54, 1.6, 0.06), 0.025,
			_c(InteriorPalette.WALL_LOW))
		kit.bevel_box(SOLID, f * _at(Vector3(side * 0.64, 0.875, 0.06)), Vector3(0.16, 1.75, 0.12), 0.04,
			_c(InteriorPalette.TRIM))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.0, 0.065)), Vector3(1.08, 0.08, 0.02), 0.008, _c(InteriorPalette.BELT))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.7, 0.06)), Vector3(1.44, 0.14, 0.12), 0.04, _c(InteriorPalette.TRIM))
	kit.box(GLOW, f * _at(Vector3(0, 1.62, 0.08)), Vector3(1.1, 0.02, 0.04), _lit(InteriorPalette.LIGHT_WARM, 2.0))
	kit.disc(GLOW, f * _at(Vector3(0.85, 1.1, 0.011)), 0.04, _lit(InteriorPalette.AMBER, 1.6, 0.5))
	kit.light(f * Vector3(0, 1.5, 0.4), InteriorPalette.LIGHT_WARM, 0.5, 2.5, &"hatch")

static func _at(offset: Vector3) -> Transform3D:
	return InteriorKit.at(offset)

static func _c(color: Color) -> Color:
	return InteriorKit.solid(color)

static func _lit(color: Color, energy: float, blink_phase := 1.0) -> Color:
	return InteriorKit.lit(color, energy, blink_phase)

## Screen modes in a fixed cycle, so a variety picks one without an int-to-enum cast.
static func _mode(i: int) -> InteriorKit.Screen:
	var modes := [InteriorKit.Screen.BARS, InteriorKit.Screen.WAVE, InteriorKit.Screen.DOTS]
	return modes[posmod(i, 3)]
```

- [ ] **Step 4: Import, run the tests, full suite**

`-gselect=test_interior_props`: all passing. Full suite: no failures.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/interior/interior_props.gd* who-knows/test/unit/test_interior_props.gd*
git commit -m "feat: add InteriorProps, the reusable interior asset library

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Build the structure from the layout and dress it

**Files:**
- Create: `who-knows/src/ship/interior/interior_dressing.gd`
- Modify: `who-knows/src/ship/interior_builder.gd` (replace the whole file with the version below)
- Test: `who-knows/test/unit/test_interior_dressing.gd` (new), `who-knows/test/unit/test_interior_builder.gd` (modified)

**Interfaces:**
- Consumes: `InteriorLayout.plan/faces`, `InteriorProps` (Task 4), `InteriorKit`, `InteriorMaterials.flat`, `InteriorPalette`.
- Produces:
  - `InteriorDressing.build(layout: InteriorLayout, body: StaticBody3D, canopy_material: Material) -> Node3D`: returns the `Dressing` node
  - `InteriorDressing.wall_frame(coord: Vector3i, normal: Vector3i) -> Transform3D`
  - `InteriorDressing.floor_y(coord) -> float`, `InteriorDressing.face_variety(face: Dictionary) -> float`
  - `InteriorBuilder.layout() -> InteriorLayout`
  - The builder's canopy panes and `canopy_pane_uvs()` **stay** until Task 6.

- [ ] **Step 1: Write the failing dressing tests**

Create `who-knows/test/unit/test_interior_dressing.gd`:

```gdscript
extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid
var _builder: InteriorBuilder

func before_each():
	_cat = BlockCatalog.new()
	for id in [&"hull", &"canopy"]:
		_cat.register(_def(id, BlockDefinition.Occupancy.SOLID))
	for id in [&"deck", &"airlock"]:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))
	_cat.register(_def(&"seat", BlockDefinition.Occupancy.MOUNT))
	_grid = ShipGrid.new()
	_builder = InteriorBuilder.new()
	add_child_autofree(_builder)
	_builder.bind(_grid, _cat)

func _def(id: StringName, occ: BlockDefinition.Occupancy) -> BlockDefinition:
	var d := BlockDefinition.new()
	d.id = id
	d.display_name = String(id)
	d.occupancy = occ
	return d

func _put(coord: Vector3i, id: StringName) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	_grid.set_block(coord, i)

func _dressing() -> Node3D:
	return _builder.find_child("Dressing", true, false)

func _lights(role: StringName = &"") -> Array:
	return _builder.find_children("*", "OmniLight3D", true, false).filter(
		func(l): return role == &"" or l.get_meta(&"role", &"") == role)

func _dressing_colliders() -> Array:
	return _builder.find_children("*", "CollisionShape3D", true, false).filter(
		func(c): return c.is_in_group(InteriorKit.GROUP))

func test_rebuilds_leave_exactly_one_dressing():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	_builder.rebuild()
	_builder.rebuild()
	assert_eq(_builder.find_children("Dressing", "Node3D", true, false).size(), 1)

func test_lights_do_not_accumulate_across_rebuilds():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	var once := _lights().size()
	_builder.rebuild()
	_builder.rebuild()
	assert_eq(_lights().size(), once)

func test_every_walkable_cell_gets_one_ceiling_light():
	for x in 3:
		_put(Vector3i(x, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"seat")
	_builder.rebuild()
	assert_eq(_lights(&"ceiling").size(), 4)

func test_every_console_brings_a_collider():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, -1), &"canopy")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(-1, 0, 0), &"hull")
	_builder.rebuild()
	var consoles := 0
	for f in _builder.layout().faces():
		if f["variant"] == InteriorLayout.WallVariant.CONSOLE:
			consoles += 1
	assert_gt(consoles, 0, "the fixture exercises consoles")
	assert_eq(_dressing_colliders().size(), consoles)

func test_dressing_colliders_sit_on_the_interior_body():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, -1), &"canopy")
	_put(Vector3i(1, 0, 0), &"hull")
	_builder.rebuild()
	for c in _dressing_colliders():
		var body := c.get_parent() as StaticBody3D
		assert_not_null(body, "a shape registers only as the body's direct child")
		assert_eq(body.collision_layer, 2)

func test_meshes_are_merged_by_material():
	for z in 4:
		for x in 3:
			_put(Vector3i(x, 0, z), &"deck")
	_builder.rebuild()
	var batches := _dressing().get_children().filter(
		func(n): return n is MeshInstance3D and String(n.name).begins_with("Dressing"))
	assert_between(batches.size(), 1, 4, "one merged mesh per material, not one per piece")

func test_dressing_stays_on_the_interior_layer_under_churn():
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260923
	var ids := [&"hull", &"deck", &"seat", &"canopy", &"airlock"]
	for step in 300:
		var coord := Vector3i(rng.randi_range(-3, 3), rng.randi_range(-1, 1), rng.randi_range(-5, 5))
		if rng.randf() < 0.7:
			_put(coord, ids[rng.randi_range(0, ids.size() - 1)])
		else:
			_grid.clear_block(coord)
	_builder.rebuild()
	for mesh in _dressing().find_children("*", "MeshInstance3D", true, false):
		assert_eq(mesh.layers, 2)
	for light in _lights():
		assert_eq(light.light_cull_mask, 2)
		assert_false(light.shadow_enabled)

func test_wall_frame_sits_on_the_inner_surface_facing_the_room():
	var f := InteriorDressing.wall_frame(Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	assert_almost_eq(f.origin, Vector3(0.95, -0.95, 0.0), Vector3.ONE * 0.0001)
	assert_almost_eq(f.basis.z, Vector3(-1, 0, 0), Vector3.ONE * 0.0001, "+z points into the room")
	assert_almost_eq(f.basis.y, Vector3.UP, Vector3.ONE * 0.0001)
```

- [ ] **Step 2: Update the builder tests**

In `who-knows/test/unit/test_interior_builder.gd`:

(a) Add this helper after `_put`:

```gdscript
## Structure colliders only: the dressing's props carry their own.
func _structure_colliders() -> Array:
	return _builder.find_children("*", "CollisionShape3D", true, false).filter(
		func(c): return not c.is_in_group(InteriorKit.GROUP))

func _structure_meshes() -> Array:
	var body: StaticBody3D = _builder.find_children("*", "StaticBody3D", true, false)[0]
	return body.get_children().filter(func(n): return n is MeshInstance3D)
```

(b) In `test_walkable_cell_facing_canopy_gets_canopy_surface_not_wall`, replace

```gdscript
	var colliders := _builder.find_children("*", "CollisionShape3D", true, false)
	assert_eq(colliders.size(), 6,
```
with
```gdscript
	var colliders := _structure_colliders()
	assert_eq(colliders.size(), 6,
```

(c) Replace the whole `test_rebuild_does_not_leave_stale_nodes_in_the_tree` with:

```gdscript
func test_rebuild_does_not_leave_stale_nodes_in_the_tree():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	var meshes_once := _structure_meshes().size()
	_builder.rebuild()
	_builder.rebuild()

	var bodies := _builder.find_children("*", "StaticBody3D", true, false)
	assert_eq(bodies.size(), 1, "stale physics bodies must be fully detached, not merely queued")
	for body in bodies:
		assert_eq(body.collision_layer, 2, "interior_geometry convention: collision_layer = 2")
		assert_eq(body.collision_mask, 0, "interior_geometry convention: collision_mask = 0")

	assert_eq(_structure_colliders().size(), 6,
		"stale colliders must be fully detached, not merely queued (2 floor/ceiling + 4 walls)")

	var meshes := _structure_meshes()
	assert_eq(meshes.size(), meshes_once, "stale mesh instances must be fully detached, not merely queued")
	for mesh in meshes:
		assert_eq(mesh.layers, 2, "interior visuals render on layer 2, or the exterior sun washes them out")
```

(d) Add these tests at the end of the file:

```gdscript
## A porthole is glass, not a way out: the picture has a hole, the collider
## does not.
func test_porthole_wall_keeps_a_whole_collider_and_draws_four_boxes():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")   # flank, vacuum beyond: a porthole
	_builder.rebuild()
	var wall_at := Vector3(ShipGrid.CELL_SIZE * 0.5, 0, 0)
	var colliders := _structure_colliders().filter(func(c): return c.position.is_equal_approx(wall_at))
	assert_eq(colliders.size(), 1)
	assert_almost_eq((colliders[0].shape as BoxShape3D).size,
		Vector3(InteriorBuilder.FLOOR_THICKNESS, ShipGrid.CELL_SIZE, ShipGrid.CELL_SIZE), Vector3.ONE * 0.001)
	var pieces := _structure_meshes().filter(
		func(m): return absf(m.position.x - wall_at.x) < 0.001)
	assert_eq(pieces.size(), 4, "four boxes round a square opening")

func test_floor_takes_its_zone_colour():
	_put(Vector3i(0, 0, 0), &"seat")
	_put(Vector3i(0, 0, 2), &"deck")
	_put(Vector3i(0, 0, 1), &"deck")
	_builder.rebuild()
	var floor_y := -ShipGrid.CELL_SIZE * 0.5
	for m in _structure_meshes():
		if not is_equal_approx(m.position.y, floor_y):
			continue
		var expected := InteriorPalette.FLOOR if is_equal_approx(m.position.z, 4.0) else InteriorPalette.FLOOR_BRIDGE
		assert_eq((m.material_override as StandardMaterial3D).albedo_color, expected)
```

- [ ] **Step 3: Run to verify failure**

`-gselect=test_interior_dressing` fails with `InteriorDressing` not declared. `-gselect=test_interior_builder` fails on the new tests.

- [ ] **Step 4: Write the dressing**

Create `who-knows/src/ship/interior/interior_dressing.gd`:

```gdscript
class_name InteriorDressing
extends RefCounted

## Turns an InteriorLayout into props (docs/superpowers/specs/
## 2026-09-23-ship-interior-redesign-design.md §4): works out each face's
## frame and asks InteriorProps for the piece its record names. The only
## place that decides which prop goes where -- the props themselves never see
## a grid, which is what lets other generators reuse them.

## Builds everything under one `Dressing` node inside `body`, so the builder's
## single remove_child() + free() clears it with the rest of the interior.
static func build(layout: InteriorLayout, body: StaticBody3D, canopy_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	body.add_child(root)
	var kit := InteriorKit.new(root, body)
	for face in layout.faces():
		_dress(kit, face)
	kit.commit()
	return root

## A wall's frame, as InteriorProps expects it: origin on the wall's inner
## surface at floor level, centred along the wall; +x along the wall, +y up,
## +z into the room.
static func wall_frame(coord: Vector3i, normal: Vector3i) -> Transform3D:
	var n := Vector3(normal)
	var inward := -n
	var along := Vector3.UP.cross(inward)
	var origin := ShipGrid.cell_center(coord) + n * (ShipGrid.CELL_SIZE - InteriorBuilder.FLOOR_THICKNESS) * 0.5
	origin.y = floor_y(coord)
	return Transform3D(Basis(along, Vector3.UP, inward), origin)

## The top of a walkable cell's deck slab.
static func floor_y(coord: Vector3i) -> float:
	return ShipGrid.cell_center(coord).y - (ShipGrid.CELL_SIZE - InteriorBuilder.FLOOR_THICKNESS) * 0.5

## A face's stable 0..1 variety, for what its props show.
static func face_variety(face: Dictionary) -> float:
	return float(InteriorLayout.face_hash(face["coord"], face["normal"]) % 1000) / 1000.0

static func _dress(kit: InteriorKit, face: Dictionary) -> void:
	var coord: Vector3i = face["coord"]
	match face["kind"]:
		InteriorLayout.Kind.CEILING:
			var centre := ShipGrid.cell_center(coord)
			centre.y = floor_y(coord) + InteriorProps.HEADROOM
			InteriorProps.ceiling_light(kit, centre)
		InteriorLayout.Kind.WALL:
			var f := wall_frame(coord, face["normal"])
			InteriorProps.wall_trim(kit, f)
			_wall_piece(kit, f, face)

static func _wall_piece(kit: InteriorKit, f: Transform3D, face: Dictionary) -> void:
	var variety := face_variety(face)
	match face["variant"]:
		InteriorLayout.WallVariant.HATCH:
			InteriorProps.hatch(kit, f)
		InteriorLayout.WallVariant.CONSOLE:
			InteriorProps.console(kit, f, variety)
		InteriorLayout.WallVariant.PORTHOLE:
			InteriorProps.porthole(kit, f)
		InteriorLayout.WallVariant.LOCKERS:
			InteriorProps.lockers(kit, f, variety)
		InteriorLayout.WallVariant.DISPLAY:
			InteriorProps.display(kit, f, variety)
		# PANEL: the trim is the whole wall.
```

- [ ] **Step 5: Rewrite the builder**

Replace the whole of `who-knows/src/ship/interior_builder.gd` with:

```gdscript
class_name InteriorBuilder
extends Node3D

## Reads a ShipGrid and produces the walkable interior's structure: a floor
## under every walkable cell, a ceiling above it, and a wall on every face
## where a walkable cell meets solid structure or vacuum -- each a collider and
## a box built from the same numbers. What every face *is* is decided once, by
## InteriorLayout; everything attached to the surfaces is InteriorDressing's
## (docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md §4-§5).
##
## A walkable cell whose face touches a `canopy` cell gets a canopy surface
## there instead of a wall (art direction §7 item 4) -- the same box
## geometry, a different material and a separate count, so the shuttle's raked
## windshield is real glass with a real collider, not a hole in the hull.
##
## The output never moves. That is the whole architecture.
##
## Never references ExteriorBuilder. Both are independent readers of the
## same ShipGrid, which is what makes the parity test honest.

## Deck and overhead slab thickness. Each slab eats half its thickness from
## the cell, so clear headroom is CELL_SIZE - FLOOR_THICKNESS. At 0.2 that
## was exactly 1.8 m for an exactly 1.8 m avatar -- zero margin, and the
## player jammed into the overhead. 0.1 leaves 1.9 m clear.
const FLOOR_THICKNESS := 0.1
const DEFAULT_GRAVITY := 9.8

const _SLAB := Vector3(ShipGrid.CELL_SIZE, FLOOR_THICKNESS, ShipGrid.CELL_SIZE)

## Names the parent under which this builder creates and owns its own
## StaticBody3D each rebuild() -- NOT a body to attach colliders to.
## This is the opposite of ExteriorBuilder.body_path, which names a
## scene-supplied RigidBody3D that colliders attach to directly. Same
## export name, deliberately different meaning between the two builders:
## a bare CollisionShape3D parented under a plain Node3D (which is what
## body_path would point at here, e.g. a Node3D "Interior" placeholder)
## never registers with the physics server, so InteriorBuilder cannot
## reuse ExteriorBuilder's shape -- it must own a StaticBody3D itself to
## carry the interior_geometry convention (collision_layer = 2,
## collision_mask = 0; see _physics_body below). If empty, the owned body
## is parented directly under this node.
@export var body_path: NodePath
## Wired by Task 15 to the material carrying the canopy SubViewport's
## ViewportTexture. Stays null in tests -- falls back to an ordinary
## opaque material so a headless build still produces a complete,
## collidable interior and never crashes or leaves a hole.
@export var canopy_material: Material

var _grid: ShipGrid
var _catalog: BlockCatalog
var _layout: InteriorLayout
var _walkable: Array[Vector3i] = []
var _walls: Array[CollisionShape3D] = []
var _canopy_faces: Array[CollisionShape3D] = []
var _canopy_panes: Array[Dictionary] = []   # [{scale, offset}], see canopy_pane_uvs()
var _fixtures: Array[MeshInstance3D] = []
var _gravity: Dictionary = {}   # Vector3i -> float

# Interior geometry owns one physics body per rebuild(), carrying every
# floor/ceiling/wall/canopy CollisionShape3D and MeshInstance3D, and the
# Dressing node. One body with many shapes is the normal Godot way to
# represent static level geometry, and it is what makes the
# interior_geometry collision convention (layer 2, mask 0) a single
# assignment instead of one per box.
var _physics_body: StaticBody3D

var _canopy_fallback_material: StandardMaterial3D

func bind(grid: ShipGrid, catalog: BlockCatalog) -> void:
	_grid = grid
	_catalog = catalog

func rebuild() -> void:
	_clear()
	if _grid == null or _catalog == null:
		return
	var graph := DeckGraph.build(_grid, _catalog)
	_walkable.assign(graph.walkable_coords())
	_layout = InteriorLayout.plan(_grid, _catalog, _walkable)

	_physics_body = StaticBody3D.new()
	_physics_body.name = "InteriorGeometry"
	_physics_body.collision_layer = 2
	_physics_body.collision_mask = 0
	_body().add_child(_physics_body)

	_build_structure()
	_build_fixtures()
	InteriorDressing.build(_layout, _physics_body, canopy_material)
	_compute_gravity()

func walkable_coords() -> Array:
	return _walkable.duplicate()

## What every interior face is, as decided for the last rebuild(). Null
## before the first.
func layout() -> InteriorLayout:
	return _layout

func wall_count() -> int:
	return _walls.size()

func canopy_face_count() -> int:
	return _canopy_faces.size()

## Each canopy pane's share of the SubViewport, as {scale, offset} in UV
## units, ordered as the panes were built. One pane shows the whole view;
## three in a row show a third each, so together they read as one window.
func canopy_pane_uvs() -> Array[Dictionary]:
	return _canopy_panes.duplicate()

func fixture_count() -> int:
	return _fixtures.size()

func fixture_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f in _fixtures:
		out.append(f.position)
	return out

func gravity_at(coord: Vector3i) -> float:
	return _gravity.get(coord, 0.0)

func _clear() -> void:
	# remove_child() then free() -- not queue_free(). remove_child() is
	# synchronous and fires NOTIFICATION_UNPARENTED immediately, which is
	# what actually deregisters a StaticBody3D (and every CollisionShape3D
	# it carries) from the physics server. queue_free() alone does not do
	# that: the node stays parented (and physics-registered) until the
	# delete queue is flushed, which never happens between two synchronous
	# rebuild() calls -- exactly what several cell_changed signals firing
	# in the same frame from the shipyard editor look like. free() then
	# deletes the body and its whole subtree (every CollisionShape3D,
	# MeshInstance3D and the Dressing under it) immediately, instead of
	# leaving them parentless-but-alive for the rest of the frame. This was a
	# Critical finding against Task 13's ExteriorBuilder for the identical
	# reason; fixed here from the start rather than round-tripped through review.
	if is_instance_valid(_physics_body):
		var parent := _physics_body.get_parent()
		if parent != null:
			parent.remove_child(_physics_body)
		_physics_body.free()
	_physics_body = null
	_layout = null
	_walls.clear()
	_canopy_faces.clear()
	_canopy_panes.clear()
	_fixtures.clear()
	_walkable.clear()
	_gravity.clear()

func _body() -> Node:
	return get_node(body_path) if not body_path.is_empty() else self

func _build_structure() -> void:
	var half := ShipGrid.CELL_SIZE * 0.5
	var panes: Array[Dictionary] = []
	for face in _layout.faces():
		var coord: Vector3i = face["coord"]
		var normal: Vector3i = face["normal"]
		var at := ShipGrid.cell_center(coord) + Vector3(normal) * half
		match face["kind"]:
			InteriorLayout.Kind.FLOOR:
				_add_box(_physics_body, _SLAB, at, InteriorMaterials.flat(_floor_colour(face["zone"])))
			InteriorLayout.Kind.CEILING:
				_add_box(_physics_body, _SLAB, at, InteriorMaterials.flat(InteriorPalette.CEILING))
			InteriorLayout.Kind.WALL:
				if face["porthole"]:
					_walls.append(_add_collider(_physics_body, _wall_size(normal), at))
					_add_porthole_wall(at, normal)
				else:
					_walls.append(_add_box(_physics_body, _wall_size(normal), at,
						InteriorMaterials.flat(InteriorPalette.WALL)))
			InteriorLayout.Kind.CANOPY:
				panes.append({"coord": coord, "face": normal, "size": _wall_size(normal), "position": at})
	_build_canopy_panes(panes)

static func _floor_colour(zone: StringName) -> Color:
	return InteriorPalette.FLOOR_BRIDGE if zone == InteriorLayout.ZONE_BRIDGE else InteriorPalette.FLOOR

static func _wall_size(normal: Vector3i) -> Vector3:
	return Vector3(
		FLOOR_THICKNESS if normal.x != 0 else ShipGrid.CELL_SIZE,
		ShipGrid.CELL_SIZE,
		FLOOR_THICKNESS if normal.z != 0 else ShipGrid.CELL_SIZE
	)

## A porthole wall's picture: four boxes round a square opening, centred where
## InteriorProps.porthole puts its frame. Only the picture has a hole -- the
## collider beside it is a whole wall, so a porthole is glass, never a way out.
func _add_porthole_wall(at: Vector3, normal: Vector3i) -> void:
	var material := InteriorMaterials.flat(InteriorPalette.WALL)
	var along := Vector3(absi(normal.z), 0, absi(normal.x))
	var thick := Vector3(absi(normal.x), 0, absi(normal.z)) * FLOOR_THICKNESS
	var half := ShipGrid.CELL_SIZE * 0.5
	var s := InteriorProps.PORTHOLE_OPENING
	var hole_y := InteriorProps.PORTHOLE_HEIGHT - (ShipGrid.CELL_SIZE - FLOOR_THICKNESS) * 0.5
	var side_w := half - s
	for side in [-1.0, 1.0]:
		_add_visual(_physics_body, thick + along * side_w + Vector3.UP * ShipGrid.CELL_SIZE,
			at + along * side * (s + side_w * 0.5), material)
	var below := hole_y - s + half
	_add_visual(_physics_body, thick + along * 2.0 * s + Vector3.UP * below,
		at + Vector3.UP * (below * 0.5 - half), material)
	var above := half - (hole_y + s)
	_add_visual(_physics_body, thick + along * 2.0 * s + Vector3.UP * above,
		at + Vector3.UP * (half - above * 0.5), material)

## Builds the canopy faces once every pane is known, because each pane's
## material depends on how many panes share its plane.
##
## All panes show the same SubViewport. Left alone, each would render the
## whole forward view, and a three-cell windshield would read as three
## copies of one picture rather than one window -- so each pane takes its
## own share of the texture, by column and row within its plane.
func _build_canopy_panes(panes: Array[Dictionary]) -> void:
	var groups: Dictionary = {}   # plane key -> Array[Dictionary]
	for pane in panes:
		var face: Vector3i = pane["face"]
		var coord: Vector3i = pane["coord"]
		var across: int = coord.x if face.z != 0 else coord.z
		var key := "%s:%d" % [face, coord.z if face.z != 0 else coord.x]
		pane["across"] = across
		groups.get_or_add(key, []).append(pane)

	for key in groups:
		var group: Array = groups[key]
		var columns := _sorted_unique(group, "across", false)
		var rows := _sorted_unique(group, "row", true)
		var scale := Vector2(1.0 / columns.size(), 1.0 / rows.size())
		group.sort_custom(func(a, b): return a["across"] < b["across"])
		for pane in group:
			var offset := Vector2(
				columns.find(pane["across"]) * scale.x,
				rows.find(pane["coord"].y) * scale.y
			)
			_canopy_panes.append({"scale": scale, "offset": offset})
			_canopy_faces.append(_add_box(
				_physics_body, pane["size"], pane["position"], _pane_mat(scale, offset)
			))

## The distinct values of `field` across a pane group, sorted. Rows sort
## downward (v increases down the texture); columns sort upward.
func _sorted_unique(group: Array, field: String, descending: bool) -> Array:
	var values: Array = []
	for pane in group:
		var value: int = pane["coord"].y if field == "row" else pane[field]
		if not values.has(value):
			values.append(value)
	values.sort()
	if descending:
		values.reverse()
	return values

## One pane's slice of the shared canopy material. Duplicated per pane
## because uv1_scale/uv1_offset live on the material, not the surface; the
## duplicate is shallow, so every pane still samples the one ViewportTexture
## rather than a copy of it.
func _pane_mat(scale: Vector2, offset: Vector2) -> Material:
	var base := _canopy_mat()
	if not base is BaseMaterial3D:
		return base
	if scale.is_equal_approx(Vector2.ONE) and offset.is_zero_approx():
		return base
	var mat: BaseMaterial3D = base.duplicate()
	mat.uv1_scale = Vector3(scale.x, scale.y, 1.0)
	mat.uv1_offset = Vector3(offset.x, offset.y, 0.0)
	return mat

## Draws every MOUNT block that has a mesh: seats, consoles, ladders -- the
## fixtures a player sees and walks up to. Without this the pilot seat is an
## invisible collider with an interact prompt and nothing to look at.
func _build_fixtures() -> void:
	for coord in _grid.coords():
		var inst := _grid.get_block(coord)
		var def := _catalog.get_def(inst.block_id)
		if def == null or def.mesh == null:
			continue
		if def.occupancy != BlockDefinition.Occupancy.MOUNT:
			continue
		var fixture := MeshInstance3D.new()
		fixture.mesh = def.mesh
		fixture.transform = Transform3D(
			BlockOrientation.basis_for(inst.orientation), ShipGrid.cell_center(coord)
		)
		fixture.layers = 2   # interior render layer, same as the walls
		_physics_body.add_child(fixture)
		_fixtures.append(fixture)

## A collider and a box from the same size and position. Never compute the two
## independently -- what you see must be exactly what you collide with. A
## porthole wall is the one deliberate exception, and it calls the halves itself.
func _add_box(parent: Node, size: Vector3, at: Vector3, material: Material) -> CollisionShape3D:
	var collider := _add_collider(parent, size, at)
	_add_visual(parent, size, at, material)
	return collider

func _add_collider(parent: Node, size: Vector3, at: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	parent.add_child(collider)
	return collider

func _add_visual(parent: Node, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.layers = 2   # interior render layer; lights cull to it separately
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _compute_gravity() -> void:
	var plates: Array = []
	for coord in _grid.coords():
		var def := _catalog.get_def(_grid.get_block(coord).block_id)
		if def != null and def.grav_radius > 0.0:
			plates.append({"center": ShipGrid.cell_center(coord), "radius": def.grav_radius})

	for coord in _walkable:
		var center := ShipGrid.cell_center(coord)
		var g := 0.0
		for plate in plates:
			if center.distance_to(plate["center"]) <= plate["radius"]:
				g = DEFAULT_GRAVITY
				break
		_gravity[coord] = g

## Falls back to an ordinary opaque material when canopy_material hasn't
## been wired by the scene (always true in this builder's own tests).
func _canopy_mat() -> Material:
	if canopy_material != null:
		return canopy_material
	if _canopy_fallback_material == null:
		_canopy_fallback_material = StandardMaterial3D.new()
		_canopy_fallback_material.albedo_color = Color("141a22")   # canopy glass, unlit
	return _canopy_fallback_material
```

- [ ] **Step 6: Import, run the focused tests, then the full suite**

Run the import command. Then `-gselect=test_interior_dressing` (all passing), `-gselect=test_interior_builder` (all passing, including the two new tests), and the full suite (no failures). `test_hud_scene_wiring` must still pass: the real scene now builds with dressing.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/ship/interior/interior_dressing.gd* who-knows/src/ship/interior_builder.gd who-knows/test/unit/test_interior_dressing.gd* who-knows/test/unit/test_interior_builder.gd
git commit -m "feat: build the interior from InteriorLayout and dress it with props

Walls, floors and ceilings become flat stylized colour, porthole walls
draw four boxes round a square opening while keeping a whole collider,
and every wall and ceiling is dressed from the prop library.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The rounded cockpit nose and projected windows

**Files:**
- Modify: `who-knows/src/ship/interior/interior_props.gd` (add the nose)
- Modify: `who-knows/src/ship/interior/interior_dressing.gd` (dress canopy groups)
- Modify: `who-knows/src/ship/interior_builder.gd` (canopy faces become colliders only; delete pane code)
- Modify: `who-knows/scenes/flight_test.tscn` (canopy material becomes the window shader)
- Modify: `who-knows/scenes/flight_test.gd` (`_aim_canopy_view()` sets the projection uniforms)
- Test: `who-knows/test/unit/test_interior_props.gd`, `test_interior_dressing.gd`, `test_interior_builder.gd`, `test_hud_scene_wiring.gd`

**Interfaces:**
- Consumes: `InteriorMaterials.canopy_fallback()`, `InteriorKit.add_mesh`, the Task 2 shader uniforms.
- Produces:
  - `InteriorProps.nose(kit, frame: Transform3D, width: float, material: Material) -> MeshInstance3D` (the shell, named `NoseShell`); key light role `&"cockpit"`
  - `InteriorProps` constants `NOSE_DEPTH`, `NOSE_VERTICAL`, `NOSE_COLUMNS`, `NOSE_ROWS`, `NOSE_BROW`, `NOSE_RIBS`, `DASH_HEIGHT`, `DASH_INSET`, `NOSE_WINDOWS`
  - `InteriorBuilder.canopy_pane_uvs()` is **removed**.

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_interior_props.gd`:

```gdscript
func test_nose_builds_a_rounded_shell_the_width_of_its_group():
	var shell := InteriorProps.nose(_kit, Transform3D.IDENTITY, 6.0, InteriorMaterials.canopy_fallback())
	var box := shell.mesh.get_aabb()
	assert_almost_eq(box.size.x, 6.0, 0.01)
	assert_almost_eq(box.size.y, InteriorProps.HEADROOM, 0.01)
	assert_almost_eq(box.size.z, InteriorProps.NOSE_DEPTH, 0.01, "bulges forward, away from the room")
	assert_lt(box.position.z, -1.0, "forward is -z in the nose's frame")

func test_nose_pushes_its_windows_and_colours_to_the_material():
	var m: ShaderMaterial = InteriorMaterials.canopy_fallback().duplicate()
	InteriorProps.nose(_kit, Transform3D.IDENTITY, 6.0, m)
	assert_eq(m.get_shader_parameter(&"window_0"), InteriorProps.NOSE_WINDOWS[0])
	assert_eq(m.get_shader_parameter(&"shell_color"), InteriorPalette.WALL)

func test_nose_has_a_cockpit_light():
	InteriorProps.nose(_kit, Transform3D.IDENTITY, 6.0, InteriorMaterials.canopy_fallback())
	assert_eq(_lights(&"cockpit").size(), 1)

func test_a_narrow_nose_still_builds():
	var shell := InteriorProps.nose(_kit, Transform3D.IDENTITY, 2.0, null)
	assert_not_null(shell)
	assert_true(shell.material_override is ShaderMaterial, "null material falls back, never a hole")
```

Append to `who-knows/test/unit/test_interior_dressing.gd`:

```gdscript
func _noses() -> Array:
	return _builder.find_children("NoseShell*", "MeshInstance3D", true, false)

func test_a_windshield_gets_one_nose():
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 0, 0), &"deck")
		_put(Vector3i(x, 0, -1), &"canopy")
	_builder.rebuild()
	assert_eq(_noses().size(), 1)

func test_no_windshield_no_nose():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	assert_eq(_noses().size(), 0)

func test_nose_spans_its_windshield_and_sits_beyond_it():
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 0, 0), &"deck")
		_put(Vector3i(x, 0, -1), &"canopy")
	_builder.rebuild()
	var shell: MeshInstance3D = _noses()[0]
	var box := shell.mesh.get_aabb()
	assert_almost_eq(box.size.x, 6.0, 0.01)
	assert_lt(box.end.z, -0.99, "the whole shell is forward of the canopy plane (z = -1)")
```

In `who-knows/test/unit/test_interior_builder.gd`, **delete** `test_canopy_panes_split_the_view_between_them` and `test_a_lone_canopy_pane_shows_the_whole_view`, and add:

```gdscript
## The canopy is the dressing's rounded nose now; the builder keeps only the
## collider, so the avatar still stops at the windshield plane.
func test_canopy_face_has_a_collider_and_no_box():
	_cat.register(_def(&"canopy", BlockDefinition.Occupancy.SOLID))
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"canopy")
	_builder.rebuild()
	var plane := Vector3(ShipGrid.CELL_SIZE * 0.5, 0, 0)
	assert_eq(_structure_colliders().filter(func(c): return c.position.is_equal_approx(plane)).size(), 1)
	assert_eq(_structure_meshes().filter(func(m): return m.position.is_equal_approx(plane)).size(), 0)
```

In `who-knows/test/unit/test_hud_scene_wiring.gd`, replace the comment block above `test_canopy_camera_looks_out_from_the_pilots_eye` (the three `##` lines beginning "The cockpit view is a SubViewport painted onto the canopy panes") with:

```gdscript
## The cockpit view is a SubViewport projected through the nose's windows, so
## the same parser defect that drops a HUD property would silently blank the
## windshield. These read the values back at runtime.
```

and add at the end of the file:

```gdscript
## The nose's windows look the canopy view up by direction from the pilot's
## eye, so the material must carry that eye and the camera's projection -- and
## still carry the viewport texture itself.
func test_canopy_material_projects_the_view_from_the_pilots_eye():
	var builder: InteriorBuilder = _root.get_node("Ship/Interior/InteriorBuilder")
	var mat := builder.canopy_material as ShaderMaterial
	assert_not_null(mat, "canopy material is a ShaderMaterial")
	assert_eq(mat.shader, InteriorMaterials.CANOPY_SHADER)
	assert_true(mat.get_shader_parameter(&"canopy_view") is ViewportTexture, "fed by the canopy SubViewport")
	var eye: Node3D = _root.get_node("Ship/Interior/PilotSeat/Eye")
	assert_almost_eq(mat.get_shader_parameter(&"eye_world"), eye.global_position, Vector3.ONE * 0.001)
	var cam: Camera3D = _root.get_node("Ship/Canopy/CanopyCam")
	assert_almost_eq(mat.get_shader_parameter(&"tan_half_fov_y"), tan(deg_to_rad(cam.fov) * 0.5), 0.0001)
	assert_almost_eq(mat.get_shader_parameter(&"aspect"), 3.0, 0.01)

func test_the_cabin_has_one_rounded_nose():
	assert_eq(_root.find_children("NoseShell*", "MeshInstance3D", true, false).size(), 1)
```

- [ ] **Step 2: Run to verify failure**

`-gselect=test_interior_props`, `test_interior_dressing`, `test_interior_builder`, `test_hud_scene_wiring`: the new tests fail (`nose` not found, no NoseShell, canopy box still present, material still a StandardMaterial3D).

- [ ] **Step 3: Add the nose to the prop library**

In `who-knows/src/ship/interior/interior_props.gd`, add these constants after `PORTHOLE_OPENING`:

```gdscript
## The rounded cockpit nose (spec §6), in a frame on the canopy plane at
## floor level: +x across the windshield, +y up, +z back into the room.
const NOSE_DEPTH := 1.4
## Fraction of the height that stays vertical before the nose curves back.
const NOSE_VERTICAL := 0.45
const NOSE_COLUMNS := 48
const NOSE_ROWS := 20
## Height of the lit brow line along the curve.
const NOSE_BROW := 1.8
## Ribs between and beside the windows, as arc length from the centre line.
const NOSE_RIBS: Array[float] = [-2.75, -1.3, 1.3, 2.75]
const DASH_HEIGHT := 0.9
## How far the dash's curved front edge reaches forward of the plane.
const DASH_INSET := 0.55
## Windows as (centre across, centre height, half width, half height), in
## metres; across is arc length along the nose from its centre line.
const NOSE_WINDOWS: Array[Vector4] = [
	Vector4(0.0, 1.325, 0.9, 0.375),
	Vector4(-1.95, 1.3, 0.5, 0.3),
	Vector4(1.95, 1.3, 0.5, 0.3),
]
```

and add these functions before `_at`:

```gdscript
## The rounded cockpit nose over a windshield `width` wide, bulging forward
## (-z) from the canopy plane: a shell with window cut-outs (the material's
## job; see canopy_window.gdshader), ribs that follow the curve, a lit brow, a
## curved dash with a wooden rail and a glowing plinth, three screen desks and
## the cockpit's key light. Returns the shell.
static func nose(kit: InteriorKit, frame: Transform3D, width: float, material: Material) -> MeshInstance3D:
	if material == null:
		material = InteriorMaterials.canopy_fallback()
	if material is ShaderMaterial:
		for k in NOSE_WINDOWS.size():
			material.set_shader_parameter("window_%d" % k, NOSE_WINDOWS[k])
		material.set_shader_parameter(&"shell_color", InteriorPalette.WALL)
		material.set_shader_parameter(&"frame_color", InteriorPalette.TRIM)

	# Arc length along the floor-level curve, so windows and ribs are placed
	# in metres rather than in angle.
	var arc := PackedFloat32Array()
	arc.resize(NOSE_COLUMNS + 1)
	var total := 0.0
	for i in range(1, NOSE_COLUMNS + 1):
		total += _nose_point(i, 0.0, width).distance_to(_nose_point(i - 1, 0.0, width))
		arc[i] = total

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in NOSE_ROWS + 1:
		var v := float(j) / NOSE_ROWS
		for i in NOSE_COLUMNS + 1:
			st.set_uv(Vector2(arc[i] - total * 0.5, v * HEADROOM))
			st.add_vertex(frame * _nose_point(i, v, width))
	for j in NOSE_ROWS:
		for i in NOSE_COLUMNS:
			# Clockwise as seen from the room: Godot's front face.
			var a := j * (NOSE_COLUMNS + 1) + i
			var c := a + NOSE_COLUMNS + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(c)
			st.add_index(c + 1)
	st.generate_normals()
	var shell := kit.add_mesh(st.commit(), material, "NoseShell")

	for target in NOSE_RIBS:
		if absf(target) > total * 0.5 - 0.1:
			continue
		var best := 0
		for i in NOSE_COLUMNS + 1:
			if absf(arc[i] - total * 0.5 - target) < absf(arc[best] - total * 0.5 - target):
				best = i
		_nose_rib(kit, frame, width, PI * float(best) / NOSE_COLUMNS)
	_nose_band(kit, frame, width, NOSE_BROW, NOSE_BROW + 0.03)
	_dash(kit, frame, width)
	kit.light(frame * Vector3(0, 1.6, 0.6), InteriorPalette.LIGHT_WARM, 0.5, 3.0, &"cockpit")
	return shell

## The shell's depth at height fraction v: vertical up to NOSE_VERTICAL, then
## curving back to meet the ceiling edge.
static func _nose_depth(v: float) -> float:
	if v <= NOSE_VERTICAL:
		return NOSE_DEPTH
	var t := (v - NOSE_VERTICAL) / (1.0 - NOSE_VERTICAL)
	return NOSE_DEPTH * sqrt(maxf(0.0, 1.0 - t * t))

static func _nose_point(i: int, v: float, width: float) -> Vector3:
	return _nose_at(PI * float(i) / NOSE_COLUMNS, v, width)

static func _nose_at(theta: float, v: float, width: float) -> Vector3:
	return Vector3(-width * 0.5 * cos(theta), HEADROOM * v, -_nose_depth(v) * sin(theta))

## The shell's normal at (theta, v), pointing into the room.
static func _nose_normal(theta: float, v: float, width: float) -> Vector3:
	var e := 0.001
	var dt := _nose_at(theta + e, v, width) - _nose_at(theta - e, v, width)
	var dv := _nose_at(theta, minf(v + e, 1.0), width) - _nose_at(theta, maxf(v - e, 0.0), width)
	var n := dt.cross(dv).normalized()
	return n if n.z > 0.0 else -n

## A chunky rib, 0.1 m wide and 0.05 m proud, from the dash to the ceiling
## along one meridian of the shell: a face and two sides.
static func _nose_rib(kit: InteriorKit, frame: Transform3D, width: float, theta: float) -> void:
	var half := 0.05 / (width * 0.5)
	var steps := 10
	var v0 := DASH_HEIGHT / HEADROOM
	var color := _c(InteriorPalette.TRIM)
	for k in steps:
		var va := lerpf(v0, 1.0, float(k) / steps)
		var vb := lerpf(v0, 1.0, float(k + 1) / steps)
		var na := _nose_normal(theta, va, width)
		var nb := _nose_normal(theta, vb, width)
		var la := _nose_at(theta - half, va, width)
		var ra := _nose_at(theta + half, va, width)
		var lb := _nose_at(theta - half, vb, width)
		var rb := _nose_at(theta + half, vb, width)
		kit.quad(SOLID, frame * (la + na * 0.05), frame * (ra + na * 0.05), frame * (rb + nb * 0.05),
			frame * (lb + nb * 0.05), (frame.basis * na).normalized(), color)
		var side_n := (ra - la).normalized()
		kit.quad(SOLID, frame * la, frame * (la + na * 0.05), frame * (lb + nb * 0.05), frame * lb,
			(frame.basis * -side_n).normalized(), color)
		kit.quad(SOLID, frame * ra, frame * (ra + na * 0.05), frame * (rb + nb * 0.05), frame * rb,
			(frame.basis * side_n).normalized(), color)

## A lit ribbon along the whole curve between two floor-relative heights,
## lifted just off the shell so it never z-fights it.
static func _nose_band(kit: InteriorKit, frame: Transform3D, width: float, h_lo: float, h_hi: float) -> void:
	var v_lo := h_lo / HEADROOM
	var v_hi := h_hi / HEADROOM
	var color := _lit(InteriorPalette.LIGHT_WARM, 2.2)
	for i in NOSE_COLUMNS:
		var t0 := PI * float(i) / NOSE_COLUMNS
		var t1 := PI * float(i + 1) / NOSE_COLUMNS
		var n := _nose_normal((t0 + t1) * 0.5, (v_lo + v_hi) * 0.5, width)
		kit.quad(GLOW, frame * (_nose_at(t0, v_lo, width) + n * 0.01), frame * (_nose_at(t1, v_lo, width) + n * 0.01),
			frame * (_nose_at(t1, v_hi, width) + n * 0.01), frame * (_nose_at(t0, v_hi, width) + n * 0.01),
			(frame.basis * n).normalized(), color)

## The dash's front edge: a shallower curve inside the shell, so the rail on
## top of it sweeps round the cockpit the way the shell does.
static func _dash_front(i: int, width: float) -> Vector3:
	var theta := PI * float(i) / NOSE_COLUMNS
	return Vector3(-width * 0.5 * cos(theta), 0.0, -DASH_INSET * sin(theta))

## The alcove floor, the dash top, its curved face, the glowing plinth under
## it, the wooden rail on it and three screen desks.
static func _dash(kit: InteriorKit, frame: Transform3D, width: float) -> void:
	var up := (frame.basis * Vector3.UP).normalized()
	var toward_room := (frame.basis * Vector3.BACK).normalized()
	var cap_v := DASH_HEIGHT / HEADROOM
	var lift := Vector3(0, DASH_HEIGHT, 0)
	for i in NOSE_COLUMNS:
		var f0 := _dash_front(i, width)
		var f1 := _dash_front(i + 1, width)
		var s0 := _nose_point(i, cap_v, width)
		var s1 := _nose_point(i + 1, cap_v, width)
		var g0 := _nose_point(i, 0.0, width)
		var g1 := _nose_point(i + 1, 0.0, width)
		kit.quad(SOLID, frame * Vector3(f0.x, 0.001, 0.0), frame * Vector3(f1.x, 0.001, 0.0),
			frame * Vector3(g1.x, 0.001, g1.z), frame * Vector3(g0.x, 0.001, g0.z), up,
			_c(InteriorPalette.FLOOR_BRIDGE))
		kit.quad(SOLID, frame * (f0 + lift), frame * (f1 + lift), frame * Vector3(s1.x, DASH_HEIGHT, s1.z),
			frame * Vector3(s0.x, DASH_HEIGHT, s0.z), up, _c(InteriorPalette.TRIM))
		var face_n := (frame.basis * (f1 - f0).cross(Vector3.UP)).normalized()
		if face_n.dot(toward_room) < 0.0:
			face_n = -face_n
		kit.quad(SOLID, frame * (f0 + Vector3(0, 0.1, 0)), frame * (f1 + Vector3(0, 0.1, 0)),
			frame * (f1 + lift), frame * (f0 + lift), face_n, _c(InteriorPalette.WALL_LOW))
		kit.quad(GLOW, frame * (f0 + Vector3(0, 0.0, -0.05)), frame * (f1 + Vector3(0, 0.0, -0.05)),
			frame * (f1 + Vector3(0, 0.1, -0.05)), frame * (f0 + Vector3(0, 0.1, -0.05)), face_n,
			_lit(InteriorPalette.LIGHT_WARM, 2.5))
		kit.tube_between(SOLID, frame * (f0 + lift + Vector3(0, 0.04, 0)),
			frame * (f1 + lift + Vector3(0, 0.04, 0)), 0.055, _c(InteriorPalette.WOOD))
	for k in 3:
		var desk := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-60.0)),
			Vector3((k - 1) * width * 0.28, DASH_HEIGHT + 0.09, -0.8))
		kit.bevel_box(SOLID, frame * desk, Vector3(minf(1.3, width * 0.25), 0.32, 0.06), 0.025,
			_c(InteriorPalette.TRIM))
		kit.screen(frame * desk * _at(Vector3(0, 0, 0.031)), Vector2(minf(1.18, width * 0.22), 0.24),
			_mode(k), 0.2 + 0.3 * k)
```

- [ ] **Step 4: Dress canopy groups**

In `who-knows/src/ship/interior/interior_dressing.gd`, in `build()`, replace

```gdscript
	for face in layout.faces():
		_dress(kit, face)
	kit.commit()
```
with
```gdscript
	for face in layout.faces():
		_dress(kit, face)
	for group in layout.canopy_groups():
		_nose(kit, group, canopy_material)
	kit.commit()
```

and add this function after `face_variety`:

```gdscript
## One rounded nose over a windshield group, in a frame on the canopy plane at
## floor level: +x across the group, +y up, +z back into the room.
static func _nose(kit: InteriorKit, group: Dictionary, material: Material) -> void:
	var normal: Vector3i = group["normal"]
	var n := Vector3(normal)
	var across := Vector3.UP.cross(-n)
	var coords: Array = group["coords"]
	var lo := INF
	var hi := -INF
	for coord: Vector3i in coords:
		var c := ShipGrid.cell_center(coord).dot(across)
		lo = minf(lo, c - ShipGrid.CELL_SIZE * 0.5)
		hi = maxf(hi, c + ShipGrid.CELL_SIZE * 0.5)
	var first: Vector3i = coords[0]
	var plane := (ShipGrid.cell_center(first) + n * ShipGrid.CELL_SIZE * 0.5).dot(n)
	var origin := across * ((lo + hi) * 0.5) + n * plane + Vector3.UP * floor_y(first)
	InteriorProps.nose(kit, Transform3D(Basis(across, Vector3.UP, -n), origin), hi - lo, material)
```

- [ ] **Step 5: Make canopy faces colliders only, and delete the pane code**

In `who-knows/src/ship/interior_builder.gd`:

1. Replace the second paragraph of the class doc comment (the one beginning "A walkable cell whose face touches a `canopy` cell") with:

```gdscript
## A walkable cell whose face touches a `canopy` cell keeps a collider there
## but no box: the visible canopy is the rounded nose InteriorDressing builds
## over the whole windshield (spec §6), so the avatar stops at the plane like
## a railing while the pilot looks out through the nose's windows.
```

2. Replace the `canopy_material` doc comment and export with:

```gdscript
## The nose shell's material: a ShaderMaterial on canopy_window.gdshader
## carrying the canopy SubViewport's ViewportTexture. Stays null in tests,
## where the nose falls back to the same shader with black windows -- never a
## hole.
@export var canopy_material: Material
```

3. Delete the `_canopy_panes` variable, `_canopy_fallback_material`, and the functions `canopy_pane_uvs()`, `_build_canopy_panes()`, `_sorted_unique()`, `_pane_mat()` and `_canopy_mat()`, with their doc comments. In `_clear()`, delete the line `_canopy_panes.clear()`.

4. In `_build_structure()`, delete `var panes: Array[Dictionary] = []` and the trailing `_build_canopy_panes(panes)`, and replace the CANOPY branch with:

```gdscript
			InteriorLayout.Kind.CANOPY:
				_canopy_faces.append(_add_collider(_physics_body, _wall_size(normal), at))
```

- [ ] **Step 6: Swap the scene's canopy material**

Edit `who-knows/scenes/flight_test.tscn`. **No `#` comments.**

1. Change the first line `[gd_scene load_steps=29 format=3]` to `[gd_scene load_steps=30 format=3]`.
2. After the line `[ext_resource type="Script" path="res://src/ui/hud_band.gd" id="16_hud_band"]`, add:
```
[ext_resource type="Shader" path="res://data/materials/interior/canopy_window.gdshader" id="17_canopy_window"]
```
3. Replace
```
[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_canopy"]
resource_local_to_scene = true
shading_mode = 0
albedo_texture = SubResource("ViewportTexture_canopy")
```
with
```
[sub_resource type="ShaderMaterial" id="ShaderMaterial_canopy"]
resource_local_to_scene = true
shader = ExtResource("17_canopy_window")
shader_parameter/canopy_view = SubResource("ViewportTexture_canopy")
```
4. Replace `canopy_material = SubResource("StandardMaterial3D_canopy")` with `canopy_material = SubResource("ShaderMaterial_canopy")`.

- [ ] **Step 7: Set the projection uniforms**

In `who-knows/scenes/flight_test.gd`, replace `_aim_canopy_view()` and its doc comment with:

```gdscript
## Puts the canopy camera where the pilot's head is, and tells the nose's
## windows where that is.
##
## Interior space and exterior space are both grid space, offset from each
## other, so the eye's interior-local position is exactly where that eye
## sits on the hull. Copying it here rather than authoring the camera's
## position in the scene keeps one source of truth: move the seat and the
## view through the glass moves with it.
##
## The windows sample the canopy view by direction from the eye
## (canopy_window.gdshader), so the material needs the eye's world position
## and the camera's projection -- set here, from the same camera and viewport.
func _aim_canopy_view() -> void:
	var eye: Node3D = $Ship/Interior/PilotSeat/Eye
	$Ship/Exterior/CanopyRemote.position = _ship.interior.to_local(eye.global_position)
	var material := _ship.interior_builder.canopy_material as ShaderMaterial
	if material == null:
		return
	var cam: Camera3D = $Ship/Canopy/CanopyCam
	var view: SubViewport = $Ship/Canopy
	material.set_shader_parameter(&"eye_world", eye.global_position)
	material.set_shader_parameter(&"tan_half_fov_y", tan(deg_to_rad(cam.fov) * 0.5))
	material.set_shader_parameter(&"aspect", float(view.size.x) / float(view.size.y))
```

- [ ] **Step 8: Run the tests, then the full suite**

Focused runs of the four test files: all pass. Full suite: no failures.

- [ ] **Step 9: Headless load and render smoke**

```powershell
& "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" --path "D:\git\whoknows\who-knows" --quit-after 120 "res://scenes/flight_test.tscn"
```
Run it **without** `--headless`, so shaders compile. Expected: no `SHADER ERROR`, `SCRIPT ERROR` or `ERROR` lines.

- [ ] **Step 10: Commit**

```bash
git add who-knows/src/ship/interior/interior_props.gd who-knows/src/ship/interior/interior_dressing.gd who-knows/src/ship/interior_builder.gd who-knows/scenes/flight_test.tscn who-knows/scenes/flight_test.gd who-knows/test/unit/test_interior_props.gd who-knows/test/unit/test_interior_dressing.gd who-knows/test/unit/test_interior_builder.gd who-knows/test/unit/test_hud_scene_wiring.gd
git commit -m "feat: give the cockpit a rounded nose with projected windows

The flat three-pane windshield becomes a curved shell with three rounded
windows. Each window samples the canopy view by direction from the
pilot's eye, so windows on a curve line up into one view and the
velocity marker still registers. A curved dash with a wooden rail sits
in front, and the canopy faces keep only their colliders.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Mood: interior environment, old lights out, seat recolour

**Files:**
- Create: `who-knows/data/environments/ship_interior.tres`
- Modify: `who-knows/scenes/flight_test.tscn` (delete the three ceiling fluorescents)
- Modify: `who-knows/scenes/flight_test.gd` (assign the interior environment)
- Modify: `who-knows/data/blocks/meshes/pilot_seat.tres` (upholstery colour)
- Test: `who-knows/test/unit/test_hud_scene_wiring.gd`

**Interfaces:**
- Consumes: `InteriorPalette.SEAT`.
- Produces: the interior camera (`Ship/Interior/Avatar/Head/Camera3D`) has `environment = res://data/environments/ship_interior.tres`.

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_hud_scene_wiring.gd`:

```gdscript
func test_old_ceiling_fluorescents_are_gone():
	for i in [1, 2, 3]:
		assert_null(_root.get_node_or_null("Ship/Interior/CeilingLight%d" % i))

## The interior's dim warm mood is on the interior camera alone, so the chase
## view and the canopy feed keep the world's look.
func test_interior_camera_carries_the_interior_mood():
	var cam: Camera3D = _root.get_node("Ship/Interior/Avatar/Head/Camera3D")
	var env := cam.environment
	assert_not_null(env)
	assert_eq(env.resource_path, "res://data/environments/ship_interior.tres")
	assert_true(env.glow_enabled, "bloom is what turns the thin lit strips into light")
	assert_false(env.ssao_enabled, "stylized and cheap: no SSAO")
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_FILMIC)
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	assert_almost_eq(env.ambient_light_energy, 0.45, 0.001)

func test_chase_camera_keeps_the_world_look():
	var cam: Camera3D = _root.get_node("Ship/Exterior/ChaseCamera")
	assert_null(cam.environment)

func test_pilot_seat_is_upholstered_to_match():
	var mesh: ArrayMesh = load("res://data/blocks/meshes/pilot_seat.tres")
	var upholstery := mesh.surface_get_material(0) as StandardMaterial3D
	assert_true(upholstery.albedo_color.is_equal_approx(InteriorPalette.SEAT))
```

- [ ] **Step 2: Run to verify failure**

`-gselect=test_hud_scene_wiring`: the four new tests fail.

- [ ] **Step 3: Create the environment**

Create `who-knows/data/environments/ship_interior.tres` exactly as follows. **No `#` comments.**

```
[gd_resource type="Environment" format=3]

[resource]
background_mode = 1
background_color = Color(0, 0, 0, 1)
ambient_light_source = 2
ambient_light_color = Color(0.2901961, 0.25882354, 0.22745098, 1)
ambient_light_energy = 0.45
tonemap_mode = 2
glow_enabled = true
glow_intensity = 0.5
glow_bloom = 0.03
glow_hdr_threshold = 1.1
```

(`background_mode = 1` is a custom colour, `ambient_light_source = 2` is a colour, `tonemap_mode = 2` is filmic. The ambient colour is `#4A423A`.)

- [ ] **Step 4: Assign it to the interior camera**

In `who-knows/scenes/flight_test.gd`, add below the `@onready` lines:

```gdscript
## The interior's own mood (spec §3.3): dim and warm, with bloom turning the
## thin lit strips into light. It goes on the interior camera, not the world,
## so the chase view and the canopy feed keep the WorldEnvironment's look.
const INTERIOR_ENVIRONMENT: Environment = preload("res://data/environments/ship_interior.tres")
```

In `_ready()`, add `_set_interior_mood()` after `_aim_canopy_view()`, and add this function after `_aim_canopy_view()`:

```gdscript
## The interior camera is also the seated camera -- CameraDirector moves it
## between head and seat -- so one assignment covers walking and flying.
func _set_interior_mood() -> void:
	var cam: Camera3D = $Ship/Interior/Avatar/Head/Camera3D
	cam.environment = INTERIOR_ENVIRONMENT
```

- [ ] **Step 5: Remove the old fluorescents from the scene**

Edit `who-knows/scenes/flight_test.tscn`. **No `#` comments.**

1. Change the first line to `[gd_scene load_steps=28 format=3]`.
2. Delete these two sub-resources, and the blank line after each:
```
[sub_resource type="BoxMesh" id="BoxMesh_light_strip"]
size = Vector3(1, 0.06, 0.2)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_light_strip"]
albedo_color = Color(1, 0.92, 0.8, 1)
emission_enabled = true
emission = Color(1, 0.85, 0.55, 1)
emission_energy_multiplier = 2.0
```
3. Delete the six node blocks `CeilingLight1`, `CeilingLight1/Strip`, `CeilingLight2`, `CeilingLight2/Strip`, `CeilingLight3` and `CeilingLight3/Strip`, from `[node name="CeilingLight1" type="OmniLight3D" parent="Ship/Interior"]` through the third Strip's `material_override = SubResource("StandardMaterial3D_light_strip")` line, together with the blank line after it. The next block, `[node name="SkyPivot" ...]`, must stay.

- [ ] **Step 6: Recolour the seat**

In `who-knows/data/blocks/meshes/pilot_seat.tres`, in `[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_fo2s5"]`, change
`albedo_color = Color(0.5411765, 0.18431373, 0.15294118, 1)` to
`albedo_color = Color(0.76862746, 0.63529414, 0.47843137, 1)`. That is `#C4A27A`. **No `#` comments.**

- [ ] **Step 7: Run the tests, then the full suite**

`-gselect=test_hud_scene_wiring`: all pass. Full suite: no failures.

- [ ] **Step 8: Render smoke without `--headless`** (the Task 6 Step 9 command). Expected: clean output.

- [ ] **Step 9: Commit**

```bash
git add who-knows/data/environments who-knows/scenes/flight_test.tscn who-knows/scenes/flight_test.gd who-knows/data/blocks/meshes/pilot_seat.tres who-knows/test/unit/test_hud_scene_wiring.gd
git commit -m "feat: dim warm interior mood, retire the ceiling fluorescents

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Phase A checkpoint (controller, with the owner)

This task is for the controller, not a subagent.

- [ ] **Step 1:** Render the real scene from the four fixed viewpoints (aft looking forward, pilot's eye, side wall, looking aft) with the throwaway probe in the session scratchpad (`shoot.gd`, as used during design). Check for missing faces, z-fighting, blown-out light and misaligned windows.
- [ ] **Step 2:** Measure the average frame time over 120 frames in the cabin at 1280 × 720. Target: 60 fps or better on the GTX 960.
- [ ] **Step 3:** Send the screenshots to the owner and fix anything they flag before starting Phase B.

# Phase B — rooms

### Task 9: Room blocks

**Files:**
- Create: `who-knows/data/blocks/bunk_room.tres`, `galley.tres`, `bathroom.tres`, `closet.tres`, `weapon_room.tres`
- Modify: `who-knows/test/unit/test_block_data.gd`

**Interfaces:**
- Produces: block ids `&"bunk_room"`, `&"galley"`, `&"bathroom"`, `&"closet"`, `&"weapon_room"`. Each is `DECK` occupancy, `INTERIOR` category, `mass_t = 0.4`, `power_draw = 0.1`, `hp = 60`, with a floor-slab `BoxMesh`, identical to `deck` apart from id and name.

- [ ] **Step 1: Write the failing tests**

In `who-knows/test/unit/test_block_data.gd`, replace `test_all_sixteen_blocks_load` with:

```gdscript
func test_all_twenty_one_blocks_load():
	assert_eq(_cat.ids().size(), 21, "16, plus the five room blocks of the interior redesign")
```

add the five room ids to the list in `test_required_ids_exist`:

```gdscript
			&"bulkhead", &"door", &"pilot_seat", &"ladder", &"airlock", &"canopy",
			&"bunk_room", &"galley", &"bathroom", &"closet", &"weapon_room"]:
```

and append:

```gdscript
## Rooms are walkable floor that says what the room is for. They weigh and
## draw exactly what deck does, so turning deck cells into rooms can never
## move a ship's centre of mass or power budget (interior redesign spec §7.1).
func test_room_blocks_are_deck_with_a_purpose():
	var deck := _cat.get_def(&"deck")
	for id in [&"bunk_room", &"galley", &"bathroom", &"closet", &"weapon_room"]:
		var def := _cat.get_def(id)
		assert_eq(def.occupancy, BlockDefinition.Occupancy.DECK, "%s is walkable floor" % id)
		assert_eq(def.category, BlockDefinition.Category.INTERIOR)
		assert_eq(def.mass_t, deck.mass_t, "%s weighs what deck weighs" % id)
		assert_eq(def.power_draw, deck.power_draw, "%s draws what deck draws" % id)
```

- [ ] **Step 2: Run to verify failure**

`-gselect=test_block_data`: the count and required-id tests fail.

- [ ] **Step 3: Create the five blocks**

Create `who-knows/data/blocks/bunk_room.tres`. **No `#` comments.**

```
[gd_resource type="Resource" script_class="BlockDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/ship/block_definition.gd" id="1_script"]

[sub_resource type="BoxMesh" id="BoxMesh_deck"]
size = Vector3(2, 0.15, 2)

[resource]
script = ExtResource("1_script")
id = &"bunk_room"
display_name = "Bunk Room"
category = 2
occupancy = 1
mass_t = 0.4
hp = 60
power_gen = 0.0
power_draw = 0.1
thrust_kn = 0.0
grav_radius = 0.0
mesh = SubResource("BoxMesh_deck")
```

Create the other four identically, changing only `id` and `display_name`:

| File | `id` | `display_name` |
|---|---|---|
| `galley.tres` | `&"galley"` | `"Galley"` |
| `bathroom.tres` | `&"bathroom"` | `"Bathroom"` |
| `closet.tres` | `&"closet"` | `"Closet"` |
| `weapon_room.tres` | `&"weapon_room"` | `"Weapon Room"` |

- [ ] **Step 4: Run the tests, then the full suite**

`-gselect=test_block_data`: all pass. Full suite: no failures. The exterior builder draws the new blocks' slabs inside the hull, where they are never seen.

- [ ] **Step 5: Commit**

```bash
git add who-knows/data/blocks/bunk_room.tres who-knows/data/blocks/galley.tres who-knows/data/blocks/bathroom.tres who-knows/data/blocks/closet.tres who-knows/data/blocks/weapon_room.tres who-knows/test/unit/test_block_data.gd
git commit -m "feat: add five room blocks: bunk room, galley, bathroom, closet, weapon room

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: InteriorLayout: rooms, partitions and doorways

**Files:**
- Modify: `who-knows/src/ship/interior/interior_layout.gd`
- Test: `who-knows/test/unit/test_interior_layout.gd`

**Interfaces:**
- Produces:
  - `const ROOM_IDS: Array[StringName]`
  - `Kind` gains `DOORWAY`; `WallVariant` gains `FEATURE`, `SECONDARY`.
  - Records gain `partition: bool` and `skin_flank: bool`. A partition is a face between two walkable cells of different rooms; it has a record on each side, and exactly one of the two has `owner = true`.
  - `rooms() -> Array[Dictionary]`: `{zone: StringName, coords: Array[Vector3i], doorway: Dictionary}`, where `doorway` is `{coord, normal}` of the chosen face, or `{}`.
  - `zone_at(coord: Vector3i) -> StringName`

- [ ] **Step 1: Write the failing tests**

In `who-knows/test/unit/test_interior_layout.gd`, add to `before_each()` after the airlock line:

```gdscript
	for id in InteriorLayout.ROOM_IDS:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))
```

and append:

```gdscript
func _walls_of(layout: InteriorLayout, coord: Vector3i) -> Array:
	return layout.faces().filter(func(f): return f["coord"] == coord
		and (f["kind"] == InteriorLayout.Kind.WALL or f["kind"] == InteriorLayout.Kind.DOORWAY))

func test_room_cells_take_their_room_as_zone():
	_put(Vector3i(0, 0, 0), &"galley")
	var layout := _plan()
	assert_eq(layout.zone_at(Vector3i(0, 0, 0)), &"galley")
	assert_eq(_face(layout, Vector3i(0, 0, 0), Vector3i.DOWN)["zone"], &"galley")

func test_a_partition_has_a_record_on_each_side_and_one_owner():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(0, 0, 1), &"deck")   # so the galley's doorway is not this face
	var layout := _plan()
	var here := _face(layout, Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	var there := _face(layout, Vector3i(1, 0, 0), Vector3i(-1, 0, 0))
	assert_true(here["partition"] and there["partition"])
	assert_ne(here["owner"], there["owner"], "exactly one side builds it")

func test_no_wall_between_bridge_and_common():
	_put(Vector3i(0, 0, 0), &"seat")
	_put(Vector3i(0, 0, 1), &"deck")   # bridge
	_put(Vector3i(0, 0, 2), &"deck")   # common
	assert_true(_face(_plan(), Vector3i(0, 0, 1), Vector3i(0, 0, 1)).is_empty())

func test_each_room_gets_exactly_one_doorway():
	for z in [0, 1]:
		_put(Vector3i(0, 0, z), &"deck")
		_put(Vector3i(-1, 0, z), &"bunk_room")
	_put(Vector3i(-1, 0, -1), &"deck")
	var layout := _plan()
	assert_eq(layout.rooms().size(), 1, "two bunk cells, one room")
	var doorways := layout.faces().filter(func(f): return f["kind"] == InteriorLayout.Kind.DOORWAY)
	assert_eq(doorways.size(), 2, "one doorway, seen from both sides")

func test_doorway_prefers_a_flank_onto_common_space():
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(0, 0, 0), &"deck")    # corridor, across a flank
	_put(Vector3i(1, 0, -1), &"deck")   # bridge side, across an end
	var door: Dictionary = _plan().rooms()[0]["doorway"]
	assert_eq(door["coord"], Vector3i(1, 0, 0))
	assert_eq(door["normal"], Vector3i(-1, 0, 0))

func test_doorway_ties_break_forward():
	for z in [0, 1]:
		_put(Vector3i(0, 0, z), &"deck")
		_put(Vector3i(-1, 0, z), &"bunk_room")
	var door: Dictionary = _plan().rooms()[0]["doorway"]
	assert_eq(door["coord"], Vector3i(-1, 0, 0), "the forward of two equal faces")

func test_a_room_with_no_common_neighbour_opens_onto_another_room():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(2, 0, 0), &"closet")   # only touches the galley
	var layout := _plan()
	for room in layout.rooms():
		assert_false(room["doorway"].is_empty(), "%s has a way in" % room["zone"])

func test_feature_wall_prefers_an_outer_flank():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"deck")
	_put(Vector3i(-1, 0, 0), &"bunk_room")
	_put(Vector3i(-1, 0, 1), &"bunk_room")
	_put(Vector3i(-2, 0, 0), &"hull")
	_put(Vector3i(-2, 0, 1), &"hull")
	var layout := _plan()
	for coord in [Vector3i(-1, 0, 0), Vector3i(-1, 0, 1)]:
		assert_eq(_face(layout, coord, Vector3i(-1, 0, 0))["variant"], InteriorLayout.WallVariant.FEATURE,
			"the hull side, not the corridor side")

func test_a_feature_on_the_outer_skin_gets_a_porthole():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(2, 0, 0), &"hull")   # vacuum beyond
	var f := _face(_plan(), Vector3i(1, 0, 0), Vector3i(1, 0, 0))
	assert_eq(f["variant"], InteriorLayout.WallVariant.FEATURE)
	assert_true(f["porthole"])

func test_every_room_cell_has_one_feature_and_the_rest_secondary():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(1, 0, 1), &"closet")
	var layout := _plan()
	for coord in [Vector3i(1, 0, 0), Vector3i(1, 0, 1)]:
		var features := 0
		for f in _walls_of(layout, coord):
			if f["kind"] == InteriorLayout.Kind.WALL:
				assert_true(f["variant"] == InteriorLayout.WallVariant.FEATURE
					or f["variant"] == InteriorLayout.WallVariant.SECONDARY)
				if f["variant"] == InteriorLayout.WallVariant.FEATURE:
					features += 1
		assert_eq(features, 1, "%s has one feature wall" % coord)

func test_partitions_are_never_portholes_or_hatches():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(0, 0, -1), &"deck")
	for f in _plan().faces():
		if f.get("partition", false):
			assert_false(f["porthole"])
			assert_ne(f["variant"], InteriorLayout.WallVariant.HATCH)
```

- [ ] **Step 2: Run to verify failure**

`-gselect=test_interior_layout`: fails, `ROOM_IDS` not found.

- [ ] **Step 3: Extend the layout**

In `who-knows/src/ship/interior/interior_layout.gd`:

1. Replace the enums and add the room ids:

```gdscript
enum Kind { FLOOR, CEILING, WALL, CANOPY, DOORWAY }
enum WallVariant { NONE, HATCH, CONSOLE, PORTHOLE, LOCKERS, DISPLAY, PANEL, FEATURE, SECONDARY }

## Walkable blocks that make a room (spec §7.1). Any other walkable cell is
## bridge or common space.
const ROOM_IDS: Array[StringName] = [&"bunk_room", &"galley", &"bathroom", &"closet", &"weapon_room"]
```

2. Add to the class doc comment, before "Pure:":

```gdscript
## Rooms (spec §7.2): a face between two walkable cells of different rooms is
## a partition, with a record on each side and one owner. Each room gets
## exactly one doorway (kind DOORWAY on both records), and each room cell
## picks one FEATURE wall for its main furniture; the rest are SECONDARY.
```

3. Add member variables after `_walkable`:

```gdscript
var _zones: Dictionary = {}   # Vector3i -> StringName
var _rooms: Array[Dictionary] = []
```

4. Replace `plan()` with:

```gdscript
static func plan(grid: ShipGrid, catalog: BlockCatalog, walkable: Array) -> InteriorLayout:
	var layout := InteriorLayout.new()
	layout._walkable.assign(walkable)
	var walkable_set := {}
	for coord in walkable:
		walkable_set[coord] = true
	# Zones first: a partition needs to know both sides.
	for coord: Vector3i in layout._walkable:
		layout._zones[coord] = _zone(grid, catalog, coord)
	var groups := {}   # plane key -> {normal, coords}
	for coord: Vector3i in layout._walkable:
		var zone: StringName = layout._zones[coord]
		var in_room := ROOM_IDS.has(zone)
		var is_mount := _is_mount(grid, catalog, coord)
		var by_the_helm := _has_mount_neighbour(grid, catalog, coord) or _has_canopy_neighbour(grid, coord)
		layout._faces.append(_record(coord, Vector3i.DOWN, Kind.FLOOR, zone))
		layout._faces.append(_record(coord, Vector3i.UP, Kind.CEILING, zone))
		for normal in _HORIZONTAL:
			var neighbour := coord + normal
			if walkable_set.has(neighbour):
				if _room_of(layout._zones[neighbour]) == _room_of(zone):
					continue   # open passage within one space
				var partition := _record(coord, normal, Kind.WALL, zone)
				partition["partition"] = true
				partition["owner"] = coord < neighbour
				partition["variant"] = WallVariant.SECONDARY if in_room else _common_variant(
					grid, coord, normal, is_mount, by_the_helm, true)
				layout._faces.append(partition)
				continue
			if _id_at(grid, neighbour) == CANOPY_ID:
				layout._faces.append(_record(coord, normal, Kind.CANOPY, zone))
				var key := "%s:%d:%d" % [normal, _along(neighbour, normal), coord.y]
				groups.get_or_add(key, {"normal": normal, "coords": []})["coords"].append(coord)
				continue
			var face := _record(coord, normal, Kind.WALL, zone)
			face["skin_flank"] = normal.x != 0 and _is_outer_skin(grid, coord, normal)
			if in_room:
				face["variant"] = WallVariant.SECONDARY
			else:
				var variant := _common_variant(grid, coord, normal, is_mount, by_the_helm, false)
				face["variant"] = variant
				face["porthole"] = variant == WallVariant.PORTHOLE
			layout._faces.append(face)
	for key in groups:
		layout._groups.append(groups[key])
	layout._resolve_rooms()
	return layout
```

5. Add these public accessors after `walkable_coords()`:

```gdscript
## Every room: {zone, coords, doorway}, where doorway is {coord, normal} of
## the face chosen as its way in, or {} for a room with no neighbour at all.
func rooms() -> Array[Dictionary]:
	return _rooms.duplicate()

## A walkable cell's zone: its room id, or ZONE_BRIDGE / ZONE_COMMON.
func zone_at(coord: Vector3i) -> StringName:
	return _zones.get(coord, &"")
```

6. Replace `_record` with:

```gdscript
static func _record(coord: Vector3i, normal: Vector3i, kind: Kind, zone: StringName) -> Dictionary:
	return {
		"coord": coord, "normal": normal, "kind": kind, "variant": WallVariant.NONE,
		"zone": zone, "porthole": false, "owner": true, "partition": false, "skin_flank": false,
	}
```

7. Replace `_common_variant` with the version below, which takes a `partition` flag:

```gdscript
## Wall variants for bridge and common cells, in strict priority order. A
## partition is inside the ship, so it can be neither a hatch nor a porthole.
static func _common_variant(grid: ShipGrid, coord: Vector3i, normal: Vector3i,
		is_mount: bool, by_the_helm: bool, partition: bool) -> WallVariant:
	if not partition and _id_at(grid, coord) == AIRLOCK_ID and not grid.has_block(coord + normal):
		return WallVariant.HATCH
	var skin_flank := not partition and normal.x != 0 and _is_outer_skin(grid, coord, normal)
	if is_mount:
		# The cell's own fixture stands here; nothing that sticks out may too.
		return WallVariant.PORTHOLE if skin_flank else WallVariant.PANEL
	if by_the_helm:
		return WallVariant.CONSOLE
	if skin_flank:
		return WallVariant.PORTHOLE
	return WallVariant.LOCKERS if face_hash(coord, normal) % 2 == 0 else WallVariant.DISPLAY
```

8. Add these functions before `_is_outer_skin`:

```gdscript
static func _zone(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> StringName:
	var id := _id_at(grid, coord)
	if ROOM_IDS.has(id):
		return id
	if _is_mount(grid, catalog, coord) or _has_mount_neighbour(grid, catalog, coord) \
			or _has_canopy_neighbour(grid, coord):
		return ZONE_BRIDGE
	return ZONE_COMMON

## Bridge and common space are one open space; only rooms are walled off.
static func _room_of(zone: StringName) -> StringName:
	return zone if ROOM_IDS.has(zone) else &""

static func _key(coord: Vector3i, normal: Vector3i) -> String:
	return "%s|%s" % [coord, normal]

## Finds every room, gives each one doorway and each room cell a feature wall.
func _resolve_rooms() -> void:
	var index := {}   # "coord|normal" -> index into _faces
	for i in _faces.size():
		index[_key(_faces[i]["coord"], _faces[i]["normal"])] = i
	var seen := {}
	for coord in _walkable:
		var zone: StringName = _zones[coord]
		if not ROOM_IDS.has(zone) or seen.has(coord):
			continue
		var cells := _flood_room(coord, zone, seen)
		var doorway := _choose_doorway(cells, index)
		if not doorway.is_empty():
			var c: Vector3i = doorway["coord"]
			var n: Vector3i = doorway["normal"]
			for key in [_key(c, n), _key(c + n, -n)]:
				var face: Dictionary = _faces[index[key]]
				face["kind"] = Kind.DOORWAY
				face["variant"] = WallVariant.NONE
				face["porthole"] = false
		_rooms.append({"zone": zone, "coords": cells, "doorway": doorway})
		for cell in cells:
			_choose_feature(cell, index)

## The connected cells of one room: horizontal neighbours with the same zone.
func _flood_room(start: Vector3i, zone: StringName, seen: Dictionary) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var frontier: Array[Vector3i] = [start]
	seen[start] = true
	while not frontier.is_empty():
		var cell: Vector3i = frontier.pop_back()
		cells.append(cell)
		for normal in _HORIZONTAL:
			var next := cell + normal
			if not seen.has(next) and _zones.get(next, &"") == zone:
				seen[next] = true
				frontier.append(next)
	cells.sort()
	return cells

## The one partition face a room opens through, ranked by: onto bridge or
## common space before onto another room; a flank (corridors run fore-aft)
## before an end; nearest the room's centroid; then forward-most, then port-most.
func _choose_doorway(cells: Array[Vector3i], index: Dictionary) -> Dictionary:
	var centroid := Vector3.ZERO
	for cell in cells:
		centroid += Vector3(cell)
	centroid /= float(cells.size())
	var best := {}
	var best_score: Array = []
	for cell in cells:
		for normal in _HORIZONTAL:
			var key := _key(cell, normal)
			if not index.has(key):
				continue
			var face: Dictionary = _faces[index[key]]
			if face["kind"] != Kind.WALL or not face["partition"]:
				continue
			var score := [
				1 if ROOM_IDS.has(_zones[cell + normal]) else 0,
				0 if normal.x != 0 else 1,
				(Vector3(cell) + Vector3(normal) * 0.5).distance_to(centroid),
				cell.z,
				cell.x,
			]
			if best.is_empty() or _ranks_before(score, best_score):
				best = {"coord": cell, "normal": normal}
				best_score = score
	return best

static func _ranks_before(a: Array, b: Array) -> bool:
	for i in a.size():
		if not is_equal_approx(float(a[i]), float(b[i])):
			return float(a[i]) < float(b[i])
	return false

## A room cell's main furniture goes on an outer flank wall if it has one,
## else any flank, else any wall -- never the doorway. A feature on the outer
## skin also gets a porthole above the furniture.
func _choose_feature(cell: Vector3i, index: Dictionary) -> void:
	var feature: Dictionary = {}
	var best_rank := 3
	for normal in _HORIZONTAL:
		var key := _key(cell, normal)
		if not index.has(key):
			continue
		var face: Dictionary = _faces[index[key]]
		if face["kind"] != Kind.WALL:
			continue
		var rank := 2
		if normal.x != 0:
			rank = 1 if face["partition"] else 0
		if rank < best_rank:
			best_rank = rank
			feature = face
	if feature.is_empty():
		return
	feature["variant"] = WallVariant.FEATURE
	feature["porthole"] = feature["skin_flank"]
```

- [ ] **Step 4: Run the tests, then the full suite**

`-gselect=test_interior_layout`: all pass, including every Phase A test. Full suite: no failures. The builder and dressing ignore the new kinds and variants until Task 13, and no grid has room blocks yet.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/interior/interior_layout.gd who-knows/test/unit/test_interior_layout.gd
git commit -m "feat: plan rooms: partitions, one doorway per room, feature walls

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: SlidingDoor

**Files:**
- Create: `who-knows/src/ship/interior/sliding_door.gd`
- Test: `who-knows/test/unit/test_sliding_door.gd`

**Interfaces:**
- Consumes: `InteriorKit` (with no body), `InteriorPalette`.
- Produces: `SlidingDoor` (`extends Node3D`) with `setup(opening_width: float, opening_height: float)`, `set_open(open: bool, animate := true)`, `is_open: bool`, `leaf_positions() -> Array[Vector3]`, `OPEN_TIME`, `AVATAR_MASK`. The origin is the doorway's centre at floor level on the wall's mid-plane; local x runs along the wall.

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_sliding_door.gd`:

```gdscript
extends GutTest

var _door: SlidingDoor

func before_each():
	_door = SlidingDoor.new()
	_door.setup(1.0, 1.9)
	add_child_autofree(_door)

func _body() -> Node3D:
	return autofree(Node3D.new())

func test_setup_builds_two_leaves_and_a_trigger():
	var trigger := _door.get_node_or_null("Trigger") as Area3D
	assert_not_null(trigger)
	assert_eq(trigger.collision_layer, 0, "the trigger is detected by nothing")
	assert_eq(trigger.collision_mask, SlidingDoor.AVATAR_MASK, "and detects the avatar")
	assert_eq(_door.leaf_positions().size(), 2)

func test_closed_leaves_meet_in_the_middle():
	assert_false(_door.is_open)
	var p := _door.leaf_positions()
	assert_almost_eq(p[0].x, -0.25, 0.001)
	assert_almost_eq(p[1].x, 0.25, 0.001)

func test_open_leaves_are_inside_the_jambs():
	_door.set_open(true, false)
	var p := _door.leaf_positions()
	assert_almost_eq(p[0].x, -0.75, 0.001, "a 0.5 m leaf centred 0.75 m out spans 0.5 to 1.0")
	assert_almost_eq(p[1].x, 0.75, 0.001)

func test_opens_when_someone_walks_up():
	_door._on_body_entered(_body())
	assert_true(_door.is_open)

func test_stays_open_until_the_last_one_leaves():
	var a := _body()
	var b := _body()
	_door._on_body_entered(a)
	_door._on_body_entered(b)
	_door._on_body_exited(a)
	assert_true(_door.is_open, "someone is still in the doorway")
	_door._on_body_exited(b)
	assert_false(_door.is_open)

func test_the_door_itself_is_never_solid():
	var shapes := _door.find_children("*", "CollisionShape3D", true, false)
	assert_eq(shapes.size(), 1, "only the trigger's shape")
	assert_true(shapes[0].get_parent() is Area3D)
```

- [ ] **Step 2: Run to verify failure**

`-gselect=test_sliding_door`: fails, `SlidingDoor` not declared.

- [ ] **Step 3: Write the implementation**

Create `who-knows/src/ship/interior/sliding_door.gd`:

```gdscript
class_name SlidingDoor
extends Node3D

## A door that slides open for whoever walks up to it and closes behind them
## (docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md §7.3).
## Two leaves part along local x into the wall on either side; an Area3D
## straddling the doorway decides when. The leaves are only a picture -- the
## doorway itself never has a collider -- so the door can never trap anyone,
## whatever its timing.
##
## Knows nothing about ships. The origin is the doorway's centre at floor
## level on the wall's mid-plane; +z faces either room.

const OPEN_TIME := 0.25
const LEAF_THICKNESS := 0.06
## How deep the trigger reaches into the rooms on both sides.
const TRIGGER_DEPTH := 2.4
## The avatar's physics layer (project.godot 3d_physics/layer_3) as a mask.
const AVATAR_MASK := 4

var is_open := false

var _width := 1.0
var _leaves: Array[Node3D] = []
var _inside := 0
var _tween: Tween

## Builds the leaves and the trigger for an opening `opening_width` wide and
## `opening_height` high. Call once, before the door enters the tree.
func setup(opening_width: float, opening_height: float) -> void:
	_width = opening_width
	for side in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.name = "LeafPort" if side < 0.0 else "LeafStarboard"
		add_child(leaf)
		var kit := InteriorKit.new(leaf)
		var w := _width * 0.5
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, opening_height * 0.5, 0)),
			Vector3(w, opening_height - 0.02, LEAF_THICKNESS), 0.025, InteriorKit.solid(InteriorPalette.WALL_LOW))
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, 1.0, 0)),
			Vector3(w - 0.04, 0.08, LEAF_THICKNESS + 0.02), 0.01, InteriorKit.solid(InteriorPalette.BELT))
		kit.commit()
		_leaves.append(leaf)

	var shape := BoxShape3D.new()
	shape.size = Vector3(_width, opening_height, TRIGGER_DEPTH)
	var trigger_shape := CollisionShape3D.new()
	trigger_shape.shape = shape
	trigger_shape.position = Vector3(0, opening_height * 0.5, 0)
	var trigger := Area3D.new()
	trigger.name = "Trigger"
	trigger.collision_layer = 0
	trigger.collision_mask = AVATAR_MASK
	trigger.add_child(trigger_shape)
	add_child(trigger)
	trigger.body_entered.connect(_on_body_entered)
	trigger.body_exited.connect(_on_body_exited)
	set_open(false, false)

## Opens or closes the door; animated when in the tree, instant otherwise.
func set_open(open: bool, animate := true) -> void:
	is_open = open
	if _tween != null:
		_tween.kill()
		_tween = null
	var slide := 0.75 if open else 0.25
	for i in _leaves.size():
		var side := -1.0 if i == 0 else 1.0
		var target := Vector3(side * _width * slide, 0, 0)
		if animate and is_inside_tree():
			if _tween == null:
				_tween = create_tween().set_parallel(true)
			_tween.tween_property(_leaves[i], "position", target, OPEN_TIME)
		else:
			_leaves[i].position = target

## Where the leaves are right now, port then starboard.
func leaf_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for leaf in _leaves:
		out.append(leaf.position)
	return out

func _on_body_entered(_body: Node3D) -> void:
	_inside += 1
	if not is_open:
		set_open(true)

func _on_body_exited(_body: Node3D) -> void:
	_inside = maxi(_inside - 1, 0)
	if _inside == 0 and is_open:
		set_open(false)
```

- [ ] **Step 4: Import, run the tests, full suite.** `-gselect=test_sliding_door`: all passing. Full suite: no failures.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/interior/sliding_door.gd* who-knows/test/unit/test_sliding_door.gd*
git commit -m "feat: add SlidingDoor, a self-contained door that opens for the avatar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Room furniture

**Files:**
- Modify: `who-knows/src/ship/interior/interior_palette.gd`
- Modify: `who-knows/src/ship/interior/interior_props.gd`
- Test: `who-knows/test/unit/test_interior_props.gd`

**Interfaces:**
- Produces:
  - `InteriorPalette.ROOM_FLOOR: Dictionary` (room id → Color), plus `MATTRESS`, `GUNMETAL`, `OLIVE`, `MIRROR`
  - `InteriorProps.DOOR_WIDTH` (1.0)
  - Props, each `(kit, f, variety)` unless noted, with the collider counts the tests pin:
    - `bunks(kit, f, variety, low_only: bool)`: 1 collider
    - `tall_lockers`: 0
    - `galley_counter(kit, f, variety, porthole: bool)`: 1
    - `fridge`: 1
    - `washstand`: 1
    - `towel_rail`: 0
    - `shelves`: 1
    - `weapon_rack`: 1
    - `ammo_crates`: 1
    - `door_frame(kit, f)`: 0 colliders, light role `&"door"`

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_interior_props.gd`:

```gdscript
func _built_with_colliders(expected: int) -> void:
	_assert_built()
	assert_eq(_colliders().size(), expected)

func test_bunks_are_solid():
	InteriorProps.bunks(_kit, Transform3D.IDENTITY, 0.3, false)
	_built_with_colliders(1)
	assert_almost_eq((_colliders()[0].shape as BoxShape3D).size.y, 1.5, 0.001, "two tiers")

func test_a_low_bunk_leaves_room_for_a_porthole():
	InteriorProps.bunks(_kit, Transform3D.IDENTITY, 0.3, true)
	_built_with_colliders(1)
	var top := (_colliders()[0].shape as BoxShape3D).size.y
	assert_lt(top, InteriorProps.PORTHOLE_HEIGHT - InteriorProps.PORTHOLE_FRAME_RADIUS)

func test_tall_lockers_are_flat():
	InteriorProps.tall_lockers(_kit, Transform3D.IDENTITY, 0.3)
	_built_with_colliders(0)

func test_galley_counter_and_fridge_are_solid():
	InteriorProps.galley_counter(_kit, Transform3D.IDENTITY, 0.3, false)
	InteriorProps.fridge(_kit, InteriorKit.at(Vector3(3, 0, 0)), 0.3)
	_built_with_colliders(2)

func test_washstand_is_solid_and_the_towel_rail_is_not():
	InteriorProps.washstand(_kit, Transform3D.IDENTITY, 0.3)
	InteriorProps.towel_rail(_kit, InteriorKit.at(Vector3(3, 0, 0)), 0.3)
	_built_with_colliders(1)

func test_shelves_are_solid():
	InteriorProps.shelves(_kit, Transform3D.IDENTITY, 0.6)
	_built_with_colliders(1)

func test_weapon_rack_and_ammo_are_solid():
	InteriorProps.weapon_rack(_kit, Transform3D.IDENTITY, 0.3)
	InteriorProps.ammo_crates(_kit, InteriorKit.at(Vector3(3, 0, 0)), 0.3)
	_built_with_colliders(2)

func test_door_frame_is_lit_and_leaves_the_opening_clear():
	InteriorProps.door_frame(_kit, Transform3D.IDENTITY)
	_built_with_colliders(0)
	assert_eq(_lights(&"door").size(), 1)

func test_every_room_has_a_floor_colour():
	for id in InteriorLayout.ROOM_IDS:
		assert_true(InteriorPalette.ROOM_FLOOR.has(id), "%s has a floor colour" % id)
```

- [ ] **Step 2: Run to verify failure.** `-gselect=test_interior_props`: the new tests fail.

- [ ] **Step 3: Add the room colours**

Append to `who-knows/src/ship/interior/interior_palette.gd`:

```gdscript
## Rooms (spec §7.4): each room's floor says what it is for at a glance.
const ROOM_FLOOR := {
	&"bunk_room": Color("5e7a7a"),
	&"galley": Color("b7a58a"),
	&"bathroom": Color("8fa9b8"),
	&"closet": Color("6b6a66"),
	&"weapon_room": Color("4e4a52"),
}
const MATTRESS := Color("6f9c9a")
const GUNMETAL := Color("3a3d44")
const OLIVE := Color("8a9a5b")
const MIRROR := Color("5a7e96")
```

- [ ] **Step 4: Add the room props**

In `who-knows/src/ship/interior/interior_props.gd`, add after `PORTHOLE_OPENING`:

```gdscript
## A doorway's clear width. Each sliding leaf is half of it, and slides into
## a jamb of (BAY - DOOR_WIDTH) / 2 = 0.5 m, so an open door hides entirely.
const DOOR_WIDTH := 1.0
```

and add these functions before `_at`:

```gdscript
## A bunk bed along the wall, two tiers with a reading strip under the top one;
## or, where the wall has a porthole above, one low bunk under it.
static func bunks(kit: InteriorKit, f: Transform3D, _variety: float, low_only: bool) -> void:
	_bed(kit, f, 0.0, 0.4)
	var top := 0.6
	if not low_only:
		for side in [-1.0, 1.0]:
			kit.bevel_box(SOLID, f * _at(Vector3(side * 0.93, 0.62, 0.86)), Vector3(0.08, 1.24, 0.08), 0.02,
				_c(InteriorPalette.WALL_LOW))
		_bed(kit, f, 1.1, 0.14)
		kit.box(GLOW, f * _at(Vector3(0, 1.095, 0.45)), Vector3(1.6, 0.01, 0.05), _lit(InteriorPalette.LIGHT_WARM, 1.2))
		top = 1.5
	kit.collider(f * _at(Vector3(0, top * 0.5, 0.45)), Vector3(1.9, top, 0.9))

## One bed: a frame from `base` up `frame_h`, a mattress on it and a pillow.
static func _bed(kit: InteriorKit, f: Transform3D, base: float, frame_h: float) -> void:
	var deck := base + frame_h
	kit.bevel_box(SOLID, f * _at(Vector3(0, base + frame_h * 0.5, 0.45)), Vector3(1.9, frame_h, 0.9), 0.04,
		_c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, f * _at(Vector3(0, deck + 0.07, 0.45)), Vector3(1.8, 0.14, 0.8), 0.05,
		_c(InteriorPalette.MATTRESS))
	kit.bevel_box(SOLID, f * _at(Vector3(0.62, deck + 0.19, 0.45)), Vector3(0.42, 0.1, 0.56), 0.04,
		_c(InteriorPalette.TRIM))

## Two tall locker doors with vents and indicators.
static func tall_lockers(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	for side in [-1.0, 1.0]:
		var x := side * 0.3
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.8, 0.05)), Vector3(0.55, 1.55, 0.1), 0.03, _c(InteriorPalette.TRIM))
		for k in 3:
			kit.box(SOLID, f * _at(Vector3(x, 1.3 + k * 0.05, 0.101)), Vector3(0.3, 0.015, 0.01),
				_c(InteriorPalette.WALL_LOW))
		var h := fposmod(variety * 7.0 + side, 1.0)
		kit.disc(GLOW, f * _at(Vector3(x + 0.18, 0.95, 0.101)), 0.025,
			_lit(InteriorPalette.AMBER if h > 0.7 else InteriorPalette.LIGHT_WARM, 1.6))

## A galley counter with a sink, a tap and two glowing cooktop rings, and
## cupboards above -- unless a porthole needs the wall.
static func galley_counter(kit: InteriorKit, f: Transform3D, _variety: float, porthole: bool) -> void:
	var trim := _c(InteriorPalette.TRIM)
	var low := _c(InteriorPalette.WALL_LOW)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.43, 0.3)), Vector3(1.8, 0.86, 0.6), 0.04, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.885, 0.32)), Vector3(1.9, 0.05, 0.64), 0.02, low)
	for x in [-0.3, 0.3]:
		kit.box(SOLID, f * _at(Vector3(x, 0.45, 0.602)), Vector3(0.015, 0.7, 0.01), low)
	kit.box(SOLID, f * _at(Vector3(-0.45, 0.912, 0.3)), Vector3(0.5, 0.006, 0.36), _c(InteriorPalette.SCREEN_BACK))
	kit.tube_between(SOLID, f * Vector3(-0.45, 0.91, 0.08), f * Vector3(-0.45, 1.08, 0.08), 0.02, trim)
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	for x in [0.35, 0.72]:
		kit.annulus(GLOW, f * Transform3D(up, Vector3(x, 0.913, 0.3)), 0.08, 0.12, _lit(InteriorPalette.CORAL, 1.8))
	if not porthole:
		kit.bevel_box(SOLID, f * _at(Vector3(0, 1.42, 0.17)), Vector3(1.8, 0.4, 0.34), 0.04, trim)
		kit.box(SOLID, f * _at(Vector3(0, 1.42, 0.341)), Vector3(0.015, 0.36, 0.01), low)
	kit.collider(f * _at(Vector3(0, 0.45, 0.32)), Vector3(1.9, 0.9, 0.64))

## A tall fridge to one side, with a handle and a status light.
static func fridge(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var x := 0.45 if variety < 0.5 else -0.45
	kit.bevel_box(SOLID, f * _at(Vector3(x, 0.8, 0.3)), Vector3(0.8, 1.6, 0.6), 0.05, _c(InteriorPalette.TRIM))
	kit.box(SOLID, f * _at(Vector3(x, 1.1, 0.601)), Vector3(0.76, 0.015, 0.01), _c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, f * _at(Vector3(x - 0.3, 1.3, 0.62)), Vector3(0.04, 0.35, 0.05), 0.015,
		_c(InteriorPalette.WALL_LOW))
	kit.disc(GLOW, f * _at(Vector3(x + 0.28, 1.45, 0.602)), 0.025, _lit(InteriorPalette.SKY, 1.6))
	kit.collider(f * _at(Vector3(x, 0.8, 0.3)), Vector3(0.8, 1.6, 0.6))

## A toilet and a sink under a mirror lit from above.
static func washstand(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var trim := _c(InteriorPalette.TRIM)
	kit.bevel_box(SOLID, f * _at(Vector3(-0.5, 0.2, 0.3)), Vector3(0.4, 0.4, 0.55), 0.06, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(-0.5, 0.43, 0.32)), Vector3(0.44, 0.06, 0.5), 0.025, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(-0.5, 0.62, 0.09)), Vector3(0.44, 0.38, 0.18), 0.04, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(0.45, 0.4, 0.2)), Vector3(0.14, 0.8, 0.14), 0.03, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(0.45, 0.85, 0.24)), Vector3(0.56, 0.14, 0.44), 0.05, trim)
	kit.tube_between(SOLID, f * Vector3(0.45, 0.92, 0.05), f * Vector3(0.45, 1.02, 0.05), 0.02,
		_c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, f * _at(Vector3(0.45, 1.3, 0.015)), Vector3(0.5, 0.55, 0.03), 0.015, trim)
	kit.box(SOLID, f * _at(Vector3(0.45, 1.3, 0.032)), Vector3(0.42, 0.47, 0.004), _c(InteriorPalette.MIRROR))
	kit.box(GLOW, f * _at(Vector3(0.45, 1.6, 0.03)), Vector3(0.44, 0.03, 0.03), _lit(InteriorPalette.LIGHT_WARM, 2.0))
	kit.collider(f * _at(Vector3(0, 0.45, 0.3)), Vector3(1.5, 0.9, 0.6))

## A towel on a rail.
static func towel_rail(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var trim := _c(InteriorPalette.TRIM)
	for x in [-0.45, 0.45]:
		kit.bevel_box(SOLID, f * _at(Vector3(x, 1.1, 0.035)), Vector3(0.05, 0.08, 0.07), 0.015, trim)
	kit.tube_x(SOLID, f * _at(Vector3(0, 1.1, 0.07)), 0.02, 0.95, trim)
	var towel := InteriorPalette.CORAL if variety < 0.5 else InteriorPalette.SKY
	kit.bevel_box(SOLID, f * _at(Vector3(-0.1, 0.88, 0.09)), Vector3(0.5, 0.46, 0.03), 0.012, _c(towel))

## Three shelves stacked with crates of seeded sizes and colours.
static func shelves(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	for x in [-0.82, 0.82]:
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.8, 0.2)), Vector3(0.05, 1.6, 0.4), 0.015, _c(InteriorPalette.WALL_LOW))
	var crates: Array[Color] = [InteriorPalette.AMBER, InteriorPalette.SKY, InteriorPalette.CORAL,
		InteriorPalette.OLIVE, InteriorPalette.TRIM]
	for level in 3:
		var y := 0.25 + level * 0.47
		kit.bevel_box(SOLID, f * _at(Vector3(0, y, 0.2)), Vector3(1.64, 0.04, 0.4), 0.015, _c(InteriorPalette.TRIM))
		var x := -0.72
		var k := 0
		while true:
			var h := fposmod(variety * 31.0 + level * 7.3 + k * 3.1, 1.0)
			var w := 0.25 + 0.2 * h
			if x + w > 0.78:
				break
			var tall := 0.18 + 0.18 * fposmod(h * 5.7, 1.0)
			kit.bevel_box(SOLID, f * _at(Vector3(x + w * 0.5, y + 0.02 + tall * 0.5, 0.2)),
				Vector3(w - 0.03, tall, 0.3), 0.03, _c(crates[int(h * 5.0) % 5]))
			x += w + 0.04
			k += 1
	kit.collider(f * _at(Vector3(0, 0.8, 0.2)), Vector3(1.7, 1.6, 0.4))

## Five chunky rifles on a rack over a gunmetal cabinet, with coral warning
## stripes.
static func weapon_rack(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var gun := _c(InteriorPalette.GUNMETAL)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.2, 0.175)), Vector3(1.6, 0.4, 0.35), 0.04, gun)
	kit.box(SOLID, f * _at(Vector3(0, 0.36, 0.352)), Vector3(1.6, 0.05, 0.01), _c(InteriorPalette.CORAL))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.0, 0.025)), Vector3(1.6, 1.1, 0.05), 0.02, _c(InteriorPalette.WALL_LOW))
	kit.box(SOLID, f * _at(Vector3(0, 1.52, 0.052)), Vector3(1.6, 0.05, 0.01), _c(InteriorPalette.CORAL))
	for i in 5:
		var x := -0.6 + i * 0.3
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.6, 0.1)), Vector3(0.1, 0.22, 0.07), 0.02, _c(InteriorPalette.WOOD))
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.98, 0.1)), Vector3(0.11, 0.55, 0.08), 0.02, gun)
		kit.bevel_box(SOLID, f * _at(Vector3(x + 0.07, 0.9, 0.1)), Vector3(0.05, 0.16, 0.06), 0.012, gun)
		kit.tube_between(SOLID, f * Vector3(x, 1.25, 0.1), f * Vector3(x, 1.45, 0.1), 0.018, gun)
		kit.disc(GLOW, f * _at(Vector3(x, 1.12, 0.141)), 0.012, _lit(InteriorPalette.SKY, 1.5))
	kit.disc(GLOW, f * _at(Vector3(0.7, 0.3, 0.352)), 0.025, _lit(InteriorPalette.AMBER, 1.6, 0.5))
	kit.collider(f * _at(Vector3(0, 0.8, 0.175)), Vector3(1.6, 1.6, 0.35))

## Three stacked ammo crates with stripes and latches.
static func ammo_crates(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var spots: Array[Vector3] = [Vector3(-0.45, 0.2, 0.25), Vector3(0.35, 0.2, 0.25), Vector3(-0.1, 0.6, 0.25)]
	for i in spots.size():
		var p := spots[i]
		kit.bevel_box(SOLID, f * _at(p), Vector3(0.7, 0.4, 0.5), 0.04, _c(InteriorPalette.OLIVE))
		kit.box(SOLID, f * _at(p + Vector3(0, 0.08, 0.251)), Vector3(0.66, 0.05, 0.01),
			_c(InteriorPalette.AMBER if i % 2 == 0 else InteriorPalette.CORAL))
		for side in [-0.25, 0.25]:
			kit.bevel_box(SOLID, f * _at(p + Vector3(side, -0.05, 0.255)), Vector3(0.08, 0.06, 0.02), 0.008,
				_c(InteriorPalette.TRIM))
	kit.collider(f * _at(Vector3(0, 0.4, 0.25)), Vector3(1.6, 0.8, 0.5))

## A doorway's frame, drawn once for both rooms: two chunky posts through the
## wall and a lit lintel. The frame's origin is on the owning side's inner
## surface, so the posts straddle the wall's mid-plane just behind it.
static func door_frame(kit: InteriorKit, f: Transform3D) -> void:
	var mid := -WALL_THICKNESS * 0.5
	for side in [-1.0, 1.0]:
		kit.bevel_box(SOLID, f * _at(Vector3(side * (DOOR_WIDTH * 0.5 + 0.07), HEADROOM * 0.5, mid)),
			Vector3(0.14, HEADROOM, 0.24), 0.04, _c(InteriorPalette.TRIM))
	kit.box(GLOW, f * _at(Vector3(0, HEADROOM - 0.012, mid)), Vector3(DOOR_WIDTH, 0.02, 0.12),
		_lit(InteriorPalette.LIGHT_WARM, 2.0))
	kit.light(f * Vector3(0, HEADROOM - 0.3, 0.3), InteriorPalette.LIGHT_WARM, 0.5, 2.5, &"door")
```

- [ ] **Step 5: Run the tests, then the full suite.** `-gselect=test_interior_props`: all pass.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/ship/interior/interior_palette.gd who-knows/src/ship/interior/interior_props.gd who-knows/test/unit/test_interior_props.gd
git commit -m "feat: add room furniture to the prop library

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Build partitions and doorways; furnish rooms

**Files:**
- Modify: `who-knows/src/ship/interior_builder.gd`
- Modify: `who-knows/src/ship/interior/interior_dressing.gd`
- Test: `who-knows/test/unit/test_interior_builder.gd`, `who-knows/test/unit/test_interior_dressing.gd`

**Interfaces:**
- Consumes: Task 10 records, Task 11 `SlidingDoor`, Task 12 props and `ROOM_FLOOR`.
- Produces: `InteriorBuilder.doorway_count() -> int`. Each doorway has one `SlidingDoor` in the `Dressing` node.

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_interior_builder.gd`:

```gdscript
func _register_rooms() -> void:
	for id in InteriorLayout.ROOM_IDS:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))

func test_a_partition_is_built_once():
	_register_rooms()
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(1, 0, 1), &"galley")
	_builder.rebuild()
	# The doorway takes the forward face (z = 0); the aft one is a plain partition.
	var between := Vector3(ShipGrid.CELL_SIZE * 0.5, 0, ShipGrid.CELL_SIZE)
	var here := _structure_colliders().filter(func(c): return c.position.is_equal_approx(between))
	assert_eq(here.size(), 1, "one wall between the corridor and the galley, not two")

func test_a_doorway_leaves_a_clear_opening_between_two_jambs():
	_register_rooms()
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_builder.rebuild()
	assert_eq(_builder.doorway_count(), 1)
	var plane_x := ShipGrid.CELL_SIZE * 0.5
	var at_plane := _structure_colliders().filter(func(c): return is_equal_approx(c.position.x, plane_x))
	assert_eq(at_plane.size(), 2, "two jambs")
	for c in at_plane:
		var half_width: float = (c.shape as BoxShape3D).size.z * 0.5
		assert_gte(absf(c.position.z) - half_width, InteriorProps.DOOR_WIDTH * 0.5 - 0.001,
			"nothing solid in the opening")

func test_room_floors_take_the_room_colour():
	_register_rooms()
	_put(Vector3i(0, 0, 0), &"bathroom")
	_builder.rebuild()
	var floor_y := -ShipGrid.CELL_SIZE * 0.5
	var floors := _structure_meshes().filter(func(m): return is_equal_approx(m.position.y, floor_y))
	assert_eq((floors[0].material_override as StandardMaterial3D).albedo_color,
		InteriorPalette.ROOM_FLOOR[&"bathroom"])
```

Append to `who-knows/test/unit/test_interior_dressing.gd`:

```gdscript
func _doors() -> Array:
	return _builder.find_children("*", "Node3D", true, false).filter(func(n): return n is SlidingDoor)

func _register_rooms() -> void:
	for id in InteriorLayout.ROOM_IDS:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))

func test_every_doorway_gets_one_sliding_door():
	_register_rooms()
	for z in [0, 1, 2]:
		_put(Vector3i(0, 0, z), &"deck")
	_put(Vector3i(-1, 0, 0), &"bunk_room")
	_put(Vector3i(-1, 0, 1), &"bunk_room")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(1, 0, 2), &"closet")
	_builder.rebuild()
	assert_eq(_doors().size(), _builder.layout().rooms().size())
	assert_eq(_doors().size(), 3)

func test_room_furniture_is_solid_where_it_should_be():
	_register_rooms()
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(2, 0, 0), &"hull")
	_builder.rebuild()
	assert_gt(_dressing_colliders().size(), 0, "a counter or a fridge you cannot walk through")

func test_rooms_survive_churn():
	_register_rooms()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ids := [&"hull", &"deck", &"seat", &"canopy", &"airlock"] + Array(InteriorLayout.ROOM_IDS)
	for step in 300:
		var coord := Vector3i(rng.randi_range(-3, 3), 0, rng.randi_range(-5, 5))
		if rng.randf() < 0.75:
			_put(coord, ids[rng.randi_range(0, ids.size() - 1)])
		else:
			_grid.clear_block(coord)
	_builder.rebuild()
	assert_eq(_doors().size(), _builder.doorway_count(), "a door for every doorway, however tangled")
```

- [ ] **Step 2: Run to verify failure.** Both files: the new tests fail (`doorway_count` missing, no doors).

- [ ] **Step 3: Build partitions and doorways**

In `who-knows/src/ship/interior_builder.gd`:

1. Add `var _doorway_count := 0` after `_canopy_faces`, add `_doorway_count = 0` in `_clear()`, and add after `canopy_face_count()`:

```gdscript
func doorway_count() -> int:
	return _doorway_count
```

2. In `_build_structure()`, replace the WALL branch and add a DOORWAY branch:

```gdscript
			InteriorLayout.Kind.WALL:
				if not face["owner"]:
					continue   # the cell on the other side builds this partition
				if face["porthole"]:
					_walls.append(_add_collider(_physics_body, _wall_size(normal), at))
					_add_porthole_wall(at, normal)
				else:
					_walls.append(_add_box(_physics_body, _wall_size(normal), at,
						InteriorMaterials.flat(InteriorPalette.WALL)))
			InteriorLayout.Kind.DOORWAY:
				if face["owner"]:
					_add_doorway(at, normal)
```

3. Replace `_floor_colour` with:

```gdscript
static func _floor_colour(zone: StringName) -> Color:
	if InteriorPalette.ROOM_FLOOR.has(zone):
		return InteriorPalette.ROOM_FLOOR[zone]
	return InteriorPalette.FLOOR_BRIDGE if zone == InteriorLayout.ZONE_BRIDGE else InteriorPalette.FLOOR
```

4. Add after `_add_porthole_wall`:

```gdscript
## A doorway: two jambs, each a collider and a box, either side of an opening
## InteriorProps.DOOR_WIDTH wide and the full cell high. The opening itself
## never has a collider -- the SlidingDoor's leaves are only a picture.
func _add_doorway(at: Vector3, normal: Vector3i) -> void:
	var along := Vector3(absi(normal.z), 0, absi(normal.x))
	var thick := Vector3(absi(normal.x), 0, absi(normal.z)) * FLOOR_THICKNESS
	var jamb := (ShipGrid.CELL_SIZE - InteriorProps.DOOR_WIDTH) * 0.5
	var size := thick + along * jamb + Vector3.UP * ShipGrid.CELL_SIZE
	var material := InteriorMaterials.flat(InteriorPalette.WALL)
	for side in [-1.0, 1.0]:
		_walls.append(_add_box(_physics_body, size,
			at + along * side * (InteriorProps.DOOR_WIDTH + jamb) * 0.5, material))
	_doorway_count += 1
```

- [ ] **Step 4: Furnish rooms and hang doors**

In `who-knows/src/ship/interior/interior_dressing.gd`, replace `_dress` and `_wall_piece` with:

```gdscript
static func _dress(kit: InteriorKit, face: Dictionary) -> void:
	var coord: Vector3i = face["coord"]
	match face["kind"]:
		InteriorLayout.Kind.CEILING:
			var centre := ShipGrid.cell_center(coord)
			centre.y = floor_y(coord) + InteriorProps.HEADROOM
			InteriorProps.ceiling_light(kit, centre)
		InteriorLayout.Kind.WALL:
			var f := wall_frame(coord, face["normal"])
			InteriorProps.wall_trim(kit, f)
			_wall_piece(kit, f, face)
		InteriorLayout.Kind.DOORWAY:
			if face["owner"]:
				_doorway(kit, wall_frame(coord, face["normal"]))

static func _wall_piece(kit: InteriorKit, f: Transform3D, face: Dictionary) -> void:
	var variety := face_variety(face)
	match face["variant"]:
		InteriorLayout.WallVariant.HATCH:
			InteriorProps.hatch(kit, f)
		InteriorLayout.WallVariant.CONSOLE:
			InteriorProps.console(kit, f, variety)
		InteriorLayout.WallVariant.PORTHOLE:
			InteriorProps.porthole(kit, f)
		InteriorLayout.WallVariant.LOCKERS:
			InteriorProps.lockers(kit, f, variety)
		InteriorLayout.WallVariant.DISPLAY:
			InteriorProps.display(kit, f, variety)
		InteriorLayout.WallVariant.FEATURE, InteriorLayout.WallVariant.SECONDARY:
			_room_piece(kit, f, face, variety)
		# PANEL: the trim is the whole wall.

## A room wall's furniture, by room: the feature wall gets the room's main
## piece, the others its secondary one (spec §7.4).
static func _room_piece(kit: InteriorKit, f: Transform3D, face: Dictionary, variety: float) -> void:
	var feature: bool = face["variant"] == InteriorLayout.WallVariant.FEATURE
	var porthole: bool = face["porthole"]
	match face["zone"]:
		&"bunk_room":
			if feature:
				InteriorProps.bunks(kit, f, variety, porthole)
			else:
				InteriorProps.tall_lockers(kit, f, variety)
		&"galley":
			if feature:
				InteriorProps.galley_counter(kit, f, variety, porthole)
			else:
				InteriorProps.fridge(kit, f, variety)
		&"bathroom":
			if feature:
				InteriorProps.washstand(kit, f, variety)
			else:
				InteriorProps.towel_rail(kit, f, variety)
		&"closet":
			InteriorProps.shelves(kit, f, variety)
		&"weapon_room":
			if feature:
				InteriorProps.weapon_rack(kit, f, variety)
			else:
				InteriorProps.ammo_crates(kit, f, variety)
	if porthole:
		InteriorProps.porthole(kit, f)

## A doorway's frame and its sliding door, on the wall's mid-plane.
static func _doorway(kit: InteriorKit, f: Transform3D) -> void:
	InteriorProps.door_frame(kit, f)
	var door := SlidingDoor.new()
	door.name = "SlidingDoor"
	door.setup(InteriorProps.DOOR_WIDTH, InteriorProps.HEADROOM)
	door.transform = f * InteriorKit.at(Vector3(0, 0, -InteriorProps.WALL_THICKNESS * 0.5))
	kit.root.add_child(door)
```

- [ ] **Step 5: Import, run the tests, full suite.** All pass.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/ship/interior_builder.gd who-knows/src/ship/interior/interior_dressing.gd who-knows/test/unit/test_interior_builder.gd who-knows/test/unit/test_interior_dressing.gd
git commit -m "feat: wall off rooms, hang sliding doors and furnish each room

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: The starter shuttle's rooms

**Files:**
- Modify: `who-knows/scenes/flight_test.gd` (`_starter_grid()`)
- Create: `who-knows/test/unit/test_starter_shuttle.gd`
- Modify: `who-knows/test/unit/test_interior_layout.gd` (the starter test), `who-knows/test/unit/test_hud_scene_wiring.gd`

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_starter_shuttle.gd`:

```gdscript
extends GutTest

## The starter shuttle after the interior redesign (spec §7.5): a bridge,
## a corridor and five rooms -- with exactly the flight balance it had before.

var _cat: BlockCatalog
var _grid: ShipGrid

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func before_each():
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	_grid = bootstrap._starter_grid()
	bootstrap.free()

func test_the_cabin_has_all_five_rooms():
	var found := {}
	for coord in _grid.coords():
		found[_grid.get_block(coord).block_id] = true
	for id in InteriorLayout.ROOM_IDS:
		assert_true(found.has(id), "the starter shuttle has a %s" % id)

func test_rooms_do_not_move_the_flight_balance():
	var decked := ShipGrid.new()
	for coord in _grid.coords():
		var inst: BlockInstance = _grid.get_block(coord).duplicate_instance()
		if InteriorLayout.ROOM_IDS.has(inst.block_id):
			inst.block_id = &"deck"
		decked.set_block(coord, inst)
	var rooms := ShipStats.compute(_grid, _cat)
	var plain := ShipStats.compute(decked, _cat)
	assert_almost_eq(rooms.total_mass_kg, plain.total_mass_kg, 0.001)
	assert_almost_eq(rooms.center_of_mass, plain.center_of_mass, Vector3.ONE * 0.0001)
	assert_almost_eq(rooms.torque_imbalance, plain.torque_imbalance, Vector3.ONE * 0.01)
	assert_almost_eq(rooms.power_draw, plain.power_draw, 0.0001)

func test_the_starter_shuttle_still_launches():
	var issues := ShipValidator.validate(_grid, _cat)
	assert_eq(issues.size(), 0, "zero validation issues")
	assert_true(ShipValidator.can_launch(issues))
```

In `who-knows/test/unit/test_interior_layout.gd`, replace `test_starter_shuttle_layout` with:

```gdscript
## The real starter shuttle, as flight_test.gd builds it (spec §7.5).
func test_starter_shuttle_layout():
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var grid: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	var catalog := BlockCatalog.load_from_dir("res://data/blocks")
	var layout := InteriorLayout.plan(grid, catalog, DeckGraph.build(grid, catalog).walkable_coords())
	assert_eq(_count(layout, InteriorLayout.WallVariant.CONSOLE), 4, "both walls of the two helm rows")
	assert_eq(_count(layout, InteriorLayout.WallVariant.HATCH), 1)
	assert_eq(layout.rooms().size(), 5)
	var doorways := layout.faces().filter(func(f): return f["kind"] == InteriorLayout.Kind.DOORWAY)
	assert_eq(doorways.size(), 10, "five doorways, two sides each")
	var portholes := layout.faces().filter(func(f): return f["porthole"])
	assert_eq(portholes.size(), 4, "two on the bridge, one in the bunk room, one in the galley")
	assert_eq(layout.canopy_groups().size(), 1)
	assert_eq(layout.canopy_groups()[0]["coords"].size(), 3)
```

Append to `who-knows/test/unit/test_hud_scene_wiring.gd`:

```gdscript
func test_the_cabin_has_a_sliding_door_for_every_room():
	var doors := _root.find_children("*", "Node3D", true, false).filter(func(n): return n is SlidingDoor)
	assert_eq(doors.size(), 5)
```

- [ ] **Step 2: Run to verify failure.** The new starter tests fail: no rooms yet.

- [ ] **Step 3: Lay out the rooms**

In `who-knows/scenes/flight_test.gd` `_starter_grid()`, replace

```gdscript
	for z in [-1, 0, 1, 2]:
		for x in [-1, 0, 1]:
			_put(g, Vector3i(x, 0, z), &"deck")
```
with
```gdscript
	for x in [-1, 0, 1]:
		_put(g, Vector3i(x, 0, -1), &"deck")
	# Behind the bridge, a corridor down the centreline with rooms either side
	# (interior redesign spec §7.5). Room blocks weigh and draw what deck
	# does, so the flight balance measured below is unchanged.
	for z in [0, 1, 2]:
		_put(g, Vector3i(0, 0, z), &"deck")
	_put(g, Vector3i(-1, 0, 0), &"bunk_room")
	_put(g, Vector3i(-1, 0, 1), &"bunk_room")
	_put(g, Vector3i(-1, 0, 2), &"bathroom")
	_put(g, Vector3i(1, 0, 0), &"galley")
	_put(g, Vector3i(1, 0, 1), &"weapon_room")
	_put(g, Vector3i(1, 0, 2), &"closet")
```

- [ ] **Step 4: Run the tests, the full suite, and the render smoke** (Task 6 Step 9 command, without `--headless`). All pass and the output is clean.

- [ ] **Step 5: Commit**

```bash
git add who-knows/scenes/flight_test.gd who-knows/test/unit/test_starter_shuttle.gd who-knows/test/unit/test_starter_shuttle.gd.uid who-knows/test/unit/test_interior_layout.gd who-knows/test/unit/test_hud_scene_wiring.gd
git commit -m "feat: divide the starter shuttle into a bridge, corridor and five rooms

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Documentation

**Files:**
- Modify: `docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md`
- Modify: `docs/superpowers/SLICE-1-STATUS.md`

- [ ] **Step 1:** In the art direction doc:
  - Under the §3.1 heading, add: *"Superseded for the cabin by docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md §7.5: rows z = 0..2 are now a corridor with five rooms."*
  - Replace the §5.2 table with a pointer to the redesign spec §3.1 and §7.4.
  - Replace §5.3's body with: *"Revised 2026-09-23: the player's ship is stylized, warm and dim (redesign spec §1). Derelict and enemy interiors must differ from it by colour and wear, such as cold or failing light and damage, not only by brightness."*
  - Append to §7 item 4: *"Since the interior redesign, canopy faces keep only their colliders; the visible canopy is the generated rounded nose (redesign spec §6)."*
- [ ] **Step 2:** In SLICE-1-STATUS, under playtest item 6, add: *"**Addressed 2026-09-23** by the interior redesign (docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md): props draw inside, a stylized dressing kit, a rounded nose with projected windows, rooms and sliding doors."* Also update the "What works" list with a bullet for the new interior.
- [ ] **Step 3:** Commit both files: `docs: point the art direction and status at the interior redesign`.

---

### Task 16: Final checkpoint (controller, with the owner)

- [ ] **Step 1:** Render the real scene from the Phase A viewpoints plus one inside each room, looking at its feature wall.
- [ ] **Step 2:** Walk every doorway in a probe. The avatar must pass through each opening, and each door must open and close.
- [ ] **Step 3:** Measure the frame time again (target: 60 fps on the GTX 960).
- [ ] **Step 4:** Send the screenshots to the owner and fix anything they flag. Then use superpowers:finishing-a-development-branch.
