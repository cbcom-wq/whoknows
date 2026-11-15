class_name TerrainChunkData
extends RefCounted

## One chunk of a world's ground (docs/superpowers/specs/2026-09-30-world-scale-design.md
## §5.2, §5.4): a quadtree node's QUADS x QUADS quads, flat-shaded with one
## colour a triangle, with a skirt round its edge to hide cracks against a
## coarser neighbour, as packed arrays for a mesh and for collision. Pure:
## built on a worker thread with that thread's own WorldTerrain.
##
## Every number is relative to `centre`, the chunk's middle rounded to whole
## metres, so no 32-bit float ever holds a world-sized offset: heights and
## the subtraction are done in 64-bit, and the node sits at
## body.point + centre in the universe.

## A skirt drops this many quads' edge below the ground.
const SKIRT_QUADS := 2.0

var key: Vector4i
## The chunk's middle, body-local, whole metres.
var centre: Vector3i
## The (QUADS + 1)^2 ground points, relative to centre, row by row in v.
var grid := PackedVector3Array()
var positions := PackedVector3Array()
var normals := PackedVector3Array()
var colours := PackedColorArray()
## For collision: the ground's triangles, relative to centre, and at the
## world's finest depth its boulders' after them (GroundCover).
var faces := PackedVector3Array()
## Built for collision alone: no positions, normals, colours or skirt (Task
## 7b: a finest chunk only an anchor wants solid skips the colours, about
## half a build). Its grid and faces are the full build's to the bit.
var solid_only := false
## Its faces as a ConcavePolygonShape3D, when the builder made it (WorldSurface
## does on its worker, off the main thread); else null.
var shape: ConcavePolygonShape3D

static func build(terrain: WorldTerrain, p_key: Vector4i, p_solid_only := false) -> TerrainChunkData:
	var c := TerrainChunkData.new()
	c.key = p_key
	c.solid_only = p_solid_only
	var n := CubeSphere.QUADS
	var rect := CubeSphere.node_rect(p_key)
	var step := rect.z / n
	c.centre = centre_of(terrain, p_key)
	var cx := float(c.centre.x)
	var cy := float(c.centre.y)
	var cz := float(c.centre.z)
	var dirs := PackedVector3Array()
	dirs.resize((n + 1) * (n + 1))
	c.grid.resize((n + 1) * (n + 1))
	# corner_dir and ground_point, written out (this runs per grid point): the
	# same numbers to the bit, which GroundCover relies on.
	for j in n + 1:
		for i in n + 1:
			var d := CubeSphere.direction(p_key.x, rect.x + i * step, rect.y + j * step)
			var r := terrain.radius + terrain.height_at(d)
			dirs[j * (n + 1) + i] = d
			c.grid[j * (n + 1) + i] = Vector3(d.x * r - cx, d.y * r - cy, d.z * r - cz)
	var quad := CubeSphere.edge_m(terrain.radius, p_key.y) / n
	var patch := quad * WorldTerrain.PATCH_QUADS
	for j in n:
		for i in n:
			var i00 := j * (n + 1) + i
			var i10 := i00 + 1
			var i01 := i00 + n + 1
			var i11 := i01 + 1
			c._ground(terrain, dirs, i00, i10, i11, patch)
			c._ground(terrain, dirs, i00, i11, i01, patch)
	var drop := quad * SKIRT_QUADS
	for k in (0 if p_solid_only else n):
		c._skirt(terrain, dirs, k, k + 1, drop, patch)                                   # v = start
		c._skirt(terrain, dirs, n * (n + 1) + k, n * (n + 1) + k + 1, drop, patch)       # v = end
		c._skirt(terrain, dirs, k * (n + 1), (k + 1) * (n + 1), drop, patch)             # u = start
		c._skirt(terrain, dirs, k * (n + 1) + n, (k + 1) * (n + 1) + n, drop, patch)     # u = end
	if p_key.y == CubeSphere.depth_for(terrain.radius):
		# The finest chunks are what is solid: their boulders are too.
		c.faces.append_array(GroundCover.scatter(terrain, p_key, c.grid).boulder_faces())
	return c

## The middle of `key`'s ground, body-local, rounded to whole metres: what a
## chunk's numbers, and its cover's, are relative to.
static func centre_of(terrain: WorldTerrain, key: Vector4i) -> Vector3i:
	var rect := CubeSphere.node_rect(key)
	var mid := CubeSphere.direction(key.x, rect.x + rect.z * 0.5, rect.y + rect.z * 0.5)
	var mid_r := terrain.radius + terrain.height_at(mid)
	return Vector3i(roundi(mid.x * mid_r), roundi(mid.y * mid_r), roundi(mid.z * mid_r))

## The unit direction of grid point (i, j) of `key`, each 0 to QUADS.
static func corner_dir(key: Vector4i, i: int, j: int) -> Vector3:
	var rect := CubeSphere.node_rect(key)
	var step := rect.z / CubeSphere.QUADS
	return CubeSphere.direction(key.x, rect.x + i * step, rect.y + j * step)

## The ground at unit direction `d`, relative to `centre`: a grid point, to
## the last bit, whoever works it out. Heights and the subtraction in 64-bit.
static func ground_point(terrain: WorldTerrain, d: Vector3, centre: Vector3i) -> Vector3:
	var r := terrain.radius + terrain.height_at(d)
	return Vector3(d.x * r - float(centre.x), d.y * r - float(centre.y), d.z * r - float(centre.z))

## How far `local` (from the world's centre) is over the ground the collision
## has there: the triangle of the finest chunk under it, found in the same
## quad and split build() makes (as GroundCover._Ground finds it), measured
## along the up through `local`. On open ground it is within centimetres of
## WorldTerrain.altitude_of; at a mesa's or a tower's lip the triangles cut
## the near-sheer edge and sit up to ~9 m under height_at (final review I1).
## About four height_at calls and a face_uv. Pure.
static func solid_altitude_of(terrain: WorldTerrain, local: Vector3) -> float:
	return drawn_altitude_of(terrain, local, CubeSphere.depth_for(terrain.radius))

## How far `local` (from the world's centre) is over the ground a chunk at
## `depth` draws there: solid_altitude_of for a coarser chunk, whose quads are
## bigger and so stray further from height_at between their corners. What a
## far piece laid on the ground (the oasis's tracks) is checked against. Pure.
static func drawn_altitude_of(terrain: WorldTerrain, local: Vector3, depth: int) -> float:
	if local.is_zero_approx():
		return -terrain.radius
	var n := CubeSphere.QUADS
	var fuv := CubeSphere.face_uv(local)
	var cells := 1 << depth
	var key := Vector4i(int(fuv.x), depth,
		clampi(floori((fuv.y + 1.0) * 0.5 * cells), 0, cells - 1),
		clampi(floori((fuv.z + 1.0) * 0.5 * cells), 0, cells - 1))
	var rect := CubeSphere.node_rect(key)
	var step := rect.z / n
	var fi := (fuv.y - rect.x) / step
	var fj := (fuv.z - rect.y) / step
	var i := clampi(floori(fi), 0, n - 1)
	var j := clampi(floori(fj), 0, n - 1)
	var up := local.normalized()
	# Each corner as build() works it out, relative to `local`; the triangle
	# i00-i10-i11 or i00-i11-i01, as build() splits the quad.
	var p00 := _solid_corner(terrain, key.x, rect.x + i * step, rect.y + j * step, local)
	var p11 := _solid_corner(terrain, key.x, rect.x + (i + 1) * step, rect.y + (j + 1) * step, local)
	var other := _solid_corner(terrain, key.x, rect.x + (i + 1) * step, rect.y + j * step, local) \
		if fi - i >= fj - j else _solid_corner(terrain, key.x, rect.x + i * step, rect.y + (j + 1) * step, local)
	var normal := (p11 - p00).cross(other - p00)
	var across := normal.dot(up)
	if absf(across) < 1e-6 * normal.length():
		return terrain.altitude_of(local)
	# Where the up through `local` meets the triangle's plane, along up.
	return -normal.dot(p00) / across

## Grid point (u, v) of `face`, as build() works it out, relative to `local`
## (64-bit until the difference).
static func _solid_corner(terrain: WorldTerrain, face: int, u: float, v: float, local: Vector3) -> Vector3:
	var d := CubeSphere.direction(face, u, v)
	var r := terrain.radius + terrain.height_at(d)
	return Vector3(d.x * r - local.x, d.y * r - local.y, d.z * r - local.z)

## One ground triangle, wound so Godot draws its outward side.
func _ground(terrain: WorldTerrain, dirs: PackedVector3Array, ia: int, ib: int, ic: int, patch: float) -> void:
	var a := grid[ia]
	var b := grid[ib]
	var c := grid[ic]
	var out := (dirs[ia] + dirs[ib] + dirs[ic]).normalized()
	var cross := (b - a).cross(c - a)
	if cross.dot(out) > 0.0:
		# Godot draws the side (b - a) x (c - a) points away from.
		var swap := b
		b = c
		c = swap
		cross = -cross
	faces.append_array(PackedVector3Array([a, b, c]))
	if solid_only:
		return
	var normal := -cross.normalized()
	var colour := terrain.colour_at(out, normal.angle_to(out), patch)
	positions.append_array(PackedVector3Array([a, b, c]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	colours.append_array(PackedColorArray([colour, colour, colour]))

## A skirt below the edge from grid point `ip` to `iq`, both ways round so
## it hides a crack whichever side it is seen from.
func _skirt(terrain: WorldTerrain, dirs: PackedVector3Array, ip: int, iq: int, drop: float, patch: float) -> void:
	var p := grid[ip]
	var q := grid[iq]
	var p2 := p - dirs[ip] * drop
	var q2 := q - dirs[iq] * drop
	var normal := (dirs[ip] + dirs[iq]).normalized()
	var colour := terrain.colour_at(normal, 0.0, patch)
	positions.append_array(PackedVector3Array([p, q, q2, p, q2, p2, p, q2, q, p, p2, q2]))
	for k in 12:
		normals.append(normal)
		colours.append(colour)
