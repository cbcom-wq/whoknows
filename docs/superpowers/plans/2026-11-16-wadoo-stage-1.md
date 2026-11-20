# Wadoo Stage 1: a Living Town — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 25 named Wadees live in the oasis town Wadoo: they walk its lanes, work its gardens, pump,
Glassworks and breach, rest under the sails, talk in pairs, drink at the bank, mourn at a new
memorial, go home, keep watch, and turn to look at you, at 80 fps or better.

**Architecture:** The Wadees are exterior NPCs on the existing framework (`src/npc`): a source
offers 25 records while the oasis is loaded, a site gives them the town (its frame is the place's
node, so the floating origin is free), a new `GroundWalker` locomotor walks routes from a grid
built from the layout (`WadooPaths`, Godot's `AStarGrid2D`), and a new `WadeeLook` plays the
retargeted library motions on one-mesh, one-material models coloured per person from
`WadeePalette`.

**Tech Stack:** Godot 4.5.1 (GDScript, GUT), Blender 5.2 headless (Python), Quaternius UAL 1 and 2
(CC0), Blender Human Base Meshes (CC0).

**Spec:** `docs/superpowers/specs/2026-11-16-wadoo-design.md` (§4, §5, §11, §12, §13 stage 1).

## Global Constraints

- At least **80 fps at 1280 × 720 on the GTX 960** with all 25 in view (style guide §2.6).
- Colours only from palettes: `WadeePalette` for the people, `OasisPalette` for the memorial;
  `test_visual_style_rules.gd` lists the new painting files.
- Never pay for an asset; CC0 only.
- Floating origin: every Wadee is an exterior NPC (`Npc.setup` joins `Universe.EXTERIOR_SPACE`);
  homes, spots and routes are in the place's frame (`[east, north]` m), never engine positions.
- No `#` comments in `.tres`/`.tscn`.
- Stable record ids `"wadee:wadoo:<n>"`, n = 0..24; the cast never reorders.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Targeted tests only: `.\run_tests.ps1 '-gselect=<file>.gd'`.

## Review Focus

1. **A Wadee walking into a wall, a hut or the pool.** Every route stays on open cells:
   `test_wadoo_paths.gd` checks every job spot and door is reachable and no route crosses a solid.
2. **Wadees piling up on one spot.** Spots are claimed by one Wadee at a time (`WadooSite.claim`);
   two walkers never stand closer than 0.6 m (`test_ground_walker.gd`).
3. **Feet floating or sunk on the slope by the pool.** The walker sets height from the ground
   (cached 1 m grid, bilinear); the probe prints the worst foot gap at eye height.
4. **The town loading in view.** Records wake only when the director promotes them (within 400 m);
   they wake at their job spots, which are inside the walls.
5. **The frame rate with 25 near.** Shadows within 25 m, motions at 15 Hz beyond 30 m; the probe
   reads fps with all 25 in view.

---

### Task 1: The models: crowd-ready, variants, and every clip

**Files:** Modify `tools/blender/wadee_base.py`, `tools/blender/wadee_rig.py`, `tools/blender/README.md`;
write `who-knows/assets/wadee/wadee_<a|b|c|m|n|q|s|t>.glb` and `sunstaff.glb`.

**Produces:**
- Each Wadee GLB: one skinned mesh, one material named `wadee_palette`, UVs at the texel
  centres of a 16 × 1 palette (`u = (slot + 0.5) / 16`, `v = 0.5`). Slots:
  0 skin, 1 lips, 2 hair, 3 brow, 4 sclera, 5 iris, 6 pupil, 7 lash, 8 cloth 1, 9 cloth 2,
  10 cloth 3, 11 leather, 12 bronze, 13 turquoise, 14 sunglass, 15 cape.
  Cloth 1–3 are the variant's outfit order (top, trim, skirt).
- Variants: `q` the queen (woman, body of `b`): bronze-and-turquoise crown, long cape (slot 15),
  more jewellery. `s` (woman, body of `a`) and `t` (man, body of `m`), the Sunguard: leather
  harness crossing the chest and leather arm guards. The men's chest sash runs over the shoulder.
- `sunstaff.glb`: a 1.5 m bronze staff with a sunglass head, its grip at the origin, along +y.
- Clips (Godot drops `_Loop` and loops those): from UAL1 `Idle_Loop`, `Idle_Talking_Loop`,
  `Walk_Loop`, `Walk_Formal_Loop`, `Jog_Fwd_Loop`, `Sprint_Loop`, `Sitting_Enter`,
  `Sitting_Idle_Loop`, `Sitting_Exit`, `Sitting_Talking_Loop`, `Fixing_Kneeling`, `Interact`,
  `PickUp_Table`, `Hit_Chest`, `Hit_Head`, `Death01`, `Roll`, `Spell_Simple_Shoot`,
  `Spell_Simple_Idle_Loop`, `Crouch_Idle_Loop`, `Crouch_Fwd_Loop`; from UAL2 (its bones mapped:
  Hips→pelvis, Spine→spine_01, Chest→spine_02, UpperChest→spine_03, Neck→neck_01, Head→Head,
  Shoulder→clavicle_*, UpperArm→upperarm_*, LowerArm→lowerarm_*, Hand→hand_*, UpperLeg→thigh_*,
  LowerLeg→calf_*, Foot→foot_*, Toes→ball_*) `Farm_Watering`, `Farm_Harvest`, `Farm_PlantSeed`,
  `Walk_Carry_Loop`, `Consume`, `Idle_FoldArms_Loop`, `Yes`, `Hit_Knockback`. A clip a pack does
  not have is reported and skipped, never fatal.

- [ ] Rebuild the bases with the variants and the sash; render the sheet and look at it.
- [ ] Rig all eight with both packs; join each into one mesh with the palette UVs; render the
      clip sheets and look at them (feet on the ground, hands not through the body).
- [ ] Import in Godot (`--headless --path . --import`) and read back one model: one
      `MeshInstance3D`, one surface, the clips listed above.
- [ ] Commit.

### Task 2: `WadeePalette`

**Files:** Create `who-knows/src/npc/wadee_palette.gd`; test `who-knows/test/unit/test_wadee_palette.gd`.

**Produces:** `class_name WadeePalette`; `const SLOTS := 16`; slot constants `SKIN`…`CAPE` as Task 1;
colour lists `SKINS`, `HAIRS`, `CLOTHS` (the outfit set: cream, rust, teal, plus ochre, indigo,
sand, terracotta, olive), fixed `LEATHER`, `BRONZE`, `TURQUOISE`, `SCLERA`, `IRIS`, `PUPIL`,
`LASH`, `SUNGLASS`, `ROYAL` (the queen's cape);
`static func colours(seed: int, role: StringName) -> PackedColorArray` (16, by slot; skin and hair
by seed; three different cloths by seed; the queen's cape `ROYAL`);
`static func image(seed: int, role: StringName) -> Image` (16 × 1, RGBA8);
`static func surface() -> Image` (16 × 1: R unused, G roughness, B metallic per slot: bronze
metallic 0.8 rough 0.35, glass rough 0.2, cloth rough 0.9, skin 0.55).

- [ ] Tests: `test_sixteen_slots`, `test_the_same_seed_gives_the_same_colours`,
      `test_seeds_differ` (25 seeds give at least 20 distinct (skin, cloth 1) pairs),
      `test_three_cloths_differ`, `test_bronze_is_metal`.
- [ ] Implement; run `.\run_tests.ps1 '-gselect=test_wadee_palette.gd'`; commit.

### Task 3: `WadeeLook`

**Files:** Create `who-knows/src/npc/wadee_look.gd`; modify `src/npc/npc_looks.gd`
(`&"wadee"`), `src/npc/npc.gd` (`_build_look` asks the site for the person), `src/npc/npc_site.gd`
(`func person(record: NpcRecord) -> Dictionary: return {}`), `test/unit/test_visual_style_rules.gd`
(`wadee_look.gd` in `PAINTING_FILES`); test `test/unit/test_wadee_look.gd`.

**Produces:** `class_name WadeeLook extends Node3D`;
`func build(variety: float, fade: Vector2) -> void`;
`func set_person(person: Dictionary) -> void` (`model`, `seed`, `role`, `staff: bool`): loads
`res://assets/wadee/wadee_<model>.glb` (cached per model), turned PI about y so it faces -z, one
`StandardMaterial3D` per person (albedo the palette image, nearest filter; roughness and metallic
from `surface()`), the staff on a `BoneAttachment3D` on `RightHand`;
`func act(action: StringName) -> void`; `const CLIPS := {action: clip}` (`&""` Idle, `&"talk"`
Idle_Talking, `&"water"` Farm_Watering, `&"harvest"` Farm_Harvest, `&"plant"` Farm_PlantSeed,
`&"kneel"` Fixing_Kneeling, `&"interact"` Interact, `&"lift"` PickUp_Table, `&"sit"` Sitting_Idle
(after Sitting_Enter), `&"drink"` Consume, `&"watch"` Idle_FoldArms (Spell_Simple_Idle with a
staff), `&"nod"` Yes, `&"carry"` Walk_Carry); `var clip: StringName` (playing now, for tests);
moving (its Npc's flat speed over 0.2 m/s) it walks, over 2.4 m/s it jogs, with
`speed_scale = speed / (PACE * hips / LIB_HIPS)` (PACE walk 1.05, jog 5.9; LIB_HIPS 0.917);
crossfade 0.3 s. LOD by the viewport camera: `cast_shadow` only within `SHADOW_WITHIN := 25.0`;
the player advances manually at 15 Hz beyond `FULL_RATE_WITHIN := 30.0`; drawn to `fade.y`.

- [ ] Tests (with a stand-in Npc parent): `test_faces_minus_z`, `test_one_mesh_one_material`,
      `test_clip_follows_action`, `test_walks_when_moving_and_jogs_fast`,
      `test_staff_only_for_the_sunguard`, `test_colours_by_seed`, `test_shadow_lod`.
- [ ] Implement; run; commit.

### Task 4: `WadooPaths`

**Files:** Create `who-knows/src/npc/populations/wadoo_paths.gd`; test `test/unit/test_wadoo_paths.gd`.

**Produces:** `class_name WadooPaths extends RefCounted`; `const CELL := 1.0`, `const REACH := 62`
(grid -62..62 m each way); `static func build(layout: Dictionary, pool_radius: float) -> WadooPaths`;
`func is_open(p: Vector2) -> bool`; `func nearest_open(p: Vector2) -> Vector2`;
`func route(from: Vector2, to: Vector2) -> PackedVector2Array` (east/north; first point `from`,
last `to` or its nearest open; string-pulled so each leg is clear);
`func clear_line(a: Vector2, b: Vector2) -> bool`.
Solid: outside the ring polygon (except within `OUTSIDE_GATES := 9.0` of the gate and the breach),
within `WALL_CLEAR := 0.9` of a wall run, yard, or pier; shells inflated `SHELL_CLEAR := 0.7`; the
pool to `pool_radius + 0.6`; garden beds; the pump 1.0; sail posts 0.4; palms 0.6; items 0.8; the
memorial `radius + 0.5`.

- [ ] Tests (on the real `oasis.json`): `test_every_door_is_reachable`,
      `test_job_spots_are_open_and_reachable`, `test_routes_never_cross_a_solid` (200 random pairs:
      every leg's `clear_line`), `test_the_pool_and_the_shells_are_solid`,
      `test_the_gate_leads_outside`.
- [ ] Implement with `AStarGrid2D` (octile, diagonal only if no obstacles); run; commit.

### Task 5: `GroundWalker`

**Files:** Create `who-knows/src/npc/ground_walker.gd`; modify `src/npc/npc.gd`
(`&"ground_walker"` in `make_locomotor`); test `test/unit/test_ground_walker.gd`.

**Consumes:** the site's `route(from: Vector2, to: Vector2) -> PackedVector2Array`,
`ground(p: Vector2) -> Vector3` (place frame), `up_at(local: Vector3) -> Vector3`,
`neighbours(npc) -> Array` (other live Wadees' local positions), `hidden(npc) -> bool`.
**Produces:** follows the route at `top_speed * intent.speed`, turning at `TURN_RATE := 5.0`
rad/s; slows within `SLOWING := 0.8` m, arrives within `ARRIVED := 0.15`; keeps `PERSONAL := 0.6`
m from others by a sideways push; kinematic (sets the transform: feet on `ground`, up
`up_at`); sets `npc.velocity` (engine space) for the look; re-plans when `move_to` changes.

- [ ] Tests (a fake site on flat and sloped ground with a wall): `test_walks_the_route`,
      `test_feet_on_the_ground`, `test_turns_to_face`, `test_keeps_apart`,
      `test_stops_at_the_target`, `test_velocity_for_the_look`.
- [ ] Implement; run; commit.

### Task 6: The cast, the site and the source

**Files:** Create `who-knows/src/npc/populations/wadoo_cast.gd`, `wadoo_site.gd`,
`wadoo_source.gd`; modify `scenes/flight_test.gd` (source in `exterior_npcs.sources`,
`max_live` 40); tests `test/unit/test_wadoo_site.gd`.

**Produces:**
- `WadooCast.PEOPLE`: 25 entries `{name, model, role, home, jobs, grief, shy}`: Queen Imsa (`q`,
  queen, `house_b`); the Sunguard Kesh (`s`, post `breach_walk`), Oru (`t`, post `queen_door`),
  three more (`s`/`t`, posts `gate`, `breach`, `pool`); 19 villagers (15 women, 4 men) including
  Halla (`c`, jobs garden_dry, memorial), Daro (`m`, glass), Lio (`a`), Wenna (`b`, bank). Others
  named from `SYLLABLES` by seed. `static func record(n: int) -> NpcRecord`.
- `WadooSite extends NpcSite` (`id = &"wadoo"`): `frame()` the place node's transform; `alive()`
  while the node is valid; `start_pose` at a job spot by seed and time; `person(record)`;
  `spots(kind) -> Array[Dictionary]` (`{key, at: Vector3, face: Vector3, action, kind}`) for
  `garden`, `pump`, `glass`, `breach`, `memorial`, `shade`, `bank`, `post`; `door_of(home)`;
  `claim(key, npc) -> bool`, `release(npc)`; `route`, `ground`, `up_at`, `neighbours`; `hide(npc,
  on)`; `partner_for(npc) -> Npc` (pairs the free and sociable within 15 m); `fill(ctx, npc)` puts
  `&"town"` (self), `&"person"`, `&"nearby"` (open points 2 m about it) in `ctx.extra`.
- `WadooSource`: `records(director)` gives the living cast while `places.loaded(&"oasis")`.

- [ ] Tests: `test_twenty_five_with_stable_ids`, `test_roles_and_species`,
      `test_homes_are_houses`, `test_spots_open`, `test_claims_are_exclusive`,
      `test_records_only_while_loaded`, `test_start_pose_on_a_spot`.
- [ ] Implement; run; commit.

### Task 7: Species and behaviours

**Files:** Create `who-knows/data/npcs/wadee_villager.tres`, `wadee_sunguard.tres`,
`wadee_queen.tres`; `src/npc/behaviours/{work,rest_shade,talk_pair,drink,mourn,go_home,keep_post,
greet,hold_court}.gd`; tests `test/unit/test_wadoo_behaviours.gd`, `test_npc_species.gd` read-backs.

**Values:** size 0.45, height 1.75, width 0.45, mass 60, top_speed 1.3 (Sunguard 1.5),
locomotor `ground_walker`, look `wadee`, `max_health` 60 / 90 / 60, `knocked_out_for` 0,
sight 25 m, cone 160°, near_sense 4, hears 1, `live_radius` 400, fade (330, 380), population
`wadoo`. Needs (rise per second): work 0.006, rest 0.003, company 0.004, thirst 0.002, grief 0.0
(the grieving 0.004), fear 0. Behaviours: villagers `work, rest_shade, talk_pair, drink, mourn,
go_home, greet, give_way`; Sunguard `keep_post, greet, give_way`; queen `hold_court`.
Each behaviour walks to a claimed spot (`Intent.go(at, 0.45)`), does its action for its time
(work 25–45 s, rest 30–60, talk 20–40, drink 6–9, mourn 30–60, home 40–90 hidden), eases its need,
releases the spot. `greet`: a reflex (threshold 0.7) the first time it sees you within 8 m in 60 s:
faces you 2.5 s, nods.

- [ ] Tests: each behaviour scored from a made-up context and walks then acts;
      species read-back; `test_npc_catalog.gd` stays green.
- [ ] Implement; run; commit.

### Task 8: The memorial

**Files:** Modify `who-knows/data/places/oasis.json` (`"memorial": {"at": [16.5, -16.5],
"radius": 2.4, "stones": 6}`), `src/world/place_field.gd` (built in `_build_village`, marked
`memorial`), `src/world/oasis_looks.gd` (`static func memorial(kit, f, radius, stones, variety)`:
six standing stones, a sunglass lamp before each), `src/world/oasis_palette.gd` (`MEMORIAL_STONE`,
`SUNGLASS`); test `test/unit/test_oasis_looks.gd`, `test_place_field.gd`.

- [ ] Tests: the memorial is in the pieces meta; its stones stand on the ground; it is clear of
      the paths' solids around it.
- [ ] Implement; run; commit.

### Task 9: In the real scene, rendered, at speed

**Files:** Create `who-knows/test/probes/wadoo_play.gd` (extends `oasis_render.gd`); modify
`test/unit/test_floating_origin_scene.gd` only if it fails.

- [ ] The probe lands at the oasis, walks out, waits for 25 live, and writes eye-height views
      (the north court, the pool bank, the memorial, the gate) and runs of frames for GIFs; it
      prints what each Wadee is doing, the worst foot gap, and fps with all in view.
- [ ] Run it windowed; fix what the pictures show; fps ≥ 80.
- [ ] Run `test_floating_origin_scene.gd`, `test_exterior_npcs.gd`, `test_npc_catalog.gd`,
      `test_visual_style_rules.gd`, `test_place_field.gd`.
- [ ] Send the owner the views and a GIF; commit.
