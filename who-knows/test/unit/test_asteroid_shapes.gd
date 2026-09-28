extends GutTest

## Where a system keeps its rocks (the system skeleton spec §6): belt and ring
## profiles at known points, and bounds that never miss a shape.

func _belt() -> AsteroidShapes.Belt:
	var b := AsteroidShapes.Belt.new()
	b.centre = UniversePoint.at(0, 0, 0)
	b.radius = 60000.0
	b.half_width = 3000.0
	b.half_thickness = 1000.0
	return b

func _ring() -> AsteroidShapes.Ring:
	var g := AsteroidShapes.Ring.new()
	g.centre = UniversePoint.at(50000, 0, 0)
	g.inner = 2000.0
	g.outer = 4000.0
	g.half_thickness = 40.0
	return g

func test_a_belt_is_full_in_its_core_and_empty_outside():
	var b := _belt()
	assert_eq(b.profile(UniversePoint.at(60000, 0, 0)), 1.0)
	assert_eq(b.profile(UniversePoint.at(0, 0, -61000)), 1.0)
	assert_eq(b.profile(UniversePoint.at(64000, 0, 0)), 0.0)
	assert_eq(b.profile(UniversePoint.at(60000, 1100, 0)), 0.0)
	var edge := b.profile(UniversePoint.at(62400, 0, 0))
	assert_between(edge, 0.01, 0.99)

func test_a_ring_is_a_thin_flat_slab():
	var g := _ring()
	assert_eq(g.profile(UniversePoint.at(53000, 0, 0)), 1.0)
	assert_eq(g.profile(UniversePoint.at(53000, 50, 0)), 0.0)
	assert_eq(g.profile(UniversePoint.at(51000, 0, 0)), 0.0)
	assert_eq(g.profile(UniversePoint.at(55000, 0, 0)), 0.0)
	assert_between(g.profile(UniversePoint.at(52100, 0, 0)), 0.01, 0.99)
	assert_between(g.profile(UniversePoint.at(53000, 35, 0)), 0.01, 0.99)

func test_a_tilted_ring_follows_its_plane():
	var g := _ring()
	g.normal = Vector3.RIGHT
	assert_eq(g.profile(UniversePoint.at(50000, 3000, 0)), 1.0)
	assert_eq(g.profile(UniversePoint.at(53000, 0, 0)), 0.0)

func test_rings_near_finds_every_ring_that_touches_a_cell():
	var s := AsteroidShapes.new()
	s.rings.append(_ring())
	assert_eq(s.rings_near(UniversePoint.at(53000, -100, -100), 200.0).size(), 1)
	assert_eq(s.rings_near(UniversePoint.at(54100, 0, 0), 200.0).size(), 0)

func test_blockers_are_a_little_bigger_than_their_bodies():
	var s := AsteroidShapes.new()
	var b := AsteroidShapes.Blocker.new()
	b.centre = UniversePoint.at(0, 0, 0)
	b.radius = 1000.0
	s.blockers.append(b)
	var near := s.blockers_near(UniversePoint.at(1050, 0, 0), 200.0)
	assert_eq(near.size(), 1)
	assert_almost_eq(near[0][1], 1100.0, 0.001)
	assert_eq(s.blockers_near(UniversePoint.at(1150, 0, 0), 200.0).size(), 0)

func test_belt_profile_takes_the_deepest_belt():
	var s := AsteroidShapes.new()
	s.belts.append(_belt())
	assert_eq(s.belt_profile(UniversePoint.at(60000, 0, 0)), 1.0)
	assert_eq(s.belt_profile(UniversePoint.at(30000, 0, 0)), 0.0)
