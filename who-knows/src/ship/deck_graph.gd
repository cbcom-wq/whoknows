class_name DeckGraph
extends RefCounted

## Connected components over the walkable set (DECK ∪ MOUNT).
##
## Vertical movement requires a Ladder on at least one end of the pair,
## so a deck stacked directly on another deck is a second storey rather
## than a ramp. This is what makes Rule 4 catch a sealed-off upper deck.

const LADDER_ID := &"ladder"

const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const _VERTICAL: Array[Vector3i] = [Vector3i(0, 1, 0), Vector3i(0, -1, 0)]

var _component: Dictionary = {}   # Vector3i -> int
var _count: int = 0

static func build(grid: ShipGrid, catalog: BlockCatalog) -> DeckGraph:
	var g := DeckGraph.new()
	var walkable := {}
	for coord in grid.coords():
		if g._is_walkable_cell(grid, catalog, coord):
			walkable[coord] = true

	for coord in walkable.keys():
		if g._component.has(coord):
			continue
		g._flood(grid, walkable, coord, g._count)
		g._count += 1
	return g

func _is_walkable_cell(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> bool:
	var inst := grid.get_block(coord)
	if inst == null:
		return false
	var def := catalog.get_def(inst.block_id)
	return def != null and def.is_walkable()

func _flood(grid: ShipGrid, walkable: Dictionary, start: Vector3i, id: int) -> void:
	var queue: Array[Vector3i] = [start]
	_component[start] = id
	while not queue.is_empty():
		var coord: Vector3i = queue.pop_back()
		for neighbour in _connected_neighbours(grid, walkable, coord):
			if _component.has(neighbour):
				continue
			_component[neighbour] = id
			queue.append(neighbour)

func _connected_neighbours(grid: ShipGrid, walkable: Dictionary, coord: Vector3i) -> Array:
	var out: Array[Vector3i] = []
	for offset in _HORIZONTAL:
		var n := coord + offset
		if walkable.has(n):
			out.append(n)
	for offset in _VERTICAL:
		var n := coord + offset
		if walkable.has(n) and (_is_ladder(grid, coord) or _is_ladder(grid, n)):
			out.append(n)
	return out

func _is_ladder(grid: ShipGrid, coord: Vector3i) -> bool:
	var inst := grid.get_block(coord)
	return inst != null and inst.block_id == LADDER_ID

func is_walkable(coord: Vector3i) -> bool:
	return _component.has(coord)

func component_of(coord: Vector3i) -> int:
	return _component.get(coord, -1)

func component_count() -> int:
	return _count

func walkable_coords() -> Array:
	return _component.keys()
