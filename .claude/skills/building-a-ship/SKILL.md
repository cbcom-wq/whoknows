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
   - **the maintenance droid's needs** (NPC foundation spec §14), on any ship with 12 or more
     walkable cells: a `closet` for its dock (otherwise it docks in the walkable cell farthest
     from the helm), and every porthole, console, locker and fixture it tends reachable on foot
     from there over `DeckPaths`, which leaves out the airlock and every fixture's own cell.
     Fixtures side by side can wall off part of a room. `DeckPaths` steps diagonally past the
     corner between two **quiet fixtures** (core, machine, bridge computer), where the floor
     round that corner is open, but never past the helm. On the starter every job is reachable.
     Jobs it cannot reach are dropped; the probe prints the dock and names them `UNREACHABLE`.
   - **a `computer`** (optional) for the bridge computer's holo table, a quiet fixture: put the
     cell its frame faces (its operator's spot) on walkable deck, within the Interactor's 2.5 m of
     its buttons, and face it so the operator looks out of a window (the owner's wish, 2026-09-27:
     on the starter, the port front corner, facing aft). A console it displaces moves aft. The
     probe prints each table and where you stand to use it.
3. **Damage** (`docs/superpowers/specs/2026-09-29-health-and-damage-design.md`):
   - every block needs a sensible `hp` in its `.tres`: damage is taken against it, and a block
     goes damaged at half, wrecked at all of it and is knocked off at one and a half;
   - `core`, `pilot_seat` and every `airlock` are **kept**: wrecked, never knocked off;
   - a block knocked off takes with it every block no longer joined to the core, so don't hang
     half the ship off one cell (the probe's `damage` line counts the blocks one loss would cut
     off at worst);
   - the ship must not be **crippled as built** (forward thrust, every turning axis and a
     working `quantum_core`): the probe's `damage` line says so.
4. **Propulsion:**
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
5. **Validate:** `ShipValidator.validate(grid, catalog)` returns **zero issues**. Warnings count:
   a ship you give the player must not greet them with a brownout or a dead airlock.
6. **Balance:** read `ShipStats.compute(grid, catalog)`:
   - `power_gen > power_draw`, with margin;
   - no zero component in `torque_budget`;
   - `thrust_budget[&"reverse"] > 0`;
   - `torque_imbalance` within a few % of `torque_budget` on each axis. Fix it by moving mass or
     thrust, not by weakening the RCS;
   - the feel numbers (`torque_budget / inertia`, and each thrust budget divided by mass) are
     what you meant. The probe prints them.

   Pin all of this in a test (`reference.md` has one). The starter's numbers live only in its
   comments, so nothing would catch it drifting.
7. **Wire the scene:**
   - `Ship.set_grid(grid)` or `load_blueprint(bp)`;
   - a unique `interior_slot` per ship in a scene;
   - the `PilotSeat` transform from `InteriorDressing.fixture_frame(layout, seat)`;
   - the avatar spawn from `InteriorBuilder.floor_y(cell)`;
   - a `PilotControls` node beside the ship's `CameraDirector` (paths to its `FlightComputer`,
     `CameraDirector`, `Exterior` and `Interior`), and the HUD's vehicle set to that node while
     seated. It adds the stick and pointer to the flight computer's telemetry. `Ship` makes the
     `RcsShow` puffs and sounds itself;
   - anything outside the hull goes in `Universe.EXTERIOR_SPACE` (CLAUDE.md);
   - **a ship's state round-trips through the save** (`docs/superpowers/specs/
     2026-09-26-saving-design.md`). A block with state of its own (a fixture, a store, a door that
     can be left open) needs a `to_dict`/`from_dict` gathered by `Ship.to_dict`, a busy source in
     `Ship.busy()` if it has actions that run over time, and a line in
     `test_save_scene.gd`'s round-trip. The probe prints `save ... round-trips`;
   - **the warp** (`Ship/Warp`, a `WarpDrive`; `docs/superpowers/specs/2026-09-28-warp-design.md`):
     every ship gets one, and the flight scene binds it (`_wire_warp`). While it travels it
     freezes the hull kinematic and clears its layer and mask, restoring them at drop-out. Anything
     that sets the hull's `collision_layer`, `collision_mask` or `freeze` must check
     `warp.travelling()` first. How far a ship can warp is set by its store; the probe prints
     `warp    reach ...`.
8. **Run the full suite** (`who-knows/run_tests.ps1`). Add ship-specific tests: launches, stats,
   rooms, and the pod and airlock present.
9. **Probe the real scene:** run `ship_probe.gd` (in this folder) **without** `--headless`. It
   prints:
   - the validator, the stats, and the feel numbers;
   - any `rcs` whose exhaust is `BLOCKED`;
   - rooms, pods and airlocks;
   - the droid's dock and its jobs, flagging any `UNREACHABLE`;
   - fps.

   It also sits, stands and walks, and flags `STUCK`.
10. **Render and show the owner:** eye-height (1.6 m) views of the bridge, the seated view, the
   corridor, each room and the exterior, plus an outside view with each RCS axis firing (every
   block's puffs should show). Cycle the airlock both ways, look out of the windows, and hold
   ≥120 fps at 1280×720.
11. **Fly it:** a steady turn on the arrow keys, a clicked heading 120° away, and a speed-locked
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
| Warp reach on a full store | `(quantum_capacity − WarpPlan.WARP_BASE) / WarpPlan.WARP_PER_KM` km | 290 km on 1,200 QE (140 km on its starting 600) |

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
| A collision mask pinned as a number in a test (`1 \| 64 \| Npc.LAYER`) | Adding the `terrain` layer for worlds' shells broke five tests at once | Build expected masks from the named layers (`BodyProxy.LAYER`, `AsteroidBody.LAYER`, `Npc.LAYER`), and check the hull meets worlds: the probe's `bumps` line |
| A `#` comment in a `.tscn` | A silently dropped property or node, or a hung load | Comments in the `.gd`; read properties back at runtime |
| "Tests pass, so it looks right" | Whiteout steam, a head in the lights, rocks for puffs | Render at eye height and send the owner the pictures |
| RCS packed against other blocks | On the starter shuttle, 6 of 8 fire into a neighbour: yaw into pitch-down, pitch-up into the hull wedges, retros into pitch-up. Their puffs never show, and no validator rule catches it | Leave the face opposite each `rcs` block's push open to space; the probe flags `BLOCKED` |
| "Assist will stop the slide" | 500 kN of side thrust on 92 t: 100 m/s sideways takes 18 s to cancel after a turn | Size `lateral` / mass for the feel; assist can only spend what the RCS has |
| All RCS behind and above the helm | The pilot hears every thruster and sees none | Put some in view of the pod if they should be seen |
| A windowed script loading `flight_test.tscn` with saving on | Saving is on outside `--headless`, so a probe or render script would load and overwrite the owner's real game | Set `scene.save_enabled = false` before `add_child`, as `ship_probe.gd` does |
| Giving a new fixture state the save doesn't know | Quit and relaunch: the fixture is back to its defaults, silently | `to_dict`/`from_dict` on it, gathered in `Ship.to_dict`, and a round-trip test |
| A door trigger that sees only the avatar | Found while planning NPCs: a sliding door has no collider, so the droid would have trundled through it shut | `SlidingDoor.OPENS_FOR` is the avatar's layer and `npcs` (layer 8); anything new that opens for people opens for NPCs too |
| "The table adds 300 kg" | The bridge computer's spec pinned the starter at +300 kg and +0.3 MW, but the table replaced a 0.4 t deck cell drawing 0.1 MW: the ship came out 100 kg lighter, and the yaw imbalance the spec said it would ease doubled (still 0.3% of authority) | A block that replaces another changes the figures by the difference. Read the new ones from `ShipStats` (the probe), never add a block's own mass to the old total |
| A fixture beside two others on a bridge | The bridge computer in the port back corner, with the core and the machine, cut the droid off from the whole front of the bridge: helm, core, portholes, the table itself | Keep a way round on foot. `DeckPaths` now squeezes past the corner between two quiet fixtures; a new fixture that is not quiet gets no such step, so check the probe's `UNREACHABLE` line |
| A quiet fixture where the consoles are | Its own walls go plain, so a fixture at the glass or beside the helm would take the bridge's consoles with it, and the shoulder's desk would stand 5 cm from it | `InteriorLayout._handed_consoles` hands the console straight back to the last open cell's same wall; the shoulder drops its desk in front of a fixture. Render the corner it went to |
| `BlockInstance.hp_current`, never set | Every placed block sat at 0 hp from Slice 1 on; read as hp left, every ship would have been a wreck the day damage arrived | Blocks store **damage taken** (`damage`, 0 intact); older saves read as intact with no migration |
| Giving the hull a method it can't have | The hull `RigidBody3D` and the interior's code-made `StaticBody3D` have no script, so `receive_hit` could not live on them | `Hit.deliver(collider, hit)` calls a `&"receive_hit"` Callable in meta; hull colliders carry their cell in meta `&"cell"` (alcoves add several colliders for one cell, so shape index ≠ coord) |
| Raycasting a body built this frame | The torch's tests hit nothing: a new body joins the physics space on the next physics frame | Wait a physics frame (`await wait_physics_frames(2)`) before querying what a rebuild made |
| Recolouring one interior cell | The dressing is a few merged meshes, so there is no one cell's mesh to tint | A stage seen from inside rebuilds the ship once, deferred (`Ship._queue_rebuild`); it costs ~140 ms on the dev Xeon |
| Letting go of a warp at 120 m/s with the assist on | The assist cancels velocity nobody asked for, so the ship braked to rest at the warp limit instead of coasting in | `WarpDrive` sets the speed lock to 120 m/s at drop-out; anything else that hands the hull a velocity with the assist on must do the same |
| Letting the rest of the ship behave normally at warp | Found in the final review: you could cycle the airlock and step out mid-warp (stranded kilometres behind), the RCS kept its last command and puffed the whole way, and motion coupling read the frozen hull's placing as a 12 m/s² shove | Anything that acts on the hull's motion or lets someone outside asks `warp.is_spinning()` / `travelling()` first: `Airlock.warping()`, `FlightComputer`'s early return, `MotionCoupling._warp()` |
| A test script that types a local from the untyped `_root.system` and loops its `warp_targets()` | Godot 4.5.1 segfaulted at exit (ObjectDB leak, GUT's own scripts included) though every test passed | Hold the system in a typed member set in `before_each`, as `test_warp_drive.gd` does; watch the run's exit code, not only its pass count |
| An off-centre retro counted as steering | It would light up for yaw, but `ShipStats` never counts pure fore-and-aft thrust as authority | Steer with blocks that push across the hull; retros only brake |

## Not built yet (plan for it; don't assume it works)

- **Per-cell rebuilds.** Any removal, and any stage seen from inside, rebuilds the whole ship:
  ~140 ms headless on a 2.8 GHz Xeon for the starter. Fine for now; a hitch in a big fight.
- **Hull tint on `hull` / `hull_wedge`.** Their livery shader ignores the instance colour, so
  they don't look damaged from outside until the owner approves `ALBEDO *= COLOR.rgb`.
- **Debris and breaches.** A piece cut off vanishes in a burst; a hole has no air to lose.

- **Multi-storey interiors.** A `ladder` passes the validator, but every walkable cell still gets
  a solid floor and ceiling, so you can't climb.
- **The bubble canopy** pod variant.
- **The shipyard** (blueprints are built in code for now). Blueprints save with
  `ShipBlueprint.from_grid(grid, name)`, sorted and diffable.
