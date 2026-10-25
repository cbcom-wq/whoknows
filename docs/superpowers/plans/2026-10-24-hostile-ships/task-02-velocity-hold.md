# Hostile ships · Task 2: The flight computer holds a velocity

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** none (merged into `hostiles` before this branch was cut). **Wave:** 1.
**Branch:** `hostiles-t02`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t02`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t02` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t02` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-2/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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

## The task

**Files:**
- Modify: `who-knows/src/flight/flight_computer.gd` (`translation_force`, new API)
- Test: `who-knows/test/unit/test_velocity_hold.gd`

**Interfaces:**
- Produces: `FlightComputer.hold_velocity(v_world: Vector3) -> void`; `release_velocity() -> void`; `velocity_hold: bool`; `held_velocity: Vector3` (world, m/s). `translation_force(local_velocity, input, mass, budget, boost, assist, locked, locked_speed, held: Variant = null)` — `held` is the hold's target in hull axes or null.

The assist already cancels "velocity nobody asked for" on every axis without input, toward 0 (or the locked speed fore and aft). The hold changes only what it cancels *toward*: on an axis with no input, toward `held`'s component instead. Same budgets, same `DRIFT_AUTHORITY`, same speed limit: a pilot with a hold flies no better than the assist. Needs assist; turning assist off, or the assist refused, drops it (as it drops the speed lock). Not saved (the pilot re-asks every tactics tick).

- [ ] **Step 1: Write the failing tests:**
  - `test_without_a_hold_nothing_changes`: `translation_force(Vector3(3, 0, -5), Vector3.ZERO, 1000, budget, false, true, false, 0.0)` equals the same call with `held = null` and equals today's expected `(-3000, 0, 5000)` clamped by budget.
  - `test_a_hold_pulls_each_quiet_axis_toward_it`: `held = Vector3(10, 0, -20)`, velocity `Vector3(0, 0, -20)`, no input → force x > 0, z ≈ 0, y ≈ 0.
  - `test_input_on_an_axis_wins_over_the_hold`: input `x = -1` with the same hold → force x == `-lateral`.
  - `test_the_hold_needs_assist`: `hold_velocity(v)` with assist off leaves `velocity_hold` false; turning assist off drops a hold.
  - `test_the_hold_obeys_the_speed_limit`: a hold of 10× `CRUISE_LIMIT_MPS` on a simulated hull is clamped by the existing limit after a physics tick (use the existing test's hull fixture from `test_flight_computer.gd`).

- [ ] **Step 2: Run** `./run_tests.ps1 '-gselect=test_velocity_hold.gd'`. Expected: FAIL (no `hold_velocity`).

- [ ] **Step 3: Implement** the API and the `held` parameter. In `_apply_translation`, pass `basis.inverse() * held_velocity` when `velocity_hold`, else null. A hold set replaces the speed lock's fore-and-aft target while it lasts; `speed_locked` itself is left as it was (the pilot never touches it).

- [ ] **Step 4: Run** `test_velocity_hold.gd` and `test_flight_computer.gd`. Expected: pass.

- [ ] **Step 5: Commit** `feat: the assist can hold a velocity, for a pilot that is not you`.
