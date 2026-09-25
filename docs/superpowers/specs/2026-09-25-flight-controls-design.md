# Flight controls — a stick you can hold, a heading you can click, thrusters you can see

**Date:** 2026-09-25
**Status:** Design approved section by section on 2026-09-24/25; this document awaits the owner's
review before planning.
**Depends on:** `main` at `f6171b0` (asteroid groups)
**Governed by:** `docs/design/visual-style.md`
**Amends:** slice spec §7.1 (the controls line); piloting HUD spec §7 (the velocity panel's
readouts); the visual style guide (§10 here)

---

## 1. Why

The owner: "The ship flying physics is okay but not great, it is pretty hard to really fly where
you want it to go reliably. I think ships should also have the ability to fire small thrusters to
rotate. Plan allowing this rotation and also improving overall control to fly a bit more easily."

What makes it hard today:

1. **The mouse turns the ship only while it is moving.** `CameraDirector` turns each frame's
   mouse delta into that frame's turn rate. Stop the mouse and the turn stops, so a steady turn
   means dragging the mouse the whole way round. A higher frame rate means smaller deltas, so the
   same flick turns less.
2. **The ship slides after a turn.** Assist may spend only 60% of the side thrusters on drift:
   about 3 m/s² on the shuttle. After a 90° turn at 100 m/s it slides the old way for about 30 s.
3. **Nothing holds a speed.** With assist on, letting go of W brakes you to a stop.
4. **No keys pitch or yaw.** Only roll is on keys.

The ship already turns with its RCS blocks: `ShipStats` sums their twist into a budget, and the
flight computer spends it. But the turn is an invisible twist on the hull. Nothing puffs, nothing
sounds.

---

## 2. Decisions

| Question | Choice | Why |
|---|---|---|
| What "fire small thrusters to rotate" means | **Keys that turn, and RCS you see and hear** | Steady turns from the keyboard, and the ship visibly steered by its thrusters. |
| How the mouse steers | **A virtual stick for flying by hand, and point-and-click for the computer** | The stick holds a steady turn without dragging. Clicking a point hands the turn to the flight computer. |
| What a click does | **Face it and hold** | The computer swings the nose onto the direction and holds it. The throttle stays yours. Smallest and most predictable. An autopilot that flies you there is a later step. |
| Speed | **Hold W to go, let go to brake, and a key to lock a speed** | Keeps the familiar model. The lock holds a speed until you unlock it. |
| Drift | **Assist spends all the side thrust on drift** | After a turn, your travel swings onto the nose in seconds. |
| How the puffs relate to the physics | **The puffs follow the flight computer (approach A)** | The physics is unchanged: one twist and one central push. Each RCS block puffs in proportion to how much it helps what was commanded. Per-thruster forces (B) and puff-by-axis (C) were rejected: B is a solver in the physics loop and can make lopsided blueprints unflyable; C puffs blocks that are not helping. |
| Learning the keys | **A controls card on the HUD** | Open when you take the seat, H hides it. Built from the input map, so it never lists a stale key. |

---

## 3. Architecture

`CameraDirector` today holds the cameras *and* turns seated input into flight commands. The
input half grows a lot here (the stick, point mode, the heading click, the speed lock), so it
moves out into its own node, `PilotControls`. `CameraDirector` keeps the cameras, sitting and
standing.

```
PilotControls ──set_pilot_input / set_heading / toggle_speed_lock──▶ FlightComputer
     │                                                                 │
     │ build_telemetry(): the computer's snapshot                      │ commanded twist and push,
     │ plus the stick and the pointer                                  │ in hull axes, each tick
     ▼                                                                 ▼
  HudRoot (stick cursor, heading marker, panel, controls card)       RcsShow (puffs, puff sounds)
```

- **`PilotControls`** reads the seated input, owns the stick and point mode, and turns a click
  into a world direction. It is the HUD's active vehicle while you sit. Its `build_telemetry()`
  asks `FlightComputer` for its snapshot and adds the stick and pointer. `HudRoot` is duck-typed,
  so it needs no change and still knows nothing of ships.
- **`FlightComputer`** gains heading hold, the speed lock and full drift authority. It keeps
  each physics tick's commanded twist and push in hull axes. Its maths stays in pure static
  functions, like `attitude_torque`, so tests need no physics.
- **`RcsShow`** sits on the hull. It is rebuilt with the ship's stats, reads the commanded twist
  and push each tick, and puffs and sounds each `rcs` block.

### 3.1 Files

```
src/flight/
  flight_computer.gd   heading hold, speed lock, drift, commanded twist/push, telemetry  (changed)
  pilot_stick.gd       PilotStick: the virtual stick, pure                               (new)
  pilot_controls.gd    PilotControls: seated input, point mode, HUD source               (new)
  rcs_show.gd          RcsShow: firing amounts (pure), puffs, puff sounds                (new)
src/camera/camera_director.gd   loses the flight input; tells PilotControls when seated  (changed)
src/ship/ship.gd                builds RcsShow on each rebuild                            (changed)
src/ship/airlock/airlock_show.gd  its puff mesh builder becomes shared (§6.2)             (changed)
src/audio/synth.gd              `rcs_puff`                                                (changed)
src/ui/
  vehicle_telemetry.gd  stick, pointer, heading hold, speed lock                          (changed)
  stick_cursor.gd       StickCursor: the stick ring and the point-mode pointer            (new)
  heading_marker.gd     HeadingMarker: the held direction, drawn like VelocityMarker      (new)
  controls_card.gd      ControlsCard: the key list, from the input map                    (new)
  panels/velocity_panel.gd   LOCK and HDG readouts                                        (changed)
scenes/flight_test.tscn, flight_test.gd   the new nodes and their wiring                  (changed)
project.godot                  the new input actions                                      (changed)
```

---

## 4. Controls

Seated only. On foot and on a spacewalk nothing changes.

| Input | Action | Does |
|---|---|---|
| Mouse | — | Moves the **virtual stick** (§4.1). |
| ↑ / ↓ | `pitch_up` / `pitch_down` | Pitch at full rate while held. Not inverted: ↑ is nose up, like the mouse. |
| ← / → | `yaw_left` / `yaw_right` | Yaw at full rate while held. |
| Q / E | `roll_left` / `roll_right` | Roll (unchanged). |
| Hold right mouse | `point_mode` | **Point mode** (§4.2). |
| Left mouse, in point mode | `set_heading` | Sets the heading under the pointer. |
| W / S | `move_forward` / `move_back` | Hold to thrust; let go and assist brakes (unchanged). |
| A / D, Shift / Ctrl | as now | Strafe, up and down (unchanged). |
| C | `speed_lock` | **Speed lock** on or off (§5.3). |
| Space | `boost` | Unchanged. |
| Z | `toggle_assist` | Unchanged. Turning assist off drops heading hold and speed lock. |
| H | `toggle_controls` | Shows or hides the controls card (§8.4). |
| F, V | as now | Stand up, cycle camera (unchanged). |

Keys and stick add, each axis capped at full. The right and left mouse buttons are already `throw`
and `use`. That is safe, because `Grasp` is disabled while you sit
(`Avatar.set_control_enabled(false)`). A test holds this (§9).

### 4.1 The virtual stick

- The mouse moves a cursor away from the centre of view. Its offset is kept as a fraction of the
  viewport's height, so it feels the same at any resolution. It is clamped to a circle of radius
  `STICK_RADIUS` (0.2 of the viewport height) and **stays where you leave it**.
- Inside `STICK_DEADZONE` (0.02 of the viewport height) it asks for nothing.
- Outside, the command along the offset's direction is `((r − deadzone) / (radius − deadzone))^1.5`.
  The gentle curve aims finely near the centre. Horizontal is yaw and vertical is pitch; up is
  nose up.
- The command comes from the cursor's position, never from a frame's mouse delta. The same mouse
  travel gives the same command whether it arrives in one event or ten, at any frame rate.
- It only moves while the mouse is captured, as now. It returns to the centre when you sit down,
  stand up, or leave point mode.
- The two constants are starting values, tuned by flying (§9.3).

### 4.2 Point mode and heading hold

- **Hold right mouse:** the stick lets go and centres, so the ship steadies under assist. A pointer
  appears at the centre of view (the nose) and the mouse moves it freely. A hint line reads
  "Click: set heading · Release RMB: back to stick".
- **Left click:** the direction under the pointer becomes the heading. You can click again to
  change it.
- **Release right mouse:** back to the stick, centred, so the ship does not lurch.
- **The direction under the pointer** is a ray from the camera you see through. In the cockpit
  that camera is aboard. The interior never moves and maps one to one onto the hull's axes, so the
  ray is taken into hull axes through the interior's basis, and into the world through the hull's
  basis. The canopy is a portal drawn from the same place with the same field of view, so the
  pointer lies over the same point outside. In chase view the ray is already in the world.
- **Handing back:** moving the stick out of the dead zone, or pressing an arrow key, clears the
  heading hold at once. Roll (Q/E) does not, because roll turns about the nose and leaves the
  heading alone.
- Heading hold needs assist. With assist off, point mode shows the pointer but a click does nothing.
- **Standing up** leaves a heading hold and a speed lock running, so you can set a course, stand
  up and walk aft.

---

## 5. The flight computer

The physics is unchanged: one torque and one central force on the hull `RigidBody3D`, clamped to
`ShipStats`' budgets. Assist off is raw Newtonian, as now. Translation input still carries on when
you stand up (`clear_pilot_input` zeroes only rotation).

### 5.1 Turning by hand

Unchanged. With assist on, the stick and keys ask for a turn rate (`ASSIST_TURN_RATE` at full),
and `attitude_torque` spends up to the budget to reach it. With assist off, they are a throttle on
the RCS.

### 5.2 Heading hold

- `set_heading(direction: Vector3)` stores a **world-space unit direction**. `clear_heading()`
  forgets it. The floating origin only shifts positions, never rotates them, so a direction
  survives a shift untouched and needs no `UniversePoint`.
- Each tick, the target in hull axes is `t = basis⁻¹ · direction`. The nose is −Z. The turn
  needed is about the axis `(−Z) × t`, which has no roll component, by the angle θ between them.
  With the target straight behind (θ near 180°), the axis is pitch.
- The rate asked for along that axis is the fastest the RCS can still brake from in time:
  `ω = min(ASSIST_TURN_RATE, √(2 · HOLD_BRAKE_SHARE · α · θ), HOLD_GAIN · θ)`.
  - α is the smaller of pitch and yaw's `torque_budget / inertia`.
  - `HOLD_BRAKE_SHARE` (0.6) leaves the rate loop some authority spare.
  - The linear term (`HOLD_GAIN`, 2 /s) keeps the √ from chattering at the end. Simulated on
    the shuttle, 3 /s overshot a 120° swing by 2.0°; 2 /s overshoots by at most 1.2°.
- That rate goes into `attitude_torque` as the pitch and yaw command, exactly as a stick would.
  Roll stays with the pilot.
- A pure static `heading_rate(target_local, budget, inertia) -> Vector3` does this sum, so it is
  tested without physics.

The shuttle's α is 0.79 rad/s² (yaw, the weaker axis), so a 90° swing takes about 3 s.

### 5.3 Speed lock

- `toggle_speed_lock()` locks the hull's current forward speed, `v_f = −(basis⁻¹ · velocity).z`,
  signed so a backward drift locks backward. Pressing it again unlocks.
- While locked, with W and S released, the fore-and-aft correction drives `v_f` toward the
  locked speed instead of toward zero.
- While locked, holding W or S thrusts as normal and the locked speed follows `v_f`. Letting go
  holds the new speed.
- The cruise ceiling still applies, so a lock is never above `CRUISE_LIMIT_MPS`.
- The lock needs assist. With assist off, the key does nothing, and turning assist off unlocks.

### 5.4 Drift

- `DRIFT_AUTHORITY` goes from 0.6 to **1.0**: assist may spend the whole side and vertical budget
  on velocity nobody asked for. Fore-and-aft braking gets the same.
- **Fix:** the fore-and-aft correction is clamped by `reverse` thrust in *both* directions today,
  so it can never push forward with the main engines. From now on it pushes forward with
  `forward` and brakes with `reverse`. The speed lock needs this to catch back up after a turn.
- The translation force becomes a pure static
  `translation_force(local_velocity, input, mass, budget, boost, locked, locked_speed)`, in hull
  axes, so drift and the lock are tested without physics.

### 5.5 What it hands on

- `commanded_torque_local: Vector3` and `commanded_force_local: Vector3`: each physics tick's
  twist and push after clamping, in hull axes. `RcsShow` reads these.
- The telemetry snapshot (§8) gains `heading_hold: bool`, `heading: Vector3` (world),
  `speed_locked: bool` and `locked_speed: float`. For the suit and any other source they are
  off and zero.

---

## 6. RcsShow — the thrusters you see

### 6.1 Which blocks, and how hard they fire

`RcsShow` is a `Node3D` on the hull (`Ship/Exterior`). `Ship` rebuilds it after each
`ShipStats.compute`, so it works for any blueprint. It covers every block with id `rcs`. Main
`thruster` blocks are left for a later engine pass.

For each `rcs` block it keeps:
- its push `f` in hull axes (`BlockOrientation.basis_for(orientation) · (0, 0, −thrust)`, as
  `ShipStats` does);
- its twist about the centre of mass, `τ = (centre − centre_of_mass) × f`;
- its **nozzle**: the face opposite its push, `centre − f̂ · CELL_SIZE / 2`. The exhaust leaves
  that way, along `−f̂`.

Each tick, a **firing amount** in 0..1 for every block, from the flight computer's commanded twist
`T` and push `F`:

- **Measure everything as a share of its budget,** so a strong axis does not drown a weak one.
  The command is `k = T / torque_budget` per axis, each clamped to ±1. The block's twist is
  `u = τ / torque_budget` per axis. An axis with no budget is left out.
- **How hard:** the largest `|k|`.
- **How well it helps:** the angle between `u` and `k`. A block within 45° fires fully, one past
  70° not at all, with a smoothstep between. A block that would push against the command never
  fires.
- **Rotation firing** = how hard × how well it helps. Only blocks that push across the hull
  (their `f` has an x or y part) count, exactly the ones `ShipStats` sums into the torque
  budget. The retro pair sits off the centreline and would otherwise light up for yaw, but the
  budget never counts it, so it only fires to brake.
- **Translation firing** is the same test on the push. `F` is measured against `lateral`
  (x), `vertical` (y) and `reverse` (+z), and only the RCS share of it counts: a forward push
  (−z) is the main engines', and no `rcs` block fires for it.
- **The firing amount** is the larger of the two.
- A pure static `firing(blocks, torque, force, torque_budget, thrust_budget) -> PackedFloat32Array`
  holds all of this, so it is tested without physics or particles.

On the starter shuttle this gives (tested, §9.1):

- pitch up: the two nose `UP` blocks;
- pitch down: the two `DOWN` blocks;
- yaw: the one nose lateral block pushing the right way;
- roll: one side's `UP` with the other side's `DOWN`;
- braking: the two retro blocks;
- a settled ship with the stick centred: nothing.

A lone thruster also pushes the ship sideways. The physics ignores that, which is approach A's
trade (§2).

### 6.2 The puffs

- **One `GPUParticles3D` per block,** at its nozzle, emitting along `−f̂`. Puffs spread in a
  narrow cone, grow and fade over a short life (about 0.5 s).
- **The same chunky puff as the airlock's burst onto the hull:** an 8-segment low-poly sphere,
  unshaded, `InteriorPalette.STEAM` fading to clear, built-in particle material and
  `StandardMaterial3D`, **no new shader**. `AirlockShow._puff_mesh` moves to a small shared
  static (`Puffs.mesh(flat)`, `src/world/puffs.gd`) that both use, rather than being copied.
- **World-space** (`local_coords = false`), so a puff hangs where it left while the ship turns
  away. The process material's `inherit_velocity_ratio` is 1, so puffs keep the hull's velocity
  and do not smear into a trail behind a fast ship. The emitters join `Universe.HOLDS_SHIFT`
  (CLAUDE.md, asteroids spec §4.3).
- **Render layer 1**, not the own-hull layer. The canopy camera leaves the own-hull layer out,
  so this is what lets **you see the nose thrusters puff through the canopy** from the seat. The
  puffs are vapour outside the hull, not hull.
- **The firing amount drives `amount_ratio`.** Below 0.05 the emitter stops.
- **Budget:** at most 16 puffs alive per block. The shuttle has 8 `rcs` blocks, so no more than
  128 small puffs at once, all outside the ship. Transparent overdraw near the camera is the cost
  the style guide warns about (§2.6), and the nose puffs sit just beyond the canopy glass, so the
  cockpit frame rate is measured with thrusters firing (§9.3).

### 6.3 The sound

- A new `Synth` builder, **`rcs_puff`**: a short, soft hiss, band-limited noise with a quick
  attack and a rounded decay, about 0.25 s. Warm, never harsh (style guide §2.9).
- **One `AudioStreamPlayer3D` per block,** on the `Ship` bus, under `Ship/Interior` where the
  block sits aboard: `ShipGrid.cell_center(coord) + (0, InteriorBuilder.storey_offset(coord.y), 0)`.
  The interior is a one-to-one map of the hull, so the nose thrusters sound ahead of you.
- A block puffs when its firing amount rises past 0.15. It re-arms when the amount falls below
  0.05, and puffs at most once per 0.12 s. Volume follows the firing amount. A held turn is heard
  as a puff when it starts and a puff from the opposite thrusters when it stops, the way real RCS
  pulses. It does not hiss continuously.
- **Space is silent:** like the hum, the puffs are heard only while the camera is aboard
  (`Ship._aboard()`). The chase view is silent.

---

## 7. PilotControls in detail

- A `Node` under `Ship`, beside `CameraDirector`, with paths to the flight computer, the hull
  and the interior.
- `CameraDirector.sit` and `stand` call `PilotControls.set_seated(on)`. That centres the stick
  and leaves point mode, and on standing it calls `clear_pilot_input()` as `stand()` does today.
- **`_unhandled_input`:**
  - mouse motion, while seated and captured, goes to the stick or, in point mode, the pointer;
  - `point_mode` pressed or released enters or leaves point mode;
  - `set_heading` in point mode sets the heading;
  - `speed_lock` toggles the lock;
  - `toggle_assist` toggles assist (moved from `CameraDirector`).
- **`_process`:** it builds the rotation command (stick plus arrows, capped; roll from Q/E) and
  the translation command (unchanged from today), clears a heading hold on manual pitch or yaw,
  and calls `set_pilot_input`.
- **`build_telemetry()`:** the flight computer's snapshot, plus `stick: Vector2` (the cursor
  offset as a fraction of viewport height), `pointing: bool` and `pointer: Vector2`.

---

## 8. HUD

All colours from `HudPalette`. Every element is a `HudElement` fed the one telemetry snapshot, so
all of it goes dark when you leave the seat, like the rest of the HUD.

1. **`StickCursor`** (screen-space): a small ring at the stick's offset from centre, a faint line
   back to centre, and a faint circle at full deflection. Hidden inside the dead zone. In point
   mode it draws the pointer and the hint line instead.
2. **`HeadingMarker`**: a diamond on the held direction. It is mounted twice, like
   `VelocityMarker`: once in the canopy overlay, projected with `CanopyCam`, and once
   screen-space for chase view. It reuses `VelocityMarker.resolve`, pinned to the frame's edge
   when the direction is off screen or behind. Hidden without a hold.
3. **Velocity panel:** `LOCK 45 m/s` while locked, and `HDG HOLD` while holding, beside the
   assist readout.
4. **`ControlsCard`**: a compact list on the left edge, one row per control in §4, e.g.
   "Mouse  stick", "↑↓←→  pitch · yaw", "RMB + click  set heading", "C  speed lock". The key
   names are read from the `InputMap` (`OS.get_keycode_string`), never typed in, so the card
   cannot drift from the bindings. It is open the first time you sit. H hides or shows it, and it
   stays that way for the rest of the session.

---

## 9. Testing and verification

### 9.1 Unit tests (GUT)

- **`test_pilot_stick.gd`** (new):
  - the dead zone gives zero;
  - full radius gives ±1 along each axis, and the cursor clamps there;
  - the curve;
  - the same mouse travel in 1 or 10 events gives the same command;
  - re-centring.
- **`test_flight_computer.gd`** (extended):
  - `heading_rate`:
    - points the right way for a target left, right, up and down;
    - is capped at `ASSIST_TURN_RATE`;
    - is zero when on target;
    - picks pitch when the target is behind.
  - A 90° and a 170° swing, simulated by integrating `attitude_torque(heading_rate(...))` on the
    shuttle's inertia and budget, settle within 0.5° inside 5 s and never overshoot by more
    than 2°.
  - `translation_force`:
    - drift is corrected with the full side budget;
    - forward catch-up uses `forward` and braking uses `reverse`;
    - a lock drives toward the locked speed;
    - W while locked moves the lock;
    - assist off drops it.
  - Clearing the heading on manual input. The existing attitude tests keep passing.
- **`test_rcs_show.gd`** (new):
  - on the starter shuttle grid, `firing` lights exactly the blocks listed in §6.1 for pitch,
    yaw, roll and braking, and nothing for a settled ship;
  - nozzles sit on the face opposite the push;
  - the emitters are world-space, on layer 1, in `HOLDS_SHIFT`;
  - the puff-sound hysteresis.
- **`test_input_map.gd`** (extended): the eight new actions exist with their keys and buttons.
- **`test_controls_card.gd`** (new): every row names an action that is bound, and shows that
  action's key name.
- **Seated mouse buttons:** while seated, `use` and `throw` do nothing in `Grasp`.
- **Scene wiring** (`test_hud_scene_wiring.gd`): the new elements exist, are wired, and are fed
  `PilotControls`' telemetry while seated.
- **Rules that must stay green:**
  - `test_visual_style_rules.gd`, with `rcs_show.gd` and `puffs.gd` added to its palette list;
  - `test_floating_origin_scene.gd`, which must see the new emitters covered.

### 9.2 Every edit to `flight_test.tscn` is read back at runtime

New nodes and properties in `flight_test.tscn` are checked by loading the real scene and reading
them back (CLAUDE.md: a clean headless load proves nothing), and the file gets no `#` comments.

### 9.3 Flying it

Green tests prove structure, not feel. Before this is called done, fly the real scene and check:

1. A steady turn by stick and by arrow keys, with no mouse dragging.
2. At 100 m/s with the speed locked, turn 90°: travel lines up with the nose within about 5 s,
   at the locked speed.
3. Click a heading 120° away: the ship swings on without overshooting and holds. A nudge of the
   stick takes it back.
4. Set a heading and a lock, stand up, walk aft: the ship holds both.
5. Assist off: the stick is raw RCS, the lock and the hold are gone, the ship tumbles freely.
6. **Look:** render the cockpit from the seat, at eye height, and the chase view, with the RCS
   firing, and show the owner (style guide §6). The nose puffs must read through the canopy.
7. **Frame rate:** cockpit view, thrusters firing hard, measured against the 120 fps budget
   (style guide §2.6). Fewer or smaller puffs if not.
8. Tune `STICK_RADIUS`, `STICK_DEADZONE`, the curve, `HOLD_BRAKE_SHARE` and `HOLD_GAIN` by
   flying, and record the final values here.

---

## 10. Documents this changes

- **Slice spec §7.1:** the controls line is replaced by a pointer to §4 here.
- **Piloting HUD spec §7:** the velocity panel gains `LOCK` and `HDG`.
- **Visual style guide:** one line under the hull's outside (§4 of the guide) records that RCS
  puffs are the airlock's chunky flat-lit puffs, on layer 1 so windows show them. The line only
  records a new use of existing rules; no rule changes.

---

## 11. Risks

| Risk | Answer |
|---|---|
| The stick feels wrong | Its constants live in one place and are tuned by flying (§9.3). |
| Full drift authority feels "on rails" | That is what assist is for. Assist off is still raw Newtonian. |
| Heading hold chatters when it settles | The linear term near zero, and the puff hysteresis, keep it quiet. The settle test pins the overshoot. |
| Puffs cost frame rate in the cockpit | At most 128 small puffs, measured with thrusters firing; fewer if needed. |
| A lone nose thruster "should" also push the ship sideways | Accepted in approach A. Per-thruster forces (B) can come later without redoing the show. |
| The right mouse button is also `throw` | `Grasp` is disabled while seated; a test holds it. |

---

## 12. Out of scope

- Main engine plumes (a later pass can reuse `RcsShow`'s firing amounts).
- Per-thruster forces (approach B).
- An autopilot that flies you to a rock.
- Gamepad and joystick input, and rebinding keys.
- A continuous mouse-aim mode.
