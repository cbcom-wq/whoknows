class_name AsteroidRock
extends RefCounted

## One rock, as data (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §5.3): where it sits in its cell, how it is turned and sized, what it looks
## like and weighs. No node: recipes make these on worker threads.

var tier: int
var cell: Vector3i
## Which candidate it was in its cell: with tier and cell, who it is.
var index: int
## From its cell's lowest corner, metres.
var local: Vector3
var turn: Basis
## Its extent on each axis: diameter times stretch.
var size: Vector3
var shape: int
var colour: Color
var mass: float
## The sphere about its centre it never pokes out of.
var radius: float

## Rotation and size together.
func basis() -> Basis:
	return turn * Basis.from_scale(size)

## Who it is, across loads: its cell, with tier and index packed together.
func id() -> Vector4i:
	return Vector4i(cell.x, cell.y, cell.z, tier * 1000 + index)
