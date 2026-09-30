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

# --- warp targets, limits, clusters and debris (the warp spec §3) -------------

func test_warp_limits_reach_past_each_body_s_edge_and_hold_its_moons():
	for k in 200:
		var s := SystemRecipe.from_seed(k * 7919 + 3)
		var broken := s.problems()
		assert_eq(broken.size(), 0, "seed %d: %s" % [s.seed, ", ".join(broken)])
		for t in s.warp_targets():
			assert_gte(t.limit, t.edge + SystemRecipe.WARP_CLEAR - 0.01, "%s" % t.id)
		for p in s.planets():
			for m in s.moons_of(p):
				assert_lte(m.point.minus(p.point).length() + m.neighbourhood, p.warp_limit, "%s" % m.id)

func test_targets_are_the_star_then_the_planets_then_the_clusters():
	var s := SystemRecipe.from_seed(1337)
	var targets := s.warp_targets()
	assert_eq(targets[0].id, &"star")
	assert_eq(targets[0].kind, WarpTarget.Kind.STAR)
	assert_eq(targets[0].edge, s.star.well_radius)
	var planets := s.planets()
	for i in planets.size():
		assert_eq(targets[i + 1].id, planets[i].id)
		assert_eq(targets[i + 1].kind, WarpTarget.Kind.PLANET)
		assert_eq(targets[i + 1].limit, planets[i].warp_limit)
	for i in s.clusters.size():
		assert_eq(targets[planets.size() + 1 + i], s.clusters[i])
	assert_eq(targets.size(), 1 + planets.size() + s.clusters.size())
	for t in targets:
		assert_eq(s.warp_target(t.id), t)
		assert_eq(t.contact_id(), StringName("body:" + String(t.id)))

func test_clusters_lie_in_their_belts_apart_and_the_first_is_the_start():
	var with_belts := 0
	for k in 200:
		var s := SystemRecipe.from_seed(k * 104729 + 11)
		if s.belts.is_empty():
			assert_eq(s.clusters.size(), 0)
			continue
		with_belts += 1
		assert_eq(s.clusters[0].id, &"belt_0.c1")
		assert_true(s.clusters[0].point.is_equal_approx(s.entry()), "seed %d: the first cluster is the start" % s.seed)
		var per_belt := {}
		for i in s.clusters.size():
			var c := s.clusters[i]
			assert_eq(c.kind, WarpTarget.Kind.CLUSTER)
			assert_eq(c.limit, SystemRecipe.CLUSTER_RADIUS + SystemRecipe.WARP_CLEAR)
			assert_true(c.name.ends_with(" CLUSTER"), c.name)
			if i > 0:
				assert_gt(s.belts[c.belt].profile(c.point), 0.0, "seed %d: %s lies in its belt" % [s.seed, c.id])
			per_belt[c.belt] = per_belt.get(c.belt, 0) + 1
		for n: int in per_belt.values():
			assert_lte(n, SystemRecipe.CLUSTERS.y)
	assert_gt(with_belts, 180)

func test_every_planet_has_a_debris_disc_from_its_well_to_inside_its_limit():
	var s := SystemRecipe.from_seed(11)
	var planets := s.planets()
	assert_eq(s.debris.size(), planets.size())
	for k in planets.size():
		var p := planets[k]
		var d := s.debris[k]
		assert_true(d.centre.is_equal_approx(p.point))
		assert_eq(d.inner, p.well_radius)
		assert_eq(d.outer, p.warp_limit - SystemRecipe.DEBRIS_INSIDE)
		assert_eq(d.half_thickness, SystemRecipe.DEBRIS_HALF_THICKNESS)
		if p.ring != null:
			assert_true(d.normal.is_equal_approx(p.ring.normal), "a ringed planet's debris follows its ring")
		assert_lte(d.normal.angle_to(Vector3.UP), SystemRecipe.RING_TILT + 0.001)

func test_the_versions_moved_on():
	assert_eq(SystemRecipe.VERSION, 2)
	assert_eq(AsteroidRecipe.VERSION, 3)
