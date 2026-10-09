class_name Planting
extends RefCounted

## Where a module fits, and why not (habitat modules spec §5.2), as a pure
## function of the ground (a PlantSurface), the module, where you aim and the
## base it would join. A new hub founds a frame: the ground's up, turned to
## face you. Anything else snaps to its base's grid in quarter turns, at the
## lowest storey whose legs all reach the ground. Each module stands on four
## legs at its footprint's corners.

enum Fit { OK, NO_GROUND, TOO_STEEP, LEGS_CANT_REACH, BLOCKED, TOO_FAR, HUB_FIRST, NEAR_SHIP, NO_ROOM }

const PROMPTS := {
	Fit.NO_GROUND: "",
	Fit.TOO_STEEP: "Too steep",
	Fit.LEGS_CANT_REACH: "Legs can't reach",
	Fit.BLOCKED: "Blocked",
	Fit.TOO_FAR: "Too far from the base",
	Fit.HUB_FIRST: "Plant a hub first",
	Fit.NEAR_SHIP: "Too close to a ship",
	Fit.NO_ROOM: "No room",
}
## The legs stand this far in from the footprint's corners.
const LEG_INSET := 0.25
## Storeys tried above and below the base's floor.
const STOREYS := 2

class Result:
	var fit: int = Fit.NO_GROUND
	## The base's frame (a new hub's own), engine space: origin at the centre
	## of base cell (0, 0, 0), y the base's up.
	var frame := Transform3D.IDENTITY
	var cell := Vector3i.ZERO
	var turns := 0
	## The body's centre and rotation, engine space, and its extents.
	var body := Transform3D.IDENTITY
	var size := Vector3.ZERO
	var legs := PackedFloat32Array()
	var feet := PackedVector3Array()

static func prompt(r: Result, module: ModuleDefinition) -> String:
	if r.fit == Fit.OK:
		return "Plant %s" % module.display_name
	return PROMPTS.get(r.fit, "")

## The fit of `module` turned `turns` quarter turns, aimed at `aim` (a point on
## the ground, engine space) from `facing`. `site` and `frame` are the base it
## would join, or null for none; `ship_gap` is how far `aim` is from the
## nearest hull; `slots_free` whether a new base could get an interior slot.
static func fit(surface: PlantSurface, module: ModuleDefinition, aim: Vector3, facing: Vector3, turns: int,
		site: BaseSite = null, frame := Transform3D.IDENTITY, ship_gap := INF, slots_free := true) -> Result:
	var r := Result.new()
	r.turns = posmod(turns, 4)
	var size := module.turned_size(r.turns)
	r.size = Vector3(size) * ShipGrid.CELL_SIZE - Vector3.ONE * 0.1
	if site == null and module.kind != ModuleCatalog.HUB:
		r.fit = Fit.HUB_FIRST
		return r
	if site == null and not slots_free:
		r.fit = Fit.NO_ROOM
		return r
	if site == null:
		if not _found(surface, size, aim, facing, r):
			return r
	elif not _snap(surface, size, aim, site, frame, r):
		return r
	var normal := _average_normal(surface, r)
	if normal.angle_to(r.frame.basis.y) > HabitatValues.MAX_TILT:
		r.fit = Fit.TOO_STEEP
		return r
	if not _legs_reach(r.legs):
		r.fit = Fit.LEGS_CANT_REACH
		return r
	if surface.blocked(r.body, r.size) or (site != null and _crowds(site, module, r)):
		r.fit = Fit.BLOCKED
		return r
	if site != null and _far(site, r):
		r.fit = Fit.TOO_FAR
		return r
	if ship_gap < HabitatValues.FROM_SHIP:
		r.fit = Fit.NEAR_SHIP
		return r
	r.fit = Fit.OK
	return r

## The leg tops, frame-local, of a module of turned `size` at cell zero: its
## footprint's corners, LEG_INSET in, at the underside of its floor.
static func corners(size: Vector3i) -> Array[Vector3]:
	var half := ShipGrid.CELL_SIZE * 0.5
	var x0 := -half + LEG_INSET
	var x1 := (size.x - 1) * ShipGrid.CELL_SIZE + half - LEG_INSET
	var z0 := -half + LEG_INSET
	var z1 := (size.z - 1) * ShipGrid.CELL_SIZE + half - LEG_INSET
	return [Vector3(x0, -half, z0), Vector3(x1, -half, z0), Vector3(x0, -half, z1), Vector3(x1, -half, z1)]

## A new hub: the ground's up, turned to face `facing`, raised so the highest
## ground under its legs is LEG_MIN + LEG_SPARE below the floor.
static func _found(surface: PlantSurface, size: Vector3i, aim: Vector3, facing: Vector3, r: Result) -> bool:
	var up := surface.up_at(aim).normalized()
	var forward := facing - up * facing.dot(up)
	if forward.length() < 0.01:
		forward = up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK)
	var basis := Basis.looking_at(forward.normalized(), up) * Basis(Vector3.UP, PI * 0.5 * r.turns)
	var centre := Vector3(size - Vector3i.ONE) * ShipGrid.CELL_SIZE * 0.5
	centre.y = 0.0
	var origin := aim - basis * centre
	var highest := -INF
	var hits := []
	for top in corners(size):
		var p := origin + basis * Vector3(top.x, 0.0, top.z)
		var hit := surface.cast(p + up * HabitatValues.CAST_SPARE, -up,
			HabitatValues.CAST_SPARE * 2.0 + HabitatValues.LEG_MAX)
		if hit.is_empty():
			r.fit = Fit.NO_GROUND if hits.is_empty() else Fit.LEGS_CANT_REACH
			r.frame = Transform3D(basis, origin + up * ShipGrid.CELL_SIZE * 0.5)
			return false
		hits.append(hit)
		highest = maxf(highest, (hit["position"] - aim).dot(up))
	var floor_at := highest + HabitatValues.LEG_MIN + HabitatValues.LEG_SPARE
	r.frame = Transform3D(basis, origin + up * (floor_at + ShipGrid.CELL_SIZE * 0.5))
	r.cell = Vector3i.ZERO
	_place(surface, size, r)
	return true

## A module joining a base: its cell under the aim on the base's grid, at the
## lowest storey whose legs all reach. If none reach, the storey whose legs
## come nearest, so fit() can still say whether it is too steep first.
static func _snap(surface: PlantSurface, size: Vector3i, aim: Vector3, _site: BaseSite, frame: Transform3D,
		r: Result) -> bool:
	r.frame = frame
	var local := frame.affine_inverse() * aim
	var cx := roundi(local.x / ShipGrid.CELL_SIZE - (size.x - 1) * 0.5)
	var cz := roundi(local.z / ShipGrid.CELL_SIZE - (size.z - 1) * 0.5)
	var nearest := Vector3i.ZERO
	var nearest_off := INF
	var mid := (HabitatValues.LEG_MIN + HabitatValues.LEG_MAX) * 0.5
	for y in range(-STOREYS, STOREYS + 1):
		r.cell = Vector3i(cx, y, cz)
		_place(surface, size, r)
		if r.legs.size() < 4:
			continue
		if _legs_reach(r.legs):
			return true
		var off := 0.0
		for leg in r.legs:
			off = maxf(off, absf(leg - mid))
		if off < nearest_off:
			nearest_off = off
			nearest = r.cell
	if nearest_off == INF:
		r.fit = Fit.NO_GROUND
		return false
	r.cell = nearest
	_place(surface, size, r)
	return true

static func _legs_reach(legs: PackedFloat32Array) -> bool:
	for leg in legs:
		if leg < HabitatValues.LEG_MIN - 0.001 or leg > HabitatValues.LEG_MAX + 0.001:
			return false
	return true

## Fills the body, legs and feet of `r` at its cell in its frame.
static func _place(surface: PlantSurface, size: Vector3i, r: Result) -> void:
	var at := ShipGrid.cell_center(r.cell)
	var centre := at + Vector3(size - Vector3i.ONE) * ShipGrid.CELL_SIZE * 0.5
	r.body = Transform3D(r.frame.basis, r.frame * centre)
	r.legs = PackedFloat32Array()
	r.feet = PackedVector3Array()
	var up := r.frame.basis.y
	for top in corners(size):
		var p := r.frame * (at + top)
		var hit := surface.cast(p + up * HabitatValues.CAST_SPARE, -up,
			HabitatValues.CAST_SPARE * 2.0 + HabitatValues.LEG_MAX)
		if hit.is_empty():
			return
		r.legs.append((p - hit["position"]).dot(up))
		r.feet.append(hit["position"])

static func _average_normal(surface: PlantSurface, r: Result) -> Vector3:
	var sum := Vector3.ZERO
	var up := r.frame.basis.y
	for foot in r.feet:
		var hit := surface.cast(foot + up * 0.5, -up, 1.0)
		if not hit.is_empty():
			sum += hit["normal"]
	return sum.normalized() if sum.length() > 0.001 else up

## True if any of its cells, or any cell beside one, is another module's.
static func _crowds(site: BaseSite, module: ModuleDefinition, r: Result) -> bool:
	var taken := site.occupied()
	for b: Array in module.turned(r.turns):
		var c: Vector3i = r.cell + (b[0] as Vector3i)
		if taken.has(c):
			return true
		for n: Vector3i in ShipGrid.FACE_OFFSETS:
			if taken.has(c + n):
				return true
	return false

## True if its body is more than FROM_BASE from every module's.
static func _far(site: BaseSite, r: Result) -> bool:
	var here := r.frame.affine_inverse() * r.body.origin
	for i in site.modules.size():
		if site.centre_of(i).distance_to(here) <= HabitatValues.FROM_BASE:
			return false
	return true
