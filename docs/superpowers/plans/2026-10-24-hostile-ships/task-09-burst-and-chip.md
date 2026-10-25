# Hostile ships · Task 9: The bright burst, and heavy hits chip pieces off

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** Task 8, Task 10 (merged into `hostiles` before this branch was cut). **Wave:** 4.
**Branch:** `hostiles-t09`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t09`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t09` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t09` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-9/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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
- Modify: `who-knows/src/items/impact_flash.gd` (`bright`), `src/combat/weapon_values.gd` (`flash_bright`), `src/combat/bolt.gd:90`, `src/ship/ship_damage.gd` (`chip`, `chipped`), `src/ship/ship.gd` (`_on_hull_hit`)
- Test: `who-knows/test/unit/test_hit_chip.gd`

**Interfaces:**
- Produces:
  - `ImpactFlash.spawn(..., grow_by := 1.0, bright := 1.0)`; `LIGHT_ENERGY × bright`, `DURATION` × `(1 + 0.5 × (bright − 1))` capped at 2×. `WeaponValues.SPECS[*]["flash_bright"]`: light 3.0, heavy 6.0 (starting points: it must read at 1 km from the helm, §6.2; Task 16's renders judge it).
  - `HitFeel.CHIP_FROM := 100.0` (a single hit's damage from which it may knock a piece off).
  - `ShipDamage.chip(coord: Vector3i, side_x := 0.0) -> bool` — the hit's section gets one more lost piece than its health says (`chipped[section] += 1`, up to its piece count); true if that changed `lost()`. `lost_count(section)` becomes `min(pieces.size(), health_count + chipped[section])`. `repair_section` clears that section's `chipped` once its health reaches `BREAK_BELOW` or above (the torch's rebuild puts pieces back in reverse order as now). Saved in `to_dict()["chipped"]`; read in `from_dict`.
  - `Ship._on_hull_hit`: after the damage, `if hit.damage >= HitFeel.CHIP_FROM: damage.chip(cell, side_x)` and `_apply_view()` (one rebuild).

- [ ] **Step 1: Write the failing tests:**
  - `test_a_heavy_hit_chips_a_whole_section`: a full-health starter, `Hit` of 120 on a bow plate → one piece of that section lost; `health(section) > 0.9`.
  - `test_a_light_hit_never_chips`: 15 hp → nothing lost.
  - `test_chips_come_back_with_the_torch`: chip twice, `repair_section(section, 0.2)` until health ≥ 0.5 → `lost()` empty.
  - `test_chipped_round_trips`: `to_dict`/`from_dict` keeps it.
  - `test_the_flash_is_brighter_for_a_heavy`: `ImpactFlash.spawn(..., 3.0, 6.0)` → its light's energy at spawn = `LIGHT_ENERGY × 6.0`.
- [ ] **Step 2–4:** run (FAIL), implement, run `test_hit_chip.gd`, `test_ship_damage_model.gd`, `test_ship_damage.gd`, `test_phaser_bolt.gd` (pass).
- [ ] **Step 5: Commit** `feat: brighter bursts; a heavy hit can knock a plate off a whole section`.
