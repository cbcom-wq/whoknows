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
