extends GutTest

## FlightComputer's attitude maths. The hull it drives is a RigidBody3D, so
## these build one rather than mocking the physics server.

const INERTIA := Vector3(1_874_906.0, 2_752_458.0, 1_115_582.0)   ## starter shuttle
const BUDGET := Vector3(3_000_000.0, 2_000_000.0, 2_000_000.0)

var _hull: RigidBody3D
var _fc: FlightComputer

func before_each():
	_hull = RigidBody3D.new()
	_hull.mass = 95_300.0
	add_child_autofree(_hull)
	_fc = FlightComputer.new()
	_fc.hull_path = NodePath("../" + _hull.name)
	_hull.get_parent().add_child(_fc)
	autofree(_fc)
	_fc.inertia = INERTIA
	_fc.torque_budget = BUDGET

func test_assist_torque_scales_with_inertia_not_mass():
	# A stationary ship asked for full pitch wants the rate error times the
	# gain times inertia -- clamped by what the RCS can actually deliver.
	_fc.torque_budget = Vector3.ONE * 1e12   # take the clamp out of the way
	var torque := _fc.attitude_torque(Vector3(1, 0, 0), Vector3.ZERO)
	assert_almost_eq(
		torque.x,
		FlightComputer.ASSIST_TURN_RATE * FlightComputer.RATE_GAIN * INERTIA.x,
		1.0
	)

func test_assist_torque_never_exceeds_the_budget():
	var torque := _fc.attitude_torque(Vector3(1, -1, 1), Vector3.ZERO)
	assert_almost_eq(torque, Vector3(BUDGET.x, -BUDGET.y, BUDGET.z), Vector3.ONE * 1.0)

func test_assist_stops_pushing_once_the_commanded_rate_is_reached():
	var at_rate := Vector3(FlightComputer.ASSIST_TURN_RATE, 0.0, 0.0)
	assert_almost_eq(
		_fc.attitude_torque(Vector3(1, 0, 0), at_rate), Vector3.ZERO, Vector3.ONE * 0.001
	)

func test_centred_stick_damps_residual_rotation():
	# Zero input is a commanded rate of zero, so the assist brakes the spin.
	var torque := _fc.attitude_torque(Vector3.ZERO, Vector3(0.5, -0.5, 0.25))
	assert_true(torque.x < 0.0 and torque.y > 0.0 and torque.z < 0.0)

func test_settled_ship_with_centred_stick_is_left_alone():
	assert_almost_eq(
		_fc.attitude_torque(Vector3.ZERO, Vector3.ZERO), Vector3.ZERO, Vector3.ONE * 0.001
	)

func test_assist_off_maps_the_stick_straight_to_torque():
	_fc.assist_enabled = false
	assert_almost_eq(
		_fc.attitude_torque(Vector3(1, 0, -0.5), Vector3.ZERO),
		Vector3(BUDGET.x, 0.0, -0.5 * BUDGET.z),
		Vector3.ONE * 1.0
	)

func test_assist_off_does_not_damp():
	_fc.assist_enabled = false
	assert_almost_eq(
		_fc.attitude_torque(Vector3.ZERO, Vector3(1, 1, 1)), Vector3.ZERO, Vector3.ONE * 0.001
	)

## Translation (flight controls spec §5.3, §5.4).

const MASS := 92_300.0
const THRUST := {
	&"forward": 1_500_000.0, &"reverse": 500_000.0,
	&"lateral": 500_000.0, &"vertical": 1_000_000.0,
}

func _push(local_velocity: Vector3, input: Vector3, locked := false, locked_speed := 0.0,
		assist := true) -> Vector3:
	return FlightComputer.translation_force(local_velocity, input, MASS, THRUST, false, assist,
		locked, locked_speed)

func test_drift_is_fought_with_the_whole_side_budget():
	# 40 m/s sideways wants far more than the budget; assist spends all of it.
	var f := _push(Vector3(40.0, 0.0, 0.0), Vector3.ZERO)
	assert_almost_eq(f.x, -THRUST[&"lateral"], 1.0)

func test_small_drift_is_cancelled_in_about_a_second():
	var f := _push(Vector3(0.0, 2.0, 0.0), Vector3.ZERO)
	assert_almost_eq(f.y, -2.0 * MASS, 1.0)

func test_letting_go_brakes_with_the_retros():
	var f := _push(Vector3(0.0, 0.0, -50.0), Vector3.ZERO)
	assert_almost_eq(f.z, THRUST[&"reverse"], 1.0)

func test_catching_up_to_a_lock_uses_the_main_engines():
	# Locked at 50, going 10: the push forward (-z) is the engines', not the
	# retros'. It used to be clamped by the retros both ways.
	var f := _push(Vector3(0.0, 0.0, -10.0), Vector3.ZERO, true, 50.0)
	assert_almost_eq(f.z, -THRUST[&"forward"], 1.0)

func test_a_lock_holds_its_speed():
	assert_almost_eq(_push(Vector3(0.0, 0.0, -50.0), Vector3.ZERO, true, 50.0).z, 0.0, 0.01)

func test_a_lock_slows_you_to_it():
	assert_gt(_push(Vector3(0.0, 0.0, -60.0), Vector3.ZERO, true, 50.0).z, 0.0, "pushes aft")

func test_thrusting_is_not_fought_on_its_own_axis():
	var f := _push(Vector3(0.0, 0.0, -50.0), Vector3(0.0, 0.0, -1.0))
	assert_almost_eq(f.z, -THRUST[&"forward"], 1.0)

func test_assist_off_is_the_stick_alone():
	var f := _push(Vector3(30.0, 5.0, -50.0), Vector3(0.0, 0.0, -0.5), true, 10.0, false)
	assert_almost_eq(f, Vector3(0.0, 0.0, -0.5 * THRUST[&"forward"]), Vector3.ONE * 1.0)

func test_boost_multiplies_the_pilots_push():
	var f := FlightComputer.translation_force(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), MASS, THRUST,
		true, true, false, 0.0)
	assert_almost_eq(f.x, THRUST[&"lateral"] * FlightComputer.BOOST_MULTIPLIER, 1.0)

func test_the_lock_takes_your_forward_speed():
	_hull.linear_velocity = Vector3(3.0, 0.0, -40.0)
	_fc.toggle_speed_lock()
	assert_true(_fc.speed_locked)
	assert_almost_eq(_fc.locked_speed, 40.0, 0.001)
	_fc.toggle_speed_lock()
	assert_false(_fc.speed_locked, "pressing again unlocks")

func test_the_lock_follows_the_throttle_while_it_is_held():
	_hull.linear_velocity = Vector3(0.0, 0.0, -40.0)
	_fc.toggle_speed_lock()
	_hull.linear_velocity = Vector3(0.0, 0.0, -55.0)
	_fc.set_pilot_input(Vector3(0.0, 0.0, -1.0), Vector3.ZERO, false)
	_fc._physics_process(1.0 / 60.0)
	assert_almost_eq(_fc.locked_speed, 55.0, 0.001)

func test_the_lock_needs_assist():
	_fc.assist_enabled = false
	_fc.toggle_speed_lock()
	assert_false(_fc.speed_locked)

func test_turning_assist_off_unlocks():
	_fc.toggle_speed_lock()
	_fc.assist_enabled = false
	assert_false(_fc.speed_locked)

func test_the_commanded_push_is_kept_in_hull_axes():
	_fc.set_pilot_input(Vector3(1.0, 0.0, 0.0), Vector3.ZERO, false)
	_fc._physics_process(1.0 / 60.0)
	assert_almost_eq(_fc.commanded_force_local.x, _fc.thrust_budget[&"lateral"], 1.0)
