# Who Knows — visual style guide

**Status:** Living document. Owner-approved 2026-09-23, after the ship interior redesign; extended
2026-09-24 for the cockpit pod and portal windows (owner-approved design, `docs/superpowers/specs/2026-09-23-cockpit-pod-design.md`).
**Authority:** This is the standing rulebook for how the game looks, and interiors most of all.
Feature specs apply these rules; they do not override them. **To change a rule, get the owner's
approval first and update this document in the same change.** Code, a spec and this guide
disagreeing is a bug.
**Sources of truth in code:** `InteriorPalette` (colours), `InteriorMaterials` (materials),
`InteriorProps` (the asset library), `InteriorKit` (primitives). Everything is under
`who-knows/src/ship/interior/`.
**Background:** `docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md` records how
this look was chosen and how it is built.

---

## 1. The look in one breath

**Stylized, warm and dim.** Chunky, bevelled, low-poly shapes in flat colour, lit by warm
practical lights. The target is *fun and real enough*: the charm of *Astroneer*, a little more
serious. The ship should feel lived-in and safe, a place you come home to.

The shape and palette language comes from a 1980s-television starship bridge: warm cream and
beige, soft rounded forms, consoles that seem to float on glowing bases, a curved wooden rail,
black-glass readouts with blocks of colour. **We borrow the language, never the ship:** no
insignia, no registry numbers, no imitation of its display system.

If a new piece of work doesn't fit that paragraph, it's wrong, however good it looks alone.

---

## 2. The rules

### 2.1 Shape carries the detail, not texture

- Build from **bevelled boxes** (`InteriorKit.bevel_box`, bevel 0.01–0.05 m), tubes, rings and
  discs, flat-shaded. A visible chamfer on every edge is the house style.
- **Few, big pieces.** Four chunky buttons, not forty small ones. Three screen rows, not a
  paragraph of text.
- **Rounded where it reads:** the cockpit nose, round ceiling lights, round portholes, pilasters
  and rails. Rounded shapes are what move this from "box" to "ship".
- **No sculpted meshes, normal maps, texture art or procedural surface noise** (seams, rivets,
  grime, carpet fibre). All of those were tried in prototyping and dropped because they cost too
  much to design and to render.

### 2.2 Flat colour, from the palette only

- Surfaces are `StandardMaterial3D` in flat colour, roughness 0.85. Walls, floors and ceilings have
  **no rim light**: on a surface seen edge-on it blows out the whole ceiling. Props get a faint rim
  (0.15) so chunky shapes stay distinct from each other in dim light.
- **Every colour comes from `InteriorPalette`.** No colour literals anywhere else; a test enforces
  this (§5).
- **Warm neutrals dominate:** cream `TRIM`, beige `WALL`, taupe `WALL_LOW`, one terracotta `BELT`
  stripe round every wall. **Accents** (`AMBER`, `SKY`, `CORAL`, `LAVENDER`) belong on screens,
  buttons and indicators. They are not surface colours.
- **Floors say what a space is:** slate for common deck, mauve `FLOOR_BRIDGE` for the command area,
  one colour per room type (`ROOM_FLOOR`).

### 2.3 Light is warm, dim and practical

- Light comes from things you can see: a **round ceiling light** in every cell, **lit strips** above
  the light shelves, **glowing plinths** under consoles and the dash, screens, door lintels. Every
  light is `LIGHT_WARM`.
- **One small `OmniLight3D` per walkable cell**, plus small ones at consoles, doors and the hatch.
  Keep energies low (0.35–0.5). **No shadows, no SSAO** in interiors.
- Glow is cheap: lit pieces go in the `glow.gdshader` batch with their strength baked into the
  vertex colour (`InteriorKit.lit`), and the interior camera's environment
  (`data/environments/ship_interior.tres`: filmic, bloom, warm ambient) does the rest.
- The interior mood sits on the **interior camera**, never the `WorldEnvironment`, so exteriors
  keep their own look.
- **Dim is not dark.** Silhouettes must stay readable from across a room.

### 2.4 Screens are set dressing that moves

- Screens run on `screen.gdshader`: big bars, one thick wave, or blinking dots, slowly animated,
  never text-heavy. Neighbouring screens must differ (seeded by `variety`).
- Screens do not read game state. The HUD is the instrument; a screen that shows real data is a
  feature with its own design.

### 2.5 The shader budget is three

`glow.gdshader`, `screen.gdshader` and `canopy_window.gdshader` are the only custom interior
shaders. `canopy_window.gdshader` is every window's glass (§2.7). **Reach for geometry and flat
colour first.** A fourth shader needs a reason no geometry
can meet, and the owner's approval. A test pins the list (§5).

### 2.6 Performance budget

The interior must hold **at least 120 fps at 1280 × 720 on the reference GPU (GTX 960)** with the
canopy view rendering. The canopy view renders the outside a second time, at full screen, whenever
the viewer is inside the ship. With portal windows, the cockpit pod and five furnished rooms it
measured 148–218 fps (2026-09-24); the seat in the pod, mostly glass, is the cheapest view.
Looking down the corridor with the hands in view it measured 143 fps, and 125–126 fps with eight
plasma bolts in flight, each carrying its own warm light (2026-09-24). Measure after any change
that adds lights, pieces, windows or post-processing.

### 2.7 Windows show the real outside

Every window is a **portal**. `CanopyPortal` renders the outside each frame from exactly where the
viewing camera would be if the interior were inside the hull, with the viewer's field of view,
into a view the size of the screen. Window glass shows that view at its own screen position. So a
window of any shape, anywhere, lines up with the world outside from wherever the player stands or
sits.

- **Window glass goes in the `InteriorKit` `PORTAL` batch.** Its material is the scene's canopy
  material made all glass (`InteriorDressing.portal_material`). With none wired, as in every unit
  test, it falls back to black glass, never a hole.
- Porthole glass is a portal too; the cartoon glint stays on top of it, in the `GLASS` batch.
- Windows show space, **never the ship's own hull**: the canopy camera leaves the hull's layer
  out.
- In the chase view no window is on screen, and the canopy view stops rendering.
- **The interior has no sky of its own.** Its private starfield sphere, which stars once moved past
  through transparent glass, was removed on 2026-09-24: behind portal glass it could never be seen.

---

## 3. The rules of reuse

Ships are generated from player blueprints, so every asset is placed by generators, not by hand.

- **Props never see the grid.** An `InteriorProps` function builds from `(kit, frame, variety)`
  and nothing else. It must not reference `ShipGrid`, `InteriorLayout`, `InteriorBuilder` or
  `InteriorDressing`; a test enforces this (§5). **The frame:** origin on the wall's inner surface
  at floor level, centred along the wall; +x along the wall, +y up, +z into the room. Props are
  designed for a 2 m bay and 2.5 m of headroom (§3.2).
- **Two more frames.** A **fixture** (a MOUNT block drawn as a prop, like the captain's chair)
  builds in a *fixture frame*: origin on the floor under it, −z the way it faces, +y up
  (`InteriorDressing.fixture_frame`). A **pod** builds in a *pod frame*: origin at the floor centre
  of the canopy face it juts out through, on the canopy plane; −z out into the pod, +x across
  (`InteriorDressing.pod_frame`).
- **Placement lives in one place.** `InteriorLayout` decides what every face is.
  `InteriorDressing` maps each face to a prop. Neither draws anything itself.
- **Rooms are grid data:** a room is a room block, so a blueprint generator can emit one. Walls
  between rooms and one doorway per room follow automatically.
- **Batching:** props add geometry to an `InteriorKit`, which commits one merged mesh per material.
  A prop that needs its own node (it animates, like `SlidingDoor`, or has its own material, like
  the nose shell) uses `InteriorKit.add_mesh` or its own small kit. Window glass is the `PORTAL`
  batch (§2.7).
- **Conventions:** interior visuals are on render layer 2; interior lights use
  `light_cull_mask = 2`; anything more than 0.15 m proud of a wall gets a box collider through
  `InteriorKit.collider` (group `interior_dressing`).
- **Items follow the same rules.** Loose items are `RigidBody3D`s on physics layer 6 (`items`);
  their looks come from `ItemLooks`, which, like the props, builds from a kit and never sees the
  grid. A prop that holds items publishes its spots in its own frame and keeps them clear of its
  colliders, so the Interactor can reach what sits there; `InteriorDressing` places the stow
  points (docs/superpowers/specs/2026-09-23-hands-and-items-design.md §5).

### 3.1 Furnishing a 2 m room

A room cell is 2 m square, and crowding it is the easiest mistake to make:

- **One feature piece** on the best wall (an outer flank first), and **at most one secondary
  piece**, under 1 m wide, at the far end of a side wall, clear of the feature's corner. Other walls
  keep their trim.
- Leave a clear aisle at least 1.0 m wide from the doorway into the room: the avatar is 0.7 m wide.
- A feature wall on the outer skin gets a porthole above the furniture, so that piece must stay
  below 1.0 m there (a low bunk, a counter with no cupboards above).

### 3.2 Interior storeys are taller than the grid

Grid cells are 2 m cubes, but **an interior storey is 2.6 m tall, with 2.5 m of clear
headroom** (`InteriorBuilder.STOREY_HEIGHT`). The first build used the 2 m cell as the storey,
which left 1.9 m of headroom: the ceiling was 0.3 m above the eye, and the owner's head was
"almost hitting the lights". The interior is its own space and is never seen beside the hull, so
it can be bigger inside than out.

- **The floor is anchored to the grid; only the ceiling rises.** Everything at floor level (the
  pilot's seat and eye, the canopy camera, the airlock) maps one to one onto the hull. Storeys
  stack at `STOREY_HEIGHT`.
- **Place interior things with `InteriorBuilder.floor_y()` and `interior_center()`**, never with
  `ShipGrid.cell_center().y`. Anything that crosses between interior and exterior space (the
  airlock, boarding, stepping outside) maps through them too.
- **Hang ceiling trim from `InteriorProps.HEADROOM`**, not from fixed heights, so it follows the
  storey. Furniture and fittings sit at human heights: eye level is 1.6 m, portholes are centred at
  1.45 m, wall screens at 1.45 m, and doors are 2.1 m (`DOOR_HEIGHT`) with a lintel above. Doors
  are never full ceiling height.

### 3.3 Cockpits: a pod, or a nose

The pilot has to be able to fly from inside, so the helm sits where the glass is.

- **A windshield with a helm behind it gets a cockpit pod.** When a `pilot_seat` looks straight at
  a canopy face, `InteriorLayout` marks that face a pod. The dressing builds a **wraparound pod**
  there: a 2 m mouth, 2.4 m wide inside, jutting 1.9 m beyond the canopy plane; glazed from a
  0.75 m sill to 2.05 m in front and on both sides; a **solid roof** at 2.2 m with a round light;
  and a header over the mouth up to the cabin ceiling. The **captain's chair** stands 0.7 m out in
  the pod (`POD_SEAT_DEPTH`), so the seated eye has glass ahead and on both flanks.
- **The windshield's other faces become shoulders:** a wall with a portal window at 1.15–1.95 m in
  a chunky frame, and a console desk under it, without the console's wall screen, which would
  cover the window.
- **A windshield with no helm behind it keeps the rounded nose**, with portal windows.
- **The pod brings its own colliders** (a floor, a roof, a wall per segment); the builder leaves its
  mouth open. The pod reaches beyond the grid, which interior space allows. The seated eye stays
  inside the hull's canopy cells, so the view outside starts from inside the ship.
- **The helm console stays under the seated sightline** to the bottom of the front glass; a test
  holds it there.
- **Later, not built:** a **bubble canopy** (the roof glazed too) as a pod variant for other ships
  and player-built ships.

---

## 4. Adding something new

**A new prop:**

1. Add a static function to `InteriorProps`, taking `(kit, f: Transform3D, variety: float)`.
2. Build it from kit primitives, with colours from `InteriorPalette` (add a constant if needed).
3. Add a collider if it protrudes more than 0.15 m, and a small warm light if it emits.
4. Test it in a bare frame in `test_interior_props.gd`: it builds with no grid, its colliders sit
   in front of the wall, and its collider count is pinned.
5. Render it (§6) before calling it done.

**A new fixture** (a MOUNT block drawn as a prop):

1. Add a prop in the fixture frame (§3), tested in a bare frame like any other.
2. Add its id to `InteriorDressing.draws_fixture` and a branch in `InteriorDressing._fixture`. The
   builder then stops drawing the block's own mesh inside.
3. Place anything interactable from `InteriorDressing.fixture_frame`, never from a second set of
   numbers.

**A new window:** put its glass in the `PORTAL` batch (§2.7) and give the wall behind it a hole.
Glass on its own is not a way out: keep the wall's collider whole.

**A new room type:**

1. Add a room block `.tres` with the same mass and power as `deck`, unless a balance decision says
   otherwise.
2. Add its id to `InteriorLayout.ROOM_IDS` and its floor colour to `InteriorPalette.ROOM_FLOOR`.
3. Give it a feature prop and a compact secondary prop, and a branch in
   `InteriorDressing._room_piece`.

**A new item** (docs/superpowers/specs/2026-09-23-hands-and-items-design.md):

1. Add a `.tres` in `data/items/` with its mass, size, grip, stow class and look.
2. Add a builder to `ItemLooks` that draws inside the item's box from kit primitives, with colours
   from `InteriorPalette`, and add its id to `ItemLooks.LOOKS`.
3. If it does something when used, give it a `use` script extending `ItemUse`.
4. If a prop should hold it, publish a spot from that prop and stock it in `InteriorDressing`.
5. Render it in the hand and on its stow point (§6) before calling it done.

**A different kind of interior** (a derelict, an enemy ship, a station):

- Keep the kit, the props and the rules. **Change colour and wear, not the style.**
- Derelict and enemy interiors should read as cold or failing: flickering or dead practicals,
  cooler light, damage, missing panels. They must differ from the player's ship **by more than
  brightness alone**.
- Palette variants belong beside `InteriorPalette`, as data, not as literals in props.

---

## 5. What is enforced by tests

`test/unit/test_visual_style_rules.gd` fails the build if:

- a colour literal appears in interior, item or hand code other than `InteriorPalette`
  (`InteriorKit` is exempt: it packs data into vertex colours);
- `interior_props.gd`, `interior_kit.gd`, `sliding_door.gd`, `item_looks.gd`, `item.gd`,
  `glove.gd` or `hands.gd` reference the grid, the layout, the builder or the dressing;
- the set of interior shaders changes.

Other interior tests pin the rest: render layer 2 and cull mask 2, no interior shadows, colliders
on protruding props, one light per cell, the doorway clearance, window glass in the `PORTAL`
batch, the pod's colliders, and the helm under the seated sightline.
`test/unit/test_mesh_winding.gd` holds every baked block mesh to Godot's winding (clockwise seen
from the front): a mesh wound the other way renders inside-out with no warning at all.

If one of these fails, the answer is almost always to fix the code, not the test. Change a test
only together with this guide, and only with the owner's approval.

---

## 6. Verifying visual work

A green test suite proves the structure, not the look. For visual work:

- **Render the real scene** from fixed viewpoints at the player's eye height (1.6 m above the
  deck): the bridge, the seated pilot's eye, a corridor, and inside each room. Send the screenshots
  to the owner.
- **Look out of the windows** from the seat and from standing: what they show must line up with
  the world outside.
- **Read scene and resource edits back at runtime** (CLAUDE.md: a clean load proves nothing for
  `.tscn`/`.tres`).
- **Compile shaders on a real renderer.** Headless runs never compile them, so run once without
  `--headless` and check for `SHADER ERROR`.
- **Measure frame time** against §2.6.

---

## 7. Directions already tried and rejected

These are recorded so nobody "corrects" the look back to one of them:

- **Moody, dark, blue-accented sci-fi** (prototyped 2026-09-23). Replaced by the warm reference.
- **A realistic take on the warm reference:** procedural panel seams, rivets, grime, carpet fibre,
  SSAO. Rejected as too costly to design and render; "fun and real enough" won.
- **Bright interior lighting.** Rendered side by side with the dim version; the owner chose dim.
- **The original bright red-and-grey palette** (starter shuttle art direction §5.2). Superseded.
