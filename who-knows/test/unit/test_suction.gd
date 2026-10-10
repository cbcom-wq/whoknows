extends GutTest

## What a held trigger pulls (quantum energy spec §11.4). Pure.

func _def(side: float, kg: float) -> ItemDefinition:
	var d := ItemDefinition.new()
	d.size = Vector3(side, side * 0.5, side * 0.5)
	d.mass_kg = kg
	return d

func test_a_thing_over_0_6_m_or_40_kg_is_too_big():
	assert_false(Suction.too_big(_def(0.4, 10.0)))
	assert_false(Suction.too_big(_def(0.6, 40.0)), "the limits themselves are allowed")
	assert_true(Suction.too_big(_def(0.7, 10.0)))
	assert_true(Suction.too_big(_def(0.4, 41.0)))

func test_a_thing_exactly_at_the_limits_is_allowed_despite_float32():
	assert_false(Suction.too_big(_def(0.6, 40.0)), "a float32 0.6 is still the limit")
	assert_true(Suction.too_big(_def(0.6001 + 0.0002, 10.0)), "the epsilon is not unbounded")

func test_the_cone_is_8_m_long_and_15_degrees_either_side():
	var dir := Vector3(0, 0, -1)
	assert_true(Suction.in_cone(Vector3(0, 0, -4), dir, 0.0), "dead ahead")
	assert_false(Suction.in_cone(Vector3(1.5, 0, -4), dir, 0.0), "tan 15 deg x 4 m is 1.07 m")
	assert_true(Suction.in_cone(Vector3(1.0, 0, -4), dir, 0.0), "inside the cone")
	assert_false(Suction.in_cone(Vector3(0, 0, -8.5), dir, 0.0), "past 8 m")
	assert_false(Suction.in_cone(Vector3(0, 0, 2), dir, 0.0), "behind")

func test_a_big_thing_is_forgiven_by_half_its_side():
	var dir := Vector3(0, 0, -1)
	assert_false(Suction.in_cone(Vector3(1.5, 0, -4), dir, 0.0))
	assert_true(Suction.in_cone(Vector3(1.5, 0, -4), dir, 0.5))

func test_a_light_thing_comes_at_6_m_per_s_squared():
	var f := Suction.pull(Vector3(0, 0, -3), Vector3.ZERO, 1.0)
	assert_almost_eq(f.length(), 6.0, 0.001, "6 N on 1 kg")
	assert_true(f.z < 0.0, "toward the mouth")

func test_a_40_kg_thing_comes_at_3_m_per_s_squared():
	var f := Suction.pull(Vector3(0, 0, -3), Vector3.ZERO, 40.0)
	assert_almost_eq(f.length(), Suction.MAX_FORCE, 0.001)
	assert_almost_eq(f.length() / 40.0, 3.0, 0.001)

func test_the_force_is_never_over_120_n():
	var f := Suction.pull(Vector3(0, 0, -3), Vector3(3, 0, 0), 100.0)
	assert_lte(f.length(), Suction.MAX_FORCE + 0.0001)

func test_sideways_drift_is_damped():
	var f := Suction.pull(Vector3(0, 0, -3), Vector3(2, 0, 0), 1.0)
	assert_true(f.x < 0.0, "opposes the sideways velocity")

func test_it_stops_pulling_at_5_m_per_s():
	var f := Suction.pull(Vector3(0, 0, -3), Vector3(0, 0, -5), 1.0)
	assert_almost_eq(f.z, 0.0, 0.0001, "no more pull toward the mouth at the speed cap")
