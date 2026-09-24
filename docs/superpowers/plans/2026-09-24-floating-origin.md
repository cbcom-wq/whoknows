# Floating Origin Implementation Plan (asteroids, build step 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep everything outside the ship near the engine origin, however far you fly, by moving
the origin in whole kilometres whenever the focus strays 2 km from it. The player should see
nothing at all.

**Architecture:** A pure `UniversePoint` (64-bit metres plus a fraction) says where things are in
the universe. A `Universe` node in the flight scene holds the origin's universe position and
watches the focus (the hull, or you on a spacewalk). Past 2 km, first thing in a physics tick,
it moves every member of group `exterior_space` back by the same whole kilometres and announces
`shifted(delta)`. The interior is never a member and never moves.

**Tech Stack:** Godot 4.5.1 (.NET build, GDScript only), GUT 9 tests, `run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-09-24-asteroids-design.md` (§4 is this plan; §4.5 is its
live check). This is plan 1 of 2. Plan 2 (recipe, streaming, the physics bubble, crash feel) is
written once this plan's live check passes (the owner asked to continue autonomously).

## Global Constraints

- The origin moves only in whole kilometres: `STEP = 1000.0`; shift past `SHIFT_AT = 2000.0` on
  any axis; world-space effects may hold it, never past `FORCE_AT = 4000.0`.
- Members of `&"exterior_space"` are shifted themselves, never through a parent; a member's
  parent never moves.
- The interior (`Ship/Interior` and everything under it) is never a member and never moves.
- The shift happens before the physics step: `Universe.process_physics_priority = -1000`.
- `UniversePoint` holds whole metres as GDScript `int` (64-bit) and the fraction as GDScript
  `float` (64-bit), never as `Vector3`, which is 32-bit.
- `.tscn` edits: no `#` comments anywhere in the file's blocks (`CLAUDE.md`); verify every scene
  edit by reading the node back at runtime, not by a clean load.
- Tests: GUT, headless, output pristine. Run everything with
  `& .\who-knows\run_tests.ps1` from the worktree root; one script with
  `& .\who-knows\run_tests.ps1 '-gselect=test_universe'` (quote the argument in PowerShell).
- After adding a `class_name`, run the import pass before tests:
  `& $env:GODOT_BIN --headless --path .\who-knows --import` (or the full path in
  `run_tests.ps1`).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Work in a sibling worktree (`D:\git\whoknows-origin`, branch `floating-origin`): other
  sessions share `D:\git\whoknows`.

---

## File Structure

| File | Responsibility |
|---|---|
| Create `who-knows/src/world/universe_point.gd` | `UniversePoint`: a universe position; `plus`, `minus`, comparison. Pure. |
| Create `who-knows/src/world/universe.gd` | `Universe`: the origin, the focus, when and how to shift, the hold, conversions. |
| Create `who-knows/test/unit/test_universe_point.gd` | `UniversePoint` maths. |
| Create `who-knows/test/unit/test_universe.gd` | The shift, headless, with bare nodes. |
| Create `who-knows/test/unit/test_floating_origin_scene.gd` | The shift in the real flight scene; the coverage rule. |
| Modify `who-knows/src/ship/ship.gd` | The hull joins `exterior_space`. |
| Modify `who-knows/src/avatar/avatar.gd` | The spacewalker joins on `enter_suit`, leaves on `enter_plating`. |
| Modify `who-knows/src/world/debris_field.gd` | Joins `exterior_space` (until plan 2 replaces it). |
| Modify `who-knows/src/ship/airlock/airlock_show.gd` | The hull's world-space burst holds the shift. |
| Modify `who-knows/scenes/flight_test.tscn` | Adds the `Universe` node. |
| Modify `who-knows/scenes/flight_test.gd` | Sets the focus; an F3 debug readout. |
| Modify `docs/superpowers/specs/2026-08-21-who-knows-slice-1-design.md` | §3.3 amendment. |
| Modify `docs/superpowers/specs/2026-09-24-asteroids-design.md` | §15 "As built (plan 1)". |
| Modify `CLAUDE.md` | The exterior-space rule for every later change. |

---

### Task 1: UniversePoint

**Files:**
- Create: `who-knows/src/world/universe_point.gd`
- Test: `who-knows/test/unit/test_universe_point.gd`

**Interfaces:**
- Produces: `class_name UniversePoint extends RefCounted` with `var x: int`, `var y: int`,
  `var z: int`, `var fx: float`, `var fy: float`, `var fz: float` (fractions in [0, 1));
  `static func at(mx: int, my: int, mz: int) -> UniversePoint`;
  `func plus(offset: Vector3) -> UniversePoint`; `func minus(other: UniversePoint) -> Vector3`;
  `func is_equal_approx(other: UniversePoint) -> bool`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

## A position in the universe (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §4.1): whole metres as 64-bit ints plus a fraction, so it never shimmers
## however far out it is.

func test_a_step_carries_whole_metres_and_keeps_the_fraction():
	var u := UniversePoint.at(0, 0, 0).plus(Vector3(2.5, -0.25, 1000.75))
	assert_eq([u.x, u.y, u.z], [2, -1, 1000])
	assert_almost_eq(u.fx, 0.5, 1e-9)
	assert_almost_eq(u.fy, 0.75, 1e-9)
	assert_almost_eq(u.fz, 0.75, 1e-9)

func test_the_step_between_two_points_is_what_was_added():
	var a := UniversePoint.at(123456789012, -5, 7).plus(Vector3(0.25, 0.5, 0.125))
	var step := Vector3(1234.5, -987.25, 0.125)
	assert_eq(a.plus(step).minus(a), step)

func test_a_millimetre_still_counts_a_billion_kilometres_out():
	var far := UniversePoint.at(1_000_000_000_000, 0, 0)
	assert_almost_eq(far.plus(Vector3(0.001, 0, 0)).minus(far).x, 0.001, 1e-6)

func test_points_compare_by_position():
	var a := UniversePoint.at(3000, -2000, 0)
	assert_true(a.is_equal_approx(UniversePoint.at(2999, -2000, 0).plus(Vector3(1, 0, 0))))
	assert_false(a.is_equal_approx(UniversePoint.at(3000, -2000, 1)))

func test_a_fraction_never_reaches_a_whole_metre():
	var u := UniversePoint.at(0, 0, 0).plus(Vector3(0.9999999, 0, 0)).plus(Vector3(0.0000002, 0, 0))
	assert_eq(u.x, 1)
	assert_true(u.fx >= 0.0 and u.fx < 1.0)
```

- [ ] **Step 2: Run to verify they fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_universe_point'`
Expected: FAIL: parse error, `UniversePoint` not declared.

- [ ] **Step 3: Implement**

```gdscript
class_name UniversePoint
extends RefCounted

## A position in the universe (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §4.1): whole metres on each axis as 64-bit ints, and the part of a metre
## past them as 64-bit floats. The engine's own positions are 32-bit and
## shimmer far from its origin; these never do, however far you fly.

var x: int
var y: int
var z: int
## The part of a metre past (x, y, z), each in [0, 1).
var fx := 0.0
var fy := 0.0
var fz := 0.0

static func at(mx: int, my: int, mz: int) -> UniversePoint:
	var u := UniversePoint.new()
	u.x = mx
	u.y = my
	u.z = mz
	return u

## This point moved by `offset`, an engine-sized step.
func plus(offset: Vector3) -> UniversePoint:
	var u := UniversePoint.new()
	var vx := fx + offset.x
	var vy := fy + offset.y
	var vz := fz + offset.z
	var wx := floori(vx)
	var wy := floori(vy)
	var wz := floori(vz)
	u.x = x + wx
	u.y = y + wy
	u.z = z + wz
	u.fx = vx - wx
	u.fy = vy - wy
	u.fz = vz - wz
	return u

## The step from `other` to this point, as an engine vector: only meaningful
## for points within an engine's reach of each other.
func minus(other: UniversePoint) -> Vector3:
	return Vector3(
		float(x - other.x) + (fx - other.fx),
		float(y - other.y) + (fy - other.fy),
		float(z - other.z) + (fz - other.fz))

func is_equal_approx(other: UniversePoint) -> bool:
	return minus(other).is_zero_approx()

func _to_string() -> String:
	return "(%d + %f, %d + %f, %d + %f)" % [x, fx, y, fy, z, fz]
```

- [ ] **Step 4: Import pass, then run the tests**

Run: `& $godot --headless --path .\who-knows --import`, then
`& .\who-knows\run_tests.ps1 '-gselect=test_universe_point'`
Expected: 5/5 pass.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/world/universe_point.gd who-knows/src/world/universe_point.gd.uid who-knows/test/unit/test_universe_point.gd
git commit -m "feat: a 64-bit universe position that never shimmers"
```

---

### Task 2: Universe, the shift

**Files:**
- Create: `who-knows/src/world/universe.gd`
- Test: `who-knows/test/unit/test_universe.gd`

**Interfaces:**
- Consumes: `UniversePoint.at`, `plus`, `minus`, `is_equal_approx` (Task 1).
- Produces: `class_name Universe extends Node`; `signal shifted(delta: Vector3)`;
  `const EXTERIOR_SPACE := &"exterior_space"`; `const HOLDS_SHIFT := &"holds_origin_shift"`;
  `const SHIFT_AT := 2000.0`; `const FORCE_AT := 4000.0`; `const STEP := 1000.0`;
  `var origin: UniversePoint`; `var focus: Node3D`; `var shifts: int`;
  `func set_focus(body: Node3D) -> void`; `func check() -> bool`;
  `func shift(delta: Vector3) -> void`; `func is_held() -> bool`;
  `func to_universe(p: Vector3) -> UniversePoint`; `func to_engine(u: UniversePoint) -> Vector3`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

## The floating origin (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §4), headless, with bare nodes.

var _world: Node3D
var _universe: Universe

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_universe = Universe.new()
	_world.add_child(_universe)

func _member(at: Vector3) -> Node3D:
	var n := Node3D.new()
	_world.add_child(n)
	n.global_position = at
	n.add_to_group(Universe.EXTERIOR_SPACE)
	return n

func test_near_the_origin_nothing_moves():
	var focus := _member(Vector3(1999, -1999, 1999))
	_universe.set_focus(focus)
	assert_false(_universe.check())
	assert_eq(focus.global_position, Vector3(1999, -1999, 1999))
	assert_eq(_universe.shifts, 0)

func test_past_two_kilometres_the_origin_moves_in_whole_kilometres():
	var focus := _member(Vector3(2600, -2100, 30))
	_universe.set_focus(focus)
	assert_true(_universe.check())
	assert_eq(focus.global_position, Vector3(-400, -100, 30))
	assert_true(_universe.origin.is_equal_approx(UniversePoint.at(3000, -2000, 0)))
	assert_eq(_universe.shifts, 1)

func test_everything_outside_moves_together():
	var focus := _member(Vector3(2500, 0, 0))
	var rock := _member(Vector3(2600, 40, -70))
	_universe.set_focus(focus)
	_universe.check()
	assert_eq(rock.global_position - focus.global_position, Vector3(100, 40, -70))

func test_the_interior_never_moves():
	var focus := _member(Vector3(0, 0, 2500))
	var interior := Node3D.new()
	_world.add_child(interior)
	interior.global_position = Vector3(0, -5000, 0)
	_universe.set_focus(focus)
	_universe.check()
	assert_eq(interior.global_position, Vector3(0, -5000, 0))

func test_motion_survives_a_shift():
	var body := RigidBody3D.new()
	_world.add_child(body)
	body.add_to_group(Universe.EXTERIOR_SPACE)
	body.global_position = Vector3(3100, 0, 0)
	body.linear_velocity = Vector3(5, 0, 0)
	body.angular_velocity = Vector3(0, 1, 0)
	_universe.set_focus(body)
	_universe.check()
	assert_eq(body.global_position, Vector3(100, 0, 0))
	assert_eq(body.linear_velocity, Vector3(5, 0, 0))
	assert_eq(body.angular_velocity, Vector3(0, 1, 0))

func test_the_shift_is_announced():
	_universe.set_focus(_member(Vector3(-2600, 0, 0)))
	watch_signals(_universe)
	_universe.check()
	assert_signal_emitted_with_parameters(_universe, "shifted", [Vector3(-3000, 0, 0)])

func test_a_shift_changes_no_universe_position():
	var focus := _member(Vector3(2600, 10, 20))
	var rock := _member(Vector3(2750.25, -3.5, 12))
	_universe.set_focus(focus)
	var before := _universe.to_universe(rock.global_position)
	_universe.check()
	assert_true(_universe.to_universe(rock.global_position).is_equal_approx(before))

func test_engine_positions_round_trip_exactly():
	_universe.shift(Vector3(7000, -3000, 12000))
	var p := Vector3(1234.567, -89.5, 3.25)
	assert_eq(_universe.to_engine(_universe.to_universe(p)), p)

func test_a_live_world_space_effect_holds_the_shift_until_four_kilometres():
	var burst := GPUParticles3D.new()
	_world.add_child(burst)
	burst.add_to_group(Universe.HOLDS_SHIFT)
	burst.emitting = true
	var focus := _member(Vector3(2500, 0, 0))
	_universe.set_focus(focus)
	assert_true(_universe.is_held())
	assert_false(_universe.check(), "waits while the puffs are out")
	focus.global_position = Vector3(4100, 0, 0)
	assert_true(_universe.check(), "but never past 4 km")

func test_with_nothing_alive_nothing_holds():
	var burst := GPUParticles3D.new()
	_world.add_child(burst)
	burst.add_to_group(Universe.HOLDS_SHIFT)
	burst.emitting = false
	assert_false(_universe.is_held())

func test_without_a_focus_nothing_happens():
	_member(Vector3(9000, 0, 0))
	assert_false(_universe.check())

func test_it_goes_first_in_every_physics_tick():
	assert_lt(_universe.process_physics_priority, 0)
```

- [ ] **Step 2: Run to verify they fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_universe.gd'`
Expected: FAIL: `Universe` not declared.

- [ ] **Step 3: Implement**

```gdscript
class_name Universe
extends Node

## Where the engine's origin is in the universe, and the floating origin that
## keeps it near you (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §4).
##
## Engine positions are 32-bit floats: precise near the origin, shimmering tens
## of kilometres out. So when the focus -- the hull, or you on a spacewalk --
## strays SHIFT_AT from the origin, everything in exterior space moves back by
## the same whole kilometres, first thing in a physics tick. Nothing moves
## relative to anything else, so there is nothing to see. The interior is its
## own space and never moves.

## After a shift, for anything that remembers an engine position instead of
## being moved: subtract `delta` from it.
signal shifted(delta: Vector3)

## What the shift moves. Each member is moved itself, never through a parent:
## a member's parent never moves, so the member's own coordinates stay small.
const EXTERIOR_SPACE := &"exterior_space"
## World-space particles outside, which cannot be moved once emitted. While
## one is alive the shift waits, up to FORCE_AT.
const HOLDS_SHIFT := &"holds_origin_shift"

const SHIFT_AT := 2000.0
const FORCE_AT := 4000.0
## The origin moves in whole steps of this, so it is always exact.
const STEP := 1000.0

var origin := UniversePoint.new()
## Where "you" are: the hull aboard, the avatar on a spacewalk.
var focus: Node3D
## How many times the origin has moved: for the debug readout and live checks.
var shifts := 0

var _held_until_ms := 0

func _ready() -> void:
	process_physics_priority = -1000

func _physics_process(_delta: float) -> void:
	check()

func set_focus(body: Node3D) -> void:
	focus = body

## Moves the origin if the focus has strayed. True if it did.
func check() -> bool:
	if not is_instance_valid(focus) or not focus.is_inside_tree():
		return false
	var p := focus.global_position
	var far := maxf(absf(p.x), maxf(absf(p.y), absf(p.z)))
	if far <= SHIFT_AT:
		return false
	if far <= FORCE_AT and is_held():
		return false
	shift(Vector3(snappedf(p.x, STEP), snappedf(p.y, STEP), snappedf(p.z, STEP)))
	return true

## Moves the origin by `delta`, whole STEPs, and everything outside with it.
func shift(delta: Vector3) -> void:
	for node in get_tree().get_nodes_in_group(EXTERIOR_SPACE):
		var n := node as Node3D
		if n != null and n.is_inside_tree():
			n.global_position -= delta
	origin = origin.plus(delta)
	shifts += 1
	shifted.emit(delta)

## True while a world-space effect outside is alive: its emitting flag, and
## its particles' lifetime after.
func is_held() -> bool:
	var now := Time.get_ticks_msec()
	for node in get_tree().get_nodes_in_group(HOLDS_SHIFT):
		var p := node as GPUParticles3D
		if p != null and p.emitting:
			_held_until_ms = maxi(_held_until_ms, now + int(ceil(p.lifetime * 1000.0)))
	return now < _held_until_ms

func to_universe(p: Vector3) -> UniversePoint:
	return origin.plus(p)

func to_engine(u: UniversePoint) -> Vector3:
	return u.minus(origin)
```

- [ ] **Step 4: Import pass, then run the tests**

Run: the import pass, then `& .\who-knows\run_tests.ps1 '-gselect=test_universe.gd'`
Expected: 12/12 pass. (`-gselect=test_universe` would also match `test_universe_point`; either
is fine.)

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/world/universe.gd who-knows/src/world/universe.gd.uid who-knows/test/unit/test_universe.gd
git commit -m "feat: the floating origin -- shift everything outside in whole kilometres"
```

---

### Task 3: Into the flight scene

**Files:**
- Modify: `who-knows/scenes/flight_test.tscn` (ext_resource list; a node after `DirectionalLight3D`)
- Modify: `who-knows/scenes/flight_test.gd` (`_ready`, new `_wire_universe`, `_process`, `_unhandled_key_input`)
- Modify: `who-knows/src/ship/ship.gd:52` (`_ready`)
- Modify: `who-knows/src/avatar/avatar.gd` (`enter_suit`, `enter_plating`)
- Modify: `who-knows/src/world/debris_field.gd:46` (`_ready`)
- Modify: `who-knows/src/ship/airlock/airlock_show.gd:68-74` (`setup`, the `burst_only` branch)
- Test: `who-knows/test/unit/test_floating_origin_scene.gd`

**Interfaces:**
- Consumes: `Universe` and its constants (Task 2); `Avatar.mode_changed(mode: Avatar.Mode)`,
  `Avatar.Mode.SUIT`, `Avatar.enter_suit(outside, pose, start_velocity, ship_hull)`,
  `Avatar.enter_plating(interior, pose, pitch, start_velocity, righting)` (existing).
- Produces: the scene node `FlightTest/Universe`; `flight_test.gd`'s `_universe: Universe`;
  the readout label `Prompt/UniverseReadout` (hidden until F3).

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

## The floating origin in the real flight scene (docs/superpowers/specs/
## 2026-09-24-asteroids-design.md §4): who it follows, what it moves, and the
## rule that everything outside is covered.

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _universe: Universe
var _outside: Node3D

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_universe = _root.get_node_or_null("Universe") as Universe
	_outside = _root.get_node("Outside")

func _out(at: Vector3) -> void:
	_avatar.enter_suit(_outside, Transform3D(Basis.IDENTITY, at), Vector3.ZERO, _ship.exterior)

func _back_in() -> void:
	_avatar.enter_plating(_ship.interior, Transform3D(Basis.IDENTITY, _ship.interior.to_global(Vector3(0, -0.95, 6))),
		0.0, Vector3.ZERO, Quaternion.IDENTITY)

## A node is covered if it, or something above it, is shifted.
func _covered(node: Node) -> bool:
	while node != null:
		if node.is_in_group(Universe.EXTERIOR_SPACE):
			return true
		node = node.get_parent()
	return false

func _uncovered() -> Array:
	var out := []
	for n in _root.find_children("*", "Node3D", true, false):
		if not (n is PhysicsBody3D or n is GeometryInstance3D):
			continue
		if _ship.interior.is_ancestor_of(n):
			continue
		if not _covered(n):
			out.append(str(_root.get_path_to(n)))
	return out

func test_the_universe_survived_the_parse():
	assert_true(_universe is Universe, "FlightTest/Universe is a Universe")

func test_aboard_the_focus_is_the_hull():
	assert_eq(_universe.focus, _ship.exterior)
	assert_true(_ship.exterior.is_in_group(Universe.EXTERIOR_SPACE))

func test_on_a_spacewalk_the_focus_is_you_and_back_aboard_the_hull():
	_out(Vector3(0, 0, 12))
	assert_eq(_universe.focus, _avatar)
	assert_true(_avatar.is_in_group(Universe.EXTERIOR_SPACE))
	_back_in()
	assert_eq(_universe.focus, _ship.exterior)
	assert_false(_avatar.is_in_group(Universe.EXTERIOR_SPACE), "aboard, you never move")

func test_a_shift_moves_the_hull_and_leaves_the_interior():
	var interior_at := _ship.interior.global_position
	var avatar_at := _avatar.global_position
	_ship.exterior.global_position = Vector3(2500, 0, -40)
	assert_true(_universe.check())
	assert_eq(_ship.exterior.global_position, Vector3(-500, 0, -40))
	assert_eq(_ship.interior.global_position, interior_at)
	assert_eq(_avatar.global_position, avatar_at)

func test_a_spacewalk_across_a_shift_keeps_you_beside_your_ship():
	_ship.exterior.global_position = Vector3(0, 0, -2490)
	_out(Vector3(3, 1, -2478))
	var offset := _avatar.global_position - _ship.exterior.global_position
	_avatar.global_position += Vector3(0, 0, -20)
	offset += Vector3(0, 0, -20)
	assert_true(_universe.check())
	assert_almost_eq(_avatar.global_position - _ship.exterior.global_position, offset, Vector3.ONE * 0.0001)

func test_everything_outside_is_covered():
	assert_eq(_uncovered(), [], "every body and mesh outside the interior shifts")

func test_everything_outside_is_covered_on_a_spacewalk():
	_out(Vector3(0, 0, 12))
	assert_eq(_uncovered(), [])

func test_the_readout_starts_hidden():
	var label := _root.get_node_or_null("Prompt/UniverseReadout") as Label
	assert_not_null(label)
	assert_false(label.visible)
```

And in `who-knows/test/unit/test_airlock_show.gd`, append:

```gdscript
func test_the_burst_on_the_hull_holds_the_origin_shift():
	var hull_show := AirlockShow.new()
	add_child_autofree(hull_show)
	hull_show.setup(Transform3D.IDENTITY, [] as Array[Transform3D], null, 1, true)
	var burst: GPUParticles3D = hull_show.get_node("Burst")
	assert_true(burst.is_in_group(Universe.HOLDS_SHIFT), "its puffs are in world space")
```

- [ ] **Step 2: Run to verify they fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_floating_origin_scene'`
Expected: FAIL: `_universe` is null ("FlightTest/Universe is a Universe"), and the rest error on
the null.

- [ ] **Step 3: Implement**

`who-knows/scenes/flight_test.tscn`: change the header to `load_steps=27`, add after the last
`[ext_resource ...]` line:

```
[ext_resource type="Script" path="res://src/world/universe.gd" id="20_universe"]
```

and add this block after the `DirectionalLight3D` node's block (a blank line before and after,
no comments):

```
[node name="Universe" type="Node" parent="."]
script = ExtResource("20_universe")
```

`who-knows/scenes/flight_test.gd`: add beside the other `@onready` lines:

```gdscript
@onready var _universe: Universe = $Universe
```

beside the other `var`s:

```gdscript
var _universe_readout: Label
```

in `_ready()`, after `_wire_hands()`:

```gdscript
	_wire_universe()
```

and these functions after `_on_view_changed`:

```gdscript
## The floating origin (asteroids spec §4) follows whoever is outside: the
## hull, or you on a spacewalk. Wired here so neither Ship nor Avatar needs to
## know about Universe. F3 shows where you are in the universe.
func _wire_universe() -> void:
	_universe.set_focus(_ship.exterior)
	_avatar.mode_changed.connect(
		func(mode: Avatar.Mode) -> void:
			_universe.set_focus(_avatar if mode == Avatar.Mode.SUIT else _ship.exterior)
	)
	_universe_readout = Label.new()
	_universe_readout.name = "UniverseReadout"
	_universe_readout.position = Vector2(16, 16)
	_universe_readout.visible = false
	$Prompt.add_child(_universe_readout)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		_universe_readout.visible = not _universe_readout.visible

func _process(_delta: float) -> void:
	if not _universe_readout.visible or _universe.focus == null:
		return
	var u := _universe.to_universe(_universe.focus.global_position)
	_universe_readout.text = "universe %.3f, %.3f, %.3f km   origin shifts %d" % [
		(u.x + u.fx) / 1000.0, (u.y + u.fy) / 1000.0, (u.z + u.fz) / 1000.0, _universe.shifts]
```

`who-knows/src/ship/ship.gd`, in `_ready()` after `exterior.collision_mask = 1`:

```gdscript
	# Outside, so the floating origin moves it (asteroids spec §4.2).
	exterior.add_to_group(Universe.EXTERIOR_SPACE)
```

`who-knows/src/avatar/avatar.gd`, in `enter_suit` after `_move_to(outside)`:

```gdscript
	add_to_group(Universe.EXTERIOR_SPACE)
```

and in `enter_plating` after `_move_to(interior)`:

```gdscript
	remove_from_group(Universe.EXTERIOR_SPACE)
```

`who-knows/src/world/debris_field.gd`, in `_ready()` after `layers = 1`:

```gdscript
	# Moved by the floating origin until the asteroid stream replaces this
	# field (asteroids spec §10).
	add_to_group(Universe.EXTERIOR_SPACE)
```

`who-knows/src/ship/airlock/airlock_show.gd`, in `setup`'s `burst_only` branch, after
`_burst.explosiveness = 0.85`:

```gdscript
		# Its puffs are in world space, which a floating-origin shift cannot
		# move: the shift waits for them (asteroids spec §4.3).
		_burst.add_to_group(Universe.HOLDS_SHIFT)
```

- [ ] **Step 4: Run the new tests, then the whole suite**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_floating_origin_scene'`, then
`& .\who-knows\run_tests.ps1 '-gselect=test_airlock_show'`, then `& .\who-knows\run_tests.ps1`
Expected: 9/9, the airlock show file all passing, and the full suite all passing with nothing
new in the output. If `test_everything_outside_is_covered` lists a node, that node is a real gap:
make it (or the one node above it whose parent never moves) a member, don't exempt it.

- [ ] **Step 5: Commit**

```bash
git add who-knows/scenes/flight_test.tscn who-knows/scenes/flight_test.gd who-knows/src/ship/ship.gd who-knows/src/avatar/avatar.gd who-knows/src/world/debris_field.gd who-knows/src/ship/airlock/airlock_show.gd who-knows/test/unit/test_floating_origin_scene.gd who-knows/test/unit/test_airlock_show.gd
git commit -m "feat: the floating origin follows the hull, or you on a spacewalk"
```

---

### Task 4: The live check (spec §4.5)

A throwaway script in the session scratchpad, run against the real scene with a window (not
headless). It proves what tests cannot: that a shift is invisible.

**Files:**
- Create (scratchpad, not committed): `live_origin.gd`

- [ ] **Step 1: Write the check**

```gdscript
extends SceneTree

## Throwaway live check for the floating origin (asteroids spec §4.5).

const OUT := "<scratchpad>/live_origin/"

var scene: Node
var ship: Ship
var universe: Universe
var avatar: Avatar
var markers: Array[Node3D] = []

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(OUT)
	scene = load("res://scenes/flight_test.tscn").instantiate()
	root.add_child(scene)
	_run.call_deferred()

func p(s: String) -> void:
	print("LIVE: ", s)

func frames(n: int) -> void:
	for i in n:
		await process_frame

## A marker cube every `spacing` metres along -z, 30 m to the side, so there
## is always something near the ship to see jump if a shift were wrong.
func lay_markers(length: float, spacing: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 4.0
	var z := 0.0
	while z < length:
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.layers = 1
		scene.get_node("Outside").add_child(m)
		m.global_position = Vector3(30, 0, -z)
		m.add_to_group(Universe.EXTERIOR_SPACE)
		markers.append(m)
		z += spacing

func mean_diff(a: Image, b: Image) -> float:
	var sum := 0.0
	var n := 0
	for y in range(0, a.get_height(), 6):
		for x in range(0, a.get_width(), 6):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			sum += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			n += 1
	return sum / n

## Flies the focus at `speed` along -z for `metres`, and reports: the worst
## jump of any marker relative to the hull at a shift tick against ordinary
## ticks, the image change at shift frames against ordinary ones, and frames
## over 33 ms.
func fly(speed: float, metres: float, label: String) -> void:
	var hull := ship.exterior
	hull.linear_velocity = Vector3(0, 0, -speed)
	hull.angular_velocity = Vector3.ZERO
	var dt := 1.0 / Engine.physics_ticks_per_second
	var travelled := 0.0
	var last_rel := {}
	var worst_shift := 0.0
	var worst_plain := 0.0
	var shift_diffs: Array[float] = []
	var plain_diffs: Array[float] = []
	var slow := 0
	var prev_img: Image = null
	var t0 := Time.get_ticks_msec()
	var start := hull.global_position
	var shifts0 := universe.shifts
	var u0 := universe.to_universe(hull.global_position)
	while travelled < metres:
		var shifts_before := universe.shifts
		await physics_frame
		var shifted := universe.shifts != shifts_before
		for m in markers:
			var rel := m.global_position - hull.global_position
			if last_rel.has(m):
				var err := (rel - last_rel[m] - Vector3(0, 0, speed * dt)).length()
				if shifted:
					worst_shift = maxf(worst_shift, err)
				else:
					worst_plain = maxf(worst_plain, err)
			last_rel[m] = rel
		var near := maxf(absf(hull.global_position.z), 0.0) > Universe.SHIFT_AT - speed * 0.15
		if near or shifted:
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			if prev_img != null:
				(shift_diffs if shifted else plain_diffs).append(mean_diff(prev_img, img))
			prev_img = img
		else:
			prev_img = null
		var now := Time.get_ticks_msec()
		if now - t0 > 33 and travelled > 200.0:
			slow += 1
		t0 = now
		travelled = u0.minus(universe.to_universe(hull.global_position)).length()
	p("%s: %.1f km in %d shifts; marker error at shift %.5f m vs plain %.5f m; image change at shift %s vs plain max %.4f; frames over 33 ms: %d" % [
		label, travelled / 1000.0, universe.shifts - shifts0, worst_shift, worst_plain,
		str(shift_diffs), plain_diffs.max() if plain_diffs.size() > 0 else 0.0, slow])

func _run() -> void:
	await frames(5)
	ship = scene.get_node("Ship")
	universe = scene.get_node("Universe")
	avatar = scene.get_node("Ship/Interior/Avatar")
	ship.flight_computer.process_mode = Node.PROCESS_MODE_DISABLED
	ship.get_node("Exterior/ChaseCamera").current = true
	lay_markers(62000.0, 400.0)
	await fly(1000.0, 50000.0, "50 km at 1 km/s")
	await fly(300.0, 10000.0, "10 km at boost")
	# A spacewalk across shifts: you beside your moving ship.
	var hull := ship.exterior
	hull.linear_velocity = Vector3(0, 0, -300)
	avatar.enter_suit(scene.get_node("Outside"), Transform3D(Basis.IDENTITY,
		hull.global_position + Vector3(3, 1, 12)), hull.linear_velocity, hull)
	await frames(2)
	p("spacewalk focus is you: %s" % (universe.focus == avatar))
	var offset := avatar.global_position - hull.global_position
	var shifts0 := universe.shifts
	var worst := 0.0
	while universe.shifts < shifts0 + 2:
		await physics_frame
		worst = maxf(worst, (avatar.global_position - hull.global_position - offset).length())
	p("spacewalk across 2 shifts: worst drift from your ship %.4f m (the suit assist holds you, so ~0)" % worst)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "spacewalk_after_shift.png")
	quit()
```

- [ ] **Step 2: Run it**

Run (PowerShell, from the worktree):
`& $godot --path .\who-knows -s "<scratchpad>/live_origin.gd" 2>&1 | Select-String "LIVE|ERROR|SCRIPT ERROR"`
Expected:
- marker error at shift within 0.001 m of the plain-tick error (both float noise, under 1 mm);
- image change at every shift frame no larger than the largest plain frame change;
- frames over 33 ms: 0;
- spacewalk focus is you: true; worst drift from your ship under 0.01 m.

- [ ] **Step 3: Fix whatever it finds**

Any failure is a real bug in Tasks 1–3: find which node or position was left behind, cover it
under the rules in Global Constraints, add a test to `test_floating_origin_scene.gd` that fails
without the fix, re-run the check. Commit each fix with its test.

---

### Task 5: Docs, merge, and the owner's flight

**Files:**
- Modify: `docs/superpowers/specs/2026-08-21-who-knows-slice-1-design.md` (§3.3)
- Modify: `docs/superpowers/specs/2026-09-24-asteroids-design.md` (new §15)
- Modify: `CLAUDE.md`

- [ ] **Step 1: The slice spec's §3.3 amendment.** After the existing 2026-09-23 amendment block
  in §3.3, add:

```markdown
> **Amended 2026-09-24 (asteroids spec §4):** there is now a **floating origin**. When the focus
> (the hull, or you on a spacewalk) strays 2 km from the engine origin, everything in exterior
> space moves back by the same whole kilometres in one physics tick; `Universe` keeps the true
> position in 64-bit. The interior never moves. Anything outside joins `&"exterior_space"` or
> listens to `Universe.shifted`.
```

- [ ] **Step 2: The asteroid spec's "As built (plan 1)".** Append:

```markdown
---

## 15. As built (plan 1: the floating origin, 2026-09-24)

- The focus is set by `flight_test.gd` (the scene bootstrap), on `Avatar.mode_changed`, rather
  than by `Ship` and `Avatar` as §4.2 had it: neither needs to know about `Universe`.
- `F3` in the flight test toggles a readout of your universe position and the shift count.
- Live check (§4.5): <fill in from Task 4's output: distances, shift counts, marker error at shift
  vs plain, image change at shift vs plain, frames over 33 ms, spacewalk drift>.
```

  (Replace the angle-bracket line with the real numbers from Task 4 before committing; it is a
  fill-in for the executor, not a placeholder to leave.)

- [ ] **Step 3: `CLAUDE.md`.** Add a section after the visual-style section:

```markdown
## Exterior space has a floating origin

The outside world is re-centred on you every 2 km (`src/world/universe.gd`,
`docs/superpowers/specs/2026-09-24-asteroids-design.md` §4). **Anything you put outside the ship
must either join group `Universe.EXTERIOR_SPACE` (a node whose parent never moves; it is moved
itself, never through a parent) or listen to `Universe.shifted(delta)` and subtract `delta` from
any engine position it remembers.** World-space particles outside join `Universe.HOLDS_SHIFT`.
The interior never moves and is never a member. `test_floating_origin_scene.gd` fails if a body
or mesh outside the interior is not covered. Positions that must survive a shift (seeds, homes,
saved places) are `UniversePoint`s, never engine `Vector3`s.
```

- [ ] **Step 4: Full suite, then commit**

Run: `& .\who-knows\run_tests.ps1`
Expected: all passing, output pristine.

```bash
git add docs/superpowers/specs/2026-08-21-who-knows-slice-1-design.md docs/superpowers/specs/2026-09-24-asteroids-design.md CLAUDE.md
git commit -m "docs: record the floating origin and the rule for everything outside"
```

- [ ] **Step 5: Merge and push.** If `main` moved, merge it into the branch and re-run the suite.
  In `D:\git\whoknows` (only when clean and on `main`): `git merge --no-ff floating-origin`, run
  the import pass there, run the suite there, `git push origin main`, then
  `git worktree remove D:/git/whoknows-origin` and `git branch -d floating-origin`.

- [ ] **Step 6: Go on to plan 2.** The owner asked (2026-09-24) for planning and implementation
  to continue autonomously, with renders to review at the end, so the flight gate becomes part of
  that final review: boost for a minute (F3 shows the shifts ticking up), and spacewalk while
  drifting. Plan 2 is written once Task 4's live check passes.
```
