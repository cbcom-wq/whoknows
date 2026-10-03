# Health and damage — things that can be hurt, broken and lost

**Date:** 2026-09-29
**Status:** Approved by the owner on 2026-09-29, after answering all eleven questions (§2), and
built on `claude/health-and-damage-design` from the plan
`docs/superpowers/plans/2026-09-29-health-and-damage.md`, and merged. §17 records where the
build differs.
**Depends on:** `main` at `dfd7b91`: the system skeleton, NPC foundation, saving, quantum energy,
asteroids, hands and items.
**Governed by:** `docs/design/visual-style.md` (damage looks come from the palettes, within the
shader budget) and CLAUDE.md's floating-origin rule (sparks and debris outside join
`Universe.HOLDS_SHIFT` or `Universe.EXTERIOR_SPACE`).
**Closes these hooks:**
- hands and items §9.3 (`receive_hit` and "Slice 2's damage reads this");
- saving §5 ("damage (future): anything took damage less than 5 s ago");
- NPC foundation §4.5 (`NpcDirector.amend`: "Slice 2's first death");
- piloting HUD §8 (hull health goes in the console band);
- the slice-1 spec §12 ("the block mutation API supports destruction from day one").

**Leaves open for later:** Planetfall's `hard_landing` (not built yet) and the star's heat (star
systems §13.2) plug into §5 when they exist.

**Amends, once approved:** the slice-1 roadmap. Slice 2 splits into *Damage* (this spec) and *First
Blood* (turrets, shields, an enemy), which builds on it. Both skills gain sections too (§12.3).

---

## 1. Why

Nothing in the game can be hurt. The plasma pistol shoves things, rocks thump the hull, and every
block has an hp number that nothing reads. The rest of Slice 2 (turrets, shields, an enemy ship
you can cripple) and all of Slice 3's boarding need one idea of damage underneath them.

This spec adds that idea on its own, before any new weapons. The ship's blocks, you, and the
creatures and droids can all take damage from what already exists: the pistol, crashes, and (new)
a creature that bites back.

---

## 2. Decisions taken

The owner, 2026-09-29:

| Question | Answer |
|---|---|
| What does the first damage slice cover? | **Damage on its own.** Blocks, you and NPCs take damage and break, from sources that exist. Turrets, shields and an enemy ship come after and build on it. |
| What happens when you run out of health? | **Downed, then rescued.** You black out and wake aboard, at a cost. No permadeath yet. |
| What does a block become at 0 hp? | **Stages, then gone.** Intact → damaged (works worse, looks it) → wrecked (stops working, still there) → removed only by further damage. |
| Which sources come first? | **The plasma pistol, crashes and creatures.** The environment (heat, vacuum, air) waits. |
| How is a damaged ship mended? | **A handheld repair tool** that you carry to the damage (§8). The quantum machine doing it for QE was the first recommendation. |
| Can your own pistol damage your own ship? | **Yes, inside and out.** |
| Which creature can hurt you? | **Skitters, when hurt or cornered** (§5.4). No new predator yet. |
| What does blacking out cost? | **50 QE from the ship's store, plus whatever you were holding** (§7.2). |
| Does a downed droid come back by itself? | **Yes, after 60 s,** or at once with the torch (§6). |
| Can you be hurt at the helm? | **No: the ship takes it** (§7.3). |
| What does the torch use up? | **Scrap plates,** fed into it (§8.1). Suit charge was the first recommendation. |

What follows from them:

- **The ship must be mendable.** With one save slot and no save-scumming, a ship that is only ever
  worn down is lost slowly for good. Repair is in this slice: the torch (§8).
- **Mending is something you do with your hands.** Hull damage is outside, so repairing it means a
  spacewalk with the torch. A crash costs time and scrap plates as well as hp.
- **Salvage gains a use.** Scrap plates have only been worth QE. Now they are what keeps the ship
  whole, so a salvage field is worth a detour after a bad crash.
- **"Crippled" becomes readable before there is anything to fight.** Crash into enough rocks and
  your ship limps. First Blood then only has to add the guns.
- **Nothing can strand you.** This matches the suit's emergency cell (quantum energy §9): being
  downed outside brings you home, just as a dry suit does.

---

## 3. The shape

One vocabulary and three receivers:

```
Hit (extended)              what lands: where, which way, impulse, + damage and kind
  │
  ├── ShipHull.receive_hit    exterior hull colliders → the struck cell  ─┐
  ├── ShipInterior hit        interior geometry → the cell behind the face ├─ BlockDamage
  │                                                                        │   (pure)
  ├── Avatar.receive_hit      → Health (you)                               │
  └── Npc.receive_hit         → Health (its record's)                      ┘
```

- **`Hit` gains two fields:** `damage: float` (hp) and `kind: StringName` (`&"plasma"`,
  `&"crash"`, `&"bite"`). `receive_hit(hit)` is still the only hook. Anything that doesn't care
  about damage keeps ignoring it.
- **`Health`** (new, pure `RefCounted`): `max`, `current`, `take(hit) -> float`, `heal(n)`,
  `since_hurt`, and `signal hurt(amount)` and `signal emptied`. You and every NPC hold one.
- **`BlockDamage`** (new, pure): turns a cell's damage (§4.2) and its `BlockDefinition` into a
  stage, and applies damage to a `ShipGrid`. It is the only code that writes a block's damage.
- **`DamageLog`** (new, pure): records when something last took damage, for the save gate and
  the HUD.

---

## 4. Blocks

### 4.1 Stages

A block's stage is read from the damage it has taken, against its definition's `hp`:

| Stage | Damage taken | Works | Looks (§9) |
|---|---|---|---|
| **Intact** | under 50% of `hp` | fully | as now |
| **Damaged** | 50% up to 100% | at **half** output: thrust, power, QE capacity, grav radius | scorched; sparks now and then |
| **Wrecked** | 100% up to 150% | **not at all**; keeps its mass and collision | charred; its ceiling light flickers (from under 20% health) |
| **Gone** | 150% or more | removed with `ShipGrid.clear_block` | a burst, and a hole |

The span from 100% to 150% is how much a wreck takes before it is knocked off. That way
"wrecked" lasts long enough to be seen and repaired.

**Quantum cells keep their energy** (amended 2026-10-03, the owner's call). A damaged or wrecked
cell lowers the store's capacity, so the store takes no more, but what it already holds stays, up
to what the cells hold intact (`QuantumStore.most`, from `ShipStats.intact_quantum_capacity`).
Spending it down below the damaged capacity, or mending the cells, lets it fill again. The status
page reads *QE 900 / 600 · CELLS DAMAGED*. Until then a hit on the cells lost the energy for good.

### 4.2 Store damage, not hp left

`BlockInstance.hp_current` is 0 on every block today, because nothing ever sets it from
`def.hp`. Every save and blueprint holds zeros. Read as hp left, that would make every ship a
wreck. And 0 can't simply mean "unset", because a just-wrecked block also sits at 0.

So the field becomes **`damage: int`, the hp lost**, where 0 means intact:

- A new block is intact without anyone setting it. `BlockInstance.new()` in
  `ShipBlueprint.to_grid` and in `flight_test.gd` needs no change.
- **Every existing save and blueprint already reads as undamaged.** The format version does not
  change. `ShipBlueprint`'s `hp_values` is renamed `damage_values`, and a dictionary holding the
  old key is read as zero damage.
- A definition's `hp` can change in a later tuning pass without damaging or healing any saved
  ship.

### 4.3 What a stage change costs

A rebuild is wholesale and happens on `cell_changed` (`ship.gd` `_on_cell_changed`). Damage
arrives in bursts of many small hits, so:

- **hp changes alone rebuild nothing.** They happen on the `BlockInstance` in place.
- **Crossing a stage** emits a new `ShipGrid.block_staged(coord, stage)`. `Ship` recomputes
  `ShipStats` and swaps that one cell's look (§9). There is no geometry rebuild.
- **Gone** goes through `clear_block` and the existing full rebuild. That is at most a few times a
  second even in a bad crash. The per-cell rebuild the slice-1 spec deferred "for when weapons
  start destroying blocks" stays deferred until profiling asks for it.

### 4.4 Stats and crippled

`ShipStats._gather` multiplies each block's contribution by its stage's output: 1, 0.5 or 0.
Mass and inertia always count in full.

The ship is **crippled** while any of these holds:

- forward thrust is below 25% of what the ship had intact;
- any rotation axis's `torque_budget` is below 25% of what it had intact;
- no quantum core works (it can't make power).

The intact figures are computed once from the blueprint with every block treated as intact. A
crippled ship still flies on whatever it has left, and the HUD says **CRIPPLED** in
`HudPalette`'s warning colour. First Blood will make the enemy stop firing at a crippled ship. For
now crippled is a warning you earned by crashing.

### 4.5 Blocks that can't be removed, and pieces that break off

> **Amended 2026-10-02, the owner's report:** after a hard crash onto a planet, losing blocks
> reshaped the cabin and left the owner stuck in a little room with the chair, unable to sit
> back down to fly. The inside now **changes style, never shape**. Every walkable cell of the
> launch layout, and every block that walls, floors or roofs one (the cabin's shell,
> `Ship.inner_cells`), is wrecked but never knocked off. So is any block whose loss would cut
> part of the shell off from the core. Only the **buffer** outside the shell breaks away: on
> the starter, 49 of 110 blocks (fairings, outer hull and wedges, engines and RCS). A save that
> had already lost shell blocks gets them back, wrecked. §4.6 and §7.4 no longer happen.

- **The ship core** goes down to Wrecked but is never removed. Losing the core would need "the
  ship is destroyed", which the owner's answers rule out for now. A wrecked core means crippled.
- **The pilot seat and the airlock you came in through** follow the same rule: they can be
  wrecked, never removed. That way you can always get aboard and sit down.
- **A removal that splits the ship:** any piece no longer connected to the core (flood fill, as
  `ShipValidator._check_all_connected` does) breaks off. It is removed with a burst and a scatter
  of short-lived debris. Debris you can salvage and pieces that fly on their own are later work.
  This is rare with the starter shuttle, but it must not leave blocks floating.

### 4.6 Holes

> **Amended 2026-10-02:** the cabin never opens (§4.5): holes are in the buffer only.

The slice-1 non-goals still stand: there is **no atmosphere or pressure**. A removed wall is a
hole onto space. The interior builder already treats a face onto an empty cell as outer skin, so
the room shows the stars through it. Decompression and breaches are later work (§14).

A removed deck cell under you drops you into the void beside the ship. The avatar switches to
suit mode, as when leaving by the airlock, so you don't fall through the world (§7.4).

---

## 5. Sources

Every number here is a **first value for the feel pass**, not a promise.

### 5.1 The plasma pistol

- A bolt carries **damage 10**, kind `&"plasma"`, as well as its existing push.
- It damages what it hits: an NPC, you (another's bolt; your own bolts never hit you), your ship's
  hull from outside, and the block behind an interior face from inside (§2).
- The hit block: exterior colliders are one `CollisionShape3D` per cell, and
  `ExteriorBuilder.collider_coords()` already maps shape index → coord. Inside, the cell is
  found from the hit point, stepped 5 cm back along the normal into the solid, turned into
  grid-local space through `Ship.interior_slot_origin()`.
- Ten hits wreck a deck plate (60 hp); twenty wreck a hull block (200 hp).

### 5.2 Crashes: the ship

- `Ship` already measures a strike as `knock`, the hull's change of speed in m/s
  (`_on_hull_struck`). It moves from `body_entered` to `_integrate_forces`, so the contact's
  shape index, and so its cell, is known.
- **Below 2 m/s of knock: nothing.** Nudging a rock while docking to it stays free.
- Above that, the struck cell takes `CRASH_K × (knock − 2)²` with `CRASH_K = 12`. Its face
  neighbours take half of that. At a knock of 5 m/s a hull block takes 108 hp: damaged. At 8 m/s
  it takes 432 hp: gone, with its neighbours wrecked.
- A rock the ship hits is not damaged. Breaking rocks is mining, which is not this spec.

### 5.3 Crashes: you, on a spacewalk

- `Avatar.bump` already finds the closing speed of every rock or creature you hit. Above
  **4 m/s** you take `10 × (closing − 4)` hp, kind `&"crash"`.
- Aboard, nothing hurts you. A hard burn's jolt is feel, not damage.

### 5.4 Creatures: skitters bite back

Skitters graze and flee. None of the NPCs can hurt you yet. This spec gives the skitter one new
behaviour (§2):

- **`defend`**: when it is hurt, or when its fear is high and you are within 2 m with nowhere for it
  to scatter to, it turns, lunges and bites. A bite is **15 hp**, kind `&"bite"`, with a
  **1.5 s** cooldown. It gives up when you are more than 6 m away, or when its fear drops.
- It is built from the NPC skill's template: a `Behaviour` scored from fear and the hurt
  stimulus, with no new locomotor. The lunge is the crawler's move with a burst of speed.
- A bite is a `Hit` from the skitter to you, so you are shoved as well as hurt.

---

## 6. NPCs

- **`NpcSpecies.max_health`** (new): skitter **40** (four bolts), maintenance droid **60**.
- **Hurt:** `Npc.receive_hit` already sends a touch and a shove. It now also takes the damage,
  raises fear by `damage / max_health`, and plays a flinch on the look.
- **Health lives on the record.** `NpcRecord` gains `health`, so an NPC that is demoted and
  promoted again keeps its wounds. NPCs heal 1 hp per 10 s, and only while their record is live.
- **At 0, a creature dies.** It stops, rolls over and lies still. After **20 s** it fades and its
  node is freed. The death is written to a new **`NpcLedger`** keyed by record id, and
  `NpcDirector.amend(record)` returns null for a dead record, so it is never promoted again. The
  ledger is saved (§10).
- **At 0, the droid is knocked out, not killed.** It drops, its lights go dead, and after **60 s**
  it reboots at 25% health, or at once if you weld it with the torch (§8.2). So a crew droid is
  never lost for good (§2).

---

## 7. You

### 7.1 Health

- **100 hp.** `Avatar` holds a `Health`.
- **You heal** 5 hp/s after 10 s with no damage. There are no medkits in this slice.
- **Feel:** a thump from `Synth`, a brief warm-red edge on the view, and a short camera jolt the
  way the hit came. Below 30 hp the edge stays, faintly, and your breathing is heard in the suit.
  The red is a `HudPalette` warning colour, never a new light.

### 7.2 Downed

At 0 hp:

1. Control is taken away. The view tips and fades to black over **1.5 s**.
2. Whatever is in your hand is dropped where you fell. If you are outside, it becomes a stray.
3. **Aboard:** you wake on the lower bunk of a bunk room, or beside the core if the ship has none,
   after **3 s** of black.
   **Outside:** the suit's emergency cell brings you home, exactly as when the suit runs dry
   (`Suit.home_step`), with the screen black and a faint beacon tone. You wake just inside the
   airlock you left by.
4. **The cost:** you wake with 50 hp, and the ship's store pays **50 QE** for patching you up. It
   may go to 0 and into low power. The toast reads *YOU BLACKED OUT · 50 QE*.

Downed is an action: the save gate waits until you are awake (§10). A save therefore never
resumes a blackout.

### 7.3 What you can't do

You can't be downed while seated at the helm. Hits to you there go to the ship instead: the canopy
is the weak point the art direction left for it. That keeps a crash from being a blackout on top of
a wreck.

### 7.4 Falling out

> **Amended 2026-10-02:** no longer happens: the deck under you is part of the cabin's shell
> (§4.5). The handling stays, harmlessly, for whatever opens a deck later.

If the deck cell under you is removed (§4.6), you switch to suit mode at your current velocity, as
if you had just left the airlock. If the suit is dry, the emergency cell brings you home.

---

## 8. Repair

The owner chose a handheld tool: you carry it to the damage and point it there.

### 8.1 The repair torch

- **A new item, `repair_torch`**: a stubby welding torch, one-handed (`Grip.WIELD`),
  `stow_class = &"tool"`, `quantum_value = 60`. It is **not** an `eva_tool`: that flag means
  "never made or converted", and a torch lost to the strays must be makeable again at the
  quantum machine. Any wielded item already works on a spacewalk. The ship starts with one in
  the tool closet, stocked like the pistol. Its look is built from the kit and coloured
  from `InteriorPalette`: a warm off-white body, a gunmetal nozzle and a terracotta `BELT` band.
- **Hold `use` to weld.** It reaches **2.5 m** from the eye. The block you aim at mends at
  **25 hp/s**. A warm spark spray and a small practical light sit where the nozzle meets the
  surface. The light is a warm `OmniLight3D` (range 1.5 m); outside, its sparks join
  `Universe.HOLDS_SHIFT`.
- **It is fed scrap plates.** The torch has a hopper of **feed**, up to **300**, and one hp
  mended costs one feed. A hull block from wrecked to intact is 200 feed. With the hopper empty,
  the torch splutters and does nothing.
- **Loading it:** aim the torch at a `scrap_plate` item within reach and hold `use`. Over
  **1.5 s** the plate glows, shrinks and is gone, and the hopper gains **100**. That is refused
  (*TORCH FULL*) while the hopper has less than 100 room. The plate can be lying on the deck,
  sitting in a stow point or drifting outside. You never have to hold it, which matters because
  the plate needs both hands (`Grip.CARRY`) and the torch one.
- **Where plates come from:**
  - salvage fields already scatter them (`SalvageField.MIX`);
  - the quantum machine already makes them from QE;
  - the ship starts with the torch full and **three plates** in a pile on the closet's bottom
    shelf, where a crate used to stand: their own stow class, `plate`, three spots stacked
    `InteriorProps.PLATE_LIFT` apart (amended 2026-10-02: they had never been stocked, and the
    owner chose the crate's place);
  - a block knocked off outside sheds **one plate** from the hole, as a stray (saving §7), which
    you can catch before it drifts off.
- **The prompt** shows what the aim is on, its health left, its stage and the hopper, which the
  player sees as **scrap**: *HULL PLATE · 12% H · WRECKED · SCRAP 180/300*. (Amended
  2026-10-02: the owner read *WRECKED 12%* either way round and *FEED* said nothing.) Releasing `use`, looking away or moving out of reach
  stops the weld.
- **The feed is saved** with the torch, through `ItemUse.save()`/`restore()` (saving §6.5).

### 8.2 What it mends

- **A damaged or wrecked block**, through `BlockDamage.repair(grid, coord, hp)`, the mirror of
  damage. A stage crossed on the way up emits `block_staged`, just as on the way down.
- **A gone block.** Aim at the empty cell, through the hole's edge from inside or at the gap from
  outside. The torch rebuilds it from the blueprint the ship launched with, which the ship
  already keeps (saving §6.2). It costs **100 feed** (one plate's worth) and **3 s** of holding.
  The block comes back **wrecked**, through `ShipGrid.set_block` and one rebuild, so it then has
  to be welded up. The prompt reads *REBUILD THRUSTER · COSTS 100 · SCRAP 300/300*.
- **The maintenance droid** (§6): welding a knocked-out droid brings it round at once, and welding
  a hurt one mends it, at the same rate and feed.
- **Not you, and not creatures.**

### 8.3 How it plugs in

- `ItemUse` gains `hold(item, aim, world, holder, delta) -> bool`, which does nothing by default.
  `Grasp` calls it every physics frame while `use` is held, after the press has called `use()`
  as today. The pistol ignores it, so nothing about the pistol changes.
- The torch finds its target with one ray, mask `2 | 1 | 32 | Npc.LAYER`: interior geometry,
  the exterior hull on a spacewalk, items (plates to load), and NPCs. The cell comes from the hit the same way as for a bolt
  (§5.1). That code is shared in `ShipCells.cell_at(ship, hit)`.
- **While welding, saving waits** (*"welding"*), through the avatar's `busy()`.

---

## 9. How damage looks

Everything here follows `docs/design/visual-style.md`: flat colour from the palettes, warm
practical lights, no procedural surface detail, and no fourth interior shader.

| Stage | Hull, outside | Interior |
|---|---|---|
| Damaged | the block's colours darkened toward a new `HullPalette.SCORCH`; now and then a spark (in its parent's frame, as built) | the cell's dressing darkened toward `InteriorPalette.SCORCH`; sparks from the wall; its ceiling light steady until the block is **under 20% of its health** (`BlockDamage.FLICKER_AT`, the owner's call on 2026-10-03), then it flickers as a wreck's does |
| Wrecked | toward `HullPalette.CHAR`; accents and emissives off | toward `InteriorPalette.CHAR`; screens `SCREEN_BACK`; its ceiling light **flickers**: 10% of full most of the time, with a short ragged burst at full every few seconds, about 93% of the time dim (`LightFlicker`; amended 2026-10-03, the owner's call: first it went dark and read as a hole) |
| Gone | a burst of warm sparks and a few chunks for 2 s; then a hole | the hole shows the stars |

Colours change through the existing kit's per-vertex colour, which means a rebuild of that one
cell's mesh, not a new material. **§11.2 needs renders at eye height** for the owner before any of
this is called done.

---

## 10. Saving

- **Already saved:** block hp (saving §3), now read as damage taken (§4.2). The format version is
  unchanged.
- **Added:** your `health.current`; the `NpcLedger` (dead records by id); each live record's
  `health`.
- **The torch's feed** rides the item's use state, which items aboard and strays already save
  (saving §6.5). There is nothing new in the format.
- **The save gate** gains `DamageLog` as a source: *"took damage"* for 5 s after anything takes
  damage, which is what saving §5 left room for. The avatar's `busy()` adds *"blacked out"* and
  *"welding"*.

---

## 11. Testing

### 11.1 Automated (GUT, headless)

- `test_health.gd`: take, heal, `emptied` fires once, regen waits for the calm.
- `test_block_damage.gd`: stages at each boundary; output factors; crossing emits
  `block_staged` once; gone calls `clear_block`; the core, the seat and the entry airlock never go;
  split-off pieces are removed.
- `test_ship_stats.gd` (extended): a damaged thruster gives half its thrust, a wrecked one none;
  crippled at each threshold.
- `test_ship_damage.gd`: the exterior shape index → cell; the interior hit point → cell, for
  every face direction; crash damage below and above the threshold.
- `test_npc_death.gd`: a dead record is never promoted again, across a save round-trip.
- `test_repair_torch.gd`: holding mends at 25 hp/s and uses 1 feed per hp; an empty hopper does
  nothing; out of reach stops it; loading a plate takes 1.5 s, frees the plate and adds 100, and
  is refused when full; a gone block comes back wrecked for 100 feed after 3 s; the droid is
  brought round; the feed round-trips through `save()`; `Grasp` calls `hold` only while `use` is
  held.
- `test_block_damage.gd` (as above) also checks that a block knocked off outside sheds one plate
  as a stray.
- `test_downed.gd`: aboard and outside; the item dropped; the QE paid; saving waits.
- `test_ship_blueprint.gd` (extended): an old dictionary with `hp_values` reads as undamaged;
  damage round-trips.
- `test_npc_catalog.gd` already checks every species. It gains a check that `max_health` is
  above 0.

### 11.2 In the real scene (mandatory)

- Render a hull block and an interior cell at each stage, at 1.6 m eye height, in the real ship.
  Show them to the owner.
- Ram rocks at 3, 5 and 8 m/s and record what breaks. Tune `CRASH_K` until the owner is happy.
- Get bitten on a rock, black out, and wake aboard.
- Shoot the maintenance droid down, and watch it reboot. Then weld it round.
- Wreck a thruster by ramming, go out on a spacewalk with the torch, and weld it back. Render the
  torch in the hand and its sparks on the hull at eye height for the owner.

### 11.3 The skills

When this is built:
- `building-a-ship` gets stages, crippled, the blocks that can't be removed, and "a new block
  needs a sensible `hp`", with lines in `ship_probe.gd` for intact hp and crippled.
- `building-an-npc` gets `max_health`, death through the ledger, and the `defend` behaviour as
  a template.

---

## 12. Files

| File | Change |
|---|---|
| `src/items/hit.gd` | `damage`, `kind` |
| `src/combat/health.gd` | new: `Health` |
| `src/combat/damage_log.gd` | new: `DamageLog` |
| `src/ship/block_damage.gd` | new: `BlockDamage` |
| `src/ship/block_instance.gd`, `ship_blueprint.gd` | `hp_current` → `damage`; `damage_values`, reading the old key |
| `src/ship/ship_grid.gd` | `block_staged` |
| `src/ship/ship_stats.gd` | stage output; intact figures; `crippled` |
| `src/ship/ship.gd` | crash damage in `_integrate_forces`; hull `receive_hit`; stage looks |
| `src/ship/exterior_builder.gd`, `interior_builder.gd` | one cell's look by stage |
| `src/avatar/avatar.gd` | `Health`, `receive_hit`, downed, falling out |
| `src/npc/npc.gd`, `npc_record.gd`, `npc_species.gd`, `npc_director.gd` | health, death, the ledger through `amend` |
| `src/npc/npc_ledger.gd` | new |
| `src/npc/behaviours/defend.gd` | new |
| `src/items/plasma_bolt.gd` | damage 10 |
| `src/items/item_use.gd`, `src/avatar/grasp.gd` | `hold()`, called while `use` is held |
| `src/items/repair_torch.gd`, `data/items/repair_torch.tres` | new: the torch's use, its feed, and its definition |
| `src/ship/ship.gd` `_stock()` | the torch, and three scrap plates |
| `src/items/item_looks.gd` | the torch's look |
| `src/ship/ship_cells.gd` | new: `cell_at(ship, hit)`, shared by bolts and the torch |
| `src/ui/…` | hull and CRIPPLED in the band; your health edge |
| `src/ship/interior/interior_palette.gd`, `src/ship/hull_palette.gd` | `SCORCH`, `CHAR` |
| `src/save/save_game.gd` | your health; the ledger |
| `data/npcs/*.tres` | `max_health` |

---

## 13. Open questions for the owner

None. All eleven were answered on 2026-09-29 and are recorded in §2.

---|---|---|
Answered on 2026-09-29 and moved to §2: repair, your own pistol, the biter, and the cost of
blacking out. These are still open, and the draft follows the recommendation until the owner
says otherwise:

| # | Question | Recommendation |
|---|---|---|
| 1 | **Does a downed droid come back by itself?** | **Yes, after 60 s,** or at once with the torch (§6). |
| 2 | **Can you be hurt at the helm?** | **No: the ship takes it** (§7.3). |
| 3 | **What does the torch draw on?** | **Your suit cell** (§8.1). Scrap plates as material are the alternative, and would give salvage a use. |

---

## 14. Later, not built

- **First Blood:** turret MOUNT blocks, shields, an enemy ship, and aiming at the crippled state.
- **Air and breaches:** pressure, decompression and patching holes.
- **The environment:** the star's heat, hard landings (Planetfall), running out of air in a suit.
- **Debris:** pieces that break off and fly on their own, and salvaging them.
- **Medkits** (a `medkit` prop already exists, with no use yet) and a medbay block.
- **Per-cell rebuilds,** if profiling shows the wholesale rebuild on "gone" costs too much.

## 15. Non-goals

No new weapons. No enemies that hunt you. No atmosphere. No permadeath. No rocks broken by
anything.

## 16. Risks

| Risk | Mitigation |
|---|---|
| Rebuild spikes when several blocks go at once in a crash | Blocks that go in one physics step share one rebuild (the grid batches its `cell_changed`) |
| A removal leaves you inside a wall or over nothing | §7.4; the avatar's `can_stand_at` is checked after every rebuild |
| Damage looks drift toward realism (decals, grime) | Stage colours only, from the palettes; renders go to the owner (§11.2) |
| The crash curve is wrong: harmless or brutal | `CRASH_K` and the threshold are tuned in the real scene, not in tests |
| Wearing the ship down with one save slot | The torch mends anything, even a gone block (§8) |
| Welding the hull outside is fiddly with the suit's drift | Reach is 2.5 m and the weld holds while the aim stays on the cell, not an exact point; tuned in the real scene |

---

## 17. How the build differs

Built 2026-09-29 to 30: the suite went from 1,421 tests to 1,530, all green, headless.

1. **Damage is a float,** not an int (§4.2). The torch mends about 0.4 hp a frame, which an int
   would round away. The save keeps its positional cell arrays: the sixth slot, always 0 before,
   is now damage taken, so there is no key to rename. `ShipBlueprint.damage_values` replaces
   `hp_values`.
2. **Every airlock is kept** (§4.5), not only the one you came in by: the ship doesn't know which
   that was, and a starter has one.
3. **How hits find a block.** The hull and the interior are scriptless bodies, so they take hits
   through a `&"receive_hit"` Callable in meta (`Hit.deliver`). Each hull collider carries its
   cell in meta `&"cell"`: an airlock alcove adds several colliders for one cell, so a shape
   index is not a coord. Crash contacts come from the hull's direct physics state, and their
   damage is dealt after the physics step, because a removal rebuilds colliders.
4. **The interior can't recolour one cell** (§4.3, §9): its dressing is a few merged meshes. A
   stage change on a block you can see from inside rebuilds the ship once, at the end of the
   frame. That costs about **140 ms** headless on the 2.8 GHz dev Xeon, the same as any removal:
   a hitch. Per-cell rebuilds stay in §14.
5. **The hull livery takes the tint.** `hull` and `hull_wedge` use `hull_livery.gdshader`, which
   ignored the instance colour, so those blocks didn't look damaged from outside. The owner
   approved the one-line fix on 2026-09-30: its albedo is multiplied by `COLOR.rgb`. The livery's
   meshes and the airlock alcove's plates have no vertex colours, so undamaged, they look as
   before.
6. **Waking** (§7.2). The bunk room is mostly bunks, so you wake at the free cell nearest it.
   Outside, the suit brings you home during the black and you wake there too, not inside the
   airlock: the airlock may be open to space.
7. **Feel** (§7.1). The thump reuses `hull_thump`, and the head rolls 0.05 rad from the side the
   hit came from. There is no breathing below 30 hp yet. The wake line *YOU BLACKED OUT · 50 QE*
   is drawn by the same overlay as the red edge (`HurtEdge`).
8. **NPC health lives in `NpcLedger`,** not on `NpcRecord` (§6): recipes make records afresh on
   every review. Looks aren't changed per species: `Npc` poses the look itself (a squash, a
   70° slump, on its back). The droid's eye doesn't go dark.
9. **Cornered** (§5.4) is fear above 0.7 with you within 2 m; the site isn't asked whether there
   is somewhere to scatter to. `defend` is weighted 1.2, so when you are close it wins over
   `scatter`'s touch.
10. **The torch works outside** because items gain `works_outside` (§8.1): hands are suspended on
    a spacewalk, and "any wielded item already works outside" was wrong. Taking, dropping and
    throwing still wait until you are aboard. What you hold goes outside drawn for outside.
11. **The torch's place.** Every stow point was full, and a test pins everything in the hands and
    items spec's set as aboard, so the torch takes the second flare's place in the weapon room
    rather than the spanner's, and **the ship starts with no plates**. A full torch holds three
    plates' worth. Plates come from salvage and the quantum machine, and from blocks knocked off.
12. **Not tuned yet.** `CRASH_K` and `CRASH_FROM` are the first values. On the starter, nose-on
    into a wall (`test/probes/crash_probe.gd`): 3 m/s hurts three blocks a little; 5 m/s knocks
    one off and damages three; 8 m/s knocks four off. Nothing crippled it.
13. **Renders** so far are software GL (Mesa llvmpipe, the compatibility renderer), flatter than
    the owner's GPU: the interior at each stage (`test/probes/damage_render.gd`) and the torch
    in hand and welding (`test/probes/torch_render.gd`). Outside, at the sun's back, the hull
    was too dark to judge.
14. **The cabin keeps its shape** (amended 2026-10-02, §4.5): the owner's crash left them stuck
    beside the helm. Damage wrecks the cabin's shell and knocks off only the buffer outside it.
    Inside, a damaged or wrecked wall now spits sparks into the cabin as well as darkening. On
    the starter, nose-on into a wall: 3 m/s hurts three blocks a little, 5 m/s damages two and
    wrecks one (nothing goes), and 8 m/s knocks three buffer blocks off.
15. **The spits no longer hold the floating origin.** The first build gave every damaged hull
    block a world-space emitter in `Universe.HOLDS_SHIFT`, re-fired every 0.8–2.5 s. With a few
    damaged blocks, the shift would almost never have found a gap. The spits are now in their
    emitter's own frame (the hull, or the interior) and hold nothing; only the two-second burst
    when a block goes still does.
16. **A stage seen from inside rebuilds only the interior.** The hull recolours in place, so it
    is left standing: about 125 ms of a full rebuild's 210–230 ms on the dev Xeon (the generated
    skin from the ship exterior work made the full rebuild dearer).

