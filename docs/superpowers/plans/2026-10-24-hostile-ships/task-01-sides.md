# Hostile ships · Task 1: Sides

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** none (merged into `hostiles` before this branch was cut). **Wave:** 1.
**Branch:** `hostiles-t01`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t01`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t01` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t01` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-1/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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
- Create: `who-knows/src/combat/sides.gd`
- Modify: `who-knows/src/combat/weapons.gd`, `fire_control.gd:154`, `src/ui/target_brackets.gd:37`, `src/ship/ship.gd` (`side`, saving), `src/avatar/avatar.gd` (nothing but the target join, see below), `scenes/flight_test.gd` (join you to `Weapons.TARGETS`, restore `side`)
- Modify tests: `test/unit/test_weapons.gd:13,55-57`, `test/unit/test_fire_control.gd:32,96` (the stub now takes `(shooter, node)`)
- Test: `who-knows/test/unit/test_sides.gd`

**Interfaces:**
- Produces: `Sides.CREW`, `Sides.HOSTILE`; `Sides.hostile_to(a: StringName, b: StringName) -> bool`; `Sides.side_of(node: Node) -> StringName` (a hull's ship's `side`, a `Ship`'s own, `CREW` for the `Avatar`, `&""` otherwise); `Ship.side: StringName = Sides.CREW` (saved as `"side"` in `Ship.to_dict`, read in `restore_aboard`); `Weapons.YOU := &"you"`; `Weapons.is_hostile(shooter: Node, node: Node) -> bool`; `Weapons.hostile_rule` is now called as `hostile_rule.call(shooter, node)`.

- [x] **Step 1: Write the failing tests** in `test_sides.gd` (scene-based like `test_ship_turrets.gd`: instance `res://scenes/flight_test.tscn`, take `/Ship`, `fleet.spawn` a second starter grid):
  - `test_crew_and_hostile_are_hostile_to_each_other`: `Sides.hostile_to(CREW, HOSTILE)` and the reverse true; `CREW`/`CREW`, `HOSTILE`/`HOSTILE`, `&""`/`HOSTILE` false.
  - `test_a_ship_is_crew_until_made_hostile`: a spawned ship's `side == Sides.CREW`; set `HOSTILE`; `Weapons.is_hostile(starter, other.exterior)` true and `Weapons.is_hostile(other, starter.exterior)` true; `Weapons.is_hostile(starter, starter.exterior)` false.
  - `test_fire_control_engages_a_hostile_unmarked`: starter `ENGAGE`, nothing listed, hostile ship placed 400 m off its dorsal turret's sky; after `fire_control.assign(0.2)` some turret's `target` is the hostile's hull. Same with the other ship `CREW`: no turret has a target.
  - `test_you_are_a_target_only_to_hostiles_on_a_spacewalk`: the avatar in `Weapons.TARGETS` with id `Weapons.YOU`; `Weapons.usable(avatar)` false while `mode == PLATING`, true in `SUIT`; `Weapons.is_hostile(hostile_ship, avatar)` true; `Weapons.is_hostile(starter, avatar)` false.
  - `test_side_survives_a_save`: `to_dict(universe)["side"] == "hostile"`; a fresh spawn given `restore_aboard(d)` reads `HOSTILE`; a dict without `"side"` reads `CREW`.

- [x] **Step 2: Run them to see them fail.** `godot --headless --path . --import`, then `./run_tests.ps1 '-gselect=test_sides.gd'`. Expected: failures naming `Sides`.

- [x] **Step 3: Implement.** `Sides` as above. `Weapons.is_hostile(shooter, node)`: the stub first if valid, else `Sides.hostile_to(Sides.side_of(shooter), Sides.side_of(node))`. `Weapons.usable` returns false for an `Avatar` not in `Avatar.Mode.SUIT`. `FireControl._pick` passes `ship`. `TargetBrackets` passes the ship whose `fire_control` it draws (`fire_control.ship`). In `flight_test.gd`, `Weapons.join(_avatar, Weapons.YOU)` once the avatar exists (TargetContacts already skips the kind). Fix the two existing tests' stubs to `func(_s: Node, n: Node) -> bool`.

- [x] **Step 4: Run** `test_sides.gd`, `test_weapons.gd`, `test_fire_control.gd`, `test_weapons_hud.gd` (the brackets' tests), `test_ship_turrets.gd`. Expected: all pass.

- [x] **Step 5: Commit** `feat: ships have a side; hostile is crew against hostile`.
