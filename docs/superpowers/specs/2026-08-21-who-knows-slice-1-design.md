# Who Knows — Slice 1: A Ship You Can Live In

**Date:** 2026-08-21
**Engine:** Godot 4.5, Forward+
**Language:** GDScript
**Status:** Approved design, ready for implementation planning

---

## 1. The game

*Who Knows* is a 3D space game about building a ship block by block, flying it yourself, and taking other ships away from the people who currently own them.

The core loop: **cripple → board → capture.** You fly your ship into a fight, shoot out an enemy's engines, then leave the pilot seat, pick up a gun, and lead your squad of droids through their airlock. You fight room to room to their Ship Core. When you reach it, the hull is yours — and so are its droids. Surviving human crew become prisoners, held in your cargo hold until you can put them down on a planet.

You do not buy ships. You take them. Fleet growth *is* the combat reward.

Your fleet, blueprints, droids, and home station persist permanently. Each **expedition** is a roguelike push into an unmapped sector: choose which ships to bring, jump node to node, and get home to bank the haul. Ships lost out there are gone for good. The empire is not.

### 1.1 The theme is a mechanic

The title is load-bearing. **Information is the scarce resource.**

- Salvaged blocks arrive **unidentified**. You know it is *a* reactor, not *which* reactor. Bolt it on and field-test it to find out. Sometimes that goes badly.
- Captured droids still carry their previous owner's memory. Wipe one for a clean servant, or keep it dirty and read the sector intel in its head.
- Human prisoners know things. That is why they are worth hauling instead of venting.
- An unexplored jump node shows you a **rumour**, not a fact.

Buying down uncertainty is a resource you spend. The honest answer to "what is out there?" is, structurally, *who knows*.

---

## 2. Slice decomposition

The full game is eight or nine independent subsystems and cannot be responsibly specified as one document. It is split into vertical slices, each independently playable.

| # | Slice | What it proves |
|---|-------|----------------|
| **1** | **A Ship You Can Live In** — block editor, derived stats, flight, walkable interior on the moving hull | The riskiest technology in the project |
| 2 | First Blood — turrets, block-level damage, crippling | Combat is readable; "crippled" feels earned |
| 3 | Boarding Party — breach, droid squad, corridor firefight, capture, prisoners | The core loop. This is the game. |
| 4 | Fleet — captured ships as AI wingmen, command wheel, hot-swap | "Amass a fleet" pays off |
| 5 | Expedition — sector node graph, jumps, banking the haul, home station, shipyard | The roguelike frame |
| 6 | Worlds — planets, footholds, conquest, faction pressure | "Conquer worlds" |

> **Amended 2026-09-23:** `docs/superpowers/specs/2026-09-23-planetfall-design.md` (Planetfall)
> pulls the first part of Slice 6 forward, ahead of Slices 2–5: small seeded worlds you can fly
> to, land on, walk out onto and explore. Footholds, conquest and faction pressure stay in Slice 6.

**This document specifies Slice 1 only.** Slices 2–6 appear as a roadmap appendix so the architecture leaves room for them.

Slice 1 deliberately front-loads the scary part. A block editor is well-understood. A person walking around inside a rigid body that is accelerating and rotating through space is not. If that does not feel good, we need to know in week two, not month six.

---

## 3. Architecture: the interior/exterior split

Everything hinges on one problem. Parenting a `CharacterBody3D` to a moving `RigidBody3D` produces sliding, jitter, and clipping the moment the ship rolls. The architecture avoids the problem rather than fighting it.

**A ship has two physical representations and one source of truth.**

```
              ShipGrid  (Dictionary[Vector3i, BlockInstance])
              the single source of truth
                    |
        +-----------+-----------+
        |                       |
   EXTERIOR                 INTERIOR
   RigidBody3D              StaticBody3D, never moves
   flies through space      parked at a fixed slot in "interior world"
   box shape per block      floors, walls, doors, navmesh
   MultiMesh hull render    where the avatar actually is
```

The exterior hull flies. **The interior never moves at all.** It sits parked at a fixed coordinate slot in a separate physics world. When you stand up from the pilot seat you are walking around a perfectly stationary room. There is no moving-floor problem because there is no moving floor.

Everything you *feel* is then applied deliberately instead of simulated accidentally. The hull's real acceleration is fed into interior space as camera shake and a shove force on the avatar. That is a tuning knob rather than a physics fight: hard burns stagger you, impacts throw you into a bulkhead, and we control exactly how much.

### 3.1 This also solves boarding

When you breach an enemy in Slice 3, their interior is slotted **adjacent to yours** in interior-world coordinates and stitched at the airlock. Two ships' interiors become one continuous walkable space. No hand-off, no loading screen, no relative motion — even though outside, both hulls are tumbling through a fight.

Interior world is therefore laid out as a grid of widely-spaced **slots**, one per loaded ship, from day one. Slice 1 uses exactly one slot. The addressing scheme costs nothing now and prevents surgery later.

### 3.2 Selling the illusion

Three things make the split invisible:

- **Stars.** Interior space has its own skybox whose orientation is driven by the hull's real transform. Roll the ship from the cockpit and the starfield rolls past the windows correctly. Nearly free.
- **The canopy.** The cockpit window is a `SubViewport` rendering the real exterior camera, slaved to the hull transform. One extra render pass, spent only where it matters — you see the actual space through the actual glass.
- **Screens.** Other windows and interior displays reuse the same viewport texture. Cheap, and "the bridge monitor showing the fight you are not flying" is atmosphere for free.

### 3.3 Consequences accepted

- Interior and exterior must stay in lockstep. One `ShipGrid` mutation rebuilds the affected cell in both. This is the main thing that can rot, so mutation goes through a single choke-point API and is covered by a parity test.
- **Combat arenas are bounded** (a few km). No floating origin and no double-precision build; single-precision floats stay accurate at that range. Long-range travel is handled by the sector map in Slice 5, not by actually flying there.
- Switching between an interior camera and an exterior camera is a world switch, and therefore a hard cut. This is normal and expected for a view toggle. The one transition that must *not* cut is sitting down (§7.3), and it happens entirely within interior space.

> **Amended 2026-09-23 (Planetfall §16):** there is still no floating origin and no
> double-precision build, but the playable space now contains worlds you fly to, not only combat
> arenas. Single precision stays accurate within about 10 km of the origin, which Planetfall's
> small worlds respect. Several worlds spread wider than that will need a floating origin, which
> belongs to the many-worlds spec. *Within* a system you fly; *between* systems, Slice 5's sector
> map remains the jump layer. Planetfall §10 also adds a second transition that must not be seen:
> leaving the ship through the airlock, which moves the avatar from interior space into exterior
> space while it is shut inside a cycling airlock.

---

## 4. Data model

```gdscript
# BlockDefinition — a Resource, one .tres per block type
id: StringName
display_name: String
category: Category            # STRUCTURE | SYSTEMS | INTERIOR
mesh: Mesh
collision_shape: Shape3D
icon: Texture2D
mass_t: float                 # tonnes
hp: int
occupancy: Occupancy          # SOLID | DECK | MOUNT
power_gen: float              # MW
power_draw: float             # MW
thrust_kn: float              # thrusters only, along block -Z
attach_faces: int             # bitmask, which faces accept neighbours

# BlockInstance — a placed block, three fields
block_id: StringName
orientation: int              # 0-23, the 24 axis-aligned rotations
hp_current: int

# ShipGrid — Dictionary[Vector3i, BlockInstance]
```

`ShipGrid` is the single source of truth. **Every mutation goes through `set_block()` or `clear_block()`**, which emit a `cell_changed(coord)` signal. The exterior mesh, exterior collision, interior geometry, navmesh, and derived stats all rebuild off that one signal. Nothing else may write to the dictionary.

### 4.1 Occupancy — the idea that makes interiors work

Every block is exactly one of three things:

- **SOLID** — machinery and armour. Fills the cell. Not walkable.
- **DECK** — open volume, floor plus 2m of headroom. Walkable. Stack two vertically for a 4m room.
- **MOUNT** — a fixture: pilot seat, ladder, console, locker, and later a turret pedestal.

The grid holds exactly one `BlockInstance` per cell, so a MOUNT **occupies its own cell** rather than nesting inside a DECK cell — you stand in the same cell as the seat. MOUNT cells are therefore walkable. The **walkable set is DECK ∪ MOUNT**, and that is the set the deck graph and Rule 4 operate on.

A ship is therefore a solid mass of machinery with **negative space carved through it** where people go. Corridors are deliberate. Every cubic metre given to a hallway is a cubic metre not generating power, and that tension is the entire ship-design game.

One block is a 2m cube — roughly a person's height plus reach. A single-cell corridor is tight, which is correct: it is where Slice 3's firefights happen.

---

## 5. Block catalogue (Slice 1)

Fifteen blocks. No weapons — those are Slice 2.

> **Amended 2026-08-23:** a sixteenth block, **Canopy** (Structure / SOLID), is added by `docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md` §7. It is the raked bow glazing, the exterior face of the cockpit `SubViewport`, and a deliberate hp weak point for Slice 2.

| Block | Category | Occupancy | Notes |
|-------|----------|-----------|-------|
| Hull Block | Structure | SOLID | Baseline mass and hp |
| Hull Wedge | Structure | SOLID | Shaping; angled faces |
| Armour Plate | Structure | SOLID | Heavy, high hp, no function |
| Ship Core | Structure | SOLID | Identity block; exactly one per ship |
| Reactor | Systems | SOLID | Primary `power_gen` |
| Main Thruster | Systems | SOLID | `thrust_kn` along block −Z |
| RCS Thruster | Systems | SOLID | Low thrust, used by the flight computer |
| Battery | Systems | SOLID | Buffers generation against draw spikes |
| Grav Plating | Systems | SOLID | Confers gravity on DECK cells within a radius |
| Deck Plate | Interior | DECK | Walkable volume, 2m headroom |
| Bulkhead | Interior | SOLID | Wall between deck cells |
| Powered Door | Interior | DECK | Walkable; barrier opens and closes |
| Pilot Seat | Interior | MOUNT | Sits in a DECK cell; the flight station |
| Ladder | Interior | MOUNT | Connects DECK cells vertically |
| Airlock | Interior | DECK | Outer hatch; inert in Slice 1 |

**Ship Core** is the ship's identity block and, from Slice 3 onward, the objective boarders must reach to capture the hull.

**Grav Plating** does quiet double duty: it is the in-fiction reason your feet stay on the deck, and it is a mass-and-power cost paid per region of deck you want walkable. Step off a plated deck into an unplated cell and you float. That is not a bug to design around — it is an engineering space you chose not to furnish, and in Slice 3 it becomes a section boarders find much harder to cross.

**Airlock** exists as geometry in Slice 1 even though nothing docks to it yet.

---

## 6. Validation and derived stats

### 6.1 Rules, checked continuously in the editor

1. Exactly one **Ship Core**.
2. Every block face-connected back to the Core.
3. At least one **Pilot Seat**.
4. **Every MOUNT is reachable on foot from the Pilot Seat.** Formally: every MOUNT cell lies in the same connected component of the deck graph as the Pilot Seat. The deck graph spans the walkable set (DECK ∪ MOUNT). Two walkable cells are connected when face-adjacent horizontally (±X, ±Z), or vertically (±Y) when at least one of the pair is a Ladder. A closed Powered Door counts as connected — doors are runtime obstacles, not layout errors.
5. Power generation ≥ power draw. *(Warning, not error — brownouts become a mechanic later.)*

Rules 1–4 are errors and block launch. Rule 5 is a warning.

Rule 4 is load-bearing. **If you cannot walk to it, you cannot use it.** That single constraint turns interior layout from decoration into engineering: the reactor room needs a door, the turret needs a crawlway, and the distance from the bridge to the aft airlock is something the player will care about intensely the first time someone breaches it.

### 6.2 Derived stats, recomputed on `cell_changed`

- Total mass and centre of mass
- Moment of inertia about each axis
- Per-axis thrust budget (forward, reverse, lateral, vertical) and resulting acceleration
- Per-axis torque budget and resulting turn rate
- **Torque imbalance** — net torque induced by a full forward burn
- Power generation, draw, and margin

All of this is cheap at 150 blocks and runs once per mutation, never per frame.

---

## 7. Flight and cameras

### 7.1 Assisted Newtonian

The hull is a `RigidBody3D` with no gravity and no damping. Momentum is real.

Thrusters are not an abstraction. Each Main Thruster applies force **at its actual position on the hull**, so engines mounted off the centreline produce genuine torque. A lopsided ship pitches over under full burn. The flight computer notices and spends RCS authority fighting it, which means a badly balanced ship is sluggish in a way you can *feel* rather than in a way a stat block tells you about. The shipyard surfaces this as a torque-imbalance warning, and learning to read it is a real skill the game teaches.

Two modes on a toggle:

- **Assist on (default)** — the flight computer counters drift, damps rotation, and holds a cruise ceiling. Forgiving and readable; the mode fights happen in.
- **Assist off** — raw Newtonian. Kill the engines, spin 180°, and burn back the way you came while still travelling forward.

Controls: `WASD` translate, mouse pitch/yaw, `Q`/`E` roll, `Shift`/`Ctrl` vertical, `Space` boost, `F` interact / leave seat, `Z` toggle assist, `V` cycle camera.

### 7.2 The four cameras

| View | Where you are | Purpose |
|------|---------------|---------|
| Cockpit | First person in the pilot seat (interior space) | Canopy `SubViewport` shows the real exterior. Cramped, immediate. |
| Chase | Behind the hull (exterior space) | Spatial awareness; admiring what you built. |
| On-foot first | Interior, eye height | Corridors. What Slice 3 lives in. |
| On-foot third | Interior, over shoulder | Navigating your own ship comfortably. |

### 7.3 Sitting down

**The money moment of the slice.** It gets a disproportionate share of the polish budget.

Pressing `F` at the pilot seat does not cut the camera. The camera **travels** — from the avatar's head, down into the seat, settling behind the canopy — while control authority hands over from legs to throttle in the same motion. Standing up plays it in reverse: the ship keeps flying, you are on your feet, and the deck is under you.

No fade. No load. One continuous move, entirely within interior space. If the transition is seamless, players will do it constantly because it feels good. If it is a cut to black, the premise reads as two separate games stapled together.

### 7.4 Standing up mid-burn

This is what the architecture buys, and it is the Slice 1 demo.

**You can leave the seat while the ship is moving.** The autopilot holds the last command. The hull's real acceleration is piped into interior space as a shove force on the avatar and a shake on the camera, so walking aft during a hard burn means stumbling downhill through your own corridor while the starfield rolls past the windows.

There are no enemies in Slice 1 and there do not need to be. *Set a burn, stand up, and walk to the back of your own moving ship* is the entire pitch.

### 7.5 The avatar

`CharacterBody3D` in interior space. Walk, sprint, crouch for crawlways, ladders between decks. A single interaction raycast drives seats, doors, consoles, and ladders through one prompt widget. Gravity is supplied by Grav Plating per §5.

---

## 8. The shipyard

A dry dock scene: the ship on a rig, orbit camera, and critically a **deck slicer** — a Z-level slider that cuts the hull away layer by layer. Without it, nobody can lay out an interior.

```
+----------+------------------------------+-----------+
| PALETTE  |                              |   MASS  42t
| Structure|        [ship on rig]         |   ACCEL 18 m/s²
| Systems  |                              |   YAW   45°/s
| Interior |     deck slice: [==|===]     |   PWR   6/8 MW
|          |                              |-----------|
|          |                              | ! Turret  |
|          |                              |   unreach-|
|          |                              |   able    |
+----------+------------------------------+-----------+
      [ WALK TEST ]   [ LAUNCH ]
```

Ghost preview follows the cursor, `R` rotates, mirror mode reflects across X. Stats update live as blocks are placed. Drop a reactor in the nose and watch the centre of mass slide forward and the pitch rate collapse — you *feel* the ship going wrong, which is the whole pleasure of a builder.

**Walk Test** drops the avatar into the interior instantly without launching. Being one keypress from standing inside the thing you just drew is what makes the loop addictive.

Blueprints save as a custom `ShipBlueprint` Resource (`.tres`) — Godot-native, diffable, inspectable.

---

## 9. Project structure

```
who-knows/
  data/blocks/*.tres              15 BlockDefinition resources
  data/blueprints/*.tres
  src/ship/                       ship_grid, block_definition, block_instance,
                                  ship_stats, exterior_builder, interior_builder, ship
  src/flight/                     flight_computer, thruster_solver
  src/avatar/                     avatar, interactor
  src/editor/                     shipyard, palette, deck_slicer, stats_panel
  src/camera/                     camera_director
  scenes/                         shipyard, flight_test, ship, avatar
  test/unit/                      GUT suite
  addons/gut/
```

Each file stays small and single-purpose. `exterior_builder` and `interior_builder` both consume `ShipGrid` and never talk to each other — two independent readers of one source of truth, which is what makes the parity test possible.

---

## 10. Testing

### 10.1 Automated (GUT)

- **Grid ops** — place, clear, orientation, face-adjacency.
- **Validation** — all five rules, each with a passing and a failing fixture. Rule 4 gets a nasty one: a mount walled off behind a sealed bulkhead.
- **Stats** — mass, centre of mass, per-axis thrust budgets, torque-imbalance detection.
- **Serialization** — blueprints round-trip identically.
- **Parity** — apply several hundred random mutations to a grid, then assert that the exterior collision set and the interior deck graph both match the grid exactly. This is the regression test for the one failure mode that could quietly rot the architecture.

### 10.2 Manual playtest checklist, run every build

Feel cannot be unit tested.

- Does the seat transition read as continuous, with no cut or hitch?
- Does the shove force during a burn feel like weight rather than like being pushed?
- Does the starfield through the canopy match what the chase camera shows?
- Does a torque-imbalanced ship feel sluggish in a legible way?
- Can a new player build a valid ship without reading anything?

---

## 11. Art direction

Flat-shaded low-poly, hard edges, a tight palette, and **emissive accents carrying the storytelling** — engine glow, deck strip lighting, the amber of a warning panel. Exteriors read as silhouettes against starfield. Interiors are lit almost entirely by practicals, so corridors are dim and pooled: costs nothing now, pays off enormously when Slice 3 puts armed strangers in them.

Sixteen blocks is a weekend of modelling, not a bottleneck.

> **Amended 2026-08-23:** the starter craft's concrete realisation of this direction — silhouette, blueprint, block meshes, palette, and the livery-stripe shader — is specified in `docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md`. Note in particular its §5.3: "dim and pooled" describes derelict and enemy interiors, not the player's own ship, which is bright and lived-in.

> **Amended 2026-09-23:** the game's standing visual style is `docs/design/visual-style.md`: stylized, warm and dim, chunky flat-coloured shapes lit by warm practicals. It refines this section. Flat shading, a tight palette and emissive accents carrying the story all still hold. It supersedes the "bright" player interior above. Derelict and enemy interiors must differ from the player's ship by colour and wear (cold or failing light, damage), not only by brightness.

---

## 12. Non-goals for Slice 1

No weapons. No enemies. No droids or crew AI. No block destruction. No atmosphere or pressure simulation. No sector map, expeditions, or persistence beyond saved blueprints. No planets. No multiplayer.

> **Amended 2026-09-23:** "No planets" remains true of Slice 1 itself. Planets arrive in
> Planetfall (`docs/superpowers/specs/2026-09-23-planetfall-design.md`), a separate slice.

The block mutation API supports destruction from day one — Slice 2 simply calls it — but nothing in Slice 1 shoots.

---

## 13. Hooks left deliberately open

Small, cheap affordances so later slices do not require surgery:

- `BlockInstance` carries per-instance state, so unidentified salvage adds a flag rather than a schema change.
- Interior world is a slot grid that can hold several ships at once, so boarding needs no restructuring.
- The Airlock block exists as geometry from the start.
- Ship Core is already the identity block, so capture has an objective to target.

---

## 14. Definition of done

Build a ship from the catalogue with live stats and validation. Save it, load it, launch it. Fly it in both assist modes, from cockpit and chase. Set a burn, stand up, walk to the back of your own accelerating ship, watch the stars roll past the window, walk back, sit down, and fly on — with no cut, no load, and no jitter. GUT suite green.

---

## 15. Risks

| Risk | Mitigation |
|------|------------|
| **Seat transition or shove force feels bad** — the premise fails | **Prototype both in week one** on a hand-built ship, before the editor exists. Cheapest possible place to learn it. |
| Interior/exterior desync | Single mutation choke point; automated parity test |
| Canopy `SubViewport` cost | Budget exactly one viewport; fall back to screens-only if profiling demands |
| Scope creep into Slice 2 | Explicit non-goals in §12 |
| Rule 4 pathfinding cost in-editor | Deck graph is a small flood fill, recomputed on mutation, not per frame |

---

## Appendix — roadmap, Slices 2 to 6

**Slice 2 — First Blood.** Turret MOUNT blocks, projectile and beam weapons, block-level damage calling the existing mutation API, shields, and a **crippled** state when thrust or power drops below a threshold. One scripted enemy. Proves combat is readable and that crippling feels earned rather than arbitrary.

**Slice 3 — Boarding Party.** Docking and hull breaching, the interior-slot stitching described in §3.1, a loadout locker, droid squad AI following the player through corridors, FPS gunplay, and capture on reaching the enemy Ship Core. Captured droids convert; surviving humans become prisoners occupying cargo mass. This is the game.

**Slice 4 — Fleet.** Captured hulls fly as AI wingmen with a small command wheel (form up, engage, disengage, board). Hot-swap between ships you own. Refit captured hulls in the shipyard.

**Slice 5 — Expedition.** Procedural sector node graph where unexplored nodes show rumours rather than facts. Jump, event, and encounter nodes. A persistent home station with shipyard, blueprint library, and prisoner drop-off. Losses in the field are permanent; the empire is not. This is also where unidentified salvage and droid-memory interrogation land, because this is the slice where information becomes scarce enough to be worth spending on.

**Slice 6 — Worlds.** Planets as strategic locations, footholds established by conquest, faction pressure responding to what you have taken, and a win condition.

> **Amended 2026-09-23:** the ground work for this slice — seeded worlds, landing, the airlock
> step-out, on-foot exploration and discoverable sites — is specified in
> `docs/superpowers/specs/2026-09-23-planetfall-design.md`, with hooks for claiming, encounters
> and many worlds in its §18.
