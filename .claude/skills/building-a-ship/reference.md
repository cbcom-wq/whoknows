# Ship building reference

The facts behind `SKILL.md`, checked against the code on 2026-09-29. Paths are relative to
`who-knows/` unless they start with `docs/`. If a name here no longer exists, trust the code and
fix this file.

## Grid and blocks

- **Cell:** a 2 m cube (`ShipGrid.CELL_SIZE`). `ShipGrid.set_block(coord, BlockInstance)`. A
  `BlockInstance` has a `block_id`, an `orientation` (0..23) and `damage` (hp lost, 0 intact; health and damage spec §4.2).
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
| hull_wedge | solid | 0.6 | | | | chamfer set by orientation roll; the same wedge as `fairing_slope` |
| armour | solid | 3.0 | | | | |
| canopy | solid | 0.5 | | | | the interior face onto it is glass, or a pod; outside it is a wedge, and the interior decides what it looks like (below) |
| fairing_slope | solid | 0.3 | | | | structure, 40 hp, no mesh (the skin draws it): a full diagonal wedge, high at the back |
| fairing_slope_long_low | solid | 0.3 | | | | the lower half of a two-cell ramp, 0 to 1 m across the cell |
| fairing_slope_long_high | solid | 0.3 | | | | the upper half: a 1 m block with a 1 to 2 m ramp on top |
| fairing_corner_out | solid | 0.3 | | | | a quarter pyramid, an outer corner |
| fairing_corner_in | solid | 0.3 | | | | an inner corner, two slopes (not convex) |
| fairing_half | solid | 0.3 | | | | the bottom half of a cell, a 2 × 1 × 2 m box |
| bulkhead | solid | 0.8 | | | | |
| deck | deck | 0.4 | | 0.1 | | open bridge or corridor |
| bunk_room, galley, bathroom, closet, weapon_room | deck | 0.4 | | 0.1 | | rooms (`InteriorLayout.ROOM_IDS`) |
| airlock | deck | 1.2 | | 0.6 | | |
| door | deck | 0.6 | | 0.3 | | |
| pilot_seat | mount | 0.5 | | 0.5 | | the helm |
| computer | mount | 0.3 | | 0.3 | | the bridge computer's holo table; a quiet fixture, optional |
| ladder | mount | 0.3 | | | | vertical link in `DeckGraph` only (see SKILL.md) |

Room blocks weigh and draw exactly what `deck` does, so swapping deck for rooms never moves the
balance. `test_starter_shuttle.gd` holds this.

The six fairings are STRUCTURE at 0.3 t against 1.0 t for `hull`, so reshaping a blueprint moves
its balance only a little. They have no `mesh` of their own: `test_block_data.gd`'s "every block
has a mesh" skips ids that start `fairing_`. Their orientation works as `hull_wedge`'s does.

## Orientation codes

`o = (forward_index << 2) | roll`. The forwards are `[FORWARD(-Z), BACK(+Z), LEFT(-X), RIGHT(+X),
UP(+Y), DOWN(-Y)]` (`BlockOrientation`). A thruster's force on the ship acts along its local −Z.

| o | name in flight_test.gd | force / use |
|---|---|---|
| 0 | `O_FORWARD` | pushes the ship bow-ward (main engines at the stern); canopy and wedge slope up-forward |
| 1 / 3 | `O_STARBOARD_FWD` / `O_PORT_FWD` | forward, rolled: `hull_wedge` chamfer to +X / −X |
| 2 | `O_KEEL` | forward rolled 180°: a `fairing_half`'s upper half, hung under a cell (the starter's keel) |
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
- **The starter shuttle** (reshaped by the ship exterior spec, 2026-09-29; Godot's figures):
  - 110 blocks (84 and 26 fairings), 104,700 kg, centre of mass (0.004, 1.301, 0.160);
  - inertia (2,065,526, 2,865,503, 1,175,422);
  - thrust 1500 forward, 500 reverse, 500 lateral and 1000 vertical kN;
  - authority (3,080,229, 2,040,115, 2,174,785) N·m against an imbalance under burn of
    (151,289, −5,731, 0): pitch **4.91%**, yaw 0.28%, roll 0% of authority (the rule is 5%);
  - 36.0 MW made (all from the quantum core), 31.3 MW drawn, 1200 QE, zero validator issues.
- **The starter's feel:**
  - turn acceleration 1.49 / 0.71 / 1.85 rad/s² (pitch, yaw, roll);
  - forward 14.3, brake 4.8, side 4.8 and vertical 9.6 m/s². 100 m/s sideways gone in 21 s;
  - `rcs` exhaust BLOCKED on 6 of 8, as it was before the reshape.
- **Before the reshape** (84 blocks): 96,900 kg, centre of mass (0.004, 1.207, 0.124), pitch
  imbalance 0.36%, feel 1.60 / 0.74 / 2.05 rad/s², 15.5 / 5.2 / 5.2 / 10.3 m/s². This file and
  `SKILL.md` had carried older figures still (1.74 / 0.79, 5.4, 16.3); they were stale. The
  reshape's 26 fairings add 7.8 t and no power. 6.0 t of it is above the cabin and 1.8 t below,
  which lifted the centre of mass 9 cm.
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

## Who lives aboard (NPC foundation spec §14)

`Ship` makes an `NpcDirector` (`Ship.npc_director`, rule `BY_SITE`, at most 8) and a
`StimulusBus` (`Ship.npc_bus`) for its interior, and rebinds its `crew_site` (`ShipSite`) after
every rebuild. Any blueprint gets its crew from its own layout:

- **`ShipCrew.records(layout, paths, ship, seed)`:** one `maintenance_droid` if the layout has at
  least `ShipCrew.MIN_CELLS` (12) walkable cells and a dock.
- **`ShipCrew.dock(layout, paths)`:** the first cell of a `closet` room, else the path cell
  farthest from the cells beside the helm.
- **`ShipCrew.reachable_spots(layout, paths)`:** the jobs it can walk to from its dock;
  `ShipSite.spots` holds these and `ShipSite.unreachable` the rest.
- **`ShipCrew.work_spots(layout, paths)`:** `{cell, facing, action, key}`: portholes `&"polish"`,
  `CONSOLE`/`DISPLAY` walls `&"scan"`, `LOCKERS` `&"tidy"`, and each fixture `&"scan"` from its
  first walkable neighbour.
- **`DeckPaths.build(layout, avoid)`:** walkable cells joined where no wall face stands between
  them, doorways included; never the airlock (`AIRLOCK_ZONE`), a fixture's cell, or a cell in
  `avoid` (the ship passes none: the felt gravity is the same in every cell). Also one diagonal
  step: past the corner between two cells that are both `InteriorLayout.QUIET_FIXTURES`, when no
  wall or doorway stands on any of the four edges round it (1.3 m clear between the table and
  the core on the starter). `path(from, to)`, `distances(from)`, `linked(a, b)`, `cell_at(p)`,
  `floor_point(cell)`.
- **Layers:** NPCs are physics layer 8, `npcs` (128). Inside, an `Npc`'s mask is 2 | 4 | 32;
  the avatar's, items' and the doors' masks include 128.
- **Felt gravity:** the droid reads `FeltGravity.felt`, the same number loose items get; it holds
  against 8 m/s² of shove walking and 10 braced, and slides past that.

## The bridge computer (bridge computer spec)

- **The block:** `computer` (`InteriorLayout.COMPUTER_ID`), MOUNT, 0.3 t, 0.3 MW, hp 60, in
  `InteriorLayout.QUIET_FIXTURES`: its own walls go plain, or a porthole on the skin, and nothing
  else round it changes. Not required by the validator.
- **Its frame** (`InteriorDressing.fixture_frame`): −z toward where you stand to use it. On the
  starter it is at (−1, 0, −3), the port front corner, orientation 4 (facing +z, aft), used from
  (−1, 0, −2), looking forward out of the shoulder window.
- **Consoles it displaces** (`InteriorLayout._handed_consoles`): a quiet fixture at a canopy face
  or beside a loud fixture hands each wall that would have been a console straight back, away
  from the glass, to the same wall of the last open bridge or common cell behind it (on the
  starter, the port wall of (−1, 0, −1)). A shoulder in front of a fixture drops its desk
  (`InteriorProps.shoulder(..., with_console)`).
- **The prop:** `InteriorProps.holo_table`, a 1.1 m top at 0.9 m on a pedestal, a rim console
  tilted 55° on the operator's side; colliders 1.0 × 0.95 × 1.0 m and the console's lip, nothing
  above 1.05 m. Frames: `holo_table_console()`, `holo_table_screen()`, `holo_table_buttons()`
  (PAGE, RANGE, ◀, big, ▶), `holo_table_volume()` (centre 1.35 m).
- **At runtime:** the dressing builds a `ShipComputer` per table
  (`InteriorBuilder.computers()`); `Ship` binds each to a `ComputerContext` (its sensors, store,
  stats, hull, exterior builder) after every rebuild and keeps its page, range and selection by
  cell across one. The status page's miniature shares `ExteriorBuilder.hull_meshes()` (the skin's
  plating and trim, and the windows and pod shell, every batch but the glows, an `Array[Mesh]`;
  `multimeshes()` is gone), sized by
  `ExteriorBuilder.bounds()`, so any blueprint gets its own model.
- **The sensors** (`Ship.sensors`): `RockContacts` (big rocks to 30 km) and `LifeContacts` are
  registered by the flight scene. One course per ship: `set_course(id)`, `clear_course()`,
  `course_contact()`, `check_course()` at 4 Hz, signals `course_changed` and `course_arrived`;
  it arrives inside a region or within `ARRIVE_ROCK` (1 km) of a big rock's surface.
- **On the starter** (Godot's figures, 2026-09-27, the flat hull; the reshaped starter's are
  under *Flight balance* and *The hull's outside*): 84 blocks, 96,900 kg, centre of mass
  (0.004, 1.207, 0.124), torque imbalance (11,146, −6,192, 0) N·m, 31.3 MW drawn of 36.0; the
  droid reaches all 12 of its jobs.

## The hull's outside (ship exterior spec, `docs/superpowers/specs/2026-09-28-ship-exterior-design.md`)

The hull's outside is generated from the grid and the interior's layout, like the interior. The
pieces, all under `src/ship/` unless stated:

- **`HullShapes`** (`hull/hull_shapes.gd`, static, pure). The shapes a block can have, block-local
  (a cell spans −1..1 m, the block facing FORWARD): `CUBE`, `SLOPE`, `SLOPE_LONG_LOW`,
  `SLOPE_LONG_HIGH`, `CORNER_OUT`, `CORNER_IN`, `HALF`.
  - `BY_ID` maps every non-cube block id to its shape: `hull_wedge` and `canopy` to `SLOPE`, and
    each fairing to its own.
  - `shape_of(id)`, `points(shape)`, `faces(shape)` (records `{points, normal, side, full}`; it
    returns the shared cache, so **never mutate it**), `covers(shape, orientation, hull_normal)`
    (does it fill that whole cell face), `contains(shape, p)` (an unknown shape counts as a cube)
    and `collider_parts(shape)` (the convex pieces; `CORNER_IN` is two slopes).
- **`HullLayout.plan(grid, catalog, interior)`** (`hull/hull_layout.gd`, pure `RefCounted`,
  deterministic; touches no nodes). Its arrays, and their keys:

  | Array | Keys | What |
  |---|---|---|
  | `plates` | `coord, normal, lo, hi` | a plate per exposed cube face; `lo`/`hi` are its corners (Vector2 in the face frame), cut back by the chamfer on each side that has one |
  | `edges` | `coord, a, b, axis, ends, running` | a chamfer on a convex edge; `running` marks a cyan strip |
  | `corners` | `coord, sign` | a facet where three chamfers meet |
  | `facets` | `coord, shape, orientation, face` | an exposed face of a shaped block |
  | `nozzles` | `coord, normal, kind` | a bell (`thruster`) or pod (`rcs`) on the exhaust face, if open |
  | `windows` | `frame, size, round, coord` | a window outside, its skin frame and size |
  | `pods` | `frame, cell` | a cockpit pod's shell, in the interior's pod frame, brought to hull space |
  | `mounts` | `group, position, normal, aim, coord` | a light's place, on the cell `coord`; `group` is `&"flood"` or `&"forward"` |
  | `unmatched` | `coord, normal` | an inside window with no place outside: empty on any ship you give the player |

  Also `wanted` (how many inside windows there are), `skin` (`Vector3i` to the open faces of each
  cube), `shape_at(coord)`, `inside(p)` and `is_pod_cell(coord)`. The `ALCOVE` cells (an airlock
  that can cycle) are `AirlockAlcove`'s, and the skin leaves them.
  - **Static frames:** `face_basis(n)`, `face_frame(coord, n)` (+z out of the hull, +y up the face
    or toward the bow on a roof or belly), `edge_frame(e)`, `edge_span(e)`, `corner_frame(c)`,
    `cell_frame(coord, orientation)`, `facet_face`, `facet_points`, `facet_normal`, `facet_centre`.
  - **Numbers:** `CHAMFER` 0.4 m, `FLOOD_TILT_DEG` 25, `FLOOD_SPACING` 6 m, `BELLY_BAND` 1.5 m,
    `FORWARD_MIN_DOT` 0.7, `FORWARD_BOW_BAND` 2.5 m, `FORWARD_BELOW_WINDOW` 0.3 m,
    `FORWARD_DROP_DEG` 5, `FORWARD_TOE_DEG` 3.
- **`HullProps`** (`hull/hull_props.gd`) builds from `(kit, frame, ...)` and never sees the grid:
  `plate`, `chamfer_strip`, `corner_facet`, `facet`, `thruster_bell`, `rcs_pod`, `running_strip`,
  `window_porthole`, `window_rect`, `pod_shell`, `flood_fixture`, `forward_fixture`, `beam_cone`.
  - **Numbers:** `PLATE_PROUD` 0.05 m, `PLATE_BEVEL` 0.04, `PLATE_GAP` 0.04, `RUNNING_WIDTH` 0.06,
    `FRAME` 0.1, `GLASS_Z` 0.07 (glass and bands stand in front of a proud plate), `POD_SKIN` 0.08,
    `POD_BELOW` 0.12, `POD_ROOF_THICK` 0.1, `POD_LIP` 0.1, `BEAM_NEAR` 0.15.
  - Plates go in the kit's `HULL` batch (the livery), trim and seams in `SOLID`, anything lit in
    `GLOW`, glass in its own batch material. **The plating's vertex colour is
    `HullPalette.UNHURT` (white)**: the livery multiplies its albedo by it, and the damage tint
    replaces it. Never give `HULL` a palette colour, or every plate darkens by it.
- **`HullMaterials`** (`hull/hull_materials.gd`): `livery()`, `trim()`, `window_glass()`,
  `glow_instance(energy)` (a glow material of its own, so its energy moves alone), `beam(colour)`;
  `WINDOW_ENERGY` 2.4, `BEAM_ALPHA` 0.012, `BEAM_MID_ALPHA` 0.2. **`HullPalette`** gains `PLATE`,
  `TRIM`, `WINDOW_GLASS`, `WINDOW_LIGHT`, `WORK_LIGHT` (= `WORK_LIGHT_WARM`, `#ffe9cc`),
  `WORK_LIGHT_COOL` (`#e4eeff`, kept until the owner picks) and `NOZZLE_DARK`.
- **`HullDressing.build(layout, root)`** (`hull/hull_dressing.gd`) returns
  `{"meshes": Array[Mesh], "lenses": {group: MeshInstance3D}, "window_glow": ShaderMaterial,
  "spans": {coord: [[ArrayMesh, from, to], ...]}, "surfaces": {ArrayMesh: arrays}}`. The meshes
  are the plating and trim (for the miniature). `spans` are each cell's runs of vertices in the
  `TINTED` batches (`HULL`, `SOLID`, `GLASS` of `Skin/Hull` and `Windows`), noted with
  `InteriorKit.vertex_count(batch)` around each piece; `surfaces` are those meshes' arrays, kept
  by `InteriorKit.keep_arrays`. **Every piece belongs to one cell:** plates, chamfers and corners
  their record's `coord`, facets, nozzles and windows theirs, a pod shell its `cell`, a light
  fixture its mount's `coord`. A new piece must be marked the same way (`_counts`, then `_mark`),
  or damage won't tint it; `test_every_tinted_skin_vertex_belongs_to_one_cell` fails. Each kit is under its own child of `root`
  (`Skin/Hull/DressingHull`, `DressingSolid`; `Windows`; `Lens_flood`, `Lens_forward`) so its
  merged meshes keep their names. All on `ExteriorBuilder.OWN_HULL_LAYER` (4), light mask
  `1 | 4`.
- **`ExteriorBuilder` accessors:** `layout()` (the `HullLayout`), `hull_meshes()`, `lenses()`,
  `window_glow()`, `light_mounts()`, `bounds()`, `alcoves()`, `collider_coords()`. Colliders are
  a box per cube cell, and one `ConvexPolygonShape3D` per `HullShapes.collider_parts` piece for
  a shaped block, under `HullLayout.cell_frame`. A pod's canopy cell keeps a box. **Every
  collider carries meta `&"cell"`**: each convex part of a shaped block, and each of an alcove's.
  `multimeshes()`, `tintable()` and the per-block `MultiMesh`es are gone.
- **`ShipLights`** (`ship_lights.gd`, `Ship.lights`, at `Ship/Exterior/Lights`, so the floating
  origin carries it):
  - state `floods`, `forward`; signal `changed`; `interior_level` and `exterior_level` (1, or 0.5
    in low power, from `apply_power(low)` each frame off the ship's `QuantumPlant`);
  - `bind(mounts, lenses, window_glow)` after each rebuild remakes one `SpotLight3D` and one
    beam per mount; `toggle(group)`, `set_group`, `is_on`, `spots(group)`, `beam(group)`;
  - `to_dict()` / `from_dict(d)`: the save's `lights` part, `{"floods": bool, "forward": bool}`;
    missing means both off. Both start off;
  - `SETTINGS`: floods cone 55°, reach 40 m, energy 4, **shadows on**; forward cone 22°, reach
    220 m, energy 16, shadows on. `LIGHT_MASK` `1 | 4`, `BEAM_LAYER` 1, `BEAM_FRACTION` 0.6,
    `LOW_POWER_LEVEL` 0.5. A spot's `spot_angle` is half the cone;
  - the beams' `transparency` follows `exterior_level`; the lenses' glow energy and the windows'
    follow their levels.
- **At the helm:** `lights_flood` on **L**, `lights_forward` on **K** (`project.godot`).
  `PilotControls.lights` (set by the scene) toggles while seated only, and adds `has_lights`,
  `floods_on`, `forward_on` to the telemetry; `VelocityPanel.lights_label` reads `FLOOD ON   FWD
  OFF`; the controls card lists *Floods* and *Forward lights*.
- **On the bridge:** `LightsPanel` (`lights_panel.gd`), two `ReadoutPanel` buttons FLOOD and FWD,
  lit `&"go"` while on, built by `InteriorDressing` on a shoulder's wall (the starboard one first,
  then the nearer the helm; never a fixture's) and bound by `Ship`. `InteriorBuilder.lights_panels()`
  lists them. Its click is `Synth`'s `&"light_switch"` (0.12 s). No shoulder means no panel; the
  helm keys still work.
- **The outside's mood** (`flight_test.gd` `_set_outside_mood()`): `SpacePalette.AMBIENT`
  (`#0b0d12`) as a colour source at `OUTSIDE_AMBIENT_ENERGY` 0.4; glow on at
  `OUTSIDE_GLOW_INTENSITY` 0.6, `OUTSIDE_GLOW_BLOOM` 0.05, blend `OUTSIDE_GLOW_BLEND` (Screen).
  The interior camera keeps `ship_interior.tres`.
- **The starter's exterior** (Godot's figures, 2026-09-29):
  - **blocks:** 84 and 26 fairings: a spine of `fairing_half` at y = 2, x −1..1, z −1..2 (12), a
    `fairing_slope_long_low` ramp forward at z = −2 (`O_FORWARD`) and aft at z = 3 (`O_STERN`),
    three cells each; a `fairing_slope` fin on each engine pod at (±3, 1, 1); a keel of
    `fairing_half` `O_KEEL` at x = 0, y = −1, z −3..2 (6);
  - **totals:** 110 blocks, 104,700 kg, centre of mass (0.004, 1.301, 0.160), inertia
    (2,065,526, 2,865,503, 1,175,422); budgets and imbalance under *Flight balance*, pitch at
    4.91% of 5%; feel 1.49 / 0.71 / 1.85 rad/s², forward 14.3, brake and side 4.8, vertical 9.6 m/s²;
  - **the probe's lines:** `skin    110 plates, 78 chamfers, 18 corners, 140 facets, 9 nozzles`;
    `windows 8 outside for 8 inside` (6 portholes, 2 shoulder windows); `lights  5 floods, 2
    forward`; `tint    88 cells in 5 meshes` (the other 22 cells are all inside, or the alcove);
  - **mounts, in hull space:** floods at (−3.667, −1, −5.667), (3.667, −1, −5.667), (−6, −1, 6),
    (6, −1, 6) and the keel's (0, −2, 0), tilted 25° outward; forward lights at (−4, −0.06, −6)
    and (4, 0, −6), aimed 5° down and 3° out. **5 floods, not the plan's 6:** the bow corner floods
    sit on wedge facets at z = −5.667, so the keel span is 11.67 m and `floor(11.67 / 6)` is one.
    The port forward light hangs 0.06 m lower because the computer's porthole is above it.
- **Measured** (GTX 960, 1280 × 720, both groups on, shadows on): standing 438, seated 181, seated
  with lights 173, seated 60 m off a rock's night side **143–150** (the worst, two runs), chase there
  298–302, 20 m over a rock belly down 273–286 fps.
- **Not adopted:** volumetric shafts (fog with a `FogVolume` per beam, cone turned so it widens
  away from the lamp, fog length about 150 m). Worst view 132–142 fps against 150.

## Thrusters you see and hear (`RcsShow`, `src/flight/rcs_show.gd`)

`Ship` builds one on the hull (`Ship/Exterior/RcsShow`) and rebuilds it with the stats, so any
blueprint gets it for free.

- **Which blocks:** every block with id `rcs` (`RcsShow.BLOCK_ID`). A new small-thruster block
  type needs adding there. Main `thruster`s have no plume yet.
- **Where it puffs:** the nozzle is the mouth of the pod on the face opposite the push,
  `cell_center − f̂ × (1 m + HullProps.RCS_POD_DEPTH)` (0.34 m, so puffs never start inside the pod). It is
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

**What the hull bumps into** (`Ship.exterior.collision_mask`): other hulls (1), worlds' shells
(`BodyProxy.LAYER`, 8, layer 4 `terrain`), rocks (`AsteroidBody.LAYER`, 64) and NPCs
(`Npc.LAYER`, 128): 201. A spacewalker's `Avatar.SUIT_MASK` and loose items outside
(`Item.SPACE_MASK`) include the shells too (the system skeleton spec §7.3). A second ship's hull
takes the same mask.

**The world round a ship** is a star system (`docs/superpowers/specs/2026-09-27-system-skeleton-design.md`):
`flight_test.gd` builds `SystemRecipe.from_seed(seed)`, gives the stream its belt and ring
shapes, starts at `system.entry()`, and adds a `StarSystem` (proxies, belts, dust,
`Whereabouts`) and `BodyContacts`. F7 / Shift+F7 hop the ship to the next or previous body.

A flyable ship also needs a `PilotControls` node under the ship, with the paths shown in
`flight_test.tscn`. It listens to `CameraDirector.piloting_changed`. While you sit, the HUD's
vehicle is that node, not the `FlightComputer`:

```gdscript
_hud.set_active_vehicle(_pilot if piloting else null)   # _pilot: $Ship/PilotControls
```

## Saving (`docs/superpowers/specs/2026-09-26-saving-design.md`)

One autosaved game at `user://save/game.json`, JSON, written only when `SaveGate` says it is calm.
What a ship contributes:

| API | Does |
|---|---|
| `Ship.to_dict(universe)` | layout (`ShipBlueprint.to_dict`), hull place and motion (during a warp, the drop-out point, moving in), `FlightComputer.to_dict`, `QuantumStore.to_dict`, `WarpDrive.to_dict` (the chart), each `Airlock.to_dict`, `ShipLights.to_dict` (`lights`), every item aboard (`Item.to_dict`) |
| `Ship.layout_of(d)` → `ShipGrid` | the grid a save was built from |
| `Ship.set_grid(grid, false)` | builds without stocking the shelves: a loaded game brings its own items |
| `Ship.restore_hull(d, universe)` / `restore_aboard(d)` / `restore_item(d)` | puts it all back; an item whose stow point is gone comes loose |
| `Ship.busy()` | why a save must wait: hull struck (`STRUCK_CALM` 5 s), airlock cycling, machine working, charging suit, bolt in flight |
| `flight_test.gd` `save_enabled`, `save_path` | set before `add_child`; saving is off under `--headless` |

A save stores the ship's **layout**, so a resumed game keeps the ship it saved: saves made before
the ship exterior keep the flat starter, and only a new game gets the reshaped one (no migration,
2026-09-28).

Saved places outside are `UniversePoint`s (`SaveCodec.upoint`). The world's start comes from
`AsteroidRecipe.find_start()` again, so keep it a pure function of the seed.

## Damage (`docs/superpowers/specs/2026-09-29-health-and-damage-design.md`)

| API | Does |
|---|---|
| `BlockInstance.damage` | hp lost; 0 intact. Only `BlockDamage` writes it |
| `BlockDamage.stage_of(inst, def)`, `stage_at(damage, hp)` | `INTACT` < 0.5 hp, `DAMAGED` < 1.0, `WRECKED` < 1.5, `GONE`; `output_of(stage)` 1, 0.5, 0, 0 |
| `BlockDamage.apply(grid, catalog, coord, hp)` / `apply_many(grid, catalog, {coord: hp})` | deals damage; `grid.block_staged(coord, stage)` on a stage change; removes the gone and anything cut off from the core in one `ShipGrid.remove_many` (one rebuild); returns what went |
| `BlockDamage.repair(...)`, `rebuild(grid, catalog, coord, id, orientation)` | mends; puts a block back at `WRECKED_AT` × hp |
| `BlockDamage.KEEP` | `core`, `pilot_seat`, `airlock`: never knocked off |
| `ShipStats.intact_forward`, `intact_torque`, `crippled`, `crippled_reason` | crippled below 25% of intact forward thrust or any intact turning axis, or with no working `quantum_core` |
| `ShipCells.hull_cell(grid, body, shape, p, n)`, `interior_cell(grid, p, n)`, `interior_cell_at(p)` | which block a hit lands on: a hull collider's meta `&"cell"`; the block 0.35 m behind an interior face, else the one in front |
| `Ship.take_damage(cell, hp)`, `take_damage_many`, `crash_damage(knock)` | crashes: nothing below `CRASH_FROM` 2 m/s of knock, then `CRASH_K` 12 × (knock − 2)² on the struck cell and half on its neighbours, dealt after the physics step |
| `Ship.blocks_lost(coords)`, `plate_shed(item)` | a burst and chunks (`DamageShow`); one `scrap_plate` from a block with a face onto space, adopted as a stray |
| `Ship.launch_blueprint`, `launch_block(cell)`, `launch_of(d)` | the layout it launched with, nothing hurt, saved as `"launch"`; what the torch rebuilds |
| `Ship.cell_hit`, `missing_cell_along`, `repair_cell`, `rebuild_cell`, `cell_label`, `hull_whole()` | the repair torch's side, and HULL % in the band |
| `Ship.wake_spots()` | where you wake after blacking out: the bunk room's cells first |
| `ExteriorBuilder.set_stage(coord, stage)`, `stage_colour(stage)`, `instance_colour(coord)`, `skin_spans(coord)` | the cell's skin multiplied by `HullPalette.UNHURT` (white) / `SCORCH` / `CHAR`: the plating's vertex colour is the stage colour, trim and glass their colour times it; glows, lenses and beams stay lit. In place: the cell's vertices are recoloured in the kept arrays and the touched surfaces re-added to the same `ArrayMesh`es once at the end of the frame. On the starter (GTX 960 box) `set_stage` 0.03–0.08 ms, the upload 1.3–1.9 ms, five stages in one frame 1.4 ms; re-dressing the skin would be 53 ms. The alcove is not tinted |
| `InteriorKit.wear`, `InteriorBuilder.wear_at(coord, normal)`, `shows(coord)` | interior dressing leans toward `InteriorPalette.SCORCH` / `CHAR`; a wreck's glow goes dark |

Measured on the starter (crash probe, `test/probes/crash_probe.gd`): 3 m/s nose-on hurts 3
blocks a little; 5 m/s knocks one off and damages 3; 8 m/s knocks 4 off. Not crippled by any.

## The warp (`docs/superpowers/specs/2026-09-28-warp-design.md`)

`WarpDrive` at `Ship/Warp`, built by `Ship._ready`; `flight_test.gd` binds it
(`warp.bind(system, universe, whereabouts, sensors, stream.recipe, warp_busy)`) and connects
`PilotControls.warp_pressed` (J) to `engage()`.

| Number | Value | Where |
|---|---|---|
| Spool | 10 s; aborts past 10° off the line | `WarpDrive.SPOOL`, `ABORT_ANGLE` |
| Lined up | within 5° | `WarpPlan.ALIGN` |
| Shortest warp | 5 km of travel | `WarpPlan.MIN_TRAVEL` |
| Cost | 40 QE + 1 QE per 12.5 km, rounded up | `WarpPlan.WARP_BASE`, `WARP_M_PER_QE` |
| Travel | 18 s + 1 s per 350 km; 4 s ramps; 120 m/s at both ends | `WarpProfile.BASE_TIME`, `PACE`, `RAMP`, `EDGE_SPEED` |
| Warp limit | a body's well (a cluster's 4 km) + 14 km; a planet's also past its ring; moons are targets too | `SystemRecipe.WARP_CLEAR`, `CLUSTER_RADIUS` |
| Arrival clear of rocks | 300 m of mid and big rocks, 30 m of rubble | `WarpPlan.ROCK_CLEAR` |

| API | Does |
|---|---|
| `chart(id)` / `clear_chart()` | a warp target by id; sets and clears the course with it |
| `check() -> WarpPlan` | status (`READY`, `ALIGN`, `INSIDE`, `BLOCKED`, `NO_QE` ...), cost, drop-out; `plan.text()` is the HUD's line |
| `engage()` | J: starts the spool when `READY`, aborts it while spooling |
| `travelling()`, `is_spinning()`, `velocity()`, `streak()`, `time_left()` | for the flight computer, the core, the dust and the HUD |
| `arrival()` | where a save made mid-warp puts the hull |
| signals `travel_started`, `travel_ended`, `aborted(why)`, `stage_changed` | the flight scene suspends and resumes the rocks, salvage and looks on the first two |

While travelling, `FlightComputer` ignores the pilot and reports the warp's velocity; the hull is
frozen kinematic with layer and mask 0; `QuantumPlant` runs the cores at `&"warp"`.

## Flying near a world (`docs/superpowers/specs/2026-09-30-world-scale-design.md` §5.5, §6)

| What | Value | Where |
|---|---|---|
| Speed limit in a well, assist on | 120 m/s + 1 m/s per 40 m of altitude, at most 1,500 | `FlightComputer.speed_limit`, `LIMIT_PER_M`, `LIMIT_CAP` |
| Easing at the well's edge | back to 120 m/s over the top tenth | `FlightComputer.LIMIT_EASE` |
| The limit now | what the assist clamps to and the HUD shows | `FlightComputer.current_limit`, `limit_raised` |
| Where you are | the well and the altitude over its ground | `Whereabouts.well()`, `altitude()` |
| Solid ground round the hull | 64 m + 1 s × speed, at most 160 m | `TerrainCollider` |
| The floor | an anchor > 0.5 m under the ground is lifted out; `WorldSurface.floor_fired` counts it | `WorldSurface.FLOOR_SLACK` |
| Far plane | `BodyProxy.PROXY_AT` + the star's largest radius + 50 km = 700 km | `BodyProxy.VIEW_FAR` |

The hull is a space anchor (`AsteroidStream.SPACE_ANCHOR`), so a world's surface keeps ground
solid under it with no wiring. A ghosted hull (mask 0, at warp) is never lifted.

## Commands

- **Tests:** `who-knows/run_tests.ps1`, or `-gselect=test_name` for one file (PowerShell).
- **After adding a `class_name`:** `<godot> --headless --path who-knows --import`.
- **Probe:** `<godot> --path who-knows --resolution 1280x720 --script <abs>/ship_probe.gd --
  <abs out dir>`. Use absolute paths, and don't pass `--headless`: headless never renders or
  compiles shaders. In a worktree, give the worktree's copy of the script.
- **The full suite** takes about 8 minutes: run it in the background, logged to a file.
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
- `docs/superpowers/specs/2026-09-28-ship-exterior-design.md`: the skin, fairings, windows that
  match the interior, the lights, and (last section) what the build did differently.
- `docs/superpowers/specs/2026-09-24-asteroids-design.md` §4: the floating origin.
- `docs/superpowers/specs/2026-09-27-system-skeleton-design.md`: the star system a ship flies
  in, the worlds it bumps off, and the debug hop.
- `docs/superpowers/specs/2026-09-25-bridge-computer-design.md`: the holo table, the sensors'
  course, and (§18) what was built.
- `docs/superpowers/specs/2026-09-25-flight-controls-design.md`: how the flight computer spends
  the budgets, the RCS show, and (§9.4) what the starter's layout does to the feel.
- `docs/superpowers/specs/2026-09-26-saving-design.md`: what a ship saves, and when.
