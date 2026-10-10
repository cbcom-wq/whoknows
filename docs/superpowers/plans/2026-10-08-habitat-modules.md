# Habitat Modules (Phases A–C) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a hub package at the ship's machine, carry it out, plant it on a big rock, board it, save and load it, and plant a drill and a store beside it that earn and hold QE, linked back to the ship.

**Architecture:** A base is a `ShipGrid` that never flies. A new `GridHome` base class takes everything `Ship` and `Base` share (grid, interior slot, items, airlocks, quantum plant, being the place you are in). Ships and bases draw interior slots from one `InteriorSlots` pool. `Bases` keeps every base as a pure `BaseSite` and builds a `Base` node only while it is awake (inside 18 km), exactly as `Fleet` sleeps ships. Planting is a pure fit test (`Planting`) against a `PlantSurface`, which only `RockSurface` implements in this build.

**Tech Stack:** Godot 4.5.1, GDScript, GUT (headless). Worktree `D:/git/whoknows-habitat`, branch `habitat-modules`.

**Spec:** `docs/superpowers/specs/2026-09-26-habitat-modules-design.md` (approved 2026-10-08). Read it before any task. This plan builds its Phases A, B and C; Phase D (corridors) waits on quantum energy's hose (Task 9 of that plan), and Phases E and F get plans of their own. A base as a sensor contact on the bridge computer's map (§10) waits on quantum energy's Task 10, as the spec says, and is not in this plan.

## Global Constraints

- **Visual style is binding** (`docs/design/visual-style.md`, CLAUDE.md): colours only from `InteriorPalette`, `HullPalette`, `SpacePalette`; no new shader (the budget stays three); props never see the grid. Every new file that paints goes into `PAINTING_FILES` in `test/unit/test_visual_style_rules.gd`.
- **Floating origin** (CLAUDE.md): anything outside joins `Universe.EXTERIOR_SPACE` (a node whose parent never moves) or listens to `Universe.shifted`. Positions that survive a shift are `UniversePoint`s. A sleeping base has no nodes at all.
- **Every ship is usable** (CLAUDE.md): never author a second `Ship` in a `.tscn`. Run `test/probes/fleet_play.gd` after any change to boarding, airlocks or the suit (Tasks 2 and 10).
- **No hand-authored `.tscn`.** Base nodes are built in code. Item and block `.tres` files are copied from a sibling file and edited, with **no `#` comment anywhere in them** (CLAUDE.md's parser hazard). After editing a `.tres`, read the value back at runtime in a test.
- **Tests:** run only the files a task names: `./run_tests.ps1 -gselect=<file>` from `D:/git/whoknows-habitat/who-knows` in PowerShell. **Check the directory before every run**: `run_tests.ps1` resolves from the current directory, and a shell in `D:/git/whoknows` runs `main`'s code. Never run the full suite without the owner's go-ahead.
- **After adding a `class_name`**, re-import: `& "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path . --import` (or `$env:GODOT_BIN`).
- **Numbers live in `HabitatValues`** (Task 3) and nowhere else, so playtest tuning touches one file.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

### Where this plan settles what the spec left open, or departs from it

The spec (§9.5) calls its file list "a sketch, for the plan to settle". Each line below is a choice made here. Tell the owner about them in the final report (Task 15):
1. **`GridInterior` is a base class, `GridHome`,** that `Ship` and `Base` both extend. `Airlock`, the avatar's `hull` and boarding need one type for "a ship or a base"; this is also the spec §5.5 "common `Home`".
2. **The universe clock is the flight scene's `play_time`,** which already exists, is already saved, and already advances every physics tick through warps and blackouts. No new `Universe.clock`.
3. **Modules are defined in code** (`ModuleCatalog`), not `data/modules/*.tres`, because of CLAUDE.md's `.tres` hazard.
4. **The hub is 3 × 2 cells, not 2 × 2.** `AirlockSite` needs an airlock with exactly one horizontal face onto open space, and a corner of a 2 × 2 has two.
5. **Modules stand at least one empty cell apart.** Face-touching modules would merge their interiors with no corridor.
6. **The ghost turns on R** (new action `turn_module`), not Q/E, which roll the suit.
7. **The store module's capacity is a new block, `quantum_tank`** (1,000 QE), since `quantum_cell` holds 400.
8. **`EnergyPanel` is unchanged.** Spec §10 says both "gains the base's store" and "aboard on foot the HUD stays dark"; the hub's link panel and the drill's gauge are the instruments, as §10's last sentence says.
9. **Herds drift away from a drill** by `RockHerdSource` leaving out a herd whose home is within 80 m of a drill that has run 10 minutes (§8.4's "rounds drift away"). No behaviour changes. The scatter at planting is the existing `VIBRATION` path.
10. **Modules on a base connect only by corridors (Phase D).** Until then a drill or store beside the hub works but can't be walked into; `BaseValidator` checks each module on its own.
11. **The drills' gauges read on the hub's link panel** (*DRILL 1 · VEIN 1.8×*), not in the drill's own room, which can't be reached until corridors. The room's own gauge comes with Phase D. The link may also ship press-only if the interactor has no held callback (Task 14 says how to tell).

## Review Focus

The five conditions most likely to bite a player that the spec implies but does not spell out. Each has a test in the task named.

1. **Loading a save made inside a base,** with the ship more than 20 km away: you load standing inside the base, the base awake, the ship asleep (Task 11, `test_save_bases.gd::test_a_save_inside_a_base_loads_you_inside_it_with_the_ship_asleep`).
2. **The slot pool full when a base wakes:** the base stays asleep and is not lost; it wakes when a slot frees (Task 8, `test_bases.gd::test_a_base_that_cannot_get_a_slot_stays_asleep_and_wakes_later`).
3. **Blacking out inside a base while the ship is asleep:** you wake by the hub's core and the base's store pays, never the sleeping ship's (Task 10, `test_base_boarding.gd::test_blacking_out_in_a_base_wakes_you_there_at_the_base_s_cost`).
4. **Planting with the ghost's last fit gone stale** (you drifted off the rock between the 10 Hz checks): `use` re-tests and refuses rather than planting in mid-air (Task 9, `test_package_use.gd::test_use_retests_the_fit_before_planting`).
5. **A drill credited across a long sleep** with the store nearly full: it stops at capacity and never goes over, and its credit clock still advances so a later wake doesn't double-pay (Task 13, `test_drill_yield.gd::test_a_long_sleep_fills_to_capacity_and_never_pays_twice`).

---

## File map

**Phase A: shared ground**
- Create `who-knows/src/ship/interior_slots.gd`: `InteriorSlots`, the slot pool.
- Create `who-knows/src/ship/grid_home.gd`: `GridHome`, what `Ship` and `Base` share.
- Modify `who-knows/src/ship/ship.gd`: extends `GridHome`; shared members removed.
- Modify `who-knows/src/ship/fleet.gd`: slots from the pool.
- Modify `who-knows/src/ship/airlock/airlock.gd`: drives any `GridHome`.

**Phase B: a hub you can plant**
- Create `who-knows/src/habitat/habitat_values.gd`: `HabitatValues`.
- Create `who-knows/src/habitat/module_definition.gd`, `module_catalog.gd`: modules as block prefabs.
- Create `who-knows/data/blocks/quantum_tank.tres`.
- Create `who-knows/src/habitat/base_site.gd`, `base_validator.gd`: a base as data, and its rules.
- Create `who-knows/src/habitat/plant_surface.gd`, `rock_surface.gd`, `planting.gd`: the fit test.
- Modify `who-knows/src/items/item_definition.gd`, `who-knows/src/avatar/grasp.gd`, `suit.gd`, `avatar.gd`: EVA cargo.
- Create `who-knows/src/habitat/base.gd`, `base_exterior.gd`: the base node and its outside.
- Modify `who-knows/src/quantum/quantum_plant.gd`: a store that starts empty, and making off.
- Create `who-knows/src/habitat/bases.gd`: every base, sleeping and waking.
- Create `who-knows/src/habitat/package_use.gd`, `package_ghost.gd`; `who-knows/data/items/{hub,drill,store}_package.tres`; modify `who-knows/src/items/item_looks.gd`, `who-knows/project.godot` (action `turn_module`).
- Modify `who-knows/scenes/flight_test.gd`, `who-knows/src/ship/suit_tie.gd`, `who-knows/src/ui/vehicle_telemetry.gd`, `who-knows/src/ui/airlock_marker.gd`: boarding a base.
- Modify `who-knows/src/save/save_game.gd`, `who-knows/scenes/flight_test.gd`: format 3.
- Create `who-knows/test/probes/base_probe.gd`: the plant probe and renders.

**Phase C: a base that earns**
- Create `who-knows/src/habitat/quantum_link.gd`, `link_panel.gd`: the link.
- Create `who-knows/src/habitat/drill_yield.gd`; modify `base.gd`, `bases.gd`, `who-knows/src/npc/populations/rock_herd_source.gd`: the drill, its hum, quiet herds.
- Docs and skills: the spec's "as built", `SLICE-1-STATUS.md`, the `building-a-ship` and `building-an-npc` skills.

---

## Phase A: shared ground

### Task 1: `InteriorSlots`, one pool for ships and bases

**Files:**
- Create: `who-knows/src/ship/interior_slots.gd`
- Modify: `who-knows/src/ship/fleet.gd` (`adopt`, `spawn`, `remove`; delete `_free_slot`)
- Test: `who-knows/test/unit/test_interior_slots.gd`

**Interfaces:**
- Produces: `InteriorSlots` with `const MAX := 16`, `claim() -> int` (lowest free, or -1), `take(slot: int) -> bool`, `release(slot: int) -> void`, `is_held(slot: int) -> bool`, `free_count() -> int`. `Fleet.slots: InteriorSlots` (the flight scene shares it with `Bases` in Task 8).

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_interior_slots.gd`:

```gdscript
extends GutTest

## One pool of interior slots for ships and bases (habitat modules spec §9.3).

func test_claims_the_lowest_free_slot():
	var pool := InteriorSlots.new()
	assert_eq(pool.claim(), 0)
	assert_eq(pool.claim(), 1)
	pool.release(0)
	assert_eq(pool.claim(), 0, "a released slot is reused")

func test_take_holds_a_given_slot_once():
	var pool := InteriorSlots.new()
	assert_true(pool.take(3))
	assert_false(pool.take(3), "already held")
	assert_false(pool.take(-1))
	assert_false(pool.take(InteriorSlots.MAX))
	assert_true(pool.is_held(3))
	assert_eq(pool.claim(), 0)

func test_the_pool_runs_out_at_max():
	var pool := InteriorSlots.new()
	for i in InteriorSlots.MAX:
		assert_eq(pool.claim(), i)
	assert_eq(pool.claim(), -1, "full")
	assert_eq(pool.free_count(), 0)

func test_the_fleet_draws_from_its_pool():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var fleet: Fleet = root.fleet
	assert_true(fleet.slots.is_held(0), "the starter holds slot 0")
	var other := fleet.slots.claim()
	assert_eq(other, 1, "something else took slot 1")
	var starter: Ship = root.get_node("Ship")
	var ship := fleet.spawn(root._starter_grid(), starter.exterior.global_transform.translated(Vector3(300, 0, 0)))
	assert_eq(ship.interior_slot, 2, "the ship takes the next free one")
	fleet.remove(ship)
	assert_false(fleet.slots.is_held(2), "removing a ship frees its slot")
```

- [ ] **Step 2: Run it to verify it fails**

Run (PowerShell, in `D:/git/whoknows-habitat/who-knows`): `./run_tests.ps1 -gselect=test_interior_slots.gd`
Expected: FAIL, parse error: `InteriorSlots` not declared.

- [ ] **Step 3: Write `InteriorSlots`**

`who-knows/src/ship/interior_slots.gd`:

```gdscript
class_name InteriorSlots
extends RefCounted

## One pool of interior slots for ships and bases (docs/superpowers/specs/
## 2026-09-26-habitat-modules-design.md §9.3). Interiors stand
## Ship.SLOT_SPACING apart on x: slot 15 is 30 km out, where a float still
## holds about 2 mm, so there are MAX of them. Slot 0 is the starter's.

const MAX := 16

var _held := {}   # int -> true

## The lowest free slot, now held; -1 when every slot is held.
func claim() -> int:
	for slot in MAX:
		if not _held.has(slot):
			_held[slot] = true
			return slot
	return -1

## Holds `slot` itself (the starter's 0). False if it is out of range or held.
func take(slot: int) -> bool:
	if slot < 0 or slot >= MAX or _held.has(slot):
		return false
	_held[slot] = true
	return true

func release(slot: int) -> void:
	_held.erase(slot)

func is_held(slot: int) -> bool:
	return _held.has(slot)

func free_count() -> int:
	return MAX - _held.size()
```

- [ ] **Step 4: Make `Fleet` draw from it**

In `who-knows/src/ship/fleet.gd`:

Add below `var max_ships := MAX_SHIPS`:

```gdscript
## The interior slots, shared with every base (habitat modules spec §9.3).
var slots := InteriorSlots.new()
```

In `adopt`, after `_ships.append(ship)`:

```gdscript
	slots.take(ship.interior_slot)
```

In `spawn`, replace

```gdscript
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.name = ship_name if ship_name != "" else _next_name()
	ship.interior_slot = _free_slot()
```

with

```gdscript
	var slot := slots.claim()
	if slot < 0:
		push_warning("Fleet: no interior slot free")
		return null
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.name = ship_name if ship_name != "" else _next_name()
	ship.interior_slot = slot
```

In `remove`, after `_asleep.erase(ship)`:

```gdscript
	slots.release(ship.interior_slot)
```

Delete `_free_slot()` and its doc comment.

- [ ] **Step 5: Run the tests**

Run: `./run_tests.ps1 -gselect=test_interior_slots.gd` then `./run_tests.ps1 -gselect=test_fleet.gd`
Expected: both PASS (`test_fleet.gd`'s `test_names_never_repeat_and_slots_are_reused` still holds).

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/ship/interior_slots.gd who-knows/src/ship/fleet.gd who-knows/test/unit/test_interior_slots.gd
git commit -m "feat: InteriorSlots -- one pool of interior slots for ships and bases"
```

---

### Task 2: `GridHome`, what a ship and a base share

A refactor with **no behaviour change**. Every existing ship, airlock, save and damage test must pass unchanged, and `fleet_play.gd` must play through.

**Files:**
- Create: `who-knows/src/ship/grid_home.gd`
- Modify: `who-knows/src/ship/ship.gd`, `who-knows/src/ship/airlock/airlock.gd`, `who-knows/test/unit/test_ship_damage.gd` (two `Ship.WAKE_ROOM` references)
- Test: `who-knows/test/unit/test_grid_home.gd`

**Interfaces:**
- Produces `GridHome extends Node3D`:
  - signal `airlock_crossed(avatar: Avatar, outward: bool)`;
  - consts `INTERIOR_WORLD_BASE`, `SLOT_SPACING`, `RESEAT_TOLERANCE`, `WAKE_ROOM`, `CANOPY_SHADER`, `HULL_LIVERY_MATERIAL`, `OWN_ONLY`;
  - vars `interior_slot`, `outside_path`, `grid`, `outside`, `catalog`, `item_catalog`, `items`, `airlocks`, `quantum`, `own`, `livery`;
  - `@onready` `exterior: RigidBody3D`, `interior`, `exterior_builder`, `interior_builder`;
  - methods `_setup_home()`, `interior_slot_origin() -> Vector3`, `set_own(on: bool)`, `wake_spots() -> Array[Transform3D]`, `restore_item(d: Dictionary) -> Item`, `items_to_dict() -> Array`, `home_busy() -> String`, `is_warping() -> bool` (false here, overridden by `Ship`), `_bind_airlocks()`, `_stowed_items()`, `_reseat(stowed)`, `_stock()`, `_apply_own()`, `_apply_livery()`.
- `Airlock.setup(home: GridHome, at: Vector3i)`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_grid_home.gd`:

```gdscript
extends GutTest

## GridHome (habitat modules spec §9.1): what a ship and a base share,
## extracted from Ship with no change to the ship.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func test_a_ship_is_a_grid_home():
	assert_true(_ship is GridHome)
	assert_eq(_ship.interior.global_position, GridHome.INTERIOR_WORLD_BASE, "slot 0")
	assert_not_null(_ship.items)
	assert_false(_ship.airlocks.is_empty())

func test_its_airlocks_know_its_warp_through_the_home():
	for a: Airlock in _ship.airlocks.values():
		assert_false(a.warping())
	assert_false(_ship.is_warping())

func test_items_round_trip_through_the_home():
	var saved := _ship.items_to_dict()
	assert_gt(saved.size(), 0, "the starter is stocked")
	var item := _ship.restore_item(saved[0])
	assert_not_null(item)
	assert_eq(item.get_parent(), _ship.items)

func test_its_home_busy_is_calm_at_rest():
	assert_eq(_ship.home_busy(), "")
	assert_eq(_ship.busy(), "")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_grid_home.gd`
Expected: FAIL, `GridHome` not declared.

- [ ] **Step 3: Create `GridHome` by moving code out of `Ship`**

Create `who-knows/src/ship/grid_home.gd`. Each method body below is **moved verbatim** from `ship.gd` (the same names). The only new pieces are `_setup_home`, `items_to_dict`, `home_busy` and `is_warping`:

```gdscript
class_name GridHome
extends Node3D

## What a ship and a base share (docs/superpowers/specs/
## 2026-09-26-habitat-modules-design.md §9.1, §5.5): a ShipGrid built into an
## exterior body and a walkable interior in a slot of its own, the items in
## it, its airlocks and quantum plant, and being the place you are in. Ship
## adds flight; Base stands still. Both have the same four nodes: Exterior (a
## RigidBody3D) with ExteriorBuilder under it, and Interior with
## InteriorBuilder under it.

## Someone crossed one of its airlocks' outer hatches (airlock spec §7):
## `outward` true out onto a spacewalk, false in (many ships spec §4.3).
signal airlock_crossed(avatar: Avatar, outward: bool)

const INTERIOR_WORLD_BASE := Vector3(0.0, -5000.0, 0.0)
const SLOT_SPACING := 2000.0
## How close a rebuilt stow point must be to where a stowed item's point was
## for the item to stay stowed through the rebuild.
const RESEAT_TOLERANCE := 0.05
## Where you wake after blacking out, if it has one.
const WAKE_ROOM := &"bunk_room"
## The livery every builder paints the hull with: one shared instance. Each
## home swaps it for its own copy, `livery` (_apply_livery).
const HULL_LIVERY_MATERIAL: ShaderMaterial = preload("res://data/materials/hull_livery.tres")
## The window glass's shader; each home makes its own material from it.
const CANOPY_SHADER: Shader = preload("res://data/materials/interior/canopy_window.gdshader")
## Marks a hull piece made for the own layer alone, so set_own can move it
## back.
const OWN_ONLY := &"own_only"

@export var interior_slot: int = 0
## Where a spacewalker goes (airlock spec §7.4): the scene's root for things in
## the real world.
@export var outside_path: NodePath

var grid: ShipGrid
var outside: Node3D
var catalog: BlockCatalog
var item_catalog: ItemCatalog
## Every item in it that is not in someone's hand (hands-and-items spec §4.4).
## A sibling of the builders, so an interior rebuild never touches it.
var items: Node3D
## Every airlock that can cycle, by cell (airlock spec §4.5).
var airlocks: Dictionary = {}   # Vector3i -> Airlock
## The quantum store and the cores and machines it drives (quantum energy
## spec §3.2).
var quantum: QuantumPlant
## True for the place you are in (many ships spec §4.2): its hull's own pieces
## are drawn on ExteriorBuilder.OWN_HULL_LAYER, which your windows leave out,
## and its interior shows. Anything else hides its interior.
var own := true
## This home's own copy of the hull livery (_apply_livery).
var livery: ShaderMaterial = HULL_LIVERY_MATERIAL.duplicate()

var _stocked := false
var _airlocks_root: Node

@onready var exterior: RigidBody3D = $Exterior
@onready var interior: Node3D = $Interior
@onready var exterior_builder: ExteriorBuilder = $Exterior/ExteriorBuilder
@onready var interior_builder: InteriorBuilder = $Interior/InteriorBuilder

func _process(_delta: float) -> void:
	livery.set_shader_parameter(&"hull_inverse", exterior.global_transform.affine_inverse())

## Puts the interior in its slot, finds outside, loads the catalogues and makes
## the Items and Airlocks holders. Call first in _ready.
func _setup_home() -> void:
	_make_canopy_material()
	interior.global_position = interior_slot_origin()
	outside = get_node_or_null(outside_path) as Node3D if not outside_path.is_empty() else null
	if outside == null:
		outside = get_parent() as Node3D
	if catalog == null:
		catalog = BlockCatalog.load_from_dir("res://data/blocks")
	if item_catalog == null:
		item_catalog = ItemCatalog.load_from_dir("res://data/items")
	items = Node3D.new()
	items.name = "Items"
	interior.add_child(items)
	_airlocks_root = Node.new()
	_airlocks_root.name = "Airlocks"
	add_child(_airlocks_root)

## True while it is spooling or travelling at warp: no airlock works then.
## Only a ship can.
func is_warping() -> bool:
	return false

## Why a save must wait on it (saving spec §5), or "": an airlock cycling, the
## quantum machine busy, or a bolt in flight.
func home_busy() -> String:
	for airlock: Airlock in airlocks.values():
		var why := airlock.busy()
		if why != "":
			return why
	var why := quantum.busy() if quantum != null else ""
	if why != "":
		return why
	if items != null:
		for node in items.get_children():
			if node is PlasmaBolt:
				return "bolt in flight"
	return ""

## Every item in it that is not in someone's hand, as saved data in the
## interior's frame (saving spec §6.4).
func items_to_dict() -> Array:
	var out := []
	var frame := interior.global_transform
	for node in items.get_children():
		var item := node as Item
		if item != null and item.state != Item.State.HELD and not item.is_queued_for_deletion():
			out.append(item.to_dict(frame))
	return out
```

Then **move these methods from `ship.gd` into `grid_home.gd` unchanged**, with their doc comments: `_make_canopy_material`, `_apply_livery`, `interior_slot_origin`, `set_own`, `_apply_own`, `wake_spots`, `_bind_airlocks`, `_stowed_items`, `_reseat`, `_stock`, `restore_item`.

- [ ] **Step 4: Make `Ship` a `GridHome`**

In `who-knows/src/ship/ship.gd`:
1. `extends Node3D` becomes `extends GridHome`.
2. Delete what moved: the `airlock_crossed` signal; the consts `INTERIOR_WORLD_BASE`, `SLOT_SPACING`, `RESEAT_TOLERANCE`, `WAKE_ROOM`, `HULL_LIVERY_MATERIAL`, `CANOPY_SHADER`, `OWN_ONLY`; the vars `interior_slot`, `outside_path`, `grid`, `outside`, `catalog`, `item_catalog`, `items`, `airlocks`, `quantum`, `own`, `livery`, `_stocked`, `_airlocks_root`; the `@onready` lines for `exterior`, `interior`, `exterior_builder`, `interior_builder`; and the methods moved in Step 3.
3. In `_ready`, delete the first line `_make_canopy_material()` and the block from `interior.global_position = interior_slot_origin()` through `add_child(_airlocks_root)`. Put `_setup_home()` as the first line of `_ready`.
4. Replace `_process` with:

```gdscript
func _process(delta: float) -> void:
	# hull_livery.gdshader paints its stripe from ship-local height (GridHome
	# pushes this hull's inverse transform every frame; see
	# hull_livery.gdshader's header comment for why).
	super(delta)
	_update_hum()
```

5. Replace the whole of `busy()` with:

```gdscript
## Why a save must wait (§5), or "": a rock struck the hull lately, something
## aboard was hurt lately, or anything GridHome waits on.
func busy() -> String:
	if since_struck < STRUCK_CALM:
		return "hull struck"
	var hurt := damage_log.busy()
	if hurt != "":
		return hurt
	return home_busy()
```

6. In `to_dict`, replace the `saved_items` loop (from `var saved_items := []` through its `for` body; keep `var frame` only if it is still used elsewhere, otherwise delete it) with `var saved_items := items_to_dict()`.
7. Add:

```gdscript
func is_warping() -> bool:
	return warp != null and warp.is_spinning()
```

- [ ] **Step 5: Make `Airlock` drive any `GridHome`**

In `who-knows/src/ship/airlock/airlock.gd`:
- `var _ship: Ship` becomes `var _ship: GridHome`.
- `func setup(ship: Ship, at: Vector3i) -> void:` becomes `func setup(ship: GridHome, at: Vector3i) -> void:`.
- `warping()`'s body becomes `return _ship != null and _ship.is_warping()`.

In `who-knows/test/unit/test_ship_damage.gd`, replace both `Ship.WAKE_ROOM` with `GridHome.WAKE_ROOM`.

Grep for anything else that still names a moved constant through `Ship.`:

Run: `git grep -n "Ship\.\(SLOT_SPACING\|INTERIOR_WORLD_BASE\|RESEAT_TOLERANCE\|WAKE_ROOM\|CANOPY_SHADER\|HULL_LIVERY_MATERIAL\|OWN_ONLY\)" -- who-knows`
Expected: only the comment in `fleet.gd` and `interior_slots.gd`. Change both comments to `GridHome.SLOT_SPACING`.

- [ ] **Step 6: Re-import and run the parity tests**

Re-import (Global Constraints), then run each:
`./run_tests.ps1 -gselect=test_grid_home.gd`, `-gselect=test_fleet.gd`, `-gselect=test_save_scene.gd`, `-gselect=test_ship_damage.gd`, `-gselect=test_airlock_site.gd`, `-gselect=test_airlock_show.gd`, `-gselect=test_suit_tie.gd`, `-gselect=test_floating_origin_scene.gd`, `-gselect=test_visual_style_rules.gd`
Expected: all PASS with no new warnings.

- [ ] **Step 7: Play `fleet_play.gd`**

Run (not headless): `& $godot --path . --resolution 1280x720 --script D:/git/whoknows-habitat/who-knows/test/probes/fleet_play.gd -- D:/git/whoknows-habitat/out/fleet_play`
Expected: it prints every step as found and ends with zero fails.

- [ ] **Step 8: Commit**

```bash
git add who-knows/src/ship/grid_home.gd who-knows/src/ship/ship.gd who-knows/src/ship/airlock/airlock.gd who-knows/src/ship/fleet.gd who-knows/src/ship/interior_slots.gd who-knows/test/unit/test_grid_home.gd who-knows/test/unit/test_ship_damage.gd
git commit -m "refactor: GridHome -- what a ship and a base share, out of Ship with no change to the ship"
```

---

## Phase B: a hub you can plant

### Task 3: `HabitatValues`, modules as block prefabs, and the quantum tank

**Files:**
- Create: `who-knows/src/habitat/habitat_values.gd`, `who-knows/src/habitat/module_definition.gd`, `who-knows/src/habitat/module_catalog.gd`, `who-knows/data/blocks/quantum_tank.tres`
- Test: `who-knows/test/unit/test_module_catalog.gd`

**Interfaces:**
- Produces `HabitatValues` (every constant below, used by later tasks by name).
- Produces `ModuleDefinition extends RefCounted`: `kind: StringName`, `display_name: String`, `size: Vector3i` (cells on x, storeys on y, cells on z), `blocks: Array` of `[Vector3i, StringName, int]` (local cell, block id, orientation), `package: StringName`; `turned_size(turns: int) -> Vector3i`; `turned(turns: int) -> Array` (the blocks with cells and orientations turned); `static turn_cell(c: Vector3i, turns: int, size: Vector3i) -> Vector3i`; `static turn_orientation(o: int, turns: int) -> int`; `floor_cells(turns: int) -> Array[Vector3i]` (storey-0 cells).
- Produces `ModuleCatalog`: `static get_def(kind: StringName) -> ModuleDefinition`, `static kinds() -> Array[StringName]`, consts `HUB := &"hub"`, `DRILL := &"drill"`, `STORE := &"store"`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_module_catalog.gd`:

```gdscript
extends GutTest

## Modules as block prefabs (habitat modules spec §6, §9.1).

var _blocks: BlockCatalog

func before_all():
	_blocks = BlockCatalog.load_from_dir("res://data/blocks")

func _grid(def: ModuleDefinition, turns := 0) -> ShipGrid:
	var g := ShipGrid.new()
	for b: Array in def.turned(turns):
		var inst := BlockInstance.new()
		inst.block_id = b[1]
		inst.orientation = b[2]
		g.set_block(b[0], inst)
	return g

func test_every_module_s_blocks_lie_in_its_footprint_however_turned():
	for kind in ModuleCatalog.kinds():
		var def := ModuleCatalog.get_def(kind)
		for turns in 4:
			var size := def.turned_size(turns)
			var seen := {}
			for b: Array in def.turned(turns):
				var c: Vector3i = b[0]
				assert_true(c.x >= 0 and c.x < size.x and c.y >= 0 and c.y < size.y and c.z >= 0 and c.z < size.z,
					"%s turned %d: %s inside %s" % [kind, turns, c, size])
				assert_false(seen.has(c), "no two blocks in one cell")
				seen[c] = true
			assert_eq(seen.size(), def.blocks.size())

func test_every_block_id_exists():
	for kind in ModuleCatalog.kinds():
		for b: Array in ModuleCatalog.get_def(kind).blocks:
			assert_not_null(_blocks.get_def(b[1]), "%s: %s" % [kind, b[1]])

func test_four_turns_are_none():
	for o in 24:
		assert_eq(ModuleDefinition.turn_orientation(o, 4), o)
	var def := ModuleCatalog.get_def(ModuleCatalog.HUB)
	assert_eq(def.turned(4), def.turned(0))

func test_a_turn_is_a_quarter_turn_about_up():
	# The block's facing turns with its cell: +90 deg about +y maps -z to -x.
	var o := ModuleDefinition.turn_orientation(0, 1)
	var facing := -(BlockOrientation.basis_for(o).z)
	assert_almost_eq(facing, Vector3(-1, 0, 0), Vector3.ONE * 0.001)

func test_the_hub_has_one_airlock_that_cycles_however_turned():
	var def := ModuleCatalog.get_def(ModuleCatalog.HUB)
	for turns in 4:
		var g := _grid(def, turns)
		var locks := 0
		for c in g.coords():
			if g.get_block(c).block_id == AirlockSite.AIRLOCK_ID:
				locks += 1
				assert_ne(AirlockSite.hatch_normal(g, c), Vector3i.ZERO, "turned %d" % turns)
		assert_eq(locks, 1)

func test_capacities():
	assert_eq(ShipStats.compute(_grid(ModuleCatalog.get_def(ModuleCatalog.HUB)), _blocks).quantum_capacity,
		HabitatValues.HUB_STORE)
	assert_eq(ShipStats.compute(_grid(ModuleCatalog.get_def(ModuleCatalog.STORE)), _blocks).quantum_capacity,
		HabitatValues.STORE_ADDS)
	assert_eq(_blocks.get_def(&"quantum_tank").quantum_capacity, 1000, "read back from the .tres")

func test_every_module_has_gravity_over_its_floor():
	for kind in ModuleCatalog.kinds():
		var g := _grid(ModuleCatalog.get_def(kind))
		var b := InteriorBuilder.new()
		add_child_autofree(b)
		b.bind(g, _blocks)
		b.rebuild()
		for c in b.walkable_coords():
			assert_gt(b.gravity_at(c), 0.0, "%s %s" % [kind, c])
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_module_catalog.gd`
Expected: FAIL, `ModuleCatalog` not declared.

- [ ] **Step 3: Write `HabitatValues`**

`who-knows/src/habitat/habitat_values.gd`:

```gdscript
class_name HabitatValues
extends RefCounted

## Every number in docs/superpowers/specs/2026-09-26-habitat-modules-design.md,
## in one place: first guesses, tuned at playtest (§3).

# Planting (§5.2).
const PLANT_REACH := 8.0
const LEG_MIN := 0.3
const LEG_MAX := 2.5
## A new hub's body stands this far above the highest ground under its corners,
## beyond LEG_MIN, so its legs start short.
const LEG_SPARE := 0.4
const MAX_TILT := deg_to_rad(25.0)
const FROM_BASE := 24.0
const FROM_SHIP := 20.0
## How often the ghost re-tests where you aim, seconds.
const FIT_EVERY := 0.1
## How far above and below the leg ends the ground is looked for.
const CAST_SPARE := 4.0

# Unfolding (§5.3), seconds.
const FLY := 0.6
const SETTLE := 0.4
const LEGS := 1.0
const WALLS := 2.0
const LIGHTS := 1.5
const UNFOLD := FLY + SETTLE + LEGS + WALLS + LIGHTS

# Stores (§6.1, §6.3).
const HUB_STORE := 400
const STORE_ADDS := 1000

# The link (§6.1).
const LINK_REACH := 1000.0
const LINK_STEP := 50
## QE a second while ◀ or ▶ is held.
const LINK_RATE := 100.0

# The drill (§6.2).
const DRILL_PERIOD := 10.0
const RICHNESS_MIN := 0.5
const RICHNESS_MAX := 3.0
const VEIN_FACTOR := 2.0
const SURVEY := 60.0
## How often an awake base credits its drills.
const CREDIT_EVERY := 5.0

# Skitters (§8.4).
const STAMP_STRENGTH := 1.0
const STAMP_RADIUS := 60.0
const HUM_STRENGTH := 0.2
const HUM_RADIUS := 80.0
const HUM_EVERY := 3.0
## A herd whose home is within QUIET_RADIUS of a drill that has run this long
## has moved away.
const QUIET_AFTER := 600.0
const QUIET_RADIUS := 80.0

# Sleeping (§9.3): as ships do.
const SLEEP_AT := 20000.0
const WAKE_AT := 18000.0
```

- [ ] **Step 4: Write `ModuleDefinition`**

`who-knows/src/habitat/module_definition.gd`:

```gdscript
class_name ModuleDefinition
extends RefCounted

## One module (habitat modules spec §6): a small grid of blocks, its prefab,
## copied into a base's grid where it is planted, turned in quarter turns
## about up. Cells are module-local: x and z across its footprint from 0, y
## its storeys from 0 (the floor) up.

var kind: StringName
var display_name: String
## Cells on x, storeys on y, cells on z, unturned.
var size: Vector3i
## [Vector3i cell, StringName block id, int orientation], unturned.
var blocks: Array = []
## The item that unfolds into it.
var package: StringName

func _init(p_kind: StringName, p_name: String, p_size: Vector3i, p_package: StringName) -> void:
	kind = p_kind
	display_name = p_name
	size = p_size
	package = p_package

func put(cell: Vector3i, id: StringName, orientation := 0) -> ModuleDefinition:
	blocks.append([cell, id, orientation])
	return self

## Its size once turned: a quarter or three-quarter turn swaps x and z.
func turned_size(turns: int) -> Vector3i:
	return Vector3i(size.z, size.y, size.x) if posmod(turns, 2) == 1 else size

## Its blocks turned `turns` quarter turns about +y, cells kept inside the
## turned footprint.
func turned(turns: int) -> Array:
	var out := []
	for b: Array in blocks:
		out.append([turn_cell(b[0], turns, size), b[1], turn_orientation(b[2], turns)])
	return out

## Its floor cells (storey 0), turned.
func floor_cells(turns: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for b: Array in turned(turns):
		if (b[0] as Vector3i).y == 0:
			out.append(b[0])
	return out

## `c` turned `turns` quarter turns (+90 deg each, about +y) inside a footprint
## of `p_size`: x, z goes to z, w-1-x, the footprint's x and z swapping.
static func turn_cell(c: Vector3i, turns: int, p_size: Vector3i) -> Vector3i:
	var out := c
	var w := p_size.x
	var d := p_size.z
	for i in posmod(turns, 4):
		out = Vector3i(out.z, out.y, w - 1 - out.x)
		var t := w
		w = d
		d = t
	return out

## Orientation `o` turned `turns` quarter turns about +y: the orientation whose
## basis is the turn times o's.
static func turn_orientation(o: int, turns: int) -> int:
	var want := Basis(Vector3.UP, PI * 0.5 * posmod(turns, 4)) * BlockOrientation.basis_for(o)
	for candidate in 24:
		var b := BlockOrientation.basis_for(candidate)
		if b.x.is_equal_approx(want.x) and b.y.is_equal_approx(want.y) and b.z.is_equal_approx(want.z):
			return candidate
	push_error("ModuleDefinition: no orientation for %d turned %d" % [o, turns])
	return o
```

Check `turn_cell` against `turn_orientation`: +90 deg about +y takes +x to -z and +z to +x, so a cell (x, z) goes to (z, -x), shifted by w-1 to stay non-negative: (z, w-1-x). The test `test_a_turn_is_a_quarter_turn_about_up` pins the basis direction. If it fails, the sign of the turn in `turn_orientation` is wrong, not the test.

- [ ] **Step 5: Write `ModuleCatalog`**

`who-knows/src/habitat/module_catalog.gd`:

```gdscript
class_name ModuleCatalog
extends RefCounted

## The modules of Phases B and C (habitat modules spec §6.1-§6.3), in code so
## no hand-written .tres can drop a line (CLAUDE.md). Orientation 0 faces -z;
## 4 faces +z. Storey 1 is the roof: gravity plating and storage live there,
## above the walkable floor.

const HUB := &"hub"
const DRILL := &"drill"
const STORE := &"store"

const O_FORWARD := 0
const O_STERN := 4

static var _defs: Dictionary = {}

static func kinds() -> Array[StringName]:
	return [HUB, DRILL, STORE]

static func get_def(kind: StringName) -> ModuleDefinition:
	if _defs.is_empty():
		_build()
	return _defs.get(kind)

static func _build() -> void:
	# The hub (§6.1): the terminal and the core along the back, the airlock in
	# the middle of the front opening out of +z, a deck either side of it. Its
	# store is one quantum cell (400) in the roof, over the core.
	var hub := ModuleDefinition.new(HUB, "Hub", Vector3i(3, 2, 2), &"hub_package")
	hub.put(Vector3i(0, 0, 0), &"quantum_machine", O_STERN)
	hub.put(Vector3i(1, 0, 0), &"deck")
	hub.put(Vector3i(2, 0, 0), &"quantum_core", O_STERN)
	hub.put(Vector3i(0, 0, 1), &"deck")
	hub.put(Vector3i(1, 0, 1), &"airlock")
	hub.put(Vector3i(2, 0, 1), &"deck")
	hub.put(Vector3i(0, 1, 0), &"hull")
	hub.put(Vector3i(1, 1, 0), &"grav_plating")
	hub.put(Vector3i(2, 1, 0), &"quantum_cell")
	hub.put(Vector3i(0, 1, 1), &"hull")
	hub.put(Vector3i(1, 1, 1), &"hull")
	hub.put(Vector3i(2, 1, 1), &"hull")
	_defs[HUB] = hub
	# The drill (§6.2): a control room of two cells over the drill head.
	var drill := ModuleDefinition.new(DRILL, "Drill", Vector3i(1, 2, 2), &"drill_package")
	drill.put(Vector3i(0, 0, 0), &"deck")
	drill.put(Vector3i(0, 0, 1), &"deck")
	drill.put(Vector3i(0, 1, 0), &"grav_plating")
	drill.put(Vector3i(0, 1, 1), &"hull")
	_defs[DRILL] = drill
	# The store (§6.3): one room, a quantum tank in the roof.
	var store := ModuleDefinition.new(STORE, "Store", Vector3i(1, 2, 1), &"store_package")
	store.put(Vector3i(0, 0, 0), &"deck")
	store.put(Vector3i(0, 1, 0), &"quantum_tank")
	_defs[STORE] = store
```

`test_every_module_has_gravity_over_its_floor` checks the store's floor gets gravity. The store has no plating of its own. If that assertion fails for `store`, give the store a second storey-1 block: change `Vector3i(1, 2, 1)` to stay as is, and replace the tank line with `store.put(Vector3i(0, 1, 0), &"grav_plating")` plus a third storey holding the tank (`size` `Vector3i(1, 3, 1)`, `store.put(Vector3i(0, 2, 0), &"quantum_tank")`). Rerun.

- [ ] **Step 6: Add the quantum tank block**

Copy `who-knows/data/blocks/quantum_cell.tres` to `who-knows/data/blocks/quantum_tank.tres`. In the copy, change only these lines (and nothing else; add no comment):
- `id = &"quantum_cell"` to `id = &"quantum_tank"`
- `display_name = "Quantum Cell"` to `display_name = "Quantum Tank"`
- the `quantum_capacity = ...` line to `quantum_capacity = 1000`

If the copy carries a `uid=` in its header, delete the `uid="..."` attribute so Godot gives it a new one on import.

- [ ] **Step 7: Re-import and run the test**

Re-import, then run: `./run_tests.ps1 -gselect=test_module_catalog.gd`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add who-knows/src/habitat who-knows/data/blocks/quantum_tank.tres who-knows/test/unit/test_module_catalog.gd
git commit -m "feat: HabitatValues, and the hub, drill and store as block prefabs"
```

---
### Task 4: `BaseSite` and `BaseValidator`, a base as data

**Files:**
- Create: `who-knows/src/habitat/base_site.gd`, `who-knows/src/habitat/base_validator.gd`
- Test: `who-knows/test/unit/test_base_site.gd`

**Interfaces:**
- Consumes: `ModuleCatalog.get_def`, `ModuleDefinition.turned/turned_size`, `SaveCodec.upoint/to_upoint/basis/to_basis/vec3i/to_vec3i`, `ShipValidator.Issue`, `DeckGraph`, `AirlockSite`.
- Produces `BaseSite extends RefCounted`:
  - vars `id: StringName`, `system: int`, `at: UniversePoint` (the centre of base cell (0,0,0)), `turn: Basis` (the frame's rotation; its y is the base's up), `rock: Vector4i`, `site_id: StringName`, `modules: Array` of Dictionary `{kind: StringName, cell: Vector3i, turns: int, legs: PackedFloat32Array, drill: Dictionary}`, `store: int`, `airlocks: Dictionary` (cell key -> `Airlock.to_dict()`), `items: Array` (item dicts in the interior's frame);
  - `add(kind, cell, turns, legs) -> int`, `remove(index) -> void`, `cells_of(index) -> Array[Vector3i]`, `occupied() -> Dictionary` (cell -> module index), `grid() -> ShipGrid`, `centre_of(index) -> Vector3` (frame-local body centre), `hubs() -> Array[int]`, `drills() -> Array[int]`, `to_dict() -> Dictionary`, `static from_dict(d) -> BaseSite`.
- Produces `BaseValidator`: `static validate(site: BaseSite, catalog: BlockCatalog) -> Array` of `ShipValidator.Issue`, codes `HAS_HUB`, `MODULE_CONNECTED`, `AIRLOCK_HATCH`, `REACHABLE`, `APART`; `static ok(issues) -> bool`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_base_site.gd`:

```gdscript
extends GutTest

## A base as data (habitat modules spec §9.1, §11.1) and its rules.

var _blocks: BlockCatalog

func before_all():
	_blocks = BlockCatalog.load_from_dir("res://data/blocks")

func _site() -> BaseSite:
	var s := BaseSite.new()
	s.id = &"Base1"
	s.system = 7
	s.at = UniversePoint.at(1000, -2000, 3000).plus(Vector3(1.5, 2.5, -0.5))
	s.turn = Basis(Vector3.UP, 0.3)
	s.rock = Vector4i(1, 2, 3, 2004)
	s.site_id = &"rock:1_2_3_2004"
	s.add(ModuleCatalog.HUB, Vector3i.ZERO, 0, PackedFloat32Array([0.7, 0.8, 0.9, 1.0]))
	return s

func test_a_module_lands_at_its_cells_turned():
	var s := _site()
	var i := s.add(ModuleCatalog.DRILL, Vector3i(5, 0, 0), 1, PackedFloat32Array([1, 1, 1, 1]))
	var cells := s.cells_of(i)
	var def := ModuleCatalog.get_def(ModuleCatalog.DRILL)
	assert_eq(cells.size(), def.blocks.size())
	for b: Array in def.turned(1):
		assert_true(cells.has(Vector3i(5, 0, 0) + b[0]))
	var g := s.grid()
	assert_eq(g.size(), ModuleCatalog.get_def(ModuleCatalog.HUB).blocks.size() + def.blocks.size())

func test_removing_a_module_removes_exactly_its_cells():
	var s := _site()
	var before := s.grid().coords().duplicate()
	var i := s.add(ModuleCatalog.STORE, Vector3i(-3, 0, 0), 0, PackedFloat32Array([1, 1, 1, 1]))
	s.remove(i)
	var after := s.grid().coords()
	before.sort()
	after.sort()
	assert_eq(after, before)

func test_the_same_site_gives_the_same_grid():
	var a := _site().grid()
	var b := _site().grid()
	for c in a.coords():
		assert_eq(b.get_block(c).block_id, a.get_block(c).block_id)
		assert_eq(b.get_block(c).orientation, a.get_block(c).orientation)

func test_it_round_trips_through_a_save():
	var s := _site()
	s.add(ModuleCatalog.DRILL, Vector3i(5, 0, 0), 1, PackedFloat32Array([1, 2, 1, 2]))
	s.modules[1]["drill"] = {"richness": 1.8, "veined": true, "ran": 75.0, "credited_at": 900.0}
	s.store = 123
	s.items = [{"kind": "mug"}]
	s.airlocks = {"1,0,1": {"pressure": 1.0, "open": ""}}
	var back := BaseSite.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.id, s.id)
	assert_eq(back.system, 7)
	assert_true(back.at.is_equal_approx(s.at))
	assert_true(back.turn.is_equal_approx(s.turn))
	assert_eq(back.rock, s.rock)
	assert_eq(back.site_id, s.site_id)
	assert_eq(back.modules.size(), 2)
	assert_eq(back.modules[1]["cell"], Vector3i(5, 0, 0))
	assert_eq(back.modules[1]["turns"], 1)
	assert_almost_eq(float(back.modules[1]["drill"]["richness"]), 1.8, 0.001)
	assert_eq(back.modules[0]["legs"].size(), 4)
	assert_eq(back.store, 123)
	assert_eq(back.items.size(), 1)
	assert_eq(back.airlocks.size(), 1)

func test_a_hub_alone_is_valid():
	assert_true(BaseValidator.ok(BaseValidator.validate(_site(), _blocks)))

func test_rules():
	var none := BaseSite.new()
	assert_true(_codes(BaseValidator.validate(none, _blocks)).has(&"HAS_HUB"))
	var s := _site()
	s.add(ModuleCatalog.DRILL, Vector3i(3, 0, 0), 0, PackedFloat32Array([1, 1, 1, 1]))
	assert_true(_codes(BaseValidator.validate(s, _blocks)).has(&"APART"), "a drill face to face with the hub")
	var apart := _site()
	apart.add(ModuleCatalog.DRILL, Vector3i(4, 0, 0), 0, PackedFloat32Array([1, 1, 1, 1]))
	assert_true(BaseValidator.ok(BaseValidator.validate(apart, _blocks)), "one cell apart is fine")

func _codes(issues: Array) -> Array:
	return issues.map(func(i: ShipValidator.Issue) -> StringName: return i.code)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_base_site.gd`
Expected: FAIL, `BaseSite` not declared.

- [ ] **Step 3: Write `BaseSite`**

`who-knows/src/habitat/base_site.gd`:

```gdscript
class_name BaseSite
extends RefCounted

## A base as data (docs/superpowers/specs/2026-09-26-habitat-modules-design.md
## §9.1, §11.1): where its frame is, which rock it stands on, its modules, its
## store, and -- while it sleeps or is saved -- its airlocks and the items in
## it. All a sleeping base is; what a save keeps. Its grid is the union of its
## modules' prefabs, so the same site always gives the same grid.

var id: StringName
## The star system it is in, by seed.
var system := 0
## The centre of base cell (0, 0, 0), and the frame's rotation: its y is the
## base's up, and its grid is ShipGrid.CELL_SIZE.
var at: UniversePoint = UniversePoint.new()
var turn := Basis.IDENTITY
## The big rock it stands on (AsteroidRock.id()) and its site
## (RockHerds.site_of()).
var rock := Vector4i.ZERO
var site_id: StringName
## {kind, cell, turns, legs, drill}: the module's kind, its origin cell in the
## base's grid, its quarter turns, its four leg lengths, and its drill's state
## ({} unless it is a drill).
var modules: Array = []
var store := 0
## While asleep or saved: each airlock's to_dict(), by cell key, and the items
## in it, in the interior's frame (GridHome.items_to_dict()).
var airlocks: Dictionary = {}
var items: Array = []

## Adds a module; returns its index.
func add(kind: StringName, cell: Vector3i, turns: int, legs: PackedFloat32Array) -> int:
	modules.append({"kind": kind, "cell": cell, "turns": posmod(turns, 4), "legs": legs, "drill": {}})
	return modules.size() - 1

func remove(index: int) -> void:
	modules.remove_at(index)

## The base cells module `index` fills.
func cells_of(index: int) -> Array[Vector3i]:
	var m: Dictionary = modules[index]
	var out: Array[Vector3i] = []
	for b: Array in ModuleCatalog.get_def(m["kind"]).turned(m["turns"]):
		out.append((m["cell"] as Vector3i) + (b[0] as Vector3i))
	return out

## Every filled cell, and the index of the module that fills it.
func occupied() -> Dictionary:
	var out := {}
	for i in modules.size():
		for c in cells_of(i):
			out[c] = i
	return out

## The base's grid: every module's blocks, turned, at its cells.
func grid() -> ShipGrid:
	var g := ShipGrid.new()
	for m: Dictionary in modules:
		for b: Array in ModuleCatalog.get_def(m["kind"]).turned(m["turns"]):
			var inst := BlockInstance.new()
			inst.block_id = b[1]
			inst.orientation = b[2]
			g.set_block((m["cell"] as Vector3i) + (b[0] as Vector3i), inst)
	return g

## Module `index`'s body centre, in the base's frame.
func centre_of(index: int) -> Vector3:
	var m: Dictionary = modules[index]
	var size := ModuleCatalog.get_def(m["kind"]).turned_size(m["turns"])
	return ShipGrid.cell_center(m["cell"]) + Vector3(size - Vector3i.ONE) * ShipGrid.CELL_SIZE * 0.5

func hubs() -> Array[int]:
	return _of(ModuleCatalog.HUB)

func drills() -> Array[int]:
	return _of(ModuleCatalog.DRILL)

func _of(kind: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in modules.size():
		if modules[i]["kind"] == kind:
			out.append(i)
	return out

func to_dict() -> Dictionary:
	var saved := []
	for m: Dictionary in modules:
		saved.append({"kind": String(m["kind"]), "cell": SaveCodec.vec3i(m["cell"]), "turns": m["turns"],
			"legs": Array(m["legs"]), "drill": m["drill"]})
	return {"id": String(id), "system": system, "at": SaveCodec.upoint(at), "turn": SaveCodec.basis(turn),
		"rock": [rock.x, rock.y, rock.z, rock.w], "site": String(site_id), "modules": saved,
		"store": store, "airlocks": airlocks, "items": items}

static func from_dict(d: Dictionary) -> BaseSite:
	var s := BaseSite.new()
	s.id = StringName(d.get("id", ""))
	s.system = int(d.get("system", 0))
	s.at = SaveCodec.to_upoint(d.get("at"))
	s.turn = SaveCodec.to_basis(d.get("turn"))
	var r: Array = d.get("rock", [0, 0, 0, 0])
	s.rock = Vector4i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
	s.site_id = StringName(d.get("site", ""))
	for m in d.get("modules", []):
		if not (m is Dictionary) or ModuleCatalog.get_def(StringName(m.get("kind", ""))) == null:
			continue
		s.modules.append({"kind": StringName(m["kind"]), "cell": SaveCodec.to_vec3i(m.get("cell")),
			"turns": int(m.get("turns", 0)), "legs": PackedFloat32Array(m.get("legs", [])),
			"drill": m.get("drill", {})})
	s.store = int(d.get("store", 0))
	s.airlocks = d.get("airlocks", {})
	s.items = d.get("items", [])
	return s
```

- [ ] **Step 4: Write `BaseValidator`**

`who-knows/src/habitat/base_validator.gd`:

```gdscript
class_name BaseValidator
extends RefCounted

## A base's rules (habitat modules spec §9.1): the ship validator's structural
## ones, none of its flight ones. Until corridors (Phase D), each module is
## checked on its own, and modules stand at least a cell apart so their
## interiors never merge without a corridor.

static func validate(site: BaseSite, catalog: BlockCatalog) -> Array:
	var issues: Array = []
	if site.hubs().is_empty():
		issues.append(ShipValidator.Issue.new(ShipValidator.Severity.ERROR, &"HAS_HUB", "A base needs a hub."))
	var owner := site.occupied()
	for i in site.modules.size():
		var cells := site.cells_of(i)
		_check_connected(cells, issues)
		for c in cells:
			for n: Vector3i in ShipGrid.FACE_OFFSETS:
				if owner.has(c + n) and owner[c + n] != i:
					issues.append(ShipValidator.Issue.new(ShipValidator.Severity.ERROR, &"APART",
						"Modules %d and %d touch at %s." % [i, owner[c + n], c], c))
					break
	var g := site.grid()
	for h in site.hubs():
		_check_hub(g, site.cells_of(h), catalog, issues)
	return issues

static func ok(issues: Array) -> bool:
	return ShipValidator.can_launch(issues)

static func _check_connected(cells: Array[Vector3i], issues: Array) -> void:
	if cells.is_empty():
		return
	var mine := {}
	for c in cells:
		mine[c] = true
	var reached := {cells[0]: true}
	var queue: Array[Vector3i] = [cells[0]]
	while not queue.is_empty():
		var c: Vector3i = queue.pop_back()
		for n: Vector3i in ShipGrid.FACE_OFFSETS:
			if mine.has(c + n) and not reached.has(c + n):
				reached[c + n] = true
				queue.append(c + n)
	if reached.size() != cells.size():
		issues.append(ShipValidator.Issue.new(ShipValidator.Severity.ERROR, &"MODULE_CONNECTED",
			"A module is in pieces.", cells[0]))

## The hub's airlock cycles, and every walkable cell of it is reachable on
## foot from the airlock.
static func _check_hub(g: ShipGrid, cells: Array[Vector3i], catalog: BlockCatalog, issues: Array) -> void:
	var lock := Vector3i.ZERO
	var found := false
	for c in cells:
		if g.get_block(c).block_id == AirlockSite.AIRLOCK_ID:
			lock = c
			found = true
	if not found or AirlockSite.hatch_normal(g, lock) == Vector3i.ZERO:
		issues.append(ShipValidator.Issue.new(ShipValidator.Severity.ERROR, &"AIRLOCK_HATCH",
			"The hub's airlock needs exactly one side onto open space.", lock))
		return
	var graph := DeckGraph.build(g, catalog)
	var home := graph.component_of(lock)
	for c in cells:
		if graph.is_walkable(c) and graph.component_of(c) != home:
			issues.append(ShipValidator.Issue.new(ShipValidator.Severity.ERROR, &"REACHABLE",
				"%s cannot be reached from the hub's airlock." % c, c))
			return
```

- [ ] **Step 5: Re-import and run the test**

Re-import, then run: `./run_tests.ps1 -gselect=test_base_site.gd`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/habitat/base_site.gd who-knows/src/habitat/base_validator.gd who-knows/test/unit/test_base_site.gd
git commit -m "feat: BaseSite and BaseValidator -- a base as data, and its rules"
```

---

### Task 5: `PlantSurface`, `RockSurface` and `Planting`, the fit test

**Files:**
- Create: `who-knows/src/habitat/plant_surface.gd`, `who-knows/src/habitat/rock_surface.gd`, `who-knows/src/habitat/planting.gd`
- Test: `who-knows/test/unit/test_planting.gd`, `who-knows/test/unit/test_rock_surface.gd`

**Interfaces:**
- Produces `PlantSurface extends RefCounted` (an interface; the base does nothing): `up_at(point: Vector3) -> Vector3`, `cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary` (`{position: Vector3, normal: Vector3}` or `{}`), `blocked(box: Transform3D, size: Vector3) -> bool`, `fixed() -> bool`, `site_id() -> StringName`, `rock() -> Vector4i`, `ore() -> Dictionary` (`{seed: int, veined: bool}`).
- Produces `RockSurface extends PlantSurface`: `_init(detail: AsteroidDetail)`, `var detail`.
- Produces `Planting`: `enum Fit { OK, NO_GROUND, TOO_STEEP, LEGS_CANT_REACH, BLOCKED, TOO_FAR, HUB_FIRST, NEAR_SHIP, NO_ROOM }`; inner `class Result` with `fit: Fit`, `frame: Transform3D` (the base's frame, engine space), `cell: Vector3i`, `turns: int`, `body: Transform3D` (body centre, engine space), `size: Vector3` (body box), `legs: PackedFloat32Array`, `feet: PackedVector3Array`; `static fit(surface, module: ModuleDefinition, aim: Vector3, facing: Vector3, turns: int, site: BaseSite = null, frame := Transform3D.IDENTITY, ship_gap := INF, slots_free := true) -> Result`; `static prompt(r: Result, module: ModuleDefinition) -> String`; `static corners(size: Vector3i) -> Array[Vector3]` (frame-local leg tops, unturned size given turned).

- [ ] **Step 1: Write the failing pure test**

`who-knows/test/unit/test_planting.gd`:

```gdscript
extends GutTest

## The fit test (habitat modules spec §5.2), against built surfaces.

## Flat ground at y = `height`, tilted by `tilt` about x; a step of `step` m
## where x > `step_at`. Its up is its normal. A body box is blocked when its
## lowest corner is under the ground.
class Ground extends PlantSurface:
	var height := 0.0
	var tilt := 0.0
	var step := 0.0
	var step_at := INF
	var normal := Vector3.UP
	func _init(p_height := 0.0, p_tilt := 0.0) -> void:
		height = p_height
		tilt = p_tilt
		normal = Basis(Vector3.RIGHT, tilt) * Vector3.UP
	func at(x: float, z: float) -> float:
		return height + z * -tan(tilt) + (step if x > step_at else 0.0)
	func up_at(_point: Vector3) -> Vector3:
		return normal
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		var g := at(to.x, to.z)
		if from.y >= g and to.y <= g:
			return {"position": Vector3(to.x, g, to.z), "normal": normal}
		return {}
	func blocked(box: Transform3D, size: Vector3) -> bool:
		for sx in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				var p := box * (Vector3(sx, -0.5, sz) * size)
				if p.y < at(p.x, p.z) - 0.01:
					return true
		return false
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:test"

var _hub: ModuleDefinition
var _drill: ModuleDefinition

func before_all():
	_hub = ModuleCatalog.get_def(ModuleCatalog.HUB)
	_drill = ModuleCatalog.get_def(ModuleCatalog.DRILL)

func _hub_site(r: Planting.Result) -> BaseSite:
	var s := BaseSite.new()
	s.add(ModuleCatalog.HUB, r.cell, r.turns, r.legs)
	return s

func test_a_hub_fits_on_flat_ground_on_short_legs():
	var r := Planting.fit(Ground.new(), _hub, Vector3(10, 0, 5), Vector3.FORWARD, 0)
	assert_eq(r.fit, Planting.Fit.OK)
	assert_eq(r.legs.size(), 4)
	for leg in r.legs:
		assert_almost_eq(leg, HabitatValues.LEG_MIN + HabitatValues.LEG_SPARE, 0.01)
	assert_almost_eq(r.frame.basis.y, Vector3.UP, Vector3.ONE * 0.001, "a new hub's up is the surface's")
	assert_eq(r.cell, Vector3i.ZERO, "the hub is the base's first module")
	assert_almost_eq(Vector2(r.body.origin.x, r.body.origin.z), Vector2(10, 5), Vector2.ONE * 0.01, "centred on the aim")
	assert_eq(Planting.prompt(r, _hub), "Plant Hub")

func test_a_hub_faces_you():
	var r := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.RIGHT, 0)
	assert_almost_eq(-r.frame.basis.z, Vector3.RIGHT, Vector3.ONE * 0.001)

func test_legs_that_cannot_reach():
	var g := Ground.new()
	g.step = -3.0
	g.step_at = 0.0
	var r := Planting.fit(g, _hub, Vector3(0, 0, 0), Vector3.FORWARD, 0)
	assert_eq(r.fit, Planting.Fit.LEGS_CANT_REACH)
	assert_eq(Planting.prompt(r, _hub), "Legs can't reach")

func test_no_ground_no_ghost():
	var r := Planting.fit(Ground.new(-50.0), _hub, Vector3(0, 0, 0), Vector3.FORWARD, 0)
	assert_eq(r.fit, Planting.Fit.NO_GROUND)
	assert_eq(Planting.prompt(r, _hub), "")

func test_anything_but_a_hub_needs_a_base():
	var r := Planting.fit(Ground.new(), _drill, Vector3.ZERO, Vector3.FORWARD, 0)
	assert_eq(r.fit, Planting.Fit.HUB_FIRST)
	assert_eq(Planting.prompt(r, _drill), "Plant a hub first")

func test_a_drill_snaps_to_the_base_s_grid():
	var hub := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0)
	var site := _hub_site(hub)
	var aim := hub.frame * Vector3(10.3, -2.0, 0.4)
	var r := Planting.fit(Ground.new(), _drill, aim, Vector3.FORWARD, 1, site, hub.frame)
	assert_eq(r.fit, Planting.Fit.OK)
	assert_eq(r.turns, 1)
	assert_eq(r.cell.y, 0, "the same storey on flat ground")
	var local := hub.frame.affine_inverse() * r.body.origin
	var expect := ShipGrid.cell_center(r.cell) \
		+ Vector3(_drill.turned_size(1) - Vector3i.ONE) * ShipGrid.CELL_SIZE * 0.5
	assert_almost_eq(local, expect, Vector3.ONE * 0.01, "its body sits on the base's grid")
	assert_eq(Planting.prompt(r, _drill), "Plant Drill")

func test_touching_a_module_is_blocked():
	var hub := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0)
	var site := _hub_site(hub)
	# The hub's cells run x 0..2: a drill at x 3 touches it.
	var aim := hub.frame * Vector3(6.0, -2.0, 1.0)
	var r := Planting.fit(Ground.new(), _drill, aim, Vector3.FORWARD, 0, site, hub.frame)
	assert_eq(r.fit, Planting.Fit.BLOCKED)
	assert_eq(Planting.prompt(r, _drill), "Blocked")

func test_too_far_from_the_base():
	var hub := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0)
	var r := Planting.fit(Ground.new(), _drill, hub.frame * Vector3(40, -2, 0), Vector3.FORWARD, 0,
		_hub_site(hub), hub.frame)
	assert_eq(r.fit, Planting.Fit.TOO_FAR)
	assert_eq(Planting.prompt(r, _drill), "Too far from the base")

func test_too_steep_for_the_base_s_up():
	var hub := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0)
	var slope := Ground.new(0.0, deg_to_rad(40.0))
	var r := Planting.fit(slope, _drill, hub.frame * Vector3(10, -2, 0), Vector3.FORWARD, 0,
		_hub_site(hub), hub.frame)
	assert_eq(r.fit, Planting.Fit.TOO_STEEP)
	assert_eq(Planting.prompt(r, _drill), "Too steep")

func test_too_close_to_a_ship():
	var r := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0, null, Transform3D.IDENTITY, 12.0)
	assert_eq(r.fit, Planting.Fit.NEAR_SHIP)
	assert_eq(Planting.prompt(r, _hub), "Too close to a ship")

func test_no_room_for_a_new_base():
	var r := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0, null, Transform3D.IDENTITY,
		INF, false)
	assert_eq(r.fit, Planting.Fit.NO_ROOM)
	assert_eq(Planting.prompt(r, _hub), "No room")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_planting.gd`
Expected: FAIL, `PlantSurface` not declared.

- [ ] **Step 3: Write `PlantSurface`**

`who-knows/src/habitat/plant_surface.gd`:

```gdscript
class_name PlantSurface
extends RefCounted

## What planting asks of the ground (habitat modules spec §5.1), so Planting
## never sees a rock. RockSurface is a big rock in detail; a PlanetSurface is
## Planetfall's to add. This base is no ground at all.

## The ground's up at `point`: a rock's averaged normal there.
func up_at(_point: Vector3) -> Vector3:
	return Vector3.UP

## The ground along a ray: {position, normal}, or {} if it misses.
func cast(_from: Vector3, _dir: Vector3, _reach: float) -> Dictionary:
	return {}

## True if a box (centre and rotation `box`, extents `size`) would touch the
## ground, a boulder or a hull.
func blocked(_box: Transform3D, _size: Vector3) -> bool:
	return false

## True if it never moves. Only fixed ground takes a base.
func fixed() -> bool:
	return false

## The place a base on it belongs to, as RockHerds.site_of() names a rock.
func site_id() -> StringName:
	return &""

## The rock's id (AsteroidRock.id()), or zero for ground that is not a rock.
func rock() -> Vector4i:
	return Vector4i.ZERO

## What a drill finds in it: {seed, veined}.
func ore() -> Dictionary:
	return {"seed": 0, "veined": false}
```

- [ ] **Step 4: Write `Planting`**

`who-knows/src/habitat/planting.gd`:

```gdscript
class_name Planting
extends RefCounted

## Where a module fits, and why not (habitat modules spec §5.2), as a pure
## function of the ground (a PlantSurface), the module, where you aim and the
## base it would join. A new hub founds a frame: the ground's up, turned to
## face you. Anything else snaps to its base's grid in quarter turns, at the
## lowest storey whose legs all reach the ground. Each module stands on four
## legs at its footprint's corners.

enum Fit { OK, NO_GROUND, TOO_STEEP, LEGS_CANT_REACH, BLOCKED, TOO_FAR, HUB_FIRST, NEAR_SHIP, NO_ROOM }

const PROMPTS := {
	Fit.NO_GROUND: "",
	Fit.TOO_STEEP: "Too steep",
	Fit.LEGS_CANT_REACH: "Legs can't reach",
	Fit.BLOCKED: "Blocked",
	Fit.TOO_FAR: "Too far from the base",
	Fit.HUB_FIRST: "Plant a hub first",
	Fit.NEAR_SHIP: "Too close to a ship",
	Fit.NO_ROOM: "No room",
}
## The legs stand this far in from the footprint's corners.
const LEG_INSET := 0.25
## Storeys tried above and below the base's floor.
const STOREYS := 2

class Result:
	var fit: int = Fit.NO_GROUND
	## The base's frame (a new hub's own), engine space: origin at the centre
	## of base cell (0, 0, 0), y the base's up.
	var frame := Transform3D.IDENTITY
	var cell := Vector3i.ZERO
	var turns := 0
	## The body's centre and rotation, engine space, and its extents.
	var body := Transform3D.IDENTITY
	var size := Vector3.ZERO
	var legs := PackedFloat32Array()
	var feet := PackedVector3Array()

static func prompt(r: Result, module: ModuleDefinition) -> String:
	if r.fit == Fit.OK:
		return "Plant %s" % module.display_name
	return PROMPTS.get(r.fit, "")

## The fit of `module` turned `turns` quarter turns, aimed at `aim` (a point on
## the ground, engine space) from `facing`. `site` and `frame` are the base it
## would join, or null for none; `ship_gap` is how far `aim` is from the
## nearest hull; `slots_free` whether a new base could get an interior slot.
static func fit(surface: PlantSurface, module: ModuleDefinition, aim: Vector3, facing: Vector3, turns: int,
		site: BaseSite = null, frame := Transform3D.IDENTITY, ship_gap := INF, slots_free := true) -> Result:
	var r := Result.new()
	r.turns = posmod(turns, 4)
	var size := module.turned_size(r.turns)
	r.size = Vector3(size) * ShipGrid.CELL_SIZE - Vector3.ONE * 0.1
	if site == null and module.kind != ModuleCatalog.HUB:
		r.fit = Fit.HUB_FIRST
		return r
	if site == null and not slots_free:
		r.fit = Fit.NO_ROOM
		return r
	if site == null:
		if not _found(surface, size, aim, facing, r):
			return r
	elif not _snap(surface, size, aim, site, frame, r):
		return r
	var normal := _average_normal(surface, r)
	if normal.angle_to(r.frame.basis.y) > HabitatValues.MAX_TILT:
		r.fit = Fit.TOO_STEEP
		return r
	if not _legs_reach(r.legs):
		r.fit = Fit.LEGS_CANT_REACH
		return r
	if surface.blocked(r.body, r.size) or (site != null and _crowds(site, module, r)):
		r.fit = Fit.BLOCKED
		return r
	if site != null and _far(site, r):
		r.fit = Fit.TOO_FAR
		return r
	if ship_gap < HabitatValues.FROM_SHIP:
		r.fit = Fit.NEAR_SHIP
		return r
	r.fit = Fit.OK
	return r

## The leg tops, frame-local, of a module of turned `size` at cell zero: its
## footprint's corners, LEG_INSET in, at the underside of its floor.
static func corners(size: Vector3i) -> Array[Vector3]:
	var half := ShipGrid.CELL_SIZE * 0.5
	var x0 := -half + LEG_INSET
	var x1 := (size.x - 1) * ShipGrid.CELL_SIZE + half - LEG_INSET
	var z0 := -half + LEG_INSET
	var z1 := (size.z - 1) * ShipGrid.CELL_SIZE + half - LEG_INSET
	return [Vector3(x0, -half, z0), Vector3(x1, -half, z0), Vector3(x0, -half, z1), Vector3(x1, -half, z1)]

## A new hub: the ground's up, turned to face `facing`, raised so the highest
## ground under its legs is LEG_MIN + LEG_SPARE below the floor.
static func _found(surface: PlantSurface, size: Vector3i, aim: Vector3, facing: Vector3, r: Result) -> bool:
	var up := surface.up_at(aim).normalized()
	var forward := facing - up * facing.dot(up)
	if forward.length() < 0.01:
		forward = up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK)
	var basis := Basis.looking_at(forward.normalized(), up) * Basis(Vector3.UP, PI * 0.5 * r.turns)
	var centre := Vector3(size - Vector3i.ONE) * ShipGrid.CELL_SIZE * 0.5
	centre.y = 0.0
	var origin := aim - basis * centre
	var highest := -INF
	var hits := []
	for top in corners(size):
		var p := origin + basis * Vector3(top.x, 0.0, top.z)
		var hit := surface.cast(p + up * HabitatValues.CAST_SPARE, -up,
			HabitatValues.CAST_SPARE * 2.0 + HabitatValues.LEG_MAX)
		if hit.is_empty():
			r.fit = Fit.NO_GROUND if hits.is_empty() else Fit.LEGS_CANT_REACH
			r.frame = Transform3D(basis, origin + up * ShipGrid.CELL_SIZE * 0.5)
			return false
		hits.append(hit)
		highest = maxf(highest, (hit["position"] - aim).dot(up))
	var floor_at := highest + HabitatValues.LEG_MIN + HabitatValues.LEG_SPARE
	r.frame = Transform3D(basis, origin + up * (floor_at + ShipGrid.CELL_SIZE * 0.5))
	r.cell = Vector3i.ZERO
	_place(surface, size, r)
	return true

## A module joining a base: its cell under the aim on the base's grid, at the
## lowest storey whose legs all reach. If none reach, the storey whose legs
## come nearest, so fit() can still say whether it is too steep first.
static func _snap(surface: PlantSurface, size: Vector3i, aim: Vector3, _site: BaseSite, frame: Transform3D,
		r: Result) -> bool:
	r.frame = frame
	var local := frame.affine_inverse() * aim
	var cx := roundi(local.x / ShipGrid.CELL_SIZE - (size.x - 1) * 0.5)
	var cz := roundi(local.z / ShipGrid.CELL_SIZE - (size.z - 1) * 0.5)
	var nearest := Vector3i.ZERO
	var nearest_off := INF
	var mid := (HabitatValues.LEG_MIN + HabitatValues.LEG_MAX) * 0.5
	for y in range(-STOREYS, STOREYS + 1):
		r.cell = Vector3i(cx, y, cz)
		_place(surface, size, r)
		if r.legs.size() < 4:
			continue
		if _legs_reach(r.legs):
			return true
		var off := 0.0
		for leg in r.legs:
			off = maxf(off, absf(leg - mid))
		if off < nearest_off:
			nearest_off = off
			nearest = r.cell
	if nearest_off == INF:
		r.fit = Fit.NO_GROUND
		return false
	r.cell = nearest
	_place(surface, size, r)
	return true

static func _legs_reach(legs: PackedFloat32Array) -> bool:
	for leg in legs:
		if leg < HabitatValues.LEG_MIN - 0.001 or leg > HabitatValues.LEG_MAX + 0.001:
			return false
	return true

## Fills the body, legs and feet of `r` at its cell in its frame.
static func _place(surface: PlantSurface, size: Vector3i, r: Result) -> void:
	var at := ShipGrid.cell_center(r.cell)
	var centre := at + Vector3(size - Vector3i.ONE) * ShipGrid.CELL_SIZE * 0.5
	r.body = Transform3D(r.frame.basis, r.frame * centre)
	r.legs = PackedFloat32Array()
	r.feet = PackedVector3Array()
	var up := r.frame.basis.y
	for top in corners(size):
		var p := r.frame * (at + top)
		var hit := surface.cast(p + up * HabitatValues.CAST_SPARE, -up,
			HabitatValues.CAST_SPARE * 2.0 + HabitatValues.LEG_MAX)
		if hit.is_empty():
			return
		r.legs.append((p - hit["position"]).dot(up))
		r.feet.append(hit["position"])

static func _average_normal(surface: PlantSurface, r: Result) -> Vector3:
	var sum := Vector3.ZERO
	var up := r.frame.basis.y
	for foot in r.feet:
		var hit := surface.cast(foot + up * 0.5, -up, 1.0)
		if not hit.is_empty():
			sum += hit["normal"]
	return sum.normalized() if sum.length() > 0.001 else up

## True if any of its cells, or any cell beside one, is another module's.
static func _crowds(site: BaseSite, module: ModuleDefinition, r: Result) -> bool:
	var taken := site.occupied()
	for b: Array in module.turned(r.turns):
		var c: Vector3i = r.cell + (b[0] as Vector3i)
		if taken.has(c):
			return true
		for n: Vector3i in ShipGrid.FACE_OFFSETS:
			if taken.has(c + n):
				return true
	return false

## True if its body is more than FROM_BASE from every module's.
static func _far(site: BaseSite, r: Result) -> bool:
	var here := r.frame.affine_inverse() * r.body.origin
	for i in site.modules.size():
		if site.centre_of(i).distance_to(here) <= HabitatValues.FROM_BASE:
			return false
	return true
```

- [ ] **Step 5: Run the pure test**

Re-import, then run: `./run_tests.ps1 -gselect=test_planting.gd`
Expected: PASS. If `test_a_drill_snaps_to_the_base_s_grid` fails with `LEGS_CANT_REACH`: on flat ground at the hub's height, a storey-0 drill's legs are `LEG_MIN + LEG_SPARE` long, as the hub's are. Check that `_place` puts leg tops at `cell_center + top` (the floor's underside), not at the cell's centre.

- [ ] **Step 6: Write `RockSurface` and its test**

`who-knows/src/habitat/rock_surface.gd`:

```gdscript
class_name RockSurface
extends PlantSurface

## A big rock in detail as ground to plant on (habitat modules spec §5.1):
## fixed, solid as drawn (asteroids spec §18). A rock not in detail offers no
## surface.

## Rays this far round the aim, averaged, give the rock's up there.
const UP_RING := 3.0

var detail: AsteroidDetail

func _init(p_detail: AsteroidDetail) -> void:
	detail = p_detail

func fixed() -> bool:
	return true

func site_id() -> StringName:
	return RockHerds.site_of(detail.rock)

func rock() -> Vector4i:
	return detail.rock.id()

func ore() -> Dictionary:
	return {"seed": hash(detail.rock.id()), "veined": detail.rock.shape == RockMesh.Shape.VEINED}

func up_at(point: Vector3) -> Vector3:
	var radial := (point - detail.global_position).normalized()
	var side := radial.cross(Vector3.UP if absf(radial.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var other := radial.cross(side)
	var sum := Vector3.ZERO
	for offset in [Vector3.ZERO, side, -side, other, -other]:
		var from: Vector3 = point + radial * 6.0 + offset * UP_RING
		var hit := cast(from, -radial, 12.0)
		if not hit.is_empty():
			sum += hit["normal"]
	return sum.normalized() if sum.length() > 0.001 else radial

func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
	if not detail.is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach, AsteroidBody.LAYER)
	var hit := detail.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit["collider"] != detail:
		return {}
	return {"position": hit["position"], "normal": hit["normal"]}

func blocked(box: Transform3D, size: Vector3) -> bool:
	if not detail.is_inside_tree():
		return true
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = box
	query.collision_mask = AsteroidBody.LAYER | 1
	return not detail.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
```

`who-knows/test/unit/test_rock_surface.gd`, against the real start rock (in detail before the first frame, asteroids spec §18):

```gdscript
extends GutTest

## A big rock as ground (habitat modules spec §5.1), on the start's rock.

var _root: Node
var _rock: AsteroidDetail

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	var stream: AsteroidStream = _root.get_node("AsteroidStream")
	_rock = stream.details.nearest(_root.get_node("Ship").exterior.global_position)

func test_the_start_rock_is_ground():
	assert_not_null(_rock, "the start's rock is in detail")
	var s := RockSurface.new(_rock)
	assert_true(s.fixed())
	assert_eq(s.site_id(), RockHerds.site_of(_rock.rock))
	var toward := (_rock.global_position - _root.get_node("Ship").exterior.global_position).normalized()
	var from := _root.get_node("Ship").exterior.global_position
	await wait_physics_frames(2)
	var hit := s.cast(from, toward, 2000.0)
	assert_false(hit.is_empty(), "a ray toward the rock lands on it")
	var up := s.up_at(hit["position"])
	assert_gt(up.dot(-toward), 0.0, "its up points back out")
	var high := Transform3D(Basis.IDENTITY, hit["position"] + up * 20.0)
	assert_false(s.blocked(high, Vector3(6, 4, 4)), "20 m out is clear")
	var low := Transform3D(Basis.IDENTITY, hit["position"] - up * 3.0)
	assert_true(s.blocked(low, Vector3(6, 4, 4)), "half in the rock is blocked")
```

Run: `./run_tests.ps1 -gselect=test_rock_surface.gd`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/habitat/plant_surface.gd who-knows/src/habitat/rock_surface.gd who-knows/src/habitat/planting.gd who-knows/test/unit/test_planting.gd who-knows/test/unit/test_rock_surface.gd
git commit -m "feat: Planting -- where a module fits on a PlantSurface, and why not; RockSurface"
```

---

### Task 6: EVA cargo, carried out, let go and slower

**Files:**
- Modify: `who-knows/src/items/item_definition.gd`, `who-knows/src/avatar/grasp.gd`, `who-knows/src/avatar/suit.gd`, `who-knows/src/avatar/avatar.gd`
- Test: `who-knows/test/unit/test_eva_cargo.gd`

**Interfaces:**
- Produces `ItemDefinition.eva_cargo: bool`, `ItemDefinition.module: StringName`.
- Produces `Grasp.let_go_outside() -> Item` and signal `Grasp.let_go(item: Item)`; `Grasp.can_use()` true for held EVA cargo, carried, aboard or out.
- Produces `Suit.cargo_accel(suit_mass: float, cargo_kg: float) -> float`; `Suit.step(..., accel := ACCEL)`.
- `Avatar` re-emits `Grasp.let_go` as its existing `let_fall(item, true)`, which the flight scene already adopts as a stray.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_eva_cargo.gd`:

```gdscript
extends GutTest

## EVA cargo (habitat modules spec §4.1): a package is carried out onto a
## spacewalk, used there, let go there as a stray, and slows the suit.

class PlantUse extends ItemUse:
	var count := 0
	func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
		count += 1
		return true

var _world: Node3D
var _body: CharacterBody3D
var _grasp: Grasp

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_body = CharacterBody3D.new()
	_world.add_child(_body)
	var head := Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	_body.add_child(head)
	_grasp = Grasp.new()
	_body.add_child(_grasp)
	_grasp.bind(_body, head)
	_grasp.world_root = _world

func _package(cargo := true) -> Item:
	var def := ItemDefinition.new()
	def.id = &"test_package"
	def.mass_kg = 30.0
	def.size = Vector3(0.5, 0.35, 0.5)
	def.grip = ItemDefinition.Grip.CARRY
	def.eva_cargo = cargo
	def.module = &"hub"
	def.use = PlantUse
	def.quantum_value = 400
	var item := Item.new()
	item.setup(def)
	_world.add_child(item)
	return item

func test_held_cargo_can_be_used_on_a_spacewalk():
	var item := _package()
	assert_true(_grasp.take(item))
	_grasp.suspended = true
	assert_true(_grasp.can_use(), "carried, out on a spacewalk")
	assert_true(_grasp.use())
	assert_eq((item.use_node as PlantUse).count, 1)

func test_other_carried_things_still_cannot():
	var item := _package(false)
	assert_true(_grasp.take(item))
	_grasp.suspended = true
	assert_false(_grasp.can_use())

func test_cargo_is_let_go_outside_and_says_so():
	var item := _package()
	_grasp.take(item)
	_grasp.suspended = true
	var space := Node3D.new()
	_world.add_child(space)
	_body.reparent(space)
	watch_signals(_grasp)
	var gone := _grasp.let_go_outside()
	assert_same(gone, item)
	assert_eq(_grasp.mode, Grasp.Mode.EMPTY)
	assert_eq(item.get_parent(), space, "into the space you are in, not the interior")
	assert_signal_emitted_with_parameters(_grasp, "let_go", [item])

func test_nothing_else_is_let_go_outside():
	var item := _package(false)
	_grasp.take(item)
	_grasp.suspended = true
	assert_null(_grasp.let_go_outside())
	assert_same(_grasp.item, item)

func test_cargo_slows_the_suit():
	assert_almost_eq(Suit.cargo_accel(120.0, 30.0), 2.0, 0.001, "2.5 x 120 / 150")
	assert_almost_eq(Suit.cargo_accel(120.0, 0.0), Suit.ACCEL, 0.001)
	var v := Suit.step(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -1), Basis.IDENTITY, false, 1.0, 2.0)
	assert_almost_eq(v.length(), 2.0, 0.001)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_eva_cargo.gd`
Expected: FAIL: `eva_cargo` is not a member of `ItemDefinition`.

- [ ] **Step 3: Add the fields**

In `who-knows/src/items/item_definition.gd`, after `works_outside`:

```gdscript
## Cargo for a spacewalk (habitat modules spec §4.1): a module package. Carried
## out, used and let go outside, though hands are otherwise suspended there;
## made and converted like any other item.
@export var eva_cargo: bool = false
## For a package: the module it unfolds into (ModuleCatalog).
@export var module: StringName = &""
```

- [ ] **Step 4: Teach `Grasp` about cargo**

In `who-knows/src/avatar/grasp.gd`:

Add a signal below `signal taken(...)`:

```gdscript
## EVA cargo let go on a spacewalk (habitat modules spec §4.1): already in the
## space you are in. The holder makes it a stray.
signal let_go(item: Item)
```

Replace `can_use()` with:

```gdscript
## Whether the held item can be used now: in your own view and wielded aboard,
## or out on a spacewalk if it works there (health and damage spec §8.3); or
## carried EVA cargo, anywhere (habitat modules spec §4.1).
func can_use() -> bool:
	if not enabled or not first_person or item == null:
		return false
	if mode == Mode.CARRYING:
		return item.definition.eva_cargo
	return mode == Mode.WIELDING and (not suspended or item.definition.works_outside)
```

Add after `let_fall`:

```gdscript
## Lets go of held EVA cargo on a spacewalk, into the space you are in, where
## it floats (habitat modules spec §4.1). Null, holding on, for anything else.
func let_go_outside() -> Item:
	if not suspended or item == null or not item.definition.eva_cargo:
		return null
	var it := item
	var was := world_root
	world_root = use_world()
	_release()
	world_root = was
	it.set_space(true)
	changed.emit()
	let_go.emit(it)
	return it
```

In `_unhandled_input`, replace

```gdscript
	if not _active():
		return
```

with

```gdscript
	if suspended and event.is_action_pressed(&"drop"):
		let_go_outside()
		return
	if not _active():
		return
```

- [ ] **Step 5: Slow the suit**

In `who-knows/src/avatar/suit.gd`, add after `HOME_GAIN`:

```gdscript
## Thrust with cargo aboard the suit (habitat modules spec §4.1): the same
## force on more mass.
static func cargo_accel(suit_mass: float, cargo_kg: float) -> float:
	return ACCEL * suit_mass / (suit_mass + maxf(cargo_kg, 0.0))
```

Change `step`'s signature to take the thrust, and use it:

```gdscript
static func step(v: Vector3, v_ref: Vector3, thrust_input: Vector3, view: Basis, assist: bool,
		delta: float, accel := ACCEL) -> Vector3:
	var push := thrust_input
	if push.length() > 1.0:
		push = push.normalized()
	v += view * push * accel * delta
	if not assist:
		return v
	var local := view.inverse() * (v - v_ref)
	for axis in 3:
		if is_zero_approx(thrust_input[axis]):
			local[axis] = move_toward(local[axis], 0.0, accel * delta)
	return v_ref + view * local.limit_length(ASSIST_CAP)
```

In `who-knows/src/avatar/avatar.gd`'s `suit_step`, replace the `Suit.step(...)` line with:

```gdscript
	var cargo := grasp.item.definition.mass_kg if grasp.item != null and grasp.item.definition.eva_cargo else 0.0
	var v := Suit.step(velocity, v_ref, input, head.global_basis, suit_assist, delta,
		Suit.cargo_accel(SUIT_MASS, cargo))
```

And in `avatar.gd`, where the avatar sets up its `grasp` (search for `grasp.bind(`), connect the new signal right after:

```gdscript
	grasp.let_go.connect(func(item: Item) -> void: let_fall.emit(item, true))
```

- [ ] **Step 6: Run the tests**

Run: `./run_tests.ps1 -gselect=test_eva_cargo.gd`, then `-gselect=test_grasp.gd`, `-gselect=test_suit.gd`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/items/item_definition.gd who-knows/src/avatar/grasp.gd who-knows/src/avatar/suit.gd who-knows/src/avatar/avatar.gd who-knows/test/unit/test_eva_cargo.gd
git commit -m "feat: EVA cargo -- carried out, used and let go on a spacewalk, and the suit slower for it"
```

---
### Task 7: `Base`, a grid that doesn't fly

**Files:**
- Create: `who-knows/src/habitat/base.gd`, `who-knows/src/habitat/base_exterior.gd`
- Modify: `who-knows/src/quantum/quantum_plant.gd` (`start_fraction`, `can_make`), `who-knows/test/unit/test_visual_style_rules.gd` (`PAINTING_FILES` += `res://src/habitat/base_exterior.gd`)
- Test: `who-knows/test/unit/test_base.gd`

**Interfaces:**
- Consumes: `GridHome` (Task 2), `BaseSite` (Task 4), `HabitatValues`, `Planting.corners` (Task 5).
- Produces `Base extends GridHome`:
  - `static make(site: BaseSite, slot: int, outside_path: NodePath, unfolding := -1) -> Base` builds its node tree in code (Exterior, ExteriorBuilder, Interior, InteriorBuilder, Canopy, CanopyCam, CanopyPortal);
  - vars `site: BaseSite`, `unfolding: int` (the module unfolding, or -1), `unfold_left: float`, `exterior_look: BaseExterior`;
  - signal `unfolded(index: int)`;
  - methods `place(frame: Transform3D)`, `rebuild()`, `begin_unfold(index: int)`, `tick_unfold(delta: float)` (tests call it directly), `capture()` (writes store, airlocks, items into `site`), `restore_inside()` (reads them back), `busy() -> String`, `stamp(index: int)`.
- Produces `BaseExterior extends Node3D`: `build(site: BaseSite)`, `unfold(index: int, t: float, site: BaseSite)` (t from 0 to 1), `leg_count() -> int`.
- `QuantumPlant.start_fraction := 0.5`, `QuantumPlant.can_make := true`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_base.gd`:

```gdscript
extends GutTest

## A base (habitat modules spec §6.1, §9.1): a hub built from its site,
## standing still, boarded like a ship.

var _root: Node3D

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)

func _site() -> BaseSite:
	var s := BaseSite.new()
	s.id = &"Base1"
	s.add(ModuleCatalog.HUB, Vector3i.ZERO, 0, PackedFloat32Array([0.7, 0.7, 0.7, 0.7]))
	return s

func _base(site := _site(), slot := 3, unfolding := -1) -> Base:
	var base := Base.make(site, slot, NodePath(".."), unfolding)
	_root.add_child(base)
	base.place(Transform3D(Basis(Vector3.UP, 0.4), Vector3(100, 20, -50)))
	return base

func test_it_is_a_still_grid_home_in_its_slot():
	var base := _base()
	assert_true(base is GridHome)
	assert_true(base.exterior.freeze, "it never moves")
	assert_eq(base.exterior.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)
	assert_eq(base.exterior.linear_velocity, Vector3.ZERO)
	assert_true(base.exterior.is_in_group(Universe.EXTERIOR_SPACE))
	assert_true(base.exterior.is_in_group(AsteroidStream.SPACE_ANCHOR), "its rock stays in detail under it")
	assert_eq(base.interior.global_position, GridHome.INTERIOR_WORLD_BASE + Vector3(3 * GridHome.SLOT_SPACING, 0, 0))
	assert_almost_eq(base.exterior.global_position, Vector3(100, 20, -50), Vector3.ONE * 0.001)

func test_its_hub_has_an_airlock_that_cycles_and_a_store_that_starts_empty():
	var base := _base()
	assert_eq(base.airlocks.size(), 1)
	for a: Airlock in base.airlocks.values():
		assert_not_null(a.alcove, "an outer hatch on its hull")
		assert_false(a.warping())
	assert_eq(base.quantum.store.capacity, HabitatValues.HUB_STORE)
	assert_eq(base.quantum.store.amount, 0, "never a free half store")

func test_its_terminal_converts_but_never_makes():
	var base := _base()
	var machines := base.interior_builder.quantum_machines()
	assert_eq(machines.size(), 1)
	base.quantum.tick(0.1)
	var cycle: MachineCycle = base.quantum.cycles[machines[0].cell]
	assert_null(cycle.selected_def(), "nothing to make")
	assert_eq(cycle.screen()[0], "NOTHING TO MAKE")

func test_it_has_somewhere_to_wake():
	var base := _base()
	assert_false(base.wake_spots().is_empty())

func test_what_is_in_it_survives_capture_and_restore():
	var base := _base()
	base.quantum.store.credit(150, &"test")
	var mug := Item.new()
	mug.setup(base.item_catalog.get_def(&"mug"))
	base.items.add_child(mug)
	mug.global_position = base.wake_spots()[0].origin + Vector3.UP
	base.capture()
	assert_eq(base.site.store, 150)
	assert_eq(base.site.items.size(), 1)
	assert_eq(base.site.airlocks.size(), 1)
	var again := _base(base.site, 5)
	again.restore_inside()
	assert_eq(again.quantum.store.amount, 150)
	assert_eq(again.items.get_child_count(), 1, "the mug, in the new slot's interior")

func test_unfolding_waits_then_builds_and_stamps():
	var base := _base(_site(), 3, 0)
	assert_eq(base.busy(), "unfolding")
	assert_true(base.airlocks.is_empty(), "the base changes at the end")
	watch_signals(base)
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	assert_eq(base.busy(), "")
	assert_signal_emitted(base, "unfolded")
	assert_eq(base.airlocks.size(), 1)

func test_it_stands_on_legs():
	var base := _base()
	assert_eq(base.exterior_look.leg_count(), 4)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_base.gd`
Expected: FAIL, `Base` not declared.

- [ ] **Step 3: Let a plant start empty and refuse to make**

In `who-knows/src/quantum/quantum_plant.gd`, add after `var cycles`:

```gdscript
## How full a new store starts (spec §3.2): half aboard a ship; a base's
## starts empty (habitat modules spec §6.1).
var start_fraction := 0.5
## False for a base's hub terminal (habitat modules spec §6.1): it converts and
## charges, never makes.
var can_make := true
```

In `bind`, change the store's creation to:

```gdscript
		store = QuantumStore.new(stats.quantum_capacity, roundi(stats.quantum_capacity * start_fraction),
			stats.intact_quantum_capacity)
```

In `_makeable_list`, add as its first line:

```gdscript
	if not can_make:
		return []
```

- [ ] **Step 4: Write `BaseExterior`**

`who-knows/src/habitat/base_exterior.gd`:

```gdscript
class_name BaseExterior
extends Node3D

## A base's outside beyond its hull (habitat modules spec §8.1, §5.3): each
## module's four chunky legs down to the rock, and, while a module unfolds, its
## case flying in, its legs punching down and its body growing out of the
## case, all by transform. In the base's frame, under its Exterior. Built from
## the site's leg lengths, never from the rock, so a waking base needs no
## ground to stand. Colours from HullPalette; no shader.

const LEG_RADIUS := 0.09
const PAD_RADIUS := 0.28
const CASE_SIZE := Vector3(0.5, 0.35, 0.5)
const LAYER := 1

var _legs: Array[MeshInstance3D] = []
var _show: Node3D
var _leg_count := 0

## Every module's legs, from the site.
func build(site: BaseSite) -> void:
	for leg in _legs:
		leg.queue_free()
	_legs.clear()
	var kit := InteriorKit.new(self)
	kit.layer = LAYER
	var count := 0
	for i in site.modules.size():
		count += _add_legs(kit, site, i, 1.0)
	if count > 0:
		_legs.assign(kit.commit())
	_leg_count = count

func leg_count() -> int:
	return _leg_count

## Module `index` at `t` of its unfolding (0..1): the case flies in and
## settles, the legs punch down, the body grows from the case. At 1 the show
## is gone and the hull the rebuild made stands in its place.
func unfold(index: int, t: float, site: BaseSite) -> void:
	if _show != null:
		_show.queue_free()
		_show = null
	if t >= 1.0:
		return
	_show = Node3D.new()
	_show.name = "Unfolding"
	add_child(_show)
	var u := HabitatValues
	var at := t * u.UNFOLD
	var centre := site.centre_of(index)
	var full := Vector3(ModuleCatalog.get_def(site.modules[index]["kind"]).turned_size(site.modules[index]["turns"])) \
		* ShipGrid.CELL_SIZE
	var kit := InteriorKit.new(_show)
	kit.layer = LAYER
	var fly := clampf(at / (u.FLY + u.SETTLE), 0.0, 1.0)
	var grow := clampf((at - u.FLY - u.SETTLE - u.LEGS) / u.WALLS, 0.0, 1.0)
	var size := CASE_SIZE.lerp(full, grow * grow * (3.0 - 2.0 * grow))
	var drop := Vector3.UP * (1.0 - fly) * 6.0
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(centre + drop - Vector3.UP * (full.y - size.y) * 0.5),
		size, minf(0.1, size.x * 0.1), InteriorKit.solid(HullPalette.TRIM))
	var legs := clampf((at - u.FLY - u.SETTLE) / u.LEGS, 0.0, 1.0)
	if legs > 0.0:
		_add_legs(kit, site, index, legs)
	kit.commit()

## The four legs of module `index`, `reach` of the way down. Returns how many.
func _add_legs(kit: InteriorKit, site: BaseSite, index: int, reach: float) -> int:
	var m: Dictionary = site.modules[index]
	var legs: PackedFloat32Array = m["legs"]
	var size := ModuleCatalog.get_def(m["kind"]).turned_size(m["turns"])
	var at := ShipGrid.cell_center(m["cell"])
	var tops := Planting.corners(size)
	var made := 0
	for k in mini(legs.size(), tops.size()):
		var top: Vector3 = at + tops[k]
		var foot := top - Vector3.UP * legs[k] * reach
		kit.tube_between(InteriorKit.Batch.SOLID, top, foot, LEG_RADIUS, InteriorKit.solid(HullPalette.TRIM))
		kit.disc(InteriorKit.Batch.SOLID, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), foot + Vector3.UP * 0.02),
			PAD_RADIUS, InteriorKit.solid(HullPalette.PANEL_LINE))
		made += 1
	return made
```

- [ ] **Step 5: Write `Base`**

`who-knows/src/habitat/base.gd`:

```gdscript
class_name Base
extends GridHome

## A base (docs/superpowers/specs/2026-09-26-habitat-modules-design.md §9.1):
## a ShipGrid that never flies, built from its BaseSite into a still exterior
## (a frozen RigidBody3D, so everything that asks a hull its velocity hears
## zero) and an interior in its own slot. Its nodes are made in code, the same
## four GridHome expects, plus a canopy view so its portholes show the real
## outside. Bases (the manager) makes one when it wakes and frees it when it
## sleeps; everything that must outlive that goes back into the site first
## (capture).

## Module `index` finished unfolding (§5.3): the base has changed.
signal unfolded(index: int)

var site: BaseSite
## The module unfolding, or -1, and how long it has left.
var unfolding := -1
var unfold_left := 0.0
var exterior_look: BaseExterior

var _stamped := false

## A base for `p_site` in interior slot `slot`, its outside `p_outside_path`
## (relative to the base), unfolding module `p_unfolding` if not -1. Add it to
## the tree, then place() it.
static func make(p_site: BaseSite, slot: int, p_outside_path: NodePath, p_unfolding := -1) -> Base:
	var b := Base.new()
	b.name = String(p_site.id)
	b.site = p_site
	b.interior_slot = slot
	b.outside_path = p_outside_path
	b.unfolding = p_unfolding
	b.unfold_left = HabitatValues.UNFOLD if p_unfolding >= 0 else 0.0
	var ext := RigidBody3D.new()
	ext.name = "Exterior"
	b.add_child(ext)
	var eb := ExteriorBuilder.new()
	eb.name = "ExteriorBuilder"
	eb.body_path = NodePath("..")
	ext.add_child(eb)
	var inside := Node3D.new()
	inside.name = "Interior"
	b.add_child(inside)
	var ib := InteriorBuilder.new()
	ib.name = "InteriorBuilder"
	inside.add_child(ib)
	var canopy := SubViewport.new()
	canopy.name = "Canopy"
	canopy.size = Vector2i(1536, 512)
	canopy.render_target_update_mode = SubViewport.UPDATE_DISABLED
	b.add_child(canopy)
	var cam := Camera3D.new()
	cam.name = "CanopyCam"
	cam.current = true
	cam.cull_mask = 1
	cam.fov = 40.0
	canopy.add_child(cam)
	var portal := CanopyPortal.new()
	portal.name = "CanopyPortal"
	portal.viewport_path = NodePath("../Canopy")
	portal.camera_path = NodePath("../Canopy/CanopyCam")
	portal.hull_path = NodePath("../Exterior")
	portal.interior_path = NodePath("../Interior")
	b.add_child(portal)
	return b

func _ready() -> void:
	_setup_home()
	_stocked = true   # nothing to stock: a base's rooms start bare
	exterior.gravity_scale = 0.0
	exterior.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	exterior.freeze = true
	exterior.collision_layer = 1   # exterior_hull
	exterior.collision_mask = 0
	exterior.add_to_group(Universe.EXTERIOR_SPACE)
	exterior.add_to_group(AsteroidStream.SPACE_ANCHOR)
	exterior.set_meta(&"base", self)
	quantum = QuantumPlant.new()
	quantum.name = "Quantum"
	quantum.items = items
	quantum.item_catalog = item_catalog
	quantum.start_fraction = 0.0
	quantum.can_make = false
	add_child(quantum)
	exterior_look = BaseExterior.new()
	exterior_look.name = "BaseExterior"
	exterior.add_child(exterior_look)
	set_own(false)
	rebuild()

func _physics_process(delta: float) -> void:
	if unfolding >= 0:
		tick_unfold(delta)

## Stands its frame at `frame` (engine space): cell (0, 0, 0)'s centre, up y.
func place(frame: Transform3D) -> void:
	exterior.global_transform = frame

## Builds the hull, the interior and the legs from the site, all but the
## module still unfolding. Keeps the store, the airlocks and every item.
func rebuild() -> void:
	var shown := site
	if unfolding >= 0:
		shown = BaseSite.from_dict(site.to_dict())
		shown.remove(unfolding)
	grid = shown.grid()
	var stowed := _stowed_items()
	exterior_builder.bind(grid, catalog)
	interior_builder.bind(grid, catalog)
	exterior_builder.rebuild()
	interior_builder.rebuild()
	_bind_airlocks()
	_reseat(stowed)
	var stats := ShipStats.compute(grid, catalog)
	quantum.bind(interior_builder.quantum_cores(), interior_builder.quantum_machines(), stats)
	exterior_look.build(shown)
	var reach := 0.0
	for c: Vector3i in grid.coords():
		reach = maxf(reach, ShipGrid.cell_center(c).length())
	exterior.set_meta(AsteroidStream.ANCHOR_RADIUS, reach + ShipGrid.CELL_SIZE * 0.87)
	_apply_own()
	_apply_livery()

## Starts module `index` unfolding (§5.3); it is already in the site.
func begin_unfold(index: int) -> void:
	unfolding = index
	unfold_left = HabitatValues.UNFOLD
	_stamped = false

## Advances the unfolding by `delta`: the show, the stamp as the legs land, and
## at the end the rebuild that changes the base. Tests call it directly.
func tick_unfold(delta: float) -> void:
	if unfolding < 0:
		return
	unfold_left = maxf(unfold_left - delta, 0.0)
	var t := 1.0 - unfold_left / HabitatValues.UNFOLD
	exterior_look.unfold(unfolding, t, site)
	var legs_down := HabitatValues.FLY + HabitatValues.SETTLE + HabitatValues.LEGS
	if not _stamped and t * HabitatValues.UNFOLD >= legs_down:
		_stamped = true
		stamp(unfolding)
	if unfold_left <= 0.0:
		var done := unfolding
		unfolding = -1
		rebuild()
		unfolded.emit(done)

## The legs stamping into the rock (§8.4): a vibration through it that
## scatters the herds near.
func stamp(index: int) -> void:
	var at := exterior.global_transform * site.centre_of(index)
	StimulusBus.send(exterior, Stimulus.make(Stimulus.VIBRATION, at, HabitatValues.STAMP_STRENGTH,
		HabitatValues.STAMP_RADIUS, exterior, site.site_id), 0.5)

## Why a save must wait on it, or "": unfolding, or anything GridHome waits on.
func busy() -> String:
	if unfolding >= 0:
		return "unfolding"
	return home_busy()

## Writes what must outlive its nodes into the site: the store, each airlock,
## every item in it (§9.3, §11.1).
func capture() -> void:
	if quantum != null and quantum.store != null:
		site.store = quantum.store.amount
	site.airlocks = {}
	for at: Vector3i in airlocks:
		site.airlocks[SaveCodec.cell_key(at)] = airlocks[at].to_dict()
	site.items = items_to_dict()

## Reads them back after a wake or a load: the store, each airlock, the items.
func restore_inside() -> void:
	if quantum.store != null:
		quantum.store.from_dict({"amount": site.store})
	for key: String in site.airlocks:
		var airlock: Airlock = airlocks.get(SaveCodec.to_cell(key))
		if airlock != null:
			airlock.from_dict(site.airlocks[key])
	for d in site.items:
		if d is Dictionary:
			restore_item(d)
```

- [ ] **Step 6: Add the painting file to the style rules**

In `who-knows/test/unit/test_visual_style_rules.gd`, add `"res://src/habitat/base_exterior.gd",` to `PAINTING_FILES`.

- [ ] **Step 7: Re-import and run the tests**

Re-import, then run: `./run_tests.ps1 -gselect=test_base.gd`, `-gselect=test_visual_style_rules.gd`, `-gselect=test_grid_home.gd`
Expected: all PASS. If `test_what_is_in_it_survives_capture_and_restore` fails because the second base's restore runs before its interior exists: `restore_inside` must be called after `add_child` (which runs `_ready` and `rebuild`), as the test does.

- [ ] **Step 8: Commit**

```bash
git add who-knows/src/habitat/base.gd who-knows/src/habitat/base_exterior.gd who-knows/src/quantum/quantum_plant.gd who-knows/test/unit/test_base.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: Base -- a grid that doesn't fly, on legs, unfolding, with a store that starts empty"
```

---

### Task 8: `Bases`, every base, sleeping and waking

**Files:**
- Create: `who-knows/src/habitat/bases.gd`
- Test: `who-knows/test/unit/test_bases.gd`

**Interfaces:**
- Consumes: `Base` (Task 7), `BaseSite`, `InteriorSlots`, `Universe`, `Planting.Result`, `PlantSurface`.
- Produces `Bases extends Node`:
  - `const GROUP := &"bases"`; signals `joined(base: Base)`, `left(base: Base)`;
  - vars `home: Node`, `outside: Node3D`, `universe: Universe`, `slots: InteriorSlots`, `system: int`, `clock: Callable` (returns play seconds), `inside: Callable` (returns the `Base` you are in or tied to, or null), `next_number := 1`;
  - `sites() -> Array[BaseSite]`, `awake() -> Array[Base]`, `named(id: StringName) -> Base`, `site_named(id) -> BaseSite`, `on(site_id: StringName) -> BaseSite`, `frame_of(site: BaseSite) -> Transform3D`;
  - `plant(kind: StringName, r: Planting.Result, surface: PlantSurface) -> Base` (founds a base for a hub on bare rock, else adds the module to the rock's base; returns the base, or null);
  - `wake(id: StringName) -> Base`, `sleep(id: StringName) -> void`, `check_sleep() -> void`, `busy() -> String`, `nearest(point: Vector3) -> Base` (awake);
  - `to_dict() -> Dictionary`, `from_dict(d: Dictionary) -> void`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_bases.gd`:

```gdscript
extends GutTest

## Every base, sleeping and waking as ships do (habitat modules spec §9.3), in
## the real flight scene with a Bases of its own.

class Ground extends PlantSurface:
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		if from.y >= -30.0 and to.y <= -30.0:
			var t := (from.y + 30.0) / (from.y - to.y)
			return {"position": from.lerp(to, t), "normal": Vector3.UP}
		return {}
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:test"
	func rock() -> Vector4i:
		return Vector4i(1, 2, 3, 4)

var _root: Node
var _bases: Bases

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_bases = Bases.new()
	_bases.home = _root
	_bases.outside = _root.get_node("Outside")
	_bases.universe = _root.get_node("Universe")
	_bases.slots = _root.fleet.slots
	_bases.clock = func() -> float: return 0.0
	_root.add_child(_bases)

func _plant_hub(at := Vector3(0, -30, 60)) -> Base:
	var r := Planting.fit(Ground.new(), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	assert_eq(r.fit, Planting.Fit.OK)
	return _bases.plant(ModuleCatalog.HUB, r, Ground.new())

func test_a_hub_on_bare_rock_founds_a_base_unfolding():
	var base := _plant_hub()
	assert_not_null(base)
	assert_eq(String(base.name), "Base1")
	assert_eq(base.unfolding, 0)
	assert_eq(base.interior_slot, 1, "the next slot after the starter's")
	assert_same(_bases.on(&"rock:test"), base.site)
	assert_eq(base.site.rock, Vector4i(1, 2, 3, 4))
	assert_true(_bases.busy() != "", "a save waits while it unfolds")

func test_a_drill_joins_the_rock_s_base():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	var frame := _bases.frame_of(base.site)
	var r := Planting.fit(Ground.new(), ModuleCatalog.get_def(ModuleCatalog.DRILL), frame * Vector3(10, -2, 0),
		Vector3.FORWARD, 0, base.site, frame)
	assert_eq(r.fit, Planting.Fit.OK)
	assert_same(_bases.plant(ModuleCatalog.DRILL, r, Ground.new()), base)
	assert_eq(base.site.modules.size(), 2)
	assert_eq(base.unfolding, 1)

func test_a_base_sleeps_far_off_and_wakes_near_with_everything_in_it():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	base.quantum.store.credit(77, &"test")
	var slot := base.interior_slot
	var universe: Universe = _root.get_node("Universe")
	universe.origin = universe.origin.plus(Vector3(25000, 0, 0))
	_bases.check_sleep()
	assert_null(_bases.named(&"Base1"), "asleep: no nodes")
	assert_false(_bases.slots.is_held(slot), "its slot is free")
	assert_eq(_bases.site_named(&"Base1").store, 77)
	universe.origin = universe.origin.plus(Vector3(-25000, 0, 0))
	_bases.check_sleep()
	var again := _bases.named(&"Base1")
	assert_not_null(again, "awake again")
	assert_eq(again.quantum.store.amount, 77)

func test_the_base_you_are_in_never_sleeps():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	_bases.inside = func() -> Base: return _bases.named(&"Base1")
	var universe: Universe = _root.get_node("Universe")
	universe.origin = universe.origin.plus(Vector3(25000, 0, 0))
	_bases.check_sleep()
	assert_not_null(_bases.named(&"Base1"))

func test_a_base_that_cannot_get_a_slot_stays_asleep_and_wakes_later():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	var universe: Universe = _root.get_node("Universe")
	universe.origin = universe.origin.plus(Vector3(25000, 0, 0))
	_bases.check_sleep()
	var held: Array[int] = []
	while _bases.slots.free_count() > 0:
		held.append(_bases.slots.claim())
	universe.origin = universe.origin.plus(Vector3(-25000, 0, 0))
	_bases.check_sleep()
	assert_null(_bases.named(&"Base1"), "no slot: still asleep")
	assert_not_null(_bases.site_named(&"Base1"), "and not lost")
	_bases.slots.release(held.pop_back())
	_bases.check_sleep()
	assert_not_null(_bases.named(&"Base1"), "a slot freed: awake")

func test_bases_round_trip_through_a_save():
	var base := _plant_hub()
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	base.quantum.store.credit(40, &"test")
	var saved := JSON.parse_string(JSON.stringify(_bases.to_dict()))
	var other := Bases.new()
	other.from_dict(saved)
	assert_eq(other.next_number, 2)
	assert_eq(other.sites().size(), 1)
	assert_eq(other.site_named(&"Base1").store, 40)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_bases.gd`
Expected: FAIL, `Bases` not declared.

- [ ] **Step 3: Write `Bases`**

`who-knows/src/habitat/bases.gd`:

```gdscript
class_name Bases
extends Node

## Every base in the game (docs/superpowers/specs/
## 2026-09-26-habitat-modules-design.md §9.1, §9.3): the one place that knows
## them. Each is a BaseSite always, and a Base node only while awake: within
## WAKE_AT of the universe's focus, in the current system, with an interior
## slot from the pool it shares with the fleet. Past SLEEP_AT it captures
## what is in it into its site and is freed, slot and all, as a sleeping ship
## is held (many ships spec §5.1). The base you are in never sleeps.

signal joined(base: Base)
signal left(base: Base)

const GROUP := &"bases"
const CHECK_EVERY := 1.0

## Where base nodes go (the flight scene), and their outside.
var home: Node
var outside: Node3D
var universe: Universe
var slots: InteriorSlots
## The current star system, by seed: only its bases wake.
var system := 0
## Seconds of play (the flight scene's play_time): the drills' clock.
var clock: Callable
## The base you are in, or whose suit you wear: never asleep. A Callable
## returning a Base, or null.
var inside: Callable
## The number the next base's name takes (Base1, Base2 ...); it only goes up.
var next_number := 1

var _sites: Dictionary = {}   # StringName -> BaseSite
var _awake: Dictionary = {}   # StringName -> Base
var _check_in := 0.0

func _ready() -> void:
	add_to_group(GROUP)

func _physics_process(delta: float) -> void:
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = CHECK_EVERY
	check_sleep()

func sites() -> Array[BaseSite]:
	var out: Array[BaseSite] = []
	for s: BaseSite in _sites.values():
		out.append(s)
	return out

func awake() -> Array[Base]:
	var out: Array[Base] = []
	for b: Base in _awake.values():
		out.append(b)
	return out

func named(id: StringName) -> Base:
	return _awake.get(id)

func site_named(id: StringName) -> BaseSite:
	return _sites.get(id)

## The base on the ground `site_id` in this system, or null.
func on(site_id: StringName) -> BaseSite:
	for s: BaseSite in _sites.values():
		if s.system == system and s.site_id == site_id:
			return s
	return null

## A site's frame in engine space.
func frame_of(site: BaseSite) -> Transform3D:
	return Transform3D(site.turn, universe.to_engine(site.at))

## The awake base whose frame is nearest `point`, or null.
func nearest(point: Vector3) -> Base:
	var best: Base = null
	for b: Base in _awake.values():
		if best == null or b.exterior.global_position.distance_to(point) \
				< best.exterior.global_position.distance_to(point):
			best = b
	return best

## Plants a module where `r` fits on `surface` (§5.3): a hub on bare ground
## founds a base; anything else joins the ground's base. Returns the base,
## which is unfolding the new module, or null if it could not wake.
func plant(kind: StringName, r: Planting.Result, surface: PlantSurface) -> Base:
	var site := on(surface.site_id())
	if site == null:
		site = BaseSite.new()
		site.id = StringName("Base%d" % next_number)
		next_number += 1
		site.system = system
		site.at = universe.to_universe(r.frame.origin)
		site.turn = r.frame.basis
		site.rock = surface.rock()
		site.site_id = surface.site_id()
		var first := site.add(kind, r.cell, r.turns, r.legs)
		_on_planted(site, first, surface)
		_sites[site.id] = site
		return _wake(site, first)
	var i := site.add(kind, r.cell, r.turns, r.legs)
	_on_planted(site, i, surface)
	var base := named(site.id)
	if base != null:
		base.begin_unfold(i)
	return base

## What a new module of `site` keeps from the ground it was planted on. The
## drill fills this in (Task 13).
func _on_planted(_site: BaseSite, _index: int, _surface: PlantSurface) -> void:
	pass

func wake(id: StringName) -> Base:
	if _awake.has(id):
		return _awake[id]
	var site: BaseSite = _sites.get(id)
	return _wake(site, -1) if site != null else null

func _wake(site: BaseSite, unfolding: int) -> Base:
	var slot := slots.claim()
	if slot < 0:
		push_warning("Bases: no interior slot free for %s" % site.id)
		return null
	var base := Base.make(site, slot, NodePath("../%s" % home.get_path_to(outside)), unfolding)
	home.add_child(base)
	base.place(frame_of(site))
	base.restore_inside()
	_awake[site.id] = base
	joined.emit(base)
	return base

func sleep(id: StringName) -> void:
	var base: Base = _awake.get(id)
	if base == null:
		return
	base.capture()
	_awake.erase(id)
	slots.release(base.interior_slot)
	left.emit(base)
	base.get_parent().remove_child(base)
	base.queue_free()

## Sleeps every awake base past SLEEP_AT of the focus that is calm and not
## yours, and wakes every sleeping one of this system inside WAKE_AT.
func check_sleep() -> void:
	if universe == null or not is_instance_valid(universe.focus):
		return
	var here := universe.to_universe(universe.focus.global_position)
	var mine: Base = inside.call() if inside.is_valid() else null
	for site: BaseSite in _sites.values():
		var base: Base = _awake.get(site.id)
		if site.system != system:
			if base != null and base != mine:
				sleep(site.id)
			continue
		var d := site.at.minus(here).length()
		if base != null:
			if base != mine and d > HabitatValues.SLEEP_AT and base.busy() == "":
				sleep(site.id)
		elif d < HabitatValues.WAKE_AT:
			wake(site.id)

## Why a save must wait on a base, or "".
func busy() -> String:
	for base: Base in _awake.values():
		var why := base.busy()
		if why != "":
			return why
	return ""

## Every base's part of a save (§11.1): awake ones captured first.
func to_dict() -> Dictionary:
	for base: Base in _awake.values():
		base.capture()
	var out := []
	for site: BaseSite in _sites.values():
		out.append(site.to_dict())
	return {"next": next_number, "sites": out}

## Takes a saved game's bases. Call before the first check_sleep: none is awake.
func from_dict(d: Dictionary) -> void:
	next_number = maxi(int(d.get("next", 1)), 1)
	_sites.clear()
	for part in d.get("sites", []):
		if part is Dictionary:
			var site := BaseSite.from_dict(part)
			if not site.modules.is_empty():
				_sites[site.id] = site
```

- [ ] **Step 4: Re-import and run the tests**

Re-import, then run: `./run_tests.ps1 -gselect=test_bases.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/habitat/bases.gd who-knows/test/unit/test_bases.gd
git commit -m "feat: Bases -- every base as a site, awake within 18 km with a slot from the pool"
```

---

### Task 9: The package in hand: the ghost, planting, and the items

**Files:**
- Create: `who-knows/src/habitat/package_use.gd`, `who-knows/src/habitat/package_ghost.gd`, `who-knows/data/items/hub_package.tres`, `drill_package.tres`, `store_package.tres`
- Modify: `who-knows/src/items/item_looks.gd` (looks `package_hub`, `package_drill`, `package_store`), `who-knows/src/ship/interior/interior_palette.gd` (`MODULE_COLOURS`), `who-knows/project.godot` (action `turn_module` on R), `who-knows/scenes/flight_test.gd` (`_make_bases`), `who-knows/test/unit/test_visual_style_rules.gd` (`PAINTING_FILES` += `res://src/habitat/package_ghost.gd`)
- Test: `who-knows/test/unit/test_package_use.gd`

**Interfaces:**
- Consumes: `Bases` (Task 8), `Planting`, `RockSurface`, `ModuleCatalog`, `Grasp` EVA cargo (Task 6), `SuitTie.gap`.
- Produces `PackageUse extends ItemUse`: `use()`, `aim_text()`, `refit(item: Item, aim: Transform3D, holder: Node3D) -> Planting.Result`, `turns: int`, `const SURFACE_LAYER := AsteroidBody.LAYER`.
- Produces `PackageGhost extends Node3D`: `show_fit(r: Planting.Result)`, `hide_fit()`.
- Produces the flight scene's `bases: Bases`, wired in `_make_bases()` right after `_make_fleet()`: `home = self`, `outside = $Outside`, `universe = _universe`, `slots = fleet.slots`, `system = system seed`, `clock = func(): return play_time`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_package_use.gd`:

```gdscript
extends GutTest

## The package in hand (habitat modules spec §4, §5.2, §5.3), in the real
## flight scene, against the start's big rock.

var _root: Node
var _rock: AsteroidDetail
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	var stream: AsteroidStream = _root.get_node("AsteroidStream")
	_rock = stream.details.nearest(_ship.exterior.global_position)
	await wait_physics_frames(2)

func _package(kind := &"hub_package") -> Item:
	var item := Item.new()
	item.setup(_ship.item_catalog.get_def(kind))
	_root.get_node("Outside").add_child(item)
	return item

## An eye 4 m off the rock's surface, looking straight down onto it, where the
## line from the ship toward the rock lands, `side` m across from it. Null if
## that misses.
func _aim(side := Vector2.ZERO) -> Variant:
	var toward := (_rock.global_position - _ship.exterior.global_position).normalized()
	var across := toward.cross(Vector3.UP).normalized()
	var other := toward.cross(across)
	var from := _ship.exterior.global_position + across * side.x + other * side.y
	var hit := RockSurface.new(_rock).cast(from, toward, 2000.0)
	if hit.is_empty():
		return null
	var up: Vector3 = hit["normal"]
	var eye: Vector3 = hit["position"] + up * 4.0
	var hint := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK).normalized()
	return Transform3D(Basis.looking_at(-up, hint), eye)

## The first aim, in a ring of tries across the near face, where a hub fits:
## a rock is lumpy, so one spot may be a crater wall.
func _fitting_aim(item: Item) -> Variant:
	var use: PackageUse = item.use_node
	for side in [Vector2.ZERO, Vector2(15, 0), Vector2(-15, 0), Vector2(0, 15), Vector2(0, -15),
			Vector2(30, 30), Vector2(-30, 30), Vector2(30, -30), Vector2(-30, -30), Vector2(50, 0), Vector2(-50, 0)]:
		var aim: Variant = _aim(side)
		if aim == null:
			continue
		var r := use.refit(item, aim, _root.get_node("Outside"))
		if r != null and r.fit == Planting.Fit.OK:
			return aim
	return null

func test_the_packages_are_cargo_with_values_that_fit_the_bay():
	for id in [&"hub_package", &"drill_package", &"store_package"]:
		var def: ItemDefinition = _ship.item_catalog.get_def(id)
		assert_not_null(def, String(id))
		assert_true(def.eva_cargo, "read back from the .tres")
		assert_ne(def.module, &"")
		assert_not_null(ModuleCatalog.get_def(def.module))
		assert_gt(def.quantum_value, 0)
		assert_lte(maxf(def.size.x, maxf(def.size.y, def.size.z)), 0.55, "fits the bay")
		assert_lte(def.mass_kg, Item.LIFT_LIMIT_KG)
	assert_eq(_ship.item_catalog.get_def(&"hub_package").quantum_value, 400)
	assert_eq(QuantumValues.make_cost(_ship.item_catalog.get_def(&"hub_package")), 800)

func test_the_ship_s_machine_offers_them():
	var ids := QuantumValues.makeable(_ship.item_catalog).map(func(d: ItemDefinition) -> StringName: return d.id)
	for id in [&"hub_package", &"drill_package", &"store_package"]:
		assert_true(ids.has(id))

func test_aimed_at_the_rock_a_hub_fits_and_planting_it_founds_a_base():
	var item := _package()
	var use: PackageUse = item.use_node
	var aim: Variant = _fitting_aim(item)
	assert_not_null(aim, "somewhere on the start rock's near face takes a hub")
	assert_true(use.use(item, aim, _root.get_node("Outside"), null))
	await wait_physics_frames(1)
	assert_eq(_root.bases.awake().size(), 1)
	assert_false(is_instance_valid(item), "the package is used up")

func test_use_retests_the_fit_before_planting():
	var item := _package()
	var use: PackageUse = item.use_node
	assert_not_null(_fitting_aim(item))
	var away := Transform3D(Basis.IDENTITY, _rock.global_position + Vector3(0, _rock.rock.radius + 500.0, 0))
	assert_false(use.use(item, away, _root.get_node("Outside"), null), "nothing under the aim now")
	assert_eq(_root.bases.awake().size(), 0)

func test_a_drill_with_no_base_says_so():
	var item := _package(&"drill_package")
	var use: PackageUse = item.use_node
	var r := use.refit(item, _aim(), _root.get_node("Outside"))
	assert_not_null(r)
	assert_eq(Planting.prompt(r, ModuleCatalog.get_def(&"drill")), "Plant a hub first")

func test_r_turns_the_ghost():
	var item := _package()
	var use: PackageUse = item.use_node
	use.turn()
	assert_eq(use.turns, 1)
	assert_true(InputMap.has_action(&"turn_module"))
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_package_use.gd`
Expected: FAIL, `_root.bases` / `PackageUse` not declared.

- [ ] **Step 3: Add the input action**

In `who-knows/project.godot`, under `[input]`, after the `lights_forward={...}` entry, add an action `turn_module` on physical R (82), copying the exact shape of an existing single-key entry such as `roll_left` and changing only the name and `"physical_keycode":81` to `"physical_keycode":82`. Add no comment. Verify with the test's `InputMap.has_action(&"turn_module")`.

- [ ] **Step 4: Write `PackageGhost`**

`who-knows/src/habitat/package_ghost.gd`:

```gdscript
class_name PackageGhost
extends Node3D

## Where a module would stand (habitat modules spec §5.2): its body at its
## levelled height and its legs down to the ground, flat and see-through,
## SIGNAL_GO where it fits and CORAL where it doesn't. An unshaded
## StandardMaterial3D, so no shader is added. Outside, in the shift group; its
## parent never moves.

const ALPHA := 0.35
const LEG_THICK := 0.12

var _body: MeshInstance3D
var _legs: Array[MeshInstance3D] = []
var _material: StandardMaterial3D

func _ready() -> void:
	add_to_group(Universe.EXTERIOR_SPACE)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_body = MeshInstance3D.new()
	_body.mesh = BoxMesh.new()
	_body.material_override = _material
	add_child(_body)
	for i in 4:
		var leg := MeshInstance3D.new()
		leg.mesh = BoxMesh.new()
		leg.material_override = _material
		add_child(leg)
		_legs.append(leg)
	visible = false

func show_fit(r: Planting.Result) -> void:
	if r == null or r.fit == Planting.Fit.NO_GROUND or r.fit == Planting.Fit.HUB_FIRST:
		hide_fit()
		return
	visible = true
	var colour := InteriorPalette.SIGNAL_GO if r.fit == Planting.Fit.OK else InteriorPalette.CORAL
	colour.a = ALPHA
	_material.albedo_color = colour
	global_transform = Transform3D.IDENTITY
	_body.global_transform = r.body
	(_body.mesh as BoxMesh).size = r.size
	var up := r.frame.basis.y
	for i in _legs.size():
		var leg := _legs[i]
		leg.visible = i < r.feet.size()
		if not leg.visible:
			continue
		var foot: Vector3 = r.feet[i]
		var length: float = r.legs[i]
		(leg.mesh as BoxMesh).size = Vector3(LEG_THICK, maxf(length, 0.05), LEG_THICK)
		leg.global_transform = Transform3D(r.frame.basis, foot + up * length * 0.5)

func hide_fit() -> void:
	visible = false
```

- [ ] **Step 5: Write `PackageUse`**

`who-knows/src/habitat/package_use.gd`:

```gdscript
class_name PackageUse
extends ItemUse

## A module package in hand (habitat modules spec §5.2, §5.3). Aboard it is
## only a heavy case. On a spacewalk, aimed at a big rock within PLANT_REACH,
## it shows a ghost of the module and says whether it fits, re-testing ten
## times a second; R turns it a quarter turn; `use` re-tests once more and, if
## it fits, plants it -- the package is used up and the base unfolds.

const SURFACE_LAYER := AsteroidBody.LAYER

## Quarter turns the ghost is turned by.
var turns := 0

var _ghost: PackageGhost
var _last: Planting.Result
var _surface: PlantSurface
var _since := INF

func _exit_tree() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"turn_module") and _ghost != null and _ghost.visible:
		turn()

func turn() -> void:
	turns = posmod(turns + 1, 4)
	_since = INF

func aim_text(item: Item, aim: Transform3D, holder: CollisionObject3D) -> String:
	if not _outside(holder):
		if _ghost != null:
			_ghost.hide_fit()
		return ""
	_since += get_physics_process_delta_time()
	if _since >= HabitatValues.FIT_EVERY:
		_since = 0.0
		refit(item, aim, holder.get_parent() as Node3D)
	return Planting.prompt(_last, _module(item)) if _last != null else ""

func use(item: Item, aim: Transform3D, world: Node3D, holder: CollisionObject3D) -> bool:
	if holder != null and not _outside(holder):
		return false
	var r := refit(item, aim, world)
	if r == null or r.fit != Planting.Fit.OK:
		return false
	var bases := _bases()
	if bases == null or bases.plant(_module(item).kind, r, _surface) == null:
		return false
	if _ghost != null:
		_ghost.hide_fit()
	Item.consume(item)
	return true

## The fit where `aim` looks now, with the ghost shown in `space` (the space
## you float in, which never moves). Null with nothing to plant on in reach.
func refit(item: Item, aim: Transform3D, space: Node3D) -> Planting.Result:
	_last = null
	_surface = null
	var bases := _bases()
	if bases == null or not is_inside_tree():
		return null
	var from := aim.origin
	var to := from - aim.basis.z * HabitatValues.PLANT_REACH
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, SURFACE_LAYER))
	if hit.is_empty() or not (hit["collider"] is AsteroidDetail):
		if _ghost != null:
			_ghost.hide_fit()
		return null
	_surface = RockSurface.new(hit["collider"])
	var site := bases.on(_surface.site_id())
	var frame := bases.frame_of(site) if site != null else Transform3D.IDENTITY
	_last = Planting.fit(_surface, _module(item), hit["position"], -aim.basis.z, turns, site, frame,
		_ship_gap(hit["position"]), bases.slots.free_count() > 0)
	_show(space)
	return _last

func _show(space: Node3D) -> void:
	if _ghost == null or not is_instance_valid(_ghost):
		if space == null:
			return
		_ghost = PackageGhost.new()
		_ghost.name = "PackageGhost"
		space.add_child(_ghost)
	_ghost.show_fit(_last)

func _module(item: Item) -> ModuleDefinition:
	return ModuleCatalog.get_def(item.definition.module)

func _bases() -> Bases:
	return get_tree().get_first_node_in_group(Bases.GROUP) as Bases if is_inside_tree() else null

## How far `p` is from the nearest ship's hull.
func _ship_gap(p: Vector3) -> float:
	var best := INF
	for node in get_tree().get_nodes_in_group(Ship.GROUP):
		var ship := node as Ship
		if ship != null and ship.visible:
			best = minf(best, SuitTie.gap(ship, p))
	return best

static func _outside(holder: Node) -> bool:
	var avatar := holder as Avatar
	return avatar == null or avatar.mode == Avatar.Mode.SUIT
```

- [ ] **Step 6: The packages' look, palette entry and items**

In `who-knows/src/ship/interior/interior_palette.gd`, after `CRATES`:

```gdscript
## Each module's colour (habitat modules spec §4.1, §8.1): the band across its
## package's lid and round its body.
const MODULE_COLOURS := {&"hub": SKY, &"drill": COPPER, &"store": LAVENDER}
```

In `who-knows/src/items/item_looks.gd`, add `&"package_hub", &"package_drill", &"package_store"` to `LOOKS`; in `build`'s `match look:` add:

```gdscript
		&"package_hub":
			package(kit, size, InteriorPalette.MODULE_COLOURS[&"hub"])
		&"package_drill":
			package(kit, size, InteriorPalette.MODULE_COLOURS[&"drill"])
		&"package_store":
			package(kit, size, InteriorPalette.MODULE_COLOURS[&"store"])
```

and the builder, beside `crate`:

```gdscript
## A module package (habitat modules spec §4.1): a bevelled trim case with two
## terracotta straps, a carrying handle on top, a violet seam round its middle
## and the module's colour in a band across the lid. Designed at 0.5 x 0.35 x 0.5.
static func package(kit: InteriorKit, size: Vector3, band: Color) -> void:
	kit.bevel_box(SOLID, Transform3D.IDENTITY, size - Vector3.ONE * 0.012, 0.04, _c(InteriorPalette.TRIM))
	for x in [-size.x * 0.28, size.x * 0.28]:
		kit.box(SOLID, _at(Vector3(x, 0, 0)), Vector3(0.05, size.y + 0.004, size.z + 0.004), _c(InteriorPalette.BELT))
	kit.box(SOLID, _at(Vector3(0, size.y * 0.5 + 0.002, 0)), Vector3(size.x * 0.3, 0.006, size.z * 0.98), _c(band))
	kit.box(GLOW, _at(Vector3.ZERO), Vector3(size.x + 0.006, 0.012, size.z + 0.006),
		InteriorKit.lit(InteriorPalette.QUANTUM, 1.2))
	kit.tube_between(SOLID, Vector3(-0.08, size.y * 0.5 + 0.01, 0), Vector3(-0.08, size.y * 0.5 + 0.06, 0),
		0.012, _c(InteriorPalette.GUNMETAL))
	kit.tube_between(SOLID, Vector3(0.08, size.y * 0.5 + 0.01, 0), Vector3(0.08, size.y * 0.5 + 0.06, 0),
		0.012, _c(InteriorPalette.GUNMETAL))
	kit.tube_between(SOLID, Vector3(-0.08, size.y * 0.5 + 0.06, 0), Vector3(0.08, size.y * 0.5 + 0.06, 0),
		0.014, _c(InteriorPalette.GUNMETAL))
```

Create the three items by copying `who-knows/data/items/crate.tres` and editing it. The copy needs a second `ext_resource` for the use script, so `load_steps` goes to 3. `hub_package.tres` in full (no comments):

```
[gd_resource type="Resource" script_class="ItemDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/items/item_definition.gd" id="1_def"]
[ext_resource type="Script" path="res://src/habitat/package_use.gd" id="2_use"]

[resource]
script = ExtResource("1_def")
id = &"hub_package"
display_name = "Hub Package"
mass_kg = 30.0
size = Vector3(0.5, 0.35, 0.5)
grip = 1
stow_class = &"crate"
look = &"package_hub"
use = ExtResource("2_use")
quantum_value = 400
eva_cargo = true
module = &"hub"
```

`drill_package.tres` is the same with `id = &"drill_package"`, `display_name = "Drill Package"`, `look = &"package_drill"`, `quantum_value = 300`, `module = &"drill"`. `store_package.tres` with `id = &"store_package"`, `display_name = "Store Package"`, `look = &"package_store"`, `quantum_value = 250`, `module = &"store"`.

- [ ] **Step 7: Put `Bases` in the flight scene**

In `who-knows/scenes/flight_test.gd`:

Add a var below `var suit_tie: SuitTie`:

```gdscript
## Every base (habitat modules spec §9.1).
var bases: Bases
```

In `_ready`, call `_make_bases()` on the line after `_make_fleet()`, and add:

```gdscript
## Every base (habitat modules spec §9.3): sharing the fleet's interior slots,
## and play time as the drills' clock. Its system is set in _wire_universe,
## once the system exists.
func _make_bases() -> void:
	bases = Bases.new()
	bases.name = "Bases"
	bases.home = self
	bases.outside = $Outside
	bases.universe = _universe
	bases.slots = fleet.slots
	bases.clock = func() -> float: return play_time
	add_child(bases)
```

In `_wire_universe`, on the line after `system = SystemRecipe.from_seed(_stream.seed)`, add `bases.system = system.seed`.

In `_wire_saving()`, add `save_gate.add_source(func() -> String: return bases.busy())`.

Add `"res://src/habitat/package_ghost.gd",` to `PAINTING_FILES` in `test_visual_style_rules.gd`.

- [ ] **Step 8: Re-import and run the tests**

Re-import, then run: `./run_tests.ps1 -gselect=test_package_use.gd`, `-gselect=test_eva_cargo.gd`, `-gselect=test_visual_style_rules.gd`, and every test file whose name starts `test_item` or `test_quantum` (list them with `ls test/unit/test_item*.gd test/unit/test_quantum*.gd`: the item looks and the make list both changed).
Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
git add who-knows/src/habitat/package_use.gd who-knows/src/habitat/package_ghost.gd who-knows/data/items/hub_package.tres who-knows/data/items/drill_package.tres who-knows/data/items/store_package.tres who-knows/src/items/item_looks.gd who-knows/src/ship/interior/interior_palette.gd who-knows/project.godot who-knows/scenes/flight_test.gd who-knows/test/unit/test_package_use.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: module packages -- made at the machine, a ghost on the rock, planted with use"
```

---
### Task 10: Boarding a base

**Files:**
- Modify: `who-knows/scenes/flight_test.gd`, `who-knows/src/ship/suit_tie.gd`, `who-knows/src/ui/vehicle_telemetry.gd`, `who-knows/src/ui/airlock_marker.gd`, `who-knows/src/avatar/avatar.gd`
- Test: `who-knows/test/unit/test_base_boarding.gd`; rerun `test_suit_tie.gd`, `test_fleet.gd`, `test_floating_origin_scene.gd`

**Interfaces:**
- Consumes: `Bases` (Tasks 8, 9), `GridHome` (Task 2).
- Produces in the flight scene:
  - `var home: GridHome`: the place you are in, or whose suit you wear (a ship, then `== aboard`, or a base);
  - `signal home_changed(home: GridHome)`;
  - `board_base(base: Base) -> void`;
  - `fleet.aboard` now answers `aboard` only while `home == aboard` (so your ship can sleep while you are in a base); `bases.inside` answers `home as Base`.
- `SuitTie`: `var bases: Bases`; `current: Callable` returns a `GridHome`; signal `tied(home: GridHome)`; `static gap(home: GridHome, p: Vector3) -> float`.
- `VehicleTelemetry`: `has_other_beacon: bool`, `other_beacon: Vector3`, `other_label: String`. `Avatar.other_beacon_source: Callable` returns `{at: Vector3, label: String}` or `{}`. `AirlockMarker.other: bool`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_base_boarding.gd`:

```gdscript
extends GutTest

## Boarding a base (habitat modules spec §5.5, §11.3): in through its airlock
## it is where you are; your ship may sleep; the suit's home is the nearer of
## a ship or a base; and a blackout inside wakes you there, at its cost.

class Ground extends PlantSurface:
	var y := 0.0
	func _init(p_y: float) -> void:
		y = p_y
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		if from.y >= y and to.y <= y:
			return {"position": from.lerp(to, (from.y - y) / (from.y - to.y)), "normal": Vector3.UP}
		return {}
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:boarding"

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _base: Base

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	var at := _ship.exterior.global_position + Vector3(0, -40, 60)
	var r := Planting.fit(Ground.new(at.y), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	_base = _root.bases.plant(ModuleCatalog.HUB, r, Ground.new(at.y))
	_base.tick_unfold(HabitatValues.UNFOLD + 0.1)

func _step_in() -> void:
	_avatar.move_aboard(_base.interior, _base.wake_spots()[0])
	_base.airlock_crossed.emit(_avatar, false)

func test_in_through_its_airlock_you_are_in_the_base():
	_step_in()
	assert_same(_root.home, _base)
	assert_same(_root.aboard, _ship, "your ship is still yours")
	assert_true(_base.own, "its interior shows")
	assert_false(_ship.own, "the ship's does not")
	assert_same(_avatar.grasp.world_root, _base.items, "what you put down stays in the base")
	assert_same(_root.get_node("Universe").focus, _base.exterior)

func test_your_ship_may_sleep_while_you_are_in_a_base():
	_step_in()
	assert_null(_root.fleet.aboard.call(), "the fleet holds no ship awake for you")
	assert_same(_root.bases.inside.call(), _base, "the base you are in never sleeps")

func test_boarding_the_ship_again_puts_you_back_aboard():
	_step_in()
	_root.board(_ship, true)
	assert_same(_root.home, _ship)
	assert_true(_ship.own)
	assert_false(_base.own)
	assert_same(_root.fleet.aboard.call(), _ship)

func test_the_suit_s_home_is_the_nearer_of_a_ship_or_a_base():
	var lock: Airlock = _base.airlocks.values()[0]
	var near_base := _base.exterior.global_transform * (lock.alcove.outer_frame * Vector3(0, 0.3, -6.0))
	_avatar.enter_suit(_base.outside, Transform3D(Basis.IDENTITY, near_base), Vector3.ZERO, _ship.exterior)
	_root.suit_tie.check()
	assert_same(_root.home, _base)
	assert_same(_avatar.hull, _base.exterior, "relative speed is to the base: zero")
	assert_same(_avatar.beacon_source.get_object(), lock, "home is its airlock")

func test_the_other_marker_points_at_the_other_kind_of_home():
	var lock: Airlock = _base.airlocks.values()[0]
	var near_base := _base.exterior.global_transform * (lock.alcove.outer_frame * Vector3(0, 0.3, -6.0))
	_avatar.enter_suit(_base.outside, Transform3D(Basis.IDENTITY, near_base), Vector3.ZERO, _ship.exterior)
	_root.suit_tie.check()
	var t := _avatar.build_telemetry()
	assert_true(t.has_other_beacon)
	assert_eq(t.other_label, "SHIP")

func test_blacking_out_in_a_base_wakes_you_there_at_the_base_s_cost():
	_step_in()
	_base.quantum.store.credit(120, &"test")
	var ship_before := _ship.quantum.store.amount
	var paid: int = _avatar.rescue_cost.call(50)
	assert_eq(paid, 50)
	assert_eq(_base.quantum.store.amount, 70, "the base pays")
	assert_eq(_ship.quantum.store.amount, ship_before, "never the ship")
	_root._rescue(_avatar)
	assert_eq(_avatar.get_parent(), _base.interior, "you wake in the base")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_base_boarding.gd`
Expected: FAIL: `home` is not a member of the flight scene.

- [ ] **Step 3: Generalise `SuitTie` to any home**

Replace `who-knows/src/ship/suit_tie.gd`'s body below the header comment with:

```gdscript
signal tied(home: GridHome)

const SWITCH_MARGIN := 10.0
const REACH := 500.0
const EVERY := 0.25

var fleet: Fleet
## Every base, whose awake ones a suit can belong to (habitat modules spec
## §5.5). Optional.
var bases: Bases
var avatar: Avatar
## The home the suit belongs to now (a Callable returning a GridHome).
var current: Callable

var _in := 0.0

func _physics_process(delta: float) -> void:
	_in -= delta
	if _in > 0.0:
		return
	_in = EVERY
	check()

## Ties the suit to a nearer ship or base if there is one, now.
func check() -> void:
	if avatar == null or fleet == null or avatar.mode != Avatar.Mode.SUIT:
		return
	var homes: Array[GridHome] = []
	for ship in fleet.awake():
		homes.append(ship)
	if bases != null:
		for base in bases.awake():
			if base.unfolding < 0:
				homes.append(base)
	var gaps: Array[float] = []
	for h in homes:
		gaps.append(gap(h, avatar.global_position))
	var mine: GridHome = current.call() if current.is_valid() else null
	var i := choose(homes.find(mine), gaps)
	if i >= 0 and homes[i] != mine:
		tied.emit(homes[i])

## How far `p` is from `home`'s hull: from the middle of its bounds, less half
## their diagonal. Rough, and the same rough for every home.
static func gap(home: GridHome, p: Vector3) -> float:
	var box := home.exterior_builder.bounds()
	var centre := home.exterior.global_transform * box.get_center()
	return maxf(p.distance_to(centre) - box.size.length() * 0.5, 0.0)
```

Keep `choose()` as it is. Update the header comment's first line to "Which ship or base your suit belongs to on a spacewalk (many ships spec §4.3; habitat modules spec §5.5)".

- [ ] **Step 4: The second marker**

In `who-knows/src/ui/vehicle_telemetry.gd`, after `var has_beacon`:

```gdscript
## The other kind of home on a spacewalk (habitat modules spec §5.5): your
## ship's airlock when your suit is a base's, the nearest base's when it is a
## ship's.
var has_other_beacon: bool = false
var other_beacon: Vector3 = Vector3.ZERO
var other_label: String = ""
```

In `who-knows/src/avatar/avatar.gd`, beside `beacon_source`:

```gdscript
## The other kind of home's airlock (habitat modules spec §5.5): returns
## {at: Vector3, label: String}, or {} when there is none.
var other_beacon_source: Callable
```

and in `build_telemetry`, after the `beacon_source` block:

```gdscript
	if other_beacon_source.is_valid():
		var other: Dictionary = other_beacon_source.call()
		if not other.is_empty():
			t.has_other_beacon = true
			t.other_beacon = other["at"]
			t.other_label = other["label"]
```

In `who-knows/src/ui/airlock_marker.gd`, add `var other := false` beside `var shown`, and in `render` replace the two reads of the beacon:

```gdscript
	var has := telemetry != null and (telemetry.has_other_beacon if other else telemetry.has_beacon)
	shown = has and cam != null
	if not shown:
		mode = VelocityMarker.Mode.HIDDEN
		queue_redraw()
		return
	var beacon := telemetry.other_beacon if other else telemetry.beacon
	_label = telemetry.other_label if other else "AIRLOCK"
	var state := VelocityMarker.resolve(INF, cam.is_position_behind(beacon),
		cam.unproject_position(beacon), size)
	mode = state["mode"]
	_position = state["position"]
	distance = cam.global_position.distance_to(beacon)
	queue_redraw()
```

with `var _label := "AIRLOCK"` beside `_position`, and in `_draw` `var text := "%s %d M" % [_label, roundi(distance)]`.

- [ ] **Step 5: The flight scene's `home`**

In `who-knows/scenes/flight_test.gd`:

1. Below `signal aboard_changed`, add `signal home_changed(home: GridHome)`. Below `var aboard: Ship`, add:

```gdscript
## Where you are (habitat modules spec §5.5): the ship you are aboard or the
## base you are in, or the one your suit belongs to on a spacewalk. A ship
## here is always `aboard`.
var home: GridHome
```

2. In `_make_fleet`, replace `fleet.aboard = func() -> Ship: return aboard` with

```gdscript
	# In a base you are aboard no ship, so yours may sleep (habitat modules
	# spec §9.3).
	fleet.aboard = func() -> Ship: return aboard if home == aboard else null
```

and after `aboard = _starter` add `home = _starter`.

3. In `_make_bases` (Task 9), add before `add_child(bases)`:

```gdscript
	bases.inside = func() -> Base: return home as Base
	bases.joined.connect(_wire_base)
```

and add:

```gdscript
## In through a base's airlock, you are in it.
func _wire_base(base: Base) -> void:
	base.airlock_crossed.connect(func(_who: Avatar, outward: bool) -> void:
		if not outward:
			board_base(base))
	base.set_own(base == home)
```

4. In `_make_suit_tie`, set `suit_tie.bases = bases`, change `current` to `func() -> GridHome: return home`. `_make_suit_tie()` runs before `_make_bases()` in `_ready`: move the `_make_bases()` call up to just after `_make_fleet()` if it is not there already, so `bases` exists.

5. Replace `_tie_suit` and `_nearest_airlock`:

```gdscript
## Your suit is `to`'s now: speed relative to its hull, home its nearest
## airlock, and you are its.
func _tie_suit(to: GridHome) -> void:
	_avatar.hull = to.exterior
	var lock := _nearest_airlock(to, _avatar.global_position)
	if lock != null:
		_avatar.beacon_source = lock.beacon
		_avatar.home_source = lock.home
	if to is Ship:
		board(to)
	else:
		board_base(to as Base)

## `to`'s airlock with a hatch on the hull nearest `p`, or null.
static func _nearest_airlock(to: GridHome, p: Vector3) -> Airlock:
	var best: Airlock = null
	for lock: Airlock in to.airlocks.values():
		if not is_instance_valid(lock.alcove):
			continue
		if best == null or lock.beacon().distance_to(p) < best.beacon().distance_to(p):
			best = lock
	return best
```

6. In `board(ship, force)`, after `aboard = ship` add `home = ship`, and after the loop that un-owns other ships add:

```gdscript
	if bases != null:
		for b in bases.awake():
			b.set_own(false)
```

At its end, after `aboard_changed.emit(ship)`, add `home_changed.emit(ship)`.

7. Add:

```gdscript
## Puts you in `base` (habitat modules spec §5.5): its interior shown and its
## hull your own, no ship's; what you put down stays in it; the origin follows
## it, or you on a spacewalk; and your ship may sleep. Your ship stays
## `aboard`: its helm, warp and sensors are still the ones you use.
func board_base(base: Base, force := false) -> void:
	if base == null or (base == home and not force):
		return
	home = base
	for s in fleet.ships():
		if s.own:
			s.set_own(false)
	for b in bases.awake():
		b.set_own(b == base)
	_avatar.grasp.world_root = base.items
	_avatar.external_accel = Vector3.ZERO
	_universe.set_focus(_avatar if _avatar.mode == Avatar.Mode.SUIT else base.exterior)
	home_changed.emit(base)
```

8. In `_wire_universe`'s `mode_changed` handler, replace `aboard.exterior` with `home.exterior`.

9. In `_wire_hurt`, `rescue_cost` drains `home.quantum.store` instead of `aboard`'s. In `_rescue`, replace both `aboard.` with `home.`.

10. Point the other marker. After `_wire_hud()` in `_ready`, call `_wire_other_marker()`:

```gdscript
## The second airlock marker on a spacewalk (habitat modules spec §5.5): your
## ship's when your suit is a base's, the nearest base's when it is a ship's.
func _wire_other_marker() -> void:
	var marker := AirlockMarker.new()
	marker.name = "OtherAirlockMarker"
	marker.other = true
	marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HudRoot/Screen.add_child(marker)
	if not _hud.is_ancestor_of(marker):
		_hud.register_element(marker)
	_avatar.other_beacon_source = func() -> Dictionary:
		var to: GridHome = aboard if home is Base else bases.nearest(_avatar.global_position)
		if to == null or (to is Ship and fleet.sleeping(to)):
			return {}
		var lock := _nearest_airlock(to, _avatar.global_position)
		if lock == null:
			return {}
		return {"at": lock.beacon(), "label": "SHIP" if to is Ship else "BASE"}
```

- [ ] **Step 6: Run the tests**

Run: `./run_tests.ps1 -gselect=test_base_boarding.gd`, then `-gselect=test_suit_tie.gd`, `-gselect=test_fleet.gd`, `-gselect=test_floating_origin_scene.gd`, `-gselect=test_save_scene.gd`
Expected: all PASS. `test_suit_tie.gd` calls `SuitTie.gap(ship, p)` with a `Ship`, which is a `GridHome`, so it still passes.

- [ ] **Step 7: Extend the floating-origin test**

In `who-knows/test/unit/test_floating_origin_scene.gd`, add a test that plants a hub with `Bases.plant` as `test_base_boarding.gd` does, runs the unfold out, lets a hub package float outside as a stray (`_root.strays.adopt(item)` after `item.set_space(true)` under `Outside`), and then runs the file's existing coverage check over the whole scene. Add a second assertion that, after moving the universe's origin 25 km and calling `_root.bases.check_sleep()`, no node named `Base1` is left in the tree.

Run: `./run_tests.ps1 -gselect=test_floating_origin_scene.gd`
Expected: PASS.

- [ ] **Step 8: Play `fleet_play.gd`**

Run it as in Task 2, Step 7. Expected: zero fails; nothing about ships changed.

- [ ] **Step 9: Commit**

```bash
git add who-knows/scenes/flight_test.gd who-knows/src/ship/suit_tie.gd who-knows/src/ui/vehicle_telemetry.gd who-knows/src/ui/airlock_marker.gd who-knows/src/avatar/avatar.gd who-knows/test/unit/test_base_boarding.gd who-knows/test/unit/test_floating_origin_scene.gd
git commit -m "feat: boarding a base -- in through its airlock, your ship may sleep, the suit's home is the nearer"
```

---

### Task 11: Saving bases (format 3)

**Files:**
- Modify: `who-knows/src/save/save_game.gd`, `who-knows/scenes/flight_test.gd`
- Test: `who-knows/test/unit/test_save_bases.gd`; add a migration case to `who-knows/test/unit/test_save_game.gd`

**Interfaces:**
- Consumes: `Bases.to_dict/from_dict/wake/site_named` (Task 8), `home`/`board_base` (Task 10).
- Produces: save format 3 with top-level `"bases": {"next": int, "sites": [BaseSite.to_dict()...]}` and `"home": {"base": "Base1"}` (or `{}` aboard a ship). `SaveGame.FORMAT == 3`; `SaveGame.migrate` takes 1 and 2 to 3.

- [ ] **Step 1: Write the failing tests**

Add to `who-knows/test/unit/test_save_game.gd`:

```gdscript
func test_format_2_migrates_to_3_with_no_bases():
	var two := {"format": 2, "ships": [], "aboard": "Ship", "fleet": {"next": 2}}
	var three := SaveGame.migrate(two)
	assert_eq(int(three["format"]), 3)
	assert_eq(three["bases"], {"next": 1, "sites": []})
	assert_eq(three["home"], {})
```

`who-knows/test/unit/test_save_bases.gd`:

```gdscript
extends GutTest

## Bases through a save and a load (habitat modules spec §11), in the real
## flight scene, at the test's own path.

const SCENE := "res://scenes/flight_test.tscn"
const DIR := "user://test_save_bases"
const PATH := DIR + "/game.json"

class Ground extends PlantSurface:
	var y := 0.0
	func _init(p_y: float) -> void:
		y = p_y
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		if from.y >= y and to.y <= y:
			return {"position": from.lerp(to, (from.y - y) / (from.y - to.y)), "normal": Vector3.UP}
		return {}
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:save"

var _real_save_time := 0

func before_all():
	_real_save_time = FileAccess.get_modified_time(SaveGame.DEFAULT_PATH) if FileAccess.file_exists(SaveGame.DEFAULT_PATH) else 0

func after_all():
	var now := FileAccess.get_modified_time(SaveGame.DEFAULT_PATH) if FileAccess.file_exists(SaveGame.DEFAULT_PATH) else 0
	assert_eq(now, _real_save_time, "the owner's real save is untouched")

func before_each():
	_clear()

func after_each():
	_clear()

func _clear() -> void:
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

func _scene() -> Node:
	var root: Node = load(SCENE).instantiate()
	root.save_enabled = true
	root.save_path = PATH
	add_child(root)
	return root

func _drop(root: Node) -> void:
	remove_child(root)
	root.free()

func _plant(root: Node) -> Base:
	var ship: Ship = root.get_node("Ship")
	var at := ship.exterior.global_position + Vector3(0, -40, 60)
	var r := Planting.fit(Ground.new(at.y), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	var base: Base = root.bases.plant(ModuleCatalog.HUB, r, Ground.new(at.y))
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	return base

func test_a_base_round_trips():
	var root := _scene()
	var base := _plant(root)
	base.quantum.store.credit(90, &"test")
	var mug := Item.new()
	mug.setup(base.item_catalog.get_def(&"mug"))
	base.items.add_child(mug)
	mug.global_position = base.wake_spots()[0].origin + Vector3.UP * 0.3
	var where := base.exterior.global_transform
	assert_true(root.save_now())
	_drop(root)
	var again := _scene()
	await wait_physics_frames(2)
	var back: Base = again.bases.named(&"Base1")
	assert_not_null(back, "awake: it is near")
	assert_eq(back.quantum.store.amount, 90)
	assert_eq(back.items.get_children().filter(func(n): return n is Item).size(), 1, "the mug")
	assert_almost_eq(back.exterior.global_transform.origin, where.origin, Vector3.ONE * 0.05)
	assert_eq(again.bases.next_number, 2)
	_drop(again)

func test_a_save_inside_a_base_loads_you_inside_it_with_the_ship_asleep():
	var root := _scene()
	var base := _plant(root)
	var avatar: Avatar = root.get_node("Ship/Interior/Avatar")
	avatar.move_aboard(base.interior, base.wake_spots()[0])
	root.board_base(base)
	var ship: Ship = root.get_node("Ship")
	ship.exterior.global_position += Vector3(25000, 0, 0)
	ship.exterior.linear_velocity = Vector3.ZERO
	assert_true(root.save_now())
	_drop(root)
	var again := _scene()
	await wait_physics_frames(2)
	var back: Base = again.bases.named(&"Base1")
	assert_same(again.home, back, "you are in the base")
	assert_eq(again.get_node("Ship/Interior/Avatar").get_parent(), back.interior)
	again.fleet.check_sleep()
	assert_true(again.fleet.sleeping(again.get_node("Ship")), "your ship, 25 km off, asleep")
	_drop(again)

func test_the_gate_waits_while_a_module_unfolds():
	var root := _scene()
	var ship: Ship = root.get_node("Ship")
	var at := ship.exterior.global_position + Vector3(0, -40, 60)
	var r := Planting.fit(Ground.new(at.y), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	root.bases.plant(ModuleCatalog.HUB, r, Ground.new(at.y))
	assert_eq(root.bases.busy(), "unfolding")
	_drop(root)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `./run_tests.ps1 -gselect=test_save_game.gd` and `-gselect=test_save_bases.gd`
Expected: FAIL: format is 2; bases are not saved.

- [ ] **Step 3: Format 3**

In `who-knows/src/save/save_game.gd`: `const FORMAT := 3`. In `migrate`, after the format-1 step:

```gdscript
	if int(out.get("format", 1)) < 3:
		out = _to_bases(out)
```

and add:

```gdscript
## Format 2 to 3 (habitat modules spec §11.1): no bases yet, and you are not in
## one.
static func _to_bases(data: Dictionary) -> Dictionary:
	var out := data.duplicate()
	out["bases"] = {"next": 1, "sites": []}
	out["home"] = {}
	out["format"] = 3
	return out
```

- [ ] **Step 4: Capture**

In `who-knows/scenes/flight_test.gd`'s `capture()`, add two entries:

```gdscript
		"bases": bases.to_dict(),
		"home": {"base": String(home.name)} if home is Base else {},
```

In `_capture_you`, replace `aboard.interior` with `home.interior`.

- [ ] **Step 5: Restore**

In `who-knows/scenes/flight_test.gd`:

1. Add `var _loaded_home: Base` below `var home`.
2. In `_ready`, on the line after `_make_bases()`, add `bases.from_dict(saved.get("bases", {}))`.
3. In `_restore_places`, before `_universe.origin = ...`, take the base you were in as the focus:

```gdscript
	var in_base := String(saved.get("home", {}).get("base", ""))
	var site := bases.site_named(StringName(in_base)) if in_base != "" else null
	if site != null and String(you.get("mode", "")) != "suit":
		focus = site.at
```

and after `_restore_fleet(saved, true)`, before `_restore_you(you, true)`:

```gdscript
	if site != null:
		_loaded_home = bases.wake(site.id)
```

4. In `_restore_you`, use the place you were in. At its start add `var where: GridHome = _loaded_home if _loaded_home != null else aboard`, then replace every `aboard.interior` with `where.interior`, `aboard.restore_item(` with `where.restore_item(`, and the stand-on-deck fallback `aboard.interior.global_transform * _deck_spot(aboard)` with `_stand_spot(where)`. Seating (`_director.sit_now(aboard.seat)`) stays the ship's. Add:

```gdscript
## Somewhere to stand in `where`: a ship's deck by the helm, a base's first
## wake spot.
func _stand_spot(where: GridHome) -> Transform3D:
	if where is Ship:
		return where.interior.global_transform * _deck_spot(where as Ship)
	return where.wake_spots()[0]
```

Make `_can_stand(pose)` take the home: `func _can_stand(pose: Transform3D, where: GridHome) -> bool`, using `where.interior`, `where.grid` and `where.catalog`, and pass `where` from `_restore_you`.

5. In `_restore_spacewalk`, use `var where: GridHome = _loaded_home if _loaded_home != null else aboard` for the airlock lookup, `enter_suit(where.outside, ..., where.exterior)`.
6. At the end of `_ready`, after `board(aboard, true)`, add:

```gdscript
	if _loaded_home != null:
		board_base(_loaded_home, true)
```

- [ ] **Step 6: Run the tests**

Run: `./run_tests.ps1 -gselect=test_save_game.gd`, `-gselect=test_save_bases.gd`, `-gselect=test_save_scene.gd`, `-gselect=test_save_gate.gd`
Expected: all PASS, and the owner's real save untouched (the `after_all` asserts).

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/save/save_game.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_save_bases.gd who-knows/test/unit/test_save_game.gd
git commit -m "feat: saving bases -- format 3, and loading back into the base you were in"
```

---

### Task 12: The plant probe, the renders and the frame time (Phase B's done)

**Files:**
- Create: `who-knows/test/probes/base_probe.gd`
- Modify: `who-knows/src/audio/synth.gd` (`unfold`, `leg_stamp`, `drill_hum`), `who-knows/test/unit/test_synth.gd`, `who-knows/src/habitat/base.gd` (play them)
- Possibly modify: `who-knows/src/habitat/base_exterior.gd` (the look, from what the renders show)

**Interfaces:**
- Consumes everything from Tasks 1–11. Produces `Synth` sounds `&"unfold"`, `&"leg_stamp"`, `&"drill_hum"` (the last looped; Task 13 plays it).

- [ ] **Step 0: The sounds (§8.5)**

In `who-knows/test/unit/test_synth.gd`, add to `LENGTHS`: `&"unfold": 2.0, &"leg_stamp": 0.4, &"drill_hum": 3.0,`. Run `./run_tests.ps1 -gselect=test_synth.gd`: expected FAIL (the sizes differ).

In `who-knows/src/audio/synth.gd`, add the three names to `NAMES`, `&"drill_hum"` to `LOOPED`, three cases to `build`'s `match`:

```gdscript
		&"unfold":
			x = _unfold()
		&"leg_stamp":
			x = _leg_stamp()
		&"drill_hum":
			x = _drill_hum()
```

and the builders, after `_warp_drop`:

```gdscript
## A module unfolding (habitat modules spec §5.3, §8.5): three soft clunks as
## its walls fold up, under a shimmer rising to the end.
static func _unfold() -> PackedFloat32Array:
	var n := _len(2.0)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(300.0, 900.0, t / 2.0) / MIX_RATE
		x[i] = sin(phase) * 0.15 * minf(t / 1.5, 1.0) * exp(-maxf(t - 1.8, 0.0) / 0.05)
		for k in 3:
			var at := 0.2 + k * 0.6
			if t >= at:
				x[i] += sin(TAU * 70.0 * (t - at)) * exp(-(t - at) / 0.08)
	return _gain(x, 0.6)

## Legs punching into rock: a short, heavy stamp.
static func _leg_stamp() -> PackedFloat32Array:
	var n := _len(0.4)
	var rumble := _lowpass(_noise(n, 31), 300.0)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		x[i] = sin(TAU * 55.0 * t) * exp(-t / 0.1) + rumble[i] * exp(-t / 0.05) * 1.8
	return _gain(x, 0.7)

## A drill working (§6.2, §8.5): a low grinding loop, quieter than the air
## handler. 60 and 90 Hz both fit whole cycles in 3 s, so it loops cleanly.
static func _drill_hum() -> PackedFloat32Array:
	var n := _len(3.0)
	var grind := _lowpass(_noise(n, 37), 180.0)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		x[i] = sin(TAU * 60.0 * t) * 0.5 + sin(TAU * 90.0 * t) * 0.25 + grind[i] * 1.2
	return _gain(x, 0.18)
```

In `who-knows/src/habitat/base.gd`, add `var _thud: AudioStreamPlayer3D` and in `_ready` make it, on the suit's bus (outside is vacuum; you hear it through the suit):

```gdscript
	_thud = AudioStreamPlayer3D.new()
	_thud.name = "Thud"
	_thud.bus = AudioBuses.SUIT
	_thud.max_distance = 40.0
	exterior.add_child(_thud)
```

with a helper:

```gdscript
func _play(sound_name: StringName, at: Vector3) -> void:
	var s := Synth.sound(sound_name)
	if s == null or _thud == null:
		return
	_thud.global_position = at
	_thud.stream = s
	_thud.play()
```

Call `_play(&"leg_stamp", at)` at the end of `stamp()`, and in `tick_unfold`, when `t * HabitatValues.UNFOLD` first passes `FLY + SETTLE + LEGS` (the walls start), `_play(&"unfold", exterior.global_transform * site.centre_of(unfolding))` (guard it with a second flag like `_stamped`).

Run `./run_tests.ps1 -gselect=test_synth.gd` and `-gselect=test_base.gd`. Expected: PASS.

- [ ] **Step 1: Write the probe**

`who-knows/test/probes/base_probe.gd`. Its header, `_initialize`, `_frames`, `_seconds`, `_until`, `_shot` and `_check` are copied from `fleet_play.gd` (lines 1–58) with the header comment rewritten for the base and the timeout raised to 300 s. Then:

```gdscript
const SIDES := [Vector2.ZERO, Vector2(15, 0), Vector2(-15, 0), Vector2(0, 15), Vector2(0, -15),
	Vector2(30, 30), Vector2(-30, 30), Vector2(30, -30), Vector2(-30, -30), Vector2(50, 0), Vector2(-50, 0)]

var _cam: Camera3D

## A camera of the probe's own for outside views, at `from` looking at `at`.
func _look(from: Vector3, at: Vector3, up := Vector3.UP) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.far = BodyProxy.VIEW_FAR
		root.add_child(_cam)
	var hint := up if absf((at - from).normalized().dot(up)) < 0.95 else Vector3.RIGHT
	_cam.global_transform = Transform3D(Basis.looking_at(at - from, hint), from)
	_cam.make_current()

## An eye 4 m off the rock where the line from the ship lands, `side` across.
func _eye(ship: Ship, surface: RockSurface, side: Vector2) -> Variant:
	var toward := (surface.detail.global_position - ship.exterior.global_position).normalized()
	var across := toward.cross(Vector3.UP).normalized()
	var other := toward.cross(across)
	var hit := surface.cast(ship.exterior.global_position + across * side.x + other * side.y, toward, 2000.0)
	if hit.is_empty():
		return null
	var n: Vector3 = hit["normal"]
	var hint := n.cross(Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK).normalized()
	return Transform3D(Basis.looking_at(-n, hint), hit["position"] + n * 4.0)

## Mean and worst frame, ms, over `n` frames.
func _frame_time(n: int, what: String) -> void:
	var worst := 0.0
	var total := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		total += ms
		worst = maxf(worst, ms)
	print("frames  %s: mean %.1f ms, worst %.1f ms" % [what, total / n, worst])

func _run(scene: Node) -> void:
	await _frames(3)
	var ship: Ship = scene.get_node("Ship")
	var bases: Bases = scene.get("bases")
	var outside: Node3D = scene.get_node("Outside")
	var avatar: Avatar = get_first_node_in_group(Avatar.GROUP)
	avatar.suit_cell.from_dict({"charge": 100.0})
	var stream: AsteroidStream = scene.get_node("AsteroidStream")
	var surface := RockSurface.new(stream.details.nearest(ship.exterior.global_position))

	# 1. Make a hub at the machine, with the store full.
	ship.quantum.store.credit(ship.quantum.store.room(), &"probe")
	var machine: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	var cycle: MachineCycle = ship.quantum.cycles[machine.cell]
	cycle.selected = QuantumValues.makeable(ship.item_catalog).find(ship.item_catalog.get_def(&"hub_package"))
	await _frames(2)
	machine.panel.interact(avatar)
	var made := await _until(func() -> bool: return not machine.bay.is_free() \
		and machine.bay.item.definition.id == &"hub_package", 5.0)
	_check(made, "the machine makes a hub package")
	_check(ship.quantum.store.amount == 1200 - 800, "for 800 QE")
	await _shot("package_in_the_bay")

	# 2. Out on a spacewalk with it.
	var package: Item = machine.bay.item
	_check(avatar.grasp.take(package), "taken in both hands")
	var first: Variant = _eye(ship, surface, Vector2.ZERO)
	avatar.enter_suit(outside, first, Vector3.ZERO, ship.exterior)
	await _frames(10)
	_check(avatar.grasp.item == package, "still carried outside")

	# 3. A green ghost and a coral one.
	var use: PackageUse = package.use_node
	var green: Variant = null
	var coral := ""
	for side in SIDES:
		var eye: Variant = _eye(ship, surface, side)
		if eye == null:
			continue
		var r := use.refit(package, eye, outside)
		if r == null:
			continue
		if r.fit == Planting.Fit.OK and green == null:
			green = eye
			_look(eye.origin + eye.basis.y * 3.0, r.body.origin)
			await _shot("ghost_green")
		elif r.fit != Planting.Fit.OK and r.fit != Planting.Fit.NO_GROUND and coral == "":
			coral = Planting.prompt(r, ModuleCatalog.get_def(&"hub"))
			_look(eye.origin + eye.basis.y * 3.0, r.body.origin)
			await _shot("ghost_coral")
	_check(green != null, "somewhere on the near face takes a hub")
	print("coral   %s" % (coral if coral != "" else "(none found)"))

	# 4. Plant it, and watch it unfold.
	_check(use.use(package, green, outside, null), "planted")
	await _seconds(2.5)
	var base: Base = bases.awake()[0] if not bases.awake().is_empty() else null
	_check(base != null, "a base, unfolding")
	_look(green.origin + green.basis.y * 6.0 + green.basis.x * 10.0, base.exterior.global_position)
	await _shot("mid_unfold")
	var done := await _until(func() -> bool: return base.unfolding < 0, 6.0)
	_check(done, "unfolded")

	# 5. In through its airlock.
	var lock: Airlock = base.airlocks.values()[0]
	var hull := base.exterior.global_transform
	avatar.global_position = hull * (lock.alcove.outer_frame * Vector3(0, 0.3, -8.0))
	avatar.velocity = Vector3.ZERO
	avatar.camera.make_current()
	var tied := await _until(func() -> bool: return scene.get("home") == base, 2.0)
	_check(tied, "near the hub, the suit is the base's")
	lock.alcove.hull_panel.interact(avatar)
	var opened := await _until(func() -> bool: return lock.cycle.outer_open >= 1.0, 12.0)
	_check(opened, "the hub's outer hatch opens")
	var inward := (hull.basis * lock.alcove.outer_frame.basis * Vector3(0, 0, 1)).normalized()
	avatar.global_position = hull * (lock.alcove.outer_frame * Vector3(0, 0.3, -1.5))
	avatar.velocity = inward * 1.2
	var inside := await _until(func() -> bool: return avatar.mode == Avatar.Mode.PLATING, 6.0)
	_check(inside and avatar.get_parent() == base.interior, "standing in the hub's airlock")
	await _seconds(1.5)
	lock.room.room_panel.interact(avatar)
	var cycled := await _until(func() -> bool: return lock.cycle.inner_open >= 1.0, 12.0)
	_check(cycled, "the inner hatch opens on air")
	avatar.place(base.wake_spots()[0])
	avatar.set_head_pitch(0.0)
	await _frames(10)
	_check(avatar.grav_strength > 0.0 and avatar.mode == Avatar.Mode.PLATING, "walking in gravity, the suit idle")
	await _shot("inside_the_hub")
	await _frame_time(300, "inside the hub")

	# 6. The hub from outside, 20 m and 2 km off, at 1.6 m above the rock.
	var up := hull.basis.y
	var near := hull * Vector3(2.0, 0.0, 20.0)
	_look(near + up * 1.6, hull.origin)
	await _shot("hub_from_20_m")
	await _frame_time(300, "outside, the hub and the rock")
	_look(hull.origin + up * 600.0 + hull.basis.x * 1900.0, hull.origin)
	await _shot("hub_from_2_km")
	avatar.camera.make_current()

	print("probe   done, %d fails" % _fails)
	quit(_fails)
```

The 20 m shot's eye is simply 20 m along the hub's +z at its own floor height; if the rock's surface rises there, raise it until it clears (a quick `surface.cast` down from 10 m above and +1.6 m over the hit).

- [ ] **Step 2: Run the probe**

Run (not headless): `& $godot --path . --resolution 1280x720 --script D:/git/whoknows-habitat/who-knows/test/probes/base_probe.gd -- D:/git/whoknows-habitat/out/base`
Expected: `done, 0 fails`; seven PNGs in the out dir (bay, green, coral, mid-unfold, inside, 20 m, 2 km); two frame-time lines printed.

- [ ] **Step 3: Look at every render yourself, then send them to the owner**

Read each PNG. Check them against the style guide: warm, dim, chunky; the hub reads as a building on legs, not a crate; the ghost is clearly green or coral; nothing realistic or blue. If the hub's box hull from `ExteriorBuilder` reads as a crate rather than §8.1's "rounded drums and capsules", add drums in `BaseExterior.build`: one bevelled drum per module round its body (`InteriorKit.ring` along the module's long axis, `HullPalette.PLATE` with `PANEL_LINE` ribs and a `MODULE_COLOURS` band), keep the box hull as collision only by moving `ExteriorBuilder`'s skin to a hidden layer for bases, re-render, and look again. Then send the renders to the owner with `SendUserFile` and the frame times, and **wait for their word on the look** before Phase C. If the frame time is under 120 fps, say so plainly with the numbers. Tell them too that the hub's floor is plain deck colour: §8.2's per-module floor colours come with corridors, when a second module can be walked into.

- [ ] **Step 4: Commit**

```bash
git add who-knows/test/probes/base_probe.gd who-knows/src/habitat/base_exterior.gd who-knows/src/habitat/base.gd who-knows/src/audio/synth.gd who-knows/test/unit/test_synth.gd
git commit -m "test: the base probe -- make, carry, plant, board; renders, frame time, and the unfold's sounds"
```

---

## Phase C: a base that earns

### Task 13: The drill, the store module and the quiet it brings

**Files:**
- Create: `who-knows/src/habitat/drill_yield.gd`
- Modify: `who-knows/src/habitat/base.gd`, `who-knows/src/habitat/bases.gd`, `who-knows/src/npc/populations/rock_herd_source.gd`, `who-knows/scenes/flight_test.gd` (`_wire_npcs`)
- Test: `who-knows/test/unit/test_drill_yield.gd`, `who-knows/test/unit/test_base_drill.gd`

**Interfaces:**
- Consumes: `BaseSite.drills()`, `Bases._on_planted`, `Bases.clock`, `PlantSurface.ore()`, `StimulusBus`, `RockHerdSource`.
- Produces `DrillYield` (pure, static): `fresh(ore: Dictionary, now: float) -> Dictionary` (`{richness, veined, ran, credited_at, owed}`), `rate(drill) -> float` (QE a second), `surveyed(drill) -> bool`, `gauge(drill) -> String`, `credit(drill: Dictionary, now: float, store: QuantumStore) -> int`.
- `Base.clock: Callable`, `Base.credit_drills() -> int`, `Base.hum()`. `Bases.quiet(site_id: StringName, point: Vector3) -> bool`. `RockHerdSource.quiet: Callable`.

- [ ] **Step 1: Write the failing pure test**

`who-knows/test/unit/test_drill_yield.gd`:

```gdscript
extends GutTest

## The drill's yield (habitat modules spec §6.2), by the play-time clock.

func _drill(richness := 1.0) -> Dictionary:
	var d := DrillYield.fresh({"seed": 42, "veined": false}, 100.0)
	d["richness"] = richness
	return d

func test_richness_is_seeded_per_rock_and_in_range():
	for s in 50:
		var d := DrillYield.fresh({"seed": s, "veined": false}, 0.0)
		assert_between(float(d["richness"]), HabitatValues.RICHNESS_MIN, HabitatValues.RICHNESS_MAX)
		assert_eq(d["richness"], DrillYield.fresh({"seed": s, "veined": false}, 9.0)["richness"], "same rock, same ore")

func test_a_veined_rock_doubles():
	var plain := DrillYield.fresh({"seed": 7, "veined": false}, 0.0)
	var veined := DrillYield.fresh({"seed": 7, "veined": true}, 0.0)
	assert_almost_eq(float(veined["richness"]), float(plain["richness"]) * HabitatValues.VEIN_FACTOR, 0.0001)

func test_it_surveys_for_its_first_minute():
	var d := _drill(1.8)
	var store := QuantumStore.new(400, 0)
	DrillYield.credit(d, 100.0 + 59.0, store)
	assert_false(DrillYield.surveyed(d))
	assert_eq(DrillYield.gauge(d), "SURVEYING")
	DrillYield.credit(d, 100.0 + 61.0, store)
	assert_true(DrillYield.surveyed(d))
	assert_eq(DrillYield.gauge(d), "ORE 1.8×")

func test_it_earns_one_qe_per_ten_seconds_times_richness():
	var d := _drill(1.0)
	var store := QuantumStore.new(400, 0)
	assert_eq(DrillYield.credit(d, 100.0 + 60.0, store), 6)
	assert_eq(store.amount, 6)
	var rich := _drill(2.5)
	var other := QuantumStore.new(400, 0)
	assert_eq(DrillYield.credit(rich, 100.0 + 60.0, other), 15)

func test_fractions_carry_over():
	var d := _drill(1.0)
	var store := QuantumStore.new(400, 0)
	for i in 10:
		DrillYield.credit(d, 100.0 + (i + 1) * 3.0, store)
	assert_eq(store.amount, 3, "30 s of 3 s steps is 3 QE, not 0")

func test_a_long_sleep_fills_to_capacity_and_never_pays_twice():
	var d := _drill(3.0)
	var store := QuantumStore.new(400, 350)
	assert_eq(DrillYield.credit(d, 100.0 + 3600.0, store), 50, "capped at the store's room")
	assert_eq(store.amount, 400)
	assert_eq(float(d["credited_at"]), 3700.0, "the clock moved on")
	store.drain(100, &"test")
	assert_eq(DrillYield.credit(d, 3700.0, store), 0, "no second payment for the same time")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_drill_yield.gd`
Expected: FAIL, `DrillYield` not declared.

- [ ] **Step 3: Write `DrillYield`**

`who-knows/src/habitat/drill_yield.gd`:

```gdscript
class_name DrillYield
extends RefCounted

## What a drill earns (docs/superpowers/specs/2026-09-26-habitat-modules-design.md
## §6.2): 1 QE per DRILL_PERIOD seconds of play, times its rock's richness --
## seeded per rock, doubled on a veined one -- into its base's store, never
## past its capacity. For its first SURVEY seconds its gauge says only
## SURVEYING (who knows). Its state is a plain dictionary in the base's site,
## so it is saved as it is; the clock is play time, so a closed game earns
## nothing and a sleeping base earns as if you were there.

static func fresh(ore: Dictionary, now: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ore.get("seed", 0))
	var richness := rng.randf_range(HabitatValues.RICHNESS_MIN, HabitatValues.RICHNESS_MAX)
	var veined := bool(ore.get("veined", false))
	if veined:
		richness *= HabitatValues.VEIN_FACTOR
	return {"richness": richness, "veined": veined, "ran": 0.0, "credited_at": now, "owed": 0.0}

## QE a second.
static func rate(drill: Dictionary) -> float:
	return float(drill.get("richness", 1.0)) / HabitatValues.DRILL_PERIOD

static func surveyed(drill: Dictionary) -> bool:
	return float(drill.get("ran", 0.0)) >= HabitatValues.SURVEY

## *SURVEYING*, then the richness: *VEIN 1.8×* on a veined rock, *ORE 1.8×*
## on any other.
static func gauge(drill: Dictionary) -> String:
	if not surveyed(drill):
		return "SURVEYING"
	return "%s %.1f×" % ["VEIN" if drill.get("veined", false) else "ORE", float(drill.get("richness", 1.0))]

## Credits `drill` from its last credit up to `now` into `store`, in whole QE,
## carrying the fraction. What will not fit is lost, not owed: a full store
## stays full. Returns what it credited.
static func credit(drill: Dictionary, now: float, store: QuantumStore) -> int:
	var dt := maxf(now - float(drill.get("credited_at", now)), 0.0)
	drill["credited_at"] = now
	drill["ran"] = float(drill.get("ran", 0.0)) + dt
	var owed := float(drill.get("owed", 0.0)) + dt * rate(drill)
	var whole := floori(owed + 1e-6)
	var paid := mini(whole, store.room())
	if paid > 0:
		store.credit(paid, &"drill")
	drill["owed"] = maxf(owed - whole, 0.0) if paid == whole else 0.0
	return paid
```

Run: `./run_tests.ps1 -gselect=test_drill_yield.gd`
Expected: PASS.

- [ ] **Step 4: Write the failing base test**

`who-knows/test/unit/test_base_drill.gd`:

```gdscript
extends GutTest

## A drill and a store on a base (habitat modules spec §6.2, §6.3, §8.4).

class Ground extends PlantSurface:
	var y := 0.0
	func _init(p_y: float) -> void:
		y = p_y
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		if from.y >= y and to.y <= y:
			return {"position": from.lerp(to, (from.y - y) / (from.y - to.y)), "normal": Vector3.UP}
		return {}
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:drill"
	func ore() -> Dictionary:
		return {"seed": 5, "veined": true}

var _root: Node
var _clock := 0.0
var _base: Base
var _ground: Ground

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_clock = 1000.0
	_root.bases.clock = func() -> float: return _clock
	var at: Vector3 = _root.get_node("Ship").exterior.global_position + Vector3(0, -40, 60)
	_ground = Ground.new(at.y)
	var r := Planting.fit(_ground, ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	_base = _root.bases.plant(ModuleCatalog.HUB, r, _ground)
	_base.tick_unfold(HabitatValues.UNFOLD + 0.1)

func _plant(kind: StringName, local: Vector3) -> int:
	var frame := _root.bases.frame_of(_base.site)
	var r := Planting.fit(_ground, ModuleCatalog.get_def(kind), frame * local, Vector3.FORWARD, 0, _base.site, frame)
	assert_eq(r.fit, Planting.Fit.OK)
	_root.bases.plant(kind, r, _ground)
	_base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	return _base.site.modules.size() - 1

func test_a_planted_drill_knows_its_rock_s_ore():
	var i := _plant(ModuleCatalog.DRILL, Vector3(10, -2, 0))
	var drill: Dictionary = _base.site.modules[i]["drill"]
	assert_true(drill["veined"])
	assert_eq(float(drill["credited_at"]), 1000.0)

func test_it_fills_the_base_s_store_by_the_clock():
	var i := _plant(ModuleCatalog.DRILL, Vector3(10, -2, 0))
	var rate := DrillYield.rate(_base.site.modules[i]["drill"])
	_clock += 120.0
	var paid := _base.credit_drills()
	assert_eq(paid, floori(rate * 120.0 + 1e-6))
	assert_eq(_base.quantum.store.amount, paid)

func test_a_store_module_raises_the_capacity():
	_plant(ModuleCatalog.STORE, Vector3(-6, -2, 0))
	assert_eq(_base.quantum.store.capacity, HabitatValues.HUB_STORE + HabitatValues.STORE_ADDS)

func test_a_sleeping_base_is_credited_when_it_wakes():
	_plant(ModuleCatalog.DRILL, Vector3(10, -2, 0))
	var universe: Universe = _root.get_node("Universe")
	universe.origin = universe.origin.plus(Vector3(25000, 0, 0))
	_root.bases.check_sleep()
	assert_null(_root.bases.named(&"Base1"))
	_clock += 600.0
	universe.origin = universe.origin.plus(Vector3(-25000, 0, 0))
	_root.bases.check_sleep()
	assert_gt(_root.bases.named(&"Base1").quantum.store.amount, 0, "it earned while asleep")

func test_herds_keep_away_from_a_drill_that_has_run_ten_minutes():
	var i := _plant(ModuleCatalog.DRILL, Vector3(10, -2, 0))
	var at := _root.bases.frame_of(_base.site) * _base.site.centre_of(i)
	assert_false(_root.bases.quiet(&"rock:drill", at), "not yet")
	_clock += HabitatValues.QUIET_AFTER + 1.0
	_base.credit_drills()
	assert_true(_root.bases.quiet(&"rock:drill", at + Vector3(30, 0, 0)), "within 80 m of it")
	assert_false(_root.bases.quiet(&"rock:drill", at + Vector3(200, 0, 0)), "but not beyond")
	assert_false(_root.bases.quiet(&"rock:other", at), "and only on its own rock")
```

- [ ] **Step 5: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_base_drill.gd`
Expected: FAIL: the drill has no state; `credit_drills` not declared.

- [ ] **Step 6: The drill in `Bases` and `Base`**

In `who-knows/src/habitat/bases.gd`, replace `_on_planted`'s body:

```gdscript
func _on_planted(site: BaseSite, index: int, surface: PlantSurface) -> void:
	if site.modules[index]["kind"] == ModuleCatalog.DRILL:
		site.modules[index]["drill"] = DrillYield.fresh(surface.ore(), clock.call() if clock.is_valid() else 0.0)
```

In `_wake`, before `home.add_child(base)`, add `base.clock = clock`. Add:

```gdscript
## True if a drill on `site_id`'s base has run QUIET_AFTER and stands within
## QUIET_RADIUS of `point` (engine space): its herds have moved away (§8.4).
func quiet(site_id: StringName, point: Vector3) -> bool:
	var site := on(site_id)
	if site == null:
		return false
	var frame := frame_of(site)
	for i in site.drills():
		var drill: Dictionary = site.modules[i]["drill"]
		if float(drill.get("ran", 0.0)) < HabitatValues.QUIET_AFTER:
			continue
		if (frame * site.centre_of(i)).distance_to(point) <= HabitatValues.QUIET_RADIUS:
			return true
	return false
```

In `who-knows/src/habitat/base.gd`, add vars:

```gdscript
## Seconds of play, for the drills (Bases.clock).
var clock: Callable
var _credit_in := 0.0
var _hum_in := 0.0
```

Replace `_physics_process`:

```gdscript
func _physics_process(delta: float) -> void:
	if unfolding >= 0:
		tick_unfold(delta)
	_credit_in -= delta
	if _credit_in <= 0.0:
		_credit_in = HabitatValues.CREDIT_EVERY
		credit_drills()
	_hum_in -= delta
	if _hum_in <= 0.0:
		_hum_in = HabitatValues.HUM_EVERY
		hum()
```

and add:

```gdscript
## Credits every drill that is not unfolding up to now. Returns what it paid.
func credit_drills() -> int:
	if not clock.is_valid() or quantum == null or quantum.store == null:
		return 0
	var now: float = clock.call()
	var paid := 0
	for i in site.drills():
		if i != unfolding:
			paid += DrillYield.credit(site.modules[i]["drill"], now, quantum.store)
	return paid

## Each working drill's hum through the rock (§8.4): too faint to startle.
func hum() -> void:
	for i in site.drills():
		if i == unfolding:
			continue
		var at := exterior.global_transform * site.centre_of(i)
		StimulusBus.send(exterior, Stimulus.make(Stimulus.VIBRATION, at, HabitatValues.HUM_STRENGTH,
			HabitatValues.HUM_RADIUS, exterior, site.site_id), HabitatValues.HUM_EVERY)
```

At the end of `restore_inside`, add `credit_drills()` (the time it slept).

The drill heard inside (§8.5): add `var _grind: AudioStreamPlayer` made in `_ready` on `AudioBuses.SHIP` at `volume_db = -22.0` (the ship's hum is -16), and at the end of `hum()`:

```gdscript
	var working := site.drills().any(func(i: int) -> bool: return i != unfolding)
	if own and working and not _grind.playing:
		_grind.stream = Synth.sound(&"drill_hum")
		_grind.play()
	elif (not own or not working) and _grind.playing:
		_grind.stop()
```

- [ ] **Step 7: Herds keep away**

In `who-knows/src/npc/populations/rock_herd_source.gd`, add after `var reach`:

```gdscript
## Whether a point on a rock is too near a working drill for a herd to keep
## its home there (habitat modules spec §8.4): a Callable (site id, engine
## point) -> bool, or none.
var quiet: Callable
```

and in `records()`, replace `for r in site.records: out.append([r, site])` with:

```gdscript
			for r in site.records:
				if quiet.is_valid() and quiet.call(site.id, site.frame() * r.home):
					continue
				out.append([r, site])
```

In `who-knows/scenes/flight_test.gd`'s `_wire_npcs`, replace `exterior_npcs.sources = [RockHerdSource.new(_stream)]` with:

```gdscript
	var herds := RockHerdSource.new(_stream)
	herds.quiet = bases.quiet
	exterior_npcs.sources = [herds]
```

- [ ] **Step 8: Run the tests**

Run: `./run_tests.ps1 -gselect=test_drill_yield.gd`, `-gselect=test_base_drill.gd`, `-gselect=test_bases.gd`, and every NPC test touching herds (`ls test/unit/test_rock_herd*.gd test/unit/test_npc*.gd`)
Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
git add who-knows/src/habitat/drill_yield.gd who-knows/src/habitat/base.gd who-knows/src/habitat/bases.gd who-knows/src/npc/populations/rock_herd_source.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_drill_yield.gd who-knows/test/unit/test_base_drill.gd
git commit -m "feat: the drill -- QE by the play-time clock, a store module, and herds that keep away"
```

---

### Task 14: The quantum link

**Files:**
- Create: `who-knows/src/habitat/quantum_link.gd`, `who-knows/src/habitat/link_panel.gd`
- Modify: `who-knows/src/habitat/base.gd` (build the panel after each rebuild), `who-knows/scenes/flight_test.gd` (give bases the ships), `who-knows/test/unit/test_visual_style_rules.gd` (`PAINTING_FILES` += `res://src/habitat/link_panel.gd`)
- Test: `who-knows/test/unit/test_quantum_link.gd`

**Interfaces:**
- Produces `QuantumLink` (pure, static): `move(from: QuantumStore, to: QuantumStore, n: int) -> int` (lossless, never past `to`'s room or `from`'s amount); `in_reach(base_at: Vector3, hull_at: Vector3) -> bool`.
- Produces `LinkPanel extends Node3D`: `setup(base: Base)`, `lines() -> PackedStringArray`, `press(role: StringName)` (`&"to_ship"`, `&"to_base"`), `hold(role: StringName, delta: float)`; three `ReadoutPanel`s: a screen and two buttons.
- `Bases.ship_near: Callable` returns the nearest awake `Ship` to a point, or null. `Base.link: LinkPanel`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_quantum_link.gd`:

```gdscript
extends GutTest

## The quantum link (habitat modules spec §6.1, row 9): QE between your ship's
## store and the base's, both ways, without loss, within 1 km.

func test_it_moves_without_loss():
	var ship := QuantumStore.new(1200, 600)
	var base := QuantumStore.new(400, 0)
	assert_eq(QuantumLink.move(ship, base, 50), 50)
	assert_eq(ship.amount, 550)
	assert_eq(base.amount, 50)
	assert_eq(QuantumLink.move(base, ship, 50), 50)
	assert_eq(ship.amount, 600)

func test_it_respects_both_stores():
	var ship := QuantumStore.new(1200, 30)
	var base := QuantumStore.new(400, 390)
	assert_eq(QuantumLink.move(ship, base, 50), 10, "only room for 10")
	assert_eq(QuantumLink.move(base, ship, 1000), 400, "only 400 to give")

func test_its_reach_is_a_kilometre():
	assert_true(QuantumLink.in_reach(Vector3.ZERO, Vector3(999, 0, 0)))
	assert_false(QuantumLink.in_reach(Vector3.ZERO, Vector3(1001, 0, 0)))

class Ground extends PlantSurface:
	var y := 0.0
	func _init(p_y: float) -> void:
		y = p_y
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		if from.y >= y and to.y <= y:
			return {"position": from.lerp(to, (from.y - y) / (from.y - to.y)), "normal": Vector3.UP}
		return {}
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:link"

func test_the_hub_s_panel_moves_qe_in_fifties_and_says_no_link_when_far():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	var at := ship.exterior.global_position + Vector3(0, -40, 60)
	var r := Planting.fit(Ground.new(at.y), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	var base: Base = root.bases.plant(ModuleCatalog.HUB, r, Ground.new(at.y))
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	var before := ship.quantum.store.amount
	assert_not_null(base.link)
	assert_eq(base.link.lines()[0], "SHIP %d · BASE 0" % before)
	base.link.press(&"to_base")
	assert_eq(base.quantum.store.amount, HabitatValues.LINK_STEP)
	assert_eq(ship.quantum.store.amount, before - HabitatValues.LINK_STEP)
	base.link.press(&"to_ship")
	assert_eq(ship.quantum.store.amount, before)
	ship.exterior.global_position += Vector3(5000, 0, 0)
	assert_eq(base.link.lines()[0], "NO LINK")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./run_tests.ps1 -gselect=test_quantum_link.gd`
Expected: FAIL, `QuantumLink` not declared.

- [ ] **Step 3: Write `QuantumLink`**

`who-knows/src/habitat/quantum_link.gd`:

```gdscript
class_name QuantumLink
extends RefCounted

## QE between two stores without loss (habitat modules spec §2 row 9, §6.1):
## never more than `from` holds or `to` has room for.

static func move(from: QuantumStore, to: QuantumStore, n: int) -> int:
	var k := mini(mini(n, from.amount), to.room())
	if k <= 0:
		return 0
	from.drain(k, &"link")
	to.credit(k, &"link")
	return k

static func in_reach(base_at: Vector3, hull_at: Vector3) -> bool:
	return base_at.distance_to(hull_at) <= HabitatValues.LINK_REACH
```

- [ ] **Step 4: Write `LinkPanel`**

`who-knows/src/habitat/link_panel.gd`:

```gdscript
class_name LinkPanel
extends Node3D

## The hub's link panel (habitat modules spec §6.1): a pedestal by the
## airlock with a screen -- *SHIP 640 · BASE 120*, and each drill's gauge
## beneath -- and two buttons, ◀ to the ship and ▶ to the base, LINK_STEP a
## press and LINK_RATE a second while held. *NO LINK* with no ship within
## LINK_REACH. Built from the kit and ReadoutPanels, in InteriorPalette.

const PEDESTAL := Vector3(0.5, 1.05, 0.3)

var base: Base
var _screen: ReadoutPanel
var _to_ship: ReadoutPanel
var _to_base: ReadoutPanel
var _held := 0.0

func setup(p_base: Base) -> void:
	base = p_base
	var kit := InteriorKit.new(self)
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, PEDESTAL.y * 0.5, 0)), PEDESTAL, 0.04,
		InteriorKit.solid(InteriorPalette.TRIM))
	kit.commit()
	_screen = ReadoutPanel.new()
	_screen.setup(&"link", InteriorKit.LAYER)
	_screen.transform = Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, PEDESTAL.y + 0.2, 0.05))
	add_child(_screen)
	_to_ship = _button(&"to_ship", -0.13)
	_to_base = _button(&"to_base", 0.13)

func _button(role: StringName, x: float) -> ReadoutPanel:
	var b := ReadoutPanel.new()
	b.setup(role, InteriorKit.LAYER, InteriorKit.LAYER, Vector3(0.12, 0.12, 0.04), false)
	b.transform = Transform3D(Basis.IDENTITY, Vector3(x, PEDESTAL.y - 0.15, PEDESTAL.z * 0.5))
	b.prompt_source = func() -> String: return _prompt(role)
	b.pressed.connect(press)
	add_child(b)
	return b

func _process(_delta: float) -> void:
	if _screen != null:
		_screen.set_readout(lines(), &"go" if _ship() != null else &"vacuum")

func _ship() -> Ship:
	var bases := get_tree().get_first_node_in_group(Bases.GROUP) as Bases if is_inside_tree() else null
	if bases == null or not bases.ship_near.is_valid():
		return null
	var ship: Ship = bases.ship_near.call(base.exterior.global_position)
	if ship == null or not QuantumLink.in_reach(base.exterior.global_position, ship.exterior.global_position):
		return null
	return ship

func lines() -> PackedStringArray:
	var ship := _ship()
	var out := PackedStringArray()
	out.append("NO LINK" if ship == null else "SHIP %d · BASE %d" % [ship.quantum.store.amount, base.quantum.store.amount])
	for i in base.site.drills():
		out.append("DRILL %d · %s" % [i, DrillYield.gauge(base.site.modules[i]["drill"])])
	return out

func _prompt(role: StringName) -> String:
	if _ship() == null:
		return ""
	return "Move %d QE to the ship" % HabitatValues.LINK_STEP if role == &"to_ship" \
		else "Move %d QE to the base" % HabitatValues.LINK_STEP

func press(role: StringName) -> void:
	_move(role, HabitatValues.LINK_STEP)

## Held down: LINK_RATE a second, in whole QE.
func hold(role: StringName, delta: float) -> void:
	_held += HabitatValues.LINK_RATE * delta
	var whole := floori(_held)
	_held -= whole
	_move(role, whole)

func _move(role: StringName, n: int) -> void:
	var ship := _ship()
	if ship == null or n <= 0:
		return
	if role == &"to_ship":
		QuantumLink.move(base.quantum.store, ship.quantum.store, n)
	else:
		QuantumLink.move(ship.quantum.store, base.quantum.store, n)
```

Holding a `ReadoutPanel` is not something the interactor reports today (it calls `interact` once per press). Wire `hold` only if the `Interactor` already offers a held callback; otherwise ship press-only, and say so in Task 15's report as the spec's "hold to move continuously" left for later.

- [ ] **Step 5: Put the panel in the hub, and give bases the ships**

In `who-knows/src/habitat/base.gd`, add `var link: LinkPanel`, and at the end of `rebuild()`:

```gdscript
	_place_link(shown)
```

with:

```gdscript
## The link panel on the first hub's deck beside its airlock (§6.1).
func _place_link(shown: BaseSite) -> void:
	if link != null:
		link.queue_free()
		link = null
	var hubs := shown.hubs()
	if hubs.is_empty():
		return
	var m: Dictionary = shown.modules[hubs[0]]
	var spot := (m["cell"] as Vector3i) + ModuleDefinition.turn_cell(Vector3i(0, 0, 1), m["turns"],
		ModuleCatalog.get_def(ModuleCatalog.HUB).size)
	link = LinkPanel.new()
	link.name = "LinkPanel"
	var at := InteriorBuilder.interior_center(spot)
	at.y = InteriorBuilder.floor_y(spot)
	link.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * m["turns"]), at + Vector3(0, 0, -0.5))
	interior.add_child(link)
	link.setup(self)
```

In `who-knows/src/habitat/bases.gd`, add `var ship_near: Callable` beside `inside`. In `who-knows/scenes/flight_test.gd`'s `_make_bases`, add:

```gdscript
	bases.ship_near = func(p: Vector3) -> Ship: return fleet.nearest(p)
```

Add `"res://src/habitat/link_panel.gd",` to `PAINTING_FILES`.

- [ ] **Step 6: Run the tests**

Run: `./run_tests.ps1 -gselect=test_quantum_link.gd`, `-gselect=test_base.gd`, `-gselect=test_visual_style_rules.gd`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/habitat/quantum_link.gd who-knows/src/habitat/link_panel.gd who-knows/src/habitat/base.gd who-knows/src/habitat/bases.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_quantum_link.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: the quantum link -- QE between ship and base, lossless, within a kilometre"
```

---

### Task 15: The drill probe, the skills, the docs (Phase C's done)

**Files:**
- Modify: `who-knows/test/probes/base_probe.gd` (a drill section), `.claude/skills/building-a-ship/SKILL.md`, `.claude/skills/building-a-ship/reference.md`, `.claude/skills/building-an-npc/SKILL.md`, `.claude/skills/building-an-npc/reference.md`, `docs/superpowers/specs/2026-09-26-habitat-modules-design.md` (a §19, "As built"), `docs/superpowers/SLICE-1-STATUS.md`

- [ ] **Step 1: The drill probe**

Add to `base_probe.gd`, between section 6 and the final `print`:

```gdscript
	# 7. A drill and a store beside the hub, made, carried and planted as the
	#    hub was, with the ghost snapping to the base's grid.
	for kind in [&"drill_package", &"store_package"]:
		var item := Item.new()
		item.setup(ship.item_catalog.get_def(kind))
		outside.add_child(item)
		var item_use: PackageUse = item.use_node
		var planted := false
		for ring in [Vector3(10, 0, 0), Vector3(-8, 0, 0), Vector3(0, 0, 10), Vector3(0, 0, -8),
				Vector3(12, 0, 6), Vector3(-10, 0, 6)]:
			var over := hull * ring + up * 4.0
			var eye := Transform3D(Basis.looking_at(-up, hull.basis.z), over)
			var r := item_use.refit(item, eye, outside)
			if r != null and r.fit == Planting.Fit.OK:
				planted = item_use.use(item, eye, outside, null)
				break
		_check(planted, "a %s planted beside the hub" % kind)
		await _until(func() -> bool: return base.unfolding < 0, 7.0)
	_check(base.site.modules.size() == 3, "hub, drill and store")
	_check(base.quantum.store.capacity == HabitatValues.HUB_STORE + HabitatValues.STORE_ADDS, "the store module adds 1,000")
	_look(near + up * 6.0, hull.origin)
	await _shot("three_modules")
	await _frame_time(300, "outside, three modules")

	# 8. Away until it sleeps, back after 90 s of play, and it has earned.
	var before := base.quantum.store.amount
	avatar.enter_plating(ship.interior, ship.wake_spots()[0], 0.0, Vector3.ZERO, Quaternion.IDENTITY)
	scene.call("board", ship, true)
	var u: Universe = scene.get_node("Universe")
	ship.exterior.global_position += (ship.exterior.global_position - hull.origin).normalized() * 25000.0
	u.check()
	bases.check_sleep()
	_check(bases.named(&"Base1") == null, "25 km off, the base sleeps")
	await _seconds(90.0)
	ship.exterior.global_position = hull.origin + up * 60.0
	u.check()
	bases.check_sleep()
	var back := bases.named(&"Base1")
	_check(back != null, "back within 18 km, it wakes")
	_check(back != null and back.quantum.store.amount > before, "and its drill earned while it slept")

	# 9. The link: 50 QE to the ship.
	var ship_before := ship.quantum.store.amount
	back.link.press(&"to_ship")
	_check(ship.quantum.store.amount == ship_before + HabitatValues.LINK_STEP, "the link moves 50 QE to the ship")
	_look(back.interior.global_transform * (back.link.position + Vector3(0, 1.6, 1.2)),
		back.interior.global_transform * (back.link.position + Vector3(0, 1.2, 0)))
	await _shot("link_panel")
```

The interior shot of the link panel needs the base's interior shown: `scene.call("board_base", back, true)` before `_look`, then `scene.call("board", ship, true)` after. If the ship's 25 km jump leaves the floating origin or the rocks behind, step the hull 5 km at a time with `u.check()` and a few frames between, as `hop()` does.

Run the probe (not headless) as in Task 12. Expected: zero fails. Look at the renders, then send them and the frame times to the owner.

- [ ] **Step 2: The `building-a-ship` skill (CLAUDE.md)**

In `.claude/skills/building-a-ship/`:
- **SKILL.md checklist:** "A base is a grid too: anything that changes how a grid becomes an interior or an exterior, or how airlocks bind, must keep `Base` working: run `test_base.gd`, `test_base_boarding.gd` and `fleet_play.gd`." And "Interior slots come from `InteriorSlots`, shared by `Fleet` and `Bases`: never hand one out by hand."
- **Mistakes already made:** every surprise met while building Tasks 1–14 (one line each, what happened and the fix), at least: the airlock's one-open-face rule forcing the hub to 3 × 2; modules that touch merging interiors.
- **reference.md:** `GridHome` (what moved out of `Ship`, and the four node names a home must have), `InteriorSlots` (MAX 16), `Base`, `Bases` (SLEEP_AT, WAKE_AT), `BaseValidator`'s codes, `ModuleCatalog` (the three modules' layouts), `HabitatValues` (every constant), the `quantum_tank` block.

- [ ] **Step 3: The `building-an-npc` skill (CLAUDE.md)**

In `.claude/skills/building-an-npc/`: `reference.md` gains "Bases give off `VIBRATION`: the planting stamp (strength 1.0, radius 60 m) and each drill's hum (0.2, 80 m, every 3 s), on the rock's site." and `RockHerdSource.quiet`. The checklist gains "A new vibration source on a rock: check it against `Scatter`'s 0.45 threshold." Add any lesson the drill's hum taught to *Mistakes already made*.

- [ ] **Step 4: The spec's "as built" and the status**

Add `## 19. As built (Phases A–C)` to the spec: what was built, the eleven plan-level choices from this plan's Global Constraints (each with its reason), the hold-to-move gap if Task 14 shipped press-only, the probe's checks, and the frame times. In the spec's header, change the status to "Phases A–C built on branch `habitat-modules`; Phase D waits on the hose". Update `docs/superpowers/SLICE-1-STATUS.md`'s habitat paragraph to say what works now.

- [ ] **Step 5: Run every test file this plan touched**

Run each, from `D:/git/whoknows-habitat/who-knows`: `test_interior_slots.gd`, `test_grid_home.gd`, `test_module_catalog.gd`, `test_base_site.gd`, `test_planting.gd`, `test_rock_surface.gd`, `test_eva_cargo.gd`, `test_base.gd`, `test_bases.gd`, `test_package_use.gd`, `test_base_boarding.gd`, `test_save_bases.gd`, `test_drill_yield.gd`, `test_base_drill.gd`, `test_quantum_link.gd`, and the existing `test_fleet.gd`, `test_save_scene.gd`, `test_save_game.gd`, `test_save_gate.gd`, `test_suit_tie.gd`, `test_suit.gd`, `test_grasp.gd`, `test_ship_damage.gd`, `test_floating_origin_scene.gd`, `test_visual_style_rules.gd`.
Expected: all PASS, output free of new warnings. Then **ask the owner** whether to run the full suite (about 8 minutes) before merging.

- [ ] **Step 6: Commit**

```bash
git add who-knows/test/probes/base_probe.gd .claude/skills docs/superpowers
git commit -m "docs: habitat modules as built -- the skills, the spec's as-built, the status"
```
