# Hostile ships · Task 8: The jolt and the dip

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** Task 1 (merged into `hostiles` before this branch was cut). **Wave:** 2.
**Branch:** `hostiles-t08`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t08`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t08` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t08` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-8/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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
- Create: `who-knows/src/combat/hit_feel.gd`, `src/ship/interior/cabin_dip.gd`
- Modify: `who-knows/src/ship/ship.gd` (`felt_hit`), `src/avatar/avatar.gd` (`knock`), `src/ship/interior/light_flicker.gd` (multiply by the dip), `src/ship/interior/interior_props.gd` (register plain ceiling lamps with the ship's `CabinDip`), `src/combat/weapons_job.gd` (the gun camera's shake), `scenes/flight_test.gd` (connect the aboard ship's `felt_hit`)
- Test: `who-knows/test/unit/test_hit_feel.gd`

**Interfaces:**
- Produces:
  - `HitFeel.strength(damage: float) -> float` = `clampf(damage / WeaponValues.spec(HEAVY)["damage"], 0.1, 1.0)` (a light bolt 0.125, a heavy 1.0; crash damage the same scale).
  - `HitFeel` constants: `ROLL_MOST := 0.03` rad, `SHIFT_MOST := 0.06` m, `SETTLE := 0.25` s, `CEILING := 1.0` (summed strength the shake can hold), `DIP := {LIGHT: [0.1 s, 0.5 level], HEAVY: [0.5 s, 0.08 level with two flicks]}` as `DIP_LIGHT_TIME := 0.1`, `DIP_LIGHT_LEVEL := 0.5`, `DIP_HEAVY_TIME := 0.5`, `DIP_HEAVY_LEVEL := 0.08`.
  - `Ship.signal felt_hit(strength: float, from: Vector3)` — emitted from `_on_hull_hit` (any `Hit` with damage > 0) and `_deal_crash`, `from` the world direction the hit came from.
  - `Avatar.knock(strength: float, from: Vector3) -> void` — adds to the existing `_jolt` roll (`ROLL_MOST × strength`, away from `from`'s side) and a head offset (`SHIFT_MOST × strength`, away from `from`), both settling over `SETTLE`; the summed live strength never past `CEILING`. Steering, aim and the avatar's body are untouched (head only, as `_jolt` already is).
  - `CabinDip` (Node under the interior): `dip(strength: float)`, `factor() -> float` (1 at rest); one dip at a time — a new one replaces the running one only if stronger; `register(lamp: OmniLight3D)` captures its built energy; `_process` writes `energy × factor()` into plain lamps; `LightFlicker` multiplies its own output by `dip.factor()` when it has one. Screens and glow plinths untouched (spec §6.1). Re-registered on every interior rebuild.
  - `WeaponsJob` shakes its gun camera with `Camera3D.h_offset`/`v_offset` by the same rule while sat.

- [x] **Step 1: Write the failing tests:**
  - `test_strength_scales_with_damage`: 15 → 0.125, 120 → 1.0, 5 → 0.1, 500 → 1.0.
  - `test_a_heavy_knock_is_bigger_and_settles`: `knock(1.0, Vector3.RIGHT)` → head roll magnitude ≈ `ROLL_MOST`; `knock(0.125, ...)` ≈ an eighth; after `SETTLE` + 0.05 s both back to 0.
  - `test_a_burst_storm_is_capped`: twelve `knock(1.0)` in one frame → roll ≤ `ROLL_MOST × CEILING`.
  - `test_the_dip_dims_and_recovers`: a `CabinDip` with one registered lamp of energy 2.0; `dip(1.0)` → within 0.1 s energy ≤ `2.0 × DIP_HEAVY_LEVEL + ε`; after 0.6 s back to 2.0. `dip(0.125)` lasts ≤ 0.15 s and never below `2.0 × DIP_LIGHT_LEVEL`.
  - `test_flicker_follows_the_dip`: a `LightFlicker` with `dip` set; at its bright phase, `dip(1.0)` → lamp energy ≤ `lamp_energy × DIP_HEAVY_LEVEL`.
  - `test_a_hull_hit_is_felt_aboard`: scene: you seated in the starter, a phaser `Hit` of 120 on its hull → `felt_hit` emitted with strength 1.0, the avatar's head roll non-zero next frame, the cabin's dip factor < 1.

- [x] **Step 2–4:** run (FAIL), implement, run `test_hit_feel.gd`, `test_light_flicker.gd`, `test_avatar.gd`, `test_weapons_job.gd` (pass).
- [x] **Step 5: Render** (eye height, seated at the starter's helm, a heavy `Hit` dealt by script): a frame at the dip's deepest and one 0.6 s later, into `.superpowers/renders/task-8/`. Send them to the owner (SendUserFile) and carry on.
- [x] **Step 6: Commit** `feat: hits jolt the cabin and dip its lights, by their strength`.
