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
	c.label = {&"rock": "ROCK", &"salvage": "SALVAGE", &"life": "LIFE?", &"body": "KORVA-7"}[c.kind]
	c.point = _universe.to_universe(at)
	c.precision = precision
	c.radius = radius
	c.km = km
	c.fresh_for = 4.0
	_source.list.append(c)
	return c

func _refresh() -> void:
	_sensors.refresh(300000.0)
	_page.reselect(_ctx)

func test_it_opens_at_ten_kilometres_and_range_cycles():
	assert_eq(_page.title(), "MAP · 10 KM")
	assert_eq(_page.prompt(&"range", _ctx), "Range 50 km")
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · 50 KM")
	assert_eq(_page.prompt(&"range", _ctx), "Range 500 km")
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · 500 KM")
	assert_eq(_page.prompt(&"range", _ctx), "Range system")
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · SYSTEM")
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
	_page.press(&"range", _ctx)   # 50 km
	assert_eq(_page.selected, &"rock:far")
	_page.press(&"range", _ctx)   # 500 km
	_page.press(&"range", _ctx)   # system
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

## At 50 km the marks are placed twice a second and turned with the ship in
## between: a turn of the hull shows at once, where a fresh placement would
## put it.
func test_between_placements_at_50_km_the_marks_turn_with_the_ship():
	_add(&"rock:a", Contact.EXACT, Vector3(0, 0, -20000), 300.0)
	_page.range_index = 2
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	_hull.rotation = Vector3(0, PI * 0.5, 0)   # turned to port: the rock is now off to starboard
	_page.holo(_holo, _ctx, 0.016)
	var shown: Vector3 = _holo.turn() * _holo.mark_transform(&"ball", 0).origin
	assert_almost_eq(shown, Vector3(20000, 0, 0) * (HoloVolume.RADIUS / 50000.0), Vector3.ONE * 0.001)
	_page.holo(_holo, _ctx, _page.place_every())
	assert_true(_holo.turn().is_equal_approx(Basis.IDENTITY), "placed afresh")
	assert_almost_eq(_holo.mark_transform(&"ball", 0).origin, shown, Vector3.ONE * 0.001)

# --- the system range (the system skeleton spec §10) --------------------------

func test_the_system_range_shows_worlds_only_and_50_km_rocks_and_worlds():
	_add(&"rock:a", Contact.EXACT, Vector3(0, 0, -20000), 300.0)
	_add(&"body:p1", Contact.EXACT, Vector3(0, 0, -25000), 900.0, 0, &"body")
	_add(&"body:p2", Contact.EXACT, Vector3(0, 0, -150000), 1100.0, 0, &"body")
	_add(&"salvage:b", Contact.PING, Vector3(0, 0, -4000), 0.0, 4)
	_page.range_index = MapPage.SYSTEM_RANGE
	_refresh()
	var ids := _page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id)
	assert_eq(ids, [&"body:p1", &"body:p2"])
	_page.range_index = 2
	_refresh()
	ids = _page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id)
	assert_eq(ids, [&"rock:a", &"body:p1"])

func test_a_course_can_be_set_to_a_world():
	_add(&"body:p1", Contact.EXACT, Vector3(0, 0, -25000), 900.0, 0, &"body")
	_page.range_index = MapPage.SYSTEM_RANGE
	_refresh()
	assert_eq(_page.big_colour(_ctx), &"go")
	_page.press(&"big", _ctx)
	assert_eq(_sensors.course, &"body:p1")

func test_worlds_are_drawn_in_their_own_colour_by_class_on_the_system_range():
	assert_eq(MapPage.colour_for(&"body"), InteriorPalette.WORLD)
	assert_eq(MapPage.colour_for(&"moon"), InteriorPalette.WORLD)
	assert_eq(MapPage.colour_for(&"cluster"), InteriorPalette.SKY)
	var c := Contact.new()
	c.kind = &"body"
	c.precision = Contact.EXACT
	c.id = &"body:p1"
	for r in [[15000.0, &"small"], [35000.0, &"medium"], [50000.0, &"large"]]:
		c.radius = r[0]
		assert_eq(MapPage.size_class(c), r[1])
		assert_eq(MapPage.mark_size(c, MapPage.STOPS[MapPage.SYSTEM_RANGE], 0.0), MapPage.CLASS_SIZE[r[1]])
	c.id = &"body:star"
	c.radius = 250000.0
	assert_eq(MapPage.size_class(c), &"star")
	c.kind = &"cluster"
	c.id = &"body:belt_0.c1"
	assert_eq(MapPage.size_class(c), &"cluster")
	c.kind = &"body"
	c.id = &"body:p1"
	c.radius = 60000.0
	assert_eq(MapPage.mark_size(c, 2000.0, 0.0), MapPage.BODY_MAX, "near ranges keep true size, clamped")

func test_the_system_range_draws_each_belt_as_a_ring_of_ticks():
	_sensors.system = SystemRecipe.from_seed(1337)
	_universe.origin = _sensors.system.entry()
	_page.range_index = MapPage.SYSTEM_RANGE
	_refresh()
	_page.holo(_holo, _ctx, 1.0)
	var ticks := _holo.mark_count(&"tick", InteriorPalette.SKY)
	assert_gte(ticks, MapPage.BELT_TICKS * _sensors.system.belts.size() / 2, "most ticks fall inside the range")

func test_with_nothing_selected_the_screen_says_where_you_are():
	_sensors.system = SystemRecipe.from_seed(1337)
	_universe.origin = _sensors.system.entry()
	var w := Whereabouts.new()
	add_child_autofree(w)
	w.setup(_sensors.system, _universe)
	_sensors.whereabouts = w
	_page.range_index = 0
	_refresh()
	var lines := _page.lines(_ctx)
	assert_eq(lines[1], "NO CONTACTS")
	assert_true(lines[0].begins_with(_sensors.system.name), lines[0])

# --- the system range with a warp drive (the warp spec §7) ---------------------

var _drive: WarpDrive

func _with_system() -> SystemRecipe:
	var s := SystemRecipe.from_seed(1337)
	_sensors.system = s
	_sensors.add_source(BodyContacts.new(s))
	_universe.origin = s.entry()
	_drive = WarpDrive.new()
	add_child_autofree(_drive)
	_drive.set_physics_process(false)
	_drive.hull = null
	_drive.bind(s, _universe, null, _sensors, null, Callable())
	_ctx.warp = _drive
	_ctx.store = QuantumStore.new(1200, 600)
	_page.range_index = MapPage.SYSTEM_RANGE
	_refresh()
	return s

func test_the_system_range_steps_through_warp_targets_moons_included():
	var s := _with_system()
	var ids := _page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id)
	for t in s.warp_targets():
		assert_true(ids.has(t.contact_id()), "%s" % t.id)
	for b in s.bodies:
		if b.kind == SystemBody.Kind.MOON:
			assert_true(ids.has(BodyContacts.id_of(b)), "moons are targets at this scale")

func test_the_system_range_is_centred_on_the_star():
	var s := _with_system()
	var frame := _ctx.map_frame()
	assert_true(_page.holo_position(_ctx, frame, s.star.point).is_equal_approx(Vector3.ZERO))
	var ship := _page.holo_position(_ctx, frame, s.entry())
	assert_almost_eq(ship.length(), s.entry().minus(s.star.point).length() * HoloVolume.RADIUS / MapPage.SYSTEM_REACH, 0.001)

func test_targets_beyond_your_qe_are_dim():
	_with_system()
	_page.holo(_holo, _ctx, 1.0)
	assert_gt(_holo.mark_count(&"ball", InteriorPalette.WORLD), 0, "some in reach on 600 QE")
	assert_gt(_holo.mark_count(&"ball", InteriorPalette.HOLO_DIM), 0, "some beyond it")
	_ctx.store = QuantumStore.new(5000, 5000)
	_page.holo(_holo, _ctx, 1.0)
	assert_eq(_holo.mark_count(&"ball", InteriorPalette.HOLO_DIM), 0, "a big store reaches everything")

func test_scale_rings_and_limit_rings_are_drawn():
	_with_system()
	_page.holo(_holo, _ctx, 1.0)
	assert_gt(_holo.mark_count(&"tick", InteriorPalette.HOLO_DIM), MapPage.SCALE_TICKS)

func test_the_big_button_charts_and_clears_a_warp():
	var s := _with_system()
	var planet := s.planets()[s.planets().size() - 1]
	_page.selected = StringName("body:" + String(planet.id))
	assert_eq(_page.prompt(&"big", _ctx), "Chart warp")
	_page.press(&"big", _ctx)
	assert_eq(_drive.charted, planet.id)
	assert_eq(_sensors.course, StringName("body:" + String(planet.id)))
	assert_eq(_page.prompt(&"big", _ctx), "Clear warp")
	assert_eq(_page.lines(_ctx)[2], "WARP CHARTED")
	_page.press(&"big", _ctx)
	assert_eq(_drive.charted, &"")
	assert_eq(_sensors.course, &"")

func test_the_screen_gives_size_distance_time_and_cost():
	var s := _with_system()
	var planet := s.planets()[0]
	_page.selected = StringName("body:" + String(planet.id))
	var lines := _page.lines(_ctx)
	assert_eq(lines.size(), 3)
	assert_true(lines[0].begins_with(planet.name + " · PLANET · "), lines[0])
	assert_true(lines[0].ends_with(" KM ACROSS"), lines[0])
	assert_true(lines[1].contains(" FLYING"), lines[1])
	assert_true(lines[2].begins_with("WARP ") or lines[2].begins_with("NEED ") or lines[2].begins_with("FLY")
		or lines[2].begins_with("BLOCKED"), lines[2])

func test_the_stops_reach_a_planet_s_moons_and_the_whole_system():
	assert_eq(MapPage.STOPS, [2000.0, 10000.0, 50000.0, 500000.0, 9000000.0] as Array[float])
	assert_eq(MapPage.SYSTEM_RANGE, MapPage.STOPS.size() - 1)
	assert_eq(MapPage.SCALE_MAX, MapPage.STOPS[MapPage.SYSTEM_RANGE])
	assert_gte(BodyContacts.RANGE, MapPage.QUERY)

func test_flying_time_reads_in_minutes_then_hours():
	assert_eq(MapPage.flying_text(72000.0), "10 MIN FLYING")
	assert_eq(MapPage.flying_text(10.0), "1 MIN FLYING")
	assert_eq(MapPage.flying_text(4600000.0), "11 H FLYING")

func test_a_moon_s_screen_says_moon_and_its_size():
	var s := _with_system()
	var moons := s.bodies.filter(func(b: SystemBody) -> bool: return b.kind == SystemBody.Kind.MOON)
	if moons.is_empty():
		pass_test("no moons in this seed")
		return
	var m: SystemBody = moons[0]
	_page.selected = BodyContacts.id_of(m)
	var lines := _page.lines(_ctx)
	assert_eq(lines[0], "%s · MOON · %d KM ACROSS" % [m.name, roundi(m.radius * 2.0 / 1000.0)])

# --- the continuous scale (computer mode spec §4.1) ---------------------------

## Computer mode spec §4.1: one continuous scale, a notch of the wheel at a
## time, between its bounds.
func test_the_scale_zooms_by_a_notch_and_stops_at_its_bounds():
	_page.range_index = 1
	_page.zoom(1.0, _ctx)
	assert_almost_eq(_page.scale_m, 13000.0, 0.01)
	_page.zoom(-2.0, _ctx)
	assert_almost_eq(_page.scale_m, 10000.0 / 1.3, 0.01)
	_page.zoom(-100.0, _ctx)
	assert_eq(_page.scale_m, MapPage.SCALE_MIN)
	_page.zoom(100.0, _ctx)
	assert_eq(_page.scale_m, MapPage.SCALE_MAX)

func test_range_steps_to_the_next_stop_from_any_scale_and_wraps():
	_page.scale_m = 12000.0
	assert_eq(_page.prompt(&"range", _ctx), "Range 50 km")
	_page.press(&"range", _ctx)
	assert_eq(_page.scale_m, 50000.0)
	_page.press(&"range", _ctx)
	assert_eq(_page.scale_m, 500000.0)
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · SYSTEM")
	_page.press(&"range", _ctx)
	assert_eq(_page.scale_m, 2000.0)

func test_range_glides_the_drawn_scale_instead_of_cutting():
	_page.range_index = 1
	_page.press(&"range", _ctx)
	assert_eq(_page.shown_m(), 10000.0, "not moved yet")
	assert_true(_page.gliding())
	_page.holo(_holo, _ctx, 0.05)
	assert_between(_page.shown_m(), 10001.0, 49999.0, "part way")
	for i in 30:
		_page.holo(_holo, _ctx, 0.05)
	assert_false(_page.gliding())
	assert_eq(_page.shown_m(), 50000.0)

func test_the_title_names_the_scale_and_the_system_from_3000_km():
	_page.scale_m = 1300.0
	assert_eq(_page.title(), "MAP · 1.3 KM")
	_page.scale_m = 12345.0
	assert_eq(_page.title(), "MAP · 12 KM")
	_page.scale_m = 3100000.0
	assert_eq(_page.title(), "MAP · SYSTEM")

func test_an_old_save_s_range_loads_as_its_stop():
	var again := MapPage.new()
	again.restore({"range": 3, "selected": "body:x"})
	assert_eq(again.scale_m, 500000.0)
	assert_eq(again.shown_m(), 500000.0)
	_page.scale_m = 77000.0
	again.restore(_page.save())
	assert_eq(again.scale_m, 77000.0)

func test_the_centre_weight_is_the_ship_to_500_km_and_the_star_from_3000_km():
	assert_eq(MapPage.system_weight(500000.0), 0.0)
	assert_eq(MapPage.system_weight(3000000.0), 1.0)
	var last := 0.0
	for k in 21:
		var w := MapPage.system_weight(500000.0 * pow(6.0, k / 20.0))
		assert_true(w >= last, "only ever further towards the star")
		last = w

## Computer mode spec §4.3: what leaves the map as you zoom out leaves by
## shrinking across a band.
func test_salvage_and_life_shrink_away_past_10_km_and_big_rocks_past_50_km():
	var salvage := Contact.new()
	salvage.kind = &"salvage"
	assert_eq(MapPage.shrink(salvage, 10000.0), 1.0)
	assert_between(MapPage.shrink(salvage, 14000.0), 0.01, 0.99)
	assert_eq(MapPage.shrink(salvage, 20000.0), 0.0)
	var rock := Contact.new()
	rock.kind = &"rock"
	assert_eq(MapPage.shrink(rock, 50000.0), 1.0)
	assert_eq(MapPage.shrink(rock, 100000.0), 0.0)
	var world := Contact.new()
	world.kind = &"body"
	assert_eq(MapPage.shrink(world, 9000000.0), 1.0)

func test_a_mark_shrunk_away_is_not_placed():
	_add(&"salvage:b", Contact.PING, Vector3(0, 0, -4000), 0.0, 4)
	_page.restore({"scale": 25000.0})
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_false(_page.targets(_ctx).any(func(c: Contact) -> bool: return c.id == &"salvage:b"))
	assert_false(_page.shown(_ctx).any(func(c: Contact) -> bool: return c.id == &"salvage:b"), "gone past 20 km")
	assert_eq(_holo.mark_count(&"diamond"), 0)

func test_a_mark_almost_shrunk_away_is_drawn_by_the_page_but_not_placed():
	_add(&"salvage:b", Contact.PING, Vector3(0, 0, -4000), 0.0, 4)
	_page.restore({"scale": 19900.0})
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_true(_page.shown(_ctx).any(func(c: Contact) -> bool: return c.id == &"salvage:b"), "still on the map")
	assert_eq(_holo.mark_count(&"diamond"), 0, "smaller than SMALLEST, so not placed")

## Spec §4.3: a rock past 50 km is not a target but is seen shrinking.
func test_a_rock_inside_its_band_is_drawn_shrunk_and_is_not_a_target():
	_add(&"rock:a", Contact.EXACT, Vector3(0, 0, -40000), 300.0)
	_page.restore({"scale": 70000.0})
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_page.targets(_ctx).size(), 0, "not at full size")
	assert_eq(_holo.mark_count(&"ball"), 1, "drawn")
	var drawn := _holo.mark_transform(&"ball", 0).basis.get_scale().x
	var full := MapPage.mark_size(_add_free_rock(300.0), 70000.0, 0.0)
	assert_gt(drawn, 0.0)
	assert_lt(drawn, full)
	_page.restore({"scale": 45000.0})
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_almost_eq(_holo.mark_transform(&"ball", 0).basis.get_scale().x, full, 0.0001, "full size inside 50 km")

## The course is always shown (§4.3 does not shrink it away).
func test_the_course_does_not_shrink_away():
	_add(&"rock:a", Contact.EXACT, Vector3(0, 0, -40000), 300.0)
	_sensors.set_course(&"rock:a")
	_page.restore({"scale": 150000.0})
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"ball", InteriorPalette.AMBER), 1, "the course, past its band")
	assert_almost_eq(_holo.mark_transform(&"ball", 0, InteriorPalette.AMBER).basis.get_scale().x,
		MapPage.ROCK_FAR, 0.0001, "at its full mark size")

func _add_free_rock(radius: float) -> Contact:
	var c := Contact.new()
	c.kind = &"rock"
	c.precision = Contact.EXACT
	c.radius = radius
	return c

func test_targets_are_what_is_inside_the_holo_at_full_size():
	_add(&"rock:near", Contact.EXACT, Vector3(0, 0, -8000), 300.0)
	_add(&"rock:far", Contact.EXACT, Vector3(0, 0, -28000), 300.0)
	_add(&"body:p", Contact.EXACT, Vector3(0, 0, -300000), 30000.0, 0, &"body")
	_page.range_index = 1
	_refresh()
	assert_eq(_page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id), [&"rock:near"])
	_page.restore({"scale": 45000.0})
	_refresh()
	assert_eq(_page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id), [&"rock:near", &"rock:far"])
	_page.range_index = 3
	_refresh()
	assert_eq(_page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id), [&"body:p"], "the rocks are gone")

func test_half_way_out_the_ship_and_the_star_sit_either_side_of_the_centre():
	var s := _with_system()
	_page.restore({"scale": sqrt(MapPage.SHIP_CENTRED * MapPage.STAR_CENTRED)})
	var frame := _ctx.map_frame()
	var star := _page.holo_position(_ctx, frame, s.star.point)
	var ship := _page.holo_position(_ctx, frame, s.entry())
	assert_almost_eq(star, -ship, Vector3.ONE * 0.0001)

func test_the_ship_is_a_chevron_near_and_a_pip_far():
	_page.range_index = 1
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_true(_holo.chevron_shown())
	_with_system()
	_page.holo(_holo, _ctx, 0.0)
	assert_false(_holo.chevron_shown())
	assert_gt(_holo.mark_count(&"ball", InteriorPalette.LIGHT_WARM), 0, "the pip")

func test_warp_limits_are_drawn_near_a_world_not_only_on_the_system_range():
	var s := _with_system()
	var planet: SystemBody = null
	for b in s.bodies:
		if b.kind == SystemBody.Kind.PLANET:
			planet = b
			break
	_universe.origin = planet.point.plus(Vector3(planet.warp_limit + 20000.0, 0, 0))
	_page.range_index = 3
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_gt(_holo.mark_count(&"tick", InteriorPalette.HOLO_DIM), 0, "the planet's limit at 500 km")

func test_belts_and_scale_rings_grow_in_past_500_km():
	_with_system()
	_page.range_index = 3
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"tick", MapPage.colour_for(&"rock")), 0, "no belt at 500 km")
	_page.range_index = MapPage.SYSTEM_RANGE
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_gt(_holo.mark_count(&"tick", MapPage.colour_for(&"rock")), 0, "belts on the system range")

func test_marks_are_placed_every_frame_while_the_scale_glides_up_close():
	_add(&"rock:a", Contact.EXACT, Vector3(0, 0, -4000), 300.0)
	_page.range_index = 1
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	var before := _holo.mark_transform(&"ball", 0).origin
	_page.zoom(-3.0, _ctx)
	_page.holo(_holo, _ctx, 0.016)
	assert_ne(_holo.mark_transform(&"ball", 0).origin, before, "placed afresh while zooming")

## Spec §4.7 as planned: a placing is cheap enough (2-3 ms at the whole
## system) that a glide places every frame at any scale, and the last lands on
## the final scale.
func test_a_glide_at_50_km_places_every_frame():
	_add(&"rock:a", Contact.EXACT, Vector3(0, 0, -20000), 300.0)
	_page.range_index = 2
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	_page.zoom(1.0, _ctx)
	var frames := 0
	var placed := 0
	var last := _holo.mark_transform(&"ball", 0).origin
	while _page.gliding() and frames < 120:
		_page.holo(_holo, _ctx, 0.016)
		frames += 1
		var now := _holo.mark_transform(&"ball", 0).origin
		if not now.is_equal_approx(last):
			placed += 1
			last = now
	assert_false(_page.gliding(), "the glide ended")
	assert_gt(frames, 5, "a glide of several frames")
	assert_eq(placed, frames, "placed afresh every frame of it")
	_page.holo(_holo, _ctx, 0.016)
	assert_almost_eq(_holo.mark_transform(&"ball", 0).origin, Vector3(0, 0, -20000) * (HoloVolume.RADIUS / _page.scale_m),
		Vector3.ONE * 0.001, "placed at the final scale as the glide ends")

# --- the placing's guard (the final review, item 1) ----------------------------

## Every mark the last placing drew: for each shape and colour, its transforms
## as 12 floats apiece, in the order they were added; and the bracket.
func _placing_snapshot() -> Dictionary:
	var out := {}
	for shape: StringName in HoloVolume.SHAPES:
		for colour: Color in _holo._groups.get(shape, {}):
			var floats: Array[float] = []
			for xf: Transform3D in _holo._placed[_holo._groups[shape][colour]]:
				for v in [xf.basis.x, xf.basis.y, xf.basis.z, xf.origin]:
					floats.append_array([v.x, v.y, v.z])
			if not floats.is_empty():
				out["%s/%s" % [shape, colour.to_html()]] = floats
	var b := _holo.bracket_position()
	out["bracket"] = [b.x, b.y, b.z] if _holo.bracket_shown() else []
	return out

## The whole system with a warp charted, the hull turned off the axes.
func _placing_at_system() -> Dictionary:
	var s := _with_system()
	_hull.rotation = Vector3(0.2, 0.9, -0.1)
	var planet := s.planets()[s.planets().size() - 1]
	_page.selected = StringName("body:" + String(planet.id))
	_page.press(&"big", _ctx)
	_page.holo(_holo, _ctx, 1.0)
	return _placing_snapshot()

## 500 km off a planet, just outside its warp limit, the hull turned.
func _placing_near_a_planet() -> Dictionary:
	var s := _with_system()
	_hull.rotation = Vector3(-0.3, 2.1, 0.15)
	var planet: SystemBody = null
	for b in s.bodies:
		if b.kind == SystemBody.Kind.PLANET:
			planet = b
			break
	_universe.origin = planet.point.plus(Vector3(planet.warp_limit + 20000.0, 0, 0))
	_page.range_index = 3
	_refresh()
	_page.holo(_holo, _ctx, 1.0)
	return _placing_snapshot()

## Making the placing cheaper must not move a mark: every tick and mark
## matches what the per-point placing drew, recorded under test/fixtures. Run
## with WHOKNOWS_RECORD_PLACING=1 to record them afresh.
func test_a_placing_at_system_draws_every_mark_where_it_always_has():
	_check_placing(_placing_at_system(), "res://test/fixtures/map_page_placing_system.json")

func test_a_placing_near_a_planet_draws_every_mark_where_it_always_has():
	_check_placing(_placing_near_a_planet(), "res://test/fixtures/map_page_placing_near_planet.json")

func _check_placing(now: Dictionary, golden_path: String) -> void:
	if OS.get_environment("WHOKNOWS_RECORD_PLACING") == "1":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(golden_path.get_base_dir()))
		var out := FileAccess.open(golden_path, FileAccess.WRITE)
		out.store_string(JSON.stringify(now, "", true, true))
		out.close()
		pending("recorded %s" % golden_path)
		return
	var golden: Variant = JSON.parse_string(FileAccess.get_file_as_string(golden_path))
	assert_true(golden is Dictionary, "the recorded placing %s" % golden_path)
	if not golden is Dictionary:
		return
	var was: Dictionary = golden
	assert_eq(now.keys().size(), was.keys().size(), "the same groups: %s" % [now.keys()])
	var compared := 0
	for key: String in was:
		var a: Array = was[key]
		var b: Array = now.get(key, [])
		assert_eq(b.size(), a.size(), "%s: the same number of marks" % key)
		if b.size() != a.size():
			continue
		var worst := 0.0
		for i in a.size():
			worst = maxf(worst, absf(float(a[i]) - float(b[i])))
		assert_lt(worst, 0.0001, "%s: no mark moved" % key)
		compared += 1
	assert_gt(compared, 3, "several groups compared")

## HoloVolume.add_mark drops a group's marks past CAPACITY without a word, so
## the whole system's faint ticks must fit in one group.
func test_the_system_s_faint_ticks_fit_in_the_holo():
	_with_system()
	_page.holo(_holo, _ctx, 1.0)
	assert_lt(_holo.mark_count(&"tick", InteriorPalette.HOLO_DIM), HoloVolume.CAPACITY)
