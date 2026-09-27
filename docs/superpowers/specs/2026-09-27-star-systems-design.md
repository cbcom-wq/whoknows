# Star systems — a galaxy of toy-scale systems, generated with hand-made worlds sprinkled in

**Date:** 2026-09-27
**Status:** Direction agreed with the owner on 2026-09-27 (§2), and the follow-up questions
answered the same day (§13). This is an umbrella design: it sets the shape of the universe and
splits it into pieces (§12), each of which gets its own spec → plan → build cycle. The numbers here
are first guesses to be tuned by flying. Two questions stay open (§13).
**Depends on:** `main` at `1d23261` (the floating origin and asteroids, saving, the bridge computer)
**Relates to:** asteroids spec §5.2 (`density_at`), §5.6 (the start), §13; Planetfall §3, §7, §14,
§18 (*Many worlds*); saving spec §3; bridge computer spec §4; quantum energy spec §8
**Governed by:** `docs/design/visual-style.md`

---

## 1. Why

The owner: "Currently we just have an endless field of asteroids but I want planets, moons, star,
other objects. Some I want generated procedurally others I want to custom make and design. I was
thinking there's maybe different map levels. Starting with a solar system, then entering the scope
of a planet or something switches you to that domain. Then maybe you can jump to other solar
systems but not just fly through endless space."

And on the space between worlds: "we still need something in between to give the sense of
movement. I think we can vary though to give it real novelty. Can use gas clouds, plasma zones,
comets, space dust, who knows."

### 1.1 Performance is not the limit

- **Size is free.** `UniversePoint` holds whole metres in 64-bit ints, so it reaches about 10¹⁸ m
  without shimmer, and the floating origin keeps the engine near you. Empty space costs nothing.
- **What costs is what is loaded near you,** and the asteroid stream already keeps that small. A
  system is a few dozen descriptors (bodies, belts, regions): a trivial amount of data.
- **Only the body you are near is detailed.** Every other body is one low-poly mesh (§6).
- **Unvisited systems cost nothing:** a system exists only as a seed until you jump there.

The real limits are travel time (§7), seeing things far away (§6) and draw calls on the GTX 960
with the canopy drawing the outside twice (style guide §2.6). This design is shaped around those
three.

---

## 2. Decisions

| Question | Choice | Why |
|---|---|---|
| Scale | **Toy scale, like *Outer Wilds*.** Planets 300–1200 m (Planetfall's range), a system about 300 km across. | Suits "fun and real enough". Every body can be a real mesh the whole time: no scaled-space renderer. Planetfall is already sized for it. |
| Levels | **A galaxy you jump across; systems you fly through, seamlessly.** | No endless flying between stars. Inside a system, arriving at a planet stays one unbroken flight, which is Planetfall's whole pitch. |
| Does anything move | **No, except a few specific cases** (comets, §8.4; later perhaps an authored mover). | No rotating frames: landing, saving, belts and the floating origin stay simple. |
| Rocks | **Belts round the star and rings round planets,** not an endless field. | Rocks become places. |
| The space between | **Space dust everywhere, plus regions with real variety:** gas clouds, plasma zones, dust lanes, comets, who knows (§8). | The owner: "something in between to give the sense of movement". |
| Crossing a system | **A cruise mode** (§7). | Keeps toy-scale systems roomy without a 17-minute boost across. |
| Jumps | **The bridge computer manages them, and they cost quantum energy** (§10). | Gives the holo table and quantum energy a big job. |
| Galaxy size | **A few dozen systems** (§10.1). | Enough to explore; few enough that the hand-made ones are found. |
| Gravity | **Wells only:** gravity inside a body's well, none between. | Arcade and readable; it is what Planetfall already built its flight and landing on. |
| Authored vs generated | **Generated, with hand-made pieces sprinkled in.** A seeded system of 8 planets and 12 moons can have 3 planets and 4 moons that are the owner's own design (§9). | Variety from the seed, the owner's dreaming where it counts. |

---

## 3. The levels

```
Galaxy          a map only, on the bridge computer's holo. Systems are pips; you jump, never fly.
  └ System      flown for real: floating origin, one seed + the owner's designs
      ├ Regions         gas clouds, plasma zones, dust lanes, belts, comets: volumes with rules
      └ Neighbourhood   a body's surroundings: its rings, its moons, its well
          └ Well        gravity (Planetfall §7)
              └ Surface Planetfall's terrain, sites, walking
                  └ Enclosed    caves, derelicts, stations: entered through an airlock-style
                                transfer (Planetfall §18)
```

- **Galaxy → system is a hard switch.** A jump tears down the outside and builds another. The
  interior is its own space and never moves, so you sit through it aboard without a seam (§10).
- **Everything inside a system is seamless.** The inner levels change *rules*, not *maps*.

### 3.1 Whereabouts: where you are

`Whereabouts` (new, pure apart from reading the focus) answers "where am I?" every physics tick,
from the focus's `UniversePoint`, the system's bodies and its regions. That is a few dozen sphere
and torus tests, cheap enough to run every tick.

- **The innermost level that contains you is where you are,** e.g.
  *KESTREL SYSTEM › near VOSS-3 › in the Veil*.
- **Regions overlap and blend** (§8.1): being in a gas cloud inside a dust lane is allowed.
- **Everything that behaves differently by place asks `Whereabouts`, never works it out itself:**
  the HUD's location line, ambient sound, the map page's default range, fog and dust, sensor
  reach, whether cruise (§7) and jumps (§10) are allowed, and the asteroid rules (§5).
- It emits `entered(level)` and `left(level)` for toasts, sound changes and the discovery log.

---

## 4. A system

### 4.1 The recipe

`SystemRecipe.from_seed(seed, design)` is a pure function, like `AsteroidRecipe` and
`WorldRecipe`: it makes no nodes, runs on any thread, and gives the same system on every machine.
`design` is the owner's optional `SystemDesign` (§9). Sub-seeds use `WorldSeed.sub` (Planetfall
§5.1), so adding a knob never reshuffles anything else, and `SystemRecipe.GENERATOR_VERSION` is
part of a system's identity.

It decides:

| Piece | First guess | Notes |
|---|---|---|
| Star | radius 2.5–4 km; colour one of a few warm star palettes | The light source. Has a well. What happens close to it waits for damage (§13). |
| Slots | 7–10; the first at about 30 km from the star, spacing growing by ×1.18–1.30, the outermost at 150 km or less. Each slot is a planet or a belt (the system skeleton spec, §4.1) | Each planet has a seeded angle round the star and a small height off the plane, so the system is a flattened disc, not a ring. |
| Planets | 5–9; `WorldRecipe` from the slot's sub-seed | Planetfall §5.2 unchanged: radius 300–1200 m, well radius 3R. |
| Moons | 0–3 per planet; radius 120–400 m; 6–14 km from their planet | A moon's well never overlaps its planet's. |
| Rings | about 1 planet in 4 | A flat rubble torus in the planet's own plane (§5). |
| Belts | 1–2 slots, round the star | Where the big asteroid fields live now. A belt takes a slot of its own: squeezed between planets, it did not fit. |
| Regions | 4–12 (§8) | Gas clouds, plasma zones, dust lanes, comets. |
| Entry point | a seeded point clear of wells and belts | Where jumps arrive (§10.3). |

### 4.2 Rules the recipe keeps

- **Nothing's well overlaps another's.** Moons sit outside their planet's well plus their own.
- **Neighbourhoods do not overlap:** a body's neighbourhood is about 4× its well radius, or the
  moons' reach, whichever is bigger.
- **Belts and rings keep clear of wells,** except a ring round its own planet, which lies outside
  the planet's surface but may lie inside its well.
- **Every design is checked by the same validator** (§9.4), so an authored body that breaks a
  rule is an error at load, not a strange collision in flight.

### 4.3 How big that feels

With the ship cruising at 120 m/s and boosting to 300 m/s:

| Trip | Distance | At boost | With cruise (§7) |
|---|---|---|---|
| Planet to its moon | 6–14 km | 20–45 s | not needed |
| Planet to the next planet | 10–60 km | 0.5–3.5 min | 5–25 s |
| Across the system | about 300 km | about 17 min | about 2 min |

Neighbouring planets are a boost away. Crossing the system needs cruise.

---

## 5. Belts and rings: asteroids in their places

`AsteroidRecipe.density_at(u)` stays the one place density is decided (asteroids spec §5.2), but
it becomes system-aware:

- **Belts:** a torus round the star. Density comes from the torus's cross-section, times the
  existing noise, so a belt has cores and gaps along its length.
- **Rings:** a thin, flat torus round a planet. Rubble and mid-size rocks only, no giants, and
  denser than a belt: a place to land on rocks, not only fly past them.
- **Elsewhere:** the existing thin *sprinkle* only, so the odd rock still drifts past.
- **Near wells:** zero, except the planet's own ring.
- The tiered cells, streaming, pictures and physics bubble are unchanged. `SystemRecipe` gives
  `AsteroidRecipe` its list of belt and ring shapes. The cells never see the system.

---

## 6. Seeing across a system

- **Near** (within about 20 km): a body is a real `Planet` (Planetfall §7), streaming its terrain
  at the detail the camera needs. At most the body you are near and its moons are live.
- **Far:** a body is a **proxy**, one low-poly faceted sphere in its palette's colours (one draw
  call). It sits in the direction the body really is, **no further than 28 km** (inside
  `AsteroidStream.VIEW_FAR`), and is scaled so its angular size is exact. Nothing needs a bigger
  far plane or a second scene.
- **The swap from proxy to real `Planet` happens at 20 km,** where the two are the same size and
  in the same direction, so nothing visibly changes.
- **The star** is a proxy like the rest, emissive (`StandardMaterial3D` emission, not a custom
  shader). The sun's `DirectionalLight3D` points from the star towards the focus, re-aimed every
  tick; across a planet's neighbourhood it hardly turns, so shadows never visibly swing.
- **Belts and rings from afar** are the giant tier's pictures, as today (fading out at 20–25 km),
  plus a proxy band: a low-poly ring of chunky slabs so a ring or a belt reads as a shape from
  across the system.
- **Everything outside follows the floating-origin rule** (CLAUDE.md): proxies, planets, regions
  and dust join `Universe.EXTERIOR_SPACE` or listen to `Universe.shifted`.
- **Budget:** the whole system, drawn as proxies, is under 40 draw calls. Measured aboard with the
  canopy view drawing the outside a second time, as the style guide requires.

---

## 7. Cruise: crossing a system

Boost alone makes a cross-system trip 17 minutes. **Quantum cruise** (chosen by the owner on
2026-09-27; the numbers are first guesses) closes the gap:

- **Engaged from the pilot's seat,** outside every well and every region that forbids it
  (`Whereabouts`). It spools up for about 5 s, like the core spinning up to boost.
- **About 2,500 m/s,** assist on, gentle turns only.
- **Costs quantum energy:** about 2 QE a second. That is 0.8 QE a km against boost's 16.7 QE a km
  (5 QE/s at 300 m/s), so long trips have a cheap way, and boost stays the way to be quick near
  things.
- **Drops out by itself** on reaching a well's edge, a belt or ring, or a region that forbids it,
  with a jolt and a HUD line (*CRUISE DROPPED · ENTERING THE VEIL*). Regions become the
  punctuation of a long trip.
- **The asteroid head-start rule** (asteroids spec §6.1) cannot hold for rubble at 2,500 m/s, so
  cruise never runs where rubble is dense, and while cruising the rubble tier is hidden and never
  promoted. A 5 m rock would be on screen for a single frame anyway.

---

## 8. The space between: regions and dust

### 8.1 One shape for every phenomenon

A **region** is data from the recipe or the owner's design:
`{ id, kind, shape (sphere, capsule or torus arc), centre: UniversePoint, size, seed, strength }`.
Each kind supplies two things, kept apart:

- **Its look,** streamed by distance like the asteroid blocks: loaded within a few km of its
  edge, a proxy beyond.
- **Its effects,** blended by `Whereabouts` from how deep you are in each region: fog colour and
  density, dust density and tint, sensor reach, quantum energy per second, cruise allowed or not,
  ambient sound.

A new kind is one look builder, one effect table and a line in the catalogue: nothing else
changes. That is the "who knows" room to grow.

### 8.2 Space dust: movement everywhere

The sense of speed comes first from **dust**: a few hundred chunky flecks (a small `MultiMesh`) in
a box about 60 m round the camera, wrapping as you move, so there is always something going past
you. Its density and tint come from `Whereabouts`: almost none in clear space, thick in a dust
lane, coloured in a gas cloud. In cruise, each fleck stretches along your velocity (its own
transform: no new shader). One draw call; world-space, so it follows the origin rule.

### 8.3 The first kinds

| Kind | Where | Look | Does |
|---|---|---|---|
| **Dust lane** | long capsules between bodies | thick dust, a faint haze | sensor reach down a little; the easiest way to see how fast you go |
| **Gas cloud** | 2–10 km blobs, often near belts | from outside, clusters of big chunky low-poly puffs; inside, the environment's fog in the cloud's colour, dimmer sun, puffs going past | hides contacts (sensor reach way down); forbids cruise; a place to hide or to hunt in |
| **Plasma zone** | rare; near the star or a planet | lavender arcs and crackling slabs, flickering | tops up quantum energy slowly, but jolts the ship and flickers the lights aboard: a risk worth taking |
| **Comet** | a few per system, on a rail (§8.4) | an ice nucleus of 50–200 m and a tail of puffs pointing away from the star | ice salvage in its wake; the one thing in the sky that moves |
| **Anomaly** | mostly hand-placed (§9) | anything | whatever the owner dreams up |

**The look follows the style guide:** chunky shapes in flat colour, no noise and no textures.
Clouds are built of puffs like the airlock's `Puffs`, only much bigger. The guide warns that
transparent overdraw is the cost to watch, so puffs use the built-in distance dither (an opaque
pass, like the rocks' fade), not alpha blending. The fog inside a region is the `Environment`'s
own fog. No new shader. Anything that glows outside (the star, plasma) is approved by the owner from
renders of the real scene, and the style guide gains the rule when it is.

### 8.4 The few things that move

A mover's position is a **pure function of the universe clock:** `position(t)`. The clock is a
number the save keeps, so a comet is where it should be on reload, and nothing about it needs
remembering. Comets fly a long, slow ellipse through the system.

**Comets are to be landable** (the owner, 2026-09-27). Landing on something that moves needs a
moving frame: near a mover, its own neighbourhood carries the ship, the avatar and anything loose
along with it, so that standing on a comet feels like standing on a still rock. That is the
movers piece's own spec (§12, step 7), not the first version of comets. An authored mover (a
station on a slow orbit, say) follows the same rules.

---

## 9. Hand-made worlds in a generated system

### 9.1 One seed, the owner's designs on top

The owner's example: *a generated system of 8 planets and 12 moons, with 3 planets and 4 moons
hand-designed*. Written as data:

```
data/systems/kestrel.tres            SystemDesign
  seed          = 7141               the rest is generated from this
  planet_count  = 8                  honoured by the generator
  moon_count    = 12
  bodies = {
    "p2"    : BodyDesign  (tweak: name "Voss", rings on, palette 3)
    "p5"    : BodyDesign  (stamp: mesa archetype, a canyon and an arch, a derelict at 12°N 40°E)
    "p7"    : BodyDesign  (hand-built: res://worlds/hollow_world.tscn)
    "p5.m1" : BodyDesign  ...
    "p5.m2" : ...
    "p7.m1" : ...
    "p7.m2" : ...
  }
  regions = { "veil": RegionDesign (gas cloud, centre, size, colour) }
```

- **Everything is keyed by id** (`p5`, `p5.m1`, `veil`), never by list order. Adding or
  removing a design never reshuffles anything else. Remove one and that body goes back to what
  the seed says.
- **Authored bodies claim their slots first,** and the generator fills the rest round them.
- **An authored body keeps its sub-seed for whatever it does not override,** so a planet the
  owner only renamed keeps its seeded terrain.

### 9.2 Three depths of authoring

| Depth | What the owner writes | What stays generated |
|---|---|---|
| **Tweak** | Recipe fields: name, radius, gravity, palette, archetype, atmosphere, rings, moons | Terrain, boulders, sites |
| **Stamp** | Plus authored terrain features (a crater, a canyon, an arch, a flattened pad) that `height_at` blends in, and pinned sites or scenes at a latitude and longitude | The rest of the ground |
| **Hand-built** | A whole scene: a hollow world, a cube moon, a station that is a moon. It **may break the round-world rules** (the owner, 2026-09-27) | Nothing. It must still honour the body contract (§9.3). |

Most special worlds should be *stamps*: cheap to make, and they still get Planetfall's streaming,
landing and walking for free.

### 9.3 The body contract

Whatever makes a body, generated or hand-built, it offers:

- `radius`, `well_radius`, `surface_gravity`;
- `proxy()`: its far look (§6);
- `contacts()`: what sensors and the map see (bridge computer spec §4.1);
- `height_at(dir)` if it has a terrain surface. A hand-built body without one brings its own
  collision and is exempt from terrain streaming, but still joins `Universe.EXTERIOR_SPACE`;
- `state`: seed plus changes (Planetfall §12.4), so saving treats it like any other body.

### 9.4 Designing it

- **`SystemValidator`** checks every system, generated or designed, against §4.2, with errors
  that name the body. A test runs it over every `.tres` in `data/systems/` and over a few hundred
  seeds.
- **A system overview scene** (a debug tool) draws the system from above: slots, wells,
  neighbourhoods, belts, regions and the entry point, with the design's bodies marked. It is where
  the owner places things before flying to them.
- The `.tscn`/`.tres` rule in CLAUDE.md applies: no `#` comments inside blocks, and every edit is
  verified by reading the values back at runtime.

---

## 10. Jumping between systems

### 10.1 The galaxy

`GalaxyRecipe.from_seed(seed, design)` places a few dozen systems as points in a flat
disc, measured in light-years only for the map. Each has a seed and a star palette. The owner's
hand-made systems are pinned by id, the same way as bodies (§9.1). A galaxy is data only: nothing
of a system exists until you arrive.

### 10.2 The bridge computer manages it

A new **JUMP** page on the bridge computer (bridge computer spec §4) shows the galaxy in the holo:
systems as pips, your own marked, those in reach lit.

- **◀ ▶** choose a target; the page shows its name, its distance and the cost.
- **Cost:** `JUMP_BASE + JUMP_PER_LY × distance` quantum energy. First guess: 150 + 20 per
  light-year. How many jumps a full starter shuttle makes is still open (§13).
- **The big button** spools the jump. It is refused, with the reason on the page, inside any
  well, inside a region that forbids it, in cruise, or without the energy.

### 10.3 What a jump looks like

1. **Spool, about 8 s:** the core's rings speed up past boost, the hum climbs, the lights dim.
   Letting go of the button aborts it; nothing has been spent yet.
2. **The jump, about 4 s:** the energy is spent. Through the canopy the dust stretches into
   streaks and the view whites out. Meanwhile the outside is torn down and the target system is
   built. The interior is untouched: you can stand up and walk about during it.
3. **Arrival** at the target system's entry point (§4.1), at rest, with the star and at least one
   planet in view. The HUD toasts the system's name.

The first build of a system happens behind the white-out, like Planetfall's first terrain load
behind the airlock cycle. If it takes longer than the jump, the white-out holds.

### 10.4 Leaving someone outside

A jump with someone on a spacewalk is refused (*CREW OUTSIDE*). Loose items outside are left
behind in the old system's ledger (§11).

---

## 11. Saving

The saving spec's world section grows one level:

- **The galaxy:** its seed, `GalaxyRecipe.GENERATOR_VERSION`, the current system id, the universe
  clock.
- **Per visited system,** keyed by id: its salvage ledger, stray ledger and body states (seed
  plus changes). A system you left keeps its ledgers; one never visited has none.
- **The ship's place** stays a `UniversePoint`, now inside the current system.
- A generator version that changed for a visited system follows the saving spec's rule for a
  changed version.

---

## 12. The pieces, in build order

Each piece is its own spec → plan → build, in an order the owner chooses. This is the suggested
one: every step is flyable by itself.

| # | Piece | Flyable result |
|---|---|---|
| 1 | **System skeleton:** `SystemRecipe`, `Whereabouts`, star and sun direction, body proxies, belts and rings through `density_at`, space dust, the map page learns bodies, the flight test starts in a system | Fly round a generated system of planets you can see but not land on |
| 2 | **Planetfall,** built against the bodies of step 1 (Planetfall §20, amended) | Land on any of them |
| 3 | **Cruise** | Cross the system in two minutes |
| 4 | **Regions:** dust lanes and gas clouds first, then plasma zones | The space between has places in it |
| 5 | **Authoring:** `SystemDesign`, tweaks and stamps, `SystemValidator`, the overview scene | The owner's 3 planets and 4 moons |
| 6 | **Galaxy and jumps:** `GalaxyRecipe`, the JUMP page, the jump sequence, saving per system | Travel between stars |
| 7 | **Movers:** comets on the clock, then the moving frame that lets you land on one | Something moves in the sky, and you can land on it |

Documents that will be amended as the pieces land: asteroids spec §5.2 and §5.6 (density and the
start), Planetfall §3 ("a few km apart" becomes slots), §14 (the test area becomes a system) and
§18, the saving spec's world section, the bridge computer spec (a JUMP page), and the style guide
(the star, clouds, plasma and dust). The `building-a-ship` skill gains cruise and jump when they
are built (CLAUDE.md).

---

## 13. The owner's answers, and what stays open

Answered on 2026-09-27:

| Question | Answer | Where |
|---|---|---|
| A cruise mode, or a smaller system crossed at boost? | **Cruise mode.** | §7 |
| Galaxy size | **A few dozen systems.** | §10.1 |
| Glow outside (the star, plasma) | **Approved by renders** of the real scene. | §6, §8.3 |
| May hand-built worlds break the round-world rules? | **Yes,** if they honour the body contract. | §9.2, §9.3 |
| Are comets landable? | **Yes,** later, with a moving frame. | §8.4, §12 |

Still open:

1. **Jump cost and reach:** how many jumps a full starter shuttle makes, and whether reach is
   limited by distance or only by what you can pay. The first guess (150 + 20 QE per light-year)
   stands until the jumps spec (§12, step 6), where it is tuned by playing.
2. **The star up close:** whether you can fly into it, and what heat does. It depends on damage
   (Slice 2), so it is decided with damage. Until then the star is a well you cannot land in.
