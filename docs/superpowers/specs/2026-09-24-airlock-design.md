# The airlock — stepping out of your ship

**Date:** 2026-09-24
**Status:** Design approved section by section on 2026-09-24. The owner asked for planning and
implementation to follow without a further review stop.
**Depends on:** `main` at `ff8631b` (cockpit pod and portal windows, hands and items)
**Governed by:** `docs/design/visual-style.md`
**Supersedes:** Planetfall spec §10 (the airlock cycle), except its refusals that need a planet.
Planetfall §10.5's transfer maths and §11 (on foot on a world) still apply when planets arrive.
**Amends:** hands-and-items spec §15 (items through the airlock); visual style guide (§12 here)

---

## 1. Why

The owner: the airlock "is what connects the inside ship to the outside world. In our starter
ship it seems inaccessible right now." It should be "a room with two hatch doors on either
side", where you press a button to pressurize or depressurize, "steam shoots in and it gets
foggy for a bit before the other door opens". It is "the point the physics can change from
internal ship physics to either planet physics or space physics", and "should be a really awe
inspiring part of the game, this is where the user first enters somewhere new. But it also
shouldn't be so long that it is cumbersome, they will do this process quite often."

Today the airlock cell is simply the end of the corridor: open to it, with lockers on both walls
and a hatch that is only a picture. Nothing exists on the other side. Planetfall §10 designed a
cycle that only opens onto a planet, and planets are not built.

---

## 2. Decisions

| Question | Decision |
|---|---|
| What is outside, in this build | **Open space.** A first spacewalk: float out beside your ship in zero-g and fly back in. Planets plug in later (§13). |
| Where ship physics ends | **At the outer hatch's threshold** (§7). The airlock room stays in interior space; the open outer hatch is a portal; crossing its plane moves you into the real world. |
| A moving ship | **Real physics.** The ship is flown only from the cockpit and keeps whatever it is doing. You leave with its velocity at the hatch, spin included. The airlock **warns** when the ship is moving; it never refuses. |
| Moving outside | **Suit thrusters** with a suit assist that holds you still relative to your own ship (§8). |
| Doors | **Two hatches, each opened only by a button.** Both are shut at rest; a hatch closes behind you once its doorway is clear. |
| Cycle length | **About 5 s, every time** (4.7 s from button to open hatch). |
| Sound | **Yes — synthesized in code.** The game's first audio. |

---

## 3. The room

### 3.1 Layout

- `InteriorLayout` gives the `airlock` cell its own zone, `&"airlock"`. The existing room rules
  then wall it off from bridge and common space and give it **exactly one doorway**, chosen as a
  room's is (interior redesign §7.2). That doorway is the **inner hatch**. The cell's wall face
  onto vacuum is the **outer hatch** (the `HATCH` variant, as now). Every other wall of the cell
  is an `AIRLOCK` wall. The airlock zone takes no room furniture.
- A face counts as the outer hatch only if it is a horizontal wall onto an empty cell. An airlock
  with no such face, or more than one, is **inert**: dressed as a plain room, no cycle.
  `ShipValidator` gains **Rule 6 (warning): every airlock has exactly one face onto empty space.**
  The starter's airlock at (0, 0, 3) has one, facing +Z (aft).

### 3.2 A low ceiling, on purpose

The airlock room is **1.9 m clear**, not the cabin's 2.5 m. Its ceiling slab sits at the top of
its grid cell, exactly where the hull's is. The room has a copy on the outside of the hull (§7.2)
that must match it exactly, and the hull cell is 2 m tall: in the starter a stern thruster sits
directly above. A cramped utility room suits an airlock, and makes stepping back into the tall
cabin feel like coming home. Its lights are flush ceiling strips, not hanging rings.

- **Hatch opening:** 1.0 m wide (`DOOR_WIDTH`) and **1.85 m high** (`InteriorProps.HATCH_HEIGHT`),
  with a header up to the ceiling. The 1.8 m avatar passes with 5 cm to spare.
- The inner hatch sits in a normal storey-height partition. The builder builds its opening to
  `HATCH_HEIGHT` rather than `DOOR_HEIGHT`, with a lintel above.

### 3.3 The hatches

One hatch design, `AirlockHatch`, is used for the inner hatch, the outer hatch and the outer
hatch's copy on the hull. It is a node like `SlidingDoor` that knows nothing about ships.

- **Two heavy leaves** that part sideways into the jambs, with bevelled edges, a coral hazard
  band, and a **round window** in the port leaf. The outer hatch's window, seen from the room, is
  portal glass: you see real space through it before it opens. Every other hatch window is plain
  glass.
- **Four chunky locking bolts** along the meeting edge. They retract visibly before the leaves
  move and drive home after the leaves meet.
- **A light strip** in the header: signal green (`SIGNAL_GO`) when this side may open, amber while
  cycling, coral when there is vacuum beyond.
- **A collider across the opening whenever it is not fully open.** It is disabled only while the
  leaves are fully open. Unlike `SlidingDoor`, a hatch never opens by walking up to it.
- `InteriorProps.hatch_frame(kit, f)` builds the fixed parts: chunky posts, a header, and bolt
  housings on both faces of the wall.

### 3.4 The panels

Three `AirlockPanel`s, each an interactable showing live state:

| Panel | Where | Prompt |
|---|---|---|
| **Room** | the room's side wall, at chest height | *Depressurize* or *Pressurize*, whichever leads to the other side; *Reverse* mid-cycle |
| **Corridor** | the partition's corridor face, beside the inner hatch | *Open hatch* / *Close hatch*, or *Pressurize* if the room is at vacuum |
| **Hull** | the hull face outside, beside the outer hatch | *Open hatch* / *Close hatch*, or *Depressurize* if the room is pressurized |

Each has one big lit button and a small readout in 3D text: the pressure (*PRESSURE 64 kPa*), a
status line (*READY*, *CYCLING*, *CLEAR THE HATCH*, *VACUUM*), and the motion warning (§4.4).
This is the first screen that shows live game state; the style guide allows it because this
spec designs it (§12).

### 3.5 The rest of the room

`InteriorProps.airlock_wall(kit, f, variety)` dresses each `AIRLOCK` wall: a kick band, vertical
ribs, a grab rail at 1.1 m, a vent grille near the floor, and **two steam nozzles** low on the
wall angled up into the room. The room gets one ceiling light strip and its small light.

---

## 4. The cycle

### 4.1 Going out and coming in

You press the room panel. The hatch you came through seals, the room cycles, and the far hatch
opens:

| Stage | Time | What happens |
|---|---|---|
| `SEALING` | 0.7 s | Near leaves close (0.5 s), then its bolts drive home (0.2 s). Lights go amber. |
| `CYCLING` | 2.8 s | Pressure runs 101 → 0 kPa going out (fast first, easing off) or 0 → 101 kPa coming in. The fog and steam run (§5). |
| `OPENING` | 1.2 s | Far bolts retract (0.3 s) and its leaves part (0.9 s). Its strip turns green: this side may open (§3.3). |

That is 4.7 s from button to open hatch. Pressure follows `p = 101·(1 − u)²` going out and
`p = 101·(1 − (1 − u)²)` coming in, with `u` the fraction of `CYCLING` done.

### 4.2 Calling the room to your side

An outside panel whose side is at the wrong pressure runs the same three stages with the room
empty. It seals whichever hatch is open (normally neither), cycles, and opens the hatch in front
of you.

### 4.3 Rules

- **You can move and look around throughout.** You are in a sealed room in ship space. Ship
  gravity holds in the room at any pressure.
- **At most one hatch is ever open**, and never during `CYCLING`. This invariant is what lets
  the portal show the hull while the outer hatch is open (§7.3).
- **Pressing the room panel mid-cycle reverses it.** Pressure runs back to where it started over
  the time already spent, and the hatch you came through reopens.
- **A hatch never closes on anyone.** `SEALING` waits, with *CLEAR THE HATCH* on the panels,
  until the doorway is clear: no avatar within 0.4 m of the hatch plane inside its opening's
  width.
- **An open hatch closes itself** once the room and both doorway zones have been empty for 2 s.
  The room keeps its pressure.
- **Loose items in the room stay in the room.** The air rush is spectacle, not a force.
- **Starting state:** pressurized, both hatches shut.

### 4.4 The motion warning

Every panel shows it, and the outer hatch's strip pulses amber with it:

- **Amber** above 0.5 m/s or 2°/s: *SHIP MOVING · 3.2 M/S* or *SHIP TURNING · 4°/S*.
- **Coral** above 3 m/s or 10°/s.

It is a warning only. The speed is the hull's linear speed, and the turn rate its angular speed.

### 4.5 How it is built

`AirlockCycle` is a `RefCounted` holding the state (stage, time in stage, pressure, which hatch
is open, direction, reversing), with a **pure** `step(delta, events) -> Array[StringName]` that
returns cues (`&"bolts_home"`, `&"leaves_open"` and so on). Events are button presses and doorway
occupancy. It is testable headless. The `Airlock` node owns one cycle, gathers the events, applies
the state to the hatches, panels, fog, steam, lights and sound, and plays the cues. Nothing else
runs its own timing.

`Ship` keeps each airlock's cycle keyed by cell across rebuilds, so a rebuild never resets its
pressure or opens a hatch.

---

## 5. The show

Everything here uses the kit, built-in particles and plain materials. No new shader.

### 5.1 Steam and fog

- **Steam puffs** are `GPUParticles3D` drawing a chunky low-poly sphere (8 segments, 4 rings) with
  a plain `StandardMaterial3D` in `STEAM`. They are lit by the room light, fade through a colour
  ramp, and grow as they drift.
- **Coming in:** each of the four nozzles fires a jet for the first 1.2 s of `CYCLING`, then the
  puffs roll through the room. During `OPENING` they sink and are drawn into the vent grilles.
- **Going out:** decompression fog blooms from the whole room volume in the first second of
  `CYCLING` and swirls. During `OPENING` it streams out through the opening hatch: the particles'
  direction turns toward the hatch.
- **From outside:** the hull copy gets a one-shot burst of puffs out of the hatch as it opens
  onto vacuum. They expand fast and fade within 1.5 s.
- **Haze:** while the viewer is in the room, their camera wears a copy of the interior
  environment whose **distance fog** follows the cycle. It rises to a near-whiteout at the fog's
  peak, about 1.5 s into `CYCLING`, and clears through `OPENING`. The copy is swapped in when you
  enter the room and out when you leave. The interior environment itself is never modified.

### 5.2 Light

- At rest the room light is `LIGHT_WARM`. Through the cycle it shifts to `AMBER`, with a pulsing
  amber lamp on each hatch header, built on the glow shader's blink.
- When the outer hatch opens, the room light cools and dims to 40%, so the view out is the
  brightest thing in the room.
- **New palette entries:** `SIGNAL_GO` (a soft signal green, for hatch strips and panel buttons
  only) and `STEAM` (warm off-white). **New `HullPalette`** (constants only, like `HudPalette`):
  `HULL_PLATE`, `PANEL_LINE` and `RUNNING_LIGHT`, from the art direction §5.1, for the airlock's
  outside face.

---

## 6. Sound

The game's first audio. It is synthesized in code, so there are no sound files. The style is soft
and warm, never harsh.

- **`Synth`** builds short `AudioStreamWAV`s from noise, sines, one-pole filters and envelopes,
  deterministically from a fixed seed. It builds them once, off the main thread, when the ship
  loads, and caches them:
  - `hatch_motor`: a low whirr;
  - `bolt_clunk`: a thump, a click and a short ring;
  - `seal_thump`;
  - `hiss_out`: noise whose filter sweeps down as it fades;
  - `steam_in`: sharp jet bursts, then a rising roar;
  - `panel_beep`;
  - `warning_chime`;
  - `ship_hum`: a quiet air-handling loop;
  - `breath`: a slow suit breathing loop;
  - `thruster_puff`: a short soft burst.
- **Buses**, created in code: **`Ship`** for everything heard through air, with a low-pass
  filter, and **`Suit`** for what you hear inside your helmet.
- **Air carries sound.** While the listener is in the airlock room, the `Ship` bus's cutoff
  follows the room's pressure: open at 101 kPa, down to 300 Hz and −18 dB at vacuum. Going out,
  the hiss and the ship's hum drain away to near silence. Coming in, sound returns with the air.
- **Interior sounds are positional** (`AudioStreamPlayer3D` in interior space): the hum at every
  ceiling light, the hatch and bolt sounds at the hatches, steam at the nozzles. The listener is
  the current camera. On a spacewalk that camera is in the real world, 5 km from interior space,
  so the ship is naturally silent.
- **On a spacewalk** you hear only the `Suit` bus: your breathing, a soft thruster puff while
  thrusting, and the warning chime. The panels play `panel_beep` when pressed.

---

## 7. The threshold

### 7.1 Crossing out

The threshold is the **outer hatch plane**.
- **When it happens:** the outer hatch is fully open and the avatar's origin passes 2 cm outward
  through the plane, inside the opening.
- **Where you land:** the avatar moves from interior space into the real world at the same pose
  relative to the hull. That is Planetfall §10.5's maths with the storey correction below:

  ```
  hull_local  = to_hull(interior.global_transform.affine_inverse() * avatar.global_transform)
  avatar_world = hull.global_transform * hull_local
  ```

  `to_hull` subtracts the storey offset `coord.y × (STOREY_HEIGHT − CELL_SIZE)` from y. It is 0 on
  storey 0.
- **Velocity:** the hull's velocity at that point, spin included, plus the avatar's own interior
  velocity carried onto the hull's axes. The hull's velocity at a point comes from the physics
  server's body state.

### 7.2 The outside copy of the room

For each airlock with an outer hatch, `ExteriorBuilder` builds an **alcove** instead of the
block's mesh and full-cell box collider:
- **Colliders:** a floor, a ceiling and a thin wall on every face but the hatch face. The hatch
  face gets jambs and a lintel round the opening. All are on the hull body, layer 1.
- **Inside:** the room's props from the same functions in the same frames (hull-local and
  interior-local coordinates are the same numbers, storey offset aside): `airlock_wall`,
  `hatch_frame`, the ceiling strip, the room panel's body, the nozzles. It draws on the own-hull
  render layer with its own light. Built with `InteriorKit` (§10).
- **Outside:** the hatch face in `HULL_PLATE` with a chunky `PANEL_LINE` frame and the
  art direction's cyan running-light arch over the hatch. The hull panel sits on the right-hand
  jamb. Exposed faces of the cell (its floor, in the starter) are plated. Plating uses the hull
  livery material, so the stripe continues across it.
- **Hatches:** an outer `AirlockHatch` with a glass window, driven by the same cycle as the
  interior's, so both copies open and close together. The inner hatch is always shown shut here,
  because nothing is behind it in exterior space.
- **The hull panel** is an `Area3D` on physics layer 5 (`exterior_props`, named in
  `project.godot`) that the spacewalking interactor finds.

### 7.3 Looking out of the open hatch

- The outer hatch has a **portal pane** just outside its leaves. While the leaves are open, you
  see the real outside through the opening, as with every window.
- **While the outer hatch is open and the viewer is in the airlock room, the canopy view includes
  the own-hull layer.** The engine pods beside the stern are then already in view before you
  cross. The camera stands inside the alcove copy, so nothing blocks the opening. The inner hatch
  is always shut then (§4.3), so no other window is visible from the room.
- `CanopyPortal` also applies the viewer's storey offset, which fixes windows on upper storeys.

### 7.4 What changes as you cross

| | Aboard | Spacewalk |
|---|---|---|
| Parent | `Ship/Interior` | the scene's `Outside` root |
| Movement | `PLATING`: walking, plating gravity, shoves | `SUIT`: zero-g, thrusters (§8) |
| Motion mode | grounded | floating |
| Collision mask | interior geometry, items | exterior hull, items |
| Interactor mask | interior geometry | exterior props (layer 5) |
| Camera environment | interior mood | none (the world's) |
| Held items and hands | render layer 2, lit by interior lights | render layer 1, lit by the sun |
| `MotionCoupling` | shoves you | leaves you alone |
| HUD | as now | the suit's band and the airlock marker (§8.3) |

**What's in your hands comes with you** and comes back. A wielded item hangs from the hands and
a carried one moves with them; both switch render layers. Outside, your hands are **idle**: no
taking, dropping, throwing or using until you are back aboard (Grasp's new `suspended`, which,
unlike `set_enabled(false)`, keeps what you hold). Items in space are a later spec.

### 7.5 Crossing back in

- **When it happens:** the spacewalking avatar's origin passes 2 cm inward through the open outer
  hatch's plane.
- **The inverse transfer:**
  - **Velocity:** the velocity relative to the hull's velocity at that point, carried into
    interior axes and **capped at 4 m/s**.
  - **Orientation:** the body is set upright: yaw from the view direction projected onto the
    ship's floor plane, head pitch kept.
  - **Righting:** the camera keeps the view it had and **rights itself over 0.4 s**, so floating
    in tilted or upside down feels like ship gravity taking hold, not a cut.

---

## 8. The spacewalk

### 8.1 Moving

The avatar's `SUIT` mode:
- **Thrust along the view:** W/S forward and back, A/D sideways, Shift/Ctrl up and down (the
  ship's vertical keys).
- **Acceleration:** 2.5 m/s².
- **Turning:** the mouse yaws the body about its own up and pitches the head (±89°). Q/E roll the
  body at 90°/s. There is no up in space: you can turn any way.
- **Suit assist** (Z, on by default): on any axis without input, the suit spends the same
  acceleration bringing your velocity **relative to your own ship** to zero. The reference is the
  hull's velocity at your position. Near a drifting ship you hold station beside it; a ship
  pulling away faster than 2.5 m/s² still leaves you. With assist on, relative speed is capped at
  8 m/s. Off, it's pure Newton.
- **Collision:** `move_and_slide` against your hull. The hull ignores the avatar (its mask is
  hulls only), so a suit never pushes a 92 t ship.

### 8.2 Getting back

Fly to the hull panel beside the outer hatch, press F to open the hatch, float in, and press the
room panel.

### 8.3 HUD

- **The band:** the suit becomes the HUD's active vehicle, through the same duck-typed
  `build_telemetry()`. It shows your speed relative to the ship and the suit assist state.
- **`AirlockMarker`**, a new `HudElement`: a small ring over your airlock's outer hatch with its
  distance, clamped to the screen edge with a chevron when off-screen (the velocity marker's
  clamp policy). It shows only on a spacewalk.

---

## 9. The starter shuttle

- **No grid change:** the airlock at (0, 0, 3) opens aft onto open space. The corridor cell
  (0, 0, 2) becomes the corridor side of its partition.
- The lockers that stood in the airlock cell go (it is no longer common space).
- Step-out lands you behind the stern, between the engine pods at x = ±3 and under the stern
  thruster bank. The pods and bells are in view as you look out.

---

## 10. Architecture

```
src/ship/airlock/
  airlock_cycle.gd      AirlockCycle: state + pure step(); cues
  airlock.gd            Airlock node: one per airlock; events in, state out; threshold watch
  airlock_hatch.gd      AirlockHatch: leaves, bolts, window, strip, collider
  airlock_panel.gd      AirlockPanel: interactable button + 3D text readout
  airlock_show.gd       AirlockShow: steam particles, haze, lights for one side
  airlock_alcove.gd     builds the hull's copy of the room (called by ExteriorBuilder)
  threshold.gd          pure transfer maths (both directions), storey offset
src/avatar/suit.gd      the SUIT movement mode, suit assist, suit telemetry, suit sounds
src/audio/synth.gd      Synth: stream builders + cache
src/audio/audio_buses.gd  creates the Ship and Suit buses; pressure cutoff
src/ui/airlock_marker.gd
src/ship/hull_palette.gd
```

Modified:
- `interior_layout.gd`: the airlock zone and `AIRLOCK` variant;
- `interior_builder.gd`: the low ceiling and hatch-height doorway;
- `interior_dressing.gd`: the airlock room, hatches and panels;
- `interior_props.gd`: `hatch_frame`, `airlock_wall`, `airlock_ceiling`, `HATCH_HEIGHT`,
  `AIRLOCK_CLEAR`;
- `interior_kit.gd`: a render-layer and light-mask choice, so the alcove can use the kit on the
  own-hull layer;
- `interior_palette.gd`;
- `exterior_builder.gd`: the alcove instead of the block for airlocks;
- `ship.gd`: airlocks, cycles kept across rebuilds, audio;
- `ship_validator.gd`: Rule 6;
- `avatar.gd`: modes, righting, layer switching;
- `grasp.gd`: `suspended`;
- `interactor.gd`: mask per mode;
- `camera_director.gd`: EVA views;
- `motion_coupling.gd`;
- `canopy_portal.gd`: hull layer in the airlock, storey offset;
- `flight_test.gd`/`.tscn`: `Outside` root, marker, HUD wiring;
- `project.godot`: layer 5's name.

The props stay grid-blind (style guide §3). `AirlockHatch`, `AirlockPanel` and `AirlockShow` know
nothing about ships: they take a size, a frame and a body.

---

## 11. Testing

### 11.1 Automated (GUT, headless)

- **`test_airlock_cycle.gd`:**
  - the stage sequence and timings both ways;
  - the pressure curves;
  - calling from each outside panel;
  - reversing mid-cycle;
  - waiting on a blocked doorway;
  - auto-close after 2 s empty;
  - never two hatches open;
  - cues fired in order.
- **Layout:** the airlock zone; exactly one doorway, which is a hatch; the `HATCH` and `AIRLOCK`
  variants; no furniture; an inert airlock; the starter's airlock facing +Z.
- **Builder:** the airlock ceiling at the cell top (1.9 m clear); the hatch-height opening; its
  lintel.
- **Props:** `hatch_frame`, `airlock_wall` and the ceiling build in bare frames with pinned
  collider counts.
- **`AirlockHatch`:** the collider is enabled whenever not fully open; bolts and leaves move in
  order; the window is portal or glass as asked.
- **`AirlockPanel`:** prompts per state; readout text; the motion warning thresholds.
- **Exterior builder:**
  - an airlock with a hatch has no full-cell collider or block mesh;
  - it gets alcove colliders on the hull body;
  - an inert airlock is unchanged.
- **`test_threshold.gd`:**
  - out-and-back round trips exactly;
  - the storey offset;
  - velocity inheritance with a spinning, moving hull;
  - the 4 m/s cap;
  - upright entry.
- **`test_suit.gd`:**
  - thrust along the view;
  - assist brings relative velocity to zero and caps it;
  - assist off drifts;
  - roll.
- **Avatar:** `PLATING` mode unchanged (regression); mode switches set masks, layers, motion
  mode and environment; righting ends upright.
- **`Synth`:** every sound builds, is deterministic, is non-silent and fits its length.
- **Audio buses:** created once; the cutoff follows pressure.
- **Validator:** Rule 6 fixtures.
- **Scene, read back at runtime:**
  - the `Outside` root;
  - one `Airlock` in the starter with three panels and three hatches;
  - the marker registered;
  - layer 5 named.

### 11.2 Real-scene probes and renders

- **Walk probe:** into the airlock through the inner hatch after the corridor panel. Blocked by
  every shut hatch. Out through the open outer hatch; back in.
- **A scripted cycle out and back:**
  - the transfer's position is continuous to within 1 mm at each crossing;
  - with the ship drifting and turning, the spacewalker's velocity matches the hull's at the
    hatch;
  - the room keeps its pressure through a rebuild.
- **Renders for the owner:**
  - the corridor with the inner hatch;
  - inside the room at rest;
  - fog at each stage both ways;
  - the outer hatch opening;
  - standing in the open hatch looking out;
  - the moment of crossing, from both sides (compared pixel by pixel just before and after);
  - outside looking back into the alcove;
  - the hull face.
- **Frame time:** at rest, at peak steam, and outside, against the 120 fps budget at
  1280 × 720.

### 11.3 Playtest checklist

- Does stepping out feel like arriving somewhere?
- Is 4.7 s right for the twentieth trip?
- Is the crossing invisible?
- Can you always find your way back?

---

## 12. Amendments to other documents

- **Planetfall §10:** superseded by this spec. The threshold replaces the dark-beat transfer. A
  planet's refusals (*NOT LANDED*, *UNEVEN GROUND*, *HATCH BLOCKED*) become refusals of the room
  panel when a world is outside. §11's `FIELD` mode becomes a third avatar mode beside
  `PLATING` and `SUIT`.
- **Hands and items §15:** held items go through the airlock and back; items in space remain
  out of scope.
- **Visual style guide:**
  - the airlock room's deliberate low ceiling;
  - hatches versus sliding doors;
  - the first live-data screen;
  - the new palette entries;
  - `HullPalette` for exterior code;
  - built-in particles and 3D text as allowed alongside the three shaders;
  - a short section on the sound style.

---

## 13. Later, not built

- **Planets:** the threshold's far side becomes a world's surface: `FIELD` mode, surface
  gravity, the landing gate.
- **Other players:** already covered by button-only hatches and the call-to-your-side panels.
  Multiplayer itself is not designed.
- **Docking and boarding:** two airlocks stitched hatch to hatch (slice spec §3.2).
- **Magnetic boots**, suit fuel, tethers, items in space.

---

## 14. Risks

| Risk | Mitigation |
|---|---|
| The crossing is visible (lighting differs between the room and its hull copy) | Same props and frames; the alcove light matched to the room's; renders compared pixel by pixel at the crossing; tune the alcove light. |
| Synthesized sound sounds cheap | Soft, filtered, enveloped; judged by ear in playtest; the buses and cues stay if the sources are replaced by recordings later. |
| Particles cost too much on the GTX 960 | A few hundred chunky puffs for 4 s; measured; fewer puffs if needed. |
| The hull moving into a floating avatar | The avatar's own collision recovery pushes it out; it cannot move the hull. |
| Suit assist fights a ship turning fast | Assist has the same 2.5 m/s² as thrust; a ship spinning hard simply leaves you. The motion warning told you. |

---

## 15. As built (2026-09-24)

Where the build settled details this design left open, or changed them:

- **The inner door** is `AirlockSite.door_normal`: straight through, opposite the outer hatch,
  when that cell is walkable; otherwise a side. Open deck is preferred to a room. The layout uses
  this choice, so the hull's copy puts its inner hatch in the same place without reading the
  layout.
- **`HullPalette`** is `PANEL_LINE` and `RUNNING_LIGHT`. The hatch face is plated in the hull's
  livery material, so the red stripe runs across its top like the rest of the stern.
- **Coming back in**, you land 0.45 m inside the hatch, within 0.15 m of its centre, clear of the
  frame. The view starts exactly where your eye was, position and rotation, and eases to your head
  over 0.4 s.
- **Steam:**
  - 18 puffs per nozzle and a room fog of 48, with a near-camera fade;
  - haze peaks at 0.5 going out and 0.7 coming in, at density 0.9, which hides about 60% of the
    hatch 1.5 m away;
  - the burst out on the hull is 36 flat-lit, unshaded puffs.
- **Frame time** at 1280 × 720:
  - 208 fps in the room at rest;
  - 183 fps at the mist going out;
  - 136 fps at the thickest steam coming in;
  - 577 fps on a spacewalk.
- **Real-scene probe,** with the ship drifting and turning:
  - the view moves 0.1 mm at the crossing;
  - you leave with exactly the hull's velocity where you cross;
  - the suit holds station beside the ship;
  - the outer hatch closes behind you, and the hull panel reopens it;
  - you float back in tilted and land upright;
  - you cycle back in.

