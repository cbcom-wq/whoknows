# NPCs — a foundation for things that live: a creature on the rocks and a droid aboard

**Date:** 2026-09-26
**Status:** The owner answered the first draft's six questions on 2026-09-26 (§3.1). This
revision folds them in. It adds a second NPC, a maintenance droid aboard, so the foundation is
proven outside and inside from the first build. It awaits the owner's review of the written spec.
No code has changed.
**Depends on:** `main` at `a67439d`: the floating origin, the asteroid groups, big rocks in detail,
the interior redesign's rooms and sliding doors, hands and items, the spacewalk. It does not depend
on quantum energy or the bridge computer, which are designed but not built; it leaves hooks for
both (§12.3).
**Governed by:** `docs/design/visual-style.md`, and CLAUDE.md's floating-origin rule
**Amends, once approved:** the slice spec's roadmap (§15 here); Planetfall §18 and hands-and-items
§15, whose NPC hooks this spec takes up; the visual style guide (a section on NPCs, §13.4 and
§14.4).

---

## 1. Why

The owner, 2026-09-26:

> Let's start thinking about npcs. "AI" characters/things in the game. I think a good test subject
> to start is a creature that lives on the asteroids. But the main intent here is to build a
> reusable foundation for npc function and intelligence. How they move, what they do, how they
> spawn, how they interact with the player and the universe, etc.

And, answering the first draft: a shy grazer to start; no memory yet; nothing more complex to do to
them yet, but room left for it; no suit clicks; **both** the creature and an interior droid; the
name *skitter* stays.

What exists today:
- **Nothing in the game acts on its own.** Rocks sit still until touched; items fall where thrown.
  The only things that decide anything are the flight computer and the airlock's cycle.
- **The roadmap is full of NPCs:** droid squads and human crew (Slice 3), captured ships flying as
  wingmen (Slice 4), encounters on worlds (Planetfall §18), droids using items (hands-and-items §15).
  All of them were left as hooks.
- **The outside streams.** Rocks are seeded per cell, drawn as pictures far off and made into bodies
  only near an anchor's path. Nothing is simulated that you could not touch (asteroids spec §6–§7).
  NPCs have to live by the same rule, or they become the thing that eats the frame.
- **Big rocks up close are solid as drawn** (asteroids spec §18): within 4 km of an anchor a big rock
  is a `StaticBody3D` with its exact surface, its craters, ledges and boulders. That is ground a
  creature can walk on, and it never moves.
- **The interior never moves,** is laid out on a grid of 2 m cells in 2.6 m storeys, and knows its
  rooms, doorways, walls and fixtures (`InteriorLayout`). Its doors slide open for whoever walks up;
  they have no collider, so they can never trap anyone. There is no navmesh.
- **The floating origin** re-centres the outside on you every 2 km. Anything outside joins
  `Universe.EXTERIOR_SPACE` or listens to `Universe.shifted`.

### 1.1 The pitch

You drift down toward the big rock on a spacewalk, lamp on. The surface below is ledges and scree,
dusty umber. One of the stones moves.

Then three more. They were never stones: squat, six-legged things with plated backs the colour of
the rock, grazing along a lavender vein in a crater's wall. Your lamp sweeps across them and they
freeze, flat to the rock. Hold still and dim the lamp, and after a few seconds the boldest one lifts
its head and goes back to the vein. Kick off the rock beside them and the whole herd feels it
through the stone and scatters, scuttling over the rim, one of them leaping clean off the surface
to a moon twenty metres away.

Back aboard, the airlock's inner hatch opens on the corridor, and something small is in the way: a
knee-high drum of a droid, polishing a porthole with one stubby arm. It chirps, turns its lit eye
strip to you, and trundles aside into the galley doorway to let you pass. When you boost from the
helm it locks its wheels and rides the burn out. When you throw a mug at it, it backs off with a
worried beep, and then goes back to work.

### 1.2 What this adds

- **A foundation** every NPC is built from: how it exists, spawns and despawns (§4), moves (§5),
  senses (§6), decides (§7), and is described as data (§8).
- **Stimuli:** light, vibration, sound and touch as things the world gives off and NPCs perceive
  (§6.1).
- **A director** per space that keeps the NPCs near you alive and everything else as cheap records
  (§4.3).
- **The skitter,** a shy grazer on the rocks outside (§13).
- **The maintenance droid,** tending the ship inside (§14).

Both are built only from the foundation's parts. Where they differ, they swap a layer.

---

## 2. The shape of the foundation

An NPC is five layers. Each layer talks only to the one beside it, so a new kind of NPC swaps a layer
rather than rewriting the stack.

```
   EXISTENCE     NpcRecord (pure data) ── made by a Population recipe, kept by an NpcDirector
       │         dormant: a record, costs bytes        live: a node, costs frame time
       ▼
   BODY          Npc node: a CharacterBody3D, its look, and one or more Locomotors
       ▲  intents                                         │ where it is, what it touches
       │                                                  ▼
   MIND          Brain: needs + scored behaviours ◄── SENSES: Perception + Memory
                                                          ▲
                                                          │ stimuli
   WORLD         StimulusBus: lights, vibrations, sounds, touches ── from the player, the ship,
                 items, rocks, other NPCs
```

- **The mind never touches physics.** It reads its own memory and needs, and writes an **intent**:
  go there, face that, this fast, do this action. A locomotor turns the intent into motion in its
  medium. That is what lets the same brain drive a crawler on a rock, a droid on a deck, or a whole
  ship through its flight computer (§15).
- **The mind never reads the world directly.** It reads what its senses put in its memory. An NPC
  knows only what it has perceived, and can be wrong: it flees from where it last saw you. That is
  the game's theme applied to its inhabitants: what does it know? Who knows.
- **Species are data.** A `.tres` per species says how big, how fast, what it senses, what it
  needs, which behaviours it has and where it lives, as `BlockDefinition` and `ItemDefinition` do
  for blocks and items.

What each NPC in this build takes from each layer:

| Layer | Skitter (outside) | Maintenance droid (inside) |
|---|---|---|
| Existence | `RockHerds`: herds per big rock, live near an anchor | `ShipCrew`: one per ship, live while the interior is |
| Body | `SurfaceCrawler`, `ZeroGDrift` | `DeckWalker` |
| Senses | sight, light, vibration, touch | sight, sound, touch, felt shake |
| Mind | graze, herd, freeze, scatter, hide | tend, roam, recharge, give way, notice, startle, brace |
| Look | `SpacePalette`, legged gait | `InteriorPalette`, the interior kit, wheels |

---

## 3. Decisions

### 3.1 Answered by the owner, 2026-09-26

| # | Question | The owner's answer | Where it lands |
|---|---|---|---|
| 1 | What is the first creature like? | **A shy grazer**, as drafted. | §13 |
| 2 | Do creatures remember? | **No memory for now.** | §4.5 |
| 3 | What can you do to them? | **Nothing more complex yet,** but leave room for future interactions. | §12.4 |
| 4 | Feel them through the suit? | **Not at this point.** Outside stays silent. | §13.4 |
| 5 | Scope of the first build | **Both:** the skitter outside and a droid inside. | §14 |
| 6 | The name | **Skitter.** | — |

### 3.2 The rest, as recommended

| # | Question | Recommendation | Why | Alternatives |
|---|---|---|---|---|
| 1 | How NPCs exist | **Records far, nodes near.** Every NPC is a pure `NpcRecord` from a seeded recipe; only those a director makes live are nodes (§4). | The same shape as the rocks' pictures and bodies, and Planetfall's chunks. The world can hold millions of creatures; the frame pays for a dozen. | Hand-placed spawners. Every NPC a node, with physics turned off far away. |
| 2 | Where they spawn | **From places,** by a recipe keyed on the place's stable id: herds from a big rock's id, a droid from a ship (§4.2). | Deterministic, free to query, and the same rock always has the same herds. Other places (a wreck, a world site) are more recipes. | A global spawn timer round the player. |
| 3 | What they do while you are away | **Nothing is simulated.** A herd's place on its seeded round is a function of universe time (§4.4). | Come back an hour later and they have moved, at no cost. It is not memory: nothing you did is kept. | Always back at home. A coarse off-screen simulation. |
| 4 | How they move | **Locomotors,** one per medium: `SurfaceCrawler` (walks any surface, any way up), `ZeroGDrift` (leaps and puffs in open space), `DeckWalker` (walks an interior's floors under its gravity) (§5). `ShipPilot` and `GroundWalker` later. | The brain's intents stay the same in every medium. | One movement script per NPC. |
| 5 | The body | **A `CharacterBody3D`** with its own up direction, in a new physics layer `npcs` (layer 8, bit 128), inside and out (§5.1). | Kinematic control of grip, gait and wheels. The avatar's spacewalk bump already shows how a kinematic body shares momentum. | A `RigidBody3D` held down by forces: harder to keep planted on ledges and in corridors. |
| 6 | How they find their way inside | **Paths over the interior's cells:** A* over walkable cells, joined where `InteriorLayout` has no wall between them (§5.5). | The layout already knows every wall and doorway; a 2 m cell graph is exact, tiny and deterministic. No navmesh to bake or rebuild. | A `NavigationRegion3D` baked from the interior geometry. |
| 7 | How they sense | **Stimuli, not queries:** the world emits light, vibration, sound and touch into a `StimulusBus` per space; each NPC's `Perception` samples it at its think rate, plus sight by cone and line of sight (§6). | In vacuum there is no sound, so outside the senses are the ones space allows; inside there is air. Lights and shocks already exist (lamp, flare, plasma bolt, hull thump), so the player has ways to be noticed from the first build. | Each NPC polls the player's position. |
| 8 | How they decide | **Needs and scored behaviours ("utility AI"):** needs rise and fall; each behaviour scores itself from needs and memory; the best one runs, with a bonus for sticking to the current one. Reflexes pre-empt instantly (§7). | Reads as alive rather than scripted; weights live in the species data; scales from a grazer to a droid squad (orders become a strong need). Each behaviour stays small and testable. | A state machine (brittle past a handful of states). Behaviour trees (good for scripted combat; more authoring for less life). Goal planning (GOAP; heavy for now). |
| 9 | How often they think | **Senses and brain at 5 Hz, staggered; movement at the physics rate** (§16). | A creature does not need to reconsider its life sixty times a second. Staggering spreads the cost evenly. | Everything at 60 Hz. |
| 10 | How they relate to you | **A disposition per species, nudged per individual while live:** fear and curiosity (§12.1). | The same field later holds a droid's loyalty and a crew member's allegiance. | Fixed per species. |
| 11 | What they look like | **Built in code from chunky low-poly parts in flat colour, from the palette of the space they are in:** `SpacePalette` outside, `InteriorPalette` and the interior kit inside (§13.4, §14.4). No new shader. | The style guide's rules. The legged gait is reusable by any legged thing. | Imported, rigged models. |
| 12 | The droid's sound | **Quiet and warm, aboard only:** a soft whir while it moves, a chirp, a worried beep. Three new `Synth` builders on the Ship bus (§14.5). | The style guide's sound rules: synthesized, soft, heard through air. A silent droid in a humming ship reads as a prop. | Silent. |
| 13 | Interactions later | **A seam, not a feature:** the `Npc` answers the `Interactor`'s contract and offers nothing yet (§12.4). | The owner asked for room for future interactions. The seam costs a few lines and fixes where they go. | Nothing until needed. |
| 14 | Debugging | **A debug overlay** (behaviour, top scores, needs, memory above each NPC, toggled by a key), and real-scene probes (§17). | Utility AI is only tunable if you can see the scores. | Logs only. |

---

## 4. Existence: records, populations and directors

### 4.1 Records

An **`NpcRecord`** is one NPC as pure data. No node: records are made on worker threads and tested
headless, as `AsteroidRock` is.

| Field | Meaning |
|---|---|
| `id: StringName` | stable: `&"skitter:<rock id>:<herd>:<n>"`, `&"droid:<ship>:<n>"` |
| `species: StringName` | which `NpcSpecies` |
| `site: StringName` | the place it belongs to: a big rock's id, a ship; later a wreck, a world site |
| `home: Vector3` | where it lives, **in the site's own frame** (a rock's local coordinates, a ship's grid) |
| `seed: int` | its own randomness: size, colour, temperament, round |
| `herd: int` | which group it belongs to at its site, or -1 |

Positions an NPC must remember are **site-local** whenever the site is fixed (a big rock never moves,
an interior never moves) and `UniversePoint`s otherwise. Never engine `Vector3`s outside: they would
be wrong after a shift.

### 4.2 Populations

A **population recipe** is a pure function from `(world seed, site) -> Array[NpcRecord]`, one per kind
of place. Two in this build:

**`RockHerds`** (outside):
- a big rock gets 0–3 herds, more on bigger and more veined rocks;
- a herd is 3–7 skitters round a **home patch** on the surface, preferring crater walls and
  lavender veins;
- home patches are chosen from the rock's own detail data (`RockDetail`, already built on a worker
  from the rock's seed), so they land on real surface;
- the same rock always has the same herds, in the same places.

**`ShipCrew`** (inside):
- one maintenance droid per ship with at least 12 walkable cells;
- its **dock** is a floor cell of the ship's closet room if it has one, otherwise the room or common
  cell farthest (by path) from the helm;
- read from `InteriorLayout`, so any blueprint gets its droid in a sensible place.

A population recipe is also a **source** of records: `records_near(site, point, radius, time)`. The
director asks it, never the other way round.

### 4.3 Directors

An **`NpcDirector`** is a node, one per space: one for the exterior, and one per interior slot. It
never moves. Its job:

- **Promote** a record to a live `Npc`, and **demote** it back to a record, by the director's rule:
  - **Outside, by distance:** a record comes alive within its species' **live radius** of an anchor
    (group `&"space_anchor"`: the hull, or you on a spacewalk), 350 m for a skitter. It is demoted
    beyond the live radius plus 100 m, only when no camera could see it (§4.6).
  - **Inside, by site:** every record of a ship is live while that ship's interior is built, and
    demoted when it is torn down. An interior is small; the budget holds (§16).
- **Stay within budget:** at most `MAX_LIVE` NPCs per director (32 outside, 8 inside to start);
  over it, the farthest are demoted first, with a logged warning.
- **Schedule thinking:** each live NPC gets a slot in a staggered 5 Hz round (§16).
- **Only where there is ground:** a skitter is promoted only while its rock is in detail
  (`AsteroidDetails.live`). Detail is kept within 4 km, far beyond the 350 m live radius, so the
  ground is always there first. If it is not, the promotion waits. A droid is promoted only after
  its interior's colliders are in.
- **Pool nodes:** demoted nodes wait in a pool for the next record of their species.

Outside, live NPCs are parented under a holder the exterior director owns, and each joins
`Universe.EXTERIOR_SPACE` itself, as rock bodies do; `test_floating_origin_scene.gd` then covers
them with no change. Inside, they are parented under the interior and join nothing: the interior
never moves.

### 4.4 Time instead of simulation

A record never runs while dormant. Instead, where it is when it wakes is a function of time:

- each herd has a **round**, seeded: a loop of three to five places on its rock (grazing patches,
  a sheltered crater), and a period of 20–40 minutes;
- on promotion, the herd starts at the point its round reaches at the current universe time, and
  each member a little way from it;
- while live, `Wander` walks the same round, so what you watch and what you come back to agree.

The droid needs none of this: it is live whenever you are aboard, and starts each load at its dock.

### 4.5 No memory, for now

**Nothing is remembered once an NPC is demoted** (the owner, 2026-09-26). A herd you frightened is
calm again next time; a droid you startled has forgotten it by the next load. This is the rocks' rule
(asteroids spec §2).

There is one seam for later: the director passes every record through `amend(record)` before it
promotes it. It changes nothing in this build. When something must stick (Slice 2's first death, a
tamed creature) a ledger of changes by record id plugs in there. Planetfall's `WorldState` is seed
plus changes, the same idea, so the two can merge when saving to disk arrives.

### 4.6 Never seen to appear (outside)

- **Distance:** a 0.8 m skitter at 350 m is about one pixel across at 1280 × 720 with a 75° field
  of view. Promotion happens past the point where you could see it.
- **Fade:** the skitter's material fades in between 300 and 250 m with the same built-in distance
  dither the rocks use.
- **Demotion only out of sight:** past the live radius and outside every exterior camera's frustum
  (chase, canopy, spacewalk), or past the fade.
- **Checked** by the asteroid spec's method: frame differences at every promotion and demotion no
  larger than between ordinary frames.

Inside, the droid appears with the interior, before the first frame, so there is nothing to see.

---

## 5. The body: `Npc` and locomotors

### 5.1 The node

```
Npc (CharacterBody3D)       layer npcs (128); outside, in EXTERIOR_SPACE
├── Look                    the species' mesh, built in code, and its gait or wheels
├── Locomotors              SurfaceCrawler, ZeroGDrift, DeckWalker … one active at a time
├── Perception              senses and memory
└── Brain                   needs, behaviours, the current intent
```

- **Pooled:** a director hands one node record after record, as `AsteroidBody` is handed rock after
  rock. `Npc.setup(record, species)` makes it that NPC.
- **Physics layers:** the interior is far from the outside (it is parked 5 km below), so one layer
  serves both, as the avatar's does.

  | Body | `collision_layer` | `collision_mask` |
  |---|---|---|
  | `Npc`, outside | 128 | 1 hull, 4 avatar, 32 items, 64 asteroids = **101** |
  | `Npc`, inside | 128 | 2 interior geometry, 4 avatar, 32 items = **38** |
  | `AsteroidBody` | 64 | + 128 |
  | Avatar, aboard and on a spacewalk | 4 | + 128 |
  | Hull | 1 | + 128 |
  | Items | 32 | + 128 |
  | `SlidingDoor`'s trigger | 0 | 4 + 128, so doors open for the droid |
  | `FeltGravity` | 0 | 32 + 128, so the droid feels the ship's shove |

- **Mass** for sharing momentum by hand, as the spacewalker does (asteroids spec §7.6): a skitter
  counts as 25 kg, the droid as 40 kg.
- **`receive_hit(hit: Hit)`:** a plasma bolt or a thrown item is a touch; a skitter is knocked off
  its rock (§12.1). Nothing takes damage yet.

### 5.2 Intents

The brain writes one `Intent` a think; the active locomotor follows it every physics tick until the
next.

| Field | Meaning |
|---|---|
| `move_to` | a site-local point, or none |
| `face` | a site-local point to look at, or none |
| `speed` | fraction of the species' top speed |
| `action` | `&"graze"`, `&"freeze"`, `&"leap"`, `&"tend"`, `&"brace"` … played by the look, maybe acted on by the locomotor |

### 5.3 `SurfaceCrawler`

Walks on any surface, any way up, which is what a rock in zero g needs.

- **Up is the ground's normal,** found by a short ray (and two more, fore and aft, for edges) along
  the body's own down. The body turns toward it smoothly, about 0.15 s to settle.
- **Grip:** a pull of 4 m/s² toward the surface stands in for gravity, so `move_and_slide` with that
  up direction behaves on a crater wall as it would on a floor.
- **Edges:** over a convex edge the fore ray misses; the crawler wraps round it by casting down and
  back from ahead of its feet. Into a concave corner the fore ray hits a wall; it climbs.
- **Lost grip:** if every ray misses (knocked off, walked off a boulder into nothing), it hands over
  to `ZeroGDrift`.
- **Steering:** toward `move_to` along the surface, with separation from herd mates, and away from
  drops it cannot wrap.

### 5.4 `ZeroGDrift`

Free movement in open space: straight lines, no gravity.

- **The leap:** before leaving a surface it casts to a landing spot (on the same rock, or a moon or
  rubble within 30 m). No hit, no leap. It flies straight, turning feet-first, and hands back to the
  crawler on contact.
- **The puff:** a knocked-off skitter tumbles, then steadies and puffs back toward the nearest
  surface with small jets of gas (the chunky puff already shared by the airlock and the RCS,
  `Puffs`). It has a limited number of puffs; one that runs out drifts away and is demoted out of
  sight.
- **Moving footing:** landing on rubble that has drifted (an adrift `AsteroidBody`) is allowed; the
  crawler then carries its footing's velocity. Grip on something moving faster than 3 m/s fails.

### 5.5 `DeckWalker`

Walks an interior's floors under its felt gravity.

- **Gravity is the interior's own:** `get_gravity()`, which `FeltGravity` sets to plating plus the
  hull's shove, as it does for loose items. A hard burn pushes the droid as it pushes a crate beside
  it, unless it braces (§14.3). It does not walk into unplated cells.
- **Paths over cells:** `DeckPaths`, a pure class built from `InteriorLayout`, joins two walkable
  cells where there is no wall face between them: open floor, and each room's doorway. A* over that
  graph gives a list of cells; the walker steers through their centres (`InteriorBuilder.
  interior_center()`), cutting corners where the line between two cells is clear.
- **Places it never goes:** the airlock (`InteriorLayout.AIRLOCK_ZONE`), the helm's cell and the
  cockpit pod. Ladders are not climbed in this build; a ship's other storeys are simply off its map.
- **Rebuilt with the layout:** when the grid changes, the layout is replanned and `DeckPaths` with
  it. A droid whose path crosses a cell that is gone plans again.
- **Local avoidance:** it slows for the avatar and anything else in its way, and the brain's
  `GiveWay` moves it aside (§14.3). Cells are 2 m wide, and the droid 0.5 m, so there is room to
  pass.
- **Doors:** a `SlidingDoor` opens for it as for you (its trigger's mask gains `npcs`).

### 5.6 Later locomotors

Same intent, other media (§15): `GroundWalker` (on a world's terrain, under its gravity well) and
`ShipPilot` (feeds a `FlightComputer`, so a wingman is an NPC whose body is a ship). A droid that
climbs ladders is `DeckWalker` with ladder links in `DeckPaths`.

---

## 6. Senses: stimuli, perception and memory

### 6.1 The stimulus bus

**`StimulusBus`** is one node per space, beside its director. Anything that gives off something an
NPC might notice calls `emit(stimulus)`. A **`Stimulus`** is short-lived data:

| Field | Meaning |
|---|---|
| `kind` | `&"light"`, `&"vibration"`, `&"sound"`, `&"touch"`, `&"shake"` |
| `position` | engine space; outside, the bus subtracts `Universe.shifted`'s delta from every live stimulus |
| `strength` | how strong at its source |
| `radius` | how far it can carry |
| `site` | for vibration: which rock it travels through |
| `source` | the node, if any: the avatar, the hull, an item |
| `until` | when it stops |

What emits, in this build:

| Source | Space | Stimulus |
|---|---|---|
| The hand lamp, a burning flare | both | a **light** each think, while on |
| The hull striking a rock (already detected for `hull_thump`) | outside | a **vibration** through that rock, by impact speed |
| A spacewalker pushing off, landing on or bumping into a rock | outside | a small **vibration** |
| A plasma bolt hitting a rock | outside | a sharp **vibration** |
| The ship's thrusters firing within 50 m of a surface | outside | a **vibration** (blast on the rock) |
| A plasma bolt or a thrown item striking something | inside | a **sound** |
| The avatar sprinting | inside | a small **sound** |
| The felt gravity jumping (a hard burn, a hull strike, from `MotionCoupling`) | inside | a **shake**, to everything in the interior |
| Anything hitting an NPC (bolt, bump, item, the hull) | both | a **touch** to it |

### 6.2 Perception

Each think, an NPC's `Perception` gathers what it senses. Per species:

- **Sight:** a cone and range. Anything tagged visible (the avatar, the hull, other NPCs) inside it
  is checked for line of sight with one ray. Outside, things in darkness are seen at a third of the
  range, lit things (in a lamp's beam or near a flare) at the full range. Inside the ship is lit;
  walls block sight, and so do closed doors.
- **Light on itself:** is it lit, and from where? Skitters freeze when lit.
- **Vibration:** anything through the rock it stands on, weaker with distance. None while leaping.
- **Sound:** anything within its radius, through air only; weaker through a closed door.
- **Shake:** the whole interior at once.
- **Touch:** anything that hit it.

### 6.3 Memory

What it perceives becomes **percepts** in its memory: *what* (a kind and, if known, a node), *where*
(site-local), *when*, and *how sure*. Sureness decays; the memory forgets a percept when it falls
below a threshold. Memory lasts only while the NPC is live (§4.5).

The brain reads memory, not the world, so a skitter that saw you by the crater and lost sight of you
flees from the crater, not from where you are now.

---

## 7. The mind: needs and scored behaviours

### 7.1 Needs

Each species names its own needs, from 0 (satisfied) to 1 (urgent), with the rates at which they rise
and fall. The brain does not care what they are called. This build's:

| Need | Who | Rises with | Falls with |
|---|---|---|---|
| `hunger` | skitter | time | grazing |
| `fear` | both | light on it, vibration, sound, being seen by something it fears, touch | calm time, being with its herd, hiding |
| `company` | skitter | time away from its herd | being near herd mates |
| `curiosity` | both | calm time, a novel percept at a distance | investigating |
| `rest` | skitter | activity | resting in shelter |
| `duty` | droid | time since it last tended something | tending |
| `charge` | droid | activity | sitting at its dock |

### 7.2 Behaviours

A behaviour is a small class: `score(ctx) -> float`, `start(ctx)`, `think(ctx) -> Intent`, and
`done(ctx) -> bool`. `ctx` holds the NPC's needs, memory, record, species and a few helpers (where
its herd is, nearest shelter, the next work spot). Behaviours never see a scene, so each is tested
headless with a made-up context.

The brain, each think:
1. Updates needs.
2. **Reflexes first:** a reflex behaviour (freeze when lit, scatter or startle at touch, brace at a
   shake) that scores above its threshold runs at once and interrupts anything.
3. Otherwise, scores every behaviour; the current one gets a bonus of 25% so it is not dropped for a
   near tie, and every behaviour has a minimum run time. The best one runs.
4. The running behaviour writes the intent.

Scores come from **response curves** on needs and memory (linear, smoothstep, threshold), with
per-species weights in the species data. Tuning is editing numbers in a `.tres`, not code.

### 7.3 Herds

Herd behaviour is behaviours that read herd mates, not a separate system: `StayWithHerd` scores with
`company`; `Scatter` makes the herd run in different directions and meet again at its shelter;
`Follow` picks the boldest as leader. A herd shares nothing but what each member perceives, plus one
rule: a member that bolts is a percept (*a mate bolted, there*) to the others who see it. Panic
spreads by sight.

---

## 8. Species as data

**`NpcSpecies`** is a `Resource`, one `.tres` per species, loaded by an `NpcCatalog` as items and blocks
are:

| Group | Fields |
|---|---|
| Identity | `id`, `display_name` |
| Body | `size`, `mass`, `top_speed`, `locomotors`, `look` (a builder name in `NpcLooks`) |
| Senses | `sight_range`, `sight_cone`, `dark_sight`, `feels_vibration`, `hears`, `feels_shake`, `light_response` (−1 flees light … +1 drawn to it) |
| Needs | per need: `rise`, `fall`, starting range |
| Mind | its behaviours, each with weights and curve settings |
| Disposition | starting `fear` of and `curiosity` about the player, the ship, other species |
| World | `population` (which recipe spawns it), `live_radius`, `fade` |
| Interactions | what the player can do to it; empty for both species in this build (§12.4) |

A new creature is a `.tres`, a look, and at most a behaviour or two. The skitter and the droid are the
proof.

---

## 9. Where the code lives

```
src/npc/
  npc.gd                  Npc extends CharacterBody3D: setup, receive_hit, the interaction seam
  npc_record.gd           NpcRecord: one NPC as data
  npc_species.gd          NpcSpecies extends Resource
  npc_catalog.gd          NpcCatalog: loads data/npcs/*.tres
  npc_director.gd         NpcDirector: promote, demote, pool, schedule, budget
  stimulus.gd             Stimulus
  stimulus_bus.gd         StimulusBus
  perception.gd           Perception: senses into memory
  npc_memory.gd           NpcMemory: percepts that decay
  brain.gd                Brain: needs, reflexes, scoring, the intent
  intent.gd               Intent
  behaviour.gd            Behaviour: the base class
  behaviours/             one file per behaviour
  locomotor.gd            Locomotor: the base class
  surface_crawler.gd
  zero_g_drift.gd
  deck_walker.gd
  deck_paths.gd           DeckPaths: A* over an interior's cells (pure)
  legged_gait.gd          LeggedGait: feet placed by rays, a tripod gait
  npc_looks.gd            NpcLooks: the skitter and the droid, built in code
  npc_debug.gd            the overlay
  populations/
    rock_herds.gd         RockHerds (pure)
    ship_crew.gd          ShipCrew (pure)
data/npcs/
  skitter.tres
  maintenance_droid.tres
```

Per CLAUDE.md, the `.tres` files carry no `#` comments, and each is verified by loading it and
reading its properties back at runtime.

---

## 10. Scene changes

- The flight scene gains the exterior's `NpcDirector` and `StimulusBus`, created in code by the
  scene's bootstrap where possible. If a `.tscn` edit is needed, no `#` comments, and properties
  read back at runtime.
- `Ship` makes an interior director and bus for its slot when it builds its interior, and tears
  them down with it, as it does `Airlocks`.
- `AsteroidStream` offers the rocks in detail to the exterior director (it already knows them).
- The emitters in §6.1: one line each in the hand lamp, the flare, the hull's rock strikes, the
  spacewalk's pushes and landings, the plasma bolt, items' impacts, the avatar's sprint and
  `MotionCoupling`.
- `project.godot` names layer 8 `npcs`; the masks in §5.1 change.

---

## 11. The two spaces

The foundation does not know which space it is in. What differs is set up by the director:

| | Outside | Inside |
|---|---|---|
| Director's rule | by distance from anchors | by site: the whole ship |
| Positions | rock-local; `UniversePoint` where not on a rock | ship-local, which is interior space |
| Floating origin | every NPC in `EXTERIOR_SPACE`; the bus shifts its stimuli | never; the interior never moves |
| Gravity | none; the crawler's grip | `FeltGravity`: plating plus the hull's shove |
| Senses | no sound; vibration through rock | sound through air; shake |
| Palette | `SpacePalette` | `InteriorPalette` and the interior kit |
| Render layer | 1 (exterior) | 2 (interior) |

---

## 12. Interaction

### 12.1 With the player

**Outside:**
- **Being seen:** skitters freeze when lit or when they see you move near. Staying still and dark lets
  them relax and come closer, to about 6 m if curiosity wins.
- **Being felt:** pushing off, landing or bumping the rock near them makes them scatter.
- **Touch:** a spacewalker bumping one shares momentum (25 kg against 120 kg): it is shoved, grips,
  and bolts. On a plasma hit it is knocked off the rock and puffs back (§5.4).
- **Flares:** skitters are drawn to a still flare from a distance and frightened by one close or
  moving. A flare thrown on the rock is a way to gather them.

**Inside:**
- **In the way:** the droid gives way when you come toward it.
- **Watching:** stop near it and it turns to look at you and chirps.
- **Touch:** walk into it, throw something at it or shoot it, and it backs away with a worried beep,
  then goes back to work.

No damage for either (Slice 2). Each fright raises that individual's fear; calm time lowers it back
toward the species' start. While live only (§4.5).

### 12.2 With the universe

- **The ship, outside:** a hard landing or strike against their rock scatters every herd within
  reach of the vibration, and so does a thruster blast close to the surface.
- **The ship, inside:** a hard burn or a hull strike is a shake; the droid braces and rides it out.
- **Rocks:** skitters walk only on big rocks in detail and leap to moons and rubble near them. A rock
  they stand on that gets shoved carries them (§5.4).
- **Doors and furniture:** the droid opens doors by walking up to them, and its work spots are the
  ship's own fixtures and wall pieces (§14.2).
- **Each other:** through perception only. A skitter and the droid never meet in this build.

### 12.3 Hooks for what is designed but not built

- **The ship's sensors** (bridge computer §4): a `LifeContacts` source can report herds as contacts of
  kind `&"life"` with `precision &"region"`: *LIFE? · ~2 KM*. Not built here.
- **Quantum energy:** the veins skitters graze are the lavender crystal. The droid could tend the
  quantum core and machine once they exist: they are fixtures, so they become work spots with no
  change here.

### 12.4 Room for future interactions

The owner: nothing more complex yet, but leave room for it. So:

- `Npc` implements the `Interactor`'s contract (`interact(actor)`, `prompt_text()`,
  `can_interact(actor)`), and routes it to its species' **interactions**: a list of small classes,
  each with `can(npc, actor)`, `prompt(npc)` and `run(npc, actor)`.
- **Both lists are empty in this build.** `can_interact` returns false, so nothing is offered.
  The `Interactor`'s mask does not include `npcs` yet.
- **Adding one later** is a class, a line in a `.tres`, and `npcs` in the `Interactor`'s mask.
  Candidates the owner has not asked for: pet or feed a skitter, catch one with `Grasp`, the hose,
  sending the droid somewhere, switching it off.

---

## 13. The skitter

A small, shy grazer that lives on big rocks.

### 13.1 In numbers

| | |
|---|---|
| Size | 0.7–1.0 m long, 0.4 m high |
| Mass | 25 kg (for bumps) |
| Crawl | 1.2 m/s calm, 4 m/s bolting |
| Leap | up to 30 m, 6 m/s |
| Sight | 40 m in a 220° cone; 13 m in the dark |
| Vibration | feels a spacewalker's landing to 30 m, a hull strike across the whole rock |
| Live radius | 350 m (fade 300 → 250 m) |
| Herds | 0–3 per big rock, 3–7 each |

### 13.2 Behaviours

| Behaviour | Scores high when | Does |
|---|---|---|
| `Graze` | hungry, calm | walks to a vein patch and nibbles |
| `Wander` | nothing else is urgent | ambles along its herd's round |
| `StayWithHerd` | far from mates | moves back among them |
| `Freeze` (reflex) | lit, or something it fears moves near | flattens to the rock, stops |
| `Scatter` (reflex) | vibration, touch, a mate bolting | runs from the source, maybe leaps, regroups at shelter |
| `Hide` | fear stays high | goes to the nearest crater or overhang and waits |
| `Investigate` | curious and calm, something still in sight | edges toward it, stops at a few metres |
| `Rest` | tired | settles in shelter |
| `DrawnToFlare` | a still flare in sight at a distance | approaches it, stops at its light's edge |

### 13.3 A day in its life

It grazes a vein with its herd. The herd moves on along its round every few minutes. When you arrive
lit and loud it freezes, then scatters; left alone in the dark, it goes back to grazing and, if you
stay still, may come to look at you.

### 13.4 The look

Following the style guide (§2.1, §2.2, §3.5), to be pinned by rendering and approved by the owner:

- **Chunky and faceted:** a plated, domed back of three or four big flat facets, a squat head, six
  stubby two-segment legs. Under 300 triangles. Flat-shaded, no texture.
- **Colour from `SpacePalette`:** the back takes its home rock's own colour (so a still skitter reads
  as a stone: camouflage is the point), the underside and legs a darker shade, and a small lavender
  patch on the back from grazing crystal. New constants go in `SpacePalette`; no new palette.
- **Eyes:** two small pale facets that catch the lamp. No glow, no light.
- **The gait:** a tripod gait, three feet planted at a time, each foot placed by a short ray to the
  surface, so it steps over scree and up ledges. `LeggedGait` is reusable by any legged NPC.
- **Silent,** like everything outside (style guide §2.9; the owner, 2026-09-26).

---

## 14. The maintenance droid

A small droid that keeps the ship tidy, and keeps out of your way. The first NPC inside, and the
first step toward Slice 3's droid squad.

### 14.1 In numbers

| | |
|---|---|
| Size | 0.55 m tall, 0.5 m across |
| Mass | 40 kg (for bumps) |
| Speed | 1.0 m/s ambling, 1.8 m/s hurrying |
| Sight | 8 m in a 140° cone; walls and closed doors block it |
| Hearing | a thrown item's impact to 10 m; a plasma hit to 15 m |
| Population | one per ship with 12 or more walkable cells; docked in the closet on the starter |

### 14.2 Work spots

The droid's jobs come from the ship's own layout, so any blueprint gets them:

- **Fixtures:** the helm (from beside it, never in its cell), and later the computer, the quantum core
  and the machine.
- **Wall pieces:** consoles, displays, lockers and portholes (`InteriorLayout`'s wall variants), each
  worked from the floor cell in front of it.
- A work spot is a cell, a facing and an action: `&"polish"` at a porthole, `&"scan"` at a console,
  `&"tidy"` at lockers.
- It picks the spot it tended longest ago, weighted by distance, and never one you are standing at.

### 14.3 Behaviours

| Behaviour | Scores high when | Does |
|---|---|---|
| `Tend` | `duty` high, calm | goes to a work spot, faces it, works for 4–8 s with its arm, chirps when done |
| `Roam` | nothing else is urgent | trundles to another room and looks about |
| `Recharge` | `charge` high | goes to its dock and sits for about 20 s |
| `GiveWay` | the avatar is coming toward it, or its path runs through you | moves to the side of the cell or into the nearest doorway, turns to face you, waits until you pass |
| `Notice` | curious, calm, the avatar stopped within 3 m | turns its eye strip to you, tilts, chirps |
| `Startle` (reflex) | touch, or a loud sound near | backs away a metre or two with a worried beep; `fear` rises |
| `Brace` (reflex) | a shake | stops, locks its wheels, rides it out; if the shove beats its grip it slides, like a crate |
| `KeepAway` | `fear` high | goes about its work in rooms you are not in |

### 14.4 The look

Following the style guide's interior rules (§2.1–§2.5, §3, §4), to be pinned by rendering at eye
height (1.6 m) and approved by the owner:

- **Built like a prop,** from the interior kit, `(kit, frame, variety)`, never seeing the grid: a
  squat bevelled drum on two chunky wheels, a domed cap, one short two-segment arm with a pad on the
  end.
- **Colour from `InteriorPalette` only:** body and cap from the ship's wall and trim colours, the
  wheels dark. New constants go in `InteriorPalette`; no new palette.
- **Its eye:** a strip in the kit's `GLOW` batch, warm, which turns to what it looks at. No light
  of its own, so the interior's light budget is unchanged. Within the interior's three shaders.
- **Render layer 2,** like everything inside.

### 14.5 The sound

Three new `Synth` builders, positional, on the Ship bus (style guide §2.9):
- `droid_whir`, looped, soft, while its wheels turn;
- `droid_chirp`, two warm notes, when it notices you or finishes a job;
- `droid_beep`, a lower, wobbling pair, when startled.

---

## 15. Proving the reuse: what later NPCs swap

| Later NPC | Existence | Body | Senses | Mind |
|---|---|---|---|---|
| Droid squad (Slice 3) | `ShipCrew` with more droids | `DeckWalker`, with ladders | sight, sound, touch | `Follow`, `Hold`, `TakeCover`, `Attack`; an order is a strong need |
| Human crew, prisoners | per ship | `DeckWalker` | sight, sound | fear, morale; `Surrender` |
| Wingmen (Slice 4) | per fleet | `ShipPilot` feeding the ship's `FlightComputer` | the ship's sensors as its perception | `FormUp`, `Engage`, `Disengage` |
| Fauna on worlds (Planetfall §18) | per world site | `GroundWalker` on terrain, the gravity well; terrain anchors | sight, sound | as the skitter's |

---

## 16. Budgets and performance

- **Frame:** all NPC work at most **1 ms per frame** on the GTX 960 target, at 1280 × 720, with 32
  live outside and the droid inside, measured in the real scene. Senses and brains run at 5 Hz, split
  into twelve groups, so a frame thinks for two or three NPCs at most.
- **Physics:** a crawler casts three rays and one `move_and_slide` a tick; the gait casts six short
  rays a tick for its feet (only within 60 m of a camera; farther away the legs play a canned cycle).
  The droid is one `move_and_slide` a tick.
- **Paths:** A* over the starter's few dozen cells costs microseconds; paths are planned at think
  time, never per tick.
- **Records:** about 100 bytes each; a rock's herds are generated only when the director asks.
- **Draws:** one mesh per live NPC to start; a `MultiMesh` for distant herds if measurement asks for
  it.

---

## 17. Testing

### 17.1 Automated (GUT, headless, output pristine)

**Existence**
- `RockHerds` gives the same records for the same seed and rock; ids are stable and unique; homes lie
  on the rock's surface; no herd on a rock too small.
- `ShipCrew` gives the starter one droid docked in the closet; a blueprint without a closet docks it
  farthest from the helm; a ship under 12 walkable cells has none.
- A herd's place at time *t* is the same every call, and moves along its round.
- The directors: outside, promotes within the live radius, demotes beyond it plus 100 m only out of
  view, keeps `MAX_LIVE`, waits for a rock in detail; inside, promotes with the interior and demotes
  with it; `amend` is called for every promotion.

**Floating origin**
- Live skitters are members of `EXTERIOR_SPACE`; the droid is not; stimuli shift with the origin;
  `test_floating_origin_scene.gd` passes with a herd live.

**Bodies**
- `SurfaceCrawler` on test meshes (a cube, a sphere, a concave bowl): stays on the surface upside
  down, wraps a convex edge, climbs a concave corner, hands over to drift when knocked off.
- `ZeroGDrift`: a leap with no landing spot is refused; a knocked-off skitter puffs back.
- `DeckPaths` on the starter: every work spot is reachable from the dock; no path enters the airlock,
  the helm's cell or the pod; paths pass rooms only through their doorways; a changed grid replans.
- `DeckWalker` in the real interior: walks dock to helm and back, through a door that opens for it,
  and slides under a big enough shove.
- Layers: every mask in §5.1, read back at runtime.

**Senses and mind**
- Sight respects the cone, range, darkness, walls and line of sight; vibration only through the same
  rock; sound only through air; memory decays.
- Each behaviour's score from a made-up context; reflexes pre-empt; the current behaviour keeps a
  near tie; minimum run times hold.

**Data and style**
- Every `.tres` in the catalogue loads and names behaviours, locomotors and a look that exist; its
  properties read back as authored.
- The skitter's colours come from `SpacePalette`, the droid's from `InteriorPalette`; the droid
  uses only the kit's batches (`test_visual_style_rules.gd` extended).

### 17.2 Live checks (renders shown to the owner)

**Outside**
- A herd on a big rock at eye height from a spacewalk, lamp on and off.
- The pitch (§1.1) played through: freeze when lit, scatter at a push-off, return in the dark,
  scatter at a hull strike.
- A skitter crawling over a crater rim and upside down under an overhang, feet planted.
- Promotion and demotion unseen (§4.6); frame times with 32 live.
- A 20 km boost across groups: no frame over 33 ms, no NPC left behind a shift.

**Inside**
- The droid at eye height (1.6 m) in the corridor, the galley and at a porthole.
- Walking toward it in the corridor: it gives way. Stopping near it: it notices you. Throwing a mug
  at it: it startles, then goes back to work.
- A boost from the helm with the droid mid-corridor: it braces.
- Frame times aboard with it moving.

### 17.3 The debug overlay

A key toggles, above each live NPC: its behaviour, the top three scores, its needs as bars, and its
freshest percepts. Off by default.

---

## 18. Non-goals

- Damage, health, death (Slice 2; `amend` is where remembering them goes).
- Memory across loads (the owner, 2026-09-26).
- Anything the player can do to an NPC beyond scaring, shoving and bumping it; the seam only
  (§12.4).
- Sound outside, suit-conducted or otherwise.
- The droid doing real work: repairs, carrying items, using items, cycling the airlock, following you.
- Hostile NPCs, combat AI, weapons in NPC hands.
- Crew, wingmen, fauna on worlds (§15 shows where they fit).
- Ladders for the droid.
- Saving to disk.

---

## 19. Risks

| Risk | Mitigation |
|---|---|
| **Surface crawling on a detailed rock is jittery** (5,000-triangle concave collision, ledges, scree) | Three rays with a smoothed up direction; the crawler tested on hard test meshes first; the gait only near a camera. Fallback: crawl on a smoothed copy of the surface. |
| **The droid gets in the way** in tight corridors | `GiveWay` scores above everything but reflexes when you approach; the debug overlay shows it; the playtest walks the corridor both ways. |
| **The droid and a hard burn** (felt shove against a kinematic body) | It reads the same felt gravity as items; `Brace` holds it up to a cap, and beyond it slides like a crate. The interior's net (`FeltGravity`) puts it back if it ever leaves every cell. |
| **NPCs cost too much frame** | The 1 ms budget measured; staggered thinking; `MAX_LIVE`. Fallback: fewer live, a lower think rate far away. |
| **Utility AI dithers** between near-tied behaviours | The 25% sticking bonus, minimum run times, and the debug overlay to see it. |
| **Promotion is seen** outside | Promotion past visible size, the distance fade, demotion only out of view, measured frame differences (§4.6). |
| **A shift leaves an NPC's memory wrong** | Positions remembered site-local or as `UniversePoint`s; stimuli shifted by the bus; a test crosses a shift with a live herd. |
| **The foundation is over-built for two NPCs** | Each layer is built only as far as the skitter and the droid need; §15 is the guard against building it too narrow, not a list to build. |

---

## 20. Build order (a sketch, for the plan)

1. **Records, species data and the directors,** with a placeholder box NPC in each space: promotion,
   demotion, pooling, the floating origin, the physics layers.
2. **`DeckPaths` and `DeckWalker`:** the box walks the starter from dock to helm, through doors,
   under felt gravity. Inside first: it is the simpler medium, so the foundation is proven there
   before the hard crawler.
3. **Stimuli, perception and the brain,** with the debug overlay; the droid's behaviours.
4. **The droid's look and sounds,** rendered at eye height and shown to the owner.
5. **`SurfaceCrawler` and `ZeroGDrift`** on test meshes, then on a big rock.
6. **The skitter's behaviours, look and gait,** rendered and shown to the owner.
7. **Tuning** by playing both halves of the pitch, and the live checks.
