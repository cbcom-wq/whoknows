# Hostile ships · Task 14: SHIP LOST, the reload, and no save under attack

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** Task 6, Task 12, Task 13 (merged into `hostiles` before this branch was cut). **Wave:** 8.
**Branch:** `hostiles-t14`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t14`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t14` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t14` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-14/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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

2. **You board another ship, or step out on a spacewalk, mid-fight:** the hostile's Destroy keeps your *ship* as its target (it does not jump to you unless your ship is gone); the save gate still sees you as engaged while any hostile targets a ship you are aboard or you. Task 14's `test_engaged_follows_you_between_ships`.

The test named there is part of this task; write it with the others.

## The task

**Files:**
- Create: `who-knows/src/ui/lost_screen.gd`
- Modify: `scenes/flight_test.gd` (`lose`, `_rescue`, the save source)
- Test: `who-knows/test/unit/test_ship_lost.gd`

**Interfaces:**
- Produces:
  - `LostScreen` (ColorRect over everything): `play(text: String) -> void` — white to full in 0.15 s, to black over 1.5 s, `text` in the HUD's font and `HudPalette.READOUT` for 2 s, then `signal finished`. `LostScreen.TOTAL := 3.65`.
  - `FlightTest.lose(text: String) -> void` — once: `save_enabled = false` for the rest of this scene (no save can be written after a death), input off for the avatar, `LostScreen.play(text)`, and on `finished` `get_tree().reload_current_scene()` (which loads the save, as a launch does; it must not set the save aside — that is F9's `new_game`).
  - `FlightTest.you_aboard(ship: Ship) -> bool` — walking or seated in its interior, at its weapons station's gun camera, or in one of its airlocks.
  - On a ship's `destroyed`: if `you_aboard(ship)` → `lose("SHIP LOST")` (no blast damage to you, you are already gone).
  - `_rescue(avatar)`: if `home` is null, freed or destroyed → `lose("SUIT LOST")` instead of placing you.
  - The save source `_under_attack() -> String`: `"under attack"` while any awake ship with `side == HOSTILE` and its pilot on has an objective (fighting or pursuing) whose target is **you** (`targets(_avatar)`) or **any crew ship within `CONTACT_RANGE` of you** (so boarding another ship mid-fight does not open a save), or while `aboard.since_hostile_fire < PilotValues.ENGAGED_CALM`.

- [ ] **Step 1: Write the failing tests:**
  - `test_your_ship_destroyed_loses_the_game`: seated in a spawned ship you boarded; destroy it → `lose` called once with `"SHIP LOST"`, `save_enabled` false, the `LostScreen` playing (do not let it reload in the test: a `reload` callable injected and recorded).
  - `test_a_spacewalk_survives_your_ship_but_not_nowhere_to_wake`: on a spacewalk 400 m off; your ship destroyed → no `lose`; then downed (`_avatar.health.take(999)`) → when `Downed` reaches `WAKING`, `lose("SUIT LOST")`.
  - `test_no_save_under_attack`: a hostile engaging → `save_gate.busy()` contains `"under attack"`; its objective pursuing you out of contact → still; it gives up (61 s) and 10 s pass since its last hit → not busy for that reason.
  - `test_engaged_follows_you_between_ships`: a hostile targets your ship; you board another crew ship 200 m away (`board_at_helm`) → still `"under attack"`; move the ship it targets 6 km from you and the hostile's objective pursuing it → still (pursuing a crew ship near you counts only while that ship is within contact of you, so this case reads `""` once the 10 s calm has passed — assert exactly that).
  - `test_winning_lets_saving_resume`: the only hostile destroyed → after `ENGAGED_CALM` the source returns `""`.
- [ ] **Step 2–4:** run (FAIL), implement, run `test_ship_lost.gd`, `test_save_gate.gd`, `test_downed.gd` (pass).
- [ ] **Step 5: Play it once:** spawn a hostile Warden and let it win; the white, the black, *SHIP LOST*, and the game back at the save from before the fight.
- [ ] **Step 6: Commit** `feat: losing your ship goes back to the last save; no save while under attack`.
