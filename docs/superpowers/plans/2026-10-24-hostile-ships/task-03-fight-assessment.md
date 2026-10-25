# Hostile ships · Task 3: Pilot numbers, skill and the fight's reading

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** none (merged into `hostiles` before this branch was cut). **Wave:** 1.
**Branch:** `hostiles-t03`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t03`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t03` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t03` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-3/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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
- Create: `who-knows/src/pilot/pilot_values.gd`, `pilot_skill.gd`, `fight_assessment.gd`
- Test: `who-knows/test/unit/test_fight_assessment.gd`

**Interfaces:**
- Produces:
  - `PilotValues` constants: `ASSESS_EVERY := 1.0`, `TACTICS_EVERY := 0.2`, `PURSUE_FOR := 60.0`, `BRAWL_RANGE := 350.0`, `BRAWL_BAND := 150.0`, `STAND_OFF_SHARE := 0.9` (of its own longest live turret range), `STAND_OFF_BAND := 150.0`, `SWITCH_MARGIN := 0.15` (hysteresis on the brawl score), `NOISE_AT_ZERO := 0.5` (judgement noise at skill 0), `HOLD_FIRE_QE := 0.5` (store share above which even a disciplined pilot fires at long range), `COMPUTER_DAMAGED_SKILL := 0.5` (multiplier), `SPAWN_RANGE := 3000.0`, `SPAWN_SKILL := Vector2(0.2, 0.8)`, `YOUR_SKILL := 0.5`, `ENGAGED_CALM := 10.0`.
  - `PilotSkill.new(skill: float)` with `reaction: float` (s, `lerp(1.0, 0.2, s)`), `jink_share: float` (of lateral budget, `lerp(0.4, 1.0, s)`), `jink_every: float` (s, `lerp(2.5, 0.8, s)`), `position_gain: float` (`lerp(0.4, 1.0, s)`), `noise: float` (`lerp(NOISE_AT_ZERO, 0.0, s)`), `hold_fire_past: float` (share of reach, `lerp(1.0, 0.75, s)`).
  - `FightAssessment.read(ship: Ship) -> Dictionary` with keys `dps` (hp/s of its live turrets: each `damage × burst / (burst × gap + recharge)` from `WeaponValues.spec`, halved recharge rate if damaged), `reach` (longest `range` of a live turret, 0 if none), `hull` (sum of section hp × `hull_whole()`), `whole`, `accel` (forward thrust budget / mass, m/s²), `qe`, `qe_max`, `burn` (QE/s at full fire). Pure given a `Ship`; `read_dict` variants for tests are fine.
  - `FightAssessment.brawl_score(own: Dictionary, foe: Dictionary) -> float` = `(own.dps / max(foe.dps, 1)) × (own.hull / max(foe.hull, 1))`.
  - `FightAssessment.choose(own, foe, skill: float, current: int, rng: RandomNumberGenerator) -> int` returning a `ShipPilot.Style` value (`STAND_OFF` or `BRAWLER`; define the enum in Task 6's `ShipPilot`, so in this task use the ints `1` and `2` through `const STAND_OFF := 1, BRAWLER := 2` mirrored there).
  - `FightAssessment.preferred_range(style: int, own: Dictionary, foe: Dictionary) -> float`.

Rules (the spec's §5.3, made exact): the score is scaled by `1 + rng.randf_range(-noise, noise)`. **Stand-off** when `own.reach > foe.reach + 100` (it can hit from where it cannot be hit), or the score is below 1; **brawler** otherwise. From brawler it needs the score under `1 − SWITCH_MARGIN` to switch, from stand-off over `1 + SWITCH_MARGIN`. A brawler whose `qe < 0.25 × qe_max` while the foe's is above it goes stand-off. Preferred range: brawler `BRAWL_RANGE`; stand-off `STAND_OFF_SHARE × own.reach`, but past `foe.reach + 50` when its reach allows. A ship with no live turret is stand-off at `foe.reach + 300` (it keeps away).

- [x] **Step 1: Write the failing tests** (dicts, no scene):
  - `test_the_stronger_up_close_brawls`: own dps 60 hull 12000, foe dps 30 hull 12000, equal reach → `BRAWLER` at skill 1.
  - `test_the_longer_reach_stands_off`: own reach 1500, foe 1200 → `STAND_OFF`, preferred range 1350 (`0.9 × 1500`) ≥ `foe.reach + 50`.
  - `test_a_losing_brawler_stands_off`: current `BRAWLER`, score 0.8 → `STAND_OFF`; score 0.9 → stays `BRAWLER` (hysteresis).
  - `test_running_dry_stands_off`: brawler with `qe` 200 of 1200 against a foe at 900 → `STAND_OFF`.
  - `test_a_novice_misjudges_sometimes`: score 1.2, skill 0, 200 seeded rolls → both styles appear; skill 1 → always `BRAWLER`.
  - `test_reading_a_starter`: scene-based: the starter reads `dps` 60 (two lights: 15 × 4 / (4 × 0.125 + 1.5)), `reach` 1200, `whole` 1.0, `hull` ≈ 12,410 (±50).
  - `test_skill_knobs_span_their_ends`: `PilotSkill.new(0).reaction == 1.0`, `PilotSkill.new(1).reaction == 0.2`, etc.

- [x] **Step 2: Run** `./run_tests.ps1 '-gselect=test_fight_assessment.gd'` (after `--import`). Expected: FAIL.
- [x] **Step 3: Implement** the three files.
- [x] **Step 4: Run** it. Expected: pass.
- [x] **Step 5: Commit** `feat: a pilot reads the fight and picks a style`.
