extends GutTest

## The overlay round the holo at a computer station (computer mode spec §5).

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
var _overlay: ComputerOverlay

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
	_computer = ShipComputer.new()
	_computer.setup(Transform3D.IDENTITY)
	add_child_autofree(_computer)
	var ctx := ComputerContext.new()
	ctx.sensors = _sensors
	ctx.hull = _hull
	_computer.bind(ctx)
	_overlay = ComputerOverlay.new()
	add_child_autofree(_overlay)

func _add(id: StringName, kind: StringName, at: Vector3, precision := Contact.EXACT) -> void:
	var c := Contact.new()
	c.id = id
	c.kind = kind
	c.label = String(kind).to_upper()
	c.point = _universe.to_universe(at)
	c.precision = precision
	c.radius = 300.0
	c.km = 4
	_source.list.append(c)

func _map() -> MapPage:
	return _computer.pages[0] as MapPage

func _ready_map() -> void:
	_add(&"rock:a", &"rock", Vector3(0, 0, -3000))
	_add(&"life:b", &"life", Vector3(0, 0, -6000), Contact.PING)
	_sensors.refresh(MapPage.QUERY)
	_map().reselect(_computer.ctx)
	_overlay.show_for(_computer.station)

func test_it_shows_for_a_station_and_hides_for_none():
	_overlay.show_for(_computer.station)
	assert_true(_overlay.visible)
	_overlay.show_for(null)
	assert_false(_overlay.visible)

func test_near_in_the_list_is_what_is_on_the_map_with_its_distance():
	_ready_map()
	var rows := ComputerOverlay.list_rows(_map(), _computer.ctx)
	assert_eq(rows.map(func(r: Dictionary) -> StringName: return r["id"]), [&"rock:a", &"life:b"])
	assert_string_contains(rows[0]["text"], "KM")

func test_far_out_the_list_is_the_system_with_moons_under_their_planets():
	var s := SystemRecipe.from_seed(1337)
	_sensors.system = s
	_sensors.add_source(BodyContacts.new(s))
	_universe.origin = s.entry()
	_map().range_index = MapPage.SYSTEM_RANGE
	var rows := ComputerOverlay.list_rows(_map(), _computer.ctx)
	assert_eq(rows[0]["id"], BodyContacts.id_of(s.star))
	var last_planet := &""
	for r in rows:
		if r["indent"] == 0 and String(r["id"]).begins_with("body:"):
			last_planet = r["id"]
		if r["indent"] == 1:
			assert_ne(last_planet, &"", "a moon comes under a planet")

func test_a_row_click_selects_the_same_contact_as_a_holo_pick_would():
	_ready_map()
	_overlay.refresh()
	var row: Button = _overlay.list_box.get_child(2)   # 0 is the title, 1 the rock
	row.pressed.emit()
	assert_eq(_map().selected, &"life:b")

func test_the_action_is_the_big_button_s_and_dark_when_it_would_do_nothing():
	_ready_map()
	_computer.select(&"rock:a")
	_overlay.refresh()
	assert_eq(_overlay.action.text, "SET COURSE")
	assert_false(_overlay.action.disabled)
	_overlay.action.pressed.emit()
	assert_eq(_sensors.course, &"rock:a")
	_overlay.refresh()
	assert_eq(_overlay.action.text, "CLEAR COURSE")
	_computer.select(&"life:b")
	_overlay.refresh()
	assert_true(_overlay.action.disabled)
	assert_eq(_overlay.action.text, "NO ACTION")

func test_the_card_shows_the_page_s_lines():
	_ready_map()
	_computer.select(&"rock:a")
	_overlay.refresh()
	assert_eq(_overlay.card_lines[0].text, _map().lines(_computer.ctx)[0])

func test_the_status_tab_has_no_list_and_no_action():
	_ready_map()
	_overlay.tabs[1].pressed.emit()
	_overlay.refresh()
	assert_eq(_computer.page_index, 1)
	assert_false(_overlay.list_box.get_parent().get_parent().visible)
	assert_false(_overlay.action.visible)

func test_the_panels_take_the_mouse():
	_ready_map()
	assert_eq(_overlay.list_box.get_parent().get_parent().mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_overlay.get_child(0).mouse_filter, Control.MOUSE_FILTER_IGNORE, "the middle lets clicks through to the holo")

func test_no_button_takes_the_keyboard_focus():
	# The mode reads R, Tab and Enter in _unhandled_input; a focused Button
	# would have eaten Tab and Enter as ui_focus_next and ui_accept first.
	_ready_map()
	_overlay.refresh()
	for t in _overlay.tabs:
		assert_eq(t.focus_mode, Control.FOCUS_NONE, "a tab")
	assert_eq((_overlay.list_box.get_child(1) as Button).focus_mode, Control.FOCUS_NONE, "a row")
	assert_eq(_overlay.action.focus_mode, Control.FOCUS_NONE, "the action")

# --- a world that is not on the map (select, spec §5.2) ---------------------

func _far_system() -> SystemRecipe:
	var s := SystemRecipe.from_seed(1337)
	_sensors.system = s
	_sensors.add_source(BodyContacts.new(s))
	_universe.origin = s.entry()
	_map().restore({"scale": 1500000.0})
	_sensors.refresh(MapPage.QUERY)
	return s

func _off_the_map(s: SystemRecipe) -> StringName:
	var on := _map().targets(_computer.ctx).map(func(c: Contact) -> StringName: return c.id)
	for p in s.bodies:
		if p.kind == SystemBody.Kind.PLANET and not on.has(BodyContacts.id_of(p)):
			return BodyContacts.id_of(p)
	return &""

func test_selecting_a_world_off_the_map_zooms_out_to_the_system_and_it_sticks():
	var s := _far_system()
	assert_lt(_map().scale_m, MapPage.STOPS[MapPage.SYSTEM_RANGE], "a mid scale to begin with")
	var far := _off_the_map(s)
	assert_ne(far, &"", "a world lies outside the holo at 1,500 km")
	_computer.select(far)
	assert_eq(_map().scale_m, MapPage.STOPS[MapPage.SYSTEM_RANGE], "the map zooms to the system")
	assert_eq(_map().selected, far)
	_computer.update(0.0)
	assert_eq(_map().selected, far, "the next frame's reselect does not undo it")

func test_a_row_for_a_world_off_the_map_selects_it_too():
	var s := _far_system()
	var far := _off_the_map(s)
	_overlay.show_for(_computer.station)
	_overlay.refresh()
	var row: Button = null
	for i in range(1, _overlay.list_box.get_child_count()):
		var b: Button = _overlay.list_box.get_child(i)
		if b.visible and b.get_meta(&"id") == far:
			row = b
	assert_not_null(row, "the system's list has a row for it")
	row.pressed.emit()
	_computer.update(0.0)
	assert_eq(_map().selected, far)

func test_selecting_what_is_not_a_target_anywhere_changes_nothing():
	_ready_map()
	var before := _map().scale_m
	var selected := _map().selected
	_computer.select(&"nothing:here")
	assert_eq(_map().scale_m, before, "the scale is left alone")
	assert_eq(_map().selected, selected)
