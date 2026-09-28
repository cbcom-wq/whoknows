extends GutTest

## The star system as you see it (the system skeleton spec §7): a proxy per
## body, placed for the focus, and the sun shining from the star.

var _universe: Universe
var _focus: Node3D
var _sun: DirectionalLight3D
var _system: StarSystem

func before_each():
	_universe = Universe.new()
	add_child_autofree(_universe)
	_focus = Node3D.new()
	add_child_autofree(_focus)
	_universe.set_focus(_focus)
	_sun = DirectionalLight3D.new()
	add_child_autofree(_sun)
	var recipe := SystemRecipe.from_seed(1337)
	_universe.origin = recipe.entry()
	_system = StarSystem.new()
	add_child_autofree(_system)
	_system.setup(recipe, _universe, _sun)

func test_every_body_has_a_proxy_placed_before_the_first_frame():
	assert_eq(_system.proxies.size(), _system.recipe.bodies.size())
	for p in _system.proxies:
		assert_lt(p.distance, INF)
		assert_lte(p.global_position.length(), BodyProxy.PROXY_AT + 1.0)

func test_the_sun_shines_from_the_star():
	var focus := _universe.to_universe(_focus.global_position)
	var from_star := focus.minus(_system.recipe.star.point).normalized()
	# A directional light shines along its -z.
	assert_almost_eq((-_sun.global_basis.z).dot(from_star), 1.0, 1e-5)
	var palette: Dictionary = SpacePalette.STARS[_system.recipe.star.star_palette]
	assert_eq(_sun.light_color, palette[&"light"])

func test_moving_the_focus_moves_the_sun():
	_focus.global_position = Vector3(0, 30000, 0)
	_system.place_all()
	var focus := _universe.to_universe(_focus.global_position)
	var from_star := focus.minus(_system.recipe.star.point).normalized()
	assert_almost_eq((-_sun.global_basis.z).dot(from_star), 1.0, 1e-5)

func test_the_star_is_the_one_unshaded_thing():
	var star := _system.proxy(&"star")
	var look := star.get_node("Far") as MeshInstance3D
	assert_eq((look.material_override as StandardMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	var planet := _system.proxy(_system.recipe.planets()[0].id)
	var p_look := planet.get_node("Far") as MeshInstance3D
	assert_eq((p_look.material_override as StandardMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL)

func test_belts_and_dust_are_drawn_from_afar_and_follow_the_origin():
	assert_eq(_system.belts.size(), _system.recipe.belts.size())
	assert_not_null(_system.dust)
	for b in _system.belts:
		assert_true(b.is_in_group(Universe.EXTERIOR_SPACE))
		assert_eq(b.multimesh.instance_count, BeltLook.SLABS)
	var focus := _universe.to_universe(_focus.global_position)
	var belt := _system.belts[0]
	# Every slab within 28 km, and each along its true direction.
	for i in [0, 40, 80]:
		var t := AsteroidStream.unpack(belt.multimesh.buffer, i)
		assert_lte(t.origin.length(), BodyProxy.PROXY_AT + 1.0)
		var true_dir := belt.points[i].minus(focus).normalized()
		assert_almost_eq(t.origin.normalized().dot(true_dir), 1.0, 1e-5)

func test_a_ringed_planet_carries_its_ring():
	for p in _system.proxies:
		assert_eq(p.has_node("Ring"), p.body.ring != null, "%s" % p.body.id)
