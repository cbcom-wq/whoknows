# Ship Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Big ships get a command bridge: a forward `helm` behind a wraparound band of glass, a `captain_chair` on a raised dais, and sittable `crew_station`s, while ships flown from a `pilot_seat` keep the cockpit pod exactly as today.

**Architecture:** Three new MOUNT blocks. `InteriorLayout` learns a list of helm ids and marks every canopy group of a `helm` ship as a **band**; `InteriorDressing` draws band panes, the dais and the new props; `HullLayout` matches each pane outside. A new `Seat` base class generalises `PilotSeat`; the ship builds a `Seat` node per chair and station; `CameraDirector` sits you in any seat but hands over the controls only at one that flies. `ShipRules` gains the bridge rules, and a bridge fixture ship proves it all.

**Tech Stack:** Godot 4.5.1 GDScript, GUT 9.5.

**Spec:** `docs/superpowers/specs/2026-10-09-ship-bridge-design.md` (approved 2026-10-09).

## Global Constraints

- **The pod stays:** a ship flown from a `pilot_seat` builds, looks and plays exactly as today. The starter's pins (`test_starter_shuttle.gd`, `test_cockpit_pod*.gd`, `test_interior_dressing.gd`, the probe's renders) must stay green and unchanged.
- **One flying seat:** a `pilot_seat` or a `helm`; `InteriorLayout.HELM_IDS := [&"pilot_seat", &"helm"]` is the only list of them.
- **Only the seat that flies pilots:** `piloting_changed`, `PilotControls`, the cockpit view, V and C act only for it.
- **The style guide is binding** (`docs/design/visual-style.md`): colours only from `InteriorPalette`/`HullPalette`; no new shader (the band's glass is the existing `PORTAL` slot); render at eye height and show the owner.
- **Numbers:** band pane sill **0.85 m**, top **2.3 m**; dais **0.25 m** high, ramp **0.5 m** deep (27°); seat look **±100° yaw, ±60° pitch**; the helm stands **0.25 m** forward of its cell centre.
- **Block figures** (spec §3.1): `helm` 0.6 t, 0.5 MW; `captain_chair` 0.8 t, 0.2 MW; `crew_station` 0.5 t, 0.3 MW; 60 hp each; tokens `Hm`, `Cc`, `Cs`.
- **The HUD at a seat that does not fly is the walking HUD** (hull and QE, as standing): the plan's reading of spec §3.2's "readouts"; speed and heading at a station come with its job. Record it in the spec at Task 13.
- **Tests:** from `who-knows`, `./run_tests.ps1 '-gselect=<file>.gd'`; GUT exits 0 on a parse error, so read the summary (`All tests passed`, a test count). After a new `class_name`, `godot --headless --path . --import`. The full suite (~17 min) is the owner's call at the end.
- **Godot:** `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe`, written `godot` below.
- **Worktree:** `D:\git\whoknows-bridge`, branch `bridge` (on `ship-designer`). Plain `git` from its root after `Set-Location`; never `git -C`.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit every new script's `.uid` with it.

## Review Focus

1. **Standing up from the captain's chair onto the floor below the dais:** you land on your feet on the bridge floor, never inside the rail or the ramp, and can walk away. Task 11's `test_you_stand_up_from_every_seat_and_walk`.
2. **A save made sitting at a crew station, loaded into a game where that ship was redesigned without the station:** you load seated at the helm, never in a seat that is not there. Task 9's `test_a_seat_that_is_gone_seats_you_at_the_helm`.
3. **F8 while sitting at a crew station:** it boards you to the other ship's helm as from anywhere, and the station you left lets go of you (not seated twice). Task 8's `test_f8_from_a_station_boards_the_other_helm`.
4. **Holding the flight keys while sitting in the captain's chair:** the ship does not move. Task 8's `test_a_seat_that_does_not_fly_moves_nothing`.
5. **A ship with both a `pilot_seat` and a `helm`:** refused by the rules (`TWO_HELMS`), never two pilots. Task 10's `test_two_helms_breaks_two_helms`.

---

## File map

| File | Task | What |
|---|---|---|
| `who-knows/data/blocks/helm.tres`, `captain_chair.tres`, `crew_station.tres` (new) | 1 | the blocks |
| `who-knows/src/ship/ship_plan.gd` | 1 | tokens |
| `who-knows/test/fixtures/bridge/bridge.plan`, `bridge.json` (new) | 1 | the bridge fixture |
| `who-knows/test/unit/test_block_data.gd` | 1 | 32 blocks |
| `who-knows/src/ship/interior/interior_layout.gd` | 2, 3 | `HELM_IDS`, quiet seats, pods only for `pilot_seat`, `band` |
| `who-knows/src/ship/ship.gd` | 2, 7 | `helm_cell`, `seats()`, `seat_at()` |
| `who-knows/src/ship/ship_validator.gd`, `block_damage.gd`, `ship_damage.gd`, `src/npc/populations/ship_crew.gd` | 2 | helm ids |
| `who-knows/test/unit/test_bridge_layout.gd` (new) | 2–5 | layout, band, hull, dais |
| `who-knows/src/ship/interior/interior_props.gd` | 3, 5 | band pane, dais, captain's chair, crew station |
| `who-knows/src/ship/interior/interior_dressing.gd` | 2, 3, 5 | helm frame, bands, panel on the desk, new fixtures |
| `who-knows/src/ship/hull/hull_layout.gd` | 4 | band windows |
| `who-knows/src/avatar/seat.gd`, `seat_job.gd`, `captain_chair_seat.gd`, `crew_station_seat.gd` (new); `pilot_seat.gd` | 6 | seats |
| `who-knows/test/unit/test_seat.gd` (new) | 6 | seats |
| `who-knows/test/unit/test_bridge_seats.gd` (new) | 7, 8 | the ship's seats, sitting |
| `who-knows/src/camera/camera_director.gd` | 8 | any seat |
| `who-knows/scenes/flight_test.gd`, `test/unit/test_save_scene.gd`, `test_starter_ship.gd` | 9 | the seat in the save; `keep_saving` |
| `who-knows/src/ship/ship_rules.gd`, `test/unit/test_ship_rules.gd` | 10 | rules |
| `who-knows/test/unit/test_bridge_ship.gd` (new) | 11 | the fixture proven |
| `.claude/skills/building-a-ship/ship_probe.gd` | 12 | the seat pass |
| skills, agent, reference, spec | 13 | docs |

---

### Task 1: The blocks, their tokens and the bridge fixture

**Files:**
- Create: `who-knows/data/blocks/helm.tres`, `captain_chair.tres`, `crew_station.tres`
- Modify: `who-knows/src/ship/ship_plan.gd` (`BASE`), `who-knows/test/unit/test_block_data.gd`
- Create: `who-knows/test/fixtures/bridge/bridge.plan`, `bridge.json`

**Interfaces:**
- Produces: block ids `&"helm"`, `&"captain_chair"`, `&"crew_station"` (MOUNT, walkable); tokens `Hm`, `Cc`, `Cs`; the fixture `res://test/fixtures/bridge/bridge.json` (id `bridge`, name `Bridge test ship`, 125 blocks) used by Tasks 2–12.

- [ ] **Step 1: The failing tests**

In `who-knows/test/unit/test_block_data.gd`: `test_all_twenty_nine_blocks_load` becomes

```gdscript
func test_all_thirty_two_blocks_load():
	assert_eq(_cat.ids().size(), 32,
		"21 minus retired reactor and battery, plus the three quantum blocks, the bridge computer, the six fairings and the three bridge seats")
```

add `&"helm", &"captain_chair", &"crew_station"` to `test_required_ids_exist`'s list and to `test_walkable_blocks_are_exactly_the_interior_traversables`'s `expected`, and add

```gdscript
func test_the_bridge_seats_are_fixtures():
	for id in [&"helm", &"captain_chair", &"crew_station"]:
		var def := _cat.get_def(id)
		assert_eq(def.occupancy, BlockDefinition.Occupancy.MOUNT, "%s is walkable furniture" % id)
		assert_eq(def.hp, 60)
	assert_almost_eq(_cat.get_def(&"helm").power_draw, 0.5, 0.001)
	assert_almost_eq(_cat.get_def(&"captain_chair").power_draw, 0.2, 0.001)
	assert_almost_eq(_cat.get_def(&"crew_station").power_draw, 0.3, 0.001)
```

- [ ] **Step 2: Run to watch them fail**

Run: `./run_tests.ps1 '-gselect=test_block_data.gd'` and `'-gselect=test_ship_plan.gd'`
Expected: block data FAILS (29 != 32, missing ids). Ship plan still passes (the catalog has no new block yet).

- [ ] **Step 3: The blocks**

Create `who-knows/data/blocks/helm.tres` (no `#` comments anywhere in a `.tres`: CLAUDE.md):

```
[gd_resource type="Resource" script_class="BlockDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/ship/block_definition.gd" id="1_script"]

[sub_resource type="BoxMesh" id="BoxMesh_helm"]
size = Vector3(1.4, 1.6, 1.4)

[resource]
script = ExtResource("1_script")
id = &"helm"
display_name = "Helm"
category = 2
occupancy = 2
mass_t = 0.6
hp = 60
power_gen = 0.0
power_draw = 0.5
thrust_kn = 0.0
grav_radius = 0.0
mesh = SubResource("BoxMesh_helm")
```

`captain_chair.tres`: the same with `BoxMesh_captain_chair`, `id = &"captain_chair"`, `display_name = "Captain's Chair"`, `mass_t = 0.8`, `power_draw = 0.2`. `crew_station.tres`: `BoxMesh_crew_station`, `id = &"crew_station"`, `display_name = "Crew Station"`, `mass_t = 0.5`, `power_draw = 0.3`.

- [ ] **Step 4: Run: block data passes, ship plan fails**

Run both files again.
Expected: `test_block_data.gd` all pass; `test_ship_plan.gd` FAILS `test_every_block_has_one_base_token` (`helm has a base token`).

- [ ] **Step 5: The tokens**

In `who-knows/src/ship/ship_plan.gd`, `BASE` gains, after `&"fairing_slope_long_low": "Fk",`:

```gdscript
	&"helm": "Hm", &"captain_chair": "Cc", &"crew_station": "Cs",
```

Run `test_ship_plan.gd`: Expected all pass (35).

- [ ] **Step 6: The bridge fixture**

Create `who-knows/test/fixtures/bridge/bridge.plan` with exactly:

```
ship   bridge
name   Bridge test ship
desc   The starter with a five-wide command bridge for its bow.

deck y=2    x: -1 .. 1
z -2  Fk  Fk  Fk
z -1  Fh  Fh  Fh
z 0   Fh  Fh  Fh
z 1   Fh  Fh  Fh
z 2   Fh  Fh  Fh
z 3   Fk4 Fk4 Fk4

deck y=1    x: -3 .. 3
z -4  .  Rv R> W  R< Rv .
z -3  .  R^ W  H  W  R^ .
z -2  .  Rb H  H  H  Rb .
z -1  .  H  H  K  H  H  .
z 0   .  H  Qc Qc Qc H  .
z 1   Fs H  G  H  G  H  Fs
z 2   .  H  H  H  H  H  .
z 3   .  W4 T  T  T  W4 .

deck y=0    x: -3 .. 3
z -5  .    C    C    C    C    C    .
z -4  C8   Cs   D    Hm   D    Cs   C12
z -3  C8   D    D    D    D    D    C12
z -2  H    D    D    Cc   D    D    H
z -1  H    Qk12 D    D    Qm   Qk8  H
z 0   .    H    Bk   D    Gy   H    .
z 1   H    H    Bk   D    Wr   H    H
z 2   H    H    Ba   D    Cl   H    H
z 3   T    H    B    A    B    H    T

deck y=-1    x: 0 .. 0
z -3  Fh2
z -2  Fh2
z -1  Fh2
z 0   Fh2
z 1   Fh2
z 2   Fh2
```

It is the starter's stern and equipment storey with its bow replaced: glass across z −5 and down both sides (`C8` to port, `C12` to starboard), the helm and two crew stations in the front row, an open row, the captain's chair on the centreline, then the two quantum cores (turned inboard) and the machine.

From `who-knows`, with `$k = "D:\git\whoknows-bridge\.claude\skills\building-a-ship"`:
Run: `godot --headless --path . --script $k\ship_plan.gd -- to-json "$PWD\test\fixtures\bridge\bridge.plan" "$PWD\test\fixtures\bridge\bridge.json"`
Expected: `plan    wrote ...bridge.json: 125 blocks`. (`ship_check` on it waits for Task 10's rules; until then `NO_POD` breaks it, which is expected.)

- [ ] **Step 7: Commit**

```bash
git add who-knows/data/blocks/helm.tres who-knows/data/blocks/captain_chair.tres who-knows/data/blocks/crew_station.tres who-knows/src/ship/ship_plan.gd who-knows/test/unit/test_block_data.gd who-knows/test/fixtures/bridge
git commit -m "feat: the helm, the captain's chair and the crew station blocks, and a bridge fixture ship"
```

---

### Task 2: One list of helms

**Files:**
- Modify: `who-knows/src/ship/interior/interior_layout.gd` (`HELM_ID` → `HELM_IDS`, `QUIET_FIXTURES`, `_mark_pods`), `src/ship/ship.gd:989-994`, `src/ship/ship_validator.gd:15,36`, `src/ship/block_damage.gd:21`, `src/ship/ship_damage.gd:29`, `src/npc/populations/ship_crew.gd:29`, `src/ship/ship_rules.gd:104`, `src/ship/interior/interior_dressing.gd` (`draws_fixture`, `_fixture`, `fixture_frame`)
- Test: `who-knows/test/unit/test_bridge_layout.gd` (new)

**Interfaces:**
- Consumes: Task 1's blocks and fixture.
- Produces: `InteriorLayout.HELM_IDS: Array[StringName]`, `InteriorLayout.POD_HELM := &"pilot_seat"`, `InteriorLayout.BRIDGE_HELM := &"helm"`, `InteriorLayout.SEAT_IDS := [&"captain_chair", &"crew_station"]`; `InteriorProps.HELM_FORWARD := 0.25`; `Ship.helm_cell()` finding either helm.

- [ ] **Step 1: The failing tests**

Create `who-knows/test/unit/test_bridge_layout.gd`:

```gdscript
extends GutTest

## The bridge in the layout (docs/superpowers/specs/2026-10-09-ship-bridge-design.md
## §3.4, §4, §5): one list of helms, a band where a helm ship has glass, no pod,
## the dais and the hull's windows.

const BRIDGE := "res://test/fixtures/bridge/bridge.json"

var _cat: BlockCatalog
var _grid: ShipGrid
var _layout: InteriorLayout

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func before_each():
	_grid = ShipLibrary.read(BRIDGE)["grid"]
	_layout = InteriorLayout.plan(_grid, _cat, DeckGraph.build(_grid, _cat).walkable_coords())

func _ids(list: Array) -> Array:
	var out := []
	for f in list:
		out.append(f["id"])
	return out

func test_both_helms_are_helms():
	assert_eq(InteriorLayout.HELM_IDS, [&"pilot_seat", &"helm"] as Array[StringName])

func test_a_helm_ship_has_no_pod():
	assert_eq(_layout.pods(), [])

func test_the_starter_still_has_its_pod():
	var starter := ShipLibrary.load_from_dir().grid(&"starter")
	var l := InteriorLayout.plan(starter, _cat, DeckGraph.build(starter, _cat).walkable_coords())
	assert_eq(l.pods().size(), 1)

func test_the_validator_takes_a_helm():
	var codes := []
	for issue in ShipValidator.validate(_grid, _cat):
		codes.append(issue.code)
	assert_does_not_have(codes, &"HAS_PILOT_SEAT")

func test_the_seats_are_fixtures():
	var ids := _ids(_layout.fixtures())
	assert_has(ids, &"helm")
	assert_has(ids, &"captain_chair")
	assert_eq(ids.count(&"crew_station"), 2)

func test_the_chairs_are_quiet():
	assert_true(InteriorLayout.QUIET_FIXTURES.has(&"captain_chair"))
	assert_true(InteriorLayout.QUIET_FIXTURES.has(&"crew_station"))

func test_the_helm_stands_forward_toward_the_glass():
	var f := InteriorDressing.fixture_frame(_layout, Vector3i(0, 0, -4))
	var centre := ShipGrid.cell_center(Vector3i(0, 0, -4))
	assert_almost_eq(f.origin.z, centre.z - InteriorProps.HELM_FORWARD, 0.001)
	assert_almost_eq((-f.basis.z).dot(Vector3.FORWARD), 1.0, 0.001)

func test_the_droid_docks_and_the_crew_scans_the_seats():
	var paths := DeckPaths.build(_layout)
	assert_ne(ShipCrew.dock(_layout, paths), ShipCrew.NO_DOCK)
	var keys := []
	for spot in ShipCrew.work_spots(_layout, paths):
		keys.append(String(spot["key"]))
	assert_has(keys, "fixture:%s" % Vector3i(0, 0, -2), "the captain's chair is tended")

func test_damage_keeps_the_helm_and_counts_it_cockpit():
	assert_true(BlockDamage.KEEP.has(&"helm"))
	assert_true(ShipDamage.COMPONENTS[&"cockpit"].has(&"helm"))
```

- [ ] **Step 2: Run to watch them fail**

Run: `./run_tests.ps1 '-gselect=test_bridge_layout.gd'`
Expected: a parse error first (`HELM_IDS`, `HELM_FORWARD` missing). If `ShipDamage.COMPONENTS` is not the dictionary's name at `ship_damage.gd:29`, use its real name in the test (read the file) and ledger it.

- [ ] **Step 3: The helm list**

In `interior_layout.gd`, replace `const HELM_ID := &"pilot_seat"` and its comment with:

```gdscript
## The two fixtures a ship is flown from (ship bridge spec §3.4): the pod
## helm, whose canopy face ahead becomes a cockpit pod, and the bridge helm,
## which never makes a pod and glazes the ship's canopies as bands.
const POD_HELM := &"pilot_seat"
const BRIDGE_HELM := &"helm"
const HELM_IDS: Array[StringName] = [POD_HELM, BRIDGE_HELM]
## The seats that do not fly (ship bridge spec §3.1).
const SEAT_IDS: Array[StringName] = [&"captain_chair", &"crew_station"]
```

`QUIET_FIXTURES` becomes `[&"quantum_core", &"quantum_machine", COMPUTER_ID, &"captain_chair", &"crew_station"]` (a chair keeps the bridge's floors and walls as they are). In `_mark_pods`, `if fixture["id"] != HELM_ID:` becomes `if fixture["id"] != POD_HELM:`.

Every other `InteriorLayout.HELM_ID`:
- `ship.gd` `helm_cell()`: `if InteriorLayout.HELM_IDS.has(grid.get_block(coord).block_id):`; its comment says "a pilot seat or a helm".
- `ship_crew.gd:29`: `if InteriorLayout.HELM_IDS.has(f["id"]):`.
- `ship_rules.gd:104`: `if InteriorLayout.HELM_IDS.has(f["id"]):`.
- `interior_dressing.gd` `draws_fixture`: `return InteriorLayout.HELM_IDS.has(id) or id in [QUANTUM_CORE_ID, QUANTUM_MACHINE_ID, InteriorLayout.COMPUTER_ID]`; `_fixture`: `if InteriorLayout.HELM_IDS.has(fixture["id"]):`.

`ship_validator.gd`: `PILOT_SEAT_ID` becomes `const HELM_IDS: Array[StringName] = [&"pilot_seat", &"helm"]`, and `var seats := _find_all(grid, PILOT_SEAT_ID)` becomes

```gdscript
	var seats: Array = []
	for id in HELM_IDS:
		seats.append_array(_find_all(grid, id))
```

(the validator stays free of the interior: it keeps its own copy, and a test pins the two equal: add `assert_eq(ShipValidator.HELM_IDS, InteriorLayout.HELM_IDS)` to `test_both_helms_are_helms`).

`block_damage.gd:21`: `KEEP` gains `&"helm"`. `ship_damage.gd:29`: the cockpit gains `&"helm"`: `&"cockpit": [&"pilot_seat", &"helm", &"canopy"],`.

- [ ] **Step 4: The helm's frame**

In `interior_props.gd`, beside `POD_SEAT_DEPTH`:

```gdscript
## How far forward of its cell's centre a bridge helm stands (ship bridge spec
## §4.2): its eye 1.2 m behind the glass.
const HELM_FORWARD := 0.25
```

In `InteriorDressing.fixture_frame`, after the pod loop and before the cell-centre return:

```gdscript
	var origin := ShipGrid.cell_center(coord)
	origin.y = floor_y(coord)
	var id := StringName(_fixture_id(layout, coord))
	if id == InteriorLayout.BRIDGE_HELM:
		origin += Vector3(facing) * InteriorProps.HELM_FORWARD
	return Transform3D(Basis.looking_at(Vector3(facing), Vector3.UP), origin)
```

replacing the two `origin` lines and the return that were there, with the helper

```gdscript
static func _fixture_id(layout: InteriorLayout, coord: Vector3i) -> String:
	for fixture in layout.fixtures():
		if fixture["coord"] == coord:
			return String(fixture["id"])
	return ""
```

- [ ] **Step 5: Run, watch them pass, and the starter's pins**

Run: `test_bridge_layout.gd`, then `test_starter_shuttle.gd`, `test_cockpit_pod.gd` (whichever `test_cockpit_pod*.gd` exist: list `test/unit`), `test_interior_layout.gd`, `test_ship_rules.gd`, `test_ship_damage.gd`, `test_block_damage.gd`, `test_ship_crew.gd` (each that exists).
Expected: the new file 9/9; every other one unchanged and passing.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src who-knows/test/unit/test_bridge_layout.gd who-knows/test/unit/test_bridge_layout.gd.uid
git commit -m "feat: one list of helms -- a pilot seat or a bridge helm; the bridge helm makes no pod"
```

---

### Task 3: The band, inside

**Files:**
- Modify: `who-knows/src/ship/interior/interior_layout.gd` (groups get `band`), `interior_props.gd` (`band_pane`), `interior_dressing.gd` (bands; the lights panel on a helm desk)
- Test: `who-knows/test/unit/test_bridge_layout.gd`

**Interfaces:**
- Consumes: Task 2's `BRIDGE_HELM`.
- Produces: every `canopy_groups()` record has `"band": bool` (true exactly when the ship's helm is a `helm`); `InteriorProps.BAND_SILL := 0.85`, `BAND_TOP := 2.3`, `BAND_POST := 0.08`, `static func band_pane(kit, f, variety)`; a `BandPane_x_y_z` marker per pane; the lights panel of a band ship on the helm desk (`InteriorProps.helm_panel_frame()`).

- [ ] **Step 1: The failing tests**

Append to `test_bridge_layout.gd`:

```gdscript
func test_every_group_of_a_helm_ship_is_a_band():
	assert_gt(_layout.canopy_groups().size(), 2, "the front and both sides")
	for g in _layout.canopy_groups():
		assert_true(g["band"])

func test_the_starter_has_no_band():
	var starter := ShipLibrary.load_from_dir().grid(&"starter")
	var l := InteriorLayout.plan(starter, _cat, DeckGraph.build(starter, _cat).walkable_coords())
	for g in l.canopy_groups():
		assert_false(g["band"])

func _dressed() -> Node3D:
	var body := StaticBody3D.new()
	add_child_autofree(body)
	var root := InteriorDressing.build(_layout, body, null)
	add_child_autofree(root)
	return root

func test_a_pane_on_every_canopy_face():
	var faces := 0
	for g in _layout.canopy_groups():
		faces += (g["coords"] as Array).size()
	var root := _dressed()
	assert_eq(root.find_children("BandPane_*", "", true, false).size(), faces)
	assert_null(root.find_child("CockpitPod", true, false), "no pod")

func test_the_lights_panel_is_on_the_helm_desk():
	var root := _dressed()
	var panels := root.find_children("LightsPanel_*", "LightsPanel", true, false)
	assert_eq(panels.size(), 1)
	var helm := InteriorDressing.fixture_frame(_layout, Vector3i(0, 0, -4))
	var expect := helm * InteriorProps.helm_panel_frame()
	assert_almost_eq((panels[0] as Node3D).transform.origin, expect.origin, Vector3.ONE * 0.001)
```

(`InteriorDressing.build`'s signature is `build(layout, body, canopy_material, wear_at := Callable(), flicker_at := Callable())`; read it and match it if it differs, ledgering any change.)

- [ ] **Step 2: Run to watch them fail**

Expected: FAIL on `g["band"]` (no key) and the pane count; a parse error for `helm_panel_frame` first: add `static func helm_panel_frame() -> Transform3D: return Transform3D.IDENTITY` to `InteriorProps` to see the assertion failures, then continue.

- [ ] **Step 3: Groups get a band**

In `InteriorLayout.plan`, the group record is made with `"band": false`:

```gdscript
				groups.get_or_add(key, {"normal": normal, "coords": [], "pods": [], "band": false})["coords"].append(coord)
```

and after `layout._mark_pods()`:

```gdscript
	layout._mark_bands()
```

with

```gdscript
## A ship flown from a bridge helm glazes every canopy group as one band
## (ship bridge spec §4.1); a pod ship keeps its pod, shoulders and nose.
func _mark_bands() -> void:
	for fixture in _fixtures:
		if fixture["id"] == BRIDGE_HELM:
			for group in _groups:
				group["band"] = true
			return
```

`canopy_groups()`'s comment gains "and `band`".

- [ ] **Step 4: The pane**

In `interior_props.gd`, beside the shoulder constants:

```gdscript
## A bridge's band of glass (ship bridge spec §4.2): one pane per canopy face,
## from the sill to its top, between posts at the cell edges.
const BAND_SILL := 0.85
const BAND_TOP := 2.3
const BAND_POST := 0.08
```

and after `shoulder()`:

```gdscript
## One pane of a bridge's band, in a wall frame (origin on the floor at the
## face's centre, +z into the room): the wall under the sill and over the top,
## the glass between half-posts at both cell edges, a sill ledge with a lit
## strip, and the wall's trim. A row of these reads as one strip of glass.
static func band_pane(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var wall := _c(InteriorPalette.WALL)
	var trim := _c(InteriorPalette.TRIM)
	var back := -WALL_THICKNESS * 0.5
	var n := (f.basis * Vector3.BACK).normalized()
	var half := BAY * 0.5
	var w := half - BAND_POST
	for band: Vector2 in [Vector2(0.0, BAND_SILL), Vector2(BAND_TOP, HEADROOM)]:
		kit.quad(SOLID, f * Vector3(-half, band.x, back), f * Vector3(half, band.x, back),
			f * Vector3(half, band.y, back), f * Vector3(-half, band.y, back), n, wall)
	kit.quad(PORTAL, f * Vector3(-w, BAND_SILL, back), f * Vector3(w, BAND_SILL, back),
		f * Vector3(w, BAND_TOP, back), f * Vector3(-w, BAND_TOP, back), n, _c(InteriorPalette.GLASS))
	var tall := BAND_TOP - BAND_SILL
	for x in [-half + BAND_POST * 0.5, half - BAND_POST * 0.5]:
		kit.bevel_box(SOLID, f * _at(Vector3(x, (BAND_SILL + BAND_TOP) * 0.5, 0.0)),
			Vector3(BAND_POST, tall + 0.1, 0.12), 0.02, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(0, BAND_SILL - 0.03, 0.1)), Vector3(BAY, 0.06, 0.24), 0.02, trim)
	kit.box(GLOW, f * _at(Vector3(0, BAND_SILL - 0.07, 0.22)), Vector3(BAY - 0.2, 0.02, 0.02),
		_lit(InteriorPalette.LIGHT_WARM, 1.6))
	kit.bevel_box(SOLID, f * _at(Vector3(0, BAND_TOP + 0.04, 0.03)), Vector3(BAY, 0.08, 0.1), 0.02, trim)
	wall_trim(kit, f)

## Where a band ship's lights panel stands, in the helm's fixture frame: on the
## desk's starboard wing, tilted up toward the pilot.
static func helm_panel_frame() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-60.0)), Vector3(0.72, 0.8, -0.62))
```

(Replace the Step 2 stub with this one.)

- [ ] **Step 5: Dress the bands**

In `InteriorDressing.build`, the canopy loop becomes:

```gdscript
	for group in layout.canopy_groups():
		var pods: Array = group["pods"]
		if group["band"]:
			_band(kit, group)
		elif pods.is_empty():
			_nose(kit, group, canopy_material)
		else:
			_cockpit(kit, layout, group)
	for fixture in layout.fixtures():
		if fixture["id"] == InteriorLayout.BRIDGE_HELM:
			_helm_lights_panel(kit, layout, fixture["coord"])
```

with

```gdscript
## A bridge's band (ship bridge spec §4.2): a pane on every face of the group,
## each with a BandPane marker for tests.
static func _band(kit: InteriorKit, group: Dictionary) -> void:
	var normal: Vector3i = group["normal"]
	for coord: Vector3i in group["coords"]:
		InteriorProps.band_pane(kit, wall_frame(coord, normal), face_variety({"coord": coord, "normal": normal}))
		var marker := Node3D.new()
		marker.name = "BandPane_%d_%d_%d_%d" % [coord.x, coord.y, coord.z, normal.x * 3 + normal.z]
		marker.transform = wall_frame(coord, normal)
		kit.root.add_child(marker)

## A band ship's lights panel, on its helm's desk (there are no shoulders).
static func _helm_lights_panel(kit: InteriorKit, layout: InteriorLayout, coord: Vector3i) -> void:
	var f := fixture_frame(layout, coord) * InteriorProps.helm_panel_frame()
	InteriorProps.lights_panel(kit, f)
	var panel := LightsPanel.new()
	panel.name = "LightsPanel_%d_%d_%d" % [coord.x, coord.y, coord.z]
	panel.cell = coord
	panel.transform = f
	panel.setup(kit.layer)
	kit.root.add_child(panel)
```

(A marker name must be unique: a corner cell can carry a front and a side pane, so the normal is in it.)

- [ ] **Step 6: Run, watch them pass, and the dressing's own tests**

Run: `test_bridge_layout.gd` (13/13), `test_interior_dressing.gd`, `test_interior_props.gd`, `test_lights_panel.gd` (each that exists).
Expected: all pass, the starter's unchanged.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src who-knows/test/unit/test_bridge_layout.gd
git commit -m "feat: a helm ship's canopies are one band of tall glass, its lights panel on the helm desk"
```

---

### Task 4: The band, outside

**Files:**
- Modify: `who-knows/src/ship/hull/hull_layout.gd:106-118`
- Test: `who-knows/test/unit/test_bridge_layout.gd`

**Interfaces:**
- Consumes: Task 3's `band` and `BAND_*`.
- Produces: one `windows` record per band pane, on its canopy cell's outer face.

- [ ] **Step 1: The failing test**

```gdscript
func test_every_pane_has_its_window_outside():
	var hull := HullLayout.plan(_grid, _cat, _layout)
	assert_eq(hull.unmatched, [] as Array[Dictionary], "no pane without glass outside")
	var faces := 0
	for g in _layout.canopy_groups():
		faces += (g["coords"] as Array).size()
	var on_canopies := 0
	for w in hull.windows:
		var c: Vector3i = w["coord"]
		if _grid.has_block(c) and _grid.get_block(c).block_id == &"canopy":
			on_canopies += 1
	assert_eq(on_canopies, faces)
```

- [ ] **Step 2: Run to watch it fail**

Expected: FAIL: the bands are drawn as noses' windows (three per group), so the count differs.

- [ ] **Step 3: Band windows**

In `HullLayout.plan`'s canopy loop, first in the loop body:

```gdscript
		if group.get("band", false):
			for coord: Vector3i in group["coords"]:
				wanted += 1
				_window_on(coord + normal, coord, normal, InteriorProps.BAND_SILL, InteriorProps.BAND_TOP,
					InteriorProps.BAY - 2.0 * InteriorProps.BAND_POST, false, 0.0)
			continue
```

- [ ] **Step 4: Run, watch it pass, and the hull's tests**

Run: `test_bridge_layout.gd` (14/14), `test_hull_layout.gd`, `test_exterior_builder.gd` (each that exists).
Expected: all pass. If `unmatched` is not empty, a side canopy's slope faces the wrong way: check `C8`/`C12` against `HullShapes` (`hull_wedge`'s orientation rules, reference.md); fix the fixture's orientation, not the code, and ledger it.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/hull/hull_layout.gd who-knows/test/unit/test_bridge_layout.gd
git commit -m "feat: every band pane has its window outside"
```

---

### Task 5: The dais and the new props

**Files:**
- Modify: `who-knows/src/ship/interior/interior_props.gd` (`DAIS_*`, `captain_dais`, `captain_chair`, `crew_station`), `interior_dressing.gd` (`draws_fixture`, `_fixture`, `fixture_frame`)
- Test: `who-knows/test/unit/test_bridge_layout.gd`

**Interfaces:**
- Consumes: Task 2's `SEAT_IDS`, `_fixture_id`.
- Produces: `InteriorProps.DAIS_HEIGHT := 0.25`, `DAIS_RAMP := 0.5`, `CAPTAIN_FORWARD := 0.25`; `fixture_frame` of a captain's chair raised by `DAIS_HEIGHT` and moved `CAPTAIN_FORWARD` toward its facing; `InteriorDressing.floor_frame(layout, coord)` (the fixture's cell floor centre, facing as it does).

- [ ] **Step 1: The failing tests**

```gdscript
func test_the_captain_sits_on_the_dais():
	var f := InteriorDressing.fixture_frame(_layout, Vector3i(0, 0, -2))
	assert_almost_eq(f.origin.y, InteriorDressing.floor_y(Vector3i(0, 0, -2)) + InteriorProps.DAIS_HEIGHT, 0.001)

func test_the_dais_and_its_ramp_are_solid_where_drawn():
	var body := StaticBody3D.new()
	add_child_autofree(body)
	add_child_autofree(InteriorDressing.build(_layout, body, null))
	await wait_physics_frames(2)
	var floor_at := InteriorDressing.floor_frame(_layout, Vector3i(0, 0, -2))
	var space := body.get_world_3d().direct_space_state
	var top := floor_at * Vector3(0, 0, -0.3)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top + Vector3.UP, top + Vector3.DOWN))
	assert_almost_eq(float(hit.get("position", Vector3.ZERO).y), floor_at.origin.y + InteriorProps.DAIS_HEIGHT, 0.03)
	var ramp := floor_at * Vector3(0, 0, 1.0 - InteriorProps.DAIS_RAMP * 0.5)
	hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(ramp + Vector3.UP, ramp + Vector3.DOWN))
	assert_almost_eq(float(hit.get("position", Vector3.ZERO).y), floor_at.origin.y + InteriorProps.DAIS_HEIGHT * 0.5, 0.04)
```

- [ ] **Step 2: Run to watch them fail**

Expected: a parse error (`DAIS_HEIGHT`, `floor_frame`); add the constants and `floor_frame` (Step 3's first two pieces) and run again: both FAIL (the chair is at floor height; no dais collider).

- [ ] **Step 3: The frames**

`interior_props.gd`:

```gdscript
## The captain's dais (ship bridge spec §5.1): a platform over its cell, a ramp
## across its back edge (27 degrees, under the avatar's 45), and the chair
## CAPTAIN_FORWARD forward of the cell's centre, on the flat.
const DAIS_HEIGHT := 0.25
const DAIS_RAMP := 0.5
const CAPTAIN_FORWARD := 0.25
```

`interior_dressing.gd`:

```gdscript
## A fixture's cell floor centre, facing as the fixture does.
static func floor_frame(layout: InteriorLayout, coord: Vector3i) -> Transform3D:
	var facing := Vector3i(0, 0, -1)
	for fixture in layout.fixtures():
		if fixture["coord"] == coord:
			facing = _upright_facing(fixture["orientation"])
	var origin := ShipGrid.cell_center(coord)
	origin.y = floor_y(coord)
	return Transform3D(Basis.looking_at(Vector3(facing), Vector3.UP), origin)
```

and in `fixture_frame`, beside the bridge-helm branch:

```gdscript
	elif id == &"captain_chair":
		origin += Vector3(facing) * InteriorProps.CAPTAIN_FORWARD + Vector3.UP * InteriorProps.DAIS_HEIGHT
```

- [ ] **Step 4: The props**

`interior_props.gd`, after `pilot_station`:

```gdscript
## The captain's dais in its cell's floor frame (-z the way the chair faces):
## the platform, a rail on the front and both flanks, the ramp across the back,
## a lit strip round its foot. Its colliders are the platform, the ramp and the
## rails.
static func captain_dais(kit: InteriorKit, f: Transform3D) -> void:
	var trim := _c(InteriorPalette.TRIM)
	var low := _c(InteriorPalette.WALL_LOW)
	var flat := BAY - DAIS_RAMP
	var flat_centre := Vector3(0, DAIS_HEIGHT * 0.5, -DAIS_RAMP * 0.5)
	kit.bevel_box(SOLID, f * _at(flat_centre), Vector3(BAY, DAIS_HEIGHT, flat), 0.03, low)
	kit.collider(f * _at(flat_centre), Vector3(BAY, DAIS_HEIGHT, flat))
	var slope := atan2(DAIS_HEIGHT, DAIS_RAMP)
	var length := sqrt(DAIS_HEIGHT * DAIS_HEIGHT + DAIS_RAMP * DAIS_RAMP)
	# Turned about +x by +slope, the ramp's +z (back) end goes down to the floor
	# and its -z end meets the platform.
	var ramp := f * Transform3D(Basis(Vector3.RIGHT, slope), Vector3(0, DAIS_HEIGHT * 0.5, BAY * 0.5 - DAIS_RAMP * 0.5))
	kit.bevel_box(SOLID, ramp * _at(Vector3(0, -0.025, 0)), Vector3(BAY, 0.05, length), 0.01, low)
	kit.collider(ramp * _at(Vector3(0, -0.025, 0)), Vector3(BAY, 0.05, length))
	kit.box(GLOW, f * _at(Vector3(0, 0.02, -BAY * 0.5 + 0.02)), Vector3(BAY - 0.1, 0.02, 0.02),
		_lit(InteriorPalette.LIGHT_WARM, 1.8))
	var rail_y := DAIS_HEIGHT + 0.9
	var rails: Array[Array] = [
		[Vector3(0, rail_y, -BAY * 0.5 + 0.06), Vector3(BAY, 0.06, 0.06)],
		[Vector3(-BAY * 0.5 + 0.06, rail_y, -DAIS_RAMP * 0.5), Vector3(0.06, 0.06, flat)],
		[Vector3(BAY * 0.5 - 0.06, rail_y, -DAIS_RAMP * 0.5), Vector3(0.06, 0.06, flat)],
	]
	for r in rails:
		kit.bevel_box(SOLID, f * _at(r[0]), r[1], 0.02, trim)
		kit.collider(f * _at(Vector3(r[0].x, DAIS_HEIGHT + 0.45, r[0].z)), Vector3(r[1].x, 0.9, r[1].z))
	for post: Vector3 in [Vector3(-0.9, 0, -0.94), Vector3(0.9, 0, -0.94), Vector3(-0.94, 0, 0.2), Vector3(0.94, 0, 0.2)]:
		kit.tube_between(SOLID, f * Vector3(post.x, DAIS_HEIGHT, post.z), f * Vector3(post.x, rail_y, post.z), 0.025, trim)

## The captain's chair in its fixture frame (on the dais): the pilot's chair
## made bigger and plainer, armrest pads but no stick or throttle, and no
## console ahead: the captain looks over the front row.
static func captain_chair(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var trim := _c(InteriorPalette.TRIM)
	var low := _c(InteriorPalette.WALL_LOW)
	var seat := _c(InteriorPalette.SEAT)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.06, 0.25)), Vector3(0.8, 0.1, 0.8), 0.04, trim)
	kit.tube_between(SOLID, f * Vector3(0, 0.1, 0.25), f * Vector3(0, 0.34, 0.25), 0.11, low)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.37, 0.26)), Vector3(0.84, 0.08, 0.72), 0.03, low)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.48, 0.25)), Vector3(0.76, 0.16, 0.66), 0.07, seat)
	var back := f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10.0)), Vector3(0, 1.0, 0.7))
	kit.bevel_box(SOLID, back * _at(Vector3(0, 0, 0.06)), Vector3(0.82, 1.0, 0.1), 0.04, low)
	kit.bevel_box(SOLID, back, Vector3(0.74, 0.94, 0.14), 0.07, seat)
	kit.bevel_box(SOLID, back * _at(Vector3(0, 0.58, 0.0)), Vector3(0.5, 0.22, 0.15), 0.07, seat)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.47
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.55, 0.4)), Vector3(0.1, 0.34, 0.1), 0.02, low)
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.74, 0.18)), Vector3(0.16, 0.09, 0.64), 0.04, trim)
		var pad := f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)), Vector3(x, 0.79, -0.04))
		kit.bevel_box(SOLID, pad, Vector3(0.16, 0.03, 0.2), 0.01, _c(InteriorPalette.SCREEN_BACK))
		kit.screen(pad * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.016, 0.02)),
			Vector2(0.12, 0.09), InteriorKit.Screen.DOTS, fposmod(variety + side * 0.3, 1.0))

## A crew station in its fixture frame: a seat like the pilot's without stick
## or throttle, at a console ahead with two screens and lit buttons, all for
## show until a job takes them (ship bridge spec §3.3).
static func crew_station(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var trim := _c(InteriorPalette.TRIM)
	var low := _c(InteriorPalette.WALL_LOW)
	var seat := _c(InteriorPalette.SEAT)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.06, 0.25)), Vector3(0.56, 0.1, 0.56), 0.04, trim)
	kit.tube_between(SOLID, f * Vector3(0, 0.1, 0.25), f * Vector3(0, 0.34, 0.25), 0.08, low)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.46, 0.25)), Vector3(0.58, 0.14, 0.54), 0.06, seat)
	var back := f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(0, 0.9, 0.62))
	kit.bevel_box(SOLID, back, Vector3(0.56, 0.72, 0.12), 0.06, seat)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.36, -0.72)), Vector3(1.3, 0.56, 0.3), 0.05, trim)
	var face := f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-55.0)), Vector3(0, 0.7, -0.64))
	kit.bevel_box(SOLID, face, Vector3(1.3, 0.3, 0.05), 0.02, trim)
	kit.bevel_box(SOLID, face * _at(Vector3(0, 0, 0.03)), Vector3(1.2, 0.24, 0.012), 0.005,
		_c(InteriorPalette.SCREEN_BACK))
	var first := int(variety * 3.0)
	kit.screen(face * _at(Vector3(-0.3, 0, 0.038)), Vector2(0.52, 0.19), _mode(first), variety)
	kit.screen(face * _at(Vector3(0.3, 0, 0.038)), Vector2(0.52, 0.19), _mode(first + 2),
		fposmod(variety + 0.37, 1.0))
	for i in 4:
		kit.bevel_box(GLOW, f * _at(Vector3(-0.27 + i * 0.18, 0.5, -0.565)), Vector3(0.08, 0.05, 0.02), 0.008,
			_lit([InteriorPalette.SKY, InteriorPalette.AMBER, InteriorPalette.LIGHT_WARM, InteriorPalette.CORAL][i], 1.6))
	kit.collider(f * _at(Vector3(0, 0.4, -0.72)), Vector3(1.3, 0.8, 0.3))
```

`interior_dressing.gd`: `draws_fixture` returns true for `InteriorLayout.SEAT_IDS` too:

```gdscript
	return InteriorLayout.HELM_IDS.has(id) or InteriorLayout.SEAT_IDS.has(id) \
		or id in [QUANTUM_CORE_ID, QUANTUM_MACHINE_ID, InteriorLayout.COMPUTER_ID]
```

and `_fixture` gains, before `elif fixture["id"] == QUANTUM_CORE_ID:`:

```gdscript
	elif fixture["id"] == &"captain_chair":
		InteriorProps.captain_dais(kit, floor_frame(layout, coord))
		InteriorProps.captain_chair(kit, fixture_frame(layout, coord), variety)
	elif fixture["id"] == &"crew_station":
		InteriorProps.crew_station(kit, fixture_frame(layout, coord), variety)
```

- [ ] **Step 5: Run, watch them pass, and the props' own rules**

Run: `test_bridge_layout.gd` (16/16), `test_interior_props.gd`, `test_visual_style_rules.gd`.
Expected: all pass (`test_visual_style_rules.gd` holds palettes and the shader budget: the new props use only `InteriorPalette` and the kit's slots).

- [ ] **Step 6: Commit**

```bash
git add who-knows/src who-knows/test/unit/test_bridge_layout.gd
git commit -m "feat: the captain's dais and chair, and the crew station, drawn at their frames"
```

---

### Task 6: Seats

**Files:**
- Create: `who-knows/src/avatar/seat.gd`, `seat_job.gd`, `captain_chair_seat.gd`, `crew_station_seat.gd`
- Modify: `who-knows/src/avatar/pilot_seat.gd`
- Test: `who-knows/test/unit/test_seat.gd`

**Interfaces:**
- Produces: `class_name Seat extends StaticBody3D` with `const STAND_SPOTS: Array[Vector3]`, `var flies := false`, `var cell := Vector3i.ZERO`, `var job: SeatJob`, `var director: CameraDirector`, `var eye: Node3D`, `func prompt_text() -> String`, `func stand_spot(avatar: Avatar) -> Transform3D`, `func interact(avatar: Avatar)`, `func sat(avatar: Avatar)`, `func stood(avatar: Avatar)`, `static func build(script: GDScript, frame: Transform3D, coord: Vector3i) -> Seat`; `class_name SeatJob extends Node` with `func sat(avatar: Avatar)`, `func stood(avatar: Avatar)`; `class_name CaptainChair extends Seat`, `class_name CrewStation extends Seat`; `PilotSeat extends Seat` with `flies = true`.

- [ ] **Step 1: The failing tests**

Create `who-knows/test/unit/test_seat.gd`:

```gdscript
extends GutTest

## Seats (docs/superpowers/specs/2026-10-09-ship-bridge-design.md §3.2-§3.3):
## what every seat shares, which one flies, and the job slot.

class RecordingJob extends SeatJob:
	var calls: Array[String] = []
	func sat(_avatar: Avatar) -> void:
		calls.append("sat")
	func stood(_avatar: Avatar) -> void:
		calls.append("stood")

func test_only_the_pilot_seat_flies():
	assert_true(PilotSeat.new().flies)
	var chair := CaptainChair.new()
	var station := CrewStation.new()
	assert_false(chair.flies)
	assert_false(station.flies)
	for s in [chair, station]:
		s.free()

func test_every_seat_is_a_seat():
	for s: Node in [PilotSeat.new(), CaptainChair.new(), CrewStation.new()]:
		assert_true(s is Seat)
		s.free()

func test_the_stand_spots_are_shared():
	assert_eq(PilotSeat.STAND_SPOTS, Seat.STAND_SPOTS)
	assert_eq(Seat.STAND_SPOTS[0], Vector3(0, 0, 1.3))

func test_each_says_what_sitting_there_is():
	var seats: Array[Seat] = [PilotSeat.new(), CaptainChair.new(), CrewStation.new()]
	assert_eq(seats[0].prompt_text(), "Take the controls")
	assert_eq(seats[1].prompt_text(), "Take the captain's chair")
	assert_eq(seats[2].prompt_text(), "Sit at the station")
	for s in seats:
		s.free()

func test_a_built_seat_has_an_eye_a_box_and_its_cell():
	var s := Seat.build(CrewStation, Transform3D(Basis.IDENTITY, Vector3(1, 2, 3)), Vector3i(4, 0, -2))
	add_child_autofree(s)
	assert_eq(s.cell, Vector3i(4, 0, -2))
	assert_almost_eq(s.position, Vector3(1, 2, 3), Vector3.ONE * 0.001)
	assert_not_null(s.eye)
	assert_almost_eq(s.eye.position, InteriorProps.SEATED_EYE, Vector3.ONE * 0.001)
	assert_eq(s.find_children("*", "CollisionShape3D").size(), 1)
	assert_eq(s.collision_layer, 2)
	assert_true(s.is_in_group("interactable"))

func test_a_job_hears_sitting_and_standing():
	var s := CrewStation.new()
	var job := RecordingJob.new()
	s.job = job
	s.sat(null)
	s.stood(null)
	assert_eq(job.calls, ["sat", "stood"] as Array[String])
	job.free()
	s.free()

func test_no_job_is_fine():
	var s := CaptainChair.new()
	s.sat(null)
	s.stood(null)
	assert_null(s.job)
	s.free()
```

- [ ] **Step 2: Run to watch them fail**

Expected: a parse error (`SeatJob`, `CaptainChair` not declared).

- [ ] **Step 3: The classes**

`who-knows/src/avatar/seat_job.gd`:

```gdscript
class_name SeatJob
extends Node

## What a seat that does not fly is for (ship bridge spec §3.3): weapon
## controls, damage control. Nothing makes one yet; a seat with one tells it
## when someone sits and stands, and a job may own the console's screens.

func sat(_avatar: Avatar) -> void:
	pass

func stood(_avatar: Avatar) -> void:
	pass
```

`who-knows/src/avatar/seat.gd`:

```gdscript
class_name Seat
extends StaticBody3D

## Anything you sit in (ship bridge spec §3.2): its eye, where you stand up
## to, the prompt, and the hand-off to the camera director. Only a seat that
## flies (PilotSeat) takes the ship's controls; the others are for looking
## round from, and for a job one day (SeatJob).

## Where you stand up to, in the seat's frame (its fixture frame: origin on
## the floor under it, -z the way it faces), best first: a step straight back
## out of the chair, clear of its backrest; back to either side; beside it; a
## longer step back.
const STAND_SPOTS: Array[Vector3] = [
	Vector3(0, 0, 1.3), Vector3(0.75, 0, 1.3), Vector3(-0.75, 0, 1.3),
	Vector3(1.1, 0, 0.3), Vector3(-1.1, 0, 0.3), Vector3(0, 0, 1.9),
]
## The box you look at to sit, in the seat's frame.
const BOX_SIZE := Vector3(1.0, 1.4, 1.0)
const BOX_AT := Vector3(0, 0.7, 0.2)

var flies := false
## The seat's block, so a save can find it again.
var cell := Vector3i.ZERO
## What the seat is for, or null (spec §3.3).
var job: SeatJob
## The game's one camera director, handed over by the flight scene, or found
## by its group when a ship builds the seat later.
var director: CameraDirector
## Where the seated camera ends up, and which way it faces.
var eye: Node3D

func _ready() -> void:
	add_to_group("interactable")
	if eye == null:
		eye = get_node_or_null("Eye")

func prompt_text() -> String:
	return "Sit down"

## Where `avatar` gets up to: the first of STAND_SPOTS it fits at, facing the
## way the seat does -- or, with none clear, where it stands now, the spot it
## sat down from, so it is never left wedged against the chair or the glass.
func stand_spot(avatar: Avatar) -> Transform3D:
	var facing := global_basis.orthonormalized()
	for spot in STAND_SPOTS:
		var pose := Transform3D(facing, to_global(spot))
		if avatar.can_stand_at(pose):
			return pose
	return avatar.global_transform

func interact(_avatar: Avatar) -> void:
	var d := director
	if d == null and is_inside_tree():
		d = get_tree().get_first_node_in_group(CameraDirector.GROUP) as CameraDirector
	if d != null:
		d.sit(self)

## Someone sat down here (the director calls it).
func sat(avatar: Avatar) -> void:
	if job != null:
		job.sat(avatar)

## Someone stood up from here.
func stood(avatar: Avatar) -> void:
	if job != null:
		job.stood(avatar)

## A seat of `script` at `frame` for block `coord`, as a ship builds one: its
## box on the interactable layer (2) and its eye at InteriorProps.SEATED_EYE.
static func build(script: GDScript, frame: Transform3D, coord: Vector3i) -> Seat:
	var s: Seat = script.new()
	s.name = "Seat_%d_%d_%d" % [coord.x, coord.y, coord.z]
	s.transform = frame
	s.cell = coord
	s.collision_layer = 2
	s.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BOX_SIZE
	shape.shape = box
	shape.position = BOX_AT
	s.add_child(shape)
	var e := Node3D.new()
	e.name = "Eye"
	e.position = InteriorProps.SEATED_EYE
	s.add_child(e)
	s.eye = e
	return s
```

`captain_chair_seat.gd`:

```gdscript
class_name CaptainChair
extends Seat

## The captain's chair on its dais (ship bridge spec §3.1): sat in, looked
## round from, never flown from.

func prompt_text() -> String:
	return "Take the captain's chair"
```

`crew_station_seat.gd`:

```gdscript
class_name CrewStation
extends Seat

## A crew station (ship bridge spec §3.1): sat in and looked round from; its
## console is decoration until a job takes it (SeatJob).

func prompt_text() -> String:
	return "Sit at the station"
```

`pilot_seat.gd` becomes:

```gdscript
class_name PilotSeat
extends Seat

## The flight station. Sitting here hands ship control to the pilot and
## moves the camera into the cockpit without a cut. The ship's one seat that
## flies (ship bridge spec §3.4), at a pilot seat's pod or a bridge's helm.

func _init() -> void:
	flies = true

func prompt_text() -> String:
	return "Take the controls"
```

- [ ] **Step 4: Import, run, watch them pass, and the seat's old tests**

Run: `godot --headless --path . --import`, then `test_seat.gd` (7/7), `test_pilot_seat.gd`, `test_avatar_modes.gd`, `test_pilot_controls.gd`.
Expected: all pass. `CameraDirector.sit` still takes a `PilotSeat` until Task 8, and every caller passes one.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/avatar who-knows/test/unit/test_seat.gd who-knows/test/unit/test_seat.gd.uid
git commit -m "feat: Seat -- the pilot seat, the captain's chair and the crew station share sitting and standing; only the pilot seat flies"
```

---

### Task 7: The ship builds every seat

**Files:**
- Modify: `who-knows/src/ship/ship.gd` (`_place_seat`, `seats()`, `seat_at()`)
- Test: `who-knows/test/unit/test_bridge_seats.gd` (new)

**Interfaces:**
- Consumes: Task 6's `Seat.build`, `CaptainChair`, `CrewStation`; `flight_test.starter_ship` (ship designer project).
- Produces: `Ship.seats() -> Array[Seat]` (the pilot seat first, then the others in fixture order); `Ship.seat_at(coord: Vector3i) -> Seat` (or null); `Ship.seat.cell` set to the helm.

- [ ] **Step 1: The failing tests**

Create `who-knows/test/unit/test_bridge_seats.gd`:

```gdscript
extends GutTest

## The bridge fixture's seats in the real flight scene
## (docs/superpowers/specs/2026-10-09-ship-bridge-design.md §3.2-§3.4): one
## seat node per chair and station, sitting in each, only the helm piloting.

const BRIDGE := "res://test/fixtures/bridge/bridge.json"

var _root: Node
var _ship: Ship
var _director: CameraDirector
var _avatar: Avatar

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.starter_ship = BRIDGE
	add_child_autofree(_root)
	await wait_process_frames(2)
	_ship = _root.aboard
	_director = _root.get_node("CameraDirector")
	_avatar = _root.get_tree().get_first_node_in_group(Avatar.GROUP)

func after_each():
	for a in [&"move_forward", &"move_back", &"strafe_left", &"strafe_right"]:
		Input.action_release(a)

func test_a_seat_for_the_helm_and_every_chair():
	var seats := _ship.seats()
	assert_eq(seats.size(), 4)
	assert_same(seats[0], _ship.seat)
	assert_eq(_ship.seat.cell, Vector3i(0, 0, -4))
	assert_true(_ship.seat_at(Vector3i(0, 0, -2)) is CaptainChair)
	assert_true(_ship.seat_at(Vector3i(-2, 0, -4)) is CrewStation)
	assert_true(_ship.seat_at(Vector3i(2, 0, -4)) is CrewStation)
	assert_null(_ship.seat_at(Vector3i(1, 0, -3)))

func test_each_seat_stands_where_its_chair_is_drawn():
	var layout := _ship.interior_builder.layout()
	for s in _ship.seats():
		var f := InteriorDressing.fixture_frame(layout, s.cell)
		assert_almost_eq(s.transform.origin, f.origin, Vector3.ONE * 0.001, "seat at %s" % s.cell)

func test_a_rebuild_keeps_one_seat_each():
	_ship.set_grid(_ship.grid, false)
	await wait_process_frames(2)
	assert_eq(_ship.seats().size(), 4)
	assert_eq(_ship.interior.find_children("Seat_*", "", false, false).size(), 3, "the old seats are gone")
```

- [ ] **Step 2: Run to watch them fail**

Expected: a parse error (`seats`, `seat_at`).

- [ ] **Step 3: Build the seats**

In `ship.gd`, under `@onready var seat: PilotSeat = $Interior/PilotSeat`:

```gdscript
## The seats that do not fly, rebuilt with the interior (ship bridge spec §3.2).
var _crew_seats: Array[Seat] = []
```

and `_place_seat()` becomes:

```gdscript
## The helm's seat where the dressing drew the chair (cockpit pod spec §7): its
## collider and eye from the same fixture frame, after every rebuild, so a
## spawned ship's seat stands where the starter's does. Then one Seat for
## every captain's chair and crew station (ship bridge spec §3.2).
func _place_seat() -> void:
	var layout := interior_builder.layout()
	var helm: Variant = helm_cell()
	if helm != null and seat != null:
		seat.transform = InteriorDressing.fixture_frame(layout, helm)
		seat.cell = helm
	for s in _crew_seats:
		if is_instance_valid(s):
			s.get_parent().remove_child(s)
			s.queue_free()
	_crew_seats.clear()
	for f in layout.fixtures():
		var script: GDScript = null
		if f["id"] == &"captain_chair":
			script = CaptainChair
		elif f["id"] == &"crew_station":
			script = CrewStation
		if script == null:
			continue
		var s := Seat.build(script, InteriorDressing.fixture_frame(layout, f["coord"]), f["coord"])
		interior.add_child(s)
		_crew_seats.append(s)

## Every seat aboard, the one that flies first.
func seats() -> Array[Seat]:
	var out: Array[Seat] = []
	if seat != null:
		out.append(seat)
	for s in _crew_seats:
		if is_instance_valid(s):
			out.append(s)
	return out

## The seat at block `coord`, or null.
func seat_at(coord: Vector3i) -> Seat:
	for s in seats():
		if s.cell == coord:
			return s
	return null
```

(`interior` is the ship's `$Interior` node: check its member name in `ship.gd` and use it.)

- [ ] **Step 4: Run, watch them pass, and the ship's tests**

Run: `test_bridge_seats.gd` (3/3), `test_pilot_seat.gd`, `test_fleet.gd`, `test_ship_catalog.gd`.
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship.gd who-knows/test/unit/test_bridge_seats.gd who-knows/test/unit/test_bridge_seats.gd.uid
git commit -m "feat: a ship builds a seat for every captain's chair and crew station"
```

---

### Task 8: The director sits you in any seat

**Files:**
- Modify: `who-knows/src/camera/camera_director.gd` (`sit`, `sit_now`, `stand`, `stand_now`, `cycle_view`, `begin_orbit`, `_unhandled_input`, `look`, `seat()`, `piloting()`)
- Test: `who-knows/test/unit/test_bridge_seats.gd`

**Interfaces:**
- Consumes: Task 6's `Seat`, Task 7's `seats()`.
- Produces: `CameraDirector.sit(seat: Seat)`, `sit_now(seat: Seat)`, `seat() -> Seat` (null standing), `piloting() -> bool`, `look(relative: Vector2)`, `SEAT_LOOK_YAW`, `SEAT_LOOK_PITCH`, `SEAT_LOOK_SENSITIVITY`.

- [ ] **Step 1: The failing tests**

Append to `test_bridge_seats.gd`:

```gdscript
func _sit(s: Seat) -> void:
	_director.sit(s)
	await wait_for_signal(_director.transition_finished, 3)

func _stand() -> void:
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)

func test_sitting_at_a_station_is_not_piloting():
	watch_signals(_director)
	await _sit(_ship.seat_at(Vector3i(-2, 0, -4)))
	assert_true(_director.is_seated)
	assert_false(_director.piloting())
	assert_signal_not_emitted(_director, "piloting_changed")
	assert_false(_ship.pilot.seated, "the controls stay with nobody")
	assert_same(_director.seat(), _ship.seat_at(Vector3i(-2, 0, -4)))

func test_the_helm_still_pilots():
	watch_signals(_director)
	await _sit(_ship.seat)
	assert_true(_director.piloting())
	assert_signal_emitted_with_parameters(_director, "piloting_changed", [true])
	assert_true(_ship.pilot.seated)

func test_a_seat_that_does_not_fly_moves_nothing():
	await _sit(_ship.seat_at(Vector3i(0, 0, -2)))
	var at := _ship.exterior.global_position
	Input.action_press(&"move_forward")
	await wait_physics_frames(60)
	Input.action_release(&"move_forward")
	assert_almost_eq(_ship.exterior.global_position, at, Vector3.ONE * 0.05)

func test_you_look_round_within_limits():
	await _sit(_ship.seat_at(Vector3i(0, 0, -2)))
	var cam := _director.camera()
	_director.look(Vector2(-100000, 0))
	assert_almost_eq(cam.transform.basis.get_euler().y, CameraDirector.SEAT_LOOK_YAW, 0.01)
	_director.look(Vector2(0, -100000))
	assert_almost_eq(cam.transform.basis.get_euler().x, CameraDirector.SEAT_LOOK_PITCH, 0.01)

func test_looking_does_nothing_at_the_helm():
	await _sit(_ship.seat)
	var before := _director.camera().transform
	_director.look(Vector2(300, 200))
	assert_eq(_director.camera().transform, before)

func test_v_does_nothing_at_a_station():
	await _sit(_ship.seat_at(Vector3i(2, 0, -4)))
	_director.cycle_view()
	assert_eq(_director.view, CameraDirector.View.COCKPIT)

func test_you_stand_up_from_a_station():
	var s := _ship.seat_at(Vector3i(2, 0, -4))
	await _sit(s)
	await _stand()
	assert_false(_director.is_seated)
	assert_null(_director.seat())
	var local := s.global_transform.affine_inverse() * _avatar.global_position
	assert_almost_eq(local, Seat.STAND_SPOTS[0], Vector3.ONE * 0.05)

func test_f8_from_a_station_boards_the_other_helm():
	await _sit(_ship.seat_at(Vector3i(-2, 0, -4)))
	var other: Ship = _root.fleet.spawn(ShipLibrary.load_from_dir().grid(&"starter"),
		Transform3D(_ship.exterior.global_basis, _ship.exterior.global_position + Vector3(300, 0, 0)))
	await wait_physics_frames(2)
	assert_true(_root.board_nearest())
	assert_same(_director.seat(), other.seat)
	assert_true(_director.piloting())
```

- [ ] **Step 2: Run to watch them fail**

Expected: parse errors first (`piloting`, `seat`, `look`); then, with a stub of each, the station tests FAIL (`piloting_changed` emitted at a station).

- [ ] **Step 3: Any seat**

In `camera_director.gd`:

```gdscript
## At a seat that does not fly (ship bridge spec §3.2): how far you can turn
## your head from the way it faces, and how fast the mouse turns it.
const SEAT_LOOK_YAW := deg_to_rad(100.0)
const SEAT_LOOK_PITCH := deg_to_rad(60.0)
const SEAT_LOOK_SENSITIVITY := 0.003
```

`var _seat: PilotSeat = null` becomes `var _seat: Seat = null`, and add `var _look := Vector2.ZERO` beside it.

```gdscript
## The seat you sit in, or null.
func seat() -> Seat:
	return _seat if is_seated else null

## True while you sit in the seat that flies.
func piloting() -> bool:
	return is_seated and _seat != null and _seat.flies
```

`sit` and `sit_now` take `seat: Seat`. In both, after `is_seated = true`, add `_look = Vector2.ZERO`, and make the hand-over conditional: `piloting_changed.emit(true)` becomes `if seat.flies: piloting_changed.emit(true)`; add `seat.sat(_avatar)` as the last line of each.

`stand` and `stand_now`: replace `piloting_changed.emit(false)` and `_flight.clear_pilot_input()` with

```gdscript
	if _seat.flies:
		piloting_changed.emit(false)
		_flight.clear_pilot_input()
	_seat.stood(_avatar)
```

`cycle_view`: after `end_orbit()`, `if is_seated and not _seat.flies: return`. `begin_orbit`: `if not is_seated or not _seat.flies or is_orbiting or _tween != null:`.

```gdscript
## The mouse at a seat that does not fly: turns your head within
## SEAT_LOOK_YAW and SEAT_LOOK_PITCH of the seat's eye. Nothing at the helm,
## where the mouse is the stick.
func look(relative: Vector2) -> void:
	if not is_seated or _seat.flies or _tween != null:
		return
	_look.x = clampf(_look.x - relative.x * SEAT_LOOK_SENSITIVITY, -SEAT_LOOK_YAW, SEAT_LOOK_YAW)
	_look.y = clampf(_look.y - relative.y * SEAT_LOOK_SENSITIVITY, -SEAT_LOOK_PITCH, SEAT_LOOK_PITCH)
	_interior_cam.transform = Transform3D(Basis.from_euler(Vector3(_look.y, _look.x, 0.0)), Vector3.ZERO)
```

and in `_unhandled_input`, before `if event.is_action_pressed("cycle_camera"):`:

```gdscript
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look((event as InputEventMouseMotion).relative)
```

`_apply_view`'s `View.COCKPIT, View.FOOT_FIRST:` branch sets `position = Vector3.ZERO`, which leaves the look's rotation alone: keep it.

`seat_ship()` keeps returning the ship of any seat you sit in; `PilotControls` takes the stick only on `piloting_changed`, which a station never emits.

- [ ] **Step 4: Run, watch them pass, and every sitting test**

Run: `test_bridge_seats.gd` (11/11), `test_pilot_seat.gd`, `test_pilot_controls.gd`, `test_avatar_modes.gd`, `test_hud_scene_wiring.gd`, `test_fleet.gd`, `test_computer_station.gd`, `test_camera_director.gd` (if it exists).
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/camera/camera_director.gd who-knows/test/unit/test_bridge_seats.gd
git commit -m "feat: sit in any seat -- look round from a chair or a station; only the helm hands over the controls"
```

---

### Task 9: The seat in the save

**Files:**
- Modify: `who-knows/scenes/flight_test.gd` (`_capture_you`, the seated restore)
- Test: `who-knows/test/unit/test_save_scene.gd`

**Interfaces:**
- Consumes: Task 7's `seat_at`, Task 8's `seat()`.
- Produces: the avatar part's `"seat"`: `SaveCodec.cell_key(cell)` while seated.

- [ ] **Step 1: The failing tests**

Append to `test_save_scene.gd` (its own scene helpers make and drop a saving scene; read the file and use them, the pattern of its existing seated test at line ~140):

```gdscript
func test_seated_at_a_station_comes_back_at_the_station():
	var a := _bridge_scene()
	await wait_process_frames(2)
	var station: Seat = a.aboard.seat_at(Vector3i(2, 0, -4))
	a.get_node("CameraDirector").sit_now(station)
	assert_true(a.save_now())
	_drop(a)
	var b := _bridge_scene()
	await wait_process_frames(2)
	var director: CameraDirector = b.get_node("CameraDirector")
	assert_true(director.is_seated)
	assert_eq(director.seat().cell, Vector3i(2, 0, -4))
	assert_false(director.piloting())
	_drop(b)

func test_a_seat_that_is_gone_seats_you_at_the_helm():
	var a := _bridge_scene()
	await wait_process_frames(2)
	a.get_node("CameraDirector").sit_now(a.aboard.seat_at(Vector3i(2, 0, -4)))
	assert_true(a.save_now())
	_drop(a)
	var saved := JSON.parse_string(FileAccess.get_file_as_string(PATH)) as Dictionary
	saved["avatar"]["seat"] = SaveCodec.cell_key(Vector3i(9, 9, 9))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(saved))
	f.close()
	var b := _bridge_scene()
	await wait_process_frames(2)
	var director: CameraDirector = b.get_node("CameraDirector")
	assert_same(director.seat(), b.aboard.seat)
	_drop(b)
```

with the helper (beside the file's own scene helper; `PATH` is the file's save path constant, under whatever name the file uses):

```gdscript
## A saving scene aboard the bridge fixture: saving kept on, with a path of
## the test's own, though starter_ship names another ship. A resumed game
## builds its ship from the save, so the second scene is the bridge again.
func _bridge_scene() -> Node:
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.starter_ship = "res://test/fixtures/bridge/bridge.json"
	root.keep_saving = true
	root.save_enabled = true
	root.save_path = PATH
	add_child(root)
	return root
```

`starter_ship` turns saving off in `_ready` (ship designer spec §7.2), before the save is read, so the scene needs a way for a test to keep it on. In `flight_test.gd`, under `starter_ship`:

```gdscript
## A test that saves aboard another ship sets this, with a save_path of its own
## (ship bridge spec §3.5): starter_ship then leaves saving as it is.
var keep_saving := false
```

and in `_ready`, `if starter_ship != String(ShipLibrary.STARTER):` becomes `if starter_ship != String(ShipLibrary.STARTER) and not keep_saving:`. `test_starter_ship.gd`'s `test_another_ship_turns_saving_off` still holds (it leaves `keep_saving` false); add beside it

```gdscript
func test_keep_saving_keeps_saving_on():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.save_enabled = true
	root.keep_saving = true
	root.save_path = SAVE
	root.starter_ship = BIG
	add_child_autofree(root)
	await wait_process_frames(2)
	assert_true(root.save_enabled)
```

and run `test_starter_ship.gd` with Step 4.

- [ ] **Step 2: Run to watch them fail**

Expected: FAIL: the second scene sits you at the helm (no `"seat"` in the save) in the first test.

- [ ] **Step 3: Save and restore the seat**

`_capture_you`, in the `else:` branch after `d["mode"] = ...`:

```gdscript
		if _director.is_seated:
			d["seat"] = SaveCodec.cell_key(_director.seat().cell)
```

and in the restore, `if mode == "seated": _director.sit_now(aboard.seat)` becomes:

```gdscript
	if mode == "seated":
		var seat: Seat = null
		if d.has("seat"):
			seat = aboard.seat_at(SaveCodec.to_cell(String(d["seat"])))
		_director.sit_now(seat if seat != null else aboard.seat)
```

- [ ] **Step 4: Run, watch them pass**

Run: `test_save_scene.gd`, `test_starter_ship.gd`.
Expected: all pass (17 + 2; 6 + 1).

- [ ] **Step 5: Commit**

```bash
git add who-knows/scenes/flight_test.gd who-knows/test/unit/test_save_scene.gd who-knows/test/unit/test_starter_ship.gd
git commit -m "feat: a save remembers the seat you sit in"
```

---

### Task 10: The bridge rules

**Files:**
- Modify: `who-knows/src/ship/ship_rules.gd` (`_check_cabin`, new `_check_seats`), `.claude/skills/building-a-ship/ship_check.gd` (nothing: it prints whatever rules break)
- Test: `who-knows/test/unit/test_ship_rules.gd`

**Interfaces:**
- Consumes: Tasks 2–7.
- Produces: rules `NO_HELM` (replaces `NO_POD`), `TWO_HELMS`, `NO_STAND` (every seat), `SEAT_FACES_WALL`, `DAIS_BLOCKED`, `UNREACHABLE` for seats.

- [ ] **Step 1: The failing tests**

Append to `test_ship_rules.gd` (it already breaks rules with copies of the starter; read its helpers and use them; here written against a local `_codes(grid)`):

```gdscript
const BRIDGE := "res://test/fixtures/bridge/bridge.json"

func _bridge() -> ShipGrid:
	return ShipLibrary.read(BRIDGE)["grid"]

func _codes_of(grid: ShipGrid) -> Array:
	var out := []
	for r in ShipRules.check(grid, BlockCatalog.load_from_dir("res://data/blocks"))["rules"]:
		out.append(r["code"])
	return out

func _set(grid: ShipGrid, c: Vector3i, id: StringName, o := 0) -> void:
	var inst := BlockInstance.new()
	inst.block_id = id
	inst.orientation = o
	grid.set_block(c, inst)

func test_the_bridge_fixture_breaks_no_rule():
	assert_eq(_codes_of(_bridge()), [])

func test_no_glass_ahead_of_the_helm_breaks_no_helm():
	var g := _bridge()
	_set(g, Vector3i(0, 0, -5), &"hull")
	assert_has(_codes_of(g), &"NO_HELM")

func test_two_helms_breaks_two_helms():
	var g := _bridge()
	_set(g, Vector3i(-1, 0, -4), &"pilot_seat")
	assert_has(_codes_of(g), &"TWO_HELMS")

func test_a_station_with_nowhere_to_stand_breaks_no_stand():
	var g := _bridge()
	for c in [Vector3i(-2, 0, -3), Vector3i(-1, 0, -4)]:
		_set(g, c, &"hull")
	assert_has(_codes_of(g), &"NO_STAND")

func test_a_chair_facing_a_wall_breaks_seat_faces_wall():
	var g := _bridge()
	_set(g, Vector3i(0, 0, -3), &"hull")
	assert_has(_codes_of(g), &"SEAT_FACES_WALL")

func test_a_blocked_ramp_breaks_dais_blocked():
	var g := _bridge()
	_set(g, Vector3i(0, 0, -1), &"hull")
	assert_has(_codes_of(g), &"DAIS_BLOCKED")

func test_the_starter_still_breaks_none():
	assert_eq(_codes_of(ShipLibrary.load_from_dir().grid(&"starter")), [])
```

(Each broken copy must break its own rule on the real fixture: if a copy breaks a different rule too, that is fine; if it does not break its own, change the copy, not the rule, and ledger it: the starter's lesson, building-a-ship *Mistakes already made*.)

- [ ] **Step 2: Run to watch them fail**

Expected: `test_the_bridge_fixture_breaks_no_rule` FAILS on `NO_POD`; the new codes are missing.

- [ ] **Step 3: The rules**

In `_check_cabin`, the pod check becomes:

```gdscript
	var helms := []
	for f in layout.fixtures():
		if InteriorLayout.HELM_IDS.has(f["id"]):
			helms.append(f)
	if helms.size() > 1:
		rules.append(item(&"TWO_HELMS", "%d seats fly this ship: a ship has one pilot seat or one helm" % helms.size(),
			helms[1]["coord"]))
	var sees := not layout.pods().is_empty()
	for f in helms:
		if f["id"] == InteriorLayout.BRIDGE_HELM:
			var ahead: Vector3i = f["coord"] + InteriorLayout.facing(f["orientation"])
			for face in layout.faces():
				if face["kind"] == InteriorLayout.Kind.CANOPY and face["coord"] == f["coord"] \
						and face["coord"] + face["normal"] == ahead:
					sees = true
	if not sees:
		rules.append(item(&"NO_HELM", "no pilot seat looks straight at a canopy (a pod), and no helm has a canopy face straight ahead (a bridge)"))
```

replacing the `NO_POD` lines; the helm loop below it (`if InteriorLayout.HELM_IDS.has(f["id"])`) stays. Then add, called from `check()` after `_check_cabin(layout, paths, rules)`:

```gdscript
## The seats that do not fly (ship bridge spec §6.1): somewhere to stand up
## to, not facing a wall, a dais you can walk onto, and reachable on foot.
static func _check_seats(grid: ShipGrid, layout: InteriorLayout, paths: DeckPaths, rules: Array) -> void:
	var reach := {}
	for lock in layout.airlocks():
		for n in InteriorLayout._HORIZONTAL:
			var c: Vector3i = lock["coord"] + n
			if paths.has(c):
				reach = paths.distances(c)
				break
		if not reach.is_empty():
			break
	for f in layout.fixtures():
		if not InteriorLayout.SEAT_IDS.has(f["id"]):
			continue
		var at: Vector3i = f["coord"]
		var facing := InteriorLayout.facing(f["orientation"])
		if stand_cell(at, facing, paths) == null:
			rules.append(item(&"NO_STAND", "nowhere to stand up from the %s: behind it and beside it is no open floor" % f["id"], at))
		var ahead := at + facing
		var at_glass := grid.has_block(ahead) and grid.get_block(ahead).block_id == InteriorLayout.CANOPY_ID
		if not at_glass and not paths.has(ahead):
			rules.append(item(&"SEAT_FACES_WALL", "the %s looks straight into %s" % [f["id"], ahead], at))
		if f["id"] == &"captain_chair" and not paths.has(at - facing):
			rules.append(item(&"DAIS_BLOCKED", "the captain's dais has no open floor behind its ramp", at))
		var beside := false
		for n in InteriorLayout._HORIZONTAL:
			if reach.has(at + n):
				beside = true
		if not reach.is_empty() and not beside:
			rules.append(item(&"UNREACHABLE", "the %s cannot be walked to from the airlock" % f["id"], at))
```

(`InteriorLayout._HORIZONTAL` is the layout's private constant: if GDScript refuses it from outside, copy the four directions into `ShipRules` as `_SIDES` and ledger it. `paths.distances(cell)` and `paths.has(cell)` are `DeckPaths`' as `ShipCrew` uses them.)

- [ ] **Step 4: Run, watch them pass, and the catalog and checker**

Run: `test_ship_rules.gd`, `test_ship_catalog.gd`, `test_big_ship.gd`; and `godot --headless --path . --script ..\.claude\skills\building-a-ship\ship_check.gd -- res://test/fixtures/bridge/bridge.json`.
Expected: all pass; `ship_check` prints `rules   0 broken`. If the fixture breaks a rule for its own reasons (power, balance), fix the plan (`bridge.plan`, then `to-json`) with the smallest change, ledgered.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship_rules.gd who-knows/test/unit/test_ship_rules.gd who-knows/test/fixtures/bridge
git commit -m "feat: the bridge rules -- NO_HELM, TWO_HELMS, every seat's NO_STAND, SEAT_FACES_WALL, DAIS_BLOCKED, seats reachable"
```

---

### Task 11: The bridge fixture proven

**Files:**
- Test: `who-knows/test/unit/test_bridge_ship.gd` (new)

**Interfaces:**
- Consumes: everything above; `test/unit/helpers/ship_use.gd`.

- [ ] **Step 1: The tests**

```gdscript
extends GutTest

## The bridge fixture (docs/superpowers/specs/2026-10-09-ship-bridge-design.md
## §7): no rule broken, usable as every ship is, and every seat sat in and
## stood up from, with somewhere to walk.

const ShipUse := preload("res://test/unit/helpers/ship_use.gd")
const BRIDGE := "res://test/fixtures/bridge/bridge.json"
const SAVE := "user://test_bridge_ship/game.json"

func after_each():
	for a in [&"move_forward", &"move_back"]:
		Input.action_release(a)
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)

func test_it_breaks_no_rule():
	var found := ShipRules.check(ShipLibrary.read(BRIDGE)["grid"], BlockCatalog.load_from_dir("res://data/blocks"))
	assert_eq(found["rules"], [])

func test_it_is_usable():
	await ShipUse.use(self, ShipLibrary.read(BRIDGE)["grid"], "Bridge test ship", SAVE, "bridge")

func test_you_stand_up_from_every_seat_and_walk():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.starter_ship = BRIDGE
	add_child_autofree(root)
	await wait_process_frames(2)
	var director: CameraDirector = root.get_node("CameraDirector")
	var avatar: Avatar = root.get_tree().get_first_node_in_group(Avatar.GROUP)
	for s: Seat in root.aboard.seats():
		director.sit(s)
		await wait_for_signal(director.transition_finished, 3)
		director.stand()
		await wait_for_signal(director.transition_finished, 3)
		await wait_physics_frames(10)
		assert_true(avatar.is_on_floor(), "standing from %s, on your feet" % s.cell)
		var from := avatar.global_position
		Input.action_press(&"move_back")
		await wait_physics_frames(45)
		Input.action_release(&"move_back")
		await wait_physics_frames(5)
		assert_gt(from.distance_to(avatar.global_position), 0.8, "and you can walk away from %s" % s.cell)
		avatar.place(root.aboard.interior.global_transform * root._deck_spot(root.aboard))
		await wait_physics_frames(5)
```

- [ ] **Step 2: Run**

Run: `./run_tests.ps1 '-gselect=test_bridge_ship.gd'`
Expected: 3/3. A failure here is a defect in Tasks 2–10 (a seat's frame, a stand spot in a rail, a dais collider): find it with superpowers:systematic-debugging; never loosen the test.

- [ ] **Step 3: Commit**

```bash
git add who-knows/test/unit/test_bridge_ship.gd who-knows/test/unit/test_bridge_ship.gd.uid
git commit -m "test: the bridge fixture -- no rule broken, usable, every seat sat in and stood up from"
```

---

### Task 12: The probe's seats, and the renders

**Files:**
- Modify: `.claude/skills/building-a-ship/ship_probe.gd` (`_seat_pass`, called after the walk)

**Interfaces:**
- Consumes: `Ship.seats()`, `CameraDirector.sit_now`, `stand_now`, `look`.

- [ ] **Step 1: The seat pass**

Add to `ship_probe.gd`:

```gdscript
## Every seat aboard (ship bridge spec §6.2): sat in, its view rendered, stood
## up from, and a step walked; and, on a ship with a captain's chair, the
## bridge from the dais at a standing eye. Prints a seats line.
func _seat_pass(scene: Node, ship: Ship, director: CameraDirector, avatar: Avatar) -> void:
	var seats := ship.seats()
	var counts := {}
	for s in seats:
		var kind := "helm" if s.flies else ("chair" if s is CaptainChair else "station")
		counts[kind] = int(counts.get(kind, 0)) + 1
	print("seats   %d: %s" % [seats.size(), counts])
	for s in seats:
		var tag := "%d_%d_%d" % [s.cell.x, s.cell.y, s.cell.z]
		director.sit_now(s)
		await _process_frames(5)
		await _shot("seat_%s" % tag)
		if not s.flies:
			director.look(Vector2(-500, 0))
			await _shot("seat_%s_left" % tag)
		director.stand_now()
		await _process_frames(10)
		var from := avatar.global_position
		Input.action_press("move_back")
		for i in 45:
			await physics_frame
		Input.action_release("move_back")
		var walked := from.distance_to(avatar.global_position)
		print("seat    %s at %s: stood and walked %.2f m%s" % [s.get_class() if s.get_script() == null else s.get_script().get_global_name(),
			s.cell, walked, "" if walked > 0.8 else "  <-- STUCK"])
	for s in seats:
		if s is CaptainChair:
			var dais := ship.interior.global_transform * InteriorDressing.floor_frame(ship.interior_builder.layout(), s.cell)
			avatar.place(Transform3D(dais.basis, dais * Vector3(0, InteriorProps.DAIS_HEIGHT, -0.5)))
			await _process_frames(10)
			await _shot("bridge_from_dais")
```

and call it in `_run`, after the `walked` line and before `await _panel_shots(ship, avatar)`:

```gdscript
	await _seat_pass(scene, ship, director, avatar)
```

- [ ] **Step 2: Probe the bridge fixture, windowed**

From `who-knows`: `godot --path . --resolution 1280x720 --script ..\.claude\skills\building-a-ship\ship_probe.gd -- <abs out dir> --ship res://test/fixtures/bridge/bridge.json`, logged.
Expected: `ship    probing bridge: Bridge test ship`; `rules   0 broken`; `seats   4: {helm: 1, station: 2, chair: 1}` (order may differ); no `<--`, `MISMATCH`, `MISSING`, `REFUSED`, `NOT FOUND`, `UNREACHABLE`, `SHADER ERROR`, `SCRIPT ERROR`; every `fps` line at least 120; `windows N outside for N inside`. Then probe the starter (`--ship starter`): the same as before this branch (its seats line `1: {helm: 1}`).

- [ ] **Step 3: Look, then show the owner**

Open `probe_seat_0_0_-4.png` (the helm), each station's view and its `_left`, the captain's chair's, `probe_bridge_from_dais.png`, `probe_hull_bow_port.png` and `probe_hull_profile.png`, and judge them against the style guide: warm and dim; the band reads as one strip of glass turning the corners; the dais and rail read; nothing floats or clips. Fix what does not (props are Task 3 and 5's), re-probe, and send the owner the set (SendUserFile) with the fps.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/building-a-ship/ship_probe.gd
git commit -m "feat: the probe sits in every seat, renders each view and the bridge from the dais"
```

---

### Task 13: Docs

**Files:**
- Modify: `.claude/skills/designing-a-ship/SKILL.md`, `.claude/skills/building-a-ship/SKILL.md`, `reference.md`, `.claude/agents/ship-designer.md`, `docs/superpowers/specs/2026-10-09-ship-bridge-design.md`

- [ ] **Step 1: designing-a-ship**

- the token table gains `Hm` helm, `Cc` captain_chair, `Cs` crew_station;
- a new section **Bridges** after §4: when (over about 150 blocks, a warship, anything with a crew); the drawing rule (spec §5.2); the bridge fixture's y=0 rows z −5..−1 as the worked example; the band (glass ahead of a `helm` and down the sides, `C8`/`C12` for side glass); the rules it must pass (`NO_HELM`, `TWO_HELMS`, `NO_STAND`, `SEAT_FACES_WALL`, `DAIS_BLOCKED`);
- the role table: fighter and shuttle keep a pod; frigate, explorer over 150 blocks, yacht get a bridge.

- [ ] **Step 2: building-a-ship**

`SKILL.md` checklist step 2: "one `pilot_seat` looking straight at a `canopy`... makes a cockpit pod" becomes "one flying seat: a `pilot_seat` looking straight at a `canopy` (a pod, small ships) or a `helm` behind a band of canopy (a bridge, big ships); captain's chairs and crew stations any number". `reference.md`: the block table gains the three seats (MOUNT; their t and MW); a **Seats** section (`Seat`, `PilotSeat`, `CaptainChair`, `CrewStation`, `SeatJob`; `Ship.seats()`, `seat_at()`; `CameraDirector.sit(seat)`, `seat()`, `piloting()`, `look()`; the save's `seat`); the rules table gains the five; the interior section gains the band and the dais numbers.

- [ ] **Step 3: The agent**

`ship-designer.md`'s rules: "A ship over about 150 blocks, or a warship, gets a bridge (the designing-a-ship skill's Bridges section), not the starter's pod."

- [ ] **Step 4: The spec**

Status: built on branch `bridge` (§9). Add **§9 What was built**: per task, the ledger's rulings, the HUD-at-a-seat reading (Global Constraints), the probe's fps on the bridge fixture.

- [ ] **Step 5: Check names, commit**

Every name the docs mention exists (grep each). Then:

```bash
git add .claude docs/superpowers/specs/2026-10-09-ship-bridge-design.md
git commit -m "docs: the bridge as built -- the skills, the agent, the reference, the spec"
```

---

### Task 14: Acceptance: the Warden rebuilt (after the final review)

- [ ] **Step 1:** In `D:\git\whoknows-design-2` (branch `ship-warden`), rebase onto `bridge` (`git rebase bridge`; only its two ship files differ).
- [ ] **Step 2:** Send a `ship-designer` agent (the session knows the type now) with: "Revise `warden`: give it a command bridge (the designing-a-ship skill's Bridges section) in place of the pod: the helm forward at the glass, crew stations either side, the captain's chair raised behind; keep its silhouette, size and feel. Work in D:\git\whoknows-design-2 by Set-Location." Wait for the report.
- [ ] **Step 3:** Verify (re-run `ship_check` on `warden.json`; the commit holds only the two files), look at its bridge renders, send them to the owner, and record the outcome in spec §9.
