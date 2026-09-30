class_name ShipCells
extends RefCounted

## Which cell of a ship a hit landed on (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §5.1): the bolt, a crash and the
## torch all ask here. Pure: points and normals in, a cell out.

## No cell with a block.
const NONE := Vector3i(-1048576, -1048576, -1048576)
## How far past an interior surface the cell behind it is looked for: past the
## wall (0.1 m) and any dressing on it, well short of the next cell's far side.
const BEHIND := 0.35
## How far into the hull a point on its skin is stepped.
const INTO_HULL := 0.05

## The cell a point in interior space is in: grid x and z, and the storey.
static func interior_cell_at(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x / ShipGrid.CELL_SIZE), InteriorBuilder.storey_at(p.y),
		roundi(p.z / ShipGrid.CELL_SIZE))

## The block a hit on an interior surface damages: the one behind the face
## (a wall's hull, the hull under a floor), or, when there is none, the one
## in front (a fixture in its own cell, a deck with nothing under it).
## `p` and `normal` are in interior space.
static func interior_cell(grid: ShipGrid, p: Vector3, normal: Vector3) -> Vector3i:
	var behind := interior_cell_at(p - normal * BEHIND)
	if grid.has_block(behind):
		return behind
	var front := interior_cell_at(p + normal * INTO_HULL)
	return front if grid.has_block(front) else NONE

## The block a hit on the hull damages. A hull collider carries its cell in
## meta &"cell" (ExteriorBuilder); anything else, or no shape, falls back to
## the cell the point sits in. `p` and `normal` are in the hull's own frame.
static func hull_cell(grid: ShipGrid, body: CollisionObject3D, shape: int, p: Vector3,
		normal: Vector3) -> Vector3i:
	if body != null and shape >= 0:
		var owner_id := body.shape_find_owner(shape)
		var node := body.shape_owner_get_owner(owner_id) as Node if owner_id >= 0 else null
		if node != null and node.has_meta(&"cell"):
			var cell: Vector3i = node.get_meta(&"cell")
			if grid.has_block(cell):
				return cell
	var at := p - normal * INTO_HULL
	var cell := Vector3i((at / ShipGrid.CELL_SIZE).round())
	return cell if grid.has_block(cell) else NONE
