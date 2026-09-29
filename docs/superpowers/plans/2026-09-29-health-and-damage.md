# Health and Damage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Things can be hurt, broken and lost, and mended. The ship's blocks go from intact to
damaged, wrecked and gone. You can be downed and rescued. Skitters can die, and bite back. The
droid can be knocked out. A repair torch fed with scrap plates mends the ship. All of this runs
on the damage sources that already exist: the plasma pistol, crashes and creatures.

**Architecture:**
- **One vocabulary for hits.** `Hit` gains `damage`, `kind` and `shape`. Everything that sends a
  hit calls `Hit.deliver(collider, hit)`, which calls `receive_hit(hit)` on the collider or a
  `&"receive_hit"` Callable in its meta. The meta route is how the hull's `RigidBody3D` and the
  interior's code-made `StaticBody3D` receive hits without a script.
- **Pure cores, tested headless:**
  - `Health`: you and each NPC;
  - `DamageLog`: when something last took damage;
  - `BlockDamage`: a block's stage, damage, repair and removal against a `ShipGrid`;
  - `ShipCells`: a hit → a grid cell;
  - `ShipStats`: stage output, figures as if intact, and `crippled`.
- **`Ship` wires them to the world.** Hull and interior hits, crash contacts, stage looks, and
  pieces breaking off.
- **`RepairTorch`** is an `ItemUse`. `ItemUse.hold()` is the one new item seam.

**Tech Stack:** Godot 4.5.1 (.NET build, GDScript only), GUT 9, `run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-09-29-health-and-damage-design.md`. Read it first. Section
numbers below (§) are that spec's unless they say otherwise.

## Global Constraints

- **The numbers, from the spec:**
  - block stages by damage taken as a share of `def.hp`: intact `< 0.5`, damaged `< 1.0`,
    wrecked `< 1.5`, gone `>= 1.5`; output 1, 0.5, 0, and removed;
  - crippled below **25%** of intact forward thrust or of any intact `torque_budget` axis, or with
    no working quantum core;
  - plasma bolt damage **10**;
  - ship crash: nothing below a knock of **2 m/s**, then `12 × (knock − 2)²` on the struck cell and
    half that on each face neighbour;
  - you on a spacewalk: `10 × (closing − 4)` above **4 m/s**;
  - skitter bite **15**, cooldown **1.5 s**; it lunges within **2 m** and gives up beyond **6 m**;
  - health: you **100**; skitter **40**; droid **60**;
  - you heal **5 hp/s** after **10 s** calm; NPCs heal **1 hp per 10 s** while live;
  - downed: **1.5 s** fade, **3 s** black, wake at **50 hp**, the ship pays **50 QE**;
  - a dead creature lies still **20 s** and then fades; the droid reboots after **60 s** at
    **25%**;
  - torch: reach **2.5 m**, **25 hp/s**, **1 feed per hp**, hopper **300**; a plate is **+100**
    over **1.5 s**, refused with less than 100 room; a rebuild costs **100** feed and takes
    **3 s**, and the block comes back wrecked;
  - the save gate waits **5 s** after any damage, and while you are *blacked out* or *welding*.
- **Visual style** (`docs/design/visual-style.md`, binding):
  - colours only from the palettes: `HullPalette.SCORCH`, `HullPalette.CHAR`,
    `InteriorPalette.SCORCH`, `InteriorPalette.CHAR`, and the torch's `InteriorPalette` colours;
  - no new shader;
  - the torch builds like a prop from `(kit, frame, variety)`;
  - `test_visual_style_rules.gd` must stay green; if it fails, fix the code, not the test.
- **Floating origin** (CLAUDE.md): sparks and bursts outside are world-space particles in
  `Universe.HOLDS_SHIFT`. A plate shed from a gone block is a stray through the existing
  `StrayField`, never a bare node outside. `test_floating_origin_scene.gd` must stay green.
- **`.tscn`/`.tres`:** no `#` comments anywhere. This plan adds `data/items/repair_torch.tres` and
  edits `data/npcs/*.tres` and the block meshes' materials only if Task 5 needs it. Prove every
  edit by reading the property back at runtime in a test.
- **Tests:** GUT, headless, output pristine. From the worktree root in PowerShell:
  - everything: `& .\who-knows\run_tests.ps1`;
  - one script: `& .\who-knows\run_tests.ps1 '-gselect=test_block_damage'`.
- **After adding a `class_name`,** run the import pass before tests, and commit Godot's `.uid`
  files:
  `& "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path .\who-knows --import`
  (or `$env:GODOT_BIN` if set).
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Work in a sibling worktree,** `D:\git\whoknows-damage` on branch `health-and-damage`:
  1. `git -C D:\git\whoknows switch main`
  2. `git -C D:\git\whoknows worktree add -b health-and-damage D:\git\whoknows-damage main`
  3. Run the import pass there once, then the whole suite, and record the baseline count.
- **Code style:** match the surrounding GDScript. British spelling in comments. Doc comments (`##`)
  say what and why, plainly, citing spec sections.
- **Renders:** visual work is verified by rendering the real scene at eye height (1.6 m) and
  showing the owner (CLAUDE.md). Green tests prove structure, not looks.
- **Skills:** this changes how a ship is laid out to survive, and adds NPC health and a behaviour.
  Task 12 updates `building-a-ship` (checklist, mistakes, `reference.md`, `ship_probe.gd`) and
  `building-an-npc` (checklist, mistakes, `reference.md`) in this branch, as CLAUDE.md requires.

## Names this plan builds on

Open each file and confirm these before starting. If one differs, note the built name in your task
report and use it throughout.

| Name | Where | Used by |
|---|---|---|
| `Hit.make(at, normal, dir, push, from)`; fields `position`, `normal`, `direction`, `impulse`, `source` | `src/items/hit.gd` | 1, 4, 8 |
| `PlasmaBolt.impact(result)` (calls `receive_hit`), `PlasmaBolt.PUSH`, `RAY_MASK` | `src/items/plasma_bolt.gd` | 4 |
| `BlockInstance.hp_current`, `duplicate_instance()` | `src/ship/block_instance.gd` | 2 |
| `ShipBlueprint.hp_values`, `from_grid`, `to_grid()`, `to_dict()`/`from_dict()` | `src/ship/ship_blueprint.gd` | 2 |
| `ShipGrid.cell_changed(coord)`, `set_block`, `clear_block`, `get_block`, `has_block`, `coords()`, `neighbours(coord)`, `cell_center(coord)`, `CELL_SIZE` | `src/ship/ship_grid.gd` | 2, 3, 4 |
| `BlockDefinition.hp`, `thrust_kn`, `power_gen`, `power_draw`, `quantum_capacity`, `grav_radius`, `id` | `src/ship/block_definition.gd` | 2, 3 |
| `ShipStats.compute(grid, catalog)`, `_gather`, `thrust_budget`, `torque_budget` | `src/ship/ship_stats.gd` | 3 |
| `ShipValidator._check_all_connected` (the flood fill to copy) | `src/ship/ship_validator.gd` | 2 |
| `Ship.exterior` (a scriptless `RigidBody3D`), `_on_hull_struck(body)`, `_last_hull_velocity`, `since_struck`, `_on_cell_changed`, `_rebuild_everything()`, `_stock()`, `busy()`, `interior_slot_origin()`, `stats_changed`, `interior`, `interior_builder`, `exterior_builder`, `items`, `quantum` | `src/ship/ship.gd` | 4, 5, 7, 10, 11 |
| `ExteriorBuilder.collider_coords()` (shape index → coord), `_multimeshes` (block id → `MultiMeshInstance3D`), `_build_meshes()` | `src/ship/exterior_builder.gd` | 4, 5 |
| `InteriorBuilder.rebuild()`, `interior_center(coord)`, `floor_y(coord)`, `InteriorGeometry` body (layer 2) | `src/ship/interior_builder.gd` | 4, 5 |
| `InteriorDressing.CLOSET_STOCK`, `CLOSET_SIDE_STOCK` | `src/ship/interior/interior_dressing.gd` | 10 |
| `Avatar.Mode`, `mode`, `enter_suit(outside, pose, v, hull)`, `enter_plating(...)`, `bump(before, slid, hits)`, `busy()`, `set_control_enabled`, `suit_cell`, `_to_home()`, `Suit.home_step` | `src/avatar/avatar.gd`, `src/avatar/suit.gd` | 6 |
| `Grasp.use()`, `_unhandled_input`, `_physics_process`, `item`, `mode`, `Mode.WIELDING`, `aim()`, `world_root`, `_body`, `drop()`, `_update_prompt()`, `prompt_changed` | `src/avatar/grasp.gd` | 6, 10 |
| `ItemUse.use / status / save / restore / recoil` | `src/items/item_use.gd` | 10 |
| `Item.LAYER` (32), `Item.definition`, `Item.use_node` | `src/items/item.gd` | 10 |
| `Npc.receive_hit`, `shove`, `species`, `record`, `perception.touched`, `look.act`, `Npc.LAYER` | `src/npc/npc.gd` | 7, 8 |
| `NpcRecord` fields; `NpcDirector.amend(record)`, `live` | `src/npc/npc_record.gd`, `npc_director.gd` | 7 |
| `NpcSpecies` export groups | `src/npc/npc_species.gd` | 7 |
| `Behaviour` (score, start, think, done, `REFLEX`), `NpcBehaviours` table, `NpcContext` | `src/npc/` | 8 |
| `QuantumStore` spend API; `SaveGate.add_source(callable)`; `SaveGame.write(parts, …)` and `flight_test.gd`'s parts dictionary | `src/quantum/`, `src/save/`, `scenes/flight_test.gd` | 6, 11 |
| `HudPalette` warning colour; `HudRoot`, `HudElement.render(telemetry)`, `VehicleTelemetry` | `src/ui/` | 6, 11 |
| `StrayField.adopt(item)`, `let_go(item)`; `SalvageField.MIX` | `src/world/` | 5, 10 |
| `Universe.HOLDS_SHIFT`, `Universe.EXTERIOR_SPACE` | `src/world/universe.gd` | 5, 10 |

---

## File Structure

| File | Responsibility |
|---|---|
| Modify `src/items/hit.gd` | `damage`, `kind`, `shape`; `Hit.deliver(collider, hit)` |
| Create `src/combat/health.gd` | `Health`: take, heal, calm regen, `hurt`/`emptied` |
| Create `src/combat/damage_log.gd` | `DamageLog`: seconds since any damage; a save-gate source |
| Modify `src/ship/block_instance.gd`, `ship_blueprint.gd` | `hp_current` → `damage`; `damage_values`, reading `hp_values` as zero |
| Create `src/ship/block_damage.gd` | `BlockDamage`: stage, apply, repair, rebuild, keep-list, split-off |
| Modify `src/ship/ship_grid.gd` | `block_staged(coord, stage)`; `remove_many(coords)` with one `cell_changed` |
| Modify `src/ship/ship_stats.gd` | stage output; `intact` figures; `crippled` |
| Create `src/ship/ship_cells.gd` | `ShipCells.cell_at(ship, hit)` for the hull and the interior |
| Modify `src/ship/ship.gd` | hit relays; crash damage; stage looks; the launch blueprint; the burst and the shed plate; `crippled` |
| Modify `src/ship/exterior_builder.gd` | per-instance stage colour |
| Modify `src/ship/interior_builder.gd`, `interior/interior_dressing.gd` | stage tint on a cell's dressing; the torch and plates in stock |
| Modify `src/ship/hull_palette.gd`, `interior/interior_palette.gd` | `SCORCH`, `CHAR`, torch colours |
| Create `src/ship/damage_show.gd` | sparks on damaged cells; the gone burst (world-space particles) |
| Modify `src/avatar/avatar.gd` | `Health`, `receive_hit`, EVA crashes, downed, falling out, the helm |
| Create `src/avatar/downed.gd` | `Downed`: the blackout's steps as a small state machine (pure timing) |
| Create `src/ui/hurt_edge.gd` | the red edge on the view |
| Modify `src/npc/npc.gd`, `npc_record.gd`, `npc_species.gd`, `npc_director.gd` | health; death; knock-out; `amend` through the ledger |
| Create `src/npc/npc_ledger.gd` | `NpcLedger`: the dead, by record id; `to_dict`/`from_dict` |
| Create `src/npc/behaviours/defend.gd` | the skitter's bite |
| Modify `src/npc/skitter_look.gd`, `droid_look.gd` | flinch, dead, knocked out |
| Modify `data/npcs/skitter.tres`, `maintenance_droid.tres` | `max_health`; `defend` for the skitter |
| Modify `src/items/item_use.gd`, `src/avatar/grasp.gd` | `hold()` while `use` is held |
| Create `src/items/repair_torch.gd`, `data/items/repair_torch.tres` | the torch |
| Modify `src/items/item_looks.gd` | the torch's look |
| Modify `src/items/plasma_bolt.gd` | damage 10, `Hit.deliver` |
| Modify `src/save/…`, `scenes/flight_test.gd` | your health, the ledger, `DamageLog` as a gate source |
| Modify `src/ui/…` | HULL and CRIPPLED in the band |
| Tests | New: `test_hit`, `test_health`, `test_damage_log`, `test_block_damage`, `test_ship_cells`, `test_ship_damage`, `test_downed`, `test_npc_health`, `test_npc_death`, `test_defend`, `test_repair_torch`. Extended: `test_ship_blueprint`, `test_ship_stats`, `test_grasp`, `test_save_codec`, `test_npc_catalog`, `test_visual_style_rules` (if it lists palettes), `test_floating_origin_scene` |
| Docs | the spec (status, as built), `SLICE-1-STATUS` if it lists slices, both skills |

---

### Task 1: The vocabulary: `Hit`, `Health`, `DamageLog`

**Files:** modify `src/items/hit.gd`; create `src/combat/health.gd`, `src/combat/damage_log.gd`;
tests `test_hit.gd`, `test_health.gd`, `test_damage_log.gd`.

- [ ] **Step 1: Write the failing tests.**
  - `Hit`: `make()` still works with five arguments; `damage` is 0 and `kind` is `&""` by default.
  - `Hit.deliver` calls `receive_hit` on a node that has it, calls the Callable in
    `&"receive_hit"` meta on one that doesn't, and does nothing on a node with neither.
  - `Health`:
    - `take` lowers `current`, never below 0, and returns what it really took;
    - `hurt` fires with the amount taken, and `emptied` fires once on reaching 0 (a second hit at
      0 fires neither);
    - `heal` caps at `max`;
    - `tick(delta)` regenerates only after `regen_after` seconds with no damage;
    - `to_dict`/`from_dict` round-trip.
  - `DamageLog`: `note()` resets `since`, and `busy()` is `"took damage"` for `CALM` (5 s), then
    `""`.
- [ ] **Step 2: Run them; they fail.**
- [ ] **Step 3: Implement.**

```gdscript
# hit.gd: new fields and the one delivery path
## hp. 0 for a hit that only pushes.
var damage := 0.0
## &"plasma", &"crash", &"bite"; &"" when it does not matter.
var kind: StringName = &""
## The collider's shape index the hit landed on, or -1: which cell of a hull.
var shape := -1

## Tells `collider` about `hit` (spec §3): its own receive_hit, or a Callable a
## scriptless body carries in meta &"receive_hit" (the hull, the interior).
static func deliver(collider: Object, hit: Hit) -> void:
	if collider == null:
		return
	if collider.has_method(&"receive_hit"):
		collider.receive_hit(hit)
	elif collider.has_meta(&"receive_hit"):
		(collider.get_meta(&"receive_hit") as Callable).call(hit)
```

```gdscript
class_name Health
extends RefCounted

## How hurt something is (docs/superpowers/specs/2026-09-29-health-and-damage-design.md
## §3): you and every NPC hold one. Pure: its owner ticks it.

signal hurt(amount: float)
signal emptied

var max := 100.0
var current := 100.0
## Seconds with no damage before regen starts, and hp/s after; 0 for none.
var regen_after := 10.0
var regen_rate := 0.0
var since_hurt := INF

static func make(p_max: float, p_regen_after := 10.0, p_regen_rate := 0.0) -> Health: ...
func take(amount: float) -> float: ...   # emits hurt, and emptied on the step to 0
func heal(amount: float) -> void: ...
func tick(delta: float) -> void: ...
func is_empty() -> bool: ...
func fraction() -> float: ...
func to_dict() -> Dictionary: ...
func from_dict(d: Dictionary) -> void: ...
```

- [ ] **Step 4: Run the tests and the whole suite; all green.**
- [ ] **Step 5: Commit** `feat: the vocabulary of damage -- Hit carries damage, Health, DamageLog`.

---

### Task 2: Blocks take damage: `BlockDamage` and the grid

**Files:** modify `block_instance.gd`, `ship_blueprint.gd`, `ship_grid.gd`; create
`src/ship/block_damage.gd`; tests `test_block_damage.gd`, extend `test_ship_blueprint.gd`.

- [ ] **Step 1: Rename** `BlockInstance.hp_current` → `damage: int` (hp lost; 0 intact). Update
  `duplicate_instance()`. In `ShipBlueprint` rename `hp_values` → `damage_values`. `from_dict`
  reads `damage_values`, or zeros if only the old `hp_values` key is there (spec §4.2). Grep
  for every other use of `hp_current`/`hp_values`, including `test_save_codec.gd`, and update it.
- [ ] **Step 2: Write the failing tests** (`test_block_damage.gd`, with a small hand-made grid and
  a real `BlockCatalog`):
  - `stage_of(inst, def)` at 0, 49%, 50%, 99%, 100%, 149% and 150% of `hp`;
  - `output_of(stage)` is 1, 0.5, 0 and 0;
  - `apply(grid, catalog, coord, amount)`:
    - raises `damage`;
    - emits `grid.block_staged` once per stage crossed, and never for a hit inside a stage;
    - returns the coords it removed;
  - at gone, the block is removed through `remove_many`, and `cell_changed` fires once for a hit
    that removes several;
  - `KEEP` blocks (`&"core"`, `&"pilot_seat"`, `&"airlock"`) stop at the wrecked cap and are never
    removed;
  - removing a block that splits the ship removes every block no longer joined to the core, in the
    same `remove_many`;
  - `repair(grid, catalog, coord, hp)` lowers damage, not below 0, emits `block_staged` on the
    way up, and returns what it used;
  - `rebuild(grid, coord, inst)` puts a block back at exactly `WRECKED_AT × hp` damage.
- [ ] **Step 3: Implement** `ShipGrid.block_staged` and `ShipGrid.remove_many(coords)`, which
  erases every cell and then emits `cell_changed` once with the first coord. Then implement
  `BlockDamage` (all static, pure):

```gdscript
class_name BlockDamage
extends RefCounted

## A block's stage from the damage it has taken (spec §4.1), and the only code
## that writes BlockInstance.damage.

enum Stage { INTACT, DAMAGED, WRECKED, GONE }
const DAMAGED_AT := 0.5
const WRECKED_AT := 1.0
const GONE_AT := 1.5
const OUTPUT := {Stage.INTACT: 1.0, Stage.DAMAGED: 0.5, Stage.WRECKED: 0.0, Stage.GONE: 0.0}
## Wrecked but never removed (spec §4.5).
const KEEP: Array[StringName] = [&"core", &"pilot_seat", &"airlock"]
```

  **A build difference to record in the spec:** §4.5 keeps "the airlock you came in through". The
  ship does not track which one that was, so every airlock is kept. A starter ship has one.
- [ ] **Step 4: Run the tests and the whole suite; all green.**
- [ ] **Step 5: Commit** `feat: blocks take damage -- stages, removal, split-off pieces, repair`.

---

### Task 3: Stats by stage, and crippled

**Files:** modify `ship_stats.gd`; extend `test_ship_stats.gd`.

- [ ] **Step 1: Write the failing tests:**
  - a damaged thruster gives half its `thrust_kn`, and a wrecked one none;
  - mass is unchanged by stage;
  - `intact_thrust_forward` and `intact_torque` are the figures with every block's damage at 0;
  - `crippled` is true below 25% forward, below 25% on any torque axis, and with every
    `quantum_core` wrecked, and false otherwise;
  - `crippled_reason()` names the first cause (*"no thrust"*, *"can't turn"*, *"no power"*).
- [ ] **Step 2: Implement.** `_gather` adds `"output"` from `BlockDamage.output_of(stage)`.
  Thrust force, `power_gen`, `power_draw`, `quantum_capacity` and grav are scaled by it; mass and
  inertia are not. `compute` runs `_accumulate_thrust` a second time with every output at 1 for
  the intact figures. It is 150 blocks, so this costs nothing.
- [ ] **Step 3: Tests and suite green. Commit** `feat: stats read each block's stage; crippled`.

---

### Task 4: Hits reach blocks: the pistol, the hull, the interior, crashes

**Files:** create `src/ship/ship_cells.gd`; modify `plasma_bolt.gd`, `ship.gd`; tests
`test_ship_cells.gd`, `test_ship_damage.gd`.

- [ ] **Step 1: `ShipCells`** (pure):
  - `hull_cell(builder_coords, shape) -> Vector3i` looks the shape index up in
    `collider_coords()`;
  - `interior_cell(grid, interior_local_point, normal) -> Vector3i` steps 5 cm back along
    `-normal`, then finds the cell by `floor((p - origin_offset) / CELL_SIZE)`. Use the same
    transform `InteriorBuilder.interior_center` inverts, and check it against it.

  Test every face direction on a hand-made grid; an interior point on a wall face must give the
  solid cell behind the wall, not the walkable cell in front.
- [ ] **Step 2: The pistol.** `PlasmaBolt.impact`:
  - sets `damage = DAMAGE` (10) and `kind = &"plasma"`;
  - sets `shape = result.get("shape", -1)`;
  - calls `Hit.deliver(collider, hit)` instead of its own `has_method` check.

  `Npc.receive_hit` still pushes, so nothing about skitters changes until Task 7.
- [ ] **Step 3: The relays.** In `Ship`:
  - after each rebuild, set `exterior.set_meta(&"receive_hit", _on_hull_hit)` and the same on the
    interior's `InteriorGeometry` body, pointing at `_on_interior_hit`;
  - both find the cell through `ShipCells` and call `take_damage(coord, hit.damage)`;
  - `take_damage` calls `BlockDamage.apply`, notes the `DamageLog`, and passes removed coords to
    Task 5's burst.
- [ ] **Step 4: Crashes.** `_on_hull_struck` already has `knock`. Read the contacts with
  `PhysicsServer3D.body_get_direct_state(exterior.get_rid())`, whose contact monitor is already
  on. For the contact whose `get_contact_collider_object(i)` is `body`,
  `get_contact_local_shape(i)` is the hull shape. Then:
  - `CRASH_K × (knock − CRASH_FROM)²` on that cell;
  - half on each of `grid.neighbours(coord)`;
  - only when `knock > CRASH_FROM`.

  Keep the thump and the jolt as they are.
- [ ] **Step 5: `test_ship_damage.gd`** (a real `Ship` from `flight_test.tscn`'s blueprint):
  - a hit relayed to `exterior` damages the right cell;
  - one on `InteriorGeometry` damages the cell behind the face;
  - `crash_damage(knock)` is 0 at 2 m/s and 108 at 5 m/s;
  - a gone block is gone from the grid, and the ship still flies (stats recomputed, no errors).
- [ ] **Step 6: Suite green. Commit** `feat: hits and crashes damage the block they land on`.

---

### Task 5: How damage looks

**Files:** modify `hull_palette.gd`, `interior_palette.gd`, `exterior_builder.gd`,
`interior_builder.gd`/`interior_dressing.gd`, `ship.gd`; create `src/ship/damage_show.gd`.

- [ ] **Step 1: Colours.** Add `HullPalette.SCORCH` and `CHAR`, and `InteriorPalette.SCORCH` and
  `CHAR`: warm, dark browns, not black (visual style §3). Add the torch colours
  (`TORCH_BODY` warm off-white, `TORCH_NOZZLE` gunmetal; reuse `BELT`) and `WELD`, a hot warm
  white for sparks.
- [ ] **Step 2: The hull.** Turn on `use_colors` for each block type's `MultiMesh` and set each
  instance's colour from its stage (white, `SCORCH`, `CHAR`). On `block_staged`, set that one
  instance's colour. There is no rebuild: keep a coord → (block id, index) map from
  `_build_meshes`.
  - The block meshes' materials must multiply by the instance colour
    (`vertex_color_use_as_albedo`). Set it on a duplicated material in code at build time rather
    than editing the mesh `.tres` files.
  - The hull plate uses `hull_livery.tres`. If that is a shader and ignores `COLOR`, stop and
    report. Do not add a shader or edit it without the owner (the shader budget).
  - Wrecked cells also hide their emissive surfaces: `RUNNING_LIGHT` bells on thrusters. Use a
    per-instance colour of black on a second emissive MultiMesh if the mesh splits by surface.
    Otherwise accept a charred tint and note it for the owner.
- [ ] **Step 3: The interior.** The dressing is merged into one mesh per batch (`InteriorKit`), so
  a single cell cannot be re-coloured on its own. On `block_staged` for a cell with interior
  faces, `Ship` asks `InteriorBuilder` to re-dress: it rebuilds the dressing and the fixtures,
  not the grid, the walkable set or the colliders. This is coalesced to once a frame with
  `call_deferred`. `InteriorDressing._dress`/`_fixture` read a `stage_of(coord)` Callable and
  darken their `solid()` colours toward `SCORCH`/`CHAR`. A wrecked cell's `lit()` pieces use
  `SCREEN_BACK`. Record this in the spec's as-built section: §4.3 and §9 said one cell's mesh, but
  the build re-dresses the interior at most once a frame, and only when a stage changes.
- [ ] **Step 4: `DamageShow`.** A node under `Ship` that does two things:
  - **Sparks:** every 0.8–2.5 s (seeded per cell), a burst of 6 sparks at a damaged cell's outer
    face. They are world-space `GPUParticles3D` in `Universe.HOLDS_SHIFT`, colour `WELD`.
  - **The gone burst:** 2 s of warm sparks and 3–5 small `SCORCH` bevelled chunks, as
    `RigidBody3D`s on no collision layer, in `EXTERIOR_SPACE`, freed after 2 s. If the removed
    cell had an outside face, one `scrap_plate` is made and handed to `StrayField.adopt(item)` at the cell's
    centre, drifting outward at 1 m/s (spec §8.1).
- [ ] **Step 5: Render** at 1.6 m, aboard and from a spacewalk: a hull block and an interior wall
  at each stage, and a hole. Show the owner and wait for their word on the colours before going
  on.
- [ ] **Step 6: Suite green (visual style and floating origin included). Commit**
  `feat: damage shows -- scorched, charred, sparks and holes`.

---

### Task 6: You can be hurt, and downed

**Files:** modify `avatar.gd`; create `src/avatar/downed.gd`, `src/ui/hurt_edge.gd`; tests
`test_avatar.gd` (extend), `test_downed.gd`.

- [ ] **Step 1: Health.**
  - `Avatar.health = Health.make(100, 10, 5)`, ticked in `_physics_process`.
  - `receive_hit(hit)` takes the damage unless you are seated (§7.3: `PilotSeat` occupied → do
    nothing; the ship takes crash damage anyway) and applies the impulse as `bump` would.
  - `health.hurt` notes the `DamageLog`.
- [ ] **Step 2: Spacewalk crashes.** In `bump`, for each rock or NPC hit with
  `closing > EVA_HURT_FROM` (4), take `EVA_HURT_K × (closing − 4)` as kind `&"crash"`. Test
  with `bump()` directly, as the existing bump tests do.
- [ ] **Step 3: Feel.**
  - `HurtEdge`: a full-screen `ColorRect` with a radial alpha drawn in `_draw()`, in
    `HudPalette`'s warning colour. It flashes to 0.35 alpha on `hurt` and fades over 0.6 s, and
    holds at 0.12 below 30 hp.
  - The camera jolt: 0.05 rad toward the hit's direction, back over 0.25 s.
  - Sounds: `Synth` `hurt_thump`; breathing below 30 hp, suit only.
- [ ] **Step 4: `Downed`** (pure timing, tested headless). It is a small state machine,
  `FADING (1.5 s) → BLACK (3 s) → WAKING`, driven by `tick(delta)` and emitting `step(name)`.
  On `emptied`, `Avatar`:
  1. turns control off;
  2. drops the held item through `Grasp.drop()`;
  3. starts `Downed`.

  In BLACK:
  - **aboard:** place yourself at the lower bunk of the first bunk room. If there is none, use
    the first walkable cell beside the core. Use `can_stand_at` and fall back to the next cell.
  - **outside:** keep suit mode and steer with `Suit.home_step` toward `_to_home()` until you
    are at the airlock's step-in point, then `enter_plating` there.

  On WAKING: `health.current = 50`, the ship's store spends 50 QE (it may reach 0), the toast
  reads *YOU BLACKED OUT · 50 QE*, and control comes back. `busy()` returns *"blacked out"* from
  `emptied` until WAKING ends.
- [ ] **Step 5: Falling out** (§7.4). After each ship rebuild, if you are in plating mode and the
  cell under you is gone, `enter_suit` at your velocity. Test it by removing the deck cell under
  a placed avatar.
- [ ] **Step 6: Suite green. Commit** `feat: you can be hurt, black out and wake aboard`.

---

### Task 7: NPCs are hurt, die, or are knocked out

**Files:** modify `npc_species.gd`, `npc_record.gd`, `npc.gd`, `npc_director.gd`, the two looks,
both species `.tres`; create `src/npc/npc_ledger.gd`; tests `test_npc_health.gd`,
`test_npc_death.gd`, extend `test_npc_catalog.gd`.

- [ ] **Step 1:**
  - `NpcSpecies.max_health` in a new `Health` export group; `knocked_out_for` (0 means it dies)
    and `wake_health` (fraction).
  - Skitter: 40 and 0. Droid: 60, 60 s and 0.25.
  - Read the values back at runtime in `test_npc_catalog.gd`, which also checks
    `max_health > 0` for every species.
- [ ] **Step 2:** `NpcRecord.health := -1.0`, where -1 means full. `Npc` makes a `Health` from it
  on promotion and writes it back on demotion. It regenerates 0.1 hp/s while live.
- [ ] **Step 3: `receive_hit`:**
  - keeps the touch and the shove;
  - takes the damage;
  - raises `brain` fear by `damage / max_health`;
  - calls `look.act(&"flinch")`.
- [ ] **Step 4: At 0:**
  - **Species that die:** the brain stops, the locomotor holds, `look.act(&"dead")` rolls it over,
    and after 20 s it fades and the director frees it. `NpcLedger.mark_dead(record.id)`, and
    `NpcDirector.amend(record)` returns null for a dead id. Make sure `amend`'s callers skip null.
  - **The droid:** `look.act(&"knocked_out")` drops it and kills the eye, and the brain pauses.
    After `knocked_out_for` it wakes at `wake_health`. `revive()` wakes it at once (Task 10's
    torch).
- [ ] **Step 5: `NpcLedger`**: one per game, held by `flight_test.gd`, and given to both directors.
  `to_dict`/`from_dict`. Test that a dead record is never promoted again, across a round-trip.
- [ ] **Step 6: Looks.** `flinch`: a 0.15 s squash. `dead`: skitter on its back, legs curled.
  `knocked_out`: the droid slumped and its eye `SCREEN_BACK`. Colours from the existing
  palettes. Render them and show the owner with Task 8's renders.
- [ ] **Step 7: Suite green. Commit** `feat: NPCs are hurt, and die or are knocked out`.

---

### Task 8: The skitter bites back

**Files:** create `src/npc/behaviours/defend.gd`; modify `npc_behaviours.gd`, `skitter.tres`;
test `test_defend.gd`. **Use the `building-an-npc` skill's behaviour template.**

- [ ] **Step 1: Failing tests** with made-up `NpcContext`s:
  - scores 0 when calm and not hurt;
  - over the reflex threshold when hurt within the last 3 s and the player is within 6 m;
  - over it when fear > 0.7, the player is within 2 m, and the site offers no scatter point;
  - the intent lunges (speed 1.0, `action &"lunge"`) at the player;
  - it bites at most every 1.5 s;
  - it is done when the player is beyond 6 m or fear < 0.3.
- [ ] **Step 2: Implement.** A bite is a `Hit` from the skitter to the avatar: 15 damage,
  `&"bite"`, a 40 N·s shove along the lunge, through `Hit.deliver`. The behaviour asks for it
  through the intent (`action = &"bite"`), and `Npc` delivers it when the locomotor reports
  contact within 0.6 m. The brain never touches the world (NPC spec §7).
- [ ] **Step 3:** Add `&"defend"` to the skitter's `behaviours`. Read it back in a test.
- [ ] **Step 4: Live check:** shoot a skitter on a rock from 4 m. It turns, lunges and bites.
  Walk away and it gives up.
- [ ] **Step 5: Suite green. Commit** `feat: a skitter bites back when hurt or cornered`.

---

### Task 9: The launch blueprint the ship remembers

**Files:** modify `ship.gd`, saving; extend `test_save_codec.gd`.

- [ ] **Step 1:** `Ship.launch_blueprint: ShipBlueprint`, set in `load_blueprint`. It is the
  layout with every block's damage at 0. Saving already writes the layout (saving §6.2). Add
  `launch` beside it, and on load read a missing `launch` as the loaded layout with damage
  cleared. A torch rebuild (Task 10) reads block id and orientation from it.
- [ ] **Step 2:** Round-trip test: damage a block, remove another, save, load. The damage is kept,
  the hole is kept, and `launch_blueprint` still has the removed block.
- [ ] **Step 3: Suite green. Commit** `feat: the ship remembers the layout it launched with`.

---

### Task 10: The repair torch

**Files:** modify `item_use.gd`, `grasp.gd`, `item_looks.gd`, `interior_dressing.gd`; create
`src/items/repair_torch.gd`, `data/items/repair_torch.tres`; tests `test_repair_torch.gd`, extend
`test_grasp.gd`.

- [ ] **Step 1: The seam.** `ItemUse.hold(item, aim, world, holder, delta) -> bool` returns false
  by default. `Grasp._physics_process` calls `item.use_node.hold(...)` every frame while
  `Input.is_action_pressed(&"use")`, the grasp is WIELDING, and the mouse is captured.
  `Grasp.use()` on the press is unchanged. Test that `hold` is called only while `use` is held,
  and never for a CARRY item.
- [ ] **Step 2: The definition.** `repair_torch.tres`:
  - `grip = 0` (WIELD), `stow_class = &"tool"`, `quantum_value = 60`, `eva_tool = false`;
  - `use = repair_torch.gd`, `look = &"repair_torch"`;
  - size about `(0.07, 0.09, 0.28)`, with `grip_point` and `use_point` at the nozzle.

  No comments in the `.tres`. Read every property back in a test.
- [ ] **Step 3: `RepairTorch extends ItemUse`**, with `feed` (0–300, saved through
  `save`/`restore`, starting at 300 for a stocked torch). Each `hold`:
  - one ray from the eye, 2.5 m, mask `2 | 1 | Item.LAYER | Npc.LAYER`, excluding the holder;
  - **an Item whose id is `scrap_plate`:** charge 1.5 s; then free the plate (through the item's
    own removal path, so stow points and the stray ledger forget it) and add 100 feed. Refuse
    with *TORCH FULL* when `300 − feed < 100`;
  - **the hull or the interior:** find the cell through `ShipCells`. If the grid has a block
    there, `BlockDamage.repair` with `min(25 × delta, feed)` and spend what it used. If the cell
    is empty and `launch_blueprint` has a block there, charge 3 s and then, with
    `feed >= 100`, call `BlockDamage.rebuild` and spend 100. To aim at an empty cell, step
    forward 5 cm along `-normal` from a hole's edge. From outside, a ray that misses but ends
    within 2.5 m of an empty launch cell next to the hull targets that cell.
  - **an `Npc` of a species with `knocked_out_for > 0`:** `revive()` if knocked out, otherwise
    heal at the same rate and feed.
  - `status()` gives the prompt: *HULL BLOCK · WRECKED 12% · FEED 180*,
    *REBUILD THRUSTER · 100 FEED*, *LOAD PLATE*, *TORCH FULL* or *FEED 0*.
  - The weld show: a warm `OmniLight3D` (range 1.5, `WELD`) and sparks at the hit point. They are
    world-space particles in `HOLDS_SHIFT` when outside, and on the interior layers aboard.
  - `busy()` on the avatar reads *"welding"* while `hold` returned true in the last 0.2 s.
- [ ] **Step 4: The look** in `ItemLooks`, `repair_torch(kit, size)`: a bevelled `TORCH_BODY` body,
  a `TORCH_NOZZLE` tube, and a `BELT` band. `ItemLooks`' list of looks gains it.
- [ ] **Step 5: Stock** (spec §8.1):
  - `CLOSET_STOCK[&"tool"]` becomes `[&"repair_torch", &"spare_module", &"hand_lamp"]`; the
    spanner leaves the starting stock and is still makeable;
  - `CLOSET_STOCK[&"crate"]` becomes `[&"scrap_plate", &"scrap_plate"]`;
  - `CLOSET_SIDE_STOCK[&"crate"]` becomes `[&"scrap_plate"]`.

  The crate, toolbox and spare helmet leave the starting stock. Note this for the owner in the
  task report, since it changes what the closet shows. Test that a new ship has one torch and
  three plates.
- [ ] **Step 6: Tests** (`test_repair_torch.gd`):
  - holding mends 25 hp/s at 1 feed per hp;
  - an empty hopper does nothing;
  - out of reach stops it;
  - a plate takes 1.5 s, is freed and adds 100, and is refused when full;
  - a rebuild takes 3 s and 100 feed and comes back wrecked;
  - the droid is revived;
  - feed round-trips through `save()`.
- [ ] **Step 7: Suite green. Commit** `feat: the repair torch, fed with scrap plates`.

---

### Task 11: Saving and the HUD

**Files:** `flight_test.gd`, `save_*`, `src/ui/…`, `ship.gd`; extend `test_save_codec.gd` and the
HUD tests.

- [ ] **Step 1: Saving:**
  - `DamageLog.busy` is a gate source;
  - the avatar's `busy()` already carries *blacked out* and *welding*;
  - the save parts gain `"you"` → `health` and a top-level `"npcs"` → `NpcLedger.to_dict()`;
  - each live record's health is written back on save through the directors;
  - round-trip test for all three.
- [ ] **Step 2: The band.** `VehicleTelemetry` gains `hull: float` (1 − total damage / total hp,
  kept blocks only), `crippled: bool` and `crippled_reason: String`. A new `HullPanel` element in
  the band's reserved space shows `HULL 87%`, and `CRIPPLED · NO THRUST` in the warning colour
  when crippled. Test `render()` with made-up telemetry, as the other panels are.
- [ ] **Step 3: On foot and on a spacewalk,** the hurt edge (Task 6) is the only health display.
  There is no bar (§7.1).
- [ ] **Step 4: Suite green. Commit** `feat: damage is saved, and the band shows the hull`.

---

### Task 12: Live checks, tuning and the docs

- [ ] **Step 1: The live checks from §11.2,** in the real game, each recorded in the task report
  with numbers:
  - ram rocks at 3, 5 and 8 m/s and list what broke; tune `CRASH_K` and `CRASH_FROM` with the
    owner;
  - get bitten, black out on a rock, and wake aboard; the QE is gone and the item is left as a
    stray;
  - shoot the droid down, watch it reboot, shoot it down again, and weld it round;
  - wreck a thruster, see CRIPPLED, load the torch with a plate, go out, and weld it back;
  - blow a hull block off, catch the shed plate, and rebuild the block.
- [ ] **Step 2: Profile** a crash that removes three blocks at once. If the rebuild frame is over
  8 ms, report it with the number; per-cell rebuilds are "later" (§14).
- [ ] **Step 3: Renders for the owner** at 1.6 m: every stage inside and out, sparks, a hole, the
  torch in hand and welding, a dead skitter, and the droid knocked out.
- [ ] **Step 4: The skills:**
  - **`building-a-ship`:**
    - checklist: every block has a sensible `hp`; `KEEP` blocks; a layout where losing one block
      doesn't split off half the ship;
    - *Mistakes already made*: `hp_current` sat at 0 on every block (the reason for `damage`);
      the scriptless hull (the `receive_hit` meta relay);
    - `reference.md`: stages, crippled, crash numbers, torch numbers, `BlockDamage`/`ShipCells`
      APIs;
    - `ship_probe.gd`: lines for "intact hp total", "crippled as built: no", and "every block
      joined to the core".
  - **`building-an-npc`:**
    - checklist: `max_health`, and whether it dies or is knocked out;
    - *Mistakes already made*: whatever the build hits;
    - `reference.md`: health numbers, `NpcLedger`, `amend`, and the `defend` behaviour as a
      template for an NPC that fights back.
- [ ] **Step 5: The spec:** set the status to built, and add *How the build differs* covering:
  - every airlock is kept (Task 2);
  - the interior is re-dressed rather than one cell's mesh (Task 5);
  - the closet stock change (Task 10);
  - the tuned numbers.

  Amend the slice-1 spec's roadmap: Slice 2 is split into Damage and First Blood.
- [ ] **Step 6: Suite green. Commit** `docs: record health and damage -- as built, the skills`.

---

## Definition of done

- Every task's tests pass, and the whole suite is green and pristine, headless.
- `test_visual_style_rules.gd`, `test_floating_origin_scene.gd` and `test_npc_catalog.gd` are
  green without being changed to pass.
- The owner has seen the renders (Tasks 5, 7, 12) and approved the colours.
- The live checks in Task 12 are done in the real game, with their numbers in the report.
- Both skills and the spec are updated in this branch.
