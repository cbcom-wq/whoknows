extends GutTest

## The bridge fixture's seats in the real flight scene
## (docs/superpowers/specs/2026-10-09-ship-bridge-design.md §3.2-§3.4): one
## seat node per chair and station, sitting in each, only the helm piloting.

const BRIDGE := "res://test/fixtures/bridge/bridge.json"

var _root: Node
var _ship: Ship
var _director: CameraDirector
var _avatar: Avatar

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.starter_ship = BRIDGE
	add_child_autofree(_root)
	await wait_process_frames(2)
	_ship = _root.aboard
	_director = _root.get_node("CameraDirector")
	_avatar = _root.get_tree().get_first_node_in_group(Avatar.GROUP)

func after_each():
	for a in [&"move_forward", &"move_back", &"strafe_left", &"strafe_right"]:
		Input.action_release(a)

func test_a_seat_for_the_helm_and_every_chair():
	var seats := _ship.seats()
	assert_eq(seats.size(), 4)
	assert_same(seats[0], _ship.seat)
	assert_eq(_ship.seat.cell, Vector3i(0, 0, -4))
	assert_true(_ship.seat_at(Vector3i(0, 0, -2)) is CaptainChair)
	assert_true(_ship.seat_at(Vector3i(-2, 0, -4)) is CrewStation)
	assert_true(_ship.seat_at(Vector3i(2, 0, -4)) is CrewStation)
	assert_null(_ship.seat_at(Vector3i(1, 0, -3)))

func test_each_seat_stands_where_its_chair_is_drawn():
	var layout := _ship.interior_builder.layout()
	for s in _ship.seats():
		var f := InteriorDressing.fixture_frame(layout, s.cell)
		assert_almost_eq(s.transform.origin, f.origin, Vector3.ONE * 0.001, "seat at %s" % s.cell)

func test_a_rebuild_keeps_one_seat_each():
	_ship.set_grid(_ship.grid, false)
	await wait_process_frames(2)
	assert_eq(_ship.seats().size(), 4)
	assert_eq(_ship.interior.find_children("Seat_*", "", false, false).size(), 3, "the old seats are gone")

func _sit(s: Seat) -> void:
	_director.sit(s)
	await wait_for_signal(_director.transition_finished, 3)

func _stand() -> void:
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)

func test_sitting_at_a_station_is_not_piloting():
	watch_signals(_director)
	await _sit(_ship.seat_at(Vector3i(-2, 0, -4)))
	assert_true(_director.is_seated)
	assert_false(_director.piloting())
	assert_signal_not_emitted(_director, "piloting_changed")
	assert_false(_ship.pilot.seated, "the controls stay with nobody")
	assert_same(_director.seat(), _ship.seat_at(Vector3i(-2, 0, -4)))

func test_the_helm_still_pilots():
	watch_signals(_director)
	await _sit(_ship.seat)
	assert_true(_director.piloting())
	assert_signal_emitted_with_parameters(_director, "piloting_changed", [true])
	assert_true(_ship.pilot.seated)

func test_a_seat_that_does_not_fly_moves_nothing():
	await _sit(_ship.seat_at(Vector3i(0, 0, -2)))
	var at := _ship.exterior.global_position
	Input.action_press(&"move_forward")
	await wait_physics_frames(60)
	Input.action_release(&"move_forward")
	assert_almost_eq(_ship.exterior.global_position, at, Vector3.ONE * 0.05)

func test_you_look_round_within_limits():
	await _sit(_ship.seat_at(Vector3i(0, 0, -2)))
	var cam := _director.camera()
	_director.look(Vector2(-100000, 0))
	assert_almost_eq(cam.transform.basis.get_euler().y, CameraDirector.SEAT_LOOK_YAW, 0.01)
	_director.look(Vector2(0, -100000))
	assert_almost_eq(cam.transform.basis.get_euler().x, CameraDirector.SEAT_LOOK_PITCH, 0.01)

func test_looking_does_nothing_at_the_helm():
	await _sit(_ship.seat)
	var before := _director.camera().transform
	_director.look(Vector2(300, 200))
	assert_eq(_director.camera().transform, before)

func test_v_does_nothing_at_a_station():
	await _sit(_ship.seat_at(Vector3i(2, 0, -4)))
	_director.cycle_view()
	assert_eq(_director.view, CameraDirector.View.COCKPIT)

func test_you_stand_up_from_a_station():
	var s := _ship.seat_at(Vector3i(2, 0, -4))
	await _sit(s)
	await _stand()
	assert_false(_director.is_seated)
	assert_null(_director.seat())
	var local := s.global_transform.affine_inverse() * _avatar.global_position
	assert_almost_eq(local, Seat.STAND_SPOTS[0], Vector3.ONE * 0.05)

func test_f8_from_a_station_boards_the_other_helm():
	await _sit(_ship.seat_at(Vector3i(-2, 0, -4)))
	var other: Ship = _root.fleet.spawn(ShipLibrary.load_from_dir().grid(&"starter"),
		Transform3D(_ship.exterior.global_basis, _ship.exterior.global_position + Vector3(300, 0, 0)))
	await wait_physics_frames(2)
	assert_true(_root.board_nearest())
	assert_same(_director.seat(), other.seat)
	assert_true(_director.piloting())

## Standing from the captain's chair puts you on the bridge floor behind the
## ramp, never balanced at dais height on its edge to drop off it.
func test_standing_from_the_captain_puts_you_on_the_floor_behind_the_ramp():
	var chair := _ship.seat_at(Vector3i(0, 0, -2))
	await _sit(chair)
	_director.stand()
	var floor_at := InteriorDressing.floor_frame(_ship.interior_builder.layout(), chair.cell)
	var local := floor_at.affine_inverse() * (_ship.interior.global_transform.affine_inverse() * _avatar.global_position)
	assert_almost_eq(local.y, 0.0, 0.05, "on the floor, not at the dais's height")
	assert_gt(local.z, InteriorProps.BAY * 0.5 + 0.3, "clear of the ramp's foot")