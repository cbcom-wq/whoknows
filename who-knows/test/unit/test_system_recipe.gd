extends GutTest

## A star system from one seed (the system skeleton spec §4): the same every
## time, and every rule of §4.3 kept for every seed.

const SEEDS := 500

func test_the_same_seed_gives_the_same_system():
	assert_eq(SystemRecipe.from_seed(1337).describe(), SystemRecipe.from_seed(1337).describe())
	assert_ne(SystemRecipe.from_seed(1337).describe(), SystemRecipe.from_seed(1338).describe())

func test_the_star_is_at_the_middle_of_a_layer_of_giant_cells():
	var s := SystemRecipe.from_seed(1337)
	assert_eq(s.star, s.bodies[0])
	assert_true(s.star.point.is_equal_approx(UniversePoint.at(0, SystemRecipe.PLANE_Y, 0)))
	assert_eq(SystemRecipe.PLANE_Y * 2, AsteroidRecipe.CELL[AsteroidRecipe.Tier.GIANT])
	assert_between(s.star.radius, 2500.0, 4000.0)
	assert_between(s.star.star_palette, 0, SpacePalette.STARS.size() - 1)
	assert_eq(s.name, s.star.name)

func test_every_seed_keeps_every_rule():
	var empty := 0
	var planets := 0
	var moons := 0
	var rings := 0
	var reasons := {}
	for k in SEEDS:
		var s := SystemRecipe.from_seed(k * 104729 + 11)
		var broken := s.problems()
		assert_eq(broken.size(), 0, "seed %d: %s" % [s.seed, ", ".join(broken)])
		assert_between(s.slots.size(), 7, 10)
		assert_between(s.belt_slots.size(), 1, 2)
		assert_false(s.belt_slots.has(0))
		assert_lte(s.slots[s.slots.size() - 1], SystemRecipe.LAST_SLOT)
		empty += s.empty_slots.size()
		for e in s.empty_slots.size():
			var why := "slot %d: %s" % [s.empty_slots[e], s.empty_why[e]]
			reasons[why] = reasons.get(why, 0) + 1
		for b in s.bodies:
			match b.kind:
				SystemBody.Kind.PLANET:
					planets += 1
					if b.ring != null:
						rings += 1
				SystemBody.Kind.MOON:
					moons += 1
	gut.p("%d seeds: %d planets, %d moons, %d rings, %d empty slots %s" % [SEEDS, planets, moons, rings, empty, reasons])
	# Empty slots should be rare, and every system should have somewhere to go.
	assert_lt(empty, SEEDS / 10)
	assert_gt(planets, SEEDS * 4)
	assert_gt(moons, SEEDS)
	assert_gt(rings, SEEDS / 4)

func test_most_seeds_keep_a_belt():
	var without := 0
	for k in SEEDS:
		if SystemRecipe.from_seed(k * 7 + 1).belts.is_empty():
			without += 1
	assert_lt(without, SEEDS / 20)

func test_ids_are_stable_and_moons_know_their_planet():
	var s := SystemRecipe.from_seed(2024)
	for b in s.bodies:
		assert_eq(s.body(b.id), b)
		if b.kind == SystemBody.Kind.MOON:
			var p := s.body(b.parent_id)
			assert_not_null(p)
			assert_true(String(b.id).begins_with(String(p.id) + ".m"))
			assert_true(b.name.begins_with(p.name + " "))

func test_moons_follow_their_planet():
	var s := SystemRecipe.from_seed(77)
	var seen := false
	for i in s.bodies.size():
		var b := s.bodies[i]
		if b.kind != SystemBody.Kind.MOON:
			continue
		seen = true
		# Its planet comes before it, with only its siblings between.
		var j := i - 1
		while s.bodies[j].kind == SystemBody.Kind.MOON:
			j -= 1
		assert_eq(s.bodies[j].id, b.parent_id)
	if not seen:
		pass_test("no moons in this seed")

func test_the_shapes_carry_every_belt_ring_and_body():
	var s := SystemRecipe.from_seed(1337)
	var shapes := s.asteroid_shapes()
	assert_eq(shapes.belts.size(), s.belts.size())
	assert_eq(shapes.blockers.size(), s.bodies.size())
	var rings := s.bodies.filter(func(b: SystemBody) -> bool: return b.ring != null).size()
	assert_eq(shapes.rings.size(), rings)
	for g in shapes.rings:
		assert_not_null(g.centre)

func test_a_planet_s_world_comes_from_its_slot():
	var s := SystemRecipe.from_seed(5)
	for p in s.planets():
		var i := String(p.id).substr(1).to_int()
		assert_eq(p.recipe.seed, WorldSeed.sub(5, StringName("slot_%d" % i)))
		assert_eq(p.name, p.recipe.name)
