class_name PlanShapes
extends RefCounted

## What a world plan draws on its map (docs/superpowers/specs/2026-11-19-wadis-land-design.md
## §5.1): so far its seas, ranges and plateaus; canyons come later. Plain
## data, written while the plan is built and only read after, from any thread.
##
## A cell is the map's: the quadtree's node at PlanMap.PLAN_DEPTH, numbered
## (face * CELLS + j) * CELLS + i, the order PlanMap.set_bounds takes them in.
##
## Each cell also lists the shapes whose reach touches it (near), so a height
## close up asks only those: shape i of a kind is listed as kind * SHAPES + i.

const RANGE := 0
const CANYON := 1
const PLATEAU := 2
## Shapes of one kind, at most.
const SHAPES := 4096

## Each sea, one connected body of cells: {"cells": PackedInt32Array, "centre":
## Vector3, the unit direction it was grown from}.
var seas: Array[Dictionary] = []
## Each mountain range: {"spine": PackedVector3Array, unit directions about
## WorldPlan.SPINE_STEP apart, end to end; "height": PackedFloat32Array, by
## spine point, metres it stands over the open ground; "half_width": float,
## metres from the spine to its flanks' foot}.
var ranges: Array[Dictionary] = []
## Each plateau region, one connected body of cells: {"cells":
## PackedInt32Array, "top": float, metres above radius its top stands at}.
var plateaus: Array[Dictionary] = []
## The world's radius, metres: what ridge_m measures in.
var radius_m := 0.0

## The near lists, by cell: its entries are _near_from[cell] to
## _near_from[cell + 1] - 1, and entry e names shape _near[e] and the first
## and last segment (_near_first[e], _near_last[e]) of its spine that can be
## nearest to a point of the cell.
var _near_from := PackedInt32Array()
var _near := PackedInt32Array()
var _near_first := PackedInt32Array()
var _near_last := PackedInt32Array()
## Entries added while the plan is built, in order, until pack_near.
var _add_cell := PackedInt32Array()
var _add_shape := PackedInt32Array()
var _add_first := PackedInt32Array()
var _add_last := PackedInt32Array()

## The number of the cell `key` (a node at PLAN_DEPTH).
static func cell_index(key: Vector4i) -> int:
	return (key.x * PlanMap.CELLS + key.w) * PlanMap.CELLS + key.z

## The node key of cell number `index`.
static func cell_key(index: int) -> Vector4i:
	var n := PlanMap.CELLS
	return Vector4i(index / (n * n), PlanMap.PLAN_DEPTH, index % n, (index / n) % n)

## While building: lists shape `shape` (kind * SHAPES + i) as near cell number
## `cell`, segments `first` to `last` of its spine or path (for a shape that
## has them) holding whatever of it is nearest the cell's points.
func add_near(cell: int, shape: int, first := 0, last := -1) -> void:
	_add_cell.append(cell)
	_add_shape.append(shape)
	_add_first.append(first)
	_add_last.append(last)

## While building: marks 1 in `out` (a byte per cell) every cell a range has
## been listed near so far.
func mark_near_ranges(out: PackedByteArray) -> void:
	for e in _add_cell.size():
		if _add_shape[e] < SHAPES:
			out[_add_cell[e]] = 1

## Once every shape is added: files the entries cell by cell, each cell's in the
## order they were added.
func pack_near() -> void:
	var cells := CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS
	_near_from.resize(cells + 1)
	_near_from.fill(0)
	for c in _add_cell:
		_near_from[c + 1] += 1
	for c in cells:
		_near_from[c + 1] += _near_from[c]
	var count := _add_cell.size()
	_near.resize(count)
	_near_first.resize(count)
	_near_last.resize(count)
	var put := _near_from.slice(0, cells)
	for e in count:
		var c := _add_cell[e]
		var at := put[c]
		put[c] = at + 1
		_near[at] = _add_shape[e]
		_near_first[at] = _add_first[e]
		_near_last[at] = _add_last[e]
	_add_cell = PackedInt32Array()
	_add_shape = PackedInt32Array()
	_add_first = PackedInt32Array()
	_add_last = PackedInt32Array()

## The shapes whose reach touches `cell`, each kind * SHAPES + i. A new array:
## a height asked per vertex uses near_count and near_at, which allocate
## nothing.
func near(cell: Vector4i) -> PackedInt32Array:
	var c := cell_index(cell)
	return _near.slice(_near_from[c], _near_from[c + 1])

func near_count(cell: Vector4i) -> int:
	var c := cell_index(cell)
	return _near_from[c + 1] - _near_from[c]

## The `k`th of near(cell), 0 to near_count(cell) - 1.
func near_at(cell: Vector4i, k: int) -> int:
	return _near[_near_from[cell_index(cell)] + k]

## Vector2(great-circle metres from `d`, a unit direction in `cell`, to the
## nearest point of the spine of any range near the cell, the spine's height
## there), or Vector2(INF, 0) with none near. From any thread; allocates
## nothing.
func ridge_m(d: Vector3, cell: Vector4i) -> Vector2:
	var c := cell_index(cell)
	var best := INF
	var height := 0.0
	for e in range(_near_from[c], _near_from[c + 1]):
		var shape := _near[e]
		if shape >= SHAPES:
			continue
		var r: Dictionary = ranges[shape]
		var spine: PackedVector3Array = r.spine
		var tall: PackedFloat32Array = r.height
		for s in range(_near_first[e], _near_last[e] + 1):
			var a := spine[s]
			var ab := spine[s + 1] - a
			var t := clampf((d - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var angle := d.angle_to(a + ab * t)
			if angle < best:
				best = angle
				height = lerpf(tall[s], tall[s + 1], t)
	if best == INF:
		return Vector2(INF, 0.0)
	return Vector2(best * radius_m, height)
