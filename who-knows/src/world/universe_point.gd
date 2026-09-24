class_name UniversePoint
extends RefCounted

## A position in the universe (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §4.1): whole metres on each axis as 64-bit ints, and the part of a metre
## past them as 64-bit floats. The engine's own positions are 32-bit and
## shimmer far from its origin; these never do, however far you fly.

var x: int
var y: int
var z: int
## The part of a metre past (x, y, z), each in [0, 1).
var fx := 0.0
var fy := 0.0
var fz := 0.0

static func at(mx: int, my: int, mz: int) -> UniversePoint:
	var u := UniversePoint.new()
	u.x = mx
	u.y = my
	u.z = mz
	return u

## This point moved by `offset`, an engine-sized step.
func plus(offset: Vector3) -> UniversePoint:
	var u := UniversePoint.new()
	var vx := fx + offset.x
	var vy := fy + offset.y
	var vz := fz + offset.z
	var wx := floori(vx)
	var wy := floori(vy)
	var wz := floori(vz)
	u.x = x + wx
	u.y = y + wy
	u.z = z + wz
	u.fx = vx - wx
	u.fy = vy - wy
	u.fz = vz - wz
	return u

## The step from `other` to this point, as an engine vector: only meaningful
## for points within an engine's reach of each other.
func minus(other: UniversePoint) -> Vector3:
	return Vector3(
		float(x - other.x) + (fx - other.fx),
		float(y - other.y) + (fy - other.fy),
		float(z - other.z) + (fz - other.fz))

func is_equal_approx(other: UniversePoint) -> bool:
	return minus(other).is_zero_approx()

func _to_string() -> String:
	return "(%d + %f, %d + %f, %d + %f)" % [x, fx, y, fy, z, fz]
