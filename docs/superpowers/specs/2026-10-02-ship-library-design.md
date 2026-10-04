# Ship library — ships as files, one set of rules, and a spawn that warps them in

**Date:** 2026-10-02
**Status:** Designed with the owner on 2026-10-02. Amended while planning, 2026-10-03, against
`main` at `2476498` (§11). Not built.
**Project 2 of 3** toward a ship-designer agent (many ships spec §1.2). Project 1, many ships, is
built and merged (`docs/superpowers/specs/2026-10-02-many-ships-design.md`); project 3, the agent,
gets its own spec.
**Depends on:** `main` at `6fc33d3` (many ships merged; the dev QE refill and scrap plates landed
after)
**Amends:** the ship skill (`.claude/skills/building-a-ship/`): where ships live and the rules
every ship must pass
**Governed by:** `docs/design/visual-style.md` (the arrival's look), `CLAUDE.md` (the floating
origin; every ship is usable; no `#` comments in `.tscn`/`.tres`)

---

## 1. Why

The owner wants an agent that designs and builds a ship end to end, and a game that can spawn it
near you. Project 1 made every ship boardable, flyable and saved. This project gives ships a home
and a gate:

- **a library:** every ship a file in `data/ships/`, the starter moved there out of code;
- **one set of rules** every ship must pass, checked by a test over the whole library, by the probe,
  and by a fast tool project 3's agent can run on a draft;
- **a spawn you can use:** F6 opens a panel; a number spawns that ship ahead of you; it arrives as
  if out of warp (the owner's ask, 2026-10-02: "give an animation like it is coming out of warp.
  This could be reusable in the future").

Until now a second ship existed only in code (`fleet.spawn`), so the owner could not fly one by
hand.

## 2. Decisions

| # | Decision | Why |
|---|---|---|
| 1 | A ship is a JSON file plus a Markdown note | The owner's choice. One plain-data shape for every ship, like saves and a future shipyard; the note holds the reasoning a JSON file cannot |
| 2 | The library holds only the starter for now | The owner's choice. Designing ships is project 3's; the rules are proven with broken copies of the starter, kept in tests |
| 3 | One shared checker, `ShipRules` | The owner's choice. The catalog test, the probe and the agent's tool all use the same rules |
| 4 | Reach, not storeys | The owner wants multi-level ships kept possible: a rule asks that every walkable cell is reachable on foot over the moves the game supports. Ladders don't climb yet, so a multi-level ship fails today with the reason, and passes the same rule once climbing is built |
| 5 | F6 opens a spawn panel; 1–9 spawn; Delete removes | A debug tool in the plain style of F3 and F4 (F9 was meant; `main` gave it to the dev reset, §11) |
| 6 | A spawned ship arrives out of warp, by a reusable `WarpArrival` | The owner's ask; anything that brings a ship in later (NPC ships, wingmen) uses the same arrival |

Rejected: ships as commented GDScript (code, unlike player-made blueprints later); a new deck-plan
text format (a parser, and orientations are awkward to draw); checks written only inside the
catalog test (the agent could only learn a draft breaks a rule by running GUT); growing
`ShipValidator` (it runs in the game; the layout, hull and droid checks are too heavy there).

## 3. The library

### 3.1 A ship file

`data/ships/<id>.json`, named for its id:

```json
{
	"id": "starter",
	"name": "Starter shuttle",
	"description": "Two decks: a bridge with a cockpit pod, five rooms, an airlock aft.",
	"format": 1,
	"cells": [
		[-3, 0, 1, "hull", 0],
		[-3, 0, 2, "hull", 0],
		[-3, 0, 3, "thruster", 0]
	]
}
```

- **A row is `[x, y, z, block, orientation]`**, one per line, sorted as `ShipBlueprint.from_grid`
  sorts (x, then y, then z), so a diff shows exactly the blocks that changed. A library ship is
  never damaged, so there is no damage column. Coordinates and orientation codes are the ship
  skill's (`reference.md`): −Z the bow, +X starboard, +Y up.
- **`name`** is what the panel and the probe show and what `launch_blueprint.ship_name` carries.
  **`description`** is one line.
- **`format`** is 1. A loader that meets a newer one refuses the file and says so.
- **Nothing limits the levels:** `y` is any integer.

`data/ships/<id>.md` beside it holds the reasoning: why each system is where it is, the numbers it
was balanced to. The starter's comments in `_starter_grid()` move to `starter.md`, grouped by deck
and system (the cabin, the engine pods, the equipment deck, RCS pairs, pitch balance, power, the
fairings).

**JSON files are not resources.** Running from the editor or the project they load as files; an
exported build will need `*.json` in the export filter. Nothing is exported yet.

### 3.2 `ShipLibrary` (`src/ship/ship_library.gd`)

On the model of `NpcCatalog`:

| API | Does |
|---|---|
| `static load_from_dir(path := "res://data/ships") -> ShipLibrary` | reads every `*.json` there |
| `ids() -> Array[StringName]`, `has(id) -> bool` | sorted, the starter first |
| `name_of(id)`, `description_of(id)` | |
| `grid(id) -> ShipGrid` | a fresh grid each call, every block intact |
| `errors: Array[String]` | each file that would not load, and why: bad JSON, a newer format, a row that is not five values (whole numbers, a block name, an orientation 0–23), two rows in one cell, an id that is not its file's name. The library only reads; whether the blocks exist is a rule (`UNKNOWN_BLOCK`, §4.1) |
| `static read(path) -> Dictionary` | one file: `{id, name, description, grid}`, or `{error}`; what `ship_check.gd` uses |
| `static write(path, id, name, description, grid) -> Error` | writes the one-row-per-line form above |
| `const STARTER := &"starter"` | |

A file in `errors` is left out of `ids()`; the catalog test fails on any.

### 3.3 The starter moves

1. `ShipLibrary.write` writes `data/ships/starter.json` from today's `_starter_grid()`, once, and a
   test checks the two match block for block (id and orientation at every cell, and nothing else).
2. Then `_starter_grid()`'s body becomes `return library.grid(ShipLibrary.STARTER)`; its comments
   go to `starter.md`. Its 16 callers (tests, probes, the new game) keep working. Most call it on a
   bare `flight_test.gd` that never entered the tree, so it loads the library itself when `library`
   is not loaded yet.
3. `test_starter_shuttle.gd`'s pinned figures (mass, balance, rooms) keep guarding the starter, and
   it gains a pin on the file itself: its block count and a hash of its sorted rows. Changing the
   starter means changing that pin on purpose, with the reason in `starter.md`.

The flight scene holds one `ShipLibrary` (`library`), loaded in `_ready`.

## 4. The rules: `ShipRules` (`src/ship/ship_rules.gd`)

`ShipRules.check(grid: ShipGrid, catalog: BlockCatalog) -> Dictionary` is pure: it builds the
interior layout (`InteriorLayout.plan`), the hull layout (`HullLayout.plan`), the droid's paths
(`DeckPaths.build`) and the stats (`ShipStats.compute`) itself, touching no nodes. It returns
`{"rules": Array, "notes": Array}`; each item is `{"code": StringName, "text": String, "cell":
Vector3i or null}`.

### 4.1 Rules: a library ship breaks none

| Code | Rule | Skill step |
|---|---|---|
| `UNKNOWN_BLOCK` | every block id is in `data/blocks` (then no other rule is checked) | |
| `VALIDATOR` | `ShipValidator.validate` reports nothing, warnings included: one core, all connected, a helm, mounts reachable, power, airlock hatches | 5 |
| `POWER_MARGIN` | power made > power drawn × 1.1 | 6 |
| `CANNOT_THRUST` | forward thrust > 0 | 4 |
| `CANNOT_BRAKE` | reverse thrust > 0 | 4 |
| `NO_AUTHORITY` | turning authority on pitch, yaw and roll (`torque_budget`, which already takes each axis's weaker direction) | 4 |
| `UNBALANCED` | on each axis, the imbalance under a full burn is under 5% of that axis's authority | 6 |
| `CRIPPLED` | not crippled as built (`ShipStats.crippled`) | 3 |
| `NO_POD` | a helm looks straight at a canopy, so the cockpit pod forms (`InteriorLayout.pods()` not empty) | 2 |
| `NO_STAND` | a cell you stand up into from the helm is open floor (in `DeckPaths`: walkable, no fixture, not the airlock): the one behind it (opposite its facing) or either beside it, where `PilotSeat.STAND_SPOTS` lie. Stricter than the seat, which can also step past a quiet fixture | 2 |
| `NO_AIRLOCK` | at least one airlock cycles (`InteriorLayout.airlocks()` not empty), with a way through its inner hatch (`door_normal` not zero) | 2 |
| `CUT_OFF` | every walkable cell that is not a fixture or an airlock, and the cell inside each airlock's inner hatch, is reachable on foot from the first of the helm's stand-up cells that is open floor, over the moves the game supports (`DeckPaths`) | 2 |
| `WINDOW_UNMATCHED` | every window inside has one outside (`HullLayout.unmatched` empty) | 2 |
| `DROID` | a ship with `ShipCrew.MIN_CELLS` walkable cells or more has a dock, and every one of the droid's jobs is reachable from it | 2 |
| `NO_PIECES` | every hull section has pieces to lose (`ShipDamage.build(grid, catalog, Ship.inner_of(grid, catalog)).pieces`), or it never shows a hole | 3 |

**`CUT_OFF` and levels (decision 4).** `DeckPaths` walks within a storey; ladders don't climb yet.
So a multi-level ship fails `CUT_OFF` today, and its text says why: "cells on storey 1 can't be
reached from the helm: ladders don't climb yet". When climbing is built, that project gives
`DeckPaths` its vertical links and multi-level ships pass the same rule unchanged.

### 4.2 Notes: reported, never failing

- **RCS exhausts blocked** (`RCS_BLOCKED`, per block): the starter has 6 of 8.
- **The feel** (`FEEL`): turn acceleration on each axis (`torque_budget / inertia`), and side,
  vertical, brake and forward thrust per tonne.
- **The ship** (`SIZE`): blocks, mass, power made and drawn, QE capacity and warp reach.

### 4.3 Where the rules are used

- **`test_ship_catalog.gd`**: zero rules for every library ship (§7).
- **`ship_probe.gd`** prints `rules   0 broken` (or each, `<-- CODE text`) and the notes.
- **`ship_check.gd`** (`.claude/skills/building-a-ship/`, beside the probe), the agent's design loop:

  ```
  godot --headless --path who-knows --script <abs>/ship_check.gd -- <path to a ship .json>
  ```

  It loads the file (reporting a load error as a finding), runs `ShipRules`, prints each rule
  broken with its cell, then the notes and numbers, and exits 0 when no rule is broken, 1
  otherwise. It takes a couple of seconds, with no scene and no window.

## 5. The spawn panel (F6)

A debug panel in the plain style of the F3 readout (a `Label` under `Prompt`, top left), built by
the flight scene (`SpawnPanel`, `src/ui/spawn_panel.gd`):

```
SPAWN                                         F6 closes
1  Starter shuttle   Two decks: a bridge with a cockpit pod, five rooms, an airlock aft.
Del  remove the nearest spawned ship
SPAWNED Ship3 · Starter shuttle · 200 m away
```

- **F6** opens and closes it. While it is open, **1–9** spawn that library ship and **Delete**
  removes the nearest spawned ship; shut, those keys do nothing (none is bound to anything else).
  A held key's repeats do nothing.
- **Where a ship arrives** (`SpawnSpot`, pure; `src/ship/spawn_spot.gd`): 200 m ahead of the ship
  you are aboard, or of your view on a spacewalk, at rest, turned to face you. Ahead of where you
  will be when it lands: your velocity times `WarpArrival.DURATION` is added first, so a spawn while
  cruising does not land in your path. The spot must be
  clear of rocks as a warp's drop-out is (`WarpPlan.rock_near`: 300 m from big and mid rocks, 30 m
  from rubble) and 60 m from every other ship. Otherwise it tries the same distance in 45° steps
  round you, then 400 m out the same way; with none clear it refuses: `NO CLEAR SPOT NEAR`.
- **Refused**, with the reason on the panel's last line: during a warp (`WARP ENGAGED`), past the
  fleet's cap (`THE FLEET IS FULL`), no clear spot, and while another ship is still arriving
  (`A SHIP IS ARRIVING`). It works seated, walking and on a spacewalk.
- **Delete** removes the nearest spawned ship (any but the starter, awake and arrived) other than
  the one you are aboard, with `Fleet.remove`: `REMOVED Ship3 · Starter shuttle`. `NO SPAWNED SHIP`
  with none; `YOU ARE ABOARD IT` when the only one is yours (on a spacewalk, the ship your suit
  belongs to). The starter is never a candidate, so nothing says it can't be removed.
- **A spawned ship is a real ship:** `fleet.spawn(library.grid(id), place)` with its library name
  as its `ship_name`, then `WarpArrival.play` (§6). Boardable with F8 or by airlock once it has
  arrived, flown and saved like any other.

## 6. Arriving out of warp: `WarpArrival` (`src/flight/warp_arrival.gd`)

A node that plays one ship's arrival and frees itself, reusable by anything that brings a ship in.

```gdscript
static func play(hull: RigidBody3D, at: Transform3D, end_velocity := Vector3.ZERO) -> WarpArrival
signal arrived
```

### 6.1 What you see (`DURATION` 1.5 s)

- The hull starts `FROM` 2 km back along its arrival line (behind `at`, against its nose) and rushes
  in along its nose, braking hard: its distance to the spot falls as `(1 − t)³`, so it covers most
  of the way in the first third and eases onto the spot.
- **A wake** streams behind it: one long, thin box (`WAKE_WIDTH` 0.6 m) from the stern back along
  the line, its length the distance travelled in the last `WAKE_SECONDS` 0.15 s, so it is long
  while fast and shrinks to nothing as the ship stops. The warp's dust streaks are the only other
  streaks in space; the wake speaks the same language.
- **A flash** at the stop: a soft shell round the hull, `FLASH_SCALE` 1.0 to 1.6 of the hull's
  bounds, fading out over `FLASH_TIME` 0.4 s.
- Then the ship sits at rest. Silent, like everything outside.

### 6.2 Within the style guide

- **No new shader:** the wake and the flash are geometry with the engine's `StandardMaterial3D`
  (unshaded, additive blend, alpha fading), the style guide's allowance (§2.5).
- **Colour from the palette:** a new `SpacePalette.WARP`, a warm white near `HullPalette.WORK_LIGHT`;
  bloom halos it against the dark (§3.8).
- **Render layer 1**, so your windows and canopy show it; children of the hull, so the floating
  origin carries them (`CLAUDE.md`). The spot is an engine position, so a shift mid-arrival must
  carry it too: nothing else moves a ghosted hull, so the arrival adds whatever the hull was moved
  by since it last placed it.
- **The cost is two meshes for 1.5 s.** Measured in the worst view during an arrival.

### 6.3 While it arrives

- **Ghosted, as a ship at warp is:** frozen kinematic, collision layer and mask 0, so it passes
  through rocks and ships on its way in (the warp spec's rule; a ghosted hull is never lifted by a
  world's floor). At the end its layer, mask and freeze come back as they were and it takes
  `end_velocity`: zero for a spawn; a future NPC ship could arrive at 120 m/s, as your own ship
  drops out of a warp.
- **Not yet a ship you can use:** `Fleet.arriving(ship)` is true; F8, the panel's Delete and the
  suit's tie skip it, it never falls asleep, and the save waits until it has arrived (`Fleet` is a
  busy source: `"a ship arriving"`). `arrived` fires when it stops; the flash plays on after it,
  but the ship is usable from then.
- **Freed with the ship:** a ship removed mid-arrival takes its arrival with it.

## 7. Testing

### 7.1 Automated (GUT, headless; targeted files while building)

- **`test_ship_library.gd`**: the library loads the starter, first among `ids()`; each file is
  named for its id; a broken file under `test/fixtures/ships/` (bad JSON, a newer format, a
  four-value row, a mismatched id, two rows in one cell, a fractional coordinate, an orientation of
  24) lands in `errors` with its reason and is left out; `write` then load gives back the same
  grid, and the written file has one row per line.
- **`test_ship_rules.gd`**: the starter breaks no rule; each rule broken by its own broken copy of
  the starter, reported with its code and, where it has one, its cell:
  - an unknown block id; the core removed (`VALIDATOR`); one more thruster in place of the
    spine's stern ramp, inside the validator's margin but not 10% clear of it (`POWER_MARGIN`);
    every thruster made hull (`CANNOT_THRUST`); the retro pair removed (`CANNOT_BRAKE`); the nose's
    yaw pair removed (`NO_AUTHORITY`); the stern thruster bank moved down a deck (`UNBALANCED`);
    every thruster wrecked (`CRIPPLED`); the canopy row made hull (`NO_POD`); the helm boxed in,
    hull behind and beside it (`NO_STAND`); the airlock made deck (`NO_AIRLOCK`); a wall of hull
    across the corridor (`CUT_OFF`); a second walkable deck above the cabin (`CUT_OFF`, its text
    naming ladders); the port hull beside the second porthole made a long low fairing slope facing
    port, so the porthole has no face outside (`WINDOW_UNMATCHED`); the closet moved out to a
    pocket of its own (`DROID`); every piece of the starboard bow made grav plating (`NO_PIECES`).
    Each was checked on the real starter while planning (§11);
  - notes never count as rules: the starter's six blocked RCS are notes.
- **`test_ship_catalog.gd`**, over every library ship, no test written per ship:
  - no load errors; zero rules broken; a `.md` note beside it;
  - **usable** (the owner's rule), in the real scene: spawned 300 m off the starter, F8 boards it,
    a 1 s burn moves it and not the starter, you stand and walk 1 m, and a save brings it back
    with the same layout.
- **The move's match** (build order step 1): the library's starter is the code starter, block for
  block, checked while both exist; then the code version goes and `test_starter_shuttle.gd`'s pin
  on the file's rows takes over (§3.3).
- **`test_spawn_spot.gd`** (pure): straight ahead when clear; the next 45° step when a rock or a
  ship is in the way; 400 m out after that; refused when nothing is clear; facing you.
- **`test_warp_arrival.gd`**: the hull ends exactly at the spot with `end_velocity`; its layer, mask
  and freeze are restored; ghosted all the way in; the wake and flash are gone after; `arrived`
  fires once; a ship removed mid-arrival leaves nothing behind; its pieces are covered by the
  floating origin (`test_floating_origin_scene.gd`'s rule) mid-arrival.
- **`test_spawn_panel.gd`** (the real scene): F6 opens and closes; 1 spawns the starter 200 m ahead,
  arriving, then at rest facing you; spawned while cruising it lands ahead of where you will be;
  a held 1 spawns one ship; F8 skips it while it arrives and boards it after; Delete removes the
  nearest spawned ship, never the starter, and says `YOU ARE ABOARD IT` on a spacewalk tied to the
  only one; refused at the cap,
  during a warp and while another ship arrives; shut, 1 and Delete do nothing; the save waits for an
  arrival.

### 7.2 In the real game

- **`ship_probe.gd`** prints the `rules` line and the notes.
- **`ship_check.gd`** on `starter.json` exits 0 with a clean report; on a broken copy it exits 1,
  naming the rule and the cell.
- **`fleet_play.gd`** spawns through the panel (F6, 1) instead of `fleet.spawn`, waits for the
  arrival, then plays its trip as before.
- **Renders for the owner** (the arrival's look needs the owner's approval, style guide §6): from
  the starter's seat and from the chase view, at 0.2, 0.6 and 1.0 s into an arrival and after it;
  the panel open in the cockpit. Fps in the worst view during an arrival.
- **The owner tries it:** F6, 1, watch it arrive, F8 across, fly it, Delete it.

## 8. Upkeep in the same branch

- **`building-a-ship` skill:** a step "a new ship is `data/ships/<id>.json` plus `<id>.md`; run
  `ship_check.gd` until it exits 0; `test_ship_catalog.gd` covers it with no test of its own"; the
  JSON format, `ShipLibrary`, every `ShipRules` code, `ship_check.gd`, the F6 panel and
  `WarpArrival` in `reference.md`; *Not built yet*: "multi-level ships: written and checked now,
  usable once ladders climb (`CUT_OFF`)".
- **`CLAUDE.md`:** the ship-building section gains "every ship lives in `data/ships/` and passes
  `ShipRules` (`test_ship_catalog.gd`)".
- **`docs/design/visual-style.md`:** the arrival under §3.8 (the wake, the flash, `SpacePalette.WARP`).
- **This spec:** a *What was built* section at the end.

## 9. Build order

1. `ShipLibrary`, the JSON format, `write`; the starter written to `starter.json` and matched block
   for block; `_starter_grid()` reads the library; `starter.md`.
2. `ShipRules` and its broken-starter tests; `ship_check.gd`; the probe's `rules` line.
3. `test_ship_catalog.gd`, with the usable check.
4. `WarpArrival` and `SpacePalette.WARP`; `Fleet.arriving`.
5. `SpawnSpot` and the F6 `SpawnPanel`.
6. `fleet_play.gd` through the panel; renders, fps; the skill, `CLAUDE.md`, the style guide.

## 10. Not in this project

- **Designing new ships:** project 3, the agent.
- **Climbing between levels:** its own project; `CUT_OFF` is ready for it.
- **NPC ships and wingmen arriving:** they will call `WarpArrival.play`.
- **Exporting the game** (and the `*.json` export filter).

## 11. Amended while planning (2026-10-03)

`main` moved on after this design was approved (`6fc33d3` to `2476498`: computer mode, damage by
section, a dev reset), and checking each rule against the real starter turned up two rules that
could not work as written. Every change below was checked on the starter with a throwaway script
before the plan named it.

| Was | Now | Why |
|---|---|---|
| F9 opens the panel | **F6** | `main` gave F9 to the dev reset ("F9 twice starts a new game", `b702074`). F6 is free and means nothing to Windows; F10 opens the window menu |
| `NO_STAND`: the cell behind the helm is walkable with no fixture | **behind or beside** the helm is open floor | The starter's quantum core stands straight behind its helm; the seat stands you up beside it (`PilotSeat.STAND_SPOTS` lie behind and to either side). As written, the starter failed |
| `CUT_OFF` from the cell behind the helm | from the **first stand-up cell that is open floor** | Same reason: the cell behind the starter's helm is a fixture, which `DeckPaths` leaves out |
| `FRAGILE`: no single loss cuts off more than 2 blocks | **`NO_PIECES`**: every hull section has pieces to lose | Damage is by section now (`docs/superpowers/specs/2026-10-03-ship-damage-sections-design.md`): a piece is only ever a block whose loss cuts nothing off, so a loss never cuts anything off. What a ship can now get wrong is a section with nothing to lose, which never shows a hole (the probe's `NO PIECES`) |
| `WINDOW_UNMATCHED` broken by two solid cells behind a porthole | by a **shaped block** beside it whose faces never look out | A porthole is only chosen where at most one cell stands before vacuum, so two cells remove the porthole instead of unmatching it |
| `DROID` broken by walling the closet off | by moving the closet **to a pocket of its own** | Walling it in place cuts the corridor and the airlock too |
| Delete refuses the starter (`CAN'T REMOVE THE STARTER`) | the starter is **never a candidate** | Delete picks the nearest spawned ship, so the starter can never be the one it picked |
| `SPAWNED ... 200 m ahead` | **`200 m away`** | The spot may be a 45° step round you, or behind |
| The spot is 200 m ahead of you | ahead of **where you will be when it lands** | At cruise (120 m/s) you cover 180 m in the 1.5 s it takes to arrive: it would land in your path |
| (not said) | a held key's repeats do nothing; a shift mid-arrival carries the spot; the suit's tie skips an arriving ship; `arrived` fires at the stop, before the flash ends | Found writing the plan's tests |
| Load errors: bad JSON, newer format, not five values, wrong id | also **two rows in one cell, a fractional number, an orientation outside 0–23** | An agent writing JSON will make these; the first would silently overwrite a block, the last crash `BlockOrientation` |
| (not tested) | broken copies for **`CANNOT_THRUST`, `NO_AUTHORITY` and `CRIPPLED`** too | Every rule gets its own broken copy |
