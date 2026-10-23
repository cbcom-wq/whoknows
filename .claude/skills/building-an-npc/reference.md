# NPC building reference

The facts behind `SKILL.md`, checked against the code on 2026-09-26 (bases' vibrations and
`RockLifeSource.quiet` added 2026-10-09; the Limpet, the Glinter and `RockLife` 2026-10-19). Paths are relative to
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
| `src/npc/npc_looks.gd`, `droid_look.gd`, `skitter_look.gd`, `legged_gait.gd`, `limpet_look.gd`, `glinter_look.gd`, `delver_look.gd` | looks |
| `src/npc/npc_debug.gd` | the F4 overlay |
| `src/npc/populations/` | `ShipCrew` + `ShipSite`; `RockLife` (every species on a rock) + `RockHerds`, `GlinterNests`, `DelverBurrows`, `LimpetBeds` (recipes) + `RockSite` + `RockLifeSource`; `DevCreatures` (F10) |
| `src/ui/creature_panel.gd` | `CreaturePanel`, the F10 dev panel |
| `data/npcs/*.tres` | species |
| `test/probes/` | `npc_probe.gd` (frame time), `droid_render.gd`, `skitter_render.gd`, `limpet_render.gd`, `glinter_render.gd`, `glinter_leap.gd`, `delver_render.gd` (not run by GUT) |

## Species fields (`NpcSpecies`)

| Group | Field | Droid | Skitter |
|---|---|---|---|
| Body | `size` (longest side), `height`, `width` | 0.55, 0.55, 0.5 | 1.3, 0.6, 0.75 |
| | `mass` (for bumps, kg), `top_speed` (m/s at speed 1) | 40, 1.8 | 90, 4.0 |
| | `locomotors` (first is active), `look`, `move_sound` | `deck_walker`; `droid`; `droid_whir` | `surface_crawler`, `zero_g_drift`; `skitter`; none |
| Senses | `sight_range`, `sight_cone_deg` (whole cone), `dark_sight` (share, outside), `near_sense` | 8, 140, 1.0, 3 | 40, 220, 0.33, 2 |
| | `feels_vibration`, `hears`, `feels_shake` (0–1), `light_response` (−1 flees … +1 drawn) | 0, 1, 1, 0 | 1, 0, 0, −1 |
| Needs | `needs` (rise/s), `need_start` (`Vector2` range) | duty .02, charge .004, curiosity .01, fear 0 | hunger .006, company .01, curiosity .008, rest .003, fear 0 |
| Mind | `behaviours`, `behaviour_weights` (missing = 1) | 8 behaviours | 10 behaviours; `defend` 1.2 |
| Health | `max_health`, `knocked_out_for` (s; 0 = it dies), `wake_health` (share) | 60, 60, 0.25 | 40, 0, — |
| Disposition | `fear_of_player`, `curiosity_about_player` | 0.1, 0.6 | 0.5, 0.4 |
| World | `population`, `live_radius` (0 = site-wide), `fade` (whole within x, gone past y) | `ship_crew`, 0, (0, 0) | `rock_herds`, 350, (250, 300) |
| | `interactions` | empty | empty |

The body's collider is a capsule sized from these: upright if `size ≤ height × 1.3`, lying along
local z otherwise. Origin at the feet; up is local +y; forward is −z.

**Fields added for the rock creatures** (`NpcSpecies`, group *Bite and drain*), and the two species that set them:

| Field | Default | Skitter, droid | Limpet | Glinter |
|---|---|---|---|---|
| `bite_damage` (hp), `bite_push` (N·s), `bite_reach` (m, from its middle) | 15, 40, 1.6 | default | 0, 40, 1.6 | 8, 25, 0.8 |
| `drain_rate` (QE/s), `drain_reach` (m) | 0, 0 (drains nothing) | default | 0.4, 5 | default |
| `shy_of_drills` | true | default | false | true |
| `grips_bases` | false | default | true | false |

| | Limpet | Glinter | Delver |
|---|---|---|---|
| `size`, `height`, `width` (m); `mass`; `top_speed` | 0.3, 0.15, 0.3; 8; 0.25 | 0.25, 0.18, 0.2; 6; 3.0 | 3.0, 0.4, 0.5; 120; 1.2 |
| `max_health`, `knocked_out_for` | 15, 0 | 20, 0 | 60, 0 |
| `locomotors` | `surface_crawler`, `zero_g_drift` | same | `surface_crawler`, `burrower`, `zero_g_drift` |
| `sight_range`, cone, `dark_sight`, `near_sense` | 20, 360, 1.0, 0 | 6, 360, **0.85**, 1.5 | 10, 220, 0.33, 2 |
| `feels_vibration`; `needs` | 0; appetite .01, fear | 1; fear | 1; hunger .004 (starts 0-0.25), fear |
| `behaviours` | `cling`, `creep`, `sip` | `lure`, `ambush`, `hide` | `feed`, `delve`, `dive` |
| `fear_of_player`; `shy_of_drills` | 0; false | 0.3; true | 0.2; true |
| `population`, `live_radius`, `fade` | `limpet_beds`, 100, (70, 95) | `glinter_nests`, 150, (110, 140) | `delver_burrows`, 250, (180, 230) |

## Health and death (`docs/superpowers/specs/2026-09-29-health-and-damage-design.md` §6)

| API | Does |
|---|---|
| `Npc.health` (`Health`), `take_damage(hp)`, `receive_hit(hit)` | a hit touches, shoves, takes `hit.damage`, raises fear by the share lost, squashes the look for `FLINCH_FOR` 0.15 s |
| `Npc.down`, `is_dead()`, `revive(fraction)` | at 0 hp: dead (on its back, `CORPSE_FOR` 20 s, shrinks over the last 1 s, demoted) or knocked out (slumped `SLUMP` 70°, up after `knocked_out_for` at `wake_health`, or at once by `revive`) |
| `Npc.bite()` (species `bite_damage`, `bite_push`, `bite_reach`) | the body's bite, asked for by an intent with action `&"bite"`; the hit is kind `&"bite"` |
| `Npc.sip(dt)`, `Npc.sipped` | the body's sip, asked for by an intent with action `&"sip"`: a hit of kind `&"sip"` with `drain` = `drain_rate × dt` to the avatar if it is within `drain_reach` of the creature's middle, else `site.sip_source(npc, dt)` (a base's store). `sipped` is the running total since it woke, for the husks |
| the `&"sip"` hit | `Hit.drain` (QE asked) and `Hit.drained` (QE given, written by the receiver); `Avatar.receive_hit` drains `suit_cell.drain(...)` on a spacewalk within `Avatar.SIP_CAP` 1.2 QE/s for all Limpets together (a budget, `refill_sip`); `SuitCell.drain(qe)` takes up to `charge` and returns it. A dry suit goes home by `Suit.home_step`. A Limpet never drains the ship's store |
| `NpcLedger` (`mark_dead`, `is_dead`, `set_health`, `health_of`, `to_dict`) | one per game (`flight_test.npc_ledger`), given to every director; `NpcDirector.amend` returns null for the dead; `demote` writes wounds; `promote` reads them. Saved as `"npcs"` |
| `ctx.extra[&"hurt_ago"]` | seconds since it was last hurt, for a behaviour to read |
| `NpcDirector.targets`, `Weapons.TARGETS`, `Weapons.npc_id(record.id)` | the exterior director joins each promoted NPC to the weapons group as `npc:<record id>` and takes it out on `demote` (ship weapons spec §4.1); the interior director's `targets` is false. A turret's phaser bolt arrives at `receive_hit` like any other hit: **15 hp a light bolt, 120 a heavy** (`WeaponValues` damage). `Weapons.usable` is false for a dead NPC (`is_dead()`), so it leaves every turret's choice and, 2 s on, the fire-control list; a knocked-out one is still a target. Test: `test_npc_director.gd` (`targets`) |
| `behaviours/ambush.gd` | a reflex that springs: you within `AMBUSH` 5 m (`ctx.position` to `ctx.player`) and fear under `CALM` 0.4 -> first think `Intent.idle(&"leap")` with `leap_to` = you; then within `bite_reach + 0.3` one `&"bite"`, else `&"lunge"`; done after the bite or `GIVE_UP` 4 s. The bite sets its fear to at least `AFTER_FEAR` 0.8 (so `hide` follows and the nest re-arms as it fades), and a give-up raises it by `GAVE_UP_FEAR` 0.3 so a miss does not spring again every 4 s. `GlinterLook` shows its eyes for `leap`, `lunge` and `bite`. `test/probes/glinter_leap.gd` is the leap check (20 tries, reach and bite), `glinter_render.gd` the renders |
| `behaviours/defend.gd` | the template for an NPC that fights back: a reflex scored from `hurt_ago`, fear and the player's distance, `Intent.go(player, 1.0, &"lunge"/&"bite")`, given up past 6 m or when calm; weight it over `scatter` |

NPCs heal `HEAL_RATE` 0.1 hp/s after `HEAL_AFTER` 10 s, only while live.

## Contracts

**A source** (anything in `NpcDirector.sources`): `records(director) -> Array` of
`[NpcRecord, NpcSite]` it may make live now. Called every `REVIEW_EVERY` (0.25 s).

**`NpcSite`:** `id`; `frame() -> Transform3D` (site to engine; outside, a node that the floating
origin moves); `gravity(local) -> Vector3`; `alive() -> bool`; `start_pose(record, time) ->
Transform3D` (site-local, feet on the ground; while `alive()` is false the `Npc` steps nothing
until the director's next review demotes it); `tint() -> Color` (the look's colour; default
`SpacePalette.UNTINTED`); `fill(ctx, npc)`. Hooks the body calls, each a no-op by default:
`died(npc)` (it died for good, after the ledger is marked; `RockSite` drops a Limpet's husks, and a Delver's shard and grit), `surfaced(npc)`
(it came up out of the ground: `Npc.surfaced()` calls it; `RockSite` pays a Delver's grit and shard), `sip_source(npc, dt) -> float` (QE the
place's own store gives it over `dt`; `RockSite` asks a base) and `group_seed(record) -> int` (the seed of
its group, given to a look that has `set_group_seed`: a nest's glints flash together).

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
| `ShipSite` | `places.dock`; `spots` (the reachable ones, each + `at`, `since`); `extra.rooms` (`[point, zone]`), `extra.nearby` (step-aside points), `extra.tended` (Callable), `extra.player_zone`, `extra.zone`; fear fades 0.1/s with no touch or sound in 2 s |
| `RockSite` | `mates` (live group mates); `places.shelter` (nearest crater floor, cached) for every species; then by species. Delver: `extra.burrows` (its round, site-local), `places.crystal` (the point it is nearest), `places.burrow` (the next one round), `extra.cycle` (its own 180-360 s from its seed), none of them for a group with no round. Skitter: `places.round` and `extra.graze` (the herd's round, cached per second); company eases near mates; fear fades 0.1/s unless jolted, touched or lit. Limpet: `places.quantum` (your suit within `SUIT_DRAW` 20 m, else the nearest module cell of an awake base within `RAID` 100 m of its bed while a non-base anchor is within `RAID_NEAR` 300 m) and, for a base, `extra.quantum_reach` `BASE_REACH` 4 m |

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
| `Base.stamp` (a module's legs landing as it unfolds) | vibration 1.0 (`HabitatValues.STAMP_STRENGTH`), 60 m (`STAMP_RADIUS`), the rock's site: scatters the herds near |
| `Base.hum` (each working drill, every `HUM_EVERY` 3 s) | vibration 0.2 (`HUM_STRENGTH`), 80 m (`HUM_RADIUS`), the rock's site: under `Scatter`'s 0.45, felt but never startling |

Bases give off `VIBRATION` on the rock they stand on (habitat modules spec §8.4): the planting
stamp and each drill's hum, both sent from the base's exterior with the base's `site.site_id`
(its rock's `RockHerds.site_of`), so only that rock's skitters feel them.

**Species that are `shy_of_drills` keep away from a drill** (`RockLifeSource.quiet`, a Callable `(site id, engine point) ->
bool`, wired by the flight scene to `Bases.quiet`; a species that is not shy, the Limpet, is never asked): true when a drill on that rock's base has run
`HabitatValues.QUIET_AFTER` (600 s) and stands within `QUIET_RADIUS` (80 m) of the point. It is
asked **once per record when the rock's `RockSite` is (re)built** (`_offered`, keyed by rock id,
cleared when the rock leaves), never on every review: live skitters never vanish in view, and the
herd is gone the next time the rock comes into detail. No behaviour changes.

`RockHerds.site_of(rock)` names a rock as a site (`&"rock:x_y_z_w"`); vibrations carry it.

## Rock creatures (`docs/superpowers/specs/2026-10-10-rock-creatures-design.md`)

**`RockLife`** (`src/npc/populations/rock_life.gd`) lists every group of every species on a rock.
`ORDER` is `[skitter, glinter, delver, limpet]` and only grows at its end; `RECIPES` maps a species to its
class (`GlinterNests`, `DelverBurrows`, `LimpetBeds`); `SPACING` 30 m; a species whose class is not in the
project yet is skipped. `groups(rock, data, seed)`, `records(rock, data, seed, groups)`, `member_dirs(g, data)`,
`clear_of(data, dir, taken, metres)`. Record ids are `"<species>:<site>:<group>:<n>"` (the skitters' are as
`RockHerds` makes them, pinned by `test/unit/golden/rock_life_skitters.json`); `herd` is the group index.

**A recipe** is a class with `static groups(rock, data, world_seed, taken: Array[Vector3], first_index) ->
Array[Dictionary]` (each `{index, species, home_dir, count, seed}` and its own keys, `crater`, `salvage`) and
`static member_dirs(g, data) -> Array[Vector3]`. Directions are unit vectors in the rock's frame as
`RockDetail` makes them. Its salt differs from every `AsteroidRecipe.cell_seed` salt in use: tiers 0-2, rock
detail 7, herds 11, **Glinter 13**, Delver 17, **Limpet 19**.

**`RockLifeSource`** replaces `RockHerdSource`: one `RockSite` per rock in detail near an anchor, built with
the Callables it holds (`quiet`, `place_salvage`, `base_place`, `base_sip`, `drop`, `count_near`), and
`site_for(rock)`. `POPULATIONS` lists the population ids it offers.

**`RockSite`** (one site for every species on the rock): `groups`, `records`, `dirs` (record id -> the
direction its home was made from), `group_of(record)`, `pose_at(dir)`, `place_nests()`, `add_group(...)`.
Its Callables, all optional (check `is_valid()`), engine-space points, set by the source and wired in
`flight_test._wire_npcs`:

| Callable | Is | Wired to |
|---|---|---|
| `place_salvage(cloud_id, centre, entries)` | registers a nest's real salvage | `SalvageField.add_placed_cloud` |
| `base_place(site_id, from)` | the nearest module cell of an awake base, or null | `Bases.place_of` |
| `base_sip(site_id, point, qe)` | the QE the base gave | `Bases.sip` |
| `drop(kind, at, up, count)` | drops stray items | the flight scene's `_drop` |
| `count_near(kind, at, radius)` | how many of `kind` lie within `radius` | `StrayField.count_of` |

Its hooks (overrides of `NpcSite`): `died(npc)` drops husks (1, and one more per `HUSK_PER_QE` 40 QE sipped, to
`HUSKS_MAX` 4), `sip_source(npc, dt)` (`BASE_RATE` 0.05 QE/s from a base), `group_seed(record)`, and `surfaced`
(a Delver's pay: see *The Delver*, below). `died` for a Delver drops one `quantum_shard` and `DELVER_GRIT` 6 `crystal_grit`, behind its tail, with no cap (a windfall). `RockDetail.dir_of(p)` turns a rock-frame point into the direction whose surface
point lies along it; use it, never `normalized()`.

**Bases and the world:** `Bases.sip(site_id, point, qe)` (0 if the base is asleep, has no store, or `point` is
over `Bases.SIP_REACH` 4 m from every module cell centre; else spends from the store, purpose `&"limpet"`),
`Bases.place_of(site_id, from)`. `SalvageField.add_placed_cloud(id, centre, entries)` takes `{index, kind,
variety, pose}` entries (pose relative to `centre`), loads at once if the focus is near, is not saved (the
ledger of what was taken is), and `is_placed(id)`. `StrayField.count_of(kind, at, radius)` counts the ledger's
strays, loaded or not. `ItemLooks.Glint.clock_phase` (a float: lit while `Time.get_ticks_msec()/1000 + phase`
falls in the first `GLINT_FLASH` of a period; null: counts its own time) with `lit_at(seconds)`. The Limpet's
drop is the item `limpet_husk` (a glinting look).

**F10, `CreaturePanel`** (`src/ui/creature_panel.gd`; same place as F6's panel, each shuts the other, group
`CreaturePanel.GROUP`): `1`-`9` ask for the species in `CreaturePanel.ORDER` that the catalogue has;
`creature_asked(index)`; `say(text)` for the last line. The flight scene's `spawn_creature(species)` makes a
group at the crosshair's rock (skitters 3, glinters 4, limpets 6, anything else one; the droid on the deck you
look at, aboard) through `RockSite.add_group`, into `DevCreatures` (a source on each director; not saved;
forgotten once its creature has been live and is not, or its site goes). **Dev ids** are
`"dev:<species>:<n>"`, `n` counting on for the session across every `DevCreatures` and skipping any id the
ledger knows (dead or hurt), so no id is ever reused. Dev groups are indexed from `RockSite.DEV_FIRST` 1000.

## The Delver (rock creatures spec §5; `test_delver_burrows.gd`, `test_delver_behaviours.gd`, `test_delver_pay.gd`)

**`DelverBurrows`** (`src/npc/populations/delver_burrows.gd`, salt `SALT` 17): `groups(rock, data, seed, taken, first_index)` makes one
group on a `RockMesh.Shape.VEINED` rock only, `{index, species, home_dir, count 1, seed, burrows}`: its home is a vein direction
(`RockMesh.in_vein`) clear of `taken` by `RockLife.SPACING`, its `burrows` (`POINTS` 6-10 directions) are the home first, then vein
directions within `REACH` 0.5 rad of it, `GAP` 15 m apart (surface point to surface point; the reach widens a quarter after `TRIES` 40
failures in a row until `POINTS.x` fit). `member_dirs(g, data)` is `[home_dir]`. `round_near(data, dir, rng)` is the same round about any
direction, vein or not: `RockSite.add_group` gives a dev Delver one, so F10 puts a working Delver on any rock. `CYCLE` is
`Vector2(180, 360)` s.

**`RockSite`:** `burrow_points(g)` (the round as site-local surface points, cached per group), `cycle_of(record)` (`lerpf(CYCLE.x, CYCLE.y,
randf)` from `record.seed`, cached), `_fill_delver(ctx, record)`. Pay: `surfaced(npc)` rolls from `rolls`, a `RandomNumberGenerator` per site, `randomize()`d when the site is built
(not seeded from the record: the site is rebuilt on every return to the rock, which would repeat the first roll; a test sets `rolls.seed`): `GRIT` (2, 4) grit always rolled, and a shard when `randi_range(0,
SHARD_ODDS - 1) == 0` (`SHARD_ODDS` 12); the grit is dropped unless `count_near(&"crystal_grit", the rock's centre, cap_radius())` is
`GRIT_CAP` 8 or more, the shard unless one `quantum_shard` already lies within `cap_radius()` (`rock.radius + CAP_MARGIN` 50 m). With no
`count_near` wired there is no cap. Both go to `behind(npc)`: `TAIL_CLEAR` 0.5 m past the tail, up the Delver's up. **Both items are strays**
(the flight scene's `_drop` adopts them into `StrayField`), so they save and unload as any stray; `crystal_grit` is `data/items/crystal_grit.tres`
(15 QE, `0.09 x 0.07 x 0.09`, `stow_class` small, `ItemLooks.crystal_grit`: three lavender splinters in `InteriorPalette.LAVENDER` and `HOLO_DIM`,
solid, and in `ItemLooks.GLINTS`).

**Behaviours:** `feed` (score `Curves.ramp(hunger, 0.3, 0.8)`; to `places.crystal` at speed 0.5 until within `THERE` 1 m, then `Intent.idle(&"eat")`
and hunger eases `EATING` 0.05/s; done below `FULL` 0.1; `min_time` 3), `delve` (score 0.7 when hunger is under 0.3 and `extra.surfaced_ago >=
extra.cycle`; `Intent.go(places.burrow, 1.0, &"burrow")`; done once `surfaced_ago < running(ctx)`, i.e. it came up since it began), `dive` (a reflex,
threshold 0.5, score 1.0 on a `VIBRATION` or `TOUCH` percept within `FRESH` 1 s and at least `FELT` 0.25 sure -- the hum of a drill, 0.2, is not
a reason to run -- while `ctx.grounded`; `Intent.go(Behaviour.farthest_from(extra.burrows, position, position), 1.0, &"burrow")`; done as
`delve`). All three score 0 without the site's round. In the brain they cycle: it eats when hungry, digests, goes under once each cycle and
never while hungry (`test_the_mind_cycles_feed_digest_burrow`).

**Probe:** `test/probes/delver_render.gd` (windowed; `--no-snag`, `--far-only`) shoots `delver_close`, `_closer`, `_sink_1..3`, `_rise_1..3`, `_heap`,
`_heap_close`, `_40m`, `_40m_low`, `_100m`, `_100m_low` and zooms, and sends the Delver over five legs of 30-67 m (into and out of a crater, open
ground) printing whether the 3 m body snags (spec §16). On the start rock (a SHARD, radius 284 m, 6 craters) 2026-10-22: no leg snagged; the
Delver kept 1.1-1.2 m/s on every leg, arrived on all five and never stalled for half a second, so the 1.2 m head collider was not needed
(the crawler reads the ground by rays, not by sliding its collider on the mesh).

## Sensors (NPC foundation spec §22)

- **`ShipSensors`** at `Ship/Sensors`: `universe` (the flight scene sets it), `time` (its clock),
  `add_source(source)`, `contacts(range_m)` (nearest first, cached 0.25 s), `refresh(range_m)`,
  `contact(id)`, `focus_point()`.
- **A source:** `contacts(focus: UniversePoint, range_m, time) -> Array[Contact]`,
  `contact(id, focus, time) -> Contact`. `LifeContacts(stream, exterior director, universe)`:
  one per group of any species in detail, id `&"life:<site>:<group>"`, at its awake members' middle, or its round (a group with none: its home).
- **`Sense.read(profile, focus, target, id, time) -> Contact`**, pure. `SenseProfile.life()`:
  reach 4000, region within 1000, radius 15, offset 7, ping ±10° every 4 s.
  `SenseProfile.salvage()`: 10000, 2000, 75, 50.
- **`Contact`:** `id`, `kind`, `label`, `point` (`UniversePoint`), `precision` (`EXACT`, `PING`,
  `REGION`), `radius`, `km`, `taken`, `fresh_for`.
- **`ContactMarker`:** nearest `MOST` (3); colour `HudPalette.for_kind(kind)` (`LIFE`,
  `SALVAGE`, else `READOUT`); `set_camera(cam)` (null: spacewalk only, through the viewport's
  camera when `telemetry.has_beacon`); `marks` lists what it drew. Mounted in
  `flight_test._wire_sensors` as `ContactsCockpit`, `ContactsChase`, `ContactsSpacewalk`.

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
- **`DeckPaths`:** no airlock, no fixture cells, no `avoid` cells (the ship passes none); rooms joined only
  through their doorway; one diagonal step past the corner between two quiet fixtures
  (`InteriorLayout.QUIET_FIXTURES`) with open floor all round it -- `DeckWalker` drives it
  straight, 1.3 m clear on the starter; `cell_at(p)`, `floor_point(cell)`, `path`, `distances`,
  `linked`.
- **`SurfaceCrawler`:** `STICK` 0.6 m/s, `SETTLE` 0.05 s, `LEAD` 6, `ACCEL` 10, `TURN_RATE` 5,
  `PERSONAL` 1.2 m, `LOST_AFTER` 0.2 s, `KNOCKED_OFF` 1.5 m/s, `SLIPPERY` 3 m/s, `LEAP_REACH`
  30 m, `STILL` 0.25 m/s, `RECHECK` 30 ticks, `WALL_GAP` 0.45 m. Rays on layer 64 only.
  `mates` (site-local) is set on it for separation. `BASE_LAYER` 1: a species with `grips_bases` also rays layer 1 (a base's body, never a ship's hull: `_ray` drops a hit there without meta `base`). A leap: intent action `&"leap"` with
  `leap_to`; refused if the ray finds nothing within reach. The leap's ray hits rock and the
  avatar (`AVATAR_LAYER` 4: a Glinter's ambush), so a leap can be aimed at a spacewalker.
- **`ZeroGDrift`:** `LEAP_SPEED` 6, `REBOUND` 0.5 m/s (a leap meeting the suit or passing its aim ends, `leaping()`), `TUMBLE` 0.6 s, `PUFF` 0.8 m/s at most once a second,
  `PUFFS` 6 (refilled on every `enter`: per trip off the rock), `LOOK` 60 m, `LANDED` 0.6 m.
- **`Burrower`** (`burrower`; only on a `RockSite`): the mind asks `Intent.go(point, speed, &"burrow")` and `SurfaceCrawler.handover` 
  sends it (`SurfaceCrawler.burrow_asked`: on a rock, the species has the locomotor, `move_to` set). `SINK` 1.5 s (the look drops by
  `species.height`, `Npc.sink_look`), then `Npc.set_solid(false)`, look hidden, `Weapons.leave`; `UNDER_SPEED` 2 m/s along `RockDetail.dir_of`
  directions with no ray; at the target `site.pose_at(data.dir_of(target))` once, `Weapons.join` if the director has `targets`, `RISE` 1.5 s,
  `set_solid(true)`, `Npc.surfaced()` (`surfaced_at`, `site.surfaced`, `look.act(&"emerge")`), and it clears the spent burrow intent and
  hands back to the crawler. `ctx.extra[&"surfaced_ago"]` is the seconds since `surfaced_at` (set at `setup` too). `Npc.setup` makes a
  pooled node solid and drawn again. `test_burrower.gd`.
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
- `SkitterLook`: built 0.85 m long and scaled to the species by the `Npc`
  (`NpcLooks.built_size`); `ArrayMesh` facets with vertex colours from `SpacePalette` (the back
  `SpacePalette.skitter(rock colour)`, 30% toward `CRYSTAL`, in three shades; two `CRYSTAL`
  patches; `SKITTER_EYE`; `scree` underside and legs); `THIGH` 0.15, `SHIN` 0.17, feet
  clamped to reach; `LeggedGait` tripods (legs 0, 3, 4 then 1, 2, 5), rays only within 60 m of
  the camera, legs posed every 6th frame beyond 100 m and not past the fade; actions `freeze`,
  `graze`, `rest`, `puff`; under 300 triangles.
- `LimpetLook`: built 1 m across, 0.58 m high; a shell of eight scalloped facets in the rock's shades
  (`SpacePalette.shade`, ash on a veined rock) with a raised apex nub, and eight lavender crystal ribs
  (`SpacePalette.CRYSTAL`) on a second mesh that swaps to the brightest `SHADES` step on `sip`; no glow;
  80 triangles at most.
- `DelverLook`: built at its own size, 3 m long (`LENGTH`; `NpcLooks.built_size` 3.0, so the `Npc` scales it by 1), head at -z, 0.4 m high
  and 0.5 wide bar a crystal's point; six bevelled hexagonal plates (`PLATES`; each a tube whose top slopes up to its rear, so the
  silhouette is a sawtooth) in `scree(UMBER)` and `scree(RUST)` alternately, a `RUST` head with two `SKITTER_EYE` facets, a snout of three
  `CRYSTAL` crystals (two darkest steps at rest, the brightest on `eat`), a lavender crystal on each plate (`Crest`, swept toward the tail),
  no legs; about 230 triangles, at most 300; `act(&"emerge")` makes `PUFFS` 10 `Puffs.mesh` spheres as children of the look in a ring
  `RING` (0.7 x 1.9 m) that drift out and fade over `PUFF_TIME` 1.4 s (no world-space particles, so the floating origin never strands
  them); meshes `Plates`, `Crest`, `Head`, `Snout`.
- `GlinterLook`: built 1 m long, 0.72 m high; a six-sided domed shell of big flat facets in `SLATE` shades
  with two opposite `RUST` patches, a blunt rust head, six short two-jointed legs; `eyes` (two `SKITTER_EYE`
  quads) shown on `leap`, `lunge` and `bite`; wears `ItemLooks.glint` on `BEAT` 1.6 s, set by `set_group_seed`
  through `Glint.clock_phase` so a nest flashes together; at most 120 triangles.

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
  (`scene.save_enabled = false` first in any script run without `--headless`),
  `add_child_autofree`, `await wait_physics_frames(3..5)`; the droid is
  `ship.npc_director.live.values()[0]`; the exterior director is `root.exterior_npcs`. Stop a
  director (`set_physics_process(false)`) when setting intents by hand. To hold the felt gravity,
  stop `Ship/MotionCoupling` first. Move the hull with `exterior.global_position` stepwise to
  wake herds. The start rock is `stream.details.nearest(ship.exterior.global_position)`: it lies
  in a belt, so other big rocks can be in detail too (the system skeleton spec §6).
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
