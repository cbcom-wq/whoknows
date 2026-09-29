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
## Damage taken per cell (health and damage spec §4.2); 0 is intact.
@export var damage_values: Array[float] = []

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
		bp.damage_values.append(inst.damage)
	return bp

func to_grid() -> ShipGrid:
	var grid := ShipGrid.new()
	for index in coords.size():
		var inst := BlockInstance.new()
		inst.block_id = block_ids[index]
		inst.orientation = orientations[index]
		inst.damage = damage_values[index]
		grid.set_block(coords[index], inst)
	return grid

## The blueprint as plain data for a save file (docs/superpowers/specs/
## 2026-09-26-saving-design.md §6.2): never a .tres, which can carry a script.
## A cell's sixth slot was hp and always 0 before health and damage; it is
## damage taken now, so every older save reads as intact.
func to_dict() -> Dictionary:
	var cells := []
	for index in coords.size():
		cells.append([coords[index].x, coords[index].y, coords[index].z, String(block_ids[index]),
			orientations[index], damage_values[index]])
	return {"name": ship_name, "format": format_version, "cells": cells}

static func from_dict(d: Dictionary) -> ShipBlueprint:
	var bp := ShipBlueprint.new()
	bp.ship_name = String(d.get("name", bp.ship_name))
	bp.format_version = int(d.get("format", CURRENT_FORMAT_VERSION))
	for cell in d.get("cells", []):
		if not (cell is Array) or cell.size() != 6:
			continue
		bp.coords.append(Vector3i(int(cell[0]), int(cell[1]), int(cell[2])))
		bp.block_ids.append(StringName(cell[3]))
		bp.orientations.append(int(cell[4]))
		bp.damage_values.append(maxf(float(cell[5]), 0.0))
	return bp

static func _compare_coords(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z
