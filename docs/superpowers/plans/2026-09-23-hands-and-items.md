# Hands and Items Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player see their gloved hands, pick objects up, carry, drop, throw and stow them, and fire a plasma pistol whose bolts push loose objects, inside the starter shuttle.

**Architecture:** Items are `RigidBody3D`s built from `ItemDefinition` resources. Stow points are placed by `InteriorDressing` where props publish spots. A felt-gravity `Area3D` gives loose items plating gravity plus the hull's shove. `Grasp` (logic) holds one item: wielded items freeze into a hand socket, carried items are pulled by a force-limited impulse. `Hands` (visuals) draws two jointed gloves from `InteriorKit` pieces and poses them from Grasp's state. `PlasmaEmitter` fires swept-ray `PlasmaBolt`s that push and flash.

**Tech Stack:** Godot 4.5.1 (Forward+), GDScript only, GUT 9.5.

**Spec:** `docs/superpowers/specs/2026-09-23-hands-and-items-design.md`. Read it and `docs/design/visual-style.md` before starting.

## Global Constraints

- **Worktree:** all work happens in `D:\git\whoknows-hands` on branch `hands-and-items`. Another session is working in `D:\git\whoknows`; never touch that checkout.
- **Engine:** Godot 4.5.1 stable, Forward+, GDScript only. Executable: `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe`.
- **Project root** is `who-knows/` (`res://`). Paths below are relative to `D:\git\whoknows-hands` unless they start with `res://`.
- **Import after a new `class_name`:** `& "<godot>" --headless --path "D:\git\whoknows-hands\who-knows" --import` before the first test run that needs it.
- **Tests:** `powershell -File D:\git\whoknows-hands\who-knows\run_tests.ps1 [-gselect=<file stem>]`. Baseline: 271 passing. Output must be pristine: no `SCRIPT ERROR`, `ERROR` or stray warnings. Free every node you make (`add_child_autofree`, `autofree`).
- **Visual style binds** (`docs/design/visual-style.md`): colours only from `InteriorPalette`; asset libraries never reference `ShipGrid`, `BlockCatalog`, `DeckGraph`, `InteriorLayout`, `InteriorBuilder` or `InteriorDressing`; exactly three interior shaders; interior meshes on render layer 2; interior lights `light_cull_mask = 2`, no shadows; every light `LIGHT_WARM`.
- **Physics layers:** 2 `interior_geometry` (bit 2), 3 `avatar` (bit 4), 6 `items` (bit 32). Item layer 32, mask 38. Avatar mask 34. Interactor, bolt, aim and tuck rays mask 34. `FeltGravity` layer 0, mask 32.
- **`.tscn`/`.tres`: no `#` comments anywhere** (CLAUDE.md). Prove every scene or resource edit by reading the value back at runtime in a test.
- **Input map** entries use `Object(InputEventKey, …)` / `Object(InputEventMouseButton, …)` syntax, never JSON-shaped.
- **Commit** Godot's `.uid` files with their scripts. Messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File map

| File | Status | Responsibility |
|---|---|---|
| `who-knows/src/items/item_definition.gd` | new | one kind of item, as data |
| `who-knows/src/items/item_catalog.gd` | new | id → definition, loads `data/items/` |
| `who-knows/src/items/item_looks.gd` | new | the item asset library |
| `who-knows/src/items/item_use.gd` | new | base for what using an item does |
| `who-knows/src/items/item.gd` | new | the rigid body; STOWED / LOOSE / HELD; interactable |
| `who-knows/src/items/stow_point.gd` | new | secures one item |
| `who-knows/src/items/hit.gd` | new | what a hit carries |
| `who-knows/src/items/impact_flash.gd` | new | muzzle and impact flashes |
| `who-knows/src/items/plasma_bolt.gd` | new | the projectile |
| `who-knows/src/items/plasma_emitter.gd` | new | the pistol's use |
| `who-knows/data/items/{plasma_pistol,mug,canister,crate}.tres` | new | the starter set |
| `who-knows/src/ship/felt_gravity.gd` | new | the interior's felt-gravity Area3D |
| `who-knows/src/avatar/grasp.gd` | new | what is in your hands |
| `who-knows/src/avatar/hand_pose.gd` | new | pose data and blending |
| `who-knows/src/avatar/glove.gd` | new | one jointed glove |
| `who-knows/src/avatar/hands.gd` | new | the first-person viewmodel |
| `who-knows/src/ui/reticle.gd` | new | the centre dot |
| `who-knows/src/ship/interior/interior_palette.gd` | modified | SUIT, SUIT_PAD, PLASMA, CRATES |
| `who-knows/src/ship/interior/interior_props.gd` | modified | spots; pistol cradles; shelf colliders |
| `who-knows/src/ship/interior/interior_dressing.gd` | modified | places StowPoints |
| `who-knows/src/ship/interior_builder.gd` | modified | owns FeltGravity; `stow_points()` |
| `who-knows/src/camera/motion_coupling.gd` | modified | drives FeltGravity |
| `who-knows/src/camera/camera_director.gd` | modified | `view_changed` |
| `who-knows/src/ship/ship.gd` | modified | Items node, catalog, stocking, re-seating |
| `who-knows/src/avatar/avatar.gd` | modified | Grasp, Hands, mask, push, re-capture click |
| `who-knows/src/avatar/interactor.gd` | modified | mask, held-item exclusion, `can_interact`, `current()` |
| `who-knows/scenes/flight_test.gd` / `.tscn` | modified | wiring; MotionCoupling path |
| `who-knows/project.godot` | modified | layer 6; `use`, `throw`, `drop` |
| `docs/design/visual-style.md`, slice spec, Planetfall spec | modified | spec §17 amendments |

---

# Phase A — items exist

### Task 1: Item data, looks and palette

**Files:**
- Create: `who-knows/src/items/item_definition.gd`, `who-knows/src/items/item_catalog.gd`, `who-knows/src/items/item_looks.gd`
- Create: `who-knows/data/items/plasma_pistol.tres`, `mug.tres`, `canister.tres`, `crate.tres`
- Modify: `who-knows/src/ship/interior/interior_palette.gd`, `who-knows/src/ship/interior/interior_props.gd` (shelves use `InteriorPalette.CRATES`)
- Modify: `who-knows/test/unit/test_visual_style_rules.gd`
- Test: `who-knows/test/unit/test_item_catalog.gd`, `who-knows/test/unit/test_item_looks.gd`

**Interfaces:**
- Produces: `ItemDefinition` (`id`, `display_name`, `mass_kg`, `size`, `grip: Grip {WIELD, CARRY}`, `stow_class`, `look`, `use: Script`, `grip_point`, `use_point`); `ItemCatalog.load_from_dir(path := "res://data/items") -> ItemCatalog`, `register`, `get_def`, `has`, `ids`; `ItemLooks.build(kit, look, size, variety)`, `ItemLooks.has_look(look) -> bool`, `ItemLooks.LOOKS`; `InteriorPalette.SUIT`, `SUIT_PAD`, `PLASMA`, `CRATES: Array[Color]`.

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_item_catalog.gd`:

```gdscript
extends GutTest

## The item catalogue (hands-and-items spec §4.1, §4.2): every kind on disk
## loads and is complete enough to build.

var _cat: ItemCatalog

func before_all():
	_cat = ItemCatalog.load_from_dir()

func test_the_starter_set_is_on_disk():
	for id in [&"plasma_pistol", &"mug", &"canister", &"crate"]:
		assert_true(_cat.has(id), "data/items has %s" % id)

func test_every_definition_is_complete():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		assert_eq(def.id, id)
		assert_ne(def.display_name, "", "%s has a name" % id)
		assert_gt(def.mass_kg, 0.0, "%s has mass" % id)
		assert_true(def.size.x > 0.0 and def.size.y > 0.0 and def.size.z > 0.0, "%s has a size" % id)
		assert_ne(def.stow_class, &"", "%s has a stow class" % id)
		assert_true(ItemLooks.has_look(def.look), "%s has a look ItemLooks can draw" % id)

func test_the_starter_grips_match_the_spec():
	assert_eq(_cat.get_def(&"plasma_pistol").grip, ItemDefinition.Grip.WIELD)
	assert_eq(_cat.get_def(&"mug").grip, ItemDefinition.Grip.WIELD)
	assert_eq(_cat.get_def(&"canister").grip, ItemDefinition.Grip.CARRY)
	assert_eq(_cat.get_def(&"crate").grip, ItemDefinition.Grip.CARRY)

func test_a_hand_built_catalog_needs_no_disk():
	var cat := ItemCatalog.new()
	var def := ItemDefinition.new()
	def.id = &"thing"
	cat.register(def)
	assert_true(cat.has(&"thing"))
	assert_eq(cat.get_def(&"thing"), def)
	assert_null(cat.get_def(&"missing"))
```

`who-knows/test/unit/test_item_looks.gd`:

```gdscript
extends GutTest

## The item asset library (hands-and-items spec §4.3): every look builds from
## a bare kit, with no grid and no ship, and stays inside its item's box.

var _root: Node3D
var _kit: InteriorKit

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)
	_kit = InteriorKit.new(_root)

func _bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var box := meshes[0].mesh.get_aabb()
	for mi in meshes:
		box = box.merge(mi.mesh.get_aabb())
	return box

func test_every_look_builds_inside_its_box():
	var cat := ItemCatalog.load_from_dir()
	for id in cat.ids():
		var def := cat.get_def(id)
		var root := Node3D.new()
		add_child_autofree(root)
		var kit := InteriorKit.new(root)
		ItemLooks.build(kit, def.look, def.size, 0.4)
		var meshes := kit.commit()
		assert_gt(meshes.size(), 0, "%s drew something" % id)
		var box := _bounds(meshes)
		var half := def.size * 0.5 + Vector3.ONE * 0.005
		assert_true(box.position.x >= -half.x and box.position.y >= -half.y and box.position.z >= -half.z
			and box.end.x <= half.x and box.end.y <= half.y and box.end.z <= half.z,
			"%s stays inside its %s box (drew %s)" % [id, def.size, box])

func test_the_pistol_has_a_lit_charge_light():
	ItemLooks.build(_kit, &"plasma_pistol", Vector3(0.06, 0.16, 0.24), 0.0)
	var names := _kit.commit().map(func(mi): return mi.name)
	assert_has(names, "DressingGlow", "the charge light and muzzle glow")

func test_looks_are_on_the_interior_layer():
	ItemLooks.build(_kit, &"crate", Vector3(0.45, 0.35, 0.35), 0.7)
	for mi in _kit.commit():
		assert_eq(mi.layers, 2)
```

Also extend `who-knows/test/unit/test_visual_style_rules.gd`: add `"res://src/items/item_looks.gd"` to both `PAINTING_FILES` and `REUSABLE_FILES`.

- [ ] **Step 2: Run the tests to see them fail**

Run: `powershell -File D:\git\whoknows-hands\who-knows\run_tests.ps1 -gselect=test_item`
Expected: FAIL, `ItemCatalog` not declared.

- [ ] **Step 3: Add the palette entries**

In `who-knows/src/ship/interior/interior_palette.gd`, append:

```gdscript

## The suit (docs/superpowers/specs/2026-09-23-hands-and-items-design.md §8.2):
## a warm off-white glove, with dark padding on the knuckles and finger backs.
const SUIT := Color("e8dfcc")
const SUIT_PAD := Color("4b4641")
## Plasma (hands-and-items spec §9): the bolt, the muzzle flash and the impact
## flash. Hot coral-amber, between CORAL and AMBER.
const PLASMA := Color("ff9a52")
## Crates, on shelves and as items: one of these, chosen by variety.
const CRATES: Array[Color] = [AMBER, SKY, CORAL, OLIVE, TRIM]
```

In `who-knows/src/ship/interior/interior_props.gd` `shelves()`, replace the local `crates` array with `InteriorPalette.CRATES` (delete the `var crates: Array[Color] = [...]` lines and use `_c(InteriorPalette.CRATES[int(h * 5.0) % 5])`).

- [ ] **Step 4: Write `ItemDefinition`**

`who-knows/src/items/item_definition.gd`:

```gdscript
class_name ItemDefinition
extends Resource

## Describes one *kind* of item (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §4.1). One .tres per kind in
## res://data/items/.
##
## Item-local frame: origin at the collider's centre, +y up, -z forward (a
## muzzle points along -z).

enum Grip {
	WIELD,  ## held in the right hand, tracking the aim exactly
	CARRY,  ## held out front in both hands by a force-limited physics hold
}

@export var id: StringName
@export var display_name: String = ""
@export var mass_kg: float = 1.0
## The one box collider. The look is built to fit inside it.
@export var size: Vector3 = Vector3(0.2, 0.2, 0.2)
@export var grip: Grip = Grip.CARRY
## Which stow points accept it (StowPoint.accepts).
@export var stow_class: StringName = &"small"
## The ItemLooks builder that draws it.
@export var look: StringName
## What using it does: a script extending ItemUse, or null.
@export var use: Script
## WIELD: the item-local point the palm closes on.
@export var grip_point: Vector3 = Vector3.ZERO
## The item-local point a use comes out of: the pistol's muzzle.
@export var use_point: Vector3 = Vector3.ZERO
```

- [ ] **Step 5: Write `ItemCatalog`**

`who-knows/src/items/item_catalog.gd`:

```gdscript
class_name ItemCatalog
extends RefCounted

## Maps item ids to definitions, as BlockCatalog does blocks. Production code
## loads from disk; tests register definitions by hand.

var _defs: Dictionary = {}   # StringName -> ItemDefinition

func register(def: ItemDefinition) -> void:
	if def.id == &"":
		push_error("ItemCatalog: an ItemDefinition must have an id")
		return
	_defs[def.id] = def

func get_def(id: StringName) -> ItemDefinition:
	return _defs.get(id, null)

func has(id: StringName) -> bool:
	return _defs.has(id)

func ids() -> Array:
	return _defs.keys()

static func load_from_dir(path: String = "res://data/items") -> ItemCatalog:
	var catalog := ItemCatalog.new()
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("ItemCatalog: cannot open %s" % path)
		return catalog
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var def := ResourceLoader.load(path.path_join(name)) as ItemDefinition
		if def != null:
			catalog.register(def)
	return catalog
```

- [ ] **Step 6: Write `ItemLooks`**

`who-knows/src/items/item_looks.gd`:

```gdscript
class_name ItemLooks
extends RefCounted

## The item asset library (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §4.3): one static builder per look,
## drawing from InteriorKit primitives in flat InteriorPalette colour, centred
## on the origin and inside the item's `size`. Like InteriorProps it never
## sees a grid, so anything that makes items can draw them.
##
## Item-local frame: origin at the collider's centre, +y up, -z forward (a
## muzzle points along -z). Each look is designed at its starter size and
## scaled to whatever size it is given.

const SOLID := InteriorKit.Batch.SOLID
const GLOW := InteriorKit.Batch.GLOW

const LOOKS: Array[StringName] = [&"plasma_pistol", &"mug", &"canister", &"crate"]

## Turn InteriorKit's x-axis tubes to run along y, or along z.
const _ALONG_Y := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
const _ALONG_Z := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))

static func has_look(look: StringName) -> bool:
	return LOOKS.has(look)

static func build(kit: InteriorKit, look: StringName, size: Vector3, variety: float) -> void:
	match look:
		&"plasma_pistol":
			plasma_pistol(kit, size)
		&"mug":
			mug(kit, size)
		&"canister":
			canister(kit, size)
		&"crate":
			crate(kit, size, variety)
		_:
			push_error("ItemLooks: no look called %s" % look)
			kit.bevel_box(SOLID, Transform3D.IDENTITY, size, 0.01, _c(InteriorPalette.TRIM))

## A chunky pistol: gunmetal body and raked grip, a trim barrel and rail,
## terracotta stripes down the sides, a plasma glow in the muzzle and a charge
## light on the back, facing whoever holds it. Designed at 0.06 x 0.16 x 0.24.
static func plasma_pistol(kit: InteriorKit, size: Vector3) -> void:
	var k := Transform3D(Basis.from_scale(size / Vector3(0.06, 0.16, 0.24)), Vector3.ZERO)
	var gun := _c(InteriorPalette.GUNMETAL)
	var trim := _c(InteriorPalette.TRIM)
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0.045, 0.01)), Vector3(0.055, 0.06, 0.2), 0.012, gun)
	kit.box(SOLID, k * _at(Vector3(0, 0.0765, 0.03)), Vector3(0.03, 0.006, 0.12), trim)
	for side in [-1.0, 1.0]:
		kit.box(SOLID, k * _at(Vector3(side * 0.0281, 0.045, 0.0)), Vector3(0.002, 0.014, 0.14),
			_c(InteriorPalette.BELT))
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Z, Vector3(0, 0.045, -0.105)), 0.016, 0.03, trim)
	kit.disc(GLOW, k * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.045, -0.1201)), 0.011,
		_lit(InteriorPalette.PLASMA, 2.0))
	kit.bevel_box(SOLID, k * Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, -0.03, 0.07)),
		Vector3(0.045, 0.1, 0.05), 0.012, gun)
	kit.box(SOLID, k * _at(Vector3(0, -0.012, 0.02)), Vector3(0.014, 0.008, 0.06), gun)
	kit.box(SOLID, k * _at(Vector3(0, 0.0, 0.028)), Vector3(0.008, 0.024, 0.01), trim)
	kit.disc(GLOW, k * _at(Vector3(0, 0.05, 0.1101)), 0.012, _lit(InteriorPalette.PLASMA, 1.8))

## A mug of something hot: a faceted trim cup with a terracotta band and a
## handle on +x. Designed at 0.09 x 0.1 x 0.09.
static func mug(kit: InteriorKit, size: Vector3) -> void:
	var k := Transform3D(Basis.from_scale(size / Vector3(0.09, 0.1, 0.09)), Vector3.ZERO)
	var trim := _c(InteriorPalette.TRIM)
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3.ZERO), 0.032, 0.1, trim)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, 0.015, 0)), 0.0335, 0.025, _c(InteriorPalette.BELT))
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.05, 0)), 0.032, trim)
	kit.disc(SOLID, k * Transform3D(up, Vector3(0, 0.045, 0)), 0.03, _c(InteriorPalette.WOOD))
	kit.annulus(SOLID, k * Transform3D(up, Vector3(0, 0.05, 0)), 0.028, 0.034, trim)
	kit.bevel_box(SOLID, k * _at(Vector3(0.039, 0, 0)), Vector3(0.012, 0.06, 0.022), 0.004, trim)

## An olive gas canister with trim caps and a terracotta band. Designed at
## 0.16 x 0.34 x 0.16.
static func canister(kit: InteriorKit, size: Vector3) -> void:
	var k := Transform3D(Basis.from_scale(size / Vector3(0.16, 0.34, 0.16)), Vector3.ZERO)
	var trim := _c(InteriorPalette.TRIM)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3.ZERO), 0.068, 0.27, _c(InteriorPalette.OLIVE))
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, 0.02, 0)), 0.0695, 0.06, _c(InteriorPalette.BELT))
	for y in [-0.1525, 0.1525]:
		kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, y, 0)), 0.074, 0.035, trim)
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.17, 0)), 0.074, trim)
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.17, 0)), 0.074, trim)

## A strapped crate in one of the shelf crates' colours, with a trim latch
## front and back. Any size.
static func crate(kit: InteriorKit, size: Vector3, variety: float) -> void:
	var colour: Color = InteriorPalette.CRATES[int(fposmod(variety, 1.0) * 5.0) % 5]
	kit.bevel_box(SOLID, Transform3D.IDENTITY, size - Vector3.ONE * 0.012, 0.03, _c(colour))
	for x in [-size.x * 0.27, size.x * 0.27]:
		kit.box(SOLID, _at(Vector3(x, 0, 0)), Vector3(0.04, size.y, size.z), _c(InteriorPalette.BELT))
	for z in [-1.0, 1.0]:
		kit.bevel_box(SOLID, _at(Vector3(0, size.y * 0.17, z * (size.z * 0.5 - 0.004))),
			Vector3(0.07, 0.04, 0.008), 0.003, _c(InteriorPalette.TRIM))

static func _at(offset: Vector3) -> Transform3D:
	return InteriorKit.at(offset)

static func _c(color: Color) -> Color:
	return InteriorKit.solid(color)

static func _lit(color: Color, energy: float) -> Color:
	return InteriorKit.lit(color, energy)
```

- [ ] **Step 7: Write the four definitions**

`who-knows/data/items/plasma_pistol.tres` (its `use` is added in Task 12):

```
[gd_resource type="Resource" script_class="ItemDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/items/item_definition.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
id = &"plasma_pistol"
display_name = "Plasma pistol"
mass_kg = 1.4
size = Vector3(0.06, 0.16, 0.24)
grip = 0
stow_class = &"sidearm"
look = &"plasma_pistol"
grip_point = Vector3(0, -0.03, 0.07)
use_point = Vector3(0, 0.045, -0.125)
```

`who-knows/data/items/mug.tres`:

```
[gd_resource type="Resource" script_class="ItemDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/items/item_definition.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
id = &"mug"
display_name = "Mug"
mass_kg = 0.3
size = Vector3(0.09, 0.1, 0.09)
grip = 0
stow_class = &"small"
look = &"mug"
grip_point = Vector3(0, 0, 0.04)
```

`who-knows/data/items/canister.tres`:

```
[gd_resource type="Resource" script_class="ItemDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/items/item_definition.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
id = &"canister"
display_name = "Canister"
mass_kg = 4.0
size = Vector3(0.16, 0.34, 0.16)
grip = 1
stow_class = &"small"
look = &"canister"
```

`who-knows/data/items/crate.tres`:

```
[gd_resource type="Resource" script_class="ItemDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/items/item_definition.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
id = &"crate"
display_name = "Crate"
mass_kg = 12.0
size = Vector3(0.45, 0.35, 0.35)
grip = 1
stow_class = &"crate"
look = &"crate"
```

- [ ] **Step 8: Import, then run the tests**

Run the import pass, then `run_tests.ps1 -gselect=test_item` and `-gselect=test_visual_style_rules` and `-gselect=test_interior_props`.
Expected: PASS, pristine output. `test_item_catalog` reading every field back is the runtime proof the `.tres` files parsed.

- [ ] **Step 9: Commit**

```bash
git add who-knows/src/items who-knows/data/items who-knows/src/ship/interior/interior_palette.gd who-knows/src/ship/interior/interior_props.gd who-knows/test/unit/test_item_catalog.gd who-knows/test/unit/test_item_looks.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: add item definitions, the catalogue and the item looks"
```

---

### Task 2: The Item node and stow points

**Files:**
- Create: `who-knows/src/items/item.gd`, `who-knows/src/items/item_use.gd`, `who-knows/src/items/stow_point.gd`
- Modify: `who-knows/project.godot` (`3d_physics/layer_6="items"`), `who-knows/test/unit/test_visual_style_rules.gd` (`item.gd` joins `REUSABLE_FILES`)
- Test: `who-knows/test/unit/test_item.gd`, `who-knows/test/unit/test_stow_point.gd`

**Interfaces:**
- Consumes: `ItemDefinition`, `ItemLooks.build`.
- Produces: `Item` (`enum State {STOWED, LOOSE, HELD}`, `LIFT_LIMIT_KG = 40.0`, `LAYER = 32`, `MASK = 38`, `definition`, `state`, `stow_point: StowPoint`, `use_node: ItemUse`, `setup(def, variety := 0.0)`, `set_stowed(point)`, `set_loose()`, `set_held(wielded: bool)`, `shape() -> BoxShape3D`, `prompt_text()`, `can_interact(actor)`, `interact(actor)`, `use(aim: Transform3D, world: Node3D, holder: CollisionObject3D) -> bool`); `ItemUse.use(item, aim, world, holder) -> bool`; `StowPoint` (`GROUP = &"stow_point"`, `accepts`, `stock`, `item`, `is_free()`, `fits(item)`, `item_transform(item) -> Transform3D`, `secure(item)`, `release() -> Item`).

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_item.gd`:

```gdscript
extends GutTest

## Item (hands-and-items spec §4.4): a rigid body built from a definition
## alone -- no grid, no ship -- in three states, talking to whoever takes it
## only through take_item and can_take_item.

class Actor extends Node:
	var taken: Item = null
	var allowed := true
	func take_item(item: Item) -> void:
		taken = item
	func can_take_item(_item: Item) -> bool:
		return allowed

func _def(grip := ItemDefinition.Grip.CARRY, mass := 4.0) -> ItemDefinition:
	var d := ItemDefinition.new()
	d.id = &"canister"
	d.display_name = "Canister"
	d.mass_kg = mass
	d.size = Vector3(0.16, 0.34, 0.16)
	d.grip = grip
	d.stow_class = &"small"
	d.look = &"canister"
	return d

func _item(def: ItemDefinition = null) -> Item:
	var item := Item.new()
	item.setup(def if def != null else _def())
	add_child_autofree(item)
	return item

func test_builds_from_a_definition_alone():
	var item := _item()
	assert_eq(item.mass, 4.0)
	var shapes := item.get_children().filter(func(n): return n is CollisionShape3D)
	assert_eq(shapes.size(), 1, "one box collider")
	assert_eq((shapes[0].shape as BoxShape3D).size, Vector3(0.16, 0.34, 0.16))
	assert_eq(item.shape(), shapes[0].shape)
	assert_gt(item.find_children("*", "MeshInstance3D", true, false).size(), 0, "it has a look")

func test_lives_on_the_items_layer():
	var item := _item()
	assert_eq(item.collision_layer, 32)
	assert_eq(item.collision_mask, 2 | 4 | 32)
	assert_true(item.continuous_cd, "thrown items must not tunnel through 0.1 m walls")
	assert_true(item.is_in_group(&"interactable"))

func test_its_look_is_on_the_interior_layer():
	for mi in _item().find_children("*", "MeshInstance3D", true, false):
		assert_eq(mi.layers, 2)

func test_loose_is_dynamic():
	var item := _item()
	item.set_loose()
	assert_eq(item.state, Item.State.LOOSE)
	assert_false(item.freeze)

func test_stowed_is_frozen_static():
	var item := _item()
	item.set_stowed(null)
	assert_eq(item.state, Item.State.STOWED)
	assert_true(item.freeze)
	assert_eq(item.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)
	assert_eq(item.collision_layer, 32, "you can still bump into it")

func test_wielded_is_frozen_kinematic_and_leaves_the_physics_world():
	var item := _item(_def(ItemDefinition.Grip.WIELD))
	item.set_held(true)
	assert_eq(item.state, Item.State.HELD)
	assert_true(item.freeze)
	assert_eq(item.freeze_mode, RigidBody3D.FREEZE_MODE_KINEMATIC)
	assert_eq(item.collision_layer, 0)
	assert_eq(item.collision_mask, 0)

func test_carried_stays_dynamic_and_solid():
	var item := _item()
	item.set_held(false)
	assert_eq(item.state, Item.State.HELD)
	assert_false(item.freeze)
	assert_eq(item.collision_layer, 32)

func test_letting_go_restores_the_layers():
	var item := _item(_def(ItemDefinition.Grip.WIELD))
	item.set_held(true)
	item.set_loose()
	assert_eq(item.collision_layer, 32)
	assert_eq(item.collision_mask, 38)
	assert_false(item.freeze)

func test_prompts_name_the_item():
	var item := _item()
	item.set_loose()
	assert_eq(item.prompt_text(), "Pick up Canister")
	item.set_stowed(null)
	assert_eq(item.prompt_text(), "Take Canister")
	assert_eq(_item(_def(ItemDefinition.Grip.CARRY, 60.0)).prompt_text(), "Too heavy")

func test_asks_the_actor_before_offering_itself():
	var actor: Actor = autofree(Actor.new())
	var item := _item()
	assert_true(item.can_interact(actor))
	actor.allowed = false
	assert_false(item.can_interact(actor))
	actor.allowed = true
	item.set_held(false)
	assert_false(item.can_interact(actor), "never while held")

func test_interacting_hands_it_to_the_actor():
	var actor: Actor = autofree(Actor.new())
	var item := _item()
	item.interact(actor)
	assert_eq(actor.taken, item)

func test_an_item_with_no_use_does_nothing_when_used():
	var item := _item()
	assert_null(item.use_node)
	assert_false(item.use(Transform3D.IDENTITY, null, null))
```

`who-knows/test/unit/test_stow_point.gd`:

```gdscript
extends GutTest

## StowPoint (hands-and-items spec §5.1): secures one item of its class, base
## down on its origin, frozen so no burn can move it.

func _item(stow_class := &"small") -> Item:
	var d := ItemDefinition.new()
	d.id = &"thing"
	d.display_name = "Thing"
	d.size = Vector3(0.1, 0.2, 0.1)
	d.stow_class = stow_class
	d.look = &"crate"
	var item := Item.new()
	item.setup(d)
	add_child_autofree(item)
	return item

func _point(accepts := &"small") -> StowPoint:
	var p := StowPoint.new()
	p.accepts = accepts
	add_child_autofree(p)
	return p

func test_joins_the_stow_point_group():
	assert_true(_point().is_in_group(StowPoint.GROUP))

func test_accepts_only_its_class():
	var p := _point(&"sidearm")
	assert_false(p.fits(_item(&"small")))
	assert_true(p.fits(_item(&"sidearm")))

func test_holds_one_item():
	var p := _point()
	p.secure(_item())
	assert_false(p.is_free())
	assert_false(p.fits(_item()))

func test_secure_puts_the_items_base_on_the_point():
	var p := _point()
	p.position = Vector3(1, 2, 3)
	p.rotation = Vector3(0, 0.5, 0)
	var item := _item()
	p.secure(item)
	assert_almost_eq(item.global_position, p.global_transform * Vector3(0, 0.1, 0), Vector3.ONE * 0.0001)
	assert_true(item.global_basis.is_equal_approx(p.global_basis))
	assert_eq(item.state, Item.State.STOWED)
	assert_true(item.freeze)
	assert_eq(item.stow_point, p)

func test_release_lets_it_loose():
	var p := _point()
	var item := _item()
	p.secure(item)
	assert_eq(p.release(), item)
	assert_eq(item.state, Item.State.LOOSE)
	assert_false(item.freeze)
	assert_true(p.is_free())

func test_a_freed_item_frees_its_point():
	var p := _point()
	var item := Item.new()
	var d := ItemDefinition.new()
	d.look = &"crate"
	item.setup(d)
	add_child(item)
	p.secure(item)
	remove_child(item)
	item.free()
	assert_true(p.is_free())
```

- [ ] **Step 2: Run them to see them fail**

Run: `run_tests.ps1 -gselect=test_item` → FAIL, `Item` not declared.

- [ ] **Step 3: Name physics layer 6**

In `who-knows/project.godot`, under `[layer_names]`, after `3d_physics/layer_3="avatar"`, add:

```
3d_physics/layer_6="items"
```

- [ ] **Step 4: Write `ItemUse`**

`who-knows/src/items/item_use.gd`:

```gdscript
class_name ItemUse
extends Node

## What an item does when its holder uses it (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §4.4). An Item instantiates its
## definition's `use` script as a child named "Use". This base does nothing;
## PlasmaEmitter is the first real one.

## `aim` is the holder's eye: origin at the eye, -z along the view. `world` is
## where anything the use spawns goes. `holder` is left out of anything the use
## casts. Returns true when the use happened.
func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
	return false
```

- [ ] **Step 5: Write `Item`**

`who-knows/src/items/item.gd`:

```gdscript
class_name Item
extends RigidBody3D

## A thing you can pick up (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §4.4): a rigid body built from an
## ItemDefinition, with one box collider and a look from ItemLooks.
##
## STOWED: frozen at a StowPoint, deaf to the felt-gravity field. LOOSE:
## dynamic; it falls, slides and can be shot across a room. HELD: a wielded
## item is frozen into a hand and leaves the physics world; a carried one
## stays dynamic, so it still bumps into walls.
##
## Knows nothing about avatars. Whoever interacts with it is an actor that may
## implement take_item(item) and can_take_item(item) -> bool; that is the whole
## contract.

enum State { STOWED, LOOSE, HELD }

## What one person can lift.
const LIFT_LIMIT_KG := 40.0
## project.godot 3d_physics/layer_6 "items", as a bit.
const LAYER := 32
## interior_geometry | avatar | items.
const MASK := 2 | 4 | 32
const FRICTION := 0.5
const BOUNCE := 0.15

static var _material: PhysicsMaterial

var definition: ItemDefinition
var state: State = State.LOOSE
## The point securing it, while STOWED.
var stow_point: StowPoint = null
## Its use behaviour, if the definition has one.
var use_node: ItemUse = null

var _shape: BoxShape3D

## Builds the look, the collider and the use. Call once, before the item
## enters the tree.
func setup(def: ItemDefinition, variety := 0.0) -> void:
	definition = def
	name = String(def.id).to_pascal_case() if def.id != &"" else "Item"
	mass = def.mass_kg
	collision_layer = LAYER
	collision_mask = MASK
	continuous_cd = true
	physics_material_override = _physics_material()
	_shape = BoxShape3D.new()
	_shape.size = def.size
	var collider := CollisionShape3D.new()
	collider.name = "Collider"
	collider.shape = _shape
	add_child(collider)
	var look := Node3D.new()
	look.name = "Look"
	add_child(look)
	var kit := InteriorKit.new(look)
	ItemLooks.build(kit, def.look, def.size, variety)
	kit.commit()
	if def.use != null:
		use_node = def.use.new() as ItemUse
		use_node.name = "Use"
		add_child(use_node)
	add_to_group(&"interactable")

func shape() -> BoxShape3D:
	return _shape

## Secured at `point`: frozen static, so it ignores the felt-gravity field.
func set_stowed(point: StowPoint) -> void:
	state = State.STOWED
	stow_point = point
	collision_layer = LAYER
	collision_mask = MASK
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true

func set_loose() -> void:
	state = State.LOOSE
	stow_point = null
	collision_layer = LAYER
	collision_mask = MASK
	freeze = false

## In someone's hands. A wielded item is frozen kinematic and leaves the
## physics world, so it can never shove anything from inside a hand; a
## carried one stays dynamic and solid.
func set_held(wielded: bool) -> void:
	state = State.HELD
	stow_point = null
	if wielded:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = LAYER
		collision_mask = MASK
		freeze = false

func prompt_text() -> String:
	if definition.mass_kg > LIFT_LIMIT_KG:
		return "Too heavy"
	if state == State.STOWED:
		return "Take %s" % definition.display_name
	return "Pick up %s" % definition.display_name

func can_interact(actor: Node) -> bool:
	if state == State.HELD:
		return false
	if actor != null and actor.has_method(&"can_take_item"):
		return actor.can_take_item(self)
	return true

func interact(actor: Node) -> void:
	if actor != null and actor.has_method(&"take_item"):
		actor.take_item(self)

func use(aim: Transform3D, world: Node3D, holder: CollisionObject3D) -> bool:
	return use_node != null and use_node.use(self, aim, world, holder)

static func _physics_material() -> PhysicsMaterial:
	if _material == null:
		_material = PhysicsMaterial.new()
		_material.friction = FRICTION
		_material.bounce = BOUNCE
	return _material
```

- [ ] **Step 6: Write `StowPoint`**

`who-knows/src/items/stow_point.gd`:

```gdscript
class_name StowPoint
extends Node3D

## A place that secures one item (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §5.1): a rack cradle, a spot on a
## counter, a place on a shelf. Its origin is where the stowed item's base
## sits -- the centre of the item's local -y face -- and the item's axes lie
## along its own. A secured item is frozen, so no burn can move it.

const GROUP := &"stow_point"

## The stow class it takes (ItemDefinition.stow_class).
@export var accepts: StringName
## The item id stocked here when a ship first loads, or &"".
@export var stock: StringName

var item: Item = null

func _init() -> void:
	add_to_group(GROUP)

func is_free() -> bool:
	return item == null or not is_instance_valid(item) or item.stow_point != self

func fits(candidate: Item) -> bool:
	return is_free() and candidate != null and candidate.definition.stow_class == accepts

## Where an item's origin goes when it is secured here.
func item_transform(candidate: Item) -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, candidate.definition.size.y * 0.5, 0.0))

func secure(candidate: Item) -> void:
	item = candidate
	candidate.set_stowed(self)
	candidate.global_transform = item_transform(candidate)
	candidate.linear_velocity = Vector3.ZERO
	candidate.angular_velocity = Vector3.ZERO

## Lets the item go loose and forgets it.
func release() -> Item:
	var out := item
	item = null
	if out != null and is_instance_valid(out) and out.stow_point == self:
		out.set_loose()
	return out
```

- [ ] **Step 7: Add `item.gd` to `REUSABLE_FILES`** in `test_visual_style_rules.gd` (items never see the grid).

- [ ] **Step 8: Import, run, verify**

Import; run `-gselect=test_item`, `-gselect=test_stow_point`, `-gselect=test_visual_style_rules`. Expected PASS.

- [ ] **Step 9: Commit** — `feat: add the Item body and stow points`

---

### Task 3: Props publish spots; dressing places stow points

**Files:**
- Modify: `who-knows/src/ship/interior/interior_props.gd` (`weapon_rack`, `shelves`, new `weapon_rack_spots`, `galley_counter_spots`, `shelves_spots`, `shelf_top`, shelf constants, `STOW_CLEARANCE`)
- Modify: `who-knows/src/ship/interior/interior_dressing.gd` (`_room_piece`, new `_stow`)
- Modify: `who-knows/src/ship/interior_builder.gd` (new `stow_points()`)
- Test: `who-knows/test/unit/test_interior_props.gd`, `who-knows/test/unit/test_starter_shuttle.gd`

**Interfaces:**
- Consumes: `StowPoint`.
- Produces: `InteriorProps.weapon_rack_spots() -> Array`, `galley_counter_spots() -> Array`, `shelves_spots(width: float) -> Array` — each element `[Transform3D, StringName]` (frame in the prop's frame, stow class); `InteriorBuilder.stow_points() -> Array[StowPoint]`.

- [ ] **Step 1: Write the failing tests**

In `who-knows/test/unit/test_interior_props.gd`, change `test_shelves_are_solid` to expect 6 colliders:

```gdscript
func test_shelves_are_solid():
	InteriorProps.shelves(_kit, Transform3D.IDENTITY, 0.6)
	# Two posts and four boards, not one block: a single box would stop the
	# Interactor's ray before it reached anything stowed on a shelf.
	_built_with_colliders(6)
```

and add:

```gdscript
## Is `p` inside any of this prop's colliders? Frames here are the identity,
## so every collider is an axis-aligned box.
func _inside_a_collider(p: Vector3) -> bool:
	for c in _colliders():
		var size := (c.shape as BoxShape3D).size
		var local: Vector3 = c.transform.affine_inverse() * p
		if absf(local.x) < size.x * 0.5 and absf(local.y) < size.y * 0.5 and absf(local.z) < size.z * 0.5:
			return true
	return false

func _assert_spots_clear(spots: Array, classes: Array) -> void:
	assert_eq(spots.map(func(s): return s[1]), classes)
	for spot in spots:
		var xf: Transform3D = spot[0]
		assert_gt(xf.origin.z, 0.0, "a spot stands in front of the wall")
		assert_false(_inside_a_collider(xf * Vector3(0, 0.05, 0)),
			"a spot is clear of its prop's colliders, so the Interactor can reach what sits there")

func test_the_weapon_rack_has_two_pistol_cradles():
	InteriorProps.weapon_rack(_kit, Transform3D.IDENTITY, 0.3)
	_assert_built()
	_assert_spots_clear(InteriorProps.weapon_rack_spots(), [&"sidearm", &"sidearm"])

func test_the_galley_counter_holds_two_small_things():
	InteriorProps.galley_counter(_kit, Transform3D.IDENTITY, 0.3, false)
	_assert_built()
	_assert_spots_clear(InteriorProps.galley_counter_spots(), [&"small", &"small"])

func test_full_shelves_hold_two_canisters_and_a_crate():
	InteriorProps.shelves(_kit, Transform3D.IDENTITY, 0.6, 1.7)
	_assert_built()
	_assert_spots_clear(InteriorProps.shelves_spots(1.7), [&"small", &"small", &"crate"])

func test_narrow_shelves_hold_one_canister():
	InteriorProps.shelves(_kit, Transform3D.IDENTITY, 0.6, 0.85)
	_assert_built()
	_assert_spots_clear(InteriorProps.shelves_spots(0.85), [&"small"])

func test_shelf_spots_sit_on_the_boards():
	for spot in InteriorProps.shelves_spots(1.7):
		var y: float = (spot[0] as Transform3D).origin.y
		assert_true(y == InteriorProps.shelf_top(0) or y == InteriorProps.shelf_top(2), "on a board top")
```

In `who-knows/test/unit/test_starter_shuttle.gd`, add:

```gdscript
func _built() -> InteriorBuilder:
	var b := InteriorBuilder.new()
	add_child_autofree(b)
	b.bind(_grid, _cat)
	b.rebuild()
	return b

func _stock(b: InteriorBuilder) -> Dictionary:
	var out := {}
	for p in b.stow_points():
		if p.stock != &"":
			out[p.stock] = out.get(p.stock, 0) + 1
	return out

func test_the_weapon_rack_is_stocked_with_two_pistols():
	assert_eq(_stock(_built()).get(&"plasma_pistol", 0), 2)

func test_the_galley_counter_has_two_mugs():
	assert_eq(_stock(_built()).get(&"mug", 0), 2)

func test_the_closet_has_canisters_and_a_crate():
	var stock := _stock(_built())
	assert_gt(stock.get(&"canister", 0), 0)
	assert_eq(stock.get(&"crate", 0), 1)

func test_every_stow_point_takes_what_it_is_stocked_with():
	var items := ItemCatalog.load_from_dir()
	for p in _built().stow_points():
		if p.stock != &"":
			assert_eq(items.get_def(p.stock).stow_class, p.accepts, "%s fits its own point" % p.stock)
```

- [ ] **Step 2: Run to see them fail** — `-gselect=test_interior_props`, `-gselect=test_starter_shuttle`: FAIL (`weapon_rack_spots` not found).

- [ ] **Step 3: Publish spots and fix the colliders in `InteriorProps`**

Add after the `DOOR_HEIGHT` constant:

```gdscript
## Shelf boards: how many, where the lowest sits, and the pitch between them.
const SHELF_LEVELS := 4
const SHELF_BASE := 0.25
const SHELF_PITCH := 0.47
const SHELF_BOARD := 0.04
const SHELF_DEPTH := 0.4

## Half the width a stow spot keeps clear of decor, by stow class.
const STOW_CLEARANCE := {&"small": 0.12, &"crate": 0.27, &"sidearm": 0.15}
```

Replace `shelves()` with:

```gdscript
## Three shelves `width` wide, stacked with crates of seeded sizes and colours.
## The places in shelves_spots() stay clear for real items, and each post and
## board is its own collider so the Interactor can reach between them.
static func shelves(kit: InteriorKit, f: Transform3D, variety: float, width := 1.7) -> void:
	var half := width * 0.5
	for x in [-(half - 0.03), half - 0.03]:
		kit.bevel_box(SOLID, f * _at(Vector3(x, 1.0, 0.2)), Vector3(0.05, 2.0, SHELF_DEPTH), 0.015,
			_c(InteriorPalette.WALL_LOW))
		kit.collider(f * _at(Vector3(x, 1.0, 0.2)), Vector3(0.05, 2.0, SHELF_DEPTH))
	var spots := shelves_spots(width)
	for level in SHELF_LEVELS:
		var y := SHELF_BASE + level * SHELF_PITCH
		kit.bevel_box(SOLID, f * _at(Vector3(0, y, 0.2)), Vector3(width - 0.06, SHELF_BOARD, SHELF_DEPTH), 0.015,
			_c(InteriorPalette.TRIM))
		kit.collider(f * _at(Vector3(0, y, 0.2)), Vector3(width - 0.06, SHELF_BOARD, SHELF_DEPTH))
		var reserved := _reserved_on(spots, shelf_top(level))
		var x := -half + 0.13
		var k := 0
		while true:
			var h := fposmod(variety * 31.0 + level * 7.3 + k * 3.1, 1.0)
			var w := 0.25 + 0.2 * h
			x = _clear_of(reserved, x, w)
			if x + w > half - 0.07:
				break
			var tall := 0.18 + 0.18 * fposmod(h * 5.7, 1.0)
			kit.bevel_box(SOLID, f * _at(Vector3(x + w * 0.5, y + 0.02 + tall * 0.5, 0.2)),
				Vector3(w - 0.03, tall, 0.3), 0.03, _c(InteriorPalette.CRATES[int(h * 5.0) % 5]))
			x += w + 0.04
			k += 1

## The top surface of shelf board `level`.
static func shelf_top(level: int) -> float:
	return SHELF_BASE + level * SHELF_PITCH + SHELF_BOARD * 0.5

## Where shelves hold loose items (hands-and-items spec §5.2): canisters on the
## third board and, on a full-width unit, a crate on the lowest. Each spot is
## [frame, stow class]; a frame's origin is where the item's base sits.
static func shelves_spots(width: float) -> Array:
	var half := width * 0.5
	var out: Array = [[_at(Vector3(-half + 0.2, shelf_top(2), 0.2)), &"small"]]
	if width >= 1.2:
		out.append([_at(Vector3(-half + 0.45, shelf_top(2), 0.2)), &"small"])
		out.append([_at(Vector3(half - 0.35, shelf_top(0), 0.2)), &"crate"])
	return out

## The x ranges a shelf board keeps clear for the spots on it.
static func _reserved_on(spots: Array, top: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for spot in spots:
		var at: Vector3 = (spot[0] as Transform3D).origin
		if absf(at.y - top) < 0.001:
			var clear: float = STOW_CLEARANCE.get(spot[1], 0.15)
			out.append(Vector2(at.x - clear, at.x + clear))
	return out

## Moves a decor crate starting at `x`, `w` wide, past any reserved range it
## would overlap.
static func _clear_of(reserved: Array[Vector2], x: float, w: float) -> float:
	var moved := true
	while moved:
		moved = false
		for r in reserved:
			if x < r.y and x + w > r.x:
				x = r.y + 0.04
				moved = true
	return x
```

Add after `galley_counter()`:

```gdscript
## Two small things on the galley worktop, between the sink and the cooktop.
static func galley_counter_spots() -> Array:
	return [
		[_at(Vector3(-0.08, 0.91, 0.36)), &"small"],
		[_at(Vector3(0.12, 0.91, 0.36)), &"small"],
	]
```

Replace `weapon_rack()` with:

```gdscript
## Three chunky rifles on a rack over a gunmetal cabinet, with coral warning
## stripes, and a pistol cradle either side (weapon_rack_spots()). The rifles
## and cradles stand under 0.15 m proud, so only the cabinet is solid and the
## pistols stay in reach of the Interactor.
static func weapon_rack(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var gun := _c(InteriorPalette.GUNMETAL)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.2, 0.175)), Vector3(1.6, 0.4, 0.35), 0.04, gun)
	kit.box(SOLID, f * _at(Vector3(0, 0.36, 0.352)), Vector3(1.6, 0.05, 0.01), _c(InteriorPalette.CORAL))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.15, 0.025)), Vector3(1.6, 1.1, 0.05), 0.02, _c(InteriorPalette.WALL_LOW))
	kit.box(SOLID, f * _at(Vector3(0, 1.67, 0.052)), Vector3(1.6, 0.05, 0.01), _c(InteriorPalette.CORAL))
	for i in 3:
		var x := -0.3 + i * 0.3
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.75, 0.1)), Vector3(0.1, 0.22, 0.07), 0.02, _c(InteriorPalette.WOOD))
		kit.bevel_box(SOLID, f * _at(Vector3(x, 1.13, 0.1)), Vector3(0.11, 0.55, 0.08), 0.02, gun)
		kit.bevel_box(SOLID, f * _at(Vector3(x + 0.07, 1.05, 0.1)), Vector3(0.05, 0.16, 0.06), 0.012, gun)
		kit.tube_between(SOLID, f * Vector3(x, 1.4, 0.1), f * Vector3(x, 1.6, 0.1), 0.018, gun)
		kit.disc(GLOW, f * _at(Vector3(x, 1.27, 0.141)), 0.012, _lit(InteriorPalette.SKY, 1.5))
	for spot in weapon_rack_spots():
		var at: Vector3 = (spot[0] as Transform3D).origin
		kit.bevel_box(SOLID, f * _at(Vector3(at.x, at.y - 0.02, 0.075)), Vector3(0.26, 0.04, 0.1), 0.012,
			_c(InteriorPalette.TRIM))
		kit.disc(GLOW, f * _at(Vector3(at.x, at.y - 0.12, 0.051)), 0.014, _lit(InteriorPalette.SKY, 1.5))
	kit.disc(GLOW, f * _at(Vector3(0.7, 0.3, 0.352)), 0.025, _lit(InteriorPalette.AMBER, 1.6, 0.5))
	kit.collider(f * _at(Vector3(0, 0.2, 0.175)), Vector3(1.6, 0.4, 0.35))

## The rack's two pistol cradles, muzzles pointing outward along the wall.
static func weapon_rack_spots() -> Array:
	return [
		[Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.6, 1.0, 0.085)), &"sidearm"],
		[Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.6, 1.0, 0.085)), &"sidearm"],
	]
```

- [ ] **Step 4: Place stow points in `InteriorDressing`**

In `_room_piece`, change the galley, closet and weapon room branches to:

```gdscript
		&"galley":
			if feature:
				InteriorProps.galley_counter(kit, f, variety, porthole)
				_stow(kit, f, InteriorProps.galley_counter_spots(), {&"small": &"mug"})
			else:
				InteriorProps.fridge(kit, f, variety)
```

```gdscript
		&"closet":
			var width := 1.7 if feature else 0.85
			InteriorProps.shelves(kit, f, variety, width)
			_stow(kit, f, InteriorProps.shelves_spots(width), {&"small": &"canister", &"crate": &"crate"})
		&"weapon_room":
			if feature:
				InteriorProps.weapon_rack(kit, f, variety)
				_stow(kit, f, InteriorProps.weapon_rack_spots(), {&"sidearm": &"plasma_pistol"})
			else:
				InteriorProps.ammo_crates(kit, f, variety)
```

Add after `_room_piece`:

```gdscript
## A StowPoint at every spot a prop publishes, stocked by stow class
## (hands-and-items spec §5.2). The prop decides where things can sit; this
## decides what a ship starts with there.
static func _stow(kit: InteriorKit, f: Transform3D, spots: Array, stock: Dictionary) -> void:
	for spot in spots:
		var point := StowPoint.new()
		point.name = "StowPoint"
		point.transform = f * (spot[0] as Transform3D)
		point.accepts = spot[1]
		point.stock = stock.get(spot[1], &"")
		kit.root.add_child(point, true)
```

- [ ] **Step 5: Expose stow points from `InteriorBuilder`**

Add after `gravity_at()`:

```gdscript
## Every StowPoint the last rebuild() placed (hands-and-items spec §5).
func stow_points() -> Array[StowPoint]:
	var out: Array[StowPoint] = []
	if not is_instance_valid(_physics_body):
		return out
	for node in _physics_body.find_children("*", "Node3D", true, false):
		if node is StowPoint:
			out.append(node)
	return out
```

- [ ] **Step 6: Run** `-gselect=test_interior_props`, `-gselect=test_starter_shuttle`, `-gselect=test_interior_dressing`, `-gselect=test_visual_style_rules`. Expected PASS.

- [ ] **Step 7: Commit** — `feat: racks, counters and shelves publish stow points`

---

### Task 4: The felt-gravity field

**Files:**
- Create: `who-knows/src/ship/felt_gravity.gd`
- Modify: `who-knows/src/ship/interior_builder.gd`, `who-knows/src/camera/motion_coupling.gd`, `who-knows/scenes/flight_test.tscn`
- Modify: `who-knows/test/unit/test_interior_builder.gd` (helper excludes FeltGravity shapes; new tests)
- Test: `who-knows/test/unit/test_felt_gravity.gd`, `who-knows/test/unit/test_motion_coupling.gd`

**Interfaces:**
- Consumes: `Item`.
- Produces: `FeltGravity` (`WAKE_THRESHOLD = 0.5`, `felt: Vector3`, `set_cells(centres: Array, size: Vector3)`, `cell_count() -> int`, `set_felt(accel: Vector3)`); `InteriorBuilder.felt_gravity: FeltGravity`; `MotionCoupling.interior_builder_path: NodePath`, `MotionCoupling.drive_felt_gravity(shove: Vector3)`.

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_felt_gravity.gd`:

```gdscript
extends GutTest

## FeltGravity (hands-and-items spec §6): plating gravity plus the hull's shove,
## applied by the engine to every loose item inside, and a net for any item
## that tunnels out.

var _field: FeltGravity

func before_each():
	_field = FeltGravity.new()
	add_child_autofree(_field)
	_field.set_cells([Vector3(0, 1.3, 0)], Vector3(2, 2.6, 2))

func _item_at(pos: Vector3) -> Item:
	var d := ItemDefinition.new()
	d.id = &"crate"
	d.display_name = "Crate"
	d.size = Vector3(0.2, 0.2, 0.2)
	d.look = &"crate"
	var item := Item.new()
	item.setup(d)
	add_child_autofree(item)
	item.global_position = pos
	item.set_loose()
	return item

func test_one_box_per_cell_replaced_on_every_call():
	_field.set_cells([Vector3.ZERO, Vector3(2, 0, 0), Vector3(4, 0, 0)], Vector3(2, 2.6, 2))
	assert_eq(_field.cell_count(), 3)
	_field.set_cells([Vector3.ZERO], Vector3(2, 2.6, 2))
	assert_eq(_field.cell_count(), 1, "rebuilding replaces the boxes instead of adding to them")

func test_only_items_feel_it():
	assert_eq(_field.collision_layer, 0)
	assert_eq(_field.collision_mask, Item.LAYER)
	assert_eq(_field.gravity_space_override, Area3D.SPACE_OVERRIDE_REPLACE)
	assert_false(_field.gravity_point)

func test_set_felt_sets_the_engines_gravity():
	var felt := Vector3(0, -9.8, 3.0)
	_field.set_felt(felt)
	assert_almost_eq(_field.gravity, felt.length(), 0.0001)
	assert_almost_eq(_field.gravity_direction, felt.normalized(), Vector3.ONE * 0.0001)
	assert_eq(_field.felt, felt)

func test_a_loose_item_falls_along_the_felt_vector():
	_field.set_felt(Vector3(0, 0, 5))
	var item := _item_at(Vector3(0, 1.3, 0))
	await wait_physics_frames(12)
	assert_gt(item.linear_velocity.z, 0.3, "pushed along the felt vector")
	assert_almost_eq(item.linear_velocity.y, 0.0, 0.01, "and nothing else: project gravity is zero")

func test_a_resting_item_wakes_when_the_felt_changes():
	_field.set_felt(Vector3.ZERO)
	var item := _item_at(Vector3(0, 1.3, 0))
	await wait_physics_frames(3)
	item.sleeping = true
	_field.set_felt(Vector3(0, 0, 3))
	assert_false(item.sleeping, "a change of 3 m/s² wakes it")

func test_a_small_change_lets_it_sleep():
	_field.set_felt(Vector3.ZERO)
	var item := _item_at(Vector3(0, 1.3, 0))
	await wait_physics_frames(3)
	item.sleeping = true
	_field.set_felt(Vector3(0, 0, 0.2))
	assert_true(item.sleeping)

func test_a_loose_item_that_leaves_is_put_back():
	_field.set_felt(Vector3.ZERO)
	var item := _item_at(Vector3(0, 1.3, 0))
	await wait_physics_frames(3)
	item.global_position = Vector3(10, 1.3, 0)
	await wait_physics_frames(4)
	assert_almost_eq(item.global_position, Vector3(0, 1.3, 0), Vector3.ONE * 0.05)

func test_a_held_item_that_leaves_is_not():
	_field.set_felt(Vector3.ZERO)
	var item := _item_at(Vector3(0, 1.3, 0))
	await wait_physics_frames(3)
	item.set_held(false)
	item.global_position = Vector3(10, 1.3, 0)
	await wait_physics_frames(4)
	assert_gt(item.global_position.x, 9.0)
```

`who-knows/test/unit/test_motion_coupling.gd`:

```gdscript
extends GutTest

## MotionCoupling drives the felt-gravity field from exactly the numbers it
## shoves the avatar with (hands-and-items spec §6).

var _root: Node

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)

func test_the_interior_builder_path_survived_the_parse():
	var mc: MotionCoupling = _root.get_node("Ship/MotionCoupling")
	assert_eq(mc.interior_builder_path, NodePath("../Interior/InteriorBuilder"))

func test_felt_gravity_is_plating_plus_the_avatars_shove():
	var mc: MotionCoupling = _root.get_node("Ship/MotionCoupling")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var builder: InteriorBuilder = _root.get_node("Ship/Interior/InteriorBuilder")
	mc.drive_felt_gravity(Vector3(0, 0, 3))
	assert_almost_eq(builder.felt_gravity.felt, Vector3.DOWN * avatar.grav_strength + Vector3(0, 0, 3),
		Vector3.ONE * 0.0001)
```

In `who-knows/test/unit/test_interior_builder.gd`, change `_structure_colliders()` to:

```gdscript
## Structure colliders only: the dressing's props carry their own, and the
## felt-gravity field's boxes are not structure.
func _structure_colliders() -> Array:
	return _builder.find_children("*", "CollisionShape3D", true, false).filter(
		func(c): return not c.is_in_group(InteriorKit.GROUP) and not (c.get_parent() is FeltGravity))
```

and add:

```gdscript
func test_the_felt_gravity_covers_every_walkable_cell_at_storey_height():
	_put(Vector3i.ZERO, &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	_builder.rebuild()
	var field := _builder.felt_gravity
	assert_not_null(field)
	assert_eq(field.cell_count(), 2)
	var centres := []
	for shape in field.get_children().filter(func(n): return n is CollisionShape3D):
		assert_eq((shape.shape as BoxShape3D).size,
			Vector3(ShipGrid.CELL_SIZE, InteriorBuilder.STOREY_HEIGHT, ShipGrid.CELL_SIZE))
		centres.append(shape.position)
	assert_has(centres, InteriorBuilder.interior_center(Vector3i.ZERO))
	assert_has(centres, InteriorBuilder.interior_center(Vector3i(1, 0, 0)))

func test_the_felt_gravity_survives_rebuilds():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	var field := _builder.felt_gravity
	_builder.rebuild()
	_builder.rebuild()
	assert_same(_builder.felt_gravity, field)
	assert_eq(field.cell_count(), 1)
	assert_eq(_builder.get_children().filter(func(n): return n is FeltGravity).size(), 1)

func test_the_felt_gravity_starts_at_plating_gravity():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	assert_almost_eq(_builder.felt_gravity.felt, Vector3.DOWN * InteriorBuilder.DEFAULT_GRAVITY,
		Vector3.ONE * 0.0001)
```

- [ ] **Step 2: Run to see them fail** — FAIL, `FeltGravity` not declared.

- [ ] **Step 3: Write `FeltGravity`**

`who-knows/src/ship/felt_gravity.gd`:

```gdscript
class_name FeltGravity
extends Area3D

## The interior's felt gravity (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §6): plating gravity plus the hull's
## shove, applied by the engine's own Area3D gravity override to every loose
## item inside. MotionCoupling sets it each tick from the numbers it shoves the
## avatar with, so you and a crate beside you feel the same thing.
##
## Also the interior's net: a LOOSE item that leaves every cell -- it tunnelled
## through a wall -- is put back where it last was inside, at rest.

## A change of felt gravity bigger than this wakes the bodies resting in it,
## which would otherwise sleep straight through a burn.
const WAKE_THRESHOLD := 0.5

var felt := Vector3.ZERO

var _woken_at := Vector3.ZERO
var _last_inside: Dictionary = {}   # instance id -> Vector3

func _init() -> void:
	collision_layer = 0
	collision_mask = Item.LAYER
	monitorable = false
	monitoring = true
	gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	gravity_point = false
	body_exited.connect(_on_body_exited)
	set_felt(Vector3.ZERO)

## One box `size` big centred on each of `centres`, replacing the last set.
func set_cells(centres: Array, size: Vector3) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.free()
	for centre: Vector3 in centres:
		var box := BoxShape3D.new()
		box.size = size
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = centre
		add_child(shape)

func cell_count() -> int:
	return get_children().filter(func(n): return n is CollisionShape3D).size()

func set_felt(accel: Vector3) -> void:
	felt = accel
	var g := accel.length()
	gravity = g if g > 0.0001 else 0.0
	if g > 0.0001:
		gravity_direction = accel / g
	if (accel - _woken_at).length() > WAKE_THRESHOLD:
		_woken_at = accel
		if is_inside_tree():
			for body in get_overlapping_bodies():
				if body is RigidBody3D and not body.freeze:
					body.sleeping = false

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Item and body.state == Item.State.LOOSE:
			_last_inside[body.get_instance_id()] = body.global_position

func _on_body_exited(body: Node3D) -> void:
	var id := body.get_instance_id()
	var back: Variant = _last_inside.get(id)
	_last_inside.erase(id)
	if back == null or not (body is Item) or body.state != Item.State.LOOSE:
		return
	# Moving a body from inside a physics callback is unsafe; do it after.
	_put_back.call_deferred(body, back)

func _put_back(body: Item, at: Vector3) -> void:
	if not is_instance_valid(body) or body.state != Item.State.LOOSE or not body.is_inside_tree():
		return
	body.global_position = at
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
```

- [ ] **Step 4: Own it in `InteriorBuilder`**

Add after `var _physics_body: StaticBody3D`:

```gdscript

## The interior's felt gravity (hands-and-items spec §6). It persists across
## rebuilds, so MotionCoupling can hold on to it; each rebuild only replaces
## its boxes, one per walkable cell.
var felt_gravity: FeltGravity
```

In `rebuild()`, make the first lines:

```gdscript
func rebuild() -> void:
	_clear()
	_ensure_felt_gravity()
	if _grid == null or _catalog == null:
		return
```

and after `_compute_gravity()` at its end add `_fill_felt_gravity()`. In `_clear()` add, before `_physics_body = null`:

```gdscript
	if felt_gravity != null:
		felt_gravity.set_cells([], Vector3.ZERO)
```

Add after `_compute_gravity()`'s definition:

```gdscript
func _ensure_felt_gravity() -> void:
	if felt_gravity != null:
		return
	felt_gravity = FeltGravity.new()
	felt_gravity.name = "FeltGravity"
	add_child(felt_gravity)
	felt_gravity.set_felt(Vector3.DOWN * DEFAULT_GRAVITY)

func _fill_felt_gravity() -> void:
	var centres: Array[Vector3] = []
	for coord in _walkable:
		centres.append(interior_center(coord))
	felt_gravity.set_cells(centres, Vector3(ShipGrid.CELL_SIZE, STOREY_HEIGHT, ShipGrid.CELL_SIZE))
```

- [ ] **Step 5: Drive it from `MotionCoupling`**

Add the export after `interior_sky_path`:

```gdscript
## The InteriorBuilder whose FeltGravity loose items feel (hands-and-items
## spec §6). Optional: with none, only the avatar is shoved.
@export var interior_builder_path: NodePath
```

and the onready after `_sky`:

```gdscript
@onready var _builder: InteriorBuilder = (
	get_node_or_null(interior_builder_path) if not interior_builder_path.is_empty() else null)
```

In `_physics_process`, replace `_avatar.external_accel = -accel_local * shove_scale` with:

```gdscript
	var shove := -accel_local * shove_scale
	_avatar.external_accel = shove
	drive_felt_gravity(shove)
```

and add:

```gdscript
## Sets the interior's felt gravity to exactly what the avatar integrates
## (Avatar._physics_process): plating gravity plus the shove.
func drive_felt_gravity(shove: Vector3) -> void:
	if _builder == null or _builder.felt_gravity == null:
		return
	_builder.felt_gravity.set_felt(Vector3.DOWN * _avatar.grav_strength + shove)
```

- [ ] **Step 6: Wire the path in `flight_test.tscn`**

In the `[node name="MotionCoupling" ...]` block, after `interior_sky_path = NodePath("../Interior/SkyPivot")`, add the line (no comment):

```
interior_builder_path = NodePath("../Interior/InteriorBuilder")
```

- [ ] **Step 7: Import, run** `-gselect=test_felt_gravity`, `-gselect=test_motion_coupling`, `-gselect=test_interior_builder`, then the full suite. Expected PASS, pristine.

- [ ] **Step 8: Commit** — `feat: loose items feel the ship's motion through a felt-gravity field`

---

### Task 5: Ships arrive stocked

**Files:**
- Modify: `who-knows/src/ship/ship.gd`
- Test: `who-knows/test/unit/test_ship_items.gd`

**Interfaces:**
- Consumes: `ItemCatalog`, `Item`, `StowPoint`, `InteriorBuilder.stow_points()`.
- Produces: `Ship.items: Node3D` (`Interior/Items`), `Ship.item_catalog: ItemCatalog`, `Ship.RESEAT_TOLERANCE = 0.05`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_ship_items.gd`:

```gdscript
extends GutTest

## Ships arrive stocked (hands-and-items spec §5.3): every stocked stow point
## gets its item once, rebuilds keep stowed items where they were, and an item
## whose stow point disappears comes loose.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func _items() -> Array:
	return _ship.items.get_children().filter(func(n): return n is Item)

func _with_id(id: StringName) -> Array:
	return _items().filter(func(i): return i.definition.id == id)

func test_items_live_under_the_interior():
	assert_eq(_ship.items.get_parent(), _ship.interior)
	assert_eq(_ship.items.name, "Items")

func test_every_stocked_point_holds_its_item():
	var stocked := 0
	for p in _ship.interior_builder.stow_points():
		if p.stock == &"":
			continue
		stocked += 1
		assert_false(p.is_free(), "%s is stocked" % p.stock)
		assert_eq(p.item.definition.id, p.stock)
		assert_eq(p.item.state, Item.State.STOWED)
	assert_gt(stocked, 0)
	assert_eq(_items().size(), stocked)

func test_the_weapon_rack_holds_two_plasma_pistols():
	assert_eq(_with_id(&"plasma_pistol").size(), 2)

func test_a_rebuild_neither_duplicates_nor_loses_items():
	var before := _items().size()
	_ship.set_grid(_ship.grid)
	assert_eq(_items().size(), before)
	for item in _items():
		assert_eq(item.state, Item.State.STOWED, "%s was re-seated" % item.name)
	for p in _ship.interior_builder.stow_points():
		if p.stock != &"":
			assert_false(p.is_free())

func test_a_stowed_item_whose_point_vanishes_comes_loose():
	var room := Vector3i.ZERO
	for coord in _ship.grid.coords():
		if _ship.grid.get_block(coord).block_id == &"weapon_room":
			room = coord
	var deck := BlockInstance.new()
	deck.block_id = &"deck"
	_ship.grid.set_block(room, deck)
	var pistols := _with_id(&"plasma_pistol")
	assert_eq(pistols.size(), 2)
	for p in pistols:
		assert_eq(p.state, Item.State.LOOSE)
```

- [ ] **Step 2: Run to see it fail** — FAIL, `items` not found on Ship.

- [ ] **Step 3: Stock and re-seat in `Ship`**

Add after `const SLOT_SPACING := 2000.0`:

```gdscript
## How close a rebuilt stow point must be to where a stowed item's point was
## for the item to stay stowed through the rebuild.
const RESEAT_TOLERANCE := 0.05
```

Add after `var catalog: BlockCatalog`:

```gdscript
var item_catalog: ItemCatalog
## Every item aboard that is not in someone's hand (hands-and-items spec
## §4.4). A sibling of the builders, so an interior rebuild never touches it.
var items: Node3D

var _stocked := false
```

At the end of `_ready()`:

```gdscript
	if item_catalog == null:
		item_catalog = ItemCatalog.load_from_dir("res://data/items")
	items = Node3D.new()
	items.name = "Items"
	interior.add_child(items)
```

Replace `_rebuild_everything()` with:

```gdscript
func _rebuild_everything() -> void:
	var stowed := _stowed_items()
	exterior_builder.rebuild()
	interior_builder.rebuild()
	_reseat(stowed)
	if not _stocked:
		_stock()
		_stocked = true
	stats = ShipStats.compute(grid, catalog)
	_apply_stats()
	stats_changed.emit(stats)

## Every stowed item and where its stow point was, before a rebuild frees the
## points.
func _stowed_items() -> Array:
	var out := []
	if items == null:
		return out
	for node in items.get_children():
		var item := node as Item
		if item != null and item.state == Item.State.STOWED and is_instance_valid(item.stow_point):
			out.append([item, item.stow_point.global_position])
	return out

## Puts each stowed item back in the rebuilt point at the same place, or lets
## it loose where it is if that point is gone.
func _reseat(stowed: Array) -> void:
	var points := interior_builder.stow_points()
	for entry in stowed:
		var item: Item = entry[0]
		var was: Vector3 = entry[1]
		var home: StowPoint = null
		for point in points:
			if point.fits(item) and point.global_position.distance_to(was) < RESEAT_TOLERANCE:
				home = point
				break
		if home != null:
			home.secure(item)
		else:
			item.set_loose()

## Fills every stocked stow point, once, when the ship first loads
## (hands-and-items spec §5.3).
func _stock() -> void:
	if items == null:
		return
	for point in interior_builder.stow_points():
		if point.stock == &"" or not point.is_free():
			continue
		var def := item_catalog.get_def(point.stock)
		if def == null:
			push_warning("Ship: no item called %s to stock" % point.stock)
			continue
		var item := Item.new()
		var at := point.global_position
		item.setup(def, fposmod(at.x * 0.37 + at.z * 0.61, 1.0))
		items.add_child(item, true)
		point.secure(item)
```

- [ ] **Step 4: Run** `-gselect=test_ship_items`, then the full suite. Expected PASS.

- [ ] **Step 5: Commit** — `feat: ships arrive with their racks and shelves stocked`

---

# Phase B — Grasp

### Task 6: Grasp and the input actions

**Files:**
- Create: `who-knows/src/avatar/grasp.gd`
- Modify: `who-knows/project.godot` (`use`, `throw`, `drop`), `who-knows/test/unit/test_input_map.gd`
- Test: `who-knows/test/unit/test_grasp.gd`

**Interfaces:**
- Consumes: `Item`, `ItemDefinition.Grip`, `StowPoint`.
- Produces: `Grasp` (`signal changed`, `signal used(item)`, `signal prompt_changed(text)`, `enum Mode {EMPTY, CARRYING, WIELDING}`, constants per spec §7, `mode`, `item`, `charge`, `enabled`, `first_person`, `wield_socket`, `world_root`, `bind(body: CharacterBody3D, head: Node3D, socket: Node3D = null)`, `set_enabled(on)`, `can_take(item) -> bool`, `take(item) -> bool`, `use() -> bool`, `aim() -> Transform3D`, `begin_throw()`, `finish_throw()`, `throw(amount)`, `static throw_speed(mass_kg, amount) -> float`, `drop()`, `stow_target() -> StowPoint`, `hold_point() -> Vector3`).

- [ ] **Step 1: Write the failing tests**

Extend `who-knows/test/unit/test_input_map.gd`: add `&"use", &"throw", &"drop"` to `REQUIRED_ACTIONS`, and add:

```gdscript
func test_hand_actions_are_bound_to_the_mouse_and_g():
	var use_ev: InputEventMouseButton = InputMap.action_get_events(&"use")[0]
	assert_eq(use_ev.button_index, MOUSE_BUTTON_LEFT)
	var throw_ev: InputEventMouseButton = InputMap.action_get_events(&"throw")[0]
	assert_eq(throw_ev.button_index, MOUSE_BUTTON_RIGHT)
	var drop_ev: InputEventKey = InputMap.action_get_events(&"drop")[0]
	assert_eq(drop_ev.physical_keycode, KEY_G)
```

`who-knows/test/unit/test_grasp.gd`:

```gdscript
extends GutTest

## Grasp (hands-and-items spec §7), with real bodies stepped through physics
## frames: taking, carrying, throwing, dropping and stowing.

class CountingUse extends ItemUse:
	var count := 0
	func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
		count += 1
		return true

var _world: Node3D
var _body: CharacterBody3D
var _head: Node3D
var _grasp: Grasp

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_add_box(Vector3(0, -0.1, 0), Vector3(20, 0.2, 20))
	_body = CharacterBody3D.new()
	_body.collision_layer = 4
	_body.collision_mask = 2 | 32
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	_body.add_child(shape)
	_world.add_child(_body)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.6, 0)
	_body.add_child(_head)
	_grasp = Grasp.new()
	_body.add_child(_grasp)
	_grasp.bind(_body, _head)
	_grasp.world_root = _world

func _add_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	body.position = at
	_world.add_child(body)
	return body

func _item(grip := ItemDefinition.Grip.CARRY, mass := 4.0, at := Vector3(0, 1.3, -0.9)) -> Item:
	var d := ItemDefinition.new()
	d.id = &"thing"
	d.display_name = "Thing"
	d.mass_kg = mass
	d.size = Vector3(0.2, 0.2, 0.2)
	d.grip = grip
	d.stow_class = &"small"
	d.look = &"crate"
	d.grip_point = Vector3(0, -0.05, 0.05)
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = at
	item.set_loose()
	return item

func test_takes_a_wielded_item_into_the_hand():
	var item := _item(ItemDefinition.Grip.WIELD)
	assert_true(_grasp.take(item))
	assert_eq(_grasp.mode, Grasp.Mode.WIELDING)
	assert_eq(item.get_parent(), _grasp.wield_socket)
	assert_eq(item.state, Item.State.HELD)
	assert_almost_eq(item.position, -item.definition.grip_point, Vector3.ONE * 0.0001)

func test_carries_an_item_to_the_hold_point():
	var item := _item()
	assert_true(_grasp.take(item))
	assert_eq(_grasp.mode, Grasp.Mode.CARRYING)
	await wait_physics_frames(40)
	assert_lt(item.global_position.distance_to(_grasp.hold_point()), 0.1)

func test_hands_must_be_empty():
	_grasp.take(_item())
	var other := _item(ItemDefinition.Grip.CARRY, 4.0, Vector3(1, 1.3, -0.9))
	assert_false(_grasp.can_take(other))
	assert_false(_grasp.take(other))

func test_refuses_what_is_too_heavy():
	assert_false(_grasp.take(_item(ItemDefinition.Grip.CARRY, 60.0)))
	assert_eq(_grasp.mode, Grasp.Mode.EMPTY)

func test_taking_a_stowed_item_frees_its_point():
	var point := StowPoint.new()
	point.accepts = &"small"
	_world.add_child(point)
	var item := _item()
	point.secure(item)
	assert_true(_grasp.take(item))
	assert_true(point.is_free())

func test_holding_ignores_the_holder():
	var item := _item()
	_grasp.take(item)
	assert_has(item.get_collision_exceptions(), _body)
	assert_has(_body.get_collision_exceptions(), item)

func test_drop_puts_a_wielded_item_back_in_the_world():
	var item := _item(ItemDefinition.Grip.WIELD)
	_grasp.take(item)
	_grasp.drop()
	assert_eq(item.get_parent(), _world)
	assert_eq(item.state, Item.State.LOOSE)
	assert_eq(item.collision_layer, Item.LAYER)
	assert_eq(_grasp.mode, Grasp.Mode.EMPTY)

func test_the_exception_outlasts_the_drop_until_they_part():
	var item := _item()
	_grasp.take(item)
	_grasp.drop()
	item.global_position = _body.global_position + Vector3(0, 0.9, 0)
	await wait_physics_frames(5)
	assert_has(item.get_collision_exceptions(), _body, "still overlapping: no pop")
	item.global_position = Vector3(3, 1, 0)
	await wait_physics_frames(3)
	assert_does_not_have(item.get_collision_exceptions(), _body, "apart: solid again")

func test_the_exception_gives_up_after_a_second():
	var item := _item()
	_grasp.take(item)
	_grasp.drop()
	item.global_position = _body.global_position + Vector3(0, 0.9, 0)
	item.freeze = true
	await wait_physics_frames(70)
	assert_does_not_have(item.get_collision_exceptions(), _body)

func test_throw_speed_scales_with_charge_and_mass():
	assert_almost_eq(Grasp.throw_speed(0.3, 1.0), 12.0, 0.001)
	assert_almost_eq(Grasp.throw_speed(12.0, 1.0), 12.0 * sqrt(5.0 / 12.0), 0.001)
	assert_almost_eq(Grasp.throw_speed(60.0, 1.0), 12.0 * 0.35, 0.001)
	assert_almost_eq(Grasp.throw_speed(1.0, 0.0), 3.0, 0.001)
	assert_almost_eq(Grasp.throw_speed(1.0, 0.5), 7.5, 0.001)

func test_a_throw_goes_where_you_look():
	_head.rotation.y = PI * 0.5
	var item := _item()
	_grasp.take(item)
	_grasp.throw(1.0)
	assert_eq(item.state, Item.State.LOOSE)
	assert_almost_eq(item.linear_velocity, Vector3(-12, 0, 0), Vector3.ONE * 0.01)

func test_winding_up_charges_over_time():
	_grasp.take(_item())
	_grasp.begin_throw()
	await wait_physics_frames(24)
	assert_almost_eq(_grasp.charge, 0.5, 0.1)
	_grasp.finish_throw()
	assert_eq(_grasp.mode, Grasp.Mode.EMPTY)
	assert_eq(_grasp.charge, -1.0)

func test_third_person_refuses_use_and_throw():
	var item := _item(ItemDefinition.Grip.WIELD)
	_grasp.take(item)
	_grasp.first_person = false
	_grasp.begin_throw()
	assert_eq(_grasp.charge, -1.0)
	assert_false(_grasp.use())

func test_a_snagged_item_is_let_go():
	var item := _item(ItemDefinition.Grip.CARRY, 30.0)
	_grasp.take(item)
	await wait_physics_frames(20)
	_head.position = Vector3(0, 1.6, 6)
	await wait_physics_frames(30)
	assert_eq(_grasp.mode, Grasp.Mode.EMPTY)
	assert_eq(item.state, Item.State.LOOSE)

func test_dropping_near_a_fitting_point_stows():
	var item := _item()
	_grasp.take(item)
	await wait_physics_frames(30)
	var point := StowPoint.new()
	point.accepts = &"small"
	_world.add_child(point)
	point.global_position = item.global_position - Vector3(0, 0.1, 0)
	_grasp.drop()
	assert_eq(item.state, Item.State.STOWED)
	assert_eq(point.item, item)
	assert_does_not_have(item.get_collision_exceptions(), _body)

func test_dropping_far_from_a_point_just_drops():
	var item := _item()
	_grasp.take(item)
	var point := StowPoint.new()
	point.accepts = &"small"
	_world.add_child(point)
	point.global_position = Vector3(5, 0, 5)
	_grasp.drop()
	assert_eq(item.state, Item.State.LOOSE)

func test_a_stow_prompt_appears_in_range():
	var item := _item()
	_grasp.take(item)
	await wait_physics_frames(30)
	watch_signals(_grasp)
	var point := StowPoint.new()
	point.accepts = &"small"
	_world.add_child(point)
	point.global_position = item.global_position - Vector3(0, 0.1, 0)
	await wait_physics_frames(2)
	assert_signal_emitted_with_parameters(_grasp, "prompt_changed", [Grasp.STOW_PROMPT])

func test_disabling_sets_down_a_carried_item():
	var item := _item()
	_grasp.take(item)
	_grasp.set_enabled(false)
	assert_eq(_grasp.mode, Grasp.Mode.EMPTY)
	assert_eq(item.state, Item.State.LOOSE)

func test_disabling_keeps_a_wielded_item_but_will_not_use_it():
	var item := _item(ItemDefinition.Grip.WIELD)
	_grasp.take(item)
	_grasp.set_enabled(false)
	assert_eq(_grasp.mode, Grasp.Mode.WIELDING)
	assert_false(_grasp.use())

func test_a_wielded_item_is_released_clear_of_a_wall():
	_add_box(Vector3(0, 1.6, -0.3), Vector3(2, 2, 0.05))
	await wait_physics_frames(2)
	var item := _item(ItemDefinition.Grip.WIELD, 1.0, Vector3(0, 1.3, 0.9))
	_grasp.take(item)
	_grasp.drop()
	assert_gt(item.global_position.z, -0.3, "on the near side of the wall")

func test_use_calls_the_items_use_and_announces_it():
	var item := _item(ItemDefinition.Grip.WIELD)
	var use := CountingUse.new()
	item.use_node = use
	item.add_child(use)
	_grasp.take(item)
	watch_signals(_grasp)
	assert_true(_grasp.use())
	assert_eq(use.count, 1)
	assert_signal_emitted(_grasp, "used")
```

- [ ] **Step 2: Run to see them fail** — FAIL, `Grasp` not declared.

- [ ] **Step 3: Add the input actions**

In `who-knows/project.godot` `[input]`, after the `cycle_camera={...}` block, add:

```
use={
"deadzone": 0.2,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)]
}
throw={
"deadzone": 0.2,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":2,"canceled":false,"pressed":false,"double_click":false,"script":null)]
}
drop={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":71,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
```

- [ ] **Step 4: Write `Grasp`**

`who-knows/src/avatar/grasp.gd`:

```gdscript
class_name Grasp
extends Node

## What is in your hands (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §7): taking, carrying, throwing,
## dropping and stowing. Logic only; Hands draws it by reading `mode`, `item`
## and `charge`.
##
## A WIELD item is frozen into `wield_socket` and tracks the aim exactly. A
## CARRY item stays a real rigid body, pulled toward a hold point in front of
## the eye by a force-limited impulse: it bumps into walls, heavy things lag
## and sag, and a snag makes you let go.
##
## It knows its holder only as a CharacterBody3D and a head, so anything with
## a body and a head could carry things.

signal changed
signal used(item: Item)
signal prompt_changed(text: String)

enum Mode { EMPTY, CARRYING, WIELDING }

## Head-local hold point; half the item's depth is added in front of it.
const HOLD_OFFSET := Vector3(0.0, -0.25, -0.45)
## How quickly a carried item closes on the hold point, in seconds.
const HOLD_RESPONSE := 0.1
## The most force a hold can use: a 12 kg crate follows snappily, a 40 kg one
## barely beats gravity and sags.
const HOLD_FORCE := 400.0
const TURN_RESPONSE := 0.15
const MAX_SPIN := 12.0
const SNAG_DISTANCE := 0.8
const SNAG_TIME := 0.3
const THROW_MIN := 3.0
const THROW_MAX := 12.0
const CHARGE_TIME := 0.8
const THROW_REF_KG := 5.0
const THROW_MASS_FLOOR := 0.35
## How far the hold point and the throwing hand draw back at full charge.
const WIND_BACK := 0.12
const STOW_RANGE := 0.5
## The Interactor's reach: how far off a wielded item can be aimed at a point.
const REACH := 2.5
## Longest a released item keeps ignoring its holder while they overlap.
const RELEASE_GRACE := 1.0
## How far short of a wall a wielded item is released.
const WALL_MARGIN := 0.15
## Where the right hand closes, head-local, until Hands provides a socket.
const DEFAULT_SOCKET := Vector3(0.17, -0.2, -0.42)
## interior_geometry | items.
const RAY_MASK := 2 | 32
const STOW_PROMPT := "[G] Stow"

var mode: Mode = Mode.EMPTY
var item: Item = null
## 0..1 while winding up a throw, -1 otherwise.
var charge := -1.0
var enabled := true
## Use and throw need the reticle, so they work only in first person.
var first_person := true
var wield_socket: Node3D
## Where released items go.
var world_root: Node3D

var _body: CharacterBody3D
var _head: Node3D
var _hold_basis := Basis.IDENTITY
var _snag := 0.0
var _releasing: Array = []   # [Item, seconds left]
var _prompt := ""

func bind(body: CharacterBody3D, head: Node3D, socket: Node3D = null) -> void:
	_body = body
	_head = head
	wield_socket = socket
	if wield_socket == null:
		wield_socket = Node3D.new()
		wield_socket.name = "WieldSocket"
		wield_socket.position = DEFAULT_SOCKET
		head.add_child(wield_socket)

func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		charge = -1.0
		if mode == Mode.CARRYING:
			_release()
			changed.emit()

func can_take(candidate: Item) -> bool:
	return enabled and mode == Mode.EMPTY and candidate != null and candidate.state != Item.State.HELD

func take(candidate: Item) -> bool:
	if not can_take(candidate) or candidate.definition.mass_kg > Item.LIFT_LIMIT_KG:
		return false
	if candidate.state == Item.State.STOWED and candidate.stow_point != null:
		candidate.stow_point.release()
	_end_grace(candidate)
	item = candidate
	_ignore(candidate, true)
	if candidate.definition.grip == ItemDefinition.Grip.WIELD:
		candidate.set_held(true)
		candidate.reparent(wield_socket, false)
		candidate.transform = Transform3D(Basis.IDENTITY, -candidate.definition.grip_point)
		mode = Mode.WIELDING
	else:
		candidate.set_held(false)
		_hold_basis = _body.global_basis.inverse() * candidate.global_basis
		_snag = 0.0
		mode = Mode.CARRYING
	charge = -1.0
	changed.emit()
	return true

func use() -> bool:
	if not enabled or not first_person or mode != Mode.WIELDING:
		return false
	if not item.use(aim(), world_root, _body):
		return false
	used.emit(item)
	return true

## The eye: origin at the head, -z along the view.
func aim() -> Transform3D:
	return _head.global_transform

func begin_throw() -> void:
	if enabled and first_person and mode != Mode.EMPTY:
		charge = 0.0
		changed.emit()

func finish_throw() -> void:
	if charge < 0.0:
		return
	var amount := charge
	charge = -1.0
	if mode != Mode.EMPTY:
		throw(amount)

## How fast a throw leaves the hand: charge sets the effort, and heavy things
## go slower, by the square root of how much heavier than 5 kg they are.
static func throw_speed(mass_kg: float, amount: float) -> float:
	var heft := clampf(sqrt(THROW_REF_KG / maxf(mass_kg, 0.001)), THROW_MASS_FLOOR, 1.0)
	return lerpf(THROW_MIN, THROW_MAX, clampf(amount, 0.0, 1.0)) * heft

func throw(amount: float) -> void:
	if mode == Mode.EMPTY:
		return
	var thrown := item
	var direction := -aim().basis.z
	_release()
	thrown.linear_velocity = direction * throw_speed(thrown.mass, amount) + _body.velocity
	changed.emit()

## Lets go, or stows the item if a fitting stow point is in range.
func drop() -> void:
	if mode == Mode.EMPTY:
		return
	var point := stow_target()
	var dropped := item
	_release()
	if point != null:
		_end_grace(dropped)
		point.secure(dropped)
	changed.emit()

## The free stow point a drop would put the held item in, or null.
func stow_target() -> StowPoint:
	if item == null or not is_inside_tree():
		return null
	var ref := item.global_position
	if mode == Mode.WIELDING:
		var eye := aim()
		var hit := _ray(eye.origin, eye.origin - eye.basis.z * REACH)
		if hit.is_empty():
			return null
		ref = hit["position"]
	var best: StowPoint = null
	var best_distance := STOW_RANGE
	for node in get_tree().get_nodes_in_group(StowPoint.GROUP):
		var point := node as StowPoint
		if point == null or not point.fits(item):
			continue
		var at := point.global_position if mode == Mode.WIELDING else point.item_transform(item).origin
		var distance := at.distance_to(ref)
		if distance < best_distance:
			best = point
			best_distance = distance
	return best

## Where a carried item is pulled to: ahead of and below the eye, drawn back
## while winding up a throw.
func hold_point() -> Vector3:
	var depth := item.definition.size.z * 0.5 if item != null else 0.0
	return aim() * (HOLD_OFFSET + Vector3(0.0, 0.0, -depth + WIND_BACK * maxf(charge, 0.0)))

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed(&"use"):
		use()
	elif event.is_action_pressed(&"throw"):
		begin_throw()
	elif event.is_action_released(&"throw"):
		finish_throw()
	elif event.is_action_pressed(&"drop"):
		drop()

func _physics_process(delta: float) -> void:
	if _body == null:
		return
	_tick_grace(delta)
	if item != null and not is_instance_valid(item):
		item = null
		mode = Mode.EMPTY
		changed.emit()
	if mode == Mode.CARRYING:
		_hold(delta)
	if charge >= 0.0:
		charge = minf(charge + delta / CHARGE_TIME, 1.0)
	_update_prompt()

func _hold(delta: float) -> void:
	var gap := hold_point() - item.global_position
	_snag = _snag + delta if gap.length() > SNAG_DISTANCE else 0.0
	if _snag >= SNAG_TIME:
		_release()
		changed.emit()
		return
	var want := gap / HOLD_RESPONSE + _body.velocity
	var impulse := (want - item.linear_velocity) * item.mass
	item.apply_central_impulse(impulse.limit_length(HOLD_FORCE * delta))
	var target := (_body.global_basis * _hold_basis).get_rotation_quaternion()
	var turn := target * item.global_basis.get_rotation_quaternion().inverse()
	if turn.w < 0.0:
		turn = -turn
	var angle := turn.get_angle()
	var spin := Vector3.ZERO
	if angle > 0.001:
		spin = turn.get_axis() * angle / TURN_RESPONSE
	item.angular_velocity = spin.limit_length(MAX_SPIN)

## Lets go: the item goes back into the world loose, still ignoring its
## holder until the two no longer overlap.
func _release() -> void:
	var it := item
	var wielded := mode == Mode.WIELDING
	item = null
	mode = Mode.EMPTY
	charge = -1.0
	if wielded:
		var at := _clear_point(it.global_position)
		it.reparent(world_root, true)
		it.global_position = at
	it.set_loose()
	if wielded:
		it.linear_velocity = _body.velocity
		it.angular_velocity = Vector3.ZERO
	_releasing.append([it, RELEASE_GRACE])

## The point on the way from the eye to `to` that a ray proves is clear.
func _clear_point(to: Vector3) -> Vector3:
	var from := aim().origin
	var hit := _ray(from, to)
	if hit.is_empty():
		return to
	return (hit["position"] as Vector3) + (from - to).normalized() * WALL_MARGIN

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var exclude: Array[RID] = [_body.get_rid()]
	if item != null:
		exclude.append(item.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, exclude)
	return _body.get_world_3d().direct_space_state.intersect_ray(query)

func _tick_grace(delta: float) -> void:
	for i in range(_releasing.size() - 1, -1, -1):
		var entry: Array = _releasing[i]
		var it: Item = entry[0]
		entry[1] -= delta
		if not is_instance_valid(it) or entry[1] <= 0.0 or not _overlaps_holder(it):
			_releasing.remove_at(i)
			if is_instance_valid(it):
				_ignore(it, false)

func _end_grace(it: Item) -> void:
	for i in range(_releasing.size() - 1, -1, -1):
		if _releasing[i][0] == it:
			_releasing.remove_at(i)
	_ignore(it, false)

func _overlaps_holder(it: Item) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = it.shape()
	query.transform = it.global_transform
	query.collision_mask = _body.collision_layer
	for hit in _body.get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit["collider"] == _body:
			return true
	return false

func _ignore(it: Item, on: bool) -> void:
	if on:
		it.add_collision_exception_with(_body)
		_body.add_collision_exception_with(it)
	else:
		it.remove_collision_exception_with(_body)
		_body.remove_collision_exception_with(it)

func _update_prompt() -> void:
	var text := STOW_PROMPT if enabled and stow_target() != null else ""
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
```

- [ ] **Step 5: Import, run** `-gselect=test_grasp`, `-gselect=test_input_map`, full suite. Expected PASS.

- [ ] **Step 6: Commit** — `feat: add Grasp -- take, carry, throw, drop and stow`

---

### Task 7: The avatar holds things; the Interactor sees items

**Files:**
- Modify: `who-knows/src/avatar/avatar.gd`, `who-knows/src/avatar/interactor.gd`
- Test: `who-knows/test/unit/test_avatar.gd`, `who-knows/test/unit/test_interactor.gd`

**Interfaces:**
- Consumes: `Grasp`, `Item`.
- Produces: `Avatar.grasp: Grasp`, `Avatar.interactor: Interactor`, `Avatar.camera: Camera3D`, `Avatar.COLLISION_MASK = 34`, `Avatar.PUSH_FORCE = 150.0`, `Avatar.take_item(item)`, `Avatar.can_take_item(item) -> bool`; `Interactor.MASK = 34`, `Interactor.current() -> Node`.

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_avatar.gd`:

```gdscript
extends GutTest

## The avatar with hands (hands-and-items spec §7, §12): it owns a Grasp,
## collides with items, nudges loose ones, and a click that re-captures the
## mouse goes no further.

var _world: Node3D
var _avatar: Avatar

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	var floor := StaticBody3D.new()
	floor.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0, -0.1, 0)
	floor.add_child(shape)
	_world.add_child(floor)
	_avatar = load("res://scenes/avatar.tscn").instantiate()
	_world.add_child(_avatar)
	_avatar.grasp.world_root = _world

func after_each():
	Input.action_release(&"move_forward")

func _crate(at: Vector3) -> Item:
	var d := ItemDefinition.new()
	d.id = &"crate"
	d.display_name = "Crate"
	d.mass_kg = 12.0
	d.size = Vector3(0.45, 0.35, 0.35)
	d.look = &"crate"
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = at
	item.set_loose()
	return item

func test_the_avatar_owns_a_grasp():
	assert_not_null(_avatar.grasp)
	assert_eq(_avatar.grasp.get_parent(), _avatar)

func test_the_avatar_collides_with_items():
	assert_eq(_avatar.collision_mask, 2 | 32)

func test_plating_gravity_is_unchanged():
	assert_eq(_avatar.grav_strength, 9.8)

func test_taking_goes_through_the_grasp():
	var item := _crate(Vector3(0, 1.2, -1))
	assert_true(_avatar.can_take_item(item))
	_avatar.take_item(item)
	assert_eq(_avatar.grasp.item, item)
	assert_false(_avatar.can_take_item(_crate(Vector3(2, 1.2, -1))), "hands full")

func test_disabling_control_sets_down_a_carried_item():
	var item := _crate(Vector3(0, 1.2, -1))
	_avatar.take_item(item)
	_avatar.set_control_enabled(false)
	assert_eq(item.state, Item.State.LOOSE)

func test_walking_into_a_loose_crate_nudges_it():
	var crate := _crate(Vector3(0, 0.18, -0.9))
	await wait_physics_frames(10)
	Input.action_press(&"move_forward")
	await wait_physics_frames(40)
	Input.action_release(&"move_forward")
	assert_lt(crate.global_position.z, -1.0, "pushed ahead")

func test_the_click_that_recaptures_the_mouse_goes_no_further():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_avatar._unhandled_input(click)
	assert_true(get_viewport().is_input_handled())
```

`who-knows/test/unit/test_interactor.gd`:

```gdscript
extends GutTest

## The Interactor sees items (hands-and-items spec §7.2): it reaches the items
## layer, hides what cannot be taken, and never reports what you hold.

var _world: Node3D
var _avatar: Avatar
var _interactor: Interactor

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_avatar = load("res://scenes/avatar.tscn").instantiate()
	_interactor = Interactor.new()
	_avatar.get_node("Head").add_child(_interactor)
	_interactor.owner = _avatar
	_world.add_child(_avatar)
	_avatar.grasp.world_root = _world
	_avatar.set_physics_process(false)

func _item(at: Vector3) -> Item:
	var d := ItemDefinition.new()
	d.id = &"mug"
	d.display_name = "Mug"
	d.size = Vector3(0.3, 0.3, 0.3)
	d.grip = ItemDefinition.Grip.WIELD
	d.look = &"mug"
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = at
	item.set_stowed(null)
	return item

func test_reaches_items_and_interior_geometry():
	assert_eq(_interactor.collision_mask, 2 | 32)

func test_offers_an_item_in_front_of_you():
	var item := _item(Vector3(0, 1.6, -1.5))
	watch_signals(_interactor)
	await wait_physics_frames(3)
	assert_eq(_interactor.current(), item)
	assert_signal_emitted_with_parameters(_interactor, "prompt_changed", ["[F] Take Mug"])

func test_hides_an_item_you_cannot_take():
	_item(Vector3(0, 1.6, -1.5))
	_avatar.take_item(_item(Vector3(3, 1.6, 0)))
	await wait_physics_frames(3)
	assert_null(_interactor.current(), "hands full")

func test_never_reports_what_you_hold():
	var item := _item(Vector3(0, 1.6, -1.5))
	await wait_physics_frames(3)
	_avatar.take_item(item)
	await wait_physics_frames(3)
	assert_ne(_interactor.current(), item)
```

- [ ] **Step 2: Run to see them fail** — FAIL, `grasp` not found on Avatar.

- [ ] **Step 3: Update `Avatar`**

In `who-knows/src/avatar/avatar.gd` add after `const CROUCH_HEIGHT := 1.0`:

```gdscript
## How hard walking into a loose thing pushes it, at walking pace
## (hands-and-items spec §7.5).
const PUSH_FORCE := 150.0
## interior_geometry | items (project.godot 3d_physics layers 2 and 6).
const COLLISION_MASK := 2 | 32
```

After `var _pitch: float = 0.0` add:

```gdscript

## What is in your hands (hands-and-items spec §7).
var grasp: Grasp
## The ray that finds interactables, when the scene gives the head one.
var interactor: Interactor
```

After `@onready var head: Node3D = $Head` add `@onready var camera: Camera3D = $Head/Camera3D`.

Replace `_ready()` with:

```gdscript
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	collision_mask = COLLISION_MASK
	interactor = get_node_or_null("Head/Interactor") as Interactor
	grasp = Grasp.new()
	grasp.name = "Grasp"
	add_child(grasp)
	grasp.bind(self, head)

## The actor contract Item talks to.
func take_item(item: Item) -> void:
	grasp.take(item)

func can_take_item(item: Item) -> bool:
	return grasp.can_take(item)
```

In `set_control_enabled`, add `grasp.set_enabled(enabled)` as the first line after `_control_enabled = enabled`.

In `_unhandled_input`, replace the re-capture branch with:

```gdscript
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# The click only brings the mouse back. Nothing else may act on it --
		# it must not also fire whatever is in your hand.
		get_viewport().set_input_as_handled()
		return
```

At the end of `_physics_process`, replace `move_and_slide()` with:

```gdscript
	var pushing := velocity
	move_and_slide()
	_push_loose_things(pushing, delta)
```

and add:

```gdscript
## Nudges the loose things you walk into (hands-and-items spec §7.5), instead
## of stopping dead against them as if they were walls.
func _push_loose_things(pushing: Vector3, delta: float) -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as RigidBody3D
		if body == null or body.freeze:
			continue
		var into := -hit.get_normal()
		into.y = 0.0
		if into.length_squared() < 0.0001:
			continue
		into = into.normalized()
		var speed := pushing.dot(into)
		if speed <= 0.0:
			continue
		var force := PUSH_FORCE * clampf(speed / WALK_SPEED, 0.0, 1.0)
		body.apply_impulse(into * force * delta, hit.get_position() - body.global_position)
```

- [ ] **Step 4: Update `Interactor`**

Replace `who-knows/src/avatar/interactor.gd` with:

```gdscript
class_name Interactor
extends RayCast3D

## Points where the avatar looks. Anything in group "interactable" that
## implements `interact(actor)` and `prompt_text()` can be used. One that also
## implements `can_interact(actor)` is passed over while that returns false --
## an item, while your hands are full (hands-and-items spec §7.2). Whatever the
## avatar holds is never reported: a carried crate sits right in front of the
## eye.

signal prompt_changed(text: String)

## interior_geometry | items (project.godot 3d_physics layers 2 and 6).
## RayCast3D defaults to mask 1 (exterior_hull) and would find nothing here.
const MASK := 2 | 32

var _current: Node = null
var _ignored: CollisionObject3D = null

func _ready() -> void:
	target_position = Vector3(0, 0, -2.5)
	collide_with_areas = true
	collision_mask = MASK

## What the ray is on and could use right now, or null.
func current() -> Node:
	return _current

func _physics_process(_delta: float) -> void:
	_ignore_held()
	var hit: Node = get_collider() if is_colliding() else null
	if hit != null and not hit.is_in_group("interactable"):
		hit = null
	if hit != null and hit.has_method(&"can_interact") and not hit.can_interact(owner):
		hit = null
	if hit != _current:
		_current = hit
		prompt_changed.emit("" if _current == null else "[F] %s" % _current.prompt_text())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current != null:
		_current.interact(owner)

func _ignore_held() -> void:
	var held: CollisionObject3D = null
	if owner != null and "grasp" in owner and owner.grasp != null:
		held = owner.grasp.item
	if held == _ignored:
		return
	if is_instance_valid(_ignored):
		remove_exception(_ignored)
	_ignored = held
	if held != null:
		add_exception(held)
```

- [ ] **Step 5: Run** `-gselect=test_avatar`, `-gselect=test_interactor`, full suite. Expected PASS.

- [ ] **Step 6: Commit** — `feat: the avatar takes, carries and nudges items`

---

### Task 8: Scene wiring, the reticle and view changes

**Files:**
- Create: `who-knows/src/ui/reticle.gd`
- Modify: `who-knows/src/camera/camera_director.gd`, `who-knows/scenes/flight_test.gd`
- Test: `who-knows/test/unit/test_hud_scene_wiring.gd`

**Interfaces:**
- Consumes: `Avatar.grasp`, `Ship.items`, `Grasp.prompt_changed`.
- Produces: `CameraDirector.view_changed(view: View, moving: bool)`; `Reticle` (Control); flight_test's `_on_view_changed(view, moving)`.

- [ ] **Step 1: Write the failing tests** — append to `who-knows/test/unit/test_hud_scene_wiring.gd`:

```gdscript
func test_released_items_go_back_aboard_the_ship():
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var ship: Ship = _root.get_node("Ship")
	assert_eq(avatar.grasp.world_root, ship.items)

func test_the_reticle_shows_on_foot():
	var reticle := _root.get_node_or_null("Prompt/Reticle")
	assert_not_null(reticle)
	assert_true(reticle is Reticle)
	assert_true(reticle.visible)

func test_third_person_hides_the_reticle_and_refuses_use():
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	director.cycle_view()
	assert_false(_root.get_node("Prompt/Reticle").visible)
	assert_false(avatar.grasp.first_person)
	director.cycle_view()
	assert_true(_root.get_node("Prompt/Reticle").visible)
	assert_true(avatar.grasp.first_person)

func test_sitting_down_hides_the_reticle_at_once():
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_false(_root.get_node("Prompt/Reticle").visible)

func test_a_stow_prompt_wins_over_the_interact_prompt():
	var interactor: Interactor = _root.get_node("Ship/Interior/Avatar/Head/Interactor")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var label: Label = _root.get_node("Prompt/Label")
	interactor.prompt_changed.emit("[F] Take the controls")
	avatar.grasp.prompt_changed.emit(Grasp.STOW_PROMPT)
	assert_eq(label.text, Grasp.STOW_PROMPT)
	avatar.grasp.prompt_changed.emit("")
	assert_eq(label.text, "[F] Take the controls")
```

- [ ] **Step 2: Run to see them fail** — `-gselect=test_hud_scene_wiring`: FAIL.

- [ ] **Step 3: Announce view changes from `CameraDirector`**

After `signal piloting_changed(piloting: bool)` add:

```gdscript

## Emitted when the view changes, and when a sit or stand camera move starts
## (`moving` true) -- the hands and the reticle hide for the move.
signal view_changed(view: View, moving: bool)
```

At the start of `_move_camera_to()` add `view_changed.emit(view, true)`. At the end of `_apply_view()` add `view_changed.emit(view, false)`.

- [ ] **Step 4: Write `Reticle`**

`who-knows/src/ui/reticle.gd`:

```gdscript
class_name Reticle
extends Control

## The centre dot you aim and pick things up with (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §10). Knows nothing about avatars; the
## bootstrap shows it on foot in first person.

const RADIUS := 2.5
const OUTLINE := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var centre := size * 0.5
	draw_circle(centre, RADIUS + OUTLINE, HudPalette.BACKDROP)
	draw_circle(centre, RADIUS, HudPalette.READOUT)
```

- [ ] **Step 5: Wire it in `flight_test.gd`**

Add after the `_interactor` onready:

```gdscript
@onready var _avatar: Avatar = $Ship/Interior/Avatar

var _reticle: Reticle
var _interact_prompt := ""
var _grasp_prompt := ""
```

In `_ready()`, after `_wire_prompt()` add `_wire_hands()`. Replace `_wire_prompt()` with:

```gdscript
## Shows what the avatar is looking at, or -- while you hold something that a
## drop would stow -- the stow prompt, which wins.
func _wire_prompt() -> void:
	_prompt.text = ""
	_interactor.prompt_changed.connect(
		func(text: String) -> void:
			_interact_prompt = text
			_show_prompt()
	)
	_avatar.grasp.prompt_changed.connect(
		func(text: String) -> void:
			_grasp_prompt = text
			_show_prompt()
	)
	# The prompt belongs to the avatar, not the pilot. Sitting down hands the
	# view to the seat, so anything the raycast still reports is stale.
	_director.piloting_changed.connect(
		func(piloting: bool) -> void:
			if piloting:
				_interact_prompt = ""
				_grasp_prompt = ""
				_show_prompt()
	)

func _show_prompt() -> void:
	_prompt.text = _grasp_prompt if _grasp_prompt != "" else _interact_prompt

## Hands and items (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §7, §8, §10): what you let go of lands aboard this ship, and the reticle and
## hands follow the view. Wired here so src/avatar and src/ui never learn about
## CameraDirector or Ship.
func _wire_hands() -> void:
	_avatar.grasp.world_root = _ship.items
	_reticle = Reticle.new()
	_reticle.name = "Reticle"
	$Prompt.add_child(_reticle)
	_director.view_changed.connect(_on_view_changed)
	_on_view_changed(_director.view, false)

func _on_view_changed(view: CameraDirector.View, moving: bool) -> void:
	var first_person := view == CameraDirector.View.FOOT_FIRST
	_avatar.grasp.first_person = first_person
	_reticle.visible = first_person and not moving
```

- [ ] **Step 6: Run** `-gselect=test_hud_scene_wiring`, full suite. Expected PASS.

- [ ] **Step 7: Commit** — `feat: wire the grasp, prompt and reticle into the flight scene`

---

# Phase C — hands

### Task 9: Hand poses and the glove

**Files:**
- Create: `who-knows/src/avatar/hand_pose.gd`, `who-knows/src/avatar/glove.gd`
- Modify: `who-knows/test/unit/test_visual_style_rules.gd` (`glove.gd` joins both lists)
- Test: `who-knows/test/unit/test_hand_pose.gd`

**Interfaces:**
- Produces: `HandPose` (`curl: PackedFloat32Array` ×4, `thumb`, `spread`, `wrist: Transform3D`, `static make(curls, thumb, spread, wrist)`, `static blend(a, b, t)`, `mirrored()`, presets `relaxed()`, `reach()`, `carry(width, depth)`, `grip(trigger: bool)`, `WIELD_SOCKET`, `PALM`); `Glove` (`_init(side := 1.0)`, `side`, `apply(pose)`, `joint_count() -> int`).

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_hand_pose.gd`:

```gdscript
extends GutTest

## Hand poses and the glove (hands-and-items spec §8.2, §8.3).

func test_blend_is_exact_at_the_ends():
	var a := HandPose.relaxed()
	var b := HandPose.grip(true)
	var start := HandPose.blend(a, b, 0.0)
	var end := HandPose.blend(a, b, 1.0)
	assert_eq(start.curl, a.curl)
	assert_eq(end.curl, b.curl)
	assert_true(start.wrist.is_equal_approx(a.wrist))
	assert_true(end.wrist.is_equal_approx(b.wrist))

func test_blend_is_linear_between():
	var a := HandPose.make([0, 0, 0, 0], 0.0, 0.0, Transform3D.IDENTITY)
	var b := HandPose.make([1, 1, 1, 1], 1.0, 1.0, Transform3D(Basis.IDENTITY, Vector3(0, 0, -1)))
	var mid := HandPose.blend(a, b, 0.5)
	assert_almost_eq(mid.curl[2], 0.5, 0.0001)
	assert_almost_eq(mid.thumb, 0.5, 0.0001)
	assert_almost_eq(mid.spread, 0.5, 0.0001)
	assert_almost_eq(mid.wrist.origin, Vector3(0, 0, -0.5), Vector3.ONE * 0.0001)

func test_mirroring_reflects_the_wrist_and_stays_a_rotation():
	var p := HandPose.relaxed()
	var m := p.mirrored()
	assert_almost_eq(m.wrist.origin, Vector3(-p.wrist.origin.x, p.wrist.origin.y, p.wrist.origin.z),
		Vector3.ONE * 0.0001)
	assert_almost_eq(m.wrist.basis.determinant(), 1.0, 0.0001)
	assert_true(m.mirrored().wrist.is_equal_approx(p.wrist))

func test_the_grip_puts_the_palm_on_the_socket():
	var pose := HandPose.grip(true)
	assert_almost_eq(pose.wrist * HandPose.PALM, HandPose.WIELD_SOCKET, Vector3.ONE * 0.0001)

func test_a_trigger_grip_leaves_the_index_finger_out():
	assert_lt(HandPose.grip(true).curl[0], HandPose.grip(false).curl[0])

func test_a_glove_has_ten_joints():
	var glove: Glove = autofree(Glove.new(1.0))
	assert_eq(glove.joint_count(), 10, "four two-joint fingers and a two-joint thumb")

func test_curling_bends_the_fingers_toward_the_palm():
	var glove := Glove.new(1.0)
	add_child_autofree(glove)
	glove.apply(HandPose.make([0, 0, 0, 0], 0.0, 0.0, Transform3D.IDENTITY))
	var tip_straight: Vector3 = glove.find_child("Joint1", true, false).global_position
	glove.apply(HandPose.make([1, 1, 1, 1], 0.0, 0.0, Transform3D.IDENTITY))
	var tip_curled: Vector3 = glove.find_child("Joint1", true, false).global_position
	assert_lt(tip_curled.y, tip_straight.y - 0.02, "palm side is -y")

func test_the_left_glove_mirrors_the_right():
	var right := Glove.new(1.0)
	var left := Glove.new(-1.0)
	add_child_autofree(right)
	add_child_autofree(left)
	var pose := HandPose.reach()
	right.apply(pose)
	left.apply(pose.mirrored())
	var r: Array = right.find_children("Joint*", "Node3D", true, false)
	var l: Array = left.find_children("Joint*", "Node3D", true, false)
	assert_eq(r.size(), l.size())
	for i in r.size():
		var a: Vector3 = r[i].global_position
		var b: Vector3 = l[i].global_position
		assert_almost_eq(b, Vector3(-a.x, a.y, a.z), Vector3.ONE * 0.0001)

func test_gloves_draw_on_the_interior_layer():
	var glove: Glove = autofree(Glove.new(1.0))
	var meshes := glove.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 10)
	for mi in meshes:
		assert_eq(mi.layers, 2)
```

- [ ] **Step 2: Run to see them fail** — FAIL, `HandPose` not declared.

- [ ] **Step 3: Write `HandPose`**

`who-knows/src/avatar/hand_pose.gd`:

```gdscript
class_name HandPose
extends RefCounted

## One glove's pose (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §8.3): how far each finger and the thumb curl, how far the fingers spread,
## and where the wrist is. Pure data; Glove applies it.
##
## Poses are written for the right hand in the Hands frame (the camera's: -z
## ahead, +x right, +y up). `mirrored()` gives the left. The presets are the
## starting point; they are tuned by rendering at eye height.

## Where the palm closes, glove-local: a wielded item's grip point goes here.
const PALM := Vector3(0.0, -0.025, -0.06)
## Where a wielded item's grip sits in the Hands frame.
const WIELD_SOCKET := Vector3(0.17, -0.2, -0.42)

const _MIRROR := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)), Vector3.ZERO)

## Index, middle, ring, little: 0 straight, 1 a fist.
var curl := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var thumb := 0.0
var spread := 0.0
## The glove in the Hands frame: origin at the wrist, fingers along -z, back
## of the hand +y.
var wrist := Transform3D.IDENTITY

static func make(curls: Array, thumb_curl: float, spread_amount: float, wrist_xf: Transform3D) -> HandPose:
	var p := HandPose.new()
	p.curl = PackedFloat32Array(curls)
	p.thumb = thumb_curl
	p.spread = spread_amount
	p.wrist = wrist_xf
	return p

static func blend(a: HandPose, b: HandPose, t: float) -> HandPose:
	var p := HandPose.new()
	for i in 4:
		p.curl[i] = lerpf(a.curl[i], b.curl[i], t)
	p.thumb = lerpf(a.thumb, b.thumb, t)
	p.spread = lerpf(a.spread, b.spread, t)
	p.wrist = a.wrist.interpolate_with(b.wrist, t)
	return p

## The same pose for the left hand: the wrist reflected through x = 0.
func mirrored() -> HandPose:
	return make(Array(curl), thumb, spread, _MIRROR * wrist * _MIRROR)

## Idle: fingers loosely curled, low in the corner, as in the reference.
static func relaxed() -> HandPose:
	return make([0.3, 0.35, 0.4, 0.45], 0.25, 0.25,
		Transform3D(Basis.from_euler(Vector3(0.25, 0.15, -0.35)), Vector3(0.2, -0.2, -0.38)))

## The Interactor is on something you can take: open and spread.
static func reach() -> HandPose:
	return make([0.05, 0.05, 0.08, 0.1], 0.05, 1.0,
		Transform3D(Basis.from_euler(Vector3(0.35, 0.1, -0.3)), Vector3(0.19, -0.17, -0.44)))

## Carrying something `width` wide and `depth` deep: at its side, palm in.
static func carry(width: float, depth: float) -> HandPose:
	var x := clampf(width * 0.5 + 0.03, 0.1, 0.25)
	return make([0.55, 0.55, 0.55, 0.55], 0.45, 0.25,
		Transform3D(Basis.from_euler(Vector3(0.1, 0.35, -1.35)), Vector3(x, -0.25, -(0.45 + depth * 0.5) + 0.05)))

## Wielding: closed round the grip, the index on the trigger if it has one.
## The wrist is placed so the palm lands on WIELD_SOCKET.
static func grip(trigger: bool) -> HandPose:
	var basis := Basis.from_euler(Vector3(0.0, 0.0, -1.35))
	return make([0.3 if trigger else 1.0, 1.0, 1.0, 1.0], 0.8, 0.0,
		Transform3D(basis, WIELD_SOCKET - basis * PALM))
```

- [ ] **Step 4: Write `Glove`**

`who-knows/src/avatar/glove.gd`:

```gdscript
class_name Glove
extends Node3D

## One suit glove (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §8.2), built from InteriorKit pieces in the house style: a sleeve and cuff,
## a palm with a padded back, four two-segment fingers and a two-segment
## thumb. Each segment hangs on its own pivot so it can curl. `side` is 1 for
## the right hand and -1 for the left, which is built mirrored.
##
## Glove-local frame: origin at the wrist, fingers along -z, back of the hand
## +y, palm -y.

const SOLID := InteriorKit.Batch.SOLID
## Runs InteriorKit's x-axis tubes along -z.
const _ALONG_Z := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))

const PALM_SIZE := Vector3(0.1, 0.035, 0.1)
## Finger positions across the knuckles, index first, for the right hand.
const FINGER_X: Array[float] = [-0.036, -0.012, 0.012, 0.036]
const FINGER_LENGTHS := [[0.046, 0.038], [0.05, 0.04], [0.046, 0.038], [0.036, 0.03]]
const FINGER_WIDTH := 0.021
const FINGER_THICK := 0.024
const THUMB_LENGTHS := [0.04, 0.034]
const THUMB_WIDTH := 0.026
## Radians each segment bends at full curl.
const CURL_MAX: Array[float] = [1.4, 1.5]
const THUMB_CURL_MAX: Array[float] = [0.9, 1.1]
## Radians between neighbouring fingers at full spread.
const SPREAD_MAX := 0.14

var side := 1.0

var _fingers: Array = []   # [[joint0, joint1], ...], index first
var _thumb: Array = []
var _thumb_rest := Basis.IDENTITY

func _init(side_sign := 1.0) -> void:
	side = side_sign
	name = "RightGlove" if side > 0.0 else "LeftGlove"
	_build()

func joint_count() -> int:
	return _fingers.size() * 2 + _thumb.size()

func apply(pose: HandPose) -> void:
	transform = pose.wrist
	for i in 4:
		var splay := (1.5 - i) * pose.spread * SPREAD_MAX * side
		var joints: Array = _fingers[i]
		(joints[0] as Node3D).basis = Basis(Vector3.UP, splay) * Basis(Vector3.RIGHT, -pose.curl[i] * CURL_MAX[0])
		(joints[1] as Node3D).basis = Basis(Vector3.RIGHT, -pose.curl[i] * CURL_MAX[1])
	(_thumb[0] as Node3D).basis = _thumb_rest * Basis(Vector3.RIGHT, -pose.thumb * THUMB_CURL_MAX[0])
	(_thumb[1] as Node3D).basis = Basis(Vector3.RIGHT, -pose.thumb * THUMB_CURL_MAX[1])

func _build() -> void:
	var suit := InteriorKit.solid(InteriorPalette.SUIT)
	var pad := InteriorKit.solid(InteriorPalette.SUIT_PAD)
	var hand := InteriorKit.new(self)
	hand.bevel_box(SOLID, InteriorKit.at(Vector3(0, 0, -0.05)), PALM_SIZE, 0.012, suit)
	hand.bevel_box(SOLID, InteriorKit.at(Vector3(0, 0.02, -0.055)), Vector3(0.082, 0.012, 0.07), 0.005, pad)
	# The cuff, a terracotta band, and a short sleeve running back toward the
	# eye, closed at both ends so you never see into it.
	hand.tube_x(SOLID, Transform3D(_ALONG_Z, Vector3(0, 0, 0.03)), 0.058, 0.06, suit)
	hand.tube_x(SOLID, Transform3D(_ALONG_Z, Vector3(0, 0, 0.045)), 0.06, 0.022, InteriorKit.solid(InteriorPalette.BELT))
	hand.tube_x(SOLID, Transform3D(_ALONG_Z, Vector3(0, 0, 0.13)), 0.052, 0.14, suit)
	hand.disc(SOLID, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.2)), 0.052, pad)
	hand.disc(SOLID, Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 0.0)), 0.058, suit)
	hand.commit()
	for i in 4:
		_fingers.append(_digit(Vector3(FINGER_X[i] * side, 0.0, -0.1), Basis.IDENTITY,
			FINGER_LENGTHS[i], FINGER_WIDTH, suit, pad))
	_thumb_rest = Basis(Vector3.UP, 0.7 * side) * Basis(Vector3.BACK, -0.5 * side)
	_thumb = _digit(Vector3(-0.048 * side, -0.006, -0.035), _thumb_rest, THUMB_LENGTHS, THUMB_WIDTH, suit, pad)

## A finger or thumb: a pivot per segment, each segment a padded block hanging
## off it along -z. Returns the pivots, knuckle first.
func _digit(at: Vector3, rest: Basis, lengths: Array, width: float, suit: Color, pad: Color) -> Array:
	var joints: Array = []
	var parent: Node3D = self
	var offset := at
	var basis := rest
	for s in lengths.size():
		var length: float = lengths[s]
		var joint := Node3D.new()
		joint.name = "Joint%d" % s
		joint.transform = Transform3D(basis, offset)
		parent.add_child(joint)
		var kit := InteriorKit.new(joint)
		kit.bevel_box(SOLID, InteriorKit.at(Vector3(0, 0, -length * 0.5)), Vector3(width, FINGER_THICK, length),
			0.007, suit)
		kit.bevel_box(SOLID, InteriorKit.at(Vector3(0, FINGER_THICK * 0.5, -length * 0.5)),
			Vector3(width * 0.8, 0.008, length * 0.6), 0.003, pad)
		kit.commit()
		joints.append(joint)
		parent = joint
		offset = Vector3(0, 0, -length)
		basis = Basis.IDENTITY
	return joints
```

- [ ] **Step 5: Add `glove.gd` to `PAINTING_FILES` and `REUSABLE_FILES`.**

- [ ] **Step 6: Import, run** `-gselect=test_hand_pose`, `-gselect=test_visual_style_rules`. Expected PASS.

- [ ] **Step 7: Commit** — `feat: add hand poses and a jointed suit glove`

---

### Task 10: The hands

**Files:**
- Create: `who-knows/src/avatar/hands.gd`
- Modify: `who-knows/src/avatar/avatar.gd` (creates Hands, binds Grasp to its socket), `who-knows/scenes/flight_test.gd` (`_on_view_changed` shows/hides hands), `who-knows/test/unit/test_visual_style_rules.gd` (`hands.gd` joins both lists)
- Test: `who-knows/test/unit/test_hands.gd`, `who-knows/test/unit/test_hud_scene_wiring.gd`

**Interfaces:**
- Consumes: `Glove`, `HandPose`, `Grasp`, `Avatar`, `Interactor.current()`, `Item`.
- Produces: `Hands` (`shown`, `wield_socket`, `right`, `left`, `bind(grasp, avatar)`, `target_poses() -> Array[HandPose]` (right, left), `tuck_amount() -> float`, `recoil`); `Avatar.hands: Hands`.

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_hands.gd`:

```gdscript
extends GutTest

## The first-person hands (hands-and-items spec §8): worn under the avatar's
## camera, posed from Grasp, tucked away from walls, kicked by recoil.

var _world: Node3D
var _avatar: Avatar

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_avatar = load("res://scenes/avatar.tscn").instantiate()
	_world.add_child(_avatar)
	_avatar.grasp.world_root = _world
	_avatar.set_physics_process(false)

func _item(grip: ItemDefinition.Grip, use: Script = null) -> Item:
	var d := ItemDefinition.new()
	d.id = &"thing"
	d.display_name = "Thing"
	d.size = Vector3(0.3, 0.2, 0.2)
	d.grip = grip
	d.look = &"crate"
	d.use = use
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = Vector3(0, 1.3, -1)
	item.set_loose()
	return item

func test_the_avatar_wears_hands_under_its_camera():
	assert_not_null(_avatar.hands)
	assert_eq(_avatar.hands.get_parent(), _avatar.camera)

func test_wielded_things_go_into_the_hands():
	assert_eq(_avatar.grasp.wield_socket, _avatar.hands.wield_socket)

func test_hiding_the_hands_hides_what_they_hold():
	var item := _item(ItemDefinition.Grip.WIELD)
	_avatar.take_item(item)
	_avatar.hands.shown = false
	assert_false(item.is_visible_in_tree())
	_avatar.hands.shown = true
	assert_true(item.is_visible_in_tree())

func test_empty_hands_relax():
	assert_eq(_avatar.hands.target_poses()[0].curl, HandPose.relaxed().curl)

func test_a_trigger_grip_for_a_usable_item():
	_avatar.take_item(_item(ItemDefinition.Grip.WIELD, load("res://src/items/item_use.gd")))
	assert_eq(_avatar.hands.target_poses()[0].curl, HandPose.grip(true).curl)

func test_a_full_grip_for_a_plain_one():
	_avatar.take_item(_item(ItemDefinition.Grip.WIELD))
	assert_eq(_avatar.hands.target_poses()[0].curl, HandPose.grip(false).curl)

func test_both_hands_carry():
	_avatar.take_item(_item(ItemDefinition.Grip.CARRY))
	var poses := _avatar.hands.target_poses()
	assert_eq(poses[0].curl, HandPose.carry(0.3, 0.2).curl)
	assert_almost_eq(poses[1].wrist.origin.x, -poses[0].wrist.origin.x, 0.0001, "the left mirrors the right")

func test_tuck_retracts_in_front_of_a_wall_and_not_in_open_space():
	await wait_physics_frames(2)
	assert_eq(_avatar.hands.tuck_amount(), 0.0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.global_position = _avatar.camera.global_position + Vector3(0, 0, -0.4)
	await wait_physics_frames(2)
	assert_gt(_avatar.hands.tuck_amount(), 0.5)

func test_a_shot_kicks_the_right_hand_back():
	var item := _item(ItemDefinition.Grip.WIELD)
	_avatar.take_item(item)
	_avatar.grasp.used.emit(item)
	assert_eq(_avatar.hands.recoil, 1.0)
	await wait_process_frames(2)
	assert_gt(_avatar.hands.get_node("Root/RightMount").position.z, 0.0)
```

Append to `who-knows/test/unit/test_hud_scene_wiring.gd`:

```gdscript
func test_third_person_hides_the_hands():
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	assert_true(avatar.hands.shown)
	director.cycle_view()
	assert_false(avatar.hands.shown)

func test_sitting_down_hides_the_hands():
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_false(avatar.hands.shown)
```

- [ ] **Step 2: Run to see them fail** — FAIL, `hands` not found.

- [ ] **Step 3: Write `Hands`**

`who-knows/src/avatar/hands.gd`:

```gdscript
class_name Hands
extends Node3D

## The first-person hands (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §8): two suit gloves under the camera,
## posed from what Grasp holds, swaying with the look, bobbing with the walk,
## drifting with the ship's shove, kicked by recoil and tucked away from any
## wall close enough to swallow them. Visuals only: reads Grasp and the avatar
## and never changes either.
##
## A wielded item hangs in `wield_socket`, so it moves -- and hides -- with the
## hands.

const POSE_RATE := 12.0
const SWAY_GAIN := 0.6
const SWAY_RETURN := 8.0
const SWAY_MAX := deg_to_rad(3.0)
## Radians of bob phase per metre walked.
const BOB_RATE := 5.0
const BOB_SIDE := 0.005
const BOB_DROP := 0.008
const SHOVE_GAIN := 0.005
const SHOVE_MAX := 0.04
const TUCK_REACH := 0.75
const TUCK_SPAN := 0.4
const TUCK_BACK := 0.25
const TUCK_DOWN := 0.1
const RECOIL_BACK := 0.04
const RECOIL_TILT := deg_to_rad(6.0)
const RECOIL_TIME := 0.15
## interior_geometry | items.
const RAY_MASK := 2 | 32

var shown := true: set = set_shown
var wield_socket: Node3D
var right: Glove
var left: Glove
## 1 just after a shot, easing to 0.
var recoil := 0.0

var _root: Node3D
var _right_mount: Node3D
var _grasp: Grasp
var _avatar: Avatar
var _pose_r: HandPose
var _pose_l: HandPose
var _sway := Vector2.ZERO
var _last_look := Vector2.ZERO
var _bob_phase := 0.0

func _init() -> void:
	name = "Hands"
	_root = Node3D.new()
	_root.name = "Root"
	add_child(_root)
	_right_mount = Node3D.new()
	_right_mount.name = "RightMount"
	_root.add_child(_right_mount)
	right = Glove.new(1.0)
	_right_mount.add_child(right)
	left = Glove.new(-1.0)
	_root.add_child(left)
	wield_socket = Node3D.new()
	wield_socket.name = "WieldSocket"
	wield_socket.position = HandPose.WIELD_SOCKET
	_right_mount.add_child(wield_socket)
	_pose_r = HandPose.relaxed()
	_pose_l = _pose_r.mirrored()
	right.apply(_pose_r)
	left.apply(_pose_l)

func bind(grasp: Grasp, avatar: Avatar) -> void:
	_grasp = grasp
	_avatar = avatar
	grasp.used.connect(func(_item: Item) -> void: recoil = 1.0)
	_last_look = _look()

func set_shown(on: bool) -> void:
	shown = on
	visible = on

## The poses the hands are heading for: right, then left.
func target_poses() -> Array[HandPose]:
	var r := HandPose.relaxed()
	var l := HandPose.relaxed()
	if _grasp != null:
		match _grasp.mode:
			Grasp.Mode.WIELDING:
				r = HandPose.grip(_grasp.item.use_node != null)
			Grasp.Mode.CARRYING:
				var size := _grasp.item.definition.size
				r = HandPose.carry(size.x, size.z)
				l = r
			_:
				if _reaching():
					r = HandPose.reach()
					l = r
	return [r, l.mirrored()]

## 0 in open space, rising to 1 as a wall comes within reach of the eye.
func tuck_amount() -> float:
	if not is_inside_tree():
		return 0.0
	var from := global_position
	var to := from - global_basis.z * TUCK_REACH
	var query := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, _exclude())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return clampf((TUCK_REACH - from.distance_to(hit["position"])) / TUCK_SPAN, 0.0, 1.0)

func _process(delta: float) -> void:
	var targets := target_poses()
	var t := 1.0 - exp(-POSE_RATE * delta)
	_pose_r = HandPose.blend(_pose_r, targets[0], t)
	_pose_l = HandPose.blend(_pose_l, targets[1], t)
	right.apply(_pose_r)
	left.apply(_pose_l)
	_root.transform = _root_motion(delta)
	_right_mount.transform = _mount_motion(delta)

func _root_motion(delta: float) -> Transform3D:
	var look := _look()
	var turn := Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y)
	_last_look = look
	_sway = (_sway - turn * SWAY_GAIN).lerp(Vector2.ZERO, 1.0 - exp(-SWAY_RETURN * delta))
	_sway = _sway.clamp(Vector2(-SWAY_MAX, -SWAY_MAX), Vector2(SWAY_MAX, SWAY_MAX))
	var offset := _bob(delta) + _shove()
	var carrying := _grasp != null and _grasp.mode == Grasp.Mode.CARRYING
	if carrying:
		offset.z += Grasp.WIND_BACK * maxf(_grasp.charge, 0.0)
	else:
		var tuck := tuck_amount()
		offset += Vector3(0.0, -TUCK_DOWN * tuck, TUCK_BACK * tuck)
	return Transform3D(Basis.from_euler(Vector3(_sway.y, _sway.x, 0.0)), offset)

## Recoil and the wind-up act on the right hand only, pivoting about the grip
## so the muzzle rises.
func _mount_motion(delta: float) -> Transform3D:
	recoil = move_toward(recoil, 0.0, delta / RECOIL_TIME)
	var back := RECOIL_BACK * recoil
	if _grasp != null and _grasp.mode == Grasp.Mode.WIELDING:
		back += Grasp.WIND_BACK * maxf(_grasp.charge, 0.0)
	var pivot := HandPose.WIELD_SOCKET
	return Transform3D(Basis.IDENTITY, pivot + Vector3(0.0, 0.0, back)) \
		* Transform3D(Basis(Vector3.RIGHT, RECOIL_TILT * recoil), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)

func _look() -> Vector2:
	if _avatar == null:
		return Vector2.ZERO
	return Vector2(_avatar.rotation.y, _avatar.head.rotation.x)

func _bob(delta: float) -> Vector3:
	if _avatar == null:
		return Vector3.ZERO
	var v := _avatar.velocity
	v.y = 0.0
	var speed := v.length()
	_bob_phase += speed * delta * BOB_RATE
	var amount := clampf(speed / Avatar.WALK_SPEED, 0.0, 1.0)
	return Vector3(sin(_bob_phase) * BOB_SIDE, -absf(cos(_bob_phase)) * BOB_DROP, 0.0) * amount

func _shove() -> Vector3:
	if _avatar == null or not is_inside_tree():
		return Vector3.ZERO
	return (global_basis.inverse() * _avatar.external_accel * SHOVE_GAIN).limit_length(SHOVE_MAX)

func _reaching() -> bool:
	return _avatar != null and _avatar.interactor != null and _avatar.interactor.current() is Item

func _exclude() -> Array[RID]:
	var out: Array[RID] = []
	if _avatar != null:
		out.append(_avatar.get_rid())
	if _grasp != null and _grasp.item != null:
		out.append(_grasp.item.get_rid())
	return out
```

- [ ] **Step 4: The avatar wears them**

In `Avatar`, add `var hands: Hands` after `var grasp: Grasp`, and in `_ready()` replace the Grasp lines with:

```gdscript
	grasp = Grasp.new()
	grasp.name = "Grasp"
	add_child(grasp)
	hands = Hands.new()
	camera.add_child(hands)
	grasp.bind(self, head, hands.wield_socket)
	hands.bind(grasp, self)
```

In `flight_test.gd` `_on_view_changed`, add `_avatar.hands.shown = first_person and not moving`.

- [ ] **Step 5: Add `hands.gd` to `PAINTING_FILES` and `REUSABLE_FILES`.**

- [ ] **Step 6: Import, run** `-gselect=test_hands`, `-gselect=test_hud_scene_wiring`, the full suite. Expected PASS.

- [ ] **Step 7: Commit** — `feat: see your hands -- posed, swaying, tucked and kicked`

---

# Phase D — the plasma pistol

### Task 11: Bolts, flashes and hits

**Files:**
- Create: `who-knows/src/items/hit.gd`, `who-knows/src/items/impact_flash.gd`, `who-knows/src/items/plasma_bolt.gd`
- Modify: `who-knows/test/unit/test_visual_style_rules.gd` (`impact_flash.gd`, `plasma_bolt.gd` join `PAINTING_FILES`)
- Test: `who-knows/test/unit/test_plasma_bolt.gd`

**Interfaces:**
- Produces: `Hit` (`position`, `normal`, `direction`, `impulse`, `source`, `static make(...)`); `ImpactFlash` (`enum Kind {MUZZLE, IMPACT}`, `static spawn(parent, at, normal, kind) -> ImpactFlash`); `PlasmaBolt` (`SPEED = 45.0`, `LIFETIME = 1.5`, `PUSH = 6.0`, `RAY_MASK = 34`, `signal struck(point: Vector3, collider: Object)`, `direction`, `exclude: Array[RID]`, `source`, `age`, `launch(from, dir)`, `impact(result: Dictionary)`).

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_plasma_bolt.gd`:

```gdscript
extends GutTest

## PlasmaBolt (hands-and-items spec §9.2, §9.3): a swept ray each tick, so it
## can never tunnel; a push and a flash where it lands.

class Target extends StaticBody3D:
	var hits: Array = []
	func receive_hit(hit: Hit) -> void:
		hits.append(hit)

var _world: Node3D

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)

func _slab(z: float, body: StaticBody3D = null) -> StaticBody3D:
	var slab := body if body != null else StaticBody3D.new()
	slab.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	slab.add_child(shape)
	_world.add_child(slab)
	slab.global_position = Vector3(0, 0, z)
	return slab

func _bolt(from: Vector3, dir := Vector3.FORWARD) -> PlasmaBolt:
	var bolt := PlasmaBolt.new()
	_world.add_child(bolt)
	bolt.launch(from, dir)
	return bolt

func test_a_bolt_cannot_tunnel_through_a_thin_wall():
	_slab(-3.0)
	await wait_physics_frames(2)
	for start in [0.0, 0.2, 0.37, 0.55, 0.71]:
		var hits: Array = []
		var bolt := _bolt(Vector3(0, 0, -start))
		bolt.struck.connect(func(point: Vector3, _c: Object) -> void: hits.append(point))
		await wait_physics_frames(10)
		assert_eq(hits.size(), 1, "starting %.2f m in, it struck" % start)
		if hits.size() == 1:
			assert_almost_eq(hits[0].z, -2.95, 0.01, "on the near face")

func test_a_bolt_ignores_its_shooter():
	var shooter := _slab(-1.0)
	_slab(-3.0)
	await wait_physics_frames(2)
	var hits: Array = []
	var bolt := _bolt(Vector3.ZERO)
	bolt.exclude = [shooter.get_rid()]
	bolt.struck.connect(func(point: Vector3, _c: Object) -> void: hits.append(point))
	await wait_physics_frames(10)
	assert_eq(hits.size(), 1)
	assert_almost_eq(hits[0].z, -2.95, 0.01)

func _loose(at: Vector3, mass := 1.0) -> Item:
	var d := ItemDefinition.new()
	d.id = &"mug"
	d.display_name = "Mug"
	d.mass_kg = mass
	d.size = Vector3(0.3, 0.3, 0.3)
	d.look = &"mug"
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = at
	item.set_loose()
	return item

func test_a_bolt_pushes_what_it_hits():
	var item := _loose(Vector3(0, 0, -2))
	await wait_physics_frames(2)
	_bolt(Vector3.ZERO)
	await wait_physics_frames(6)
	assert_almost_eq(item.linear_velocity.z, -PlasmaBolt.PUSH / item.mass, 0.5)

func test_a_stowed_item_stays_put():
	var item := _loose(Vector3(0, 0, -2))
	item.set_stowed(null)
	await wait_physics_frames(2)
	_bolt(Vector3.ZERO)
	await wait_physics_frames(6)
	assert_almost_eq(item.global_position, Vector3(0, 0, -2), Vector3.ONE * 0.0001)

func test_receive_hit_is_called_with_the_hit():
	var target := _slab(-2.0, Target.new()) as Target
	await wait_physics_frames(2)
	_bolt(Vector3.ZERO)
	await wait_physics_frames(6)
	assert_eq(target.hits.size(), 1)
	var hit: Hit = target.hits[0]
	assert_almost_eq(hit.position.z, -1.95, 0.01)
	assert_almost_eq(hit.normal, Vector3.BACK, Vector3.ONE * 0.001)
	assert_almost_eq(hit.impulse, Vector3.FORWARD * PlasmaBolt.PUSH, Vector3.ONE * 0.001)

func test_a_bolt_expires():
	var bolt := _bolt(Vector3.ZERO)
	bolt.age = PlasmaBolt.LIFETIME - 0.01
	await wait_physics_frames(3)
	assert_false(is_instance_valid(bolt))

func test_an_impact_leaves_a_flash_that_frees_itself():
	_slab(-2.0)
	await wait_physics_frames(2)
	_bolt(Vector3.ZERO)
	await wait_physics_frames(6)
	var flashes := _world.get_children().filter(func(n): return n is ImpactFlash)
	assert_eq(flashes.size(), 1)
	await wait_seconds(0.3)
	assert_eq(_world.get_children().filter(func(n): return n is ImpactFlash).size(), 0)

func test_bolts_light_warm_on_the_interior_layer():
	var bolt := _bolt(Vector3.ZERO)
	var lights := bolt.find_children("*", "OmniLight3D", true, false)
	assert_eq(lights.size(), 1)
	var light: OmniLight3D = lights[0]
	assert_eq(light.light_color, InteriorPalette.LIGHT_WARM)
	assert_eq(light.light_cull_mask, 2)
	assert_false(light.shadow_enabled)
	for mi in bolt.find_children("*", "MeshInstance3D", true, false):
		assert_eq(mi.layers, 2)
```

- [ ] **Step 2: Run to see them fail** — FAIL, `PlasmaBolt` not declared.

- [ ] **Step 3: Write `Hit`**

`who-knows/src/items/hit.gd`:

```gdscript
class_name Hit
extends RefCounted

## What a hit carries to whatever it lands on (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §9.3): anything with
## receive_hit(hit: Hit) is told. Nothing takes damage yet; Slice 2's damage
## reads this.

var position: Vector3
var normal: Vector3
var direction: Vector3
## Newton-seconds.
var impulse: Vector3
var source: Node

static func make(at: Vector3, surface_normal: Vector3, dir: Vector3, push: Vector3, from: Node) -> Hit:
	var hit := Hit.new()
	hit.position = at
	hit.normal = surface_normal
	hit.direction = dir
	hit.impulse = push
	hit.source = from
	return hit
```

- [ ] **Step 4: Write `ImpactFlash`**

`who-knows/src/items/impact_flash.gd`:

```gdscript
class_name ImpactFlash
extends Node3D

## A short burst of plasma light (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §9): at the muzzle when the pistol
## fires, and where a bolt lands. It grows and shrinks to nothing -- by scale,
## so the shared glow material is never touched -- with a warm light fading
## beside it, then frees itself.

enum Kind { MUZZLE, IMPACT }

const DURATION := {Kind.MUZZLE: 0.05, Kind.IMPACT: 0.15}
const SIZE := {Kind.MUZZLE: 0.08, Kind.IMPACT: 0.3}
const LIGHT_ENERGY := 0.8
const LIGHT_RANGE := 3.0

static var _mesh: Mesh

var kind: Kind = Kind.IMPACT
var _age := 0.0
var _burst: MeshInstance3D
var _light: OmniLight3D

static func spawn(parent: Node, at: Vector3, normal: Vector3, flash_kind: Kind) -> ImpactFlash:
	var flash := ImpactFlash.new()
	flash.kind = flash_kind
	parent.add_child(flash)
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	flash.global_transform = Transform3D(Basis.looking_at(-normal, up), at + normal * 0.01)
	return flash

func _ready() -> void:
	_burst = MeshInstance3D.new()
	_burst.mesh = _shared_mesh()
	_burst.material_override = InteriorMaterials.glow()
	_burst.layers = InteriorKit.LAYER
	_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_burst.scale = Vector3.ONE * 0.001
	add_child(_burst)
	_light = OmniLight3D.new()
	_light.light_color = InteriorPalette.LIGHT_WARM
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = LIGHT_RANGE
	_light.light_cull_mask = InteriorKit.LAYER
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	_age += delta
	var t: float = _age / DURATION[kind]
	if t >= 1.0:
		queue_free()
		return
	_burst.scale = Vector3.ONE * maxf(sin(t * PI) * SIZE[kind], 0.001)
	_light.light_energy = LIGHT_ENERGY * (1.0 - t)

## A unit burst facing +z: a plasma disc with a hot core and a chunky centre.
static func _shared_mesh() -> Mesh:
	if _mesh == null:
		var holder := Node3D.new()
		var kit := InteriorKit.new(holder)
		kit.disc(InteriorKit.Batch.GLOW, Transform3D.IDENTITY, 1.0, InteriorKit.lit(InteriorPalette.PLASMA, 2.4))
		kit.disc(InteriorKit.Batch.GLOW, InteriorKit.at(Vector3(0, 0, 0.02)), 0.5,
			InteriorKit.lit(InteriorPalette.LIGHT_WARM, 2.4))
		kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D.IDENTITY, Vector3.ONE * 0.6, 0.1,
			InteriorKit.lit(InteriorPalette.PLASMA, 2.4))
		_mesh = kit.commit()[0].mesh
		holder.free()
	return _mesh
```

- [ ] **Step 5: Write `PlasmaBolt`**

`who-knows/src/items/plasma_bolt.gd`:

```gdscript
class_name PlasmaBolt
extends Node3D

## A plasma bolt (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §9.2, §9.3). Not a physics body: each tick it casts a ray from where it is
## to where it will be, so it cannot pass through a 0.1 m wall at any speed.
## Where it lands it pushes whatever is loose, tells anything that listens
## (receive_hit), flashes, and is gone.

signal struck(point: Vector3, collider: Object)

const SPEED := 45.0
const LIFETIME := 1.5
## Newton-seconds given to whatever it hits.
const PUSH := 6.0
## interior_geometry | items.
const RAY_MASK := 2 | 32
const LENGTH := 0.4
const THICKNESS := 0.06
const LIGHT_ENERGY := 0.4
const LIGHT_RANGE := 2.5

static var _mesh: Mesh

var direction := Vector3.FORWARD
var exclude: Array[RID] = []
var source: Node = null
var age := 0.0

var _spent := false

func launch(from: Vector3, dir: Vector3) -> void:
	direction = dir.normalized()
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(direction, up), from)

func _ready() -> void:
	var body := MeshInstance3D.new()
	body.mesh = _shared_mesh()
	body.material_override = InteriorMaterials.glow()
	body.layers = InteriorKit.LAYER
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var light := OmniLight3D.new()
	light.light_color = InteriorPalette.LIGHT_WARM
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.light_cull_mask = InteriorKit.LAYER
	light.shadow_enabled = false
	add_child(light)

func _physics_process(delta: float) -> void:
	if _spent:
		return
	age += delta
	if age >= LIFETIME:
		_spent = true
		queue_free()
		return
	var from := global_position
	var to := from + direction * SPEED * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, exclude)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = to
	else:
		impact(result)

## Lands: a push, the hook, a flash, and gone.
func impact(result: Dictionary) -> void:
	if _spent:
		return
	_spent = true
	var point: Vector3 = result["position"]
	var normal: Vector3 = result["normal"]
	var collider: Object = result.get("collider")
	var body := collider as RigidBody3D
	if body != null and not body.freeze:
		body.apply_impulse(direction * PUSH, point - body.global_position)
		body.sleeping = false
	if collider != null and collider.has_method(&"receive_hit"):
		collider.receive_hit(Hit.make(point, normal, direction, direction * PUSH, source))
	ImpactFlash.spawn(get_parent(), point, normal, ImpactFlash.Kind.IMPACT)
	struck.emit(point, collider)
	queue_free()

## A stretched glowing capsule along -z, shared by every bolt.
static func _shared_mesh() -> Mesh:
	if _mesh == null:
		var holder := Node3D.new()
		var kit := InteriorKit.new(holder)
		kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D.IDENTITY, Vector3(THICKNESS, THICKNESS, LENGTH),
			THICKNESS * 0.4, InteriorKit.lit(InteriorPalette.PLASMA, 2.4))
		_mesh = kit.commit()[0].mesh
		holder.free()
	return _mesh
```

- [ ] **Step 6: Add `impact_flash.gd` and `plasma_bolt.gd` to `PAINTING_FILES`.**

- [ ] **Step 7: Import, run** `-gselect=test_plasma_bolt`, `-gselect=test_visual_style_rules`. Expected PASS.

- [ ] **Step 8: Commit** — `feat: add plasma bolts, impact flashes and the hit hook`

---

### Task 12: The plasma pistol fires

**Files:**
- Create: `who-knows/src/items/plasma_emitter.gd`
- Modify: `who-knows/data/items/plasma_pistol.tres` (`use`)
- Test: `who-knows/test/unit/test_plasma_emitter.gd`

**Interfaces:**
- Consumes: `ItemUse`, `PlasmaBolt`, `ImpactFlash`.
- Produces: `PlasmaEmitter` (`COOLDOWN = 0.25`, `AIM_RANGE = 100.0`, `MAX_BOLTS = 8`, `bolts() -> Array[PlasmaBolt]`, `cooldown_left() -> float`).

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_plasma_emitter.gd`:

```gdscript
extends GutTest

## The plasma pistol (hands-and-items spec §9.1): bolts leave the muzzle for
## wherever the eye is looking, at most four a second and eight in flight.

var _world: Node3D
var _pistol: Item

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_pistol = Item.new()
	_pistol.setup(ItemCatalog.load_from_dir().get_def(&"plasma_pistol"))
	_world.add_child(_pistol)
	_pistol.global_position = Vector3(0.2, -0.2, -0.4)
	_pistol.set_held(true)

func _slab(z: float) -> void:
	var slab := StaticBody3D.new()
	slab.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(40, 40, 0.1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	slab.add_child(shape)
	_world.add_child(slab)
	slab.global_position = Vector3(0, 0, z)

func _bolts() -> Array:
	return _world.get_children().filter(func(n): return n is PlasmaBolt and not n.is_queued_for_deletion())

func test_the_pistol_is_a_plasma_emitter():
	assert_true(_pistol.use_node is PlasmaEmitter)

func test_a_bolt_leaves_the_muzzle_for_where_you_look():
	_slab(-10.0)
	await wait_physics_frames(2)
	assert_true(_pistol.use(Transform3D.IDENTITY, _world, null))
	var bolts := _bolts()
	assert_eq(bolts.size(), 1)
	var bolt: PlasmaBolt = bolts[0]
	var muzzle := _pistol.global_transform * _pistol.definition.use_point
	assert_almost_eq(bolt.global_position, muzzle, Vector3.ONE * 0.0001)
	assert_almost_eq(bolt.direction, (Vector3(0, 0, -9.95) - muzzle).normalized(), Vector3.ONE * 0.001)

func test_firing_is_rate_limited():
	assert_true(_pistol.use(Transform3D.IDENTITY, _world, null))
	assert_false(_pistol.use(Transform3D.IDENTITY, _world, null), "cooling down")
	await wait_physics_frames(18)
	assert_true(_pistol.use(Transform3D.IDENTITY, _world, null))

func test_at_most_eight_bolts_fly():
	var emitter: PlasmaEmitter = _pistol.use_node
	for i in 10:
		emitter._cooldown = 0.0
		_pistol.use(Transform3D.IDENTITY, _world, null)
	assert_eq(emitter.bolts().size(), PlasmaEmitter.MAX_BOLTS)
	assert_eq(_bolts().size(), PlasmaEmitter.MAX_BOLTS)

func test_point_blank_strikes_at_once():
	_slab(-0.2)
	await wait_physics_frames(2)
	assert_true(_pistol.use(Transform3D.IDENTITY, _world, null))
	assert_eq(_bolts().size(), 0, "no bolt left flying")
	var flashes := _world.get_children().filter(func(n): return n is ImpactFlash)
	assert_gt(flashes.size(), 0)
	var impact: ImpactFlash = flashes.filter(func(f): return f.kind == ImpactFlash.Kind.IMPACT)[0]
	assert_almost_eq(impact.global_position.z, -0.14, 0.02)

func test_each_shot_flashes_at_the_muzzle():
	_pistol.use(Transform3D.IDENTITY, _world, null)
	var muzzles := _world.get_children().filter(
		func(n): return n is ImpactFlash and n.kind == ImpactFlash.Kind.MUZZLE)
	assert_eq(muzzles.size(), 1)
```

- [ ] **Step 2: Run to see them fail** — FAIL.

- [ ] **Step 3: Write `PlasmaEmitter`**

`who-knows/src/items/plasma_emitter.gd`:

```gdscript
class_name PlasmaEmitter
extends ItemUse

## The plasma pistol's use (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §9.1). A bolt leaves the muzzle but
## heads for wherever the eye's ray lands, so it hits what the reticle is on
## although the muzzle is off to one side. If something stands between the eye
## and the muzzle -- you are pressed against a wall -- the shot strikes it at
## once.

const COOLDOWN := 0.25
const AIM_RANGE := 100.0
const MAX_BOLTS := 8
## interior_geometry | items.
const RAY_MASK := 2 | 32

var _cooldown := 0.0
var _bolts: Array[PlasmaBolt] = []

func use(item: Item, aim: Transform3D, world: Node3D, holder: CollisionObject3D) -> bool:
	if _cooldown > 0.0 or world == null:
		return false
	_cooldown = COOLDOWN
	var exclude: Array[RID] = [item.get_rid()]
	if holder != null:
		exclude.append(holder.get_rid())
	var space := item.get_world_3d().direct_space_state
	var muzzle := item.global_transform * item.definition.use_point
	var bolt := PlasmaBolt.new()
	bolt.exclude = exclude
	bolt.source = holder
	world.add_child(bolt)
	var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(aim.origin, muzzle, RAY_MASK, exclude))
	if not blocked.is_empty():
		bolt.launch(aim.origin, muzzle - aim.origin)
		bolt.impact(blocked)
		return true
	var far := aim.origin - aim.basis.z * AIM_RANGE
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(aim.origin, far, RAY_MASK, exclude))
	var target: Vector3 = hit["position"] if not hit.is_empty() else far
	bolt.launch(muzzle, target - muzzle)
	_track(bolt)
	ImpactFlash.spawn(world, muzzle, bolt.direction, ImpactFlash.Kind.MUZZLE)
	return true

## The bolts this pistol has in flight, oldest first.
func bolts() -> Array[PlasmaBolt]:
	_bolts = _bolts.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion())
	return _bolts

func cooldown_left() -> float:
	return _cooldown

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

func _track(bolt: PlasmaBolt) -> void:
	var flying := bolts()
	while flying.size() >= MAX_BOLTS:
		var oldest: PlasmaBolt = flying.pop_front()
		oldest.get_parent().remove_child(oldest)
		oldest.free()
	flying.append(bolt)
```

- [ ] **Step 4: Give the pistol its use**

Replace `who-knows/data/items/plasma_pistol.tres` with:

```
[gd_resource type="Resource" script_class="ItemDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/items/item_definition.gd" id="1_def"]
[ext_resource type="Script" path="res://src/items/plasma_emitter.gd" id="2_use"]

[resource]
script = ExtResource("1_def")
id = &"plasma_pistol"
display_name = "Plasma pistol"
mass_kg = 1.4
size = Vector3(0.06, 0.16, 0.24)
grip = 0
stow_class = &"sidearm"
look = &"plasma_pistol"
use = ExtResource("2_use")
grip_point = Vector3(0, -0.03, 0.07)
use_point = Vector3(0, 0.045, -0.125)
```

Add to `test_item_catalog.gd`:

```gdscript
func test_the_pistol_fires_plasma():
	var def := _cat.get_def(&"plasma_pistol")
	assert_not_null(def.use, "the use survived the .tres parse")
	var use = autofree(def.use.new())
	assert_true(use is PlasmaEmitter)
```

- [ ] **Step 5: Import, run** `-gselect=test_plasma`, `-gselect=test_item_catalog`, full suite. Expected PASS.

- [ ] **Step 6: Commit** — `feat: the plasma pistol fires`

---

### Task 13: Documents, renders and the live check

**Files:**
- Modify: `docs/design/visual-style.md`, `docs/superpowers/specs/2026-08-21-who-knows-slice-1-design.md`, `docs/superpowers/specs/2026-09-23-planetfall-design.md`

- [ ] **Step 1: Amend the documents** (spec §17)

`docs/design/visual-style.md`:
- §3 conventions bullet, append: "Loose items are `RigidBody3D`s on physics layer 6 (`items`); their looks come from `ItemLooks`, which obeys the same reuse rule as props."
- §4, add after *A new room type*:

```markdown
**A new item** (docs/superpowers/specs/2026-09-23-hands-and-items-design.md):

1. Add a `.tres` in `data/items/` with its mass, size, grip, stow class and look.
2. Add a builder to `ItemLooks` that draws inside the item's box from kit primitives, with colours
   from `InteriorPalette`. Add its id to `ItemLooks.LOOKS`.
3. If it does something, give it a `use` script extending `ItemUse`.
4. If a prop should hold it, publish a spot from that prop and stock it in `InteriorDressing`.
5. Render it in a hand and on its stow point (§6) before calling it done.
```

- §5, first list: change "a colour literal appears in interior code other than `InteriorPalette`" to "…in interior, item or hand code other than `InteriorPalette`", and the second to "`interior_props.gd`, `interior_kit.gd`, `sliding_door.gd`, `item_looks.gd`, `item.gd`, `glove.gd` or `hands.gd` reference the grid, the layout, the builder or the dressing;".

Slice spec §2, after the Planetfall amendment block, add:

```markdown
> **Amended 2026-09-23:** `docs/superpowers/specs/2026-09-23-hands-and-items-design.md` pulls a
> sliver of Slice 3 forward: visible hands, items you pick up, carry, throw and stow, and a first
> handheld weapon, a plasma pistol whose bolts push loose objects. Damage stays in Slice 2.
```

Planetfall §4.2, after the layer table, add:

```markdown
> **Amended 2026-09-23 (hands and items):** layer 6 is `items`, loose and carried items
> (`docs/superpowers/specs/2026-09-23-hands-and-items-design.md` §3.2). The avatar on EVA must
> keep colliding with it: its EVA mask is layers 1, 4, 5 and 6.
```

Planetfall §10.5, after "Transfer back reverses every item.", add:

```markdown
> **Amended 2026-09-23 (hands and items):** a wielded item travels with the avatar because it
> hangs in the hands. A carried item must be moved with the same transform maths, and items switch
> from render layer 2 to layer 1 outside.
```

- [ ] **Step 2: Full suite and render smoke**

Run the full suite: pristine, all passing. Then run without `--headless`:
`& "<godot>" --path "D:\git\whoknows-hands\who-knows" --quit-after 120 "res://scenes/flight_test.tscn"`.
Expected: no `SHADER ERROR`, `SCRIPT ERROR` or `ERROR` lines.

- [ ] **Step 3: The live check**

Write a throwaway driver in the scratchpad (never committed) that loads `flight_test.tscn` in a real window at 1280 × 720 and, frame by frame:
1. saves a screenshot of idle hands in the corridor at eye height;
2. walks the avatar to the weapon room, faces the rack, saves a screenshot (reach pose, stocked cradles);
3. takes a pistol, saves a screenshot (grip pose);
4. takes it to the galley, drops it; takes a mug, drops it on the floor; takes the pistol again, fires at the mug; saves screenshots mid-flight and at impact, and logs the mug's velocity;
5. takes a crate from the closet, carries it into the corridor, saves a screenshot, throws it;
6. sits, burns hard for two seconds, stands; logs how far the loose crate and a stowed mug moved;
7. logs the frame rate with eight bolts in flight.

Look at every screenshot. Fix anything wrong (pose values, sizes, clipping, darkness, colours) in code and re-run until it reads right. Any change that is not pose or size tuning goes through its own failing test first.

- [ ] **Step 4: Send the renders to the owner** and commit the documents and any fixes.

```bash
git add docs who-knows
git commit -m "docs: record hands and items in the style guide, slice spec and Planetfall"
```
