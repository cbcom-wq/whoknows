# Hostile ships · Task 6: `ShipPilot` on every ship

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5 (merged into `hostiles` before this branch was cut). **Wave:** 3.
**Branch:** `hostiles-t06`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t06`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t06` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t06` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-6/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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
- Create: `who-knows/src/pilot/ship_pilot.gd`
- Modify: `who-knows/src/ship/ship.gd` (build it beside `FireControl`; save `"pilot"`; `since_hostile_fire`), `src/flight/pilot_controls.gd` (stand aside while the pilot is on — the handover itself is Task 15)
- Test: `who-knows/test/unit/test_ship_pilot.gd`

**Interfaces:**
- Consumes: Tasks 1–5.
- Produces:
  - `ShipPilot` (Node, `Ship/ShipPilot`), `enum Style { AUTO, STAND_OFF, BRAWLER }` (values 0, 1, 2 — `FightAssessment` mirrors 1 and 2).
  - Fields: `ship: Ship`, `flight: FlightComputer`, `fire_control: FireControl`, `on := false` (setter; off releases the hold, centres input, restores orders it changed), `skill := 0.5`, `style_choice := Style.AUTO`, `style := Style.STAND_OFF` (the one in use), `objective: PilotObjective`, `intent: StringName` (one of `&"closing"`, `&"holding_range"`, `&"jinking"`, `&"boosting"`, `&"holding_fire"`, `&"pursuing"`, `&"holding_station"`, `&"no_pilot"`), `last_reading: Dictionary` (own and foe readings and the score, for the readout).
  - `engage(id: StringName) -> void` — objective `DestroyObjective.new(id)`, `on = true`.
  - `targets(node: Node) -> bool` — the objective's target is that ship's hull or you (`Weapons.YOU`), fighting or pursuing.
  - `effective_skill() -> float` — `skill × COMPUTER_DAMAGED_SKILL` with the computer damaged; the computer wrecked → the pilot does nothing (intent `&"no_pilot"`, no input written; `FireControl` left as it was, §5.6).
  - `tick(delta: float) -> void` (`_physics_process` calls it; tests call it).
  - `to_dict()` (`on`, `skill`, `style_choice`, `style`, `objective`), `from_dict(d)`.
  - `Ship.ship_pilot: ShipPilot`; `Ship.since_hostile_fire: float` (seconds since a hostile ship's bolt hit this hull: set in `_on_hull_hit` when `Sides.hostile_to(side, Sides.side_of(hit.source))`).
  - `Ship.side` set to `HOSTILE` → `ship_pilot.on` follows only through `engage` (Task 7 spawns with `engage`).

What a tick does (the spec's §5.2 layers; exact cadence from `PilotValues`):
1. **Every `ASSESS_EVERY`:** read own and foe (`FightAssessment.read`), choose the style (unless `style_choice` fixes it), the preferred range.
2. **Every `TACTICS_EVERY`:** the target's point and velocity (`Weapons.point_of`, `velocity_of`); the wanted velocity = the foe's velocity + along the line of sight `position_gain × (range − preferred) / 2 s`, clamped to the speed limit; brawler boosts (`set_pilot_input(..., boost)`) while more than `2 × BRAWL_BAND` outside its band; jink: every `jink_every` (± 30% random), or `reaction` seconds after `Broadside.inbound(...) > 0`, add a lateral velocity change of `jink_share × lateral thrust / mass × 1.5 s` in a random direction across the line of sight; add `RockAvoid.steer(...)`; `flight.hold_velocity(wanted)`. The face: `Broadside.best_face` (recomputed when a turret's stage changes), `desired_basis` toward the target. Fire control: `mark(objective.target_id())` once, `set_orders(ENGAGE)`, but `HOLD` while the range is past `hold_fire_past × reach` and the store is under `HOLD_FIRE_QE`. Pursuing: wanted velocity along `last_seen().dir` at the speed limit, the face is the nose (`Vector3.FORWARD`), orders `HOLD`. Done (gave up, or nobody to fight): `hold_velocity(Vector3.ZERO)`, intent `&"holding_station"`.
3. **Every physics tick:** `rotate := Broadside.rotate_input(...)`; `flight.set_pilot_input(Vector3.ZERO, rotate, boost)`; `flight.clear_heading()`. Translation is all through the hold.

`PilotControls._process`: when `ship_pilot != null and ship_pilot.on`, write nothing (Task 15 adds the takeback).

- [ ] **Step 1: Write the failing tests** (scene: `flight_test.tscn`, `save_enabled = false`, a second starter spawned and made `HOSTILE`, `engage(Weapons.ship_id(starter))`; physics stepped with `await wait_physics_frames(n)`):
  - `test_drives_only_through_the_flight_computer`: a `FlightComputer` spy (subclass recording `set_pilot_input` / `hold_velocity` calls) swapped in → calls recorded; the hull's `linear_velocity` never written by the pilot (assert the pilot's script has no `linear_velocity =`/`apply_` text: `FileAccess.get_file_as_string` on `ship_pilot.gd` does not contain `linear_velocity =`, `apply_central`, `apply_torque`, `global_transform =`).
  - `test_turns_its_best_face_to_the_target`: target 800 m off its starboard; after 8 s, the dorsal or ventral turret `can_engage` the target.
  - `test_closes_to_brawl_and_holds_range`: forced `BRAWLER`, start at 1.5 km → after 40 s the range is within `BRAWL_RANGE ± BRAWL_BAND`.
  - `test_jinks_when_fired_on`: a bolt from the target armed toward it → within `reaction + 0.5` s `intent == &"jinking"` and `flight.held_velocity` changed by > 2 m/s across the line of fire.
  - `test_marks_and_engages`: after one tactics tick its `fire_control.list[0] == ship:Ship` and orders `ENGAGE`.
  - `test_a_wrecked_computer_stops_the_pilot_not_the_guns`: `ship.damage` computer to 0 → after a tick no new `set_pilot_input` call; `fire_control.orders` still `ENGAGE`; mend → input resumes.
  - `test_a_damaged_computer_halves_skill`: computer at 40% → `effective_skill() == skill × 0.5`.
  - `test_off_lets_go`: `on = false` → `flight.velocity_hold` false, orders back to what they were before `engage`.
  - `test_pilot_round_trips`: `to_dict` / `from_dict` keep on, skill, style choice, objective id.

- [ ] **Step 2: Run** `./run_tests.ps1 '-gselect=test_ship_pilot.gd'`. Expected: FAIL.
- [ ] **Step 3: Implement** `ShipPilot`, its build in `Ship._ready` (after `fire_control`), `"pilot"` in `to_dict`/`restore_aboard`, `since_hostile_fire` (ticked in `_physics_process`), and the `PilotControls` guard.
- [ ] **Step 4: Run** `test_ship_pilot.gd`, `test_ship_turrets.gd`, `test_weapons_job.gd`, `test_fleet.gd`. Expected: pass.
- [ ] **Step 5: Commit** `feat: ShipPilot flies and fights through the flight computer and fire control`.
