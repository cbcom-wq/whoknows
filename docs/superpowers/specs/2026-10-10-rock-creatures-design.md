# Rock creatures — a Glinter, a Delver and a Limpet on the big rocks

**Date:** 2026-10-10 (brainstormed with the owner, 2026-10-02 to 2026-10-10)
**Status:** Design, awaiting the owner's review of this written spec. Nothing is built. Every row
of §2 was decided by the owner in the brainstorm. Refreshed 2026-10-18 against `main` at `85aa4d4`:
the hose, its prerequisite, has merged (§13), and ship weapons now target creatures (§8.1).
**Depends on:** `main` at `85aa4d4`: the NPC foundation (skitters, the droid, `NpcDirector`,
`StimulusBus`), health and damage (bites, `NpcLedger`), habitat modules Phases A–C (bases, drills and
`Bases.quiet`), quantum energy's Tasks 1–8 (the store, the machine, the suit cell, the near cloud),
the hose (`93543b3`), ship weapons (`85aa4d4`), the floating origin, and big rocks in detail.
**Governed by:** `docs/design/visual-style.md` (§3.6 NPCs), CLAUDE.md's floating-origin rule, and
the `building-an-npc` skill.
**Builds on:**
- the NPC foundation (`docs/superpowers/specs/2026-09-26-npc-foundation-design.md`): §2 the layers,
  §4 populations, §13 the skitter, §22 the life sensor;
- health and damage §5.4 (the skitter's `defend`) and §6 (`NpcLedger`);
- habitat modules §8.4 (skitters and drills), §6.2 (the drill's richness);
- quantum energy §2 row 8 (the hose reaches 8 m), §9 (the suit cell), §10 (salvage and its glint),
  §11 and its *As built* (the hose);
- ship weapons (`docs/superpowers/specs/2026-10-11-ship-weapons-design.md`): exterior NPCs are
  fire-control targets.

**Amends, once approved:** the NPC foundation (a rock's site holds every species on it, §3); habitat
modules §8.4 (Limpets raid a base; Delvers keep away from a drill); the visual style guide §3.6 (a
bullet per creature); the `building-an-npc` skill (§14).

---

## 1. Why

The owner, 2026-10-02:

> Let's imagine some new NPC creatures we can have in our asset pool to create and spawn if desired.

What exists today:
- **Two species.** The skitter (outside, a shy grazer on the big rocks) and the maintenance droid
  (inside). The foundation was built so that "a new species swaps a layer": locomotors, behaviours,
  senses and looks are reusable parts.
- **Nothing to find, fear or earn from out there.** Skitters scatter and, since health and damage,
  bite back. Salvage is a cloud behind the stern, gathered with the hose. A drill earns QE
  on the clock. Nothing on a rock is worth going to look at for its own sake.
- **No way to call a creature up.** A species appears only where its seeded population puts it.

### 1.1 The bestiary

The brainstorm sketched eight creatures, for three roles the owner chose (ambient life, hazards and
threats, part of the economy) in two places (asteroids, open space). They are the pool; the owner
chose batch A to build first.

| # | Creature | Role | Place | Moves | Hook ("who knows") | Batch |
|---|---|---|---|---|---|---|
| 1 | **Glinter** | hazard, salvage you can't trust | rocks | crawls, leaps | glints like salvage; some of a nest's "salvage" bites | **A** |
| 2 | **Delver** | economy, ambient | veined rocks | crawls, burrows | follow it; it pays in grit and, rarely, a shard | **A** |
| 3 | **Limpet** | hazard and economy | rocks | crawls, slowly | drawn to quantum energy: sips your suit, raids a base | **A** |
| 4 | Trapjaw | hazard, food chain | crater floors | lunges | disguised as scree; hunts skitters | C |
| 5 | Motes | ambient, a hint of economy | open space | swirls | a shoal circling something often means salvage | B |
| 6 | Sunsail | ambient, economy | open space | drifts | turns its panels to the sun; sheds crystal | B |
| 7 | Harrier | hazard | open space | fast passes | hunts a spacewalker; hates light | B |
| 8 | Atoll | ambient spectacle | open space | very slow | a skitter herd lives on its back | B |

### 1.2 What this adds

- **A rock's whole ecology in one place** (§3): one site, one recipe, one source for every species
  on a rock, with the skitter's records unchanged.
- **Three species** (§4–§6) built only from the foundation's layers, plus one small locomotor.
- **A dev spawner** (§7) and the life sensor reading every group.
- **A few small seams** in shared code (§8: bite and drain as species data, a drain hit, a placed
  salvage cloud, a stray count) that later species will reuse.

---

## 2. Decisions

All taken by the owner in the brainstorm.

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Roles | Ambient life, hazards and threats, and part of the economy | the owner's pick of four |
| 2 | Places | Asteroids and open space; batch A is the rocks | the rocks reuse the crawler and drift as they are |
| 3 | Which first | **Glinter, Delver, Limpet** (batch A) | all reuse locomotors, and they exercise item drops, a quantum sense and a multi-species rock |
| 4 | Structure | **One rock, one ecology** (§3) | one place keeps groups apart and caches the craters once; the Trapjaw needs it later |
| 5 | Glinter | **Hoarders:** nests of real salvage with Glinters among it; no sensor lure | learn to tell them apart by eye; salvage has no sensor contact yet |
| 6 | Limpet | **Sips your suit**, and raids bases | a hazard with a risk-reward; bases get a pest without designing raids |
| 7 | Bases | **Limpets raid; the rest keep away** | the drill already scares skitters; Limpets are drawn to quantum energy |
| 8 | Delver's pay | **Grit, sometimes a shard** | a steady trickle and a gamble |
| 9 | Spawning | **A dev panel** (F10), not saved | testing and showing creatures off; no save format change |
| 10 | Gathering | **The hose is built first** | its own piece, already designed; habitat Phase D waits on it too. Done: merged at `93543b3` (§13) |

---

## 3. One rock, one ecology

### 3.1 The recipe

`RockLife` (new, pure) lists every group on a rock, of any species, by running each species' own
small recipe in a fixed order:

| Order | Species | Recipe | Groups per rock | Members per group |
|---|---|---|---|---|
| 1 | Skitter | `RockHerds`, **unchanged** | as today | as today |
| 2 | Glinter | `GlinterNests` | 0–1 (about a third of rocks with craters), on a crater floor | 3–5 Glinters and 2–4 real salvage items |
| 3 | Delver | `DelverBurrows` | 0–1, **veined rocks only** | 1 Delver, a round of 6–10 burrow points |
| 4 | Limpet | `LimpetBeds` | 0–2, on the vein if the rock is veined, else on crater rims | 8–12 Limpets |

- **Fixed salts.** Each recipe has its own salt, distinct from every existing `AsteroidRecipe.cell_seed`
  salt (the plan checks), so adding a species never reshuffles another.
- **Spacing.** Each recipe is handed the places already taken and keeps its homes about 30 m clear
  of them. No Limpet bed sits on a skitter herd.
- **Numbering.** Group numbers carry on across species: skitter herds keep `0…n−1`. So **skitter
  record ids and life-contact ids are unchanged**, and the ledger's dead stay dead. A golden test
  pins this against the pre-change output for several seeds.
- **Record ids:** `"<species>:<site>:<group>:<n>"`, homes in the rock's frame, as the foundation
  requires, and each record keeps its generating direction (the skitter lesson).

### 3.2 The site and the source

- **`RockSite`** (generalised) holds every group of its rock, each record's home direction and the
  cached crater floors. Its `fill` writes what every species shares (group mates, the nearest
  shelter) and then hands over to the species' recipe for the rest: a skitter's round, a nest and
  its untaken salvage, a Delver's burrow points and the crystal, a Limpet's bed and the nearest
  source of quantum energy. **That hand-over is the one place a new species plugs in.**
- **`RockLifeSource`** replaces `RockHerdSource`. It offers a rock's records once its surface is
  within reach of an anchor, as today, with `reach` = the largest `live_radius` of a rock species
  plus `NpcDirector.DEMOTE_MARGIN`. `site_for(rock)` stays.
- **The drill's rule is kept** (habitat modules §8.4). The `quiet` Callable `(site id, engine point)
  -> bool` is asked once per record when a rock first comes into detail, for every species, and a
  quiet record is not offered. A species with `shy_of_drills = false` (the Limpet) is not asked.

### 3.3 The sensor

`LifeContacts` already makes one contact per group on a rock in detail, read by
`SenseProfile.life()` and labelled "LIFE?". After §3.1 a group can be any species, with ids
`life:<site>:<n>`; no other change. See §7.1.

---

## 4. The Glinter

**What it is.** A hoarder: a fist-sized, shell-backed scuttler that lives in nests on crater
floors. From afar a nest is a handful of glints, like salvage. Up close, some of it is Glinters, and
they spring at you.

### 4.1 The nest

- **Placement:** only rocks with craters; about a third of them; never within 30 m of a skitter
  herd (§3.1).
- **Contents:** 3–5 Glinters among 2–4 real salvage items drawn from `SalvageField.MIX`.
- **Real salvage keeps the ledger.** `SalvageField` today scatters a cloud's items in a ball. It
  gains **`add_placed_cloud(cloud_id, centre, entries)`**, where each entry carries its pose, kind and
  variety already chosen. The nest recipe finds each pose with a ray down onto the crater floor, at
  rest (no tumble). Cloud ids are `nest:<site>:<group>`; what is taken goes in `SalvageLedger` as
  before. The rock is fixed, so a placed cloud is re-registered whenever its rock comes into
  detail, and only the ledger is saved (§16).
- **An emptied nest keeps glinting.** Its Glinters stay; nothing real is left to pay.

### 4.2 The tell

A Glinter wears the **same glint as salvage** (`ItemLooks.glint`). Its tell is the rhythm: a nest's
Glinters flash on **one shared beat of about 1.6 s**, where real salvage flashes on its own 2–4 s
(`ItemLooks.GLINT_EVERY`). A nest therefore shows independent blinks and a synchronised flash. Up
close, shut it reads as a scrap-coloured lump; sprung, two pale `SKITTER_EYE` facets show.

### 4.3 Mind

| Behaviour | Kind | What it does |
|---|---|---|
| `lure` (new) | ordinary, default | sits shut among the items; the glint does the work |
| `ambush` (new) | reflex | you within **5 m** and it is not afraid (fear under 0.4): action `&"leap"` at your suit, then `&"bite"` once within its reach; then it raises its own fear to 0.8 |
| `hide` (reused) | ordinary | afterwards it scuttles to the crater floor and stays still until its fear fades, so the nest re-arms |

- **The leap** is the crawler's leap (`Intent.leap_to`, `ZeroGDrift`), aimed at the avatar's
  position rather than at rock. Whether `ZeroGDrift` lands well on a moving suit is checked in the
  plan (§16).
- **Counterplay:** the hose pulls loose items from **8 m** and an ambush springs from **5 m**, so a
  careful player gathers from range and a hasty one is bitten. It has 20 hp (two bolts) and dies.

### 4.4 The bite

`Npc.BITE_DAMAGE`, `BITE_PUSH` and `BITE_REACH` become species fields (§8), defaulting to today's
values so the skitter is untouched. The Glinter's: **8 hp**, push 25, reach 0.8 m.

---

## 5. The Delver

**What it is.** A 3 m segmented burrower that feeds on a rock's crystal. It sinks into the ground,
travels under the surface and comes up elsewhere on the same rock, leaving crystal grit where it
surfaces. It is harmless: surfacing under you shoves you, and that is all.

### 5.1 Where

**Veined rocks only** (`RockMesh.Shape.VEINED`), the rocks a drill pays double on. So a drill and a
Delver compete for the same rocks: the drill's `quiet` rule clears a Delver at rock load, as it does
skitters. A steady drill, or a Delver's windfalls.

### 5.2 Movement: `burrower`

One new small locomotor beside `surface_crawler`, registered in `Npc.make_locomotor`:

- **Sink:** over about 1.5 s the body drops into the ground and its collider switches off.
- **Under:** it travels as an interpolation along the rock's surface directions at about 2 m/s,
  hidden, with no physics and no cost.
- **Emerge:** it rises at the exit point and hands back to `surface_crawler`.

The mind only asks `Intent.go(point, speed, &"burrow")`; it never touches physics. `burrower` keeps a
resting path that does nothing.

### 5.3 Mind

| Behaviour | Kind | What it does |
|---|---|---|
| `feed` (new) | ordinary | goes to the crystal and eats; hunger rises slowly |
| `delve` (new) | ordinary | after feeding it digests, then burrows to the next point of its seeded round, and surfaces |
| `dive` (new) | reflex | a vibration or touch (a bump, thrusters near it) sends it under at once, to the farthest burrow point (`Behaviour.farthest_from`) |

A Delver cycles every **3–6 minutes** of its rock's live time. It does not earn while you are away,
so there is no farming it AFK.

### 5.4 The pay

- **Each surfacing leaves 2–4 crystal grit** (a new item, 15 QE, glints like salvage), and about
  **1 in 12 also leaves a quantum shard** (the existing item, 250 QE).
- **Caps:** at most about 8 untaken grit near a rock, and only one shard lying untaken at a time.
- **They are strays.** The body reports the surfacing to the site, which asks the flight scene (a
  Callable, as `quiet` is) to make the items and `StrayField.adopt` them, so they save and unload
  like any stray. `StrayField` gains a count of a kind within a radius of a point, for the cap.
- **Killed** (60 hp, six bolts) it leaves one shard and six grit and the income ends, so following it
  beats shooting it.
- **The follow:** each surfacing leaves a ring of puffs and then the heap; the heaps teach you its
  burrow points; and the life sensor's region creeps across the rock while it is under (§7.1).

---

## 6. The Limpet

**What it is.** A small, slow, flat-coned shell, 0.3 m across, in beds of 8–12 on a rock's crystal
vein or crater rims. It never bites and never flees. It is drawn to quantum energy and sips it.

### 6.1 What it drains

| Source | When | Rate |
|---|---|---|
| Your suit cell | you are within **5 m** of it, on a spacewalk | 0.4 QE/s each; the avatar takes at most **1.2 QE/s** in all |
| A base's store | it is on the base (within 4 m of a module of an awake, loaded base) | 0.05 QE/s each, so a full bed costs about 24 QE/min |
| Your ship's store | never | none |

- **Safe end.** A bed that runs your suit dry brings you home by the suit's emergency cell
  (`Suit.home_step`), as any dry suit does. Nothing is lost and nothing strands you.
- **It never touches the ship's store or hull,** and the base only while the base is awake.
- **Rates are first values,** set in the real scene.

### 6.2 Mind

| Behaviour | Kind | What it does |
|---|---|---|
| `cling` (new) | ordinary, default | sits on its bed, nearly still |
| `creep` (new) | ordinary | appetite high and a source known: crawls toward it at 0.2 m/s. Your suit within 20 m draws it, and so does a base on its site (the site supplies the place) |
| `sip` (new) | ordinary | in reach it stays and drains; its crystal facets brighten (the brightest `SHADES` step, no glow) |

It feels quantum energy as long-range, all-round, dark-proof sight (range 20 m, a 360° cone,
`dark_sight` 1.0), so no new sense field is needed. It has no fear and never bites.

### 6.3 Raids

A bed within about 100 m of your base, while you are near, creeps over (about 7 minutes) and
settles on the walls, which skitters already treat as terrain. **A Limpet is the exception to
`quiet`:** a drill does not clear it, because it is drawn to it. Asleep (past 20 km) a base is not
drained: no Limpet is live.

### 6.4 The pay

The plasma pistol is the counter (the repair torch mends, so it is not). A Limpet has 15 hp (two bolts) and
drops **one husk worth 20 QE, plus one more for every 40 QE it had sipped, up to four**. Killing a
fat one returns your QE. The tally is kept while it is live. The dead stay dead (`NpcLedger`), so a
bed is a one-time bounty.

---

## 7. Finding them and spawning them

### 7.1 On the HUD

- **The contact keeps its name.** One contact per group, any species, "LIFE?" in the soft green. From
  the cockpit you cannot tell a skitter herd from a Limpet bed, and that fits the game.
- **A Delver's contact follows it underground:** `LifeContacts.herd_point` reads awake members'
  positions, so a 15 m region creeps across the rock while it is under, and your eyes find where it
  surfaces.
- **Nests show as life, not salvage.** Salvage has no sensor contact yet (`SenseProfile.salvage()` has
  no consumer), so a nest's real items do not ping. Its Glinters do.

### 7.2 The dev spawner

- **`CreaturePanel`** (new, `src/ui/`), on **F10** (F3, F4, F6, F7, F8 and F9 are taken). Built like
  F6's `SpawnPanel`: plain text; `1`–`9` pick a species; it only asks (`creature_asked(index)`); the
  flight scene does the work and says how it went on the panel's last line.
- **Where it lands:** at the crosshair, through the camera you are looking through.

  | Species | Spawns on | Count |
  |---|---|---|
  | skitter, glinter, delver, limpet | a big rock in view within 60 m: a ray, then `RockSite.pose_at` | one, or a small group for herd species (skitters 3, glinters 4, limpets 6) |
  | maintenance droid | the deck at the crosshair, when you are aboard | one |

- **Wrong place:** it says why on the last line ("needs a big rock in view").
- **Not saved.** Dev records are held by a **`DevCreatures`** source on the exterior and interior
  directors, live for the session, and forgotten once demoted. The dead still go in the ledger.
- **Record ids** are `"dev:<species>:<n>"`, `n` counting up for the session, so they never collide
  with a rock's records and their fire-control ids (`npc:<record id>`, §8.1) stay unique.
- **Use:** renders and probes make a creature on demand, and a Limpet bed dropped beside a base
  tests a raid.

### 7.3 Species data

Three new `.tres` in `data/npcs/`, populations `glinter_nests`, `delver_burrows` and
`limpet_beds`; the skitter stays `rock_herds`. First values (tuned in renders):

| | Glinter | Delver | Limpet |
|---|---|---|---|
| `size` / `height` / `width` (m) | 0.25 / 0.18 / 0.2 | 3.0 / 0.4 / 0.5 | 0.3 / 0.15 / 0.3 |
| `mass` (kg), `top_speed` (m/s) | 6, 3.0 | 120, 1.2 | 8, 0.25 |
| `max_health`, `knocked_out_for` | 20, 0 | 60, 0 | 15, 0 |
| `locomotors` | `surface_crawler`, `zero_g_drift` | `surface_crawler`, `burrower`, `zero_g_drift` | `surface_crawler`, `zero_g_drift` |
| `sight_range`, cone | 6, 360° | 10, 220° | 20, 360° |
| `dark_sight`, `near_sense` | 0.5, 1.5 | 0.33, 2.0 | 1.0, 0 |
| `feels_vibration` | 1.0 | 1.0 | 0 |
| `needs` | fear | hunger, fear | appetite (0.01/s), fear |
| `behaviours` | `lure`, `ambush`, `hide` | `feed`, `delve`, `dive` | `cling`, `creep`, `sip` |
| `fear_of_player` | 0.3 | 0.2 | 0 |
| bite (hp, push, reach) | 8, 25, 0.8 | — | — |
| drain (QE/s, reach) | — | — | 0.4, 5 |
| `shy_of_drills` | true | true | **false** |
| `live_radius`, `fade` | 150, (110, 140) | 250, (180, 230) | 100, (70, 95) |

`test_npc_catalog.gd` checks every behaviour, locomotor and look id, and that `max_health` is above
0, with no change.

---

## 8. Shared code that changes

| File | Change | Why |
|---|---|---|
| `src/npc/npc_species.gd` | `bite_damage` (15), `bite_push` (40), `bite_reach` (1.6), `drain_rate` (0), `drain_reach` (0), `shy_of_drills` (true) | the skitter's constants become data; defaults keep it identical |
| `src/npc/npc.gd` | `bite()` reads the species' fields; `sip()` asks the avatar or the site to drain; `make_locomotor` knows `burrower`; the body reports a surfacing and a death to its site | the mind never delivers a hit |
| `src/items/hit.gd`, `src/avatar/avatar.gd`, `src/quantum/suit_cell.gd` | a `drain` on `Hit` (kind `&"sip"`, no damage); `Avatar.receive_hit` spends it from the suit cell, capped at 1.2 QE/s; `SuitCell.drain(qe)` | the suit cell is the avatar's |
| `src/habitat/bases.gd` | `sip(site, qe)` (spends from an awake base's store) and `place_of(site, from)` (the nearest module, or null) | the only habitat change |
| `src/world/salvage_field.gd` | `add_placed_cloud` | a nest's items carry chosen poses |
| `src/world/stray_field.gd` | a count of a kind within a radius | the grit cap |
| `src/sensors/life_contacts.gd` | reads groups of any species | §7.1 |
| `src/npc/populations/` | `RockLife`, `GlinterNests`, `DelverBurrows`, `LimpetBeds`, `RockLifeSource` (replaces `RockHerdSource`), generalised `RockSite`, `DevCreatures` | §3 |
| `src/npc/npc_looks.gd` | looks `glinter`, `delver`, `limpet` | §9 |
| `src/items/item_looks.gd`, `data/items/` | `crystal_grit`, `limpet_husk` | §5.4, §6.4 |
| `scenes/flight_test.gd` | wires `RockLifeSource` (with `quiet`), the drop Callables, the dev panel | one place |
| `src/npc/locomotors/burrower.gd` (new) | leaves the fire-control targets while under (`Weapons.leave`), joins again on emerging | §8.1 |

### 8.1 Ship weapons and the creatures

Since ship weapons merged, every live exterior NPC joins the fire-control targets as it is promoted
(`NpcDirector.targets`, `Weapons.join(npc, Weapons.npc_id(record.id))`). So all three species can be
marked and shot from the ship with **no change to weapons**. What that means here:

- **The pay is the same** whoever kills it: drops come from the body's death report (§8, `npc.gd`),
  not from the weapon. A light turret bolt is 15 hp and a heavy one 120 hp, so a heavy bolt kills a
  Delver outright and ends its income, as the pistol's six would.
- **A buried Delver is not a target** (Claude's call in the 2026-10-18 refresh): while `burrower` has it under, hidden and without a
  collider, it leaves the targets and the marked list drops it after the usual 2 s grace; it joins
  again when it emerges. A bolt can never reach it under rock, and a bracket on bare rock would lie.
- **Asteroids take no damage** (weapons §2 row 8), so missing a creature never harms its rock.
- **Bites and sips on a seated player:** creatures never reach you in the turret seat (you are
  aboard); nothing to do.

---

## 9. Looks and sound

Rock palette only (`SpacePalette`), chunky facets, flat colour, no glow, silent outside, built like
`SkitterLook` (built at a fixed size and scaled to the species by the `Npc`). A new colour goes into
`SpacePalette` and is approved by the owner from renders; each look file joins `PAINTING_FILES` in
`test_visual_style_rules.gd`.

| | Look | Triangles |
|---|---|---|
| Glinter | a scrap-coloured lump on short legs (the gait's feet clamped to reach); sprung, two pale `SKITTER_EYE` facets; wears the salvage glint on the nest's beat | ≤ 120 |
| Delver | about six chunky plates trailing a blunt head with a `CRYSTAL` snout; no legs; sinks and rises | ≤ 300 |
| Limpet | a low flat cone in its rock's colour, underside `CRYSTAL`; sipping swaps crystal facets to the brightest `SHADES` step | ≤ 80 |

Distance fade is reversed as for the skitter (`min = fade.y`, `max = fade.x`), render layer 1. The
grit and the husk are items with `ItemLooks` builders, lavender from the palette, glinting.

---

## 10. Budgets

- **Frame:** all NPC work stays under **1 ms** (foundation §16). `npc_probe.gd` is extended to fill
  the exterior director on the worst rock (three skitter herds, a nest, a Delver and two Limpet
  beds) and time 600 frames, reporting the machine. If over, `max_live` or a wake radius moves; the
  measurement is not skipped.
- **Live count:** Limpets wake only within 100 m, so a rock's whole bestiary is never live together;
  `max_live` stays 32, the farthest out dropped with one warning.
- **Resting does nothing,** as the skitter's does; legs are posed rarely when far.

---

## 11. Testing

Targeted files only (project rule).

**New (GUT, headless, output pristine):**
- `test_rock_life.gd`: skitter records and ids identical to a golden file for several seeds;
  determinism; uniqueness; spacing; on-the-surface.
- `test_glinter_nests.gd`, `test_delver_burrows.gd`, `test_limpet_beds.gd`: each recipe.
- Behaviour tests per species, scored from made-up contexts (`templates/test_behaviours.gd`).
- `test_burrower.gd`: sink, under, emerge, hand-over, resting path.
- `test_limpet_sip.gd`: rates, the 1.2 QE/s cap, a dry suit going home, a base drained only while
  awake, the ship's store untouched.
- `test_placed_cloud.gd`: poses kept, the ledger remembers what was taken.
- `test_dev_creatures.gd` and the panel's asks.
- The tell: a nest's Glinter beats are equal and lie outside the salvage band.

**Extended:** `test_npc_species.gd` (new fields read back; the skitter's defaults), `test_exterior_npcs.gd`
(wake unseen beyond the fade, hold place through `Universe.shift`, survive a warp, the drill's `quiet`
per species), `test_floating_origin_scene.gd`, `test_visual_style_rules.gd`.

**Probes and renders shown to the owner:** each creature from a spacewalk at 40–100 m, asking "would
I notice it?" (the skitter lesson); a nest's shared beat across frames; a Delver sinking and rising;
a Limpet sipping; a bed on a base's wall. With `scene.save_enabled = false` in any windowed script.

---

## 12. Build order

The hose has merged, so the plan starts here. Each step ends with the tests for it:

1. **`RockLife` and the single site,** with the skitters pinned identical, and `quiet` kept.
2. **The species fields** and `shy_of_drills`.
3. **The dev spawner,** so every later step can be shown.
4. **Limpet:** the cheapest, with no new locomotor; the sip hit, the suit cap and `Bases.sip`.
5. **Glinter:** `add_placed_cloud`, the nest, the leap check.
6. **Delver:** `burrower`, the grit item, the stray count.
7. **Frame probe, renders to the owner, then the docs** (§14).

Each creature ends with a render shown to the owner before the next begins.

---

## 13. The hose

**Built and merged** (`93543b3`, plan `docs/superpowers/plans/2026-10-10-hose.md`, quantum energy
§11 *As built*): a nozzle on a 30 m line from a reel beside every airlock's outer hatch, pulling
loose things into its own home's store. Its cone is **8 m** long (`Suction.RANGE`), as this design
assumed, so the Glinter's 5 m ambush against an 8 m gather (§4.3) stands. Two as-built facts touch
this batch:

- **Over 0.6 m or 40 kg is not pulled** (`Suction.BIGGEST`, `HEAVIEST`). Grit, shards, husks and a
  nest's salvage are all well under; a Glinter is an NPC, not an item, and is never pulled.
- **Suction stops before an item flies in that the store has no room for** (`HoseReel.room`). A
  Delver's heap beside a full store waits; the grit cap (§5.4) keeps it from piling up meanwhile.

If the hose's reach ever changes, the Glinter's numbers move with it.

---

## 14. Documents to update, in the same branch (CLAUDE.md)

- **`building-an-npc` skill:** the checklist (a rock holds many species; group numbers carry on;
  `shy_of_drills`; the body delivers every drain and drop), *Mistakes already made*, and
  `reference.md` (new fields, `RockLife`, `burrower`, the `sip` hit kind, F10).
- **`docs/design/visual-style.md` §3.6:** a bullet per creature, once the owner approves the renders.
- **Habitat modules §8.4:** Limpets raid; Delvers keep away from a drill.
- **This spec's *As built*.**

---

## 15. Non-goals

- The Trapjaw and the food chain (NPCs perceiving other species): batch C.
- Open-space creatures (Motes, Sunsail, Harrier, Atoll) and their locomotor: batch B.
- Creatures aboard ships, taming, riding, and interactions beyond the seam.
- Sound outside (never, by the style guide).
- A Limpet on your ship's store or hull.
- Salvage on the HUD (quantum energy Task 10).
- Saving dev creatures.

---

## 16. Risks

| Risk | Mitigation |
|---|---|
| The skitter refactor changes records or ids, and the ledger's dead come back | the golden test (§11) before anything else is built |
| A rich rock wants more than 32 NPCs | wake radii differ; the probe measures the worst rock; `max_live` drops the farthest |
| `ZeroGDrift` was built to land on rock, not a moving suit | checked at step 5; if it fails, the Glinter's leap is a lunge along the surface and a shorter ambush |
| The crawler was built for a 1.3 m body; a 3 m Delver may snag | a 1.2 m collider at the head with the look trailing, if the probe shows trouble |
| The grit and shard economy is untuned and may be farmed | the clock only runs while it is live; caps per rock; first values are tuned in play |
| A Limpet-drained suit goes home by `Suit.home_step`, and two fixes to the dry suit's route (`330f1df`, `898f26b`) sit unmerged on the `quantum-energy` branch | the plan checks main's behaviour before relying on it |
| A placed salvage cloud's centre across a save | it is re-registered whenever its rock comes into detail; only the ledger is saved; `SalvageField.VERSION` is bumped only if the nest recipe changes |
| Puffs at a burrow outside | world-space particles join `Universe.HOLDS_SHIFT` (CLAUDE.md); `test_floating_origin_scene.gd` covers them |
| Left behind in a warp | a population must not assume its rocks stay loaded; creatures are freed by distance and the salvage field is suspended while warping, as the warp spec §5.2 requires |

---

## 17. Later: what batches B and C need

- **B, open space:** a free-flight locomotor (`ZeroGDrift` steered rather than ballistic), a
  population for places with no site (a region of space), and a distance rule that is not a rock's.
  The Motes reuse these as one NPC drawn as one mesh. The Atoll needs riding something that moves.
- **C, the food chain:** NPCs perceiving other species (today a creature perceives only the player,
  lights and its own group), a predator behaviour scored from a prey percept, and the lunge, which
  reuses the leap. `RockLife` already puts skitters and a Trapjaw on one site.

---

## 18. Numbers to tune in the real scene

The glint beat (1.6 s), the ambush range (5 m) and bite (8 hp), the Delver's cycle (3–6 minutes) and
shard odds (1 in 12), the grit's value (15 QE) and the husk's (20 QE), the Limpet's drain rates
(0.4 and 0.05 QE/s) and creep speed (0.2 m/s), each species' wake radius and fade, and the group
sizes. None of them blocks the design.
