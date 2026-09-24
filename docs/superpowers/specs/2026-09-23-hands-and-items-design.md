# Hands and items — pick things up, throw them, shoot a plasma pistol

**Date:** 2026-09-23
**Status:** Design approved section by section on 2026-09-23; awaiting the owner's review of this
written spec before an implementation plan
**Depends on:** `main` at `f8823e2` (interior storeys 2.6 m tall; `InteriorBuilder.floor_y()` and
`interior_center()`), the ship interior redesign (`InteriorKit`, `InteriorProps`,
`InteriorDressing`, `InteriorPalette`)
**Relates to:** slice spec §3 (interior/exterior split), §7.5 (the avatar), roadmap Slices 2 and 3;
Planetfall §4.2 (physics layers), §10.5 (the transfer), §18 (items hook)
**Standing rules:** `docs/design/visual-style.md` governs every visual in this spec: the gloves,
the items, the bolt and the flashes.

> **Amended 2026-09-24, after the owner's first playtest.** Throwing and the plasma bolts played
> well. Three things did not, and the owner chose the fixes:
>
> 1. **Held objects floated.** The physics hold for carried items kept them in front of the eye,
>    at the orientation they were picked up in, never in the hands. **Everything you take now locks
>    into the hands**: one-handed items (pistol, mug, and now the canister, held by its neck) in
>    the right hand; crates in a socket between both hands. The physics hold, its lag and its snag
>    rule are gone (§2, §4.4, §7.2, §7.3). A held crate no longer bumps walls; it pulls back with
>    the hands instead (§8.4). Held items also freeze **static**, not kinematic: the engine steps
>    a kinematic body and writes its position back a frame behind the hand's.
> 2. **No grab.** Taking something now plays a **grab swipe** (§8.3).
> 3. **Too precise an aim.** When the ray is not on anything usable, the item **nearest the line
>    of sight** is offered (§7.2).
>
> **Amended 2026-09-24, later: the ship-and-space set.** The owner asked for more things to handle,
> "mostly props and a few uses". Twelve more items, three of them with a use, a `tool` stow class,
> a hold angle, and a status in the prompt: §4.5.

---

## 1. Why this document exists

The owner's direction: *add interactivity with world objects. The user should see their hands,
kind of like ADR1FT* (a screenshot of two white, dark-padded spacesuit gloves in the lower
corners of the view, reaching into the scene). *Many objects in the universe will be able to be
picked up and affected by physics. Start with picking objects up, dropping them and throwing
them, and a basic gun that shoots a plasma shot.*

Today the avatar is a capsule with a camera on a bare `Head` node. It can walk and sit in the
pilot seat, and nothing else in the world responds to it.

### 1.1 The pitch

You look down and see your gloves. Walk into the weapon room and a plasma pistol sits in a cradle
on the rack. Take it: your right hand closes round the grip, finger on the trigger. Walk to the
galley, take a mug off the counter, drop it on the floor, step back and shoot it. A hot coral bolt
crosses the room, lighting the walls as it goes, and the mug skids away across the floor. Put the
pistol back in its cradle. Carry a crate out of the closet and leave it in the corridor. Sit down,
burn hard, and watch it slide aft, while the mugs on the counter stay where they are.

---

## 2. Decisions taken, and why

Each was put to the owner as options with trade-offs.

| Question | Decision | Why |
|---|---|---|
| How held objects behave | ~~Physics hold for carried objects, hand-snap for tools~~ **Amended 2026-09-24: everything locks into the hands** | First choice: a carried crate stayed a real rigid body pulled toward a hold point. Playtest: it floated in front of you instead of sitting in your hands. Now a crate is held between both hands, attached like the pistol; the owner accepted that it no longer bumps walls and tucks back with the hands instead. Joint springs stay rejected. |
| What a plasma hit does | **Push and flash** | A real impulse on loose objects and a brief impact flash. Nothing takes damage; a `receive_hit` hook is left for Slice 2. Breakable objects now were rejected as scope that could clash with Slice 2's block-damage design. |
| Plasma colour | **Warm coral-amber** | Keeps the style guide's "every light is `LIGHT_WARM`" without a rule change, and reads as *hot* against the cream cabin. |
| Do loose objects feel the ship's motion | **Yes, exactly as the avatar does; secured objects stay put** | One felt-gravity field: plating gravity plus the hull's shove at the same `shove_scale`. A crate beside you on a burn slides as you are shoved. Items stowed on racks and shelves are clamped and ignore it. |
| Can taken items be secured again | **Yes: snap back into stow points** | Racks and shelves have stow points; drop a held item near a free one it fits and it is secured again. Gives the weapon rack a real job and lets you tidy up before a burn. "Stick anywhere" was rejected (surfaces fill with stuck objects; more to test). |

---

## 3. Architecture

Four units, each with one job. The scene bootstrap wires them together, as `flight_test.gd`
already wires the HUD.

```
ItemDefinition (.tres) ──► ItemCatalog ──► Ship stocks StowPoints once, on first load
                                                   │
Interactor ray ──► Item (interactable) ──► actor.take_item(item) ──► Grasp
                                                                       │ state, charge, used
                                                                       ▼
                                                                     Hands  (visuals only)
Grasp.use() ──► Item.use() ──► PlasmaEmitter ──► PlasmaBolt ──► push + ImpactFlash + receive_hit

MotionCoupling ──► FeltGravity (Area3D over the walkable cells) ──► every loose Item, natively
```

- **Items know nothing about avatars.** An item talks to whoever interacts with it through a
  two-method contract (§4.4).
- **Grasp is logic only; Hands is visuals only.** Grasp can be tested headless with real bodies.
  Hands reads Grasp's state and never changes it.
- **Placement stays in one place.** `InteriorDressing` already decides where every prop goes, so it
  also places the stow points those props carry. Props stay pure geometry.
- **Gravity comes from one field**, applied by the engine's `Area3D` gravity override with no
  per-item code. The same `Item` will therefore fall correctly in Planetfall's gravity well and
  float in open space, where project gravity is zero.

### 3.1 Files

```
who-knows/
  src/items/
    item_definition.gd   ItemDefinition: a Resource, one .tres per kind
    item_catalog.gd      ItemCatalog: loads data/items/ (the BlockCatalog pattern)
    item.gd              Item: RigidBody3D built from a definition; STOWED / LOOSE / HELD
    item_looks.gd        ItemLooks: the item asset library, (kit, look, size, variety) only
    stow_point.gd        StowPoint: secures one item of a given class
    item_use.gd          ItemUse: base for what an item does when used
    plasma_emitter.gd    PlasmaEmitter extends ItemUse: the pistol
    plasma_bolt.gd       PlasmaBolt: the projectile
    impact_flash.gd      ImpactFlash: muzzle and impact flashes
    hit.gd               Hit: what a hit carries, for receive_hit
  src/avatar/
    grasp.gd             Grasp: what is in your hands
    hands.gd             Hands: the first-person viewmodel
    glove.gd             Glove: one jointed glove built from InteriorKit
    hand_pose.gd         HandPose: pose data and blending, pure
  src/ship/
    felt_gravity.gd      FeltGravity: the interior's felt-gravity Area3D
  src/ui/
    reticle.gd           Reticle: the centre dot
  data/items/
    plasma_pistol.tres, mug.tres, canister.tres, crate.tres
```

Modified: `avatar.gd`, `interactor.gd`, `interior_builder.gd`, `interior_dressing.gd`,
`interior_props.gd`, `interior_palette.gd`, `motion_coupling.gd`, `camera_director.gd`, `ship.gd`,
`flight_test.gd`/`.tscn`, `project.godot`, and the tests in §13.1.

### 3.2 Physics layers

`project.godot` gains one named layer. Planetfall has reserved 4 (`terrain`) and 5
(`exterior_props`), so items take 6.

| Layer | Name | Bit | Who is on it | Who collides with it |
|---|---|---|---|---|
| 2 | `interior_geometry` | 2 | interior structure | the avatar; items; bolts; the Interactor |
| 3 | `avatar` | 4 | the avatar | door triggers; items |
| **6** | **`items`** | **32** | loose and carried items | the avatar; items; bolts; the Interactor; `FeltGravity` |

- `Item`: `collision_layer = 32`, `collision_mask = 2 | 4 | 32 = 38`.
- `Avatar`: `collision_mask` becomes `2 | 32 = 34`, set in `avatar.gd`.
- `Interactor`: `collision_mask` becomes `34`.
- `FeltGravity`: `collision_layer = 0`, `collision_mask = 32`.
- Bolt, aim and tuck rays: mask `34`.

---

## 4. Items

### 4.1 The definition

```
# ItemDefinition — a Resource, one .tres per kind in res://data/items/
enum Grip { WIELD, CARRY }
@export var id: StringName
@export var display_name: String
@export var mass_kg: float
@export var size: Vector3            ## the one box collider; the look fits inside it
@export var grip: Grip               ## WIELD: in the right hand. CARRY: out front, both hands
@export var stow_class: StringName   ## which stow points accept it
@export var look: StringName         ## the ItemLooks builder
@export var use: Script              ## optional; extends ItemUse
@export var grip_point: Vector3      ## WIELD: item-local point the palm closes on
@export var use_point: Vector3       ## item-local point a use comes out of (the muzzle)
@export var hold_rotation: Vector3   ## degrees; turns it in the hands (amended 2026-09-24, §4.5)
```

**Item-local frame:** origin at the collider's centre, +y up, −z forward (the muzzle direction).

### 4.2 The starter set

| Id | Name | Grip | Mass | Size (m, about) | Stow class | Use |
|---|---|---|---|---|---|---|
| `plasma_pistol` | Plasma pistol | wield | 1.4 kg | 0.06 × 0.16 × 0.24 | `sidearm` | `PlasmaEmitter` |
| `mug` | Mug | wield | 0.3 kg | 0.09 × 0.10 × 0.09 | `small` | — |
| `canister` | Canister | wield (by its neck; amended 2026-09-24) | 4 kg | 0.16 × 0.34 × 0.16 | `small` | — |
| `crate` | Crate | carry | 12 kg | 0.45 × 0.35 × 0.35 | `crate` | — |

Sizes are pinned in the plan by rendering the looks. Twelve more items join the set in §4.5.

### 4.3 The looks

`ItemLooks.build(kit, look, size, variety)` dispatches to one static builder per look. Like
`InteriorProps`, it builds from kit primitives in flat palette colour, centred on the origin and
inside `size`, and **never sees the grid**.

- **Plasma pistol:** a chunky bevelled `GUNMETAL` body and grip, a barrel tube, `TRIM` and `BELT`
  accents, a lit `CORAL` charge light on the glow batch.
- **Mug:** a faceted tube with a handle, `TRIM` with a `BELT` band.
- **Canister:** an `OLIVE` tube with `TRIM` caps.
- **Crate:** a bevelled box in the colours `InteriorProps.shelves` already gives its drawn crates,
  with `BELT` straps.

Every item uses `InteriorMaterials.props()` and, for lit parts, the glow batch: no new material or
shader. The kit puts them on render layer 2, like every interior prop.

### 4.4 The Item node

`Item` extends `RigidBody3D`. `setup(definition, variety)` builds the look into its own small
`InteriorKit` and one `CollisionShape3D` box of `definition.size`, and instantiates
`definition.use` as a child if it is set. Call it before the item enters the tree.

- **Physics:** mass from the definition; a `PhysicsMaterial` with friction 0.5 and bounce 0.15;
  `continuous_cd = true`. Walls are 0.1 m slabs, and a 12 m/s throw moves 0.2 m per tick.
- **Lift limit:** `Item.LIFT_LIMIT_KG = 40.0`, what one person can pick up.

**States:**

| State | Body | Feels the field | Collides |
|---|---|---|---|
| `STOWED` | frozen (`FREEZE_MODE_STATIC`) at its stow point | no: it stays put | yes |
| `LOOSE` | dynamic | yes | yes |
| `HELD` | frozen (`FREEZE_MODE_STATIC`), parented to the right hand's `wield_socket` or, for a crate, the `carry_socket` between both hands (amended 2026-09-24) | no | no: `collision_layer = 0` |

**The interactable contract.** `Item` joins group `interactable` and implements:

- `prompt_text()`: *Take Plasma pistol* when stowed, *Pick up Crate* when loose, *Too heavy*
  above the lift limit.
- `can_interact(actor)`: `false` while held; otherwise `actor.can_take_item(self)` if the actor
  has that method.
- `interact(actor)`: calls `actor.take_item(self)` if the actor has that method.

`Avatar` implements `take_item` and `can_take_item` by forwarding to its `Grasp`. That is the whole
of what an item knows about who holds it.

- `use(aim: Transform3D, world: Node3D) -> bool` forwards to the use behaviour; it returns false
  when there is none or it declined (cooling down).

**Where items live.** `Ship` creates `Interior/Items` in code, and every item is its child whenever
it is not wielded. Interior rebuilds never touch it (§5.3).

### 4.5 The ship-and-space set (amended 2026-09-24)

Twelve more items. Most are props to pick up, carry, throw and put back; three do something.

| Id | Name | Grip | Mass | Size (m) | Stow class | Use | Where it lives |
|---|---|---|---|---|---|---|---|
| `toolbox` | Toolbox | carry | 8 kg | 0.50 × 0.26 × 0.20 | `crate` | — | closet shelves |
| `spare_helmet` | Spare helmet | carry | 2.5 kg | 0.34 × 0.34 × 0.36 | `crate` | — | closet, narrow shelves |
| `power_cell` | Power cell | wield | 2 kg | 0.10 × 0.18 × 0.10 | `small` | — | closet shelves |
| `o2_tank` | O2 tank | wield | 5 kg | 0.13 × 0.40 × 0.13 | `small` | — | closet, narrow shelves |
| `spanner` | Spanner | wield | 0.8 kg | 0.06 × 0.025 × 0.30 | `tool` | — | closet shelves |
| `spare_module` | Spare module | wield | 0.5 kg | 0.18 × 0.03 × 0.12 | `tool` | — | closet shelves |
| `medkit` | Medkit | wield | 1.5 kg | 0.30 × 0.22 × 0.12 | `tool` | — | washstand bracket |
| `ration_tin` | Ration tin | wield | 0.4 kg | 0.08 × 0.10 × 0.08 | `small` | — | closet, narrow shelves |
| `rock_sample` | Rock sample | wield | 3 kg | 0.16 × 0.12 × 0.14 | `small` | — | closet shelves |
| `hand_lamp` | Hand lamp | wield | 0.6 kg | 0.06 × 0.07 × 0.22 | `tool` | `HandLamp` | closet shelves |
| `flare` | Flare | wield | 0.3 kg | 0.04 × 0.04 × 0.26 | `tool` | `Flare` | two on the ammo crates |
| `datapad` | Datapad | wield | 0.5 kg | 0.18 × 0.02 × 0.26 | `tool` | `Datapad` | the lower bunk |

**The uses.** Each extends `ItemUse`, which is now a `Node3D` so a use can carry lights and glow.

- **`HandLamp`:** use switches a warm `SpotLight3D` beam (energy 2.6, range 10 m, 22°, no
  shadows) and a glowing lens on and off. It keeps its state when dropped, stowed or thrown.
- **`Flare`:** use strikes it, once. It burns for 60 s with a flickering warm `OmniLight3D`
  (energy 1.3, range 6 m) and a coral flame, wherever it is, then goes out for good.
- **`Datapad`:** use toggles its screen, drawn with the kit's screen shader.

Every light is `LIGHT_WARM` (visual style guide §2.3): the flare burns warm, not signal red, and its
tip carries the plasma coral. The lamp and flare light layers 1 and 2, so they still light the
hull on a spacewalk. The shader budget stays three.

**`ItemUse` gains two hooks,** both with quiet defaults:

- `status() -> String`, shown in the prompt: *Pick up Hand lamp (on)*, *Pick up Flare (burning)*,
  *Take Flare (spent)*. Default `""`.
- `recoil() -> float`, the hand's kick on use. Only `PlasmaEmitter` kicks (1.0); default 0.

**The hold angle.** `hold_rotation` turns an item in the hands, in degrees about x, y and z. A
one-handed item pivots on its grip point; a crate on its centre. It exists because long, thin items
held straight ahead hide behind the fist. Pinned by rendering each item at eye height:

| Item | Hold angle | Why |
|---|---|---|
| spanner | 50, 0, 0 | its head shows above the fist |
| spare_module | 30, 0, 0 | the board faces you |
| medkit | 60, 0, 0 | held out in front, lid up, not hanging out of view |
| hand_lamp | −6, 5, 0 | the beam lands on the reticle at a few metres |
| flare | 60, 0, 0 | held up like a torch |
| datapad | 55, 0, 0 | the screen faces you |
| spare_helmet | −35, 0, 0 | carried with the visor toward you |

**The `tool` stow class** (`InteriorProps.STOW_CLEARANCE` 0.14 m) holds flat, one-handed things.
New spots, each published by its prop in its own frame (§5.2):

| Prop | New spots |
|---|---|
| `shelves` (1.7 m) | a `crate` on the lowest tier; 3 `small` on the second tier; 3 `tool` on the third |
| `shelves` (0.85 m) | 2 `small` on a middle tier; a `crate` on the lowest tier |
| `bunks` | a `tool` on the lower mattress; the upper bunk now has its own collider |
| `washstand` | a `tool` on a new bracket 1.15 m up |
| `ammo_crates` | 2 `tool` on the lids |

**Stocking from lists.** `InteriorDressing` stocks each shelf spot by cycling a list per stow class,
so the closet holds a mix, and the spots that already existed keep their old stock:

- 1.7 m shelves: `small` canister, canister, power cell, power cell, rock sample; `crate` crate,
  toolbox; `tool` spanner, spare module, hand lamp.
- 0.85 m shelves: `small` canister, O2 tank, ration tin; `crate` spare helmet.

---

## 5. Stow points and stocking

### 5.1 StowPoint

```
# StowPoint extends Node3D — group &"stow_point"
@export var accepts: StringName   ## a stow_class
@export var stock: StringName     ## item id to stock on first load, or &""
var item: Item                    ## the occupant, or null
func fits(candidate: Item) -> bool    ## free, and candidate's stow_class == accepts
func secure(candidate: Item) -> void  ## moves it to this transform; STOWED; frozen
func release() -> Item                ## LOOSE (or about to be HELD); unfrozen
```

The point's transform is the stowed item's transform: the item's origin sits on it, axes aligned.

### 5.2 Props publish their spots

A prop that holds items publishes its spots **in its own frame**, as a constant or a pure function
of its arguments, and leaves those spots clear of its own geometry. It never creates nodes itself.
`InteriorDressing` places a `StowPoint` at `f * spot` under the dressing root, the way it already
places `SlidingDoor`s:

| Prop | Spots | `accepts` | `stock` |
|---|---|---|---|
| `weapon_rack` | 2 pistol cradles | `sidearm` | `plasma_pistol` |
| `galley_counter` | 2 on the worktop | `small` | `mug` |
| `shelves` (1.7 m, feature) | 2 on a middle tier; 1 on the lowest tier | `small`; `crate` | `canister`; `crate` |
| `shelves` (0.85 m, secondary) | 1 on a middle tier | `small` | `canister` |

The cradles are drawn by `weapon_rack` as new geometry. Shelves stop drawing their seeded decor
crates wherever a spot is. Exact frames are pinned by rendering (§13.2).

### 5.3 Stocking and rebuilds

- **`Ship` loads an `ItemCatalog`** in `_ready`, as it does the block catalog.
- **Stocking happens once:** after the first build, every stow point with a `stock` id gets a new
  `Item` from the catalog, secured in place. Later rebuilds never stock again.
- **On a rebuild,** each `STOWED` item re-seats into a new stow point within 0.05 m that accepts
  it. If none exists, the item comes loose where it is.

Any ship built from any blueprint therefore arrives with stocked racks, including, in Slice 3,
the ships you board.

---

## 6. The felt-gravity field

`FeltGravity` extends `Area3D`. `InteriorBuilder` owns one; the node persists across rebuilds and
only its shapes are replaced.

- **Shapes:** one `BoxShape3D` per walkable cell, `CELL_SIZE × STOREY_HEIGHT × CELL_SIZE`, at
  `InteriorBuilder.interior_center(coord)`. Adjacent boxes touch, so the field is continuous
  through doorways.
- **Override:** `gravity_space_override = SPACE_OVERRIDE_REPLACE`, not a point source.
  `set_felt(accel)` sets `gravity = accel.length()` and `gravity_direction = accel.normalized()`,
  or `gravity = 0` below 1e-4.
- **Driven by `MotionCoupling`,** which already computes the avatar's shove each tick:

  ```
  shove = −accel_local × shove_scale
  avatar.external_accel = shove                                   # unchanged
  felt_gravity.set_felt(Vector3.DOWN × InteriorBuilder.DEFAULT_GRAVITY + shove)
  ```

  You and a loose crate feel identical forces. `MotionCoupling` reaches the field through the
  `InteriorBuilder`.
- **Friction sets the feel:** with friction 0.5, a full burn (about 5.7 m/s² felt on the starter
  shuttle) slides loose items aft, and gentle manoeuvring does not. Tuned at playtest together with
  `shove_scale`.

**Two gotchas it handles:**

1. **Resting bodies sleep and ignore a change of gravity.** Whenever the felt vector has moved by
   more than 0.5 m/s² since the last wake, the field wakes every unfrozen body it overlaps.
2. **An item could still tunnel out.** Each tick the field records where each overlapping `LOOSE`
   item is. If a `LOOSE` item leaves the field entirely (`body_exited`, which fires only when no
   shape overlaps any more), it is put back at its last recorded position, at rest. This is a
   safety net, not a mechanic.

Per-cell plating (zero-g rooms) is a hook (§15). Today every starter cell is plated, and the
avatar ignores plating too.

---

## 7. Grasp

`Grasp` extends `Node` and is a child of `Avatar`, which creates it in code. It holds one item at
a time.

```
enum Mode { EMPTY, CARRYING, WIELDING }
signal changed                # mode or item changed
signal used(item: Item)       # a use happened: recoil
var mode: Mode
var item: Item
var charge: float             # 0..1 while winding up a throw, −1 otherwise
var first_person: bool        # set by the bootstrap from CameraDirector
var wield_socket: Node3D      # the right glove's grip; a plain Node3D in tests
var world_root: Node3D        # where released items go: Interior/Items
```

### 7.1 Controls

| Input | Action | Binding |
|---|---|---|
| `interact` (F) | Take the item you are looking at. Hands must be empty | existing |
| **`use`** | Use the wielded item: fire the pistol. Nothing for an item with no use | left mouse |
| **`throw`** | Hold to wind up, release to throw. A tap is a gentle toss; full charge in 0.8 s | right mouse |
| **`drop`** | Drop. Stows instead if a stow point fits (§7.4) | G (physical keycode 71) |

The new actions are added in the `Object(InputEventMouseButton, …)` and `Object(InputEventKey, …)`
syntax. The JSON-shaped form registers actions with no bindings (SLICE-1-STATUS, hard-won lessons).

**The re-capture click.** Today a click that re-captures the mouse also passes through as input.
`Avatar` marks it handled (`get_viewport().set_input_as_handled()`), and `Grasp` acts only while
the mouse is captured. Re-capturing the mouse never fires the gun.

### 7.2 Taking and holding

- **Prompts.** The `Interactor` ray gains the items layer, excludes whatever the avatar holds, and
  hides the prompt of any interactable whose optional `can_interact(owner)` returns false. With full
  hands, items show no prompt.
- **Forgiving aim** (amended 2026-09-24). When the ray is not on anything usable, the Interactor
  offers the usable item nearest the line of sight: within 8° of it, widened by half the item's
  largest dimension, within the 2.5 m reach, and in plain view (a ray from the eye reaches it).
  Looking straight at something still wins.
- **Taking a stowed item** calls `StowPoint.release()` first.
- **Everything goes into the hands** (amended 2026-09-24). The item freezes static, its layers go
  to 0, and it is reparented: a one-handed item to `wield_socket`, so that `grip_point` sits on the
  socket; a two-handed item to `carry_socket`, centred on it with its near face on it. Either way
  item −z points along the view and it moves and turns exactly with the view.
  `Grasp.taken(item, from)` reports where it came from, for the grab swipe.
- **Holding ignores the holder:** collision exceptions both ways, item and avatar, while held.

### 7.3 Releasing

- **Drop:** the item is released where it is in the hands, with the avatar's velocity.
- **Throw:** speed = `lerp(3, 12, charge) × clamp(sqrt(5 kg / mass), 0.35, 1.0)` m/s along the aim,
  plus the avatar's velocity. The mug, pistol and canister leave at up to 12 m/s, the crate at
  about 7.7, a 40 kg item at about 4.2. While winding up, the throwing hand, or both hands for a
  crate, draw back by `0.12 m × charge`.
- **Items leave from a point proven clear:** a ray from the eye to the item. If it is blocked
  (tucked against a wall), the item is released short of the hit by 0.15 m plus half its largest
  dimension.
- **No pop on release.** The collision exception with the avatar stays until the item no longer
  overlaps the avatar's capsule, for at most 1 s, so a dropped item does not burst out of your legs.
- Released items are reparented to `world_root` (unless stowed) and become `LOOSE`.

### 7.4 Stowing

On `drop`, if a free `StowPoint` that fits the held item is within **0.5 m** of where the eye ray
hits within the Interactor's 2.5 m reach, the item is secured there instead of dropped: you aim at
the cradle, the shelf or the counter. While a stow would happen, Grasp's prompt reads *[G] Stow*. A throw never
stows.

### 7.5 Walking into things

After `move_and_slide()`, `Avatar` pushes each unfrozen rigid body it touched with a force along
the contact of up to **150 N** (an impulse of `150 × dt` per tick), scaled by how fast it was
walking into it. You nudge crates along the floor instead of stopping dead against them.

### 7.6 Other modes

- **Control disabled** (seated now; the airlock cycle later): Grasp does nothing.
- **Sitting down:** on `CameraDirector.piloting_changed(true)`, a carried item is dropped where it
  is. A wielded item stays in the hand and is hidden with the hands.
- **Third person:** take, carry and drop still work, because the hold point and aim come from the
  head, not the camera. `use` and `throw` work only in first person, where the reticle means
  something.

---

## 8. The hands

### 8.1 Where they live

`Hands` extends `Node3D`; `Avatar` creates it under its camera. It is shown only in first person
on foot, and hidden while seated, in third person, and during the sit and stand camera move.
`CameraDirector` gains `signal view_changed(view: View, moving: bool)`, and the bootstrap connects
it to `Hands.shown`, so `src/avatar` never learns about `CameraDirector`.

### 8.2 The gloves

Two `Glove`s, the left mirrored, in the house style: chunky, bevelled and flat-shaded, built from
`InteriorKit` primitives. Suit gloves are bulky, about 1.2 × a bare hand: the palm is about 10 cm
across.

- **Pieces:** a cuff ring; a back-of-hand plate and palm; four fingers of two segments each; a
  two-segment thumb. Each segment is its own small mesh on a pivot so it can curl: 12 meshes per
  glove, no lights.
- **Colours** (new `InteriorPalette` entries, §11): `SUIT`, a warm off-white glove as in the
  reference; `SUIT_PAD`, dark padding on the knuckles and finger backs; the ship's terracotta `BELT`
  stripe round the cuff, so the suit belongs to the ship.
- **Material:** `InteriorMaterials.props()`, with its faint rim. The gloves are on render layer 2
  and lit only by the room's own warm lights. If they read too dark at render, the fix is a
  lighter `SUIT` value, never an extra light.
- **Placement:** real scale, about 0.4 m ahead of the eye, low in each lower corner and slightly
  spread, as in the reference. Pinned by rendering at 1.6 m eye height.
- **The grip socket:** the right glove carries `Grip`, a `Node3D` where the palm closes. It becomes
  Grasp's `wield_socket`.

### 8.3 Poses

`HandPose` is data: `curl` for each of four fingers (0 straight, 1 fist), `thumb_curl`, `spread`,
and a `wrist` transform offset. `HandPose.blend(a, b, t)` is pure. Each frame each glove eases
toward its target at rate 12/s (`t = 1 − exp(−12 × dt)`), so pose changes flow rather than snap.

| Pose | When | Right | Left |
|---|---|---|---|
| Relaxed | idle | loosely curled, as in the reference | same |
| Reach | the Interactor is on something you can take | open, spread | open, spread |
| Carry | carrying | forward to the item's side, palm in, curl 0.5 | same, mirrored |
| Grip | wielding an item with a use | closed round the grip, index on the trigger | relaxed |
| Hold | wielding an item with no use | closed round it | relaxed |
| Wind-up | charging a throw | draws back `0.12 m × charge` | carry: same; else relaxed |
| Grab (amended 2026-09-24) | the first 40% of a grab swipe | reach, open | carry: same; else unchanged |

**The grab swipe** (amended 2026-09-24). On `Grasp.taken`, the grabbing hand, or both for a crate,
reaches out of its rest place toward where the item sat, at most 0.3 m, and back, over 0.3 s
(`sin(π t)`), open for the first 40% and then closing. The item eases from where it sat into its
socket over the same 0.3 s (`smoothstep`). If the item leaves the hands mid-swipe, the swipe lets
go of it.

In **Carry**, the hands' spacing follows the item's width, clamped to 0.2–0.5 m, so they sit at its
sides.

### 8.4 Procedural motion

These offsets stack on the pose, on the hands' root:

- **Sway:** the hands lag your mouse look through a spring, up to about 3°.
- **Bob:** a small walk bob, about 1 cm at walking pace, scaled by horizontal speed; nothing when
  still.
- **Recoil:** on `Grasp.used`, the right hand kicks 0.04 m back and 6° up, and recovers in 0.15 s.
- **Felt shove:** the hands drift by `external_accel × 0.005 m`, clamped to 0.04 m. A full burn moves
  them about 3 cm aft.
- **Tuck:** a 0.75 m ray from the eye, mask 34. With a hit at distance `d`,
  `t = clamp((0.75 − d) / 0.4, 0, 1)`, and the hands and any wielded item move `0.25 m × t` back
  and `0.1 m × t` down. They never poke through walls. This is geometry only: no depth-trick shader,
  which would break the three-shader budget.

---

## 9. The plasma pistol

### 9.1 PlasmaEmitter

`PlasmaEmitter` extends `ItemUse`. `use(item, aim, world) -> bool`:

- **Rate:** one bolt per press of `use`, at most 4 per second (`COOLDOWN = 0.25 s`). No ammunition,
  no heat.
- **Aim convergence:** a ray from the eye along the view, out to 100 m, mask 34, excluding the
  shooter and the pistol. The bolt leaves `use_point` (the muzzle) heading for the ray's hit
  point, or the ray's end, so it lands on the reticle although the muzzle is off to one side.
- **Point-blank:** if the stretch from the eye to the muzzle is blocked, the shot is an immediate
  impact where it meets the wall.
- **Muzzle flash:** an `ImpactFlash` at the muzzle, lasting 0.05 s.
- **Cap:** each emitter keeps at most 8 bolts alive; firing a ninth frees the oldest.
- Bolts are added to `world`, the interior. Returns true when it fired; Grasp then emits `used`.

### 9.2 PlasmaBolt

`PlasmaBolt` extends `Node3D`, not a physics body.

- **Motion:** 45 m/s, living 1.5 s.
- **No tunnelling:** each physics tick it casts a ray from its current position to its next
  (`PhysicsRayQueryParameters3D`, mask 34, excluding the shooter and the pistol). It cannot pass
  through a 0.1 m wall at any speed or tick phase.
- **Look:** a stretched glowing capsule 0.09 × 0.09 × 0.5 m along its travel (rendered at
  0.06 × 0.4 m first, it was a hairline by four metres), in `PLASMA`
  (§11) on the glow batch, built once and shared by every bolt. Bloom does the rest.
- **Light:** an `OmniLight3D` in `LIGHT_WARM`, energy 0.4, range 2.5 m, no shadows,
  `light_cull_mask = 2`, so walls light up as it passes.

### 9.3 On hit

- **Push:** an unfrozen `RigidBody3D` gets `apply_impulse(direction × 6.0 N·s, hit − origin)`. A
  0.3 kg mug leaves at about 20 m/s, a 4 kg canister at 1.5 m/s, and a 12 kg crate gets a solid
  nudge. Stowed items stay put.
- **Flash:** an `ImpactFlash` at the hit, facing along the surface normal: a glow burst that grows
  and shrinks to nothing in 0.15 s, with a `LIGHT_WARM` light (peak energy 0.8, range 3 m, no
  shadows, cull mask 2) fading with it. It then frees itself. The flash animates by scale, so the
  shared glow material is never modified.
- **The hook:** if the collider has `receive_hit(hit: Hit)`, it is called. `Hit` carries
  `position`, `normal`, `direction`, `impulse` and `source`. Nothing implements it yet; Slice 2's
  damage plugs in here.
- The bolt frees itself on impact or at the end of its life.

---

## 10. HUD

- **Reticle:** a small centre dot with a thin dark outline, in `HudPalette` colours, as
  `src/ui/reticle.gd`. The bootstrap shows it on foot in first person and hides it seated and in
  third person.
- **Prompts:** the existing prompt label shows the Interactor's prompt, or Grasp's *[G] Stow* when
  a stow would happen. Grasp's prompt wins while you hold something.

---

## 11. Palette additions

`InteriorPalette` gains the following; values are pinned by rendering:

| Constant | Use |
|---|---|
| `SUIT` | the glove: warm off-white |
| `SUIT_PAD` | knuckle and finger-back padding: dark, warm grey |
| `PLASMA` | the bolt, the muzzle flash and the impact flash: hot coral-amber, between `CORAL` and `AMBER` |

Adding palette entries is not a rule change. Every light in this spec is `LIGHT_WARM`.

---

## 12. Changes to existing code

- **`avatar.gd`:** creates `Grasp` and `Hands`; `collision_mask` 34; `take_item` and
  `can_take_item`; the re-capture click marked handled; pushing rigid bodies after
  `move_and_slide()`. Its plating gravity behaviour is unchanged, and a regression test pins it.
- **`interactor.gd`:** mask 34; excludes the held item; honours `can_interact(owner)`.
- **`interior_builder.gd`:** owns `FeltGravity` and rebuilds its shapes.
- **`interior_props.gd`:** the weapon rack's cradles; the spots published by the rack, counter and
  shelves; shelves leave their spots clear.
- **`interior_dressing.gd`:** places `StowPoint`s at the published spots.
- **`interior_palette.gd`:** §11.
- **`motion_coupling.gd`:** drives `FeltGravity`.
- **`camera_director.gd`:** `view_changed`.
- **`ship.gd`:** the `Items` node, the item catalog, stocking, re-seating on rebuild.
- **`flight_test.gd`/`.tscn`:** wires Grasp, Hands, the reticle and the prompt. Per CLAUDE.md, no
  `#` comments go in the `.tscn`; narrative lives in the scripts.
- **`project.godot`:** layer 6 `items`; actions `use`, `throw`, `drop`.

---

## 13. Testing

### 13.1 Automated (GUT, headless, output pristine, zero orphans)

- **`test_item_catalog.gd`:** every `.tres` in `data/items/` loads; each has an id, mass > 0, size > 0,
  a look `ItemLooks` knows, and a `use` script that extends `ItemUse` when set.
- **`test_item.gd`:** an item builds from a hand-made definition with no grid and no ship; its
  collider matches `size`; layer 32 and mask 38; `continuous_cd` on. State transitions: `STOWED` is
  frozen static, `LOOSE` is dynamic, wielded is frozen kinematic with layer 0. The prompt text for
  each state and for *Too heavy*. `can_interact` and `interact` call the actor's contract methods.
- **`test_stow_point.gd`:** accepts only its class; holds one item; `secure` snaps the transform
  and freezes; `release` unfreezes.
- **`test_interior_dressing.gd`** (extended): the weapon room emits two `sidearm` points stocked
  with `plasma_pistol`; the galley and closet emit theirs; every point sits in front of its wall.
- **`test_ship_items.gd`:** stocking fills every stocked point once; a second rebuild neither
  duplicates nor loses items; a stowed item whose point vanishes comes loose.
- **`test_felt_gravity.gd`:** one shape per walkable cell at storey height; `set_felt` sets the
  engine's gravity; a resting body wakes on a change over 0.5 m/s² and not below it; a `LOOSE`
  item moved outside the field is returned; a held or stowed one is not.
- **`test_motion_coupling.gd`** (new or extended): felt gravity equals plating plus the avatar's
  shove, from the same numbers.
- **`test_grasp.gd`**, with real bodies stepped through physics frames: take, drop and throw;
  collision exceptions added while held and removed only after separation (and by 1 s); throw
  speed scaling and direction; the snag release; *Too heavy* refused; full hands hide item prompts;
  stowing within 0.5 m and not beyond; sitting drops a carried item and keeps a wielded one;
  nothing happens while control is disabled; `use` and `throw` refused in third person; the item
  is excluded from the Interactor's ray.
- **`test_hands.gd`:** `HandPose.blend` is exact at 0 and 1 and linear between; the pose chosen for
  each Grasp mode; shown and hidden per view and during moves; tuck retracts in front of a wall and
  not in open space; the right glove's grip socket exists.
- **`test_plasma.gd`:** a bolt hits a 0.1 m slab from a spread of starting offsets within one tick
  (no tunnelling); ignores its shooter and pistol; pushes a rigid body along its direction with the
  right impulse; leaves a stowed item still; calls `receive_hit` when present; expires at 1.5 s;
  the emitter's rate limit and cap of 8; aim convergence onto the eye ray's hit; the point-blank
  case impacts at once.
- **`test_avatar.gd`** (new or extended): plating gravity unchanged; the re-capture click is marked
  handled; walking into a loose item moves it.
- **`test_visual_style_rules.gd`** (extended): `PAINTING_FILES` gains `item_looks.gd`, `glove.gd`,
  `hands.gd`, `plasma_bolt.gd`, `impact_flash.gd` and `stow_point.gd`; `REUSABLE_FILES` gains
  `item_looks.gd`, `item.gd`, `glove.gd` and `hands.gd`. The shader set is still exactly three.
- **`test_input_map.gd`** (extended): `use`, `throw` and `drop` are registered, bound, and bound to
  left mouse, right mouse and G.

### 13.2 Runtime and visual verification (mandatory)

- **`.tscn` edits:** load the real scene and read the edited properties back at runtime. A clean
  load proves nothing (CLAUDE.md).
- **Renders at 1.6 m eye height,** sent to the owner: idle hands in the corridor; reaching at the
  weapon rack; wielding the pistol; a bolt mid-flight lighting the corridor; an impact flash;
  carrying a crate out of the closet; the stocked rack, counter and shelves.
- **Shaders:** run once without `--headless` and check for `SHADER ERROR`. There are no new
  shaders, but there is new use of the glow shader.
- **Frame rate:** at least 120 fps at 1280 × 720 on the GTX 960, with eight bolts in flight.

### 13.3 Manual playtest checklist

- Take the pistol from the rack; fire at walls, at a loose mug, at a stowed mug; put the pistol
  back in its cradle.
- Take a crate; carry it through a doorway; snag it on the frame and see it drop; throw it at full
  charge and with a tap.
- Leave a crate and a mug loose in the corridor; sit; burn hard; see them slide aft while the
  stowed items stay put.
- Walk into a loose crate and nudge it along.
- Face a wall with the pistol: the hands tuck and never clip. Shoot point-blank.
- Toggle third person with V: no floating hands; carrying still works.

---

## 14. Risks

| Risk | Mitigation |
|---|---|
| The physics hold jitters against walls | The force cap limits how hard it pushes; the snag rule lets go; tune `HOLD_RESPONSE` and `HOLD_FORCE` at playtest |
| Rigid-body CCD quality depends on the physics engine | `test_plasma.gd` covers bolts; `test_grasp.gd` pins that a full-strength throw does not pass a 0.1 m wall; `FeltGravity`'s return is the net |
| Gloves read too dark in the dim cabin | A lighter `SUIT` value, verified by render; never an extra light |
| A wielded item clips at extreme angles | Tuck covers the common case; residual clipping at the screen edge is accepted |
| Loose items slide too much or too little on burns | Friction and `shove_scale` are tuned together at playtest |
| Bolt and flash lights cost frame time | A cap of 8 bolts per emitter; flashes last at most 0.15 s; measured (§13.2) |

---

## 15. Hooks left deliberately open

- **Damage:** `receive_hit(hit: Hit)` is where Slice 2's damage and Slice 3's gunplay attach.
- **Loot and inventory:** `ItemDefinition` is the unit, which Planetfall's supply-cache manifests
  (Planetfall §18) can take literally.
- **Droids:** `Grasp` is a component with no player-only code except its input; a droid could use
  one.
- **Stepping outside:** a wielded item travels with the avatar because it is parented to the hands.
  A carried item can be moved with the same transform maths as Planetfall §10.5. Items are on render
  layer 2; outside they need layer 1, switched at the transfer.
- **Zero-g rooms:** `InteriorBuilder` already computes per-cell plating. Unplated cells can get a
  field of shove only.
- **More kinds:** a new item is a `.tres`, a look and optionally a use: tools, scanners, lamps.

---

## 16. Non-goals

- Damage, health and destruction (only the hook).
- Ammunition, heat, reloading, aim-down-sights, automatic fire.
- Inventory, holsters, dual-wielding, holding two items.
- Audio (the project has none yet).
- Hands while seated; a third-person body.
- Zero-g rooms or zero-g movement.
- Carrying items through the airlock; grabbing anything outside the ship. *Amended 2026-09-24 by
  `docs/superpowers/specs/2026-09-24-airlock-design.md` §7.4: whatever is in your hands goes out and comes back with you, switching render layers;
  outside your hands are idle (`Grasp.suspended`). Items in space are still out of scope.*
- NPCs or droids using items.

---

## 17. Amendments to other documents

Applied in the implementation, together with the code they describe:

- **`docs/design/visual-style.md`:** §4 gains *A new item* (a `.tres`, an `ItemLooks` builder with
  palette colours, a render); §5's enforced-file lists grow as in §13.1; §3's conventions note
  physics layer 6 for items.
- **Slice spec §2:** a note that handheld items and a first handheld weapon are pulled forward from
  Slice 3's gunplay, as Planetfall pulled worlds forward from Slice 6.
- **Planetfall §4.2:** layer 6 `items` joins the table; the avatar on EVA also collides with it.
  **§10.5:** the transfer list gains a note that a held item must travel with the avatar.

---

## 18. Build order

Each phase ends playable:

- **Phase A — items exist:** palette entries; `ItemDefinition`, `ItemCatalog`, `ItemLooks`, `Item`;
  layer 6; `FeltGravity` and `MotionCoupling`; spots, `StowPoint`s and stocking. *See stocked racks,
  counter and shelves.*
- **Phase B — Grasp:** input actions; take, carry, throw, drop and stow; the Interactor changes;
  walking into items; the reticle and prompts. *Throw a mug across the galley.*
- **Phase C — hands:** `HandPose`, `Glove`, `Hands`; poses and procedural motion; tuck; wield
  attach; `view_changed`. *See your hands.*
- **Phase D — the pistol:** its look, `PlasmaEmitter`, `PlasmaBolt`, `ImpactFlash`, `Hit`. *Shoot
  the mug across the galley.*

Then the final render review and frame-rate measurement (§13.2).

---

## 19. Definition of done

Launch `flight_test`. Your gloves are in the lower corners of the view, moving as you look and
walk. Walk to the weapon room and take a plasma pistol from the rack: your hand closes round it.
Take a mug from the galley counter, drop it on the floor, and shoot it: a coral bolt lights the
walls and the mug skids away. Put the pistol back in its cradle.

Carry a crate out of the closet and throw it down the corridor. Leave it there, sit down, and burn
hard: the crate slides aft while everything stowed stays in place.

The GUT suite is green with pristine output. Every render in §13.2 has been sent to the owner. The
interior holds 120 fps on the GTX 960 with bolts in flight.
