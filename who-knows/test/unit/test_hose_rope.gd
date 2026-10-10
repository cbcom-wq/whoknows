extends GutTest

## The hose's line as a pure rope (quantum energy spec §11.3): 40 segments of
## 30 m, verlet, no gravity, damped, pinned at both ends.

const DT := 1.0 / 60.0

func test_it_has_41_points_for_40_segments_of_30_m():
	var rope := HoseRope.new()
	assert_eq(HoseRope.SEGMENTS, 40)
	assert_eq(rope.points.size(), 41)
	assert_almost_eq(HoseRope.segment_length() * HoseRope.SEGMENTS, 30.0, 0.0001)

func test_reset_lays_it_straight_between_the_ends():
	var rope := HoseRope.new()
	rope.reset(Vector3.ZERO, Vector3(20, 0, 0))
	assert_eq(rope.points[0], Vector3.ZERO)
	assert_eq(rope.points[40], Vector3(20, 0, 0))
	assert_almost_eq(rope.points[20].x, 10.0, 0.0001)

func test_a_step_pins_both_ends():
	var rope := HoseRope.new()
	rope.reset(Vector3.ZERO, Vector3(10, 0, 0))
	rope.step(Vector3(1, 2, 3), Vector3(9, 4, 0), DT)
	assert_eq(rope.points[0], Vector3(1, 2, 3))
	assert_eq(rope.points[40], Vector3(9, 4, 0))

func test_it_never_stretches_past_a_segment_once_settled():
	var rope := HoseRope.new()
	rope.reset(Vector3.ZERO, Vector3(10, 0, 0))
	for i in 600:
		rope.step(Vector3.ZERO, Vector3(10, 6, 0), DT)
	var rest := HoseRope.segment_length()
	for i in HoseRope.SEGMENTS:
		assert_lte(rope.points[i].distance_to(rope.points[i + 1]), rest * 1.05, "segment %d" % i)

## Bounds measured from a Godot run (after 600 taut ticks: max |y| 0.367801 m,
## max |z| 0, max link 1.000388 x rest), each set to about 2x the measured value.
## |z| measured exactly 0, so 2x would be 0; the 0.001 m floor is the old test's.
func test_a_bent_line_is_drawn_taut_when_the_ends_are_30_m_apart():
	var rope := HoseRope.new()
	rope.reset(Vector3.ZERO, Vector3(10, 6, 0))
	for i in 120:
		rope.step(Vector3.ZERO, Vector3(10, 6, 0), DT)
	for i in 600:
		rope.step(Vector3.ZERO, Vector3(30, 0, 0), DT)
	for i in rope.points.size():
		var p := rope.points[i]
		assert_lte(absf(p.y), 0.75, "point %d is %.3f m off the axis" % [i, p.y])
		assert_lte(absf(p.z), 0.001, "point %d is off the plane" % i)
	for i in HoseRope.SEGMENTS:
		assert_lte(rope.points[i].distance_to(rope.points[i + 1]), HoseRope.segment_length() * 2.0, "link %d" % i)
	assert_eq(rope.points[0], Vector3.ZERO)
	assert_eq(rope.points[40], Vector3(30, 0, 0))

func test_a_line_at_rest_stays_put_when_stepped():
	var rope := HoseRope.new()
	rope.reset(Vector3.ZERO, Vector3(5, 0, 0))
	# duplicate(): a plain assignment aliases the live array, so the check would compare it with itself.
	var before := rope.points.duplicate()
	rope.step(Vector3.ZERO, Vector3(5, 0, 0), DT)
	for i in before.size():
		assert_almost_eq(rope.points[i].distance_to(before[i]), 0.0, 0.000001, "point %d moved" % i)

func test_there_is_no_gravity():
	var rope := HoseRope.new()
	rope.reset(Vector3.ZERO, Vector3(5, 0, 0))
	for i in 300:
		rope.step(Vector3.ZERO, Vector3(5, 0, 0), DT)
	for p in rope.points:
		assert_almost_eq(p.y, 0.0, 0.0001, "nothing pulls it down")

func test_the_same_motion_gives_the_same_line():
	var a := HoseRope.new()
	var b := HoseRope.new()
	for rope in [a, b]:
		rope.reset(Vector3.ZERO, Vector3(8, 0, 0))
		for i in 90:
			rope.step(Vector3.ZERO, Vector3(8.0 - i * 0.05, i * 0.04, 0), DT)
	assert_eq(a.points, b.points)

func test_paid_out_is_the_straight_distance_up_to_the_length():
	assert_almost_eq(HoseRope.paid_out(Vector3.ZERO, Vector3(12, 0, 0)), 12.0, 0.0001)
	assert_almost_eq(HoseRope.paid_out(Vector3.ZERO, Vector3(40, 0, 0)), 30.0, 0.0001)
