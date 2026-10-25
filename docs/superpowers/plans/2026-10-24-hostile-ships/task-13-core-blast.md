# Hostile ships · Task 13: The core goes up, the blast, the chunks

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** Task 12 (merged into `hostiles` before this branch was cut). **Wave:** 7.
**Branch:** `hostiles-t13`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t13`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t13` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t13` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-13/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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

5. **Two ships destroyed in the same tick (a blast chaining into a nearly dead neighbour):** each explodes once; neither is destroyed twice or removed twice. Task 13's `test_a_chain_of_blasts_destroys_each_once`.

The test named there is part of this task; write it with the others.

## The task

**Files:**
- Create: `who-knows/src/combat/core_blast.gd`, `who-knows/src/ship/ship_breakup.gd`
- Modify: `who-knows/src/audio/synth.gd` (`&"core_boom"`), `scenes/flight_test.gd` (play them before `fleet.destroy`), `test/unit/test_visual_style_rules.gd`, `test/unit/test_floating_origin_scene.gd`
- Test: `who-knows/test/unit/test_core_blast.gd`

**Interfaces:**
- Produces:
  - `CoreBlast.RADIUS := 120.0` m, `CoreBlast.PEAK := 400.0` hp at the centre, falling linearly to 0 at `RADIUS × scale`; `scale = clampf(mass_t / 105.0, 0.5, 2.0)`; `CoreBlast.damage_at(distance: float, scale: float) -> float` (pure).
  - `CoreBlast.go(outside: Node3D, at: Vector3, scale: float, source: Node) -> void` — the flash (a big warm glow sphere, `SpacePalette.PHASER` family, growing to `20 × scale` m and gone in 1.2 s) with an `OmniLight3D` (range `300 × scale`, warm) in `EXTERIOR_SPACE`; the boom (`core_boom`) on a 3D player outside, and through the `SHIP` bus as a thump for a listener aboard a ship within 500 m; then one sphere query (`PhysicsShapeQueryParameters3D`, mask hulls `1`, NPCs `Npc.LAYER`, items `Item.LAYER`) delivering a `Hit` of kind `&"blast"` with `damage_at(d)` to each hull at its nearest point, each NPC, each loose item; and to you on a spacewalk within range (`Avatar.receive_hit`). The exploding ship is excluded (`source`).
  - `ShipBreakup.go(ship: Ship, outside: Node3D) -> void` — the ship's present blocks grouped into 6–10 large chunks (a flood-fill of the grid in seeded clusters) and 20–30 small, each a `RigidBody3D` (`collision_layer = 0`, `collision_mask = AsteroidBody.LAYER`) carrying a merged mesh of its cells from the exterior builder's look (or flat-shaded `HullPalette` boxes, scorched/charred by `ExteriorBuilder.stage_colour`), the hull's velocity plus 5–25 m/s outward from the core and a spin; in `EXTERIOR_SPACE`; freed after a random 20–60 s with a shrink over its last 2 s. A spark burst and a gas puff from the core (`DamageShow`'s burst, world-space, `HOLDS_SHIFT` for its 2 s).
  - Order in `flight_test` on `destroyed`: `CoreBlast.go` → `ShipBreakup.go` → deaths (Task 12) → `fleet.destroy` next frame. A ship destroyed by a blast in the same frame queues its own sequence; `Ship.is_destroyed()` guards against a second.

- [ ] **Step 1: Write the failing tests:**
  - `test_blast_falls_off`: `damage_at(0, 1) == 400`, `damage_at(60, 1) == 200`, `damage_at(130, 1) == 0`, `damage_at(200, 2) > 0`.
  - `test_blast_hurts_what_is_near_not_far`: scene: two other starters at 50 m and 300 m → the near one's `hull_whole() < 1`, the far one untouched; an NPC at 30 m loses health.
  - `test_a_chain_of_blasts_destroys_each_once`: a second starter at 40 m with 100 hp of hull left → it is destroyed by the first blast; each emits `destroyed` once; `fleet.destroy` called once each (spy on the signal count).
  - `test_chunks_are_outside_and_go`: after `ShipBreakup.go`, ≥ 26 bodies in `EXTERIOR_SPACE` with `collision_layer == 0`; after simulating 61 s (`await` with the time scale up, or by calling their timers), none left.
  - Visual-style and floating-origin suites gain both files and pass.
- [ ] **Step 2–4:** run (FAIL), implement, run `test_core_blast.gd`, `test_visual_style_rules.gd`, `test_floating_origin_scene.gd`, `test_ship_destroyed.gd` (pass).
- [ ] **Step 5: Render and measure:** a starter destroyed 400 m ahead of your helm: frames at 0.1, 0.4 and 2 s from the helm and from a chase view at 80 m; the fps over the 3 s after. Renders into `.superpowers/renders/task-13/`, sent to the owner. If the fps dips under 120 for more than a few frames, cut the small chunks first.
- [ ] **Step 6: Commit** `feat: the core goes up, the blast reaches what is near, the ship breaks apart`.
