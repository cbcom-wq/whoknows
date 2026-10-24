# Hostile Ships Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ships get a side; a `ShipPilot` on each ship's computer flies it through the flight computer and runs its fire control to destroy a target; hits jolt the cabin, dip its lights and burst bright on the hull; damaged hulls spark and vent gas; a ship at 0% HULL explodes and breaks apart, and if you were aboard the game goes back to the last save; you can hand your own ship to its pilot.

**Architecture:** A new `src/pilot/` holds the pilot in layers that are each pure or nearly so: `FightAssessment` (which style, what range), `Broadside` and `RockAvoid` (which way to face, what to steer round), `PilotObjective`/`DestroyObjective` (what it is trying to do, pursuit), and `ShipPilot`, the node that ties them together and drives the ship *only* through `FlightComputer.set_pilot_input` plus a new assist feature, `hold_velocity`, and through `FireControl`. Sides are a `StringName` on `Ship`, read by `Weapons.is_hostile(shooter, node)`. Hit feel hangs off a new `Ship.felt_hit` signal; destruction off a new `Ship.destroyed` signal that `Fleet.destroy` and the flight scene answer.

**Tech Stack:** Godot 4.5.1 GDScript, GUT 9.5.

**Spec:** `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (approved 2026-10-24). Read it with this plan; § numbers below are the spec's.

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
- **Worktree:** `D:\git\whoknows-hostiles`, branch `hostiles` (from `main` at `1a58d32`). PowerShell: `Set-Location D:\git\whoknows-hostiles` then plain `git`; never `git -C`. Run `godot --headless --path who-knows --import` once before the first test (the tree's `.godot` cache starts empty).
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; commit every new script's `.uid` with it.
- **Skills:** `building-a-ship`, `designing-a-ship` and `building-an-npc` are updated in this branch (Task 17).

## Review Focus

1. **The pilot's target is freed mid-fight** (destroyed, removed by F6 Delete, gone to sleep): no error from a freed node, the objective retargets or holds station, fire control's entry leaves. Task 5's `test_a_freed_target_is_let_go`.
2. **You board another ship, or step out on a spacewalk, mid-fight:** the hostile's Destroy keeps your *ship* as its target (it does not jump to you unless your ship is gone); the save gate still sees you as engaged while any hostile targets a ship you are aboard or you. Task 14's `test_engaged_follows_you_between_ships`.
3. **A save loaded with a hostile asleep far off and a destroyed starter:** the hostile comes back hostile with its pilot settings; the starter stays destroyed, hidden and out of physics, and nothing iterating `fleet.ships()` breaks. Task 12's `test_a_destroyed_starter_survives_a_save`.
4. **Taking the stick while your pilot holds a velocity:** the hold is released the same tick, so the ship does not keep fighting your input. Task 15's `test_stick_releases_the_held_velocity`.
5. **Two ships destroyed in the same tick (a blast chaining into a nearly dead neighbour):** each explodes once; neither is destroyed twice or removed twice. Task 13's `test_a_chain_of_blasts_destroys_each_once`.

---

## File map

| File | Task | What |
|---|---|---|
| `who-knows/src/combat/sides.gd` (new); `src/combat/weapons.gd`, `fire_control.gd`; `src/ship/ship.gd`; `src/avatar/avatar.gd`; `scenes/flight_test.gd` | 1 | sides, `is_hostile(shooter, node)`, you as a target |
| `who-knows/src/flight/flight_computer.gd` | 2 | `hold_velocity` |
| `who-knows/src/pilot/pilot_values.gd`, `pilot_skill.gd`, `fight_assessment.gd` (new) | 3 | numbers, skill knobs, reading a fight |
| `who-knows/src/pilot/broadside.gd`, `rock_avoid.gd` (new); `src/combat/bolt_pool.gd` | 4 | facing, steering, bolts inbound |
| `who-knows/src/pilot/pilot_objective.gd`, `destroy_objective.gd` (new) | 5 | Destroy, pursuit |
| `who-knows/src/pilot/ship_pilot.gd` (new); `src/ship/ship.gd`; `src/flight/pilot_controls.gd` | 6 | the pilot on every ship |
| `who-knows/src/ui/spawn_panel.gd`, `target_brackets.gd`, `weapons_strip.gd`, `vehicle_telemetry.gd`, `pilot_readout.gd` (new); `scenes/flight_test.gd` | 7 | spawning a hostile, brackets, warning, F8, the readout |
| `who-knows/src/combat/hit_feel.gd` (new); `src/ship/interior/cabin_dip.gd` (new), `light_flicker.gd`, `interior_props.gd`; `src/avatar/avatar.gd`; `src/combat/weapons_job.gd`; `src/ship/ship.gd`; `scenes/flight_test.gd` | 8 | the jolt and the dip |
| `who-knows/src/items/impact_flash.gd`; `src/combat/weapon_values.gd`, `bolt.gd`; `src/ship/ship_damage.gd`, `ship.gd` | 9 | the bright burst, heavy hits chip pieces |
| `who-knows/src/ship/ship_damage.gd` | 10 | spill-over |
| `who-knows/src/ship/damage_show.gd`, `gas_vents.gd` (new), `ship.gd`; `src/world/space_palette.gd` | 11 | sparks by damage, gas |
| `who-knows/src/ship/ship.gd`, `fleet.gd`; `scenes/flight_test.gd` | 12 | destroyed, removed, saved |
| `who-knows/src/combat/core_blast.gd`, `src/ship/ship_breakup.gd` (new); `src/audio/synth.gd` | 13 | the explosion, the blast, the chunks |
| `who-knows/src/ui/lost_screen.gd` (new); `scenes/flight_test.gd` | 14 | SHIP LOST, the reload, no save under attack |
| `who-knows/project.godot`; `src/flight/pilot_controls.gd`; `src/pilot/ship_pilot.gd`; `src/ship/computer/pilot_page.gd` (new), `ship_computer.gd`, `computer_context.gd`; `src/combat/weapons_job.gd`; `src/ui/` HUD | 15 | your ship's pilot |
| `who-knows/test/probes/duel_probe.gd` (new) | 16 | proof, tuning, renders |
| `.claude/skills/building-a-ship/*`, `designing-a-ship/*`, `building-an-npc/*`; the spec | 17 | upkeep, as built |

Tests are all new files under `who-knows/test/unit/` unless named as existing.

---

## Phase 1: sides and a pilot that fights

### Task 1: Sides

**Files:**
- Create: `who-knows/src/combat/sides.gd`
- Modify: `who-knows/src/combat/weapons.gd`, `fire_control.gd:154`, `src/ui/target_brackets.gd:37`, `src/ship/ship.gd` (`side`, saving), `src/avatar/avatar.gd` (nothing but the target join, see below), `scenes/flight_test.gd` (join you to `Weapons.TARGETS`, restore `side`)
- Modify tests: `test/unit/test_weapons.gd:13,55-57`, `test/unit/test_fire_control.gd:32,96` (the stub now takes `(shooter, node)`)
- Test: `who-knows/test/unit/test_sides.gd`

**Interfaces:**
- Produces: `Sides.CREW`, `Sides.HOSTILE`; `Sides.hostile_to(a: StringName, b: StringName) -> bool`; `Sides.side_of(node: Node) -> StringName` (a hull's ship's `side`, a `Ship`'s own, `CREW` for the `Avatar`, `&""` otherwise); `Ship.side: StringName = Sides.CREW` (saved as `"side"` in `Ship.to_dict`, read in `restore_aboard`); `Weapons.YOU := &"you"`; `Weapons.is_hostile(shooter: Node, node: Node) -> bool`; `Weapons.hostile_rule` is now called as `hostile_rule.call(shooter, node)`.

- [ ] **Step 1: Write the failing tests** in `test_sides.gd` (scene-based like `test_ship_turrets.gd`: instance `res://scenes/flight_test.tscn`, take `/Ship`, `fleet.spawn` a second starter grid):
  - `test_crew_and_hostile_are_hostile_to_each_other`: `Sides.hostile_to(CREW, HOSTILE)` and the reverse true; `CREW`/`CREW`, `HOSTILE`/`HOSTILE`, `&""`/`HOSTILE` false.
  - `test_a_ship_is_crew_until_made_hostile`: a spawned ship's `side == Sides.CREW`; set `HOSTILE`; `Weapons.is_hostile(starter, other.exterior)` true and `Weapons.is_hostile(other, starter.exterior)` true; `Weapons.is_hostile(starter, starter.exterior)` false.
  - `test_fire_control_engages_a_hostile_unmarked`: starter `ENGAGE`, nothing listed, hostile ship placed 400 m off its dorsal turret's sky; after `fire_control.assign(0.2)` some turret's `target` is the hostile's hull. Same with the other ship `CREW`: no turret has a target.
  - `test_you_are_a_target_only_to_hostiles_on_a_spacewalk`: the avatar in `Weapons.TARGETS` with id `Weapons.YOU`; `Weapons.usable(avatar)` false while `mode == PLATING`, true in `SUIT`; `Weapons.is_hostile(hostile_ship, avatar)` true; `Weapons.is_hostile(starter, avatar)` false.
  - `test_side_survives_a_save`: `to_dict(universe)["side"] == "hostile"`; a fresh spawn given `restore_aboard(d)` reads `HOSTILE`; a dict without `"side"` reads `CREW`.

- [ ] **Step 2: Run them to see them fail.** `godot --headless --path . --import`, then `./run_tests.ps1 '-gselect=test_sides.gd'`. Expected: failures naming `Sides`.

- [ ] **Step 3: Implement.** `Sides` as above. `Weapons.is_hostile(shooter, node)`: the stub first if valid, else `Sides.hostile_to(Sides.side_of(shooter), Sides.side_of(node))`. `Weapons.usable` returns false for an `Avatar` not in `Avatar.Mode.SUIT`. `FireControl._pick` passes `ship`. `TargetBrackets` passes the ship whose `fire_control` it draws (`fire_control.ship`). In `flight_test.gd`, `Weapons.join(_avatar, Weapons.YOU)` once the avatar exists (TargetContacts already skips the kind). Fix the two existing tests' stubs to `func(_s: Node, n: Node) -> bool`.

- [ ] **Step 4: Run** `test_sides.gd`, `test_weapons.gd`, `test_fire_control.gd`, `test_weapons_hud.gd` (the brackets' tests), `test_ship_turrets.gd`. Expected: all pass.

- [ ] **Step 5: Commit** `feat: ships have a side; hostile is crew against hostile`.

### Task 2: The flight computer holds a velocity

**Files:**
- Modify: `who-knows/src/flight/flight_computer.gd` (`translation_force`, new API)
- Test: `who-knows/test/unit/test_velocity_hold.gd`

**Interfaces:**
- Produces: `FlightComputer.hold_velocity(v_world: Vector3) -> void`; `release_velocity() -> void`; `velocity_hold: bool`; `held_velocity: Vector3` (world, m/s). `translation_force(local_velocity, input, mass, budget, boost, assist, locked, locked_speed, held: Variant = null)` — `held` is the hold's target in hull axes or null.

The assist already cancels "velocity nobody asked for" on every axis without input, toward 0 (or the locked speed fore and aft). The hold changes only what it cancels *toward*: on an axis with no input, toward `held`'s component instead. Same budgets, same `DRIFT_AUTHORITY`, same speed limit: a pilot with a hold flies no better than the assist. Needs assist; turning assist off, or the assist refused, drops it (as it drops the speed lock). Not saved (the pilot re-asks every tactics tick).

- [ ] **Step 1: Write the failing tests:**
  - `test_without_a_hold_nothing_changes`: `translation_force(Vector3(3, 0, -5), Vector3.ZERO, 1000, budget, false, true, false, 0.0)` equals the same call with `held = null` and equals today's expected `(-3000, 0, 5000)` clamped by budget.
  - `test_a_hold_pulls_each_quiet_axis_toward_it`: `held = Vector3(10, 0, -20)`, velocity `Vector3(0, 0, -20)`, no input → force x > 0, z ≈ 0, y ≈ 0.
  - `test_input_on_an_axis_wins_over_the_hold`: input `x = -1` with the same hold → force x == `-lateral`.
  - `test_the_hold_needs_assist`: `hold_velocity(v)` with assist off leaves `velocity_hold` false; turning assist off drops a hold.
  - `test_the_hold_obeys_the_speed_limit`: a hold of 10× `CRUISE_LIMIT_MPS` on a simulated hull is clamped by the existing limit after a physics tick (use the existing test's hull fixture from `test_flight_computer.gd`).

- [ ] **Step 2: Run** `./run_tests.ps1 '-gselect=test_velocity_hold.gd'`. Expected: FAIL (no `hold_velocity`).

- [ ] **Step 3: Implement** the API and the `held` parameter. In `_apply_translation`, pass `basis.inverse() * held_velocity` when `velocity_hold`, else null. A hold set replaces the speed lock's fore-and-aft target while it lasts; `speed_locked` itself is left as it was (the pilot never touches it).

- [ ] **Step 4: Run** `test_velocity_hold.gd` and `test_flight_computer.gd`. Expected: pass.

- [ ] **Step 5: Commit** `feat: the assist can hold a velocity, for a pilot that is not you`.

### Task 3: Pilot numbers, skill and the fight's reading

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

- [ ] **Step 1: Write the failing tests** (dicts, no scene):
  - `test_the_stronger_up_close_brawls`: own dps 60 hull 12000, foe dps 30 hull 12000, equal reach → `BRAWLER` at skill 1.
  - `test_the_longer_reach_stands_off`: own reach 1500, foe 1200 → `STAND_OFF`, preferred range 1350 (`0.9 × 1500`) ≥ `foe.reach + 50`.
  - `test_a_losing_brawler_stands_off`: current `BRAWLER`, score 0.8 → `STAND_OFF`; score 0.9 → stays `BRAWLER` (hysteresis).
  - `test_running_dry_stands_off`: brawler with `qe` 200 of 1200 against a foe at 900 → `STAND_OFF`.
  - `test_a_novice_misjudges_sometimes`: score 1.2, skill 0, 200 seeded rolls → both styles appear; skill 1 → always `BRAWLER`.
  - `test_reading_a_starter`: scene-based: the starter reads `dps` 60 (two lights: 15 × 4 / (4 × 0.125 + 1.5)), `reach` 1200, `whole` 1.0, `hull` ≈ 12,410 (±50).
  - `test_skill_knobs_span_their_ends`: `PilotSkill.new(0).reaction == 1.0`, `PilotSkill.new(1).reaction == 0.2`, etc.

- [ ] **Step 2: Run** `./run_tests.ps1 '-gselect=test_fight_assessment.gd'` (after `--import`). Expected: FAIL.
- [ ] **Step 3: Implement** the three files.
- [ ] **Step 4: Run** it. Expected: pass.
- [ ] **Step 5: Commit** `feat: a pilot reads the fight and picks a style`.

### Task 4: Facing, steering and bolts inbound

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

- [ ] **Step 1: Write the failing tests:**
  - `test_best_face_on_a_starter_is_up_or_down`: build the starter's turrets' sky maps (`SkyMap.build(layout, coord, normal)` for its two turrets) → best face has `abs(y) > 0.5` and both bear on it.
  - `test_a_wrecked_turret_does_not_count`: same, with the dorsal not live → the face is one only the ventral bears on.
  - `test_desired_basis_aims_the_face`: random `current`, `face_local = Vector3.UP`, `to_target = Vector3.RIGHT` → `(desired * Vector3.UP).dot(Vector3.RIGHT) > 0.999`.
  - `test_rotate_input_turns_toward_and_settles`: integrate a toy rigid rotation (rate = input × `ASSIST_TURN_RATE`, first-order lag 0.25 s) for 10 s from a 120° error → within 2°, never more than 10° of overshoot.
  - `test_rock_avoid_steers_round_a_rock`: a `StaticBody3D` sphere (radius 50) on layer `AsteroidBody.LAYER` 400 m ahead of a body moving at 60 m/s → `steer` returns a vector with length > 0 perpendicular-ish (`abs(dot(normalized, velocity.normalized())) < 0.3`); the same with the rock 40 m off the path's side beyond clearance → zero.
  - `test_inbound_counts_only_bolts_that_pass_close`: three fake bolt dicts/objects (one aimed at you, one wide by 200 m, one from your own ship) → 1.

- [ ] **Step 2: Run** `./run_tests.ps1 '-gselect=test_pilot_steering.gd'`. Expected: FAIL.
- [ ] **Step 3: Implement** both files and `BoltPool.flying()`. `inbound` takes duck-typed bolts (`global_position`, `direction`, `carrier`, `speed()`, `source`) so tests can pass stubs.
- [ ] **Step 4: Run** it and `test_phaser_bolt.gd`. Expected: pass.
- [ ] **Step 5: Commit** `feat: a pilot knows which face to show, what to steer round, and what is coming`.

### Task 5: The objective, and pursuit

**Files:**
- Create: `who-knows/src/pilot/pilot_objective.gd`, `destroy_objective.gd`
- Test: `who-knows/test/unit/test_destroy_objective.gd`

**Interfaces:**
- Produces:
  - `PilotObjective` (RefCounted, base): `target_id() -> StringName`, `target(tree: SceneTree, from: Vector3) -> Node3D` (via `Weapons.find`, null if gone or past `CONTACT_RANGE` of `from`), `step(from: Vector3, tree: SceneTree, delta: float) -> void`, `done() -> bool`, `pursuing() -> bool`, `last_seen() -> Dictionary` (`{dir: Vector3, speed: Vector3, at: UniversePoint}` or `{}`), `to_dict()`, `static from_dict(d) -> PilotObjective`.
  - `DestroyObjective.new(id: StringName)`: in contact → fighting, remembers `dir` (world direction from `from` to the target), its velocity, and its `UniversePoint` (the pilot passes a `Universe` or a callable `to_universe`); out of contact → `pursuing()` true and a clock runs; back in contact → clock reset; after `PilotValues.PURSUE_FOR` → `done()` true. Target **destroyed or freed** (not found and not merely out of range: `Weapons.find` null *and* no node with that id in the tree) → `retarget` to the nearest `CREW` ship in contact (`Weapons.TARGETS`, kind `ship`, `Sides.side_of == CREW`), else `done()`.
  - `DestroyObjective.retarget(tree, from) -> bool`.

- [ ] **Step 1: Write the failing tests** (nodes in `Weapons.TARGETS` with ids, positions set; `from` given):
  - `test_fights_while_in_contact`: target at 2 km → `pursuing()` false, `done()` false, `last_seen().dir` toward it.
  - `test_pursues_out_of_contact_then_gives_up`: target moved to 6 km → `pursuing()` true; `step` 59 s → not done; 61 s → `done()`.
  - `test_contact_again_resets_the_clock`: out 50 s, back in 1 s, out 50 s → not done.
  - `test_a_freed_target_is_let_go`: free the target node → next `step` retargets to another `CREW` ship at 3 km if there is one (its id), else `done()`; no error.
  - `test_never_retargets_a_hostile`: the only other ship is `HOSTILE` → `done()`.
  - `test_round_trips`: `to_dict` → `from_dict` keeps id, pursuing, the clock.

- [ ] **Step 2–4:** run (expected FAIL), implement, run (pass).
- [ ] **Step 5: Commit** `feat: Destroy, with a minute's pursuit`.

### Task 6: `ShipPilot` on every ship

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

### Task 7: Spawning a hostile, brackets, the warning, F8, the readout

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

- [ ] **Step 1: Write the failing tests:**
  - `test_shift_number_asks_for_a_hostile` (in `test_spawn_panel.gd`): Shift+2 emits `hostile_asked(1)`, not `spawn_asked`.
  - `test_a_hostile_spawns_three_km_off_facing_you`: `spawn_hostile(&"starter")` → a new ship, `side == HOSTILE`, distance 3000 ± 50 m, `(-hull.basis.z).dot(to_you) > 0.95`, `ship_pilot.on`, skill in 0.2..0.8, objective target `ship:Ship`.
  - `test_brackets_show_an_unlisted_hostile_with_its_hull`: after a render, `marks` has an entry with `hostile` true and text containing `HULL 100%`.
  - `test_hold_with_a_hostile_warns`: orders `HOLD`, a hostile engaging → `WeaponsStrip.orders_text() == "HOSTILE · WEAPONS ON HOLD"`.
  - `test_f8_refuses_a_hostile`: nearest ship hostile → `board_nearest()` false and the toast `HOSTILE SHIP`.

- [ ] **Step 2–4:** run (FAIL), implement, run `test_hostile_spawn.gd`, `test_spawn_panel.gd`, `test_weapons_hud.gd` (pass).
- [ ] **Step 5: Play it once** (windowed: `godot --path who-knows`): F6, Shift+1, watch the starter come at you; F2 shows it. Note anything wrong for Task 16; do not tune yet.
- [ ] **Step 6: Commit** `feat: Shift+F6 brings a hostile; its bracket, its hull, and the HOLD warning`.

---

## Phase 2: how hits feel

### Task 8: The jolt and the dip

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

- [ ] **Step 1: Write the failing tests:**
  - `test_strength_scales_with_damage`: 15 → 0.125, 120 → 1.0, 5 → 0.1, 500 → 1.0.
  - `test_a_heavy_knock_is_bigger_and_settles`: `knock(1.0, Vector3.RIGHT)` → head roll magnitude ≈ `ROLL_MOST`; `knock(0.125, ...)` ≈ an eighth; after `SETTLE` + 0.05 s both back to 0.
  - `test_a_burst_storm_is_capped`: twelve `knock(1.0)` in one frame → roll ≤ `ROLL_MOST × CEILING`.
  - `test_the_dip_dims_and_recovers`: a `CabinDip` with one registered lamp of energy 2.0; `dip(1.0)` → within 0.1 s energy ≤ `2.0 × DIP_HEAVY_LEVEL + ε`; after 0.6 s back to 2.0. `dip(0.125)` lasts ≤ 0.15 s and never below `2.0 × DIP_LIGHT_LEVEL`.
  - `test_flicker_follows_the_dip`: a `LightFlicker` with `dip` set; at its bright phase, `dip(1.0)` → lamp energy ≤ `lamp_energy × DIP_HEAVY_LEVEL`.
  - `test_a_hull_hit_is_felt_aboard`: scene: you seated in the starter, a phaser `Hit` of 120 on its hull → `felt_hit` emitted with strength 1.0, the avatar's head roll non-zero next frame, the cabin's dip factor < 1.

- [ ] **Step 2–4:** run (FAIL), implement, run `test_hit_feel.gd`, `test_light_flicker.gd`, `test_avatar.gd`, `test_weapons_job.gd` (pass).
- [ ] **Step 5: Render** (eye height, seated at the starter's helm, a heavy `Hit` dealt by script): a frame at the dip's deepest and one 0.6 s later, into `.superpowers/renders/task-8/`. Send them to the owner (SendUserFile) and carry on.
- [ ] **Step 6: Commit** `feat: hits jolt the cabin and dip its lights, by their strength`.

### Task 9: The bright burst, and heavy hits chip pieces off

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

---

## Phase 3: damage you can read

### Task 10: Spill-over

**Files:**
- Modify: `who-knows/src/ship/ship_damage.gd` (`_hurt`, `NEIGHBOURS`)
- Test: `who-knows/test/unit/test_spill_over.gd`

**Interfaces:**
- Produces: `ShipDamage.NEIGHBOURS: Dictionary` — each section to its neighbours along the length on its side and across in its third: `port_bow → [starboard_bow, port_mid]`, `port_mid → [starboard_mid, port_bow, port_stern]`, `port_stern → [starboard_stern, port_mid]`, and the starboard mirror. `_hurt(section, amount)` keeps what fits; the rest is split evenly between neighbours not at 0, each recursively; when every section is at 0 the rest is dropped. Breadth-first with a visited set so it ends.

- [ ] **Step 1: Write the failing tests** (`ShipDamage.build` on the starter's layout):
  - `test_overflow_goes_to_neighbours`: deal `section_hp[port_bow] + 1000` to a port-bow block → port bow at 0, starboard bow + port mid share 1000 (500 each ± 1).
  - `test_overflow_skips_dead_neighbours`: port bow and starboard bow at 0 → the next 1000 on port bow goes all to port mid.
  - `test_one_face_can_reach_zero`: keep hitting one port-bow block → `hull_whole()` reaches 0.0 after about the total hp (± 1%).
  - `test_components_never_spill`: 5000 on the core → core at its hp, every section untouched.
  - `test_crash_damage_spills_too`: `Ship.take_damage_many` with a crash-sized amount past a section's hp → a neighbour takes the rest (scene-based).
- [ ] **Step 2–4:** run (FAIL), implement, run `test_spill_over.gd`, `test_ship_damage_model.gd`, `test_ship_damage.gd` (pass).
- [ ] **Step 5: Commit** `feat: a section at 0 passes the rest to its neighbours`.

### Task 11: Sparks by damage, and gas vents

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

- [ ] **Step 1: Write the failing tests:**
  - `test_no_vents_above_half`: every section at 60% → `vents()` empty.
  - `test_vents_grow_as_a_section_falls`: a section at 45% → 1 vent; at 5% → 4; each has a face onto space.
  - `test_vents_ride_the_hull`: scene: a vented starter, `GasVents` emitters `local_coords` true, children of the hull; after `Universe.shift`, their positions relative to the hull unchanged; not in `HOLDS_SHIFT`.
  - `test_sparks_quicken_with_damage`: `DamageShow.share(coord, 1.0)` → that block's next spit within `SPIT_EVERY_WORST.y`.
  - Visual-style and floating-origin suites gain `gas_vents.gd` and pass.
- [ ] **Step 2–4:** run (FAIL), implement, run `test_gas_vents.gd`, `test_block_damage.gd`, `test_visual_style_rules.gd`, `test_floating_origin_scene.gd` (pass).
- [ ] **Step 5: Measure and render:** a starter at 10% HULL venting from all six sections; chase view at 30 m and from a second starter's helm at 200 m; fps over 10 s each (`Engine.get_frames_per_second`) on the dev GPU. Must hold 120; if not, fewer, smaller puffs. Renders to `.superpowers/renders/task-11/`, sent to the owner.
- [ ] **Step 6: Commit** `feat: a damaged hull sparks harder and vents gas`.

---

## Phase 4: destroyed

### Task 12: Destroyed, removed, saved

**Files:**
- Modify: `who-knows/src/ship/ship.gd` (`destroyed` signal, `is_destroyed`), `src/ship/fleet.gd` (`destroy`, the starter held destroyed, saving), `scenes/flight_test.gd` (the deaths aboard; restore)
- Test: `who-knows/test/unit/test_ship_destroyed.gd`

**Interfaces:**
- Produces:
  - `Ship.signal destroyed(ship: Ship)`, emitted once, the first time `damage.hull_whole() <= 0.0` after `take_damage_many`; `Ship.is_destroyed() -> bool`. From then on `take_damage_many` does nothing.
  - `Fleet.destroy(ship: Ship) -> void` — the starter (`name == STARTER`): held as asleep where it is (`_hold`) and added to `_destroyed`, never woken by `check_sleep`, never `aboard`; every other ship: `remove(ship)` (with the aboard check bypassed: `Fleet.remove(ship, force := false)` gains `force`). Emits `left` for a removed ship as now; `Fleet.signal ship_destroyed(ship_name: StringName)` for both.
  - `Fleet.is_destroyed(ship) -> bool`; `capture` writes `"destroyed": true` on a destroyed starter's part; `restore_hull` holds a part with `"destroyed"` destroyed.
  - Leaving `Weapons.TARGETS`: a destroyed starter calls `Weapons.leave(exterior)`.
  - In `flight_test.gd`, on `destroyed`: every NPC of `ship.npc_director` and every record `ship.records(...)` marked dead in `npc_ledger` (`mark_dead`); items aboard dropped (freed with the ship); then `fleet.destroy(ship)` deferred one frame (Task 13 plays the blast before it; Task 14 handles you aboard).

- [ ] **Step 1: Write the failing tests:**
  - `test_zero_hull_destroys_once`: deal past the total → `destroyed` emitted once; more damage does nothing.
  - `test_a_spawned_ship_is_removed`: after the frame, `fleet.ships()` lacks it, its slot is free, `Weapons.find(tree, ship_id)` null, a fire control listing it drops it within 2.2 s.
  - `test_the_starter_is_held_destroyed`: aboard another ship; destroy the starter → still in `fleet.ships()`, `fleet.is_destroyed` true, `sleeping` true, invisible, `process_mode` disabled, out of `Weapons.TARGETS`; `check_sleep` with you beside it never wakes it.
  - `test_a_destroyed_starter_survives_a_save`: `capture` → part has `"destroyed": true`; a new scene restored from it holds it destroyed.
  - `test_the_crew_aboard_die`: the starter's droid (`ship.npc_director.live_npcs()`) → `npc_ledger.is_dead(record.id)` after the destruction.
- [ ] **Step 2–4:** run (FAIL), implement, run `test_ship_destroyed.gd`, `test_fleet.gd`, `test_ship_turrets.gd` (pass).
- [ ] **Step 5: Run** `test/probes/fleet_play.gd` as its header says (CLAUDE.md: after a change to how ships come and go). Expected: its pass line.
- [ ] **Step 6: Commit** `feat: a ship at 0% hull is destroyed and leaves the fleet; the starter is held destroyed`.

### Task 13: The core goes up, the blast, the chunks

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

### Task 14: SHIP LOST, the reload, and no save under attack

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

---

## Phase 5: your ship's pilot

### Task 15: Handing your ship to its pilot

**Files:**
- Create: `who-knows/src/ship/computer/pilot_page.gd`
- Modify: `who-knows/project.godot` (`pilot_ai` = **P**, physical keycode 80), `src/flight/pilot_controls.gd` (the key, the takeback), `src/pilot/ship_pilot.gd` (`fight_for_you`), `src/ship/computer/ship_computer.gd` + `computer_context.gd` (`ship_pilot`), `src/combat/weapons_job.gd` (no hold while the pilot flies), `src/ui/vehicle_telemetry.gd` + the HUD band (the `AI PILOT · <STYLE>` line)
- Test: `who-knows/test/unit/test_your_pilot.gd`

**Interfaces:**
- Produces:
  - `ShipPilot.fight_for_you() -> void` — on, skill `PilotValues.YOUR_SKILL`, the objective Destroy on fire control's first listed hostile, else the nearest hostile in contact; with none, `hold_velocity(Vector3.ZERO)` and intent `&"holding_station"`, re-checking every `ASSESS_EVERY` for one. Remembers the orders it found and restores them when turned off (Task 6's `on = false`).
  - `ShipPilot.signal handed_back`.
  - `PilotControls`: `pilot_ai` pressed while seated toggles `ship_pilot.fight_for_you()` / `on = false`; while on, any stick motion past the dead zone, arrow key or translation key (the same tests `_process` already makes) sets `on = false` the same frame and then writes the input as usual. `VehicleTelemetry.ai_pilot: String` (`""` or `"AI PILOT · AUTO"` / `STAND-OFF` / `BRAWLER`), shown in the HUD band in `HudPalette.READOUT`.
  - `PilotPage` (a `ComputerPage`, added to the computer beside WEAPONS when the ship has turrets — the spec's §9.1 put the switch on the WEAPONS page, whose five buttons are all in use, so it gets a page of its own): lines `PILOT · ON/OFF`, `STYLE · AUTO`, the intent, the target; `big` toggles, `prev`/`next` cycle `style_choice`.
  - `WeaponsJob.sat`: sets `gunner_hold` only while `ship.ship_pilot == null or not ship.ship_pilot.on`; turning the pilot on while sat drops the hold, off restores it.

- [ ] **Step 1: Write the failing tests:**
  - `test_p_hands_over_and_hands_back`: seated in the starter, a hostile in contact; `pilot_controls.handle(P)` → `ship_pilot.on`, objective on the hostile, telemetry `ai_pilot == "AI PILOT · AUTO"`; P again → off.
  - `test_stick_releases_the_held_velocity`: pilot on with a hold; a stick motion event → same frame `ship_pilot.on` false and `flight_computer.velocity_hold` false.
  - `test_orders_come_back`: orders `HOLD` before; pilot on sets `ENGAGE`; off → `HOLD`.
  - `test_no_hostile_holds_station`: pilot on with nothing in contact → `held_velocity == Vector3.ZERO`, intent `&"holding_station"`.
  - `test_the_station_without_the_hold`: the Warden; pilot on, sit at the weapons station → `gunner_hold` false and the pilot still writes input; pilot off → `gunner_hold` true.
  - `test_the_pilot_page`: `PilotPage.press(&"big")` toggles; `&"next"` cycles AUTO → STAND-OFF → BRAWLER → AUTO.
- [ ] **Step 2–4:** run (FAIL), implement, run `test_your_pilot.gd`, `test_weapons_job.gd`, `test_weapons_page.gd`, `test_flight_computer.gd` (pass).
- [ ] **Step 5: Commit** `feat: hand your ship to its pilot with P; take it back with the stick`.

---

## Phase 6: proof and upkeep

### Task 16: The duel probe, tuning and renders

**Files:**
- Create: `who-knows/test/probes/duel_probe.gd`
- Modify (tuning only): `who-knows/src/pilot/pilot_values.gd`, then if needed `src/combat/weapon_values.gd`

**Interfaces:**
- Consumes: everything above.

The probe, in the style of `combat_probe.gd` (`extends SceneTree`, windowed, `--resolution 1280x720`, args the output dir; prints one line per result):

- **Duels in real time** in a patch of space with no rock within 5 km (the combat probe's `_clear_heading` idea: turn to a clear heading, then place both ships there). Each fight: two ships 3 km apart, both pilots `engage` each other, run until one is destroyed or 12 minutes. Print `duel <a> <skill> <style> vs <b> <skill> <style> · <seconds> · winner <x> · hits <band>:<rate> ... · qe <spent a>/<spent b> · switches <n> · rock_contacts <n>`.
- **Fights:** starter vs starter at 0.5/0.5 (×5, styles AUTO), 0.2 vs 0.8 (×5), BRAWLER vs STAND-OFF and the reverse (×3 each), Warden vs starter (×2).
- **Seated fps:** one starter-vs-starter duel with the probe seated at one helm (the canopy rendering): `fps <min> <mean>`; the same for the Warden fight against its 109–117 floor.
- **Losing:** a fight with you seated aboard the losing ship, to `LostScreen.finished` (the reload stubbed); print `lost ok`.
- **Your pilot:** one duel with the probe seated and your ship's pilot on (`fight_for_you`): print its result line.
- **Renders** (eye height 1.6 m where aboard), into the output dir: `hit_from_helm_400.png`, `hit_from_helm_1000.png` (an enemy bolt burst on the foe's hull from your helm), `cabin_heavy_hit.png` (the dip's deepest frame), `enemy_30pct.png` (sparks and gas, from your helm at 300 m), `core_0.1s.png`, `core_0.4s.png`, `breakup_2s.png` (from the helm and a chase view at 80 m).

**Pass** (spec §12.2): starter-vs-starter at 0.5/0.5 averages **4–6 minutes**; the 0.8 pilot wins at least 4 of 5 against 0.2; neither style wins every one of its six; `rock_contacts` 0 everywhere; seated **≥ 120 fps** in the starter duel, the Warden's ≥ 109; light-bolt hit rates in the 400 m band ≥ 70% and the 1 km band ≤ 40% (the dance holds).

- [ ] **Step 1: Write the probe** and run it once (`godot --path who-knows --resolution 1280x720 --script res://test/probes/duel_probe.gd -- D:\git\whoknows-hostiles\.superpowers\renders\task-16`). Expected: lines printed; record the first numbers.
- [ ] **Step 2: Tune** `PilotValues` (ranges, jink, gains, hold-fire) toward the pass marks, re-running between changes; only if the fight length cannot reach 4–6 minutes by the pilot alone, move `WeaponValues` damage or the light recharge, one at a time. Log each run to `run<n>.log` in the output dir.
- [ ] **Step 3: Send the renders and the numbers to the owner** (SendUserFile), with the pass table filled in. The owner judges the look.
- [ ] **Step 4: Commit** `test: the duel probe; pilots tuned to a five-minute fight` with the values changed listed in the body.

### Task 17: Skills and the as-built notes

**Files:**
- Modify: `.claude/skills/building-a-ship/SKILL.md` (checklist, *Mistakes already made*), `reference.md` (the pilot's and the blast's numbers, `Fleet.destroy`, `Ship.side`, `felt_hit`, `destroyed`), `ship_probe.gd` (a line: for each ship, `Broadside.best_face` and how many turrets bear on it); `.claude/skills/designing-a-ship/` (what makes a brawler or a stand-off fighter: reach, turrets that bear together on one face, thrust/mass); `.claude/skills/building-an-npc/` (NPCs aboard a destroyed ship die through the ledger; the blast reaches creatures as a `&"blast"` hit); `docs/superpowers/specs/2026-10-24-hostile-ships-design.md` (§17 *As built*: numbers that moved, the probe's table, what differs from the spec — at least the PILOT page beside WEAPONS — and known edges); the status line to *approved and built*.

- [ ] **Step 1:** run `ship_probe.gd` on the three library ships with the new line; record the faces.
- [ ] **Step 2:** write the skill and spec changes. Check every name the skills mention still exists (`Grep`).
- [ ] **Step 3: Commit** `docs: hostile ships as built; the ship skills learn the pilot and the end of a ship`.
- [ ] **Step 4:** ask the owner whether to run the full suite before finishing the branch (superpowers:finishing-a-development-branch).
