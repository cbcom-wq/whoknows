class_name InteriorLayout
extends RefCounted

## Decides what every interior face is, once, for both InteriorBuilder
## (structure) and InteriorDressing (props): a floor and a ceiling per
## walkable cell, and for each horizontal face that does not open onto
## another walkable cell, either a canopy face or a wall with exactly one
## variant (docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md
## §5.1).
##
## A record is {coord, normal, kind, variant, zone, porthole, owner, pod}. `zone`
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
## The airlock (docs/superpowers/specs/2026-09-24-airlock-design.md §3.1): an
## airlock cell with one face onto open space (AirlockSite) is a room of its
## own, AIRLOCK_ZONE, with one doorway like any room -- its inner hatch -- and
## the face onto space as its outer hatch. It takes no furniture, and no other
## room may open into it.
##
## Fixtures and pods (docs/superpowers/specs/2026-09-23-cockpit-pod-design.md
## §4-§5): every MOUNT cell is a fixture, with the way it faces. The canopy
## face straight ahead of a helm is a pod (`pod` true on its record): the
## cockpit juts out through it.
##
## Pure: reads the grid, returns records, touches no nodes. The same grid
## always yields the same layout.

enum Kind { FLOOR, CEILING, WALL, CANOPY, DOORWAY }
enum WallVariant { NONE, HATCH, CONSOLE, PORTHOLE, LOCKERS, DISPLAY, PANEL, FEATURE, SECONDARY, AIRLOCK }

## Walkable blocks that make a room (spec §7.1). Any other walkable cell is
## bridge or common space.
const ROOM_IDS: Array[StringName] = [&"bunk_room", &"galley", &"bathroom", &"closet", &"weapon_room"]

const ZONE_BRIDGE := &"bridge"
const ZONE_COMMON := &"common"
## An airlock that can cycle. A room, but not one of ROOM_IDS: it has no
## block of its own and takes no furniture.
const AIRLOCK_ZONE := &"airlock"
const CANOPY_ID := &"canopy"
const AIRLOCK_ID := &"airlock"
## The fixture the ship is flown from. A canopy face ahead of it becomes a pod.
const HELM_ID := &"pilot_seat"
## Fixtures that stand IN the bridge without spreading it (quantum energy
## spec §6.1): unlike the helm, a quiet fixture's neighbours do not become
## bridge/console/porthole-blocking on its account, and _zone() does not
## treat it as a reason to call a neighbouring cell bridge. The fixture's
## own cell is still a MOUNT for its own walls, which go plain (PANEL), or
## PORTHOLE on a skin flank -- nothing else stands where it does.
const QUIET_FIXTURES: Array[StringName] = [&"quantum_core", &"quantum_machine"]
const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _faces: Array[Dictionary] = []
var _groups: Array[Dictionary] = []
var _walkable: Array[Vector3i] = []
var _zones: Dictionary = {}   # Vector3i -> StringName
var _rooms: Array[Dictionary] = []
var _fixtures: Array[Dictionary] = []
var _pods: Array[Dictionary] = []
var _airlocks: Array[Dictionary] = []
var _hatches: Dictionary = {}   # Vector3i -> outer hatch normal, for airlock-zone cells
var _doors: Dictionary = {}     # Vector3i -> inner hatch normal (AirlockSite.door_normal)

static func plan(grid: ShipGrid, catalog: BlockCatalog, walkable: Array) -> InteriorLayout:
	var layout := InteriorLayout.new()
	layout._walkable.assign(walkable)
	var walkable_set := {}
	for coord in walkable:
		walkable_set[coord] = true
	# Zones first: a partition needs to know both sides.
	for coord: Vector3i in layout._walkable:
		layout._zones[coord] = _zone(grid, catalog, coord)
		if layout._zones[coord] == AIRLOCK_ZONE:
			layout._hatches[coord] = AirlockSite.hatch_normal(grid, coord)
			layout._doors[coord] = AirlockSite.door_normal(grid, catalog, coord)
	var groups := {}   # plane key -> {normal, coords}
	for coord: Vector3i in layout._walkable:
		var zone: StringName = layout._zones[coord]
		var in_room := _is_room(zone)
		var room_wall := WallVariant.AIRLOCK if zone == AIRLOCK_ZONE else WallVariant.PANEL
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
				partition["variant"] = room_wall if in_room else _common_variant(
					grid, coord, normal, is_mount, by_the_helm, true)
				layout._faces.append(partition)
				continue
			if _id_at(grid, neighbour) == CANOPY_ID:
				layout._faces.append(_record(coord, normal, Kind.CANOPY, zone))
				var key := "%s:%d:%d" % [normal, _along(neighbour, normal), coord.y]
				groups.get_or_add(key, {"normal": normal, "coords": [], "pods": []})["coords"].append(coord)
				continue
			var face := _record(coord, normal, Kind.WALL, zone)
			face["skin_flank"] = normal.x != 0 and _is_outer_skin(grid, coord, normal)
			if zone == AIRLOCK_ZONE:
				face["variant"] = WallVariant.HATCH if normal == layout._hatches[coord] else room_wall
			elif in_room:
				face["variant"] = room_wall
			else:
				var variant := _common_variant(grid, coord, normal, is_mount, by_the_helm, false)
				face["variant"] = variant
				face["porthole"] = variant == WallVariant.PORTHOLE
			layout._faces.append(face)
	for key in groups:
		layout._groups.append(groups[key])
	layout._resolve_rooms()
	for coord: Vector3i in layout._walkable:
		if _is_mount(grid, catalog, coord):
			var inst := grid.get_block(coord)
			layout._fixtures.append({"coord": coord, "id": inst.block_id, "orientation": inst.orientation})
	layout._mark_pods()
	return layout

func faces() -> Array[Dictionary]:
	return _faces.duplicate()

## One entry per windshield plane: {normal, coords, pods} -- the walkable
## cells whose face on that plane is canopy, and those of them that are pods.
## InteriorDressing builds a rounded nose over a group with no pod, and a
## cockpit over one with.
func canopy_groups() -> Array[Dictionary]:
	return _groups.duplicate()

## Every MOUNT cell: {coord, id, orientation}.
func fixtures() -> Array[Dictionary]:
	return _fixtures.duplicate()

## Every pod: {coord, normal} of the canopy face it juts out through.
func pods() -> Array[Dictionary]:
	return _pods.duplicate()

## The horizontal grid direction a block with this orientation faces.
static func facing(orientation: int) -> Vector3i:
	return Vector3i((BlockOrientation.basis_for(orientation) * Vector3.FORWARD).round())

func walkable_coords() -> Array[Vector3i]:
	return _walkable.duplicate()

## Every room: {zone, coords, doorway}, where doorway is {coord, normal} of
## the face chosen as its way in, or {} for a room with no neighbour at all.
## Airlocks are listed by airlocks(), not here.
func rooms() -> Array[Dictionary]:
	return _rooms.duplicate()

## Every airlock that can cycle: {coord, hatch_normal, door_normal}.
## door_normal is the inner hatch's (its doorway), or Vector3i.ZERO for an
## airlock with nowhere inside to open onto.
func airlocks() -> Array[Dictionary]:
	return _airlocks.duplicate()

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
		"feature_normal": Vector3i.ZERO, "pod": false, "hatch": false,
	}

## Wall variants for bridge and common cells, in strict priority order. A
## partition is inside the ship, so it can be neither a hatch nor a porthole.
static func _common_variant(grid: ShipGrid, coord: Vector3i, normal: Vector3i,
		is_mount: bool, by_the_helm: bool, partition: bool) -> WallVariant:
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
	if id == AIRLOCK_ID and AirlockSite.hatch_normal(grid, coord) != Vector3i.ZERO:
		return AIRLOCK_ZONE
	if ROOM_IDS.has(id):
		return id
	if _is_mount(grid, catalog, coord) or _has_mount_neighbour(grid, catalog, coord) \
			or _has_canopy_neighbour(grid, coord):
		return ZONE_BRIDGE
	return ZONE_COMMON

## Bridge and common space are one open space; only rooms are walled off.
static func _room_of(zone: StringName) -> StringName:
	return zone if _is_room(zone) else &""

static func _is_room(zone: StringName) -> bool:
	return ROOM_IDS.has(zone) or zone == AIRLOCK_ZONE

static func _key(coord: Vector3i, normal: Vector3i) -> String:
	return "%s|%s" % [coord, normal]

## A helm looking straight at a canopy face makes that face a pod.
func _mark_pods() -> void:
	for fixture in _fixtures:
		if fixture["id"] != HELM_ID:
			continue
		var coord: Vector3i = fixture["coord"]
		var normal := facing(fixture["orientation"])
		for face in _faces:
			if face["kind"] == Kind.CANOPY and face["coord"] == coord and face["normal"] == normal:
				face["pod"] = true
				_pods.append({"coord": coord, "normal": normal})
				for group in _groups:
					var coords: Array = group["coords"]
					if group["normal"] == normal and coords.has(coord):
						group["pods"].append(coord)

## Finds every room, gives each one doorway and each room cell a feature wall.
func _resolve_rooms() -> void:
	var index := {}   # "coord|normal" -> index into _faces
	for i in _faces.size():
		index[_key(_faces[i]["coord"], _faces[i]["normal"])] = i
	var seen := {}
	for coord in _walkable:
		var zone: StringName = _zones[coord]
		if not _is_room(zone) or seen.has(coord):
			continue
		var cells := _flood_room(coord, zone, seen)
		var doorway := _airlock_doorway(cells, index) if zone == AIRLOCK_ZONE else _choose_doorway(cells, index, zone)
		if not doorway.is_empty():
			var c: Vector3i = doorway["coord"]
			var n: Vector3i = doorway["normal"]
			for key in [_key(c, n), _key(c + n, -n)]:
				var face: Dictionary = _faces[index[key]]
				face["kind"] = Kind.DOORWAY
				face["variant"] = WallVariant.NONE
				face["porthole"] = false
				face["hatch"] = zone == AIRLOCK_ZONE
		if zone == AIRLOCK_ZONE:
			for cell in cells:
				var door := Vector3i.ZERO
				if not doorway.is_empty() and doorway["coord"] == cell:
					door = doorway["normal"]
				_airlocks.append({"coord": cell, "hatch_normal": _hatches[cell], "door_normal": door})
			continue   # an airlock takes no furniture
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
## Only the airlock itself may open onto the airlock: a door straight into it
## would bypass its hatch.
func _choose_doorway(cells: Array[Vector3i], index: Dictionary, zone: StringName) -> Dictionary:
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
			if zone != AIRLOCK_ZONE and _zones[cell + normal] == AIRLOCK_ZONE:
				continue
			var score := [
				1 if _is_room(_zones[cell + normal]) else 0,
				0 if normal.x != 0 else 1,
				(Vector3(cell) + Vector3(normal) * 0.5).distance_to(centroid),
				cell.z,
				cell.x,
			]
			if best.is_empty() or _ranks_before(score, best_score):
				best = {"coord": cell, "normal": normal}
				best_score = score
	return best

## An airlock's doorway is AirlockSite's choice, so the hull's copy of the room
## puts its inner hatch in the same place: the first of its cells with one.
func _airlock_doorway(cells: Array[Vector3i], index: Dictionary) -> Dictionary:
	for cell in cells:
		var door: Vector3i = _doors.get(cell, Vector3i.ZERO)
		var key := _key(cell, door)
		if door != Vector3i.ZERO and index.has(key) and _faces[index[key]]["kind"] == Kind.WALL:
			return {"coord": cell, "normal": door}
	return {}

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

## Whether `coord` has a neighbour that makes IT bridge/console (spec §6.1):
## any ordinary MOUNT does, but a quiet fixture does not -- only its own
## cell counts (_is_mount), never a neighbour's.
static func _has_mount_neighbour(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> bool:
	for normal in _HORIZONTAL:
		if _is_loud_mount(grid, catalog, coord + normal):
			return true
	return false

static func _is_mount(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> bool:
	var inst := grid.get_block(coord)
	if inst == null:
		return false
	var def := catalog.get_def(inst.block_id)
	return def != null and def.occupancy == BlockDefinition.Occupancy.MOUNT

## A MOUNT that is not one of QUIET_FIXTURES: one whose presence spreads
## bridge zone and consoles to its neighbours.
static func _is_loud_mount(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> bool:
	var inst := grid.get_block(coord)
	if inst != null and QUIET_FIXTURES.has(inst.block_id):
		return false
	return _is_mount(grid, catalog, coord)

static func _id_at(grid: ShipGrid, coord: Vector3i) -> StringName:
	var inst := grid.get_block(coord)
	return inst.block_id if inst != null else &""

## The coordinate that identifies a face's plane along its normal's axis.
static func _along(coord: Vector3i, normal: Vector3i) -> int:
	return coord.x if normal.x != 0 else coord.z
