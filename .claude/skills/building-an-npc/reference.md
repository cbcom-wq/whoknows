# NPC building reference

The facts behind `SKILL.md`, checked against the code on 2026-09-26. Paths are relative to
`who-knows/` unless they start with `docs/` or `.claude/`. If a name here no longer exists,
trust the code and fix this file.

## Files

| File | What |
|---|---|
| `src/npc/npc_record.gd` | `NpcRecord`: `id`, `species`, `site`, `home` (site frame), `seed`, `herd`; `make(...)` |
| `src/npc/npc_species.gd` | `NpcSpecies extends Resource`, every field `@export` |
| `src/npc/npc_catalog.gd` | `NpcCatalog.load_from_dir("res://data/npcs")`, `get_def(id)`, `register(def)` |
| `src/npc/npc_director.gd` | `NpcDirector`: promote, demote, pool, think schedule, LOD, herds |
| `src/npc/npc.gd` | `Npc extends CharacterBody3D` |
| `src/npc/npc_site.gd` | `NpcSite`: what a place tells its NPCs |
| `src/npc/npc_context.gd` | `NpcContext`: all a behaviour may read |
| `src/npc/intent.gd` | `Intent`: `move_to`, `face`, `speed`, `action`, `leap_to` |
| `src/npc/brain.gd`, `behaviour.gd`, `npc_behaviours.gd`, `curves.gd` | the mind |
| `src/npc/perception.gd`, `npc_memory.gd`, `stimulus.gd`, `stimulus_bus.gd` | the senses |
| `src/npc/locomotor.gd`, `deck_walker.gd`, `deck_paths.gd`, `surface_crawler.gd`, `zero_g_drift.gd` | movement |
| `src/npc/npc_looks.gd`, `droid_look.gd`, `skitter_look.gd`, `legged_gait.gd` | looks |
| `src/npc/npc_debug.gd` | the F4 overlay |
| `src/npc/populations/` | `ShipCrew` + `ShipSite`; `RockHerds` + `RockSite` + `RockHerdSource` |
| `data/npcs/*.tres` | species |
| `test/probes/` | `npc_probe.gd` (frame time), `droid_render.gd`, `skitter_render.gd` (not run by GUT) |

## Species fields (`NpcSpecies`)

| Group | Field | Droid | Skitter |
|---|---|---|---|
| Body | `size` (longest side), `height`, `width` | 0.55, 0.55, 0.5 | 0.85, 0.4, 0.5 |
| | `mass` (for bumps, kg), `top_speed` (m/s at speed 1) | 40, 1.8 | 25, 4.0 |
| | `locomotors` (first is active), `look`, `move_sound` | `deck_walker`; `droid`; `droid_whir` | `surface_crawler`, `zero_g_drift`; `skitter`; none |
| Senses | `sight_range`, `sight_cone_deg` (whole cone), `dark_sight` (share, outside), `near_sense` | 8, 140, 1.0, 3 | 40, 220, 0.33, 2 |
| | `feels_vibration`, `hears`, `feels_shake` (0–1), `light_response` (−1 flees … +1 drawn) | 0, 1, 1, 0 | 1, 0, 0, −1 |
| Needs | `needs` (rise/s), `need_start` (`Vector2` range) | duty .02, charge .004, curiosity .01, fear 0 | hunger .006, company .01, curiosity .008, rest .003, fear 0 |
| Mind | `behaviours`, `behaviour_weights` (missing = 1) | 8 behaviours | 9 behaviours |
| Disposition | `fear_of_player`, `curiosity_about_player` | 0.1, 0.6 | 0.5, 0.4 |
| World | `population`, `live_radius` (0 = site-wide), `fade` (whole within x, gone past y) | `ship_crew`, 0, (0, 0) | `rock_herds`, 350, (250, 300) |
| | `interactions` | empty | empty |

The body's collider is a capsule sized from these: upright if `size ≤ height × 1.3`, lying along
local z otherwise. Origin at the feet; up is local +y; forward is −z.

## Contracts

**A source** (anything in `NpcDirector.sources`): `records(director) -> Array` of
`[NpcRecord, NpcSite]` it may make live now. Called every `REVIEW_EVERY` (0.25 s).

**`NpcSite`:** `id`; `frame() -> Transform3D` (site to engine; outside, a node that the floating
origin moves); `gravity(local) -> Vector3`; `alive() -> bool`; `start_pose(record, time) ->
Transform3D` (site-local, feet on the ground); `tint() -> Color` (the look's colour; default
`SpacePalette.UNTINTED`); `fill(ctx, npc)`.

**`Locomotor`:** `id`; `enter(npc)`; `step(npc, intent, delta)`; `exit(npc)`; `handover(npc) ->
StringName` (`&""` to stay); `grounded() -> bool`; `shoved(npc, dv)`.

**`Behaviour`:** `id` (from its file name), `reflex`, `threshold`, `min_time`, `weight`,
`started`; `score(ctx) -> float`, `start(ctx)` (call `super(ctx)`), `think(ctx) -> Intent`,
`done(ctx) -> bool`, `running(ctx)`. Static helpers: `flat_distance(a, b)`,
`farthest_from(points, from, fallback)`, `player_at(ctx, seconds)`.

**A light** (group `StimulusBus.LIGHTS`): `light_reach() -> float` (0 while off),
`light_cone_deg() -> float` (whole cone; 360 all round), `light_origin() -> Transform3D`
(shining along −z), `light_kind() -> StringName` (`&"lamp"`, `&"flare"`). `HandLamp` and `Flare`
answer them.

**A look:** a `Node3D` from `NpcLooks.build(look, variety, inside, tint, fade)`; optional
`act(action)`. The `Npc` calls `act(intent.action)` every think; `ZeroGDrift` calls
`act(&"puff")`.

## The brain (`Brain`)

- Each think: needs rise by `species.needs[n] × dt`; every behaviour scores (`× weight`); a
  reflex at or over its `threshold` wins at once; otherwise the best ordinary one, the current
  one's score × `STICK` (1.25). A behaviour younger than its `min_time` and not `done` is kept,
  unless a reflex fires. A behaviour that is `done` but still wins starts again.
- `brain.scores` holds the last think's scores (the overlay shows the top three).
- `Curves`: `ramp(x, a, b)`, `smooth(x, a, b)`, `above(x, t)`, `inverse(x)`.

## The context (`NpcContext`)

Filled by the `Npc` (record, species, memory, time, dt, `position`/`forward`/`up` in the site's
frame, `grounded`), then `Perception` (`lit`, `player`, `player_moving`, `extra.flare_moving`,
percepts), then the site's `fill`:

| Site | Fills |
|---|---|
| `ShipSite` | `places.dock`; `spots` (each + `at`, `since`); `extra.rooms` (`[point, zone]`), `extra.nearby` (step-aside points), `extra.tended` (Callable), `extra.player_zone`, `extra.zone`; fear fades 0.1/s with no touch or sound in 2 s |
| `RockSite` | `mates` (live herd mates); `places.round` and `extra.graze` (the herd's round, cached per second); `places.shelter` (nearest crater floor, cached); company eases near mates; fear fades 0.1/s unless jolted, touched or lit |

`ctx.need(n)`, `ctx.ease(n, rate)` (per second over `dt`), `ctx.raise(n, amount)`,
`ctx.recent(kind, seconds) -> Percept`, `ctx.voice`.

## Senses

**Percept kinds** in `NpcMemory` (half-life 6 s, forgotten below 0.05, pruned once over 8):
`Perception.PLAYER`, `LIGHT`, `FLARE`, `MATE_BOLTED`, and the stimulus kinds `Stimulus.VIBRATION`,
`SOUND`, `TOUCH`, `SHAKE`. Positions are site-local.

- **Sight:** avatar (group `Avatar.GROUP`) in the same bus's space, within range (`dark_sight` of
  it in the dark outside; lit if near or carrying a light, or in a light's beam), in the cone, one
  clear ray (mask 2 inside, 64 outside). Within `near_sense` the cone and range are ignored.
  Herd mates running `scatter` are noted as `MATE_BOLTED` (panic spreads by sight).
- **Vibration** only through its own rock (`s.site == npc.site.id`) and only while `grounded`.
- **Touch:** `Npc.skin` (avatar, or a rigid body moving ≥ 1 m/s against it) and `receive_hit`.

**Emitters in the game now** (all `StimulusBus.send`):

| Where | Kind, strength, radius |
|---|---|
| `PlasmaBolt._tell_npcs` | sound 1.0, 15 m; on a rock, vibration 0.8, 40 m |
| `Item.watch_first_impact` (after `Grasp.throw`) | sound by throw speed / 6, 10 m |
| `Avatar._footfalls` (sprinting aboard, every 0.5 s) | sound 0.4, 6 m |
| `Avatar._jolt_rocks` (spacewalk bump > 0.3 m/s) | vibration closing / 3, 30 m, the rock |
| `Ship._jolt_rock` (hull strike) | vibration knock / 4, rock radius × 2, the rock |
| `Ship._blast_rock` (burn over 10 % within 50 m of a rock, 2 Hz) | vibration 0.6, 40 m |
| `MotionCoupling.drive_felt_gravity` (shove changes > 3 m/s² in a tick) | shake, shove / 12 |

`RockHerds.site_of(rock)` names a rock as a site (`&"rock:x_y_z_w"`); vibrations carry it.

## Directors

| | Exterior (`flight_test.gd._wire_npcs`) | Interior (`Ship._make_crew_quarters`) |
|---|---|---|
| Rule | `BY_DISTANCE`: live within `live_radius` of a node in `anchor_group` (`AsteroidStream.SPACE_ANCHOR`: the hull, you on a spacewalk); demoted past `live_radius + DEMOTE_MARGIN` (100) and only if no camera could see it | `BY_SITE`: every record of a live site |
| `max_live` | 32 (over it: farthest out, one warning) | 8 |
| Holder, bus | scene root children; bus `setup(self, _universe)` | `Ship/Interior/Npcs`; bus `setup(interior)` |
| Cameras (for sight and LOD) | chase, canopy, avatar | none (always full detail) |

- Thinking: 5 Hz (`THINK_HZ`), each NPC on its own tick (`think_group`) of a 12-tick round.
- LOD (`set_detail`, nearest camera): under 60 m every tick and every turn; under 150 m move
  every 3rd tick, think every 2nd turn; beyond, every 6th and 3rd.
- `promote` pools by species; `demote` returns to the pool; `amend(record)` is the ledger hook;
  `herd_of(npc)` lists live herd mates; `anchors()`, `live_npcs()`, `could_be_seen(npc)`.
- A record demoted in a review is not woken in the same review.

## Movement numbers

- **`DeckWalker`:** `GRIP` 8 m/s², `BRACED_GRIP` 10 (action `&"brace"`), `CORNER` 0.3 m,
  `SLOWING` 0.5, `ARRIVED` 0.05, `TURN_RATE` 4 rad/s. Gravity: `ShipSite.gravity()` =
  `FeltGravity.felt`. Plans with `DeckPaths.path(cell_at(here), cell_at(to))`, replans when
  `move_to` or `ShipSite.version` changes.
- **`DeckPaths`:** no airlock, no fixture cells, no `avoid` cells (unplated); rooms joined only
  through their doorway; `cell_at(p)`, `floor_point(cell)`, `path`, `distances`, `linked`.
- **`SurfaceCrawler`:** `STICK` 0.6 m/s, `SETTLE` 0.05 s, `LEAD` 6, `ACCEL` 10, `TURN_RATE` 5,
  `PERSONAL` 1.2 m, `LOST_AFTER` 0.2 s, `KNOCKED_OFF` 1.5 m/s, `SLIPPERY` 3 m/s, `LEAP_REACH`
  30 m, `STILL` 0.25 m/s, `RECHECK` 30 ticks, `WALL_GAP` 0.45 m. Rays on layer 64 only.
  `mates` (site-local) is set on it for separation. A leap: intent action `&"leap"` with
  `leap_to`; refused if the ray finds nothing within reach.
- **`ZeroGDrift`:** `LEAP_SPEED` 6, `TUMBLE` 0.6 s, `PUFF` 0.8 m/s at most once a second,
  `PUFFS` 6, `LOOK` 60 m, `LANDED` 0.6 m.
- **Bumps:** `Avatar.bump` shares momentum with an `Npc` by the rocks' rule
  (`SUIT_MASS × m / (SUIT_MASS + m)`, bounce 0.2) through `npc.shove`.

## Physics layers

| Body | Layer | Mask |
|---|---|---|
| `Npc` outside | 128 (`npcs`) | 1 hull, 4 avatar, 32 items, 64 rocks |
| `Npc` inside | 128 | 2 interior, 4 avatar, 32 items |
| `Npc.skin` | 0 | 4 \| 32 (\| 64 outside) |
| Avatar aboard / suit, items, rock bodies, hull, bolt and pistol rays, door triggers | — | each includes 128 |

## Looks

- `DroidLook`: interior kit pieces (`NpcLooks.droid_body/wheel/cap/arm(kit, frame, ...)`),
  `InteriorPalette.DROID_BODY`, `DROID_WHEEL`; eye in the `GLOW` batch; actions `polish`,
  `scan`, `tidy`, `notice`, `startle`, `brace`; 512 triangles (pinned).
- `SkitterLook`: `ArrayMesh` facets with vertex colours from `SpacePalette` (the rock's shades,
  `CRYSTAL` patch, `SKITTER_EYE`, `scree` underside and legs); `THIGH` 0.15, `SHIN` 0.17, feet
  clamped to reach; `LeggedGait` tripods (legs 0, 3, 4 then 1, 2, 5), rays only within 60 m of
  the camera, legs posed every 6th frame beyond 100 m and not past the fade; actions `freeze`,
  `graze`, `rest`, `puff`; under 300 triangles.

## Testing patterns

- **A behaviour:** build an `NpcContext` by hand (`memory = NpcMemory.new()`, `needs`, `record`,
  `species`, `up`, `forward`), call `score`/`start`/`think`/`done`. Note percepts with
  `ctx.memory.note(kind, source_id, where, sure, ctx.time)`.
- **A body:** a `FakeSite extends NpcSite` with an identity `frame()`, an `Npc` added to a test
  root, `npc.setup(record, species, site, inside, pose)`, set `npc.intent`, `await
  wait_physics_frames(n)`. Build shapes as `StaticBody3D`s on layer 64.
- **A director:** a fake source (`records()` returning entries), `director.set_physics_process
  (false)`, call `review()` and `think_step()` yourself; subclass `_make_npc()` or `amend()` to
  count.
- **The real scene:** `load("res://scenes/flight_test.tscn").instantiate()`,
  `add_child_autofree`, `await wait_physics_frames(3..5)`; the droid is
  `ship.npc_director.live.values()[0]`; the exterior director is `root.exterior_npcs`. Stop a
  director (`set_physics_process(false)`) when setting intents by hand. To hold the felt gravity,
  stop `Ship/MotionCoupling` first. Move the hull with `exterior.global_position` stepwise to
  wake herds; the start rock (`stream.details.live.values()[0]`) has two herds, 13 skitters.
- Physics frames run in real time: keep waits short (a 10 s walk is 10 s of suite time).
  `wait_process_frames` for overlays and looks.
- Expected warnings and errors: `assert_engine_error(text)` / `assert_push_error(text)`.

## Commands

- **Tests (Windows):** `& .\who-knows\run_tests.ps1`, or `'-gselect=test_name'`.
- **After adding a `class_name`:** `<godot> --headless --path who-knows --import`.
- **In a Linux cloud container** (no Godot installed): download
  `https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip`
  (the standard build runs this GDScript-only project), then
  `godot --headless --path who-knows -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`.
- **Frame time:** `godot --headless --path who-knows --script res://test/probes/npc_probe.gd`.
- **Renders:** without `--headless`: `godot --path who-knows --resolution 1280x720 --script
  res://test/probes/<render>.gd -- <abs out dir>`. In a container: `apt-get update && apt-get
  install -y mesa-vulkan-drivers`, then prefix with `xvfb-run -a -s "-screen 0 1280x720x24"`.

## Specs to read for depth

- `docs/superpowers/specs/2026-09-26-npc-foundation-design.md` (§21 is what was built).
- `docs/superpowers/plans/2026-09-26-npc-foundation.md` (task order that worked: inside first,
  then outside; renders at the end of each NPC).
- `docs/superpowers/specs/2026-09-24-asteroids-design.md` §4 (floating origin), §18 (big rocks
  in detail: the ground skitters walk on).
