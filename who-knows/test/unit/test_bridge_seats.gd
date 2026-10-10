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
