extends GutTest

## The flight computer feels a world's pull and holds against it (desert-world
## spec §5.2; Planetfall §8.2).

const BUDGET := {&"forward": 1.5e6, &"reverse": 5e5, &"lateral": 5e5, &"vertical": 1e6}
const MASS := 105_700.0

## A well that pulls the same everywhere, so no system is needed.
class FakeGravity extends WorldGravity:
	var g := Vector3.ZERO
	var alt := INF
	var air := 0.0
	var body: SystemBody = null
	func air_at(_p: Vector3) -> float:
		return air
	func body_at(_p: Vector3) -> SystemBody:
		return body
	func at(_p: Vector3) -> Vector3:
		return g
	func up_at(_p: Vector3) -> Vector3:
		return -g.normalized()
	func altitude_at(_p: Vector3) -> float:
		return alt
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

## Boost raises the ceiling only on the axes it boosts (plan constraint: that
## direction's cap rises 2.5x; the sum never exceeds the budget elsewhere).
func test_boost_forward_does_not_lift_the_vertical_ceiling():
	_fc.thrust_budget = BUDGET
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_hull.linear_velocity = Vector3(0, -5.0, 0)   # sinking: drift correction adds to the hold
	_fc.set_pilot_input(Vector3(0, 0, -1), Vector3.ZERO, true)
	_fc._apply_translation(1.0 / 60.0)
	assert_true(_fc.boosting)
	assert_lte(_fc.commanded_force_local.y, 1e6)
	assert_gte(_fc.commanded_force_local.y, -1e6)
	assert_gt(absf(_fc.commanded_force_local.z), 1.5e6, "the boosted axis may exceed 1x")

func test_input_up_in_a_well_is_clamped_at_the_vertical_budget():
	_fc.thrust_budget = BUDGET
	_fc.gravity = _fake_gravity(Vector3(0, -2.0, 0))
	_fc.set_pilot_input(Vector3(0, 1, 0), Vector3.ZERO, false)
	_fc._apply_translation(1.0 / 60.0)
	assert_eq(_fc.commanded_force_local.y, 1e6)

func test_input_down_in_a_well_adds_to_the_hold():
	_fc.thrust_budget = BUDGET
	_fc.gravity = _fake_gravity(Vector3(0, -2.0, 0))
	_fc.set_pilot_input(Vector3(0, -1, 0), Vector3.ZERO, false)
	_fc._apply_translation(1.0 / 60.0)
	assert_almost_eq(_fc.commanded_force_local.y, 2.0 * MASS - 1e6, 0.5)

## Horizon levelling (desert-world spec §5.2).
func test_level_rates_fade_in_below_150():
	var tilted := Basis(Vector3.RIGHT, deg_to_rad(20))
	assert_eq(FlightComputer.level_rates(tilted, Vector3.UP, 200.0, Vector3.ZERO), Vector3.ZERO)
	var half := FlightComputer.level_rates(tilted, Vector3.UP, 125.0, Vector3.ZERO)
	var full := FlightComputer.level_rates(tilted, Vector3.UP, 50.0, Vector3.ZERO)
	assert_almost_eq(half.x, full.x * 0.5, 1e-4)
	assert_almost_eq(absf(full.x), minf(FlightComputer.LEVEL_GAIN * deg_to_rad(20), FlightComputer.ASSIST_TURN_RATE), 1e-4)
	assert_eq(full.y, 0.0)

func test_the_stick_wins():
	var tilted := Basis(Vector3.RIGHT, deg_to_rad(20))
	assert_eq(FlightComputer.level_rates(tilted, Vector3.UP, 50.0, Vector3(1, 0, 0)).x, 0.0)

func test_levelling_turns_toward_up_in_pitch():
	var tilted := Basis(Vector3.RIGHT, deg_to_rad(20))
	var r := FlightComputer.level_rates(tilted, Vector3.UP, 50.0, Vector3.ZERO)
	var after := tilted * Basis(Vector3.RIGHT, r.x * 0.1)
	assert_lt(after.y.angle_to(Vector3.UP), deg_to_rad(20))

func test_levelling_turns_toward_up_in_roll():
	var tilted := Basis(Vector3.BACK, deg_to_rad(20))
	var r := FlightComputer.level_rates(tilted, Vector3.UP, 50.0, Vector3.ZERO)
	assert_ne(r.z, 0.0)
	var after := tilted * Basis(Vector3.BACK, r.z * 0.1)
	assert_lt(after.y.angle_to(Vector3.UP), deg_to_rad(20))

func test_keel_altitude_is_infinite_without_a_well():
	assert_eq(_fc.keel_altitude(), INF)

func test_the_assist_levels_a_tilted_hull_near_the_ground():
	_fc.gravity = _fake_gravity(Vector3(0, -2.0, 0))
	(_fc.gravity as FakeGravity).alt = 50.0
	_fc.torque_budget = Vector3(1e6, 1e6, 1e6)
	_fc.inertia = Vector3(1e5, 1e5, 1e5)
	_hull.global_transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(20)), Vector3.ZERO)
	_fc._apply_rotation(1.0 / 60.0)
	# Rolled +20 about local Z: the torque must roll it back, the way level_rates says.
	var want := FlightComputer.level_rates(_hull.global_transform.basis, Vector3.UP, 50.0, Vector3.ZERO)
	assert_ne(_fc.commanded_torque_local.z, 0.0)
	assert_eq(signf(_fc.commanded_torque_local.z), signf(want.z))
	assert_lt(want.z, 0.0, "rolls back toward up")

func _near_ground(basis: Basis) -> void:
	_fc.gravity = _fake_gravity(Vector3(0, -2.0, 0))
	(_fc.gravity as FakeGravity).alt = 50.0
	_fc.torque_budget = Vector3(1e6, 1e6, 1e6)
	_fc.inertia = Vector3(1e5, 1e5, 1e5)
	_hull.global_transform = Transform3D(basis, Vector3.ZERO)

func test_the_assist_levels_pitch_near_the_ground():
	_near_ground(Basis(Vector3.RIGHT, deg_to_rad(20)))
	_fc._apply_rotation(1.0 / 60.0)
	var want := FlightComputer.level_rates(_hull.global_transform.basis, Vector3.UP, 50.0, Vector3.ZERO)
	assert_ne(_fc.commanded_torque_local.x, 0.0)
	assert_eq(signf(_fc.commanded_torque_local.x), signf(want.x))

func test_heading_hold_is_levelled_in_roll_only():
	# Tilted in both pitch and roll, so ungated levelling would add pitch; the hold
	# already points the nose at its heading (-Z), so it commands none itself and
	# levelling must not add any.
	_near_ground(Basis(Vector3.RIGHT, deg_to_rad(15)) * Basis(Vector3.BACK, deg_to_rad(20)))
	_fc.heading_hold = true
	_fc.heading = _hull.global_transform.basis * Vector3.FORWARD
	_fc._apply_rotation(1.0 / 60.0)
	assert_ne(_fc.commanded_torque_local.z, 0.0, "roll still levels")
	assert_eq(_fc.commanded_torque_local.x, 0.0, "pitch is the hold's")

func test_the_roll_stick_wins():
	var tilted := Basis(Vector3.BACK, deg_to_rad(20))
	assert_eq(FlightComputer.level_rates(tilted, Vector3.UP, 50.0, Vector3(0, 0, 1)).z, 0.0)

func test_an_inverted_hull_rolls_to_right_itself():
	var r := FlightComputer.level_rates(Basis(Vector3.BACK, PI), Vector3.UP, 50.0, Vector3.ZERO)
	assert_ne(r.z, 0.0)
	assert_eq(r.x, 0.0)
	assert_eq(r.y, 0.0)

func test_no_levelling_with_the_assist_off():
	_fc.assist_enabled = false
	_fc.gravity = _fake_gravity(Vector3(0, -2.0, 0))
	(_fc.gravity as FakeGravity).alt = 50.0
	_fc.torque_budget = Vector3(1e6, 1e6, 1e6)
	_hull.global_transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(20)), Vector3.ZERO)
	_fc._apply_rotation(1.0 / 60.0)
	assert_eq(_fc.commanded_torque_local, Vector3.ZERO)

## On the ground (Ruling 7): the landing monitor says the hull rests on it, and
## with the stick centred the hold and the levelling stand down, so the ship's
## weight reaches the ground and it can settle.
func test_on_the_ground_with_a_centred_stick_the_hold_stands_down():
	_fc.thrust_budget = BUDGET
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_fc.on_ground = true
	_fc._apply_translation(1.0 / 60.0)
	assert_eq(_fc.commanded_force_local, Vector3.ZERO)

func test_on_the_ground_the_levelling_stands_down():
	_near_ground(Basis(Vector3.RIGHT, deg_to_rad(20)))
	_fc.on_ground = true
	_fc._apply_rotation(1.0 / 60.0)
	assert_eq(_fc.commanded_torque_local.x, 0.0)

func test_any_translation_input_restores_the_hold():
	_fc.thrust_budget = BUDGET
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_fc.on_ground = true
	_fc.set_pilot_input(Vector3(0, 0, -0.1), Vector3.ZERO, false)
	_fc._apply_translation(1.0 / 60.0)
	assert_almost_eq(_fc.commanded_force_local.y, 7.0 * MASS, 1.0)

func test_any_translation_input_restores_the_levelling():
	_near_ground(Basis(Vector3.RIGHT, deg_to_rad(20)))
	_fc.on_ground = true
	_fc.set_pilot_input(Vector3(0, 0, -0.1), Vector3.ZERO, false)
	_fc._apply_rotation(1.0 / 60.0)
	assert_ne(_fc.commanded_torque_local.x, 0.0)

## Task 15 N1: the hold stands down on the ground for exactly what the landing
## monitor lifts a landed ship off on (LandingMonitor.translating): the stick,
## or a velocity hold climbing over HOLD_LIFTS. So your ship handed to its pilot
## climbs off the ground with the hold behind it, not against its own weight.
func test_a_climbing_velocity_hold_restores_the_hold_on_the_ground():
	_fc.thrust_budget = BUDGET
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_fc.on_ground = true
	_fc.hold_velocity(Vector3(0, 1.0, 0))
	assert_false(_fc._resting_on_ground(), "a 1 m/s climb is not resting")
	_fc._apply_translation(1.0 / 60.0)
	assert_gte(_fc.commanded_force_local.y, 7.0 * MASS - 1.0, "the hold is back")
	for v: Vector3 in [Vector3(0, 0.2, 0), Vector3(5, 0, 0), Vector3(0, -2, 0)]:
		_fc.hold_velocity(v)
		assert_true(_fc._resting_on_ground(), "a hold of %s leaves it resting, as it leaves it landed" % v)

func test_off_the_ground_the_hold_still_holds():
	_fc.thrust_budget = BUDGET
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_fc._apply_translation(1.0 / 60.0)
	assert_almost_eq(_fc.commanded_force_local.y, 7.0 * MASS, 1.0)

func test_drag_slows_a_coasting_hull():
	_fc.assist_enabled = false
	var f := _fake_gravity(Vector3.ZERO)
	f.air = 1.0
	_fc.gravity = f
	_hull.linear_velocity = Vector3(100, 0, 0)
	await wait_physics_frames(60)
	assert_almost_eq(_hull.linear_velocity.length(), 87.8, 1.0)   # 1/v = 1/100 + t/720

## Air at a point, not at the ship's whereabouts: _fc.whereabouts stays null.
class PatchyAir extends FakeGravity:
	func air_at(p: Vector3) -> float:
		return 1.0 if p.x > 1000.0 else 0.0

func test_drag_is_the_hulls_own_air():
	_fc.assist_enabled = false
	_fc.gravity = PatchyAir.new()
	_hull.global_position = Vector3(5000, 0, 0)
	_hull.linear_velocity = Vector3(100, 0, 0)
	await wait_physics_frames(30)
	assert_lt(_hull.linear_velocity.length(), 99.0)
	_hull.global_position = Vector3.ZERO
	_hull.linear_velocity = Vector3(100, 0, 0)
	await wait_physics_frames(1)
	assert_almost_eq(_hull.linear_velocity.length(), 100.0, 1e-3)

func test_no_drag_at_warp():
	var w := TravellingWarp.new()
	add_child_autofree(w)
	_fc.warp = w
	var f := _fake_gravity(Vector3.ZERO)
	f.air = 1.0
	_fc.gravity = f
	_hull.linear_velocity = Vector3(100, 0, 0)
	await wait_physics_frames(2)
	assert_almost_eq(_hull.linear_velocity.length(), 100.0, 1e-3)

func test_no_heat_below_eighty_percent_or_without_air():
	assert_eq(FlightComputer.heat(0.79 * 200.0, 200.0, 1.0), 0.0)
	assert_eq(FlightComputer.heat(250.0, 200.0, 0.04), 0.0)

func test_heat_rises_to_the_limit():
	assert_almost_eq(FlightComputer.heat(180.0, 200.0, 1.0), 0.5, 1e-6)
	assert_almost_eq(FlightComputer.heat(200.0, 200.0, 0.5), 1.0, 1e-6)
	assert_almost_eq(FlightComputer.heat(400.0, 200.0, 1.0), 1.0, 1e-6)

func _heat_gravity() -> FakeGravity:
	var f := FakeGravity.new()
	f.air = 1.0
	f.alt = 500.0
	var b := SystemBody.new()
	b.radius = 30000.0
	b.well_radius = 60000.0
	f.body = b
	return f

func test_heat_is_the_hulls_own_place():
	_fc.gravity = _heat_gravity()
	var limit := FlightComputer.speed_limit(500.0, 30000.0)
	_hull.linear_velocity = Vector3(limit, 0, 0)
	assert_almost_eq(_fc.entry_heat(), 1.0, 1e-4)
	_hull.linear_velocity = Vector3(limit * 0.5, 0, 0)
	assert_eq(_fc.entry_heat(), 0.0)

## A gravity that counts what entry_heat asks of it.
class CountingGravity extends FakeGravity:
	var asked := 0
	func body_at(p: Vector3) -> SystemBody:
		asked += 1
		return super(p)
	func air_at(p: Vector3) -> float:
		asked += 1
		return super(p)
	func altitude_at(p: Vector3) -> float:
		asked += 1
		return super(p)

## Review #20: the limit is never under cruise, so a hull slower than HEAT_FROM
## of cruise has no heat, and entry_heat answers before it asks the world
## anything (it runs every tick for every ship).
func test_a_slow_hull_has_no_heat_without_asking_the_world():
	var f := CountingGravity.new()
	f.air = 1.0
	f.alt = 500.0
	f.body = _heat_gravity().body
	_fc.gravity = f
	_hull.linear_velocity = Vector3(FlightComputer.HEAT_FROM * FlightComputer.CRUISE_LIMIT_MPS - 0.5, 0, 0)
	assert_eq(_fc.entry_heat(), 0.0)
	assert_eq(f.asked, 0, "nothing asked of the world")
	_hull.linear_velocity = Vector3(FlightComputer.speed_limit(500.0, 30000.0), 0, 0)
	assert_almost_eq(_fc.entry_heat(), 1.0, 1e-4, "fast, it still heats")

## The hold alone, as RcsShow leaves it unpuffed: the gravity hold within the
## budget, whatever the pilot adds; none with the assist off.
func test_the_hold_alone_is_kept_for_the_rcs_show():
	_fc.thrust_budget = BUDGET
	_fc.gravity = _fake_gravity(Vector3(0, -7.0, 0))
	_fc.assist_enabled = true
	_fc.set_pilot_input(Vector3(0.5, 0.0, -1.0), Vector3.ZERO, false)
	_fc._apply_translation(1.0 / 60.0)
	assert_almost_eq(_fc.hold_force_local, FlightComputer.gravity_hold(Vector3(0, -7.0, 0), MASS, BUDGET),
		Vector3.ONE * 0.01)
	_fc.gravity = _fake_gravity(Vector3(0, -20.0, 0))
	_fc._apply_translation(1.0 / 60.0)
	assert_eq(_fc.hold_force_local.y, 1e6, "clamped to the vertical budget")
	_fc.assist_enabled = false
	_fc._apply_translation(1.0 / 60.0)
	assert_eq(_fc.hold_force_local, Vector3.ZERO, "no hold with the assist off")

func test_a_frozen_or_arriving_hull_never_glows():
	_fc.gravity = _heat_gravity()
	var limit := FlightComputer.speed_limit(500.0, 30000.0)
	_hull.linear_velocity = Vector3(limit, 0, 0)
	assert_gt(_fc.entry_heat(), 0.9)
	_hull.freeze = true
	assert_eq(_fc.entry_heat(), 0.0)
	_hull.freeze = false
	var w := TravellingWarp.new()
	add_child_autofree(w)
	_fc.warp = w
	assert_eq(_fc.entry_heat(), 0.0)
