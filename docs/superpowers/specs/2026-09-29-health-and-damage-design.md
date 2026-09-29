# Health and damage — things that can be hurt, broken and lost

**Date:** 2026-09-29
**Status:** First draft. The owner answered four scoping questions (§2) on 2026-09-29. §13 lists
the questions still open; nothing is built until they are answered.
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

What follows from them:

- **The ship must be mendable.** With one save slot and no save-scumming, a ship that is only ever
  worn down is lost slowly for good. This slice needs some repair (§13, question 1).
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
| **Wrecked** | 100% up to 150% | **not at all**; keeps its mass and collision | charred; lights dead |
| **Gone** | 150% or more | removed with `ShipGrid.clear_block` | a burst, and a hole |

The span from 100% to 150% is how much a wreck takes before it is knocked off. That way
"wrecked" lasts long enough to be seen and repaired.

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

- **The ship core** goes down to Wrecked but is never removed. Losing the core would need "the
  ship is destroyed", which the owner's answers rule out for now. A wrecked core means crippled.
- **The pilot seat and the airlock you came in through** follow the same rule: they can be
  wrecked, never removed. That way you can always get aboard and sit down.
- **A removal that splits the ship:** any piece no longer connected to the core (flood fill, as
  `ShipValidator._check_all_connected` does) breaks off. It is removed with a burst and a scatter
  of short-lived debris. Debris you can salvage and pieces that fly on their own are later work.
  This is rare with the starter shuttle, but it must not leave blocks floating.

### 4.6 Holes

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
  hull from outside, and the block behind an interior face from inside (§13, question 2).
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
behaviour (§13, question 3):

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
  it reboots at 25% health. A crew droid lost for good needs repair to exist first (§13,
  question 5).

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

If the deck cell under you is removed (§4.6), you switch to suit mode at your current velocity, as
if you had just left the airlock. If the suit is dry, the emergency cell brings you home.

---

## 8. Repair

**Not decided: §13, question 1.** The recommendation:

- **The quantum machine repairs the ship.** It already makes objects from QE. A new page on its
  panel lists damaged, wrecked and gone blocks, with costs. A block's repair costs
  `hp missing × 0.5 QE`, and a gone block costs its full hp × 0.5 plus 25 QE.
- Repair happens over time: 20 hp/s for the whole ship, one block at a time, nearest the machine
  first. It is an action, so the save gate waits.
- A gone block is put back as it was in the blueprint the ship launched with. The ship
  remembers that blueprint anyway (saving §6.2).

A handheld repair tool you carry to the damage is the alternative. It is more fun and more work,
and suits Slice 3's corridors better.

---

## 9. How damage looks

Everything here follows `docs/design/visual-style.md`: flat colour from the palettes, warm
practical lights, no procedural surface detail, and no fourth interior shader.

| Stage | Hull, outside | Interior |
|---|---|---|
| Damaged | the block's colours darkened toward a new `HullPalette.SCORCH`; now and then a spark (world-space particles, in `Universe.HOLDS_SHIFT`) | the cell's dressing darkened toward `InteriorPalette.SCORCH`; its practical light flickers |
| Wrecked | toward `HullPalette.CHAR`; accents and emissives off | toward `InteriorPalette.CHAR`; its light dead; screens `SCREEN_BACK` |
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
- **The save gate** gains `DamageLog` as a source: *"took damage"* for 5 s after anything takes
  damage, which is what saving §5 left room for. The avatar's `busy()` adds *"blacked out"*,
  and the quantum machine's adds *"repairing"*.

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
- Shoot the maintenance droid down, and watch it reboot.

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
| `src/ui/…` | hull and CRIPPLED in the band; your health edge |
| `src/ship/interior/interior_palette.gd`, `src/ship/hull_palette.gd` | `SCORCH`, `CHAR` |
| `src/save/save_game.gd` | your health; the ledger |
| `data/npcs/*.tres` | `max_health` |

---

## 13. Open questions for the owner

| # | Question | Recommendation |
|---|---|---|
| 1 | **How is the ship mended?** | **At the quantum machine, for QE** (§8). A repair tool is the alternative. |
| 2 | **Can your own pistol damage your own ship?** | **Yes, from inside and out.** Nothing about it is special, and it's the easy way to test. The other option is that bolts only damage what isn't yours. |
| 3 | **Which creature bites?** | **Skitters, but only when hurt or cornered** (§5.4). A new predator species is the alternative, and is bigger. |
| 4 | **What does blacking out cost?** | **50 QE, plus whatever you were holding** (§7.2). |
| 5 | **Does a downed droid come back?** | **Yes, after 60 s** (§6), until repair can mend it. |
| 6 | **Can you be hurt at the helm?** | **No: the ship takes it** (§7.3). |

---

## 14. Later, not built

- **First Blood:** turret MOUNT blocks, shields, an enemy ship, and aiming at the crippled state.
- **Air and breaches:** pressure, decompression and patching holes.
- **The environment:** the star's heat, hard landings (Planetfall), running out of air in a suit.
- **Debris:** pieces that break off and fly on their own, and salvaging them.
- **Medkits** and a medbay block.
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
| Wearing the ship down with one save slot and no repair | Repair is in scope (§8); only the method is open |
