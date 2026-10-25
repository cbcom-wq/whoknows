extends GutTest

## The velocity hold (hostile ships spec §5.1): a pilot that is not you asks the
## assist to hold a velocity. It changes only what the assist cancels toward on
## each quiet axis; budgets, DRIFT_AUTHORITY and the speed limit are the
## assist's own, so a hold flies no better than you do.

const MASS := 1000.0
const THRUST := {
	&"forward": 1_500_000.0, &"reverse": 500_000.0,
	&"lateral": 500_000.0, &"vertical": 1_000_000.0,
}

var _hull: RigidBody3D
var _fc: FlightComputer

func before_each():
	_hull = RigidBody3D.new()
	_hull.mass = 95_300.0
	_hull.gravity_scale = 0.0
	add_child_autofree(_hull)
	_fc = FlightComputer.new()
	_fc.hull_path = NodePath("../" + _hull.name)
	_hull.get_parent().add_child(_fc)
	autofree(_fc)

func test_without_a_hold_nothing_changes():
	var v := Vector3(3.0, 0.0, -5.0)
	var today := FlightComputer.translation_force(v, Vector3.ZERO, MASS, THRUST, false, true,
		false, 0.0)
	var unheld := FlightComputer.translation_force(v, Vector3.ZERO, MASS, THRUST, false, true,
		false, 0.0, null)
	assert_almost_eq(unheld, today, Vector3.ONE * 0.001)
	assert_almost_eq(today, Vector3(-3000.0, 0.0, 5000.0), Vector3.ONE * 0.001)

func test_a_hold_pulls_each_quiet_axis_toward_it():
	var f := FlightComputer.translation_force(Vector3(0.0, 0.0, -20.0), Vector3.ZERO, MASS,
		THRUST, false, true, false, 0.0, Vector3(10.0, 0.0, -20.0))
	assert_gt(f.x, 0.0, "pulled toward the held sideways speed")
	assert_almost_eq(f.y, 0.0, 0.001)
	assert_almost_eq(f.z, 0.0, 0.001, "already at the held forward speed")

func test_input_on_an_axis_wins_over_the_hold():
	var f := FlightComputer.translation_force(Vector3(0.0, 0.0, -20.0), Vector3(-1.0, 0.0, 0.0),
		MASS, THRUST, false, true, false, 0.0, Vector3(10.0, 0.0, -20.0))
	assert_almost_eq(f.x, -THRUST[&"lateral"], 0.001)

func test_the_hold_replaces_the_lock_s_target_while_it_lasts():
	var f := FlightComputer.translation_force(Vector3(0.0, 0.0, -50.0), Vector3.ZERO, MASS,
		THRUST, false, true, true, 50.0, Vector3(0.0, 0.0, -20.0))
	assert_gt(f.z, 0.0, "slows to the hold, not the lock")

func test_the_hold_needs_assist():
	_fc.assist_enabled = false
	_fc.hold_velocity(Vector3(0.0, 0.0, -30.0))
	assert_false(_fc.velocity_hold, "refused with the assist off")
	_fc.assist_enabled = true
	_fc.hold_velocity(Vector3(0.0, 0.0, -30.0))
	assert_true(_fc.velocity_hold)
	assert_almost_eq(_fc.held_velocity, Vector3(0.0, 0.0, -30.0), Vector3.ONE * 0.001)
	_fc.assist_enabled = false
	assert_false(_fc.velocity_hold, "turning the assist off drops it")

func test_the_assist_refused_drops_the_hold():
	_fc.hold_velocity(Vector3(0.0, 0.0, -30.0))
	_fc.assist_allowed = false
	assert_false(_fc.velocity_hold)

func test_releasing_hands_the_ship_back():
	_fc.hold_velocity(Vector3(0.0, 0.0, -30.0))
	_fc.release_velocity()
	assert_false(_fc.velocity_hold)

func test_the_hold_leaves_the_pilot_s_lock_alone():
	_hull.linear_velocity = Vector3(0.0, 0.0, -40.0)
	_fc.toggle_speed_lock()
	_fc.hold_velocity(Vector3(0.0, 0.0, -10.0))
	_fc.release_velocity()
	assert_true(_fc.speed_locked)
	assert_almost_eq(_fc.locked_speed, 40.0, 0.001)

func test_the_hold_is_flown_in_hull_axes():
	# Nose turned to world +X: a held world velocity along +X is straight ahead.
	_hull.global_transform.basis = Basis(Vector3.UP, -PI / 2.0)
	_fc.hold_velocity(Vector3(30.0, 0.0, 0.0))
	_fc._physics_process(1.0 / 60.0)
	assert_lt(_fc.commanded_force_local.z, 0.0, "the main engines push ahead")
	assert_almost_eq(_fc.commanded_force_local.x, 0.0, 1.0, "nothing sideways")

func test_the_hold_obeys_the_speed_limit():
	var limit := FlightComputer.CRUISE_LIMIT_MPS
	_hull.linear_velocity = Vector3(0.0, 0.0, -2.0 * limit)
	_fc.hold_velocity(Vector3(0.0, 0.0, -10.0 * limit))
	_fc._physics_process(1.0 / 60.0)
	assert_almost_eq(_hull.linear_velocity.length(), limit, 0.001, "clamped as ever")
	assert_true(_fc.velocity_hold, "the hold stays; only the speed is refused")
