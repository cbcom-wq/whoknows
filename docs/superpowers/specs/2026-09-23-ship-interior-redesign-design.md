# Ship interior redesign — design

**Date:** 2026-09-23 (rewritten the same day after two rounds of prototyping)
**Status:** Approved design, ready for an implementation plan
**Depends on:** Tasks 13–15 (grid-generated interior), commit `71643cd` (fixtures drawn, canopy
camera at the pilot's eye)
**Supersedes:** starter shuttle art direction §3.1 (cabin blueprint, Phase B), §5.2 (interior
palette); refines §5.3 and §7 item 4
**Addresses:** SLICE-1-STATUS "Reported by playtest" item 6 — the interior is plain and boring

---

## 1. Why this document exists

The cabin is a box: flat beige walls, a red-brown floor, three warm fluorescent strips, one flat
6 m windshield, and nothing in it that says *spacecraft*.

The owner's direction settled over three iterations, each prototyped and rendered:

1. "Moody, darkish, blue accents, electronics and control panels, a few small windows, a more
   rounded front." Prototyped; superseded.
2. A photo of a 1980s-television starship bridge as design inspiration: warm beige and cream,
   rounded forms, soft indirect light, glowing console bases, a curved wooden rail, black-glass
   readouts. Prototyped realistic; superseded on realism.
3. **Final: stylized, not realistic** — "fun and real enough", *Astroneer* vibes but a little more
   serious. Chunky bevelled shapes, flat colours, the reference photo's palette and shapes, and
   **dim, warm** lighting. Prototyped and approved.

Then the owner widened the scope: the ship should not be one open room. **A big open bridge at
the front; behind it a corridor with a bunk room, closet, weapon room, galley and bathroom; the
airlock at the very back.**

### 1.1 Decisions already made

- **Stylized over realistic**, for design effort and rendering cost (target GPU: GTX 960).
- **Dim, warm lighting** (chosen against a bright variant, side by side).
- **Front windows plus side portholes.** A rounded cockpit front with three small windows
  replaces the flat windshield; portholes sit in outer walls.
- **Generated, not hand-dressed.** Everything is derived from the ship grid.
- **Rooms are room blocks.** Rooms are made by placing room floor blocks; thin walls rise where
  different rooms meet and each room gets one doorway, automatically.
- **Sliding doors** that open as the player approaches.
- **The rounded front is interior-only.** The exterior hull and its canopy wedge are unchanged.
- **We borrow the reference's design language, not its ship:** no insignia, no registry, and no
  imitation of its specific display system (art direction §1.1 already says this).

### 1.2 Product context that shapes the architecture

In the planned shipyard the player does not place ships block by block: they build a **ship
blueprint**, and the ship is generated from that blueprint plus game constraints. So every piece
built here will be placed by generators, not just by the starter shuttle. **Assets must be
reusable**: props are standalone builders that know nothing about the grid; placement rules live
elsewhere; room types are grid data a generator can emit.

---

## 2. Scope

**Phase A — the style kit**, applied to today's open cabin:

- Palette, materials and lighting (§3).
- A reusable mesh toolkit and prop library (§4).
- Structural dressing and common-area wall pieces: consoles, lockers, displays, portholes, the
  airlock hatch (§5).
- The rounded cockpit nose with projected windows, a curved dash and a wooden rail (§6).
- Seat recolour, interior camera environment, removal of the old ceiling fluorescents.

**Phase B — rooms:**

- Five room blocks, partitions, one doorway per room, sliding doors (§7).
- Room furniture (§7.4).
- The starter shuttle's new cabin layout (§7.5).

**Out, deliberately:**

- Exterior changes of any kind; hull size is unchanged.
- Interactive furniture or consoles. Screens animate from `TIME`; nothing reads ship state.
- Player-chosen door placement (the existing `door` block could override later).
- GI, reflection probes, SSAO, fog, interior shadows.
- Ceiling height (1.9 m clear stays; SLICE-1-STATUS item 2 is separate).
- The shipyard's blueprint generator itself.

---

## 3. The look

### 3.1 `InteriorPalette`

`src/ship/interior/interior_palette.gd`, constants only (the `HudPalette` pattern). Every interior
colour resolves here.

| Constant | Colour | Role |
|---|---|---|
| `WALL` | `#D8C7A8` | walls, nose shell |
| `WALL_LOW` | `#9C7B63` | kick bands, door leaves, dash face |
| `TRIM` | `#EDE3D0` | pilasters, frames, console bodies, light shelf |
| `BELT` | `#B0714E` | the terracotta stripe along every wall |
| `CEILING` | `#CBBBA0` | overhead |
| `FLOOR` | `#56607A` | common deck |
| `FLOOR_BRIDGE` | `#8A5A66` | the command area's floor |
| `SCREEN_BACK` | `#1A1C23` | screen glass and bezels |
| `WOOD` | `#9A5E3A` | the dash rail |
| `LIGHT_WARM` | `#FFD9A8` | every light and lit strip |
| `AMBER` / `SKY` / `CORAL` / `LAVENDER` | `#FFB45A` / `#8CC8F0` / `#F07C5A` / `#B9A6E0` | readouts, buttons, indicators |
| `GLASS` | `(0.55, 0.75, 0.90, 0.22)` | porthole glass |
| `SEAT` | `#C4A27A` | pilot seat upholstery |

Phase B adds room floor colours and furniture colours (§7.4).

### 3.2 Materials

`src/ship/interior/interior_materials.gd` builds and caches every material.

- **Structure and props use `StandardMaterial3D`** with flat colour, roughness 0.85. Props share
  one material with `vertex_color_use_as_albedo` and a faint rim (0.15), since each prop's colour
  rides on its vertices. Structure surfaces have no rim: on a ceiling seen at a glancing angle it
  blows the whole overhead out (found in the prototype).
- **Three custom shaders, and only three**, in `data/materials/interior/`:
  - `glow.gdshader`: unshaded; vertex colour pre-scaled by energy; alpha below 1 blinks.
  - `screen.gdshader`: unshaded animated readouts, three chunky modes (bars, wave, dots).
  - `canopy_window.gdshader`: the nose shell, flat-coloured, with the projected canopy view in
    rounded window cut-outs (§6.2).
- **Glass:** transparent `StandardMaterial3D` with vertex colours, so the tint and a cartoon
  glint share a batch.

### 3.3 Lighting and environment

- One warm `OmniLight3D` per walkable cell under its round ceiling light (energy 0.35, range
  3.5). Small warm lights at consoles (0.35), hatches and doors (0.5), and one cockpit key light
  (0.5). All `light_cull_mask = 2`, **no shadows**.
- `data/environments/ship_interior.tres`, set on the interior camera only: black background,
  ambient `#4A423A` at 0.45, filmic tonemap, glow on (intensity 0.5, bloom 0.03, HDR threshold
  1.1), **no SSAO**.
- The chase camera and the canopy `SubViewport` keep the `WorldEnvironment`, so the exterior look
  does not change.

---

## 4. Architecture

```
ShipGrid ──► InteriorLayout.plan() ──► records ─┬─► InteriorBuilder   structure: colliders, walls, floors
                (what every face is)            │
                                                └─► InteriorDressing  maps records to props
                                                         │
                                                         ▼
                                   InteriorProps (reusable library) ──► InteriorKit (mesh toolkit)
```

| Unit | File (`src/ship/interior/` unless noted) | Responsibility | Knows about |
|---|---|---|---|
| `InteriorPalette` | `interior_palette.gd` | colours | nothing |
| `InteriorMaterials` | `interior_materials.gd` | builds and caches materials | palette, shaders |
| `InteriorKit` | `interior_kit.gd` | accumulates geometry into one merged mesh per material; bevel boxes, tubes, rings, discs, screens; creates lights and colliders | materials |
| `InteriorProps` | `interior_props.gd` | **the reusable asset library**: every piece, built in a local frame from `(kit, frame, seed)` | kit, palette — **never** the grid, layout or builder |
| `InteriorLayout` | `interior_layout.gd` | decides what every face is | grid, catalog |
| `InteriorDressing` | `interior_dressing.gd` | turns layout records into frames and calls props | layout, props, kit |
| `SlidingDoor` | `sliding_door.gd` | a door that opens for the avatar (Phase B) | nothing ship-specific |
| `InteriorBuilder` | `src/ship/interior_builder.gd` (existing) | structure: colliders and wall, floor and ceiling boxes; calls the dressing | layout, materials, dressing |

**The frame convention every prop uses:** origin on the wall's inner surface at floor level,
centred along the wall; +x along the wall, +y up, +z out into the room. Sizes and heights are
metres in that frame. A prop never looks outside its frame, so any generator that can produce a
frame can place it.

**Why a kit and a separate library:** the kit is plumbing (batching, primitives) and the library
is content. A future generator, such as the shipyard, a derelict or a station, reuses both
without touching layout code. It also keeps each file small enough to hold in one reading.

---

## 5. Phase A: structure and common-area pieces

### 5.1 `InteriorLayout` records

```gdscript
static func plan(grid: ShipGrid, catalog: BlockCatalog, walkable: Array) -> InteriorLayout
func faces() -> Array[Dictionary]
func canopy_groups() -> Array[Dictionary]   # {normal: Vector3i, coords: Array}
func walkable_coords() -> Array[Vector3i]
static func face_hash(coord: Vector3i, normal: Vector3i) -> int
```

A face record is `{coord, normal, kind, variant, zone, porthole, owner}`:

- `kind`: `FLOOR`, `CEILING`, `WALL` or `CANOPY` (Phase B adds `DOORWAY`).
- `zone` of the cell: `&"bridge"` if the cell is common and either has a canopy neighbour or is,
  or is next to, a MOUNT cell; else `&"common"`. Phase B adds room ids.
- `porthole`: whether the builder cuts a porthole in this wall.
- `owner`: whether this record builds the structure. It is always true in Phase A; Phase B
  partitions have two records and one owner.

Common-area wall variants, in strict priority order:

1. **`HATCH`**: an `airlock` cell's face onto vacuum.
2. **`PANEL`** (or `PORTHOLE` if outer-skin flank): any wall of a MOUNT cell, because its
   fixture stands there and nothing that protrudes may go in.
3. **`CONSOLE`**: the cell is next to a MOUNT cell, or has a canopy face.
4. **`PORTHOLE`**: a flank face (normal ±X) on the outer skin. The neighbour is empty, or solid
   with empty beyond it.
5. **`LOCKERS`** or **`DISPLAY`**, alternating by `face_hash`.

On today's shuttle this gives 4 consoles, 4 portholes, 1 hatch, and lockers or displays on the
remaining 8 walls.

### 5.2 Structure (`InteriorBuilder`)

- Collision is unchanged: one box collider per floor, ceiling and wall face.
- Visible boxes use `InteriorMaterials` flat colours: floor by zone, ceiling, wall.
- **Porthole walls:** the collider stays whole. The visible wall is four boxes around a
  0.54 m square opening centred at 1.28 m above the floor. The porthole prop's thick ring
  (radius 0.26 to 0.42) covers the square's corners, and its bore hides the gap round the glass.
  No shader trick needed.
- **Canopy faces:** a collider and no visible box. The nose shell is the canopy now. The old
  per-pane UV split (`canopy_pane_uvs()` and friends) is deleted.
- `rebuild()` ends by calling `InteriorDressing.build(layout, body, canopy_material)`. All
  dressing lives under one `Dressing` node inside the single owned body, so the existing
  `remove_child()` + `free()` clears it with everything else.

### 5.3 The prop library, Phase A

All sizes in the §4 frame. Every piece is built from bevelled boxes (chamfered edges,
flat-shaded) unless noted. Colliders go on anything more than 0.15 m proud.

| Prop | Summary | Collider |
|---|---|---|
| `wall_trim` | Pilasters (0.18 × 1.9 × 0.1) on both cell edges, one a hair smaller so the neighbours' never z-fight. Kick band, terracotta belt at 0.95 m, light shelf at 1.66 m with a warm strip above it, 45° cove to the ceiling. | — |
| `ceiling_light` | A round light: a ring frame (radius 0.30 to 0.42) and a glowing disc, plus the cell's light. | — |
| `console` | Glowing plinth, bevelled body 1.4 × 0.62 × 0.38, 45° sloped top with a screen, four chunky buttons (one blinks), a framed wall screen above, a small light. | 1.4 × 1.1 × 0.4 |
| `lockers` | Six raised bevelled doors in a 2 × 3 grid on a dark backing, each with a round indicator. | — |
| `display` | A framed screen at 1.3 m on a ledge at 1.0 m. | — |
| `porthole` | A thick ring (0.26 to 0.42, 0.09 proud), a faint warm inner rim, tinted glass with a two-streak glint. | — (wall stays whole) |
| `hatch` | Two bevelled door leaves with a belt stripe, thick posts and header, a lit strip under the header, a blinking amber indicator, a light. | — |

Screens choose their mode from the seed, so no two neighbouring screens match.

---

## 6. Phase A: the cockpit nose

### 6.1 Shell

For each canopy group, `InteriorDressing` builds a frame with its origin on the canopy plane at
floor level, +z back into the room, and asks the `nose` prop for a shell of the group's width.
The shell bulges forward into the canopy cells:

```
θ = π·u,   d(v) = D                                  (v ≤ 0.45)
                = D·sqrt(1 − ((v − 0.45)/0.55)²)     (v > 0.45),   D = 1.4 m
x = −(W/2)·cos θ,   y = 1.9·v,   z = −d(v)·sin θ
```

It is tessellated 48 × 20 with smooth normals. The shell's UV is (arc length across from the
centre line, height), both in metres, and the windows are defined in that space.

Around the shell:
- **Ribs:** four chunky ribs (0.1 wide, 0.05 proud) follow the curve between and beside the
  windows, from the dash to the ceiling.
- **Brow line:** a warm line along the curve at 1.8 m.
- **Dash:** its front edge is a shallower curve (depth 0.55) that sweeps round the cockpit.
  Walnut rail on top (radius 0.055), `WALL_LOW` face, glowing plinth underneath, flat top out to
  the shell, and three angled screen desks.
- **Alcove floor:** `FLOOR_BRIDGE`.
- **Key light.**

### 6.2 Windows

Three rounded rectangles in (across, height) metres, corner radius 0.14 and frame 0.09:
- centre: (0, 1.325) with half-size (0.9, 0.375);
- port and starboard: (∓1.95, 1.3) with half-size (0.5, 0.3).

These are constants on the prop, pushed to the shader as uniforms.

Inside a window, `canopy_window.gdshader` takes the fragment's world position minus `eye_world`
(the pilot's eye) as a view-space direction for the canopy camera. The interior is axis-aligned
with the hull and the camera looks down −Z. It projects that direction with `tan_half_fov_y` and
`aspect`, and samples the `SubViewport` there, showing black outside it. So windows of any shape
on a curve line up into one view, and the cockpit velocity marker still registers.
`flight_test.gd::_aim_canopy_view()` sets the three uniforms. The viewport stays 1536 × 512.

With no canopy material (every builder test), the dressing uses the same shader with no texture,
so the windows render black and there is never a hole.

The dash and shell sit beyond the canopy faces' colliders, which stay at the plane: the avatar
stops at the dash like a railing.

---

## 7. Phase B: rooms

### 7.1 Room blocks

Five new blocks in `data/blocks/`: `bunk_room`, `galley`, `bathroom`, `closet`, `weapon_room`.
Each is `DECK` occupancy and `INTERIOR` category, with a floor-slab mesh like `deck`.
**Mass 0.4 t and power draw 0.1 MW, identical to `deck`**, so swapping deck cells for room cells
cannot move the starter shuttle's tuned centre of mass or power budget. Real fit-out mass is a
later balance decision. The block count goes from 16 to 21.

### 7.2 Layout rules for rooms

- **Zone:** a room block's cell has its block id as its zone. Any other walkable cell is
  `bridge` or `common` as in §5.1.
- **Partitions:** a face between two walkable cells of different zones is a wall. It gets a
  record on each side, each dressed for its own zone, and the record whose coord sorts lower is
  the `owner`. Bridge and common count as the same zone, so no wall goes up between them.
- **Doorways:** each room, meaning a connected set of cells with the same room zone, gets exactly
  one. The candidates are its partition faces onto common or bridge cells, or onto any other room
  if it has none. They are ranked by:
  1. flank faces first (±X, because corridors run fore to aft);
  2. then distance from the face centre to the room's centroid;
  3. then lowest `(z, x)`.

  The two records become `kind = DOORWAY`.
- **Room walls:** each room cell picks one **feature** wall for its main furniture. It never
  picks the doorway. It prefers an outer flank wall (neighbour not walkable), then any flank
  wall, then any wall. A feature wall on the outer skin also gets `porthole = true`.
- **One secondary wall:** a 2 m cell has room for one more, smaller piece. It goes on a wall at
  right angles to the feature wall, and the record carries `feature_normal` so the dressing can
  push the piece to the far end of its wall, clear of the feature's corner. Any other wall
  keeps its trim (`PANEL`). The first render, which put a secondary piece on *every* other
  wall, had fridges, crates and shelves colliding in the corners and squeezing the floor to
  0.8 m.

### 7.3 Doorways and sliding doors

- **Structure:** the owning record builds two jamb colliders and boxes, each 0.5 m wide, leaving
  a 1.0 m opening the full 1.9 m high (the avatar is 1.8 m tall and 0.7 m wide). The opening
  never has a collider. At 1.0 m, each 0.5 m leaf fits entirely inside its jamb when open; a
  1.2 m opening would leave 0.2 m of leaf showing in the doorway.
- **`SlidingDoor`:** chunky frame posts and header, two bevelled leaves that slide 0.5 m apart
  into the wall over 0.25 s, and an `Area3D` trigger (1.2 × 1.9 × 2.4 m, `collision_mask = 4`,
  the avatar's layer)
  that opens on enter and closes when the last body leaves. The leaves are visual only.
  `SlidingDoor` knows nothing about ships, so a station can use it as it is.

### 7.4 Room furniture (props)

Room floors and furniture colours are added to `InteriorPalette`:

| Room | Floor |
|---|---|
| `bunk_room` | `#5E7A7A` |
| `galley` | `#B7A58A` |
| `bathroom` | `#8FA9B8` |
| `closet` | `#6B6A66` |
| `weapon_room` | `#4E4A52` |

Furniture colours: mattress `#6F9C9A`, gunmetal `#3A3D44`, olive `#8A9A5B`.

Secondary props are under a metre wide.

| Room | Feature prop | Secondary prop | Colliders |
|---|---|---|---|
| Bunk room | `bunks`: two tiers (0.45 m and 1.25 m) of bed frame, mattress and pillow; a single low bunk when the wall has a porthole | `lockers` (tall pair) | bunk 1.9 × h × 0.9 |
| Galley | `galley_counter`: 0.9 m counter with sink and cooktop (a glowing ring); cupboards above unless there's a porthole | `fridge` (tall, handle, indicator) | counter, fridge |
| Bathroom | `washstand`: toilet, sink, lit mirror | `towel_rail` panel | toilet and sink block |
| Closet | `shelves`: three levels with seeded coloured crates | `shelves` | shelves 0.4 deep |
| Weapon room | `weapon_rack`: chunky rifle silhouettes in slots, coral warning stripe | `ammo_crates` | rack, crates |

### 7.5 Starter shuttle layout

```
 z \ x     −1           0            +1
  −4     canopy      canopy        canopy
  −3      deck        deck          deck        ┐
  −2      deck     pilot_seat       deck        │ bridge
  −1      deck        deck          deck        ┘
   0    bunk_room     deck         galley
  +1    bunk_room     deck       weapon_room
  +2    bathroom      deck          closet
  +3    bulkhead     airlock       bulkhead
```

Everything outside the cabin (equipment deck, pods, RCS) is unchanged. Validation must stay at
zero issues, and `ShipStats` numbers must not move (§7.1).

---

## 8. Testing

GUT, `test/unit/`, output pristine. Scene edits are proven by runtime read-back (CLAUDE.md).

- **`test_interior_layout.gd`:**
  - Variant priorities, and skin and flank detection.
  - The zone rules, including `bridge` for the command area.
  - Determinism.
  - Canopy grouping.
  - Phase B: partitions have two records and one owner; each room gets exactly one doorway;
    doorway ranking; feature and porthole selection.
  - The real starter shuttle's counts in each phase.
- **`test_interior_kit.gd`:**
  - A bevelled box has 26 faces and closed winding (every triangle's normal agrees with its
    face).
  - Batches merge into one mesh per material.
  - Lights and colliders follow the layer and group conventions.
- **`test_interior_props.gd`:** every prop builds in an identity frame without error, adds
  geometry, and its colliders sit inside the frame's forward half-space. This is the
  reusability guard: props must work with no grid.
- **`test_interior_dressing.gd`:**
  - A fuzzed grid never crashes; all visuals are on layer 2 and all lights use cull mask 2.
  - Exactly one `Dressing` after repeated rebuilds, with no stale lights.
  - One cell light per walkable cell.
  - A nose exists exactly when there is a canopy group, and is never a hole.
  - Protruding props get colliders.
- **`test_interior_builder.gd`:**
  - The pane UV tests are deleted.
  - Structure counts exclude dressing colliders.
  - A porthole wall keeps a whole collider and draws four boxes.
  - A canopy face has a collider and no box.
  - Phase B: a partition is built once, and a doorway leaves an opening with no collider.
- **`test_sliding_door.gd`:** it opens on enter, stays open while any body is inside, and closes
  after the last one leaves.
- **`test_hud_scene_wiring.gd`, runtime read-back:**
  - The canopy material, its projection uniforms, and that there is one nose.
  - The old ceiling lights are gone.
  - The interior camera's environment; the chase camera has none.
  - The seat colour.
  - Phase B: the starter ship has 5 rooms and 5 sliding doors.
- **Stats guard:** `ShipStats` for the Phase B starter grid equals the Phase A one.
- **Verifying it for real:** a throwaway probe renders the real `flight_test.tscn` from fixed
  viewpoints: aft looking forward, the pilot's eye, a side wall, looking aft, and in Phase B
  inside each room. It also logs average frame time over 120 frames at 1280 × 720 on the
  GTX 960. Screenshots go to the owner.

---

## 9. Amendments to other documents

- **Art direction §5.2** is replaced by §3.1 here. **§5.3:** the player's ship is warm and dim,
  stylized. Derelict and enemy interiors must differ by colour and wear, such as failing or
  cold light and damage, not only by brightness. **§7 item 4:** canopy faces keep colliders; the
  visible canopy is the generated nose. **§3.1:** the cabin blueprint is replaced by §7.5 here.
- **SLICE-1-STATUS:** item 6 is marked addressed and points here.

---

## 10. Known trade-offs and follow-ups

- **The pilot sees less.** The eye is about 3.5 m behind the front plane, so the centre window
  covers roughly ±9° horizontally and ±5° vertically. The chase camera (V) is unaffected.
  Moving the pilot seat forward a row is the real fix, a blueprint decision left for later.
- **The canopy view is only correct from the eye.** Walking around, it shows slight parallax,
  the same class of cheat as before.
- **Portholes show stars only**, from the interior sky sphere.
- **Rooms are compact:** 2 m wide off a 2 m corridor. That suits the chunky style. A bigger
  starter ship is a blueprint and flight-balance decision.
- **Room fit-out weighs nothing yet** (§7.1).
- **Doorway placement is automatic.** A player-placed `door` block override is a natural
  shipyard follow-up.
