# Hostile ships · Task 16: The duel probe, tuning and renders

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9, Task 10, Task 11, Task 12, Task 13, Task 14, Task 15 (merged into `hostiles` before this branch was cut). **Wave:** 9.
**Branch:** `hostiles-t16`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t16`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t16` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t16` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-16/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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
- Create: `who-knows/test/probes/duel_probe.gd`
- Modify (tuning only): `who-knows/src/pilot/pilot_values.gd`, then if needed `src/combat/weapon_values.gd`

**Interfaces:**
- Consumes: everything above.

The probe, in the style of `combat_probe.gd` (`extends SceneTree`, windowed, `--resolution 1280x720`, args the output dir; prints one line per result):

- **Duels in real time** in a patch of space with no rock within 5 km (the combat probe's `_clear_heading` idea: turn to a clear heading, then place both ships there). Each fight: two ships 3 km apart, both pilots `engage` each other, run until one is destroyed or 12 minutes. Print `duel <a> <skill> <style> vs <b> <skill> <style> · <seconds> · winner <x> · hits <band>:<rate> ... · qe <spent a>/<spent b> · switches <n> · rock_contacts <n>`.
- **Fights:** starter vs starter at 0.5/0.5 (×5, styles AUTO), 0.2 vs 0.8 (×5), BRAWLER vs STAND-OFF and the reverse (×3 each), Warden vs starter (×2).
- **Seated fps:** one starter-vs-starter duel with the probe seated at one helm (the canopy rendering): `fps <min> <mean>`; the same for the Warden fight against its 109–117 floor.
- **Losing:** a fight with you seated aboard the losing ship, to `LostScreen.finished` (the reload stubbed); print `lost ok`.
- **Your pilot:** one duel with the probe seated and your ship's pilot on (`fight_for_you`): print its result line.
- **Renders** (eye height 1.6 m where aboard), into the output dir: `hit_from_helm_400.png`, `hit_from_helm_1000.png` (an enemy bolt burst on the foe's hull from your helm), `cabin_heavy_hit.png` (the dip's deepest frame), `enemy_30pct.png` (sparks and gas, from your helm at 300 m), `core_0.1s.png`, `core_0.4s.png`, `breakup_2s.png` (from the helm and a chase view at 80 m).

**Pass** (spec §12.2): starter-vs-starter at 0.5/0.5 averages **4–6 minutes**; the 0.8 pilot wins at least 4 of 5 against 0.2; neither style wins every one of its six; `rock_contacts` 0 everywhere; seated **≥ 120 fps** in the starter duel, the Warden's ≥ 109; light-bolt hit rates in the 400 m band ≥ 70% and the 1 km band ≤ 40% (the dance holds).

- [ ] **Step 1: Write the probe** and run it once (`godot --path who-knows --resolution 1280x720 --script res://test/probes/duel_probe.gd -- D:\git\whoknows-hostiles\.superpowers\renders\task-16`). Expected: lines printed; record the first numbers.
- [ ] **Step 2: Tune** `PilotValues` (ranges, jink, gains, hold-fire) toward the pass marks, re-running between changes; only if the fight length cannot reach 4–6 minutes by the pilot alone, move `WeaponValues` damage or the light recharge, one at a time. Log each run to `run<n>.log` in the output dir.
- [ ] **Step 3: Send the renders and the numbers to the owner** (SendUserFile), with the pass table filled in. The owner judges the look.
- [ ] **Step 4: Commit** `test: the duel probe; pilots tuned to a five-minute fight` with the values changed listed in the body.
