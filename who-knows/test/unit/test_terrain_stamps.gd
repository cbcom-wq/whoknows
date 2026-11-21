extends GutTest

## Hand-made shapes in the ground (the desert world spec §8.1): a flattened
## disc and a basin, blended into height_at; a world with none is untouched.

## p3 from its seed alone, with the ground its oasis's stamps stand on: today's
## desert, which WADIS's kept disc keeps there (the wadis land spec §5.6), and
## which a recipe with no design keeps only with its plan off.
func _p3() -> WorldRecipe:
	var r := WorldRecipe.from_seed(SystemRecipe.from_seed(1337).body(&"p3").seed)
	r.planned = false
	return r

static func _dir(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if v.length() > 0.1 and v.length() <= 1.0:
			return v.normalized()
	return Vector3.UP

static func _flatten(id: StringName, centre: Vector3, radius: float, edge: float) -> TerrainStamp:
	var s := TerrainStamp.new()
	s.id = id
	s.kind = TerrainStamp.Kind.FLATTEN
	s.centre = centre.normalized()
	s.radius = radius
	s.edge = edge
	return s

static func _basin(id: StringName, centre: Vector3, rim: float, floor_r: float, depth: float) -> TerrainStamp:
	var s := TerrainStamp.new()
	s.id = id
	s.kind = TerrainStamp.Kind.BASIN
	s.centre = centre.normalized()
	s.radius = rim
	s.floor_radius = floor_r
	s.depth = depth
	return s

## The direction `m` metres from `centre` along bearing `turn` (radians).
static func _at(centre: Vector3, m: float, turn: float, world_radius: float) -> Vector3:
	var side := centre.cross(Vector3.UP if absf(centre.y) < 0.9 else Vector3.RIGHT).normalized()
	var other := centre.cross(side)
	var a := m / world_radius
	return (centre * cos(a) + (side * cos(turn) + other * sin(turn)) * sin(a)).normalized()

const HERE := Vector3(0.6, 0.3, -0.7)
## Over p3's oasis, where the dunes roll by metres.
const DUNES := Vector3(-0.9895, -0.0377, 0.1397)

func test_no_stamps_no_change():
	var seeds: Array[int] = []
	for archetype in 5:
		var k := 100
		while WorldRecipe.from_seed(k).archetype != archetype:
			k += 1
		seeds.append(k)
	for k in seeds:
		var r := WorldRecipe.from_seed(k)
		var t := WorldTerrain.new(r)
		var rng := RandomNumberGenerator.new()
		rng.seed = k
		for i in 500:
			var d := _dir(rng)
			assert_eq(t.height_at(d), t.base_height_at(d))
			assert_false(t.stamp_clear(d))
			assert_eq(t.ground_at(d, 0.1), WorldTerrain.new(r).ground_at(d, 0.1))

func test_a_flatten_is_flat():
	var r := _p3()
	var s := _flatten(&"floor", HERE, 120.0, 150.0)
	r.stamps.append(s)
	var t := WorldTerrain.new(r)
	var sum := 0.0
	var points := s.level_samples(r.radius_m)
	assert_eq(points.size(), 37)
	for p in points:
		sum += t.base_height_at(p)
	var level := sum / 37.0
	assert_almost_eq(t.height_at(s.centre), level, 0.001)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var d := _at(s.centre, 119.0 * sqrt(rng.randf()), rng.randf() * TAU, r.radius_m)
		assert_almost_eq(t.height_at(d), level, 0.01)
	# The terrain's level is its own: the recipe's stamp is as it was.
	assert_true(is_nan(s.level))
	for i in 200:
		var d := _at(s.centre, s.reach() + 1.0 + 500.0 * rng.randf(), rng.randf() * TAU, r.radius_m)
		assert_eq(t.height_at(d), t.base_height_at(d))

func test_a_flatten_blends_smoothly():
	var r := _p3()
	var s := _flatten(&"floor", HERE, 120.0, 150.0)
	r.stamps.append(s)
	var t := WorldTerrain.new(r)
	for ray in 5:
		var turn := TAU * ray / 5.0
		var m := 0.0
		var prev := t.height_at(_at(s.centre, m, turn, r.radius_m))
		while m < s.reach() + 20.0:
			m += 2.0
			var h := t.height_at(_at(s.centre, m, turn, r.radius_m))
			assert_lt(atan(absf(h - prev) / 2.0), WorldTerrain.ROCK_SLOPE - deg_to_rad(5.0), "ray %d at %.0f m" % [ray, m])
			prev = h

## `keep` lets a FLATTEN keep some of the land's roll: inside the flat part the
## height is level + keep * (ground before - level), and keep 0 is as it always was.
func test_keep_zero_is_unchanged():
	var r := _p3()
	var plain := _flatten(&"floor", HERE, 120.0, 150.0)
	r.stamps.append(plain)
	var kept := _p3()
	var zero := _flatten(&"floor", HERE, 120.0, 150.0)
	zero.keep = 0.0
	kept.stamps.append(zero)
	var a := WorldTerrain.new(r)
	var b := WorldTerrain.new(kept)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 200:
		var d := _at(HERE.normalized(), 300.0 * rng.randf(), rng.randf() * TAU, r.radius_m)
		assert_eq(b.height_at(d), a.height_at(d))
	assert_eq(zero.copy().keep, 0.0)

func test_keep_half_halves_the_roll_inside_the_flat_part():
	var r := _p3()
	var s := _flatten(&"floor", DUNES, 120.0, 150.0)
	s.keep = 0.5
	r.stamps.append(s)
	var t := WorldTerrain.new(r)
	var level := t.stamps[0].level
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var rolled := false
	var spread := 0.0
	for i in 200:
		var d := _at(s.centre, 119.0 * sqrt(rng.randf()), rng.randf() * TAU, r.radius_m)
		var ground := t.base_height_at(d)
		assert_almost_eq(t.height_at(d), level + 0.5 * (ground - level), 1e-9)
		rolled = rolled or absf(ground - level) > 0.2
		spread = maxf(spread, absf(ground - level))
	gut.p("land spread %.2f m" % spread)
	assert_true(rolled, "the land rolls by more than 0.2 m here")
	# Past the blend the land is untouched, and the blend runs from the kept surface.
	for i in 50:
		var d := _at(s.centre, s.reach() + 1.0 + 300.0 * rng.randf(), rng.randf() * TAU, r.radius_m)
		assert_eq(t.height_at(d), t.base_height_at(d))
	var edge := _at(s.centre, 135.0, 0.3, r.radius_m)
	var base := t.base_height_at(edge)
	var kept := level + 0.5 * (base - level)
	var w := s.weight(135.0)
	assert_almost_eq(t.height_at(edge), lerpf(base, kept, w), 1e-6)

func test_keep_counts_in_the_design_and_is_checked():
	var d := SystemDesign.new()
	d.seed = 4242
	d.bodies = {"x": {"stamps": [{"id": "s", "lat": 1.0, "lon": 1.0, "radius": 10.0, "keep": 0.4}]}}
	var out := d._stamps(&"x", 10000.0, PackedStringArray())
	assert_eq(out.size(), 1)
	assert_eq(out[0].keep, 0.4)

func test_a_raised_flatten_stands_proud():
	var r := _p3()
	r.stamps.append(_flatten(&"floor", HERE, 120.0, 150.0))
	var pad := _flatten(&"pad", HERE, 26.0, 4.0)
	pad.raise = 0.15
	pad.ground = &"pad"
	r.stamps.append(pad)
	var t := WorldTerrain.new(r)
	var floor_h := t.height_at(_at(pad.centre, 60.0, 0.0, r.radius_m))
	assert_almost_eq(t.height_at(pad.centre) - t.height_at(_at(pad.centre, 60.0, 1.0, r.radius_m)), 0.15, 0.001)
	assert_almost_eq(floor_h, t.height_at(_at(pad.centre, 80.0, 2.0, r.radius_m)), 0.01)

func test_a_basin_dips():
	var r := _p3()
	r.stamps.append(_flatten(&"floor", HERE, 120.0, 150.0))
	var basin := _basin(&"pool", HERE, 17.0, 9.0, 1.3)
	r.stamps.append(basin)
	var t := WorldTerrain.new(r)
	var floor_h := t.height_at(_at(HERE, 30.0, 0.3, r.radius_m))
	assert_almost_eq(t.height_at(basin.centre), floor_h - 1.3, 0.001)
	var mid := t.height_at(_at(basin.centre, 12.4, 0.9, r.radius_m))
	assert_between(floor_h - mid, 0.75, 0.85)
	for m in [17.0, 20.0, 40.0]:
		assert_almost_eq(t.height_at(_at(basin.centre, m, 2.2, r.radius_m)), floor_h, 0.001)

func test_stamp_ground():
	var r := _p3()
	r.stamps.append(_flatten(&"floor", HERE, 120.0, 150.0))
	var pad := _flatten(&"pad", _at(HERE.normalized(), 80.0, 0.0, r.radius_m), 26.0, 4.0)
	pad.ground = &"pad"
	r.stamps.append(pad)
	var basin := _basin(&"pool", HERE, 17.0, 9.0, 1.3)
	basin.ground = &"damp"
	r.stamps.append(basin)
	var t := WorldTerrain.new(r)
	assert_eq(t.ground_at(pad.centre, 0.05), &"pad")
	assert_eq(t.ground_at(_at(pad.centre, 20.0, 1.0, r.radius_m), 0.05), &"pad")
	assert_eq(t.ground_at(basin.centre, 0.05), &"damp")
	assert_eq(t.ground_at(_at(basin.centre, 16.0, 1.0, r.radius_m), 0.05), &"damp")
	assert_eq(t.ground_at(pad.centre, deg_to_rad(40.0)), &"rock")
	# Outside every stamp's flat part the desert answers as it always did.
	var far := _at(HERE.normalized(), 500.0, 0.0, r.radius_m)
	assert_eq(t.ground_at(far, 0.05), WorldTerrain.new(_p3()).ground_at(far, 0.05))

func test_stamp_clear():
	var r := _p3()
	var pad := _flatten(&"pad", HERE, 26.0, 4.0)
	r.stamps.append(pad)
	var basin := _basin(&"pool", _at(HERE.normalized(), 300.0, 0.0, r.radius_m), 17.0, 9.0, 1.3)
	r.stamps.append(basin)
	var t := WorldTerrain.new(r)
	assert_true(t.stamp_clear(_at(pad.centre, 26.0 + TerrainStamp.CLEAR_MARGIN - 0.2, 1.0, r.radius_m)))
	assert_false(t.stamp_clear(_at(pad.centre, 26.0 + TerrainStamp.CLEAR_MARGIN + 0.5, 1.0, r.radius_m)))
	assert_true(t.stamp_clear(_at(basin.centre, 17.0 + TerrainStamp.CLEAR_MARGIN - 0.2, 1.0, r.radius_m)))
	assert_false(t.stamp_clear(_at(basin.centre, 17.0 + TerrainStamp.CLEAR_MARGIN + 0.5, 1.0, r.radius_m)))
	assert_false(t.stamp_clear(_at(pad.centre, 150.0, 1.0, r.radius_m)))

func _heights(t: WorldTerrain, dirs: Array[Vector3]) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for d in dirs:
		out.append(t.height_at(d))
	return out

func test_level_is_the_same_on_every_thread():
	var r := _p3()
	r.stamps.append(_flatten(&"floor", HERE, 120.0, 150.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var dirs: Array[Vector3] = []
	for i in 40:
		dirs.append(_at(HERE.normalized(), 200.0 * rng.randf(), rng.randf() * TAU, r.radius_m))
	var here := WorldTerrain.new(r)
	var there := [PackedFloat64Array()]
	var task := WorkerThreadPool.add_task(func() -> void:
		there[0] = _heights(WorldTerrain.new(r), dirs))
	WorkerThreadPool.wait_for_task_completion(task)
	var mine := _heights(here, dirs)
	assert_eq(there[0].size(), 40)
	for i in 40:
		assert_eq(there[0][i], mine[i])
	assert_true(is_nan(r.stamps[0].level))

func test_the_desert_palette_has_pad_and_damp():
	var p: Dictionary = SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE]
	assert_eq(p[&"pad"], Color("a0642c"))
	assert_eq(p[&"damp"], Color("7a5a3c"))

static func _mesa(id: StringName, centre: Vector3, radius: float, edge: float, height: float) -> TerrainStamp:
	var s := TerrainStamp.new()
	s.id = id
	s.kind = TerrainStamp.Kind.MESA
	s.centre = centre.normalized()
	s.radius = radius
	s.edge = edge
	s.height = height
	return s

## A MESA (Rework 1, the ledge): a flat top `height` over the mean of the ground
## under it (37 samples, as a FLATTEN's level), out to `radius`, falling over
## `edge` to the ground beneath, steeply enough to be rock by the slope rule.
func test_a_mesa_raises_a_flat_top():
	var r := _p3()
	r.stamps.append(_flatten(&"floor", DUNES, 120.0, 150.0))
	var mesa := _mesa(&"ledge", _at(DUNES.normalized(), 80.0, 0.7, r.radius_m), 14.0, 5.5, 6.0)
	mesa.ground = &"ground_high"
	r.stamps.append(mesa)
	var t := WorldTerrain.new(r)
	var floor_only := _p3()
	floor_only.stamps.append(_flatten(&"floor", DUNES, 120.0, 150.0))
	var before := WorldTerrain.new(floor_only)
	var sum := 0.0
	for p in mesa.level_samples(r.radius_m):
		sum += before.height_at(p)
	var level := sum / 37.0
	assert_almost_eq(t.stamps[1].level, level, 1e-6, "the level is the mean of the ground under it")
	assert_true(is_nan(mesa.level), "the recipe's stamp is as it was")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 200:
		var d := _at(mesa.centre, 13.9 * sqrt(rng.randf()), rng.randf() * TAU, r.radius_m)
		assert_almost_eq(t.height_at(d), level + 6.0, 0.01, "on the top")
	for i in 200:
		var d := _at(mesa.centre, mesa.reach() + 0.05 + 30.0 * rng.randf(), rng.randf() * TAU, r.radius_m)
		assert_eq(t.height_at(d), before.height_at(d), "beyond its reach the ground is as it was")
	# Mid-edge, over the ground's own triangles' size (2 m), it is steeper than rock.
	for ray in 8:
		var turn := TAU * ray / 8.0
		var inner := _at(mesa.centre, mesa.radius + mesa.edge * 0.5 - 1.0, turn, r.radius_m)
		var outer := _at(mesa.centre, mesa.radius + mesa.edge * 0.5 + 1.0, turn, r.radius_m)
		var slope := atan(absf(t.height_at(inner) - t.height_at(outer)) / 2.0)
		assert_gt(slope, WorldTerrain.ROCK_SLOPE, "ray %d: %.1f deg mid-edge" % [ray, rad_to_deg(slope)])
		var mid := _at(mesa.centre, mesa.radius + mesa.edge * 0.5, turn, r.radius_m)
		assert_eq(t.ground_at(mid, slope), &"rock", "the edge is rock by the slope rule")
	assert_eq(t.ground_at(mesa.centre, 0.05), &"ground_high", "its top wears its ground")
	assert_true(t.stamp_clear(_at(mesa.centre, 10.0, 0.3, r.radius_m)), "no cover on its top")
	assert_eq(mesa.copy().height, 6.0)
	assert_eq(mesa.copy().kind, TerrainStamp.Kind.MESA)

## A world with no stamps is bit for bit what it was now MESA exists; and one
## with a MESA alone is too beyond its reach.
func test_no_stamps_is_unchanged_for_a_mesa():
	var r := _p3()
	var plain := WorldTerrain.new(r)
	var with_mesa := _p3()
	var mesa := _mesa(&"ledge", HERE, 14.0, 5.5, 6.0)
	with_mesa.stamps.append(mesa)
	var t := WorldTerrain.new(with_mesa)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in 300:
		var d := _dir(rng)
		assert_eq(plain.height_at(d), plain.base_height_at(d))
		assert_false(plain.stamp_clear(d))
		if mesa.metres_from(d, r.radius_m) > mesa.reach() + 0.01:
			assert_eq(t.height_at(d), plain.height_at(d))
			assert_eq(t.ground_at(d, 0.1), plain.ground_at(d, 0.1))
	for i in 100:
		var d := _at(mesa.centre, mesa.reach() + 0.05 + 200.0 * rng.randf(), rng.randf() * TAU, r.radius_m)
		assert_eq(t.height_at(d), plain.height_at(d))

## A point `along` m along `s`'s long axis and `across` m along its short one,
## from its centre (on the world's surface).
static func _on_axes(s: TerrainStamp, along: float, across: float, world_radius: float) -> Vector3:
	var long := (s.axis - s.centre * s.centre.dot(s.axis)).normalized()
	var short := s.centre.cross(long)
	var way := long * along + short * across
	var a := way.length() / world_radius
	if a == 0.0:
		return s.centre
	return (s.centre * cos(a) + way.normalized() * sin(a)).normalized()

## A long ledge (Rework 1, round 2): the MESA's top is an ellipse `stretch`
## times as long as it is wide, its long axis along `axis`, its edge wobbled
## in and out by at most `wobble` of it, the same every time. Inside the long
## axis the top is level; off the short sides, within the long axis's reach,
## the ground is as it was; and beyond its reach it is as it was bit for bit.
func test_a_long_mesa_is_an_ellipse():
	var r := _p3()
	r.stamps.append(_flatten(&"floor", DUNES, 120.0, 150.0))
	var mesa := _mesa(&"ledge", _at(DUNES.normalized(), 80.0, 0.7, r.radius_m), 20.0, 5.5, 6.0)
	mesa.stretch = 2.5
	mesa.wobble = 0.08
	var north := (Vector3.UP - mesa.centre * mesa.centre.y).normalized()
	mesa.axis = north.rotated(mesa.centre, -deg_to_rad(80.0))
	r.stamps.append(mesa)
	var t := WorldTerrain.new(r)
	var floor_only := _p3()
	floor_only.stamps.append(_flatten(&"floor", DUNES, 120.0, 150.0))
	var before := WorldTerrain.new(floor_only)
	assert_false(mesa.is_round())
	assert_almost_eq(mesa.reach(), 20.0 * 1.08 + 5.5, 1e-9, "its reach is the long axis's, wobbled out, and its edge")
	var top: float = t.stamps[1].level + 6.0
	var short := 20.0 / 2.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 300:
		# Inside the ellipse shrunk by the wobble's most.
		var turn := rng.randf() * TAU
		var k := sqrt(rng.randf()) * (1.0 - 0.08) - 0.01
		var d := _on_axes(mesa, 20.0 * k * cos(turn), short * k * sin(turn), r.radius_m)
		assert_almost_eq(t.height_at(d), top, 0.01, "on the top")
	for along in [-19.0, -10.0, 0.0, 10.0, 18.0]:
		assert_almost_eq(t.height_at(_on_axes(mesa, along, 0.0, r.radius_m)), top, 0.01, "level along the long axis at %.0f" % along)
	for side in [-1.0, 1.0]:
		var off := _on_axes(mesa, 0.0, side * (short * 1.08 + 5.5 + 0.3), r.radius_m)
		assert_lt(mesa.metres_from(off, r.radius_m), mesa.reach(), "inside the long axis's reach")
		assert_eq(t.height_at(off), before.height_at(off), "off its short side the ground is as it was")
		assert_false(t.ground_at(off, 0.05) == &"ground_high", "and wears the land's own ground")
	for i in 200:
		var d := _at(mesa.centre, mesa.reach() + 0.05 + 30.0 * rng.randf(), rng.randf() * TAU, r.radius_m)
		assert_eq(t.height_at(d), before.height_at(d), "beyond its reach the ground is as it was")
	# The wobble moves the edge, at most `wobble` of the ellipse either way.
	var least := INF
	var most := 0.0
	for k in 72:
		var turn := TAU * k / 72.0
		var way := _on_axes(mesa, cos(turn), sin(turn), r.radius_m)
		var ellipse := 20.0 * short / sqrt(pow(short * cos(turn), 2.0) + pow(20.0 * sin(turn), 2.0))
		var share := mesa.flat_radius(way) / ellipse - 1.0
		least = minf(least, share)
		most = maxf(most, share)
	assert_between(most, 0.02, 0.0801, "out by up to the wobble")
	assert_between(least, -0.0801, -0.02, "and in")
	# The same every time, and a copy keeps it.
	var again := WorldTerrain.new(r)
	for i in 50:
		var d := _at(mesa.centre, 30.0 * rng.randf(), rng.randf() * TAU, r.radius_m)
		assert_eq(again.height_at(d), t.height_at(d))
	var c := mesa.copy()
	assert_eq([c.stretch, c.wobble, c.axis, c.heading], [mesa.stretch, mesa.wobble, mesa.axis, mesa.heading])
	assert_eq(c.flat_radius(mesa.centre.rotated(Vector3.UP, 0.001)), mesa.flat_radius(mesa.centre.rotated(Vector3.UP, 0.001)))
	# The edge is still steeper than rock across the short side.
	for side in [-1.0, 1.0]:
		var lip := mesa.flat_radius(_on_axes(mesa, 0.0, side, r.radius_m))
		var inner := _on_axes(mesa, 0.0, side * (lip + 2.75 - 1.0), r.radius_m)
		var outer := _on_axes(mesa, 0.0, side * (lip + 2.75 + 1.0), r.radius_m)
		var slope := atan(absf(t.height_at(inner) - t.height_at(outer)) / 2.0)
		assert_gt(slope, WorldTerrain.ROCK_SLOPE, "mid-edge off the short side: %.1f deg" % rad_to_deg(slope))
