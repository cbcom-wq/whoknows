extends GutTest

## The way home on a spacewalk (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §8.3): a ring over your airlock, clamped to
## the screen edge when it is off-screen.

var _marker: AirlockMarker
var _cam: Camera3D

func before_each():
	_cam = Camera3D.new()
	add_child_autofree(_cam)
	_cam.current = true
	_marker = AirlockMarker.new()
	_marker.size = Vector2(1280, 720)
	add_child_autofree(_marker)

func _telemetry(beacon: Vector3, has := true) -> VehicleTelemetry:
	var t := VehicleTelemetry.from_state(Basis.IDENTITY, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, true, false, 8.0)
	t.has_beacon = has
	t.beacon = beacon
	return t

func test_it_shows_the_airlock_ahead_on_screen():
	_marker.render(_telemetry(Vector3(0, 0, -20)))
	assert_true(_marker.shown)
	assert_eq(_marker.mode, VelocityMarker.Mode.ON_FRAME)
	assert_almost_eq(_marker.distance, 20.0, 0.01)

func test_behind_you_it_waits_at_the_edge():
	_marker.render(_telemetry(Vector3(3, 0, 20)))
	assert_eq(_marker.mode, VelocityMarker.Mode.CLAMPED_BEHIND)

func test_without_a_beacon_it_hides():
	_marker.render(_telemetry(Vector3.ZERO, false))
	assert_false(_marker.shown)
	_marker.render(null)
	assert_false(_marker.shown)
