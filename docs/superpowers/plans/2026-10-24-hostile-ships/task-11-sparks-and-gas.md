# Hostile ships · Task 11: Sparks by damage, and gas vents

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** Task 9 (merged into `hostiles` before this branch was cut). **Wave:** 5.
**Branch:** `hostiles-t11`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t11`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t11` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t11` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-11/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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
- Create: `who-knows/src/ship/gas_vents.gd`
- Modify: `who-knows/src/ship/damage_show.gd` (spit rate by share), `src/ship/ship.gd` (feed shares and vents from `_apply_view`), `src/world/space_palette.gd` (`VENT_GAS`), `test/unit/test_visual_style_rules.gd` (painting files), `test/unit/test_floating_origin_scene.gd` (gas is local to the hull)
- Test: `who-knows/test/unit/test_gas_vents.gd`

**Interfaces:**
- Produces:
  - `DamageShow.share(coord: Vector3i, share: float) -> void` — a damaged block's spit interval is `lerp(SPIT_EVERY, SPIT_EVERY_WORST, (share − 0.25) / 0.75)` with `SPIT_EVERY_WORST := Vector2(0.05, 0.2)`; under 0.25 as today.
  - `GasVents.VENT_BELOW := 0.5`, `GasVents.MOST_PER_SECTION := 4`, `GasVents.vents(damage: ShipDamage, grid: ShipGrid) -> Array[Dictionary]` (pure: per section under `VENT_BELOW`, `ceili(lerp(1, MOST_PER_SECTION, (VENT_BELOW − h) / VENT_BELOW))` of its most exposed present blocks with a face onto space, each `{coord, normal: Vector3i, strength: 0..1}`).
  - `GasVents` (Node3D on the hull): `sync(list)` makes or retunes one `GPUParticles3D` per vent, `local_coords = true` (rides the hull; never holds the shift), chunky puffs like the airlock's steam (built-in `ParticleProcessMaterial`, sphere-ish low-poly mesh, `SpacePalette.VENT_GAS`, a pale warm grey), amount and speed by strength; removes vents no longer listed.
  - `SpacePalette.VENT_GAS: Color` (new; the owner sees it in the renders).

- [x] **Step 1: Write the failing tests:**
  - `test_no_vents_above_half`: every section at 60% → `vents()` empty.
  - `test_vents_grow_as_a_section_falls`: a section at 45% → 1 vent; at 5% → 4; each has a face onto space.
  - `test_vents_ride_the_hull`: scene: a vented starter, `GasVents` emitters `local_coords` true, children of the hull; after `Universe.shift`, their positions relative to the hull unchanged; not in `HOLDS_SHIFT`.
  - `test_sparks_quicken_with_damage`: `DamageShow.share(coord, 1.0)` → that block's next spit within `SPIT_EVERY_WORST.y`.
  - Visual-style and floating-origin suites gain `gas_vents.gd` and pass.
- [x] **Step 2–4:** run (FAIL), implement, run `test_gas_vents.gd`, `test_block_damage.gd`, `test_visual_style_rules.gd`, `test_floating_origin_scene.gd` (pass).
- [x] **Step 5: Measure and render:** a starter at 10% HULL venting from all six sections; chase view at 30 m and from a second starter's helm at 200 m; fps over 10 s each (`Engine.get_frames_per_second`) on the dev GPU. Must hold 120; if not, fewer, smaller puffs. Renders to `.superpowers/renders/task-11/`, sent to the owner.
- [x] **Step 6: Commit** `feat: a damaged hull sparks harder and vents gas`.
