extends GutTest

## The landing monitor's transition table (Planetfall §9; desert-world spec §5.3).

func _i(o := {}) -> Dictionary:
	var d := {touching = true, closing = 1.0, speed = 0.1, spin = 0.0, tilt = 0.0, translating = false}
	d.merge(o, true)
	return d

func _s(state: int, held := 0.0, apart := 0.0) -> Dictionary:
	return {state = state, held = held, apart = apart}

func test_first_contact_touches():
	var s := LandingMonitor.step(_s(LandingMonitor.State.FLYING), _i(), 0.016)
	assert_eq(s.state, LandingMonitor.State.TOUCHING)
	assert_eq(s.hard, 0.0)

func test_hard_touchdown_reports_speed():
	var s := LandingMonitor.step(_s(LandingMonitor.State.FLYING), _i({closing = 5.5}), 0.016)
	assert_eq(s.hard, 5.5)

func test_a_gentle_touchdown_is_not_hard():
	var s := LandingMonitor.step(_s(LandingMonitor.State.FLYING), _i({closing = 4.0}), 0.016)
	assert_eq(s.hard, 0.0)

func test_no_contact_keeps_flying():
	var s := LandingMonitor.step(_s(LandingMonitor.State.FLYING), _i({touching = false}), 0.016)
	assert_eq(s.state, LandingMonitor.State.FLYING)

func test_settled_for_a_second_lands():
	var s := _s(LandingMonitor.State.TOUCHING)
	for k in 61:
		s = LandingMonitor.step(s, _i(), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.LANDED)

func test_not_yet_a_second_does_not_land():
	var s := _s(LandingMonitor.State.TOUCHING)
	for k in 50:
		s = LandingMonitor.step(s, _i(), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.TOUCHING)

func test_tilt_over_25_never_lands():
	var s := _s(LandingMonitor.State.TOUCHING)
	for k in 120:
		s = LandingMonitor.step(s, _i({tilt = deg_to_rad(31)}), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.TOUCHING)

func test_moving_never_lands():
	var s := _s(LandingMonitor.State.TOUCHING)
	for k in 120:
		s = LandingMonitor.step(s, _i({speed = 0.8}), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.TOUCHING)

func test_spinning_never_lands():
	var s := _s(LandingMonitor.State.TOUCHING)
	for k in 120:
		s = LandingMonitor.step(s, _i({spin = 0.3}), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.TOUCHING)

func test_pilot_translation_never_lands():
	var s := _s(LandingMonitor.State.TOUCHING)
	for k in 120:
		s = LandingMonitor.step(s, _i({translating = true}), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.TOUCHING)

func test_a_jolt_restarts_the_second():
	var s := _s(LandingMonitor.State.TOUCHING)
	for k in 50:
		s = LandingMonitor.step(s, _i(), 1.0 / 60.0)
	s = LandingMonitor.step(s, _i({speed = 2.0}), 1.0 / 60.0)
	for k in 50:
		s = LandingMonitor.step(s, _i(), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.TOUCHING)

func test_lost_contact_flies_again_after_grace():
	var s := _s(LandingMonitor.State.TOUCHING, 0.5)
	for k in 16:
		s = LandingMonitor.step(s, _i({touching = false}), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.FLYING)

func test_a_brief_bounce_stays_touching():
	var s := _s(LandingMonitor.State.TOUCHING, 0.5)
	for k in 8:
		s = LandingMonitor.step(s, _i({touching = false}), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.TOUCHING)

func test_translation_lifts_off():
	var s := LandingMonitor.step(_s(LandingMonitor.State.LANDED, 1.0), _i({translating = true}), 0.016)
	assert_eq(s.state, LandingMonitor.State.FLYING)

func test_landed_ignores_lost_contact():
	var s := _s(LandingMonitor.State.LANDED, 1.0)
	for k in 120:
		s = LandingMonitor.step(s, _i({touching = false}), 1.0 / 60.0)
	assert_eq(s.state, LandingMonitor.State.LANDED)

func test_landed_stays_with_no_input():
	var s := LandingMonitor.step(_s(LandingMonitor.State.LANDED, 1.0), _i(), 0.016)
	assert_eq(s.state, LandingMonitor.State.LANDED)

func test_step_does_not_change_its_input():
	var before := _s(LandingMonitor.State.FLYING)
	LandingMonitor.step(before, _i(), 0.016)
	assert_eq(before.state, LandingMonitor.State.FLYING)

func test_refusal_words():
	var m := LandingMonitor.new()
	autofree(m)
	assert_eq(m.refusal(), "Not landed")
	m.restore_landed()
	assert_eq(m.refusal(), "")

## Out of a well nothing steps (a restored landed ship in a scene with no world
## stays landed and frozen; a flying one never freezes).
func _rig() -> Array:
	var hull := RigidBody3D.new()
	add_child_autofree(hull)
	var fc := FlightComputer.new()
	fc.hull_path = NodePath("../" + hull.name)
	hull.get_parent().add_child(fc)
	autofree(fc)
	var m := LandingMonitor.new()
	m.hull = hull
	m.flight = fc
	add_child_autofree(m)
	return [hull, fc, m]

func test_out_of_a_well_a_flying_ship_never_freezes():
	var r := _rig()
	await wait_physics_frames(5)
	assert_eq(r[2].state, LandingMonitor.State.FLYING)
	assert_false(r[0].freeze)
	assert_false(r[1].on_ground)

func test_out_of_a_well_a_restored_landed_ship_stays_landed_and_frozen():
	var r := _rig()
	r[2].restore_landed()
	await wait_physics_frames(5)
	assert_eq(r[2].state, LandingMonitor.State.LANDED)
	assert_true(r[0].freeze)
	assert_eq(r[0].freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)
	assert_true(r[1].on_ground)

## Ruling 7a: touching AND in contact this tick; through the grace it is false.
class StubContact extends LandingMonitor:
	var contact := true
	func _touching_ground() -> bool:
		return contact

class Pull extends WorldGravity:
	func at(_p: Vector3) -> Vector3:
		return Vector3(0, -3.0, 0)
	func up_at(_p: Vector3) -> Vector3:
		return Vector3.UP
	## On the ground: a ship restored landed is where it was saved
	## (LandingMonitor.RESTORE_SLACK).
	func altitude_at(_p: Vector3) -> float:
		return 0.0

func test_touching_with_no_contact_this_tick_is_not_on_ground():
	var hull := RigidBody3D.new()
	add_child_autofree(hull)
	var fc := FlightComputer.new()
	fc.hull_path = NodePath("../" + hull.name)
	hull.get_parent().add_child(fc)
	autofree(fc)
	fc.gravity = Pull.new()
	var m := StubContact.new()
	m.hull = hull
	m.flight = fc
	add_child_autofree(m)
	m._physics_process(1.0 / 60.0)
	assert_eq(m.state, LandingMonitor.State.TOUCHING)
	assert_true(fc.on_ground, "touching and in contact")
	m.contact = false
	m._physics_process(1.0 / 60.0)
	assert_eq(m.state, LandingMonitor.State.TOUCHING, "still in the grace")
	assert_false(fc.on_ground, "the hold is back at once")

## Final review M1: your ship handed to its pilot (P) flies on a velocity hold
## with the stick centred. A hold with an upward part -- over 0.5 m/s along up
## (LandingMonitor.HOLD_LIFTS) -- lifts a landed ship off, as the stick would;
## one along the ground, down, or barely up leaves it landed.
func _landed_rig() -> Array:
	var hull := RigidBody3D.new()
	add_child_autofree(hull)
	var fc := FlightComputer.new()
	fc.hull_path = NodePath("../" + hull.name)
	hull.get_parent().add_child(fc)
	autofree(fc)
	fc.gravity = Pull.new()
	var m := StubContact.new()
	m.hull = hull
	m.flight = fc
	add_child_autofree(m)
	m.restore_landed()
	return [hull, fc, m]

func test_a_landed_ship_given_an_upward_hold_lifts_off():
	var r := _landed_rig()
	var fc: FlightComputer = r[1]
	var m: LandingMonitor = r[2]
	assert_true(fc.assist_enabled, "a hold needs the assist")
	fc.hold_velocity(Vector3(3.0, 2.0, 0.0))
	m._physics_process(1.0 / 60.0)
	assert_eq(m.state, LandingMonitor.State.FLYING, "the pilot's climb lifts it off")
	assert_false((r[0] as RigidBody3D).freeze, "thawed")

func test_a_landed_ship_given_a_level_or_downward_hold_stays_landed():
	var r := _landed_rig()
	var fc: FlightComputer = r[1]
	var m: LandingMonitor = r[2]
	for v: Vector3 in [Vector3(5.0, 0.0, 0.0), Vector3(0.0, -2.0, 0.0), Vector3(0.0, 0.2, 0.0)]:
		fc.hold_velocity(v)
		m._physics_process(1.0 / 60.0)
		assert_eq(m.state, LandingMonitor.State.LANDED, "held at %s" % v)
	fc.release_velocity()
	m._physics_process(1.0 / 60.0)
	assert_eq(m.state, LandingMonitor.State.LANDED, "no hold")

## Task 15 N1, in the flight scene: the starter landed on a world and handed a
## 1 m/s climb with the stick centred (as its pilot flies it) rises off the
## ground within 3 s. The flight computer's hold stands down on the ground only
## for what leaves it landed (LandingMonitor.translating), so it climbs with
## the hold behind it, not against its own weight.
func test_a_landed_starter_given_a_1_m_s_climb_rises_off_within_3_s():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	await wait_physics_frames(3)
	root.reload = func() -> void: pass
	var ship: Ship = root.get_node("Ship")
	var universe: Universe = root.get_node("Universe")
	var system: SystemRecipe = root.system
	var planet: SystemBody = system.planets()[0]
	for p in system.planets():
		if p.radius > planet.radius:
			planet = p
	root.hop_index = system.bodies.find(planet) - 1
	assert_true(root.hop(1))
	await wait_physics_frames(2)
	var surface: WorldSurface = (root.star_system.proxy(planet.id) as BodyProxy).surface()
	var centre := universe.to_engine(planet.point)
	var up := (ship.exterior.global_position - centre).normalized()
	var along := up.cross(Vector3.UP).normalized()
	ship.exterior.global_transform = Transform3D(Basis(along, up, along.cross(up).normalized()),
		centre + up * (planet.radius + surface.terrain.height_at(up) + ship.stance_depth() + 0.02))
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	ship.flight_computer.assist_enabled = true
	ship.landing.restore_landed()
	await wait_physics_frames(10)
	assert_true(ship.landing.is_landed(), "landed")
	var fc := ship.flight_computer
	var start := fc.keel_altitude()
	fc.hold_velocity(up * 1.0)
	var rose: bool = await wait_until(func() -> bool: return fc.keel_altitude() > start + 0.5, 3.0)
	var rise := fc.keel_altitude() - start
	fc.release_velocity()
	assert_true(rose, "risen %.2f m off the ground in 3 s (state %s)" % [rise, LandingMonitor.State.keys()[ship.landing.state]])
	assert_false(ship.landing.is_landed(), "lifted off")

func test_the_status_strings():
	var m := LandingMonitor.new()
	autofree(m)
	m.state = LandingMonitor.State.TOUCHING
	m._tilt = deg_to_rad(31.0)
	assert_eq(m.refusal(), "Uneven ground · tilt 31°")
	assert_eq(m.ground_status(), "UNEVEN GROUND · TILT 31°")
	m._tilt = deg_to_rad(10.0)
	assert_eq(m.refusal(), "Not landed")
	assert_eq(m.ground_status(), "")

func test_too_heavy_for_this_world():
	var m := LandingMonitor.new()
	autofree(m)
	var fc := FlightComputer.new()
	m.flight = fc
	autofree(fc)
	assert_eq(m.ground_status(), "", "INF margin outside a well")
	m.flight = HeavyFlight.new()
	autofree(m.flight)
	assert_eq(m.ground_status(), "TOO HEAVY FOR THIS WORLD")

class HeavyFlight extends FlightComputer:
	func lift_margin() -> float:
		return 0.8

func test_only_terrain_is_ground():
	var terrain := StaticBody3D.new()
	terrain.collision_layer = BodyProxy.LAYER
	var rock := StaticBody3D.new()
	rock.collision_layer = AsteroidBody.LAYER
	var hull := StaticBody3D.new()
	hull.collision_layer = 1
	autofree(terrain)
	autofree(rock)
	autofree(hull)
	assert_true(LandingMonitor.is_ground(terrain))
	assert_false(LandingMonitor.is_ground(rock))
	assert_false(LandingMonitor.is_ground(hull))
	assert_false(LandingMonitor.is_ground(null))
