extends GutTest

## A position in the universe (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §4.1): whole metres as 64-bit ints plus a fraction, so it never shimmers
## however far out it is.

func test_a_step_carries_whole_metres_and_keeps_the_fraction():
	var u := UniversePoint.at(0, 0, 0).plus(Vector3(2.5, -0.25, 1000.75))
	assert_eq([u.x, u.y, u.z], [2, -1, 1000])
	assert_almost_eq(u.fx, 0.5, 1e-9)
	assert_almost_eq(u.fy, 0.75, 1e-9)
	assert_almost_eq(u.fz, 0.75, 1e-9)

func test_the_step_between_two_points_is_what_was_added():
	var a := UniversePoint.at(123456789012, -5, 7).plus(Vector3(0.25, 0.5, 0.125))
	var step := Vector3(1234.5, -987.25, 0.125)
	assert_eq(a.plus(step).minus(a), step)

func test_a_millimetre_still_counts_a_billion_kilometres_out():
	var far := UniversePoint.at(1_000_000_000_000, 0, 0)
	assert_almost_eq(far.plus(Vector3(0.001, 0, 0)).minus(far).x, 0.001, 1e-6)

func test_points_compare_by_position():
	var a := UniversePoint.at(3000, -2000, 0)
	assert_true(a.is_equal_approx(UniversePoint.at(2999, -2000, 0).plus(Vector3(1, 0, 0))))
	assert_false(a.is_equal_approx(UniversePoint.at(3000, -2000, 1)))

func test_a_fraction_never_reaches_a_whole_metre():
	var u := UniversePoint.at(0, 0, 0).plus(Vector3(0.9999999, 0, 0)).plus(Vector3(0.0000002, 0, 0))
	assert_eq(u.x, 1)
	assert_true(u.fx >= 0.0 and u.fx < 1.0)
