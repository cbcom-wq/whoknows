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

func test_a_taut_line_is_straight():
	var rope := HoseRope.new()
	rope.reset(Vector3.ZERO, Vector3(30, 0, 0))
	for i in 60:
		rope.step(Vector3.ZERO, Vector3(30, 0, 0), DT)
	for p in rope.points:
		assert_almost_eq(p.y, 0.0, 0.001)
		assert_almost_eq(p.z, 0.0, 0.001)

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
