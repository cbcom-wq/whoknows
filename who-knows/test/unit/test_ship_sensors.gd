extends GutTest

## The ship's sensors (NPC foundation spec §22.3): every source's contacts,
## nearest first, within range, looked up by id.

class FakeSource:
	var things := {}   # id -> Vector3 (engine == universe here)
	func contacts(focus: UniversePoint, range_m: float, time: float) -> Array[Contact]:
		var out: Array[Contact] = []
		for id in things:
			var c := Sense.read(SenseProfile.life(), focus, UniversePoint.at(0, 0, 0).plus(things[id]), id, time)
			if c != null:
				out.append(c)
		return out
	func contact(id: StringName, focus: UniversePoint, time: float) -> Contact:
		if not things.has(id):
			return null
		return Sense.read(SenseProfile.life(), focus, UniversePoint.at(0, 0, 0).plus(things[id]), id, time)

var _sensors: ShipSensors
var _universe: Universe
var _focus: Node3D

func before_each():
	_universe = Universe.new()
	add_child_autofree(_universe)
	_focus = Node3D.new()
	add_child_autofree(_focus)
	_universe.set_focus(_focus)
	_sensors = ShipSensors.new()
	add_child_autofree(_sensors)
	_sensors.universe = _universe

func test_contacts_come_nearest_first():
	var src := FakeSource.new()
	src.things = {&"life:a:0": Vector3(0, 0, -3000), &"life:b:0": Vector3(0, 0, -500), &"life:c:0": Vector3(1500, 0, 0)}
	_sensors.add_source(src)
	var cs := _sensors.contacts(10000.0)
	assert_eq(cs.size(), 3)
	assert_eq(cs[0].id, &"life:b:0")
	assert_eq(cs[2].id, &"life:a:0")

func test_with_no_focus_there_is_nothing():
	_universe.set_focus(null)
	var src := FakeSource.new()
	src.things = {&"life:a:0": Vector3(0, 0, -500)}
	_sensors.add_source(src)
	assert_eq(_sensors.contacts(10000.0).size(), 0)

func test_a_contact_is_found_by_id():
	var src := FakeSource.new()
	src.things = {&"life:a:0": Vector3(0, 0, -500)}
	_sensors.add_source(src)
	assert_not_null(_sensors.contact(&"life:a:0"))
	assert_null(_sensors.contact(&"life:zz:0"))
