extends GutTest

## Sub-seeds (docs/superpowers/specs/2026-09-23-planetfall-design.md §5.1): the
## same every run, on every machine, and independent of one another.

func test_fnv1a_is_the_64_bit_one():
	assert_eq(WorldSeed.fnv1a(""), -3750763034362895579)
	assert_eq(WorldSeed.fnv1a("a"), -5808556873153909620)
	assert_eq(WorldSeed.fnv1a("terrain"), 4578760715504805550)

func test_a_sub_seed_is_pinned():
	assert_eq(WorldSeed.sub(1337, &"terrain"), WorldSeed.sub(1337, &"terrain"))
	assert_eq(WorldSeed.sub(1337, &"terrain"),
		AsteroidRecipe.mix((1337 ^ 4578760715504805550) + -7046029254386353131))

func test_concerns_and_seeds_give_different_sub_seeds():
	var seen := {}
	for s in [0, 1, 1337, -9]:
		for c in [&"terrain", &"palette", &"name", &"slot_0", &"slot_1"]:
			var v := WorldSeed.sub(s, c)
			assert_false(seen.has(v), "%d %s collides" % [s, c])
			seen[v] = true

func test_a_noise_seed_fits_in_31_bits():
	for s in [0, -1, 1337, WorldSeed.sub(7, &"x")]:
		var n := WorldSeed.noise_seed(s)
		assert_between(n, 0, 0x7FFFFFFF)
