extends GutTest

## The canopy SubViewport's authored size, so the numbers below are the ones
## the real cockpit will produce.
const VP := Vector2(1024.0, 512.0)
const CENTRE := Vector2(512.0, 256.0)

func test_hidden_below_the_speed_deadband():
	# At rest the velocity direction is numerical noise, so an unguarded ring
	# strobes around the frame.
	var s := VelocityMarker.resolve(0.5, false, Vector2(600.0, 300.0), VP)
	assert_eq(s["mode"], VelocityMarker.Mode.HIDDEN, "under 1 m/s stays hidden")

func test_visible_at_the_deadband_threshold():
	var s := VelocityMarker.resolve(1.0, false, Vector2(600.0, 300.0), VP)
	assert_eq(s["mode"], VelocityMarker.Mode.ON_FRAME, "exactly 1 m/s shows")

func test_on_frame_passes_the_projected_point_through_untouched():
	var pos := Vector2(600.0, 300.0)
	var s := VelocityMarker.resolve(50.0, false, pos, VP)
	assert_eq(s["mode"], VelocityMarker.Mode.ON_FRAME)
	assert_eq(s["position"], pos, "no adjustment inside the frame")

func test_ahead_but_off_frame_clamps_to_the_inset_edge():
	var s := VelocityMarker.resolve(50.0, false, Vector2(2000.0, 256.0), VP)
	assert_eq(s["mode"], VelocityMarker.Mode.CLAMPED_AHEAD)
	assert_almost_eq(
		s["position"].x, VP.x - VelocityMarker.EDGE_MARGIN_PX, 0.001,
		"pinned one margin in from the right edge"
	)
	assert_almost_eq(s["position"].y, CENTRE.y, 0.001, "still on the centreline")

func test_behind_clamps_to_the_opposite_edge():
	# unproject_position mirrors points that are behind the camera, so the
	# raw screen position points the wrong way and must be negated about
	# centre before clamping.
	var s := VelocityMarker.resolve(50.0, true, Vector2(600.0, 256.0), VP)
	assert_eq(s["mode"], VelocityMarker.Mode.CLAMPED_BEHIND)
	assert_almost_eq(
		s["position"].x, VelocityMarker.EDGE_MARGIN_PX, 0.001,
		"a point mirrored to the right of centre belongs on the left edge"
	)

func test_behind_clamps_on_the_vertical_axis_too():
	var s := VelocityMarker.resolve(50.0, true, Vector2(512.0, 100.0), VP)
	assert_eq(s["mode"], VelocityMarker.Mode.CLAMPED_BEHIND)
	assert_almost_eq(
		s["position"].y, VP.y - VelocityMarker.EDGE_MARGIN_PX, 0.001,
		"mirrored above centre belongs on the bottom edge"
	)

func test_a_point_exactly_at_centre_while_behind_does_not_divide_by_zero():
	# Flying dead astern: the mirrored point lands on centre and has no
	# direction. Must pick one rather than produce NAN.
	var s := VelocityMarker.resolve(50.0, true, CENTRE, VP)
	assert_eq(s["mode"], VelocityMarker.Mode.CLAMPED_BEHIND)
	assert_false(is_nan(s["position"].x), "x is a real number")
	assert_false(is_nan(s["position"].y), "y is a real number")

func test_clamped_points_land_on_the_inset_rectangle():
	# Whatever direction it is pushed, a clamped marker sits exactly one
	# margin inside the frame on at least one axis.
	for pos in [Vector2(3000.0, 3000.0), Vector2(-500.0, 20.0), Vector2(700.0, -900.0)]:
		var s := VelocityMarker.resolve(50.0, false, pos, VP)
		assert_eq(s["mode"], VelocityMarker.Mode.CLAMPED_AHEAD, "off-frame clamps")
		var m: float = VelocityMarker.EDGE_MARGIN_PX
		var on_x: bool = is_equal_approx(s["position"].x, m) \
			or is_equal_approx(s["position"].x, VP.x - m)
		var on_y: bool = is_equal_approx(s["position"].y, m) \
			or is_equal_approx(s["position"].y, VP.y - m)
		assert_true(on_x or on_y, "sits on the inset boundary for %s" % pos)
