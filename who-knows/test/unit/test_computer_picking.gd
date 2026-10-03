extends GutTest

## Picking with the mouse at a computer station (computer mode spec §4.5), and
## the calls the mode makes on the table: zoom, spin, tabs and the big
## button's action.

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
var _computer: ShipComputer
var _cam: Camera3D

func before_each():
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child_autofree(vp)
	_universe = Universe.new()
	vp.add_child(_universe)
	_hull = Node3D.new()
	vp.add_child(_hull)
	_universe.set_focus(_hull)
	_sensors = ShipSensors.new()
	vp.add_child(_sensors)
	_sensors.universe = _universe
	_source = FakeSource.new()
	_sensors.add_source(_source)
	_computer = ShipComputer.new()
	_computer.setup(Transform3D.IDENTITY)
	vp.add_child(_computer)
	var ctx := ComputerContext.new()
	ctx.sensors = _sensors
	ctx.hull = _hull
	_computer.bind(ctx)
	_cam = Camera3D.new()
	vp.add_child(_cam)
	_cam.current = true
	var centre := _computer.holo.global_position
	_cam.look_at_from_position(centre + Vector3(0, 0.5, -0.9), centre)

func _add(id: StringName, at: Vector3, kind: StringName = &"rock") -> void:
	var c := Contact.new()
	c.id = id
	c.kind = kind
	c.label = "ROCK"
	c.point = _universe.to_universe(at)
	c.precision = Contact.EXACT
	c.radius = 300.0
	_source.list.append(c)

func _placed_on_screen(id: StringName) -> Vector2:
	var map := _computer.page() as MapPage
	for m in map.placed_marks:
		if m["id"] == id:
			return _cam.unproject_position(_computer.holo.marks_to_global(m["position"]))
	return Vector2(-1000, -1000)

func _ready_map() -> void:
	_add(&"rock:ahead", Vector3(0, 0, -5000))
	_add(&"rock:right", Vector3(5000, 0, 0))
	_sensors.refresh(MapPage.QUERY)
	(_computer.page() as MapPage).reselect(_computer.ctx)
	_computer.update(0.0)

func test_a_click_near_a_mark_selects_it():
	_ready_map()
	var at := _placed_on_screen(&"rock:right")
	assert_eq(_computer.pick(at + Vector2(10, 0), _cam), &"rock:right")
	assert_eq((_computer.page() as MapPage).selected, &"rock:right")

func test_a_click_far_from_every_mark_selects_nothing_and_keeps_the_selection():
	_ready_map()
	var before := (_computer.page() as MapPage).selected
	assert_eq(_computer.pick(Vector2(5, 5), _cam), &"")
	assert_eq((_computer.page() as MapPage).selected, before)

func test_hover_names_the_mark_under_the_cursor():
	_ready_map()
	assert_eq(_computer.hover(_placed_on_screen(&"rock:ahead"), _cam), &"rock:ahead")
	assert_eq(_computer.hovered, &"rock:ahead")
	_computer.hover(Vector2(5, 5), _cam)
	assert_eq(_computer.hovered, &"")

func test_a_mark_that_is_drawn_but_shrinking_is_not_pickable():
	# A rock is full size to 50 km and gone by 100 km (spec §4.3): at 70 km it
	# is drawn, half grown out, and is not a target, so no click takes it
	# (spec §4.5). A world is full size at any scale: the control.
	_add(&"rock:fading", Vector3(0, 0, -40000))
	_add(&"body:world", Vector3(0, 0, 30000), &"body")
	_sensors.refresh(MapPage.QUERY)
	var map := _computer.page() as MapPage
	map.restore({"scale": 70000.0})
	_computer.update(0.0)
	var ids: Array = map.placed_marks.map(func(m: Dictionary) -> StringName: return m["id"])
	assert_true(ids.has(&"body:world"), "a full-size target is placed")
	assert_false(ids.has(&"rock:fading"), "a shrinking mark is not placed as a target")
	var fading := _cam.unproject_position(_computer.holo.marks_to_global(
		map.holo_position(_computer.ctx, _computer.ctx.map_frame(), _universe.to_universe(Vector3(0, 0, -40000)))))
	assert_eq(_computer.pick(fading, _cam), &"")

func test_spin_reaches_the_holo():
	_computer.spin = 0.5
	assert_almost_eq(_computer.holo.spin(), 0.5, 0.000001)

func test_zoom_moves_the_map_and_does_nothing_on_the_status_tab():
	_computer.zoom(1.0)
	assert_almost_eq((_computer.pages[0] as MapPage).scale_m, 13000.0, 0.01)
	_computer.tab(1)
	assert_eq(_computer.page_index, 1)
	_computer.zoom(1.0)
	assert_almost_eq((_computer.pages[0] as MapPage).scale_m, 13000.0, 0.01, "status ignores the wheel")

func test_act_is_the_big_button():
	_ready_map()
	_computer.act()
	assert_eq(_sensors.course, (_computer.page() as MapPage).selected)
