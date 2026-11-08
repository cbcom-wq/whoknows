class_name GroundCover
extends RefCounted

## What lies on a world's ground near you (the desert world spec §5.6, §7.2;
## phase 2 plan, Task 4): boulders on every world, a third sunk and solid, and
## on a desert tufts of dry grass in clumps, which are not. One finest chunk's
## worth, from that chunk's own seed (WorldSeed.sub(seed, &"cover") mixed with
## its key), so it is the same every time, whatever detail is drawn, whatever
## was built before and whichever thread builds it.
##
## Everything sits on the ground the chunk's triangles describe -- the
## collision -- found in the same quad and the same triangle split
## TerrainChunkData uses, never on a height sampled between its corners. Every
## number is relative to TerrainChunkData's `centre` for the same key.
##
## The boulders are the asteroids' (style guide §3.5): RockMesh's BOULDER and
## SHARD, turned and stretched as a rock's boulders are, each a shade of the
## palette's `boulder`. On a desert they gather on the talus below the mesas
## and towers (WorldTerrain.in_talus) and are rare on the dunes. The grass is
## a shade of the palette's `grass`, on sand (`ground_low` and `dust`) alone.
##
## Pure, for worker threads: call RockMesh.warm() on the main thread first,
## and grass_mesh() too before anything draws it.

## Boulders: across, metres, skewed small (u^3); the share of that sunk below
## the ground; none on ground steeper than BOULDER_SLOPE.
const BOULDER_SIZE := Vector2(0.5, 4.0)
const BOULDER_SUNK := 0.33
const BOULDER_SLOPE := deg_to_rad(30.0)
## Boulders per 100 m^2: on any world but a desert; on a desert's dunes and
## flats; on its talus.
const BOULDERS_PER_100M2 := 0.8
const DESERT_BOULDERS := 0.15
const BOULDER_TALUS := 3.0
## Grass, on a desert alone: tufts per 100 m^2 inside a clump (none outside),
## on sand no steeper than GRASS_SLOPE; the share of the ground in a clump;
## a tuft's height, metres.
const GRASS_PER_100M2 := 5.0
const GRASS_SLOPE := deg_to_rad(15.0)
const GRASS_CLUMP := 0.35
const GRASS_HEIGHT := Vector2(0.3, 0.7)
## The clumps' noise: about this many metres across.
const GRASS_CLUMP_WAVE := 40.0
## Of the boulders this share are round (BOULDER), the rest SHARD, as on a rock.
const ROUND_SHARE := 0.55
## A tuft (grass_mesh): its blades, each this wide at its foot.
const BLADES := 6
const BLADE_WIDTH := 0.07
## splitmix64's increment, as WorldSeed and AsteroidRecipe mix with it.
const _GOLDEN := -7046029254386353131

## [Transform3D relative to the chunk's centre, shape (RockMesh.Shape),
## colour, diameter (metres)] per boulder.
var boulders: Array = []
## [Transform3D relative to the chunk's centre, colour] per tuft: its basis
## turned about the local up and scaled by its height.
var grass: Array = []

static var _tuft: ArrayMesh

## The cover of finest chunk `key` on `terrain`'s world. `grid` is the chunk's
## own TerrainChunkData.grid when its builder has it, which saves the heights:
## the cover is the same to the last bit either way.
static func scatter(terrain: WorldTerrain, key: Vector4i, grid := PackedVector3Array()) -> GroundCover:
	var cover := GroundCover.new()
	var ground := _Ground.new(terrain, key, grid)
	var rng := RandomNumberGenerator.new()
	var h := WorldSeed.sub(terrain.recipe.seed, &"cover")
	for v in [key.x, key.y, key.z, key.w]:
		h = AsteroidRecipe.mix(h ^ AsteroidRecipe.mix(v + _GOLDEN))
	rng.seed = h
	var edge := CubeSphere.edge_m(terrain.radius, key.y)
	var area := edge * edge
	var desert := terrain.recipe.is_desert()
	cover._boulders(terrain, ground, rng, area, desert)
	if desert:
		cover._grass(terrain, ground, rng, area)
	return cover

## Every boulder's detail-0 hull, relative to the chunk's centre, wound as
## RockDetail winds its boulders: so the physics sees each face's front from
## outside the stone.
func boulder_faces() -> PackedVector3Array:
	var out := PackedVector3Array()
	var tris: PackedInt32Array = RockMesh.sphere(0)[1]
	for b: Array in boulders:
		var place: Transform3D = b[0]
		var verts := RockMesh.cut_vertices(b[1], 0)
		for k in range(0, tris.size(), 3):
			var p := place * verts[tris[k]]
			var q := place * verts[tris[k + 1]]
			var r := place * verts[tris[k + 2]]
			if (q - p).cross(r - p).dot((p + q + r) / 3.0 - place.origin) > 0.0:
				out.append_array(PackedVector3Array([p, r, q]))
			else:
				out.append_array(PackedVector3Array([p, q, r]))
	return out

## One tuft at scale 1: BLADES thin triangles leaning out from a point, about
## a metre tall, in white vertex colours so each instance's colour tints it.
## Built once; call it on the main thread before any worker might.
static func grass_mesh() -> ArrayMesh:
	if _tuft != null:
		return _tuft
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for k in BLADES:
		# Spread round the foot unevenly, leaning out by turns, some shorter.
		var a := k * TAU / BLADES + 0.35 * float(k % 2)
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-out.z, 0.0, out.x) * BLADE_WIDTH * 0.5
		var foot := out * 0.04
		var tip := out * (0.22 + 0.12 * float(k % 3)) + Vector3.UP * (1.0 - 0.12 * float((k * 2) % 3))
		var p := foot - side
		var q := tip
		var r := foot + side
		var n := (q - p).cross(r - p).normalized()
		positions.append_array(PackedVector3Array([p, q, r]))
		normals.append_array(PackedVector3Array([n, n, n]))
		colours.append_array(PackedColorArray([SpacePalette.UNTINTED, SpacePalette.UNTINTED, SpacePalette.UNTINTED]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	_tuft = ArrayMesh.new()
	_tuft.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _tuft

## How many of something at `mean` a chunk: the whole part, and one more with
## the chance of its fraction.
static func _count(rng: RandomNumberGenerator, mean: float) -> int:
	var whole := floori(mean)
	return whole + (1 if rng.randf() < mean - whole else 0)

## A desert rolls at the talus's density and keeps each boulder with the
## chance of its own place's over that, so they gather where the talus is.
func _boulders(terrain: WorldTerrain, ground: _Ground, rng: RandomNumberGenerator, area: float,
		desert: bool) -> void:
	var most := BOULDER_TALUS if desert else BOULDERS_PER_100M2
	var base: Color = terrain.palette[&"boulder"]
	for n in _count(rng, area * most / 100.0):
		# Every roll is made, kept or not, so one stone never moves the next.
		var u := rng.randf()
		var v := rng.randf()
		var keep := rng.randf() * most
		var size := rng.randf()
		var stretch := Vector3(rng.randf_range(AsteroidRecipe.STRETCH_MIN, AsteroidRecipe.STRETCH_MAX),
			rng.randf_range(AsteroidRecipe.STRETCH_MIN, AsteroidRecipe.STRETCH_MAX),
			rng.randf_range(AsteroidRecipe.STRETCH_MIN, AsteroidRecipe.STRETCH_MAX))
		var turn := Basis.from_euler(Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI)))
		var shape := RockMesh.Shape.BOULDER if rng.randf() < ROUND_SHARE else RockMesh.Shape.SHARD
		var shade := rng.randi_range(0, SpacePalette.SHADES.size() - 1)
		if desert and keep >= (BOULDER_TALUS if terrain.in_talus(ground.direction(u, v)) else DESERT_BOULDERS):
			continue
		var at := ground.at(u, v)
		if at.slope > BOULDER_SLOPE:
			continue
		var diameter := lerpf(BOULDER_SIZE.x, BOULDER_SIZE.y, size * size * size)
		var basis := turn * Basis.from_scale(stretch * diameter)
		# Its lowest point BOULDER_SUNK of its diameter under the ground, along
		# the local up.
		var lo := INF
		for p in RockMesh.cut_vertices(shape, 0):
			lo = minf(lo, (basis * p).dot(at.up))
		var origin := at.point + at.up * (-BOULDER_SUNK * diameter - lo)
		boulders.append([Transform3D(basis, origin), shape, SpacePalette.shade(base, shade), diameter])

## Tufts in clumps, where a slow noise is over 1 - 2 GRASS_CLUMP, on sand.
func _grass(terrain: WorldTerrain, ground: _Ground, rng: RandomNumberGenerator, area: float) -> void:
	var clumps := FastNoiseLite.new()
	clumps.seed = WorldSeed.noise_seed(WorldSeed.sub(terrain.recipe.seed, &"grass"))
	clumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	clumps.frequency = 1.0
	clumps.fractal_type = FastNoiseLite.FRACTAL_NONE
	var scale := terrain.radius / GRASS_CLUMP_WAVE
	var base: Color = terrain.palette[&"grass"]
	for n in _count(rng, area * GRASS_PER_100M2 / 100.0):
		var u := rng.randf()
		var v := rng.randf()
		var spin := rng.randf() * TAU
		var tall := rng.randf_range(GRASS_HEIGHT.x, GRASS_HEIGHT.y)
		var shade := rng.randi_range(0, SpacePalette.SHADES.size() - 1)
		if clumps.get_noise_3dv(ground.direction(u, v) * scale) <= 1.0 - 2.0 * GRASS_CLUMP:
			continue
		var at := ground.at(u, v)
		if at.slope > GRASS_SLOPE:
			continue
		var kind := terrain.ground_at(at.out, at.slope)
		if kind != &"ground_low" and kind != &"dust":
			continue
		var across := at.up.cross(Vector3.UP if absf(at.up.y) < 0.9 else Vector3.RIGHT).normalized()
		var upright := Basis(across, at.up, across.cross(at.up)).orthonormalized()
		var basis := Basis(at.up, spin) * upright * Basis.from_scale(Vector3.ONE * tall)
		grass.append([Transform3D(basis, at.point), SpacePalette.shade(base, shade)])

## A finest chunk's ground, as TerrainChunkData triangulates it: its grid
## points worked out only where asked (or read from the chunk's own grid),
## each by TerrainChunkData.ground_point, so they are the chunk's to the bit.
class _Ground:
	var terrain: WorldTerrain
	var key: Vector4i
	var centre: Vector3i
	var rect: Vector3
	var grid: PackedVector3Array
	var have := {}

	func _init(p_terrain: WorldTerrain, p_key: Vector4i, p_grid: PackedVector3Array) -> void:
		terrain = p_terrain
		key = p_key
		centre = TerrainChunkData.centre_of(terrain, key)
		rect = CubeSphere.node_rect(key)
		grid = p_grid

	## The unit direction at (u, v), each 0 to 1 across the chunk.
	func direction(u: float, v: float) -> Vector3:
		return CubeSphere.direction(key.x, rect.x + rect.z * u, rect.y + rect.z * v)

	## The ground at (u, v): its point on the triangle there, relative to the
	## centre; the triangle's outward normal, its `out` and slope as the chunk
	## colours it; the local up at the point.
	func at(u: float, v: float) -> Spot:
		var n := CubeSphere.QUADS
		var i := mini(floori(u * n), n - 1)
		var j := mini(floori(v * n), n - 1)
		var fu := u * n - i
		var fv := v * n - j
		var p00 := _point(i, j)
		var p10 := _point(i + 1, j)
		var p01 := _point(i, j + 1)
		var p11 := _point(i + 1, j + 1)
		var spot := Spot.new()
		var a: Vector3
		var b: Vector3
		var c: Vector3
		var out: Vector3
		if fu >= fv:
			# The triangle i00-i10-i11.
			spot.point = p00 + (p10 - p00) * fu + (p11 - p10) * fv
			a = p00
			b = p10
			c = p11
			out = (_dir(i, j) + _dir(i + 1, j) + _dir(i + 1, j + 1)).normalized()
		else:
			# The triangle i00-i11-i01.
			spot.point = p00 + (p01 - p00) * fv + (p11 - p01) * fu
			a = p00
			b = p11
			c = p01
			out = (_dir(i, j) + _dir(i + 1, j + 1) + _dir(i, j + 1)).normalized()
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(out) < 0.0:
			normal = -normal
		spot.normal = normal
		spot.out = out
		spot.slope = normal.angle_to(out)
		spot.up = (spot.point + Vector3(centre)).normalized()
		return spot

	func _dir(i: int, j: int) -> Vector3:
		return TerrainChunkData.corner_dir(key, i, j)

	func _point(i: int, j: int) -> Vector3:
		var k := j * (CubeSphere.QUADS + 1) + i
		if not grid.is_empty():
			return grid[k]
		if not have.has(k):
			have[k] = TerrainChunkData.ground_point(terrain, _dir(i, j), centre)
		return have[k]

## A point on the ground and what the ground is there.
class Spot:
	var point: Vector3
	var normal: Vector3
	var out: Vector3
	var slope: float
	var up: Vector3
