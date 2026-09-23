# Ship interior redesign — design

**Date:** 2026-09-23
**Status:** Approved design, ready for an implementation plan
**Depends on:** Tasks 13–15 (grid-generated interior), commit `71643cd` (fixtures drawn, canopy
camera at the pilot's eye)
**Supersedes:** starter shuttle art direction §5.2 (interior palette) and §5.3 (bright, warm,
lived-in); refines §7 item 4 (canopy faces)
**Addresses:** SLICE-1-STATUS "Reported by playtest" item 6 — the interior is plain and boring

---

## 1. Why this document exists

The cabin is a box. Flat beige walls, a red-brown floor, a flat ceiling, three warm fluorescent
strips, and one 6 m × 2 m flat windshield. Nothing in it says *spacecraft*.

The owner's direction, verbatim in intent: **it needs to look like a spaceship — moody, darkish,
blue accents, electronics and control panels, a few small windows, and a more rounded front.**

This reverses art direction §5.3, which said the player's ship is "bright, warm and lived-in" and
asked that nobody correct it toward gloom. The owner has now asked for exactly that. §5.2 and §5.3
are rewritten as part of this work (§9) so the two documents do not disagree.

### 1.1 Decisions already made

- **Windows:** a rounded cockpit front with a few small windows replacing the flat windshield,
  **plus** small portholes along the cabin's outer walls.
- **Approach:** a **generated dressing kit** driven by the ship grid — not hand-dressing of the
  starter shuttle, and not a pre-baked mesh kit. The project's architecture is that nothing about
  the craft is hand-authored scenery; a player-built ship in the shipyard must get the same
  treatment for free.
- **"Rounded front" is interior-only.** The exterior hull, its canopy wedge mesh and the
  blueprint are unchanged.

---

## 2. Scope

**In:**

- A dark, blue-accented interior palette and material set (§3).
- Structural dressing on every walkable cell: ribs, coves, floor strips, conduits, ceiling light
  panels (§4.1).
- Wall variants chosen by grid context: console, porthole, electronics rack, panel, hatch (§4.2).
- A rounded cockpit nose with three small windows and a dashboard, replacing the flat canopy
  panes (§5).
- Generated interior lighting and a dedicated interior camera environment (§6).
- Recolouring the pilot seat to match.

**Out, deliberately:**

- Exterior changes of any kind.
- Blueprint changes (the seat stays at `(0, 0, −2)`; see §10 for the trade-off this leaves).
- Interactive consoles. Screens animate from `TIME` only; nothing reads ship state.
- Global illumination (SDFGI/VoxelGI), reflection probes, volumetric fog. The target GPU is a
  GTX 960 and the interior is regenerated at runtime.
- Ceiling height. Headroom stays 1.9 m (SLICE-1-STATUS item 2 is a separate decision).
- A new block type. Everything here is derived from existing blocks.

---

## 3. Palette and materials

### 3.1 `InteriorPalette`

New `src/ship/interior_palette.gd`, `class_name InteriorPalette extends RefCounted`, constants
only — the same pattern as `HudPalette`. Every interior colour resolves here.

| Constant | Colour | Role |
|---|---|---|
| `PANEL` | `#2A3038` | wall panels, dominant surface |
| `PANEL_DARK` | `#1B1F25` | seams, ribs, rack bodies |
| `TRIM` | `#3A424C` | kick plates, frames, console bodies |
| `CEILING` | `#171A1F` | overhead |
| `FLOOR` | `#1C1F24` | deck plates |
| `ACCENT` | `#3FA9FF` | emissive strips, hatch arch |
| `SCREEN` | `#7FD4FF` | console readouts (matches `HudPalette.READOUT`) |
| `WARN` | `#FFB03A` | sparse status lights (matches `HudPalette.WARNING`) |
| `ALERT` | `#FF4A3D` | sparse status lights |
| `LIGHT_COOL` | `#9DBBFF` | ceiling panels and their lights |
| `GLASS` | `#0E1A26`, alpha 0.35 | porthole glass tint |
| `SEAT` | `#23272E` | pilot seat upholstery |

### 3.2 Shaders

All under `data/materials/interior/`. Materials are built in code from these shaders with
parameters from `InteriorPalette`, so `.tres` files stay minimal (CLAUDE.md comment hazard).

- **`panel.gdshaderinc`** — shared surface function. Procedural panel seams on a 1 m grid,
  rivets at seam intersections, low-frequency grime and roughness variation, all from
  **world-space position** with a triplanar pick by normal, so any box at any position tiles
  correctly without UVs. Parameters: base colour, seam colour, metallic (0.3), roughness (0.55).
- **`panel.gdshader`** — floors, ceilings, walls, trim. Includes `panel.gdshaderinc`. Adds one
  **instance uniform** `porthole` (`vec4`: centre in local space xyz, radius w; w ≤ 0 means none)
  and discards fragments inside that cylinder along the wall normal. This is how a porthole wall
  gets a real see-through hole while its `BoxMesh` and its collider stay whole.
- **`screen.gdshader`** — unshaded emissive readouts, animated from `TIME`: a mode uniform picks
  bar graph, waveform, or text-like block rows; scanline and slight flicker. A second mode set
  (`leds`) draws a grid of blinking status LEDs for racks, mostly `SCREEN`, a few `WARN`/`ALERT`.
- **`canopy_window.gdshader`** — the nose shell. Includes `panel.gdshaderinc` for the shell
  body; inside the window mask it shows the projected canopy view (§5.2); a thin `ACCENT` rim
  glows around each window.
- **Emissive strip** and **glass** are plain `StandardMaterial3D`s built in code (`ACCENT`
  emission energy 2.5; `GLASS` transparent, roughness 0.05, metallic 0.2).

---

## 4. The dressing kit

### 4.1 Structural dressing — every walkable cell

Heights below are **floor-relative** (floor surface = 0, ceiling underside = 1.9 m).

- **Ribs.** Each wall face emits a half-rib at both vertical edges: 0.06 m wide, 0.06 m proud,
  full height, `PANEL_DARK`. Two adjacent faces' halves meet as one 0.12 m rib at every cell
  boundary.
- **Ceiling ribs.** Across every shared edge between two walkable cells: 0.08 m wide, 0.04 m
  deep. Kept shallow because headroom is 1.9 m for a 1.8 m avatar.
- **Coves.** Along the top of each wall face: a 45° chamfer panel 0.22 m wide, meeting the wall
  at 1.74 m and the ceiling 0.16 m in. An `ACCENT` emissive line (0.025 m) runs along its lower
  edge.
- **Conduit.** One pipe, radius 0.045 m, along each cove's lower edge, `TRIM`.
- **Kick plate and floor strip.** A 0.12 m × 0.03 m `TRIM` kick plate at each wall base, with a
  0.02 m `ACCENT` emissive strip along its top.
- **Ceiling panel.** One per walkable cell, 0.9 × 0.5 m, 0.01 m below the ceiling, `LIGHT_COOL`
  emissive at energy 0.6, with a `PANEL_DARK` bezel.

### 4.2 Wall variants

Every wall face (not canopy) gets exactly one variant, decided by `InteriorLayout` (§7.1).

| Variant | What it is | Collider |
|---|---|---|
| `HATCH` | Door slab 1.1 × 1.75 m, 0.04 m proud, seamed; 0.12 m `TRIM` frame; an `ACCENT` arch strip across the frame head (energy 2.0); one `WARN` indicator beside the door. | none (≤ 0.1 m proud) |
| `CONSOLE` | Base cabinet 1.4 wide × 0.75 tall × 0.35 deep (`TRIM`); a sloped screen face rising from 0.75 m at 0.35 m out to 1.1 m at the wall (`screen`, bar/waveform/text mode varying per face); a button row of small emissive boxes, mostly `SCREEN`, one `WARN`; a wall display 0.8 × 0.4 m at 1.2–1.6 m, 0.04 m proud (`screen`). | box 1.4 × 1.1 × 0.4 |
| `PORTHOLE` | The wall's `porthole` instance uniform cuts a hole of radius 0.28 m centred at 1.4 m. A frame ring (outer radius 0.38, inner 0.28, 0.14 deep, 0.07 proud, `TRIM`), with a thin `ACCENT` ring on its inner lip. Glass disc at the wall's outer plane (`GLASS`). Beyond it is the interior `SkySphere`, which `MotionCoupling` already rotates with the hull. | none — the wall's box collider stays whole |
| `RACK` | Cabinet 1.2 wide × 1.5 tall (0.15–1.65 m) × 0.25 deep, `PANEL_DARK`; front split into modules — two `leds` screen strips, a vent slat block, a small `screen` readout. | box 1.2 × 1.5 × 0.25 |
| `PANEL` | Plain wall plus one junction box greeble (0.3 × 0.4 × 0.08 m). | none |

The kit's pieces are built from primitive meshes via `SurfaceTool.append_from()` and merged into
**one `ArrayMesh` per material** per rebuild, so the draw-call count does not grow with ship size
beyond a handful of merged meshes.

---

## 5. The cockpit nose

### 5.1 Shell geometry

`InteriorLayout` groups canopy faces by plane (§7.1). For each group, `InteriorDressing` builds
one **nose shell** that bulges *forward*, into the canopy cells, from the plane those faces share.
Canopy cells are solid, so the space is free; the exterior is a separate space, so the interior
shell does not need to fit inside the exterior wedge.

Parametrised over `u ∈ [0, 1]` across the group and `v ∈ [0, 1]` floor to ceiling, for a group of
width `W` centred at `x_c` on plane `z_p`, with nose depth `D = 1.4 m`:

```
θ    = π · u
d(v) = D                                     for v ≤ v0
     = D · sqrt(1 − ((v − v0) / (1 − v0))²)   for v > v0      (v0 = 0.45)
x    = x_c − (W / 2) · cos θ
z    = z_p − d(v) · sin θ
y    = floor + 1.9 · v
```

That is a vertical lower half and a curved-back upper half: plan view a half-ellipse, and the
roof of the alcove sweeping down onto the ceiling edge. At `θ = 0` and `θ = π` the depth is zero,
so it meets the side walls flush. Tessellated at 48 × 20.

The formula is written for a group facing −Z (a forward windshield, which is all this ship has).
Other facings rotate the same local shell by the group's face normal.

### 5.2 Windows

Three windows, as rounded rectangles in `(u, floor-relative height)`, corner radius 0.08 m:

| Window | u | Height |
|---|---|---|
| Centre | 0.5 ± 0.13 | 0.95–1.70 m |
| Port / starboard | 0.5 ∓ 0.27, ± 0.08 | 1.00–1.60 m |

These are constants in `InteriorDressing` and are expected to be tuned from screenshots.

The shell's material is `InteriorBuilder.canopy_material` — the scene supplies it as a
`ShaderMaterial` on `canopy_window.gdshader` carrying the `ViewportTexture`. Inside a window,
for each fragment the shader:

1. takes the fragment's world position and subtracts the uniform `eye_world` — the pilot's eye;
2. treats that as a view-space direction for the canopy camera (the interior is axis-aligned with
   the hull and the canopy camera looks down −Z, so no rotation is needed);
3. projects it with `tan_half_fov_y` and `aspect` to a UV and samples the viewport there; outside
   `[0, 1]` it shows black.

Because every window samples by direction from the eye, windows of any shape, anywhere on a
curved surface, line up into one continuous view, and the cockpit velocity marker (drawn inside
the SubViewport) still registers against what is visible. The old per-pane UV split is deleted.

The viewport stays 1536 × 512 (3 : 1) with `fov = 40`. The side windows' far edges sit about 33°
off-axis from the eye, inside the camera's ±47.5° horizontal cover.

`flight_test.gd::_aim_canopy_view()` already computes the eye; it additionally sets `eye_world`,
`tan_half_fov_y` and `aspect` on the canopy material from `CanopyCam` and the viewport size.

If `canopy_material` is null (every builder test), the dressing builds the shell with a default
`canopy_window.gdshader` material and no texture: the windows render black, never a hole.

### 5.3 Dashboard and collision

A dashboard follows the shell arc, inset 0.1 m, 0.5 m deep, top at 0.9 m, with a sloped `screen`
strip. The canopy faces' existing box colliders stay exactly where they are, at the plane, so the
avatar stops at the front of the dash like a railing. The dash and the shell are beyond that plane
and need no colliders.

---

## 6. Lighting and environment

### 6.1 Generated lights

`InteriorDressing` creates every interior light; `flight_test.tscn` loses `CeilingLight1`–`3`,
their `Strip` meshes, and the `BoxMesh_light_strip` / `StandardMaterial3D_light_strip`
sub-resources.

| Light | Where | Colour | Energy | Range | Shadow |
|---|---|---|---|---|---|
| Cell light | every walkable cell's ceiling panel | `LIGHT_COOL` | 0.5 | 3.2 | no |
| Screen spill | every `CONSOLE`, 0.4 m out from the screen | `SCREEN` | 0.6 | 1.8 | no |
| Hatch light | every `HATCH`, above the arch | `ACCENT` | 1.2 | 3.0 | no |
| Cockpit key | one per nose shell, above the dash | `SCREEN` | 0.8 | 3.0 | **yes** |

All `OmniLight3D`, all `light_cull_mask = 2`. The starter shuttle lands at 26 lights (20 cells, 4 consoles, 1 hatch, 1 key), one
shadowed; Forward+ clustered lighting handles that without shadows.

### 6.2 Interior environment

New `data/environments/ship_interior.tres` (`Environment`), assigned by `flight_test.gd` to the
interior camera (`Ship/Interior/Avatar/Head/Camera3D`, which is also the seated camera). The chase
camera and the canopy `SubViewport` keep the `WorldEnvironment`, so the exterior look does not
change.

- Background: custom colour, black (the interior `SkySphere` covers it).
- Ambient: colour `#0B1320`, energy 0.4.
- Tonemap: filmic, exposure 1.0.
- Glow: on, intensity 0.8, bloom 0.05, HDR threshold 1.0 — this is what turns thin emissive strips
  into light.
- SSAO: on, radius 1.0, intensity 2.0 — contact darkening in corners and under consoles.

---

## 7. Architecture

### 7.1 `InteriorLayout` — new, pure

`src/ship/interior_layout.gd`, `class_name InteriorLayout extends RefCounted`.

```gdscript
static func plan(grid: ShipGrid, catalog: BlockCatalog, walkable: Array) -> InteriorLayout
func faces() -> Array[Dictionary]          # {coord, normal: Vector3i, kind, variant}
func canopy_groups() -> Array[Dictionary]  # {normal, plane, coords: Array[Vector3i]}
```

`kind` is `FLOOR`, `CEILING`, `WALL` or `CANOPY`. `variant` is set for `WALL` only. Wall variants
are resolved in strict priority order:

1. **`HATCH`** — the cell is an `airlock` and the neighbour across this face is empty (vacuum).
2. **`CONSOLE`** — the cell is face-adjacent to a MOUNT cell (the pilot seat), or the cell has a
   `CANOPY` face (it is in the cockpit row).
3. **`PORTHOLE`** — the face is a **flank** (normal ±X: port or starboard — ships carry
   portholes on their sides, not on end bulkheads) **and outer skin**: the neighbour is empty, or
   the neighbour is solid and the cell beyond it (`coord + 2 · normal`) is empty.
4. **`RACK` or `PANEL`** — alternating by a stable integer hash of `(coord, normal)`.

Walkable-to-walkable faces are open and produce no record, exactly as today. The layout never
references `InteriorBuilder` or `InteriorDressing`; both read it.

On the starter shuttle this yields: `CONSOLE` on both side walls of the z = −3 and z = −2 rows (4);
`PORTHOLE` on both side walls at z = −1 and z = 0 (4 — the engine pods sit outboard of z = +1
and +2, so those walls are not skin); one `HATCH` on the airlock's aft face; `RACK`/`PANEL` on
the rest (the aft bulkhead faces are skin but not flanks, so they get no porthole).

### 7.2 `InteriorBuilder` — changed

- `rebuild()` computes the `InteriorLayout` once and builds from its records instead of from its
  own neighbour loop.
- Floors, ceilings and walls keep their `_add_box()` collider + `BoxMesh` pair, with the §3
  `panel.gdshader` materials in place of the flat `StandardMaterial3D`s. A `PORTHOLE` wall's mesh
  instance gets its `porthole` instance uniform set; its collider is unchanged.
- **Canopy faces keep their colliders and lose their visible boxes.** The nose shell is the
  canopy surface now.
- `_build_canopy_panes()`, `_sorted_unique()`, `_pane_mat()`, `canopy_pane_uvs()` and
  `_canopy_panes` are deleted.
- After fixtures, `rebuild()` calls `InteriorDressing.build(layout, …)`, which parents all of its
  output under one `Dressing` `Node3D` inside the owned `StaticBody3D`. Consequently one rebuild
  still owns one body, and `_clear()`'s existing `remove_child()` + `free()` removes the dressing
  with everything else.
- New read-only accessor `layout() -> InteriorLayout` for tests and the dressing.

### 7.3 `InteriorDressing` — new

`src/ship/interior_dressing.gd`, `class_name InteriorDressing extends RefCounted`, one entry
point:

```gdscript
static func build(layout: InteriorLayout, grid: ShipGrid, body: StaticBody3D,
		canopy_material: Material) -> Node3D
```

It returns the `Dressing` node it created, holding:

- one `MeshInstance3D` per material with the merged `ArrayMesh` (layers = 2);
- the `OmniLight3D`s of §6.1;
- `CollisionShape3D` boxes for `CONSOLE` and `RACK` pieces, added to `body` (not to `Dressing`,
  because shapes must be direct children of the body to register).

Tests count pieces by querying that node tree (`find_children` by type), so `Dressing` is a
plain `Node3D` with no script.

### 7.4 Scene and resource edits

- `flight_test.tscn`: delete the three ceiling lights and their sub-resources; replace
  `StandardMaterial3D_canopy` with a `ShaderMaterial` on `canopy_window.gdshader` whose
  `canopy_view` parameter is the existing `ViewportTexture_canopy` (`resource_local_to_scene`
  kept).
- `flight_test.gd`: `_aim_canopy_view()` also sets the three canopy shader uniforms; a new step
  assigns `ship_interior.tres` to the interior camera.
- `data/blocks/meshes/pilot_seat.tres`: the upholstery material's `albedo_color` becomes
  `InteriorPalette.SEAT`. The cyan readout material is unchanged.

No `#` comments in any `.tscn` or `.tres`. Every scene edit is proven by reading the value back at
runtime, per CLAUDE.md.

---

## 8. Testing

### 8.1 `test_interior_layout.gd` — new

- A porthole is placed only on an outer-skin flank face; a wall whose solid neighbour has
  another solid cell beyond it gets no porthole, and neither does a ±Z face that is skin.
- A wall next to a MOUNT cell is a `CONSOLE`, even when it is also outer skin (priority).
- `HATCH` appears only on an airlock face whose neighbour is empty.
- Every wall face has exactly one variant; canopy faces have none.
- Canopy faces are grouped by plane: three in a row form one group.
- The same grid planned twice yields identical records.
- On the real starter shuttle (`load("res://scenes/flight_test.gd").new()._starter_grid()`, the
  node freed afterwards): 4 portholes, 1 hatch, 4 consoles, one canopy group of 3.

### 8.2 `test_interior_dressing.gd` — new

- Fuzz: 300 random mutations (same seed style as the parity test), rebuild, no crash, every
  dressing visual on layer 2, every light's cull mask is 2.
- Repeated rebuilds leave exactly one `Dressing` node and no stale `OmniLight3D`s.
- Every `CONSOLE` and `RACK` contributes one collider on the interior body.
- A nose shell exists if and only if there is a canopy group; with a null `canopy_material` its
  material is still a `ShaderMaterial` (never a hole).

### 8.3 `test_interior_builder.gd` — changed

- Delete `test_canopy_panes_split_the_view_between_them` and
  `test_a_lone_canopy_pane_shows_the_whole_view`.
- `test_rebuild_does_not_leave_stale_nodes_in_the_tree` counts structure meshes as the body's
  direct `MeshInstance3D` children, and separately asserts exactly one `Dressing` child.
- New: a porthole wall still has a full-size box collider.
- New: a canopy face has a collider and no structure mesh at that position.

### 8.4 `test_hud_scene_wiring.gd` — changed, runtime read-back

- The canopy material is a `ShaderMaterial` whose `canopy_view` is a `ViewportTexture`, and whose
  `eye_world` equals the seat `Eye`'s global position.
- `Ship/Interior/CeilingLight1` no longer exists.
- The interior camera's `environment` is `ship_interior.tres`, with glow enabled.
- The pilot seat mesh's upholstery surface albedo is `InteriorPalette.SEAT`.
- `test_canopy_viewport_matches_the_windshield_shape` keeps asserting 3 : 1.

### 8.5 Verifying it for real

A throwaway probe script (scratch, never committed) loads the real `flight_test.tscn` with
rendering on and saves screenshots from four fixed viewpoints — aft looking forward, pilot's eye,
forward looking aft, corner — before and after. Those go to the owner. The same probe logs an
average frame time over 120 frames inside the cabin at 1280 × 720; if the GTX 960 cannot hold
60 fps, SSAO is the first thing to drop, then the cockpit key light's shadow.

The whole GUT suite stays green.

---

## 9. Amendments to other documents

- **Starter shuttle art direction §5.2** — replaced by §3.1 of this document.
- **§5.3** — replaced with: *Revised 2026-09-23 at the owner's direction: the player's ship is
  moody and dark with blue accents. §11's "dim and pooled" treatment for derelict and enemy
  interiors now needs to differentiate by colour and wear (e.g. failing amber/red lighting,
  damage) rather than by brightness alone.*
- **§7 item 4** — annotated: canopy faces keep their colliders; the visible canopy is now the
  generated nose shell (this document §5).
- **SLICE-1-STATUS** — playtest item 6 marked addressed, pointing here.

---

## 10. Known trade-offs and follow-ups

- **The pilot sees less.** The eye sits about 3.5 m behind the front plane and 4.9 m from the
  nose apex, so the centre window covers roughly ±9° horizontally and ±5° vertically. The chase
  camera (V) is unaffected. The honest fix is moving the pilot seat forward one row in the
  blueprint, which is out of scope here and should be decided with the SLICE-1-STATUS ceiling
  question.
- **The canopy view is correct only from the eye.** Walking around, the projected view shows
  slight parallax error. That is the same class of cheat the flat panes had, and less visible.
- **Portholes show stars only**, not debris or the hull — the interior sky sphere is all that
  exists behind them. A side-camera feed is not worth its cost for small portholes.
- **Consoles and racks protrude into cells**, so a player-built one-cell corridor gets a little
  narrower. Every protruding piece has a collider, so it is honest about it.
