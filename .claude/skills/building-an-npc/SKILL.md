---
name: building-an-npc
description: Use when adding or changing an NPC in the who-knows Godot project - a new creature, droid, crew member, wingman or world fauna; a new behaviour, need, sense, stimulus, locomotor, look, population or site; or wiring NPCs into a new space (another ship, a wreck, a world). Also when an NPC pops into view, is left behind by the floating origin, falls through or floats off a rock, snags on a doorway or edge, settles at 45° in a corner, dithers between behaviours, never reacts (or never stops reacting), won't step aside, walks through a shut door, reads as the wrong thing in renders, or blows the frame budget.
---

# Building an NPC

## Overview

An NPC is **five layers**, and a new NPC swaps layers rather than writing a new stack:

| Layer | What it is | Where |
|---|---|---|
| Existence | `NpcRecord` (pure data, from a seeded population recipe), made live by an `NpcDirector` | `src/npc/npc_record.gd`, `npc_director.gd`, `populations/` |
| Body | `Npc` (a pooled `CharacterBody3D`), its look, one active `Locomotor` | `npc.gd`, `*_look.gd`, `deck_walker.gd`, `surface_crawler.gd`, `zero_g_drift.gd` |
| Senses | `Perception` fills `NpcMemory` from a `StimulusBus`, sight and lights | `perception.gd`, `npc_memory.gd`, `stimulus_bus.gd` |
| Mind | `Brain`: needs rise, `Behaviour`s score, reflexes pre-empt, one `Intent` a think | `brain.gd`, `behaviour.gd`, `behaviours/` |
| Data | `NpcSpecies` `.tres`: ids name the code | `npc_species.gd`, `data/npcs/*.tres` |

The rules that make it work: **the mind never touches physics** (it writes an `Intent`; the
locomotor moves), **the mind never reads the world** (only its memory, needs and what its
`NpcSite` puts in the `NpcContext`), and **only the site knows the place** (frame, gravity,
where a record wakes, mates, shelter, jobs).

Two worked examples, one per space. Read the one nearest to what you are making:
- **The maintenance droid** (inside): `data/npcs/maintenance_droid.tres`, `ShipCrew` +
  `ShipSite`, `DeckWalker` over `DeckPaths`, `behaviours/{tend,roam,recharge,give_way,notice,
  startle,brace,keep_away}.gd`, `DroidLook`.
- **The skitter** (outside, 1.3 m, found with the ship's life sensor): `data/npcs/skitter.tres`, `RockHerds` + `RockSite` +
  `RockHerdSource`, `SurfaceCrawler` + `ZeroGDrift`, `behaviours/{graze,wander,stay_with_herd,
  freeze,scatter,hide,investigate,rest,drawn_to_flare}.gd`, `SkitterLook` + `LeggedGait`.

**Read first:** `CLAUDE.md` (style guide binding; floating origin; no `#` in `.tscn`/`.tres`),
`docs/superpowers/specs/2026-09-26-npc-foundation-design.md` (§2 the layers, §21 *As built*: why
the code differs from the text), `docs/design/visual-style.md` §3.6, and `reference.md` beside
this file (every API, number and test pattern). `templates/` has starting files.

## Decide before you build

Answer these, in the spec or the task, before writing code. Each answer picks existing parts.

1. **Which space?** Outside (exterior director, `BY_DISTANCE`, floating origin) or inside a ship
   (that ship's director, `BY_SITE`, never shifts)? A new kind of place (a wreck, a world) means a
   new site and maybe a new director.
2. **Which place does it belong to, and how many?** That is its population recipe and site: an
   existing one (`RockHerds`/`RockSite`, `ShipCrew`/`ShipSite`) or a new pair.
3. **How does it move?** `DeckWalker` (floors under gravity), `SurfaceCrawler` + `ZeroGDrift`
   (any surface in zero g, leaping and puffing), or a new locomotor (§ *Recipes*).
4. **What does it sense?** Sight (range, cone, `dark_sight`, `near_sense`), light response,
   vibration (through its own rock only), sound (air only), shake (a ship's felt gravity), touch.
5. **What does it need, and what does it do?** Needs with rise rates; behaviours and which are
   reflexes. Reuse behaviours by id where the meaning fits (a new species can list `startle`).
6. **What does it look and sound like?** Palette of its space; silent outside.
7. **How does the player find it?** If it is small or rare, give it a sensor source (as
   `LifeContacts`): a ping far off, a region close by, then the player looks (§ *Recipes*).
8. **What can the player do to it?** Nothing yet unless asked: the interaction seam exists
   (`species.interactions`, empty).

## Checklist

Do these in order. Each names the check that proves it.

1. **Species `.tres`** from `templates/species.tres` in `data/npcs/`. Every field set, **no `#`
   comments**. Proof: a read-back test of every property (as `test_npc_species.gd`), and the
   catalogue test `test_npc_catalog.gd` (every behaviour, locomotor and look id exists).
2. **Population and site.** Records are pure: same place, same records, stable unique ids
   (`"<species>:<site>:<group>:<n>"`), homes in the **site's frame**, never engine positions.
   If the place is stretched or curved, keep each record's generating direction (the skitter
   lesson). Proof: determinism, uniqueness and on-the-surface tests (as `test_rock_herds.gd`,
   `test_ship_crew.gd`).
3. **Wire a source into the right director** (`sources`), or make a director for a new space
   (holder that never moves, `catalog`, `bus`, `rule`, `max_live`, `cameras` outside). Proof: a
   director test with a fake source and site (as `test_npc_director.gd`), then the real scene.
4. **Movement.** Pick locomotors; add new ids to `Npc.make_locomotor`. Proof: test shapes built
   in the test (cube edge, sphere, corner, moving footing; or the real interior), as
   `test_surface_crawler.gd` / `test_deck_walker.gd`.
5. **Senses and emitters.** Set the species' senses. Anything new in the world that an NPC should
   notice gets **one line**: `StimulusBus.send(self, Stimulus.make(kind, pos, strength, radius,
   source, site))`, or joins `StimulusBus.LIGHTS` with the four light methods. Proof:
   `test_perception.gd`-style tests with a fake site.
6. **Behaviours** from `templates/behaviour.gd`, one file each in `src/npc/behaviours/<id>.gd`
   (the file name *is* the id). Scores from `Curves` on needs and `ctx.recent(...)`; the site's
   helpers through `ctx.places` / `ctx.extra`. Proof: each scored from a made-up context
   (`templates/test_behaviours.gd`), and `test_brain.gd` stays green.
7. **Look** in `NpcLooks.build` (a match on the look id), colours only from its space's palette
   (add constants there), a class with `act(action)` for moving parts. Add the file to
   `PAINTING_FILES` (and `REUSABLE_FILES` if it builds like a prop) in
   `test_visual_style_rules.gd`. Outside: distance fade reversed (min = `fade.y`, max =
   `fade.x`), render layer 1. Inside: the interior kit, layer 2, glow batch, no light of its own.
   Proof: `test_npc_looks.gd`-style tests (triangle budget, palette, layer, fade, parts move).
8. **Sound** (inside only): new `Synth` builders, `species.move_sound` for a loop, behaviours set
   `ctx.voice`. Proof: `test_synth.gd` lengths.
9. **Run the whole suite.** Masks and the floating-origin coverage test catch a lot.
10. **Real-scene tests:** it wakes where it should, unseen (outside: beyond its fade from every
    camera); sleeps when you leave; holds its place through `Universe.shift`; reacts to the
    player in the scene (as `test_droid_scene.gd`, `test_exterior_npcs.gd`). Add it to
    `test_floating_origin_scene.gd` if it lives outside.
11. **Frame time:** adapt `test/probes/npc_probe.gd` to fill its director to `max_live` and
    time all NPC work over 600 frames. Budget: **1 ms** for everything (spec §16). Report the
    machine. If over, see *Mistakes* (resting, LOD, no slides, caches).
12. **Render and show the owner** with a script like `test/probes/droid_render.gd` /
    `skitter_render.gd`: inside at eye height (1.6 m), outside from a spacewalk, lamp on and off,
    and each reaction caught mid-act. Print the counts (how many froze, scattered). Green tests
    prove structure, not looks: the droid read as part of the walls and the skitter as a spider
    until they were rendered.
13. **Update this skill and the spec's *As built*** in the same branch: new checks here, new
    lessons in *Mistakes*, new numbers and APIs in `reference.md`.

## Recipes

- **A behaviour:** copy `templates/behaviour.gd` to `src/npc/behaviours/<id>.gd`, list the id in
  the species, test it from a context. A reflex sets `reflex = true` and a `threshold`; anything
  that must interrupt a job in progress has to be a reflex (the brain holds an ordinary
  behaviour for its `min_time`). Walking somewhere: `Intent.go(site_local_point, speed_fraction,
  action)`; facing: `.facing(point)`; a sound: `ctx.voice = &"..."`; finishing a job:
  `ctx.extra[&"tended"].call(key, ctx.time)`.
- **A need:** add it to the species' `needs` (rise per second) and `need_start`; ease it in the
  behaviours that satisfy it (`ctx.ease(n, rate)`), or passively in the site's `fill` (fear and
  company fade there).
- **A population and site:** copy `templates/site.gd`. A pure static recipe makes records; the
  site answers `frame`, `gravity`, `alive`, `start_pose`, `tint`, `fill`. Outside, a source class
  (like `RockHerdSource`) offers records only for places near an anchor and caches one site per
  place.
- **A locomotor:** extend `Locomotor` (`enter`, `step`, `exit`, `handover`, `grounded`,
  `shoved`), add its id to `Npc.make_locomotor`. Hand over by returning the other id; pass data
  by setting fields on the other locomotor first (as the crawler sets `ZeroGDrift.leap_to`).
  Keep a resting path that does nothing.
- **A stimulus kind:** add a constant to `Stimulus`, a case in `Perception.feel` with a species
  sensitivity field, and emitters.
- **Making it findable:** a source class with `contacts(focus, range_m, time)` and
  `contact(id, focus, time)` that turns each group into a `Contact` with
  `Sense.read(profile, focus, target, id, time)`; a `SenseProfile` for its kind (reach, where
  regions start, region radius, and an offset no bigger than the radius less the group's
  spread); `_ship.sensors.add_source(...)` in `flight_test.gd`; a colour in `HudPalette.for_kind`.
  `ContactMarker` draws it with no change.
- **An interaction** (only when the owner asks): a class with `can`, `prompt`, `run`; its id in
  `species.interactions`; route it in `Npc.interact`/`prompt_text`/`can_interact`; add `npcs`
  (128) to the `Interactor`'s mask.
- **A new space:** a director and a bus beside it; bus `setup(space_root, universe_or_null)`. The
  bus lookup picks the deepest `space_root`, so an interior's bus beats the exterior's for
  anything aboard. Outside, every NPC joins `Universe.EXTERIOR_SPACE` itself (`Npc.setup` does
  it when `inside` is false).

## Mistakes already made (don't repeat)

| Mistake | What happened | Do instead |
|---|---|---|
| A door trigger that sees only the avatar | Doors have no collider; the droid would walk through them shut | Triggers include layer 128 (`SlidingDoor.OPENS_FOR`) |
| Rounding corners in a corridor | The droid clipped the closet's door frame and stuck | `DeckWalker` walks cell centre to centre, from its own cell's centre |
| An ordinary behaviour for stepping aside | A job it had just started held it in your way for 6 s | Anything that must interrupt is a reflex (`give_way`, threshold 0.8) |
| Sight by cone alone | It never noticed you coming up behind it in a corridor | `species.near_sense`: all round within a few metres |
| A pull toward the surface (m/s²) | Speed into the surface built up; it flew off the first edge | While gripping, move only along the surface, pressed on at `STICK` |
| Averaging the normals under and ahead equally | Settled at 45° in every corner and on every edge | The ground ahead leads (`LEAD` = 6) |
| `move_and_slide` against a big rock | 64 µs a call on a 5,000-triangle mesh: three times all its rays | Gripping: step, then settle onto the ground a ray finds |
| A point's direction from a stretched rock's centre | Homes and wake points off the surface by metres | Keep the direction that made the point (`RockSite.dirs`) |
| Waking on the exact surface | The collision mesh sits outside it in hollows: under the mesh, falling through | Find the solid ground with a ray (`RockSite.pose_at`) |
| Everything every tick | 4.5 ms for 32 skitters | Resting does nothing; LOD by camera distance (`NpcDirector.set_detail`); legs posed rarely when far |
| The exact surface asked every think | `surface_point` costs ~40 µs in GDScript; ten a think for shelter | Cache per site (crater floors, rounds per second) |
| Walking every live NPC for herd mates | Think cost grew with the live count | `NpcDirector.herd_of(npc)` |
| Waking and demoting in one review | A demoted record was woken again at its home at once | A record demoted in a review is not woken in it |
| "It's standing still" from `velocity` | The press onto the surface counted as motion; nothing ever rested | Measure speed along the surface |
| Leaving unplated cells off the droid's map | `gravity_at` said the front of the bridge was unplated, so the droid never went there, though you and loose items feel the same gravity everywhere aboard | Trust the felt gravity the NPC actually reads; don't filter the map by a number nothing else uses |
| Assuming the ship's layout stays put | Main added the quantum core and machine as fixtures; with the helm they walled the droid off from the starboard bridge, and the avatar's spawn moved onto its route. The bridge computer's table then walled off the port side too | Filter jobs to those reachable (`ShipCrew.reachable_spots`); keep the probe's `UNREACHABLE` line; in hand-driven tests, stand the avatar out of the way. `DeckPaths` now steps diagonally between two quiet fixtures, so on the starter every job is reachable again |
| No way to find it | Herds existed on 90 of 114 rocks and were awake as you came near, yet the owner found none | Small or rare things get a sensor source and a HUD mark (§22), and a look that stands out once you are close |
| Rendering only close up | The skitter renders were taken 3–8 m away; on the PC the owner visited several rocks and never saw one. A herd is on average 200 m from you, and at 40 m a 0.85 m skitter is smaller than the scree round it | Render from where the player will be (the cockpit 40–100 m off, a random spot on a spacewalk) and ask "would I notice it?"; check how far the nearest one usually is |
| World-sized overlay labels | F4's text was 6 cm tall: unreadable past a few metres, useless for finding a herd | `Label3D.fixed_size`, one short line far off, full detail within 30 m; ASCII only (the default font has no block glyphs) |
| Beige droid, long skitter legs | Read as a bin and a spider | Render early; contrast with the space; short, clamped legs |
| Feet trailing a bolting body | Legs stretched to reach them | Clamp each foot to the leg's reach |
| `push_warning`/`push_error` in a test | GUT fails the test on an unexpected engine error | `assert_engine_error(...)` / `assert_push_error(...)` for expected ones |
| Colour literals in a look | `test_visual_style_rules.gd` fails | Palette constants only, also for defaults (`SpacePalette.UNTINTED`) |
| A Variant-typed `:=` | GDScript treats the warning as an error; the whole script fails to load | Type it: `var x: Variant = ...` |

## Not built yet (plan for it; don't assume it works)

- **Memory across loads.** Nothing is remembered when an NPC sleeps; `NpcDirector.amend(record)`
  is where a ledger of changes plugs in.
- **Damage and death** (Slice 2). `Npc.receive_hit` only shoves and touches.
- **Local avoidance.** A walker does not path round people: a droid heading through you steps
  aside (`give_way`) and tries again. A player standing still in a doorway blocks it.
- **Ladders and upper storeys for walkers.** `DeckPaths` joins one storey only.
- **Interactions** beyond the seam; the hose; carrying an NPC.
- **Sound outside** (never, by the style guide) and **sensors** (`LifeContacts` for the bridge
  computer).
- **Hostile NPCs and combat**, `GroundWalker` (worlds), `ShipPilot` (wingmen).
- **The frame budget on the target PC.** Measured 1.2 ms for 32 + the droid on a shared 2.1 GHz
  Xeon; unmeasured on the GTX 960 machine.
