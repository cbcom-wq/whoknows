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
	assert_eq(_terrain.stamps.size(), 6, "six stamps")
	for id in [&"oasis_floor", &"pool_bank", &"pad", &"pool", &"garden_dry", &"hut_crushed"]:
		assert_not_null(_stamp(id), str(id))
	assert_eq(_system.design.problems(_system), PackedStringArray(), "the design is valid")

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
	var pad := _stamp(&"pad")
	var pool := _stamp(&"pool")
	if floor_stamp == null or bank == null or pad == null or pool == null:
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
	for i in 200:
		var h := _terrain.height_at(_disc_sample(bank.centre, rng, pool.radius, bank.radius))
		lo = minf(lo, h)
		hi = maxf(hi, h)
	gut.p("pool bank: %.4f .. %.4f" % [lo, hi])
	assert_lt(hi - lo, FLAT, "the pool's bank is level")
	assert_lt(absf((hi + lo) * 0.5 - bank.level), FLAT, "at the bank's own level")
	# The rest of the floor rolls, gently.
	var heights := PackedFloat64Array()
	while heights.size() < 400:
		var d := _disc_sample(floor_stamp.centre, rng, 30.0, 115.0)
		if pad.metres_from(d, _terrain.radius) <= pad.reach() or bank.metres_from(d, _terrain.radius) <= bank.reach():
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
		if pad.metres_from(d, _terrain.radius) <= pad.reach() or bank.metres_from(d, _terrain.radius) <= bank.reach():
			continue
		var turn := rng.randf() * TAU
		var step := _terrain.height_at(_toward(d, turn, 2.0)) - _terrain.height_at(d)
		steepest = maxf(steepest, rad_to_deg(atan(absf(step) / 2.0)))
	gut.p("steepest 2 m step on the floor: %.1f deg" % steepest)
	assert_lte(steepest, MAX_FLOOR_SLOPE_DEG, "the floor stays walkable")

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
	var water := _stamp(&"pool_bank").level - WATER_BELOW
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
