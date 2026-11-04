extends GutTest

## The flight computer feels a world's pull and holds against it (desert-world
## spec §5.2; Planetfall §8.2).

const BUDGET := {&"forward": 1.5e6, &"reverse": 5e5, &"lateral": 5e5, &"vertical": 1e6}
const MASS := 105_700.0

## A well that pulls the same everywhere, so no system is needed.
class FakeGravity extends WorldGravity:
	var g := Vector3.ZERO
	func at(_p: Vector3) -> Vector3:
		return g
	func surface_gravity_at(_p: Vector3) -> float:
		return g.length()

## A warp drive that says it is travelling.
class TravellingWarp extends WarpDrive:
	func travelling() -> bool:
		return true

var _hull: RigidBody3D
var _fc: FlightComputer

func before_each():
	_hull = RigidBody3D.new()
	_hull.mass = MASS
	_hull.gravity_scale = 0.0
	add_child_autofree(_hull)
	_fc = FlightComputer.new()
	_fc.hull_path = NodePath("../" + _hull.name)
	_hull.get_parent().add_child(_fc)
	autofree(_fc)

func _fake_gravity(g: Vector3) -> WorldGravity:
	var f := FakeGravity.new()
	f.g = g
	return f

func test_hold_cancels_gravity_within_budget():
	var h := FlightComputer.gravity_hold(Vector3(0, -7.0, 0), MASS, BUDGET)
	assert_almost_eq(h, Vector3(0, 7.0 * MASS, 0), Vector3.ONE * 0.01)

func test_hold_is_clamped_to_the_budget():
	var h := FlightComputer.gravity_hold(Vector3(0, -20.0, 0), MASS, BUDGET)
	assert_eq(h.y, 1e6)

func test_hold_on_a_pitched_hull_uses_the_engines_it_has():
	# Nose down 90°: gravity is along hull -z (forward); the hold pushes +z with the reverse budget.
	var h := FlightComputer.gravity_hold(Vector3(0, 0, -7.0), MASS, BUDGET)
	assert_eq(h.z, minf(7.0 * MASS, 5e5))

func test_sum_never_exceeds_budget():
	var f := FlightComputer.within_budget(Vector3(2e6, -3e6, -9e6), BUDGET)
	assert_eq(f, Vector3(5e5, -1e6, -1.5e6))

func test_within_budget_scales():
	var f := FlightComputer.within_budget(Vector3(2e6, 3e6, 9e6), BUDGET, 2.0)
	assert_eq(f, Vector3(1e6, 2e6, 1e6))

func test_low_power_never_weakens_the_hold():
	_fc.thrust_budget = BUDGET
	_fc.quantum = QuantumStore.new(1000, 50)   # low power: line is 100
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_hull.mass = MASS
	_fc._apply_translation(1.0 / 60.0)
	assert_almost_eq(_fc.commanded_force_local.y, 7.0 * MASS, 1.0)

func test_assist_off_means_no_hold():
	_fc.assist_enabled = false
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_fc._apply_translation(1.0 / 60.0)
	assert_eq(_fc.commanded_force_local, Vector3.ZERO)

func test_no_gravity_means_no_hold():
	_fc._apply_translation(1.0 / 60.0)
	assert_eq(_fc.commanded_force_local, Vector3.ZERO)

func test_no_gravity_during_warp():
	var w := TravellingWarp.new()
	add_child_autofree(w)
	_fc.warp = w
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	await wait_physics_frames(2)
	assert_eq(_hull.linear_velocity, Vector3.ZERO)

func test_frozen_hull_feels_nothing():
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_hull.freeze = true
	await wait_physics_frames(2)
	assert_eq(_hull.linear_velocity, Vector3.ZERO)
	assert_eq(_fc.commanded_force_local, Vector3.ZERO)

func test_a_hull_with_no_hold_falls():
	# Assist off: nothing holds, so the pull accelerates the hull.
	_fc.assist_enabled = false
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	await wait_physics_frames(3)
	assert_lt(_hull.linear_velocity.y, 0.0)

func test_lift_margin():
	_fc.thrust_budget = BUDGET
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	assert_almost_eq(_fc.lift_margin(), 1e6 / (MASS * 7.0), 0.0001)
	assert_almost_eq(_fc.build_telemetry().lift_margin, _fc.lift_margin(), 0.0001)

func test_lift_margin_is_infinite_in_deep_space():
	assert_eq(_fc.lift_margin(), INF)
	_fc.gravity = _fake_gravity(Vector3.ZERO)
	assert_eq(_fc.lift_margin(), INF)

func test_translation_input_is_the_latched_stick():
	_fc.set_pilot_input(Vector3(1, 0, -1), Vector3.ZERO, false)
	assert_eq(_fc.translation_input(), Vector3(1, 0, -1))
