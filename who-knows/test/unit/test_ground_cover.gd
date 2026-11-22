extends GutTest

## Ground cover (the desert world spec §5.6, §7.2; phase 2 plan, Task 4):
## boulders on every world, half sunk in the collision ground and solid, and
## dry grass on a desert's sand, placed the same every time from each finest
## chunk's own seed.

const N := CubeSphere.QUADS

var _system: SystemRecipe
## WADIS on today's desert ground (`planned = false`): its talus below the
## mesas and towers, and its open dunes, live on inside the plan's kept discs.
var _desert_t: WorldTerrain
var _rolling_t: WorldTerrain

func before_all():
	# The boulders' shapes are read on workers: built here first.
	RockMesh.warm()
	GroundCover.grass_mesh()
	_system = SystemRecipe.from_seed(1337)
	var desert := _system.body(&"p3").recipe
	desert.planned = false
	_desert_t = WorldTerrain.new(desert)
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
	# Task 7b: clustered, about half of Task 7's even 0.8 a 100 m2, and well
	# under a heart's own density.
	assert_between(per, 0.25, 0.55)
	assert_lt(per, GroundCover.BOULDERS_PER_100M2 * 0.6)

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

## The first of `n` talus keys from `seed` that has stones (clusters leave
## bare ground between).
func _stony_talus_key(n: int, seed: int) -> Vector4i:
	var keys := _keys(_desert_t, n, seed, _talus)
	for k in keys:
		if not GroundCover.scatter(_desert_t, k).boulders.is_empty():
			return k
	return keys[0]

func test_finest_chunks_are_solid_round_their_boulders():
	var key := _stony_talus_key(20, 9)
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
	var key := _stony_talus_key(20, 10)
	var cover := GroundCover.scatter(_desert_t, key)
	assert_gt(cover.boulders.size(), 0, "a chunk with stones")
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

## Task 7b: the stones gather in clusters with bare ground between, the same
## across chunk edges (a world-space mask, not each chunk's own dice). Over a
## patch of PATCH x PATCH neighbouring finest chunks the stones per chunk are
## far from even: their variance is well over their mean (a random scatter's
## is its mean, Task 7's even one's about a twentieth of it), many chunks hold
## none, and the big stones lie where the most stones are (a cluster's heart),
## the small ones round it.
const PATCH := 16

## [count per chunk, mean diameter per chunk] over the PATCH x PATCH chunks
## round `key` (clamped inside its face), only those whose middle passes
## `wanted`.
func _patch(t: WorldTerrain, key: Vector4i, wanted: Callable) -> Array:
	var cells := 1 << key.y
	var x0 := clampi(key.z - PATCH / 2, 0, cells - PATCH)
	var y0 := clampi(key.w - PATCH / 2, 0, cells - PATCH)
	var counts: Array[int] = []
	var sizes: Array[float] = []
	for j in PATCH:
		for i in PATCH:
			var k := Vector4i(key.x, key.y, x0 + i, y0 + j)
			if not wanted.call(_mid(k)):
				continue
			var bs := GroundCover.scatter(t, k).boulders
			counts.append(bs.size())
			var sum := 0.0
			for b: Array in bs:
				sum += float(b[3])
			sizes.append(sum / bs.size() if bs.size() > 0 else 0.0)
	return [counts, sizes]

## [mean, variance over mean, share empty] of `counts`.
static func _spread_of(counts: Array[int]) -> Array:
	var mean := 0.0
	for c in counts:
		mean += c
	mean /= maxf(counts.size(), 1)
	var v := 0.0
	var empty := 0
	for c in counts:
		v += (c - mean) * (c - mean)
		if c == 0:
			empty += 1
	v /= maxf(counts.size() - 1, 1)
	return [mean, v / maxf(mean, 1e-6), float(empty) / maxf(counts.size(), 1)]

## The mean stone size in the busiest quarter of the chunks with stones, and
## in the quietest quarter: [busy, quiet].
static func _sizes_by_crowd(counts: Array[int], sizes: Array[float]) -> Array:
	var order: Array[Vector2] = []
	for i in counts.size():
		if counts[i] > 0:
			order.append(Vector2(counts[i], i))
	order.sort()
	var q := maxi(order.size() / 4, 1)
	var quiet := 0.0
	var busy := 0.0
	var nq := 0
	var nb := 0
	for i in q:
		quiet += sizes[int(order[i].y)] * order[i].x
		nq += int(order[i].x)
		busy += sizes[int(order[order.size() - 1 - i].y)] * order[order.size() - 1 - i].x
		nb += int(order[order.size() - 1 - i].x)
	return [busy / maxf(nb, 1), quiet / maxf(nq, 1)]

func test_boulders_gather_in_clusters():
	var cases: Array = [
		["ROLLING", _rolling_t, _keys(_rolling_t, 3, 11, _any), _any],
		["talus", _desert_t, _keys(_desert_t, 3, 11, _talus), _talus],
	]
	for c: Array in cases:
		var t: WorldTerrain = c[1]
		var all_counts: Array[int] = []
		var all_sizes: Array[float] = []
		for key: Vector4i in c[2]:
			var p := _patch(t, key, c[3])
			all_counts.append_array(p[0])
			all_sizes.append_array(p[1])
		var s := _spread_of(all_counts)
		var by := _sizes_by_crowd(all_counts, all_sizes)
		gut.p("%s: %d chunks, %.2f stones a chunk, variance %.1f x the mean, %.0f%% empty; mean size %.2f m where busiest, %.2f m where quietest" % [
			c[0], all_counts.size(), s[0], s[1], float(s[2]) * 100.0, by[0], by[1]])
		assert_gt(all_counts.size(), 100, "%s: enough chunks to judge" % c[0])
		assert_gt(float(s[0]), 0.3, "%s: stones there at all" % c[0])
		assert_gt(float(s[1]), 1.5, "%s: gathered, not even (a random scatter's variance is its mean)" % c[0])
		assert_gt(float(s[2]), 0.25, "%s: bare ground between the clusters" % c[0])
		assert_gt(float(by[0]), float(by[1]) * 1.2, "%s: the big stones at the clusters' hearts" % c[0])

## The clusters are laid on the world, not rolled chunk by chunk: a cluster
## spans the line between two chunks, so side by side their stone counts go
## up and down together. A mask rolled per chunk would leave neighbours
## unrelated (correlation near 0) and a hard edge on every chunk's border.
## With two to four stones a chunk the counting alone is noisy (a random
## scatter's variance is its mean, half the variance here), so even a
## perfectly shared mask reads well under 1: rolled per chunk it read 0.04
## and 0.00, laid on the world 0.25 and 0.34.
func test_clusters_lie_across_chunk_edges():
	var cases: Array = [
		["ROLLING", _rolling_t, _keys(_rolling_t, 3, 11, _any), _any],
		["talus", _desert_t, _keys(_desert_t, 3, 11, _talus), _talus],
	]
	for c: Array in cases:
		var t: WorldTerrain = c[1]
		var xs: Array[float] = []
		var ys: Array[float] = []
		for key: Vector4i in c[2]:
			var cells := 1 << key.y
			var x0 := clampi(key.z - PATCH / 2, 0, cells - PATCH)
			var y0 := clampi(key.w - PATCH / 2, 0, cells - PATCH)
			var count := {}
			for j in PATCH:
				for i in PATCH:
					var k := Vector4i(key.x, key.y, x0 + i, y0 + j)
					if (c[3] as Callable).call(_mid(k)):
						count[Vector2i(i, j)] = GroundCover.scatter(t, k).boulders.size()
			for at: Vector2i in count:
				for next: Vector2i in [at + Vector2i(1, 0), at + Vector2i(0, 1)]:
					if count.has(next):
						xs.append(float(count[at]))
						ys.append(float(count[next]))
		var r := _correlation(xs, ys)
		gut.p("%s: %d neighbouring pairs, their stone counts correlate %.2f" % [c[0], xs.size(), r])
		assert_gt(xs.size(), 100, "%s: enough pairs to judge" % c[0])
		assert_gt(r, 0.2, "%s: neighbours share their clusters" % c[0])

static func _correlation(xs: Array[float], ys: Array[float]) -> float:
	var n := float(xs.size())
	var mx := 0.0
	var my := 0.0
	for i in xs.size():
		mx += xs[i]
		my += ys[i]
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in xs.size():
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	return sxy / sqrt(maxf(sxx * syy, 1e-9))

## Stamps (phase 3, Task 2): cover keeps off a stamp's flat part.

const STAMP_RADIUS := 120.0

## `p3` with a FLATTEN of STAMP_RADIUS on the middle of talus key `key`, and
## the same world without it: [stamped terrain, bare terrain, the stamp]. Both
## on today's ground, like `_desert_t`, where the talus is.
func _stamped(key: Vector4i) -> Array:
	var seed: int = _system.body(&"p3").seed
	var r := _todays(seed)
	var s := TerrainStamp.new()
	s.id = &"test_flat"
	s.kind = TerrainStamp.Kind.FLATTEN
	s.centre = _mid(key)
	s.radius = STAMP_RADIUS
	s.edge = 150.0
	r.stamps.append(s)
	return [WorldTerrain.new(r), WorldTerrain.new(_todays(seed)), s]

## The world of `seed` alone, on today's ground (no plan).
static func _todays(seed: int) -> WorldRecipe:
	var r := WorldRecipe.from_seed(seed)
	r.planned = false
	return r

## The finest keys within `reach` chunks of `key` on its face.
static func _round(key: Vector4i, reach: int) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	var cells := 1 << key.y
	for j in range(-reach, reach + 1):
		for i in range(-reach, reach + 1):
			var x := key.z + i
			var y := key.w + j
			if x >= 0 and y >= 0 and x < cells and y < cells:
				out.append(Vector4i(key.x, key.y, x, y))
	return out

static func _from_stamp(s: TerrainStamp, t: WorldTerrain, centre: Vector3i, p: Vector3) -> float:
	return s.metres_from((p + Vector3(centre)).normalized(), t.radius)

func test_no_cover_on_a_stamp():
	var seen := 0
	var would := 0
	# A talus chunk with stones in plenty round it, so the bare world has cover
	# inside the stamp to lose.
	for mid in _keys(_desert_t, 6, 21, _talus):
		var made := _stamped(mid)
		var t: WorldTerrain = made[0]
		var s: TerrainStamp = made[2]
		var limit := s.radius + TerrainStamp.CLEAR_MARGIN
		var reach := ceili(limit / CubeSphere.edge_m(t.radius, _finest(t))) + 1
		for key in _round(mid, reach):
			var centre := TerrainChunkData.centre_of(t, key)
			var bare := GroundCover.scatter(made[1], key)
			for b: Array in bare.boulders:
				if _from_stamp(s, t, centre, (b[0] as Transform3D).origin) < limit - 0.5:
					would += 1
			var cover := GroundCover.scatter(t, key)
			for b: Array in cover.boulders:
				assert_gte(_from_stamp(s, t, centre, (b[0] as Transform3D).origin), limit - 0.5, "a boulder on the stamp")
				seen += 1
			for g: Array in cover.grass:
				assert_gte(_from_stamp(s, t, centre, (g[0] as Transform3D).origin), limit - 0.5, "a tuft on the stamp")
				seen += 1
	gut.p("%d stones and tufts kept, %d boulders cleared" % [seen, would])
	assert_gt(would, 0, "the bare ground had cover there to clear")
	assert_gt(seen, 0, "and cover stays beyond")

func test_cover_beside_a_stamp_is_unchanged():
	var mid: Vector4i = _keys(_desert_t, 1, 22, _talus)[0]
	var made := _stamped(mid)
	var t: WorldTerrain = made[0]
	var s: TerrainStamp = made[2]
	var far := s.reach() + 50.0
	var stones := 0
	var tufts := 0
	for key in _keys(_desert_t, 60, 23, _talus):
		var beyond := true
		for c in [Vector2i(0, 0), Vector2i(N, 0), Vector2i(0, N), Vector2i(N, N)]:
			beyond = beyond and s.metres_from(TerrainChunkData.corner_dir(key, c.x, c.y), t.radius) > far
		if not beyond:
			continue
		var a := GroundCover.scatter(t, key)
		var b := GroundCover.scatter(made[1], key)
		assert_eq(a.boulders, b.boulders, "stone for stone at %s" % key)
		assert_eq(a.grass, b.grass, "tuft for tuft at %s" % key)
		stones += b.boulders.size()
		tufts += b.grass.size()
	assert_gt(stones, 0, "stones compared")
	assert_gt(tufts, 0, "tufts compared")

func test_a_cleared_chunk_is_solid_only_where_stones_are():
	var mid: Vector4i = _keys(_desert_t, 1, 24, _talus)[0]
	var made := _stamped(mid)
	var t: WorldTerrain = made[0]
	# Deep inside the flat part: every corner within the radius, no margin.
	var ground := N * N * 2 * 3
	var inside := 0
	for key in _round(mid, 2):
		var all := true
		for c in [Vector2i(0, 0), Vector2i(N, 0), Vector2i(0, N), Vector2i(N, N)]:
			all = all and (made[2] as TerrainStamp).metres_from(TerrainChunkData.corner_dir(key, c.x, c.y), t.radius) < STAMP_RADIUS
		if not all:
			continue
		inside += 1
		var c := TerrainChunkData.build(t, key)
		assert_eq(c.faces.size(), ground, "the ground's faces alone at %s" % key)
		# The bare world's same chunk may carry stones; the stamped one never.
		assert_true(GroundCover.scatter(t, key).boulders.is_empty(), "no stones inside the stamp")
	assert_gt(inside, 0, "chunks inside the stamp")
