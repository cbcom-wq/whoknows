class_name ShipGrid
extends RefCounted

## The single source of truth for a ship's construction.
##
## ARCHITECTURAL RULE: `_cells` is private and only `set_block` and
## `clear_block` may write to it. Every other system — exterior mesh,
## exterior collision, interior geometry, navmesh, stats — rebuilds off
## `cell_changed`. Code that mutates cells any other way lets the
## exterior and interior drift apart, which is the one failure mode that
## can quietly rot this architecture. `remove_many` is the same choke point
## for a burst of removals: one signal, so one rebuild.
##
## Damage changes a BlockInstance in place, never a cell; crossing a stage is
## told through `block_staged` (health and damage spec §4.3), which rebuilds
## nothing.

signal cell_changed(coord: Vector3i)
## A block's damage crossed into `stage`, a BlockDamage.Stage. Emitted by
## BlockDamage through note_staged().
signal block_staged(coord: Vector3i, stage: int)

const CELL_SIZE := 2.0

const FACE_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _cells: Dictionary = {}   # Vector3i -> BlockInstance

func set_block(coord: Vector3i, inst: BlockInstance) -> void:
	# assert() is stripped from release builds, so it cannot be the only
	# guard on the choke point: a null slipping through would leave
	# has_block() true while get_block() returns null.
	if inst == null:
		push_error("ShipGrid.set_block: use clear_block() to empty a cell")
		assert(false, "use clear_block() to empty a cell")
		return
	_cells[coord] = inst
	cell_changed.emit(coord)

func clear_block(coord: Vector3i) -> void:
	if not _cells.has(coord):
		return
	_cells.erase(coord)
	cell_changed.emit(coord)

## Empties every cell in `coords` that holds a block, then emits cell_changed
## once, with the first: blocks knocked off together cost one rebuild.
func remove_many(coords: Array) -> void:
	var first = null
	for coord in coords:
		if _cells.erase(coord) and first == null:
			first = coord
	if first != null:
		cell_changed.emit(first)

func note_staged(coord: Vector3i, stage: int) -> void:
	block_staged.emit(coord, stage)

func get_block(coord: Vector3i) -> BlockInstance:
	return _cells.get(coord, null)

func has_block(coord: Vector3i) -> bool:
	return _cells.has(coord)

func size() -> int:
	return _cells.size()

func coords() -> Array:
	return _cells.keys()

func neighbours(coord: Vector3i) -> Array:
	var out: Array[Vector3i] = []
	for offset in FACE_OFFSETS:
		out.append(coord + offset)
	return out

static func cell_center(coord: Vector3i) -> Vector3:
	return Vector3(coord) * CELL_SIZE
