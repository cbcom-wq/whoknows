# Warden patrol frigate (`warden.json`)

A military patrol ship for the system: 296 blocks, 260.4 t, 36 m from the sensor head to the
nozzles, 18 m across the engine block, 10 m from keel to superstructure. A long, flat bow runs out
ahead of a raised bridge and tapers to a sensor head; the cabin sits over the spine with a
stepped superstructure rising toward the stern; the stern is one heavy block of nineteen engine
bells. It is two and a half times the starter's size and still well under the 400-block limit,
and it outruns the starter by half again while turning a little slower than it on every axis.
−Z is the bow, +X starboard, +Y up.

**Role:** a frigate (no role in the skill's table fits: a warship between a fighter and a hauler).
**Twist:** a long spine with the bridge set well back over it, the stern a wall of engines. The
owner's concept image gave the silhouette, not the look: the style guide's chunky, warm, dim
blocks and palettes, never the image's gritty grey.

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
z -5  .    Fs   Fs   Fs   Fs   Fs   .
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
z -7   .    .    .    .    Fh   .    .    .    .
z -6   .    .    .    .    Fk4  .    .    .    .
z -5   .    .    C    C    C    C    C    .    .
z -4   .    Rb   D    Cp4  S    D    D    Rb   .
z -3   .    Ar   D    D    D    D    D    Ar   .
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
z -9   .    .    .    H    H    H    .    .    .
z -8   .    .    Fs10 Rv   H    Rv   Fs14 .    .
z -7   .    .    Fs10 R^   H    R^   Fs14 .    .
z -6   .    .    Fs10 Rv   H    Rv   Fs14 .    .
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
the system; it can go pretty fast but is not as nimble as a fighter". The targets were written
before the first plan; the figures are `ship_check`'s `FEEL` and `SIZE` notes (and the probe's).

| Target | Meant | Reached |
|---|---|---|
| Big but not enormous | 220–300 blocks, at least twice the starter's 16 m length | 296 blocks, 260.4 t; 36 m × 18 m × 10 m |
| Pretty fast | forward well above the starter's 14.3: 18–22 m/s² | **21.9** m/s² (19 thrusters, 5,700 kN) |
| Not as nimble as a fighter, never sluggish | every turn at or under the starter's 1.49 / 0.71 / 1.85, none under 0.5 | **1.08 / 0.61 / 1.39** rad/s² (pitch / yaw / roll) |
| Steady on a patrol line | side ≥ 5 m/s² (the starter's 4.8 slides) | side **7.7**, vertical 13.4; 100 m/s sideways gone in 13 s (the starter 21 s) |
| Stops like a warship | brake ≥ 5 | **5.8** m/s² (6 retros) |
| Patrols the system | warp above the starter's 14,500 km | **19,500 km** on a full store (4 cells, 1,600 QE) |
| Power with margin | made > drawn × 1.1 | 108.0 MW made, 95.8 drawn (12.7% spare) |
| Balanced under burn | under 5% of authority | pitch 0.31%, yaw 0.13%, roll 0% |
| Military | armour, an armoury, a crew berth | 8 armour blocks on the bridge's flanks, a four-cell weapon room, a four-cell bunk room |
| Usable | helm with a view, airlock, walkable cabin, the droid's needs | pod at the helm, one airlock, 45 walkable cells on one storey, closet dock, 31 jobs all reachable |
| Frames | every probe `fps` ≥ 120 | worst 127–128 seated by a rock with both light groups (with and without a second ship); 124 with a ship arriving |

## Why the unusual blocks are where they are

- **The cabin on the spine, the bow below the helm.** Everything walkable is on y = 0 (ladders
  don't climb yet). The bow is one storey lower, at y = −1, so from the helm you look out over a
  long, flat foredeck; its top is the cabin's floor level and sits under the pod's sill. A low
  ridge of `fairing_half` on the bow's centreline (y = 0, z −9..−7, ramped down at z = −6) gives
  it a spine without crossing the view.
- **The bridge** spans the cabin's whole 5-cell width behind a 5-wide canopy row: the helm in the
  middle (its pod), the bridge computer `Cp4` to port of it facing aft so its operator looks out
  of the port shoulder window, as on the starter. The cell behind the helm is open deck to stand up
  into. Two quantum cores stand in the bridge's back corners, turned inboard (`Qk12`, `Qk8`) so
  their gauges face the deck, not the rooms behind them.
- **Three quantum cores.** 19 thrusters and 28 rcs draw 85 MW alone; one core makes 36. The third
  stands at the end of the corridor in the engine room (z = 4), facing forward down it, with the
  quantum machine beside it. It sits on the centreline because there, port of centre, it put the
  centre of mass 7.5 cm to port and the yaw imbalance at 3%; centred, 0.13%.
- **Rooms:** a four-cell crew berth (`bunk_room`) to port and a four-cell armoury
  (`weapon_room`) to starboard, a two-cell galley, the bathroom and the droid's closet. Every
  outer room cell has a porthole (15 windows, all matched outside). The rear rows (z 2..4) are
  open deck, a cross-passage to the airlock and the engine room.
- **The airlock** is in the port wall at z = 2, its hatch facing port onto space, the passage
  through its inner hatch. The stern is all engines, so it could not be aft.
- **Armour** (`armour`, 900 hp, 3 t) is the bridge's and the berth's outer walls, z −3..0: the
  part of the cabin a fight faces. It looks exactly like hull outside; the portholes still cut
  through it (one solid cell to space).
- **The superstructure.** The roof over the cabin is `fairing_half` (1 m), with slopes
  (`Fs8`, `Fs12`) down to the walls; behind the bridge a long-high ramp (`Fl`) climbs to a full
  tower (x −1..1, z 0..4) holding the ship core and two quantum cells, and a second ramp (`Fk`)
  and slab of `fairing_half` on top of that at y = 2. It steps up toward the stern, as the
  concept's command deck does.
- **The underside.** `Fs10` / `Fs14` slopes under the cabin's outer cells and along the bow make a
  chined belly, `fairing_half` strakes (`Fh2`, the upper half) run under the cabin's walls as an
  armoured skirt, and a keel of `fairing_half` runs under the centreline for the floods.
- **Two quantum cells low in the spine** at (±1, −1, 3) and two up in the tower: the low pair
  balances the tower's mass so the centre of mass sits on the thrust line (below).
- **RCS flush in the hull.** Every rcs is part of the hull's skin with its exhaust face open, not
  stuck on: the bow core's outer cells are lateral rcs at z −11 and −10, then vertical ones
  alternating up and down (z −8..−5); the engine pods at x = ±4 hold a vertical pair and a lateral
  pair each. **None of the 28 is blocked**: every puff shows. The one exception is the sensor
  head: an up and a down rcs above and below the neck (z = −11) with the two laterals there make a
  cross round the tip cube, the frigate's sensor head. They are the farthest from the centre of
  mass (22 m), which is what gives a 36 m hull its pitch.
- **Retros:** a stacked pair at each front corner of the bridge (y = 0 and −1, z = −4), where the
  pilot sees them fire forward out of the shoulder windows, and one at the front of each engine pod
  (z = 2). An earlier pair at the bow's widening (z = −8) went to the bridge corners to keep the
  bow's taper clean.
- **The engine block.** 9 thrusters across y = 0, 7 across y = −1 (x −2..2 and the pods' ±4) and 3
  on the tower's stern (y = 1): 19 bells. Their mean height is 0.42 m below the cabin row's
  centre, and the centre of mass is at −0.43 m, so a full burn pitches the ship with only
  64,747 N·m, 0.31% of its authority.

## The numbers (`ShipStats`, the probe)

296 blocks (8 armour, 19 thrusters, 28 rcs, 3 quantum cores, 4 cells, 121 fairings), 260,400 kg,
centre of mass (−0.003, −0.432, 0.589); inertia (19,315,343, 22,947,631, 5,253,308). Thrust
forward / reverse / lateral / vertical 5,700 / 1,500 / 2,000 / 3,500 kN; authority (20,941,820,
14,000,000, 7,284,562) N·m against an imbalance under burn of (−64,747, 17,513, 0). 108.0 MW made,
95.8 drawn; 1,600 QE. Sections (hp / pieces): bow 1,420 / 12 a side, midship 5,980–6,040 / 21,
stern 8,060–8,100 / 24–26; engines 2,850, quantum cores 750, computer 300, cockpit 360; not
crippled. Skin 188 plates, 122 chamfers, 40 corners, 512 facets, 47 nozzles; 15 windows outside for
15 inside; 7 floods and one forward light (on the sensor head). Probe fps (GTX 960, 1280 × 720,
alone on the machine): 284 standing, 143 seated, 140 with both light groups, 128 by a rock, 211
and 228 in the chase views, 128 with a second ship 300 m off; 124 with a frigate arriving. No
validator issues; no rule broken.
