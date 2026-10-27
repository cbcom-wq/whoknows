# Hostile ships · Task 7: Spawning a hostile, brackets, the warning, F8, the readout

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** Task 6 (merged into `hostiles` before this branch was cut). **Wave:** 4.
**Branch:** `hostiles-t07`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t07`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t07` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t07` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-7/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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
- Create: `who-knows/src/ui/pilot_readout.gd`
- Modify: `who-knows/src/ui/spawn_panel.gd` (Shift + 1–9), `target_brackets.gd` (hostiles in contact, HULL %), `weapons_strip.gd` + `vehicle_telemetry.gd` (the HOLD warning), `scenes/flight_test.gd` (`spawn_hostile`, `_board_refusal`, wiring)
- Modify tests: `test_spawn_panel.gd`, `test_weapons_hud.gd`
- Test: `who-knows/test/unit/test_hostile_spawn.gd`

**Interfaces:**
- Produces:
  - `SpawnPanel.signal hostile_asked(index: int)` (Shift + 1–9); the panel lists `Shift+n  hostile` in its help line.
  - `FlightTest.spawn_hostile(id: StringName) -> String` — like `spawn_from_library` but the place is `PilotValues.SPAWN_RANGE` from you, 30° off your nose's side (alternating sides), facing you, at rest, no warp arrival (it is already there), side `HOSTILE`, `ship_pilot.skill = rng.randf_range(SPAWN_SKILL.x, SPAWN_SKILL.y)`, `style_choice = AUTO`, `engage(Weapons.ship_id(aboard))` (or `Weapons.YOU` on a spacewalk with no ship aboard). Uses `SpawnSpot`'s rock and ship clearance checks at that place (`_rock_near`, 60 m from other hulls); tries ±60° and ±90° if blocked. Returns `"HOSTILE <NAME> · SKILL 0.6 · AUTO"` or why not (the same refusals as `spawn_from_library`).
  - `TargetBrackets.hostiles: Callable` → `Array[Node3D]` of hostile hulls within `CONTACT_RANGE` of the ship you are aboard, bracketed unnumbered in `HudPalette.HOSTILE` when not listed. Each ship bracket's text gains a second line `HULL n%` (`roundi(ship.hull_whole() × 100)`).
  - `VehicleTelemetry.hostile_on_hold: bool`; `WeaponsStrip` shows `HOSTILE · WEAPONS ON HOLD` in `HudPalette.WARNING` when it is true (above the low-power line in priority).
  - `_board_refusal()` returns `"HOSTILE SHIP"` for a target with `side == HOSTILE`.
  - `PilotReadout` (Label, plain F3 style, key **F2**, `CreaturePanel.GROUP` so it shuts the others): one block per hostile in contact — name, `style`/`style_choice`, skill, preferred and actual range, `intent`, QE, `HULL %`, the last brawl score. Keys while open: `[`/`]` select a ship, `S` cycles its style choice, `-`/`=` skill ∓ 0.1, `H` flips its side (CREW ⇄ HOSTILE; making it hostile `engage`s the ship you are aboard).

- [x] **Step 1: Write the failing tests:**
  - `test_shift_number_asks_for_a_hostile` (in `test_spawn_panel.gd`): Shift+2 emits `hostile_asked(1)`, not `spawn_asked`.
  - `test_a_hostile_spawns_three_km_off_facing_you`: `spawn_hostile(&"starter")` → a new ship, `side == HOSTILE`, distance 3000 ± 50 m, `(-hull.basis.z).dot(to_you) > 0.95`, `ship_pilot.on`, skill in 0.2..0.8, objective target `ship:Ship`.
  - `test_brackets_show_an_unlisted_hostile_with_its_hull`: after a render, `marks` has an entry with `hostile` true and text containing `HULL 100%`.
  - `test_hold_with_a_hostile_warns`: orders `HOLD`, a hostile engaging → `WeaponsStrip.orders_text() == "HOSTILE · WEAPONS ON HOLD"`.
  - `test_f8_refuses_a_hostile`: nearest ship hostile → `board_nearest()` false and the toast `HOSTILE SHIP`.

- [x] **Step 2–4:** run (FAIL), implement, run `test_hostile_spawn.gd`, `test_spawn_panel.gd`, `test_weapons_hud.gd` (pass).
- [x] **Step 5: Play it once** (windowed: `godot --path who-knows`): F6, Shift+1, watch the starter come at you; F2 shows it. Note anything wrong for Task 16; do not tune yet.
- [x] **Step 6: Commit** `feat: Shift+F6 brings a hostile; its bracket, its hull, and the HOLD warning`.
