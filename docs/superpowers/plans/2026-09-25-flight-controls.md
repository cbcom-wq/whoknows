# Flight Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the ship easy to fly where you mean to. A virtual stick holds a steady turn, the
arrow keys pitch and yaw, and point-and-click hands a heading to the flight computer. C locks a
speed, and assist spends all the side thrust on drift. The RCS blocks visibly and audibly puff
as they turn and push the ship.

**Architecture:** The physics is unchanged: `FlightComputer` still applies one torque and one
central force to the hull, clamped to `ShipStats`' budgets. It gains a speed lock, a heading
hold (a pure `heading_rate`), full drift authority (a pure `translation_force`), and keeps each
tick's commanded twist and push in hull axes. A new `PilotControls` node takes the seated input
out of `CameraDirector`, drives the flight computer, and is the HUD's vehicle while you sit. A
new `RcsShow` on the hull turns the commanded twist and push into a firing amount per `rcs`
block, which drives world-space puffs and a puff sound aboard. New HUD elements draw the stick,
the pointer, the held heading and a controls card.

**Tech Stack:** Godot 4.5.1 (.NET build, GDScript only), GUT 9 tests, `run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-09-25-flight-controls-design.md`. Read it first; section
numbers below (§) are that spec's.

## Global Constraints

- **Physics unchanged:** one `apply_torque` and one `apply_central_force` on the hull per tick,
  clamped to `ShipStats`' budgets. No per-thruster forces.
- **Numbers from the spec**, as starting values:
  - `PilotStick`: `RADIUS = 0.2`, `DEADZONE = 0.02` (fractions of viewport height), `CURVE = 1.5`.
  - `FlightComputer`:
    - `ASSIST_TURN_RATE = deg_to_rad(60.0)` and `RATE_GAIN = 4.0`, both unchanged;
    - `DRIFT_AUTHORITY = 1.0`;
    - `HOLD_BRAKE_SHARE = 0.6`;
    - `HOLD_GAIN = 2.0`.
  - `RcsShow`:
    - fires fully within 45° (`FULL_ALIGN = 0.7071`) and not at all past 70° (`NO_ALIGN = 0.342`);
    - `SHOW_AT = 0.05`;
    - `PUFF_ON = 0.15`, `PUFF_REARM = 0.05`, `PUFF_GAP = 0.12` s;
    - `PUFFS = 16` per block, `LIFETIME = 0.5` s;
    - render layer `1`.
- **Keys** (§4): ↑/↓ `pitch_up`/`pitch_down`, ←/→ `yaw_left`/`yaw_right`, RMB `point_mode`,
  LMB `set_heading`, C `speed_lock`, H `toggle_controls`. Everything else is unchanged.
- **Visual style** (`docs/design/visual-style.md`, binding):
  - puff colour is `InteriorPalette.STEAM`, through the shared `Puffs` builder;
  - HUD colours come from `HudPalette`;
  - built-in particle material and `StandardMaterial3D` only, **no new shader**;
  - `test_visual_style_rules.gd` must stay green; if it fails, fix the code, not the test.
- **Floating origin** (CLAUDE.md): the puff emitters are children of the hull
  (`Ship/Exterior`, which is in `Universe.EXTERIOR_SPACE`), are world-space
  (`local_coords = false`), and join `Universe.HOLDS_SHIFT`. The heading is a world direction,
  which a shift never changes.
- **`.tscn` edits: no `#` comments anywhere in a scene file.** Verify every scene edit by
  reading the node and its properties back at runtime in a test, not by a clean load.
- **Tests:** GUT, headless, output pristine. From the worktree root in PowerShell:
  - everything: `& .\who-knows\run_tests.ps1`;
  - one script: `& .\who-knows\run_tests.ps1 '-gselect=test_pilot_stick'` (quote the argument).
- **After adding a `class_name`,** run the import pass before tests:
  `& "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path .\who-knows --import`
  (or `$env:GODOT_BIN` if set).
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Work in a sibling worktree,** `D:\git\whoknows-flight` on branch `flight-controls`; other
  sessions share `D:\git\whoknows`. The branch already holds the spec and this plan. Set it up
  once:
  1. Put `D:\git\whoknows` back on `main`: `git -C D:\git\whoknows switch main`.
  2. Add the worktree: `git -C D:\git\whoknows worktree add D:\git\whoknows-flight flight-controls`.
  3. Run the import pass there once.
- Code style: match the surrounding GDScript. British spelling in comments ("colour", "centre").
  Doc comments (`##`) say what and why, plainly, citing spec sections.

---

## File Structure

| File | Responsibility |
|---|---|
| Modify `who-knows/project.godot` | Eight new input actions; drop a stray dictionary-style block at the end of `[input]`. |
| Create `who-knows/src/flight/pilot_stick.gd` | `PilotStick`: the virtual stick's offset, dead zone and curve. Pure. |
| Modify `who-knows/src/flight/flight_computer.gd` | Drift authority, `translation_force`, speed lock, heading hold, `heading_rate`, commanded twist and push, telemetry. |
| Modify `who-knows/src/ui/vehicle_telemetry.gd` | Hold, lock, stick and pointer fields. |
| Create `who-knows/src/flight/pilot_controls.gd` | `PilotControls`: seated input, point mode, pointer to world direction, HUD source. |
| Modify `who-knows/src/camera/camera_director.gd` | Loses the flight input (now `PilotControls`'). |
| Create `who-knows/src/world/puffs.gd` | `Puffs`: the shared chunky puff mesh, fade and growth. |
| Modify `who-knows/src/ship/airlock/airlock_show.gd` | Uses `Puffs` instead of its private copies. |
| Modify `who-knows/src/audio/synth.gd` | `rcs_puff`. |
| Create `who-knows/src/flight/rcs_show.gd` | `RcsShow`: which blocks, firing amounts (pure), puffs, puff sounds. |
| Modify `who-knows/src/ship/ship.gd` | Builds `RcsShow` on the hull and rebuilds it with the stats. |
| Create `who-knows/src/ui/stick_cursor.gd` | `StickCursor`: the stick ring and the point-mode pointer and hint. |
| Create `who-knows/src/ui/heading_marker.gd` | `HeadingMarker`: the held heading, projected like `VelocityMarker`. |
| Modify `who-knows/src/ui/panels/velocity_panel.gd` | `LOCK` and `HDG HOLD` readout. |
| Create `who-knows/src/ui/controls_card.gd` | `ControlsCard`: the key list, from the `InputMap`. |
| Modify `who-knows/scenes/flight_test.tscn` | `PilotControls`, `StickCursor`, both `HeadingMarker`s, `ControlsCard`. |
| Modify `who-knows/scenes/flight_test.gd` | HUD source is `PilotControls`; registers the cockpit heading marker. |
| Tests | `test_input_map`, `test_pilot_stick` (new), `test_flight_computer`, `test_vehicle_telemetry`, `test_pilot_controls` (new), `test_puffs` (new), `test_synth`, `test_rcs_show` (new), `test_hud_panels`, `test_stick_cursor` (new), `test_heading_marker` (new), `test_controls_card` (new), `test_hud_scene_wiring`, `test_visual_style_rules`. |
| Docs | Slice spec §7.1, piloting HUD spec §7, visual style guide §4, flight controls spec (status and tuned values). |

---

### Task 1: The input actions

**Files:**
- Modify: `who-knows/project.godot` (the `[input]` section)
- Test: `who-knows/test/unit/test_input_map.gd`

**Interfaces:**
- Produces: actions `pitch_up` (↑), `pitch_down` (↓), `yaw_left` (←), `yaw_right` (→),
  `point_mode` (RMB), `set_heading` (LMB), `speed_lock` (C), `toggle_controls` (H).

**Watch out:**
- The `[input]` section ends with a stray block after `drop={...}`: a line starting
  `[{"device":-1,"keycode":87,...` followed by eleven dictionary-style duplicate actions
  (`move_back={"deadzone":0.2,"events":[{...}]}` and so on).
- That first line begins with `[`, so Godot reads it as a new section header. Anything written
  after it lands outside `[input]`, and the new actions would silently register with no
  bindings.
- The real bindings are the `Object(InputEventKey, ...)` ones above it; the tests prove it.
  Delete the stray block and add the new actions straight after `drop`.

- [ ] **Step 1: Write the failing tests**

In `test_input_map.gd`, extend `REQUIRED_ACTIONS`:

```gdscript
const REQUIRED_ACTIONS := [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint", &"crouch", &"interact",
	&"roll_left", &"roll_right", &"boost",
	&"toggle_assist", &"cycle_camera",
	&"use", &"throw", &"drop",
	&"pitch_up", &"pitch_down", &"yaw_left", &"yaw_right",
	&"point_mode", &"set_heading", &"speed_lock", &"toggle_controls",
]
```

and append:

```gdscript
## Flight controls spec §4: arrows turn, RMB points, LMB sets the heading, C
## locks the speed, H shows the controls card.
func test_flight_controls_are_bound_where_the_card_says():
	var keys := {
		&"pitch_up": KEY_UP, &"pitch_down": KEY_DOWN,
		&"yaw_left": KEY_LEFT, &"yaw_right": KEY_RIGHT,
		&"speed_lock": KEY_C, &"toggle_controls": KEY_H,
	}
	for action in keys:
		var ev: InputEventKey = InputMap.action_get_events(action)[0]
		assert_eq(ev.physical_keycode, keys[action], String(action))
	var point: InputEventMouseButton = InputMap.action_get_events(&"point_mode")[0]
	assert_eq(point.button_index, MOUSE_BUTTON_RIGHT)
	var click: InputEventMouseButton = InputMap.action_get_events(&"set_heading")[0]
	assert_eq(click.button_index, MOUSE_BUTTON_LEFT)

## A stray block of dictionary-style duplicates once sat at the end of [input].
## Its first line starts with "[", which opens a new section, so any action
## written after it silently lost its bindings.
func test_the_input_section_has_no_dictionary_style_bindings():
	var text := FileAccess.get_file_as_string("res://project.godot")
	assert_false(text.contains("\"type\":\"InputEventKey\""))
```

- [ ] **Step 2: Run to see them fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_input_map'`
Expected: FAIL. The new actions are "not registered", and the dictionary-style test fails.

- [ ] **Step 3: Edit `project.godot`**

1. Delete the stray block: every line from the one starting `[{"device":-1,"keycode":87` down
   to the line starting `cycle_camera={"deadzone":0.2,"events":[{`, inclusive. Keep the blank
   line before `[layer_names]`.
2. Straight after the `drop={ ... }` block's closing `}`, add:

```
pitch_up={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
pitch_down={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
yaw_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
yaw_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
point_mode={
"deadzone": 0.2,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":2,"canceled":false,"pressed":false,"double_click":false,"script":null)]
}
set_heading={
"deadzone": 0.2,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)]
}
speed_lock={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":67,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
toggle_controls={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":72,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
```

(4194319–4194322 are Godot's `KEY_LEFT`, `KEY_UP`, `KEY_RIGHT`, `KEY_DOWN`; 67 is C, 72 is H.)

- [ ] **Step 4: Run to see them pass, and the whole suite**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_input_map'` then `& .\who-knows\run_tests.ps1`
Expected: PASS, including the existing WASD/F/mouse/G binding tests (proving the deleted block
never mattered).

- [ ] **Step 5: Commit**

```bash
git add who-knows/project.godot who-knows/test/unit/test_input_map.gd
git commit -m "feat: input actions for the stick keys, point mode, speed lock and controls card

Also drops a stray dictionary-style block at the end of [input]: its first
line opened a new section, so any action added after it had no bindings.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The virtual stick

**Files:**
- Create: `who-knows/src/flight/pilot_stick.gd`
- Test: `who-knows/test/unit/test_pilot_stick.gd`

**Interfaces:**
- Produces: `class_name PilotStick extends RefCounted`:
  - `const RADIUS := 0.2`, `const DEADZONE := 0.02`, `const CURVE := 1.5`;
  - `var offset: Vector2`, in fractions of viewport height, screen axes (+y down);
  - `move(pixels: Vector2, viewport_height: float) -> void`;
  - `centre() -> void`;
  - `is_centred() -> bool`, true inside the dead zone;
  - `command() -> Vector2`: (pitch, yaw), each −1..1, up is nose up, left is yaw left.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_pilot_stick.gd`:

```gdscript
extends GutTest

## The virtual stick (flight controls spec §4.1): where the cursor sits, not
## how fast the mouse moved, is the command.

const H := 720.0

func test_a_centred_stick_asks_for_nothing():
	var s := PilotStick.new()
	assert_eq(s.command(), Vector2.ZERO)
	assert_true(s.is_centred())

func test_inside_the_dead_zone_asks_for_nothing():
	var s := PilotStick.new()
	s.move(Vector2(PilotStick.DEADZONE * H * 0.9, 0.0), H)
	assert_eq(s.command(), Vector2.ZERO)
	assert_true(s.is_centred())

func test_full_deflection_up_is_full_nose_up():
	var s := PilotStick.new()
	s.move(Vector2(0.0, -PilotStick.RADIUS * H), H)
	assert_almost_eq(s.command(), Vector2(1.0, 0.0), Vector2.ONE * 0.0001)
	assert_false(s.is_centred())

func test_full_deflection_left_is_full_yaw_left():
	var s := PilotStick.new()
	s.move(Vector2(-PilotStick.RADIUS * H, 0.0), H)
	assert_almost_eq(s.command(), Vector2(0.0, 1.0), Vector2.ONE * 0.0001)

func test_the_cursor_clamps_at_full_deflection():
	var s := PilotStick.new()
	s.move(Vector2(0.0, 5000.0), H)
	assert_almost_eq(s.offset.length(), PilotStick.RADIUS, 0.00001)
	assert_almost_eq(s.command(), Vector2(-1.0, 0.0), Vector2.ONE * 0.0001)

func test_half_way_out_is_gentler_than_half():
	# The curve aims finely near the centre.
	var s := PilotStick.new()
	var r := PilotStick.DEADZONE + (PilotStick.RADIUS - PilotStick.DEADZONE) * 0.5
	s.move(Vector2(0.0, -r * H), H)
	assert_almost_eq(s.command().x, pow(0.5, PilotStick.CURVE), 0.0001)
	assert_lt(s.command().x, 0.5)

func test_the_same_travel_in_one_event_or_ten_is_the_same_command():
	var once := PilotStick.new()
	once.move(Vector2(40.0, -60.0), H)
	var tenfold := PilotStick.new()
	for i in 10:
		tenfold.move(Vector2(4.0, -6.0), H)
	assert_almost_eq(tenfold.command(), once.command(), Vector2.ONE * 0.0001)

func test_it_feels_the_same_at_any_resolution():
	var small := PilotStick.new()
	small.move(Vector2(0.0, -72.0), 720.0)
	var big := PilotStick.new()
	big.move(Vector2(0.0, -144.0), 1440.0)
	assert_almost_eq(big.command(), small.command(), Vector2.ONE * 0.0001)

func test_the_stick_stays_where_you_leave_it():
	var s := PilotStick.new()
	s.move(Vector2(30.0, 0.0), H)
	var before := s.command()
	s.move(Vector2.ZERO, H)
	assert_eq(s.command(), before)

func test_centre_brings_it_home():
	var s := PilotStick.new()
	s.move(Vector2(50.0, 50.0), H)
	s.centre()
	assert_eq(s.offset, Vector2.ZERO)
	assert_eq(s.command(), Vector2.ZERO)

func test_a_zero_height_viewport_is_ignored():
	var s := PilotStick.new()
	s.move(Vector2(50.0, 50.0), 0.0)
	assert_eq(s.offset, Vector2.ZERO)
```

- [ ] **Step 2: Run to see it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_pilot_stick'`
Expected: FAIL. `PilotStick` is not declared.

- [ ] **Step 3: Implement**

`who-knows/src/flight/pilot_stick.gd`:

```gdscript
class_name PilotStick
extends RefCounted

## The virtual stick (docs/superpowers/specs/2026-09-25-flight-controls-design.md
## §4.1). The mouse moves a cursor away from the centre of view and it stays
## where you leave it; how far out it sits is the turn you ask for. The command
## comes from the cursor's position, never from one frame's mouse delta, so the
## same mouse travel gives the same turn at any frame rate. That delta was the
## old steering, and it stopped the moment the mouse did.

## Full deflection, as a fraction of the viewport's height.
const RADIUS := 0.2
## Inside this the stick asks for nothing.
const DEADZONE := 0.02
## Past the dead zone the command is its share of the travel to this power, so
## small movements aim finely.
const CURVE := 1.5

## The cursor's offset from the centre of view, in fractions of the viewport's
## height, screen axes (+x right, +y down).
var offset := Vector2.ZERO

## Moves the cursor by `pixels` of mouse travel, clamped to full deflection.
func move(pixels: Vector2, viewport_height: float) -> void:
	if viewport_height <= 0.0:
		return
	offset = (offset + pixels / viewport_height).limit_length(RADIUS)

func centre() -> void:
	offset = Vector2.ZERO

## True inside the dead zone.
func is_centred() -> bool:
	return offset.length() <= DEADZONE

## (pitch, yaw), each -1..1: up is nose up, left is yaw left, matching the
## right-handed torques about the hull's own X and Y.
func command() -> Vector2:
	var r := offset.length()
	if r <= DEADZONE:
		return Vector2.ZERO
	var d := offset / r * pow((r - DEADZONE) / (RADIUS - DEADZONE), CURVE)
	return Vector2(-d.y, -d.x)
```

- [ ] **Step 4: Import pass, then run to see it pass**

Run the import pass (Global Constraints), then `& .\who-knows\run_tests.ps1 '-gselect=test_pilot_stick'`
Expected: PASS (11 tests).

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/flight/pilot_stick.gd who-knows/src/flight/pilot_stick.gd.uid who-knows/test/unit/test_pilot_stick.gd who-knows/test/unit/test_pilot_stick.gd.uid
git commit -m "feat: a virtual stick that holds a steady turn

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(If the import pass made no `.uid` files, leave them out of `git add`.)

---

### Task 3: Drift, the speed lock and the commanded push

**Files:**
- Modify: `who-knows/src/flight/flight_computer.gd`
- Test: `who-knows/test/unit/test_flight_computer.gd`

**Interfaces:**
- Produces, on `FlightComputer`:
  - `const DRIFT_AUTHORITY := 1.0`;
  - `var assist_enabled` with a setter: turning it off clears `speed_locked`;
  - `var speed_locked: bool`, `var locked_speed: float` (m/s, signed, forward positive);
  - `var commanded_force_local: Vector3` (this tick's push in hull axes, N);
  - `toggle_speed_lock() -> void` (needs assist);
  - `forward_speed() -> float`;
  - `static translation_force(local_velocity: Vector3, input: Vector3, mass: float,
    budget: Dictionary, boost: bool, assist: bool, locked: bool, locked_speed: float) -> Vector3`.

- [ ] **Step 1: Write the failing tests**

Append to `test_flight_computer.gd` (after the existing tests; the file's `before_each` builds
`_hull` and `_fc`):

```gdscript
## Translation (flight controls spec §5.3, §5.4).

const MASS := 92_300.0
const THRUST := {
	&"forward": 1_500_000.0, &"reverse": 500_000.0,
	&"lateral": 500_000.0, &"vertical": 1_000_000.0,
}

func _push(local_velocity: Vector3, input: Vector3, locked := false, locked_speed := 0.0,
		assist := true) -> Vector3:
	return FlightComputer.translation_force(local_velocity, input, MASS, THRUST, false, assist,
		locked, locked_speed)

func test_drift_is_fought_with_the_whole_side_budget():
	# 40 m/s sideways wants far more than the budget; assist spends all of it.
	var f := _push(Vector3(40.0, 0.0, 0.0), Vector3.ZERO)
	assert_almost_eq(f.x, -THRUST[&"lateral"], 1.0)

func test_small_drift_is_cancelled_in_about_a_second():
	var f := _push(Vector3(0.0, 2.0, 0.0), Vector3.ZERO)
	assert_almost_eq(f.y, -2.0 * MASS, 1.0)

func test_letting_go_brakes_with_the_retros():
	var f := _push(Vector3(0.0, 0.0, -50.0), Vector3.ZERO)
	assert_almost_eq(f.z, THRUST[&"reverse"], 1.0)

func test_catching_up_to_a_lock_uses_the_main_engines():
	# Locked at 50, going 10: the push forward (-z) is the engines', not the
	# retros'. It used to be clamped by the retros both ways.
	var f := _push(Vector3(0.0, 0.0, -10.0), Vector3.ZERO, true, 50.0)
	assert_almost_eq(f.z, -THRUST[&"forward"], 1.0)

func test_a_lock_holds_its_speed():
	assert_almost_eq(_push(Vector3(0.0, 0.0, -50.0), Vector3.ZERO, true, 50.0).z, 0.0, 0.01)

func test_a_lock_slows_you_to_it():
	assert_gt(_push(Vector3(0.0, 0.0, -60.0), Vector3.ZERO, true, 50.0).z, 0.0, "pushes aft")

func test_thrusting_is_not_fought_on_its_own_axis():
	var f := _push(Vector3(0.0, 0.0, -50.0), Vector3(0.0, 0.0, -1.0))
	assert_almost_eq(f.z, -THRUST[&"forward"], 1.0)

func test_assist_off_is_the_stick_alone():
	var f := _push(Vector3(30.0, 5.0, -50.0), Vector3(0.0, 0.0, -0.5), true, 10.0, false)
	assert_almost_eq(f, Vector3(0.0, 0.0, -0.5 * THRUST[&"forward"]), Vector3.ONE * 1.0)

func test_boost_multiplies_the_pilots_push():
	var f := FlightComputer.translation_force(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), MASS, THRUST,
		true, true, false, 0.0)
	assert_almost_eq(f.x, THRUST[&"lateral"] * FlightComputer.BOOST_MULTIPLIER, 1.0)

func test_the_lock_takes_your_forward_speed():
	_hull.linear_velocity = Vector3(3.0, 0.0, -40.0)
	_fc.toggle_speed_lock()
	assert_true(_fc.speed_locked)
	assert_almost_eq(_fc.locked_speed, 40.0, 0.001)
	_fc.toggle_speed_lock()
	assert_false(_fc.speed_locked, "pressing again unlocks")

func test_the_lock_follows_the_throttle_while_it_is_held():
	_hull.linear_velocity = Vector3(0.0, 0.0, -40.0)
	_fc.toggle_speed_lock()
	_hull.linear_velocity = Vector3(0.0, 0.0, -55.0)
	_fc.set_pilot_input(Vector3(0.0, 0.0, -1.0), Vector3.ZERO, false)
	_fc._physics_process(1.0 / 60.0)
	assert_almost_eq(_fc.locked_speed, 55.0, 0.001)

func test_the_lock_needs_assist():
	_fc.assist_enabled = false
	_fc.toggle_speed_lock()
	assert_false(_fc.speed_locked)

func test_turning_assist_off_unlocks():
	_fc.toggle_speed_lock()
	_fc.assist_enabled = false
	assert_false(_fc.speed_locked)

func test_the_commanded_push_is_kept_in_hull_axes():
	_fc.set_pilot_input(Vector3(1.0, 0.0, 0.0), Vector3.ZERO, false)
	_fc._physics_process(1.0 / 60.0)
	assert_almost_eq(_fc.commanded_force_local.x, _fc.thrust_budget[&"lateral"], 1.0)
```

- [ ] **Step 2: Run to see them fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_flight_computer'`
Expected: FAIL. `translation_force`, `toggle_speed_lock` and the new vars do not exist.

- [ ] **Step 3: Implement**

In `flight_computer.gd`:

(a) Replace the header comment's second paragraph and the `DRIFT_AUTHORITY` line:

```gdscript
## Assist on: counters drift, damps residual rotation, holds a cruise ceiling,
## and can lock a speed or hold a heading (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §5). Assist off: raw Newtonian, input
## maps straight to thrust.

const CRUISE_LIMIT_MPS := 120.0
const BOOST_MULTIPLIER := 2.5
## Fraction of the budget assist may spend on velocity nobody asked for: all
## of it, so after a turn your travel swings onto the nose in seconds (spec
## §5.4). At 0.6 the shuttle slid the old way for half a minute after a turn.
const DRIFT_AUTHORITY := 1.0
```

(b) Replace `var assist_enabled: bool = true` with:

```gdscript
## Turning assist off drops everything that needs it.
var assist_enabled: bool = true:
	set(on):
		assist_enabled = on
		if not on:
			speed_locked = false

## The speed lock (spec §5.3): a forward speed, m/s, that assist holds while W
## and S are released. Signed, so a backward drift locks backward.
var speed_locked := false
var locked_speed := 0.0
## This tick's push, after boost and assist, in the hull's own axes, newtons.
## RcsShow reads it to show which thrusters are doing it.
var commanded_force_local := Vector3.ZERO
```

(c) After `clear_pilot_input()`, add:

```gdscript
## Locks the hull's forward speed as it is now, or unlocks. Needs assist.
func toggle_speed_lock() -> void:
	if speed_locked:
		speed_locked = false
	elif assist_enabled:
		speed_locked = true
		locked_speed = forward_speed()

## Speed out of the nose, m/s: negative when drifting backward.
func forward_speed() -> float:
	return -(_hull.global_transform.basis.inverse() * _hull.linear_velocity).z
```

(d) Replace `_apply_translation` and `_drift_correction` (the whole of both functions) with:

```gdscript
func _apply_translation(_delta: float) -> void:
	var basis := _hull.global_transform.basis
	var local_velocity := basis.inverse() * _hull.linear_velocity
	# While locked, W or S moves the lock: letting go holds the new speed.
	if speed_locked and not is_zero_approx(_translate_input.z):
		locked_speed = clampf(-local_velocity.z, -CRUISE_LIMIT_MPS, CRUISE_LIMIT_MPS)
	commanded_force_local = translation_force(local_velocity, _translate_input, _hull.mass,
		thrust_budget, _boost, assist_enabled, speed_locked, locked_speed)
	_hull.apply_central_force(basis * commanded_force_local)

	if assist_enabled and _hull.linear_velocity.length() > CRUISE_LIMIT_MPS:
		_hull.linear_velocity = _hull.linear_velocity.normalized() * CRUISE_LIMIT_MPS

## The push along the hull's own axes, newtons (spec §5.3, §5.4). Pure, so
## drift and the speed lock are tested without physics.
##
## The pilot's input spends the budget along each axis, boosted if asked. With
## assist on, every axis the pilot is not pushing on also cancels velocity
## nobody asked for -- toward the locked speed fore and aft, when locked --
## at up to DRIFT_AUTHORITY of that axis's budget. Fore and aft, a push forward
## (-z) is the main engines' and a push aft the retros', each clamped by its
## own budget.
static func translation_force(local_velocity: Vector3, input: Vector3, mass: float,
		budget: Dictionary, boost: bool, assist: bool, locked: bool,
		locked_speed: float) -> Vector3:
	var forward: float = budget[&"forward"]
	var reverse: float = budget[&"reverse"]
	var lateral: float = budget[&"lateral"]
	var vertical: float = budget[&"vertical"]
	var force := Vector3(
		input.x * lateral,
		input.y * vertical,
		input.z * (forward if input.z < 0.0 else reverse),
	)
	if boost:
		force *= BOOST_MULTIPLIER
	if not assist:
		return force
	var target_z := -locked_speed if locked else 0.0
	var wanted := Vector3(
		-local_velocity.x if is_zero_approx(input.x) else 0.0,
		-local_velocity.y if is_zero_approx(input.y) else 0.0,
		target_z - local_velocity.z if is_zero_approx(input.z) else 0.0,
	) * mass
	return force + Vector3(
		clampf(wanted.x, -lateral * DRIFT_AUTHORITY, lateral * DRIFT_AUTHORITY),
		clampf(wanted.y, -vertical * DRIFT_AUTHORITY, vertical * DRIFT_AUTHORITY),
		clampf(wanted.z, -forward * DRIFT_AUTHORITY, reverse * DRIFT_AUTHORITY),
	)
```

- [ ] **Step 4: Run to see them pass**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_flight_computer'` then the whole suite.
Expected: PASS, including the seven existing attitude tests.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/flight/flight_computer.gd who-knows/test/unit/test_flight_computer.gd
git commit -m "feat: assist spends all the side thrust on drift, and a speed lock

The fore-and-aft correction is now clamped by the main engines forward and
the retros aft; it was clamped by the retros both ways.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Heading hold, the commanded twist, and the telemetry

**Files:**
- Modify: `who-knows/src/flight/flight_computer.gd`
- Modify: `who-knows/src/ui/vehicle_telemetry.gd`
- Test: `who-knows/test/unit/test_flight_computer.gd`, `who-knows/test/unit/test_vehicle_telemetry.gd`

**Interfaces:**
- Consumes: Task 3's `assist_enabled` setter, `speed_locked`, `locked_speed`.
- Produces, on `FlightComputer`:
  - `const HOLD_BRAKE_SHARE := 0.6`, `const HOLD_GAIN := 2.0`;
  - `var heading_hold: bool`, `var heading: Vector3` (world, unit);
  - `var commanded_torque_local: Vector3`;
  - `set_heading(direction: Vector3) -> void` (needs assist), `clear_heading() -> void`;
  - `static heading_rate(target_local: Vector3, budget: Vector3, moment: Vector3) -> Vector3`;
  - the assist setter also clears `heading_hold`.
- Produces, on `VehicleTelemetry`, all defaulting off or zero:
  - `heading_hold: bool`, `heading: Vector3`, `speed_locked: bool`, `locked_speed: float`;
  - `stick: Vector2`, `stick_radius: float`, `stick_deadzone: float`;
  - `pointing: bool`, `pointer: Vector2`.

- [ ] **Step 1: Write the failing tests**

Append to `test_flight_computer.gd`:

```gdscript
## Heading hold (flight controls spec §5.2).

func test_a_target_above_asks_for_nose_up():
	var rate := FlightComputer.heading_rate(Vector3(0.0, 0.5, -1.0), BUDGET, INERTIA)
	assert_gt(rate.x, 0.0)
	assert_almost_eq(rate.y, 0.0, 0.0001)
	assert_eq(rate.z, 0.0, "roll stays with the pilot")

func test_a_target_to_the_left_asks_for_yaw_left():
	var rate := FlightComputer.heading_rate(Vector3(-0.5, 0.0, -1.0), BUDGET, INERTIA)
	assert_gt(rate.y, 0.0)
	assert_almost_eq(rate.x, 0.0, 0.0001)

func test_below_and_right_are_the_other_ways():
	assert_lt(FlightComputer.heading_rate(Vector3(0.0, -0.5, -1.0), BUDGET, INERTIA).x, 0.0)
	assert_lt(FlightComputer.heading_rate(Vector3(0.5, 0.0, -1.0), BUDGET, INERTIA).y, 0.0)

func test_on_target_asks_for_nothing():
	assert_eq(FlightComputer.heading_rate(Vector3.FORWARD, BUDGET, INERTIA), Vector3.ZERO)

func test_a_far_target_is_capped_at_the_turn_rate():
	var rate := FlightComputer.heading_rate(Vector3.LEFT, BUDGET, INERTIA)
	assert_almost_eq(rate.length(), FlightComputer.ASSIST_TURN_RATE, 0.0001)

func test_dead_astern_pitches_round():
	var rate := FlightComputer.heading_rate(Vector3.BACK, BUDGET, INERTIA)
	assert_gt(absf(rate.x), 0.0)
	assert_almost_eq(rate.y, 0.0, 0.0001)

## Swings the shuttle's nose onto a target the way the hull would: the hold's
## rate through attitude_torque, integrated at 60 Hz. Returns [seconds until
## within 0.5 deg, worst error after that in degrees].
func _swing(degrees: float) -> Array:
	var target := Basis(Vector3(0.3, 1.0, 0.1).normalized(), deg_to_rad(degrees)) * Vector3.FORWARD
	var basis := Basis.IDENTITY
	var spin := Vector3.ZERO
	var dt := 1.0 / 60.0
	var reached_at := -1.0
	var worst := 0.0
	for i in 60 * 8:
		var rate := FlightComputer.heading_rate(basis.inverse() * target, BUDGET, INERTIA)
		var torque := _fc.attitude_torque(
			Vector3(rate.x, rate.y, 0.0) / FlightComputer.ASSIST_TURN_RATE, spin)
		spin += torque / INERTIA * dt
		if not spin.is_zero_approx():
			basis = (basis * Basis(spin.normalized(), spin.length() * dt)).orthonormalized()
		var error := rad_to_deg((basis * Vector3.FORWARD).angle_to(target))
		if reached_at < 0.0 and error < 0.5:
			reached_at = i * dt
		if reached_at >= 0.0:
			worst = maxf(worst, error)
	return [reached_at, worst]

func test_the_hold_swings_on_without_overshooting():
	# Simulated before this was written: HOLD_GAIN 3 overshot a 120 deg swing
	# by 2.0 deg; 2 overshoots by at most 1.2 deg and settles in under 4 s.
	for degrees in [30.0, 90.0, 170.0]:
		var result := _swing(degrees)
		assert_between(result[0], 0.0, 5.0, "%d deg reached within 5 s" % degrees)
		assert_lt(result[1], 2.0, "%d deg never overshoots by 2 deg" % degrees)

func test_a_heading_needs_assist():
	_fc.assist_enabled = false
	_fc.set_heading(Vector3.LEFT)
	assert_false(_fc.heading_hold)

func test_turning_assist_off_drops_the_heading():
	_fc.set_heading(Vector3.LEFT)
	assert_true(_fc.heading_hold)
	_fc.assist_enabled = false
	assert_false(_fc.heading_hold)

func test_clearing_the_heading_hands_the_ship_back():
	_fc.set_heading(Vector3.LEFT)
	_fc.clear_heading()
	assert_false(_fc.heading_hold)

func test_holding_a_heading_to_the_left_yaws_left():
	_fc.set_heading(Vector3.LEFT)
	_fc._physics_process(1.0 / 60.0)
	assert_gt(_fc.commanded_torque_local.y, 0.0)
	assert_almost_eq(_fc.commanded_torque_local.x, 0.0, 1.0)

func test_roll_stays_with_the_pilot_during_a_hold():
	_fc.set_heading(Vector3.LEFT)
	_fc.set_pilot_input(Vector3.ZERO, Vector3(0.0, 0.0, 1.0), false)
	_fc._physics_process(1.0 / 60.0)
	assert_gt(_fc.commanded_torque_local.z, 0.0)

func test_the_telemetry_carries_the_hold_and_the_lock():
	_fc.set_heading(Vector3.LEFT)
	_hull.linear_velocity = Vector3(0.0, 0.0, -30.0)
	_fc.toggle_speed_lock()
	var t := _fc.build_telemetry()
	assert_true(t.heading_hold)
	assert_almost_eq(t.heading, Vector3.LEFT, Vector3.ONE * 0.0001)
	assert_true(t.speed_locked)
	assert_almost_eq(t.locked_speed, 30.0, 0.001)
```

Append to `test_vehicle_telemetry.gd`:

```gdscript
## Flight controls spec §5.5, §7: anything that holds nothing reports nothing.
func test_holds_and_the_stick_start_off():
	var t := VehicleTelemetry.from_state(Basis.IDENTITY, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
		true, false, 120.0)
	assert_false(t.heading_hold)
	assert_false(t.speed_locked)
	assert_eq(t.locked_speed, 0.0)
	assert_false(t.pointing)
	assert_eq(t.stick, Vector2.ZERO)
	assert_eq(t.pointer, Vector2.ZERO)
```

- [ ] **Step 2: Run to see them fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_flight_computer'` and `'-gselect=test_vehicle_telemetry'`
Expected: FAIL. `heading_rate`, `set_heading` and the telemetry fields do not exist.

- [ ] **Step 3: Implement `VehicleTelemetry`**

After `var beacon: Vector3 = Vector3.ZERO`, add:

```gdscript
## What the flight computer is holding (flight controls spec §5.5). Set after
## from_state(); off for anything that holds nothing, like the suit.
var heading_hold: bool = false
## World direction, unit length.
var heading: Vector3 = Vector3.FORWARD
var speed_locked: bool = false
var locked_speed: float = 0.0
## The pilot's hands (spec §7), set by PilotControls. The virtual stick's
## offset from the centre of view, and the point-mode pointer's, both in
## fractions of the viewport's height, +y down; the stick's full-deflection
## radius and dead zone in the same units.
var stick: Vector2 = Vector2.ZERO
var stick_radius: float = 0.0
var stick_deadzone: float = 0.0
var pointing: bool = false
var pointer: Vector2 = Vector2.ZERO
```

- [ ] **Step 4: Implement `FlightComputer`**

(a) After `const RATE_GAIN := 4.0`, add:

```gdscript
## Heading hold (spec §5.2): the share of the weaker turning axis's angular
## acceleration it plans to brake with, leaving the rate loop some spare.
const HOLD_BRAKE_SHARE := 0.6
## Heading hold's turn rate per radian of error near the target, 1/s. It keeps
## the braking curve from chattering at the end. Simulated on the shuttle, 3
## overshot a 120 deg swing by 2.0 deg; 2 overshoots by at most 1.2 deg.
const HOLD_GAIN := 2.0
```

(b) In the `assist_enabled` setter, clear the hold too:

```gdscript
var assist_enabled: bool = true:
	set(on):
		assist_enabled = on
		if not on:
			speed_locked = false
			heading_hold = false
```

(c) After `var commanded_force_local := Vector3.ZERO`, add:

```gdscript
## Heading hold (spec §5.2): the world direction the nose is swung onto and
## held on. A direction, not a position, so the floating origin never moves it.
var heading_hold := false
var heading := Vector3.FORWARD
## This tick's twist, after clamping, in the hull's own axes, newton-metres.
## RcsShow reads it.
var commanded_torque_local := Vector3.ZERO
```

(d) After `forward_speed()`, add:

```gdscript
## Swings the nose onto `direction` (world) and holds it there. Needs assist.
func set_heading(direction: Vector3) -> void:
	if not assist_enabled or direction.is_zero_approx():
		return
	heading = direction.normalized()
	heading_hold = true

## Hands pitch and yaw back to the pilot.
func clear_heading() -> void:
	heading_hold = false
```

(e) Replace `_apply_rotation` with:

```gdscript
func _apply_rotation(_delta: float) -> void:
	var basis := _hull.global_transform.basis
	var local_spin := basis.inverse() * _hull.angular_velocity
	var rotate := _rotate_input
	if heading_hold:
		# The hold flies pitch and yaw as a stick would; roll stays the pilot's.
		var rate := heading_rate(basis.inverse() * heading, torque_budget, inertia)
		rotate = Vector3(rate.x / ASSIST_TURN_RATE, rate.y / ASSIST_TURN_RATE, _rotate_input.z)
	commanded_torque_local = attitude_torque(rotate, local_spin)
	_hull.apply_torque(basis * commanded_torque_local)
```

(f) After `attitude_torque`, add:

```gdscript
## The (pitch, yaw) turn rate, rad/s, that swings the nose (-Z) onto
## `target_local`, a direction in the hull's own axes (spec §5.2). Pure.
##
## The turn is about (-Z) x target, which never has a roll part, by the angle
## between them. The rate is the fastest the RCS can still brake from in time
## -- sqrt(2 * share * alpha * angle), alpha being the weaker of pitch and
## yaw's torque over inertia -- capped at the ordinary turn rate, and linear
## near the end so it settles instead of chattering. Dead astern, it pitches.
static func heading_rate(target_local: Vector3, budget: Vector3, moment: Vector3) -> Vector3:
	var target := target_local.normalized()
	var angle := Vector3.FORWARD.angle_to(target)
	if angle < 0.0001:
		return Vector3.ZERO
	var axis := Vector3.FORWARD.cross(target)
	if axis.length() < 0.0001:
		axis = Vector3.RIGHT
	axis = Vector3(axis.x, axis.y, 0.0).normalized()
	var alpha := minf(budget.x / maxf(moment.x, 1.0), budget.y / maxf(moment.y, 1.0))
	var rate := minf(ASSIST_TURN_RATE,
		minf(sqrt(2.0 * HOLD_BRAKE_SHARE * alpha * angle), HOLD_GAIN * angle))
	return axis * rate
```

(g) Replace `build_telemetry()` with:

```gdscript
func build_telemetry() -> VehicleTelemetry:
	var t := VehicleTelemetry.from_state(
		_hull.global_transform.basis,
		_hull.global_position,
		_hull.linear_velocity,
		_hull.angular_velocity,
		assist_enabled,
		_boost,
		CRUISE_LIMIT_MPS
	)
	t.heading_hold = heading_hold
	t.heading = heading
	t.speed_locked = speed_locked
	t.locked_speed = locked_speed
	return t
```

Keep `build_telemetry`'s existing doc comment above it.

- [ ] **Step 5: Run to see them pass, then the suite**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_flight_computer'`, `'-gselect=test_vehicle_telemetry'`, then everything.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/flight/flight_computer.gd who-knows/src/ui/vehicle_telemetry.gd who-knows/test/unit/test_flight_computer.gd who-knows/test/unit/test_vehicle_telemetry.gd
git commit -m "feat: heading hold -- swing the nose onto a direction and hold it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: PilotControls — the pilot's hands

**Files:**
- Create: `who-knows/src/flight/pilot_controls.gd`
- Modify: `who-knows/src/camera/camera_director.gd`
- Modify: `who-knows/scenes/flight_test.tscn`, `who-knows/scenes/flight_test.gd`
- Test: `who-knows/test/unit/test_pilot_controls.gd` (new), `who-knows/test/unit/test_hud_scene_wiring.gd`

**Interfaces:**
- Consumes:
  - `PilotStick` (Task 2);
  - the new input actions (Task 1);
  - `FlightComputer.set_pilot_input`, `set_heading`, `clear_heading`, `toggle_speed_lock`,
    `assist_enabled`, `build_telemetry`, `CRUISE_LIMIT_MPS` (Tasks 3–4);
  - `CameraDirector.piloting_changed(piloting: bool)`.
- Produces: `class_name PilotControls extends Node`:
  - exports `flight_computer_path`, `camera_director_path`, `hull_path`, `interior_path`;
  - `var stick: PilotStick`, `var seated: bool`, `var pointing: bool`, `var pointer: Vector2`;
  - `set_seated(on: bool) -> void`;
  - `handle(event: InputEvent) -> void`, the testable seam;
  - `pointer_direction(cam: Camera3D = null) -> Vector3`;
  - `build_telemetry() -> VehicleTelemetry`.
- The scene node is `Ship/PilotControls`.

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_pilot_controls.gd`:

```gdscript
extends GutTest

## The pilot's hands (flight controls spec §4, §7), in the real flight scene.
## handle() is driven directly: a headless run cannot capture the mouse.

var _root: Node
var _pilot: PilotControls
var _fc: FlightComputer
var _hull: RigidBody3D
var _interior: Node3D

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_pilot = _root.get_node("Ship/PilotControls")
	_fc = _root.get_node("Ship/FlightComputer")
	_hull = _root.get_node("Ship/Exterior")
	_interior = _root.get_node("Ship/Interior")
	_pilot.set_seated(true)

func after_each():
	for action in [&"pitch_up", &"roll_left"]:
		Input.action_release(action)

func _action(action: StringName, pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	return ev

func _motion(relative: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	return ev

func test_sitting_down_seats_the_controls():
	_pilot.set_seated(false)
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_true(_pilot.seated)

func test_while_seated_your_hands_do_nothing():
	# RMB and LMB fly the ship while you sit (spec §4): Grasp must be off.
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_false(avatar.grasp.enabled)

func test_the_mouse_moves_the_stick():
	_pilot.handle(_motion(Vector2(0.0, -40.0)))
	assert_lt(_pilot.stick.offset.y, 0.0)
	assert_gt(_pilot.stick.command().x, 0.0, "up is nose up")

func test_standing_up_centres_the_stick():
	_pilot.handle(_motion(Vector2(60.0, 0.0)))
	_pilot.set_seated(false)
	assert_eq(_pilot.stick.offset, Vector2.ZERO)

func test_point_mode_lets_go_of_the_stick_and_moves_a_pointer():
	_pilot.handle(_motion(Vector2(60.0, 0.0)))
	_pilot.handle(_action(&"point_mode", true))
	assert_true(_pilot.pointing)
	assert_eq(_pilot.stick.offset, Vector2.ZERO, "the stick lets go")
	_pilot.handle(_motion(Vector2(30.0, 0.0)))
	assert_gt(_pilot.pointer.x, 0.0)
	assert_eq(_pilot.stick.offset, Vector2.ZERO, "the mouse moves the pointer, not the stick")
	_pilot.handle(_action(&"point_mode", false))
	assert_false(_pilot.pointing)
	assert_eq(_pilot.stick.offset, Vector2.ZERO, "back to a centred stick")

func test_a_click_in_point_mode_sets_the_heading():
	_pilot.handle(_action(&"point_mode", true))
	_pilot.handle(_action(&"set_heading", true))
	assert_true(_fc.heading_hold)

func test_a_click_outside_point_mode_does_nothing():
	_pilot.handle(_action(&"set_heading", true))
	assert_false(_fc.heading_hold)

func test_the_pointer_at_the_centre_is_the_nose():
	# A camera aboard, facing the way the seat does: the centre of view is the
	# hull's nose, wherever the hull points.
	var cam := Camera3D.new()
	_interior.add_child(cam)
	_hull.global_basis = Basis(Vector3.UP, deg_to_rad(90.0))
	var dir := _pilot.pointer_direction(cam)
	assert_almost_eq(dir, _hull.global_basis * Vector3.FORWARD, Vector3.ONE * 0.001)
	cam.free()

func test_the_pointer_above_centre_looks_above_the_nose():
	var cam := Camera3D.new()
	_interior.add_child(cam)
	_pilot.pointer = Vector2(0.0, -0.2)
	var dir := _pilot.pointer_direction(cam)
	assert_gt(dir.dot(_hull.global_basis * Vector3.UP), 0.1)
	cam.free()

func test_outside_the_pointer_is_the_cameras_own_ray():
	var cam := Camera3D.new()
	_hull.add_child(cam)
	_hull.global_basis = Basis(Vector3.UP, deg_to_rad(90.0))
	var centre := cam.get_viewport().get_visible_rect().size * 0.5
	assert_almost_eq(_pilot.pointer_direction(cam), cam.project_ray_normal(centre),
		Vector3.ONE * 0.001)
	cam.free()

func test_flying_by_hand_takes_the_ship_back_from_a_hold():
	_fc.set_heading(Vector3.LEFT)
	Input.action_press(&"pitch_up")
	_pilot._process(0.016)
	assert_false(_fc.heading_hold)

func test_moving_the_stick_out_takes_the_ship_back_too():
	_fc.set_heading(Vector3.LEFT)
	_pilot.handle(_motion(Vector2(0.0, -100.0)))
	_pilot._process(0.016)
	assert_false(_fc.heading_hold)

func test_rolling_keeps_the_hold():
	_fc.set_heading(Vector3.LEFT)
	Input.action_press(&"roll_left")
	_pilot._process(0.016)
	assert_true(_fc.heading_hold)

func test_c_locks_the_speed():
	_hull.linear_velocity = Vector3(0.0, 0.0, -20.0)
	_pilot.handle(_action(&"speed_lock", true))
	assert_true(_fc.speed_locked)

func test_z_toggles_assist_and_drops_the_lock():
	_pilot.handle(_action(&"speed_lock", true))
	_pilot.handle(_action(&"toggle_assist", true))
	assert_false(_fc.assist_enabled)
	assert_false(_fc.speed_locked)

func test_nothing_happens_standing_up():
	_pilot.set_seated(false)
	_pilot.handle(_action(&"speed_lock", true))
	assert_false(_fc.speed_locked)

func test_the_hud_sees_the_stick_and_the_pointer():
	_pilot.handle(_motion(Vector2(30.0, 0.0)))
	var t := _pilot.build_telemetry()
	assert_eq(t.stick, _pilot.stick.offset)
	assert_almost_eq(t.stick_radius, PilotStick.RADIUS, 0.0001)
	assert_almost_eq(t.stick_deadzone, PilotStick.DEADZONE, 0.0001)
	assert_false(t.pointing)
	assert_almost_eq(t.cruise_limit, FlightComputer.CRUISE_LIMIT_MPS, 0.001,
		"and the flight computer's own readings")
```

Append to `test_hud_scene_wiring.gd`:

```gdscript
## Flight controls spec §3, §7: the pilot's controls, read back at runtime.
func test_pilot_controls_survived_the_parse():
	var pilot: PilotControls = _root.get_node_or_null("Ship/PilotControls")
	assert_not_null(pilot, "PilotControls present")
	for path in [pilot.flight_computer_path, pilot.camera_director_path, pilot.hull_path,
			pilot.interior_path]:
		assert_ne(path, NodePath(""), "no export was dropped")
		assert_not_null(pilot.get_node_or_null(path), "%s resolves" % path)

func test_sitting_down_hands_the_hud_to_the_pilot():
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	var hud: HudRoot = _root.get_node("HudRoot")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_same(hud._source, _root.get_node("Ship/PilotControls"))
```

- [ ] **Step 2: Run to see them fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_pilot_controls'`
Expected: FAIL. There is no `Ship/PilotControls` node and no `PilotControls` class.

- [ ] **Step 3: Implement `PilotControls`**

`who-knows/src/flight/pilot_controls.gd`:

```gdscript
class_name PilotControls
extends Node

## The pilot's hands on the ship (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §4, §7): the virtual stick and the
## arrow keys, point mode and the heading click, the speed lock and the assist
## toggle, turned into FlightComputer calls. While you sit it is the HUD's
## vehicle: its telemetry is the flight computer's, plus the stick and the
## pointer.

@export var flight_computer_path: NodePath
@export var camera_director_path: NodePath
@export var hull_path: NodePath
@export var interior_path: NodePath

var stick := PilotStick.new()
var seated := false
## Point mode (spec §4.2): the mouse moves a free pointer instead of the stick.
var pointing := false
## The pointer's offset from the centre of view, in fractions of the
## viewport's height, +y down.
var pointer := Vector2.ZERO

@onready var _flight: FlightComputer = get_node(flight_computer_path)
@onready var _hull: Node3D = get_node(hull_path)
@onready var _interior: Node3D = get_node(interior_path)

func _ready() -> void:
	var director: CameraDirector = get_node(camera_director_path)
	director.piloting_changed.connect(set_seated)

## Sitting down or standing up: the stick centres and point mode ends. A
## heading hold or a speed lock keeps running (spec §4.2).
func set_seated(on: bool) -> void:
	seated = on
	stick.centre()
	pointing = false
	pointer = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		handle(event)

## One input event, while seated. Split from _unhandled_input so tests can
## drive it: a headless run cannot capture the mouse.
func handle(event: InputEvent) -> void:
	if not seated:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var view := _view_size()
		if view.y <= 0.0:
			return
		if pointing:
			var half := Vector2(view.x / view.y * 0.5, 0.5)
			pointer = (pointer + motion.relative / view.y).clamp(-half, half)
		else:
			stick.move(motion.relative, view.y)
	elif event.is_action_pressed(&"point_mode"):
		pointing = true
		pointer = Vector2.ZERO
		stick.centre()
	elif event.is_action_released(&"point_mode"):
		# Back to the stick, centred, so the ship does not lurch.
		pointing = false
		stick.centre()
	elif event.is_action_pressed(&"set_heading"):
		if pointing:
			_flight.set_heading(pointer_direction())
	elif event.is_action_pressed(&"speed_lock"):
		_flight.toggle_speed_lock()
	elif event.is_action_pressed(&"toggle_assist"):
		_flight.assist_enabled = not _flight.assist_enabled

func _process(_delta: float) -> void:
	if not seated:
		return
	var keys := Vector2(
		Input.get_axis(&"pitch_down", &"pitch_up"),
		Input.get_axis(&"yaw_right", &"yaw_left"),
	)
	# Flying by hand takes the ship back from a heading hold (spec §4.2). Roll
	# does not: it turns about the nose and leaves the heading alone.
	if not stick.is_centred() or not keys.is_zero_approx():
		_flight.clear_heading()
	var steer := (stick.command() + keys).clamp(-Vector2.ONE, Vector2.ONE)
	var translate := Vector3(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"crouch", &"sprint"),
		Input.get_axis(&"move_forward", &"move_back"),
	)
	var rotate := Vector3(steer.x, steer.y, Input.get_axis(&"roll_left", &"roll_right"))
	_flight.set_pilot_input(translate, rotate, Input.is_action_pressed(&"boost"))

## The world direction under the pointer (spec §4.2), seen through `cam`, or
## the camera you see through. Aboard, that camera is in interior space, which
## never moves and maps one to one onto the hull's axes. The canopy is a portal
## drawn from the same place with the same field of view, so the pointer lies
## over the same point outside.
func pointer_direction(cam: Camera3D = null) -> Vector3:
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return _hull.global_basis * Vector3.FORWARD
	var view := cam.get_viewport().get_visible_rect().size
	var ray := cam.project_ray_normal(view * 0.5 + pointer * view.y)
	if _interior.is_ancestor_of(cam):
		ray = _hull.global_basis * (_interior.global_basis.inverse() * ray)
	return ray.normalized()

## The flight computer's snapshot plus the pilot's hands, for the HUD.
func build_telemetry() -> VehicleTelemetry:
	var t := _flight.build_telemetry()
	t.stick = stick.offset
	t.stick_radius = PilotStick.RADIUS
	t.stick_deadzone = PilotStick.DEADZONE
	t.pointing = pointing
	t.pointer = pointer
	return t

func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size
```

- [ ] **Step 4: Take the flight input out of `CameraDirector`**

In `camera_director.gd`:
- delete `MOUSE_STEER_SENSITIVITY` and its two-line doc comment;
- delete `var _mouse_delta: Vector2 = Vector2.ZERO`;
- delete the whole `_process` function;
- keep `stand()`'s `_flight.clear_pilot_input()` and the `flight_computer_path` export.

Make `_unhandled_input` read:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_camera"):
		cycle_view()
	elif event.is_action_pressed("interact") and is_seated:
		stand()
```

Add one line to the class doc comment, after its first paragraph:

```gdscript
##
## Seated flying input -- the stick, the keys, point mode -- is PilotControls'
## (flight controls spec §7); this node only says when you sit and stand.
```

- [ ] **Step 5: Add the node to the scene**

In `flight_test.tscn`:

1. Change the header to `[gd_scene load_steps=28 format=3]`.
2. After the last `[ext_resource ...]` line, add:

```
[ext_resource type="Script" path="res://src/flight/pilot_controls.gd" id="22_pilot_controls"]
```

3. After the `MotionCoupling` node block (before `[node name="Outside" ...]`), add, with a blank
   line before and after:

```
[node name="PilotControls" type="Node" parent="Ship"]
script = ExtResource("22_pilot_controls")
flight_computer_path = NodePath("../FlightComputer")
camera_director_path = NodePath("../CameraDirector")
hull_path = NodePath("../Exterior")
interior_path = NodePath("../Interior")
```

No `#` comments anywhere in the file.

- [ ] **Step 6: The HUD reads the pilot while you sit**

In `flight_test.gd`, add below `@onready var _stream`:

```gdscript
@onready var _pilot: PilotControls = $Ship/PilotControls
```

and replace `_on_piloting_changed` with:

```gdscript
## The pilot's controls report the flight computer's telemetry plus the stick
## and the pointer (flight controls spec §7).
func _on_piloting_changed(piloting: bool) -> void:
	_hud.set_active_vehicle(_pilot if piloting else null)
```

- [ ] **Step 7: Import pass, then run to see them pass**

Run the import pass, then `& .\who-knows\run_tests.ps1 '-gselect=test_pilot_controls'`, `'-gselect=test_hud_scene_wiring'`, then everything.
Expected: PASS, including `test_pilot_seat`, `test_avatar_modes` and `test_spacewalk_hud`.

- [ ] **Step 8: Commit**

```bash
git add who-knows/src/flight/pilot_controls.gd who-knows/src/flight/pilot_controls.gd.uid who-knows/src/camera/camera_director.gd who-knows/scenes/flight_test.tscn who-knows/scenes/flight_test.gd who-knows/test/unit/test_pilot_controls.gd who-knows/test/unit/test_pilot_controls.gd.uid who-knows/test/unit/test_hud_scene_wiring.gd
git commit -m "feat: PilotControls -- the stick, the arrow keys, point-and-click heading, C to lock speed

Seated input moves out of CameraDirector.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The shared puff, and the RCS puff sound

**Files:**
- Create: `who-knows/src/world/puffs.gd`
- Modify: `who-knows/src/ship/airlock/airlock_show.gd`
- Modify: `who-knows/src/audio/synth.gd`
- Test: `who-knows/test/unit/test_puffs.gd` (new), `who-knows/test/unit/test_synth.gd`, `who-knows/test/unit/test_visual_style_rules.gd`

**Interfaces:**
- Produces: `class_name Puffs extends RefCounted`:
  - `const SEGMENTS := 8`, `const RINGS := 4`, `const FADE_NEAR := 0.25`, `const FADE_FAR := 0.9`;
  - `static mesh(flat: bool) -> SphereMesh`;
  - `static fade(peak: float) -> GradientTexture1D`;
  - `static grow(from: float, to: float) -> CurveTexture`.
- Produces: `Synth` sound `&"rcs_puff"`, 0.25 s, not looped.

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_puffs.gd`:

```gdscript
extends GutTest

## The shared chunky puff (flight controls spec §6.2): the airlock's steam and
## the RCS thrusters draw the same thing.

func test_a_puff_is_a_chunky_low_poly_sphere():
	var m := Puffs.mesh(false)
	assert_eq(m.radial_segments, 8)
	assert_eq(m.rings, 4)

func test_flat_puffs_are_unshaded_and_others_are_lit():
	var flat := Puffs.mesh(true).material as StandardMaterial3D
	var lit := Puffs.mesh(false).material as StandardMaterial3D
	assert_eq(flat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_ne(lit.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)

func test_puffs_are_steam_coloured_and_fade_in_and_out():
	assert_eq((Puffs.mesh(true).material as StandardMaterial3D).albedo_color, InteriorPalette.STEAM)
	var ramp := Puffs.fade(0.5).gradient
	assert_almost_eq(ramp.colors[0].a, 0.0, 0.001)
	assert_almost_eq(ramp.colors[1].a, 0.5, 0.001)
	assert_almost_eq(ramp.colors[3].a, 0.0, 0.001)

func test_a_puff_grows_over_its_life():
	var c := Puffs.grow(0.8, 2.2).curve
	assert_almost_eq(c.sample(0.0), 0.8, 0.001)
	assert_almost_eq(c.sample(1.0), 2.2, 0.001)
```

In `test_synth.gd`, add `&"rcs_puff": 0.25,` to `LENGTHS` (after `&"hull_thump": 0.6,`).

In `test_visual_style_rules.gd`, add `"res://src/world/puffs.gd",` to both `PAINTING_FILES` and
`REUSABLE_FILES`.

- [ ] **Step 2: Run to see them fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_puffs'`, `'-gselect=test_synth'`, `'-gselect=test_visual_style_rules'`
Expected: FAIL. `Puffs` is undeclared, `NAMES` and `LENGTHS` sizes differ, and `puffs.gd` cannot
be read.

- [ ] **Step 3: Implement `Puffs`**

`who-knows/src/world/puffs.gd`, moving the three builders out of `AirlockShow` unchanged:

```gdscript
class_name Puffs
extends RefCounted

## The chunky vapour puff, shared by everything that puffs: the airlock's
## steam, its burst onto the hull, and the RCS thrusters (flight controls spec
## §6.2). An 8-segment low-poly sphere in the palette's steam, faded near the
## camera. Built-in materials only, never a new shader (style guide §2.5).

const SEGMENTS := 8
const RINGS := 4
## Puffs closer to the camera than this fade away, so one drifting through your
## head never fills the screen.
const FADE_NEAR := 0.25
const FADE_FAR := 0.9

## One puff. `flat` puffs are unshaded: vapour out on the hull, not lit rock.
static func mesh(flat: bool) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = SEGMENTS
	m.rings = RINGS
	var material := StandardMaterial3D.new()
	material.albedo_color = InteriorPalette.STEAM
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	if flat:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.shadow_to_opacity = false
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = FADE_NEAR
	material.distance_fade_max_distance = FADE_FAR
	m.material = material
	return m

## Fades in, holds, fades out: steam in the palette's off-white.
static func fade(peak: float) -> GradientTexture1D:
	var clear := InteriorPalette.STEAM
	clear.a = 0.0
	var thick := InteriorPalette.STEAM
	thick.a = peak
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	g.colors = PackedColorArray([clear, thick, thick, clear])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex

## Grows from `from` to `to` times its size over a puff's life.
static func grow(from: float, to: float) -> CurveTexture:
	var c := Curve.new()
	c.max_value = maxf(from, to)
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, to))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex
```

- [ ] **Step 4: `AirlockShow` uses it**

In `airlock_show.gd`:
- delete `PUFF_SEGMENTS`, `PUFF_RINGS`, `FADE_NEAR` and `FADE_FAR`, with their doc comments;
- change the doc line above `JET_PUFFS` to `## Puffs are Puffs' chunky spheres, lit, fading through a colour ramp.`;
- delete the static functions `_puff_mesh`, `_fade` and `_grow`;
- replace every call: `_puff_mesh(` → `Puffs.mesh(`, `_fade(` → `Puffs.fade(`, `_grow(` → `Puffs.grow(`.

Confirm with `grep -n "_puff_mesh\|_fade(\|_grow(\|PUFF_SEGMENTS\|FADE_NEAR" who-knows/src/ship/airlock/airlock_show.gd`,
which should print nothing.

- [ ] **Step 5: `rcs_puff` in `Synth`**

In `synth.gd`:
- append `&"rcs_puff"` to `NAMES`;
- add a `match` branch in `build()`, before `_:`:

```gdscript
		&"rcs_puff":
			x = _rcs_puff()
```

and after `_thruster()`:

```gdscript
## An RCS thruster firing, heard aboard (flight controls spec §6.3): a short,
## soft hiss with a rounded tail -- warm, never a crack.
static func _rcs_puff() -> PackedFloat32Array:
	var n := _len(0.25)
	var x := _lowpass(_highpass(_noise(n, 28), 300.0), 3000.0)
	for i in n:
		var t := float(i) / MIX_RATE
		x[i] *= minf(t / 0.012, 1.0) * exp(-t / 0.07)
	return _gain(x, 0.6)
```

- [ ] **Step 6: Import pass, run to see them pass, then the suite**

Run the import pass, then `'-gselect=test_puffs'`, `'-gselect=test_synth'`,
`'-gselect=test_visual_style_rules'`, `'-gselect=test_airlock'`, then everything.
Expected: PASS. The airlock tests are unchanged, which proves the move changed nothing.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/world/puffs.gd who-knows/src/world/puffs.gd.uid who-knows/src/ship/airlock/airlock_show.gd who-knows/src/audio/synth.gd who-knows/test/unit/test_puffs.gd who-knows/test/unit/test_puffs.gd.uid who-knows/test/unit/test_synth.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "refactor: share the chunky puff; add the RCS puff sound

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: RcsShow — the thrusters you see and hear

**Files:**
- Create: `who-knows/src/flight/rcs_show.gd`
- Modify: `who-knows/src/ship/ship.gd`
- Test: `who-knows/test/unit/test_rcs_show.gd` (new), `who-knows/test/unit/test_visual_style_rules.gd`

**Interfaces:**
- Consumes:
  - `FlightComputer.commanded_torque_local`, `commanded_force_local`, `torque_budget`,
    `thrust_budget` (Tasks 3–4);
  - `Puffs` and `Synth` `&"rcs_puff"` (Task 6);
  - `InteriorBuilder.storey_offset(y: int) -> float`, `AudioBuses.SHIP`,
    `Universe.HOLDS_SHIFT`.
- Produces: `class_name RcsShow extends Node3D`:
  - `static gather(grid: ShipGrid, catalog: BlockCatalog, center_of_mass: Vector3) -> Array`,
    with entries `{coord: Vector3i, force: Vector3, torque: Vector3, nozzle: Vector3}`;
  - `static firing_for(blocks: Array, torque: Vector3, force: Vector3, torque_budget: Vector3,
    thrust_budget: Dictionary) -> PackedFloat32Array`;
  - `static puff_step(fire: float, armed: bool, since_last: float) -> Array` returning
    `[puff_now: bool, armed_after: bool]`;
  - `setup(flight: FlightComputer, interior: Node3D) -> void`;
  - `rebuild(grid: ShipGrid, catalog: BlockCatalog, center_of_mass: Vector3) -> void`;
  - `apply(amounts: PackedFloat32Array) -> void`;
  - vars `blocks`, `firing`, `emitters: Array[GPUParticles3D]`,
    `players: Array[AudioStreamPlayer3D]`.
- `Ship` gains `var rcs_show: RcsShow`, the node at `Ship/Exterior/RcsShow`.

The expected blocks below were computed on the real starter shuttle before this plan was written
(firing past 0.05; the retro pair only brakes, because `ShipStats` never counts it for turning):

| Command | Blocks lit |
|---|---|
| pitch up (+x) | (−2,1,−3), (2,1,−3) |
| pitch down | (−2,1,−4), (2,1,−4) |
| yaw left (+y) | (1,1,−4) |
| yaw right | (−1,1,−4) |
| roll +z | (2,1,−3) at 0.98, (−2,1,−4) at 0.69 |
| roll −z | (−2,1,−3), (2,1,−4) |
| brake (push +z) | (−2,1,−2), (2,1,−2) |
| forward push (−z) | none |
| strafe right (+x) | (−1,1,−4) |
| settled | none |

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_rcs_show.gd`:

```gdscript
extends GutTest

## The RCS thrusters you see and hear (flight controls spec §6), on the
## starter shuttle.

var _cat: BlockCatalog
var _grid: ShipGrid
var _stats: ShipStats
var _blocks: Array

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	_grid = bootstrap._starter_grid()
	bootstrap.free()
	_stats = ShipStats.compute(_grid, _cat)
	_blocks = RcsShow.gather(_grid, _cat, _stats.center_of_mass)

func _fire(torque: Vector3, force := Vector3.ZERO) -> PackedFloat32Array:
	return RcsShow.firing_for(_blocks, torque, force, _stats.torque_budget, _stats.thrust_budget)

## The cells of the blocks that show for this command, sorted.
func _lit(torque: Vector3, force := Vector3.ZERO) -> Array:
	var fire := _fire(torque, force)
	var out := []
	for i in _blocks.size():
		if fire[i] >= RcsShow.SHOW_AT:
			out.append(_blocks[i]["coord"])
	out.sort()
	return out

func _sorted(cells: Array) -> Array:
	var out := cells.duplicate()
	out.sort()
	return out

func _amount(torque: Vector3, coord: Vector3i) -> float:
	var fire := _fire(torque)
	for i in _blocks.size():
		if _blocks[i]["coord"] == coord:
			return fire[i]
	return -1.0

func test_the_shuttle_has_eight_rcs_blocks():
	assert_eq(_blocks.size(), 8)

func test_pitch_up_fires_the_two_nose_up_thrusters():
	assert_eq(_lit(Vector3(_stats.torque_budget.x, 0, 0)),
		_sorted([Vector3i(-2, 1, -3), Vector3i(2, 1, -3)]))

func test_pitch_down_fires_the_two_nose_down_thrusters():
	assert_eq(_lit(Vector3(-_stats.torque_budget.x, 0, 0)),
		_sorted([Vector3i(-2, 1, -4), Vector3i(2, 1, -4)]))

func test_yaw_fires_the_one_nose_thruster_pushing_the_right_way():
	assert_eq(_lit(Vector3(0, _stats.torque_budget.y, 0)), [Vector3i(1, 1, -4)])
	assert_eq(_lit(Vector3(0, -_stats.torque_budget.y, 0)), [Vector3i(-1, 1, -4)])

func test_roll_fires_one_sides_up_with_the_other_sides_down():
	assert_eq(_lit(Vector3(0, 0, _stats.torque_budget.z)),
		_sorted([Vector3i(2, 1, -3), Vector3i(-2, 1, -4)]))
	assert_eq(_lit(Vector3(0, 0, -_stats.torque_budget.z)),
		_sorted([Vector3i(-2, 1, -3), Vector3i(2, 1, -4)]))

func test_braking_fires_the_retros_and_nothing_fires_for_the_main_engines():
	assert_eq(_lit(Vector3.ZERO, Vector3(0, 0, _stats.thrust_budget[&"reverse"])),
		_sorted([Vector3i(-2, 1, -2), Vector3i(2, 1, -2)]))
	assert_eq(_lit(Vector3.ZERO, Vector3(0, 0, -_stats.thrust_budget[&"forward"])), [])

func test_strafing_fires_the_thruster_pushing_that_way():
	assert_eq(_lit(Vector3.ZERO, Vector3(_stats.thrust_budget[&"lateral"], 0, 0)),
		[Vector3i(-1, 1, -4)])

func test_a_settled_ship_fires_nothing():
	assert_eq(_lit(Vector3.ZERO), [])

func test_half_a_command_fires_half_as_hard():
	assert_almost_eq(_amount(Vector3(_stats.torque_budget.x * 0.5, 0, 0), Vector3i(-2, 1, -3)),
		0.5, 0.01)

func test_the_exhaust_leaves_the_face_opposite_the_push():
	for b in _blocks:
		var centre := ShipGrid.cell_center(b["coord"])
		var push: Vector3 = (b["force"] as Vector3).normalized()
		assert_almost_eq(b["nozzle"], centre - push * ShipGrid.CELL_SIZE * 0.5, Vector3.ONE * 0.001)

func test_a_block_puffs_once_as_it_starts_firing():
	assert_eq(RcsShow.puff_step(0.5, true, 1.0), [true, false])

func test_a_held_firing_does_not_puff_again():
	assert_eq(RcsShow.puff_step(0.5, false, 1.0), [false, false])

func test_it_rearms_once_the_firing_falls_away():
	assert_eq(RcsShow.puff_step(0.02, false, 1.0), [false, true])

func test_a_faint_firing_never_puffs():
	assert_eq(RcsShow.puff_step(0.1, true, 1.0), [false, true])

func test_puffs_are_never_closer_than_the_gap():
	assert_eq(RcsShow.puff_step(0.5, true, RcsShow.PUFF_GAP * 0.5), [false, true])

func _built() -> Array:
	var interior := Node3D.new()
	add_child_autofree(interior)
	var show := RcsShow.new()
	add_child_autofree(show)
	show.setup(null, interior)
	show.rebuild(_grid, _cat, _stats.center_of_mass)
	return [show, interior]

func test_every_block_gets_a_world_space_emitter_on_the_world_layer():
	var show: RcsShow = _built()[0]
	assert_eq(show.emitters.size(), 8)
	for e in show.emitters:
		assert_false(e.local_coords, "puffs hang where they left")
		assert_eq(e.layers, 1, "on the world layer, so the canopy shows them")
		assert_true(e.is_in_group(Universe.HOLDS_SHIFT), "world-space puffs hold the origin's shift")
		assert_false(e.emitting)

func test_each_emitter_blows_out_of_its_nozzle():
	var show: RcsShow = _built()[0]
	for i in show.blocks.size():
		var e := show.emitters[i]
		var push: Vector3 = (show.blocks[i]["force"] as Vector3).normalized()
		assert_almost_eq(e.position, show.blocks[i]["nozzle"], Vector3.ONE * 0.001)
		assert_almost_eq(-e.transform.basis.z, -push, Vector3.ONE * 0.001)

func test_puffs_follow_the_firing():
	var show: RcsShow = _built()[0]
	var amounts := PackedFloat32Array()
	amounts.resize(8)
	amounts[0] = 0.6
	amounts[1] = 0.02
	show.apply(amounts)
	assert_true(show.emitters[0].emitting)
	assert_almost_eq(show.emitters[0].amount_ratio, 0.6, 0.001)
	assert_false(show.emitters[1].emitting, "too faint to show")

func test_each_block_is_heard_where_it_sits_aboard():
	var built := _built()
	var show: RcsShow = built[0]
	assert_eq(show.players.size(), 8)
	for i in show.blocks.size():
		var p := show.players[i]
		var coord: Vector3i = show.blocks[i]["coord"]
		assert_same(p.get_parent(), built[1])
		assert_eq(p.bus, AudioBuses.SHIP)
		assert_almost_eq(p.position,
			ShipGrid.cell_center(coord) + Vector3(0.0, InteriorBuilder.storey_offset(coord.y), 0.0),
			Vector3.ONE * 0.001)

func test_a_rebuild_replaces_rather_than_adds():
	var built := _built()
	var show: RcsShow = built[0]
	show.rebuild(_grid, _cat, _stats.center_of_mass)
	assert_eq(show.emitters.size(), 8)
	assert_eq(show.get_child_count(), 8)
	assert_eq((built[1] as Node).get_child_count(), 8)

func test_the_flight_scene_shows_the_shuttles_rcs():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var show: RcsShow = root.get_node_or_null("Ship/Exterior/RcsShow")
	assert_not_null(show, "on the hull, so the floating origin carries it")
	assert_eq(show.emitters.size(), 8)
```

In `test_visual_style_rules.gd`, add `"res://src/flight/rcs_show.gd",` to `PAINTING_FILES`.

- [ ] **Step 2: Run to see them fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_rcs_show'`
Expected: FAIL. `RcsShow` is not declared.

- [ ] **Step 3: Implement `RcsShow`**

`who-knows/src/flight/rcs_show.gd`:

```gdscript
class_name RcsShow
extends Node3D

## The RCS thrusters you see and hear (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §6). Each `rcs` block puffs vapour, and
## sounds aboard, in proportion to how much it helps the twist and push the
## flight computer commanded this tick. The physics is untouched: the flight
## computer still applies one twist and one push to the hull. This only shows
## which thrusters would be doing it.

const BLOCK_ID := &"rcs"
## A block lined up within 45 deg of the command fires fully; past 70 deg, not
## at all; a smoothstep between.
const FULL_ALIGN := 0.7071
const NO_ALIGN := 0.342
## Below this an emitter stops.
const SHOW_AT := 0.05
## A block puffs aloud when its firing rises past PUFF_ON, re-arms once it falls
## below PUFF_REARM, and puffs at most once per PUFF_GAP seconds. A held turn is
## heard as a puff when it starts and one from the other side when it stops.
const PUFF_ON := 0.15
const PUFF_REARM := 0.05
const PUFF_GAP := 0.12
const PUFFS := 16
const LIFETIME := 0.5
const EXHAUST_SPEED := 6.0
const LOUD_DB := -8.0
const SOFT_DB := -26.0
## The world's render layer: the canopy camera leaves the own-hull layer out,
## and the puffs are what you should see through it.
const LAYER := 1

## One entry per `rcs` block, in hull axes: {coord, force (N), torque about the
## centre of mass (N m), nozzle (the middle of the face the exhaust leaves)}.
var blocks: Array = []
## Each block's firing this tick, 0..1, in `blocks` order.
var firing := PackedFloat32Array()
var emitters: Array[GPUParticles3D] = []
var players: Array[AudioStreamPlayer3D] = []

var _flight: FlightComputer
var _interior: Node3D
var _armed := PackedByteArray()
var _last_puff := PackedFloat32Array()

## `flight` is read each physics tick; the puff sounds go under `interior`,
## where each block sits aboard.
func setup(flight: FlightComputer, interior: Node3D) -> void:
	_flight = flight
	_interior = interior

## One emitter and one sound per `rcs` block of `grid`, replacing the last set.
func rebuild(grid: ShipGrid, catalog: BlockCatalog, center_of_mass: Vector3) -> void:
	for e in emitters:
		e.free()
	for p in players:
		p.free()
	emitters.clear()
	players.clear()
	blocks = gather(grid, catalog, center_of_mass)
	var mesh := Puffs.mesh(true)
	var process := _process_material()
	for b in blocks:
		emitters.append(_emitter(b, mesh, process))
		if _interior != null:
			players.append(_player(b))
	firing.resize(blocks.size())
	firing.fill(0.0)
	_armed.resize(blocks.size())
	_armed.fill(1)
	_last_puff.resize(blocks.size())
	_last_puff.fill(-INF)

## Every `rcs` block of `grid`, with its push and its twist about
## `center_of_mass`, worked out the way ShipStats does.
static func gather(grid: ShipGrid, catalog: BlockCatalog, center_of_mass: Vector3) -> Array:
	var out: Array = []
	for coord: Vector3i in grid.coords():
		var inst := grid.get_block(coord)
		if inst.block_id != BLOCK_ID:
			continue
		var def := catalog.get_def(inst.block_id)
		if def == null or def.thrust_kn <= 0.0:
			continue
		var force := BlockOrientation.basis_for(inst.orientation) * Vector3(0, 0, -1) \
			* def.thrust_kn * ShipStats.N_PER_KN
		var centre := ShipGrid.cell_center(coord)
		out.append({
			"coord": coord,
			"force": force,
			"torque": (centre - center_of_mass).cross(force),
			"nozzle": centre - force.normalized() * ShipGrid.CELL_SIZE * 0.5,
		})
	return out

## How hard each block fires, 0..1, for the commanded twist `torque` and push
## `force`, both in hull axes (spec §6.1). Pure.
##
## Everything is measured as a share of its budget, so a strong axis does not
## drown a weak one. A block fires as hard as the command asks, times how well
## its own twist or push lines up with it. Only blocks that push across the
## hull count for turning -- exactly the ones ShipStats sums into the torque
## budget, so the off-centre retros never light up for yaw -- and only aft
## pushes count for moving, since a forward push is the main engines'.
static func firing_for(blocks: Array, torque: Vector3, force: Vector3,
		torque_budget: Vector3, thrust_budget: Dictionary) -> PackedFloat32Array:
	var push_budget := Vector3(thrust_budget[&"lateral"], thrust_budget[&"vertical"],
		thrust_budget[&"reverse"])
	var twist_wanted := _share(torque, torque_budget)
	var push_wanted := _share(_aft_only(force), push_budget)
	var out := PackedFloat32Array()
	out.resize(blocks.size())
	for i in blocks.size():
		var f: Vector3 = blocks[i]["force"]
		var twist := 0.0
		if not (is_zero_approx(f.x) and is_zero_approx(f.y)):
			twist = _helps(_share(blocks[i]["torque"], torque_budget), twist_wanted)
		var push := _helps(_share(_aft_only(f), push_budget), push_wanted)
		out[i] = maxf(twist, push)
	return out

## Whether a block should puff aloud now, and whether it stays armed after.
static func puff_step(fire: float, armed: bool, since_last: float) -> Array:
	if fire < PUFF_REARM:
		return [false, true]
	if armed and fire >= PUFF_ON and since_last >= PUFF_GAP:
		return [true, false]
	return [false, armed]

func _physics_process(_delta: float) -> void:
	if _flight == null or blocks.is_empty():
		return
	firing = firing_for(blocks, _flight.commanded_torque_local, _flight.commanded_force_local,
		_flight.torque_budget, _flight.thrust_budget)
	apply(firing)
	_sound(firing)

## Puffs each block's emitter at its firing amount.
func apply(amounts: PackedFloat32Array) -> void:
	for i in emitters.size():
		emitters[i].amount_ratio = clampf(amounts[i], 0.0, 1.0)
		emitters[i].emitting = amounts[i] >= SHOW_AT

func _sound(amounts: PackedFloat32Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var aboard := _aboard()
	for i in players.size():
		var step := puff_step(amounts[i], _armed[i] == 1, now - _last_puff[i])
		_armed[i] = 1 if step[1] else 0
		if not step[0]:
			continue
		_last_puff[i] = now
		var s := Synth.sound(&"rcs_puff")
		if not aboard or s == null:
			continue
		players[i].stream = s
		players[i].volume_db = lerpf(SOFT_DB, LOUD_DB, amounts[i])
		players[i].play()

## True while the camera you see through is aboard. Space is silent: the chase
## view hears nothing, like the ship's hum (spec §6.3).
func _aboard() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and _interior != null and _interior.is_ancestor_of(cam)

func _emitter(b: Dictionary, mesh: Mesh, process: ParticleProcessMaterial) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Rcs%d" % emitters.size()
	p.amount = PUFFS
	p.lifetime = LIFETIME
	p.draw_pass_1 = mesh
	p.process_material = process
	p.layers = LAYER
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var exhaust: Vector3 = -(b["force"] as Vector3).normalized()
	var up := Vector3.UP if absf(exhaust.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	p.transform = Transform3D(Basis.looking_at(exhaust, up), b["nozzle"])
	# World-space puffs cannot be moved once out, so they hold the floating
	# origin's shift while alive (CLAUDE.md).
	p.add_to_group(Universe.HOLDS_SHIFT)
	add_child(p)
	return p

func _player(b: Dictionary) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "RcsPuff%d" % players.size()
	p.bus = AudioBuses.SHIP
	var coord: Vector3i = b["coord"]
	p.position = ShipGrid.cell_center(coord) + Vector3(0.0, InteriorBuilder.storey_offset(coord.y), 0.0)
	_interior.add_child(p)
	return p

## Puffs blow out of the nozzle, slow in a metre or two, grow and fade. They
## keep the hull's velocity, so a fast ship does not smear them into a trail.
static func _process_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, -1)
	m.spread = 14.0
	m.initial_velocity_min = EXHAUST_SPEED * 0.7
	m.initial_velocity_max = EXHAUST_SPEED
	m.damping_min = 6.0
	m.damping_max = 9.0
	m.gravity = Vector3.ZERO
	m.inherit_velocity_ratio = 1.0
	m.scale_min = 0.3
	m.scale_max = 0.45
	m.scale_curve = Puffs.grow(0.7, 2.2)
	m.color_ramp = Puffs.fade(0.7)
	m.angle_min = 0.0
	m.angle_max = 360.0
	return m

## `v` with its forward (-z) part dropped.
static func _aft_only(v: Vector3) -> Vector3:
	return Vector3(v.x, v.y, maxf(v.z, 0.0))

## `v` per axis as a share of `budget`; an axis with no budget is left out.
static func _share(v: Vector3, budget: Vector3) -> Vector3:
	return Vector3(
		0.0 if budget.x <= 0.0 else v.x / budget.x,
		0.0 if budget.y <= 0.0 else v.y / budget.y,
		0.0 if budget.z <= 0.0 else v.z / budget.z,
	)

## How hard a block whose share is `mine` fires for the command `wanted`.
static func _helps(mine: Vector3, wanted: Vector3) -> float:
	var strength := minf(maxf(absf(wanted.x), maxf(absf(wanted.y), absf(wanted.z))), 1.0)
	if strength < 0.0001 or mine.length() < 0.0001:
		return 0.0
	var align := mine.dot(wanted) / (mine.length() * wanted.length())
	return strength * smoothstep(NO_ALIGN, FULL_ALIGN, align)
```

- [ ] **Step 4: The ship builds it**

In `ship.gd`:

(a) Below `var airlocks: Dictionary = {}   # Vector3i -> Airlock`, add:

```gdscript
## The RCS thrusters you see and hear (flight controls spec §6). On the hull,
## so the floating origin carries it.
var rcs_show: RcsShow
```

(b) In `_ready()`, after `add_child(_airlocks_root)`, add:

```gdscript
	rcs_show = RcsShow.new()
	rcs_show.name = "RcsShow"
	exterior.add_child(rcs_show)
	rcs_show.setup(flight_computer, interior)
```

(c) In `_rebuild_everything()`, after `_apply_stats()`, add:

```gdscript
	if rcs_show != null:
		rcs_show.rebuild(grid, catalog, stats.center_of_mass)
```

- [ ] **Step 5: Import pass, run to see them pass, then the suite**

Run the import pass, then `'-gselect=test_rcs_show'`, `'-gselect=test_visual_style_rules'`,
`'-gselect=test_floating_origin_scene'`, then everything.
Expected: PASS. `test_everything_outside_is_covered` still passes because the emitters sit under
`Ship/Exterior`.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/flight/rcs_show.gd who-knows/src/flight/rcs_show.gd.uid who-knows/src/ship/ship.gd who-knows/test/unit/test_rcs_show.gd who-knows/test/unit/test_rcs_show.gd.uid who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: the RCS thrusters puff and sound as they turn and push the ship

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: HUD — the stick, the pointer, the heading, the holds

**Files:**
- Create: `who-knows/src/ui/stick_cursor.gd`, `who-knows/src/ui/heading_marker.gd`
- Modify: `who-knows/src/ui/panels/velocity_panel.gd`
- Modify: `who-knows/scenes/flight_test.tscn`, `who-knows/scenes/flight_test.gd`
- Test:
  - new: `test_stick_cursor.gd`, `test_heading_marker.gd`;
  - changed: `test_hud_panels.gd`, `test_hud_scene_wiring.gd`.

**Interfaces:**
- Consumes: the `VehicleTelemetry` fields (Task 4), `VelocityMarker.resolve`,
  `VelocityMarker.Mode`, `VelocityMarker.MIN_SPEED_MPS`, `HudPalette`.
- Produces:
  - `class_name StickCursor extends HudElement`: vars `armed`, `pointing`, `show_stick`,
    `stick_at: Vector2`, `pointer_at: Vector2`, `hint: Label`;
  - `class_name HeadingMarker extends HudElement`: export `camera_path`, vars `armed`, `mode`,
    `marker_at`;
  - `VelocityPanel.hold_label: Label`;
  - scene nodes `HudRoot/Screen/StickCursor`, `HudRoot/Screen/HeadingChaseMarker` and
    `Ship/Canopy/CanopyOverlay/HeadingCockpitMarker`.

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_stick_cursor.gd`:

```gdscript
extends GutTest

## The stick and the pointer on the HUD (flight controls spec §8).

func _cursor() -> StickCursor:
	var c := StickCursor.new()
	add_child_autofree(c)
	c.size = Vector2(1280.0, 720.0)
	return c

func _t(stick: Vector2, pointing := false, pointer := Vector2.ZERO) -> VehicleTelemetry:
	var t := VehicleTelemetry.new()
	t.stick = stick
	t.stick_radius = PilotStick.RADIUS
	t.stick_deadzone = PilotStick.DEADZONE
	t.pointing = pointing
	t.pointer = pointer
	return t

func test_a_centred_stick_draws_nothing():
	var c := _cursor()
	c.render(_t(Vector2.ZERO))
	assert_true(c.armed)
	assert_false(c.show_stick)

func test_a_deflected_stick_sits_where_it_is_held():
	var c := _cursor()
	c.render(_t(Vector2(0.1, -0.05)))
	assert_true(c.show_stick)
	assert_almost_eq(c.stick_at, Vector2(640.0 + 72.0, 360.0 - 36.0), Vector2.ONE * 0.01)

func test_point_mode_draws_the_pointer_and_the_hint():
	var c := _cursor()
	c.render(_t(Vector2.ZERO, true, Vector2(-0.1, 0.0)))
	assert_true(c.pointing)
	assert_false(c.show_stick)
	assert_true(c.hint.visible)
	assert_almost_eq(c.pointer_at, Vector2(640.0 - 72.0, 360.0), Vector2.ONE * 0.01)

func test_no_vehicle_draws_nothing():
	var c := _cursor()
	c.render(_t(Vector2(0.1, 0.0), true))
	c.render(null)
	assert_false(c.armed)
	assert_false(c.show_stick)
	assert_false(c.hint.visible)

func test_it_ignores_the_mouse():
	var c := _cursor()
	assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(c.hint.mouse_filter, Control.MOUSE_FILTER_IGNORE)
```

`who-knows/test/unit/test_heading_marker.gd`:

```gdscript
extends GutTest

## The held heading on the HUD (flight controls spec §8).

var _cam: Camera3D
var _marker: HeadingMarker

func before_each():
	_cam = Camera3D.new()
	add_child_autofree(_cam)
	_cam.current = true
	_marker = HeadingMarker.new()
	_marker.camera_path = _cam.get_path()
	add_child_autofree(_marker)
	_marker.size = Vector2(1280.0, 720.0)

func _held(direction: Vector3) -> VehicleTelemetry:
	var t := VehicleTelemetry.new()
	t.heading_hold = true
	t.heading = direction
	return t

func test_without_a_hold_nothing_is_drawn():
	_marker.render(VehicleTelemetry.new())
	assert_false(_marker.armed)
	assert_eq(_marker.mode, VelocityMarker.Mode.HIDDEN)

func test_a_heading_dead_ahead_sits_in_the_middle():
	_marker.render(_held(Vector3.FORWARD))
	assert_eq(_marker.mode, VelocityMarker.Mode.ON_FRAME)
	var view := _cam.get_viewport().get_visible_rect().size
	assert_almost_eq(_marker.marker_at, view * 0.5, Vector2.ONE * 1.0)

func test_a_heading_behind_is_pinned_to_the_edge():
	_marker.render(_held(Vector3.BACK.rotated(Vector3.UP, 0.3)))
	assert_eq(_marker.mode, VelocityMarker.Mode.CLAMPED_BEHIND)

func test_only_the_live_camera_draws():
	_cam.current = false
	_marker.render(_held(Vector3.FORWARD))
	assert_false(_marker.armed)

func test_no_vehicle_draws_nothing():
	_marker.render(null)
	assert_false(_marker.armed)
```

Append to `test_hud_panels.gd`:

```gdscript
## Flight controls spec §8: the speed lock and the heading hold.
func test_velocity_panel_shows_a_speed_lock_and_a_heading_hold():
	var p := _velocity_panel()
	var t := _telemetry(45.0, 120.0, true, false)
	t.speed_locked = true
	t.locked_speed = 45.2
	t.heading_hold = true
	p.render(t)
	assert_string_contains(p.hold_label.text, "LOCK 45")
	assert_string_contains(p.hold_label.text, "HDG HOLD")

func test_velocity_panel_shows_no_holds_when_there_are_none():
	var p := _velocity_panel()
	p.render(_telemetry(45.0, 120.0, true, false))
	assert_eq(p.hold_label.text, "")
```

Append to `test_hud_scene_wiring.gd`:

```gdscript
## Flight controls spec §8: the stick cursor and the heading markers, read back.
func test_the_stick_cursor_is_on_the_screen():
	assert_true(_root.get_node_or_null("HudRoot/Screen/StickCursor") is StickCursor)

func test_heading_markers_survived_the_parse():
	for path in ["HudRoot/Screen/HeadingChaseMarker", "Ship/Canopy/CanopyOverlay/HeadingCockpitMarker"]:
		var marker: HeadingMarker = _root.get_node_or_null(path)
		assert_not_null(marker, path)
		assert_ne(marker.camera_path, NodePath(""), "%s camera_path was not dropped" % path)
		assert_true(marker.get_node_or_null(marker.camera_path) is Camera3D,
			"%s camera_path resolves" % path)

func test_the_cockpit_heading_marker_is_fed_by_the_hud():
	# It lives in the canopy SubViewport, so HudRoot cannot find it by walking.
	var hud: HudRoot = _root.get_node("HudRoot")
	assert_true(hud._registered.has(
		_root.get_node("Ship/Canopy/CanopyOverlay/HeadingCockpitMarker")))
```

- [ ] **Step 2: Run to see them fail**

Run: `'-gselect=test_stick_cursor'`, `'-gselect=test_heading_marker'`, `'-gselect=test_hud_panels'`
Expected: FAIL. The classes are undeclared and `hold_label` is missing.

- [ ] **Step 3: Implement `StickCursor`**

`who-knows/src/ui/stick_cursor.gd`:

```gdscript
class_name StickCursor
extends HudElement

## The virtual stick and the point-mode pointer (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §8). A small ring where the stick sits,
## a faint line back to the centre and a faint circle at full deflection,
## hidden inside the dead zone. In point mode, the pointer and a hint instead.
## Everything it needs comes in the telemetry, so it knows nothing of flight.

const HINT := "CLICK: SET HEADING   ·   RELEASE RMB: BACK TO STICK"
const RING := 7.0
const POINTER_ARM := 9.0
const LINE_WIDTH := 1.5
## Where the hint sits, as a fraction of the screen's height.
const HINT_HEIGHT := 0.72

var armed := false
var pointing := false
var show_stick := false
## Screen positions, for _draw and the tests.
var stick_at := Vector2.ZERO
var pointer_at := Vector2.ZERO
var hint: Label

var _radius_px := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint = Label.new()
	hint.text = HINT
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", HudPalette.READOUT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.visible = false
	add_child(hint)

func render(telemetry: VehicleTelemetry) -> void:
	armed = telemetry != null
	pointing = armed and telemetry.pointing
	show_stick = armed and not pointing and telemetry.stick.length() > telemetry.stick_deadzone
	if armed:
		var centre := size * 0.5
		stick_at = centre + telemetry.stick * size.y
		pointer_at = centre + telemetry.pointer * size.y
		_radius_px = telemetry.stick_radius * size.y
	hint.visible = pointing
	if pointing:
		hint.position = Vector2(size.x * 0.5 - hint.get_minimum_size().x * 0.5, size.y * HINT_HEIGHT)
	queue_redraw()

func _draw() -> void:
	if pointing:
		var c := HudPalette.READOUT
		draw_line(pointer_at + Vector2(-POINTER_ARM, 0.0), pointer_at + Vector2(POINTER_ARM, 0.0), c, LINE_WIDTH)
		draw_line(pointer_at + Vector2(0.0, -POINTER_ARM), pointer_at + Vector2(0.0, POINTER_ARM), c, LINE_WIDTH)
		draw_arc(pointer_at, POINTER_ARM * 0.5, 0.0, TAU, 16, c, LINE_WIDTH)
		return
	if not show_stick:
		return
	var centre := size * 0.5
	draw_arc(centre, _radius_px, 0.0, TAU, 48, Color(HudPalette.READOUT, 0.15), 1.0)
	draw_line(centre, stick_at, Color(HudPalette.READOUT, 0.3), 1.0)
	draw_arc(stick_at, RING, 0.0, TAU, 20, HudPalette.READOUT, LINE_WIDTH)
```

- [ ] **Step 4: Implement `HeadingMarker`**

`who-knows/src/ui/heading_marker.gd`:

```gdscript
class_name HeadingMarker
extends HudElement

## The heading the flight computer is holding (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §8): a diamond on that direction, drawn
## over the view it refers to. Mounted twice, like VelocityMarker -- in the
## canopy overlay, projected with CanopyCam, and screen-space for chase view,
## projected with ChaseCamera -- and gated the same way, by the camera's
## `current`.

const SIZE := 9.0
const LINE_WIDTH := 2.0
## How much an edge-pinned marker for a heading behind you is faded.
const BEHIND_ALPHA := 0.5
## How far out along the heading the marker is projected from, metres. A
## direction has no distance; any point this far off reads the same on screen.
const REACH := 1000.0

@export var camera_path: NodePath

var armed := false
var mode: int = VelocityMarker.Mode.HIDDEN
var marker_at := Vector2.ZERO

var _camera: Camera3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not camera_path.is_empty():
		_camera = get_node_or_null(camera_path) as Camera3D

func render(telemetry: VehicleTelemetry) -> void:
	armed = telemetry != null and telemetry.heading_hold and _camera != null and _camera.current
	if not armed:
		mode = VelocityMarker.Mode.HIDDEN
		queue_redraw()
		return
	var target := _camera.global_position + telemetry.heading * REACH
	# resolve() hides anything slower than its speed deadband. A heading has no
	# speed, so it is handed exactly the deadband to pass.
	var state := VelocityMarker.resolve(VelocityMarker.MIN_SPEED_MPS,
		_camera.is_position_behind(target), _camera.unproject_position(target), size)
	mode = state["mode"]
	marker_at = state["position"]
	queue_redraw()

func _draw() -> void:
	if not armed:
		return
	match mode:
		VelocityMarker.Mode.ON_FRAME:
			_diamond(marker_at, 1.0, false)
		VelocityMarker.Mode.CLAMPED_AHEAD:
			_diamond(marker_at, 1.0, true)
		VelocityMarker.Mode.CLAMPED_BEHIND:
			_diamond(marker_at, BEHIND_ALPHA, true)

## An open diamond on the heading; a filled one pinned to the edge, so an
## edge-pinned marker never reads as a real position.
func _diamond(at: Vector2, alpha: float, filled: bool) -> void:
	var colour := Color(HudPalette.READOUT, alpha)
	var points := PackedVector2Array([
		at + Vector2(0.0, -SIZE), at + Vector2(SIZE, 0.0),
		at + Vector2(0.0, SIZE), at + Vector2(-SIZE, 0.0),
	])
	if filled:
		draw_colored_polygon(points, colour)
	else:
		points.append(points[0])
		draw_polyline(points, colour, LINE_WIDTH)
```

- [ ] **Step 5: `LOCK` and `HDG HOLD` on the velocity panel**

In `velocity_panel.gd`:
- change the class doc's first line to
  `## Speed against the cruise ceiling, the two flight-mode flags, and what the flight computer is holding.`;
- add `var hold_label: Label` below `var mode_label: Label`;
- at the end of `_ready()`, add:

```gdscript
	hold_label = Label.new()
	hold_label.text = ""
	hold_label.add_theme_font_size_override("font_size", 11)
	hold_label.add_theme_color_override("font_color", HudPalette.READOUT)
	hold_label.position = Vector2(170.0, 20.0)
	add_child(hold_label)
```

- at the end of `render()`, add:

```gdscript
	# What the flight computer is holding (flight controls spec §8).
	var holds := PackedStringArray()
	if telemetry.speed_locked:
		holds.append("LOCK %d M/S" % roundi(telemetry.locked_speed))
	if telemetry.heading_hold:
		holds.append("HDG HOLD")
	hold_label.text = "   ".join(holds)
```

- [ ] **Step 6: Add the nodes to the scene**

In `flight_test.tscn`:

1. Change the header's `load_steps` to 30.
2. Add after the last `[ext_resource ...]` line:

```
[ext_resource type="Script" path="res://src/ui/stick_cursor.gd" id="23_stick_cursor"]
[ext_resource type="Script" path="res://src/ui/heading_marker.gd" id="24_heading_marker"]
```

3. After the `CockpitMarker` node block (before `[node name="Interior" ...]`), add, with blank lines around it:

```
[node name="HeadingCockpitMarker" type="Control" parent="Ship/Canopy/CanopyOverlay"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("24_heading_marker")
camera_path = NodePath("../../CanopyCam")
```

4. At the end of the file, after the `AirlockMarker` block, add, with a blank line between blocks:

```
[node name="HeadingChaseMarker" type="Control" parent="HudRoot/Screen"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("24_heading_marker")
camera_path = NodePath("../../../Ship/Exterior/ChaseCamera")

[node name="StickCursor" type="Control" parent="HudRoot/Screen"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("23_stick_cursor")
```

No `#` comments.

- [ ] **Step 7: Register the cockpit heading marker**

In `flight_test.gd`, add below `@onready var _cockpit_marker ...`:

```gdscript
@onready var _heading_cockpit: HeadingMarker = $Ship/Canopy/CanopyOverlay/HeadingCockpitMarker
```

and in `_wire_hud()`, after `_hud.register_element(_cockpit_marker)`:

```gdscript
	_hud.register_element(_heading_cockpit)
```

- [ ] **Step 8: Import pass, run to see them pass, then the suite**

Run the import pass, then `'-gselect=test_stick_cursor'`, `'-gselect=test_heading_marker'`,
`'-gselect=test_hud_panels'`, `'-gselect=test_hud_scene_wiring'`, then everything.
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add who-knows/src/ui/stick_cursor.gd who-knows/src/ui/stick_cursor.gd.uid who-knows/src/ui/heading_marker.gd who-knows/src/ui/heading_marker.gd.uid who-knows/src/ui/panels/velocity_panel.gd who-knows/scenes/flight_test.tscn who-knows/scenes/flight_test.gd who-knows/test/unit/test_stick_cursor.gd who-knows/test/unit/test_stick_cursor.gd.uid who-knows/test/unit/test_heading_marker.gd who-knows/test/unit/test_heading_marker.gd.uid who-knows/test/unit/test_hud_panels.gd who-knows/test/unit/test_hud_scene_wiring.gd
git commit -m "feat: the HUD shows the stick, the pointer, the held heading and the speed lock

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: The controls card

**Files:**
- Create: `who-knows/src/ui/controls_card.gd`
- Modify: `who-knows/scenes/flight_test.tscn`
- Test: `who-knows/test/unit/test_controls_card.gd` (new), `who-knows/test/unit/test_hud_scene_wiring.gd`

**Interfaces:**
- Consumes: the input actions (Task 1), `HudPalette`, `HudElement`.
- Produces: `class_name ControlsCard extends HudElement`:
  - `const ROWS`, `static var shown: bool`, `var keys: Array[Label]`;
  - `handle(event: InputEvent) -> void`;
  - `static keys_text(source: Variant, joiner: String) -> String`;
  - `static key_name(action: StringName) -> String`.
- Scene node `HudRoot/Screen/ControlsCard`.

- [ ] **Step 1: Write the failing tests**

`who-knows/test/unit/test_controls_card.gd`:

```gdscript
extends GutTest

## The controls card (flight controls spec §8.4): every seated control, with
## key names read from the InputMap.

func before_each():
	ControlsCard.shown = true

func after_each():
	ControlsCard.shown = true

func _card() -> ControlsCard:
	var c := ControlsCard.new()
	add_child_autofree(c)
	return c

func _h() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"toggle_controls"
	ev.pressed = true
	return ev

func test_every_row_names_a_bound_action():
	for row in ControlsCard.ROWS:
		if row[0] is String:
			continue
		for action in row[0]:
			assert_true(InputMap.has_action(action), "%s is an action" % action)
			assert_gt(InputMap.action_get_events(action).size(), 0, "%s is bound" % action)

func test_the_card_shows_each_rows_keys_from_the_input_map():
	var c := _card()
	assert_eq(c.keys.size(), ControlsCard.ROWS.size())
	for i in ControlsCard.ROWS.size():
		var row: Array = ControlsCard.ROWS[i]
		assert_eq(c.keys[i].text, ControlsCard.keys_text(row[0], row[2]))

func test_key_names_come_from_the_bindings():
	assert_eq(ControlsCard.key_name(&"speed_lock"), "C")
	assert_eq(ControlsCard.key_name(&"pitch_up"), "Up")
	assert_eq(ControlsCard.key_name(&"point_mode"), "RMB")
	assert_eq(ControlsCard.key_name(&"set_heading"), "LMB")
	assert_eq(ControlsCard.keys_text([&"point_mode", &"set_heading"], " + "), "RMB + LMB")

func test_it_is_open_the_first_time_you_sit():
	var c := _card()
	c.render(VehicleTelemetry.new())
	assert_true(c.visible)

func test_h_hides_it_and_shows_it_again():
	var c := _card()
	c.render(VehicleTelemetry.new())
	c.handle(_h())
	assert_false(c.visible)
	assert_false(ControlsCard.shown, "and it stays hidden for the session")
	c.handle(_h())
	assert_true(c.visible)

func test_h_does_nothing_on_foot():
	var c := _card()
	c.render(null)
	c.handle(_h())
	assert_true(ControlsCard.shown)

func test_it_ignores_the_mouse():
	var c := _card()
	assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child in c.get_children():
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
```

Append to `test_hud_scene_wiring.gd`:

```gdscript
func test_the_controls_card_is_on_the_screen():
	assert_true(_root.get_node_or_null("HudRoot/Screen/ControlsCard") is ControlsCard)
```

- [ ] **Step 2: Run to see them fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_controls_card'`
Expected: FAIL. `ControlsCard` is undeclared.

- [ ] **Step 3: Implement**

`who-knows/src/ui/controls_card.gd`:

```gdscript
class_name ControlsCard
extends HudElement

## Every seated control, on the HUD (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §8.4). The key names are read from the
## InputMap, never typed in, so the card cannot drift from the bindings. It is
## open the first time you sit; H hides or shows it, and it stays that way for
## the rest of the session.

## [what you press -- actions, or a name for something with no action; what it
## does; how to join several actions' keys].
const ROWS := [
	["Mouse", "Stick: pitch and yaw", " "],
	[[&"pitch_up", &"pitch_down", &"yaw_left", &"yaw_right"], "Pitch and yaw", " "],
	[[&"roll_left", &"roll_right"], "Roll", " "],
	[[&"move_forward", &"move_back"], "Thrust; let go to brake", " "],
	[[&"move_left", &"move_right"], "Strafe", " "],
	[[&"sprint", &"crouch"], "Up and down", " "],
	[[&"boost"], "Boost", " "],
	[[&"speed_lock"], "Lock speed", " "],
	[[&"point_mode", &"set_heading"], "Hold, click: set heading", " + "],
	[[&"toggle_assist"], "Assist", " "],
	[[&"cycle_camera"], "Camera", " "],
	[[&"interact"], "Stand up", " "],
	[[&"toggle_controls"], "Hide this card", " "],
]
const ROW_HEIGHT := 18.0
const KEY_WIDTH := 130.0
const TEXT_WIDTH := 170.0
const PAD := 10.0

## Open or hidden, for the rest of the session.
static var shown := true

var keys: Array[Label] = []

var _armed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := ColorRect.new()
	back.color = HudPalette.BACKDROP
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.size = Vector2(PAD * 2.0 + KEY_WIDTH + TEXT_WIDTH, PAD * 2.0 + ROWS.size() * ROW_HEIGHT)
	add_child(back)
	for i in ROWS.size():
		var row: Array = ROWS[i]
		var y := PAD + i * ROW_HEIGHT
		keys.append(_label(keys_text(row[0], row[2]), HudPalette.READOUT, Vector2(PAD, y)))
		_label(row[1], HudPalette.DIM, Vector2(PAD + KEY_WIDTH, y))
	visible = shown

func render(telemetry: VehicleTelemetry) -> void:
	_armed = telemetry != null
	visible = shown

func _unhandled_input(event: InputEvent) -> void:
	handle(event)

## H, while you sit. Split from _unhandled_input so tests can drive it.
func handle(event: InputEvent) -> void:
	if _armed and event.is_action_pressed(&"toggle_controls"):
		shown = not shown
		visible = shown

## The keys for `source`: an action list's key names joined by `joiner`, or a
## name, as it is.
static func keys_text(source: Variant, joiner: String) -> String:
	if source is String:
		return source
	var names := PackedStringArray()
	for action: StringName in source:
		names.append(key_name(action))
	return joiner.join(names)

## The name of the first key or mouse button bound to `action`.
static func key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
		var button := event as InputEventMouseButton
		if button != null:
			match button.button_index:
				MOUSE_BUTTON_LEFT:
					return "LMB"
				MOUSE_BUTTON_RIGHT:
					return "RMB"
			return "Mouse %d" % button.button_index
	return "?"

func _label(text: String, colour: Color, at: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
```

- [ ] **Step 4: Add the node to the scene**

In `flight_test.tscn`: change `load_steps` to 31, add

```
[ext_resource type="Script" path="res://src/ui/controls_card.gd" id="25_controls_card"]
```

after the last `[ext_resource ...]`, and at the end of the file, after a blank line:

```
[node name="ControlsCard" type="Control" parent="HudRoot/Screen"]
anchors_preset = 4
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = 24.0
offset_top = -130.0
offset_right = 344.0
offset_bottom = 130.0
grow_vertical = 2
mouse_filter = 2
script = ExtResource("25_controls_card")
```

No `#` comments.

- [ ] **Step 5: Import pass, run to see them pass, then the suite**

Run the import pass, then `'-gselect=test_controls_card'`, `'-gselect=test_hud_scene_wiring'`, then everything.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/ui/controls_card.gd who-knows/src/ui/controls_card.gd.uid who-knows/scenes/flight_test.tscn who-knows/test/unit/test_controls_card.gd who-knows/test/unit/test_controls_card.gd.uid who-knows/test/unit/test_hud_scene_wiring.gd
git commit -m "feat: a controls card on the HUD, built from the input map

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Fly it — the live check, the look, the frame rate, the tuning

Green tests prove structure, not feel or looks (CLAUDE.md, style guide §6). This task runs the
real game, measures it, renders it and shows the owner.

**Files:**
- Scratch only: `<scratchpad>/flight_check.gd`. Never committed.
- Modify, only if tuning changes a constant: `pilot_stick.gd`, `flight_computer.gd`,
  `rcs_show.gd`, together with the tests that pin those constants.

- [ ] **Step 1: The scratch check script**

Write `flight_check.gd` in the session scratchpad. `OUT` is a folder in the scratchpad.

```gdscript
extends SceneTree

## Scratch, not committed: the flight controls live check (plan Task 10).

const OUT := "C:/Users/Brandon/AppData/Local/Temp/claude/flight-check/"

var _root: Node
var _fc: FlightComputer
var _hull: RigidBody3D
var _pilot: PilotControls
var _director: CameraDirector

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_root = load("res://scenes/flight_test.tscn").instantiate()
	root.add_child(_root)
	_fc = _root.get_node("Ship/FlightComputer")
	_hull = _root.get_node("Ship/Exterior")
	_pilot = _root.get_node("Ship/PilotControls")
	_director = _root.get_node("Ship/CameraDirector")
	await _wait(1.0)
	_director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	await _wait(1.5)

	# 1. The look: nose thrusters through the canopy, seated eye.
	Input.action_press(&"pitch_up")
	await _wait(0.2)
	await _shot("1_cockpit_pitch_up")
	Input.action_release(&"pitch_up")
	await _wait(0.8)
	Input.action_press(&"yaw_left")
	await _wait(0.2)
	await _shot("2_cockpit_yaw_left")
	Input.action_release(&"yaw_left")
	await _wait(1.0)
	await _shot("3_cockpit_controls_card")

	# 2. A steady turn from the keys: the rate should sit near 60 deg/s.
	Input.action_press(&"yaw_left")
	await _wait(2.0)
	print("keys: yaw rate %.1f deg/s" % rad_to_deg((_hull.global_basis.inverse() * _hull.angular_velocity).y))
	Input.action_release(&"yaw_left")
	await _wait(2.0)

	# 3. A steady turn from the stick, with no mouse moving.
	_pilot.handle(_motion(Vector2(-0.12 * _height(), 0.0)))
	await _wait(2.0)
	print("stick: yaw rate %.1f deg/s" % rad_to_deg((_hull.global_basis.inverse() * _hull.angular_velocity).y))
	await _shot("4_cockpit_stick_held")
	_pilot.stick.centre()
	await _wait(2.0)

	# 4. Locked at 100 m/s, turn 90 deg: time until travel lines up with the nose.
	_hull.linear_velocity = _hull.global_basis * Vector3(0, 0, -100)
	_fc.toggle_speed_lock()
	Input.action_press(&"yaw_left")
	await _wait(1.5)
	Input.action_release(&"yaw_left")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		var nose := _hull.global_basis * Vector3.FORWARD
		if rad_to_deg(nose.angle_to(_hull.linear_velocity)) < 5.0:
			break
		await physics_frame
	print("lock+turn: travel on the nose after %.2f s at %.1f m/s (locked %.1f)" % [
		(Time.get_ticks_msec() - t0) / 1000.0, _hull.linear_velocity.length(), _fc.locked_speed])
	_fc.toggle_speed_lock()

	# 5. Heading hold, 120 deg away: time to 0.5 deg and the worst overshoot.
	var target := Basis(Vector3.UP, deg_to_rad(120.0)) * (_hull.global_basis * Vector3.FORWARD)
	_fc.set_heading(target)
	var reached := -1.0
	var worst := 0.0
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 8000:
		var err := rad_to_deg((_hull.global_basis * Vector3.FORWARD).angle_to(target))
		if reached < 0.0 and err < 0.5:
			reached = (Time.get_ticks_msec() - t1) / 1000.0
		if reached >= 0.0:
			worst = maxf(worst, err)
		await physics_frame
	print("heading 120: within 0.5 deg at %.2f s, worst after %.2f deg" % [reached, worst])
	_fc.clear_heading()

	# 6. Frame rate in the cockpit with thrusters firing hard.
	var samples: Array[float] = []
	var t2 := Time.get_ticks_msec()
	var flip := false
	while Time.get_ticks_msec() - t2 < 4000:
		Input.action_release(&"pitch_up" if flip else &"pitch_down")
		Input.action_press(&"pitch_down" if flip else &"pitch_up")
		flip = not flip
		await _wait(0.25)
		samples.append(Engine.get_frames_per_second())
	Input.action_release(&"pitch_up")
	Input.action_release(&"pitch_down")
	samples.sort()
	print("cockpit fps with RCS firing: min %.0f, median %.0f" % [samples[0], samples[samples.size() / 2]])

	# 7. Chase view, rolling.
	_director.cycle_view()
	Input.action_press(&"roll_left")
	await _wait(0.25)
	await _shot("5_chase_roll")
	Input.action_release(&"roll_left")
	quit()

func _height() -> float:
	return root.get_visible_rect().size.y

func _motion(relative: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	return ev

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + shot_name + ".png")
	print("saved ", OUT, shot_name, ".png")
```

- [ ] **Step 2: Run it on the real renderer (not headless) at 1280×720**

Run:

```powershell
& "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" --path .\who-knows --resolution 1280x720 -s "<scratchpad>\flight_check.gd"
```

Check the printed lines:
- keys and stick yaw rates near 60 deg/s (assist on);
- lock+turn: travel on the nose within about 5 s, speed back near 100 m/s;
- heading 120: within 0.5° in under 5 s, worst after under 2°;
- cockpit fps with RCS firing: record it. The budget is 120 fps on the GTX 960 (style guide
  §2.6). If this machine's figure is well above the at-rest figure from the same run, fine.
  If the puffs cost more than about 10% of the frame, reduce `PUFFS` or the puff scale and
  re-measure.
- No `SHADER ERROR` or GDScript errors in the output.

- [ ] **Step 3: Look at the renders**

Open each PNG with the Read tool:
- the nose puffs read through the canopy in shots 1–2;
- they are chunky, pale and flat-lit, not white-out;
- the stick ring shows in shot 4 and the controls card in shot 3;
- the chase shot shows the rolling pair puffing.

If a puff reads too small or too large, tune `scale_min`, `scale_max` and `Puffs.grow(...)` in
`RcsShow._process_material` and re-run. Send the final renders to the owner with
`SendUserFile`, captioned with the measured numbers.

- [ ] **Step 4: The owner flies it**

Ask the owner to play (`who-knows\play.bat`) and fly the §9.3 checklist:
- steady turns by stick and by keys;
- a locked-speed turn;
- click a heading, then nudge the stick;
- set a heading and a lock, stand up and walk aft;
- assist off.

Tune `PilotStick.RADIUS`, `DEADZONE`, `CURVE`, `HOLD_BRAKE_SHARE` and `HOLD_GAIN` from their
feedback. Any constant a test pins changes in the test in the same commit. Re-run the whole
suite.

- [ ] **Step 5: Commit any tuning**

```bash
git add -u who-knows
git commit -m "tune: flight controls, from flying them

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Skip if nothing changed.)

---

### Task 11: Record it in the docs

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-flight-controls-design.md`
- Modify: `docs/superpowers/specs/2026-08-21-who-knows-slice-1-design.md` (§7.1)
- Modify: `docs/superpowers/specs/2026-08-23-piloting-hud-design.md` (§7)
- Modify: `docs/design/visual-style.md` (§4)

- [ ] **Step 1: The flight controls spec**

- Set **Status** to `Approved by the owner on 2026-09-25; built on branch flight-controls.`
- Under §9.3, add a short "As built" list:
  - the final values of `STICK_RADIUS`, `STICK_DEADZONE`, the curve, `HOLD_BRAKE_SHARE` and
    `HOLD_GAIN`;
  - the Task 10 measurements (turn rates, lock+turn time, heading settle and overshoot, cockpit
    fps with RCS firing).

- [ ] **Step 2: Slice spec §7.1**

Replace the line starting `Controls: \`WASD\` translate, mouse pitch/yaw` with:

```markdown
Controls: `docs/superpowers/specs/2026-09-25-flight-controls-design.md` §4. `WASD` translate
(let go to brake), `Shift`/`Ctrl` vertical, a virtual stick on the mouse and the arrow keys for
pitch and yaw, `Q`/`E` roll, hold right mouse and click to set a heading, `C` speed lock,
`Space` boost, `Z` assist, `F` leave seat, `V` camera, `H` controls card.
```

- [ ] **Step 3: Piloting HUD spec §7**

After the `**VelocityPanel**` paragraph, add:

```markdown
Flight controls spec §8 adds a second line to the panel: `LOCK <speed> M/S` while the speed is
locked and `HDG HOLD` while the flight computer holds a heading. The same spec adds the stick
cursor, the heading marker (mounted twice, like the velocity marker) and the controls card.
```

- [ ] **Step 4: Style guide §4**

After the **Anything on the hull's outside** paragraph, add:

```markdown
**Thruster puffs** (`RcsShow`, flight controls spec §6): the same chunky, flat-lit puff as the
airlock's burst (`Puffs`), world-space and holding the origin's shift, on render layer 1 so
windows show them. No new shader.
```

- [ ] **Step 5: Commit**

```bash
git add docs
git commit -m "docs: record the flight controls in the specs and the style guide

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: Finish the branch**

Use superpowers:finishing-a-development-branch to merge `flight-controls` into `main` as the
earlier features were (a merge commit, `Merge branch 'flight-controls'`), after the whole suite
passes on the merged result.
