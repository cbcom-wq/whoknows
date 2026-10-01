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
## The ground's triangles alone, relative to centre: for collision.
var faces := PackedVector3Array()

static func build(terrain: WorldTerrain, p_key: Vector4i) -> TerrainChunkData:
	var c := TerrainChunkData.new()
	c.key = p_key
	var n := CubeSphere.QUADS
	var rect := CubeSphere.node_rect(p_key)
	var step := rect.z / n
	var mid := CubeSphere.direction(p_key.x, rect.x + rect.z * 0.5, rect.y + rect.z * 0.5)
	var mid_r := terrain.radius + terrain.height_at(mid)
	c.centre = Vector3i(roundi(mid.x * mid_r), roundi(mid.y * mid_r), roundi(mid.z * mid_r))
	var cx := float(c.centre.x)
	var cy := float(c.centre.y)
	var cz := float(c.centre.z)
	var dirs := PackedVector3Array()
	dirs.resize((n + 1) * (n + 1))
	c.grid.resize((n + 1) * (n + 1))
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
	for k in n:
		c._skirt(terrain, dirs, k, k + 1, drop, patch)                                   # v = start
		c._skirt(terrain, dirs, n * (n + 1) + k, n * (n + 1) + k + 1, drop, patch)       # v = end
		c._skirt(terrain, dirs, k * (n + 1), (k + 1) * (n + 1), drop, patch)             # u = start
		c._skirt(terrain, dirs, k * (n + 1) + n, (k + 1) * (n + 1) + n, drop, patch)     # u = end
	return c

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
	var normal := -cross.normalized()
	var colour := terrain.colour_at(out, normal.angle_to(out), patch)
	positions.append_array(PackedVector3Array([a, b, c]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	colours.append_array(PackedColorArray([colour, colour, colour]))
	faces.append_array(PackedVector3Array([a, b, c]))

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
