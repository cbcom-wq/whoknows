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

## Heading hold (flight controls spec §5.2).

func test_a_target_above_asks_for_nose_up():
	var rate := FlightComputer.heading_rate(Vector3(0.0, 0.5, -1.0), BUDGET, INERTIA)
	assert_gt(rate.x, 0.0)
	assert_almost_eq(rate.y, 0.0, 0.0001)
	assert_eq(rate.z, 0.0, "roll stays with the pilot")

func test_a_target_to_the_left_asks_for_yaw_left():
	var rate := FlightComputer.heading_rate(Vector3(-0.5, 0.0, -1.0), BUDGET, INERTIA)
	assert_gt(rate.y, 0.0)
	assert_almost_eq(rate.x, 0.0, 0.0001)

func test_below_and_right_are_the_other_ways():
	assert_lt(FlightComputer.heading_rate(Vector3(0.0, -0.5, -1.0), BUDGET, INERTIA).x, 0.0)
	assert_lt(FlightComputer.heading_rate(Vector3(0.5, 0.0, -1.0), BUDGET, INERTIA).y, 0.0)

func test_on_target_asks_for_nothing():
	assert_eq(FlightComputer.heading_rate(Vector3.FORWARD, BUDGET, INERTIA), Vector3.ZERO)

func test_a_far_target_is_capped_at_the_turn_rate():
	var rate := FlightComputer.heading_rate(Vector3.LEFT, BUDGET, INERTIA)
	assert_almost_eq(rate.length(), FlightComputer.ASSIST_TURN_RATE, 0.0001)

func test_dead_astern_pitches_round():
	var rate := FlightComputer.heading_rate(Vector3.BACK, BUDGET, INERTIA)
	assert_gt(absf(rate.x), 0.0)
	assert_almost_eq(rate.y, 0.0, 0.0001)

## Swings the shuttle's nose onto a target the way the hull would: the hold's
## rate through attitude_torque, integrated at 60 Hz. Returns [seconds until
## within 0.5 deg, worst error after that in degrees].
func _swing(degrees: float) -> Array:
	var target := Basis(Vector3(0.3, 1.0, 0.1).normalized(), deg_to_rad(degrees)) * Vector3.FORWARD
	var basis := Basis.IDENTITY
	var spin := Vector3.ZERO
	var dt := 1.0 / 60.0
	var reached_at := -1.0
	var worst := 0.0
	for i in 60 * 8:
		var rate := FlightComputer.heading_rate(basis.inverse() * target, BUDGET, INERTIA)
		var torque := _fc.attitude_torque(
			Vector3(rate.x, rate.y, 0.0) / FlightComputer.ASSIST_TURN_RATE, spin)
		spin += torque / INERTIA * dt
		if not spin.is_zero_approx():
			basis = (basis * Basis(spin.normalized(), spin.length() * dt)).orthonormalized()
		var error := rad_to_deg((basis * Vector3.FORWARD).angle_to(target))
		if reached_at < 0.0 and error < 0.5:
			reached_at = i * dt
		if reached_at >= 0.0:
			worst = maxf(worst, error)
	return [reached_at, worst]

func test_the_hold_swings_on_without_overshooting():
	# Simulated before this was written: HOLD_GAIN 3 overshot a 120 deg swing
	# by 2.0 deg; 2 overshoots by at most 1.2 deg and settles in under 4 s.
	for degrees in [30.0, 90.0, 170.0]:
		var result := _swing(degrees)
		assert_between(result[0], 0.0, 5.0, "%d deg reached within 5 s" % degrees)
		assert_lt(result[1], 2.0, "%d deg never overshoots by 2 deg" % degrees)

func test_a_heading_needs_assist():
	_fc.assist_enabled = false
	_fc.set_heading(Vector3.LEFT)
	assert_false(_fc.heading_hold)

func test_turning_assist_off_drops_the_heading():
	_fc.set_heading(Vector3.LEFT)
	assert_true(_fc.heading_hold)
	_fc.assist_enabled = false
	assert_false(_fc.heading_hold)

func test_clearing_the_heading_hands_the_ship_back():
	_fc.set_heading(Vector3.LEFT)
	_fc.clear_heading()
	assert_false(_fc.heading_hold)

func test_holding_a_heading_to_the_left_yaws_left():
	_fc.set_heading(Vector3.LEFT)
	_fc._physics_process(1.0 / 60.0)
	assert_gt(_fc.commanded_torque_local.y, 0.0)
	assert_almost_eq(_fc.commanded_torque_local.x, 0.0, 1.0)

func test_roll_stays_with_the_pilot_during_a_hold():
	_fc.set_heading(Vector3.LEFT)
	_fc.set_pilot_input(Vector3.ZERO, Vector3(0.0, 0.0, 1.0), false)
	_fc._physics_process(1.0 / 60.0)
	assert_gt(_fc.commanded_torque_local.z, 0.0)

func test_the_telemetry_carries_the_hold_and_the_lock():
	_fc.set_heading(Vector3.LEFT)
	_hull.linear_velocity = Vector3(0.0, 0.0, -30.0)
	_fc.toggle_speed_lock()
	var t := _fc.build_telemetry()
	assert_true(t.heading_hold)
	assert_almost_eq(t.heading, Vector3.LEFT, Vector3.ONE * 0.0001)
	assert_true(t.speed_locked)
	assert_almost_eq(t.locked_speed, 30.0, 0.001)
