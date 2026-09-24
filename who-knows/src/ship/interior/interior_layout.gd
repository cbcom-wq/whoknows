class_name InteriorLayout
extends RefCounted

## Decides what every interior face is, once, for both InteriorBuilder
## (structure) and InteriorDressing (props): a floor and a ceiling per
## walkable cell, and for each horizontal face that does not open onto
## another walkable cell, either a canopy face or a wall with exactly one
## variant (docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md
## §5.1).
##
## A record is {coord, normal, kind, variant, zone, porthole, owner}. `zone`
## is the cell's: bridge for the command area, common otherwise. `porthole`
## tells the builder to cut one. `owner` says which record builds a face's
## structure; every face has exactly one.
##
## Pure: reads the grid, returns records, touches no nodes. The same grid
## always yields the same layout.

enum Kind { FLOOR, CEILING, WALL, CANOPY }
enum WallVariant { NONE, HATCH, CONSOLE, PORTHOLE, LOCKERS, DISPLAY, PANEL }

const ZONE_BRIDGE := &"bridge"
const ZONE_COMMON := &"common"
const CANOPY_ID := &"canopy"
const AIRLOCK_ID := &"airlock"
const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _faces: Array[Dictionary] = []
var _groups: Array[Dictionary] = []
var _walkable: Array[Vector3i] = []

static func plan(grid: ShipGrid, catalog: BlockCatalog, walkable: Array) -> InteriorLayout:
	var layout := InteriorLayout.new()
	layout._walkable.assign(walkable)
	var walkable_set := {}
	for coord in walkable:
		walkable_set[coord] = true
	var groups := {}   # plane key -> {normal, coords}
	for coord: Vector3i in layout._walkable:
		var is_mount := _is_mount(grid, catalog, coord)
		var by_the_helm := _has_mount_neighbour(grid, catalog, coord) or _has_canopy_neighbour(grid, coord)
		var zone := ZONE_BRIDGE if is_mount or by_the_helm else ZONE_COMMON
		layout._faces.append(_record(coord, Vector3i.DOWN, Kind.FLOOR, zone))
		layout._faces.append(_record(coord, Vector3i.UP, Kind.CEILING, zone))
		for normal in _HORIZONTAL:
			var neighbour := coord + normal
			if walkable_set.has(neighbour):
				continue   # open passage between two walkable cells
			if _id_at(grid, neighbour) == CANOPY_ID:
				layout._faces.append(_record(coord, normal, Kind.CANOPY, zone))
				var key := "%s:%d:%d" % [normal, _along(neighbour, normal), coord.y]
				groups.get_or_add(key, {"normal": normal, "coords": []})["coords"].append(coord)
				continue
			var face := _record(coord, normal, Kind.WALL, zone)
			var variant := _common_variant(grid, coord, normal, is_mount, by_the_helm)
			face["variant"] = variant
			face["porthole"] = variant == WallVariant.PORTHOLE
			layout._faces.append(face)
	for key in groups:
		layout._groups.append(groups[key])
	return layout

func faces() -> Array[Dictionary]:
	return _faces.duplicate()

## One entry per windshield plane: {normal, coords} -- the walkable cells
## whose face on that plane is canopy. InteriorDressing builds one rounded
## nose over each.
func canopy_groups() -> Array[Dictionary]:
	return _groups.duplicate()

func walkable_coords() -> Array[Vector3i]:
	return _walkable.duplicate()

## A stable integer per face, for choosing between equally good variants and
## for seeding what a prop's screens show. Not random: the same face on the
## same ship always gets the same answer.
static func face_hash(coord: Vector3i, normal: Vector3i) -> int:
	return absi((coord.x * 73856093) ^ (coord.y * 19349663) ^ (coord.z * 83492791)
		^ (normal.x * 2654435761) ^ (normal.z * 40503))

static func _record(coord: Vector3i, normal: Vector3i, kind: Kind, zone: StringName) -> Dictionary:
	return {
		"coord": coord, "normal": normal, "kind": kind, "variant": WallVariant.NONE,
		"zone": zone, "porthole": false, "owner": true,
	}

## Wall variants for bridge and common cells, in strict priority order.
static func _common_variant(grid: ShipGrid, coord: Vector3i, normal: Vector3i,
		is_mount: bool, by_the_helm: bool) -> WallVariant:
	if _id_at(grid, coord) == AIRLOCK_ID and not grid.has_block(coord + normal):
		return WallVariant.HATCH
	var skin_flank := normal.x != 0 and _is_outer_skin(grid, coord, normal)
	if is_mount:
		# The cell's own fixture stands here; nothing that sticks out may too.
		return WallVariant.PORTHOLE if skin_flank else WallVariant.PANEL
	if by_the_helm:
		return WallVariant.CONSOLE
	if skin_flank:
		return WallVariant.PORTHOLE
	return WallVariant.LOCKERS if face_hash(coord, normal) % 2 == 0 else WallVariant.DISPLAY

## Outer skin: at most one solid cell stands between this face and vacuum,
## so a porthole here looks out rather than into machinery.
static func _is_outer_skin(grid: ShipGrid, coord: Vector3i, normal: Vector3i) -> bool:
	var neighbour := coord + normal
	return not grid.has_block(neighbour) or not grid.has_block(neighbour + normal)

static func _has_canopy_neighbour(grid: ShipGrid, coord: Vector3i) -> bool:
	for normal in _HORIZONTAL:
		if _id_at(grid, coord + normal) == CANOPY_ID:
			return true
	return false

static func _has_mount_neighbour(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> bool:
	for normal in _HORIZONTAL:
		if _is_mount(grid, catalog, coord + normal):
			return true
	return false

static func _is_mount(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> bool:
	var inst := grid.get_block(coord)
	if inst == null:
		return false
	var def := catalog.get_def(inst.block_id)
	return def != null and def.occupancy == BlockDefinition.Occupancy.MOUNT

static func _id_at(grid: ShipGrid, coord: Vector3i) -> StringName:
	var inst := grid.get_block(coord)
	return inst.block_id if inst != null else &""

## The coordinate that identifies a face's plane along its normal's axis.
static func _along(coord: Vector3i, normal: Vector3i) -> int:
	return coord.x if normal.x != 0 else coord.z
