---
name: designing-a-ship
description: Use when designing a new ship for the who-knows Godot project, or reshaping a library ship, from a description or "be creative" - choosing its role, size, decks, rooms and flight feel, and drawing it as a deck plan. The ship-designer agent runs on it; building-a-ship then builds and proves the result.
---

# Designing a ship

## Overview

This is the judgment half of making a ship: a brief becomes **numbers to hit** and a **deck plan**.
`building-a-ship` (beside this skill) is how to build and prove one, its checklist and its
*Mistakes already made*. Read both; this skill never repeats that one. The spec is
`docs/superpowers/specs/2026-10-09-ship-designer-design.md`.

**Existing blocks only** (`who-knows/data/blocks/`). A ship that wants a block the game lacks says
so in its report ("blocks I wished for"); never add one. **Every ship is usable:** boarded, flown,
walked and saved. **At most 400 blocks** (`ShipRules.MOST_BLOCKS`; more breaks `TOO_BIG`).

## The tools

From the worktree's `who-knows` folder, with `godot` the console exe (`run_tests.ps1` has its
path) and `$k = <worktree>\.claude\skills\building-a-ship`:

| Do | Command |
|---|---|
| Print a ship as a plan | `godot --headless --path . --script $k\ship_plan.gd -- to-plan <id or ship .json> <abs out.plan>` |
| Plan to ship file | `godot --headless --path . --script $k\ship_plan.gd -- to-json <abs plan> <abs out\<id>.json>` |
| Check it (about 2 s) | `godot --headless --path . --script $k\ship_check.gd -- <abs or res:// ship .json>` |
| Probe it, windowed | `godot --path . --resolution 1280x720 --script $k\ship_probe.gd -- <abs out dir> --ship <id>` |
| Watch it arrive | `godot --path . --resolution 1280x720 --script test\probes\arrival_render.gd -- <abs out dir> --ship <id>` |
| Prove it usable | `.\run_tests.ps1 '-gselect=test_ship_catalog.gd'` |

In a fresh worktree run `godot --headless --path . --import` once first, or every class is
"not declared".

**A probe passes** when its first line after the engine's banner is `ship    probing <id>: <name>`
(or it probed something else), no line holds `<--`, `MISMATCH`, `MISSING`, `REFUSED`, `NOT FOUND`, `UNREACHABLE`,
`SHADER ERROR` or `SCRIPT ERROR`, and every `fps` line is at least 120. `exhaust BLOCKED` is a
note: the starter has six.

## The plan

One map per storey, **seen from above, bow up, port on the left**: rows run z from the bow (−z) to
the stern, columns x from port (−x) to starboard. Each deck line gives its y and x range; each row
starts `z <n>` and holds one token per cell; `.` is empty. `#` starts a comment, except on the
`ship`, `name` and `desc` lines.

**Tokens.** Every block and orientation has one: the block's base token, then the orientation
unless it is 0 (`W3`, `Fh2`, `Cp4`).

| Token | Block | Token | Block | Token | Block |
|---|---|---|---|---|---|
| `H` | hull | `D` | deck | `K` | core |
| `S` | pilot_seat | `C` | canopy | `A` | airlock |
| `B` | bulkhead | `O` | door | `T` | thruster |
| `R` | rcs | `W` | hull_wedge | `Bk` | bunk_room |
| `Gy` | galley | `Ba` | bathroom | `Wr` | weapon_room |
| `Cl` | closet | `Cp` | computer | `Qk` | quantum_core |
| `Qm` | quantum_machine | `Qc` | quantum_cell | `G` | grav_plating |
| `Ar` | armour | `L` | ladder | `Fs` | fairing_slope |
| `Fh` | fairing_half | `Fi` | fairing_corner_in | `Fo` | fairing_corner_out |
| `Fl` | fairing_slope_long_high | `Fk` | fairing_slope_long_low | `Hm` | helm |
| `Cc` | captain_chair | `Cs` | crew_station | | |

The rcs pushes are arrows: `R<` to port (8), `R>` to starboard (12), `R^` up (16), `Rv` down (20),
`Rb` aft, a retro (4). `T` pushes forward (a main engine at the stern). Orientation codes are in
`building-a-ship/reference.md`. A `legend` section before the first deck can name its own tokens
(`X  fairing_half 2`).

## 1. The brief becomes numbers

Write the targets down **before** drawing, as `ship_check`'s `FEEL` and `SIZE` notes print them.
The starter is the yardstick: **110 blocks, 104.7 t; turns 1.49 / 0.71 / 1.85 rad/s² (pitch / yaw
/ roll); side 4.8, vertical 9.6, brake 4.8, forward 14.3 m/s²; 36 MW made, 31.3 drawn; 14,500 km
of warp.**

| The brief says | Means | Moved by |
|---|---|---|
| nimble, agile, a fighter | every turn above the starter's | rcs far from the centre of mass, less mass |
| heavy, a freighter | turns below 0.5, forward 3–8 | mass; but brake and side stay ≥ 2 or it can't stop or settle |
| fast | forward above 14 | thrusters (300 kN each) per tonne |
| steady, doesn't slide | side ≥ 5 | lateral rcs pairs (250 kN each) per tonne |
| long range | warp above 14,500 km | quantum cells (400 QE each) |
| roomy, comfortable | more rooms than the starter's five, windows | walkable cells, rooms at the hull |

A turn rate is `torque / inertia`: inertia grows with the **square** of length, so a long ship
turns slowly unless it has rcs at **both ends**.

## 2. Roles

| Role | Shape | Leans on | Watch for |
|---|---|---|---|
| shuttle | the starter: one cabin storey, an equipment storey over it; a pod | — | — |
| fighter | short, canopy forward, little inside; a pod | rcs, thrusters, a small cabin | too small for the airlock, the stand cell behind the helm and the droid's closet |
| frigate, warship | long, armoured; **a bridge** (§4b) | thrusters, armour, a weapon room, crew stations | power; the bridge's posts in the helm's view |
| hauler | long, a hold of open deck or rooms; a bridge if over ~150 blocks | quantum cells, lateral rcs | mass above the thrust line (pitch under burn); power for every walkable cell |
| explorer | bunks, galley, a computer, long reach; a bridge if over ~150 blocks | quantum cells, `Cp` facing a window | power |
| yacht | rooms with windows, comfort over speed; a bridge | rooms at the hull, `Ba`, `Gy` | the droid reaching every porthole |

## 3. Be creative

Pick one role and one twist, say which, and read the `.md` of every ship in `data/ships/` first:
never the same pair as one already there.

Twists: a ventral bridge (the helm on a lower storey); twin engine pods on outriggers; a long spine
with the cabin at the bow; a stubby brick with huge engines; a ring of rooms round the quantum
core; a hammerhead bow wider than the hull; a stern bridge looking back over the ship; a ship that
is mostly hold; an asymmetric hull (and its balance fixed by mass, not by weaker rcs).

## 4. The method

Draw and check **one layer at a time** (`to-json`, then `ship_check`), never all at the end.
`to-json` is free; a `ship_check` is a round. **If `to-json` exits non-zero, stop there:** the old
ship file is still on disk, and a `ship_check` after it checks the stale ship and can say 0 broken.

1. **The walkable storey:** the helm (`S`) looking at the canopy (`C`); the cell behind it walkable
   deck (you stand up into it); the corridor; the airlock (`A`) with one face to space and deck
   through its other (any outer edge works, not only the stern); the rooms, each touching walkable
   space; a closet (`Cl`) for the droid; every porthole, console and fixture it tends reachable on
   foot. **Draw a bridge two rows deep:** `DeckPaths` never crosses a fixture, so a one-row bridge
   is cut in two at the helm. One walkable storey for now: ladders don't climb yet (`CUT_OFF`).
   Walkable cells need nothing above or below them: the skin plates them, which is how a big ship
   stays light.
2. **The equipment storey** over or under it: the core (`K`), quantum cells, grav plating (only mass
   and power in play today: it decides nothing else).
3. **Power** (§5).
4. **Engines and rcs** sized to the targets: main thrusters at the stern pushing forward, a retro
   pair, rcs in opposed pairs on every axis, port and starboard mirrored, every rcs's exhaust face
   open (`ship_check` notes `RCS_BLOCKED`). **Set rcs flush, as outer hull cells,** not as pods
   stuck on: pods read as clutter, and a flush rcs puffs as well when its exhaust face is open.
5. **The outside:** wedges and fairings outside the cabin row; the skin chamfers for free. A
   chamfer along a flank faces the slope outward: `Fs8` / `Fs12` on a roof edge to port /
   starboard, `Fs10` / `Fs14` on a belly edge. `Fs1` / `Fs3` make a sawtooth.
6. **Mirror port and starboard** unless the twist says otherwise, and keep heavy blocks (quantum
   cores and cells, 5 t) on the centreline or in mirrored pairs: one core 4 m off-centre put a
   260 t ship's yaw imbalance at 3%.
7. **Probe while you design, to see the shape:** green rules prove nothing about looks, and a first
   draft can pass every rule and look like a shuttle on a pole. Write the `.md` last.

Windows: a walkable cell facing space gets a porthole, and so does a quiet fixture (core, machine,
computer) on an outer side wall; a cell beside a canopy gets consoles, not glass.

## 4b. Bridges

A ship over about 150 blocks, a warship, or anything with a crew gets a **command bridge**, not
the starter's pod (the owner, 2026-10-09: "These big ships would benefit from more of a bridge
with a wide looping view": `docs/superpowers/specs/2026-10-09-ship-bridge-design.md`). The
`helm` (`Hm`) flies it like a pilot seat but never makes a pod; every canopy of a helm ship is
glazed as one band of tall glass. Draw it like this (the bridge fixture,
`test/fixtures/bridge/bridge.plan`):

```
deck y=0    x: -3 .. 3
z -5  W3   C    C    C    C    C    W1     # the glass across the bow
z -4  C8   Cs   D    Hm   D    Cs   C12    # the front row; side glass C8 / C12
z -3  C8   D    D    D    D    D    C12    # an open row to walk along
z -2  H    D    D    Cc   D    D    H      # the captain's chair, ramp behind
z -1  H    Qk12 D    D    Qm   Qk8  H
```

- **The glass:** a row of canopy across the bow, wrapping a cell or two down each side, `C8` to
  port and `C12` to starboard (their slopes face out; `WINDOW_UNMATCHED` catches a wrong one). A
  wedge at each empty bow corner gives the bow sections something to lose (`NO_PIECES`).
- **The front row**, behind the glass: the `helm` at its centre, `crew_station`s (`Cs`) either
  side, all facing forward.
- **An open row** behind it: routes never cross a fixture.
- **The `captain_chair`** (`Cc`) on the centreline behind that, facing forward, with open floor
  behind its ramp (`DAIS_BLOCKED`) and round it.
- At least 5 wide and 3 deep, on the one walkable storey.
- Rules it must pass: `NO_HELM`, `TWO_HELMS` (one flying seat), `NO_STAND` (every seat),
  `SEAT_FACES_WALL`, `DAIS_BLOCKED`, `UNREACHABLE`.
- The posts between panes sit at cell edges: the helm, centred on its cell, sees one 40° to each
  side. An odd-width bridge with the helm on the centre cell keeps the middle of its view clear.

## 5. Budgets

- **Power:** only `quantum_core` makes power, **36 MW** each, with 10% to spare (`POWER_MARGIN`).
  Draws: thruster 3, core 2, grav plating 1.5, rcs 1, airlock 0.6, pilot seat 0.5, quantum machine
  0.5, door 0.3, computer 0.3, **every walkable or room cell 0.1**. Hull, fairings, cells and
  armour draw nothing. **The starter already draws 31.3 of its core's 36 MW** (its five thrusters,
  eight rcs and two grav plates are most of it), so one core leaves room for about a dozen more
  cabin cells and nothing else: **most new ships need a second quantum core.** Put it on the
  walkable storey beside the corridor, never in it (a quiet fixture). Face its gauge into the room:
  `Qk4` (aft) behind a helm as on the starter, but in a corner beside a room turn it inboard
  (`Qk12` on the port side, `Qk8` on starboard). The quantum plant runs any number.
- **Mass** (t): quantum core and cell 5, core 4, armour 3, thruster 2.5, grav plating 1.5, airlock
  1.2, hull and rcs 1, bulkhead 0.8, door and wedge 0.6, canopy and seat 0.5, deck and rooms 0.4,
  fairings 0.3.
- **Size:** 400 blocks at most. A 400-block ship builds in about 1.2 s when it spawns, a freeze the
  owner accepted for now; its rules take 0.3 s; it holds 121 fps in the worst view, just over the
  120 floor, so **a big ship costs frames**: keep it no bigger than the brief needs.

## 6. Worked example: the starter

`to-plan starter` prints it:

```
ship   starter
name   Starter shuttle
desc   Two decks: a bridge with a cockpit pod, five rooms, an airlock aft.

deck y=2    x: -1 .. 1
z -2  Fk  Fk  Fk
z -1  Fh  Fh  Fh
z 0   Fh  Fh  Fh
z 1   Fh  Fh  Fh
z 2   Fh  Fh  Fh
z 3   Fk4 Fk4 Fk4

deck y=1    x: -3 .. 3
z -4  .  Rv R> W  R< Rv .
z -3  .  R^ W  H  W  R^ .
z -2  .  Rb H  H  H  Rb .
z -1  .  H  H  K  H  H  .
z 0   .  H  Qc Qc Qc H  .
z 1   Fs H  G  H  G  H  Fs
z 2   .  H  H  H  H  H  .
z 3   .  W4 T  T  T  W4 .

deck y=0    x: -3 .. 3
z -4  .   .   C   C   C   .   .
z -3  .   W3  Cp4 S   D   W1  .
z -2  .   H   D   Qk4 D   H   .
z -1  .   H   D   D   Qm  H   .
z 0   .   H   Bk  D   Gy  H   .
z 1   H   H   Bk  D   Wr  H   H
z 2   H   H   Ba  D   Cl  H   H
z 3   T   H   B   A   B   H   T

deck y=-1    x: 0 .. 0
z -3  Fh2
z -2  Fh2
z -1  Fh2
z 0   Fh2
z 1   Fh2
z 2   Fh2
```

- **y = 0, the cabin.** The canopy row (z −4) ahead of the helm `S`; the bridge computer `Cp4` to
  port facing aft; the quantum core `Qk4` straight behind the helm, so you stand up to its
  starboard side; the machine `Qm`; the corridor down x = 0 with a bunk room (two cells), bathroom,
  galley, weapon room and closet beside it; the airlock `A` at the stern between bulkheads; engine
  pods at x = ±3 with a thruster each.
- **y = 1, equipment and roof.** The core `K`, three quantum cells, grav plating, a roof thruster
  bank at the stern, the rcs at the bow.
- **y = 2 and y = −1:** a fairing spine above and a keel below.

`data/ships/starter.md` says why each block is where it is: read it before your first design.

## Mistakes already made (don't repeat)

| Mistake | What happened | Do instead |
|---|---|---|
| One quantum core for a big ship | A 600-block draft drew 92.8 MW against 36 made | Count power while drawing the cabin; a second `Qk` beside the corridor; grav plating sparingly (1.5 MW each) |
| 600 blocks | The first limit; probed, its worst view fell to 116 fps (109 with a second ship), under the 120 floor | The limit is 400, which holds 121; size costs frames |
| RCS only at the bow of a long ship | The 43-row draft turned 0.06 / 0.03 / 0.42 rad/s² | Rcs pairs at both ends; the lever arm is free authority |
| Probing in a fresh worktree | Every class "not declared", no output at all | `godot --headless --path . --import` once first |
| `ship_check` after a failed `to-json` | The Lamplighter's plan had `Fs12.` (no space): `to-json` refused it, the old file stayed, and `ship_check` passed the stale ship | A round stops when `to-json` exits non-zero |
| `Fs1` / `Fs3` for a flank chamfer | A sawtooth: every block still rose aft | `Fs8` / `Fs12` on a roof edge, `Fs10` / `Fs14` on a belly edge |
| Rcs as pods on the hull | The Warden's first draft read as clutter at the bow | Rcs as outer hull cells, exhaust face open |
| A quantum core off the centreline | 3% yaw imbalance on a 260 t ship | Centre it, or mirror two |
| Judging shape from `ship_check` alone | A first draft broke no rule and looked like a shuttle on a pole | Probe inside the design loop; the `.md` last |
| The arrival render to judge looks | At 200–400 m the new ship is a few pixels | It proves the arrival; judge the ship from the probe's hull views |
