# Piloting HUD — design

**Date:** 2026-08-23
**Status:** Approved design, ready for an implementation plan
**Depends on:** Tasks 13–15 (grid-generated ship, `ShipStats` live on `Ship`)
**Relates to:** slice spec §3.2 (selling the illusion), §7 (flight and cameras), §11 (art direction);
starter shuttle art direction §5.2 (console palette)

**Superseded on these points by:** docs/superpowers/plans/2026-08-23-piloting-hud.md --
`HudPanel` shipped as `HudElement`; `register_marker()`/`unregister_marker()` shipped as
`register_element()`/`unregister_element()`; a `Screen` Control node exists under `HudRoot`
(needed because `CanvasLayer` has no `modulate` of its own to fade), where this document
described no such node; and elements are re-walked on every `refresh()` rather than
collected once in `_ready()`.

---

## 1. Why this document exists

There is no UI layer in the project. When you sit in the pilot seat you get a view out of the glass
and nothing else — no speed, no indication of which flight mode you are in, and in assist-off no way
to tell where the ship is actually travelling as opposed to where its nose is aimed.

This specifies a HUD that appears while piloting, and — equally the point — specifies it as a shape
that Slice 2's weapons and block damage can extend by adding a field and a panel, rather than by
rewriting a display.

---

## 2. Scope

**In, for v1:**

- Core flight numerics: speed against the cruise ceiling, assist state, boost state.
- Attitude: angular velocity about pitch, yaw and roll, plus a settled indicator.
- A velocity vector marker — prograde ring and nose boresight — drawn on the canopy.

**Deliberately deferred, with the extension point documented in §10:**

- Weapons. Nothing in Slice 1 shoots (slice spec §12).
- Hull and block health. Nothing in Slice 1 takes damage.
- Mass, per-axis thrust utilisation and torque imbalance. `Ship.stats_changed` makes this a panel plus
  one connection whenever it is wanted, but slice spec §7.1 argues a badly balanced ship should be
  *felt* rather than read off a stat block. Adding the readout too early replaces the lesson with a
  number.
- Acceleration and g-load. Not requested for v1, and `MotionCoupling` already finite-differences hull
  velocity. When g-load arrives, extract that computation — do not add a second one.
- The retrograde marker. It is always exactly opposite prograde and therefore carries no information
  the prograde ring does not. Cheap to add once assist-off flying shows it is wanted.

---

## 3. Decisions taken, and why

| # | Decision | Reasoning |
|---|---|---|
| 1 | **Screen-space overlay, styled as instrumentation** | Readable at any resolution and identical in cockpit and chase. Styled with the console palette so it reads as the ship's own displays rather than as game chrome. Adds no render pass, which matters because slice spec §15 already lists canopy `SubViewport` cost as a live risk. |
| 2 | **World-registered elements go inside the canopy `SubViewport`; abstract numerics stay screen-space** | See §6. This is forced by the geometry, not a stylistic preference. |
| 3 | **Typed telemetry snapshot, panels read from it** | Any vehicle that can build a snapshot gets a HUD. Nothing in `src/ui/` references `Ship`, `RigidBody3D` or `FlightComputer`. Testable headless, which the GUT setup requires. |
| 4 | **Console band layout** | One strip along the bottom, sitting directly above the `pilot_seat` block's real raked console, so it reads as that console's upper display. Also the layout with room to grow: weapons and health land in reserved space in the same band. |
| 5 | **Prograde + boresight, not prograde alone** | The *gap* between the two is the readout. Assist holds it closed; toggling assist off springs it open, making the mode change visible rather than only felt. |
| 6 | **The HUD goes dark when you leave the seat** | You are not piloting. The burn continues — `clear_pilot_input()` zeroes only rotation — so walking aft mid-burn means doing it without instruments. Per slice spec §1.1, the theme is a mechanic; this costs strictly less to build than the alternative. |

---

## 4. Architecture

### 4.1 Two mount points

```
FlightTest
├── HudRoot                    (CanvasLayer)          NEW — global, screen-space
│   ├── Band                   (Control, bottom-wide)
│   │   ├── VelocityPanel      (HudPanel)
│   │   └── AttitudePanel      (HudPanel)
│   └── ChaseMarker            (VelocityMarker, full rect)   camera = ChaseCamera
└── Ship
    └── Canopy                 (SubViewport, exists)
        ├── CanopyCam                              (exists)
        └── CanopyOverlay      (Control, full rect) NEW — per ship
            └── CockpitMarker  (VelocityMarker)   camera = CanopyCam
```

`HudRoot` is global and survives vehicle changes; `CanopyOverlay` is necessarily per-ship because it
must project through *that* hull's `CanopyCam`. `ChaseMarker` sits under `HudRoot` because in chase
view the player's camera really is the camera seeing space. It is a **full-rect sibling of `Band`,
not a child of it** — a marker must be free to sit anywhere on screen, while the band is pinned to
the bottom.

`CanopyOverlay` is a plain `Control` child of the `SubViewport` — `CanvasItem` children of a viewport
render into it. `Canopy` is already `render_target_update_mode = 4` (always), so the overlay updates
with **no new render pass and no change to viewport cost**.

### 4.2 Files

```
src/ui/vehicle_telemetry.gd      VehicleTelemetry  — RefCounted snapshot
src/ui/hud_root.gd               HudRoot           — CanvasLayer; owns source, arming, distribution
src/ui/hud_panel.gd              HudPanel          — Control base: render(t: VehicleTelemetry)
src/ui/hud_palette.gd            HudPalette        — art-direction colours, one place
src/ui/velocity_marker.gd        VelocityMarker    — Control; takes a Camera3D
src/ui/panels/velocity_panel.gd
src/ui/panels/attitude_panel.gd

test/unit/test_vehicle_telemetry.gd
test/unit/test_velocity_marker.gd
test/unit/test_hud_root.gd
test/unit/test_hud_panels.gd
```

### 4.3 The contract

A **telemetry source** is any node with `build_telemetry() -> VehicleTelemetry`. `HudRoot` guards with
`has_method` and stays dark if the method is absent. That single method is the entire vehicle-facing
interface — which is what makes "ship *or vehicle*" true rather than aspirational.

`FlightComputer` is the ship's source. It already holds `_hull`, `assist_enabled`, `_boost` and
`CRUISE_LIMIT_MPS`; a flight computer emitting telemetry is the natural reading of the class, not a
concern leaking into it. It gains one method and no new state.

---

## 5. The telemetry snapshot

```gdscript
class_name VehicleTelemetry
extends RefCounted

var speed: float                     ## m/s, magnitude
var cruise_limit: float              ## so no panel hardcodes 120.0
var world_velocity: Vector3          ## for the marker's projection
var local_velocity: Vector3          ## velocity in hull basis — the drift readout
var local_angular_velocity: Vector3  ## (pitch, yaw, roll) rad/s about local axes
var assist_enabled: bool
var boost_active: bool
var hull_origin: Vector3             ## the marker projects from here

static func from_state(
    basis: Basis, origin: Vector3,
    linear_velocity: Vector3, angular_velocity: Vector3,
    assist: bool, boost: bool, cruise_limit: float
) -> VehicleTelemetry
```

Godot reports `RigidBody3D.angular_velocity` in the world frame, so `local_angular_velocity` is
`basis.inverse() * angular_velocity`, giving pitch about local X, yaw about local Y, roll about
local Z — matching the axis convention `FlightComputer._apply_rotation` already uses.

**`from_state` takes plain values, not a body.** That is the seam that makes the whole data layer
testable headless: `FlightComputer.build_telemetry()` becomes a one-line adapter reading `_hull`, and
every piece of the math is exercised with no nodes and no physics steps.

**No placeholder weapon or health fields.** Extensibility lives in the shape, not in empty structs
that nothing writes. See §10.

---

## 6. Why world-registered elements must live in the viewport

In cockpit view the pilot is not looking at space. They are looking at a picture of space.

```
interior eye  ──2.8 m──▶  canopy panes  ...showing...  CanopyCam
renders THE ROOM          flat textures               renders SPACE, from the hull,
                                                      9 m forward, fov 75, aspect 2:1
```

Derived from the starter blueprint, with `ShipGrid.cell_center(c) = c * CELL_SIZE` and
`CELL_SIZE = 2.0`:

| Quantity | Value |
|---|---|
| Seat cell `(0, 0, −2)` → seat origin | `(0, 0, −4)`; eye `+(0, 1.2, −0.2)` → **(0, 1.2, −4.2)** |
| Canopy cells `(−1…1, 0, −4)`; faces on the `z = −3` cells' −Z side | **z = −7** |
| Eye-to-pane distance | **2.8 m** |
| Pane run | 3 × 2 m wide, 2 m tall → **6 m × 2 m**, spanning y ∈ [−1, +1] |
| Aperture subtended from the eye | **≈ 94° × 34°** |
| `CanopyCam` frustum (fov 75 vertical, 2:1) | **≈ 114° × 75°** |

So the glass shows a 114° × 75° render through a 94° × 34° hole — different frustum, different
aspect, in both axes. A marker projected through the *interior* camera would land wherever that
camera says, which bears no relationship to the debris actually visible in the glass. You would fly
toward a rock and the reticle would point elsewhere.

Drawing into the `SubViewport` instead makes the marker correct by construction: it is projected with
the same camera that rendered the scene it annotates, so it cannot disagree with it.

This also survives the canopy work described in §11. Whatever fixes pane UV mapping, the marker
continues to appear wherever `CanopyCam` says that direction is — which is the definition of right.

---

## 7. The console band

Anchored bottom-wide, inset from the screen edges so it sits over the seat's raked console rather
than over the deck. Left to right:

```
┌────────────────────────────────────────────────────────────────────────────┐
│  VEL          ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░       P ──┼──      ASSIST ON              │
│   87 M/S      0   CRUISE CEILING  120  Y ──┼──      BOOST  —               │
│                                        R ──┼──                    ◀ §10 ◀  │
└────────────────────────────────────────────────────────────────────────────┘
```

**Colours** come from the starter shuttle art direction §5.2 and live only in `HudPalette`:
readouts `#7FD4FF`, warnings `#FFB03A`.

**VelocityPanel** — speed as the large numeral, a bar against `cruise_limit`, and the two mode flags.
The bar reads amber above 90% of the ceiling. With assist off there is no cruise clamp, so speed can
exceed the ceiling: the bar pins full and goes amber, which is honest and is exactly when the pilot
should notice.

**AttitudePanel** — three centre-zero tracks for pitch, yaw and roll, scaled against a display
maximum, plus a SETTLED indicator below a small threshold. This is what tells you whether
`ROTATION_DAMPING` has actually finished settling the ship before you commit to a burn.

The right end of the band is **reserved and left empty in v1**. That is where weapons and hull
condition go.

---

## 8. The velocity marker

Two elements drawn into whichever viewport the marker is mounted in:

- **Boresight** — a thin fixed cross at viewport centre. Where the nose points, by definition. Static.
- **Prograde ring** — `hull_origin + world_velocity` projected to screen.

### 8.1 The state policy is a pure function

```gdscript
enum Mode { HIDDEN, ON_FRAME, CLAMPED_AHEAD, CLAMPED_BEHIND }

static func resolve(
    speed: float, is_behind: bool,
    screen_pos: Vector2, viewport_size: Vector2
) -> Dictionary   ## { "mode": Mode, "position": Vector2 }
```

| Condition | Mode | Position |
|---|---|---|
| `speed < MIN_SPEED_MPS` | `HIDDEN` | — |
| `is_behind` | `CLAMPED_BEHIND` | edge, along the direction from centre **negated** |
| in front, inside frame | `ON_FRAME` | `screen_pos` |
| in front, outside frame | `CLAMPED_AHEAD` | edge, along the direction from centre |

Clamped positions inset by `EDGE_MARGIN_PX` and render as a chevron rather than a ring, so a clamped
marker never reads as a real position. `CLAMPED_BEHIND` additionally renders dimmed.

Constants: `MIN_SPEED_MPS := 1.0`, `EDGE_MARGIN_PX := 16.0`.

Three reasons this is a separate static function rather than inline logic:

1. **`unproject_position` returns mirrored nonsense for points behind the camera.** That is a real
   trap, not a hypothetical — it must be guarded with `is_position_behind()`, and a guard worth having
   is worth testing.
2. At rest, velocity direction is numerical noise, so an unguarded ring strobes around the frame.
3. Both rules are pure data transformations, so they test headless with no camera and no viewport.

The `Camera3D` calls stay in a thin adapter that is not unit-tested.

---

## 9. Gating and state

`CameraDirector` gains one signal — the only change to existing behaviour in this feature:

```gdscript
signal piloting_changed(piloting: bool)
```

emitted `true` at the end of `sit()` and `false` at the top of `stand()`.

`scenes/flight_test.gd` connects it, following the precedent it set with `_place_avatar_on_deck()`:
the bootstrap does the wiring, so `HudRoot` never learns what a `CameraDirector`, a `Ship` or a seat
is. It has an active source, or it does not.

```gdscript
director.piloting_changed.connect(func(p: bool) -> void:
    hud.set_active_vehicle(ship.flight_computer if p else null))
```

**Fades:** in over `CameraDirector.SIT_DURATION`, so the band arrives as the camera settles into the
seat; out over ~0.2 s on standing, so the instruments leave with the chair.

**Markers gate themselves, with no signal at all.** Each `VelocityMarker` holds a `Camera3D` and sets
`visible = camera.current and armed`. `ChaseMarker` lights only when `ChaseCamera` is current;
`CockpitMarker` sees `CanopyCam.current == true` within the `SubViewport` always, so it draws whenever
armed. View cycling therefore needs no plumbing — `cycle_view()` already flips `current` and the
markers simply notice.

**Distribution.** `HudRoot` pulls one snapshot per frame in `_process` and pushes it to every
consumer. Consumers are found two ways:

- **Descendants**, collected once in `_ready()` — every `HudPanel` and every `VelocityMarker` in
  `HudRoot`'s own subtree. That covers `VelocityPanel`, `AttitudePanel` and `ChaseMarker`.
- **Registered externally**, via `register_marker(m)` / `unregister_marker(m)` — `CockpitMarker`
  cannot be a descendant, because it has to live inside the ship's `SubViewport`. The bootstrap
  registers it alongside the `piloting_changed` connection.

When disarmed, `HudRoot` pushes `null` to every consumer and each fades itself out — one code path
for both states, rather than a separate teardown to keep in sync.

---

## 10. Extension points

This is what §2's deferrals cost to un-defer.

| Later feature | Work required |
|---|---|
| Weapons (Slice 2) | Add a field to `VehicleTelemetry`, populate it in `build_telemetry()`, drop a `WeaponsPanel` into the band's reserved right end. No existing panel changes. |
| Hull / block health (Slice 2) | Same shape. Damage already routes through the single `ShipGrid` mutation choke point, so the snapshot reads from `Ship.stats`. |
| Mass, thrust, torque imbalance | `Ship` already emits `stats_changed(stats)`. One connection, one panel. |
| G-load | Extract the finite difference from `MotionCoupling._physics_process`; do not duplicate it. |
| A second vehicle type | Implement `build_telemetry()` on its controller. Nothing in `src/ui/` changes. |
| Retrograde marker | One more element in `VelocityMarker`; `resolve` already handles the geometry. |

> **Amended 2026-09-23 (Planetfall §13):** surface flight follows the same pattern as the weapons
> row. The surface fields (altitude, vertical speed, lift margin, tilt, landing state) arrive through a
> second plain-values step, `with_surface()`, so `from_state()` and its callers do not change. A
> `SurfacePanel` joins the band between `AttitudePanel` and the right end, which stays reserved.
> World markers add a second duck-typed source, `build_contacts()`, independent of vehicle arming
> so they also show on foot. They and the toast line live under their own `WorldOverlay`
> `CanvasLayer`, not under `HudRoot`.

---

## 11. Known interactions with the generated interior

Two pre-existing issues surfaced while deriving §6's geometry. Both affect how this HUD will *look*
in the cockpit; neither affects its architecture, and **neither is in scope here**. Recorded so they
are not mistaken for HUD defects.

### 11.1 Canopy panes tile the full viewport

`InteriorBuilder._add_box` creates a fresh `BoxMesh` per face with
`material_override = _canopy_mat()`. A `BoxMesh` UV-maps 0→1 across each face, so **every canopy pane
samples the entire `SubViewport` texture**, squashed to that pane's aspect. The starter grid places
three `canopy` cells at x ∈ {−1, 0, 1}, so the forward view is currently the same image tiled three
times — a video wall rather than a windscreen.

This predates the HUD and is **out of scope here**; it is tracked as its own task. Two consequences
worth recording:

1. **The architecture is unaffected.** The marker belongs in the viewport under either behaviour. If
   the panes are later fixed to show *sections* of the view, the marker automatically appears once, in
   whichever pane covers that direction.
2. **What ships before that fix lands shows three prograde rings**, one per pane. That is the tiling
   defect surfacing, not a HUD bug.

### 11.2 The seated eye sits above the top of the windscreen

`PilotSeat`'s `Eye` offset of `(0, 1.2, −0.2)` was authored against the hand-built room, whose floor
surface sat at local y = 0. With the generated interior the deck surface for that cell is at
`0 − CELL_SIZE/2 + FLOOR_THICKNESS/2 = −0.95`, putting the seated eye **2.15 m above the deck** —
standing height, not seated.

The windscreen spans y ∈ [−1, +1], so its top edge is 0.2 m *below* eye level: the entire aperture
sits under the seated pilot's horizon, and they look down at the glass rather than through it.

`_place_avatar_on_deck()` in `scenes/flight_test.gd` exists to fix exactly this class of problem —
deriving position from the grid rather than trusting a coordinate authored for the old room — but the
seat's `Eye` did not get the same treatment.

Consequence for this feature: the prograde ring sits low in view, and viewport centre (where the
boresight is pinned) does not coincide with the natural forward gaze. The marker remains correct
*within* the viewport, so nothing in §8 changes; the cockpit simply reads wrong until the eye is
derived from the deck the way the avatar spawn is.

---

## 12. Testing

### 12.1 Automated (GUT, headless)

| Suite | Covers |
|---|---|
| `test_vehicle_telemetry.gd` | `speed` magnitude; `local_velocity` under a rotated basis; pitch/yaw/roll axis mapping from world angular velocity; `cruise_limit` passthrough. |
| `test_velocity_marker.gd` | Every row of the §8.1 table: deadband, on-frame passthrough, ahead-clamp direction, behind-clamp negation, edge-margin inset. |
| `test_hud_root.gd` | Arming and disarming; a source lacking `build_telemetry` leaves the HUD dark rather than erroring; `null` push reaches registered markers. |
| `test_hud_panels.gd` | `render(t)` produces expected label text; the amber threshold at 90% of ceiling; over-ceiling pinning with assist off. |

`Control` and `Label` both work headless, so panel rendering needs no viewport.

### 12.2 Manual playtest checklist

Additions to slice spec §10.2:

- Sit down — the band fades in as the camera settles, not before.
- Boost — speed climbs and the bar approaches the ceiling; it goes amber past 90%.
- Toggle assist off and strafe — the prograde ring visibly separates from the boresight.
- Toggle assist back on — the gap closes as drift correction takes hold.
- Stand up mid-burn — everything goes dark, and the ship keeps burning.
- Cycle to chase — the band persists; the marker is now screen-space and tracks correctly.

### 12.3 Scene-edit verification — mandatory

Adding `HudRoot` and `CanopyOverlay` means editing `flight_test.tscn`, which is precisely where the
parser defect documented in `CLAUDE.md` lives.

- **No `#` comments anywhere in the file.** Not before a property, not trailing, not isolated by blank
  lines. Any narrative explanation goes in the `.gd` doc comments or the task report.
- **Verification is: load the real scene and read the properties back at runtime.** A clean
  `--headless --quit-after N` exit proves nothing here. That is exactly how this defect survived two
  prior task reviews in this project.

---

## 13. Risks

| Risk | Mitigation |
|---|---|
| Band crowds the cockpit view | It is anchored over the seat's console, below the glass. Tune inset and height during the manual pass; nothing else depends on its size. |
| Prograde ring is illegible in a 1024×512 viewport squashed across panes | Partly the §11 tiling defect rather than the marker. Ring is sized in viewport pixels, so it can be scaled independently of the numerics. |
| `piloting_changed` and the existing tween disagree about state | The signal is emitted at the two points that already own the transition — end of `sit()`, top of `stand()` — not inferred from tween progress. |
| Per-frame telemetry allocation churn | One `RefCounted` per frame is well within budget at this scale. If profiling ever objects, `build_telemetry` can fill a reused instance without changing any consumer. |
| HUD drifts out of step with art direction | All colours live in `HudPalette`, referencing art direction §5.2. No panel names a colour. |

---

## 14. Definition of done

Sit down and the band fades in over the seat's console. Speed, cruise ceiling, assist and boost read
correctly and update live. The attitude tracks show rotation settling. On the glass, the prograde ring
tracks true velocity while the boresight holds centre; toggling assist off visibly opens the gap
between them. Stand up mid-burn and everything goes dark while the ship keeps accelerating. Cycle to
chase and the band persists with the marker correctly projected against the chase camera. GUT suite
green.
