# NPC Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A reusable foundation for NPCs (records, directors, bodies, senses, a mind and species
data), proven by two NPCs built only from its parts: a maintenance droid aboard the ship, and the
skitter, a shy grazer on the big rocks outside.

**Architecture:**
- An NPC is an `NpcRecord` (pure data from a seeded population recipe) until an `NpcDirector`
  makes it a live `Npc` (a pooled `CharacterBody3D`). There is one director and one `StimulusBus`
  per space: the exterior, and each ship's interior.
- The `Npc` owns a `Brain` (needs and scored `Behaviour`s), a `Perception` feeding an `NpcMemory`,
  and one active `Locomotor`. The brain writes an `Intent`; the locomotor follows it. The brain never
  touches physics and never reads the world, only its memory and needs.
- An `NpcSite` adapter, made by the population recipe, is the one thing that knows the place: its
  frame, its gravity, and the helpers a behaviour may ask for (herd mates, shelter, work spots, the
  dock).
- Species are `.tres` files (`NpcSpecies`) naming their locomotors, behaviours, look and population
  by id. `NpcBehaviours`, `Npc.make_locomotor` and `NpcLooks` turn ids into objects.

**Tech Stack:** Godot 4.5.1 (.NET build, GDScript only), GUT 9, `run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-09-26-npc-foundation-design.md`. Read it first. Section
numbers below (§) are that spec's unless they say otherwise.

## Global Constraints

- **The numbers, from the spec:**
  - physics layer 8, named `npcs`, bit **128**;
  - `Npc` masks: outside `1 | 4 | 32 | 64` (**101**), inside `2 | 4 | 32` (**38**);
  - senses and brains think at **5 Hz**, staggered over **12** groups; movement at the physics rate;
  - the brain's sticking bonus is **1.25×**;
  - `MAX_LIVE`: **32** outside, **8** inside;
  - skitter: 0.7–1.0 m long, 25 kg, crawl 1.2 m/s calm and 4 m/s bolting, leap up to 30 m at 6 m/s,
    sight 40 m in a 220° cone (13 m in the dark), live radius 350 m, demoted beyond 450 m, fade
    300 → 250 m, 0–3 herds per big rock of 3–7 each, a round of 3–5 places over 20–40 minutes;
  - crawler grip 4 m/s², settling its up direction in about 0.15 s; grip fails on footing faster
    than 3 m/s;
  - droid: 0.55 m tall, 0.5 m across, 40 kg, 1.0 m/s ambling and 1.8 m/s hurrying, sight 8 m in a
    140° cone, hearing 10 m (an item's impact) and 15 m (a plasma hit), one per ship with 12 or more
    walkable cells;
  - droid grip: 8 m/s² walking, 10 m/s² braced (the felt shove is capped at 12, a full burn is
    about 5.7);
  - all NPC work at most **1 ms a frame** with 32 live outside and the droid inside.
- **Visual style** (`docs/design/visual-style.md`, binding):
  - the skitter's colours only from `SpacePalette`, the droid's only from `InteriorPalette`; add
    constants there, never a new palette;
  - the droid builds like a prop from `(kit, frame, variety)` and never sees the grid;
  - no new shader; the droid's eye is the kit's `GLOW` batch, and it has no light of its own;
  - skitters on render layer 1, the droid on render layer 2;
  - `test_visual_style_rules.gd` must stay green; if it fails, fix the code, not the test.
- **Floating origin** (CLAUDE.md): every live NPC outside joins `Universe.EXTERIOR_SPACE` itself,
  under a holder that never moves. Positions an NPC keeps are site-local (a rock's frame, the
  interior's frame), never engine `Vector3`s. The exterior `StimulusBus` subtracts
  `Universe.shifted`'s delta from its live stimuli. Inside, nothing joins the group.
- **`.tscn`/`.tres`:** no `#` comments anywhere. This plan adds two `.tres` (`data/npcs/`) and edits
  no scene: the directors and buses are created in code. Prove each `.tres` by reading its
  properties back in a test.
- **Tests:** GUT, headless, output pristine. From the worktree root in PowerShell:
  - everything: `& .\who-knows\run_tests.ps1`;
  - one script: `& .\who-knows\run_tests.ps1 '-gselect=test_deck_paths'` (quote the argument).
- **After adding a `class_name`,** run the import pass before tests, and commit Godot's `.uid`
  files:
  `& "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path .\who-knows --import`
  (or `$env:GODOT_BIN` if set).
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Work in a sibling worktree,** `D:\git\whoknows-npcs` on branch `npc-foundation`, because other
  sessions share `D:\git\whoknows`:
  1. `git -C D:\git\whoknows switch main`
  2. `git -C D:\git\whoknows worktree add -b npc-foundation D:\git\whoknows-npcs main`
  3. Run the import pass there once, then the whole suite, and record the baseline count.
- **Code style:** match the surrounding GDScript. British spelling in comments ("colour",
  "behaviour", "centre"). Doc comments (`##`) say what and why, plainly, citing spec sections.
- **Renders:** visual work is verified by rendering the real scene and showing the owner (CLAUDE.md):
  the droid at eye height (1.6 m) aboard, the skitter from a spacewalk.
- **The building-a-ship skill:** the droid is a system every ship has to fit (a dock, reachable work
  spots). Task 11 updates `.claude/skills/building-a-ship/` in this branch, as CLAUDE.md requires.

## Names this plan builds on

Open each file and confirm these before starting. If one differs, note the built name in your task
report and use it throughout.

| Name | Where | Used by |
|---|---|---|
| `Ship.interior`, `Ship.interior_builder`, `Ship._rebuild_everything()`, `Ship._bind_airlocks()` (the pattern for a code-made child that survives rebuilds), `Ship.hull_struck(knock)`, `Ship._on_hull_struck(body)` | `src/ship/ship.gd` | Tasks 4, 5 |
| `InteriorBuilder.layout()`, `walkable_coords()`, `gravity_at(coord)`, `felt_gravity: FeltGravity`, static `floor_y(coord)`, `interior_center(coord)`, `storey_at(y)` | `src/ship/interior_builder.gd` | Tasks 3, 4 |
| `FeltGravity.felt: Vector3` | `src/ship/felt_gravity.gd` | Task 4 |
| `InteriorLayout.faces()` (records `{coord, normal, kind, variant, zone, porthole, ...}`), `rooms()`, `fixtures()`, `pods()`, `zone_at(coord)`, `Kind`, `WallVariant`, `AIRLOCK_ZONE`, `HELM_ID`, `ROOM_IDS` | `src/ship/interior/interior_layout.gd` | Task 3 |
| `SlidingDoor.AVATAR_MASK` (the trigger's mask) | `src/ship/interior/sliding_door.gd` | Task 4 |
| `Avatar.COLLISION_MASK`, `Avatar.SUIT_MASK`, `Avatar.SUIT_MASS`, `Avatar.bump(before, slid, hits)`, `Avatar._bump_in_space(before)`, `Avatar.mode`, `Avatar.Mode.SUIT` | `src/avatar/avatar.gd` | Tasks 4, 5, 9 |
| `Item.MASK`, `Item.LAYER`, `Item.State`; `Grasp.throw(amount)` | `src/items/item.gd`, `src/avatar/grasp.gd` | Tasks 4, 5 |
| `PlasmaBolt.RAY_MASK`, `PlasmaBolt.impact(result)`; `PlasmaEmitter.RAY_MASK` | `src/items/plasma_bolt.gd`, `src/items/plasma_emitter.gd` | Tasks 4, 5 |
| `HandLamp.on`, `HandLamp.RANGE`, `HandLamp.ANGLE`; `Flare.burn`, `Flare.Burn.BURNING`, `Flare.RANGE` | `src/items/hand_lamp.gd`, `src/items/flare.gd` | Task 5 |
| `MotionCoupling.drive_felt_gravity(shove)`, `SHOVE_CAP` | `src/camera/motion_coupling.gd` | Task 5 |
| `FlightComputer.commanded_force_local` | `src/flight/flight_computer.gd` | Task 5 |
| `AsteroidBody.LAYER`, `AsteroidBody.MASK`; `AsteroidDetail.rock`, `.data`; `AsteroidDetails.live` (id → `AsteroidDetail`); `AsteroidStream.details`, `AsteroidStream.SPACE_ANCHOR` | `src/world/` | Tasks 4, 8, 9 |
| `RockDetail.surface_point(d)`, `RockDetail.craters` (`[unit direction, angular radius]`), `RockDetail.radius_at(d)` | `src/world/rock_detail.gd` | Task 8 |
| `AsteroidRock.id()`, `AsteroidRock.colour`, `AsteroidRock.radius`, `AsteroidRock.shape`; `RockMesh.Shape` | `src/world/` | Task 8 |
| `InteriorKit` (`Batch.SOLID`, `Batch.GLOW`, `bevel_box`, `tube_between`, `disc`, `commit()`, `solid(c)`, `lit(c, energy)`), `InteriorMaterials.GLOW_ENERGY` | `src/ship/interior/` | Task 7 |
| `Synth.NAMES`, `Synth.LOOPED`, `Synth.build()` and its helpers (`_len`, `_noise`, `_lowpass`, `_gain`) | `src/audio/synth.gd` | Task 7 |
| `ShipGrid.CELL_SIZE`, `ShipGrid.cell_center(coord)` | `src/ship/ship_grid.gd` | Task 3 |

---

## File Structure

| File | Responsibility |
|---|---|
| Create `who-knows/src/npc/npc_record.gd` | `NpcRecord`: one NPC as data. |
| Create `who-knows/src/npc/npc_species.gd` | `NpcSpecies extends Resource`. |
| Create `who-knows/src/npc/npc_catalog.gd` | `NpcCatalog`: loads `data/npcs/*.tres`. |
| Create `who-knows/data/npcs/maintenance_droid.tres`, `skitter.tres` | The two species. |
| Create `who-knows/src/npc/intent.gd` | `Intent`: what the brain wants the body to do. |
| Create `who-knows/src/npc/stimulus.gd`, `stimulus_bus.gd` | `Stimulus`, `StimulusBus`. |
| Create `who-knows/src/npc/npc_memory.gd` | `NpcMemory`: percepts that fade. |
| Create `who-knows/src/npc/perception.gd` | `Perception`: senses into memory. |
| Create `who-knows/src/npc/npc_context.gd` | `NpcContext`: all a behaviour may read. |
| Create `who-knows/src/npc/curves.gd` | `Curves`: response curves. |
| Create `who-knows/src/npc/behaviour.gd`, `npc_behaviours.gd`, `behaviours/*.gd` | `Behaviour`, the id → class table, each behaviour. |
| Create `who-knows/src/npc/brain.gd` | `Brain`: needs, reflexes, scoring. |
| Create `who-knows/src/npc/locomotor.gd`, `deck_walker.gd`, `surface_crawler.gd`, `zero_g_drift.gd` | Locomotors. |
| Create `who-knows/src/npc/npc_site.gd` | `NpcSite`: what a place tells its NPCs. |
| Create `who-knows/src/npc/npc.gd` | `Npc extends CharacterBody3D`. |
| Create `who-knows/src/npc/npc_director.gd` | `NpcDirector`: promote, demote, pool, schedule. |
| Create `who-knows/src/npc/deck_paths.gd` | `DeckPaths`: A* over an interior's cells. Pure. |
| Create `who-knows/src/npc/populations/ship_crew.gd`, `ship_site.gd` | `ShipCrew` (pure), `ShipSite`. |
| Create `who-knows/src/npc/populations/rock_herds.gd`, `rock_site.gd` | `RockHerds` (pure), `RockSite`. |
| Create `who-knows/src/npc/npc_looks.gd`, `legged_gait.gd` | The droid and the skitter; the gait. |
| Create `who-knows/src/npc/npc_debug.gd` | The overlay (F4). |
| Modify `who-knows/project.godot` | Layer 8 `npcs`. |
| Modify `who-knows/src/ship/ship.gd` | The interior's director and bus; hull strikes as vibration. |
| Modify `who-knows/scenes/flight_test.gd` | The exterior's director and bus; the overlay. |
| Modify `src/avatar/avatar.gd`, `src/items/item.gd`, `src/items/plasma_bolt.gd`, `src/items/plasma_emitter.gd`, `src/world/asteroid_body.gd`, `src/ship/interior/sliding_door.gd` | Masks (Task 4); emitters and bumps (Tasks 5, 9). |
| Modify `src/items/hand_lamp.gd`, `src/items/flare.gd`, `src/avatar/grasp.gd`, `src/camera/motion_coupling.gd` | Emitters (Task 5). |
| Modify `who-knows/src/world/space_palette.gd`, `who-knows/src/ship/interior/interior_palette.gd` | NPC colours. |
| Modify `who-knows/src/audio/synth.gd` | `droid_whir`, `droid_chirp`, `droid_beep`. |
| Tests | New: `test_npc_species`, `test_npc_director`, `test_deck_paths`, `test_ship_crew`, `test_deck_walker`, `test_npc_layers`, `test_stimulus_bus`, `test_perception`, `test_brain`, `test_droid_behaviours`, `test_npc_looks`, `test_droid_scene`, `test_rock_herds`, `test_exterior_npcs`, `test_surface_crawler`, `test_zero_g_drift`, `test_skitter_behaviours`, `test_legged_gait`. Extended: `test_floating_origin_scene`, `test_sliding_door`, `test_synth`, `test_visual_style_rules`, `test_avatar`. |
| Docs | The spec (status, as built), the visual style guide (an NPC section), `SLICE-1-STATUS`, the building-a-ship skill. |

---

### Task 1: Records, species and the vocabulary

**Files:**
- Create: `src/npc/npc_record.gd`, `src/npc/npc_species.gd`, `src/npc/npc_catalog.gd`,
  `src/npc/intent.gd`, `src/npc/stimulus.gd`, `data/npcs/maintenance_droid.tres`,
  `data/npcs/skitter.tres`, `test/unit/test_npc_species.gd`
- Modify: `project.godot` (`[layer_names]`)

- [ ] **Step 1: Name the layer.** In `project.godot`, under `[layer_names]`, add
  `3d_physics/layer_8="npcs"`.

- [ ] **Step 2: `NpcRecord`.**

```gdscript
class_name NpcRecord
extends RefCounted

## One NPC as data (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §4.1): who it is, what it is, and where it lives in its site's own frame. No
## node: population recipes make these on any thread, and the same place always
## makes the same ones.

var id: StringName
var species: StringName
## The place it belongs to: a big rock, a ship.
var site: StringName
## Where it lives, in its site's frame: a rock's local coordinates, a ship's
## interior. Never an engine position: those move with the floating origin.
var home := Vector3.ZERO
## Its own randomness: size, colour, temperament.
var seed := 0
## Which group it belongs to at its site, or -1.
var herd := -1

static func make(p_id: StringName, p_species: StringName, p_site: StringName, p_home: Vector3,
		p_seed: int, p_herd := -1) -> NpcRecord:
	var r := NpcRecord.new()
	r.id = p_id
	r.species = p_species
	r.site = p_site
	r.home = p_home
	r.seed = p_seed
	r.herd = p_herd
	return r
```

- [ ] **Step 3: `Intent`.**

```gdscript
class_name Intent
extends RefCounted

## What the brain wants the body to do until its next think (spec §5.2). The
## locomotor follows it every physics tick. Points are site-local.

## Where to go, or null to stay.
var move_to: Variant = null
## What to look at, or null to look where it is going.
var face: Variant = null
## A fraction of the species' top speed.
var speed := 0.0
## Played by the look; some locomotors act on it too (&"leap", &"brace").
var action: StringName = &""

static func idle(p_action: StringName = &"") -> Intent:
	var i := Intent.new()
	i.action = p_action
	return i

static func go(to: Vector3, p_speed: float, p_action: StringName = &"") -> Intent:
	var i := Intent.new()
	i.move_to = to
	i.speed = p_speed
	i.action = p_action
	return i

func facing(at: Vector3) -> Intent:
	face = at
	return self
```

- [ ] **Step 4: `Stimulus`.**

```gdscript
class_name Stimulus
extends RefCounted

## Something the world gives off that an NPC might notice (spec §6.1). Short
## lived: the bus drops it at `until`. Position is in engine space; outside,
## the bus moves it with the floating origin.

const LIGHT := &"light"
const VIBRATION := &"vibration"
const SOUND := &"sound"
const TOUCH := &"touch"
const SHAKE := &"shake"

var kind: StringName
var position := Vector3.ZERO
## How strong at its source, 0-1.
var strength := 1.0
## How far it carries, metres. SHAKE ignores it: it reaches the whole space.
var radius := 10.0
## For VIBRATION: the rock it travels through (RockHerds.site_of()).
var site: StringName = &""
var source: Node
## When the bus took it, and when it drops it.
var at := 0.0
var until := 0.0

static func make(p_kind: StringName, p_position: Vector3, p_strength: float, p_radius: float,
		p_source: Node = null, p_site: StringName = &"") -> Stimulus:
	var s := Stimulus.new()
	s.kind = p_kind
	s.position = p_position
	s.strength = p_strength
	s.radius = p_radius
	s.source = p_source
	s.site = p_site
	return s

## How strongly it is felt at `point`: full at the source, nothing at radius.
func felt_at(point: Vector3) -> float:
	if kind == SHAKE:
		return strength
	return strength * clampf(1.0 - position.distance_to(point) / radius, 0.0, 1.0)
```

- [ ] **Step 5: `NpcSpecies`.** Every field `@export`ed, grouped as spec §8:

```gdscript
class_name NpcSpecies
extends Resource

## One kind of NPC, as data (spec §8): its body, senses, needs, mind and where
## it lives. A new creature is one of these, a look, and at most a behaviour
## or two. Ids name code: NpcBehaviours, Npc.make_locomotor and NpcLooks turn
## them into objects.

@export var id: StringName
@export var display_name: String
@export_group("Body")
## Length, metres (its longest side).
@export var size := 1.0
## For bumps, kg.
@export var mass := 25.0
@export var top_speed := 2.0
## The first is the one it starts with.
@export var locomotors: Array[StringName] = []
@export var look: StringName
@export_group("Senses")
@export var sight_range := 20.0
@export var sight_cone_deg := 180.0
## Sight in the dark as a fraction of sight_range (outside only; inside is lit).
@export var dark_sight := 1.0
## 0 feels no vibration; 1 feels a stimulus to its full radius.
@export var feels_vibration := 0.0
@export var hears := 0.0
@export var feels_shake := 0.0
## -1 freezes or flees in light ... +1 is drawn to it.
@export var light_response := 0.0
@export_group("Needs")
## Need -> how fast it rises by itself, per second.
@export var needs: Dictionary = {}
## Need -> the range it starts in, Vector2(min, max).
@export var need_start: Dictionary = {}
@export_group("Mind")
@export var behaviours: Array[StringName] = []
## Behaviour -> weight; missing means 1.
@export var behaviour_weights: Dictionary = {}
@export_group("Disposition")
@export var fear_of_player := 0.0
@export var curiosity_about_player := 0.0
@export_group("World")
@export var population: StringName
@export var live_radius := 0.0
## Fully drawn within x, gone beyond y; (0, 0) for no fade (inside).
@export var fade := Vector2.ZERO
@export_group("Interactions")
## Empty in this build (spec §12.4).
@export var interactions: Array[StringName] = []
```

- [ ] **Step 6: `NpcCatalog`**, modelled on `ItemCatalog` (`load_from_dir(path)`, `get_def(id)`,
  `ids()`), reading `data/npcs/*.tres`.

- [ ] **Step 7: The two `.tres`.** Write them by hand, **no `#` comments**. Values:

  | Field | `maintenance_droid` | `skitter` |
  |---|---|---|
  | `size`, `mass`, `top_speed` | 0.55, 40, 1.8 | 0.85, 25, 4.0 |
  | `locomotors` | `[&"deck_walker"]` | `[&"surface_crawler", &"zero_g_drift"]` |
  | `look` | `&"droid"` | `&"skitter"` |
  | `sight_range`, `sight_cone_deg`, `dark_sight` | 8, 140, 1.0 | 40, 220, 0.33 |
  | `feels_vibration`, `hears`, `feels_shake` | 0, 1, 1 | 1, 0, 0 |
  | `light_response` | 0 | -1 |
  | `needs` (rise/s) | `duty` 0.02, `charge` 0.004, `curiosity` 0.01, `fear` 0 | `hunger` 0.006, `company` 0.01, `curiosity` 0.008, `rest` 0.003, `fear` 0 |
  | `need_start` | `duty` (0.3, 0.7), `charge` (0, 0.3), others (0, 0.1) | `hunger` (0.2, 0.6), `rest` (0, 0.4), others (0, 0.1) |
  | `behaviours` | `tend, roam, recharge, give_way, notice, startle, brace, keep_away` | `graze, wander, stay_with_herd, freeze, scatter, hide, investigate, rest, drawn_to_flare` |
  | `fear_of_player`, `curiosity_about_player` | 0.1, 0.6 | 0.5, 0.4 |
  | `population` | `&"ship_crew"` | `&"rock_herds"` |
  | `live_radius`, `fade` | 0, (0, 0) | 350, (250, 300) |

- [ ] **Step 8: Test.** `test_npc_species.gd`: the catalogue finds both ids; **every property in the
  table reads back as authored** (the CLAUDE.md `.tres` rule); every behaviour id is known to
  `NpcBehaviours` (write this assertion now, commented as pending, and enable it in Task 6); every
  locomotor id to `Npc.make_locomotor` (enable in Task 2); the layer name reads back from
  `ProjectSettings.get_setting("layer_names/3d_physics/layer_8") == "npcs"`.

- [ ] **Step 9:** Import pass, run the suite, commit: `feat: NPC records, species data and the
  vocabulary`.

---

### Task 2: The `Npc`, the director and the site

**Files:**
- Create: `src/npc/npc.gd`, `src/npc/locomotor.gd`, `src/npc/npc_site.gd`,
  `src/npc/npc_director.gd`, `test/unit/test_npc_director.gd`

- [ ] **Step 1: `Locomotor`.** A `RefCounted` base:

```gdscript
class_name Locomotor
extends RefCounted

## Turns the brain's intent into motion in one medium (spec §5). One is active
## at a time; it can ask to hand over (a crawler knocked into space asks for
## &"zero_g_drift").

var id: StringName

func enter(_npc: Npc) -> void:
	pass

## One physics tick.
func step(_npc: Npc, _intent: Intent, _delta: float) -> void:
	pass

func exit(_npc: Npc) -> void:
	pass

## The locomotor it wants to hand over to, or &"" to stay.
func handover(_npc: Npc) -> StringName:
	return &""
```

- [ ] **Step 2: `NpcSite`.** A `RefCounted` base the population recipes subclass:

```gdscript
class_name NpcSite
extends RefCounted

## What a place tells its NPCs (spec §4): its frame, its gravity, whether it
## still exists, and the helpers its behaviours ask for. The only thing that
## knows the place: the brain and the locomotors ask the site.

var id: StringName

## Site-local to engine space.
func frame() -> Transform3D:
	return Transform3D.IDENTITY

## Engine-space gravity at a site-local point, m/s^2.
func gravity(_local: Vector3) -> Vector3:
	return Vector3.ZERO

## False once the place is gone (a rock out of detail, a ship torn down).
func alive() -> bool:
	return true

## Fills in what behaviours may ask of this place: mates, shelter, spots...
func fill(_ctx: NpcContext, _npc: Npc) -> void:
	pass
```

  (`NpcContext` is created in Task 6; until then give `fill` an untyped `_ctx`.)

- [ ] **Step 3: `Npc`.** `class_name Npc extends CharacterBody3D`. Fields: `record: NpcRecord`,
  `species: NpcSpecies`, `site: NpcSite`, `inside: bool`, `intent: Intent`, `locomotors:
  Dictionary` (id → `Locomotor`), `active: Locomotor`, `look: Node3D`, `skin: Area3D`.
  - `const LAYER := 128`, `const MASK_OUTSIDE := 1 | 4 | 32 | 64`, `const MASK_INSIDE := 2 | 4 | 32`.
  - `_init()`: `collision_layer = LAYER`, a `CapsuleShape3D` collider (sized in `setup` from
    `species.size`), `motion_mode = MOTION_MODE_FLOATING` (each locomotor sets it as it needs).
  - `setup(p_record, p_species, p_site, p_inside)`: sets the fields; `collision_mask` from `inside`;
    joins `Universe.EXTERIOR_SPACE` if outside and leaves it if inside; resizes the collider; builds
    `locomotors` with `make_locomotor(id)` for each of `species.locomotors` and enters the first;
    builds the look with `NpcLooks.build(species.look, record.seed)` (Task 7; until then a
    placeholder `BoxMesh` sized to the species, on render layer 1 or 2 by `inside`); places itself at
    `site.frame() * record.home`; zeroes velocity. Called for every record a pooled node becomes.
  - `static func make_locomotor(id: StringName) -> Locomotor`: a `match` over ids, returning `null`
    and `push_error` for an unknown one. Add each locomotor here as it is written.
  - `switch_to(id)`: exits the active locomotor, enters the named one.
  - `_physics_process(delta)`: if `intent != null`, `active.step(self, intent, delta)`; then asks
    `active.handover(self)` and switches if it names one.
  - `local_position() -> Vector3`: `site.frame().affine_inverse() * global_position`.
  - `receive_hit(hit: Hit)`: records a touch (Task 5 wires it into perception) and passes the
    impulse to `shove(hit.impulse)`.
  - `shove(impulse: Vector3)`: `velocity += impulse / species.mass`. Locomotors decide what a shove
    does to their grip.
  - **The interaction seam** (spec §12.4): `interact(actor)`, `prompt_text() -> String` and
    `can_interact(actor) -> bool`, which returns `false` while `species.interactions` is empty. Do
    not add the node to group `interactable` and do not change the `Interactor`'s mask.
  - `think(time, dt)` is a stub until Task 6.

- [ ] **Step 4: `NpcDirector`.** `class_name NpcDirector extends Node`.

```gdscript
enum Rule { BY_DISTANCE, BY_SITE }

## Outside: live within a species' live_radius of an anchor (spec §4.3).
## Inside: every record of the site while the site is alive.
var rule := Rule.BY_DISTANCE
var max_live := 32
## Where live NPCs are parented. Never moves.
var holder: Node3D
var catalog: NpcCatalog
## Its own clock, seconds. There is no universe time; rounds read this.
var time := 0.0
## id -> Npc
var live := {}
## Anything with records(director) -> Array[[NpcRecord, NpcSite]]:
## the records it may make live now.
var sources: Array = []

const THINK_HZ := 5.0
const GROUPS := 12
const DEMOTE_MARGIN := 100.0
const REVIEW_EVERY := 0.25
```

  - `_physics_process(delta)`: `time += delta`. Every `REVIEW_EVERY` s, `review()`. Every tick,
    think for one twelfth of the live NPCs: group `g = tick % GROUPS` thinks when
    `hash(npc.record.id) % GROUPS == g`, and a group comes round `THINK_HZ` times a second (at 60 Hz
    physics, advance `g` every tick and let each group's turn come every `60 / (THINK_HZ)` ticks:
    compute from `Engine.physics_ticks_per_second` so tests at other rates still hold). Each think
    gets `dt = 1.0 / THINK_HZ`.
  - `review()`:
    1. Gather wanted records from every source.
    2. `amend(record)` on each (spec §4.5: returns the record unchanged in this build; one line and
       a doc comment saying where a ledger plugs in).
    3. **BY_SITE:** promote every wanted record not live; demote every live one no longer wanted or
       whose `site.alive()` is false.
    4. **BY_DISTANCE:** for each wanted record, its engine position `site.frame() * home`, and its
       distance to the nearest node in group `AsteroidStream.SPACE_ANCHOR`. Promote within
       `species.live_radius`. Demote a live NPC when its site is not alive, or when it is beyond
       `live_radius + DEMOTE_MARGIN` **and** it could not be seen: beyond `species.fade.y` from every
       exterior camera, or outside every camera's frustum (`Camera3D.is_position_in_frustum`). The
       cameras are passed in (`director.cameras: Array[Camera3D]`), so tests need none.
    5. Over `max_live`: demote the farthest first, with one `push_warning` per review.
  - `promote(record, site) -> Npc`: a node from the pool for that species (or a new one), `setup`,
    added under `holder`, into `live`. Inside, only once the site says it is ready (`site.alive()`).
  - `demote(npc)`: out of `live`, removed from `holder`, back into the pool (not freed).
  - `_exit_tree()`: free the pool.

- [ ] **Step 5: Test.** `test_npc_director.gd`, with a fake source and a fake site (a `RefCounted`
  with a fixed frame) and a placeholder species built in the test:
  - BY_SITE: two records promote at once; removing one from the source demotes it; a dead site
    demotes both; demoted nodes are reused by the next promotion (same instance id);
  - BY_DISTANCE: an anchor node at the origin in group `SPACE_ANCHOR`; a record at 300 m promotes, at
    400 m does not; moved to 420 m it stays (hysteresis); at 460 m with no cameras it demotes; with a
    camera looking at it and within fade it does not;
  - `max_live` = 2 with three wanted: the farthest is not promoted, and one warning is logged;
  - `amend` is called once per promotion (count it with a subclass);
  - live NPCs outside are in `Universe.EXTERIOR_SPACE`; inside they are not;
  - thinking: with 24 live and 60 ticks, each NPC thinks 5 times (count in a subclass of `Npc`).

- [ ] **Step 6:** Import, run, commit: `feat: Npc, NpcDirector and NpcSite -- records far, nodes near`.

---

### Task 3: Paths over the interior, and the ship's crew

**Files:**
- Create: `src/npc/deck_paths.gd`, `src/npc/populations/ship_crew.gd`,
  `test/unit/test_deck_paths.gd`, `test/unit/test_ship_crew.gd`

- [ ] **Step 1: `DeckPaths`** (pure, spec §5.5):

```gdscript
class_name DeckPaths
extends RefCounted

## Paths over an interior's cells (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §5.5). Two walkable cells on one storey
## are joined where InteriorLayout put no wall between them: open floor, and
## each room's doorway. The layout already knows every wall, so a 2 m cell
## graph is exact, tiny and the same every time. No navmesh.
##
## Pure: reads the layout, touches no nodes.

const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _links := {}   # Vector3i -> Array[Vector3i]

## The walkable cells of `layout` minus the airlock, every fixture's cell and
## anything in `avoid` (cells without plating, say).
static func build(layout: InteriorLayout, avoid: Array[Vector3i] = []) -> DeckPaths:
	var paths := DeckPaths.new()
	var blocked := {}
	for cell in avoid:
		blocked[cell] = true
	for f in layout.fixtures():
		blocked[f["coord"]] = true
	var cells := {}
	for cell in layout.walkable_coords():
		if not blocked.has(cell) and layout.zone_at(cell) != InteriorLayout.AIRLOCK_ZONE:
			cells[cell] = true
	var shut := {}   # "coord|normal" of every face that is not a way through
	for face in layout.faces():
		if face["kind"] != InteriorLayout.Kind.DOORWAY:
			shut["%s|%s" % [face["coord"], face["normal"]]] = true
	for cell: Vector3i in cells:
		var out: Array[Vector3i] = []
		for n in _HORIZONTAL:
			var next := cell + n
			if cells.has(next) and not shut.has("%s|%s" % [cell, n]):
				out.append(next)
		paths._links[cell] = out
	return paths

func has(cell: Vector3i) -> bool:
	return _links.has(cell)

func cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(_links.keys())
	out.sort()
	return out

func neighbours(cell: Vector3i) -> Array[Vector3i]:
	return _links.get(cell, [] as Array[Vector3i])

## The cells from `from` to `to`, both included; empty if there is no way.
func path(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	if not has(from) or not has(to):
		return []
	var came := {from: from}
	var cost := {from: 0}
	var open: Array[Vector3i] = [from]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if cost[open[i]] + _h(open[i], to) < cost[open[best]] + _h(open[best], to):
				best = i
		var cell: Vector3i = open[best]
		open.remove_at(best)
		if cell == to:
			break
		for next in neighbours(cell):
			var c: int = cost[cell] + 1
			if not cost.has(next) or c < cost[next]:
				cost[next] = c
				came[next] = cell
				if not open.has(next):
					open.append(next)
	if not came.has(to):
		return []
	var out: Array[Vector3i] = [to]
	while out[0] != from:
		out.push_front(came[out[0]])
	return out

## Steps from `from` to every cell it can reach.
func distances(from: Vector3i) -> Dictionary:
	var out := {from: 0}
	var frontier: Array[Vector3i] = [from]
	while not frontier.is_empty():
		var cell: Vector3i = frontier.pop_front()
		for next in neighbours(cell):
			if not out.has(next):
				out[next] = out[cell] + 1
				frontier.append(next)
	return out

## The cell an interior-local point is in.
static func cell_at(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x / ShipGrid.CELL_SIZE), InteriorBuilder.storey_at(p.y),
		roundi(p.z / ShipGrid.CELL_SIZE))

## Where to stand in `cell`: its centre on the floor.
static func floor_point(cell: Vector3i) -> Vector3:
	var c := InteriorBuilder.interior_center(cell)
	c.y = InteriorBuilder.floor_y(cell)
	return c

static func _h(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.z - b.z)
```

  Check `cell_at` against `ShipGrid.cell_center` (it must invert it for x and z); if the grid's
  centres are offset, invert the offset here and say so in the doc comment.

- [ ] **Step 2: `ShipCrew`** (pure, spec §4.2, §14.2). A static class:
  - `const SPECIES := &"maintenance_droid"`, `const MIN_CELLS := 12`.
  - `static func dock(layout, paths) -> Vector3i`: the first reachable cell (sorted) of a room with
    zone `&"closet"`; otherwise the path cell farthest (by `paths.distances`) from the cells beside
    the helm; `Vector3i.MAX` if the paths are empty.
  - `static func work_spots(layout, paths) -> Array[Dictionary]`: `{cell, facing, action, key}`,
    sorted by `key`:
    - each `WALL` face whose `coord` is in `paths`: `porthole` true → `&"polish"`; variant
      `CONSOLE` or `DISPLAY` → `&"scan"`; `LOCKERS` → `&"tidy"`; others none. `facing` is the face's
      normal; `key` is `&"wall:%s|%s"`.
    - each fixture: the first (sorted) horizontal neighbour in `paths`, facing the fixture,
      `&"scan"`, key `&"fixture:%s"`. The helm is tended from beside it, never from its cell.
  - `static func records(layout, paths, ship: StringName, world_seed: int) -> Array[NpcRecord]`:
    none if `layout.walkable_coords().size() < MIN_CELLS` or no dock; otherwise one record, id
    `&"droid:%s:0" % ship`, home `DeckPaths.floor_point(dock)`, seed from
    `AsteroidRecipe.mix(world_seed ^ hash(ship))` (use the recipe's integer mix, not `hash()` on
    anything that must be stable).

- [ ] **Step 3: Tests.** Build the starter's grid and layout exactly as `test_interior_layout.gd`
  does (reuse its helper, or `flight_test.gd`'s `_starter_grid()` through the scene).
  - `test_deck_paths.gd`: the airlock cell `(0, 0, 3)` and the helm `(0, 0, -3)` are not in the
    paths; every other walkable cell is; the corridor `(0,0,0)–(0,0,2)` links fore and aft; each
    room cell links to the corridor only through its doorway (for each room, count links crossing
    its boundary: exactly one); a path from the closet to `(-1, 0, -3)` exists and never enters a
    room it does not start or end in; `path` to an unknown cell is empty; `cell_at(floor_point(c))
    == c` for every cell.
  - `test_ship_crew.gd`: the starter's dock is the closet `(1, 0, 2)`; one record with the pinned
    id; a grid with its closet made `deck` docks farthest from the helm; a 6-cell ship has no crew;
    every work spot's cell is reachable from the dock; there is at least one of each action on the
    starter (it has portholes, consoles and lockers; if the starter has no `LOCKERS` wall, pin what
    it has instead and say so); records are identical for the same seed.

- [ ] **Step 4:** Import, run, commit: `feat: DeckPaths and ShipCrew -- the droid's map and its
  place aboard`.

---

### Task 4: The `DeckWalker`, the ship's director and the layers

**Files:**
- Create: `src/npc/deck_walker.gd`, `src/npc/populations/ship_site.gd`,
  `test/unit/test_deck_walker.gd`, `test/unit/test_npc_layers.gd`
- Modify: `src/ship/ship.gd`, `src/avatar/avatar.gd`, `src/items/item.gd`,
  `src/items/plasma_bolt.gd`, `src/items/plasma_emitter.gd`, `src/world/asteroid_body.gd`,
  `src/ship/interior/sliding_door.gd`, `test/unit/test_sliding_door.gd`

- [ ] **Step 1: The layers** (spec §5.1). Add `Npc.LAYER` (128) to: `Avatar.COLLISION_MASK`,
  `Avatar.SUIT_MASK`, `Item.MASK`, `AsteroidBody.MASK`, the hull's mask in `Ship._ready()`
  (`1 | AsteroidBody.LAYER | Npc.LAYER`), `PlasmaBolt.RAY_MASK` and `PlasmaEmitter.RAY_MASK` (and any
  outside mask the bolt uses on a spacewalk: find it). Rename `SlidingDoor.AVATAR_MASK` to
  `OPENS_FOR := 4 | 128` with its doc comment updated; the door opens for anyone walking up, and
  still has no collider. Write each as the named constant, not the number, where a constant exists.

- [ ] **Step 2: `ShipSite`** (`extends NpcSite`): made by the ship for its interior.
  - `frame()`: `ship.interior.global_transform`.
  - `gravity(_local)`: `ship.interior_builder.felt_gravity.felt` (the same number every loose item
    gets: plating plus the hull's shove). Spec §5.1 said the droid would be in `FeltGravity`'s mask;
    reading `felt` is the same number with no physics query. Record this in the spec's as-built note
    (Task 11).
  - `alive()`: the interior is built (`ship.interior_builder.layout() != null`).
  - `paths: DeckPaths`, `spots: Array[Dictionary]`, `dock: Vector3i`, `tended: Dictionary` (spot key
    → time last tended), rebuilt by `rebind(layout)`.
  - `fill(ctx, npc)`: Task 6.

- [ ] **Step 3: `DeckWalker`** (`extends Locomotor`, id `&"deck_walker"`), spec §5.5:
  - `enter`: `npc.motion_mode = MOTION_MODE_GROUNDED`, `up_direction = Vector3.UP` (the interior is
    always upright; plating is down).
  - `step(npc, intent, delta)`:
    1. `npc.velocity += site.gravity(...) * delta` (the vertical part keeps it on the floor; the
       horizontal part is the hull's shove).
    2. If `intent.move_to` changed since the last step (compare with `is_equal_approx`), replan:
       `_path = paths.path(cell_at(npc.local_position()), cell_at(intent.move_to))`. An empty path
       means stay.
    3. The next waypoint: skip cells already reached (within 0.3 m of their `floor_point`), and cut
       a corner when the waypoint after is in plain line (both cells on a straight or diagonal
       step whose shared corners are both path cells). The last waypoint is `intent.move_to` itself.
    4. Desired horizontal velocity: towards the waypoint at `intent.speed * species.top_speed`,
       slowing within 0.5 m of the last one. `&"brace"` wants zero.
    5. Grip: move the horizontal velocity towards the desired one at `GRIP` (8 m/s²), or
       `BRACED_GRIP` (10 m/s²) while bracing. A shove beyond the grip slides it, like a crate.
    6. `move_and_slide()`.
    7. Turn (yaw only) towards `intent.face`, or the way it is going, at 4 rad/s.
  - Positions are interior-local through `npc.site.frame()`; the interior never moves, so there is
    nothing to shift.
  - A path through a cell that is no longer in `paths` (the ship was rebuilt) is replanned on the
    next step: `ShipSite.rebind` bumps a `version` the walker compares.

- [ ] **Step 4: The ship's director.** In `Ship`:
  - `_ready()`: an `npcs: Node3D` holder under `interior` (never moves), and an `NpcDirector` with
    `rule = BY_SITE`, `max_live = 8`, `holder = npcs`, the catalogue from `res://data/npcs`, and one
    source: the ship itself (`records(director)` below). Created in code, like `Airlocks`.
  - `var crew_site: ShipSite`, rebound at the end of `_rebuild_everything()` from
    `interior_builder.layout()`, with `avoid` = the walkable cells whose `gravity_at` is 0.
  - `func records(_director) -> Array`: `ShipCrew.records(layout, crew_site.paths, name, 0)` paired
    with `crew_site`, cached until the next rebuild.
  - A live droid survives a rebuild (the director keeps any record still wanted). If its cell is no
    longer walkable, put it at its dock.
  - Task 5 adds the interior's `StimulusBus` beside the director, in the same place.

- [ ] **Step 5: Tests.**
  - `test_npc_layers.gd`: every mask in spec §5.1 read back at runtime from the real scene: the
    droid's layer and mask, the avatar aboard and on a spacewalk, an item, a rock body, the hull, a
    door's trigger, the bolt's ray.
  - `test_deck_walker.gd` (the real flight scene, as `test_floating_origin_scene.gd` loads it): the
    droid is live at its dock after the first frames; with `intent = Intent.go(floor_point(-1, 0,
    -3), 1.0)` it arrives within 0.3 m in under 20 s of physics frames, having passed through the
    closet's doorway (the door's `is_open` went true); it never stands in the airlock or the helm's
    cell (sample every tick); with `felt_gravity.felt = DOWN * 9.8 + Vector3(12, 0, 0)` and no
    intent it slides; braced with a 9 m/s² shove it holds within 0.05 m over a second.
  - `test_sliding_door.gd`: the trigger's mask includes 128; a body on layer 128 opens it.

- [ ] **Step 6:** Import, run the whole suite (the mask changes touch many tests), commit:
  `feat: DeckWalker and the ship's director -- the droid walks the ship`.

---

### Task 5: Stimuli and perception

**Files:**
- Create: `src/npc/stimulus_bus.gd`, `src/npc/npc_memory.gd`, `src/npc/perception.gd`,
  `src/npc/populations/rock_herds.gd` (only `site_of` for now; Task 8 fills it),
  `test/unit/test_stimulus_bus.gd`, `test/unit/test_perception.gd`
- Modify: `src/npc/npc.gd`, `src/ship/ship.gd`, `src/items/hand_lamp.gd`, `src/items/flare.gd`,
  `src/items/plasma_bolt.gd`, `src/items/item.gd`, `src/avatar/grasp.gd`, `src/avatar/avatar.gd`,
  `src/camera/motion_coupling.gd`

- [ ] **Step 1: `StimulusBus`** (spec §6.1). `class_name StimulusBus extends Node`. `Ship._ready()`
  makes one for its interior (`setup(interior)`) beside its director and hands it to the director
  (`director.bus`):
  - `const GROUP := &"stimulus_bus"`, `const LIGHTS := &"npc_light"`.
  - `var space_root: Node3D`, `var now := 0.0`, `var _live: Array[Stimulus]`.
  - `setup(root: Node3D, universe: Universe = null)`: joins `GROUP`; connects `universe.shifted` to
    subtract the delta from every live stimulus's position (outside only).
  - `emit(s: Stimulus, lasts := 0.5)`: `s.at = now`, `s.until = now + lasts`, appended.
  - `since(t: float) -> Array[Stimulus]`: live stimuli with `at >= t`.
  - `lights() -> Array[Node3D]`: the nodes in group `LIGHTS` under `space_root`.
  - `_physics_process(delta)`: `now += delta`; drop stimuli past `until`.
  - `static func for_node(n: Node) -> StimulusBus`: of the buses in `GROUP`, the one with the deepest
    `space_root` that is an ancestor of `n` (an interior bus beats the exterior one for anything
    aboard, because the interior is under the scene root too). Null if none.
  - `static func send(from: Node, s: Stimulus, lasts := 0.5)`: `for_node(from)`, then `emit`. Every
    emitter calls this one line; with no bus (most unit tests) it does nothing.

- [ ] **Step 2: Lights** (spec §6.2). A light is a node in group `StimulusBus.LIGHTS` that answers
  `light_reach() -> float` (0 when off), `light_cone_deg() -> float` (180 for all round) and
  `light_origin() -> Transform3D` (shining along −z). `HandLamp`: joins in `_ready`, reach `RANGE`
  while `on`, cone `ANGLE`, origin its beam's global transform. `Flare`: reach `RANGE` while
  `BURNING`, cone 180, origin its light's.

- [ ] **Step 3: The emitters** (spec §6.1). One call to `StimulusBus.send` each:

  | Where | Stimulus |
  |---|---|
  | `PlasmaBolt.impact` | `SOUND` at the point, strength 1, radius 15; if the collider is an `AsteroidDetail` or `AsteroidBody`, also a `VIBRATION` with `site = RockHerds.site_of(rock)` (write `site_of` now in `rock_herds.gd` as a static, `&"rock:%d_%d_%d_%d"` from `rock.id()`), strength 0.8, radius 40 |
  | `Item`: new `watch_first_impact()` turns on `contact_monitor` (1 contact) until the first `body_entered`, then emits a `SOUND` (strength by speed / 6 m/s, radius 10) and turns it off. `Grasp.throw` calls it | `SOUND` |
  | `Avatar._physics_process`, aboard, sprinting and moving, every 0.5 s | `SOUND`, strength 0.4, radius 6 |
  | `Avatar._bump_in_space`, each slide collision with an `AsteroidDetail` or `AsteroidBody` closing faster than 0.3 m/s | `VIBRATION`, strength `clamp(closing / 3, 0, 1)`, radius 30, the rock's site |
  | `Ship._on_hull_struck`: also for an `AsteroidDetail` (static rocks report through `body_entered` too); pass the knock | `VIBRATION`, strength `clamp(knock / 4, 0, 1)`, radius the rock's radius × 2, the rock's site |
  | `Ship`, 2 Hz: when `flight_computer.commanded_force_local` is over a tenth of its budget and one ray from the hull opposite the thrust hits an `AsteroidDetail` within 50 m | `VIBRATION` at the hit, strength 0.6, radius 40 |
  | `MotionCoupling.drive_felt_gravity`: when the shove changes by more than 3 m/s² between ticks | `SHAKE` to the interior's bus, strength `shove.length() / SHOVE_CAP` |
  | `Npc`: its skin (below) | `TOUCH` to itself only (not through the bus) |

- [ ] **Step 4: The skin.** `Npc` gets an `Area3D` (`skin`) a little larger than its collider,
  `collision_layer = 0`, mask `4 | 32 | 64` outside and `4 | 32` inside. `body_entered` from the
  avatar, an item moving faster than 1 m/s relative to the NPC, or a moving rock notes a touch (from
  the body's position). A kinematic body is never pushed by a rigid one, so the skin is how it knows.

- [ ] **Step 5: `NpcMemory`** (spec §6.3):

```gdscript
class_name NpcMemory
extends RefCounted

## What an NPC has perceived (spec §6.3): what, where (site-local), when and how
## sure. Sureness halves every half_life seconds; a percept is forgotten below
## FORGET. The brain reads this, never the world, so an NPC can be wrong: it
## flees from where it last saw you. Lasts only while the NPC is live.

const FORGET := 0.05

class Percept:
	var kind: StringName
	## The node's instance id, or 0 for no one in particular.
	var source_id := 0
	var where := Vector3.ZERO
	var at := 0.0
	var sure := 1.0

var half_life := 6.0
var percepts: Array[Percept] = []

## Remembers `kind` from `source_id` at `where`: refreshes what it already
## remembers of that source, or adds it.
func note(kind: StringName, source_id: int, where: Vector3, sure: float, time: float) -> void:
	for p in percepts:
		if p.kind == kind and p.source_id == source_id and source_id != 0:
			p.where = where
			p.sure = maxf(sure, sure_of(p, time))
			p.at = time
			return
	var p := Percept.new()
	p.kind = kind
	p.source_id = source_id
	p.where = where
	p.sure = sure
	p.at = time
	percepts.append(p)

func sure_of(p: Percept, time: float) -> float:
	return p.sure * pow(0.5, (time - p.at) / half_life)

func forget_faded(time: float) -> void:
	percepts.assign(percepts.filter(func(p: Percept) -> bool: return sure_of(p, time) >= FORGET))

## The surest percept of `kind` now, or null.
func surest(kind: StringName, time: float) -> Percept:
	var best: Percept = null
	for p in percepts:
		if p.kind == kind and (best == null or sure_of(p, time) > sure_of(best, time)):
			best = p
	return best
```

  Percept kinds: `&"player"` (seen), `&"light"` (lit by, at the light), `&"vibration"`, `&"sound"`,
  `&"touch"`, `&"shake"`, `&"mate_bolted"`, `&"flare"`.

- [ ] **Step 6: `Perception`** (spec §6.2). A `RefCounted` owned by the `Npc`; `sense(npc, bus,
  time)` runs at each think. Keep each test pure in a static:
  - `static func in_cone(forward: Vector3, to: Vector3, cone_deg: float) -> bool`.
  - `static func sight_range(species, lit: bool, inside: bool) -> float`: inside, full; outside,
    full when lit, `sight_range * dark_sight` in the dark.
  - Sight: nodes in group `Avatar.GROUP`, and other live NPCs in the director (for herd mates, spec
    §7.3), within range and cone, with one ray (mask: interior geometry inside, rocks outside)
    clear. Is the target lit? Outside, the avatar counts as lit while it holds a light that is on,
    or is within any light's reach and cone. Notes `&"player"` or `&"mate_bolted"` (a mate whose
    brain's current behaviour is `scatter`).
  - Light on itself: for each of `bus.lights()`, within reach, inside the cone, and a clear ray:
    `ctx.lit = true` and a `&"light"` percept at the light. A burning flare also notes `&"flare"`.
  - Stimuli since its last think: `VIBRATION` only if `species.feels_vibration > 0`, the NPC is
    gripping (not drifting), and `s.site == npc.site.id`; `SOUND` if `hears > 0`; `SHAKE` if
    `feels_shake > 0`; strength `s.felt_at(npc.global_position) * sensitivity`, noted if over 0.05.
  - Touches from the skin and `receive_hit` since the last think.
  - Positions are converted to site-local before they are noted.

- [ ] **Step 7: Tests.**
  - `test_stimulus_bus.gd`: `emit`/`since`/expiry; `for_node` picks the interior's bus for a node
    under the interior and the exterior's for one outside; a `Universe.shift` moves live stimuli by
    the delta; `send` with no bus does nothing and logs nothing.
  - `test_perception.gd`: `in_cone` at the cone's edge; sight range lit and in the dark; a wall
    between (a `StaticBody3D` box on layer 2) blocks sight; a vibration on another rock is not felt;
    a sound is not heard by a species with `hears = 0`; a lamp pointed at the NPC lights it and one
    pointed away does not; memory halves at `half_life` and forgets below `FORGET`; a refreshed
    percept keeps one entry.
  - Extend `test_avatar.gd`: a spacewalk bump into a rock sends a vibration (a bus in the test).

- [ ] **Step 8:** Import, run, commit: `feat: stimuli and perception -- light, vibration, sound, touch`.

---

### Task 6: The brain, and the overlay

**Files:**
- Create: `src/npc/npc_context.gd`, `src/npc/curves.gd`, `src/npc/behaviour.gd`,
  `src/npc/npc_behaviours.gd`, `src/npc/brain.gd`, `src/npc/npc_debug.gd`,
  `test/unit/test_brain.gd`
- Modify: `src/npc/npc.gd`, `src/npc/npc_site.gd`, `scenes/flight_test.gd`

- [ ] **Step 1: `NpcContext`** (spec §7.2): everything a behaviour may read. No nodes, so tests make
  one by hand.

```gdscript
class_name NpcContext
extends RefCounted

## All a behaviour may read (spec §7.2). Behaviours never see a scene, so each
## can be tested with a context made up in the test. Points are site-local.

var record: NpcRecord
var species: NpcSpecies
var needs: Dictionary = {}
var memory: NpcMemory
var time := 0.0
## Seconds since the last think.
var dt := 0.2
var position := Vector3.ZERO
var forward := Vector3.FORWARD
var up := Vector3.UP
## A light is on it now.
var lit := false
## It is gripping a surface or standing on a floor (not drifting).
var grounded := true
## Herd mates' positions.
var mates: Array[Vector3] = []
## Named places the site offers: &"dock", &"shelter", &"round" ...
var places: Dictionary = {}
## Work spots, for a crew site: {cell, facing, action, key, at: Vector3, since: float}.
var spots: Array[Dictionary] = []
## The player's position, if seen within the last think, else null.
var player: Variant = null
## Anything the site or perception adds for one behaviour.
var extra: Dictionary = {}

func need(n: StringName) -> float:
	return float(needs.get(n, 0.0))

## Lowers need `n` at `rate` per second over this think.
func ease(n: StringName, rate: float) -> void:
	if needs.has(n):
		needs[n] = clampf(needs[n] - rate * dt, 0.0, 1.0)

func raise(n: StringName, amount: float) -> void:
	if needs.has(n):
		needs[n] = clampf(needs[n] + amount, 0.0, 1.0)
```

- [ ] **Step 2: `Curves`** (static): `ramp(x, a, b)` (linear 0→1 from a to b, clamped),
  `smooth(x, a, b)` (`smoothstep`), `above(x, t)` (0 or 1), `inverse(x)` (1 − x).

- [ ] **Step 3: `Behaviour`**:

```gdscript
class_name Behaviour
extends RefCounted

## One thing an NPC can do (spec §7.2): it scores itself from the context,
## starts, writes an intent each think, and says when it is done. Small and
## scene-free, so each is tested with a made-up context.

var id: StringName
## A reflex pre-empts anything once its score reaches threshold.
var reflex := false
var threshold := 0.5
## Seconds it keeps running once chosen, unless done or a reflex fires.
var min_time := 1.0
## From the species; multiplies the score.
var weight := 1.0

func score(_ctx: NpcContext) -> float:
	return 0.0

func start(_ctx: NpcContext) -> void:
	pass

func think(_ctx: NpcContext) -> Intent:
	return Intent.idle()

func done(_ctx: NpcContext) -> bool:
	return false
```

- [ ] **Step 4: `NpcBehaviours`**: `static func make(id: StringName) -> Behaviour`, a `match` over
  ids, each case `return preload("res://src/npc/behaviours/<id>.gd").new()` with `id` set; unknown →
  `null`. Tasks 7 and 10 add the cases. Enable the pending assertion in `test_npc_species.gd` at the
  end of Task 10 (the ids exist by then); until then assert only the ids already written.

- [ ] **Step 5: `Brain`**:

```gdscript
class_name Brain
extends RefCounted

## Needs and scored behaviours (spec §7): needs rise by themselves; each think
## every behaviour scores itself; a reflex over its threshold runs at once;
## otherwise the best runs, the current one scoring STICK times higher so a
## near tie never flips it. It writes one intent a think. It never touches
## physics and never reads the world: only its needs and its NPC's memory.

const STICK := 1.25

var needs := {}
var rises := {}
var behaviours: Array[Behaviour] = []
var current: Behaviour
## When the current behaviour started.
var since := 0.0
## Last think's scores, by id, for the overlay.
var scores := {}
var intent := Intent.idle()

func setup(species: NpcSpecies, rng: RandomNumberGenerator) -> void:
	rises = species.needs.duplicate()
	needs.clear()
	for n: StringName in species.needs:
		var start: Vector2 = species.need_start.get(n, Vector2.ZERO)
		needs[n] = rng.randf_range(start.x, start.y)
	behaviours.clear()
	for id: StringName in species.behaviours:
		var b := NpcBehaviours.make(id)
		if b == null:
			push_error("Brain: %s names no behaviour called %s" % [species.id, id])
			continue
		b.weight = float(species.behaviour_weights.get(id, 1.0))
		behaviours.append(b)
	current = null
	since = 0.0

func think(ctx: NpcContext) -> Intent:
	for n: StringName in needs:
		needs[n] = clampf(needs[n] + float(rises.get(n, 0.0)) * ctx.dt, 0.0, 1.0)
	ctx.needs = needs
	scores.clear()
	var next := _choose(ctx)
	if next != current:
		current = next
		since = ctx.time
		if current != null:
			current.start(ctx)
	intent = current.think(ctx) if current != null else Intent.idle()
	return intent

func _choose(ctx: NpcContext) -> Behaviour:
	var held := current != null and ctx.time - since < current.min_time and not current.done(ctx)
	var reflex: Behaviour = null
	var best: Behaviour = null
	var best_score := 0.0
	for b in behaviours:
		var s := b.score(ctx) * b.weight
		scores[b.id] = s
		if b.reflex:
			if s >= b.threshold and (reflex == null or s > float(scores[reflex.id])):
				reflex = b
		else:
			var judged := s * (STICK if b == current else 1.0)
			if judged > best_score:
				best = b
				best_score = judged
	if held and (current.reflex or reflex == null):
		return current
	if reflex != null:
		return reflex
	return best
```

- [ ] **Step 6: Wire the `Npc`.** `setup` makes `brain`, `memory` and `perception` fresh (seeded
  `RandomNumberGenerator` from `record.seed`), with `memory.half_life` 6 s. `think(time, dt)`:
  1. build an `NpcContext` (record, species, memory, time, dt, `local_position()`, forward and up in
     site space, `grounded` from the active locomotor);
  2. `perception.sense(self, bus, time)` into the context and memory;
  3. `site.fill(ctx, self)`;
  4. `intent = brain.think(ctx)`;
  5. `look` plays `intent.action` if it has an `act(action)` method.

  The director hands each NPC its space's bus (`director.bus`).

- [ ] **Step 7: The overlay** (spec §17.3). `NpcDebug`, a `Node3D` that `flight_test.gd` adds,
  toggled with **F4** (F3 is the universe readout). While on, a `Label3D` above each live NPC in both
  directors (billboard, no depth test, render layers 1 and 2): its behaviour, the top three scores,
  its needs as `name ▮▮▮▯▯`, and its surest two percepts. Colours from `HudPalette`. Off by default,
  and nothing is built while off.

- [ ] **Step 8: Test.** `test_brain.gd`, with two or three tiny behaviours defined in the test
  (constant scores, a reflex with a settable score):
  - needs rise at their rates and clamp at 1;
  - the best behaviour runs; a challenger at 1.2× the current does not win, at 1.3× it does;
  - a held behaviour is kept until `min_time`, unless a reflex fires;
  - a reflex over its threshold pre-empts at once; a held reflex is not pre-empted by a higher
    non-reflex;
  - `done` releases a held behaviour early;
  - an unknown behaviour id logs an error and is skipped;
  - `scores` holds every behaviour's last score.

- [ ] **Step 9:** Import, run, commit: `feat: the brain -- needs, scored behaviours, reflexes; the F4
  overlay`.

---

### Task 7: The droid comes alive

**Files:**
- Create: `src/npc/behaviours/tend.gd`, `roam.gd`, `recharge.gd`, `give_way.gd`, `notice.gd`,
  `startle.gd`, `brace.gd`, `keep_away.gd`; `src/npc/npc_looks.gd`;
  `test/unit/test_droid_behaviours.gd`, `test/unit/test_npc_looks.gd`,
  `test/unit/test_droid_scene.gd`
- Modify: `src/npc/populations/ship_site.gd`, `src/npc/npc_behaviours.gd`,
  `src/ship/interior/interior_palette.gd`, `src/audio/synth.gd`, `src/npc/npc.gd`,
  `test/unit/test_synth.gd`, `test/unit/test_visual_style_rules.gd`

- [ ] **Step 1: `ShipSite.fill`.** Puts in `ctx.places[&"dock"]` (`DeckPaths.floor_point(dock)`),
  `ctx.spots` (each with `at` = the floor point of its cell pushed 0.45 m toward `facing`, and `since`
  = time since last tended, or 999), `ctx.extra[&"rooms"]` (one floor point per room and one for the
  common space, for `Roam`), and `ctx.extra[&"player_room"]` (the zone the avatar is in, if it is
  aboard). `ShipSite.tended(key, time)` records a finished job.

- [ ] **Step 2: The behaviours** (spec §14.3). Scores are from `Curves` on needs and memory; the
  numbers here are the starting tune (Task 11 tunes by playing):

  | Behaviour | Reflex | `score` | `think` | `done` |
  |---|---|---|---|---|
  | `tend` | no, `min_time` 6 | `ramp(duty, 0.2, 0.8) × (1 − fear)` | walk to the chosen spot (longest since tended, less 0.1 per metre away, never the one within 1.5 m of the player); there, face along `facing` with `action` (`&"polish"`, `&"scan"`, `&"tidy"`) for 4–8 s, `ease(duty, 0.15)`, then call `site.tended` and chirp | its time at the spot is up |
  | `roam` | no, `min_time` 8 | 0.15 | walk to a room point not the current one, calm speed (1.0/1.8) | arrived |
  | `recharge` | no, `min_time` 10 | `ramp(charge, 0.5, 1.0)` | walk to the dock, then sit (`&"dock"`), `ease(charge, 0.05)` | `charge` below 0.05 |
  | `give_way` | no, `min_time` 1.5 | `0.9` when the player was seen within 3 m and closing, or the current path's next two cells hold the player; else 0 | step to the side of its cell away from the player's line (0.6 m off centre), or into the nearest doorway cell off the player's path; face the player | the player is 2.5 m away and not closing |
  | `notice` | no, `min_time` 2 | `ramp(curiosity, 0.2, 0.7) × above(player within 3 m and still for 1 s)` | face the player, `&"notice"` (tilts its cap), chirp once, `ease(curiosity, 0.3)` | 3 s |
  | `startle` | yes, threshold 0.5, `min_time` 1.2 | the surest `touch`, or a `sound` over 0.6, in the last think | back away 1.5 m from the source, fast, `&"startle"`, beep; `raise(fear, 0.3)` | 1.2 s |
  | `brace` | yes, threshold 0.3, `min_time` 0.8 | the strongest `shake` in the last think | `Intent.idle(&"brace")` | no shake for 0.8 s |
  | `keep_away` | no, `min_time` 6 | `ramp(fear, 0.4, 0.9)` | tend spots, or roam, only in rooms the player is not in; `ease(fear, 0.05)` | fear below 0.2 |

  `fear` also eases by itself: every think, `ctx.ease(&"fear", 0.02)` in `ShipSite.fill` while
  nothing touched or startled it. Add every id to `NpcBehaviours.make`.

- [ ] **Step 3: The look** (spec §14.4). `NpcLooks`, a static class with
  `static func build(look: StringName, variety: float) -> Node3D` (a match; unknown → a placeholder
  box and `push_error`), and `static func droid(kit: InteriorKit, f: Transform3D, variety: float)`,
  built in the frame `f` from kit primitives only:
  - body: a bevelled drum 0.5 m across, 0.36 m tall, in `InteriorPalette.WALL`, a `BELT` band;
  - cap: a flattened bevelled dome on top (separate node so it can tilt) in `TRIM`;
  - eye: a strip 0.22 × 0.04 m on the cap's front in the `GLOW` batch,
    `InteriorKit.lit(InteriorPalette.LIGHT_WARM, InteriorMaterials.GLOW_ENERGY)`;
  - two wheels: short tubes 0.16 m across in a new `InteriorPalette.DROID_WHEEL` (dark, near
    `GUNMETAL`), one either side;
  - arm: two `tube_between` segments and a small pad, folded against the body (separate node so it
    can move).
  - `variety` picks a trim colour from two or three palette entries so a later fleet of droids is not
    identical.
  - The look node exposes `act(action)`: `&"polish"`/`&"scan"`/`&"tidy"` swing the arm on a small
    loop, `&"notice"` tilts the cap 15°, `&"startle"` jolts the cap back, `&"brace"` drops the body
    2 cm; wheels turn with speed; the eye strip turns with `intent.face`.
  - Render layer 2. It never names `ShipGrid`, `InteriorLayout` or any other grid-side class.
  - Add `npc_looks.gd` to `PAINTING_FILES` and `REUSABLE_FILES` in `test_visual_style_rules.gd`.
  Until Task 10, `build(&"skitter", …)` returns the placeholder.

- [ ] **Step 4: The sounds** (spec §14.5). Three `Synth` builders, in `NAMES`; `droid_whir` in
  `LOOPED`:
  - `droid_whir`: 1.0 s seamless, low-passed noise at 600 Hz under a soft 140 Hz sine, quiet
    (`_gain(x, 0.25)`);
  - `droid_chirp`: two sine notes, 880 then 1175 Hz, 0.07 s each, soft attack, gain 0.35;
  - `droid_beep`: two lower notes, 520 then 440 Hz, with a 7 Hz wobble, 0.1 s each, gain 0.4.
  The `Npc` gets an `AudioStreamPlayer3D` on the Ship bus when inside (none outside: outside is
  silent). The whir plays while its speed is over 0.1 m/s; the behaviours ask for chirp and beep by
  setting `intent.action` to `&"chirp"`-suffixed actions, or through `npc.voice(name)`: pick the
  simpler once written, and say which in the report.

- [ ] **Step 5: Tests.**
  - `test_droid_behaviours.gd`: each behaviour's score from made-up contexts (the rows above); `tend`
    picks the spot tended longest ago and never the one beside the player; `give_way` steps away
    from the player's line; `startle` fires on a touch and raises fear; `brace` fires on a shake.
  - `test_npc_looks.gd`: the droid builds in a bare frame with no grid; its triangle count is pinned;
    every surface is from the kit; render layer 2; `act` with each action changes the arm or cap
    transform and back.
  - `test_synth.gd`: the three new sounds build, are not silent, and `droid_whir` loops.
  - `test_droid_scene.gd` (the real flight scene, the avatar aboard): over 60 s of physics frames the
    droid tends at least two spots and returns to its dock when its charge is set high; walking the
    avatar at it down the corridor makes it give way (distance never under 0.6 m); a thrown mug that
    hits it makes it startle; `felt` jumping by 8 m/s² makes it brace.

- [ ] **Step 6: Render and show the owner.** In the real scene at eye height (1.6 m): the droid in
  the corridor, at a porthole polishing, in the galley doorway giving way, and at its dock in the
  closet. Four images. The owner approves the look before Task 8.

- [ ] **Step 7:** Import, run, commit: `feat: the maintenance droid -- tends the ship, keeps out of
  your way`.

---

### Task 8: Herds on the rocks, and the exterior's director

**Files:**
- Create: `src/npc/populations/rock_herds.gd` (it has `site_of` from Task 5),
  `src/npc/populations/rock_site.gd`, `test/unit/test_rock_herds.gd`,
  `test/unit/test_exterior_npcs.gd`
- Modify: `scenes/flight_test.gd`, `test/unit/test_floating_origin_scene.gd`

- [ ] **Step 1: `RockHerds`** (pure, spec §4.2, §4.4). Statics, from a rock and its detail:
  - `static func herds(rock: AsteroidRock, data: RockDetail, world_seed: int) -> Array[Dictionary]`:
    `{index, home_dir, round_dirs: Array[Vector3], period, count}`. A seeded generator from
    `AsteroidRecipe.cell_seed(world_seed, 11, rock.cell) ^ rock.index`. Herds: 0–3, one more for
    every 150 m of the rock's diameter over 150, and one more if `rock.shape` is the veined shape,
    capped at 3. Each herd's home is on a crater's wall: a crater from `data.craters`, a direction
    at 0.8 of its angular radius from its centre, at a seeded bearing. Its round: 3–5 directions
    within 0.35 rad of home, the first being home; period 20–40 minutes. Count 3–7.
  - `static func records(rock, data, world_seed) -> Array[NpcRecord]`: per herd, `count` records,
    id `&"skitter:%s:%d:%d" % [site_of(rock), herd, n]`, home = `data.surface_point(dir)` for a
    direction jittered within 3 m of the herd's home direction, pushed 0.5 m out along it; `herd`
    set; seed from the same generator.
  - `static func round_point(herd: Dictionary, data: RockDetail, time: float) -> Vector3`: where
    the herd is at `time`: along the loop of `round_dirs` by `fposmod(time / period, 1)`, slerping
    directions between stops, then `data.surface_point`.
  - Nothing here reads a node, so it runs anywhere and is tested headless.

- [ ] **Step 2: `RockSite`** (`extends NpcSite`), one per big rock in detail:
  - `frame()`: `detail.global_transform` (it is in `EXTERIOR_SPACE`, so it moves with the origin;
    rock-local positions never change).
  - `alive()`: `is_instance_valid(detail) and detail.is_inside_tree()`.
  - `gravity()`: zero.
  - `herds`, `records`, cached at creation (a few dozen `surface_point` calls: main thread is fine).
  - `fill(ctx, npc)`: `ctx.mates` (positions of the live NPCs of the same herd, from the director);
    `ctx.places[&"round"]` (`round_point` at the director's time); `ctx.places[&"shelter"]` (the
    nearest crater floor point to the NPC); `ctx.extra[&"graze"]` (the nearest crater wall point along
    its herd's round).
  - Records are promoted at their herd's round point at the current time plus their own offset from
    home (spec §4.4): `RockSite.start_point(record, time)`.

- [ ] **Step 3: The exterior's source and director.** In `flight_test.gd`, a new `_wire_npcs()` after
  `_wire_universe()`:
  - a `StimulusBus` under the scene root, `setup(self, _universe)`;
  - an `NpcDirector`, `rule = BY_DISTANCE`, `max_live = 32`, `holder` a new `Node3D` under the scene
    root (never moves), `cameras` = the chase camera, the canopy camera and the avatar's camera;
  - a source object (`RockHerds.Source`, an inner class or small file) whose `records(director)`
    keeps one `RockSite` per `AsteroidDetail` in `_stream.details.live` within `skitter.live_radius
    + rock radius + DEMOTE_MARGIN` of an anchor, and drops sites whose detail is gone;
  - the director's `promote` asks the site for `start_point` instead of `home` when the site offers
    one (add `NpcSite.start_point(record, time) -> Vector3`, defaulting to `record.home`);
  - `NpcDebug` watches both directors.
  - Skitters are still placeholder boxes in `SpacePalette` colours with no locomotor worth the
    name until Task 9: in this task give `surface_crawler` a stub that holds position, so promotion,
    demotion and the origin can be tested first.

- [ ] **Step 4: The fade** (spec §4.6). The skitter's material (placeholder now, the look in Task
  10) is `StandardMaterial3D` with `distance_fade_mode = DISTANCE_FADE_PIXEL_DITHER`,
  `distance_fade_min_distance = 300`, `distance_fade_max_distance = 250` (reversed, as the rocks do:
  check `AsteroidStream.rock_material` for the exact convention and copy it).

- [ ] **Step 5: Tests.**
  - `test_rock_herds.gd`: the same seed and rock give the same records; ids unique; every home within
    1 m of `data.surface_point` of its direction; 0–3 herds of 3–7; no herd on a rock with no craters
    (a hand-made `RockDetail` with `craters` emptied); `round_point` is the same for the same time,
    starts at home at `time = 0`, and moves over a period; `site_of` is stable.
  - `test_exterior_npcs.gd` (the real flight scene): after the first load, the start's big rock is
    in detail; moving the hull's anchor within 350 m of a herd promotes it; back beyond 450 m (and
    the cameras pointed away) demotes it; a promotion is not visible (the NPC is beyond the fade
    distance from every camera at the moment it appears); `max_live` holds when two rocks' herds are
    in reach.
  - Extend `test_floating_origin_scene.gd`: with a herd live, `_uncovered()` is still empty, and after
    a shift every live skitter's `local_position()` is unchanged within 1 mm.

- [ ] **Step 6:** Import, run, commit: `feat: herds on the big rocks -- the exterior's director`.

---

### Task 9: Crawling and drifting

**Files:**
- Create: `src/npc/surface_crawler.gd`, `src/npc/zero_g_drift.gd`,
  `test/unit/test_surface_crawler.gd`, `test/unit/test_zero_g_drift.gd`
- Modify: `src/npc/npc.gd`, `src/avatar/avatar.gd`, `test/unit/test_avatar.gd`

- [ ] **Step 1: `SurfaceCrawler`** (`&"surface_crawler"`, spec §5.3):
  - `enter`: `motion_mode = MOTION_MODE_FLOATING` (it manages its own up), `gripping = true`.
  - Each step: three rays along the body's down (`-up`), 1.2 × its height long, from the centre, a
    body length ahead and a body length behind, mask `AsteroidBody.LAYER`.
    - **Up:** the average of the hit normals (the centre's weighted double). Turn the body's basis
      toward it by `1 − exp(−delta / 0.05)` of the way each tick (settles in about 0.15 s).
    - **Grip:** `velocity += −up × GRIP × delta` (4 m/s²) while the centre ray hits.
    - **Convex edge:** the fore ray misses → cast from ahead of its feet down and back toward the
      body; if that hits, steer onto it (the new surface's normal becomes the target up).
    - **Concave corner:** a short ray straight ahead (0.8 of its length) hits → take that normal as
      the target up and climb.
    - **Steering:** the direction to `intent.move_to`, projected onto the plane of `up`, at
      `intent.speed × top_speed`; plus separation from herd mates closer than 1.2 m (from the
      context's `mates`, kept on the locomotor after each think). Horizontal (in the surface plane)
      velocity moves toward that at 10 m/s².
    - `npc.up_direction = up`; `move_and_slide()`.
    - **Moving footing:** if the centre ray's collider is an `AsteroidBody`, add its point velocity;
      if that exceeds 3 m/s, let go.
  - `handover`: `&"zero_g_drift"` when every ray has missed for 0.2 s, or it let go, or a shove took
    its speed off the surface over 1.5 m/s.
  - `&"leap"` in the intent: hand over to drift with the leap target (below).
  - `grounded` is `gripping`.

- [ ] **Step 2: `ZeroGDrift`** (`&"zero_g_drift"`, spec §5.4):
  - **Leap:** `start_leap(npc, target_local)`: one ray from the NPC to the target (mask rocks); no
    hit within 30 m, no leap (the crawler stays). Otherwise velocity = 6 m/s toward the hit; turn
    feet-first toward the surface over the flight; hand back to the crawler when a slide collision
    with a rock happens or the centre ray (as the crawler's) hits within 0.6 m.
  - **Knocked off:** no gravity; tumble for 0.6 s (spin from the shove); then steady, find the
    nearest rock surface (rays in six directions and toward the site's centre, 60 m), and puff toward
    it: a 0.8 m/s kick, at most one a second, `PUFFS = 6` in all. Each puff spawns a small puff from
    `Puffs` at the NPC (outside, in `EXTERIOR_SPACE`: check how `Puffs` is used outside and follow
    it).
  - **Out of puffs:** keep drifting; the director demotes it once out of sight (nothing else to do).
  - `grounded` false.

- [ ] **Step 3: Bumps.** In `Avatar.bump`, handle an `Npc` like a rock body: `m = SUIT_MASS × npc.mass
  / (SUIT_MASS + npc.mass)` with `npc.mass` = `species.mass`, and `npc.shove(-n × j)` instead of
  `apply_impulse`. `Npc.shove` outside: the crawler's grip holds a shove under 1.5 m/s off the
  surface; more knocks it off (the drift's tumble). Inside, the droid slides by the shove.

- [ ] **Step 4: `receive_hit`.** A plasma bolt's hit on a skitter: `shove(hit.impulse)` (bolt `PUSH`
  over 25 kg knocks it off), a touch percept.

- [ ] **Step 5: Tests** on test meshes, built in the test as `StaticBody3D`s on layer 64:
  - `test_surface_crawler.gd`: on a 10 m cube, walking toward a point on the far face, it wraps two
    edges and arrives, its centre ray hitting throughout (allow 0.2 s of misses at an edge); on a
    sphere of radius 8, walking round the equator from the top, it ends upside down on the bottom
    with its up within 10° of the normal; in a concave bowl it climbs the wall; a 3 m/s shove away
    from the surface hands over to drift; on an `AsteroidBody` moving at 2 m/s it keeps its footing,
    at 4 m/s it lets go.
  - `test_zero_g_drift.gd`: a leap at empty space is refused; a leap to a box 20 m away lands on it
    and hands back to the crawler; knocked off, it puffs back to the sphere within 15 s; with puffs
    at 0 it drifts on.
  - Extend `test_avatar.gd`: a spacewalker at 1 m/s into a 25 kg skitter shares momentum by the
    formula.
  - Live check in the real scene: a placeholder skitter walks over a crater rim and upside down
    under an overhang of the start's big rock. Record frame times.

- [ ] **Step 6:** Import, run, commit: `feat: SurfaceCrawler and ZeroGDrift -- any way up, and back
  again`.

---

### Task 10: The skitter

**Files:**
- Create: `src/npc/behaviours/graze.gd`, `wander.gd`, `stay_with_herd.gd`, `freeze.gd`,
  `scatter.gd`, `hide.gd`, `investigate.gd`, `rest.gd`, `drawn_to_flare.gd`;
  `src/npc/legged_gait.gd`; `test/unit/test_skitter_behaviours.gd`,
  `test/unit/test_legged_gait.gd`
- Modify: `src/npc/npc_looks.gd`, `src/npc/npc_behaviours.gd`, `src/world/space_palette.gd`,
  `test/unit/test_npc_looks.gd`, `test/unit/test_npc_species.gd`

- [ ] **Step 1: The behaviours** (spec §13.2), starting tune:

  | Behaviour | Reflex | `score` | `think` | `done` |
  |---|---|---|---|---|
  | `graze` | no, `min_time` 8 | `ramp(hunger, 0.2, 0.8) × (1 − fear)` | walk to `extra.graze`, then `&"graze"` in place, `ease(hunger, 0.08)` | hunger below 0.1 |
  | `wander` | no, `min_time` 10 | 0.15 | amble toward `places.round`, calm speed (0.3) | within 2 m |
  | `stay_with_herd` | no, `min_time` 3 | `ramp(company, 0.3, 0.9)` when the nearest mate is over 6 m away | walk to the mates' centre; `ease(company, 0.2)` near them | within 3 m of the centre |
  | `freeze` | yes, threshold 0.5, `min_time` 1.5 | `lit ? 0.9 : 0` + the player seen moving within 15 m × 0.7, times `−light_response` for the light part | `Intent.idle(&"freeze")`; `raise(fear, 0.05)` a think | not lit and no player moving near for 2 s |
  | `scatter` | yes, threshold 0.45, `min_time` 3 | the strongest `vibration`, `touch` or `mate_bolted` in the last think | run from the source at full speed along the surface, in a direction offset ±60° by the record's seed (so a herd fans out); leap (`&"leap"`) toward a moon or rubble in that direction if one is within 30 m and the seed says so; `raise(fear, 0.4)` | 3 s |
  | `hide` | no, `min_time` 10 | `ramp(fear, 0.4, 0.9)` | go to `places.shelter`, then `&"freeze"` there; `ease(fear, 0.04)` | fear below 0.2 |
  | `investigate` | no, `min_time` 4 | `ramp(curiosity, 0.4, 0.9) × (1 − fear) ×` the player seen and still | edge toward the player, speed 0.15, stop 6 m away, face them; `ease(curiosity, 0.1)` | 6 s, or the player moves |
  | `rest` | no, `min_time` 15 | `ramp(rest, 0.6, 1.0)` | go to shelter, `&"rest"`; `ease(rest, 0.05)` | rest below 0.1 |
  | `drawn_to_flare` | no, `min_time` 5 | a `flare` percept over 12 m away, not moving, × (1 − fear) | walk to its light's edge (`Flare.RANGE` from it), face it | the flare gone or moving |

  `fear` eases by itself, 0.02 a think while nothing frightens it (in `RockSite.fill`). A flare that
  is close (within its light's reach) or moving frightens: perception notes it as a `&"light"`
  percept with the flare as source, which `freeze` reads like a lamp.

- [ ] **Step 2: `LeggedGait`** (spec §13.4). A `RefCounted` the skitter's look owns:
  - six feet, home points on the body (three each side), a tripod gait: legs 0, 3, 4 step together,
    then 1, 2, 5;
  - a foot steps when its home point (projected by a short ray to the surface) is more than 0.25 m
    from where it is planted, and only when its tripod's turn has come; a step lasts 0.12 s at
    bolting speed and 0.3 s calm, lifting 0.08 m;
  - within 60 m of the nearest camera, feet are placed by rays (six a tick); beyond it, legs play a
    canned cycle with no rays;
  - `update(body_transform, speed, delta, space_state, near_camera)` returns six foot positions; the
    look bends each two-segment leg to reach its foot (a simple two-bone solve in the leg's plane).

- [ ] **Step 3: The look** (spec §13.4). `NpcLooks.skitter(variety, rock_colour)`: built in code
  from `ArrayMesh` facets (not the interior kit: it is outside) with flat normals:
  - a domed back of three or four big facets, a squat head, six two-segment legs; under 300
    triangles;
  - colours from `SpacePalette`: the back in its home rock's colour (the `RockSite` passes
    `rock.colour`), the underside and legs `SpacePalette.shade(colour, 0)` darker, a small lavender
    patch (`SpacePalette.CRYSTAL`) on the back; the eyes two pale facets in a new
    `SpacePalette.SKITTER_EYE`;
  - one `StandardMaterial3D` per skitter with vertex colours, the distance fade from Task 8, render
    layer 1, casting shadows;
  - `act(action)`: `&"freeze"` flattens the body 4 cm and stops the legs; `&"graze"` bobs the head;
    `&"rest"` folds the legs; `&"leap"` tucks them.
  - `npc_looks.gd` is already in `PAINTING_FILES` (Task 7), so the palette rule covers the skitter
    too.

- [ ] **Step 4: Tests.**
  - `test_skitter_behaviours.gd`: each score from made-up contexts; `freeze` fires when lit and not
    otherwise; `scatter` fires on a vibration and fans a herd out (three records' directions differ
    by over 60°); `hide` goes to shelter; `investigate` stops at 6 m; `drawn_to_flare` stops at the
    light's edge.
  - `test_legged_gait.gd`: on a flat plane, walking straight, the tripods alternate and never both
    lift at once; no foot is ever more than 0.4 m from its home; beyond 60 m no rays are cast (count
    them through a spy).
  - `test_npc_looks.gd`: the skitter builds, under 300 triangles, colours only from `SpacePalette`,
    render layer 1, with the fade set.
  - `test_npc_species.gd`: enable the pending assertion: every behaviour, locomotor and look id in
    both `.tres` exists.

- [ ] **Step 5: Render and show the owner.** From a spacewalk at the start's big rock, lamp on and
  off: a herd grazing, frozen in the beam, and scattering. The owner approves the look before Task
  11.

- [ ] **Step 6:** Import, run, commit: `feat: the skitter -- a shy grazer on the big rocks`.

---

### Task 11: Live checks, tuning and the docs

**Files:**
- Modify: `docs/superpowers/specs/2026-09-26-npc-foundation-design.md` (status, "As built"),
  `docs/design/visual-style.md`, `docs/superpowers/SLICE-1-STATUS.md`,
  `.claude/skills/building-a-ship/SKILL.md`, `reference.md`, `ship_probe.gd`

- [ ] **Step 1: The live checks** (spec §17.2), windowed, real scene, each result recorded in a
  table in the spec's "As built" section, as the asteroids spec does:
  - **Outside:** the pitch played through (freeze when lit, scatter at a push-off, return in the
    dark, scatter at a hull strike); a skitter over a crater rim and under an overhang; promotions and
    demotions unseen (image difference no larger than between ordinary frames); frame times with 32
    live (all NPC work ≤ 1 ms: time the directors' `_physics_process` with
    `Time.get_ticks_usec`); a 20 km boost across groups with no frame over 33 ms and no NPC left
    behind a shift.
  - **Inside:** the droid at eye height in the corridor, the galley and at a porthole; giving way,
    noticing, startling at a thrown mug, bracing in a boost; frame times aboard.

- [ ] **Step 2: Tune** by playing both halves of the pitch with the F4 overlay on. Change numbers in
  the `.tres` files and behaviour constants only; record the final values in the spec.

- [ ] **Step 3: The spec.** Status: built. An "As built" section: the live-check table, the tuned
  numbers, and every place the build differs from the text, at least:
  - `Brain`, `Perception` and `NpcMemory` are `RefCounted` members of the `Npc`, not child nodes
    (§5.1's tree), so they test without a scene;
  - the droid reads `FeltGravity.felt` through its site instead of joining `FeltGravity`'s mask (§5.1);
  - the `Npc`'s skin area is how it feels touches (§6.1);
  - the director's own clock stands in for universe time (§4.4);
  - lights are a group queried at think time, not stimuli emitted each think (§6.1).

- [ ] **Step 4: The style guide.** A new section after §3.5, *NPCs*: the skitter (chunky facets,
  its rock's colour, silent, fades in with distance) and the droid (built like a prop from the kit,
  `InteriorPalette`, a glow-batch eye and no light, three soft synthesized sounds), each with the
  owner's approval date from Tasks 7 and 10. §5 lists `npc_looks.gd` among the checked files.

- [ ] **Step 5: `SLICE-1-STATUS.md`:** NPCs under "What works"; the suite count.

- [ ] **Step 6: The building-a-ship skill** (CLAUDE.md: a system a ship has to fit):
  - **Checklist:** "A ship with 12 or more walkable cells gets a maintenance droid. Give it a
    closet, or it docks in the cell farthest from the helm; every console, porthole and fixture it
    tends must be reachable on foot from there (`DeckPaths`)."
  - **Mistakes already made:** anything the build turned up (for example, a room whose only doorway
    faces the airlock strands the droid, because it never enters the airlock).
  - **`reference.md`:** `ShipCrew.MIN_CELLS`, `DeckPaths.build(layout, avoid)`, `ShipCrew.dock`,
    `ShipCrew.work_spots`, layer 8 `npcs` and the masks.
  - **`ship_probe.gd`:** a line printing the droid's dock and the number of work spots unreachable
    from it (must be 0).

- [ ] **Step 7:** Run the whole suite, commit: `docs: NPCs as built -- live checks, the style guide,
  the building-a-ship skill`.

---

## Definition of done

- The whole suite is green, output pristine, with every test in the File Structure table.
- The owner has seen and approved the droid's renders (Task 7) and the skitter's (Task 10).
- The live checks in Task 11 are recorded and meet the spec's budgets.
- `test_floating_origin_scene.gd` passes with a herd live; `test_visual_style_rules.gd` passes
  unchanged in its rules.
- The spec, the style guide, `SLICE-1-STATUS.md` and the building-a-ship skill are updated in this
  branch.
