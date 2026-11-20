class_name PlanShapes
extends RefCounted

## What a world plan draws on its map (docs/superpowers/specs/2026-11-19-wadis-land-design.md
## §5.1): so far its seas; ranges, plateaus and canyons come later. Plain data,
## written while the plan is built and only read after, from any thread.
##
## A cell is the map's: the quadtree's node at PlanMap.PLAN_DEPTH, numbered
## (face * CELLS + j) * CELLS + i, the order PlanMap.set_bounds takes them in.

## Each sea, one connected body of cells: {"cells": PackedInt32Array, "centre":
## Vector3, the unit direction it was grown from}.
var seas: Array[Dictionary] = []

## The number of the cell `key` (a node at PLAN_DEPTH).
static func cell_index(key: Vector4i) -> int:
	return (key.x * PlanMap.CELLS + key.w) * PlanMap.CELLS + key.z

## The node key of cell number `index`.
static func cell_key(index: int) -> Vector4i:
	var n := PlanMap.CELLS
	return Vector4i(index / (n * n), PlanMap.PLAN_DEPTH, index % n, (index / n) % n)
