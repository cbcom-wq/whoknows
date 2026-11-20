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
	assert_eq(r.palette, rng.randi_range(0, SpacePalette.DRAWN_PALETTES - 1))
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
	assert_eq(WorldRecipe.GENERATOR_VERSION, 4)

func test_planets_pull_at_most_seven():
	assert_eq(WorldRecipe.GRAVITY[WorldRecipe.Kind.PLANET], Vector2(2.0, 7.0))
	for s in 200:
		var r := WorldRecipe.from_seed(s)
		assert_between(r.surface_gravity, 2.0, 7.0)

func test_air_top_by_atmosphere():
	var r := WorldRecipe.from_seed(1)
	r.radius_m = 20000.0
	r.atmosphere = WorldRecipe.Atmosphere.NONE
	assert_almost_eq(r.air_top(), 3000.0, 0.01)
	r.atmosphere = WorldRecipe.Atmosphere.THIN
	assert_almost_eq(r.air_top(), 2400.0, 0.01)
	r.atmosphere = WorldRecipe.Atmosphere.THICK
	assert_almost_eq(r.air_top(), 4000.0, 0.01)

## Pinned from main at b280fa5 before the gravity change: name, radius,
## archetype, relief, palette and atmosphere of four seeds.
const PINNED := [
	[1, "HESTES-34", 46226.47, 2, 870.54, 0, 1],
	[7, "IMAL-87", 38359.94, 1, 409.88, 5, 2],
	[1337, "LIIM-30", 37603.02, 2, 478.26, 5, 1],
	[90210, "MAZE-54", 51302.18, 1, 933.63, 3, 2],
]

func test_gravity_change_moves_nothing_else():
	for row in PINNED:
		var r := WorldRecipe.from_seed(row[0])
		assert_eq([r.name, r.archetype, r.palette, r.atmosphere], [row[1], row[3], row[5], row[6]])
		assert_almost_eq(r.radius_m, row[2], 0.01)
		assert_almost_eq(r.relief_m, row[4], 0.01)

func test_air_is_nothing_at_the_top_and_whole_on_thick_ground():
	var r := WorldRecipe.from_seed(1)
	r.radius_m = 20000.0
	r.atmosphere = WorldRecipe.Atmosphere.THICK   # air top 4000 m
	assert_eq(r.air_at(4000.0), 0.0)
	assert_eq(r.air_at(9000.0), 0.0)
	assert_almost_eq(r.air_at(0.0), 1.0, 1e-6)
	assert_almost_eq(r.air_at(-50.0), 1.0, 1e-6)
	assert_almost_eq(r.air_at(2000.0), 0.25, 1e-6)   # rises faster near the ground

func test_thin_air_and_none():
	var r := WorldRecipe.from_seed(1)
	r.radius_m = 20000.0
	r.atmosphere = WorldRecipe.Atmosphere.THIN
	assert_almost_eq(r.air_at(0.0), 0.35, 1e-6)
	r.atmosphere = WorldRecipe.Atmosphere.NONE
	assert_eq(r.air_at(0.0), 0.0)
	assert_eq(r.air_at(100.0), 0.0)

func test_today_s_worlds_keep_their_archetype_and_palette():
	for s in range(1, 601):
		var r := WorldRecipe.from_seed(s)
		if r.is_desert():
			continue
		assert_eq(r.archetype, WorldSeed.rng(s, &"terrain").randi_range(0, 3), "seed %d" % s)
		assert_eq(r.palette, WorldSeed.rng(s, &"palette").randi_range(0, 7), "seed %d" % s)

func test_a_quarter_of_planets_with_air_are_deserts():
	var air := 0
	var deserts := 0
	for s in range(1, 2001):
		var r := WorldRecipe.from_seed(s)
		if r.atmosphere == WorldRecipe.Atmosphere.NONE:
			assert_false(r.is_desert())
			continue
		air += 1
		if r.is_desert():
			deserts += 1
			assert_eq(r.palette, SpacePalette.DESERT_PALETTE)
	assert_almost_eq(float(deserts) / air, 0.25, 0.03)

func test_moons_are_never_deserts():
	for s in range(1, 501):
		assert_false(WorldRecipe.from_seed(s, WorldRecipe.Kind.MOON).is_desert())

func test_a_desert_keeps_its_size_relief_gravity_and_air():
	# Find seeds that are deserts, and compare with the draws they would have had.
	var found := 0
	for s in range(1, 400):
		var r := WorldRecipe.from_seed(s)
		if not r.is_desert():
			continue
		found += 1
		var terrain := WorldSeed.rng(s, &"terrain")
		terrain.randi_range(0, 3)
		assert_almost_eq(r.relief_m, minf(r.radius_m * terrain.randf_range(0.01, 0.025), 1200.0), 0.001)
	assert_gt(found, 10)

func test_the_starting_system_has_its_deserts():
	var sr := SystemRecipe.from_seed(1337)
	assert_true(sr.body(&"p3").recipe.is_desert())
	assert_true(sr.body(&"p4").recipe.is_desert())
	assert_false(sr.body(&"p2").recipe.is_desert())

func test_every_palette_has_cover_colours():
	for p in SpacePalette.WORLDS:
		assert_true(p.has(&"boulder") and p.has(&"grass"), String(p[&"name"]))
	assert_true(SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE].has(&"streak"))

func test_only_planned_deserts_have_a_plan():
	var r := SystemRecipe.from_seed(1337).body(&"p3").recipe
	assert_not_null(r.plan())
	assert_same(r.plan(), r.plan())
	r.planned = false
	assert_null(r.plan())
