# Hostile ships · Task 10: Spill-over

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** none (merged into `hostiles` before this branch was cut). **Wave:** 1.
**Branch:** `hostiles-t10`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t10`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t10` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t10` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-10/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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
- Modify: `who-knows/src/ship/ship_damage.gd` (`_hurt`, `NEIGHBOURS`)
- Test: `who-knows/test/unit/test_spill_over.gd`

**Interfaces:**
- Produces: `ShipDamage.NEIGHBOURS: Dictionary` — each section to its neighbours along the length on its side and across in its third: `port_bow → [starboard_bow, port_mid]`, `port_mid → [starboard_mid, port_bow, port_stern]`, `port_stern → [starboard_stern, port_mid]`, and the starboard mirror. `_hurt(section, amount)` keeps what fits; the rest is split evenly between neighbours not at 0, each recursively; when every section is at 0 the rest is dropped. Breadth-first with a visited set so it ends.

- [x] **Step 1: Write the failing tests** (`ShipDamage.build` on the starter's layout):
  - `test_overflow_goes_to_neighbours`: deal `section_hp[port_bow] + 1000` to a port-bow block → port bow at 0, starboard bow + port mid share 1000 (500 each ± 1).
  - `test_overflow_skips_dead_neighbours`: port bow and starboard bow at 0 → the next 1000 on port bow goes all to port mid.
  - `test_one_face_can_reach_zero`: keep hitting one port-bow block → `hull_whole()` reaches 0.0 after about the total hp (± 1%).
  - `test_components_never_spill`: 5000 on the core → core at its hp, every section untouched.
  - `test_crash_damage_spills_too`: `Ship.take_damage_many` with a crash-sized amount past a section's hp → a neighbour takes the rest (scene-based).
- [x] **Step 2–4:** run (FAIL), implement, run `test_spill_over.gd`, `test_ship_damage_model.gd`, `test_ship_damage.gd` (pass).
- [x] **Step 5: Commit** `feat: a section at 0 passes the rest to its neighbours`.
