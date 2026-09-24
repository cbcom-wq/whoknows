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
