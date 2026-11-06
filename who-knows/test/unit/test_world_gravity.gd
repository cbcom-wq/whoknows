extends GutTest

## WorldGravity, the one source (desert-world spec §5.1).

var sys: SystemRecipe
var b: SystemBody
var star: SystemBody

func before_all():
	sys = SystemRecipe.from_seed(1337)
	b = sys.planets()[0]
	star = sys.star

func _ringed_system() -> SystemRecipe:
	for s in range(1, 200):
		var r := SystemRecipe.from_seed(s)
		if r.planets().any(func(p: SystemBody) -> bool: return p.ring != null and p.ring.inner < p.well_radius):
			return r
	return null

func test_surface_pull_is_the_recipes():
	var g := WorldGravity.vector(sys, b.point.plus(Vector3.UP * b.radius))
	assert_almost_eq(g.length(), b.recipe.surface_gravity, 0.001)
	assert_almost_eq(g.normalized(), Vector3.DOWN, Vector3.ONE * 1e-5)

func test_inverse_square():
	var g := WorldGravity.vector(sys, b.point.plus(Vector3.RIGHT * b.radius * 1.5))
	assert_almost_eq(g.length(), b.recipe.surface_gravity / 2.25, 0.001)

func test_nothing_beyond_the_well_or_from_the_star():
	assert_eq(WorldGravity.vector(sys, b.point.plus(Vector3.UP * (b.well_radius + 1.0))), Vector3.ZERO)
	assert_eq(WorldGravity.vector(sys, star.point.plus(Vector3.UP * star.radius * 1.1)), Vector3.ZERO)

func test_under_ground_pulls_as_at_the_ground():
	var g := WorldGravity.vector(sys, b.point.plus(Vector3.UP * b.radius * 0.5))
	assert_almost_eq(g.length(), b.recipe.surface_gravity, 0.001)

func test_on_world_line_is_the_air_top():
	var top := b.recipe.air_top()
	assert_true(WorldGravity.on_world(sys, b.point.plus(Vector3.UP * (b.radius + top - 1.0))))
	assert_false(WorldGravity.on_world(sys, b.point.plus(Vector3.UP * (b.radius + top + 1.0))))

func test_a_ring_is_not_on_a_world():
	var rs := _ringed_system()
	assert_not_null(rs)
	var ringed: SystemBody = rs.planets().filter(func(p: SystemBody) -> bool: return p.ring != null and p.ring.inner < p.well_radius)[0]
	# The part of the ring that lies inside the well (it begins at 1.6-2.0 R).
	var mid := (ringed.ring.inner + minf(ringed.ring.outer, ringed.well_radius)) * 0.5
	var u := ringed.point.plus(ringed.ring.normal.cross(Vector3.RIGHT).normalized() * mid)
	assert_false(WorldGravity.on_world(rs, u))
	assert_gt(WorldGravity.vector(rs, u).length(), 0.0)

func test_instance_reads_engine_positions():
	var universe := Universe.new()
	add_child_autofree(universe)
	universe.origin = b.point
	var w := WorldGravity.new()
	w.setup(sys, universe, null)
	var p := Vector3.UP * (b.radius + 10.0)
	assert_eq(w.body_at(p), b)
	assert_true(w.on_world_at(p))
	assert_almost_eq(w.up_at(p), Vector3.UP, Vector3.ONE * 1e-5)
	assert_gt(w.at(p).length(), 0.0)
	assert_almost_eq(w.surface_gravity_at(p), b.recipe.surface_gravity, 0.0001)
	assert_almost_eq(w.altitude_at(p), 10.0, 0.01)
	var far := Vector3.UP * (b.well_radius + 1.0)
	assert_null(w.body_at(far))
	assert_eq(w.up_at(far), Vector3.ZERO)
	assert_eq(w.altitude_at(far), INF)
	assert_eq(w.surface_gravity_at(far), 0.0)

func test_body_at_is_null_in_the_stars_well():
	var universe := Universe.new()
	add_child_autofree(universe)
	universe.origin = star.point
	var w := WorldGravity.new()
	w.setup(sys, universe, null)
	assert_null(w.body_at(Vector3.UP * star.radius * 1.1))

func test_air_at_is_the_recipes_at_the_altitude():
	var was := b.recipe.atmosphere
	b.recipe.atmosphere = WorldRecipe.Atmosphere.THICK
	var universe := Universe.new()
	add_child_autofree(universe)
	universe.origin = b.point
	var w := WorldGravity.new()
	w.setup(sys, universe, null)
	var p := Vector3.UP * (b.radius + 1500.0)
	assert_almost_eq(w.air_at(p), b.recipe.air_at(w.altitude_at(p)), 1e-6)
	assert_gt(w.air_at(p), 0.0)
	assert_eq(w.air_at(Vector3.UP * (b.well_radius + 10.0)), 0.0)
	b.recipe.atmosphere = was   # the system is shared by the file's other tests
