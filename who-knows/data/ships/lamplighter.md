# Lamplighter (`lamplighter.json`)

A deep-range surveyor built round its bridge. The bow is a flat crossbar 22 m wide, one storey
thick, with a seven-pane windshield across its leading edge, so the helm looks out over a
panorama and the whole crew can stand at the glass. A quantum core sits in each wingtip behind
its own porthole, the two lanterns the ship is named for, and the bridge computer's holo table
stands in the port tip looking out of its window. Behind the crossbar a narrow two-storey body
holds six rooms down a corridor, six quantum cells for twice the starter's reach, and five main
engines. Thrusters on the wingtips, 10 m out, make it roll like a fighter though it yaws like
the bigger ship it is.

131 blocks, 125.7 t. −Z is the bow, +X starboard, +Y up.

- **Role:** explorer (bunks, a galley, a computer facing a window, long reach).
- **Twist:** a hammerhead bow wider than the hull: the bridge storey is 11 cells wide, the body
  behind it 5.

## The decks

Seen from above, bow up, port on the left (the `designing-a-ship` skill's plan form;
`ship_plan.gd -- to-plan lamplighter` prints it).

```
deck y=2    x: -1 .. 1
z -2  Fk  Fk  Fk
z -1  Fh  Fh  Fh
z 0   Fh  Fh  Fh
z 1   Fh  Fh  Fh
z 2   Fh  Fh  Fh
z 3   Fk4 Fk4 Fk4

deck y=1    x: -5 .. 5
z -5  Fk  .   .   .   .   .   .   .   .   .   Fk
z -4  Fl  .   .   .   .   .   .   .   .   .   Fl
z -3  .   .   .   Rb  Fs  Fs  Fs  Rb  .   .   .
z -2  .   .   .   Fs8 Qc  H   Qc  Fs12 .   .   .
z -1  .   .   .   Fs8 Qc  K   Qc  Fs12 .   .   .
z 0   .   .   .   Fs8 Qc  H   Qc  Fs12 .   .   .
z 1   .   .   .   Fs8 G   H   G   Fs12 .   .   .
z 2   .   .   .   Fs8 H   H   H   Fs12 .   .   .
z 3   .   .   .   Rv  T   T   T   Rv  .   .   .

deck y=0    x: -5 .. 5
z -5  R>  Rb   C   C   C   C   C   C   C   Rb  R<
z -4  R^  Cp12 D   D   D   S   D   D   D   Qm8 R^
z -3  Rv  Qk12 D   D   D   D   D   D   D   Qk8 Rv
z -2  W4  H    A   H   Gy  D   Cl  H   H   H   W4
z -1  .   .    .   H   Bk  D   Bk  H   .   .   .
z 0   .   .    .   H   Bk  D   Bk  H   .   .   .
z 1   .   .    .   H   Ba  D   Wr  H   .   .   .
z 2   .   .    .   R>  H   H   H   R<  .   .   .
z 3   .   .    .   R^  T   H   T   R^  .   .   .

deck y=-1    x: 0 .. 0
z -2  Fh2
z -1  Fh2
z 0   Fh2
z 1   Fh2
z 2   Fh2
```

## Targets

Written as numbers before the first block was drawn; reached as `ship_check` and the probe print
them.

| Target | Wanted | Reached |
|---|---|---|
| Blocks | ≤ 160 | 131 |
| Mass | 120–150 t | 125.7 t |
| Power | made ≥ 1.25 × drawn | 72.0 MW made, 40.4 drawn (1.78 ×) |
| Warp | ≥ 29,000 km | 29,500 km on 2,400 QE |
| Pitch | ≥ 1.0 rad/s² | 1.94 |
| Yaw | ≥ 0.5 rad/s² | 0.64 |
| Roll | ≥ 2.0 rad/s² | 2.70 |
| Side | ≥ 5 m/s² | 8.0 (100 m/s sideways gone in 13 s) |
| Vertical | ≥ 8 m/s² | 15.9 |
| Brake | ≥ 4 m/s² | 8.0 |
| Forward | 9–12 m/s² | 11.9 |
| Rooms | ≥ 6 | 6 (two bunk rooms, galley, bathroom, closet, weapon room) |
| Windows | ≥ 8 portholes, all matched | 16 outside for 16 inside (10 portholes, 6 shoulder windows) |
| Balance | < 5% each axis | pitch 2.59%, yaw 0.14%, roll 0% |
| Rules | 0 broken | 0 broken, no `RCS_BLOCKED` note (all 16 rcs puff in the open) |
| Droid | every job | dock in the closet, 19 jobs, none unreachable |
| fps | ≥ 120 | 127 seated by a rock with both light groups (126 with a second ship 300 m off) |

## The bridge (y = 0, z −5 .. −3)

- **The windshield:** seven canopies across x −3..3 at z = −5. The helm (`S`) at (0, 0, −4) looks
  at the middle one, so its pod juts out there; the other six faces are shoulders, each a desk
  under a window, and the lights panel goes on the starboard one next to the helm. The cell behind
  the helm, (0, 0, −3), is open deck: you stand up into it.
- **Two rows deep, on purpose.** `DeckPaths` never walks through a fixture's cell, so a one-row
  bridge would be cut in two at the helm; the second row, z = −3, is the way round it and the
  bridge's common floor.
- **The port wingtip:** the bridge computer (`Cp12`, facing +x) at (−4, 0, −4). You stand at
  (−3, 0, −4) and look to port over the holo, out of the porthole in the table's own outer wall
  (a quiet fixture's wall on the skin goes porthole). Behind it the port quantum core (`Qk12`,
  facing the bridge).
- **The starboard wingtip:** the quantum machine (`Qm8`, facing −x, toward the bridge) and the
  starboard quantum core (`Qk8`). Machine 0.5 t against the table's 0.3 t: the yaw imbalance is
  0.14% of authority.
- **Two quantum cores.** One core's 36 MW would not cover the 40.4 MW this ship draws; they sit
  mirrored at the wingtips, 8 m out, so they cost no balance, and each has a porthole beside it.
- **The airlock** is on the crossbar's trailing edge at (−3, 0, −2), not at the stern: hull on
  either side of it, its outer hatch faces aft onto space along the body, and its inner hatch
  opens straight forward onto the bridge's back row. This leaves the stern to the engines. Its
  starboard twin cell (3, 0, −2) is plain hull, 0.2 t lighter.

## The body (y = 0, z −2 .. 3)

- **A corridor** down x = 0 from the bridge to z = 1, with rooms either side, each opening onto it:
  to port the galley (beside the bridge), a two-cell bunk room and the bathroom; to starboard the
  closet (the droid's dock, beside the bridge), a second two-cell bunk room and the weapon room.
  Every room but the galley and the closet has a porthole; those two sit behind the crossbar's
  trailing edge, two solid cells from space.
- **The stern:** a row of hull at z = 2 with a lateral rcs at each corner, then two main engines
  at (±1, 0, 3) either side of a hull plate.

## Equipment and roof (y = 1)

- **The core** at (0, 1, −1); six **quantum cells** in the x = ±1 columns, z −2..0 (2,400 QE);
  **grav plating** at (±1, 1, 1); hull fill.
- **Three main engines** at (−1..1, 1, 3) over the two at y = 0: five in all, 1,500 kN. Three
  high and two low put the thrust line at 1.2 m against a centre of mass at 1.10 m: a full burn
  pitches it with 155,600 N·m, 2.59% of its 6.0 MN·m authority.
- **Sloped shoulders:** the outer columns x = ±2, z −2..2, are `fairing_slope` facing outward
  (`Fs8` to port, `Fs12` to starboard), low on the outside, so the body's top edges run as one
  chamfer instead of a box. Each is outside the cabin's shell, so they are the midship and stern
  sections' pieces to lose.
- **A ramp** of three `fairing_slope` at (−1..1, 1, −3), over the bridge's back row, rising aft
  from the crossbar's roof onto the body.
- **Wingtip fins:** a long ramp (`Fk` then `Fl`) over each wingtip's lateral rcs and up-thruster,
  rising aft to 2 m. They are the bow sections' only pieces (2 a side) and mark the tips.

## RCS (16, every exhaust open)

Every rcs has the face opposite its push onto space, so all of them puff where they can be seen
(the starter shows 2 of its 8).

- **Wingtips** (x = ±5, 10 m out): a lateral pushing inward at z = −5 (`R>` port, `R<`
  starboard, exhausts outboard), an up-thruster at z = −4 (exhaust down) and a down-thruster at
  z = −3 (exhaust up, so the cell over it stays empty). The vertical pairs fired across 20 m give
  most of the roll; fired together, the bow's pitch.
- **Retros:** a pair on the leading edge at (±4, 0, −5), and a second on the body's front at
  (±2, 1, −3), all exhausting forward: 1,000 kN of brake.
- **Stern:** a lateral each side at (±2, 0, 2), an up-thruster at (±2, 0, 3) and a down-thruster
  at (±2, 1, 3), mirrored, for pitch, roll and yaw at the other end from the bow's.

## Shape and the keel

A spine of `fairing_half` at y = 2 over the body (z −1..2) with long low ramps at z = −2 and 3, as
the starter's; a keel of `fairing_half` under the corridor (y = −1, z −2..2) for the floods; tail
tapers (`W4`) at the crossbar's trailing corners. The crossbar is left one storey thick, so from
any side the bow reads as a flat hammer in front of a taller body.

## The numbers (`ShipStats`, the probe)

131 blocks, 125,700 kg, centre of mass (0.003, 1.096, −1.540). Thrust forward / reverse /
lateral / vertical 1500 / 1000 / 1000 / 2000 kN; authority (6,000,000, 3,500,000, 7,548,130)
N·m against an imbalance under a full burn of (−155,609, −4,773, 0). Turning 1.94 / 0.64 / 2.70
rad/s² (pitch / yaw / roll); forward 11.9, brake and side 8.0, vertical 15.9 m/s². 72.0 MW made,
40.4 drawn; 2,400 QE, 29,500 km of warp. Sections (hp / pieces): bow 930 / 2 and 1,030 / 2,
midship 2,970 / 10 a side, stern 1,730 / 12 a side; not crippled as built. Skin: 127 plates, 77
chamfers, 24 corners, 188 facets, 21 nozzles; 6 floods and 2 forward lights. No validator issue;
no rule broken.
