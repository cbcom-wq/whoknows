# Asteroids — rocks you can touch, streamed in before you see them

**Date:** 2026-09-24
**Status:** Design approved section by section on 2026-09-24; this document awaits the owner's
review before planning.
**Depends on:** `main` at `c79402f` (hands and items, the airlock and the spacewalk, the
ship-and-space item set)
**Governed by:** `docs/design/visual-style.md`
**Supersedes:** `DebrisField` (`src/world/debris_field.gd`), removed in build step 3.
**Amends:** slice spec §3.3 (no floating origin); Planetfall §4.2, §6.4, §14 and §16; airlock
spec §7.4; the visual style guide (§12 here)

---

## 1. Why

The owner: "Currently I think the asteroids are just visuals. There is no physics with them they
aren't objects. We want asteroids to be part of the game, touch-able interactive. And we want to
be careful with trying to spawn and track every asteroid in the universe at once. They will need
to be spawned programmatically and pseudo-randomly off the horizon. The user never sees them
spawn but they are there before the user has a chance to see them, not just always present
though taking up processing and memory."

Today's asteroids are one `DebrisField`: a fixed `MultiMesh` of 700 copies of one rock, 5–40 m
across, in a 1.5 km ball around the origin, with no collision. The ship crosses it in seconds (it
cruises at 120 m/s and boosts to 300 m/s) and can fly on for ever into nothing. Past about 10 km
from the origin, single-precision positions start to shimmer, and the project has no floating
origin.

"How objects act in space" is the owner's next topic. This spec comes first and leaves that open.

---

## 2. Decisions

| Question | Choice | Why |
|---|---|---|
| What touching a rock does | **Solid and pushable** | The ship and a spacewalker collide with rocks; mass is real, so rubble gets shoved and giants are walls. No damage, breaking or grabbing: those overlap Slice 2 and items in space. |
| Where a pushed rock is when you come back | **Back in its seeded place** | Untouched regions cost nothing while you are away, and nothing about touched rocks is remembered once their region unloads. Simplest and cheapest; a sharp-eyed player might notice. |
| How rocks are spread | **Fields with gaps** | A seeded density map of dense cores, thin fringes and empty space, so flying somewhere feels like arriving somewhere, and the gaps are cheap. |
| How far you can fly | **Floating origin, built first** | Streaming only matters if you can travel. The owner was unsure what it feels like, so it is built and flown on its own before anything depends on it. It should feel like nothing. |
| Sizes | **Rubble to mountains** | 1–5 m rubble you can shove, 5–40 m mid-size like today, 40–300 m giants that dominate a field. Pushing feels different at each scale. |
| Untouched rocks | **Still until touched** | A field is a steady landmark and a clear sense of your own speed. Touching one brings it alive, which reads as a real consequence. No new shader. |
| Architecture | **Tiered cells: pictures far, sleeping bodies near** | Rocks exist cheaply well before they are visible, and only the few you could touch cost anything. The same shape as Planetfall's terrain streaming. |

Rejected architectures: every nearby rock as a full physics node (thousands of nodes; short view
distance); rocks generated on the GPU with CPU copies for physics (the generator written twice,
in two languages that must agree to the bit, plus a new shader).

---

## 3. Architecture

```
FlightTest
├── Universe                 NEW: where the engine origin is in the universe; shifts it
├── AsteroidStream           NEW: loads cells, draws pictures, promotes bodies
│   ├── Pictures             per tier: blocks of MultiMeshes
│   └── Bodies               AsteroidBody pool, live bodies
├── Ship
│   ├── Exterior             in group exterior_space and space_anchor
│   └── Interior             never shifts
└── Outside                  spacewalkers: in exterior_space and space_anchor while outside
```

- **`Universe`** knows the universe position of the engine origin, watches the **focus** (the
  hull, or you on a spacewalk), and shifts the origin when the focus strays 2 km from it (§4).
- **`AsteroidRecipe`** is a pure function from `(seed, tier, cell)` to that cell's rocks. It
  makes no nodes, so it runs on worker threads and is tested headless (§5).
- **`AsteroidStream`** keeps the cells around the focus loaded, draws them as batched pictures
  (§6), and turns rocks near an anchor's path into sleeping physics bodies (§7).
- **`AsteroidBody`** is a pooled `RigidBody3D`: one rock, touchable.

### 3.1 Files

```
src/world/
  universe.gd             Universe: origin, focus, shift, UniversePoint conversion
  universe_point.gd       UniversePoint: a 64-bit position in the universe
  asteroid_recipe.gd      AsteroidRecipe: density, tiers, one cell's rocks
  asteroid_rock.gd        AsteroidRock: one rock's data (no node)
  asteroid_stream.gd      AsteroidStream: cells, blocks, the physics bubble
  asteroid_body.gd        AsteroidBody extends RigidBody3D
  rock_mesh.gd            RockMesh: the base rock shapes, extracted from DebrisField
  space_palette.gd        SpacePalette: rock colours
```

Modified: `ship.gd`, `avatar.gd`, `motion_coupling.gd`, `airlock_show.gd`, `flight_test.gd`/
`.tscn`, `project.godot`, `synth.gd`, and the tests in §11.1. Removed: `debris_field.gd`.

### 3.2 Physics layers

`project.godot` names layer 7 `asteroids` (bit 64). Layer 4 (`terrain`) stays Planetfall's.

| Body | `collision_layer` | `collision_mask` |
|---|---|---|
| `AsteroidBody` | 64 | 1 hull, 4 avatar, 32 items, 64 asteroids = **101** |
| Hull (`Ship.exterior`) | 1 | 1, 64 = **65** |
| Avatar, on a spacewalk (`Avatar.SUIT_MASK`) | 4 | 1, 32, 64 = **97** |

Aboard, the avatar's mask is unchanged: the interior is its own space and never meets a rock.

---

## 4. The floating origin

### 4.1 Universe positions

A `UniversePoint` is a position in the universe: three 64-bit integer metres (GDScript `int`)
and a `Vector3` fraction in [0, 1). `Universe` holds `origin: UniversePoint`, the universe
position of the engine's (0, 0, 0). Because the origin only ever moves in whole kilometres, it is
always exact.

- `Universe.to_universe(p: Vector3) -> UniversePoint` and `to_engine(u: UniversePoint) -> Vector3`
  convert exactly both ways for any point within 100 km of the origin.
- The asteroid grid, the seed and the start position only ever see `UniversePoint`s. A shift
  changes no cell.

### 4.2 The focus and the shift

- **The focus** is `Ship.exterior` while you are aboard and the avatar while it is on a
  spacewalk. `Universe.set_focus(body)` is called by `Ship` and by `Avatar.enter_suit` and
  `enter_plating`.
- **When:** at the start of a physics tick, if the focus is more than **2 km** from the engine
  origin on any axis.
- **By how much:** `delta` is the focus's position rounded to the nearest whole kilometre on each
  axis. `origin` moves by `delta`.
- **What moves:** every node in group `&"exterior_space"` gets `global_position -= delta`, in one
  pass, before the physics step: the hull (and with it the chase camera, the alcove, anything
  parented to it), the spacewalker (and whatever is in its hands), the asteroid pictures and
  bodies. Linear and angular velocities are untouched, so nothing moves relative to anything else.
- **Then** `Universe.shifted(delta: Vector3)` fires, for anything that remembers an engine-space
  position instead of being moved.
- **What never moves:** the interior and everything in it. It is not in the group.
- **Members are shifted themselves, never through a parent.** A member's parent never moves (the
  scene root, `Ship`, `Outside`, the stream), so its own coordinates stay small. Shifting a parent
  instead would leave its children's local coordinates growing without limit, which is the
  precision problem again. So each picture block and each body is a member, not the node that
  holds them.

### 4.3 World-space effects

`GPUParticles3D` with `local_coords = false` cannot be moved once emitted. The hull copy of the
airlock's outward burst (`AirlockShow._burst`) is one. The shift **waits while any exterior
world-space effect is alive** (group `&"holds_origin_shift"`, at most its lifetime, about 1 s),
and is forced regardless at 4 km. Precision is still sub-millimetre there.

### 4.4 The rule for everything after this

Anything in exterior space either joins `&"exterior_space"` or listens to `Universe.shifted`.
A test walks the flight scene and fails if a `PhysicsBody3D` or `GeometryInstance3D` outside the
interior is neither a member nor under one. Directional lights are exempt: only their direction
matters. Planetfall's worlds, other ships and items in space all
follow this rule.

### 4.5 Verified before anything builds on it

Build step 1 ends with a live check and the owner flying it (§11.2):

- Fly 50 km at boost past today's debris field (which joins the group in step 1).
- Every shift frame is compared with its neighbours: the image difference at a shift is no larger
  than between ordinary frames.
- Frame times are logged: no frame over 33 ms.
- A spacewalk crosses a shift.

---

## 5. The recipe

### 5.1 Tiers and cells

| Tier | Diameter | Cell | Most rocks per cell | Base shapes | Triangles per shape |
|---|---|---|---|---|---|
| Rubble | 1–5 m | 200 m | 24 | 2 | about 20 |
| Mid | 5–40 m | 1 km | 12 | 2 (+1 veined) | about 80 |
| Giant | 40–300 m | 5 km | 3 | 2 (+1 veined) | about 320 |

- Each tier's cell is exactly 5× the one below, so every cell sits inside exactly one cell of
  each larger tier.
- Diameters within a tier lean small: `d = d_min × (d_max / d_min)^(u²)`, `u` uniform in [0, 1).

### 5.2 Fields with gaps

- **Density** in [0, 1] comes from 3D simplex noise (`FastNoiseLite`, features about 15 km
  across), sampled at each cell's centre in universe kilometres and shaped with
  `smoothstep(0.35, 0.75, n)`.
- A cell's count is `round(density × most_per_cell)`. Giants need density over 0.7, so they
  appear only in the cores.
- Target proportions, tuned by flying: about a third of space in fields, about half empty, the
  rest thin fringe.
- `AsteroidRecipe.density_at(u: UniversePoint) -> float` is the one place density is decided.
  It is the hook for keeping fields away from worlds later (§13).

### 5.3 One cell, same rocks, every time

- A cell's generator is a `RandomNumberGenerator` seeded with `mix(seed, tier, cx, cy, cz)`, a
  splitmix64-style integer hash written in GDScript. Engine `hash()` is not used, because it is
  not promised to be stable between engine versions.
- Each rock (`AsteroidRock`): position within the cell, orientation, diameter, per-axis stretch
  (0.75–1.25), base shape, colour index, and mass.
- **Each cell is independent**, so cells can be generated in any order, on any thread.

### 5.4 No rock overlaps another

Overlapping rigid bodies fly apart violently, so the recipe guarantees none:

- **Inside its cell:** a rock's centre stays at least the tier's largest bounding radius from the
  cell's faces.
- **Within a cell:** a candidate is rejected if its bounding sphere touches an earlier rock's.
  The bounding radius is 0.7 × diameter × largest stretch, covering the shape's jitter.
- **Across tiers:** a candidate is rejected if it touches a rock of the one larger-tier cell of
  each tier that contains it. Those cells are generated first (cached).
- A rejected candidate is simply not placed: a crowded cell ends up with fewer rocks.

### 5.5 Mass

`mass_kg = 840 × diameter³ × stretch.x × stretch.y × stretch.z`: rock at about 2,000 kg/m³,
less voids.

| Rock | Mass | Against the 42 t starter shuttle |
|---|---|---|
| 1 m rubble | about 0.8 t | the ship brushes it aside; a spacewalker nudges it |
| 5 m | about 105 t | the ship bounces off and shoves it |
| 40 m | about 54,000 t | effectively a wall |

### 5.6 The start

The flight test starts at the edge of a field so rocks are in view from the first frame. The
start is found by a fixed search: the first universe point along +z from the universe origin,
stepping 500 m, whose density is between 0.3 and 0.6. Every tier keeps a 150 m bubble around the
start clear.

---

## 6. Streaming and pictures

### 6.1 Load well beyond sight

| Tier | Fades in between | Loads within | Unloads beyond | Head start at 300 m/s |
|---|---|---|---|---|
| Rubble | 600 → 450 m | 900 m | 1.1 km | 1 s |
| Mid | 4 → 3 km | 5 km | 5.5 km | 3.3 s |
| Giant | 20 → 15 km | 25 km | 30 km | 16.7 s |

- Distances are from the focus.
- **The head-start rule** (tested): for every tier, load radius − fade start ≥ 300 m/s × 1 s.
- At the far edge of its fade, a tier's largest rock is about 5–8 pixels across at 1280 × 720
  with the default 75° field of view.
- **The fade** is `StandardMaterial3D`'s built-in distance fade (`DISTANCE_FADE_PIXEL_DITHER`,
  reversed so it fades out with distance), one material per tier. No new shader.
- **The first load** happens synchronously before the first frame is drawn, so nothing pops in
  at the start.

### 6.2 Pictures are batched

- A tier draws its rocks in **blocks** the size of the next tier's cell: rubble in 1 km blocks,
  mid-size in 5 km blocks, giants in 25 km blocks.
- A block has one `MultiMeshInstance3D` per base shape (§5.1), with per-instance colour. Each
  rock's own stretch, rotation and colour give variety at no extra draw calls.
- A block is written with one bulk buffer assignment, built off the main thread. A promoted
  rock's slot is hidden with a zero transform.
- Blocks off-screen are culled whole.
- Each block is an `&"exterior_space"` member (§4.2).
- Render layer 1, like everything outside.

### 6.3 Loading does not stall the game

- Each cell's recipe runs as a `WorkerThreadPool` task, with its own `FastNoiseLite` (none shared
  across threads).
- Cells are queued nearest first, and ahead of the focus's velocity first.
- The main thread applies finished blocks within **2 ms a frame**.
- A generation counter drops results that went out of date while they were building.

### 6.4 Budgets

- **Frame rate:** steady 60 fps at 1280 × 720 on the GTX 960 target, measured in the worst case:
  a dense core, seen through the canopy (aboard, the outside renders a second time for the
  windows) and on a spacewalk.
- **Streaming:** no frame over 33 ms; applying results at most 2 ms a frame.
- **Memory:** about 64 bytes per loaded rock. A dense core at full load is about 16,000 rocks,
  about 1 MB.
- **Shadows:** every rock receives the sun's shadow. Bodies cast shadows; picture batches do not,
  except the giant tier. Confirmed by measuring.

---

## 7. The physics bubble

### 7.1 Anchors

Bodies in group `&"space_anchor"` touch rocks: the hull always, and the avatar while on a
spacewalk (it joins and leaves in `enter_suit`/`enter_plating`). Later, items in space and other
ships join. An anchor offers `anchor_radius() -> float` (the hull: its bounding sphere; the
avatar: 1 m).

### 7.2 Which rocks become bodies

Every physics tick, a rock becomes a body if its bounding sphere comes within **24 m +
`anchor_radius()`** of the segment from the anchor's position to its position 1.5 s ahead at its
current velocity. At boost that capsule reaches about 450 m ahead. It only ever holds the
handful of rocks you could hit. Only cells overlapping the capsule's bounds are searched.

### 7.3 Becoming a body

`AsteroidBody` (a pooled `RigidBody3D`, in `&"exterior_space"`):

- Placed at the rock's exact transform. Its picture slot is hidden, and its own `MeshInstance3D`
  shows the same shape, stretch and colour. **Nothing visibly changes.**
- **Shape:** a `ConvexPolygonShape3D` from the base shape's hull points, stretched and scaled to
  the rock.
- **Mass** from the recipe. `PhysicsMaterial`: friction 0.6, bounce 0.2. No damping.
- **Starts asleep:** `can_sleep = true`, `sleeping = true`. It costs nothing until something
  touches it, then it answers with its real mass, never as an immovable wall.
- `continuous_cd = true` for rubble.

### 7.4 Going back to being a picture

- **Untouched:** out of every anchor's capsule for 2 s, and still where it was placed → back to
  the pool; its picture slot is shown again, in the same place.
- **Touched:** once a body has moved 1 cm or turned 0.5° from home, it is **adrift**:
  - It never becomes a picture again.
  - Its home slot stays hidden while its cell is loaded.
  - It is dropped only when it is beyond its tier's fade-out distance from the focus, so it is
    never seen to vanish.
  - When its cell unloads, its home is forgotten. Next time the cell loads, the rock is back in
    its seeded place (§2).
  - At most **96** adrift bodies. Over the cap, the farthest from the focus is dropped first,
    with a logged warning.

### 7.5 The ship

- `Ship.exterior.continuous_cd = true`. At 300 m/s the hull moves 5 m a tick: without it, it
  passes through rubble.
- No damage (Slice 2). A hit rocks the ship; the flight computer's assist steadies it as it does
  after any disturbance.
- **Aboard, you feel it, within limits.** `MotionCoupling`'s shove is capped at **12 m/s²**
  (normal flight peaks near 5.7 m/s² felt, so flying is unchanged). Acceleration beyond the cap
  becomes a short, sharp camera jolt through the existing shake. Loose items feel the same capped
  shove through `FeltGravity`.
- **A thump:** a hull strike plays a synthesized low thump (`Synth`, new sound `hull_thump`)
  through the Ship bus, louder for harder hits (by the rock's relative speed along the contact).
  Style guide §2.9: aboard you hear the hull; outside stays silent.

### 7.6 On a spacewalk

The avatar is a `CharacterBody3D`, so bumps are resolved by hand, like two bodies in space. On
each slide collision with an `AsteroidBody`:

- The avatar with suit counts as **120 kg**. With `v` the closing speed along the contact
  normal, `m = 120 × m_rock / (120 + m_rock)`, and bounce 0.2, the rock gets the impulse
  `1.2 × m × v`, and the avatar's velocity changes by the opposite impulse over 120 kg.
- A 1 m rock drifts off slowly; a giant stops you dead.

---

## 8. The look

Following the style guide's "chunky low-poly shapes in flat colour":

- **Shapes:** `RockMesh` builds faceted, flat-shaded rocks with hard edges (per-face normals, as
  `DebrisField` does now), chunkier than today's, not spiky. Two base shapes per tier: a rounded
  boulder and a longer, angular one. Detail rises with size (§5.1).
- **Veined rocks:** about 1 in 10 mid-size and giant rocks use a third, veined shape with a few
  faces in lavender, drawn in vertex colour: the source of the rock sample aboard. Flat colour,
  lit by the sun, no glow.
- **Colour:** a new `SpacePalette` beside `HullPalette`: dusty, warm greys and browns (ash,
  umber, slate, rust, sand) and the lavender. Each rock takes one as its instance colour; the
  veined shape's instance colour is white, so its vertex colours carry. Pinned by rendering.
- **Light:** the sun, as the outside is lit today. Render layer 1.

---

## 9. Scene changes

- `flight_test.tscn`: adds `Universe` and `AsteroidStream`; removes `DebrisField` in step 3. Per
  `CLAUDE.md`, no `#` comments in the `.tscn`; every scene edit is verified by reading its
  properties back at runtime.
- `Ship`: the hull joins `&"exterior_space"` and `&"space_anchor"`, sets its focus, and gets
  `continuous_cd`.
- The flight test starts the ship at the start point (§5.6), converted to engine space.

---

## 10. Implementation notes

- **`DebrisField` in step 1:** it joins `&"exterior_space"` so the first flight test has
  something to see shift. It is removed in step 3.
- **Worker safety:** `AsteroidRecipe` touches no nodes and no shared state; each task gets its own
  noise and generator.
- **Cell arithmetic:** cell indices come from `UniversePoint`s in 64-bit integers, never from
  engine floats, so a cell is the same cell at any distance.

---

## 11. Testing

### 11.1 Automated (GUT, headless, output pristine)

**Universe (`test_universe.gd`)**
- `to_universe`/`to_engine` round-trip exactly, and a shift changes no universe position.
- The shift fires past 2 km, not before, and rounds to whole kilometres.
- The shift moves every `exterior_space` member by `delta`, leaves the interior alone, and keeps
  linear and angular velocities.
- `shifted` fires with `delta`.
- The shift waits while a `holds_origin_shift` member is alive, and is forced at 4 km.
- **Coverage:** walking the flight scene finds no physics body or geometry instance outside the
  interior that is neither a member nor under one (directional lights exempt).

**Recipe (`test_asteroid_recipe.gd`)**
- The same `(seed, tier, cell)` gives identical rocks; a different seed or cell gives different
  ones.
- Every rock lies inside its cell by the tier's margin.
- No overlaps within a cell or across tiers, checked over thousands of cells.
- Over a large sample, both empty cells and full cells occur, and giants only where density is
  over 0.7.
- The start bubble is clear in every tier.
- The mass formula holds.
- The head-start rule holds for every tier.

**Stream (`test_asteroid_stream.gd`)**
- Cells load within the load radius and unload beyond the unload radius, with no flicker when
  hovering at the boundary.
- A result superseded while building is dropped.
- The first load completes before the first frame.
- A hidden slot has a zero transform; a restored slot has its rock's transform.

**Bodies (`test_asteroid_body.gd`)**
- The capsule picks rocks near the anchor's path, and not those behind or beside it.
- A promoted body starts asleep, at the rock's exact transform, with its mass, and its slot is
  hidden.
- An untouched body demotes after 2 s outside every capsule and its slot comes back.
- Moving 1 cm or turning 0.5° makes a body adrift. An adrift body keeps its home hidden, is
  dropped only beyond its fade distance, and the cap drops the farthest first.
- A home is forgotten when its cell unloads.
- Layers and masks are as in §3.2.

**Crashes (`test_motion_coupling.gd`, `test_avatar_modes.gd`)**
- The shove is capped at 12 m/s², and the excess becomes a jolt.
- A spacewalk bump shares momentum as in §7.6.

**Style (`test_visual_style_rules.gd`)**
- Rock and palette files take colours from `SpacePalette` only.

### 11.2 Live checks (mandatory, renders shown to the owner)

- **Step 1:** the floating-origin flight in §4.5, then the owner flies it before step 2 starts.
- **Flight:** 50 km at boost through fields, with frame times logged. Two counts must be zero:
  frames over 33 ms, and **late cells** (a cell applied after the focus was already inside its
  fade-start distance).
- **Crashes:** ram rubble, a mid-size rock and a giant with the ship, logging both velocities
  before and after. Push rubble on a spacewalk.
- **Renders:** from the chase camera, through the canopy, and at 1.6 m eye height beside a rock on
  a spacewalk. Green tests prove structure, not looks.

### 11.3 Playtest checklist

- Fly into a field: rocks are there before you notice them arrive.
- Fly through a gap: space thins out and fills in again.
- Clip a rock of each size: rubble scatters, a mid-size rock shoves and bounces you, a giant stops
  you, and aboard you hear and feel it without being flung across the room.
- Spacewalk to a rubble rock and bump it; bump a giant.
- Fly far at boost: nothing shimmers, jumps or hitches.

---

## 12. Amendments to other documents

- **Slice spec §3.3:** there is now a floating origin (§4). Exterior space is re-centred on the
  focus every 2 km; the interior never moves.
- **Planetfall §4.2 (physics layers):** layer 7 is `asteroids`.
- **Planetfall §6.4:** terrain anchors and space anchors are the same bodies; Planetfall uses
  `&"space_anchor"` rather than a group of its own.
- **Planetfall §14 and §16:** worlds are placed by `UniversePoint` and join `&"exterior_space"`.
  The note that the debris field overlaps the well's edge harmlessly no longer applies. Density
  near a world is decided by `density_at()` (§13).
- **Airlock spec §7.4:** on a spacewalk the collision mask adds asteroids (§3.2), and the avatar
  joins `&"exterior_space"` and `&"space_anchor"` and becomes the focus.
- **Visual style guide:** a new section, *Rocks in space*: faceted flat-shaded rocks from
  `RockMesh`, colours from `SpacePalette` only, a distance-dither fade from the tier's fade band,
  render layer 1, no new shader. §5 adds the rock and palette files to the colour rule.
  **Approving this spec is the owner's approval of that rule change.**

---

## 13. Later, not built

- Grabbing, holding or carrying rocks; items in space (the owner's next topic).
- Damage, chipping and breaking rocks (Slice 2).
- Remembering touched rocks after their region unloads; saving the universe position to disk.
- Other ships (they join `&"exterior_space"` and `&"space_anchor"`).
- Keeping fields clear of Planetfall's worlds: `density_at()` is the hook.
- Slow tumbling of untouched rocks (a GPU shader).

---

## 14. Risks

| Risk | Mitigation |
|---|---|
| Something outside keeps a stale engine position across a shift | The group rule and its coverage test (§4.4); world-space effects hold the shift (§4.3); the live shift-frame comparison. |
| GDScript generation is too slow at boost | Worker threads, nearest and ahead first, the head-start rule, the late-cell count; fallbacks: fewer rocks per rubble cell, then a C# recipe (the project runs the .NET build). |
| Too many draw calls or triangles on the GTX 960 | Blocks culled whole, two shapes per tier, shadows only on bodies and giants; measured in the worst case (§6.4). |
| The hull tunnels through rubble at boost | `continuous_cd` on the hull and rubble; a crash test at boost. |
| A crash flings you across the room | The 12 m/s² shove cap and the jolt (§7.5). |
| Promoted bodies overlap and explode apart | The recipe guarantees no overlaps (§5.4), tested over thousands of cells. |
| Precision of the density noise far from the universe origin | Density is sampled at cell centres in kilometres; 15 km features need no finer precision. |

---

## 15. As built (plan 1: the floating origin, 2026-09-24)

- The focus is set by `flight_test.gd` (the scene bootstrap) on `Avatar.mode_changed`, rather
  than by `Ship` and `Avatar` as §4.2 had it: neither needs to know about `Universe`. The hull
  and the spacewalker join `&"exterior_space"` themselves.
- `F3` in the flight test toggles a readout of your universe position and the shift count.
- **Live check (§4.5),** real scene, windowed, chase camera, a marker cube every 400 m:
  - 50 km at 1 km/s (25 shifts) and 10 km at 300 m/s (5 shifts). Every marker's motion relative
    to the hull across a shift tick matched an ordinary tick to float noise (2.6 mm at 1 km/s,
    under 2 mm at 300 m/s).
  - The image change at shift frames (max 0.0031) stayed below ordinary frames near a shift
    (mean 0.0059–0.0105, max 0.0195).
  - Frame times with no captures running: 1,440 frames through 11 shifts, none over 33 ms, every
    shift frame 16.7 ms (one vsync).
  - A spacewalk beside the ship at 300 m/s across 2 shifts: 0.1 mm drift from the ship, 0.1 mm
    change in distance to the airlock beacon.

---

## 16. As built (plan 2: the asteroids, 2026-09-24)

Deviations from the design above, each found by testing or the live check:

- **Density** thresholds are set from the noise's own spread: `DENSITY_LOW` 0.50 (its median) and
  `DENSITY_HIGH` 0.67 (its 90th percentile). Over 3,600 mid cells: 47% empty, 13% core.
- **Counts** are 40 rubble and 16 mid-size rocks per cell at most (the design said 24 and 12):
  at 24 the nearest rubble was about 70 m apart, and the field read as specks.
- **The start** is inside a field (density 0.55 to 0.85), not at its edge, with 80 m cleared
  rather than 150 m, so rocks are near and far from the first frame.
- **Mass** is capped at 10^8 kg for the physics solver (`AsteroidBody.MASS_CAP`); anything that
  heavy is a wall to anything that can hit it.
- **The wanted set** is redone every quarter cell of travel, not on crossing into a new cell:
  between crossings you can close up to a cell's diagonal on a cell before it is asked for, which
  is more than the head start. It runs on a worker thread, nearest and ahead of you first; the
  main thread only swaps the result in. The "generation counter" is this: a result is dropped if
  its cell is no longer wanted.
- **The stream keeps a copy of each block's buffer.** Without a renderer the engine hands no
  MultiMesh instance data back, and the tests run headless. The live check compared the copy with
  the real renderer's data over 1,948 instances: identical.
- **A new body is placed before it enters the tree.** Placed after, it stood at its holder's
  origin, usually right where you are, until transforms flushed, and could knock you for a tick.
- **A spacewalk bump counts once per rock per step** (`Avatar.bump`): sliding along a rock can
  touch it twice in one step, and pushed it twice.
- **The thump's loudness** comes from the hull's own change of speed: what you feel.

**Live check (§11.2),** windowed, real scene:

| Check | Result |
|---|---|
| 20 km at 300 m/s through a field core | 0 late cells; 3,995 frames, mean 16.7 ms; one frame over 33 ms (the first after switching to the chase camera, an engine cost of a new view, not streaming); up to 30 bodies at once |
| Streaming cost at boost (timing probe) | worst update 7.6 ms, worst bubble tick 2.3 ms, no frame over 30 ms |
| Ram a 1.9 m rubble rock (5 t) at 60 m/s | hull 60 → 56 m/s; the rock flung ahead at 62 m/s |
| Ram a 20 m rock (6,459 t) | the hull bounces back at about 11 m/s; the rock 0.6 m/s |
| Ram a 46 m giant (75,657 t) | the hull bounces back at about 9 m/s; the giant 0.04 m/s |
| Aboard, each crash | shove capped at 12 m/s², a head jolt of 5 cm, and the thump |
| Spacewalk bump into a 1.4 m rock (2.1 t) at 2 m/s | momentum shared exactly: you rebound (a 2.1 m/s change), the rock drifts off at 0.12 m/s, 254 kg·m/s each |
| Floating origin across the flight | 10 shifts, nothing out of place |

The unit suite grew from 599 to 646 tests and from about 30 s to about 65 s: every test that
loads the flight scene now streams its asteroids.

---

## 17. Amended 2026-09-24: groups, not fields

After flying it, the owner: "I feel there are too many small asteroids and don't see many big ones.
I'd rather have fewer asteroids where you have to fly a bit to reach them but then be meaningful
once there. Maybe they are grouped where you have a really big one with little ones around it."
They chose groups mostly 3–6 km apart, a big rock of 150–600 m, and a thin sprinkle between.
This replaces §5.1's giant row, §5.2 (fields with gaps) and §5.6 (the start); the rest of §5 and
all of §6–§7 stand.

**Groups.** Each giant cell, a 5 km region, holds at most one big rock, 150–600 m across. Whether
it does is a chance the density noise sets (`AsteroidRecipe.group_chance`: the noise shaped by
`smoothstep(0.42, 0.6, ...)`). Measured over 1,728 regions: 47% hold a group; the nearest group
is a median 3.8 km away (10% under 2.7 km, 10% over 5.1 km).

**Little ones round each big rock.** A mid-size or rubble candidate is kept with a chance that is
the sprinkle plus, for every big rock near, `0.6 × exp(-height / radius)` for heights above its
surface up to four of its radii. So:

- rubble is thickest just off the surface: 12 per 200 m cell there, against 0.4 in open space;
- a 150 m rock gets a light swarm and a few moons; a 600 m one a cloud of thousands and a few
  dozen moons;
- between groups, only the sprinkle: a stray piece of rubble every 270 m or so, a stray mid-size
  rock every 1.5 km.

A candidate is drawn where it would sit, then kept or not, then its other draws taken; a kept
candidate takes all its draws whether or not it fits, so an overlap never reshuffles the rest.
A cell looks for big rocks in its own region and the neighbours a halo could reach from.

**Seen from far.** Big rocks fade in from 25 km to 20 km and load within 30 km (unload 35 km).
The cameras outside -- the chase camera, the canopy's and yours on a spacewalk -- see to 30 km
(`AsteroidStream.VIEW_FAR`): they had Godot's default of 4 km, so no giant past it had ever
been drawn.

**The start** is 700 m off the surface of the first big rock along +z from the universe's
origin, on its +z side: dead ahead of a ship facing -z, with its swarm round it, and 80 m clear.

**Live check,** windowed, real scene: from the pilot's seat the start is a big rock ahead with
its rubble round it; 20 km at boost across groups had 0 late cells and one frame over 33 ms (the
first after switching to the chase camera); at most 3 rock bodies at once between groups. At
60 m/s the ship brushes 1 m rubble aside, bounces off a 10 m moon (737 t) at about 4 m/s, and off
a 434 m big rock at about 9 m/s; each felt aboard, capped, with the jolt and the thump. A
spacewalk bump shares momentum exactly (246 kg·m/s each way).

**Cost.** A rubble cell's recipe takes about 0.6 ms (it looks for big rocks round it); the flight
scene's first load takes about 0.8 s, against 0.6 s before. The unit suite takes about 97 s.

