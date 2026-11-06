extends GutTest

## Where you are (the system skeleton spec §8): places at known points,
## innermost first; hysteresis at their edges; signals once per change.

var _system: SystemRecipe

func before_all():
	# A seed with a ringed planet, so every kind of place is there.
	for s in range(1, 200):
		var sys := SystemRecipe.from_seed(s)
		if sys.planets().any(func(p: SystemBody) -> bool: return p.ring != null and not sys.moons_of(p).is_empty()):
			_system = sys
			return

func _ringed() -> SystemBody:
	for p in _system.planets():
		if p.ring != null and not _system.moons_of(p).is_empty():
			return p
	return null

func _ids(places: Array) -> Array:
	return places.map(func(p: Whereabouts.Place) -> StringName: return p.id)

func test_open_space_is_just_the_system():
	var far := UniversePoint.at(0, SystemRecipe.PLANE_Y + int(_system.star.neighbourhood) + 100000, 0)
	var places := Whereabouts.places_at(_system, far)
	assert_eq(_ids(places), [&"system"])
	assert_eq(places[0].name, _system.name)

func test_in_a_ring_near_its_planet():
	var p := _ringed()
	var ring := p.ring
	var across := ring.normal.cross(Vector3.RIGHT).normalized()
	var at := p.point.plus(across * (ring.inner + ring.outer) * 0.5)
	var ids := _ids(Whereabouts.places_at(_system, at))
	assert_eq(ids[0], StringName("ring_%s" % p.id))
	assert_true(ids.has(StringName("near_%s" % p.id)))
	assert_eq(ids[ids.size() - 1], &"system")

func test_near_a_moon_is_inside_near_its_planet():
	var p := _ringed()
	var m := _system.moons_of(p)[0]
	var ids := _ids(Whereabouts.places_at(_system, m.point.plus(Vector3(0, m.radius + 100.0, 0))))
	assert_lt(ids.find(StringName("near_%s" % m.id)), ids.find(StringName("near_%s" % p.id)), "the moon first")

func test_in_a_belt():
	var belt := _system.belts[0]
	var at := belt.centre.plus(Vector3(belt.radius, 0, 0))
	var ids := _ids(Whereabouts.places_at(_system, at))
	assert_eq(ids, [&"belt_0", &"system"])

func test_you_leave_only_beyond_the_edge():
	var belt := _system.belts[0]
	var just_out := belt.centre.plus(Vector3(belt.radius + belt.half_width + 50.0, 0, 0))
	assert_false(_ids(Whereabouts.places_at(_system, just_out)).has(&"belt_0"), "not entered from outside")
	assert_true(_ids(Whereabouts.places_at(_system, just_out, {&"belt_0": true})).has(&"belt_0"), "not yet left")
	var well_out := belt.centre.plus(Vector3(belt.radius + belt.half_width + 150.0, 0, 0))
	assert_false(_ids(Whereabouts.places_at(_system, well_out, {&"belt_0": true})).has(&"belt_0"))

func test_the_node_says_once_when_you_come_and_go():
	var universe := Universe.new()
	add_child_autofree(universe)
	var focus := Node3D.new()
	add_child_autofree(focus)
	universe.set_focus(focus)
	var belt := _system.belts[0]
	universe.origin = belt.centre.plus(Vector3(belt.radius, 0, 0))
	var w := Whereabouts.new()
	add_child_autofree(w)
	watch_signals(w)
	w.setup(_system, universe)
	assert_signal_emit_count(w, "entered", 2, "the belt and the system")
	assert_eq(w.dust(), Whereabouts.DUST_THICK)
	assert_true(w.text().begins_with(_system.name + " › in "), w.text())
	w.look()
	assert_signal_emit_count(w, "entered", 2, "nothing new")
	focus.global_position = Vector3(0, 60000, 0)
	w.look()
	assert_signal_emit_count(w, "left", 1)
	assert_eq(w.dust(), Whereabouts.DUST_OPEN)

# --- warp limits (the warp spec §8) -------------------------------------------

func _has(places: Array[Whereabouts.Place], id: StringName) -> bool:
	return places.any(func(p: Whereabouts.Place) -> bool: return p.id == id)

func test_a_limit_is_entered_at_its_edge_and_left_beyond_it():
	var s := SystemRecipe.from_seed(1337)
	var p := s.planets()[0]
	var id := StringName("limit_%s" % p.id)
	var up := Vector3.UP
	assert_true(_has(Whereabouts.limits_at(s, p.point.plus(up * (p.warp_limit - 10.0))), id))
	assert_false(_has(Whereabouts.limits_at(s, p.point.plus(up * (p.warp_limit + 50.0))), id))
	assert_true(_has(Whereabouts.limits_at(s, p.point.plus(up * (p.warp_limit + 50.0)), {id: true}), id),
		"left only HYSTERESIS beyond")

func test_warp_clear_the_limit_signals_and_the_line_unchanged():
	var s := SystemRecipe.from_seed(1337)
	var p := s.planets()[0]
	var universe := Universe.new()
	add_child_autofree(universe)
	var focus := Node3D.new()
	add_child_autofree(focus)
	universe.set_focus(focus)
	universe.origin = p.point.plus(Vector3.UP * (p.warp_limit - 1000.0))
	var w := Whereabouts.new()
	add_child_autofree(w)
	w.setup(s, universe)
	assert_false(w.warp_clear())
	assert_eq(w.limits(), [p.id] as Array[StringName])
	assert_false(w.text().contains("limit"), "limits stay off the line")
	var left := []
	w.limit_left.connect(func(q: Whereabouts.Place) -> void: left.append(q.id))
	universe.origin = s.star.point.plus(Vector3.UP * (s.star.neighbourhood + 100000.0))
	w.look()
	assert_true(w.warp_clear())
	assert_true(left.has(StringName("limit_%s" % p.id)))
	w.look()
	assert_eq(left.count(StringName("limit_%s" % p.id)), 1, "once")

func test_the_start_is_inside_its_cluster_s_limit():
	var s := SystemRecipe.from_seed(1337)
	var ids := Whereabouts.limits_at(s, s.entry()).map(func(q: Whereabouts.Place) -> StringName: return q.id)
	assert_true(ids.has(&"limit_belt_0.c1"), "a new game begins by a major body")

# --- the air (the desert world spec §6.1) -------------------------------------

func _far() -> UniversePoint:
	return UniversePoint.at(0, SystemRecipe.PLANE_Y + int(_system.star.neighbourhood) + 100000, 0)

## A whereabouts reading `_system`, its focus at `focus` and the origin on `b`.
func _air_rig(b: SystemBody) -> Array:
	var universe := Universe.new()
	add_child_autofree(universe)
	var focus := Node3D.new()
	add_child_autofree(focus)
	universe.set_focus(focus)
	universe.origin = b.point
	var w := Whereabouts.new()
	add_child_autofree(w)
	w.setup(_system, universe)
	return [w, focus]

func test_the_air_up_and_sun_up_over_a_world():
	var b := _system.planets()[0]
	var was := b.recipe.atmosphere
	b.recipe.atmosphere = WorldRecipe.Atmosphere.THICK
	var rig := _air_rig(b)
	var w: Whereabouts = rig[0]
	var focus: Node3D = rig[1]
	var dir := Vector3(0.3, 0.8, 0.5).normalized()
	var r := b.radius + w.terrain_of(b).height_at(dir) + 1000.0
	focus.global_position = dir * r
	w.look()
	assert_almost_eq(w.air(), b.recipe.air_at(w.altitude()), 1e-6)
	assert_gt(w.air(), 0.0)
	assert_almost_eq(w.up(), dir, Vector3.ONE * 1e-5)
	# The sun overhead, and underfoot, standing on the ground.
	var to_star := _system.star.point.minus(b.point).normalized()
	focus.global_position = to_star * (b.radius + w.terrain_of(b).height_at(to_star))
	w.look()
	assert_gt(w.sun_up(), 0.99)
	focus.global_position = -to_star * (b.radius + w.terrain_of(b).height_at(-to_star))
	w.look()
	assert_lt(w.sun_up(), -0.99)
	b.recipe.atmosphere = was

func test_outside_every_well_there_is_no_air_and_the_sun_is_up():
	var rig := _air_rig(_system.planets()[0])
	var w: Whereabouts = rig[0]
	var focus: Node3D = rig[1]
	w.universe.origin = _far()
	focus.global_position = Vector3.ZERO
	w.look()
	assert_null(w.well())
	assert_eq(w.air(), 0.0)
	assert_eq(w.up(), Vector3.ZERO)
	assert_eq(w.sun_up(), 1.0)

func test_the_dust_goes_as_the_air_thickens():
	var b := _system.planets()[0]
	var was := b.recipe.atmosphere
	b.recipe.atmosphere = WorldRecipe.Atmosphere.THICK
	var rig := _air_rig(b)
	var w: Whereabouts = rig[0]
	var focus: Node3D = rig[1]
	var dir := Vector3(0.3, 0.8, 0.5).normalized()
	var ground := b.radius + w.terrain_of(b).height_at(dir)
	var h := b.recipe.air_top() * (1.0 - sqrt(0.1))   # where the air is 0.1
	focus.global_position = dir * (ground + h)
	w.look()
	assert_almost_eq(w.air(), 0.1, 1e-4)
	var thin_dust := w.dust()
	b.recipe.atmosphere = WorldRecipe.Atmosphere.NONE
	w.look()
	assert_gt(w.dust(), 0.0)
	assert_almost_eq(thin_dust, w.dust() * 0.5, 1e-4)
	b.recipe.atmosphere = WorldRecipe.Atmosphere.THICK
	focus.global_position = dir * (ground + 300.0)
	w.look()
	assert_eq(w.dust(), 0.0)
	w.universe.origin = _far()
	focus.global_position = Vector3.ZERO
	w.look()
	assert_eq(w.dust(), Whereabouts.DUST_OPEN)
	b.recipe.atmosphere = was
