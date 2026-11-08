extends GutTest

## Ground cover (the desert world spec §5.6, §7.2; phase 2 plan, Task 4):
## boulders on every world, half sunk in the collision ground and solid, and
## dry grass on a desert's sand, placed the same every time from each finest
## chunk's own seed.

const N := CubeSphere.QUADS

var _system: SystemRecipe
var _desert_t: WorldTerrain
var _rolling_t: WorldTerrain

func before_all():
	# The boulders' shapes are read on workers: built here first.
	RockMesh.warm()
	GroundCover.grass_mesh()
	_system = SystemRecipe.from_seed(1337)
	_desert_t = WorldTerrain.new(_system.body(&"p3").recipe)
	var k := 1
	while true:
		var r := WorldRecipe.from_seed(k)
		if r.archetype == WorldRecipe.Archetype.ROLLING and r.kind == WorldRecipe.Kind.PLANET:
			_rolling_t = WorldTerrain.new(r)
			break
		k += 1

func after_all():
	_system = null

static func _finest(t: WorldTerrain) -> int:
	return CubeSphere.depth_for(t.radius)

static func _dir(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if v.length() > 0.1 and v.length() <= 1.0:
			return v.normalized()
	return Vector3.UP

## The middle of a finest key, as a direction.
static func _mid(key: Vector4i) -> Vector3:
	var rect := CubeSphere.node_rect(key)
	return CubeSphere.direction(key.x, rect.x + rect.z * 0.5, rect.y + rect.z * 0.5)

## `n` distinct finest keys on `t` whose middles pass `wanted`.
func _keys(t: WorldTerrain, n: int, seed: int, wanted: Callable) -> Array[Vector4i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array[Vector4i] = []
	var tries := 0
	while out.size() < n and tries < 200000:
		tries += 1
		var key := CubeSphere.key_for(_dir(rng), _finest(t))
		if out.has(key) or not wanted.call(_mid(key)):
			continue
		out.append(key)
	assert_eq(out.size(), n, "found %d keys" % n)
	return out

func _any(_d: Vector3) -> bool:
	return true

func _talus(d: Vector3) -> bool:
	return _desert_t.in_talus(d)

## Open dunes: sand off the talus, clear of where the dunes fade toward a
## mesa and of the wind axis's poles (test_world_terrain's _open_dune).
func _open(d: Vector3) -> bool:
	var t := _desert_t
	var g := t.ground_at(d, 0.0)
	return (g == &"ground_low" or g == &"dust") and not t.in_talus(d) \
		and t.continent_at(d) < WorldTerrain.MESA_FROM - WorldTerrain.MESA_EDGE \
		and absf(d.dot(t.wind_axis)) < WorldTerrain.DUNE_POLE

## The ground triangle of `c` straight under `p` (relative to its centre),
## cast down the local up: [triangle's first index, the point hit], or [].
static func _under(c: TerrainChunkData, p: Vector3) -> Array:
	var up := (p + Vector3(c.centre)).normalized()
	var from := p + up * 20.0
	var dir := -up
	for t in range(0, N * N * 6, 3):
		var a := c.faces[t]
		if a.distance_to(p) > 8.0:
			continue
		var b := c.faces[t + 1]
		var cc := c.faces[t + 2]
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir, a, b, cc)
		if hit != null:
			return [t, hit]
	return []

## How steep the triangle at `t` is, and which ground it is, as the chunk
## colours it: [slope, ground].
static func _ground_of(terrain: WorldTerrain, c: TerrainChunkData, t: int) -> Array:
	var a := c.faces[t]
	var b := c.faces[t + 1]
	var cc := c.faces[t + 2]
	var centre := Vector3(c.centre)
	var out := ((a + centre).normalized() + (b + centre).normalized() + (cc + centre).normalized()).normalized()
	var n := (b - a).cross(cc - a).normalized()
	if n.dot(out) < 0.0:
		n = -n
	var slope := n.angle_to(out)
	return [slope, terrain.ground_at(out, slope)]

static func _shades(base: Color) -> Array[Color]:
	var out: Array[Color] = []
	for k in SpacePalette.SHADES.size():
		out.append(SpacePalette.shade(base, k))
	return out

static func _area_100(t: WorldTerrain) -> float:
	var e := CubeSphere.edge_m(t.radius, _finest(t))
	return e * e / 100.0

func test_the_same_chunk_gives_the_same_cover():
	var keys := _keys(_desert_t, 400, 1, _talus)
	var key := keys[0]
	for k in keys:
		var c := GroundCover.scatter(_desert_t, k)
		if c.boulders.size() > 0 and c.grass.size() > 0:
			key = k
			break
	var a := GroundCover.scatter(_desert_t, key)
	assert_gt(a.boulders.size(), 0, "a chunk with stones")
	assert_gt(a.grass.size(), 0, "and tufts")
	var recipe := _desert_t.recipe
	var out := [null]
	var id := WorkerThreadPool.add_task(func() -> void:
		out[0] = GroundCover.scatter(WorldTerrain.new(recipe), key))
	WorkerThreadPool.wait_for_task_completion(id)
	var b: GroundCover = out[0]
	assert_eq(b.boulders, a.boulders, "stone for stone, on a worker")
	assert_eq(b.grass, a.grass, "tuft for tuft, on a worker")
	assert_eq(b.boulder_faces(), a.boulder_faces())

func test_neighbours_differ():
	var differ := 0
	for key in _keys(_rolling_t, 20, 2, _any):
		var next := Vector4i(key.x, key.y, key.z + 1 if key.z + 1 < (1 << key.y) else key.z - 1, key.w)
		var a := GroundCover.scatter(_rolling_t, key)
		var b := GroundCover.scatter(_rolling_t, next)
		if a.boulders.is_empty() and b.boulders.is_empty():
			continue
		assert_ne(a.boulders, b.boulders, "%s and %s" % [key, next])
		differ += 1
	assert_gt(differ, 10)

func test_boulders_sit_on_the_collision_ground():
	var seen := 0
	var chunks: Array = []
	for key in _keys(_rolling_t, 15, 3, _any):
		chunks.append([_rolling_t, key])
	for key in _keys(_desert_t, 15, 3, _talus):
		chunks.append([_desert_t, key])
	for entry in chunks:
		var t: WorldTerrain = entry[0]
		var c := TerrainChunkData.build(t, entry[1])
		var up_of := Vector3(c.centre)
		for b: Array in GroundCover.scatter(t, entry[1]).boulders:
			var place: Transform3D = b[0]
			var d: float = b[3]
			var hit := _under(c, place.origin)
			assert_false(hit.is_empty(), "%s: ground under a boulder" % entry[1])
			if hit.is_empty():
				continue
			var ground: Vector3 = hit[1]
			var up := (place.origin + up_of).normalized()
			var lo := INF
			var hi := -INF
			for v in RockMesh.cut_vertices(b[1], 0):
				var h := (place * v - ground).dot(up)
				lo = minf(lo, h)
				hi = maxf(hi, h)
			assert_lt(lo, 0.0, "the ground passes through it")
			assert_gt(hi, 0.0, "the ground passes through it")
			# Sunk from the collision triangle's own point, to the millimetre: a
			# height sampled between the corners would be centimetres out.
			assert_almost_eq(-lo, GroundCover.BOULDER_SUNK * d, 1e-3, "a third of it sunk (%.4f m of %.2f)" % [-lo, d])
			seen += 1
	gut.p("%d boulders on 30 chunks" % seen)
	assert_gt(seen, 40)

func test_sizes_and_slopes():
	var chunks: Array = []
	for key in _keys(_rolling_t, 30, 4, _any):
		chunks.append([_rolling_t, key])
	for key in _keys(_desert_t, 20, 4, _talus):
		chunks.append([_desert_t, key])
	for key in _keys(_desert_t, 20, 4, _open):
		chunks.append([_desert_t, key])
	var stones := 0
	var tufts := 0
	for entry in chunks:
		var t: WorldTerrain = entry[0]
		var c := TerrainChunkData.build(t, entry[1])
		var cover := GroundCover.scatter(t, entry[1])
		for b: Array in cover.boulders:
			assert_between(float(b[3]), GroundCover.BOULDER_SIZE.x, GroundCover.BOULDER_SIZE.y)
			var hit := _under(c, (b[0] as Transform3D).origin)
			if not hit.is_empty():
				assert_lte(float(_ground_of(t, c, hit[0])[0]), GroundCover.BOULDER_SLOPE + 1e-4, "a boulder on a slope")
				stones += 1
		for g: Array in cover.grass:
			var hit := _under(c, (g[0] as Transform3D).origin)
			assert_false(hit.is_empty(), "ground under a tuft")
			if not hit.is_empty():
				assert_lte(float(_ground_of(t, c, hit[0])[0]), GroundCover.GRASS_SLOPE + 1e-4, "a tuft on a slope")
				tufts += 1
			var s := (g[0] as Transform3D).basis.get_scale()
			assert_between(s.y, GroundCover.GRASS_HEIGHT.x - 1e-4, GroundCover.GRASS_HEIGHT.y + 1e-4)
	gut.p("%d stones, %d tufts" % [stones, tufts])
	assert_gt(stones, 50)
	assert_gt(tufts, 20)

func test_grass_only_on_desert_sand():
	for key in _keys(_rolling_t, 30, 5, _any):
		assert_eq(GroundCover.scatter(_rolling_t, key).grass.size(), 0, "no grass off a desert")
	var tufts := 0
	var chunks := _keys(_desert_t, 50, 5, _open)
	var on := {}
	for key in chunks:
		var c := TerrainChunkData.build(_desert_t, key)
		for g: Array in GroundCover.scatter(_desert_t, key).grass:
			var hit := _under(c, (g[0] as Transform3D).origin)
			if hit.is_empty():
				continue
			var ground: StringName = _ground_of(_desert_t, c, hit[0])[1]
			assert_true(ground == &"ground_low" or ground == &"dust", "a tuft on %s" % ground)
			on[ground] = int(on.get(ground, 0)) + 1
			tufts += 1
	gut.p("%d tufts over 50 open chunks: %s" % [tufts, on])
	assert_gt(tufts, 0, "some grass on the sand")
	# And by the mesas and towers, where rock and mesa tops are near, still
	# none on them.
	for key in _keys(_desert_t, 25, 5, _talus):
		var c := TerrainChunkData.build(_desert_t, key)
		for g: Array in GroundCover.scatter(_desert_t, key).grass:
			var hit := _under(c, (g[0] as Transform3D).origin)
			if not hit.is_empty():
				var ground: StringName = _ground_of(_desert_t, c, hit[0])[1]
				assert_true(ground == &"ground_low" or ground == &"dust", "a tuft on %s at the talus" % ground)

func test_boulders_gather_at_the_talus():
	var talus := 0
	for key in _keys(_desert_t, 40, 6, _talus):
		talus += GroundCover.scatter(_desert_t, key).boulders.size()
	var open := 0
	for key in _keys(_desert_t, 40, 6, _open):
		open += GroundCover.scatter(_desert_t, key).boulders.size()
	var area := 40.0 * _area_100(_desert_t)
	gut.p("per 100 m2: talus %.2f, open dunes %.2f" % [talus / area, open / area])
	assert_gte(float(talus), 5.0 * maxf(float(open), 1.0), "five times as many at the talus")

func test_density_on_other_worlds():
	var stones := 0
	for key in _keys(_rolling_t, 100, 7, _any):
		stones += GroundCover.scatter(_rolling_t, key).boulders.size()
	var per := stones / (100.0 * _area_100(_rolling_t))
	gut.p("ROLLING: %.3f boulders per 100 m2 (%d)" % [per, stones])
	assert_almost_eq(per, GroundCover.BOULDERS_PER_100M2, GroundCover.BOULDERS_PER_100M2 * 0.25)

func test_colours_come_from_the_palette():
	var chunks: Array = []
	for key in _keys(_rolling_t, 20, 8, _any):
		chunks.append([_rolling_t, key])
	for key in _keys(_desert_t, 20, 8, _talus):
		chunks.append([_desert_t, key])
	for key in _keys(_desert_t, 20, 8, _open):
		chunks.append([_desert_t, key])
	var stones := 0
	var tufts := 0
	for entry in chunks:
		var t: WorldTerrain = entry[0]
		var boulder := _shades(t.palette[&"boulder"])
		var grass := _shades(t.palette[&"grass"])
		var cover := GroundCover.scatter(t, entry[1])
		for b: Array in cover.boulders:
			assert_has(boulder, b[2], "a shade of the palette's boulder")
			stones += 1
		for g: Array in cover.grass:
			assert_has(grass, g[1], "a shade of the palette's grass")
			tufts += 1
	assert_gt(stones, 0)
	assert_gt(tufts, 0)

func test_finest_chunks_are_solid_round_their_boulders():
	var key := _keys(_desert_t, 1, 9, _talus)[0]
	var cover := GroundCover.scatter(_desert_t, key)
	assert_gt(cover.boulders.size(), 0, "a chunk with stones")
	var c := TerrainChunkData.build(_desert_t, key)
	var ground := N * N * 2 * 3
	var stones := cover.boulder_faces()
	assert_eq(stones.size(), cover.boulders.size() * RockMesh.sphere(0)[1].size())
	assert_eq(c.faces.size(), ground + stones.size())
	assert_eq(c.faces.slice(ground), stones, "the boulders' faces, as scatter says")
	assert_eq(c.positions.size(), ground + 4 * N * 4 * 3, "the drawn ground unchanged")
	var coarse := TerrainChunkData.build(_desert_t, CubeSphere.parent(key))
	assert_eq(coarse.faces.size(), ground, "a coarser chunk is the ground alone")

## Each boulder face looks out of its boulder, as the physics wants.
func test_boulder_faces_look_out():
	var key := _keys(_desert_t, 1, 10, _talus)[0]
	var cover := GroundCover.scatter(_desert_t, key)
	var faces := cover.boulder_faces()
	var per: int = (RockMesh.sphere(0)[1] as PackedInt32Array).size()
	for i in cover.boulders.size():
		var middle := (cover.boulders[i][0] as Transform3D).origin
		for k in range(i * per, (i + 1) * per, 3):
			var a := faces[k]
			var b := faces[k + 1]
			var cc := faces[k + 2]
			assert_lt((b - a).cross(cc - a).dot((a + b + cc) / 3.0 - middle), 0.0, "wound like RockDetail's")

func test_a_tuft_is_six_thin_blades_about_a_metre_tall():
	var m := GroundCover.grass_mesh()
	assert_same(GroundCover.grass_mesh(), m, "built once")
	var arrays := m.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_eq(verts.size(), 6 * 3, "six blades")
	var top := 0.0
	for v in verts:
		top = maxf(top, v.y)
	assert_between(top, 0.8, 1.2, "about a metre tall")
	for c in colours:
		assert_eq(c, SpacePalette.UNTINTED, "white: the instance colour tints it")
