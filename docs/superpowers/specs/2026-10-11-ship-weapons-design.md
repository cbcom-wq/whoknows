# Ship weapons — QE-powered phaser turrets

**Date:** 2026-10-11
**Status:** Designed with the owner on 2026-10-10 to 11; not yet built.
**Depends on:** `main` at `93543b3` (the bridge, the hose and habitat modules merged)
**Amends:** the quantum energy spec (`2026-09-24-quantum-energy-design.md`) §8.4, *Turret weapons*,
built here; the ship damage sections spec (`2026-10-03-ship-damage-sections-design.md`) §2.2, one
component per turret; the bridge spec
(`2026-10-09-ship-bridge-design.md`) §3.3, the first `SeatJob`; the health and damage spec
(`2026-09-29-health-and-damage-design.md`) §5.1, the pistol's bolt shares a base with the
turrets'; the slice-1 spec's roadmap, Slice 2 *First Blood* split again (§2).
**Governed by:** `docs/design/visual-style.md` (binding: palettes, the three-shader interior budget,
renders at eye height), `CLAUDE.md` (floating origin; every ship is usable; every ship lives in
`data/ships/`; keep `building-a-ship` and `building-an-npc` current)

---

## 1. Why

The owner (2026-10-10): *"My vision is the ship would have multiple QE powered phaser weapons
attached to it, the guns work mostly autonomously. The player can define targets but the guns
themselves fire and rotate on their own. I don't want to turn it into the player just points and
shoots everything, the idea is to be more realistic and strategic."*

On the shots themselves: *"Standard phaser turrets fire kind of rapid succession bolt shots to
maximize chances of hitting, they move fast and leave temporary light trails behind them, but at
long ranges these can be dodged as they are not instantaneous. This is the strategy of the game
and good piloting. Align your ship to get your weapons in the best position to hit and also be
able to dodge incoming fire. It's a bit of a dance."*

Nothing in the game shoots from a ship today. The pieces it needs are there: `Hit` and
`receive_hit` already carry damage to hull sections, components, NPCs and you; the pistol's bolt
already flies outside without tunnelling; the QE store already pays for extras and has a
low-power line; the bridge left an empty `SeatJob` slot "for weapon controls".

**Success:** the Warden, its targets marked and its orders at `ENGAGE`, swings its six light
turrets onto a spawned starter and hammers it with bursts of amber bolts that leave short trails;
the starter, jinking sideways at a kilometre, slips most of them, and at 400 m cannot. From the
Warden's weapons station you look down the heavy turret's barrel and land a 120 hp bolt at 2 km.
The QE readout falls while the guns fire, and in low power they go quiet. A crate breaks; a base's
drill, wrecked, stops. The game holds 120 fps through all of it.

## 2. Decisions

| # | Decision | Why |
|---|---|---|
| 1 | **Weapons only in this project** | The owner's choice. Shields and a hostile ship that fires back come next, on the same fire control. Slice 2 *First Blood* becomes three: Damage (built), Weapons (this), then Shields and the enemy |
| 2 | **Bolts, not beams** | The owner's words above: elongated, fast, in bursts, with light trails, dodgeable at range. Turrets must lead and can miss |
| 3 | **A priority list of three, then the nearest hostile** | The owner's choice (B of three). Each turret takes the highest entry it can bear on, so port and starboard batteries can work different targets |
| 4 | **An engagement range past which turrets hold fire** | The owner: past it the bolts "dissipate before they reach" or are "easily dodged"; firing would only waste QE |
| 5 | **A heavy turret that also fires on its own, aimed by hand from a weapons station** | The owner's choice (A of three). Not every ship has one, so not every ship has a gun you can aim |
| 6 | **While you sit at the station, nobody flies** | You are alone aboard: the assist holds the ship. Man the big gun, or fly and dodge |
| 7 | **Fighters: noted, not built** | The owner: "Let's just note the fighter for now but not care too much about implementing until we have an actual fighter ship" (§11) |
| 8 | **Loose items and habitat bases take damage; asteroids do not, yet** | The owner's choice |
| 9 | **A wrecked base module stops working** | The owner's choice: attacking a base means something |
| 10 | **Loadouts:** starter 2 light, Lamplighter 1 light, Warden 6 light + 1 heavy + the weapons station | The owner: the Warden gets six "so it really packs a punch" |
| 11 | **One `FireControl` per ship; turrets are blocks** | The owner's choice (approach 1 of three). Approach 2, turrets choosing alone, scattered "can I bear?" and *HOLD* across every turret and left an enemy AI nothing to drive; approach 3, turrets as NPC gunners, was heavy and the wrong idea |

## 3. The blocks

### 3.1 Two turrets

Both are SYSTEMS blocks, one 2 m cell, `occupancy` SOLID: a cell of the hull's surface (it takes the
place of a plate or a fairing), with the turret standing on its open face.

| | `turret_light` (*Light Turret*) | `turret_heavy` (*Heavy Turret*) |
|---|---|---|
| Look | a squat armoured dome, twin short barrels | a bigger dome, one long barrel overhanging its cell |
| Mass, hp | 0.8 t, 200 | 2.0 t, 400 |
| Power draw | 0.1 MW | 0.3 MW |
| Slew | 90°/s | 30°/s |
| Fire | bursts of 4 at 8 a second, then 1.5 s recharge | one bolt, then 3 s recharge |
| Bolt speed | 600 m/s | 450 m/s |
| Bolt damage | 15 hp | 120 hp |
| Bolt life | 3 s (1.8 km) | 7 s (3.15 km) |
| Engagement range | 1.2 km | 1.5 km alone; 3 km manned |
| Spread | 0.4° per bolt | none |
| QE | 1 per bolt | 15 per bolt |

The numbers are starting points; the combat probe (§10.2) tunes them and the as-built notes record
what they became. They live in one place, `WeaponValues` (as `QuantumValues`, `HabitatValues`).

Plan tokens: `Tl`, `Th`. Both drawn from `HullPalette` only, by `TurretLook` from a kit and a frame
(a reusable asset: it never sees the grid).

The power draws are small on purpose (amended 2026-10-11, while planning): every shot is paid in QE,
and at 0.5 MW a light turret the Warden (108 MW made, 97 drawn) would break `POWER_MARGIN`.

### 3.2 Mounting and the arc

A turret's orientation names its **mount face** (the block's up): dorsal, ventral, port, starboard,
or fore. The face must open onto an empty cell (`TURRET_BURIED`, §8). The turret aims over the
**half-sky** above that face: up to 90° from its normal.

### 3.3 The sky map

`SkyMap` marches each direction of a **32 × 16 grid** of the half-sky (yaw × elevation) from the
turret's muzzle through its ship's **launch layout**, every cell a cube, out to 40 m, and keeps one bit
per direction: clear or blocked. Pure, so `ShipRules` uses it too. It answers
`can_bear(dir_local) -> bool` by lookup, and `coverage() -> float`, the clear fraction. Made once per
turret when the ship is given its grid: a piece lost only opens the sky, so the launch layout is the
cautious answer, and the ray each shot casts (§5.3) catches the rest. A turret behind a fin sees
less; `TURRET_BLIND` warns under 25%.

### 3.4 Each turret a component

Every turret is its own component in the damage model, id `&"turret:<x>,<y>,<z>"`, label
*TURRET <n>* (numbered bow to stern, port to starboard), hp its block's:

- **damaged** (under 50%): slews at half rate, recharges twice as long;
- **wrecked** (0%): silent, parked where it was;
- mended **from outside** with the torch, like the engines; never knocked off.

### 3.5 The weapons station

`weapons_station` (*Weapons Station*), an INTERIOR MOUNT seat like `crew_station`: the same chair
and stand rules, a console with a gun-camera screen and a target board, drawn from
`InteriorPalette`. At most one per ship. Plan token `Ws`. Its seat's `job` is a `WeaponsJob` (§7).

## 4. Targets

### 4.1 What can be shot

A **target** is any node outside in group `Weapons.TARGETS` with:

- `target_id() -> StringName`, stable across saves and shifts: `&"ship:<name>"`, `&"base:<id>"`,
  `&"npc:<id>"`, `&"item:<id>"`;
- `target_point() -> Vector3` (engine space, now) and `target_velocity() -> Vector3`.

Ships, bases, NPCs outside, and loose items in space join it. Your own avatar does not.

### 4.2 Contacts

A new sensor source, `TargetContacts`, lists every other ship and base within **5 km** as an EXACT
contact, kinds `&"ship"` and `&"base"`. Creatures are already life signs (`LifeContacts`), and items
are not listed (the map would drown in crates); both can still be marked by looking at them (§9.1). Other ships become contacts on the HUD and the bridge
computer's map for the first time.

### 4.3 Hostile

`Weapons.is_hostile(target) -> bool` is the one answer. **It is false for everything in this
project.** The enemy project fills it; tests set a stub.

### 4.4 Your own

`Weapons.is_own(ship, target)`: the ship itself. Ships have no owner yet (every ship is yours to
board, `CLAUDE.md`), so a turret may fire on any other ship you mark; factions come with the enemy
project. Marking your own ship does nothing.

Ships, bases and NPCs keep their ids across a save (`ship:<name>`, `base:<id>`, `npc:<record id>`);
an item's is good for the session only (`item:<instance id>`), so a listed item is dropped on load
(§5.1).

## 5. Fire control

### 5.1 `FireControl`

One node per ship, a sibling of `FlightComputer`, built by the ship with its turrets. It holds:

- **orders:** `HOLD` or `ENGAGE`. A new ship starts in `HOLD`;
- **the list:** up to three target ids, in priority order. Marking a fourth drops the last;
  marking one already listed moves it to the top.

Every **0.2 s** it gives each turret a target: the first list entry that

1. resolves to a target out there (not gone, not asleep),
2. is not your own (§4.4),
3. is within the turret's engagement range, and
4. lies in the clear part of its sky map along the aim solution (§5.2);

failing every entry, the **nearest hostile** that passes 1–4; failing that, none, and the turret
parks facing along its mount's forward.

In `HOLD`, no turret is given anything, and a manned heavy turret still fires (§7.2).

An entry whose target is **gone** (an NPC dead, an item destroyed, a ship removed or gone to sleep
past 20 km) for **2 s** running leaves the list; the grace lets a loaded game's ships, bases and NPCs
wake before their entries are judged. A wrecked ship stays until you clear it.

### 5.2 The aim solution

`WeaponAim.intercept(shooter_pos, shooter_vel, bolt_speed, target_pos, target_vel) -> Variant`:
the direction to fire, or null when the bolt can never catch it. Bolts carry the shooter's
velocity, so the solve is in the shooter's frame; the target is assumed to hold its velocity.
Changing velocity is how you dodge.

### 5.3 The turret's loop

Each physics tick, `Turret`:

1. reads its target's position and velocity and solves (§5.2);
2. slews its yaw and pitch toward the solution at its rate, clamped to the half-sky;
3. fires when **all** hold: the barrel within 1° of the solution; the time to impact times the bolt
   speed is inside its engagement range; its recharge is done; the store is at or above the
   low-power line and can pay; a ray from the muzzle along the shot is clear of its own hull (the
   sky map is coarse);
4. a light turret's burst fires its four bolts 0.125 s apart, each re-aimed and spread by up to
   0.4°; a burst stops early if its target leaves the arc.

### 5.4 QE

Each bolt is a `spend(n, &"weapons")` at the moment it leaves: 1 for a light, 15 for a heavy. A
spend that fails stops the burst. **No bolt fires below the low-power line** (as boost, QE spec
§8.2). Two light turrets firing without pause spend about 4 QE/s: the starter's 1,200 lasts four to
five minutes of it.

### 5.5 The floating origin

Turrets read positions only when they fire. The list holds ids, never positions, so a shift
changes nothing in fire control. Bolts and trails join `Universe.EXTERIOR_SPACE` (§6.3).

## 6. Bolts

### 6.1 One base, two bolts

`Bolt` (new, `src/combat/bolt.gd`) is what `PlasmaBolt` does today, lifted out: each tick a ray
from where it is to where it will be (no tunnelling at any speed), `impact()` delivering a `Hit`,
the flash, the stimulus to NPCs, the `outside` handling. `PlasmaBolt` extends it and keeps its
numbers, look and behaviour exactly. `PhaserBolt` extends it with the turrets' numbers and look,
`kind = &"phaser"`. A ship's bolts exclude that ship's own exterior and interior colliders.

`PhaserBolt`s carry their shooter's velocity: position advances by `(velocity + direction × speed)
× delta`.

### 6.2 The look

- an elongated glowing capsule along its path: 2 m × 0.25 m (light), 4 m × 0.5 m (heavy);
- colour **`SpacePalette.PHASER`**, a hot amber-gold, new; the owner sees it in the first renders
  before anything else builds on it. Not blue (the style guide §7);
- a **light trail**: bolts fly straight, so the trail is one thin glowing streak from where the bolt
  was 0.4 s ago (or its muzzle) to its head, tapering; when the bolt lands or fades the streak's
  tail runs up to where it ended over 0.4 s. It fades by scale, never by touching the shared glow
  material (as `ImpactFlash`);
- only the **heavy** bolt carries an `OmniLight3D` (warm, range 30 m); light bolts glow only. A
  hundred and fifty lights in flight would break the frame budget;
- at impact the existing `ImpactFlash`, scaled up for the heavy bolt.

### 6.3 Budget

The Warden at full fire keeps about 150 bolts in the air: 150 rays per physics tick. Bolts and
trails are **pooled** by a `BoltPool` under the outside world, never freed and made per shot. Each
pooled bolt and trail is in `Universe.EXTERIOR_SPACE` while live. The combat probe (§10.2) must
hold **120 fps** on the dev machine with the Warden's guns all firing.

### 6.4 What a bolt does

| It hits | What happens |
|---|---|
| A ship's hull | `Ship._on_hull_hit`, as now: a section, or a component, now including a turret. A small push (light 20 N·s, heavy 400 N·s) |
| An NPC or creature | its `receive_hit`, as now |
| You on a spacewalk | 15 hp from a light bolt, 120 from a heavy: a heavy bolt downs you |
| A loose item | §6.6 |
| A base | §6.5 |
| An asteroid | a flash and the stimulus, as the pistol's: no damage |

### 6.5 Bases

A base wears its own shell over its blocks (`BaseExterior`), and its modules are prefabs that never
lose pieces, so it does not borrow the ship's sections (amended 2026-10-11, while planning: the
spec first moved `ShipDamage` into `GridHome`). Instead **each module is a section** of its own,
kept on `Base` by a small pure `ModuleDamage`: id `&"module:<index>"`, label the module's name
(*DRILL 2*), hp the sum of its blocks'. A hit on the base's exterior finds its cell, then its module.
Damage shows as a tint on that module's shell (`ExteriorBuilder.stage_colour`: scorched, then
charred) and sparks from its damaged blocks (`DamageShow`); nothing breaks off. A **wrecked** module
stops working until it is mended above wrecked:

- **hub:** its machine is unbound (dark, refuses) and its link panel reads *HUB WRECKED*;
- **drill:** it stops drilling and humming;
- **store:** its tanks drop out of the base's capacity; QE above what is left is lost.

Mended from outside with the torch, at a ship section's rate (`RepairTorch` learns the base, as it
knows a ship). Saved in the `BaseSite`, per module.

### 6.6 Items

`ItemDefinition` gains `hp` (default 40) and `unbreakable` (default false). The pistol, the torch
and the datapad are unbreakable. `Item.receive_hit` takes damage on any hit, inside or out: a crate
takes three light bolts or four pistol bolts. At 0 the item bursts (a small spray of debris in
`HullPalette` tones, outside in `HOLDS_SHIFT`) and is freed. A salvage item is struck off the
`SalvageLedger`: its QE is lost. An item's damage is saved with it.

## 7. The weapons station

### 7.1 `WeaponsJob`

The `SeatJob` of a `weapons_station`. `sat()` takes the screens and input; `stood()` hands them
back. While someone sits, **the ship is held**: `FlightComputer.gunner_hold` centres the stick and
the translation keys, and, with the assist on, locks the forward speed it has, so it keeps its course
while drift and spin are damped. With the assist off it simply coasts. The other turrets go on firing
on their own.

### 7.2 With a heavy turret

- **The camera** moves to the heavy turret's gun camera: outside, beside the barrel, rendering the
  outside world (the layers a spacewalk sees).
- **The mouse aims** a reticle within the turret's half-sky; the barrel follows at its own 30°/s,
  and a second mark shows where it actually points.
- **Left mouse** fires when the turret has recharged and the store can pay, `HOLD` or not.
- **The wheel** zooms 1×, 2×, 4×.
- **Range:** you may fire at anything out to 3 km.
- **A lead marker** for the list's first target: where to put the reticle to meet it (§5.2).
- **T** marks the target nearest the reticle; **Tab** cycles the list's order; **Q** / **E**
  switch heavy turrets when a ship has more than one; **F** stands you up, and the heavy turret
  fires on its own again.

### 7.3 Without one

The station's screen shows the target board (§7.4); T, Tab and F work. No gun camera.

### 7.4 The target board

On the station's screen and as a new **WEAPONS** page of the bridge computer: the orders, the list
(each entry with its label, distance, and whether any turret can bear), and each turret's state:
*TRACKING*, *FIRING*, *NO ARC*, *DAMAGED*, *WRECKED*, *LOW POWER*, *IDLE*. The page's buttons: prev
and next pick an entry, RANGE drops it, the big button switches the orders. Marking is done where you
can see: at the helm and in the gun camera (T).

## 8. Rules

`ShipRules` gains:

| Rule | Severity | When |
|---|---|---|
| `TURRET_BURIED` | error | a turret's mount face does not open onto an empty cell |
| `TURRET_BLIND` | warning | a turret's sky map is under 25% clear |
| `TWO_WEAPONS_STATIONS` | error | more than one `weapons_station` |

The weapons station passes every seat rule (`NO_STAND`, `SEAT_FACES_WALL`, reachable). A heavy
turret with no station is allowed: it fires on its own. A station with no heavy turret is allowed:
it is a target board.

## 9. The helm, the HUD and sound

### 9.1 At the helm

New input actions, all free keys today:

| Action | Key | Does |
|---|---|---|
| `weapons_mark` | T | marks the target nearest the crosshair within 10° and 5 km (items included); already listed, it moves to #1 |
| `weapons_clear` | Shift+T | clears the list |
| `weapons_orders` | B | `HOLD` ⇄ `ENGAGE` |

### 9.2 The HUD

In the flight HUD's existing look, palette colours only:

- a **bracket** on each listed target, numbered 1–3, with its distance; dashed while no turret can
  bear, solid when one can; a hostile tint, unused until the enemy project;
- a **weapons strip** under the QE readout: `HOLD` / `ENGAGE` and a pip per turret (lit, firing,
  no arc, damaged, wrecked, low power);
- *WEAPONS · LOW POWER* in `WARNING` while the store is below the line and the orders are
  `ENGAGE`.

### 9.3 Sound

Synthesised with `Synth`, through the `SHIP` or `SUIT` bus as every ship sound is:

- a light turret's punchy *thrum* per bolt, heard inside as a thud through the hull;
- the heavy's deep *whump*, and a rising whine as it recharges (loudest at the station);
- an impact *crack* outside within 200 m; a hit on your own hull, a bang through it.

## 10. Testing

### 10.1 Automated (GUT, headless; run only the files that cover each change)

- `WeaponAim.intercept`: a still target, a crossing target, a target faster than the bolt and
  receding (null), shooter velocity carried;
- the sky map: a turret on a flat deck sees about 100%; one behind a wall cell sees under half;
  `coverage()`;
- `FireControl`: priority order; range; arcs; port and starboard on different entries; own ships
  never; the nearest hostile after the list (stub hostile); `HOLD` gives nothing; gone entries
  leave; a fourth mark drops the last;
- `Turret`: fires only within 1°; the burst; the recharge; damaged halves the slew; wrecked is
  silent;
- QE: each bolt spends; a failed spend stops the burst; nothing fires below the line;
- `Bolt`: `PlasmaBolt`'s existing tests pass unchanged; a `PhaserBolt` carries its shooter's
  velocity and never hits its own ship;
- hits: a ship section; a turret component; an item to 0 (freed, struck off the ledger); an
  unbreakable item untouched; a base module to wrecked (a drill stops, a store refuses) and back;
- the rules: `TURRET_BURIED`, `TURRET_BLIND`, `TWO_WEAPONS_STATIONS`; `test_ship_catalog.gd`
  passes all three library ships with their weapons;
- saving: orders and list round-trip; turret components; a base module's damage; an item's damage;
  a listed id that no longer exists is dropped on load;
- the floating origin: `test_floating_origin_scene.gd` covers bolts, trails and pooled bolts;
- the visual style: `TurretLook`, `PhaserBolt` and `Turret` are in `test_visual_style_rules.gd`'s
  painting files, and `TurretLook` in its reusable ones.

### 10.2 In the real scene (mandatory, renders shown to the owner)

- **`test/probes/combat_probe.gd`** (new): the Warden in `ENGAGE`, a spawned starter listed first,
  jinking sideways at 5 m/s² (a new direction every 1–2 s). It reports the **hit rate by range**
  (200 m steps to 1.4 km) and the **frame rate** with every gun firing. Pass: at least 80% at
  400 m, at most 30% at 1.2 km, at least 120 fps. Then the heavy turret, manned by the probe, at
  2 km on a target holding its course.
- **Renders** at eye height (1.6 m): bursts and trails seen from the Warden's bridge; from outside
  the hull; through the gun camera; the starter's turrets; a wrecked base drill. The owner judges
  the look, the colour first.
- **`fleet_play.gd`** re-run (seats and ships change).
- **`ship_probe.gd`** on all three library ships: each turret's sky coverage.

## 11. Fighters (noted, not built)

A fighter is a small ship whose only weapons are **fixed guns**: a `gun_fixed` block facing the way
it is mounted, fired by the helm's trigger (left mouse at the helm) at the crosshair, from the same
`Bolt` and QE path. No `FireControl` targets are needed, though marking still works for brackets.
Whether the pilot gets a lead marker, a plain crosshair or a small gimbal is decided when there is a
fighter ship to fly. Nothing here is built.

## 12. Files

New:
- `src/combat/bolt.gd`, `phaser_bolt.gd`, `bolt_pool.gd`, `bolt_trail.gd`
- `src/combat/weapons.gd` (the group, `is_hostile`, `is_own`), `weapon_values.gd`, `weapon_aim.gd`
- `src/combat/fire_control.gd`, `turret.gd`, `sky_map.gd`
- `src/combat/weapons_job.gd`, `gun_camera.gd`
- `src/sensors/target_contacts.gd`
- `src/ui/weapons_strip.gd`, `target_brackets.gd`; `src/ship/computer/weapons_page.gd`
- `data/blocks/turret_light.tres`, `turret_heavy.tres`, `weapons_station.tres` and their meshes
- `test/probes/combat_probe.gd`; tests under `test/unit/`

Changed:
- `src/items/plasma_bolt.gd` (extends `Bolt`), `item.gd`, `item_definition.gd`
- `ship.gd` (turrets, fire control, saving), `ship_damage.gd` (turret components), `ship_rules.gd`,
  `ship_plan.gd` (tokens)
- `src/habitat/base.gd`, `base_site.gd`, `base_exterior.gd`, `link_panel.gd`; `src/items/repair_torch.gd`
- `src/npc/npc_director.gd` (exterior NPCs are targets)
- `src/flight/flight_computer.gd` (held while a gunner sits), the flight HUD
- `src/world/space_palette.gd` (`PHASER`)
- `data/ships/starter.*`, `lamplighter.*`, `warden.*`
- `project.godot` (the three actions)
- `.claude/skills/building-a-ship/` (checklist, *Mistakes already made*, `reference.md`,
  `ship_probe.gd`), `designing-a-ship` (loadouts by role), `building-an-npc` (phaser hits)

## 13. Build order

Each phase is playable at its end.

1. **Bolts, targets, fire control, the light turret.** `Bolt` and `PhaserBolt`, the pool and
   trails, `Weapons`, `TargetContacts`, `FireControl`, `Turret`, the sky map, the turret component,
   the helm keys, the HUD brackets and strip, the sounds; the starter armed. You can mark an F6 ship
   and shoot it.
2. **Items and bases.** Item hp; `ModuleDamage` on bases; wrecked modules stop; the torch mends
   them.
3. **The heavy turret and the weapons station.** `WeaponsJob`, the gun camera, the held ship, the
   target board and the WEAPONS page; the Warden (six light, one heavy, the station) and the
   Lamplighter armed; the rules.
4. **Proof and upkeep.** The combat probe and its tuning, the renders, the skills, the as-built
   notes in this spec.

## 14. Not in this project

Shields; hostile ships or any AI that sets targets; damage to asteroids; fixed guns (§11);
missiles and ammunition; friendly fire policy beyond your own ships; boarding; NPC crew at the
weapons station.

## 15. Risks

- **Turrets that never hit, or never miss.** The whole design rests on the dodge window. The probe
  measures it in phase 4 and the numbers in `WeaponValues` move until the owner's dance is there.
- **Frame budget.** 150 rays a tick and 150 trails. Pooling, no lights on light bolts, and the
  probe's 120 fps floor; if it fails, trails become one `MultiMesh` first.
- **A turret replaces a plate.** Each loadout swaps a fairing or plate for a turret cell; the probe's
  renders show whether the hull still reads right, and `ShipRules` (`NO_PIECES`, `UNBALANCED`) still
  passes.
- **The gun camera and render layers.** The camera sits outside a ship whose interior lives in a
  slot; it must see the world, the hull and bolts, not the interior. The bridge's seated cameras
  and the spacewalk's layers are the models.
