extends GutTest

## The course (bridge computer spec §4.3, §6.2): one per ship, kept by its
## sensors, followed beyond range, and cleared on arrival.

class FakeSource extends RefCounted:
	var list: Array[Contact] = []
	func contacts(focus: UniversePoint, range_m: float, _time: float) -> Array[Contact]:
		return list.filter(func(c: Contact) -> bool: return c.point.minus(focus).length() <= range_m)
	func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
		for c in list:
			if c.id == id:
				return c
		return null

var _universe: Universe
var _hull: Node3D
var _sensors: ShipSensors
var _source: FakeSource

func before_each():
	_universe = Universe.new()
	add_child_autofree(_universe)
	_hull = Node3D.new()
	add_child_autofree(_hull)
	_universe.set_focus(_hull)
	_sensors = ShipSensors.new()
	add_child_autofree(_sensors)
	_sensors.universe = _universe
	_source = FakeSource.new()
	_sensors.add_source(_source)

func _add(id: StringName, precision: StringName, at: Vector3, radius := 0.0) -> Contact:
	var c := Contact.new()
	c.id = id
	c.kind = &"rock" if precision == Contact.EXACT else &"salvage"
	c.label = "ROCK" if precision == Contact.EXACT else "SALVAGE"
	c.point = _universe.to_universe(at)
	c.precision = precision
	c.radius = radius
	_source.list.append(c)
	return c

func test_a_course_is_set_cleared_and_announced_once_each():
	_add(&"rock:1,0,0", Contact.EXACT, Vector3(0, 0, -5000), 300.0)
	watch_signals(_sensors)
	_sensors.set_course(&"rock:1,0,0")
	_sensors.set_course(&"rock:1,0,0")
	assert_signal_emit_count(_sensors, "course_changed", 1)
	assert_eq(_sensors.course, &"rock:1,0,0")
	_sensors.clear_course()
	_sensors.clear_course()
	assert_signal_emit_count(_sensors, "course_changed", 2)
	assert_eq(_sensors.course, &"")

func test_the_course_is_followed_beyond_any_range():
	_add(&"rock:9,0,0", Contact.EXACT, Vector3(0, 0, -45000), 300.0)
	_sensors.set_course(&"rock:9,0,0")
	_sensors.check_course()
	assert_true(_sensors.contacts(30000.0).is_empty(), "out of the map's reach")
	assert_not_null(_sensors.course_contact(), "but still followed")
	assert_eq(_sensors.course, &"rock:9,0,0")

func test_arriving_within_a_kilometre_of_a_rock_s_surface_clears_it():
	_add(&"rock:1,0,0", Contact.EXACT, Vector3(0, 0, -1500), 300.0)
	_sensors.set_course(&"rock:1,0,0")
	_sensors.check_course()
	assert_eq(_sensors.course, &"rock:1,0,0", "1.2 km off the surface: not yet")
	watch_signals(_sensors)
	_hull.position = Vector3(0, 0, -300)
	_sensors.check_course()
	assert_eq(_sensors.course, &"")
	assert_eq(_sensors.last_arrived, &"rock:1,0,0")
	assert_signal_emitted_with_parameters(_sensors, "course_arrived", [&"rock:1,0,0"])

func test_arriving_inside_a_region_clears_it():
	_add(&"salvage:3,0,0", Contact.REGION, Vector3(0, 0, -500), 75.0)
	_sensors.set_course(&"salvage:3,0,0")
	_sensors.check_course()
	assert_eq(_sensors.course, &"salvage:3,0,0")
	_hull.position = Vector3(0, 0, -450)
	_sensors.check_course()
	assert_eq(_sensors.course, &"")
	assert_eq(_sensors.last_arrived, &"salvage:3,0,0")

func test_a_ping_never_arrives():
	var c := _add(&"salvage:4,0,0", Contact.PING, Vector3(0, 0, -4000))
	c.km = 4
	_sensors.set_course(&"salvage:4,0,0")
	_hull.position = Vector3(0, 0, -3990)
	_sensors.check_course()
	assert_eq(_sensors.course, &"salvage:4,0,0")

func test_a_course_whose_contact_is_gone_clears_without_arriving():
	_add(&"salvage:5,0,0", Contact.REGION, Vector3(0, 0, -900), 75.0)
	_sensors.set_course(&"salvage:5,0,0")
	_source.list.clear()
	watch_signals(_sensors)
	_sensors.check_course()
	assert_eq(_sensors.course, &"")
	assert_eq(_sensors.last_arrived, &"")
	assert_signal_not_emitted(_sensors, "course_arrived")

func test_a_new_course_forgets_the_last_arrival():
	_sensors.last_arrived = &"rock:1,0,0"
	_add(&"rock:2,0,0", Contact.EXACT, Vector3(0, 0, -9000), 300.0)
	_sensors.set_course(&"rock:2,0,0")
	assert_eq(_sensors.last_arrived, &"")

## The sensors check the course on their own, a few times a second.
func test_it_checks_the_course_as_time_passes():
	_add(&"rock:1,0,0", Contact.EXACT, Vector3(0, 0, -900), 300.0)
	_sensors.set_course(&"rock:1,0,0")
	_sensors._process(ShipSensors.REFRESH_EVERY)
	assert_eq(_sensors.course, &"", "already there")
