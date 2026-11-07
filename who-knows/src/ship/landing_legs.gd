class_name LandingLegs
extends Node3D

## Landing legs (desert world phase 0, Task 15; the owner's decision,
## 2026-11-04). A ship that landed on its keel strip read as hovering: four
## chunky legs, two forward and two aft, set wide under the hull's outer edge,
## fold out about DOWN_BELOW metres over a world's ground and tuck back up past
## UP_ABOVE. In space they stay up, and there is no key. Their feet stand at
## least CLEARANCE under the keel's plane, and further when anything hangs
## lower: the owner's rule (2026-11-05) is that a ship's lowest hanging look --
## a belly turret's dome, a flood's housing -- clears the sand by HANG_CLEAR,
## so a hanging part costs ramp length, not placement (stance_for). All four
## are fixed in length, so the ship tilts with the ground.
##
## Where they go is worked out from each ship's own grid (plan(), pure): never
## in or beside a landing ramp's path, never under or beside an engine or a
## thruster whose exhaust faces down. ExteriorBuilder builds them (build()),
## from the launch layout's plan, for each mount the hull still has; Ship puts
## them down and up (Ship._sync_legs, wanted()).
##
## The plane the feet stand on is the stance plane, Ship.stance_depth() under
## the hull's origin: everything that measured from the keel's plane -- the
## flight computer's keel altitude and levelling, a landing ramp's sill, the
## step-or-ramp decision -- measures from it.
##
## The shape (docs/design/visual-style.md §2.1, §3.8): a hinge housing under the
## mount, an upper leg of two chunky arms that the lower leg folds between, a
## knee knuckle, and a broad foot pad that stays level. Struts in hull plate,
## housing and pad in the hull's trim, the knee in the panel line's grey (the
## one accent, as the ramp's treads are). Flat colour on the hull's trim
## material; no new shader. Chunky landing gear, not stilts (the owner,
## 2026-11-05): 0.38 m struts, a 0.8 m foot. Stowed, a leg lies folded flat
## within 0.5 m of its mount's bottom face: visible, tucked.
##
## Each leg has its own frame (frame()): its origin in the middle of the
## mount's bottom face, +y the hull's up, +z along the hull toward the leg's
## end (the bow for a forward leg), so a leg folds out toward its end.

enum State { STOWED, DEPLOYING, DOWN, STOWING }

## They come down under this many metres of keel altitude on a world...
const DOWN_BELOW := 40.0
## ...and go up over this many.
const UP_ABOVE := 60.0
## Seconds from stowed to down: folding out about the hinge (FOLD_TIME), then
## the lower leg straightening at the knee.
const TRAVEL := 1.5
const FOLD_TIME := 0.8
## No leg is longer than this, from its mount's bottom face to its foot.
const MOST_LENGTH := 4.0
## The feet stand at least this far under the keel's plane...
const CLEARANCE := 0.4
## ...and far enough that the lowest hanging look clears the ground by this
## (the owner, 2026-11-05; stance_for).
const HANG_CLEAR := 0.1

## How far the upper leg folds out, below the hull's level, once down.
const SPLAY := deg_to_rad(70.0)
## The hinge's axis, this far under the mount's bottom face.
const HINGE_Y := -0.2
## The hinge housing: a block under the mount, round the hinge's barrel.
const HOUSING := Vector3(0.92, 0.26, 0.56)
const BARREL_RADIUS := 0.12
## The lower leg: one strut this square.
const STRUT := 0.38
## The upper leg: two arms, each this wide and this tall, either side of the
## lower leg (their middles ARM_X off the leg's middle).
const ARM_WIDTH := 0.18
const ARM_HEIGHT := 0.38
const ARM_X := STRUT * 0.5 + 0.02 + ARM_WIDTH * 0.5
## The knee knuckle, across both arms.
const KNEE_RADIUS := 0.22
## The upper leg is this much longer than the lower.
const KNEE_EXTRA := 0.15
## The foot pad: broad and level.
const PAD := Vector3(0.8, 0.1, 0.8)
## The boss on the pad's top, round the strut's foot.
const BOSS := Vector3(0.52, 0.09, 0.52)
## Its collider is this tall, from the foot up.
const PAD_COLLIDER := 0.3
const BEVEL := 0.05
## The ramp's motor (LandingRamp.SOUND), quieter and lower.
const SOUND_DB := -7.0
const SOUND_PITCH := 0.8

const _ACROSS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

var state := State.STOWED
## The plan this was built from, one entry per leg (plan()).
var legs: Array[Dictionary] = []
## Every leg's colliders, on the hull body: enabled only while fully down.
var colliders: Array[CollisionShape3D] = []

## Seconds into the travel: 0 stowed, TRAVEL down.
var _t := 0.0
## Per leg: {upper, lower, pad: Node3D, length}.
var _parts: Array[Dictionary] = []
var _motor: AudioStreamPlayer3D

# --- where, pure -----------------------------------------------------------------

## Where `layout`'s legs go: one per quadrant (fore and aft, port and starboard
## of the footprint's middle), each as far out toward its corner as a mount
## allows, mirrored port and starboard when the hull is. Each entry is {cell:
## the mount, foot: the middle of the foot pad's underside in the hull's frame,
## on the stance plane (stance_for); length: from the mount's bottom face to
## the foot; side: +1 starboard, -1 port; end: +1 aft, -1 forward}. A mount is
## a cell with its bottom face open and whole, above the keel's plane (off the
## keel strip), not an airlock or a turret, whose leg is no longer than
## MOST_LENGTH and hangs through no block, no ramp's path or the cells beside
## it, and nowhere under or beside an engine or a downward thruster
## (keep_clear). With fewer mounts than quadrants it plans what fits.
##
## `lowest` is the lowest point of the hull's own look in its frame: NAN, the
## default, works it out from `layout` (ExteriorBuilder.lowest_look, which
## draws it off the tree: about 60-190 ms); the ship's rebuild passes what it
## drew. `catalog` null loads the blocks'. Pure.
static func plan(layout: ShipGrid, lowest := NAN, catalog: BlockCatalog = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if layout == null or layout.size() == 0:
		return out
	if is_nan(lowest):
		lowest = ExteriorBuilder.lowest_look(layout, catalog)
	var keel := Ship.keel_depth_of(layout)
	var stance := stance_for(keel, lowest)
	var box := _footprint(layout)
	var mid := box.get_center()
	var half := box.size * 0.5
	var clear := keep_clear(layout)
	var path := ramp_paths(layout, stance)
	var mounts := {}
	for c: Vector3i in layout.coords():
		var leg := _mount(layout, c, keel, stance, mid, clear, path)
		if not leg.is_empty():
			leg["score"] = _score(leg, mid, half)
			mounts[c] = leg
	var mirrored := _mirrored(layout, mid)
	for end: int in [-1, 1]:
		var pair: Array[Dictionary] = []
		if mirrored:
			pair = _best_pair(mounts, end, mid)
		if pair.is_empty():
			for side: int in [-1, 1]:
				var best := _best(mounts, side, end)
				if not best.is_empty():
					pair.append(best)
		for leg in pair:
			var entry := leg.duplicate()
			entry.erase("score")
			out.append(entry)
	return out

## How far under the hull's origin the feet stand, for a keel `keel` metres
## under it and a look whose lowest point is `lowest` (y, in the hull's frame;
## INF: none): CLEARANCE under the keel's plane at least, and HANG_CLEAR under
## the lowest look -- a belly turret's dome, a flood's housing -- so nothing
## that hangs touches the sand (the owner, 2026-11-05). Pure.
static func stance_for(keel: float, lowest: float) -> float:
	return maxf(keel + CLEARANCE, -lowest + HANG_CLEAR)

## Engines, and RCS blocks whose exhaust faces down: no leg hangs under or
## beside one. Pure.
static func keep_clear(layout: ShipGrid) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for c: Vector3i in layout.coords():
		var inst := layout.get_block(c)
		if inst.block_id == &"thruster":
			out.append(c)
		elif inst.block_id == &"rcs" and (BlockOrientation.basis_for(inst.orientation) * Vector3.FORWARD).y > 0.5:
			out.append(c)
	return out

## Every cell any landing ramp of `layout` passes through, coming down to a
## stance plane `stance` under the hull's origin: cell -> true. Pure.
static func ramp_paths(layout: ShipGrid, stance: float) -> Dictionary:
	var out := {}
	for c: Vector3i in layout.coords():
		if layout.get_block(c).block_id != AirlockSite.AIRLOCK_ID:
			continue
		for k: Vector3i in AirlockAlcove.ramp_plan(layout, c, stance)["path"]:
			out[k] = true
	return out

## The cells a leg from `cell` with its foot `foot_y` metres up the hull hangs
## through: the mount, down to the cell the foot is in. Pure.
static func column(cell: Vector3i, foot_y: float) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y in range(cell.y, roundi(foot_y / ShipGrid.CELL_SIZE) - 1, -1):
		out.append(Vector3i(cell.x, y, cell.z))
	return out

## The leg's frame for a mount at `cell` at end `end` (+1 aft, -1 forward), in
## the hull's frame. Pure.
static func frame(cell: Vector3i, end: int) -> Transform3D:
	var z := Vector3(0.0, 0.0, 1.0 if end >= 0 else -1.0)
	return Transform3D(Basis(Vector3.UP.cross(z), Vector3.UP, z),
		ShipGrid.cell_center(cell) + Vector3.DOWN * ShipGrid.CELL_SIZE * 0.5)

static func _footprint(layout: ShipGrid) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Vector3i in layout.coords():
		var p := ShipGrid.cell_center(c)
		lo = Vector2(minf(lo.x, p.x - 1.0), minf(lo.y, p.z - 1.0))
		hi = Vector2(maxf(hi.x, p.x + 1.0), maxf(hi.y, p.z + 1.0))
	return Rect2(lo, hi - lo)

## The leg a mount at `c` would have, or {} if it cannot be one.
static func _mount(layout: ShipGrid, c: Vector3i, keel: float, stance: float, mid: Vector2,
		clear: Array[Vector3i], path: Dictionary) -> Dictionary:
	var inst := layout.get_block(c)
	if inst.block_id == AirlockSite.AIRLOCK_ID or WeaponValues.is_turret(inst.block_id):
		return {}
	if layout.has_block(c + Vector3i.DOWN):
		return {}
	if not HullShapes.covers(HullShapes.shape_of(inst.block_id), inst.orientation, Vector3i.DOWN):
		return {}
	var centre := ShipGrid.cell_center(c)
	var bottom := centre.y - ShipGrid.CELL_SIZE * 0.5
	if bottom <= -keel + 0.01:
		return {}
	var length := bottom + stance
	if length > MOST_LENGTH + 0.001:
		return {}
	var side := _sign(centre.x - mid.x)
	var end := _sign(centre.z - mid.y)
	if side == 0 or end == 0:
		return {}
	var foot := frame(c, end) * foot_local(length)
	for k in column(c, foot.y):
		if k != c and layout.has_block(k):
			return {}
		if path.has(k):
			return {}
		for n in _ACROSS:
			if path.has(k + n):
				return {}
		for t in clear:
			var d := t - k
			if absi(d.x) + absi(d.y) + absi(d.z) <= 1 or (d.x == 0 and d.z == 0 and d.y > 0):
				return {}
	return {"cell": c, "foot": foot, "length": length, "side": side, "end": end}

## How far out toward its corner a leg stands, 0 at the middle to 1 at the
## footprint's edge, the nearer edge first; then the farther; then the
## shorter leg.
static func _score(leg: Dictionary, mid: Vector2, half: Vector2) -> Vector3:
	var p := ShipGrid.cell_center(leg["cell"])
	var across := absf(p.x - mid.x) / maxf(half.x, 0.001)
	var along := absf(p.z - mid.y) / maxf(half.y, 0.001)
	return Vector3(minf(across, along), across + along, -float(leg["length"]))

static func _better(a: Vector3, b: Vector3) -> bool:
	for i in 3:
		if absf(a[i] - b[i]) > 0.0001:
			return a[i] > b[i]
	return false

static func _best(mounts: Dictionary, side: int, end: int) -> Dictionary:
	var best := {}
	for leg: Dictionary in mounts.values():
		if leg["side"] != side or leg["end"] != end:
			continue
		if best.is_empty() or _better(leg["score"], best["score"]):
			best = leg
	return best

## The best starboard mount at `end` whose mirror across the middle is a mount
## too, with it: [port, starboard], or [] if none has one.
static func _best_pair(mounts: Dictionary, end: int, mid: Vector2) -> Array[Dictionary]:
	var best: Array[Dictionary] = []
	for leg: Dictionary in mounts.values():
		if leg["side"] != 1 or leg["end"] != end:
			continue
		var twin: Dictionary = mounts.get(_mirror(leg["cell"], mid), {})
		if twin.is_empty():
			continue
		if best.is_empty() or _better(leg["score"], best[1]["score"]):
			best = [twin, leg]
	return best

## `c` mirrored port to starboard across the footprint's middle, `mid` in
## metres: cell x and its twin's add up to twice the middle, in cells.
static func _mirror(c: Vector3i, mid: Vector2) -> Vector3i:
	return Vector3i(roundi(2.0 * mid.x / ShipGrid.CELL_SIZE) - c.x, c.y, c.z)

## Whether every cell has a twin across the middle.
static func _mirrored(layout: ShipGrid, mid: Vector2) -> bool:
	for c: Vector3i in layout.coords():
		if not layout.has_block(_mirror(c, mid)):
			return false
	return true

## Words for `layout`'s plan, `plan_legs`: ship_check's and the probe's legs
## line. It begins with how many legs fit, says what set the stance -- the
## keel's 0.4 m, or the lowest hanging look cleared by 0.1 -- and ends ONLY n
## FIT under four.
static func plan_words(layout: ShipGrid, plan_legs: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for leg in plan_legs:
		parts.append("%s %s %s %.2f m" % ["fore" if int(leg["end"]) < 0 else "aft",
			"port" if int(leg["side"]) < 0 else "starboard", leg["cell"], float(leg["length"])])
	var keel := Ship.keel_depth_of(layout)
	if plan_legs.is_empty():
		return "0: none fit, it stands on its keel %.2f m under the origin  <-- ONLY 0 FIT" % keel
	var stance := -(plan_legs[0]["foot"] as Vector3).y
	var under := stance - keel
	var why := "keel %.2f + %.2f" % [keel, under]
	if under > CLEARANCE + 0.001:
		why += ": its lowest look %.2f under the keel, cleared by %.2f" % [under - HANG_CLEAR, HANG_CLEAR]
	var words := "%d: %s; feet %.2f m under the origin (%s)" % [plan_legs.size(), ", ".join(parts), stance, why]
	if plan_legs.size() < 4:
		words += "  <-- ONLY %d FIT" % plan_legs.size()
	return words

static func _sign(v: float) -> int:
	if v > 0.01:
		return 1
	if v < -0.01:
		return -1
	return 0

# --- when, pure --------------------------------------------------------------------

## Whether the legs should be down: always while landed; never off a world;
## on one, down under DOWN_BELOW metres of `keel_altitude`, up over UP_ABOVE,
## and as they were (`was_down`) between. Pure.
static func wanted(was_down: bool, on_world: bool, landed: bool, keel_altitude: float) -> bool:
	if landed:
		return true
	if not on_world:
		return false
	if keel_altitude < DOWN_BELOW:
		return true
	if keel_altitude > UP_ABOVE:
		return false
	return was_down

# --- the shape, pure ---------------------------------------------------------------

## The upper and lower legs' lengths, hinge to knee and knee to ankle, for a
## leg `length` long: the foot pad's underside lands `length` under the mount
## once down. Pure.
static func parts_for(length: float) -> Vector2:
	var s := sin(SPLAY)
	var lower := (length + HINGE_Y - PAD.y - KNEE_EXTRA * s) / (1.0 + s)
	return Vector2(lower + KNEE_EXTRA, lower)

## The hinge, in the leg's frame: under the mount, half the upper leg back from
## the middle, so a stowed leg lies centred under its mount.
static func hinge_local(length: float) -> Vector3:
	return Vector3(0.0, HINGE_Y, -parts_for(length).x * 0.5)

## The middle of the foot pad's underside once down, in the leg's frame.
static func foot_local(length: float) -> Vector3:
	var hinge := hinge_local(length)
	return Vector3(0.0, -length, hinge.z + parts_for(length).x * cos(SPLAY))

## Along a leg at `angle` (radians below level, toward the leg's end), in the
## leg's frame.
static func along(angle: float) -> Vector3:
	return Vector3(0.0, -sin(angle), cos(angle))

## A leg `length` long, `t` seconds into its travel: {upper: the upper leg's
## angle below level; lower: the lower leg's; hinge, knee, ankle; foot: the
## middle of the pad's underside; pad_top; lowest: the lowest point of the
## whole leg}, in the leg's frame. Stowed (t 0) both legs lie level, the lower
## folded back between the upper's arms; it folds out to SPLAY by FOLD_TIME,
## then the knee opens until the lower leg points straight down. Pure.
static func pose(length: float, t: float) -> Dictionary:
	var parts := parts_for(length)
	var upper: float
	var lower: float
	if t <= FOLD_TIME:
		upper = smoothstep(0.0, FOLD_TIME, t) * SPLAY
		lower = upper + PI
	else:
		upper = SPLAY
		lower = lerpf(SPLAY + PI, PI * 0.5, smoothstep(FOLD_TIME, TRAVEL, t))
	var hinge := hinge_local(length)
	var knee := hinge + along(upper) * parts.x
	var ankle := knee + along(lower) * parts.y
	var pad_top := ankle.y - STRUT * 0.5 * absf(along(lower).z)
	var foot := Vector3(ankle.x, pad_top - PAD.y, ankle.z)
	var lowest := minf(foot.y, minf(knee.y - KNEE_RADIUS, hinge.y - ARM_HEIGHT * 0.5))
	return {"upper": upper, "lower": lower, "hinge": hinge, "knee": knee, "ankle": ankle, "foot": foot,
		"pad_top": pad_top, "lowest": lowest}

# --- the node ------------------------------------------------------------------------

## Builds stowed legs under `parent` (which shares `body`'s frame) for each
## entry of `plan_legs`, with their colliders on `body`, disabled.
static func build(parent: Node3D, body: CollisionObject3D, plan_legs: Array[Dictionary]) -> LandingLegs:
	var node := LandingLegs.new()
	node.name = "LandingLegs"
	node.legs = plan_legs.duplicate()
	parent.add_child(node)
	node._make(body)
	return node

func _make(body: CollisionObject3D) -> void:
	for i in legs.size():
		var leg := legs[i]
		var root := Node3D.new()
		root.name = "Leg_%d_%d_%d" % [leg["cell"].x, leg["cell"].y, leg["cell"].z]
		root.transform = frame(leg["cell"], leg["end"])
		add_child(root)
		var length: float = leg["length"]
		var parts := parts_for(length)
		var housing := _node(root, "Housing")
		var upper := _node(root, "Upper")
		var lower := _node(root, "Lower")
		var pad := _node(root, "Pad")
		_draw_housing(_kit(housing), length)
		_draw_upper(_kit(upper), parts.x)
		_draw_lower(_kit(lower), parts.y)
		_draw_pad(_kit(pad))
		_parts.append({"upper": upper, "lower": lower, "pad": pad, "length": length})
		for c in _make_colliders(root.transform, length, leg["cell"]):
			body.add_child(c)
			colliders.append(c)
	_motor = AudioStreamPlayer3D.new()
	_motor.name = "Motor"
	_motor.bus = AudioBuses.SHIP
	_motor.unit_size = 3.0
	_motor.max_distance = 30.0
	_motor.volume_db = SOUND_DB
	_motor.pitch_scale = SOUND_PITCH
	add_child(_motor)
	_apply()

static func _node(parent: Node3D, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	parent.add_child(n)
	return n

## A kit drawing on the own hull's layer, as the ramp's does, in the hull's
## trim material: flat vertex colour.
func _kit(root: Node3D) -> InteriorKit:
	var kit := InteriorKit.new(root)
	kit.layer = ExteriorBuilder.OWN_HULL_LAYER
	kit.light_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	kit.materials = {InteriorKit.Batch.SOLID: HullMaterials.trim()}
	return kit

## Commits a kit's pieces, casting shadows: a leg's shadow on the sand is half
## of what makes it read as standing.
static func _commit(kit: InteriorKit) -> void:
	for mi in kit.commit():
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

## The hinge housing, fixed under the mount, and the hinge's barrel through it.
func _draw_housing(kit: InteriorKit, length: float) -> void:
	var hinge := hinge_local(length)
	var trim := InteriorKit.solid(HullPalette.TRIM)
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0.0, -HOUSING.y * 0.5 + 0.02, hinge.z)),
		HOUSING + Vector3(0.0, 0.04, 0.0), BEVEL, trim)
	kit.tube_x(InteriorKit.Batch.SOLID, InteriorKit.at(hinge), BARREL_RADIUS, HOUSING.x + 0.08, trim)
	_commit(kit)

## The upper leg, in its own frame (origin on the hinge, +z along it): two arms
## with the lower leg folding between them, and the knee knuckle across their
## ends in the panel line's grey.
func _draw_upper(kit: InteriorKit, upper_length: float) -> void:
	var plate := InteriorKit.solid(HullPalette.PLATE)
	for side: float in [-1.0, 1.0]:
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(side * ARM_X, 0.0, upper_length * 0.5)),
			Vector3(ARM_WIDTH, ARM_HEIGHT, upper_length + ARM_HEIGHT * 0.5), BEVEL, plate)
	kit.tube_x(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0.0, 0.0, upper_length)), KNEE_RADIUS,
		ARM_X * 2.0 + ARM_WIDTH + 0.04, InteriorKit.solid(HullPalette.PANEL_LINE))
	_commit(kit)

## The lower leg, in its own frame (origin on the knee, +z along it to the
## ankle): one square strut.
func _draw_lower(kit: InteriorKit, lower_length: float) -> void:
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0.0, 0.0, lower_length * 0.5)),
		Vector3(STRUT, STRUT, lower_length), BEVEL, InteriorKit.solid(HullPalette.PLATE))
	_commit(kit)

## The foot pad, level, in its own frame (origin in the middle of its top): a
## broad bevelled plate and a boss where the strut meets it.
func _draw_pad(kit: InteriorKit) -> void:
	var trim := InteriorKit.solid(HullPalette.TRIM)
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0.0, -PAD.y * 0.5, 0.0)), PAD, 0.03, trim)
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0.0, BOSS.y * 0.5 - 0.01, 0.0)), BOSS, 0.025, trim)
	_commit(kit)

## A fully down leg's colliders, in the hull body's frame: the pad (PAD_COLLIDER
## tall, from the foot up), the lower strut and the upper leg. Each carries its
## mount's cell, as the hull's own colliders do, so a hit on a leg lands on its
## mount (ShipCells.hull_cell).
static func _make_colliders(leg_frame: Transform3D, length: float, cell: Vector3i) -> Array[CollisionShape3D]:
	var down := pose(length, TRAVEL)
	var parts := parts_for(length)
	var foot: Vector3 = down["foot"]
	var knee: Vector3 = down["knee"]
	var hinge: Vector3 = down["hinge"]
	var out: Array[CollisionShape3D] = []
	out.append(_collider("LegPad", Vector3(PAD.x, PAD_COLLIDER, PAD.z),
		leg_frame * InteriorKit.at(foot + Vector3.UP * PAD_COLLIDER * 0.5), cell))
	var strut_top := knee.y
	var strut_bottom := foot.y + PAD_COLLIDER
	out.append(_collider("LegStrut", Vector3(STRUT, strut_top - strut_bottom, STRUT),
		leg_frame * InteriorKit.at(Vector3(knee.x, (strut_top + strut_bottom) * 0.5, knee.z)), cell))
	out.append(_collider("LegUpper", Vector3(ARM_X * 2.0 + ARM_WIDTH, ARM_HEIGHT, parts.x),
		leg_frame * Transform3D(Basis(Vector3.RIGHT, SPLAY), hinge) * InteriorKit.at(Vector3(0.0, 0.0, parts.x * 0.5)),
		cell))
	return out

static func _collider(collider_name: String, size: Vector3, xform: Transform3D, cell: Vector3i) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var c := CollisionShape3D.new()
	c.name = collider_name
	c.shape = shape
	c.transform = xform
	c.disabled = true
	c.set_meta(&"cell", cell)
	return c

# --- down and up -----------------------------------------------------------------

func is_down() -> bool:
	return state == State.DOWN

func is_stowed() -> bool:
	return state == State.STOWED

## How far along its travel it is: 0 stowed, 1 down.
func progress() -> float:
	return _t / TRAVEL

## Down (or up, `down` false), animated or `instant`ly. Asking for where they
## are going already does nothing, unless `instant` finishes the travel now.
func set_down(down: bool, instant := false) -> void:
	if down:
		if state == State.STOWED or state == State.STOWING:
			_go(State.DEPLOYING, instant)
		elif instant and state == State.DEPLOYING:
			_finish(State.DOWN)
	else:
		if state == State.DOWN or state == State.DEPLOYING:
			_go(State.STOWING, instant)
		elif instant and state == State.STOWING:
			_finish(State.STOWED)

## Starts moving: the colliders are off the moment they leave DOWN.
func _go(next: State, instant: bool) -> void:
	_enable(false)
	if instant:
		_finish(State.DOWN if next == State.DEPLOYING else State.STOWED)
		return
	if state == State.STOWED or state == State.DOWN:
		_play()
	state = next
	_apply()

func _finish(at: State) -> void:
	state = at
	_t = TRAVEL if at == State.DOWN else 0.0
	_apply()
	_enable(at == State.DOWN)

func _enable(on: bool) -> void:
	for c in colliders:
		if is_instance_valid(c):
			c.disabled = not on

func _process(delta: float) -> void:
	match state:
		State.DEPLOYING:
			_t = minf(_t + delta, TRAVEL)
			if _t >= TRAVEL:
				_finish(State.DOWN)
			else:
				_apply()
		State.STOWING:
			_t = maxf(_t - delta, 0.0)
			if _t <= 0.0:
				_finish(State.STOWED)
			else:
				_apply()

## Each leg where it is along the travel.
func _apply() -> void:
	for p in _parts:
		var at := pose(p["length"], _t)
		(p["upper"] as Node3D).transform = Transform3D(Basis(Vector3.RIGHT, at["upper"]), at["hinge"])
		(p["lower"] as Node3D).transform = Transform3D(Basis(Vector3.RIGHT, at["lower"]), at["knee"])
		var ankle: Vector3 = at["ankle"]
		(p["pad"] as Node3D).transform = InteriorKit.at(Vector3(ankle.x, at["pad_top"], ankle.z))

## Where each foot is now, the middle of its pad's underside, in the world.
func feet() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in _parts.size():
		var pad: Node3D = _parts[i]["pad"]
		out.append(pad.global_transform * Vector3(0.0, -PAD.y, 0.0))
	return out

func _play() -> void:
	var s := Synth.sound(LandingRamp.SOUND)
	if s == null or not is_inside_tree():
		return
	_motor.stream = s
	_motor.play()
