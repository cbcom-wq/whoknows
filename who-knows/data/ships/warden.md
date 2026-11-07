# Warden patrol frigate (`warden.json`)

A military patrol ship for the system: 311 blocks, 265.3 t, 36 m from the sensor head to the
nozzles, 18 m across the engine block, 10 m from keel to superstructure. A long, flat bow runs out
ahead of a command bridge and tapers to a sensor head; the cabin sits over the spine with a
stepped superstructure rising toward the stern; the stern is one heavy block of nineteen engine
bells. The bridge is the ship's face: a band of tall glass across the bow that turns both corners
and runs three cells down each flank, the pilot forward at the glass with a crew station either
side, the captain's chair raised on its dais behind them, and the holo table and the weapons station
beside the captain. It outruns the starter by half again while turning a little slower than it on
every axis. −Z is the bow, +X starboard, +Y up.

**Role:** a frigate (no role in the skill's table fits: a warship between a fighter and a hauler).
**Twist:** a long spine with the bridge set well back over it, the stern a wall of engines. The
owner's concept image gave the silhouette, not the look: the style guide's chunky, warm, dim
blocks and palettes, never the image's gritty grey.

**Revised 2026-10-09** for a command bridge
(`docs/superpowers/specs/2026-10-09-ship-bridge-design.md`). The owner on the first Warden: "The
exteriors look pretty cool. I think biggest complaint is the cockpit. The cockpit seems like it is
being just copied and pasted from the starter model. These big ships would benefit from more of a
bridge with a wide looping view and a pilot seat kind of set back with other control seats
included." The starter's pod is gone; the silhouette, size and feel are kept as close as the bridge
allowed (296 blocks and 260.4 t before; the figures below).

**Revised 2026-11-04** so it can be boarded on foot when it lands on a world: the two engine pods'
forward retros moved two cells forward, out of the landing ramp's path (*Boardable on a world*,
below). Nothing else changed.

## The decks

`to-plan warden` prints them (bow up, port on the left; turrets included, as of 2026-11-04):

```
deck y=2    x: -1 .. 1
z 0  Fk Fk Fk
z 1  Fh Fh Fh
z 2  Fh Tl Fh
z 3  Fh Fh Fh
z 4  Fh Fh Fh

deck y=1    x: -3 .. 3
z -6  .    Fs   Fs   Fs   Fs   Fs   .
z -5  Fs8  Fh   Fh   Fh   Fh   Fh   Fs12
z -4  Fs8  Fh   Fh   Tl   Fh   Fh   Fs12
z -3  Fs8  Fh   Fh   Fh   Fh   Fh   Fs12
z -2  Fs8  Fh   Fh   Fh   Fh   Fh   Fs12
z -1  Fs8  Fh   Fl   Fl   Fl   Fh   Fs12
z 0   Fs8  Fh   H    H    H    Fh   Fs12
z 1   Fs8  Fh   Qc   H    Qc   Fh   Fs12
z 2   Fs8  Fh   H    K    H    Fh   Fs12
z 3   Fs8  Fh   H    H    H    Fh   Fs12
z 4   Fs8  Fh   H    H    H    Fh   Fs12
z 5   .    .    T    T    T    .    .

deck y=0    x: -4 .. 4
z -11  .    .    .    .    Rv   .    .    .    .
z -10  .    .    .    .    .    .    .    .    .
z -9   .    .    .    .    Th   .    .    .    .
z -8   .    .    .    .    Fh   .    .    .    .
z -7   .    .    .    .    Fk4  .    .    .    .
z -6   .    Rb   C    C    C    C    C    Rb   .
z -5   .    C8   Cs   D    Hm   D    Cs   C12  .
z -4   .    C8   D    D    D    D    D    C12  .
z -3   .    C8   Cp12 D    Cc   D    Ws   C12  .
z -2   .    Ar   Qk12 D    D    D    Qk8  Ar   .
z -1   .    Ar   Bk   Bk   D    Wr   Wr   Ar   .
z 0    .    Ar   Bk   Bk   D    Wr   Wr   Ar   .
z 1    .    Tl3  Gy   Gy   D    Ba   Cl   Tl1  .
z 2    .    A    D    D    D    D    D    H    .
z 3    Rv   H    D    D    D    D    D    H    Rv
z 4    R>   H    D    D    Qk   Qm   D    H    R<
z 5    T    T    T    T    T    T    T    T    T

deck y=-1    x: -4 .. 4
z -12  .    .    .    .    H    .    .    .    .
z -11  .    .    .    R>   H    R<   .    .    .
z -10  .    .    .    R>   H    R<   .    .    .
z -9   .    .    .    R^   H    R^   .    .    .
z -8   .    .    Fs10 Rv   H    Rv   Fs14 .    .
z -7   .    .    Fs10 Rv   H    Rv   Fs14 .    .
z -6   .    .    Fs10 H    H    H    Fs14 .    .
z -5   .    .    Fs10 R^   H    R^   Fs14 .    .
z -4   .    Rb   Fs10 H    G    H    Fs14 Rb   .
z -3   .    Fh2  Fs10 H    H    H    Fs14 Fh2  .
z -2   .    Fh2  Fs10 H    H    H    Fs14 Fh2  .
z -1   .    Fh2  Fs10 H    H    H    Fs14 Fh2  .
z 0    Rb   Fh2  Fs10 H    H    H    Fs14 Fh2  Rb
z 1    .    Fh2  Fs10 H    G    H    Fs14 Fh2  .
z 2    .    Fh2  Fs10 H    H    H    Fs14 Fh2  .
z 3    R>   H    H    Qc   H    Qc   H    H    R<
z 4    R^   H    H    H    H    H    H    H    R^
z 5    T    H    T    T    T    T    T    H    T

deck y=-2    x: 0 .. 0
z -11  R^
z -10  Fh2
z -9   Fh2
z -8   Fh2
z -7   Fh2
z -6   Tl2
z -5   Fh2
z -4   Fh2
z -3   Fh2
z -2   Fh2
z -1   Fh2
z 0    Fh2
z 1    Tl2
z 2    Fh2
z 3    Fh2
z 4    Fh2
```

## Targets and what it reached

The brief: "a frigate style, big but not enormous but intimidating; a military ship patrolling
the system; it can go pretty fast but is not as nimble as a fighter". The revision's brief: a
command bridge in place of the pod, the silhouette, size and feel kept. The figures are
`ship_check`'s `FEEL` and `SIZE` notes and the probe's.

| Target | Meant | Reached |
|---|---|---|
| A command bridge | the helm forward at the glass, crew stations either side, the captain's chair on its dais behind, a band of glass across the bow and down the sides | helm at (0, 0, −5); stations at (±2, 0, −5), the weapons station at (2, 0, −3); captain's chair at (0, 0, −3); 5 panes across the bow and 3 down each flank; every seat sat in and stood up from |
| Keep the size | the first Warden's 296 blocks, 260.4 t, 36 × 18 × 10 m | 311 blocks, 265.3 t, 36 × 18 × 10 m (one row longer inside, no longer outside) |
| Keep the feel | turns 1.08 / 0.61 / 1.39, forward 21.9 | turns **1.09 / 0.58 / 1.40** rad/s² (pitch / yaw / roll; 1.089 / 0.575 / 1.396 exactly, the same before and after the 2026-11-04 move: yaw went from 0.5747 to 0.5754, so it now rounds up); forward **21.5** m/s² |
| Pretty fast | forward well above the starter's 14.2: 18–22 m/s² | 21.5 m/s² (19 thrusters, 5,700 kN) |
| Not as nimble as a fighter, never sluggish | every turn at or under the starter's 1.48 / 0.71 / 1.84, none under 0.5 | 1.09 / 0.57 / 1.40 |
| Steady on a patrol line | side ≥ 5 m/s² (the starter's 4.7 slides) | side **7.5**, vertical 13.2; 100 m/s sideways gone in 13 s |
| Stops like a warship | brake ≥ 5 | **5.7** m/s² (6 retros) |
| Patrols the system | warp above the starter's 14,500 km | **19,500 km** on a full store (4 cells, 1,600 QE) |
| Power with margin | made > drawn × 1.1 | 108.0 MW made, 97.9 drawn (10.3% spare) |
| Balanced under burn | under 5% of authority | pitch 0.22%, yaw 0.03%, roll 0% |
| Military | armour, an armoury, a crew berth | 6 armour blocks on the cabin's flanks, a four-cell weapon room, a four-cell bunk room |
| Usable | helm with a view, airlock, walkable cabin, the droid's needs | one airlock, 51 walkable cells on one storey, closet dock, 31 jobs all reachable; 20 windows outside for 20 inside |
| Boardable on a world (2026-11-04) | a plain `ramp` line on every outer airlock, nothing in its way | `ramp: 4.05 m, 8.10 m at 30°` (it said `through the hull at [(-4, -1, 2)] — NOT BOARDABLE ON A WORLD`) |
| Lifts off a 7 m/s² world | `lift` at least 1.3 × | **13.2** m/s², **1.88 ×** (unchanged) |
| Frames | every probe `fps` ≥ 120 | worst **121** seated by a rock with both light groups and a second ship 300 m off (123 without it), on a quiet machine, 2026-11-03. After the 2026-11-04 move, with another designer's probe running beside it: **121** by a rock and **119** with a second ship in the cleanest run; four interleaved pairs, original against revised, read 119.3 / 116.0 by a rock and 113.8 / 113.5 with a second ship on average (the original alone ranged 104–121 in them), so no change the noise can show |

**Turns.** Yaw is 0.04 under the first Warden's: the bridge row moved mass 2 m forward and yaw
inertia grows with it. Pitch is 0.01 over: the bow's vertical rcs had to be rearranged (below), and
the nearest arrangement with every exhaust open came out a little stronger, not weaker.

## Why the unusual blocks are where they are

- **The bridge** is the cabin's whole 5-cell width and four rows deep (z −5..−2), one row farther
  forward than the old pod bridge: the glass row is at z = −6, where the bow ridge's ramp was.
  - **The glass:** five canopies across the bow (z = −6) and three down each flank (`C8` to port,
    `C12` to starboard, z −5..−3, their slopes facing out), so the band turns both front corners
    with a post in each and runs back past the captain. The roof's `fairing_slope` row overhangs
    the front glass and the `Fs8` / `Fs12` roof edges overhang the side glass, so from outside the
    band is a dark strip of panes under the red-striped visor, all the way round.
  - **The front row** (z = −5): the `helm` on the centreline (an odd width keeps the middle of
    its view clear: one post 40° to each side) and a `crew_station` either side at the corners of
    the glass, all facing forward. The pilot sits forward, at the glass.
  - **The open row** (z = −4): routes never cross a fixture, so the front row is reached from here;
    it is also where you stand up from the helm and the front stations.
  - **The captain's row** (z = −3): the `captain_chair` on the centreline on its dais, open floor
    either side of it, its ramp onto the corridor's head at (0, 0, −2). From the chair the captain
    looks over the pilot's head through the whole band. To port the bridge computer's holo table
    (`Cp12`) faces starboard, so its operator stands at (−1, 0, −3) beside the captain and looks
    out of the port side glass across it. To starboard the `weapons_station` (the former third crew station) faces forward; you
    stand up from it to port, beside the chair.
  - **The two bridge quantum cores** stand in the bridge's back corners (z = −2), turned inboard
    (`Qk12`, `Qk8`) so their gauges face the deck, not the rooms behind them; each keeps a
    porthole in the armour behind it.
- **The cabin on the spine, the bow below the helm.** Everything walkable is on y = 0 (ladders
  don't climb yet). The bow is one storey lower, at y = −1, so from the bridge you look out over a
  long, flat foredeck; its top is the cabin's floor level and sits under the band's sill. A low
  ridge of `fairing_half` on the bow's centreline (y = 0, z −9..−8, ramped down at z = −7) gives
  it a spine without crossing the view.
- **Three quantum cores.** 19 thrusters and 28 rcs draw 85 MW alone; one core makes 36. The third
  stands at the end of the corridor in the engine room (z = 4), facing forward down it, with the
  quantum machine beside it. It sits on the centreline because there, port of centre, it put the
  centre of mass 7.5 cm to port and the yaw imbalance at 3%.
- **Rooms:** a four-cell crew berth (`bunk_room`) to port and a four-cell armoury
  (`weapon_room`) to starboard, a two-cell galley, the bathroom and the droid's closet. Every
  outer room cell has a porthole. The rear rows (z 2..4) are open deck, a cross-passage to the
  airlock and the engine room.
- **The airlock** is in the port wall at z = 2, its hatch facing port onto space, the passage
  through its inner hatch. The stern is all engines, so it could not be aft. Landed on a world, its
  sill is 4.05 m over the keel's plane, so a landing ramp 8.10 m long folds down out of it at 30°;
  the cells it comes down through, (−4..−7, −1..−2, 2), are kept empty (*Boardable on a world*).
- **Armour** (`armour`, 900 hp, 3 t) is the cabin's outer walls beside the berth, the armoury and
  the bridge's back corners (z −2..0): six blocks, two fewer than before, since the bridge's flanks
  are glass now. It looks exactly like hull outside; the portholes still cut through it.
- **The superstructure.** The roof over the cabin is `fairing_half` (1 m), with slopes
  (`Fs8`, `Fs12`) down to the walls and a `fairing_slope` visor over the front glass; behind the
  bridge a long-high ramp (`Fl`) climbs to a full tower (x −1..1, z 0..4) holding the ship core and
  two quantum cells, and a second ramp (`Fk`) and slab of `fairing_half` on top of that at y = 2.
  It steps up toward the stern, as the concept's command deck does.
- **The underside.** `Fs10` / `Fs14` slopes under the cabin's outer cells and along the bow make a
  chined belly, `fairing_half` strakes (`Fh2`, the upper half) run under the cabin's walls as an
  armoured skirt, and a keel of `fairing_half` runs under the centreline for the floods.
- **Two quantum cells low in the spine** at (±1, −1, 3) and two up in the tower: the low pair
  balances the tower's mass so the centre of mass sits on the thrust line (below).
- **RCS flush in the hull, every exhaust open.** The bow core's outer cells are lateral rcs at
  z −11 and −10. The vertical ones along the bow's sides were re-laid for the bridge: the glass
  row at z = −6 now covers the bow there, so a down-pusher (`Rv`, its exhaust up) can only sit
  where nothing is above it, at z −8 and −7, and the up-pushers (`R^`, exhaust down) went to
  z = −9, at the bow's widening, and z = −5, under the bridge floor; z = −6 is plain hull. With the
  old pattern two of them fired into the glass row (`RCS_BLOCKED`), and the first all-open swap put
  both up-pairs near the centre of mass, so pitch fell to 0.98. The engine pods at x = ±4 hold a
  vertical pair and a lateral pair each. **None of the 28 is blocked.** The sensor head's up and
  down rcs, above and below the neck (z = −11), with the two laterals there make a cross round the
  tip cube; at 22 m from the centre of mass they give a 36 m hull its pitch.
- **Retros:** one at each front corner of the glass (y = 0, z = −6), beside the band's corner
  posts, firing forward past the bridge's flanks; a pair below the side glass (y = −1, z = −4);
  and one under each flank at midship (x = ±4, y = −1, z = 0), a blister below the flank turret's
  corner that answers the bow pair under the side glass. Until 2026-11-04 that pair was the front of
  each engine pod (z = 2), where the port one stood in the landing ramp's path. The old pair at
  y = 0, z = −4 is side glass now.
- **The engine block.** 9 thrusters across y = 0, 7 across y = −1 (x −2..2 and the pods' ±4) and 3
  on the tower's stern (y = 1): 19 bells. A full burn pitches the ship with 49,529 N·m, 0.22% of
  its authority.

## Boardable on a world (revised 2026-11-04)

Landed on a world, a hull rests on its keel, and a landing ramp folds down at 30° under every
horizontal outer hatch more than 0.45 m over the keel's plane, `sill / sin 30°` long (`LandingRamp`,
built by `AirlockAlcove` only if nothing is in its way). The Warden's sill is 4.05 m up, so its ramp
is 8.10 m long and reaches 7.0 m out from the port flank, and it came down through the port engine
pod's forward retro. No ramp was built: you could land the Warden and step out, but never walk back
in. `ship_check`'s ramp line:

- before: `ramp    airlock (-3, 0, 2): ramp: 4.05 m, 8.10 m at 30° through the hull at [(-4, -1, 2)] — NOT BOARDABLE ON A WORLD`
- after: `ramp    airlock (-3, 0, 2): ramp: 4.05 m, 8.10 m at 30°`

**What moved:** the engine pods' forward retros, (±4, −1, 2) to (±4, −1, 0), two cells forward
along the flanks. That is two rows of the file. The blocks, count (311), mass (265.3 t), power,
brake (5.7 m/s², still six retros) and lift (13.2 m/s², 1.88 ×) are as they were. A retro pushes
along the hull, so it is never steering authority, and the turns are 1.089 / 0.575 / 1.396 rad/s²
before and after; the pitch imbalance under burn is still 49,529 N·m (0.22%). The centre of mass
moved 3 cm forward. Each engine pod is now a plain box, no longer a step deeper at its bottom front.
The starboard retro moved too, with nothing in its way, to keep the flanks mirrored.

**The options weighed** (four `ship_check` rounds; renders of each from eye height on the ground):

| Round | Change | Ramp | Cost |
|---|---|---|---|
| 1 | port retro one cell forward, (−4, −1, 1) | clear | right under the port flank turret, whose sky fell from 92% to 84%; a lump crowding the ramp's top |
| 2 | port retro two cells forward, (−4, −1, 0) | clear | sky 91%; it reads as a blister like the bow pair under the side glass |
| 3 | round 2, and the keel row (y = −2) taken off: the ventral turrets up into the belly at (0, −1, −6) and (0, −1, 0), the sensor head's up-pusher into the tip cube (0, −1, −11) | **2.05 m, 4.10 m** | 295 blocks, 258.4 t, turns 1.17 / 0.60 / 1.43, lift 1.93 ×, no rule broken; but the keel and its hanging turrets, the ship's lower line from every low angle (where a landed ship is seen from), are gone, and the belly reads flat |
| 4 (built) | round 2, mirrored on starboard | clear | both flank turrets 91% |

- **Moving the airlock** costs more: z = 2 is the only flank cell with open deck inside and an
  empty cell outside, and at z = 3 or 4 the pods' rcs stand outside the hatch and under it.
- **Lowering the airlock's deck** cannot be done alone: the walkable storey is y = 0 (ladders don't
  climb yet: `CUT_OFF`). The sill is 4.05 m only because the keel row sets the keel's plane
  (`Ship.keel_depth_of` counts every cell's bottom, the half-height keel fairings too), so round 3
  is the one way to a shorter ramp. It is kept aside, not built, to keep the silhouette. If landing
  legs come (about 0.4 m), this ramp grows to about 8.9 m and its path stays clear: nothing stands
  outboard of the port flank at z = 2 at any height.
- **Dropping a retro** would put the brake at 4.7 m/s² (one) or 3.8 (both), under the target of 5.

## Weapons (ship weapons spec §13)

Six `turret_light` and one `turret_heavy`, each in the place of a fairing half or a plate of
hull, and the bridge's third station made the weapons station. The `TURRETS` note reads seven
turrets, none `TURRET_BLIND` and none `TURRET_BURIED`: no cell had to be moved.

| Turret | Cell | Face | Sky clear |
|---|---|---|---|
| light, dorsal | (0, 2, 2) | up (orientation 0), on the spine behind the ramp | 100% |
| light, dorsal | (0, 1, −4) | up (0), on the bow ridge over the bridge | 98% |
| light, ventral | (0, −2, −6) | down (2), under the sensor head | 100% |
| light, ventral | (0, −2, 1) | down (2), on the keel | 100% |
| light, starboard | (3, 0, 1) | out to +x (1), a plate of the flank | 91% (92% before 2026-11-04) |
| light, port | (−3, 0, 1) | out to −x (3), a plate of the flank | 91% (92% before 2026-11-04) |
| **heavy**, forward | (0, 0, −9) | up (0), on the tip of the sensor head | 96% |

- **Why there:** a pair on top and a pair underneath, spread along the hull, so that between them
  the whole sphere is covered from both ends of the ship; the flank pair at the midship fill in
  the beams. Their 91% is the armour plate and the fairing slopes either side of each, standing
  a little proud of the flank, and the retro blister below and ahead of each (since 2026-11-04;
  one cell further aft, right under the turret, it took 84%). The heavy turret is on the nose, where its field forward is
  widest, the point of a frigate.
- **The station** is the former third crew station at (2, 0, −3), in the captain's row beside the
  chair: sitting there is the board, and, with a heavy turret aboard, the heavy turret's gun
  camera. Still five seats; the probe sits in each and walks away from each. The
  `TWO_WEAPONS_STATIONS` rule is quiet (one).
- **Mass and power as the check printed them:** 265.3 t (262.0 before): the four dorsal and
  ventral lights are 0.5 t over the fairing halves they replaced, the heavy one 1.7 t over its
  half, the two flank lights 0.2 t *under* the hull plates they replaced. 108.0 MW made and
  **97.9 MW drawn** (97.0 before: six lights at 0.1 and the heavy at 0.3; the station draws
  what the crew station did). That is **10.3% spare** (108.0 made against 97.9 drawn), about
  0.3 MW above the 10% rule, so a further draw of more than about 0.3 MW trips
  `POWER_MARGIN`. Pitch imbalance under burn went from 41,680 to 49,529 N·m of 22.7 MN·m of
  authority (0.22%); the centre of mass moved 0.15 m forward.

## The numbers (`ShipStats`, the probe)

311 blocks (6 armour, 19 thrusters, 28 rcs, 3 quantum cores, 4 cells, 11 canopies, 122 fairings,
6 light turrets and a heavy one; the helm, a captain's chair, 2 crew stations and a weapons
station, the computer), 265,300 kg, centre of mass (−0.001, −0.412, 0.223) (0.253 before the
2026-11-04 move). Thrust forward / reverse / lateral / vertical 5,700 / 1,500 / 2,000 / 3,500 kN;
inertia (20,806,150, 24,331,246, 5,225,356) kg·m²; authority (22,667,358, 14,000,000, 7,294,007)
N·m against an imbalance under burn of (49,529, 4,295, 0). 108.0 MW made, 97.9 drawn; 1,600 QE.
Sections (hp / pieces): bow 1,280 / 11 a side, midship 5,430–5,490 / 18, stern 7,820–7,860 /
21–23 (22–24 before the move); engines 2,850, quantum cores 750, computer 300, cockpit (the helm
and the 11 canopies) 720, light turrets 200 each, the heavy one 400; not crippled. Skin 223
plates, 198 chamfers, 86 corners, 521 facets, 47 nozzles (219, 186, 76 before: the blisters show
more faces than the pods' fronts did); 20 windows outside for 20 inside; 7 floods and one forward
light (on the sensor head). Landing ramp: 4.05 m sill, 8.10 m at 30°, nothing in its way.
Seats: 5 (the helm, 2 crew stations, the weapons station, the captain's chair), each sat in and
stood up from. Probe fps (GTX 960, 1280 × 720): 275 standing, 136 seated, 132 with both light
groups, 122 by a rock, 203 and 223 in the chase views, 122 with a second ship 300 m off;
re-measured on a quiet machine on 2026-11-03, 123 by a rock and 121–122 with a second ship.
Revised, 2026-11-04, beside another probe: 260 standing, 134 seated, 125 with both light groups,
121 by a rock, 178 and 203 in the chase views, 119 with a second ship 300 m off. No validator
issues; no rule broken.
