class_name ShipSite
extends NpcSite

## A ship's interior as a place NPCs live (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §4.2, §5.5, §14.2): its frame is the
## interior's, which never moves; its gravity is the interior's felt gravity,
## the same number every loose item gets; and it keeps the droid's map, its
## dock and its jobs, rebuilt with the ship.

var ship: Ship
var layout: InteriorLayout
var paths: DeckPaths
var dock := ShipCrew.NO_DOCK
var spots: Array[Dictionary] = []
## Work spot key -> director time it was last tended.
var tended := {}
## Bumped by every rebind, so a walker knows its path may be stale.
var version := 0
## [floor point, zone]: one per room, and a few of the open cells.
var _rooms: Array = []

## A job is worked from this far toward its wall, from the cell's centre.
const SPOT_REACH := 0.45
## How far aside it steps within its own cell to let you by.
const SIDE_STEP := 0.6
## Fear fades this much a second while nothing startles it.
const FEAR_FADES := 0.1
## A job never done counts as done this long ago.
const NEVER := 999.0

func _init(p_ship: Ship) -> void:
	ship = p_ship
	id = StringName("ship:%s" % p_ship.name)

## Re-reads the ship after a rebuild: its map, its dock, its jobs. Cells with
## no plating are left off the map (spec §5.5).
func rebind(p_layout: InteriorLayout) -> void:
	var avoid: Array[Vector3i] = []
	for cell in p_layout.walkable_coords():
		if ship.interior_builder.gravity_at(cell) <= 0.0:
			avoid.append(cell)
	layout = p_layout
	paths = DeckPaths.build(layout, avoid)
	dock = ShipCrew.dock(layout, paths)
	spots = ShipCrew.work_spots(layout, paths)
	_rooms.clear()
	var seen := {}
	var open: Array[Vector3i] = []
	for cell in paths.cells():
		var zone := layout.zone_at(cell)
		if InteriorLayout.ROOM_IDS.has(zone):
			if not seen.has(zone):
				seen[zone] = true
				_rooms.append([DeckPaths.floor_point(cell), zone])
		else:
			open.append(cell)
	for i in range(0, open.size(), 3):
		_rooms.append([DeckPaths.floor_point(open[i]), layout.zone_at(open[i])])
	version += 1

func frame() -> Transform3D:
	return ship.interior.global_transform

## Plating plus the hull's shove, as MotionCoupling sets it each tick.
func gravity(_local: Vector3) -> Vector3:
	var felt := ship.interior_builder.felt_gravity
	return felt.felt if felt != null else Vector3.DOWN * InteriorBuilder.DEFAULT_GRAVITY

func alive() -> bool:
	return is_instance_valid(ship) and ship.interior_builder.layout() != null and paths != null

## A job finished at `time`.
func tend(key: StringName, time: float) -> void:
	tended[key] = time

## What its behaviours may ask of the ship (spec §14): its dock, its jobs and
## how long since each was done, a point in every room with the room's zone,
## the spots it could step aside to, where the player is, and a way to say a
## job is done. Fear fades by itself while nothing startles it.
func fill(ctx: NpcContext, _npc: Npc) -> void:
	if dock != ShipCrew.NO_DOCK:
		ctx.places[&"dock"] = DeckPaths.floor_point(dock)
	for spot in spots:
		var s := spot.duplicate()
		s["at"] = DeckPaths.floor_point(spot["cell"]) + Vector3(spot["facing"]) * SPOT_REACH
		s["since"] = ctx.time - float(tended.get(spot["key"], -NEVER))
		ctx.spots.append(s)
	ctx.extra[&"rooms"] = _rooms
	ctx.extra[&"nearby"] = nearby(ctx.position)
	ctx.extra[&"tended"] = tend
	var seen: Variant = Behaviour.player_at(ctx)
	if seen != null:
		ctx.extra[&"player_zone"] = zone_at(seen)
	ctx.extra[&"zone"] = zone_at(ctx.position)
	if ctx.recent(Stimulus.TOUCH, 2.0) == null and ctx.recent(Stimulus.SOUND, 2.0) == null:
		ctx.ease(&"fear", FEAR_FADES)

## The zone of the cell a point is in: a room's id, bridge or common.
func zone_at(local: Vector3) -> StringName:
	return layout.zone_at(DeckPaths.cell_at(local)) if layout != null else &""

## Places it could step to from `local`: its own cell's sides, and the cells
## next to it.
func nearby(local: Vector3) -> Array:
	var out: Array = []
	var cell := DeckPaths.cell_at(local)
	if paths == null or not paths.has(cell):
		return out
	var centre := DeckPaths.floor_point(cell)
	for side in [Vector3(SIDE_STEP, 0, 0), Vector3(-SIDE_STEP, 0, 0), Vector3(0, 0, SIDE_STEP), Vector3(0, 0, -SIDE_STEP)]:
		out.append(centre + side)
	for n in paths.neighbours(cell):
		out.append(DeckPaths.floor_point(n))
	return out
