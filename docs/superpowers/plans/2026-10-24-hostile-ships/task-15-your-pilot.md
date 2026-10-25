# Hostile ships · Task 15: Handing your ship to its pilot

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** Task 6, Task 7 (merged into `hostiles` before this branch was cut). **Wave:** 5.
**Branch:** `hostiles-t15`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t15`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t15` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t15` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-15/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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

4. **Taking the stick while your pilot holds a velocity:** the hold is released the same tick, so the ship does not keep fighting your input. Task 15's `test_stick_releases_the_held_velocity`.

The test named there is part of this task; write it with the others.

## The task

**Files:**
- Create: `who-knows/src/ship/computer/pilot_page.gd`
- Modify: `who-knows/project.godot` (`pilot_ai` = **P**, physical keycode 80), `src/flight/pilot_controls.gd` (the key, the takeback), `src/pilot/ship_pilot.gd` (`fight_for_you`), `src/ship/computer/ship_computer.gd` + `computer_context.gd` (`ship_pilot`), `src/combat/weapons_job.gd` (no hold while the pilot flies), `src/ui/vehicle_telemetry.gd` + the HUD band (the `AI PILOT · <STYLE>` line)
- Test: `who-knows/test/unit/test_your_pilot.gd`

**Interfaces:**
- Produces:
  - `ShipPilot.fight_for_you() -> void` — on, skill `PilotValues.YOUR_SKILL`, the objective Destroy on fire control's first listed hostile, else the nearest hostile in contact; with none, `hold_velocity(Vector3.ZERO)` and intent `&"holding_station"`, re-checking every `ASSESS_EVERY` for one. Remembers the orders it found and restores them when turned off (Task 6's `on = false`).
  - `ShipPilot.signal handed_back`.
  - `PilotControls`: `pilot_ai` pressed while seated toggles `ship_pilot.fight_for_you()` / `on = false`; while on, any stick motion past the dead zone, arrow key or translation key (the same tests `_process` already makes) sets `on = false` the same frame and then writes the input as usual. `VehicleTelemetry.ai_pilot: String` (`""` or `"AI PILOT · AUTO"` / `STAND-OFF` / `BRAWLER`), shown in the HUD band in `HudPalette.READOUT`.
  - `PilotPage` (a `ComputerPage`, added to the computer beside WEAPONS when the ship has turrets — the spec's §9.1 put the switch on the WEAPONS page, whose five buttons are all in use, so it gets a page of its own): lines `PILOT · ON/OFF`, `STYLE · AUTO`, the intent, the target; `big` toggles, `prev`/`next` cycle `style_choice`.
  - `WeaponsJob.sat`: sets `gunner_hold` only while `ship.ship_pilot == null or not ship.ship_pilot.on`; turning the pilot on while sat drops the hold, off restores it.

- [ ] **Step 1: Write the failing tests:**
  - `test_p_hands_over_and_hands_back`: seated in the starter, a hostile in contact; `pilot_controls.handle(P)` → `ship_pilot.on`, objective on the hostile, telemetry `ai_pilot == "AI PILOT · AUTO"`; P again → off.
  - `test_stick_releases_the_held_velocity`: pilot on with a hold; a stick motion event → same frame `ship_pilot.on` false and `flight_computer.velocity_hold` false.
  - `test_orders_come_back`: orders `HOLD` before; pilot on sets `ENGAGE`; off → `HOLD`.
  - `test_no_hostile_holds_station`: pilot on with nothing in contact → `held_velocity == Vector3.ZERO`, intent `&"holding_station"`.
  - `test_the_station_without_the_hold`: the Warden; pilot on, sit at the weapons station → `gunner_hold` false and the pilot still writes input; pilot off → `gunner_hold` true.
  - `test_the_pilot_page`: `PilotPage.press(&"big")` toggles; `&"next"` cycles AUTO → STAND-OFF → BRAWLER → AUTO.
- [ ] **Step 2–4:** run (FAIL), implement, run `test_your_pilot.gd`, `test_weapons_job.gd`, `test_weapons_page.gd`, `test_flight_computer.gd` (pass).
- [ ] **Step 5: Commit** `feat: hand your ship to its pilot with P; take it back with the stick`.
