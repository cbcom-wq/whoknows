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
