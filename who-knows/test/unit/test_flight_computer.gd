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

## Translation and the throttle the engines report. The fixture keeps
## FlightComputer's default budgets: forward 900 kN, reverse 300 kN, lateral
## and vertical 250 kN each.

func test_forward_and_reverse_draw_on_their_own_budgets():
	assert_almost_eq(_fc.translation_force(Vector3(0, 0, -1), false),
		Vector3(0, 0, -900_000.0), Vector3.ONE * 1.0)
	assert_almost_eq(_fc.translation_force(Vector3(0, 0, 1), false),
		Vector3(0, 0, 300_000.0), Vector3.ONE * 1.0)

func test_boost_multiplies_the_translation_force():
	assert_almost_eq(_fc.translation_force(Vector3(0.5, 0, -1), true),
		Vector3(0.5 * 250_000.0, 0, -900_000.0) * FlightComputer.BOOST_MULTIPLIER,
		Vector3.ONE * 1.0)

func test_throttle_is_the_share_of_the_budget_on_the_side_pushed():
	assert_almost_eq(_fc.throttle_for(Vector3(-125_000.0, 250_000.0, -450_000.0)),
		Vector3(-0.5, 1.0, -0.5), Vector3.ONE * 0.0001)
	assert_almost_eq(_fc.throttle_for(Vector3(0, 0, 150_000.0)),
		Vector3(0, 0, 0.5), Vector3.ONE * 0.0001, "reverse reads against the reverse budget")

func test_throttle_of_the_pilots_input_is_the_input():
	# Whatever the budgets, full stick is full throttle, and boost goes past it.
	var input := Vector3(0.25, -1.0, -0.75)
	assert_almost_eq(_fc.throttle_for(_fc.translation_force(input, false)), input,
		Vector3.ONE * 0.0001)
	assert_almost_eq(_fc.throttle_for(_fc.translation_force(input, true)),
		input * FlightComputer.BOOST_MULTIPLIER, Vector3.ONE * 0.0001)

func test_a_side_with_no_engines_reads_zero_throttle():
	_fc.thrust_budget[&"reverse"] = 0.0
	assert_almost_eq(_fc.throttle_for(Vector3(0, 0, 50_000.0)), Vector3.ZERO,
		Vector3.ONE * 0.0001)

func test_each_physics_tick_publishes_the_throttle_it_applied():
	_fc.set_pilot_input(Vector3(0, 0, -1), Vector3.ZERO, false)
	_fc._physics_process(1.0 / 60.0)
	assert_almost_eq(_fc.throttle, Vector3(0, 0, -1), Vector3.ONE * 0.0001)

func test_the_throttle_includes_the_assists_drift_correction():
	# Stick centred, but the hull is sliding to port: the assist fires the
	# starboard-pushing engines to stop it, and the throttle says so.
	_hull.linear_velocity = Vector3(-10.0, 0, 0)
	_fc._physics_process(1.0 / 60.0)
	assert_gt(_fc.throttle.x, 0.0, "drift correction pushes to starboard")
	assert_almost_eq(_fc.throttle.x, FlightComputer.DRIFT_AUTHORITY, 0.0001,
		"a hard slide spends all the authority the assist may use")
