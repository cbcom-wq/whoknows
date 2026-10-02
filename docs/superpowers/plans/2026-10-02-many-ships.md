# Many Ships Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Any number of ships in the world, each one boardable, flyable and saved, with you handed between them.

**Architecture:** The `/Ship` subtree of `flight_test.tscn` becomes `scenes/ship.tscn`, a complete ship; the starter is an instance of it still named `Ship`. The camera director moves to the scene root, and each ship's seat and controls are handed it by reference. A new `Fleet` node owns every ship (slots, names, spawning, sleeping far ones); the flight scene's `aboard` is the ship you are in, and `board(ship)` is the one switch that moves your views, HUD, hands and the floating origin's focus to it.

**Tech Stack:** Godot 4.5.1, GDScript, GUT (headless) for tests.

**Spec:** `docs/superpowers/specs/2026-10-02-many-ships-design.md`

## Global Constraints

- **Godot:** `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe` (call it `$godot` below).
- **Where commands run:** the repo root, `D:\git\whoknows`. Check `pwd` before every test command: `run_tests.ps1` resolves from the current directory, and a shell in another tree runs that tree's code (the ship skill's *Mistakes already made*).
- **One test file:** `./who-knows/run_tests.ps1 -gselect=test_fleet.gd` (PowerShell). **Several:** `foreach ($t in "test_a","test_b") { ./who-knows/run_tests.ps1 -gselect="$t.gd"; if ($LASTEXITCODE) { break } }`. Watch the exit code, not only the pass count.
- **The full suite** (about 8 minutes) runs **only with the owner's say-so**, once, at the end (Task 8). Every task runs only the files that cover it.
- **New script or `class_name`:** run `& $godot --headless --path who-knows --import`, then commit the generated `.uid` files (the repo tracks them).
- **`.tscn`/`.tres`:** no `#` comment lines anywhere inside them (`CLAUDE.md`). Check an edited scene by reading properties back at runtime, never by a clean load.
- **Floating origin (`CLAUDE.md`):** anything outside the interior is in `Universe.EXTERIOR_SPACE` or listens to `Universe.shifted`; positions that must survive a shift are `UniversePoint`s.
- **Numbers, verbatim from the spec:** `Fleet.MAX_SHIPS` 16; `SLEEP_AT` 20 km; `WAKE_AT` 18 km; sleep checked at 1 Hz; `SuitTie.SWITCH_MARGIN` 10 m, `REACH` 500 m, checked at 4 Hz; debug key **F8**; `SaveGame.FORMAT` 2; the starter is named `Ship`, spawned ships `Ship2`, `Ship3`…; the worst view holds **≥ 120 fps** at 1280 × 720 with a second ship 300 m off.
- **Comments** read like the code round them: `##` doc comments in plain sentences, citing the spec's section (`many ships spec §4.1`).
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Branch: `many-ships`.

## Review Focus

1. **Boarding by F8 while holding something:** the item stays in your hand, and dropped, lands in the ship you are now in. Test in Task 4.
2. **A save made on a spacewalk tied to the second ship:** it resumes tied to that ship, with its airlock as home. Test in Task 7.
3. **An origin shift with two ships awake:** both hulls move together, and neither interior moves. Test in Task 3.
4. **A ship falling asleep while its RCS puffs, or just struck:** its emitters stop, so it never holds the origin shift, and asleep it never holds the save. Test in Task 6.
5. **A block knocked off a ship you are not in:** you stay where you are, not thrown outside. Test in Task 3.

---

### Task 1: The ship becomes its own scene

The starter keeps working exactly as before, but as an instance of `scenes/ship.tscn`, with the camera director at the scene root.

**Deviation from the spec (§3.1), on purpose:** the canopy material is built in code (`Ship._make_canopy_material`, from `Canopy.get_texture()`) instead of a `resource_local_to_scene` `ViewportTexture` in the `.tscn`. A `ViewportTexture`'s path inside an instanced scene is fragile in Godot, and the code version can be checked directly. Record this in the spec's *What was built* (Task 8).

**Files:**
- Create: `who-knows/scenes/ship.tscn`
- Create: `who-knows/test/unit/test_ship_scene.gd`
- Modify: `who-knows/scenes/flight_test.tscn` (lines 1–177 replaced)
- Modify: `who-knows/scenes/flight_test.gd` (`_director` path; hand the director over after `set_grid`)
- Modify: `who-knows/src/ship/ship.gd` (accessors, canopy material)
- Modify: `who-knows/src/avatar/pilot_seat.gd`, `who-knows/src/flight/pilot_controls.gd`, `who-knows/src/camera/motion_coupling.gd`, `who-knows/src/camera/camera_director.gd`
- Modify (paths only): `who-knows/test/unit/test_avatar_modes.gd`, `test_hud_scene_wiring.gd`, `test_pilot_controls.gd`, `test_pilot_seat.gd`, `test_save_scene.gd`; `who-knows/test/probes/computer_render.gd`, `system_render.gd`; `.claude/skills/building-a-ship/ship_probe.gd`

**Interfaces:**
- Produces:
  - `Ship.pilot: PilotControls`, `Ship.seat: PilotSeat`, `Ship.motion: MotionCoupling`, `Ship.chase_camera: Camera3D`, `Ship.canopy_camera: Camera3D`, `Ship.canopy_overlay: Control` (all `@onready`)
  - `PilotSeat.director: CameraDirector`
  - `PilotControls.director: CameraDirector`, `PilotControls.bind_director(d: CameraDirector) -> void`
  - `CameraDirector.seat_ship() -> Ship`, `static CameraDirector.ship_of(node: Node) -> Ship`
  - `MotionCoupling.interior_path: NodePath`, `MotionCoupling.PLATING_GRAVITY := 9.8`
  - Scene: `/CameraDirector` at the flight scene's root.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_ship_scene.gd`:

```gdscript
extends GutTest

## The ship as a scene of its own (docs/superpowers/specs/
## 2026-10-02-many-ships-design.md §3): everything one ship needs to be flown,
## and nothing of yours. Read back at runtime: a `#` in a .tscn drops
## properties without a word (CLAUDE.md).

const SHIP := "res://scenes/ship.tscn"
const FLIGHT := "res://scenes/flight_test.tscn"

## A ship on its own, under a Node3D that stands in for the outside.
func _ship(slot := 3) -> Ship:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var ship: Ship = load(SHIP).instantiate()
	ship.interior_slot = slot
	holder.add_child(ship)
	return ship

func test_the_ship_scene_holds_a_whole_ship():
	var ship := _ship()
	for path in ["Exterior", "Exterior/ExteriorBuilder", "Exterior/ChaseCamera", "FlightComputer",
			"PilotControls", "MotionCoupling", "CanopyPortal", "Canopy", "Canopy/CanopyCam",
			"Canopy/CanopyOverlay/CockpitMarker", "Canopy/CanopyOverlay/HeadingCockpitMarker",
			"Interior", "Interior/InteriorBuilder", "Interior/PilotSeat", "Interior/PilotSeat/Eye"]:
		assert_not_null(ship.get_node_or_null(path), "%s present" % path)
	assert_null(ship.get_node_or_null("CameraDirector"), "the director is the game's, not the ship's")
	assert_null(ship.get_node_or_null("Interior/Avatar"), "and so are you")

func test_every_exported_path_survived_the_parse():
	var ship := _ship()
	var portal := ship.get_node("CanopyPortal")
	for pair in [[ship.flight_computer, "hull_path"], [ship.pilot, "flight_computer_path"],
			[ship.pilot, "hull_path"], [ship.pilot, "interior_path"], [ship.motion, "hull_path"],
			[ship.motion, "interior_path"], [ship.motion, "interior_builder_path"],
			[ship.exterior_builder, "body_path"], [portal, "viewport_path"], [portal, "camera_path"],
			[portal, "hull_path"], [portal, "interior_path"]]:
		var node: Node = pair[0]
		var path: NodePath = node.get(pair[1])
		assert_ne(path, NodePath(""), "%s.%s was not dropped" % [node.name, pair[1]])
		assert_not_null(node.get_node_or_null(path), "%s.%s resolves" % [node.name, pair[1]])
	assert_almost_eq(ship.seat.get_node("Eye").position, Vector3(0, 1.35, 0.45), Vector3.ONE * 0.001)
	assert_eq(ship.seat.collision_layer, 2)
	assert_eq(ship.chase_camera.cull_mask, 5)
	assert_eq(ship.canopy_camera.cull_mask, 1)
	assert_eq((ship.get_node("Canopy") as SubViewport).render_target_update_mode, SubViewport.UPDATE_ALWAYS)

func test_each_ship_draws_its_own_canopy_view():
	var a := _ship(3)
	var b := _ship(4)
	var mat_a := a.interior_builder.canopy_material as ShaderMaterial
	var mat_b := b.interior_builder.canopy_material as ShaderMaterial
	assert_not_null(mat_a, "a canopy material")
	assert_ne(mat_a, mat_b, "one each")
	assert_eq(mat_a.get_shader_parameter(&"canopy_view"), (a.get_node("Canopy") as SubViewport).get_texture())
	assert_eq(mat_b.get_shader_parameter(&"canopy_view"), (b.get_node("Canopy") as SubViewport).get_texture())

func test_the_starter_is_an_instance_of_it():
	var root: Node = load(FLIGHT).instantiate()
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	assert_eq(ship.scene_file_path, SHIP)
	var director := root.get_node_or_null("CameraDirector") as CameraDirector
	assert_not_null(director, "the director at the root")
	assert_true(root.get_node_or_null("Ship/Interior/Avatar") is Avatar, "you start aboard it")
	assert_eq(ship.outside, root.get_node("Outside"))
	assert_same(ship.seat.director, director, "its seat was handed the director")
	assert_same(ship.pilot.director, director, "and so were its controls")
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `./who-knows/run_tests.ps1 -gselect=test_ship_scene.gd`
Expected: FAIL (`res://scenes/ship.tscn` does not exist).

- [ ] **Step 3: Create `who-knows/scenes/ship.tscn`**

No `#` lines anywhere in it.

```
[gd_scene load_steps=12 format=3]

[ext_resource type="Script" path="res://src/ship/ship.gd" id="1_ship"]
[ext_resource type="Script" path="res://src/ship/exterior_builder.gd" id="2_exterior_builder"]
[ext_resource type="Script" path="res://src/flight/flight_computer.gd" id="3_flight_computer"]
[ext_resource type="Script" path="res://src/ship/canopy_portal.gd" id="4_canopy_portal"]
[ext_resource type="Script" path="res://src/ui/velocity_marker.gd" id="5_velocity_marker"]
[ext_resource type="Script" path="res://src/ui/heading_marker.gd" id="6_heading_marker"]
[ext_resource type="Script" path="res://src/ship/interior_builder.gd" id="7_interior_builder"]
[ext_resource type="Script" path="res://src/avatar/pilot_seat.gd" id="8_pilot_seat"]
[ext_resource type="Script" path="res://src/camera/motion_coupling.gd" id="9_motion_coupling"]
[ext_resource type="Script" path="res://src/flight/pilot_controls.gd" id="10_pilot_controls"]

[sub_resource type="BoxShape3D" id="BoxShape3D_seat"]
size = Vector3(1.4, 1.6, 1.4)

[node name="Ship" type="Node3D"]
script = ExtResource("1_ship")

[node name="Exterior" type="RigidBody3D" parent="."]
mass = 42000.0

[node name="ExteriorBuilder" type="Node3D" parent="Exterior"]
script = ExtResource("2_exterior_builder")
body_path = NodePath("..")

[node name="ChaseCamera" type="Camera3D" parent="Exterior"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 5, 26)
current = false
cull_mask = 5

[node name="FlightComputer" type="Node" parent="."]
script = ExtResource("3_flight_computer")
hull_path = NodePath("../Exterior")

[node name="CanopyPortal" type="Node" parent="."]
script = ExtResource("4_canopy_portal")
viewport_path = NodePath("../Canopy")
camera_path = NodePath("../Canopy/CanopyCam")
hull_path = NodePath("../Exterior")
interior_path = NodePath("../Interior")

[node name="Canopy" type="SubViewport" parent="."]
size = Vector2i(1536, 512)
render_target_update_mode = 4

[node name="CanopyCam" type="Camera3D" parent="Canopy"]
current = true
cull_mask = 1
fov = 40.0

[node name="CanopyOverlay" type="Control" parent="Canopy"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="CockpitMarker" type="Control" parent="Canopy/CanopyOverlay"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("5_velocity_marker")
camera_path = NodePath("../../CanopyCam")

[node name="HeadingCockpitMarker" type="Control" parent="Canopy/CanopyOverlay"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("6_heading_marker")
camera_path = NodePath("../../CanopyCam")

[node name="Interior" type="Node3D" parent="."]

[node name="InteriorBuilder" type="Node3D" parent="Interior"]
script = ExtResource("7_interior_builder")

[node name="PilotSeat" type="StaticBody3D" parent="Interior"]
position = Vector3(0, -0.95, -4)
collision_layer = 2
collision_mask = 0
script = ExtResource("8_pilot_seat")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Interior/PilotSeat"]
position = Vector3(0, -0.1, 0)
shape = SubResource("BoxShape3D_seat")

[node name="Eye" type="Node3D" parent="Interior/PilotSeat"]
position = Vector3(0, 1.35, 0.45)

[node name="MotionCoupling" type="Node" parent="."]
script = ExtResource("9_motion_coupling")
hull_path = NodePath("../Exterior")
interior_path = NodePath("../Interior")
interior_builder_path = NodePath("../Interior/InteriorBuilder")

[node name="PilotControls" type="Node" parent="."]
script = ExtResource("10_pilot_controls")
flight_computer_path = NodePath("../FlightComputer")
hull_path = NodePath("../Exterior")
interior_path = NodePath("../Interior")
```

- [ ] **Step 4: Replace lines 1–177 of `who-knows/scenes/flight_test.tscn`**

Everything from line 178 (`[node name="Outside" type="Node3D" parent="."]`) to the end stays exactly as it is. Lines 1–177 become:

```
[gd_scene load_steps=21 format=3]

[ext_resource type="PackedScene" path="res://scenes/ship.tscn" id="1_ship"]
[ext_resource type="PackedScene" path="res://scenes/avatar.tscn" id="2_avatar"]
[ext_resource type="Script" path="res://src/avatar/interactor.gd" id="4_interactor"]
[ext_resource type="Script" path="res://src/camera/camera_director.gd" id="6_camera_director"]
[ext_resource type="Script" path="res://scenes/flight_test.gd" id="11_flight_test"]
[ext_resource type="Script" path="res://src/ui/hud_root.gd" id="12_hud_root"]
[ext_resource type="Script" path="res://src/ui/velocity_marker.gd" id="13_velocity_marker"]
[ext_resource type="Script" path="res://src/ui/panels/velocity_panel.gd" id="14_velocity_panel"]
[ext_resource type="Script" path="res://src/ui/panels/attitude_panel.gd" id="15_attitude_panel"]
[ext_resource type="Script" path="res://src/ui/hud_band.gd" id="16_hud_band"]
[ext_resource type="Script" path="res://src/ui/airlock_marker.gd" id="19_airlock_marker"]
[ext_resource type="Script" path="res://src/world/universe.gd" id="20_universe"]
[ext_resource type="Script" path="res://src/world/asteroid_stream.gd" id="21_asteroid_stream"]
[ext_resource type="Script" path="res://src/ui/stick_cursor.gd" id="23_stick_cursor"]
[ext_resource type="Script" path="res://src/ui/heading_marker.gd" id="24_heading_marker"]
[ext_resource type="Script" path="res://src/ui/controls_card.gd" id="25_controls_card"]
[ext_resource type="Script" path="res://src/ui/energy_panel.gd" id="26_energy_panel"]

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_flighttest"]
sky_top_color = Color(0.02, 0.02, 0.05, 1)
sky_horizon_color = Color(0.05, 0.05, 0.09, 1)
sky_curve = 0.15
ground_bottom_color = Color(0.01, 0.01, 0.02, 1)
ground_horizon_color = Color(0.05, 0.05, 0.09, 1)
ground_curve = 0.15
sun_angle_max = 1.0

[sub_resource type="Sky" id="Sky_flighttest"]
sky_material = SubResource("ProceduralSkyMaterial_flighttest")

[sub_resource type="Environment" id="Environment_flighttest"]
background_mode = 2
sky = SubResource("Sky_flighttest")

[node name="FlightTest" type="Node3D"]
script = ExtResource("11_flight_test")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_flighttest")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-45, 30, 0)
shadow_enabled = true
light_cull_mask = 5

[node name="Universe" type="Node" parent="."]
script = ExtResource("20_universe")

[node name="AsteroidStream" type="Node3D" parent="."]
script = ExtResource("21_asteroid_stream")

[node name="Ship" parent="." instance=ExtResource("1_ship")]
outside_path = NodePath("../Outside")

[node name="Avatar" parent="Ship/Interior" instance=ExtResource("2_avatar")]
position = Vector3(0, 0.1, 3.0)

[node name="Interactor" type="RayCast3D" parent="Ship/Interior/Avatar/Head" owner="Ship/Interior/Avatar"]
script = ExtResource("4_interactor")

[node name="CameraDirector" type="Node" parent="."]
script = ExtResource("6_camera_director")
avatar_path = NodePath("../Ship/Interior/Avatar")
flight_computer_path = NodePath("../Ship/FlightComputer")
interior_camera_path = NodePath("../Ship/Interior/Avatar/Head/Camera3D")
chase_camera_path = NodePath("../Ship/Exterior/ChaseCamera")

```

(`ChaseMarker` and `HeadingChaseMarker` further down keep `camera_path = NodePath("../../../Ship/Exterior/ChaseCamera")`: it still resolves.)

- [ ] **Step 5: `ship.gd`: accessors and a canopy material of its own**

In `who-knows/src/ship/ship.gd`, after `const HULL_LIVERY_MATERIAL ...` add:

```gdscript
## The window glass's shader; each ship makes its own material from it.
const CANOPY_SHADER: Shader = preload("res://data/materials/interior/canopy_window.gdshader")
```

After the existing `@onready var flight_computer ...` line add:

```gdscript
## The parts of ship.tscn the flight scene hands you between (many ships spec
## §3.1).
@onready var pilot: PilotControls = $PilotControls
@onready var seat: PilotSeat = $Interior/PilotSeat
@onready var motion: MotionCoupling = $MotionCoupling
@onready var chase_camera: Camera3D = $Exterior/ChaseCamera
@onready var canopy_camera: Camera3D = $Canopy/CanopyCam
@onready var canopy_overlay: Control = $Canopy/CanopyOverlay
```

In `_ready()`, as its first line (before `exterior.gravity_scale = 0.0`):

```gdscript
	_make_canopy_material()
```

And add the method after `_ready()`:

```gdscript
## Every window's glass shows this ship's own canopy view (cockpit pod spec
## §3): one material per ship, fed by its own SubViewport, so each instance of
## ship.tscn draws its own (many ships spec §3.1). Made here rather than in the
## .tscn: a ViewportTexture's path inside an instanced scene is fragile.
func _make_canopy_material() -> void:
	var canopy := get_node_or_null("Canopy") as SubViewport
	if canopy == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = CANOPY_SHADER
	mat.set_shader_parameter(&"canopy_view", canopy.get_texture())
	interior_builder.canopy_material = mat
```

- [ ] **Step 6: `pilot_seat.gd`: the director by reference**

Replace `@export var camera_director_path: NodePath` with:

```gdscript
## The game's one camera director (many ships spec §3.2), handed over by the
## flight scene: a ship's scene cannot reach it by path.
var director: CameraDirector
```

Replace `interact`'s body with:

```gdscript
func interact(avatar: Avatar) -> void:
	if director != null:
		director.sit(self)
	# `avatar` is unused here; the director owns the handoff. Kept in the
	# signature because every interactable receives it.
```

- [ ] **Step 7: `camera_director.gd`: which ship your seat is in**

Add after `is_moving()`:

```gdscript
## The ship whose seat you sit in, or null standing (many ships spec §3.2):
## every ship's controls ask, and take the stick only for their own.
func seat_ship() -> Ship:
	return ship_of(_seat) if is_seated else null

## The Ship `node` is part of, or null.
static func ship_of(node: Node) -> Ship:
	while node != null and not (node is Ship):
		node = node.get_parent()
	return node as Ship
```

- [ ] **Step 8: `pilot_controls.gd`: the stick only for its own seat**

Remove `@export var camera_director_path: NodePath` and the whole `_ready()` function. After `var lights: ShipLights` add:

```gdscript
## The game's one camera director (many ships spec §3.2). A ship's scene
## cannot reach it by path, so the flight scene hands it over.
var director: CameraDirector
```

After `set_seated` add:

```gdscript
## Listens to `d` for sitting and standing. Every ship's controls hear every
## sit, and take the stick only when the seat is their own ship's. Bound late,
## they catch up with a sit that has already happened (a game loaded at the
## helm).
func bind_director(d: CameraDirector) -> void:
	if director != null and director.piloting_changed.is_connected(_on_piloting_changed):
		director.piloting_changed.disconnect(_on_piloting_changed)
	director = d
	director.piloting_changed.connect(_on_piloting_changed)
	_on_piloting_changed(director.is_seated)

func _on_piloting_changed(piloting: bool) -> void:
	set_seated(piloting and director.seat_ship() == get_parent())
```

- [ ] **Step 9: `motion_coupling.gd`: you, found by group, shoved only in its interior**

Replace `@export var avatar_path: NodePath` with:

```gdscript
## The ship's Interior: you are shoved only while you stand in it (many ships
## spec §3.2).
@export var interior_path: NodePath
```

Add with the other constants:

```gdscript
## The plating gravity loose items feel when no one is about to read it from:
## the avatar's own default grav_strength.
const PLATING_GRAVITY := 9.8
```

Replace `@onready var _avatar: Avatar = get_node(avatar_path)` with:

```gdscript
@onready var _interior: Node3D = get_node_or_null(interior_path) if not interior_path.is_empty() else null
var _avatar: Avatar
```

Add after `_physics_process`:

```gdscript
## You, wherever you are: a ship's scene holds no path to you, so you are found
## by group, as the airlock finds you.
func _you() -> Avatar:
	if not is_instance_valid(_avatar) and is_inside_tree():
		_avatar = get_tree().get_first_node_in_group(Avatar.GROUP) as Avatar
	return _avatar

## True while you stand in this ship's interior: only then are you shoved.
func _you_aboard() -> bool:
	var you := _you()
	return you != null and you.mode == Avatar.Mode.PLATING \
		and (_interior == null or you.get_parent() == _interior)
```

In `_physics_process`, change both `if _avatar.mode == Avatar.Mode.PLATING:` lines to `if _you_aboard():`, and inside them `_avatar.external_accel` to `_you().external_accel`. In `_apply_shake`, change `_avatar.head` (two places) to `_you().head`. In `drive_felt_gravity`, change the `set_felt` line to:

```gdscript
	var you := _you()
	var g := you.grav_strength if you != null else PLATING_GRAVITY
	_builder.felt_gravity.set_felt(Vector3.DOWN * g + shove)
```

- [ ] **Step 10: `flight_test.gd`: the director at the root, handed to the ship**

Change `@onready var _director: CameraDirector = $Ship/CameraDirector` to `@onready var _director: CameraDirector = $CameraDirector`. In `_ready()`, right after `_ship.set_grid(layout if resumed else _starter_grid(), not resumed)`, add:

```gdscript
	# The ship's scene cannot reach the game's director by path (many ships
	# spec §3.2): its seat and controls are handed it.
	_ship.seat.director = _director
	_ship.pilot.bind_director(_director)
```

- [ ] **Step 11: Point the tests and probes at the moved director**

```bash
cd /d/git/whoknows
sed -i 's#"Ship/CameraDirector"#"CameraDirector"#g' who-knows/test/unit/test_avatar_modes.gd who-knows/test/unit/test_hud_scene_wiring.gd who-knows/test/unit/test_pilot_controls.gd who-knows/test/unit/test_pilot_seat.gd who-knows/test/unit/test_save_scene.gd
sed -i 's#_ship.get_node("CameraDirector")#_ship.get_parent().get_node("CameraDirector")#' who-knows/test/probes/computer_render.gd who-knows/test/probes/system_render.gd
sed -i 's#ship.get_node("CameraDirector")#scene.get_node("CameraDirector")#' .claude/skills/building-a-ship/ship_probe.gd
```

In `test_hud_scene_wiring.gd`, `test_pilot_controls_survived_the_parse` becomes:

```gdscript
func test_pilot_controls_survived_the_parse():
	var pilot: PilotControls = _root.get_node_or_null("Ship/PilotControls")
	assert_not_null(pilot, "PilotControls present")
	for path in [pilot.flight_computer_path, pilot.hull_path, pilot.interior_path]:
		assert_ne(path, NodePath(""), "no export was dropped")
		assert_not_null(pilot.get_node_or_null(path), "%s resolves" % path)
	assert_same(pilot.director, _root.get_node("CameraDirector"), "handed the director")
```

Then check nothing still reaches for the old paths; this must print nothing:

```bash
grep -rn "Ship/CameraDirector\|camera_director_path" who-knows/test who-knows/scenes who-knows/src .claude/skills
```

- [ ] **Step 12: Import, then run the covering tests**

```powershell
& $godot --headless --path who-knows --import
foreach ($t in "test_ship_scene","test_hud_scene_wiring","test_pilot_seat","test_pilot_controls","test_avatar_modes","test_motion_coupling","test_crash_feel","test_save_scene","test_floating_origin_scene","test_droid_scene","test_deck_walker","test_bridge_computer_scene") { ./who-knows/run_tests.ps1 -gselect="$t.gd"; if ($LASTEXITCODE) { break } }
```

Expected: all PASS, exit code 0, and no `SCRIPT ERROR` in the output.

- [ ] **Step 13: Commit**

```bash
git add who-knows/scenes/ship.tscn who-knows/scenes/flight_test.tscn who-knows/scenes/flight_test.gd who-knows/src who-knows/test .claude/skills/building-a-ship/ship_probe.gd
git add who-knows/test/unit/test_ship_scene.gd.uid
git commit -m "feat: many ships -- the ship is its own scene; the camera director is the game's

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Your hull and the others'

**Files:**
- Modify: `who-knows/src/ship/ship.gd`
- Create: `who-knows/test/unit/test_ship_own.gd`

**Interfaces:**
- Consumes: the flight scene's `Ship` (Task 1).
- Produces: `Ship.own: bool` (default `true`), `Ship.set_own(on: bool) -> void`, `Ship.OWN_ONLY := &"own_only"` (meta on pieces made for the own layer alone). Re-applied at the end of every `_rebuild_everything`.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_ship_own.gd`:

```gdscript
extends GutTest

## Which ship's hull is drawn as your own (many ships spec §4.2): yours on
## ExteriorBuilder.OWN_HULL_LAYER, which every window leaves out; any other's
## on layer 1, so you see it through your windows; and only your interior
## shown.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

## How many drawn pieces of the hull are on each set of layers.
func _layers() -> Dictionary:
	var out := {}
	for node in _ship.exterior.find_children("*", "GeometryInstance3D", true, false):
		var layers := (node as GeometryInstance3D).layers
		out[layers] = out.get(layers, 0) + 1
	return out

func test_a_ship_is_your_own_until_told_otherwise():
	assert_true(_ship.own)
	assert_gt(_layers().get(ExteriorBuilder.OWN_HULL_LAYER, 0), 0, "its skin is on the own layer")
	assert_true(_ship.interior.visible)

func test_another_ships_hull_is_on_the_worlds_layer():
	var own_pieces: int = _layers()[ExteriorBuilder.OWN_HULL_LAYER]
	var on_one: int = _layers().get(1, 0)
	_ship.set_own(false)
	var now := _layers()
	assert_eq(now.get(ExteriorBuilder.OWN_HULL_LAYER, 0), 0, "nothing left only on the own layer")
	assert_eq(now.get(1, 0), on_one + own_pieces, "every own piece moved to layer 1")
	assert_false(_ship.interior.visible, "its interior hides")

func test_and_back_again():
	var before := _layers()
	_ship.set_own(false)
	_ship.set_own(true)
	assert_eq(_layers(), before)
	assert_true(_ship.interior.visible)

func test_pieces_on_both_layers_stay_on_both():
	var both: int = _layers().get(1 | ExteriorBuilder.OWN_HULL_LAYER, 0)
	_ship.set_own(false)
	assert_eq(_layers().get(1 | ExteriorBuilder.OWN_HULL_LAYER, 0), both)

func test_a_rebuild_keeps_it():
	_ship.set_own(false)
	_ship.set_grid(_ship.grid, false)
	assert_eq(_layers().get(ExteriorBuilder.OWN_HULL_LAYER, 0), 0, "a rebuilt skin comes out on layer 1 too")
	assert_false(_ship.interior.visible)
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `./who-knows/run_tests.ps1 -gselect=test_ship_own.gd`
Expected: FAIL (`own` and `set_own` do not exist).

- [ ] **Step 3: Implement**

In `who-knows/src/ship/ship.gd`, add after `const CANOPY_SHADER ...`:

```gdscript
## Marks a hull piece made for the own layer alone, so set_own can move it
## back.
const OWN_ONLY := &"own_only"
```

After `var warp: WarpDrive` add:

```gdscript
## True for the ship you are aboard (many ships spec §4.2): the hull's own
## pieces are drawn on ExteriorBuilder.OWN_HULL_LAYER, which your canopy and
## windows leave out, and the interior shows. Any other ship draws them on
## layer 1, so you see it through your windows, and hides its interior, which
## nobody can see from outside. A ship is your own until told otherwise.
var own := true
```

After `interior_slot_origin()` add:

```gdscript
func set_own(on: bool) -> void:
	own = on
	_apply_own()

## Every piece the builders made for the own layer alone goes on the layer
## `own` says; pieces on both layers stay on both. After every rebuild too: the
## builders always make the own layer.
func _apply_own() -> void:
	interior.visible = own
	for node in exterior.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g.layers == ExteriorBuilder.OWN_HULL_LAYER:
			g.set_meta(OWN_ONLY, true)
		if g.has_meta(OWN_ONLY):
			g.layers = ExteriorBuilder.OWN_HULL_LAYER if own else 1
```

At the very end of `_rebuild_everything` (after `_bind_crew()`):

```gdscript
	_apply_own()
```

- [ ] **Step 4: Run the covering tests**

```powershell
foreach ($t in "test_ship_own","test_hud_scene_wiring","test_hull_windows","test_ship_lights") { ./who-knows/run_tests.ps1 -gselect="$t.gd"; if ($LASTEXITCODE) { break } }
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
& $godot --headless --path who-knows --import
git add who-knows/src/ship/ship.gd who-knows/test/unit/test_ship_own.gd who-knows/test/unit/test_ship_own.gd.uid
git commit -m "feat: many ships -- only the ship you are aboard draws its hull on the own layer

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The fleet, and a second ship in the world

`Fleet` takes in the starter and spawns more; `_wire_ship` gives every ship what the starter used to get inline. `aboard` is introduced but stays the starter until Task 4. Each ship places its own seat.

**Files:**
- Create: `who-knows/src/ship/fleet.gd`, `who-knows/test/unit/test_fleet.gd`
- Modify: `who-knows/src/ship/ship.gd` (`helm_cell`, `_place_seat`)
- Modify: `who-knows/scenes/flight_test.gd` (`_ship` → `_starter`/`aboard`; `_make_fleet`; `_wire_ship`; `_deck_spot`; `_fleet_busy`; `warp_busy_for`; `_on_course_arrived`; `_on_blocks_lost(coords, ship)`)
- Modify: `who-knows/test/unit/test_floating_origin_scene.gd`

**Interfaces:**
- Consumes: `Ship.pilot`, `Ship.seat`, `Ship.chase_camera`, `Ship.canopy_camera`, `Ship.canopy_overlay`, `PilotControls.bind_director`, `PilotSeat.director` (Task 1); `Ship.set_own` (Task 2).
- Produces:
  - `class_name Fleet extends Node`: signals `joined(ship: Ship)`, `left(ship: Ship)`; `const SHIP_SCENE`, `STARTER := &"Ship"`, `MAX_SHIPS := 16`; `var home: Node`, `outside: Node3D`, `universe: Universe`, `aboard: Callable` (returns a `Ship`), `max_ships := MAX_SHIPS`, `next_number := 2`; `ships() -> Array[Ship]`, `awake() -> Array[Ship]` (all of them until Task 6), `named(ship_name: StringName) -> Ship`, `adopt(ship: Ship) -> void`, `spawn(grid: ShipGrid, place: Transform3D, stock := true, ship_name := "", launch: ShipBlueprint = null) -> Ship`, `remove(ship: Ship) -> bool`, `nearest(point: Vector3, except: Ship = null) -> Ship`.
  - `Ship.helm_cell() -> Variant` (a `Vector3i`, or null).
  - flight scene: `var fleet: Fleet`, `var aboard: Ship`, `_wire_ship(ship: Ship)`, `_deck_spot(ship: Ship) -> Transform3D` (interior-local), `_fleet_busy() -> String`, `warp_busy_for(ship: Ship) -> StringName`.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_fleet.gd`:

```gdscript
extends GutTest

## The fleet (many ships spec §5): every ship in the world, in the real flight
## scene, with a second starter spawned beside the first.

const OFF := Vector3(300, 0, 0)

var _root: Node
var _fleet: Fleet
var _starter: Ship
var _director: CameraDirector

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_fleet = _root.fleet
	_starter = _root.get_node("Ship")
	_director = _root.get_node("CameraDirector")

func _spawn(off := OFF) -> Ship:
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + off)
	return _fleet.spawn(_root._starter_grid(), place)

func test_the_starter_is_the_first_ship():
	assert_eq(_fleet.ships().size(), 1)
	assert_same(_fleet.ships()[0], _starter)
	assert_eq(_starter.interior_slot, 0)
	assert_same(_root.aboard, _starter)

func test_a_spawned_ship_is_whole_and_where_it_was_put():
	var ship := _spawn()
	assert_not_null(ship)
	assert_eq(String(ship.name), "Ship2")
	assert_eq(ship.interior_slot, 1)
	assert_eq(ship.grid.coords().size(), _starter.grid.coords().size(), "built from the grid")
	assert_almost_eq(ship.exterior.global_position, _starter.exterior.global_position + OFF, Vector3.ONE * 0.01)
	assert_eq(ship.exterior.linear_velocity, Vector3.ZERO, "at rest")
	assert_ne(ship.interior.global_position, _starter.interior.global_position, "an interior of its own")
	assert_eq(ship.outside, _root.get_node("Outside"))
	assert_false(ship.own, "not yours until you board it")
	assert_true(ship.exterior.is_in_group(Universe.EXTERIOR_SPACE))

func test_a_spawned_ship_is_wired_like_the_starter():
	var ship := _spawn()
	assert_same(ship.seat.director, _director)
	assert_same(ship.pilot.director, _director)
	assert_same(ship.pilot.lights, ship.lights)
	assert_not_null(ship.flight_computer.whereabouts, "its speed limit knows where it is")
	assert_not_null(ship.warp.system, "its warp is bound")
	assert_eq(ship.chase_camera.far, BodyProxy.VIEW_FAR)
	assert_true(_root.npc_debug.directors.has(ship.npc_director), "its crew shows on F4")
	assert_same(ship.npc_director.ledger, _root.npc_ledger)

func test_its_seat_is_where_its_chair_is():
	var ship := _spawn()
	assert_eq(ship.seat.transform, InteriorDressing.fixture_frame(ship.interior_builder.layout(), ship.helm_cell()))

func test_names_never_repeat_and_slots_are_reused():
	var a := _spawn()
	var b := _spawn(Vector3(-300, 0, 0))
	assert_eq([String(a.name), String(b.name)], ["Ship2", "Ship3"])
	assert_eq([a.interior_slot, b.interior_slot], [1, 2])
	assert_true(_fleet.remove(a))
	await wait_process_frames(1)
	var c := _spawn(Vector3(0, 300, 0))
	assert_eq(String(c.name), "Ship4", "a name is never used twice")
	assert_eq(c.interior_slot, 1, "a slot is")

func test_the_starter_and_the_ship_aboard_stay():
	assert_false(_fleet.remove(_starter), "the starter stays")
	var ship := _spawn()
	_root.aboard = ship
	assert_false(_fleet.remove(ship), "the ship you are aboard stays")
	_root.aboard = _starter

func test_no_more_than_the_cap():
	_fleet.max_ships = 2
	assert_not_null(_spawn())
	assert_null(_spawn(Vector3(-300, 0, 0)), "past the cap, none")
	assert_eq(Fleet.MAX_SHIPS, 16)

func test_nearest():
	var a := _spawn()
	var b := _spawn(Vector3(0, 0, 900))
	assert_same(_fleet.nearest(_starter.exterior.global_position, _starter), a)
	assert_same(_fleet.nearest(b.exterior.global_position, b), _starter)

## Review focus: a shift moves every hull, and no interior.
func test_a_shift_moves_both_hulls_and_neither_interior():
	var ship := _spawn()
	var gap := ship.exterior.global_position - _starter.exterior.global_position
	var interiors := [_starter.interior.global_position, ship.interior.global_position]
	_starter.exterior.global_position += Vector3(2500, 0, 0)
	ship.exterior.global_position += Vector3(2500, 0, 0)
	assert_true((_root.get_node("Universe") as Universe).check())
	assert_almost_eq(ship.exterior.global_position - _starter.exterior.global_position, gap, Vector3.ONE * 0.001)
	assert_eq([_starter.interior.global_position, ship.interior.global_position], interiors)

## Only the ship whose seat you take answers the stick (§3.2).
func test_sitting_in_the_starter_seats_only_its_controls():
	var ship := _spawn()
	_director.sit(_starter.seat)
	assert_true(_starter.pilot.seated)
	assert_false(ship.pilot.seated, "the other ship's controls ignore you")

## You are shoved only by the ship you stand in.
func test_another_ships_burn_never_shoves_you():
	var ship := _spawn()
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	_starter.motion.set_physics_process(false)
	avatar.external_accel = Vector3.ZERO
	ship.exterior.linear_velocity = Vector3(0, 0, -50)
	await wait_physics_frames(3)
	assert_eq(avatar.external_accel, Vector3.ZERO)

## Review focus: a block lost on another ship leaves you where you are.
func test_a_block_lost_on_another_ship_leaves_you_aboard():
	var ship := _spawn()
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	ship.blocks_lost.emit([Vector3i(0, 0, 0)] as Array[Vector3i])
	assert_eq(avatar.mode, Avatar.Mode.PLATING)
	assert_same(avatar.get_parent(), _starter.interior)

## Saving waits on any ship (§6.4).
func test_the_save_waits_on_every_ship():
	var ship := _spawn()
	assert_eq(_root._fleet_busy(), "")
	ship.since_struck = 0.0
	assert_eq(_root._fleet_busy(), "hull struck")
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `./who-knows/run_tests.ps1 -gselect=test_fleet.gd`
Expected: FAIL (`fleet` is not a property of the flight scene).

- [ ] **Step 3: Create `who-knows/src/ship/fleet.gd`**

```gdscript
class_name Fleet
extends Node

## Every ship in the world (docs/superpowers/specs/
## 2026-10-02-many-ships-design.md §5.1): the one place that knows how many
## there are. It takes in the starter, spawns the rest from ship.tscn, gives
## each an interior slot and a name of its own, and lets them go.

signal joined(ship: Ship)
signal left(ship: Ship)

const SHIP_SCENE: PackedScene = preload("res://scenes/ship.tscn")
## The starter's name. The save's ship of that name is always built into the
## scene's own /Ship, and it is never removed (§6.2).
const STARTER := &"Ship"
## Interiors stand Ship.SLOT_SPACING apart on x: slot 15 is 30 km out, where a
## float still holds about 2 mm.
const MAX_SHIPS := 16

## Where spawned ships go in the tree (the flight scene), and their outside.
var home: Node
var outside: Node3D
var universe: Universe
## The ship you are aboard (a Callable returning a Ship): never removed.
var aboard: Callable
var max_ships := MAX_SHIPS
## The number the next spawned ship's name takes (Ship2, Ship3 ...). It only
## goes up, so a name is never used twice in one game: a droid's ledger record
## is named for its ship (§6.2).
var next_number := 2

var _ships: Array[Ship] = []

func ships() -> Array[Ship]:
	return _ships.duplicate()

## The ships that are awake: every one, until ships sleep.
func awake() -> Array[Ship]:
	return _ships.duplicate()

func named(ship_name: StringName) -> Ship:
	for ship in _ships:
		if ship.name == ship_name:
			return ship
	return null

## Takes in a ship already in the tree: the starter the scene was authored with.
func adopt(ship: Ship) -> void:
	if _ships.has(ship):
		return
	_ships.append(ship)
	joined.emit(ship)

## A new ship built from `grid`, its hull at `place`, at rest; null past the
## cap. `stock` false leaves its shelves empty (a loaded game brings its own
## items); `ship_name` is its saved name and `launch` the layout it launched
## with, from a save. It is not your own until you board it.
func spawn(grid: ShipGrid, place: Transform3D, stock := true, ship_name := "",
		launch: ShipBlueprint = null) -> Ship:
	if _ships.size() >= max_ships:
		push_warning("Fleet: already %d ships, the most there can be" % max_ships)
		return null
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.name = ship_name if ship_name != "" else _next_name()
	ship.interior_slot = _free_slot()
	ship.outside_path = NodePath("../%s" % home.get_path_to(outside))
	ship.launch_blueprint = launch
	home.add_child(ship)
	ship.set_grid(grid, stock)
	ship.exterior.global_transform = place
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	ship.set_own(false)
	_ships.append(ship)
	joined.emit(ship)
	return ship

## Lets `ship` go, freeing it and its slot. Refuses the starter and the ship
## you are aboard. True if it went.
func remove(ship: Ship) -> bool:
	if ship == null or not _ships.has(ship) or ship.name == STARTER:
		return false
	if aboard.is_valid() and aboard.call() == ship:
		return false
	_ships.erase(ship)
	left.emit(ship)
	ship.get_parent().remove_child(ship)
	ship.queue_free()
	return true

## The awake ship whose hull is nearest `point`, other than `except`; null if
## there is none.
func nearest(point: Vector3, except: Ship = null) -> Ship:
	var best: Ship = null
	var best_d := INF
	for ship in awake():
		if ship == except:
			continue
		var d := point.distance_to(ship.exterior.global_position)
		if d < best_d:
			best = ship
			best_d = d
	return best

func _next_name() -> String:
	var n := "Ship%d" % next_number
	next_number += 1
	while named(n) != null:
		n = "Ship%d" % next_number
		next_number += 1
	return n

## The lowest interior slot no ship holds.
func _free_slot() -> int:
	var used := {}
	for ship in _ships:
		used[ship.interior_slot] = true
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot
```

- [ ] **Step 4: `ship.gd`: each ship places its own seat**

Add after `launch_block`:

```gdscript
## The helm's cell, or null with no pilot seat.
func helm_cell() -> Variant:
	for coord: Vector3i in grid.coords():
		if grid.get_block(coord).block_id == InteriorLayout.HELM_ID:
			return coord
	return null

## The helm's seat where the dressing drew the chair (cockpit pod spec §7): its
## collider and eye from the same fixture frame, after every rebuild, so a
## spawned ship's seat stands where the starter's does.
func _place_seat() -> void:
	var helm: Variant = helm_cell()
	if helm != null and seat != null:
		seat.transform = InteriorDressing.fixture_frame(interior_builder.layout(), helm)
```

In `_rebuild_everything`, right after `interior_builder.rebuild()`, add `_place_seat()`.

- [ ] **Step 5: `flight_test.gd`: the fleet, `aboard`, and `_wire_ship`**

Make these changes in `who-knows/scenes/flight_test.gd`:

1. Rename `@onready var _ship: Ship = $Ship` to `@onready var _starter: Ship = $Ship`. Delete `@onready var _pilot: PilotControls = $Ship/PilotControls`. Add with the other members:

```gdscript
## Every ship in the world (many ships spec §5), and the one you are in, or
## the one your suit belongs to on a spacewalk (§3.4).
var fleet: Fleet
var aboard: Ship
```

2. In `_ready()`, replace the Task 1 lines (`_ship.seat.director = ...`, `_ship.pilot.bind_director(...)` and their comment) with `_make_fleet()`. Rename every remaining `_ship` in `_ready()` to `_starter`. At the end of `_ready()`, after `_wire_saving()`, add:

```gdscript
	for ship in fleet.ships():
		_wire_ship(ship)
	fleet.joined.connect(_wire_ship)
	fleet.left.connect(_on_ship_left)
```

3. Add after `_ready()`:

```gdscript
## Every ship in the world (many ships spec §5): the starter first, aboard.
func _make_fleet() -> void:
	fleet = Fleet.new()
	fleet.name = "Fleet"
	fleet.home = self
	fleet.outside = $Outside
	fleet.universe = _universe
	fleet.aboard = func() -> Ship: return aboard
	add_child(fleet)
	fleet.adopt(_starter)
	aboard = _starter

## Everything one ship needs from the game, once (many ships spec §5.2): every
## ship at the end of _ready, and each the fleet takes in after.
func _wire_ship(ship: Ship) -> void:
	# The ship's scene cannot reach the game's director by path (§3.2).
	ship.seat.director = _director
	ship.pilot.bind_director(_director)
	ship.pilot.lights = ship.lights
	# Godot's cameras stop drawing at 4 km; a world's horizon is about 120 km
	# off (the world scale spec §5.2).
	for cam: Camera3D in [ship.chase_camera, ship.canopy_camera]:
		cam.far = BodyProxy.VIEW_FAR
	# Hurt (health and damage spec §7.4, §8.1): a hole where you stand puts you
	# outside; a shed plate is a stray.
	ship.blocks_lost.connect(_on_blocks_lost.bind(ship))
	ship.plate_shed.connect(func(item: Item) -> void: strays.adopt(item))
	# Its crew answers to the game's ledger, and shows on F4. The crew woke
	# with the ship, before it had the ledger.
	ship.npc_director.ledger = npc_ledger
	for npc: Npc in ship.npc_director.live_npcs():
		npc.health.current = npc_ledger.health_of(npc.record.id, npc.health.max)
	npc_debug.directors.append(ship.npc_director)
	# Its sensors (NPC foundation spec §22; the system skeleton spec §8, §10):
	# signs of life, big rocks to 30 km, the star, planets and moons.
	ship.sensors.universe = _universe
	ship.sensors.add_source(LifeContacts.new(_stream, exterior_npcs, _universe))
	ship.sensors.add_source(RockContacts.new(_stream.seed, _stream.recipe.start, _stream.shapes))
	ship.sensors.add_source(BodyContacts.new(system))
	ship.sensors.system = system
	ship.sensors.whereabouts = star_system.whereabouts
	ship.sensors.course_arrived.connect(_on_course_arrived.bind(ship))
	# The speed limit climbs with altitude in a world's well (the world scale
	# spec §6).
	ship.flight_computer.whereabouts = star_system.whereabouts
	# Its warp (the warp spec §5): J at its helm engages it.
	ship.warp.bind(system, _universe, star_system.whereabouts, ship.sensors, _stream.recipe,
		warp_busy_for.bind(ship))
	ship.pilot.warp_pressed.connect(ship.warp.engage)
	ship.warp.travel_started.connect(_on_warp_started)
	ship.warp.travel_ended.connect(_on_warp_ended)

func _on_ship_left(ship: Ship) -> void:
	npc_debug.directors.erase(ship.npc_director)
```

4. Take the per-ship lines out of the old wiring functions, since `_wire_ship` now does them:
   - `_wire_hurt`: delete `_ship.blocks_lost.connect(_on_blocks_lost)`.
   - `_wire_strays`: delete the `plate_shed` comment and connect line.
   - `_wire_npcs`: delete `_ship.npc_director.ledger = npc_ledger`, the crew-health loop and its comment, and `npc_debug.directors.append(_ship.npc_director)`. Change `exterior_npcs.catalog = _ship.npc_director.catalog` to use `_starter`, and the `cameras` line to `[aboard.chase_camera, aboard.canopy_camera, _avatar.camera]`.
   - `_wire_sensors`: delete every `_ship.sensors...` and `_ship.flight_computer.whereabouts` line; the markers use `aboard.sensors`.
   - `_wire_course_chime`: keep making `course_chime`; delete the `connect` (now `_on_course_arrived`).
   - `_wire_warp`: delete `warp.bind(...)`, `_pilot.warp_pressed.connect(...)` and the two `travel_*` connects; `warp_panel.drive = aboard.warp`; `m.warp = aboard.warp`.
   - `_wire_hud`: delete `_pilot.lights = _ship.lights`.
   - `_wire_universe`: the far-plane loop becomes `_avatar.camera.far = BodyProxy.VIEW_FAR`.
   - `_mount_per_view`: `$Ship/Canopy/CanopyOverlay` → `aboard.canopy_overlay`, `$Ship/Canopy/CanopyCam` → `aboard.canopy_camera`, `$Ship/Exterior/ChaseCamera` → `aboard.chase_camera`.

5. Add these, and replace `warp_busy()` and `_on_blocks_lost`:

```gdscript
## A soft chime when the course of the ship you are aboard clears by arriving
## (bridge computer spec §9): through the suit on a spacewalk, else the ship.
func _on_course_arrived(_id: StringName, ship: Ship) -> void:
	if ship != aboard:
		return
	var s := Synth.sound(&"course_arrived")
	if s == null:
		return
	course_chime.bus = AudioBuses.SUIT if _avatar.mode == Avatar.Mode.SUIT else AudioBuses.SHIP
	course_chime.stream = s
	course_chime.play()

## Why the warp of the ship you are aboard must wait for the crew.
func warp_busy() -> StringName:
	return warp_busy_for(aboard)

## Why `ship`'s warp must wait for the crew: &"crew" on a spacewalk,
## &"airlock" while one of its airlocks cycles or stands open to space, else
## &"".
func warp_busy_for(ship: Ship) -> StringName:
	if _avatar.mode == Avatar.Mode.SUIT:
		return &"crew"
	for airlock: Airlock in ship.airlocks.values():
		if airlock.busy() != "" or airlock.cycle.open_side() == AirlockCycle.Door.OUTER:
			return &"airlock"
	return &""

## Why a save must wait on any ship (many ships spec §6.4), or "".
func _fleet_busy() -> String:
	for ship in fleet.ships():
		var why := ship.busy()
		if why != "":
			return why
	return ""

## A hole where you stand puts you outside, moving as you were (health and
## damage spec §7.4): only a hole in the ship you stand in.
func _on_blocks_lost(_coords: Array[Vector3i], ship: Ship) -> void:
	if _avatar.mode != Avatar.Mode.PLATING or _avatar.get_parent() != ship.interior:
		return
	var local := ship.interior.to_local(_avatar.global_position + _avatar.global_basis.y * 0.1)
	var cell := ShipCells.interior_cell_at(local)
	if ship.grid.has_block(cell):
		return
	var world := Threshold.to_world(ship.interior.global_transform, ship.exterior.global_transform,
		_avatar.global_transform, InteriorBuilder.storey_offset(cell.y))
	var v := Threshold.carry_velocity_out(ship.exterior.linear_velocity, ship.exterior.global_basis,
		_avatar.velocity)
	_avatar.enter_suit(ship.outside, world, v, ship.exterior)
	for airlock: Airlock in ship.airlocks.values():
		_avatar.beacon_source = airlock.beacon
		_avatar.home_source = airlock.home
		break
```

6. In `_wire_saving`, `save_gate.add_source(_ship.busy)` becomes `save_gate.add_source(_fleet_busy)`.

7. Replace `_place_avatar_on_deck()` with the two functions below (the seat is now placed by `Ship._place_seat`):

```gdscript
## Stands you on the starter's deck to begin with (see _deck_spot).
func _place_avatar_on_deck() -> void:
	if _starter.helm_cell() == null:
		return
	_avatar.position = _deck_spot(_starter).origin

## Where you stand on `ship`'s deck to start, in its interior's frame: the first
## walkable cell aft of its helm that holds no fixture, or the helm's own cell
## (quantum energy spec §5.3, §6.1). A MOUNT block, like the quantum core,
## still fills its cell's floor though the cell is walkable.
func _deck_spot(ship: Ship) -> Transform3D:
	var helm: Variant = ship.helm_cell()
	if helm == null:
		return Transform3D.IDENTITY
	var cell: Vector3i = helm
	var probe: Vector3i = cell + Vector3i(0, 0, 1)
	while ship.grid.has_block(probe):
		var def := ship.catalog.get_def(ship.grid.get_block(probe).block_id)
		if def != null and def.is_walkable() and def.occupancy != BlockDefinition.Occupancy.MOUNT:
			cell = probe
			break
		probe += Vector3i(0, 0, 1)
	var centre := ShipGrid.cell_center(cell)
	return Transform3D(Basis.IDENTITY, Vector3(centre.x, InteriorBuilder.floor_y(cell) + 0.05, centre.z))
```

8. Every other `_ship` use becomes `aboard` (runtime: rescue and its cost, hands, focus, hop, `_physics_process`'s streak, `capture`, `_capture_npcs`, `_capture_you`, `_restore_*`, `_can_stand`) or `_starter` (setup only: `_stern`, salvage and strays' `item_catalog`). In `_capture_npcs`, gather every ship's director:

```gdscript
	var directors: Array = fleet.ships().map(func(s: Ship) -> NpcDirector: return s.npc_director)
	directors.append(exterior_npcs)
	for director: NpcDirector in directors:
```

Check nothing is left over: `grep -n "_ship\b\|\$Ship/\|_pilot\b" who-knows/scenes/flight_test.gd` should print only the `$Ship/Interior/Avatar...` `@onready` lines and `$Ship` in `_starter`'s.

- [ ] **Step 6: The floating-origin test knows every interior**

In `who-knows/test/unit/test_floating_origin_scene.gd`, replace `_uncovered()` and add a test:

```gdscript
func _uncovered() -> Array:
	var out := []
	for n in _root.find_children("*", "Node3D", true, false):
		if not (n is PhysicsBody3D or n is GeometryInstance3D):
			continue
		if _in_an_interior(n):
			continue
		if not _covered(n):
			out.append(str(_root.get_path_to(n)))
	return out

## Inside any ship: interiors never move (many ships spec §5.1).
func _in_an_interior(n: Node) -> bool:
	for ship: Ship in _root.fleet.ships():
		if ship.interior.is_ancestor_of(n):
			return true
	return false

func test_with_a_second_ship_everything_outside_is_covered():
	var place := Transform3D(Basis.IDENTITY, _ship.exterior.global_position + Vector3(300, 0, 0))
	_root.fleet.spawn(_root._starter_grid(), place)
	assert_eq(_uncovered(), [])
```

- [ ] **Step 7: Import, then run the covering tests**

```powershell
& $godot --headless --path who-knows --import
foreach ($t in "test_fleet","test_floating_origin_scene","test_ship_scene","test_hud_scene_wiring","test_pilot_seat","test_save_scene","test_warp_scene","test_droid_scene","test_system_scene","test_bridge_computer_scene","test_crash_feel") { ./who-knows/run_tests.ps1 -gselect="$t.gd"; if ($LASTEXITCODE) { break } }
```

Expected: all PASS, exit code 0.

- [ ] **Step 8: Commit**

```bash
git add who-knows/src/ship/fleet.gd who-knows/src/ship/fleet.gd.uid who-knows/src/ship/ship.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_fleet.gd who-knows/test/unit/test_fleet.gd.uid who-knows/test/unit/test_floating_origin_scene.gd
git commit -m "feat: many ships -- the fleet: a second ship spawns whole, wired like the starter

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Boarding, and F8 to another helm

**Files:**
- Modify: `who-knows/scenes/flight_test.gd` (`board`, `board_nearest`, `board_at_helm`, `_board_refusal`, `_rebind_markers`, `_cockpit_markers`, F8, `_on_piloting_changed`; `board(aboard, true)` at the end of `_ready`)
- Modify: `who-knows/src/camera/camera_director.gd` (`bind`, `stand_now`)
- Modify: `who-knows/src/avatar/avatar.gd` (`move_aboard`)
- Modify: `who-knows/src/ui/velocity_marker.gd`, `who-knows/src/ui/heading_marker.gd` (`set_camera`), `who-knows/src/ui/course_marker.gd` (`bind` lets go of the old sensors)
- Create: `who-knows/test/unit/test_boarding_scene.gd`

**Interfaces:**
- Consumes: `Fleet.spawn`, `Fleet.nearest`, `Fleet.ships`, `aboard`, `_deck_spot`, `_wire_ship` (Task 3); `Ship.set_own` (Task 2); `CameraDirector.seat_ship` (Task 1).
- Produces:
  - flight scene: `signal aboard_changed(ship: Ship)`, `board(ship: Ship, force := false) -> void`, `board_nearest() -> bool`, `board_at_helm(ship: Ship) -> void`.
  - `CameraDirector.bind(ship: Ship) -> void`, `CameraDirector.stand_now() -> void`.
  - `Avatar.move_aboard(interior: Node3D, pose: Transform3D) -> void`.
  - `VelocityMarker.set_camera(cam: Camera3D)`, `HeadingMarker.set_camera(cam: Camera3D)`.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_boarding_scene.gd`:

```gdscript
extends GutTest

## Boarding another ship and flying it (many ships spec §4), in the real
## flight scene, with a second starter spawned 300 m off.

var _root: Node
var _starter: Ship
var _second: Ship
var _avatar: Avatar
var _director: CameraDirector
var _hud: HudRoot

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_starter = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_director = _root.get_node("CameraDirector")
	_hud = _root.get_node("HudRoot")
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + Vector3(300, 0, 0))
	_second = _root.fleet.spawn(_root._starter_grid(), place)
	await wait_process_frames(2)
	await wait_physics_frames(2)

func after_each():
	for action in [&"move_forward", &"move_back"]:
		Input.action_release(action)

func test_you_start_aboard_the_starter():
	assert_same(_root.aboard, _starter)
	assert_true(_starter.own)
	assert_false(_second.own)

func test_f8_seats_you_at_the_other_ships_helm():
	assert_true(_root.board_nearest())
	assert_same(_root.aboard, _second)
	assert_true(_director.is_seated)
	assert_same(_director.seat_ship(), _second)
	assert_same(_avatar.get_parent(), _second.interior)
	assert_true(_second.pilot.seated)
	assert_false(_starter.pilot.seated)
	assert_same(_hud._source, _second.pilot, "the HUD reads the ship you fly")
	assert_same((_root.get_node("Universe") as Universe).focus, _second.exterior)
	assert_same(_root.warp_panel.drive, _second.warp)
	assert_same(_avatar.grasp.world_root, _second.items)
	assert_eq(_second.sensors.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(_starter.sensors.process_mode, Node.PROCESS_MODE_DISABLED, "the other's scans rest")

func test_the_ship_you_left_shows_through_your_windows():
	_root.board_nearest()
	assert_true(_second.own)
	assert_false(_starter.own)
	assert_false(_starter.interior.visible)
	assert_true(_second.interior.visible)
	for node in _starter.exterior.find_children("*", "GeometryInstance3D", true, false):
		assert_ne((node as GeometryInstance3D).layers, ExteriorBuilder.OWN_HULL_LAYER, "%s on the world's layer" % node.name)
	assert_ne(_second.canopy_camera.cull_mask & 1, 0, "the canopy shows layer 1")

func test_the_cockpit_markers_follow_you():
	_root.board_nearest()
	assert_true(_hud._registered.has(_second.canopy_overlay.get_node("CockpitMarker")))
	assert_false(_hud._registered.has(_starter.canopy_overlay.get_node("CockpitMarker")))
	for m: WorldMarker in _root.contact_markers:
		if String(m.name).ends_with("Cockpit"):
			assert_same(m.get_parent(), _second.canopy_overlay, "%s moved into its canopy" % m.name)
		assert_same((m as ContactMarker).sensors, _second.sensors)

func test_flying_it_moves_it_and_not_the_starter():
	_root.board_nearest()
	var starter_at := _starter.exterior.global_position
	Input.action_press(&"move_forward")
	await wait_physics_frames(60)
	Input.action_release(&"move_forward")
	var forward := -_second.exterior.global_basis.z
	assert_gt(_second.exterior.linear_velocity.dot(forward), 5.0, "it accelerates")
	assert_almost_eq(_starter.exterior.global_position, starter_at, Vector3.ONE * 0.5, "the starter stays")

func test_stand_up_and_walk_it():
	_root.board_nearest()
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)
	var from := _avatar.global_position
	Input.action_press(&"move_back")
	await wait_physics_frames(60)
	Input.action_release(&"move_back")
	assert_gt(from.distance_to(_avatar.global_position), 1.0, "walked off")
	assert_same(_avatar.get_parent(), _second.interior)

func test_f8_again_takes_you_back():
	_root.board_nearest()
	assert_true(_root.board_nearest())
	assert_same(_root.aboard, _starter)
	assert_same(_director.seat_ship(), _starter)
	assert_true(_starter.own)
	assert_false(_second.own)

func test_refused_on_a_spacewalk():
	var at := _starter.exterior.global_position + Vector3(0, 0, 20)
	_avatar.enter_suit(_root.get_node("Outside"), Transform3D(Basis.IDENTITY, at), Vector3.ZERO, _starter.exterior)
	assert_false(_root.board_nearest())
	assert_same(_root.aboard, _starter)

func test_refused_with_no_other_ship():
	assert_true(_root.fleet.remove(_second))
	assert_false(_root.board_nearest())

## Review focus: what you hold comes with you, and lands in the ship you are in.
func test_what_you_hold_comes_with_you():
	var mugs := _starter.items.get_children().filter(func(n): return n is Item and n.definition.id == &"mug")
	var mug: Item = mugs[0]
	assert_true(_avatar.grasp.take(mug))
	_root.board_nearest()
	assert_same(_avatar.grasp.item, mug, "still in your hand")
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)
	_avatar.grasp.drop()
	assert_same(mug.get_parent(), _second.items, "dropped, it lands in the ship you are in")
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `./who-knows/run_tests.ps1 -gselect=test_boarding_scene.gd`
Expected: FAIL (`board_nearest` does not exist).

- [ ] **Step 3: `camera_director.gd`: `bind` and `stand_now`**

Add after `seat_ship()`:

```gdscript
## Points the views at `ship` (many ships spec §4.1): the flight computer you
## let go of when you stand, and the chase camera C switches to.
func bind(ship: Ship) -> void:
	_flight = ship.flight_computer
	if _chase_cam == ship.chase_camera:
		return
	var chasing := view == View.CHASE
	_chase_cam.current = false
	_chase_cam = ship.chase_camera
	if chasing:
		_chase_cam.current = true

## Stands you up at once, with no camera move (many ships spec §4.3): F8's hop
## to another helm. The camera goes straight back to your head.
func stand_now() -> void:
	if not is_seated or _tween != null:
		return
	is_seated = false
	piloting_changed.emit(false)
	_flight.clear_pilot_input()
	_avatar.place(_seat.stand_spot(_avatar))
	_interior_cam.reparent(_avatar.head, false)
	_interior_cam.transform = Transform3D.IDENTITY
	_avatar.set_control_enabled(true)
	view = View.FOOT_FIRST
	_apply_view()
```

- [ ] **Step 4: `avatar.gd`: `move_aboard`**

Add after `place()`:

```gdscript
## Moves you, standing aboard, into another ship's `interior` at `pose` (many
## ships spec §4.3): F8's hop to a helm. Not for a spacewalk: that is
## enter_plating's.
func move_aboard(interior: Node3D, pose: Transform3D) -> void:
	_move_to(interior)
	place(pose)
```

- [ ] **Step 5: The markers can be re-aimed**

In `who-knows/src/ui/velocity_marker.gd` and `who-knows/src/ui/heading_marker.gd`, add after `_ready()`:

```gdscript
## Aims it through `cam`: the chase camera of the ship you are aboard (many
## ships spec §4.1).
func set_camera(cam: Camera3D) -> void:
	_camera = cam
```

In `who-knows/src/ui/course_marker.gd`, replace `bind` with:

```gdscript
## Reads `p_sensors`, letting go of the ship it read before (many ships spec
## §4.1).
func bind(p_sensors: ShipSensors) -> void:
	if sensors != null and sensors.course_arrived.is_connected(_on_course_arrived):
		sensors.course_arrived.disconnect(_on_course_arrived)
	sensors = p_sensors
	sensors.course_arrived.connect(_on_course_arrived)

func _on_course_arrived(_id: StringName) -> void:
	_fading = FADE
```

- [ ] **Step 6: `flight_test.gd`: `board()` and F8**

1. Delete the `@onready` lines for `_cockpit_marker` and `_heading_cockpit`, and the two `_hud.register_element(...)` lines for them in `_wire_hud`: `board()` registers the cockpit markers of the ship you are aboard.

2. Add the signal under `extends Node3D`:

```gdscript
## The ship you are aboard changed (many ships spec §4.1).
signal aboard_changed(ship: Ship)
```

3. At the end of `_ready()`, after `fleet.left.connect(_on_ship_left)`, add:

```gdscript
	board(aboard, true)
```

4. Replace `_on_piloting_changed`:

```gdscript
## The pilot's controls of the ship whose seat you took report the flight
## computer's telemetry plus the stick and the pointer (flight controls spec
## §7).
func _on_piloting_changed(piloting: bool) -> void:
	var ship := _director.seat_ship()
	_hud.set_active_vehicle(ship.pilot if piloting and ship != null else null)
```

5. In `_unhandled_key_input`, add to the `match`:

```gdscript
		KEY_F8:
			board_nearest()
```

6. Add the boarding functions:

```gdscript
## Hands you to `ship` (many ships spec §4.1): its hull drawn as your own and
## its interior shown, the other's not; the views, the HUD's markers, the warp
## panel, your hands and the origin's focus all follow it, and only its
## sensors scan. Boarding the ship you are aboard does nothing unless `force`.
func board(ship: Ship, force := false) -> void:
	if ship == null or (ship == aboard and not force):
		return
	var old := aboard
	aboard = ship
	if old != null and old != ship and is_instance_valid(old):
		old.set_own(false)
		for m in _cockpit_markers(old):
			_hud.unregister_element(m)
	ship.set_own(true)
	for m in _cockpit_markers(ship):
		_hud.register_element(m)
	_director.bind(ship)
	($HudRoot/Screen/ChaseMarker as VelocityMarker).set_camera(ship.chase_camera)
	($HudRoot/Screen/HeadingChaseMarker as HeadingMarker).set_camera(ship.chase_camera)
	_rebind_markers(ship)
	if warp_panel != null:
		warp_panel.drive = ship.warp
	_avatar.grasp.world_root = ship.items
	if exterior_npcs != null:
		exterior_npcs.cameras = [ship.chase_camera, ship.canopy_camera, _avatar.camera]
	for s in fleet.ships():
		s.sensors.process_mode = Node.PROCESS_MODE_INHERIT if s == ship else Node.PROCESS_MODE_DISABLED
	_universe.set_focus(_avatar if _avatar.mode == Avatar.Mode.SUIT else ship.exterior)
	aboard_changed.emit(ship)

## The cockpit's own markers, in `ship`'s canopy view: the HUD feeds them while
## it is the ship you are aboard.
static func _cockpit_markers(ship: Ship) -> Array[HudElement]:
	var out: Array[HudElement] = []
	for marker_name in ["CockpitMarker", "HeadingCockpitMarker"]:
		var m := ship.canopy_overlay.get_node_or_null(marker_name) as HudElement
		if m != null:
			out.append(m)
	return out

## The contact, course and body markers onto `ship` (bridge computer spec §8):
## the cockpit's into its canopy view, the chase view's through its chase
## camera, all reading its sensors.
func _rebind_markers(ship: Ship) -> void:
	for group: Array in [contact_markers, course_markers, body_markers]:
		for m: WorldMarker in group:
			if String(m.name).ends_with("Cockpit"):
				if m.get_parent() != ship.canopy_overlay:
					m.reparent(ship.canopy_overlay, false)
				m.set_camera(ship.canopy_camera)
			elif String(m.name).ends_with("Chase"):
				m.set_camera(ship.chase_camera)
	for m in contact_markers:
		(m as ContactMarker).sensors = ship.sensors
	for m in course_markers:
		(m as CourseMarker).bind(ship.sensors)
		(m as CourseMarker).warp = ship.warp
	for m in body_markers:
		(m as BodyMarker).sensors = ship.sensors

## F8, debug (many ships spec §4.3): seats you at the helm of the nearest other
## awake ship. False, with a toast saying why, when it can't.
func board_nearest() -> bool:
	var why := _board_refusal()
	var target: Ship = null
	if why == "":
		target = fleet.nearest(aboard.exterior.global_position, aboard)
		if target == null:
			why = "NO OTHER SHIP NEAR"
	if why != "":
		if warp_panel != null:
			warp_panel.toast(why)
		return false
	board_at_helm(target)
	return true

## Why F8 must wait, or "": on a spacewalk, mid-sit, during a warp, or while an
## airlock of the ship you are aboard cycles.
func _board_refusal() -> String:
	if _avatar.mode == Avatar.Mode.SUIT:
		return "NOT ON A SPACEWALK"
	if _director.is_moving():
		return "SITTING DOWN"
	for ship in fleet.ships():
		if ship.warp.is_spinning():
			return "WARP ENGAGED"
	for airlock: Airlock in aboard.airlocks.values():
		if airlock.busy() != "":
			return "AIRLOCK CYCLING"
	return ""

## Seats you at `ship`'s helm at once (many ships spec §4.3): up out of your own
## chair, across to its deck, aboard it, and down into its seat.
func board_at_helm(ship: Ship) -> void:
	_director.stand_now()
	_avatar.move_aboard(ship.interior, ship.interior.global_transform * _deck_spot(ship))
	board(ship)
	_director.sit_now(ship.seat)
```

- [ ] **Step 7: Run the covering tests**

```powershell
foreach ($t in "test_boarding_scene","test_fleet","test_hud_scene_wiring","test_pilot_seat","test_pilot_controls","test_bridge_computer_scene","test_warp_scene","test_system_scene","test_avatar_modes") { ./who-knows/run_tests.ps1 -gselect="$t.gd"; if ($LASTEXITCODE) { break } }
```

Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
& $godot --headless --path who-knows --import
git add who-knows/scenes/flight_test.gd who-knows/src who-knows/test/unit/test_boarding_scene.gd who-knows/test/unit/test_boarding_scene.gd.uid
git commit -m "feat: many ships -- board(): you are handed to a ship; F8 seats you at the nearest other helm

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Any airlock lets you in; your suit belongs to the nearest ship

**Files:**
- Modify: `who-knows/src/ship/airlock/airlock.gd` (any suit), `who-knows/src/ship/ship.gd` (`airlock_crossed` relay)
- Create: `who-knows/src/ship/suit_tie.gd`, `who-knows/test/unit/test_suit_tie.gd`
- Modify: `who-knows/scenes/flight_test.gd` (`suit_tie`, `_tie_suit`, `_nearest_airlock`, `_on_airlock_crossed`)
- Modify: `who-knows/test/unit/test_boarding_scene.gd` (three tests added)

**Interfaces:**
- Consumes: `board()`, `aboard` (Task 4); `Fleet.awake()` (Task 3).
- Produces:
  - `Ship.airlock_crossed(avatar: Avatar, outward: bool)` signal.
  - `class_name SuitTie extends Node`: `signal tied(ship: Ship)`; `const SWITCH_MARGIN := 10.0`, `REACH := 500.0`, `EVERY := 0.25`; `var fleet: Fleet`, `avatar: Avatar`, `current: Callable` (returns a `Ship`); `check() -> void`; `static gap(ship: Ship, p: Vector3) -> float`; `static choose(current: int, gaps: Array[float]) -> int`.
  - flight scene: `var suit_tie: SuitTie`.

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_suit_tie.gd`:

```gdscript
extends GutTest

## Which ship your suit belongs to on a spacewalk (many ships spec §4.3): the
## nearest, once it is SWITCH_MARGIN nearer than yours and within REACH.

func test_the_nearer_ship_wins_past_the_margin():
	assert_eq(SuitTie.choose(0, [100.0, 80.0] as Array[float]), 1)

func test_within_the_margin_you_stay():
	assert_eq(SuitTie.choose(0, [100.0, 95.0] as Array[float]), 0)

func test_past_reach_nothing_changes():
	assert_eq(SuitTie.choose(0, [900.0, 600.0] as Array[float]), 0)

func test_with_none_the_nearest_in_reach():
	assert_eq(SuitTie.choose(-1, [700.0, 300.0] as Array[float]), 1)
	assert_eq(SuitTie.choose(-1, [700.0, 600.0] as Array[float]), -1)
	assert_eq(SuitTie.choose(-1, [] as Array[float]), -1)
```

Append to `who-knows/test/unit/test_boarding_scene.gd`:

```gdscript
## Steps out of the second ship onto a spacewalk at `at`, tied to it.
func _out_of_the_second(at: Vector3) -> void:
	_root.board_nearest()
	_director.stand_now()
	_avatar.enter_suit(_root.get_node("Outside"), Transform3D(Basis.IDENTITY, at), Vector3.ZERO, _second.exterior)

func test_floating_near_the_starter_ties_your_suit_to_it():
	_out_of_the_second(_starter.exterior.global_position + Vector3(0, 30, 0))
	_root.suit_tie.check()
	assert_same(_avatar.hull, _starter.exterior)
	assert_same(_root.aboard, _starter)
	var lock: Airlock = _starter.airlocks.values()[0]
	assert_eq(_avatar.beacon_source, Callable(lock, &"beacon"), "home is its airlock")
	assert_same((_root.get_node("Universe") as Universe).focus, _avatar, "the origin still follows you")

func test_halfway_between_your_suit_stays_with_the_ship_you_left():
	_out_of_the_second((_starter.exterior.global_position + _second.exterior.global_position) * 0.5)
	_root.suit_tie.check()
	assert_same(_avatar.hull, _second.exterior)
	assert_same(_root.aboard, _second)

func test_in_through_the_starters_airlock_you_are_aboard_it():
	_out_of_the_second(_second.exterior.global_position + Vector3(0, 30, 0))
	var lock: Airlock = _starter.airlocks.values()[0]
	lock.cycle.restore_idle(0.0, AirlockCycle.Door.OUTER)
	var hull := _starter.exterior
	var at := hull.global_transform * (lock.alcove.outer_frame * Vector3(0, 0.2, 0.3))
	_avatar.global_transform = Transform3D(hull.global_basis, at)
	lock._watch_threshold()
	assert_eq(_avatar.mode, Avatar.Mode.PLATING, "in through its outer hatch, though your suit was the other ship's")
	assert_same(_avatar.get_parent(), _starter.interior)
	assert_same(_root.aboard, _starter, "and aboard it")
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `./who-knows/run_tests.ps1 -gselect=test_suit_tie.gd`, then `-gselect=test_boarding_scene.gd`.
Expected: FAIL (`SuitTie` does not exist; `suit_tie` is not a property).

- [ ] **Step 3: Create `who-knows/src/ship/suit_tie.gd`**

```gdscript
class_name SuitTie
extends Node

## Which ship your suit belongs to on a spacewalk (docs/superpowers/specs/
## 2026-10-02-many-ships-design.md §4.3): the nearest, once it is
## SWITCH_MARGIN nearer than yours and within REACH, so floating between two
## ships never flicks the HUD back and forth. Your relative speed, the home
## marker and `aboard` follow it.

signal tied(ship: Ship)

const SWITCH_MARGIN := 10.0
const REACH := 500.0
const EVERY := 0.25

var fleet: Fleet
var avatar: Avatar
## The ship the suit belongs to now (a Callable returning a Ship).
var current: Callable

var _in := 0.0

func _physics_process(delta: float) -> void:
	_in -= delta
	if _in > 0.0:
		return
	_in = EVERY
	check()

## Ties the suit to a nearer ship if there is one, now.
func check() -> void:
	if avatar == null or fleet == null or avatar.mode != Avatar.Mode.SUIT:
		return
	var ships := fleet.awake()
	var gaps: Array[float] = []
	for ship in ships:
		gaps.append(gap(ship, avatar.global_position))
	var mine: Ship = current.call() if current.is_valid() else null
	var i := choose(ships.find(mine), gaps)
	if i >= 0 and ships[i] != mine:
		tied.emit(ships[i])

## How far `p` is from `ship`'s hull: from the middle of its bounds, less half
## their diagonal. Rough, and the same rough for every ship.
static func gap(ship: Ship, p: Vector3) -> float:
	var box := ship.exterior_builder.bounds()
	var centre := ship.exterior.global_transform * box.get_center()
	return maxf(p.distance_to(centre) - box.size.length() * 0.5, 0.0)

## Which of `gaps` the suit should belong to, given it belongs to `current` now
## (-1 for none): the nearest within REACH, if it beats yours by SWITCH_MARGIN.
static func choose(current: int, gaps: Array[float]) -> int:
	var nearest := -1
	for i in gaps.size():
		if nearest < 0 or gaps[i] < gaps[nearest]:
			nearest = i
	if nearest < 0 or nearest == current or gaps[nearest] > REACH:
		return current
	if current >= 0 and gaps[nearest] + SWITCH_MARGIN > gaps[current]:
		return current
	return nearest
```

- [ ] **Step 4: Any suit at any airlock; the ship hears who came in**

In `who-knows/src/ship/airlock/airlock.gd`:
- in `occupancy()`, `elif avatar.mode == Avatar.Mode.SUIT and is_instance_valid(alcove) and avatar.hull == _ship.exterior:` becomes `elif avatar.mode == Avatar.Mode.SUIT and is_instance_valid(alcove):`;
- in `_watch_threshold()`, `elif avatar.hull == hull:` becomes `elif avatar.mode == Avatar.Mode.SUIT:`.

Add to their doc comments: *"a suit from any ship (many ships spec §4.3)"*.

In `who-knows/src/ship/ship.gd`, add with the other signals:

```gdscript
## Someone crossed one of its airlocks' outer hatches (airlock spec §7):
## `outward` true out onto a spacewalk, false in, aboard (many ships spec §4.3).
signal airlock_crossed(avatar: Avatar, outward: bool)
```

In `_bind_airlocks`, right after `_airlocks_root.add_child(airlock)`:

```gdscript
			airlock.crossed.connect(airlock_crossed.emit)
```

- [ ] **Step 5: `flight_test.gd`: the tie, and boarding by airlock**

Add the member `var suit_tie: SuitTie`. In `_ready()`, after `_make_fleet()`:

```gdscript
	_make_suit_tie()
```

In `_wire_ship`, add:

```gdscript
	# In through its airlock, you are aboard it (§4.3).
	ship.airlock_crossed.connect(_on_airlock_crossed.bind(ship))
```

And add:

```gdscript
## On a spacewalk, your suit belongs to the nearest ship (many ships spec §4.3).
func _make_suit_tie() -> void:
	suit_tie = SuitTie.new()
	suit_tie.name = "SuitTie"
	suit_tie.fleet = fleet
	suit_tie.avatar = _avatar
	suit_tie.current = func() -> Ship: return aboard
	suit_tie.tied.connect(_tie_suit)
	add_child(suit_tie)

## Your suit is `ship`'s now: speed relative to its hull, home its nearest
## airlock, and aboard it.
func _tie_suit(ship: Ship) -> void:
	_avatar.hull = ship.exterior
	var lock := _nearest_airlock(ship, _avatar.global_position)
	if lock != null:
		_avatar.beacon_source = lock.beacon
		_avatar.home_source = lock.home
	board(ship)

## `ship`'s airlock with a hatch on the hull nearest `p`, or null.
static func _nearest_airlock(ship: Ship, p: Vector3) -> Airlock:
	var best: Airlock = null
	for lock: Airlock in ship.airlocks.values():
		if not is_instance_valid(lock.alcove):
			continue
		if best == null or lock.beacon().distance_to(p) < best.beacon().distance_to(p):
			best = lock
	return best

## In through any ship's airlock: you are aboard it.
func _on_airlock_crossed(_who: Avatar, outward: bool, ship: Ship) -> void:
	if not outward:
		board(ship)
```

- [ ] **Step 6: Run the covering tests**

```powershell
& $godot --headless --path who-knows --import
foreach ($t in "test_suit_tie","test_boarding_scene","test_airlock_node","test_avatar_modes","test_floating_origin_scene","test_airlock_marker") { ./who-knows/run_tests.ps1 -gselect="$t.gd"; if ($LASTEXITCODE) { break } }
```

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/ship/suit_tie.gd who-knows/src/ship/suit_tie.gd.uid who-knows/src/ship/airlock/airlock.gd who-knows/src/ship/ship.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_suit_tie.gd who-knows/test/unit/test_suit_tie.gd.uid who-knows/test/unit/test_boarding_scene.gd
git commit -m "feat: many ships -- any airlock lets a suit in; on a spacewalk your suit belongs to the nearest ship

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Far ships sleep

**Files:**
- Modify: `who-knows/src/ship/fleet.gd` (sleeping)
- Modify: `who-knows/scenes/flight_test.gd` (`_fleet_busy` skips sleepers)
- Modify: `who-knows/test/unit/test_fleet.gd`, `who-knows/test/unit/test_floating_origin_scene.gd`

**Interfaces:**
- Consumes: `Fleet` (Task 3), `board_nearest` (Task 4).
- Produces: `Fleet.SLEEP_AT := 20000.0`, `WAKE_AT := 18000.0`, `CHECK_EVERY := 1.0`, `ASLEEP := &"ships_asleep"`; `sleeping(ship: Ship) -> bool`, `place_of(ship: Ship) -> UniversePoint`, `check_sleep() -> void`, `sleep(ship: Ship) -> void`, `wake(ship: Ship) -> void`, `_hold(ship: Ship, held: Dictionary) -> void` (`held` keys `at: UniversePoint`, `turn: Basis`, `v: Vector3`, `w: Vector3`); signals `slept(ship)`, `woke(ship)`. `awake()` and `nearest()` leave sleepers out.

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_fleet.gd`:

```gdscript
## Moves the starter `by` and lets the origin and the fleet catch up.
func _fly_starter(by: Vector3) -> void:
	_starter.exterior.global_position += by
	(_root.get_node("Universe") as Universe).check()
	_fleet.check_sleep()

func test_a_ship_left_far_behind_sleeps_and_wakes_when_you_come_back():
	var ship := _spawn()
	var universe: Universe = _root.get_node("Universe")
	var was := universe.to_universe(ship.exterior.global_position)
	_fly_starter(Vector3(21000, 0, 0))
	assert_true(_fleet.sleeping(ship), "20.7 km off: asleep")
	assert_true(ship.is_in_group(Fleet.ASLEEP))
	assert_false(ship.exterior.is_in_group(Universe.EXTERIOR_SPACE))
	assert_false(ship.exterior.is_in_group(AsteroidStream.SPACE_ANCHOR))
	assert_eq(ship.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(ship.visible)
	assert_false(_fleet.awake().has(ship))
	_fly_starter(Vector3(-2000, 0, 0))
	assert_true(_fleet.sleeping(ship), "18.7 km: between the two, it sleeps on")
	_fly_starter(Vector3(-2000, 0, 0))
	assert_false(_fleet.sleeping(ship), "16.7 km: awake")
	assert_true(ship.visible)
	assert_true(ship.exterior.is_in_group(Universe.EXTERIOR_SPACE))
	assert_lt(universe.to_universe(ship.exterior.global_position).minus(was).length(), 0.01, "where it was")

func test_a_sleeping_ship_keeps_its_place_across_shifts():
	var ship := _spawn()
	var universe: Universe = _root.get_node("Universe")
	var was := universe.to_universe(ship.exterior.global_position)
	_fly_starter(Vector3(25000, 0, 0))
	for i in 3:
		_starter.exterior.global_position += Vector3(0, 0, 3000)
		assert_true(universe.check())
	assert_lt(_fleet.place_of(ship).minus(was).length(), 0.001)
	_starter.exterior.global_position = universe.to_engine(was) + Vector3(100, 0, 0)
	_fleet.check_sleep()
	assert_false(_fleet.sleeping(ship))
	assert_lt(universe.to_universe(ship.exterior.global_position).minus(was).length(), 0.01)

func test_the_ship_aboard_never_sleeps():
	var ship := _spawn()
	assert_true(_root.board_nearest())
	ship.exterior.global_position += Vector3(30000, 0, 0)
	(_root.get_node("Universe") as Universe).check()
	_fleet.check_sleep()
	assert_false(_fleet.sleeping(ship), "you are aboard it")
	assert_true(_fleet.sleeping(_starter), "the one you left behind sleeps")

## Review focus: asleep, a ship holds neither the origin's shift nor the save.
func test_a_ship_falling_asleep_stops_its_puffs_and_never_holds_the_save():
	var ship := _spawn()
	var puffs := ship.find_children("*", "GPUParticles3D", true, false)
	assert_gt(puffs.size(), 0, "it has emitters")
	for p in puffs:
		(p as GPUParticles3D).emitting = true
	ship.since_struck = 0.0
	assert_eq(_root._fleet_busy(), "hull struck")
	_fly_starter(Vector3(25000, 0, 0))
	for p in puffs:
		assert_false((p as GPUParticles3D).emitting, "%s stopped" % p.name)
	assert_eq(_root._fleet_busy(), "", "asleep, it never holds the save")
```

In `who-knows/test/unit/test_floating_origin_scene.gd`, replace `_covered` and add a test:

```gdscript
## A node is covered if it, or something above it, is shifted, or is a ship
## asleep, held as a UniversePoint (many ships spec §5.1).
func _covered(node: Node) -> bool:
	while node != null:
		if node.is_in_group(Universe.EXTERIOR_SPACE) or node.is_in_group(Fleet.ASLEEP):
			return true
		node = node.get_parent()
	return false

func test_with_a_ship_asleep_everything_outside_is_covered():
	var place := Transform3D(Basis.IDENTITY, _ship.exterior.global_position + Vector3(0, 0, 25000))
	var far: Ship = _root.fleet.spawn(_root._starter_grid(), place)
	_root.fleet.check_sleep()
	assert_true(_root.fleet.sleeping(far))
	assert_eq(_uncovered(), [])
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `./who-knows/run_tests.ps1 -gselect=test_fleet.gd`
Expected: FAIL (`check_sleep` does not exist).

- [ ] **Step 3: Implement sleeping in `fleet.gd`**

Add the signals and constants:

```gdscript
signal slept(ship: Ship)
signal woke(ship: Ship)

## A ship you are not aboard farther than this from the universe's focus
## sleeps; it wakes back inside WAKE_AT. The gap stops it toggling at the edge.
const SLEEP_AT := 20000.0
const WAKE_AT := 18000.0
const CHECK_EVERY := 1.0
## A sleeping ship's root is in this group: out of Universe.EXTERIOR_SPACE,
## held as a UniversePoint instead (CLAUDE.md, the floating origin).
const ASLEEP := &"ships_asleep"
```

Add the members:

```gdscript
var _asleep: Dictionary = {}   # Ship -> {"at": UniversePoint, "turn": Basis, "v": Vector3, "w": Vector3}
var _check_in := 0.0
```

Replace `awake()`:

```gdscript
## The ships that are awake. Built by hand: filter() on a typed array hands
## back an untyped one.
func awake() -> Array[Ship]:
	var out: Array[Ship] = []
	for ship in _ships:
		if not _asleep.has(ship):
			out.append(ship)
	return out
```

In `remove()`, after `_ships.erase(ship)`, add `_asleep.erase(ship)`.

Add:

```gdscript
func _physics_process(delta: float) -> void:
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = CHECK_EVERY
	check_sleep()

func sleeping(ship: Ship) -> bool:
	return _asleep.has(ship)

## Where `ship` is in the universe, asleep or awake.
func place_of(ship: Ship) -> UniversePoint:
	if _asleep.has(ship):
		return _asleep[ship]["at"]
	return universe.to_universe(ship.exterior.global_position)

## Puts to sleep every ship past SLEEP_AT of the focus and wakes every one
## back inside WAKE_AT (many ships spec §5.1). The ship you are aboard never
## sleeps.
func check_sleep() -> void:
	if universe == null or not is_instance_valid(universe.focus):
		return
	var here := universe.to_universe(universe.focus.global_position)
	var mine: Ship = aboard.call() if aboard.is_valid() else null
	for ship in _ships:
		if ship == mine:
			if _asleep.has(ship):
				wake(ship)
			continue
		var d := place_of(ship).minus(here).length()
		if not _asleep.has(ship) and d > SLEEP_AT:
			sleep(ship)
		elif _asleep.has(ship) and d < WAKE_AT:
			wake(ship)

## Holds `ship` where it is, as a UniversePoint, with the velocities it had.
func sleep(ship: Ship) -> void:
	if _asleep.has(ship):
		return
	var hull := ship.exterior
	_hold(ship, {"at": universe.to_universe(hull.global_position), "turn": hull.global_basis,
		"v": hull.linear_velocity, "w": hull.angular_velocity})

## Asleep at `held`: out of the shift and of the worlds' ground, its puffs
## stopped so it never holds the shift, out of physics, its droid and sounds
## stopped, and hidden. A ship coasting when it fell asleep is found where it
## fell asleep.
func _hold(ship: Ship, held: Dictionary) -> void:
	_asleep[ship] = held
	ship.exterior.remove_from_group(Universe.EXTERIOR_SPACE)
	ship.exterior.remove_from_group(AsteroidStream.SPACE_ANCHOR)
	for p in ship.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).emitting = false
	ship.add_to_group(ASLEEP)
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	ship.visible = false
	slept.emit(ship)

## Back where it was held, moving as it was.
func wake(ship: Ship) -> void:
	if not _asleep.has(ship):
		return
	var held: Dictionary = _asleep[ship]
	_asleep.erase(ship)
	var hull := ship.exterior
	hull.global_transform = Transform3D(held["turn"], universe.to_engine(held["at"]))
	ship.remove_from_group(ASLEEP)
	ship.process_mode = Node.PROCESS_MODE_INHERIT
	ship.visible = true
	hull.linear_velocity = held["v"]
	hull.angular_velocity = held["w"]
	hull.add_to_group(Universe.EXTERIOR_SPACE)
	hull.add_to_group(AsteroidStream.SPACE_ANCHOR)
	woke.emit(ship)
```

In `who-knows/scenes/flight_test.gd`, `_fleet_busy` skips sleepers (a ship frozen mid-cycle would otherwise hold the save forever):

```gdscript
	for ship in fleet.awake():
```

- [ ] **Step 4: Run the covering tests**

```powershell
foreach ($t in "test_fleet","test_floating_origin_scene","test_boarding_scene","test_warp_scene") { ./who-knows/run_tests.ps1 -gselect="$t.gd"; if ($LASTEXITCODE) { break } }
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/fleet.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_fleet.gd who-knows/test/unit/test_floating_origin_scene.gd
git commit -m "feat: many ships -- a ship 20 km off sleeps, held as a UniversePoint, and wakes inside 18 km

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Every ship is saved

**Files:**
- Modify: `who-knows/src/save/save_game.gd` (`FORMAT` 2, migration)
- Modify: `who-knows/src/ship/fleet.gd` (`capture`, `to_dict`, `from_dict`, `restore_hull`)
- Modify: `who-knows/scenes/flight_test.gd` (`_ready`, `capture`, `_restore_places`, `_restore_fleet`, `_restore_you`, `_part_named`, `RESTART_ROW`)
- Modify: `who-knows/test/unit/test_save_game.gd`, `test_save_scene.gd`, `test_warp_scene.gd`

**Interfaces:**
- Consumes: `Fleet` with sleeping (Tasks 3, 6), `board_nearest`, `Avatar.move_aboard`, `_deck_spot` (Tasks 3–4).
- Produces: `SaveGame.FORMAT := 2`; `SaveGame.migrate` turns format 1 into 2; save keys `"ships"` (Array of `Ship.to_dict` plus `"name"`), `"aboard"` (String), `"fleet"` (`{"next": int}`). `Fleet.capture(universe_now: Universe) -> Array`, `Fleet.to_dict() -> Dictionary`, `Fleet.from_dict(d: Dictionary) -> void`, `Fleet.restore_hull(ship: Ship, part: Dictionary) -> void`.

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_save_game.gd`:

```gdscript
## Many ships (many ships spec §6.1): format 1's one ship becomes the first of a
## list, named Ship, with you aboard it.
func test_a_format_1_save_becomes_one_ship_named_ship_with_you_aboard():
	var old := {"format": 1, "ship": {"layout": {"cells": []}, "hull": {}}, "avatar": {"mode": "walking"}}
	var now := SaveGame.migrate(old)
	assert_eq(int(now["format"]), 2)
	assert_false(now.has("ship"))
	assert_eq(now["ships"].size(), 1)
	assert_eq(now["ships"][0]["name"], "Ship")
	assert_eq(now["ships"][0]["hull"], {})
	assert_eq(now["aboard"], "Ship")
	assert_eq(now["fleet"], {"next": 2})
	assert_eq(now["avatar"], old["avatar"], "the rest untouched")
	assert_true(old.has("ship"), "the dictionary passed in is not changed")

func test_a_format_2_save_is_left_as_it_is():
	var d := {"format": 2, "ships": [], "aboard": "Ship", "fleet": {"next": 2}}
	assert_eq(SaveGame.migrate(d), d)
```

Append to `who-knows/test/unit/test_save_scene.gd`:

```gdscript
## A second starter spawned 300 m off `root`'s.
func _spawn_second(root: Node, off := Vector3(300, 0, 0)) -> Ship:
	var starter: Ship = root.get_node("Ship")
	var place := Transform3D(starter.exterior.global_basis, starter.exterior.global_position + off)
	return root.fleet.spawn(root._starter_grid(), place)

static func _you(root: Node) -> Avatar:
	return root.get_tree().get_first_node_in_group(Avatar.GROUP) as Avatar

## Many ships (many ships spec §6): two ships through a save, aboard the second
## at its helm. It comes back named and slotted as it was, where it was, with
## you in its seat.
func test_two_ships_round_trip_aboard_the_second_seated():
	var a := _scene()
	await wait_process_frames(2)
	var second := _spawn_second(a)
	second.quantum.store.from_dict({"amount": 123})
	assert_true(a.board_nearest())
	var was_at: UniversePoint = a.get_node("Universe").to_universe(second.exterior.global_position)
	assert_true(a.save_now())
	_drop(a)
	var b := _scene()
	await wait_process_frames(2)
	assert_eq(b.fleet.ships().size(), 2)
	var again: Ship = b.fleet.named(&"Ship2")
	assert_not_null(again, "Ship2 is back")
	assert_eq(again.interior_slot, 1)
	assert_same(b.aboard, again)
	assert_true(again.own)
	assert_false((b.get_node("Ship") as Ship).own)
	assert_eq(again.quantum.store.amount, 123)
	var director: CameraDirector = b.get_node("CameraDirector")
	assert_true(director.is_seated)
	assert_same(director.seat_ship(), again)
	assert_true(again.pilot.seated)
	assert_lt((b.get_node("Universe") as Universe).to_universe(again.exterior.global_position).minus(was_at).length(), 0.5)
	assert_eq(b.fleet.next_number, 3)
	_drop(b)

## Your save from before many ships: one ship, with you aboard it.
func test_a_format_1_save_loads_as_one_ship_with_you_aboard():
	var a := _scene()
	await wait_process_frames(2)
	var parts: Dictionary = a.capture()
	_drop(a)
	var old := parts.duplicate(true)
	var ship: Dictionary = old["ships"][0]
	ship.erase("name")
	old.erase("ships")
	old.erase("aboard")
	old.erase("fleet")
	old["ship"] = ship
	old["format"] = 1
	old["generators"] = SaveGame.generators()
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old, "", false, true))
	f.close()
	var b := _scene()
	await wait_process_frames(2)
	assert_true(b.resumed, "it loaded")
	assert_eq(b.fleet.ships().size(), 1)
	assert_same(b.aboard, b.get_node("Ship"))
	_drop(b)

func test_a_far_ship_loads_asleep_where_it_was():
	var a := _scene()
	await wait_process_frames(2)
	var far := _spawn_second(a, Vector3(0, 0, 25000))
	var was: UniversePoint = a.get_node("Universe").to_universe(far.exterior.global_position)
	a.fleet.check_sleep()
	assert_true(a.fleet.sleeping(far))
	assert_true(a.save_now())
	_drop(a)
	var b := _scene()
	await wait_process_frames(2)
	var again: Ship = b.fleet.named(&"Ship2")
	assert_true(b.fleet.sleeping(again), "it loads asleep")
	assert_lt(b.fleet.place_of(again).minus(was).length(), 0.01)
	_drop(b)

## Review focus: a spacewalk tied to the second ship comes back tied to it.
func test_a_spacewalk_tied_to_the_second_ship_comes_back_tied_to_it():
	var a := _scene()
	await wait_process_frames(2)
	var second := _spawn_second(a)
	assert_true(a.board_nearest())
	(a.get_node("CameraDirector") as CameraDirector).stand_now()
	var you := _you(a)
	you.enter_suit(a.get_node("Outside"), Transform3D(Basis.IDENTITY, second.exterior.global_position + Vector3(0, 25, 0)),
		Vector3.ZERO, second.exterior)
	var lock: Airlock = second.airlocks.values()[0]
	you.beacon_source = lock.beacon
	you.home_source = lock.home
	assert_true(a.save_now())
	_drop(a)
	var b := _scene()
	await wait_process_frames(2)
	var again: Ship = b.fleet.named(&"Ship2")
	var back := _you(b)
	assert_eq(back.mode, Avatar.Mode.SUIT)
	assert_same(b.aboard, again)
	assert_same(back.hull, again.exterior)
	assert_same(back.beacon_source.get_object(), again.airlocks.values()[0])
	_drop(b)
```

In `who-knows/test/unit/test_warp_scene.gd`, `test_a_save_during_travel_loads_at_the_drop_out_point` reads the first ship:

```bash
sed -i 's#saved\["ship"\]#saved["ships"][0]#g' who-knows/test/unit/test_warp_scene.gd
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `./who-knows/run_tests.ps1 -gselect=test_save_game.gd`, then `-gselect=test_save_scene.gd`.
Expected: FAIL (format is 1; `"ships"` missing).

- [ ] **Step 3: `save_game.gd`: format 2**

Set `const FORMAT := 2`. Replace `migrate` and add the step:

```gdscript
## Brings an older format up to FORMAT, one step at a time.
static func migrate(data: Dictionary) -> Dictionary:
	var out := data
	if int(out.get("format", 1)) < 2:
		out = _to_many_ships(out)
	return out

## Format 1 to 2 (docs/superpowers/specs/2026-10-02-many-ships-design.md
## §6.1): the one ship becomes the first of a list, named Ship, and you are
## aboard it.
static func _to_many_ships(data: Dictionary) -> Dictionary:
	var out := data.duplicate()
	var ship: Dictionary = out.get("ship", {})
	out.erase("ship")
	var ships := []
	if not ship.is_empty():
		var named := ship.duplicate()
		named["name"] = String(Fleet.STARTER)
		ships.append(named)
	out["ships"] = ships
	out["aboard"] = String(Fleet.STARTER)
	out["fleet"] = {"next": 2}
	out["format"] = 2
	return out
```

- [ ] **Step 4: `fleet.gd`: saving the ships**

```gdscript
## Every ship's part of a save, each with its name (many ships spec §6.1). A
## sleeping ship's hull is where it is held, not an engine position.
func capture(universe_now: Universe) -> Array:
	var out := []
	for ship in _ships:
		var part := ship.to_dict(universe_now)
		part["name"] = String(ship.name)
		if _asleep.has(ship):
			var held: Dictionary = _asleep[ship]
			part["hull"] = {"at": SaveCodec.upoint(held["at"]), "turn": SaveCodec.basis(held["turn"]),
				"v": SaveCodec.vec3(held["v"]), "w": SaveCodec.vec3(held["w"])}
		out.append(part)
	return out

func to_dict() -> Dictionary:
	return {"next": next_number}

func from_dict(d: Dictionary) -> void:
	next_number = maxi(int(d.get("next", 2)), 2)

## Puts a loaded ship's hull back (§6.3): where the save had it, or asleep
## there when that is past SLEEP_AT of the origin, never placed far off in
## engine space.
func restore_hull(ship: Ship, part: Dictionary) -> void:
	var hull: Dictionary = part.get("hull", {})
	var at := SaveCodec.to_upoint(hull.get("at"))
	if at.minus(universe.origin).length() > SLEEP_AT:
		_hold(ship, {"at": at, "turn": SaveCodec.to_basis(hull.get("turn")),
			"v": SaveCodec.to_vec3(hull.get("v")), "w": SaveCodec.to_vec3(hull.get("w"))})
	else:
		ship.restore_hull(part, universe)
```

- [ ] **Step 5: `flight_test.gd`: capture and restore many**

1. Add the constant:

```gdscript
## A save from another world generator brings every ship along, lined up this
## far apart beside the starter (many ships spec §6.3).
const RESTART_ROW := 300.0
```

2. `capture()` returns:

```gdscript
	return {
		"world": {"seed": _stream.seed},
		"ships": fleet.capture(_universe),
		"aboard": String(aboard.name),
		"fleet": fleet.to_dict(),
		"avatar": _capture_you(),
		"salvage": salvage.to_dict(),
		"strays": strays.to_dict(),
		"npcs": _capture_npcs(),
	}
```

3. The start of `_ready()` reads the starter's part by name:

```gdscript
	var saved := _read_save()
	var starter_part := _part_named(saved, Fleet.STARTER)
	var layout := Ship.layout_of(starter_part) if resumed else null
	if resumed and (layout == null or layout.coords().is_empty()):
		push_error("FlightTest: the saved starter has no blocks; starting a new game")
		resumed = false
		saved = {}
		starter_part = {}
	if resumed:
		_starter.launch_blueprint = Ship.launch_of(starter_part)
		npc_ledger.from_dict(saved.get("npcs", {}))
	_starter.set_grid(layout if resumed else _starter_grid(), not resumed)
	if resumed:
		_starter.restore_aboard(starter_part)
	_make_fleet()
```

4. In `_wire_universe`, the not-same-world branch becomes:

```gdscript
	else:
		_universe.origin = start
		if resumed:
			_restore_fleet(saved, false)
			_restore_you(saved.get("avatar", {}), false)
```

5. Replace `_restore_places` and add `_restore_fleet` and `_part_named`:

```gdscript
## The origin near where you were, then every ship and you (§6.1; many ships
## spec §6.3).
func _restore_places(saved: Dictionary) -> void:
	var you: Dictionary = saved.get("avatar", {})
	var first := _part_named(saved, String(saved.get("aboard", Fleet.STARTER)))
	if first.is_empty():
		first = _part_named(saved, Fleet.STARTER)
	var focus := SaveCodec.to_upoint(first.get("hull", {}).get("at"))
	if String(you.get("mode", "")) == "suit":
		focus = SaveCodec.to_upoint(you.get("at"))
	_universe.origin = UniversePoint.at(
		roundi(focus.x / Universe.STEP) * int(Universe.STEP),
		roundi(focus.y / Universe.STEP) * int(Universe.STEP),
		roundi(focus.z / Universe.STEP) * int(Universe.STEP))
	_restore_fleet(saved, true)
	_restore_you(you, true)

## Every saved ship but the starter, spawned under its own name, unstocked,
## with everything aboard, and the ship you were aboard (many ships spec
## §6.3). `in_place` false (the world started over) lines them up RESTART_ROW
## apart beside the starter instead of where they were.
func _restore_fleet(saved: Dictionary, in_place: bool) -> void:
	fleet.from_dict(saved.get("fleet", {}))
	if in_place:
		_starter.restore_hull(_part_named(saved, Fleet.STARTER), _universe)
	var row := 0
	for part in saved.get("ships", []):
		if not (part is Dictionary) or String(part.get("name", "")) == Fleet.STARTER:
			continue
		var grid := Ship.layout_of(part)
		if grid.coords().is_empty():
			push_error("FlightTest: the saved ship %s has no blocks; it is left out" % part.get("name", "?"))
			continue
		row += 1
		var place := _starter.exterior.global_transform.translated(Vector3(RESTART_ROW * row, 0, 0))
		var ship := fleet.spawn(grid, place, false, String(part["name"]), Ship.launch_of(part))
		if ship == null:
			continue
		ship.restore_aboard(part)
		if in_place:
			fleet.restore_hull(ship, part)
	var named := fleet.named(StringName(saved.get("aboard", Fleet.STARTER)))
	aboard = named if named != null else _starter

## The saved ship called `ship_name`, or {}.
static func _part_named(saved: Dictionary, ship_name: String) -> Dictionary:
	for part in saved.get("ships", []):
		if part is Dictionary and String(part.get("name", "")) == ship_name:
			return part
	return {}
```

6. In `_restore_you`, the walking/seated placing moves you into the ship you were aboard:

```gdscript
	var mode := String(d.get("mode", "walking"))
	if mode != "suit":
		var pose := aboard.interior.global_transform * SaveCodec.to_transform(d.get("place"))
		if _can_stand(pose):
			pose = Transform3D(Basis(Vector3.UP, pose.basis.get_euler().y), pose.origin)
		else:
			pose = aboard.interior.global_transform * _deck_spot(aboard)
		_avatar.move_aboard(aboard.interior, pose)
		_avatar.set_head_pitch(float(d.get("pitch", 0.0)))
	elif not outside_too:
		_avatar.move_aboard(aboard.interior, aboard.interior.global_transform * _deck_spot(aboard))
```

and `_director.sit_now($Ship/Interior/PilotSeat)` becomes `_director.sit_now(aboard.seat)`. (`_restore_spacewalk` and `_can_stand` already use `aboard` from Task 3.)

7. The `SaveGame` header comment's *"Format 1 is the first, so there is nothing to do yet"* is gone with the old `migrate`; check no other comment still says the save has one `"ship"` (`grep -rn '"ship"' who-knows/src who-knows/scenes`).

- [ ] **Step 6: Run the covering tests**

```powershell
foreach ($t in "test_save_game","test_save_scene","test_warp_scene","test_fleet","test_boarding_scene","test_save_codec") { ./who-knows/run_tests.ps1 -gselect="$t.gd"; if ($LASTEXITCODE) { break } }
```

Expected: all PASS; `test_save_scene`'s `after_all` still finds the owner's real save untouched.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/save/save_game.gd who-knows/src/ship/fleet.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_save_game.gd who-knows/test/unit/test_save_scene.gd who-knows/test/unit/test_warp_scene.gd
git commit -m "feat: many ships -- every ship saves under its own name; format 1 saves load as one ship

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Proof in the real game, and the upkeep

**Files:**
- Modify: `.claude/skills/building-a-ship/ship_probe.gd` (`_fleet_pass`), `SKILL.md`, `reference.md`
- Modify: `CLAUDE.md`, `docs/superpowers/specs/2026-10-02-many-ships-design.md` (§12 *What was built*), `docs/superpowers/SLICE-1-STATUS.md`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: The probe's two-ship pass**

In `.claude/skills/building-a-ship/ship_probe.gd`, add to the header comment: *"Then a two-ship pass (many ships spec §8.2): fps in the worst view with a second ship 300 m off, probe_fleet_from_starter{,_dark}.png, F8 to its helm, probe_fleet_from_second.png, a burn, standing and walking, probe_fleet_spacewalk.png, and the fleet line."* Add before `_run`:

```gdscript
## Many ships (docs/superpowers/specs/2026-10-02-many-ships-design.md §8.2):
## the worst view's frame rate with a second ship 300 m off; the second ship
## from the starter's seat, sunlit and then dark with its floods on; F8 to its
## helm and the starter from there; a 1.5 s burn, short of the starter; standing
## and walking; a spacewalk between the two. Prints the fleet line.
func _fleet_pass(scene: Node) -> void:
	var fleet: Fleet = scene.get("fleet")
	if fleet == null:
		print("fleet   no Fleet in this scene")
		return
	var first: Ship = scene.get("aboard")
	var director: CameraDirector = scene.get_node("CameraDirector")
	var sun: DirectionalLight3D = scene.get_node("DirectionalLight3D")
	var avatar: Avatar = scene.get_tree().get_first_node_in_group(Avatar.GROUP)
	director.sit_now(first.seat)
	var behind := first.exterior.global_transform * Vector3(0, 0, 300)
	var second := fleet.spawn(scene.call("_starter_grid"), Transform3D(first.exterior.global_basis, behind))
	if await _park_by_a_rock(scene, first, 60.0):
		second.exterior.global_position = first.exterior.global_transform * Vector3(0, 0, 300)
		_lights(first, true, true)
		print("fps     %.0f seated by a rock, both groups on, a second ship 300 m off" % await _fps(2.0))
		_lights(first, false, false)
	# Out in the open, the second ship 120 m ahead and a little to port, nose to
	# the starter.
	first.exterior.global_position += first.exterior.global_basis.z * 2000.0
	await _process_frames(60)
	var hull := first.exterior.global_transform
	second.exterior.global_transform = Transform3D(Basis(hull.basis.y, PI) * hull.basis, hull * Vector3(-25, 0, -120))
	second.exterior.linear_velocity = Vector3.ZERO
	await _shot("fleet_from_starter")
	sun.visible = false
	_lights(second, true, false)
	await _shot("fleet_from_starter_dark")
	_lights(second, false, false)
	sun.visible = true
	print("board   F8 %s" % ("ok" if scene.call("board_nearest") else "REFUSED"))
	await _process_frames(10)
	await _shot("fleet_from_second")
	var first_at := first.exterior.global_position
	Input.action_press("move_forward")
	for i in 90:
		await physics_frame
	Input.action_release("move_forward")
	print("fly     second ship %.1f m/s after 1.5 s; the starter moved %.2f m" % [
		second.exterior.linear_velocity.length(), first.exterior.global_position.distance_to(first_at)])
	director.stand()
	await director.transition_finished
	var from := avatar.global_position
	Input.action_press("move_back")
	for i in 60:
		await physics_frame
	Input.action_release("move_back")
	var walked := from.distance_to(avatar.global_position)
	print("walked  %.2f m aboard %s%s" % [walked, second.name, "" if walked > 1.0 else "  <-- STUCK"])
	var mid := (first.exterior.global_position + second.exterior.global_position) * 0.5 + Vector3(0, 6, 0)
	avatar.enter_suit(scene.get_node("Outside"), Transform3D(Basis.looking_at(first.exterior.global_position - mid, Vector3.UP), mid),
		Vector3.ZERO, second.exterior)
	await _process_frames(10)
	await _shot("fleet_spacewalk")
	var aboard: Ship = scene.get("aboard")
	var own_ok := true
	for s in fleet.ships():
		var own_pieces := 0
		for g in s.exterior.find_children("*", "GeometryInstance3D", true, false):
			if (g as GeometryInstance3D).layers == ExteriorBuilder.OWN_HULL_LAYER:
				own_pieces += 1
		own_ok = own_ok and ((own_pieces > 0) == (s == aboard))
	var asleep := fleet.ships().filter(func(s: Ship) -> bool: return fleet.sleeping(s)).size()
	print("fleet   %d ships, aboard %s, own layer %s, asleep %d" % [fleet.ships().size(), aboard.name,
		"ok" if own_ok else "WRONG", asleep])
```

At the end of `_run`, replace `quit()` with:

```gdscript
	await _fleet_pass(scene)
	quit()
```

- [ ] **Step 2: Run the probe, windowed**

```powershell
New-Item -ItemType Directory -Force C:\Users\Brandon\AppData\Local\Temp\claude\D--git-whoknows\probe_fleet | Out-Null
& $godot --path who-knows --resolution 1280x720 --script D:\git\whoknows\.claude\skills\building-a-ship\ship_probe.gd -- C:\Users\Brandon\AppData\Local\Temp\claude\D--git-whoknows\probe_fleet 2>&1 | Tee-Object -FilePath C:\Users\Brandon\AppData\Local\Temp\claude\D--git-whoknows\probe_fleet\probe.log
```

Expected in the log: `fleet   2 ships, aboard Ship2, own layer ok, asleep 0`; `board   F8 ok`; no `STUCK`; no `SHADER ERROR`; the fps line *"seated by a rock, both groups on, a second ship 300 m off"* **≥ 120**, next to the main run's one-ship figure. If it is under 120, stop and report both numbers to the owner before going on.

- [ ] **Step 3: Look at the renders, then show the owner**

Read `probe_fleet_from_starter.png`, `probe_fleet_from_starter_dark.png`, `probe_fleet_from_second.png` and `probe_fleet_spacewalk.png`. Each must show the other ship's hull (a blank sky means `set_own` or the canopy mask is wrong). Send them to the owner with `SendUserFile`, with the fps lines, and ask them to fly it: F8 across, fly the second ship, spacewalk back into the starter.

- [ ] **Step 4: `CLAUDE.md`**

Add after the *Exterior space has a floating origin* section:

```markdown
## Every ship is usable

The owner's rule (2026-10-02): **any ship in the game can be boarded, flown and saved**, never a
look-only prop. Ships come and go through `Fleet` (`src/ship/fleet.gd`): the starter is `/Ship`,
an instance of `scenes/ship.tscn`; any other is `fleet.spawn(grid, place)`. The ship you are in
is the flight scene's `aboard`, and `board(ship)` is the one place it changes
(`docs/superpowers/specs/2026-10-02-many-ships-design.md`). Never author a second `Ship` in a
`.tscn` or instance `ship.tscn` any other way.
```

And at the end of the floating-origin section's rule, add: *"A ship asleep, more than 20 km off, is the one exception: it leaves the group, is held as a `UniversePoint`, and is in group `Fleet.ASLEEP`."*

- [ ] **Step 5: The `building-a-ship` skill**

In `SKILL.md`:
- Checklist step 7, *Wire the scene*: replace the `Ship.set_grid`, `interior_slot`, `PilotSeat` transform, avatar spawn and `PilotControls` bullets with:
  - **every ship goes through `Fleet`** (many ships spec): the starter is `/Ship`, an instance of `scenes/ship.tscn`; any other is `fleet.spawn(grid, place)`, which gives it a slot and a name that is never reused. The flight scene's `_wire_ship` hands it the director, its warp, sensors, lights and crew ledger, and `Ship` places its own `PilotSeat` from `fixture_frame` after every rebuild;
  - **every ship is usable** (the owner's rule, 2026-10-02): F8 seats you at the nearest other helm, any airlock lets a suit in, and every ship saves. The probe's `fleet` line proves it.
- *Mistakes already made*: add these rows:

| Mistake | What happened | Do instead |
|---|---|---|
| Every hull on `OWN_HULL_LAYER` | Found while designing many ships: the canopy and every window leave that layer out, so a second ship would have been invisible from your seat | `Ship.set_own`: only the ship you are aboard draws there; `board()` moves it |
| Each `PilotControls` listening to the one director | Sitting in any seat would have handed every ship the stick | `bind_director`; controls take the stick only when `director.seat_ship()` is their ship |
| An airlock that let in only its own suit (`avatar.hull == hull`) | No way to board another ship from a spacewalk | Any suit; `Ship.airlock_crossed` boards that ship |
| A `ViewportTexture` path for a scene instanced many times | Fragile inside an instanced scene | `Ship._make_canopy_material()` from `Canopy.get_texture()`, one per ship |
| Naming a ship anew on load | The droid's ledger record is named for its ship, so its health would be lost or given to another | Names never change and are never reused; `Fleet.next_number` is saved |

- *Not built yet*: add **docking** (two hulls held airlock to airlock) and **ships flown by NPCs**.

In `reference.md`, add a section **Many ships** (`docs/superpowers/specs/2026-10-02-many-ships-design.md`) with this table, and replace *Scene wiring*'s "A second ship in the same scene needs its own `interior_slot`…" paragraph with "Every ship is spawned through `Fleet`; see *Many ships*":

| API | Does |
|---|---|
| `scenes/ship.tscn` | a whole ship: hull, interior, seat, flight computer, controls, canopy view, motion coupling. No avatar, no director |
| `Fleet.adopt(ship)`, `spawn(grid, place, stock, ship_name, launch)`, `remove(ship)` | take in the starter; a new ship at rest with the next free slot and a never-reused name (`Ship2`…), not own; free one (never `Ship` or the one aboard) |
| `Fleet.ships()`, `awake()`, `named(n)`, `nearest(p, except)`, `sleeping(s)`, `place_of(s)` | |
| `Fleet.MAX_SHIPS` 16, `SLEEP_AT` 20 km, `WAKE_AT` 18 km, `CHECK_EVERY` 1 s, `ASLEEP`, `STARTER` `&"Ship"`, `next_number` | |
| `Fleet.capture(universe)`, `to_dict()`, `from_dict(d)`, `restore_hull(ship, part)` | the save's `"ships"` and `"fleet"`; a far ship loads asleep |
| flight scene `aboard`, `board(ship, force)`, `board_nearest()` (F8), `board_at_helm(ship)`, `_wire_ship(ship)`, `aboard_changed` | the ship you are in; the one switch; F8's hop; everything one ship needs from the game |
| `Ship.own`, `set_own(on)` | the own render layer and the interior shown, for the ship aboard only; re-applied after every rebuild |
| `Ship.pilot`, `seat`, `motion`, `chase_camera`, `canopy_camera`, `canopy_overlay`, `helm_cell()`, `airlock_crossed` | |
| `CameraDirector.bind(ship)`, `seat_ship()`, `stand_now()`, `ship_of(node)` | |
| `PilotControls.bind_director(d)`, `PilotSeat.director`, `Avatar.move_aboard(interior, pose)` | |
| `SuitTie.choose`, `gap`, `SWITCH_MARGIN` 10 m, `REACH` 500 m, 4 Hz | your suit belongs to the nearest ship |
| Save format 2 | `"ships"` (each `Ship.to_dict` + `"name"`), `"aboard"`, `"fleet"`; format 1 migrates |

Also put the probe's measured numbers in `reference.md` (the two fps figures, the `fleet` line).

- [ ] **Step 6: The spec's *What was built*, and the status page**

Append §12 *What was built (the date it was finished)* to `docs/superpowers/specs/2026-10-02-many-ships-design.md`: the canopy material made in code (Task 1's deviation), `Fleet.awake()` and `launch` on `spawn` (beyond §5.1), the measured fps with one ship and two, and anything else that differed. Set the spec's **Status** line to *Built on `many-ships`*. Add a *Many ships* bullet to *What works* in `docs/superpowers/SLICE-1-STATUS.md`.

- [ ] **Step 7: Ask the owner about the full suite**

Ask the owner whether to run the full suite now (about 8 minutes). Only with their yes:

```powershell
./who-knows/run_tests.ps1 *> C:\Users\Brandon\AppData\Local\Temp\claude\D--git-whoknows\suite.log
```

Run it in the background and wait for the end. Report the pass count, any failures with their output, and the exit code.

- [ ] **Step 8: Commit**

```bash
git add CLAUDE.md .claude/skills/building-a-ship docs/superpowers
git commit -m "docs: many ships -- the rule in CLAUDE.md, the ship skill, the probe's two-ship pass and what was built

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
