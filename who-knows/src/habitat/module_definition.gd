class_name ModuleDefinition
extends RefCounted

## One module (habitat modules spec §6): a small grid of blocks, its prefab,
## copied into a base's grid where it is planted, turned in quarter turns
## about up. Cells are module-local: x and z across its footprint from 0, y
## its storeys from 0 (the floor) up.

var kind: StringName
var display_name: String
## Cells on x, storeys on y, cells on z, unturned.
var size: Vector3i
## [Vector3i cell, StringName block id, int orientation], unturned.
var blocks: Array = []
## The item that unfolds into it.
var package: StringName

func _init(p_kind: StringName, p_name: String, p_size: Vector3i, p_package: StringName) -> void:
	kind = p_kind
	display_name = p_name
	size = p_size
	package = p_package

func put(cell: Vector3i, id: StringName, orientation := 0) -> ModuleDefinition:
	blocks.append([cell, id, orientation])
	return self

## Its size once turned: a quarter or three-quarter turn swaps x and z.
func turned_size(turns: int) -> Vector3i:
	return Vector3i(size.z, size.y, size.x) if posmod(turns, 2) == 1 else size

## Its blocks turned `turns` quarter turns about +y, cells kept inside the
## turned footprint.
func turned(turns: int) -> Array:
	var out := []
	for b: Array in blocks:
		out.append([turn_cell(b[0], turns, size), b[1], turn_orientation(b[2], turns)])
	return out

## Its floor cells (storey 0), turned.
func floor_cells(turns: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for b: Array in turned(turns):
		if (b[0] as Vector3i).y == 0:
			out.append(b[0])
	return out

## `c` turned `turns` quarter turns (+90 deg each, about +y) inside a footprint
## of `p_size`: x, z goes to z, w-1-x, the footprint's x and z swapping.
static func turn_cell(c: Vector3i, turns: int, p_size: Vector3i) -> Vector3i:
	var out := c
	var w := p_size.x
	var d := p_size.z
	for i in posmod(turns, 4):
		out = Vector3i(out.z, out.y, w - 1 - out.x)
		var t := w
		w = d
		d = t
	return out

## Orientation `o` turned `turns` quarter turns about +y: the orientation whose
## basis is the turn times o's.
static func turn_orientation(o: int, turns: int) -> int:
	var want := Basis(Vector3.UP, PI * 0.5 * posmod(turns, 4)) * BlockOrientation.basis_for(o)
	for candidate in 24:
		var b := BlockOrientation.basis_for(candidate)
		if b.x.is_equal_approx(want.x) and b.y.is_equal_approx(want.y) and b.z.is_equal_approx(want.z):
			return candidate
	push_error("ModuleDefinition: no orientation for %d turned %d" % [o, turns])
	return o
