# Piloting HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the pilot a heads-up display while flying — speed against the cruise ceiling, assist and boost state, per-axis rotation rates, and a prograde/boresight velocity marker on the canopy — built so Slice 2's weapons and hull health extend it by adding a field and an element.

**Architecture:** A vehicle produces one immutable `VehicleTelemetry` snapshot per frame through a single duck-typed method, `build_telemetry()`. `HudRoot` (a global `CanvasLayer`) pulls that snapshot and pushes it to independent `HudElement` nodes that each read only the fields they need. Abstract numerics render screen-space in a console band along the bottom; world-registered elements render *inside* the ship's canopy `SubViewport`, because in cockpit view the player sees a picture of space rather than space, and only the camera that rendered that picture can project onto it correctly.

**Tech Stack:** Godot 4.5.1 (mono build), GDScript, GUT for headless unit tests.

**Spec:** `docs/superpowers/specs/2026-08-23-piloting-hud-design.md`

## Global Constraints

- **Godot 4.5.1**, Forward Plus renderer. Tests run headless via `who-knows/run_tests.ps1`.
- **Indent with tabs.** Every existing `.gd` file in this repo uses tabs. Do not introduce spaces.
- **`##` doc comments** on every `class_name` and on any member whose purpose is not obvious from its name. Match the density of `src/flight/flight_computer.gd`.
- **Never put a `#` comment inside or adjacent to a `[node]`, `[sub_resource]`, or `[resource]` block in a `.tscn`/`.tres` file.** See `CLAUDE.md`. The Godot 4.5.1 text-scene parser silently corrupts the adjacent line with zero error output, and a clean headless load does **not** catch it. Narrative explanation goes in the `.gd` doc comments.
- **Colours come only from `HudPalette`.** No element names a colour literal. Values trace to `docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md` §5.2.
- **Nothing in `src/ui/` may reference `Ship`, `RigidBody3D`, `FlightComputer`, or `CameraDirector`.** That isolation is the feature — it is what makes the HUD work for any future vehicle. A task that breaks it has failed even if its tests pass.
- **Elements build their own child controls in `_ready()`, in code.** Do not author panel internals in `.tscn`. This keeps the scene-file surface (and therefore exposure to the parser defect above) down to a handful of nodes, and makes every element testable headless.

### Two refinements to the spec's naming, applied throughout

The spec was approved before these were worked through. Both are deliberate; use the names in this plan.

| Spec said | This plan uses | Why |
|---|---|---|
| `HudPanel` base class; `register_marker()` | **`HudElement`** base class; **`register_element()`** | `VelocityMarker` extends the same base as the panels, so distribution is one type check and one loop. "Panel" is a poor name for a full-rect reticle overlay. |
| `HudRoot` → `Band`, `ChaseMarker` | `HudRoot` → **`Screen`** → `Band`, `ChaseMarker` | `CanvasLayer` has no `modulate`, so it cannot fade. One full-rect `Screen` Control wraps both and becomes the single fade target. |

---

## File Structure

| File | Responsibility |
|---|---|
| `src/ui/vehicle_telemetry.gd` | `VehicleTelemetry` — immutable per-frame snapshot. Pure data plus one static factory. |
| `src/ui/hud_palette.gd` | `HudPalette` — the art-direction colours. Constants only. |
| `src/ui/hud_element.gd` | `HudElement` — `Control` base. One virtual method, `render(t)`. |
| `src/ui/hud_root.gd` | `HudRoot` — `CanvasLayer`. Owns the active source, arming, fade, and distribution. |
| `src/ui/velocity_marker.gd` | `VelocityMarker` — the prograde ring and boresight. Pure `resolve()` policy plus a thin camera adapter. |
| `src/ui/panels/velocity_panel.gd` | `VelocityPanel` — speed numeral, cruise bar, assist/boost flags. |
| `src/ui/panels/attitude_panel.gd` | `AttitudePanel` — three centre-zero rotation tracks and a settled indicator. |
| `src/flight/flight_computer.gd` | **Modified.** Gains `build_telemetry()`. One method, no new state. |
| `src/camera/camera_director.gd` | **Modified.** Gains the `piloting_changed(piloting: bool)` signal. |
| `scenes/flight_test.gd` | **Modified.** Bootstrap wiring, so `src/ui/` stays ignorant of ships. |
| `scenes/flight_test.tscn` | **Modified.** Six new nodes. Highest-risk file in the plan — see the constraint above. |
| `run_tests.ps1` | **Modified.** Argument passthrough so single suites can be run. |

Test files mirror the source: `test/unit/test_vehicle_telemetry.gd`, `test_velocity_marker.gd`, `test_hud_panels.gd`, `test_hud_root.gd`, `test_hud_scene_wiring.gd`.

---

### Task 1: Telemetry snapshot and the vehicle contract

**Files:**
- Create: `who-knows/src/ui/vehicle_telemetry.gd`
- Test: `who-knows/test/unit/test_vehicle_telemetry.gd`
- Modify: `who-knows/src/flight/flight_computer.gd` (append one method)
- Modify: `who-knows/run_tests.ps1` (argument passthrough)

**Interfaces:**
- Consumes: nothing.
- Produces: `VehicleTelemetry` with fields `speed: float`, `cruise_limit: float`, `world_velocity: Vector3`, `local_velocity: Vector3`, `local_angular_velocity: Vector3`, `assist_enabled: bool`, `boost_active: bool`, `hull_origin: Vector3`; static `VehicleTelemetry.from_state(basis: Basis, origin: Vector3, linear_velocity: Vector3, angular_velocity: Vector3, assist: bool, boost: bool, limit: float) -> VehicleTelemetry`. Also `FlightComputer.build_telemetry() -> VehicleTelemetry`.

- [ ] **Step 1: Add argument passthrough to the test runner**

Replace the final two lines of `who-knows/run_tests.ps1` with:

```powershell
& $godot --headless --path $PSScriptRoot -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json @args
exit $LASTEXITCODE
```

This lets every later step run one suite instead of all of them. Verify the full run still works:

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1
```

Expected: the existing suite runs and passes, exactly as before.

- [ ] **Step 2: Write the failing test**

Create `who-knows/test/unit/test_vehicle_telemetry.gd`:

```gdscript
extends GutTest

## A basis yawed 90 degrees about +Y. Under it, world -Z maps to local +X.
func _yawed() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(90.0))

func test_speed_is_velocity_magnitude():
	var t := VehicleTelemetry.from_state(
		Basis.IDENTITY, Vector3.ZERO,
		Vector3(3.0, 0.0, 4.0), Vector3.ZERO,
		true, false, 120.0
	)
	assert_almost_eq(t.speed, 5.0, 0.001, "3-4-5 triangle")

func test_world_velocity_is_stored_unrotated():
	var v := Vector3(0.0, 0.0, -10.0)
	var t := VehicleTelemetry.from_state(
		_yawed(), Vector3.ZERO, v, Vector3.ZERO, true, false, 120.0
	)
	assert_almost_eq(t.world_velocity.z, -10.0, 0.001, "world velocity untouched")

func test_local_velocity_is_expressed_in_hull_basis():
	# Ship yawed 90 degrees, travelling along world -Z. In its own frame that
	# is straight out the left/right beam, not out the nose.
	var t := VehicleTelemetry.from_state(
		_yawed(), Vector3.ZERO,
		Vector3(0.0, 0.0, -10.0), Vector3.ZERO,
		true, false, 120.0
	)
	assert_almost_eq(t.local_velocity.z, 0.0, 0.001, "nothing along local Z")
	assert_almost_eq(absf(t.local_velocity.x), 10.0, 0.001, "all of it across the beam")

func test_local_angular_velocity_is_expressed_in_hull_basis():
	# Godot reports angular_velocity in the world frame. Rolling about the
	# hull's own nose axis must land on local Z regardless of hull attitude.
	var world_spin: Vector3 = _yawed() * Vector3(0.0, 0.0, 2.0)
	var t := VehicleTelemetry.from_state(
		_yawed(), Vector3.ZERO, Vector3.ZERO, world_spin, true, false, 120.0
	)
	assert_almost_eq(t.local_angular_velocity.z, 2.0, 0.001, "roll on local Z")
	assert_almost_eq(t.local_angular_velocity.x, 0.0, 0.001, "no pitch")
	assert_almost_eq(t.local_angular_velocity.y, 0.0, 0.001, "no yaw")

func test_flags_and_limit_pass_through():
	var t := VehicleTelemetry.from_state(
		Basis.IDENTITY, Vector3(1.0, 2.0, 3.0),
		Vector3.ZERO, Vector3.ZERO,
		false, true, 99.0
	)
	assert_false(t.assist_enabled, "assist off")
	assert_true(t.boost_active, "boost on")
	assert_almost_eq(t.cruise_limit, 99.0, 0.001, "limit carried, never hardcoded downstream")
	assert_eq(t.hull_origin, Vector3(1.0, 2.0, 3.0), "origin carried for projection")
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_vehicle_telemetry.gd"
```

Expected: FAIL — the parser cannot resolve the identifier `VehicleTelemetry`.

- [ ] **Step 4: Write the snapshot**

Create `who-knows/src/ui/vehicle_telemetry.gd`:

```gdscript
class_name VehicleTelemetry
extends RefCounted

## One frame's worth of a vehicle's state, as the HUD needs to read it.
##
## Built fresh each frame and never mutated afterwards. Deliberately holds
## no node references: an element that receives this cannot reach back into
## the ship, which is what keeps src/ui free of vehicle-specific types.

var speed: float = 0.0
## The vehicle's own cruise ceiling, so no readout hardcodes 120.
var cruise_limit: float = 0.0
## World frame. The velocity marker projects `hull_origin + world_velocity`.
var world_velocity: Vector3 = Vector3.ZERO
## Velocity in the hull's frame. X is drift across the beam, Y is vertical,
## -Z is out the nose. This is the drift readout.
var local_velocity: Vector3 = Vector3.ZERO
## Rotation about the hull's own axes as (pitch, yaw, roll), radians/sec.
var local_angular_velocity: Vector3 = Vector3.ZERO
var assist_enabled: bool = false
var boost_active: bool = false
var hull_origin: Vector3 = Vector3.ZERO

## Takes plain values rather than a body on purpose: it is the seam that lets
## every derivation here be tested headless, with no nodes and no physics
## steps. Callers holding a RigidBody3D adapt in one line -- see
## FlightComputer.build_telemetry().
static func from_state(
	basis: Basis,
	origin: Vector3,
	linear_velocity: Vector3,
	angular_velocity: Vector3,
	assist: bool,
	boost: bool,
	limit: float
) -> VehicleTelemetry:
	var t := VehicleTelemetry.new()
	# One inverse, reused. Godot reports both velocities in the world frame.
	var inv := basis.inverse()
	t.world_velocity = linear_velocity
	t.local_velocity = inv * linear_velocity
	t.local_angular_velocity = inv * angular_velocity
	t.speed = linear_velocity.length()
	t.hull_origin = origin
	t.assist_enabled = assist
	t.boost_active = boost
	t.cruise_limit = limit
	return t
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_vehicle_telemetry.gd"
```

Expected: PASS, 5 tests.

- [ ] **Step 6: Add the adapter to FlightComputer**

Append to `who-knows/src/flight/flight_computer.gd`, at the end of the file:

```gdscript
## The vehicle-facing half of the HUD contract. Any node with this method is
## a telemetry source as far as HudRoot is concerned -- there is no interface
## type and no base class to inherit, which is what lets a future ground
## vehicle or turret station light the same HUD.
func build_telemetry() -> VehicleTelemetry:
	return VehicleTelemetry.from_state(
		_hull.global_transform.basis,
		_hull.global_position,
		_hull.linear_velocity,
		_hull.angular_velocity,
		assist_enabled,
		_boost,
		CRUISE_LIMIT_MPS
	)
```

- [ ] **Step 7: Run the whole suite**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1
```

Expected: PASS, all suites green including the pre-existing ones.

- [ ] **Step 8: Commit**

```bash
git add who-knows/src/ui/vehicle_telemetry.gd who-knows/test/unit/test_vehicle_telemetry.gd who-knows/src/flight/flight_computer.gd who-knows/run_tests.ps1
git commit -m "feat: add VehicleTelemetry snapshot and the build_telemetry contract"
```

---

### Task 2: Palette, element base, and the velocity panel

**Files:**
- Create: `who-knows/src/ui/hud_palette.gd`
- Create: `who-knows/src/ui/hud_element.gd`
- Create: `who-knows/src/ui/hud_band.gd`
- Create: `who-knows/src/ui/panels/velocity_panel.gd`
- Test: `who-knows/test/unit/test_hud_panels.gd`

**Interfaces:**
- Consumes: `VehicleTelemetry` from Task 1.
- Produces: `HudPalette.READOUT`, `.WARNING`, `.BACKDROP`, `.BORDER`, `.DIM` (all `Color` constants); `HudElement` with `render(telemetry: VehicleTelemetry) -> void`; `HudBand` (extends `PanelContainer`, no public API — it styles itself); `VelocityPanel` with `const AMBER_FRACTION := 0.9` and readable members `speed_label: Label`, `mode_label: Label`, `bar_fill: ColorRect`, `bar_track: ColorRect`.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_hud_panels.gd`:

```gdscript
extends GutTest

func _telemetry(speed: float, limit: float, assist: bool, boost: bool) -> VehicleTelemetry:
	return VehicleTelemetry.from_state(
		Basis.IDENTITY, Vector3.ZERO,
		Vector3(0.0, 0.0, -speed), Vector3.ZERO,
		assist, boost, limit
	)

func _velocity_panel() -> VelocityPanel:
	var p := VelocityPanel.new()
	add_child_autofree(p)
	return p

func test_velocity_panel_shows_rounded_speed():
	var p := _velocity_panel()
	p.render(_telemetry(87.4, 120.0, true, false))
	assert_eq(p.speed_label.text, "87", "speed rounded to whole m/s")

func test_velocity_panel_bar_fills_proportionally():
	var p := _velocity_panel()
	p.render(_telemetry(60.0, 120.0, true, false))
	assert_almost_eq(
		p.bar_fill.size.x, p.bar_track.size.x * 0.5, 0.5,
		"half the ceiling fills half the bar"
	)

func test_velocity_panel_bar_is_cyan_below_the_amber_threshold():
	var p := _velocity_panel()
	p.render(_telemetry(100.0, 120.0, true, false))
	assert_eq(p.bar_fill.color, HudPalette.READOUT, "100 of 120 is under 90 percent")

func test_velocity_panel_bar_goes_amber_at_the_threshold():
	var p := _velocity_panel()
	p.render(_telemetry(108.0, 120.0, true, false))
	assert_eq(p.bar_fill.color, HudPalette.WARNING, "exactly 90 percent warns")

func test_velocity_panel_pins_the_bar_over_the_ceiling():
	# Assist off removes the cruise clamp, so speed can exceed the ceiling.
	var p := _velocity_panel()
	p.render(_telemetry(200.0, 120.0, false, false))
	assert_almost_eq(p.bar_fill.size.x, p.bar_track.size.x, 0.5, "bar pins full")
	assert_eq(p.bar_fill.color, HudPalette.WARNING, "and warns")

func test_velocity_panel_shows_mode_flags():
	var p := _velocity_panel()
	p.render(_telemetry(10.0, 120.0, false, true))
	assert_string_contains(p.mode_label.text, "ASSIST OFF")
	assert_string_contains(p.mode_label.text, "BOOST ON")

func test_velocity_panel_ignores_a_null_snapshot():
	var p := _velocity_panel()
	p.render(_telemetry(87.0, 120.0, true, false))
	p.render(null)
	assert_eq(p.speed_label.text, "87", "last good reading is left alone")

func test_velocity_panel_survives_a_zero_ceiling():
	# A vehicle with no cruise limit must not divide by zero.
	var p := _velocity_panel()
	p.render(_telemetry(50.0, 0.0, false, false))
	assert_almost_eq(p.bar_fill.size.x, 0.0, 0.5, "no ceiling means no meaningful fill")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_hud_panels.gd"
```

Expected: FAIL — `VelocityPanel` and `HudPalette` are unresolved identifiers.

- [ ] **Step 3: Write the palette and the band's chrome**

Two files here, because they are the same concern: the colours, and the one surface that paints
with them.

Create `who-knows/src/ui/hud_palette.gd`:

```gdscript
class_name HudPalette
extends RefCounted

## The console palette, from
## docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md §5.2.
##
## Every HUD colour resolves here. No element names a literal, so retuning
## the ship's instrumentation is a change to this file and nowhere else.

## Normal readouts.
const READOUT := Color("7fd4ff")
## Anything the pilot should notice: over-ceiling, and later damage.
const WARNING := Color("ffb03a")
## The band's own ground. Dark and slightly transparent so it reads as a lit
## panel rather than as an opaque rectangle pasted over the scene.
const BACKDROP := Color(0.07, 0.10, 0.13, 0.92)
const BORDER := Color(0.498, 0.831, 1.0, 0.28)
## Labels and rules that should recede.
const DIM := Color(0.498, 0.831, 1.0, 0.55)
```

Then create `who-knows/src/ui/hud_band.gd`:

```gdscript
class_name HudBand
extends PanelContainer

## The console band's own surface -- the lit panel the readouts sit on.
##
## Without this the band is bare text floating over the scene, which reads as
## game chrome rather than as the ship's instrumentation. Built in code, not
## authored, for two reasons: the colours must come from HudPalette rather
## than being restated as literals in the scene file, and a StyleBoxFlat
## authored in .tscn would be another sub_resource block in exactly the file
## CLAUDE.md warns about.

const CORNER_RADIUS := 4
const CONTENT_MARGIN := 14

func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = HudPalette.BACKDROP
	box.border_color = HudPalette.BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.content_margin_left = CONTENT_MARGIN
	box.content_margin_right = CONTENT_MARGIN
	box.content_margin_top = CONTENT_MARGIN * 0.5
	box.content_margin_bottom = CONTENT_MARGIN * 0.5
	add_theme_stylebox_override("panel", box)
```

- [ ] **Step 4: Write the element base**

Create `who-knows/src/ui/hud_element.gd`:

```gdscript
class_name HudElement
extends Control

## Base for everything the HUD draws -- the console band's readouts and the
## canopy's velocity marker alike.
##
## HudRoot pushes one snapshot per frame. A null snapshot means no vehicle is
## being piloted; elements that hold a last-good reading may simply ignore it,
## because HudRoot fades the whole layer out. Elements that draw world-derived
## geometry must stop drawing, since a stale reticle would point at a lie.

func render(_telemetry: VehicleTelemetry) -> void:
	pass
```

- [ ] **Step 5: Write the velocity panel**

Create `who-knows/src/ui/panels/velocity_panel.gd`:

```gdscript
class_name VelocityPanel
extends HudElement

## Speed against the cruise ceiling, plus the two flight-mode flags.
##
## Children are built in code rather than authored in the scene. That keeps
## flight_test.tscn small -- see CLAUDE.md on the text-scene parser defect --
## and lets every assertion below run headless.

## Fraction of the ceiling at which the bar starts warning.
const AMBER_FRACTION := 0.9

const BAR_WIDTH := 150.0
const BAR_HEIGHT := 4.0

var speed_label: Label
var units_label: Label
var bar_track: ColorRect
var bar_fill: ColorRect
var mode_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(320.0, 56.0)

	speed_label = Label.new()
	speed_label.text = "0"
	speed_label.add_theme_font_size_override("font_size", 30)
	speed_label.add_theme_color_override("font_color", HudPalette.READOUT)
	speed_label.position = Vector2(0.0, 0.0)
	add_child(speed_label)

	units_label = Label.new()
	units_label.text = "M/S"
	units_label.add_theme_font_size_override("font_size", 10)
	units_label.add_theme_color_override("font_color", HudPalette.DIM)
	units_label.position = Vector2(62.0, 18.0)
	add_child(units_label)

	bar_track = ColorRect.new()
	bar_track.color = Color(HudPalette.READOUT, 0.18)
	bar_track.position = Vector2(0.0, 40.0)
	bar_track.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	add_child(bar_track)

	bar_fill = ColorRect.new()
	bar_fill.color = HudPalette.READOUT
	bar_fill.position = Vector2(0.0, 40.0)
	bar_fill.size = Vector2(0.0, BAR_HEIGHT)
	add_child(bar_fill)

	mode_label = Label.new()
	mode_label.text = "ASSIST ON   BOOST OFF"
	mode_label.add_theme_font_size_override("font_size", 11)
	mode_label.add_theme_color_override("font_color", HudPalette.READOUT)
	mode_label.position = Vector2(170.0, 38.0)
	add_child(mode_label)

func render(telemetry: VehicleTelemetry) -> void:
	if telemetry == null:
		return

	speed_label.text = "%d" % roundi(telemetry.speed)

	# A vehicle with no declared ceiling gets an empty bar rather than a
	# division by zero. The numeral still reads correctly.
	var fraction := 0.0
	if telemetry.cruise_limit > 0.0:
		fraction = clampf(telemetry.speed / telemetry.cruise_limit, 0.0, 1.0)
	bar_fill.size.x = bar_track.size.x * fraction

	# Assist off removes the cruise clamp entirely, so speed can sit above the
	# ceiling. The bar pins and warns instead of silently misreporting.
	var warn := telemetry.cruise_limit > 0.0 \
		and telemetry.speed >= telemetry.cruise_limit * AMBER_FRACTION
	bar_fill.color = HudPalette.WARNING if warn else HudPalette.READOUT

	mode_label.text = "ASSIST %s   BOOST %s" % [
		"ON" if telemetry.assist_enabled else "OFF",
		"ON" if telemetry.boost_active else "OFF",
	]
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_hud_panels.gd"
```

Expected: PASS, 8 tests.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/ui/hud_palette.gd who-knows/src/ui/hud_element.gd who-knows/src/ui/hud_band.gd who-knows/src/ui/panels/velocity_panel.gd who-knows/test/unit/test_hud_panels.gd
git commit -m "feat: add HUD palette, band chrome, element base, and the velocity panel"
```

---

### Task 3: Attitude panel

**Files:**
- Create: `who-knows/src/ui/panels/attitude_panel.gd`
- Modify: `who-knows/test/unit/test_hud_panels.gd` (append)

**Interfaces:**
- Consumes: `HudElement`, `HudPalette`, `VehicleTelemetry`.
- Produces: `AttitudePanel` with `const DISPLAY_MAX_RAD := 1.5`, `const SETTLED_RAD := 0.05`, and readable members `pitch_pip: ColorRect`, `yaw_pip: ColorRect`, `roll_pip: ColorRect`, `track_width: float`, `settled_label: Label`.

- [ ] **Step 1: Write the failing test**

Append to `who-knows/test/unit/test_hud_panels.gd`:

```gdscript
func _spinning(pitch: float, yaw: float, roll: float) -> VehicleTelemetry:
	return VehicleTelemetry.from_state(
		Basis.IDENTITY, Vector3.ZERO,
		Vector3.ZERO, Vector3(pitch, yaw, roll),
		true, false, 120.0
	)

func _attitude_panel() -> AttitudePanel:
	var p := AttitudePanel.new()
	add_child_autofree(p)
	return p

func test_attitude_pips_centre_when_not_rotating():
	var p := _attitude_panel()
	p.render(_spinning(0.0, 0.0, 0.0))
	var centre := p.track_width * 0.5 - p.pitch_pip.size.x * 0.5
	assert_almost_eq(p.pitch_pip.position.x, centre, 0.5, "pitch centred")
	assert_almost_eq(p.yaw_pip.position.x, centre, 0.5, "yaw centred")
	assert_almost_eq(p.roll_pip.position.x, centre, 0.5, "roll centred")

func test_attitude_pip_travels_right_at_full_positive_rate():
	var p := _attitude_panel()
	p.render(_spinning(AttitudePanel.DISPLAY_MAX_RAD, 0.0, 0.0))
	assert_almost_eq(
		p.pitch_pip.position.x, p.track_width - p.pitch_pip.size.x * 0.5, 0.5,
		"full positive pitch pins right"
	)

func test_attitude_pip_travels_left_at_full_negative_rate():
	var p := _attitude_panel()
	p.render(_spinning(0.0, -AttitudePanel.DISPLAY_MAX_RAD, 0.0))
	assert_almost_eq(
		p.yaw_pip.position.x, -p.yaw_pip.size.x * 0.5, 0.5,
		"full negative yaw pins left"
	)

func test_attitude_pip_clamps_beyond_the_display_maximum():
	var p := _attitude_panel()
	p.render(_spinning(0.0, 0.0, AttitudePanel.DISPLAY_MAX_RAD * 10.0))
	assert_almost_eq(
		p.roll_pip.position.x, p.track_width - p.roll_pip.size.x * 0.5, 0.5,
		"a wild tumble pins rather than leaving the panel"
	)

func test_attitude_reports_settled_when_rotation_is_negligible():
	var p := _attitude_panel()
	p.render(_spinning(0.001, 0.001, 0.001))
	assert_true(p.settled_label.visible, "settled shown")

func test_attitude_hides_settled_while_still_turning():
	var p := _attitude_panel()
	p.render(_spinning(0.5, 0.0, 0.0))
	assert_false(p.settled_label.visible, "not settled while pitching")

func test_attitude_ignores_a_null_snapshot():
	var p := _attitude_panel()
	p.render(_spinning(AttitudePanel.DISPLAY_MAX_RAD, 0.0, 0.0))
	var before := p.pitch_pip.position.x
	p.render(null)
	assert_almost_eq(p.pitch_pip.position.x, before, 0.5, "last good reading left alone")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_hud_panels.gd"
```

Expected: FAIL — `AttitudePanel` is an unresolved identifier. The Task 2 tests in the same file still pass.

- [ ] **Step 3: Write the attitude panel**

Create `who-knows/src/ui/panels/attitude_panel.gd`:

```gdscript
class_name AttitudePanel
extends HudElement

## Rotation rate about each of the hull's own axes, as three centre-zero
## tracks, plus a settled indicator.
##
## This is what tells the pilot whether FlightComputer's rotation damping has
## actually finished before they commit to a burn -- a ship that still has
## residual spin will curve away from wherever they aimed it.

## Rate that pins a pip to the end of its track, radians/sec.
##
## Deliberately set for a ship that turns properly, not for the one that
## exists today. SLICE-1-STATUS.md records peak yaw acceleration at
## 3.83 deg/s^2 with assist damping exceeding control authority by 1.66x, so
## until torque_budget is reworked the pips will sit closer to centre than
## this constant implies. Tuning it down to flatter the current defect would
## only mean retuning it once that defect is fixed.
const DISPLAY_MAX_RAD := 1.5
## Total rotation magnitude below which the ship counts as settled.
const SETTLED_RAD := 0.05

const TRACK_WIDTH := 84.0
const TRACK_HEIGHT := 3.0
const PIP_WIDTH := 3.0
const PIP_HEIGHT := 7.0
const ROW_SPACING := 14.0

var track_width: float = TRACK_WIDTH
var pitch_pip: ColorRect
var yaw_pip: ColorRect
var roll_pip: ColorRect
var settled_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(150.0, 56.0)
	pitch_pip = _build_row("PITCH", 0)
	yaw_pip = _build_row("YAW", 1)
	roll_pip = _build_row("ROLL", 2)

	settled_label = Label.new()
	settled_label.text = "SETTLED"
	settled_label.add_theme_font_size_override("font_size", 9)
	settled_label.add_theme_color_override("font_color", HudPalette.DIM)
	settled_label.position = Vector2(0.0, ROW_SPACING * 3.0)
	settled_label.visible = false
	add_child(settled_label)

## Builds one labelled track and returns its pip.
func _build_row(caption: String, row: int) -> ColorRect:
	var y := row * ROW_SPACING

	var name_label := Label.new()
	name_label.text = caption
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", HudPalette.DIM)
	name_label.position = Vector2(0.0, y - 2.0)
	add_child(name_label)

	var track := ColorRect.new()
	track.color = Color(HudPalette.READOUT, 0.18)
	track.position = Vector2(40.0, y + 3.0)
	track.size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	add_child(track)

	# The zero rule. Reading a pip against the centre is the whole point, so
	# the centre has to be visible when the pip is elsewhere.
	var zero := ColorRect.new()
	zero.color = Color(HudPalette.READOUT, 0.35)
	zero.position = Vector2(40.0 + TRACK_WIDTH * 0.5, y + 1.0)
	zero.size = Vector2(1.0, PIP_HEIGHT)
	add_child(zero)

	var pip := ColorRect.new()
	pip.color = HudPalette.READOUT
	pip.size = Vector2(PIP_WIDTH, PIP_HEIGHT)
	# Parented to the track, so this position is relative to it: centred
	# horizontally, and lifted so the taller pip straddles the thin track.
	pip.position = Vector2(
		TRACK_WIDTH * 0.5 - PIP_WIDTH * 0.5,
		(TRACK_HEIGHT - PIP_HEIGHT) * 0.5
	)
	track.add_child(pip)
	return pip

func render(telemetry: VehicleTelemetry) -> void:
	if telemetry == null:
		return
	var rates := telemetry.local_angular_velocity
	_place(pitch_pip, rates.x)
	_place(yaw_pip, rates.y)
	_place(roll_pip, rates.z)
	settled_label.visible = rates.length() < SETTLED_RAD

## Maps a rate onto its track, clamped, and centres the pip on that point.
func _place(pip: ColorRect, rate: float) -> void:
	var fraction := clampf(rate / DISPLAY_MAX_RAD, -1.0, 1.0)
	var centre := TRACK_WIDTH * 0.5
	pip.position.x = centre + centre * fraction - PIP_WIDTH * 0.5
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_hud_panels.gd"
```

Expected: PASS, 15 tests (8 from Task 2, 7 new).

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ui/panels/attitude_panel.gd who-knows/test/unit/test_hud_panels.gd
git commit -m "feat: add the attitude panel with centre-zero rotation tracks"
```

---

### Task 4: The velocity marker's state policy

This task builds only the pure decision function. Drawing and the camera come in Task 5, so a reviewer can reject the geometry rules without also relitigating the rendering.

**Files:**
- Create: `who-knows/src/ui/velocity_marker.gd`
- Test: `who-knows/test/unit/test_velocity_marker.gd`

**Interfaces:**
- Consumes: `HudElement`.
- Produces: `VelocityMarker.Mode` enum with members `HIDDEN`, `ON_FRAME`, `CLAMPED_AHEAD`, `CLAMPED_BEHIND`; `const MIN_SPEED_MPS := 1.0`; `const EDGE_MARGIN_PX := 16.0`; static `VelocityMarker.resolve(speed: float, is_behind: bool, screen_pos: Vector2, viewport_size: Vector2) -> Dictionary` returning `{"mode": int, "position": Vector2}`.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_velocity_marker.gd`:

```gdscript
extends GutTest

## The canopy SubViewport's authored size, so the numbers below are the ones
## the real cockpit will produce.
const VP := Vector2(1024.0, 512.0)
const CENTRE := Vector2(512.0, 256.0)

func test_hidden_below_the_speed_deadband():
	# At rest the velocity direction is numerical noise, so an unguarded ring
	# strobes around the frame.
	var s := VelocityMarker.resolve(0.5, false, Vector2(600.0, 300.0), VP)
	assert_eq(s["mode"], VelocityMarker.Mode.HIDDEN, "under 1 m/s stays hidden")

func test_visible_at_the_deadband_threshold():
	var s := VelocityMarker.resolve(1.0, false, Vector2(600.0, 300.0), VP)
	assert_eq(s["mode"], VelocityMarker.Mode.ON_FRAME, "exactly 1 m/s shows")

func test_on_frame_passes_the_projected_point_through_untouched():
	var pos := Vector2(600.0, 300.0)
	var s := VelocityMarker.resolve(50.0, false, pos, VP)
	assert_eq(s["mode"], VelocityMarker.Mode.ON_FRAME)
	assert_eq(s["position"], pos, "no adjustment inside the frame")

func test_ahead_but_off_frame_clamps_to_the_inset_edge():
	var s := VelocityMarker.resolve(50.0, false, Vector2(2000.0, 256.0), VP)
	assert_eq(s["mode"], VelocityMarker.Mode.CLAMPED_AHEAD)
	assert_almost_eq(
		s["position"].x, VP.x - VelocityMarker.EDGE_MARGIN_PX, 0.001,
		"pinned one margin in from the right edge"
	)
	assert_almost_eq(s["position"].y, CENTRE.y, 0.001, "still on the centreline")

func test_behind_clamps_to_the_opposite_edge():
	# unproject_position mirrors points that are behind the camera, so the
	# raw screen position points the wrong way and must be negated about
	# centre before clamping.
	var s := VelocityMarker.resolve(50.0, true, Vector2(600.0, 256.0), VP)
	assert_eq(s["mode"], VelocityMarker.Mode.CLAMPED_BEHIND)
	assert_almost_eq(
		s["position"].x, VelocityMarker.EDGE_MARGIN_PX, 0.001,
		"a point mirrored to the right of centre belongs on the left edge"
	)

func test_behind_clamps_on_the_vertical_axis_too():
	var s := VelocityMarker.resolve(50.0, true, Vector2(512.0, 100.0), VP)
	assert_eq(s["mode"], VelocityMarker.Mode.CLAMPED_BEHIND)
	assert_almost_eq(
		s["position"].y, VP.y - VelocityMarker.EDGE_MARGIN_PX, 0.001,
		"mirrored above centre belongs on the bottom edge"
	)

func test_a_point_exactly_at_centre_while_behind_does_not_divide_by_zero():
	# Flying dead astern: the mirrored point lands on centre and has no
	# direction. Must pick one rather than produce NAN.
	var s := VelocityMarker.resolve(50.0, true, CENTRE, VP)
	assert_eq(s["mode"], VelocityMarker.Mode.CLAMPED_BEHIND)
	assert_false(is_nan(s["position"].x), "x is a real number")
	assert_false(is_nan(s["position"].y), "y is a real number")

func test_clamped_points_land_on_the_inset_rectangle():
	# Whatever direction it is pushed, a clamped marker sits exactly one
	# margin inside the frame on at least one axis.
	for pos in [Vector2(3000.0, 3000.0), Vector2(-500.0, 20.0), Vector2(700.0, -900.0)]:
		var s := VelocityMarker.resolve(50.0, false, pos, VP)
		assert_eq(s["mode"], VelocityMarker.Mode.CLAMPED_AHEAD, "off-frame clamps")
		var m: float = VelocityMarker.EDGE_MARGIN_PX
		var on_x: bool = is_equal_approx(s["position"].x, m) \
			or is_equal_approx(s["position"].x, VP.x - m)
		var on_y: bool = is_equal_approx(s["position"].y, m) \
			or is_equal_approx(s["position"].y, VP.y - m)
		assert_true(on_x or on_y, "sits on the inset boundary for %s" % pos)
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_velocity_marker.gd"
```

Expected: FAIL — `VelocityMarker` is an unresolved identifier.

- [ ] **Step 3: Write the marker's policy**

Create `who-knows/src/ui/velocity_marker.gd`. Drawing and the camera adapter are added in Task 5; this step establishes the class and its pure decision function only.

```gdscript
class_name VelocityMarker
extends HudElement

## Where the vehicle is actually going, drawn over the scene it refers to.
##
## Mounted twice: once inside the ship's canopy SubViewport (projected with
## CanopyCam, so it agrees with the space visible through the glass) and once
## screen-space for chase view (projected with ChaseCamera). Same code, two
## cameras -- see the design doc §6 for why the cockpit case cannot be done
## screen-space.

enum Mode {
	HIDDEN,           ## below the speed deadband, or nothing to show
	ON_FRAME,         ## the real projected position
	CLAMPED_AHEAD,    ## ahead but outside the frame, pinned to the edge
	CLAMPED_BEHIND,   ## behind the camera, pinned to the opposite edge
}

## Below this, velocity direction is numerical noise rather than information.
const MIN_SPEED_MPS := 1.0
## How far inside the frame a clamped marker sits.
const EDGE_MARGIN_PX := 16.0

## Decides what the marker should show, given a projected point.
##
## Pure on purpose. The two rules it encodes are both traps that are easy to
## get wrong and impossible to notice in review: unproject_position() returns
## a mirrored, meaningless point for anything behind the camera, and velocity
## direction is noise at rest. Keeping them here means both are covered by
## tests that need no camera and no viewport.
static func resolve(
	speed: float,
	is_behind: bool,
	screen_pos: Vector2,
	viewport_size: Vector2
) -> Dictionary:
	if speed < MIN_SPEED_MPS:
		return {"mode": Mode.HIDDEN, "position": Vector2.ZERO}

	var centre := viewport_size * 0.5

	if is_behind:
		# The projected point is mirrored through centre, so negate the
		# offset to recover the true bearing before pinning it.
		return {
			"mode": Mode.CLAMPED_BEHIND,
			"position": _clamp_to_edge(-(screen_pos - centre), viewport_size),
		}

	var margin := Vector2(EDGE_MARGIN_PX, EDGE_MARGIN_PX)
	var inset := Rect2(margin, viewport_size - margin * 2.0)
	if inset.has_point(screen_pos):
		return {"mode": Mode.ON_FRAME, "position": screen_pos}

	return {
		"mode": Mode.CLAMPED_AHEAD,
		"position": _clamp_to_edge(screen_pos - centre, viewport_size),
	}

## Pushes `offset` out from centre until it meets the inset rectangle.
static func _clamp_to_edge(offset: Vector2, viewport_size: Vector2) -> Vector2:
	var centre := viewport_size * 0.5
	var half := centre - Vector2(EDGE_MARGIN_PX, EDGE_MARGIN_PX)

	# Dead astern (or dead ahead) leaves no bearing at all. Pick one rather
	# than divide by zero and hand NAN to the renderer.
	if offset.length_squared() < 0.000001:
		offset = Vector2.DOWN

	# Scale to whichever boundary is reached first.
	var sx := INF if is_zero_approx(offset.x) else half.x / absf(offset.x)
	var sy := INF if is_zero_approx(offset.y) else half.y / absf(offset.y)
	return centre + offset * minf(sx, sy)
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_velocity_marker.gd"
```

Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ui/velocity_marker.gd who-knows/test/unit/test_velocity_marker.gd
git commit -m "feat: add velocity marker clamp and deadband policy"
```

---

### Task 5: The velocity marker's camera adapter and drawing

**Files:**
- Modify: `who-knows/src/ui/velocity_marker.gd` (append)
- Modify: `who-knows/test/unit/test_velocity_marker.gd` (append)

**Interfaces:**
- Consumes: `VelocityMarker.resolve()` and `Mode` from Task 4; `HudPalette`; `VehicleTelemetry`.
- Produces: `VelocityMarker` with `@export var camera_path: NodePath`, and readable state `mode: int` (a `Mode` value) and `armed: bool`.

**Note on test coverage:** the `Camera3D` calls are deliberately *not* unit-tested. `unproject_position()` needs a live viewport and a real projection, so a headless test of it would assert against a fixture rather than against reality. The policy it feeds is fully covered by Task 4; the camera path is covered by the manual checklist in Task 7.

- [ ] **Step 1: Write the failing test**

Append to `who-knows/test/unit/test_velocity_marker.gd`:

```gdscript
func _marker() -> VelocityMarker:
	var m := VelocityMarker.new()
	m.size = VP
	add_child_autofree(m)
	return m

func _moving(speed: float) -> VehicleTelemetry:
	return VehicleTelemetry.from_state(
		Basis.IDENTITY, Vector3.ZERO,
		Vector3(0.0, 0.0, -speed), Vector3.ZERO,
		true, false, 120.0
	)

func test_marker_is_disarmed_without_a_snapshot():
	var m := _marker()
	m.render(null)
	assert_false(m.armed, "no telemetry means nothing to point at")
	assert_eq(m.mode, VelocityMarker.Mode.HIDDEN)

func test_marker_is_disarmed_without_a_camera():
	# camera_path is left empty, as it would be for a marker whose exported
	# path was dropped by the .tscn parser defect described in CLAUDE.md.
	var m := _marker()
	m.render(_moving(50.0))
	assert_false(m.armed, "no camera means no projection, so draw nothing")
	assert_eq(m.mode, VelocityMarker.Mode.HIDDEN)

func test_marker_disarms_again_when_piloting_ends():
	var m := _marker()
	m.render(_moving(50.0))
	m.render(null)
	assert_false(m.armed, "a stale reticle would point at a lie")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_velocity_marker.gd"
```

Expected: FAIL — `armed` and `mode` are not declared on `VelocityMarker`.

- [ ] **Step 3: Append the adapter and drawing**

Append to `who-knows/src/ui/velocity_marker.gd`:

```gdscript
const RING_RADIUS := 13.0
const RING_WING := 9.0
const BORESIGHT_GAP := 6.0
const BORESIGHT_ARM := 11.0
const CHEVRON_SIZE := 10.0
const LINE_WIDTH := 2.0
## How much a behind-the-camera marker is faded, so it never reads as a real
## position the pilot could steer toward.
const BEHIND_ALPHA := 0.5

## The camera whose projection this marker annotates. CanopyCam for the
## cockpit mount, ChaseCamera for the screen-space one.
@export var camera_path: NodePath

## True when there is a vehicle to report on and a camera to project with.
var armed: bool = false
var mode: int = Mode.HIDDEN

var _position: Vector2 = Vector2.ZERO
var _camera: Camera3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not camera_path.is_empty():
		_camera = get_node_or_null(camera_path) as Camera3D

func render(telemetry: VehicleTelemetry) -> void:
	# `current` is what gates the two mounts against each other: the chase
	# marker draws only while the chase camera is live, and the cockpit one
	# draws whenever its SubViewport camera is. Cycling views therefore needs
	# no signal -- whoever owns the view already flips `current`, and this
	# just notices.
	armed = telemetry != null and _camera != null and _camera.current
	if not armed:
		mode = Mode.HIDDEN
		queue_redraw()
		return

	var target := telemetry.hull_origin + telemetry.world_velocity
	var state := resolve(
		telemetry.speed,
		_camera.is_position_behind(target),
		_camera.unproject_position(target),
		size
	)
	mode = state["mode"]
	_position = state["position"]
	queue_redraw()

func _draw() -> void:
	if not armed:
		return
	_draw_boresight()
	match mode:
		Mode.ON_FRAME:
			_draw_ring(_position, 1.0)
		Mode.CLAMPED_AHEAD:
			_draw_chevron(_position, 1.0)
		Mode.CLAMPED_BEHIND:
			_draw_chevron(_position, BEHIND_ALPHA)

## The nose reference: four ticks around viewport centre. Static, because
## viewport centre IS where the hull points, by construction. The gap between
## this and the ring is the actual readout.
func _draw_boresight() -> void:
	var centre := size * 0.5
	var colour := Color(HudPalette.READOUT, 0.45)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(
			centre + direction * BORESIGHT_GAP,
			centre + direction * (BORESIGHT_GAP + BORESIGHT_ARM),
			colour,
			1.0
		)

func _draw_ring(at: Vector2, alpha: float) -> void:
	var colour := Color(HudPalette.READOUT, alpha)
	draw_arc(at, RING_RADIUS, 0.0, TAU, 32, colour, LINE_WIDTH)
	draw_line(at + Vector2(-RING_RADIUS - RING_WING, 0.0), at + Vector2(-RING_RADIUS, 0.0), colour, LINE_WIDTH)
	draw_line(at + Vector2(RING_RADIUS, 0.0), at + Vector2(RING_RADIUS + RING_WING, 0.0), colour, LINE_WIDTH)
	draw_line(at + Vector2(0.0, -RING_RADIUS - RING_WING), at + Vector2(0.0, -RING_RADIUS), colour, LINE_WIDTH)

## Clamped markers render as a chevron rather than a ring, so an edge-pinned
## marker never reads as a real position.
func _draw_chevron(at: Vector2, alpha: float) -> void:
	var colour := Color(HudPalette.READOUT, alpha)
	var direction := (at - size * 0.5).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var perpendicular := Vector2(-direction.y, direction.x)
	draw_colored_polygon(
		PackedVector2Array([
			at + direction * CHEVRON_SIZE,
			at - direction * CHEVRON_SIZE * 0.4 + perpendicular * CHEVRON_SIZE * 0.8,
			at - direction * CHEVRON_SIZE * 0.4 - perpendicular * CHEVRON_SIZE * 0.8,
		]),
		colour
	)
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_velocity_marker.gd"
```

Expected: PASS, 11 tests.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ui/velocity_marker.gd who-knows/test/unit/test_velocity_marker.gd
git commit -m "feat: draw the velocity marker ring, boresight, and edge chevrons"
```

---

### Task 6: HudRoot — arming, distribution, and fade

**Files:**
- Create: `who-knows/src/ui/hud_root.gd`
- Test: `who-knows/test/unit/test_hud_root.gd`

**Interfaces:**
- Consumes: `HudElement`, `VehicleTelemetry`.
- Produces: `HudRoot` (extends `CanvasLayer`) with `@export var screen_path: NodePath`, `const FADE_IN := 0.75`, `const FADE_OUT := 0.2`, and methods `set_active_vehicle(source: Node) -> void`, `register_element(element: HudElement) -> void`, `unregister_element(element: HudElement) -> void`, `refresh() -> void`, `is_armed() -> bool`.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_hud_root.gd`:

```gdscript
extends GutTest

## A minimal telemetry source. HudRoot never learns what a Ship is -- it only
## requires that a source can answer build_telemetry().
class StubSource:
	extends Node
	var calls: int = 0
	func build_telemetry() -> VehicleTelemetry:
		calls += 1
		return VehicleTelemetry.from_state(
			Basis.IDENTITY, Vector3.ZERO,
			Vector3(0.0, 0.0, -42.0), Vector3.ZERO,
			true, false, 120.0
		)

## A source that does not honour the contract at all.
class BrokenSource:
	extends Node

class RecordingElement:
	extends HudElement
	var last_telemetry: VehicleTelemetry = null
	var render_count: int = 0
	func render(telemetry: VehicleTelemetry) -> void:
		last_telemetry = telemetry
		render_count += 1

var _hud: HudRoot
var _screen: Control
var _child: RecordingElement

func before_each():
	_hud = HudRoot.new()
	_screen = Control.new()
	_screen.name = "Screen"
	_hud.add_child(_screen)
	_hud.screen_path = NodePath("Screen")
	_child = RecordingElement.new()
	_screen.add_child(_child)
	add_child_autofree(_hud)
	# Drive distribution only from explicit refresh() calls. Left enabled,
	# _process would fire on any frame boundary between tests and make the
	# call-counting assertions below flaky.
	_hud.set_process(false)

func _source() -> StubSource:
	var s := StubSource.new()
	add_child_autofree(s)
	return s

func test_descendant_elements_are_discovered_automatically():
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_not_null(_child.last_telemetry, "a nested element still receives frames")
	assert_almost_eq(_child.last_telemetry.speed, 42.0, 0.001)

func test_starts_disarmed():
	assert_false(_hud.is_armed(), "nothing is being piloted at startup")

func test_arms_when_given_a_valid_source():
	_hud.set_active_vehicle(_source())
	assert_true(_hud.is_armed())

func test_a_source_without_the_contract_leaves_the_hud_dark():
	var broken := BrokenSource.new()
	add_child_autofree(broken)
	_hud.set_active_vehicle(broken)
	assert_false(_hud.is_armed(), "no build_telemetry means no HUD, not a crash")
	_hud.refresh()
	assert_null(_child.last_telemetry, "and nothing is pushed")

func test_clearing_the_vehicle_pushes_null_to_elements():
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	_hud.set_active_vehicle(null)
	_hud.refresh()
	assert_null(_child.last_telemetry, "elements are told the vehicle is gone")

func test_registered_external_elements_receive_frames():
	# CockpitMarker cannot be a descendant: it must live inside the ship's
	# SubViewport, which is elsewhere in the tree entirely.
	var external := RecordingElement.new()
	add_child_autofree(external)
	_hud.register_element(external)
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_not_null(external.last_telemetry, "external element got the frame")

func test_registering_twice_does_not_double_render():
	var external := RecordingElement.new()
	add_child_autofree(external)
	_hud.register_element(external)
	_hud.register_element(external)
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_eq(external.render_count, 1, "registered once, rendered once")

func test_unregistered_elements_stop_receiving_frames():
	var external := RecordingElement.new()
	add_child_autofree(external)
	_hud.register_element(external)
	_hud.unregister_element(external)
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_eq(external.render_count, 0, "no frames after unregistering")

func test_one_snapshot_is_built_per_frame_and_shared():
	# Two elements, one build_telemetry() call. Panels must never each pull
	# their own snapshot -- they would disagree within a single frame.
	var second := RecordingElement.new()
	_screen.add_child(second)
	var source := _source()
	_hud.set_active_vehicle(source)
	_hud.refresh()
	assert_eq(source.calls, 1, "exactly one snapshot built")
	assert_eq(_child.last_telemetry, second.last_telemetry, "and both saw the same one")

func test_a_freed_external_element_does_not_break_distribution():
	var external := RecordingElement.new()
	add_child(external)
	_hud.register_element(external)
	external.free()
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_true(_hud.is_armed(), "distribution survived a freed registrant")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_hud_root.gd"
```

Expected: FAIL — `HudRoot` is an unresolved identifier.

- [ ] **Step 3: Write HudRoot**

Create `who-knows/src/ui/hud_root.gd`:

```gdscript
class_name HudRoot
extends CanvasLayer

## The piloting HUD's one global node.
##
## Holds whichever vehicle is currently being piloted, pulls a single
## telemetry snapshot per frame, and hands it to every element. It knows
## nothing about ships, seats or cameras: the scene's bootstrap decides when
## a vehicle becomes active and tells it. That ignorance is deliberate -- it
## is what lets a future vehicle of any kind light this same HUD.

## Matches the seat transition's duration, so the band arrives exactly as
## the camera settles into the seat rather than popping in ahead of it.
## Kept as a local constant rather than read from the camera code: this
## layer deliberately knows nothing about seats or who moves the view.
const FADE_IN := 0.75
## Leaving is quicker than arriving: the instruments go with the chair.
const FADE_OUT := 0.2

## The full-rect Control wrapping everything. CanvasLayer has no modulate of
## its own, so this is the fade target.
@export var screen_path: NodePath

var _source: Node = null
var _descendants: Array[HudElement] = []
var _registered: Array[HudElement] = []
var _tween: Tween = null

@onready var _screen: Control = get_node(screen_path)

func _ready() -> void:
	_screen.modulate.a = 0.0

## Walks the whole subtree fresh each call. Elements may be nested inside
## layout containers, so a direct-children scan would miss them; walking on
## every refresh (rather than caching once in _ready()) also means an
## element added to the tree later is picked up on its very next frame.
func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is HudElement:
			_descendants.append(child)
		_collect(child)

## Hands control of the HUD to `source`, or clears it when given null.
##
## The contract is duck-typed rather than a base class so that no vehicle has
## to inherit from anything to be pilotable. A source that cannot answer it is
## refused here, once, rather than erroring every frame downstream.
func set_active_vehicle(source: Node) -> void:
	if source != null and not source.has_method("build_telemetry"):
		push_warning(
			"HudRoot: %s has no build_telemetry(); HUD staying dark" % source
		)
		source = null
	_source = source
	_fade_to(1.0 if _source != null else 0.0)

func is_armed() -> bool:
	return _source != null

## Registers an element that cannot be a descendant. The canopy marker lives
## inside the ship's SubViewport, which is nowhere near this node.
func register_element(element: HudElement) -> void:
	if not _registered.has(element):
		_registered.append(element)

func unregister_element(element: HudElement) -> void:
	_registered.erase(element)

func _process(_delta: float) -> void:
	refresh()

## Builds one snapshot and gives every element the same instance. Elements
## must never pull their own -- two snapshots in one frame can disagree.
func refresh() -> void:
	_descendants.clear()
	_collect(self)

	var telemetry: VehicleTelemetry = null
	if _source != null:
		telemetry = _source.build_telemetry()

	for element in _descendants:
		if is_instance_valid(element):
			element.render(telemetry)
	for element in _registered:
		if is_instance_valid(element):
			element.render(telemetry)

func _fade_to(alpha: float) -> void:
	if _tween != null:
		_tween.kill()
	var duration := FADE_IN if alpha > 0.0 else FADE_OUT
	_tween = create_tween()
	_tween.tween_property(_screen, "modulate:a", alpha, duration)
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_hud_root.gd"
```

Expected: PASS, 10 tests.

- [ ] **Step 5: Run the whole suite**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1
```

Expected: PASS, everything green.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/ui/hud_root.gd who-knows/test/unit/test_hud_root.gd
git commit -m "feat: add HudRoot with arming, snapshot distribution, and fade"
```

---

### Task 7: Scene wiring and the piloting signal

The highest-risk task in the plan, because it edits `flight_test.tscn`. Read the Global Constraints on `.tscn` comments before starting, and read `CLAUDE.md` in full.

**Files:**
- Modify: `who-knows/src/camera/camera_director.gd` (add signal, two emit sites)
- Modify: `who-knows/scenes/flight_test.gd` (bootstrap wiring)
- Modify: `who-knows/scenes/flight_test.tscn` (six new nodes)
- Test: `who-knows/test/unit/test_hud_scene_wiring.gd`

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: `CameraDirector.piloting_changed(piloting: bool)` signal. Scene node paths `HudRoot`, `HudRoot/Screen`, `HudRoot/Screen/Band`, `HudRoot/Screen/ChaseMarker`, `Ship/Canopy/CanopyOverlay`, `Ship/Canopy/CanopyOverlay/CockpitMarker`.

- [ ] **Step 1: Write the failing test**

Create `who-knows/test/unit/test_hud_scene_wiring.gd`. This suite exists specifically to catch the `.tscn` parser defect documented in `CLAUDE.md`: it loads the real scene and reads properties back, because a clean headless load proves nothing.

```gdscript
extends GutTest

## Guards the flight scene's HUD wiring against the Godot 4.5.1 text-scene
## parser defect described in CLAUDE.md, where a '#' comment adjacent to a
## node or property line silently drops that property -- or the whole next
## node -- with no error output at all. Checking for load warnings does not
## catch it. Reading the values back at runtime does.

var _root: Node

func before_each():
	var scene: PackedScene = load("res://scenes/flight_test.tscn")
	assert_not_null(scene, "flight_test.tscn loads")
	_root = scene.instantiate()
	add_child_autofree(_root)

func test_hud_root_survived_the_parse():
	var hud := _root.get_node_or_null("HudRoot")
	assert_not_null(hud, "HudRoot node present")
	assert_true(hud is HudRoot, "and carries its script")

func test_hud_root_screen_path_survived_the_parse():
	var hud: HudRoot = _root.get_node_or_null("HudRoot")
	assert_ne(hud.screen_path, NodePath(""), "screen_path was not dropped")
	assert_not_null(hud.get_node_or_null(hud.screen_path), "and still resolves")

func test_band_holds_both_panels():
	assert_not_null(
		_root.get_node_or_null("HudRoot/Screen/Band/Row/VelocityPanel"),
		"velocity panel present"
	)
	assert_not_null(
		_root.get_node_or_null("HudRoot/Screen/Band/Row/AttitudePanel"),
		"attitude panel present"
	)

func test_band_carries_its_chrome_script():
	# Without HudBand the readouts float over the scene with no lit surface
	# behind them, which is the layout that was explicitly not chosen.
	var band := _root.get_node_or_null("HudRoot/Screen/Band")
	assert_not_null(band, "band present")
	assert_true(band is HudBand, "band carries its script")

func test_chase_marker_camera_path_survived_the_parse():
	var marker: VelocityMarker = _root.get_node_or_null("HudRoot/Screen/ChaseMarker")
	assert_not_null(marker, "chase marker present")
	assert_ne(marker.camera_path, NodePath(""), "camera_path was not dropped")

func test_cockpit_marker_lives_inside_the_canopy_viewport():
	# It has to be in the SubViewport: only the camera that rendered the view
	# can project onto it correctly. See design doc §6.
	var marker: VelocityMarker = _root.get_node_or_null(
		"Ship/Canopy/CanopyOverlay/CockpitMarker"
	)
	assert_not_null(marker, "cockpit marker present, inside Ship/Canopy")
	assert_ne(marker.camera_path, NodePath(""), "camera_path was not dropped")

func test_camera_director_exports_survived_the_parse():
	# This scene's other exported NodePaths are re-verified here because the
	# same edit touches the same file.
	var director: CameraDirector = _root.get_node_or_null("Ship/CameraDirector")
	assert_not_null(director, "CameraDirector present")
	assert_ne(director.chase_camera_path, NodePath(""), "chase_camera_path intact")
	assert_ne(director.flight_computer_path, NodePath(""), "flight_computer_path intact")

func test_camera_director_announces_piloting_changes():
	var director: CameraDirector = _root.get_node_or_null("Ship/CameraDirector")
	assert_has_signal(director, "piloting_changed")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_hud_scene_wiring.gd"
```

Expected: FAIL — the HUD nodes do not exist and `piloting_changed` is not declared.

- [ ] **Step 3: Add the signal to CameraDirector**

In `who-knows/src/camera/camera_director.gd`, add below the existing `transition_finished` signal:

```gdscript
## Emitted when control of the ship is taken or given up. Anything that cares
## about "is the player flying right now" listens here rather than polling
## `is_seated`, so the moment is defined in exactly one place.
signal piloting_changed(piloting: bool)
```

Then emit it. In `sit()`, after the existing `_move_camera_to(seat.eye.global_transform)` line:

```gdscript
	piloting_changed.emit(true)
```

And in `stand()`, immediately after the guard and before `_flight.clear_pilot_input()`:

```gdscript
	piloting_changed.emit(false)
```

Both sites sit after their early-return guards, so a rejected `sit()` or `stand()` emits nothing. Emitting at the *start* of each transition rather than at its end is what lets the HUD fade across the camera move instead of snapping at the end of it.

- [ ] **Step 4: Wire the bootstrap**

In `who-knows/scenes/flight_test.gd`, add below the existing `@onready var _ship` line:

```gdscript
@onready var _hud: HudRoot = $HudRoot
@onready var _director: CameraDirector = $Ship/CameraDirector
@onready var _cockpit_marker: VelocityMarker = $Ship/Canopy/CanopyOverlay/CockpitMarker
```

Change `_ready()` to:

```gdscript
func _ready() -> void:
	_ship.set_grid(_starter_grid())
	_place_avatar_on_deck()
	_wire_hud()
```

And add, after `_place_avatar_on_deck()`:

```gdscript
## Connects the HUD to this scene's ship.
##
## Done here rather than inside HudRoot on purpose: it keeps src/ui ignorant
## of Ship, CameraDirector and FlightComputer, which is what makes the HUD
## reusable for any future vehicle. The bootstrap is the only place that
## knows both halves.
func _wire_hud() -> void:
	# The cockpit marker lives in the ship's SubViewport, so it cannot be
	# discovered as one of HudRoot's descendants.
	_hud.register_element(_cockpit_marker)
	_director.piloting_changed.connect(_on_piloting_changed)

func _on_piloting_changed(piloting: bool) -> void:
	_hud.set_active_vehicle(_ship.flight_computer if piloting else null)
```

- [ ] **Step 5: Add the scene nodes**

Edit `who-knows/scenes/flight_test.tscn`. **Add no `#` comments to this file at any point.**

Add these `ext_resource` lines alongside the existing ones at the top, giving them ids that do not collide with the current set:

```
[ext_resource type="Script" path="res://src/ui/hud_root.gd" id="12_hud_root"]
[ext_resource type="Script" path="res://src/ui/velocity_marker.gd" id="13_velocity_marker"]
[ext_resource type="Script" path="res://src/ui/panels/velocity_panel.gd" id="14_velocity_panel"]
[ext_resource type="Script" path="res://src/ui/panels/attitude_panel.gd" id="15_attitude_panel"]
[ext_resource type="Script" path="res://src/ui/hud_band.gd" id="16_hud_band"]
```

Increment `load_steps` in the `[gd_scene]` header by 5.

Add the canopy overlay as a child of the existing `Ship/Canopy` SubViewport, immediately after the `CanopyCam` node block:

```
[node name="CanopyOverlay" type="Control" parent="Ship/Canopy"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="CockpitMarker" type="Control" parent="Ship/Canopy/CanopyOverlay"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("13_velocity_marker")
camera_path = NodePath("../../CanopyCam")
```

Add the HUD layer at the end of the file, as a child of the scene root:

```
[node name="HudRoot" type="CanvasLayer" parent="."]
script = ExtResource("12_hud_root")
screen_path = NodePath("Screen")

[node name="Screen" type="Control" parent="HudRoot"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="Band" type="PanelContainer" parent="HudRoot/Screen"]
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 120.0
offset_top = -110.0
offset_right = -120.0
offset_bottom = -40.0
mouse_filter = 2
script = ExtResource("16_hud_band")

[node name="Row" type="HBoxContainer" parent="HudRoot/Screen/Band"]
theme_override_constants/separation = 28
mouse_filter = 2

[node name="VelocityPanel" type="Control" parent="HudRoot/Screen/Band/Row"]
mouse_filter = 2
script = ExtResource("14_velocity_panel")

[node name="AttitudePanel" type="Control" parent="HudRoot/Screen/Band/Row"]
mouse_filter = 2
script = ExtResource("15_attitude_panel")

[node name="ChaseMarker" type="Control" parent="HudRoot/Screen"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("13_velocity_marker")
camera_path = NodePath("../../../Ship/Exterior/ChaseCamera")
```

`Row` is an `HBoxContainer` holding two panels, so the right end of the band is empty by
construction. That empty space is the reserved area design doc §7 describes: a Slice 2 weapons or
hull-condition panel is added by dropping a third child into `Row`, with no change to either existing
panel.

- [ ] **Step 6: Run the test to verify it passes**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1 "-gselect=test_hud_scene_wiring.gd"
```

Expected: PASS, 8 tests. If any `camera_path` or `screen_path` assertion fails while the node itself is found, that is the `CLAUDE.md` parser defect: look for a comment adjacent to the dropped property line and remove it.

- [ ] **Step 7: Run the whole suite**

```bash
pwsh -File D:\git\whoknows\who-knows\run_tests.ps1
```

Expected: PASS, every suite green.

- [ ] **Step 8: Play the scene and walk the manual checklist**

Launch the game and confirm each item. These are the parts no headless test can reach.

- [ ] Sit down (`F` at the seat) — the band **fades in** over the camera move, rather than popping.
- [ ] Speed reads plausibly and updates live while burning.
- [ ] `Space` to boost — speed climbs; the bar goes amber past 90% of the ceiling.
- [ ] `Z` to drop assist, then strafe — the prograde ring **visibly separates** from the boresight.
- [ ] `Z` again — the gap closes as drift correction takes hold.
- [ ] Rotate, then release — the attitude pips return to centre and `SETTLED` appears.
- [ ] Set a burn, then `F` to stand up — **everything goes dark** and the ship keeps accelerating.
- [ ] `V` to chase view while seated — the band persists and the marker tracks against the chase camera.
- [ ] Sit back down — everything returns.

Note: until the canopy tiling defect is fixed (design doc §11.1) the marker appears **once per canopy pane**. That is expected and is not a HUD bug.

- [ ] **Step 9: Commit**

```bash
git add who-knows/src/camera/camera_director.gd who-knows/scenes/flight_test.gd who-knows/scenes/flight_test.tscn who-knows/test/unit/test_hud_scene_wiring.gd
git commit -m "feat: wire the piloting HUD into the flight scene"
```

---

## Notes for the reviewer

**The isolation constraint is the feature.** If any file under `src/ui/` ends up naming `Ship`, `RigidBody3D`, `FlightComputer`, or `CameraDirector`, the task has failed regardless of test results. Check with:

```bash
grep -rn "Ship\|RigidBody3D\|FlightComputer\|CameraDirector" who-knows/src/ui/
```

Expected: no matches. (`build_telemetry` appears only as a string in `has_method`.)

**Two known interior defects are out of scope** and are recorded in design doc §11 — canopy panes each sampling the whole viewport texture, and the seated eye sitting above the top edge of the windscreen. Both affect how the cockpit *looks* while testing this. Neither is caused by, nor fixable within, this plan.
