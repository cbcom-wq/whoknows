# System skeleton — a generated star system you can fly round

**Date:** 2026-09-27
**Status:** Piece 1 of the star systems design
(`docs/superpowers/specs/2026-09-27-star-systems-design.md` §12). Approved by the owner on
2026-09-28, with the answers in §15.
**Depends on:** `main` at `1d23261` (the floating origin, asteroids, saving, the bridge computer)
**Builds early:** Planetfall §5 (`WorldSeed`, `WorldRecipe`, names and palettes), so Planetfall
starts at its terrain
**Amends:** asteroids spec §5.2, §5.6 and §13; Planetfall §4.2, §5.3, §7.4 and §14; saving spec
§8.1; bridge computer spec §5; the style guide (§12 here)
**Governed by:** `docs/design/visual-style.md`

---

## 1. What you get

You start where you do today: 700 m off a big rock, its swarm round you. But the rock is in a
**belt**, a star burns off to one side and lights everything from where it really is, and there
are planets in the sky: small faceted worlds in their own colours, some with moons, one with a
ring. Dust drifts past the canopy, so even in open space you can see that you are moving.

The bridge computer's map has a new range, **SYSTEM**: the star, every planet and moon, and the
belts, on the holo table. Pick a planet and set a course, and the HUD shows it. Fly there and it
grows from a dot into a world. You cannot land yet: its surface is a hard, faceted shell you bump
off. Landing is Planetfall, the next piece.

A system is about 300 km across, so a debug key hops you from body to body until cruise (piece 3)
exists.

---

## 2. Decisions

| Question | Choice | Why |
|---|---|---|
| What the system is made of | **Slots round the star, each a planet or a belt.** Moons round planets; rings on some. | A belt in place of a planet (like the real asteroid belt) leaves it room; squeezing belts between planets did not fit. |
| Where the rocks go | **Only in belts and rings,** plus today's thin sprinkle everywhere. | The umbrella's decision (§5 there). Groups, halos, streaming and bodies are unchanged. |
| How far bodies are seen | **All of them, always,** as proxies no further than 28 km, scaled to their true angular size. | No bigger far plane, no second scene (umbrella §6). |
| What a body is up close, before Planetfall | **A faceted shell with a convex collider.** | Flyable to and touchable, without terrain. Planetfall replaces the near look and the collider. |
| The star | **An emissive body; the sun's light comes from it.** | The light has a real source. Its glow is approved from renders (umbrella §13). |
| Colours | **Planet and star colours join `SpacePalette`.** | CLAUDE.md allows colours only from the three palettes. Space's palette is the right home, so no rule changes. |
| The sense of speed | **Space dust in piece 1,** not later. | Without it, open space between belts looks like standing still. |
| Getting round a system before cruise | **A debug hop key.** | 300 km at boost is 17 minutes. |

---

## 3. Architecture

```
flight_test
├── Universe                  unchanged
├── AsteroidStream            gains the system's belt and ring shapes (§6)
├── StarSystem                NEW: builds and places everything below, from a SystemRecipe
│   ├── Star                  a BodyProxy, emissive
│   ├── Bodies                a BodyProxy per planet and moon; a RingLook under ringed planets
│   ├── Belts                 a BeltLook per belt: the band seen from afar
│   ├── SpaceDust             flecks round the focus
│   └── Whereabouts           where you are (§8)
├── DirectionalLight3D        re-aimed from the star every tick (§7.4)
└── Ship                      hull and suit masks gain layer 4 (§7.3)
```

- **`SystemRecipe`** is pure: seed in, the whole system out as data (§4). No nodes; any thread.
- **`AsteroidShapes`** is pure: the belts' and rings' shapes, and how deep a point is in them.
  `AsteroidRecipe` reads it; it never sees the system (§6).
- **`StarSystem`** is the only node that knows the system. It builds the proxies, places them
  every frame, aims the sun and feeds `Whereabouts`.

### 3.1 Files

```
src/world/
  world_seed.gd          WorldSeed: sub-seed mixing (Planetfall §5.1)
  world_recipe.gd        WorldRecipe: what a seed decides about one world (Planetfall §5.2)
  world_names.gd         WorldNames: syllable names (Planetfall §5.2)
  system_recipe.gd       SystemRecipe: the star, slots, bodies, belts, rings, the entry
  system_body.gd         SystemBody: one body's data (no node)
  asteroid_shapes.gd     AsteroidShapes: belt and ring shapes, pure
  star_system.gd         StarSystem: builds and places everything outside that is not rocks
  body_proxy.gd          BodyProxy: one body's far and near look, placed every frame
  body_look.gd           BodyLook: faceted body meshes and collision points
  ring_look.gd           RingLook: a ring seen from afar
  belt_look.gd           BeltLook: a belt seen from afar
  space_dust.gd          SpaceDust
  whereabouts.gd         Whereabouts
src/sensors/
  body_contacts.gd       BodyContacts: every body, for the map and courses
```

Modified: `asteroid_recipe.gd`, `asteroid_stream.gd`, `rock_contacts.gd`, `space_palette.gd`,
`map_page.gd`, `computer_context.gd`, `ship.gd` and `avatar.gd` (masks), `save_game.gd`,
`flight_test.gd`/`.tscn`, `project.godot`, and `test_visual_style_rules.gd` (every new file that
paints joins its list).

---

## 4. The system recipe

`SystemRecipe.from_seed(seed)` returns the same system for the same seed, on any machine.
Each concern draws from its own sub-seed (`WorldSeed.sub(seed, &"star")`, `&"slots"`,
`&"slot_<i>"`, `&"moons_<i>"`, `&"ring_<i>"`, `&"belt_<i>"`), so tuning one never reshuffles
another. `SystemRecipe.VERSION := 1` is bumped when a seed's system changes.

### 4.1 The layout

The star sits at (0, 2.5 km, 0). The system is a flattened disc in the plane y = 2.5 km, y up: the
middle of a layer of the asteroids' 5 km giant cells, so a belt lies inside one layer (§16).

| Piece | Rule (first guesses, tuned by flying) |
|---|---|
| **Star** | Radius 2.5–4 km. One of the star palettes (§7.1). |
| **Slots** | The first at 30 km (±10%); each next one ×1.18–1.30 further out; none past 150 km. That makes 7–10 slots. |
| **Belts** | 1–2 slots become belts: never slot 0, never two side by side, and only where both gaps to the neighbouring slots are at least 12 km (failing that, the roomiest slot). |
| **Planets** | Every other slot: 5–9 planets. A seeded angle round the star, and a height off the plane of up to ±3% of its slot's radius. |
| **Planet recipe** | `WorldRecipe.from_seed(WorldSeed.sub(seed, &"slot_<i>"), PLANET)`: Planetfall §5.2 as written (radius 300–1200 m, gravity 2–8 m/s², archetype, palette, atmosphere, name), minus sites, which Planetfall adds under its own sub-seed. |
| **Moons** | 0–3 per planet, bigger planets more likely to have them. `WorldRecipe` with kind `MOON`: radius 120–400 m, gravity 1–4 m/s². Any direction from the planet (static, so no orbital plane); 6–14 km from its centre. |
| **Rings** | A quarter of the planets of radius 600 m and up. Inner edge 1.6–2.0 R, 1–2.5 km wide, 40 m half-thick, tilted up to 30° from the disc. |
| **Belts' shape** | A torus round the star at the slot's radius: 4–7 km radial half-width, 1.5–2 km half-thick. A planet beside a belt leaves it at least 3 km of half-width. |

### 4.2 Wells and neighbourhoods

Every body has a **well** of radius 3R (Planetfall §7.1: nothing uses it yet, but the layout keeps
room for it) and a **neighbourhood**, the space that belongs to it:

- **A planet:** the largest of 3R + 2 km, its farthest moon's distance + that moon's well + 1 km,
  and its ring's outer edge + 1 km.
- **A moon:** its well + 500 m.
- **The star:** its well + 4 km.

### 4.3 The rules the recipe keeps

1. **No two neighbourhoods overlap,** and a moon's neighbourhood lies inside its planet's.
2. **Moons are clear of each other's wells and of their planet's ring,** by 1 km.
3. **Belts are clear of every neighbourhood** by 1 km. A belt too wide for its gap is narrowed;
   one that would go below a 1.5 km half-width is dropped.
4. **The entry point is clear** (§4.4).

Placing a planet, the recipe tries up to 32 seeded angles to satisfy rule 1. If none works it
drops the planet's moons and tries again. If that fails too, the slot is left empty. Every retry
draws from that slot's own generator, so it never touches another slot. A test runs 500 seeds and
checks every rule on each (§13.1); in practice it should almost never leave a slot empty.

### 4.4 The entry point

The flight starts at the **entry** (the umbrella's jump arrival point, §10.3 there): the first
belt's first group, walking round the belt from angle 0. It keeps today's rule (asteroids spec
§17): 700 m off the big rock's surface, the rock dead ahead of a ship facing −z, 80 m kept clear.
Salvage's near cloud, the skitters on the start rock and every test built on them are unchanged.

### 4.5 The data

`SystemBody` (a `RefCounted`, no node): `id` (`&"star"`, `&"p3"`, `&"p3.m1"`), `kind` (`STAR`,
`PLANET`, `MOON`), `name`, `point: UniversePoint`, `radius`, `well_radius`, `neighbourhood`,
`recipe: WorldRecipe` (null for the star), `parent_id`, and `ring` (null, or its plane, inner and
outer radius and half-thickness).

`SystemRecipe` gives `star`, `bodies` (star first, then each planet followed by its moons),
`belts`, `entry()`, `body(id)`, `asteroid_shapes()` and `describe()`, a plain-text listing for
tests and for the owner.

**Names:** the star gets a syllable name (*KESTREL*), and the system is named after it. Planets
get Planetfall's generated names (*KORVA-7*). Moons take their planet's name and a letter
(*KORVA-7 b*).

---

## 5. How it feels to cross

| Trip | Distance | At 120 m/s | At 300 m/s boost |
|---|---|---|---|
| Start to the nearest planet | 10–40 km | 1.5–5.5 min | 0.5–2 min |
| Planet to its moon | 6–14 km | 1–2 min | 20–45 s |
| Across the system | about 300 km | 40 min | 17 min |

Until cruise arrives (piece 3), the hop key (§10) covers the long trips.

---

## 6. Asteroids in belts and rings

`AsteroidRecipe.new(seed, start, shapes: AsteroidShapes = null)`. With `null` it behaves exactly
as today, so tests of the recipe itself keep an open field to work with.

- **Belts carry the groups.** `density_at(u)` becomes today's shaped noise times the belt
  profile: 1 in the inner 60% of a belt's cross-section, easing to 0 at its edge, and 0 outside
  every belt. Big rocks, and the halos of mid-size rocks and rubble round them, therefore appear
  only in belts. `GROUP_LOW`/`GROUP_HIGH` are retuned so a belt's core holds groups every 3–6 km,
  as the open field does now.
- **Rings carry rubble and mid-size rocks, never giants.** `_keep_chance` gains a ring term:
  `RING_PEAK[tier] × ring_profile(point)`: 0.6 for rubble and for mid-size.
  The profile is 1 inside the ring's slab and eases off over its last 20%. Only rings whose
  bounds touch a cell are tested.
- **The sprinkle stays everywhere,** so the odd rock still tumbles past in open space.
- **Nothing inside a body:** every body whose sphere (radius × 1.1) touches a cell is a blocker
  in `_blockers`, so the existing overlap test keeps rocks out of stars, planets and moons.
- **Everything else is unchanged:** cells, tiers, the stream, pictures, detail, the physics
  bubble, herds and salvage.
- `RockContacts` builds its recipe with the same shapes, so the map's big rocks are the ones you
  see.
- `AsteroidRecipe.VERSION` goes to 2. An old save puts you back at the start (saving spec §8.1;
  §11 here).

---

## 7. Bodies

### 7.1 Colours

`SpacePalette` gains:

- **`WORLDS`:** Planetfall's eight world palettes (§5.3 there), each with `ground_low`,
  `ground_high`, `rock`, `dust`, `accent` and `sky`. Chosen from rendered proxies and approved by
  the owner, as Planetfall intended with swatches.
- **`STARS`:** three or four warm star palettes, each a body colour, a light colour and a light
  energy.

Dusty and warm like the rocks. The star is the one bright thing outside.

### 7.2 The look

`BodyLook` builds, from a body's recipe and sub-seed:

- **Far:** an icosphere subdivided twice (320 faces), flat-shaded. Each face takes `ground_low`,
  `ground_high` or `rock` by a seeded pattern over the sphere (bands for `RIDGED`, patches for
  `ROLLING`, a few big dark disks for `CRATERED`, flat plateaus for `MESA`), each in one of
  `SpacePalette.SHADES`. A little world, not a ball. Moons use their own palette, usually a
  dustier one.
- **Near:** the same pattern on an icosphere subdivided four times (5,120 faces), within 6 km of
  its surface. Built-in visibility ranges fade one into the other. Planetfall's terrain replaces
  it later.
- **The star:** an icosphere subdivided three times, with an emissive `StandardMaterial3D` in its
  body colour. No custom shader; its brightness is tuned from renders and approved by the owner.
- **No atmosphere yet:** Planetfall's shell comes with Planetfall.

### 7.3 Touching one

Within 6 km of its surface, a body gets a `StaticBody3D` with a `ConvexPolygonShape3D` made from
the near mesh's points: exactly the shell you see. It sits on physics layer 4, named `terrain` in
`project.godot` as Planetfall planned (§4.2 there). The hull's mask becomes 1, 4, 64 and the
suit's 1, 4, 32, 64, so both bump off it. `continuous_cd` is already on the hull. Beyond 6 km the
collider is removed. Nothing about the hull's feel changes: a body is a wall, like a giant rock.

### 7.4 Placing them: the proxy rule

Every frame, after the origin can have shifted, `StarSystem` places every `BodyProxy` from its
`UniversePoint` and the focus:

- `D` is the distance from the focus to the body's centre.
- **Within `PROXY_AT` = 28 km:** the body is where it is, at full size.
- **Beyond:** it is placed along the same direction at 28 km, scaled by `28 km / D`. Its angular
  size and direction are exact, so from the cockpit it looks exactly as the real thing would.
- 28 km lies beyond the giant rocks' fade (25 km) and inside the cameras' 30 km far plane. No rock
  is ever drawn beyond a proxy, so nothing is sorted wrongly.
- The two rules meet at 28 km, where they give the same position and size, so there is no pop.
- **Shadows:** a proxy casts shadows only within `AsteroidStream.SHADOW_REACH` (2 km). Far ones
  cast none, so there are no eclipses yet.
- **The floating origin:** each `BodyProxy` is a member of `Universe.EXTERIOR_SPACE`, directly
  under `Bodies`, which never moves (CLAUDE.md). It is placed afresh every frame anyway.

A system has 15–35 bodies at 320 faces each: under 40 draw calls, and placing them is a few
dozen conversions a frame.

### 7.5 Rings and belts from afar

- **`RingLook`:** a `MultiMesh` of 128 chunky slabs, 150–300 m across, in the ring's annulus, in `SpacePalette`
  rock colours, a child of its planet's proxy so it scales with it. It fades out as the real ring
  rocks fade in, when the focus nears the ring. The fade distance is tuned by render.
- **`BeltLook`:** a `MultiMesh` of 160 slabs, 1.5–3 km across, along the belt's centre circle. Each slab is
  placed by the proxy rule on its own. Slabs within 25 km of the focus are hidden, because the
  belt's real giants show there. From across the system, a belt reads as a broken band.
- Both are world-space members of `Universe.EXTERIOR_SPACE`, or children of one.

### 7.6 The sun

`StarSystem` re-aims the scene's `DirectionalLight3D` every physics tick: it points from the
star's centre to the focus, in the star palette's light colour and energy. Its shadow reach is
unchanged. Across a planet's neighbourhood the direction turns by a few degrees at most, so
shadows never visibly swing. This replaces Planetfall §7.4's fixed aim: the lit side of a world
is the side facing its star.

---

## 8. Whereabouts

`Whereabouts` works out where you are from the focus's `UniversePoint` and the recipe, ten times
a second:

- **Places,** innermost first: the ring of a planet, a body's neighbourhood (a moon's inside its
  planet's), a belt, and the system itself. A point can be in a belt and nowhere more specific.
- **Hysteresis:** you enter a place at its edge and leave it 100 m beyond, so nothing flickers.
- **Signals:** `entered(place)` and `left(place)`.
- **Queries:** `here() -> Array[Place]`, `text()` (*KESTREL › near KORVA-7 › in the ring*),
  `dust() -> float` (§9).
- **Its users in piece 1:** the F3 readout, the map page's second line, and the dust. Later ones
  (cruise, regions, toasts, sound) ask it too, never working out places for themselves
  (umbrella §3.1).

---

## 9. Space dust

`SpaceDust` is one `MultiMeshInstance3D`: **about 400 flecks** in a **200 m box** round the focus.

- **Fixed in the universe:** each fleck has a seeded place in the box's lattice. Its engine
  position is the focus plus `(fleck − focus) mod 200 m`, centred, computed from the
  `UniversePoint`'s whole metres so it is exact at any distance. Flecks stay still while you move
  past them, and wrap to the far side as you leave them behind.
- **Look:** chunky flecks 0.2–0.5 m across, in `SpacePalette` rock colours, lit by the sun.
  They shrink to nothing over the box's outer 20 m (per-instance scale), so the wrap never pops,
  and dither out within 3 m of the camera, so none sits on the canopy. No new shader.
- **How much:** `visible_instance_count = COUNT × Whereabouts.dust()`. First guesses: 0.25 in open
  space, 0.5 in a neighbourhood, 1.0 in a belt or ring. Regions (piece 4) add their own.
- **Cost:** one draw call, and 400 transforms written in one buffer a frame.
- **The floating origin:** a member of `Universe.EXTERIOR_SPACE`, placed afresh every frame.

It is seen through the canopy, in chase view and on a spacewalk, like everything outside.

---

## 10. Sensors, the map, and the hop key

- **`BodyContacts`** (new sensor source): one exact contact per body, kind `&"body"`, the body's
  name as its label, its radius as the contact's. Range: the whole system (400 km). Its ids are
  `body:<id>`, so `contact(id)` finds one at any range.
- **The map page** gains a fourth range, **SYSTEM (300 km)**:
  - `RANGES` = 2, 10, 30 and 300 km; its title reads *MAP · SYSTEM*.
  - The system range shows bodies only. The 30 km range shows big rocks and bodies. The two near
    ranges show everything, as now, plus any body in reach.
  - Bodies are balls sized by radius, with a floor so moons still show. The star is the largest.
    Their colour is a new `InteriorPalette` entry picked by render, distinct from rocks (`SKY`),
    salvage (`QUANTUM`), life (`SIGNAL_GO`) and the course (`AMBER`).
  - Each belt is drawn on the system range as a ring of 48 ticks, from the recipe that
    `ComputerContext` now carries.
  - `COURSE_KINDS` gains `&"body"`. A course arrives by the existing exact-contact rule (within
    `ARRIVE_ROCK`, 1 km, of the surface); Planetfall moves that to the well's edge.
  - The second line reads the whereabouts when no contact is selected.
- **The HUD** shows a course to a body as it shows any course: the diamond through the canopy, in
  chase view and on a spacewalk.
- **The hop key (debug):** **F7** puts the ship at rest 3 km off the surface (nearer a small moon,
  so you are in its neighbourhood) of the next body in
  order (star, then each planet and its moons), facing it. **Shift+F7** goes back. It is refused
  on a spacewalk and while the airlock is cycling. A hop is a teleport of the hull through
  `Universe`, so the origin follows and the rocks load before the next frame, as at the start.
- **F3's readout** gains the system's name and seed and the whereabouts line.

---

## 11. Saving

- `SaveGame.generators()` gains `"system": SystemRecipe.VERSION`, and `"asteroids"` becomes 2.
- **A save from before this piece starts over,** under the existing rule (saving spec §8.1): the
  rocks it knew have moved into belts, so the ship goes back to the start, and what was aboard is
  kept. The owner's current game is affected (§15).
- The world part stays `{"seed": …}`: that one seed makes the system, and the rocks with it.
- Bodies have no state yet. Planetfall's `WorldState` adds it, per body id.

---

## 12. The look, and the style guide

The style guide gains a section, **Worlds and the star from afar**, written from the renders the
owner approves:

- bodies faceted and flat-shaded, colours from `SpacePalette.WORLDS` only;
- the star is the one emissive thing outside, its glow approved from renders (umbrella §13);
- belts and rings from afar are chunky slabs, never particles;
- dust is chunky flecks, lit, never glowing, never streaks until cruise.

**Renders for the owner** (CLAUDE.md: the real scene, at the 1.6 m eye height, from the pilot's
seat through the canopy):

1. the start: the belt's big rock ahead, the star and at least two planets in view;
2. a planet from 25 km, then from 3 km, with a ring;
3. a moon beside its planet;
4. a belt from the far side of the system;
5. the star from 40 km and from 8 km;
6. dust going past at boost in open space and in a belt (still frames);
7. the eight world palettes and the star palettes side by side on proxies.

---

## 13. Testing

### 13.1 Automated (GUT, headless, output pristine)

- **`test_world_seed.gd`:** sub-seeds are stable and independent; FNV-1a and SplitMix64 match
  known values.
- **`test_world_recipe.gd`:** determinism; ranges for `PLANET` and `MOON`; each concern keeps its
  values when another's draws change.
- **`test_system_recipe.gd`:**
  - the same seed gives the same `describe()`;
  - over 500 seeds, every rule of §4.3 holds, slot counts and planet counts are in range, and
    empty slots are reported;
  - the star is at (0, 2.5 km, 0); the entry is 700 m off a big rock in the first belt.
- **`test_asteroid_shapes.gd`:** belt and ring profiles at known points; bounds are
  conservative.
- **`test_asteroid_recipe.gd`** (added):
  - with shapes, no group outside a belt;
  - ring rocks lie inside the slab, and no giant is in a ring;
  - no rock inside a body;
  - `null` shapes reproduce today's rocks exactly (the existing tests keep passing).
- **`test_body_proxy.gd`:** the proxy rule keeps direction and angular size to 1e-6; the two
  sides meet at 28 km; a shift changes nothing you can see.
- **`test_space_dust.gd`:** flecks keep their universe places as the focus moves and across a
  shift; the wrap is exact far from the origin (at 10⁹ m); the density follows `Whereabouts`.
- **`test_whereabouts.gd`:** places at known points; nesting; hysteresis; the signals fire once.
- **`test_body_contacts.gd`:** a contact per body; lookup by id at any range.
- **Map page tests:** the fourth range, its title and targets; belts as ticks; a course to a
  body arrives within 1 km of its surface.
- **`test_floating_origin_scene.gd`:** needs no new test. It already fails if anything outside is
  not covered, so proxies, looks and dust must all be covered.
- **`test_visual_style_rules.gd`:** the new painting files join its list, so their colours can
  come only from palettes.
- **The scene:** the `.tscn` edits are read back at runtime (CLAUDE.md).

### 13.2 Live checks

- Hop round the whole system with F7: no frame over 33 ms, and every body lit on the side facing
  its star.
- Fly from 40 km into a planet's ring at boost: no proxy pop at 28 km, rocks loaded before they
  show, a bump off the shell.
- **Budget:** the interior at least 120 fps with the canopy view (style guide §2.6), and 60 fps
  outside in the worst case (aboard, in a ring, a ringed planet and the star in view), measured
  and written into the style guide's performance section.

---

## 14. Build order

Each step ends flyable:

1. **The recipe on paper:** `WorldSeed`, `WorldRecipe`, `WorldNames`, `SystemRecipe`,
   `SystemBody`, `AsteroidShapes`, and `describe()`. All tests of §13.1 for them. Nothing in the
   scene changes yet.
2. **Rocks in belts and rings:** `AsteroidRecipe` and `RockContacts` take the shapes; the start
   moves to the entry; save versions bump. *Fly the first belt.*
3. **Bodies:** `StarSystem`, `BodyLook`, `BodyProxy`, the star, the sun's aim, colliders and
   masks. *See the star and planets, fly to one, bump off it.*
4. **Rings and belts from afar,** and **space dust.**
5. **Whereabouts, contacts, the map's SYSTEM range, F7 and F3.**
6. **Renders for the owner (§12), palettes approved, the style guide written, budgets
   measured.**

Each step also updates the documents it amends, and the `building-a-ship` skill gains the hull's
new mask (CLAUDE.md).

---

## 15. The owner's answers (2026-09-28)

1. **The current save starts over** (§11): yes.
2. **F7 / Shift+F7** for the debug hop: good.
3. **The star up close** stays a hard shell you bump off: OK for now. Heat waits for damage.

---

## 16. What was built (2026-09-28)

Built on `claude/universe-structure-scope-cmtzfk` in the order of §14. The numbers above are the
built ones. Where the build differs from the first draft of this spec, and why:

- **The disc sits at y = 2.5 km, not 0.** The asteroids' 5 km giant cells meet at y = 0, and a
  big rock's centre stays 525 m inside its cell. A belt centred on a cell boundary left its big
  rocks almost nowhere to go. Centred in a layer, it holds a group every 5 km or so along its
  centre (`test_asteroid_recipe_system.gd`).
- **Belts are fatter** (4–7 km half-width, 1.5–2 km half-thick). One big rock per 5 km cell is
  the ceiling, so a belt needs about 25 km² of cross-section to hold a group every 5 km.
- **Belts only where there is room.** The first rule (any slot but 0) left 155 empty slots in
  500 seeds: inner slots are only 5–9 km apart, too close for a belt and a planet. With the 12 km
  gap rule, 500 seeds give no empty slots, about 6.6 planets, 5.8 moons and 1.2 rings each.
- **A big rock is kept by the belt's depth at its own place,** not at its cell's centre, which
  can lie outside the belt when the rock is inside it.
- **Rings hold 0.6 of rubble and mid-size candidates at their heart;** at the first guesses a
  ring read as bare.
- **Shade comes in broad patches** (a cellular noise over the sphere), the same at every detail.
  The first build shaded triangle by triangle, and up close the 5,120-face look read as noise,
  against style guide §3.5.
- **Dust and belt slabs are worked out again only after the focus has moved** 20 m and 250 m.
  Placing everything every tick cost 1.2 ms a physics tick at boost; now 0.25 ms at boost and
  next to nothing at rest (measured headless on the build machine's CPU, seed 1337: 12 bodies, one
  belt). Building the system's looks takes about 25 ms, once.
- **`AsteroidDetails.nearest(at)`:** in a belt more than one big rock can be in detail at once,
  so the NPC and life-sign tests find the start rock by distance, not as the first in the list.
- **Loose items outside** bump off worlds' shells too: `Item.SPACE_MASK` gained the `terrain`
  layer, as `AsteroidBody.MASK` did.
- **The hop** stops nearer a small moon than 3 km, so it lands inside the moon's neighbourhood.
- **No new scene edits:** `StarSystem` is built in code by `flight_test.gd`, and layer 4 is named
  `terrain` in `project.godot`.

Still to do: the owner's approval of the renders (§12), and then the style guide's section;
frame rates measured on the GTX 960 (the renders here came from a software renderer); and the
amendments §14 lists, noted at the head of each spec they touch.
