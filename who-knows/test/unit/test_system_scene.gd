extends GutTest

## The star system in the real flight scene (the system skeleton spec §3, §10):
## it is there from the first frame, the debug hop puts you by any body, the
## hull bumps off a world's shell, and the sensors and map know the bodies.

var _root: Node
var _ship: Ship
var _universe: Universe

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	await wait_physics_frames(3)

func _focus() -> UniversePoint:
	return _universe.to_universe(_ship.exterior.global_position)

func test_the_flight_starts_at_the_system_s_entry_with_its_worlds_in_place():
	var system: SystemRecipe = _root.system
	var star_system: StarSystem = _root.star_system
	assert_not_null(star_system)
	assert_eq(star_system.proxies.size(), system.bodies.size())
	assert_almost_eq(_focus().minus(system.entry()).length(), 0.0, 50.0, "at the entry")
	assert_true(star_system.whereabouts.is_in(&"belt_0"), star_system.whereabouts.text())

func test_the_sensors_know_every_world():
	var system: SystemRecipe = _root.system
	var ids := _ship.sensors.contacts(MapPage.RANGES[MapPage.SYSTEM_RANGE]).map(func(c: Contact) -> StringName: return c.id)
	var worlds := 0
	for b in system.bodies:
		if _focus().minus(b.point).length() - b.radius <= MapPage.RANGES[MapPage.SYSTEM_RANGE]:
			worlds += 1
			assert_true(ids.has(BodyContacts.id_of(b)), "%s" % b.id)
	assert_gt(worlds, 3)
	assert_eq(_ship.sensors.system, system)
	assert_not_null(_ship.sensors.whereabouts)

func test_the_hop_puts_you_by_each_body_in_turn():
	var system: SystemRecipe = _root.system
	for i in 3:
		assert_true(_root.hop(1))
		await wait_physics_frames(2)
		var b := system.bodies[i]
		var height := _focus().minus(b.point).length() - b.radius
		assert_almost_eq(height, _root.hop_off(b), 5.0, "%s" % b.id)
		assert_lt(_ship.exterior.global_position.length(), Universe.SHIFT_AT + 1.0, "the origin followed")
		assert_true(_root.star_system.whereabouts.is_in(StringName("near_%s" % b.id)))
	assert_true(_root.hop(-1))
	await wait_physics_frames(2)
	var back := system.bodies[1]
	assert_almost_eq(_focus().minus(back.point).length() - back.radius, _root.hop_off(back), 5.0)

func test_the_hull_bumps_off_a_world():
	var system: SystemRecipe = _root.system
	var planet := system.planets()[0]
	_root.hop_index = system.bodies.find(planet) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(2)
	var proxy: BodyProxy = _root.star_system.proxy(planet.id)
	assert_true(proxy.is_near(), "3 km off: solid")
	var centre := _universe.to_engine(planet.point)
	var out := (_ship.exterior.global_position - centre).normalized()
	_ship.exterior.global_position = centre + out * (planet.radius + 40.0)
	_ship.exterior.linear_velocity = -out * 15.0
	await wait_physics_frames(240)
	var closest := (_ship.exterior.global_position - centre).length()
	assert_gt(closest, planet.radius, "the hull never went in")
