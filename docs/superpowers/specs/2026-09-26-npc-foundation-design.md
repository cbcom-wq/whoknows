# NPCs — a foundation for things that live, starting with a creature on the rocks

**Date:** 2026-09-26
**Status:** First draft, for discussion with the owner. **Nothing here is decided.** Every row in §3
is a recommendation, and §15 lists the questions only the owner can answer. No code has changed.
**Depends on:** `main` at `a67439d`: the floating origin, the asteroid groups, big rocks in detail,
hands and items, the spacewalk. It does not depend on quantum energy or the bridge computer, which
are designed but not built; it leaves hooks for both (§10.3).
**Governed by:** `docs/design/visual-style.md`, and CLAUDE.md's floating-origin rule
**Amends, once approved:** the slice spec's roadmap (§14 here); Planetfall §18 and hands-and-items
§15, whose NPC hooks this spec takes up; the visual style guide (a creature section, §11.4).

---

## 1. Why

The owner, 2026-09-26:

> Let's start thinking about npcs. "AI" characters/things in the game. I think a good test subject
> to start is a creature that lives on the asteroids. But the main intent here is to build a
> reusable foundation for npc function and intelligence. How they move, what they do, how they
> spawn, how they interact with the player and the universe, etc.

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

Back aboard, you set the ship down hard against the same rock. The thump carries through the stone;
when you come out again the crater is empty. They are on the far side of the rock now, and they
remember the light.

### 1.2 What this adds

- **A foundation** every NPC is built from: how it exists, spawns and despawns (§4), moves (§5),
  senses (§6), decides (§7), and is described as data (§8).
- **Stimuli:** light, vibration and touch as things the world gives off and NPCs perceive (§6.1).
- **A director** that keeps the few NPCs near you alive and everything else as cheap records (§4).
- **The first creature,** a rock-dwelling grazer (working name *skitter*), built only from the
  foundation's parts (§11).

---

## 2. The shape of the foundation

An NPC is five layers. Each layer talks only to the one beside it, so a new kind of NPC swaps a layer
rather than rewriting the stack.

```
   EXISTENCE     NpcRecord (pure data) ── made by a Population recipe, kept by the NpcDirector
       │         dormant: a record, costs bytes        live: a node, costs frame time
       ▼
   BODY          Npc node: a CharacterBody3D, its look, and one or more Locomotors
       ▲  intents                                         │ where it is, what it touches
       │                                                  ▼
   MIND          Brain: needs + scored behaviours ◄── SENSES: Perception + Memory
                                                          ▲
                                                          │ stimuli
   WORLD         StimulusBus: lights, vibrations, touches, sights ── from the player, the ship,
                 items, rocks, other NPCs
```

- **The mind never touches physics.** It reads its own memory and needs, and writes an **intent**:
  go there, face that, this fast, do this action. A locomotor turns the intent into motion in its
  medium. That is what lets the same brain drive a crawler on a rock, a droid on a deck, or a whole
  ship through its flight computer (§13).
- **The mind never reads the world directly.** It reads what its senses put in its memory. An NPC
  knows only what it has perceived, and can be wrong: it flees from where it last saw you. That is
  the game's theme applied to its inhabitants: what does it know? Who knows.
- **Species are data.** A `.tres` per species says how big, how fast, what it senses, what it
  needs, which behaviours it has and where it lives, as `BlockDefinition` and `ItemDefinition` do
  for blocks and items.

---

## 3. Decisions to make

Recommendations, awaiting the owner. §15 pulls out the ones that change the game rather than the
code.

| # | Question | Recommendation | Why | Alternatives |
|---|---|---|---|---|
| 1 | The first creature | **A skittish grazer** that lives on big rocks, feeds on the lavender veins, freezes when lit or watched, and scatters when the rock shakes (§11). | Every layer gets exercised: surface movement, a leap in zero g, three senses, several needs, herd behaviour, reaction to the player and the ship, and no dependence on damage (Slice 2). | A curious creature that follows you like a pet. A pest that latches onto your hull and has to be dislodged. A drifting space jelly (free flight only, no surface). |
| 2 | How NPCs exist | **Records far, nodes near.** Every NPC is a pure `NpcRecord` from a seeded recipe; only those within a live radius of an anchor are nodes (§4). | The same shape as the rocks' pictures and bodies, and Planetfall's chunks. The world can hold millions of creatures; the frame pays for a dozen. | Hand-placed spawners. Every NPC a node, with physics turned off far away. |
| 3 | Where they spawn | **From places,** by a recipe keyed on the place's stable id: herds from a big rock's id (§4.2). | Deterministic, free to query, and the same rock always has the same herds. Other places (a wreck, a world site, a ship) are more recipes. | A global spawn timer round the player. |
| 4 | What they do while you are away | **Nothing is simulated. Where they are is a function of time:** a record says where its herd would be at universe time *t*, on a seeded daily round (§4.4). | Come back an hour later and they have moved, at no cost. No off-screen tick. | They are always back at home. A coarse off-screen simulation. |
| 5 | What they remember | **Nothing once they unload, for now,** exactly as rocks do. A `NpcLedger` of changes by record id exists in the data model but has no entries until something must stick (§4.5). | Slice 2's deaths will be the first thing that must be remembered; the ledger is where they go. | Every live NPC's state saved on unload. |
| 6 | How they move | **Locomotors,** one per medium, swappable at run time: `SurfaceCrawler` (walks any surface, any way up), `ZeroGDrift` (leaps and puffs in open space) now; `GroundWalker` (navmesh under gravity) and `ShipPilot` later (§5). | The brain's intents stay the same in every medium. | One movement script per creature. |
| 7 | The body | **A `CharacterBody3D`** with its own up direction, in a new physics layer `creatures` (layer 8, bit 128) (§5.1). | Kinematic control of grip and gait; the avatar's spacewalk bump already shows how a kinematic body shares momentum. | A `RigidBody3D` held to the rock by forces: harder to keep planted on ledges. |
| 8 | How they sense | **Stimuli, not queries:** the world emits light, vibration and touch into a `StimulusBus`; each NPC's `Perception` samples it at its think rate, plus sight by cone and line of sight (§6). | In vacuum there is no sound, so the senses are the ones space allows. Lights and shocks already exist (lamp, flare, plasma bolt, hull thump), so the player has tools to be noticed or stay hidden from the first build. | Each NPC polls the player's position. |
| 9 | How they decide | **Needs and scored behaviours ("utility AI"):** needs rise and fall; each behaviour scores itself from needs and memory; the best one runs, with a bonus for sticking to the current one. Reflexes pre-empt instantly (§7). | Reads as alive rather than scripted; weights live in the species data; scales from a grazer to a droid squad (orders become a strong need). Each behaviour stays small and testable. | A state machine (brittle past a handful of states). Behaviour trees (good for scripted combat; more authoring for less life). Goal planning (GOAP; heavy for now). |
| 10 | How often they think | **Senses and brain at 5 Hz, staggered; movement at the physics rate** (§12). | A creature does not need to reconsider its life sixty times a second. Staggering spreads the cost evenly. | Everything at 60 Hz. |
| 11 | How they relate to you | **A disposition per species, nudged per individual:** fear, curiosity, and later hostility; being lit, shaken or hit raises fear, calm time lowers it (§10.1). | The same field later holds a droid's loyalty and a crew member's allegiance. | Fixed per species. |
| 12 | What they look like | **Built in code from chunky low-poly parts, in flat colour from `SpacePalette`,** legs moved by a procedural gait (§11.4). No new shader. | The style guide's rules for everything outside. The gait is reusable by any legged thing. | Imported, rigged models. |
| 13 | Debugging | **A debug overlay** (behaviour, top scores, needs, memory above each NPC, toggled by a key), and a real-scene probe (§14). | Utility AI is only tunable if you can see the scores. | Logs only. |

---

## 4. Existence: records, populations and the director

### 4.1 Records

An **`NpcRecord`** is one NPC as pure data. No node: records are made on worker threads and tested
headless, as `AsteroidRock` is.

| Field | Meaning |
|---|---|
| `id: StringName` | stable forever: `&"skitter:<rock id>:<herd>:<n>"` |
| `species: StringName` | which `NpcSpecies` |
| `site: StringName` | the place it belongs to: the big rock's id, later a wreck, a world site, a ship |
| `home: Vector3` | where it lives, **in the site's own frame** (the rock's local coordinates) |
| `seed: int` | its own randomness: size, colour, temperament, round |
| `herd: int` | which group it belongs to at its site, or -1 |

Positions an NPC must remember are **site-local** whenever the site is fixed (a big rock never moves)
and `UniversePoint`s otherwise. Never engine `Vector3`s: they would be wrong after a shift.

### 4.2 Populations

A **population recipe** is a pure function from `(world seed, site) -> Array[NpcRecord]`, one per kind
of place. The first is **`RockHerds`**:

- a big rock gets 0–3 herds, more on bigger and more veined rocks;
- a herd is 3–7 skitters round a **home patch** on the surface, preferring crater walls and
  lavender veins;
- home patches are chosen from the rock's own detail data (`RockDetail`, already built on a worker
  from the rock's seed), so they land on real surface;
- the same rock always has the same herds, in the same places.

A population recipe is also a **source** of records: `records_near(site, point, radius, time)`. The
director asks it, never the other way round.

### 4.3 The director

**`NpcDirector`** is a node in the flight scene, one per space (exterior now; each interior slot
later). It never moves. Its job:

- **Promote** a record to a live `Npc` when it comes within the **live radius** of an anchor (group
  `&"space_anchor"`: the hull, or you on a spacewalk). The live radius is per species; the skitter's
  is 350 m.
- **Demote** a live NPC back to a record beyond the live radius plus 100 m, and only when no camera
  could see it (§4.6). Its node goes back to a pool.
- **Stay within budget:** at most `MAX_LIVE` NPCs (32 to start); over it, the farthest are
  demoted first, with a logged warning.
- **Schedule thinking:** each live NPC gets a slot in a staggered 5 Hz round (§12).
- **Only where there is ground:** a skitter is promoted only while its rock is in detail
  (`AsteroidDetails.live`). Detail is kept within 4 km, far beyond the 350 m live radius, so the
  ground is always there first. If it is not, the promotion waits.

Live NPCs are parented under a holder the director owns, and each joins `Universe.EXTERIOR_SPACE`
itself, as rock bodies do. `test_floating_origin_scene.gd` then covers them with no change.

### 4.4 Time instead of simulation

A record never runs while dormant. Instead, where it is when it wakes is a function of time:

- each herd has a **daily round**, seeded: a loop of three to five places on its rock (grazing
  patches, a sheltered crater), and a period of 20–40 minutes;
- on promotion, the herd starts at the point its round reaches at the current universe time, and
  each member a little way from it;
- so leaving and coming back finds them somewhere else, as if they had been living all along.

A herd frightened while live keeps its fright only while live (§4.5). Its round is seeded, and it
picks the round up again once it calms.

### 4.5 Memory across loads

For now, **nothing is remembered once an NPC is demoted.** This is the rocks' rule (asteroids spec §2):
cheap, and a sharp-eyed player might notice.

The data model has a place for what must stick: **`NpcLedger`**, a dictionary from record id to a
small change (`gone`, `moved home`, `tamed`). The director applies it to every record it promotes.
Nothing writes to it in this build. Slice 2's first death is the first entry. Planetfall's
`WorldState` is seed plus changes, and the ledger is the same idea, so the two can merge when saving
to disk arrives.

### 4.6 Never seen to appear

- **Distance:** a 0.8 m skitter at 350 m is about one pixel across at 1280 × 720 with a 75° field
  of view. Promotion happens past the point where you could see it.
- **Fade:** the skitter's material fades in between 300 and 250 m with the same built-in distance
  dither the rocks use.
- **Demotion only out of sight:** past the live radius and outside every exterior camera's frustum
  (chase, canopy, spacewalk), or past the fade.
- **Checked** by the asteroid spec's method: frame differences at every promotion and demotion no
  larger than between ordinary frames.

---

## 5. The body: `Npc` and locomotors

### 5.1 The node

```
Npc (CharacterBody3D)       in EXTERIOR_SPACE outside; layer creatures (128)
├── Look                    the species' mesh, built in code, and its gait
├── Locomotors              SurfaceCrawler, ZeroGDrift … one active at a time
├── Perception              senses and memory
└── Brain                   needs, behaviours, the current intent
```

- **Pooled:** the director hands one node record after record, as `AsteroidBody` is handed rock
  after rock. `Npc.setup(record, species)` makes it that NPC.
- **Physics layers:**

  | Body | `collision_layer` | `collision_mask` |
  |---|---|---|
  | `Npc` (outside) | 128 | 1 hull, 4 avatar, 32 items, 64 asteroids = **101** |
  | `AsteroidBody` | 64 | + 128 |
  | Avatar on a spacewalk | 4 | + 128 |
  | Hull | 1 | + 128 |

- **Mass** for sharing momentum by hand, as the spacewalker does (asteroids spec §7.6): a skitter
  counts as 25 kg.
- **`receive_hit(hit: Hit)`:** a plasma bolt knocks it off the rock (§10.1). Nothing takes damage
  yet.

### 5.2 Intents

The brain writes one `Intent` a think; the active locomotor follows it every physics tick until the
next.

| Field | Meaning |
|---|---|
| `move_to` | a site-local point, or none |
| `face` | a site-local point to look at, or none |
| `speed` | fraction of the species' top speed |
| `action` | `&"graze"`, `&"freeze"`, `&"leap"` … played by the look, maybe acted on by the locomotor |

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
  `Puffs`). It has a limited number of puffs; one that runs out drifts away and is demoted
  out of sight.
- **Moving targets:** landing on rubble that has drifted (an adrift `AsteroidBody`) is allowed; the
  crawler then carries its footing's velocity. Grip on something moving fast (over 3 m/s) fails.

### 5.5 Later locomotors

Same intent, other media (§13): `GroundWalker` (a `NavigationAgent3D` on an interior's or a world's
navmesh, under real gravity) and `ShipPilot` (feeds a `FlightComputer`, so a wingman is an NPC whose
body is a ship).

---

## 6. Senses: stimuli, perception and memory

### 6.1 The stimulus bus

**`StimulusBus`** is one node per space. Anything that gives off something an NPC might notice calls
`emit(stimulus)`. A **`Stimulus`** is short-lived data:

| Field | Meaning |
|---|---|
| `kind` | `&"light"`, `&"vibration"`, `&"touch"`, and later `&"sound"` (in air, aboard or on a world) |
| `position` | engine space; the bus subtracts `Universe.shifted`'s delta from every live stimulus |
| `strength` | how strong at its source |
| `radius` | how far it can carry |
| `site` | for vibration: which rock it travels through |
| `source` | the node, if any: the avatar, the hull, an item |
| `until` | when it stops |

What emits, in this build:

| Source | Stimulus |
|---|---|
| The hand lamp, a burning flare (and any light later put outside the ship) | a **light** each think, while on |
| The hull striking a rock (already detected for `hull_thump`) | a **vibration** through that rock, by impact speed |
| A spacewalker pushing off, landing on or bumping into a rock | a small **vibration** |
| A plasma bolt hitting a rock | a sharp **vibration** |
| Anything hitting an NPC (bolt, bump, the hull) | a **touch** to it, and a **vibration** |
| The ship's thrusters firing within 50 m of a surface | a **vibration** (blast on the rock) |

### 6.2 Perception

Each think, an NPC's `Perception` gathers what it senses. Per species:

- **Sight:** a cone and range. Anything tagged visible (the avatar, the hull, other NPCs) inside it
  is checked for line of sight with one ray. Things in darkness are seen at a third of the range;
  lit things (in a lamp's beam or near a flare) at the full range.
- **Light on itself:** is it lit, and from where? Skitters freeze when lit.
- **Vibration:** anything through the rock it stands on, weaker with distance. None while leaping.
- **Touch:** anything that hit it.

### 6.3 Memory

What it perceives becomes **percepts** in its memory: *what* (a kind and, if known, a node), *where*
(site-local), *when*, and *how sure*. Sureness decays; the memory forgets a percept when it falls
below a threshold.

The brain reads memory, not the world, so a skitter that saw you by the crater and lost sight of you
flees from the crater, not from where you are now.

---

## 7. The mind: needs and scored behaviours

### 7.1 Needs

Each NPC has a few needs, from 0 (satisfied) to 1 (urgent), rising or falling at species rates:

| Need | Rises with | Falls with |
|---|---|---|
| `hunger` | time | grazing |
| `fear` | light on it, vibration, being seen by something it fears, touch | calm time, being with its herd, hiding |
| `company` | time away from its herd | being near herd mates |
| `curiosity` | calm time, a novel percept at a distance | investigating |
| `rest` | activity | resting in shelter |

### 7.2 Behaviours

A behaviour is a small class: `score(ctx) -> float`, `start(ctx)`, `think(ctx) -> Intent`, and
`done(ctx) -> bool`. `ctx` holds the NPC's needs, memory, record, species and a few helpers (where
its herd is, nearest shelter). Behaviours never see a scene, so each is tested headless with a
made-up context.

The brain, each think:
1. Updates needs.
2. **Reflexes first:** a reflex behaviour (flinch at touch, freeze when lit) that scores above its
   threshold runs at once and interrupts anything.
3. Otherwise, scores every behaviour; the current one gets a bonus of 25% so it is not dropped for a
   near tie. The best one runs.
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
| Senses | `sight_range`, `sight_cone`, `dark_sight`, `feels_vibration`, `light_response` (−1 flees light … +1 drawn to it) |
| Needs | per need: `rise`, `fall`, starting range |
| Mind | its behaviours, each with weights and curve settings |
| Disposition | starting `fear` of and `curiosity` about the player, the ship, other species |
| World | `population` (which recipe spawns it), `live_radius`, `fade` |

A new creature is a `.tres`, a look, and at most a behaviour or two. The skitter is the proof.

---

## 9. Scene changes

- `flight_test.tscn` gains `NpcDirector` and `StimulusBus`, created in code under the scene's
  bootstrap where possible. If a `.tscn` edit is needed, CLAUDE.md's rule holds: no `#` comments,
  properties read back at runtime.
- `AsteroidStream` offers the rocks in detail to the director (it already knows them).
- The hand lamp, the flare, the hull's rock strikes, the spacewalk's pushes and landings, and the
  plasma bolt's hits emit stimuli (§6.1): one line each.
- `project.godot` names layer 8 `creatures`; the masks in §5.1 change.

---

## 10. Interaction

### 10.1 With the player

- **Being seen:** skitters freeze when lit or when they see you move near. Staying still and dark lets
  them relax and come closer, to about 6 m if curiosity wins.
- **Being felt:** pushing off, landing or bumping the rock near them makes them scatter.
- **Touch:** a spacewalker bumping one shares momentum (25 kg against 120 kg): it is shoved, grips,
  and bolts. On a plasma hit it is knocked off the rock and puffs back (§5.4). No damage (Slice 2).
- **Disposition:** each fright raises that individual's fear of you; calm time lowers it back towards
  the species' start. While live only, for now (§4.5).
- **Flares:** skitters are drawn to a still flare from a distance but frightened by one close to or
  moving (§11.2). A flare thrown on the rock is a way to gather them.

### 10.2 With the universe

- **The ship:** a hard landing or strike against their rock scatters every herd within reach of the
  vibration, and so does a thruster blast close to the surface.
- **Rocks:** they walk only on big rocks in detail and leap to moons and rubble near them. A rock they
  stand on that gets shoved carries them (§5.4).
- **Other NPCs:** through perception only. Two species react to each other through their
  dispositions; there is only one species in this build.

### 10.3 Hooks for what is designed but not built

- **The ship's sensors** (bridge computer §4): a `LifeContacts` source can report herds as contacts of
  kind `&"life"` with `precision &"region"`: *LIFE? · ~2 KM*. Not built here.
- **Quantum energy:** the veins skitters graze are the lavender crystal, the rock sample's colour.
  Whether a creature has a QE value, and whether the hose can take one, is a question for the owner
  (§15).
- **Carrying one:** `Grasp` could hold a skitter as it holds an item. Taking it aboard needs the
  airlock's transfer for a live thing. Not built here.

---

## 11. The first creature: the skitter

Working name. A small grazer that lives on big rocks.

### 11.1 In numbers

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

### 11.2 Behaviours

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

### 11.3 A day in its life

It grazes a vein with its herd. The herd moves on along its round every few minutes. When you arrive
lit and loud it freezes, then scatters; left alone in the dark, it goes back to grazing and, if you
stay still, may come to look at you.

### 11.4 The look

Following the style guide (§2.1, §2.2, §3.5), to be pinned by rendering and approved by the owner:

- **Chunky and faceted:** a plated, domed back of three or four big flat facets, a squat head, six
  stubby two-segment legs. Under 300 triangles. Flat-shaded, no texture.
- **Colour from `SpacePalette`:** the back takes its home rock's own colour (so a still skitter reads
  as a stone: camouflage is the point), the underside and legs a darker shade, and a small lavender
  patch on the back from grazing crystal. New constants go in `SpacePalette`; no new palette.
- **Eyes:** two small pale facets that catch the lamp. No glow, no light.
- **The gait:** a tripod gait, three feet planted at a time, each foot placed by a short ray to the
  surface, so it steps over scree and up ledges. A `LeggedGait` class any legged NPC can use.
- **Sound:** none outside, as the style guide says for everything outside (§2.9). Whether you might
  feel them through your suit's gloves on the rock is a question (§15).

---

## 12. Budgets and performance

- **Frame:** all NPC work at most **1 ms per frame** on the GTX 960 target, with 32 live NPCs, at
  1280 × 720, measured in the real scene. Senses and brains run at 5 Hz, split into twelve groups, so
  a frame thinks for two or three NPCs at most.
- **Physics:** a crawler casts three rays and one `move_and_slide` a tick; the gait casts six short
  rays a tick for its feet (only while within 60 m of a camera; farther away the legs play a canned
  cycle).
- **Records:** about 100 bytes each; a rock's herds are generated only when the director asks.
- **Draws:** one mesh per live NPC to start; a `MultiMesh` for distant herds if measurement asks for
  it.

---

## 13. Proving the reuse: what later NPCs swap

| Later NPC | Existence | Body | Senses | Mind |
|---|---|---|---|---|
| Droid squad (Slice 3) | records per ship (a ship is a site) | `GroundWalker` on the interior's navmesh, grav plating as gravity | sight; `sound` in air | `Follow`, `Hold`, `TakeCover`, `Attack`; an order is a strong need |
| Human crew, prisoners | per ship | `GroundWalker` | sight, sound | fear, morale; `Surrender` |
| Wingmen (Slice 4) | per fleet | `ShipPilot` feeding the ship's `FlightComputer` | the ship's sensors as its perception | `FormUp`, `Engage`, `Disengage` |
| Fauna on worlds (Planetfall §18) | per world site | `GroundWalker` on terrain, the gravity well; terrain anchors | sight, sound | as the skitter's |

Interiors never move, so interior NPCs never join `EXTERIOR_SPACE`; each interior slot gets its own
director and bus.

---

## 14. Testing

### 14.1 Automated (GUT, headless, output pristine)

- **Records:** `RockHerds` gives the same records for the same seed and rock; ids are stable and
  unique; homes lie on the rock's surface; no herd on a rock too small.
- **Time:** a herd's position at time *t* is the same every call; it moves along its round.
- **Director:** promotes within the live radius, demotes beyond it plus 100 m only out of view,
  keeps `MAX_LIVE`, waits for a rock in detail, applies the ledger.
- **Floating origin:** live NPCs are members of `EXTERIOR_SPACE`; stimuli shift with the origin;
  `test_floating_origin_scene.gd` passes with a herd live.
- **Crawler:** on a test mesh (a cube, a sphere, a concave bowl) it stays on the surface upside
  down, wraps a convex edge, climbs a concave corner, and hands over to drift when knocked off.
- **Drift:** a leap with no landing spot is refused; a knocked-off skitter puffs back.
- **Perception:** sight respects the cone, range, darkness and line of sight; vibration only through
  the same rock; memory decays.
- **Brain:** each behaviour's score from a made-up context; reflexes pre-empt; the current behaviour
  keeps a near tie.
- **Species:** every `.tres` in the catalogue loads and names behaviours and a look that exist.
- **Style:** the look's colours come from `SpacePalette` (`test_visual_style_rules.gd` extended).

### 14.2 Live checks (renders shown to the owner)

- A herd on a big rock at eye height from a spacewalk, lamp on and off.
- The pitch (§1.1) played through: freeze when lit, scatter at a push-off, return in the dark,
  scatter at a hull strike.
- A skitter crawling over a crater rim and upside down under an overhang, feet planted.
- Promotion and demotion unseen (§4.6); frame times with 32 live.
- A 20 km boost across groups: no frame over 33 ms, no NPC left behind a shift.

### 14.3 The debug overlay

A key toggles, above each live NPC: its behaviour, the top three scores, its needs as bars, and its
freshest percepts. Off by default.

---

## 15. Questions for the owner

These change what the game is, not how the code is built:

1. **What is the first creature like?** The draft's skittish grazer (§11), or something that engages
   you more: curious and pet-like, or a pest that goes for your ship?
2. **Do creatures remember?** The draft forgets on unload and fakes time with a seeded round (§4.4,
   §4.5). Or should a herd you frightened still be frightened next visit?
3. **What can you do to them, now?** The draft allows scaring and shoving only. Should you be able
   to catch one and carry it aboard? Should the hose take one, and are they worth QE?
4. **Sound:** outside is silent (style guide §2.9). Would you like to *feel* them as faint clicks
   through the suit while you touch the same rock? That would be a style-rule change.
5. **The first build's scope:** the foundation and the skitter only, outside only (the draft), or
   also a bare interior NPC (a maintenance droid ambling the corridor) to prove the foundation works
   in both spaces from day one?
6. **The name:** *skitter* is a working name.

---

## 16. Non-goals

- Damage, health, death (Slice 2; the ledger is ready for it).
- Hostile NPCs, combat AI, weapons in NPC hands.
- Interior NPCs, droids, crew, wingmen (§13 shows where they fit; unless §15.5 says otherwise).
- Saving to disk.
- Dialogue, trading, factions beyond a disposition number.
- NPCs on worlds.

---

## 17. Risks

| Risk | Mitigation |
|---|---|
| **Surface crawling on a detailed rock is jittery** (5,000-triangle concave collision, ledges, scree) | Three rays with a smoothed up direction; the crawler tested on hard test meshes first; the gait only near a camera. Fallback: crawl on a smoothed copy of the surface. |
| **NPCs cost too much frame** | The 1 ms budget measured with 32 live; staggered thinking; `MAX_LIVE`. Fallback: fewer live, a lower think rate far away. |
| **Utility AI dithers** between near-tied behaviours | The 25% sticking bonus, minimum run times per behaviour, and the debug overlay to see it. |
| **Promotion is seen** | Promotion past visible size, the distance fade, demotion only out of view, measured frame differences (§4.6). |
| **A shift leaves an NPC's memory wrong** | Positions remembered site-local or as `UniversePoint`s; stimuli shifted by the bus; a test crosses a shift with a live herd. |
| **The foundation is over-built for one creature** | Each layer is built only as far as the skitter needs; §13 is the guard against building it too narrow, not a list to build. |

---

## 18. Build order (a sketch, for the plan)

1. **Records and the director** with a placeholder box NPC: promotion, demotion, the floating origin.
2. **`SurfaceCrawler` and `ZeroGDrift`** on test meshes, then on a big rock.
3. **Stimuli and perception,** with the emitters in §6.1.
4. **The brain** and the skitter's behaviours, with the debug overlay.
5. **The look and the gait,** rendered and shown to the owner.
6. **Tuning** by playing the pitch, and the live checks.
