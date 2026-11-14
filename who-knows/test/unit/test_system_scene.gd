extends GutTest

## The star system in the real flight scene (the system skeleton spec §3, §10):
## it is there from the first frame, the debug hop puts you by any body, the
## hull bumps off a world's ground, and the sensors and map know the bodies.

const LevelGround := preload("res://test/unit/helpers/level_ground.gd")

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
	var ids := _ship.sensors.contacts(MapPage.QUERY).map(func(c: Contact) -> StringName: return c.id)
	var worlds := 0
	for b in system.bodies:
		if _focus().minus(b.point).length() - b.radius <= MapPage.QUERY:
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
	var surface: WorldSurface = (_root.star_system.proxy(planet.id) as BodyProxy).surface()
	assert_not_null(surface, "3 km off: its ground is drawn")
	var centre := _universe.to_engine(planet.point)
	var out := (_ship.exterior.global_position - centre).normalized()
	var ground := planet.radius + surface.terrain.height_at(out)
	_ship.exterior.global_position = centre + out * (ground + 40.0)
	_ship.exterior.linear_velocity = -out * 15.0
	await wait_physics_frames(240)
	var local := _universe.to_universe(_ship.exterior.global_position).minus(planet.point)
	assert_gt(surface.terrain.altitude_of(local), 0.0, "the hull never went in")
	assert_eq(surface.floor_fired, 0, "the ground held it, not the safety net")

## The hull flown into a hillside at the low-altitude limit (the world scale
## spec §8.2): about 124 m/s is 2 m a physics tick into a trimesh, with the
## streaming and the under-anchor build racing it. It must never end below the
## ground, and the analytic floor, the safety net, must never be what stops it.
## `steep` is the glide's pitch below the horizon, degrees; `start_height` is
## how far over the ground it starts: the air's drag (WorldGravity.DRAG_K) bleeds
## speed over a long path, so a shallow glide starts low to still meet the
## ground fast.
func _dive_into_the_ground(steep: float, start_height := 300.0) -> void:
	var system: SystemRecipe = _root.system
	var planet: SystemBody = system.planets()[0]
	for p in system.planets():
		if p.radius > planet.radius:
			planet = p
	_root.hop_index = system.bodies.find(planet) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(2)
	var surface: WorldSurface = (_root.star_system.proxy(planet.id) as BodyProxy).surface()
	assert_not_null(surface, "3 km off: its ground is drawn")
	var centre := _universe.to_engine(planet.point)
	var out := (_ship.exterior.global_position - centre).normalized()
	var ground := planet.radius + surface.terrain.height_at(out)
	_ship.exterior.global_position = centre + out * (ground + start_height)
	_ship.exterior.linear_velocity = Vector3.ZERO
	await wait_physics_frames(60)
	# Re-aim from where the hull is now: it has not moved, but be exact.
	out = (_ship.exterior.global_position - centre).normalized()
	var along := out.cross(Vector3.UP).normalized()
	var limit: float = _ship.flight_computer.speed_limit_now()
	assert_between(limit, 120.0, 130.0, "the low-altitude limit")
	# A levelled hull meets the hillside flat at ~100 m/s and may break; this test
	# is about the ground holding it, and never the real reload over GUT's scene.
	_root.reload = func() -> void: pass
	var speed := limit - 3.0
	_ship.exterior.linear_velocity = (-out * sin(deg_to_rad(steep)) + along * cos(deg_to_rad(steep))) * speed
	var lowest := INF
	var fastest_at_ground := 0.0
	for i in 600:
		await wait_physics_frames(1)
		var local := _universe.to_universe(_ship.exterior.global_position).minus(planet.point)
		var altitude := surface.terrain.altitude_of(local)
		lowest = minf(lowest, altitude)
		if altitude < 30.0:
			fastest_at_ground = maxf(fastest_at_ground, _ship.exterior.linear_velocity.length())
	assert_lt(lowest, 30.0, "it reached the ground, so the test means something")
	assert_gt(fastest_at_ground, 60.0, "and met it at speed, not after the assist had slowed it")
	assert_gt(lowest, 0.0, "the hull never went in (lowest altitude %.2f m)" % lowest)
	assert_eq(surface.floor_fired, 0, "the ground held it, not the safety net")

func test_the_hull_glides_into_a_world_at_the_limit_and_stays_above_it():
	await _dive_into_the_ground(30.0, 120.0)

func test_the_hull_dives_straight_into_a_world_at_the_limit_and_stays_above_it():
	await _dive_into_the_ground(90.0)

func test_every_ship_flies_through_the_one_world_gravity():
	assert_not_null(_root.world_gravity)
	assert_eq(_ship.flight_computer.gravity, _root.world_gravity)

## The starter put upright `clearance` m over level, boulder-free ground
## (LevelGround) of the biggest planet, the assist on, at rest in the hover.
## Returns the ground's up. Level matters: over a slope one side of the hull is
## nearer the ground than `clearance`, and it meets the ground in the same tick
## it is pushed, before the monitor has seen it moving.
func _hover_over_flat_ground(clearance: float) -> Vector3:
	var system: SystemRecipe = _root.system
	var planet: SystemBody = system.planets()[0]
	for p in system.planets():
		if p.radius > planet.radius:
			planet = p
	_root.hop_index = system.bodies.find(planet) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(2)
	var surface: WorldSurface = (_root.star_system.proxy(planet.id) as BodyProxy).surface()
	assert_not_null(surface, "3 km off: its ground is drawn")
	var centre := _universe.to_engine(planet.point)
	# Level, clear ground near the hop: on a desert, off the dunes and stones.
	var level: Variant = LevelGround.near(surface.terrain, (_ship.exterior.global_position - centre).normalized())
	assert_not_null(level, "level, clear ground near the hop")
	if level == null:
		return Vector3.ZERO
	var out: Vector3 = level
	assert_lt(LevelGround.tilt(surface.terrain, out), LevelGround.LEVEL, "level ground found")
	assert_true(LevelGround.clear(surface.terrain, out), "and no boulder on it")
	var ground := planet.radius + surface.terrain.height_at(out)
	var along := out.cross(Vector3.UP).normalized()
	var basis := Basis(along, out, along.cross(out).normalized())
	_ship.exterior.global_transform = Transform3D(basis, centre + out * (ground + _ship.stance_depth() + clearance))
	_ship.exterior.linear_velocity = Vector3.ZERO
	_ship.exterior.angular_velocity = Vector3.ZERO
	_ship.flight_computer.assist_enabled = true
	_root.reload = func() -> void: pass
	await wait_physics_frames(30)
	# Under 40 m its landing legs fold out (Task 15): it sets down on them.
	var legs := _ship.exterior_builder.legs()
	await wait_until(func() -> bool: return legs.is_down(), 2.0)
	return out

func _push(y: float) -> void:
	_ship.flight_computer.set_pilot_input(Vector3(0.0, y, 0.0), Vector3.ZERO, false)

func test_a_ship_set_down_gently_lands_freezes_and_stays_put():
	await _hover_over_flat_ground(3.0)
	assert_eq(_ship.landing.state, LandingMonitor.State.FLYING, "hovering, not yet down")
	assert_false(_ship.flight_computer.on_ground)
	_push(-0.1)
	var frames := 0
	while _ship.landing.state == LandingMonitor.State.FLYING and frames < 600:
		await wait_physics_frames(1)
		frames += 1
	assert_ne(_ship.landing.state, LandingMonitor.State.FLYING, "it came down (%d frames)" % frames)
	_push(0.0)
	await wait_physics_frames(60 * 4)
	assert_eq(_ship.landing.state, LandingMonitor.State.LANDED, "tilt %.1f deg" % rad_to_deg(_ship.landing.tilt()))
	assert_true(_ship.exterior.freeze, "frozen")
	assert_eq(_ship.landing.ground_status(), "LANDED")
	var at := _ship.exterior.global_position
	await wait_physics_frames(120)
	assert_eq(_ship.landing.state, LandingMonitor.State.LANDED)
	assert_eq(_ship.exterior.global_position, at, "it stays put")

func test_translation_lifts_a_landed_ship_off_and_thaws_it():
	await _hover_over_flat_ground(3.0)
	_push(-0.1)
	var frames := 0
	while _ship.landing.state == LandingMonitor.State.FLYING and frames < 600:
		await wait_physics_frames(1)
		frames += 1
	_push(0.0)
	await wait_physics_frames(60 * 4)
	assert_eq(_ship.landing.state, LandingMonitor.State.LANDED, "tilt %.1f deg" % rad_to_deg(_ship.landing.tilt()))
	var at := _ship.exterior.global_position
	_push(1.0)
	await wait_physics_frames(90)
	assert_eq(_ship.landing.state, LandingMonitor.State.FLYING)
	assert_false(_ship.exterior.freeze, "thawed")
	assert_gt((_ship.exterior.global_position - at).length(), 0.5, "and rising")

func _total_damage() -> float:
	var total := 0.0
	for c in _ship.grid.coords():
		total += _ship.grid.get_block(c).damage
	return total

## A hard landing (Planetfall §9; desert-world spec §5.2) is a warning and a
## thud: terrain has its own, higher crash threshold, so no block takes damage.
func test_a_hard_landing_warns_and_damages_nothing():
	var out := await _hover_over_flat_ground(0.5)
	_ship.flight_computer.assist_enabled = false
	var speeds: Array[float] = []
	_ship.landing.hard_landing.connect(func(s: float) -> void: speeds.append(s))
	var before := _total_damage()
	_ship.exterior.linear_velocity = -out * 6.0
	await wait_physics_frames(60)
	assert_gt(speeds.size(), 0, "hard_landing fired")
	if not speeds.is_empty():
		assert_gt(speeds[0], 4.0)
	assert_eq(_total_damage(), before, "no block lost hp")
