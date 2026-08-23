class_name ShipBlueprint
extends Resource

## A serializable ShipGrid. Stored as sorted parallel arrays rather than a
## Vector3i-keyed dictionary so that saved .tres files are stable and
## diffable in git.

const CURRENT_FORMAT_VERSION := 1

@export var ship_name: String = "Unnamed"
@export var format_version: int = CURRENT_FORMAT_VERSION

@export var coords: Array[Vector3i] = []
@export var block_ids: Array[StringName] = []
@export var orientations: Array[int] = []
@export var hp_values: Array[int] = []

static func from_grid(grid: ShipGrid, name: String) -> ShipBlueprint:
	var bp := ShipBlueprint.new()
	bp.ship_name = name

	var sorted: Array = grid.coords()
	sorted.sort_custom(_compare_coords)

	for coord in sorted:
		var inst := grid.get_block(coord)
		bp.coords.append(coord)
		bp.block_ids.append(inst.block_id)
		bp.orientations.append(inst.orientation)
		bp.hp_values.append(inst.hp_current)
	return bp

func to_grid() -> ShipGrid:
	var grid := ShipGrid.new()
	for index in coords.size():
		var inst := BlockInstance.new()
		inst.block_id = block_ids[index]
		inst.orientation = orientations[index]
		inst.hp_current = hp_values[index]
		grid.set_block(coords[index], inst)
	return grid

static func _compare_coords(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z
