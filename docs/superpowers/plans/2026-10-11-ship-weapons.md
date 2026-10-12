# Ship Weapons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ships carry QE-powered phaser turrets that turn and fire bursts of dodgeable amber bolts on their own at targets you mark; a heavy turret can be aimed by hand from a weapons station; bolts hurt ships, NPCs, you, loose items and base modules.

**Architecture:** Turrets are blocks. Each ship builds one `Turret` node per turret block on its hull and one `FireControl` node that keeps the orders and a priority list of target ids and hands each turret a target every 0.2 s. A turret leads its target (`WeaponAim`), turns at its slew rate within the half-sky its `SkyMap` says is clear of its own hull, and fires `PhaserBolt`s from a shared `BoltPool`. `PhaserBolt` and the pistol's `PlasmaBolt` share a `Bolt` base (the swept-ray flight and the `Hit`). Targets are any node in group `Weapons.TARGETS`. A `WeaponsJob` fills the weapons station's `SeatJob` slot with a gun camera on the heavy turret.

**Tech Stack:** Godot 4.5.1 GDScript, GUT 9.5.

**Spec:** `docs/superpowers/specs/2026-10-11-ship-weapons-design.md` (approved 2026-10-11).

## Global Constraints

- **Numbers live in `WeaponValues`** (spec §3.1): light turret 90°/s, bursts of 4 at 0.125 s, 1.5 s recharge, 600 m/s, 15 hp, 3 s life, 1.2 km range, 0.4° spread, 1 QE a bolt, 0.8 t, 200 hp, 0.1 MW; heavy 30°/s, one bolt, 3 s recharge, 450 m/s, 120 hp, 7 s life, 1.5 km alone and 3 km manned, 15 QE, 2.0 t, 400 hp, 0.3 MW. Never a literal elsewhere.
- **Fire control:** orders `HOLD`/`ENGAGE` (a ship starts in `HOLD`); a list of at most **3** ids; assigned every **0.2 s**; an entry gone for **2 s** running leaves; a turret fires within **1°** of its solution; no bolt below the low-power line.
- **The style guide is binding** (`docs/design/visual-style.md`): colours only from `HullPalette`, `InteriorPalette`, `SpacePalette` (and `HudPalette` on the HUD); no new shader; `TurretLook` builds from a kit and a frame alone. `test_visual_style_rules.gd` must stay green; add every new painting file to it.
- **Floating origin (CLAUDE.md):** every bolt joins `Universe.EXTERIOR_SPACE` when made and stays in it (pooled too); turrets live on the hull. `test_floating_origin_scene.gd` must stay green.
- **Every ship is usable** (CLAUDE.md): `test_ship_catalog.gd` must pass all three library ships with their weapons.
- **`.tres` files:** no `#` comment anywhere near a property or tag (CLAUDE.md). Read a new property back at runtime in a test.
- **Tests:** from `who-knows`, `./run_tests.ps1 '-gselect=<file>.gd'`; GUT exits 0 on a parse error, so read the summary (`All tests passed`, a test count). After a new `class_name`, run `godot --headless --path . --import` first. Run only the files that cover the change; the full suite (~17 min) is the owner's call at the end.
- **Godot:** `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe`, written `godot` below.
- **Worktree:** `D:\git\whoknows-weapons`, branch `weapons` (on `main` at `93543b3`). PowerShell: `Set-Location D:\git\whoknows-weapons` then plain `git`; never `git -C`.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit every new script's `.uid` with it.
- **Skills:** at the end (Task 20) `building-a-ship`, `designing-a-ship` and `building-an-npc` are updated in this branch (CLAUDE.md).

## Review Focus

1. **A turret with its target on the far side of its own ship:** it never fires through its own hull, however the sky map rounds. Task 7's `test_never_fires_through_its_own_hull`.
2. **The store crossing the low-power line mid-burst, or running dry:** the burst stops at once; nothing more fires until full power returns; no QE goes negative. Task 7's `test_a_burst_stops_at_the_low_power_line`.
3. **A listed target freed mid-fight (an NPC killed, an item broken, a ship removed):** no error from a freed node; the turrets take the next entry; the entry leaves after 2 s. Task 6's `test_a_freed_target_is_dropped_without_error`.
4. **A save with targets listed, loaded:** ships and bases stay listed, an item does not, the orders come back. Task 8's `test_the_list_survives_a_save`.
5. **The floating origin shifting while bolts and trails are in flight:** every bolt moves with it, none is left uncovered. Task 8's `test_bolts_shift_with_the_origin`.

---

## File map

| File | Task | What |
|---|---|---|
| `who-knows/src/combat/weapon_values.gd` (new) | 1 | every number |
| `who-knows/src/combat/weapon_aim.gd` (new) | 1 | the intercept |
| `who-knows/src/combat/sky_map.gd` (new) | 2 | the clear half-sky, mount frames, mount normals |
| `who-knows/src/combat/bolt.gd` (new); `src/items/plasma_bolt.gd`; `src/items/impact_flash.gd` | 3 | the shared bolt; the pistol's on it; bigger flashes |
| `who-knows/src/combat/phaser_bolt.gd`, `bolt_pool.gd` (new); `src/world/space_palette.gd` | 3 | the turret bolt, the pool, `PHASER` |
| `who-knows/data/blocks/turret_light.tres`, `turret_heavy.tres` (new); `src/ship/ship_plan.gd`; `src/ship/ship_damage.gd` | 4 | the blocks, tokens, turret components |
| `who-knows/src/combat/weapons.gd` (new); `src/sensors/target_contacts.gd` (new); `src/ship/ship.gd`; `src/habitat/base.gd`; `src/npc/npc_director.gd`; `src/items/item.gd` | 5 | targets |
| `who-knows/src/combat/fire_control.gd` (new) | 6 | orders, list, assignment |
| `who-knows/src/combat/turret.gd`, `turret_look.gd` (new); `src/audio/synth.gd`; `src/ship/ship.gd` | 7 | the turret, its look and sound, on the ship |
| `who-knows/project.godot`; `src/flight/pilot_controls.gd`; `src/flight/flight_computer.gd`; `src/ui/vehicle_telemetry.gd`; `src/ui/hud_palette.gd`; `src/ui/weapons_strip.gd`, `target_brackets.gd` (new); `scenes/flight_test.gd` | 8 | the helm keys, the HUD, the scene |
| `who-knows/src/ship/ship_rules.gd` | 9 | `TURRET_BURIED`, `TURRET_BLIND` |
| `who-knows/data/ships/starter.json`, `starter.md` | 10 | the starter armed |
| `who-knows/src/items/item.gd`, `item_definition.gd`; `data/items/*.tres` | 11 | items break |
| `who-knows/src/habitat/module_damage.gd` (new); `base.gd`, `base_site.gd`, `base_exterior.gd`, `link_panel.gd` | 12 | base modules hurt and stop |
| `who-knows/src/items/repair_torch.gd` | 13 | the torch mends a module |
| `who-knows/data/blocks/weapons_station.tres` (new); `src/ship/interior/interior_layout.gd`, `interior_props.gd`, `interior_dressing.gd`; `src/avatar/weapons_station_seat.gd` (new); `src/ship/ship.gd`; `src/ship/ship_rules.gd` | 14 | the station |
| `who-knows/src/avatar/seat_job.gd`; `src/camera/camera_director.gd`; `src/flight/flight_computer.gd` | 15 | a job's camera and mouse; the gunner's hold |
| `who-knows/src/combat/weapons_job.gd` (new); `src/ui/gun_sight.gd` (new) | 16 | manning the heavy turret |
| `who-knows/src/ship/computer/weapons_page.gd` (new); `computer_context.gd`; `ship_computer.gd` | 17 | the board |
| `who-knows/data/ships/warden.*`, `lamplighter.*` | 18 | the Warden and the Lamplighter armed |
| `who-knows/test/probes/combat_probe.gd` (new); `.claude/skills/building-a-ship/ship_probe.gd` | 19 | proof, tuning, renders |
| skills, spec | 20 | docs |

---

## Phase 1: bolts, targets, fire control, the light turret

### Task 1: `WeaponValues` and `WeaponAim`

**Files:**
- Create: `who-knows/src/combat/weapon_values.gd`, `who-knows/src/combat/weapon_aim.gd`
- Test: `who-knows/test/unit/test_weapon_aim.gd`

**Interfaces:**
- Produces: `WeaponValues.LIGHT`, `.HEAVY`, `.TURRET_IDS: Array[StringName]`, `.STATION`, `.spec(kind) -> Dictionary` (keys `slew`, `burst`, `gap`, `recharge`, `speed`, `damage`, `life`, `push`, `range`, `manned_range`, `spread`, `qe`, `length`, `thickness`, `flash`, `barrel`), and the constants named below; `WeaponAim.intercept(shooter, shooter_v, speed, target, target_v) -> Dictionary` (`{dir: Vector3, time: float}` or `{}`).

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_weapon_aim.gd`:

```gdscript
extends GutTest

## WeaponAim (ship weapons spec §5.2): where to fire so a bolt carried at the
## shooter's velocity meets a target holding its own.

func _meets(shooter: Vector3, shooter_v: Vector3, speed: float, target: Vector3, target_v: Vector3) -> void:
	var s := WeaponAim.intercept(shooter, shooter_v, speed, target, target_v)
	assert_false(s.is_empty(), "a solution")
	if s.is_empty():
		return
	var t: float = s["time"]
	var bolt := shooter + (shooter_v + (s["dir"] as Vector3) * speed) * t
	assert_almost_eq(bolt, target + target_v * t, Vector3.ONE * 0.01, "the bolt is where the target is")

func test_a_still_target_dead_ahead():
	var s := WeaponAim.intercept(Vector3.ZERO, Vector3.ZERO, 100.0, Vector3(0, 0, -500), Vector3.ZERO)
	assert_almost_eq(s["dir"], Vector3.FORWARD, Vector3.ONE * 0.0001)
	assert_almost_eq(s["time"], 5.0, 0.0001)

func test_a_crossing_target_is_led():
	var s := WeaponAim.intercept(Vector3.ZERO, Vector3.ZERO, 600.0, Vector3(0, 0, -600), Vector3(30, 0, 0))
	assert_gt((s["dir"] as Vector3).x, 0.0, "aimed ahead of it, to its right")
	_meets(Vector3.ZERO, Vector3.ZERO, 600.0, Vector3(0, 0, -600), Vector3(30, 0, 0))

func test_the_shooters_velocity_is_carried():
	var s := WeaponAim.intercept(Vector3.ZERO, Vector3(50, 0, 0), 600.0, Vector3(0, 0, -600), Vector3(50, 0, 0))
	assert_almost_eq(s["dir"], Vector3.FORWARD, Vector3.ONE * 0.0001, "flying alongside, aim straight at it")
	_meets(Vector3(10, 5, 0), Vector3(-20, 3, 1), 450.0, Vector3(200, -40, -900), Vector3(15, 10, -30))

func test_a_target_outrunning_the_bolt_has_no_solution():
	assert_eq(WeaponAim.intercept(Vector3.ZERO, Vector3.ZERO, 600.0, Vector3(0, 0, -100), Vector3(0, 0, -700)), {})

func test_a_target_at_the_muzzle_has_no_solution():
	assert_eq(WeaponAim.intercept(Vector3.ONE, Vector3.ZERO, 600.0, Vector3.ONE, Vector3.ZERO), {})

func test_every_turret_kind_has_every_number():
	for kind in WeaponValues.TURRET_IDS:
		var s := WeaponValues.spec(kind)
		for key in ["slew", "burst", "gap", "recharge", "speed", "damage", "life", "push", "range",
				"manned_range", "spread", "qe", "length", "thickness", "flash", "barrel"]:
			assert_true(s.has(key), "%s has %s" % [kind, key])
		assert_gt(float(s["speed"]) * float(s["life"]), float(s["manned_range"]), "%s's bolts reach its manned range" % kind)
```

- [ ] **Step 2: Run it to see it fail**

Run: `./run_tests.ps1 '-gselect=test_weapon_aim.gd'`
Expected: parse errors naming `WeaponAim` / `WeaponValues` (not declared).

- [ ] **Step 3: Write `weapon_values.gd`**

```gdscript
class_name WeaponValues
extends RefCounted

## Every number the ship weapons use (docs/superpowers/specs/
## 2026-10-11-ship-weapons-design.md §3.1), in one place, as QuantumValues and
## HabitatValues are. Starting points: the combat probe (§10.2) tunes them and
## the spec's as-built notes record what they became.

const LIGHT := &"turret_light"
const HEAVY := &"turret_heavy"
const TURRET_IDS: Array[StringName] = [LIGHT, HEAVY]
const STATION := &"weapons_station"

## Per turret: slew deg/s; bolts a burst, seconds between them, recharge after
## a burst; bolt speed m/s, damage hp, life s, push N·s; engagement range m,
## and how far a gunner may fire it by hand; spread deg; QE a bolt; the bolt's
## length and thickness, m; its impact flash against a pistol bolt's; and the
## barrel's length from its pivot, m, where bolts leave.
const SPECS := {
	LIGHT: {"slew": 90.0, "burst": 4, "gap": 0.125, "recharge": 1.5, "speed": 600.0, "damage": 15.0,
		"life": 3.0, "push": 20.0, "range": 1200.0, "manned_range": 1200.0, "spread": 0.4, "qe": 1,
		"length": 2.0, "thickness": 0.25, "flash": 1.5, "barrel": 1.0},
	HEAVY: {"slew": 30.0, "burst": 1, "gap": 0.0, "recharge": 3.0, "speed": 450.0, "damage": 120.0,
		"life": 7.0, "push": 400.0, "range": 1500.0, "manned_range": 3000.0, "spread": 0.0, "qe": 15,
		"length": 4.0, "thickness": 0.5, "flash": 3.0, "barrel": 2.4},
}

## A turret fires when its barrel is this close to its solution (spec §5.3).
const AIM_TOLERANCE := deg_to_rad(1.0)
## Fire control hands out targets this often, s (spec §5.1).
const ASSIGN_EVERY := 0.2
## The most targets you may mark.
const LIST_MOST := 3
## A listed target unseen this long, s, leaves the list.
const MISSING_GRACE := 2.0
## Other ships and bases are contacts within this, m (spec §4.2); T marks
## within it, and within MARK_CONE of the crosshair (spec §9.1).
const CONTACT_RANGE := 5000.0
const MARK_CONE := deg_to_rad(10.0)
## From a turret cell's centre to its mount face, and from the face up to the
## barrels' pivot, m.
const FACE_OUT := 1.0
const MUZZLE_UP := 0.6
## Where a turret with no target rests: ahead, a little raised.
const PARK_ELEVATION := deg_to_rad(10.0)
## How much of its path a bolt's trail shows, s, and how long it takes to run
## up to where the bolt ended (spec §6.2).
const TRAIL_TIME := 0.4
## The sky map (spec §3.3): yaw by elevation bins, how far each ray marches
## and in what steps, m, and the clear share under which TURRET_BLIND warns.
const SKY_YAW := 32
const SKY_PITCH := 16
const SKY_REACH := 40.0
const SKY_STEP := 0.5
const BLIND_BELOW := 0.25
## Damaged (spec §3.4): slews at this share, recharges this many times longer.
const DAMAGED_SLEW := 0.5
const DAMAGED_RECHARGE := 2.0
## The ray each shot casts against its own hull, m.
const HULL_CHECK := 40.0
## The heavy bolt's practical light, m.
const HEAVY_LIGHT_RANGE := 30.0

static func spec(kind: StringName) -> Dictionary:
	return SPECS.get(kind, SPECS[LIGHT])

static func is_turret(block_id: StringName) -> bool:
	return TURRET_IDS.has(block_id)
```

- [ ] **Step 4: Write `weapon_aim.gd`**

```gdscript
class_name WeaponAim
extends RefCounted

## Where to fire a bolt so it meets a target (ship weapons spec §5.2). A bolt
## carries its shooter's velocity, so the solve is in the shooter's frame: the
## target moves at its velocity less the shooter's. The target is taken to
## hold its velocity; changing it is how you dodge.

## {dir, time}: the world direction to fire at `speed` and the seconds until
## the bolt meets the target; {} when it never can (it outruns the bolt, or is
## at the muzzle).
static func intercept(shooter: Vector3, shooter_v: Vector3, speed: float, target: Vector3,
		target_v: Vector3) -> Dictionary:
	var p := target - shooter
	var v := target_v - shooter_v
	var a := v.dot(v) - speed * speed
	var b := 2.0 * p.dot(v)
	var c := p.dot(p)
	if c < 1e-6:
		return {}
	var t := -1.0
	if absf(a) < 1e-6:
		if absf(b) > 1e-9:
			t = -c / b
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var root := sqrt(disc)
			var t1 := (-b - root) / (2.0 * a)
			var t2 := (-b + root) / (2.0 * a)
			var lo := minf(t1, t2)
			var hi := maxf(t1, t2)
			t = lo if lo > 0.0 else hi
	if t <= 0.0:
		return {}
	var aim := p + v * t
	if aim.length_squared() < 1e-9:
		return {}
	return {"dir": aim.normalized(), "time": t}
```

- [ ] **Step 5: Import, then run the test**

Run: `godot --headless --path . --import` then `./run_tests.ps1 '-gselect=test_weapon_aim.gd'`
Expected: `All tests passed`, 6 tests.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/combat/weapon_values.gd* who-knows/src/combat/weapon_aim.gd* who-knows/test/unit/test_weapon_aim.gd*
git commit -m "feat: WeaponValues and WeaponAim -- every weapon number, and where to fire to meet a target

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: `SkyMap`

**Files:**
- Create: `who-knows/src/combat/sky_map.gd`
- Test: `who-knows/test/unit/test_sky_map.gd`

**Interfaces:**
- Consumes: `WeaponValues` (Task 1).
- Produces: `SkyMap.build(layout: ShipGrid, coord: Vector3i, normal: Vector3i) -> SkyMap`; `SkyMap.normal_of(orientation: int) -> Vector3i` (the block's up, rounded); `SkyMap.mount_basis(normal: Vector3i) -> Basis` (+y the normal, -z its forward); `SkyMap.muzzle(coord, normal) -> Vector3` (hull-local); `SkyMap.direction(yaw_i, el_i) -> Vector3` and `SkyMap.angles(d: Vector3) -> Vector2` (mount frame: yaw 0 ahead, + to the right; elevation 0 at the face, PI/2 straight out); members `coord`, `normal`, `basis`, `origin`; `can_bear(dir_hull: Vector3) -> bool`; `coverage() -> float`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_sky_map.gd`:

```gdscript
extends GutTest

## SkyMap (ship weapons spec §3.3): which way a turret can fire without its
## own ship in the way, marched through the layout, every cell a cube.

func _plate(half := 2) -> ShipGrid:
	var g := ShipGrid.new()
	for x in range(-half, half + 1):
		for z in range(-half, half + 1):
			var inst := BlockInstance.new()
			inst.block_id = &"hull"
			g.set_block(Vector3i(x, 0, z), inst)
	return g

func _put(g: ShipGrid, at: Vector3i, id := &"hull") -> void:
	var inst := BlockInstance.new()
	inst.block_id = id
	g.set_block(at, inst)

func test_mount_normals_follow_the_block_up():
	assert_eq(SkyMap.normal_of(0), Vector3i.UP, "orientation 0 is dorsal")
	assert_eq(SkyMap.normal_of(2), Vector3i.DOWN, "orientation 2 is ventral")
	var sides := [SkyMap.normal_of(1), SkyMap.normal_of(3)]
	assert_true(sides.has(Vector3i.RIGHT) and sides.has(Vector3i.LEFT), "1 and 3 are the two flanks")
	for o in BlockOrientation.COUNT:
		var n := SkyMap.normal_of(o)
		assert_eq(absi(n.x) + absi(n.y) + absi(n.z), 1, "orientation %d has an axis normal" % o)

func test_the_mount_basis_stands_on_its_normal():
	for n: Vector3i in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i(0, 0, -1), Vector3i(0, 0, 1)]:
		var b := SkyMap.mount_basis(n)
		assert_almost_eq(b.y, Vector3(n), Vector3.ONE * 0.0001, "+y is %s" % n)
		assert_almost_eq(b.determinant(), 1.0, 0.0001, "a rotation")

func test_directions_and_angles_agree():
	for yi in [0, 7, 16, 31]:
		for ei in [0, 5, 15]:
			var d := SkyMap.direction(yi, ei)
			assert_almost_eq(d.length(), 1.0, 0.0001)
			var a := SkyMap.angles(d)
			assert_almost_eq(SkyMap.direction(yi, ei), Vector3(sin(a.x) * cos(a.y), sin(a.y), -cos(a.x) * cos(a.y)),
				Vector3.ONE * 0.0001)

func test_a_turret_on_a_flat_deck_sees_its_whole_half_sky():
	var sky := SkyMap.build(_plate(), Vector3i.ZERO, Vector3i.UP)
	assert_almost_eq(sky.coverage(), 1.0, 0.0001)
	assert_true(sky.can_bear(Vector3.UP))
	assert_true(sky.can_bear(Vector3(1, 0.05, 0).normalized()), "just over the horizon")
	assert_false(sky.can_bear(Vector3.DOWN), "never below its face")

func test_a_wall_beside_it_blocks_that_side_low():
	var g := _plate()
	for y in range(1, 4):
		for z in range(-2, 3):
			_put(g, Vector3i(2, y, z))
	var sky := SkyMap.build(g, Vector3i.ZERO, Vector3i.UP)
	assert_lt(sky.coverage(), 1.0)
	assert_false(sky.can_bear(Vector3(1, 0.2, 0).normalized()), "into the wall")
	assert_true(sky.can_bear(Vector3(-1, 0.2, 0).normalized()), "away from it")
	assert_true(sky.can_bear(Vector3.UP), "over it")

func test_a_ventral_turret_looks_down():
	var sky := SkyMap.build(_plate(), Vector3i.ZERO, Vector3i.DOWN)
	assert_true(sky.can_bear(Vector3.DOWN))
	assert_false(sky.can_bear(Vector3.UP))

func test_its_own_cell_never_blocks_it():
	var g := _plate()
	_put(g, Vector3i.ZERO, WeaponValues.LIGHT)
	assert_almost_eq(SkyMap.build(g, Vector3i.ZERO, Vector3i.UP).coverage(), 1.0, 0.0001)

func test_the_muzzle_stands_off_the_face():
	assert_almost_eq(SkyMap.muzzle(Vector3i(1, 2, 3), Vector3i.UP),
		ShipGrid.cell_center(Vector3i(1, 2, 3)) + Vector3.UP * (WeaponValues.FACE_OUT + WeaponValues.MUZZLE_UP),
		Vector3.ONE * 0.0001)
```

- [ ] **Step 2: Run it to see it fail**

Run: `./run_tests.ps1 '-gselect=test_sky_map.gd'`
Expected: parse errors naming `SkyMap`.

- [ ] **Step 3: Write `sky_map.gd`**

```gdscript
class_name SkyMap
extends RefCounted

## Which way a turret can fire without its own ship in the way (ship weapons
## spec §3.3): each direction of a SKY_YAW × SKY_PITCH grid over the half-sky
## above its mount face, marched from its muzzle through the ship's layout,
## every cell a cube, out to SKY_REACH. Pure, so ShipRules asks it too. A
## ship builds one per turret from its launch layout: a piece lost only opens
## the sky, and the ray each shot casts catches the rest.
##
## The mount frame: +y the face's normal, -z its forward (the hull's forward,
## or its up for a turret on a bow or a stern face). Yaw is 0 ahead and grows
## to the right; elevation is 0 along the face and PI/2 straight out.

var coord := Vector3i.ZERO
var normal := Vector3i.UP
## The mount frame in the hull's axes.
var basis := Basis.IDENTITY
## The muzzle, hull-local.
var origin := Vector3.ZERO
## 1 clear, 0 blocked, by yaw_i * SKY_PITCH + elevation_i.
var bits := PackedByteArray()

## The face a block of `orientation` stands on: its up, rounded.
static func normal_of(orientation: int) -> Vector3i:
	var up := BlockOrientation.basis_for(orientation) * Vector3.UP
	return Vector3i(roundi(up.x), roundi(up.y), roundi(up.z))

static func mount_basis(n: Vector3i) -> Basis:
	var up := Vector3(n)
	var forward := Vector3.FORWARD if absf(up.z) < 0.5 else Vector3.UP
	return Basis.looking_at(forward, up).orthonormalized()

## Where a turret on `coord`'s `n` face fires from, hull-local: the barrels'
## pivot, MUZZLE_UP off the face.
static func muzzle(p_coord: Vector3i, n: Vector3i) -> Vector3:
	return ShipGrid.cell_center(p_coord) + Vector3(n) * (WeaponValues.FACE_OUT + WeaponValues.MUZZLE_UP)

static func build(layout: ShipGrid, p_coord: Vector3i, n: Vector3i) -> SkyMap:
	var m := SkyMap.new()
	m.coord = p_coord
	m.normal = n
	m.basis = mount_basis(n)
	m.origin = muzzle(p_coord, n)
	m.bits.resize(WeaponValues.SKY_YAW * WeaponValues.SKY_PITCH)
	var steps := int(WeaponValues.SKY_REACH / WeaponValues.SKY_STEP)
	for yi in WeaponValues.SKY_YAW:
		for ei in WeaponValues.SKY_PITCH:
			var dir := m.basis * direction(yi, ei)
			m.bits[yi * WeaponValues.SKY_PITCH + ei] = 1 if _clear(layout, p_coord, m.origin, dir, steps) else 0
	return m

static func _clear(layout: ShipGrid, own: Vector3i, from: Vector3, dir: Vector3, steps: int) -> bool:
	for k in range(1, steps + 1):
		var p := from + dir * (k * WeaponValues.SKY_STEP)
		var cell := Vector3i((p / ShipGrid.CELL_SIZE).round())
		if cell != own and layout.has_block(cell):
			return false
	return true

## The centre of bin (yaw_i, elevation_i), a mount-frame unit vector.
static func direction(yi: int, ei: int) -> Vector3:
	var yaw := (yi + 0.5) / WeaponValues.SKY_YAW * TAU - PI
	var el := (ei + 0.5) / WeaponValues.SKY_PITCH * PI * 0.5
	return Vector3(sin(yaw) * cos(el), sin(el), -cos(yaw) * cos(el))

## A mount-frame direction's (yaw, elevation).
static func angles(d: Vector3) -> Vector2:
	var n := d.normalized()
	return Vector2(atan2(n.x, -n.z), asin(clampf(n.y, -1.0, 1.0)))

## A mount-frame direction's bin, or (-1, -1) below the face.
static func bin(d: Vector3) -> Vector2i:
	var a := angles(d)
	if a.y < -0.0001:
		return Vector2i(-1, -1)
	var yi := clampi(floori((a.x + PI) / TAU * WeaponValues.SKY_YAW), 0, WeaponValues.SKY_YAW - 1)
	var ei := clampi(floori(maxf(a.y, 0.0) / (PI * 0.5) * WeaponValues.SKY_PITCH), 0, WeaponValues.SKY_PITCH - 1)
	return Vector2i(yi, ei)

## Whether a shot along `dir_hull` (hull-local) is clear of the ship.
func can_bear(dir_hull: Vector3) -> bool:
	var b := bin(basis.inverse() * dir_hull)
	if b.x < 0:
		return false
	return bits[b.x * WeaponValues.SKY_PITCH + b.y] == 1

## The clear share of the half-sky, 0..1.
func coverage() -> float:
	var clear := 0
	for v in bits:
		clear += v
	return float(clear) / maxf(bits.size(), 1.0)
```

- [ ] **Step 4: Import, run the test**

Run: `godot --headless --path . --import` then `./run_tests.ps1 '-gselect=test_sky_map.gd'`
Expected: `All tests passed`, 8 tests. If `test_mount_normals_follow_the_block_up` fails on 1 and 3, the flanks are the other way round: fix the test's expectation only if both still land on ±x, and note which is starboard for Task 10.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/combat/sky_map.gd* who-knows/test/unit/test_sky_map.gd*
git commit -m "feat: SkyMap -- the half-sky a turret can fire into without hitting its own ship

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: `Bolt`, `PhaserBolt`, `BoltPool`

**Files:**
- Create: `who-knows/src/combat/bolt.gd`, `phaser_bolt.gd`, `bolt_pool.gd`
- Modify: `who-knows/src/items/plasma_bolt.gd` (extends `Bolt`), `who-knows/src/items/impact_flash.gd` (`grow`), `who-knows/src/world/space_palette.gd` (`PHASER`), `who-knows/test/unit/test_visual_style_rules.gd` (painting files)
- Test: `who-knows/test/unit/test_plasma_bolt.gd` (unchanged, must pass), `who-knows/test/unit/test_phaser_bolt.gd` (new)

**Interfaces:**
- Consumes: `WeaponValues` (Task 1).
- Produces: `Bolt` (fields `direction`, `carrier`, `speed`, `lifetime`, `push`, `damage`, `kind`, `ray_mask`, `flash_scale`, `exclude: Array[RID]`, `source`, `age`, `outside`, `travelled`; `launch(from, dir)`, `impact(result)`, `is_spent()`, signal `struck(point, collider)`; virtuals `_done()`, `_after(delta)`); `PhaserBolt.RAY_MASK`, `arm(kind, from, dir, carrier, source, exclude)`; `BoltPool.GROUP`, `BoltPool.find(tree) -> BoltPool`, `fire(kind, from, dir, carrier, source, exclude) -> PhaserBolt`, `release(bolt)`, `live: int`, `made: int`; `ImpactFlash.spawn(parent, at, normal, kind, out := false, grow := 1.0)`; `SpacePalette.PHASER`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_phaser_bolt.gd`:

```gdscript
extends GutTest

## PhaserBolt and BoltPool (ship weapons spec §6): a turret's bolt flies at
## its ship's velocity plus its own, hits what is outside, leaves a trail that
## runs up to its end, and goes back to the pool.

class Target extends StaticBody3D:
	var hits: Array = []
	func receive_hit(hit: Hit) -> void:
		hits.append(hit)

var _world: Node3D
var _pool: BoltPool

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_pool = BoltPool.new()
	_world.add_child(_pool)

func _slab(z: float, body: StaticBody3D = null) -> StaticBody3D:
	var slab := body if body != null else StaticBody3D.new()
	slab.collision_layer = 1
	var box := BoxShape3D.new()
	box.size = Vector3(40, 40, 1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	slab.add_child(shape)
	_world.add_child(slab)
	slab.global_position = Vector3(0, 0, z)
	return slab

func _fire(from := Vector3.ZERO, dir := Vector3.FORWARD, carrier := Vector3.ZERO, ex: Array[RID] = []) -> PhaserBolt:
	return _pool.fire(WeaponValues.LIGHT, from, dir, carrier, null, ex)

func test_it_flies_at_its_speed_plus_its_carrier():
	var bolt := _fire(Vector3.ZERO, Vector3.FORWARD, Vector3(10, 0, 0))
	await wait_physics_frames(30)
	var t := bolt.age
	assert_almost_eq(bolt.global_position.x, 10.0 * t, 0.2, "carried sideways with its ship")
	assert_almost_eq(bolt.global_position.z, -600.0 * t, 2.0, "and out at 600 m/s")

func test_a_hit_carries_its_damage_and_kind():
	var target := _slab(-60.0, Target.new()) as Target
	await wait_physics_frames(2)
	_fire()
	await wait_physics_frames(20)
	assert_eq(target.hits.size(), 1)
	var hit: Hit = target.hits[0]
	assert_eq(hit.damage, WeaponValues.spec(WeaponValues.LIGHT)["damage"])
	assert_eq(hit.kind, &"phaser")

func test_it_ignores_what_it_excludes():
	var own := _slab(-20.0)
	var far := _slab(-80.0, Target.new()) as Target
	await wait_physics_frames(2)
	var ex: Array[RID] = [own.get_rid()]
	_fire(Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, ex)
	await wait_physics_frames(20)
	assert_eq(far.hits.size(), 1, "through its own ship to the target beyond")

func test_it_hits_a_spacewalker():
	assert_eq(PhaserBolt.RAY_MASK & 4, 4, "the avatar's layer")

func test_its_trail_grows_then_runs_up_and_it_goes_back_to_the_pool():
	_slab(-300.0)
	await wait_physics_frames(2)
	var bolt := _fire()
	await wait_physics_frames(10)
	var trail := bolt.get_node("Trail") as MeshInstance3D
	assert_gt(trail.scale.z, 1.0, "a streak behind it")
	await wait_physics_frames(40)
	assert_true(bolt.is_spent())
	await wait_seconds(WeaponValues.TRAIL_TIME + 0.2)
	assert_false(bolt.visible, "gone")
	assert_eq(_pool.live, 0)
	_fire()
	assert_eq(_pool.made, 1, "the pool reused it")

func test_every_bolt_is_shifted_by_the_origin():
	var bolt := _fire()
	assert_true(bolt.is_in_group(Universe.EXTERIOR_SPACE))
	bolt.age = bolt.lifetime - 0.01
	await wait_seconds(WeaponValues.TRAIL_TIME + 0.2)
	assert_true(bolt.is_in_group(Universe.EXTERIOR_SPACE), "pooled too: it never leaves the group")

func test_a_heavy_bolt_carries_a_light():
	var heavy := _pool.fire(WeaponValues.HEAVY, Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, null, [] as Array[RID])
	var light := heavy.get_node("Light") as OmniLight3D
	assert_true(light.visible)
	assert_eq(light.light_color, SpacePalette.PHASER)
	var small := _fire()
	assert_false((small.get_node("Light") as OmniLight3D).visible, "light bolts only glow")
```

- [ ] **Step 2: Run it to see it fail**

Run: `./run_tests.ps1 '-gselect=test_phaser_bolt.gd'`
Expected: parse errors naming `BoltPool`, `PhaserBolt`.

- [ ] **Step 3: Write `bolt.gd`**

```gdscript
class_name Bolt
extends Node3D

## What every bolt does (hands-and-items spec §9.2, §9.3; ship weapons spec
## §6.1). Not a physics body: each tick it casts a ray from where it is to
## where it will be, so it cannot pass through a 0.1 m wall at any speed. Where
## it lands it pushes whatever is loose, tells anything that listens
## (receive_hit), flashes, and is done. `outside`, it hits what is out there
## and moves with the floating origin (CLAUDE.md). PlasmaBolt and PhaserBolt
## set the numbers and the look.

signal struck(point: Vector3, collider: Object)

var direction := Vector3.FORWARD
## The shooter's velocity, carried by the bolt (world, m/s): a turret's bolts
## leave with their ship's motion. Zero for the pistol.
var carrier := Vector3.ZERO
var speed := 45.0
var lifetime := 1.5
## Newton-seconds given to whatever it hits.
var push := 6.0
## hp it takes from what it hits.
var damage := 10.0
var kind: StringName = &"plasma"
var ray_mask := 0
## Its impact flash's size against a pistol bolt's.
var flash_scale := 1.0
var exclude: Array[RID] = []
var source: Node = null
var age := 0.0
## Set before it enters the tree.
var outside := false
## Metres flown, for a trail.
var travelled := 0.0

var _spent := false

func launch(from: Vector3, dir: Vector3) -> void:
	direction = dir.normalized()
	var along := carrier + direction * speed
	along = along.normalized() if along.length_squared() > 1e-9 else direction
	var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(along, up), from)

func is_spent() -> bool:
	return _spent

func _physics_process(delta: float) -> void:
	if _spent:
		_after(delta)
		return
	age += delta
	if age >= lifetime:
		_spent = true
		_done()
		return
	var from := global_position
	var step := (carrier + direction * speed) * delta
	var query := PhysicsRayQueryParameters3D.create(from, from + step, ray_mask, exclude)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = from + step
		travelled += step.length()
	else:
		travelled += from.distance_to(result["position"])
		impact(result)

## Lands: a push, the hook, a flash, and done.
func impact(result: Dictionary) -> void:
	if _spent:
		return
	_spent = true
	var point: Vector3 = result["position"]
	var normal: Vector3 = result["normal"]
	var collider: Object = result.get("collider")
	var body := collider as RigidBody3D
	if body != null and not body.freeze:
		body.apply_impulse(direction * push, point - body.global_position)
		body.sleeping = false
	var hit := Hit.make(point, normal, direction, direction * push, source)
	hit.damage = damage
	hit.kind = kind
	hit.shape = int(result.get("shape", -1))
	Hit.deliver(collider, hit)
	_tell_npcs(point, collider)
	ImpactFlash.spawn(get_parent(), point, normal, ImpactFlash.Kind.IMPACT, outside, flash_scale)
	struck.emit(point, collider)
	_done()

## Spent: freed here; a pooled bolt goes back to its pool.
func _done() -> void:
	queue_free()

## Each tick once spent, until it is gone: a trail fading.
func _after(_delta: float) -> void:
	pass

## What NPCs notice of a hit (NPC foundation spec §6.1): a crack they hear
## through air, and, on a rock, a jolt through the stone.
func _tell_npcs(point: Vector3, collider: Object) -> void:
	StimulusBus.send(self, Stimulus.make(Stimulus.SOUND, point, 1.0, 15.0, source))
	var rock: AsteroidRock = null
	if collider is AsteroidDetail:
		rock = (collider as AsteroidDetail).rock
	elif collider is AsteroidBody:
		rock = (collider as AsteroidBody).rock
	if rock != null:
		StimulusBus.send(self, Stimulus.make(Stimulus.VIBRATION, point, 0.8, 40.0, source, RockHerds.site_of(rock)))
```

- [ ] **Step 4: Put `PlasmaBolt` on `Bolt`**

In `who-knows/src/items/plasma_bolt.gd`: `extends Bolt`; delete `signal struck`, the `direction`, `exclude`, `source`, `age`, `outside` and `_spent` vars, `launch()`, `_physics_process()`, `impact()` and `_tell_npcs()` (all now `Bolt`'s). Keep every constant, `static var _mesh`, `mask()`, `render_layer()`, `light_mask()` and `_shared_mesh()`. Add:

```gdscript
func _init() -> void:
	speed = SPEED
	lifetime = LIFETIME
	push = PUSH
	damage = DAMAGE
	kind = &"plasma"
```

and start `_ready()` with `ray_mask = mask(outside)` before its `if outside: add_to_group(...)`. The doc comment at the top becomes: "A plasma bolt (hands-and-items spec §9.2, §9.3): the pistol's. Its flight and its landing are Bolt's; this sets its numbers and its look." `plasma_emitter.gd` and `grid_home.gd` need no change.

- [ ] **Step 5: `ImpactFlash` grows**

In `who-knows/src/items/impact_flash.gd`: add `var grow := 1.0` beside `var outside`; `spawn` gains `grow_by := 1.0` as its last parameter and sets `flash.grow = grow_by` before `parent.add_child(flash)`; in `_process` the burst's scale is `maxf(sin(t * PI) * SIZE[kind] * grow, 0.001)`; in `_ready` the light's `omni_range` is `LIGHT_RANGE * grow`.

- [ ] **Step 6: `SpacePalette.PHASER`**

In `who-knows/src/world/space_palette.gd`, after the existing constants:

```gdscript
## A turret's phaser bolt and its trail (ship weapons spec §6.2): a hot
## amber-gold, warm like every light in the game, never the rejected blue.
const PHASER := Color("ffbf4d")
```

- [ ] **Step 7: Write `phaser_bolt.gd`**

```gdscript
class_name PhaserBolt
extends Bolt

## A turret's bolt (ship weapons spec §6): an elongated amber-gold streak
## carried at its ship's velocity, with a light trail behind it, always
## outside. Pooled (BoltPool): spent, its trail runs up to where it ended and
## it goes back to the pool, never freed. It is in Universe.EXTERIOR_SPACE
## from the moment it is made, flying or waiting.

## Outside, everything a turret can hit: exterior_hull | avatar | terrain |
## items | asteroids | npcs.
const RAY_MASK := 1 | 4 | BodyProxy.LAYER | Item.LAYER | AsteroidBody.LAYER | Npc.LAYER
const HEAD_ENERGY := 2.6
const TRAIL_ENERGY := 1.4
## The trail's thickness against the head's.
const TRAIL_THIN := 0.35
const LIGHT_ENERGY := 1.2

static var _head_mesh: Mesh
static var _trail_mesh: Mesh

var turret_kind := WeaponValues.LIGHT
var pool: BoltPool
var _head: MeshInstance3D
var _trail: MeshInstance3D
var _light: OmniLight3D
var _fading := 0.0
var _trail_end := 0.0

func _init() -> void:
	outside = true
	ray_mask = RAY_MASK
	kind = &"phaser"
	_spent = true

func _ready() -> void:
	add_to_group(Universe.EXTERIOR_SPACE)
	_head = _streak("Head", _shared(true))
	_trail = _streak("Trail", _shared(false))
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.light_color = SpacePalette.PHASER
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = WeaponValues.HEAVY_LIGHT_RANGE
	_light.light_cull_mask = PlasmaBolt.light_mask(true)
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	visible = false
	set_physics_process(false)

func _streak(streak_name: String, mesh: Mesh) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = streak_name
	m.mesh = mesh
	m.material_override = InteriorMaterials.glow()
	m.layers = Item.SPACE_LAYER
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

## Readies it to fly from `from` along `dir` as a `p_kind` turret's bolt,
## carried at `p_carrier`, from `p_source`, through `p_exclude`.
func arm(p_kind: StringName, from: Vector3, dir: Vector3, p_carrier: Vector3, p_source: Node,
		p_exclude: Array[RID]) -> void:
	var s := WeaponValues.spec(p_kind)
	turret_kind = p_kind
	speed = s["speed"]
	lifetime = s["life"]
	damage = s["damage"]
	push = s["push"]
	flash_scale = s["flash"]
	carrier = p_carrier
	source = p_source
	exclude = p_exclude
	age = 0.0
	travelled = 0.0
	_fading = 0.0
	_spent = false
	launch(from, dir)
	var thick: float = s["thickness"]
	_head.scale = Vector3(thick, thick, s["length"])
	_head.visible = true
	_light.visible = p_kind == WeaponValues.HEAVY
	_draw_trail()
	visible = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	super(delta)
	if not _spent:
		_draw_trail()

## Where it lands, it stops: the trail runs up to that point.
func impact(result: Dictionary) -> void:
	if _spent:
		return
	global_position = result["position"]
	super(result)

func _draw_trail() -> void:
	var length := minf(travelled, (carrier + direction * speed).length() * WeaponValues.TRAIL_TIME)
	var thick: float = WeaponValues.spec(turret_kind)["thickness"] * TRAIL_THIN
	_trail.scale = Vector3(thick, thick, maxf(length, 0.001))

func _done() -> void:
	_head.visible = false
	_light.visible = false
	_trail_end = _trail.scale.z
	_fading = 0.0

func _after(delta: float) -> void:
	_fading += delta
	var left := 1.0 - _fading / WeaponValues.TRAIL_TIME
	if left <= 0.0:
		_release()
		return
	var thick: float = WeaponValues.spec(turret_kind)["thickness"] * TRAIL_THIN * left
	_trail.scale = Vector3(thick, thick, maxf(_trail_end * left, 0.001))

func _release() -> void:
	set_physics_process(false)
	visible = false
	if pool != null:
		pool.release(self)
	else:
		queue_free()

## A unit streak from the node back along +z, 1 m long: the head brighter, the
## trail dimmer. Scaled per bolt, so one mesh serves every bolt and the shared
## glow material is never touched.
static func _shared(head: bool) -> Mesh:
	if head and _head_mesh != null:
		return _head_mesh
	if not head and _trail_mesh != null:
		return _trail_mesh
	var holder := Node3D.new()
	var kit := InteriorKit.new(holder)
	kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.5)), Vector3.ONE,
		0.3 if head else 0.45, InteriorKit.lit(SpacePalette.PHASER, HEAD_ENERGY if head else TRAIL_ENERGY))
	var mesh := kit.commit()[0].mesh
	holder.free()
	if head:
		_head_mesh = mesh
	else:
		_trail_mesh = mesh
	return mesh
```

- [ ] **Step 8: Write `bolt_pool.gd`**

```gdscript
class_name BoltPool
extends Node3D

## Every turret bolt (ship weapons spec §6.3): made once and reused, so a
## broadside makes no nodes. One per game, under the outside world; it never
## moves, and each bolt is shifted by the floating origin itself.

const GROUP := &"bolt_pool"

## Bolts flying or fading now, and every bolt ever made: for the probe.
var live := 0
var made := 0
var _free: Array[PhaserBolt] = []

func _ready() -> void:
	add_to_group(GROUP)

static func find(tree: SceneTree) -> BoltPool:
	return tree.get_first_node_in_group(GROUP) as BoltPool if tree != null else null

## A `kind` turret's bolt from `from` along `dir`, carried at `carrier`.
func fire(kind: StringName, from: Vector3, dir: Vector3, carrier: Vector3, source: Node,
		exclude: Array[RID]) -> PhaserBolt:
	var bolt: PhaserBolt
	if _free.is_empty():
		bolt = PhaserBolt.new()
		bolt.name = "Bolt%d" % made
		bolt.pool = self
		add_child(bolt)
		made += 1
	else:
		bolt = _free.pop_back()
	live += 1
	bolt.arm(kind, from, dir, carrier, source, exclude)
	return bolt

func release(bolt: PhaserBolt) -> void:
	live -= 1
	_free.append(bolt)
```

- [ ] **Step 9: The style rules know the new painters**

In `test_visual_style_rules.gd`'s `PAINTING_FILES`, after `"res://src/items/plasma_bolt.gd",` add `"res://src/combat/bolt.gd",` and `"res://src/combat/phaser_bolt.gd",`.

- [ ] **Step 10: Import, run the tests**

Run: `godot --headless --path . --import`, then `./run_tests.ps1 '-gselect=test_phaser_bolt.gd'`, `'-gselect=test_plasma_bolt.gd'`, `'-gselect=test_plasma_emitter.gd'`, `'-gselect=test_visual_style_rules.gd'`.
Expected: `All tests passed` in each; `test_plasma_bolt.gd` and `test_plasma_emitter.gd` unchanged.

- [ ] **Step 11: Commit**

```bash
git add who-knows/src/combat who-knows/src/items/plasma_bolt.gd who-knows/src/items/impact_flash.gd who-knows/src/world/space_palette.gd who-knows/test/unit/test_phaser_bolt.gd* who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: Bolt, PhaserBolt and BoltPool -- the pistol's flight shared, a turret's amber bolt with its trail, pooled

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: The turret blocks, their tokens, and a component each

**Files:**
- Create: `who-knows/data/blocks/turret_light.tres`, `who-knows/data/blocks/turret_heavy.tres`
- Modify: `who-knows/src/ship/ship_plan.gd` (`BASE`), `who-knows/src/ship/ship_damage.gd`, `who-knows/test/unit/test_block_data.gd`
- Test: `who-knows/test/unit/test_turret_damage.gd` (new)

**Interfaces:**
- Consumes: `WeaponValues.TURRET_IDS` (Task 1).
- Produces: block ids `&"turret_light"`, `&"turret_heavy"` (SYSTEMS, SOLID); tokens `Tl`, `Th`; `ShipDamage.turret_part(coord) -> StringName` (`&"turret:x,y,z"`), `ShipDamage.is_turret_part(part) -> bool`, `ShipDamage.turret_labels: Dictionary` (part → `"TURRET n"`).

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_turret_damage.gd`:

```gdscript
extends GutTest

## Every turret is a component of its own (ship weapons spec §3.4): hit on its
## cell, it is the turret that takes it, never a section; numbered bow first.

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func _ship() -> ShipGrid:
	var g := ShipGrid.new()
	for z in range(-2, 3):
		for x in range(-1, 2):
			var inst := BlockInstance.new()
			inst.block_id = &"hull"
			g.set_block(Vector3i(x, 0, z), inst)
	for at: Vector3i in [Vector3i(0, 1, 1), Vector3i(0, 1, -2)]:
		var t := BlockInstance.new()
		t.block_id = WeaponValues.LIGHT
		g.set_block(at, t)
	return g

func test_the_blocks_load_as_systems():
	for id in WeaponValues.TURRET_IDS:
		var def := _cat.get_def(id)
		assert_not_null(def, "%s loads" % id)
		if def == null:
			continue
		assert_eq(def.category, BlockDefinition.Category.SYSTEMS)
		assert_eq(def.occupancy, BlockDefinition.Occupancy.SOLID)
	assert_eq(_cat.get_def(WeaponValues.LIGHT).hp, 200)
	assert_almost_eq(_cat.get_def(WeaponValues.LIGHT).power_draw, 0.1, 0.0001)
	assert_eq(_cat.get_def(WeaponValues.HEAVY).hp, 400)
	assert_almost_eq(_cat.get_def(WeaponValues.HEAVY).mass_t, 2.0, 0.0001)

func test_their_tokens():
	assert_eq(ShipPlan.default_token(WeaponValues.LIGHT, 0), "Tl")
	assert_eq(ShipPlan.default_token(WeaponValues.HEAVY, 2), "Th2")
	assert_eq(ShipPlan.default_pair("Tl3"), [WeaponValues.LIGHT, 3])

func test_each_turret_is_its_own_component():
	var d := ShipDamage.build(_ship(), _cat)
	var part := ShipDamage.turret_part(Vector3i(0, 1, 1))
	assert_eq(d.component_of[Vector3i(0, 1, 1)], part)
	assert_true(d.has_component(part))
	var before := d.hull_whole()
	assert_true(d.hit(Vector3i(0, 1, 1), 150.0))
	assert_eq(d.component_stage(part), BlockDamage.Stage.DAMAGED)
	assert_eq(d.hull_whole(), before, "the hull took none of it")
	assert_eq(d.component_stage(ShipDamage.turret_part(Vector3i(0, 1, -2))), BlockDamage.Stage.INTACT, "the other turret neither")

func test_turrets_are_numbered_bow_first():
	var d := ShipDamage.build(_ship(), _cat)
	assert_eq(d.label(ShipDamage.turret_part(Vector3i(0, 1, -2))), "TURRET 1")
	assert_eq(d.label(ShipDamage.turret_part(Vector3i(0, 1, 1))), "TURRET 2")

func test_a_turret_degrades_and_round_trips():
	assert_true(ShipDamage.degrades(WeaponValues.LIGHT))
	var d := ShipDamage.build(_ship(), _cat)
	d.hit(Vector3i(0, 1, 1), 200.0)
	var again := ShipDamage.build(_ship(), _cat)
	again.from_dict(d.to_dict())
	assert_eq(again.component_stage(ShipDamage.turret_part(Vector3i(0, 1, 1))), BlockDamage.Stage.WRECKED)
```

In `who-knows/test/unit/test_block_data.gd`: `test_all_thirty_three_blocks_load` becomes `test_all_thirty_five_blocks_load` asserting `35`.

- [ ] **Step 2: Run them to see them fail**

Run: `./run_tests.ps1 '-gselect=test_turret_damage.gd'`
Expected: failures: no `turret_light` definition, no `turret_part`.

- [ ] **Step 3: The block files**

`who-knows/data/blocks/turret_light.tres` (no comments anywhere in it):

```
[gd_resource type="Resource" script_class="BlockDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/ship/block_definition.gd" id="1_script"]

[sub_resource type="BoxMesh" id="BoxMesh_turret_light"]
size = Vector3(2, 2, 2)

[resource]
script = ExtResource("1_script")
id = &"turret_light"
display_name = "Light Turret"
category = 1
occupancy = 0
mass_t = 0.8
hp = 200
power_gen = 0.0
power_draw = 0.1
thrust_kn = 0.0
grav_radius = 0.0
mesh = SubResource("BoxMesh_turret_light")
```

`who-knows/data/blocks/turret_heavy.tres`: the same with `id="BoxMesh_turret_heavy"` (both places), `id = &"turret_heavy"`, `display_name = "Heavy Turret"`, `mass_t = 2.0`, `hp = 400`, `power_draw = 0.3`.

- [ ] **Step 4: Tokens**

In `ship_plan.gd`'s `BASE`, after `&"quantum_tank": "Qt",` add `&"turret_light": "Tl", &"turret_heavy": "Th",`.

- [ ] **Step 5: Turret components in `ShipDamage`**

In `who-knows/src/ship/ship_damage.gd`:

Add to the doc comment: "Every turret is a component of its own (ship weapons spec §3.4), numbered bow to stern, port to starboard."

After `var launch := {}` add:

```gdscript
## Each turret's label, by its part: "TURRET 1" bow first.
var turret_labels := {}
```

In `build()`, at the top of the per-coord loop body, right after `d.launch[coord] = [inst.block_id, inst.orientation, hp]`:

```gdscript
		if WeaponValues.is_turret(inst.block_id):
			var part := turret_part(coord)
			d.component_of[coord] = part
			d.component_hp[part] = hp
			continue
```

After the loop that sets `d.component_damage[comp] = 0.0`, add `d._number_turrets()`, and the functions:

```gdscript
## A turret's part id (ship weapons spec §3.4).
static func turret_part(coord: Vector3i) -> StringName:
	return StringName("turret:%d,%d,%d" % [coord.x, coord.y, coord.z])

static func is_turret_part(part: StringName) -> bool:
	return String(part).begins_with("turret:")

## TURRET 1, 2 ... bow to stern, then port to starboard, then top down.
func _number_turrets() -> void:
	var cells: Array[Vector3i] = []
	for coord: Vector3i in component_of:
		if is_turret_part(component_of[coord]):
			cells.append(coord)
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.z != b.z:
			return a.z < b.z
		if a.x != b.x:
			return a.x < b.x
		return a.y > b.y)
	for i in cells.size():
		turret_labels[turret_part(cells[i])] = "TURRET %d" % (i + 1)
```

`degrades()` starts with `if WeaponValues.is_turret(block_id): return true`. `label()` becomes `return SECTION_LABELS.get(part, COMPONENT_LABELS.get(part, turret_labels.get(part, "")))`.

- [ ] **Step 6: Run the tests**

Run: `godot --headless --path . --import`, then `./run_tests.ps1 '-gselect=test_turret_damage.gd'`, `'-gselect=test_block_data.gd'`, `'-gselect=test_ship_damage.gd'` (if it exists; else `test_block_damage.gd`), `'-gselect=test_ship_plan.gd'`.
Expected: `All tests passed` in each. If `test_block_data.gd`'s `test_required_ids_exist` or a mesh test lists blocks by hand, add the two.

- [ ] **Step 7: Commit**

```bash
git add who-knows/data/blocks/turret_light.tres who-knows/data/blocks/turret_heavy.tres who-knows/src/ship/ship_plan.gd who-knows/src/ship/ship_damage.gd who-knows/test/unit/test_turret_damage.gd* who-knows/test/unit/test_block_data.gd
git commit -m "feat: the light and heavy turret blocks, Tl and Th, each turret a component of its own

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Targets — `Weapons`, who joins, and `TargetContacts`

**Files:**
- Create: `who-knows/src/combat/weapons.gd`, `who-knows/src/sensors/target_contacts.gd`
- Modify: `who-knows/src/ship/ship.gd` (`_rebuild_everything` joins), `who-knows/src/habitat/base.gd` (`_ready` joins), `who-knows/src/npc/npc_director.gd` (`targets`), `who-knows/src/items/item.gd` (`set_space`)
- Test: `who-knows/test/unit/test_weapons.gd` (new)

**Interfaces:**
- Produces: `Weapons.TARGETS`, `Weapons.ID`, `static var hostile_rule: Callable`; `join(node, id)`, `leave(node)`, `id_of(node) -> StringName`, `ship_id(ship) -> StringName`, `base_id(site_id) -> StringName`, `npc_id(record_id) -> StringName`, `item_id(item) -> StringName`, `kind_of(id) -> StringName` (`&"ship"`, `&"base"`, `&"npc"`, `&"item"`), `usable(node) -> bool`, `find(tree, id) -> Node3D`, `point_of(node) -> Vector3`, `velocity_of(node) -> Vector3`, `label_of(node) -> String`, `is_hostile(node) -> bool`, `is_own(ship, node) -> bool`; `NpcDirector.targets: bool`; `TargetContacts.new(own: Node, universe: Universe)` as a sensor source.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_weapons.gd`:

```gdscript
extends GutTest

## What turrets may shoot (ship weapons spec §4): the TARGETS group, the ids,
## where a target is and how it moves, and what is never one.

var _world: Node3D

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)

func after_each():
	Weapons.hostile_rule = Callable()

func _body(id: StringName, at := Vector3.ZERO) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.gravity_scale = 0.0
	_world.add_child(b)
	b.global_position = at
	Weapons.join(b, id)
	return b

func test_join_find_and_leave():
	var b := _body(&"ship:Ship2")
	assert_eq(Weapons.id_of(b), &"ship:Ship2")
	assert_same(Weapons.find(get_tree(), &"ship:Ship2"), b)
	Weapons.leave(b)
	assert_null(Weapons.find(get_tree(), &"ship:Ship2"))

func test_a_freed_target_is_not_found():
	var b := _body(&"item:1")
	b.free()
	assert_null(Weapons.find(get_tree(), &"item:1"))

func test_kinds():
	assert_eq(Weapons.kind_of(&"ship:Ship2"), &"ship")
	assert_eq(Weapons.kind_of(&"npc:skitter:rock:3"), &"npc")
	assert_eq(Weapons.kind_of(&"nothing"), &"")

func test_where_a_body_is_and_how_it_moves():
	var b := _body(&"item:2", Vector3(5, 0, 0))
	b.linear_velocity = Vector3(0, 3, 0)
	assert_almost_eq(Weapons.point_of(b), Vector3(5, 0, 0), Vector3.ONE * 0.001)
	assert_almost_eq(Weapons.velocity_of(b), Vector3(0, 3, 0), Vector3.ONE * 0.001)
	b.freeze = true
	assert_eq(Weapons.velocity_of(b), Vector3.ZERO, "a base stands still")

func test_own_and_hostile():
	var ship := Node.new()
	add_child_autofree(ship)
	var hull := _body(&"ship:A")
	hull.set_meta(&"ship", ship)
	assert_true(Weapons.is_own(ship, hull))
	assert_false(Weapons.is_own(ship, _body(&"ship:B")))
	assert_false(Weapons.is_hostile(hull), "nothing is hostile in this project")
	Weapons.hostile_rule = func(n: Node) -> bool: return n == hull
	assert_true(Weapons.is_hostile(hull))

func test_an_item_outside_is_a_target_and_aboard_is_not():
	var d := ItemDefinition.new()
	d.id = &"crate"
	d.display_name = "Crate"
	d.size = Vector3(0.5, 0.5, 0.5)
	d.look = &"crate"
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.set_space(true)
	assert_true(item.is_in_group(Weapons.TARGETS))
	assert_eq(Weapons.kind_of(Weapons.id_of(item)), &"item")
	assert_eq(Weapons.label_of(item), "CRATE")
	item.set_space(false)
	assert_false(item.is_in_group(Weapons.TARGETS))

func test_target_contacts_lists_other_ships_in_range():
	var universe := Universe.new()
	_world.add_child(universe)
	var own := _body(&"ship:Own")
	var near := _body(&"ship:Near", Vector3(0, 0, -800))
	_body(&"ship:Far", Vector3(0, 0, -9000))
	_body(&"item:9", Vector3(0, 0, -50))
	var source := TargetContacts.new(own, universe)
	var found := source.contacts(universe.to_universe(Vector3.ZERO), 10000.0, 0.0)
	assert_eq(found.size(), 1, "only the near ship: not itself, not past 5 km, not an item")
	if found.size() == 1:
		assert_eq(found[0].id, &"ship:Near")
		assert_eq(found[0].kind, &"ship")
	assert_not_null(source.contact(&"ship:Near", universe.to_universe(Vector3.ZERO), 0.0))
	assert_null(source.contact(&"ship:Own", universe.to_universe(Vector3.ZERO), 0.0))
	near.free()
```

- [ ] **Step 2: Run it to see it fail**

Run: `./run_tests.ps1 '-gselect=test_weapons.gd'`
Expected: parse errors naming `Weapons`, `TargetContacts`.

- [ ] **Step 3: Write `weapons.gd`**

```gdscript
class_name Weapons
extends RefCounted

## What turrets may shoot (ship weapons spec §4): every target outside is in
## TARGETS, its id in meta ID. Ships, bases, NPCs outside and loose items in
## space join; you never do. Nothing here holds a node: fire control keeps ids
## and finds them again.

const TARGETS := &"weapon_targets"
const ID := &"target_id"
## An NPC is aimed at this far up its own body from its feet, m.
const NPC_CENTRE := 0.4

## Whether a node is hostile, for tests and the enemy project (spec §4.3):
## nothing is in this one.
static var hostile_rule: Callable

static func join(node: Node, id: StringName) -> void:
	node.set_meta(ID, id)
	if not node.is_in_group(TARGETS):
		node.add_to_group(TARGETS)

static func leave(node: Node) -> void:
	if node.is_in_group(TARGETS):
		node.remove_from_group(TARGETS)

static func id_of(node: Node) -> StringName:
	return node.get_meta(ID, &"") if node != null else &""

static func ship_id(ship: Node) -> StringName:
	return StringName("ship:%s" % ship.name)

static func base_id(site_id: StringName) -> StringName:
	return StringName("base:%s" % site_id)

static func npc_id(record_id: StringName) -> StringName:
	return StringName("npc:%s" % record_id)

## Good for the session only (spec §4.4).
static func item_id(item: Node) -> StringName:
	return StringName("item:%d" % item.get_instance_id())

## The part of an id before its colon: &"ship", &"base", &"npc", &"item".
static func kind_of(id: StringName) -> StringName:
	var s := String(id)
	var at := s.find(":")
	return StringName(s.substr(0, at)) if at > 0 else &""

## Whether `node` can be shot at now: alive, in the tree, a target, not dead,
## not a ship asleep.
static func usable(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree() or not node.is_in_group(TARGETS):
		return false
	if node is Npc and (node as Npc).is_dead():
		return false
	var ship := node.get_meta(&"ship", null) as Node
	if ship != null and ship.is_in_group(Fleet.ASLEEP):
		return false
	return true

## The target called `id`, or null when it is gone.
static func find(tree: SceneTree, id: StringName) -> Node3D:
	if tree == null or id == &"":
		return null
	for node in tree.get_nodes_in_group(TARGETS):
		if is_instance_valid(node) and id_of(node) == id and usable(node):
			return node as Node3D
	return null

## Where to aim at it, now: a hull's centre of mass, an NPC's middle.
static func point_of(node: Node3D) -> Vector3:
	var body := node as RigidBody3D
	if body != null and body.center_of_mass_mode == RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM:
		return body.global_transform * body.center_of_mass
	if node is Npc:
		return node.global_position + node.global_basis.y * NPC_CENTRE
	return node.global_position

static func velocity_of(node: Node3D) -> Vector3:
	if node is RigidBody3D:
		var body := node as RigidBody3D
		return Vector3.ZERO if body.freeze else body.linear_velocity
	if node is CharacterBody3D:
		return (node as CharacterBody3D).velocity
	return Vector3.ZERO

## What the HUD and the board call it.
static func label_of(node: Node) -> String:
	var ship := node.get_meta(&"ship", null) as Ship
	if ship != null:
		var given := ship.launch_blueprint.ship_name if ship.launch_blueprint != null else ""
		return (given if given != "" else String(ship.name)).to_upper()
	if node.has_meta(&"base"):
		return "BASE"
	if node is Npc and (node as Npc).species != null:
		return (node as Npc).species.display_name.to_upper()
	if node is Item and (node as Item).definition != null:
		return (node as Item).definition.display_name.to_upper()
	return String(id_of(node)).to_upper()

static func is_hostile(node: Node) -> bool:
	return hostile_rule.is_valid() and bool(hostile_rule.call(node))

## Whether `node` is `ship`'s own hull (spec §4.4): ships have no owner yet.
static func is_own(ship: Node, node: Node) -> bool:
	return ship != null and node != null and is_instance_valid(node) and node.get_meta(&"ship", null) == ship
```

- [ ] **Step 4: Write `target_contacts.gd`**

```gdscript
class_name TargetContacts
extends RefCounted

## Other ships and bases, for the ship's sensors (ship weapons spec §4.2): one
## exact contact each within WeaponValues.CONTACT_RANGE, kind &"ship" or
## &"base". Creatures are LifeContacts' life signs; loose items are left off,
## marked only by looking at them (§9.1). A sensor source: ShipSensors calls
## contacts() and contact().

const SHIP := &"ship"
const BASE := &"base"

var _own: Node
var _universe: Universe

## `own` is the ship's own hull, never its own contact.
func _init(own: Node, universe: Universe) -> void:
	_own = own
	_universe = universe

func contacts(focus: UniversePoint, range_m: float, time: float) -> Array[Contact]:
	var out: Array[Contact] = []
	if not _ready_to_look() or focus == null:
		return out
	var at := _universe.to_engine(focus)
	var reach := minf(range_m, WeaponValues.CONTACT_RANGE)
	for node in _own.get_tree().get_nodes_in_group(Weapons.TARGETS):
		var c := _contact_of(node as Node3D, at, reach, time)
		if c != null:
			out.append(c)
	return out

func contact(id: StringName, focus: UniversePoint, time: float) -> Contact:
	if not _ready_to_look() or focus == null:
		return null
	return _contact_of(Weapons.find(_own.get_tree(), id), _universe.to_engine(focus), WeaponValues.CONTACT_RANGE, time)

func _ready_to_look() -> bool:
	return _universe != null and is_instance_valid(_own) and _own.is_inside_tree()

func _contact_of(node: Node3D, at: Vector3, reach: float, time: float) -> Contact:
	if node == null or node == _own or not Weapons.usable(node):
		return null
	var kind := Weapons.kind_of(Weapons.id_of(node))
	if kind != SHIP and kind != BASE:
		return null
	var p := Weapons.point_of(node)
	if p.distance_to(at) > reach:
		return null
	var c := Contact.new()
	c.id = Weapons.id_of(node)
	c.kind = kind
	c.label = Weapons.label_of(node)
	c.point = _universe.to_universe(p)
	c.precision = Contact.EXACT
	c.taken = time
	c.fresh_for = ShipSensors.REFRESH_EVERY
	return c
```

- [ ] **Step 5: Who joins**

- `ship.gd`, at the end of `_rebuild_everything()`: `Weapons.join(exterior, Weapons.ship_id(self))` (the name is final by then; a rename between rebuilds is caught by the next).
- `base.gd`, in `_ready()` after `exterior.set_meta(&"base", self)`: `Weapons.join(exterior, Weapons.base_id(site.id))`.
- `npc_director.gd`: add after `var cameras`:

  ```gdscript
  ## Outside, its NPCs are targets (ship weapons spec §4.1); inside they never are.
  var targets := false
  ```

  In `promote()`, after `holder.add_child(npc)`: `if targets: Weapons.join(npc, Weapons.npc_id(record.id))`. In `demote()`, before the `get_parent().remove_child`: `Weapons.leave(npc)`.
- `item.gd`, in `set_space(outside)` after `in_space = outside`:

  ```gdscript
  	# Outside, a loose item is something a turret may break (ship weapons
  	# spec §4.1, §6.6); aboard it never is.
  	if outside:
  		Weapons.join(self, Weapons.item_id(self))
  	else:
  		Weapons.leave(self)
  ```

- [ ] **Step 6: Import, run the tests**

Run: `godot --headless --path . --import`, then `./run_tests.ps1 '-gselect=test_weapons.gd'`, `'-gselect=test_item.gd'`, `'-gselect=test_npc_director.gd'`, `'-gselect=test_base.gd'`.
Expected: `All tests passed` in each.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/combat/weapons.gd* who-knows/src/sensors/target_contacts.gd* who-knows/src/ship/ship.gd who-knows/src/habitat/base.gd who-knows/src/npc/npc_director.gd who-knows/src/items/item.gd who-knows/test/unit/test_weapons.gd*
git commit -m "feat: targets -- ships, bases, NPCs outside and items in space join Weapons.TARGETS; other ships become contacts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: `FireControl`

**Files:**
- Create: `who-knows/src/combat/fire_control.gd`
- Test: `who-knows/test/unit/test_fire_control.gd` (new)

**Interfaces:**
- Consumes: `Weapons` (Task 5), `WeaponValues` (Task 1).
- Produces: `FireControl` (`enum Orders { HOLD, ENGAGE }`, `orders`, `list: Array[StringName]`, `ship: Node`, `turrets: Array`, `entries: Array[Dictionary]` of `{id, node, label, distance, bearing}`, signal `changed`); `mark(id) -> bool`, `mark_nearest(from: Vector3, dir: Vector3, cone: float, reach: float) -> StringName`, `unmark(id)`, `clear()`, `set_orders(o)`, `toggle_orders()`, `rotate_list()`, `assign(elapsed)`, `tick(delta)`, `bearing(id) -> bool`, `pips() -> Array[StringName]`, `to_dict()`, `from_dict(d)`. A turret, to it, is anything with `can_engage(node) -> bool`, `muzzle() -> Vector3`, and fields `target: Node3D`, `no_arc: bool`, `state: StringName`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_fire_control.gd`:

```gdscript
extends GutTest

## FireControl (ship weapons spec §5.1): orders, a list of three in priority
## order, a target for each turret every 0.2 s -- the first it can engage,
## else the nearest hostile it can -- and entries that leave once gone.

class StubTurret extends Node3D:
	var target: Node3D
	var no_arc := false
	var state: StringName = &"idle"
	var reach: Array = []
	func can_engage(node: Node3D) -> bool:
		return reach.has(node)
	func muzzle() -> Vector3:
		return global_position

var _world: Node3D
var _fc: FireControl
var _ship: Node3D

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_ship = Node3D.new()
	_ship.name = "Own"
	_world.add_child(_ship)
	_fc = FireControl.new()
	_fc.ship = _ship
	_world.add_child(_fc)

func after_each():
	Weapons.hostile_rule = Callable()

func _target(id: StringName, at := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	_world.add_child(n)
	n.global_position = at
	Weapons.join(n, id)
	return n

func _turret(reach: Array) -> StubTurret:
	var t := StubTurret.new()
	t.reach = reach
	_world.add_child(t)
	_fc.turrets.append(t)
	return t

func test_hold_gives_nothing():
	var a := _target(&"ship:A")
	var t := _turret([a])
	_fc.mark(&"ship:A")
	_fc.assign(0.2)
	assert_null(t.target, "a new ship holds fire")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	assert_same(t.target, a)

func test_each_turret_takes_the_first_it_can_engage():
	var a := _target(&"ship:A")
	var b := _target(&"ship:B")
	var port := _turret([a, b])
	var starboard := _turret([b])
	_fc.mark(&"ship:A")
	_fc.mark(&"ship:B")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	assert_same(port.target, a, "#1 where it can")
	assert_same(starboard.target, b, "#2 where #1 is out of its arc")

func test_marking_orders_the_list():
	for id in [&"ship:A", &"ship:B", &"ship:C"]:
		_fc.mark(id)
	assert_eq(_fc.list, [&"ship:A", &"ship:B", &"ship:C"] as Array[StringName], "in the order marked")
	_fc.mark(&"ship:D")
	assert_eq(_fc.list, [&"ship:A", &"ship:B", &"ship:D"] as Array[StringName], "a fourth takes the last place")
	_fc.mark(&"ship:B")
	assert_eq(_fc.list, [&"ship:B", &"ship:A", &"ship:D"] as Array[StringName], "marked again, to the top")

func test_its_own_ship_is_never_marked_or_shot():
	assert_false(_fc.mark(Weapons.ship_id(_ship)))
	var hull := _target(Weapons.ship_id(_ship))
	hull.set_meta(&"ship", _ship)
	var t := _turret([hull])
	_fc.list.append(Weapons.ship_id(_ship))
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	assert_null(t.target)

func test_after_the_list_the_nearest_hostile():
	var near := _target(&"npc:a", Vector3(0, 0, -100))
	var far := _target(&"npc:b", Vector3(0, 0, -900))
	var t := _turret([near, far])
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	assert_null(t.target, "nothing is hostile")
	Weapons.hostile_rule = func(n: Node) -> bool: return n == near or n == far
	_fc.assign(0.2)
	assert_same(t.target, near)

func test_a_freed_target_is_dropped_without_error():
	var a := _target(&"ship:A")
	var b := _target(&"ship:B")
	var t := _turret([a, b])
	_fc.mark(&"ship:A")
	_fc.mark(&"ship:B")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	a.free()
	_fc.assign(0.2)
	assert_same(t.target, b, "straight on to the next")
	for i in 8:
		_fc.assign(0.2)
	assert_true(_fc.list.has(&"ship:A"), "kept through its grace")
	_fc.assign(0.4)
	assert_false(_fc.list.has(&"ship:A"), "gone for 2 s: dropped")

func test_no_arc_when_engaged_with_nothing_it_can_reach():
	_target(&"ship:A")
	var t := _turret([])
	_fc.mark(&"ship:A")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	assert_true(t.no_arc)

func test_mark_nearest_picks_inside_the_cone():
	_target(&"ship:Wide", Vector3(300, 0, -300))
	_target(&"ship:Ahead", Vector3(20, 0, -1000))
	assert_eq(_fc.mark_nearest(Vector3.ZERO, Vector3.FORWARD, WeaponValues.MARK_CONE, 5000.0), &"ship:Ahead")
	assert_eq(_fc.mark_nearest(Vector3.ZERO, Vector3.BACK, WeaponValues.MARK_CONE, 5000.0), &"")

func test_rotate_and_unmark():
	for id in [&"ship:A", &"ship:B", &"ship:C"]:
		_fc.mark(id)
	_fc.rotate_list()
	assert_eq(_fc.list, [&"ship:B", &"ship:C", &"ship:A"] as Array[StringName])
	_fc.unmark(&"ship:C")
	assert_eq(_fc.list, [&"ship:B", &"ship:A"] as Array[StringName])

func test_it_round_trips():
	_fc.mark(&"ship:A")
	_fc.mark(&"base:b1")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	var again := FireControl.new()
	again.from_dict(_fc.to_dict())
	assert_eq(again.orders, FireControl.Orders.ENGAGE)
	assert_eq(again.list, [&"ship:A", &"base:b1"] as Array[StringName])
	again.free()
```

- [ ] **Step 2: Run it to see it fail**

Run: `./run_tests.ps1 '-gselect=test_fire_control.gd'`
Expected: parse errors naming `FireControl`.

- [ ] **Step 3: Write `fire_control.gd`**

```gdscript
class_name FireControl
extends Node

## One ship's fire control (ship weapons spec §5.1): its orders, the targets
## you marked in priority order, and every ASSIGN_EVERY a target for each
## turret -- the first listed it can engage, else the nearest hostile it can,
## else none. The turrets aim and fire themselves. An enemy ship will drive one
## the same way, its list written by its AI. Saved with the ship.

signal changed

enum Orders { HOLD, ENGAGE }

var orders := Orders.HOLD
var list: Array[StringName] = []
## The ship it fires for: never a target of its own.
var ship: Node
## Its turrets: each has can_engage(node) -> bool, muzzle() -> Vector3, and
## `target`, `no_arc` and `state`.
var turrets: Array = []
## The list as last resolved, for the HUD and the board: {id, node, label,
## distance, bearing}, node null while it is not found.
var entries: Array[Dictionary] = []
var _missing := {}   # id -> seconds unseen
var _since := 0.0

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	_since += delta
	if _since >= WeaponValues.ASSIGN_EVERY:
		assign(_since)
		_since = 0.0

## Marks `id` (spec §5.1, §9.1): a new one at the end, or in the last place
## when the list is full; one already listed to the top. Its own hull is
## refused. True if it is listed now.
func mark(id: StringName) -> bool:
	if id == &"" or (ship != null and id == Weapons.ship_id(ship)):
		return false
	if list.has(id):
		list.erase(id)
		list.push_front(id)
	elif list.size() < WeaponValues.LIST_MOST:
		list.append(id)
	else:
		list[WeaponValues.LIST_MOST - 1] = id
	_missing.erase(id)
	changed.emit()
	return true

## Marks the target nearest the line from `from` along `dir`, within `cone`
## (radians) of it and `reach` metres (spec §9.1). Its id, or &"" for none.
func mark_nearest(from: Vector3, dir: Vector3, cone: float, reach: float) -> StringName:
	var best: StringName = &""
	var best_angle := cone
	if not is_inside_tree():
		return best
	for n in get_tree().get_nodes_in_group(Weapons.TARGETS):
		var node := n as Node3D
		if node == null or Weapons.is_own(ship, node) or not Weapons.usable(node):
			continue
		var to := Weapons.point_of(node) - from
		if to.length() > reach or to.length_squared() < 1e-6:
			continue
		var angle := dir.angle_to(to)
		if angle <= best_angle:
			best_angle = angle
			best = Weapons.id_of(node)
	if best != &"":
		mark(best)
	return best

func unmark(id: StringName) -> void:
	if list.has(id):
		list.erase(id)
		_missing.erase(id)
		changed.emit()

func clear() -> void:
	list.clear()
	_missing.clear()
	changed.emit()

func set_orders(o: Orders) -> void:
	orders = o
	changed.emit()

func toggle_orders() -> void:
	set_orders(Orders.HOLD if orders == Orders.ENGAGE else Orders.ENGAGE)

## The first entry to the back (Tab at the weapons station, spec §7.2).
func rotate_list() -> void:
	if list.size() > 1:
		list.append(list.pop_front())
		changed.emit()

## Resolves the list and gives each turret its target. `elapsed` is the time
## since the last call, for the grace of an entry that has gone.
func assign(elapsed: float) -> void:
	var tree := get_tree() if is_inside_tree() else null
	var listed: Array[Node3D] = []
	entries.clear()
	for id in list.duplicate():
		var node := Weapons.find(tree, id)
		if node == null:
			_missing[id] = float(_missing.get(id, 0.0)) + elapsed
			if _missing[id] >= WeaponValues.MISSING_GRACE - 0.0001:
				list.erase(id)
				_missing.erase(id)
				changed.emit()
			else:
				entries.append({"id": id, "node": null, "label": String(id).to_upper(), "distance": -1.0, "bearing": false})
			continue
		_missing.erase(id)
		if not Weapons.is_own(ship, node):
			listed.append(node)
		entries.append({"id": id, "node": node, "label": Weapons.label_of(node), "distance": _distance_to(node),
			"bearing": false})
	for t in turrets:
		if not is_instance_valid(t):
			continue
		t.target = null if orders == Orders.HOLD else _pick(t, listed, tree)
		t.no_arc = orders == Orders.ENGAGE and not listed.is_empty() and t.target == null
	for e in entries:
		e["bearing"] = e["node"] != null and _anyone_can(e["node"])

func bearing(id: StringName) -> bool:
	for e in entries:
		if e["id"] == id:
			return e["bearing"]
	return false

## Each turret's state, for the HUD's pips.
func pips() -> Array[StringName]:
	var out: Array[StringName] = []
	for t in turrets:
		if is_instance_valid(t):
			out.append(t.state)
	return out

func _pick(turret, listed: Array[Node3D], tree: SceneTree) -> Node3D:
	for node in listed:
		if turret.can_engage(node):
			return node
	if tree == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for n in tree.get_nodes_in_group(Weapons.TARGETS):
		var node := n as Node3D
		if node == null or Weapons.is_own(ship, node) or not Weapons.usable(node) or not Weapons.is_hostile(node):
			continue
		if not turret.can_engage(node):
			continue
		var d: float = (turret.muzzle() as Vector3).distance_to(Weapons.point_of(node))
		if d < best_d:
			best_d = d
			best = node
	return best

func _anyone_can(node: Node3D) -> bool:
	for t in turrets:
		if is_instance_valid(t) and t.can_engage(node):
			return true
	return false

func _distance_to(node: Node3D) -> float:
	var from := ship as Node3D
	var hull: Node3D = ship.get("exterior") if ship != null and "exterior" in ship else from
	return hull.global_position.distance_to(Weapons.point_of(node)) if hull != null and hull.is_inside_tree() else -1.0

func to_dict() -> Dictionary:
	var ids := []
	for id in list:
		ids.append(String(id))
	return {"orders": "engage" if orders == Orders.ENGAGE else "hold", "list": ids}

func from_dict(d: Dictionary) -> void:
	orders = Orders.ENGAGE if String(d.get("orders", "hold")) == "engage" else Orders.HOLD
	list.clear()
	_missing.clear()
	for id in d.get("list", []):
		if list.size() < WeaponValues.LIST_MOST:
			list.append(StringName(id))
	changed.emit()
```

- [ ] **Step 4: Import, run the test**

Run: `godot --headless --path . --import` then `./run_tests.ps1 '-gselect=test_fire_control.gd'`
Expected: `All tests passed`, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/combat/fire_control.gd* who-knows/test/unit/test_fire_control.gd*
git commit -m "feat: FireControl -- orders, a list of three, a target for each turret every 0.2 s

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: `Turret`, its look and its sound, built by the ship

**Files:**
- Create: `who-knows/src/combat/turret.gd`, `who-knows/src/combat/turret_look.gd`
- Modify: `who-knows/src/audio/synth.gd` (four sounds), `who-knows/src/combat/phaser_bolt.gd` (its crack), `who-knows/src/ship/ship.gd` (turrets, fire control, sky maps, saving, `listener_aboard`, a hit's thump), `who-knows/test/unit/test_visual_style_rules.gd`
- Test: `who-knows/test/unit/test_turret.gd`, `who-knows/test/unit/test_ship_turrets.gd` (new)

**Interfaces:**
- Consumes: `SkyMap` (Task 2), `BoltPool` (Task 3), `ShipDamage.turret_part` (Task 4), `Weapons` (Task 5), `FireControl` (Task 6).
- Produces: `Turret` (fields `kind`, `coord`, `normal`, `sky`, `hull: RigidBody3D`, `store: QuantumStore`, `stage_of: Callable`, `source: Node`, `target: Node3D`, `no_arc`, `manual`, `manual_aim: Vector3`, `yaw`, `elevation`, `state`; signal `fired(kind)`; `setup(kind, coord, normal, sky)`, `step(delta)`, `can_engage(node) -> bool`, `muzzle() -> Vector3`, `barrel_dir() -> Vector3`, `pull_trigger() -> bool`, `recharge_left() -> float`); `TurretLook.plinth/dome/barrels(kit, f, kind)`; `Ship.fire_control: FireControl`, `Ship.turrets: Array[Turret]`, `Ship.heavy_turrets() -> Array[Turret]`, `Ship.listener_aboard() -> bool`; save key `"weapons"`; Synth `&"phaser_thrum"`, `&"phaser_heavy"`, `&"phaser_whine"`, `&"phaser_crack"`; a phaser hit on the hull you are aboard is a thump through it.

- [ ] **Step 1: Write the failing turret test**

`who-knows/test/unit/test_turret.gd`:

```gdscript
extends GutTest

## Turret (ship weapons spec §5.3): it turns at its slew, leads its target,
## fires bursts only on target, in range, clear of its own hull and paid for,
## recharges, and suffers its damage.

var _world: Node3D
var _hull: RigidBody3D
var _store: QuantumStore
var _stage := BlockDamage.Stage.INTACT

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_world.add_child(BoltPool.new())
	_hull = RigidBody3D.new()
	_hull.gravity_scale = 0.0
	_hull.freeze = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	shape.shape = box
	_hull.add_child(shape)
	_world.add_child(_hull)
	_store = QuantumStore.new(1000, 1000)
	_stage = BlockDamage.Stage.INTACT

func _turret(kind := WeaponValues.LIGHT, layout: ShipGrid = null) -> Turret:
	var g := layout if layout != null else ShipGrid.new()
	if layout == null:
		var inst := BlockInstance.new()
		inst.block_id = kind
		g.set_block(Vector3i.ZERO, inst)
	var t := Turret.new()
	t.setup(kind, Vector3i.ZERO, Vector3i.UP, SkyMap.build(g, Vector3i.ZERO, Vector3i.UP))
	t.hull = _hull
	t.store = _store
	t.source = _hull
	t.stage_of = func() -> int: return _stage
	_hull.add_child(t)
	return t

func _target(at: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 6, 6)
	shape.shape = box
	b.add_child(shape)
	_world.add_child(b)
	b.global_position = at
	Weapons.join(b, &"ship:T")
	return b

func _count(t: Turret) -> Array:
	var shots := []
	t.fired.connect(func(_k: StringName) -> void: shots.append(1))
	return shots

func test_it_turns_at_its_slew():
	var t := _turret()
	t.target = _target(Vector3(300, 1.6, 0))
	await wait_physics_frames(15)
	var slew := deg_to_rad(90.0) * 0.25 + 0.02
	assert_lt(absf(t.yaw), slew, "no faster than 90 deg/s")
	assert_gt(t.yaw, 0.1, "toward the right")

func test_it_fires_a_burst_of_four_then_recharges():
	var t := _turret()
	t.yaw = 0.0
	t.elevation = 0.0
	t.target = _target(Vector3(0, 1.6, -300))
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_eq(shots.size(), 4, "one burst; the next waits for its recharge")
	assert_eq(_store.amount, 996, "1 QE a bolt")

func test_it_holds_fire_off_target():
	var t := _turret()
	t.yaw = PI
	t.target = _target(Vector3(0, 1.6, -300))
	var shots := _count(t)
	await wait_physics_frames(10)
	assert_eq(shots.size(), 0, "not within 1 deg yet")

func test_it_holds_fire_out_of_range():
	var t := _turret()
	t.target = _target(Vector3(0, 1.6, -2000))
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_eq(shots.size(), 0)
	assert_false(t.can_engage(t.target))

func test_a_burst_stops_at_the_low_power_line():
	var t := _turret()
	t.yaw = 0.0
	t.elevation = 0.0
	t.target = _target(Vector3(0, 1.6, -300))
	_store.amount = _store.line() + 1
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_lt(shots.size(), 4, "it stopped mid-burst")
	assert_gte(_store.amount, _store.line() - 1, "never past one bolt under the line")
	var after := shots.size()
	await wait_seconds(2.0)
	assert_eq(shots.size(), after, "nothing more in low power")

func test_never_fires_through_its_own_hull():
	var g := ShipGrid.new()
	for at: Vector3i in [Vector3i.ZERO, Vector3i(0, 1, -1), Vector3i(0, 2, -1)]:
		var inst := BlockInstance.new()
		inst.block_id = &"hull" if at != Vector3i.ZERO else WeaponValues.LIGHT
		g.set_block(at, inst)
	var t := _turret(WeaponValues.LIGHT, g)
	# The same cells as hull colliders, as a ship's exterior has them.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 4, 2)
	shape.shape = box
	shape.position = Vector3(0, 3, -2)
	_hull.add_child(shape)
	t.target = _target(Vector3(0, 1.6, -300))
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_eq(shots.size(), 0, "its own ship is in the way")

func test_damaged_it_slews_at_half_and_wrecked_it_is_silent():
	_stage = BlockDamage.Stage.DAMAGED
	var t := _turret()
	t.target = _target(Vector3(300, 1.6, 0))
	await wait_physics_frames(15)
	assert_lt(t.yaw, deg_to_rad(45.0) * 0.25 + 0.02)
	_stage = BlockDamage.Stage.WRECKED
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_eq(shots.size(), 0)
	assert_eq(t.state, &"wrecked")

func test_by_hand_the_trigger_fires_where_it_points():
	var t := _turret(WeaponValues.HEAVY)
	t.manual = true
	t.manual_aim = Vector3.FORWARD
	t.yaw = 0.0
	t.elevation = 0.0
	var shots := _count(t)
	assert_true(t.pull_trigger())
	await wait_physics_frames(2)
	assert_eq(shots.size(), 1)
	assert_eq(_store.amount, 1000 - 15)
	assert_false(t.pull_trigger(), "recharging")
	assert_gt(t.recharge_left(), 2.5)
```

- [ ] **Step 2: Write the failing ship test**

`who-knows/test/unit/test_ship_turrets.gd`:

```gdscript
extends GutTest

## A ship builds a Turret for every turret block and one FireControl (ship
## weapons spec §5.1), keeps them across rebuilds, and saves its orders.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func _armed() -> ShipGrid:
	var grid := ShipLibrary.read("res://data/ships/starter.json")["grid"] as ShipGrid
	var top := BlockInstance.new()
	top.block_id = WeaponValues.LIGHT
	grid.set_block(Vector3i(0, 2, 0), top)
	return grid

func test_a_turret_block_makes_a_turret():
	_ship.launch_blueprint = null
	_ship.set_grid(_armed())
	await wait_process_frames(2)
	assert_eq(_ship.turrets.size(), 1)
	var t: Turret = _ship.turrets[0]
	assert_eq(t.coord, Vector3i(0, 2, 0))
	assert_same(t.get_parent(), _ship.exterior, "on the hull, so the origin carries it")
	assert_eq(_ship.fire_control.turrets, _ship.turrets)
	assert_same(t.store, _ship.quantum.store)

func test_a_rebuild_keeps_the_same_turret():
	_ship.launch_blueprint = null
	_ship.set_grid(_armed())
	await wait_process_frames(2)
	var t: Turret = _ship.turrets[0]
	_ship._rebuild_everything()
	assert_same(_ship.turrets[0], t)

func test_hitting_it_hurts_the_turret():
	_ship.launch_blueprint = null
	_ship.set_grid(_armed())
	_ship.take_damage(Vector3i(0, 2, 0), 150.0)
	assert_eq(_ship.damage.component_stage(ShipDamage.turret_part(Vector3i(0, 2, 0))), BlockDamage.Stage.DAMAGED)

func test_the_orders_are_saved():
	_ship.fire_control.mark(&"ship:Ship2")
	_ship.fire_control.set_orders(FireControl.Orders.ENGAGE)
	var d := _ship.to_dict(_root.get_node("Universe"))
	assert_eq(d["weapons"]["orders"], "engage")
	_ship.fire_control.clear()
	_ship.restore_aboard(d)
	assert_eq(_ship.fire_control.list, [&"ship:Ship2"] as Array[StringName])
```

- [ ] **Step 3: Run them to see them fail**

Run: `./run_tests.ps1 '-gselect=test_turret.gd'` and `'-gselect=test_ship_turrets.gd'`
Expected: parse errors naming `Turret`; `fire_control` not found on `Ship`.

- [ ] **Step 4: Write `turret_look.gd`**

```gdscript
class_name TurretLook
extends RefCounted

## A turret's look (ship weapons spec §3.1; the style guide §3): chunky
## bevelled shapes in the hull's own colours, built from a kit and a frame
## alone. Three parts, each its own kit, because two of them turn: the plinth
## on the mount face, the dome that yaws, the barrels that pitch. Every frame
## has +y out of the mount face and -z the way the barrels point at rest; the
## dome's and the barrels' frames sit at the pivot, MUZZLE_UP off the face.

const SOLID := InteriorKit.Batch.SOLID
const HULL := InteriorKit.Batch.HULL
const GLOW := InteriorKit.Batch.GLOW

static func _plate() -> Color:
	return InteriorKit.solid(HullPalette.PLATE)

static func _trim() -> Color:
	return InteriorKit.solid(HullPalette.TRIM)

static func _dark() -> Color:
	return InteriorKit.solid(HullPalette.NOZZLE_DARK)

static func _big(kind: StringName) -> bool:
	return kind == WeaponValues.HEAVY

## The ring it turns on, on the face.
static func plinth(kit: InteriorKit, f: Transform3D, kind: StringName) -> void:
	var w := 1.8 if _big(kind) else 1.4
	kit.bevel_box(SOLID, f * InteriorKit.at(Vector3(0, 0.08, 0)), Vector3(w, 0.16, w), 0.05, _trim())
	kit.bevel_box(SOLID, f * InteriorKit.at(Vector3(0, 0.2, 0)), Vector3(w * 0.8, 0.1, w * 0.8), 0.03, _dark())

## The armoured dome, in the yawing frame (at the pivot).
static func dome(kit: InteriorKit, f: Transform3D, kind: StringName) -> void:
	var size := Vector3(1.5, 0.8, 1.7) if _big(kind) else Vector3(1.0, 0.55, 1.1)
	kit.bevel_box(HULL, f * InteriorKit.at(Vector3(0, -0.12, 0.1)), size, size.y * 0.3, _plate())
	kit.bevel_box(SOLID, f * InteriorKit.at(Vector3(0, -0.12 + size.y * 0.3, size.z * 0.5 + 0.05)),
		Vector3(size.x * 0.7, size.y * 0.35, 0.12), 0.03, _trim())

## The barrels, in the pitching frame: twin short ones, or one long one, each
## with a faint amber ring at its mouth.
static func barrels(kit: InteriorKit, f: Transform3D, kind: StringName) -> void:
	var length: float = WeaponValues.spec(kind)["barrel"]
	var xs: Array[float] = [0.0] if _big(kind) else [-0.16, 0.16]
	var r := 0.14 if _big(kind) else 0.07
	for x in xs:
		kit.tube_between(SOLID, f * Vector3(x, 0, 0), f * Vector3(x, 0, -length), r, _trim())
		kit.bevel_box(SOLID, f * InteriorKit.at(Vector3(x, 0, -length * 0.35)), Vector3(r * 3.0, r * 3.0, length * 0.25),
			r * 0.6, _dark())
		kit.bevel_box(GLOW, f * InteriorKit.at(Vector3(x, 0, -length - 0.02)), Vector3(r * 2.2, r * 2.2, 0.04), 0.01,
			InteriorKit.lit(SpacePalette.PHASER, 0.9))
```

If `InteriorKit.at` or `tube_between` differ from what is used here, follow `hull_props.gd`'s own use of them; the shape is what matters.

- [ ] **Step 5: Write `turret.gd`**

```gdscript
class_name Turret
extends Node3D

## One turret on a ship's hull (ship weapons spec §3, §5.3): it turns toward the
## target fire control gave it at its own slew, leads it (WeaponAim), and fires
## bursts while its barrel is on the solution, the shot is in range and clear
## of its own hull, and the store can pay above the low-power line. A heavy
## turret can be aimed by hand instead (`manual`, the weapons station). On the
## hull, so the floating origin carries it; its own look turns with it.

signal fired(kind: StringName)

var kind := WeaponValues.LIGHT
var coord := Vector3i.ZERO
var normal := Vector3i.UP
var sky: SkyMap
var hull: RigidBody3D
var store: QuantumStore
## () -> BlockDamage.Stage of this turret's component.
var stage_of: Callable
## Whose bolts these are: the ship.
var source: Node
## Set by fire control, or null.
var target: Node3D
## Engaged, with a list, and nothing on it this turret can reach.
var no_arc := false
## Aimed by hand (spec §7.2): it turns toward `manual_aim` (world) and fires
## only on pull_trigger().
var manual := false
var manual_aim := Vector3.FORWARD
## Mount-frame yaw (0 ahead, + to the right) and elevation, radians.
var yaw := 0.0
var elevation := WeaponValues.PARK_ELEVATION
## &"idle", &"tracking", &"firing", &"no_arc", &"damaged", &"low_power",
## &"wrecked": the HUD's pip and the board's word.
var state: StringName = &"idle"

var _spec: Dictionary
var _recharge := 0.0
var _burst_left := 0
var _gap := 0.0
var _solution := {}
var _yaw_node: Node3D
var _pitch_node: Node3D
var _rng := RandomNumberGenerator.new()
var _outside_sound: AudioStreamPlayer3D
var _inside_sound: AudioStreamPlayer

func setup(p_kind: StringName, p_coord: Vector3i, p_normal: Vector3i, p_sky: SkyMap) -> void:
	kind = p_kind
	coord = p_coord
	normal = p_normal
	sky = p_sky
	_spec = WeaponValues.spec(kind)
	name = "Turret_%d_%d_%d" % [coord.x, coord.y, coord.z]
	transform = Transform3D(SkyMap.mount_basis(normal), ShipGrid.cell_center(coord) + Vector3(normal) * WeaponValues.FACE_OUT)
	_rng.seed = hash(coord)
	_yaw_node = Node3D.new()
	_yaw_node.name = "Yaw"
	_yaw_node.position = Vector3(0, WeaponValues.MUZZLE_UP, 0)
	add_child(_yaw_node)
	_pitch_node = Node3D.new()
	_pitch_node.name = "Pitch"
	_yaw_node.add_child(_pitch_node)
	_look(self, Transform3D(Basis.IDENTITY, Vector3.ZERO), TurretLook.plinth)
	_look(_yaw_node, Transform3D.IDENTITY, TurretLook.dome)
	_look(_pitch_node, Transform3D.IDENTITY, TurretLook.barrels)
	_pose()

func _look(root: Node3D, f: Transform3D, part: Callable) -> void:
	var holder := Node3D.new()
	holder.name = "Look"
	root.add_child(holder)
	var kit := InteriorKit.new(holder)
	kit.layer = Item.SPACE_LAYER
	kit.light_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	kit.materials = {InteriorKit.Batch.HULL: HullMaterials.livery(), InteriorKit.Batch.SOLID: HullMaterials.trim(),
		InteriorKit.Batch.GLOW: HullMaterials.glow_instance(1.0)}
	part.call(kit, f, kind)
	kit.commit()

func _ready() -> void:
	_outside_sound = AudioStreamPlayer3D.new()
	_outside_sound.name = "Shot"
	_outside_sound.bus = AudioBuses.SUIT
	_outside_sound.max_distance = 200.0
	add_child(_outside_sound)
	_inside_sound = AudioStreamPlayer.new()
	_inside_sound.name = "ShotInside"
	_inside_sound.bus = AudioBuses.SHIP
	_inside_sound.volume_db = -14.0
	add_child(_inside_sound)

func _physics_process(delta: float) -> void:
	step(delta)

## The barrels' pivot, world.
func muzzle() -> Vector3:
	return to_global(Vector3(0, WeaponValues.MUZZLE_UP, 0))

## Where the barrels point now, world.
func barrel_dir() -> Vector3:
	return (global_basis * _mount_dir(yaw, elevation)).normalized()

func recharge_left() -> float:
	return _recharge

## Whether this turret could fire on `node` now: not wrecked, a solution in
## range, along a clear part of its sky.
func can_engage(node: Node3D) -> bool:
	if _stage() == BlockDamage.Stage.WRECKED or not Weapons.usable(node):
		return false
	var s := _solve(node)
	return not s.is_empty() and _reaches(s) and _sky_clear(s["dir"])

## The gunner's trigger (spec §7.2): one bolt (a burst for a light turret)
## where the barrels point, if recharged, paid for and at full power.
func pull_trigger() -> bool:
	if not manual or _recharge > 0.0 or _burst_left > 0 or not _can_pay():
		return false
	if _stage() == BlockDamage.Stage.WRECKED:
		return false
	_burst_left = int(_spec["burst"])
	_gap = 0.0
	return true

func step(delta: float) -> void:
	var stage := _stage()
	if stage == BlockDamage.Stage.WRECKED:
		state = &"wrecked"
		_burst_left = 0
		return
	var damaged := stage == BlockDamage.Stage.DAMAGED
	_solution = _solve(target) if target != null and not manual else {}
	var goal := Vector2(0.0, WeaponValues.PARK_ELEVATION)
	if manual:
		goal = _angles(manual_aim)
	elif not _solution.is_empty():
		goal = _angles(_solution["dir"])
	var rate := deg_to_rad(_spec["slew"]) * (WeaponValues.DAMAGED_SLEW if damaged else 1.0) * delta
	yaw = _toward_angle(yaw, goal.x, rate)
	elevation = move_toward(elevation, goal.y, rate)
	_pose()
	_recharge = maxf(_recharge - delta / (WeaponValues.DAMAGED_RECHARGE if damaged else 1.0), 0.0)
	if _burst_left == 0 and not manual and _recharge <= 0.0 and _ready_to_fire():
		_burst_left = int(_spec["burst"])
		_gap = 0.0
	if _burst_left > 0:
		_gap -= delta
		if _gap <= 0.0:
			if _can_pay() and (manual or _ready_to_fire()):
				_fire_one()
				_burst_left -= 1
				_gap = _spec["gap"]
			else:
				_burst_left = 0
			if _burst_left == 0:
				_recharge = _spec["recharge"]
	state = _state_now(damaged)

func _state_now(damaged: bool) -> StringName:
	if _burst_left > 0:
		return &"firing"
	if (target != null or manual) and store != null and store.is_low_power():
		return &"low_power"
	if target != null or manual:
		return &"tracking"
	if no_arc:
		return &"no_arc"
	return &"damaged" if damaged else &"idle"

func _stage() -> int:
	return stage_of.call() if stage_of.is_valid() else BlockDamage.Stage.INTACT

func _can_pay() -> bool:
	return store != null and not store.is_low_power() and store.can_spend(int(_spec["qe"]))

func _ready_to_fire() -> bool:
	if target == null or _solution.is_empty() or not _can_pay():
		return false
	if barrel_dir().angle_to(_solution["dir"]) > WeaponValues.AIM_TOLERANCE:
		return false
	return _reaches(_solution) and _sky_clear(_solution["dir"]) and _clear_of_hull()

func _solve(node: Node3D) -> Dictionary:
	if node == null or hull == null or not Weapons.usable(node):
		return {}
	return WeaponAim.intercept(muzzle(), hull.linear_velocity, _spec["speed"], Weapons.point_of(node),
		Weapons.velocity_of(node))

func _reaches(s: Dictionary) -> bool:
	return float(s["time"]) * float(_spec["speed"]) <= float(_spec["range"])

func _sky_clear(dir: Vector3) -> bool:
	return sky == null or hull == null or sky.can_bear(hull.global_basis.inverse() * dir)

## The ray every shot casts along its barrels against its own hull (spec §5.3):
## the sky map is coarse.
func _clear_of_hull() -> bool:
	if hull == null or not is_inside_tree():
		return true
	var from := muzzle()
	var query := PhysicsRayQueryParameters3D.create(from, from + barrel_dir() * WeaponValues.HULL_CHECK, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] != hull

func _fire_one() -> void:
	if not store.spend(int(_spec["qe"]), &"weapons"):
		_burst_left = 0
		return
	var dir := barrel_dir()
	var spread := deg_to_rad(_spec["spread"])
	if spread > 0.0:
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		dir = dir.rotated(side, _rng.randf() * spread).rotated(dir, _rng.randf() * TAU).normalized()
	var pool := BoltPool.find(get_tree())
	if pool != null:
		var ex: Array[RID] = [hull.get_rid()]
		pool.fire(kind, muzzle() + dir * float(_spec["barrel"]), dir, hull.linear_velocity, source, ex)
	_sound()
	fired.emit(kind)

func _sound() -> void:
	var s := Synth.sound(&"phaser_heavy" if kind == WeaponValues.HEAVY else &"phaser_thrum")
	if s == null:
		return
	var aboard: bool = source != null and source.has_method(&"listener_aboard") and source.listener_aboard()
	var player: Node = _inside_sound if aboard else _outside_sound
	if player == null or not player.is_inside_tree():
		return
	player.stream = s
	player.play()

## A world direction's mount-frame (yaw, elevation), elevation kept to the
## half-sky.
func _angles(dir_world: Vector3) -> Vector2:
	var a := SkyMap.angles(global_basis.inverse() * dir_world)
	return Vector2(a.x, clampf(a.y, 0.0, PI * 0.5))

static func _mount_dir(y: float, e: float) -> Vector3:
	return Vector3(sin(y) * cos(e), sin(e), -cos(y) * cos(e))

static func _toward_angle(from: float, to: float, step: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	return wrapf(from + clampf(diff, -step, step), -PI, PI)

func _pose() -> void:
	if _yaw_node != null:
		_yaw_node.rotation = Vector3(0, -yaw, 0)
		_pitch_node.rotation = Vector3(elevation, 0, 0)
```

- [ ] **Step 6: The sounds**

In `synth.gd`: add `&"phaser_thrum", &"phaser_heavy", &"phaser_whine", &"phaser_crack",` to `NAMES` (after `&"hose_gulp"`), four cases in `build()`, and:

```gdscript
## A light turret's bolt (ship weapons spec §9.3): a punchy falling thrum with a
## bright crack on its front.
static func _phaser_thrum() -> PackedFloat32Array:
	var n := _len(0.2)
	var crack := _highpass(_noise(n, 71), 1500.0)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(170.0, 70.0, minf(t / 0.12, 1.0)) / MIX_RATE
		x[i] = sin(phase) * exp(-t / 0.06) + crack[i] * exp(-t / 0.02) * 0.6
	return _gain(x, 0.7)

## The heavy turret's bolt: a deep whump.
static func _phaser_heavy() -> PackedFloat32Array:
	var n := _len(0.7)
	var rumble := _lowpass(_noise(n, 73), 300.0)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(95.0, 35.0, minf(t / 0.4, 1.0)) / MIX_RATE
		x[i] = sin(phase) * exp(-t / 0.22) + rumble[i] * exp(-t / 0.08) * 1.8
	return _gain(x, 0.9)

## The heavy turret recharging, at the weapons station: a soft rising whine.
static func _phaser_whine() -> PackedFloat32Array:
	var n := _len(3.0)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(300.0, 900.0, t / 3.0) / MIX_RATE
		x[i] = sin(phase) * _ramp(t, 0.1, 3.0, 0.3) * (0.8 + 0.2 * sin(TAU * 7.0 * t))
	return _gain(x, 0.25)

## A bolt landing, heard outside close by: a short sharp crack.
static func _phaser_crack() -> PackedFloat32Array:
	var n := _len(0.25)
	var crack := _highpass(_noise(n, 79), 900.0)
	var body := _lowpass(_noise(n, 83), 400.0)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		x[i] = crack[i] * exp(-t / 0.015) + body[i] * exp(-t / 0.07) * 1.5
	return _gain(x, 0.6)
```

A bolt's crack: in `phaser_bolt.gd`'s `_ready()`, an `AudioStreamPlayer3D` named `Crack` on `AudioBuses.SUIT` with `max_distance = 200.0`; in its `impact()` override, before `super(result)`, play `Synth.sound(&"phaser_crack")` on it when the sound is built (spec §9.3: outside, within 200 m). A hit on your own hull: in `ship.gd`'s `_on_hull_hit()`, after the damage, `if hit.kind == &"phaser": hull_struck(clampf(hit.damage / 4.0, 2.0, 8.0))` — the thump `hull_struck` already plays aboard only.

- [ ] **Step 7: The ship builds turrets and fire control**

In `ship.gd`:

```gdscript
## The ship's weapons (ship weapons spec §5): fire control, and a turret for
## every turret block, on the hull, kept across rebuilds by cell.
var fire_control: FireControl
var turrets: Array[Turret] = []
## Each turret's sky map, from the launch layout (spec §3.3): coord -> SkyMap.
var _skies := {}
```

In `_ready()`, after the warp block: 

```gdscript
	fire_control = FireControl.new()
	fire_control.name = "FireControl"
	fire_control.ship = self
	add_child(fire_control)
```

In `set_grid()`, after `damage = ShipDamage.build(...)` and `damage.infer(grid)`:

```gdscript
	_skies.clear()
	for coord: Vector3i in layout.coords():
		var inst := layout.get_block(coord)
		if WeaponValues.is_turret(inst.block_id):
			_skies[coord] = SkyMap.build(layout, coord, SkyMap.normal_of(inst.orientation))
```

In `_rebuild_everything()`, right after `quantum.bind(...)` and `flight_computer.quantum = quantum.store`: `_place_turrets()`, and:

```gdscript
## A Turret for each turret block (spec §3), on the hull: one kept from the
## last build by cell and kind, so a rebuild on every hit never resets an aim.
func _place_turrets() -> void:
	var kept := {}
	for t in turrets:
		if is_instance_valid(t):
			kept[t.coord] = t
	var placed: Array[Turret] = []
	var coords: Array = grid.coords()
	coords.sort()
	for coord: Vector3i in coords:
		var inst := grid.get_block(coord)
		if not WeaponValues.is_turret(inst.block_id):
			continue
		var n := SkyMap.normal_of(inst.orientation)
		var t: Turret = kept.get(coord)
		if t != null and t.kind == inst.block_id and t.normal == n:
			kept.erase(coord)
		else:
			t = Turret.new()
			t.setup(inst.block_id, coord, n, _skies.get(coord, SkyMap.build(grid, coord, n)))
			t.hull = exterior
			t.source = self
			var part := ShipDamage.turret_part(coord)
			t.stage_of = func() -> int:
				return damage.component_stage(part) if damage != null else BlockDamage.Stage.INTACT
			exterior.add_child(t)
		t.store = quantum.store
		placed.append(t)
	for t: Turret in kept.values():
		exterior.remove_child(t)
		t.free()
	turrets = placed
	fire_control.turrets = turrets

## The heavy turrets, bow first: the weapons station's guns (spec §7.2).
func heavy_turrets() -> Array[Turret]:
	var out: Array[Turret] = []
	for t in turrets:
		if t.kind == WeaponValues.HEAVY:
			out.append(t)
	return out

## Whether whoever listens is aboard: a turret's shot is a thud through the hull.
func listener_aboard() -> bool:
	return _aboard()
```

In `to_dict()` add `"weapons": fire_control.to_dict(),`; in `restore_aboard()` add `fire_control.from_dict(d.get("weapons", {}))`.

- [ ] **Step 8: Style rules**

In `test_visual_style_rules.gd`: add `"res://src/combat/turret.gd",` and `"res://src/combat/turret_look.gd",` to `PAINTING_FILES`, and `"res://src/combat/turret_look.gd",` to `REUSABLE_FILES`.

- [ ] **Step 9: Import, run the tests**

Run: `godot --headless --path . --import`, then `./run_tests.ps1` with `'-gselect=test_turret.gd'`, `'-gselect=test_ship_turrets.gd'`, `'-gselect=test_visual_style_rules.gd'`, `'-gselect=test_starter_ship.gd'`, `'-gselect=test_save_scene.gd'`.
Expected: `All tests passed` in each.

- [ ] **Step 10: Commit**

```bash
git add who-knows/src/combat who-knows/src/audio/synth.gd who-knows/src/ship/ship.gd who-knows/test/unit/test_turret.gd* who-knows/test/unit/test_ship_turrets.gd* who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: Turret -- it turns, leads, fires bursts on target and paid for; the ship builds one per turret block

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 8: The helm keys, the HUD, and the scene

**Files:**
- Modify: `who-knows/project.godot` (three actions), `who-knows/src/flight/pilot_controls.gd`, `who-knows/src/flight/flight_computer.gd` (`fire_control`, telemetry), `who-knows/src/ui/vehicle_telemetry.gd`, `who-knows/src/ui/hud_palette.gd`, `who-knows/src/ship/ship.gd` (`pilot.fire_control`), `who-knows/scenes/flight_test.gd`, `who-knows/test/unit/test_input_map.gd`, `who-knows/test/unit/test_floating_origin_scene.gd`
- Create: `who-knows/src/ui/weapons_strip.gd`, `who-knows/src/ui/target_brackets.gd`
- Test: `who-knows/test/unit/test_weapons_hud.gd`, `who-knows/test/unit/test_weapons_scene.gd` (new)

**Interfaces:**
- Consumes: `FireControl` (Task 6), `Turret` (Task 7), `TargetContacts` (Task 5), `BoltPool` (Task 3).
- Produces: actions `weapons_mark` (T), `weapons_clear` (Shift+T), `weapons_orders` (B); `PilotControls.fire_control`; telemetry `has_weapons`, `weapons_engage`, `weapons_pips: Array[StringName]`, `weapons_low_power`; `HudPalette.TARGET`, `HudPalette.HOSTILE`, `HudPalette.for_pip(state) -> Color`; `WeaponsStrip` (a `HudElement`); `TargetBrackets` (a `WorldMarker`, `fire_control`, `marks: Array[Dictionary]`); in the scene: `bolt_pool: BoltPool` under `Outside`, `target_brackets: Array[TargetBrackets]`, `weapons_strip: WeaponsStrip`.

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_weapons_hud.gd`:

```gdscript
extends GutTest

## The weapons on the HUD (ship weapons spec §9.2): the strip's orders and
## pips, and a numbered bracket on each listed target.

func _telemetry(engage: bool, pips: Array[StringName], low := false) -> VehicleTelemetry:
	var t := VehicleTelemetry.new()
	t.has_weapons = true
	t.weapons_engage = engage
	t.weapons_pips = pips
	t.weapons_low_power = low
	return t

func test_the_strip_shows_orders_and_a_pip_a_turret():
	var strip := WeaponsStrip.new()
	add_child_autofree(strip)
	strip.render(_telemetry(true, [&"firing", &"no_arc"] as Array[StringName]))
	assert_true(strip.visible)
	assert_eq(strip.orders_text(), "ENGAGE")
	assert_eq(strip.pip_colours(), [HudPalette.for_pip(&"firing"), HudPalette.for_pip(&"no_arc")])
	strip.render(_telemetry(true, [&"tracking"] as Array[StringName], true))
	assert_eq(strip.orders_text(), "WEAPONS · LOW POWER")

func test_no_turrets_no_strip():
	var strip := WeaponsStrip.new()
	add_child_autofree(strip)
	strip.render(VehicleTelemetry.new())
	assert_false(strip.visible)

func test_every_pip_state_has_a_colour():
	for s in [&"idle", &"tracking", &"firing", &"no_arc", &"damaged", &"low_power", &"wrecked"]:
		assert_true(HudPalette.for_pip(s) is Color)
```

`who-knows/test/unit/test_weapons_scene.gd`:

```gdscript
extends GutTest

## The weapons in the real flight scene (ship weapons spec §9): T marks the
## ship ahead, B engages, the brackets and the strip show it, bolts fly and
## follow the origin, and the list survives a save.

const PATH := "user://test_weapons_scene/game.json"

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func after_each():
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

func _arm_and_spawn(ahead := 400.0) -> Ship:
	var grid := ShipLibrary.read("res://data/ships/starter.json")["grid"] as ShipGrid
	var top := BlockInstance.new()
	top.block_id = WeaponValues.LIGHT
	grid.set_block(Vector3i(0, 2, 0), top)
	_ship.launch_blueprint = null
	_ship.set_grid(grid)
	var place := Transform3D(_ship.exterior.global_basis,
		_ship.exterior.global_position - _ship.exterior.global_basis.z * ahead + _ship.exterior.global_basis.y * 20.0)
	var other: Ship = _root.fleet.spawn(ShipLibrary.read("res://data/ships/starter.json")["grid"], place)
	return other

func _key(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	_ship.pilot.handle(e)

func test_t_marks_the_ship_ahead_and_b_engages():
	var other := _arm_and_spawn()
	await wait_physics_frames(3)
	_ship.pilot.seated = true
	_key(&"weapons_mark")
	assert_eq(_ship.fire_control.list, [Weapons.ship_id(other)] as Array[StringName])
	_key(&"weapons_orders")
	assert_eq(_ship.fire_control.orders, FireControl.Orders.ENGAGE)
	_key(&"weapons_clear")
	assert_eq(_ship.fire_control.list.size(), 0)

func test_the_turret_fires_on_a_marked_ship():
	var other := _arm_and_spawn()
	await wait_physics_frames(3)
	_ship.fire_control.mark(Weapons.ship_id(other))
	_ship.fire_control.set_orders(FireControl.Orders.ENGAGE)
	var before := _ship.quantum.store.amount
	await wait_seconds(4.0)
	assert_lt(_ship.quantum.store.amount, before, "it paid for bolts")
	var taken := 0.0
	for v in other.damage.section_damage.values():
		taken += v
	for v in other.damage.component_damage.values():
		taken += v
	assert_gt(taken, 0.0, "the other ship took some")

func test_bolts_shift_with_the_origin():
	var pool: BoltPool = _root.bolt_pool
	var ex: Array[RID] = []
	var bolt := pool.fire(WeaponValues.LIGHT, _ship.exterior.global_position + Vector3(0, 50, 0), Vector3.UP,
		Vector3.ZERO, null, ex)
	var at := bolt.global_position
	var universe: Universe = _root.get_node("Universe")
	universe.shift(Vector3(1000, 0, 0))
	assert_almost_eq(bolt.global_position, at - Vector3(1000, 0, 0), Vector3.ONE * 0.01)

func test_the_list_survives_a_save():
	_root.queue_free()
	await wait_process_frames(2)
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.save_enabled = true
	_root.save_path = PATH
	add_child_autofree(_root)
	await wait_process_frames(2)
	_ship = _root.get_node("Ship")
	var other := _arm_and_spawn()
	await wait_physics_frames(3)
	_ship.fire_control.mark(Weapons.ship_id(other))
	_ship.fire_control.mark(&"item:12345")
	_ship.fire_control.set_orders(FireControl.Orders.ENGAGE)
	assert_true(_root.save_now())
	var other_name := other.name
	_root.queue_free()
	await wait_process_frames(2)
	var again: Node = load("res://scenes/flight_test.tscn").instantiate()
	again.save_enabled = true
	again.save_path = PATH
	add_child_autofree(again)
	await wait_seconds(WeaponValues.MISSING_GRACE + 0.5)
	var ship: Ship = again.get_node("Ship")
	assert_eq(ship.fire_control.orders, FireControl.Orders.ENGAGE)
	assert_eq(ship.fire_control.list, [StringName("ship:%s" % other_name)] as Array[StringName], "the ship kept, the item gone")
```

In `test_input_map.gd`'s `REQUIRED_ACTIONS` add `&"weapons_mark", &"weapons_clear", &"weapons_orders",`.

In `test_floating_origin_scene.gd`, add:

```gdscript
func test_bolts_in_flight_are_covered():
	var pool: BoltPool = _root.bolt_pool
	var ex: Array[RID] = []
	pool.fire(WeaponValues.HEAVY, _ship.exterior.global_position + Vector3(0, 30, 0), Vector3.UP, Vector3.ZERO, null, ex)
	await wait_physics_frames(2)
	assert_eq(_uncovered(), [], "every bolt, its streak and its light move with the origin")
```

- [ ] **Step 2: Run them to see them fail**

Run: `./run_tests.ps1 '-gselect=test_weapons_hud.gd'` and `'-gselect=test_weapons_scene.gd'`
Expected: parse errors naming `WeaponsStrip`; `bolt_pool` not found.

- [ ] **Step 3: The actions**

In `project.godot` under `[input]`, after `warp={...}`, three entries in the same form as `warp`: `weapons_mark` with `"physical_keycode":84` (T); `weapons_clear` with `"shift_pressed":true` and `"physical_keycode":84`; `weapons_orders` with `"physical_keycode":66` (B).

- [ ] **Step 4: The palette and the telemetry**

`hud_palette.gd`, after `GO`:

```gdscript
## A marked target's bracket (ship weapons spec §9.2): a warm orange of its
## own, so it never reads as the course; and a hostile's, the hurt red.
const TARGET := Color("ff9a5a")
const HOSTILE := HURT

## A turret's pip on the weapons strip.
static func for_pip(state: StringName) -> Color:
	match state:
		&"firing":
			return TARGET
		&"tracking":
			return READOUT
		&"no_arc", &"idle":
			return DIM
		&"damaged", &"low_power":
			return WARNING
		&"wrecked":
			return HURT
	return DIM
```

`vehicle_telemetry.gd`, at the end of its fields:

```gdscript
## The ship's weapons (ship weapons spec §9.2): whether it has any, its
## orders, each turret's state, and whether low power holds them.
var has_weapons := false
var weapons_engage := false
var weapons_pips: Array[StringName] = []
var weapons_low_power := false
```

`flight_computer.gd`: `var fire_control: FireControl = null` beside `var warp`, and in `build_telemetry()` before `return t`:

```gdscript
	if fire_control != null and not fire_control.turrets.is_empty():
		t.has_weapons = true
		t.weapons_engage = fire_control.orders == FireControl.Orders.ENGAGE
		t.weapons_pips = fire_control.pips()
		t.weapons_low_power = t.weapons_engage and quantum != null and quantum.is_low_power()
```

`ship.gd` `_ready()`, after making `fire_control`: `flight_computer.fire_control = fire_control` and `pilot.fire_control = fire_control`.

- [ ] **Step 5: The helm keys**

`pilot_controls.gd`: `var fire_control: FireControl` beside `var lights`; in `handle()`, before `elif event.is_action_pressed(&"warp")`:

```gdscript
	elif event.is_action_pressed(&"weapons_clear", false, true):
		if fire_control != null:
			fire_control.clear()
	elif event.is_action_pressed(&"weapons_mark", false, true):
		# Along the nose: the crosshair (ship weapons spec §9.1).
		if fire_control != null:
			fire_control.mark_nearest(_hull.global_position, -_hull.global_basis.z, WeaponValues.MARK_CONE,
				WeaponValues.CONTACT_RANGE)
	elif event.is_action_pressed(&"weapons_orders"):
		if fire_control != null:
			fire_control.toggle_orders()
```

An `InputEventAction` in a test matches `is_action_pressed(action, false, true)`; if it does not, drop `exact_match` for the action-event case and keep it for key events.

- [ ] **Step 6: `weapons_strip.gd`**

```gdscript
class_name WeaponsStrip
extends HudElement

## The weapons on the console band (ship weapons spec §9.2): HOLD or ENGAGE,
## and a pip for each turret in its state's colour. Hidden on a ship with no
## turrets. Low power holding the guns reads WEAPONS · LOW POWER in WARNING.

const PIP := 8.0
const PIP_GAP := 4.0

var _label: Label
var _pips: Array[Color] = []

func _ready() -> void:
	custom_minimum_size = Vector2(150.0, 64.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", HudPalette.READOUT)
	_label.position = Vector2(0.0, 6.0)
	add_child(_label)

func render(telemetry: VehicleTelemetry) -> void:
	if telemetry == null or not telemetry.has_weapons:
		visible = false
		return
	visible = true
	if _label == null:
		_ready()
	if telemetry.weapons_low_power:
		_label.text = "WEAPONS · LOW POWER"
		_label.add_theme_color_override("font_color", HudPalette.WARNING)
	else:
		_label.text = "ENGAGE" if telemetry.weapons_engage else "HOLD"
		_label.add_theme_color_override("font_color", HudPalette.READOUT if telemetry.weapons_engage else HudPalette.DIM)
	_pips.clear()
	for s in telemetry.weapons_pips:
		_pips.append(HudPalette.for_pip(s))
	queue_redraw()

func orders_text() -> String:
	return _label.text if _label != null else ""

func pip_colours() -> Array[Color]:
	return _pips

func _draw() -> void:
	for i in _pips.size():
		draw_rect(Rect2(Vector2(i * (PIP + PIP_GAP), 34.0), Vector2(PIP, PIP)), _pips[i])
```

- [ ] **Step 7: `target_brackets.gd`**

```gdscript
class_name TargetBrackets
extends WorldMarker

## A numbered bracket on each target you marked (ship weapons spec §9.2), with
## its distance: dashed while no turret can bear, solid once one can; the
## hostile red for a hostile. Mounted per view, like every WorldMarker. Off
## screen or behind, it is not drawn: the board lists it.

const CORNER := 10.0
const HALF := 18.0
const LINE_WIDTH := 2.0
const LABEL_SIZE := 12

var fire_control: FireControl
## What was drawn this frame, for tests: {index, position, solid, hostile, text}.
var marks: Array[Dictionary] = []

func render(telemetry: VehicleTelemetry) -> void:
	marks.clear()
	var cam := view_camera(telemetry)
	if cam == null or fire_control == null:
		queue_redraw()
		return
	for i in fire_control.entries.size():
		var e: Dictionary = fire_control.entries[i]
		var node := e["node"] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var at := Weapons.point_of(node)
		if cam.is_position_behind(at):
			continue
		var d: float = e["distance"]
		marks.append({"index": i + 1, "position": cam.unproject_position(at), "solid": e["bearing"],
			"hostile": Weapons.is_hostile(node),
			"text": "%d · %s" % [i + 1, ("%.1f KM" % (d / 1000.0)) if d >= 1000.0 else ("%d M" % roundi(d))]})
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for m in marks:
		var colour: Color = HudPalette.HOSTILE if m["hostile"] else HudPalette.TARGET
		var c: Vector2 = m["position"]
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := c + Vector2(sx, sy) * HALF
				_edge(corner, corner - Vector2(sx, 0) * CORNER, colour, m["solid"])
				_edge(corner, corner - Vector2(0, sy) * CORNER, colour, m["solid"])
		draw_string(font, c + Vector2(-HALF, HALF + LABEL_SIZE + 2.0), m["text"], HORIZONTAL_ALIGNMENT_LEFT, -1,
			LABEL_SIZE, colour)

func _edge(a: Vector2, b: Vector2, colour: Color, solid: bool) -> void:
	if solid:
		draw_line(a, b, colour, LINE_WIDTH)
	else:
		draw_dashed_line(a, b, colour, LINE_WIDTH, 3.0)
```

- [ ] **Step 8: The scene**

In `flight_test.gd`:

```gdscript
## Every turret bolt (ship weapons spec §6.3), under Outside.
var bolt_pool: BoltPool
## The marked targets on the HUD, one per view (spec §9.2), and the weapons on the band.
var target_brackets: Array[TargetBrackets] = []
var weapons_strip: WeaponsStrip
```

Call `_wire_weapons()` in `_ready()` right after `_wire_warp()`:

```gdscript
## The weapons (ship weapons spec §5, §9): the bolt pool outside, the strip on
## the band, a bracket per view on the ship you are aboard; exterior NPCs are
## targets.
func _wire_weapons() -> void:
	bolt_pool = BoltPool.new()
	bolt_pool.name = "BoltPool"
	$Outside.add_child(bolt_pool)
	weapons_strip = WeaponsStrip.new()
	weapons_strip.name = "WeaponsStrip"
	$HudRoot/Screen/Band/Row.add_child(weapons_strip)
	target_brackets.clear()
	for m in _mount_per_view(func() -> WorldMarker: return TargetBrackets.new(), "Targets"):
		(m as TargetBrackets).fire_control = aboard.fire_control
		target_brackets.append(m)
	exterior_npcs.targets = true
```

In `_rebind_markers()`, add `target_brackets` to the list of groups reparented, and after the loops: `for m in target_brackets: m.fire_control = ship.fire_control`. In `_wire_ship()`, after the `BodyContacts` source: `ship.sensors.add_source(TargetContacts.new(ship.exterior, _universe))`. `_wire_npcs()` runs before `_wire_weapons()`, so `exterior_npcs` exists; set `exterior_npcs.targets = true` there instead if the order differs.

- [ ] **Step 9: Import, run the tests**

Run: `godot --headless --path . --import`, then `./run_tests.ps1` with `'-gselect=test_weapons_hud.gd'`, `'-gselect=test_weapons_scene.gd'`, `'-gselect=test_input_map.gd'`, `'-gselect=test_floating_origin_scene.gd'`, `'-gselect=test_hud_scene_wiring.gd'`, `'-gselect=test_pilot_controls.gd'`, `'-gselect=test_contact_text.gd'`.
Expected: `All tests passed` in each. `test_the_turret_fires_on_a_marked_ship` is loose by design (one turret, a still ship 400 m off): it asks only that some bolts landed.

- [ ] **Step 10: Commit**

```bash
git add who-knows/project.godot who-knows/src/flight who-knows/src/ui who-knows/src/ship/ship.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_weapons_hud.gd* who-knows/test/unit/test_weapons_scene.gd* who-knows/test/unit/test_input_map.gd who-knows/test/unit/test_floating_origin_scene.gd
git commit -m "feat: T marks, B engages; the weapons strip and numbered brackets; the bolt pool in the scene

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 9: The turret rules

**Files:**
- Modify: `who-knows/src/ship/ship_rules.gd`
- Test: `who-knows/test/unit/test_ship_rules.gd`

**Interfaces:**
- Consumes: `SkyMap` (Task 2), `WeaponValues` (Task 1).
- Produces: rule `TURRET_BURIED` (cell); note `TURRET_BLIND` (cell); note `TURRETS` (each turret's coverage).

- [ ] **Step 1: The failing tests**

Add to `test_ship_rules.gd` (it already builds ships from fixtures; use the starter):

```gdscript
func _starter_with(at: Vector3i, orientation: int, extra := {}) -> ShipGrid:
	var grid := ShipLibrary.read("res://data/ships/starter.json")["grid"] as ShipGrid
	var t := BlockInstance.new()
	t.block_id = WeaponValues.LIGHT
	t.orientation = orientation
	grid.set_block(at, t)
	for c: Vector3i in extra:
		var inst := BlockInstance.new()
		inst.block_id = extra[c]
		grid.set_block(c, inst)
	return grid

func _codes(found: Array) -> Array:
	return found.map(func(r: Dictionary) -> StringName: return r["code"])

func test_a_buried_turret_breaks_turret_buried():
	var found := ShipRules.check(_starter_with(Vector3i(0, 1, -3), 0, {Vector3i(0, 2, -3): &"hull"}),
		BlockCatalog.load_from_dir("res://data/blocks"))
	assert_true(_codes(found["rules"]).has(&"TURRET_BURIED"))

func test_an_open_turret_breaks_nothing_and_notes_its_sky():
	var found := ShipRules.check(_starter_with(Vector3i(0, 2, 0), 0), BlockCatalog.load_from_dir("res://data/blocks"))
	assert_false(_codes(found["rules"]).has(&"TURRET_BURIED"))
	assert_true(_codes(found["notes"]).has(&"TURRETS"))

func test_a_hemmed_in_turret_is_noted_blind():
	# A ring of hull two cells high round it: it sees only a disc of sky overhead.
	var walls := {}
	for y in [3, 4]:
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx != 0 or dz != 0:
					walls[Vector3i(dx, y, dz)] = &"hull"
	var found := ShipRules.check(_starter_with(Vector3i(0, 2, 0), 0, walls), BlockCatalog.load_from_dir("res://data/blocks"))
	assert_true(_codes(found["notes"]).has(&"TURRET_BLIND"))
```

The hemmed-in fixture may break other rules (balance, pieces); the test only reads its notes. From the muzzle at 5.6 m the ring's top at 9 m clears only above about 73°, under a quarter of the half-sky.

- [ ] **Step 2: Run to see them fail**

Run: `./run_tests.ps1 '-gselect=test_ship_rules.gd'`
Expected: the three new tests fail.

- [ ] **Step 3: The rules**

In `ship_rules.gd`'s `check()`, after `_check_pieces(grid, catalog, rules)`: `_check_turrets(grid, rules, notes)`, and:

```gdscript
## Turrets (ship weapons spec §8): each must stand on an open face, and one
## that sees under BLIND_BELOW of its half-sky is worth knowing.
static func _check_turrets(grid: ShipGrid, rules: Array, notes: Array) -> void:
	var seen: Array[String] = []
	var coords: Array = grid.coords()
	coords.sort()
	for coord: Vector3i in coords:
		var inst := grid.get_block(coord)
		if not WeaponValues.is_turret(inst.block_id):
			continue
		var n := SkyMap.normal_of(inst.orientation)
		if grid.has_block(coord + n):
			rules.append(item(&"TURRET_BURIED", "the %s at %s stands under %s: its mount face must open onto space"
				% [inst.block_id, coord, coord + n], coord))
			continue
		var cover := SkyMap.build(grid, coord, n).coverage()
		seen.append("%s %d%%" % [coord, roundi(cover * 100.0)])
		if cover < WeaponValues.BLIND_BELOW:
			notes.append(item(&"TURRET_BLIND", "the %s at %s sees %d%% of its half-sky: mount it where it can see"
				% [inst.block_id, coord, roundi(cover * 100.0)], coord))
	if not seen.is_empty():
		notes.append(item(&"TURRETS", "%d turrets, sky clear: %s" % [seen.size(), ", ".join(seen)]))
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.ps1 '-gselect=test_ship_rules.gd'` and `'-gselect=test_ship_catalog.gd'`
Expected: `All tests passed` in both.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship_rules.gd who-knows/test/unit/test_ship_rules.gd
git commit -m "feat: the turret rules -- TURRET_BURIED, and TURRET_BLIND and each turret's sky as notes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 10: The starter armed (Phase 1's done)

**Files:**
- Modify: `who-knows/data/ships/starter.json`, `who-knows/data/ships/starter.md`
- Test: `test_ship_catalog.gd`, `test_starter_ship.gd`, the ship check, the ship probe

**Interfaces:**
- Produces: the starter with `turret_light` at `(0, 2, 0)` orientation 0 (dorsal) and `(0, -1, 0)` orientation 2 (ventral), in place of the fairing halves there.

- [ ] **Step 1: The blueprint**

In `starter.json`, `[0, 2, 0, "fairing_half", 0]` becomes `[0, 2, 0, "turret_light", 0]` and `[0, -1, 0, "fairing_half", 2]` becomes `[0, -1, 0, "turret_light", 2]`.

- [ ] **Step 2: The check**

Run: `godot --headless --path who-knows --script D:/git/whoknows-weapons/.claude/skills/building-a-ship/ship_check.gd -- res://data/ships/starter.json`
Expected: `rules   0 broken`, a `TURRETS` note with both above 50%, no `TURRET_BLIND`. A `POWER_MARGIN`, `UNBALANCED` or `NO_PIECES` here means a turret moved the margins: move the ventral turret one cell along z and check again; record what moved in `starter.md`.

- [ ] **Step 3: The tests that pin the starter**

Run: `./run_tests.ps1` with `'-gselect=test_starter_ship.gd'`, `'-gselect=test_ship_catalog.gd'`, `'-gselect=test_exterior_builder.gd'`, `'-gselect=test_hull_layout.gd'`, `'-gselect=test_crash_feel.gd'`.
Expected: all pass. A test that counts the starter's blocks by id (fairing halves) is updated to the new count, with a comment pointing at the weapons spec §13.

- [ ] **Step 4: See it**

Run (windowed): `godot --path who-knows --resolution 1280x720 --script D:/git/whoknows-weapons/.claude/skills/building-a-ship/ship_probe.gd -- D:/git/whoknows-weapons/renders/weapons`
Then, in the game (`play.bat` from the worktree), F6 a second starter ahead, T, B, and watch. Take a screenshot of bursts and trails at eye height from the cockpit and show the owner before Phase 2, with the amber of `SpacePalette.PHASER` called out: the owner judges the colour first (spec §6.2).

- [ ] **Step 5: The note**

In `starter.md`, a short section *Weapons*: two light turrets, dorsal and ventral on the centre line, where the fairing halves were; each one's sky coverage from the `TURRETS` note; mass and power as the check printed them.

- [ ] **Step 6: Commit**

```bash
git add who-knows/data/ships/starter.json who-knows/data/ships/starter.md
git commit -m "feat: the starter carries two light turrets, dorsal and ventral

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Phase 2: items and bases

### Task 11: Items break

**Files:**
- Modify: `who-knows/src/items/item_definition.gd`, `who-knows/src/items/item.gd`, `who-knows/data/items/plasma_pistol.tres`, `repair_torch.tres`, `datapad.tres`, `hub_package.tres`, `drill_package.tres`, `store_package.tres`
- Test: `who-knows/test/unit/test_item_break.gd` (new)

**Interfaces:**
- Produces: `ItemDefinition.hp: float = 40.0`, `ItemDefinition.unbreakable: bool`; `Item.damage_taken: float`, `Item.receive_hit(hit)`, `Item.breaks() -> bool`, signal-free break via `Item.consume(self)`; save key `"hurt"`.

- [ ] **Step 1: The failing test**

`who-knows/test/unit/test_item_break.gd`:

```gdscript
extends GutTest

## Items break (ship weapons spec §6.6): enough hits and a loose item bursts
## and is gone, through Item.consume, so the salvage ledger and the strays let
## it go; tools and packages never break; what it took is saved.

var _world: Node3D

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)

func _item(unbreakable := false) -> Item:
	var d := ItemDefinition.new()
	d.id = &"crate"
	d.display_name = "Crate"
	d.size = Vector3(0.5, 0.5, 0.5)
	d.look = &"crate"
	d.unbreakable = unbreakable
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.set_loose()
	return item

func _hit(amount: float) -> Hit:
	var h := Hit.make(Vector3.ZERO, Vector3.UP, Vector3.DOWN, Vector3.ZERO, null)
	h.damage = amount
	return h

func test_three_light_bolts_break_a_crate():
	var item := _item()
	var gone := []
	item.consumed.connect(func() -> void: gone.append(1))
	item.receive_hit(_hit(15.0))
	item.receive_hit(_hit(15.0))
	assert_true(is_instance_valid(item))
	item.receive_hit(_hit(15.0))
	assert_eq(gone.size(), 1, "consumed: the ledger and the strays let it go")
	assert_false(is_instance_valid(item))

func test_an_unbreakable_item_takes_nothing():
	var item := _item(true)
	for i in 10:
		item.receive_hit(_hit(50.0))
	assert_true(is_instance_valid(item))
	assert_eq(item.damage_taken, 0.0)

func test_a_stowed_item_takes_nothing():
	var item := _item()
	item.set_stowed(null)
	item.receive_hit(_hit(100.0))
	assert_true(is_instance_valid(item))

func test_the_tools_and_packages_are_unbreakable():
	var cat := ItemCatalog.load_from_dir("res://data/items")
	for id in [&"plasma_pistol", &"repair_torch", &"datapad", &"hose_nozzle", &"hub_package", &"drill_package",
			&"store_package"]:
		var def := cat.get_def(id)
		assert_true(def != null and (def.unbreakable or def.eva_tool), "%s never breaks" % id)
	assert_almost_eq(cat.get_def(&"crate").hp, 40.0, 0.001)

func test_what_it_took_is_saved():
	var cat := ItemCatalog.load_from_dir("res://data/items")
	var item := Item.new()
	item.setup(cat.get_def(&"crate"))
	_world.add_child(item)
	item.set_loose()
	item.receive_hit(_hit(15.0))
	var d := item.to_dict(Transform3D.IDENTITY)
	assert_almost_eq(float(d["hurt"]), 15.0, 0.001)
	var again := Item.from_dict(d, cat)
	assert_almost_eq(again.damage_taken, 15.0, 0.001)
	again.free()
```

- [ ] **Step 2: Run to see it fail**

Run: `./run_tests.ps1 '-gselect=test_item_break.gd'`
Expected: failures: no `unbreakable`, no `receive_hit`.

- [ ] **Step 3: The code**

`item_definition.gd`, after `eva_cargo`:

```gdscript
## How much it takes before it breaks, hp (ship weapons spec §6.6): three light
## bolts or four pistol bolts for most things.
@export var hp: float = 40.0
## Never breaks: the tools and the module packages.
@export var unbreakable: bool = false
```

`item.gd`: `var damage_taken := 0.0` beside `var in_space`; and:

```gdscript
## A bolt or a bite (ship weapons spec §6.6): a loose item takes it, and at its
## hp it bursts and is gone through consume(), so the salvage ledger strikes it
## off and the strays forget it. Stowed and held items, tools and packages
## never break.
func receive_hit(hit: Hit) -> void:
	if hit == null or hit.damage <= 0.0 or not breaks() or state != State.LOOSE:
		return
	damage_taken += hit.damage
	if damage_taken >= definition.hp:
		var parent := get_parent()
		if parent != null:
			ImpactFlash.spawn(parent, global_position, Vector3.UP, ImpactFlash.Kind.IMPACT, in_space, 2.5)
		Item.consume(self)

func breaks() -> bool:
	return definition != null and not definition.unbreakable and not definition.eva_tool
```

In `to_dict()`, before `return d`: `if damage_taken > 0.0: d["hurt"] = damage_taken`. In `from_dict()`, after `item.setup(...)`: `item.damage_taken = float(d.get("hurt", 0.0))`.

The six `.tres` files each get `unbreakable = true` as a new line inside their `[resource]` block, beside their other properties, with no comment near it.

- [ ] **Step 4: Run the tests**

Run: `./run_tests.ps1` with `'-gselect=test_item_break.gd'`, `'-gselect=test_item.gd'`, `'-gselect=test_item_catalog.gd'`, `'-gselect=test_plasma_bolt.gd'`, `'-gselect=test_salvage_field.gd'`.
Expected: all pass. `test_plasma_bolt.gd`'s push tests hit a mug of 1 kg with 10 hp: it survives (40 hp).

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/items who-knows/data/items who-knows/test/unit/test_item_break.gd*
git commit -m "feat: loose items break under fire; tools and packages never do

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 12: Base modules hurt, show it, and stop

**Files:**
- Create: `who-knows/src/habitat/module_damage.gd`
- Modify: `who-knows/src/habitat/base_site.gd` (`damage` per module), `who-knows/src/habitat/base.gd`, `who-knows/src/habitat/base_exterior.gd` (`tints`), `who-knows/src/habitat/link_panel.gd` (`offline`), `who-knows/test/unit/test_visual_style_rules.gd` (painting file)
- Test: `who-knows/test/unit/test_module_damage.gd`, `who-knows/test/unit/test_base_damage.gd` (new)

**Interfaces:**
- Produces: `ModuleDamage.hp(site, index, catalog) -> float`, `stage(site, index, catalog) -> int`, `hit(site, index, amount, catalog) -> bool` (stage changed), `repair(site, index, share, catalog) -> float` (share used), `part(index) -> StringName` (`&"module:i"`), `index_of(part) -> int`, `label(site, index) -> String`, `wrecked(site, kind, catalog) -> Array[int]`; `Base.part_hit(collider, shape, at, normal) -> Dictionary` (`{part, cell, outside: true}` or `{}`), `Base.repair_section(part, share) -> float`, `Base.part_label(part) -> String`, `Base.is_section(part) -> bool`, `Base.module_stage(index) -> int`; `BaseExterior.build(site, windows, openings, tints := [])`; `LinkPanel.offline: bool`.

- [ ] **Step 1: The failing tests**

`who-knows/test/unit/test_module_damage.gd`:

```gdscript
extends GutTest

## ModuleDamage (ship weapons spec §6.5): each module of a base is a section of
## its own, its hp its blocks', its stage scorched then charred, mended by share.

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func _site() -> BaseSite:
	var s := BaseSite.new()
	s.add(ModuleCatalog.HUB, Vector3i.ZERO, 0, PackedFloat32Array([1, 1, 1, 1]))
	s.add(ModuleCatalog.DRILL, Vector3i(3, 0, 0), 0, PackedFloat32Array([1, 1, 1, 1]))
	return s

func test_a_module_has_its_blocks_hp():
	var s := _site()
	var total := 0.0
	for b: Array in ModuleCatalog.get_def(ModuleCatalog.DRILL).turned(0):
		total += _cat.get_def(b[1]).hp
	assert_almost_eq(ModuleDamage.hp(s, 1, _cat), total, 0.001)

func test_hits_stage_it_and_repair_mends_it():
	var s := _site()
	var hp := ModuleDamage.hp(s, 1, _cat)
	assert_false(ModuleDamage.hit(s, 1, hp * 0.3, _cat), "still intact")
	assert_true(ModuleDamage.hit(s, 1, hp * 0.3, _cat), "damaged now")
	assert_eq(ModuleDamage.stage(s, 1, _cat), BlockDamage.Stage.DAMAGED)
	ModuleDamage.hit(s, 1, hp, _cat)
	assert_eq(ModuleDamage.stage(s, 1, _cat), BlockDamage.Stage.WRECKED)
	assert_eq(ModuleDamage.wrecked(s, ModuleCatalog.DRILL, _cat), [1] as Array[int])
	ModuleDamage.repair(s, 1, 1.0, _cat)
	assert_eq(ModuleDamage.stage(s, 1, _cat), BlockDamage.Stage.INTACT)
	assert_eq(ModuleDamage.stage(s, 0, _cat), BlockDamage.Stage.INTACT, "the hub took nothing")

func test_parts_and_labels():
	var s := _site()
	assert_eq(ModuleDamage.part(1), &"module:1")
	assert_eq(ModuleDamage.index_of(&"module:1"), 1)
	assert_eq(ModuleDamage.index_of(&"port_bow"), -1)
	assert_eq(ModuleDamage.label(s, 1), "DRILL 1")

func test_the_site_saves_it():
	var s := _site()
	ModuleDamage.hit(s, 1, 50.0, _cat)
	var again := BaseSite.from_dict(s.to_dict())
	assert_almost_eq(float(again.modules[1]["damage"]), 50.0, 0.001)
```

`who-knows/test/unit/test_base_damage.gd` (its setup is `test_base_drill.gd`'s, a hub on flat ground with a drill and a store planted beside it):

```gdscript
extends GutTest

## A base under fire (ship weapons spec §6.5): a hit finds its module, a
## wrecked drill earns nothing, a wrecked hub's machine and panel go dark, a
## wrecked store's tanks leave the capacity, and the torch mends a module.

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
		return &"rock:fire"
	func ore() -> Dictionary:
		return {"seed": 5, "veined": false}

var _root: Node
var _clock := 0.0
var _base: Base
var _ground: Ground
var _drill := -1
var _store := -1

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
	_drill = _plant(ModuleCatalog.DRILL, Vector3(10, -2, 0))
	_store = _plant(ModuleCatalog.STORE, Vector3(-6, -2, 0))

func _plant(kind: StringName, local: Vector3) -> int:
	var frame: Transform3D = _root.bases.frame_of(_base.site)
	var r := Planting.fit(_ground, ModuleCatalog.get_def(kind), frame * local, Vector3.FORWARD, 0, _base.site, frame)
	assert_eq(r.fit, Planting.Fit.OK)
	_root.bases.plant(kind, r, _ground)
	_base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	return _base.site.modules.size() - 1

func _wreck(index: int) -> void:
	_base.site.modules[index]["damage"] = ModuleDamage.hp(_base.site, index, _base.catalog)
	_base.rebuild()

func test_a_hit_on_the_drill_hurts_the_drill():
	var cell: Vector3i = _base.site.cells_of(_drill)[0]
	var hit := Hit.make(_base.exterior.to_global(ShipGrid.cell_center(cell)), Vector3.UP, Vector3.DOWN, Vector3.ZERO, null)
	hit.damage = 50.0
	_base._on_hull_hit(hit)
	assert_almost_eq(float(_base.site.modules[_drill]["damage"]), 50.0, 0.001)
	assert_almost_eq(float(_base.site.modules[0]["damage"]), 0.0, 0.001, "the hub took none")

func test_a_wrecked_drill_earns_nothing():
	_wreck(_drill)
	var before := _base.quantum.store.amount
	_clock += 600.0
	assert_eq(_base.credit_drills(), 0)
	assert_eq(_base.quantum.store.amount, before)

func test_mended_it_earns_again():
	_wreck(_drill)
	_base.repair_section(ModuleDamage.part(_drill), 1.0)
	_clock += 600.0
	assert_gt(_base.credit_drills(), 0)

func test_a_wrecked_hub_unbinds_its_machine_and_darkens_its_panel():
	_wreck(0)
	assert_eq(_base.quantum.machines.size(), 0)
	assert_true(_base.link.offline)

func test_a_wrecked_store_leaves_the_capacity():
	var whole := _base.quantum.store.capacity
	_wreck(_store)
	assert_eq(_base.quantum.store.capacity, whole - HabitatValues.STORE_ADDS)

func test_the_torch_finds_the_module():
	var cell: Vector3i = _base.site.cells_of(_drill)[0]
	var on := _base.part_hit(_base.exterior, -1, _base.exterior.to_global(ShipGrid.cell_center(cell)), Vector3.UP)
	assert_eq(on.get("part"), ModuleDamage.part(_drill))
	assert_true(_base.is_section(ModuleDamage.part(_drill)))
	assert_string_starts_with(_base.part_label(ModuleDamage.part(_drill)), "DRILL 1")

func test_the_damage_survives_sleep():
	_base.site.modules[_drill]["damage"] = 40.0
	var again := BaseSite.from_dict(_base.site.to_dict())
	assert_almost_eq(float(again.modules[_drill]["damage"]), 40.0, 0.001)
```

- [ ] **Step 2: Run to see them fail**

Run: `./run_tests.ps1 '-gselect=test_module_damage.gd'` and `'-gselect=test_base_damage.gd'`
Expected: parse errors naming `ModuleDamage`.

- [ ] **Step 3: Write `module_damage.gd`**

```gdscript
class_name ModuleDamage
extends RefCounted

## A base's damage (ship weapons spec §6.5): each module is a section of its
## own, its hp the sum of its blocks', its damage a number in its site entry
## ("damage"), so it sleeps and saves with the base. Pure. A wrecked module
## stops working until it is mended above wrecked; nothing breaks off.

static func part(index: int) -> StringName:
	return StringName("module:%d" % index)

static func index_of(p: StringName) -> int:
	var s := String(p)
	return s.substr(7).to_int() if s.begins_with("module:") else -1

static func hp(site: BaseSite, index: int, catalog: BlockCatalog) -> float:
	var total := 0.0
	var m: Dictionary = site.modules[index]
	for b: Array in ModuleCatalog.get_def(m["kind"]).turned(m["turns"]):
		var def := catalog.get_def(b[1])
		total += float(def.hp) if def != null else 0.0
	return total

static func taken(site: BaseSite, index: int) -> float:
	return float(site.modules[index].get("damage", 0.0))

static func stage(site: BaseSite, index: int, catalog: BlockCatalog) -> int:
	return BlockDamage.stage_at(taken(site, index), hp(site, index, catalog))

## Deals `amount`; true if the module's stage changed.
static func hit(site: BaseSite, index: int, amount: float, catalog: BlockCatalog) -> bool:
	if amount <= 0.0 or index < 0 or index >= site.modules.size():
		return false
	var before := stage(site, index, catalog)
	site.modules[index]["damage"] = minf(taken(site, index) + amount, hp(site, index, catalog))
	return stage(site, index, catalog) != before

## Mends `share` (0..1) of its hp; returns the share used.
static func repair(site: BaseSite, index: int, share: float, catalog: BlockCatalog) -> float:
	var total := hp(site, index, catalog)
	if total <= 0.0 or share <= 0.0:
		return 0.0
	var used := minf(share * total, taken(site, index))
	site.modules[index]["damage"] = taken(site, index) - used
	return used / total

## "DRILL 2": its kind and its number among its kind.
static func label(site: BaseSite, index: int) -> String:
	var kind: StringName = site.modules[index]["kind"]
	var n := 0
	for i in index + 1:
		if site.modules[i]["kind"] == kind:
			n += 1
	return "%s %d" % [ModuleCatalog.get_def(kind).display_name.to_upper(), n]

## The wrecked modules of `kind`.
static func wrecked(site: BaseSite, kind: StringName, catalog: BlockCatalog) -> Array[int]:
	var out: Array[int] = []
	for i in site.modules.size():
		if site.modules[i]["kind"] == kind and stage(site, i, catalog) == BlockDamage.Stage.WRECKED:
			out.append(i)
	return out
```

If `ModuleDefinition` has no `display_name`, use its name field as `test_module_catalog.gd` shows (`"Hub"`, `"Drill"`, `"Store"` are passed to its constructor).

- [ ] **Step 4: The site saves it**

`base_site.gd`: `add()` puts `"damage": 0.0` in the new entry; `to_dict()` writes `"damage": float(m.get("damage", 0.0))` per module; `from_dict()` reads `"damage": float(m.get("damage", 0.0))`.

- [ ] **Step 5: The base**

`base.gd`:

- `_ready()`: after `exterior.set_meta(&"base", self)`, `exterior.set_meta(&"receive_hit", _on_hull_hit)`; make a `DamageShow` as the ship does (`damage_show = DamageShow.new()`, named, under `exterior`, `setup(exterior, outside)`).
- `var damage_show: DamageShow` with the other vars.
- In `rebuild()`, after `var stats := ShipStats.compute(grid, catalog)`:

```gdscript
	# Wrecked modules stop (ship weapons spec §6.5): a store's tanks leave the
	# capacity, a hub's machine is unbound, a drill stops (credit_drills).
	var lost := 0
	for i in ModuleDamage.wrecked(site, ModuleCatalog.STORE, catalog):
		for b: Array in ModuleCatalog.get_def(ModuleCatalog.STORE).turned(site.modules[i]["turns"]):
			var def := catalog.get_def(b[1])
			lost += def.quantum_capacity if def != null else 0
	stats.quantum_capacity = maxi(stats.quantum_capacity - lost, 0)
	stats.intact_quantum_capacity = maxi(stats.intact_quantum_capacity - lost, 0)
	var hub_down := not ModuleDamage.wrecked(site, ModuleCatalog.HUB, catalog).is_empty()
	var machines: Array[QuantumMachine] = [] if hub_down else interior_builder.quantum_machines()
	quantum.bind(interior_builder.quantum_cores(), machines, stats)
```

  replacing the existing `quantum.bind(...)` line. Then the shell's tints: build `tints` with one `ExteriorBuilder.stage_colour(ModuleDamage.stage(site, i, catalog))` for each module index `i` that is not `unfolding`, in order, and pass it: `exterior_look.build(shown, windows, openings, tints)`. After `_place_link(shown)`: `if link != null: link.offline = hub_down`. Then the sparks: for each module `i` (not unfolding) with damage, write `inst.damage = def.hp * minf(ModuleDamage.taken(site, i) / ModuleDamage.hp(site, i, catalog), ShipDamage.SHOWN_MOST / BlockDamage.GONE_AT)` into each of its blocks in `grid` (the shown grid, rebuilt every time), then `damage_show.sync(grid, catalog)`.
- `credit_drills()`: skip `i` when `ModuleDamage.stage(site, i, catalog) == BlockDamage.Stage.WRECKED`; `hum()` the same.
- New functions:

```gdscript
## A hit on the base's shell (ship weapons spec §6.5): its cell, then its
## module. A stage crossed rebuilds it, which is what stops or restarts it.
func _on_hull_hit(hit: Hit) -> void:
	var at := exterior.to_local(hit.position)
	var cell := ShipCells.hull_cell(grid, exterior, hit.shape, at, exterior.global_basis.inverse() * hit.normal)
	var index: int = site.occupied().get(cell, -1)
	if index < 0 or index == unfolding:
		return
	if ModuleDamage.hit(site, index, hit.damage, catalog):
		rebuild()

func module_stage(index: int) -> int:
	return ModuleDamage.stage(site, index, catalog)

## What the torch is aimed at (RepairTorch): {part, cell, outside}, or {}.
func part_hit(collider: Object, shape: int, at: Vector3, normal: Vector3) -> Dictionary:
	if collider != exterior:
		return {}
	var cell := ShipCells.hull_cell(grid, exterior, shape, exterior.to_local(at), exterior.global_basis.inverse() * normal)
	var index: int = site.occupied().get(cell, -1)
	if index < 0 or index == unfolding:
		return {}
	return {"part": ModuleDamage.part(index), "cell": cell, "outside": true}

func is_section(p: StringName) -> bool:
	return ModuleDamage.index_of(p) >= 0

func repair_section(p: StringName, share: float) -> float:
	var index := ModuleDamage.index_of(p)
	if index < 0 or index >= site.modules.size():
		return 0.0
	var before := module_stage(index)
	var used := ModuleDamage.repair(site, index, share, catalog)
	if used > 0.0 and module_stage(index) != before:
		rebuild()
	return used

## "DRILL 1 · 45% H"
func part_label(p: StringName) -> String:
	var index := ModuleDamage.index_of(p)
	if index < 0:
		return ""
	var left := 1.0 - ModuleDamage.taken(site, index) / maxf(ModuleDamage.hp(site, index, catalog), 1.0)
	return "%s · %d%% H" % [ModuleDamage.label(site, index), roundi(left * 100.0)]
```

- [ ] **Step 6: The shell's tint and the panel**

`base_exterior.gd`: `build(site, windows := [], openings := [], tints: Array = [])`; pass `tints[i] if i < tints.size() else HullPalette.UNHURT` to `_draw_shell` as a new last parameter `tint: Color`, and inside it `var plate := InteriorKit.solid(tint)` instead of `HullPalette.UNHURT`. Its doc comment says the tint is the module's damage (ship weapons spec §6.5). Note `build` iterates `site` = the shown site, whose indices skip the unfolding module, as `tints` does.

`link_panel.gd`: `var offline := false`; while it is true its `lines()` returns `PackedStringArray(["HUB WRECKED", "MEND IT WITH THE TORCH"])` and `press`/`hold` do nothing.

- [ ] **Step 7: Run the tests**

Run: `godot --headless --path . --import`, then `./run_tests.ps1` with `'-gselect=test_module_damage.gd'`, `'-gselect=test_base_damage.gd'`, `'-gselect=test_base.gd'`, `'-gselect=test_base_drill.gd'`, `'-gselect=test_bases.gd'`, `'-gselect=test_save_bases.gd'`, `'-gselect=test_quantum_link.gd'`, `'-gselect=test_visual_style_rules.gd'`.
Expected: all pass.

- [ ] **Step 8: See it**

Run `test/probes/base_probe.gd` as its header says, with a drill set to damaged and then wrecked before its renders (a two-line change at its start, reverted after); show the owner the scorched and charred shell at eye height.

- [ ] **Step 9: Commit**

```bash
git add who-knows/src/habitat who-knows/test/unit/test_module_damage.gd* who-knows/test/unit/test_base_damage.gd* who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: base modules take fire -- scorched, charred, and a wrecked one stops until mended

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 13: The torch mends a module (Phase 2's done)

**Files:**
- Modify: `who-knows/src/items/repair_torch.gd`
- Test: `who-knows/test/unit/test_repair_torch.gd`

**Interfaces:**
- Consumes: `Base.part_hit`, `Base.repair_section`, `Base.part_label`, `Base.is_section` (Task 12).
- Produces: `RepairTorch.target()` returns, for a base, `{kind: &"part", base, part, cell, outside: true, point, normal}`.

- [ ] **Step 1: The failing test**

Add to `test_repair_torch.gd` (its `_root`, `_item` and `_torch` are the real scene's; the ground class is `test_base_drill.gd`'s, copied in under the name `BaseGround`):

```gdscript
class BaseGround extends PlantSurface:
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
		return &"rock:torch"

func test_the_torch_mends_a_base_module_from_outside():
	_root.bases.clock = func() -> float: return 0.0
	var at: Vector3 = _ship.exterior.global_position + Vector3(0, -40, 60)
	var ground := BaseGround.new(at.y)
	var r := Planting.fit(ground, ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	var base: Base = _root.bases.plant(ModuleCatalog.HUB, r, ground)
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	await wait_physics_frames(2)
	base.site.modules[0]["damage"] = 100.0
	var top := Vector3i(0, -1 << 20, 0)
	for c in base.site.cells_of(0):
		if c.y > top.y and not base.grid.has_block(c + Vector3i.UP):
			top = c
	var face := base.exterior.to_global(ShipGrid.cell_center(top) + Vector3.UP * 1.0)
	var aim := Transform3D(Basis.looking_at(-base.exterior.global_basis.y, base.exterior.global_basis.z),
		face + base.exterior.global_basis.y * 1.5)
	var t := _torch.target(_item, aim, null)
	assert_eq(t.get("part"), ModuleDamage.part(0))
	_torch.hold(_item, aim, null, null, 1.0)
	assert_lt(float(base.site.modules[0]["damage"]), 100.0)
	assert_string_starts_with(_torch.aim_text(_item, aim, null), "HUB 1")
```

The shell drawn over a base hides its box skin but keeps the cell colliders, so the torch's ray lands on the top cell's collider.

- [ ] **Step 2: Run to see it fail**

Run: `./run_tests.ps1 '-gselect=test_repair_torch.gd'`
Expected: the new test fails (the torch ignores bases).

- [ ] **Step 3: The torch**

In `repair_torch.gd`'s `target()`, after the `has_meta(&"ship")` block:

```gdscript
		if collider != null and collider.has_meta(&"base"):
			var base := collider.get_meta(&"base") as Base
			var on := base.part_hit(collider, int(hit.get("shape", -1)), point, normal)
			if not on.is_empty():
				return {"kind": &"part", "base": base, "part": on["part"], "cell": on["cell"], "outside": true,
					"point": point, "normal": normal}
```

`_mend_part()` starts with `if t.has("base"): return (t["base"] as Base).repair_section(t["part"], SECTION_RATE * delta) > 0.0`. `aim_text()`'s `&"part"` branch starts with `if t.has("base"): return (t["base"] as Base).part_label(t["part"])`. The doc comment names bases (ship weapons spec §6.5).

- [ ] **Step 4: Run the tests**

Run: `./run_tests.ps1 '-gselect=test_repair_torch.gd'` and `'-gselect=test_item_uses.gd'`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/items/repair_torch.gd who-knows/test/unit/test_repair_torch.gd
git commit -m "feat: the torch mends a base's module from outside

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Phase 3: the heavy turret and the weapons station

### Task 14: The weapons station block, its look and its seat

**Files:**
- Create: `who-knows/data/blocks/weapons_station.tres`, `who-knows/src/avatar/weapons_station_seat.gd`
- Modify: `who-knows/src/ship/interior/interior_layout.gd` (`SEAT_IDS`, `QUIET_FIXTURES`), `who-knows/src/ship/interior/interior_props.gd` (`weapons_station`, the shared station body), `who-knows/src/ship/interior/interior_dressing.gd` (`_fixture`), `who-knows/src/ship/ship.gd` (`_place_seat`), `who-knows/src/ship/ship_plan.gd` (`Ws`), `who-knows/src/ship/ship_rules.gd` (`TWO_WEAPONS_STATIONS`), `who-knows/test/unit/test_block_data.gd` (36)
- Test: `who-knows/test/unit/test_weapons_station.gd` (new), `test_ship_rules.gd`

**Interfaces:**
- Produces: block `&"weapons_station"` (INTERIOR, MOUNT, 0.5 t, 60 hp, 0.3 MW), token `Ws`; `InteriorProps.weapons_station(kit, f, variety)`; `WeaponsStation` (a `Seat`: `prompt_text()` "Man the weapons", `board: Label3D`); `Ship._place_seat` gives each one a `WeaponsJob` (Task 16; until then the seat has no job); rule `TWO_WEAPONS_STATIONS`.

- [ ] **Step 1: The failing tests**

`who-knows/test/unit/test_weapons_station.gd`:

```gdscript
extends GutTest

## The weapons station (ship weapons spec §3.5): a crew station of its own,
## sat in like one, its console's screen the target board.

func _bridge_grid() -> ShipGrid:
	var grid := ShipLibrary.read("res://test/fixtures/bridge/bridge.json")["grid"] as ShipGrid
	for c: Vector3i in grid.coords():
		if grid.get_block(c).block_id == &"crew_station":
			grid.get_block(c).block_id = WeaponValues.STATION
			break
	return grid

func test_the_block():
	var def := BlockCatalog.load_from_dir("res://data/blocks").get_def(WeaponValues.STATION)
	assert_not_null(def)
	assert_eq(def.occupancy, BlockDefinition.Occupancy.MOUNT)
	assert_almost_eq(def.power_draw, 0.3, 0.0001)
	assert_eq(ShipPlan.default_token(WeaponValues.STATION, 0), "Ws")

func test_it_is_a_seat_the_rules_check():
	assert_true(InteriorLayout.SEAT_IDS.has(WeaponValues.STATION))
	assert_true(InteriorLayout.QUIET_FIXTURES.has(WeaponValues.STATION))
	var found := ShipRules.check(_bridge_grid(), BlockCatalog.load_from_dir("res://data/blocks"))
	assert_eq(found["rules"], [], "the bridge fixture with a weapons station breaks nothing")

func test_a_ship_builds_a_weapons_station_seat():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.starter_ship = "res://test/fixtures/bridge/bridge.json"
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	ship.launch_blueprint = null
	ship.set_grid(_bridge_grid())
	var stations := ship.seats().filter(func(s: Seat) -> bool: return s is WeaponsStation)
	assert_eq(stations.size(), 1)
	if stations.size() == 1:
		assert_eq((stations[0] as WeaponsStation).prompt_text(), "Man the weapons")
		assert_not_null((stations[0] as WeaponsStation).board)
```

In `test_ship_rules.gd`:

```gdscript
func test_two_weapons_stations_break_the_rule():
	var grid := ShipLibrary.read("res://test/fixtures/bridge/bridge.json")["grid"] as ShipGrid
	for c: Vector3i in grid.coords():
		if grid.get_block(c).block_id == &"crew_station":
			grid.get_block(c).block_id = WeaponValues.STATION
	var found := ShipRules.check(grid, BlockCatalog.load_from_dir("res://data/blocks"))
	assert_true(_codes(found["rules"]).has(&"TWO_WEAPONS_STATIONS"))
```

(The bridge fixture has two crew stations; if it has one, add a second at a free bridge cell beside the first, as the fixture's `.plan` shows.)

`test_block_data.gd`: 35 → 36, renamed `test_all_thirty_six_blocks_load`.

- [ ] **Step 2: Run to see them fail**

Run: `./run_tests.ps1 '-gselect=test_weapons_station.gd'`
Expected: failures: no `weapons_station`.

- [ ] **Step 3: The block**

`who-knows/data/blocks/weapons_station.tres`: a copy of `crew_station.tres` with `id="BoxMesh_weapons_station"` (both places), `id = &"weapons_station"`, `display_name = "Weapons Station"`, and nothing else changed (0.5 t, 60 hp, 0.3 MW). No comments.

- [ ] **Step 4: Layout, token, rule**

- `interior_layout.gd`: `SEAT_IDS` gains `WeaponValues.STATION` (write `&"weapons_station"` if a const can't name another class's const there); `QUIET_FIXTURES` gains it too.
- `ship_plan.gd` `BASE`: `&"weapons_station": "Ws",`.
- `ship_rules.gd`, in `_check_seats()` before its loop:

```gdscript
	var stations := layout.fixtures().filter(func(f: Dictionary) -> bool: return f["id"] == WeaponValues.STATION)
	if stations.size() > 1:
		rules.append(item(&"TWO_WEAPONS_STATIONS", "%d weapons stations: a ship has at most one (ship weapons spec §8)"
			% stations.size(), stations[1]["coord"]))
```

- [ ] **Step 5: Its look**

In `interior_props.gd`, split `crew_station()` into `_station_seat(kit, f)` (the pedestal, cushion, backrest and the console's body and face, everything up to the `SCREEN_BACK` panel) and the screens and buttons; `crew_station()` calls `_station_seat` then draws its two screens and four buttons as now (its look unchanged: `test_interior_props.gd` pins it). Add:

```gdscript
## The weapons station (ship weapons spec §3.5): a crew station whose console
## carries one wide dark screen -- the target board is drawn on it -- with a
## row of amber and coral buttons under it.
static func weapons_station(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	_station_seat(kit, f)
	var face := f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-55.0)), Vector3(0, 0.7, -0.64))
	kit.bevel_box(SOLID, face * _at(Vector3(0, 0, 0.03)), Vector3(1.2, 0.24, 0.012), 0.005,
		_c(InteriorPalette.SCREEN_BACK))
	for i in 4:
		kit.bevel_box(GLOW, f * _at(Vector3(-0.27 + i * 0.18, 0.5, -0.565)), Vector3(0.08, 0.05, 0.02), 0.008,
			_lit([InteriorPalette.AMBER, InteriorPalette.CORAL, InteriorPalette.AMBER, InteriorPalette.CORAL][i], 1.6))
	kit.collider(f * _at(Vector3(0, 0.4, -0.72)), Vector3(1.3, 0.8, 0.3))
```

`interior_dressing.gd`'s `_fixture()`: `elif fixture["id"] == &"weapons_station": InteriorProps.weapons_station(kit, fixture_frame(layout, coord), variety)`.

- [ ] **Step 6: The seat**

`who-knows/src/avatar/weapons_station_seat.gd`:

```gdscript
class_name WeaponsStation
extends Seat

## The weapons station (ship weapons spec §3.5, §7): a crew station whose job
## is the guns (WeaponsJob). Its console's screen is the target board.

## The board on the console's face, in the seat's frame: the face InteriorProps
## draws, a hair proud of it.
const BOARD_AT := Vector3(0, 0.72, -0.61)
const BOARD_TILT := -55.0

var board: Label3D

func prompt_text() -> String:
	return "Man the weapons"

func _ready() -> void:
	super()
	board = ReadoutPanel.make_readout(InteriorKit.LAYER, 300.0)
	board.name = "Board"
	board.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(BOARD_TILT)), BOARD_AT)
	add_child(board)

func _process(_delta: float) -> void:
	if board == null:
		return
	var fc: FireControl = job.get("fire_control") if job != null and "fire_control" in job else null
	board.text = "\n".join(WeaponsPage.board_lines(fc, -1)) if fc != null else "WEAPONS\nNO FIRE CONTROL"
```

Until Task 17 makes `WeaponsPage`, write the `_process` body as `board.text = "WEAPONS"`; Task 17 replaces it with the line above.

`ship.gd` `_place_seat()`: `elif f["id"] == WeaponValues.STATION: script = WeaponsStation`.

- [ ] **Step 7: Run the tests**

Run: `godot --headless --path . --import`, then `./run_tests.ps1` with `'-gselect=test_weapons_station.gd'`, `'-gselect=test_block_data.gd'`, `'-gselect=test_ship_rules.gd'`, `'-gselect=test_bridge_seats.gd'`, `'-gselect=test_bridge_layout.gd'`, `'-gselect=test_interior_props.gd'`, `'-gselect=test_interior_dressing.gd'`.
Expected: all pass. A bridge test that pins `SEAT_IDS` by value gets the third id.

- [ ] **Step 8: Commit**

```bash
git add who-knows/data/blocks/weapons_station.tres who-knows/src/avatar/weapons_station_seat.gd* who-knows/src/ship who-knows/test/unit/test_weapons_station.gd* who-knows/test/unit/test_ship_rules.gd who-knows/test/unit/test_block_data.gd
git commit -m "feat: the weapons station -- a crew station of its own, Ws, at most one a ship

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 15: A job's camera and mouse; the gunner's hold

**Files:**
- Modify: `who-knows/src/avatar/seat_job.gd`, `who-knows/src/camera/camera_director.gd`, `who-knows/src/flight/flight_computer.gd`
- Test: `who-knows/test/unit/test_job_camera.gd` (new), `who-knows/test/unit/test_flight_computer.gd`

**Interfaces:**
- Produces: `SeatJob.view_camera() -> Camera3D` (null by default), `SeatJob.takes_mouse() -> bool` (false); `CameraDirector.refresh_view()`; `FlightComputer.gunner_hold: bool`.

- [ ] **Step 1: The failing tests**

`who-knows/test/unit/test_job_camera.gd`:

```gdscript
extends GutTest

## A seat's job may own the camera and the mouse (ship weapons spec §7.2): the
## bridge fixture's crew station, given a job with a camera of its own.

const BRIDGE := "res://test/fixtures/bridge/bridge.json"

class CameraJob extends SeatJob:
	var cam := Camera3D.new()
	func view_camera() -> Camera3D:
		return cam
	func takes_mouse() -> bool:
		return true

var _root: Node
var _ship: Ship
var _director: CameraDirector

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.starter_ship = BRIDGE
	add_child_autofree(_root)
	await wait_process_frames(2)
	_ship = _root.aboard
	_director = _root.get_node("CameraDirector")

func test_a_job_with_a_camera_is_seen_through():
	var station := _ship.seat_at(Vector3i(2, 0, -4))
	var job := CameraJob.new()
	station.job = job
	station.add_child(job)
	_ship.exterior.add_child(job.cam)
	_director.sit(station)
	await wait_for_signal(_director.transition_finished, 3)
	assert_true(job.cam.current, "the job's camera")
	_director.look(Vector2(200, 0))
	assert_eq(_director.camera().transform, Transform3D.IDENTITY, "the mouse is the job's")
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)
	assert_true(_director.camera().current, "standing, your own eyes again")
```

In `test_flight_computer.gd` (its `_hull` and `_fc`):

```gdscript
func test_a_gunner_holds_the_ship():
	_hull.gravity_scale = 0.0
	_hull.linear_velocity = Vector3(0, 0, -30)
	_fc.thrust_budget = {&"forward": 1_000_000.0, &"reverse": 400_000.0, &"lateral": 400_000.0, &"vertical": 400_000.0}
	_fc.set_pilot_input(Vector3(1, 0, -1), Vector3(0.5, 0, 0), false)
	_fc.gunner_hold = true
	assert_true(_fc.speed_locked, "the speed it had is held")
	assert_almost_eq(_fc.locked_speed, 30.0, 0.5)
	_fc.set_pilot_input(Vector3(1, 0, -1), Vector3(0.5, 0, 0), true)
	await wait_physics_frames(3)
	assert_almost_eq(_fc.commanded_force_local.x, 0.0, 1.0, "no one strafes it")
	assert_almost_eq(_fc.commanded_torque_local.x, 0.0, 1.0, "no one turns it")
	_fc.gunner_hold = false
	_fc.set_pilot_input(Vector3(1, 0, 0), Vector3.ZERO, false)
	await wait_physics_frames(2)
	assert_gt(_fc.commanded_force_local.x, 0.0, "let go, the helm flies it again")
```

- [ ] **Step 2: Run to see them fail**

Run: `./run_tests.ps1 '-gselect=test_job_camera.gd'` and `'-gselect=test_flight_computer.gd'`
Expected: the new tests fail.

- [ ] **Step 3: `SeatJob`**

Add to `seat_job.gd`:

```gdscript
## The camera you see through while you sit here, or null for the seat's eye
## (ship weapons spec §7.2: the heavy turret's gun camera).
func view_camera() -> Camera3D:
	return null

## Whether the mouse is the job's while you sit here, not your head's.
func takes_mouse() -> bool:
	return false
```

- [ ] **Step 4: The director**

In `camera_director.gd`:

- `look()`: after its first guard, `if _seat.job != null and _seat.job.takes_mouse(): return`.
- `_apply_view()`'s `View.COCKPIT, View.FOOT_FIRST` branch:

```gdscript
		View.COCKPIT, View.FOOT_FIRST:
			var job_cam := _job_camera()
			if job_cam != null:
				job_cam.current = true
				_interior_cam.current = false
				_chase_cam.current = false
			else:
				_interior_cam.current = true
				_chase_cam.current = false
				_interior_cam.position = Vector3.ZERO
```

- New:

```gdscript
## A seated job's own camera (ship weapons spec §7.2), or null.
func _job_camera() -> Camera3D:
	if not is_seated or _seat == null or _seat.job == null or _tween != null:
		return null
	return _seat.job.view_camera()

## A job changed its camera (another turret): see through the new one.
func refresh_view() -> void:
	if is_seated and _tween == null:
		_apply_view()
```

`stand()` and `stand_now()` already make the interior camera current; `_seat.stood()` runs first, so the job lets go of its camera before.

- [ ] **Step 5: The gunner's hold**

In `flight_computer.gd`:

```gdscript
## Someone at the weapons station (ship weapons spec §7.1): the stick and the
## keys are centred and, with the assist on, the forward speed it had is
## locked, so it keeps its course while drift and spin are damped. Off, the
## helm flies it again.
var gunner_hold := false:
	set(on):
		gunner_hold = on
		if on:
			_translate_input = Vector3.ZERO
			_rotate_input = Vector3.ZERO
			_boost = false
			if assist_enabled and not speed_locked:
				speed_locked = true
				locked_speed = forward_speed() if _hull != null else 0.0
```

`set_pilot_input()` starts with `if gunner_hold: return`.

- [ ] **Step 6: Run the tests**

Run: `./run_tests.ps1` with `'-gselect=test_job_camera.gd'`, `'-gselect=test_seat.gd'`, `'-gselect=test_flight_computer.gd'`, `'-gselect=test_bridge_seats.gd'`, `'-gselect=test_pilot_seat.gd'`.
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/avatar/seat_job.gd who-knows/src/camera/camera_director.gd who-knows/src/flight/flight_computer.gd who-knows/test/unit/test_job_camera.gd* who-knows/test/unit/test_flight_computer.gd
git commit -m "feat: a seat's job may own the camera and the mouse; a gunner holds the ship's course

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 16: `WeaponsJob` — manning the heavy turret

**Files:**
- Create: `who-knows/src/combat/weapons_job.gd`, `who-knows/src/ui/gun_sight.gd`
- Modify: `who-knows/src/ship/ship.gd` (`_place_seat` gives the job)
- Test: `who-knows/test/unit/test_weapons_job.gd` (new)

**Interfaces:**
- Consumes: `SeatJob.view_camera/takes_mouse` and `CameraDirector.refresh_view` (Task 15), `FlightComputer.gunner_hold` (Task 15), `Turret.manual/manual_aim/pull_trigger/recharge_left/muzzle/barrel_dir` (Task 7), `Ship.heavy_turrets()` (Task 7), `FireControl.mark_nearest/rotate_list/entries` (Task 6).
- Produces: `WeaponsJob` (`ship: Ship`, `fire_control: FireControl`, `active`, `heavy_index`, `zoom`, `aim: Vector2`, `camera: Camera3D`, `sight: GunSight`; `heavy() -> Turret`, `handle(event)`); `GunSight` (`camera`, `barrel_point: Vector3`, `lead_point: Variant`, `status: String`).

- [ ] **Step 1: The failing test**

`who-knows/test/unit/test_weapons_job.gd`:

```gdscript
extends GutTest

## Manning the heavy turret (ship weapons spec §7): sitting holds the ship and
## puts you behind the gun's camera; the mouse aims, the trigger fires, the
## wheel zooms, T marks; standing gives the gun back to fire control.

var _root: Node
var _ship: Ship
var _director: CameraDirector
var _station: WeaponsStation

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.starter_ship = "res://test/fixtures/bridge/bridge.json"
	add_child_autofree(_root)
	await wait_process_frames(2)
	_ship = _root.aboard
	_director = _root.get_node("CameraDirector")
	var grid := ShipLibrary.read("res://test/fixtures/bridge/bridge.json")["grid"] as ShipGrid
	for c: Vector3i in grid.coords():
		if grid.get_block(c).block_id == &"crew_station":
			grid.get_block(c).block_id = WeaponValues.STATION
			break
	var heavy := BlockInstance.new()
	heavy.block_id = WeaponValues.HEAVY
	grid.set_block(_free_roof(grid), heavy)
	_ship.launch_blueprint = null
	_ship.set_grid(grid)
	for s in _ship.seats():
		if s is WeaponsStation:
			_station = s

## A cell on top of the fixture's roof with space above it.
func _free_roof(grid: ShipGrid) -> Vector3i:
	var top := -1 << 20
	for c: Vector3i in grid.coords():
		top = maxi(top, c.y)
	for c: Vector3i in grid.coords():
		if c.y == top and not grid.has_block(c + Vector3i.UP):
			return c + Vector3i.UP
	return Vector3i(0, top + 1, 0)

func _sit() -> void:
	_director.sit(_station)
	await wait_for_signal(_director.transition_finished, 3)

func test_sitting_takes_the_gun_and_holds_the_ship():
	await _sit()
	var job := _station.job as WeaponsJob
	assert_not_null(job)
	assert_true(job.active)
	assert_true(_ship.flight_computer.gunner_hold)
	assert_true(job.heavy().manual)
	assert_true(job.camera.current, "you look down the gun")

func test_the_trigger_fires_and_standing_gives_it_back():
	await _sit()
	var job := _station.job as WeaponsJob
	var shots := []
	job.heavy().fired.connect(func(_k: StringName) -> void: shots.append(1))
	var click := InputEventAction.new()
	click.action = &"use"
	click.pressed = true
	job.handle(click)
	await wait_physics_frames(2)
	assert_eq(shots.size(), 1)
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)
	assert_false(job.heavy().manual, "fire control has it again")
	assert_false(_ship.flight_computer.gunner_hold, "the helm flies it again")
	assert_false(job.camera.current)

func test_the_mouse_aims_and_the_wheel_zooms():
	await _sit()
	var job := _station.job as WeaponsJob
	var before := job.aim
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(100, -50)
	job.handle(move)
	assert_gt(job.aim.x, before.x, "to the right")
	assert_gt(job.aim.y, before.y, "and up")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	job.handle(wheel)
	assert_almost_eq(job.camera.fov, WeaponsJob.ZOOMS[1], 0.01)

func test_without_a_heavy_turret_it_is_a_board():
	for t in _ship.heavy_turrets():
		_ship.grid.clear_block(t.coord)
	await wait_process_frames(2)
	await _sit()
	var job := _station.job as WeaponsJob
	assert_null(job.view_camera())
	assert_true(_ship.flight_computer.gunner_hold, "you still are not flying")
```

- [ ] **Step 2: Run to see it fail**

Run: `./run_tests.ps1 '-gselect=test_weapons_job.gd'`
Expected: parse errors naming `WeaponsJob`.

- [ ] **Step 3: Write `gun_sight.gd`**

```gdscript
class_name GunSight
extends Control

## What you see over the gun camera (ship weapons spec §7.2): the reticle where
## you aim (the middle), a ring where the barrel points now, a diamond where to
## aim for the first target listed, and a line of status. HUD colours.

const RETICLE := 14.0
const RING := 9.0
const DIAMOND := 8.0

var camera: Camera3D
var barrel_point := Vector3.ZERO
var lead_point: Variant = null
var status := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if camera == null or not camera.is_inside_tree():
		return
	var c := size * 0.5
	draw_line(c - Vector2(RETICLE, 0), c + Vector2(RETICLE, 0), HudPalette.READOUT, 2.0)
	draw_line(c - Vector2(0, RETICLE), c + Vector2(0, RETICLE), HudPalette.READOUT, 2.0)
	if not camera.is_position_behind(barrel_point):
		draw_arc(camera.unproject_position(barrel_point), RING, 0.0, TAU, 24, HudPalette.DIM, 2.0)
	if lead_point != null and not camera.is_position_behind(lead_point):
		var p := camera.unproject_position(lead_point)
		var pts := PackedVector2Array([p + Vector2(0, -DIAMOND), p + Vector2(DIAMOND, 0), p + Vector2(0, DIAMOND),
			p + Vector2(-DIAMOND, 0), p + Vector2(0, -DIAMOND)])
		draw_polyline(pts, HudPalette.TARGET, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(c.x - 160.0, size.y - 40.0), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		HudPalette.READOUT)
```

- [ ] **Step 4: Write `weapons_job.gd`**

```gdscript
class_name WeaponsJob
extends SeatJob

## The weapons station's job (ship weapons spec §7). Sitting holds the ship
## (FlightComputer.gunner_hold) and, with a heavy turret aboard, puts you
## behind its gun camera: the mouse aims, the trigger (use) fires, the wheel
## zooms, T marks the target nearest the reticle, Tab cycles the list, Q and E
## change heavy turrets. Standing gives the gun back to fire control. With no
## heavy turret the station is the target board, and you still are not flying.

const SENSITIVITY := 0.003
## The gun camera's field of view at each zoom: 1×, 2×, 4×.
const ZOOMS: Array[float] = [70.0, 35.0, 17.5]
## The camera stands this far over the barrels' pivot, m.
const CAMERA_UP := 0.6

var ship: Ship
var fire_control: FireControl
var active := false
var heavy_index := 0
var zoom := 0
## The reticle's mount-frame (yaw, elevation).
var aim := Vector2(0.0, WeaponValues.PARK_ELEVATION)
var camera: Camera3D
var sight: GunSight
var _layer: CanvasLayer
var _whine: AudioStreamPlayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "Sight"
	_layer.layer = 5
	add_child(_layer)
	sight = GunSight.new()
	sight.visible = false
	_layer.add_child(sight)
	_whine = AudioStreamPlayer.new()
	_whine.bus = AudioBuses.SHIP
	_whine.volume_db = -12.0
	add_child(_whine)

func heavy() -> Turret:
	if ship == null:
		return null
	var all := ship.heavy_turrets()
	return all[heavy_index % all.size()] if not all.is_empty() else null

func sat(_avatar: Avatar) -> void:
	active = true
	if ship != null:
		ship.flight_computer.gunner_hold = true
	_take()

func stood(_avatar: Avatar) -> void:
	active = false
	if ship != null:
		ship.flight_computer.gunner_hold = false
		for t in ship.heavy_turrets():
			t.manual = false
	if camera != null:
		camera.current = false
	sight.visible = false

func view_camera() -> Camera3D:
	return camera if active and heavy() != null else null

func takes_mouse() -> bool:
	return active and heavy() != null

func _take() -> void:
	var t := heavy()
	if t == null:
		return
	for other in ship.heavy_turrets():
		other.manual = other == t
	aim = Vector2(t.yaw, t.elevation)
	t.manual_aim = t.barrel_dir()
	if camera == null:
		camera = Camera3D.new()
		camera.name = "GunCamera"
		camera.cull_mask = ship.chase_camera.cull_mask
		camera.far = ship.chase_camera.far
	if camera.get_parent() != t:
		if camera.get_parent() != null:
			camera.get_parent().remove_child(camera)
		t.add_child(camera)
	camera.fov = ZOOMS[zoom]
	_pose_camera()
	sight.visible = true
	sight.camera = camera
	var d := get_tree().get_first_node_in_group(CameraDirector.GROUP) as CameraDirector if is_inside_tree() else null
	if d != null:
		d.refresh_view()

func _pose_camera() -> void:
	camera.transform = Transform3D(Basis.from_euler(Vector3(aim.y, -aim.x, 0.0)),
		Vector3(0, WeaponValues.MUZZLE_UP + CAMERA_UP, 0))

func _process(_delta: float) -> void:
	var t := heavy()
	if not active or t == null or camera == null:
		return
	_pose_camera()
	t.manual_aim = -camera.global_basis.z
	sight.barrel_point = t.muzzle() + t.barrel_dir() * 1000.0
	sight.lead_point = _lead(t)
	var left := t.recharge_left()
	sight.status = "HEAVY %d · %s · ×%d" % [heavy_index % ship.heavy_turrets().size() + 1,
		"READY" if left <= 0.0 else "CHARGING %.1f S" % left, 1 << zoom]
	if left > 0.0 and not _whine.playing:
		var s := Synth.sound(&"phaser_whine")
		if s != null:
			_whine.stream = s
			_whine.play()

## Where to aim for the first target listed, world, or null.
func _lead(t: Turret) -> Variant:
	if fire_control == null or fire_control.entries.is_empty():
		return null
	var node := fire_control.entries[0]["node"] as Node3D
	if node == null or not is_instance_valid(node):
		return null
	var s := WeaponAim.intercept(t.muzzle(), ship.exterior.linear_velocity, WeaponValues.spec(t.kind)["speed"],
		Weapons.point_of(node), Weapons.velocity_of(node))
	return null if s.is_empty() else t.muzzle() + (s["dir"] as Vector3) * 1000.0

func _unhandled_input(event: InputEvent) -> void:
	if active and handle(event):
		get_viewport().set_input_as_handled()

## One input event while sat here; true if it was the gun's. Split from
## _unhandled_input so tests can drive it.
func handle(event: InputEvent) -> bool:
	var t := heavy()
	if not active or t == null:
		return false
	var motion := event as InputEventMouseMotion
	if motion != null:
		var scale := SENSITIVITY * camera.fov / ZOOMS[0]
		aim.x = wrapf(aim.x + motion.relative.x * scale, -PI, PI)
		aim.y = clampf(aim.y - motion.relative.y * scale, 0.0, PI * 0.5)
		return true
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom = clampi(zoom + (1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, ZOOMS.size() - 1)
		camera.fov = ZOOMS[zoom]
		return true
	if event.is_action_pressed(&"use"):
		t.pull_trigger()
		return true
	if event.is_action_pressed(&"weapons_mark", false, true) and fire_control != null:
		fire_control.mark_nearest(camera.global_position, -camera.global_basis.z, WeaponValues.MARK_CONE,
			WeaponValues.spec(WeaponValues.HEAVY)["manned_range"])
		return true
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_TAB and fire_control != null:
		fire_control.rotate_list()
		return true
	if event.is_action_pressed(&"roll_left") or event.is_action_pressed(&"roll_right"):
		var n := ship.heavy_turrets().size()
		if n > 1:
			heavy_index = posmod(heavy_index + (1 if event.is_action_pressed(&"roll_right") else -1), n)
			_take()
		return true
	return false
```

Manned, the heavy turret may fire past its automatic range: in `turret.gd`'s `_reaches()`, use `_spec["manned_range"]` when `manual`; add that one line and a test in `test_turret.gd` (`test_by_hand_it_reaches_further`).

- [ ] **Step 5: The ship gives the job**

In `ship.gd` `_place_seat()`, after a seat is placed or kept, for a `WeaponsStation` with no job:

```gdscript
		if s is WeaponsStation and s.job == null:
			var job := WeaponsJob.new()
			job.name = "WeaponsJob"
			job.ship = self
			job.fire_control = fire_control
			s.job = job
			s.add_child(job)
```

- [ ] **Step 6: Run the tests**

Run: `godot --headless --path . --import`, then `./run_tests.ps1` with `'-gselect=test_weapons_job.gd'`, `'-gselect=test_turret.gd'`, `'-gselect=test_bridge_seats.gd'`, `'-gselect=test_weapons_station.gd'`.
Expected: all pass. The sit glide asks for a real camera move; in a headless run `transition_finished` still fires (the bridge tests rely on it).

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/combat/weapons_job.gd* who-knows/src/ui/gun_sight.gd* who-knows/src/ship/ship.gd who-knows/src/combat/turret.gd who-knows/test/unit/test_weapons_job.gd* who-knows/test/unit/test_turret.gd
git commit -m "feat: man the heavy turret -- its gun camera, the mouse aims, the trigger fires, the lead diamond

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 17: The WEAPONS page and the board

**Files:**
- Create: `who-knows/src/ship/computer/weapons_page.gd`
- Modify: `who-knows/src/ship/computer/computer_context.gd` (`fire_control`), `who-knows/src/ship/computer/ship_computer.gd` (adds the page), `who-knows/src/ship/ship.gd` (`_bind_computers`), `who-knows/src/avatar/weapons_station_seat.gd` (the board's text)
- Test: `who-knows/test/unit/test_weapons_page.gd` (new)

**Interfaces:**
- Consumes: `FireControl` (Task 6).
- Produces: `WeaponsPage` (`title() == "WEAPONS"`, `selected`, buttons: prev/next pick, `range` drops, `big` switches the orders); `WeaponsPage.board_lines(fc, selected) -> PackedStringArray`; `ComputerContext.fire_control`.

- [ ] **Step 1: The failing test**

`who-knows/test/unit/test_weapons_page.gd`:

```gdscript
extends GutTest

## The WEAPONS page (ship weapons spec §7.4): the orders, the list with each
## entry's distance and bearing, each turret's state; prev and next pick, RANGE
## drops, the big button switches the orders.

class StubTurret extends Node3D:
	var target: Node3D
	var no_arc := false
	var state: StringName = &"firing"
	func can_engage(_n: Node3D) -> bool:
		return true
	func muzzle() -> Vector3:
		return Vector3.ZERO

var _fc: FireControl
var _ctx: ComputerContext

func before_each():
	_fc = FireControl.new()
	add_child_autofree(_fc)
	var t := StubTurret.new()
	add_child_autofree(t)
	_fc.turrets = [t]
	_ctx = ComputerContext.new()
	_ctx.fire_control = _fc

func test_no_turrets_no_weapons():
	_fc.turrets = []
	assert_eq(WeaponsPage.board_lines(_fc, 0), PackedStringArray(["NO WEAPONS"]))

func test_lines():
	_fc.mark(&"ship:A")
	_fc.entries = [{"id": &"ship:A", "node": null, "label": "WARDEN", "distance": 1400.0, "bearing": true}]
	var lines := WeaponsPage.new().lines(_ctx)
	assert_eq(lines[0], "HOLD · 1 TURRET")
	assert_string_contains(lines[1], "1 WARDEN 1.4 KM")
	assert_string_contains(lines[2], "T1 FIRING")

func test_buttons():
	var page := WeaponsPage.new()
	_fc.mark(&"ship:A")
	_fc.mark(&"ship:B")
	page.press(&"big", _ctx)
	assert_eq(_fc.orders, FireControl.Orders.ENGAGE)
	assert_eq(page.big_colour(_ctx), &"go")
	page.press(&"next", _ctx)
	assert_eq(page.selected, 1)
	page.press(&"range", _ctx)
	assert_eq(_fc.list, [&"ship:A"] as Array[StringName])
```

- [ ] **Step 2: Run to see it fail**

Run: `./run_tests.ps1 '-gselect=test_weapons_page.gd'`
Expected: parse errors naming `WeaponsPage`.

- [ ] **Step 3: Write `weapons_page.gd`**

```gdscript
class_name WeaponsPage
extends ComputerPage

## The bridge computer's WEAPONS page and the weapons station's board (ship
## weapons spec §7.4): the orders, the list -- each entry's label, distance, and
## NO ARC while no turret can bear -- and each turret's state. prev and next
## pick an entry, RANGE drops it, the big button switches the orders. Marking
## is done where you can see: the helm and the gun camera.

var selected := 0

func title() -> String:
	return "WEAPONS"

func lines(ctx: ComputerContext) -> PackedStringArray:
	return board_lines(ctx.fire_control if ctx != null else null, selected)

## The board's three lines; `selected` < 0 marks none.
static func board_lines(fc: FireControl, p_selected: int) -> PackedStringArray:
	if fc == null or fc.turrets.is_empty():
		return PackedStringArray(["NO WEAPONS"])
	var n := fc.turrets.size()
	var head := "%s · %d TURRET%s" % ["ENGAGE" if fc.orders == FireControl.Orders.ENGAGE else "HOLD", n,
		"" if n == 1 else "S"]
	var listed := PackedStringArray()
	for i in fc.entries.size():
		var e: Dictionary = fc.entries[i]
		var d: float = e["distance"]
		var far := "--" if d < 0.0 else (("%.1f KM" % (d / 1000.0)) if d >= 1000.0 else ("%d M" % roundi(d)))
		listed.append("%s%d %s %s%s" % [">" if i == p_selected else "", i + 1, e["label"], far,
			"" if e["bearing"] else " NO ARC"])
	var list_line := " · ".join(listed) if not listed.is_empty() else "NO TARGETS · T TO MARK"
	var states := PackedStringArray()
	var pips := fc.pips()
	for i in pips.size():
		states.append("T%d %s" % [i + 1, String(pips[i]).to_upper().replace("_", " ")])
	return PackedStringArray([head, list_line, " · ".join(states)])

func lit(ctx: ComputerContext) -> Array[StringName]:
	var fc := ctx.fire_control if ctx != null else null
	if fc == null or fc.turrets.is_empty():
		return []
	if fc.list.is_empty():
		return [&"big"]
	return [&"range", &"prev", &"big", &"next"]

func big_colour(ctx: ComputerContext) -> StringName:
	var fc := ctx.fire_control if ctx != null else null
	if fc == null or fc.turrets.is_empty():
		return &"dark"
	return &"go" if fc.orders == FireControl.Orders.ENGAGE else &"amber"

func prompt(button: StringName, ctx: ComputerContext) -> String:
	var fc := ctx.fire_control if ctx != null else null
	match button:
		&"big":
			return "Hold fire" if fc != null and fc.orders == FireControl.Orders.ENGAGE else "Engage"
		&"prev":
			return "Previous target"
		&"next":
			return "Next target"
		&"range":
			return "Drop target"
	return ""

func press(button: StringName, ctx: ComputerContext) -> void:
	var fc := ctx.fire_control if ctx != null else null
	if fc == null:
		return
	match button:
		&"big":
			fc.toggle_orders()
		&"prev":
			selected = posmod(selected - 1, maxi(fc.list.size(), 1))
		&"next":
			selected = posmod(selected + 1, maxi(fc.list.size(), 1))
		&"range":
			if selected < fc.list.size():
				fc.unmark(fc.list[selected])
				selected = clampi(selected, 0, maxi(fc.list.size() - 1, 0))

func save() -> Dictionary:
	return {"selected": selected}

func restore(state: Dictionary) -> void:
	selected = int(state.get("selected", 0))
```

- [ ] **Step 4: Wire it**

- `computer_context.gd`: `var fire_control: FireControl` with a doc line (ship weapons spec §7.4; null in tests).
- `ship.gd` `_bind_computers()`: `context.fire_control = fire_control`.
- `ship_computer.gd` `bind(context)`: after storing the context, `if context.fire_control != null and not context.fire_control.turrets.is_empty() and not pages.any(func(p): return p is WeaponsPage): pages.append(WeaponsPage.new())`. A test that pins the starter's page count (`test_bridge_computer_scene.gd`) now expects 3 on the armed starter; update it with a comment.
- `weapons_station_seat.gd` `_process`: the board's text is `"\n".join(WeaponsPage.board_lines(fc, -1))` as written in Task 14's Step 6.

- [ ] **Step 5: Run the tests**

Run: `./run_tests.ps1` with `'-gselect=test_weapons_page.gd'`, `'-gselect=test_bridge_computer_scene.gd'`, `'-gselect=test_bridge_computer_block.gd'`, `'-gselect=test_computer_station.gd'`, `'-gselect=test_weapons_station.gd'`.
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/ship/computer who-knows/src/ship/ship.gd who-knows/src/avatar/weapons_station_seat.gd who-knows/test/unit/test_weapons_page.gd* who-knows/test/unit/test_bridge_computer_scene.gd
git commit -m "feat: the WEAPONS page and the station's board -- orders, the list, each turret's state

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 18: The Warden and the Lamplighter armed (Phase 3's done)

**Files:**
- Modify: `who-knows/data/ships/warden.json`, `warden.md`, `lamplighter.json`, `lamplighter.md`

**Interfaces:**
- Produces: the Warden with six light turrets — dorsal `(0, 2, 2)` and `(0, 1, -4)` (orientation 0), ventral `(0, -2, -6)` and `(0, -2, 1)` (2), starboard `(3, 0, 1)` and port `(-3, 0, 1)` (the flank orientations Task 2's test found) — one heavy turret at `(0, 0, -9)` (0), and its crew station at `(2, 0, -3)` a `weapons_station`; the Lamplighter with one light turret at `(0, 2, 0)` (0).

- [ ] **Step 1: The blueprints**

Each listed cell's entry in the JSON becomes the turret (or station) with the orientation given; the cells hold fairing halves or hull today.

- [ ] **Step 2: The check**

Run the ship check (Task 10, Step 2) on `warden.json` and `lamplighter.json`.
Expected: 0 rules broken; no `TURRET_BLIND`; the `TURRETS` note lists each. For any blind or buried turret, move it to the nearest cell on the same face that clears, and say why in the ship's `.md`. A `POWER_MARGIN` on the Warden (108 MW made, now about 97.9 drawn, 107.7 needed) means a draw changed: report it to the owner rather than raising a turret's draw.

- [ ] **Step 3: The tests**

Run: `./run_tests.ps1 '-gselect=test_ship_catalog.gd'` (every ship boards, flies, walks and saves) and `'-gselect=test_bridge_ship.gd'`.
Expected: all pass.

- [ ] **Step 4: See it**

The ship probe on each (`--ship warden`, `--ship lamplighter`), and in the game: board the Warden (F8), F6 a starter 800 m ahead, T, B, then sit at the weapons station and fire the heavy turret. Renders at eye height from the bridge and through the gun camera, shown to the owner.

- [ ] **Step 5: The notes**

`warden.md` and `lamplighter.md` each get a *Weapons* section: the turrets, where and why, their sky coverage, the station, mass and power as the check printed them.

- [ ] **Step 6: Commit**

```bash
git add who-knows/data/ships
git commit -m "feat: the Warden packs six light turrets, a heavy one forward and a weapons station; the Lamplighter one

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Phase 4: proof and upkeep

### Task 19: The combat probe, tuning and the renders

**Files:**
- Create: `who-knows/test/probes/combat_probe.gd`
- Modify: `.claude/skills/building-a-ship/ship_probe.gd` (a `turrets` line), possibly `who-knows/src/combat/weapon_values.gd` (tuning)

**Interfaces:**
- Consumes: everything above.
- Produces: the probe's lines (`hit`, `fps`, `heavy`, `render`), and `WeaponValues` as tuned.

- [ ] **Step 1: Write the probe**

```gdscript
extends SceneTree

# The weapons in the real flight scene (docs/superpowers/specs/
# 2026-10-11-ship-weapons-design.md §10.2): the Warden in ENGAGE on a starter
# jinking sideways at 5 m/s², and the hit rate at each range; the frame rate
# with every gun firing; the heavy turret by hand at 2 km; renders. Windowed,
# so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/combat_probe.gd -- <abs out dir>
#
# Pass: at least 80% at 400 m, at most 30% at 1.2 km, at least 120 fps.

const RANGES := [400.0, 600.0, 800.0, 1000.0, 1200.0]
const JINK := 5.0
const RUN := 8.0

var _out := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "user://combat_probe"
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()

func _scene() -> Node:
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	scene.save_enabled = false
	scene.starter_ship = "warden"
	root.add_child(scene)
	return scene

func _physics(n: int) -> void:
	for i in n:
		await physics_frame

## A starter `ahead` metres off the Warden's bow, flying itself no more.
func _target(scene: Node, warden: Ship, ahead: float) -> Ship:
	var grid := ShipLibrary.read("res://data/ships/starter.json")["grid"] as ShipGrid
	var place := Transform3D(warden.exterior.global_basis,
		warden.exterior.global_position - warden.exterior.global_basis.z * ahead)
	var ship: Ship = scene.fleet.spawn(grid, place)
	ship.flight_computer.set_physics_process(false)
	return ship

static func _taken(ship: Ship) -> float:
	var sum := 0.0
	for v in ship.damage.section_damage.values():
		sum += v
	for v in ship.damage.component_damage.values():
		sum += v
	return sum

func _run() -> void:
	for range_m: float in RANGES:
		var scene := _scene()
		await _physics(10)
		var warden: Ship = scene.get_node("Ship")
		var target := _target(scene, warden, range_m)
		await _physics(5)
		warden.quantum.store.amount = warden.quantum.store.capacity
		var shots := [0]
		for t in warden.turrets:
			t.fired.connect(func(_k: StringName) -> void: shots[0] += 1)
		warden.fire_control.mark(Weapons.ship_id(target))
		warden.fire_control.set_orders(FireControl.Orders.ENGAGE)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(range_m)
		var push := Vector3.ZERO
		var next_turn := 0.0
		var t0 := _taken(target)
		var elapsed := 0.0
		while elapsed < RUN:
			await physics_frame
			var dt := 1.0 / Engine.physics_ticks_per_second
			elapsed += dt
			if elapsed >= next_turn:
				var side := target.exterior.global_basis.x if rng.randf() < 0.5 else target.exterior.global_basis.y
				push = side * (1.0 if rng.randf() < 0.5 else -1.0)
				next_turn = elapsed + rng.randf_range(1.0, 2.0)
			target.exterior.linear_velocity += push * JINK * dt
		var hits := (_taken(target) - t0) / float(WeaponValues.spec(WeaponValues.LIGHT)["damage"])
		print("hit     %4.0f m: %d bolts, %.0f hit (%.0f%%)" % [range_m, shots[0], hits,
			100.0 * hits / maxf(shots[0], 1.0)])
		scene.queue_free()
		await _physics(3)
	await _fps_and_renders()
	quit(0)

func _fps_and_renders() -> void:
	var scene := _scene()
	await _physics(10)
	var warden: Ship = scene.get_node("Ship")
	var target := _target(scene, warden, 300.0)
	await _physics(5)
	warden.quantum.store.amount = warden.quantum.store.capacity
	warden.fire_control.mark(Weapons.ship_id(target))
	warden.fire_control.set_orders(FireControl.Orders.ENGAGE)
	await _physics(60)
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 3_000_000:
		await process_frame
		frames += 1
	print("fps     %.0f with every gun firing (%d bolts live)" % [frames / 3.0, scene.bolt_pool.live])
	await _shot("combat_chase")
	print("render  done")
	scene.queue_free()

func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	var file := "%s/%s.png" % [_out, shot_name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)
```

Add to it, in the same style, the bridge view (seat the avatar at the Warden's helm with `CameraDirector.sit_now` and shoot `combat_bridge`), the gun camera (sit at the weapons station and shoot `combat_gun`), and the heavy by hand at 2 km: a still target 2,000 m ahead, the job's `heavy()` set `manual`, `manual_aim` from `WeaponAim.intercept`, five `pull_trigger()`s 3.1 s apart; print `heavy   5 bolts, n hit`.

- [ ] **Step 2: Run it and tune**

Run: `godot --path who-knows --resolution 1280x720 --script res://test/probes/combat_probe.gd -- D:/git/whoknows-weapons/renders/combat`
Expected: the pass marks in its header. If 400 m hits under 80%, lower `spread` or raise `speed`; if 1.2 km hits over 30%, lower `speed` or raise `spread`; change one number at a time in `WeaponValues`, re-run, and keep a table of what each run gave for the spec's as-built notes. Under 120 fps: trails into one `MultiMesh` first (spec §15). Re-run the probe alone if another run shares the GPU.

- [ ] **Step 3: The ship probe's line**

In `ship_probe.gd`, after it prints the rules line, print each turret: `print("turret  %s %s at %s, sky %d%%" % [t.name, t.kind, t.coord, roundi(t.sky.coverage() * 100.0)])` for `t in ship.turrets`, or `turret  none`; add the line to its header comment.

- [ ] **Step 4: Show the owner**

Send the renders (bridge, chase, gun camera, a base's wrecked drill from Task 12) with the probe's table. The owner judges the look and the dance; changes go back to the relevant task's numbers.

- [ ] **Step 5: Commit**

```bash
git add who-knows/test/probes/combat_probe.gd* who-knows/src/combat/weapon_values.gd .claude/skills/building-a-ship/ship_probe.gd
git commit -m "test: the combat probe -- hit rate by range on a jinking starter, the frame rate under full fire, the heavy by hand

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 20: The skills and the spec (done)

**Files:**
- Modify: `.claude/skills/building-a-ship/SKILL.md`, `reference.md`; `.claude/skills/designing-a-ship/SKILL.md`; `.claude/skills/building-an-npc/SKILL.md`, its `reference.md`; `docs/superpowers/specs/2026-10-11-ship-weapons-design.md`

- [ ] **Step 1: `building-a-ship`**

- *Checklist*: "Every turret stands on an open face and its `TURRETS` note shows its sky; under 25% (`TURRET_BLIND`) move it. At most one `weapons_station`; a heavy turret without one fires on its own."
- *Mistakes already made*: what the loadouts taught (which fairing became which turret, any that came out blind or tipped the balance), and anything the probe found.
- `reference.md`: the three blocks (mass, hp, draw, tokens `Tl`, `Th`, `Ws`), the orientation table (dorsal 0, ventral 2, the flanks as Task 2 found, fore and aft), `WeaponValues` as tuned, the APIs (`Ship.turrets`, `Ship.fire_control`, `Ship.heavy_turrets()`, `FireControl.mark/set_orders`, `Weapons.ship_id`), and the probe's `turret` line.

- [ ] **Step 2: `designing-a-ship`**

In *Roles*, a loadout for each: a shuttle two light turrets (dorsal, ventral); an explorer one; a patrol ship or warship light turrets on every face it shows an enemy, one heavy forward and a weapons station on the bridge; a freighter none or one. In the token table, `Tl`, `Th`, `Ws`. In *Budgets*, the power and mass a turret costs.

- [ ] **Step 3: `building-an-npc`**

In *Checklist* or *reference.md*: NPCs outside are `Weapons.TARGETS` (`NpcDirector.targets`), take phaser hits through `receive_hit` like any other (15 hp a light bolt, 120 a heavy), and a dead NPC leaves every list.

- [ ] **Step 4: The spec's as-built notes**

`Status:` becomes "approved and built, <date>"; a §16 *As built* section: the tuned numbers and the probe's table, anything that moved from this plan (with why), the Warden's and the starter's sky coverage, and the renders' verdicts from the owner.

- [ ] **Step 5: Check the skills against the code**

`grep` each name the skills mention (`turret_light`, `weapons_station`, `FireControl`, `WeaponValues`, `SkyMap`, `NpcDirector.targets`) in `who-knows/src`; every one must exist.

- [ ] **Step 6: Commit**

```bash
git add .claude/skills docs/superpowers/specs/2026-10-11-ship-weapons-design.md
git commit -m "docs: the weapons as built -- the skills, the reference, the spec's as-built notes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Ask the owner about the full suite**

Run nothing more; ask the owner whether to run the full suite (~17 min) before the branch is finished.
