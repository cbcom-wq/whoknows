extends GutTest

## The virtual stick (flight controls spec §4.1): where the cursor sits, not
## how fast the mouse moved, is the command.

const H := 720.0

func test_a_centred_stick_asks_for_nothing():
	var s := PilotStick.new()
	assert_eq(s.command(), Vector2.ZERO)
	assert_true(s.is_centred())

func test_inside_the_dead_zone_asks_for_nothing():
	var s := PilotStick.new()
	s.move(Vector2(PilotStick.DEADZONE * H * 0.9, 0.0), H)
	assert_eq(s.command(), Vector2.ZERO)
	assert_true(s.is_centred())

func test_full_deflection_up_is_full_nose_up():
	var s := PilotStick.new()
	s.move(Vector2(0.0, -PilotStick.RADIUS * H), H)
	assert_almost_eq(s.command(), Vector2(1.0, 0.0), Vector2.ONE * 0.0001)
	assert_false(s.is_centred())

func test_full_deflection_left_is_full_yaw_left():
	var s := PilotStick.new()
	s.move(Vector2(-PilotStick.RADIUS * H, 0.0), H)
	assert_almost_eq(s.command(), Vector2(0.0, 1.0), Vector2.ONE * 0.0001)

func test_the_cursor_clamps_at_full_deflection():
	var s := PilotStick.new()
	s.move(Vector2(0.0, 5000.0), H)
	assert_almost_eq(s.offset.length(), PilotStick.RADIUS, 0.00001)
	assert_almost_eq(s.command(), Vector2(-1.0, 0.0), Vector2.ONE * 0.0001)

func test_half_way_out_is_gentler_than_half():
	# The curve aims finely near the centre.
	var s := PilotStick.new()
	var r := PilotStick.DEADZONE + (PilotStick.RADIUS - PilotStick.DEADZONE) * 0.5
	s.move(Vector2(0.0, -r * H), H)
	assert_almost_eq(s.command().x, pow(0.5, PilotStick.CURVE), 0.0001)
	assert_lt(s.command().x, 0.5)

func test_the_same_travel_in_one_event_or_ten_is_the_same_command():
	var once := PilotStick.new()
	once.move(Vector2(40.0, -60.0), H)
	var tenfold := PilotStick.new()
	for i in 10:
		tenfold.move(Vector2(4.0, -6.0), H)
	assert_almost_eq(tenfold.command(), once.command(), Vector2.ONE * 0.0001)

func test_it_feels_the_same_at_any_resolution():
	var small := PilotStick.new()
	small.move(Vector2(0.0, -72.0), 720.0)
	var big := PilotStick.new()
	big.move(Vector2(0.0, -144.0), 1440.0)
	assert_almost_eq(big.command(), small.command(), Vector2.ONE * 0.0001)

func test_the_stick_stays_where_you_leave_it():
	var s := PilotStick.new()
	s.move(Vector2(30.0, 0.0), H)
	var before := s.command()
	s.move(Vector2.ZERO, H)
	assert_eq(s.command(), before)

func test_centre_brings_it_home():
	var s := PilotStick.new()
	s.move(Vector2(50.0, 50.0), H)
	s.centre()
	assert_eq(s.offset, Vector2.ZERO)
	assert_eq(s.command(), Vector2.ZERO)

func test_a_zero_height_viewport_is_ignored():
	var s := PilotStick.new()
	s.move(Vector2(50.0, 50.0), 0.0)
	assert_eq(s.offset, Vector2.ZERO)
