# Planetfall — worlds you can fly to, land on, and walk out onto

**Date:** 2026-09-23
**Status:** Design approved section by section on 2026-09-23; awaiting the owner's review of this
written spec before an implementation plan
**Depends on:** `main` at `c64920d` (grid-generated ship, inertia-scaled flight assist, piloting HUD);
for §10 only, the ship interior redesign (`docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md`,
merged to `main` in `77c58a7`): its airlock `HATCH` variant, `SlidingDoor`, `InteriorProps` library
and interior camera environment
**Relates to:** slice spec §3 (interior/exterior split), §3.3 (bounded arenas), §7 (flight), roadmap
Slice 6; piloting HUD spec §4.3, §5, §6, §10; starter shuttle art direction §4 (`airlock`)
**Amends:** slice spec §2, §3.3, §12 and the roadmap appendix; piloting HUD spec §10 (see §16)

---

## 1. Why this document exists

The owner's direction: *fly through space to different worlds. The worlds are big compared to the
player but not realistic in scale. A place you can land and explore, find things, do things,
encounter friends or enemies, lay claim. Start with one in the test area, but the goal is that they
are generated pseudo-randomly, so you never know what you might find. Hence "who knows".*

The slice spec already makes information the scarce resource (§1.1). Planetfall extends that to
places: every world is a seed, and the honest answer to "what is on that one?" is, structurally,
*who knows* — until you go and look.

### 1.1 The pitch

A world hangs ahead of you in the test area. You fly to it. The HUD tells you its name and how
hard it pulls. You come down under assist, the ship levels itself over the ground, and you set
down. You stand up, walk aft, and cycle the airlock. The outer door opens onto the surface.
There is a signal over the ridge that the scanner cannot identify. You walk to it and find out
what it is.

Press F9 and it is a different world.

---

## 2. Decomposition

The owner's idea is eight subsystems, not one:

| # | Piece | This spec |
|---|-------|-----------|
| 1 | **World generation** — seed → recipe → terrain and collision | **In** |
| 2 | **Getting there** — gravity, descent, landing | **In** |
| 3 | **Stepping outside** — crossing the interior/exterior split | **In** |
| 4 | **On foot on a world** — walking where down points at the centre | **In** |
| 5 | **Things to find and do** — sites on the surface | **Thin slice**: signals and discoveries |
| 6 | Encounters — friends and enemies (needs AI) | Hooks only (§18) |
| 7 | Laying claim — ownership and persistence | Hooks only (§18) |
| 8 | Many worlds — a system of seeds | Hooks only (§18) |

Pieces 6–8 each get their own spec → plan → implementation cycle, in an order the owner chooses.

---

## 3. Decisions taken, and why

Each was put to the owner as options with trade-offs.

| Question | Decision | Why |
|---|---|---|
| World scale and shape | **Small round worlds**, radius 300–1200 m, a few km apart | Seamless descent from space, a visible horizon curve, walk round one in 8–30 minutes. Single-precision floats stay accurate at this range, so no floating origin (slice spec §3.3 still holds in spirit; §16). |
| Terrain representation | **Cube-sphere heightfield** with a quadtree for render detail and separate collision near physics bodies | The standard technique for small planets; one pure height function serves terrain, placement, altitude and seams; fits the flat-shaded art direction. Voxels (caves, digging) were rejected as far heavier and likely needing a custom engine build. Authored planets were rejected for lack of variety. |
| How the player gets outside | **Airlock cycle** | The world handoff happens while the player is shut in a closed room, so it is never seen. Gives the inert `airlock` block its job. |
| Descent and landing | **Assisted descent** | Assist holds a hover against gravity and levels to the horizon; hard landings are flagged. Gravity becomes a ship-design constraint via lift margin. |
| First content | **Unknown signals** that resolve into discoveries | The information theme, applied to places. Rewards are information because there is no inventory yet. |
| What claiming means | **Not decided** | World state is stored as *seed + a list of changes* so either outposts or beacons fit later. |

---

## 4. Architecture

The world follows the same shape as the ship: one source of truth, read by independent builders.

```
seed ──► WorldRecipe.from_seed(seed)         pure; every knob the seed decided
            │
            ▼
        WorldTerrain.height_at(dir) → metres  pure; THE source of truth for the ground
            │
     ┌──────┴──────────────────┐
 TerrainRenderer            TerrainCollider
 quadtree detail,           full-detail chunks near
 follows the camera         "terrain anchors" (hull, avatar)
            │                          │
            └──── TerrainChunkData ────┘   pure: one chunk's packed arrays,
                  (worker threads)          shared by both

 Planet (Node3D)
   GravityWell (Area3D)    engine-native point gravity
   Terrain                 renderer + collider
   Atmosphere              optional shell
   Sites                   one node per recipe site

 WorldState                seed + changes (sites discovered, …)
```

**Nothing but `WorldTerrain` decides where the ground is.** Chunk vertices, collision, site
placement, prop snapping, the altitude readout and the tunnelling safety net (§8.5) all call
`height_at`. No consumer reads another consumer's geometry.

### 4.1 Files

```
who-knows/
  src/world/
    world_seed.gd           sub-seed mixing (§5.1)
    world_recipe.gd         WorldRecipe Resource + from_seed()
    world_palettes.gd       the eight palettes; constants only (HudPalette pattern)
    world_names.gd          syllable name generator
    world_terrain.gd        height_at, surface_point, altitude_of; archetypes; site flattening
    cube_sphere.gd          face/uv ↔ direction mapping; chunk ids; max depth
    terrain_chunk_data.gd   pure: one chunk's render arrays, collision faces, boulders
    terrain_renderer.gd     quadtree LOD driven by the active camera; worker dispatch
    terrain_collider.gd     max-depth collision chunks driven by terrain anchors
    rock_mesh.gd            extracted from DebrisField; DebrisField calls it
    planet.gd               Planet node
    world_state.gd          seed + changes
    sites/                  site_builder.gd, wreck.gd, monolith.gd, crystal_grove.gd,
                            supply_cache.gd, site_node.gd, site_text.gd
  src/flight/landing_monitor.gd
  src/ship/airlock_cycle.gd
  src/ui/panels/surface_panel.gd
  src/ui/signal_markers.gd, signal_contact.gd, toast_line.gd, discovery_log.gd
  data/materials/world/terrain.gdshader, atmosphere.gdshader
```

Modified: `ship.gd`, `flight_computer.gd`, `avatar.gd`, `interactor.gd`, `camera_director.gd`,
`motion_coupling.gd`, `exterior_builder.gd`, `ship_validator.gd`, `vehicle_telemetry.gd`,
`debris_field.gd`, `flight_test.gd`/`.tscn`, `project.godot`; and, from the interior redesign,
`interior_layout.gd` and `sliding_door.gd` (§10.2).

### 4.2 Physics layers

`project.godot` gains two named layers. Render layers are unchanged; terrain and sites render on
layer 1 (`exterior`).

| Layer | Name | Who is on it | Who collides with it |
|---|---|---|---|
| 1 | `exterior_hull` | hulls | hulls; the avatar on EVA |
| 2 | `interior_geometry` | interior structure | the avatar inside |
| 3 | `avatar` | the avatar | door triggers; gravity wells |
| **4** | **`terrain`** | terrain collision chunks | hulls; the avatar on EVA |
| **5** | **`exterior_props`** | site colliders; the exterior airlock control | the avatar on EVA; the EVA interactor |

> **Amended 2026-09-23 (hands and items):** layer 6 is `items`, loose and carried items
> (`docs/superpowers/specs/2026-09-23-hands-and-items-design.md` §3.2). The avatar on EVA must
> keep colliding with it: its EVA mask is layers 1, 4, 5 and 6.

---

## 5. The world recipe

### 5.1 Determinism

`WorldRecipe.from_seed(seed)` is a pure function. Same seed, same recipe, on every machine and
every run.

- **Each concern draws from its own sub-seed:** `WorldSeed.sub(seed, &"terrain")`,
  `&"palette"`, `&"atmosphere"`, `&"sites"`, `&"name"`, `&"boulders"`, and per-site
  `&"site_<id>"`. Adding a knob later, or reordering draws within one concern, cannot reshuffle
  any other concern. A seed someone remembers as "the crystal moon" stays the crystal moon.
- **The mix is hand-written** — SplitMix64 over `seed XOR FNV-1a(concern name)` — not Godot's
  `hash()`, whose output is not guaranteed stable between engine versions.
- Draws use `RandomNumberGenerator` seeded from the sub-seed. `FastNoiseLite.seed` takes the
  sub-seed's low 31 bits.
- `WorldRecipe.GENERATOR_VERSION := 1` is part of a world's identity. Anything that would change
  an existing seed's output bumps it. Nothing reads it yet; saved worlds will.

### 5.2 What a seed decides

| Field | Range | Notes |
|---|---|---|
| `name` | e.g. `KORVA-7` | Two or three syllables from a seeded table, plus a designation number |
| `radius_m` | 300–1200 | Uniform |
| `surface_gravity` | 2.0–8.0 m/s² | Capped below the starter shuttle's ≈10.8 m/s² of lift so no world strands the only ship. The cap is one constant; revisit when ships can be refitted (§17) |
| `archetype` | `CRATERED`, `ROLLING`, `RIDGED`, `MESA` | Equal weights (§6.2) |
| `relief` | 2–6% of radius | Peak-to-trough terrain amplitude; 72 m at most |
| `palette` | one of eight | §5.3 |
| `atmosphere` | `NONE` 40%, `THIN` 35%, `THICK` 25% | Visual only (§7.3); tint from the palette |
| `sites` | 3–6 attempted | Placement can yield fewer (§12.1) |
| `boulder_density` | per archetype, jittered ±30% | §6.5 |

### 5.3 Palettes

`world_palettes.gd` holds eight curated palettes, constants only. Each defines `ground_low`,
`ground_high`, `rock` (steep slopes), `dust` (boulders), `accent` (site emissives) and `sky`
(atmosphere tint). Seeds pick a palette whole, with no hue jitter, which keeps the art
direction's "tight palette" (slice spec §11) true of every world. The exact colours are chosen in
the implementation plan's art task and approved by the owner from rendered swatches, the way the
interior palette was.

---

## 6. Terrain

### 6.1 The height function

```gdscript
# WorldTerrain — built from a WorldRecipe; one instance per thread (§6.6)
func height_at(dir: Vector3) -> float          # metres above radius_m; may be negative
func surface_point(dir: Vector3) -> Vector3    # planet-local: dir * (radius_m + height_at(dir))
func altitude_of(local_pos: Vector3) -> float  # local_pos.length() - (radius_m + height_at(dir))
```

Noise is sampled at `dir * radius_m`, a point in 3D, so the surface is seamless everywhere on the
sphere by construction. Cube-face edges need no stitching.

### 6.2 Archetypes

Each archetype is a recipe of `FastNoiseLite` layers scaled to `relief`:

- **`ROLLING`** — smooth simplex FBM, 4 octaves, base frequency giving 6–10 hills across a
  hemisphere. Dunes and downs.
- **`RIDGED`** — ridged FBM, 5 octaves, under a low-frequency mask so ranges are separated by
  lowlands.
- **`MESA`** — FBM, then terraced: 3–5 steps, each flat for 80% of its height with a steep riser
  in the last 20%. Plateaus and canyons.
- **`CRATERED`** — low-amplitude FBM plus **two cellular-noise crater layers** at different
  frequencies. Each uses the distance-to-nearest-feature-point return, shaped into a bowl with a
  raised rim. Cellular noise is native, stateless and thread-safe, so craters cost no more than
  hills and need no crater list.

### 6.3 Site flattening

Around each site, `height_at` blends toward the height at the site's centre:
`h = lerp(h, h_site, 1 − smoothstep(12 m, 25 m, d))`, with `d` the chord distance to the site.
Props sit on level ground without being hand-placed, and no consumer needs to know flattening
happened.

### 6.4 Cube-sphere and the quadtree

- Six faces, each with face-local `(u, v) ∈ [−1, 1]²`. Cube points map to sphere directions with
  the **spherified-cube** mapping rather than plain normalisation, for evenly sized cells.
- Each face is a quadtree. A node is `(face, depth, ix, iy)`, and every node's chunk is
  **16 × 16 quads** (17 × 17 vertices) plus a skirt.
- **Maximum depth per world:** the smallest `D` with a leaf quad edge of 2.0 m or less:
  `D = ceil(log2(π·R / (2 · 16 · 2.0)))`. That is D = 4 at 300 m and D = 6 at 1200 m, both about
  1.84 m per quad.
- **Render split rule:** split a node when the active camera is within `2.5 ×` its edge length
  of its bounding sphere; merge again beyond `3.0 ×`, for hysteresis. The first frame shows
  depth-1 geometry, built synchronously at load, so the world is visible immediately.
- **Skirts:** each chunk edge drops a one-quad skirt radially inward by twice that chunk's quad
  edge, hiding cracks between neighbouring levels. There is no geomorphing: popping is accepted,
  and the flat-shaded style hides most of it.
- **Look:** flat-shaded with per-triangle normals, as `DebrisField` and the interior already are.
  **One colour per triangle**, chosen from the palette by the triangle's height band
  (`ground_low` → `ground_high`) and slope (`rock` above 35°). One `terrain.gdshader` material:
  vertex-colour albedo plus the atmosphere's distance fog (§7.3).

### 6.5 Collision

- **Collision is decoupled from what is drawn.** Collision chunks are always at maximum depth D,
  whatever the render quadtree is doing.
- A **terrain anchor** is any node in group `&"terrain_anchor"`: the hull always, the avatar
  while on EVA, and later NPCs. Each anchor keeps built every max-depth chunk within
  `64 m + 1.0 s × its speed` of it, capped at 160 m.
- A collision chunk is a `StaticBody3D` (layer 4, mask 0) holding a `ConcavePolygonShape3D`
  built from the **same `TerrainChunkData`** as the render chunk. At maximum depth the ground you
  see is the ground you stand on.
- **Boulders:** each max-depth chunk scatters boulders from its own sub-seed, using the rock mesh
  extracted from `DebrisField`. They render through one `MultiMesh` per render chunk at depth
  D−1 and deeper. Boulders of 1 m and over get a `SphereShape3D` (radius 0.4 × diameter) in their
  collision chunk; smaller ones are decoration.
- `TerrainCollider.is_ready(point, radius) -> bool` answers whether collision exists there. The
  airlock waits on it (§10.4).

### 6.6 Threading and budgets

- `TerrainChunkData` builds packed arrays (positions, normals, colours, collision faces, boulder
  transforms) in `WorkerThreadPool` tasks. **Each task uses its own `WorldTerrain` with its own
  `FastNoiseLite` copies;** none are shared across threads.
- The main thread turns finished data into meshes, shapes and nodes, **at most four chunks per
  frame**. A generation counter drops results superseded while they were building.
- **Budgets:** a chunk builds in 10 ms or less on a worker; applying one costs 1 ms or less on
  the main thread; streaming never produces a frame over 33 ms. The target is steady 60 fps at
  1280 × 720 on a GTX 960 (the interior redesign's target), on approach and on the ground.
- **Fallback if GDScript misses budget:** first drop to 12 × 12 quads per chunk. This project
  runs the .NET build of Godot, so a C# port of `TerrainChunkData` and `WorldTerrain` is the
  second fallback.

---

## 7. The Planet node

### 7.1 Gravity

`GravityWell` is an `Area3D` with a `SphereShape3D` of radius **3R**:

- `gravity_point = true`, `gravity_point_center = Vector3.ZERO`,
  `gravity_point_unit_distance = R`, `gravity = surface_gravity`, giving inverse-square falloff
  that equals the recipe's value at the base radius.
- **`gravity_space_override = SPACE_OVERRIDE_COMBINE`.** The default, `DISABLED`, makes the area
  apply no gravity at all, silently. Read back at runtime (§15.3).
- `collision_mask` = layers 1 and 3 (hulls and the avatar). Project default gravity stays 0, so
  deep space is unchanged.

This is the **one source of gravity**. Rigid bodies receive it automatically. The hull and the
avatar read the combined value with `get_gravity()`. Future NPCs and dropped items get it for
free.

**World context.** The well's `body_entered`/`body_exited` signals tell the bootstrap, which sets
a nullable `world: Planet` on the flight computer, the landing monitor and the avatar. That is
the only coupling between a ship and a world, and it already generalises to many worlds.

**Interior guard.** At load and after every re-roll, `Planet` reports a `push_error` if its well
intersects any of the first eight interior slots (`Ship.INTERIOR_WORLD_BASE +
slot × SLOT_SPACING`, each treated as a 1000 m sphere). The interior avatar ignores
`get_gravity()` anyway (§11.1), so this guard is a second, independent protection.

### 7.2 Static worlds

Planets neither spin nor orbit. A landed ship stays exactly where it is, and flight assist's
"world frame" and the surface frame are the same thing.

### 7.3 Atmosphere

Visual only: no drag, no heat, no pressure.

- **Shell:** a sphere at 1.12 R (thin) or 1.2 R (thick) with `atmosphere.gdshader`. From outside
  it draws a fresnel rim glow in the palette's `sky` colour. From inside it draws a sky
  gradient, strongest at the horizon, over the stars. Both are lit by the sun direction, so the
  night side's sky is dark.
- **Fog:** `terrain.gdshader` and site materials apply
  `1 − exp(−density × view_distance)` in the sky colour, only while the camera is inside the
  shell.
- **The global `WorldEnvironment` is never modified.** Every camera in the scene shares it,
  including interior space's, so fog there would fill the cabin.

### 7.4 The sun

The scene's existing `DirectionalLight3D` is re-aimed so the hemisphere facing spawn is lit,
35° off the spawn axis. Relief shades clearly on approach and the terminator is visible. The
night side is really dark: the suit lamp (§11.3) and the sites' emissive accents make it
explorable.

---

## 8. Flight near a world

### 8.1 Reading gravity

`FlightComputer` reads `_hull.get_gravity()` each physics tick. `Ship._ready()` changes the hull
from `gravity_scale = 0.0` to `1.0`, and physics applies the pull itself. The flight computer
only needs to know about it so it can fight it.

### 8.2 Thrust allocation

Per hull axis and direction (forward/reverse along Z, both ways along X, both ways along Y), thrust
is allocated in **priority order**, each stage taking only what the earlier stages left of that
direction's budget:

1. **Gravity hold** (assist on, in a well): demand `−g × mass`, expressed in hull axes.
2. **Pilot command.**
3. **Drift correction** (assist on), unchanged in meaning.

**The sum never exceeds the budget.** A tilted ship spends whatever thrusters happen to point
against gravity, and sinks if those are weak. Boost keeps its current meaning: it multiplies the
pilot's command, and that direction's cap rises by the same 2.5×.

With the stick centred, gravity hold plus drift correction means **hovering in place**. With
assist off, stages 1 and 3 do not run, so gravity simply acts. Lunar-lander flying needs no extra
code.

### 8.3 Horizon levelling

When assist is on, a world is set, and keel altitude is under **150 m**, the assist adds a
levelling term to its pitch and roll rate targets. That term is `1.5 /s ×` the angle from hull
up to local up, split onto the hull's pitch and roll axes and clamped to `ASSIST_TURN_RATE`. It
fades in linearly from zero at 150 m to full at 100 m. **It applies only on axes where the pilot
is giving no input,** so the stick always wins. Yaw is never touched.

### 8.4 Derived surface values

- **Altitude** is measured from the keel: `world.altitude_of(hull origin)` minus the grid's keel
  depth (the bottom face of the lowest occupied cell; 1 m on the starter). It reads 0 on flat
  ground. It uses `height_at`, with no raycast.
- **Vertical speed** is `velocity · local_up`.
- **Lift margin** is `thrust_budget.vertical / (mass × |g|)`, recomputed every tick because `g`
  varies with altitude. On the surface of an 8 m/s² world the ≈92 t starter has about **1.35**,
  so hovering there takes 74% of its vertical thrust.
- **Tilt** is the angle between hull up and local up.

### 8.5 Not falling through the ground

At the 120 m/s cruise ceiling the hull moves 2 m per 60 Hz tick against a surface with no
thickness.

- The hull gets `continuous_cd = true`.
- **Safety net:** if keel altitude is ever below −0.5 m, meaning genuinely under the analytic
  ground, the hull is moved out along local up to altitude 0, its inward velocity is removed, and
  a warning is logged. This should never fire; if it does, a collision chunk was late or
  continuous collision missed.

### 8.6 Hull changes

`Ship._ready()`: `gravity_scale = 1.0`; `collision_mask` = layers 1 and 4; `contact_monitor =
true`, `max_contacts_reported = 8`; `continuous_cd = true`; and the hull joins
`&"terrain_anchor"`.

---

## 9. Landing

`LandingMonitor` (`src/flight/landing_monitor.gd`, a `Node` on the `Ship`) owns the hull's
relationship with the ground. Its transition logic is a static pure function,
`step(state, inputs) -> state`, testable headless (the `VelocityMarker` state-policy pattern,
HUD spec §8.1). The node only gathers inputs and applies results.

| From | To | When |
|---|---|---|
| FLYING | TOUCHING | First contact with a layer-4 body. Records closing speed `−(v · local_up)`. Above **4.0 m/s**, emits `hard_landing(speed)`. |
| TOUCHING | LANDED | Held continuously for **1.0 s**: touching terrain, speed < 0.5 m/s, spin < 0.1 rad/s, tilt < **25°**, pilot translation zero |
| TOUCHING | FLYING | No terrain contact for 0.25 s |
| LANDED | FLYING | Any non-zero pilot translation (only possible from the seat) |

- **On LANDED the hull freezes:** `freeze_mode = FREEZE_MODE_STATIC`, `freeze = true`, and
  `FlightComputer` applies no forces. The ship cannot creep downhill or jitter on the terrain
  mesh while the player is outside, and the airlock's step-out point cannot move.
- **Tilt over 25°** keeps the ship in TOUCHING. The HUD shows *UNEVEN GROUND · TILT 31°*, and
  the airlock will not cycle.
- `hard_landing` is a warning in this slice. Slice 2 turns it into block damage through the
  existing `ShipGrid` mutation API.
- Emits `state_changed(state)`.

---

## 10. The airlock cycle

### 10.1 Which face is the hatch

The hatch is the airlock cell's **one wall face (±X or ±Z) onto empty space**, the same face the
interior redesign dresses with its `HATCH` variant (redesign §5.1). Floor and ceiling faces never
count. `ShipValidator` gains **Rule 6 (warning):** every airlock has exactly one such face. An
airlock with none or several is inert. The starter shuttle's airlock at (0, 0, 3) has exactly
one, facing +Z (aft).

### 10.2 Interior side

- The airlock cell gets its own zone, `&"airlock"`, in `InteriorLayout`. The redesign's partition
  and doorway rules (redesign §7.2) then put a wall and **one doorway with a `SlidingDoor`**
  between it and the corridor. The airlock zone takes no feature or secondary furniture: its
  walls keep the `HATCH` and `PANEL` variants.
- **`SlidingDoor` gains `locked`.** While locked it ignores its trigger, stays shut, and enables a
  collider across the opening. **Unlocked doors still never have a collider,** so the redesign's
  guarantee that a door cannot trap anyone (§7.3) holds for every door that is not mid-cycle.
- An `AirlockControl` panel (a `StaticBody3D` on layer 2 with `interact()`) is generated beside
  the hatch. Its prompt is *F — Cycle airlock*.

### 10.3 Exterior side: the alcove

In exterior space every cell is a solid box collider today, so there is nowhere to stand inside
the airlock. For airlock cells, `ExteriorBuilder` instead builds:

- **no full-cell box collider**; a floor slab; and thin wall colliders on any face onto empty
  space other than the hatch. Faces onto occupied neighbours rely on the neighbours' own boxes;
- **an alcove mesh:** a closed 2 m box open only on the hatch face, with its own inner walls,
  dressed with **the same `InteriorProps` pieces as the interior airlock** (hatch leaves, wall
  trim, ceiling light) in the same frames, plus its own light. The redesign built the prop
  library to be reused by other generators (redesign §1.2, §4); this is the first;
- **an outer door:** a `SlidingDoor`, locked except when the cycle opens it;
- an exterior `AirlockControl` on layer 5.

**At the moment of the swap both sides look alike:** a dim alcove, the same hatch leaves, a
closed door in front of you.

### 10.4 The cycle

`AirlockCycle` (`src/ship/airlock_cycle.gd`, one per ship, bound to the ship's first valid
airlock) is a state machine with a pure transition policy.

**Going out** (about 3.1 s):

| State | Duration | What happens |
|---|---|---|
| `SEALING` | 0.5 s | Inner door locks and closes. Movement is disabled; looking around is not. |
| `CYCLING` | 2.0 s | Red light, hiss, and a pressure readout on the hatch display counting 100 → 0 kPa. Lights dim to 20% for the final 0.4 s. **At 1.8 s, in the dark, the avatar is transferred** (§10.5). At that moment the cycle checks `TerrainCollider.is_ready()` at the step-out point. If collision is not ready, the cycle holds, dark, for up to 5 s. If it is still not ready, the cycle aborts: pressure climbs back to 100 kPa, the inner door unlocks and reopens, and the toast reads *CYCLE ABORTED*. |
| `OPENING` | 0.6 s | The camera environment switches to the world's (§11.4). The exterior outer door slides open onto the surface. Movement is re-enabled. |
| `OUTSIDE` | — | On EVA. |

**Coming back in:** F at the exterior control, standing in the alcove. `CLOSING` (0.6 s, outer
door shuts, movement off) → `CYCLING` (0 → 100 kPa; transfer and environment switch back at the
dark beat) → `UNSEALING` (0.5 s, inner door unlocks and opens, movement on) → idle.

**Refusals**, shown as toasts (§13.3):

- *NOT LANDED* — `LandingMonitor` is not LANDED.
- *UNEVEN GROUND · TILT n°* — shown instead of *NOT LANDED* when tilt over 25° is what keeps the
  ship in TOUCHING (§9).
- *HATCH BLOCKED* — a shape cast of the avatar's capsule 2.5 m outward from the hatch face hits
  layer 4 or 5.
- The cycle also refuses until the avatar is wholly inside the airlock cell and clear of the
  doorway trigger.

### 10.5 The transfer

Interior-local space **is** hull-local space: the same grid coordinates on the same axes, which
`flight_test.gd::_aim_canopy_view()` already relies on. So the transfer is exact:

```
hull_local   = interior.global_transform.affine_inverse() * avatar.global_transform
avatar_world = hull.global_transform * hull_local                      # going out
avatar_int   = interior.global_transform * (hull.global_transform.affine_inverse() * avatar_world)
```

Velocity is zeroed (movement is disabled throughout `CYCLING`). On transfer out:

- the avatar is reparented from `Ship/Interior` to the planet's surface root;
- its `collision_mask` becomes layers 1, 4 and 5 (hull, terrain, props), so you can climb on
  your own ship;
- the `Interactor`'s mask becomes layer 5;
- the avatar switches to field gravity (§11.1) and joins `&"terrain_anchor"`;
- `MotionCoupling` stops writing `external_accel` and head shake to it;
- `CameraDirector` sets `is_eva`. The first- and third-person foot views work unchanged because
  the camera rides the avatar's head, and the chase camera is not offered on foot, as now.

Transfer back reverses every item.

> **Amended 2026-09-23 (hands and items):** a wielded item travels with the avatar because it
> hangs in the hands. A carried item must be moved with the same transform maths, and items switch
> from render layer 2 to layer 1 outside (`docs/superpowers/specs/2026-09-23-hands-and-items-design.md` §15).

---

## 11. On foot on a world

### 11.1 The avatar's up vector

`Avatar` gains `up: Vector3` and a gravity mode:

- **`PLATING`** (inside a ship): gravity is `Vector3.DOWN × grav_strength`, and up is +Y. This
  is exactly today's behaviour, and a regression test pins it.
- **`FIELD`** (on EVA): gravity is `get_gravity()`, and up is `−gravity.normalized()`, keeping
  the last up if gravity is near zero.

Each physics tick the body basis rotates by the **shortest arc** from its current up to `up`, so
heading is preserved as you walk around the curve. Mouse yaw becomes a rotation about the current
up, replacing `rotation.y = _yaw`; head pitch is unchanged. Velocity splits into its component
along `up` and its tangent part, and `move_toward` acts on the tangent part only.
`CharacterBody3D.up_direction` is set to `up` each tick, so floor detection and snapping follow
the planet.

### 11.2 Jump

New `jump` action on Space, **on EVA only**, since the cabin's 1.9 m of headroom leaves nowhere
to go. The take-off speed is fixed at 3.1 m/s, so jump height falls as gravity rises: 2.4 m at
2 m/s², 0.6 m at 8 m/s². This is the most direct way to *feel* a world's gravity. Space is also
`boost`, but boost is read only while seated and jump only while on foot.

### 11.3 Suit lamp

A `SpotLight3D` on the head, toggled by the new `suit_lamp` action (L), EVA only: range 25 m,
angle 35°, `light_cull_mask` = layer 1, no shadows (GTX 960).

### 11.4 Camera environment

The interior redesign sets `ship_interior.tres` on the interior camera, which is the avatar's
head camera. That camera goes outside with the avatar. It keeps `ship_interior.tres` through the
swap and switches to `null` (the scene's `WorldEnvironment`) as the outer door starts opening;
coming back in, it switches back at the dark beat.

---

## 12. Signals

### 12.1 Sites in the recipe

A site is `{id, type, dir, seed}`.

- **Placement:** candidate directions drawn uniformly on the sphere from the `&"sites"` sub-seed.
  A candidate is rejected if its great-circle distance to an accepted site is under
  `max(150 m, 2πR / 10)`, or if the unflattened slope there is over 20°. Up to 200 attempts.
  This can place fewer sites than attempted, or even none: a barren rock is a legitimate world.
- **Types**, weighted `WRECK` 3 : `MONOLITH` 1 : `GROVE` 3 : `CACHE` 2. At most one monolith per
  world, and only on worlds with two or more sites.

### 12.2 Site builders

`SiteBuilder.build(type, seed, palette) -> Node3D` builds in a local frame: origin on the ground
at the site, +Y along local up. The frame convention follows the interior redesign's props
(redesign §4). **Builders know nothing about planets,** so a station, a derelict or an asteroid
could place the same sites. Colliders go on layer 5.

| Site | Built from | F does | Log entry |
|---|---|---|---|
| **Wreck** | 6–14 real block meshes (`hull`, `hull_wedge`, `thruster`, `armour`…) in a seeded connected blob, tilted 10–35°, sunk 30–50% into the ground, with debris around. Meshes use a weathered `material_override`, so the shared livery uniform (SLICE-1-STATUS deferred finding) is never involved. | *Read flight recorder* | A seeded ship name and a fragment of what happened |
| **Monolith** | A dark slab about 2 × 9 × 0.8 m with a glyph strip in the palette's `accent`, humming | *Touch* — it pulses and **reveals the nearest unknown site's type** | Which site it revealed, or "The monolith is silent." |
| **Crystal grove** | 8–20 tapered hexagonal crystals, `accent`-emissive, clustered over 6–12 m | *Take sample* — they chime and brighten for 3 s | A seeded crystal name |
| **Supply cache** | A 2 × 1.2 × 1.2 m container with a lid | *Open* — the lid opens | A seeded manifest of 3–5 lines, e.g. "1× unidentified reactor coil". **Information, not items**: there is no inventory yet (§18). |

Text comes from small seeded phrase tables in `site_text.gd`.

### 12.3 Site states

| State | Meaning | Marker |
|---|---|---|
| `UNKNOWN` | Detected, not identified | `?` and distance |
| `REVEALED` | Type known (a monolith told you), not visited | type glyph and name |
| `DISCOVERED` | The avatar came within **20 m on foot** | type glyph and name |
| `INTERACTED` | F used | type glyph, name, and a tick |

Flying over a site never resolves it. **You have to go and look.** Resolving shows the toast
*DISCOVERED: Crystal Grove* and writes to the log.

Markers appear for every site while the ship or avatar is inside the well. The well is the
scanner's range.

### 12.4 World state

`WorldState` (`RefCounted`) is `{seed, sites: {id → {state, log}}}`, with `to_dict()` and
`from_dict()` round-tripping. It lives in memory only. It is discarded on F9 (a new seed is a new
world) and on quit. It is shaped as *seed + changes* so claims, placed grids and removed items
become new change kinds later rather than a new model.

---

## 13. HUD

`src/ui` stays ignorant of `Planet`, `Ship` and sites (HUD spec §4.3). Everything arrives as
plain data.

### 13.1 Telemetry

`VehicleTelemetry` gains `in_gravity_well`, `altitude`, `vertical_speed`, `lift_margin`, `tilt`
and `landing_state`. They are filled by a second plain-values step,
`with_surface(basis, local_up, altitude, lift_margin, landing_state) -> VehicleTelemetry`. That
leaves `from_state()`'s signature and every existing caller unchanged, and keeps the math testable
headless. In deep space the fields stay at their zero values and `in_gravity_well` is false.

### 13.2 SurfacePanel

A new band panel between `AttitudePanel` and the band's right end, which **stays reserved** for
weapons and hull condition (HUD spec §7). It is hidden, not merely empty, outside a well.

```
ALT  12.4 M    V/S ▼ 1.8    LIFT ×1.35    TILT 4°    LANDED
```

- ALT shows one decimal below 10 m.
- LIFT turns amber below 1.2 and reads *CANNOT HOVER* below 1.0.
- TILT turns amber above 15° and reads *UNEVEN* at 25° or more.

Colours come from `HudPalette`.

### 13.3 World overlay: markers, toasts, log

These do not depend on piloting: they show on foot too. `HudRoot` fades with the active vehicle,
so they live under their own `CanvasLayer`, `WorldOverlay`, rather than under `HudRoot`.

- **`SignalMarkers`** — a second duck-typed source, `build_contacts() -> Array[SignalContact]`,
  mirrors `build_telemetry()`. `SignalContact` holds a world position, a label and a state.
  Contacts are clamped to the screen edges with chevrons using the velocity marker's existing
  clamp policy. Like every world-registered element, a second instance is mounted in the canopy
  viewport's overlay for cockpit view (HUD spec §6).
- **`ToastLine`** — `show_toast(text, severity)`, queued, 3 s each, warnings in amber. Sources:
  entering a well (*KORVA-7 · GRAVITY 5.2 M/S²*), *HARD LANDING 6.2 M/S*, *CANNOT HOVER* (on the
  way in, not every frame), the §10.4 refusals, *DISCOVERED: …*, and
  *CYCLE ABORTED*, and *WORLD RE-ROLLED · SEED 48213*.
- **`DiscoveryLog`** — Tab (new `toggle_log` action) shows a plain `DiscoverySnapshot`: world
  name, seed, gravity, sites found out of total, and each entry.

The existing `Prompt` label carries every F prompt, on board and outside.

### 13.4 Input actions

Added to `project.godot` in the `Object(InputEventKey, …)` syntax. The JSON-shaped form parses
and registers actions with **no bindings** (SLICE-1-STATUS, hard-won lessons). `test_input_map.gd`
gains each one.

| Action | Key | Physical keycode |
|---|---|---|
| `jump` | Space | 32 |
| `toggle_log` | Tab | 4194306 |
| `suit_lamp` | L | 76 |
| `debug_reroll_world` | F9 | 4194340 |
| `debug_step_out` | F10 | 4194341 |

`debug_step_out` performs the §10.5 transfer instantly, either way, while the ship is LANDED. It
lets Phase C (§20) be played before the cycle exists, and stays afterwards as a debug shortcut.

The same task deletes the malformed block at the end of `[input]` in `project.godot` (lines
77–88 at `a82dc3c`): JSON-shaped duplicates of every action under a broken section header,
introduced in `211842f`. It does nothing today, but it sits exactly where these edits go.

---

## 14. The test area

- **Placement:** one `Planet` at **(0, 0, −4500)**, dead ahead of the spawn heading. Its `seed` is
  exported, with a fixed default so the everyday test world is stable.
- **Clearances,** computed for the largest possible world (R = 1200 m, well radius 3600 m):
  - Spawn, at 4500 m from the centre, is **900 m outside** the well.
  - Interior slot 0, at (0, −5000, 0), is 6727 m from the centre, **3127 m outside** the well.
    Later slots are further away.
  - The debris field (1500 m around the origin) overlaps the well's outer edge. That is harmless:
    debris has no physics.
- At the 120 m/s cruise ceiling the surface is about 30 s away.
- **F9** picks a new seed, rebuilds the planet and toasts the seed. If the ship is inside the
  well, it is reset to spawn: origin, identity rotation, zero velocity, unfrozen, and FLYING. If
  the avatar is on EVA, it is first returned aboard at the airlock, instantly and without a
  cycle.
- The sun is re-aimed as in §7.4.
- Per CLAUDE.md, none of the `.tscn` edits carry `#` comments. Narrative goes in the scripts' doc
  comments.

---

## 15. Testing

### 15.1 Automated (GUT, headless, output pristine)

| File | Covers |
|---|---|
| `test_world_seed.gd` | Sub-seeds are stable, pinned to literal values; different concerns give different sub-seeds |
| `test_world_recipe.gd` | Same seed gives the same recipe; different seeds differ; every field stays in range across 1000 seeds |
| `test_world_terrain.gd` | `height_at` is deterministic; site flattening is level within 12 m; `altitude_of` agrees with `surface_point` |
| `test_cube_sphere.gd` | Mapping round-trips; the max-depth formula matches §6.4's figures; the leaves of any split cover each face exactly once |
| `test_terrain_chunks.gd` | Shared edge vertices of neighbouring same-depth chunks are identical, including across cube-face edges; skirts are present; no NaNs; at max depth the collision faces equal the render faces |
| `test_gravity_well.gd` | Runtime, with a probe body: surface gravity equals the recipe's value, points at the centre, falls off as inverse square, and is zero outside 3R |
| `test_flight_surface.gd` | Allocation priority; no direction ever exceeds its budget; hover with the stick centred; the levelling torque's sign and fade; levelling is skipped on axes with pilot input; lift margin |
| `test_landing_monitor.gd` | The pure `step`: every transition, hard-landing classification, and the tilt gate |
| `test_airlock_cycle.gd` | The state sequence both ways; every refusal; the hold-and-abort on unready collision; the transfer round-trips exactly |
| `test_avatar_surface.gd` | `PLATING` mode reproduces today's walk and gravity numbers (regression); `FIELD` movement stays tangent; heading survives a quarter-circumference walk; jump height ∝ 1/g |
| `test_sites.gd` | Placement is deterministic, respects spacing and slope, and follows the weights; the monolith rule; reveal and resolve transitions |
| `test_world_state.gd` | `to_dict`/`from_dict` round-trip |
| `test_hud_surface.gd` | `with_surface` math; `SurfacePanel` hidden outside a well; `SignalMarkers` contact states |
| `test_input_map.gd` | Extended with the five new actions |
| `test_ship_validator.gd` | Rule 6, passing and failing fixtures |

### 15.2 Manual playtest checklist

- Does the world read as a place from 4 km away?
- Does descent feel controlled? Does levelling help rather than fight you?
- Does a hard landing *read* as one?
- Is the airlock swap invisible? Does the environment switch as the door opens pass unnoticed?
- Is the horizon's curve visible from the ground? Does jumping on a 2 m/s² world feel different
  from jumping on an 8 m/s² one?
- Is the night side explorable with the suit lamp?
- Do ten different seeds feel like ten different places?
- Do signals make you want to go and look?

### 15.3 Scene-edit and runtime verification (mandatory)

Per CLAUDE.md, a clean headless load proves nothing. Read back from the real running
`flight_test.tscn`:

- the well's `gravity_space_override`, `gravity_point` and mask;
- the hull's `gravity_scale`, `collision_mask` and `continuous_cd`;
- the planet's position;
- the sun's basis;
- that the new input actions have bindings.

A throwaway probe also flies a scripted descent in the real scene and logs frame times and chunk
build times against §6.6's budgets. It captures screenshots for the owner:

- from spawn;
- at 500 m altitude;
- landed;
- beside each site type;
- the night side with the suit lamp on;
- from spawn for each of ten seeds.

---

## 16. Amendments to other documents

- **Slice spec §2 (slice decomposition):** a note under the table. Planetfall pulls the first
  part of Slice 6 forward, ahead of Slices 2–5: worlds you can fly to, land on and explore.
  Footholds, conquest and faction pressure stay in Slice 6.
- **Slice spec §3.3 (bounded arenas):** amended. There is still no floating origin and no
  double-precision build, but the playable space now contains worlds you fly to. Single precision
  stays accurate within about 10 km of the origin. Several worlds spread wider than that will
  need a floating origin, which belongs to the many-worlds spec. *Within* a system you fly;
  *between* systems, Slice 5's sector map remains the jump layer. It also records a second
  transition that must not be seen: the airlock step-out (§10).
- **Slice spec §12 (non-goals):** a note. "No planets" remains true of Slice 1 itself; planets
  arrive in this separate slice.
- **Slice spec, roadmap appendix, Slice 6:** a pointer to this document.
- **Piloting HUD spec §10 (extension points):** the surface fields arrive via `with_surface()`;
  a `SurfacePanel` joins the band, whose right end stays reserved; and a second duck-typed source,
  `build_contacts()`, feeds world markers independently of vehicle arming, under a separate
  `WorldOverlay` layer.

---

## 17. Risks

| Risk | Mitigation |
|---|---|
| **Chunk generation too slow in GDScript** | Worker threads, and §6.6's budgets are measured by the probe. Fallback: 12 × 12 chunks, then a C# port of the two hot files. |
| **The hull tunnels through the terrain** | Continuous collision detection, collision chunks with speed lookahead, and the analytic safety net (§8.5). |
| **The ship jitters resting on a trimesh during TOUCHING** | It freezes once LANDED, so only the one-second touching phase is exposed. If that still jitters, evaluate Jolt, which is a single project setting. |
| **The airlock swap is visible** | Same props, same frames, the dark beat, and the environment switch timed to the door. Judged in playtest. Fallback: a brief fade at the dark beat, still inside the cycle. |
| **Thrust becomes positional** (slice spec §7.1 intends it; today `FlightComputer` applies thrust centrally) | The starter's vertical RCS are all at the nose, so a positional hover would pitch it over. Whoever makes thrust positional must re-balance the starter's vertical RCS first. |
| **The interior redesign's pieces change under Phase D** | Only §10's cycle depends on them, and Phases A–C (§20) do not. They merged in `77c58a7`, and Phase D's plan tasks must read `InteriorLayout`, `SlidingDoor` and `InteriorProps` as they stand at that point rather than as this document describes them. |
| **The gravity cap strands a heavier ship** | The lift margin is shown and the cap is one constant. Revisit when the shipyard lets ships grow. |
| **Portholes show stars while landed in daylight** | A known trade-off inherited from redesign §10. A world-aware porthole sky is a follow-up. The cockpit windows show the real surface. |

---

## 18. Hooks left deliberately open

- **Encounters:** any site type can later spawn actors. Terrain anchors give NPCs collision and
  the gravity well gives them gravity, both for free. `SignalContact` already carries a state
  that can say *hostile* or *friendly*.
- **Claiming:** `WorldState` is seed plus changes, so a claim beacon is one new change kind. An
  outpost is a `ShipGrid` that never flies: `ExteriorBuilder` under a `StaticBody3D`, standing on
  terrain.
- **Enclosed places:** a derelict's interior, a cave or a bunker can be an **interior slot
  entered through an airlock-style transfer**. §10.5's transform math does not care whether the
  exterior side is a ship.
- **Items:** a cache's manifest is written as items so that an inventory can take them literally
  later.
- **Many worlds:** `Planet` does not depend on its position, world context is per body, and
  sub-seeds are stable. A `SystemRecipe.from_seed()` places several.
- **Saving:** `WorldState.to_dict()` and `GENERATOR_VERSION`.

---

## 19. Non-goals

- Encounters, NPCs, AI.
- Claiming.
- More than one world; a system map.
- Saving to disk.
- Inventory, resources, crafting.
- Caves, overhangs, digging, voxels.
- Oceans or liquids.
- Planet spin or orbits.
- Weather.
- Atmospheric drag, lift or heat.
- Block damage.
- Geomorphing between levels of detail.
- Landing-gear blocks.
- Ship refit.

---

## 20. Build order

Each phase ends playable, as in Slice 1:

- **Phase A — the world, visible:** seed, recipe, palettes, names, terrain, cube-sphere, render
  quadtree, `Planet`, atmosphere, sun, test-area placement, F9. *Fly around a world.*
- **Phase B — touching it:** gravity well, collision chunks, flight assist in a well, landing
  monitor, surface telemetry and `SurfacePanel`, toasts. *Land on it.*
- **Phase C — on foot, finding things:** the avatar's up vector, jump and lamp; the §10.5
  transfer and EVA wiring, triggered by `debug_step_out` (F10) while LANDED, standing in for the
  cycle; then sites, builders, markers, resolution, interactions, `WorldState` and the discovery
  log. *Walk on it and find things.*
- **Phase D — the airlock cycle,** built on the merged interior redesign: the airlock zone, locked
  doors, the exterior alcove, `AirlockControl`, `AirlockCycle`, and Rule 6. `debug_step_out`
  stays as a debug shortcut. *Walk out of your own airlock onto it.*

---

## 21. Definition of done

Launch `flight_test`. A world is visible ahead. Fly to it. The HUD announces its name and gravity
and shows ALT, V/S, LIFT and TILT. Descend under assist; the ship levels itself below 150 m. Land.
A hard landing is flagged.

Stand up, walk aft, cycle the airlock without seeing the swap, and step onto the surface. Walk and
jump around the curve under that world's gravity. See `?` markers; walk to them; watch each
resolve; use each site type; read it back in the log.

Walk back, cycle in, sit down, take off, and leave the well. Press F9 and do it again on a
different world.

The GUT suite is green with pristine output, and §6.6's performance targets are met on the
GTX 960.
