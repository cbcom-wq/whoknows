# Ship exterior — a hull that matches its interior, and lights to see by

**Date:** 2026-09-28
**Status:** Design approved section by section by the owner on 2026-09-28. Not built.
**Depends on:** `main` at `dfd7b91`:
- quantum energy (the core, the machine, quantum cells, low power);
- the bridge computer, whose miniature uses the hull's meshes;
- NPCs and saving;
- the star-system skeleton. It aims the sun from the star, and its space dust catches the lights.
  The star's glow, approved from renders, must be re-shown with the outside's bloom (§6.3).
**Governed by:** `docs/design/visual-style.md`, CLAUDE.md's floating-origin rule, the
`building-a-ship` skill.
**Amends, once built:**
- the starter shuttle art direction (`2026-08-23-starter-shuttle-art-direction.md`) §2 and §3:
  the starter's envelope and its cells above and below the cabin;
- the bridge computer spec §7 and §3 of its miniature (`multimeshes()` becomes `hull_meshes()`);
- the visual style guide: a new §3.6, additions to §4 and §5 (§9 here);
- the `building-a-ship` skill.

---

## 1. Why

The owner, 2026-09-28, with three pictures (two screenshots of the starter drawn over, one concept
render):

> I want to improve ship exterior design. Ideally aspects of the ships exterior matching the
> interior like windows, general shape, etc. They currently do not. Also ships should be a little
> less flat, kind of boxy is ok but there should be variation and tapering. Ships should have
> exterior lighting able to be controlled from the inside. Flood lights to illuminate beneath and
> around the ship and separately controlled forward lights to illuminate to the front.

On the lights, asked whether beams should show:

> I'd really like rich lighting, however that gets done. I like the idea of flying over a dark
> asteroid or through a tunnel in an asteroid and illuminating the as we go. Like uncovering
> something unseen, uncovering a mystery and just looking cool.

The drawn-over screenshots ask for: a raised section on top, tapering toward the nose (red); lit
strips along the top edges and the nose (blue); portholes and a big window on the flank where the
rooms and bridge are (yellow); flood cones under the belly and at a corner (yellow and pale blue).
The concept render: a boxy hull with chamfered corners and stepped sections, warm-lit windows of
several shapes, white edge lights, and floods under the belly lighting the dust below. **We take
its language, not its detail:** no panel greebles, vents or texture (style guide §2.1).

### 1.1 What is wrong today

- **The hull is one mesh per block, per cell.** `ExteriorBuilder` instances each block's own mesh
  at its cell centre, in one `MultiMesh` per block type. The starter reads as a flat 4 m slab with
  square edges.
- **The cabin level shows as dark gaps.** Walkable blocks (deck, rooms, the helm, the core, the
  machine, the computer) have a 15 cm floor plate for a mesh, so nothing closes the cabin where it
  meets space. On the starter the cabin is walled by hull cells on the flanks, but not below.
- **Nothing outside reads the interior.** The rooms' portholes, the bridge's shoulder windows and
  the wraparound cockpit pod, which juts 1.9 m out through the canopy, have no counterpart on the
  hull. The canopy block is always a glass wedge, whatever the interior made of it. The one
  exception is the airlock, whose room has a copy on the hull (`AirlockAlcove`).
- **There are no lights outside** except the airlock's arch and the running-light cyan on its
  hatch.
- **The outside is never dark.** The world environment takes its ambient from the procedural sky,
  so a rock's night side is a mid grey. A light has nothing to uncover.

### 1.2 What this adds

- **A skin:** the hull is generated as one surface over the grid, with chamfered edges and
  bevelled plates, the same way the interior is generated.
- **Fairings:** six light shape blocks that let any blueprint taper and step.
- **A reshaped starter:** a raised dorsal spine sloping to the nose, a shallow keel, tapered pods.
- **Windows that match:** every interior window has one on the hull, at the same height; the pod
  and the shoulders are drawn as they are inside.
- **Lights:** floods under and around the ship and a forward pair, placed by the generator,
  switched from the helm or a panel on the bridge.
- **A darker outside, with shadows, beams and bloom,** so the lights uncover things.

### 1.3 Not in this design

- **Tunnels in asteroids.** None exist. The forward lights are sized for them (§6.2).
- **Light blocks** a builder places by hand. The generator places every light (§2, row 4). If the
  shipyard needs them, they come with its own spec.
- **A real view into the interior from outside.** Windows glow instead (§2, row 3).
- **Dust kicked up by the floods** near a surface, as in the concept render. A later tuning pass
  may add it with the airlock's `Puffs`.
- **The bubble canopy** (style guide §3.3), still a later pod variant.

---

## 2. Decisions

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | May the starter's blueprint change? | **Yes, outside the cabin.** Cells above and below the cabin and at its ends may change. The cabin, bridge, rooms, airlock and every walkable cell stay exactly as they are. | The owner's choice. Less flat needs cells, and moving the interior would unsettle the helm, the pod, the core and the computer, all just placed. |
| 2 | Where does shape come from? | **Both:** the generator chamfers every exposed convex edge of any blueprint, and new **fairing** blocks let a builder taper on purpose. | The owner's choice. Every blueprint looks less boxy for free; a deliberate taper needs a block. |
| 3 | What does a window show from outside? | **Warm lit glass:** dark amber glass with soft `LIGHT_WARM` bands behind it, dimming with the ship. | The owner's choice. The interior is 5 km away in its own space; seeing in would be another render per window. |
| 4 | How do lights get onto a ship? | **The generator places them** from the skin. No new blocks. | The owner's choice. Every blueprint gets lights. |
| 5 | How are they switched? | **Both:** two keys at the helm, and a two-button panel on the bridge, driving one state. | The owner's choice. |
| 6 | What colour are they? | **Decided at the renders:** warm white against cool white, from the real scene. | The owner's choice. Interior light is `LIGHT_WARM`; the running lights are cyan; the concept has cool floods. |
| 7 | Beams? | **Rich light, however it gets done:** shadows on the forward lights, a darker outside, faint beam cones, bloom outside, and a measured spike on real light shafts (§6.4). | The owner, quoted in §1. |
| 8 | How is the hull built? | **The interior's pipeline, outside:** a pure `HullLayout`, a `HullDressing` that maps its faces to grid-blind `HullProps`, built with `InteriorKit`. | One pattern for both halves of the ship. `InteriorKit` already builds on the hull for the airlock alcove. Per-block auto-tiling was rejected: its variants multiply, it leaves internal faces, and it can't cut windows cleanly. A hand-built hull breaks the blueprint rule. |

---

## 3. The skin

### 3.1 `HullLayout`

A pure `RefCounted`, like `InteriorLayout`: `HullLayout.plan(grid, catalog, interior_layout)`.
It touches no nodes, and tests call it with a bare grid.

**The skin** is every face of an occupied cell whose neighbour across that face is empty. It
covers every block, walkable ones included. A walkable cell open to space gets a skin face like a
solid one, which closes the dark gaps of §1.1. Faces between two occupied cells are never drawn.

Each skin record is `{coord, normal, kind, ...}`. The kinds:

| Kind | Where | Drawn as |
|---|---|---|
| `PLATE` | every skin face of a cube-shaped block | a bevelled panel, inset from any chamfered edge |
| `EDGE` | where two skin faces of the same or neighbouring cells meet at a **convex** edge | a 45° chamfer strip, `CHAMFER` wide |
| `CORNER` | where three chamfered edges meet | a triangular facet closing them |
| `SLOPE` | the sloped face of a fairing (§4) | a bevelled panel on the slope |
| `WINDOW` | a skin face an interior window looks out through (§5) | a plate with a window in it |
| `POD` | the canopy face of a cockpit pod (§5.2) | the pod shell |
| `AIRLOCK` | the faces of a cell with an `AirlockAlcove` | nothing: the alcove draws them |
| `MOUNT` | a light's mount (§6.1), recorded beside the face's own kind | a light fixture |

- **Concave edges** get nothing: two plates meet in the corner.
- **An edge next to a fairing's slope** gets no chamfer. The slope already turns the corner.
- **An edge next to the airlock** stops short, so the alcove's hatch face stays flat.
- **Thruster and RCS cells** are skinned like any cube, and their props (§3.3) sit over the face
  their exhaust leaves by.

### 3.2 The numbers

| Name | Value | Note |
|---|---|---|
| `CHAMFER` | 0.4 m | measured along each face from the edge; the strip is 0.57 m across |
| `PLATE_PROUD` | 0.05 m | how far a plate stands off the cell face |
| `PLATE_BEVEL` | 0.04 m | the plate's own bevel (under half the plate's 0.1 m depth, or its edges collapse) |
| `PLATE_GAP` | 0.04 m | between neighbouring plates |

A plate is inset by `CHAMFER` on each side that has a chamfered edge, and by `PLATE_GAP / 2`
elsewhere. Plate sizes and the chamfer are pinned at the first renders and may move there.

### 3.3 `HullDressing` and `HullProps`

- **`HullDressing`** maps each skin record to a `HullProps` builder, in a **skin frame**: origin at
  the face's centre on the cell face, +z along the face's outward normal (out of the hull), +y up
  the face (or toward the bow on a roof or belly face), +x across. The pod shell keeps the interior's
  pod frame (−z out into the pod), so both are built from the same numbers. It commits one `InteriorKit` per
  ship: layer `OWN_HULL_LAYER`, light mask `1 | OWN_HULL_LAYER`, the own-hull body for colliders.
- **`HullProps`** builds from `(kit, frame, variety)` and never sees the grid, the layout or the
  dressing (style guide §3):
  - `plate`, `chamfer_strip`, `corner_facet`, `slope_plate`;
  - `window_porthole`, `window_shoulder`, `pod_shell` (§5);
  - `thruster_bell`: a chunky bevelled bell with a `RUNNING_LIGHT` glow ring inside, on the aft
    face of a `thruster`;
  - `rcs_pod`: a small bevelled block with a round nozzle on the exhaust face of an `rcs`;
  - `flood_fixture`, `forward_fixture` (§6.1);
  - `running_strip` (§5.4).
- **Materials:** plates and strips use the hull livery material (`hull_livery.tres`), so the stripe
  runs across the new skin as it does today. Trim, frames, bells and fixtures use flat
  `StandardMaterial3D` in `HullPalette` colours. Lit pieces go in the kit's glow batch.
- **Batches:** one merged mesh per material. On the starter that is about a dozen draw calls, fewer
  than today's one per block type plus the alcove.

### 3.4 `ExteriorBuilder`

- It keeps building the colliders and the airlock alcoves, and calls `HullLayout` and
  `HullDressing` for the meshes. Its per-block `MultiMesh`es go.
- **Colliders:** cubes keep one box per cell. A 0.4 m chamfer is too small to matter against rocks
  or a spacewalker. **Every shaped block** (fairings, and `hull_wedge` and `canopy`, which are the
  same wedge as `fairing_slope`) gets `ConvexPolygonShape3D`s matching its shape (§4). The one
  exception is a pod's canopy cell, which keeps a box: the pod shell reaches past the wedge.
- **The miniature:** `multimeshes()` is replaced by `hull_meshes() -> Array[MeshInstance3D]`, the
  dressing's merged meshes. The bridge computer's status page shares them, as it shared the
  `MultiMesh`es. `bounds()` stays.
- `rebuild()` still clears everything synchronously first (see its comments on `free()`).

---

## 4. Fairings

Six new blocks: five shapes, the long slope coming in two halves. (The approved design's "five
fairings" counted the halves as one.) They are **structure, not armour**: light shells at 0.3 t, against 1.0 t for
`hull`, so reshaping a blueprint moves its balance only a little. No power, no thrust.

| id | Shape in its cell, orientation `FORWARD` | Collider |
|---|---|---|
| `fairing_slope` | a full diagonal wedge, like `hull_wedge`: high at the back (+z), down to nothing at the front | convex, 6 points |
| `fairing_slope_long_low` | the lower half of a two-cell ramp: 0 → 1 m rise across the cell | convex |
| `fairing_slope_long_high` | the upper half: a 1 m block with a 1 → 2 m ramp on top | convex |
| `fairing_corner_out` | an outer corner: the point where two slopes meet at a convex corner (a quarter pyramid) | convex, 4 points |
| `fairing_corner_in` | an inner corner: where two slopes meet at a concave corner (not convex) | two convex slopes |
| `fairing_half` | the bottom half of a cell | box, 2 × 1 × 2 m |

- **Orientation** works as it does for `hull_wedge`, with the 24 codes of `BlockOrientation`.
- **The skin** treats a fairing's flat faces as `PLATE` and its slope as `SLOPE`. The kit draws
  them; fairing blocks carry no `mesh` of their own for the exterior.
- **`hull_wedge` stays** for old blueprints and weighs what it did. New work uses `fairing_slope`.
- **The validator** needs no new rule. Fairings are solid and must connect like anything else.

---

## 5. Matching the interior

**The rule: the outside shows what the inside made of it.** `HullLayout` reads `InteriorLayout`
(pure data: faces, pods, canopy groups, airlocks), so windows are derived from one source and
cannot disagree. `ExteriorBuilder` and `InteriorBuilder` stay independent readers of the grid; only
the hull's layout also reads the interior's layout, and it touches no interior nodes.

### 5.1 Windows

- **Which faces.** Every interior face that is a window: a porthole (a room feature's or a common
  wall's), a shoulder window, or a nose window.
- **Where on the hull.** Walk out from the interior wall along its normal until the next cell is
  empty. The interior's outer-skin rule (`InteriorLayout._is_outer_skin`) already guarantees at
  most one solid cell in between. The skin face there becomes a `WINDOW`.
- **At what height.** Interior-local equals hull-local on storey 0 (style guide §3.2). A porthole
  centred 1.45 m above the floor is at `InteriorBuilder.floor_y(cell) + 1.45` in hull space, cell
  y +0.5 on storey 0. A shoulder window runs from `SHOULDER_WINDOW_LOW` to `SHOULDER_WINDOW_HIGH`
  above the floor. The constants are `InteriorProps`', read, never copied.
- **What it looks like:**
  - a chunky bevelled frame in `HullPalette.TRIM`, standing 0.08 m proud of the plate;
  - `WINDOW_GLASS`, a dark amber `StandardMaterial3D`, slightly glossy;
  - two or three soft horizontal `LIGHT_WARM` bands just behind the glass, like ceiling strips
    seen from outside, in their own glow batch.
- **Brightness** is that batch's material's `energy`: one number for every window on the ship.
  `ShipLights.interior_level` (§7.1) sets it. Low power halves it, and nothing else touches it.
- **No new shader.** The glass is `StandardMaterial3D`; the bands use `glow.gdshader` (style guide
  §2.5). The glow batch is a second instance of its material, not a second shader.

### 5.2 The cockpit pod

A canopy face that the interior made a **pod** is drawn as `pod_shell`, not as a canopy block:

- the interior pod's own outline and heights (`InteriorProps.POD_OUTLINE`, `POD_SILL`,
  `POD_GLASS_TOP`, `POD_ROOF`), in the same pod frame (`InteriorDressing.pod_frame`), read, never
  copied;
- glass front and both flanks, sill to glass top; a solid roof with a 0.1 m lip; the hull livery
  below the sill;
- the pod's glass is `WINDOW_GLASS` with the warm bands, like any window, and dims with them.

The pod's glass top and roof sit 2.05 and 2.2 m above the floor: 0.1 and 0.25 m above the canopy
cell. **The pod shell stands proud of whatever is above it.** The skin draws the cell above as
usual and the shell's roof caps the joint. On the reshaped starter (§8) the nose slope begins at
the pod roof's lip.

### 5.3 Shoulders and noses

- **Shoulders:** a windshield's other canopy faces, which the interior makes walls with a portal
  window, are drawn as hull plate with a `window_shoulder` at the interior window's height. They
  are no longer glass.
- **A windshield with no helm** keeps the rounded nose inside. Outside it is plate with a
  `window_shoulder` for each nose window.
- **The canopy block** therefore means "whatever the interior made of this face". Its own mesh is
  no longer drawn outside.

### 5.4 Running strips

Thin cyan `RUNNING_LIGHT` strips, 0.06 m wide, always on, glow only (no light):
- along the top chamfers of the dorsal spine (on any blueprint, the highest run of roof edge,
  fore and aft);
- along the nose's side chamfers.

`HullLayout` marks them on `EDGE` records. They follow the blue lines in the owner's sketch.

### 5.5 The airlock

`AirlockAlcove` still draws its cell. The skin leaves the cell's faces (`AIRLOCK`) and stops its
chamfers short of them. Its cyan arch stays.

---

## 6. Lights

### 6.1 Where the generator puts them

`HullLayout` picks mounts from the skin. A mount is `{coord, normal, group, aim}`, with `aim` a
unit vector in hull space.

**Floods** (`group = &"flood"`):
- on the lowest downward-facing skin faces (`normal = DOWN`, the least y that has any), one at
  each corner of their footprint: for each of the four (±x, ±z) corners of those faces' bounding
  rectangle, the face nearest that corner (ties broken toward the centreline, then the bow);
- then along the centreline (the faces nearest x = 0), about every 6 m (three cells) between the
  bow and stern corners;
- **aim:** straight down, tilted 25° outward, away from the footprint's centre in the horizontal.
  A centreline flood tilts toward the nearer end, fore or aft.
- **cone:** 55°; **reach:** 40 m.
- **fixture:** `flood_fixture`: a chunky bevelled housing hung under the face, and a round lens,
  lit when on.
- **The belly** is every downward skin face within 1.5 m of the lowest, so the keel does not pull
  every flood to the centreline. Keel floods: `floor(span / 6 m)` of them, evenly spaced between
  the bow and stern corner floods.
- On the reshaped starter: **5** floods (four corners and one on the keel: the corner floods are 11.67 m apart fore and aft, and `floor(11.67 / 6)` is 1).

**Forward lights** (`group = &"forward"`):
- a pair on the bow: of the skin faces facing within 45° of forward (normal · forward ≥ 0.7), on
  the pod's row (with no pod, the lowest row that has any), within 2.5 m of the frontmost, and not
  the pod's own cell, the ones with the least and the greatest x. Each sits 0.3 m below any window
  on its face. On the starter they are the nose corners, the wedges at (±2, 0, −3), outboard of the
  shoulders;
- **aim:** forward, 5° down, 3° toed out;
- **cone:** 22°; **reach:** 220 m;
- **fixture:** `forward_fixture`: a recessed round lamp in a bevelled bezel, lit when on.
- If a blueprint has only one forward face on that row, it gets one forward light.

Every mount's aim must leave the hull: no ray from a lens along its aim hits a cell within 2 m
(tested, §10).

### 6.2 The lights themselves

- One `SpotLight3D` per mount, a child of the hull body, so it rides the floating origin with it
  (CLAUDE.md).
- **Light mask:** `1 | OWN_HULL_LAYER`, the world and the ship's own hull. Never layer 2, the
  interior.
- **Shadows:** on for the forward pair; off for floods until the spike (§6.4) says otherwise.
- **Colour:** `HullPalette.WORK_LIGHT`, chosen at the renders between a warm white and a cool white
  (§2, row 6). Both are defined for the renders, and the loser is deleted. *At the renders
  (2026-09-29): both were rendered (`renders-task12/warm`, `cool`, with side-by-sides). `WORK_LIGHT`
  stays `WORK_LIGHT_WARM`, the default, and `WORK_LIGHT_COOL` stays defined until the owner picks;
  nothing is deleted yet.*
- **Energy:** tuned at the renders so that a rock face 150 m ahead is clearly lit by the forward
  pair against the darker ambient (§6.3), and the ground 20 m below is lit by the floods.
  *At the renders the plan's defaults stood: floods 4, forward pair 16. Parked 60 m off a rock's
  night side the pair lights two overlapping discs clearly, and 20 m over one the five floods leave
  soft pools with the sun's ambient gone, with dust flecks lit in both. Nothing was blown out or
  invisible, so `ShipLights.SETTINGS` did not change.*
- **Tunnels:** the forward lights reach 220 m and cast shadows, so a tunnel's walls will light up
  ahead of you and fall into shadow behind the rim as you fly in. Nothing here needs to change
  when tunnels exist.

### 6.3 A darker outside

- **Ambient:** the world environment's ambient comes down (a fixed dim colour or a low sky
  contribution, chosen at the renders), so a rock's night side is close to black until a light
  reaches it. The sun is unchanged: sunlit faces read as they do today.
- **Bloom outside:** the world environment gets a gentle glow, so lenses, windows and running
  strips bloom in the chase view and through the canopy. The interior keeps its own environment on
  its camera (style guide §2.3).
- Both are renders-first decisions: the owner sees before and after.
- **Built (2026-09-29):** `SpacePalette.AMBIENT` `#0b0d12` at `OUTSIDE_AMBIENT_ENERGY` 0.4 as a
  colour source (was the sky), and glow on at `OUTSIDE_GLOW_INTENSITY` 0.6 and
  `OUTSIDE_GLOW_BLOOM` 0.05, all in `flight_test.gd`'s `_set_outside_mood()`. These plan defaults
  stood: the night side was near black and lit surfaces read as they did.
- **One change from the plan:** `glow_blend_mode` is **Screen** (`OUTSIDE_GLOW_BLEND`). At the
  engine's default (soft light) the bloom drew no visible halo at all round lenses and strips
  against the dark, at these intensities, and up to 1.2, or with the threshold at 0.6; it was
  invisible. With Screen a gentle halo shows round the strips, the lenses and the star.
- **The star with the bloom** (`probe_star_bloom_off.png`, `probe_star_bloom_on.png`): the star is
  still a clean disc, with a soft warm halo added and nothing else changed.
- **Measured** at 1280 × 720 on the GTX 960 (2026-09-29): standing 410–463 fps; seated 180 fps;
  seated, both groups on, 172–173 fps; seated 60 m off a rock, both groups on, nose to its night
  side, the worst view, **150 fps**; the chase view there 295–297 fps, and 20 m over a rock
  299–307 fps. All hold 120 fps with the flood shadows still off.

### 6.4 Beams, and a spike on real shafts

- **Cones:** every light gets a faint cone mesh along its aim:
  - `StandardMaterial3D`, unshaded, additive blending, the light's colour at low alpha;
  - vertex alpha falling from the lens to nothing at 60% of the reach;
    *(Tuned at the renders, 2026-09-29: the first cones read as flat, hard solids that swamped the
    ship. `HullMaterials.BEAM_ALPHA` 0.06 → **0.012**; the fade gets a mid stop, alpha 0 / 0.2 / 1 at
    v 0 / 0.5 / 1 (`BEAM_MID_ALPHA`), so it is strong at the lens and mostly gone by halfway;
    the material culls back faces (was both), which also halves the additive sum, and no beam
    vanished with the seat camera behind the lenses; and each beam mesh's `transparency` follows
    `ShipLights.exterior_level`, so low power dims the shafts with the lamps.)*
  - **proximity fade**, so a beam softens where it meets rock instead of cutting a hard line;
  - **distance fade**, so it never clutters the chase view from far away;
  - on **render layer 1**, so the canopy shows your forward beams reaching out ahead.
  - Built by `HullProps.beam_cone`, as a child of the fixture's node, shown only while its light is
    on.
- **The spike:** Godot's volumetric fog, with zero global density and a `FogVolume` inside each
  beam, gives real shafts that respect the forward lights' shadows. It is tried and measured:
  - the worst views: seated with both groups on in front of a big rock, and the chase view over one;
  - at 1280 × 720 on the reference GPU (GTX 960), counting the canopy view's second render;
  - **adopted** (in place of the cones or with them) only if the worst view holds 120 fps;
  - otherwise the cones stand, and the spike's code is thrown away.
- The spike also measures flood shadows. They are turned on only if they fit the same budget.

---

## 7. Switching them

### 7.1 `ShipLights`

A node under `Ship`, like `QuantumPlant`, alive across rebuilds.

- **State:** `floods: bool`, `forward: bool`; both start **off**. Signal `changed`.
- **`interior_level: float`**, 1.0 at full power and 0.5 in low power: the windows' brightness
  (§5.1).
- **`exterior_level: float`**, 1.0 at full power and 0.5 in low power: the lights' energy. The
  lights stay usable in low power. The quantum spec makes lights free, and a ship in trouble must
  still see.
- **`bind(mounts, fixtures)`** after every hull rebuild: it makes one `SpotLight3D` and one beam per
  mount, and turns the fixtures' lenses on or off with the state.
- **`toggle(group: StringName)`** and **`set_group(group, on)`**.
- It reads low power from the ship's `QuantumPlant` each frame, as the flight computer does.
- **Saving:** a `lights` part, `{"floods": bool, "forward": bool}`. A save without it loads with
  both off.
- **Saved ships:** a save stores the ship's layout (`Ship.to_dict()["layout"]`), and a resumed game
  builds from it. So an existing save keeps the flat starter unless it is migrated. **Decided (controller ruling, 2026-09-28, pending the owner's word):** saves are left alone; start a new game to fly the reshaped starter. Migrating a saved starter is a small follow-up if the owner wants it.

### 7.2 At the helm

- Two new input actions: **`lights_flood` on L** and **`lights_forward` on K**. Both are free today.
- `PilotControls` calls `ShipLights.toggle` while seated.
- **The controls card** is built from the input map, so the two lines appear by themselves.
  Their labels: *Floods* and *Forward lights*.
- **The HUD** shows two small indicators on its band while you fly: *FLOOD* and *FWD*, in
  `HudPalette` colours, lit when on. `VehicleTelemetry` gains `floods` and `forward`.

### 7.3 On the bridge

- **A lights panel:** two big buttons and no screen, built like the bridge computer's buttons (small
  `ReadoutPanel`s, quantum spec §14.1). Each is lit `SIGNAL_GO` when its group is on, and dim when
  off. They are labelled FLOOD and FWD in `Label3D`, style guide §2.8.
- **Where:** on a **shoulder's wall, beside its window on the side toward the pod, above the
  desk**: the starboard shoulder nearest the helm first, else the port one. A shoulder where a
  fixture stands (the bridge computer) is passed over. With no shoulder, there is no panel, and the
  helm keys still work. On the starter it is the starboard shoulder at (1, 0, −3): reachable
  standing, and in view from the seat. `InteriorDressing` places it from the wall's frame; the
  panel prop never sees the grid.
- **Sound:** a soft clunk, a new `Synth` builder, on the Ship bus. Outside, the lights make no
  sound (style guide §2.9).

---

## 8. The reshaped starter

The cabin row (y = 0) keeps every cell. Everything below is added to or changed around it.

- **A dorsal spine at y = 2**, 1 m high:
  - `fairing_half` over x = −1..1, z = −1..2 (12 cells);
  - a `fairing_slope_long_low` ramp up to it at z = −2, facing the bow, so the spine rises out of
    the roof's slope down to the pod (3 cells);
  - the same ramp facing aft at z = 3, over the stern thruster bank (3 cells).
- **The engine pods** (x = ±3) each get a `fairing_slope` on top at z = 1, rising toward the stern,
  so each pod rises from the flank instead of standing as a box (2 cells).
- **A keel at y = −1:** `fairing_half` turned over (orientation 2: the cell's upper half) under the
  centreline, x = 0, z = −3..2 (6 cells).
- **26 fairing cells, 7.8 t.** These are the first cells. The renders of the profile, checked
  against the owner's red sketch, may move them, within the balance rules below.
  Measured (Task 6): 110 blocks, 104,700 kg, centre of mass y 1.207 to 1.301; torque imbalance
  4.9% of pitch authority (was 0.4%), 0.3% of yaw, 0% of roll; power unchanged. The spine's z = 2
  row and a wider keel stay in reserve as trims if the profile changes.
- The RCS stay where they are. Only the down-firing pair's exhaust faces are open today (building-a-
  ship skill), and the reshape must keep them open.
- **Balance:** the building-a-ship checklist, steps 4 and 5:
  - zero validator issues;
  - power with margin;
  - `reverse` > 0;
  - `torque_imbalance` within 5% of `torque_budget` on every axis, trimmed by moving fairings,
    never by weakening the RCS;
  - the feel numbers re-measured and written into `_starter_grid()`'s comments and the skill's
    `reference.md`.
- **Every RCS exhaust face stays open.** The probe's `BLOCKED` count must not rise.
- **Nothing inside moves:** the interior's renders at eye height must match before and after.

---

## 9. The style guide

A new **§3.6, "The hull's outside"**, records:
- the skin: plates, the 0.4 m chamfer, corner facets, the panel line from the plate gap;
- fairings, and that a taper is a block;
- the rule that windows match the interior, and what window glass looks like from outside;
- light mounts, the two groups, and that lights never light the interior;
- the darker outside and the bloom outside.

Also:
- **§4, "Anything on the hull's outside",** points to §3.6.
- **§5:** `hull_props.gd` joins the grid-blind list. `hull_layout.gd`, `hull_dressing.gd`,
  `hull_props.gd` and `ship_lights.gd` join the no-colour-literal list.
- **§2.5 is unchanged:** no new shader.
- **§2.6** gains the measured frame times with the lights on.
- **`HullPalette`** gains `TRIM`, `WINDOW_GLASS`, `WORK_LIGHT` (and, until the renders, its two
  candidates).

The owner's approval of this design is the approval the guide requires for these changes.

---

## 10. Testing

TDD throughout. New tests:

- **`test_hull_layout.gd`**, on bare grids:
  - one cube: 6 `PLATE`s, 12 `EDGE`s, 8 `CORNER`s;
  - two cubes side by side: no face between them, 10 plates;
  - an L of three cubes: its concave edge has no `EDGE`;
  - a walkable cell open to space has skin faces;
  - a fairing's slope is a `SLOPE`, and the edge along it has no chamfer;
  - an airlock cell's faces are `AIRLOCK`, and no `EDGE` touches them.
- **`test_hull_windows.gd`**, on the starter:
  - every interior window face has exactly one hull `WINDOW`, and every hull window has an interior
    window;
  - each hull window's centre height equals its interior window's;
  - the pod shell's outline and heights are `InteriorProps`' constants.
- **`test_hull_lights.gd`:**
  - the starter has 6 flood mounts and 2 forward mounts;
  - every aim leaves the hull (§6.1);
  - floods tilt outward; forward lights point within 10° of −z;
  - every `SpotLight3D` has light mask `1 | OWN_HULL_LAYER` and is a child of the hull body.
- **`test_ship_lights.gd`:** toggling, `changed`, low power halving both levels, the save round
  trip, a missing part loading as off.
- **The helm and the panel:** the two input actions exist; L and K toggle while seated and not
  while standing; the panel's buttons toggle and light.
- **`test_starter_shuttle.gd`:** re-pinned stats, zero issues, the `reference.md` test for a new
  ship.
- **Existing tests** stay green: visual-style rules (with the new files listed), mesh winding (the
  new props are wound like the kit), the floating-origin scene test, the bridge computer's
  miniature, the RCS show.
- **`ship_probe.gd`** gains lines for skin faces by kind, windows matched, light mounts, and fps
  with each light group on.

**Renders** (style guide §6), shown to the owner at each step:
- the chase view from the four quarters, the profile, and above;
- the chase view over a big rock's night side with floods, forward lights, both and neither;
- the seated view with the forward lights on in front of a rock face;
- eye-height interiors, unchanged;
- the frame budget at each step, lights on.

---

## 11. Build order

Each step is shippable and rendered for the owner.

1. **The skin** replaces the block meshes on the unchanged starter: `HullLayout`, `HullDressing`,
   `HullProps` (plates, chamfers, corners, thruster bells, RCS pods), `hull_meshes()` for the
   miniature.
2. **Fairings and the reshaped starter:** the six blocks, their colliders, the spine, keel and
   tapers; balance re-pinned.
3. **Windows and the pod shell,** and the running strips.
4. **`ShipLights`:** mounts, fixtures, spot lights, the keys, the HUD indicators, the panel, the
   save.
5. **Rich light:** the darker ambient, bloom outside, beam cones, the volumetric spike, and the
   colour chosen with the owner at the renders.
6. **The records:** the style guide (§9), the starter art direction, the bridge computer spec's
   miniature, and the `building-a-ship` skill (checklist, *Mistakes already made*, `reference.md`,
   `ship_probe.gd`).
