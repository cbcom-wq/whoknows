extends GutTest

## The mouse and keys at a computer station (computer mode spec §3.3, §4.4).

var _root: Node
var _ship: Ship
var _director: CameraDirector
var _input: ComputerModeInput

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_director = _root.get_node("CameraDirector")
	_input = _root.computer_input
	_station().interact(_root.get_node("Ship/Interior/Avatar"))
	await wait_seconds(CameraDirector.SIT_DURATION + 0.3)

func _station() -> ComputerStation:
	return _ship.interior_builder.computers()[0].station

func _map() -> MapPage:
	return _station().computer.pages[0] as MapPage

func _button(index: MouseButton, pressed: bool, at := Vector2(400, 300)) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = index
	ev.pressed = pressed
	ev.position = at
	_input._unhandled_input(ev)

func _move(to: Vector2, by: Vector2, mask := MOUSE_BUTTON_MASK_LEFT) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = to
	ev.relative = by
	ev.button_mask = mask
	_input._unhandled_input(ev)

func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	_input._unhandled_input(ev)

func test_the_wheel_zooms():
	var before := _map().scale_m
	_button(MOUSE_BUTTON_WHEEL_UP, true)
	assert_almost_eq(_map().scale_m, before / 1.3, 0.01)
	_button(MOUSE_BUTTON_WHEEL_DOWN, true)
	assert_almost_eq(_map().scale_m, before, 0.01)

func test_a_drag_orbits_and_picks_nothing():
	var before := _map().selected
	_button(MOUSE_BUTTON_LEFT, true, Vector2(400, 300))
	_move(Vector2(460, 320), Vector2(60, 20))
	_button(MOUSE_BUTTON_LEFT, false, Vector2(460, 320))
	assert_almost_eq(_station().computer.spin, -60.0 * ComputerModeInput.SPIN_PER_PIXEL, 0.0001)
	assert_almost_eq(_station().elevation, InteriorProps.HOLO_STATION_ELEVATION + 20.0 * 0.3, 0.0001)
	assert_eq(_map().selected, before)

func test_a_click_on_a_mark_selects_it():
	await wait_process_frames(3)
	assert_gt(_map().placed_marks.size(), 0, "the start's rocks are on the map")
	var m := {}
	for mark: Dictionary in _map().placed_marks:
		if mark["id"] != _map().selected:
			m = mark
	assert_false(m.is_empty(), "a mark that is not already selected")
	assert_ne(_map().selected, m["id"], "so the click has something to change")
	var at := _director.camera().unproject_position(_station().computer.holo.marks_to_global(m["position"]))
	_button(MOUSE_BUTTON_LEFT, true, at)
	_button(MOUSE_BUTTON_LEFT, false, at)
	assert_eq(_map().selected, m["id"])

func test_motion_with_the_button_up_is_not_a_drag():
	var before := _map().selected
	_button(MOUSE_BUTTON_LEFT, true, Vector2(400, 300))
	_move(Vector2(460, 320), Vector2(60, 20), 0)
	assert_eq(_station().computer.spin, 0.0, "a lost release must not leave the holo orbiting")
	assert_eq(_map().selected, before)

func test_r_recentres_tab_turns_the_page_and_enter_acts():
	_station().computer.spin = 1.0
	_key(KEY_R)
	assert_eq(_station().computer.spin, 0.0)
	assert_ne(_map().selected, &"", "something is selected for the button to act on")
	assert_eq(_ship.sensors.course, &"", "and no course is set yet")
	_key(KEY_ENTER)
	assert_eq(_ship.sensors.course, _map().selected, "Enter is the big button")
	_key(KEY_TAB)
	assert_eq(_station().computer.page_index, 1)

func test_nothing_happens_once_you_have_left():
	_director.leave_station()
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)
	var before := _map().scale_m
	_button(MOUSE_BUTTON_WHEEL_UP, true)
	assert_eq(_map().scale_m, before)
