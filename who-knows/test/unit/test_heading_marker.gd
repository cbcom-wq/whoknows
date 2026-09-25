extends GutTest

## The held heading on the HUD (flight controls spec §8).

var _cam: Camera3D
var _marker: HeadingMarker

func before_each():
	_cam = Camera3D.new()
	add_child_autofree(_cam)
	_cam.current = true
	_marker = HeadingMarker.new()
	_marker.camera_path = _cam.get_path()
	add_child_autofree(_marker)
	_marker.size = Vector2(1280.0, 720.0)

func _held(direction: Vector3) -> VehicleTelemetry:
	var t := VehicleTelemetry.new()
	t.heading_hold = true
	t.heading = direction
	return t

func test_without_a_hold_nothing_is_drawn():
	_marker.render(VehicleTelemetry.new())
	assert_false(_marker.armed)
	assert_eq(_marker.mode, VelocityMarker.Mode.HIDDEN)

func test_a_heading_dead_ahead_sits_in_the_middle():
	_marker.render(_held(Vector3.FORWARD))
	assert_eq(_marker.mode, VelocityMarker.Mode.ON_FRAME)
	var view := _cam.get_viewport().get_visible_rect().size
	assert_almost_eq(_marker.marker_at, view * 0.5, Vector2.ONE * 1.0)

func test_a_heading_behind_is_pinned_to_the_edge():
	_marker.render(_held(Vector3.BACK.rotated(Vector3.UP, 0.3)))
	assert_eq(_marker.mode, VelocityMarker.Mode.CLAMPED_BEHIND)

func test_only_the_live_camera_draws():
	_cam.current = false
	_marker.render(_held(Vector3.FORWARD))
	assert_false(_marker.armed)

func test_no_vehicle_draws_nothing():
	_marker.render(null)
	assert_false(_marker.armed)
