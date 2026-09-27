extends GutTest

## The map (bridge computer spec §5): the ranges, the targets, the course's
## buttons, the screen's lines and what the holo is given.

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
var _ctx: ComputerContext
var _page: MapPage
var _holo: HoloVolume

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
	_ctx = ComputerContext.new()
	_ctx.sensors = _sensors
	_ctx.hull = _hull
	_page = MapPage.new()
	_holo = HoloVolume.new()
	_holo.setup()
	add_child_autofree(_holo)

func _add(id: StringName, precision: StringName, at: Vector3, radius := 0.0, km := 0,
		kind: StringName = &"") -> Contact:
	var c := Contact.new()
	c.id = id
	c.kind = kind if kind != &"" else (&"rock" if precision == Contact.EXACT else &"salvage")
	c.label = {&"rock": "ROCK", &"salvage": "SALVAGE", &"life": "LIFE?"}[c.kind]
	c.point = _universe.to_universe(at)
	c.precision = precision
	c.radius = radius
	c.km = km
	c.fresh_for = 4.0
	_source.list.append(c)
	return c

func _refresh() -> void:
	_sensors.refresh(30000.0)
	_page.reselect(_ctx)

func test_it_opens_at_ten_kilometres_and_range_cycles():
	assert_eq(_page.title(), "MAP · 10 KM")
	assert_eq(_page.prompt(&"range", _ctx), "Range 30 km")
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · 30 KM")
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · 2 KM")
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · 10 KM")

func test_prev_and_next_step_nearest_first_and_wrap():
	_add(&"rock:far", Contact.EXACT, Vector3(0, 0, -8000), 300.0)
	_add(&"rock:near", Contact.EXACT, Vector3(0, 0, -3000), 300.0)
	_refresh()
	assert_eq(_page.selected, &"rock:near", "the nearest to start with")
	_page.press(&"next", _ctx)
	assert_eq(_page.selected, &"rock:far")
	_page.press(&"next", _ctx)
	assert_eq(_page.selected, &"rock:near", "wrapped")
	_page.press(&"prev", _ctx)
	assert_eq(_page.selected, &"rock:far")

func test_after_a_change_of_range_the_course_is_selected_if_it_is_there():
	_add(&"rock:near", Contact.EXACT, Vector3(0, 0, -3000), 300.0)
	_add(&"rock:far", Contact.EXACT, Vector3(0, 0, -8000), 300.0)
	_refresh()
	_sensors.set_course(&"rock:far")
	_page.press(&"range", _ctx)   # 30 km
	assert_eq(_page.selected, &"rock:far")
	_page.press(&"range", _ctx)   # 2 km: the course is off this range
	assert_eq(_page.selected, &"", "nothing within 2 km")

func test_the_far_range_shows_big_rocks_only():
	_add(&"rock:a", Contact.EXACT, Vector3(0, 0, -20000), 300.0)
	_add(&"salvage:b", Contact.PING, Vector3(0, 0, -4000), 0.0, 4)
	_page.range_index = 2
	_refresh()
	var ids := _page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id)
	assert_eq(ids, [&"rock:a"])

func test_the_big_button_sets_and_clears_the_course():
	_add(&"rock:near", Contact.EXACT, Vector3(0, 0, -3000), 300.0)
	_refresh()
	assert_eq(_page.big_colour(_ctx), &"go")
	assert_eq(_page.prompt(&"big", _ctx), "Set course")
	_page.press(&"big", _ctx)
	assert_eq(_sensors.course, &"rock:near")
	assert_eq(_page.big_colour(_ctx), &"amber")
	assert_eq(_page.prompt(&"big", _ctx), "Clear course")
	assert_eq(_page.lines(_ctx)[1], "COURSE SET")
	_page.press(&"big", _ctx)
	assert_eq(_sensors.course, &"")

## Spec §15: a course goes to a big rock or salvage, not to signs of life.
func test_life_is_on_the_map_but_takes_no_course():
	_add(&"life:a:0", Contact.PING, Vector3(0, 0, -3000), 0.0, 3, &"life")
	_refresh()
	assert_eq(_page.selected, &"life:a:0")
	assert_eq(_page.lines(_ctx)[0], "LIFE? · ~3 KM")
	assert_eq(_page.lines(_ctx)[1], "")
	assert_false(_page.lit(_ctx).has(&"big"))
	assert_eq(_page.big_colour(_ctx), &"dark")
	_page.press(&"big", _ctx)
	assert_eq(_sensors.course, &"")

func test_the_screen_names_the_selected_contact():
	_add(&"rock:near", Contact.EXACT, Vector3(0, 0, -3500), 300.0)
	_refresh()
	assert_eq(_page.lines(_ctx)[0], "ROCK · 3.2 KM")
	assert_eq(_page.lines(_ctx)[1], "SET COURSE")

func test_with_nothing_in_range_it_says_so_and_only_range_is_lit():
	_refresh()
	assert_eq(_page.lines(_ctx)[1], "NO CONTACTS")
	assert_eq(_page.lit(_ctx), [&"range"] as Array[StringName])
	assert_eq(_page.big_colour(_ctx), &"dark")

func test_arrived_shows_until_the_selection_changes():
	_add(&"salvage:r", Contact.REGION, Vector3(0, 0, -40), 75.0)
	_add(&"rock:x", Contact.EXACT, Vector3(0, 0, -5000), 300.0)
	_refresh()
	_sensors.last_arrived = &"salvage:r"
	assert_eq(_page.selected, &"salvage:r")
	assert_eq(_page.lines(_ctx)[1], "ARRIVED")
	_page.press(&"next", _ctx)
	_page.press(&"prev", _ctx)
	assert_eq(_page.lines(_ctx)[1], "SET COURSE", "forgotten once you moved on")

## Spec §5.1: the map is turned with the ship. A rock dead ahead of a hull
## turned to face +x is at the holo's forward edge all the same.
func test_a_rock_dead_ahead_is_at_the_forward_edge_however_the_hull_is_turned():
	_hull.rotation = Vector3(0, -PI * 0.5, 0)
	var ahead := _hull.global_basis * Vector3(0, 0, -1000)
	_add(&"rock:ahead", Contact.EXACT, ahead, 300.0)
	_page.range_index = 0   # 2 km
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"ball"), 1)
	assert_almost_eq(_holo.mark_transform(&"ball", 0).origin, Vector3(0, 0, -0.25), Vector3.ONE * 0.0001)

func test_each_kind_is_drawn_in_its_colour_and_the_course_in_amber():
	_add(&"rock:a", Contact.EXACT, Vector3(0, 0, -3000), 300.0)
	_add(&"rock:b", Contact.EXACT, Vector3(2000, 0, -3000), 300.0)
	_add(&"salvage:c", Contact.PING, Vector3(0, 0, -5000), 0.0, 5)
	_add(&"life:d:0", Contact.REGION, Vector3(0, 0, -800), 15.0, 0, &"life")
	_refresh()
	_sensors.set_course(&"rock:b")
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"ball", InteriorPalette.SKY), 1)
	assert_eq(_holo.mark_count(&"ball", InteriorPalette.AMBER), 1, "the course")
	assert_eq(_holo.mark_count(&"diamond", InteriorPalette.QUANTUM), 1, "the salvage ping")
	assert_eq(_holo.mark_count(&"sphere", InteriorPalette.SIGNAL_GO), 1, "life's region")

func test_the_course_beyond_range_is_drawn_pinned():
	_add(&"rock:away", Contact.EXACT, Vector3(0, 0, -25000), 300.0)
	_refresh()
	_sensors.set_course(&"rock:away")
	_page.range_index = 0
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"pin"), 1)

func test_stalks_only_for_the_nearest_twelve_and_the_selected():
	for i in 20:
		_add(StringName("rock:%d" % i), Contact.EXACT, Vector3(i * 300.0, 200.0, -1000.0 - i * 300.0), 300.0)
	_page.range_index = 1
	_refresh()
	_page.selected = &"rock:19"
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"stalk"), MapPage.STALKS + 1)
	assert_eq(_holo.mark_count(&"tick"), MapPage.STALKS + 1)
	assert_true(_holo.bracket_shown())

func test_mark_sizes_follow_the_range():
	var rock := Contact.new()
	rock.precision = Contact.EXACT
	rock.radius = 300.0
	assert_almost_eq(MapPage.mark_size(rock, 2000.0, 0.0), 0.15, 0.0001, "to scale at 2 km")
	assert_almost_eq(MapPage.mark_size(rock, 10000.0, 0.0), MapPage.ROCK_MAX_MID, 0.0001, "the biggest at 10 km")
	assert_almost_eq(MapPage.mark_size(rock, 30000.0, 0.0), MapPage.ROCK_FAR, 0.0001)
	var ping := Contact.new()
	ping.precision = Contact.PING
	ping.taken = 8.0
	ping.fresh_for = 4.0
	assert_almost_eq(MapPage.mark_size(ping, 10000.0, 8.0), MapPage.PING_SIZE, 0.0001, "full on the refresh")
	assert_lt(MapPage.mark_size(ping, 10000.0, 8.0 + 4.0 * 0.9), MapPage.PING_SIZE * 0.5, "shrunk by the next")

func test_the_page_state_survives_a_save():
	_page.range_index = 2
	_page.selected = &"rock:x"
	var again := MapPage.new()
	again.restore(_page.save())
	assert_eq(again.range_index, 2)
	assert_eq(again.selected, &"rock:x")

## CLAUDE.md: a floating-origin shift must leave the holo exactly as it was.
## The hull is a member, as the real one is, so the shift moves it and the
## origin together, and nothing moves relative to anything.
func test_a_shift_leaves_the_map_unchanged():
	_hull.add_to_group(Universe.EXTERIOR_SPACE)
	_hull.global_position = Vector3(1900, 0, 0)
	_add(&"rock:a", Contact.EXACT, Vector3(2600, 100, -1600), 300.0)
	_page.range_index = 1
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	var before := _holo.mark_transform(&"ball", 0).origin
	_universe.shift(Vector3(1000, 0, 0))
	_sensors.refresh(30000.0)
	_page.reselect(_ctx)
	_page.holo(_holo, _ctx, 0.0)
	assert_almost_eq(_holo.mark_transform(&"ball", 0).origin, before, Vector3.ONE * 0.0001)
	assert_almost_eq(before, Vector3(700, 100, -1600) * (HoloVolume.RADIUS / 10000.0), Vector3.ONE * 0.0001)

## At 30 km the marks are placed twice a second and turned with the ship in
## between: a turn of the hull shows at once, where a fresh placement would
## put it.
func test_between_placements_at_30_km_the_marks_turn_with_the_ship():
	_add(&"rock:a", Contact.EXACT, Vector3(0, 0, -20000), 300.0)
	_page.range_index = 2
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	_hull.rotation = Vector3(0, PI * 0.5, 0)   # turned to port: the rock is now off to starboard
	_page.holo(_holo, _ctx, 0.016)
	var shown: Vector3 = _holo.turn() * _holo.mark_transform(&"ball", 0).origin
	assert_almost_eq(shown, Vector3(20000, 0, 0) * (HoloVolume.RADIUS / 30000.0), Vector3.ONE * 0.001)
	_page.holo(_holo, _ctx, MapPage.PLACE_EVERY[2])
	assert_true(_holo.turn().is_equal_approx(Basis.IDENTITY), "placed afresh")
	assert_almost_eq(_holo.mark_transform(&"ball", 0).origin, shown, Vector3.ONE * 0.001)
