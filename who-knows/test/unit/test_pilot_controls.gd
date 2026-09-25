extends GutTest

## The pilot's hands (flight controls spec §4, §7), in the real flight scene.
## handle() is driven directly: a headless run cannot capture the mouse.

var _root: Node
var _pilot: PilotControls
var _fc: FlightComputer
var _hull: RigidBody3D
var _interior: Node3D

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_pilot = _root.get_node("Ship/PilotControls")
	_fc = _root.get_node("Ship/FlightComputer")
	_hull = _root.get_node("Ship/Exterior")
	_interior = _root.get_node("Ship/Interior")
	_pilot.set_seated(true)

func after_each():
	for action in [&"pitch_up", &"roll_left"]:
		Input.action_release(action)

func _action(action: StringName, pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	return ev

func _motion(relative: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	return ev

func test_sitting_down_seats_the_controls():
	_pilot.set_seated(false)
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_true(_pilot.seated)

func test_while_seated_your_hands_do_nothing():
	# RMB and LMB fly the ship while you sit (spec §4): Grasp must be off.
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_false(avatar.grasp.enabled)

func test_the_mouse_moves_the_stick():
	_pilot.handle(_motion(Vector2(0.0, -40.0)))
	assert_lt(_pilot.stick.offset.y, 0.0)
	assert_gt(_pilot.stick.command().x, 0.0, "up is nose up")

func test_standing_up_centres_the_stick():
	_pilot.handle(_motion(Vector2(60.0, 0.0)))
	_pilot.set_seated(false)
	assert_eq(_pilot.stick.offset, Vector2.ZERO)

func test_point_mode_lets_go_of_the_stick_and_moves_a_pointer():
	_pilot.handle(_motion(Vector2(60.0, 0.0)))
	_pilot.handle(_action(&"point_mode", true))
	assert_true(_pilot.pointing)
	assert_eq(_pilot.stick.offset, Vector2.ZERO, "the stick lets go")
	_pilot.handle(_motion(Vector2(30.0, 0.0)))
	assert_gt(_pilot.pointer.x, 0.0)
	assert_eq(_pilot.stick.offset, Vector2.ZERO, "the mouse moves the pointer, not the stick")
	_pilot.handle(_action(&"point_mode", false))
	assert_false(_pilot.pointing)
	assert_eq(_pilot.stick.offset, Vector2.ZERO, "back to a centred stick")

func test_a_click_in_point_mode_sets_the_heading():
	_pilot.handle(_action(&"point_mode", true))
	_pilot.handle(_action(&"set_heading", true))
	assert_true(_fc.heading_hold)

func test_a_click_outside_point_mode_does_nothing():
	_pilot.handle(_action(&"set_heading", true))
	assert_false(_fc.heading_hold)

func test_the_pointer_at_the_centre_is_the_nose():
	# A camera aboard, facing the way the seat does: the centre of view is the
	# hull's nose, wherever the hull points.
	var cam := Camera3D.new()
	_interior.add_child(cam)
	_hull.global_basis = Basis(Vector3.UP, deg_to_rad(90.0))
	var dir := _pilot.pointer_direction(cam)
	assert_almost_eq(dir, _hull.global_basis * Vector3.FORWARD, Vector3.ONE * 0.001)
	cam.free()

func test_the_pointer_above_centre_looks_above_the_nose():
	var cam := Camera3D.new()
	_interior.add_child(cam)
	_pilot.pointer = Vector2(0.0, -0.2)
	var dir := _pilot.pointer_direction(cam)
	assert_gt(dir.dot(_hull.global_basis * Vector3.UP), 0.1)
	cam.free()

func test_outside_the_pointer_is_the_cameras_own_ray():
	var cam := Camera3D.new()
	_hull.add_child(cam)
	_hull.global_basis = Basis(Vector3.UP, deg_to_rad(90.0))
	var centre := cam.get_viewport().get_visible_rect().size * 0.5
	assert_almost_eq(_pilot.pointer_direction(cam), cam.project_ray_normal(centre),
		Vector3.ONE * 0.001)
	cam.free()

func test_flying_by_hand_takes_the_ship_back_from_a_hold():
	_fc.set_heading(Vector3.LEFT)
	Input.action_press(&"pitch_up")
	_pilot._process(0.016)
	assert_false(_fc.heading_hold)

func test_moving_the_stick_out_takes_the_ship_back_too():
	_fc.set_heading(Vector3.LEFT)
	_pilot.handle(_motion(Vector2(0.0, -100.0)))
	_pilot._process(0.016)
	assert_false(_fc.heading_hold)

func test_rolling_keeps_the_hold():
	_fc.set_heading(Vector3.LEFT)
	Input.action_press(&"roll_left")
	_pilot._process(0.016)
	assert_true(_fc.heading_hold)

func test_c_locks_the_speed():
	_hull.linear_velocity = Vector3(0.0, 0.0, -20.0)
	_pilot.handle(_action(&"speed_lock", true))
	assert_true(_fc.speed_locked)

func test_z_toggles_assist_and_drops_the_lock():
	_pilot.handle(_action(&"speed_lock", true))
	_pilot.handle(_action(&"toggle_assist", true))
	assert_false(_fc.assist_enabled)
	assert_false(_fc.speed_locked)

func test_nothing_happens_standing_up():
	_pilot.set_seated(false)
	_pilot.handle(_action(&"speed_lock", true))
	assert_false(_fc.speed_locked)

func test_the_hud_sees_the_stick_and_the_pointer():
	_pilot.handle(_motion(Vector2(30.0, 0.0)))
	var t := _pilot.build_telemetry()
	assert_eq(t.stick, _pilot.stick.offset)
	assert_almost_eq(t.stick_radius, PilotStick.RADIUS, 0.0001)
	assert_almost_eq(t.stick_deadzone, PilotStick.DEADZONE, 0.0001)
	assert_false(t.pointing)
	assert_almost_eq(t.cruise_limit, FlightComputer.CRUISE_LIMIT_MPS, 0.001,
		"and the flight computer's own readings")
