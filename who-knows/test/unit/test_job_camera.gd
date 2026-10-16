extends GutTest

## A seat's job may own the camera and the mouse (ship weapons spec §7.2): the
## bridge fixture's crew station, given a job with a camera of its own.

const BRIDGE := "res://test/fixtures/bridge/bridge.json"

class CameraJob extends SeatJob:
	var cam := Camera3D.new()
	func view_camera() -> Camera3D:
		return cam
	func takes_mouse() -> bool:
		return true

var _root: Node
var _ship: Ship
var _director: CameraDirector

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.starter_ship = BRIDGE
	add_child_autofree(_root)
	await wait_process_frames(2)
	_ship = _root.aboard
	_director = _root.get_node("CameraDirector")

func test_a_job_with_a_camera_is_seen_through():
	var station := _ship.seat_at(Vector3i(2, 0, -4))
	var job := CameraJob.new()
	station.job = job
	station.add_child(job)
	_ship.exterior.add_child(job.cam)
	_director.sit(station)
	await wait_for_signal(_director.transition_finished, 3)
	assert_true(job.cam.current, "the job's camera")
	_director.look(Vector2(200, 0))
	assert_eq(_director.camera().transform, Transform3D.IDENTITY, "the mouse is the job's")
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)
	assert_true(_director.camera().current, "standing, your own eyes again")
