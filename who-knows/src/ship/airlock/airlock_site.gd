class_name AirlockSite
extends RefCounted

## Where an airlock's outer hatch is (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §3.1): the airlock cell's one horizontal face
## onto an empty cell. Floors and ceilings never count. With no such face, or
## more than one, the airlock is inert -- dressed as a plain room, with no
## cycle. Both builders and the validator ask here, so they always agree.

const AIRLOCK_ID := &"airlock"
const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## The outer hatch's outward normal, or Vector3i.ZERO if `coord` is not an
## airlock that can cycle.
static func hatch_normal(grid: ShipGrid, coord: Vector3i) -> Vector3i:
	var inst := grid.get_block(coord)
	if inst == null or inst.block_id != AIRLOCK_ID:
		return Vector3i.ZERO
	var found := Vector3i.ZERO
	var count := 0
	for normal in _HORIZONTAL:
		if not grid.has_block(coord + normal):
			found = normal
			count += 1
	return found if count == 1 else Vector3i.ZERO

## The inner hatch's normal: the face the airlock opens onto from inside the
## ship, or Vector3i.ZERO if it has nowhere walkable to open onto. Straight
## through, opposite the outer hatch, when that cell is walkable; otherwise a
## side, in a fixed order. Open deck beats a room -- an airlock should not open
## into someone's bunk -- and another airlock never counts. The interior layout
## and the hull's copy of the room both ask here, so they always agree.
static func door_normal(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i) -> Vector3i:
	var hatch := hatch_normal(grid, coord)
	if hatch == Vector3i.ZERO:
		return Vector3i.ZERO
	var candidates: Array[Vector3i] = [-hatch]
	for normal in _HORIZONTAL:
		if normal != hatch and normal != -hatch:
			candidates.append(normal)
	var best := Vector3i.ZERO
	var best_rank := 99
	for normal in candidates:
		var inst := grid.get_block(coord + normal)
		if inst == null or inst.block_id == AIRLOCK_ID:
			continue
		var def := catalog.get_def(inst.block_id)
		if def == null or (def.occupancy != BlockDefinition.Occupancy.DECK
				and def.occupancy != BlockDefinition.Occupancy.MOUNT):
			continue
		var rank := (2 if InteriorLayout.ROOM_IDS.has(inst.block_id) else 0) + (0 if normal == -hatch else 1)
		if rank < best_rank:
			best_rank = rank
			best = normal
	return best
