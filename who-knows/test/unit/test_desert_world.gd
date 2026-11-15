extends GutTest

## The desert world's oasis ground (desert world spec §8; phase 3 plan, Task 4):
## p3 of seed 1337 with its floor, its landing pad and its pool, made by the
## design's data alone, and the rest of the world as the seed rolls it.

const SEED := 1337
## How far the sun may stand from 30 degrees over the oasis (degrees).
const SUN_SLACK := 5.0
## The pad is this far above the floor (m), within PAD_SLACK.
const PAD_RAISE := 0.15
const PAD_SLACK := 0.005
## How flat flat is (m).
const FLAT := 0.02
## The water stands this far under the floor (m).
const WATER_BELOW := 0.3
## The floor between 30 and 115 m rolls by at least this standard deviation (m), and
## no 2 m step on it is steeper than MAX_FLOOR_SLOPE_DEG.
const MIN_ROLL := 0.5
const MAX_FLOOR_SLOPE_DEG := 15.0
## A ship's pad margin beyond its half-diagonal (m).
const PAD_MARGIN := 5.0

var _system: SystemRecipe
var _planet: SystemBody
var _terrain: WorldTerrain
var _place: PlaceDesign

func before_all() -> void:
	RockMesh.warm()
	GroundCover.grass_mesh()
	_system = SystemRecipe.from_seed(SEED)
	_planet = _system.body(&"p3")
	_terrain = WorldTerrain.new(_planet.recipe)
	for p in _system.places():
		if p.id == &"oasis":
			_place = p

func after_all() -> void:
	_system = null

func _stamp(id: StringName) -> TerrainStamp:
	for s in _terrain.stamps:
		if s.id == id:
			return s
	return null

## The direction `metres` from `centre` along `bearing` (radians) on p3.
func _toward(centre: Vector3, bearing: float, metres: float) -> Vector3:
	var side := centre.cross(Vector3.UP if absf(centre.y) < 0.9 else Vector3.RIGHT).normalized()
	var other := centre.cross(side)
	var angle := metres / _terrain.radius
	return (centre * cos(angle) + (side * cos(bearing) + other * sin(bearing)) * sin(angle)).normalized()

func _disc_sample(centre: Vector3, rng: RandomNumberGenerator, inner: float, outer: float) -> Vector3:
	var metres := sqrt(rng.randf_range(inner * inner, outer * outer))
	return _toward(centre, rng.randf() * TAU, metres)

func test_the_desert_world_is_p3() -> void:
	var r := _planet.recipe
	assert_true(r.is_desert(), "a desert")
	assert_eq(r.atmosphere, WorldRecipe.Atmosphere.THICK, "thick air")
	assert_almost_eq(r.surface_gravity, 5.28, 0.01, "gravity")
	assert_eq(r.name, "WADIS", "the owner named it")
	for m in _system.moons_of(_planet):
		assert_true(m.name.begins_with("WADIS "), m.name)

func test_the_oasis_is_placed() -> void:
	assert_not_null(_place, "p3 has the place oasis")
	if _place == null:
		return
	assert_eq(_place.name, "OASIS")
	assert_true(_place.beacon)
	assert_eq(_place.heading, 0.0)
	# Rework 1, round 2: the floor, the pool's bank, the pad, the pool, the
	# ledge, one under each of the five compounds and one under each of the three
	# gardens; Rework 2: and the pool's level shore.
	assert_eq(_terrain.stamps.size(), 14, "fourteen stamps")
	var ids: Array[StringName] = [&"oasis_floor", &"pool_bank", &"pad", &"pool_shore", &"pool", &"ledge"]
	var layout := _place.layout()
	for s: Dictionary in layout.get("shells", []):
		var court := StringName(s["stamp"])
		if not ids.has(court):
			ids.append(court)
	for g: Dictionary in layout.get("gardens", []):
		ids.append(StringName(g["id"]))
	assert_eq(ids.size(), 14, "five compounds and three gardens in the layout")
	for id in ids:
		assert_not_null(_stamp(id), str(id))
	assert_eq(_system.design.problems(_system), PackedStringArray(), "the design is valid")

## Rework 1: every pair of stamps nests or keeps apart (the design's problems
## check) with at least MARGIN to spare.
const MARGIN := 0.3

func test_every_stamp_keeps_a_margin() -> void:
	var worst := INF
	var where := ""
	for i in _terrain.stamps.size():
		for j in range(i + 1, _terrain.stamps.size()):
			var a := _terrain.stamps[i]
			var b := _terrain.stamps[j]
			var m := SystemDesign.stamp_margin(a, b, _terrain.radius)
			assert_gte(m, MARGIN, "%s and %s" % [a.id, b.id])
			if a.id in [&"pool_bank", &"pool_shore"] or b.id in [&"pool_bank", &"pool_shore"]:
				gut.p("  %s and %s: %.2f m" % [a.id, b.id, m])
			if m < worst:
				worst = m
				where = "%s and %s" % [a.id, b.id]
	gut.p("the tightest stamps: %s, %.2f m to spare" % [where, worst])

## Rework 1: the outcrop is replaced by a low sandstone ledge, a MESA north of
## the village outside its wall, nested in the floor's flat part. Round 2: a
## long shelf, not a plug: about 40 x 16 m, its edge wobbled.
func test_the_ledge_stands_north_outside_the_wall() -> void:
	var ledge := _stamp(&"ledge")
	var floor_stamp := _stamp(&"oasis_floor")
	if ledge == null or floor_stamp == null or _place == null:
		fail_test("the ledge is not there")
		return
	assert_eq(ledge.kind, TerrainStamp.Kind.MESA, "a mesa")
	assert_between(ledge.height, 5.0, 7.0, "about 6 m up")
	assert_between(ledge.radius, 18.0, 22.0, "about 40 m long")
	assert_between(ledge.radius / ledge.stretch, 7.0, 9.0, "about 16 m deep")
	assert_between(ledge.wobble, 0.04, 0.15, "its edge wanders a little")
	assert_false(ledge.is_round(), "an ellipse, not a disc")
	assert_between(ledge.edge, 5.0, 6.0, "its edge")
	assert_eq(ledge.ground, &"ground_high", "its top is the world's mesa-top ground")
	var from_floor := floor_stamp.metres_from(ledge.centre, _terrain.radius)
	assert_lte(from_floor + ledge.reach(), floor_stamp.radius - MARGIN, "nested in the floor's flat part")
	var layout := _place.layout()
	assert_false(layout.has("outcrop"), "the outcrop is gone")
	# North of the pool, and its foot clear of the wall's farthest point.
	var off := ledge.centre - _place.dir()
	var frame := _place.frame()
	var local := frame.inverse() * off
	assert_lt(local.z, 0.0, "north of the pool")
	var far := 0.0
	for p: Array in layout["wall"]["ring"]:
		far = maxf(far, Vector2(float(p[0]), float(p[1])).length())
	assert_gt(from_floor - ledge.reach(), far + 3.0, "outside the wall")
	# Its top is flat at its level + height, all the way out along its long
	# axis, well past the short one.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tested := 0
	var long_way := 0
	for i in 400:
		var d := _disc_sample(ledge.centre, rng, 0.0, ledge.radius * (1.0 + ledge.wobble))
		var m := ledge.metres_from(d, _terrain.radius)
		if m > ledge.flat_radius(d) - 0.3:
			continue
		tested += 1
		if m > ledge.radius / ledge.stretch * 1.5:
			long_way += 1
		assert_almost_eq(_terrain.height_at(d), ledge.level + ledge.height, FLAT, "a flat top")
	assert_gt(tested, 60, "enough of the top was walked")
	assert_gt(long_way, 15, "and much of it far out along the long axis")

func test_the_sun_stands_low_over_the_oasis() -> void:
	assert_not_null(_place, "p3 has the place oasis")
	if _place == null:
		return
	var d := _place.dir()
	var to_sun := _system.star.point.minus(_planet.point.plus(d * _planet.radius)).normalized()
	var elevation := rad_to_deg(asin(d.dot(to_sun)))
	gut.p("the sun is %.2f degrees up at the oasis" % elevation)
	assert_between(elevation, 30.0 - SUN_SLACK, 30.0 + SUN_SLACK)

func test_the_pad_and_the_bank_are_flat_and_the_floor_rolls() -> void:
	var floor_stamp := _stamp(&"oasis_floor")
	var bank := _stamp(&"pool_bank")
	var shore := _stamp(&"pool_shore")
	var pad := _stamp(&"pad")
	var pool := _stamp(&"pool")
	if floor_stamp == null or bank == null or pad == null or pool == null or shore == null:
		fail_test("the oasis stamps are not there")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var lo := INF
	var hi := -INF
	for i in 200:
		var h := _terrain.height_at(_disc_sample(pad.centre, rng, 0.0, pad.radius))
		lo = minf(lo, h)
		hi = maxf(hi, h)
	gut.p("pad: %.4f .. %.4f over its own level %.4f" % [lo, hi, pad.level])
	assert_lt(hi - lo, FLAT, "the pad is level")
	assert_between((hi + lo) * 0.5 - pad.level, PAD_RAISE - PAD_SLACK, PAD_RAISE + PAD_SLACK, "0.15 m over the floor")
	lo = INF
	hi = -INF
	# Rework 2: the pool's shore is level (its own stamp, keep 0) ...
	for i in 200:
		var h := _terrain.height_at(_disc_sample(shore.centre, rng, pool.radius, shore.radius))
		lo = minf(lo, h)
		hi = maxf(hi, h)
	gut.p("pool shore: %.4f .. %.4f" % [lo, hi])
	assert_lt(hi - lo, FLAT, "the pool's shore is level")
	assert_lt(absf((hi + lo) * 0.5 - shore.level - shore.raise), FLAT, "at the shore's own level")
	# ... and the bank round it keeps a fifth of the floor's roll: gentle, but
	# not dead flat.
	assert_almost_eq(bank.keep, 0.2, 0.05, "the bank keeps about a fifth of the roll")
	var bank_lo := INF
	var bank_hi := -INF
	var bank_n := 0
	while bank_n < 200:
		var d := _disc_sample(bank.centre, rng, shore.reach() + 2.0, bank.radius)
		var on_another := false
		for st in _terrain.stamps:
			if st.id != &"oasis_floor" and st.id != &"pool_bank" and st.metres_from(d, _terrain.radius) <= st.reach() + 1.0:
				on_another = true
		if on_another:
			continue
		bank_n += 1
		var h := _terrain.height_at(d)
		bank_lo = minf(bank_lo, h)
		bank_hi = maxf(bank_hi, h)
	gut.p("pool bank: %.4f .. %.4f" % [bank_lo, bank_hi])
	assert_gt(bank_hi - bank_lo, FLAT, "the bank rolls")
	assert_lt(bank_hi - bank_lo, 0.6, "gently")
	# The rest of the floor rolls, gently.
	var heights := PackedFloat64Array()
	while heights.size() < 400:
		var d := _disc_sample(floor_stamp.centre, rng, 30.0, 115.0)
		if _on_a_stamp(d):
			continue
		heights.append(_terrain.height_at(d))
	var mean := 0.0
	for h in heights:
		mean += h
	mean /= heights.size()
	var variance := 0.0
	for h in heights:
		variance += (h - mean) * (h - mean)
	var deviation := sqrt(variance / heights.size())
	gut.p("floor: standard deviation %.3f m over 400 samples" % deviation)
	assert_gte(deviation, MIN_ROLL, "the floor rolls")
	var steepest := 0.0
	for i in 400:
		var d := _disc_sample(floor_stamp.centre, rng, 30.0, 115.0)
		if _on_a_stamp(d):
			continue
		var turn := rng.randf() * TAU
		var step := _terrain.height_at(_toward(d, turn, 2.0)) - _terrain.height_at(d)
		steepest = maxf(steepest, rad_to_deg(atan(absf(step) / 2.0)))
	gut.p("steepest 2 m step on the floor: %.1f deg" % steepest)
	assert_lte(steepest, MAX_FLOOR_SLOPE_DEG, "the floor stays walkable")

## Whether `d` is within reach (and 2 m) of any stamp but the floor: the
## pad, the bank, the ledge, each building's and garden's.
func _on_a_stamp(d: Vector3) -> bool:
	for s in _terrain.stamps:
		if s.id != &"oasis_floor" and s.metres_from(d, _terrain.radius) <= s.reach() + 2.0:
			return true
	return false

## R3: the file and the stamp name one pad radius.
func test_the_pad_matches_the_oasis_file() -> void:
	assert_not_null(_place, "p3 has the place oasis")
	if _place == null or _stamp(&"pad") == null:
		return
	var layout := _place.layout()
	assert_true(layout.has("pad") and layout.has("pool"), "oasis.json has the pad and the pool")
	assert_eq(float(layout["pad"]["radius"]), _stamp(&"pad").radius, "oasis.json's pad is the stamp's pad")
	assert_eq(layout["pad"]["at"], [-80.0, -40.0])
	assert_eq(float(layout["pool"]["level"]), -WATER_BELOW)

## The half-diagonal (m) of a grid's horizontal footprint: its cells' box in x and z.
static func _half_diagonal(grid: ShipGrid) -> float:
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for c: Vector3i in grid.coords():
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.z))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.z))
	var size := Vector2(hi - lo + Vector2i.ONE) * ShipGrid.CELL_SIZE
	return size.length() * 0.5

func test_every_library_ship_fits_the_pad() -> void:
	var pad := _stamp(&"pad")
	if pad == null:
		fail_test("the pad stamp is not there")
		return
	var library := ShipLibrary.load_from_dir()
	assert_gt(library.ids().size(), 0, "there are ships")
	for id in library.ids():
		var half := _half_diagonal(library.grid(id))
		gut.p("%s: half-diagonal %.1f m" % [id, half])
		assert_lte(half + PAD_MARGIN, pad.radius, "%s fits a %.0f m pad" % [id, pad.radius])

func test_the_pool_is_wadeable() -> void:
	var pool := _stamp(&"pool")
	var floor_stamp := _stamp(&"oasis_floor")
	if pool == null or floor_stamp == null:
		fail_test("the oasis stamps are not there")
		return
	var shore := _stamp(&"pool_shore")
	var water := shore.level + shore.raise - WATER_BELOW
	var worst := 0.0
	for k in 8:
		var bearing := TAU * k / 8.0 + 0.2
		# The edge: the metres out at which the ground comes up to the water.
		var lo := 0.0
		var hi := pool.radius
		for i in 40:
			var mid := (lo + hi) * 0.5
			if water - _terrain.height_at(_toward(pool.centre, bearing, mid)) > 0.0:
				lo = mid
			else:
				hi = mid
		var edge := lo
		assert_between(edge, 14.0, 15.5, "the water's edge on ray %d (%.2f m)" % [k, edge])
		var knee := water - _terrain.height_at(_toward(pool.centre, bearing, edge - 2.0))
		assert_between(knee, 0.4, 0.6, "2 m in on ray %d (%.2f m deep)" % [k, knee])
		var middle := water - _terrain.height_at(pool.centre)
		assert_between(middle, 0.9, 1.05, "the centre")
		for step in 60:
			worst = maxf(worst, water - _terrain.height_at(_toward(pool.centre, bearing, step * 0.3)))
	gut.p("deepest %.3f m" % worst)
	assert_lte(worst, 1.05, "nowhere over waist deep")

func test_no_cover_at_the_oasis() -> void:
	var floor_stamp := _stamp(&"oasis_floor")
	if floor_stamp == null:
		fail_test("the floor stamp is not there")
		return
	var finest := CubeSphere.depth_for(_terrain.radius)
	var reach := ceili((floor_stamp.radius + 4.0) / CubeSphere.edge_m(_terrain.radius, finest)) + 1
	var mid := CubeSphere.key_for(floor_stamp.centre, finest)
	var cells := 1 << finest
	var chunks := 0
	var beyond := 0
	for j in range(-reach, reach + 1):
		for i in range(-reach, reach + 1):
			var x := mid.z + i
			var y := mid.w + j
			if x < 0 or y < 0 or x >= cells or y >= cells:
				continue
			var key := Vector4i(mid.x, mid.y, x, y)
			var centre := TerrainChunkData.centre_of(_terrain, key)
			var cover := GroundCover.scatter(_terrain, key)
			chunks += 1
			var found: Array = []
			found.append_array(cover.boulders)
			found.append_array(cover.grass)
			for item: Array in found:
				var d := ((item[0] as Transform3D).origin + Vector3(centre)).normalized()
				assert_gt(floor_stamp.metres_from(d, _terrain.radius), floor_stamp.radius, "cover on the oasis floor")
				beyond += 1
	gut.p("%d chunks round the oasis, %d stones and tufts beyond its floor" % [chunks, beyond])
	assert_gt(chunks, 4, "chunks were looked at")

func test_the_rest_of_p3_is_untouched() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var checked := 0
	while checked < 500:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if d.length() < 0.1 or d.length() > 1.0:
			continue
		d = d.normalized()
		var beyond := true
		for s in _terrain.stamps:
			beyond = beyond and s.metres_from(d, _terrain.radius) > s.reach() + 1.0
		if not beyond:
			continue
		checked += 1
		assert_eq(_terrain.height_at(d), _terrain.base_height_at(d), "untouched ground")
	# And the ground just past the floor's blend is the base ground too.
	var floor_stamp := _stamp(&"oasis_floor")
	if floor_stamp == null:
		fail_test("the floor stamp is not there")
		return
	for k in 16:
		var d := _toward(floor_stamp.centre, k * 0.4, floor_stamp.reach() + 3.0)
		assert_eq(_terrain.height_at(d), _terrain.base_height_at(d), "just past the blend")
