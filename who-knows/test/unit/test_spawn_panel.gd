extends GutTest

## The spawn panel in the real flight scene (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §5, §6.3): F6, a number to spawn a library
## ship ahead of you out of warp, Delete to take one away, and every refusal.
## Arrivals are stepped by hand.

var _root: Node
var _panel: SpawnPanel
var _starter: Ship
var _fleet: Fleet

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_panel = _root.spawn_panel
	_starter = _root.get_node("Ship")
	_fleet = _root.fleet
	await wait_process_frames(2)

func after_each():
	if is_instance_valid(_starter):
		_starter.warp.stage = WarpDrive.Stage.IDLE

func _key(code: Key, echo := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.echo = echo
	_panel._unhandled_key_input(ev)

func _open_and_spawn() -> Ship:
	_key(KEY_F6)
	_key(KEY_1)
	return _newest()

func _newest() -> Ship:
	var ships := _fleet.ships()
	return ships[ships.size() - 1]

## Steps `ship`'s arrival to its stop.
func _land(ship: Ship) -> void:
	var a := WarpArrival.of(ship.exterior)
	if a != null:
		a._physics_process(WarpArrival.DURATION + 0.01)

func _last_line() -> String:
	var lines := _panel.text.split("\n")
	return lines[lines.size() - 1]

func test_f6_opens_and_shuts_it():
	assert_false(_panel.visible)
	_key(KEY_F6)
	assert_true(_panel.visible)
	assert_string_contains(_panel.text, "1  Starter shuttle")
	assert_string_contains(_panel.text, "Del  remove the nearest spawned ship")
	_key(KEY_F6)
	assert_false(_panel.visible)

func test_shut_1_and_delete_do_nothing():
	_key(KEY_1)
	_key(KEY_DELETE)
	assert_eq(_fleet.ships().size(), 1)
	assert_false(_panel.visible)

func test_1_spawns_the_starter_ahead_arriving_out_of_warp():
	var view := _starter.exterior.global_transform
	var expected: Transform3D = SpawnSpot.find(view, [view.origin] as Array[Vector3], Callable(_root, "_rock_near"))
	var ship := _open_and_spawn()
	assert_eq(_fleet.ships().size(), 2)
	assert_true(_fleet.arriving(ship), "it arrives out of warp")
	assert_almost_eq(WarpArrival.of(ship.exterior).along, SpawnSpot.arrival_line(expected), Vector3.ONE * 0.0001,
		"across your view")
	assert_eq(ship.launch_blueprint.ship_name, "Starter shuttle")
	assert_eq(_last_line(), "SPAWNED %s · Starter shuttle · %d m away" % [ship.name,
		roundi(view.origin.distance_to(expected.origin))])
	_land(ship)
	assert_almost_eq(ship.exterior.global_position, expected.origin, Vector3.ONE * 0.01)
	assert_eq(ship.exterior.linear_velocity, Vector3.ZERO, "at rest")
	var nose := -ship.exterior.global_basis.z
	assert_gt(nose.dot((view.origin - ship.exterior.global_position).normalized()), 0.999, "facing you")

func test_spawned_while_cruising_it_lands_ahead_of_where_you_will_be():
	_starter.exterior.linear_velocity = -_starter.exterior.global_basis.z * 120.0
	var view := _starter.exterior.global_transform
	var led := view.translated(_starter.exterior.linear_velocity * WarpArrival.DURATION)
	var expected: Transform3D = SpawnSpot.find(led, [view.origin] as Array[Vector3], Callable(_root, "_rock_near"),
		_starter.exterior.linear_velocity)
	var ship := _open_and_spawn()
	_land(ship)
	assert_almost_eq(ship.exterior.global_position, expected.origin, Vector3.ONE * 0.01)

## Parked dead ahead it would be hit 1.7 s after it landed: at cruise the
## brakes need 25 s.
func test_spawned_while_cruising_it_lands_clear_of_your_path():
	_face_where_straight_ahead_is_clear(120.0)
	var v := -_starter.exterior.global_basis.z * 120.0
	_starter.exterior.linear_velocity = v
	var from := _starter.exterior.global_position
	var ship := _open_and_spawn()
	_land(ship)
	var p := ship.exterior.global_position
	var t := clampf((p - from).dot(v) / v.length_squared(), 0.0, SpawnSpot.PATH_SECONDS)
	assert_gt(p.distance_to(from + v * t), SpawnSpot.CLEAR)

## Turns the starter in 45° steps until, moving at `speed`, nothing but your
## path would stop a ship arriving straight ahead: the scene has a rock ahead.
func _face_where_straight_ahead_is_clear(speed: float) -> void:
	for step in 8:
		_starter.exterior.global_basis = Basis(Vector3.UP, deg_to_rad(45.0 * step))
		var view := _starter.exterior.global_transform
		var led := view.translated(-view.basis.z * speed * WarpArrival.DURATION)
		var spot: Transform3D = SpawnSpot.find(led, [view.origin] as Array[Vector3], Callable(_root, "_rock_near"))
		if (spot.origin - led.origin).angle_to(-view.basis.z) < 0.01:
			return
	fail_test("no clear way ahead in the scene")

func test_on_a_spacewalk_it_lands_ahead_of_your_view():
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var out := _starter.exterior.global_position + _starter.exterior.global_basis.x * 40.0
	avatar.enter_suit(_root.get_node("Outside"), Transform3D(Basis(Vector3.UP, 1.2), out), Vector3.ZERO, _starter.exterior)
	var view := avatar.camera.global_transform
	var expected: Transform3D = SpawnSpot.find(view, [_starter.exterior.global_position] as Array[Vector3],
		Callable(_root, "_rock_near"))
	var ship := _open_and_spawn()
	_land(ship)
	assert_almost_eq(ship.exterior.global_position, expected.origin, Vector3.ONE * 0.01)

func test_a_held_1_spawns_one_ship():
	_open_and_spawn()
	_key(KEY_1, true)
	_key(KEY_1, true)
	assert_eq(_fleet.ships().size(), 2)

func test_a_second_spawn_waits_for_the_first_to_arrive():
	var first := _open_and_spawn()
	_key(KEY_1)
	assert_eq(_fleet.ships().size(), 2)
	assert_eq(_last_line(), "A SHIP IS ARRIVING")
	_land(first)
	_key(KEY_1)
	assert_eq(_fleet.ships().size(), 3)

func test_f8_skips_it_while_it_arrives_and_boards_it_after():
	var ship := _open_and_spawn()
	assert_false(_root.board_nearest())
	_land(ship)
	assert_true(_root.board_nearest())
	assert_same(_root.aboard, ship)

func test_refused_when_the_fleet_is_full():
	_fleet.max_ships = 1
	_open_and_spawn()
	assert_eq(_fleet.ships().size(), 1)
	assert_eq(_last_line(), "THE FLEET IS FULL")

## Bases hold slots too (habitat modules spec §9.3, §6.5): with none free,
## F6 says so, and nothing crashes.
func test_refused_when_no_berth_is_free():
	while _fleet.slots.free_count() > 0:
		_fleet.slots.claim()
	_open_and_spawn()
	assert_eq(_fleet.ships().size(), 1)
	assert_eq(_last_line(), "NO BERTH FREE")

func test_refused_during_a_warp():
	_starter.warp.stage = WarpDrive.Stage.SPOOLING
	_open_and_spawn()
	assert_eq(_fleet.ships().size(), 1)
	assert_eq(_last_line(), "WARP ENGAGED")

func test_delete_removes_the_nearest_spawned_ship():
	var ship := _open_and_spawn()
	_land(ship)
	var ship_name := ship.name
	_key(KEY_DELETE)
	assert_eq(_fleet.ships().size(), 1)
	assert_eq(_last_line(), "REMOVED %s · Starter shuttle" % ship_name)

func test_delete_never_takes_the_starter():
	_key(KEY_F6)
	_key(KEY_DELETE)
	assert_eq(_fleet.ships().size(), 1)
	assert_eq(_last_line(), "NO SPAWNED SHIP")

func test_delete_skips_a_ship_still_arriving():
	_open_and_spawn()
	_key(KEY_DELETE)
	assert_eq(_fleet.ships().size(), 2)
	assert_eq(_last_line(), "NO SPAWNED SHIP")

func test_on_a_spacewalk_tied_to_the_only_spawned_ship_delete_says_so():
	var ship := _open_and_spawn()
	_land(ship)
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var beside := ship.exterior.global_position + ship.exterior.global_basis.x * 25.0
	avatar.enter_suit(_root.get_node("Outside"), Transform3D(Basis.IDENTITY, beside), Vector3.ZERO, _starter.exterior)
	_root.suit_tie.check()
	assert_same(_root.aboard, ship, "your suit is its")
	_key(KEY_DELETE)
	assert_eq(_fleet.ships().size(), 2)
	assert_eq(_last_line(), "YOU ARE ABOARD IT")

## Seen at the renders: its RCS puffed all the way in, a dotted trail along its
## line. Nothing fires while it arrives, as nothing does during a warp.
func test_its_thrusters_rest_while_it_arrives():
	var ship := _open_and_spawn()
	WarpArrival.of(ship.exterior).set_physics_process(false)
	var fc := ship.flight_computer
	fc.set_pilot_input(Vector3(1, 0, 0), Vector3.ZERO, false)
	await wait_physics_frames(2)
	assert_eq(fc.commanded_force_local, Vector3.ZERO, "no thrust while it arrives")
	assert_eq(fc.commanded_torque_local, Vector3.ZERO)
	_land(ship)
	await wait_physics_frames(2)
	assert_ne(fc.commanded_force_local, Vector3.ZERO, "its own again once it has arrived")
	fc.set_pilot_input(Vector3.ZERO, Vector3.ZERO, false)

func test_the_save_waits_for_an_arrival():
	var ship := _open_and_spawn()
	assert_eq(_root._fleet_busy(), "a ship arriving")
	_land(ship)
	assert_eq(_root._fleet_busy(), "")
