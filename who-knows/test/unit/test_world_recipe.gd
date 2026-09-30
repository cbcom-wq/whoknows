extends GutTest

## A world's recipe (Planetfall §5.2; the system skeleton spec §4.1): the same
## for the same seed, in range for its kind, and each field from its own
## sub-seed.

const K := WorldRecipe.Kind

func test_the_same_seed_gives_the_same_world():
	var a := WorldRecipe.from_seed(1337)
	var b := WorldRecipe.from_seed(1337)
	assert_eq(a.name, b.name)
	assert_eq(a.radius_m, b.radius_m)
	assert_eq(a.surface_gravity, b.surface_gravity)
	assert_eq(a.archetype, b.archetype)
	assert_eq(a.palette, b.palette)
	assert_eq(a.atmosphere, b.atmosphere)

func test_planets_and_moons_are_in_range():
	for s in 300:
		for kind in [K.PLANET, K.MOON]:
			var r := WorldRecipe.from_seed(s * 7919 + 3, kind)
			assert_between(r.radius_m, WorldRecipe.RADIUS[kind].x, WorldRecipe.RADIUS[kind].y)
			assert_between(r.surface_gravity, WorldRecipe.GRAVITY[kind].x, WorldRecipe.GRAVITY[kind].y)
			assert_between(r.palette, 0, SpacePalette.WORLDS.size() - 1)
			assert_lte(r.relief_m, WorldRecipe.RELIEF_MAX)
			assert_eq(r.well_radius(), r.radius_m * 2.0)
			if kind == K.MOON:
				assert_ne(r.atmosphere, WorldRecipe.Atmosphere.THICK)

func test_each_field_draws_from_its_own_sub_seed():
	# The palette is exactly what its own sub-seed says, whatever else the
	# recipe draws: adding a field never moves it.
	var r := WorldRecipe.from_seed(42)
	var rng := WorldSeed.rng(42, &"palette")
	assert_eq(r.palette, rng.randi_range(0, SpacePalette.WORLDS.size() - 1))
	var size := WorldSeed.rng(42, &"size")
	assert_eq(r.radius_m, size.randf_range(15000.0, 60000.0))

func test_a_name_is_syllables_and_a_number():
	var r := WorldRecipe.from_seed(99)
	var parts := r.name.split("-")
	assert_eq(parts.size(), 2)
	assert_true(parts[1].is_valid_int())
	assert_eq(parts[0], parts[0].to_upper())

func test_worlds_are_tens_of_kilometres_with_real_mountains():
	# The world scale spec §3.1.
	assert_eq(WorldRecipe.RADIUS[K.PLANET], Vector2(15000.0, 60000.0))
	assert_eq(WorldRecipe.RADIUS[K.MOON], Vector2(4000.0, 15000.0))
	assert_eq(WorldRecipe.RELIEF_MAX, 1200.0)
	for s in 200:
		var r := WorldRecipe.from_seed(s * 131 + 7)
		assert_between(r.relief_m, minf(r.radius_m * 0.01, 1200.0) - 0.001, 1200.0)
	assert_eq(WorldRecipe.GENERATOR_VERSION, 2)
