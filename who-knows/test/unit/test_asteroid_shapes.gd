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

# --- debris and clusters (the warp spec §3.1, §3.3) ---------------------------

func _disc() -> AsteroidShapes.Debris:
	var d := AsteroidShapes.Debris.new()
	d.centre = UniversePoint.at(0, 0, 0)
	d.inner = 1000.0
	d.outer = 15000.0
	d.half_thickness = 3000.0
	d.holes = [[Vector3(8000, 0, 0), 900.0]]
	return d

func test_a_debris_disc_is_empty_in_its_well_and_holes_and_full_mid_disc():
	var d := _disc()
	assert_eq(d.profile(UniversePoint.at(500, 0, 0)), 0.0, "in the well")
	assert_eq(d.profile(UniversePoint.at(0, 2000, 0)), 0.0, "straight above the planet: still the well")
	assert_eq(d.profile(UniversePoint.at(8000, 0, 300)), 0.0, "in a moon's well")
	assert_almost_eq(d.profile(UniversePoint.at(0, 0, 5000)), 1.0, 1e-6, "mid-disc")
	assert_eq(d.profile(UniversePoint.at(0, 0, 16000)), 0.0, "beyond its outer edge")
	assert_eq(d.profile(UniversePoint.at(0, 3500, 5000)), 0.0, "above the disc")
	assert_between(d.profile(UniversePoint.at(0, 0, 13000)), 0.01, 0.99, "easing off outward")

func test_discs_near_a_cell_are_found_by_a_conservative_bound():
	var shapes := AsteroidShapes.new()
	shapes.debris.append(_disc())
	assert_eq(shapes.debris_near(UniversePoint.at(14000, 0, 0), 200.0).size(), 1)
	assert_eq(shapes.debris_near(UniversePoint.at(0, 0, 40000), 200.0).size(), 0)

func test_a_cluster_lifts_most_at_its_heart_and_none_past_its_reach():
	var shapes := AsteroidShapes.new()
	var c := AsteroidShapes.Cluster.new()
	c.centre = UniversePoint.at(0, 0, 0)
	c.radius = 4000.0
	shapes.clusters.append(c)
	assert_almost_eq(shapes.cluster_lift(UniversePoint.at(0, 0, 0)), AsteroidShapes.CLUSTER_LIFT, 1e-6)
	assert_almost_eq(shapes.cluster_lift(UniversePoint.at(1500, 0, 0)), AsteroidShapes.CLUSTER_LIFT, 1e-6)
	assert_eq(shapes.cluster_lift(UniversePoint.at(4100, 0, 0)), 0.0)
	assert_eq(AsteroidShapes.new().cluster_lift(UniversePoint.at(0, 0, 0)), 0.0, "no clusters, no lift")
