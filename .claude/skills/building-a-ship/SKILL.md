---
name: building-a-ship
description: Use when designing, adding or changing a ship blueprint in the who-knows Godot project - a new ship, a second ship in a scene, a shipyard or generator emitting a grid, or moving the helm, canopy, airlock, engines, thrusters, reactors or rooms of an existing ship. Also when a ship won't launch, won't turn or brake, pitches under burn, slides long after a turn, browns out, has thrusters that never puff, or strands the player (stuck by the chair, an airlock that never cycles).
---

# Building a ship

## Overview

A ship is **one `ShipGrid` of 2 m blocks**. Everything else is generated from it and must never
be hand-placed: the hull, colliders, interior walls, rooms and doorways, the cockpit pod, the
airlock rooms and hatches, the stow points, the flight stats, and the hull's skin, windows and
lights. Building a ship means choosing
blocks and orientations, then **proving** the generated result launches, flies, can be walked
and looks right. Green tests prove structure, not looks or feel.

The worked example is the starter shuttle: `who-knows/data/ships/starter.json`, with
`starter.md` beside it explaining every block that isn't obvious. Read both before you design.

**Read first:** `CLAUDE.md` (the style guide is binding; the floating origin; no `#` comments in
`.tscn`), `docs/design/visual-style.md` §3 and §6, and `reference.md` beside this file (blocks,
orientation codes, numbers, APIs).

## Checklist

Do these in order. Each one names the check that proves it.

0. **A ship is a file** (`docs/superpowers/specs/2026-10-02-ship-library-design.md`):
   `who-knows/data/ships/<id>.json` plus `<id>.md` beside it, the id the file's name, one row
   `[x, y, z, block, orientation]` per line (`ShipLibrary.write` writes the form). Run
   `ship_check.gd` on it until it exits 0: it runs every rule (`ShipRules`) in seconds.
   `test_ship_catalog.gd` then holds it to the rules and to being usable, with no test of its
   own. F6 in the game spawns it.
1. **Lay out the decks.** −Z is the bow, +X starboard, +Y up. The proven pattern is y=0 a
   walkable cabin and y=+1 a solid equipment deck (core, reactors, grav plating). **Shape the
   outside with fairings, outside the cabin row** (`fairing_*`, 0.3 t each: a spine above, a keel
   below, fins on the pods, ramps at the ends); the skin chamfers every other convex edge for
   free. The cabin row keeps its full blocks, so nothing inside moves.
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
     its buttons (and with nothing solid between that eye and them:
     `test_looking_at_a_button_from_its_operator_s_spot_finds_the_button`), and face it so the operator looks out of a window (the owner's wish, 2026-09-27:
     on the starter, the port front corner, facing aft). A console it displaces moves aft. The
     probe prints each table and where you stand to use it. Its station's eye (1.85 m up, 0.9 m
     behind the holo's centre, up to 2.34 m while orbiting) must be clear of the ceiling and
     walls; the probe prints it (`eye ... m up, orbiting to ... m`, flagged
     `EYE IN THE CEILING`).
3. **Damage** (`docs/superpowers/specs/2026-10-03-ship-damage-sections-design.md`): a ship
   takes damage as **six hull sections and four components**, not block by block (`ShipDamage`):
   - **the sections** are the launch layout's thirds (bow, midship, stern) split port and
     starboard; the centre line is in both. Every block that is not a component is in one: its
     `hp` (in its `.tres`) adds to its section's. Hull damage changes only looks and pieces,
     never what the ship can do;
   - **the components** are the `thruster`s (as one, the engines), the `quantum_core`, the
     `computer` and the cockpit (`pilot_seat` and every `canopy`). Damaged under half: half
     thrust, half power, a glitching table and a 20 s warp spool, a cracked canopy and a sluggish
     assist; wrecked: none, crippled, dark and no warp, assist off (a centred stick still damps a spin; mending it turns the assist back on). They are mended where they
     sit, so put the core and the table where the torch reaches them from walkable deck;
   - **give each section pieces to lose:** plating and fairings (`ShipDamage.STRUCTURE`)
     outside the cabin's shell (`Ship.inner_cells`), whose loss cuts nothing off. Below half a
     section sheds them, outermost first, and welding brings them back. A section with none never
     shows a hole; the probe's `damage` line prints each section's hp and pieces and flags `NO
     PIECES`;
   - **the cabin keeps its shape:** nothing in the shell is ever a piece; inside, the whole
     cabin scorches below 50% HULL and chars, sparks and flickers below 20%;
   - **the hull is mended from outside only** (`RepairTorch.SECTION_RATE`): a section a
     spacewalker cannot reach the outside of cannot be mended;
   - the ship must not be **crippled as built**: the probe's `damage` line says so;
   - **damage shows on the skin:** a hurt cell's plating, trim and glass are multiplied by its
     stage colour (`ExteriorBuilder.set_stage`, in place). A new hull piece must be marked to its
     cell in `HullDressing` (`reference.md`), or it stays clean when its section is scorched.
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
     thrust, not by weakening the RCS. Fairings above the thrust line count: the reshaped
     starter's spine and fins put pitch at **4.91% of the 5% limit**, so leave headroom;
   - the feel numbers (`torque_budget / inertia`, and each thrust budget divided by mass) are
     what you meant. The probe prints them.

   Pin all of this in a test (`reference.md` has one). The starter's numbers live only in its
   comments, so nothing would catch it drifting.
7. **Wire the scene:**
   - **every ship goes through `Fleet`** (`docs/superpowers/specs/2026-10-02-many-ships-design.md`):
     the starter is `/Ship`, an instance of `scenes/ship.tscn`; any other is
     `fleet.spawn(grid, place)`, which gives it an `interior_slot` and a name never reused
     (`Ship2`, `Ship3`...). `ship.tscn` holds everything one ship needs to be flown (seat,
     `FlightComputer`, `PilotControls`, `MotionCoupling`, canopy view), and `Ship` places its own
     `PilotSeat` from `InteriorDressing.fixture_frame` after every rebuild. The flight scene's
     `_wire_ship` hands each ship the game's one `CameraDirector` (`seat.director`,
     `pilot.bind_director`), `pilot.lights` (or L and K do nothing), its warp, its sensors'
     sources and its crew's ledger. `Ship` makes the `RcsShow` puffs, `ShipLights` and the
     bridge's lights panel itself;
   - **every ship is usable** (the owner's rule, 2026-10-02): you can board it (F8 to the nearest
     other helm, or any ship's airlock from a spacewalk), fly it, and it saves. Only where you are
     (`home`: the ship you stand in, or a base you are in) draws its hull on `OWN_HULL_LAYER`
     (`GridHome.set_own`). The probe's
     `fleet` line and `test/probes/fleet_play.gd` prove it;
   - the avatar's starting spot from `InteriorBuilder.floor_y(cell)` (the flight scene's
     `_deck_spot`);
   - **a base is a grid too** (`docs/superpowers/specs/2026-09-26-habitat-modules-design.md`):
     `Ship` and `Base` both extend `GridHome`, and a base's hub is built by the same
     `ExteriorBuilder`, `InteriorBuilder` and airlock code from its `BaseSite`'s grid. Anything
     that changes how a grid becomes an interior or an exterior, or how airlocks bind, must keep
     `Base` working: run `test_base.gd`, `test_base_boarding.gd` and `test/probes/fleet_play.gd`
     (and `test/probes/base_probe.gd` for anything a base shows);
   - **interior slots come from `InteriorSlots`**, one pool shared by `Fleet` and `Bases`
     (`fleet.slots`, `MAX` 16): never hand one out by hand, and give it back when a home is freed;
   - anything outside the hull goes in `Universe.EXTERIOR_SPACE` (CLAUDE.md);
   - **a ship's state round-trips through the save** (`docs/superpowers/specs/
     2026-09-26-saving-design.md`). A block with state of its own (a fixture, a store, a door that
     can be left open) needs a `to_dict`/`from_dict` gathered by `Ship.to_dict`, a busy source in
     `Ship.busy()` if it has actions that run over time, and a line in
     `test_save_scene.gd`'s round-trip. The probe prints `save ... round-trips`. The lights are
     a `lights` part (`{"floods", "forward"}`); a save without one loads with both off;
   - **the warp** (`Ship/Warp`, a `WarpDrive`; `docs/superpowers/specs/2026-09-28-warp-design.md`):
     every ship gets one, and the flight scene binds it (`_wire_warp`). While it travels it
     freezes the hull kinematic and clears its layer and mask, restoring them at drop-out. Anything
     that sets the hull's `collision_layer`, `collision_mask` or `freeze` must check
     `warp.travelling()` first. How far a ship can warp is set by its store; the probe prints
     `warp    reach ...`;
   - **near a world** (`docs/superpowers/specs/2026-09-30-world-scale-design.md` §5.5, §6):
     - **the assist's limit climbs with altitude** (`FlightComputer.speed_limit`): anything else
       that caps the hull's speed must use `current_limit`, never `CRUISE_LIMIT_MPS`, and a
       ship's `Whereabouts` must be wired (`flight_computer.whereabouts`) or it is held to
       120 m/s everywhere. `locked_speed` is re-clamped to the limit every tick, so a lock set high
       in a well drops to cruise on leaving it;
     - **the hull is a space anchor** (`AsteroidStream.SPACE_ANCHOR`, joined in `Ship._ready`),
       so a world's `WorldSurface` keeps solid ground under it with no wiring. Anything else that
       flies near ground (a wingman, a pod) joins that group with its `ANCHOR_RADIUS` meta, or the
       ground under it is not built and the floor does not lift it;
     - **a ghosted hull** (mask 0, at warp) is never lifted by the floor: it passes through
       everything on purpose, so do not give it a mask to "protect" it. The probe prints
       `worlds  hull is a space anchor yes; speed limit knows where it is yes`;
8. **Run the full suite** (`who-knows/run_tests.ps1`). It takes **about 8 minutes**, longer than a
   single command's timeout: run it in the background, logged to a file, and wait for the end. Add
   ship-specific tests: launches, stats, rooms, and the pod and airlock present.
9. **Probe the real scene:** run `ship_probe.gd` (in this folder) **without** `--headless`. It
   prints:
   - the validator, the stats, the `balance` line (each axis's imbalance as a share of authority,
     flagged `OVER 5%`), and the feel numbers;
   - any `rcs` whose exhaust is `BLOCKED`;
   - the `rules` line (`0 broken`, or each `<-- CODE`) and the notes;
   - rooms, pods and airlocks;
   - **the hull:** `skin` (plates, chamfers, corners, facets, nozzles), `windows N outside for N
     inside` (with `UNMATCHED` naming any inside window that has no place outside), and `lights  5
     floods, 2 forward` on the starter (the four belly corners and one on the keel, and a forward
     pair); `panel` says whether the bridge has its lights panel; `tint` counts the cells the
     damage tint reaches and flags `VERTICES WITHOUT A CELL`;
   - `toilet`, on a ship with a bathroom: whether the Interactor finds the shut lid and, in a dev
     build, the QE refill button under it once it is lifted, and whether the button fills the
     store (`NOT FOUND`, `NOT FULL`). It writes `probe_toilet_shut.png` and
     `probe_toilet_open.png`;
   - the droid's dock and its jobs, flagging any `UNREACHABLE`;
   - fps.

   It also sits, stands and walks, and flags `STUCK`. Look for `SHADER ERROR` too: headless never
   compiles shaders.
10. **Render and show the owner:** eye-height (1.6 m) views of the bridge, the seated view, the
   corridor, each room and the exterior, plus an outside view with each RCS axis firing (every
   block's puffs should show). Cycle the airlock both ways, look out of the windows, and hold
   ≥120 fps at 1280×720. **The hull views** (the probe writes them): two quarters (bow port,
   stern starboard), the profile, above and below, fill-lit to judge the shape and **dark with the floods, the forward
   lights and both on** to judge the lights; and the ship **by a big rock's night side**, nose on
   with the seat's view and belly down over it. The worst view is seated by the rock with both
   groups on; the starter held 143–150 fps there on 2026-09-29, and 130 on 2026-10-02 (`main`
   and `many-ships` alike, the same box), with or without a second ship 300 m off. **Damage** (anything touching damage, its
   looks or the cabin's shell): render `test/probes/damage_review.gd` before merging. It shows
   the hull intact and with the port sections at 70%, 35% and 0% (fill-lit: scorched in
   patches, then pieces off), the cabin at eye height at 60%, 35% and 15% HULL, the bridge
   computer intact, glitching and dark, and the seated view with the cockpit damaged and wrecked.
   The cabin must keep its shape: same rooms, pod, helm and doors.
11. **Fly it:** a steady turn on the arrow keys, a clicked heading 120° away, and a speed-locked
    turn at cruise. Compare them with the feel numbers you meant.

## What the blueprint decides about flying

Flight assist is the same for every ship (`docs/superpowers/specs/
2026-09-25-flight-controls-design.md` §5): it asks for 60°/s on each turning axis, and it spends
the **whole** side and vertical budget cancelling drift. The only thing that differs between ships
is the blueprint's budgets, so the grid decides the feel:

| Feel | Comes from | Starter shuttle |
|---|---|---|
| How fast a turn starts and stops | `torque_budget / inertia`, per axis | 1.49 / 0.71 / 1.85 rad/s² (pitch / yaw / roll) |
| A clicked heading swinging on | the weaker of pitch and yaw above | 120° in 3.1 s on the flat starter; not re-measured on the reshaped one, a little slower |
| Travel swinging onto the nose after a turn | `thrust_budget[&"lateral"]` (and `vertical`) / mass | side 4.8 m/s², vertical 9.6: 100 m/s sideways takes about 21 s |
| Braking; a speed lock slowing down | `reverse` / mass | 4.8 m/s² |
| Accelerating; a speed lock catching up | `forward` / mass | 14.3 m/s² |
| Thrusters the player sees | each `rcs` block's exhaust face open and in view | 6 of 8 blocked (only the pitch-down pair shows); none in the pilot's view |
| Warp reach on a full store | `(quantum_capacity − WarpPlan.WARP_BASE) × WarpPlan.WARP_M_PER_QE / 1000` km | 14,500 km on 1,200 QE (7,000 km on its starting 600) |

The figures are the **reshaped starter's** (110 blocks, 104.7 t; the spine, fins and keel added
7.8 t). Before the reshape it was 1.60 / 0.74 / 2.05 rad/s², 15.5 forward, 5.2 brake and side and
10.3 vertical; this table had said 1.74 / 0.79 / 2.05 and 5.4 since well before that, and was
already stale. Weight added outside the thrust line slows every axis, so re-measure with the
probe after any fairing.

A ship that slides for 20 s after a hard turn at speed is not a controls bug. It needs more side
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
| The plating's vertex colour after main's livery took `COLOR` | The skin wrote `HullPalette.PLATE` into its `HULL` batch, which the livery ignored until the damage merge made it multiply by `COLOR.rgb`: every plate would have darkened by the plate colour | The plating's vertex colour is the cell's stage colour, `UNHURT` (white) when whole; `test_an_unhurt_cell_s_plating_is_white_so_the_livery_is_as_painted` |
| Re-dressing the skin for one stage | Rebuilding the skin from the layout costs 53 ms on the starter, and would replace the lens meshes and window glow `ShipLights` holds | `set_stage` recolours the cell's vertex runs in arrays kept from the dressing and re-adds the touched surfaces once at the end of the frame (~1.5 ms). Never read a mesh's arrays back to do it: that stalls on the GPU (5–25 ms) |
| Recolouring one interior cell | The dressing is a few merged meshes, so there is no one cell's mesh to tint | A stage seen from inside rebuilds the interior once, deferred (`Ship._queue_rebuild`), leaving the hull standing: ~125 ms on the dev Xeon |
| Letting damage knock off cabin blocks | After a hard crash onto a planet the cabin had reshaped round the owner: a little room with the chair, and no way to sit back down to fly | Nothing in the cabin's shell (`Ship.inner_cells`) is ever one of a section's pieces; a save missing shell blocks gets them back from the model on load |
| Merging damage work on green tests | The cabin's shell went to `main` with no renders; the owner had to ask for them, and the first ones showed the cabin's sparks as chunky white tiles hanging in the air | Render `damage_review.gd` and show the owner before merging (step 10). Sparks are 1.5 × 5 cm and live 0.3 s |
| Damage block by block | Every one of the starter's 110 blocks took damage and was welded on its own, inside and out; the owner found repairing "a little too tedious" (2026-10-03) | Six hull sections mended from outside and four components mended where they sit (`ShipDamage`). A new system breaks only if it is made a component, with the owner's say |
| A wrecked cockpit that only took the assist away | A rock wrecked the cockpit and knocked the ship spinning; with the assist off nothing damped it, and mending the cockpit left the assist off, so it spun until the owner reset the game (2026-10-03) | Refused, a centred axis still damps (`FlightComputer.WRECKED_DAMPING`); mended, the pilot's own choice comes back (`assist_wanted`). Anything that takes a flight aid away must hand it back and never leave the hull unrecoverable: `test_a_ship_knocked_spinning_with_a_wrecked_cockpit_settles` |
| Holding a bridge computer across a stage change | The damage review kept a `ShipComputer` while the computer was damaged; the stage rebuilt the cabin, freed the table, and the script stopped on the freed object without quitting | Fetch tables (and anything else in the dressing) again from `interior_builder` after any damage seen from inside |
| Clamping the QE store to its damaged capacity | A crash wrecked the cells and the owner's stored energy was gone for good, leaving the ship in low power with no way to tell why | A damaged cell lowers `capacity` only; the store keeps up to `QuantumStore.most` (pass `intact_quantum_capacity`), and the status page says *CELLS DAMAGED* |
| A repeating world-space emitter in `Universe.HOLDS_SHIFT` | Every damaged block re-fired its sparks every second or two, so with a few damaged the floating origin would almost never have found a gap to shift in | Anything that repeats stays in its parent's frame (`local_coords`) and out of the group; only short one-shots outside hold the shift |
| Letting go of a warp at 120 m/s with the assist on | The assist cancels velocity nobody asked for, so the ship braked to rest at the warp limit instead of coasting in | `WarpDrive` sets the speed lock to 120 m/s at drop-out; anything else that hands the hull a velocity with the assist on must do the same |
| Letting the rest of the ship behave normally at warp | Found in the final review: you could cycle the airlock and step out mid-warp (stranded kilometres behind), the RCS kept its last command and puffed the whole way, and motion coupling read the frozen hull's placing as a 12 m/s² shove | Anything that acts on the hull's motion or lets someone outside asks `warp.is_spinning()` / `travelling()` first: `Airlock.warping()`, `FlightComputer`'s early return, `MotionCoupling._warp()` |
| Writing a warp cost as 0.08 QE per km | `ceili(0.08 * 3000)` is 241, not 240: 0.08 is not exact in floating point | Price per whole units the other way round: `WarpPlan.WARP_M_PER_QE` (metres per QE) |
| A camera outside with its own far plane | The far plane must hold `PROXY_AT` plus the biggest body's radius: a proxy just past `PROXY_AT` is drawn at nearly its true size, so at 400 km the star's disc was clipped | Use `BodyProxy.VIEW_FAR` (`PROXY_AT` + `SystemRecipe.STAR_RADIUS.y` + 50 km, 700 km) for any new outside camera |
| An upright collider round a tilted console | The holo table's console lip was a box round the whole console, so it enclosed all five buttons: the Interactor's ray hit the table, every prompt was empty, and the computer could not be used at all in play. Its tests pressed the buttons in code and only measured distance | Give a tilted part its collider in its own frame, no farther out than its face, so its buttons stand proud of it. Test an interactable by casting the Interactor's ray at it from where you stand, not by distance |
| A fixed mark capacity checked against one seed | The holo's 512-a-group cap held the shipped system's faint ticks with 6 to spare at the start, but 79% of seeds overflowed it at SYSTEM and the last worlds' limit rings vanished without a word | `HoloVolume` groups double as they fill (to `MAX_CAPACITY`), and a drop is counted and warned of. Test a budget against the busiest seed and more than one position, not the shipped seed where you start |
| A test script that types a local from the untyped `_root.system` and loops its `warp_targets()` | Godot 4.5.1 segfaulted at exit (ObjectDB leak, GUT's own scripts included) though every test passed | Hold the system in a typed member set in `before_each`, as `test_warp_drive.gd` does; watch the run's exit code, not only its pass count |
| An off-centre retro counted as steering | It would light up for yaw, but `ShipStats` never counts pure fore-and-aft thrust as authority | Steer with blocks that push across the hull; retros only brake |
| A fairing in the cabin row | The interior sees a solid cell and builds a whole wall against it, but a slope or a half leaves the outside open, and a porthole outside lands on a slope or above a 1 m block | Fairings go above and below the cabin and at its ends. The cabin row keeps full blocks. Check the probe's `windows` line |
| A window inside with none outside | `HullLayout.unmatched` is not empty (the probe prints `UNMATCHED`). The walk out from a porthole wall stops at one solid cell, so **two solid cells** between the room and space leave the window nowhere to go. A covered face or a slope turned away fails too | One solid cell (or none) between a porthole's room and space. Every interior window must have one outside: `test_hull_windows.gd` |
| An RCS exhaust closed by a fairing | The puffs are born inside the fairing and never show, exactly as with any block. Fairings are solid | Keep each `rcs` block's exhaust face open. The starter's `BLOCKED` count stays at 6 of 8; it must not rise |
| "Balance by weakening RCS", again, for the spine | The reshape put 6.0 t of spine and fins above the thrust line and 1.8 t of keel below, lifting the centre of mass 9 cm: pitch imbalance went from 0.36% to **4.91% of the 5% limit** | Trim by moving fairings, never the RCS. The spine's z = 2 row (three cells) or a wider keel are the trims held in reserve. Watch the `balance` line |
| Window glass flush with the cell face | It was buried behind plates that stand `PLATE_PROUD` (0.05 m) proud: portholes showed as bare rings on white plate | Glass and bands go in front of the plate (`HullProps.GLASS_Z`). Render a window close up before calling it done |
| `-1 << 30` or a multi-line lambda in GDScript 4.5 | Both are parse errors, and a parse error in `hull_layout.gd` made `plan` "nonexistent" with a message far from the cause | Write `-(1 << 30)`, and keep a `filter(func(f): ...)` lambda on one line |
| Two `InteriorKit.commit()`s under one parent | The second commit's meshes are renamed by Godot (`DressingHull2`) and a lookup by batch name fails | Give each kit its own node, as `HullDressing` does (`Skin/Hull`, `Windows`, `Lens_flood`...) |
| Judging the hull's shape from an unlit render | The sun lights some faces and the ambient is nearly black, so an unlit hull is a black silhouette and a hole looks like shadow | The probe's `_hull_shots` has a fill light for shape checks and none for judging the ship's lights; use both |
| Additive beams at alpha 0.06 | Each cone rendered as a flat, hard-edged tan solid that hid the ship, and overlapping cones stacked | `HullMaterials.BEAM_ALPHA` 0.012, a mid fade stop, back faces culled. Judge them against a dark sky, not a bare hull |
| Bloom left at the engine's default blend | The outside's glow drew no halo at all round lenses and strips, at any intensity | `glow_blend_mode` Screen (`OUTSIDE_GLOW_BLEND` in `flight_test.gd`) |
| A new sound not in `test_synth`'s list | `test_synth` pins `Synth.NAMES.size()` against its `LENGTHS` table and each sound's length, so the full suite fails on one line | Add the sound and its length to `LENGTHS` in the same change |
| One collider over a whole prop with something to use on it | The washstand was one 1.5 × 0.9 m box over the toilet and the sink, so the Interactor's ray stopped on it 0.4 m above the toilet's lid (found adding the dev QE refill) | Keep a prop's colliders under anything on it that is used or picked up (the bunk's mattress, the shelves' boards, the toilet's bowl). Prove it with a ray from eye height in the real scene, as `test_toilet_lid.gd` does: it fails with the old box |
| A reach test with the eye where the brief said | The lights panel is on the shoulder's front wall, about 3.1 m from the cell behind, past the Interactor's 2.5 m; the test failed | Stand the test's eye in the shoulder's own cell (1.3 m from the panel) and remember the desk is 0.4 m deep |
| Running a test or the probe from the main checkout | `run_tests.ps1` resolves from the current directory, so a shell that started in another tree ran that tree's code and reported a pass | Check the directory before every command when working in a worktree |
| A new `class_name` without `--import` and its `.uid` | Tests fail to find the class, and the generated `.uid` is not committed | Run `--import`, then commit the `.uid` files (the repo tracks them) |
| Every hull on `OWN_HULL_LAYER` | Found while designing many ships: the canopy and every window leave that layer out, so a second ship would have been invisible from your seat | `GridHome.set_own`: only `home` draws there (the ship you stand in, or the base you are in); `board()` and `board_base()` move it and let every other ship and base go |
| Each `PilotControls` listening to the one director | Sitting in any seat would have handed every ship the stick | `bind_director`; controls take the stick only when `director.seat_ship()` is their ship |
| An airlock that let in only its own suit (`avatar.hull == hull`) | No way to board another ship from a spacewalk | Any suit; `Ship.airlock_crossed` boards that ship |
| A canopy camera left where nobody looks through it | A second ship's canopy camera sat at the world's origin, then (first fix) at the hull's origin, where the velocity marker aims at rest: `unproject_position` hit depth 0 the frame you boarded | Unused, `CanopyPortal` rests the camera at the helm's eye on the hull |
| `board()` letting go only of the last ship aboard | A loaded game sets `aboard` before its first board, so the starter stayed own beside the ship you were in | `board()` makes every other ship not own |
| A `ViewportTexture` path for a scene instanced many times | Fragile inside an instanced scene | `Ship._make_canopy_material()` from `Canopy.get_texture()`, one per ship |
| Naming a ship anew on load | The droid's ledger record is named for its ship, so its health would be lost or given to another | Names never change and are never reused; `Fleet.next_number` is saved |
| Standing up in the frame you let go of a key | `clear_pilot_input` latches the burn on purpose, so a scripted run kept reversing at 4.8 m/s² after standing | In a probe or test, let a process frame or two pass between releasing a key and standing |
| A GUT file that will not parse | GUT skips it, says nothing failed and exits 0 | Check the run's `Tests` count is there, not only the exit code |
| Every ship writing its uniform into one shared material | Found in many ships' final review: each ship pushed its hull's `hull_inverse` into the one livery, so with two awake one ship's stripe was measured in the other's frame | Anything per ship in a shared material needs a copy per ship: `Ship.livery`, swapped on by `_apply_livery`. Render two ships at different attitudes |
| A SubViewport that only turns off when its owner processes | A ship loaded asleep (processing disabled from the start) rendered its canopy view every frame, unseen | Start it `UPDATE_DISABLED` in the scene; whatever puts a ship to sleep turns it off too (`Fleet._hold`) |
| Drawing only what a page can step to | The computer mode's map drew `targets()` (full size only), so a rock left the holo at once instead of shrinking across its band, and the bands' code was dead | Keep what is drawn (`MapPage.shown()`, at the scale drawn) apart from what ◀ ▶, the list and the mouse can pick (`targets()`, full size at the scale chosen). The course is always drawn, never shrunk |
| Leaving a station only on Esc, F or a rebuild | Found in review: blacked out, blown into the suit, or carried off to another ship, you stayed in the computer's view with control off; F8 boarded from it | `CameraDirector` drops out whenever the avatar can no longer be at the station (`_station_usable`), restoring only what the station took; F8 says *AT THE COMPUTER*. Anything new that holds the camera does the same |
| Trusting a button's release to reach you | A release eaten by the overlay or the window left the computer mode's drag running: the next mouse motion orbited with no button down | Motion with the left button up ends a drag (`ComputerModeInput`). Every overlay button is `FOCUS_NONE`: a focused `Button` takes Tab and Enter as `ui_focus_next` and `ui_accept` before `_unhandled_input` sees them |
| Timing the holo's `update()` with the computer still processing | The computer's own `_process` updates the holo too, untimed, and took the placings: the sweep read 1.7 ms worst when a placing at 4,000 km cost 10-12 ms (as first built) | `computer.set_process(false)` round a timed loop, as `computer_mode_render.gd` does |
| Overlay text straight on the room | The computer mode's tabs and *ESC LEAVE* were cream on the bridge's cream ceiling: unreadable | Anything on screen outside a panel gets a `SCREEN_BACK` outline (`ComputerOverlay.OUTLINE`). Render it over the brightest wall it can sit on |
| Working a tick out like a contact | Every one of the map's ~600 far ticks made a UniversePoint, worked the star's offset out again (three logs), undid the frame's basis and got a Dictionary back from `HoloVolume.place`: 12 ms a still SYSTEM placing, twice a second, a rhythmic stutter | Work out once a placing what every mark reads (`MapPage.Placing`); a ring's tick is its centre plus a unit circle times its radius, in the map's frame; test inside with `HoloVolume.inside` and hand ticks over with `add_ticks`. Guard a cost refactor with a recording of every mark (`test_map_page.gd`'s placing guard) before touching it |
| A rule that failed the starter | `NO_STAND` as first written wanted the cell behind the helm free, but the starter's quantum core stands there; the seat stands you up beside it | Check a new rule on the starter first; `ShipRules.stand_cell` is where you stand up to |
| Testing a rule with a broken copy that can't break it | Two solid cells behind a porthole remove the porthole rather than leave it unmatched | Check each broken copy breaks its rule on the real starter before writing the test |
| `-gtest=` to run one test file | With this `.gutconfig.json` it ran the whole suite; and GUT exits 0 on a file that fails to parse | `-gselect=<file>.gd`, and read the summary: `Tests` must be above 0. After adding a `class_name`, run `godot --headless --import` first or nothing can see it |
| A 2 × 2 hub (habitat modules) | `AirlockSite` wants exactly one horizontal face onto open space, and an airlock in the corner of a 2 × 2 has two: it would never cycle | The hub is 3 × 2 with the airlock mid-front (`ModuleCatalog`); any new module with an airlock puts it where only one face is open |
| Modules planted face to face | Two grids that touch become one interior: rooms run together with no corridor or door between them | `Planting._crowds` and `BaseValidator`'s `APART` keep a cell between modules until corridors (Phase D) join them |
| A shape query for "is this box in the rock" | The rock's `ConcavePolygonShape3D` is one-sided, so a box whose centre is under the surface overlaps nothing | `RockSurface._buried` casts rays in from outside to the box's centre and corners; never turn on backface collision for every rock to fix one query |
| Freeing an item from inside its own `use()` | `Item.consume` inside `Item.use` hit "Attempted to free a locked object": the package lived on, orphaned, in your hand; and a freed object compares equal to `null`, so `item != null and not is_instance_valid(item)` never fired | Consume deferred (`Item.consume.call_deferred`); `Grasp` lets go on the item's `consumed` signal and guards on its mode, not on `item != null` |
| `board()` returning early when `ship == aboard` | In a base your ship stays `aboard`, so walking back into it changed nothing: you stood in your ship with the base still `home` and your hull hidden | `board()` returns early only when the ship is both `aboard` and `home`; `board_base` is the one place a base becomes `home` |
| Loading into a base with the focus on your ship | The rocks loaded round the ship, 25 km off, so the base woke with no ground in detail under it | `_restore_places` points the universe's focus at the woken base before the stream starts |
| A `push_warning` in a check that runs every second | GUT counts it as an unexpected error, and a base waiting on a full slot pool would have logged one a second | Stay quiet and retry at the next check (`Bases._wake`) |
| A ghost refreshed only when re-fitted | It stayed up after you aimed away, then flickered | `PackageUse` stamps the tick on every `aim_text` and hides the ghost `STALE_AFTER` 3 ticks later, or when the item leaves the hand |
| The box skin on a base | The first hub rendered as a dark crate on spindly legs | A base hides `ExteriorBuilder.skin()` and wears `BaseExterior`'s drum shell over the same colliders; the shell leaves the hatch face open for the alcove |
| A probe glide with the suit assist on | The assist brakes you to your home's velocity, so the suit stopped short of the hub's hatch | Turn `avatar.suit_assist` off for a scripted glide, as `fleet_play.gd` and `base_probe.gd` do |
| An engine position kept across a 25 km jump | After `Universe.check()` the origin had moved, so "back where it was" in engine space was 25 km off | Keep places that cross a jump as `UniversePoint`s (`to_universe` before, `to_engine` after), and do what `hop()` does after one: `check()`, `place_all()`, `whereabouts.look()`, `stream.update(0, true)` |
| The hub's link panel facing the front wall | It stood mid-cell with its back to the room, 0.6 m from the machine's face, and its offset did not turn with the hub; its tests pressed it in code and never looked | `LinkPanel.FROM_CENTRE` against the front wall, facing in, the offset turned with the hub (`test_the_panel_faces_into_the_hub_however_it_is_turned`); render a panel at eye height and press it through the Interactor |
| A ship arriving straight at you | The first arrival flew in along its nose, toward the viewer: from the seat its wake hid behind it, and a 0.6 m wake was under a pixel from 400 m | A spawn comes in across your view (`SpawnSpot.arrival_line`, 60°) and turns to face you; judge effects outside at the distances they happen |
| Measuring a hull by every mesh under it | The light beams are hidden meshes reaching 140 m ahead: the arrival's flash swallowed the view | Count only what shows (`WarpArrival.bounds_of`), or use `ExteriorBuilder.bounds()` where you have the ship |
| A hull moved by something new, with its flight computer still steering | The arriving ship's RCS puffed all the way in, a dotted trail along its line | Anything that flies a hull for it rests the flight computer, as the warp and `WarpArrival` do (`FlightComputer._physics_process`) |

## Not built yet (plan for it; don't assume it works)

- **Per-cell rebuilds.** Any removal rebuilds the whole ship (~220 ms headless on the 2.8 GHz
  dev Xeon for the starter since the generated skin), and a stage seen from inside rebuilds the
  interior (~125 ms; the hull recolours in place). Fine for now; a hitch in a big fight.
- **Debris and breaches.** A piece cut off vanishes in a burst; a hole has no air to lose.
- **Damage beyond the four components.** RCS, cells, rooms and the airlock never break; a
  section's health changes only looks and pieces. No per-section effect on flight, no repairing
  a section from inside, no droid repairing the ship.
- **Gravity and landing on a world.** Worlds are solid and you can skim and bump off them, but
  there is no gravity, landing gear or step-out yet (Planetfall's). Do not give a ship legs or
  skids that assume a pull.

- **Multi-storey interiors.** A `ladder` passes the validator, but every walkable cell still gets
  a solid floor and ceiling, so you can't climb. **Multi-level ships** can be written and checked
  now and are usable once ladders climb: `CUT_OFF` names every storey the helm can't reach
  ("ladders don't climb yet"). The climbing project gives `DeckPaths` its vertical links, and the
  same rule then passes.
- **Bases beyond Phase C** (habitat modules spec §19): no corridors between modules yet (Phase D,
  waiting on the hose), so a drill or store beside the hub can't be walked into; the link moves
  50 QE a press, with no hold; nothing makes a base visible from afar (no lights, beacon or sensor
  contact: the owner's call); a hub's machine makes nothing (`can_make` false).
- **The bubble canopy** pod variant.
- **Light blocks** placed by hand. The generator places every light; a shipyard that wants its own
  comes with its own spec.
- **Volumetric light shafts.** Measured, not adopted: fog with a `FogVolume` in each beam cost
  6-10% in the worst view (132-142 fps against 150) and merged the floods into one soft column.
  A ready follow-up if the owner wants it: `ShipLights.bind` makes a `FogVolume` per beam (cone
  turned so it widens away from the lamp), the cones go, fog goes on in `_set_outside_mood` with
  a 150 m length. See the ship exterior spec §6.4 and the Task 13 report.
- **Asteroid tunnels.** None exist; the forward lights (220 m, shadowed) are sized for them.
- **Migrating a saved starter.** A resumed game keeps its saved layout, the flat starter; only a
  new game gets the reshaped one.
- **Dust kicked up by the floods** near a surface, and a rendered low-power frame of the beams
  (their dimming is tested by property only).
- **Docking** (two hulls held airlock to airlock), **ships flown by NPCs**, and a ship that moves
  while asleep (one coasting when it falls asleep is found where it fell asleep).
- **A way to spawn a chosen ship in play** (a debug key, a library of blueprints in
  `data/ships/`): project 2 of the ship-designer plan. Until then a second ship comes only from
  code (`fleet.spawn`), as the probes do.
- **The shipyard** (blueprints are built in code for now). Blueprints save with
  `ShipBlueprint.from_grid(grid, name)`, sorted and diffable.
