# Slice 1 — status and handoff

**Last updated:** 2026-08-23
**Branch history:** `design/slice-1` (Tasks 1–12, merged) → `feat/slice-1-builders` (Tasks 13–15)
**Suite:** 88 tests, green, pristine output, zero orphans

Governing documents:

- `docs/superpowers/specs/2026-08-21-who-knows-slice-1-design.md` — the slice spec
- `docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md` — the ship's visual design
- `docs/superpowers/plans/2026-08-21-who-knows-slice-1.md` — the 20-task implementation plan
- `.superpowers/sdd/2026-08-21-who-knows-slice-1/progress.md` — the execution ledger, including
  every deferred finding with its reasoning
- `CLAUDE.md` — repo conventions, including the `.tscn`/`.tres` comment hazard

---

## What works

Tasks 1–15 of 20 are implemented and reviewed.

**The ship is fully generated from a `ShipGrid`.** 84 blocks produce the hull mesh, hull
colliders, the walkable interior, and the derived stats. Nothing about the craft is hand-authored
scenery any more.

- Fly it, steer with the mouse, roll with Q/E, toggle flight assist with Z
- Walk the interior, sit in the pilot seat with a continuous camera move, stand up mid-burn
- A live cockpit canopy showing the real exterior through the bow windows
- A 700-instance debris field so motion is legible
- A livery stripe painted by a vertex shader from genuinely ship-local height
- 21 block types (five of them room blocks), six with real meshes, the rest placeholder boxes
- A stylized, warm, dim interior generated from the grid: a rounded cockpit nose whose windows
  project the live forward view, portholes, consoles, a bridge, a corridor, and five furnished
  rooms behind sliding doors (docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md)

Derived stats for the starter shuttle: 88,500 kg, torque imbalance 4.3% of budget, power 36.0
gen / 25.2 draw MW, **zero validation issues**, `can_launch = true`.

---

## What does not exist yet

**Phase C — Tasks 16 to 20, the entire shipyard editor.** This is the largest remaining gap and
it is what turns the project from "a ship" into "ships you build":

- Task 16 — block placement, orbit camera, ghost preview
- Task 17 — deck slicer cutaway, block palette
- Task 18 — live stats and validation panel
- Task 19 — mirror mode, blueprint save/load
- Task 20 — Walk Test, Launch, the full loop

Until these exist the player cannot build anything; they fly the one blueprint defined in
`scenes/flight_test.gd::_starter_grid()`.

Slice 1's Definition of Done (spec §14) is therefore **not met**.

---

## Known open problems

### Unverified: the feel verdict

The whole slice was ordered to front-load one question and it is still unanswered:

- Does the seat transition **travel** rather than cut?
- Does standing up mid-burn **shove you aft** — does it feel like weight rather than a push?
- Is `shove_scale` (currently `0.35`, on the `MotionCoupling` node) the right value? The plan
  says sweep 0.1–0.6 and pick where a hard burn is clearly felt but you can still walk.

No agent can answer these. They need a human at a display.

### Unreviewed change

Commit `c6448ad` (avatar spawn height, deck slab thickness, pilot seat placement) was applied
directly by the controller to unblock a broken build rather than dispatched and reviewed. It is
verified by runtime probe but has not been through a review pass. **Fold it into the next
review.**

### Open design decision — two engine bells or five

The starter shuttle currently has five engine bells (two outboard pods plus a three-bell stern
bank) rather than the two-pod silhouette the art direction is built around.

This was measured, not chosen carelessly. The governing relationship is:

```
torque_imbalance.x = −F_total × (thruster_height − centre_of_mass_height)
```

The z-position of mass drops out entirely, so fore/aft ballast cannot affect pitch. Only the
vertical gap between the thrust line and the centre of mass matters. The equipment deck at
y = +1 over a hollow cabin puts the centre of mass at ~1.2 m, and a 2 m grid quantises thruster
height to 0 m or 2 m — so no two-pod layout can reach it. Pods at 0 m pitch one way (+680 kN·m),
pods at 2 m pitch the other (−382 kN·m). The stern bank works by straddling the centre of mass
instead of trying to match it.

**To get two bells, the deck layout has to change** — bring the heavy equipment down to the cabin
level so the centre of mass drops to where pods can sit. That costs art-direction §3.2's
rationale (a flat roof, and the Ship Core buried where Slice 3 boarders must work for it). It is
a real trade and it is unresolved.

### Reported by playtest, 2026-08-23 — not yet fixed

Six problems observed by the human. Diagnosis below where it was established.

**1. The pilot seat is invisible.** *Root cause found.* Two compounding reasons, and the second
also explains problem 6:

- The hand-built `PilotSeat` in `flight_test.tscn` has a `CollisionShape3D` and an `Eye` node but
  **no `MeshInstance3D`**. It is pure collision.
- **`InteriorBuilder` never renders block meshes at all** — zero references to `def.mesh`. It
  emits structure (floors, ceilings, walls, canopy faces) and nothing else. So `pilot_seat.tres`'s
  real mesh, `airlock.tres`'s emissive arch, and every future fixture exist only in *exterior*
  space, 5 km away, where the player can never see them.

  This is an architectural gap, not a bug: the interior renders **structure but not fixtures**.
  Fixing it properly means `InteriorBuilder` instantiating `def.mesh` for MOUNT (and probably
  DECK) cells on render layer 2. That also removes the need for a hand-authored seat node
  entirely — the seat becomes what the grid says it is.

**2. The ceiling is weirdly low.** By construction, and the art direction acknowledges it
(§2: "a 2 m cell forces a 2 m cabin"). Clear headroom is `CELL_SIZE − FLOOR_THICKNESS` = 1.9 m for
a 1.8 m avatar. Options: stack two DECK cells vertically for a 4 m cabin (the spec explicitly
allows this and `DeckGraph` already treats stacked decks as a second storey unless laddered — so
this needs thought), thin the slabs further, or shorten the avatar. A 4 m cabin over a 16 m hull
would change the ship's proportions, so this is partly an art-direction decision.

**3. Flying feels sluggish.** *Root cause found — two compounding causes.*

- **Peak yaw acceleration is 3.83 °/s².** Reaching even 30 °/s takes about eight seconds of full
  input. Torque budget is 160,000 N·m against a yaw inertia of 2,395,121 kg·m².
- **Assist damping exceeds control authority by 1.66×.** `FlightComputer` applies
  `ROTATION_DAMPING (3.0) × mass` = 265,500 N·m of damping at 1 rad/s, against 160,000 N·m of
  control torque. The ship actively fights every input. Worse, **damping scales with mass while
  the torque budget scales with RCS count** — so a heavier ship fights you harder no matter how
  much RCS you bolt on. That relationship is backwards.

  Underlying both: `ShipStats.torque_budget` is the crude proxy the plan flagged as a known rough
  edge — `Vector3(vertical, lateral, lateral) × CELL_SIZE` — not a real moment sum. It badly
  understates true authority, since it ignores each thruster's actual lever arm about the centre
  of mass. The plan says to revisit it "if turn rates feel wrong in playtest". **This is that
  moment.**

  Fix: compute `torque_budget` as a genuine `Σ r × F` over RCS and manoeuvring thrusters, and make
  assist damping proportional to *available torque* rather than to mass.

**4. Thruster visuals should respond to throttle.** Not implemented. The engine bells carry a
static emissive material (`#7FD4FF`, energy 3.0, art direction §5.1). They should scale emission —
and ideally bell length or a flame element — with commanded thrust. Note the constraint from §4:
one `MultiMesh` per block type with no per-instance material, so this needs either a shader
uniform driven from `FlightComputer`, or per-instance custom data.

**5. Hold-C free-look orbit.** Not implemented. Wanted: hold C to orbit the camera around the
player without altering movement or heading, releasing to return. Applies on foot and probably
seated. `CameraDirector` already owns all view state and is the natural home.

**6. The interior is plain and boring.** Largely downstream of problem 1 — no fixture meshes
render inside at all, so the cabin is bare structural surfaces. Beyond fixing that: the palette is
implemented but flat, there is no panel detail, no greebling, and the three ceiling practicals are
the only lighting. Art direction §5.2 and §5.3 describe the intended read (bright, warm,
lived-in), and it is not there yet.

**Addressed 2026-09-23** by the interior redesign
(docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md): MOUNT fixtures draw inside, a
reusable stylized prop library dresses every wall, the canopy is a rounded nose with projected
windows, and the cabin behind the bridge is a corridor with five rooms. The direction also changed:
warm and **dim**, stylized rather than realistic.

### Deferred findings

Seventeen Minor findings are recorded in the ledger with full reasoning. None are correctness
bugs. The ones most likely to matter later:

- **`avatar.tscn`'s `CapsuleShape3D` is not `resource_local_to_scene`.** Any instance calling
  `_apply_height()` mutates the collider for *every* Avatar instance. Harmless with one avatar;
  **must be fixed before Slice 3's boarding squads.**
- **`ShipGrid.get_block()` returns the live `BlockInstance`.** A caller can mutate `.orientation`
  in place with no `cell_changed` emission — a second, quieter route to the interior/exterior
  drift the architecture exists to prevent. The shipyard editor is where that temptation arises.
- **One shared `hull_inverse` uniform on one shared livery material.** Correct for a single-ship
  scene; two independently-rotating hulls would race on it. Slice 4 (fleet) must address this.
- **`deck`/`door`/`ladder` use thin slab meshes, not full boxes.** Verified necessary — the avatar
  camera has no `cull_mask`, so full boxes read as phantom walls at aisle boundaries. Latent gap
  if a player ever places `deck` on a hull boundary in the shipyard.

### No final whole-branch review has run

The subagent-driven process calls for one before integration, and it is also where the deferred
findings get triaged for merge. It has not happened.

---

## Hard-won lessons worth not relearning

- **A clean headless load proves nothing.** Godot's `.tscn` parser silently drops properties, and
  entire nodes, adjacent to `#` comments — with zero warnings. This cost a window collider, a
  starfield, and a ceiling light before it was found. See `CLAUDE.md`. Always read state back at
  runtime.
- **`assert()` is stripped from release builds.** It cannot be the only guard on an invariant.
- **`queue_free()` leaves a `CollisionShape3D` parented and physics-registered** until the engine
  flushes its delete queue, which never happens between two synchronous calls. Use `remove_child()`
  then `free()`.
- **`RayCast3D` defaults to `collision_mask = 1`.** It silently never hits anything on another
  layer. `PhysicsRayQueryParameters3D.create()` defaults to all layers — the inconsistency is a
  trap.
- **A test that only asserts on a builder's internal arrays** will pass happily while stale nodes
  accumulate in the scene tree. Assert on real children.
- **Godot's input map needs `Object(InputEventKey, ...)` syntax** in `project.godot`. A
  JSON-shaped `events` array parses without error and registers the action with **zero bindings** —
  the game runs, renders, responds to the mouse, and no key does anything.
