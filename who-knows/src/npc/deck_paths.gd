class_name DeckPaths
extends RefCounted

## Paths over an interior's cells (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §5.5). Two walkable cells on one storey
## are joined where InteriorLayout put no wall between them: open floor, and
## each room's doorway. The layout already knows every wall, so a 2 m cell
## graph is exact, tiny and the same every time. No navmesh.
##
## One step goes diagonally: past the corner between two quiet fixtures
## (InteriorLayout.QUIET_FIXTURES), when the floor all round that corner is
## open. A quiet fixture stands clear of its cell's corners -- the quantum core
## 1.2 m across, the bridge computer's table 1.0 m, the machine against its
## back wall -- so two side by side leave a way between them, 1.3 m wide on
## the starter's bridge (bridge computer spec §3.2). Without it the table, the
## core and the machine would wall the droid off from the whole front of the
## bridge.
##
## Pure: reads the layout, touches no nodes.

const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _links := {}   # Vector3i -> Array[Vector3i]

## The walkable cells of `layout` minus the airlock, every fixture's cell and
## anything in `avoid` (cells without plating, say).
static func build(layout: InteriorLayout, avoid: Array[Vector3i] = []) -> DeckPaths:
	var paths := DeckPaths.new()
	var blocked := {}
	for cell in avoid:
		blocked[cell] = true
	var quiet := {}
	for f in layout.fixtures():
		blocked[f["coord"]] = true
		if InteriorLayout.QUIET_FIXTURES.has(f["id"]):
			quiet[f["coord"]] = true
	var cells := {}
	for cell in layout.walkable_coords():
		if not blocked.has(cell) and layout.zone_at(cell) != InteriorLayout.AIRLOCK_ZONE:
			cells[cell] = true
	var shut := {}   # "coord|normal" of every face that is not a way through
	for face in layout.faces():
		if face["kind"] != InteriorLayout.Kind.DOORWAY:
			shut[_key(face["coord"], face["normal"])] = true
	for cell: Vector3i in cells:
		var out: Array[Vector3i] = []
		for n in _HORIZONTAL:
			var next := cell + n
			if cells.has(next) and not shut.has(_key(cell, n)):
				out.append(next)
		for dx in [-1, 1]:
			for dz in [-1, 1]:
				var side_x := cell + Vector3i(dx, 0, 0)
				var side_z := cell + Vector3i(0, 0, dz)
				var next := cell + Vector3i(dx, 0, dz)
				if cells.has(next) and quiet.has(side_x) and quiet.has(side_z) \
						and _open_round(shut, cell, side_x, side_z, next):
					out.append(next)
		paths._links[cell] = out
	return paths

func has(cell: Vector3i) -> bool:
	return _links.has(cell)

func is_empty() -> bool:
	return _links.is_empty()

## Every cell, sorted.
func cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(_links.keys())
	out.sort()
	return out

func neighbours(cell: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(_links.get(cell, []))
	return out

## Whether you can step straight from `a` to its neighbour `b`.
func linked(a: Vector3i, b: Vector3i) -> bool:
	return _links.has(a) and (_links[a] as Array).has(b)

## The cells from `from` to `to`, both included; empty if there is no way.
func path(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	if not has(from) or not has(to):
		return []
	var came := {from: from}
	var cost := {from: 0}
	var open: Array[Vector3i] = [from]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if int(cost[open[i]]) + _h(open[i], to) < int(cost[open[best]]) + _h(open[best], to):
				best = i
		var cell: Vector3i = open[best]
		open.remove_at(best)
		if cell == to:
			break
		for next in neighbours(cell):
			var c: int = int(cost[cell]) + 1
			if not cost.has(next) or c < int(cost[next]):
				cost[next] = c
				came[next] = cell
				if not open.has(next):
					open.append(next)
	if not came.has(to):
		return []
	var out: Array[Vector3i] = [to]
	while out[0] != from:
		out.push_front(came[out[0]])
	return out

## Steps from `from` to every cell it can reach.
func distances(from: Vector3i) -> Dictionary:
	if not has(from):
		return {}
	var out := {from: 0}
	var frontier: Array[Vector3i] = [from]
	while not frontier.is_empty():
		var cell: Vector3i = frontier.pop_front()
		for next in neighbours(cell):
			if not out.has(next):
				out[next] = int(out[cell]) + 1
				frontier.append(next)
	return out

## The cell an interior-local point is in: ShipGrid.cell_center inverted on x
## and z, and the storey it stands on.
static func cell_at(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x / ShipGrid.CELL_SIZE), InteriorBuilder.storey_at(p.y),
		roundi(p.z / ShipGrid.CELL_SIZE))

## Where to stand in `cell`: its centre, on the floor.
static func floor_point(cell: Vector3i) -> Vector3:
	var c := InteriorBuilder.interior_center(cell)
	c.y = InteriorBuilder.floor_y(cell)
	return c

## No wall or doorway on any of the four edges between `cell`, the two cells
## beside the corner and the one across it.
static func _open_round(shut: Dictionary, cell: Vector3i, side_x: Vector3i, side_z: Vector3i,
		across: Vector3i) -> bool:
	for pair in [[cell, side_x], [cell, side_z], [side_x, across], [side_z, across]]:
		var a: Vector3i = pair[0]
		var b: Vector3i = pair[1]
		if shut.has(_key(a, b - a)) or shut.has(_key(b, a - b)):
			return false
	return true

static func _h(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.z - b.z)

static func _key(coord: Vector3i, normal: Vector3i) -> String:
	return "%s|%s" % [coord, normal]
