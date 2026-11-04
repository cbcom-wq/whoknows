# The desert world: planets that feel like planets, and the first one made by hand

**Date:** 2026-11-03
**Status:** Designed with the owner on 2026-11-03, in conversation, and approved the same day. The
owner lowered the heaviest planet's gravity to 7 m/s² (§5.4) and left the calls of §14 to the
designer, so they stand as written.
**Depends on:** `main` at `b280fa5` (world scale, the airlock, many ships, saving, NPCs, habitat
bases, health and damage, hostile ships).
**Builds most of the rest of:** Planetfall (`2026-09-23-planetfall-design.md`). Its terrain was
built by the world scale spec. Gravity, the assisted descent, landing, the step-out, walking,
boulders, sites and the atmosphere never were. Phase 0 here builds the first five, brought up to
date, and phase 2 folds in boulders. Phase 1 **replaces** Planetfall §7.3 (air that is only for
looks). Planetfall's sites, signals, discovery log and surface readout (§12–§13) stay unbuilt and
stay Planetfall's.
**Builds:** star systems spec §9 (hand-made worlds in a generated system), the *tweak* and
*stamp* depths, as its step 5.
**Governed by:** `docs/design/visual-style.md`, and CLAUDE.md's rules on the floating origin, on
every ship being usable, and on `.tscn`/`.tres` comments.
**Pictures:** `2026-11-03-desert-world/descent.html` (the descent the owner approved),
`2026-11-03-desert-world/oasis-layout.html` (the oasis, approved), and
`2026-11-03-desert-world/beast-concept.webp` (the owner's concept art; the beast is later, but
this is the land it lives in).

> **Status, 2026-11-04: phase 0 is built** (branch `desert-world`, to merge after the owner's
> look). The skills (`building-a-ship`, `designing-a-ship`, `building-an-npc`) record it.
> Phases 1 to 3 are not started.
>
> **Differences as built** (each is a ruling in the branch's progress file):
> - **The hold is per axis (Ruling 4).** Boost raises an axis's ceiling to 2.5 times its budget
>   only where the pilot pushes or a velocity hold is set. Every other axis stays at 1 times, so
>   hold plus command never pass the budget.
> - **Levelling goes by height only (Ruling 6).** It fades in from 150 m to 100 m over the keel and
>   not by speed. A pilot who dives low must hold the stick to keep the nose down. Revisit at
>   playtest.
> - **On the ground, weight reaches the ground (Rulings 2, 7a).** LANDED freezes the hull and you
>   leave it only by translating. While LANDED, or TOUCHING with terrain contact this tick, the
>   hold and the levelling stand down if the stick's translation is centred. Any translation input
>   brings both back at once.
> - **Touchdown is not a crash (Ruling 8).** Terrain deals crash damage only above 10 m/s
>   (`Ship.TERRAIN_CRASH_FROM`); everything else still from 2 m/s. A 6 m/s touchdown had dealt
>   665 hp. It now deals 0.
> - **The hatch cast clears small bumps (Ruling 10).** The capsule's bottom is 0.45 m over the
>   outer hatch floor, so ground a walker can step over does not read "Hatch blocked".
> - **Hostiles keep above the air (Ruling 11)** by 2 km, for `Sides.HOSTILE` only. Your own ship
>   flown by its pilot is free to land.
> - **Strays freeze at rest on a world (Ruling 12)**, since the ground has no collider far from an
>   anchor.
> - **A landing ramp, added in the branch.** The plan had you jump into a landed ship. A landed
>   starter's hatch is **2.05 m** over the ground (the keel row under the cabin), a jump peaks at
>   0.89 m, and nobody could get back in. The owner chose a ramp (2026-11-04). Every horizontal
>   outer hatch over 0.45 m above the keel gets one: 30°, `sill / sin 30°` long, 4.10 m on the
>   starter. It lowers when the ship lands on a world and stows as it lifts off.
> - **The head lamp spares your hands.** The hands are on `Avatar.HANDS_LAYER`, so the lamp does
>   not wash them white. And the HUD on foot says `SUIT n%`, not the spacewalk's "returning".
>
> **Measured** (`test/probes/landing_play.gd`, GTX 960, 1280 by 720, windowed; the floor is 120
> fps): **140 fps** seated at the helm on the ground; **177** standing 6 m off the ship; **149**
> at the foot of the ramp looking up it. The Warden (265 t, the heaviest) levels from 15° to
> **0.03°** with no overshoot, and touchdown damage is **0**.
>
> **Known gap: the Warden cannot be boarded on a world (Ruling 14).** Its hatch is 4.05 m over the
> keel; its 8.1 m ramp would come down through its RCS block at (-4, -1, 2), so none is built.
> You can land it and step out, not walk back in. The fix is a reshape through the `ship-designer`
> agent after this branch merges. Boardability is a printed line (`ship_check`, `ship_probe`), not
> a `ShipRules` rule yet.
>
> **Open for phase 1:** the sky is black; the hover puff reads as a white blob; the help card
> shows the pilot's keys while you are on foot; and step 10 of the probe (a spacewalk in a ring)
> is untested because no planet in the seeded system had a ring (it flies up through the air top
> instead).
>
> **Notes for phase 3:**
> - **Override `Base.on_world()` and `Base.outside_refusal()`.** `GridHome` returns false and "".
>   Without that, a base on a world steps you out in SUIT mode and asks for a charge.
> - **A base can build a ramp that nothing lowers.** A ramp comes down from `Ship._sync_ramps`
>   only. A `Base` with a high hatch would build one that stays stowed, so give it its own call.
> - **Items taken by hand from another shift field stay in `EXTERIOR_SPACE` while held.** Placed
>   oasis items must handle that.
> - **Hover puffs and the floating origin:** a hovering ship's RCS puffs are in `HOLDS_SHIFT`, and
>   in a well the hold puffs all the time, so a re-centre may always wait for the forced one at
>   4 km. Read from the code, not measured.

---

## 1. Why

The owner, 2026-11-03:

> Currently we fly down to a surface and it still feels like we are on an asteroid. The sky still
> looks raw, space [dust] still suspend next to the surface, but we need a planet to feel like a
> planet like you are no longer in space. So there needs to be this transition as you descend to
> a surface and a different feel once there.

The owner wants to improve planets in general and, along the way, build one planet by hand. It
started as a water world with islands. It became **a desert with a small oasis settlement**
because an ocean is the biggest single piece (§13). The ocean world comes later, on what this
builds.

Today a world is bare seeded rock. Nothing pulls you toward it. You skim its ground and bump off
it. The sky is black down to the horizon, and space dust hangs over the sand. A world rolls an
atmosphere (`WorldRecipe.atmosphere`), but nothing draws it.

## 2. The moment this is for

You warp in. Far out, the desert world has a soft warm glow round its edge, so you can see it
has air. Falling in, the black overhead turns deep blue with a warm band along the horizon. The
stars fade, the dust thins and goes, and a rush of wind starts. Lower down, it's a full sky:
pale blue overhead, sandy haze at the horizon. Far mesas fade into the haze. The ship feels the
pull of the ground. Below there's a glint of water and palms.

You set down on a packed-stone pad outside the oasis, step out of the airlock and hear the wind.
You walk into a village that was left in a hurry. A hut is crushed. The outer wall is knocked
through from the desert side, with huge tracks leading off into the dunes. Inside four of the
buildings you find what the settlers dropped as they ran. In the comms hut, a datapad's last
entries tell you what drove them out.

The thing that drove them out is **the beast** (`beast-concept.webp`): big, four long arched
legs, an armoured spiny back, a tusked head, sand-coloured. **It is not in this project.** It
gets its own design next. Here it is only a story, told by tracks, damage and the log.

## 3. Goals, non-goals, anti-goals

**Goals**
- Standing on a world: gravity, a descent the assist helps with, landing, stepping out and
  walking. On every world, not just this one.
- **A world with air feels like a planet, not space:** the descent of §6, on every world with
  air.
- A desert style the generator can roll for any world: dunes, mesas, rock towers, boulders, dry
  grass, a warm sandy sky.
- Hand-made worlds: a seeded base with hand-placed pieces on top.
- The first one: the desert world, its oasis, its village, things to find, and the log.

**Non-goals (later, each its own design)**
- The beast, and the fight with it.
- People in the village.
- The ocean world: a sea level round a whole world, shorelines, landing on water, swimming.
- Day and night cycles, weather and storms. Worlds still neither spin nor orbit.
- Wings, lift and flight that depends on air beyond light drag. Heat damage on entry.
- Hand-built worlds that break the round-world rules (star systems §9.2's third depth).
- Hostile ships flying down into the air (§5.7).
- Planetfall's sites, signals, discovery log and surface readout.
- Planting habitat bases on a world (`PlantSurface`'s planet ground). Bases stay on rocks.
- Oxygen, or any other limit on time on foot (§5.5).

**Anti-goals (a failure even if it works)**
- **It still feels like space on the ground.** If you can stand at the oasis and see stars
  overhead, or dust hanging in the air, it has failed.
- **It drifts from the house style:** realism, textures, noise on surfaces, photographic skies.
  The desert is chunky, faceted, flat-coloured and lit by a warm sun, like the concept art.
- **Hand-made means look-only.** Every building you can walk into is a real place you can save
  in. Every item you find is a real item.
- **A world strands a ship.** Never land somewhere the ship can't leave.
- **Existing worlds change under the player.** The seeds that make today's worlds keep making the
  same worlds (§7.4).

## 4. Decisions

Each line says whose decision it is. *Owner* means decided by the owner in the conversation of
2026-11-03. *My call* means a sensible default the owner hasn't ruled on. Those are listed again
for the owner in §14.

| Decision | Choice | Whose |
|---|---|---|
| Handcrafted or generated | **A seeded base with hand-made parts on top.** A fixed place, the same every visit | Owner |
| Which world first | **A desert with a small oasis settlement**; the water world later | Owner |
| The descent | **The four stages of `descent.html`**: approach, into the air, flying low, on the ground | Owner (from the mockup) |
| Sound outside | **Air carries sound on a world too:** wind on the way down and on the ground. Space stays silent. Changes style guide §2.9 | Owner (from the mockup) |
| What air does to flight | **Light drag, and a glow and a little shake on a fast entry. Nothing else** | Owner |
| The settlement | **The layout of `oasis-layout.html`.** Empty of people; things to find; the beast's damage | Owner (approved my proposal) |
| The creature | **Large, menacing, terrorised the village; something you fight and kill. Designed later** | Owner |
| Order | **Phase 0 standing on a world, 1 air, 2 desert, 3 the world** | Owner |
| Planetfall | **Its unbuilt half is folded in as phase 0, not redesigned** | Owner |
| Heaviest planet | **7 m/s², down from 8**, so the starter lifts off any world with margin (§5.4) | Owner |
| The calls marked *my call* | **Accepted as they stand** (§14) | Owner |
| Where the world is | **One of the planets of the system you start in, a warp away** | My call |
| Which buildings you enter | **Four:** two homes, the workshop and the comms hut | My call |
| What buildings are made of | **The enterable ones are bases** (grids that never fly), so they get the game's interiors | My call |
| Items to find | **From the existing catalogue**, placed by hand; taken stays taken | My call |
| The log | **A datapad whose last entries you can read**; text drafted in §8.7 | My call |
| Hostiles near worlds | **Stay above the air for now** | My call |

## 5. Phase 0: standing on a world

Planetfall §7–§11 designed this and the owner approved it on 2026-09-23. Build it as designed,
with the changes below. The world has changed since: a floating origin, worlds 15–60 km across,
many ships, NPCs, loose items, saving, the airlock and the hostile pilot. Where this section is
silent, Planetfall's text stands.

### 5.1 Gravity: one source

- **Every world pulls**, at its recipe's `surface_gravity` at the ground, falling off with the
  square of the distance from the centre, out to the well's edge (`WorldRecipe.well_radius()`, 2
  radii). Deep space stays at zero. One world pulls at a time: wells never overlap (star systems
  §4.2).
- **One place answers "what is gravity here"**, and every body outside asks it. Interiors (ships'
  and bases') never ask it: they keep their plating, as today.
- **Ships feel the whole well.** Every awake ship in `Fleet` feels it from the well's edge down.
- **The avatar, loose items and NPCs feel it only *on a world*:** below the air top (§6.1), or,
  on a world with no air, below 0.15 radii above the ground. *(My call.)* Rings start at 1.6–2.0
  radii, inside wells. A spacewalk among ring rocks stays the zero-gravity spacewalk of today, and
  a dropped item there doesn't fall tens of kilometres. The same line decides the airlock (§5.5)
  and the avatar's mode.
- **How it is applied is the builder's call.** Planetfall's `GravityWell` was an `Area3D` with
  point gravity, designed before the floating origin and before worlds were 60 km. An area would
  have to be a member of `Universe.EXTERIOR_SPACE` and up to 240 km across. *My call:* gravity
  worked out in code from the well and the focus's place (`Whereabouts` already knows the well
  and the altitude) and applied as a force. That's cheaper to reason about, and the same in tests.
  If the builder chooses an area, Planetfall §7.1's warnings stand: `SPACE_OVERRIDE_COMBINE`, read
  back at runtime.
- **A ship asleep** (more than 20 km off, `Fleet.ASLEEP`) feels nothing. One that falls asleep
  in a well while flying wakes where it was. One asleep on the ground is landed (§5.3).

### 5.2 Flying in a well

As Planetfall §8, with these changes:
- **The flight computer fights gravity first** (§8.2's priority order: gravity hold, pilot,
  drift). With the stick centred and assist on, a ship hovers. With assist off, it falls.
- **Horizon levelling** below 150 m (§8.3) as designed.
- **The altitude speed limit stays** (world scale spec §6). Gravity hold and drag (§6.5) live
  inside it.
- **Hard landings** (§9 of Planetfall) are a warning and a thud. *My call:* no damage yet. The
  damage system can take it later through its sections.
- **Low power never weakens the gravity hold.** Below 10% of its store, a ship runs at half
  authority (`QuantumValues.LOW_POWER_AUTHORITY`). The pilot light only refills to 25 QE, under
  that line. If the hold were halved too, the starter couldn't hover on a 5 m/s² world after a
  long warp, and couldn't leave. The owner's quantum energy rule is that normal flight is free
  and you can't be stranded. So the hold always gets full authority, and low power halves only
  the pilot's command and drift correction. *(My call.)* You can still land and take off on low
  power, slowly.

### 5.3 Landing

Planetfall §9's `LandingMonitor` as designed: FLYING → TOUCHING → LANDED, a landed hull frozen,
tilt over 25° refuses, and the HUD says why. Also:
- **A landed ship saves landed.** It loads frozen on the ground. The ground under it is built
  before it unfreezes, like the chunk under an anchor today (world scale §5.5).
- **Every ship can land** (CLAUDE.md, *every ship is usable*): the monitor reads the grid's keel,
  never the starter's numbers.

### 5.4 No world strands a ship

Today `WorldRecipe.GRAVITY` caps planets at 8 m/s². Its comment says that's "below the starter shuttle's
lift of about 10.8 m/s²". That figure is out of date since the starter's reshape of 2026-09-29.
- **What counts as lift:** the `vertical` thrust budget as the game already counts it, every
  vertical thruster in both directions (`building-a-ship` reference, *one quirk*). The flight
  computer already spends it that way. Changing the count would be a flight-model change, out of
  scope here. Measured: **starter 9.5 m/s², warden 13.2, lamplighter 15.8.**
- **At 8 m/s² the starter's margin was 1.19,** too thin to climb with any briskness. **The owner
  lowered the planets' cap to 7 m/s² (2026-11-03):** `GRAVITY` for planets becomes 2–7 m/s², and
  moons stay 1–4. The starter's margin is then 1.36, about what Planetfall meant it to have, and no
  ship changes.
- **Every library ship must lift off the heaviest world with a margin of at least 1.3:** a
  `vertical` budget of 1.3 × mass × 7 m/s². Add it as a `ShipRules` check, a line in
  `ship_probe.gd`, and an item in the `building-a-ship` and `designing-a-ship` checklists.
- Gravity has never been felt in play, so changing the range changes no world anyone has known.
  The draw has its own sub-seed (`&"gravity"`), so nothing else about any world moves. Correct
  the comment on `WorldRecipe.GRAVITY` to the real reason.
- **The HUD warns at a well's edge** if the ship you're flying can't lift off that world (a ship
  damaged into weakness, say): *TOO HEAVY FOR THIS WORLD*.

### 5.5 Stepping out and walking

- **The airlock** is built (airlock spec). **On a world** (§5.1's line), Planetfall §10's refusals
  become the room panel's: *NOT LANDED*, *UNEVEN GROUND · TILT n°*, *HATCH BLOCKED*. Above that
  line, a ring included, it cycles as today, onto a spacewalk.
- **On a world, the avatar takes a third mode, `FIELD`**, beside `PLATING` and `SUIT`: gravity
  from §5.1, and up is away from the world's centre. Planetfall §11.1's shortest-arc turning,
  yaw about the current up and `up_direction` stand. `PLATING` is pinned by a regression test, as
  Planetfall asked. You only reach `FIELD` by stepping out of a landed ship, so a spacewalk never
  crosses into it.
- **In `FIELD` the suit's thrusters are off** (their 2.5 m/s² can't beat a world's pull). The
  dry-suit trip home doesn't apply. You walk and jump.
- **Time on foot is unlimited,** as on a spacewalk today: the game has no oxygen (`SuitCell` only
  pays for thrust, and the `o2_tank` is a prop). A world's air is not breathable, so you stay
  suited, but nothing runs out. *(My call.)* Life support is a design of its own if it ever comes.
- **Jump** (Space, outside only) and **the suit lamp** (L) as Planetfall §11.2 and §11.3. Check
  first whether the spacewalk already gave the lamp a key.
- **Things you carry** go out and come back as they do on a spacewalk. Dropped outside on a world,
  they fall and rest on the ground (§5.1). They're saved by today's stray rule (saving spec §7,
  the owner's own): one left more than 5 km behind you for 10 minutes of play is gone. *(My
  call.)* That covers the log datapad too, once it has been taken from the comms hut. Placed items
  not yet taken are the world's, not strays (§8.5).

### 5.6 Boulders

Planetfall's boulders are folded into phase 2's ground cover (§7.3), not built separately.

### 5.7 Who else feels a world

- **Hostile ships** fly with the same `FlightComputer`, so they would hold against gravity. They
  don't know the ground, though. *My call:* they **stay above the air** for now: their pilot
  treats the top of a world's air (§6.1) as a floor it won't cross. Coming down after you is a
  later design.
- **NPCs** live on rocks and in ships today. None lives on a world in this project. The NPC
  foundation's locomotors should not break if one is spawned there, but nothing spawns one. The
  beast is the first world creature, in its own design.

## 6. Phase 1: air

### 6.1 How thick the air is where you are

Every world with air has an **air top**, where the air starts. *Starting numbers, tuned by flying:*
Planetfall's shell at 1.12 R (thin) and 1.2 R (thick), so 1.8–12 km above the ground. Below it,
one number, **air** (0 at the top, 1 on the ground of a thick world, about 0.4 on a thin one,
rising faster near the ground), drives everything in this section. `Whereabouts` works it out
from the altitude it already knows, and everything that changes with air reads it there. Nothing
works it out for itself.

A world with no air (`Atmosphere.NONE`) keeps today's look, and gets gravity and landing from
phase 0. A bare world should still feel like a big rock. That's right.

### 6.2 The four stages

`descent.html` is the target. The owner approved it.

| Stage | Where | What you see | What you hear |
|---|---|---|---|
| **1 · Approach** | Outside the air | The world's edge glows in its sky colour, a rim you can see from far off | Silence |
| **2 · Into the air** | Air top downward | Overhead goes from black to deep blue; a warm band along the curved horizon; stars fade; space dust thins and is gone; the ground goes soft with haze | A faint rush of wind begins |
| **3 · Flying low** | Low over the ground | A full sky: the world's sky colour at the horizon, paler blue overhead, a soft glow round the sun; far land fades into haze, near land stays warm and strong | Wind rising with speed |
| **4 · On the ground** | Standing | A big warm sky; the sun soft and golden; mesas in the haze; on a desert, sand blowing in thin streaks (§7.3) | Wind |

**The night side.** Worlds don't spin, so a place is always day or always night. On the night
side the sky is dark and the stars show through, dimmer than in space. The air's glow at the
terminator is warm. *Builder's call, checked with renders.*

### 6.3 How it is drawn (the builder's call, within these rules)

- **The outside's `WorldEnvironment` can change now.** Planetfall forbade it because the
  interior camera shared it. Since the interior redesign, the interior camera carries
  `ship_interior.tres`, and `flight_test.gd` already sets the outside's mood on the
  `WorldEnvironment`. So the sky, its colours, the sun's halo and the haze can be the outside
  environment's, blended by **air**. The canopy view and every portal window render the outside
  through it, so **the windows show the sky for free** (style guide §2.7). Check that they do.
- **The rim from outside** (stage 1) has to be drawn on the world, since the environment can't
  draw it. That means a shell, or the far mesh's edge. Whatever draws it is **one** new exterior
  shader at most, and it needs the owner's approval like any other (style guide §2.5 limits
  interior shaders to three; this one is outside, but the same caution applies). Reach for
  geometry and the engine's own materials first.
- **Haze is the distance cue:** far ground fades toward the sky colour, near ground keeps its
  palette colour. Flat colour, no noise.
- **Colours come from the palettes.** `SpacePalette.WORLDS` has one `sky` per palette. The
  overhead and horizon colours of stage 3 probably need two (`sky_high`, `sky_low`) instead of
  one. That's a palette change, approved from renders, as the palettes were.
- **Space dust** (`SpaceDust.density`, set by `Whereabouts`) falls to zero as **air** rises past
  about 0.2. Nothing hangs over the ground.
- **The star** is a real body, far off. Seen through air it gets the soft halo of stage 3.

### 6.4 Sound

- **Style guide §2.9 changes** (owner, 2026-11-03): *space is silent; a world with air carries
  sound.* Update the guide in the same branch.
- **Wind** is a new `Synth` builder (noise through a moving filter; no sound files). Its loudness
  follows **air** × speed in flight, and **air** alone on the ground, with slow gusts.
- **Seated, it is heard through the hull**, low and muffled on the Ship bus. **On foot, through
  the helmet** on the Suit bus. Inside an enterable building, faintly, through the walls.
- *Builder's call, by ear and with the owner:* whether the ship's own thrusters are heard outside
  on foot now that there is air.

### 6.5 Drag, glow and shake

- **Drag** on every body outside, in air: a force against velocity, growing with **air** and
  with speed squared. *Targets, tuned by flying:* in thick air at the ground, the starter coasting
  at 120 m/s with assist off is under 20 m/s after about 30 s. In thin air it takes about three
  times as long. With assist on, the assist already stops drift, so drag shows as stops that feel
  quicker and a top speed lower near the ground. Light enough that the speed limit, not drag, is
  what you usually feel.
- **Hostiles, items and NPCs** feel the same drag where they are in air, from the same place
  (§5.1's rule: one source).
- **Entry glow:** when you come in fast, which means **near the altitude speed limit** (*starting
  point:* above 80% of it, while **air** is above 0.05), the hull's leading faces glow warm, amber
  to white. The limit is 165–420 m/s at the air top and about 150 m/s near the ground, so a fixed
  speed would show the glow almost only with assist off. A fast assisted dive should show it. A
  gentle descent shouldn't. **No heat damage.** It's built from the engine's materials or the puff
  pattern (`Puffs`, style guide §4's thruster puffs). Colours come from a palette.
- **Shake:** in the same conditions, a little camera shake seated, through the existing
  `MotionCoupling` and hit-feel path, never stronger than a light hit.

## 7. Phase 2: the desert style

### 7.1 What it is

From the concept art and the descent mockup: warm sand in long dunes, flat mesas and rock towers
with steep risers, scattered boulders, tufts of spiky dry grass, and a sandy haze. It's faceted
and flat-coloured. The generator can roll it for any world.

### 7.2 Terrain

- **A new archetype, `DUNES`:** long parallel ridges with a soft windward side and a steeper lee,
  all running one way across a region. The direction comes from a sub-seed and turns slowly
  across the world. Where the continent layer is high, the ground terraces into mesas, as
  `MESA` does today (`WorldTerrain._terrace`), with rock towers where the terraces break up.
- **Colour** follows `ground_at`: sand on the dunes, `ground_high` on the mesa tops, `rock` on the
  risers and towers. The `sand` palette is the starting point, retuned from renders with two sky
  colours (§6.3).
- **The far mesh shows it** (`BodyLook` samples `WorldTerrain`), so a desert looks like a desert
  from orbit.

### 7.3 Ground cover

- **Boulders and dry grass** are scattered on the ground near the focus. They're generated from
  the chunk's own sub-seed, so they come back the same every time, and built on the chunk
  workers. *Starting point:* boulders 0.5–4 m, a few per 100 m²; grass tufts thicker on sand,
  none on rock or slopes. Boulders have collision. Grass doesn't.
- **Boulders count for landing:** the pad (§8.3) is kept clear. On open ground, a boulder under
  the keel is just ground you can't land level on.
- **Blowing sand** in stage 4: thin pale streaks close to the camera, on foot and flying low. They
  are world-space and join `Universe.HOLDS_SHIFT` (CLAUDE.md). There's no sand in the air above
  low flight.
- **Colours** are new `SpacePalette` entries, or a world palette beside it (`grass`, `boulder`).
  The style test's palette list grows with them (style guide §5).
- **Budget:** §10.

### 7.4 Keeping today's worlds the same

`WorldRecipe.from_seed` picks the archetype with `randi_range(0, Archetype.size() - 1)`. **Adding
an archetype to that enum changes which archetype every existing seed gets.** Draw "is this a
desert" from a sub-seed of its own (`&"desert"`, a modest share of planets with air), and leave
the old draw alone for the rest. Bump `GENERATOR_VERSION` only if a seed's world really changes,
and say so in the save notes. A test pins a handful of today's seeds to their archetypes.

## 8. Phase 3: hand-made worlds, and the desert world

### 8.1 Authoring

Build star systems §9.1 and the first two depths of §9.2: **tweak** (recipe fields) and **stamp**
(terrain features blended into `height_at`, and scenes pinned at a latitude and longitude).
- **A system design** is data keyed by body id, never by list order (§9.1). Authored bodies keep
  their sub-seeds for anything they don't override. Whether it's a `.tres` or a `.json` beside
  the ship library is the builder's call.
- **Stamps needed now:** a **flattened pad** (a disc of ground eased flat, its edge blended), a
  **basin** (a shallow bowl with a flat floor, for the pool), and **a pinned place** (the oasis
  scene, at a latitude and longitude, its pieces placed from `UniversePoint`s and joining
  `Universe.EXTERIOR_SPACE`).
- **Everything that asks the ground sees the stamps,** because they live in `height_at`: the far
  mesh, the chunks, collision, landing and the speed limit.
- **A validator** checks a design: ids exist, stamps don't overlap, a pinned place sits on its
  stamped ground. A test runs it over every design in the data. The overview scene of §9.4 is
  *not* needed now.

### 8.2 The desert world

- **Where:** one planet slot in the starting system (seed 1337), a warp from the entry, chosen by
  the builder so its well sits clear of the belts. It's a **tweak** (name, `DUNES`, the sand
  palette, thick air, gravity about 5 m/s² so jumps feel light but landing still matters) plus
  **stamps** (the pad, the basin, the oasis).
- **Its name** is the owner's to give (§14). Until then, `WorldNames` draws one.
- **The oasis is on the day side,** where the sun stands about 25–35° above the horizon: low and
  golden, as in the concept art. Worlds don't spin, so it stays that way.
- **Finding it** *(my call)*. The oasis is about 150 m across on a world tens of km wide, and a
  warp drops you 30–75 km up on whatever side your line gives. So:
  - The settlement's beacon is still running. Once you're inside the world's well, the oasis is a
    contact on the HUD and the map, with its name and range, like the other contacts the sensors
    report (bridge computer spec §4).
  - Warping to this world arrives on the oasis's side, so the beacon is ahead and below.
  - Pinned places in general can carry a beacon. Most hand-made places won't.

### 8.3 The oasis

`oasis-layout.html` is the target, about 150 m across. The owner approved it.

| # | Piece | Notes |
|---|---|---|
| 1 | **Landing pad** | Packed stone, a flattened stamp, big enough for the largest library ship with a margin, kept clear of boulders and grass. A short path leads in |
| 2 | **The pool** | About 30 m across in the basin stamp. Flat water, wadeable: knee-deep at the edge, waist-deep in the middle, never deeper than the avatar can stand in. Ringed with green and palms |
| 3–5 | **Homes** | Mud-brick with cloth shade sails. **Two are enterable** (3 and 4), one is a shell |
| 6, 7 | **Prefab modules** | Flown in by the settlers, patched with brick. **The workshop (6) and the comms hut (7), both enterable** |
| 8 | **The crushed hut** | Roof caved in. A shell, with the beast's damage |
| 9 | **The broken wall** | Knocked through from the desert side; rubble; **huge tracks** leading off into the dunes and fading |
| 10 | **Rock outcrop** | North of the village: shade, and a lookout you can climb |
| 11 | **Gardens** | Plots watered by a pump at the pool; half dried out |

- **Palms** are hand-placed, chunky and faceted: a segmented trunk and a few broad flat fronds.
  Colours come from a palette.
- **Shells** (the buildings you can't enter) are kit-built, chunky and bevelled, with collision.
  They're exterior space, built in `ExteriorBuilder`'s manner.
- **The tracks** are footprints a couple of metres across, pressed into the sand as a decal-free
  stamp or as flat darker patches. *Builder's call.* They should read from the ship as it comes in
  to land.

### 8.4 Enterable buildings

- **Each is a base** (habitat modules spec §9.1: a `ShipGrid` that never flies, its exterior a
  frozen body, its interior in its own slot). That gets them the airlock threshold, the canopy
  view through their windows, saving, and the interior style for free. **They are not ships**,
  and are never in `Fleet`. This is the same exception bases already have from *every ship is
  usable*.
- **They have no airlock cycle** to step through. The air outside isn't breathable but the suit
  is sealed, so a door is a door. *My call:* each gets a plain door that hands you between
  exterior and interior space at its threshold, as the airlock's outer hatch does, without the
  cycle. The builder decides how much of the airlock's threshold code serves.
- **Built from blocks**, a small grid each: one or two rooms, 2 m cells as the ships use. New
  room types, or dressing variants, for *home*, *workshop* and *comms*.
- **The outside skin** of the mud-brick homes is brick, not hull plating: a new skin beside
  `HullPalette`, with its own palette. The prefab modules keep a hull-like skin, weathered and
  patched with brick.
- **Inside: abandoned, not cold.** Style guide §4 says a different interior changes colour and
  wear, not style. These are warm homes left in a hurry: furniture knocked over, a door off its
  track, sand blown in across the floor, some practical lights dead, daylight from the doorway
  and windows. They read differently from your ship by more than brightness.

### 8.5 Things to find

All from the existing catalogue (`data/items/`), placed by hand in the design, inside and out:

| Where | What |
|---|---|
| Home 3 | Ration tins, a mug, a spare helmet |
| Home 4 | A medkit, an O2 tank, ration tins |
| Workshop 6 | A toolbox, a spanner, a wire coil, power cells; **a plasma pistol by a barricade of crates** |
| Comms hut 7 | **The log datapad** (§8.7), a power cell |
| Outside | A crate by the crushed hut; a canister dropped on the path to the pad |

The amounts are the builder's, kept modest: useful, not a hoard. **Taken stays taken.** The
world's state saves which placed items are gone, as the saving spec already does for strays and
salvage, and loading never puts them back.

### 8.6 Saving

The world's changes save with the system: items taken, items dropped there, a landed ship's
place, and anything the bases already save. The design itself isn't saved, because it's data. A
save made before this design keeps working. The world appears at its slot, and the save's
version notes record any change to that slot's seed (§7.4).

### 8.7 The log

- **A datapad you can read.** Today a datapad only shows a moving screen (style guide §2.4), and
  a screen that shows real data is a feature of its own (§2.8). This one, used, shows its entries
  as a few lines of large text in a HUD panel styled like the computer pages. ESC closes it. Any
  datapad item can carry entries. Most carry none and behave as today.
- **Draft text** (*my draft; the owner's to rewrite*):

  > **Day 212.** Pump's fixed. Gardens will make it if the wells hold.
  >
  > **Day 230.** Something big crossing the dunes at night. Tracks wider than the pad.
  >
  > **Day 233.** It came to the wall. Took Ama's hut with it. Nobody hurt. Everyone shaken.
  >
  > **Day 236.** Back again. Bolts just bounce off the plates on its back. We're loading the
  > shuttle.
  >
  > **Day 237.** Leaving what we can't carry. If you're reading this, don't stay after dark.

  The last line hints at the beast's design to come. Remove it if that design goes another way.

## 9. Style guide changes, together with the code

- **§2.9 Sound:** air carries sound on a world (§6.4).
- **A new section, *Worlds up close*** (world scale spec §8.3 promised one): the sky and haze by
  air, the rim, ground cover, the desert's colours, palms, the oasis, and the brick skin.
- **§5:** the palette list in `test_visual_style_rules.gd` grows with any new palette (§7.3,
  §8.3, §8.4). An exterior shader, if one is approved (§6.3), is recorded.
- Changing a rule needs the owner's approval (CLAUDE.md). The ones above are approved here, and
  the renders will confirm the look.

## 10. Verification and budgets

- **Render the real scene and show the owner** (CLAUDE.md; style guide §6). Use a descent probe,
  extending `world_probe.gd` or `system_render.gd`, that renders the four stages of §6.2 at fixed
  altitudes, and the night side. At the oasis, render at eye height (1.6 m): from the pad, at the
  pool, at the broken wall looking at the tracks, inside each enterable building, and from the
  seat as the ship comes in to land. Put them side by side with `descent.html` and
  `oasis-layout.html`.
- **Frame budget:** at least **120 fps at 1280 × 720 on the GTX 960** (style guide §2.6). The
  worst views are expected seated on the pad looking across the oasis (canopy view drawing
  everything twice) and low flight over dense dunes. Record the numbers in §2.6.
- **Tests,** targeted to the change, never the full suite unless the owner asks:
  - gravity's strength and fall-off;
  - the gravity-hold priority and hovering (Planetfall §15);
  - the landing monitor's pure step;
  - `FIELD` mode's up, with `PLATING` pinned;
  - **air** by altitude;
  - drag's coast-down target;
  - the stamps in `height_at`;
  - today's seeds pinned to today's archetypes;
  - the system validator over the data;
  - placed items not returning after a save and load;
  - lift for every library ship.
- **`test_floating_origin_scene.gd` passes** with the oasis loaded and a ship landed: every
  exterior piece is in `EXTERIOR_SPACE` or `HOLDS_SHIFT`.
- **`test/probes/fleet_play.gd`** after the airlock and suit changes (CLAUDE.md).
- **Read `.tscn`/`.tres` edits back at runtime** (CLAUDE.md).

## 11. Skills and other documents to update in the same branch

- **`building-a-ship`** (CLAUDE.md): lift on worlds (§5.4) in the checklist, `ShipRules` and
  `ship_probe.gd`; gravity hold, landing and the keel in `reference.md`; drag and entry glow;
  lessons in *Mistakes already made*.
- **`designing-a-ship`:** a new ship must lift off the heaviest world.
- **`building-an-npc`:** gravity, drag and `FIELD` up exist for anything outside on a world.
  Nothing lives there yet.
- **Planetfall:** each section this design builds is marked built. Sites, signals, the discovery
  log and the surface readout (§12–§13) are marked still open. The gravity comment on
  `WorldRecipe.GRAVITY` and Planetfall's "≈10.8 m/s², margin 1.35" are corrected (§5.4).
- **Star systems:** step 5 (authoring) marked built at the tweak and stamp depths.
- **World scale:** §8.3's *Worlds up close* is done (§9).

## 12. Left to the builder

- How gravity and drag are applied (§5.1), within *one source*.
- How the sky, haze and rim are drawn (§6.3), within one new exterior shader at most, approved.
- The numbers marked *starting point* or *target*, tuned by flying and rendering.
- The dune shape, ground cover density and the palette values, from renders.
- The data format for system designs.
- How the enterable buildings' doors hand you over (§8.4).
- Phases are built in order, each flyable alone. Phase 0 can be split further in the plan (e.g.
  gravity and hover; landing; walking out).

## 13. Why not water first

The owner started with a water world of islands. A planet-wide ocean needs a sea level round the
whole world drawn at every distance with the quadtree, shorelines where it meets the terrain,
what happens when a ship or the avatar touches it, and a sea that fits the flat-colour style. It
isn't out of reach, just the biggest single piece. This design builds what the ocean world will
stand on (gravity, landing, air, ground cover, authoring, a small pool), so the ocean is a design
of its own next.

## 14. The designer's calls

These were made where the conversation didn't decide. The owner left them to the designer on
2026-11-03, so they stand. Each is still easy to change before its phase is built:

1. **Where:** a planet in the starting system, a warp away (§8.2).
2. **Four enterable buildings,** built as bases (§8.4).
3. **The items** in §8.5.
4. **The log's text** (§8.7).
5. **Hostiles stay above the air** for now (§5.7).
6. **No hard-landing damage yet** (§5.2).
7. **Time on foot is unlimited;** the air isn't breathable but nothing runs out (§5.5).
8. **The world's gravity, about 5 m/s²** (§8.2).
9. **The world's name** is yours to give.
10. **Gravity on the avatar and items starts at the air top**, so ring spacewalks stay
    weightless (§5.1).
11. **Low power never weakens the gravity hold** (§5.2).
12. **Dropped items on a world follow the stray rule** (§5.5).
13. **The oasis has a beacon** you pick up inside the well, and warping to the world arrives on
    its side (§8.2).
14. **Entry glow follows the speed limit,** so a fast assisted dive shows it (§6.5).
