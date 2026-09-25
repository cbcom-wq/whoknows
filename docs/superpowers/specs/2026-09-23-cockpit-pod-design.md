# Cockpit pod, captain's chair and portal windows — design

**Date:** 2026-09-23
**Status:** Approved design (prototyped and rendered in the real scene), ready for a plan
**Depends on:** the ship interior redesign and taller interior (`main` at `c45ce48`)
**Governed by:** `docs/design/visual-style.md`
**Amends:** interior redesign spec §6 (the nose) and §10 (the pilot sees less); starter shuttle
art direction §3.1 (pilot seat position) and §4 (`pilot_seat` mesh)

---

## 1. Why

The owner: the captain's chair "does not look good… too boxy and has visual artifacting, barely
looks like a chair". Then: "place the pilot chair in kind of a jut out in the front surrounded by
windows so you can really see where you are flying. Currently it is so far away it is impossible
to really fly from inside."

Three problems, one of them hidden:

1. **The chair is broken geometry.** Every triangle of `data/blocks/meshes/pilot_seat.tres` is
   wound backwards. The Task 15 bake script used the opposite convention to Godot's, so the
   engine culls every outside face and draws the insides: open shells, black faces and pieces
   that look detached.
2. **The same fault is on the hull.** `hull`, `hull_wedge`, `canopy` and `airlock` are also wound
   backwards; only `thruster` (built from primitive meshes) is right. The ship has been rendering
   inside-out from outside.
3. **The pilot can't see out.** The eye sits 3.5 m behind small windows, and the windows show
   one fixed forward camera view that covers only about ±47° horizontally.

---

## 2. Decisions

- **A wraparound cockpit pod** juts out of the front of the bridge, with the captain's chair
  inside it. The starter ship's pod has glass in front and on both sides and a **solid roof**. A
  bubble canopy (roof glass too) is a later variant for other ships and player-built ships; it is
  not built now.
- **Portal windows.** Every frame the outside is rendered from exactly where the viewing camera
  is, and window glass shows it by screen position. Every window, of any shape, lines up with the
  world outside from wherever you stand or sit, at full screen resolution. This replaces the fixed
  eye-point projection.
- **The captain's chair and helm console become a prop** in the stylized kit, like everything
  else inside. The broken baked mesh is deleted.
- **All baked block meshes get their winding fixed**, and a test keeps them fixed.
- **The pilot seat moves forward one row** in the starter blueprint, so it sits at the pod's
  mouth.

---

## 3. Portal windows

- **`CanopyPortal`** (`src/ship/canopy_portal.gd`, a node under `Ship`). Each frame, after the
  cameras have moved (`process_priority` 1000), if the viewport's current camera is inside the
  interior:
  - the canopy camera's global transform becomes
    `hull.global_transform * interior.global_transform.affine_inverse() * viewer.global_transform`:
    the viewer's pose relative to the interior, carried onto the hull. The interior is
    axis-aligned with the hull, so this is exact;
  - its field of view and near plane are copied from the viewer;
  - the canopy `SubViewport` is sized to the screen and set to update always.
  When the viewer is outside, for example the chase camera, the canopy view stops updating.
- **Window glass** (`canopy_window.gdshader`, still one of the three interior shaders) samples
  `canopy_view` at `SCREEN_UV`. The eye, field-of-view and aspect uniforms are removed. A new
  `all_glass` uniform makes a whole surface window; without it, the rounded-rectangle window mask
  still applies, for noses.
- **`InteriorKit` gains a `PORTAL` batch** whose material is supplied to the kit: the scene's
  canopy material, duplicated with `all_glass = true`. Pod panes, shoulder windows and **porthole
  glass** all go in it. Portholes now show real space; the cartoon glint stays on top.
- **The HUD's cockpit velocity marker** stays inside the canopy view. That view now matches the
  screen, so the marker lands where the prograde point really is.
- **Removed:** the `CanopyRemote` `RemoteTransform3D` and `flight_test.gd::_aim_canopy_view()`.

---

## 4. The cockpit pod

- **Where:** a pod is built at the canopy face directly ahead of a **helm** fixture (a
  `pilot_seat` block, facing along its `BlockOrientation` forward). `InteriorLayout` marks that
  `CANOPY` record `pod = true`, lists it in `pods()`, and each canopy group records its pod faces.
- **Structure:** the builder builds no collider at a pod face; the mouth is open. The pod prop
  adds its own colliders to the interior body: floor, roof, and one wall per outline segment.
- **Shape**, in a pod frame (origin: floor centre of the mouth, on the canopy plane; −z out into
  the pod; +x across). Outline:
  - (−1.0, 0) → (−1.2, −0.25) → (−1.2, −1.2) → (−0.6, −1.9) → (0.6, −1.9) → (1.2, −1.2) →
    (1.2, −0.25) → (1.0, 0);
  - a 2 m mouth, 2.4 m wide inside, jutting 1.9 m.

  The short segments at the mouth are solid jambs. The side segments and the three bow segments
  are glazed from a **0.75 m sill** to **2.05 m**, with a band above to a **2.2 m roof**. There are
  chunky frame posts at the glazed corners, a sill ledge, a mauve floor with a lit edge strip, a
  round ceiling light in the roof, and a header over the mouth up to the cabin ceiling with a lit
  strip.
- **Shoulders:** the other canopy faces in a group with a pod become walls. Each has a portal
  window at 1.15–1.95 m in a chunky frame, the usual wall trim, and a console desk (the console
  without its wall screen, which would cover the window). The builder draws no box at canopy
  faces, so the shoulder draws its own wall around the window.
- **A group without a pod** keeps the rounded nose, with portal windows now.

---

## 5. The captain's chair and helm console

- **`InteriorProps.pilot_station(kit, f, variety)`** uses a new **fixture frame**: origin at the
  floor under the seat, −z the way it faces, +y up. It builds:
  - a pedestal with a glowing base, a chunky foot and a column;
  - a seat pan and cushion (`SEAT`);
  - a backrest tilted back 12°, with channel stitching, **side bolsters** and a shell behind;
  - a headrest behind the seated head (the eye is at 1.35 m, 0.45 m back);
  - armrests with control pads, a flight stick on the right and a throttle on the left;
  - a low **helm console** 0.72 m ahead, with two screens, lit buttons and a small light.

  The console top stays below the pod sill, clear of the seated sightline.
- **Collision:** the chair relies on the pilot seat's interactable box, so looking at it still
  offers "Take the controls". The helm console adds its own collider.
- **Placement:** `InteriorDressing.fixture_frame(layout, coord)` returns the chair's frame. In a
  pod, the chair sits **0.7 m beyond the canopy plane** (`InteriorProps.POD_SEAT_DEPTH`), which
  puts the eye 1.65 m behind the front glass with side glass on both flanks. Anywhere else, it's
  at the cell's floor centre. `flight_test.gd` places the `PilotSeat` node from the same frame, so
  the picture and the interactable can't drift apart.
- **Standing up (amended 2026-09-24):** there must always be room to get out of the chair and walk
  away. Getting up puts you at the first of `PilotSeat.STAND_SPOTS` where your body fits on a
  floor (`Avatar.can_stand_at`): a step straight back out of the chair, 1.3 m behind its origin
  and clear of the backrest, then back to either side, beside it, and a longer step back. You face
  the way the chair does. If none of those is clear, you stand where you sat down from, which is
  always somewhere you fit. The first version put you 0.9 m to the chair's right. In the pod that
  spot is inside the side wall and the seat's box, which left you wedged between the chair and the
  glass. `test_pilot_seat.gd` holds the starter ship to the step straight back, and requires that
  you can walk away from it.
- **Fixtures in general:** `InteriorLayout.fixtures()` lists every MOUNT cell `{coord, id,
  orientation}`. The dressing draws the fixtures it has props for (`draws_fixture(id)`). The
  builder draws a block's own mesh only for the rest.
- **`pilot_seat.tres`** gets a plain `BoxMesh` placeholder for the exterior, like ten other
  blocks. `data/blocks/meshes/pilot_seat.tres` is deleted.

---

## 6. Winding fix

A throwaway tool reverses every triangle of `airlock`, `canopy`, `hull` and `hull_wedge` (and
`pilot_seat` until it is deleted) and re-saves them. **`test_mesh_winding.gd`** then asserts that
every triangle of every `.tres` mesh in `data/blocks/meshes/` agrees with its normal under Godot's
convention (clockwise seen from the front). Exterior renders before and after go to the owner.

---

## 7. Blueprint

`_starter_grid()` moves `pilot_seat` from (0, 0, −2) to (0, 0, −3), and (0, 0, −2) becomes `deck`.
The mass difference is 0.1 t moved 2 m, which is negligible. The existing stats and validation
tests must pass. Knock-on effects on the layout:
- the bridge's consoles at z = −2 become portholes, so the bridge has 2 consoles and 4 portholes
  (6 across the ship);
- the shoulders add two console desks.

---

## 8. Testing

- **`test_mesh_winding.gd`:** every baked block mesh is wound correctly.
- **Layout:**
  - `fixtures()` lists MOUNT cells with their orientation;
  - the canopy face ahead of a helm is a pod, and a canopy face beside one is not;
  - groups record their pod faces;
  - updated starter counts.
- **Builder:**
  - a pod face has no collider;
  - a helm fixture isn't drawn from its block mesh;
  - other MOUNT meshes still are.
- **Props:**
  - `pilot_station` builds with no grid and has one collider (the helm);
  - `cockpit_pod` builds with its colliders (floor, roof, seven walls) and portal panes;
  - `shoulder` builds with a portal window;
  - `console(..., false)` draws no wall screen.
- **Kit:** the `PORTAL` batch uses the supplied material and falls back when none is given.
- **Dressing:**
  - a group with a helm gets a pod and no nose shell, with a `CockpitPod` marker at the pod frame;
  - a group without one keeps its nose;
  - `fixture_frame` puts the chair 0.7 m into the pod.
- **Scene, read back at runtime:**
  - `CanopyPortal` carries the viewer's pose onto the hull and sizes the view to the screen;
  - `CanopyRemote` is gone;
  - the canopy material is the window shader fed by the viewport texture;
  - the bridge has a pod;
  - `PilotSeat` sits at the chair's frame.
- **Real-scene checks:**
  - renders of the seated view, the bridge, the pod from outside and the exterior (before and
    after);
  - the walk probe, extended so the player can reach the chair and the interactor finds the seat;
  - frame time against the style guide's 120 fps budget at 1280 × 720, now that the canopy view
    renders at full screen.
- **Docs:** style guide sections for portal windows, the fixture frame and the pod; this spec's
  amendments noted in the interior redesign spec and the art direction.

---

## 9. Trade-offs

- **The canopy view renders the outside a second time at full screen resolution** while you're
  inside the ship. The outside scene is light, and it stops rendering in the chase view.
- **Portal windows show the outside but never your own hull,** because the canopy camera excludes
  the ship's hull layer. Looking back from the pod, you see space where the hull's nose would be.
- **The pod extends the interior beyond the grid** (interior space is its own place). The eye
  stays inside the hull's canopy cells, so the outside view starts from a point inside the ship.
