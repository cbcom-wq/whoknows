extends GutTest

## The floating origin (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §4), headless, with bare nodes.

var _world: Node3D
var _universe: Universe

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_universe = Universe.new()
	_world.add_child(_universe)

func _member(at: Vector3) -> Node3D:
	var n := Node3D.new()
	_world.add_child(n)
	n.global_position = at
	n.add_to_group(Universe.EXTERIOR_SPACE)
	return n

func test_near_the_origin_nothing_moves():
	var focus := _member(Vector3(1999, -1999, 1999))
	_universe.set_focus(focus)
	assert_false(_universe.check())
	assert_eq(focus.global_position, Vector3(1999, -1999, 1999))
	assert_eq(_universe.shifts, 0)

func test_past_two_kilometres_the_origin_moves_in_whole_kilometres():
	var focus := _member(Vector3(2600, -2100, 30))
	_universe.set_focus(focus)
	assert_true(_universe.check())
	assert_eq(focus.global_position, Vector3(-400, -100, 30))
	assert_true(_universe.origin.is_equal_approx(UniversePoint.at(3000, -2000, 0)))
	assert_eq(_universe.shifts, 1)

func test_everything_outside_moves_together():
	var focus := _member(Vector3(2500, 0, 0))
	var rock := _member(Vector3(2600, 40, -70))
	_universe.set_focus(focus)
	_universe.check()
	assert_eq(rock.global_position - focus.global_position, Vector3(100, 40, -70))

func test_the_interior_never_moves():
	var focus := _member(Vector3(0, 0, 2500))
	var interior := Node3D.new()
	_world.add_child(interior)
	interior.global_position = Vector3(0, -5000, 0)
	_universe.set_focus(focus)
	_universe.check()
	assert_eq(interior.global_position, Vector3(0, -5000, 0))

func test_motion_survives_a_shift():
	var body := RigidBody3D.new()
	_world.add_child(body)
	body.add_to_group(Universe.EXTERIOR_SPACE)
	body.global_position = Vector3(3100, 0, 0)
	body.linear_velocity = Vector3(5, 0, 0)
	body.angular_velocity = Vector3(0, 1, 0)
	_universe.set_focus(body)
	_universe.check()
	assert_eq(body.global_position, Vector3(100, 0, 0))
	assert_eq(body.linear_velocity, Vector3(5, 0, 0))
	assert_eq(body.angular_velocity, Vector3(0, 1, 0))

func test_the_shift_is_announced():
	_universe.set_focus(_member(Vector3(-2600, 0, 0)))
	watch_signals(_universe)
	_universe.check()
	assert_signal_emitted_with_parameters(_universe, "shifted", [Vector3(-3000, 0, 0)])

func test_a_shift_changes_no_universe_position():
	var focus := _member(Vector3(2600, 10, 20))
	var rock := _member(Vector3(2750.25, -3.5, 12))
	_universe.set_focus(focus)
	var before := _universe.to_universe(rock.global_position)
	_universe.check()
	assert_true(_universe.to_universe(rock.global_position).is_equal_approx(before))

func test_engine_positions_round_trip_exactly():
	_universe.shift(Vector3(7000, -3000, 12000))
	var p := Vector3(1234.567, -89.5, 3.25)
	assert_eq(_universe.to_engine(_universe.to_universe(p)), p)

func test_a_live_world_space_effect_holds_the_shift_until_four_kilometres():
	var burst := GPUParticles3D.new()
	_world.add_child(burst)
	burst.add_to_group(Universe.HOLDS_SHIFT)
	burst.emitting = true
	var focus := _member(Vector3(2500, 0, 0))
	_universe.set_focus(focus)
	assert_true(_universe.is_held())
	assert_false(_universe.check(), "waits while the puffs are out")
	focus.global_position = Vector3(4100, 0, 0)
	assert_true(_universe.check(), "but never past 4 km")

func test_with_nothing_alive_nothing_holds():
	var burst := GPUParticles3D.new()
	_world.add_child(burst)
	burst.add_to_group(Universe.HOLDS_SHIFT)
	burst.emitting = false
	assert_false(_universe.is_held())

func test_without_a_focus_nothing_happens():
	_member(Vector3(9000, 0, 0))
	assert_false(_universe.check())

func test_it_goes_first_in_every_physics_tick():
	assert_lt(_universe.process_physics_priority, 0)
