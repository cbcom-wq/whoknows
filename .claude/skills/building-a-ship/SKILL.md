---
name: building-a-ship
description: Use when designing, adding or changing a ship blueprint in the who-knows Godot project - a new ship, a second ship in a scene, a shipyard or generator emitting a grid, or moving the helm, canopy, airlock, engines, thrusters, reactors or rooms of an existing ship. Also when a ship won't launch, won't turn or brake, pitches under burn, slides long after a turn, browns out, has thrusters that never puff, or strands the player (stuck by the chair, an airlock that never cycles).
---

# Building a ship

## Overview

A ship is **one `ShipGrid` of 2 m blocks**. Everything else is generated from it and must never
be hand-placed: the hull, colliders, interior walls, rooms and doorways, the cockpit pod, the
airlock rooms and hatches, the stow points, and the flight stats. Building a ship means choosing
blocks and orientations, then **proving** the generated result launches, flies, can be walked
and looks right. Green tests prove structure, not looks or feel.

The worked example is the starter shuttle: `_starter_grid()` in `who-knows/scenes/flight_test.gd`.
Its comments explain every block that isn't obvious. Read it before you design.

**Read first:** `CLAUDE.md` (the style guide is binding; the floating origin; no `#` comments in
`.tscn`), `docs/design/visual-style.md` §3 and §6, and `reference.md` beside this file (blocks,
orientation codes, numbers, APIs).

## Checklist

Do these in order. Each one names the check that proves it.

1. **Lay out the decks.** −Z is the bow, +X starboard, +Y up. The proven pattern is y=0 a
   walkable cabin and y=+1 a solid equipment deck (core, reactors, grav plating). The roof stays
   flat.
2. **Place what the player needs:**
   - exactly one `core`, with every block face-connected to it;
   - one `pilot_seat` looking straight at a `canopy` block, which makes a cockpit pod. Keep the
     cell behind the seat walkable deck: you stand up into it.
   - an `airlock` with **exactly one** horizontal face onto an empty cell (its outer hatch), and
     walkable deck straight through on the opposite side, not a room.
   - room blocks (`bunk_room`, `galley`...) each touching walkable space for their doorway.
3. **Propulsion:**
   - main `thruster`s oriented FORWARD (`o=0`), at the stern;
   - `rcs` in **opposed pairs** on every axis: pitch, yaw and roll both ways;
   - a **retro pair** (BACK, `o=4`) so the ship can brake;
   - **side and vertical thrust sized for the feel you want.** Assist cancels drift with them, so
     `lateral / mass` is how fast travel swings onto the nose after a turn (see *What the
     blueprint decides about flying*);
   - **every `rcs` block's exhaust face open:** the face opposite its push must not touch
     another block, or its puffs are born inside that block and never show;
   - if the pilot should *see* the thrusters fire, some `rcs` in view of the pod or a window.
     Otherwise they are only heard from the seat.
4. **Validate:** `ShipValidator.validate(grid, catalog)` returns **zero issues**. Warnings count:
   a ship you give the player must not greet them with a brownout or a dead airlock.
5. **Balance:** read `ShipStats.compute(grid, catalog)`:
   - `power_gen > power_draw`, with margin;
   - no zero component in `torque_budget`;
   - `thrust_budget[&"reverse"] > 0`;
   - `torque_imbalance` within a few % of `torque_budget` on each axis. Fix it by moving mass or
     thrust, not by weakening the RCS;
   - the feel numbers (`torque_budget / inertia`, and each thrust budget divided by mass) are
     what you meant. The probe prints them.

   Pin all of this in a test (`reference.md` has one). The starter's numbers live only in its
   comments, so nothing would catch it drifting.
6. **Wire the scene:**
   - `Ship.set_grid(grid)` or `load_blueprint(bp)`;
   - a unique `interior_slot` per ship in a scene;
   - the `PilotSeat` transform from `InteriorDressing.fixture_frame(layout, seat)`;
   - the avatar spawn from `InteriorBuilder.floor_y(cell)`;
   - a `PilotControls` node beside the ship's `CameraDirector` (paths to its `FlightComputer`,
     `CameraDirector`, `Exterior` and `Interior`), and the HUD's vehicle set to that node while
     seated. It adds the stick and pointer to the flight computer's telemetry. `Ship` makes the
     `RcsShow` puffs and sounds itself;
   - anything outside the hull goes in `Universe.EXTERIOR_SPACE` (CLAUDE.md).
7. **Run the full suite** (`who-knows/run_tests.ps1`). Add ship-specific tests: launches, stats,
   rooms, and the pod and airlock present.
8. **Probe the real scene:** run `ship_probe.gd` (in this folder) **without** `--headless`. It
   prints:
   - the validator, the stats, and the feel numbers;
   - any `rcs` whose exhaust is `BLOCKED`;
   - rooms, pods and airlocks;
   - fps.

   It also sits, stands and walks, and flags `STUCK`.
9. **Render and show the owner:** eye-height (1.6 m) views of the bridge, the seated view, the
   corridor, each room and the exterior, plus an outside view with each RCS axis firing (every
   block's puffs should show). Cycle the airlock both ways, look out of the windows, and hold
   ≥120 fps at 1280×720.
10. **Fly it:** a steady turn on the arrow keys, a clicked heading 120° away, and a speed-locked
    turn at cruise. Compare them with the feel numbers you meant.

## What the blueprint decides about flying

Flight assist is the same for every ship (`docs/superpowers/specs/
2026-09-25-flight-controls-design.md` §5): it asks for 60°/s on each turning axis, and it spends
the **whole** side and vertical budget cancelling drift. The only thing that differs between ships
is the blueprint's budgets, so the grid decides the feel:

| Feel | Comes from | Starter shuttle |
|---|---|---|
| How fast a turn starts and stops | `torque_budget / inertia`, per axis | 1.74 / 0.79 / 2.05 rad/s² (pitch / yaw / roll) |
| A clicked heading swinging on | the weaker of pitch and yaw above | 120° in 3.1 s |
| Travel swinging onto the nose after a turn | `thrust_budget[&"lateral"]` (and `vertical`) / mass | 5.4 m/s²: 100 m/s sideways takes about 18 s |
| Braking; a speed lock slowing down | `reverse` / mass | 5.4 m/s² |
| Accelerating; a speed lock catching up | `forward` / mass | 16.3 m/s² |
| Thrusters the player sees | each `rcs` block's exhaust face open and in view | 6 of 8 blocked (only the pitch-down pair shows); none in the pilot's view |

A ship that slides for 18 s after a hard turn at speed is not a controls bug. It needs more side
thrust.

## Mistakes already made (don't repeat)

| Mistake | What happened | Do instead |
|---|---|---|
| Engines only at y=0, mass at y=+1 | 686,582 N·m pitch under burn against 160,000 of authority: unflyable | Raise the thrust line (a stern-roof thruster bank) or lower the mass |
| One UP + one DOWN RCS on opposite sides | Both rolled the same way: no roll authority | Mirror each vertical pair port and starboard |
| All engines facing aft | `reverse` = 0: the ship could never slow down | A retro RCS pair facing BACK |
| More thrusters, same reactors | A brownout warning on a starter ship | Add a reactor (12 MW each) |
| Seat position hard-coded in the `.tscn` | The collider and the drawn chair drifted apart | `fixture_frame`, the one source for both |
| Stand-up at a fixed offset from the chair | Wedged between the chair and the pod glass | `PilotSeat.STAND_SPOTS` + `Avatar.can_stand_at`; keep the cell behind the helm walkable |
| `ShipGrid.cell_center().y` for interior things | Off by the storey offset (storeys are 2.6 m, cells 2 m) | `InteriorBuilder.floor_y()` / `interior_center()` |
| Airlock with 0 or 2+ faces onto space | Inert: dressed as a plain room, never cycles | Exactly one open face; open deck through the inner hatch |
| Two ships sharing `interior_slot` | Their interiors overlap at y=−5000 | One slot each (2 km apart on x) |
| A node outside not in `EXTERIOR_SPACE` | Left behind by the 2 km origin shift | Join the group, or listen to `Universe.shifted` |
| A `#` comment in a `.tscn` | A silently dropped property or node, or a hung load | Comments in the `.gd`; read properties back at runtime |
| "Tests pass, so it looks right" | Whiteout steam, a head in the lights, rocks for puffs | Render at eye height and send the owner the pictures |
| RCS packed against other blocks | On the starter shuttle, 6 of 8 fire into a neighbour: yaw into pitch-down, pitch-up into the hull wedges, retros into pitch-up. Their puffs never show, and no validator rule catches it | Leave the face opposite each `rcs` block's push open to space; the probe flags `BLOCKED` |
| "Assist will stop the slide" | 500 kN of side thrust on 92 t: 100 m/s sideways takes 18 s to cancel after a turn | Size `lateral` / mass for the feel; assist can only spend what the RCS has |
| All RCS behind and above the helm | The pilot hears every thruster and sees none | Put some in view of the pod if they should be seen |
| An off-centre retro counted as steering | It would light up for yaw, but `ShipStats` never counts pure fore-and-aft thrust as authority | Steer with blocks that push across the hull; retros only brake |

## Not built yet (plan for it; don't assume it works)

- **Multi-storey interiors.** A `ladder` passes the validator, but every walkable cell still gets
  a solid floor and ceiling, so you can't climb.
- **The bubble canopy** pod variant.
- **The shipyard** (blueprints are built in code for now). Blueprints save with
  `ShipBlueprint.from_grid(grid, name)`, sorted and diffable.
