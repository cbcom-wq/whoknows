extends GutTest

## A world's ground (the world scale spec §4): the same for the same recipe,
## within its relief, altitude agreeing with height, and every colour from its
## palette.

func _recipe(seed: int, archetype := -1) -> WorldRecipe:
	var k := seed
	while true:
		var r := WorldRecipe.from_seed(k)
		if archetype < 0 or r.archetype == archetype:
			return r
		k += 1
	return null

static func _dir(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if v.length() > 0.1 and v.length() <= 1.0:
			return v.normalized()
	return Vector3.UP

func test_the_same_recipe_gives_the_same_ground():
	var r := _recipe(1337)
	var a := WorldTerrain.new(r)
	var b := WorldTerrain.new(r)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 50:
		var d := _dir(rng)
		assert_eq(a.height_at(d), b.height_at(d))
		assert_eq(a.colour_at(d, 0.1, 50.0), b.colour_at(d, 0.1, 50.0))

func test_heights_stay_within_the_relief_and_vary():
	for seed in [11, 12, 13, 14]:
		var t := WorldTerrain.new(_recipe(seed))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var lo := INF
		var hi := -INF
		for i in 1500:
			var h := t.height_at(_dir(rng))
			lo = minf(lo, h)
			hi = maxf(hi, h)
		assert_gte(lo, -t.relief * 0.5 - 0.001)
		assert_lte(hi, t.relief * 0.5 + 0.001)
		assert_gt(hi - lo, t.relief * 0.25, "seed %d: a world, not a ball" % seed)

func test_altitude_agrees_with_height():
	var t := WorldTerrain.new(_recipe(21))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 50:
		var d := _dir(rng)
		var p := d * (t.radius + t.height_at(d) + 25.0)
		assert_almost_eq(t.altitude_of(p), 25.0, 0.05)

func test_every_colour_comes_from_the_palette():
	var r := _recipe(31)
	var t := WorldTerrain.new(r)
	var palette: Dictionary = SpacePalette.WORLDS[r.palette]
	var allowed: Array[Color] = []
	for key in [&"ground_low", &"ground_high", &"rock", &"dust"]:
		for k in SpacePalette.SHADES.size():
			allowed.append(SpacePalette.shade(palette[key], k))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 200:
		var c := t.colour_at(_dir(rng), rng.randf_range(0.0, 1.2), rng.randf_range(10.0, 50000.0))
		assert_true(allowed.has(c), "a colour from outside the palette: %s" % c)

func test_steep_ground_is_bare_rock():
	var t := WorldTerrain.new(_recipe(41))
	assert_eq(t.ground_at(Vector3.UP, deg_to_rad(50.0)), &"rock")

func test_a_crater_seen_from_afar_is_a_real_bowl():
	var t := WorldTerrain.new(_recipe(51, WorldRecipe.Archetype.CRATERED))
	assert_gt(t.craters.size(), 0)
	var c: Array = t.craters[0]
	var centre: Vector3 = c[0]
	var size: float = c[1]
	var side := centre.cross(Vector3.UP if absf(centre.y) < 0.9 else Vector3.RIGHT).normalized()
	var rim := centre.rotated(side, size * (WorldTerrain.CRATER_FLOOR + 1.0) * 0.5)
	assert_lt(t.height_at(centre), t.height_at(rim), "the floor is below the rim")
	assert_eq(t.ground_at(centre, 0.0), &"rock", "and painted as the far pattern paints it")

func test_shades_come_in_patches_a_few_triangles_across():
	# Style guide §3.5: broad patches, never triangle by triangle. Walk a great
	# circle one triangle at a time; most steps keep the shade they had.
	var patch_m := 60.0
	for seed in [61, 62, 63]:
		var t := WorldTerrain.new(_recipe(seed))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var d := _dir(rng)
		var axis := d.cross(_dir(rng)).normalized()
		var step := (patch_m / WorldTerrain.PATCH_QUADS) / t.radius
		var same := 0
		var prev := t.colour_at(d, 0.0, patch_m)
		for i in 400:
			d = d.rotated(axis, step)
			var c := t.colour_at(d, 0.0, patch_m)
			if c == prev:
				same += 1
			prev = c
		var fraction := float(same) / 400.0
		gut.p("seed %d: %.3f of steps keep their colour" % [seed, fraction])
		assert_gt(fraction, 0.6, "seed %d: shades by the triangle, not in patches" % seed)

# The desert (the desert world spec §7.2): long dunes running one way and
# turning across the world, flat mesas with rock risers, rock towers where the
# terraces break up.

func _desert(seed := 1) -> WorldTerrain:
	return WorldTerrain.new(_recipe(seed, WorldRecipe.Archetype.DUNES))

## An open point on a desert's dunes: sand, off the talus, below where the
## dunes start to fade toward a mesa, and clear of the wind axis's poles.
static func _open_dune(t: WorldTerrain, rng: RandomNumberGenerator) -> Vector3:
	while true:
		var d := _dir(rng)
		if t.ground_at(d, 0.0) == &"ground_low" and not t.in_talus(d) \
				and t.continent_at(d) < WorldTerrain.MESA_FROM - WorldTerrain.MESA_EDGE \
				and absf(d.dot(t.wind_axis)) < WorldTerrain.DUNE_POLE:
			return d
	return Vector3.UP

## `d` moved `metres` along the great circle toward the tangent `toward`.
static func _walk(t: WorldTerrain, d: Vector3, toward: Vector3, metres: float) -> Vector3:
	return d.rotated(d.cross(toward).normalized(), metres / t.radius)

## Heights every 2 m along `toward` from `d`, over `metres`.
static func _profile(t: WorldTerrain, d: Vector3, toward: Vector3, metres: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in int(metres / 2.0) + 1:
		out.append(t.height_at(_walk(t, d, toward, i * 2.0)))
	return out

static func _spread(heights: PackedFloat64Array) -> float:
	var lo := INF
	var hi := -INF
	for h in heights:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return hi - lo

func test_dunes_stay_within_the_relief():
	for seed in [1, 200]:
		var t := _desert(seed)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var lo := INF
		var hi := -INF
		for i in 2000:
			var h := t.height_at(_dir(rng))
			lo = minf(lo, h)
			hi = maxf(hi, h)
		assert_gte(lo, -t.relief * 0.5, "seed %d" % seed)
		assert_lte(hi, t.relief * 0.5, "seed %d" % seed)

func test_the_windward_side_is_gentler_than_the_lee():
	for seed in [1, 200, 400]:
		var t := _desert(seed)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var d := _open_dune(t, rng)
		var heights := _profile(t, d, t.wind_at(d), WorldTerrain.DUNE_WAVE * 3.0)
		var rise := 0.0
		var rises := 0
		var fall := 0.0
		var falls := 0
		var steepest := 0.0
		for i in range(1, heights.size()):
			var s := (heights[i] - heights[i - 1]) / 2.0
			if s > 0.0:
				rise += s
				rises += 1
			elif s < 0.0:
				fall -= s
				falls += 1
				steepest = maxf(steepest, -s)
		rise /= maxf(rises, 1)
		fall /= maxf(falls, 1)
		gut.p("seed %d: windward %.1f°, lee %.1f°, steepest %.1f°" % [seed,
			rad_to_deg(atan(rise)), rad_to_deg(atan(fall)), rad_to_deg(atan(steepest))])
		assert_lt(rise, fall * 0.5, "seed %d: a soft windward side, a steeper lee" % seed)
		assert_lt(atan(steepest), WorldTerrain.ROCK_SLOPE, "seed %d: the lee is sand, not rock" % seed)

func test_ridges_run_across_the_wind():
	for seed in [1, 200, 400]:
		var t := _desert(seed)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var d := _open_dune(t, rng)
		var w := t.wind_at(d)
		var along := _spread(_profile(t, d, w, 200.0))
		var across := _spread(_profile(t, d, d.cross(w), 200.0))
		gut.p("seed %d: %.1f m along the wind, %.1f m across" % [seed, along, across])
		assert_gt(along, across * 4.0, "seed %d: ridges across the wind" % seed)

func test_the_wind_turns_across_the_world():
	var t := _desert()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var points: Array[Vector3] = []
	while points.size() < 50:
		var d := _open_dune(t, rng)
		if points.all(func(p: Vector3) -> bool: return p.angle_to(d) * t.radius >= 2000.0):
			points.append(d)
	var lo := INF
	var hi := -INF
	for d in points:
		var w := t.wind_at(d)
		assert_almost_eq(w.length(), 1.0, 1e-4)
		assert_almost_eq(w.dot(d), 0.0, 1e-4, "tangent to the ground")
		# Against the plain lines of d . axis: the warp's turn alone.
		var plain := (t.wind_axis - d * d.dot(t.wind_axis)).normalized()
		var angle := atan2(plain.cross(w).dot(d), plain.dot(w))
		lo = minf(lo, angle)
		hi = maxf(hi, angle)
	gut.p("the wind's turn: %.1f° to %.1f°" % [rad_to_deg(lo), rad_to_deg(hi)])
	assert_gt(hi - lo, deg_to_rad(20.0), "the ridges turn across the world")

func test_crests_are_as_far_apart_near_the_poles_as_at_the_equator():
	# Twenty waves along the wind, centred on an open point: twenty crests,
	# give or take the warp's few, near the axis's equator and near where the
	# dunes start to fade toward a pole.
	var t := _desert()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var length := WorldTerrain.DUNE_WAVE * 20.0
	for band in [Vector2(0.0, 0.3), Vector2(0.8, 0.86)]:
		var d := _open_dune(t, rng)
		while absf(d.dot(t.wind_axis)) < band.x or absf(d.dot(t.wind_axis)) > band.y:
			d = _open_dune(t, rng)
		var w := t.wind_at(d)
		var heights := _profile(t, _walk(t, d, w, -length * 0.5), w, length)
		var crests := 0
		for i in range(1, heights.size() - 1):
			if heights[i] > heights[i - 1] and heights[i] >= heights[i + 1]:
				crests += 1
		gut.p("|d . axis| %.2f: %d crests in %.1f km" % [absf(d.dot(t.wind_axis)), crests, length / 1000.0])
		assert_between(crests, 15, 25, "crests DUNE_WAVE apart at |d . axis| %.2f" % absf(d.dot(t.wind_axis)))

func test_only_a_desert_has_wind_and_talus():
	var t := WorldTerrain.new(_recipe(105, WorldRecipe.Archetype.MESA))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for i in 50:
		var d := _dir(rng)
		assert_eq(t.wind_at(d), Vector3.ZERO)
		assert_false(t.in_talus(d))

func test_mesas_are_flat_steps_with_rock_risers():
	var t := _desert()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var high := WorldTerrain.MESA_FROM + 0.05
	var centre := _dir(rng)
	while t.continent_at(centre) < high:
		centre = _dir(rng)
	var side := centre.cross(_dir(rng)).normalized()
	var samples: Array[Vector3] = []
	while samples.size() < 400:
		var d := _walk(t, centre, side.rotated(centre, rng.randf() * TAU), sqrt(rng.randf()) * 600.0)
		if t.continent_at(d) >= high:
			samples.append(d)
	# Group the heights to within 2 m: the TERRACES + 1 biggest groups hold
	# most of them.
	var heights: Array[float] = []
	for d in samples:
		heights.append(t.height_at(d))
	heights.sort()
	var groups: Array[int] = [0]
	var start := heights[0]
	for h in heights:
		if h - start > 2.0:
			groups.append(0)
			start = h
		groups[-1] += 1
	groups.sort()
	groups.reverse()
	var flat := 0
	for i in mini(WorldTerrain.TERRACES + 1, groups.size()):
		flat += groups[i]
	gut.p("%d groups; the biggest %s" % [groups.size(), groups.slice(0, WorldTerrain.TERRACES + 1)])
	assert_gte(flat, 320, "flat steps")
	var tops := 0
	for d in samples.slice(0, 60):
		# Level both ways for 2 m: a terrace's top, not its riser.
		var h := t.height_at(d)
		if absf(t.height_at(_walk(t, d, side, 2.0)) - h) < 0.01 \
				and absf(t.height_at(_walk(t, d, side.rotated(d, PI * 0.5), 2.0)) - h) < 0.01:
			assert_eq(t.ground_at(d, 0.0), &"ground_high", "a mesa's top")
			tops += 1
	assert_gt(tops, 30, "most of a mesa is its tops")
	# Walk out from the centre until a riser turns up, steeper than rock; at
	# its steepest it is rock by rule, whatever the slope it is asked with.
	var riser := false
	for k in 16:
		var toward := side.rotated(centre, k * TAU / 16.0)
		for i in 1000:
			var a := _walk(t, centre, toward, i * 2.0)
			if t.continent_at(a) < WorldTerrain.MESA_FROM:
				break
			var b := _walk(t, centre, toward, i * 2.0 + 2.0)
			if atan(absf(t.height_at(b) - t.height_at(a)) / 2.0) > WorldTerrain.ROCK_SLOPE:
				var steepest := a
				var rise := 0.0
				for j in 8:
					var p := _walk(t, a, toward, j * 0.25)
					var q := _walk(t, a, toward, j * 0.25 + 0.25)
					var s := absf(t.height_at(q) - t.height_at(p))
					if s > rise:
						rise = s
						steepest = (p + q).normalized()
				assert_eq(t.ground_at(steepest, 0.0), &"rock", "a riser is rock")
				riser = true
				break
		if riser:
			break
	assert_true(riser, "risers between the steps")

func test_towers_stand_in_the_band_and_nowhere_else():
	var t := _desert()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var floor := WorldTerrain.MESA_FROM - WorldTerrain.TOWER_BAND
	var inside := 0
	var outside := 0
	var lines := 0
	while lines < 12:
		# A line 6 km long through a point in the band.
		var mid := _dir(rng)
		var z := t.continent_at(mid)
		if z < floor or z >= WorldTerrain.MESA_FROM:
			continue
		lines += 1
		var toward := mid.cross(_dir(rng)).normalized()
		var start := _walk(t, mid, toward, -3000.0)
		var a := start
		var ha := t.height_at(a)
		for i in 3000:
			var b := _walk(t, start, toward, i * 2.0 + 2.0)
			var hb := t.height_at(b)
			if absf(hb - ha) > 10.0:
				var za := t.continent_at(a)
				var zb := t.continent_at(b)
				if minf(za, zb) >= floor and maxf(za, zb) < WorldTerrain.MESA_FROM:
					inside += 1
				elif maxf(za, zb) < floor:
					outside += 1
			a = b
			ha = hb
	gut.p("cliffs: %d in the band, %d below it" % [inside, outside])
	assert_gt(inside, 0, "towers in the band")
	assert_eq(outside, 0, "and none on the open dunes")

func test_no_tower_is_cut():
	# Round each tower top, half of them found on cube faces' edges, the
	# ground falls away on every side down a flank (TOWER_FOOT), never by a
	# cliff where a neighbouring cell or a face's edge slices it.
	var t := _desert()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var floor := WorldTerrain.MESA_FROM - WorldTerrain.TOWER_BAND
	var tops: Array[Vector3] = []
	var on_edges := 0
	var tries := 0
	while tops.size() < 30 and tries < 6000:
		tries += 1
		var edge := tries % 2 == 0
		var p := _dir(rng)
		if edge:
			# 40 to 100 m in from an edge, so the search reaches the towers
			# nearest it.
			p = _by_face_edge(t, p, rng.randf_range(40.0, 100.0))
		var z := t.continent_at(p)
		if z < floor or z >= WorldTerrain.MESA_FROM:
			continue
		var top := _tower_top_near(t, p)
		if top != Vector3.ZERO:
			tops.append(top)
			on_edges += 1 if edge else 0
	gut.p("%d tower tops, %d within 140 m of a face's edge" % [tops.size(), on_edges])
	assert_gte(tops.size(), 20, "towers to look round")
	assert_gte(on_edges, 5, "towers by the faces' edges among them")
	var cut := 0
	for top in tops:
		var side := top.cross(Vector3.UP if absf(top.y) < 0.9 else Vector3.RIGHT).normalized()
		for k in 16:
			var heights := _profile_fine(t, top, side.rotated(top, k * TAU / 16.0), 60.0)
			var fall := heights[0]
			var drop := 0.0
			for i in range(1, heights.size()):
				fall = minf(fall, heights[i])
				drop = maxf(drop, heights[i - 1] - heights[i])
			fall = heights[0] - fall
			if fall > 5.0 and drop > fall * 0.35:
				cut += 1
	assert_eq(cut, 0, "every tower's flank all the way round")

## Heights every 0.25 m along `toward` from `d`, over `metres`.
static func _profile_fine(t: WorldTerrain, d: Vector3, toward: Vector3, metres: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in int(metres / 0.25) + 1:
		out.append(t.height_at(_walk(t, d, toward, i * 0.25)))
	return out

## A point `metres` in from the cube face edge nearest `d`, on `d`'s face.
static func _by_face_edge(t: WorldTerrain, d: Vector3, metres: float) -> Vector3:
	var a := d.abs()
	var big := a.max_axis_index()
	var second := (big + 1) % 3 if a[(big + 1) % 3] >= a[(big + 2) % 3] else (big + 2) % 3
	var on := d
	on[second] = signf(d[second]) * a[big]
	on = on.normalized()
	var axis := Vector3.ZERO
	axis[big] = signf(d[big])
	return _walk(t, on, (axis - on * on.dot(axis)).normalized(), metres)

## The top of a tower within 40 m of `p`, or ZERO: a point of rock on level
## ground below the mesa line (only a tower is that), climbed to its highest.
static func _tower_top_near(t: WorldTerrain, p: Vector3) -> Vector3:
	var e1 := p.cross(Vector3.UP if absf(p.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := p.cross(e1)
	for j in 21:
		for i in 21:
			var d := (p * t.radius + e1 * (i * 4.0 - 40.0) + e2 * (j * 4.0 - 40.0)).normalized()
			if t.ground_at(d, 0.0) != &"rock" or t.continent_at(d) >= WorldTerrain.MESA_FROM:
				continue
			# Climb to the highest ground near it, 1 m at a time.
			var h := t.height_at(d)
			var climbing := true
			while climbing:
				climbing = false
				for k in 8:
					var q := _walk(t, d, e1.rotated(d, k * TAU / 8.0), 1.0)
					var hq := t.height_at(q)
					if hq > h + 0.001:
						d = q
						h = hq
						climbing = true
						break
			return d
	return Vector3.ZERO

func test_dunes_change_little_between_details():
	var t := _desert()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := CubeSphere.QUADS
	var key := CubeSphere.key_for(_open_dune(t, rng), CubeSphere.depth_for(t.radius) - 3)
	var coarse := TerrainChunkData.build(t, key)
	var centre := Vector3(coarse.centre)
	var rect := CubeSphere.node_rect(key)
	# The finest grid is 8 x 8 times finer.
	var fine_step := rect.z / n / 8.0
	var close := 0
	var worst := 0.0
	for k in 200:
		var u := rng.randf() * n
		var v := rng.randf() * n
		var i := mini(floori(u), n - 1)
		var j := mini(floori(v), n - 1)
		var near := _on_quad(t, PackedVector3Array([
			coarse.grid[j * (n + 1) + i] + centre, coarse.grid[j * (n + 1) + i + 1] + centre,
			coarse.grid[(j + 1) * (n + 1) + i] + centre, coarse.grid[(j + 1) * (n + 1) + i + 1] + centre]),
			u - i, v - j)
		var fu := u * 8.0
		var fv := v * 8.0
		var i0 := floorf(fu)
		var j0 := floorf(fv)
		var corners := PackedVector3Array()
		for c in 4:
			var d := CubeSphere.direction(key.x, rect.x + (i0 + (c & 1)) * fine_step, rect.y + (j0 + (c >> 1)) * fine_step)
			corners.append(d * (t.radius + t.height_at(d)))
		var off := absf(near - _on_quad(t, corners, fu - i0, fv - j0))
		worst = maxf(worst, off)
		if off < 2.0:
			close += 1
	gut.p("%d of 200 within 2 m; the worst %.1f m" % [close, worst])
	assert_gte(close, 180, "the coarse ground is the fine ground, smoothed")

## The ground's height over radius at (fu, fv) within a quad of corners 00,
## 10, 01, 11, on its two triangles split along 00-11 as TerrainChunkData
## draws them.
static func _on_quad(t: WorldTerrain, corners: PackedVector3Array, fu: float, fv: float) -> float:
	var p: Vector3
	if fu >= fv:
		p = corners[0] + (corners[1] - corners[0]) * fu + (corners[3] - corners[1]) * fv
	else:
		p = corners[0] + (corners[2] - corners[0]) * fv + (corners[3] - corners[2]) * fu
	return p.length() - t.radius

func test_a_desert_looks_sandy_from_afar():
	for seed in [1, 200]:
		# A body of its own, not one from a SystemRecipe: reaching a recipe's
		# bodies from this script has Godot report leaked resources at exit.
		var body := SystemBody.new()
		body.recipe = _recipe(seed, WorldRecipe.Archetype.DUNES)
		var palette: Dictionary = SpacePalette.WORLDS[body.recipe.palette]
		var sandy: Array[Color] = []
		for key in [&"ground_low", &"dust"]:
			for k in SpacePalette.SHADES.size():
				sandy.append(SpacePalette.shade(palette[key], k))
		var colours: PackedColorArray = BodyLook.mesh(body, BodyLook.FAR_DETAIL).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var count := 0
		for i in range(0, colours.size(), 3):
			var c := colours[i]
			for a in sandy:
				# Vertex colours are kept to 8 bits a channel.
				if absf(a.r - c.r) < 0.004 and absf(a.g - c.g) < 0.004 and absf(a.b - c.b) < 0.004:
					count += 1
					break
		var share := float(count) / (colours.size() / 3.0)
		gut.p("seed %d: %.2f of the far faces are sand or dust" % [seed, share])
		assert_gte(share, 0.6, "seed %d: a desert from orbit" % seed)

## Pinned from main (3af7971) before the desert came, by a throwaway script
## drawing exactly as below: per seed, its archetype, then the sha256 of the
## 200 heights (64-bit floats) and of the 200 colours (PackedColorArray bytes).
const MAIN_GROUND := [
	[104, WorldRecipe.Archetype.CRATERED,
		"06e87bf9fb2d7c4e5a2f777863c4f27c84483373d435d8f7cc5c12fa39f1c7d2",
		"cecb405ce942887be2954593350b3903709da43ebfe20cf8d9d39b2867a8d8cd"],
	[103, WorldRecipe.Archetype.ROLLING,
		"9201007070ad2ded53c04525259896e38987dc15cfbedc324079f885f418a6ba",
		"a93f9d4a8af2b68ef5b386a1b0b39bf380d39c2716db42858f573ca0342afc56"],
	[100, WorldRecipe.Archetype.RIDGED,
		"eae2beb51f55f18ca9ba527db0199c7b15b7c8d9b951bc5ae13bc46160e84218",
		"d30ea784ed458d5b6714d7fa1d8d852194ecb76e08aab3c0fc1fc1eea2c207c1"],
	[105, WorldRecipe.Archetype.MESA,
		"ea63335fe281a44b145de267df0e911538b91eb2cdb9ad7663113f74a6809fa3",
		"92147fc6777334bcfe948989bd7e2cefb985414074fd508bacdcdbd18bd3e0cd"],
]

func test_other_worlds_are_untouched():
	for row: Array in MAIN_GROUND:
		var seed: int = row[0]
		var r := WorldRecipe.from_seed(seed)
		assert_eq(r.archetype, row[1], "seed %d keeps its archetype" % seed)
		var t := WorldTerrain.new(r)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var heights := PackedFloat64Array()
		var colours := PackedColorArray()
		for i in 200:
			var d := _dir(rng)
			heights.append(t.height_at(d))
			colours.append(t.colour_at(d, rng.randf_range(0.0, 1.2), rng.randf_range(10.0, 50000.0)))
		assert_eq(heights.to_byte_array().hex_encode().sha256_text(), row[2], "seed %d: main's heights" % seed)
		assert_eq(colours.to_byte_array().hex_encode().sha256_text(), row[3], "seed %d: main's colours" % seed)
