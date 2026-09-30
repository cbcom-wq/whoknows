class_name HullShapes
extends RefCounted

## The shapes a hull block can have (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §4), block-local with the block facing
## FORWARD: a cell spans -1..1 m on each axis. Pure data and geometry.
## HullLayout asks which faces show, HullDressing draws them, and
## ExteriorBuilder takes colliders from them.

const CUBE := &"cube"
const SLOPE := &"slope"
const SLOPE_LONG_LOW := &"slope_long_low"
const SLOPE_LONG_HIGH := &"slope_long_high"
const CORNER_OUT := &"corner_out"
const CORNER_IN := &"corner_in"
const HALF := &"half"

## Every block that is not a cube. `hull_wedge` and `canopy` have always been
## this wedge; the fairings are the new shapes.
const BY_ID := {
	&"hull_wedge": SLOPE,
	&"canopy": SLOPE,
	&"fairing_slope": SLOPE,
	&"fairing_slope_long_low": SLOPE_LONG_LOW,
	&"fairing_slope_long_high": SLOPE_LONG_HIGH,
	&"fairing_corner_out": CORNER_OUT,
	&"fairing_corner_in": CORNER_IN,
	&"fairing_half": HALF,
}

## Each shape's corners, and its faces as indices into them. The four bottom
## corners come first in every shape: B0 front-left, B1 front-right, B2
## back-right, B3 back-left.
const _SOLIDS := {
	&"cube": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		"faces": [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]],
	},
	# A full bottom rising to a full back: the old hull_wedge.
	&"slope": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		"faces": [[0, 1, 2, 3], [3, 2, 4, 5], [1, 2, 4], [0, 3, 5], [0, 1, 4, 5]],
	},
	# The lower half of a two-cell ramp: 0 to 1 m of rise across the cell.
	&"slope_long_low": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(1, 0, 1), Vector3(-1, 0, 1)],
		"faces": [[0, 1, 2, 3], [3, 2, 4, 5], [1, 2, 4], [0, 3, 5], [0, 1, 4, 5]],
	},
	# The upper half: a metre of block with the ramp's second metre on top.
	&"slope_long_high": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		"faces": [[0, 1, 2, 3], [0, 1, 5, 4], [3, 2, 6, 7], [1, 2, 6, 5], [0, 3, 7, 4], [4, 5, 6, 7]],
	},
	# Where two slopes meet round a convex corner: a quarter pyramid.
	&"corner_out": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(1, 1, 1)],
		"faces": [[0, 1, 2, 3], [1, 2, 4], [3, 2, 4], [0, 1, 4], [0, 3, 4]],
	},
	# Where two slopes meet round a concave corner: a slope rising to +z and
	# one rising to +x, together. Not convex: the valley runs corner to corner.
	&"corner_in": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)],
		"faces": [[0, 1, 2, 3], [1, 2, 5, 6], [3, 2, 5, 4], [0, 3, 4], [0, 1, 6], [0, 4, 5], [0, 5, 6]],
	},
	# The bottom half of a cell. Turned over (orientation 2), the top half.
	&"half": {
		"points": [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)],
		"faces": [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]],
	},
}

static var _faces_cache: Dictionary = {}

static func shape_of(block_id: StringName) -> StringName:
	return BY_ID.get(block_id, CUBE)

static func points(shape: StringName) -> PackedVector3Array:
	return PackedVector3Array(_SOLIDS[shape]["points"])

## Every face: its points round the face, its unit normal out of the solid,
## the cell face it lies on (`side`, ZERO for a slope or a half's top), and
## whether it fills that whole cell face (`full`).
static func faces(shape: StringName) -> Array[Dictionary]:
	if not _faces_cache.has(shape):
		_faces_cache[shape] = _build_faces(shape)
	return _faces_cache[shape]

static func _build_faces(shape: StringName) -> Array[Dictionary]:
	var pts := points(shape)
	var centre := Vector3.ZERO
	for p in pts:
		centre += p
	centre /= pts.size()
	var out: Array[Dictionary] = []
	for indices: Array in _SOLIDS[shape]["faces"]:
		var fp := PackedVector3Array()
		for i: int in indices:
			fp.append(pts[i])
		var n := (fp[1] - fp[0]).cross(fp[2] - fp[0]).normalized()
		var mid := Vector3.ZERO
		for p in fp:
			mid += p
		mid /= fp.size()
		if n.dot(mid - centre) < 0.0:
			n = -n
		var side := _side_of(fp)
		out.append({"points": fp, "normal": n, "side": side,
			"full": side != Vector3i.ZERO and is_equal_approx(_area(fp), 4.0)})
	return out

static func _side_of(fp: PackedVector3Array) -> Vector3i:
	for axis in 3:
		for s: float in [-1.0, 1.0]:
			var on := true
			for p in fp:
				if not is_equal_approx(p[axis], s):
					on = false
					break
			if on:
				var v := Vector3i.ZERO
				v[axis] = int(s)
				return v
	return Vector3i.ZERO

static func _area(fp: PackedVector3Array) -> float:
	var sum := Vector3.ZERO
	for i in range(1, fp.size() - 1):
		sum += (fp[i] - fp[0]).cross(fp[i + 1] - fp[0])
	return sum.length() * 0.5

## Whether a block of `shape`, turned by `orientation`, fills its whole cell
## face toward `hull_normal`: if so, whatever is on the other side is hidden.
static func covers(shape: StringName, orientation: int, hull_normal: Vector3i) -> bool:
	if shape == CUBE:
		return true
	var local := BlockOrientation.basis_for(orientation).inverse() * Vector3(hull_normal)
	var side := Vector3i(roundi(local.x), roundi(local.y), roundi(local.z))
	for face in faces(shape):
		if face["side"] == side and face["full"]:
			return true
	return false

## Whether a block-local point is inside the solid.
static func contains(shape: StringName, p: Vector3) -> bool:
	const E := 0.0001
	if absf(p.x) > 1.0 + E or absf(p.y) > 1.0 + E or absf(p.z) > 1.0 + E:
		return false
	match shape:
		SLOPE:
			return p.y <= p.z + E
		SLOPE_LONG_LOW:
			return p.y <= (p.z - 1.0) * 0.5 + E
		SLOPE_LONG_HIGH:
			return p.y <= (p.z + 1.0) * 0.5 + E
		CORNER_OUT:
			return p.y <= minf(p.x, p.z) + E
		CORNER_IN:
			return p.y <= maxf(p.x, p.z) + E
		HALF:
			return p.y <= E
	return true

## The convex pieces a collider is made of, block-local. The inner corner is
## not convex, so it is its two slopes.
static func collider_parts(shape: StringName) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	if shape == CORNER_IN:
		var slope := points(SLOPE)
		out.append(slope)
		var turned := PackedVector3Array()
		var quarter := Basis(Vector3.UP, PI * 0.5)   # its rise, +z, turned to +x
		for p in slope:
			turned.append(quarter * p)
		out.append(turned)
	else:
		out.append(points(shape))
	return out
