# Ship building reference

The facts behind `SKILL.md`, checked against the code on 2026-09-25. Paths are relative to
`who-knows/` unless they start with `docs/`. If a name here no longer exists, trust the code and
fix this file.

## Grid and blocks

- **Cell:** a 2 m cube (`ShipGrid.CELL_SIZE`). `ShipGrid.set_block(coord, BlockInstance)`. A
  `BlockInstance` has a `block_id`, an `orientation` (0..23) and `hp_current`.
- **Catalog:** `BlockCatalog.load_from_dir("res://data/blocks")`, with one `BlockDefinition`
  `.tres` per block.
- **Occupancy:**
  - SOLID fills the cell;
  - DECK is walkable open volume;
  - MOUNT is a walkable fixture.

  Walkable means DECK or MOUNT.

| id | occupancy | t | MW made | MW drawn | kN | notes |
|---|---|---|---|---|---|---|
| core | solid | 4.0 | | 2.0 | | exactly one; everything connects to it |
| reactor | solid | 5.0 | 12 | | | |
| thruster | solid | 2.5 | | 3.0 | 300 | main engine |
| rcs | solid | 1.0 | | 1.0 | 250 | steering; also retro, lateral, vertical |
| grav_plating | solid | 1.5 | | 1.5 | | `grav_radius` 6 m |
| battery | solid | 2.0 | | | | |
| hull | solid | 1.0 | | | | |
| hull_wedge | solid | 0.6 | | | | chamfer set by orientation roll |
| armour | solid | 3.0 | | | | |
| canopy | solid | 0.5 | | | | the interior face onto it is glass |
| bulkhead | solid | 0.8 | | | | |
| deck | deck | 0.4 | | 0.1 | | open bridge or corridor |
| bunk_room, galley, bathroom, closet, weapon_room | deck | 0.4 | | 0.1 | | rooms (`InteriorLayout.ROOM_IDS`) |
| airlock | deck | 1.2 | | 0.6 | | |
| door | deck | 0.6 | | 0.3 | | |
| pilot_seat | mount | 0.5 | | 0.5 | | the helm |
| ladder | mount | 0.3 | | | | vertical link in `DeckGraph` only (see SKILL.md) |

Room blocks weigh and draw exactly what `deck` does, so swapping deck for rooms never moves the
balance. `test_starter_shuttle.gd` holds this.

## Orientation codes

`o = (forward_index << 2) | roll`. The forwards are `[FORWARD(-Z), BACK(+Z), LEFT(-X), RIGHT(+X),
UP(+Y), DOWN(-Y)]` (`BlockOrientation`). A thruster's force on the ship acts along its local −Z.

| o | name in flight_test.gd | force / use |
|---|---|---|
| 0 | `O_FORWARD` | pushes the ship bow-ward (main engines at the stern); canopy and wedge slope up-forward |
| 1 / 3 | `O_STARBOARD_FWD` / `O_PORT_FWD` | forward, rolled: `hull_wedge` chamfer to +X / −X |
| 4 | `O_STERN` | pushes aft: a **retro** RCS; `hull_wedge` tail taper |
| 8 / 12 | `O_RCS_PORT` / `O_RCS_STARBOARD` | lateral −X / +X |
| 16 / 20 | `O_RCS_UP` / `O_RCS_DOWN` | vertical +Y / −Y |

## Validator (`ShipValidator.validate`)

| code | severity | rule |
|---|---|---|
| SINGLE_CORE | error | exactly one `core` |
| ALL_CONNECTED | error | every block face-connected to the core |
| HAS_PILOT_SEAT | error | at least one `pilot_seat` |
| MOUNTS_REACHABLE | error | every MOUNT walkable from the seat (`DeckGraph`; vertical moves need a ladder at one end) |
| POWER_MARGIN | warning | draw > generation |
| AIRLOCK_HATCH | warning | an airlock without exactly one horizontal face onto an empty cell |

`can_launch(issues)` is false only on errors. A ship given to the player should have **zero**
issues.

## Flight balance (`ShipStats.compute`)

- **Budgets:**
  - `thrust_budget` is a Dictionary keyed `&"forward"`, `&"reverse"`, `&"lateral"` and
    `&"vertical"`, in newtons;
  - `torque_budget` is (pitch, yaw, roll) authority in N·m. Only RCS counts, and **each axis takes
    the smaller of its two directions**;
  - `torque_imbalance` is the torque from a full forward burn about `center_of_mass`.
- **Where each value comes from:**
  - the centre of mass comes from block masses at cell centres;
  - a thrust line away from it (up/down or sideways) gives `torque_imbalance`;
  - a lone thruster in one direction gives zero authority on its axis.
- **The starter shuttle:**
  - 84 blocks, 92.3 t, centre of mass (0, 1.27, 0.33);
  - thrust 1500 forward, 500 reverse, 500 lateral and 1000 vertical kN;
  - authority (3.16, 2.08, 2.18) MN·m against an imbalance of (0.10, 0, 0) MN·m;
  - 36.0 MW made, 30.8 MW drawn.
- **The starter's feel:**
  - turn acceleration 1.74 / 0.79 / 2.05 rad/s² (pitch, yaw, roll);
  - side 5.4, vertical 10.8, brake 5.4 and forward 16.3 m/s².
- **Handling (flight controls, 2026-09-25):**
  - arrow keys give a steady 60°/s;
  - a clicked heading 120° away settles in 3.1 s, overshooting 1.2°;
  - after a 94° turn at 100 m/s with the speed locked, travel was still not on the nose after
    15 s.
- **One quirk:** `lateral` and `vertical` sum every block's push along that axis **in both
  directions**, unlike `torque_budget`. The starter's two nose lateral RCS (250 kN each, one per
  side) count as 500 kN either way, and the flight computer spends that as a single central
  force. Budgets, not individual thrusters, are what the physics uses.

How `FlightComputer` spends the budgets (`src/flight/flight_computer.gd`):
- **Turning:** `attitude_torque` chases a turn rate (`ASSIST_TURN_RATE`, 60°/s at full stick),
  clamped to `torque_budget`.
- **Heading hold:** `heading_rate` brakes on the weaker of pitch and yaw's `torque_budget /
  inertia`.
- **Translation:** `translation_force` cancels unwanted velocity with the **whole** `lateral` and
  `vertical` budget (`DRIFT_AUTHORITY` = 1.0). Fore and aft, it catches up with `forward` (the main
  engines) and slows with `reverse`, which also holds a speed lock.

A test to pin a new ship. `_grid` comes from wherever the blueprint is built; see
`test_starter_shuttle.gd` for how it gets `_starter_grid()`:

```gdscript
func test_the_new_ship_flies():
	var s := ShipStats.compute(_grid, _cat)
	assert_eq(ShipValidator.validate(_grid, _cat).size(), 0, "zero issues, warnings included")
	assert_gt(s.power_gen, s.power_draw * 1.1, "power with margin")
	assert_gt(s.thrust_budget[&"reverse"], 0.0, "it can brake")
	for axis in 3:
		assert_gt(s.torque_budget[axis], 0.0, "authority both ways on axis %d" % axis)
		assert_lt(absf(s.torque_imbalance[axis]), s.torque_budget[axis] * 0.05, "no fight under burn")
```

## What the interior makes of the grid

All of this is `ship.interior_builder.layout()` (`InteriorLayout`), which reads the grid and
touches no nodes.

- **Faces:**
  - every walkable cell gets a floor and a ceiling;
  - each horizontal face not onto walkable space is a wall, or glass where the neighbour is a
    `canopy`.
- **Zones:**
  - fixture (MOUNT) cells, cells beside a fixture, and cells beside a canopy are **bridge**;
  - other deck is **common**;
  - bridge and common are one open space;
  - room blocks are walled off, each with **one doorway** (`rooms()`: zone, coords, doorway);
  - a working airlock is a room of its own.
- **The pod:** a `pilot_seat` facing a canopy face makes that face a **pod** (`pods()`). The pod
  is a 2 m mouth, 2.4 m wide inside and 1.9 m deep, so it fits inside the canopy cell ahead. The
  chair stands 0.7 m out in it (`POD_SEAT_DEPTH`). The other faces of that windshield become
  shoulders with portal windows. A windshield with no helm gets a rounded nose.
- **The airlock:** `airlocks()` returns `coord`, `hatch_normal` and `door_normal`.
  - The outer hatch (`AirlockSite.hatch_normal`) is the one face onto an empty cell.
  - The inner hatch (`door_normal`) is straight through if that cell is walkable. Otherwise it is
    a side, and open deck beats a room. It is ZERO if there is nowhere to open onto.
  - The room is 1.9 m clear, with hatches 1.0 × 1.85 m. It has an exact copy on the hull
    (`AirlockAlcove`), and the cycle takes about 4.7 s.
- **Storeys:** 2.6 m (`STOREY_HEIGHT`), with 2.5 m of headroom. The floor is anchored to the grid.
  Storey 0's floor top is at interior y −0.95 (`floor_y`).
- **Interior space:**
  - it sits at `Ship.INTERIOR_WORLD_BASE` (0, −5000, 0) + `interior_slot` × 2000 m on x, and
    never moves;
  - interior-local equals hull-local on storey 0.
- **The pilot seat and standing up:**
  - the seat's interactable box is 1.4 × 1.6 × 1.4 m;
  - standing up tries `PilotSeat.STAND_SPOTS` in the seat frame (first 1.3 m straight back),
    else where you sat from;
  - the avatar is a capsule of radius 0.35 m and height 1.8 m, with the eye at 1.6 m; a room
    needs an aisle ≥ 1.0 m.

## Thrusters you see and hear (`RcsShow`, `src/flight/rcs_show.gd`)

`Ship` builds one on the hull (`Ship/Exterior/RcsShow`) and rebuilds it with the stats, so any
blueprint gets it for free.

- **Which blocks:** every block with id `rcs` (`RcsShow.BLOCK_ID`). A new small-thruster block
  type needs adding there. Main `thruster`s have no plume yet.
- **Where it puffs:** the nozzle is the face opposite the push, `cell_center − f̂ × 1 m`. It is
  one world-space `GPUParticles3D`:
  - in `Universe.HOLDS_SHIFT`;
  - on render layer 1, so windows show it;
  - using the shared chunky `Puffs`, 0.7–1.0 m.

  If the neighbouring cell on that face holds a block, the puffs start inside it and never show.
- **Where it sounds:** one `AudioStreamPlayer3D` under `Ship/Interior` at
  `cell_center + (0, storey_offset(y), 0)`, on the Ship bus. It is heard only while the camera is
  aboard.
- **How hard it fires:** each tick it takes the flight computer's commanded twist and push,
  measured as shares of the budgets, and compares each block's own twist or push with them.
  - Only blocks that push across the hull count for turning (as in `ShipStats`).
  - Only aft pushes count for moving; forward is the main engines'.
  - `firing_for` is pure, and `test_rcs_show.gd` pins which starter blocks light for each
    command.

## Scene wiring (as in `flight_test.gd`)

```gdscript
_ship.set_grid(grid)            # or _ship.load_blueprint(bp)
var layout := _ship.interior_builder.layout()
$Ship/Interior/PilotSeat.transform = InteriorDressing.fixture_frame(layout, seat_coord)
var cell := seat_coord + Vector3i(0, 0, 1)      # spawn a cell aft of the seat
var c := ShipGrid.cell_center(cell)
$Ship/Interior/Avatar.position = Vector3(c.x, InteriorBuilder.floor_y(cell) + 0.05, c.z)
```

A second ship in the same scene needs its own `interior_slot`. The exterior hull body is already
in `Universe.EXTERIOR_SPACE` and `AsteroidStream.SPACE_ANCHOR`, because `Ship._ready` puts it
there.

A flyable ship also needs a `PilotControls` node under the ship, with the paths shown in
`flight_test.tscn`. It listens to `CameraDirector.piloting_changed`. While you sit, the HUD's
vehicle is that node, not the `FlightComputer`:

```gdscript
_hud.set_active_vehicle(_pilot if piloting else null)   # _pilot: $Ship/PilotControls
```

## Commands

- **Tests:** `who-knows/run_tests.ps1`, or `-gselect=test_name` for one file (PowerShell).
- **After adding a `class_name`:** `<godot> --headless --path who-knows --import`.
- **Probe:** `<godot> --path who-knows --resolution 1280x720 --script <abs>/ship_probe.gd --
  <abs out dir>`. Use absolute paths, and don't pass `--headless`: headless never renders or
  compiles shaders.
- **Godot:** `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe`.
- **Testing a real scene in GUT:**
  - load `res://scenes/flight_test.tscn` and `add_child_autofree`;
  - then `await wait_process_frames(2)` before sitting. `wait_frames` counts **physics** frames,
    and the canopy camera is placed on the first process frame.
  - `test_pilot_seat.gd` and `test_avatar_modes.gd` are the patterns to copy.

## Specs to read for depth

- `docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md`: envelope, proportions,
  blueprint §3 and its acceptance criteria.
- `docs/superpowers/specs/2026-08-21-who-knows-slice-1-design.md` §6.1: the build rules.
- `docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md`: rooms, walls, doorways.
- `docs/superpowers/specs/2026-09-23-cockpit-pod-design.md`: the pod, the chair, standing up.
- `docs/superpowers/specs/2026-09-24-airlock-design.md`: the airlock.
- `docs/superpowers/specs/2026-09-24-asteroids-design.md` §4: the floating origin.
- `docs/superpowers/specs/2026-09-25-flight-controls-design.md`: how the flight computer spends
  the budgets, the RCS show, and (§9.4) what the starter's layout does to the feel.
