# World scale — planets big enough to be places

**Date:** 2026-09-30
**Status:** Designed with the owner on 2026-09-30, section by section. **Built** on branch
`world-scale` (2026-09-30 to 2026-10-01); §13 is what was built, where it differs from this text
(amended in place, each marked *as built*) and what is left. The owner's approval of the look is
pending (§13.7).
**Depends on:** `main` at `a59890a` (the system skeleton, the warp, the ship exterior, health and
damage)
**Amends:** the star systems design §2, §4.1, §4.3, §6; the system skeleton spec's proxies (§7); the
warp spec §2, §3.1, §3.2, §5.3, §6, §7.1; Planetfall §3, §5.2, §6.4, §7.1, §14 (see §9)
**Governed by:** `docs/design/visual-style.md`

---

## 1. Why

The owner, after flying the system at toy scale:

> To me even the large planets are on the small side, I can fly around them in a matter of seconds
> and they have obvious curvature even sitting on one. The intent is for planets to be a whole new
> world/environment you can fly in to and do various things. Obviously not scale real planet size
> but big enough to feel immersive. We may need to carefully manage how we render something like
> that though to not overload the game. We also need to consider expanding the space between things
> if we are making them larger, but that should be ok now that we can warp jump.

What was measured at toy scale (`WorldRecipe.RADIUS`, planets 300–1,200 m):

| | The largest planet today |
|---|---|
| Horizon, standing (1.6 m) | about 60 m |
| A lap at 120 m/s | about 63 s |
| Facets on the shell you land on | 5,120, each about 50 m across |

### 1.1 The pitch

You drop out of warp 14 km above KORVA-7's well. Debris tumbles past for two minutes; below it the
world fills the canopy, a 96 km disc with a range of mountains across its day side. You cross into
its well, and as you sink the HUD's limit climbs to *LIMIT 1,500*. You dive. Mountains grow out of
the patches you saw from orbit, the limit falls as the ground comes up, and a minute and a half
later you are skimming a valley a few hundred metres up, with its ridges above you on both sides
and the horizon kilometres away. Its moon
hangs in the sky, four times the width of ours.

---

## 2. Decisions

| Question | Choice | Why |
|---|---|---|
| How big | **Large planets 30–60 km in radius**; all planets 15–60 km, moons 4–15 km, the star 200–300 km (§3) | Horizon about 400 m on foot, 3–5 km from 100 m up: the ground looks flat until you climb. A lap is 25–50 minutes at 120 m/s. Roughly KSP's Minmus. Big enough for regions and long flights, small enough to cross in one sitting. |
| Where this piece stops | **Scale, spacing and the world renderer** (§4, §5). Gravity, landing, the airlock step-out, walking and sites stay in Planetfall, amended to the new scale (§9) | A 60 km world cannot be a 5,120-face shell: each facet would be 3 km across. The renderer has to come forward; the rest of Planetfall builds on top of it. |
| Getting around a big world | **The speed limit rises with altitude** inside a well (§6) | Climb, dash, descend: the far side is minutes away and the world still feels huge low down. It also bounds how fast terrain detail must stream. |
| How to draw it | **One quadtree surface per body, at true scale when near, with the far plane raised to 700 km** (§5; *as built*, 400 km was too short for the star, §13.1) | Godot 4.5's Forward+ uses reversed depth, so a long far plane costs no precision. No new shader, no second scene, and one surface from across the system to the ground. |
| Moons at the new spacing | **Moons become warp targets** (§3.3) | A moon 180–400 km from its planet is a 25–55 minute flight. |
| Warp trips | **Retuned so they take and cost what they do now** (§3.4) | The warp's feel and QE progression were agreed on 2026-09-28; only the distances change. |

Rejected for rendering:

- **Squashing distance in a vertex shader** to keep the 30 km far plane: a custom shader on every
  world material, shadows and collision disagreeing with what is drawn, and it solves a problem
  reversed depth has already removed.
- **A second scaled-space scene** (KSP's way): another full pass, when the canopy already draws the
  outside twice, and a hand-over between the two scenes to hide. The most expensive option on the
  GTX 960.

---

## 3. Sizes and spacing

### 3.1 Bodies

| Body | Today | Now | Where |
|---|---|---|---|
| Planet radius | 0.3–1.2 km | **15–60 km** | `WorldRecipe.RADIUS[PLANET]` |
| Moon radius | 0.12–0.4 km | **4–15 km** | `WorldRecipe.RADIUS[MOON]` |
| Star radius | 2.5–4 km | **200–300 km** | `SystemRecipe.STAR_RADIUS` |
| Terrain relief | 2–6% of radius, at most 72 m | **1–2.5% of radius, at most 1,200 m** | `WorldRecipe.RELIEF`, `RELIEF_MAX` |
| Gravity well | 3 radii | **2 radii**: its edge is 15–60 km above a planet's ground | `WorldRecipe.WELL_RADII` |
| Surface gravity | 2–8 m/s² (moons 1–4) | unchanged | |

- **Size classes** on the map: small under 30 km, medium 30–45 km, large 45 km and over
  (`MapPage.LARGE`, `MEDIUM`). The screen reads *KORVA-7 · PLANET · LARGE · 96 KM ACROSS*.
- A 10 km moon 250 km away is 4.6° across in its planet's sky, nine times our Moon. A large planet
  seen from its moon is about 27° across.
- The star's well is 2 radii too (400–600 km). What happens close to the star still waits for a
  decision (star systems design §13).

### 3.2 Spacing

| Distance | Today | Now | Where |
|---|---|---|---|
| Warp limit | well + 14 km | **unchanged**: well + 14 km | `SystemRecipe.WARP_CLEAR` |
| Moon from its planet's centre | 6–14 km | **180–400 km**, and always outside the planet's limit (§3.3) | `MOON_NEAR`, `MOON_FAR` |
| First slot from the star | about 30 km | **about 1,500 km** | `FIRST_SLOT` |
| Slot ratio | ×1.18–1.30 | unchanged | `SLOT_RATIO` |
| Outermost slot | 150 km or less | **7,500 km or less** | `LAST_SLOT` |
| The system across | about 300 km | **about 15,000 km** | |
| Room past a well | planet 2 km, moon 0.5 km, star 4 km | **planet 20 km, moon 5 km, star 40 km** | `PLANET_ROOM`, `MOON_ROOM`, `STAR_ROOM` |
| Clearance between shapes | 1 km | **5 km** | `CLEAR` |

- From a neighbour 1,000 km away, a large planet is a 7° disc: the sky stays full of places.
- **Drop-out to touchdown takes about 3–4 minutes:** 2 minutes through the debris to the well's
  edge at 120 m/s, as now, then 1–1.5 minutes down at the altitude limit (§6).
- `SystemRecipe.problems()` keeps every rule it has, at the new sizes, and gains §3.3's.

### 3.3 Moons as warp targets

- Every moon is a `WarpTarget` of kind `MOON`, with its own limit: its well + 14 km.
- **A moon lies wholly outside its planet's limit:** its distance from the planet's centre is at
  least the planet's limit plus the moon's limit plus `CLEAR`. `problems()` checks it.
- A planet's neighbourhood still holds its moons. A planet's limit is its well plus `WARP_CLEAR`,
  and at least its ring's outer edge plus `CLEAR`, but no longer at least its neighbourhood (the
  warp spec §3.2): the limit would otherwise swallow the moons it is meant to lead to. Moons, not
  the planet's limit, hold the neighbourhood's far reaches.
- **Moon limits block a warp's line** like a planet's (the warp spec §4.2): you warp to the moon
  first, or fly clear.
- A planet-to-moon warp is a short hop: up to about 330 km of travel, about 20 s (§3.4). A moon
  whose limit lies within `WarpPlan.MIN_TRAVEL` of its planet's is flown to, as neighbours are
  today.
- On the map's SYSTEM range moons are selectable targets after their planet in ◀ ▶ order. Their
  contacts keep kind `&"moon"`; the map's target kinds and `BodyMarker` gain it.

### 3.4 The warp, retuned

| | Today | Now | Where |
|---|---|---|---|
| Travel time | 18 s + 1 s per 5 km | **18 s + 1 s per 350 km** | `WarpProfile.PACE` |
| Cost | 40 QE + 4 QE per km | **40 QE + 1 QE per 12.5 km** (0.08 QE per km) | `WarpPlan.WARP_M_PER_QE`, replacing `WARP_PER_KM` |
| Too close to warp | target's limit under 5 km away | unchanged | `WarpPlan.MIN_TRAVEL` |

- Distances between centres grow about 50 times, but limits only about 8 times, so the median
  trip's travel grows to about 4,600 km. At 1 s per 350 km that is about 31 s, as today (1 s per
  250 km would make it 37 s). It costs about 410 QE; across the system (12,500 km) takes about
  54 s and 1,040 QE. The starter's 600 QE reaches about 7,000 km, about half the system, as today.
- The cost is written as metres per QE so it stays exact: 0.08 is not exact in floating point,
  and `ceili` of 240.00000000000003 is 241.
- `test_warp_profile.gd`'s 200-seed average (25–35 s) is the check; if it misses, `PACE` is tuned,
  not the test.
- Peak warp speed rises to around 200 km/s. The floating origin then shifts every physics tick
  (every 3 km or so). Rocks are already suspended during a warp and proxies are placed every tick
  anyway, so it should hold; the live checks measure it (§8.3).
- The spool (10 s), the alignment rules and the drop-out at 120 m/s are unchanged.

### 3.5 Belts, rings and debris

Rocks keep their sizes and densities; the shapes that hold them grow so they read at the new scale.

| Shape | Today | Now | Where |
|---|---|---|---|
| Belt half-width | 4–7 km | **20–40 km** | `SystemRecipe.BELT_HALF_WIDTH`, `BELT_MIN_HALF_WIDTH` 15 km |
| Belt half-thickness | 1.5–2 km | **unchanged:** a belt must lie inside one 5 km layer of giant cells (`SystemRecipe.PLANE_Y`) | `BELT_HALF_THICKNESS` |
| Belt gap between slots | 12 km | **300 km** | `BELT_GAP` |
| Ring inner edge | 1.6–2.0 radii | unchanged, so rings may lie inside a well as before | `RING_INNER` |
| Ring width | 1–2.5 km | **10–30 km** | `RING_WIDTH` |
| Ring half-thickness | 40 m | **100 m** | `RING_HALF_THICKNESS` |
| Rings on planets of at least | 600 m radius | **30 km** | `RING_MIN_RADIUS` |
| Debris disc | from the well to 1 km inside the limit | unchanged | `DEBRIS_*` |
| Clusters | 4 km reach, 18 km limit | unchanged | `CLUSTER_RADIUS` |

- The start is unchanged: 700 m off the first belt's first group, inside its first cluster.
- `BeltLook` and `RingLook` slabs are resized from renders so a belt still reads as a band from a
  neighbouring planet (`SLAB_ACROSS`, `SLAB_THICK`, the fades).
- The map's nearer ranges become **2, 10, 50 and 500 km**, so a planet and its moons fit one range;
  the SYSTEM range covers **9,000 km** from the star, with scale rings every **2,500 km**
  (`MapPage.RANGES`, `SYSTEM_REACH`, `SCALE_RING`).

### 3.6 Versions

`WorldRecipe.GENERATOR_VERSION`, `SystemRecipe.VERSION` and `AsteroidRecipe.VERSION` each go up by
one. A save from before starts over (saving spec §8.1), as with the skeleton and the warp.

---

## 4. One source of truth for the ground

`WorldTerrain` (new, pure, one per thread) is built from a `WorldRecipe` and answers:

```gdscript
func height_at(dir: Vector3) -> float        # metres above radius_m; may be negative
func colour_at(dir: Vector3) -> Color        # the palette colour of the ground facing dir
func altitude_of(local: Vector3) -> float    # body-local point's height above the ground
```

- **Everything reads it,** never each other: the far mesh, the quadtree chunks, collision, the
  analytic floor (§5.5) and the altitude speed limit (§6). This is Planetfall §4's rule, brought
  forward.
- **Shape:** Planetfall §6.2's archetypes (`ROLLING`, `RIDGED`, `MESA`, `CRATERED`), with noise
  sampled at `dir * radius_m` so the sphere is seamless. At the new sizes each archetype gains one
  low-frequency layer for continents and basins, so a world has regions a few thousand km² across,
  not one texture repeated.
- **Colour:** the patterns `BodyLook._Pattern` paints today (patches, bands, plateaus, craters) move
  here and become terrain: a crater you see from 1,000 km away is a real crater when you arrive.
  `colour_at` picks a palette ground by height band and slope (`rock` on steep faces) and a shade
  from `SpacePalette.SHADES` in broad patches, exactly as today.
- **The look stays inside the style guide:** flat-shaded, one colour per triangle, broad patches,
  no noise on the surface itself, colours only from `SpacePalette`. The material is the existing
  vertex-colour `BodyLook.material()`: **no new shader.**
- Noise uses `FastNoiseLite` seeded from `WorldSeed.sub(seed, &"terrain")` and friends, per
  Planetfall §5.1. Each worker thread builds its own `WorldTerrain`.

---

## 5. The world renderer

### 5.1 Three ranges, one surface

| Where the focus is | What is drawn | Cost |
|---|---|---|
| Beyond `SURFACE_AT` (10 radii, or 300 km if less) from a body's centre | **The far mesh:** one icosphere of 1,280 faces, heights and colours sampled once from `WorldTerrain`. Beyond `PROXY_AT` it is shrunk onto the proxy shell, as today | 1 draw call per body |
| Inside `SURFACE_AT` | **The quadtree surface** (§5.2) at the body's true place | Budget: 150 chunks in view |
| Within 160 m of a terrain anchor | The finest chunks also become **collision** (§5.5) | A few dozen shapes |

- **The far mesh hands over to the quadtree** at `SURFACE_AT`, where a world is about 11°
  across and the two differ by a pixel or two at 1280 × 720. The quadtree's first frame is its six coarsest
  chunks, built synchronously when it is made. A fade over `FADE_MARGIN` by visibility ranges
  covers any residue, as the proxies do today.
- Moons are 180 km or more from their planet, so normally one quadtree is live. Two may be, briefly,
  near a moon.
- `BodyProxy` keeps its place and scale rules (the skeleton spec §7), owns the far mesh and, inside
  `SURFACE_AT`, a `WorldSurface`. Its faceted "near" shell and convex collider go.
- **The star** stays a far mesh at every distance, unshaded, as today.

### 5.2 The quadtree

- **Cube-sphere** (Planetfall §6.4): six faces, spherified-cube mapping, each face a quadtree of
  nodes `(face, depth, ix, iy)`. Every node's chunk is **16 × 16 quads** plus a skirt.
- **Depth per body:** the smallest `D` with a leaf quad of 2 m or less,
  `D = ceil(log2(π·R / (2 · 16 · 2.0)))`: 12 for a 60 km planet, 10 at 15 km, 8 for a 4 km moon.
- **Split** a node when the focus is within 1.5× its edge of it; merge beyond 1.8×. *As built,
  the distance is measured to the node's real ground point (its centre direction at the radius
  plus the height there) less the node's corner chord, with no relief padding; the relief-padded
  bound is for horizon culling only (§13.2).* Each level costs about the same number of chunks,
  about 21 at 1.5× (about 58 at Planetfall's 2.5×, which over 12 levels is about 700 chunks
  built). At 1.5× a quad is about 2.4° across at the split distance: chunky, which is the style.
  *As built, a 60 km world is about 450 chunks built at ground level, not 250, and about a
  quarter of them in view (§13.3).*
- **Horizon culling:** a node wholly below the focus's horizon (its bounding sphere, lifted by the
  world's relief, behind the sphere of radius `R − relief`) is neither built nor drawn. Low down,
  that removes most of the coarse ones.
- **Detail follows the focus** (the hull, or the avatar on a spacewalk), not a camera. The canopy's
  second view draws the same chunks.
- **Skirts** hide cracks between levels; no geomorphing. Popping is accepted, and the flat-shaded
  look hides most of it (Planetfall §6.4).
- The cameras' far plane goes from 30 km to **700 km** (`BodyProxy.VIEW_FAR`, which
  `flight_test.gd` and every probe that sets it read; *as built*, not the 400 km first written, §13.1).
  `BodyProxy.PROXY_AT` goes from 28 km to **350 km**. Rocks keep their own 25 km fade; sun
  shadows keep their 2 km reach.

### 5.3 Streaming

- `TerrainChunkData` (pure) builds one chunk's packed arrays (positions, normals, colours, collision
  faces) in `WorkerThreadPool` tasks, each with its own `WorldTerrain`.
- The main thread turns finished data into meshes and nodes within **2 ms a frame**, the budget the
  asteroids use (`AsteroidStream.APPLY_BUDGET_USEC`). A generation counter drops results superseded
  while they were building. Nearest-first, by the split rule's distance.
- **The altitude speed limit (§6) is what keeps this from falling behind.** Speed is tied to height,
  so the detail you need changes at a bounded rate however fast you fly: halving your altitude
  takes at least about 28 s at full speed, and crossing a chunk sideways takes about as long at
  every level.
- A body's chunks are freed when it leaves `SURFACE_AT` plus a hysteresis.

### 5.4 Precision and the floating origin

- **A chunk's vertices are relative to the chunk's own centre,** computed in 64-bit GDScript floats
  and stored in 32-bit. No mesh ever holds a 60 km offset in a 32-bit float, so the far side of a
  world never shimmers.
- **Each chunk is its own member of `Universe.EXTERIOR_SPACE`,** under a holder that never moves
  (CLAUDE.md), placed from its centre's `UniversePoint` when made. A shift moves it with everything
  else: a few hundred nodes every 2 km, which is cheap. `test_floating_origin_scene.gd` must see
  every chunk and collision body covered.

### 5.5 Solid ground

- `TerrainCollider` keeps a collision chunk (a `StaticBody3D` on layer 4 `terrain`, mask 0, with a
  `ConcavePolygonShape3D` from the same `TerrainChunkData`) for every finest chunk within
  `64 m + 1 s × speed` of each terrain anchor, capped at 160 m (*as built*, 113 to 380 keys
  an anchor at full reach, cached per anchor, and the chunk under an anchor is built at once, §13.4).
  The hull is an anchor (`AsteroidStream.SPACE_ANCHOR`); the avatar becomes one on a spacewalk. This is Planetfall §6.5, less boulders, which stay Planetfall's.
- **The analytic floor:** if the hull's lowest point is ever more than 0.5 m below
  `WorldTerrain`'s ground, it is lifted out along local up, its inward velocity is removed, and a
  warning is logged (Planetfall §8.5). It should never fire; the descent probe counts it.
- Until Planetfall lands there is **no gravity and no landing:** you can fly down, skim the ground
  and bump off it, as you bump off today's shells.

### 5.6 Budgets (GTX 960, 1280 × 720, canopy drawing the outside twice)

| What | Budget |
|---|---|
| Worst frame, descending and skimming | 33 ms |
| Chunks drawn in view | 150 or fewer (*as built*: this is the binding budget, not chunks built, §13.3) |
| A chunk's build on a worker | 10 ms or less |
| Applying chunks on the main thread | 2 ms a frame |
| The analytic floor firing | never |

If draw calls are the problem, the levers in order are: 32 × 32-quad chunks (a quarter as many), then
merging a face's distant chunks into one mesh. If chunk builds are, Planetfall §6.6's fallbacks
apply: smaller chunks, then a C# port of `WorldTerrain` and `TerrainChunkData`.

---

## 6. The altitude speed limit

Inside a well, with the assist on:

- **The limit is 120 m/s plus 1 m/s for every 40 m of altitude, capped at 1,500 m/s.** At full
  speed you are always about 40 s or more from the ground.
- **It eases back to 120 m/s over the top tenth of the well,** so you leave into the debris at the
  speed the rocks outside stream for, and are never clamped hard at the edge. (Over the top fifth,
  the largest world's limit would peak at 1,320 m/s and the cap would never be reached; over the
  top tenth it peaks at about 1,470.)
- **Boost is unchanged:** it multiplies thrust, so you reach the limit sooner, and it never raises
  the limit (with the assist on, `FlightComputer` clamps speed to the limit today as well).
- **Altitude** is `WorldTerrain.altitude_of` for the body whose well you are in, from
  `Whereabouts` (§7). Outside every well the limit is today's 120 m/s.
- With the assist off there is no limit, as today.
- `FlightComputer.CRUISE_LIMIT_MPS` becomes the floor of the rule, and the speed lock is clamped to
  the current limit. The limit goes into `VehicleTelemetry`, and the velocity panel shows
  *LIMIT 1,500* whenever it is above 120.

| From a well's edge | Large planet (60 km up) | Small planet (15 km up) |
|---|---|---|
| Limit at the edge (before easing) | 1,500 m/s | 495 m/s |
| Down to 1 km at the limit | about 1.5 min | under 1 min |
| Halfway round, high up | about 4 min | about 3.5 min |

---

## 7. Whereabouts

- **Limits for moons** (`&"limit_p3.m1"`), entered and left like the others.
- **`well() -> SystemBody`:** the body whose well the focus is in, or null. Wells never overlap, so
  there is at most one.
- **`altitude() -> float`:** the focus's altitude over that body's ground, from `WorldTerrain`; `INF`
  outside every well. Read by the speed limit and, later, by Planetfall.
- It keeps its rule: anything that behaves differently by place asks `Whereabouts` (star systems
  design §3.1).

---

## 8. Testing

### 8.1 Pure, headless (GUT, output pristine)

- **`test_world_recipe.gd`:** every field in its new range across 1,000 seeds; relief never over
  1,200 m.
- **`test_system_recipe.gd`:** `problems()` empty over 500 seeds; every moon wholly outside its
  planet's limit; every planet's limit is its well plus `WARP_CLEAR` and holds its ring; moons are warp targets;
  `describe()` lists them.
- **`test_world_terrain.gd`** (new): `height_at` deterministic and within relief; `altitude_of`
  agrees with `height_at`; `colour_at` only returns palette colours.
- **`test_cube_sphere.gd`** (new): the mapping round-trips; depth per radius matches §5.2; the
  leaves of any split cover each face exactly once.
- **`test_terrain_chunks.gd`** (new): shared edge vertices of same-depth neighbours match, across
  cube-face edges too; skirts present; no NaNs; collision faces equal render faces at the finest
  depth; vertices are chunk-relative and small.
- **`test_world_surface.gd`** (new): the split and merge rule with hysteresis; horizon culling hides
  the far side; the node count at 1 km, 10 km and 100 km altitude stays within budget.
- **`test_speed_limit.gd`** (new): the limit on the ground, mid-well, in the easing band and outside;
  boost below and above 300 m/s; no limit with the assist off.
- **`test_warp_profile.gd`, `test_warp_plan.gd`:** the duration and cost tables of §3.4; blocking by
  a moon's limit.
- **Map page tests:** the new ranges and classes; moons selectable.
- **`test_visual_style_rules.gd`:** `world_terrain.gd`, `terrain_chunk_data.gd` and
  `world_surface.gd` join its painting list.

### 8.2 Scene tests

- **`test_floating_origin_scene.gd`:** passes with a live quadtree, and during a warp at the new
  speeds; every chunk and collision body is covered.
- **`test_warp_scene.gd`:** a warp to a large planet and to its moon arrives at their limits.
- A headless flight from a limit to the ground, stepping the assist, never falls through and never
  fires the floor.

### 8.3 Live checks and renders

A scripted **descent probe** in the real flight scene warps to a large planet, flies from its limit
to the ground at the speed limit, and skims 20 km. It logs the worst frame, chunks in view, draw
calls with the canopy on, chunk build times, the origin's shifts during the warp, and any firing of
the floor, against §5.6.

**Renders for the owner** (CLAUDE.md: the real scene, at eye height where it applies):

- a large world from a neighbouring planet;
- from its warp limit, and from its well's edge;
- from 1 km up, and skimming at 150 m;
- standing height (1.6 m) on its ground;
- a moon in its planet's sky;
- a belt from the neighbouring planet;
- the map's SYSTEM and 500 km ranges.

The style guide gains a *Worlds up close* rule only once the owner approves these (§13.7).

---

## 9. Other documents

Amended in the same branch:

- **Star systems design:** §2's *Scale* row becomes this spec's; §4.1 and §4.3's tables take §3's
  numbers; §6 notes the far plane, `PROXY_AT` and the quadtree surface.
- **System skeleton spec §7:** proxies own a far mesh and a `WorldSurface`; the near shell is gone.
- **Warp spec:** §2 and §3.1 (moons are targets), §3.2 (a planet's limit no longer holds its
  moons), §5.3 and §6 (pace and cost), §7.1 (ranges and classes).
- **Planetfall:** §3 and §5.2 (sizes and relief), §6 (terrain, cube-sphere, quadtree and collision
  are built here, at the new depths), §7.1 (the well at 2 radii), §14 (the test area is the
  system). What stays Planetfall's: gravity, the assisted descent, landing, the airlock step-out,
  walking, boulders, sites and the atmosphere.
- **The `building-a-ship` skill** (CLAUDE.md): the altitude speed limit in `reference.md` and its
  checklist; the warp's new pace and cost; a `ship_probe.gd` line for warp reach at the new cost.
- **The style guide:** *Worlds up close*, once approved (§8.3).

---

## 10. Build order

Each step ends flyable:

1. **The numbers:** `WorldRecipe`, `SystemRecipe` (sizes, spacing, moons as targets), belts and
   rings, the warp's pace and cost, `Whereabouts` moon limits, the map's ranges and classes, the far
   plane and `PROXY_AT`, the versions. Bodies are still shells, only huge. *Warp round a system at
   the new scale and judge the sizes and spacing.*
2. **`WorldTerrain` and the far mesh.** *Bodies look like their real surfaces from afar.*
3. **The quadtree:** `CubeSphere`, `TerrainChunkData`, `WorldSurface`, horizon culling, streaming.
   *Fly down to real terrain.*
4. **`TerrainCollider` and the analytic floor.** *Skim it and bump off it.*
5. **The altitude speed limit,** `Whereabouts.well()` and `altitude()`, the HUD line. *Climb, dash,
   descend.*
6. **The descent probe, renders and tuning,** then §9's documents and the skill.

Step 1 comes first on purpose: the sizes and spacing can be judged by flying before any terrain
exists, while they are cheap to change.

---

## 11. Where to tune

| What | Where |
|---|---|
| Body sizes | `WorldRecipe.RADIUS`, `SystemRecipe.STAR_RADIUS` |
| Mountains | `WorldRecipe.RELIEF`, `RELIEF_MAX` |
| Wells | `WorldRecipe.WELL_RADII` |
| Spacing | `SystemRecipe.FIRST_SLOT`, `SLOT_RATIO`, `LAST_SLOT`, `MOON_NEAR`, `MOON_FAR`, the `*_ROOM`s, `CLEAR` |
| Warp time and cost | `WarpProfile.PACE`, `WarpPlan.WARP_M_PER_QE` |
| When the surface takes over | `BodyProxy.SURFACE_AT`, `PROXY_AT`; the cameras' far plane |
| Detail and its cost | `WorldSurface` split and merge factors, chunk quads, finest quad size |
| The speed limit | its per-metre rate, cap and easing band |

Changing a recipe constant needs its version bumped (§3.6).

---

## 12. Non-goals

- Gravity, landing, the airlock step-out, walking, boulders, sites, atmosphere and fog: Planetfall.
- Real planetary scale, orbits or spin.
- Caves, overhangs, oceans.
- Hand-made worlds: the authoring piece (star systems design §12, step 5) works at whatever scale
  this sets.
- A new shader.

---

## 13. What was built

Built on branch `world-scale` (off `main` at `a59890a`), 2026-09-30 to 2026-10-01, in thirteen
tasks: the numbers (sizes, spacing, moons as targets, the warp), the map and far plane, the far
mesh from `WorldTerrain`, `CubeSphere`, `TerrainChunkData`, `WorldSurface`, `TerrainCollider` and
the floor, the altitude speed limit and `Whereabouts.well()`/`altitude()`, the descent probe, and
the documents. Versions: `WorldRecipe.GENERATOR_VERSION` 2, `SystemRecipe.VERSION` 3,
`AsteroidRecipe.VERSION` 4, so an old save starts over at the start. The sections above are
amended in place where the build differs and marked *as built*; this section says why.

Tests: 1,674 before (158 scripts); 1,734 at Task 11's last full run, and two more in
`test_world_surface.gd` since. Per the owner's rule of 2026-10-01 the full suite was not run after
Task 12; the owner decides whether to run it before merging.

### 13.1 The far plane is 700 km, not 400 km

`BodyProxy.VIEW_FAR` is `PROXY_AT + SystemRecipe.STAR_RADIUS.y + 50 km`, 700 km. A proxy just past
`PROXY_AT` (350 km) is drawn at nearly its true radius, so its far edge lies about `PROXY_AT` plus
its radius from the eye, and the star's radius is up to 300 km. With 400 km the render probe showed
the star's disc clipped; 420 km showed it whole. The far plane has to hold `PROXY_AT` plus the
biggest body's radius. Reversed-Z makes the length free of precision cost and nothing else is drawn
that far.

### 13.2 The split distance is measured to the real ground

The plan's metric padded every node's bounding sphere by half the world's relief (about 600 m on
the largest), so everything within roughly 600 m split to the finest depth: about 2,000 chunks.
As built, `WorldSurface.select()` measures from the focus to the node's real ground point (its
centre direction at the radius plus `height_at` there) minus the node's corner chord, with no
relief padding. `bound_of` returns `[centre, cull radius, ground point, chord]`; the relief-padded
cull radius is for horizon culling only. `SPLIT` and `MERGE` are the spec's 1.5 and 1.8 (they were
tuned to 1.3 and 1.6 on the way and put back once the metric was fixed).

### 13.3 Chunks built about 450, in view about 100: the budget that binds is in view

At ground level a 60 km world has about 450 chunks built (452 at 2 m, 391 to 470 over a skim), not
the 250 estimated in §5.2: "within 1.5× its edge of its bounding sphere" ignored the chord. The
binding budget of §5.6 is chunks **in view**, at 150 or fewer, and that holds: **94 in the canopy's
frustum on the descent, 115 on the skim.**
`test_the_chunk_count_stays_in_budget_at_every_height` caps built chunks at 500. If a later probe
shows more than 150 in view, `SPLIT` is the lever. A chunk builds in about 4 ms on a worker.

### 13.4 Solid ground

- Solid keys run to 113 to 380 an anchor at full reach (149 on the test planet), across the
  planet range: `keys_near`'s disc is `ceil(reach / edge) + 1`. 200 is only the bound the test
  puts on the test planet, not a cap. They are cached per anchor, since a cube-edge `keys_near` cost 1.8 to 7.5 ms uncached.
- The chunk **under** an anchor is first in `keys_near` and is built at once, directly, through
  `key_for`, so a fast, low hull never outruns its own ground.
- A ghosted hull (mask 0, at warp) is never lifted by the floor.

### 13.5 `PATCH_QUADS` stays 6, and a direct shade-patch test

Tuning `WorldTerrain.PATCH_QUADS` to 12 passed a test that measured the 1,280-face far mesh, but
that test was dominated by ground-pattern changes, not shade patches. The test now samples
consecutive points one triangle apart along a great circle and requires that they share a shade
more than 60% of the time (measured 0.84 at `PATCH_QUADS` 6), and the far mesh uses one nominal
patch size per detail rather than each face's lifted edge. If the owner finds six-triangle patches
too busy, `PATCH_QUADS` is the one constant to raise.

### 13.6 The descent probe, and what it found

`test/probes/world_probe.gd` runs in the real flight scene (1280 × 720, GTX 960, Vulkan Forward+,
not headless): it warps to the largest planet (r 54,607 m, relief 864 m), descends from its limit
to the ground at the speed limit, and skims 20 km, logging per-phase frames, worst frame, frames
over 33 ms, draw calls, chunks visible, in the frustum and built, and the floor's count.

It found the **`_apply` death spiral.** Skimming at 150 m, `_apply` sorted every finished chunk,
including ones no longer wanted, by distance before applying any; once the sort used up the 2 ms
budget nothing was applied, `_done` grew without end (2,255 to 2,930), leaves stayed undrawn, and
frames went to 400 to 730 ms with memory climbing from 187 to 605 MB. The owner saw it in play
("unusable"). The fix (`dbc85ee`): `_apply` first drops results nobody wants, works each distance
out once, and applies at least one result a tick whatever the deadline; the bounds cache is capped
(`BOUNDS_KEPT`).

| After the fix | Descent | Skim |
|---|---|---|
| Frames, time | 13,300 frames, 222 s | 9,697 frames, 162 s |
| Worst frame | 28.9 ms, none over 33 ms | 33.7 ms, 3 of 9,697 over 33 ms |
| Chunks in the frustum / built | 94 / 392 | 115 / 470 |
| Draw calls, at most | 1,085 | 1,269 |
| Floor fired | 0 | 0 |

Memory stays flat. The skim misses the 33 ms budget by 0.7 ms on three frames, within one vsync of
a 60 Hz screen; "frames over 33 ms in 10,000" is a steadier budget than a strict worst frame. The
first frames after a teleport cost 137 to 147 ms (shaders and uploads at a new place); the probe
settles 60 ticks first.

**Remaining cost (open):** `WorldSurface.update()` costs 8 to 16 ms a physics tick at the speed
limit (about 25 m a tick): `select` about 4 ms, solid keys 5 to 7 ms, `_apply` about 2.2 ms. The
frame is physics-bound there, with about 8 ms of headroom. Levers, not pulled: keep the previous
solid keys and add only the swept path ahead (or compute them on a worker); cache a node's ground
in `_bounds` (terrain is a pure function of direction, so it cannot go stale).

### 13.7 The look: approval pending

The world renders (from a neighbour, the limit, the well's edge, 1 km, skimming at 150 m,
standing at 1.6 m, a belt) were sent to the owner on 2026-10-01 for the look, and **approval is
pending**. So `docs/design/visual-style.md` is not changed and has no *Worlds up close* rule yet.
On approval it gains one stating what was approved (flat-shaded chunks, one palette colour a
triangle, shade patches about six triangles across, rock on slopes over 35°), with the date and
the render names; if the owner asks for something else, record it here. What the renders showed:
no holes, cracks or z-fighting; patch edges visibly stair-stepped on the coarse meshes; ridges a
little busy from 1 km; standing on the ground reads best. The size renders of Part A (planet
25 km, star, belts) were shown to the owner earlier; no change was recorded.

### 13.8 Levers

| Lever | Value | Why |
|---|---|---|
| `QUADS` | 16, unchanged | no draw-call problem: 1,085 to 1,269 at most |
| `SPLIT` / `MERGE` | 1.5 / 1.8, unchanged | tuned to 1.3 / 1.6, then restored once the metric was fixed (§13.2) |
| `WarpProfile.PACE` | 350,000, unchanged | measured 30.4 s mean trip between star and planets, inside 25 to 35 s |
| `BELT_GAP` | 300 km, unchanged | no rule needed it moved |
| `WorldTerrain.PATCH_QUADS` | 6, unchanged | 12 tried and withdrawn (§13.5) |

### 13.9 Left to do

- **Fix before merge:** `FlightComputer.locked_speed` is re-clamped only while W or S is pressed,
  so a lock set high in a well (say 1,400) stays after leaving it: a stale LOCK readout, and the
  assist pushes against the clamp every tick. Clamp it to `current_limit` every tick.
- `WorldSurface.update()` at the speed limit (§13.6).
- **Horizon hole:** a region newly over the horizon has no drawn ancestor once its root was freed,
  so it is blank until its leaves build; the class doc's "nothing is ever a hole" overclaims. Low
  severity; not seen in the renders.
- `FlightComputer`: `current_limit` and `limit_raised` are not updated during a warp (a stale HUD
  if one starts with the limit raised); `well()` is computed twice a tick; `var ease` shadows the
  built-in.
- Belts from afar: a slab is 2 to 3 px at 2,600 km, so a belt reads as a dotted arc; the slab fade
  (22 to 26 km) was not rescaled to 8 to 16 km slabs and may pop at the hand-over. A cluster's
  lift of group chance is masked in belt cores (the chance is already 1.0). `problems()` does not
  check moon limits against each other, so adjacent moons can block each other's warp line (§3.3
  allows it). The moon and long-warp scene tests fall back to `pass_test` if a seed has no moon or
  no 5,000 km line.
- Render probes: `world_moon_in_the_sky` shows no moon (it needs a lit angle). The SYSTEM and
  500 km map renders from the start inside a cluster show a huge rock and "TOO CLOSE TO WARP"; the
  SYSTEM page wants the owner's eye. `computer_render.gd` ran with saving on before this branch
  fixed it, so it may have rewritten the owner's save.
- Missing tests: a mid-stream no-hole/no-overlap check, a seam test in `test_cube_sphere`, a skirt
  geometry test, `set_warp` freezing proxies, a far mesh for a cratered world or the star.
- Housekeeping: `AsteroidStream.VIEW_FAR` and `BodyProxy.FADE_MARGIN` are unused; one full run
  failed `test_save_scene` because the real save's mtime changed mid-run (something else was
  writing it); subagent commits carry `Co-Authored-By: Claude Sonnet 5.5`, not the plan's Opus 5.5
  line.
