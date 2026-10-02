class_name CubeSphere
extends RefCounted

## The six faces of a cube pushed out onto a sphere, and the quadtree on each
## (Planetfall §6.4; docs/superpowers/specs/2026-09-30-world-scale-design.md
## §5.2). Pure. A node is Vector4i(face, depth, ix, iy): at depth d a face is
## 2^d nodes across, each covering u from -1 + ix * 2 / 2^d over 2 / 2^d, and
## v likewise. The spherified-cube mapping keeps cells nearly even in size.
##
## Neighbouring faces meet exactly: the cube point on one face's edge is
## computed from the same numbers on the other's, so shared edges agree to
## the last bit.

const FACES := 6
## Quads along a chunk's edge.
const QUADS := 16
## The finest quad, metres, at most.
const FINEST_QUAD := 2.0
## Per face: its outward axis, then its u and v axes.
const AXES := [
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
]

## The unit direction at (u, v) on `face`.
static func direction(face: int, u: float, v: float) -> Vector3:
	var axes: Array = AXES[face]
	var p: Vector3 = axes[0] + axes[1] * u + axes[2] * v
	var x2 := p.x * p.x
	var y2 := p.y * p.y
	var z2 := p.z * p.z
	return Vector3(
		p.x * sqrt(maxf(0.0, 1.0 - y2 * 0.5 - z2 * 0.5 + y2 * z2 / 3.0)),
		p.y * sqrt(maxf(0.0, 1.0 - z2 * 0.5 - x2 * 0.5 + z2 * x2 / 3.0)),
		p.z * sqrt(maxf(0.0, 1.0 - x2 * 0.5 - y2 * 0.5 + x2 * y2 / 3.0)))

## The face a direction lies on.
static func face_of(d: Vector3) -> int:
	var a := d.abs()
	if a.x >= a.y and a.x >= a.z:
		return 0 if d.x > 0.0 else 1
	if a.y >= a.z:
		return 2 if d.y > 0.0 else 3
	return 4 if d.z > 0.0 else 5

## Vector3(face, u, v) for `dir`: the plain cube projection, refined by a few
## Newton steps onto the spherified mapping.
static func face_uv(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var face := face_of(d)
	var axes: Array = AXES[face]
	var k: float = d.dot(axes[0])
	var u: float = d.dot(axes[1]) / k
	var v: float = d.dot(axes[2]) / k
	for i in 6:
		var p := direction(face, u, v)
		var e := d - p
		if e.length() < 1e-7:
			break
		var h := 1e-4
		var du := (direction(face, u + h, v) - p) / h
		var dv := (direction(face, u, v + h) - p) / h
		var a11 := du.dot(du)
		var a12 := du.dot(dv)
		var a22 := dv.dot(dv)
		var b1 := du.dot(e)
		var b2 := dv.dot(e)
		var det := a11 * a22 - a12 * a12
		if absf(det) < 1e-12:
			break
		u += (a22 * b1 - a12 * b2) / det
		v += (a11 * b2 - a12 * b1) / det
	return Vector3(face, clampf(u, -1.0, 1.0), clampf(v, -1.0, 1.0))

## The node at `depth` holding `dir`.
static func key_for(dir: Vector3, depth: int) -> Vector4i:
	var fuv := face_uv(dir)
	var n := 1 << depth
	var ix := clampi(floori((fuv.y + 1.0) * 0.5 * n), 0, n - 1)
	var iy := clampi(floori((fuv.z + 1.0) * 0.5 * n), 0, n - 1)
	return Vector4i(int(fuv.x), depth, ix, iy)

## Vector3(u0, v0, size): where a node starts on its face, and its width.
static func node_rect(key: Vector4i) -> Vector3:
	var size := 2.0 / float(1 << key.y)
	return Vector3(-1.0 + key.z * size, -1.0 + key.w * size, size)

static func children(key: Vector4i) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	for k in 4:
		out.append(Vector4i(key.x, key.y + 1, key.z * 2 + (k & 1), key.w * 2 + (k >> 1)))
	return out

static func parent(key: Vector4i) -> Vector4i:
	return Vector4i(key.x, key.y - 1, key.z >> 1, key.w >> 1)

## The depth whose quads are FINEST_QUAD or less on a world of `radius`
## (Planetfall §6.4): 12 at 60 km, 10 at 15 km, 8 for a 4 km moon.
static func depth_for(radius: float) -> int:
	return ceili(log(PI * radius / (2.0 * QUADS * FINEST_QUAD)) / log(2.0))

## A node's edge at `depth` on a world of `radius`, metres: a face spans a
## quarter of a great circle.
static func edge_m(radius: float, depth: int) -> float:
	return PI * radius * 0.5 / float(1 << depth)

## [centre, radius] of a sphere, body-local, holding all of a node's ground
## on a world of `radius` whose ground lies within `relief` / 2 of it.
static func node_bound(key: Vector4i, radius: float, relief: float) -> Array:
	var rect := node_rect(key)
	var mid := direction(key.x, rect.x + rect.z * 0.5, rect.y + rect.z * 0.5) * radius
	var r := 0.0
	for k in 4:
		var corner := direction(key.x, rect.x + rect.z * float(k & 1), rect.y + rect.z * float(k >> 1)) * radius
		r = maxf(r, corner.distance_to(mid))
	return [mid, r + relief * 0.5]
