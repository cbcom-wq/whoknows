# Starter shuttle (`starter.json`)

The ship every new game starts in: 110 blocks, 104.7 t. Two decks, the cabin at y = 0 and a solid
equipment deck at y = +1, with fairings outside both. −Z is the bow, +X starboard, +Y up.
`test_starter_shuttle.gd` pins the file and its figures: changing a block means changing that pin
on purpose, with the reason here.

## The cabin (y = 0; art direction spec §3.1)

- **The bridge**, x −1..1 by z −3..−1, behind a canopy row at z = −4, hull wedges on its front
  corners. The helm (`pilot_seat`) sits in the front row facing the windshield, so the cockpit pod
  juts out through the canopy face ahead of it (cockpit pod spec §7).
- **The bridge computer** (`computer`, facing aft) in the port front corner beside the helm: you
  stand aft of it and look forward over the holo, out of the shoulder window (bridge computer spec
  §3.2, as amended 2026-09-27). The corner's console goes to the back corner
  (`InteriorLayout._handed_consoles`). It replaced a 0.4 t deck cell with a 0.3 t table.
- **The quantum core** at the bridge's centre, straight behind the helm, facing aft so its gauge
  faces the corridor; **the quantum machine** in the starboard back corner, facing forward with its
  back to the galley's wall (quantum energy spec §5.3). With the core behind the helm you stand up
  to the helm's starboard side (`NO_STAND`).
- **A corridor** down the centreline, z 0..2, with rooms either side (interior redesign spec §7.5):
  a two-cell bunk room and a bathroom to port; a galley, a weapon room and the closet (the droid's
  dock) to starboard. Room blocks weigh and draw what deck does, so the rooms never moved the
  balance.
- **The airlock** at the stern, z = 3, between two bulkheads: its outer hatch faces aft onto space,
  its inner hatch the corridor.

## The engine pods (y = 0, x = ±3)

Two pods of hull beside the cabin's aft half, each with a main `thruster` at its stern (z = 3).

## The equipment deck and roof (y = +1; art direction spec §3.2)

- **The ship core** at (0, 1, −1), hull round it.
- **Three quantum cells** across z = 0. The spec placed two; a third at x = 0 was added for pitch
  balance (below). They were reactors; the quantum core makes the power now, and the cells keep
  their mass and hp, storing QE (quantum energy spec §5.1, §5.3).
- **Grav plating** at (±1, 1, 1).
- **A second thruster bank** on the stern roof, x −1..1 at z = 3, where the spec had plain hull
  (pitch balance, below). Hull wedges taper the nose and the stern corners.

## RCS (art direction §3 placed none)

As specified the ship had thrust only along −Z, so no turning authority at all: the flight computer
could not turn it. Eight `rcs` sit in cells the nose taper left empty, each touching a placed
block, in **opposed pairs** (an axis counts its weaker direction):

- **Yaw:** a lateral pair at the nose, (−1, 1, −4) thrusting +X and (1, 1, −4) thrusting −X.
- **Pitch and roll:** four vertical units, UP at z = −3 and DOWN at z = −4, mirrored port and
  starboard; fired differentially across the 8 m between them they roll the ship both ways. An
  earlier layout had one UP and one DOWN on opposite sides: both rolled it the same way, so it had
  no roll.
- **Braking:** every main engine faces aft, so reverse thrust was 0 and the ship could never slow
  down. The retro pair at (±2, 1, −2) thrusts +Z: 500 kN, stopping the 2-second sprint speed of
  32 m/s in about 6 s, and giving the assist something to cancel drift along Z with.

Six of the eight fire into a neighbour, so their puffs never show (`ship_check.gd`'s
`RCS_BLOCKED` notes); only the pitch-down pair is seen, and none from the seat.

## Pitch balance

Both pod thrusters at y = 0 with the equipment deck's mass at y = +1 put the centre of mass above
the thrust line: with thrust at y = 0 only, a full burn pitched the ship with 686,582 N·m against
160,000 of authority. The stern roof's three hull cells became the second thruster bank, which
brought it to −14,371 N·m, and the nose RCS trimmed the rest. The quantum core's 5 t at cabin level
then pulled the centre of mass down to about the thrust's 1.2 m average height; the fairings' 6.0 t
above the cabin (and 1.8 t of keel below) raised it 9 cm again. **A full burn now pitches it with
151,289 N·m, 4.91% of its authority, against the 5% limit (`UNBALANCED`).** Leave headroom: a little
more mass above the thrust line breaks it. Yaw is 0.3% (the machine and the table stand off the
centreline); roll 0.

## Power

The five main thrusters drew 9 MW more than the art direction's two-reactor estimate, which
assumed four; three reactors restored the margin. The quantum core now makes all 36.0 MW alone,
and the machine adds 0.5 MW of draw: **36.0 MW made, 31.3 MW drawn**, past the 34.4 MW that
`POWER_MARGIN`'s 10% asks for.

## The shape (ship exterior spec §8)

26 fairings, 0.3 t each, all outside the cabin row so nothing inside moves: a dorsal spine a metre
high (half blocks at y = 2 over z −1..2, ramped by long low slopes at z = −2 and z = 3); a fin
rising aft on each engine pod (slopes at (±3, 1, 1)); and a keel of half blocks under the
centreline (y = −1, z −3..2) for the floods to hang from. They added 7.8 t and no power draw. Every
hull section has plating or fairings outside the cabin to lose (`NO_PIECES`): 3 a side at the bow,
6 midships and 12 at the stern.

## The numbers (`ShipStats`, `data/blocks`)

110 blocks, 104,700 kg, centre of mass (0.004, 1.301, 0.160); inertia (2065526, 2865503, 1175422);
torque authority (3080229, 2040115, 2174785), imbalance under a full burn (151289, −5731, 0).
Thrust forward / reverse / lateral / vertical 1500 / 500 / 500 / 1000 kN. Turning 1.49 / 0.71 /
1.85 rad/s² (pitch / yaw / roll); forward 14.3, brake and side 4.8, vertical 9.6 m/s². 1,200 QE:
14,500 km of warp on a full store. No validator issues; no rule broken.
