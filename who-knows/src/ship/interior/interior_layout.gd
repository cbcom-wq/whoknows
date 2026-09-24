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
## Rooms (spec §7.2): a face between two walkable cells of different rooms is
## a partition, with a record on each side and one owner. Each room gets
## exactly one doorway (kind DOORWAY on both records), and each room cell
## picks one FEATURE wall for its main furniture and at most one SECONDARY
## wall beside it for a smaller piece; the rest keep their trim (PANEL).
##
## Pure: reads the grid, returns records, touches no nodes. The same grid
## always yields the same layout.

enum Kind { FLOOR, CEILING, WALL, CANOPY, DOORWAY }
enum WallVariant { NONE, HATCH, CONSOLE, PORTHOLE, LOCKERS, DISPLAY, PANEL, FEATURE, SECONDARY }

## Walkable blocks that make a room (spec §7.1). Any other walkable cell is
## bridge or common space.
const ROOM_IDS: Array[StringName] = [&"bunk_room", &"galley", &"bathroom", &"closet", &"weapon_room"]

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
var _zones: Dictionary = {}   # Vector3i -> StringName
var _rooms: Array[Dictionary] = []

static func plan(grid: ShipGrid, catalog: BlockCatalog, walkable: Array) -> InteriorLayout:
	var layout := InteriorLayout.new()
	layout._walkable.assign(walkable)
	var walkable_set := {}
	for coord in walkable:
		walkable_set[coord] = true
	# Zones first: a partition needs to know both sides.
	for coord: Vector3i in layout._walkable:
		layout._zones[coord] = _zone(grid, catalog, coord)
	var groups := {}   # plane key -> {normal, coords}
	for coord: Vector3i in layout._walkable:
		var zone: StringName = layout._zones[coord]
		var in_room := ROOM_IDS.has(zone)
		var is_mount := _is_mount(grid, catalog, coord)
		var by_the_helm := _has_mount_neighbour(grid, catalog, coord) or _has_canopy_neighbour(grid, coord)
		layout._faces.append(_record(coord, Vector3i.DOWN, Kind.FLOOR, zone))
		layout._faces.append(_record(coord, Vector3i.UP, Kind.CEILING, zone))
		for normal in _HORIZONTAL:
			var neighbour := coord + normal
			if walkable_set.has(neighbour):
				if _room_of(layout._zones[neighbour]) == _room_of(zone):
					continue   # open passage within one space
				var partition := _record(coord, normal, Kind.WALL, zone)
				partition["partition"] = true
				partition["owner"] = coord < neighbour
				partition["variant"] = WallVariant.PANEL if in_room else _common_variant(
					grid, coord, normal, is_mount, by_the_helm, true)
				layout._faces.append(partition)
				continue
			if _id_at(grid, neighbour) == CANOPY_ID:
				layout._faces.append(_record(coord, normal, Kind.CANOPY, zone))
				var key := "%s:%d:%d" % [normal, _along(neighbour, normal), coord.y]
				groups.get_or_add(key, {"normal": normal, "coords": []})["coords"].append(coord)
				continue
			var face := _record(coord, normal, Kind.WALL, zone)
			face["skin_flank"] = normal.x != 0 and _is_outer_skin(grid, coord, normal)
			if in_room:
				face["variant"] = WallVariant.PANEL
			else:
				var variant := _common_variant(grid, coord, normal, is_mount, by_the_helm, false)
				face["variant"] = variant
				face["porthole"] = variant == WallVariant.PORTHOLE
			layout._faces.append(face)
	for key in groups:
		layout._groups.append(groups[key])
	layout._resolve_rooms()
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

## Every room: {zone, coords, doorway}, where doorway is {coord, normal} of
## the face chosen as its way in, or {} for a room with no neighbour at all.
func rooms() -> Array[Dictionary]:
	return _rooms.duplicate()

## A walkable cell's zone: its room id, or ZONE_BRIDGE / ZONE_COMMON.
func zone_at(coord: Vector3i) -> StringName:
	return _zones.get(coord, &"")

## A stable integer per face, for choosing between equally good variants and
## for seeding what a prop's screens show. Not random: the same face on the
## same ship always gets the same answer.
static func face_hash(coord: Vector3i, normal: Vector3i) -> int:
	return absi((coord.x * 73856093) ^ (coord.y * 19349663) ^ (coord.z * 83492791)
		^ (normal.x * 2654435761) ^ (normal.z * 40503))

static func _record(coord: Vector3i, normal: Vector3i, kind: Kind, zone: StringName) -> Dictionary:
	return {
		"coord": coord, "normal": normal, "kind": kind, "variant": WallVariant.NONE,
		"zone": zone, "porthole": false, "owner": true, "partition": false, "skin_flank": false,
		"feature_normal": Vector3i.ZERO,
	}

## Wall variants for bridge and common cells, in strict priority order. A
## partition is inside the ship, so it can be neither a hatch nor a porthole.
static func _common_variant(grid: ShipGrid, coord: Vector3i, normal: Vector3i,
		is_mount: bool, by_the_helm: bool, partition: bool) -> WallVariant:
	if not partition and _id_at(grid, coord) == AIRLOCK_ID and not grid.has_block(coord + normal):
		return WallVariant.HATCH
	var skin_flank := not partition and normal.x != 0 and _is_outer_skin(grid, coord, normal)
	if is_mount:
		# The cell's own fixture stands here; nothing that sticks out may too.
		return WallVariant.PORTHOLE if skin_flank else WallVariant.PANEL
	if by_the_helm:
		return WallVariant.CONSOLE
	if skin_flank:
		return WallVariant.PORTHOLE
	return WallVariant.LOCKERS if face_hash(coord, normal) % 2 == 0 else WallVariant.DISPLAY

static func _zone(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> StringName:
	var id := _id_at(grid, coord)
	if ROOM_IDS.has(id):
		return id
	if _is_mount(grid, catalog, coord) or _has_mount_neighbour(grid, catalog, coord) \
			or _has_canopy_neighbour(grid, coord):
		return ZONE_BRIDGE
	return ZONE_COMMON

## Bridge and common space are one open space; only rooms are walled off.
static func _room_of(zone: StringName) -> StringName:
	return zone if ROOM_IDS.has(zone) else &""

static func _key(coord: Vector3i, normal: Vector3i) -> String:
	return "%s|%s" % [coord, normal]

## Finds every room, gives each one doorway and each room cell a feature wall.
func _resolve_rooms() -> void:
	var index := {}   # "coord|normal" -> index into _faces
	for i in _faces.size():
		index[_key(_faces[i]["coord"], _faces[i]["normal"])] = i
	var seen := {}
	for coord in _walkable:
		var zone: StringName = _zones[coord]
		if not ROOM_IDS.has(zone) or seen.has(coord):
			continue
		var cells := _flood_room(coord, zone, seen)
		var doorway := _choose_doorway(cells, index)
		if not doorway.is_empty():
			var c: Vector3i = doorway["coord"]
			var n: Vector3i = doorway["normal"]
			for key in [_key(c, n), _key(c + n, -n)]:
				var face: Dictionary = _faces[index[key]]
				face["kind"] = Kind.DOORWAY
				face["variant"] = WallVariant.NONE
				face["porthole"] = false
		_rooms.append({"zone": zone, "coords": cells, "doorway": doorway})
		for cell in cells:
			_furnish_cell(cell, index)

## The connected cells of one room: horizontal neighbours with the same zone.
func _flood_room(start: Vector3i, zone: StringName, seen: Dictionary) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var frontier: Array[Vector3i] = [start]
	seen[start] = true
	while not frontier.is_empty():
		var cell: Vector3i = frontier.pop_back()
		cells.append(cell)
		for normal in _HORIZONTAL:
			var next := cell + normal
			if not seen.has(next) and _zones.get(next, &"") == zone:
				seen[next] = true
				frontier.append(next)
	cells.sort()
	return cells

## The one partition face a room opens through, ranked by: onto bridge or
## common space before onto another room; a flank (corridors run fore-aft)
## before an end; nearest the room's centroid; then forward-most, then port-most.
func _choose_doorway(cells: Array[Vector3i], index: Dictionary) -> Dictionary:
	var centroid := Vector3.ZERO
	for cell in cells:
		centroid += Vector3(cell)
	centroid /= float(cells.size())
	var best := {}
	var best_score: Array = []
	for cell in cells:
		for normal in _HORIZONTAL:
			var key := _key(cell, normal)
			if not index.has(key):
				continue
			var face: Dictionary = _faces[index[key]]
			if face["kind"] != Kind.WALL or not face["partition"]:
				continue
			var score := [
				1 if ROOM_IDS.has(_zones[cell + normal]) else 0,
				0 if normal.x != 0 else 1,
				(Vector3(cell) + Vector3(normal) * 0.5).distance_to(centroid),
				cell.z,
				cell.x,
			]
			if best.is_empty() or _ranks_before(score, best_score):
				best = {"coord": cell, "normal": normal}
				best_score = score
	return best

static func _ranks_before(a: Array, b: Array) -> bool:
	for i in a.size():
		if not is_equal_approx(float(a[i]), float(b[i])):
			return float(a[i]) < float(b[i])
	return false

## Furnishes one room cell's walls. The main piece (FEATURE) goes on an outer
## flank wall if the cell has one, else any flank, else any wall -- never the
## doorway; on the outer skin it also gets a porthole. A 2 m cell has room for
## one more, smaller piece (SECONDARY): it goes on a wall at right angles to
## the feature, and records the feature's normal so the dressing can push it
## to the far end, clear of the feature's corner. Any other wall keeps its
## trim (PANEL).
func _furnish_cell(cell: Vector3i, index: Dictionary) -> void:
	var walls: Array[Dictionary] = []
	for normal in _HORIZONTAL:
		var key := _key(cell, normal)
		if index.has(key) and _faces[index[key]]["kind"] == Kind.WALL:
			walls.append(_faces[index[key]])
	if walls.is_empty():
		return
	var feature: Dictionary = {}
	var best_rank := 3
	for face in walls:
		var n: Vector3i = face["normal"]
		var rank := 2
		if n.x != 0:
			rank = 1 if face["partition"] else 0
		if rank < best_rank:
			best_rank = rank
			feature = face
	feature["variant"] = WallVariant.FEATURE
	feature["porthole"] = feature["skin_flank"]
	var feature_normal: Vector3i = feature["normal"]
	for face in walls:
		var n: Vector3i = face["normal"]
		if face != feature and n.x * feature_normal.x + n.z * feature_normal.z == 0:
			face["variant"] = WallVariant.SECONDARY
			face["feature_normal"] = feature_normal
			return

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
