# Saving — one game, kept for you, only when it is calm

**Date:** 2026-09-26
**Status:** The owner answered the three design questions (§2) on 2026-09-26 and asked for it to be
built the same day. Built on `claude/game-saving-gfabv1`; §15 records where the build differs
from the first draft.
**Depends on:** `main` at `ae32d48`, which has the floating origin, asteroids, the airlock,
hands and items, flight controls, and quantum energy through salvage.
**Governed by:** CLAUDE.md's floating-origin rule. A position that must survive a shift is a
`UniversePoint`, never an engine `Vector3`.
**Closes these hooks:** quantum energy §17 ("the store, the suit cell and the salvage ledger save
when saving exists"), asteroids §13 ("saving the universe position to disk").
**Amends, once approved:** quantum energy §10.3 (the ledger is saved and no longer lasts only one
session), and the building-a-ship skill (a ship's state has to round-trip, see §11).

---

## 1. Why

Nothing survives a quit. When you close the game, the ship, the QE you gathered, the salvage you
took and everything you moved aboard are gone. The next launch starts over at the field's edge
with a half-full store.

This spec adds a single continuous game. It saves itself, and each launch resumes it.

---

## 2. Decisions taken

The owner, 2026-09-26:

| Question | Answer |
|---|---|
| How does the player save? | **Autosave to one slot.** No manual saves, and no slots to pick between. Launching the game resumes it. |
| Where can you be when it saves? | **"Anywhere but not in the middle of an action or while taking damage. Must be stable and safe."** There is no damage yet, but there will be. |
| Items thrown or left drifting outside? | **"Maintained to an extent. We don't need to track every item forever. Once the player has moved far enough away for a set period of time they are deleted and lost."** |

What follows from them:

- A save is only ever written in a **calm** moment (§5). Loading a save therefore never
  resumes a half-finished action. Nothing needs saving mid-cycle, mid-transition or mid-flight
  of a bolt, which keeps the save format small.
- One slot and no manual save means **no save-scumming**. That suits the slice spec's direction
  (Slice 5: losses in the field are permanent).
- Items outside are **strays** (§7): they are saved and they keep drifting, until you have been
  far from one for long enough. Then it is gone for good.

---

## 3. What is saved

| Part | Holds | Owner of `to_dict()` / `from_dict()` |
|---|---|---|
| Header | format version, generator versions (§8), save time, play time | `SaveGame` |
| World | universe seed | `flight_test.gd` (from `AsteroidStream.seed`) |
| Ship's layout | the grid: coords, block ids, orientations, hp | `ShipBlueprint` (reused, as a dictionary; §6.2) |
| Ship in space | position (`UniversePoint`), rotation, linear and angular velocity | `Ship` |
| Flight settings | assist on/off, speed lock and its speed, heading hold and its heading, a burn latched when you stood up | `FlightComputer` |
| Store | QE amount | `QuantumStore` |
| Airlocks | per airlock cell: pressure, and whether each hatch is open | `Airlock` |
| Items aboard | per item: kind, variety, state, where (§6.4), use state (§6.5) | `Ship` via `Item` |
| You | mode (walking, seated or suit), pose, head pitch, velocity, what's in your hand | `flight_test.gd`, through `Avatar` and `Grasp` |
| Suit cell | charge | `SuitCell` |
| Salvage | each cloud's centre, and the ledger: cloud id → taken indices | `SalvageField` + `SalvageLedger` |
| Strays | per stray: kind, variety, universe position, rotation, velocities, use state, far-time (§7) | `StrayLedger` (new) |

### 3.1 What is not saved, and why

| Not saved | Why it is safe to drop |
|---|---|
| Pushed rocks | They go back to their seeded places anyway once their region unloads (asteroids spec §2). |
| Salvage pushed but not taken | Same rule as today (quantum energy §10.3): it returns to its seeded place when its cloud loads. The ledger still records what was taken. |
| Airlock or machine mid-cycle, seat transitions, bolts in flight, a charging throw | A save is never written during one (§5). |
| Camera view (cockpit, chase, first or third person) | Falls out of the mode: seated loads to the cockpit, walking to first person. |
| The floating origin's offset | The origin is placed where the saved focus is on load (§6.1). Nothing engine-sized is stored. |
| Where the flight started | `AsteroidRecipe.find_start()` works it out from the seed again. The rocks depend on it, so it must stay a pure function of the seed. |
| The pilot light's timer, boost's fractional QE | Less than one QE. Dropping it is invisible. |
| HUD toggles (F3 readout, the controls card) | Session conveniences, not game state. |

---

## 4. When it saves

- **Every 60 seconds of play**, if it is calm. If it is not calm, the save waits for the first
  calm moment after that.
- **When an action ends**, if the last save is more than 15 seconds old. Examples: an airlock
  finishes cycling, you sit down, the machine finishes making something. The moments you'd
  most hate to lose get saved promptly.
- **On quit** (window close, `NOTIFICATION_WM_CLOSE_REQUEST`), if it is calm. If it is not, the
  last save stands. You lose at most the action in progress and up to a minute before it.
- **Never** during loading, or in the first 2 seconds after a load (§6.7).

A small, dim `SAVED` tag fades in and out at the HUD's bottom-right corner for about 1 second,
in the HUD's palette. It is the only sign that a save happened. Nothing else on screen says so.

---

## 5. Calm: when a save is allowed

`SaveGate` asks every registered source "are you busy?". It saves only if none is, and none has
been for the last **CALM_FOR = 2 s**, so it never saves on the very tick an action finishes.

| Source | Busy while |
|---|---|
| `CameraDirector` | a sit or stand transition is running |
| each `Airlock` | its cycle's stage is not `IDLE`, or a hatch is part-way open or bolted |
| each `QuantumMachine` | its cycle's stage is not `IDLE`, or an item is in its bay |
| the quantum machine's charge plate | it is charging the suit |
| `Avatar` | re-entry righting is running; the suit is dry and the emergency cell is bringing you home |
| `Grasp` | a throw is charging; something just let go of still ignores you (its release grace) |
| items in use | a `PlasmaBolt` is in flight aboard |
| `Ship` | a rock struck the hull less than **STRUCK_CALM = 5 s** ago |
| `Avatar` (suit) | you bumped a rock less than 5 s ago |
| **damage (future)** | anything took damage less than 5 s ago. Slice 2 plugs in here. |

Deliberately **not** busy:
- **Flying.** Seated at the helm, burning or drifting, is a stable state. It loads mid-flight
  at the saved velocity, with speed lock and heading hold as they were. A seated burn stops on
  load, because no key is held yet; a burn latched by standing up mid-burn keeps burning.
- **Spacewalking.** Drifting outside on suit thrusters is a stable state too. You load outside,
  at your saved place and velocity relative to the universe.
- **Holding an item.** It loads in your hand.
- **A lit flare, or a hand lamp switched on.** Each loads in the same state, with the burn time
  left (§6.5).
- **Low power, or a low suit.** These are ongoing conditions, not actions.

A source registers a `Callable` returning a `String` reason, or `""` for calm. The gate keeps
the reasons, so the debug readout (F3) can show *why* a save is waiting. Adding damage later is
one new source, with no change to the gate.

---

## 6. How a load rebuilds the game

A load builds the scene exactly as a new game does, then overwrites its state. It never
builds the scene a second way. `flight_test.gd::_ready()` gains one branch: build the ship from
the saved layout, or from `_starter_grid()` when there is no save. A save whose layout has no
blocks is treated as no save.

### 6.1 Order

1. Read the file and check it (§8). If it is missing, unreadable or refused, start a new game.
2. The world seed goes to `AsteroidStream` before `start()`.
3. The ship's grid comes from the saved layout, through `Ship.set_grid()`. **Stocking is
   skipped** (`Ship._stocked = true` before the build), so the shelves are not refilled on top
   of the saved items.
4. `Universe.origin` is set to the saved focus, the hull or you on a spacewalk, rounded to
   whole `Universe.STEP`s. Every saved `UniversePoint` then converts to a small engine position.
   `AsteroidStream.start()` loads the rocks around it before the first frame, as it does today.
5. Hull: transform and velocities.
6. Store, flight settings, airlocks, suit cell, ledger.
7. Items aboard (§6.4), then you (§6.3), then strays (§7).

### 6.2 The ship's layout

The layout is stored as the dictionary form of `ShipBlueprint`: sorted parallel arrays and its
`format_version`. It is **not** a `.tres`. Save files are JSON (§8). Loading a `.tres` from
`user://` can run a script embedded in it, and a save file is something players pass around.

Today every game's layout is the starter's. Once the shipyard (Slice 1 Tasks 16–20) exists, the
saved layout is whatever you launched. Hp is saved now so block damage needs no format change.

### 6.3 You

| Saved mode | Loads as |
|---|---|
| walking | standing at the saved interior pose, head pitch restored |
| seated | seated at the helm (`CameraDirector` placed directly, with no transition), cockpit view |
| suit | outside at the saved universe position and rotation, at the saved velocity, via `Avatar.enter_suit()`; the universe focuses on you |

The interior pose is stored in the ship's interior space. The interior never moves, so this is
safe. The load checks that the cell under the pose is still a walkable block. If it is not,
because the layout changed, you stand at the new-game spawn instead. (`Avatar.can_stand_at()`
was the first plan, but it is a physics query, and the interior's colliders are not in the
physics space yet while the scene is still being built.)

### 6.4 Items aboard

Each item under `Ship.items` and in your hand is saved:
- `kind` (item definition id), `variety`;
- `state`: stowed, loose or held;
- **stowed:** the stow point's position in interior space. On load, the item goes to the stow
  point within `Ship.RESEAT_TOLERANCE` of it. This is the same rule a rebuild already uses. If
  no point matches, the item loads loose where the point was, and falls to the floor.
- **loose:** interior-space transform, linear and angular velocity;
- **held:** attached to your hand through `Grasp`, as if just taken.

Items the machine is holding in its bay are never saved, because a save never happens while one
is there (§5).

### 6.5 An item's use state

`ItemUse` gains `save() -> Dictionary` and `restore(state)`. The defaults do nothing.

| Use | Saves |
|---|---|
| `HandLamp` | `on` |
| `Datapad` | `on` |
| `Flare` | `burn`, `burn_left` |
| `PlasmaEmitter` | nothing (its cooldown is shorter than the calm window) |

Items that no longer exist in the catalogue are skipped with a warning.

### 6.6 Airlocks

Airlocks are saved by cell. A save is only taken when a cycle is `IDLE`. The idle state is
therefore just pressure plus which hatch stands open. That covers the case that matters: you are
on a spacewalk with the airlock depressurized and the outer hatch open behind you. You load to
find it that way.

### 6.7 Settling

For 2 seconds after a load, the gate reports busy (`"settling"`) while physics wakes, rocks
arrive and items find their stow points. Nothing saves until the loaded state has proven stable.

---

## 7. Strays: items outside

A **stray** is an item outside the ship that no seed accounts for. Salvage in its cloud is not a
stray, because the seed and the ledger account for it (§3.1). Nothing makes strays yet: hands are
suspended on a spacewalk, and only salvage is ever outside. The first strays will come with hands
outside (quantum energy §17): carrying or throwing things out of the airlock, and salvage carried
off. `StrayLedger` is built now so that feature only has to call `adopt(item)`.

### 7.1 The rule

- A stray is kept, and saved, while you are near it.
- Once it is more than **FORGET_BEYOND = 5 km** from you (the universe's focus: the hull, or you
  on a spacewalk), its **far-time** starts counting, in play time.
- Coming back within 5 km resets its far-time to zero.
- When its far-time reaches **FORGET_AFTER = 10 minutes**, it is **gone for good**. It is freed
  if it is loaded, and dropped from the ledger either way.
- Play time only: time with the game closed does not count. A stray you left 3 minutes before
  quitting still has 7 minutes left when you load.

5 km is beyond salvage's view range and a comfortable distance for the asteroid bubble. 10 minutes
is long enough to fly away, realize you left something, and come back. Both are constants to
tune in play.

### 7.2 Mechanics

- `StrayLedger` (`RefCounted`, pure) holds one entry per stray: `kind`, `variety`, a
  `UniversePoint`, rotation, velocities, `far_time`. `tick(delta, focus: UniversePoint)` advances
  far-times and returns the ids to forget. It is pure so it can be tested without a scene.
- `StrayField` (a `Node3D` under `Outside`, like `SalvageField`) owns the ledger and the live
  `Item` nodes. Each live stray joins `Universe.EXTERIOR_SPACE` (CLAUDE.md), and `StrayField`
  refreshes the ledger's `UniversePoint` from the live item before each save.
- A stray more than `SalvageField.FREE_BEYOND` from you is **unloaded**: its node is freed and
  its last position and velocity stay in the ledger. It does not move while unloaded, and loads
  again when you come back within range. This matches the rocks, which also stand still while
  you are away.
- A stray that is swallowed, or carried back aboard, leaves the ledger.

---

## 8. The file

- **Path:** `user://save/game.json`. On Windows that is
  `%APPDATA%\Godot\app_userdata\WhoKnows\save\game.json`.
- **Written safely:** write `game.json.tmp`, flush and close it, rename the current
  `game.json` to `game.json.bak`, then rename `.tmp` to `game.json`. A crash at any point leaves
  either the old save or the new one whole.
- **Read safely:** if `game.json` will not parse, try `game.json.bak`. If both fail, start a new
  game and **leave both files where they are**, with an error in the log. A bad save is never
  silently overwritten until a new save succeeds.
- **JSON**, through `JSON.stringify` / `JSON.parse_string`. Vectors are arrays of numbers and
  `UniversePoint`s are `[x, y, z, fx, fy, fz]`. Integers above 2^53 cannot occur: the universe
  is far smaller than that.

### 8.1 Versions

- **`format`** (int, starting at 1): the shape of the file. `SaveGame.migrate(dict)` upgrades
  older formats one step at a time. A format *newer* than the game understands is refused: the
  game starts new and does not autosave over that file (the `SAVED` tag shows
  `SAVE LOCKED: NEWER VERSION` instead).
- **`generators`**: `{asteroids: AsteroidRecipe.VERSION, salvage: SalvageField.VERSION}`. Each is
  a new constant, starting at 1, bumped whenever a seed's output changes. If salvage's version
  differs, the **ledger is dropped** (with a log line), because its indices would point at
  different items. If the asteroids' version differs, the rocks may now stand where the ship
  was, so **the world starts over**: the ship goes back to the start, at rest, and you come back
  aboard. You keep the ship, its store, everything aboard and your suit; the salvage clouds and
  strays start fresh. (The first draft pushed the hull clear of whatever rock it overlapped.
  Starting over is simpler and always safe.)

---

## 9. Starting, and starting over

- **Launching** loads the save if there is one; otherwise it is a new game. There is no title
  screen yet. When one exists, *Continue* and *New game* belong on it.
- **Starting over:** `play.bat -- --new-game` starts a new game. The old save is renamed to
  `game.json.old` rather than deleted. Nothing in the game deletes a save.
- **Headless runs never touch the real save.** Tests, probes and `--headless` scene loads get
  saving **off** unless a test turns it on with a temporary path (`SaveGame.path`). The
  headless probes and GUT runs must stay deterministic, and must never overwrite the owner's
  game.

---

## 10. Files

| File | Change |
|---|---|
| `src/save/save_game.gd` | **New.** `SaveGame`: the file, its header, versions, migration, safe write and read. |
| `src/save/save_gate.gd` | **New.** `SaveGate`: busy sources, the calm window, the timers (§4, §5). |
| `src/save/save_codec.gd` | **New.** Pure helpers: `Vector3`, `Basis`, `Transform3D`, `UniversePoint` to and from JSON arrays. |
| `src/world/stray_ledger.gd` | **New.** §7.2. |
| `src/world/stray_field.gd` | **New.** §7.2. |
| `src/ui/saved_tag.gd` | **New.** The `SAVED` tag (§4). |
| `src/ship/ship.gd` | `to_dict`/`from_dict` for the hull and items; skip stocking on load; hull-struck time for the gate. |
| `src/ship/ship_blueprint.gd` | `to_dict`/`from_dict` alongside the `.tres` form. |
| `src/flight/flight_computer.gd` | `to_dict`/`from_dict` (§3). |
| `src/quantum/quantum_store.gd`, `src/quantum/suit_cell.gd` | `to_dict`/`from_dict`. |
| `src/world/salvage_ledger.gd` | `to_dict`/`from_dict`. |
| `src/world/asteroid_recipe.gd`, `src/world/salvage_field.gd` | `VERSION` constants (§8.1). |
| `src/ship/airlock/airlock.gd` | `to_dict`/`from_dict` at idle; busy source. |
| `src/avatar/avatar.gd`, `src/avatar/grasp.gd` | `to_dict`/`from_dict`; busy sources. |
| `src/items/item_use.gd` and its four uses | `save`/`restore` (§6.5). |
| `src/camera/camera_director.gd` | Busy source; seat you with no transition. |
| `scenes/flight_test.gd` | Owns the `SaveGame`, `SaveGate` and `StrayField`; `capture()` and the restore that gather and hand out every part; load-or-new in `_ready()`; save on quit; the gate's state on F3. |

`to_dict`/`from_dict` follows `WorldState`'s naming in the planetfall spec §12.4. The bridge
computer plan uses `save()`/`restore()` for the same idea within a session. When the computer is
built, its state joins the save through a thin `to_dict` wrapper.

---

## 11. Testing

### 11.1 Automated (GUT, headless)

- **Round-trip per part.** For each `to_dict`/`from_dict` pair, `from_dict(to_dict(x))` equals
  `x`, including through `JSON.stringify` and `JSON.parse_string`. That catches any float or int
  that JSON changes.
- **`UniversePoint` far out.** A point 10^9 m away round-trips exactly.
- **Whole game round-trip.** Build the scene, change something in every part (fly, spend QE, take
  salvage, stow a mug in the wrong place, drop a crate loose, walk to the galley), save to a temp
  path, build a fresh scene from that file, and compare every part. Run it once each with you
  walking, seated and on a spacewalk.
- **Stocking skipped.** After a load, the number of items aboard equals the number saved, not
  that plus a fresh stock.
- **Gate.** Each busy source blocks a save. A save waits for `CALM_FOR` after the last one clears.
  A save due during a busy spell happens on the first calm moment after.
- **Strays.** `StrayLedger.tick()`: far-time starts beyond 5 km, resets within it, forgets at
  10 minutes, and keeps counting across a save and load.
- **Files.** A truncated `game.json` falls back to `.bak`. Two bad files start a new game and
  leave both on disk. A newer `format` is refused and never written over.
- **Floating origin.** `test_floating_origin_scene.gd` also runs on a loaded scene: strays are
  covered by `Universe.EXTERIOR_SPACE`.
- **No real save touched.** Across the suite, `user://save/game.json` is not created or changed.

### 11.2 In the real game (mandatory)

Launch with `play.bat`, and for each of the following, quit and relaunch:
1. Fly out, lock your speed, and quit seated. You reload seated, moving as you were, the speed
   lock still on.
2. Stow a pistol in the galley, leave a mug on the corridor floor, and quit walking. Both are
   where you left them. The weapon rack is not restocked.
3. Cycle the airlock, step out, and quit on the spacewalk. You reload outside, with the airlock
   depressurized behind you and the suit's charge as it was.
4. Start the airlock cycling and quit during it. You reload from the last calm moment before the
   cycle started.
5. Take salvage, quit, and reload. What you took is still gone, and the store holds its QE.

### 11.3 The building-a-ship skill

Add to its checklist: **a ship's state round-trips through `SaveGame`.** A new block with state
(a new fixture, a store, a door that can be left open) needs a `to_dict`/`from_dict` and a line
in the whole-game round-trip test. Add a `ship_probe.gd` check that saves and loads the ship and
compares the grid and the store.

---

## 12. Later, not built

- A title screen with *Continue* and *New game*.
- Several games at once (profiles). The file path is the only single-slot assumption.
- Saving the bridge computer's course (bridge computer §15), once the computer is built.
- Planetfall's `WorldState` joins the save as another part when worlds are built.
- Slice 5's permanent empire vs expedition split: which parts survive losing a ship. The format
  allows one ship per file today; a fleet is a list of ships.
- Cloud sync, and save thumbnails.

---

## 13. Non-goals

- Manual saving, quicksave or quickload, and save slots.
- Saving mid-action and resuming it part-way through.
- Remembering pushed rocks or pushed salvage.
- Compression or encryption of the file.

---

## 14. Risks

| Risk | Mitigation |
|---|---|
| A long busy spell (a spacewalk with repeated rock bumps) means no save for minutes | The gate's reasons show on F3. The calm windows are short (2 s, 5 s). If this bites in play, lower them. It is not a reason to save mid-action. |
| A field added to a system later is forgotten in the save | §11.3's skill checklist line and the whole-game round-trip test. Any part a test changes but the load doesn't restore fails the comparison. |
| Loading on a changed layout (after the shipyard exists) strands stowed items | Unmatched stow points drop their items loose (§6.4). A blocked avatar pose falls back to the spawn (§6.3). |
| Generator changes silently shift the world under an old save | `generators` versions (§8.1); the ledger is dropped on a salvage change and the hull is pushed clear on an asteroid change. |
| A test or probe overwrites the owner's real game | Saving is off headless unless a test turns it on with a temp path. A suite-wide check proves the real file is untouched (§11.1). |

---

## 15. How the build differs from the first draft

- `capture()` and the restore live in `flight_test.gd`, the one place that knows every part, as
  the HUD wiring already does. `SaveGame` is only the file.
- A saved standing place is checked against the grid, not with a physics query (§6.3).
- A save from another asteroid generator starts the world over rather than pushing the hull
  clear (§8.1).
- A seated burn does not survive a load; a burn latched by standing up does (§5).
- The floating origin's held shift (world-space particles alive) is not a busy source. The RCS
  puffs keep it held for most of any flight, which kept every save waiting, and a particle is
  never saved anyway.

## 16. Build order

1. `SaveCodec` and the pure parts' `to_dict`/`from_dict`: store, suit cell, ledger, blueprint,
   flight settings, with round-trip tests.
2. `SaveGame`: file, versions, safe write and read, with file tests.
3. Hull, items aboard, avatar, airlocks, and load-or-new in `flight_test.gd`, with the whole-game
   round-trip test.
4. `SaveGate` and its sources; timers; save on quit; the `SAVED` tag.
5. `StrayLedger` and `StrayField`.
6. Real-game checks (§11.2), the building-a-ship skill update (§11.3), and a status line in
   `SLICE-1-STATUS.md`.
