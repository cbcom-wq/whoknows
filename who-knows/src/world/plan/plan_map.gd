class_name PlanMap
extends RefCounted

## A world plan's coarse map (docs/superpowers/specs/2026-11-19-wadis-land-design.md
## §5.1): a few fields, each held at the corners of the quadtree's cells at
## PLAN_DEPTH on every cube face, and read between them bilinearly in the face's
## (u, v) (CubeSphere's spherified mapping). Built once, then only read, from
## any thread; reading allocates nothing.
##
## The corner rule: a field is worked out from each corner's direction alone
## (corner_dir), and a corner on a face's edge, shared by two faces (three at a
## cube corner), is one corner: one direction, and set_corner writes every
## face's copy of it. So a field read across a face's edge comes to the same
## value from either side.
##
## Also the least and most height under each quadtree node (set_bounds), for
## the streaming's bounds (§8.3).

## Cells are the quadtree's nodes at this depth: CELLS along a face's edge,
## 1.34 km each on WADIS.
const PLAN_DEPTH := 6
const CELLS := 1 << PLAN_DEPTH
## Corners along a face's edge.
const SIDE := CELLS + 1

## Values per corner.
var fields: int
## Every field at every face's corners: corner (i, j) of `face` is
## k = (face * SIDE + j) * SIDE + i, and its field f is at k * fields + f.
var _values := PackedFloat32Array()
## By k, the direction of each corner; a shared corner's copies hold the same.
var _dirs := PackedVector3Array()
## By k, for a corner on a face's edge only: every k that is a copy of it,
## itself among them.
var _copies := {}
## The least and most height under each node, depth by depth from 0 to
## PLAN_DEPTH: the nodes at depth d (n = 2^d across a face) start at
## 6 * (n * n - 1) / 3, face by face, row by row.
var _low := PackedFloat32Array()
var _high := PackedFloat32Array()

func _init(p_fields: int) -> void:
	fields = p_fields
	_values.resize(CubeSphere.FACES * SIDE * SIDE * fields)
	_values.fill(0.0)
	_dirs.resize(CubeSphere.FACES * SIDE * SIDE)
	# The corners on faces' edges, by their point on the cube in half cells
	# (exact), so each face's copy of one is found.
	var shared := {}
	for face in CubeSphere.FACES:
		var axes: Array = CubeSphere.AXES[face]
		for j in SIDE:
			var v := -1.0 + j * 2.0 / CELLS
			for i in SIDE:
				var k := (face * SIDE + j) * SIDE + i
				_dirs[k] = CubeSphere.direction(face, -1.0 + i * 2.0 / CELLS, v)
				if i == 0 or j == 0 or i == CELLS or j == CELLS:
					var p := Vector3i(axes[0] * CELLS + axes[1] * (2 * i - CELLS) + axes[2] * (2 * j - CELLS))
					if not shared.has(p):
						shared[p] = PackedInt32Array()
					shared[p].append(k)
	for p: Vector3i in shared:
		var copies: PackedInt32Array = shared[p]
		for k in copies:
			_copies[k] = copies
			_dirs[k] = _dirs[copies[0]]

## The unit direction of corner (i, j) of `face`, 0 to CELLS each way: what its
## fields are worked out from.
func corner_dir(face: int, i: int, j: int) -> Vector3:
	return _dirs[(face * SIDE + j) * SIDE + i]

## Sets `field` at corner (i, j) of `face`, and at every other face's copy of it.
func set_corner(field: int, face: int, i: int, j: int, value: float) -> void:
	var k := (face * SIDE + j) * SIDE + i
	if i == 0 or j == 0 or i == CELLS or j == CELLS:
		for c: int in _copies[k]:
			_values[c * fields + field] = value
	else:
		_values[k * fields + field] = value

func corner(field: int, face: int, i: int, j: int) -> float:
	return _values[((face * SIDE + j) * SIDE + i) * fields + field]

## Sets `field` to `value` at every corner.
func fill(field: int, value: float) -> void:
	for k in range(field, _values.size(), fields):
		_values[k] = value

## `field` at `dir`, bilinear in the cell it falls in.
func at(field: int, dir: Vector3) -> float:
	var cell := _locate(dir)
	var fu := cell.y
	var fv := cell.z
	var k := int(cell.x) * fields + field
	var up := SIDE * fields
	var a := _values[k]
	var b := _values[k + fields]
	var c := _values[k + up]
	var e := _values[k + up + fields]
	if a == b and a == c and a == e:
		return a
	var s := a * ((1.0 - fu) * (1.0 - fv)) + b * (fu * (1.0 - fv)) + c * ((1.0 - fu) * fv) + e * (fu * fv)
	# NaN only where an INF corner had no weight: as far as INF.
	return s if s == s else INF

## Every field at `dir` into `out` (fields long), each as at() gives it, to the
## bit, or only the first `count` of them, and gives back the number of the
## cell it falls in (as cell_number does). Where it falls (_locate) and the
## blend are written out here, since this runs per height.
func sample(dir: Vector3, out: PackedFloat64Array, count := -1) -> int:
	# _locate(dir), written out.
	var d := dir.normalized()
	var ax := absf(d.x)
	var ay := absf(d.y)
	var az := absf(d.z)
	var face: int
	var b: float
	var c: float
	if ax >= ay and ax >= az:
		if d.x > 0.0:
			face = 0; b = -d.z; c = d.y
		else:
			face = 1; b = d.z; c = d.y
	elif ay >= az:
		if d.y > 0.0:
			face = 2; b = d.x; c = -d.z
		else:
			face = 3; b = d.x; c = d.z
	elif d.z > 0.0:
		face = 4; b = d.x; c = d.y
	else:
		face = 5; b = -d.x; c = d.y
	var bb := b * b
	var cc := c * c
	var q := 3.0 - 2.0 * bb + 2.0 * cc
	var vv := 12.0 * cc / (q + sqrt(maxf(0.0, q * q - 24.0 * cc)))
	q = 3.0 + 2.0 * bb - 2.0 * cc
	var uu := 12.0 * bb / (q + sqrt(maxf(0.0, q * q - 24.0 * bb)))
	var x := clampf((b / sqrt(0.5 - vv / 6.0) + 1.0) * 0.5 * CELLS, 0.0, CELLS)
	var y := clampf((c / sqrt(0.5 - uu / 6.0) + 1.0) * 0.5 * CELLS, 0.0, CELLS)
	var ix := mini(int(x), CELLS - 1)
	var iy := mini(int(y), CELLS - 1)
	# As 32-bit floats, as _locate's Vector3 holds them.
	var across := Vector2(x - ix, y - iy)
	var fu := across.x
	var fv := across.y
	var w00 := (1.0 - fu) * (1.0 - fv)
	var w10 := fu * (1.0 - fv)
	var w01 := (1.0 - fu) * fv
	var w11 := fu * fv
	var values := _values
	var stride := fields
	var k := ((face * SIDE + iy) * SIDE + ix) * stride
	var up := SIDE * stride
	var over := up + stride
	for f in (stride if count < 0 else count):
		var a := values[k]
		var e := values[k + stride]
		var g := values[k + up]
		var h := values[k + over]
		if a == e and a == g and a == h:
			out[f] = a
		else:
			var s := a * w00 + e * w10 + g * w01 + h * w11
			out[f] = s if s == s else INF   # as in at()
		k += 1
	return (face * CELLS + iy) * CELLS + ix

## The number of the cell `dir` falls in, (face * CELLS + j) * CELLS + i: as
## cell_of's, but in closed form, so cheap enough to ask per height. Within a
## hair of a cell's edge the two may differ, and either cell holds the
## direction.
func cell_number(dir: Vector3) -> int:
	return _number(int(_locate(dir).x))

## The cell `dir` falls in: the quadtree's node at PLAN_DEPTH.
func cell_of(dir: Vector3) -> Vector4i:
	return CubeSphere.key_for(dir, PLAN_DEPTH)

## The four cells that share an edge with `cell`, across a face's edge too.
func neighbours(cell: Vector4i) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	var ix := cell.z
	var iy := cell.w
	if ix > 0 and iy > 0 and ix < CELLS - 1 and iy < CELLS - 1:
		out.append(Vector4i(cell.x, PLAN_DEPTH, ix + 1, iy))
		out.append(Vector4i(cell.x, PLAN_DEPTH, ix - 1, iy))
		out.append(Vector4i(cell.x, PLAN_DEPTH, ix, iy + 1))
		out.append(Vector4i(cell.x, PLAN_DEPTH, ix, iy - 1))
		return out
	# The cell's centre on the cube in half cells, stepped one cell each way
	# and, off its face, folded over the edge onto the next.
	var axes: Array = CubeSphere.AXES[cell.x]
	var n := Vector3i(axes[0])
	var eu := Vector3i(axes[1])
	var ev := Vector3i(axes[2])
	var centre := n * CELLS + eu * (2 * ix + 1 - CELLS) + ev * (2 * iy + 1 - CELLS)
	for step: Vector3i in [eu * 2, eu * -2, ev * 2, ev * -2]:
		var p := centre + step
		var off := step.abs().max_axis_index()
		if absi(p[off]) > CELLS:
			p[off] -= signi(p[off])
			var normal := n.abs().max_axis_index()
			p[normal] -= signi(p[normal])
		out.append(_cell_at(p))
	return out

## Sets the least and most height of each cell at PLAN_DEPTH (6 * CELLS * CELLS
## of each, face by face, row by row), and works out every coarser node's from
## the cells under it.
func set_bounds(low: PackedFloat32Array, high: PackedFloat32Array) -> void:
	var cells := CubeSphere.FACES * CELLS * CELLS
	var start := _start(PLAN_DEPTH)
	_low.resize(start + cells)
	_high.resize(start + cells)
	for k in cells:
		_low[start + k] = low[k]
		_high[start + k] = high[k]
	for depth in range(PLAN_DEPTH - 1, -1, -1):
		var n := 1 << depth
		var at := _start(depth)
		var below := _start(depth + 1)
		for face in CubeSphere.FACES:
			for y in n:
				var row := below + (face * n * 2 + y * 2) * n * 2
				for x in n:
					var a := row + x * 2
					var b := a + n * 2
					_low[at] = minf(minf(_low[a], _low[a + 1]), minf(_low[b], _low[b + 1]))
					_high[at] = maxf(maxf(_high[a], _high[a + 1]), maxf(_high[b], _high[b + 1]))
					at += 1

## Vector2(least, most) height under the quadtree node `key`: its cell's at
## PLAN_DEPTH or deeper, else over all the cells under it. After set_bounds.
func bounds_of(key: Vector4i) -> Vector2:
	var depth := key.y
	var ix := key.z
	var iy := key.w
	if depth > PLAN_DEPTH:
		ix >>= depth - PLAN_DEPTH
		iy >>= depth - PLAN_DEPTH
		depth = PLAN_DEPTH
	var n := 1 << depth
	var at := _start(depth) + (key.x * n + iy) * n + ix
	return Vector2(_low[at], _high[at])

## Fills `low` and `high`, one per cell in set_bounds' order, with the least
## and most of `field` over each cell's four corners: what it reaches in the
## cell, since it is read bilinearly. With `pad` (a value by corner, by k), the
## least is less, and the most more, by the most of it over the cell's corners.
func cell_range(field: int, low: PackedFloat32Array, high: PackedFloat32Array, pad := PackedFloat32Array()) -> void:
	var cells := CubeSphere.FACES * CELLS * CELLS
	low.resize(cells)
	high.resize(cells)
	var up := SIDE * fields
	var padded := not pad.is_empty()
	var cell := 0
	for face in CubeSphere.FACES:
		for j in CELLS:
			var corner := (face * SIDE + j) * SIDE
			var k := corner * fields + field
			for i in CELLS:
				var a := _values[k]
				var b := _values[k + fields]
				var c := _values[k + up]
				var e := _values[k + up + fields]
				var by := 0.0
				if padded:
					by = maxf(maxf(pad[corner], pad[corner + 1]), maxf(pad[corner + SIDE], pad[corner + SIDE + 1]))
					corner += 1
				low[cell] = minf(minf(a, b), minf(c, e)) - by
				high[cell] = maxf(maxf(a, b), maxf(c, e)) + by
				k += fields
				cell += 1

## `field` at every corner, by k.
func values_of(field: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := _values.size() / fields
	out.resize(count)
	var at := field
	for k in count:
		out[k] = _values[at]
		at += fields
	return out

## Where `dir` falls: Vector3(k of its cell's first corner, how far across the
## cell it lies in u and in v, 0 to 1). The face's (u, v) comes from inverting
## CubeSphere.direction in closed form: on face (n, eu, ev) a unit direction's
## b = d . eu is u * sqrt(1/2 - v^2/6) and its c = d . ev is
## v * sqrt(1/2 - u^2/6), so v^2 solves v^4 + (2b^2 - 2c^2 - 3) v^2 + 6c^2 = 0
## (the smaller root, written without cancelling), and u^2 likewise. The face
## (CubeSphere.face_of) and b and c (by CubeSphere.AXES) are written out, and
## sample() writes all of this out again, since it runs per height: each axis
## is a unit axis, so each dot is one of d's components, exactly.
func _locate(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var ax := absf(d.x)
	var ay := absf(d.y)
	var az := absf(d.z)
	var face: int
	var b: float
	var c: float
	if ax >= ay and ax >= az:
		if d.x > 0.0:
			face = 0; b = -d.z; c = d.y
		else:
			face = 1; b = d.z; c = d.y
	elif ay >= az:
		if d.y > 0.0:
			face = 2; b = d.x; c = -d.z
		else:
			face = 3; b = d.x; c = d.z
	elif d.z > 0.0:
		face = 4; b = d.x; c = d.y
	else:
		face = 5; b = -d.x; c = d.y
	var bb := b * b
	var cc := c * c
	var q := 3.0 - 2.0 * bb + 2.0 * cc
	var vv := 12.0 * cc / (q + sqrt(maxf(0.0, q * q - 24.0 * cc)))
	q = 3.0 + 2.0 * bb - 2.0 * cc
	var uu := 12.0 * bb / (q + sqrt(maxf(0.0, q * q - 24.0 * bb)))
	var x := clampf((b / sqrt(0.5 - vv / 6.0) + 1.0) * 0.5 * CELLS, 0.0, CELLS)
	var y := clampf((c / sqrt(0.5 - uu / 6.0) + 1.0) * 0.5 * CELLS, 0.0, CELLS)
	var ix := mini(int(x), CELLS - 1)
	var iy := mini(int(y), CELLS - 1)
	return Vector3((face * SIDE + iy) * SIDE + ix, x - ix, y - iy)

## The number of the cell whose first corner is k (as _locate gives it).
static func _number(k: int) -> int:
	var face := k / (SIDE * SIDE)
	var at := k % (SIDE * SIDE)
	return (face * CELLS + at / SIDE) * CELLS + at % SIDE

## The cell whose centre is `p`, on the cube in half cells.
static func _cell_at(p: Vector3i) -> Vector4i:
	var face := CubeSphere.face_of(Vector3(p))
	var axes: Array = CubeSphere.AXES[face]
	var eu := Vector3i(axes[1])
	var ev := Vector3i(axes[2])
	var u := p.x * eu.x + p.y * eu.y + p.z * eu.z
	var v := p.x * ev.x + p.y * ev.y + p.z * ev.z
	return Vector4i(face, PLAN_DEPTH, (u + CELLS - 1) / 2, (v + CELLS - 1) / 2)

## Where the bounds of the nodes at `depth` start.
static func _start(depth: int) -> int:
	var n := 1 << depth
	return CubeSphere.FACES * (n * n - 1) / 3
