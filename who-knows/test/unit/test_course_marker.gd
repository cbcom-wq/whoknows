extends GutTest

## The course on the HUD (bridge computer spec §6.1): a diamond on a big rock,
## a caret for a ping, a ring round a region, pinned to the edge off screen,
## fading out on arrival.

class FakeSource extends RefCounted:
	var list: Array[Contact] = []
	func contacts(_focus: UniversePoint, _range_m: float, _time: float) -> Array[Contact]:
		return list
	func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
		for c in list:
			if c.id == id:
				return c
		return null

var _cam: Camera3D
var _universe: Universe
var _sensors: ShipSensors
var _source: FakeSource
var _marker: CourseMarker

func before_each():
	_cam = Camera3D.new()
	_cam.name = "Cam"
	add_child_autofree(_cam)
	_cam.current = true
	_universe = Universe.new()
	add_child_autofree(_universe)
	_universe.set_focus(_cam)
	_sensors = ShipSensors.new()
	add_child_autofree(_sensors)
	_sensors.universe = _universe
	_source = FakeSource.new()
	_sensors.add_source(_source)
	_marker = CourseMarker.new()
	_marker.size = Vector2(1280, 720)
	add_child_autofree(_marker)
	_marker.set_camera(_cam)
	_marker.bind(_sensors)

func _telemetry() -> VehicleTelemetry:
	return VehicleTelemetry.from_state(Basis.IDENTITY, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, true, false, 8.0)

func _course(precision: StringName, at: Vector3, radius := 0.0, km := 0) -> void:
	var c := Contact.new()
	c.id = &"c"
	c.kind = &"rock" if precision == Contact.EXACT else &"salvage"
	c.label = "ROCK" if precision == Contact.EXACT else "SALVAGE"
	c.point = _universe.to_universe(at)
	c.precision = precision
	c.radius = radius
	c.km = km
	_source.list = [c]
	_sensors.set_course(&"c")

func test_with_no_course_it_hides():
	_marker.render(_telemetry())
	assert_false(_marker.shown)

func test_a_course_to_a_rock_ahead_is_a_diamond_with_its_distance():
	_course(Contact.EXACT, Vector3(0, 0, -3500), 300.0)
	_marker.render(_telemetry())
	assert_true(_marker.shown)
	assert_eq(_marker.mode, VelocityMarker.Mode.ON_FRAME)
	assert_eq(_marker.reading, Contact.EXACT)
	assert_eq(_marker.text, "COURSE 3.2 KM")

func test_a_ping_says_only_its_rounded_kilometres():
	_course(Contact.PING, Vector3(0, 0, -4200), 0.0, 4)
	_marker.render(_telemetry())
	assert_eq(_marker.reading, Contact.PING)
	assert_eq(_marker.text, "COURSE ~4 KM")

func test_a_region_is_a_ring_and_hides_once_you_are_inside():
	_course(Contact.REGION, Vector3(0, 0, -700), 75.0)
	_marker.render(_telemetry())
	assert_eq(_marker.reading, Contact.REGION)
	assert_gt(_marker.ring_px, 0.0)
	assert_eq(_marker.text, "COURSE 630 M")
	_cam.position = Vector3(0, 0, -660)
	_marker.render(_telemetry())
	assert_false(_marker.shown, "inside the region, you look for yourself")

func test_behind_you_it_waits_at_the_edge():
	_course(Contact.EXACT, Vector3(0, 0, 3500), 300.0)
	_marker.render(_telemetry())
	assert_true(_marker.shown)
	assert_eq(_marker.mode, VelocityMarker.Mode.CLAMPED_BEHIND)

func test_without_its_camera_current_or_any_vehicle_it_hides():
	_course(Contact.EXACT, Vector3(0, 0, -3500), 300.0)
	_marker.render(null)
	assert_false(_marker.shown)
	_cam.current = false
	_marker.render(_telemetry())
	assert_false(_marker.shown)

func test_on_arrival_it_fades_out_where_it_was():
	_course(Contact.EXACT, Vector3(0, 0, -3500), 300.0)
	_marker.render(_telemetry())
	_sensors.clear_course()
	_sensors.course_arrived.emit(&"c")
	_marker.render(_telemetry())
	assert_true(_marker.shown, "still there, fading")
	_marker._process(CourseMarker.FADE * 0.5)
	_marker.render(_telemetry())
	assert_almost_eq(_marker.alpha, 0.5, 0.01)
	_marker._process(CourseMarker.FADE)
	_marker.render(_telemetry())
	assert_false(_marker.shown)

## Spec §6.1: the course's contact is the course marker's alone.
func test_the_contact_marker_leaves_the_course_to_it():
	var other := Contact.new()
	other.id = &"d"
	other.kind = &"salvage"
	other.label = "SALVAGE"
	other.point = _universe.to_universe(Vector3(300, 0, -5000))
	other.precision = Contact.PING
	other.km = 5
	_course(Contact.PING, Vector3(0, 0, -4200), 0.0, 4)
	(_source.list as Array).append(other)
	var contacts: ContactMarker = ContactMarker.new()
	contacts.size = Vector2(1280, 720)
	add_child_autofree(contacts)
	contacts.set_camera(_cam)
	contacts.sensors = _sensors
	contacts.render(_telemetry())
	assert_eq(contacts.marks.size(), 1, "only the other cloud")
	assert_string_contains(contacts.marks[0]["text"], "~5 KM")
