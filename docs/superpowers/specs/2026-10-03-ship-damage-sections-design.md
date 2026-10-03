# Ship damage by sections and components — design

**Status:** approved and built, 2026-10-03 (as-built notes in §11). Amends `2026-09-29-health-and-damage-design.md` §4, §5.1,
§8 and §9 for ships; your own health, NPCs, the pistol, the torch as an item and scrap plates
are unchanged.

## 1. Why

The owner (2026-10-03): *"repairing the ship is a little too tedious."* Every one of a ship's
110 blocks takes its own damage and is welded on its own, from inside or out. Instead:

- the **hull** is **six large sections**, mended **from outside** only;
- four **components** take damage of their own: the **engines**, the **quantum core**, the
  **bridge computer** and the **cockpit**;
- the **cabin's look** (scorch, char, sparks, flickering lights) follows **how damaged the hull
  is overall**, not the block behind each wall.

The owner's answers, 2026-10-03:

| Question | Answer |
|---|---|
| How the hull is split | six sections: bow, middle, stern × port, starboard |
| What the hull costs you | only looks and pieces breaking off; only components change how the ship works |
| The pistol fired inside | it hurts the hull (a little), or the component it hits |
| How the cabin shows it | graded by HULL %, the whole cabin together |
| The cockpit | damaged: cracked canopy, sluggish assist; wrecked: assist off, HUD flickers, still flyable |
| The computer | damaged: glitching screens, a warp spools longer; wrecked: dark, no map, no warp |

## 2. What takes damage

### 2.1 Hull sections

Six sections, from the **launch layout** (`Ship.launch_blueprint`), so they never change as
pieces come and go:

- **along the length:** the layout's z span cut into thirds, the bow third getting the extra row
  when it does not divide (the starter's 8 rows: bow 3, middle 2, stern 3);
- **across:** port (x < 0) and starboard (x > 0). A block on the centre line (x = 0) belongs to
  **both** sides of its third: a hit on it goes to the side the hit landed on (the contact point's
  x), half to each when exactly central, and it shows the worse of the two.

Ids and labels: `&"port_bow"` *PORT BOW*, `&"starboard_bow"`, `&"port_mid"` *PORT MIDSHIP*,
`&"starboard_mid"`, `&"port_stern"`, `&"starboard_stern"`.

Every block that is not part of a component is a **hull block** and belongs to its sections,
whatever it is (hull, fairings, decks, rooms, RCS, cells, the core block). A section's **hp** is
the sum of its blocks' `hp` (a centre-line block counts half on each side). On the starter that is
1,430–2,760 per section (§11).

**Health** is `1 − damage / hp`, from 1 (whole) to 0. **HULL %** is the hp-weighted mean of
the six, as the HUD band already shows (`Ship.hull_whole()`, now from the sections).

### 2.2 Components

| Component | Blocks | Where it is mended | Damaged (under 50%) | Wrecked (0%) |
|---|---|---|---|---|
| **Engines** | every `thruster`, as one | outside: aim at any thruster | half forward thrust | no forward thrust: crippled |
| **Quantum core** | the `quantum_core` | inside, at the core | half power | no power: crippled (as now) |
| **Bridge computer** | the `computer` | inside, at the table | screens glitch; a warp spools 20 s, not 10 | dark: no map, no warp |
| **Cockpit** | the `pilot_seat` and every `canopy` | inside, at the helm | cracks on the canopy; the assist chases its rate at half strength | assist off and refused; the HUD flickers; still flyable |

A component's hp is the sum of its blocks' (engines 750, core 250, computer 60, cockpit 240 on the
starter). The computer's and cockpit's hp are raised to **300** each, or one stray bolt would wreck
them. Component blocks are **never knocked off**. A ship without a component (no computer) simply
has none to damage.

### 2.3 What no longer takes damage of its own

RCS, quantum cells, decks, rooms and walls: they are hull blocks. Their **function never
degrades** (hull damage is only looks and pieces), so steering, the store's capacity and the
rooms always work. The store's "cells damaged" path stays in the code but no longer happens.

## 3. Hits

`Ship.take_damage_many(hits)` (crashes, the bolt, creatures) routes each hit:

- on a **component's block**: to that component;
- on any other block: to its **section** (the centre-line rule above);
- on an **interior face** (a bolt fired inside): the block behind it, as now, then the same
  routing. A wall's bolt (10) is 0.4–0.5% of a section.

Crash damage is unchanged in size (`CRASH_K` 12 × (knock − 2)², half to the neighbours), now
summed into the sections and components it lands on. The crash probe is re-measured; if 8 m/s
takes a section below half, `CRASH_K` is tuned so it takes about a third.

## 4. How the hull shows its damage

Sections are the truth; each block's `damage` in the grid becomes **a view of its section**,
recomputed whenever a section changes. That keeps the skin tint, the hull's sparks, the burst
and chunks for a lost piece, the scrap plate shed and the torch's rebuild all working as built.

- **Scorch and char, unevenly.** Each hull block gets a fixed **exposure** in 0..1 from its
  launch layout (the more open faces onto space, the higher, a seeded jitter breaking ties). A
  block's shown damage is the section's damage share pushed up for exposed blocks and down for
  sheltered ones, so a section darkens from its edges in.
- **Pieces breaking off.** Only **structural buffer** breaks away: `hull`, `hull_wedge`,
  `armour` and the fairings, outside the cabin's shell (`Ship.inner_cells`), never a block whose
  loss would cut off anything else. Below **50%** a section loses them most exposed first, all of
  them at **0%**. As it is welded back up they **come back**, wrecked-looking, in reverse order,
  and are scorched or clean as the section's health says.
- **Components** show their own stage on their own blocks, as now.

## 5. How the cabin shows it

From **HULL %**, the whole cabin together (the owner's choice):

| HULL % | Walls, floors, ceilings | Sparks inside | Ceiling lights |
|---|---|---|---|
| over 50% | as built | none | steady |
| 50% to 20% | lean toward `SCORCH` | 3 spits round the cabin | steady |
| under 20% | lean toward `CHAR` | 8 spits | **flicker** (`LightFlicker`) |

The interior is rebuilt once when HULL % crosses 50% or 20% either way (`_queue_rebuild`).
Components inside (the core, the computer, the helm) show their own stage on top. The cabin never
changes shape: no interior block is ever removed.

## 6. Repair

The torch (`RepairTorch`) keeps its hopper, plates, prompts and rates:

- **A hull section, from outside only.** Aim at any of its blocks or holes from a spacewalk and
  hold: it mends **4% of the section a second** for **1 scrap per 1%**, so a section from 0 to
  whole is **25 s and 100 scrap**, one plate. Pieces come back as it rises. The prompt:
  *PORT BOW HULL · 45% H · SCRAP 300/300*.
- **From inside, the hull refuses:** aimed at a wall or floor the prompt reads *HULL 45% ·
  WELD FROM OUTSIDE*, and nothing happens.
- **A component, where it is:** as now, 25 hp a second, one scrap an hp: the core, the computer
  and the helm from inside; the engines from outside. The prompt: *ENGINES · 40% H · DAMAGED ·
  SCRAP 300/300*.
- The droid as now.

## 7. What you see of it

- **The HUD band:** HULL %, and the crippled reason as now.
- **The status page**, a new line: *HULL 64% · ENGINES DAMAGED* (the worst component's state, or
  *ALL SYSTEMS OK*).
- **The cockpit damaged:** a few flat crack lines over the canopy overlay (palette colours, no new
  shader). **Wrecked:** the HUD readouts flicker.
- **The computer damaged:** its screens jump between modes; **wrecked:** the holo and screens are
  dark and its buttons answer *OFFLINE*.

## 8. Saving

The save adds `"sections"` (id → damage) and `"components"` (id → damage). Per-block damage is
still written but is derived on load. **An older save** converts: each section's damage is the
sum of its blocks' saved damage (capped at its hp), each component's the sum of its blocks'; then
the grid is re-derived, which puts back any buffer piece the section's health says is there.

## 9. Testing and proof

- **Unit:** section assignment (thirds, the centre line, the starter's six hp totals); routing
  (component, section, centre-line split); the view (shown damage by exposure; pieces lost below
  50% and back in reverse); the cabin's thresholds; the torch's rates and refusals; the save and
  the old-save conversion; each component's effect (thrust, power, warp spool and refusal, assist
  strength and refusal).
- **Scene:** a crash takes pieces off the struck section only; welding it outside brings them back;
  the cabin flickers below 20% and steadies above; the helm, rooms and doors never move.
- **Probes:** `crash_probe.gd` re-measured and its numbers in the skill; `damage_review.gd`
  renders a section at 70%, 35% and 0% from outside and the cabin at 60%, 35% and 15% at eye
  height, shown to the owner before merging; `ship_probe.gd` prints the six sections' hp and the
  components.
- **The skill** (`building-a-ship`) is updated in the same branch: the checklist's damage step,
  the sections and components, the numbers.

## 10. Not in this

Damage to RCS, cells or rooms; per-section effects on flight; repairing a section from inside;
NPCs repairing; a ship-wide damage screen on the computer beyond the status line.

## 11. As built (2026-10-03)

- **The starter's sections** (ship probe): port/starboard bow 1,430/1,490 hp with 3 pieces each,
  midship 1,965/2,005 with 6, stern 2,760 with 12. Components: engines 750, core 250, computer
  300, cockpit 300.
- **Crashes** (crash probe): `CRASH_K` went from 12 to **5.5**, so 8 m/s nose on takes the
  struck bow section and the cockpit to 67%; 5 m/s to 92%; 3 m/s to 99%. No pieces off, never
  crippled.
- **The scorch in patches** (§4): a block shows its section's share × (0.6 + 1.8 × exposure),
  exposure being 70% open faces and 30% seeded chance. The first renders, at 1 + 1.8 ×
  exposure with almost no chance, darkened a whole side evenly at 70%.
- **The cabin's scorch** (§5): `InteriorKit.WEAR_MIX` for damaged went from 0.35 to **0.5**: at
  35% HULL the corridor read the same as at 60%.
- **The torch** mends a hole as part of its section; there is no separate rebuild any more
  (`REBUILD_COST`/`REBUILD_TIME` are gone). From inside, aimed at the hull, the prompt reads
  *HULL 45% · WELD FROM OUTSIDE*.
- **A wrecked cockpit** turns the assist off; mending it lets the assist be turned back on (it
  does not come back on by itself).
- **The damaged computer's spool sound** plays at half pitch, so it lasts the 20 s spool.
- **The canopy's cracks** are drawn on the HUD's screen (`CanopyCracks`, a `HudElement` that
  `HudRoot` adds), not the canopy overlay: the seated view looks through the pod's own glass, and
  the overlay is only seen on the cabin's windows, so the first render showed no cracks.
- **Saving** adds `"damage"` to the ship's part; a load infers the sections from the grid first,
  so an older save converts with no version change.
