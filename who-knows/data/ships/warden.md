# Warden patrol frigate (`warden.json`)

A military patrol ship for the system: 311 blocks, 262.0 t, 36 m from the sensor head to the
nozzles, 18 m across the engine block, 10 m from keel to superstructure. A long, flat bow runs out
ahead of a command bridge and tapers to a sensor head; the cabin sits over the spine with a
stepped superstructure rising toward the stern; the stern is one heavy block of nineteen engine
bells. The bridge is the ship's face: a band of tall glass across the bow that turns both corners
and runs three cells down each flank, the pilot forward at the glass with a crew station either
side, the captain's chair raised on its dais behind them, and the holo table and a third station
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

## The decks

`to-plan warden` prints them (bow up, port on the left):

```
deck y=2    x: -1 .. 1
z 0  Fk Fk Fk
z 1  Fh Fh Fh
z 2  Fh Fh Fh
z 3  Fh Fh Fh
z 4  Fh Fh Fh

deck y=1    x: -3 .. 3
z -6  .    Fs   Fs   Fs   Fs   Fs   .
z -5  Fs8  Fh   Fh   Fh   Fh   Fh   Fs12
z -4  Fs8  Fh   Fh   Fh   Fh   Fh   Fs12
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
z -9   .    .    .    .    Fh   .    .    .    .
z -8   .    .    .    .    Fh   .    .    .    .
z -7   .    .    .    .    Fk4  .    .    .    .
z -6   .    Rb   C    C    C    C    C    Rb   .
z -5   .    C8   Cs   D    Hm   D    Cs   C12  .
z -4   .    C8   D    D    D    D    D    C12  .
z -3   .    C8   Cp12 D    Cc   D    Cs   C12  .
z -2   .    Ar   Qk12 D    D    D    Qk8  Ar   .
z -1   .    Ar   Bk   Bk   D    Wr   Wr   Ar   .
z 0    .    Ar   Bk   Bk   D    Wr   Wr   Ar   .
z 1    .    H    Gy   Gy   D    Ba   Cl   H    .
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
z 0    .    Fh2  Fs10 H    H    H    Fs14 Fh2  .
z 1    .    Fh2  Fs10 H    G    H    Fs14 Fh2  .
z 2    Rb   Fh2  Fs10 H    H    H    Fs14 Fh2  Rb
z 3    R>   H    H    Qc   H    Qc   H    H    R<
z 4    R^   H    H    H    H    H    H    H    R^
z 5    T    H    T    T    T    T    T    H    T

deck y=-2    x: 0 .. 0
z -11  R^
z -10  Fh2
z -9   Fh2
z -8   Fh2
z -7   Fh2
z -6   Fh2
z -5   Fh2
z -4   Fh2
z -3   Fh2
z -2   Fh2
z -1   Fh2
z 0    Fh2
z 1    Fh2
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
| A command bridge | the helm forward at the glass, crew stations either side, the captain's chair on its dais behind, a band of glass across the bow and down the sides | helm at (0, 0, −5); stations at (±2, 0, −5) and (2, 0, −3); captain's chair at (0, 0, −3); 5 panes across the bow and 3 down each flank; every seat sat in and stood up from |
| Keep the size | the first Warden's 296 blocks, 260.4 t, 36 × 18 × 10 m | 311 blocks, 262.0 t, 36 × 18 × 10 m (one row longer inside, no longer outside) |
| Keep the feel | turns 1.08 / 0.61 / 1.39, forward 21.9 | turns **1.13 / 0.59 / 1.40** rad/s² (pitch / yaw / roll); forward **21.8** m/s² |
| Pretty fast | forward well above the starter's 14.3: 18–22 m/s² | 21.8 m/s² (19 thrusters, 5,700 kN) |
| Not as nimble as a fighter, never sluggish | every turn at or under the starter's 1.49 / 0.71 / 1.85, none under 0.5 | 1.13 / 0.59 / 1.40 |
| Steady on a patrol line | side ≥ 5 m/s² (the starter's 4.8 slides) | side **7.6**, vertical 13.4; 100 m/s sideways gone in 13 s |
| Stops like a warship | brake ≥ 5 | **5.7** m/s² (6 retros) |
| Patrols the system | warp above the starter's 14,500 km | **19,500 km** on a full store (4 cells, 1,600 QE) |
| Power with margin | made > drawn × 1.1 | 108.0 MW made, 97.0 drawn (11.3% spare) |
| Balanced under burn | under 5% of authority | pitch 0.18%, yaw 0.03%, roll 0% |
| Military | armour, an armoury, a crew berth | 6 armour blocks on the cabin's flanks, a four-cell weapon room, a four-cell bunk room |
| Usable | helm with a view, airlock, walkable cabin, the droid's needs | one airlock, 51 walkable cells on one storey, closet dock, 31 jobs all reachable; 20 windows outside for 20 inside |
| Frames | every probe `fps` ≥ 120 | worst **123** seated by a rock with both light groups (and with a second ship 300 m off) |

**Turns.** Yaw is 0.02 under the first Warden's: the bridge row moved mass 2 m forward and yaw
inertia grows with it. Pitch is 0.05 over: the bow's vertical rcs had to be rearranged (below), and
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
    out of the port side glass across it. To starboard a third crew station faces forward; you
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
  through its inner hatch. The stern is all engines, so it could not be aft.
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
  and one at the front of each engine pod (z = 2). The old pair at y = 0, z = −4 is side glass now.
- **The engine block.** 9 thrusters across y = 0, 7 across y = −1 (x −2..2 and the pods' ±4) and 3
  on the tower's stern (y = 1): 19 bells. A full burn pitches the ship with 41,680 N·m, 0.18% of
  its authority.

## The numbers (`ShipStats`, the probe)

311 blocks (6 armour, 19 thrusters, 28 rcs, 3 quantum cores, 4 cells, 11 canopies, 127 fairings;
the helm, a captain's chair, 3 crew stations, the computer), 262,000 kg, centre of mass
(−0.001, −0.414, 0.403). Thrust forward / reverse / lateral / vertical 5,700 / 1,500 / 2,000 /
3,500 kN; authority (22,802,290, 14,000,000, 7,293,321) N·m against an imbalance under burn of
(41,680, 4,351, 0). 108.0 MW made, 97.0 drawn; 1,600 QE. Sections (hp / pieces): bow 1,300 / 13 a
side, midship 5,470–5,530 / 19, stern 8,060–8,100 / 24–26; engines 2,850, quantum cores 750,
computer 300, cockpit (the helm and the 11 canopies) 720; not crippled. Skin 194 plates, 146
chamfers, 56 corners, 559 facets, 47 nozzles; 20 windows outside for 20 inside; 7 floods and one
forward light (on the sensor head). Seats: 5 (the helm, 3 stations, the captain's chair), each sat
in and stood up from. Probe fps (GTX 960, 1280 × 720): 282 standing, 137 seated, 134 with both
light groups, 123 by a rock, 210 and 228 in the chase views, 123 with a second ship 300 m off. No
validator issues; no rule broken.
