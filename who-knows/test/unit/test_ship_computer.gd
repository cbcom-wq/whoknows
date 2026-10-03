extends GutTest

## One bridge computer's table (bridge computer spec §3.4, §3.5): its screen,
## its five buttons and its pages, built in a bare frame.

class OnePage extends ComputerPage:
	var presses: Array[StringName] = []
	var saved := {"n": 0}
	func title() -> String: return "TEST"
	func lines(_ctx: ComputerContext) -> PackedStringArray: return PackedStringArray(["LINE ONE", "LINE TWO"])
	func lit(_ctx: ComputerContext) -> Array[StringName]: return [&"next", &"big"]
	func big_colour(_ctx: ComputerContext) -> StringName: return &"amber"
	func prompt(button: StringName, _ctx: ComputerContext) -> String: return "Do %s" % button
	func press(button: StringName, _ctx: ComputerContext) -> void: presses.append(button)
	func save() -> Dictionary: return saved.duplicate()
	func restore(state: Dictionary) -> void: saved = state.duplicate()

var _computer: ShipComputer

func before_each():
	_computer = ShipComputer.new()
	_computer.setup(Transform3D.IDENTITY)
	add_child_autofree(_computer)

func test_it_builds_five_buttons_where_the_prop_says():
	var frames := InteriorProps.holo_table_buttons()
	for i in ShipComputer.BUTTONS.size():
		var panel: ReadoutPanel = _computer.panels[ShipComputer.BUTTONS[i]]
		assert_not_null(panel)
		assert_almost_eq(panel.transform.origin, frames[i].origin, Vector3.ONE * 0.0001)
		assert_true(panel.is_in_group("interactable"))

func test_the_holo_hangs_over_the_table_turned_with_the_ship_not_the_table():
	var turned := ShipComputer.new()
	var f := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2, 0, 3))
	turned.setup(f)
	add_child_autofree(turned)
	assert_almost_eq(turned.holo.position, f * InteriorProps.holo_table_volume().origin, Vector3.ONE * 0.0001)
	assert_true(turned.holo.basis.is_equal_approx(Basis.IDENTITY), "the holo is not turned with the table")

func test_the_screen_shows_the_page_s_title_and_lines():
	_computer.pages = [OnePage.new()]
	_computer.press(&"none")
	assert_eq(_computer.screen_text(), "TEST\nLINE ONE\nLINE TWO")

func test_only_the_buttons_a_page_uses_are_lit_and_offered():
	_computer.pages = [OnePage.new()]
	_computer.press(&"none")
	assert_eq(_computer.panels[&"next"].button_state(), &"go")
	assert_eq(_computer.panels[&"big"].button_state(), &"cycling", "amber")
	assert_eq(_computer.panels[&"prev"].button_state(), &"", "dark")
	assert_eq(_computer.panels[&"range"].button_state(), &"")
	assert_eq(_computer.prompt(&"next"), "Do next")
	assert_eq(_computer.prompt(&"prev"), "", "a dark button offers nothing")
	assert_false(_computer.panels[&"prev"].can_interact(null), "the Interactor passes over it")
	assert_eq(_computer.prompt(&"page"), "", "one page: nowhere to go")

func test_a_press_reaches_the_page_only_on_a_lit_button():
	var page := OnePage.new()
	_computer.pages = [page]
	_computer.press(&"prev")
	_computer.press(&"next")
	assert_eq(page.presses, [&"next"] as Array[StringName])

func test_page_steps_through_the_pages_and_wraps():
	_computer.pages = [OnePage.new(), StatusPage.new()]
	assert_eq(_computer.prompt(&"page"), "Next page")
	_computer.press(&"page")
	assert_eq(_computer.page_index, 1)
	assert_true(_computer.screen_text().begins_with("STATUS"))
	_computer.press(&"page")
	assert_eq(_computer.page_index, 0)

func test_whoever_presses_is_the_operator():
	var who := Node.new()
	add_child_autofree(who)
	_computer.panels[&"page"].interact(who)
	assert_eq(_computer.ctx.operator, who)

func test_its_state_survives_being_saved_and_restored():
	var page := OnePage.new()
	page.saved = {"n": 7}
	_computer.pages = [OnePage.new(), page]
	_computer.page_index = 1
	var state := _computer.save()
	var again := ShipComputer.new()
	again.setup(Transform3D.IDENTITY)
	add_child_autofree(again)
	again.pages = [OnePage.new(), OnePage.new()]
	again.restore(state)
	assert_eq(again.page_index, 1)
	assert_eq((again.pages[1] as OnePage).saved, {"n": 7})

func test_nothing_it_builds_collides_but_its_buttons_and_its_station():
	var bodies := _computer.find_children("*", "CollisionObject3D", true, false)
	assert_eq(bodies.size(), ShipComputer.BUTTONS.size() + 1)
	for b in bodies:
		assert_true(b is ReadoutPanel or b == _computer.station)

## Computer mode spec §3.1: each table builds its own station, in its frame.
func test_it_builds_a_station_in_the_table_s_frame():
	var f := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2, 0, 3))
	var turned := ShipComputer.new()
	turned.setup(f)
	add_child_autofree(turned)
	assert_not_null(turned.station)
	assert_true(turned.station.transform.is_equal_approx(f))
	assert_true(turned.station.is_in_group("interactable"))
	assert_eq(turned.station.prompt_text(), "Use computer")
	assert_eq(turned.station.computer, turned)

func test_the_station_s_eye_orbits_and_recentres():
	var s := _computer.station
	var start := s.eye_transform()
	s.orbit(30.0)
	assert_almost_eq(s.elevation, InteriorProps.HOLO_STATION_ELEVATION + 30.0, 0.0001)
	assert_gt(s.eye_transform().origin.y, start.origin.y)
	s.orbit(1000.0)
	assert_eq(s.elevation, ComputerStation.ELEVATION_MAX)
	_computer.spin = 1.0
	s.recentre()
	assert_eq(s.elevation, InteriorProps.HOLO_STATION_ELEVATION)
	assert_eq(_computer.spin, 0.0)
	assert_true(s.eye_transform().is_equal_approx(start))
