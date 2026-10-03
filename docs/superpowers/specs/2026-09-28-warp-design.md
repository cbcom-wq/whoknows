# Warp — crossing a system by jumping between its major bodies

**Date:** 2026-09-28
**Status:** Designed with the owner on 2026-09-28, after their play-test of the system skeleton.
§2 is agreed; the numbers are first guesses, to be tuned by flying. **Built** on
`star-systems-warp` (2026-09-29); §13 is what was built. The owner has not yet flown it or seen
its renders.
**Piece 3 of the star systems design** (`2026-09-27-star-systems-design.md` §12). It **replaces
quantum cruise** (§7 there). Jumps between stars (piece 6) are unchanged.
**Depends on:** `main` at `dfd7b91` (the system skeleton)
**Amends:** the star systems design §4.3, §7 and §12; the system skeleton spec §9, §10, §12 and
§16.1; the bridge computer spec §5; the quantum energy spec §8.4; the saving spec's world section
**Governed by:** `docs/design/visual-style.md`

> **Amended 2026-09-30 by the world scale spec** (`2026-09-30-world-scale-design.md` §3.3,
> §3.4): moons are warp targets, each wholly outside its planet's limit, and block a line like
> a planet. A planet's limit is its well + 14 km and past its ring, no longer at least its
> neighbourhood. Travel is 18 s + 1 s per 350 km; the cost is 40 QE + 1 QE per 12.5 km
> (`WARP_M_PER_QE`). The map's ranges are 2, 10, 50 and 500 km and the system.
>
> **Amended 2026-10-03 by the computer mode spec** (`2026-09-30-computer-mode-design.md` §4, built
> on `computer-mode`): §7.1's SYSTEM range is no longer a separate framing. It is the far end of
> one continuous map (1 km to 9,000 km), whose centre slides from the ship at 500 km to the star
> at 3,000 km; marks by class and reach colouring apply once the centre is more than half way to
> the star. Warp limits are drawn at every scale, not only on SYSTEM.

---

## 1. Why

The owner's play-test of the system skeleton, 2026-09-28:

> The system is too spread out, you fly through emptiness too long. I think part of the problem is
> it is space so what is between is pretty boring. I wonder if we should allow for a type of "warp
> jump" once the user is far enough away from a major body. They open the ship computer and can
> choose another body in the system then jump near there. Then they still have to fly some amount
> in the area of a major body, maybe through asteroids, rings, debris, moons etc, but they don't
> spend time in just the vastness of space. [...] Consider using QE to jump, then we can kind of
> unlock bodies as the user gains more QE making for a game progression.

Then, on distances: "maybe it's ok as is, the trouble is I don't really know where things are or
what is big because there's not much sense of scale/distance in space. Let's keep the size but as
part of the warp jump improve the map in the ship computer to show better information on what is
out there and how far away things are."

What was measured (60 seeds, at the ship's 120 m/s top speed; boost only gets you there faster):

| Trip | Distance, median (p90) | Flying |
|---|---|---|
| A major body to its nearest neighbour | 34 km (76) | about 5 min (10.5) |
| The start to the nearest planet | 46 km (90) | about 6.5 min (12.5) |
| Any two major bodies | 80 km (153) | about 11 min (21) |

Almost all of it is empty: a planet's neighbourhood reaches only 3–15 km.

### 1.1 The pitch

You climb out of KORVA-7's gravity. Loose rocks tumble past, and its moon hangs off to port. Two
minutes out, the HUD toasts *LEAVING KORVA-7 · WARP CLEAR*. On the holo table the whole system
sits round its star like an orrery. You step through the planets with ▶: *TESVOSS-68 · PLANET ·
LARGE · 1.6 KM ACROSS*, *82 KM · 11 MIN FLYING · 41 S WARP*, *WARP 302 QE · IN REACH*. Press
the big button: *WARP CHARTED*.

Back in the chair, a diamond with a ring round it sits off to the right. Swing the nose onto it
and the ring turns green: *WARP READY · J*. Press J. The core's rings race, the hum climbs, the
dust starts to stretch. Ten seconds later the ship leaps. Dust streaks past the canopy, a belt's
slabs flick by beneath you, and TESVOSS-68 swells from a dot to a world. Half a minute on,
the streaks shrink back to flecks and you are coasting in at 120 m/s, 16 km out, with its ring
ahead of you and its debris to fly through.

---

## 2. Decisions

| Question | Choice | Why |
|---|---|---|
| The system's size | **Unchanged.** | The owner: the trouble is not size but not knowing where things are or how big they are. The map fixes that (§7). |
| Cruise or warp | **Warp replaces cruise.** | Cruise still flew you through the emptiness, only faster. The warp skips it and leaves you the busy part. |
| What you warp to | **Major bodies: the star, each planet, and each belt cluster** (§3.1). Moons are not targets. | The owner's "sun, planet, large asteroid cluster". A moon lies inside its planet's limit, so you fly to it. |
| How far out you may warp | **The warp limit: the body's edge + 14 km**, the edge being a well or a cluster's reach (§3.2). | The owner: "about 2 minutes" of flying, and "careful measuring from a body center as different bodies might have vastly different diameters". |
| What the warp is | **Real flight at warp speed** along a straight line (§5). | The sense of movement the owner asked for. A tunnel is a loading screen; a teleport has no travel. |
| How long | **10 s of spool, then about 30 s of travel on average** (§5.3). | The owner's numbers. |
| How you start it | **Chart it on the computer, line the nose up at the helm, press J** (§4). | The owner's flow. |
| A line through another body's limit | **Refused;** the map shows the blocker (§4.3). | Predictable. You warp to the blocker first, or fly clear. |
| What it costs | **40 QE + 4 QE per km** (§6). | Far targets unlock as your QE grows: the owner's progression. |
| Something to fly through on the way out | **Orbital debris round every planet** (§3.3), plus the moons and rings already there. | Otherwise the two minutes out are empty too. |

---

## 3. Targets, limits and debris

### 3.1 Warp targets

`SystemRecipe.warp_targets()` lists every major body as a `WarpTarget` (pure data):
`id`, `name`, `kind` (`STAR`, `PLANET`, `CLUSTER`), `point: UniversePoint`, `edge` (m from the
point) and `limit` (m from the point).

- **The star and every planet** are targets, with the ids they already have (`&"star"`, `&"p3"`).
- **Belt clusters.** Each belt gets 3–6 clusters, drawn from `WorldSeed.sub(seed, &"clusters_<i>")`.
  - Each lies on its belt's centre circle, at a seeded angle, except the first (below).
  - Clusters of one belt are at least `2 × limit` apart round it, so their limits never overlap.
  - **The first cluster of the first belt is centred on the start** (the entry, 700 m off its big
    rock), so you begin at a major body. The start is found without the clusters' lift, so the
    lift never moves it.
  - Ids `&"belt_0.c1"`; names from `WorldNames.cluster()`, for example *TRELL CLUSTER*.
  - **Denser inside:** within `CLUSTER_RADIUS` (4 km) of its centre, a cluster lifts the belt's
    group noise towards 1 (`AsteroidShapes.cluster_lift`), so it reads as a real cluster and not
    only a named stretch of belt.
- **Moons are not targets.** They lie inside their planet's limit.

### 3.2 The warp limit

**A target's limit is its edge plus `WARP_CLEAR` = 14 km:** about two minutes of flying at 120 m/s.

| Kind | Edge | Limit from its centre |
|---|---|---|
| Star | its well, 3R (7.5–12 km) | 21.5–26 km |
| Planet | its well, 3R (0.9–3.6 km); Planetfall's atmosphere (1.12–1.2 R) lies inside it | 14.9–17.6 km |
| Cluster | `CLUSTER_RADIUS`, 4 km | 18 km |

- **A planet's limit is at least its neighbourhood + 1 km,** so it always holds its moons and
  ring. `problems()` checks it.
- **Limits may overlap.** About one pair of neighbours in ten sits closer than their two limits.
  There is no warp between them: you fly, and it is a three-minute trip.
- **You may start a warp only outside every limit** (§4.2).

### 3.3 Orbital debris

`AsteroidShapes.Debris`, one per planet: a thick disc round the planet, fed through the recipe's
keep chance like rings (skeleton spec §6).

- **From the well's edge to 1 km inside the limit,** so the climb out of gravity is clear, then
  rocks, then open space. That keeps the umbrella's rule: no rocks in a well except a planet's own
  ring.
- **Half-thickness 3 km,** easing off over its outer 40%. The disc lies in the ring's plane if the
  planet has a ring, else in a seeded plane up to 20° off the system's.
- **Rubble and mid-size rocks only**, sparse: `DEBRIS_PEAK` = 0.12 for rubble and 0.08 for
  mid-size (a ring is 0.6), tuned by render. No giants, so no salvage clouds yet.
- **Only discs whose bounds touch a cell are tested**, as with rings.

`SystemRecipe.VERSION` goes to 2 and `AsteroidRecipe.VERSION` to 3. A save from before starts
over (saving spec §8.1), as with the skeleton.

---

## 4. Charting and lining up

### 4.1 Charting

On the map's SYSTEM range (§7.1), ◀ ▶ step through warp targets, nearest first. The big button
**charts a warp** to the selected one: *Chart warp*, then *Clear warp*.

- Charting sets the course to the target too, so the HUD's course diamond points at it (bridge
  computer spec §6).
- The charted target is kept by `WarpDrive.charted` and saved with the ship.
- Charting is allowed from anywhere. The checks come at the helm.

### 4.2 `WarpPlan`: can I go?

`WarpPlan.check(from: UniversePoint, nose: Vector3, target, targets, store, ship_state)` is pure. It
returns a status, and for a ready or near-ready plan the distance, cost, duration and drop-out point.

| Status, in the order checked | HUD line |
|---|---|
| `NONE`: nothing charted | *(the panel is hidden)* |
| `CREW`: someone on a spacewalk, or an airlock cycling | *WARP · CREW OUTSIDE* / *WARP · AIRLOCK CYCLING* |
| `INSIDE`: within a limit | *CLEAR OF KORVA-7 IN 6.2 KM* |
| `CLOSE`: the target's limit is less than 5 km away | *FLY · 3.4 KM TO TESVOSS-68* |
| `BLOCKED`: the line crosses another star's or planet's limit | *BLOCKED BY ZESU* |
| `LOW_POWER` | *WARP · LOW POWER* |
| `NO_QE`: cost above the store | *WARP · NEED 512 QE* |
| `ALIGN`: the nose more than 5° off the line | *ALIGN · 23°* |
| `READY` | *WARP READY · J*, amber with *→ LOW POWER* if it would drop you into low power |

- **The line** runs from you to the target's centre; the drop-out point is where it meets the
  limit.
- **Blocking:** only star and planet limits block. Clusters and belts never do, since the warp
  passes over rocks without touching them (§5.2).
- **Drop-out clearance:** the drop-out point is stepped back along the line in 100 m steps until it
  is 300 m clear of every big and mid-size rock the recipe places there and 30 m clear of rubble,
  so you never arrive inside a rock. (Rubble's thin sprinkle leaves almost no point 300 m clear of
  it.)

### 4.3 Blocked lines

The map draws a charted line in ticks from you to the drop-out point. A blocker's limit on it is
marked in `CORAL`. You warp to the blocker first, or fly until the line is clear.

---

## 5. The warp

`WarpDrive` is a `Node` under `Ship`, created in code like `QuantumPlant`, with the stages
`IDLE`, `SPOOLING`, `TRAVELLING` and `DROPPING`.

### 5.1 Spool (10 s)

- **J** (new input action `warp`) starts it when `WarpPlan` reads `READY`.
- The core's rings climb past boost speed, the hum rises (`warp_spool`), and the dust starts to
  stretch along the line.
- **You keep the helm.** It **aborts, with nothing spent,** if the nose swings more than 10° off
  the line, if the plan reads anything but `READY` or `ALIGN` (a spacewalk starting, low power), or
  if you press J again.
- The HUD reads *WARP · SPOOLING 7*.

### 5.2 Travel

- **The cost is spent at the moment of leaving.** If the store cannot pay by then, it aborts
  with *WARP · NEED 512 QE*.
- **The hull flies the line.** Every physics tick, `WarpDrive` sets the hull's place and velocity
  from `WarpProfile` (§5.3), facing along the line. The pilot's controls are ignored; you can look
  round, stand up and walk about, since the interior never moves.
- **Nothing solid on the way:** the hull's collision mask is cleared for the travel and restored at
  drop-out.
- **Rocks stop streaming** (`AsteroidStream.suspended`): every rock tier is hidden, nothing loads,
  and the physics bubble frees its bodies. `BeltLook` shows all its slabs, since no giants fill in
  near you, so a belt you cross flicks past as slabs.
- **Dust streaks:** each fleck stretches along the velocity, up to 40 m at full speed, by its own
  transform. There is no new shader. Its density is 1 for the travel.
- **Proxies, the sun and `Whereabouts`** work as always. The floating origin shifts about twice a
  second at full speed, which it already handles.
- The HUD reads *WARP · TESVOSS-68 · 18 S*. Boost is off.
- Sound: `warp_travel`, a deep rushing loop.

### 5.3 `WarpProfile`: how fast

`WarpProfile.new(distance)` is pure: `duration`, `speed_at(t)` and `travelled_at(t)`.

- **Duration: 18 s + 1 s for every 5 km.** 40 km takes 26 s; a typical 60 km trip (80 km between
  centres, less the two limits) takes 30 s; 250 km takes 68 s.
- **Speed:** from 120 m/s up to the peak over 4 s, held, then down to 120 m/s over the last 4 s.
  The peak makes the distance come out exactly: about 2.3 km/s for 60 km, about 3.9 km/s for 250 km.

### 5.4 Drop-out

- At the drop-out point you are moving in at **120 m/s**, facing the target. With the assist on,
  the speed lock is set to 120 m/s, so the ship coasts in rather than braking.
- **Rocks load before the next frame,** as for the F7 hop: `Universe.check()`, the star system
  placed, `Whereabouts.look()`, then `AsteroidStream.update(0.0, true)`.
- The mask comes back, the dust shrinks to flecks, and `warp_drop` thumps.
- The HUD toasts *ENTERING TESVOSS-68*.

### 5.5 Saving

- **During the spool,** saving is as usual. Nothing has been spent, and a load puts you back at the
  helm with the warp still charted.
- **During travel,** a save records the ship at the drop-out point, moving in at 120 m/s, with the
  cost already spent. A load puts you there.

---

## 6. What it costs

**`WARP_BASE` 40 QE + `WARP_PER_KM` 4 QE per km** of travel (from you to the drop-out point).

| Trip | Travel | Cost |
|---|---|---|
| Neighbours | 20 km | 120 |
| Typical | 60 km | 280 |
| Long | 120 km | 520 |
| Across the system | 250 km | 1,040 |

- The starter holds 1,200 and starts at 600. **With 600 you reach about 140 km,** and a full store
  crosses the system. Far targets open up as you gather, and later as a ship carries more quantum
  cells.
- **Refused in low power** and without the QE. A warp that would leave you in low power warns
  (amber, *→ LOW POWER*) and still goes, as making does at the machine (quantum energy spec §7.2).
- The quantum energy spec's §8.4 gains the warp as a built spender.

---

## 7. Seeing where things are

### 7.1 The map's SYSTEM range

- **Centred on the star,** so the whole system always fits and reads like an orrery. It still turns
  with the ship (bridge computer spec §5.1), so ahead in the holo is ahead out of the canopy. The
  range covers 180 km from the star.
- **The ship** is a pip with a heading tick.
- **Scale rings round the ship every 50 km,** in faint ticks.
- **Marks by class,** not by clamped radius:

  | Class | Holo size |
  |---|---|
  | Star | 0.06 |
  | Large planet (R ≥ 900 m) | 0.04 |
  | Medium (600–900 m) | 0.03 |
  | Small (under 600 m) | 0.02 |
  | Cluster | a clump of three 0.01 balls on its belt's ticks |

- **Each target's limit** as a ring of 24 faint ticks.
- **Reachable targets are lit; those beyond your QE are dim,** in a dim palette colour chosen at
  render (an existing `InteriorPalette` entry if one reads, else a new one).
- **The charted line** in ticks, with any blocker in `CORAL` (§4.3).
- Moons show as today: balls beside their planet, not targets on this range.

The three nearer ranges (2, 10, 30 km) are unchanged, apart from clusters showing as contacts.

### 7.2 The screen

For the selected target, three lines:

```
TESVOSS-68 · PLANET · LARGE · 1.6 KM ACROSS
82 KM · 11 MIN FLYING · 41 S WARP
WARP 302 QE · IN REACH
```

- The second line gives the distance to the centre, the time at 120 m/s, and the spool plus the
  profile's duration.
- The third line is one of *WARP 302 QE · IN REACH*, *NEED 512 QE · STORE 380*,
  *FLY · TOO CLOSE TO WARP*, *BLOCKED BY ZESU* or *WARP CHARTED*.
- A cluster's first line reads *TRELL CLUSTER · BELT · 8 KM ACROSS*.

### 7.3 The HUD, seated

- **Body brackets.** Every warp target in view gets a small dim bracket: *KORVA-7 · 82 KM*. The
  charted one is amber. `BodyMarker` is a `WorldMarker` reading body contacts from the ship's
  sensors, mounted per view like `SalvageMarker` (canopy, chase view, spacewalk). Only the charted
  one pins to the screen's edge; the rest simply leave the screen.
- **The warp panel** (`WarpPanel`, a `HudElement` in the band) shows `WarpPlan`'s line (§4.2), and
  during a warp its stage.
- **The alignment ring:** while a warp is charted, the course diamond gains a ring 5° across. It
  turns `SIGNAL_GO` when you are lined up and ready.
- **Toasts** from `Whereabouts` when you cross a limit, shown for 3 s on the warp panel's second
  line: *LEAVING KORVA-7 · WARP CLEAR* (or just *LEAVING KORVA-7* while another limit still holds
  you), *ENTERING KORVA-7*.

### 7.4 Contacts

`BodyContacts` gains one contact per cluster, kind `&"cluster"`, id `body:belt_0.c1`, and moons
become kind `&"moon"`, so `&"body"` is exactly the star and the planets. The course kinds gain
`&"moon"` and `&"cluster"`. The HUD's `ContactMarker` leaves bodies and clusters to `BodyMarker`;
moons it still marks within 10 km, as now.

---

## 8. Whereabouts

- **A new kind of place, `LIMIT`,** one per target (`&"limit_p3"`), entered at the limit and left
  `HYSTERESIS` beyond it, like the rest.
- **`warp_clear() -> bool`:** true when you are in no limit. `WarpPlan` takes it from here, not by
  working it out itself (umbrella §3.1).
- **`text()`** is unchanged: a limit is not shown on the location line.
- Its `entered` and `left` signals feed the HUD's toasts.

---

## 9. Architecture

```
SystemRecipe ── warp_targets(): star, planets, clusters ── limits, debris discs (AsteroidShapes)
     │
     ├── Whereabouts ── LIMIT places, warp_clear() ── toasts
     │
     └── BodyContacts ── bodies and clusters ──► ShipSensors ──► MapPage (chart), BodyMarker
                                                                  │
 MapPage ── chart ──► WarpDrive (under Ship) ◄── J ── HUD: WarpPanel, alignment ring
                          │  WarpPlan (pure): status, cost, drop-out
                          │  WarpProfile (pure): speed and place over time
                          ├──► QuantumPlant: spend; core spin
                          ├──► hull: place, velocity, mask
                          ├──► AsteroidStream.suspended, BeltLook (all slabs), SpaceDust (streaks)
                          └──► save: the drop-out point while travelling
```

- **`WarpDrive` is the only thing that moves a ship at warp.** `FlightComputer` asks it whether to
  ignore the pilot.
- **`WarpPlan` and `WarpProfile` are pure** and tested headless.
- **The world knows nothing about warps.** The stream, belt looks and dust take a flag or a velocity.

### 9.1 Files

```
src/world/
  warp_target.gd       WarpTarget: one major body's data (no node)
src/flight/
  warp_plan.gd         WarpPlan: can I go, and what it costs (pure)
  warp_profile.gd      WarpProfile: speed and distance over time (pure)
  warp_drive.gd        WarpDrive: the stages, driving the hull
src/ui/
  warp_panel.gd        WarpPanel
  body_marker.gd       BodyMarker
```

**Modified:**
- **The world:** `system_recipe.gd` (clusters, targets, limits, debris, `VERSION` 2),
  `asteroid_shapes.gd` (`Debris`, `cluster_lift`), `asteroid_recipe.gd` (`DEBRIS_PEAK`, the
  lift, `VERSION` 3), `asteroid_stream.gd` (`suspended`), `belt_look.gd` (all slabs),
  `space_dust.gd` (streaks), `whereabouts.gd` (`LIMIT`) and `world_names.gd` (`cluster()`).
- **Sensors and the computer:** `body_contacts.gd` (clusters), `map_page.gd` (§7.1, §7.2),
  `computer_context.gd` (the warp drive and the store).
- **Flight and the ship:** `flight_computer.gd` (ignores the pilot while warping; no boost),
  `ship.gd` (`WarpDrive`), `quantum_core.gd` (the spool spin).
- **The HUD:** `course_marker.gd` (the alignment ring), and the HUD's mounting of `BodyMarker`,
  `WarpPanel` and the toasts.
- **Elsewhere:** `synth.gd` (three sounds), `save_game.gd` (§5.5), `project.godot` (`warp` on J),
  `flight_test.gd` (wiring), and `test_visual_style_rules.gd` (every new painting file joins
  its list).

---

## 10. Testing

### 10.1 Automated (GUT, headless, output pristine)

- **`test_system_recipe.gd`:**
  - over 500 seeds, every planet's limit holds its neighbourhood;
  - clusters lie inside their belt, a belt's clusters' limits never overlap, and the first
    cluster is centred on the start;
  - every debris disc lies outside its planet's well and inside its limit;
  - `describe()` lists clusters and limits.
- **`test_asteroid_recipe_system.gd`:**
  - no debris rock inside a well, and no giant in a disc;
  - a cluster's core holds more groups than the belt round it.
- **`test_warp_plan.gd`:** every status of §4.2 from a built case; the cost; blocking by a planet,
  not by a cluster or a belt; the drop-out point 300 m clear of rocks.
- **`test_warp_profile.gd`:**
  - the distance comes out exact;
  - speeds start and end at 120 m/s;
  - the duration rule;
  - the average travel time over 200 seeds' typical trips is 25–35 s.
- **`test_whereabouts.gd`:** limits entered and left with hysteresis; `warp_clear()`.
- **`test_warp_drive.gd`** (a headless flight scene):
  - a warp from the start to a planet arrives at its limit at 120 m/s, facing it, with the cost
    spent;
  - rocks are loaded, and none overlaps the hull;
  - an abort during the spool spends nothing;
  - the mask is restored;
  - a save during travel loads at the drop-out point.
- **Map page tests:** star-centred placement; classes; lit and dim by QE; charting sets the course;
  the screen's three lines.
- **`test_floating_origin_scene.gd`:** unchanged, and it must still pass during a warp. A warp
  crosses many shifts.
- **`test_visual_style_rules.gd`:** the new painting files join its list.

### 10.2 Live checks and renders

- Warp from the start to the farthest reachable planet: no frame over 33 ms during travel; rocks
  at drop-out loaded before they show.
- **Renders for the owner** (with the skeleton spec's §12 set, per §16.3 there): the map's new
  SYSTEM range at arm's length; the HUD lined up and ready; dust streaks mid-warp through the canopy;
  a planet's debris from its limit; a cluster from its limit.
- The style guide's *Worlds and the star from afar* section gains: dust streaks only at warp.

---

## 11. Build order

Each step ends flyable:

1. **The recipe:** clusters, `WarpTarget`, limits, debris discs, the versions, `describe()`, and
   their tests. *Fly out of a planet through its debris.*
2. **`WarpPlan` and `WarpProfile`,** pure, with tests.
3. **`Whereabouts` limits** and the toasts. *See WARP CLEAR as you leave.*
4. **`WarpDrive`:** spool, travel, drop-out, the stream suspended, streaks, slabs, the mask, the
   QE, sounds, J, saving, and the headless warp test. *Warp to a planet charted by a debug key.*
5. **The map:** the star-centred SYSTEM range, classes, rings, reach, charting, the screen, and
   clusters as contacts. *Chart it at the table.*
6. **The HUD:** `WarpPanel`, the alignment ring, `BodyMarker`. *The whole flow, seated.*
7. **Skills and documents:**
   - the `building-a-ship` skill gains the warp: the drive, the ghosted hull, the helm ignored,
     reach by QE capacity, and a `ship_probe.gd` line for the reach;
   - the amendments listed at the head are noted in each spec they touch.

Then, as the owner ordered on 2026-09-28: the renders (the skeleton spec §16.3 plus §10.2 here),
the owner's approval of the look and the style guide's section, frame rates on the GTX 960, and
then Planetfall.

---

## 12. Where to tune

| What | Where |
|---|---|
| How far out you may warp | `SystemRecipe.WARP_CLEAR` (and `CLUSTER_RADIUS` for clusters) |
| How many clusters, how dense | `SystemRecipe.CLUSTERS`; `AsteroidShapes.CLUSTER_LIFT` |
| Debris | `SystemRecipe.DEBRIS_*` (reach, thickness, tilt); `AsteroidRecipe.DEBRIS_PEAK` |
| How long a warp takes | `WarpProfile.BASE_TIME`, `PACE`, `RAMP`; `WarpDrive.SPOOL` |
| What it costs | `WarpPlan.WARP_BASE`, `WARP_PER_KM` |
| How lined up you must be | `WarpPlan.ALIGN`, `WarpDrive.ABORT_ANGLE` |
| Streaks | `SpaceDust.STREAK_MAX` |
| The map | `MapPage.SYSTEM_REACH`, `SCALE_RING`, the class sizes |

Changing a recipe constant needs `SystemRecipe.VERSION` or `AsteroidRecipe.VERSION` bumped, as in
the skeleton spec §16.2.

---

## 13. What was built (2026-09-29)

Built on `star-systems-warp` in the order of §11 (plan: `docs/superpowers/plans/2026-09-28-warp.md`).
The numbers above are the built ones. Where the build differs from this spec's first draft, and why:

- **Cluster 1 is centred on the start** (the entry, 700 m off its big rock), not on the rock,
  whose centre can lie outside the belt. The start is found without the clusters' lift, so the
  lift never moves it.
- **Arrival clearance is per tier:** 300 m from mid-size and big rocks, 30 m from rubble. Rubble's
  thin sprinkle leaves almost no point 300 m clear of it.
- **At drop-out the speed lock is set to 120 m/s** when the assist is on. Otherwise the assist
  cancels the velocity nobody asked for and brakes you to rest at the limit.
- **Moons are contacts of their own kind** (`&"moon"`), so `&"body"` is exactly the star and the
  planets. The HUD's contact marker leaves bodies and clusters to `BodyMarker`, which also skips a
  target you are inside (cluster 1 surrounds the start).
- **Limits have their own signals,** `Whereabouts.limit_entered` and `limit_left`, not `entered`
  and `left`, whose listeners count the places on the location line.
- **The physics bubble keeps its few bodies while suspended.** The hull touches nothing at warp,
  and they are let go by distance when the stream resumes.
- **Nothing leaves, fires or is felt during a warp** (the final review): airlock panels refuse
  and nobody crosses the outer hatch while the drive spins, and an idle outer hatch left open
  holds the warp (*WARP · AIRLOCK CYCLING*). The flight computer zeroes its commands, so the RCS
  never puffs along the way. Motion coupling feels nothing while travelling: the frozen hull's
  placing, origin shifts included, would otherwise shove you at the 12 m/s² cap.
- **Typical trips:** over 200 seeds, 4,136 trips between the star and planets average **30.9 s**
  of travel (plus the 10 s spool).
- **Tests:** 1,421 before, about 1,480 after, all passing. `test_warp_scene.gd` warps in the real
  flight scene by stepping the drive by hand.

### 13.1 Left to do

1. **Renders for the owner** (§10.2, with the skeleton spec's §12 set; the skeleton spec §16.3 says
   how), then the owner's play-test. Tune from §12.
2. **The owner's approval of the look,** then the style guide's *Worlds and the star from afar*
   (skeleton spec §12), including the rule that dust streaks only at warp.
3. **Frame rates on the GTX 960** (skeleton spec §13.2), and one warp's worst frame.
4. Then **Planetfall.**
