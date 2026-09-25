class_name RockMesh
extends RefCounted

## The base rock shapes (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §8): chunky, faceted, flat-shaded. Each is a sphere cut by a handful of
## seeded planes -- big flat facets, like stone split along its grain --
## sampled at an icosphere's vertices, so the shape is convex and its collision
## hull is the rock you see. Built once per (shape, detail) and shared by every
## rock.
##
## Diameter one: no vertex lies farther than REACH from the centre. A rock
## scales it by its diameter and stretch.

enum Shape { BOULDER, SHARD, VEINED }

## The farthest any shape's vertex lies from its centre, at diameter one.
const REACH := 0.65

## Per shape: seed, cut planes, nearest and farthest cut (a fraction of the
## radius), and a stretch baked into the shape.
const _RECIPES := {
	Shape.BOULDER: [101, 12, 0.78, 0.93, Vector3(1.0, 1.0, 1.0)],
	Shape.SHARD: [202, 9, 0.62, 0.86, Vector3(0.82, 0.74, 1.3)],
	Shape.VEINED: [303, 12, 0.76, 0.92, Vector3(1.05, 0.95, 1.0)],
}
## A veined rock's crystal: faces whose centre lies this close to the vein's
## great circle, on one side of the rock.
const _VEIN_AXIS := Vector3(0.3, 1.0, 0.2)
const _VEIN_WIDTH := 0.16

static var _spheres := {}
static var _meshes := {}
static var _points := {}
static var _planes := {}

## Builds everything worker threads read -- each shape's cut planes and the
## icospheres RockDetail uses -- so after this they only ever read.
static func warm() -> void:
	for shape in [Shape.BOULDER, Shape.SHARD, Shape.VEINED]:
		_cuts(shape)
	for detail in [0, 1, 2, RockDetail.DETAIL]:
		_icosphere(detail)

## How far out the shape's surface is along unit direction `d`, as a fraction
## of the uncut sphere's radius, before the baked stretch.
static func cut_radius(shape: int, d: Vector3) -> float:
	var r := 1.0
	for p: Vector4 in _cuts(shape):
		var along := d.x * p.x + d.y * p.y + d.z * p.z
		if along > 0.05:
			r = minf(r, p.w / along)
	return r

## The stretch baked into a shape.
static func stretch_of(shape: int) -> Vector3:
	return _RECIPES[shape][4]

## True for a face of a veined rock, facing `d`, that is crystal.
static func in_vein(d: Vector3) -> bool:
	return absf(d.dot(_VEIN_AXIS.normalized())) < _VEIN_WIDTH and d.x > -0.3

## Unit directions and triangles of an icosahedron subdivided `detail` times.
static func sphere(detail: int) -> Array:
	return _icosphere(detail)

## The shape's vertices at `detail`, diameter one, in icosphere order.
static func cut_vertices(shape: int, detail: int) -> PackedVector3Array:
	return _vertices(shape, detail)

## The shared mesh for `shape` at `detail` subdivisions (0: 20 triangles, 1:
## 80, 2: 320). Vertex colours are white, so a rock's instance colour tints it
## -- except the veined shape, which carries rock and crystal itself.
static func mesh(shape: int, detail: int) -> ArrayMesh:
	var key := shape * 10 + detail
	if not _meshes.has(key):
		_meshes[key] = _build(shape, detail)
	return _meshes[key]

## The shape's distinct vertices, for its convex collision shape.
static func hull_points(shape: int, detail: int) -> PackedVector3Array:
	var key := shape * 10 + detail
	if not _points.has(key):
		var seen := {}
		var out := PackedVector3Array()
		for v in _vertices(shape, detail):
			if not seen.has(v):
				seen[v] = true
				out.append(v)
		_points[key] = out
	return _points[key]

static func _build(shape: int, detail: int) -> ArrayMesh:
	var sphere := _icosphere(detail)
	var dirs: PackedVector3Array = sphere[0]
	var faces: PackedInt32Array = sphere[1]
	var verts := _vertices(shape, detail)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for t in range(0, faces.size(), 3):
		var a := verts[faces[t]]
		var b := verts[faces[t + 1]]
		var c := verts[faces[t + 2]]
		var cross := (b - a).cross(c - a)
		if cross.dot(a + b + c) > 0.0:
			# Godot draws the side (b - a) x (c - a) points away from.
			var swap := b
			b = c
			c = swap
			cross = -cross
		var n := -cross.normalized()
		var colour := SpacePalette.UNTINTED
		if shape == Shape.VEINED:
			var d := (dirs[faces[t]] + dirs[faces[t + 1]] + dirs[faces[t + 2]]).normalized()
			colour = SpacePalette.CRYSTAL if in_vein(d) else SpacePalette.ASH
		positions.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([n, n, n]))
		colours.append_array(PackedColorArray([colour, colour, colour]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## Every icosphere vertex, pulled in to the shape's cut planes.
static func _vertices(shape: int, detail: int) -> PackedVector3Array:
	var stretch := stretch_of(shape)
	var out := PackedVector3Array()
	var dirs: PackedVector3Array = _icosphere(detail)[0]
	for d in dirs:
		out.append(d * cut_radius(shape, d) * 0.5 * stretch)
	return out

## The shape's seeded cut planes: normal, and distance as a fraction of the
## radius.
static func _cuts(shape: int) -> Array[Vector4]:
	if _planes.has(shape):
		return _planes[shape]
	var recipe: Array = _RECIPES[shape]
	var rng := RandomNumberGenerator.new()
	rng.seed = recipe[0]
	var planes: Array[Vector4] = []
	while planes.size() < recipe[1]:
		var n := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if n.length() < 0.2:
			continue
		n = n.normalized()
		planes.append(Vector4(n.x, n.y, n.z, rng.randf_range(recipe[2], recipe[3])))
	_planes[shape] = planes
	return planes

## Unit directions and triangles of an icosahedron subdivided `detail` times.
static func _icosphere(detail: int) -> Array:
	if _spheres.has(detail):
		return _spheres[detail]
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var dirs: Array[Vector3] = []
	for c in [Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
			Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
			Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1)]:
		dirs.append(c.normalized())
	var faces := PackedInt32Array([
		0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
		1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
		4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for level in detail:
		var mids := {}
		var next := PackedInt32Array()
		for t in range(0, faces.size(), 3):
			var a := faces[t]
			var b := faces[t + 1]
			var c := faces[t + 2]
			var ab := _mid(dirs, mids, a, b)
			var bc := _mid(dirs, mids, b, c)
			var ca := _mid(dirs, mids, c, a)
			next.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
		faces = next
	var sphere := [PackedVector3Array(dirs), faces]
	_spheres[detail] = sphere
	return sphere

static func _mid(dirs: Array[Vector3], mids: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if not mids.has(key):
		mids[key] = dirs.size()
		dirs.append(((dirs[a] + dirs[b]) * 0.5).normalized())
	return mids[key]
