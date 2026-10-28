# Hostile ships · Task 12: Destroyed, removed, saved

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** Task 10, Task 11 (merged into `hostiles` before this branch was cut). **Wave:** 6.
**Branch:** `hostiles-t12`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t12`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t12` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t12` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-12/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
- **Done means:** every step ticked; every test file named in the steps passing (the GUT summary's count and `All tests passed`); the commits on the branch. Then report: what changed (files), the test summary lines, anything that differs from this plan and why, and anything left for a later task.

## Global Constraints

- **The pilot never cheats** (spec §5.1, decision 4): it writes only `FlightComputer.set_pilot_input`, `hold_velocity`/`release_velocity`, `clear_heading`, and `FireControl` (`mark`, `set_orders`, `clear`). Never a hull velocity, transform, force or a turret field. It knows only targets within `WeaponValues.CONTACT_RANGE` (5,000 m), its own ship, and bolts in flight.
- **Numbers live in `PilotValues`** (new) and `HitFeel` (new), as `WeaponValues` does; never a literal elsewhere. `WeaponValues` keeps the turret numbers; tuning (Task 16) moves `PilotValues` first, `WeaponValues` only if the duel needs it.
- **Sides:** `Sides.CREW` (`&"crew"`) and `Sides.HOSTILE` (`&"hostile"`); every existing ship is `CREW`; hostile only across the two.
- **Destroyed** is `ShipDamage.hull_whole() <= 0.0` (§8.1); a section at 0 spills into its neighbours (§8.1 *Spill-over*); components never spill.
- **Pursuit:** 60 s without contact, then give up (§5.5). **No save** while a hostile engages or pursues you, or for 10 s after a hostile bolt hits you (§8.4).
- **The style guide is binding** (`docs/design/visual-style.md`): colours only from `HullPalette`, `InteriorPalette`, `SpacePalette`, `HudPalette`; no new shader (built-in particle and standard materials are fine); warm, never blue; gas is chunky puffs like the airlock's steam (§3.4), foggy never a whiteout. Add every new painting file to `test_visual_style_rules.gd`.
- **Floating origin (CLAUDE.md):** chunks, the blast flash and its light join `Universe.EXTERIOR_SPACE`; world-space particles join `Universe.HOLDS_SHIFT`; gas and sparks on a hull are local to it. The pilot stores directions and ids, never engine positions (a remembered place is a `UniversePoint`). `test_floating_origin_scene.gd` stays green and gains the new nodes.
- **Every ship is usable (CLAUDE.md)** stays true for every ship that exists; a destroyed ship is the one way a ship leaves, through `Fleet.destroy`. Never instance `ship.tscn` any other way.
- **Frame rate:** 120 fps on the GTX 960 at 1280 × 720 seated at the helm in a starter fight; a fight with a Warden no worse than its accepted 109–117 (§12.2).
- **`.tscn`/`.tres`:** no `#` comment near a property or tag (CLAUDE.md).
- **Tests:** from `who-knows`, `./run_tests.ps1 '-gselect=<file>.gd'`; GUT exits 0 on a parse error, so read the summary for `All tests passed` and the count. After any new `class_name`, run `godot --headless --path . --import` first. **Targeted tests only; never the full suite** (~17 min) — that is the owner's call at the end.
- **Godot:** `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe`, written `godot` below.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; commit every new script's `.uid` with it.
- **Skills:** `building-a-ship`, `designing-a-ship` and `building-an-npc` are updated in this branch (Task 17).

## Review focus this task owns

3. **A save loaded with a hostile asleep far off and a destroyed starter:** the hostile comes back hostile with its pilot settings; the starter stays destroyed, hidden and out of physics, and nothing iterating `fleet.ships()` breaks. Task 12's `test_a_destroyed_starter_survives_a_save`.

The test named there is part of this task; write it with the others.

## The task

**Files:**
- Modify: `who-knows/src/ship/ship.gd` (`destroyed` signal, `is_destroyed`), `src/ship/fleet.gd` (`destroy`, the starter held destroyed, saving), `scenes/flight_test.gd` (the deaths aboard; restore)
- Test: `who-knows/test/unit/test_ship_destroyed.gd`

**Interfaces:**
- Produces:
  - `Ship.signal destroyed(ship: Ship)`, emitted once, the first time `damage.hull_whole() <= 0.0` after `take_damage_many`; `Ship.is_destroyed() -> bool`. From then on `take_damage_many` does nothing.
  - `Fleet.destroy(ship: Ship) -> void` — the starter (`name == STARTER`): held as asleep where it is (`_hold`) and added to `_destroyed`, never woken by `check_sleep`, never `aboard`; every other ship: `remove(ship)` (with the aboard check bypassed: `Fleet.remove(ship, force := false)` gains `force`). Emits `left` for a removed ship as now; `Fleet.signal ship_destroyed(ship_name: StringName)` for both.
  - `Fleet.is_destroyed(ship) -> bool`; `capture` writes `"destroyed": true` on a destroyed starter's part; `restore_hull` holds a part with `"destroyed"` destroyed.
  - Leaving `Weapons.TARGETS`: a destroyed starter calls `Weapons.leave(exterior)`.
  - In `flight_test.gd`, on `destroyed`: every NPC of `ship.npc_director` and every record `ship.records(...)` marked dead in `npc_ledger` (`mark_dead`); items aboard dropped (freed with the ship); then `fleet.destroy(ship)` deferred one frame (Task 13 plays the blast before it; Task 14 handles you aboard).

- [x] **Step 1: Write the failing tests:**
  - `test_zero_hull_destroys_once`: deal past the total → `destroyed` emitted once; more damage does nothing.
  - `test_a_spawned_ship_is_removed`: after the frame, `fleet.ships()` lacks it, its slot is free, `Weapons.find(tree, ship_id)` null, a fire control listing it drops it within 2.2 s.
  - `test_the_starter_is_held_destroyed`: aboard another ship; destroy the starter → still in `fleet.ships()`, `fleet.is_destroyed` true, `sleeping` true, invisible, `process_mode` disabled, out of `Weapons.TARGETS`; `check_sleep` with you beside it never wakes it.
  - `test_a_destroyed_starter_survives_a_save`: `capture` → part has `"destroyed": true`; a new scene restored from it holds it destroyed.
  - `test_the_crew_aboard_die`: the starter's droid (`ship.npc_director.live_npcs()`) → `npc_ledger.is_dead(record.id)` after the destruction.
- [x] **Step 2–4:** run (FAIL), implement, run `test_ship_destroyed.gd`, `test_fleet.gd`, `test_ship_turrets.gd` (pass).
- [x] **Step 5: Run** `test/probes/fleet_play.gd` as its header says (CLAUDE.md: after a change to how ships come and go). Expected: its pass line.
- [x] **Step 6: Commit** `feat: a ship at 0% hull is destroyed and leaves the fleet; the starter is held destroyed`.
