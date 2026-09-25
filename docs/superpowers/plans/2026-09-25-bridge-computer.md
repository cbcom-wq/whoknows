# Bridge Computer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Gate:** quantum energy must be built and merged first (its plan,
> `docs/superpowers/plans/2026-09-24-quantum-energy.md`, through its Task 12). This plan builds on
> names that plan creates. They are listed under "Before Task 1". Check them against the built code
> before starting, and wherever a built name differs, use the built one throughout.

**Goal:** Put a holo table on the bridge that maps what the ship's sensors know, sets a course the
HUD follows, and shows the ship in miniature with its store, power and suit.

**Architecture:**
- `ShipSensors`, built by quantum energy, gains a second source, `RockContacts`, for big rocks out
  to 30 km. It also gains the course: one per ship, cleared on arrival.
- The dressing builds a `ShipComputer` for each `computer` fixture. It is the table's screen, five
  `ReadoutPanel` buttons, a `HoloVolume` and a list of `ComputerPage`s: `MapPage` and
  `StatusPage`.
- The ship binds each table after every rebuild to a `ComputerContext` (its sensors, store, stats,
  hull and exterior builder) and keeps each table's page state across the rebuild.
- `HoloVolume` is grid-blind glowing kit geometry, one MultiMesh per kind of mark. The miniature
  shares the hull's own MultiMeshes.
- `CourseMarker` is a `WorldMarker`, mounted per view like the salvage marker.

**Tech Stack:** Godot 4.5.1 (.NET build, GDScript only), GUT 9, `run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-09-25-bridge-computer-design.md`. Read it first. Section
numbers below (§) are that spec's unless they say otherwise.

## Global Constraints

- **The numbers, from the spec:**
  - the `computer` block: Interior (category 2), MOUNT, `mass_t` 0.3, `hp` 60, `power_draw` 0.3;
  - on the starter at (−1, 0, −1), orientation 12 (facing +x);
  - the table top is 1.1 m across (radius 0.55) at 0.9 m;
  - the holo volume is a cylinder of radius 0.5 m, from 1.05 to 1.65 m (centre 1.35, half-height
    0.3);
  - the console is tilted 55°, with five buttons: PAGE, RANGE, ◀, big, ▶;
  - ranges 2, 10 and 30 km, opening at 10 km;
  - stalks for the nearest 12 contacts and the selected one;
  - a course arrives inside a salvage region, or within 1 km of a big rock's surface;
  - sensors refresh at 4 Hz; rock contacts reach 30 km (6 giant cells either side);
  - the miniature's longest side is 0.8 m, turning at 10°/s;
  - mark sizes as in §5.2 (constants in `MapPage`, Task 5).
- **Visual style** (`docs/design/visual-style.md`, binding):
  - colours only from `InteriorPalette` (inside) and `HudPalette` (the HUD);
  - the prop and `HoloVolume` never see the grid;
  - no new shader: the holo is the glow batch, and the miniature is an unshaded
    `StandardMaterial3D`;
  - interior render layer 2;
  - `test_visual_style_rules.gd` must stay green; if it fails, fix the code, not the test.
- **Floating origin** (CLAUDE.md): nothing in this plan lives outside the ship. Contacts are
  `UniversePoint`s, turned into the hull's frame each frame. Prove that a shift leaves the holo
  unchanged (Task 5).
- **`.tscn`/`.tres`:** no `#` comments anywhere. This plan adds one `.tres`
  (`data/blocks/computer.tres`) and no scene edits: the markers are created in code. Prove the
  `.tres` by reading its properties back in a test.
- **Tests:** GUT, headless, output pristine. From the worktree root in PowerShell:
  - everything: `& .\who-knows\run_tests.ps1`;
  - one script: `& .\who-knows\run_tests.ps1 '-gselect=test_holo_volume'` (quote the argument).
- **After adding a `class_name`,** run the import pass before tests, and commit Godot's `.uid`
  files:
  `& "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path .\who-knows --import`
  (or `$env:GODOT_BIN` if set).
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Work in a sibling worktree,** `D:\git\whoknows-computer` on branch `bridge-computer`, because
  other sessions share `D:\git\whoknows`:
  1. `git -C D:\git\whoknows switch main`
  2. `git -C D:\git\whoknows worktree add -b bridge-computer D:\git\whoknows-computer main`
  3. Run the import pass there once, then the whole suite, and record the baseline count.
- **Code style:** match the surrounding GDScript. British spelling in comments ("colour",
  "centre"). Doc comments (`##`) say what and why, plainly, citing spec sections.
- **Task 1 touches the starter shuttle.** Use the project's `building-a-ship` skill and its probe
  for the checks it describes.

## Before Task 1: what quantum energy built

This plan calls these names. Open each file and confirm them. If one differs, note the built name
in your task report and use it wherever this plan uses the planned one.

| Planned name | Where | Used by |
|---|---|---|
| `ReadoutPanel.setup(role: StringName, layer_bits: int, render_layer := InteriorKit.LAYER, size := SIZE, has_screen := true)`; `prompt_source: Callable`; signal `pressed(role: StringName)`; `interact(actor)`; `set_readout(lines: PackedStringArray, state: StringName)`, where `&"go"`, `&"cycling"` and `&"vacuum"` light the button and any other state (`&""`) lights none; `button_state() -> StringName` | `src/ship/interior/readout_panel.gd` | Task 4 |
| `InteriorLayout.QUIET_FIXTURES: Array[StringName]`, and the rule that a quiet fixture's own walls go `PANEL`, or `PORTHOLE` on a skin flank | `src/ship/interior/interior_layout.gd` | Task 1 |
| `InteriorDressing.draws_fixture(id)` accepting the helm and the two quantum fixtures | `src/ship/interior/interior_dressing.gd` | Task 1 |
| `InteriorPalette.QUANTUM` | `src/ship/interior/interior_palette.gd` | Task 3 |
| `Ship.quantum: QuantumPlant` with `store: QuantumStore`; `QuantumStore.amount`, `capacity`, `set_capacity(c)`, `is_low_power()`; `QuantumValues.LOW_POWER_AUTHORITY` | `src/ship/ship.gd`, `src/quantum/` | Task 4 |
| `Avatar.suit_cell: SuitCell`; `SuitCell.charge`, `SuitCell.CAPACITY` | `src/avatar/avatar.gd`, `src/quantum/suit_cell.gd` | Task 4 |
| `Contact`: `id`, `kind`, `label`, `point: UniversePoint`, `precision`, `radius`, `km` | `src/sensors/contact.gd` | Tasks 2, 5, 6 |
| `ShipSensors` at `Ship.sensors`: `universe: Universe`; `time: float` (what it passes its sources); `add_source(source)`; `contacts(range_m) -> Array[Contact]`, nearest first; `refresh(time: float)`, which re-reads the sources (its `_process` calls it at 4 Hz); `focus_point() -> UniversePoint`; its sources kept in `_sources` | `src/sensors/ship_sensors.gd` | Tasks 2, 5, 6 |
| `SalvageField.contacts(focus, range_m, time)` and `contact(id, focus, time)` | `src/world/salvage_field.gd` | Task 6 |
| `SalvageSense.PING_PERIOD` (4.0) | `src/world/salvage_sense.gd` | Task 5 |
| `WorldMarker`: `@export var camera_path: NodePath`; `view_camera(telemetry) -> Camera3D` | `src/ui/world_marker.gd` | Task 6 |
| `SalvageMarker.bind(sensors)`, mounted three times in `flight_test.gd` | `src/ui/salvage_marker.gd`, `scenes/flight_test.gd` | Task 6 |
| The starter's pinned figures in `test_starter_shuttle.gd` (quantum Task 1) | `test/unit/test_starter_shuttle.gd` | Task 1 |
| The starter's recorded zones and wall variants (quantum Task 2) | `test/unit/test_interior_layout.gd` | Task 1 |

---

## File Structure

| File | Responsibility |
|---|---|
| Create `who-knows/data/blocks/computer.tres` | The `computer` block. |
| Modify `who-knows/src/ship/interior/interior_layout.gd` | `COMPUTER_ID`; the computer joins `QUIET_FIXTURES`. |
| Modify `who-knows/src/ship/interior/interior_props.gd` | `holo_table` and its frames: console, screen, buttons, volume. |
| Modify `who-knows/src/ship/interior/interior_dressing.gd` | Draws the table; builds a `ShipComputer` at it. |
| Modify `who-knows/scenes/flight_test.gd` | The starter's computer; `RockContacts` registered; `CourseMarker` mounted; the arrival chime. |
| Create `who-knows/src/sensors/rock_contacts.gd` | `RockContacts`: big rocks within 30 km, from the recipe. Pure. |
| Create `who-knows/src/sensors/contact_text.gd` | `ContactText`: "3.2 KM", "~4 KM", "640 M", "HERE". Pure. |
| Modify `who-knows/src/sensors/ship_sensors.gd` | The course, arrival, `last_arrived`. |
| Modify `who-knows/src/ship/interior/interior_kit.gd` | `mesh(batch)`: one batch as a mesh, no node. |
| Modify `who-knows/src/ship/interior/interior_materials.gd` | `holo()`: the miniature's material. |
| Create `who-knows/src/ship/computer/holo_volume.gd` | `HoloVolume`: marks, stalks, pins, bracket, chevron, miniature; `place()`. Grid-blind. |
| Create `who-knows/src/ship/computer/computer_page.gd` | `ComputerPage`: what a page supplies. |
| Create `who-knows/src/ship/computer/computer_context.gd` | `ComputerContext`: what a page may read. |
| Create `who-knows/src/ship/computer/status_page.gd` | `StatusPage`. |
| Create `who-knows/src/ship/computer/map_page.gd` | `MapPage`. |
| Create `who-knows/src/ship/computer/ship_computer.gd` | `ShipComputer`: one table's screen, buttons, holo, pages and sounds. |
| Modify `who-knows/src/ship/interior/readout_panel.gd` | `last_actor`. |
| Modify `who-knows/src/ship/exterior_builder.gd` | `multimeshes()` and `bounds()`. |
| Modify `who-knows/src/ship/interior_builder.gd` | `computers()`. |
| Modify `who-knows/src/ship/ship.gd` | Saves, rebinds and restores each table around a rebuild. |
| Create `who-knows/src/ui/course_marker.gd` | `CourseMarker`: the course on the HUD. |
| Modify `who-knows/src/ui/salvage_marker.gd` | Skips the course's cloud. |
| Modify `who-knows/src/ui/hud_palette.gd` | `COURSE`. |
| Modify `who-knows/src/audio/synth.gd` | `holo_hum`, `page`, `course_set`, `course_clear`, `course_arrived`. |
| Tests | New: `test_bridge_computer_block`, `test_rock_contacts`, `test_contact_text`, `test_ship_sensors_course`, `test_holo_volume`, `test_status_page`, `test_ship_computer`, `test_map_page`, `test_course_marker`, `test_bridge_computer_scene`. Extended: `test_interior_props`, `test_interior_dressing`, `test_interior_kit`, `test_starter_shuttle`, `test_interior_layout`, `test_airlock_panel` (or the quantum `ReadoutPanel` test), `test_synth`, `test_salvage_marker`, `test_visual_style_rules`. |
| Docs | Slice spec §5, interior redesign §7.5, visual style guide, the bridge computer spec (status and as built), `SLICE-1-STATUS`. |

---

### Task 1: The table on the bridge

**Files:**
- Create: `who-knows/data/blocks/computer.tres`, `who-knows/test/unit/test_bridge_computer_block.gd`
- Modify: `who-knows/src/ship/interior/interior_layout.gd`, `who-knows/src/ship/interior/interior_props.gd`,
  `who-knows/src/ship/interior/interior_dressing.gd`, `who-knows/scenes/flight_test.gd` (`_starter_grid()`)
- Test: `test_interior_props.gd`, `test_interior_dressing.gd`, `test_starter_shuttle.gd`, `test_interior_layout.gd`

**Interfaces:**
- Consumes: `InteriorLayout.QUIET_FIXTURES`, `InteriorDressing.draws_fixture` (quantum Tasks 2–3).
- Produces:
  - `InteriorLayout.COMPUTER_ID := &"computer"`, in `QUIET_FIXTURES`;
  - `InteriorProps.holo_table(kit: InteriorKit, f: Transform3D, variety: float) -> void`;
  - `InteriorProps.holo_table_console() -> Transform3D`, `holo_table_screen() -> Transform3D`,
    `holo_table_buttons() -> Array[Transform3D]` (PAGE, RANGE, ◀, big, ▶) and
    `holo_table_volume() -> Transform3D`, all in the table's fixture frame;
  - constants `HOLO_TABLE_TOP := 0.9`, `HOLO_TABLE_RADIUS := 0.55`, `HOLO_VOLUME_CENTRE := 1.35`,
    `HOLO_CONSOLE_TILT := 55.0`, `HOLO_BUTTON_X: Array[float] = [-0.28, -0.14, 0.0, 0.14, 0.28]`;
  - `InteriorDressing.draws_fixture(&"computer")` is true.

**The frame.** A fixture frame has its origin on the floor under the table's centre, +y up, and −z
the way the fixture faces (`InteriorDressing.fixture_frame`). For the table, −z points toward the
operator. The console sits on that side, and its own frame has +z out of its surface toward the
operator's eyes and +x to the operator's right (fixture −x, because the operator faces +z).

- [ ] **Step 1: Write the failing block test**

`who-knows/test/unit/test_bridge_computer_block.gd`:

```gdscript
extends GutTest

## The bridge computer's block (bridge computer spec §3.1), read back from the
## .tres at runtime: a comment in a hand-authored resource can silently drop a
## property (CLAUDE.md), so a clean load proves nothing.

func test_the_computer_is_a_light_interior_fixture():
	var d: BlockDefinition = load("res://data/blocks/computer.tres")
	assert_not_null(d, "computer.tres loads")
	assert_eq(d.id, InteriorLayout.COMPUTER_ID)
	assert_eq(d.display_name, "Bridge Computer")
	assert_eq(d.category, 2, "Interior")
	assert_eq(d.occupancy, BlockDefinition.Occupancy.MOUNT)
	assert_almost_eq(d.mass_t, 0.3, 0.0001)
	assert_eq(d.hp, 60)
	assert_almost_eq(d.power_gen, 0.0, 0.0001)
	assert_almost_eq(d.power_draw, 0.3, 0.0001)
	assert_not_null(d.mesh, "the hull and the miniature draw its box")

func test_the_catalogue_knows_it():
	var cat := BlockCatalog.load_from_dir("res://data/blocks")
	assert_not_null(cat.get_def(InteriorLayout.COMPUTER_ID))

## Spec §3.1: a quiet fixture, so the bridge's floors, consoles and portholes
## stay as they are round it.
func test_it_is_a_quiet_fixture():
	assert_true(InteriorLayout.QUIET_FIXTURES.has(InteriorLayout.COMPUTER_ID))
```

- [ ] **Step 2: Run it and watch it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_bridge_computer_block'`
Expected: FAIL, because `InteriorLayout.COMPUTER_ID` doesn't exist and `computer.tres` doesn't load.

- [ ] **Step 3: Add the block and the id**

`who-knows/data/blocks/computer.tres` (no comments anywhere in it):

```
[gd_resource type="Resource" script_class="BlockDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/ship/block_definition.gd" id="1_script"]

[sub_resource type="BoxMesh" id="BoxMesh_computer"]
size = Vector3(1.0, 0.95, 1.0)

[resource]
script = ExtResource("1_script")
id = &"computer"
display_name = "Bridge Computer"
category = 2
occupancy = 2
mass_t = 0.3
hp = 60
power_gen = 0.0
power_draw = 0.3
thrust_kn = 0.0
grav_radius = 0.0
mesh = SubResource("BoxMesh_computer")
```

In `interior_layout.gd`, below `const HELM_ID := &"pilot_seat"`:

```gdscript
## The bridge computer's holo table (bridge computer spec §3.1): a fixture
## the dressing draws, and a quiet one, so it leaves the bridge as it is.
const COMPUTER_ID := &"computer"
```

and add `COMPUTER_ID` to `QUIET_FIXTURES`, which quantum Task 2 made
`[&"quantum_core", &"quantum_machine"]`:

```gdscript
const QUIET_FIXTURES: Array[StringName] = [&"quantum_core", &"quantum_machine", COMPUTER_ID]
```

- [ ] **Step 4: Run it and watch it pass**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_bridge_computer_block'`
Expected: PASS.

- [ ] **Step 5: Write the failing prop tests**

Append to `who-knows/test/unit/test_interior_props.gd`:

```gdscript
## Bridge computer spec §3.3: the holo table builds in a bare fixture frame,
## solid where you would walk into it and open where the holo hangs.
func test_the_holo_table_builds_in_a_bare_fixture_frame():
	InteriorProps.holo_table(_kit, Transform3D.IDENTITY, 0.3)
	assert_gt(_kit.commit().size(), 0, "the table added geometry")
	assert_eq(_colliders().size(), 2, "the table, and the console's lip")

func test_nothing_solid_stands_in_the_holo():
	InteriorProps.holo_table(_kit, Transform3D.IDENTITY, 0.3)
	var c := InteriorProps.HOLO_VOLUME_CENTRE
	var volume := AABB(Vector3(-0.5, c - 0.3, -0.5), Vector3(1.0, 0.6, 1.0))
	for shape: CollisionShape3D in _colliders():
		var half := (shape.shape as BoxShape3D).size * 0.5
		var box := AABB(shape.position - half, half * 2.0)
		assert_false(box.intersects(volume), "a collider reaches into the holo")

func test_the_console_faces_its_operator_and_its_buttons_run_left_to_right():
	var out := InteriorProps.holo_table_console().basis.z
	assert_lt(out.z, 0.0, "the console faces -z, toward the operator")
	assert_gt(out.y, 0.0, "and tilts up toward their eyes")
	var buttons := InteriorProps.holo_table_buttons()
	assert_eq(buttons.size(), 5, "PAGE, RANGE, prev, big, next")
	# The operator faces +z, so their right is -x: PAGE is furthest to +x.
	for i in 4:
		assert_gt(buttons[i].origin.x, buttons[i + 1].origin.x)
	assert_gt(InteriorProps.holo_table_screen().origin.y, buttons[0].origin.y,
		"the screen sits above the buttons")
	for b in buttons:
		assert_almost_eq(b.basis.z, out, Vector3.ONE * 0.0001, "each button faces the operator")

func test_the_holo_volume_hangs_over_the_table():
	var v := InteriorProps.holo_table_volume()
	assert_almost_eq(v.origin, Vector3(0, InteriorProps.HOLO_VOLUME_CENTRE, 0), Vector3.ONE * 0.0001)
	assert_gt(InteriorProps.HOLO_VOLUME_CENTRE - 0.3, InteriorProps.HOLO_TABLE_TOP,
		"the holo's floor is above the table top")
```

- [ ] **Step 6: Run them and watch them fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_interior_props'`
Expected: FAIL, because `holo_table` doesn't exist.

- [ ] **Step 7: Build the prop**

In `interior_props.gd`, beside `pilot_station`:

```gdscript
## The bridge computer's holo table (bridge computer spec §3.3).
const HOLO_TABLE_TOP := 0.9
const HOLO_TABLE_RADIUS := 0.55
## The holo's centre, floor-relative: it spans 1.05 to 1.65 m, just under a
## standing eye, so you look slightly down into it.
const HOLO_VOLUME_CENTRE := 1.35
## The rim console's tilt from vertical, degrees: facing an operator's eyes.
const HOLO_CONSOLE_TILT := 55.0
## Where the five buttons sit along the console, operator's left to right:
## PAGE, RANGE, prev, big, next.
const HOLO_BUTTON_X: Array[float] = [-0.28, -0.14, 0.0, 0.14, 0.28]

## The holo table, in a fixture frame: origin on the floor under the table's
## centre, -z toward where its operator stands. A round top on a pedestal and
## a glowing plinth, its black glass ringed by the holo's emitter, and a rim
## console on the operator's side. The holo, the screen's text and the
## buttons are ShipComputer's own nodes; this builds only what never moves.
static func holo_table(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var trim := _c(InteriorPalette.TRIM)
	var low := _c(InteriorPalette.WALL_LOW)
	var up := Basis(Vector3.RIGHT, -PI * 0.5)   # a disc's +z turned to face up
	var down := Basis(Vector3.RIGHT, PI * 0.5)
	# The plinth: a glowing disc, a chunky foot and a column.
	kit.disc(GLOW, f * Transform3D(up, Vector3(0, 0.012, 0)), 0.42, _lit(InteriorPalette.LIGHT_WARM, 2.2))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.06, 0)), Vector3(0.62, 0.1, 0.62), 0.04, trim)
	kit.tube_between(SOLID, f * Vector3(0, 0.1, 0), f * Vector3(0, HOLO_TABLE_TOP - 0.06, 0), 0.16, low)
	# The top: a cream rim, black glass inside it, the emitter ring and the
	# underside.
	var rim_base := HOLO_TABLE_TOP - 0.06
	kit.ring(SOLID, f * Transform3D(up, Vector3(0, rim_base, 0)), HOLO_TABLE_RADIUS - 0.06,
		HOLO_TABLE_RADIUS, 0.0, 0.06, trim)
	kit.disc(SOLID, f * Transform3D(up, Vector3(0, HOLO_TABLE_TOP - 0.004, 0)), HOLO_TABLE_RADIUS - 0.06,
		_c(InteriorPalette.SCREEN_BACK))
	kit.annulus(GLOW, f * Transform3D(up, Vector3(0, HOLO_TABLE_TOP - 0.002, 0)), 0.40, 0.46,
		_lit(InteriorPalette.SKY, 1.4))
	kit.disc(SOLID, f * Transform3D(down, Vector3(0, rim_base, 0)), HOLO_TABLE_RADIUS, low)
	# The rim console, its face on the surface of its own frame.
	var console := f * holo_table_console()
	kit.bevel_box(SOLID, console * _at(Vector3(0, 0, -0.03)), Vector3(0.8, 0.3, 0.06), 0.02, trim)
	# Solid where you'd walk into it; nothing reaches the holo above 1.05 m.
	kit.collider(f * _at(Vector3(0, 0.475, 0)), Vector3(1.0, 0.95, 1.0))
	kit.collider(f * _at(Vector3(0, 0.97, -0.55)), Vector3(0.8, 0.14, 0.2))

## The rim console's frame in the table's fixture frame: origin on its face,
## +z out toward the operator's eyes, +x to the operator's right (fixture -x,
## because the operator faces +z), +y up the slope.
static func holo_table_console() -> Transform3D:
	var t := deg_to_rad(HOLO_CONSOLE_TILT)
	var out := Vector3(0, sin(t), -cos(t))
	var right := Vector3(-1, 0, 0)
	return Transform3D(Basis(right, out.cross(right), out), Vector3(0, 0.95, -0.52))

## The screen's frame: the upper part of the console's face.
static func holo_table_screen() -> Transform3D:
	return holo_table_console() * _at(Vector3(0, 0.06, 0.0))

## The five buttons' frames, in HOLO_BUTTON_X order, along the console's
## lower edge.
static func holo_table_buttons() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for x in HOLO_BUTTON_X:
		out.append(holo_table_console() * _at(Vector3(x, -0.08, 0.0)))
	return out

## The holo's centre over the table. Only its origin matters: the holo is
## turned with the ship, not the table (spec §5.1).
static func holo_table_volume() -> Transform3D:
	return _at(Vector3(0, HOLO_VOLUME_CENTRE, 0))
```

- [ ] **Step 8: Run the prop tests and watch them pass**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_interior_props'`
Expected: PASS, including every existing prop test.

- [ ] **Step 9: Write the failing dressing and starter tests**

Append to `who-knows/test/unit/test_interior_dressing.gd`:

```gdscript
## Bridge computer spec §3.1: the dressing draws the holo table.
func test_the_dressing_draws_the_computer():
	assert_true(InteriorDressing.draws_fixture(InteriorLayout.COMPUTER_ID))

func test_a_computer_gets_its_table_where_its_frame_says():
	_cat.register(_def(InteriorLayout.COMPUTER_ID, BlockDefinition.Occupancy.MOUNT))
	_put(Vector3i(0, 0, 0), InteriorLayout.COMPUTER_ID, 12)   # facing +x
	_put(Vector3i(1, 0, 0), &"deck")
	_builder.rebuild()
	var table := _dressing_colliders().filter(
		func(c): return (c.shape as BoxShape3D).size.is_equal_approx(Vector3(1.0, 0.95, 1.0)))
	assert_eq(table.size(), 1, "one table collider")
	assert_almost_eq(table[0].position, Vector3(0, -0.95 + 0.475, 0), Vector3.ONE * 0.0001,
		"at its cell's floor centre")
```

Append to `who-knows/test/unit/test_starter_shuttle.gd`:

```gdscript
## Bridge computer spec §3.2: the table in the bridge's port back corner,
## facing starboard, toward where you stand to use it.
func test_the_computer_stands_in_the_port_back_corner():
	var inst := _grid.get_block(Vector3i(-1, 0, -1))
	assert_not_null(inst)
	assert_eq(inst.block_id, InteriorLayout.COMPUTER_ID)
	assert_eq(InteriorLayout.facing(inst.orientation), Vector3i(1, 0, 0))

## Spec §3.2: 300 kg at cabin level to port, and 0.3 MW more drawn. Mass and
## draw are exact; the centre of mass is the arithmetic estimate from quantum
## spec §5.4's figures, and Godot's own number is pinned in quantum's test.
func test_the_computer_adds_its_weight_and_its_draw():
	var stats := ShipStats.compute(_grid, _cat)
	assert_almost_eq(stats.total_mass_kg, 97300.0, 0.5)
	assert_almost_eq(stats.power_draw, 31.4, 0.001)
	assert_almost_eq(stats.center_of_mass, Vector3(-0.004, 1.202, 0.111), Vector3.ONE * 0.01)
```

In `test_interior_layout.gd`, find quantum Task 2's recorded-layout test (the starter's zone per
cell and variant per face, with the machine cell's +Z wall as its one exception). Add the
computer cell's two walls to its exceptions, and append:

```gdscript
## Bridge computer spec §3.1: a quiet fixture keeps the bridge as it was. Only
## its own cell's walls change, by the quiet-fixture rule: plain, or a
## porthole on the skin.
func test_the_computer_leaves_the_bridge_alone():
	var cat := BlockCatalog.load_from_dir("res://data/blocks")
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var grid: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	var b := InteriorBuilder.new()
	add_child_autofree(b)
	b.bind(grid, cat)
	b.rebuild()
	var layout := b.layout()
	var cell := Vector3i(-1, 0, -1)
	assert_eq(layout.zone_at(cell), InteriorLayout.ZONE_BRIDGE)
	var variants := {}
	for face in layout.faces():
		if face["coord"] == cell and face["kind"] == InteriorLayout.Kind.WALL:
			variants[face["normal"]] = face["variant"]
	assert_eq(variants.get(Vector3i(0, 0, 1)), InteriorLayout.WallVariant.PANEL, "its back wall goes plain")
	assert_eq(variants.get(Vector3i(-1, 0, 0)), InteriorLayout.WallVariant.PORTHOLE, "its port wall is a porthole")
```

- [ ] **Step 10: Run them and watch them fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_interior_dressing'`, then `'-gselect=test_starter_shuttle'` and `'-gselect=test_interior_layout'`
Expected: FAIL. The dressing doesn't draw the computer, and the starter has no computer.

- [ ] **Step 11: Draw it, and put it on the starter**

In `interior_dressing.gd`, add `InteriorLayout.COMPUTER_ID` to the ids `draws_fixture` accepts. After
quantum Task 3 it reads like this:

```gdscript
static func draws_fixture(id: StringName) -> bool:
	return id in [InteriorLayout.HELM_ID, &"quantum_core", &"quantum_machine", InteriorLayout.COMPUTER_ID]
```

and in `_fixture`, after the branches quantum Task 3 added, add:

```gdscript
	elif fixture["id"] == InteriorLayout.COMPUTER_ID:
		InteriorProps.holo_table(kit, fixture_frame(layout, coord),
			face_variety({"coord": coord, "normal": Vector3i.ZERO}))
```

In `flight_test.gd` `_starter_grid()`, add the constant beside the others:

```gdscript
const O_STARBOARD := 12   ## RIGHT: a fixture facing +x
```

and replace the bridge's back row:

```gdscript
	for x in [-1, 0, 1]:
		_put(g, Vector3i(x, 0, -1), &"deck")
```

keeping whatever quantum Task 1 made of (1, 0, −1) (the machine), so that (−1, 0, −1) holds the
computer and (0, 0, −1) stays deck:

```gdscript
	# The bridge computer's holo table in the port back corner, facing
	# starboard toward where you use it (bridge computer spec §3.2).
	_put(g, Vector3i(-1, 0, -1), InteriorLayout.COMPUTER_ID, O_STARBOARD)
	_put(g, Vector3i(0, 0, -1), &"deck")
```

If quantum Task 1 wrote the row as a loop, split it the same way, and leave its machine exactly as
it put it.

- [ ] **Step 12: Run them and watch them pass, then re-pin the starter**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_interior_dressing'`, `'-gselect=test_starter_shuttle'`, `'-gselect=test_interior_layout'`
Expected: the new tests PASS. Quantum Task 1's pinned-figures test now FAILS: the mass is 97,300 kg,
not 97,000, and the centre of mass, the imbalance, the torque budget and the draw have all moved.

Run the `building-a-ship` probe to read Godot's new figures:
`& $godot --path .\who-knows --resolution 1280x720 --script D:\git\whoknows-computer\.claude\skills\building-a-ship\ship_probe.gd -- D:\git\whoknows-computer\probe-out`
(`$godot` being the path under Global Constraints). Check the printed figures:
- mass exactly 97,300 kg;
- draw exactly 31.4 MW;
- centre of mass within 0.01 m of (−0.004, 1.202, 0.111);
- zero validation issues.

If any of these is off, stop and report. Otherwise, update quantum Task 1's pinned test to Godot's
figures, and the recorded-numbers comment in `_starter_grid()`: add that the table's 300 kg to
port eases the machine's pull to starboard. The probe's spawn, seated and stood renders must show
nothing new in the way. Keep them for the report.

- [ ] **Step 13: Run the whole suite**

Run: `& .\who-knows\run_tests.ps1`
Expected: PASS, pristine output.

- [ ] **Step 14: Render and commit**

With the probe's renders, also render the bridge from the corridor at 1.6 m eye height, with the
table on the left and the machine on the right. Send them to the owner: this is where the table's
size on the bridge is judged (§16). If it crowds the corner, shrink the top to 0.9 m
(`HOLO_TABLE_RADIUS := 0.45`) before going on.

```bash
git add who-knows/data/blocks/computer.tres who-knows/src/ship/interior/interior_layout.gd \
  who-knows/src/ship/interior/interior_props.gd who-knows/src/ship/interior/interior_dressing.gd \
  who-knows/scenes/flight_test.gd who-knows/test/unit/test_bridge_computer_block.gd \
  who-knows/test/unit/test_interior_props.gd who-knows/test/unit/test_interior_dressing.gd \
  who-knows/test/unit/test_starter_shuttle.gd who-knows/test/unit/test_interior_layout.gd
git commit -m "feat: a holo table in the bridge's port back corner

The computer block is a quiet fixture: the dressing draws its table and
leaves the bridge's floors, consoles and portholes as they were. On the
starter it adds 300 kg to port and 0.3 MW of draw; the figures are
re-pinned from Godot's.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: What the sensors know: rocks, words for distance, and the course

**Files:**
- Create: `who-knows/src/sensors/rock_contacts.gd`, `who-knows/src/sensors/contact_text.gd`
- Modify: `who-knows/src/sensors/ship_sensors.gd`, `who-knows/scenes/flight_test.gd` (registers `RockContacts`)
- Test: new `test_rock_contacts.gd`, `test_contact_text.gd`, `test_ship_sensors_course.gd`

**Interfaces:**
- Consumes: `Contact`, `ShipSensors` (`universe`, `time`, `add_source`, `contacts`, `refresh`,
  `focus_point`, `_sources`), `AsteroidRecipe` (`cell_rocks`, `cell_of`, `cell_corner`,
  `Tier.GIANT`, `find_start`), `UniversePoint` (`plus`, `minus`).
- Produces:
  - `RockContacts.new(world_seed: int, start: UniversePoint = null)`; `const RANGE := 30000.0`;
    `const REACH := 6`; `static func id_of(cell: Vector3i) -> StringName` (`&"rock:x,y,z"`);
    `contacts(focus, range_m, time) -> Array[Contact]`; `contact(id, focus, time) -> Contact`;
    `regions_read() -> int`;
  - `ContactText.distance(contact: Contact, metres: float) -> String` and
    `ContactText.line(contact, metres) -> String` (`"ROCK · 3.2 KM"`);
  - `ShipSensors`: signal `course_changed(id: StringName)`, signal `course_arrived(id: StringName)`,
    `const ARRIVE_ROCK := 1000.0`, `var course: StringName`, `var last_arrived: StringName`,
    `set_course(id)`, `clear_course()`, `forget_arrival()`, `course_contact() -> Contact`, and
    arrival checked at the end of every `refresh`.

- [ ] **Step 1: Write the failing `ContactText` test**

`who-knows/test/unit/test_contact_text.gd`:

```gdscript
extends GutTest

## The few capitalised words a screen or the HUD uses for how far a contact is
## (bridge computer spec §5.2, §6.1).

func _contact(precision: StringName, radius := 0.0, km := 0) -> Contact:
	var c := Contact.new()
	c.id = &"x"
	c.kind = &"rock" if precision == &"exact" else &"salvage"
	c.label = "ROCK" if precision == &"exact" else "SALVAGE"
	c.precision = precision
	c.radius = radius
	c.km = km
	return c

func test_a_big_rock_is_as_far_as_its_surface():
	var rock := _contact(&"exact", 300.0)
	assert_eq(ContactText.distance(rock, 3500.0), "3.2 KM")
	assert_eq(ContactText.distance(rock, 1000.0), "700 M")
	assert_eq(ContactText.distance(rock, 200.0), "0 M", "never less than nothing")

func test_a_ping_says_only_its_rounded_kilometres():
	assert_eq(ContactText.distance(_contact(&"ping", 0.0, 4), 3721.0), "~4 KM")

func test_a_region_is_as_far_as_its_edge_and_here_inside():
	var region := _contact(&"region", 75.0)
	assert_eq(ContactText.distance(region, 715.0), "640 M")
	assert_eq(ContactText.distance(region, 60.0), "HERE")

func test_metres_round_to_tens():
	assert_eq(ContactText.distance(_contact(&"exact"), 644.0), "640 M")
	assert_eq(ContactText.distance(_contact(&"exact"), 999.0), "1000 M")

func test_a_line_is_its_label_and_its_distance():
	assert_eq(ContactText.line(_contact(&"exact", 300.0), 3500.0), "ROCK · 3.2 KM")
```

- [ ] **Step 2: Run it and watch it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_contact_text'`
Expected: FAIL, because `ContactText` doesn't exist.

- [ ] **Step 3: Write `ContactText`**

`who-knows/src/sensors/contact_text.gd`:

```gdscript
class_name ContactText
extends RefCounted

## How far a contact is, in the few capitalised words a screen or the HUD
## shows (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §5.2,
## §6.1). `metres` is from the viewer to the contact's point. A big rock is as
## far as its surface; a ping says only its rounded kilometres, so it never
## gives away more than the sensors know; a region is as far as its edge.
## Pure.

static func distance(contact: Contact, metres: float) -> String:
	match contact.precision:
		&"ping":
			return "~%d KM" % contact.km
		&"region":
			var to_edge := metres - contact.radius
			return "HERE" if to_edge <= 0.0 else _metres(to_edge)
	return _metres(maxf(metres - contact.radius, 0.0))

static func line(contact: Contact, metres: float) -> String:
	return "%s · %s" % [contact.label, distance(contact, metres)]

static func _metres(m: float) -> String:
	if m < 1000.0:
		return "%d M" % (roundi(m / 10.0) * 10)
	return "%.1f KM" % (m / 1000.0)
```

Run the import pass, then: `& .\who-knows\run_tests.ps1 '-gselect=test_contact_text'`
Expected: PASS. (`999` rounds to `1000 M`, which is below 1 km before rounding, as the test pins.)

- [ ] **Step 4: Write the failing `RockContacts` test**

`who-knows/test/unit/test_rock_contacts.gd`:

```gdscript
extends GutTest

## Big rocks as sensor contacts (bridge computer spec §4.2): one exact contact
## per asteroid group's big rock within 30 km, from the recipe alone.

const SEED := 1337

func _ids(list: Array[Contact]) -> Array:
	var out := list.map(func(c: Contact) -> String: return String(c.id))
	out.sort()
	return out

func test_the_same_seed_gives_the_same_rocks():
	var focus := UniversePoint.at(0, 0, 0)
	var a := RockContacts.new(SEED).contacts(focus, RockContacts.RANGE, 0.0)
	var b := RockContacts.new(SEED).contacts(focus, RockContacts.RANGE, 0.0)
	assert_gt(a.size(), 0, "there are big rocks within 30 km")
	assert_eq(_ids(a), _ids(b))

func test_every_rock_is_exact_and_within_range():
	var focus := UniversePoint.at(0, 0, 0)
	for c in RockContacts.new(SEED).contacts(focus, 10000.0, 0.0):
		assert_eq(c.kind, &"rock")
		assert_eq(c.label, "ROCK")
		assert_eq(c.precision, &"exact")
		assert_gt(c.radius, 50.0, "a big rock is 150-600 m across")
		assert_lte(c.point.minus(focus).length(), 10000.0)

## REACH is enough: a direct scan one region further finds nothing more
## within 30 km.
func test_no_big_rock_within_range_is_missed():
	var focus := UniversePoint.at(1234, -567, 8901)
	var found := _ids(RockContacts.new(SEED).contacts(focus, RockContacts.RANGE, 0.0))
	var recipe := AsteroidRecipe.new(SEED)
	var centre := AsteroidRecipe.cell_of(AsteroidRecipe.Tier.GIANT, focus)
	var reach := RockContacts.REACH + 1
	var expected := []
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			for dz in range(-reach, reach + 1):
				var cell := centre + Vector3i(dx, dy, dz)
				var rocks := recipe.cell_rocks(AsteroidRecipe.Tier.GIANT, cell)
				if rocks.is_empty():
					continue
				var at := AsteroidRecipe.cell_corner(AsteroidRecipe.Tier.GIANT, cell).plus(rocks[0].local)
				if at.minus(focus).length() <= RockContacts.RANGE:
					expected.append(String(RockContacts.id_of(cell)))
	expected.sort()
	assert_eq(found, expected)

func test_a_rock_is_found_again_by_its_id():
	var focus := UniversePoint.at(0, 0, 0)
	var rocks := RockContacts.new(SEED)
	var first: Contact = rocks.contacts(focus, RockContacts.RANGE, 0.0)[0]
	var again := RockContacts.new(SEED).contact(first.id, focus, 0.0)
	assert_not_null(again, "a fresh reader finds it without a scan")
	assert_true(again.point.is_equal_approx(first.point))
	assert_null(rocks.contact(&"salvage:near", focus, 0.0), "not a rock's id")
	assert_null(rocks.contact(&"rock:nonsense", focus, 0.0))

## Crossing into the next region reads one slab and keeps the rest.
func test_moving_on_matches_a_fresh_read():
	var rocks := RockContacts.new(SEED)
	rocks.contacts(UniversePoint.at(0, 0, 0), RockContacts.RANGE, 0.0)
	var moved := UniversePoint.at(0, 0, 5000)
	var kept := rocks.contacts(moved, RockContacts.RANGE, 0.0)
	var fresh := RockContacts.new(SEED).contacts(moved, RockContacts.RANGE, 0.0)
	assert_eq(_ids(kept), _ids(fresh))
	var side := 2 * RockContacts.REACH + 1
	assert_eq(rocks.regions_read(), side * side * side, "one cube of regions is kept, not two")

func test_the_start_s_own_big_rock_is_close():
	var start := AsteroidRecipe.new(SEED).find_start()
	var near := RockContacts.new(SEED, start).contacts(start, 2000.0, 0.0)
	assert_gt(near.size(), 0, "the start is 700 m off a big rock's surface")
```

- [ ] **Step 5: Run it and watch it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_rock_contacts'`
Expected: FAIL, because `RockContacts` doesn't exist.

- [ ] **Step 6: Write `RockContacts`**

`who-knows/src/sensors/rock_contacts.gd`:

```gdscript
class_name RockContacts
extends RefCounted

## The big rocks the ship's sensors know about
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §4.2): one
## exact contact per asteroid group's big rock within RANGE, read from the
## asteroid recipe, so nothing has to be loaded to be known. A sensor source:
## ShipSensors calls contacts() and contact().
##
## It reads the giant cells (5 km regions) round the focus's own and keeps
## them. Crossing into the next region reads one new slab of 169 and drops the
## far one. A rock someone has shoved stays where the recipe put it: salvage
## placement accepts the same (quantum energy spec §10.2).

const RANGE := 30000.0
## Regions either side of the focus's own that can hold a rock within RANGE:
## any further, and even its nearest point is 30 km away.
const REACH := 6
const PREFIX := "rock:"

var _recipe: AsteroidRecipe
var _centre := Vector3i(2147483647, 2147483647, 2147483647)   # nothing read yet
var _by_cell: Dictionary = {}   # Vector3i -> Contact, or null for a region with no big rock

## `start` must be the stream's, so the recipe keeps the same bubble clear.
func _init(world_seed: int, start: UniversePoint = null) -> void:
	_recipe = AsteroidRecipe.new(world_seed, start)

static func id_of(cell: Vector3i) -> StringName:
	return StringName("%s%d,%d,%d" % [PREFIX, cell.x, cell.y, cell.z])

func contacts(focus: UniversePoint, range_m: float, _time: float) -> Array[Contact]:
	_read_round(focus)
	var reach := minf(range_m, RANGE)
	var out: Array[Contact] = []
	for c in _by_cell.values():
		if c != null and (c as Contact).point.minus(focus).length() <= reach:
			out.append(c)
	return out

func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
	var text := String(id)
	if not text.begins_with(PREFIX):
		return null
	var parts := text.substr(PREFIX.length()).split(",")
	if parts.size() != 3 or not (parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int()):
		return null
	var cell := Vector3i(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
	return _by_cell[cell] if _by_cell.has(cell) else _read(cell)

## How many regions are held, for the cost check (spec §11).
func regions_read() -> int:
	return _by_cell.size()

func _read_round(focus: UniversePoint) -> void:
	var centre := AsteroidRecipe.cell_of(AsteroidRecipe.Tier.GIANT, focus)
	if centre == _centre:
		return
	var next := {}
	for dx in range(-REACH, REACH + 1):
		for dy in range(-REACH, REACH + 1):
			for dz in range(-REACH, REACH + 1):
				var cell := centre + Vector3i(dx, dy, dz)
				next[cell] = _by_cell[cell] if _by_cell.has(cell) else _read(cell)
	_by_cell = next
	_centre = centre

func _read(cell: Vector3i) -> Contact:
	var rocks := _recipe.cell_rocks(AsteroidRecipe.Tier.GIANT, cell)
	if rocks.is_empty():
		return null
	var rock: AsteroidRock = rocks[0]
	var c := Contact.new()
	c.id = id_of(cell)
	c.kind = &"rock"
	c.label = "ROCK"
	c.point = AsteroidRecipe.cell_corner(AsteroidRecipe.Tier.GIANT, cell).plus(rock.local)
	c.precision = &"exact"
	# Half its largest side: what you'd call its surface, not the recipe's
	# looser bounding sphere.
	c.radius = maxf(rock.size.x, maxf(rock.size.y, rock.size.z)) * 0.5
	c.km = 0
	return c
```

Run the import pass, then: `& .\who-knows\run_tests.ps1 '-gselect=test_rock_contacts'`
Expected: PASS.

- [ ] **Step 7: Write the failing course test**

`who-knows/test/unit/test_ship_sensors_course.gd`:

```gdscript
extends GutTest

## The course (bridge computer spec §4.3, §6.2): one per ship, kept by its
## sensors, followed beyond range, and cleared on arrival.

class FakeSource extends RefCounted:
	var list: Array[Contact] = []
	func contacts(focus: UniversePoint, range_m: float, _time: float) -> Array[Contact]:
		return list.filter(func(c: Contact) -> bool: return c.point.minus(focus).length() <= range_m)
	func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
		for c in list:
			if c.id == id:
				return c
		return null

var _universe: Universe
var _hull: Node3D
var _sensors: ShipSensors
var _source: FakeSource

func before_each():
	_universe = Universe.new()
	add_child_autofree(_universe)
	_hull = Node3D.new()
	add_child_autofree(_hull)
	_universe.set_focus(_hull)
	_sensors = ShipSensors.new()
	add_child_autofree(_sensors)
	_sensors.universe = _universe
	_source = FakeSource.new()
	_sensors.add_source(_source)

func _add(id: StringName, precision: StringName, at: Vector3, radius := 0.0) -> Contact:
	var c := Contact.new()
	c.id = id
	c.kind = &"rock" if precision == &"exact" else &"salvage"
	c.label = "ROCK" if precision == &"exact" else "SALVAGE"
	c.point = _universe.to_universe(at)
	c.precision = precision
	c.radius = radius
	_source.list.append(c)
	return c

func test_a_course_is_set_cleared_and_announced_once_each():
	_add(&"rock:1,0,0", &"exact", Vector3(0, 0, -5000), 300.0)
	watch_signals(_sensors)
	_sensors.set_course(&"rock:1,0,0")
	_sensors.set_course(&"rock:1,0,0")
	assert_signal_emit_count(_sensors, "course_changed", 1)
	assert_eq(_sensors.course, &"rock:1,0,0")
	_sensors.clear_course()
	_sensors.clear_course()
	assert_signal_emit_count(_sensors, "course_changed", 2)
	assert_eq(_sensors.course, &"")

func test_the_course_is_followed_beyond_any_range():
	_add(&"rock:9,0,0", &"exact", Vector3(0, 0, -45000), 300.0)
	_sensors.set_course(&"rock:9,0,0")
	_sensors.refresh(0.0)
	assert_true(_sensors.contacts(30000.0).is_empty(), "out of the map's reach")
	assert_not_null(_sensors.course_contact(), "but still followed")

func test_arriving_within_a_kilometre_of_a_rock_s_surface_clears_it():
	_add(&"rock:1,0,0", &"exact", Vector3(0, 0, -1500), 300.0)
	_sensors.set_course(&"rock:1,0,0")
	_sensors.refresh(0.0)
	assert_eq(_sensors.course, &"rock:1,0,0", "1.2 km off the surface: not yet")
	watch_signals(_sensors)
	_hull.position = Vector3(0, 0, -300)
	_sensors.refresh(0.25)
	assert_eq(_sensors.course, &"")
	assert_eq(_sensors.last_arrived, &"rock:1,0,0")
	assert_signal_emitted_with_parameters(_sensors, "course_arrived", [&"rock:1,0,0"])

func test_arriving_inside_a_salvage_region_clears_it():
	_add(&"salvage:3,0,0", &"region", Vector3(0, 0, -500), 75.0)
	_sensors.set_course(&"salvage:3,0,0")
	_sensors.refresh(0.0)
	assert_eq(_sensors.course, &"salvage:3,0,0")
	_hull.position = Vector3(0, 0, -450)
	_sensors.refresh(0.25)
	assert_eq(_sensors.course, &"")
	assert_eq(_sensors.last_arrived, &"salvage:3,0,0")

func test_a_ping_never_arrives():
	var c := _add(&"salvage:4,0,0", &"ping", Vector3(0, 0, -4000))
	c.km = 4
	_sensors.set_course(&"salvage:4,0,0")
	_sensors.refresh(0.0)
	assert_eq(_sensors.course, &"salvage:4,0,0")

func test_a_course_whose_contact_is_gone_clears_without_arriving():
	_add(&"salvage:5,0,0", &"region", Vector3(0, 0, -900), 75.0)
	_sensors.set_course(&"salvage:5,0,0")
	_source.list.clear()
	watch_signals(_sensors)
	_sensors.refresh(0.25)
	assert_eq(_sensors.course, &"")
	assert_eq(_sensors.last_arrived, &"")
	assert_signal_not_emitted(_sensors, "course_arrived")

func test_a_new_course_forgets_the_last_arrival():
	_sensors.last_arrived = &"rock:1,0,0"
	_add(&"rock:2,0,0", &"exact", Vector3(0, 0, -9000), 300.0)
	_sensors.set_course(&"rock:2,0,0")
	assert_eq(_sensors.last_arrived, &"")
```

- [ ] **Step 8: Run it and watch it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_ship_sensors_course'`
Expected: FAIL, because `set_course` doesn't exist.

- [ ] **Step 9: Add the course to `ShipSensors`**

In `ship_sensors.gd`, add:

```gdscript
## The course (docs/superpowers/specs/2026-09-25-bridge-computer-design.md
## §4.3, §6.2): one per ship, kept here so every table and the HUD agree.
signal course_changed(id: StringName)
signal course_arrived(id: StringName)

## Within this far of a big rock's surface, you have arrived.
const ARRIVE_ROCK := 1000.0

var course: StringName = &""
## The course that last cleared by arriving, until the next is set.
var last_arrived: StringName = &""

func set_course(id: StringName) -> void:
	if id == course:
		return
	course = id
	last_arrived = &""
	course_changed.emit(id)

func clear_course() -> void:
	if course.is_empty():
		return
	course = &""
	course_changed.emit(&"")

func forget_arrival() -> void:
	last_arrived = &""

## The course's contact wherever it is, through its source: null for none,
## or once it is gone.
func course_contact() -> Contact:
	if course.is_empty():
		return null
	var focus := focus_point()
	for source in _sources:
		var c: Contact = source.contact(course, focus, time)
		if c != null:
			return c
	return null

## Clears the course on arriving, or once its contact is gone (§6.2).
func _check_course() -> void:
	if course.is_empty():
		return
	var c := course_contact()
	if c == null:
		clear_course()
		return
	var d := c.point.minus(focus_point()).length()
	var arrived := false
	match c.precision:
		&"region":
			arrived = d <= c.radius
		&"exact":
			arrived = d - c.radius <= ARRIVE_ROCK
	if arrived:
		var id := course
		clear_course()
		last_arrived = id
		course_arrived.emit(id)
```

and call `_check_course()` as the last line of `refresh(time)`.

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_ship_sensors_course'`
Expected: PASS. Then run quantum's own sensors test (`'-gselect=test_ship_sensors'`) to check
nothing changed for it.

- [ ] **Step 10: Register the rocks in the flight scene**

In `flight_test.gd` `_wire_universe()`, after `_stream.start(_universe, start)` and wherever quantum
Task 10 registered the salvage field with `_ship.sensors.add_source(...)`, add:

```gdscript
	# Big rocks out to 30 km, for the bridge computer's map and the course
	# (bridge computer spec §4.2). The same seed and start as the stream.
	_ship.sensors.add_source(RockContacts.new(_stream.seed, start))
```

- [ ] **Step 11: Time the first read, then run the whole suite**

The first `contacts()` reads about 2,200 regions (spec §11). Measure it once in a throwaway GUT
test that you don't commit:

```gdscript
extends GutTest
func test_time_the_first_read():
	var start := AsteroidRecipe.new(1337).find_start()
	var rocks := RockContacts.new(1337, start)
	var t0 := Time.get_ticks_usec()
	rocks.contacts(start, RockContacts.RANGE, 0.0)
	gut.p("first read: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	pass_test("timed")
```

Record the figure in your report and delete the file. If it's over 100 ms, make the first read
lazy: read the ring nearest the focus first, and the rest over the next frames, 169 regions per
frame. Add a test that `contacts()` still returns every rock after `ceil(2197 / 169)` calls.

Run: `& .\who-knows\run_tests.ps1`
Expected: PASS, pristine.

- [ ] **Step 12: Commit**

```bash
git add who-knows/src/sensors/ who-knows/scenes/flight_test.gd \
  who-knows/test/unit/test_rock_contacts.gd who-knows/test/unit/test_contact_text.gd \
  who-knows/test/unit/test_ship_sensors_course.gd
git commit -m "feat: the sensors know the big rocks out to 30 km, and keep a course

RockContacts reads each 5 km region's big rock from the recipe; the
ship's sensors gain one course per ship, followed beyond range and
cleared on arrival: inside a salvage region, or within 1 km of a big
rock's surface.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The holo volume

**Files:**
- Create: `who-knows/src/ship/computer/holo_volume.gd`
- Modify: `who-knows/src/ship/interior/interior_kit.gd` (`mesh`),
  `who-knows/src/ship/interior/interior_materials.gd` (`holo`), `who-knows/test/unit/test_visual_style_rules.gd`
- Test: new `test_holo_volume.gd`; `test_interior_kit.gd`

**Interfaces:**
- Consumes: `InteriorKit`, `InteriorPalette.SKY`, `QUANTUM`, `LIGHT_WARM`, `AMBER`, `InteriorMaterials.glow()`.
- Produces:
  - `InteriorKit.mesh(batch: InteriorKit.Batch) -> ArrayMesh`: that batch as a mesh, with no node, and
    the batch emptied;
  - `InteriorMaterials.holo() -> StandardMaterial3D`;
  - `HoloVolume` (`Node3D`):
    - `const RADIUS := 0.5`, `const HALF_HEIGHT := 0.3`, `const CAPACITY := 512`,
      `const MINIATURE_SIZE := 0.8`, `const SPIN := deg_to_rad(10.0)`;
    - `const KINDS: Array[StringName] = [&"rock", &"ping", &"region", &"pinned_rock", &"pinned_salvage", &"stalk", &"tick"]`;
    - `setup(render_layer := InteriorKit.LAYER)`;
    - `static func place(relative: Vector3, range_m: float) -> Dictionary`: `{"position": Vector3, "pinned": bool}`;
    - `show_marks(marks: Array)`, each `{"kind": StringName, "position": Vector3, "size": float}`.
      For `&"stalk"`, `position` is the top of the stalk, and it runs from there to the chevron's
      level;
    - `mark_count(kind) -> int` and `mark_transform(kind, index) -> Transform3D`, for tests;
    - `show_bracket(position: Vector3, size: float, shown: bool)`, `bracket_shown() -> bool`;
    - `show_map_frame(shown: bool)`: the chevron and the edge ring;
    - `show_miniature(meshes: Array[MultiMesh], bounds: AABB)`, `clear_miniature()`,
      `miniature_shown() -> bool`, `miniature_meshes() -> Array[MultiMesh]`.

- [ ] **Step 1: Write the failing kit test**

Append to `who-knows/test/unit/test_interior_kit.gd` (it builds kits in its own `before_each`; if
it has no `_root`, make a `Node3D` with `add_child_autofree` in the test):

```gdscript
## Bridge computer spec §10: one batch as a mesh, for pieces something else
## instances, like the holo's MultiMeshes.
func test_one_batch_comes_out_as_a_mesh_with_no_node():
	var root := Node3D.new()
	add_child_autofree(root)
	var kit := InteriorKit.new(root)
	kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D.IDENTITY, Vector3.ONE, 0.2,
		InteriorKit.lit(InteriorPalette.SKY, 1.4))
	kit.box(InteriorKit.Batch.SOLID, Transform3D.IDENTITY, Vector3.ONE, InteriorKit.solid(InteriorPalette.TRIM))
	var mesh := kit.mesh(InteriorKit.Batch.GLOW)
	assert_not_null(mesh)
	assert_eq(mesh.get_surface_count(), 1)
	assert_eq(root.get_child_count(), 0, "no node was made")
	var committed := kit.commit()
	assert_eq(committed.size(), 1, "only the solid batch is left to commit")
	assert_null(kit.mesh(InteriorKit.Batch.GLOW), "the batch was emptied")
```

- [ ] **Step 2: Run it, watch it fail, add `mesh`, watch it pass**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_interior_kit'`. Expected: FAIL (no `mesh`).

In `interior_kit.gd`, after `commit()`:

```gdscript
## One batch as a mesh, with no node: for pieces something else instances,
## like the bridge computer's holo marks (bridge computer spec §10). The batch
## is emptied, as commit() empties all of them. Null if nothing was added to it.
func mesh(batch: Batch) -> ArrayMesh:
	if not _tools.has(batch):
		return null
	var st: SurfaceTool = _tools[batch]
	_tools.erase(batch)
	return st.commit()
```

Run it again. Expected: PASS.

- [ ] **Step 3: Write the failing holo tests**

`who-knows/test/unit/test_holo_volume.gd`:

```gdscript
extends GutTest

## The holo over the bridge computer's table (bridge computer spec §5, §7):
## where a contact sits in it, how marks are drawn, and the miniature.

var _holo: HoloVolume

func before_each():
	_holo = HoloVolume.new()
	_holo.setup()
	add_child_autofree(_holo)

func test_the_range_fills_the_volume_s_radius():
	var p := HoloVolume.place(Vector3(0, 0, -1000), 2000.0)
	assert_almost_eq(p["position"], Vector3(0, 0, -0.25), Vector3.ONE * 0.0001)
	assert_false(p["pinned"])
	var q := HoloVolume.place(Vector3(3000, 0, 0), 10000.0)
	assert_almost_eq(q["position"], Vector3(0.15, 0, 0), Vector3.ONE * 0.0001)

func test_height_uses_the_same_scale():
	var p := HoloVolume.place(Vector3(0, 1000, -1000), 10000.0)
	assert_almost_eq(p["position"], Vector3(0, 0.05, -0.05), Vector3.ONE * 0.0001)

func test_beyond_the_range_a_contact_is_pinned_to_the_edge_in_its_own_direction():
	var p := HoloVolume.place(Vector3(0, 0, -45000), 30000.0)
	assert_true(p["pinned"])
	assert_almost_eq(p["position"], Vector3(0, 0, -HoloVolume.RADIUS), Vector3.ONE * 0.0001)
	var q := HoloVolume.place(Vector3(3000, 3000, 0), 2000.0)
	assert_true(q["pinned"])
	var pos: Vector3 = q["position"]
	assert_almost_eq(pos.y, HoloVolume.HALF_HEIGHT, 0.0001, "pinned to the top")
	assert_almost_eq(pos.x, pos.y, 0.0001, "still the same direction")

func test_marks_are_drawn_by_kind():
	_holo.show_marks([
		{"kind": &"rock", "position": Vector3(0.1, 0, 0), "size": 0.01},
		{"kind": &"rock", "position": Vector3(-0.1, 0, 0), "size": 0.02},
		{"kind": &"ping", "position": Vector3(0, 0, -0.2), "size": 0.012},
	])
	assert_eq(_holo.mark_count(&"rock"), 2)
	assert_eq(_holo.mark_count(&"ping"), 1)
	assert_eq(_holo.mark_count(&"region"), 0)
	_holo.show_marks([])
	assert_eq(_holo.mark_count(&"rock"), 0, "an empty list clears them")

func test_more_marks_than_it_holds_are_cut_off_not_crashed():
	var marks := []
	for i in HoloVolume.CAPACITY + 10:
		marks.append({"kind": &"rock", "position": Vector3.ZERO, "size": 0.006})
	_holo.show_marks(marks)
	assert_eq(_holo.mark_count(&"rock"), HoloVolume.CAPACITY)

func test_a_stalk_runs_from_its_mark_to_the_ship_s_level():
	_holo.show_marks([{"kind": &"stalk", "position": Vector3(0.1, -0.2, 0.05), "size": 0.0}])
	var xf := _holo.mark_transform(&"stalk", 0)
	assert_almost_eq(xf.origin, Vector3(0.1, -0.1, 0.05), Vector3.ONE * 0.0001, "centred halfway")
	assert_almost_eq(xf.basis.get_scale().y, 0.2, 0.0001, "as tall as the drop, never negative")

func test_the_bracket_shows_and_hides():
	_holo.show_bracket(Vector3(0.1, 0, 0), 0.03, true)
	assert_true(_holo.bracket_shown())
	_holo.show_bracket(Vector3.ZERO, 0.0, false)
	assert_false(_holo.bracket_shown())

func test_everything_is_on_the_interior_layer():
	for n in _holo.find_children("*", "GeometryInstance3D", true, false):
		assert_eq((n as GeometryInstance3D).layers, InteriorKit.LAYER, str(n.name))

## Spec §7.1: the miniature shares the hull's MultiMeshes rather than copying
## them, and is sized so its longest side is 0.8 m.
func test_the_miniature_shares_the_meshes_it_is_given():
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = 2
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, 0, -4)))
	mm.set_instance_transform(1, Transform3D(Basis.IDENTITY, Vector3(0, 0, 4)))
	var meshes: Array[MultiMesh] = [mm]
	_holo.show_miniature(meshes, mm.get_aabb())
	assert_true(_holo.miniature_shown())
	assert_eq(_holo.miniature_meshes()[0], mm, "the same resource, not a copy")
	var drawn := _holo.find_children("*", "MultiMeshInstance3D", true, false).filter(
		func(n): return n.multimesh == mm)
	assert_eq(drawn.size(), 1)
	var inst: MultiMeshInstance3D = drawn[0]
	assert_eq(inst.material_override, InteriorMaterials.holo())
	assert_eq(inst.layers, InteriorKit.LAYER)
	var longest := mm.get_aabb().size.z * inst.get_parent().scale.z
	assert_almost_eq(longest, HoloVolume.MINIATURE_SIZE, 0.001)
	_holo.clear_miniature()
	assert_false(_holo.miniature_shown())
```

- [ ] **Step 4: Run them and watch them fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_holo_volume'`
Expected: FAIL, because `HoloVolume` doesn't exist.

- [ ] **Step 5: Add the miniature's material**

In `interior_materials.gd`:

```gdscript
## The bridge computer's miniature ship (bridge computer spec §7.1): the
## hull's own meshes, drawn flat and warm, unshaded and opaque. The glow shader
## would draw their uncoloured vertices white.
static func holo() -> StandardMaterial3D:
	if not _cache.has(&"holo"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = InteriorPalette.LIGHT_WARM
		_cache[&"holo"] = m
	return _cache[&"holo"]
```

- [ ] **Step 6: Write `HoloVolume`**

`who-knows/src/ship/computer/holo_volume.gd`:

```gdscript
class_name HoloVolume
extends Node3D

## The holo over the bridge computer's table
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §5, §7): small
## glowing marks for what the ship's sensors know, a chevron for the ship,
## stalks for height, a bracket round the selected mark, and on the status
## page a miniature of the ship itself.
##
## Every mark is glowing kit geometry, one MultiMesh per kind, so a few
## hundred cost a handful of draws. Nothing changes a shared material: marks
## grow, shrink and pulse by scale, and dim with the rest of the glow in low
## power (quantum energy spec §8.3).
##
## Knows nothing about ships. Its own frame is the map's: origin at the
## volume's centre, axes the ship's, so the table places it unrotated.

const RADIUS := 0.5
const HALF_HEIGHT := 0.3
## Marks of one kind it can draw at once.
const CAPACITY := 512
## The miniature's longest side, metres (spec §7.1), and how fast it turns.
const MINIATURE_SIZE := 0.8
const SPIN := deg_to_rad(10.0)
## How strongly the holo glows, against the glow batch's other pieces.
const ENERGY := 1.4
const BRACKET_PULSE_HZ := 1.5
const KINDS: Array[StringName] = [&"rock", &"ping", &"region", &"pinned_rock", &"pinned_salvage",
	&"stalk", &"tick"]
const _GLOW := InteriorKit.Batch.GLOW

var layer := InteriorKit.LAYER
var _multis: Dictionary = {}   # StringName -> MultiMeshInstance3D
var _frame_parts: Array[MeshInstance3D] = []
var _bracket: MeshInstance3D
var _bracket_at := Vector3.ZERO
var _bracket_size := 0.0
var _pivot: Node3D
var _mini_meshes: Array[MultiMesh] = []
var _time := 0.0

## Builds the marks' MultiMeshes, the chevron, the edge ring and the bracket.
## Call once, before it enters the tree.
func setup(render_layer := InteriorKit.LAYER) -> void:
	layer = render_layer
	for kind in KINDS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh_for(kind)
		mm.instance_count = CAPACITY
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Marks_%s" % kind
		mmi.multimesh = mm
		mmi.material_override = InteriorMaterials.glow()
		mmi.layers = layer
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_multis[kind] = mmi
	var kit := _kit()
	_chevron(kit)
	_edge_ring(kit)
	_frame_parts = kit.commit()
	var bracket_kit := _kit()
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				bracket_kit.bevel_box(_GLOW, InteriorKit.at(Vector3(sx, sy, sz)), Vector3.ONE * 0.18, 0.05,
					InteriorKit.lit(InteriorPalette.AMBER, ENERGY))
	_bracket = bracket_kit.commit()[0]
	_bracket.name = "Bracket"
	_bracket.visible = false
	_pivot = Node3D.new()
	_pivot.name = "Miniature"
	add_child(_pivot)

## Where a contact `relative` metres from the ship, in the ship's axes, sits in
## the holo at `range_m`. Beyond the range, or above or below the volume, it is
## pulled back along its own direction onto the volume's surface: pinned.
static func place(relative: Vector3, range_m: float) -> Dictionary:
	var p := relative * (RADIUS / range_m)
	var t := 1.0
	var flat := Vector2(p.x, p.z).length()
	if flat > RADIUS:
		t = minf(t, RADIUS / flat)
	if absf(p.y) > HALF_HEIGHT:
		t = minf(t, HALF_HEIGHT / absf(p.y))
	return {"position": p * t, "pinned": t < 1.0}

## Draws `marks`, each {kind, position, size}; a kind with none is emptied.
func show_marks(marks: Array) -> void:
	var by_kind := {}
	for kind in KINDS:
		by_kind[kind] = []
	for m in marks:
		by_kind[m["kind"]].append(m)
	for kind: StringName in KINDS:
		var list: Array = by_kind[kind]
		var mm: MultiMesh = _multis[kind].multimesh
		var n := mini(list.size(), CAPACITY)
		for i in n:
			mm.set_instance_transform(i, _transform(kind, list[i]))
		mm.visible_instance_count = n

func mark_count(kind: StringName) -> int:
	return _multis[kind].multimesh.visible_instance_count

func mark_transform(kind: StringName, index: int) -> Transform3D:
	return _multis[kind].multimesh.get_instance_transform(index)

func show_bracket(position: Vector3, size: float, shown: bool) -> void:
	_bracket_at = position
	_bracket_size = size
	_bracket.visible = shown and size > 0.0

func bracket_shown() -> bool:
	return _bracket.visible

## The ship's chevron and the edge ring, which the map shows and the status
## page doesn't.
func show_map_frame(shown: bool) -> void:
	for part in _frame_parts:
		part.visible = shown

## The ship in miniature (spec §7.1), from `meshes` shared as they are, and
## `bounds`, everything they draw in their own frame.
func show_miniature(meshes: Array[MultiMesh], bounds: AABB) -> void:
	clear_miniature()
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if meshes.is_empty() or longest <= 0.0:
		return
	var model := Node3D.new()
	model.name = "Model"
	var s := MINIATURE_SIZE / longest
	model.transform = Transform3D(Basis.from_scale(Vector3.ONE * s), -bounds.get_center() * s)
	_pivot.add_child(model)
	for mm in meshes:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = InteriorMaterials.holo()
		mmi.layers = layer
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(mmi)
	_mini_meshes = meshes.duplicate()

func clear_miniature() -> void:
	for child in _pivot.get_children():
		_pivot.remove_child(child)
		child.free()
	_mini_meshes.clear()

func miniature_shown() -> bool:
	return not _mini_meshes.is_empty()

func miniature_meshes() -> Array[MultiMesh]:
	return _mini_meshes

func _process(delta: float) -> void:
	_time += delta
	_pivot.rotate_y(SPIN * delta)
	if _bracket.visible:
		var pulse := 1.0 + 0.1 * sin(TAU * BRACKET_PULSE_HZ * _time)
		_bracket.transform = Transform3D(Basis.from_scale(Vector3.ONE * _bracket_size * pulse), _bracket_at)

func _transform(kind: StringName, m: Dictionary) -> Transform3D:
	var at: Vector3 = m["position"]
	var size: float = m["size"]
	match kind:
		&"stalk":
			# A centred unit stalk, scaled to the drop: never a negative
			# scale, which would turn it inside out.
			return Transform3D(Basis.from_scale(Vector3(1.0, maxf(absf(at.y), 0.0001), 1.0)),
				Vector3(at.x, at.y * 0.5, at.z))
		&"pinned_rock", &"pinned_salvage":
			var out := at.normalized() if at.length() > 0.0001 else Vector3.BACK
			var up := Vector3.RIGHT if absf(out.y) > 0.99 else Vector3.UP
			return Transform3D(Basis.looking_at(-out, up).scaled(Vector3.ONE * size), at)
	return Transform3D(Basis.from_scale(Vector3.ONE * size), at)

func _mesh_for(kind: StringName) -> ArrayMesh:
	var kit := _kit()
	var sky := InteriorKit.lit(InteriorPalette.SKY, ENERGY)
	var quantum := InteriorKit.lit(InteriorPalette.QUANTUM, ENERGY)
	var warm := InteriorKit.lit(InteriorPalette.LIGHT_WARM, ENERGY * 0.45)
	match kind:
		&"rock":
			kit.bevel_box(_GLOW, Transform3D.IDENTITY, Vector3.ONE, 0.3, sky)
		&"ping":
			kit.bevel_box(_GLOW, Transform3D.IDENTITY, Vector3.ONE, 0.3, quantum)
		&"region":
			# Three rings round the sphere, each two-sided.
			for b in [Basis.IDENTITY, Basis(Vector3.UP, PI * 0.5), Basis(Vector3.RIGHT, PI * 0.5)]:
				_two_sided_ring(kit, b, 0.46, 0.5, InteriorKit.lit(InteriorPalette.QUANTUM, ENERGY * 0.6))
		&"pinned_rock":
			_two_sided_ring(kit, Basis.IDENTITY, 0.3, 0.5, sky)
		&"pinned_salvage":
			_two_sided_ring(kit, Basis.IDENTITY, 0.3, 0.5, quantum)
		&"stalk":
			kit.box(_GLOW, Transform3D.IDENTITY, Vector3(0.003, 1.0, 0.003), warm)
		&"tick":
			kit.bevel_box(_GLOW, Transform3D.IDENTITY, Vector3(1.0, 0.15, 1.0), 0.05, warm)
	return kit.mesh(_GLOW)

static func _two_sided_ring(kit: InteriorKit, b: Basis, r_in: float, r_out: float, colour: Color) -> void:
	kit.annulus(_GLOW, Transform3D(b, Vector3.ZERO), r_in, r_out, colour)
	kit.annulus(_GLOW, Transform3D(b * Basis(Vector3.UP, PI), Vector3.ZERO), r_in, r_out, colour)

## The ship: a small warm arrow at the centre, pointing forward (-z).
func _chevron(kit: InteriorKit) -> void:
	var warm := InteriorKit.lit(InteriorPalette.LIGHT_WARM, ENERGY)
	for side in [-1.0, 1.0]:
		var arm := Transform3D(Basis(Vector3.UP, side * deg_to_rad(30.0)), Vector3(side * 0.008, 0, 0.006))
		kit.bevel_box(_GLOW, arm, Vector3(0.006, 0.006, 0.03), 0.002, warm)

## A faint ring round the volume's edge at the ship's level, both faces.
func _edge_ring(kit: InteriorKit) -> void:
	var dim := InteriorKit.lit(InteriorPalette.LIGHT_WARM, ENERGY * 0.3)
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	kit.annulus(_GLOW, Transform3D(flat, Vector3.ZERO), RADIUS - 0.006, RADIUS, dim)
	kit.annulus(_GLOW, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), RADIUS - 0.006, RADIUS, dim)

func _kit() -> InteriorKit:
	var kit := InteriorKit.new(self)
	kit.layer = layer
	kit.light_mask = layer
	return kit
```

(`_two_sided_ring`'s second face turns the ring 180° about its own up axis, so it faces the other
way.)

- [ ] **Step 7: Run the holo tests and watch them pass**

Run the import pass, then: `& .\who-knows\run_tests.ps1 '-gselect=test_holo_volume'`
Expected: PASS.

- [ ] **Step 8: Hold it to the style rules**

In `test_visual_style_rules.gd`, add `"res://src/ship/computer/holo_volume.gd"` to both
`PAINTING_FILES` and `REUSABLE_FILES`.

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_visual_style_rules'`, then the whole suite.
Expected: PASS, pristine.

- [ ] **Step 9: Commit**

```bash
git add who-knows/src/ship/computer/holo_volume.gd who-knows/src/ship/interior/interior_kit.gd \
  who-knows/src/ship/interior/interior_materials.gd who-knows/test/unit/test_holo_volume.gd \
  who-knows/test/unit/test_interior_kit.gd who-knows/test/unit/test_visual_style_rules.gd \
  who-knows/src/ship/computer/*.uid
git commit -m "feat: the holo volume -- marks, stalks, pins and a miniature, from the kit

Every mark is glowing kit geometry, one MultiMesh per kind; the
miniature shares whatever MultiMeshes it is given, drawn flat and warm.
No new shader, and it never sees the grid.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The table, its pages and the status page

**Files:**
- Create: `who-knows/src/ship/computer/computer_page.gd`, `computer_context.gd`, `status_page.gd`,
  `ship_computer.gd`
- Modify: `who-knows/src/ship/interior/readout_panel.gd` (`last_actor`),
  `who-knows/src/ship/exterior_builder.gd` (`multimeshes`, `bounds`),
  `who-knows/src/ship/interior_builder.gd` (`computers`), `who-knows/src/ship/interior/interior_dressing.gd`
  (builds a `ShipComputer`), `who-knows/src/ship/ship.gd` (saves, binds, restores),
  `who-knows/src/audio/synth.gd` (`holo_hum`, `page`), `who-knows/test/unit/test_visual_style_rules.gd`
- Test: new `test_status_page.gd`, `test_ship_computer.gd`, `test_bridge_computer_scene.gd`;
  `test_synth.gd`, the `ReadoutPanel` test quantum Task 3 wrote (or `test_airlock_panel.gd`)

**Interfaces:**
- Consumes: `ReadoutPanel`, `HoloVolume`, `InteriorProps.holo_table_*`, `QuantumStore`,
  `QuantumValues.LOW_POWER_AUTHORITY`, `SuitCell`, `ShipSensors`, `ShipStats`.
- Produces:
  - `ReadoutPanel.last_actor: Node`, set by `interact(actor)` before `pressed` is emitted;
  - `ExteriorBuilder.multimeshes() -> Array[MultiMesh]` and `bounds() -> AABB`;
  - `InteriorBuilder.computers() -> Array[ShipComputer]`;
  - `ComputerContext` (`RefCounted`): `sensors: ShipSensors`, `store: QuantumStore`,
    `stats: ShipStats`, `hull: Node3D`, `exterior_builder: ExteriorBuilder`, `operator: Node`,
    `time: float`; `relative(point: UniversePoint) -> Vector3`;
  - `ComputerPage` (`RefCounted`): `title()`, `lines(ctx)`, `lit(ctx) -> Array[StringName]`,
    `big_colour(ctx) -> StringName` (`&"go"`, `&"amber"`, `&"dark"`), `prompt(button, ctx)`,
    `press(button, ctx)`, `opened(ctx)`, `holo(volume, ctx, delta)`, `save() -> Dictionary`,
    `restore(state)`;
  - `StatusPage`: `static qe_line(ctx)`, `power_line(ctx)`, `suit_line(ctx)`;
  - `ShipComputer` (`Node3D`): `const BUTTONS: Array[StringName] = [&"page", &"range", &"prev", &"big", &"next"]`,
    `cell: Vector3i`, `holo: HoloVolume`, `panels: Dictionary`, `pages: Array[ComputerPage]`,
    `page_index: int`, `ctx: ComputerContext`; `setup(f: Transform3D, render_layer := InteriorKit.LAYER)`,
    `bind(context)`, `press(button)`, `prompt(button) -> String`, `page() -> ComputerPage`,
    `screen_text() -> String`, `save() -> Dictionary`, `restore(state)`;
  - Synth sounds `&"holo_hum"` (looped, 2.0 s) and `&"page"` (0.08 s).

- [ ] **Step 1: Write the failing `last_actor` test**

In the `ReadoutPanel` test quantum Task 3 wrote (search `test/unit` for `ReadoutPanel.new()`),
append:

```gdscript
## Bridge computer spec §7.2: the table shows the suit of whoever pressed it.
func test_it_remembers_who_pressed_it():
	var panel := ReadoutPanel.new()
	panel.setup(&"page", 2)
	add_child_autofree(panel)
	var who := Node.new()
	add_child_autofree(who)
	panel.interact(who)
	assert_eq(panel.last_actor, who)
```

Run it: FAIL. In `readout_panel.gd`, add `var last_actor: Node` and make `interact` set it before
emitting:

```gdscript
## Whoever pressed it last, for anything that needs to know whose hand it was.
var last_actor: Node

func interact(actor: Node) -> void:
	last_actor = actor
	pressed.emit(role)
```

Run it: PASS. Run the airlock's panel tests too: nothing else changes.

- [ ] **Step 2: Write the failing status page test**

`who-knows/test/unit/test_status_page.gd`:

```gdscript
extends GutTest

## The status page's rim (bridge computer spec §7.2).

class Crew extends Node:
	var suit_cell: SuitCell

func _ctx() -> ComputerContext:
	var ctx := ComputerContext.new()
	ctx.store = QuantumStore.new()
	ctx.store.set_capacity(1200)
	ctx.store.amount = 600
	ctx.stats = ShipStats.new()
	ctx.stats.power_gen = 36.0
	ctx.stats.power_draw = 31.4
	return ctx

func test_at_full_power_it_shows_the_store_and_the_power():
	var ctx := _ctx()
	var page := StatusPage.new()
	assert_eq(page.title(), "STATUS")
	assert_eq(page.lines(ctx)[0], "QE 600 / 1200")
	assert_eq(page.lines(ctx)[1], "POWER 36.0 / 31.4 MW")

func test_in_low_power_it_says_so_and_the_core_gives_half():
	var ctx := _ctx()
	ctx.store.amount = 96
	assert_true(ctx.store.is_low_power(), "96 is below the 120 line")
	assert_eq(StatusPage.qe_line(ctx), "QE 96 · LOW POWER")
	assert_eq(StatusPage.power_line(ctx), "POWER 18.0 / 31.4 MW")

func test_it_shows_the_suit_of_whoever_pressed_it():
	var ctx := _ctx()
	assert_eq(StatusPage.suit_line(ctx), "SUIT --", "nobody yet")
	var crew := Crew.new()
	add_child_autofree(crew)
	crew.suit_cell = SuitCell.new()
	crew.suit_cell.charge = 64.0
	ctx.operator = crew
	assert_eq(StatusPage.suit_line(ctx), "SUIT 64%")

func test_with_nothing_bound_it_shows_dashes_not_errors():
	var ctx := ComputerContext.new()
	assert_eq(StatusPage.qe_line(ctx), "QE --")
	assert_eq(StatusPage.power_line(ctx), "POWER --")

func test_it_uses_no_buttons():
	assert_true(StatusPage.new().lit(_ctx()).is_empty())
	assert_eq(StatusPage.new().big_colour(_ctx()), &"dark")
```

- [ ] **Step 3: Run it and watch it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_status_page'`
Expected: FAIL, because `ComputerContext` doesn't exist.

- [ ] **Step 4: Write the page base, the context and the status page**

`who-knows/src/ship/computer/computer_page.gd`:

```gdscript
class_name ComputerPage
extends RefCounted

## One page of the bridge computer
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §3.5). The
## table shows one at a time and PAGE steps through them; a later feature adds
## a page, not a new machine. The buttons a page may use are &"range",
## &"prev", &"big" and &"next" -- PAGE is the table's own.

func title() -> String:
	return ""

## Up to three lines under the title.
func lines(_ctx: ComputerContext) -> PackedStringArray:
	return PackedStringArray()

## The buttons this page uses right now; the rest stay dark.
func lit(_ctx: ComputerContext) -> Array[StringName]:
	return []

## The big button's colour: &"go", &"amber" or &"dark".
func big_colour(_ctx: ComputerContext) -> StringName:
	return &"dark"

func prompt(_button: StringName, _ctx: ComputerContext) -> String:
	return ""

func press(_button: StringName, _ctx: ComputerContext) -> void:
	pass

## Called when PAGE brings this page up.
func opened(_ctx: ComputerContext) -> void:
	pass

## What the holo shows this frame.
func holo(_volume: HoloVolume, _ctx: ComputerContext, _delta: float) -> void:
	pass

## What survives a rebuild, and putting it back.
func save() -> Dictionary:
	return {}

func restore(_state: Dictionary) -> void:
	pass
```

`who-knows/src/ship/computer/computer_context.gd`:

```gdscript
class_name ComputerContext
extends RefCounted

## What a bridge computer's pages may read
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §3.5): the
## ship binds one to each table after every rebuild. Any field may be null in
## a test, and a page shows dashes rather than fail.

var sensors: ShipSensors
var store: QuantumStore
var stats: ShipStats
var hull: Node3D
var exterior_builder: ExteriorBuilder
## Whoever last pressed one of the table's buttons.
var operator: Node
var time := 0.0

## Where `point` is from the hull, in the hull's own axes: the map's frame
## (spec §5.1).
func relative(point: UniversePoint) -> Vector3:
	if sensors == null or sensors.universe == null or hull == null:
		return Vector3.ZERO
	var basis := hull.global_basis.orthonormalized()
	return basis.inverse() * (sensors.universe.to_engine(point) - hull.global_position)
```

`who-knows/src/ship/computer/status_page.gd`:

```gdscript
class_name StatusPage
extends ComputerPage

## The ship itself (docs/superpowers/specs/2026-09-25-bridge-computer-design.md
## §7): your ship in miniature over the table, and its store, power and suit
## on the rim. It uses no button but PAGE.

func title() -> String:
	return "STATUS"

func lines(ctx: ComputerContext) -> PackedStringArray:
	return PackedStringArray([qe_line(ctx), power_line(ctx), suit_line(ctx)])

static func qe_line(ctx: ComputerContext) -> String:
	if ctx.store == null:
		return "QE --"
	if ctx.store.is_low_power():
		return "QE %d · LOW POWER" % ctx.store.amount
	return "QE %d / %d" % [ctx.store.amount, ctx.store.capacity]

## Generated against drawn: the core gives half in low power (quantum energy
## spec §3.1).
static func power_line(ctx: ComputerContext) -> String:
	if ctx.stats == null:
		return "POWER --"
	var gen := ctx.stats.power_gen
	if ctx.store != null and ctx.store.is_low_power():
		gen *= QuantumValues.LOW_POWER_AUTHORITY
	return "POWER %.1f / %.1f MW" % [gen, ctx.stats.power_draw]

static func suit_line(ctx: ComputerContext) -> String:
	var cell: SuitCell = ctx.operator.get("suit_cell") if ctx.operator != null else null
	if cell == null:
		return "SUIT --"
	return "SUIT %d%%" % roundi(cell.charge / SuitCell.CAPACITY * 100.0)

func holo(volume: HoloVolume, ctx: ComputerContext, _delta: float) -> void:
	volume.show_map_frame(false)
	volume.show_marks([])
	volume.show_bracket(Vector3.ZERO, 0.0, false)
	if not volume.miniature_shown() and ctx.exterior_builder != null:
		volume.show_miniature(ctx.exterior_builder.multimeshes(), ctx.exterior_builder.bounds())
```

Run the import pass, then: `& .\who-knows\run_tests.ps1 '-gselect=test_status_page'`
Expected: PASS.

- [ ] **Step 5: Write the failing table test**

`who-knows/test/unit/test_ship_computer.gd`:

```gdscript
extends GutTest

## One bridge computer's table (bridge computer spec §3.4, §3.5): its screen,
## its five buttons and its pages, built in a bare frame.

class OnePage extends ComputerPage:
	var presses: Array[StringName] = []
	var saved := {"n": 0}
	func title() -> String: return "TEST"
	func lines(_ctx: ComputerContext) -> PackedStringArray: return PackedStringArray(["LINE ONE", "LINE TWO"])
	func lit(_ctx: ComputerContext) -> Array[StringName]: return [&"next", &"big"]
	func big_colour(_ctx: ComputerContext) -> StringName: return &"amber"
	func prompt(button: StringName, _ctx: ComputerContext) -> String: return "Do %s" % button
	func press(button: StringName, _ctx: ComputerContext) -> void: presses.append(button)
	func save() -> Dictionary: return saved.duplicate()
	func restore(state: Dictionary) -> void: saved = state.duplicate()

var _computer: ShipComputer

func before_each():
	_computer = ShipComputer.new()
	_computer.setup(Transform3D.IDENTITY)
	add_child_autofree(_computer)

func test_it_builds_five_buttons_where_the_prop_says():
	var frames := InteriorProps.holo_table_buttons()
	for i in ShipComputer.BUTTONS.size():
		var panel: ReadoutPanel = _computer.panels[ShipComputer.BUTTONS[i]]
		assert_not_null(panel)
		assert_almost_eq(panel.transform.origin, frames[i].origin, Vector3.ONE * 0.0001)
		assert_true(panel.is_in_group("interactable"))

func test_the_holo_hangs_over_the_table_turned_with_the_ship_not_the_table():
	var turned := ShipComputer.new()
	var f := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2, 0, 3))
	turned.setup(f)
	add_child_autofree(turned)
	assert_almost_eq(turned.holo.position, f * InteriorProps.holo_table_volume().origin, Vector3.ONE * 0.0001)
	assert_true(turned.holo.basis.is_equal_approx(Basis.IDENTITY), "the holo is not turned with the table")

func test_the_screen_shows_the_page_s_title_and_lines():
	_computer.pages = [OnePage.new()]
	_computer.press(&"none")
	assert_eq(_computer.screen_text(), "TEST\nLINE ONE\nLINE TWO")

func test_only_the_buttons_a_page_uses_are_lit_and_offered():
	_computer.pages = [OnePage.new()]
	_computer.press(&"none")
	assert_eq(_computer.panels[&"next"].button_state(), &"go")
	assert_eq(_computer.panels[&"big"].button_state(), &"cycling", "amber")
	assert_eq(_computer.panels[&"prev"].button_state(), &"", "dark")
	assert_eq(_computer.panels[&"range"].button_state(), &"")
	assert_eq(_computer.prompt(&"next"), "Do next")
	assert_eq(_computer.prompt(&"prev"), "", "a dark button offers nothing")
	assert_eq(_computer.prompt(&"page"), "", "one page: nowhere to go")

func test_a_press_reaches_the_page_only_on_a_lit_button():
	var page := OnePage.new()
	_computer.pages = [page]
	_computer.press(&"prev")
	_computer.press(&"next")
	assert_eq(page.presses, [&"next"] as Array[StringName])

func test_page_steps_through_the_pages_and_wraps():
	_computer.pages = [OnePage.new(), StatusPage.new()]
	assert_eq(_computer.prompt(&"page"), "Next page")
	_computer.press(&"page")
	assert_eq(_computer.page_index, 1)
	assert_true(_computer.screen_text().begins_with("STATUS"))
	_computer.press(&"page")
	assert_eq(_computer.page_index, 0)

func test_whoever_presses_is_the_operator():
	var who := Node.new()
	add_child_autofree(who)
	_computer.panels[&"page"].interact(who)
	assert_eq(_computer.ctx.operator, who)

func test_its_state_survives_being_saved_and_restored():
	var page := OnePage.new()
	page.saved = {"n": 7}
	_computer.pages = [OnePage.new(), page]
	_computer.page_index = 1
	var state := _computer.save()
	var again := ShipComputer.new()
	again.setup(Transform3D.IDENTITY)
	add_child_autofree(again)
	again.pages = [OnePage.new(), OnePage.new()]
	again.restore(state)
	assert_eq(again.page_index, 1)
	assert_eq((again.pages[1] as OnePage).saved, {"n": 7})
```

- [ ] **Step 6: Run it and watch it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_ship_computer'`
Expected: FAIL, because `ShipComputer` doesn't exist.

- [ ] **Step 7: Add the two sounds**

In `synth.gd`, add `&"holo_hum"` and `&"page"` to `NAMES`, add `&"holo_hum"` to `LOOPED`, and in
`build`'s `match`:

```gdscript
		&"holo_hum":
			x = _holo_hum()
		&"page":
			x = _tones([1760.0], 0.08, 0.15)
```

and add the builder:

```gdscript
## The holo table: a very soft, high shimmer, two close sines beating slowly
## (bridge computer spec §9). Whole cycles of both in 2 s, so it loops clean.
static func _holo_hum() -> PackedFloat32Array:
	var n := _len(2.0)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		x[i] = sin(TAU * 1320.0 * t) + sin(TAU * 1321.5 * t)
	return _gain(x, 0.12)
```

In `test_synth.gd`, add `&"holo_hum": 2.0, &"page": 0.08` to `LENGTHS`.

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_synth'`. Expected: PASS.

- [ ] **Step 8: Write `ShipComputer`**

`who-knows/src/ship/computer/ship_computer.gd`:

```gdscript
class_name ShipComputer
extends Node3D

## One bridge computer's table
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §3, §10): its
## screen, five buttons, holo and pages, built by the dressing at the table's
## frames. The ship binds it to a ComputerContext after every rebuild, and
## saves and restores its state around the rebuild, so a page, a range and a
## selection survive one.
##
## Knows nothing about ships: it takes a frame and a context.

const BUTTONS: Array[StringName] = [&"page", &"range", &"prev", &"big", &"next"]
const BUTTON_SIZE := Vector3(0.09, 0.09, 0.03)
## The ReadoutPanel state each page colour lights.
const PANEL_STATE := {&"go": &"go", &"amber": &"cycling", &"dark": &""}
const SCREEN_SIZE := Vector3(0.5, 0.15, 0.012)

var cell := Vector3i.ZERO
var holo: HoloVolume
var panels: Dictionary = {}   # StringName -> ReadoutPanel
var pages: Array[ComputerPage] = []
var page_index := 0
var ctx := ComputerContext.new()

var _label: Label3D
var _hum: AudioStreamPlayer3D
var _blip: AudioStreamPlayer3D

## Builds the table's moving parts at `f`, the table's fixture frame in this
## node's parent's space. Call once, before it enters the tree.
func setup(f: Transform3D, render_layer := InteriorKit.LAYER) -> void:
	pages = [StatusPage.new()]
	holo = HoloVolume.new()
	holo.name = "Holo"
	holo.position = f * InteriorProps.holo_table_volume().origin
	holo.setup(render_layer)
	add_child(holo)

	var screen := Node3D.new()
	screen.name = "Screen"
	screen.transform = f * InteriorProps.holo_table_screen()
	add_child(screen)
	var kit := InteriorKit.new(screen)
	kit.layer = render_layer
	kit.light_mask = render_layer
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, 0, SCREEN_SIZE.z * 0.5)), SCREEN_SIZE, 0.004,
		InteriorKit.solid(InteriorPalette.SCREEN_BACK))
	kit.commit()
	_label = Label3D.new()
	_label.name = "Readout"
	_label.position = Vector3(0, 0, SCREEN_SIZE.z + 0.002)
	_label.pixel_size = 0.0009
	_label.font_size = 26
	_label.outline_size = 0
	_label.modulate = InteriorPalette.LIGHT_WARM
	_label.shaded = false
	_label.layers = render_layer
	_label.width = 480.0
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	screen.add_child(_label)

	var frames := InteriorProps.holo_table_buttons()
	for i in BUTTONS.size():
		var button: StringName = BUTTONS[i]
		var panel := ReadoutPanel.new()
		panel.setup(button, InteriorKit.LAYER, render_layer, BUTTON_SIZE, false)
		panel.transform = f * frames[i]
		panel.prompt_source = prompt.bind(button)
		panel.pressed.connect(_on_pressed.bind(panel))
		add_child(panel)
		panels[button] = panel

	_hum = _player("Hum", holo.position, -30.0)
	_blip = _player("Blip", screen.transform.origin, -14.0)
	_refresh()

func page() -> ComputerPage:
	return pages[page_index]

func bind(context: ComputerContext) -> void:
	var operator := ctx.operator
	ctx = context
	if ctx.operator == null:
		ctx.operator = operator
	holo.clear_miniature()
	_refresh()

func press(button: StringName) -> void:
	if button == &"page":
		if pages.size() > 1:
			page_index = (page_index + 1) % pages.size()
			page().opened(ctx)
			_play(&"page")
	elif page().lit(ctx).has(button):
		page().press(button, ctx)
		if button == &"range":
			_play(&"page")
	_refresh()

func prompt(button: StringName) -> String:
	if button == &"page":
		return "Next page" if pages.size() > 1 else ""
	if not page().lit(ctx).has(button):
		return ""
	return page().prompt(button, ctx)

func screen_text() -> String:
	return _label.text

func save() -> Dictionary:
	var saved := []
	for p in pages:
		saved.append(p.save())
	return {"page": page_index, "pages": saved}

func restore(state: Dictionary) -> void:
	page_index = clampi(int(state.get("page", 0)), 0, pages.size() - 1)
	var saved: Array = state.get("pages", [])
	for i in mini(saved.size(), pages.size()):
		pages[i].restore(saved[i])
	_refresh()

func _on_pressed(role: StringName, panel: ReadoutPanel) -> void:
	if panel.last_actor != null:
		ctx.operator = panel.last_actor
	press(role)

func _process(delta: float) -> void:
	ctx.time += delta
	page().holo(holo, ctx, delta)
	_refresh()
	if _hum.stream == null:
		_hum.stream = Synth.sound(&"holo_hum")
	if _hum.stream != null and not _hum.playing:
		_hum.play()

func _refresh() -> void:
	var p := page()
	var shown := PackedStringArray([p.title()])
	shown.append_array(p.lines(ctx))
	_label.text = "\n".join(shown)
	var lit := p.lit(ctx)
	for button: StringName in BUTTONS:
		var state: StringName = &""
		if button == &"page":
			state = &"go" if pages.size() > 1 else &""
		elif button == &"big":
			state = PANEL_STATE[p.big_colour(ctx)] if lit.has(&"big") else &""
		elif lit.has(button):
			state = &"go"
		panels[button].set_readout(PackedStringArray(), state)

func _player(player_name: String, at: Vector3, db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	player.bus = AudioBuses.SHIP
	player.volume_db = db
	player.position = at
	add_child(player)
	return player

func _play(sound: StringName) -> void:
	var s := Synth.sound(sound)
	if s != null and is_inside_tree():
		_blip.stream = s
		_blip.play()
```

Run the import pass, then: `& .\who-knows\run_tests.ps1 '-gselect=test_ship_computer'`
Expected: PASS.

- [ ] **Step 9: Write the failing scene test**

`who-knows/test/unit/test_bridge_computer_scene.gd`:

```gdscript
extends GutTest

## The bridge computer in the real flight scene (bridge computer spec §3.2,
## §7, §10): the starter's table, bound to its ship, surviving a rebuild.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func _computer() -> ShipComputer:
	var all := _ship.interior_builder.computers()
	assert_eq(all.size(), 1, "the starter has one table")
	return all[0]

func test_the_starter_has_one_table_bound_to_its_ship():
	var c := _computer()
	assert_eq(c.cell, Vector3i(-1, 0, -1))
	assert_eq(c.ctx.sensors, _ship.sensors)
	assert_eq(c.ctx.store, _ship.quantum.store)
	assert_eq(c.ctx.stats, _ship.stats)
	assert_eq(c.ctx.hull, _ship.exterior)
	assert_eq(c.ctx.exterior_builder, _ship.exterior_builder)

func test_its_buttons_are_interactables_on_the_interior_layer():
	for button in ShipComputer.BUTTONS:
		var panel: ReadoutPanel = _computer().panels[button]
		assert_true(panel.is_in_group("interactable"))
		assert_eq(panel.collision_layer, InteriorKit.LAYER)

## Spec §7.1: the status page's miniature shares the hull's own MultiMeshes.
func test_the_miniature_is_the_hull_s_own_meshes():
	var c := _computer()
	for i in c.pages.size():
		if c.pages[i] is StatusPage:
			c.page_index = i
	c._process(0.016)
	var shared := c.holo.miniature_meshes()
	assert_eq(shared.size(), _ship.exterior_builder.multimeshes().size())
	for mm in _ship.exterior_builder.multimeshes():
		assert_true(shared.has(mm), "shared, not copied")

func test_a_rebuild_makes_a_new_table_bound_again_with_its_state():
	var before := _computer()
	before.page_index = before.pages.size() - 1
	_ship._rebuild_everything()
	var after := _computer()
	assert_ne(after, before, "the dressing rebuilt it")
	assert_eq(after.page_index, before.pages.size() - 1, "its page survived")
	assert_eq(after.ctx.stats, _ship.stats, "and it is bound again")
```

- [ ] **Step 10: Run it and watch it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_bridge_computer_scene'`
Expected: FAIL, because `InteriorBuilder.computers` doesn't exist.

- [ ] **Step 11: Build it into the ship**

In `exterior_builder.gd`, after `alcoves()`:

```gdscript
## The hull's per-type MultiMeshes, for the bridge computer's miniature
## (bridge computer spec §7.1), which shares them rather than copying.
func multimeshes() -> Array[MultiMesh]:
	var out: Array[MultiMesh] = []
	for mmi: MultiMeshInstance3D in _multimeshes.values():
		out.append(mmi.multimesh)
	return out

## Everything the hull draws, in its own frame.
func bounds() -> AABB:
	var box := AABB()
	var first := true
	for mm in multimeshes():
		box = mm.get_aabb() if first else box.merge(mm.get_aabb())
		first = false
	return box
```

In `interior_builder.gd`, after `airlock_rooms()`:

```gdscript
## Every bridge computer the last rebuild dressed (bridge computer spec §10).
func computers() -> Array[ShipComputer]:
	var out: Array[ShipComputer] = []
	if is_instance_valid(_physics_body):
		for node in _physics_body.find_children("*", "Node3D", true, false):
			if node is ShipComputer:
				out.append(node)
	return out
```

In `interior_dressing.gd` `_fixture`, extend the computer branch from Task 1:

```gdscript
	elif fixture["id"] == InteriorLayout.COMPUTER_ID:
		var f := fixture_frame(layout, coord)
		InteriorProps.holo_table(kit, f, face_variety({"coord": coord, "normal": Vector3i.ZERO}))
		var computer := ShipComputer.new()
		computer.name = "Computer_%d_%d_%d" % [coord.x, coord.y, coord.z]
		computer.cell = coord
		computer.setup(f, kit.layer)
		kit.root.add_child(computer)
```

In `ship.gd`:

```gdscript
var _computer_state: Dictionary = {}   # Vector3i -> ShipComputer.save()
```

In `_rebuild_everything()`, add `_save_computers()` as the **first** line, before anything is
rebuilt, and `_bind_computers()` straight after `_apply_stats()`, when the stats, the store and the
sensors are all current:

```gdscript
## Keeps each bridge computer's page, range and selection across a rebuild,
## which frees the dressing and every table in it (bridge computer spec §10).
func _save_computers() -> void:
	for c in interior_builder.computers():
		_computer_state[c.cell] = c.save()

func _bind_computers() -> void:
	for c in interior_builder.computers():
		var context := ComputerContext.new()
		context.sensors = sensors
		context.store = quantum.store if quantum != null else null
		context.stats = stats
		context.hull = exterior
		context.exterior_builder = exterior_builder
		c.bind(context)
		if _computer_state.has(c.cell):
			c.restore(_computer_state[c.cell])
```

(Use the names quantum energy gave `Ship`'s sensors and quantum plant, if they differ.)

- [ ] **Step 12: Run it and watch it pass**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_bridge_computer_scene'`
Expected: PASS.

- [ ] **Step 13: Hold it to the style rules, and run everything**

In `test_visual_style_rules.gd`, add `"res://src/ship/computer/ship_computer.gd"` to
`PAINTING_FILES` and `REUSABLE_FILES`.

Run: `& .\who-knows\run_tests.ps1`
Expected: PASS, pristine. The dressing's one-light-per-cell test still holds (the table adds no
light).

- [ ] **Step 14: Verify in the real scene, and commit**

Launch `flight_test`, walk to the table from the start, and press PAGE: with one page it does
nothing yet, and the status page shows. Render the table at 1.6 m eye height from (0, 0, −1), with
the miniature turning and the rim reading *QE 600 / 1200*, *POWER 36.0 / 31.4 MW* and *SUIT 0%*
(the suit starts empty). Measure frame time looking at it. Send the render to the owner.

```bash
git add who-knows/src/ship/computer/ who-knows/src/ship/interior/readout_panel.gd \
  who-knows/src/ship/exterior_builder.gd who-knows/src/ship/interior_builder.gd \
  who-knows/src/ship/interior/interior_dressing.gd who-knows/src/ship/ship.gd \
  who-knows/src/audio/synth.gd who-knows/test/unit/
git commit -m "feat: the bridge computer's table, its pages, and the ship in miniature

The dressing builds a ShipComputer at each table; the ship binds it to
its sensors, store, stats and hull after every rebuild and keeps its
page across one. The status page shows the ship in miniature from the
hull's own MultiMeshes, with the store, power and suit on the rim.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The map page

**Files:**
- Create: `who-knows/src/ship/computer/map_page.gd`
- Modify: `who-knows/src/ship/computer/ship_computer.gd` (pages become `[MapPage, StatusPage]`)
- Test: new `test_map_page.gd`; `test_ship_computer.gd`, `test_bridge_computer_scene.gd`

**Interfaces:**
- Consumes: `ComputerPage`, `ComputerContext.relative`, `ShipSensors` (`contacts`, `course`,
  `set_course`, `clear_course`, `course_contact`, `last_arrived`, `forget_arrival`, `time`),
  `HoloVolume` (`place`, `show_marks`, `show_bracket`, `show_map_frame`, `clear_miniature`),
  `ContactText.line`, `SalvageSense.PING_PERIOD`.
- Produces: `MapPage`:
  - `const RANGES: Array[float] = [2000.0, 10000.0, 30000.0]`, `const OPEN_AT := 1`, `const STALKS := 12`;
  - `var range_index: int`, `var selected: StringName`;
  - `range_m()`, `targets(ctx) -> Array[Contact]`, `selected_contact(ctx) -> Contact`, `reselect(ctx)`;
  - `static mark_kind(c: Contact, pinned: bool) -> StringName`;
  - `static mark_size(c: Contact, range_m: float, time: float) -> float`.

- [ ] **Step 1: Write the failing map page test**

`who-knows/test/unit/test_map_page.gd`:

```gdscript
extends GutTest

## The map (bridge computer spec §5): the ranges, the targets, the course's
## buttons, the screen's lines and what the holo is given.

class FakeSource extends RefCounted:
	var list: Array[Contact] = []
	func contacts(focus: UniversePoint, range_m: float, _time: float) -> Array[Contact]:
		return list.filter(func(c: Contact) -> bool: return c.point.minus(focus).length() <= range_m)
	func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
		for c in list:
			if c.id == id:
				return c
		return null

var _universe: Universe
var _hull: Node3D
var _sensors: ShipSensors
var _source: FakeSource
var _ctx: ComputerContext
var _page: MapPage
var _holo: HoloVolume

func before_each():
	_universe = Universe.new()
	add_child_autofree(_universe)
	_hull = Node3D.new()
	add_child_autofree(_hull)
	_universe.set_focus(_hull)
	_sensors = ShipSensors.new()
	add_child_autofree(_sensors)
	_sensors.universe = _universe
	_source = FakeSource.new()
	_sensors.add_source(_source)
	_ctx = ComputerContext.new()
	_ctx.sensors = _sensors
	_ctx.hull = _hull
	_page = MapPage.new()
	_holo = HoloVolume.new()
	_holo.setup()
	add_child_autofree(_holo)

func _add(id: StringName, precision: StringName, at: Vector3, radius := 0.0, km := 0) -> Contact:
	var c := Contact.new()
	c.id = id
	c.kind = &"rock" if precision == &"exact" else &"salvage"
	c.label = "ROCK" if precision == &"exact" else "SALVAGE"
	c.point = _universe.to_universe(at)
	c.precision = precision
	c.radius = radius
	c.km = km
	_source.list.append(c)
	return c

func _refresh() -> void:
	_sensors.refresh(0.0)
	_page.reselect(_ctx)

func test_it_opens_at_ten_kilometres_and_range_cycles():
	assert_eq(_page.title(), "MAP · 10 KM")
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · 30 KM")
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · 2 KM")
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · 10 KM")

func test_prev_and_next_step_nearest_first_and_wrap():
	_add(&"rock:far", &"exact", Vector3(0, 0, -8000), 300.0)
	_add(&"rock:near", &"exact", Vector3(0, 0, -3000), 300.0)
	_refresh()
	assert_eq(_page.selected, &"rock:near", "the nearest to start with")
	_page.press(&"next", _ctx)
	assert_eq(_page.selected, &"rock:far")
	_page.press(&"next", _ctx)
	assert_eq(_page.selected, &"rock:near", "wrapped")
	_page.press(&"prev", _ctx)
	assert_eq(_page.selected, &"rock:far")

func test_after_a_change_of_range_the_course_is_selected_if_it_is_there():
	_add(&"rock:near", &"exact", Vector3(0, 0, -3000), 300.0)
	_add(&"rock:far", &"exact", Vector3(0, 0, -8000), 300.0)
	_refresh()
	_sensors.set_course(&"rock:far")
	_page.press(&"range", _ctx)   # 30 km
	assert_eq(_page.selected, &"rock:far")

func test_the_far_range_shows_big_rocks_only():
	_add(&"rock:a", &"exact", Vector3(0, 0, -20000), 300.0)
	_add(&"salvage:b", &"ping", Vector3(0, 0, -4000), 0.0, 4)
	_page.range_index = 2
	_refresh()
	var ids := _page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id)
	assert_eq(ids, [&"rock:a"])

func test_the_big_button_sets_and_clears_the_course():
	_add(&"rock:near", &"exact", Vector3(0, 0, -3000), 300.0)
	_refresh()
	assert_eq(_page.big_colour(_ctx), &"go")
	assert_eq(_page.prompt(&"big", _ctx), "Set course")
	_page.press(&"big", _ctx)
	assert_eq(_sensors.course, &"rock:near")
	assert_eq(_page.big_colour(_ctx), &"amber")
	assert_eq(_page.prompt(&"big", _ctx), "Clear course")
	assert_eq(_page.lines(_ctx)[1], "COURSE SET")
	_page.press(&"big", _ctx)
	assert_eq(_sensors.course, &"")

func test_the_screen_names_the_selected_contact():
	_add(&"rock:near", &"exact", Vector3(0, 0, -3500), 300.0)
	_refresh()
	assert_eq(_page.lines(_ctx)[0], "ROCK · 3.2 KM")
	assert_eq(_page.lines(_ctx)[1], "SET COURSE")

func test_with_nothing_in_range_it_says_so_and_only_range_is_lit():
	_refresh()
	assert_eq(_page.lines(_ctx)[1], "NO CONTACTS")
	assert_eq(_page.lit(_ctx), [&"range"] as Array[StringName])
	assert_eq(_page.big_colour(_ctx), &"dark")

func test_arrived_shows_until_the_selection_changes():
	_add(&"salvage:r", &"region", Vector3(0, 0, -40), 75.0)
	_add(&"rock:x", &"exact", Vector3(0, 0, -5000), 300.0)
	_refresh()
	_sensors.last_arrived = &"salvage:r"
	assert_eq(_page.selected, &"salvage:r")
	assert_eq(_page.lines(_ctx)[1], "ARRIVED")
	_page.press(&"next", _ctx)
	_page.press(&"prev", _ctx)
	assert_eq(_page.lines(_ctx)[1], "SET COURSE", "forgotten once you moved on")

## Spec §5.1: the map is turned with the ship. A rock dead ahead of a hull
## turned to face +x is at the holo's forward edge all the same.
func test_a_rock_dead_ahead_is_at_the_forward_edge_however_the_hull_is_turned():
	_hull.rotation = Vector3(0, -PI * 0.5, 0)
	var ahead := _hull.global_basis * Vector3(0, 0, -1000)
	_add(&"rock:ahead", &"exact", ahead, 300.0)
	_page.range_index = 0   # 2 km
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"rock"), 1)
	assert_almost_eq(_holo.mark_transform(&"rock", 0).origin, Vector3(0, 0, -0.25), Vector3.ONE * 0.0001)

func test_the_course_beyond_range_is_drawn_pinned():
	_add(&"rock:away", &"exact", Vector3(0, 0, -25000), 300.0)
	_refresh()
	_sensors.set_course(&"rock:away")
	_page.range_index = 0
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"pinned_rock"), 1)

func test_stalks_only_for_the_nearest_twelve_and_the_selected():
	for i in 20:
		_add(StringName("rock:%d" % i), &"exact", Vector3(i * 300.0, 200.0, -1000.0 - i * 300.0), 300.0)
	_page.range_index = 1
	_refresh()
	_page.selected = &"rock:19"
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"stalk"), MapPage.STALKS + 1)
	assert_eq(_holo.mark_count(&"tick"), MapPage.STALKS + 1)
	assert_true(_holo.bracket_shown())

func test_mark_sizes_follow_the_range():
	var rock := Contact.new()
	rock.precision = &"exact"
	rock.radius = 300.0
	assert_almost_eq(MapPage.mark_size(rock, 2000.0, 0.0), 0.15, 0.0001, "to scale at 2 km")
	assert_almost_eq(MapPage.mark_size(rock, 10000.0, 0.0), 0.02, 0.0001, "the biggest at 10 km")
	assert_almost_eq(MapPage.mark_size(rock, 30000.0, 0.0), 0.006, 0.0001)
	var ping := Contact.new()
	ping.precision = &"ping"
	assert_almost_eq(MapPage.mark_size(ping, 10000.0, 0.0), 0.012, 0.0001, "full on the refresh")
	assert_lt(MapPage.mark_size(ping, 10000.0, SalvageSense.PING_PERIOD * 0.9), 0.006, "shrunk by the next")

func test_the_page_state_survives_a_save():
	_page.range_index = 2
	_page.selected = &"rock:x"
	var again := MapPage.new()
	again.restore(_page.save())
	assert_eq(again.range_index, 2)
	assert_eq(again.selected, &"rock:x")

## CLAUDE.md: a floating-origin shift must leave the holo exactly as it was.
## The hull is a member, as the real one is, so the shift moves it and the
## origin together, and nothing moves relative to anything.
func test_a_shift_leaves_the_map_unchanged():
	_hull.add_to_group(Universe.EXTERIOR_SPACE)
	_add(&"rock:a", &"exact", Vector3(700, 100, -1600), 300.0)
	_hull.global_position = Vector3(1900, 0, 0)
	_page.range_index = 1
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	var before := _holo.mark_transform(&"rock", 0).origin
	_universe.shift(Vector3(1000, 0, 0))
	_sensors.refresh(0.25)
	_page.holo(_holo, _ctx, 0.0)
	assert_almost_eq(_holo.mark_transform(&"rock", 0).origin, before, Vector3.ONE * 0.0001)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_map_page'`
Expected: FAIL, because `MapPage` doesn't exist.

- [ ] **Step 3: Write `MapPage`**

`who-knows/src/ship/computer/map_page.gd`:

```gdscript
class_name MapPage
extends ComputerPage

## The map (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §5):
## what the ship's sensors know, shrunk into the holo and turned with the
## ship, at 2, 10 or 30 km. ◀ and ▶ pick a contact, nearest first; the big
## button sets or clears the course (§6). It shows only what the sensors
## report: a ping where the ping says, a region as its sphere, never a
## cloud's true centre.

const RANGES: Array[float] = [2000.0, 10000.0, 30000.0]
const OPEN_AT := 1
## Contacts that get a stalk, nearest first; the selected one always does.
const STALKS := 12
## Mark sizes, metres across in the holo (spec §5.2).
const ROCK_MIN_NEAR := 0.01
const ROCK_MIN_MID := 0.008
const ROCK_MAX_MID := 0.02
## A 600 m rock is the biggest; at 10 km it is ROCK_MAX_MID across.
const ROCK_BIGGEST := 600.0
const ROCK_FAR := 0.006
const REGION_MIN := 0.012
const PING_SIZE := 0.012
## A ping shrinks to this share of its size by its next refresh.
const PING_SHRINK := 0.4
const PIN_SIZE := 0.012
const TICK_SIZE := 0.008
const BRACKET_GAP := 0.012

var range_index := OPEN_AT
var selected: StringName = &""

func range_m() -> float:
	return RANGES[range_index]

func title() -> String:
	return "MAP · %d KM" % roundi(range_m() / 1000.0)

## What ◀ and ▶ step through: the contacts on this range, nearest first. The
## far range shows big rocks only (§5.2).
func targets(ctx: ComputerContext) -> Array[Contact]:
	var out: Array[Contact] = []
	if ctx.sensors == null:
		return out
	for c in ctx.sensors.contacts(range_m()):
		if range_index == RANGES.size() - 1 and c.kind != &"rock":
			continue
		out.append(c)
	return out

func selected_contact(ctx: ComputerContext) -> Contact:
	for c in targets(ctx):
		if c.id == selected:
			return c
	return null

## After a change of page or range: the course if it is on this range, else
## the nearest.
func reselect(ctx: ComputerContext) -> void:
	var list := targets(ctx)
	selected = &""
	if list.is_empty():
		return
	for c in list:
		if c.id == ctx.sensors.course:
			selected = c.id
			return
	selected = list[0].id

func opened(ctx: ComputerContext) -> void:
	reselect(ctx)

func lit(ctx: ComputerContext) -> Array[StringName]:
	if targets(ctx).is_empty():
		return [&"range"]
	return [&"range", &"prev", &"big", &"next"]

func big_colour(ctx: ComputerContext) -> StringName:
	if selected_contact(ctx) == null:
		return &"dark"
	return &"amber" if ctx.sensors.course == selected else &"go"

func prompt(button: StringName, ctx: ComputerContext) -> String:
	match button:
		&"range":
			return "Range %d km" % roundi(RANGES[(range_index + 1) % RANGES.size()] / 1000.0)
		&"prev":
			return "Previous target"
		&"next":
			return "Next target"
		&"big":
			return "Clear course" if ctx.sensors.course == selected else "Set course"
	return ""

func press(button: StringName, ctx: ComputerContext) -> void:
	match button:
		&"range":
			range_index = (range_index + 1) % RANGES.size()
			reselect(ctx)
		&"prev", &"next":
			var list := targets(ctx)
			if list.is_empty():
				return
			var at := -1
			for i in list.size():
				if list[i].id == selected:
					at = i
			var step := -1 if button == &"prev" else 1
			selected = list[posmod(at + step, list.size())].id if at >= 0 else list[0].id
			ctx.sensors.forget_arrival()
		&"big":
			if selected_contact(ctx) == null:
				return
			if ctx.sensors.course == selected:
				ctx.sensors.clear_course()
			else:
				ctx.sensors.set_course(selected)

func lines(ctx: ComputerContext) -> PackedStringArray:
	var c := selected_contact(ctx)
	if c == null:
		return PackedStringArray(["", "NO CONTACTS"])
	var action := "SET COURSE"
	if ctx.sensors.course == c.id:
		action = "COURSE SET"
	elif ctx.sensors.last_arrived == c.id:
		action = "ARRIVED"
	return PackedStringArray([ContactText.line(c, ctx.relative(c.point).length()), action])

func holo(volume: HoloVolume, ctx: ComputerContext, _delta: float) -> void:
	volume.clear_miniature()
	volume.show_map_frame(true)
	if selected_contact(ctx) == null:
		reselect(ctx)
	var list := targets(ctx)
	var course := ctx.sensors.course_contact() if ctx.sensors != null else null
	if course != null and not list.any(func(c: Contact) -> bool: return c.id == course.id):
		list.append(course)   # always shown, pinned if it must be
	var time := ctx.sensors.time if ctx.sensors != null else ctx.time
	var marks: Array = []
	var bracketed := false
	for i in list.size():
		var c: Contact = list[i]
		var placed := HoloVolume.place(ctx.relative(c.point), range_m())
		var at: Vector3 = placed["position"]
		var pinned: bool = placed["pinned"]
		var size := PIN_SIZE if pinned else mark_size(c, range_m(), time)
		marks.append({"kind": mark_kind(c, pinned), "position": at, "size": size})
		if not pinned and (i < STALKS or c.id == selected):
			marks.append({"kind": &"stalk", "position": at, "size": 0.0})
			marks.append({"kind": &"tick", "position": Vector3(at.x, 0.0, at.z), "size": TICK_SIZE})
		if c.id == selected:
			volume.show_bracket(at, size + BRACKET_GAP, true)
			bracketed = true
	if not bracketed:
		volume.show_bracket(Vector3.ZERO, 0.0, false)
	volume.show_marks(marks)

static func mark_kind(c: Contact, pinned: bool) -> StringName:
	if pinned:
		return &"pinned_rock" if c.kind == &"rock" else &"pinned_salvage"
	match c.precision:
		&"ping":
			return &"ping"
		&"region":
			return &"region"
	return &"rock"

static func mark_size(c: Contact, range_m: float, time: float) -> float:
	var scale := HoloVolume.RADIUS / range_m
	match c.precision:
		&"ping":
			var age := fposmod(time, SalvageSense.PING_PERIOD) / SalvageSense.PING_PERIOD
			return PING_SIZE * lerpf(1.0, PING_SHRINK, age)
		&"region":
			return maxf(REGION_MIN, c.radius * 2.0 * scale)
	if range_m <= RANGES[0]:
		return maxf(ROCK_MIN_NEAR, c.radius * 2.0 * scale)
	if range_m <= RANGES[1]:
		return clampf(c.radius * 2.0 / ROCK_BIGGEST * ROCK_MAX_MID, ROCK_MIN_MID, ROCK_MAX_MID)
	return ROCK_FAR

func save() -> Dictionary:
	return {"range": range_index, "selected": String(selected)}

func restore(state: Dictionary) -> void:
	range_index = clampi(int(state.get("range", OPEN_AT)), 0, RANGES.size() - 1)
	selected = StringName(state.get("selected", ""))
```

In `ship_computer.gd` `setup`, make the map the first page:

```gdscript
	pages = [MapPage.new(), StatusPage.new()]
```

- [ ] **Step 4: Run it and watch it pass**

Run the import pass, then: `& .\who-knows\run_tests.ps1 '-gselect=test_map_page'`
Expected: PASS.

- [ ] **Step 5: Update the table's scene tests for two pages**

In `test_bridge_computer_scene.gd`, append:

```gdscript
func test_the_table_opens_on_the_map_and_page_reaches_the_status():
	var c := _computer()
	assert_true(c.page() is MapPage)
	assert_true(c.screen_text().begins_with("MAP · 10 KM"))
	c.press(&"page")
	assert_true(c.page() is StatusPage)

func test_the_map_s_range_survives_a_rebuild():
	var c := _computer()
	c.press(&"range")
	_ship._rebuild_everything()
	var after := _computer()
	assert_eq((after.pages[0] as MapPage).range_index, 2)
```

`test_a_rebuild_makes_a_new_table_bound_again_with_its_state` needs no change: it uses
`pages.size() - 1`, which is now the status page.

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_bridge_computer_scene'`, `'-gselect=test_ship_computer'`, then the whole suite.
Expected: PASS, pristine.

- [ ] **Step 6: Verify in the real scene, and commit**

Launch `flight_test`. At the table, at each range, check that the holo reads: the start's big rock
ahead, its salvage region beside it at 2 km, pings at 10 km, the fields at 30 km. Yaw the ship from
the seat with the chase camera and see the map turn. Render each range at 1.6 m from (0, 0, −1).
Measure frame time looking into the 30 km map (spec §11). Send the renders and the figure to the
owner.

```bash
git add who-knows/src/ship/computer/ who-knows/test/unit/test_map_page.gd \
  who-knows/test/unit/test_bridge_computer_scene.gd who-knows/test/unit/test_ship_computer.gd
git commit -m "feat: the map page -- the sensors' contacts at 2, 10 and 30 km, turned with the ship

Rocks to scale up close, pings and regions as the salvage sensor
reports them, pins at the edge, stalks for height, and a bracket on
the selected contact.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The course on the HUD

**Files:**
- Create: `who-knows/src/ui/course_marker.gd`
- Modify: `who-knows/src/ui/hud_palette.gd` (`COURSE`), `who-knows/src/ui/salvage_marker.gd` (skips the
  course), `who-knows/src/audio/synth.gd` (`course_set`, `course_clear`, `course_arrived`),
  `who-knows/src/ship/computer/ship_computer.gd` (plays set and clear), `who-knows/scenes/flight_test.gd`
  (mounts the marker, plays the arrival chime)
- Test: new `test_course_marker.gd`; `test_salvage_marker.gd`, `test_synth.gd`, `test_bridge_computer_scene.gd`

**Interfaces:**
- Consumes: `WorldMarker` (`camera_path`, `view_camera`), `VelocityMarker.resolve`,
  `VelocityMarker.MIN_SPEED_MPS`, `ShipSensors` (`course_contact`, `course_arrived`, `course`,
  `universe`), `ContactText.distance`.
- Produces:
  - `HudPalette.COURSE := Color("ffb45a")`;
  - `CourseMarker` (`WorldMarker`): `bind(sensors)`, `shown`, `mode`, `reading`, `marker_at`,
    `ring_px`, `text`, `alpha`, `const FADE := 0.5`;
  - Synth sounds `&"course_set"` (0.3 s), `&"course_clear"` (0.3 s), `&"course_arrived"` (0.6 s).

- [ ] **Step 1: Write the failing marker test**

`who-knows/test/unit/test_course_marker.gd`:

```gdscript
extends GutTest

## The course on the HUD (bridge computer spec §6.1): a diamond on a big rock,
## a chevron for a ping, a ring round a region, pinned to the edge off
## screen, fading out on arrival.

class FakeSource extends RefCounted:
	var list: Array[Contact] = []
	func contacts(_focus: UniversePoint, _range_m: float, _time: float) -> Array[Contact]:
		return list
	func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
		for c in list:
			if c.id == id:
				return c
		return null

var _cam: Camera3D
var _universe: Universe
var _sensors: ShipSensors
var _source: FakeSource
var _marker: CourseMarker

func before_each():
	_cam = Camera3D.new()
	_cam.name = "Cam"
	add_child_autofree(_cam)
	_cam.current = true
	_universe = Universe.new()
	add_child_autofree(_universe)
	_universe.set_focus(_cam)
	_sensors = ShipSensors.new()
	add_child_autofree(_sensors)
	_sensors.universe = _universe
	_source = FakeSource.new()
	_sensors.add_source(_source)
	_marker = CourseMarker.new()
	_marker.camera_path = NodePath("../Cam")
	_marker.size = Vector2(1280, 720)
	add_child_autofree(_marker)
	_marker.bind(_sensors)

func _telemetry() -> VehicleTelemetry:
	return VehicleTelemetry.from_state(Basis.IDENTITY, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, true, false, 8.0)

func _course(precision: StringName, at: Vector3, radius := 0.0, km := 0) -> void:
	var c := Contact.new()
	c.id = &"c"
	c.kind = &"rock" if precision == &"exact" else &"salvage"
	c.label = "ROCK" if precision == &"exact" else "SALVAGE"
	c.point = _universe.to_universe(at)
	c.precision = precision
	c.radius = radius
	c.km = km
	_source.list = [c]
	_sensors.set_course(&"c")

func test_with_no_course_it_hides():
	_marker.render(_telemetry())
	assert_false(_marker.shown)

func test_a_course_to_a_rock_ahead_is_a_diamond_with_its_distance():
	_course(&"exact", Vector3(0, 0, -3500), 300.0)
	_marker.render(_telemetry())
	assert_true(_marker.shown)
	assert_eq(_marker.mode, VelocityMarker.Mode.ON_FRAME)
	assert_eq(_marker.reading, &"exact")
	assert_eq(_marker.text, "COURSE 3.2 KM")

func test_a_ping_says_only_its_rounded_kilometres():
	_course(&"ping", Vector3(0, 0, -4200), 0.0, 4)
	_marker.render(_telemetry())
	assert_eq(_marker.text, "COURSE ~4 KM")

func test_a_region_is_a_ring_and_hides_once_you_are_inside():
	_course(&"region", Vector3(0, 0, -700), 75.0)
	_marker.render(_telemetry())
	assert_eq(_marker.reading, &"region")
	assert_gt(_marker.ring_px, 0.0)
	assert_eq(_marker.text, "COURSE 630 M")
	_cam.position = Vector3(0, 0, -660)
	_marker.render(_telemetry())
	assert_false(_marker.shown, "inside the region, you look for yourself")

func test_behind_you_it_waits_at_the_edge():
	_course(&"exact", Vector3(0, 0, 3500), 300.0)
	_marker.render(_telemetry())
	assert_eq(_marker.mode, VelocityMarker.Mode.CLAMPED_BEHIND)

func test_without_its_camera_current_or_any_vehicle_it_hides():
	_course(&"exact", Vector3(0, 0, -3500), 300.0)
	_marker.render(null)
	assert_false(_marker.shown)
	_cam.current = false
	_marker.render(_telemetry())
	assert_false(_marker.shown)

func test_on_arrival_it_fades_out_where_it_was():
	_course(&"exact", Vector3(0, 0, -3500), 300.0)
	_marker.render(_telemetry())
	_sensors.clear_course()
	_sensors.course_arrived.emit(&"c")
	_marker.render(_telemetry())
	assert_true(_marker.shown, "still there, fading")
	_marker._process(CourseMarker.FADE)
	_marker.render(_telemetry())
	assert_false(_marker.shown)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_course_marker'`
Expected: FAIL, because `CourseMarker` doesn't exist.

- [ ] **Step 3: Add the colour and write the marker**

In `hud_palette.gd`:

```gdscript
## The course (bridge computer spec §6.1): an amber, so it never reads as the
## readout's own cyan.
const COURSE := Color("ffb45a")
```

`who-knows/src/ui/course_marker.gd`:

```gdscript
class_name CourseMarker
extends WorldMarker

## The course on the HUD
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §6.1): a
## diamond on a big rock, a chevron for a ping, a ring round a salvage region,
## each with its distance, pinned to the screen's edge off screen. Inside a
## region it hides, because that is where the search begins. When the course
## clears by arriving, the last mark fades out over FADE. Mounted per view,
## like every WorldMarker (spec §8).

const SIZE := 9.0
const LINE_WIDTH := 2.0
const LABEL_SIZE := 12
const BEHIND_ALPHA := 0.5
const FADE := 0.5
const MIN_RING := 12.0

var sensors: ShipSensors
var shown := false
var mode: int = VelocityMarker.Mode.HIDDEN
var reading: StringName = &""
var marker_at := Vector2.ZERO
var ring_px := MIN_RING
var text := ""
var alpha := 1.0

var _fading := 0.0

func bind(p_sensors: ShipSensors) -> void:
	sensors = p_sensors
	sensors.course_arrived.connect(func(_id: StringName) -> void: _fading = FADE)

func _process(delta: float) -> void:
	if _fading > 0.0:
		_fading = maxf(_fading - delta, 0.0)

func render(telemetry: VehicleTelemetry) -> void:
	var cam := view_camera(telemetry)
	var c := sensors.course_contact() if sensors != null else null
	if cam == null:
		shown = false
	elif c == null:
		shown = _fading > 0.0
		alpha = _fading / FADE
	else:
		_fading = 0.0
		alpha = 1.0
		_follow(cam, c)
	queue_redraw()

func _follow(cam: Camera3D, c: Contact) -> void:
	var world := sensors.universe.to_engine(c.point)
	var metres := cam.global_position.distance_to(world)
	reading = c.precision
	if reading == &"region" and metres <= c.radius:
		shown = false
		return
	var state := VelocityMarker.resolve(VelocityMarker.MIN_SPEED_MPS, cam.is_position_behind(world),
		cam.unproject_position(world), size)
	mode = state["mode"]
	marker_at = state["position"]
	ring_px = MIN_RING
	if reading == &"region" and mode == VelocityMarker.Mode.ON_FRAME:
		var edge := cam.unproject_position(world + cam.global_basis.x * c.radius)
		ring_px = maxf(MIN_RING, edge.distance_to(marker_at))
	text = "COURSE " + ContactText.distance(c, metres)
	shown = true

func _draw() -> void:
	if not shown:
		return
	var a := alpha * (BEHIND_ALPHA if mode == VelocityMarker.Mode.CLAMPED_BEHIND else 1.0)
	var colour := Color(HudPalette.COURSE, a)
	if mode != VelocityMarker.Mode.ON_FRAME:
		_edge_chevron(colour)
	else:
		match reading:
			&"region":
				draw_arc(marker_at, ring_px, 0.0, TAU, 40, colour, LINE_WIDTH, true)
			&"ping":
				_caret(colour)
			_:
				_diamond(colour)
	var at := marker_at + Vector2(maxf(ring_px, SIZE) + 6.0, 4.0)
	if at.x > size.x - 120.0:
		at.x = marker_at.x - maxf(ring_px, SIZE) - 110.0
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, colour)

func _diamond(colour: Color) -> void:
	var p := marker_at
	draw_polyline(PackedVector2Array([p + Vector2(0, -SIZE), p + Vector2(SIZE, 0), p + Vector2(0, SIZE),
		p + Vector2(-SIZE, 0), p + Vector2(0, -SIZE)]), colour, LINE_WIDTH, true)

## A ping on screen: an open caret over the pinged direction.
func _caret(colour: Color) -> void:
	var p := marker_at
	draw_polyline(PackedVector2Array([p + Vector2(-SIZE, SIZE * 0.5), p + Vector2(0, -SIZE * 0.5),
		p + Vector2(SIZE, SIZE * 0.5)]), colour, LINE_WIDTH, true)

## Off screen: a chevron on the edge, pointing out toward it.
func _edge_chevron(colour: Color) -> void:
	var out := (marker_at - size * 0.5).normalized()
	var side := Vector2(-out.y, out.x) * SIZE * 0.6
	var tip := marker_at + out * SIZE * 0.5
	var back := marker_at - out * SIZE * 0.5
	draw_polyline(PackedVector2Array([back + side, tip, back - side]), colour, LINE_WIDTH, true)
```

Run the import pass, then: `& .\who-knows\run_tests.ps1 '-gselect=test_course_marker'`
Expected: PASS. (`COURSE 630 M`: 700 m to the region's centre less its 75 m radius is 625, which
rounds to tens as 630.)

- [ ] **Step 4: Write the failing salvage-marker test**

In `test_salvage_marker.gd` (quantum Task 10), append a test in that file's own style: with four
salvage contacts and the course set on the nearest, the marker draws the next three and not the
course's cloud. For example, if the file exposes what it drew as `drawn_ids`:

```gdscript
## Bridge computer spec §6.1: the course's cloud is the course marker's, so
## the salvage marker skips it and shows the next three.
func test_it_skips_the_course_s_cloud():
	# four clouds, nearest first: a, b, c, d
	_sensors.set_course(&"salvage:a")
	_marker.render(_telemetry())
	assert_eq(_marker.drawn_ids, [&"salvage:b", &"salvage:c", &"salvage:d"])
```

Adapt the names to what quantum's test and marker actually expose. Run it: FAIL.

- [ ] **Step 5: Make the salvage marker skip the course**

In `salvage_marker.gd`, where it takes the nearest three salvage contacts, drop the course's
first:

```gdscript
		if sensors.course != &"" and c.id == sensors.course:
			continue   # the course marker draws it (bridge computer spec §6.1)
```

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_salvage_marker'`. Expected: PASS.

- [ ] **Step 6: The course's sounds**

In `synth.gd`, add `&"course_set"`, `&"course_clear"` and `&"course_arrived"` to `NAMES`, and to
`build`'s `match`:

```gdscript
		&"course_set":
			x = _tones([660.0, 880.0], 0.3, 0.2)
		&"course_clear":
			x = _tones([880.0, 660.0], 0.3, 0.2)
		&"course_arrived":
			x = _tones([1047.0], 0.6, 0.2)
```

In `test_synth.gd`, add `&"course_set": 0.3, &"course_clear": 0.3, &"course_arrived": 0.6` to
`LENGTHS`.

In `ship_computer.gd` `press`, play them when the big button changes the course:

```gdscript
	elif page().lit(ctx).has(button):
		var course_before := ctx.sensors.course if ctx.sensors != null else &""
		page().press(button, ctx)
		if button == &"range":
			_play(&"page")
		elif button == &"big" and ctx.sensors != null and ctx.sensors.course != course_before:
			_play(&"course_clear" if ctx.sensors.course.is_empty() else &"course_set")
```

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_synth'`. Expected: PASS.

- [ ] **Step 7: Mount the marker and the chime in the flight scene**

In `flight_test.gd`, add a helper (if quantum Task 10 already wrote one that mounts a
`WorldMarker` per view, use that instead):

```gdscript
## Mounts a world marker once per view (bridge computer spec §8): in the canopy
## overlay with CanopyCam, on the HUD screen with ChaseCamera, and on the HUD
## screen with no camera, for a spacewalk. `make` returns a fresh marker.
func _mount_per_view(make: Callable) -> Array[WorldMarker]:
	var cockpit: WorldMarker = make.call()
	cockpit.camera_path = NodePath("../../CanopyCam")
	var chase: WorldMarker = make.call()
	chase.camera_path = NodePath("../../../Ship/Exterior/ChaseCamera")
	var suit: WorldMarker = make.call()
	var out: Array[WorldMarker] = [cockpit, chase, suit]
	for m in out:
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Ship/Canopy/CanopyOverlay.add_child(cockpit)
	_hud.register_element(cockpit)
	$HudRoot/Screen.add_child(chase)
	$HudRoot/Screen.add_child(suit)
	return out
```

and a wiring function called from `_ready()` after `_wire_universe()`:

```gdscript
var _course_chime: AudioStreamPlayer

## The course (bridge computer spec §6): its marker on every view, and a
## chime when you arrive -- through the suit on a spacewalk, else the ship.
func _wire_course() -> void:
	for m in _mount_per_view(func() -> WorldMarker:
			var marker := CourseMarker.new()
			marker.name = "CourseMarker"
			return marker):
		(m as CourseMarker).bind(_ship.sensors)
	_course_chime = AudioStreamPlayer.new()
	_course_chime.name = "CourseChime"
	add_child(_course_chime)
	_ship.sensors.course_arrived.connect(func(_id: StringName) -> void:
		var s := Synth.sound(&"course_arrived")
		if s == null:
			return
		_course_chime.bus = AudioBuses.SUIT if _avatar.mode == Avatar.Mode.SUIT else AudioBuses.SHIP
		_course_chime.stream = s
		_course_chime.play())
```

Names under `CanopyOverlay` and `Screen` must be unique, so if quantum's salvage markers are also
called by a fixed name, let Godot suffix them (`add_child` does, with `force_readable_name` off).
Assert on type, not name, in the tests below.

- [ ] **Step 8: Write the failing scene test, then run it**

Append to `test_bridge_computer_scene.gd`:

```gdscript
## Spec §8: the course marker is mounted once per view.
func test_the_course_marker_is_mounted_per_view():
	var overlay := _root.get_node("Ship/Canopy/CanopyOverlay").get_children().filter(
		func(n): return n is CourseMarker)
	var screen := _root.get_node("HudRoot/Screen").get_children().filter(
		func(n): return n is CourseMarker)
	assert_eq(overlay.size(), 1, "the cockpit's")
	assert_eq(screen.size(), 2, "the chase camera's and the spacewalk's")
	for m in overlay + screen:
		assert_eq((m as CourseMarker).sensors, _ship.sensors)

## The start is 700 m off a big rock, so at 10 km there is always one to pick.
func test_setting_a_course_at_the_table_reaches_the_ship_s_sensors():
	var c := _computer()
	_ship.sensors.refresh(0.0)   # no frame has run its 4 Hz refresh yet
	var map := c.pages[0] as MapPage
	map.reselect(c.ctx)
	assert_ne(map.selected, &"", "the start's big rock is on the map")
	c.press(&"big")
	assert_eq(_ship.sensors.course, map.selected)
```

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_bridge_computer_scene'`, then the whole suite.
Expected: PASS, pristine.

- [ ] **Step 9: The course probe, and commit**

In the real scene:
1. at the table, set a course to the next group's salvage ping;
2. sit and see the course marker through the canopy, then in chase view;
3. fly there, crossing a floating-origin shift, and see it turn from a ping into a region;
4. arrive inside the region: it fades, the chime plays, and the table reads *ARRIVED*.

Then set a course to a rock, go out on a spacewalk, and see the marker on the suit's HUD. Render
the HUD with a course to a rock, to a ping and to a region. Send the renders to the owner.

```bash
git add who-knows/src/ui/ who-knows/src/audio/synth.gd who-knows/src/ship/computer/ship_computer.gd \
  who-knows/scenes/flight_test.gd who-knows/test/unit/
git commit -m "feat: the course on the HUD -- a diamond, a ping or a region, on every view

CourseMarker follows the course's contact as vaguely as the sensors know
it, pins to the edge off screen, and fades out on arrival with a chime.
The salvage marker leaves the course's cloud to it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Docs and the final check

- [ ] **Step 1: The amendments** (spec §13), each in its own document:
  - **slice spec §5:** the `computer` block joins the catalogue;
  - **interior redesign §7.5:** the starter's bridge gains the computer at (−1, 0, −1);
  - **visual style guide:**
    - a section on the holo table: a quiet fixture; a holo of glowing kit geometry with no
      collider, turned with the ship; the miniature in `InteriorMaterials.holo()`;
    - §2.8: the first graphical live-data screen, its colours (rocks `SKY`, salvage `QUANTUM`,
      you `LIGHT_WARM`, the course `AMBER`) and `HudPalette.COURSE`;
    - the frame-time figures from Tasks 4 and 5;
  - **the bridge computer spec:** its status (built), and an "as built" section recording anything
    that differed from the plan, the first-read time from Task 2 and the frame times;
  - **`SLICE-1-STATUS`:** a "what works" entry, with the starter's new figures from Task 1.
- [ ] **Step 2: The final checks:**
  - the full suite, pristine;
  - the walk probe: from the start to the table, press through every button, round the core's port
    side to the helm;
  - the course probe (Task 6, Step 9);
  - every render in spec §12.2, sent to the owner;
  - frame time looking into the 30 km map, and at the status page;
  - the definition of done (spec §17), walked end to end.
- [ ] **Step 3: Commit**

```bash
git add docs/
git commit -m "docs: record the bridge computer -- the holo table, the map, the course and the miniature

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
