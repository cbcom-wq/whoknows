# Hostile ships · Task 4: Facing, steering and bolts inbound

> **For agentic workers:** this is one task of the hostile ships plan, run in a session of its own. Use superpowers:executing-plans for its steps and superpowers:test-driven-development for each test-first step. Steps use checkbox (`- [ ]`) syntax.

**Whole plan:** `docs/superpowers/plans/2026-10-24-hostile-ships.md` (read its *File map*, and the *Interfaces* of the tasks this one depends on, to know the names they produced).
**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read the sections this task names.
**Depends on:** none (merged into `hostiles` before this branch was cut). **Wave:** 1.
**Branch:** `hostiles-t04`, cut from `hostiles`.
**Worktree:** `D:\git\whoknows-hostiles-t04`. Work only there: in PowerShell `Set-Location D:\git\whoknows-hostiles-t04` first, then plain `git` (never `git -C`). Never edit `D:\git\whoknows` (it stays on `main`), `D:\git\whoknows-hostiles`, or another task's worktree. Run `godot --headless --path who-knows --import` once before the first test: the worktree's `.godot` cache starts empty.

## Session rules

- Touch only the files this task lists (and the tests it names). Other tasks run at the same time in other worktrees; a file outside your list is someone else's.
- If the code differs from what this plan or the plan's *Interfaces* say (a name, a signature, a line number), follow the code, keep the plan's intent, and say so in your report.
- **Targeted tests only:** the files this task names. Never the full suite.
- Commit on `hostiles-t04` as the steps say. **Never merge, rebase onto, or push** any branch: the owner merges.
- Renders and probe output go under `.superpowers/renders/task-4/` in your worktree (git-ignored); send them to the owner with SendUserFile when a step says so.
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
- Create: `who-knows/src/pilot/broadside.gd`, `rock_avoid.gd`
- Modify: `who-knows/src/combat/bolt_pool.gd` (`flying()`)
- Test: `who-knows/test/unit/test_pilot_steering.gd`

**Interfaces:**
- Produces:
  - `Broadside.SAMPLES: Array[Vector3]` — the 26 unit directions of a cube's faces, edges and corners.
  - `Broadside.best_face(skies: Array, live: Array) -> Vector3` — the hull-local sample along which the most turrets whose `live[i]` is true can bear (`skies[i].can_bear(dir)`), ties to the one nearest `Vector3.FORWARD` (−z); `Vector3.FORWARD` when there are no turrets.
  - `Broadside.desired_basis(current: Basis, face_local: Vector3, to_target: Vector3) -> Basis` — `current` turned by the shortest arc that puts `current * face_local` along `to_target`.
  - `Broadside.rotate_input(current: Basis, desired: Basis, spin_local: Vector3, gain: float) -> Vector3` — stick and roll in −1..1: the rotation error as an axis-angle in hull axes, times `gain`, minus a damping of `spin_local`, divided by `FlightComputer.ASSIST_TURN_RATE`, clamped. Axis order matches `set_pilot_input`'s `rotate` (x pitch, y yaw, z roll; check `PilotControls._process` for signs and match them).
  - `RockAvoid.LOOK_AHEAD := 8.0` (s), `RockAvoid.CLEARANCE := 80.0` (m past the hull's `AsteroidStream.ANCHOR_RADIUS` meta), `RockAvoid.FEELERS := 4` (rays at 20° off the velocity).
  - `RockAvoid.steer(space: PhysicsDirectSpaceState3D, from: Vector3, velocity: Vector3, radius: float, exclude: Array[RID]) -> Vector3` — a world velocity change away from the nearest rock hit (mask `AsteroidBody.LAYER`) within `max(velocity.length() × LOOK_AHEAD, CLEARANCE)`, zero when clear. Away = the hit's normal's part perpendicular to the velocity, scaled up the nearer it is.
  - `BoltPool.flying() -> Array[PhaserBolt]` — bolts armed and not yet landed or fading. `PhaserBolt` exposes `source: Node`, `direction`, `carrier`, `speed()` (from its spec) for the watcher.
  - `Broadside.inbound(bolts: Array, own_ship: Node, at: Vector3, own_v: Vector3, miss: float, horizon: float) -> int` — how many bolts not from `own_ship` pass within `miss` (25 m) of `at` within `horizon` (3 s), relative motion.

- [x] **Step 1: Write the failing tests:**
  - `test_best_face_on_a_starter_is_up_or_down`: build the starter's turrets' sky maps (`SkyMap.build(layout, coord, normal)` for its two turrets) → best face has `abs(y) > 0.5` and both bear on it.
  - `test_a_wrecked_turret_does_not_count`: same, with the dorsal not live → the face is one only the ventral bears on.
  - `test_desired_basis_aims_the_face`: random `current`, `face_local = Vector3.UP`, `to_target = Vector3.RIGHT` → `(desired * Vector3.UP).dot(Vector3.RIGHT) > 0.999`.
  - `test_rotate_input_turns_toward_and_settles`: integrate a toy rigid rotation (rate = input × `ASSIST_TURN_RATE`, first-order lag 0.25 s) for 10 s from a 120° error → within 2°, never more than 10° of overshoot.
  - `test_rock_avoid_steers_round_a_rock`: a `StaticBody3D` sphere (radius 50) on layer `AsteroidBody.LAYER` 400 m ahead of a body moving at 60 m/s → `steer` returns a vector with length > 0 perpendicular-ish (`abs(dot(normalized, velocity.normalized())) < 0.3`); the same with the rock 40 m off the path's side beyond clearance → zero.
  - `test_inbound_counts_only_bolts_that_pass_close`: three fake bolt dicts/objects (one aimed at you, one wide by 200 m, one from your own ship) → 1.

- [x] **Step 2: Run** `./run_tests.ps1 '-gselect=test_pilot_steering.gd'`. Expected: FAIL.
- [x] **Step 3: Implement** both files and `BoltPool.flying()`. `inbound` takes duck-typed bolts (`global_position`, `direction`, `carrier`, `speed()`, `source`) so tests can pass stubs.
- [x] **Step 4: Run** it and `test_phaser_bolt.gd`. Expected: pass.
- [x] **Step 5: Commit** `feat: a pilot knows which face to show, what to steer round, and what is coming`.
