# Many ships — every ship can be boarded, flown and saved

**Date:** 2026-10-02
**Status:** Designed with the owner on 2026-10-02. **Built** on `many-ships` (2026-10-02); §12 is
what was built. The owner has the renders; they have not yet flown it themselves.
**Project 1 of 3** toward a ship-designer agent (§1.2). Projects 2 (a ship library and the test
spawn) and 3 (the agent) get their own specs once this is built.
**Depends on:** `main` at `269f106` (world scale and health and damage merged; the design was
drafted against `7e8c281`, and nothing between touched it)
**Amends:** the saving spec (`2026-09-26-saving-design.md`) §3 and §6 (one ship becomes many);
the airlock spec (`2026-09-24-airlock-design.md`) §7 (any ship's airlock lets a suit in); the
cockpit pod spec's seat wiring
**Governed by:** `docs/design/visual-style.md`, `CLAUDE.md` (the floating origin)

---

## 1. Why

### 1.1 The owner's ask

The owner wants an agent that designs and builds a ship from start to finish, from a description
or "be creative", and a game that can spawn it a little way off the starter. Asked what a spawned
ship is for, the owner set a rule:

> we are building a usable ship so we need to be able to board and fly, this is a rule of any
> ship in the game

### 1.2 Three projects

The game today is built round exactly one ship, so the ask splits into three, built in this
order (the owner's choice, 2026-10-02):

1. **Many ships** (this spec): any number of ships in the world, each boardable, flyable and
   saved, with you handed between them.
2. **A ship library and the test spawn:** blueprints as files in `data/ships/` (the starter
   moved there), a catalog test that holds every ship to the rules, a debug key that spawns a
   chosen ship some distance off the starter.
3. **The designer agent:** `.claude/agents/ship-designer.md` and a design skill that turn a
   description into a concept and a layout, hand it to `building-a-ship` to build and prove,
   and finish with the ship in the library, spawned, boarded and flown.

### 1.3 What assumes one ship today

- **You live in the starter.** The avatar, `CameraDirector`, seat, `PilotControls`, canopy view
  and `MotionCoupling` are children of `/Ship` in `flight_test.tscn`; `flight_test.gd` says
  `_ship` 65 times (HUD, origin focus, warp, sensors, NPCs, saving).
- **Every hull draws on the own-hull layer** (`ExteriorBuilder.OWN_HULL_LAYER`, 4), which the
  canopy and every window leave out. A second hull there would be invisible from your seat.
- **An airlock lets in only its own suit:** `avatar.hull == hull` (`airlock.gd` `_watch_threshold`,
  `occupancy`).
- **Every `PilotControls` listens to the one director:** with a shared director, sitting in any
  seat would seat them all.
- **The canopy material** points at `Ship/Canopy` from the scene's root.
- **The save has one `"ship"`.**

## 2. Decisions

| # | Decision | Why |
|---|---|---|
| 1 | Every ship is a complete scene; you are handed between them by one `board(ship)` | Each ship stays self-contained, so project 3's ships drop in; boarding is one tested switch |
| 2 | You get between ships by spacewalk, airlock to airlock, plus a debug key (F8) to the nearest helm | The existing mechanic; the key makes board-and-fly quick to test. Docking is its own spec later |
| 3 | On a spacewalk your suit belongs to the nearest ship | Relative speed, the home marker and the airlock follow the ship you are heading for |
| 4 | Ships more than 20 km off sleep; they wake inside 18 km | A ship you cannot see costs nothing; the gap stops flicker |
| 5 | A sleeping ship is frozen where it fell asleep | Simple, and it never flies into a world unseen |
| 6 | Every ship is saved; names are stable | The droid's ledger record is named for its ship |
| 7 | Old saves load: format 1 migrates to 2 | The owner's game survives the change |

Rejected: **the player carries the controls** (re-wiring several nodes by path at every boarding,
and a ship nobody is aboard could not feel a crash in its felt gravity); **swapping ships into
`/Ship`** (a 140 ms+ rebuild on every boarding, and every piece of state must round-trip each
time).

## 3. A ship and you

### 3.1 `scenes/ship.tscn`

The `/Ship` subtree of `flight_test.tscn` moves into its own scene, everything a ship needs to
be flown:

| Node | Notes |
|---|---|
| `Ship` (`ship.gd`) | root; `outside_path` set by whoever adds it |
| `Exterior` (`RigidBody3D`), `Exterior/ExteriorBuilder`, `Exterior/ChaseCamera` | as now |
| `FlightComputer`, `PilotControls`, `MotionCoupling` | paths local to the ship |
| `CanopyPortal`, `Canopy` (`SubViewport`), `Canopy/CanopyCam`, `Canopy/CanopyOverlay` with `CockpitMarker` and `HeadingCockpitMarker` | as now |
| `Interior`, `Interior/InteriorBuilder`, `Interior/PilotSeat` (with its shape and `Eye`) | as now |

- **The canopy material** (`ViewportTexture` `viewport_path = NodePath("Canopy")`, the
  `ShaderMaterial` and the texture both `resource_local_to_scene`) moves into `ship.tscn`, so
  each instance draws its own canopy view.
- **No `#` comments** in it (`CLAUDE.md`). After building, load it and read the material's
  `viewport_path` and each `@export` path back at runtime.
- `Ship._ready` already builds its airlocks, lights, warp drive, sensors, store, droid, RCS show
  and damage effects, so each instance gets them.

### 3.2 You

- **`CameraDirector` moves to the scene root** (`/CameraDirector`). It gains `bind(ship)`: the
  flight computer and the chase camera it switches views with. `avatar_path` and
  `interior_camera_path` point at the avatar wherever it is (the director holds the nodes, not
  paths, after `_ready`).
- **`PilotSeat` gets its director by reference** (`seat.director`), set by `_wire_ship` (§5.2), not
  by `camera_director_path`.
- **`PilotControls` takes the stick only for its own seat:** the director's `piloting_changed`
  is answered with `set_seated(on and director.seat_ship() == ship)`; every other ship's
  controls stay unseated and ignore input.
- **`MotionCoupling` stays per ship.** It drives that ship's felt gravity always, and shoves,
  shakes and jolts the avatar only while the avatar's parent is that ship's `Interior`.
- **The avatar** is still authored under `Ship/Interior` in `flight_test.tscn` (a child added
  under the instanced scene), and moves between interiors and `Outside` by `enter_plating`,
  `enter_suit` and `place`, as now.

### 3.3 `flight_test.tscn`

- `Ship` becomes an instance of `ship.tscn` named `Ship`, with `outside_path` `../Outside`. The
  starter keeps every path the tests use (`Ship/Interior/Avatar`, `Ship/Interior/PilotSeat`,
  `Ship/PilotControls`, `Ship/MotionCoupling`, `Ship/Exterior/ChaseCamera`, `Ship/Canopy/...`).
- **Only `Ship/CameraDirector` moves** (to `CameraDirector`): 11 references in tests and probes
  change.
- `ChaseMarker` and `HeadingChaseMarker` keep their path to the starter's chase camera in the
  scene file; `board()` re-aims them (§4.1).

### 3.4 `aboard` and `ships`

`flight_test.gd`'s `_ship` splits in two:

- **`aboard`**: the ship you are in, or the one your suit belongs to. The HUD, helm, warp panel,
  markers, course chime, hands, rescue and hop follow it.
- **`fleet.ships()`**: every ship. Saving, NPC capture and the save gate go over all of them (the
  repair torch already walks `Ship.GROUP`).

Each of the 65 uses is sorted into one or the other in the plan.

## 4. Boarding

### 4.1 `board(ship)`

The one place you move from ship to ship, in `flight_test.gd`. Boarding the ship you are aboard
does nothing. It:

1. **The ship you leave:** `set_own(false)` (§4.2); its interior hides (`Interior.visible`); its
   cockpit markers are unregistered from the HUD.
2. **The ship you board:** `set_own(true)`; its interior shows; its cockpit markers registered.
3. **Rebinds to it:** `_director.bind(ship)`; `ChaseMarker` and `HeadingChaseMarker` cameras;
   the contact, course and body markers' `sensors` (and the cockpit-view ones reparented into its
   `CanopyOverlay` with its `CanopyCam`, the chase-view ones aimed at its `ChaseCamera`); the warp
   panel's `drive`; the course chime's sensors; `_avatar.grasp.world_root` (its `items`); the
   rescue and its cost (its store); the exterior NPC director's `cameras`; the floating origin's
   focus (its hull, or you on a spacewalk).
4. **Sets `aboard`** and emits `aboard_changed(ship)`.

Its canopy needs no switching: `CanopyPortal.sync` already stops drawing when the viewing camera
is not inside its interior.

### 4.2 `Ship.set_own(own: bool)`

Which render layer the hull's own pieces are on: `ExteriorBuilder.OWN_HULL_LAYER` (4) while you
are aboard, layer 1 otherwise, so another ship shows through your windows and canopy. It covers
every kit under `Exterior` that sets `OWN_HULL_LAYER` today: the skin and the lenses
(`HullDressing`), the airlock alcoves (`AirlockAlcove.LAYER`) and `DamageShow.layer`. The beams
and the RCS puffs are on layer 1 already and stay there. Light masks stay `1 | 4`, so your floods
light another ship's hull. `Ship.own` is kept and re-applied after
every rebuild (`_rebuild_everything`). A ship starts not own; `board()` makes it own.

### 4.3 What boards you

1. **An airlock, from outside.** `Airlock` lets in a suit from any ship: in `occupancy()` and
   `_watch_threshold()`, `avatar.hull == hull` becomes "the avatar is on a spacewalk". `crossed`
   (`outward` false) calls `board()` with the airlock's ship. Stepping out (`outward` true) keeps
   `aboard` and moves the focus to you, as now.
2. **On a spacewalk, the nearest ship.** At 4 Hz, `SuitTie` (`src/ship/suit_tie.gd`, a small
   node the scene owns; its choice is a pure static function, tested alone) measures the distance from you to each awake ship's hull surface (its centre less its
   `ExteriorBuilder.bounds()` radius). When another ship's is at least `SUIT_SWITCH_MARGIN`
   (10 m) nearer than yours and within `SUIT_REACH` (500 m), your suit becomes its: `avatar.hull`,
   `beacon_source` and `home_source` (its nearest airlock that has an alcove), then `board()`. The
   margin stops it flicking between two ships you float between.
3. **F8, debug:** `board_nearest()` seats you at the helm of the nearest other awake ship within
   `Fleet.SLEEP_AT`: if you are seated it stands you up at once (a `stand_now()` beside
   `sit_now()`: no camera move), puts the avatar in that ship's interior a cell aft of its seat
   (`enter_plating` into the new interior), `board()`, then `_director.sit_now(its seat)`. Refused (returns
   false, the warp panel's toast says why) during a warp on either ship, on a spacewalk, and while an airlock
   you are in cycles. It is how the owner, the tests and the agent check board-and-fly quickly.

### 4.4 A ship nobody is aboard

It keeps flying under its own flight computer: with no pilot, the assist holds as it does when you
stand up today (with no speed lock it brakes to rest; a lock keeps going). Its droid keeps
working; its loose items feel its own felt gravity; its hum and RCS sounds are heard only aboard,
as now.

## 5. Ships in the world

### 5.1 `Fleet` (`src/ship/fleet.gd`)

A `Node` at the scene root, the one place that knows every ship:

| API | Does |
|---|---|
| `adopt(ship)` | takes the starter authored in the scene (slot 0) |
| `spawn(grid, place: Transform3D, stock := true, ship_name := "") -> Ship` | instances `ship.tscn`, gives it the next free slot and a name never used before in this game (`Ship2`, `Ship3`... from `next_number`, or `ship_name` when loading), sets `outside_path`, adds it under the scene root, `set_grid(grid, stock)`, puts the hull at `place` at rest. Null past the cap |
| `remove(ship) -> bool` | frees it and its slot; refuses the starter (`Ship`) and the ship you are aboard. Unused in this project; project 2's debug spawn will use it |
| `ships()`, `named(name)`, `nearest(point, except)` | |
| `sleeping(ship)`, `place_of(ship) -> UniversePoint` | |
| signals `joined(ship)`, `left(ship)`, `slept(ship)`, `woke(ship)` | |

- **Names are never reused,** even after `remove`, so a new ship's droid never inherits a gone
  one's ledger record: `next_number` is saved (§6.1).
- **`MAX_SHIPS` 16.** Interiors are 2 km apart on x (`Ship.SLOT_SPACING`): slot 15 is 30 km out,
  where a float holds about 2 mm.
- **Sleeping** (`SLEEP_AT` 20 km, `WAKE_AT` 18 km from the universe's focus, checked at 1 Hz, never
  the ship you are aboard):
  - asleep, a ship keeps its place as a `UniversePoint` and its velocities, leaves
    `Universe.EXTERIOR_SPACE` and `AsteroidStream.SPACE_ANCHOR` (no world builds ground for it),
    is `PROCESS_MODE_DISABLED` (hull out of physics, droid and sounds stopped) and hidden;
  - waking puts the hull back at `universe.to_engine(point)` with its velocities, rejoins both
    groups, and processes and shows again;
  - a ship that was coasting when it fell asleep is found where it fell asleep.
- **Ships bump each other:** hulls are layer 1 with 1 in their mask, so a collision deals crash
  damage to both by the existing path.

### 5.2 `_wire_ship(ship)` in `flight_test.gd`

Everything set once per ship, on `Fleet.joined`, the starter included:
`seat.director`; the warp's `bind(system, universe, whereabouts, ship.sensors, recipe, busy)`
with `busy` asking about that ship; `flight_computer.whereabouts`; the sensors' sources
(`LifeContacts`, `RockContacts`, `BodyContacts`), `universe`, `system`, `whereabouts`;
`ChaseCamera` and `CanopyCam` far planes (`BodyProxy.VIEW_FAR`); `pilot.lights`;
`pilot.warp_pressed` to its warp's `engage`; its warp's `travel_started` and `travel_ended`;
`npc_director.ledger` and the F4 overlay; `plate_shed` to the strays; `blocks_lost`. The sensors
of a ship you are not aboard stop processing (`ShipSensors.process_mode`), so its contact scans
cost nothing.

### 5.3 Cost

An awake ship you are not aboard costs its hull and colliders, its droid, and its lights only
while on (they start off). Its canopy view and its interior are off. Spawning one costs a build
(about 140 ms headless on the starter), fine for a debug spawn and at load.

**The bar:** with a second starter 300 m off, the skill's worst view (seated 60 m off a rock's
night side, both light groups on) holds **≥ 120 fps** at 1280 × 720 on the owner's box, measured
before and after.

## 6. Saving

### 6.1 The shape (format 2)

| Key | Format 1 | Format 2 |
|---|---|---|
| `"ship"` | the one ship's `Ship.to_dict` | gone |
| `"ships"` | — | a list: each ship's `Ship.to_dict(universe)` plus `"name"` |
| `"aboard"` | — | the name of the ship you are aboard |
| `"fleet"` | — | `{"next": n}`: the number the next spawned ship's name takes |

- A sleeping ship's hull place is its `UniversePoint` and kept velocities, not an engine position.
- **`SaveGame.FORMAT` becomes 2,** with a migration step: `"ship"` becomes `"ships": [ship +
  {"name": "Ship"}]` and `"aboard": "Ship"` and `"fleet": {"next": 2}`.

### 6.2 Names

The droid's record id is `droid:<ship name>:0`, so names never change: the starter is always
`Ship`, a spawned ship keeps the name it was given. On load the save's `Ship` goes into the
authored `/Ship`, and each other ship is spawned under its saved name. That is why
`Fleet.remove()` refuses `Ship`.

### 6.3 Load order

1. The origin goes near the aboard ship's hull, or near you on a spacewalk (`_restore_places`).
2. `/Ship` is built from the save's `Ship` layout; every other ship is spawned from its layout,
   unstocked (`Fleet.spawn(grid, place, false, name)`); a ship more than `SLEEP_AT` off loads
   asleep.
3. Each ship's `launch_blueprint`, `restore_aboard` and `restore_hull`.
4. `board(aboard)`, then you: walking in its interior, seated at its helm, or on a spacewalk tied
   to its airlock (`_restore_you` and `_restore_spacewalk` take the aboard ship).

A saved ship with no blocks is skipped with an error. If the aboard ship is missing, you wake
aboard `Ship`.

### 6.4 The gate

`save_gate` asks every ship's `busy()` (an airlock cycling on any ship holds the save), plus the
director and you, as now.

## 7. Files

| File | Change |
|---|---|
| `scenes/ship.tscn` | new: the ship (§3.1) |
| `scenes/flight_test.tscn` | `Ship` an instance of it; `CameraDirector` at the root; the canopy material moved out |
| `scenes/flight_test.gd` | `fleet`, `aboard`, `board()`, `board_nearest()` (F8), `_wire_ship()`, the suit tie, saving many |
| `src/ship/fleet.gd` | new (§5.1) |
| `src/ship/suit_tie.gd` | new (§4.3) |
| `src/ship/ship.gd` | `own`, `set_own()`, re-applied on rebuild |
| `src/ship/hull/hull_dressing.gd`, `airlock/airlock_alcove.gd`, `damage_show.gd`, `ship_lights.gd` | take their layer from the ship, not a constant |
| `src/ship/airlock/airlock.gd` | any suit; `crossed` boards |
| `src/camera/camera_director.gd` | `bind(ship)`, `seat_ship()`, `stand_now()` |
| `src/avatar/pilot_seat.gd` | `director` by reference |
| `src/flight/pilot_controls.gd` | seated only for its own seat |
| `src/camera/motion_coupling.gd` | shoves the avatar only in its own interior |
| `src/save/save_game.gd` | `FORMAT` 2, the migration |
| tests and probes | `Ship/CameraDirector` → `CameraDirector` (11) |

## 8. Testing

### 8.1 Automated (GUT, headless, targeted files while building)

- **`test_fleet.gd`:** slots handed out in order and reused after `remove`; the cap; names; `nearest`;
  sleep past 20 km and wake inside 18 km (and nothing in between); `SuitTie`'s choice with and
  without the 10 m margin; a sleeping ship's place exact
  across three origin shifts; `remove` refuses `Ship` and the ship aboard.
- **`test_ship_own.gd`:** `set_own` moves the skin, lenses, alcove and damage effects between
  layer 4 and 1 (the beams stay on 1), and a rebuild keeps it.
- **`test_boarding_scene.gd`** (the real `flight_test.tscn`, a second starter 300 m off):
  - F8 seats you at its helm; the director, HUD vehicle, origin focus and warp panel follow it;
  - full forward stick moves it and not the starter;
  - stand and walk its corridor;
  - step out of its airlock, float to the starter, the suit switches ships past the margin,
    cycle in: `aboard` is the starter;
  - the starter's hull is on layer 1 and in the second ship's `CanopyCam` mask;
  - only the seated ship's `PilotControls` is seated.
- **`test_save_scene.gd`:** two ships round-trip, aboard the second, seated; a format-1 save loads
  as one ship with you aboard; a far ship loads asleep.
- **`test_save_game.gd`:** the format 1 → 2 migration.
- The `.tscn` checks read properties back at runtime (`CLAUDE.md`): the canopy material's
  `viewport_path` on two instances differs, and each draws its own canopy.

Per the owner's standing preference, the full suite (about 8 minutes) is run only with their
say-so at the end.

### 8.2 In the real game

- **`ship_probe.gd`** gains a two-ship pass: spawn a second ship 300 m off, `board_nearest()`,
  sit, full stick for 3 s, stand. It prints
  `fleet   2 ships, aboard Ship2, own layer ok, asleep 0`, and fps in the worst view with one ship
  and with two.
- **Renders for the owner:** the second ship from the starter's seat, fill-lit and dark with its
  floods on; the starter from the second ship's seat; mid-spacewalk between the two.
- **The owner flies it:** F8 across, fly the second ship, spacewalk back to the starter.

## 9. Upkeep in the same branch

- **`building-a-ship`:** a checklist step "every ship goes through `Fleet` and must board, fly and
  save"; *Mistakes already made* for the one-ship assumptions in §1.3; `Fleet`, `board()`,
  `set_own()` and F8 in `reference.md`; the probe's `fleet` line.
- **`CLAUDE.md`:** a rule beside the floating origin's: *Every ship is usable: you can board it,
  fly it, and it saves. Ships come and go through `Fleet`; the ship you are in is `aboard`.*
- **This spec:** a *What was built* section at the end.

## 10. Build order

1. `ship.tscn` extracted; `flight_test.tscn` instances it; `CameraDirector` to the root, seat by
   reference, controls seated for their own seat. The existing suite's flight, seat, airlock
   and save tests pass unchanged but for the 11 paths.
2. `Ship.set_own` and the layer pieces.
3. `Fleet` (adopt, spawn, remove, nearest) and `_wire_ship`; a second ship spawns and sits there.
4. `board()` and F8: fly the second ship.
5. Airlocks for any suit, the suit tie, boarding by airlock.
6. Sleeping and waking.
7. Saving many, the migration.
8. The probe's two-ship pass, renders, fps; the skill and `CLAUDE.md`.

## 11. Not in this project

- **Docking** (two hulls held airlock to airlock): its own spec.
- **The ship library, the debug spawn key, the catalog test:** project 2.
- **The designer agent and design skill:** project 3.
- **Ships flown by NPCs**, and a ship that moves while asleep.

## 12. What was built (2026-10-02)

Built on `many-ships` in eight tasks (`docs/superpowers/plans/2026-10-02-many-ships.md`), as
designed, except:

- **The canopy material is made in code** (`Ship._make_canopy_material`, from
  `Canopy.get_texture()`), not a `resource_local_to_scene` `ViewportTexture` in `ship.tscn`
  (§3.1): a `ViewportTexture`'s path inside an instanced scene is fragile, and the code version is
  checked directly (`test_ship_scene.gd`).
- **A canopy camera nobody looks through rests at the helm's eye on the hull**
  (`CanopyPortal.sync`). Found building §4.1: a ship you had never been in kept its canopy camera
  at the world's origin, and the cockpit's velocity marker projected through it at depth 0 the
  frame you boarded (an engine error). A first fix at the hull's origin was wrong too: the marker
  aims at the hull's origin at rest.
- **`board()` lets go of every other ship**, not only the last one aboard (§4.1): a loaded game
  sets `aboard` before it first boards, so the starter stayed own beside the ship you were in.
- **Beyond §5.1:** `Fleet.awake()`, `max_ships` (the cap, settable for tests), and `launch` on
  `spawn` (a saved ship's launch layout must be set before its grid).
- **§4.2 as built:** a ship is its own until told otherwise (`Ship.own` starts true; `Fleet.spawn`
  makes a new one not own), and the layer is moved by one pass over the hull's drawn pieces after
  every rebuild (`Ship._apply_own`, pieces made on layer 4 alone are marked `OWN_ONLY`), not by
  each builder taking its layer from the ship. F8 is also refused mid-sit ("SITTING DOWN").
- **From the final review** (a fresh reviewer read the whole branch):
  - **each ship has its own livery** (`Ship.livery`, swapped onto every piece painted with the
    shared one by `_apply_livery` after each rebuild). The stripe is measured through
    `hull_inverse`, which every ship had been pushing into the one shared material: with two
    awake, one ship's stripe was drawn in the other's frame. Rendered with the second ship
    rolled 15°: each stripe stays on its own hull;
  - **a canopy view starts off** (`ship.tscn`, `render_target_update_mode` 0) and a ship falling
    asleep turns it off: one loaded asleep never ran its portal, so it rendered a 1536 × 512 view
    every frame;
  - **a ship spawned after you boarded scans nothing** (`_wire_ship` sets its sensors' process
    mode, as `board()` does).
- **`SuitTie` checks at 4 Hz in its own `_physics_process`**; `suit_tie.check()` runs it now.
- **Proof** (§8.2), on the owner's box at 1280 × 720:
  - seated 60 m off a rock's night side with both light groups on: **130 fps with one ship and
    130 with a second 300 m off**. `main` gave the same 130 that day; the 143–150 in the skill
    was from 2026-09-29;
  - the probe prints `fleet   2 ships, aboard Ship2, own layer ok, asleep 0`, `board   F8 ok`, and
    the second ship flying while the starter stays put;
  - `test/probes/fleet_play.gd` plays it in real time: F8 to the second ship's helm, a full cycle
    out of its airlock, across the gap with the suit switching to the starter, a full cycle in
    through the starter's airlock, and the starter's helm and a burn. All 16 checks pass.
- **Not done:** the owner flying it by hand, which needs a way to spawn a second ship in play
  (project 2's debug spawn key). Until then a second ship comes only from code.
- **The save file is shared by every checkout** (`user://`): playing this branch upgrades it to
  format 2, which `main` (format 1) then refuses and locks against autosaves.
