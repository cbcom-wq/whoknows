# Who Knows — Slice 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a ship out of blocks in an editor, launch it, fly it, then stand up mid-burn and walk to the back of your own accelerating ship without a cut or a loading screen.

**Architecture:** One `ShipGrid` (a `Dictionary[Vector3i, BlockInstance]`) is the single source of truth. Two independent readers render it: an `ExteriorBuilder` that produces a flying `RigidBody3D` hull, and an `InteriorBuilder` that produces a permanently stationary walkable interior parked in a separate physics world. The avatar always walks in the stationary interior, so there is never a moving floor; the hull's real acceleration is piped into interior space deliberately as a shove force and camera shake.

**Tech Stack:** Godot 4.5.1 (mono build, GDScript only), GUT 9.5.0 for unit tests, PowerShell wrapper for headless test runs.

## Global Constraints

- **Engine:** Godot 4.5.1 stable. Executable at `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe`. Override with the `GODOT_BIN` environment variable.
- **Language:** GDScript only. Do not add C# scripts — the mono build is incidental, and adding one generates a `.csproj` that complicates the build.
- **Godot project root:** `who-knows/` (so `res://` maps to `D:\git\whoknows\who-knows`). The plan and spec live one level up in `docs/`.
- **Cell size:** `2.0` metres. Declared once as `ShipGrid.CELL_SIZE` and never hardcoded elsewhere.
- **Cell geometry:** a cell at `coord` occupies the axis-aligned box centred on `Vector3(coord) * CELL_SIZE`.
- **Thrust direction:** a thruster's force acts along its block-local **−Z** (Godot's forward). Exhaust vents the opposite way. `thrust_kn` is kilonewtons; multiply by `1000.0` for newtons.
- **Walkable set:** `DECK ∪ MOUNT`. One `BlockInstance` per cell; MOUNT blocks occupy their own cell and are walkable.
- **Grid mutation:** only `ShipGrid.set_block()` and `ShipGrid.clear_block()` may write to the cell dictionary. Every other system reacts to the `cell_changed` signal. This is the architectural choke point — a reviewer should reject any code that writes cells directly.
- **Interior world slots:** interiors are parked on a slot grid with `10000.0` metre spacing, `slot_origin(i) = Vector3(i * 10000.0, 0, 0)`. Slice 1 uses slot `0` only.
- **Test naming:** GUT test files are `test/unit/test_<subject>.gd`, classes `extends GutTest`, methods `test_<behaviour>()`.

## Task type legend

Tasks are marked by how they are verified. Both kinds are mandatory; they differ in what "green" means.

- **[LOGIC]** — pure logic. Strict TDD: failing test first, then minimal implementation. Verified by GUT.
- **[FEEL]** — scenes, cameras, input, physics tuning. Cannot be meaningfully unit tested. Verified by running the game and checking explicit, written observations. Each of these tasks lists exactly what you must see.

---

## File structure

```
who-knows/
  project.godot                     modified: input map, autoloads, physics
  .gutconfig.json                   created: headless test config
  addons/gut/                       created: vendored GUT 9.5.0

  data/blocks/*.tres                created: 15 BlockDefinition resources
  data/blueprints/                  created: saved ShipBlueprint resources

  src/ship/orientation.gd           the 24 axis-aligned rotations
  src/ship/block_definition.gd      Resource: one block type
  src/ship/block_instance.gd        Resource: one placed block
  src/ship/block_catalog.gd         id -> BlockDefinition lookup
  src/ship/ship_grid.gd             the source of truth + mutation choke point
  src/ship/deck_graph.gd            walkable connectivity
  src/ship/ship_validator.gd        the five rules
  src/ship/ship_stats.gd            mass, CoM, inertia, thrust, torque, power
  src/ship/ship_blueprint.gd        Resource: serializable grid
  src/ship/exterior_builder.gd      grid -> hull mesh + collision
  src/ship/interior_builder.gd      grid -> floors, walls, navmesh
  src/ship/ship.gd                  owns a grid and both representations

  src/flight/flight_computer.gd     assisted Newtonian control
  src/flight/thruster_solver.gd     desired accel -> per-thruster firing

  src/avatar/avatar.gd              CharacterBody3D in interior space
  src/avatar/interactor.gd          raycast + prompt
  src/avatar/pilot_seat.gd          the sit/stand handoff

  src/camera/camera_director.gd     four views + the seat transition
  src/camera/motion_coupling.gd     hull accel -> shove force + shake + skybox

  src/editor/shipyard.gd            placement, orbit camera, ghost
  src/editor/deck_slicer.gd         Z-level cutaway
  src/editor/palette_panel.gd       block picker UI
  src/editor/stats_panel.gd         live stats + validation UI

  scenes/ship.tscn                  scenes/avatar.tscn
  scenes/flight_test.tscn           scenes/shipyard.tscn

  test/unit/test_*.gd               GUT suite
  run_tests.ps1                     headless test runner
```

`exterior_builder.gd` and `interior_builder.gd` never reference each other. They are two independent readers of one source of truth, which is exactly what makes the parity test in Task 13 and Task 14 meaningful.

---

# Phase A — Foundations and the risky spike

Phase A builds the feel prototype on hand-authored scenes, **before** the grid or the editor exist. If Task 6 does not feel extraordinary, stop and revisit the design — that is the whole point of ordering it this way.

---

### Task 1: Project scaffold and headless test harness [LOGIC]

**Files:**
- Create: `who-knows/addons/gut/` (vendored)
- Create: `who-knows/.gutconfig.json`
- Create: `who-knows/run_tests.ps1`
- Create: `who-knows/test/unit/test_harness.gd`
- Modify: `who-knows/project.godot`

**Interfaces:**
- Consumes: nothing
- Produces: a working `./run_tests.ps1` that exits non-zero on failure. Every later task's test steps invoke it.

- [ ] **Step 1: Vendor GUT**

Download GUT 9.5.0 and place it so that `who-knows/addons/gut/plugin.cfg` exists.

```bash
curl -L -o /tmp/gut.zip https://github.com/bitwes/Gut/archive/refs/tags/v9.5.0.zip
unzip -q /tmp/gut.zip -d /tmp/gut
cp -r /tmp/gut/Gut-9.5.0/addons/gut "D:/git/whoknows/who-knows/addons/gut"
ls "D:/git/whoknows/who-knows/addons/gut/plugin.cfg"
```

- [ ] **Step 2: Create the GUT config**

Create `who-knows/.gutconfig.json`:

```json
{
  "dirs": ["res://test/unit"],
  "include_subdirs": true,
  "log_level": 1,
  "should_exit": true,
  "should_maximize": false,
  "prefix": "test_",
  "suffix": ".gd"
}
```

- [ ] **Step 3: Create the test runner**

Create `who-knows/run_tests.ps1`:

```powershell
$ErrorActionPreference = "Stop"
$godot = $env:GODOT_BIN
if (-not $godot) {
    $godot = "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe"
}
if (-not (Test-Path $godot)) { throw "Godot not found at $godot. Set GODOT_BIN." }

& $godot --headless --path $PSScriptRoot -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
exit $LASTEXITCODE
```

- [ ] **Step 4: Enable the plugin and register source paths**

In `who-knows/project.godot`, add:

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[physics]

3d/default_gravity=0.0
```

Setting default gravity to zero is deliberate: the exterior hull must not fall. Interior gravity is applied per-avatar by Grav Plating, not by the world.

- [ ] **Step 5: Write a harness smoke test**

Create `who-knows/test/unit/test_harness.gd`:

```gdscript
extends GutTest

func test_harness_runs():
	assert_true(true, "GUT harness executes")

func test_godot_version_is_4_5_or_later():
	var info := Engine.get_version_info()
	assert_true(
		info.major > 4 or (info.major == 4 and info.minor >= 5),
		"Expected Godot 4.5+, got %d.%d" % [info.major, info.minor]
	)
```

- [ ] **Step 6: Run the suite and verify it passes**

```bash
powershell -File "D:/git/whoknows/who-knows/run_tests.ps1"
```

Expected: 2 passing tests, exit code 0. If Godot reports the plugin is not enabled, open the project once in the editor to let it import `addons/`.

- [ ] **Step 7: Commit**

```bash
git add who-knows/
git commit -m "chore: scaffold Godot project with GUT headless test harness"
```

---

### Task 2: The two-world scaffold [FEEL]

**Files:**
- Create: `who-knows/scenes/flight_test.tscn`
- Create: `who-knows/src/ship/ship.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `Ship` node with `exterior: RigidBody3D`, `interior: Node3D`, and `func interior_slot_origin() -> Vector3`. Tasks 3–6 attach to these.

This task builds the split as raw scene structure with a hand-placed hull and a hand-placed room. No grid yet.

- [ ] **Step 1: Write the Ship node script**

Create `who-knows/src/ship/ship.gd`:

```gdscript
class_name Ship
extends Node3D

## Owns one ship's two representations. In Slice 1 the geometry under
## each is hand-authored; from Task 15 both are generated from a ShipGrid.

const SLOT_SPACING := 10000.0

@export var interior_slot: int = 0

@onready var exterior: RigidBody3D = $Exterior
@onready var interior: Node3D = $Interior

func _ready() -> void:
	exterior.gravity_scale = 0.0
	exterior.linear_damp = 0.0
	exterior.angular_damp = 0.0
	exterior.can_sleep = false
	interior.global_position = interior_slot_origin()

func interior_slot_origin() -> Vector3:
	return Vector3(interior_slot * SLOT_SPACING, 0.0, 0.0)
```

- [ ] **Step 2: Build the flight test scene**

Create `who-knows/scenes/flight_test.tscn` with this node tree. Build it in the Godot editor.

```
FlightTest (Node3D)
├── WorldEnvironment          Environment: sky = ProceduralSkyMaterial, starfield-dark
├── DirectionalLight3D        rotated to rake the hull
└── Ship (Node3D, ship.gd)
    ├── Exterior (RigidBody3D)
    │   ├── Hull (MeshInstance3D)      BoxMesh 8 x 4 x 12
    │   └── Collider (CollisionShape3D) BoxShape3D 8 x 4 x 12
    └── Interior (Node3D)
        ├── Floor (StaticBody3D + CollisionShape3D)  BoxShape3D 6 x 0.2 x 10, at y = -0.1
        ├── Ceiling (StaticBody3D + CollisionShape3D) BoxShape3D 6 x 0.2 x 10, at y = 2.1
        ├── WallN / WallS / WallE / WallW (StaticBody3D + CollisionShape3D)
        └── SeatMarker (Marker3D) at (0, 0, -3.5)
```

The interior room is 6m × 10m with 2m headroom — one deck of a corvette. `SeatMarker` is where the pilot seat goes in Task 5.

- [ ] **Step 3: Run the scene and verify the split**

Open `flight_test.tscn` in Godot and press F6.

Expected observations:
- The hull box is visible at the world origin.
- The interior room exists at x = 0 (slot 0 resolves to the origin in Slice 1) but is a separate, non-parented subtree.
- Nothing moves. Nothing falls. If the hull falls, `3d/default_gravity` was not set to 0 in Task 1.

- [ ] **Step 4: Commit**

```bash
git add who-knows/
git commit -m "feat: add Ship node with interior/exterior split scaffold"
```

---

### Task 3: Avatar controller in interior space [FEEL]

**Files:**
- Create: `who-knows/src/avatar/avatar.gd`
- Create: `who-knows/scenes/avatar.tscn`
- Modify: `who-knows/project.godot` (input map)
- Modify: `who-knows/scenes/flight_test.tscn`

**Interfaces:**
- Consumes: `Ship.interior` from Task 2
- Produces: `Avatar` with `head: Node3D` (camera mount point at eye height), `func set_control_enabled(enabled: bool) -> void`, and `var external_accel: Vector3` (written by Task 6).

- [ ] **Step 1: Add the input map**

In `who-knows/project.godot`, add:

```ini
[input]

move_forward={"deadzone":0.2,"events":[{"device":-1,"keycode":87,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
move_back={"deadzone":0.2,"events":[{"device":-1,"keycode":83,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
move_left={"deadzone":0.2,"events":[{"device":-1,"keycode":65,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
move_right={"deadzone":0.2,"events":[{"device":-1,"keycode":68,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
sprint={"deadzone":0.2,"events":[{"device":-1,"keycode":4194325,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
crouch={"deadzone":0.2,"events":[{"device":-1,"keycode":4194326,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
interact={"deadzone":0.2,"events":[{"device":-1,"keycode":70,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
roll_left={"deadzone":0.2,"events":[{"device":-1,"keycode":81,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
roll_right={"deadzone":0.2,"events":[{"device":-1,"keycode":69,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
boost={"deadzone":0.2,"events":[{"device":-1,"keycode":32,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
toggle_assist={"deadzone":0.2,"events":[{"device":-1,"keycode":90,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
cycle_camera={"deadzone":0.2,"events":[{"device":-1,"keycode":86,"physical_keycode":0,"type":"InputEventKey","pressed":true}]}
```

- [ ] **Step 2: Write the avatar controller**

Create `who-knows/src/avatar/avatar.gd`:

```gdscript
class_name Avatar
extends CharacterBody3D

## Walks in interior space. Interior geometry never moves, so this is an
## ordinary character controller. All felt motion from the ship arrives
## through `external_accel`, written by MotionCoupling (Task 6).

const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.0
const ACCEL := 30.0
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := deg_to_rad(89.0)
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0

## Local gravity, supplied by Grav Plating. Zero means the cell is unplated.
var grav_strength: float = 9.8

## Acceleration felt from the hull, in interior-space metres per second squared.
var external_accel: Vector3 = Vector3.ZERO

var _control_enabled: bool = true
var _yaw: float = 0.0
var _pitch: float = 0.0

@onready var head: Node3D = $Head
@onready var _collider: CollisionShape3D = $Collider

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not _control_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		rotation.y = _yaw
		head.rotation.x = _pitch

func _physics_process(delta: float) -> void:
	# Gravity plus whatever the hull is doing to us. Both are just
	# accelerations; the avatar cannot tell them apart, which is the point.
	velocity += (Vector3.DOWN * grav_strength + external_accel) * delta

	if _control_enabled:
		var crouching := Input.is_action_pressed("crouch")
		_apply_height(CROUCH_HEIGHT if crouching else STAND_HEIGHT)

		var speed := CROUCH_SPEED if crouching else (
			SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
		)
		var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var wish := (transform.basis * Vector3(input_2d.x, 0.0, input_2d.y)).normalized()
		var target := wish * speed
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)

	move_and_slide()

func _apply_height(height: float) -> void:
	var capsule := _collider.shape as CapsuleShape3D
	capsule.height = height
	_collider.position.y = height * 0.5
	head.position.y = height - 0.2
```

- [ ] **Step 3: Build the avatar scene**

Create `who-knows/scenes/avatar.tscn`:

```
Avatar (CharacterBody3D, avatar.gd)
├── Collider (CollisionShape3D)   CapsuleShape3D, radius 0.35, height 1.8
└── Head (Node3D)                 at (0, 1.6, 0)
    └── Camera3D                  current = true
```

- [ ] **Step 4: Place the avatar in the flight test**

In `flight_test.tscn`, instance `avatar.tscn` under `Ship/Interior` at position `(0, 0.1, 3.0)` — inside the room, near the aft wall.

- [ ] **Step 5: Run and verify**

Press F6 on `flight_test.tscn`.

Expected observations:
- Mouse look is smooth, pitch clamps just short of straight up and down.
- WASD walks; Shift sprints noticeably; Ctrl crouches and lowers the camera.
- You collide with all four walls and cannot leave the room.
- You stand on the floor and do not sink or jitter.

- [ ] **Step 6: Commit**

```bash
git add who-knows/
git commit -m "feat: add avatar controller walking in interior space"
```

---

### Task 4: Assisted Newtonian flight [FEEL]

**Files:**
- Create: `who-knows/src/flight/flight_computer.gd`
- Modify: `who-knows/scenes/flight_test.tscn`

**Interfaces:**
- Consumes: `Ship.exterior` from Task 2
- Produces: `FlightComputer` with `var assist_enabled: bool`, `var thrust_budget: Dictionary` (keys `&"forward" &"reverse" &"lateral" &"vertical"`, values newtons), `var torque_budget: Vector3`, and `func set_pilot_input(translate: Vector3, rotate: Vector3, boost: bool) -> void`. Task 15 replaces the hardcoded budgets with values from `ShipStats`.

- [ ] **Step 1: Write the flight computer**

Create `who-knows/src/flight/flight_computer.gd`:

```gdscript
class_name FlightComputer
extends Node

## Assisted Newtonian control of a hull RigidBody3D.
##
## Assist on: counters lateral drift, damps residual rotation, holds a
## cruise ceiling. Assist off: raw Newtonian, input maps straight to thrust.

const CRUISE_LIMIT_MPS := 120.0
const BOOST_MULTIPLIER := 2.5
const DRIFT_AUTHORITY := 0.6   ## fraction of budget assist may spend on drift
const ROTATION_DAMPING := 3.0

@export var hull_path: NodePath

var assist_enabled: bool = true

## Newtons available along each axis. Overwritten from ShipStats in Task 15.
var thrust_budget: Dictionary = {
	&"forward": 900_000.0,
	&"reverse": 300_000.0,
	&"lateral": 250_000.0,
	&"vertical": 250_000.0,
}
## Newton-metres available about each local axis (pitch, yaw, roll).
var torque_budget: Vector3 = Vector3(4_000_000.0, 4_000_000.0, 2_500_000.0)

var _translate_input: Vector3 = Vector3.ZERO
var _rotate_input: Vector3 = Vector3.ZERO
var _boost: bool = false

@onready var _hull: RigidBody3D = get_node(hull_path)

func set_pilot_input(translate: Vector3, rotate: Vector3, boost: bool) -> void:
	_translate_input = translate
	_rotate_input = rotate
	_boost = boost

func clear_pilot_input() -> void:
	# Called when the pilot stands up. Translation input latches at its last
	# value (the burn continues), rotation input does not (the ship stops
	# turning). This is what makes leaving the seat mid-burn interesting.
	_rotate_input = Vector3.ZERO

func _physics_process(delta: float) -> void:
	_apply_translation(delta)
	_apply_rotation(delta)

func _apply_translation(delta: float) -> void:
	var basis := _hull.global_transform.basis
	var force := Vector3.ZERO

	var longitudinal := _translate_input.z
	if longitudinal < 0.0:
		force += basis * Vector3(0, 0, -1) * absf(longitudinal) * thrust_budget[&"forward"]
	elif longitudinal > 0.0:
		force += basis * Vector3(0, 0, 1) * longitudinal * thrust_budget[&"reverse"]

	force += basis * Vector3(_translate_input.x, 0, 0) * thrust_budget[&"lateral"]
	force += basis * Vector3(0, _translate_input.y, 0) * thrust_budget[&"vertical"]

	if _boost:
		force *= BOOST_MULTIPLIER

	if assist_enabled:
		force += _drift_correction(basis)

	_hull.apply_central_force(force)

	if assist_enabled and _hull.linear_velocity.length() > CRUISE_LIMIT_MPS:
		_hull.linear_velocity = _hull.linear_velocity.normalized() * CRUISE_LIMIT_MPS

func _drift_correction(basis: Basis) -> Vector3:
	# Cancel velocity components the pilot is not asking for.
	var local_vel := basis.inverse() * _hull.linear_velocity
	var unwanted := Vector3(
		local_vel.x if is_zero_approx(_translate_input.x) else 0.0,
		local_vel.y if is_zero_approx(_translate_input.y) else 0.0,
		local_vel.z if is_zero_approx(_translate_input.z) else 0.0,
	)
	var authority := Vector3(
		thrust_budget[&"lateral"], thrust_budget[&"vertical"], thrust_budget[&"reverse"]
	) * DRIFT_AUTHORITY
	var correction := Vector3(
		clampf(-unwanted.x * _hull.mass, -authority.x, authority.x),
		clampf(-unwanted.y * _hull.mass, -authority.y, authority.y),
		clampf(-unwanted.z * _hull.mass, -authority.z, authority.z),
	)
	return basis * correction

func _apply_rotation(_delta: float) -> void:
	var basis := _hull.global_transform.basis
	var torque := basis * (_rotate_input * torque_budget)
	_hull.apply_torque(torque)

	if assist_enabled:
		var residual := _hull.angular_velocity
		var damping := -residual * ROTATION_DAMPING * _hull.mass
		_hull.apply_torque(damping)
```

- [ ] **Step 2: Add a temporary pilot input driver**

Add this to `flight_test.tscn` as a script on the root `FlightTest` node. It is replaced by the seat in Task 5, but it lets you fly *now*.

Create `who-knows/scenes/flight_test.gd`:

```gdscript
extends Node3D

@onready var _fc: FlightComputer = $Ship/FlightComputer

func _ready() -> void:
	# This temporary driver borrows the same WASD actions the avatar walks
	# with. Without this, W would walk the avatar AND fire the engines.
	# Task 5 replaces the whole arrangement with the pilot seat, which hands
	# control back and forth properly.
	$Ship/Interior/Avatar.set_control_enabled(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_assist"):
		_fc.assist_enabled = not _fc.assist_enabled
		print("Flight assist: ", "ON" if _fc.assist_enabled else "OFF")

func _process(_delta: float) -> void:
	var translate := Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("crouch", "sprint"),
		Input.get_axis("move_forward", "move_back"),
	)
	var mouse := Vector2.ZERO  # replaced by real mouse look in Task 5
	var rotate := Vector3(
		mouse.y, mouse.x, Input.get_axis("roll_left", "roll_right")
	)
	_fc.set_pilot_input(translate, rotate, Input.is_action_pressed("boost"))
```

- [ ] **Step 3: Wire the scene**

In `flight_test.tscn`:
- Add `FlightComputer` (Node, `flight_computer.gd`) under `Ship`, with `hull_path` set to `../Exterior`.
- Set `Ship/Exterior` mass to `42000.0` (42 tonnes, a plausible corvette).
- Add a `Camera3D` under `Ship/Exterior` at `(0, 4, 18)` looking forward, `current = true`. This is a placeholder chase camera until Task 5.
- Set the avatar's `Camera3D` to `current = false` for now.
- Attach `flight_test.gd` to the root.

- [ ] **Step 4: Run and verify**

Press F6.

Expected observations:
- W accelerates forward; the starfield moves.
- Release W with assist ON: the ship coasts, then drift on X and Y bleeds off while forward velocity is retained.
- Press Z to toggle assist OFF, then strafe and release: the ship keeps drifting sideways forever.
- Space noticeably boosts acceleration.
- With assist ON, speed stops climbing at 120 m/s.

- [ ] **Step 5: Commit**

```bash
git add who-knows/
git commit -m "feat: add assisted Newtonian flight computer"
```

---

### Task 5: The seat, and the seamless transition [FEEL]

**Files:**
- Create: `who-knows/src/avatar/interactor.gd`
- Create: `who-knows/src/avatar/pilot_seat.gd`
- Create: `who-knows/src/camera/camera_director.gd`
- Modify: `who-knows/scenes/flight_test.tscn`
- Delete: `who-knows/scenes/flight_test.gd` (the temporary driver from Task 4)

**Interfaces:**
- Consumes: `Avatar.set_control_enabled()`, `Avatar.head`, `FlightComputer.set_pilot_input()`
- Produces: `CameraDirector` with `enum View { COCKPIT, CHASE, FOOT_FIRST, FOOT_THIRD }`, `func sit(seat: PilotSeat) -> void`, `func stand() -> void`, `func cycle_view() -> void`, and `signal transition_finished`.

**This is the money moment of the slice. The camera must never cut.**

- [ ] **Step 1: Write the interactor**

Create `who-knows/src/avatar/interactor.gd`:

```gdscript
class_name Interactor
extends RayCast3D

## Points where the avatar looks. Anything in group "interactable" that
## implements `interact(avatar)` and `prompt_text()` can be used.

signal prompt_changed(text: String)

var _current: Node = null

func _ready() -> void:
	target_position = Vector3(0, 0, -2.5)
	collide_with_areas = true

func _physics_process(_delta: float) -> void:
	var hit: Node = get_collider() if is_colliding() else null
	if hit != null and not hit.is_in_group("interactable"):
		hit = null
	if hit != _current:
		_current = hit
		prompt_changed.emit("" if _current == null else "[F] %s" % _current.prompt_text())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current != null:
		_current.interact(owner)
```

- [ ] **Step 2: Write the pilot seat**

Create `who-knows/src/avatar/pilot_seat.gd`:

```gdscript
class_name PilotSeat
extends StaticBody3D

## The flight station. Sitting here hands ship control to the pilot and
## moves the camera into the cockpit without a cut.

@export var camera_director_path: NodePath

## Where the seated camera ends up, and which way it faces.
@onready var eye: Node3D = $Eye

func _ready() -> void:
	add_to_group("interactable")

func prompt_text() -> String:
	return "Take the controls"

func interact(avatar: Avatar) -> void:
	var director: CameraDirector = get_node(camera_director_path)
	director.sit(self)
	# `avatar` is unused here; the director owns the handoff. Kept in the
	# signature because every interactable receives it.
```

- [ ] **Step 3: Write the camera director**

Create `who-knows/src/camera/camera_director.gd`:

```gdscript
class_name CameraDirector
extends Node

## Owns all four views and, critically, the continuous move between
## standing and sitting. The transition happens entirely inside interior
## space, so it is a plain interpolation of one camera's transform —
## there is no world switch and therefore nothing to hide with a fade.

signal transition_finished

enum View { COCKPIT, CHASE, FOOT_FIRST, FOOT_THIRD }

const SIT_DURATION := 0.75
const THIRD_PERSON_OFFSET := Vector3(0.5, 0.4, 2.5)

@export var avatar_path: NodePath
@export var flight_computer_path: NodePath
@export var interior_camera_path: NodePath
@export var chase_camera_path: NodePath

var view: View = View.FOOT_FIRST
var is_seated: bool = false

var _seat: PilotSeat = null
var _tween: Tween = null

@onready var _avatar: Avatar = get_node(avatar_path)
@onready var _flight: FlightComputer = get_node(flight_computer_path)
@onready var _interior_cam: Camera3D = get_node(interior_camera_path)
@onready var _chase_cam: Camera3D = get_node(chase_camera_path)

func _ready() -> void:
	_apply_view()

func sit(seat: PilotSeat) -> void:
	if is_seated or _tween != null:
		return
	_seat = seat
	is_seated = true
	_avatar.set_control_enabled(false)
	_move_camera_to(seat.eye.global_transform)

func stand() -> void:
	if not is_seated or _tween != null:
		return
	is_seated = false
	_flight.clear_pilot_input()
	# Put the avatar beside the seat, then fly the camera back to its head.
	_avatar.global_position = _seat.global_position + _seat.global_basis * Vector3(0.9, 0, 0)
	_move_camera_to(_avatar.head.global_transform)

func _move_camera_to(target: Transform3D) -> void:
	# Reparent the interior camera to the interior root so it can travel
	# freely between the avatar's head and the seat without inheriting
	# either one's motion mid-flight.
	var interior_root := _avatar.get_parent()
	var start := _interior_cam.global_transform
	if _interior_cam.get_parent() != interior_root:
		_interior_cam.reparent(interior_root, true)
	_interior_cam.global_transform = start
	_interior_cam.current = true
	_chase_cam.current = false

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_interior_cam, "global_transform", target, SIT_DURATION)
	_tween.finished.connect(_on_transition_finished)

func _on_transition_finished() -> void:
	_tween = null
	if is_seated:
		_interior_cam.reparent(_seat.eye, true)
		_interior_cam.transform = Transform3D.IDENTITY
		view = View.COCKPIT
	else:
		_interior_cam.reparent(_avatar.head, true)
		_interior_cam.transform = Transform3D.IDENTITY
		_avatar.set_control_enabled(true)
		view = View.FOOT_FIRST
	_apply_view()
	transition_finished.emit()

func cycle_view() -> void:
	if _tween != null:
		return
	if is_seated:
		view = View.CHASE if view == View.COCKPIT else View.COCKPIT
	else:
		view = View.FOOT_THIRD if view == View.FOOT_FIRST else View.FOOT_FIRST
	_apply_view()

func _apply_view() -> void:
	match view:
		View.COCKPIT, View.FOOT_FIRST:
			_interior_cam.current = true
			_chase_cam.current = false
			_interior_cam.position = Vector3.ZERO
		View.FOOT_THIRD:
			_interior_cam.current = true
			_chase_cam.current = false
			_interior_cam.position = THIRD_PERSON_OFFSET
		View.CHASE:
			_interior_cam.current = false
			_chase_cam.current = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_camera"):
		cycle_view()
	elif event.is_action_pressed("interact") and is_seated:
		stand()

func _process(_delta: float) -> void:
	if not is_seated:
		return
	var translate := Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("crouch", "sprint"),
		Input.get_axis("move_forward", "move_back"),
	)
	var rotate := Vector3(0, 0, Input.get_axis("roll_left", "roll_right"))
	_flight.set_pilot_input(translate, rotate, Input.is_action_pressed("boost"))
	if Input.is_action_just_pressed("toggle_assist"):
		_flight.assist_enabled = not _flight.assist_enabled
```

- [ ] **Step 4: Wire the scene**

In `flight_test.tscn`:
- Delete `flight_test.gd` from the root node and delete the file.
- Under `Ship/Interior`, add `PilotSeat` (StaticBody3D, `pilot_seat.gd`) at `SeatMarker`'s position, with a `CollisionShape3D` (BoxShape3D 0.8 × 1.2 × 0.8), a `MeshInstance3D` so you can see it, and a child `Eye` (Node3D) at `(0, 1.2, -0.2)`.
- Add `Interactor` (RayCast3D, `interactor.gd`) under `Avatar/Head`, with `owner` set to the Avatar.
- Add `CameraDirector` (Node) under `Ship`, wiring all four exported paths.
- Move the chase `Camera3D` under `Ship/Exterior`, `current = false`.
- The interior `Camera3D` under `Avatar/Head` starts `current = true`.

- [ ] **Step 5: Run and verify — this is the gate**

Press F6.

Expected observations, in order:
- Walk to the seat. The prompt reads `[F] Take the controls`.
- Press F. **The camera travels smoothly from your head into the seat over about three quarters of a second. There is no cut, no fade, and no snap at either end.**
- You now have ship control: W burns, Q/E roll.
- Press V: the view snaps to the chase camera (a cut here is correct and expected — it is a world switch). Press V again to return to the cockpit.
- Press F: the camera travels back out to standing height and you have legs again.
- Repeat five times. There must be no drift in where you end up standing and no accumulating camera offset.

If the transition snaps at either end, the reparenting in `_on_transition_finished` is fighting the tween — check that `reparent(..., true)` is keeping the global transform.

- [ ] **Step 6: Commit**

```bash
git add -A who-knows/
git commit -m "feat: add pilot seat with seamless sit/stand camera transition"
```

---

### Task 6: Motion coupling — the go/no-go [FEEL]

**Files:**
- Create: `who-knows/src/camera/motion_coupling.gd`
- Modify: `who-knows/scenes/flight_test.tscn`

**Interfaces:**
- Consumes: `Ship.exterior`, `Avatar.external_accel`, interior `WorldEnvironment`
- Produces: `MotionCoupling` with `@export var shove_scale: float` and `@export var shake_scale: float` — the two tuning knobs the whole illusion rests on.

- [ ] **Step 1: Write the motion coupling**

Create `who-knows/src/camera/motion_coupling.gd`:

```gdscript
class_name MotionCoupling
extends Node

## Pipes the hull's real motion into interior space as felt effects.
##
## The interior never moves, so nothing here is simulated — it is authored.
## That is the entire advantage of the split: these are tuning knobs, not
## physics we have to fight.

## How much of the hull's acceleration the avatar feels, as a fraction.
## 1.0 is physically honest and violently unpleasant. Start at 0.35.
@export var shove_scale: float = 0.35
@export var shake_scale: float = 0.05
@export var shake_frequency: float = 18.0

@export var hull_path: NodePath
@export var avatar_path: NodePath
@export var interior_sky_path: NodePath

var _last_velocity: Vector3 = Vector3.ZERO
var _shake_phase: float = 0.0

@onready var _hull: RigidBody3D = get_node(hull_path)
@onready var _avatar: Avatar = get_node(avatar_path)
@onready var _sky: Node3D = get_node(interior_sky_path)

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	var velocity := _hull.linear_velocity
	var accel_world := (velocity - _last_velocity) / delta
	_last_velocity = velocity

	# Express the hull's acceleration in the hull's own frame, then apply it
	# in the interior's frame. The interior is axis-aligned with the hull by
	# construction, so this is a straight basis change.
	var accel_local := _hull.global_transform.basis.inverse() * accel_world

	# A ship accelerating forward throws you backward. Negate.
	_avatar.external_accel = -accel_local * shove_scale

	_apply_shake(accel_local, delta)
	_sync_sky()

func _apply_shake(accel_local: Vector3, delta: float) -> void:
	_shake_phase += delta * shake_frequency
	var magnitude := accel_local.length() * shake_scale
	if magnitude < 0.001:
		_avatar.head.position.x = 0.0
		return
	# Deliberately cheap: a single axis wobble reads as engine rumble.
	_avatar.head.position.x = sin(_shake_phase) * magnitude * 0.01

func _sync_sky() -> void:
	# The interior's starfield inherits the hull's orientation, so rolling
	# the ship rolls the stars past the windows even though the room is
	# bolted to the floor of the universe.
	_sky.global_basis = _hull.global_transform.basis
```

- [ ] **Step 2: Add an interior sky and a window**

In `flight_test.tscn`, under `Ship/Interior`:
- Add `SkyPivot` (Node3D). Under it add a large inverted `MeshInstance3D` sphere (radius 500, `flip_faces` on) with an unshaded `StandardMaterial3D` carrying a starfield texture. This is the interior's private starfield.
- Cut a window into the forward wall: replace `WallN`'s single collider with two colliders leaving a 3m × 1.5m gap at eye height, so you can actually see the sky sphere while walking.

- [ ] **Step 3: Wire the coupling**

Add `MotionCoupling` (Node) under `Ship` with `hull_path = ../Exterior`, `avatar_path = ../Interior/Avatar`, `interior_sky_path = ../Interior/SkyPivot`.

- [ ] **Step 4: Run and verify — THIS IS THE GO/NO-GO**

Press F6 and do exactly this:

1. Sit down. Press and hold W to start a hard burn.
2. **While still burning, press F to stand up.**
3. Walk aft (S) toward the back of the room.
4. Walk forward (W) toward the seat.
5. Sit back down.

Expected observations:
- On standing, you are pushed toward the rear of the ship — walking aft feels downhill and walking forward feels uphill.
- The camera has a faint rumble that scales with thrust and stops when the engines do.
- Through the window, the starfield holds still while you burn straight, and **rolls when you roll the ship** — verify by rolling with Q/E before standing up.
- You never clip through the floor, never slide when standing still with engines off, and never get pinned to a wall.

**Tune before proceeding.** `shove_scale` at 1.0 is physically honest and horrible to play. Sweep it from 0.1 to 0.6 and pick the value where a hard burn is clearly felt but you can still walk. Record the chosen value in the commit message.

**Gate:** if this does not feel extraordinary, stop and return to the spec before building Phase B. This is the cheapest possible moment to learn that the premise does not work.

- [ ] **Step 5: Commit**

```bash
git add -A who-knows/
git commit -m "feat: couple hull motion into interior as shove force, shake, and sky"
```

---

# Phase B — The grid

Phase A proved the feel on hand-built scenes. Phase B builds the real data model behind it. Everything here is **[LOGIC]** and strictly test-driven.

---

### Task 7: Orientation and block definitions [LOGIC]

**Files:**
- Create: `who-knows/src/ship/orientation.gd`
- Create: `who-knows/src/ship/block_definition.gd`
- Create: `who-knows/src/ship/block_instance.gd`
- Create: `who-knows/src/ship/block_catalog.gd`
- Test: `who-knows/test/unit/test_orientation.gd`
- Test: `who-knows/test/unit/test_block_catalog.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `Orientation.basis_for(o: int) -> Basis` and `Orientation.COUNT`; `BlockDefinition` with `Category` and `Occupancy` enums and the fields listed below; `BlockInstance`; `BlockCatalog` with `register(def)`, `get_def(id) -> BlockDefinition`, `has(id) -> bool`, and `static load_from_dir(path) -> BlockCatalog`.

- [ ] **Step 1: Write the failing orientation test**

Create `who-knows/test/unit/test_orientation.gd`:

```gdscript
extends GutTest

func test_identity_orientation_points_forward():
	var b := Orientation.basis_for(0)
	assert_almost_eq(b * Vector3(0, 0, -1), Vector3.FORWARD, Vector3.ONE * 0.001)

func test_there_are_twenty_four_orientations():
	assert_eq(Orientation.COUNT, 24, "24 axis-aligned rotations of a cube")

func test_all_orientations_are_distinct():
	var seen: Array[String] = []
	for o in range(Orientation.COUNT):
		var b := Orientation.basis_for(o)
		var key := "%.2f,%.2f,%.2f|%.2f,%.2f,%.2f" % [
			b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z
		]
		assert_false(seen.has(key), "orientation %d duplicates another" % o)
		seen.append(key)

func test_all_orientations_are_right_handed_and_axis_aligned():
	for o in range(Orientation.COUNT):
		var b := Orientation.basis_for(o)
		assert_almost_eq(b.determinant(), 1.0, 0.001, "orientation %d is not a rotation" % o)
		for axis in [b.x, b.y, b.z]:
			var longest := maxf(absf(axis.x), maxf(absf(axis.y), absf(axis.z)))
			assert_almost_eq(longest, 1.0, 0.001, "orientation %d is not axis-aligned" % o)

func test_four_rolls_return_to_start():
	var start := Orientation.basis_for(0)
	var rolled := Orientation.basis_for(3)  # same forward, three rolls
	assert_almost_eq((rolled * Vector3(0, 0, -1)), (start * Vector3(0, 0, -1)), Vector3.ONE * 0.001)
```

- [ ] **Step 2: Run to verify it fails**

```bash
powershell -File "D:/git/whoknows/who-knows/run_tests.ps1"
```

Expected: FAIL — `Identifier "Orientation" not declared`.

- [ ] **Step 3: Implement orientation**

Create `who-knows/src/ship/orientation.gd`:

```gdscript
class_name Orientation
extends RefCounted

## The 24 axis-aligned rotations of a cube, encoded as 0..23.
## Layout: `o >> 2` selects one of six forward directions,
##         `o & 3` selects one of four quarter-turn rolls about it.

const COUNT := 24

const _FORWARDS := [
	Vector3.FORWARD, Vector3.BACK, Vector3.LEFT,
	Vector3.RIGHT, Vector3.UP, Vector3.DOWN,
]

static func basis_for(o: int) -> Basis:
	var forward: Vector3 = _FORWARDS[(o >> 2) % 6]
	# looking_at needs an up vector that is not parallel to forward.
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	var b := Basis.looking_at(forward, up)
	return b.rotated(forward, (o & 3) * PI * 0.5).orthonormalized()
```

- [ ] **Step 4: Run to verify it passes**

```bash
powershell -File "D:/git/whoknows/who-knows/run_tests.ps1"
```

Expected: PASS, 5 orientation tests green.

- [ ] **Step 5: Write the failing catalog test**

Create `who-knows/test/unit/test_block_catalog.gd`:

```gdscript
extends GutTest

func _make_def(id: StringName, occ: BlockDefinition.Occupancy) -> BlockDefinition:
	var d := BlockDefinition.new()
	d.id = id
	d.display_name = String(id)
	d.occupancy = occ
	d.mass_t = 1.0
	d.hp = 100
	return d

func test_registered_definition_is_retrievable():
	var cat := BlockCatalog.new()
	cat.register(_make_def(&"hull", BlockDefinition.Occupancy.SOLID))
	assert_true(cat.has(&"hull"))
	assert_eq(cat.get_def(&"hull").display_name, "hull")

func test_unknown_id_returns_null():
	var cat := BlockCatalog.new()
	assert_null(cat.get_def(&"nope"))
	assert_false(cat.has(&"nope"))

func test_registering_same_id_twice_overwrites():
	var cat := BlockCatalog.new()
	cat.register(_make_def(&"hull", BlockDefinition.Occupancy.SOLID))
	var second := _make_def(&"hull", BlockDefinition.Occupancy.DECK)
	cat.register(second)
	assert_eq(cat.get_def(&"hull").occupancy, BlockDefinition.Occupancy.DECK)

func test_block_instance_defaults_to_orientation_zero():
	var inst := BlockInstance.new()
	inst.block_id = &"hull"
	assert_eq(inst.orientation, 0)
```

- [ ] **Step 6: Run to verify it fails**

Expected: FAIL — `Identifier "BlockDefinition" not declared`.

- [ ] **Step 7: Implement the three resources**

Create `who-knows/src/ship/block_definition.gd`:

```gdscript
class_name BlockDefinition
extends Resource

## Describes one *kind* of block. One .tres per type in res://data/blocks/.

enum Category { STRUCTURE, SYSTEMS, INTERIOR }
enum Occupancy {
	SOLID,   ## machinery and armour; fills the cell; not walkable
	DECK,    ## open volume with a floor; walkable
	MOUNT,   ## a fixture occupying its own cell; walkable
}

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.STRUCTURE
@export var occupancy: Occupancy = Occupancy.SOLID

@export_group("Physical")
@export var mass_t: float = 1.0        ## tonnes
@export var hp: int = 100

@export_group("Power")
@export var power_gen: float = 0.0     ## MW
@export var power_draw: float = 0.0    ## MW

@export_group("Propulsion")
@export var thrust_kn: float = 0.0     ## kN, acting along block-local -Z

@export_group("Habitation")
## Radius in metres over which Grav Plating confers gravity on walkable cells.
@export var grav_radius: float = 0.0

@export_group("Presentation")
@export var mesh: Mesh
@export var icon: Texture2D

func is_walkable() -> bool:
	return occupancy == Occupancy.DECK or occupancy == Occupancy.MOUNT
```

Create `who-knows/src/ship/block_instance.gd`:

```gdscript
class_name BlockInstance
extends Resource

## One placed block. Deliberately tiny — a ship holds hundreds of these.
## Per-instance state lives here, which is why Slice 5's unidentified
## salvage will be a new field rather than a schema change.

@export var block_id: StringName
@export var orientation: int = 0     ## 0..23, see Orientation
@export var hp_current: int = 0

func duplicate_instance() -> BlockInstance:
	var copy := BlockInstance.new()
	copy.block_id = block_id
	copy.orientation = orientation
	copy.hp_current = hp_current
	return copy
```

Create `who-knows/src/ship/block_catalog.gd`:

```gdscript
class_name BlockCatalog
extends RefCounted

## Maps block ids to definitions. Production code loads from disk;
## tests build catalogs by hand, which is why ShipGrid never touches this.

var _defs: Dictionary = {}   # StringName -> BlockDefinition

func register(def: BlockDefinition) -> void:
	assert(def.id != &"", "BlockDefinition must have an id")
	_defs[def.id] = def

func get_def(id: StringName) -> BlockDefinition:
	return _defs.get(id, null)

func has(id: StringName) -> bool:
	return _defs.has(id)

func ids() -> Array:
	return _defs.keys()

static func load_from_dir(path: String = "res://data/blocks") -> BlockCatalog:
	var catalog := BlockCatalog.new()
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("BlockCatalog: cannot open %s" % path)
		return catalog
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var def := ResourceLoader.load(path.path_join(name)) as BlockDefinition
		if def != null:
			catalog.register(def)
	return catalog
```

- [ ] **Step 8: Run to verify it passes**

Expected: PASS, 9 tests green.

- [ ] **Step 9: Commit**

```bash
git add who-knows/src/ship who-knows/test/unit
git commit -m "feat: add orientation encoding, block definitions, and catalog"
```

---

### Task 8: ShipGrid and the mutation choke point [LOGIC]

**Files:**
- Create: `who-knows/src/ship/ship_grid.gd`
- Test: `who-knows/test/unit/test_ship_grid.gd`

**Interfaces:**
- Consumes: `BlockInstance` from Task 7
- Produces: `ShipGrid` (extends `RefCounted`) with `CELL_SIZE := 2.0`, `signal cell_changed(coord: Vector3i)`, `set_block(coord, inst)`, `clear_block(coord)`, `get_block(coord) -> BlockInstance`, `has_block(coord) -> bool`, `coords() -> Array`, `size() -> int`, `neighbours(coord) -> Array`, `static cell_center(coord) -> Vector3`.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_ship_grid.gd`:

```gdscript
extends GutTest

var _grid: ShipGrid
var _changes: Array[Vector3i]

func before_each():
	_grid = ShipGrid.new()
	_changes = []
	_grid.cell_changed.connect(func(c: Vector3i): _changes.append(c))

func _inst(id: StringName = &"hull", orientation: int = 0) -> BlockInstance:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = orientation
	return i

func test_new_grid_is_empty():
	assert_eq(_grid.size(), 0)
	assert_false(_grid.has_block(Vector3i.ZERO))
	assert_null(_grid.get_block(Vector3i.ZERO))

func test_set_block_stores_and_emits():
	_grid.set_block(Vector3i(1, 2, 3), _inst(&"reactor"))
	assert_eq(_grid.size(), 1)
	assert_eq(_grid.get_block(Vector3i(1, 2, 3)).block_id, &"reactor")
	assert_eq(_changes, [Vector3i(1, 2, 3)] as Array[Vector3i])

func test_set_block_overwrites_and_emits_again():
	_grid.set_block(Vector3i.ZERO, _inst(&"hull"))
	_grid.set_block(Vector3i.ZERO, _inst(&"armour"))
	assert_eq(_grid.size(), 1)
	assert_eq(_grid.get_block(Vector3i.ZERO).block_id, &"armour")
	assert_eq(_changes.size(), 2)

func test_clear_block_removes_and_emits():
	_grid.set_block(Vector3i.ZERO, _inst())
	_changes.clear()
	_grid.clear_block(Vector3i.ZERO)
	assert_eq(_grid.size(), 0)
	assert_eq(_changes, [Vector3i.ZERO] as Array[Vector3i])

func test_clearing_empty_cell_does_not_emit():
	_grid.clear_block(Vector3i(9, 9, 9))
	assert_eq(_changes.size(), 0, "no change means no signal")

func test_orientation_round_trips():
	_grid.set_block(Vector3i.ZERO, _inst(&"thruster", 17))
	assert_eq(_grid.get_block(Vector3i.ZERO).orientation, 17)

func test_neighbours_returns_six_face_adjacent_coords():
	var n := _grid.neighbours(Vector3i.ZERO)
	assert_eq(n.size(), 6)
	for expected in [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]:
		assert_true(n.has(expected), "missing neighbour %s" % expected)

func test_cell_center_scales_by_cell_size():
	assert_eq(ShipGrid.CELL_SIZE, 2.0)
	assert_almost_eq(
		ShipGrid.cell_center(Vector3i(1, 0, -2)),
		Vector3(2.0, 0.0, -4.0),
		Vector3.ONE * 0.001
	)

func test_coords_returns_every_occupied_cell():
	_grid.set_block(Vector3i(0, 0, 0), _inst())
	_grid.set_block(Vector3i(0, 0, 1), _inst())
	var c := _grid.coords()
	assert_eq(c.size(), 2)
	assert_true(c.has(Vector3i(0, 0, 1)))
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `Identifier "ShipGrid" not declared`.

- [ ] **Step 3: Implement ShipGrid**

Create `who-knows/src/ship/ship_grid.gd`:

```gdscript
class_name ShipGrid
extends RefCounted

## The single source of truth for a ship's construction.
##
## ARCHITECTURAL RULE: `_cells` is private and only `set_block` and
## `clear_block` may write to it. Every other system — exterior mesh,
## exterior collision, interior geometry, navmesh, stats — rebuilds off
## `cell_changed`. Code that mutates cells any other way lets the
## exterior and interior drift apart, which is the one failure mode that
## can quietly rot this architecture.

signal cell_changed(coord: Vector3i)

const CELL_SIZE := 2.0

const FACE_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _cells: Dictionary = {}   # Vector3i -> BlockInstance

func set_block(coord: Vector3i, inst: BlockInstance) -> void:
	assert(inst != null, "use clear_block() to empty a cell")
	_cells[coord] = inst
	cell_changed.emit(coord)

func clear_block(coord: Vector3i) -> void:
	if not _cells.has(coord):
		return
	_cells.erase(coord)
	cell_changed.emit(coord)

func get_block(coord: Vector3i) -> BlockInstance:
	return _cells.get(coord, null)

func has_block(coord: Vector3i) -> bool:
	return _cells.has(coord)

func size() -> int:
	return _cells.size()

func coords() -> Array:
	return _cells.keys()

func neighbours(coord: Vector3i) -> Array:
	var out: Array[Vector3i] = []
	for offset in FACE_OFFSETS:
		out.append(coord + offset)
	return out

static func cell_center(coord: Vector3i) -> Vector3:
	return Vector3(coord) * CELL_SIZE
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 9 grid tests green.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship_grid.gd who-knows/test/unit/test_ship_grid.gd
git commit -m "feat: add ShipGrid with single mutation choke point"
```

---

### Task 9: Deck graph and walkable connectivity [LOGIC]

**Files:**
- Create: `who-knows/src/ship/deck_graph.gd`
- Test: `who-knows/test/unit/test_deck_graph.gd`

**Interfaces:**
- Consumes: `ShipGrid`, `BlockCatalog`, `BlockDefinition.Occupancy`
- Produces: `DeckGraph` with `static build(grid, catalog) -> DeckGraph`, `is_walkable(coord) -> bool`, `component_of(coord) -> int` (returns `-1` for non-walkable), `component_count() -> int`, `walkable_coords() -> Array`.

Connectivity rule, restated from spec §6.1 rule 4: two walkable cells connect when face-adjacent horizontally (±X, ±Z), or vertically (±Y) when **at least one of the pair is a Ladder**.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_deck_graph.gd`:

```gdscript
extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid

func before_each():
	_cat = BlockCatalog.new()
	_cat.register(_def(&"hull", BlockDefinition.Occupancy.SOLID))
	_cat.register(_def(&"deck", BlockDefinition.Occupancy.DECK))
	_cat.register(_def(&"seat", BlockDefinition.Occupancy.MOUNT))
	_cat.register(_def(&"ladder", BlockDefinition.Occupancy.MOUNT))
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

func test_solid_cells_are_not_walkable():
	_put(Vector3i.ZERO, &"hull")
	var g := DeckGraph.build(_grid, _cat)
	assert_false(g.is_walkable(Vector3i.ZERO))
	assert_eq(g.component_of(Vector3i.ZERO), -1)

func test_deck_and_mount_cells_are_walkable():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"seat")
	var g := DeckGraph.build(_grid, _cat)
	assert_true(g.is_walkable(Vector3i(0, 0, 0)))
	assert_true(g.is_walkable(Vector3i(1, 0, 0)))

func test_horizontally_adjacent_decks_share_a_component():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(1, 0, 1), &"deck")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 1)
	assert_eq(g.component_of(Vector3i(0, 0, 0)), g.component_of(Vector3i(1, 0, 1)))

func test_separated_decks_are_different_components():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(5, 0, 0), &"deck")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 2)
	assert_ne(g.component_of(Vector3i(0, 0, 0)), g.component_of(Vector3i(5, 0, 0)))

func test_vertically_stacked_decks_do_not_connect_without_a_ladder():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 1, 0), &"deck")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 2, "a stacked deck is a second storey, not a ramp")

func test_ladder_connects_vertically():
	_put(Vector3i(0, 0, 0), &"ladder")
	_put(Vector3i(0, 1, 0), &"deck")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 1)
	assert_eq(g.component_of(Vector3i(0, 0, 0)), g.component_of(Vector3i(0, 1, 0)))

func test_ladder_above_also_connects():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 1, 0), &"ladder")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 1)

func test_empty_cells_break_connectivity():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(2, 0, 0), &"deck")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 2, "vacuum is not a corridor")

func test_unknown_block_id_is_not_walkable():
	_put(Vector3i.ZERO, &"mystery")
	var g := DeckGraph.build(_grid, _cat)
	assert_false(g.is_walkable(Vector3i.ZERO))

func test_walkable_coords_lists_only_walkable_cells():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.walkable_coords().size(), 1)
	assert_true(g.walkable_coords().has(Vector3i(0, 0, 0)))
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `Identifier "DeckGraph" not declared`.

- [ ] **Step 3: Implement DeckGraph**

Create `who-knows/src/ship/deck_graph.gd`:

```gdscript
class_name DeckGraph
extends RefCounted

## Connected components over the walkable set (DECK ∪ MOUNT).
##
## Vertical movement requires a Ladder on at least one end of the pair,
## so a deck stacked directly on another deck is a second storey rather
## than a ramp. This is what makes Rule 4 catch a sealed-off upper deck.

const LADDER_ID := &"ladder"

const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const _VERTICAL: Array[Vector3i] = [Vector3i(0, 1, 0), Vector3i(0, -1, 0)]

var _component: Dictionary = {}   # Vector3i -> int
var _count: int = 0

static func build(grid: ShipGrid, catalog: BlockCatalog) -> DeckGraph:
	var g := DeckGraph.new()
	var walkable := {}
	for coord in grid.coords():
		if g._is_walkable_cell(grid, catalog, coord):
			walkable[coord] = true

	for coord in walkable.keys():
		if g._component.has(coord):
			continue
		g._flood(grid, walkable, coord, g._count)
		g._count += 1
	return g

func _is_walkable_cell(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> bool:
	var inst := grid.get_block(coord)
	if inst == null:
		return false
	var def := catalog.get_def(inst.block_id)
	return def != null and def.is_walkable()

func _flood(grid: ShipGrid, walkable: Dictionary, start: Vector3i, id: int) -> void:
	var queue: Array[Vector3i] = [start]
	_component[start] = id
	while not queue.is_empty():
		var coord: Vector3i = queue.pop_back()
		for neighbour in _connected_neighbours(grid, walkable, coord):
			if _component.has(neighbour):
				continue
			_component[neighbour] = id
			queue.append(neighbour)

func _connected_neighbours(grid: ShipGrid, walkable: Dictionary, coord: Vector3i) -> Array:
	var out: Array[Vector3i] = []
	for offset in _HORIZONTAL:
		var n := coord + offset
		if walkable.has(n):
			out.append(n)
	for offset in _VERTICAL:
		var n := coord + offset
		if walkable.has(n) and (_is_ladder(grid, coord) or _is_ladder(grid, n)):
			out.append(n)
	return out

func _is_ladder(grid: ShipGrid, coord: Vector3i) -> bool:
	var inst := grid.get_block(coord)
	return inst != null and inst.block_id == LADDER_ID

func is_walkable(coord: Vector3i) -> bool:
	return _component.has(coord)

func component_of(coord: Vector3i) -> int:
	return _component.get(coord, -1)

func component_count() -> int:
	return _count

func walkable_coords() -> Array:
	return _component.keys()
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 10 deck graph tests green.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/deck_graph.gd who-knows/test/unit/test_deck_graph.gd
git commit -m "feat: add deck graph with ladder-gated vertical connectivity"
```

---

### Task 10: The five validation rules [LOGIC]

**Files:**
- Create: `who-knows/src/ship/ship_validator.gd`
- Test: `who-knows/test/unit/test_ship_validator.gd`

**Interfaces:**
- Consumes: `ShipGrid`, `BlockCatalog`, `DeckGraph`
- Produces: `ShipValidator.Issue` (inner class with `severity: Severity`, `code: StringName`, `message: String`, `coord: Vector3i`), `ShipValidator.Severity { ERROR, WARNING }`, `static validate(grid, catalog) -> Array[Issue]`, `static can_launch(issues) -> bool`. Issue codes: `&"SINGLE_CORE"`, `&"ALL_CONNECTED"`, `&"HAS_PILOT_SEAT"`, `&"MOUNTS_REACHABLE"`, `&"POWER_MARGIN"`.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_ship_validator.gd`:

```gdscript
extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid

func before_each():
	_cat = BlockCatalog.new()
	_cat.register(_def(&"core", BlockDefinition.Occupancy.SOLID))
	_cat.register(_def(&"hull", BlockDefinition.Occupancy.SOLID))
	_cat.register(_def(&"deck", BlockDefinition.Occupancy.DECK))
	_cat.register(_def(&"pilot_seat", BlockDefinition.Occupancy.MOUNT))
	_cat.register(_def(&"ladder", BlockDefinition.Occupancy.MOUNT))
	var reactor := _def(&"reactor", BlockDefinition.Occupancy.SOLID)
	reactor.power_gen = 10.0
	_cat.register(reactor)
	var lamp := _def(&"lamp", BlockDefinition.Occupancy.SOLID)
	lamp.power_draw = 50.0
	_cat.register(lamp)
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

func _codes(issues: Array) -> Array:
	var out: Array = []
	for issue in issues:
		out.append(issue.code)
	return out

## A minimal ship that passes every rule: core, one deck, a seat beside it.
func _build_valid_ship() -> void:
	_put(Vector3i(0, 0, 0), &"core")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(2, 0, 0), &"pilot_seat")
	_put(Vector3i(3, 0, 0), &"reactor")

func test_valid_ship_has_no_issues():
	_build_valid_ship()
	var issues := ShipValidator.validate(_grid, _cat)
	assert_eq(_codes(issues), [], "minimal valid ship should be clean")
	assert_true(ShipValidator.can_launch(issues))

func test_missing_core_is_an_error():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"pilot_seat")
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"SINGLE_CORE"))
	assert_false(ShipValidator.can_launch(issues))

func test_two_cores_is_an_error():
	_build_valid_ship()
	_put(Vector3i(4, 0, 0), &"core")
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"SINGLE_CORE"))

func test_disconnected_block_is_an_error():
	_build_valid_ship()
	_put(Vector3i(20, 0, 0), &"hull")
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"ALL_CONNECTED"))

func test_missing_pilot_seat_is_an_error():
	_put(Vector3i(0, 0, 0), &"core")
	_put(Vector3i(1, 0, 0), &"deck")
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"HAS_PILOT_SEAT"))

## The nasty one: a mount walled off behind sealed structure. It is
## physically attached to the hull, so rule 2 passes — but you cannot
## walk to it, so rule 4 must catch it.
func test_mount_sealed_behind_bulkhead_is_unreachable():
	_build_valid_ship()
	_put(Vector3i(4, 0, 0), &"hull")     # a wall
	_put(Vector3i(5, 0, 0), &"ladder")   # a MOUNT stranded on the far side
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(
		_codes(issues).has(&"MOUNTS_REACHABLE"),
		"a mount you cannot walk to must fail rule 4"
	)
	assert_false(ShipValidator.can_launch(issues))

func test_mount_on_a_second_deck_with_a_ladder_is_reachable():
	_build_valid_ship()
	_put(Vector3i(2, 1, 0), &"ladder")
	_put(Vector3i(3, 1, 0), &"deck")
	# The seat at (2,0,0) is a MOUNT; the ladder above it links the storeys.
	var issues := ShipValidator.validate(_grid, _cat)
	assert_false(_codes(issues).has(&"MOUNTS_REACHABLE"))

func test_power_deficit_is_a_warning_not_an_error():
	_build_valid_ship()
	_put(Vector3i(4, 0, 0), &"lamp")   # draws 50 MW against 10 MW generated
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"POWER_MARGIN"))
	assert_true(
		ShipValidator.can_launch(issues),
		"brownouts are a mechanic, not a build error"
	)

func test_empty_grid_reports_missing_core_and_seat():
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"SINGLE_CORE"))
	assert_true(_codes(issues).has(&"HAS_PILOT_SEAT"))
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `Identifier "ShipValidator" not declared`.

- [ ] **Step 3: Implement the validator**

Create `who-knows/src/ship/ship_validator.gd`:

```gdscript
class_name ShipValidator
extends RefCounted

## The five build rules from spec §6.1. Rules 1-4 are errors and block
## launch; rule 5 is a warning because a power deficit becomes the
## brownout mechanic rather than an invalid ship.

enum Severity { ERROR, WARNING }

const CORE_ID := &"core"
const PILOT_SEAT_ID := &"pilot_seat"

class Issue extends RefCounted:
	var severity: Severity
	var code: StringName
	var message: String
	var coord: Vector3i

	func _init(p_severity: Severity, p_code: StringName, p_message: String,
			p_coord: Vector3i = Vector3i.ZERO) -> void:
		severity = p_severity
		code = p_code
		message = p_message
		coord = p_coord

static func validate(grid: ShipGrid, catalog: BlockCatalog) -> Array:
	var issues: Array = []
	var cores := _find_all(grid, CORE_ID)
	var seats := _find_all(grid, PILOT_SEAT_ID)

	_check_single_core(cores, issues)
	if cores.size() == 1:
		_check_all_connected(grid, cores[0], issues)
	_check_has_pilot_seat(seats, issues)
	if seats.size() >= 1:
		_check_mounts_reachable(grid, catalog, seats[0], issues)
	_check_power_margin(grid, catalog, issues)
	return issues

static func can_launch(issues: Array) -> bool:
	for issue in issues:
		if issue.severity == Severity.ERROR:
			return false
	return true

static func _find_all(grid: ShipGrid, id: StringName) -> Array:
	var out: Array[Vector3i] = []
	for coord in grid.coords():
		if grid.get_block(coord).block_id == id:
			out.append(coord)
	return out

static func _check_single_core(cores: Array, issues: Array) -> void:
	if cores.size() == 1:
		return
	if cores.is_empty():
		issues.append(Issue.new(
			Severity.ERROR, &"SINGLE_CORE", "Ship has no Ship Core."
		))
	else:
		issues.append(Issue.new(
			Severity.ERROR, &"SINGLE_CORE",
			"Ship has %d Ship Cores; exactly one is required." % cores.size(),
			cores[1]
		))

static func _check_all_connected(grid: ShipGrid, core: Vector3i, issues: Array) -> void:
	var reached := {core: true}
	var queue: Array[Vector3i] = [core]
	while not queue.is_empty():
		var coord: Vector3i = queue.pop_back()
		for n in grid.neighbours(coord):
			if grid.has_block(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	for coord in grid.coords():
		if not reached.has(coord):
			issues.append(Issue.new(
				Severity.ERROR, &"ALL_CONNECTED",
				"Block at %s is not attached to the Ship Core." % coord, coord
			))
			return   # one report is enough; the editor highlights the set

static func _check_has_pilot_seat(seats: Array, issues: Array) -> void:
	if seats.is_empty():
		issues.append(Issue.new(
			Severity.ERROR, &"HAS_PILOT_SEAT", "Ship has no Pilot Seat."
		))

static func _check_mounts_reachable(grid: ShipGrid, catalog: BlockCatalog,
		seat: Vector3i, issues: Array) -> void:
	var graph := DeckGraph.build(grid, catalog)
	var seat_component := graph.component_of(seat)
	for coord in grid.coords():
		var def := catalog.get_def(grid.get_block(coord).block_id)
		if def == null or def.occupancy != BlockDefinition.Occupancy.MOUNT:
			continue
		if graph.component_of(coord) != seat_component:
			issues.append(Issue.new(
				Severity.ERROR, &"MOUNTS_REACHABLE",
				"%s at %s cannot be reached on foot from the Pilot Seat."
					% [def.display_name, coord],
				coord
			))

static func _check_power_margin(grid: ShipGrid, catalog: BlockCatalog,
		issues: Array) -> void:
	var gen := 0.0
	var draw := 0.0
	for coord in grid.coords():
		var def := catalog.get_def(grid.get_block(coord).block_id)
		if def == null:
			continue
		gen += def.power_gen
		draw += def.power_draw
	if draw > gen:
		issues.append(Issue.new(
			Severity.WARNING, &"POWER_MARGIN",
			"Power draw %.1f MW exceeds generation %.1f MW." % [draw, gen]
		))
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 9 validator tests green. Note especially that `test_mount_sealed_behind_bulkhead_is_unreachable` passes — that is Rule 4 earning its keep.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship_validator.gd who-knows/test/unit/test_ship_validator.gd
git commit -m "feat: add the five ship validation rules"
```

---

### Task 11: Derived stats [LOGIC]

**Files:**
- Create: `who-knows/src/ship/ship_stats.gd`
- Test: `who-knows/test/unit/test_ship_stats.gd`

**Interfaces:**
- Consumes: `ShipGrid`, `BlockCatalog`, `Orientation`
- Produces: `ShipStats` with fields `total_mass_kg: float`, `center_of_mass: Vector3`, `inertia: Vector3`, `thrust_budget: Dictionary`, `torque_budget: Vector3`, `torque_imbalance: Vector3`, `power_gen: float`, `power_draw: float`; and `static compute(grid, catalog) -> ShipStats`.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_ship_stats.gd`:

```gdscript
extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid

func before_each():
	_cat = BlockCatalog.new()
	var hull := _def(&"hull")
	hull.mass_t = 1.0
	_cat.register(hull)

	var heavy := _def(&"heavy")
	heavy.mass_t = 9.0
	_cat.register(heavy)

	var thruster := _def(&"thruster")
	thruster.mass_t = 1.0
	thruster.thrust_kn = 100.0
	_cat.register(thruster)

	var reactor := _def(&"reactor")
	reactor.mass_t = 1.0
	reactor.power_gen = 8.0
	_cat.register(reactor)

	var lamp := _def(&"lamp")
	lamp.mass_t = 1.0
	lamp.power_draw = 2.0
	_cat.register(lamp)

	_grid = ShipGrid.new()

func _def(id: StringName) -> BlockDefinition:
	var d := BlockDefinition.new()
	d.id = id
	d.display_name = String(id)
	d.occupancy = BlockDefinition.Occupancy.SOLID
	return d

func _put(coord: Vector3i, id: StringName, orientation: int = 0) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = orientation
	_grid.set_block(coord, i)

func test_empty_grid_has_zero_mass():
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.total_mass_kg, 0.0, 0.001)

func test_mass_is_summed_in_kilograms():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"hull")
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.total_mass_kg, 2000.0, 0.001, "2 blocks of 1 t = 2000 kg")

func test_center_of_mass_of_symmetric_pair_is_between_them():
	_put(Vector3i(-1, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"hull")
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.center_of_mass, Vector3.ZERO, Vector3.ONE * 0.001)

func test_center_of_mass_shifts_toward_heavy_block():
	_put(Vector3i(0, 0, 0), &"hull")     # 1 t at z = 0
	_put(Vector3i(0, 0, -1), &"heavy")   # 9 t at z = -2 m
	var s := ShipStats.compute(_grid, _cat)
	# (1 * 0 + 9 * -2) / 10 = -1.8
	assert_almost_eq(s.center_of_mass.z, -1.8, 0.001)

func test_single_block_has_nonzero_inertia():
	_put(Vector3i.ZERO, &"hull")
	var s := ShipStats.compute(_grid, _cat)
	assert_true(s.inertia.x > 0.0, "a solid cube has inertia about its own axis")

func test_forward_thruster_fills_forward_budget():
	_put(Vector3i.ZERO, &"thruster", 0)   # orientation 0 = force along -Z
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.thrust_budget[&"forward"], 100_000.0, 1.0, "100 kN = 100000 N")
	assert_almost_eq(s.thrust_budget[&"reverse"], 0.0, 1.0)

func test_two_forward_thrusters_double_the_budget():
	_put(Vector3i(0, 0, 0), &"thruster", 0)
	_put(Vector3i(1, 0, 0), &"thruster", 0)
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.thrust_budget[&"forward"], 200_000.0, 1.0)

func test_centred_thrusters_produce_no_torque_imbalance():
	_put(Vector3i(-1, 0, 2), &"thruster", 0)
	_put(Vector3i(1, 0, 2), &"thruster", 0)
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.torque_imbalance.length(), 0.0, 1.0,
		"symmetric engines cancel")

func test_offset_thruster_produces_torque_imbalance():
	_put(Vector3i(0, 0, 0), &"heavy")           # mass at the centreline
	_put(Vector3i(4, 0, 2), &"thruster", 0)     # engine far off to one side
	var s := ShipStats.compute(_grid, _cat)
	assert_true(
		s.torque_imbalance.length() > 1.0,
		"an off-centre engine must induce torque under full burn"
	)

func test_power_is_summed():
	_put(Vector3i(0, 0, 0), &"reactor")
	_put(Vector3i(1, 0, 0), &"lamp")
	_put(Vector3i(2, 0, 0), &"lamp")
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.power_gen, 8.0, 0.001)
	assert_almost_eq(s.power_draw, 4.0, 0.001)

func test_unknown_block_ids_are_ignored():
	_put(Vector3i.ZERO, &"mystery")
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.total_mass_kg, 0.0, 0.001)
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `Identifier "ShipStats" not declared`.

- [ ] **Step 3: Implement ShipStats**

Create `who-knows/src/ship/ship_stats.gd`:

```gdscript
class_name ShipStats
extends RefCounted

## Everything derived from the grid. Recomputed once per mutation on
## `cell_changed`, never per frame — at 150 blocks this is trivial.

const KG_PER_TONNE := 1000.0
const N_PER_KN := 1000.0

var total_mass_kg: float = 0.0
## Centre of mass in grid-local metres, relative to the grid origin.
var center_of_mass: Vector3 = Vector3.ZERO
## Moment of inertia about each local axis, kg·m².
var inertia: Vector3 = Vector3.ZERO
## Newtons available along each axis.
var thrust_budget: Dictionary = {
	&"forward": 0.0, &"reverse": 0.0, &"lateral": 0.0, &"vertical": 0.0,
}
## Newton-metres available about (pitch, yaw, roll) from RCS and main engines.
var torque_budget: Vector3 = Vector3.ZERO
## Net torque induced by a full forward burn. Non-zero means the ship
## fights itself under acceleration.
var torque_imbalance: Vector3 = Vector3.ZERO
var power_gen: float = 0.0
var power_draw: float = 0.0

static func compute(grid: ShipGrid, catalog: BlockCatalog) -> ShipStats:
	var s := ShipStats.new()
	var entries := _gather(grid, catalog)
	s._accumulate_mass(entries)
	s._accumulate_inertia(entries)
	s._accumulate_power(entries)
	s._accumulate_thrust(entries)
	return s

## Returns [{def, coord, center, force}] once so each pass can reuse it.
static func _gather(grid: ShipGrid, catalog: BlockCatalog) -> Array:
	var out: Array = []
	for coord in grid.coords():
		var inst := grid.get_block(coord)
		var def := catalog.get_def(inst.block_id)
		if def == null:
			continue
		var force := Vector3.ZERO
		if def.thrust_kn > 0.0:
			var basis := Orientation.basis_for(inst.orientation)
			force = basis * Vector3(0, 0, -1) * def.thrust_kn * N_PER_KN
		out.append({
			"def": def,
			"coord": coord,
			"center": ShipGrid.cell_center(coord),
			"force": force,
		})
	return out

func _accumulate_mass(entries: Array) -> void:
	var weighted := Vector3.ZERO
	for e in entries:
		var kg: float = e["def"].mass_t * KG_PER_TONNE
		total_mass_kg += kg
		weighted += e["center"] * kg
	if total_mass_kg > 0.0:
		center_of_mass = weighted / total_mass_kg

func _accumulate_inertia(entries: Array) -> void:
	# Each block is a solid cube (self term m·s²/6) displaced from the
	# centre of mass (parallel axis term). Accurate enough to make turn
	# rates feel right, and cheap.
	var self_factor := (ShipGrid.CELL_SIZE * ShipGrid.CELL_SIZE) / 6.0
	for e in entries:
		var kg: float = e["def"].mass_t * KG_PER_TONNE
		var r: Vector3 = e["center"] - center_of_mass
		inertia.x += kg * (self_factor + r.y * r.y + r.z * r.z)
		inertia.y += kg * (self_factor + r.x * r.x + r.z * r.z)
		inertia.z += kg * (self_factor + r.x * r.x + r.y * r.y)

func _accumulate_power(entries: Array) -> void:
	for e in entries:
		power_gen += e["def"].power_gen
		power_draw += e["def"].power_draw

func _accumulate_thrust(entries: Array) -> void:
	for e in entries:
		var f: Vector3 = e["force"]
		if f.is_zero_approx():
			continue
		# Bin the force magnitude into the axis it mostly pushes along.
		if f.z < 0.0:
			thrust_budget[&"forward"] += absf(f.z)
		else:
			thrust_budget[&"reverse"] += absf(f.z)
		thrust_budget[&"lateral"] += absf(f.x)
		thrust_budget[&"vertical"] += absf(f.y)

		# Torque about the centre of mass from a full forward burn.
		if f.z < 0.0:
			var r: Vector3 = e["center"] - center_of_mass
			torque_imbalance += r.cross(f)

	torque_budget = Vector3(
		thrust_budget[&"vertical"], thrust_budget[&"lateral"], thrust_budget[&"lateral"]
	) * ShipGrid.CELL_SIZE
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 11 stats tests green.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship_stats.gd who-knows/test/unit/test_ship_stats.gd
git commit -m "feat: derive mass, inertia, thrust budgets, and torque imbalance from grid"
```

---

### Task 12: Blueprint serialization [LOGIC]

**Files:**
- Create: `who-knows/src/ship/ship_blueprint.gd`
- Test: `who-knows/test/unit/test_ship_blueprint.gd`

**Interfaces:**
- Consumes: `ShipGrid`, `BlockInstance`
- Produces: `ShipBlueprint` (Resource) with `@export var ship_name: String`, `@export var format_version: int`, parallel arrays `coords`, `block_ids`, `orientations`, `hp_values`; and `static from_grid(grid, name) -> ShipBlueprint`, `func to_grid() -> ShipGrid`.

Parallel arrays rather than a `Dictionary` keyed by `Vector3i`, sorted deterministically, so saved `.tres` files diff cleanly in git.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_ship_blueprint.gd`:

```gdscript
extends GutTest

func _grid_with(cells: Array) -> ShipGrid:
	var g := ShipGrid.new()
	for cell in cells:
		var i := BlockInstance.new()
		i.block_id = cell[1]
		i.orientation = cell[2]
		i.hp_current = cell[3]
		g.set_block(cell[0], i)
	return g

func test_round_trip_preserves_every_cell():
	var original := _grid_with([
		[Vector3i(0, 0, 0), &"core", 0, 100],
		[Vector3i(1, 0, 0), &"deck", 5, 80],
		[Vector3i(0, 1, -3), &"thruster", 17, 42],
	])
	var bp := ShipBlueprint.from_grid(original, "Testbed")
	var restored := bp.to_grid()

	assert_eq(restored.size(), 3)
	for coord in original.coords():
		var a := original.get_block(coord)
		var b := restored.get_block(coord)
		assert_not_null(b, "cell %s missing after round trip" % coord)
		assert_eq(b.block_id, a.block_id)
		assert_eq(b.orientation, a.orientation)
		assert_eq(b.hp_current, a.hp_current)

func test_round_trip_preserves_name_and_version():
	var bp := ShipBlueprint.from_grid(ShipGrid.new(), "Kestrel")
	assert_eq(bp.ship_name, "Kestrel")
	assert_eq(bp.format_version, ShipBlueprint.CURRENT_FORMAT_VERSION)

func test_empty_grid_round_trips_to_empty():
	var bp := ShipBlueprint.from_grid(ShipGrid.new(), "Empty")
	assert_eq(bp.to_grid().size(), 0)

func test_coords_are_sorted_for_deterministic_diffs():
	var g := _grid_with([
		[Vector3i(5, 0, 0), &"hull", 0, 1],
		[Vector3i(0, 0, 0), &"hull", 0, 1],
		[Vector3i(0, 0, 3), &"hull", 0, 1],
	])
	var first := ShipBlueprint.from_grid(g, "A").coords
	var second := ShipBlueprint.from_grid(g, "A").coords
	assert_eq(first, second, "same grid must serialize identically")
	assert_eq(first[0], Vector3i(0, 0, 0), "sorted ascending")

func test_saves_and_loads_from_disk():
	var g := _grid_with([[Vector3i(2, -1, 4), &"reactor", 9, 55]])
	var bp := ShipBlueprint.from_grid(g, "DiskTest")
	var path := "user://test_blueprint.tres"
	assert_eq(ResourceSaver.save(bp, path), OK)

	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ShipBlueprint
	assert_not_null(loaded)
	var restored := loaded.to_grid()
	assert_eq(restored.size(), 1)
	assert_eq(restored.get_block(Vector3i(2, -1, 4)).block_id, &"reactor")
	assert_eq(restored.get_block(Vector3i(2, -1, 4)).orientation, 9)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `Identifier "ShipBlueprint" not declared`.

- [ ] **Step 3: Implement the blueprint**

Create `who-knows/src/ship/ship_blueprint.gd`:

```gdscript
class_name ShipBlueprint
extends Resource

## A serializable ShipGrid. Stored as sorted parallel arrays rather than a
## Vector3i-keyed dictionary so that saved .tres files are stable and
## diffable in git.

const CURRENT_FORMAT_VERSION := 1

@export var ship_name: String = "Unnamed"
@export var format_version: int = CURRENT_FORMAT_VERSION

@export var coords: Array[Vector3i] = []
@export var block_ids: Array[StringName] = []
@export var orientations: Array[int] = []
@export var hp_values: Array[int] = []

static func from_grid(grid: ShipGrid, name: String) -> ShipBlueprint:
	var bp := ShipBlueprint.new()
	bp.ship_name = name

	var sorted: Array = grid.coords()
	sorted.sort_custom(_compare_coords)

	for coord in sorted:
		var inst := grid.get_block(coord)
		bp.coords.append(coord)
		bp.block_ids.append(inst.block_id)
		bp.orientations.append(inst.orientation)
		bp.hp_values.append(inst.hp_current)
	return bp

func to_grid() -> ShipGrid:
	var grid := ShipGrid.new()
	for index in coords.size():
		var inst := BlockInstance.new()
		inst.block_id = block_ids[index]
		inst.orientation = orientations[index]
		inst.hp_current = hp_values[index]
		grid.set_block(coords[index], inst)
	return grid

static func _compare_coords(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 5 blueprint tests green.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship_blueprint.gd who-knows/test/unit/test_ship_blueprint.gd
git commit -m "feat: add diffable ShipBlueprint serialization"
```

---

### Task 13: Exterior builder and parity [LOGIC]

**Files:**
- Create: `who-knows/src/ship/exterior_builder.gd`
- Test: `who-knows/test/unit/test_exterior_builder.gd`

**Interfaces:**
- Consumes: `ShipGrid`, `BlockCatalog`, `Orientation`
- Produces: `ExteriorBuilder` (extends `Node3D`) with `func bind(grid, catalog) -> void`, `func rebuild() -> void`, `func collider_coords() -> Array`. Attaches its output under a target `RigidBody3D` set via `@export var body_path: NodePath`.

Every occupied cell gets an exterior collider — DECK cells are still hull volume seen from outside.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_exterior_builder.gd`:

```gdscript
extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid
var _body: RigidBody3D
var _builder: ExteriorBuilder

func before_each():
	_cat = BlockCatalog.new()
	for id in [&"hull", &"deck", &"seat"]:
		var d := BlockDefinition.new()
		d.id = id
		d.display_name = String(id)
		d.mass_t = 1.0
		d.occupancy = (
			BlockDefinition.Occupancy.DECK if id == &"deck"
			else BlockDefinition.Occupancy.MOUNT if id == &"seat"
			else BlockDefinition.Occupancy.SOLID
		)
		d.mesh = BoxMesh.new()
		_cat.register(d)

	_grid = ShipGrid.new()
	_body = RigidBody3D.new()
	_builder = ExteriorBuilder.new()
	add_child_autofree(_body)
	_body.add_child(_builder)
	_builder.body_path = _builder.get_path_to(_body)
	_builder.bind(_grid, _cat)

func _put(coord: Vector3i, id: StringName) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	_grid.set_block(coord, i)

func test_empty_grid_produces_no_colliders():
	_builder.rebuild()
	assert_eq(_builder.collider_coords().size(), 0)

func test_every_occupied_cell_gets_a_collider():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(2, 0, 0), &"seat")
	_builder.rebuild()
	assert_eq(_builder.collider_coords().size(), 3,
		"deck and mount cells are still hull volume from outside")

func test_collider_coords_match_grid_exactly():
	for coord in [Vector3i(0, 0, 0), Vector3i(3, -1, 2), Vector3i(-4, 5, 0)]:
		_put(coord, &"hull")
	_builder.rebuild()
	var built := _builder.collider_coords()
	assert_eq(built.size(), _grid.size())
	for coord in _grid.coords():
		assert_true(built.has(coord), "missing exterior collider at %s" % coord)

func test_rebuild_is_idempotent():
	_put(Vector3i.ZERO, &"hull")
	_builder.rebuild()
	_builder.rebuild()
	_builder.rebuild()
	assert_eq(_builder.collider_coords().size(), 1, "rebuild must not accumulate")

func test_clearing_a_block_removes_its_collider():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"hull")
	_builder.rebuild()
	_grid.clear_block(Vector3i(1, 0, 0))
	_builder.rebuild()
	var remaining := _builder.collider_coords()
	assert_eq(remaining.size(), 1)
	assert_true(remaining.has(Vector3i(0, 0, 0)))

## The regression test for the one failure mode that can rot the
## architecture: exterior and grid drifting apart under churn.
func test_parity_survives_random_mutation():
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260821
	for step in 300:
		var coord := Vector3i(
			rng.randi_range(-4, 4), rng.randi_range(-2, 2), rng.randi_range(-6, 6)
		)
		if rng.randf() < 0.65:
			_put(coord, &"hull")
		else:
			_grid.clear_block(coord)
	_builder.rebuild()

	var built := _builder.collider_coords()
	assert_eq(built.size(), _grid.size(), "collider count drifted from grid")
	for coord in _grid.coords():
		assert_true(built.has(coord), "grid cell %s has no collider" % coord)
	for coord in built:
		assert_true(_grid.has_block(coord), "collider %s has no grid cell" % coord)
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `Identifier "ExteriorBuilder" not declared`.

- [ ] **Step 3: Implement the exterior builder**

Create `who-knows/src/ship/exterior_builder.gd`:

```gdscript
class_name ExteriorBuilder
extends Node3D

## Reads a ShipGrid and produces the flying hull: one MultiMesh per block
## type for rendering, one box collider per occupied cell for physics.
##
## This never references InteriorBuilder. Both are independent readers of
## the same source of truth, which is what makes the parity test honest.

@export var body_path: NodePath

var _grid: ShipGrid
var _catalog: BlockCatalog
var _collider_coords: Array[Vector3i] = []
var _colliders: Array[CollisionShape3D] = []
var _multimeshes: Dictionary = {}   # StringName -> MultiMeshInstance3D

func bind(grid: ShipGrid, catalog: BlockCatalog) -> void:
	_grid = grid
	_catalog = catalog

func rebuild() -> void:
	_clear()
	if _grid == null or _catalog == null:
		return
	_build_colliders()
	_build_meshes()

func collider_coords() -> Array:
	return _collider_coords.duplicate()

func _clear() -> void:
	var body := _body()
	for collider in _colliders:
		if is_instance_valid(collider):
			body.remove_child(collider)
			collider.queue_free()
	_colliders.clear()
	_collider_coords.clear()
	for mmi in _multimeshes.values():
		if is_instance_valid(mmi):
			mmi.queue_free()
	_multimeshes.clear()

func _body() -> Node:
	return get_node(body_path) if not body_path.is_empty() else get_parent()

func _build_colliders() -> void:
	var body := _body()
	var extent := ShipGrid.CELL_SIZE * 0.5
	for coord in _grid.coords():
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE * ShipGrid.CELL_SIZE
		var node := CollisionShape3D.new()
		node.shape = shape
		node.position = ShipGrid.cell_center(coord)
		body.add_child(node)
		_colliders.append(node)
		_collider_coords.append(coord)

func _build_meshes() -> void:
	# Group cells by block type so each type draws in one instanced call.
	var by_type: Dictionary = {}   # StringName -> Array[Transform3D]
	for coord in _grid.coords():
		var inst := _grid.get_block(coord)
		var def := _catalog.get_def(inst.block_id)
		if def == null or def.mesh == null:
			continue
		var xform := Transform3D(
			Orientation.basis_for(inst.orientation), ShipGrid.cell_center(coord)
		)
		if not by_type.has(inst.block_id):
			by_type[inst.block_id] = []
		by_type[inst.block_id].append(xform)

	for block_id in by_type.keys():
		var transforms: Array = by_type[block_id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _catalog.get_def(block_id).mesh
		mm.instance_count = transforms.size()
		for index in transforms.size():
			mm.set_instance_transform(index, transforms[index])

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
		_multimeshes[block_id] = mmi
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 6 exterior tests green, including the 300-step parity fuzz.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/exterior_builder.gd who-knows/test/unit/test_exterior_builder.gd
git commit -m "feat: build hull mesh and collision from grid with parity test"
```

---

### Task 14: Interior builder and parity [LOGIC]

**Files:**
- Create: `who-knows/src/ship/interior_builder.gd`
- Test: `who-knows/test/unit/test_interior_builder.gd`

**Interfaces:**
- Consumes: `ShipGrid`, `BlockCatalog`, `DeckGraph`
- Produces: `InteriorBuilder` (extends `Node3D`) with `bind(grid, catalog)`, `rebuild()`, `walkable_coords() -> Array`, `wall_count() -> int`, `func gravity_at(coord) -> float`.

Gravity rule from spec §5: Grav Plating confers gravity on walkable cells within `grav_radius` metres.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_interior_builder.gd`:

```gdscript
extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid
var _builder: InteriorBuilder

func before_each():
	_cat = BlockCatalog.new()
	_cat.register(_def(&"hull", BlockDefinition.Occupancy.SOLID))
	_cat.register(_def(&"deck", BlockDefinition.Occupancy.DECK))
	_cat.register(_def(&"seat", BlockDefinition.Occupancy.MOUNT))
	var grav := _def(&"grav", BlockDefinition.Occupancy.SOLID)
	grav.grav_radius = 5.0
	_cat.register(grav)

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

func test_solid_only_ship_has_no_interior():
	_put(Vector3i.ZERO, &"hull")
	_builder.rebuild()
	assert_eq(_builder.walkable_coords().size(), 0)

func test_deck_and_mount_cells_become_walkable_floor():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"seat")
	_put(Vector3i(2, 0, 0), &"hull")
	_builder.rebuild()
	var walkable := _builder.walkable_coords()
	assert_eq(walkable.size(), 2)
	assert_true(walkable.has(Vector3i(0, 0, 0)))
	assert_true(walkable.has(Vector3i(1, 0, 0)))
	assert_false(walkable.has(Vector3i(2, 0, 0)))

func test_wall_is_built_where_deck_meets_solid():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_builder.rebuild()
	assert_true(_builder.wall_count() > 0, "a deck beside solid needs a bulkhead")

func test_no_wall_between_two_adjacent_decks():
	_put(Vector3i(0, 0, 0), &"deck")
	_builder.rebuild()
	var single := _builder.wall_count()

	_put(Vector3i(1, 0, 0), &"deck")
	_builder.rebuild()
	var pair := _builder.wall_count()

	assert_eq(single, 4, "an isolated deck cell is walled on all four sides")
	assert_eq(pair, 6, "adjacent decks share one open face, not two walls")

func test_rebuild_is_idempotent():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	var once := _builder.wall_count()
	_builder.rebuild()
	_builder.rebuild()
	assert_eq(_builder.wall_count(), once, "rebuild must not accumulate walls")

func test_grav_plating_confers_gravity_within_radius():
	_put(Vector3i(0, 0, 0), &"grav")
	_put(Vector3i(1, 0, 0), &"deck")    # 2 m away, inside radius 5
	_builder.rebuild()
	assert_true(_builder.gravity_at(Vector3i(1, 0, 0)) > 0.0)

func test_cells_beyond_grav_radius_are_weightless():
	_put(Vector3i(0, 0, 0), &"grav")
	_put(Vector3i(10, 0, 0), &"deck")   # 20 m away, outside radius 5
	_builder.rebuild()
	assert_almost_eq(_builder.gravity_at(Vector3i(10, 0, 0)), 0.0, 0.001,
		"an unplated compartment is a room you chose not to furnish")

## Parity: the interior's walkable set must equal the grid's walkable set,
## under churn, forever.
func test_parity_survives_random_mutation():
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260822
	var ids := [&"hull", &"deck", &"seat"]
	for step in 300:
		var coord := Vector3i(
			rng.randi_range(-3, 3), rng.randi_range(-1, 1), rng.randi_range(-5, 5)
		)
		if rng.randf() < 0.7:
			_put(coord, ids[rng.randi_range(0, 2)])
		else:
			_grid.clear_block(coord)
	_builder.rebuild()

	# Derive the expectation straight from the grid rather than from
	# DeckGraph, so this test is genuinely independent of the code path
	# the builder uses internally.
	var expected: Array = []
	for coord in _grid.coords():
		var def := _cat.get_def(_grid.get_block(coord).block_id)
		if def != null and def.is_walkable():
			expected.append(coord)

	var built := _builder.walkable_coords()
	assert_eq(built.size(), expected.size(), "interior drifted from grid")
	for coord in expected:
		assert_true(built.has(coord), "walkable cell %s has no interior floor" % coord)
	for coord in built:
		assert_true(expected.has(coord), "interior floor %s is not walkable in grid" % coord)
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `Identifier "InteriorBuilder" not declared`.

- [ ] **Step 3: Implement the interior builder**

Create `who-knows/src/ship/interior_builder.gd`:

```gdscript
class_name InteriorBuilder
extends Node3D

## Reads a ShipGrid and produces the walkable interior: a floor under every
## walkable cell, a ceiling above it, and a wall on every face where a
## walkable cell meets solid structure or vacuum.
##
## The output never moves. That is the whole architecture.

const FLOOR_THICKNESS := 0.2
const DEFAULT_GRAVITY := 9.8

@export var body_path: NodePath

var _grid: ShipGrid
var _catalog: BlockCatalog
var _walkable: Array[Vector3i] = []
var _walls: Array[CollisionShape3D] = []
var _floors: Array[CollisionShape3D] = []
var _gravity: Dictionary = {}   # Vector3i -> float

func bind(grid: ShipGrid, catalog: BlockCatalog) -> void:
	_grid = grid
	_catalog = catalog

func rebuild() -> void:
	_clear()
	if _grid == null or _catalog == null:
		return
	var graph := DeckGraph.build(_grid, _catalog)
	_walkable.assign(graph.walkable_coords())
	_build_floors()
	_build_walls()
	_compute_gravity()

func walkable_coords() -> Array:
	return _walkable.duplicate()

func wall_count() -> int:
	return _walls.size()

func gravity_at(coord: Vector3i) -> float:
	return _gravity.get(coord, 0.0)

func _clear() -> void:
	for node in _walls + _floors:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_walls.clear()
	_floors.clear()
	_walkable.clear()
	_gravity.clear()

func _body() -> Node:
	return get_node(body_path) if not body_path.is_empty() else self

func _build_floors() -> void:
	var body := _body()
	var half := ShipGrid.CELL_SIZE * 0.5
	for coord in _walkable:
		var center := ShipGrid.cell_center(coord)
		_floors.append(_add_box(
			body,
			Vector3(ShipGrid.CELL_SIZE, FLOOR_THICKNESS, ShipGrid.CELL_SIZE),
			center + Vector3(0, -half, 0)
		))
		_floors.append(_add_box(
			body,
			Vector3(ShipGrid.CELL_SIZE, FLOOR_THICKNESS, ShipGrid.CELL_SIZE),
			center + Vector3(0, half, 0)
		))

func _build_walls() -> void:
	var body := _body()
	var half := ShipGrid.CELL_SIZE * 0.5
	var walkable_set := {}
	for coord in _walkable:
		walkable_set[coord] = true

	for coord in _walkable:
		var center := ShipGrid.cell_center(coord)
		for offset in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
				Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			if walkable_set.has(coord + offset):
				continue   # open passage between two walkable cells
			var normal := Vector3(offset)
			var size := Vector3(
				FLOOR_THICKNESS if offset.x != 0 else ShipGrid.CELL_SIZE,
				ShipGrid.CELL_SIZE,
				FLOOR_THICKNESS if offset.z != 0 else ShipGrid.CELL_SIZE
			)
			_walls.append(_add_box(body, size, center + normal * half))

func _add_box(parent: Node, size: Vector3, position: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = position
	parent.add_child(node)
	return node

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
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 8 interior tests green, including the parity fuzz.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/interior_builder.gd who-knows/test/unit/test_interior_builder.gd
git commit -m "feat: build walkable interior from grid with parity test"
```

---

### Task 15: Author the fifteen blocks and wire the grid into the ship [FEEL]

**Files:**
- Create: `who-knows/data/blocks/*.tres` (15 resources)
- Modify: `who-knows/src/ship/ship.gd`
- Modify: `who-knows/scenes/flight_test.tscn`
- Test: `who-knows/test/unit/test_block_data.gd`

**Interfaces:**
- Consumes: everything from Tasks 7–14
- Produces: `Ship.load_blueprint(bp: ShipBlueprint) -> void`, `Ship.grid: ShipGrid`, `Ship.stats: ShipStats`. `Ship` now owns both builders and pushes `stats.thrust_budget` into the flight computer.

This is where Phase A's hand-built scenery is replaced by generated geometry.

- [ ] **Step 1: Author the fifteen block resources**

Create one `.tres` per row in `who-knows/data/blocks/`. Use `BoxMesh` placeholders sized `2 × 2 × 2` for every block for now; real art comes later and changes nothing but the `mesh` field.

| File | id | category | occupancy | mass_t | hp | power_gen | power_draw | thrust_kn | grav_radius |
|---|---|---|---|---|---|---|---|---|---|
| `hull.tres` | `hull` | STRUCTURE | SOLID | 1.0 | 200 | 0 | 0 | 0 | 0 |
| `hull_wedge.tres` | `hull_wedge` | STRUCTURE | SOLID | 0.6 | 140 | 0 | 0 | 0 | 0 |
| `armour.tres` | `armour` | STRUCTURE | SOLID | 3.0 | 900 | 0 | 0 | 0 | 0 |
| `core.tres` | `core` | STRUCTURE | SOLID | 4.0 | 500 | 0 | 2.0 | 0 | 0 |
| `reactor.tres` | `reactor` | SYSTEMS | SOLID | 5.0 | 250 | 12.0 | 0 | 0 | 0 |
| `thruster.tres` | `thruster` | SYSTEMS | SOLID | 2.5 | 150 | 0 | 3.0 | 300.0 | 0 |
| `rcs.tres` | `rcs` | SYSTEMS | SOLID | 0.5 | 80 | 0 | 0.4 | 40.0 | 0 |
| `battery.tres` | `battery` | SYSTEMS | SOLID | 2.0 | 120 | 0 | 0 | 0 | 0 |
| `grav_plating.tres` | `grav_plating` | SYSTEMS | SOLID | 1.5 | 100 | 0 | 1.5 | 0 | 6.0 |
| `deck.tres` | `deck` | INTERIOR | DECK | 0.4 | 60 | 0 | 0.1 | 0 | 0 |
| `bulkhead.tres` | `bulkhead` | INTERIOR | SOLID | 0.8 | 180 | 0 | 0 | 0 | 0 |
| `door.tres` | `door` | INTERIOR | DECK | 0.6 | 90 | 0 | 0.3 | 0 | 0 |
| `pilot_seat.tres` | `pilot_seat` | INTERIOR | MOUNT | 0.5 | 60 | 0 | 0.5 | 0 | 0 |
| `ladder.tres` | `ladder` | INTERIOR | MOUNT | 0.3 | 50 | 0 | 0 | 0 | 0 |
| `airlock.tres` | `airlock` | INTERIOR | DECK | 1.2 | 200 | 0 | 0.6 | 0 | 0 |

- [ ] **Step 2: Write the data integrity test**

Create `who-knows/test/unit/test_block_data.gd`:

```gdscript
extends GutTest

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func test_all_fifteen_blocks_load():
	assert_eq(_cat.ids().size(), 15, "spec §5 lists fifteen blocks")

func test_required_ids_exist():
	for id in [&"hull", &"hull_wedge", &"armour", &"core", &"reactor",
			&"thruster", &"rcs", &"battery", &"grav_plating", &"deck",
			&"bulkhead", &"door", &"pilot_seat", &"ladder", &"airlock"]:
		assert_true(_cat.has(id), "missing block definition: %s" % id)

func test_every_block_has_positive_mass_and_hp():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		assert_true(def.mass_t > 0.0, "%s has non-positive mass" % id)
		assert_true(def.hp > 0, "%s has non-positive hp" % id)

func test_every_block_has_a_mesh_and_display_name():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		assert_not_null(def.mesh, "%s has no mesh" % id)
		assert_ne(def.display_name, "", "%s has no display name" % id)

func test_only_thrusters_produce_thrust():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		if id in [&"thruster", &"rcs"]:
			assert_true(def.thrust_kn > 0.0, "%s should produce thrust" % id)
		else:
			assert_almost_eq(def.thrust_kn, 0.0, 0.001, "%s should not thrust" % id)

func test_only_grav_plating_confers_gravity():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		if id == &"grav_plating":
			assert_true(def.grav_radius > 0.0)
		else:
			assert_almost_eq(def.grav_radius, 0.0, 0.001, "%s should not plate" % id)

func test_walkable_blocks_are_exactly_the_interior_traversables():
	var walkable: Array = []
	for id in _cat.ids():
		if _cat.get_def(id).is_walkable():
			walkable.append(id)
	walkable.sort()
	var expected := [&"airlock", &"deck", &"door", &"ladder", &"pilot_seat"]
	expected.sort()
	assert_eq(walkable, expected)
```

- [ ] **Step 3: Run to verify the data tests pass**

```bash
powershell -File "D:/git/whoknows/who-knows/run_tests.ps1"
```

Expected: PASS. If `test_all_fifteen_blocks_load` fails with 0, the `.tres` files are missing their `script` reference to `block_definition.gd`.

- [ ] **Step 4: Rewrite Ship to own the grid**

Replace `who-knows/src/ship/ship.gd` entirely:

```gdscript
class_name Ship
extends Node3D

## Owns one ship's grid and both representations of it. The grid is the
## source of truth; everything else here reacts to `cell_changed`.

signal stats_changed(stats: ShipStats)

const SLOT_SPACING := 10000.0

@export var interior_slot: int = 0

var grid: ShipGrid
var stats: ShipStats
var catalog: BlockCatalog

@onready var exterior: RigidBody3D = $Exterior
@onready var interior: Node3D = $Interior
@onready var exterior_builder: ExteriorBuilder = $Exterior/ExteriorBuilder
@onready var interior_builder: InteriorBuilder = $Interior/InteriorBuilder
@onready var flight_computer: FlightComputer = $FlightComputer

func _ready() -> void:
	exterior.gravity_scale = 0.0
	exterior.linear_damp = 0.0
	exterior.angular_damp = 0.0
	exterior.can_sleep = false
	interior.global_position = interior_slot_origin()
	if catalog == null:
		catalog = BlockCatalog.load_from_dir("res://data/blocks")

func interior_slot_origin() -> Vector3:
	return Vector3(interior_slot * SLOT_SPACING, 0.0, 0.0)

func load_blueprint(bp: ShipBlueprint) -> void:
	set_grid(bp.to_grid())

func set_grid(new_grid: ShipGrid) -> void:
	if grid != null and grid.cell_changed.is_connected(_on_cell_changed):
		grid.cell_changed.disconnect(_on_cell_changed)
	grid = new_grid
	grid.cell_changed.connect(_on_cell_changed)
	exterior_builder.bind(grid, catalog)
	interior_builder.bind(grid, catalog)
	_rebuild_everything()

func _on_cell_changed(_coord: Vector3i) -> void:
	# Slice 1 rebuilds wholesale on any change. At 150 blocks this is well
	# under a frame. Incremental per-cell rebuild is a Slice 2 optimisation
	# for when weapons start destroying blocks every few milliseconds.
	_rebuild_everything()

func _rebuild_everything() -> void:
	exterior_builder.rebuild()
	interior_builder.rebuild()
	stats = ShipStats.compute(grid, catalog)
	_apply_stats()
	stats_changed.emit(stats)

func _apply_stats() -> void:
	exterior.mass = maxf(stats.total_mass_kg, 1.0)
	exterior.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	exterior.center_of_mass = stats.center_of_mass
	exterior.inertia = stats.inertia
	flight_computer.thrust_budget = stats.thrust_budget.duplicate()
	flight_computer.torque_budget = stats.torque_budget
```

- [ ] **Step 5: Update the flight test scene**

In `flight_test.tscn`:
- Delete the hand-built `Hull` mesh and `Collider` under `Exterior`; add `ExteriorBuilder` (Node3D) with `body_path = ..`.
- Delete the hand-built `Floor`, `Ceiling`, and four `Wall` nodes under `Interior`; add a `StaticBody3D` named `InteriorBody` and, under it, `InteriorBuilder` with `body_path = ..`.
- Keep `SkyPivot`, `Avatar`, and `PilotSeat`.
- Add a bootstrap script to the root that builds a starter ship in code so the scene has something to show.

Create `who-knows/scenes/flight_test.gd`:

```gdscript
extends Node3D

## Builds a small starter corvette so flight_test.tscn always has a ship.
## Once the shipyard exists (Task 20) this loads a saved blueprint instead.

@onready var _ship: Ship = $Ship

func _ready() -> void:
	_ship.set_grid(_starter_grid())

func _starter_grid() -> ShipGrid:
	var g := ShipGrid.new()
	# A 3-wide, 7-long single-deck corvette: bridge forward, engines aft.
	for z in range(-3, 4):
		for x in range(-1, 2):
			_put(g, Vector3i(x, 0, z), &"deck" if x == 0 else &"hull")
	_put(g, Vector3i(0, 0, -3), &"pilot_seat")
	_put(g, Vector3i(0, 0, 0), &"core")
	_put(g, Vector3i(1, 0, 1), &"reactor")
	_put(g, Vector3i(-1, 0, 1), &"grav_plating")
	_put(g, Vector3i(-1, 0, 3), &"thruster")
	_put(g, Vector3i(1, 0, 3), &"thruster")
	_put(g, Vector3i(0, 0, 3), &"airlock")
	return g

func _put(g: ShipGrid, coord: Vector3i, id: StringName) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	g.set_block(coord, i)
```

- [ ] **Step 6: Run and verify the generated ship**

Press F6 on `flight_test.tscn`.

Expected observations:
- A blocky corvette appears, assembled from the placeholder boxes.
- The interior has a walkable central corridor running fore to aft.
- You can walk from the airlock at the stern to the pilot seat at the bow.
- Sitting and flying still works, and **the ship now handles differently** — mass and thrust come from the blocks, not from the hardcoded numbers in Task 4.
- Standing up mid-burn still shoves you aft.

- [ ] **Step 7: Commit**

```bash
git add -A who-knows/
git commit -m "feat: author 15 block definitions and drive the ship from its grid"
```

---

# Phase C — The shipyard

---

### Task 16: Placement, orbit camera, and the ghost [FEEL]

**Files:**
- Create: `who-knows/src/editor/shipyard.gd`
- Create: `who-knows/scenes/shipyard.tscn`

**Interfaces:**
- Consumes: `ShipGrid`, `BlockCatalog`, `Orientation`, `ExteriorBuilder`, `InteriorBuilder`
- Produces: `Shipyard` with `var selected_block: StringName`, `var ghost_orientation: int`, `signal grid_dirty`, and `func focus_coord() -> Vector3i`.

- [ ] **Step 1: Write the shipyard script**

Create `who-knows/src/editor/shipyard.gd`:

```gdscript
class_name Shipyard
extends Node3D

## Dry-dock editor. Left click places the selected block, right click
## clears a cell, R rotates the ghost. Placement targets the face of the
## block under the cursor, so you build outward the way you would expect.

signal grid_dirty

const ORBIT_SENSITIVITY := 0.006
const ZOOM_STEP := 2.0
const MIN_DISTANCE := 6.0
const MAX_DISTANCE := 80.0
const RAY_LENGTH := 500.0

var grid: ShipGrid
var catalog: BlockCatalog
var selected_block: StringName = &"hull"
var ghost_orientation: int = 0

var _yaw: float = 0.6
var _pitch: float = -0.5
var _distance: float = 24.0
var _orbiting: bool = false
var _ghost_coord: Vector3i = Vector3i.ZERO

@onready var _camera: Camera3D = $OrbitPivot/Camera3D
@onready var _pivot: Node3D = $OrbitPivot
@onready var _ghost: MeshInstance3D = $Ghost
@onready var _exterior_builder: ExteriorBuilder = $Preview/Exterior/ExteriorBuilder
@onready var _interior_builder: InteriorBuilder = $Preview/Interior/InteriorBuilder

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	catalog = BlockCatalog.load_from_dir("res://data/blocks")
	grid = ShipGrid.new()
	grid.cell_changed.connect(func(_c: Vector3i): _rebuild())
	_exterior_builder.bind(grid, catalog)
	_interior_builder.bind(grid, catalog)
	_seed_starter_block()
	_update_camera()

func _seed_starter_block() -> void:
	# You cannot build on nothing, so every new ship starts with its Core.
	var core := BlockInstance.new()
	core.block_id = &"core"
	grid.set_block(Vector3i.ZERO, core)

func focus_coord() -> Vector3i:
	return _ghost_coord

func _rebuild() -> void:
	_exterior_builder.rebuild()
	_interior_builder.rebuild()
	grid_dirty.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _orbiting:
		_yaw -= event.relative.x * ORBIT_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * ORBIT_SENSITIVITY,
			-PI * 0.49, PI * 0.49)
		_update_camera()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		ghost_orientation = (ghost_orientation + 1) % Orientation.COUNT

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
			_update_camera()
		MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
			_update_camera()
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_place()
		MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_erase()

func _update_camera() -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	_camera.position = Vector3(0, 0, _distance)

func _process(_delta: float) -> void:
	var target := _pick_placement_coord()
	if target != null:
		_ghost_coord = target
		_ghost.visible = true
		_ghost.position = ShipGrid.cell_center(_ghost_coord)
		_ghost.basis = Orientation.basis_for(ghost_orientation)
	else:
		_ghost.visible = false

## Returns the empty cell adjacent to the hovered face, or null.
func _pick_placement_coord():
	var hit := _raycast()
	if hit.is_empty():
		return null
	var cell := _coord_from_point(hit["position"] - hit["normal"] * 0.01)
	return cell + Vector3i(hit["normal"].round())

func _pick_erase_coord():
	var hit := _raycast()
	if hit.is_empty():
		return null
	return _coord_from_point(hit["position"] - hit["normal"] * 0.01)

func _raycast() -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse)
	var to := from + _camera.project_ray_normal(mouse) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return get_world_3d().direct_space_state.intersect_ray(query)

static func _coord_from_point(point: Vector3) -> Vector3i:
	return Vector3i((point / ShipGrid.CELL_SIZE).round())

func _place() -> void:
	var coord = _pick_placement_coord()
	if coord == null or grid.has_block(coord):
		return
	var inst := BlockInstance.new()
	inst.block_id = selected_block
	inst.orientation = ghost_orientation
	var def := catalog.get_def(selected_block)
	inst.hp_current = def.hp if def != null else 100
	grid.set_block(coord, inst)

func _erase() -> void:
	var coord = _pick_erase_coord()
	if coord == null or coord == Vector3i.ZERO:
		return   # never delete the Core out from under the ship
	grid.clear_block(coord)
```

- [ ] **Step 2: Build the shipyard scene**

Create `who-knows/scenes/shipyard.tscn`:

```
Shipyard (Node3D, shipyard.gd)
├── WorldEnvironment            dim dry-dock ambience
├── DirectionalLight3D
├── OrbitPivot (Node3D)
│   └── Camera3D                at (0, 0, 24), current = true
├── Ghost (MeshInstance3D)      BoxMesh 2³, translucent additive material
└── Preview (Node3D)
    ├── Exterior (StaticBody3D)
    │   └── ExteriorBuilder     body_path = ..
    └── Interior (StaticBody3D) visible = false in Slice 1
        └── InteriorBuilder     body_path = ..
```

The preview exterior is a `StaticBody3D`, not a `RigidBody3D` — in the dry dock the ship must not drift, and the builder does not care which body it attaches to.

- [ ] **Step 3: Run and verify**

Press F6 on `shipyard.tscn`.

Expected observations:
- A single Core block sits at the origin.
- Right-drag orbits smoothly; the wheel zooms between 6m and 80m.
- Hovering a block face shows the translucent ghost snapped to the adjacent empty cell.
- Left click places a block there; the ship visibly grows.
- Middle click erases the hovered block, but the Core at the origin refuses to delete.
- R rotates the ghost through 24 orientations.

- [ ] **Step 4: Commit**

```bash
git add -A who-knows/
git commit -m "feat: add shipyard with orbit camera and face-snapped block placement"
```

---

### Task 17: Deck slicer and block palette [FEEL]

**Files:**
- Create: `who-knows/src/editor/deck_slicer.gd`
- Create: `who-knows/src/editor/palette_panel.gd`
- Modify: `who-knows/scenes/shipyard.tscn`
- Modify: `who-knows/src/editor/shipyard.gd`

**Interfaces:**
- Consumes: `Shipyard.selected_block`, `ExteriorBuilder`
- Produces: `DeckSlicer` with `var slice_level: int` and `signal slice_changed(level: int)`; `PalettePanel` with `signal block_selected(id: StringName)`.

Without the slicer you cannot see inside your own hull to lay out a corridor, so this task is not optional polish — it is what makes interior design possible at all.

- [ ] **Step 1: Write the deck slicer**

Create `who-knows/src/editor/deck_slicer.gd`:

```gdscript
class_name DeckSlicer
extends Control

## A Y-level cutaway. Everything above `slice_level` is hidden so you can
## see and build the deck you are working on.

signal slice_changed(level: int)

const MIN_LEVEL := -4
const MAX_LEVEL := 8

var slice_level: int = MAX_LEVEL

@onready var _slider: HSlider = $VBox/Slider
@onready var _label: Label = $VBox/Label

func _ready() -> void:
	_slider.min_value = MIN_LEVEL
	_slider.max_value = MAX_LEVEL
	_slider.step = 1
	_slider.value = MAX_LEVEL
	_slider.value_changed.connect(_on_slider_changed)
	_update_label()

func _on_slider_changed(value: float) -> void:
	slice_level = int(value)
	_update_label()
	slice_changed.emit(slice_level)

func _update_label() -> void:
	_label.text = (
		"Deck slice: all" if slice_level >= MAX_LEVEL
		else "Deck slice: ≤ %d" % slice_level
	)
```

- [ ] **Step 2: Add slicing support to the exterior builder**

Add to `who-knows/src/ship/exterior_builder.gd`:

```gdscript
## Cells with y greater than this are hidden. Editor-only; the flying hull
## leaves this at its default so nothing is ever hidden in flight.
var slice_level: int = 999

func set_slice_level(level: int) -> void:
	slice_level = level
	rebuild()
```

Then in `_build_colliders()` and `_build_meshes()`, skip any cell where `coord.y > slice_level`, by adding this guard immediately after each `for coord in _grid.coords():` line:

```gdscript
		if coord.y > slice_level:
			continue
```

- [ ] **Step 3: Write the palette panel**

Create `who-knows/src/editor/palette_panel.gd`:

```gdscript
class_name PalettePanel
extends Control

## Block picker, grouped by category.

signal block_selected(id: StringName)

@onready var _container: VBoxContainer = $Scroll/VBox

func populate(catalog: BlockCatalog) -> void:
	for child in _container.get_children():
		child.queue_free()

	var by_category: Dictionary = {}
	for id in catalog.ids():
		var def := catalog.get_def(id)
		if not by_category.has(def.category):
			by_category[def.category] = []
		by_category[def.category].append(def)

	for category in [BlockDefinition.Category.STRUCTURE,
			BlockDefinition.Category.SYSTEMS,
			BlockDefinition.Category.INTERIOR]:
		if not by_category.has(category):
			continue
		var header := Label.new()
		header.text = BlockDefinition.Category.keys()[category]
		_container.add_child(header)

		var defs: Array = by_category[category]
		defs.sort_custom(func(a, b): return a.display_name < b.display_name)
		for def in defs:
			var button := Button.new()
			button.text = def.display_name
			button.icon = def.icon
			button.pressed.connect(func(): block_selected.emit(def.id))
			_container.add_child(button)
```

- [ ] **Step 4: Wire both into the shipyard**

Add to `who-knows/src/editor/shipyard.gd`, inside `_ready()` after the builders are bound:

```gdscript
	var palette: PalettePanel = $UI/PalettePanel
	palette.populate(catalog)
	palette.block_selected.connect(func(id: StringName): selected_block = id)

	var slicer: DeckSlicer = $UI/DeckSlicer
	slicer.slice_changed.connect(_exterior_builder.set_slice_level)
```

- [ ] **Step 5: Build the UI in the scene**

In `shipyard.tscn`, add:

```
UI (CanvasLayer)
├── PalettePanel (Control, palette_panel.gd)   anchored left, width 200
│   └── Scroll (ScrollContainer)
│       └── VBox (VBoxContainer)
└── DeckSlicer (Control, deck_slicer.gd)       anchored bottom-centre
    └── VBox (VBoxContainer)
        ├── Label
        └── Slider (HSlider)
```

- [ ] **Step 6: Run and verify**

Press F6 on `shipyard.tscn`.

Expected observations:
- The palette lists all fifteen blocks under three headings.
- Clicking a palette entry changes what the ghost places.
- Dragging the slicer down hides upper decks progressively; at the bottom you see only the lowest layer.
- With the top sliced away, you can place Deck blocks in the hull's interior and see them.
- Sliding back to the top restores the whole ship.

- [ ] **Step 7: Commit**

```bash
git add -A who-knows/
git commit -m "feat: add deck slicer cutaway and categorised block palette"
```

---

### Task 18: Live stats and validation panel [FEEL]

**Files:**
- Create: `who-knows/src/editor/stats_panel.gd`
- Modify: `who-knows/scenes/shipyard.tscn`
- Modify: `who-knows/src/editor/shipyard.gd`

**Interfaces:**
- Consumes: `ShipStats`, `ShipValidator`, `Shipyard.grid_dirty`
- Produces: `StatsPanel` with `func refresh(grid, catalog) -> void` and `var can_launch: bool`.

- [ ] **Step 1: Write the stats panel**

Create `who-knows/src/editor/stats_panel.gd`:

```gdscript
class_name StatsPanel
extends Control

## Live derived stats and validation. This is where a builder becomes a
## game: you place a reactor in the nose and watch the pitch rate collapse.

const WARN_COLOR := Color(1.0, 0.75, 0.2)
const ERROR_COLOR := Color(1.0, 0.35, 0.3)
const TORQUE_WARN_THRESHOLD := 50_000.0

var can_launch: bool = false

@onready var _stats_label: RichTextLabel = $VBox/Stats
@onready var _issues_label: RichTextLabel = $VBox/Issues

func refresh(grid: ShipGrid, catalog: BlockCatalog) -> void:
	var stats := ShipStats.compute(grid, catalog)
	var issues := ShipValidator.validate(grid, catalog)
	can_launch = ShipValidator.can_launch(issues)
	_render_stats(stats)
	_render_issues(stats, issues)

func _render_stats(stats: ShipStats) -> void:
	var mass_t := stats.total_mass_kg / 1000.0
	var accel := 0.0
	if stats.total_mass_kg > 0.0:
		accel = stats.thrust_budget[&"forward"] / stats.total_mass_kg
	var yaw_rate := 0.0
	if stats.inertia.y > 0.0:
		yaw_rate = rad_to_deg(stats.torque_budget.y / stats.inertia.y)

	_stats_label.text = "\n".join([
		"[b]MASS[/b]   %.1f t" % mass_t,
		"[b]ACCEL[/b]  %.1f m/s²" % accel,
		"[b]YAW[/b]    %.0f °/s²" % yaw_rate,
		"[b]PWR[/b]    %.1f / %.1f MW" % [stats.power_draw, stats.power_gen],
		"[b]CoM[/b]    %.1f, %.1f, %.1f" % [
			stats.center_of_mass.x, stats.center_of_mass.y, stats.center_of_mass.z
		],
	])

func _render_issues(stats: ShipStats, issues: Array) -> void:
	var lines: Array[String] = []
	for issue in issues:
		var color := ERROR_COLOR if issue.severity == ShipValidator.Severity.ERROR else WARN_COLOR
		lines.append("[color=#%s]%s[/color]" % [color.to_html(false), issue.message])

	if stats.torque_imbalance.length() > TORQUE_WARN_THRESHOLD:
		lines.append("[color=#%s]Torque imbalance: engines will pitch the ship under burn.[/color]"
			% WARN_COLOR.to_html(false))

	_issues_label.text = "\n".join(lines) if not lines.is_empty() else "[color=#6f6]Ready to launch.[/color]"
```

- [ ] **Step 2: Wire it up**

Add to `shipyard.gd` `_ready()`:

```gdscript
	var stats_panel: StatsPanel = $UI/StatsPanel
	grid_dirty.connect(func(): stats_panel.refresh(grid, catalog))
	stats_panel.refresh(grid, catalog)
```

- [ ] **Step 3: Add the panel to the scene**

```
UI/StatsPanel (Control, stats_panel.gd)   anchored right, width 240
└── VBox (VBoxContainer)
    ├── Stats (RichTextLabel, bbcode_enabled)
    └── Issues (RichTextLabel, bbcode_enabled)
```

- [ ] **Step 4: Run and verify**

Press F6 on `shipyard.tscn`.

Expected observations:
- With only the Core placed, the issues panel shows `Ship has no Pilot Seat.` in red.
- Place a Deck then a Pilot Seat beside it: that error disappears.
- Place blocks and watch MASS climb in real time.
- Place two thrusters aft and watch ACCEL jump.
- **Place a heavy reactor at the nose and watch CoM shift and yaw rate drop.**
- Place a single thruster far off the centreline: the torque imbalance warning appears.
- Place a Ladder in a sealed pocket with no deck path: `cannot be reached on foot` appears in red.

- [ ] **Step 5: Commit**

```bash
git add -A who-knows/
git commit -m "feat: add live stats and validation panel to shipyard"
```

---

### Task 19: Mirror mode and blueprint save/load [FEEL]

**Files:**
- Modify: `who-knows/src/editor/shipyard.gd`
- Modify: `who-knows/scenes/shipyard.tscn`
- Test: `who-knows/test/unit/test_mirror.gd`

**Interfaces:**
- Consumes: `ShipBlueprint`, `Orientation`
- Produces: `Shipyard.mirror_x: bool`, `static Shipyard.mirror_coord(coord) -> Vector3i`, `static Shipyard.mirror_orientation(o) -> int`, `Shipyard.save_blueprint(name)`, `Shipyard.load_blueprint(path)`.

- [ ] **Step 1: Write the failing mirror test**

Create `who-knows/test/unit/test_mirror.gd`:

```gdscript
extends GutTest

func test_mirror_coord_negates_x():
	assert_eq(Shipyard.mirror_coord(Vector3i(3, 1, -2)), Vector3i(-3, 1, -2))

func test_mirror_coord_on_centreline_is_itself():
	assert_eq(Shipyard.mirror_coord(Vector3i(0, 2, 5)), Vector3i(0, 2, 5))

func test_mirror_is_an_involution():
	for coord in [Vector3i(4, 0, 0), Vector3i(-1, 3, 2), Vector3i(0, 0, 0)]:
		assert_eq(Shipyard.mirror_coord(Shipyard.mirror_coord(coord)), coord)

func test_mirrored_orientation_is_a_valid_orientation():
	for o in range(Orientation.COUNT):
		var m := Shipyard.mirror_orientation(o)
		assert_true(m >= 0 and m < Orientation.COUNT,
			"orientation %d mirrored out of range to %d" % [o, m])

func test_mirroring_forward_orientation_keeps_it_forward():
	# A thruster pointing aft still points aft on the other side of the hull.
	var mirrored := Shipyard.mirror_orientation(0)
	var forward := Orientation.basis_for(0) * Vector3(0, 0, -1)
	var mirrored_forward := Orientation.basis_for(mirrored) * Vector3(0, 0, -1)
	assert_almost_eq(mirrored_forward.z, forward.z, 0.001)
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `mirror_coord` not found on `Shipyard`.

- [ ] **Step 3: Implement mirror and save/load**

Add to `who-knows/src/editor/shipyard.gd`:

```gdscript
const BLUEPRINT_DIR := "res://data/blueprints"

var mirror_x: bool = false

## Reflects a coordinate across the X = 0 centreline.
static func mirror_coord(coord: Vector3i) -> Vector3i:
	return Vector3i(-coord.x, coord.y, coord.z)

## Finds the orientation whose basis is the X-reflection of `o`'s basis.
## Reflection is not a rotation, so we search the 24 rotations for the one
## that best matches the reflected forward and up axes.
static func mirror_orientation(o: int) -> int:
	var source := Orientation.basis_for(o)
	var want_forward := _reflect_x(source * Vector3(0, 0, -1))
	var want_up := _reflect_x(source * Vector3(0, 1, 0))

	var best := o
	var best_score := -INF
	for candidate in range(Orientation.COUNT):
		var b := Orientation.basis_for(candidate)
		var score := (b * Vector3(0, 0, -1)).dot(want_forward) \
			+ (b * Vector3(0, 1, 0)).dot(want_up)
		if score > best_score:
			best_score = score
			best = candidate
	return best

static func _reflect_x(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)

func save_blueprint(name: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BLUEPRINT_DIR))
	var bp := ShipBlueprint.from_grid(grid, name)
	var path := "%s/%s.tres" % [BLUEPRINT_DIR, name.to_snake_case()]
	return ResourceSaver.save(bp, path)

func load_blueprint(path: String) -> void:
	var bp := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ShipBlueprint
	if bp == null:
		push_error("Shipyard: could not load blueprint at %s" % path)
		return
	var loaded := bp.to_grid()
	loaded.cell_changed.connect(func(_c: Vector3i): _rebuild())
	grid = loaded
	_exterior_builder.bind(grid, catalog)
	_interior_builder.bind(grid, catalog)
	_rebuild()
```

Then change `_place()` and `_erase()` to honour mirroring. Replace the body of `_place()`:

```gdscript
func _place() -> void:
	var coord = _pick_placement_coord()
	if coord == null:
		return
	_place_at(coord, ghost_orientation)
	if mirror_x:
		var mirrored := mirror_coord(coord)
		if mirrored != coord:
			_place_at(mirrored, mirror_orientation(ghost_orientation))

func _place_at(coord: Vector3i, orientation: int) -> void:
	if grid.has_block(coord):
		return
	var inst := BlockInstance.new()
	inst.block_id = selected_block
	inst.orientation = orientation
	var def := catalog.get_def(selected_block)
	inst.hp_current = def.hp if def != null else 100
	grid.set_block(coord, inst)
```

And replace the body of `_erase()`:

```gdscript
func _erase() -> void:
	var coord = _pick_erase_coord()
	if coord == null or coord == Vector3i.ZERO:
		return
	grid.clear_block(coord)
	if mirror_x:
		var mirrored := mirror_coord(coord)
		if mirrored != Vector3i.ZERO:
			grid.clear_block(mirrored)
```

Finally add the M key to `_unhandled_input`, in the `InputEventKey` branch:

```gdscript
		elif event.keycode == KEY_M:
			mirror_x = not mirror_x
			print("Mirror X: ", "ON" if mirror_x else "OFF")
```

- [ ] **Step 4: Run to verify the tests pass**

```bash
powershell -File "D:/git/whoknows/who-knows/run_tests.ps1"
```

Expected: PASS, 5 mirror tests green plus everything from Tasks 7–15.

- [ ] **Step 5: Add save/load UI and verify by hand**

Add to `shipyard.tscn` under `UI`: a `LineEdit` for the ship name and `Save` / `Load` buttons wired to `save_blueprint()` and `load_blueprint()`.

Press F6 and verify:
- Press M, then place a thruster off the centreline. **A matching thruster appears mirrored on the other side, correctly oriented.**
- Middle-click one of a mirrored pair with M on: both disappear.
- Name the ship, press Save, quit, relaunch, press Load: the ship returns exactly as built.
- Open the saved `.tres` in a text editor — the coordinate list is sorted and readable.

- [ ] **Step 6: Commit**

```bash
git add -A who-knows/
git commit -m "feat: add mirror mode and blueprint save/load to shipyard"
```

---

### Task 20: Walk Test, Launch, and the canopy [FEEL]

**Files:**
- Modify: `who-knows/src/editor/shipyard.gd`
- Modify: `who-knows/scenes/shipyard.tscn`
- Modify: `who-knows/scenes/flight_test.tscn`
- Modify: `who-knows/scenes/flight_test.gd`
- Create: `who-knows/docs/playtest-checklist.md`

**Interfaces:**
- Consumes: everything
- Produces: the complete Slice 1 loop.

- [ ] **Step 1: Add scene handoff to the shipyard**

Add to `who-knows/src/editor/shipyard.gd`:

```gdscript
const HANDOFF_PATH := "user://handoff.tres"
const FLIGHT_SCENE := "res://scenes/flight_test.tscn"

## Saves the current grid where flight_test.gd will find it, then switches
## scenes. `walk_only` starts the player on foot with engines cold.
func launch(walk_only: bool) -> void:
	var stats_panel: StatsPanel = $UI/StatsPanel
	if not stats_panel.can_launch:
		push_warning("Shipyard: fix build errors before launching")
		return
	ResourceSaver.save(ShipBlueprint.from_grid(grid, "Handoff"), HANDOFF_PATH)
	var config := ConfigFile.new()
	config.set_value("handoff", "walk_only", walk_only)
	config.save("user://handoff.cfg")
	get_tree().change_scene_to_file(FLIGHT_SCENE)
```

Wire two buttons in `UI`: `WalkTestButton` calls `launch(true)`, `LaunchButton` calls `launch(false)`.

- [ ] **Step 2: Make the flight scene consume the handoff**

Replace `who-knows/scenes/flight_test.gd`:

```gdscript
extends Node3D

## Loads whatever the shipyard handed off. Falls back to a built-in
## starter corvette when the scene is run directly from the editor.

const HANDOFF_PATH := "user://handoff.tres"

@onready var _ship: Ship = $Ship

func _ready() -> void:
	var bp := ResourceLoader.load(HANDOFF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ShipBlueprint
	if bp != null:
		_ship.load_blueprint(bp)
	else:
		_ship.set_grid(_starter_grid())
	_place_avatar_at_seat()

func _place_avatar_at_seat() -> void:
	# Drop the player onto the deck cell nearest the pilot seat.
	for coord in _ship.grid.coords():
		if _ship.grid.get_block(coord).block_id == &"pilot_seat":
			$Ship/Interior/Avatar.global_position = (
				_ship.interior.global_position
				+ ShipGrid.cell_center(coord)
				+ Vector3(0, 0.2, ShipGrid.CELL_SIZE)
			)
			return

func _starter_grid() -> ShipGrid:
	var g := ShipGrid.new()
	for z in range(-3, 4):
		for x in range(-1, 2):
			_put(g, Vector3i(x, 0, z), &"deck" if x == 0 else &"hull")
	_put(g, Vector3i(0, 0, -3), &"pilot_seat")
	_put(g, Vector3i(0, 0, 0), &"core")
	_put(g, Vector3i(1, 0, 1), &"reactor")
	_put(g, Vector3i(-1, 0, 1), &"grav_plating")
	_put(g, Vector3i(-1, 0, 3), &"thruster")
	_put(g, Vector3i(1, 0, 3), &"thruster")
	_put(g, Vector3i(0, 0, 3), &"airlock")
	return g

func _put(g: ShipGrid, coord: Vector3i, id: StringName) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	g.set_block(coord, i)
```

- [ ] **Step 3: Add the canopy viewport**

In `flight_test.tscn`:
- Add `SubViewport` (size 1024 × 512, `render_target_update_mode = ALWAYS`) under `Ship`.
- Add a `Camera3D` inside it named `CanopyCam`, `current = true` within that viewport.
- Add a script or a `RemoteTransform3D` on `Ship/Exterior` so `CanopyCam` copies the hull's global transform each frame, offset forward to the bridge.
- Add a `MeshInstance3D` quad in front of the pilot seat in the interior, with an unshaded `StandardMaterial3D` whose `albedo_texture` is the `SubViewport`'s `ViewportTexture`.

- [ ] **Step 4: Write the playtest checklist**

Create `who-knows/docs/playtest-checklist.md`:

```markdown
# Slice 1 playtest checklist

Run every build. Feel cannot be unit tested.

## Shipyard
- [ ] A new ship starts with a Core and nothing else.
- [ ] Orbit, zoom, and ghost placement all feel responsive.
- [ ] Deck slicer reveals interiors; you can lay a corridor without fighting the camera.
- [ ] Stats update the instant a block is placed.
- [ ] Reactor in the nose visibly shifts CoM and drops yaw rate.
- [ ] A mount sealed behind a bulkhead reports "cannot be reached on foot".
- [ ] Mirror mode places correctly-oriented pairs.
- [ ] Save, quit, load: the ship returns exactly as built.

## Flight
- [ ] Launch produces the ship you drew.
- [ ] Assist ON bleeds off drift; assist OFF drifts forever.
- [ ] A torque-imbalanced ship feels sluggish in a legible way.
- [ ] Boost is clearly more than full throttle.

## The premise
- [ ] The seat transition reads as continuous — no cut, no snap at either end.
- [ ] Standing up mid-burn shoves you aft; walking forward feels uphill.
- [ ] The shake scales with thrust and stops with the engines.
- [ ] Rolling the ship rolls the starfield past the windows.
- [ ] The canopy shows the real exterior, matching what the chase camera sees.
- [ ] Sitting and standing five times in a row leaves no drift or camera offset.
- [ ] A new player can build a valid ship without reading anything.
```

- [ ] **Step 5: Run the full loop end to end**

Open `shipyard.tscn`. Build a corvette: a hull shell, a central corridor of Deck blocks, a Pilot Seat at the bow, a Reactor, Grav Plating, two Thrusters aft, an Airlock at the stern. Fix any red validation errors. Press **Walk Test** — confirm you are standing in your own ship. Return to the shipyard. Press **Launch**.

Then run the **definition of done** from spec §14, in one unbroken session:

> Set a burn, stand up, walk to the back of your own accelerating ship, watch the stars roll past the window, walk back, sit down, and fly on — with no cut, no load, and no jitter.

- [ ] **Step 6: Run the full test suite one final time**

```bash
powershell -File "D:/git/whoknows/who-knows/run_tests.ps1"
```

Expected: all suites green — harness, orientation, catalog, grid, deck graph, validator, stats, blueprint, exterior parity, interior parity, block data, mirror.

- [ ] **Step 7: Commit**

```bash
git add -A who-knows/
git commit -m "feat: complete Slice 1 loop with walk test, launch, and canopy viewport"
```

---

## Self-review notes

**Spec coverage.** Every numbered spec section maps to at least one task: §3 architecture → Tasks 2, 6, 15; §4 data model → Tasks 7, 8; §4.1 occupancy → Tasks 7, 9; §5 catalogue → Task 15; §6.1 rules → Task 10; §6.2 stats → Task 11; §7.1 flight → Tasks 4, 15; §7.2 cameras → Task 5; §7.3 seat transition → Task 5; §7.4 mid-burn → Task 6; §7.5 avatar → Task 3; §8 shipyard → Tasks 16–20; §9 structure → file map above; §10 testing → every LOGIC task plus Task 20's checklist; §12 non-goals → nothing here shoots; §13 hooks → `BlockInstance` per-instance state (Task 7), interior slots (Task 2), airlock block (Task 15), Core as identity (Tasks 10, 16); §14 done → Task 20 step 5.

**Deferred deliberately.** Spec §11 art direction is placeholder `BoxMesh` throughout — Task 15 notes that swapping in real meshes touches only the `mesh` field. Powered Doors are placeable and walkable but do not animate open and closed; nothing in Slice 1 needs them to, and Slice 3 is where a door becomes a tactical object.

**Known rough edge.** `ShipStats.torque_budget` is a crude proxy — RCS thrust magnitude times cell size — rather than a true per-thruster moment sum. It is good enough to make turn rates respond to layout, and Task 18's panel surfaces it honestly as an acceleration figure. If turn rates feel wrong during Task 20's playtest, that is the calculation to revisit first.
