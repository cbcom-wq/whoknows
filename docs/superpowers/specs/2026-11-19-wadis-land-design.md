# WADIS's land: a world plan with a sea, mountains, canyons and wild oases

Status: draft for the owner, 2026-11-19. Branch `world-plan` (worktree `D:/git/whoknows-world-plan`).

Builds on the desert world (`2026-11-03-desert-world-design.md`, phases 0–3), the world scale
spec (`2026-09-30-world-scale-design.md`: the quadtree, chunks and the speed limit) and Wadoo
(`2026-11-16-wadoo-design.md`).

## 1. Why

The owner, 2026-11-19:

> How can we improve the generated terrain of Wadis? Currently it is just a vast mostly flat desert
> with a few plateaus. I wish there was at least one sea and more mountains, canyons with a few
> generated Oasis. Just a more dynamic realistic landscape but still mostly desert. Think of how we
> can seed to control how planet terrain and environment is generated to apply to other planets as
> well. Also think how we can improve performance, smooth things out when far away and only bring
> in detail when really close to the ground, maybe employ a stricter speed limit near the ground so
> we don't go so fast rendering can't catch up.

On the sea: "I guess it depends what is reasonable to accomplish. Could have a boat. I imagine some
type of cities or settlements we create in the future along waters edge." On the oases: "Wild ones
for now, I could see us wanting to add more settlements though. Maybe even generated settlements."

**What WADIS is today** (sampled 2026-11-19, 20,000 points): radius 54.6 km, relief allowed 864 m,
but the ground runs only from −31 m to +270 m. About 55% is dunes within 40 m of the floor, 26% is
flat plateaus that all stand at the same 270 m (the top terrace: `MESA_STEP` is so small that any
mesa reaches its fourth terrace), and the rest is the tower band between. There are no valleys and
nothing climbs. `DUNE_FLOOR` squashes the continent layer to a quarter under the dunes. That is
why it reads as flat.

**How the ground streams today:** a cube-sphere quadtree of 16 × 16-quad chunks, 1.3 m quads at
the finest on WADIS (depth 12, 21 m chunks), split at 1.5 chunk edges from the ground, up to 12
building on workers, each job making its own `WorldTerrain`. The speed limit near the ground is
120 m/s plus 1 m/s per 40 m up (`FlightComputer.speed_limit`); boost does not raise it; with the
assist off there is no limit at all. Low flight over rough ground was the slowest view in phase 2
(98 fps at 30 m over talus).

## 2. The moment this is for

You warp in over WADIS. From orbit there's a blue-green sea in a great basin, brown ranges with
their feet in the sand, and dark lines where canyons cut the plateaus. Coming down, a range stands
on the horizon above the dune haze. You drop into a canyon and fly its floor, walls stepping up on
either side, at a speed the ground keeps up with: no blurred ground snapping into shape under you.
Where the canyon widens there's a patch of green: palms round a spring pool, nobody there, a few
old walls half in the sand. You land beside it, walk to the pool, then fly on down the canyon
until it opens onto a beach. You skim the water, set down on the sand and wade in to your chest.
Wadoo is where it always was, now with mountains on its skyline.

## 3. Goals, non-goals, anti-goals

**Goals**
- **A seeded plan for every desert world:** a few dials, rolled from the seed or pinned by a
  design file, that decide how much sea, mountain, plateau and canyon a world has and how many
  oases. The same machinery can later take other kinds of world.
- **WADIS reshaped:** one big inland sea, mountain ranges, canyons that run down to the sea,
  plateau country, and dunes and plains for most of it. Still mostly desert.
- **The sea:** seen from orbit, flown low over, waded into from its shores. Shores of three kinds:
  beaches, cliffs and flat ledges.
- **Wild oases:** a handful the generator places, with a pool, palms, green, and sometimes ruins.
- **Sites:** each world's plan lists where things could go (oases, shore ledges) for settlements
  later, hand-made or generated.
- **Smoother, cheaper streaming:** plain shapes far away, detail only near the ground, no pops,
  and a stricter speed limit near the ground so the detail keeps up.

**Non-goals (later, each its own design)**
- Boats, floating, swimming, diving, an underwater look.
- Settlements and towns, hand-made or generated, on the sites.
- Reshaping any world that isn't a desert. Rock worlds keep their look until a later pass.
- Rivers of running water, waves, tides, weather.
- The beast.
- Ground that changes over time.

**Anti-goals (a failure even if it works)**
- **It still reads as flat.** From 300 m up over most of WADIS, something should stand on the
  horizon besides dunes: a range, a plateau's edge, a canyon or the sea.
- **It stops being a desert.** Water and green together stay well under a quarter of the world.
- **Wadoo moves or changes.** Its ground, its pieces and its people stay exactly as they are.
- **It drifts from the house style** (`docs/design/visual-style.md`). Realistic landforms, but
  the surfaces stay chunky, faceted and flat-coloured. No shimmering photographic water, no foam
  particles, no textures.
- **It costs frame rate.** Every view holds 80 fps at 1280 × 720 on the GTX 960.
- **A world strands you.** No ship stuck in or under water, no avatar stuck in deep water.
- **Other worlds change.** Every world that isn't a desert keeps its ground to the bit.

## 4. Decisions

*Owner* means decided by the owner on 2026-11-19. *Shown* means proposed to the owner in the
conversation and not corrected. *My call* means a default not yet put to the owner; §15 lists
those.

| Decision | Choice | Whose |
|---|---|---|
| Which worlds change | **Desert worlds only, WADIS first and checked** | Owner |
| How the land is built | **A region map of the whole world** (§13) | Owner |
| Oases | **Wild ones now, no people.** Settlements, maybe generated, later | Owner |
| The sea now | **Seen, flown over, waded into. No boats, no swimming, no landing on it** | Shown |
| Sites for later towns | **The plan lists them; nothing is built on them** | Shown |
| World controls | **A few dials per world, from the seed, pinnable in its design file** | Shown |
| One design in phases | **Land, then streaming and speed, then the sea, then the oases** (§12) | Shown |
| Speed limit with assist off | **Thick air holds you near the limit, even with the assist off** | Shown |
| Easing detail in | **One ground shader, only to ease detail in; it otherwise draws what today's ground does** (§8.2) | Owner |
| Wadoo | **Its ground is today's to the bit, inside a kept disc** | My call |
| WADIS's dials | **§5.3's numbers** | My call |
| Deep water on foot | **You tread water at chest depth, slowly; no diving** | My call |
| The sea's water | **Opaque, faceted, flat colour by depth** | My call |
| Where the stricter limit applies | **Every world (it is about streaming); the air hold only in air** | My call |
| Where the streaming changes apply | **Every world; none of them reshapes a world** (§8) | My call |
| WADIS's layout | **The sea in view on arrival, a canyon ending on a beach, a range on Wadoo's skyline** (§5.3) | My call |

## 5. The world plan

### 5.1 What it is

`WorldPlan` (new) is what a seed decides about a desert world's land at the scale of the whole
world. It is built once per world from the recipe, deterministically (the same on every machine
and every thread), and is then read-only. It holds:

- **the dials** (§5.2), rolled or pinned;
- **a coarse region map:** for each cell of a coarse grid on each cube face, which kind of land it
  is (sea, dunes, plains, plateau country, mountains), how high its base lies, and the least and
  most height its ground can reach (for the streaming's bounds, §8.3);
- **shapes drawn on the map:** the sea's basin, each range's spine, each canyon's path with its
  width and floor profile;
- **sites** (§5.5) and **kept discs** (§5.6).

`WorldTerrain.height_at` reads the plan for the big shape and adds each kind's own detail close up
(§6). Stamps apply on top, as today.

**Built once, shared by all.** Today every chunk job makes its own `WorldTerrain`. The plan must
not be rebuilt per job: it hangs off the recipe (as `stamps` do), built before any desert height
is asked (the far mesh asks at system load), and every `WorldTerrain` on every thread reads the
same one. Its arrays are never written after it is built. `FastNoiseLite` stays per
`WorldTerrain`, as today, because it is not thread-safe.

**Cost.** Building WADIS's plan should take well under a second on the build machine and must not
hitch the game: on a worker at system load, or cached under `user://` keyed by seed and generator
version. The builder picks, within that.

### 5.2 The dials

Each desert world's plan has these dials, drawn from sub-seed `&"plan"` (each dial its own
sub-seed, as `WorldSeed` does for the recipe, so adding a dial later never reshuffles the rest):

| Dial | What it decides | Rolled range (starting point) |
|---|---|---|
| `sea` | share of the surface under the sea | 0 for a third of deserts, else 0.05–0.25 |
| `seas` | how many separate seas | 1–2 |
| `mountains` | share in mountain ranges | 0.03–0.15 |
| `ranges` | how many ranges | 1–5 |
| `plateaus` | share of plateau country | 0.10–0.30 |
| `canyons` | how many canyon systems | 0–6 |
| `peak` | tallest peak, m over the plains | 600–2,500, and at most 4% of the radius |
| `oases` | how many wild oases | 2–8 |

Dunes and plains fill the rest, and must keep at least half the world: a roll that leaves less
scales the other shares down. The ranges are a starting point, tuned from renders.

### 5.3 WADIS's dials

WADIS's design file (`data/systems/kesdra.json`, body `p3`) gains a `plan` key that pins its
dials. *My call, tuned at Checkpoint 1:*

- `sea` 0.15, `seas` 1: one inland sea, about 85 km across on a world 343 km round.
- `mountains` 0.10, `ranges` 3, `peak` 2,000 m.
- `plateaus` 0.20, `canyons` 4.
- `oases` 6.
- Dunes and plains: the remaining 0.55.

**Placement pins.** A design may also say *where* a feature goes relative to one of its places,
never its shape: the generator still grows the sea, bends the range and routes the canyon. WADIS
pins (*my call*), so §2's moment happens:
- **the sea's nearest shore 20–40 km from Wadoo**, outside the kept disc. A warp arrives about
  68 km over the oasis, where the horizon is some 110 km off, so the sea is in view on arrival;
- **a range within about 15 km of Wadoo**, on its skyline (§5.6).

Every world with a sea also gets, by the generator's own rule, **at least one canyon whose mouth
opens on a beach**.

`SystemDesign`'s validator learns the `plan` key, its dials and its pins (§10).

### 5.4 How the plan is made

The order below is the intent; the method in each step is the builder's.

1. **Dials:** rolled, then any pinned value replaces its roll.
2. **Sea basins:** each sea grown on the coarse grid from a seeded centre to its share, one
   connected body by construction, its outline broken up by noise so it has bays and headlands.
   Ground inside falls below sea level (shelves, then a deep floor). Ground outside every basin is
   kept above sea level, so there are no stray puddles.
3. **Ranges:** spines as smooth curves bent by noise, each a few tens of km long, kept off the
   sea and the kept discs. At least one range on a world with a sea runs to its coast, so some
   shore is cliff.
4. **Plateau country:** regions grown from seeded centres away from the sea, each plateau region
   with its own top height (100–400 m on WADIS), so they no longer all stand at 270 m.
5. **Dunes and plains** take the rest: dune seas in the lower ground, gravel plains between.
6. **Canyons:** each starts in plateau country or on a range's flank and runs downhill over the
   coarse map to the sea (or a dry basin on a world with none). Its floor never climbs toward its
   mouth. A canyon may branch once or twice.
7. **Sites and kept discs** (§5.5, §5.6).
8. **Bounds:** each cell's least and most height, including the detail §6 adds.

### 5.5 Sites

The plan lists places that suit something. Each site has a kind, a place on the world
(`UniversePoint`-safe: a direction), a radius, a heading and how level it is.

- **`oasis`:** low, fairly level ground that could hold water: where a canyon widens, at a
  range's foot, just inland of the sea, or in a hollow between dunes. Spaced several km apart.
  The `oases` dial says how many get a wild oasis (§9); the rest stay listed.
- **`shore`:** flat ledges by the sea, a few hundred metres along the shore, gently sloping to
  the water: where towns will want to be.
- **`kept`:** each kept disc (§5.6) is listed too, so nothing later builds on Wadoo.

Nothing is built on `shore` sites, or on `oasis` sites without an oasis, in this project. A later
settlement design, hand-made or generated, chooses from the list.

### 5.6 Kept discs: Wadoo stays

A design can keep a disc of a world as it is. WADIS's file keeps one round the oasis place
(`"keep": [{"place": "oasis", "radius": 2000, "blend": 1500}]`, *my call*):

- **Inside the radius the base ground is today's desert ground, to the bit** (today's
  `_desert_height`, kept as it is for this use). Wadoo's stamps, pieces, paths, tracks and
  people stand on exactly what they stand on now.
- **Over the blend** the old ground eases into the plan's.
- **Nothing the plan places** (sea, range, plateau, canyon, site) comes within radius + blend.
  A range stands on Wadoo's skyline, within about 15 km (pinned, §5.3).

The `wadoo` branch is building its stage 5 on today's ground. The kept disc means the two never
meet.

## 6. The land close up

Each kind adds its own detail on the plan's base. The house look holds (style guide §3): faceted,
flat-coloured, one colour a triangle, steep ground `rock` (`ROCK_SLOPE`).

- **Dunes:** today's dunes (`DUNE_*`), unchanged in shape, on the dune seas. The pole fade and the
  wind axis stay.
- **Plains:** gravel and sand flats with a gentle roll, `ground_low`; boulders and grass as today.
  Near the sea, pale salt pans (*my call*: a new `salt` key in the desert palette, if renders want
  it).
- **Plateau country:** today's mesas, terraces and towers, on the plan's plateau regions, each
  region at its own height.
- **Mountains:** sharp ridged peaks along the spine, falling to its flanks, with talus and alluvial
  fans at the foot (the boulder fields gather there, as `in_talus` does today).
- **Canyons:** cut into whatever they cross. Stepped walls (terraces, `rock` risers, `ground_high`
  ledges), a flat sandy floor 150–600 m wide that winds, 100–400 m deep where they cut plateaus.
  Every floor is wide enough to land the starter, so you can always be picked up.
- **The sea basin:** sand beaches where dunes and plains run down, cliffs where mountains or
  plateaus meet it, a shallow shelf, then a deep floor (to a few hundred metres under the water).
  Wet sand (`damp`) in a band along the waterline.
- **Wild oasis sites:** green and palms (§9).

**Seen from afar.** The far mesh (`BodyLook`) samples `height_at` and `colour_at` as today, so the
sea, ranges and canyons show from orbit. Ground under the sea shows as the sea's colour at sea
level.

**Heights and the relief.** A desert with a plan reports a relief that covers its deepest seabed
and highest peak, since today's streaming culls by relief. §8.3 replaces that pad with the plan's
own bounds, or a 2 km peak would keep far chunks from ever being culled.

## 7. The sea

### 7.1 What it is

- **Sea level:** one per world, from the plan. Ground under it is seabed.
- **The surface every flying thing knows** is the higher of the ground and the sea:
  `WorldTerrain.surface_at` (new). Altitude for the speed limit, the air, the gravity hold, the
  landing aid, the HUD and the streaming's split all measure to it. A ship 30 m over the water is
  30 m up, not 330.

### 7.2 How it is drawn

- **Water belongs to the chunks.** Each chunk with ground under sea level also draws its water: a
  faceted sheet at sea level over the same grid, in the same mesh or a second surface of it. So
  the water comes and goes with the ground's detail, joins `Universe.EXTERIOR_SPACE` with its
  chunk, and needs nothing of its own for the floating origin.
- **Opaque, flat colour by depth** (*my call*): shallow water a warm green-blue (the owner asked
  for the pool to be "more green-blue, not icy"), deepening to blue-teal over deep water. New keys
  in the desert palette (`sea_shallow`, `sea_deep`, and a pale band at the very edge if renders
  want it). Opaque means no overdraw, no sorting and no seeing the seabed: the shallow colour does
  that job. A little specular for the sun's glint is fine; no waves.
- **Deep water needs no detail.** A chunk wholly under deep water draws only its sheet, and the
  quadtree need not split it finely (§8.4).
- **Skirts** hide cracks in the sheet as they do in the ground.

### 7.3 Touching it

- **Hulls can't go under it.** The water is solid to hulls: their collision meets a water sheet
  where the solid chunks are under sea level, on a layer only hulls collide with. Hitting it hard
  counts like hitting the ground (`TERRAIN_CRASH_FROM`).
- **No landing on water.** The landing monitor never makes a hull `LANDED` on water, and the
  landing aid says so. With the assist on, the gravity hold keeps you hovering; with it off, the
  hull rests on the water and drifts to a stop.
- **No stepping out over deep water.** The airlock won't cycle out while the hull is over water
  deeper than wading depth, so no one is stranded beside a hatch they can't reach.
- **On foot:** in the shallows you wade, as at the pool (`Avatar.wade_depth`, `wade_factor`). In
  water deeper than chest height you tread water (*my call*): held at chest depth, moving at the
  slowest wading speed, no diving. You can always walk back out.
- **Items** stand on the seabed like any ground. One dropped in deep water is out of reach, so
  you can't drop items while treading water.
- **NPCs never go into water** deeper than their knees. Wadoo has none near it anyway.

## 8. Streaming and speed

**Every world** gets this section's changes (*my call*): they change how the ground is streamed and
how fast you may fly, never what a world's ground is. "Ground to the bit" (§3, §10) means
`height_at` and `colour_at` at full detail: what the finest chunks draw and what collision,
altitude and landing use. Coarse chunks may draw less detail than today (§8.2), on rock worlds too.
Tighter bounds (§8.3) need a plan, so they come to deserts only; rock worlds keep today's relief
pad, which their relief (at most 1,200 m) allows.

### 8.1 Measure first

A new probe, `test/probes/stream_probe.gd`, flies fixed routes on WADIS (over dunes, along a canyon,
over a range, along the coast, over the sea) at the limit, and with the assist off at full thrust.
It records, at 1280 × 720 on the GTX 960:
- frames per second;
- **detail lag:** how much of the ground within 500 m ahead is drawn coarser than the quadtree
  wants, and for how long;
- **pops:** chunks swapped in view within 300 m without easing (§8.2).

It runs on today's main before any change, so the gains are measured, not guessed.

**The pass line** (*my call*, starting point, shown to the owner at Checkpoint 2): along the way
ahead, within 500 m, ground drawn more than one level coarser than the quadtree wants in no more
than 2% of the probe's samples, never for longer than 0.5 s at a time, and no pop within 300 m
(§8.2).

### 8.2 Plain far, detailed near

- **Detail by level.** A chunk asks only for the detail its quads can show: the plan's shape and
  the big landforms on coarse chunks, the dune ripples and small roughness only on fine ones.
  Coarse chunks are then what their children average to, so a swap barely moves the ground, and
  they are cheaper to build. Collision, the analytic floor and altitude still use full detail.
- **Ease in.** When finer chunks replace a coarser one, their points ease from the coarser shape
  to their own (over a fraction of a second, or across a distance band), so nothing pops.
  **The owner allowed one ground shader for this (2026-11-20),** an exception to style guide
  §3.9's "no exterior shader". Its whole job is easing: each chunk carries its parent's shape
  alongside its own, and the vertex stage blends from one to the other. Everything else (flat
  colour per triangle, the light, the haze, the shadows) draws exactly what the ground's
  `StandardMaterial3D` draws today; a render beside today's must not tell them apart once the
  ease has finished. It is the only exterior shader; any other still needs the owner. Style
  guide §3.9 and §2.5, and a check in `test_visual_style_rules.gd` that pins it as the only one,
  change in the same branch.

### 8.3 Tighter bounds

Today a node is culled by its corner chord plus half the world's relief. With 2 km peaks that pad
would cull almost nothing. Nodes take their least and most height from the plan's cells instead,
so the horizon culls as it should and splits stay honest.

### 8.4 Fewer, smarter builds

- **Over deep water**, chunks split only as far as the shore needs.
- **Ask ahead.** Requests rank by where you will be (along your velocity) as well as where you
  are, so the ground ahead is built first.
- Anything else the probe shows (build cost in GDScript, the apply budget) is the builder's.

### 8.5 The stricter limit near the ground

- **On every world** (*my call*: streaming is the same everywhere), the limit falls near the
  surface. *Starting point:* 70 m/s up to 50 m over the surface (ground or sea), rising to today's
  curve by 1,000 m; today's curve unchanged above that. The final numbers are the fastest limit
  that still meets §8.1's pass line on the GTX 960 after this section's other work, shown to the
  owner at Checkpoint 2.
- **Ships flown by the AI** fly under the same limit (it is worked out from the focus), so low
  fights near airless worlds slow down too. Hostiles stay above the air on worlds with air (the
  desert world spec §4), and rocks have no well, so the limit never touches them.
- **In air, the assist off too:** past the limit the air's drag climbs steeply, so a hull at
  full thrust settles about at the limit. The game-world reason is the thick air. On airless
  worlds the assist off stays unlimited, as today.
- **Entry heat** keeps reading from the limit, so the glow comes on as you push it.
- The HUD's speed readout and limit tell you when the limit tightens, as it shows when it rises
  today.

## 9. Wild oases

- **Where:** on the plan's `oasis` sites, as many as the `oases` dial says (6 on WADIS), best
  sites first.
- **What:** each is generated from its site's own sub-seed, the same every visit:
  - stamps like Wadoo's, minus the town: a floor that keeps some of the land's roll, a spring
    pool (a basin, 8–25 m across) with its `PoolWater`;
  - a green ring and grass thicker near the water;
  - palms in clusters (`OasisLooks`' palms), some reeds by the water if renders want them;
  - in about one oasis in three, a few old walls half buried in the sand (`OasisLooks`' brick
    pieces);
  - no beacon. You find them by eye: they show green from the air at 2 km, and the far mesh
    colours their ground.
- **How they load:** as generated places beside the designed ones (`PlaceField`), built near the
  focus and freed far away, each a member of `Universe.EXTERIOR_SPACE` with its pieces as
  children, as the oasis place is today.
- **Colours** from `OasisPalette`, as Wadoo's outside.

## 10. Keeping everything else the same

- **Non-desert worlds** keep their ground to the bit (§8: `height_at` and `colour_at` at full
  detail). A test pins sample heights and colours for a handful of seeds of each archetype.
- **Desert worlds change:** `WorldRecipe.GENERATOR_VERSION` goes to 4, with a save note. A ship
  saved landed on a desert is restored onto the new surface by the existing safe restore; a probe
  proves it, including one restored over what is now sea.
- **Wadoo:** heights inside its kept disc are today's to the bit (a test), and its probes
  (`oasis_render`, `wadoo_play`) still pass.
- **The design file:** `SystemDesign` reads `plan` (the dials and `keep`), and its validator
  checks the keys, the ranges, and that a kept disc's place exists.

## 11. Verification and budgets

- **Render the real scene and show the owner** (CLAUDE.md, style guide §6) at each checkpoint:
  WADIS from orbit, at 10 km, 2 km over a range and over the sea, 300 m along a canyon; at eye
  height (1.6 m) on a canyon floor, at a range's foot, on a beach looking out, at a wild oasis,
  and from Wadoo's pad. With them, **a map of the plan** (each kind of land a colour, the sites
  marked), so the owner sees the whole world at once.
- **Frame rate:** at least 80 fps at 1280 × 720 on the GTX 960 in every view, including low
  flight at the limit along a canyon and over a range, and seated at a wild oasis. Record the
  numbers in style guide §2.6.
- **Tests,** targeted to the change, never the full suite unless the owner asks:
  - the same seed makes the same plan, on any thread;
  - pinned dials replace rolled ones; the validator over the data;
  - WADIS has exactly one connected sea, its share within the dial;
  - every canyon reaches a sea or a basin, and its floor never climbs toward its mouth;
  - peaks within the dial; dunes and plains at least half the world;
  - sites: oases on low, level, dry ground outside kept discs; shores by the water;
  - heights continuous across cube-face edges;
  - non-desert worlds unchanged; Wadoo's disc unchanged;
  - `surface_at` and altitude over the sea;
  - the new speed limit curve, and the air hold with the assist off;
  - wading and treading water; no step-out over deep water; no landing on water;
  - the style rules (`test_visual_style_rules.gd`) with the new palette keys, and the ground's
    easing shader as the only exterior shader;
  - `test_floating_origin_scene.gd` with sea chunks and a wild oasis loaded.
- **Probes:** the new `stream_probe`; `world_probe`, `desert_render`, `descent_render`,
  `landing_play`, `oasis_render` and `fleet_play` still pass.

## 12. Phases and checkpoints

Each phase ends with renders and numbers shown to the owner.

1. **The land.** The plan, the dials, the region map, the landforms, the kept disc, the far mesh,
   the tighter bounds. The sea basin is there but dry (its seabed drawn, no water yet).
   *Checkpoint 1:* the renders and the plan's map.
2. **Streaming and speed.** The probe (first run on today's main), detail by level, easing in,
   asking ahead, the stricter limit and the air hold. *Checkpoint 2:* before and after numbers,
   and a low flight down a canyon.
3. **The sea.** Sea level, `surface_at`, the water sheet, shores, colours, hulls and water, wading
   and treading, deep-water chunks. *Checkpoint 3:* the shore and sea renders.
4. **Wild oases.** Sites to places, pools, palms, green, ruins. *Checkpoint 4:* oasis renders.
5. **Docs and skills** (§14).

## 13. Approaches

Three ways to build the land were weighed; the owner picked the first.

- **A region map of the whole world (picked).** A coarse map with shapes drawn on it, built once
  per world. It can promise one sea, ranges in lines, and canyons that drain to the sea; sites are
  known up front; Wadoo's disc can be kept; and far ground reads only the smooth map, which is
  exactly "plain far, detailed near". The cost is more new code and a one-off build at load that
  must be identical on every machine.
- **More noise layers on today's generator.** The smallest change, with nothing to build. But
  noise can't promise one sea (five puddles or none), canyons start and stop nowhere, sites must be
  searched for, and each layer adds cost to every height sample, already the streaming's busiest
  code.
- **Simulated erosion on the map.** The most natural land, but slow to build, hard to keep the
  same on every machine, hard to steer round Wadoo, and it fights the chunky style.

Shaping the big features by hand on WADIS was ruled out: it wouldn't carry to other worlds.

## 14. Docs and skills to update in the same branch

- **Style guide:** the new landforms and the sea in the world sections, the new palette keys
  (guide, code and `test_visual_style_rules.gd` together), and §2.6's new numbers. §3.9 and §2.5
  name the ground's easing shader as the one exterior shader (§8.2), with the test that pins it.
- **The desert world spec:** a pointer here from §7.2 and §13 (the sea now exists, smaller than
  the ocean world).
- **`building-a-ship`:** the new limit curve and air hold in `reference.md`; no landing on water
  and no step-out over deep water in the checklist; a `ship_probe.gd` line if one is checkable.
- **`building-an-npc`:** NPCs on worlds keep out of deep water; the sea in `reference.md`.
- **CLAUDE.md:** only if a palette is added (the sea's keys go in the existing desert palette, so
  probably not).

## 15. Left to the builder

- The map's resolution and how each step of §5.4 is done, within the plan's promises and the
  build-time budget.
- The noise and numbers of each landform's detail, tuned from renders.
- How detail by level and easing in are done, within §8's promises.
- Where the water sheet lives in the mesh, and its collision layer.
- Key and class names beyond those this document fixes (`WorldPlan`, `surface_at`, the `plan`
  key, the `stream_probe`).

**My calls, for the owner to check while reading:**
1. Wadoo's kept disc: 2 km, with a 1.5 km blend, its ground today's to the bit; a range on its
   skyline if the plan can.
2. WADIS's dials (§5.3): one sea at 15%, three ranges to 2 km, 20% plateaus, four canyons,
   six oases.
3. Treading water in deep water rather than being blocked at the shore.
4. Opaque water coloured by depth.
5. The stricter limit on every world, starting at 70 m/s under 50 m. It slows the AI's low
   fights near airless worlds too.
6. No stepping out over deep water; no items dropped while treading water.
7. Salt pans near the sea, if renders want them.
8. The streaming changes on every world, with coarse chunks drawing less detail than today.
9. WADIS's placement pins: the sea's near shore 20–40 km from Wadoo, a range on its skyline, and
   a canyon ending on a beach on every world with a sea.
10. §8.1's pass line for the ground keeping up.
